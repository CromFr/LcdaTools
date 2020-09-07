import std.stdio;
import std.parallelism;
import std.path;
import std.file;
import std.getopt;
import std.math;
import std.string;
import std.typecons;
import std.conv;
import std.exception;

import nwn.twoda;
import nwn.gff;

import lcda.config;

void main(string[] args)
{

	//auto res = LcdaConfig.init(args);
	//res.options ~= getopt(args).options;



	//TwoDA[string] twoDAs;
	//TwoDA getTwoDA(in string name){
	//	synchronized{
	//		if(name.toLower !in twoDAs){
	//			const path = buildPath(LcdaConfig["path_lcdaclientsrc"], "lcda2da.hak", name ~ ".2da");
	//			twoDAs[name.toLower] = new TwoDA(path);
	//		}
	//	}
	//	return twoDAs[name.toLower];
	//}
	//auto reqLevel2da = getTwoDA("skillvsitemcost");
	//auto baseitems2da = getTwoDA("baseitems");
	//auto itempropdef2da = getTwoDA("itempropdef");
	//auto costTableList2da = getTwoDA("iprp_costtable");


	auto reqLevel2da = new TwoDA(cast(ubyte[])`2DA V2.0

   LABEL DESIREDTREASURE MAXSINGLEITEMVALUE TOTALVALUEFILTER
0  1     0               1000               5000
1  2     0               1500               7500
2  3     0               2500               15000
3  4     0               3500               30000
4  5     0               5000               60000
5  6     0               6500               85000
6  7     0               9000               100000
7  8     0               12000              150000
8  9     0               15000              200000
9  10    0               19500              300000
10 11    0               25000              400000
11 12    0               30000              500000
12 13    0               35000              600000
13 14    0               40000              700000
14 15    0               50000              800000
15 16    0               65000              900000
16 17    0               75000              1000000
17 18    0               90000              1100000
18 19    0               110000             1200000
19 20    0               130000             1300000
20 21    0               250000             1500000
21 22    0               500000             1500000
22 23    0               750000             1500000
23 24    0               1000000            1500000
24 25    0               1200000            1500000
25 26    0               1400000            1500000
26 27    0               1600000            1500000
27 28    0               1800000            1500000
28 29    0               2000000            1500000
29 30    0               3000000            1500000
30 31    0               4000000            1500000
31 32    0               4000001            1500000
32 33    0               8000002            1500000
33 34    0               8000003            1500000
34 35    0               8000004            1500000
35 36    0               8000005            1500000
36 37    0               8000006            1500000
37 38    0               8000007            1500000
38 39    0               8000008            1500000
39 40    0               8000009            1500000
40 41    0               8200010            1500000
41 42    0               8200011            1500000
42 43    0               8200012            1500000
43 44    0               8200013            1500000
44 45    0               8200014            1500000
45 46    0               8200015            1500000
46 47    0               8200016            1500000
47 48    0               8200017            1500000
48 49    0               8200018            1500000
49 50    0               8200019            1500000
50 51    0               8200020            1500000
51 52    0               8200021            1500000
52 53    0               8200022            1500000
53 54    0               8200023            1500000
54 55    0               8200024            1500000
55 56    0               8200025            1500000
56 57    0               8200026            1500000
57 58    0               8200027            1500000
58 59    0               8200028            1500000
59 60    0               8200029            1500000
`);

	foreach(file ; parallel(args[1].dirEntries("*.uti", SpanMode.shallow))){
	//foreach(file ; parallel(LcdaConfig["path_lcdadev"].dirEntries("*.uti", SpanMode.shallow))){
		auto item = new Gff(file);

		try{
			Nullable!float targetLevel;
			foreach(ref var ; item["VarTable"].as!(GffType.List)){
				if(var["Name"].as!(GffType.ExoString) == "__required_level__"){
					targetLevel = var["Value"].as!(GffType.Float);
				}
			}

			if(!targetLevel.isNull){


				const priceMin = reqLevel2da[cast(int)targetLevel.get - 1, "MAXSINGLEITEMVALUE"].to!int;
				const priceMax = reqLevel2da[cast(int)targetLevel.get, "MAXSINGLEITEMVALUE"].to!int;

				const targetPrice = (priceMin + (priceMax - priceMin) * (targetLevel.get - cast(int)targetLevel.get)).to!long;
				const currentPrice = item["Cost"].as!(GffType.DWord);
				const modCost = targetPrice - currentPrice;

				try{
					item["ModifyCost"].as!(GffType.Int) = modCost.to!GffInt;
					std.file.write(file, item.serialize());
					writeln(file.baseName, " => currentPrice=", currentPrice, " targetPrice=", targetPrice, " modCost=", modCost);
				}
				catch(ConvException){

					writeln("ERROR: ", file.baseName, " => currentPrice=", currentPrice, " targetPrice=", targetPrice, " modCost=", modCost, ": Cannot convert ", modCost, " to GffInt");
				}

			}

			//const baseItemType = item["BaseItem"].as!(GffType.Int);

			//float propsCost = 0;
			//foreach(ref prop ; item["PropertiesList"].as!(GffType.List)){
			//	const type = prop["PropertyName"].as!(GffType.Word);
			//	const subtype = prop["Subtype"].as!(GffType.Word);
			//	const costTable = prop["CostTable"].as!(GffType.Byte);
			//	const costValue = prop["CostValue"].as!(GffType.Word);
			//	//const param1 = prop["Param1"].as!(GffType.Byte);
			//	//const param1Value = prop["Param1Value"].as!(GffType.Byte);
			//	//const param2 = prop["Param1"].as!(GffType.Byte);
			//	//const param2Value = prop["Param1Value"].as!(GffType.Byte);
			//	writeln("Prop: ", type, " ", costTable, " ", costValue);

			//	// Type
			//	auto typeCostMult = (itempropdef2da[type, "Cost"] != "" ? itempropdef2da[type, "Cost"].to!float : 1.0);

			//	// SubType
			//	float subTypeCost = 1.0;
			//	auto subTypeTableName = itempropdef2da[type, "SubTypeResRef"];
			//	if(subTypeTableName != ""){
			//		auto subTypeTable2da = getTwoDA(subTypeTableName);

			//		subTypeCost = subTypeTable2da[type, "Cost"] != "" ? subTypeTable2da[type, "Cost"].to!float : 1.0;
			//	}

			//	// CostValue
			//	enforce((itempropdef2da[type, "CostTableResRef"] == "" && costTable == 0) || costTable == itempropdef2da[type, "CostTableResRef"].to!int, "Cost table mismatch");

			//	float costValueCost = 1.0;
			//	auto costTableName = costTableList2da[costTable, "Name"];
			//	if(costTableName != ""){
			//		auto costTable2da = getTwoDA(costTableName);

			//		costValueCost = itempropdef2da[type, "CostTableResRef"] != "" ? costTable2da[costValue, "Cost"].to!float : 1.0;
			//	}

			//	writeln(" => typeCostMult=", typeCostMult, " subTypeCost=", subTypeCost, " costValueCost=", costValueCost);
			//	propsCost += typeCostMult * subTypeCost * costValueCost;
			//}

			//const itemBaseCost = baseitems2da[baseItemType, "BaseCost"].to!int;
			//const itemCostMultiplier = baseitems2da[baseItemType, "ItemMultiplier"].to!float;
			//writeln("itemBaseCost=", itemBaseCost, " propsCost=", propsCost, " ^^ 2 * 1000.0) * ", itemCostMultiplier);
			//auto cost = ((itemBaseCost + 1000.0 * propsCost ^^ 2) * itemCostMultiplier).to!long;

			//writeln("Calculated cost: ", cost, " vs stored: ", item["Cost"].as!(GffType.DWord));

			////item["ModifyCost"] = targetPrice - cost;

			////enforce(cost == item["Cost"].as!(GffType.DWord));
		}
		catch(Exception e){
			e.msg = "Exception for item " ~ file ~ ": " ~ e.msg;
			throw e;
		}




	}

}
