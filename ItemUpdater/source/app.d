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
import std.datetime: StopWatch;
import std.parallelism;
import core.thread;
import mysql.connection;
import nwn.gff;
import nwn.twoda;

import lcda.config;
import lcda.hagbe;
import lcda.compat.lib_forge_epique;



enum UpdatePolicy{
	Override = 0,
	Keep = 1,
}

alias ItemPolicy = UpdatePolicy[string];
ItemPolicy[string] updatePolicy;

//--update 'item_resref=>item_blueprint("Cursed":Keep, "Var.bIntelligent=Override")'
//--update-tag 'item_resref=>item_blueprint("Cursed":Keep, "Var.bIntelligent=Override")'

int main(string[] args){
	string vaultOvr;
	string tempOvr;
	bool noninteractive = false;
	uint parallelJobs = 1;
	bool skipVault = false;
	bool skipSql = false;

	alias BlueprintUpdateDef = Tuple!(string,"from", string,"blueprint", UpdatePolicy[string],"policy");
	BlueprintUpdateDef[] resrefupdateDef;
	BlueprintUpdateDef[] tagupdateDef;


	//Parse cmd line
	try{
		void parseUpdateArg(string param, string arg){
			import std.regex: ctRegex, matchFirst;
			enum rgx = ctRegex!r"^(?:(.+)=)?(.+?)(?:\(([^\(]*)\))?$";

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
	immutable vault = vaultOvr !is null? vaultOvr : buildPath(LcdaConfig["path_nwn2docs"], "servervault");
	enforce(vault.exists && vault.isDir, "Vault is not a directory/does not exist");
	immutable temp = tempOvr !is null? tempOvr : buildPath(LcdaConfig["path_nwn2docs"], "itemupdater_tmp");


	alias UpdateTarget = Tuple!(Gff,"gff", ItemPolicy,"policy");
	UpdateTarget[string] updateResref;
	UpdateTarget[string] updateTag;

	foreach(ref bpu ; resrefupdateDef){
		auto bpPath = bpu.blueprint.extension is null?
			buildPath(LcdaConfig["path_lcdadev"], bpu.blueprint~".uti") : bpu.blueprint;
		auto gff = new Gff(bpPath);

		if(bpu.from !is null && bpu.from.length>0){
			enforce(bpu.from !in updateResref,
				"Template resref '"~bpu.from~"' already registered. Cannot add blueprint '"~bpu.blueprint~"'");
			updateResref[bpu.from] = UpdateTarget(gff, bpu.policy);
		}
		else{
			immutable tplResref = gff["TemplateResRef"].as!(GffType.ResRef);
			enforce(tplResref !in updateResref,
				"Template resref '"~tplResref~"' already registered. Cannot add blueprint '"~bpu.blueprint~"'");
			updateResref[tplResref] = UpdateTarget(gff, bpu.policy);
		}
	}
	foreach(ref bpu ; tagupdateDef){
		auto bpPath = bpu.blueprint.extension is null?
			buildPath(LcdaConfig["path_lcdadev"], bpu.blueprint~".uti") : bpu.blueprint;
		auto gff = new Gff(bpPath);

		if(bpu.from !is null && bpu.from.length>0){
			enforce(bpu.from !in updateTag,
				"Tag '"~bpu.from~"' already registered. Cannot add blueprint '"~bpu.blueprint~"'");
			updateTag[bpu.from] = UpdateTarget(gff, bpu.policy);
		}
		else{
			immutable tag = gff["Tag"].as!(GffType.ResRef);
			enforce(tag !in updateTag,
				"Tag '"~tag~"' already registered. Cannot add blueprint '"~bpu.blueprint~"'");
			updateTag[tag] = UpdateTarget(gff, bpu.policy);
		}
	}

	enforce(updateResref.length>0 || updateTag.length>0,
		"Nothing to update. Use --update or --update-tag");






	StopWatch bench;
	auto taskPool = new TaskPool(parallelJobs-1);
	scope(exit) taskPool.finish;
	auto conn = skipSql? null : new Connection(
		LcdaConfig["sql_address"],
		LcdaConfig["sql_user"],
		LcdaConfig["sql_password"],
		LcdaConfig["sql_schema"]);
	scope(exit){
		if(!skipSql)
			conn.close();
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

			void updateSingleItem(string UpdateMethod)(ref GffNode item, in UpdateTarget target){
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
				auto update = item.updateItem(target.gff, target.policy, charFile.relativePath(vault));

				refund += update.refund;
				item = update.item;
			}

			void updateInventory(ref GffNode container){
				assert("ItemList" in container.as!(GffType.Struct));

				foreach(ref item ; container["ItemList"].as!GffList){
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
					foreach(ref item ; container["Equip_ItemList"].as!GffList){

						bool u = false;
						if(auto target = item["TemplateResRef"].to!string in updateResref){
							updateSingleItem!"resref"(item, *target);
							u=true;
						}
						else if(auto target = item["Tag"].to!string in updateTag){
							updateSingleItem!"tag"(item, *target);
							u=true;
						}

						if(u){
							if(container["ItemList"].as!GffList.length < 128){
								itemsToRemove[item.structType] = true;
								container["ItemList"].as!GffList ~= item.dup;
							}
							else{
								stderr.writeln(
									"\x1b[1;31mWARNING: ",charPathRelative," has '",item["Tag"].to!string,"' equipped and no room in inventory to unequip it.",
									" The character may be refused on login for having an item too powerful for his level.\x1b[m");
							}
						}
					}

					//container["Equip_ItemList"].as!GffList.remove!(a=>(a.structType in itemsToRemove) !is null);

					foreach_reverse(i, ref item ; container["Equip_ItemList"].as!GffList){
						if(item.structType in itemsToRemove){
							immutable l = container["Equip_ItemList"].as!GffList.length;
							container["Equip_ItemList"].as!GffList =
								container["Equip_ItemList"].as!GffList[0..i]
								~ (i+1<l? container["Equip_ItemList"].as!GffList[i+1..$] : null);
						}
					}
				}
			}

			auto character = new Gff(cast(ubyte[])charFile.read);
			updateInventory(character);

			if(charUpdated){
				//Apply refund
				character["Gold"].as!GffDWord += refund;

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
		writeln(">>> ",bench.peek.msecs/1000.0," seconds");
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

		Command(conn, "SET autocommit=0").execSQL;
		ulong affectedRows;

		void refundInBank(string account, int amount){
			auto cmdRefund = Command(conn, "UPDATE account SET ibee_bank=(ibee_bank+?) WHERE name=?");
			cmdRefund.prepare;
			cmdRefund.bindParameterTuple(amount, account);
			cmdRefund.execPrepared(affectedRows);
			enforce(affectedRows==1, "Wrong number of rows affected by SQL query");
		}

		//COFFREIBEE
		bench.reset;
		bench.start;
		auto res = Command(conn, "SELECT id, item_name, account_name, item_data FROM coffreibee").execSQLResult;
		foreach(row ; res){
			auto id = row[0].get!long;
			auto itemName = row[1].get!string;
			auto owner = row[2].get!string;
			auto itemData = row[3].get!(ubyte[]);
			auto item = new Gff(itemData);

			auto target = item["TemplateResRef"].to!string in updateResref;
			if(!target) target = item["Tag"].to!string in updateTag;

			if(target){
				//Item will be updated and name will be changed
				auto update = item.updateItem(target.gff, target.policy, "coffreibee["~id.to!string~"]");

				item.root = update.item;
				ubyte[] updatedData = item.serialize();

				if(itemData == updatedData){
					writeln("\x1b[1;31mWARNING: Item id=", id, " (resref=", target.gff["TemplateResRef"].to!string, ") did not change after update\x1b[m");
				}
				else{
					bool firstUpdate = itemName.indexOf("<b><c=red>MAJ</c></b>")==-1;

					//Update item data
					auto cmdUpdate = Command(conn,
							"UPDATE coffreibee SET"
								~ (firstUpdate? " item_name=CONCAT('<b><c=red>MAJ</c></b> ',item_name)," : null)
								~ (firstUpdate? " item_description=CONCAT('<b><c=red>Cet objet a été mis à jour et ne correspond plus à la description.\\nVeuillez retirer et re-déposer l\\'objet pour le mettre à jour\\n\\n</c></b>',item_description)," : null)
								~" item_data=?"
							~" WHERE id=?");
					cmdUpdate.prepare;
					cmdUpdate.bindParameterTuple(updatedData, id);
					cmdUpdate.execPrepared(affectedRows);
					enforce(affectedRows==1, "Wrong number of rows affected by SQL query: "~affectedRows.to!string~" rows affected for item ID="~id.to!string);

					if(update.refund > 0){
						//Apply refund in bank
						refundInBank(owner, update.refund);
					}

					buildPath(coffreIbeeBackup, id.to!string~".item.gff").writeFile(itemData);
				}


				writeln("coffreibee[",id,"] ",update.item["Tag"].to!string," (Owner: ",owner,")", update.refund>0? " + refund "~update.refund.to!string~" gp sent in bank" : "");
				stdout.flush();
			}


		}
		writeln("-----");
		//CASIERIBEE
		res = Command(conn, "SELECT id, item_name, vendor_account_name, item_data FROM casieribee WHERE active=1").execSQLResult;
		foreach(row ; res){
			auto id = row[0].get!long;
			auto itemName = row[1].get!string;
			auto owner = row[2].get!string;
			auto itemData = row[3].get!(ubyte[]);
			auto item = new Gff(itemData);

			auto target = item["TemplateResRef"].to!string in updateResref;
			if(!target) target = item["Tag"].to!string in updateTag;

			if(target){
				//Item will be updated and marked as sold with price = 0gp
				auto update = item.updateItem(target.gff, target.policy, "casieribee["~id.to!string~"]");

				item.root = update.item;
				ubyte[] updatedData = item.serialize();

				if(itemData == updatedData){
					writeln("\x1b[1;31mWARNING: Item id=", id, " (resref=", target.gff["TemplateResRef"].to!string, ") did not change after update\x1b[m");
				}
				else{
					bool firstUpdate = itemName.indexOf("<b><c=red>MAJ</c></b>")==-1;

					//Update item data
					auto cmdUpdate = Command(conn,
							"UPDATE casieribee SET"
								~ (firstUpdate? " item_name=CONCAT('<b><c=red>MAJ</c></b> ',item_name)," : null)
								~ (firstUpdate? " item_description=CONCAT('<b><c=red>Cet objet a été mis à jour et ne correspond plus à la description.\\nVeuillez retirer et re-déposer l\\'objet pour le mettre à jour\\n\\n</c></b>',item_description)," : null)
								~" sale_allowed=0,"
								~" item_data=?"
							~" WHERE id=?");
					cmdUpdate.prepare;
					cmdUpdate.bindParameterTuple(updatedData, id);
					cmdUpdate.execPrepared(affectedRows);
					enforce(affectedRows==1, "Wrong number of rows affected by SQL query: "~affectedRows.to!string~" rows affected for item ID="~id.to!string);

					if(update.refund > 0){
						//Apply refund in bank
						refundInBank(owner, update.refund);
					}

					buildPath(casierIbeeBackup, id.to!string~".item.gff").writeFile(itemData);
				}

				writeln("casieribee[",id,"] ",update.item["Tag"].to!string," (Owner: ",owner,")", update.refund>0? " + refund "~update.refund.to!string~" gp sent in bank" : "");
				stdout.flush();
			}


		}
		bench.stop;
		writeln(">>> ",bench.peek.msecs/1000.0," seconds");
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
							copyRecurse(child.name, buildPath(to, child.baseName));
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
				Command(conn, "COMMIT").execSQL;
				writeln("SQL work commited");
				stdout.flush();
			}

			writeln("  DONE !  ".center(80, '_'));

			return 0;
		}
	}


	//SQL rollback
	if(!skipSql)
		Command(conn, "ROLLBACK").execSQL;


	return 0;
}


///
auto updateItem(in GffNode oldItem, in GffNode blueprint, in ItemPolicy itemPolicy, lazy string ownerName){
	bool enchanted = false;
	EnchantmentId enchantment;

	GffNode updatedItem = blueprint.dup;
	updatedItem.structType = 0;

	//Remove blueprint props
	updatedItem.as!GffStruct.remove("Comment");
	updatedItem.as!GffStruct.remove("Classification");
	updatedItem.as!GffStruct.remove("ItemCastsShadow");
	updatedItem.as!GffStruct.remove("ItemRcvShadow");
	updatedItem.as!GffStruct.remove("UVScroll");

	void copyPropertyIfPresent(in GffNode oldItem, ref GffNode updatedItem, string property){
		if(auto node = property in oldItem.as!GffStruct)
			updatedItem.appendField(node.dup);
	}

	//Add instance & inventory props

	copyPropertyIfPresent(oldItem, updatedItem, "ObjectId");
	copyPropertyIfPresent(oldItem, updatedItem, "Repos_Index");
	copyPropertyIfPresent(oldItem, updatedItem, "ActionList");
	copyPropertyIfPresent(oldItem, updatedItem, "DisplayName");//TODO: see if value is copied from name
	copyPropertyIfPresent(oldItem, updatedItem, "EffectList");
	if("LastName" in oldItem.as!GffStruct){
		if("LastName" !in updatedItem.as!GffStruct)
			updatedItem.appendField(GffNode(GffType.ExoLocString, "LastName", GffExoLocString(0, [0:""])));
	}
	copyPropertyIfPresent(oldItem, updatedItem, "XOrientation");
	copyPropertyIfPresent(oldItem, updatedItem, "XPosition");
	copyPropertyIfPresent(oldItem, updatedItem, "YOrientation");
	copyPropertyIfPresent(oldItem, updatedItem, "YPosition");
	copyPropertyIfPresent(oldItem, updatedItem, "ZOrientation");
	copyPropertyIfPresent(oldItem, updatedItem, "ZPosition");

	//Set instance properties that must persist through updates
	//updatedItem["Dropable"] = oldItem["Dropable"].dup;
	updatedItem["StackSize"] = oldItem["StackSize"].dup;
	if("ItemList" in oldItem.as!GffStruct){
		enforce(blueprint["BaseItem"].to!int == 66,
			"Updating an container (bag) by removing its container ability would remove all its content"
			~" ("~oldItem["Tag"].to!string~" => "~blueprint["TemplateResRef"].to!string~")");
		//The item is a container (bag)
		updatedItem["ItemList"] = oldItem["ItemList"].dup;
	}
	updatedItem.structType = oldItem.structType;

	//Fix nwn2 oddities
	updatedItem["ArmorRulesType"] = GffNode(GffType.Int, "ArmorRulesType", blueprint["ArmorRulesType"].as!GffByte);
	updatedItem["Cost"].as!GffDWord = 0;
	foreach(ref prop ; updatedItem["PropertiesList"].as!GffList){
		prop.as!GffStruct.remove("Param2");
		prop.as!GffStruct.remove("Param2Value");
		prop["UsesPerDay"] = GffNode(GffType.Byte, "UsesPerDay", 255);
		prop["Useable"] = GffNode(GffType.Byte, "Useable", 1);
	}


	//Copy local variables
	size_t[string] varsInUpdatedItem;
	foreach(i, ref var ; updatedItem["VarTable"].as!GffList)
		varsInUpdatedItem[var["Name"].as!GffExoString] = i;

	foreach(ref oldItemVar ; oldItem["VarTable"].as!GffList){
		immutable name = oldItemVar["Name"].to!string;

		auto policy = UpdatePolicy.Keep;
		if(auto p = ("Var."~name) in itemPolicy)
			policy = *p;


		if(name=="DEJA_ENCHANTE")
			enchanted   = oldItemVar["Value"].to!bool;
		else if(name=="X2_LAST_PROPERTY"){
			auto val = oldItemVar["Value"].as!GffInt;
			if(val>0)
				enchantment = val.to!EnchantmentId;
		}

		if(auto idx = name in varsInUpdatedItem){
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
				varsInUpdatedItem[name] = updatedItem["VarTable"].as!GffList.length;
				updatedItem["VarTable"].as!GffList ~= oldItemVar.dup;
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
			auto propOld = propName in oldItem.as!GffStruct;
			auto propUpd = propName in updatedItem.as!GffStruct;
			enforce(propOld && propUpd, "Property '"~propName~"' does not exist in both instance and blueprint, impossible to enforce policy.");
			if(policy == UpdatePolicy.Keep){
				*propUpd = propOld.dup;
			}
		}
	}

	//Enchantment
	int refund = 0;
	if(enchanted){
		enforce(enchantment>0, "Wrong enchantment ID: "~enchantment.to!string);

		try updatedItem.enchantItem(enchantment);
		catch(EnchantmentException e){
			stderr.writeln("\x1b[1;31mWARNING: ",ownerName,":",updatedItem["Tag"].to!string,": ",e.msg, " - Enchantment refunded\x1b[m");

			//Refund enchantment
			refund = PrixDuService(enchantment);
			assert(refund != 0);


			//Remove enchantment variables
			foreach_reverse(i, ref var ; updatedItem["VarTable"].as!GffList){
				if(var["Name"].to!string=="DEJA_ENCHANTE" || var["Name"].to!string=="X2_LAST_PROPERTY"){
					immutable l = updatedItem["VarTable"].as!GffList.length;
					updatedItem["VarTable"].as!GffList =
						updatedItem["VarTable"].as!GffList[0..i]
						~ (i+1<l? updatedItem["VarTable"].as!GffList[i+1..$] : null);
				}
			}
		}
	}

	return Tuple!(GffNode,"item", int,"refund")(updatedItem, refund);
}