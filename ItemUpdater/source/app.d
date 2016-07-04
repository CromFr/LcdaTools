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


ref const(TwoDA) getTwoDA(in string name){
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
UpdatePolicy cursedPolicy = UpdatePolicy.Override;
UpdatePolicy plotPolicy = UpdatePolicy.Override;

int main(string[] args){
	string vaultOvr;
	string tempOvr;
	string[string] updateMapPaths;
	bool noninteractive = false;
	uint parallelJobs = 1;
	bool skipVault = false;
	bool skipSql = false;

	//Parse cmd line
	try{
		auto res = LcdaConfig.init(args);
		arraySep = ",";
		res.options ~= getopt(args,
			"vault", "Vault containing all character bic files to update.\nDefault: $path_nwn2docs/servervault", &vaultOvr,
			"temp", "Temp folder for storing modified files installing them, and also backup files.\nDefault: $path_nwn2docs/itemupdater_tmp", &tempOvr,
			required,"update", "Tag of the item with the updated blueprint.\nThe item blueprint can be a path to any UTI file or the resource name of an item on LcdaDev (without the .uti extension)\nCan be specified multiple times\nExample: --update ITEMTAG=mynewitem", &updateMapPaths,
			"noninteractive|y", "Do not prompt and update everything", &noninteractive,
			"policy-cursed", "Whether or not keeping the cursed property state through updates.\nValues: Override, Keep\nDefault: Keep", &cursedPolicy,
			"policy-plot", "Whether or not keeping the plot property state through updates.\nValues: Override, Keep\nDefault: Keep", &plotPolicy,
			"skip-vault", "Do not update the servervault", &skipVault,
			"skip-sql", "Do not update the items in the SQL db (coffreibee, casieribee)", &skipSql,
			"j", "Number of parallel jobs\nDefault: 1", &parallelJobs,
			).options;

		if(res.helpWanted){
			improvedGetoptPrinter(
				"Update items in bic files & sql db",
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


	//Parse blueprints
	Gff[string] updateMap;
	foreach(k, v ; updateMapPaths){
		if(v.extension !is null)
			updateMap[k] = new Gff(v);
		else
			updateMap[k] = new Gff(buildPath(LcdaConfig["path_lcdadev"], v~".uti"));
	}


	StopWatch bench;
	auto taskPool = new TaskPool(parallelJobs-1);
	scope(exit) taskPool.finish;
	auto conn = new Connection(
		LcdaConfig["sql_address"],
		LcdaConfig["sql_user"],
		LcdaConfig["sql_password"],
		LcdaConfig["sql_schema"]);
	scope(exit) conn.close();


	//Servervault update
	if(!skipVault){
		writeln();
		writeln("".center(80, '='));
		writeln("  SERVERVAULT UPDATE  ".center(80, '|'));
		writeln("".center(80, '='));
		stdout.flush();

		if(temp.exists){
			if(noninteractive==false && !temp.dirEntries(SpanMode.shallow).empty){
				stderr.writeln("WARNING: '",temp,"' is not empty and may contain backups from previous item updates");
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


		bench.start;
		foreach(charFile ; taskPool.parallel(vault.dirEntries("*.bic", SpanMode.depth))){
			bool charUpdated = false;
			uint refund = 0;
			int[string] updatedItemStats;

			void updateSingleItem(ref GffNode item){
				immutable tag = item["Tag"].to!string;
				assert(tag in updateMap);

				if(auto cnt = tag in updatedItemStats)
					(*cnt)++;
				else
					updatedItemStats[tag] = 1;

				charUpdated = true;
				auto update = item.updateItem(updateMap[tag], charFile.relativePath(vault));

				refund += update.refund;
				item = update.item;
			}

			void updateInventory(ref GffNode container){
				assert("ItemList" in container.as!(GffType.Struct));

				foreach(ref item ; container["ItemList"].as!GffList){
					if(item["Tag"].to!string in updateMap){
						updateSingleItem(item);
					}
					if("ItemList" in item.as!(GffType.Struct)){
						updateInventory(item);
					}
				}

				if("Equip_ItemList" in container.as!(GffType.Struct)){
					bool[size_t] itemsToRemove;
					foreach(ref item ; container["Equip_ItemList"].as!GffList){
						if(item["Tag"].to!string in updateMap){
							updateSingleItem(item);

							itemsToRemove[item.structType] = true;

							if(container["ItemList"].as!GffList.length < 128){
								//TODO: check if ok if inventory full
								container["ItemList"].as!GffList ~= item.dup;
							}
							else{
								stderr.writeln(
									"WARNING: ",charFile," has '",item["Tag"].to!string,"' equipped and no room in inventory to unequip it.",
									" The character may be refused on login for having an item too powerful for his level.",item.structType);
							}
						}
					}

					container["Equip_ItemList"].as!GffList.remove!(a=>(a.structType in itemsToRemove) !is null);


				}
			}

			auto character = new Gff(cast(ubyte[])charFile.read);
			updateInventory(character);

			if(charUpdated){
				immutable charPathRelative = charFile.relativePath(vault);

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
		auto res = Command(conn, "SELECT id, account_name, item_data FROM coffreibee").execSQLResult;
		foreach(row ; taskPool.parallel(res)){
			auto id = row[0].get!long;
			auto owner = row[1].get!string;
			auto item = new Gff(row[2].get!(ubyte[]));

			immutable tag = item["Tag"].to!string;
			if(auto blueprint = tag in updateMap){
				//Item will be updated and name will be changed
				auto update = item.updateItem(*blueprint, "coffreibee["~id.to!string~"]");

				item.root = update.item;
				ubyte[] updatedData = item.serialize();

				//Update item data
				auto cmdUpdate = Command(conn,
						"UPDATE coffreibee SET"
							~" item_name=CONCAT('<b><c=red>MAJ</c></b> ',item_name),"
							~" item_description=CONCAT('<b><c=red>Cet objet a été mis à jour et ne correspond plus à la description.\\nVeuillez retirer et re-déposer l\\'objet pour le mettre à jour\\n\\n</c></b>',item_description),"
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

				writeln("coffreibee[",id,"] ",tag," (Owner: ",owner,")", update.refund>0? " + refund "~update.refund.to!string~" gp sent in bank" : "");
				stdout.flush();
			}


		}
		//CASIERIBEE
		res = Command(conn, "SELECT id, vendor_account_name, item_data FROM casieribee WHERE active=1").execSQLResult;
		foreach(row ; taskPool.parallel(res)){
			auto id = row[0].get!long;
			auto owner = row[1].get!string;
			auto item = new Gff(row[2].get!(ubyte[]));

			immutable tag = item["Tag"].to!string;
			if(auto blueprint = tag in updateMap){
				//Item will be updated and marked as sold with price = 0gp
				auto update = item.updateItem(*blueprint, "casieribee["~id.to!string~"]");

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

				writeln("casieribee[",id,"] ",tag," (Owner: ",owner,")", update.refund>0? " + refund "~update.refund.to!string~" gp sent in bank" : "");
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
					writeln("> ",to);
					stdout.flush();
					copy(from, to);
				}
			}

			if(!skipVault)
				copyRecurse(buildPath(temp, "updated_vault"), vault);

			//SQL commit
			if(!skipSql)
				Command(conn, "COMMIT").execSQL;

			return 0;
		}
	}


	//SQL rollback
	if(!skipSql)
		Command(conn, "ROLLBACK").execSQL;


	return 0;
}


///
auto updateItem(in GffNode oldItem, in GffNode blueprint, lazy string ownerName){
	bool enchanted = false;
	int enchantmentId;

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
	if(cursedPolicy == UpdatePolicy.Keep){
		updatedItem["Cursed"] = oldItem["Cursed"].dup;
	}
	if(plotPolicy == UpdatePolicy.Keep){
		updatedItem["Plot"] = oldItem["Plot"].dup;
	}

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
	//  rule: override oldItem vars with blueprint vars
	size_t[string] varsInBlueprint;
	foreach(i, ref var ; blueprint["VarTable"].as!GffList)
		varsInBlueprint[var["Name"].as!GffExoString] = i;

	foreach(ref varNode ; oldItem["VarTable"].as!GffList){
		//Append oldItem var if not in blueprint
		if(varNode.label !in varsInBlueprint){
			immutable name = varNode["Name"].to!string;
			if(name=="DEJA_ENCHANTE"){
				//stderr.writeln("DEJA_ENCHANTE=",varNode["Value"].as!GffInt);
				enchanted     = varNode["Value"].to!bool;
			}
			else if(name=="X2_LAST_PROPERTY"){
				//stderr.writeln("X2_LAST_PROPERTY=",varNode["Value"].as!GffInt);
				enchantmentId = varNode["Value"].as!GffInt;
			}

			updatedItem["VarTable"].as!GffList ~= varNode.dup;
		}
	}

	//Enchantment
	int refund = 0;
	if(enchanted){
		try updatedItem.enchantItem(enchantmentId);
		catch(EnchantmentException e){
			stderr.writeln("WARNING: ",ownerName,":",updatedItem["Tag"].to!string,": ",e.msg, " - Enchantment refunded");

			//Refund enchantment
			refund = PrixDuService(enchantmentId);
			assert(refund != 0);


			//Remove enchantment variables
			//updatedItem["VarTable"]
			//	.as!GffList
			//	.remove!((var){
			//			stderr.writeln("Lookin at ",var["Name"].to!string, "=========",var["Name"].to!string=="DEJA_ENCHANTE" || var["Name"].to!string=="X2_LAST_PROPERTY");
			//			return var["Name"].to!string=="DEJA_ENCHANTE" || var["Name"].to!string=="X2_LAST_PROPERTY";
			//		});
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

unittest{
	with(GffType){
		void cmpItems(GffType TYPE=Struct)(in GffNode lhs, in GffNode rhs) if(TYPE==Struct || TYPE==List){
			assert(lhs.type==TYPE && rhs.type==TYPE, "GffNode type mismatch");
			assert(lhs.as!TYPE.length == rhs.as!TYPE.length, "children length mismatch");

			static if(TYPE==Struct){
				foreach(ref lhskv ; lhs.as!Struct.byKeyValue){
					auto rhsv = lhskv.key in rhs.as!Struct;
					assert(rhsv, "Key '"~lhskv.key~"' is in 'lhs' but not in 'rhs'");

					assert(lhskv.key == lhskv.value.label);
					assert(lhskv.value.label == lhskv.key);
					assert(rhsv.label == lhskv.key);

					if(lhskv.key=="LocalizedName") continue;//May change for practical reasons
					if(lhskv.key=="Tint") continue;//Tint has a bug where color2 is automatically changed to red by the server
					if(lhskv.key=="LastName") continue;//we dont care

					if(lhskv.value.type == Struct){
						cmpItems!Struct(lhskv.value, *rhsv);
					}
					else if(lhskv.value.type == List){
						cmpItems!List(lhskv.value, *rhsv);
					}
					else{
						assert(rhsv.toPrettyString == lhskv.value.toPrettyString,
							"Value mismatch on key '"~lhskv.key~"': "~lhskv.value.toPrettyString~" => "~rhsv.toPrettyString);
					}
				}
			}
			else static if(TYPE==List){
				foreach(i, ref lhsv ; lhs.as!List){
					cmpItems!Struct(lhsv, rhs.as!List[i]);
				}
			}
		}


		auto character = new Gff("unittests/aaadebug.bic");
		//import std.file: writeFile=write;
		//foreach(i ; 0..6){
		//	("unittests/instance-"~character["ItemList"][i]["LocalizedName"].to!string~".json").writeFile(character["ItemList"][i].toJson.toString);
		//	("unittests/instance-"~character["ItemList"][i]["LocalizedName"].to!string~".pretty").writeFile(character["ItemList"][i].toPrettyString);
		//}
		//"unittests/blueprint-hacheavatardesglaces--ORIGINAL.UTI.pretty".writeFile(
		//	new Gff("unittests/blueprint-hacheavatardesglaces--ORIGINAL.UTI").toPrettyString);

		auto bpOriginal = new Gff("unittests/blueprint-hacheavatardesglaces--ORIGINAL.UTI");
		auto bpBuffed = new Gff("unittests/blueprint-hacheavatardesglaces--ORIGINAL+2ALT.UTI");

		auto from = character["ItemList"][0];
		auto to = character["ItemList"][0].updateItem(bpOriginal).item;

		cmpItems(from, to);


		//import std.algorithm: sort, each;
		//writeln("==================================== ORIGINAL ITEM");
		//from.as!Struct.byKeyValue.dup.sort!"a.key < b.key".each!((a){writeln(a.key, "=", a.value.to!string, a.key in to.as!Struct? "" : "     <<<<<<<<<<<<<<<<");});
		//writeln("==================================== UPDATED ITEM");
		//to.as!Struct.byKeyValue.dup.sort!"a.key < b.key".each!((a){writeln(a.key, "=", a.value.to!string, a.key in from.as!Struct? "" : "     <<<<<<<<<<<<<<<<");});

		//to.toPrettyString.writeln();




	}

}
class EnchantmentException : Exception{
	@safe pure nothrow this(string msg, string f=__FILE__, size_t l=__LINE__, Throwable t=null){
		super(msg, f, l, t);
	}
}

void enchantItem(ref GffNode item, int enchantType){
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

PropType getPropertyType(uint baseItemType, uint enchantType){
	//Indices are found in itempropdef.2da
	switch(enchantType){
		case 0: .. case 13:                                     return PropType(16, enchantType,  7);//7 is for 1d6
		case IP_CONST_WS_ARMOR_STRENGTH_BONUS2:                 return PropType(0,  0,            2);
		case IP_CONST_WS_ARMOR_DEXTERITY_BONUS2:                return PropType(0,  1,            2);
		case IP_CONST_WS_ARMOR_CONSTITUTION_BONUS2:             return PropType(0,  2,            2);
		case IP_CONST_WS_ARMOR_INTELLIGENCE_BONUS2:             return PropType(0,  3,            2);
		case IP_CONST_WS_ARMOR_WISDOM_BONUS2:                   return PropType(0,  4,            2);
		case IP_CONST_WS_ARMOR_CHARISMA_BONUS2:                 return PropType(0,  5,            2);
		case IP_CONST_WS_BRACERS_BELT_STRENGTH_BONUS2:          return PropType(0,  0,            2);
		case IP_CONST_WS_BRACERS_BELT_DEXTERITY_BONUS2:         return PropType(0,  1,            2);
		case IP_CONST_WS_BRACERS_BELT_CONSTITUTION_BONUS2:      return PropType(0,  2,            2);
		case IP_CONST_WS_BRACERS_BELT_INTELLIGENCE_BONUS2:      return PropType(0,  3,            2);
		case IP_CONST_WS_BRACERS_BELT_WISDOM_BONUS2:            return PropType(0,  4,            2);
		case IP_CONST_WS_BRACERS_BELT_CHARISMA_BONUS2:          return PropType(0,  5,            2);
		case IP_CONST_WS_HELM_STRENGTH_BONUS2:                  return PropType(0,  0,            2);
		case IP_CONST_WS_HELM_DEXTERITY_BONUS2:                 return PropType(0,  1,            2);
		case IP_CONST_WS_HELM_CONSTITUTION_BONUS2:              return PropType(0,  2,            2);
		case IP_CONST_WS_HELM_INTELLIGENCE_BONUS2:              return PropType(0,  3,            2);
		case IP_CONST_WS_HELM_WISDOM_BONUS2:                    return PropType(0,  4,            2);
		case IP_CONST_WS_HELM_CHARISMA_BONUS2:                  return PropType(0,  5,            2);
		case IP_CONST_WS_AMULET_STRENGTH_BONUS2:                return PropType(0,  0,            2);
		case IP_CONST_WS_AMULET_DEXTERITY_BONUS2:               return PropType(0,  1,            2);
		case IP_CONST_WS_AMULET_CONSTITUTION_BONUS2:            return PropType(0,  2,            2);
		case IP_CONST_WS_AMULET_INTELLIGENCE_BONUS2:            return PropType(0,  3,            2);
		case IP_CONST_WS_AMULET_WISDOM_BONUS2:                  return PropType(0,  4,            2);
		case IP_CONST_WS_AMULET_CHARISMA_BONUS2:                return PropType(0,  5,            2);
		case IP_CONST_WS_RING_STRENGTH_BONUS2:                  return PropType(0,  0,            2);
		case IP_CONST_WS_RING_DEXTERITY_BONUS2:                 return PropType(0,  1,            2);
		case IP_CONST_WS_RING_CONSTITUTION_BONUS2:              return PropType(0,  2,            2);
		case IP_CONST_WS_RING_INTELLIGENCE_BONUS2:              return PropType(0,  3,            2);
		case IP_CONST_WS_RING_WISDOM_BONUS2:                    return PropType(0,  4,            2);
		case IP_CONST_WS_RING_CHARISMA_BONUS2:                  return PropType(0,  5,            2);
		case IP_CONST_WS_BOOTS_STRENGTH_BONUS2:                 return PropType(0,  0,            2);
		case IP_CONST_WS_BOOTS_DEXTERITY_BONUS2:                return PropType(0,  1,            2);
		case IP_CONST_WS_BOOTS_CONSTITUTION_BONUS2:             return PropType(0,  2,            2);
		case IP_CONST_WS_BOOTS_INTELLIGENCE_BONUS2:             return PropType(0,  3,            2);
		case IP_CONST_WS_BOOTS_WISDOM_BONUS2:                   return PropType(0,  4,            2);
		case IP_CONST_WS_BOOTS_CHARISMA_BONUS2:                 return PropType(0,  5,            2);
		case IP_CONST_WS_CLOAK_STRENGTH_BONUS2:                 return PropType(0,  0,            2);
		case IP_CONST_WS_CLOAK_DEXTERITY_BONUS2:                return PropType(0,  1,            2);
		case IP_CONST_WS_CLOAK_CONSTITUTION_BONUS2:             return PropType(0,  2,            2);
		case IP_CONST_WS_CLOAK_INTELLIGENCE_BONUS2:             return PropType(0,  3,            2);
		case IP_CONST_WS_CLOAK_WISDOM_BONUS2:                   return PropType(0,  4,            2);
		case IP_CONST_WS_CLOAK_CHARISMA_BONUS2:                 return PropType(0,  5,            2);
		case IP_CONST_WS_SHIELD_STRENGTH_BONUS2:                return PropType(0,  0,            2);
		case IP_CONST_WS_SHIELD_DEXTERITY_BONUS2:               return PropType(0,  1,            2);
		case IP_CONST_WS_SHIELD_CONSTITUTION_BONUS2:            return PropType(0,  2,            2);
		case IP_CONST_WS_SHIELD_INTELLIGENCE_BONUS2:            return PropType(0,  3,            2);
		case IP_CONST_WS_SHIELD_WISDOM_BONUS2:                  return PropType(0,  4,            2);
		case IP_CONST_WS_SHIELD_CHARISMA_BONUS2:                return PropType(0,  5,            2);
		case IP_CONST_WS_ARMOR_BONUS_CA2:                       return PropType(1,  uint16_t.max, 2);
		case IP_CONST_WS_CLOAK_PARADE_BONUS2:                   return PropType(1,  uint16_t.max, 2);
		case IP_CONST_WS_BRACERS_BELT_CA_VS_BLUDGEONING_BONUS5: return PropType(3,  0,            5);
		case IP_CONST_WS_BRACERS_BELT_CA_VS_PIERCING_BONUS5:    return PropType(3,  1,            5);
		case IP_CONST_WS_BRACERS_BELT_CA_VS_SLASHING_BONUS5:    return PropType(3,  2,            5);
		case IP_CONST_WS_ENHANCEMENT_BONUS:                     return PropType(6,  uint16_t.max, 1);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_BLUDGEONING:    return PropType(23, 0,            5);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_PIERCING:       return PropType(23, 1,            5);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_SLASHING:       return PropType(23, 2,            5);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_MAGICAL:        return PropType(23, 5,            5);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_ACID:           return PropType(23, 6,            5);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_COLD:           return PropType(23, 7,            5);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_DIVINE:         return PropType(23, 8,            5);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_ELECTRICAL:     return PropType(23, 9,            5);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_FIRE:           return PropType(23, 10,           5);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_NEGATIVE:       return PropType(23, 11,           5);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_POSITIVE:       return PropType(23, 12,           5);
		case IP_CONST_WS_HELM_DAMAGERESISTANCE5_SONIC:          return PropType(23, 13,           5);
		case IP_CONST_WS_BOOTS_DARKVISION:                      return PropType(26);
		case IP_CONST_WS_HASTE:                                 return PropType(35);
		case IP_CONST_WS_RING_IMMUNE_ABSORBTION:                return PropType(37, 1);
		case IP_CONST_WS_RING_IMMUNE_TERROR:                    return PropType(37, 5);
		case IP_CONST_WS_RING_IMMUNE_DEATH:                     return PropType(37, 9);
		case IP_CONST_WS_SPELLRESISTANCE:                       return PropType(39, uint16_t.max, 0);//+10
		case IP_CONST_WS_SHIELD_SPELLRESISTANCE10:              return PropType(39, uint16_t.max, 0);//+10
		case IP_CONST_WS_SHIELD_BONUS_VIG_PLUS7:                return PropType(41, 1,            7);
		case IP_CONST_WS_SHIELD_BONUS_VOL_PLUS7:                return PropType(41, 2,            7);
		case IP_CONST_WS_SHIELD_BONUS_REF_PLUS7:                return PropType(41, 3,            7);
		case IP_CONST_WS_KEEN:                                  return PropType(43);
		case IP_CONST_WS_MIGHTY_5:                              return PropType(45, uint16_t.max, 5);
		case IP_CONST_WS_MIGHTY_10:                             return PropType(45, uint16_t.max, 10);
		case IP_CONST_WS_REGENERATION:                          return PropType(51, uint16_t.max, 1);
		case IP_CONST_WS_BOOTS_REGENERATION1:                   return PropType(51, uint16_t.max, 1);
		case IP_CONST_WS_SHIELD_REGENERATION1:                  return PropType(51, uint16_t.max, 1);
		case IP_CONST_WS_AMULET_SKILL_CONCENTRATION_BONUS15:    return PropType(52, 1,            15);
		case IP_CONST_WS_AMULET_SKILL_DISABLE_TRAP_BONUS15:     return PropType(52, 2,            15);
		case IP_CONST_WS_AMULET_SKILL_DISCIPLINE_BONUS15:       return PropType(52, 3,            15);
		case IP_CONST_WS_AMULET_SKILL_HEAL_BONUS15:             return PropType(52, 4,            15);
		case IP_CONST_WS_AMULET_SKILL_HIDE_BONUS15:             return PropType(52, 5,            15);
		case IP_CONST_WS_AMULET_SKILL_LISTEN_BONUS15:           return PropType(52, 6,            15);
		case IP_CONST_WS_AMULET_SKILL_LORE_BONUS15:             return PropType(52, 7,            15);
		case IP_CONST_WS_AMULET_SKILL_MOVE_SILENTLY_BONUS15:    return PropType(52, 8,            15);
		case IP_CONST_WS_AMULET_SKILL_OPEN_LOCK_BONUS15:        return PropType(52, 9,            15);
		case IP_CONST_WS_AMULET_SKILL_PARRY_BONUS15:            return PropType(52, 10,           15);
		case IP_CONST_WS_AMULET_SKILL_PERFORM_BONUS15:          return PropType(52, 11,           15);
		case IP_CONST_WS_AMULET_SKILL_DIPLOMACY_BONUS15:        return PropType(52, 12,           15);
		case IP_CONST_WS_AMULET_SKILL_PERSUADE_BONUS15:         return PropType(52, 12,           15);//Diplomacy
		case IP_CONST_WS_AMULET_SKILL_SLEIGHT_OF_HAND_BONUS15:  return PropType(52, 13,           15);
		case IP_CONST_WS_AMULET_SKILL_PICK_POCKET_BONUS15:      return PropType(52, 13,           15);//SleightOfHand
		case IP_CONST_WS_AMULET_SKILL_SEARCH_BONUS15:           return PropType(52, 14,           15);
		case IP_CONST_WS_AMULET_SKILL_SET_TRAP_BONUS15:         return PropType(52, 15,           15);
		case IP_CONST_WS_AMULET_SKILL_SPELLCRAFT_BONUS15:       return PropType(52, 16,           15);
		case IP_CONST_WS_AMULET_SKILL_SPOT_BONUS15:             return PropType(52, 17,           15);
		case IP_CONST_WS_AMULET_SKILL_TAUNT_BONUS15:            return PropType(52, 18,           15);
		case IP_CONST_WS_AMULET_SKILL_USE_MAGIC_DEVICE_BONUS15: return PropType(52, 19,           15);
		case IP_CONST_WS_AMULET_SKILL_APPRAISE_BONUS15:         return PropType(52, 20,           15);
		case IP_CONST_WS_AMULET_SKILL_TUMBLE_BONUS15:           return PropType(52, 21,           15);
		case IP_CONST_WS_AMULET_SKILL_CRAFT_TRAP_BONUS15:       return PropType(52, 22,           15);
		case IP_CONST_WS_AMULET_SKILL_BLUFF_BONUS15:            return PropType(52, 23,           15);
		case IP_CONST_WS_AMULET_SKILL_INTIMIDATE_BONUS15:       return PropType(52, 24,           15);
		case IP_CONST_WS_AMULET_SKILL_CRAFT_ARMOR_BONUS15:      return PropType(52, 25,           15);
		case IP_CONST_WS_AMULET_SKILL_CRAFT_WEAPON_BONUS15:     return PropType(52, 26,           15);
		case IP_CONST_WS_AMULET_SKILL_CRAFT_ALCHEMY_BONUS15:    return PropType(52, 27,           15);
		case IP_CONST_WS_AMULET_SKILL_SURVIVAL_BONUS15:         return PropType(52, 29,           15);
		case IP_CONST_WS_ATTACK_BONUS:                          return PropType(56, uint16_t.max, 1);
		case IP_CONST_WS_UNLIMITED_3:
			switch(baseItemType){
				case 8,11:                                      return PropType(61, 0,            15);//Bow
				case 6,7:                                       return PropType(61, 1,            15);//XBow
				case 61:                                        return PropType(61, 2,            15);//Sling
				default: throw new EnchantmentException("Cannot add Unlimited enchantment to item type "~baseItemType.to!string);
			}
		case IP_CONST_WS_TRUESEEING:                            return PropType(71);
		case IP_CONST_WS_RING_FREEACTION:                       return PropType(75);
		case IP_CONST_WS_ARMOR_FREEACTION:                      return PropType(75);
		default: assert(0, "Unknown enchantType "~enchantType.to!string);
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