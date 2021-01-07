import std.stdio;
import std.getopt;
	alias required = std.getopt.config.required;
import std.string;
import std.stdint;
import std.conv;
import std.path;
import std.array;
import std.typecons;
import std.file;
	alias write = std.stdio.write;
	alias writeFile = std.file.write;
import std.typecons: Tuple;
import std.exception: assertThrown, assertNotThrown, enforce;
import std.algorithm;
import std.datetime.stopwatch: StopWatch;
import std.parallelism;
import core.thread;

import mysql;

import nwn.gff;
import nwn.twoda;
import nwn.tlk;
import nwnlibd.path;

import lcda.config;


struct ItemProcessorConfig {
	string vaultOvr;
	string tempOvr;
	bool alwaysAccept = false;
	uint parallelJobs = 1;
	bool skipVault = false;
	bool skipSql = false;
	bool dryRun = false;
}

auto itemProcessorParseArgs(ref string[] args){
	ItemProcessorConfig cfg;

	auto res = getopt(args, config.passThrough,
		"vault", "Vault containing all character bic files to update.\nDefault: $path_nwn2docs/servervault", &cfg.vaultOvr,
		"temp", "Temp folder for storing modified files installing them, and also backup files.\nDefault: $path_nwn2docs/itemupdater_tmp", &cfg.tempOvr,
		"skip-vault", "Do not update the servervault", &cfg.skipVault,
		"skip-sql", "Do not update the items in the SQL db (coffreibee, casieribee)", &cfg.skipSql,
		"dry-run", "Do not write any file or execute any SQL write commands", &cfg.dryRun,
		"y|y", "Do not prompt and accept everything", &cfg.alwaysAccept,
		"j|j", "Number of parallel jobs\nDefault: 1", &cfg.parallelJobs,
	);
	res.options = res.options[0..$-1];//remove help option
	if(res.helpWanted)
		args ~= "--help";

	return tuple(res, cfg);
}

struct ItemProcessorContext{
	import std.variant: VariantN;

	static struct Sql{
		string table;
		size_t id;
		string owner;
	}
	static struct Bic{
		string bicFile;
		Gff character;
	}

	VariantN!(Sql.sizeof, Sql, Bic) _value;
	alias _value this;

	string toString() const{
		if(auto v = _value.peek!Sql)
			return format!"%s[%d](owned by %s)"(v.table, v.id, v.owner);
		else if(auto v = _value.peek!Bic)
			return v.bicFile.stripExtension;
		else assert(0);
	}
}

int processAllItems(in ItemProcessorConfig cfg, bool delegate(ref GffStruct item, in ItemProcessorContext context) processItem){

	//paths
	immutable vault = cfg.vaultOvr !is null? cfg.vaultOvr : buildPathCI(LcdaConfig["path_nwn2docs"], "servervault");
	enforce(vault.exists && vault.isDir, "Vault is not a directory/does not exist");
	immutable temp = cfg.tempOvr !is null? cfg.tempOvr : buildPath(LcdaConfig["path_nwn2docs"], "itemupdater_tmp");

	StopWatch bench;

	auto taskPool = new TaskPool(cfg.parallelJobs-1);
	scope(exit) taskPool.finish;

	auto connPool = cfg.skipSql? null : new MySQLPool(
		LcdaConfig["sql_address"],
		LcdaConfig["sql_user"],
		LcdaConfig["sql_password"],
		LcdaConfig["sql_schema"]
	);
	if(connPool !is null){
		connPool.onNewConnection = delegate(conn){
			conn.exec("SET autocommit=0");

			// The workaround for manual commit / rollback relies on the
			// lastCommandID to know if the connection has been used and
			// should be committed / rolled back
			assert(conn.lastCommandID == 3);
		};
		connPool.lockConnection();
	}
	scope(exit){
		if(connPool !is null){
			connPool.removeUnusedConnections();
		}
	}

	if(temp.exists){
		if(!temp.dirEntries(SpanMode.shallow).empty){
			stderr.writeln("\x1b[1;31mWARNING: '",temp,"' is not empty and may contain backups from previous item updates\x1b[m");
			writeln();
			write("'d' to delete content and continue: ");
			stdout.flush();
			if(readln()[0] != 'd')
				return 1;
		}
		temp.rmdirRecurse;
		writeln("Deleted '",temp,"'");
	}
	temp.mkdirRecurse;

	//Servervault update
	if(!cfg.skipVault){
		writeln();
		writeln("".center(80, '='));
		writeln("  SERVERVAULT UPDATE  ".center(80, '|'));
		writeln("".center(80, '='));
		stdout.flush();


		bench.start;
		foreach(charFile ; taskPool.parallel(vault.dirEntries("*.bic", SpanMode.depth))){
			immutable charPathRelative = charFile.relativePath(vault);

			bool charUpdated = false;
			string[] modifiedResrefs;

			void updateInventory(ref GffStruct container, in ItemProcessorContext context){
				enforce("ItemList" in container);

				foreach(i, ref item ; container["ItemList"].get!GffList){
					if(processItem(item, context)){
						modifiedResrefs ~= item["TemplateResRef"].to!string;
						charUpdated = true;
					}

					if("ItemList" in item){
						updateInventory(item, context);
					}
				}

				if("Equip_ItemList" in container){
					bool[size_t] itemsToRemove;
					foreach(i, ref item ; container["Equip_ItemList"].get!GffList){
						if(processItem(item, context)){
							modifiedResrefs ~= item["TemplateResRef"].to!string;
							charUpdated = true;
						}
					}
				}
			}

			const oldData = cast(ubyte[])charFile.read;
			auto character = new Gff(oldData);

			ItemProcessorContext context;
			context._value = ItemProcessorContext.Bic(charPathRelative, character);
			updateInventory(character, context);


			if(charUpdated){
				//copy backup
				auto backupFile = buildPath(temp, "backup_vault", charPathRelative);
				if(!buildNormalizedPath(backupFile, "..").exists)
					buildNormalizedPath(backupFile, "..").mkdirRecurse;
				charFile.copy(backupFile);

				//serialize current
				auto tmpFile = buildPath(temp, "updated_vault", charPathRelative);
				if(!buildNormalizedPath(tmpFile, "..").exists)
					buildNormalizedPath(tmpFile, "..").mkdirRecurse;

				const newData = character.serialize;
				if(oldData == newData){
					writeln("\x1b[1;31mWARNING: Character ", charPathRelative, " did not change after update (modified item resrefs: ", modifiedResrefs, ")\x1b[m");
					stdout.flush();
				}
				else{
					tmpFile.writeFile(newData);

					//message
					writeln(charPathRelative.leftJustify(35), ": Modified ", modifiedResrefs.length, " items: ", modifiedResrefs);
					stdout.flush();
				}


			}

		}
		bench.stop;
		writeln(">>> ",bench.peek.total!"msecs"/1000.0," seconds");
	}


	//SQL db update
	if(!cfg.skipSql){
		writeln();
		writeln("".center(80, '='));
		writeln("  SQL - IBEE  ".center(80, '|'));
		writeln("".center(80, '='));
		writeln();
		stdout.flush();

		immutable coffreIbeeBackup = buildPath(temp, "backup_coffreibee");
		coffreIbeeBackup.mkdirRecurse;
		immutable casierIbeeBackup = buildPath(temp, "backup_casieribee");
		casierIbeeBackup.mkdirRecurse;

		void UpdateSQL(string type)(){
			auto conn = connPool.lockConnection();
			static if(type == "coffreibee")
				auto res = conn.query("SELECT id, item_name, account_name, item_data FROM coffreibee");
			else static if(type == "casieribee")
				auto res = conn.query("SELECT id, item_name, vendor_account_name, item_data FROM casieribee WHERE active=1");
			else static assert(0);

			//foreach(row ; taskPool.parallel(res.array)){
			foreach(row ; res.array){
				auto id = row[0].get!long;
				auto itemName = row[1].get!string;
				auto owner = row[2].get!string;
				auto itemData = row[3].get!(ubyte[]);
				auto item = new Gff(itemData);

				ItemProcessorContext context;
				context._value = ItemProcessorContext.Sql(type, id, owner);
				if(processItem(item, context)){
					ubyte[] updatedData = item.serialize();
					if(itemData == updatedData){
						writefln("\x1b[1;31mWARNING: %s: item did not change after update\x1b[m", context);
					}
					else{
						//Update item data
						auto conn2 = connPool.lockConnection();
						auto affectedRows = conn2.exec(
							"UPDATE "~type~" SET"
								~ " item_name=CONCAT(item_name, ' <c=#9257FF>*</c>'),"
								~ " item_data=?"
							~ " WHERE id=?",
							updatedData, id,
						);
						enforce(affectedRows==1, "Wrong number of rows affected by SQL query: "~affectedRows.to!string~" rows affected for item ID="~id.to!string);

						static if(type == "coffreibee")
							buildPath(coffreIbeeBackup, id.to!string~".item.gff").writeFile(itemData);
						else static if(type == "casieribee")
							buildPath(casierIbeeBackup, id.to!string~".item.gff").writeFile(itemData);
						else static assert(0);
					}
					writeln(type, "[",id,"] ", itemName, " (Owner: ",owner,")");
					stdout.flush();
				}
			}

		}

		bench.reset;
		bench.start;

		//COFFREIBEE
		UpdateSQL!"coffreibee"();
		writeln("-----");
		//CASIERIBEE
		UpdateSQL!"casieribee"();

		bench.stop;
		writeln(">>> ",bench.peek.total!"msecs"/1000.0," seconds");
	}




	writeln();
	writeln("".center(80, '='));
	writeln("  INSTALLATION  ".center(80, '|'));
	writeln("".center(80, '='));
	writeln("All items have been updated");
	writeln("- new character files have been put in ", buildPath(temp, "updated_vault"));
	writeln("- new items in database are pending for SQL commit");
	writeln();


	char ans;
	do{
		write("'y' to apply changes, 'n' to discard them: ");
		stdout.flush();
		ans = readln()[0];
	} while(ans!='y' && ans !='n');

	if(ans=='y'){
		//Copy char to new vault
		size_t count;
		void copyRecurse(string from, string to){
			if(isDir(from)){
				if(!to.exists){
					mkdir(to);
				}

				if(to.isDir){
					foreach(child ; from.dirEntries(SpanMode.shallow))
						copyRecurse(child.name, buildPathCI(to, child.baseName));
				}
				else
					throw new Exception("Cannot copy '"~from~"': '"~to~"' already exists and is not a directory");
			}
			else{
				//writeln("> ",to); stdout.flush();
				copy(from, to);
				count++;
			}
		}

		if(!cfg.skipVault){
			copyRecurse(buildPath(temp, "updated_vault"), vault);
			writeln(count," files copied");
			stdout.flush();
		}

		//SQL commit
		if(!cfg.skipSql){
			//conn.exec("COMMIT");
			auto conns = [connPool.lockConnection()];
			while(conns[$-1].lastCommandID > 3){
				conns[$-1].exec("COMMIT");
				conns ~= connPool.lockConnection();
			}
			foreach(ref conn ; conns)
				conn.close();
			writeln("SQL work commited");
			stdout.flush();
		}

		writeln("  DONE !  ".center(80, '_'));
		return 0;
	}


	//SQL rollback
	if(!cfg.skipSql){
		//conn.exec("ROLLBACK");
		auto conns = [connPool.lockConnection()];
		while(conns[$-1].lastCommandID > 3){
			conns[$-1].exec("ROLLBACK");
			conns ~= connPool.lockConnection();
		}
		foreach(ref conn ; conns)
			conn.close();
	}

	return 0;
}

