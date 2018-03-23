import std.stdio;
import std.getopt;
import std.path;
import nwn.gff;

int main(string[] args)
{
	if(args.length != 2 && args.length != 3){
		writeln("Usage: ", args[0], " infile.bic [outfile.utc]");
		return 1;
	}
	auto targetFile = args.length == 3? args[2] : args[1].setExtension("utc");

	auto gff = new Gff(args[1]);


	immutable resref = args[1].baseName.stripExtension;

	gff.fileType = "UTC";

	//Set equipped item list resrefs
	foreach(ref item ; gff["Equip_ItemList"].as!(GffType.List)){

		auto newItem = GffNode(GffType.Struct);
		newItem.structType = item.structType;
		newItem["Repos_PosX"] = GffNode(GffType.Word, null, 0);
		newItem["Repos_PosY"] = GffNode(GffType.Word, null, 0);
		newItem["Pickpocketable"] = GffNode(GffType.Byte, null, 0);
		newItem["Dropable"] = GffNode(GffType.Byte, null, 0);
		newItem["EquippedRes"] = GffNode(GffType.ResRef, null, item["TemplateResRef"].to!string);

		item = newItem;
	}

	//Remove inventory items
	gff["ItemList"].as!(GffType.List).length = 0;

	//Set misc
	gff["TemplateResRef"].as!(GffType.ResRef) = resref;
	gff["Tag"].as!(GffType.ExoString) = resref;
	gff["FactionID"].as!(GffType.Word) = 1;
	gff["Classification"] = GffNode(GffType.ExoString, null, "");
	gff["IsPC"].as!(GffType.Byte) = 0;
	gff.as!(GffType.Struct).remove("LvlStatList");

	//Set scripts
	gff["ScriptAttacked"].as!(GffType.ResRef) = "nw_c2_default5";
	gff["ScriptDamaged"].as!(GffType.ResRef) = "nw_c2_default6";
	gff["ScriptDeath"].as!(GffType.ResRef) = "nw_c2_default7";
	gff["ScriptDialogue"].as!(GffType.ResRef) = "nw_c2_default4";
	gff["ScriptDisturbed"].as!(GffType.ResRef) = "nw_c2_default8";
	gff["ScriptEndRound"].as!(GffType.ResRef) = "nw_c2_default3";
	gff["ScriptHeartbeat"].as!(GffType.ResRef) = "nw_c2_default1";
	gff["ScriptOnBlocked"].as!(GffType.ResRef) = "nw_c2_defaulte";
	gff["ScriptOnNotice"].as!(GffType.ResRef) = "nw_c2_default2";
	gff["ScriptRested"].as!(GffType.ResRef) = "nw_c2_defaulta";
	gff["ScriptSpawn"].as!(GffType.ResRef) = "nw_c2_default9";
	gff["ScriptSpellAt"].as!(GffType.ResRef) = "nw_c2_defaultb";
	gff["ScriptUserDefine"].as!(GffType.ResRef) = "nw_c2_defaultd";



	//Write file
	import std.file: writeFile = write;
	writeFile(targetFile, gff.serialize());

	return 0;
}
