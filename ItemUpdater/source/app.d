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

import lcdaconfig;
import lib_forge_epique;


auto ref TwoDA getTwoDA(in string name){
	static __gshared TwoDA[string] twoDACache;

	immutable n = name.toLower;
	synchronized{
		if(auto ret = n in twoDACache)
			return *ret;
		return twoDACache[n] = new TwoDA(buildPath(LcdaConfig["path_lcdaclientsrc"],"lcda2da.hak",n~".2da"));
	}
}

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
			auto itemName = row[1].get!(string[]);
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
				enforce(affectedRows==1, "Wrong number of rows affected by SQL query");

				if(update.refund > 0){
					//Apply refund in bank
					refundInBank(owner, update.refund);
				}

				buildPath(coffreIbeeBackup, id.to!string~".item.gff").writeFile(itemData);

				writeln("coffreibee[",id,"] ",update.item["Tag"].to!string," (Owner: ",owner,")", update.refund>0? " + refund "~update.refund.to!string~" gp sent in bank" : "");
				stdout.flush();
			}


		}
		writeln("-----");
		//CASIERIBEE
		res = Command(conn, "SELECT id, vendor_account_name, item_data FROM casieribee WHERE active=1").execSQLResult;
		foreach(row ; res){
			auto id = row[0].get!long;
			auto owner = row[1].get!string;
			auto itemData = row[2].get!(ubyte[]);
			auto item = new Gff(itemData);

			auto target = item["TemplateResRef"].to!string in updateResref;
			if(!target) target = item["Tag"].to!string in updateTag;

			if(target){
				//Item will be updated and marked as sold with price = 0gp
				auto update = item.updateItem(target.gff, target.policy, "casieribee["~id.to!string~"]");

				item.root = update.item;
				ubyte[] updatedData = item.serialize();

				//Update item data
				auto cmdUpdate = Command(conn,
						"UPDATE casieribee SET"
							~" item_name=CONCAT('<b><c=red>MAJ</c></b> ',item_name),"
							~" item_description=CONCAT('<b><c=red>Cet objet a été mis à jour et ne correspond plus à la description.\\nVeuillez retirer et re-déposer l\\'objet pour le mettre à jour\\n\\n</c></b>',item_description),"
							~" sale_allowed=0,"
							~" item_data=?"
						~" WHERE id=?");
				cmdUpdate.prepare;
				cmdUpdate.bindParameterTuple(updatedData, id);
				cmdUpdate.execPrepared(affectedRows);
				enforce(affectedRows==1, "Wrong number of rows affected by SQL query");

				if(update.refund > 0){
					//Apply refund in bank
					refundInBank(owner, update.refund);
				}

				buildPath(casierIbeeBackup, id.to!string~".item.gff").writeFile(itemData);

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

	//Add instance & inventory props
	if("ObjectId" in oldItem.as!GffStruct)
		updatedItem.appendField(oldItem["ObjectId"].dup);
	if("Repos_Index" in oldItem.as!GffStruct)
		updatedItem.appendField(oldItem["Repos_Index"].dup);
	updatedItem.appendField(oldItem["ActionList"].dup);
	updatedItem.appendField(oldItem["DisplayName"].dup);//TODO: see value is copied from name
	if("EffectList" in oldItem.as!GffStruct)
		updatedItem.appendField(oldItem["EffectList"].dup);
	if("LastName" in oldItem.as!GffStruct){
		if("LastName" !in updatedItem.as!GffStruct)
			updatedItem.appendField(GffNode(GffType.ExoLocString, "LastName", GffExoLocString(0, [0:""])));
	}
	updatedItem.appendField(oldItem["XOrientation"].dup);
	updatedItem.appendField(oldItem["XPosition"].dup);
	updatedItem.appendField(oldItem["YOrientation"].dup);
	updatedItem.appendField(oldItem["YPosition"].dup);
	updatedItem.appendField(oldItem["ZOrientation"].dup);
	updatedItem.appendField(oldItem["ZPosition"].dup);

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

class EnchantmentException : Exception{
	@safe pure nothrow this(string msg, string f=__FILE__, size_t l=__LINE__, Throwable t=null){
		super(msg, f, l, t);
	}
}

void enchantItem(ref GffNode item, EnchantmentId enchantType){
	GffNode* findExistingProperty(in PropType propType){
		foreach(ref prop ; item["PropertiesList"].as!GffList){
			if(prop["PropertyName"].as!GffWord == propType.propertyName
				&& (propType.subType!=uint16_t.max? prop["Subtype"].as!GffWord==propType.subType : true))
				return &prop;
		}
		return null;
	}

	auto baseItemType = item["BaseItem"].to!uint;
	immutable propertyType = getPropertyType(baseItemType, enchantType);

	switch(propertyType.propertyName){

		case 16://dmg bonus
		case 26://DarkVision
		case 35://Haste
		case 37://Misc immunities (abs, fear, death)
		case 43://Keen
		case 61://Unlimited ammo
		case 71://TrueSeeing
		case 75://FreeAction
			//Add only if property does not exist (properties without CostValue)
			if(propertyType.propertyName!=16 && propertyType.propertyName!=61)
				assert(getTwoDA("itempropdef").get("CostTableResRef", propertyType.propertyName) is null,
					"Property "~propertyType.to!string~" has a cost value table and is handled as if there were none");

			enforce!EnchantmentException(findExistingProperty(propertyType) is null,
				"Enchantment "~propertyType.toString~" already exist on the updated version");

			item["PropertiesList"].as!GffList ~= buildPropertyUsing2DA(propertyType);
			return;

		default:
			//Merge by adding CostValue
			immutable costTableResref = getTwoDA("itempropdef").get("CostTableResRef", propertyType.propertyName);
			assert(costTableResref !is null,
				"Property "~propertyType.to!string~" has no cost value table and is handled as if there were one");

			if(auto prop = findExistingProperty(propertyType)){
				//merge with existing
				enforce!EnchantmentException(propertyType.propertyName != 39,//Spell resistance
					"Cannot merge "~propertyType.toString~" with existing property (not handled yet)");


				GffWord newCostValue, maxCostValue;
				if(propertyType.propertyName == 39){
					//Spell resistance
					//+10 SR => +5 index in 2da
					//max index: 15
					assert(propertyType.costValue==0);

					maxCostValue = 15;
					newCostValue = cast(GffWord)((*prop)["CostValue"].as!GffWord + 5);
				}
				else{
					immutable costValueTableIndex = getTwoDA("itempropdef").get("CostTableResRef", propertyType.propertyName);
					immutable costValueTable = getTwoDA("iprp_costtable").get("Name", costValueTableIndex.to!uint);

					maxCostValue = cast(GffWord)(getTwoDA(costValueTable).rows-1);
					newCostValue = cast(GffWord)((*prop)["CostValue"].as!GffWord + propertyType.costValue);
				}

				enforce!EnchantmentException(newCostValue <= maxCostValue,
					"Cannot merge enchantment "~propertyType.toString~": CostValue "~newCostValue.to!string~" is too high");

				(*prop)["CostValue"].as!GffWord = newCostValue;
			}
			else{
				//append
				item["PropertiesList"].as!GffList ~= buildPropertyUsing2DA(propertyType);
			}
			return;
	}
	assert(0);
}


struct PropType{
	uint32_t propertyName;
	uint32_t subType = uint16_t.max;
	uint32_t costValue = uint16_t.max;

	string toString() const{
		immutable propNameLabel = getTwoDA("itempropdef").get("Label", propertyName);

		immutable subTypeTable = getTwoDA("itempropdef").get("SubTypeResRef", propertyName);
		string subTypeLabel;
		try subTypeLabel = subTypeTable is null? null : getTwoDA(subTypeTable).get("Label", subType);
		catch(TwoDAColumnNotFoundException){
			subTypeLabel = subTypeTable is null? null : getTwoDA(subTypeTable).get("NameString", subType);
		}

		immutable costValueTableIndex = getTwoDA("itempropdef").get("CostTableResRef", propertyName);
		immutable costValueTable = costValueTableIndex is null? null : getTwoDA("iprp_costtable").get("Name", costValueTableIndex.to!uint);

		immutable costValueLabel = costValueTable is null? null : getTwoDA(costValueTable).get("Label", costValue);

		return propNameLabel
			~(subTypeLabel is null? null : "."~subTypeLabel)
			~(costValueLabel is null? null : "("~costValueLabel~")");
	}
}

PropType getPropertyType(uint baseItemType, EnchantmentId enchantType){
	//Indices are found in itempropdef.2da
	final switch(enchantType) with(EnchantmentId){
		case DAMAGETYPE_ACID:
		case DAMAGETYPE_FIRE:
		case DAMAGETYPE_COLD:
		case DAMAGETYPE_ELECTRICAL:
		case DAMAGETYPE_NEGATIVE:
		case DAMAGETYPE_POSITIVE:
		case DAMAGETYPE_DIVINE:                     return PropType(16, enchantType,  7);//7 is for 1d6
		case ARMOR_STRENGTH_BONUS2:                 return PropType(0,  0,            2);
		case ARMOR_DEXTERITY_BONUS2:                return PropType(0,  1,            2);
		case ARMOR_CONSTITUTION_BONUS2:             return PropType(0,  2,            2);
		case ARMOR_INTELLIGENCE_BONUS2:             return PropType(0,  3,            2);
		case ARMOR_WISDOM_BONUS2:                   return PropType(0,  4,            2);
		case ARMOR_CHARISMA_BONUS2:                 return PropType(0,  5,            2);
		case BRACERS_BELT_STRENGTH_BONUS2:          return PropType(0,  0,            2);
		case BRACERS_BELT_DEXTERITY_BONUS2:         return PropType(0,  1,            2);
		case BRACERS_BELT_CONSTITUTION_BONUS2:      return PropType(0,  2,            2);
		case BRACERS_BELT_INTELLIGENCE_BONUS2:      return PropType(0,  3,            2);
		case BRACERS_BELT_WISDOM_BONUS2:            return PropType(0,  4,            2);
		case BRACERS_BELT_CHARISMA_BONUS2:          return PropType(0,  5,            2);
		case HELM_STRENGTH_BONUS2:                  return PropType(0,  0,            2);
		case HELM_DEXTERITY_BONUS2:                 return PropType(0,  1,            2);
		case HELM_CONSTITUTION_BONUS2:              return PropType(0,  2,            2);
		case HELM_INTELLIGENCE_BONUS2:              return PropType(0,  3,            2);
		case HELM_WISDOM_BONUS2:                    return PropType(0,  4,            2);
		case HELM_CHARISMA_BONUS2:                  return PropType(0,  5,            2);
		case AMULET_STRENGTH_BONUS2:                return PropType(0,  0,            2);
		case AMULET_DEXTERITY_BONUS2:               return PropType(0,  1,            2);
		case AMULET_CONSTITUTION_BONUS2:            return PropType(0,  2,            2);
		case AMULET_INTELLIGENCE_BONUS2:            return PropType(0,  3,            2);
		case AMULET_WISDOM_BONUS2:                  return PropType(0,  4,            2);
		case AMULET_CHARISMA_BONUS2:                return PropType(0,  5,            2);
		case RING_STRENGTH_BONUS2:                  return PropType(0,  0,            2);
		case RING_DEXTERITY_BONUS2:                 return PropType(0,  1,            2);
		case RING_CONSTITUTION_BONUS2:              return PropType(0,  2,            2);
		case RING_INTELLIGENCE_BONUS2:              return PropType(0,  3,            2);
		case RING_WISDOM_BONUS2:                    return PropType(0,  4,            2);
		case RING_CHARISMA_BONUS2:                  return PropType(0,  5,            2);
		case BOOTS_STRENGTH_BONUS2:                 return PropType(0,  0,            2);
		case BOOTS_DEXTERITY_BONUS2:                return PropType(0,  1,            2);
		case BOOTS_CONSTITUTION_BONUS2:             return PropType(0,  2,            2);
		case BOOTS_INTELLIGENCE_BONUS2:             return PropType(0,  3,            2);
		case BOOTS_WISDOM_BONUS2:                   return PropType(0,  4,            2);
		case BOOTS_CHARISMA_BONUS2:                 return PropType(0,  5,            2);
		case CLOAK_STRENGTH_BONUS2:                 return PropType(0,  0,            2);
		case CLOAK_DEXTERITY_BONUS2:                return PropType(0,  1,            2);
		case CLOAK_CONSTITUTION_BONUS2:             return PropType(0,  2,            2);
		case CLOAK_INTELLIGENCE_BONUS2:             return PropType(0,  3,            2);
		case CLOAK_WISDOM_BONUS2:                   return PropType(0,  4,            2);
		case CLOAK_CHARISMA_BONUS2:                 return PropType(0,  5,            2);
		case SHIELD_STRENGTH_BONUS2:                return PropType(0,  0,            2);
		case SHIELD_DEXTERITY_BONUS2:               return PropType(0,  1,            2);
		case SHIELD_CONSTITUTION_BONUS2:            return PropType(0,  2,            2);
		case SHIELD_INTELLIGENCE_BONUS2:            return PropType(0,  3,            2);
		case SHIELD_WISDOM_BONUS2:                  return PropType(0,  4,            2);
		case SHIELD_CHARISMA_BONUS2:                return PropType(0,  5,            2);
		case ARMOR_BONUS_CA2:                       return PropType(1,  uint16_t.max, 2);
		case CLOAK_PARADE_BONUS2:                   return PropType(1,  uint16_t.max, 2);
		case BRACERS_BELT_CA_VS_BLUDGEONING_BONUS5: return PropType(3,  0,            5);
		case BRACERS_BELT_CA_VS_PIERCING_BONUS5:    return PropType(3,  1,            5);
		case BRACERS_BELT_CA_VS_SLASHING_BONUS5:    return PropType(3,  2,            5);
		case ENHANCEMENT_BONUS:                     return PropType(6,  uint16_t.max, 1);
		case HELM_DAMAGERESISTANCE5_BLUDGEONING:    return PropType(23, 0,            1);
		case HELM_DAMAGERESISTANCE5_PIERCING:       return PropType(23, 1,            1);
		case HELM_DAMAGERESISTANCE5_SLASHING:       return PropType(23, 2,            1);
		case HELM_DAMAGERESISTANCE5_MAGICAL:        return PropType(23, 5,            1);
		case HELM_DAMAGERESISTANCE5_ACID:           return PropType(23, 6,            1);
		case HELM_DAMAGERESISTANCE5_COLD:           return PropType(23, 7,            1);
		case HELM_DAMAGERESISTANCE5_DIVINE:         return PropType(23, 8,            1);
		case HELM_DAMAGERESISTANCE5_ELECTRICAL:     return PropType(23, 9,            1);
		case HELM_DAMAGERESISTANCE5_FIRE:           return PropType(23, 10,           1);
		case HELM_DAMAGERESISTANCE5_NEGATIVE:       return PropType(23, 11,           1);
		case HELM_DAMAGERESISTANCE5_POSITIVE:       return PropType(23, 12,           1);
		case HELM_DAMAGERESISTANCE5_SONIC:          return PropType(23, 13,           1);
		case BOOTS_DARKVISION:                      return PropType(26);
		case HASTE:                                 return PropType(35);
		case RING_IMMUNE_ABSORBTION:                return PropType(37, 1);
		case RING_IMMUNE_TERROR:                    return PropType(37, 5);
		case RING_IMMUNE_DEATH:                     return PropType(37, 9);
		case SPELLRESISTANCE:                       return PropType(39, uint16_t.max, 0);//+10
		case SHIELD_SPELLRESISTANCE10:              return PropType(39, uint16_t.max, 0);//+10
		case SHIELD_BONUS_VIG_PLUS7:                return PropType(41, 1,            7);
		case SHIELD_BONUS_VOL_PLUS7:                return PropType(41, 2,            7);
		case SHIELD_BONUS_REF_PLUS7:                return PropType(41, 3,            7);
		case KEEN:                                  return PropType(43);
		case MIGHTY_5:                              return PropType(45, uint16_t.max, 5);
		case MIGHTY_10:                             return PropType(45, uint16_t.max, 10);
		case REGENERATION:                          return PropType(51, uint16_t.max, 1);
		case BOOTS_REGENERATION1:                   return PropType(51, uint16_t.max, 1);
		case SHIELD_REGENERATION1:                  return PropType(51, uint16_t.max, 1);
		case AMULET_SKILL_CONCENTRATION_BONUS15:    return PropType(52, 1,            15);
		case AMULET_SKILL_DISABLE_TRAP_BONUS15:     return PropType(52, 2,            15);
		case AMULET_SKILL_DISCIPLINE_BONUS15:       return PropType(52, 3,            15);
		case AMULET_SKILL_HEAL_BONUS15:             return PropType(52, 4,            15);
		case AMULET_SKILL_HIDE_BONUS15:             return PropType(52, 5,            15);
		case AMULET_SKILL_LISTEN_BONUS15:           return PropType(52, 6,            15);
		case AMULET_SKILL_LORE_BONUS15:             return PropType(52, 7,            15);
		case AMULET_SKILL_MOVE_SILENTLY_BONUS15:    return PropType(52, 8,            15);
		case AMULET_SKILL_OPEN_LOCK_BONUS15:        return PropType(52, 9,            15);
		case AMULET_SKILL_PARRY_BONUS15:            return PropType(52, 10,           15);
		case AMULET_SKILL_PERFORM_BONUS15:          return PropType(52, 11,           15);
		case AMULET_SKILL_DIPLOMACY_BONUS15:        return PropType(52, 12,           15);
		case AMULET_SKILL_PERSUADE_BONUS15:         return PropType(52, 12,           15);//Diplomacy
		case AMULET_SKILL_SLEIGHT_OF_HAND_BONUS15:  return PropType(52, 13,           15);
		case AMULET_SKILL_PICK_POCKET_BONUS15:      return PropType(52, 13,           15);//SleightOfHand
		case AMULET_SKILL_SEARCH_BONUS15:           return PropType(52, 14,           15);
		case AMULET_SKILL_SET_TRAP_BONUS15:         return PropType(52, 15,           15);
		case AMULET_SKILL_SPELLCRAFT_BONUS15:       return PropType(52, 16,           15);
		case AMULET_SKILL_SPOT_BONUS15:             return PropType(52, 17,           15);
		case AMULET_SKILL_TAUNT_BONUS15:            return PropType(52, 18,           15);
		case AMULET_SKILL_USE_MAGIC_DEVICE_BONUS15: return PropType(52, 19,           15);
		case AMULET_SKILL_APPRAISE_BONUS15:         return PropType(52, 20,           15);
		case AMULET_SKILL_TUMBLE_BONUS15:           return PropType(52, 21,           15);
		case AMULET_SKILL_CRAFT_TRAP_BONUS15:       return PropType(52, 22,           15);
		case AMULET_SKILL_BLUFF_BONUS15:            return PropType(52, 23,           15);
		case AMULET_SKILL_INTIMIDATE_BONUS15:       return PropType(52, 24,           15);
		case AMULET_SKILL_CRAFT_ARMOR_BONUS15:      return PropType(52, 25,           15);
		case AMULET_SKILL_CRAFT_WEAPON_BONUS15:     return PropType(52, 26,           15);
		case AMULET_SKILL_CRAFT_ALCHEMY_BONUS15:    return PropType(52, 27,           15);
		case AMULET_SKILL_SURVIVAL_BONUS15:         return PropType(52, 29,           15);
		case ATTACK_BONUS:                          return PropType(56, uint16_t.max, 1);
		case UNLIMITED_3:
			switch(baseItemType){
				case 8,11:                          return PropType(61, 0,            15);//Bow
				case 6,7:                           return PropType(61, 1,            15);//XBow
				case 61:                            return PropType(61, 2,            15);//Sling
				default: throw new EnchantmentException("Cannot add Unlimited enchantment to item type "~baseItemType.to!string);
			}
		case TRUESEEING:                            return PropType(71);
		case RING_FREEACTION:                       return PropType(75);
		case ARMOR_FREEACTION:                      return PropType(75);
	}
}



GffNode buildPropertyUsing2DA(in PropType propType, uint8_t param1Value=uint8_t.max){
	GffNode ret = GffNode(GffType.Struct);
	with(ret){
		assert(propType.propertyName < getTwoDA("itempropdef").rows);

		appendField(GffNode(GffType.Word, "PropertyName", propType.propertyName));

		immutable subTypeTable = getTwoDA("itempropdef").get("SubTypeResRef", propType.propertyName);
		if(subTypeTable is null)
			assert(propType.subType==uint16_t.max, "propType.subType pointing to non-existent SubTypeTable");
		else
			assert(propType.subType!=uint16_t.max, "propType.subType must be defined");

		appendField(GffNode(GffType.Word, "Subtype", propType.subType));

		string costTableResRef = getTwoDA("itempropdef").get("CostTableResRef", propType.propertyName);
		if(costTableResRef is null)
			assert(propType.costValue==uint16_t.max, "propType.costValue pointing to non-existent CostTableResRef");
		else
			assert(propType.costValue!=uint16_t.max, "propType.costValue must be defined");

		appendField(GffNode(GffType.Byte, "CostTable", costTableResRef !is null? costTableResRef.to!ubyte : ubyte.max));
		appendField(GffNode(GffType.Word, "CostValue", propType.costValue));


		immutable paramTableResRef = getTwoDA("itempropdef").get("Param1ResRef", propType.propertyName);
		if(paramTableResRef !is null){
			assert(param1Value!=uint8_t.max, "param1Value must be defined");
			appendField(GffNode(GffType.Byte, "Param1", paramTableResRef.to!ubyte));
			appendField(GffNode(GffType.Byte, "Param1Value", param1Value));
		}
		else{
			assert(param1Value==uint8_t.max, "param1Value pointing to non-existent Param1ResRef");
			appendField(GffNode(GffType.Byte, "Param1", uint8_t.max));
			appendField(GffNode(GffType.Byte, "Param1Value", uint8_t.max));
		}

		appendField(GffNode(GffType.Byte, "ChanceAppear", 100));
		appendField(GffNode(GffType.Byte, "UsesPerDay",   255));
		appendField(GffNode(GffType.Byte, "Useable",      1));
	}
	return ret;
}