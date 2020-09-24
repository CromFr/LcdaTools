module lcda.compat._type_conversion;

import std.string;

import nwn.nwscript;
import lcda.compat._misc;

NWItemproperty BuildItemProperty(NWInt nType, NWInt nSubType = -1, NWInt nCostValue = -1, NWInt nParam1 = -1){
	return NWItemproperty(nType, nSubType, nCostValue, nParam1);
}

// iprp_immuncost.2da
NWInt StringToIprpImmuCost(NWString sImmuCost, NWInt bRaiseBug = TRUE){
	if     (sImmuCost == "5")   return IP_CONST_DAMAGEIMMUNITY_5_PERCENT;
	else if(sImmuCost == "10")  return IP_CONST_DAMAGEIMMUNITY_10_PERCENT;
	else if(sImmuCost == "25")  return IP_CONST_DAMAGEIMMUNITY_25_PERCENT;
	else if(sImmuCost == "50")  return IP_CONST_DAMAGEIMMUNITY_50_PERCENT;
	else if(sImmuCost == "75")  return IP_CONST_DAMAGEIMMUNITY_75_PERCENT;
	else if(sImmuCost == "90")  return IP_CONST_DAMAGEIMMUNITY_90_PERCENT;
	else if(sImmuCost == "100") return IP_CONST_DAMAGEIMMUNITY_100_PERCENT;
	else if(sImmuCost == "15")  return 8;
	else if(sImmuCost == "20")  return 9;
	else if(sImmuCost == "30")  return 10;
	else if(bRaiseBug) SignalBug(__FILE__~":"~__FUNCTION__~": Unknown immu value string: '"~sImmuCost~"'");
	return -1;
}
NWString IprpImmuCostToString(NWInt nImmuCost, NWInt bRaiseBug = TRUE){
	if(bRaiseBug && nImmuCost < 0 || nImmuCost > 10)
		SignalBug(__FILE__~":"~__FUNCTION__~": Unknown immu value: '"~IntToString(nImmuCost)~"'");
	return Get2DAString("iprp_immuncost", "Value", nImmuCost);
}
NWInt IprpImmuCostToInt(NWInt nImmuCost, NWInt bRaiseBug = TRUE){
	return StringToInt(IprpImmuCostToString(nImmuCost, bRaiseBug));
}


NWInt IprpSRValueToInt(NWInt nIprpSRValue, NWInt bRaiseBug = TRUE){
	switch(nIprpSRValue){
		case 0:  return 10;
		case 1:  return 12;
		case 2:  return 14;
		case 3:  return 16;
		case 4:  return 18;
		case 5:  return 20;
		case 6:  return 22;
		case 7:  return 24;
		case 8:  return 26;
		case 9:  return 28;
		case 10: return 30;
		case 11: return 32;
		case 12: return 34;
		case 13: return 36;
		case 14: return 38;
		case 15: return 40;
		case 16: return 19;
		default: break;
	}
	if(bRaiseBug) SignalBug(__FILE__~":"~__FUNCTION__~": Unknown IPRP SR value int: '"~IntToString(nIprpSRValue)~"'");
	return -1;
}

NWInt IntToIprpSRValue(NWInt nValue, NWInt bRaiseBug = TRUE){
	while(nValue > 0){
		switch(nValue){
			case 10: return 0;
			case 12: return 1;
			case 14: return 2;
			case 16: return 3;
			case 18: return 4;
			case 20: return 5;
			case 22: return 6;
			case 24: return 7;
			case 26: return 8;
			case 28: return 9;
			case 30: return 10;
			case 32: return 11;
			case 34: return 12;
			case 36: return 13;
			case 38: return 14;
			case 40: return 15;
			case 19: return 16;
			default: break;
		}
		nValue--;
	}
	if(bRaiseBug) SignalBug(__FILE__~":"~__FUNCTION__~": Unknown SR value int: '"~IntToString(nValue)~"'");
	return -1;
}


NWInt StringToIprpSpellFailure(NWString sSpellFailure, NWInt bRaiseBug = TRUE){
	if     (sSpellFailure == "-50") return 0;
	else if(sSpellFailure == "-45") return 1;
	else if(sSpellFailure == "-40") return 2;
	else if(sSpellFailure == "-35") return 3;
	else if(sSpellFailure == "-30") return 4;
	else if(sSpellFailure == "-25") return 5;
	else if(sSpellFailure == "-20") return 6;
	else if(sSpellFailure == "-15") return 7;
	else if(sSpellFailure == "-10") return 8;
	else if(sSpellFailure == "-5")  return 9;
	else if(sSpellFailure == "5")   return 10;
	else if(sSpellFailure == "10")  return 11;
	else if(sSpellFailure == "15")  return 12;
	else if(sSpellFailure == "20")  return 13;
	else if(sSpellFailure == "25")  return 14;
	else if(sSpellFailure == "30")  return 15;
	else if(sSpellFailure == "35")  return 16;
	else if(sSpellFailure == "40")  return 17;
	else if(sSpellFailure == "45")  return 18;
	else if(sSpellFailure == "50")  return 19;
	else if(bRaiseBug) SignalBug(__FILE__~":"~__FUNCTION__~": Unknown saving spell failure string: '"~sSpellFailure~"'");
	return -1;
}

NWString ItempropertyToString(NWItemproperty ip){
	return format!"(%d,%d,%d,%d)"(ip.type, ip.subType, ip.costValue, ip.p1);
}