import std.stdio;
import std.getopt;
	alias required = std.getopt.config.required;
import std.string;
import std.stdint;
import std.conv;
import std.path;
import std.file;
	alias write = std.stdio.write;
	alias writeFile = std.file.write;
import std.typecons;
import std.exception: assertThrown, assertNotThrown, enforce;
import std.algorithm;
import std.datetime: StopWatch;
import std.parallelism;
import core.thread;
import mysql.connection;
import nwn.gff;
import nwn.twoda;
import lcdaconfig;

void main(string[] args){

	auto res = LcdaConfig.init(args);
	if(res.helpWanted){
		improvedGetoptPrinter("",
			res.options);
		return;
	}


	alias DescEntry = Tuple!(int,string);
	DescEntry[] descriptions;

	auto conn = new Connection(
		LcdaConfig["sql_address"],
		LcdaConfig["sql_user"],
		LcdaConfig["sql_password"],
		LcdaConfig["sql_schema"]);
	scope(exit){
		conn.close();
	}

	foreach(row ; Command(conn, "SELECT id, text FROM machineot_combinaisons").execSQLResult){
		auto id = row[0].get!int;
		auto text = row[1].get!string;

		descriptions ~= DescEntry(id, text);
	}

	//writeln(descriptions);





	immutable vault = buildPath(LcdaConfig["path_nwn2docs"], "servervault");

	foreach(charFile ; vault.dirEntries("*.bic", SpanMode.depth)){

		auto accountName = buildNormalizedPath(charFile~"/..").baseName;
		if(accountName == "deleted")
			continue;
		const character = new Gff(charFile);

		writeln(accountName.leftJustify(30), charFile.baseName);
		stdout.flush();

		void checkInventory(in GffNode container){
			foreach(const ref item ; container["ItemList"].as!GffList){
				if("ItemList" in item.as!GffStruct){
					checkInventory(item);
				}

				const tag = item["Tag"].to!string;
				if(tag == "machiteot_notedefou"){
					const description = item["DescIdentified"].to!string;

					size_t foundId = size_t.max;
					foreach(ref t ; descriptions){
						if(description.indexOf(t[1])==0){
							foundId = t[0];
							break;
						}
					}

					if(foundId != foundId.max){
						auto characterName = character["FirstName"].to!string~" "~character["LastName"].to!string;
						synchronized{
							try{
								auto cmd = Command(conn,
										"INSERT IGNORE machineot_droppedmsg"
											~" (`account_name`,`character_name`,`combinaison_id`)"
											~" VALUES (?,?,?)");
								cmd.prepare;
								cmd.bindParameterTuple(
									accountName,
									characterName,
									foundId);
								ulong affectedRows;
								cmd.execPrepared(affectedRows);

								if(affectedRows==1){
									writeln("===> Add ",accountName," | ",character["FirstName"].to!string~" "~character["LastName"].to!string," | ",foundId);
									stdout.flush();
								}
							}
							catch(MySQLReceivedException e){

							}
						}

					}
					else{
						writeln("\x1b[1;31mCould not detect note ID for description: ",description,"\x1b[m");
						stdout.flush();
					}

				}
			}
		}
		checkInventory(character);
	}
}
