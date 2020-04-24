import std.stdio;
import std.getopt;
	alias required = std.getopt.config.required;
import std.string;
import std.stdint;
import std.conv;
import std.path;
import std.array;
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
import lcda.hagbe: isEnchanted, addEnchantmentSuffix;



int main(string[] args){
	string vaultOvr;
	string tempOvr;
	bool noninteractive = false;
	uint parallelJobs = 1;
	bool skipVault = false;
	bool skipSql = false;

	//Parse cmd line
	try{
		enum prgHelp = "Mark items in bic files & sql db\n";

		auto res = LcdaConfig.init(args);
		res.options ~= getopt(args,
			"vault", "Vault containing all character bic files to update.\nDefault: $path_nwn2docs/servervault", &vaultOvr,
			"temp", "Temp folder for storing modified files installing them, and also backup files.\nDefault: $path_nwn2docs/itemupdater_tmp", &tempOvr,
			"skip-vault", "Do not update the servervault", &skipVault,
			"skip-sql", "Do not update the items in the SQL db (coffreibee, casieribee)", &skipSql,
			"y|y", "Do not prompt and accept everything", &noninteractive,
			"j|j", "Number of parallel jobs\nDefault: 1", &parallelJobs,
			).options;

		if(res.helpWanted){
			improvedGetoptPrinter(
				prgHelp,
				res.options);
			return 0;
		}

		enforce(parallelJobs>0, "-j option must be >= 1");
	}
	catch(Exception e){
		stderr.writeln(e.msg);
		stderr.writeln("Use --help for more information");
		return 1;
	}

	//paths
	immutable vault = vaultOvr !is null? vaultOvr : buildPathCI(LcdaConfig["path_nwn2docs"], "servervault");
	enforce(vault.exists && vault.isDir, "Vault is not a directory/does not exist");
	immutable temp = tempOvr !is null? tempOvr : buildPath(LcdaConfig["path_nwn2docs"], "itemupdater_tmp");

	auto tlkresolv = new StrRefResolver(
		new Tlk(buildPath(LcdaConfig["path_tlk_main"])),
		new Tlk(buildPath(LcdaConfig["path_tlk_lcda"])),
	);

	StopWatch bench;

	auto taskPool = new TaskPool(parallelJobs-1);
	scope(exit) taskPool.finish;

	auto connPool = skipSql? null : new MySQLPool(
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
		if(noninteractive==false && !temp.dirEntries(SpanMode.shallow).empty){
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

	bool processItem(ref GffNode item){
		if(isEnchanted(item)){
			return addEnchantmentSuffix(item, tlkresolv);
		}
		return false;
	}


	//Servervault update
	if(!skipVault){
		writeln();
		writeln("".center(80, '='));
		writeln("  SERVERVAULT UPDATE  ".center(80, '|'));
		writeln("".center(80, '='));
		stdout.flush();


		bench.start;
		foreach(charFile ; taskPool.parallel(vault.dirEntries("*.bic", SpanMode.depth))){
			immutable charPathRelative = charFile.relativePath(vault);

			bool charUpdated = false;
			size_t itemCount;

			void updateInventory(ref GffNode container){
				assert("ItemList" in container.as!(GffType.Struct));

				foreach(ref item ; container["ItemList"].as!(GffType.List)){
					if(processItem(item)){
						itemCount++;
						charUpdated = true;
					}

					if("ItemList" in item.as!(GffType.Struct)){
						updateInventory(item);
					}
				}

				if("Equip_ItemList" in container.as!(GffType.Struct)){
					bool[size_t] itemsToRemove;
					foreach(ref item ; container["Equip_ItemList"].as!(GffType.List)){
						if(processItem(item)){
							itemCount++;
							charUpdated = true;
						}
					}
				}
			}

			auto character = new Gff(cast(ubyte[])charFile.read);
			updateInventory(character);


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
				tmpFile.writeFile(character.serialize);

				//message
				writeln(charPathRelative.leftJustify(35), ": Marked ", itemCount, " items");
				stdout.flush();
			}

		}
		bench.stop;
		writeln(">>> ",bench.peek.total!"msecs"/1000.0," seconds");
	}


	//SQL db update
	if(!skipSql){
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

			foreach(row ; taskPool.parallel(res.array)){
				auto id = row[0].get!long;
				auto itemName = row[1].get!string;
				auto owner = row[2].get!string;
				auto itemData = row[3].get!(ubyte[]);
				auto item = new Gff(itemData);

				if(processItem(item)){
					ubyte[] updatedData = item.serialize();
					if(itemData == updatedData){
						writeln("\x1b[1;31mWARNING: Item id=", id, " (resref=", item["TemplateResRef"].to!string, ") did not change after update\x1b[m");
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


	if(noninteractive==false){

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

			if(!skipVault){
				copyRecurse(buildPath(temp, "updated_vault"), vault);
				writeln(count," files copied");
				stdout.flush();
			}

			//SQL commit
			if(!skipSql){
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
	}


	//SQL rollback
	if(!skipSql){
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

