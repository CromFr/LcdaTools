import std.stdio;
import std.getopt;
import nwn.gff;

int main(string[] args)
{
	if(args.length != 3){
		writeln("Usage: ", args[0], " infile.bic outfile.utc");
		return 1;
	}

	auto gff = new Gff(args[1]);

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

	//Write file
	import std.file: writeFile = write;
	writeFile(args[2], gff.serialize());

	return 0;
}
