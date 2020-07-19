module lcda.util;

import nwn.gff;


auto GetBaseItemType(in GffNode item){
	return item["BaseItem"].as!(GffType.Int);
}


static GffNode LocalVar(T)(in string name, in GffType type, in T value){
	auto retStruct = GffNode(GffType.Struct);
	retStruct["Name"] = GffNode(GffType.ExoString, null, name);
	if(type == GffType.Int)
		retStruct["Type"] = GffNode(GffType.DWord, null, 1);
	else if(type == GffType.ExoString)
		retStruct["Type"] = GffNode(GffType.DWord, null, 3);
	else assert(0, "Unsupported type");

	retStruct["Value"] = GffNode(type, null, value);

	return retStruct;
}