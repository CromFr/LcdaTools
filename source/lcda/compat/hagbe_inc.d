module lcda.compat.hagbe_inc;

import std.exception;
import std.conv;
import nwn.gff;
import nwn.nwscript;

import lcda.compat._misc;
import lcda.compat._type_conversion;
import lcda.compat.x2_inc_itemprop;



struct EnhanceItemPropertyCostValueRet {
	NWInt act;// 0: impossible, 1: add, 2: replace, 3: remove,
	NWItemproperty ip_res;// IP result
	NWItemproperty ip_diff;// what the player payed for
}

// Combine two item properties together
EnhanceItemPropertyCostValueRet EnhanceItemPropertyCostValue(NWInt nBaseItemType, NWItemproperty ipCurrent, NWInt nCostValueBonus)
{
	EnhanceItemPropertyCostValueRet ret;

	int nType = GetItemPropertyType(ipCurrent);
	int nSubType = GetItemPropertySubType(ipCurrent);
	int nCostValue = GetItemPropertyCostTableValue(ipCurrent);

	// Hitpoint bonus can be added multiple times
	switch(nType){
		case ITEM_PROPERTY_DAMAGE_BONUS:
		case ITEM_PROPERTY_BONUS_HITPOINTS:
			ret.act = 1;
			ret.ip_res = BuildItemProperty(nType, nSubType, nCostValueBonus);
			ret.ip_diff = ret.ip_res;
			return ret;
		default: break;
	}

	switch(GetItemPropertyCostTable(ipCurrent))
	{
		case 1: // IPRP_BONUSCOST
			// From 1 to 12
			if(nCostValue + nCostValueBonus <= 12){
				ret.act = 2;
				ret.ip_res = BuildItemProperty(nType, nSubType, nCostValue + nCostValueBonus);
				ret.ip_diff = BuildItemProperty(nType, nSubType, nCostValueBonus);
			}
			else if(nCostValue < 12){
				ret.act = 2;
				ret.ip_res = BuildItemProperty(nType, nSubType, 12);
				ret.ip_diff = BuildItemProperty(nType, nSubType, 12 - nCostValue);
			}
			break;

		case 2: // IPRP_MELEECOST
			{
				// From 1 to 20
				if(nCostValue + nCostValueBonus <= 20){
					ret.act = 2;
					ret.ip_res = BuildItemProperty(nType, nSubType, nCostValue + nCostValueBonus);
					ret.ip_diff = BuildItemProperty(nType, nSubType, nCostValueBonus);
				}
				else if(nCostValue < 20){
					ret.act = 2;
					ret.ip_res = BuildItemProperty(nType, nSubType, 20);
					ret.ip_diff = BuildItemProperty(nType, nSubType, 20 - nCostValue);
				}
			}
			break;

		case 5: // IPRP_IMMUNCOST
			{
				int nCurrValue = IprpImmuCostToInt(nCostValue);
				int nBonusValue = IprpImmuCostToInt(nCostValueBonus);
				int nMax = 5;
				switch(nBaseItemType){
					case BASE_ITEM_ARMOR:
					case BASE_ITEM_HELMET:
					case BASE_ITEM_BELT:
						nMax = 10;
						break;
					default: break;
				}
				if(nCurrValue + nBonusValue <= nMax){
					int nNewCostValue = StringToIprpImmuCost(IntToString(nCurrValue + nBonusValue), FALSE);
					if(nNewCostValue > 0){
						ret.act = 2;
						ret.ip_res = BuildItemProperty(nType, nSubType, nNewCostValue);
						ret.ip_diff = BuildItemProperty(nType, nSubType, nCostValueBonus);
					}
				}
				else if(nCurrValue < nMax){
					int nDiffCostValue = StringToIprpImmuCost(IntToString(nMax - nCurrValue), FALSE);
					if(nDiffCostValue > 0){
						int nNewCostValue = StringToIprpImmuCost(IntToString(nMax));
						ret.act = 2;
						ret.ip_res = BuildItemProperty(nType, nSubType, nNewCostValue);
						ret.ip_diff = BuildItemProperty(nType, nSubType, nDiffCostValue);
					}
				}
			}
			break;

		case 7: // IPRP_RESISTCOST
			// resistance = costValue * 5
			// From id 1 to id 10
			if(nCostValue + nCostValueBonus <= 10){
				ret.act = 2;
				ret.ip_res = BuildItemProperty(nType, nSubType, nCostValue + nCostValueBonus);
				ret.ip_diff = BuildItemProperty(nType, nSubType, nCostValueBonus);
			}
			else if(nCostValue < 10){
				ret.act = 2;
				ret.ip_res = BuildItemProperty(nType, nSubType, 10);
				ret.ip_diff = BuildItemProperty(nType, nSubType, 10 - nCostValue);
			}
			break;

		case 11: // IPRP_SRCOST
			{
				int nCurrValue = IprpSRValueToInt(nCostValue);
				int nBonusValue = IprpSRValueToInt(nCostValueBonus);
				if(nCurrValue + nBonusValue <= 40){
					int nNewCostValue = IntToIprpSRValue(nCurrValue + nBonusValue);
					if(nNewCostValue >= 0){
						ret.act = 2;
						ret.ip_res = BuildItemProperty(nType, nSubType, nNewCostValue);
						ret.ip_diff = BuildItemProperty(nType, nSubType, nCostValue);
					}
				}
				else if(nCurrValue < 40){
					int nDiffCostValue = IntToIprpSRValue(40 - nCurrValue);
					if(nDiffCostValue > 0){
						ret.act = 2;
						ret.ip_res = BuildItemProperty(nType, nSubType, 15);//Bonus_40
						ret.ip_diff = BuildItemProperty(nType, nSubType, nDiffCostValue);
					}
				}
			}
			break;

		case 25: // IPRP_SKILLCOST
			// From 1 to 50
			if(nCostValue + nCostValueBonus <= 50){
				ret.act = 2;
				ret.ip_res = BuildItemProperty(nType, nSubType, nCostValue + nCostValueBonus);
				ret.ip_diff = BuildItemProperty(nType, nSubType, nCostValueBonus);
			}
			else if(nCostValue < 50){
				ret.act = 2;
				ret.ip_res = BuildItemProperty(nType, nSubType, 50);
				ret.ip_diff = BuildItemProperty(nType, nSubType, 50 - nCostValue);
			}
			break;

		case 27: // IPRP_ARCSPELL
			{
				int nCurrValue = StringToInt(Get2DAString("IPRP_ARCSPELL", "Value", nCostValue));
				int nBonusValue = StringToInt(Get2DAString("IPRP_ARCSPELL", "Value", nCostValueBonus));
				int nResValue = nCurrValue + nBonusValue;
				if(nResValue == 0){
					// The iprp should be removed
					ret.act = 3;
					ret.ip_res = BuildItemProperty(nType, nSubType, nCostValue);
					ret.ip_diff = ret.ip_res;
				}
				else{
					if(nResValue >= -50 && nResValue <= 50){
						int nNewCostValue = StringToIprpSpellFailure(IntToString(nResValue), FALSE);
						if(nNewCostValue >= 0){
							ret.act = 2;
							ret.ip_res = BuildItemProperty(nType, nSubType, nNewCostValue);
							ret.ip_diff = BuildItemProperty(nType, nSubType, nCostValue);
						}
					}
					else if(nCurrValue < 50 && nBonusValue > 0){
						int nDiffCostValue = StringToIprpSpellFailure(IntToString(50 - nCurrValue));
						if(nDiffCostValue > 0){
							ret.act = 2;
							ret.ip_res = BuildItemProperty(nType, nSubType, IP_CONST_ARCANE_SPELL_FAILURE_PLUS_50_PERCENT);
							ret.ip_diff = BuildItemProperty(nType, nSubType, nDiffCostValue);
						}
					}
					else if(nCurrValue > -50 && nBonusValue < 0){
						int nDiffCostValue = StringToIprpSpellFailure(IntToString(-50 - nCurrValue));
						if(nDiffCostValue > 0){
							ret.act = 2;
							ret.ip_res = BuildItemProperty(nType, nSubType, IP_CONST_ARCANE_SPELL_FAILURE_MINUS_50_PERCENT);
							ret.ip_diff = BuildItemProperty(nType, nSubType, nDiffCostValue);
						}

					}
				}
			}
			break;
		default:
			SignalBug(__FILE__ ~ ":" ~ IntToString(__LINE__) ~ ": Unhandled cost table " ~ IntToString(GetItemPropertyCostTable(ipCurrent)));
	}

	return ret;
}

EnhanceItemPropertyCostValueRet GetItemEnhancedItemProperty(ref GffStruct oItem, NWItemproperty ipToAdd){
	EnhanceItemPropertyCostValueRet ret;
	NWItemproperty ipExisting = GetSimilarItemProperty(oItem, ipToAdd);
	if(GetIsItemPropertyValid(ipExisting))
	{
		// Replace with similar property with higher cost value
		ret = EnhanceItemPropertyCostValue(
			GetBaseItemType(oItem),
			ipExisting,
			GetItemPropertyCostTableValue(ipToAdd)
		);
	}
	else{
		ret.act = 1;
		ret.ip_res = ipToAdd;
		ret.ip_diff = ipToAdd;
	}
	return ret;
}


NWItemproperty GetSimilarItemProperty(ref GffStruct oItem, NWItemproperty ipSimilar, int bIgnoreSubType = FALSE)
{
	int nType = GetItemPropertyType(ipSimilar);
	int nSubType = GetItemPropertySubType(ipSimilar);
	switch(nType)
	{
		case ITEM_PROPERTY_AC_BONUS:
		case ITEM_PROPERTY_ENHANCEMENT_BONUS:
		case ITEM_PROPERTY_DECREASED_ENHANCEMENT_MODIFIER:
		case ITEM_PROPERTY_BASE_ITEM_WEIGHT_REDUCTION:
		case ITEM_PROPERTY_DECREASED_DAMAGE:
		case ITEM_PROPERTY_DARKVISION:
		case ITEM_PROPERTY_ENHANCED_CONTAINER_REDUCED_WEIGHT:
		case ITEM_PROPERTY_HASTE:
		case ITEM_PROPERTY_HOLY_AVENGER:
		case ITEM_PROPERTY_IMPROVED_EVASION:
		case ITEM_PROPERTY_SPELL_RESISTANCE:
		case ITEM_PROPERTY_KEEN:
		case ITEM_PROPERTY_LIGHT:
		case ITEM_PROPERTY_MIGHTY:
		case ITEM_PROPERTY_NO_DAMAGE:
		case ITEM_PROPERTY_REGENERATION:
		case ITEM_PROPERTY_IMMUNITY_SPECIFIC_SPELL:
		case ITEM_PROPERTY_THIEVES_TOOLS:
		case ITEM_PROPERTY_ATTACK_BONUS:
		case ITEM_PROPERTY_DECREASED_ATTACK_MODIFIER:
		case ITEM_PROPERTY_UNLIMITED_AMMUNITION:
		case ITEM_PROPERTY_BONUS_HITPOINTS:
		case ITEM_PROPERTY_REGENERATION_VAMPIRIC:
		case ITEM_PROPERTY_TRUE_SEEING:
		case ITEM_PROPERTY_TURN_RESISTANCE:
		case ITEM_PROPERTY_MASSIVE_CRITICALS:
		case ITEM_PROPERTY_FREEDOM_OF_MOVEMENT:
		case ITEM_PROPERTY_MONSTER_DAMAGE:
		case ITEM_PROPERTY_IMMUNITY_SPELLS_BY_LEVEL:
		case ITEM_PROPERTY_HEALERS_KIT:
		case ITEM_PROPERTY_WEIGHT_INCREASE:
		case ITEM_PROPERTY_ARCANE_SPELL_FAILURE:
			bIgnoreSubType = TRUE;
			break;
		default: break;
	}

	NWItemproperty ip = GetFirstItemProperty(oItem);
	while(GetIsItemPropertyValid(ip))
	{
		if(GetItemPropertyType(ip) == nType)
		{
			if(bIgnoreSubType || GetItemPropertySubType(ip) == nSubType)
			{
				return ip;
			}
		}
		ip = GetNextItemProperty(oItem);
	}
	return ip;
}


int EnchantItem(ref GffStruct oItem, NWItemproperty iprp, int nCost)
{
	// Remove temporary properties
	IPRemoveAllItemProperties(oItem, DURATION_TYPE_TEMPORARY);

	int nIprpType = GetItemPropertyType(iprp);
	int nIprpSubType = GetItemPropertySubType(iprp);

	EnhanceItemPropertyCostValueRet ipToAdd = GetItemEnhancedItemProperty(oItem, iprp);

	if(ipToAdd.act == 0)
		return FALSE;
	else if(ipToAdd.act == 1){// add
		Enforce(GetIsItemPropertyValid(ipToAdd.ip_res), "Invalid IPRP to add: " ~ ItempropertyToString(ipToAdd.ip_res), __FILE__, __LINE__);
		AddItemProperty(DURATION_TYPE_PERMANENT, ipToAdd.ip_res, oItem);
	}
	else if(ipToAdd.act == 2){// replace
		Enforce(GetIsItemPropertyValid(ipToAdd.ip_res), "Invalid IPRP to replace: " ~ ItempropertyToString(ipToAdd.ip_res), __FILE__, __LINE__);
		IPSafeAddItemProperty(oItem, ipToAdd.ip_res, 0.0f, X2_IP_ADDPROP_POLICY_REPLACE_EXISTING);
	}
	else if(ipToAdd.act == 3){// remove
		Enforce(GetIsItemPropertyValid(ipToAdd.ip_res), "Invalid IPRP to remove: " ~ ItempropertyToString(ipToAdd.ip_res), __FILE__, __LINE__);
		RemoveItemProperty(oItem, ipToAdd.ip_res);
	}

	SetLocalInt(oItem, "DEJA_ENCHANTE", TRUE);
	SetLocalInt(oItem, "hagbe_iprp_t", GetItemPropertyType(ipToAdd.ip_diff));
	SetLocalInt(oItem, "hagbe_iprp_st", GetItemPropertySubType(ipToAdd.ip_diff));
	SetLocalInt(oItem, "hagbe_iprp_c", GetItemPropertyCostTableValue(ipToAdd.ip_diff));
	SetLocalInt(oItem, "hagbe_iprp_p1", GetItemPropertyParam1Value(ipToAdd.ip_diff));
	SetLocalInt(oItem, "hagbe_cost", nCost);
	SetFirstName(oItem, GetName(oItem) ~ " <c=#9257FF>*</c>");
	//WriteTimestampedLogEntry("[Hagbe] Enchanted item " ~ ObjectInfo(oItem) ~ " with " ~ ItempropertyToString(ipToAdd.ip_diff) ~ " (" ~ GetItemPropertyDescription(ipToAdd.ip_diff) ~ ")");
	return TRUE;
}