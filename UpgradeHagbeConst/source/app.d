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
import lcda.hagbe;
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

		//res.options ~= getopt(args,
		//	"skip-vault", "Do not update the servervault", &skipVault,
		//	).options;

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


	return processAllItems(procCfg, (ref item){
		bool enchanted = false;
		int32_t oldConst = int32_t.max;
		foreach(ref var ; item["VarTable"].as!(GffType.List)){
			switch(var["Name"].to!string){
				case "DEJA_ENCHANTE":
					enchanted = var["Value"].to!bool;
					break;
				case "X2_LAST_PROPERTY":
					oldConst = var["Value"].as!(GffType.Int);
					break;
				default:
					break;
			}
		}
		if(oldConst <= 0){
			stderr.writeln("\x1b[1;31mWARNING: Item '", item["TemplateResRef"].to!string, "' has an invalid X2_LAST_PROPERTY value " ~ oldConst.to!string ~ "\x1b[m");
			return false;
		}

		if(enchanted && oldConst != int32_t.max){
			auto ench = oldConst.to!EnchantmentId;

			GffNode[] newVarTable;
			foreach(ref var ; item["VarTable"].as!(GffType.List)){
				switch(var["Name"].to!string){
					case "X2_LAST_PROPERTY":
						break;
					default:
						newVarTable ~= var;
				}
			}

			auto iprp = legacyConstToIprp(GetBaseItemType(item), ench);
			newVarTable ~= LocalVar("hagbe_iprp_t", GffType.Int, iprp.type);
			newVarTable ~= LocalVar("hagbe_iprp_st", GffType.Int, iprp.subType);
			newVarTable ~= LocalVar("hagbe_iprp_c", GffType.Int, iprp.costValue);
			newVarTable ~= LocalVar("hagbe_iprp_p1", GffType.Int, iprp.p1);

			item["VarTable"].as!(GffType.List) = newVarTable;

			return true;
		}
		return false;
	});
}

