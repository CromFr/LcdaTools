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
import std.typecons: Tuple;
import std.exception: assertThrown, assertNotThrown, enforce;
import std.algorithm;
import std.datetime.stopwatch: StopWatch;
import std.parallelism;
import std.array;
import core.thread;
import mysql;
import nwn.gff;
import nwn.tlk;
import nwn.twoda;
import nwn.nwscript;
import nwnlibd.path;

import lcda.config;
import lcda.compat.hagbe_inc;



enum UpdatePolicy{
	Override = 0,
	Keep = 1,
}
alias ItemPolicy = UpdatePolicy[string];

int main(string[] args){
	import etc.linux.memoryerror;
	static if (is(typeof(registerMemoryErrorHandler)))
		registerMemoryErrorHandler();

	string vaultOvr;
	string tempOvr;
	bool alwaysAccept = false;
	uint parallelJobs = 1;
	bool skipVault = false;
	bool skipSql = false;
	bool dryRun = false;

	alias BlueprintUpdateDef = Tuple!(string,"from", string,"blueprint", UpdatePolicy[string],"policy");
	BlueprintUpdateDef[] resrefupdateDef;
	BlueprintUpdateDef[] tagupdateDef;


	//Parse cmd line
	try{
		void parseUpdateArg(string param, string arg){
			import std.regex: ctRegex, matchFirst;
			enum rgx = ctRegex!`^(?:(.+)=)?(.+?)(?:\(([^\(]*)\))?$`;

			foreach(ref s ; arg.split("+")){
				auto cap = s.matchFirst(rgx);
				enforce(!cap.empty, "Wrong --update format for: '"~s~"'");

				string from = cap[1];
				string blueprint = cap[2];
				auto policy = ("["~cap[3]~"]").to!(ItemPolicy);

				if(param=="update"){
					resrefupdateDef ~= BlueprintUpdateDef(from, blueprint, policy);
				}
				else if(param=="update-tag"){
					tagupdateDef ~= BlueprintUpdateDef(from, blueprint, policy);
				}
				else assert(0);
			}
		}

		enum prgHelp =
			 "Update items in bic files & sql db\n"
			~"\n"
			~"Tokens:\n"
			~"- identifier: String used to detect is the item needs to be updated. Can be a resref or a tag (see below)\n"
			~"- blueprint: Path of an UTI file, or resource name in LcdaDev\n"
			~"- policy: associative array of properties to keep/override\n"
			~"    Ex: (\"Cursed\":Keep, \"Var.bIntelligent\":Override)";
		enum updateHelp =
			 "Update an item using its TemplateResRef property as identifier.\n"
			~"The format is: identifier=blueprint(policy)\n"
			~"identifier & policy are optional\n"
			~"Can be specified multiple times, separated by the character '+'\n"
			~"Ex: --update myresref=myblueprint\n"
			~"    --update myblueprint(\"Cursed\":Keep)";

		auto res = LcdaConfig.init(args);
		res.options ~= getopt(args,
			"vault", "Vault containing all character bic files to update.\nDefault: $path_nwn2docs/servervault", &vaultOvr,
			"temp", "Temp folder for storing modified files installing them, and also backup files.\nDefault: $path_nwn2docs/itemupdater_tmp", &tempOvr,
			"update", updateHelp, &parseUpdateArg,
			"update-tag", "Similar to --update, but using the Tag property as identifier.", &parseUpdateArg,
			"skip-vault", "Do not update the servervault", &skipVault,
			"skip-sql", "Do not update the items in the SQL db (coffreibee, casieribee)", &skipSql,
			"dry-run", "Do not write any file or execute any SQL write commands", &dryRun,
			"y|y", "Do not prompt and accept everything", &alwaysAccept,
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

	// TLK resolving
	auto tlkresolv = new StrRefResolver(
		new Tlk(buildPath(LcdaConfig["path_tlk_main"])),
		new Tlk(buildPath(LcdaConfig["path_tlk_lcda"])),
	);
	initStrRefResolver(tlkresolv);

	// 2da search path
	initTwoDAPaths([buildPath(LcdaConfig["path_lcdaclientsrc"], "lcda2da.hak")]);

	alias UpdateTarget = Tuple!(Gff,"gff", ItemPolicy,"policy");
	UpdateTarget[string] updateResref;
	UpdateTarget[string] updateTag;

	bool errored = false;
	foreach(ref bpu ; resrefupdateDef){
		auto bpPath = bpu.blueprint.extension is null?
			buildPathCI(LcdaConfig["path_lcdadev"], bpu.blueprint~".uti") : bpu.blueprint;
		auto gff = new Gff(bpPath);

		if(bpu.from !is null && bpu.from.length>0){
			if(bpu.from in updateResref){
				stderr.writeln("\x1b[1;31mERROR: Template resref '"~bpu.from~"' already registered. Cannot add blueprint '"~bpu.blueprint~".uti'\x1b[m");
				errored = true;
			}
			updateResref[bpu.from] = UpdateTarget(gff, bpu.policy);
		}
		else{
			immutable tplResref = gff["TemplateResRef"].as!(GffType.ResRef);
			if(tplResref in updateResref){
				stderr.writeln("\x1b[1;31mERROR: Template resref '"~tplResref~"' already registered. Cannot add blueprint '"~bpu.blueprint~".uti'\x1b[m");
				errored = true;
			}
			updateResref[tplResref] = UpdateTarget(gff, bpu.policy);
		}
	}
	foreach(ref bpu ; tagupdateDef){
		auto bpPath = bpu.blueprint.extension is null?
			buildPathCI(LcdaConfig["path_lcdadev"], bpu.blueprint~".uti") : bpu.blueprint;
		auto gff = new Gff(bpPath);

		if(bpu.from !is null && bpu.from.length>0){
			if(bpu.from in updateTag){
				stderr.writeln("\x1b[1;31mERROR: Tag '"~bpu.from~"' already registered. Cannot add blueprint '"~bpu.blueprint~".uti'\x1b[m");
				errored = true;
			}
			updateTag[bpu.from] = UpdateTarget(gff, bpu.policy);
		}
		else{
			immutable tag = gff["Tag"].as!(GffType.ExoString);
			if(tag in updateTag){
				stderr.writeln("\x1b[1;31mERROR: Tag '"~tag~"' already registered. Cannot add blueprint '"~bpu.blueprint~".uti'\x1b[m");
				errored = true;
			}
			updateTag[tag] = UpdateTarget(gff, bpu.policy);
		}
	}
	enforce(!errored, "There was some update errors");

	enforce(updateResref.length>0 || updateTag.length>0,
		"Nothing to update. Use --update or --update-tag");






	StopWatch bench;
	size_t updatedCount;
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

	if(dryRun == false){
		if(temp.exists){
			if(alwaysAccept == false && !temp.dirEntries(SpanMode.shallow).empty){
				stderr.writeln("\x1b[1;31mWARNING: '", temp, "' is not empty and may contain backups from previous item updates\x1b[m");
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
			uint refund = 0;
			int[string] updatedItemStats;

			auto character = new Gff(cast(ubyte[])charFile.read);

			int charLevel;
			foreach(ref c ; character["ClassList"].as!(GffType.List)){
				charLevel += c["ClassLevel"].as!(GffType.Short);
			}
			auto maxItemValue = nwn.nwscript.resources.getTwoDA("itemvalue").get("MAXSINGLEITEMVALUE", charLevel - 1).to!int - 1;


			bool updateSingleItem(string UpdateMethod)(ref GffNode item, in UpdateTarget target){
				static if(UpdateMethod=="tag")
					auto identifier = item["Tag"].to!string;
				else static if(UpdateMethod=="resref")
					auto identifier = item["TemplateResRef"].to!string;
				else static assert(0);


				if(auto cnt = identifier in updatedItemStats)
					(*cnt)++;
				else
					updatedItemStats[identifier] = 1;

				charUpdated = true;
				auto update = item.updateItem(target.gff, target.policy, charFile.relativePath(vault), tlkresolv);

				refund += update.refund;
				item = update.item;
				updatedCount++;
				return update.enchanted;
			}

			void updateInventory(ref GffNode container){
				assert("ItemList" in container.as!(GffType.Struct));

				foreach(ref item ; container["ItemList"].as!(GffType.List)){
					if(auto target = item["TemplateResRef"].to!string in updateResref){
						updateSingleItem!"resref"(item, *target);
					}
					else if(auto target = item["Tag"].to!string in updateTag){
						updateSingleItem!"tag"(item, *target);
					}

					if("ItemList" in item.as!(GffType.Struct)){
						updateInventory(item);
					}
				}

				if("Equip_ItemList" in container.as!(GffType.Struct)){
					bool[size_t] itemsToRemove;
					foreach(ref item ; container["Equip_ItemList"].as!(GffType.List)){
						bool u = false;
						bool enchantedBack = false;
						if(auto target = item["TemplateResRef"].to!string in updateResref){
							enchantedBack = updateSingleItem!"resref"(item, *target);
							u=true;
						}
						else if(auto target = item["Tag"].to!string in updateTag){
							enchantedBack = updateSingleItem!"tag"(item, *target);
							u=true;
						}

						if(u){
							auto newPrice = item["Cost"].to!long + item["ModifyCost"].to!long;
							if(newPrice > maxItemValue || enchantedBack){
								if(container["ItemList"].as!(GffType.List).length < 128){
									itemsToRemove[item.structType] = true;
									container["ItemList"].as!(GffType.List) ~= item.dup;
								}
								else{
									stderr.writefln(
										"\x1b[1;31mWARNING: %s has '%s' equipped and no room in inventory to unequip it."
										~" The character will be refused on login for having an item too powerful for his level (item price=%d > %d, char level=%d).\x1b[m",
										charPathRelative, item["TemplateResRef"].to!string,
										newPrice, maxItemValue, charLevel,
										);
								}
							}
						}
					}

					//container["Equip_ItemList"].as!(GffType.List).remove!(a=>(a.structType in itemsToRemove) !is null);

					foreach_reverse(i, ref item ; container["Equip_ItemList"].as!(GffType.List)){
						if(item.structType in itemsToRemove){
							immutable l = container["Equip_ItemList"].as!(GffType.List).length;
							container["Equip_ItemList"].as!(GffType.List) =
								container["Equip_ItemList"].as!(GffType.List)[0..i]
								~ (i+1<l? container["Equip_ItemList"].as!(GffType.List)[i+1..$] : null);
						}
					}
				}
			}

			updateInventory(character);

			if(charUpdated){
				//Apply refund
				character["Gold"].as!(GffType.DWord) += refund;

				//copy backup
				auto backupFile = buildPath(temp, "backup_vault", charPathRelative);
				if(!buildNormalizedPath(backupFile, "..").exists)
					buildNormalizedPath(backupFile, "..").mkdirRecurse;
				charFile.copy(backupFile);

				//serialize current
				auto serializedChar = character.serialize;
				if(dryRun == false){
					auto tmpFile = buildPath(temp, "updated_vault", charPathRelative);
					if(!buildNormalizedPath(tmpFile, "..").exists)
						buildNormalizedPath(tmpFile, "..").mkdirRecurse;
					tmpFile.writeFile(serializedChar);
				}

				//message
				write(charPathRelative.leftJustify(35));
				foreach(k,v ; updatedItemStats)
					write(" ",k,"(x",v,")");
				if(refund>0)
					write(" + Refund of ",refund,"gp");
				writeln();
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
			auto connLoop = connPool.lockConnection();
			static if(type == "coffreibee")
				auto res = connLoop.query("SELECT id, item_name, account_name, item_data FROM coffreibee");
			else static if(type == "casieribee")
				auto res = connLoop.query("SELECT id, item_name, vendor_account_name, item_data FROM casieribee WHERE active=1");
			else static assert(0);

			foreach(row ; res.array){
				auto id = row[0].get!long;
				auto itemName = row[1].get!string;
				auto owner = row[2].get!string;
				auto itemData = row[3].get!(ubyte[]);
				auto item = new Gff(itemData);

				auto target = item["TemplateResRef"].to!string in updateResref;
				if(!target) target = item["Tag"].to!string in updateTag;

				if(target){
					auto update = item.updateItem(target.gff, target.policy, type~"["~id.to!string~"]", tlkresolv);
					updatedCount++;

					item.root = update.item;
					ubyte[] updatedData = item.serialize();

					if(itemData == updatedData){
						writeln("\x1b[1;31mWARNING: Item id=", id, " (resref=", target.gff["TemplateResRef"].to!string, ") did not change after update\x1b[m");
					}
					else if(dryRun == false){
						bool firstUpdate = itemName.indexOf("<b><c=red>MAJ</c></b>") == -1;

						auto conn = connPool.lockConnection();

						//Update item data
						static if(type == "coffreibee"){
							//Item will be updated and name will be changed
							auto affectedRows = conn.exec(
								"UPDATE coffreibee SET"
									~ (firstUpdate? " item_name=CONCAT('<b><c=red>MAJ</c></b> ',item_name)," : null)
									~ (firstUpdate? " item_description=CONCAT('<b><c=red>Cet objet a été mis à jour et ne correspond plus à la description.\\nVeuillez retirer et re-déposer l\\'objet pour le mettre à jour\\n\\n</c></b>',item_description)," : null)
									~" item_data=?"
								~" WHERE id=?",
								updatedData, id,
							);
						}
						else static if(type == "casieribee"){
							//Item will be updated and marked as forbidden to sell (do not appear in list) and can be retrieved by the owner
							auto affectedRows = conn.exec(
								"UPDATE casieribee SET"
									~ (firstUpdate? " item_name=CONCAT('<b><c=red>MAJ</c></b> ',item_name)," : null)
									~ (firstUpdate? " item_description=CONCAT('<b><c=red>Cet objet a été mis à jour et ne correspond plus à la description.\\nVeuillez retirer et re-déposer l\\'objet pour le mettre à jour\\n\\n</c></b>',item_description)," : null)
									~" sale_allowed=0,"
									~" item_data=?"
								~" WHERE id=?",
								updatedData, id,
							);
						}
						else static assert(0);

						enforce(affectedRows==1, "Wrong number of rows affected by SQL query: "~affectedRows.to!string~" rows affected for item ID="~id.to!string);

						if(update.refund > 0){
							//Apply refund in bank
							affectedRows = conn.exec(
								"UPDATE account SET ibee_bank=(ibee_bank+?) WHERE name=?",
								update.refund, owner,
							);
							enforce(affectedRows==1, "Wrong number of rows affected by SQL query");
						}

						static if(type == "coffreibee")
							buildPath(coffreIbeeBackup, id.to!string~".item.gff").writeFile(itemData);
						else static if(type == "casieribee")
							buildPath(casierIbeeBackup, id.to!string~".item.gff").writeFile(itemData);
						else static assert(0);
					}

					writeln(type~"[",id,"] ",update.item["Tag"].to!string," (Owner: ",owner,")", update.refund>0? " + refund "~update.refund.to!string~" gp sent in bank" : "");
					stdout.flush();
				}


			}
		}

		//COFFREIBEE
		bench.reset;
		bench.start;
		UpdateSQL!"coffreibee";
		writeln("-----");
		//CASIERIBEE
		UpdateSQL!"casieribee";
		bench.stop;

		writeln(">>> ",bench.peek.total!"msecs"/1000.0," seconds");
	}


	writeln();
	writeln("".center(80, '='));
	writeln("  INSTALLATION  ".center(80, '|'));
	writeln("".center(80, '='));
	writefln("All items have been updated (%d)", updatedCount);
	writeln("- new character files have been put in ", buildPath(temp, "updated_vault"));
	writeln("- new items in database are pending for SQL commit");
	writeln();


	char ans;
	if(alwaysAccept==false && dryRun == false){
		do{
			write("'y' to apply changes, 'n' to discard them: ");
			stdout.flush();
			ans = readln()[0];
		} while(ans!='y' && ans !='n');
	}
	else
		ans = 'y';

	if(ans=='y' && dryRun == false){
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


	//SQL rollback
	if(!skipSql && dryRun == false){
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


///
auto updateItem(in GffNode oldItem, in GffNode blueprint, in ItemPolicy itemPolicy, lazy string ownerName, in StrRefResolver tlkresolv){
	GffNode updatedItem = blueprint.dup;
	updatedItem.structType = 0;

	//Remove blueprint props
	updatedItem.as!(GffType.Struct).remove("Comment");
	updatedItem.as!(GffType.Struct).remove("Classification");
	updatedItem.as!(GffType.Struct).remove("ItemCastsShadow");
	updatedItem.as!(GffType.Struct).remove("ItemRcvShadow");
	updatedItem.as!(GffType.Struct).remove("UVScroll");

	static void copyPropertyIfPresent(in GffNode oldItem, ref GffNode updatedItem, string property){
		if(auto node = property in oldItem.as!(GffType.Struct))
			updatedItem.appendField(node.dup);
	}

	//Add instance & inventory props

	copyPropertyIfPresent(oldItem, updatedItem, "ObjectId");
	copyPropertyIfPresent(oldItem, updatedItem, "Repos_Index");
	copyPropertyIfPresent(oldItem, updatedItem, "ActionList");
	copyPropertyIfPresent(oldItem, updatedItem, "DisplayName");//TODO: see if value is copied from name
	copyPropertyIfPresent(oldItem, updatedItem, "EffectList");
	if("LastName" in oldItem.as!(GffType.Struct)){
		if("LastName" !in updatedItem.as!(GffType.Struct))
			updatedItem.appendField(GffNode(GffType.ExoLocString, "LastName", GffExoLocString(0, [0:""])));
	}
	copyPropertyIfPresent(oldItem, updatedItem, "XOrientation");
	copyPropertyIfPresent(oldItem, updatedItem, "XPosition");
	copyPropertyIfPresent(oldItem, updatedItem, "YOrientation");
	copyPropertyIfPresent(oldItem, updatedItem, "YPosition");
	copyPropertyIfPresent(oldItem, updatedItem, "ZOrientation");
	copyPropertyIfPresent(oldItem, updatedItem, "ZPosition");

	// Keep cursed flag by default
	copyPropertyIfPresent(oldItem, updatedItem, "Cursed");

	//Set instance properties that must persist through updates
	//updatedItem["Dropable"] = oldItem["Dropable"].dup;
	updatedItem["StackSize"] = oldItem["StackSize"].dup;
	if("ItemList" in oldItem.as!(GffType.Struct)){
		enforce(blueprint["BaseItem"].to!int == 66,
			"Updating an container (bag) by removing its container ability would remove all its content"
			~" ("~oldItem["Tag"].to!string~" => "~blueprint["TemplateResRef"].to!string~")");
		//The item is a container (bag)
		updatedItem["ItemList"] = oldItem["ItemList"].dup;
	}
	updatedItem.structType = oldItem.structType;

	//Fix nwn2 oddities
	updatedItem["ArmorRulesType"] = GffNode(GffType.Int, "ArmorRulesType", blueprint["ArmorRulesType"].as!(GffType.Byte));
	if(updatedItem["Plot"].as!(GffType.Byte) > 0)
		updatedItem["Cost"].as!(GffType.DWord) = 0;

	foreach(ref prop ; updatedItem["PropertiesList"].as!(GffType.List)){
		prop.as!(GffType.Struct).remove("Param2");
		prop.as!(GffType.Struct).remove("Param2Value");
		prop["UsesPerDay"] = GffNode(GffType.Byte, "UsesPerDay", 255);
		prop["Useable"] = GffNode(GffType.Byte, "Useable", 1);
	}


	//Copy local variables
	size_t[string] varsInUpdatedItem;
	foreach(i, ref var ; updatedItem["VarTable"].as!(GffType.List))
		varsInUpdatedItem[var["Name"].as!(GffType.ExoString)] = i;

	bool enchanted = false;
	bool enchantedBack = false;
	int enchantmentCost = false;
	NWItemproperty enchIprp;
	foreach(ref oldItemVar ; oldItem["VarTable"].as!(GffType.List)){
		immutable name = oldItemVar["Name"].to!string;

		auto policy = UpdatePolicy.Keep;
		if(auto p = ("Var."~name) in itemPolicy)
			policy = *p;

		if(name.length >= 6 && name[0..6] == "hagbe_"){
			// Do not copy hagbe variables
			// They will be added later with EnchantItem
			switch(name){
				case "hagbe_ench":    enchanted          = oldItemVar["Value"].to!bool; break;
				case "hagbe_iprp_t":  enchIprp.type      = cast(uint16_t)oldItemVar["Value"].as!(GffType.Int); break;
				case "hagbe_iprp_st": enchIprp.subType   = cast(uint16_t)oldItemVar["Value"].as!(GffType.Int); break;
				case "hagbe_iprp_c":  enchIprp.costValue = cast(uint16_t)oldItemVar["Value"].as!(GffType.Int); break;
				case "hagbe_iprp_p1": enchIprp.p1        = cast(uint8_t) oldItemVar["Value"].as!(GffType.Int); break;
				case "hagbe_cost":    enchantmentCost    = oldItemVar["Value"].as!(GffType.Int); break;
				default: throw new Exception("Unknown hagbe var " ~ name);
			}
		}
		else if(auto idx = name in varsInUpdatedItem){
			//Var is in updatedItem (inherited from blueprint)
			//Set var using policy
			if(policy == UpdatePolicy.Keep){
				//Copy old item var to updated item
				updatedItem["VarTable"][*idx] = oldItemVar.dup;
			}
			else{
				//keep the var inherited from blueprint
			}
		}
		else{
			//Var not found in blueprint
			//Append var
			if(policy == UpdatePolicy.Keep){
				//Add oldvar to updated item
				varsInUpdatedItem[name] = updatedItem["VarTable"].as!(GffType.List).length;
				updatedItem["VarTable"].as!(GffType.List) ~= oldItemVar.dup;
			}
			else{
				//Do not add oldvar to updated item
			}
		}
	}

	//Property policy
	foreach(propName, policy ; itemPolicy){
		if(propName.length<4 || propName[0..4]!="Var."){
			//policy is for a property
			auto propOld = propName in oldItem.as!(GffType.Struct);
			auto propUpd = propName in updatedItem.as!(GffType.Struct);
			enforce(propOld && propUpd, "Property '"~propName~"' does not exist in both instance and blueprint, impossible to enforce policy.");
			if(policy == UpdatePolicy.Keep){
				*propUpd = propOld.dup;
			}
		}
	}

	//Enchantment
	int refund = 0;
	if(enchanted){

		if(enchIprp.type == enchIprp.type.max){
			// Invalid enchantment
			stderr.writefln("\x1b[1;31mWARNING: %s:%s: Invalid IPRP\x1b[m",
				ownerName, updatedItem["TemplateResRef"].to!string,
			);
			stderr.writeln("\x1b[1;31m", updatedItem["VarTable"].toPrettyString, "\x1b[m");
		}
		else{
			auto res = EnchantItem(updatedItem.as!(GffType.Struct), enchIprp, enchantmentCost);
			if(!res){
				stderr.writeln("\x1b[1;31mWARNING: ",ownerName,":",updatedItem["TemplateResRef"].to!string,": cannot re-enchant with "~enchIprp.toPrettyString~" - Enchantment refunded\x1b[m");

				//Refund enchantment
				refund = enchantmentCost;
			}
			else{
				enchantedBack = true;
			}
		}
	}

	return Tuple!(GffNode,"item", int,"refund", bool,"enchanted")(updatedItem, refund, enchantedBack);
}

void removeEnchantment(ref GffNode item){
	//Remove enchantment variables

	item["VarTable"].as!(GffType.List) = item["VarTable"].as!(GffType.List).remove!((ref var){
		switch(var["Name"].to!string){
			case "DEJA_ENCHANTE":
			case "X2_LAST_PROPERTY":
			case "hagbe_ench":
			case "hagbe_iprp_t":
			case "hagbe_iprp_st":
			case "hagbe_iprp_c":
			case "hagbe_iprp_p1":
			case "hagbe_cost":
				return true;
			default: return false;
		}
	});
}