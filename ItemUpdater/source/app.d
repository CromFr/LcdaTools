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

	//Parse cmd line
	try{
		auto res = LcdaConfig.init(args);
		res.options ~= getopt(args,
			"vault", "Vault containing all character bic files to update.\nDefault: $path_nwn2docs/servervault", &vaultOvr,
			"temp", "Temp folder for storing modified files installing them, and also backup files.\nDefault: $path_nwn2docs/itemupdater_tmp", &tempOvr,
			required,"update", "Tag of the item with the updated blueprint.\nThe item blueprint can be a path to any UTI file or the resource name of an item on LcdaDev (without the .uti extension)\nCan be specified multiple times\nExample: --update ITEMTAG=mynewitem", &updateMapPaths,
			"noninteractive|y", "Do not prompt and update everything", &noninteractive,
			"policy-cursed", "Whether or not keeping the cursed property state through updates.\nValues: Override, Keep\nDefault: Keep", &cursedPolicy,
			"policy-plot", "Whether or not keeping the plot property state through updates.\nValues: Override, Keep\nDefault: Keep", &plotPolicy,
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



	//Parse blueprints
	Gff[string] updateMap;
	foreach(k, v ; updateMapPaths){
		if(v.extension !is null)
			updateMap[k] = new Gff(v);
		else
			updateMap[k] = new Gff(buildPath(LcdaConfig["path_lcdadev"], v~".uti"));
	}

	//Update servervault
	writeln();
	writeln("".center(80, '='));
	writeln("  SERVERVAULT UPDATE  ".center(80, '|'));
	writeln("".center(80, '='));
	stdout.flush();

	StopWatch bench;

	auto taskPool = new TaskPool(parallelJobs-1);
	scope(exit) taskPool.finish;
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
			auto update = item.updateItem(updateMap[tag]);

			refund += update.refund;
			item = update.item;
		}

		void updateInventory(ref GffNode container){
			assert("ItemList" in container.as!(GffType.Struct));

			foreach(ref item ; container["ItemList"].as!(GffType.List)){
				if(item["Tag"].to!string in updateMap){
					updateSingleItem(item);
				}
				if("ItemList" in item.as!(GffType.Struct)){
					updateInventory(item);
				}
			}

			if("Equip_ItemList" in container.as!(GffType.Struct)){
				bool[size_t] itemsToRemove;
				foreach(ref item ; container["Equip_ItemList"].as!(GffType.List)){
					if(item["Tag"].to!string in updateMap){
						updateSingleItem(item);

						itemsToRemove[item.structType] = true;

						if(container["ItemList"].as!(GffType.List).length < 128){
							//TODO: check if ok if inventory full
							container["ItemList"].as!(GffType.List) ~= item.dup;
						}
						else{
							stderr.writeln(
								"WARNING: ",charFile," has '",item["Tag"].to!string,"' equipped and no room in inventory to unequip it.",
								" The character may be refused on login for having an item too powerful for his level.",item.structType);
						}
					}
				}

				container["Equip_ItemList"].as!(GffType.List).remove!(a=>(a.structType in itemsToRemove) !is null);


			}
		}

		auto character = new Gff(cast(ubyte[])charFile.read);
		updateInventory(character);

		if(charUpdated){
			immutable charPathRelative = charFile.relativePath(vault);

			//Apply refund
			character["Gold"].as!(GffType.DWord) += refund;

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



	writeln();
	writeln("".center(80, '='));
	writeln("  SQL - IBEE  ".center(80, '|'));
	writeln("".center(80, '='));
	writeln();
	stdout.flush();
	auto conn = new Connection(
		LcdaConfig["sql_address"],
		LcdaConfig["sql_user"],
		LcdaConfig["sql_password"],
		LcdaConfig["sql_schema"]);
	scope(exit) conn.close();
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
			auto update = item.updateItem(*blueprint);

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
			auto update = item.updateItem(*blueprint);

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
			//copyRecurse(buildPath(temp, "updated_vault"), vault);

			//SQL commit
			Command(conn, "COMMIT").execSQL;

			return 0;
		}
	}


	//SQL rollback
	Command(conn, "ROLLBACK").execSQL;


	return 0;
}


///
auto updateItem(in GffNode oldItem, in GffNode blueprint){
	with(GffType){
		bool enchanted = false;
		int enchantmentId;

		GffNode updatedItem = blueprint.dup;
		updatedItem.structType = 0;

		//Remove blueprint props
		updatedItem.as!Struct.remove("Comment");
		updatedItem.as!Struct.remove("Classification");
		updatedItem.as!Struct.remove("ItemCastsShadow");
		updatedItem.as!Struct.remove("ItemRcvShadow");
		updatedItem.as!Struct.remove("UVScroll");

		//Add instance & inventory props
		if("ObjectId" in oldItem.as!Struct)
			updatedItem.appendField(oldItem["ObjectId"].dup);
		if("Repos_Index" in oldItem.as!Struct)
			updatedItem.appendField(oldItem["Repos_Index"].dup);
		updatedItem.appendField(oldItem["ActionList"].dup);
		updatedItem.appendField(oldItem["DisplayName"].dup);//TODO: see value is copied from name
		if("EffectList" in oldItem.as!Struct)
			updatedItem.appendField(oldItem["EffectList"].dup);
		if("LastName" in oldItem.as!Struct){
			if("LastName" !in updatedItem.as!Struct)
				updatedItem.appendField(GffNode(ExoLocString, "LastName", gffTypeToNative!ExoLocString(0, [0:""])));
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
		if("ItemList" in oldItem.as!Struct){
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
		updatedItem["ArmorRulesType"] = GffNode(Int, "ArmorRulesType", blueprint["ArmorRulesType"].as!Byte);
		updatedItem["Cost"].as!DWord = 0;
		foreach(ref prop ; updatedItem["PropertiesList"].as!List){
			prop.as!Struct.remove("Param2");
			prop.as!Struct.remove("Param2Value");
			prop["UsesPerDay"] = GffNode(Byte, "UsesPerDay", 255);
			prop["Useable"] = GffNode(Byte, "Useable", 1);
		}



		//Copy local variables
		//  rule: override oldItem vars with blueprint vars
		size_t[string] varsInBlueprint;
		foreach(i, ref var ; blueprint["VarTable"].as!List)
			varsInBlueprint[var["Name"].as!ExoString] = i;

		foreach(ref varNode ; oldItem["VarTable"].as!List){
			//Append oldItem var if not in blueprint
			if(varNode.label !in varsInBlueprint){
				immutable name = varNode["Name"].to!string;
				if(name=="DEJA_ENCHANTE")
					enchanted     = varNode["Value"].to!bool;
				else if(name=="X2_LAST_PROPERTY")
					enchantmentId = varNode["Value"].as!Int;
				else
					updatedItem["VarTable"].as!List ~= varNode.dup;
			}
		}

		//Enchantment
		int refund = 0;
		if(enchanted){
			//Refund enchantment
			refund = PrixDuService(enchantmentId);
			assert(refund != 0);
		}

		return Tuple!(GffNode,"item", int,"refund")(updatedItem, refund);
	}
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


version(none)//<------------------ DISABLED
struct ItemProperty{
	this(int enchantType){
		import nwnconstants;
		root = GffNode(GffType.Struct);
		switch(enchantType){
			case 0: .. case 13:                                     buildUsing2DA(16, IP_CONST_DAMAGEBONUS_1d6, enchantType); break;//Checked vs game
			case IP_CONST_WS_ENHANCEMENT_BONUS:                     buildUsing2DA(6, 1); break;
			case IP_CONST_WS_HASTE:                                 buildUsing2DA(35); break;//Checked vs game
			case IP_CONST_WS_KEEN:                                  buildUsing2DA(43); break;
			case IP_CONST_WS_TRUESEEING:                            buildUsing2DA(71); break;
			case IP_CONST_WS_SPELLRESISTANCE:                       buildUsing2DA(39, 10); break;//TODO: add to item
			case IP_CONST_WS_REGENERATION:                          buildUsing2DA(51, 2); break;//Checked vs game
			case IP_CONST_WS_MIGHTY_5:                              buildUsing2DA(); break;
			case IP_CONST_WS_MIGHTY_10:                             buildUsing2DA(); break;
			case IP_CONST_WS_UNLIMITED_3:                           buildUsing2DA(); break;
			case IP_CONST_WS_ARMOR_BONUS_CA2:                       buildUsing2DA(1, 2); break;
			case IP_CONST_WS_ARMOR_FREEACTION:                      buildUsing2DA(); break;
			case IP_CONST_WS_ARMOR_STRENGTH_BONUS2:                 buildUsing2DA(); break;
			case IP_CONST_WS_ARMOR_DEXTERITY_BONUS2:                buildUsing2DA(); break;
			case IP_CONST_WS_ARMOR_CONSTITUTION_BONUS2:             buildUsing2DA(); break;
			case IP_CONST_WS_ARMOR_INTELLIGENCE_BONUS2:             buildUsing2DA(); break;
			case IP_CONST_WS_ARMOR_WISDOM_BONUS2:                   buildUsing2DA(); break;
			case IP_CONST_WS_ARMOR_CHARISMA_BONUS2:                 buildUsing2DA(); break;
			case IP_CONST_WS_SHIELD_REGENERATION1:                  buildUsing2DA(); break;
			case IP_CONST_WS_SHIELD_SPELLRESISTANCE10:              buildUsing2DA(); break;
			case IP_CONST_WS_SHIELD_BONUS_VIG_PLUS7:                buildUsing2DA(); break;
			case IP_CONST_WS_SHIELD_BONUS_REF_PLUS7:                buildUsing2DA(); break;
			case IP_CONST_WS_SHIELD_BONUS_VOL_PLUS7:                buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_ACID:           buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_BLUDGEONING:    buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_COLD:           buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_DIVINE:         buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_ELECTRICAL:     buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_FIRE:           buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_MAGICAL:        buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_NEGATIVE:       buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_PIERCING:       buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_POSITIVE:       buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_SLASHING:       buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_SONIC:          buildUsing2DA(); break;
			case IP_CONST_WS_RING_FREEACTION:                       buildUsing2DA(); break;
			case IP_CONST_WS_RING_IMMUNE_DEATH:                     buildUsing2DA(); break;
			case IP_CONST_WS_RING_IMMUNE_TERROR:                    buildUsing2DA(); break;
			case IP_CONST_WS_RING_IMMUNE_ABSORBTION:                buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_APPRAISE_BONUS15:         buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_BLUFF_BONUS15:            buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_CONCENTRATION_BONUS15:    buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_CRAFT_ARMOR_BONUS15:      buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_CRAFT_TRAP_BONUS15:       buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_CRAFT_WEAPON_BONUS15:     buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_DISABLE_TRAP_BONUS15:     buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_DISCIPLINE_BONUS15:       buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_HEAL_BONUS15:             buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_HIDE_BONUS15:             buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_INTIMIDATE_BONUS15:       buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_LISTEN_BONUS15:           buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_LORE_BONUS15:             buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_MOVE_SILENTLY_BONUS15:    buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_OPEN_LOCK_BONUS15:        buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_PARRY_BONUS15:            buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_PERFORM_BONUS15:          buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_PERSUADE_BONUS15:         buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_PICK_POCKET_BONUS15:      buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_SEARCH_BONUS15:           buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_SET_TRAP_BONUS15:         buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_SPELLCRAFT_BONUS15:       buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_SPOT_BONUS15:             buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_TAUNT_BONUS15:            buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_TUMBLE_BONUS15:           buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_USE_MAGIC_DEVICE_BONUS15: buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_DIPLOMACY_BONUS15:        buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_CRAFT_ALCHEMY_BONUS15:    buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_SLEIGHT_OF_HAND_BONUS15:  buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_SKILL_SURVIVAL_BONUS15:         buildUsing2DA(); break;
			case IP_CONST_WS_BOOTS_DARKVISION:                      buildUsing2DA(); break;
			case IP_CONST_WS_BOOTS_REGENERATION1:                   buildUsing2DA(); break;
			case IP_CONST_WS_CLOAK_PARADE_BONUS2:                   buildUsing2DA(); break;
			case IP_CONST_WS_BRACERS_BELT_CA_VS_BLUDGEONING_BONUS5: buildUsing2DA(); break;
			case IP_CONST_WS_BRACERS_BELT_CA_VS_PIERCING_BONUS5:    buildUsing2DA(); break;
			case IP_CONST_WS_BRACERS_BELT_CA_VS_SLASHING_BONUS5:    buildUsing2DA(); break;
			case IP_CONST_WS_BRACERS_BELT_CONSTITUTION_BONUS2:      buildUsing2DA(); break;
			case IP_CONST_WS_BRACERS_BELT_WISDOM_BONUS2:            buildUsing2DA(); break;
			case IP_CONST_WS_BRACERS_BELT_INTELLIGENCE_BONUS2:      buildUsing2DA(); break;
			case IP_CONST_WS_BRACERS_BELT_STRENGTH_BONUS2:          buildUsing2DA(); break;
			case IP_CONST_WS_BRACERS_BELT_DEXTERITY_BONUS2:         buildUsing2DA(); break;
			case IP_CONST_WS_BRACERS_BELT_CHARISMA_BONUS2:          buildUsing2DA(); break;
			case IP_CONST_WS_HELM_CONSTITUTION_BONUS2:              buildUsing2DA(); break;
			case IP_CONST_WS_HELM_WISDOM_BONUS2:                    buildUsing2DA(); break;
			case IP_CONST_WS_HELM_INTELLIGENCE_BONUS2:              buildUsing2DA(); break;
			case IP_CONST_WS_HELM_STRENGTH_BONUS2:                  buildUsing2DA(); break;
			case IP_CONST_WS_HELM_DEXTERITY_BONUS2:                 buildUsing2DA(); break;
			case IP_CONST_WS_HELM_CHARISMA_BONUS2:                  buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_CONSTITUTION_BONUS2:            buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_WISDOM_BONUS2:                  buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_INTELLIGENCE_BONUS2:            buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_STRENGTH_BONUS2:                buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_DEXTERITY_BONUS2:               buildUsing2DA(); break;
			case IP_CONST_WS_AMULET_CHARISMA_BONUS2:                buildUsing2DA(); break;
			case IP_CONST_WS_RING_CONSTITUTION_BONUS2:              buildUsing2DA(); break;
			case IP_CONST_WS_RING_WISDOM_BONUS2:                    buildUsing2DA(); break;
			case IP_CONST_WS_RING_INTELLIGENCE_BONUS2:              buildUsing2DA(); break;
			case IP_CONST_WS_RING_STRENGTH_BONUS2:                  buildUsing2DA(); break;
			case IP_CONST_WS_RING_DEXTERITY_BONUS2:                 buildUsing2DA(); break;
			case IP_CONST_WS_RING_CHARISMA_BONUS2:                  buildUsing2DA(); break;
			case IP_CONST_WS_BOOTS_CONSTITUTION_BONUS2:             buildUsing2DA(); break;
			case IP_CONST_WS_BOOTS_WISDOM_BONUS2:                   buildUsing2DA(); break;
			case IP_CONST_WS_BOOTS_INTELLIGENCE_BONUS2:             buildUsing2DA(); break;
			case IP_CONST_WS_BOOTS_STRENGTH_BONUS2:                 buildUsing2DA(); break;
			case IP_CONST_WS_BOOTS_DEXTERITY_BONUS2:                buildUsing2DA(); break;
			case IP_CONST_WS_BOOTS_CHARISMA_BONUS2:                 buildUsing2DA(); break;
			case IP_CONST_WS_CLOAK_CONSTITUTION_BONUS2:             buildUsing2DA(); break;
			case IP_CONST_WS_CLOAK_WISDOM_BONUS2:                   buildUsing2DA(); break;
			case IP_CONST_WS_CLOAK_INTELLIGENCE_BONUS2:             buildUsing2DA(); break;
			case IP_CONST_WS_CLOAK_STRENGTH_BONUS2:                 buildUsing2DA(); break;
			case IP_CONST_WS_CLOAK_DEXTERITY_BONUS2:                buildUsing2DA(); break;
			case IP_CONST_WS_CLOAK_CHARISMA_BONUS2:                 buildUsing2DA(); break;
			case IP_CONST_WS_SHIELD_CONSTITUTION_BONUS2:            buildUsing2DA(); break;
			case IP_CONST_WS_SHIELD_WISDOM_BONUS2:                  buildUsing2DA(); break;
			case IP_CONST_WS_SHIELD_INTELLIGENCE_BONUS2:            buildUsing2DA(); break;
			case IP_CONST_WS_SHIELD_STRENGTH_BONUS2:                buildUsing2DA(); break;
			case IP_CONST_WS_SHIELD_DEXTERITY_BONUS2:               buildUsing2DA(); break;
			case IP_CONST_WS_SHIELD_CHARISMA_BONUS2:                buildUsing2DA(); break;
			default: throw new Exception("Unknown enchantType");
		}
	}


	alias root this;
	GffNode root;

private:

	/++
		property: id of the property
		value: index in iprp_*cost.2da (corresponding to CostValue node)

		Builds a GFF with the following nodes:
			PropertyName: idx in "itempropdef.2da"
			Subtype     : idx in itempropdef[PropertyName]["SubTypeResRef"]~".2da"
			CostTable   : idx in "iprp_costtable.2da". Also CostTableResRef column of itempropdef.2da
			CostValue   : idx in iprp_costtable[CostTable]["Name"]~".2da"
			Param1      : idx in "iprp_paramtable.2da". ubyte.max if no params
			Param1Value : idx in iprp_paramtable[Param1]["TableResRef"]~".2da"
			ChanceAppear: always 100
			UsesPerDay  : ??? =255
			Useable     : ??? =1
	+/
	void buildUsing2DA(uint32_t property, uint32_t value=uint16_t.max, uint32_t subType=uint16_t.max, uint8_t param1Value=uint8_t.max){
		appendField(GffNode(GffType.Word, "PropertyName", property));

		if("itempropdef" in twoDAs)
			twoDAs["itempropdef"] = new TwoDA(buildPath(CFG_TwoDAPath,"itempropdef.2da"));

		immutable subTypeTable = twoDAs["itempropdef"].get("SubTypeResRef", property);

		appendField(GffNode(GffType.Word, "Subtype", subTypeTable !is null? subType : ushort.max));

		string costTableResRef = twoDAs["itempropdef"].get("CostTableResRef", property);
		appendField(GffNode(GffType.Byte, "CostTable", costTableResRef !is null? costTableResRef.to!ubyte : ubyte.max));
		appendField(GffNode(GffType.Word, "CostValue", value));


		string paramTableResRef = twoDAs["itempropdef"].get("Param1ResRef", property);
		if(paramTableResRef !is null){
			appendField(GffNode(GffType.Byte, "Param1", paramTableResRef.to!ubyte));
			appendField(GffNode(GffType.Byte, "Param1Value", param1Value));
		}
		else{
			appendField(GffNode(GffType.Byte, "Param1", -1));
			appendField(GffNode(GffType.Byte, "Param1Value", -1));
		}

		appendField(GffNode(GffType.Byte, "ChanceAppear", 100));
		appendField(GffNode(GffType.Byte, "UsesPerDay",   255));
		appendField(GffNode(GffType.Byte, "Useable",      1));
	}


	uint getPropertyId(uint enchantType){
		//Indices are found in itempropdef.2da
		switch(enchantType){
			case 0: .. case 13:                                     return 16;
			case IP_CONST_WS_ENHANCEMENT_BONUS:                     return  6;
			case IP_CONST_WS_HASTE:                                 return 35;
			case IP_CONST_WS_KEEN:                                  return 43;
			case IP_CONST_WS_TRUESEEING:                            return 71;
			case IP_CONST_WS_SPELLRESISTANCE:                       return 39;
			case IP_CONST_WS_REGENERATION:                          return 51;
			case IP_CONST_WS_MIGHTY_5:                              return 45;
			case IP_CONST_WS_MIGHTY_10:                             return 45;
			case IP_CONST_WS_UNLIMITED_3:                           return 61;
			case IP_CONST_WS_ARMOR_BONUS_CA2:                       return  1;
			case IP_CONST_WS_ARMOR_FREEACTION:                      return 75;
			case IP_CONST_WS_ARMOR_STRENGTH_BONUS2:                 return  0;
			case IP_CONST_WS_ARMOR_DEXTERITY_BONUS2:                return  0;
			case IP_CONST_WS_ARMOR_CONSTITUTION_BONUS2:             return  0;
			case IP_CONST_WS_ARMOR_INTELLIGENCE_BONUS2:             return  0;
			case IP_CONST_WS_ARMOR_WISDOM_BONUS2:                   return  0;
			case IP_CONST_WS_ARMOR_CHARISMA_BONUS2:                 return  0;
			case IP_CONST_WS_SHIELD_REGENERATION1:                  return 51;
			case IP_CONST_WS_SHIELD_SPELLRESISTANCE10:              return 39;
			case IP_CONST_WS_SHIELD_BONUS_VIG_PLUS7:                return 40;
			case IP_CONST_WS_SHIELD_BONUS_REF_PLUS7:                return 40;
			case IP_CONST_WS_SHIELD_BONUS_VOL_PLUS7:                return 40;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_ACID:           return 23;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_BLUDGEONING:    return 23;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_COLD:           return 23;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_DIVINE:         return 23;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_ELECTRICAL:     return 23;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_FIRE:           return 23;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_MAGICAL:        return 23;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_NEGATIVE:       return 23;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_PIERCING:       return 23;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_POSITIVE:       return 23;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_SLASHING:       return 23;
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_SONIC:          return 23;
			case IP_CONST_WS_RING_FREEACTION:                       return 75;
			case IP_CONST_WS_RING_IMMUNE_DEATH:                     return 37;
			case IP_CONST_WS_RING_IMMUNE_TERROR:                    return 37;
			case IP_CONST_WS_RING_IMMUNE_ABSORBTION:                return 37;
			case IP_CONST_WS_AMULET_SKILL_APPRAISE_BONUS15:         return 52;
			case IP_CONST_WS_AMULET_SKILL_BLUFF_BONUS15:            return 52;
			case IP_CONST_WS_AMULET_SKILL_CONCENTRATION_BONUS15:    return 52;
			case IP_CONST_WS_AMULET_SKILL_CRAFT_ARMOR_BONUS15:      return 52;
			case IP_CONST_WS_AMULET_SKILL_CRAFT_TRAP_BONUS15:       return 52;
			case IP_CONST_WS_AMULET_SKILL_CRAFT_WEAPON_BONUS15:     return 52;
			case IP_CONST_WS_AMULET_SKILL_DISABLE_TRAP_BONUS15:     return 52;
			case IP_CONST_WS_AMULET_SKILL_DISCIPLINE_BONUS15:       return 52;
			case IP_CONST_WS_AMULET_SKILL_HEAL_BONUS15:             return 52;
			case IP_CONST_WS_AMULET_SKILL_HIDE_BONUS15:             return 52;
			case IP_CONST_WS_AMULET_SKILL_INTIMIDATE_BONUS15:       return 52;
			case IP_CONST_WS_AMULET_SKILL_LISTEN_BONUS15:           return 52;
			case IP_CONST_WS_AMULET_SKILL_LORE_BONUS15:             return 52;
			case IP_CONST_WS_AMULET_SKILL_MOVE_SILENTLY_BONUS15:    return 52;
			case IP_CONST_WS_AMULET_SKILL_OPEN_LOCK_BONUS15:        return 52;
			case IP_CONST_WS_AMULET_SKILL_PARRY_BONUS15:            return 52;
			case IP_CONST_WS_AMULET_SKILL_PERFORM_BONUS15:          return 52;
			case IP_CONST_WS_AMULET_SKILL_PERSUADE_BONUS15:         return 52;
			case IP_CONST_WS_AMULET_SKILL_PICK_POCKET_BONUS15:      return 52;
			case IP_CONST_WS_AMULET_SKILL_SEARCH_BONUS15:           return 52;
			case IP_CONST_WS_AMULET_SKILL_SET_TRAP_BONUS15:         return 52;
			case IP_CONST_WS_AMULET_SKILL_SPELLCRAFT_BONUS15:       return 52;
			case IP_CONST_WS_AMULET_SKILL_SPOT_BONUS15:             return 52;
			case IP_CONST_WS_AMULET_SKILL_TAUNT_BONUS15:            return 52;
			case IP_CONST_WS_AMULET_SKILL_TUMBLE_BONUS15:           return 52;
			case IP_CONST_WS_AMULET_SKILL_USE_MAGIC_DEVICE_BONUS15: return 52;
			case IP_CONST_WS_AMULET_SKILL_DIPLOMACY_BONUS15:        return 52;
			case IP_CONST_WS_AMULET_SKILL_CRAFT_ALCHEMY_BONUS15:    return 52;
			case IP_CONST_WS_AMULET_SKILL_SLEIGHT_OF_HAND_BONUS15:  return 52;
			case IP_CONST_WS_AMULET_SKILL_SURVIVAL_BONUS15:         return 52;
			case IP_CONST_WS_BOOTS_DARKVISION:                      return 26;
			case IP_CONST_WS_BOOTS_REGENERATION1:                   return 51;
			case IP_CONST_WS_CLOAK_PARADE_BONUS2:                   return  1;
			case IP_CONST_WS_BRACERS_BELT_CA_VS_BLUDGEONING_BONUS5: return  3;
			case IP_CONST_WS_BRACERS_BELT_CA_VS_PIERCING_BONUS5:    return  3;
			case IP_CONST_WS_BRACERS_BELT_CA_VS_SLASHING_BONUS5:    return  3;
			case IP_CONST_WS_BRACERS_BELT_CONSTITUTION_BONUS2:      return  0;
			case IP_CONST_WS_BRACERS_BELT_WISDOM_BONUS2:            return  0;
			case IP_CONST_WS_BRACERS_BELT_INTELLIGENCE_BONUS2:      return  0;
			case IP_CONST_WS_BRACERS_BELT_STRENGTH_BONUS2:          return  0;
			case IP_CONST_WS_BRACERS_BELT_DEXTERITY_BONUS2:         return  0;
			case IP_CONST_WS_BRACERS_BELT_CHARISMA_BONUS2:          return  0;
			case IP_CONST_WS_HELM_CONSTITUTION_BONUS2:              return  0;
			case IP_CONST_WS_HELM_WISDOM_BONUS2:                    return  0;
			case IP_CONST_WS_HELM_INTELLIGENCE_BONUS2:              return  0;
			case IP_CONST_WS_HELM_STRENGTH_BONUS2:                  return  0;
			case IP_CONST_WS_HELM_DEXTERITY_BONUS2:                 return  0;
			case IP_CONST_WS_HELM_CHARISMA_BONUS2:                  return  0;
			case IP_CONST_WS_AMULET_CONSTITUTION_BONUS2:            return  0;
			case IP_CONST_WS_AMULET_WISDOM_BONUS2:                  return  0;
			case IP_CONST_WS_AMULET_INTELLIGENCE_BONUS2:            return  0;
			case IP_CONST_WS_AMULET_STRENGTH_BONUS2:                return  0;
			case IP_CONST_WS_AMULET_DEXTERITY_BONUS2:               return  0;
			case IP_CONST_WS_AMULET_CHARISMA_BONUS2:                return  0;
			case IP_CONST_WS_RING_CONSTITUTION_BONUS2:              return  0;
			case IP_CONST_WS_RING_WISDOM_BONUS2:                    return  0;
			case IP_CONST_WS_RING_INTELLIGENCE_BONUS2:              return  0;
			case IP_CONST_WS_RING_STRENGTH_BONUS2:                  return  0;
			case IP_CONST_WS_RING_DEXTERITY_BONUS2:                 return  0;
			case IP_CONST_WS_RING_CHARISMA_BONUS2:                  return  0;
			case IP_CONST_WS_BOOTS_CONSTITUTION_BONUS2:             return  0;
			case IP_CONST_WS_BOOTS_WISDOM_BONUS2:                   return  0;
			case IP_CONST_WS_BOOTS_INTELLIGENCE_BONUS2:             return  0;
			case IP_CONST_WS_BOOTS_STRENGTH_BONUS2:                 return  0;
			case IP_CONST_WS_BOOTS_DEXTERITY_BONUS2:                return  0;
			case IP_CONST_WS_BOOTS_CHARISMA_BONUS2:                 return  0;
			case IP_CONST_WS_CLOAK_CONSTITUTION_BONUS2:             return  0;
			case IP_CONST_WS_CLOAK_WISDOM_BONUS2:                   return  0;
			case IP_CONST_WS_CLOAK_INTELLIGENCE_BONUS2:             return  0;
			case IP_CONST_WS_CLOAK_STRENGTH_BONUS2:                 return  0;
			case IP_CONST_WS_CLOAK_DEXTERITY_BONUS2:                return  0;
			case IP_CONST_WS_CLOAK_CHARISMA_BONUS2:                 return  0;
			case IP_CONST_WS_SHIELD_CONSTITUTION_BONUS2:            return  0;
			case IP_CONST_WS_SHIELD_WISDOM_BONUS2:                  return  0;
			case IP_CONST_WS_SHIELD_INTELLIGENCE_BONUS2:            return  0;
			case IP_CONST_WS_SHIELD_STRENGTH_BONUS2:                return  0;
			case IP_CONST_WS_SHIELD_DEXTERITY_BONUS2:               return  0;
			case IP_CONST_WS_SHIELD_CHARISMA_BONUS2:                return  0;
			default: throw new Exception("Unknown enchantType "~enchantType.to!string);
		}
	}


	deprecated void buildUsing2DA(){}
}