module lcda.hagbe;

import std.stdint;
import std.conv;
import std.exception;
import nwn.gff;
import nwn.twoda;
import lcda.config: getTwoDA;
import lcda.compat.lib_forge_epique;

struct PropType{
	uint32_t propertyName;
	uint32_t subType = uint16_t.max;
	uint32_t costValue = uint16_t.max;

	string toString() const{
		immutable propNameLabel = getTwoDA("itempropdef").get("Label", propertyName);

		immutable subTypeTable = getTwoDA("itempropdef").get("SubTypeResRef", propertyName);
		string subTypeLabel;
		try subTypeLabel = subTypeTable is null? null : getTwoDA(subTypeTable).get("Label", subType);
		catch(TwoDAColumnNotFoundException){
			subTypeLabel = subTypeTable is null? null : getTwoDA(subTypeTable).get("NameString", subType);
		}

		immutable costValueTableIndex = getTwoDA("itempropdef").get("CostTableResRef", propertyName);
		immutable costValueTable = costValueTableIndex is null? null : getTwoDA("iprp_costtable").get("Name", costValueTableIndex.to!uint);

		immutable costValueLabel = costValueTable is null? null : getTwoDA(costValueTable).get("Label", costValue);

		return propNameLabel
			~(subTypeLabel is null? null : "."~subTypeLabel)
			~(costValueLabel is null? null : "("~costValueLabel~")");
	}
}

PropType getPropertyType(uint baseItemType, EnchantmentId enchantType){
	//Indices are found in itempropdef.2da
	final switch(enchantType) with(EnchantmentId){
		case DAMAGETYPE_ACID:
		case DAMAGETYPE_SONIC:
		case DAMAGETYPE_FIRE:
		case DAMAGETYPE_COLD:
		case DAMAGETYPE_ELECTRICAL:
		case DAMAGETYPE_NEGATIVE:
		case DAMAGETYPE_POSITIVE:
		case DAMAGETYPE_DIVINE:                     return PropType(16, enchantType,  7);//7 is for 1d6
		case ARMOR_STRENGTH_BONUS2:                 return PropType(0,  0,            2);
		case ARMOR_DEXTERITY_BONUS2:                return PropType(0,  1,            2);
		case ARMOR_CONSTITUTION_BONUS2:             return PropType(0,  2,            2);
		case ARMOR_INTELLIGENCE_BONUS2:             return PropType(0,  3,            2);
		case ARMOR_WISDOM_BONUS2:                   return PropType(0,  4,            2);
		case ARMOR_CHARISMA_BONUS2:                 return PropType(0,  5,            2);
		case BRACERS_BELT_STRENGTH_BONUS2:          return PropType(0,  0,            2);
		case BRACERS_BELT_DEXTERITY_BONUS2:         return PropType(0,  1,            2);
		case BRACERS_BELT_CONSTITUTION_BONUS2:      return PropType(0,  2,            2);
		case BRACERS_BELT_INTELLIGENCE_BONUS2:      return PropType(0,  3,            2);
		case BRACERS_BELT_WISDOM_BONUS2:            return PropType(0,  4,            2);
		case BRACERS_BELT_CHARISMA_BONUS2:          return PropType(0,  5,            2);
		case HELM_STRENGTH_BONUS2:                  return PropType(0,  0,            2);
		case HELM_DEXTERITY_BONUS2:                 return PropType(0,  1,            2);
		case HELM_CONSTITUTION_BONUS2:              return PropType(0,  2,            2);
		case HELM_INTELLIGENCE_BONUS2:              return PropType(0,  3,            2);
		case HELM_WISDOM_BONUS2:                    return PropType(0,  4,            2);
		case HELM_CHARISMA_BONUS2:                  return PropType(0,  5,            2);
		case AMULET_STRENGTH_BONUS2:                return PropType(0,  0,            2);
		case AMULET_DEXTERITY_BONUS2:               return PropType(0,  1,            2);
		case AMULET_CONSTITUTION_BONUS2:            return PropType(0,  2,            2);
		case AMULET_INTELLIGENCE_BONUS2:            return PropType(0,  3,            2);
		case AMULET_WISDOM_BONUS2:                  return PropType(0,  4,            2);
		case AMULET_CHARISMA_BONUS2:                return PropType(0,  5,            2);
		case RING_STRENGTH_BONUS2:                  return PropType(0,  0,            2);
		case RING_DEXTERITY_BONUS2:                 return PropType(0,  1,            2);
		case RING_CONSTITUTION_BONUS2:              return PropType(0,  2,            2);
		case RING_INTELLIGENCE_BONUS2:              return PropType(0,  3,            2);
		case RING_WISDOM_BONUS2:                    return PropType(0,  4,            2);
		case RING_CHARISMA_BONUS2:                  return PropType(0,  5,            2);
		case BOOTS_STRENGTH_BONUS2:                 return PropType(0,  0,            2);
		case BOOTS_DEXTERITY_BONUS2:                return PropType(0,  1,            2);
		case BOOTS_CONSTITUTION_BONUS2:             return PropType(0,  2,            2);
		case BOOTS_INTELLIGENCE_BONUS2:             return PropType(0,  3,            2);
		case BOOTS_WISDOM_BONUS2:                   return PropType(0,  4,            2);
		case BOOTS_CHARISMA_BONUS2:                 return PropType(0,  5,            2);
		case CLOAK_STRENGTH_BONUS2:                 return PropType(0,  0,            2);
		case CLOAK_DEXTERITY_BONUS2:                return PropType(0,  1,            2);
		case CLOAK_CONSTITUTION_BONUS2:             return PropType(0,  2,            2);
		case CLOAK_INTELLIGENCE_BONUS2:             return PropType(0,  3,            2);
		case CLOAK_WISDOM_BONUS2:                   return PropType(0,  4,            2);
		case CLOAK_CHARISMA_BONUS2:                 return PropType(0,  5,            2);
		case SHIELD_STRENGTH_BONUS2:                return PropType(0,  0,            2);
		case SHIELD_DEXTERITY_BONUS2:               return PropType(0,  1,            2);
		case SHIELD_CONSTITUTION_BONUS2:            return PropType(0,  2,            2);
		case SHIELD_INTELLIGENCE_BONUS2:            return PropType(0,  3,            2);
		case SHIELD_WISDOM_BONUS2:                  return PropType(0,  4,            2);
		case SHIELD_CHARISMA_BONUS2:                return PropType(0,  5,            2);
		case ARMOR_BONUS_CA2:                       return PropType(1,  uint16_t.max, 2);
		case CLOAK_PARADE_BONUS2:                   return PropType(1,  uint16_t.max, 2);
		case BRACERS_BELT_CA_VS_BLUDGEONING_BONUS5: return PropType(3,  0,            5);
		case BRACERS_BELT_CA_VS_PIERCING_BONUS5:    return PropType(3,  1,            5);
		case BRACERS_BELT_CA_VS_SLASHING_BONUS5:    return PropType(3,  2,            5);
		case ENHANCEMENT_BONUS:                     return PropType(6,  uint16_t.max, 1);
		case ENHANCEMENT_BONUS2:                    return PropType(6,  uint16_t.max, 2);
		case HELM_DAMAGERESISTANCE5_BLUDGEONING:    return PropType(23, 0,            1);
		case HELM_DAMAGERESISTANCE5_PIERCING:       return PropType(23, 1,            1);
		case HELM_DAMAGERESISTANCE5_SLASHING:       return PropType(23, 2,            1);
		case HELM_DAMAGERESISTANCE5_MAGICAL:        return PropType(23, 5,            1);
		case HELM_DAMAGERESISTANCE5_ACID:           return PropType(23, 6,            1);
		case HELM_DAMAGERESISTANCE5_COLD:           return PropType(23, 7,            1);
		case HELM_DAMAGERESISTANCE5_DIVINE:         return PropType(23, 8,            1);
		case HELM_DAMAGERESISTANCE5_ELECTRICAL:     return PropType(23, 9,            1);
		case HELM_DAMAGERESISTANCE5_FIRE:           return PropType(23, 10,           1);
		case HELM_DAMAGERESISTANCE5_NEGATIVE:       return PropType(23, 11,           1);
		case HELM_DAMAGERESISTANCE5_POSITIVE:       return PropType(23, 12,           1);
		case HELM_DAMAGERESISTANCE5_SONIC:          return PropType(23, 13,           1);
		case BOOTS_DARKVISION:                      return PropType(26);
		case HASTE:                                 return PropType(35);
		case RING_IMMUNE_ABSORBTION:                return PropType(37, 1);
		case RING_IMMUNE_TERROR:                    return PropType(37, 5);
		case RING_IMMUNE_DEATH:                     return PropType(37, 9);
		case SPELLRESISTANCE:                       return PropType(39, uint16_t.max, 0);//+10
		case SHIELD_SPELLRESISTANCE10:              return PropType(39, uint16_t.max, 0);//+10
		case SHIELD_BONUS_VIG_PLUS7:                return PropType(41, 1,            7);
		case SHIELD_BONUS_VOL_PLUS7:                return PropType(41, 2,            7);
		case SHIELD_BONUS_REF_PLUS7:                return PropType(41, 3,            7);
		case KEEN:                                  return PropType(43);
		case MIGHTY_5:                              return PropType(45, uint16_t.max, 5);
		case MIGHTY_10:                             return PropType(45, uint16_t.max, 10);
		case MIGHTY_15:                             return PropType(45, uint16_t.max, 15);
		case MIGHTY_20:                             return PropType(45, uint16_t.max, 20);
		case REGENERATION:                          return PropType(51, uint16_t.max, 2);
		case BOOTS_REGENERATION1:                   return PropType(51, uint16_t.max, 2);
		case SHIELD_REGENERATION1:                  return PropType(51, uint16_t.max, 2);
		case AMULET_SKILL_CONCENTRATION_BONUS15:    return PropType(52, 1,            15);
		case AMULET_SKILL_DISABLE_TRAP_BONUS15:     return PropType(52, 2,            15);
		case AMULET_SKILL_DISCIPLINE_BONUS15:       return PropType(52, 3,            15);
		case AMULET_SKILL_HEAL_BONUS15:             return PropType(52, 4,            15);
		case AMULET_SKILL_HIDE_BONUS15:             return PropType(52, 5,            15);
		case AMULET_SKILL_LISTEN_BONUS15:           return PropType(52, 6,            15);
		case AMULET_SKILL_LORE_BONUS15:             return PropType(52, 7,            15);
		case AMULET_SKILL_MOVE_SILENTLY_BONUS15:    return PropType(52, 8,            15);
		case AMULET_SKILL_OPEN_LOCK_BONUS15:        return PropType(52, 9,            15);
		case AMULET_SKILL_PARRY_BONUS15:            return PropType(52, 10,           15);
		case AMULET_SKILL_PERFORM_BONUS15:          return PropType(52, 11,           15);
		case AMULET_SKILL_DIPLOMACY_BONUS15:        return PropType(52, 12,           15);
		case AMULET_SKILL_PERSUADE_BONUS15:         return PropType(52, 12,           15);//Diplomacy
		case AMULET_SKILL_SLEIGHT_OF_HAND_BONUS15:  return PropType(52, 13,           15);
		case AMULET_SKILL_PICK_POCKET_BONUS15:      return PropType(52, 13,           15);//SleightOfHand
		case AMULET_SKILL_SEARCH_BONUS15:           return PropType(52, 14,           15);
		case AMULET_SKILL_SET_TRAP_BONUS15:         return PropType(52, 15,           15);
		case AMULET_SKILL_SPELLCRAFT_BONUS15:       return PropType(52, 16,           15);
		case AMULET_SKILL_SPOT_BONUS15:             return PropType(52, 17,           15);
		case AMULET_SKILL_TAUNT_BONUS15:            return PropType(52, 18,           15);
		case AMULET_SKILL_USE_MAGIC_DEVICE_BONUS15: return PropType(52, 19,           15);
		case AMULET_SKILL_APPRAISE_BONUS15:         return PropType(52, 20,           15);
		case AMULET_SKILL_TUMBLE_BONUS15:           return PropType(52, 21,           15);
		case AMULET_SKILL_CRAFT_TRAP_BONUS15:       return PropType(52, 22,           15);
		case AMULET_SKILL_BLUFF_BONUS15:            return PropType(52, 23,           15);
		case AMULET_SKILL_INTIMIDATE_BONUS15:       return PropType(52, 24,           15);
		case AMULET_SKILL_CRAFT_ARMOR_BONUS15:      return PropType(52, 25,           15);
		case AMULET_SKILL_CRAFT_WEAPON_BONUS15:     return PropType(52, 26,           15);
		case AMULET_SKILL_CRAFT_ALCHEMY_BONUS15:    return PropType(52, 27,           15);
		case AMULET_SKILL_SURVIVAL_BONUS15:         return PropType(52, 29,           15);
		case ATTACK_BONUS:                          return PropType(56, uint16_t.max, 1);
		case ATTACK_BONUS2:                         return PropType(56, uint16_t.max, 2);
		case ATTACK_BONUS3:                         return PropType(56, uint16_t.max, 3);
		case ATTACK_BONUS4:                         return PropType(56, uint16_t.max, 4);
		case UNLIMITED_3:
			switch(baseItemType){
				case 8,11:                          return PropType(61, 0,            15);//Bow
				case 6,7:                           return PropType(61, 1,            15);//XBow
				case 61:                            return PropType(61, 2,            15);//Sling
				default: throw new EnchantmentException("Cannot add Unlimited enchantment to item type "~baseItemType.to!string);
			}
		case TRUESEEING:                            return PropType(71);
		case RING_FREEACTION:                       return PropType(75);
		case ARMOR_FREEACTION:                      return PropType(75);
	}
}

class EnchantmentException : Exception{
	@safe pure nothrow this(string msg, string f=__FILE__, size_t l=__LINE__, Throwable t=null){
		super(msg, f, l, t);
	}
}

void enchantItem(ref GffNode item, EnchantmentId enchantType){
	GffNode* findExistingProperty(in PropType propType){
		foreach(ref prop ; item["PropertiesList"].as!GffList){
			if(prop["PropertyName"].as!GffWord == propType.propertyName
				&& (propType.subType!=uint16_t.max? prop["Subtype"].as!GffWord==propType.subType : true))
				return &prop;
		}
		return null;
	}

	auto baseItemType = item["BaseItem"].to!uint;
	immutable propertyType = getPropertyType(baseItemType, enchantType);

	switch(propertyType.propertyName){

		case 16://dmg bonus
		case 26://DarkVision
		case 35://Haste
		case 37://Misc immunities (abs, fear, death)
		case 43://Keen
		case 61://Unlimited ammo
		case 71://TrueSeeing
		case 75://FreeAction
			//Add only if property does not exist (properties without CostValue)
			if(propertyType.propertyName!=16 && propertyType.propertyName!=61)
				assert(getTwoDA("itempropdef").get("CostTableResRef", propertyType.propertyName) is null,
					"Property "~propertyType.to!string~" has a cost value table and is handled as if there were none");

			enforce!EnchantmentException(findExistingProperty(propertyType) is null,
				"Enchantment "~propertyType.toString~" already exist on the updated version");

			item["PropertiesList"].as!GffList ~= buildPropertyUsing2DA(propertyType);
			return;

		default:
			//Merge by adding CostValue
			immutable costTableResref = getTwoDA("itempropdef").get("CostTableResRef", propertyType.propertyName);
			assert(costTableResref !is null,
				"Property "~propertyType.to!string~" has no cost value table and is handled as if there were one");

			if(auto prop = findExistingProperty(propertyType)){
				//merge with existing
				enforce!EnchantmentException(propertyType.propertyName != 39,//Spell resistance
					"Cannot merge "~propertyType.toString~" with existing property (not handled yet)");


				GffWord newCostValue, maxCostValue;
				if(propertyType.propertyName == 39){
					//Spell resistance
					//+10 SR => +5 index in 2da
					//max index: 15
					assert(propertyType.costValue==0);

					maxCostValue = 15;
					newCostValue = cast(GffWord)((*prop)["CostValue"].as!GffWord + 5);
				}
				else{
					immutable costValueTableIndex = getTwoDA("itempropdef").get("CostTableResRef", propertyType.propertyName);
					immutable costValueTable = getTwoDA("iprp_costtable").get("Name", costValueTableIndex.to!uint);

					maxCostValue = cast(GffWord)(getTwoDA(costValueTable).rows-1);
					newCostValue = cast(GffWord)((*prop)["CostValue"].as!GffWord + propertyType.costValue);
				}

				enforce!EnchantmentException(newCostValue <= maxCostValue,
					"Cannot merge enchantment "~propertyType.toString~": CostValue "~newCostValue.to!string~" is too high");

				(*prop)["CostValue"].as!GffWord = newCostValue;
			}
			else{
				//append
				item["PropertiesList"].as!GffList ~= buildPropertyUsing2DA(propertyType);
			}
			return;
	}
	assert(0);
}





GffNode buildPropertyUsing2DA(in PropType propType, uint8_t param1Value=uint8_t.max){
	GffNode ret = GffNode(GffType.Struct);
	with(ret){
		assert(propType.propertyName < getTwoDA("itempropdef").rows);

		appendField(GffNode(GffType.Word, "PropertyName", propType.propertyName));

		immutable subTypeTable = getTwoDA("itempropdef").get("SubTypeResRef", propType.propertyName);
		if(subTypeTable is null)
			assert(propType.subType==uint16_t.max, "propType.subType pointing to non-existent SubTypeTable");
		else
			assert(propType.subType!=uint16_t.max, "propType.subType must be defined");

		appendField(GffNode(GffType.Word, "Subtype", propType.subType));

		string costTableResRef = getTwoDA("itempropdef").get("CostTableResRef", propType.propertyName);
		if(costTableResRef is null)
			assert(propType.costValue==uint16_t.max, "propType.costValue pointing to non-existent CostTableResRef");
		else
			assert(propType.costValue!=uint16_t.max, "propType.costValue must be defined");

		appendField(GffNode(GffType.Byte, "CostTable", costTableResRef !is null? costTableResRef.to!ubyte : ubyte.max));
		appendField(GffNode(GffType.Word, "CostValue", propType.costValue));


		immutable paramTableResRef = getTwoDA("itempropdef").get("Param1ResRef", propType.propertyName);
		if(paramTableResRef !is null){
			assert(param1Value!=uint8_t.max, "param1Value must be defined");
			appendField(GffNode(GffType.Byte, "Param1", paramTableResRef.to!ubyte));
			appendField(GffNode(GffType.Byte, "Param1Value", param1Value));
		}
		else{
			assert(param1Value==uint8_t.max, "param1Value pointing to non-existent Param1ResRef");
			appendField(GffNode(GffType.Byte, "Param1", uint8_t.max));
			appendField(GffNode(GffType.Byte, "Param1Value", uint8_t.max));
		}

		appendField(GffNode(GffType.Byte, "ChanceAppear", 100));
		appendField(GffNode(GffType.Byte, "UsesPerDay",   255));
		appendField(GffNode(GffType.Byte, "Useable",      1));
	}
	return ret;
}