import std.stdio;
import std.getopt;
	alias required = std.getopt.config.required;
import std.string;
import std.stdint;
import std.conv;
import std.typecons: Tuple;
import std.exception: assertThrown, assertNotThrown, enforce;
import std.algorithm;

import nwn.gff;

import lcda.config;
import lcda.util;
import lcda.compat.lib_forge_epique;

import item_processor;

int main(string[] args){
	ItemProcessorConfig procCfg;

	//Parse cmd line
	try{
		enum prgHelp = "Mark items in bic files & sql db\n";

		auto res = LcdaConfig.init(args);

		auto ipRes = itemProcessorParseArgs(args);
		res.options ~= ipRes[0].options;
		procCfg = ipRes[1];

		if(res.helpWanted){
			improvedGetoptPrinter(
				prgHelp,
				res.options);
			return 0;
		}
	}
	catch(Exception e){
		stderr.writeln(e.msg);
		stderr.writeln("Use --help for more information");
		return 1;
	}

	return processAllItems(procCfg, (ref item, context){
		bool hasEnchantmentVars = false;
		bool enchanted = false;
		int32_t oldConst = int32_t.max;

		foreach(ref var ; item["VarTable"].as!(GffType.List)){
			switch(var["Name"].to!string){
				case "DEJA_ENCHANTE":
					enchanted = var["Value"].to!bool;
					hasEnchantmentVars = true;
					break;
				case "X2_LAST_PROPERTY":
					oldConst = var["Value"].as!(GffType.Int);
					hasEnchantmentVars = true;
					break;
				default:
					break;
			}
		}

		if(hasEnchantmentVars){
			GffNode[] newVarTable;

			// Remove old vars
			foreach(ref var ; item["VarTable"].as!(GffType.List)){
				switch(var["Name"].to!string){
					case "X2_LAST_PROPERTY":
					case "DEJA_ENCHANTE":
						break;
					default:
						newVarTable ~= var;
				}
			}

			// Add new vars (if correctly enchanted)
			if(!enchanted){
				if(oldConst != int32_t.max){
					stderr.writefln("\x1b[1;31mWARNING: %s: Item '%s' is not enchanted but has a X2_LAST_PROPERTY=%d.\x1b[m",
						context, item["TemplateResRef"].to!string, oldConst, enchanted
					);
					stderr.writeln(item["VarTable"].toPrettyString);
				}
			}
			else if(oldConst <= 0){
				stderr.writefln("\x1b[1;31mWARNING: %s: Item '%s' is enchanted with an invalid X2_LAST_PROPERTY=%d. Enchantement will be removed.\x1b[m",
					context, item["TemplateResRef"].to!string, oldConst
				);
				stderr.writeln(item["VarTable"].toPrettyString);
			}
			else if(oldConst == int32_t.max){
				stderr.writefln("\x1b[1;31mWARNING: %s: Item '%s' is enchanted but has no X2_LAST_PROPERTY value. Enchantement will be removed.\x1b[m",
					context, item["TemplateResRef"].to!string
				);
				stderr.writeln(item["VarTable"].toPrettyString);
			}
			else{
				auto ench = oldConst.to!EnchantmentId;

				auto iprp = legacyConstToIprp(GetBaseItemType(item), ench);
				newVarTable ~= LocalVar("hagbe_ench", GffType.Int, 1);
				newVarTable ~= LocalVar("hagbe_iprp_t", GffType.Int, iprp.type);
				newVarTable ~= LocalVar("hagbe_iprp_st", GffType.Int, iprp.subType);
				newVarTable ~= LocalVar("hagbe_iprp_c", GffType.Int, iprp.costValue);
				newVarTable ~= LocalVar("hagbe_iprp_p1", GffType.Int, iprp.p1);
				newVarTable ~= LocalVar("hagbe_cost", GffType.Int, PrixDuService(ench));
			}

			item["VarTable"].as!(GffType.List) = newVarTable;
			//stderr.writefln("        %s: enchanted=%s, oldConst=%s", item["TemplateResRef"].to!string, enchanted, oldConst);
			return true;
		}
		return false;
	});
}

