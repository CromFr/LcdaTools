module lcda.hagbe;

import std.stdint;
import std.conv;
import std.exception;
import std.string: indexOf;
import nwn.gff;
import nwn.twoda;
import nwn.tlk: StrRefResolver;
import nwn.nwscript;
import lcda.config: getTwoDA;

class EnchantmentException : Exception{
	@safe pure nothrow this(string msg, string f=__FILE__, size_t l=__LINE__, Throwable t=null){
		super(msg, f, l, t);
	}
}

//bool addEnchantmentSuffix(ref GffNode item, in StrRefResolver tlkResolver){

//	auto locName = tlkResolver[item["LocalizedName"]];
//	if(locName.indexOf("<c=#9257FF>*</c>") == -1){
//		auto locStr = &item["LocalizedName"].as!(GffType.ExoLocString)();

//		if(locStr.strings.length > 0){
//			foreach(lang, ref str ; locStr.strings)
//				str ~= " <c=#9257FF>*</c>";
//		}
//		else
//			locStr.strings[0] = locName ~ " <c=#9257FF>*</c>";
//		return true;
//	}
//	return false;
//}

//bool isEnchanted(in GffNode item){
//	if("VarTable" in item.as!(GffType.Struct)){
//		foreach(ref var ; item["VarTable"].as!(GffType.List)){
//			if(var["Name"].as!(GffType.ExoString) == "DEJA_ENCHANTE" && var["Value"].as!(GffType.Int) == 1){
//				return true;
//			}
//		}
//	}
//	return false;
//}

//void enchantItem(ref GffNode item, NWItemproperty iprp, in StrRefResolver tlkResolver){
//	GffNode* findExistingProperty(in NWItemproperty iprp){
//		foreach(ref prop ; item["PropertiesList"].as!(GffType.List)){
//			if(prop["PropertyName"].as!(GffType.Word) == iprp.type
//				&& (iprp.subType!=uint16_t.max? prop["Subtype"].as!(GffType.Word)==iprp.subType : true))
//				return &prop;
//		}
//		return null;
//	}


//	auto baseItemType = item["BaseItem"].to!uint;

//	auto ipToAdd = NWItemproperty();
//	if("VarTable" in item.as!(GffType.Struct)){
//		foreach(ref var ; item["VarTable"].as!(GffType.List)){
//			switch(var["Name"].as!(GffType.ExoString)){
//				case "hagbe_iprp_t":  ipToAdd.type = var["Value"].as!(GffType.Int); break;
//				case "hagbe_iprp_st": ipToAdd.subType = var["Value"].as!(GffType.Int); break;
//				case "hagbe_iprp_c":  ipToAdd.costValue = var["Value"].as!(GffType.Int); break;
//				case "hagbe_iprp_p1": ipToAdd.p1 = var["Value"].as!(GffType.Int); break;
//				default: break;
//			}
//		}
//	}

//	switch(iprp.type){

//		case 16://dmg bonus
//		case 26://DarkVision
//		case 35://Haste
//		case 37://Misc immunities (abs, fear, death)
//		case 43://Keen
//		case 61://Unlimited ammo
//		case 71://TrueSeeing
//		case 75://FreeAction
//			//Add only if property does not exist (properties without CostValue)
//			if(iprp.type!=16 && iprp.type!=61)
//				assert(getTwoDA("itempropdef").get("CostTableResRef", iprp.type) is null,
//					"Property "~iprp.to!string~" has a cost value table and is handled as if there were none");

//			enforce!EnchantmentException(findExistingProperty(iprp) is null,
//				"Enchantment "~iprp.toString~" already exist on the updated version");

//			item["PropertiesList"].as!(GffType.List) ~= buildPropertyUsing2DA(iprp);

//			addEnchantmentSuffix(item, tlkResolver);
//			return;

//		default:
//			//Merge by adding CostValue
//			immutable costTableResref = getTwoDA("itempropdef").get("CostTableResRef", iprp.type);
//			assert(costTableResref !is null,
//				"Property "~iprp.to!string~" has no cost value table and is handled as if there were one");

//			if(auto prop = findExistingProperty(iprp)){
//				//merge with existing
//				enforce!EnchantmentException(iprp.type != 39,//Spell resistance
//					"Cannot merge "~iprp.toString~" with existing property (not handled yet)");


//				GffWord newCostValue, maxCostValue;
//				if(iprp.type == 39){
//					//Spell resistance
//					//+10 SR => +5 index in 2da
//					//max index: 15
//					assert(iprp.costValue==0);

//					maxCostValue = 15;
//					newCostValue = cast(GffWord)((*prop)["CostValue"].as!(GffType.Word) + 5);
//				}
//				else{
//					immutable costValueTableIndex = getTwoDA("itempropdef").get("CostTableResRef", iprp.type);
//					immutable costValueTable = getTwoDA("iprp_costtable").get("Name", costValueTableIndex.to!uint);

//					maxCostValue = cast(GffWord)(getTwoDA(costValueTable).rows-1);
//					newCostValue = cast(GffWord)((*prop)["CostValue"].as!(GffType.Word) + iprp.costValue);
//				}

//				enforce!EnchantmentException(newCostValue <= maxCostValue,
//					"Cannot merge enchantment "~iprp.toString~": CostValue "~newCostValue.to!string~" is too high");

//				(*prop)["CostValue"].as!(GffType.Word) = newCostValue;
//			}
//			else{
//				//append
//				item["PropertiesList"].as!(GffType.List) ~= buildPropertyUsing2DA(iprp);
//			}

//			addEnchantmentSuffix(item, tlkResolver);
//			return;
//	}
//	assert(0);
//}





//GffNode buildPropertyUsing2DA(in NWItemproperty iprp, uint8_t param1Value=uint8_t.max){
//	GffNode ret = GffNode(GffType.Struct);
//	with(ret){
//		assert(iprp.type < getTwoDA("itempropdef").rows);

//		appendField(GffNode(GffType.Word, "PropertyName", iprp.type));

//		immutable subTypeTable = getTwoDA("itempropdef").get("SubTypeResRef", iprp.type);
//		if(subTypeTable is null)
//			assert(iprp.subType==uint16_t.max, "iprp.subType pointing to non-existent SubTypeTable");
//		else
//			assert(iprp.subType!=uint16_t.max, "iprp.subType must be defined");

//		appendField(GffNode(GffType.Word, "Subtype", iprp.subType));

//		string costTableResRef = getTwoDA("itempropdef").get("CostTableResRef", iprp.type);
//		if(costTableResRef is null)
//			assert(iprp.costValue==uint16_t.max, "iprp.costValue pointing to non-existent CostTableResRef");
//		else
//			assert(iprp.costValue!=uint16_t.max, "iprp.costValue must be defined");

//		appendField(GffNode(GffType.Byte, "CostTable", costTableResRef !is null? costTableResRef.to!ubyte : ubyte.max));
//		appendField(GffNode(GffType.Word, "CostValue", iprp.costValue));


//		immutable paramTableResRef = getTwoDA("itempropdef").get("Param1ResRef", iprp.type);
//		if(paramTableResRef !is null){
//			assert(param1Value!=uint8_t.max, "param1Value must be defined");
//			appendField(GffNode(GffType.Byte, "Param1", paramTableResRef.to!ubyte));
//			appendField(GffNode(GffType.Byte, "Param1Value", param1Value));
//		}
//		else{
//			assert(param1Value==uint8_t.max, "param1Value pointing to non-existent Param1ResRef");
//			appendField(GffNode(GffType.Byte, "Param1", uint8_t.max));
//			appendField(GffNode(GffType.Byte, "Param1Value", uint8_t.max));
//		}

//		appendField(GffNode(GffType.Byte, "ChanceAppear", 100));
//		appendField(GffNode(GffType.Byte, "UsesPerDay",   255));
//		appendField(GffNode(GffType.Byte, "Useable",      1));
//	}
//	return ret;
//}





import lcda.compat.lib_forge_epique: EnchantmentId;

deprecated
NWItemproperty legacyConstToIprp(uint baseItemType, EnchantmentId enchantType){
	//Indices are found in itempropdef.2da
	final switch(enchantType) with(EnchantmentId){
		case DAMAGETYPE_ACID:
		case DAMAGETYPE_SONIC:
		case DAMAGETYPE_FIRE:
		case DAMAGETYPE_COLD:
		case DAMAGETYPE_ELECTRICAL:
		case DAMAGETYPE_NEGATIVE:
		case DAMAGETYPE_POSITIVE:
		case DAMAGETYPE_DIVINE:                     return NWItemproperty(16, enchantType, 7);//7 is for 1d6
		case ARMOR_STRENGTH_BONUS2:                 return NWItemproperty(0,  0,           2);
		case ARMOR_DEXTERITY_BONUS2:                return NWItemproperty(0,  1,           2);
		case ARMOR_CONSTITUTION_BONUS2:             return NWItemproperty(0,  2,           2);
		case ARMOR_INTELLIGENCE_BONUS2:             return NWItemproperty(0,  3,           2);
		case ARMOR_WISDOM_BONUS2:                   return NWItemproperty(0,  4,           2);
		case ARMOR_CHARISMA_BONUS2:                 return NWItemproperty(0,  5,           2);
		case BRACERS_BELT_STRENGTH_BONUS2:          return NWItemproperty(0,  0,           2);
		case BRACERS_BELT_DEXTERITY_BONUS2:         return NWItemproperty(0,  1,           2);
		case BRACERS_BELT_CONSTITUTION_BONUS2:      return NWItemproperty(0,  2,           2);
		case BRACERS_BELT_INTELLIGENCE_BONUS2:      return NWItemproperty(0,  3,           2);
		case BRACERS_BELT_WISDOM_BONUS2:            return NWItemproperty(0,  4,           2);
		case BRACERS_BELT_CHARISMA_BONUS2:          return NWItemproperty(0,  5,           2);
		case HELM_STRENGTH_BONUS2:                  return NWItemproperty(0,  0,           2);
		case HELM_DEXTERITY_BONUS2:                 return NWItemproperty(0,  1,           2);
		case HELM_CONSTITUTION_BONUS2:              return NWItemproperty(0,  2,           2);
		case HELM_INTELLIGENCE_BONUS2:              return NWItemproperty(0,  3,           2);
		case HELM_WISDOM_BONUS2:                    return NWItemproperty(0,  4,           2);
		case HELM_CHARISMA_BONUS2:                  return NWItemproperty(0,  5,           2);
		case AMULET_STRENGTH_BONUS2:                return NWItemproperty(0,  0,           2);
		case AMULET_DEXTERITY_BONUS2:               return NWItemproperty(0,  1,           2);
		case AMULET_CONSTITUTION_BONUS2:            return NWItemproperty(0,  2,           2);
		case AMULET_INTELLIGENCE_BONUS2:            return NWItemproperty(0,  3,           2);
		case AMULET_WISDOM_BONUS2:                  return NWItemproperty(0,  4,           2);
		case AMULET_CHARISMA_BONUS2:                return NWItemproperty(0,  5,           2);
		case RING_STRENGTH_BONUS2:                  return NWItemproperty(0,  0,           2);
		case RING_DEXTERITY_BONUS2:                 return NWItemproperty(0,  1,           2);
		case RING_CONSTITUTION_BONUS2:              return NWItemproperty(0,  2,           2);
		case RING_INTELLIGENCE_BONUS2:              return NWItemproperty(0,  3,           2);
		case RING_WISDOM_BONUS2:                    return NWItemproperty(0,  4,           2);
		case RING_CHARISMA_BONUS2:                  return NWItemproperty(0,  5,           2);
		case BOOTS_STRENGTH_BONUS2:                 return NWItemproperty(0,  0,           2);
		case BOOTS_DEXTERITY_BONUS2:                return NWItemproperty(0,  1,           2);
		case BOOTS_CONSTITUTION_BONUS2:             return NWItemproperty(0,  2,           2);
		case BOOTS_INTELLIGENCE_BONUS2:             return NWItemproperty(0,  3,           2);
		case BOOTS_WISDOM_BONUS2:                   return NWItemproperty(0,  4,           2);
		case BOOTS_CHARISMA_BONUS2:                 return NWItemproperty(0,  5,           2);
		case CLOAK_STRENGTH_BONUS2:                 return NWItemproperty(0,  0,           2);
		case CLOAK_DEXTERITY_BONUS2:                return NWItemproperty(0,  1,           2);
		case CLOAK_CONSTITUTION_BONUS2:             return NWItemproperty(0,  2,           2);
		case CLOAK_INTELLIGENCE_BONUS2:             return NWItemproperty(0,  3,           2);
		case CLOAK_WISDOM_BONUS2:                   return NWItemproperty(0,  4,           2);
		case CLOAK_CHARISMA_BONUS2:                 return NWItemproperty(0,  5,           2);
		case SHIELD_STRENGTH_BONUS2:                return NWItemproperty(0,  0,           2);
		case SHIELD_DEXTERITY_BONUS2:               return NWItemproperty(0,  1,           2);
		case SHIELD_CONSTITUTION_BONUS2:            return NWItemproperty(0,  2,           2);
		case SHIELD_INTELLIGENCE_BONUS2:            return NWItemproperty(0,  3,           2);
		case SHIELD_WISDOM_BONUS2:                  return NWItemproperty(0,  4,           2);
		case SHIELD_CHARISMA_BONUS2:                return NWItemproperty(0,  5,           2);
		case ARMOR_BONUS_CA2:                       return NWItemproperty(1,  -1,          2);
		case CLOAK_PARADE_BONUS2:                   return NWItemproperty(1,  -1,          2);
		case BRACERS_BELT_CA_VS_BLUDGEONING_BONUS5: return NWItemproperty(3,  0,           5);
		case BRACERS_BELT_CA_VS_PIERCING_BONUS5:    return NWItemproperty(3,  1,           5);
		case BRACERS_BELT_CA_VS_SLASHING_BONUS5:    return NWItemproperty(3,  2,           5);
		case ENHANCEMENT_BONUS:                     return NWItemproperty(6,  -1,          1);
		case ENHANCEMENT_BONUS2:                    return NWItemproperty(6,  -1,          2);
		case HELM_DAMAGERESISTANCE5_BLUDGEONING:    return NWItemproperty(23, 0,           1);
		case HELM_DAMAGERESISTANCE5_PIERCING:       return NWItemproperty(23, 1,           1);
		case HELM_DAMAGERESISTANCE5_SLASHING:       return NWItemproperty(23, 2,           1);
		case HELM_DAMAGERESISTANCE5_MAGICAL:        return NWItemproperty(23, 5,           1);
		case HELM_DAMAGERESISTANCE5_ACID:           return NWItemproperty(23, 6,           1);
		case HELM_DAMAGERESISTANCE5_COLD:           return NWItemproperty(23, 7,           1);
		case HELM_DAMAGERESISTANCE5_DIVINE:         return NWItemproperty(23, 8,           1);
		case HELM_DAMAGERESISTANCE5_ELECTRICAL:     return NWItemproperty(23, 9,           1);
		case HELM_DAMAGERESISTANCE5_FIRE:           return NWItemproperty(23, 10,          1);
		case HELM_DAMAGERESISTANCE5_NEGATIVE:       return NWItemproperty(23, 11,          1);
		case HELM_DAMAGERESISTANCE5_POSITIVE:       return NWItemproperty(23, 12,          1);
		case HELM_DAMAGERESISTANCE5_SONIC:          return NWItemproperty(23, 13,          1);
		case BOOTS_DARKVISION:                      return NWItemproperty(26);
		case HASTE:                                 return NWItemproperty(35);
		case RING_IMMUNE_ABSORBTION:                return NWItemproperty(37, 1);
		case RING_IMMUNE_TERROR:                    return NWItemproperty(37, 5);
		case RING_IMMUNE_DEATH:                     return NWItemproperty(37, 9);
		case SPELLRESISTANCE:                       return NWItemproperty(39, -1,          0);//+10
		case SHIELD_SPELLRESISTANCE10:              return NWItemproperty(39, -1,          0);//+10
		case SHIELD_BONUS_VIG_PLUS7:                return NWItemproperty(41, 1,           7);
		case SHIELD_BONUS_VOL_PLUS7:                return NWItemproperty(41, 2,           7);
		case SHIELD_BONUS_REF_PLUS7:                return NWItemproperty(41, 3,           7);
		case KEEN:                                  return NWItemproperty(43);
		case MIGHTY_5:                              return NWItemproperty(45, -1,          5);
		case MIGHTY_10:                             return NWItemproperty(45, -1,          10);
		case MIGHTY_15:                             return NWItemproperty(45, -1,          15);
		case MIGHTY_20:                             return NWItemproperty(45, -1,          20);
		case REGENERATION:                          return NWItemproperty(51, -1,          2);
		case BOOTS_REGENERATION1:                   return NWItemproperty(51, -1,          2);
		case SHIELD_REGENERATION1:                  return NWItemproperty(51, -1,          2);
		case AMULET_SKILL_CONCENTRATION_BONUS15:    return NWItemproperty(52, 1,           15);
		case AMULET_SKILL_DISABLE_TRAP_BONUS15:     return NWItemproperty(52, 2,           15);
		case AMULET_SKILL_DISCIPLINE_BONUS15:       return NWItemproperty(52, 3,           15);
		case AMULET_SKILL_HEAL_BONUS15:             return NWItemproperty(52, 4,           15);
		case AMULET_SKILL_HIDE_BONUS15:             return NWItemproperty(52, 5,           15);
		case AMULET_SKILL_LISTEN_BONUS15:           return NWItemproperty(52, 6,           15);
		case AMULET_SKILL_LORE_BONUS15:             return NWItemproperty(52, 7,           15);
		case AMULET_SKILL_MOVE_SILENTLY_BONUS15:    return NWItemproperty(52, 8,           15);
		case AMULET_SKILL_OPEN_LOCK_BONUS15:        return NWItemproperty(52, 9,           15);
		case AMULET_SKILL_PARRY_BONUS15:            return NWItemproperty(52, 10,          15);
		case AMULET_SKILL_PERFORM_BONUS15:          return NWItemproperty(52, 11,          15);
		case AMULET_SKILL_DIPLOMACY_BONUS15:        return NWItemproperty(52, 12,          15);
		case AMULET_SKILL_PERSUADE_BONUS15:         return NWItemproperty(52, 12,          15);//Diplomacy
		case AMULET_SKILL_SLEIGHT_OF_HAND_BONUS15:  return NWItemproperty(52, 13,          15);
		case AMULET_SKILL_PICK_POCKET_BONUS15:      return NWItemproperty(52, 13,          15);//SleightOfHand
		case AMULET_SKILL_SEARCH_BONUS15:           return NWItemproperty(52, 14,          15);
		case AMULET_SKILL_SET_TRAP_BONUS15:         return NWItemproperty(52, 15,          15);
		case AMULET_SKILL_SPELLCRAFT_BONUS15:       return NWItemproperty(52, 16,          15);
		case AMULET_SKILL_SPOT_BONUS15:             return NWItemproperty(52, 17,          15);
		case AMULET_SKILL_TAUNT_BONUS15:            return NWItemproperty(52, 18,          15);
		case AMULET_SKILL_USE_MAGIC_DEVICE_BONUS15: return NWItemproperty(52, 19,          15);
		case AMULET_SKILL_APPRAISE_BONUS15:         return NWItemproperty(52, 20,          15);
		case AMULET_SKILL_TUMBLE_BONUS15:           return NWItemproperty(52, 21,          15);
		case AMULET_SKILL_CRAFT_TRAP_BONUS15:       return NWItemproperty(52, 22,          15);
		case AMULET_SKILL_BLUFF_BONUS15:            return NWItemproperty(52, 23,          15);
		case AMULET_SKILL_INTIMIDATE_BONUS15:       return NWItemproperty(52, 24,          15);
		case AMULET_SKILL_CRAFT_ARMOR_BONUS15:      return NWItemproperty(52, 25,          15);
		case AMULET_SKILL_CRAFT_WEAPON_BONUS15:     return NWItemproperty(52, 26,          15);
		case AMULET_SKILL_CRAFT_ALCHEMY_BONUS15:    return NWItemproperty(52, 27,          15);
		case AMULET_SKILL_SURVIVAL_BONUS15:         return NWItemproperty(52, 29,          15);
		case ATTACK_BONUS:                          return NWItemproperty(56, -1,          1);
		case ATTACK_BONUS2:                         return NWItemproperty(56, -1,          2);
		case ATTACK_BONUS3:                         return NWItemproperty(56, -1,          3);
		case ATTACK_BONUS4:                         return NWItemproperty(56, -1,          4);
		case UNLIMITED_3:
			switch(baseItemType){
				case 8: case 11:                    return NWItemproperty(61, 0,           15);//Bow
				case 6: case 7:                     return NWItemproperty(61, 1,           15);//XBow
				case 61:                            return NWItemproperty(61, 2,           15);//Sling
				default: throw new EnchantmentException("Cannot add Unlimited enchantment to item type "~baseItemType.to!string);
			}
		case TRUESEEING:                            return NWItemproperty(71);
		case RING_FREEACTION:                       return NWItemproperty(75);
		case ARMOR_FREEACTION:                      return NWItemproperty(75);
	}
}