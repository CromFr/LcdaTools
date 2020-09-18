module lcda.compat.hagbe_inc;

import std.exception;
import std.conv;
import nwn.gff;

import lcda.constants;
import lcda.hagbe;
import lcda.compat.x2_inc_itemprop;

import nwn.nwscript;

// Enchantment prices
int GetEnchantmentCost(in GffStruct oItem, NWItemproperty ipr){
	switch(ipr.type){
		case ITEM_PROPERTY_ABILITY_BONUS:
			switch(ipr.costValue){
				case 2: return 450000;
				default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
			}
			break;
		case ITEM_PROPERTY_ATTACK_BONUS:
			switch(ipr.costValue){
				case 1: return 100000;
				case 2: return 200000;
				case 4: return 450000;
				default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
			}
			break;
		case ITEM_PROPERTY_ENHANCEMENT_BONUS:
			switch(ipr.costValue){
				case 1: return 150000;
				case 2: return 450000;
				default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
			}
			break;
		case ITEM_PROPERTY_DAMAGE_BONUS:
			switch(ipr.costValue){
				case IP_CONST_DAMAGEBONUS_1d6: return 300000;
				default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
			}
			break;
		case ITEM_PROPERTY_REGENERATION:
			switch(ipr.costValue){
				case 1: return 150000;
				case 2: return 450000;
				default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
			}
			break;
		case ITEM_PROPERTY_MIGHTY:
			switch(ipr.costValue){
				case 5: return 100000;
				case 10: return 300000;
				case 15: return 400000;
				case 20: return 500000;
				default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
			}
			break;
		case ITEM_PROPERTY_UNLIMITED_AMMUNITION:
			switch(ipr.costValue){
				case IP_CONST_UNLIMITEDAMMO_PLUS5: return 200000;
				default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
			}
			break;
		case ITEM_PROPERTY_AC_BONUS:
			switch(oItem["BaseItem"].to!int){
				case BASE_ITEM_ARMOR:
					// Armor bonus
					// -> Fallthrough
				case BASE_ITEM_SMALLSHIELD:
				case BASE_ITEM_LARGESHIELD:
				case BASE_ITEM_TOWERSHIELD:
					// Shield bonus
					// -> Fallthrough
				case BASE_ITEM_AMULET:
					// Natural armor bonus
					// -> Fallthrough
				case BASE_ITEM_BOOTS:
					// Dodge bonus
					switch(ipr.costValue){
						case 2: return 450000;
						default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
					}
					break;
				case BASE_ITEM_RING:
				case BASE_ITEM_CLOAK:
				case BASE_ITEM_BRACER:
				case BASE_ITEM_GLOVES:
					// Deflection bonus
					switch(ipr.costValue){
						case 2: return 30000;
						default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
					}
					break;
				default: enforce(false, "Unknown item type " ~ oItem["BaseItem"].to!string);
			}
			break;
		case ITEM_PROPERTY_AC_BONUS_VS_DAMAGE_TYPE:
			switch(ipr.costValue){
				case 5: return 300000;
				default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
			}
			break;
		case ITEM_PROPERTY_IMMUNITY_MISCELLANEOUS:
			switch(ipr.subType){
				case IP_CONST_IMMUNITYMISC_DEATH_MAGIC: return 1000000;
				case IP_CONST_IMMUNITYMISC_FEAR: return 150000;
				case IP_CONST_IMMUNITYMISC_LEVEL_ABIL_DRAIN: return 300000;
				default: enforce(false, "Unknown subtype " ~ ipr.subType.to!string);
			}
			break;
		case ITEM_PROPERTY_SAVING_THROW_BONUS_SPECIFIC:
			switch(ipr.costValue){
				case 7: return 150000;
				default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
			}
			break;
		case ITEM_PROPERTY_DAMAGE_RESISTANCE:
			switch(ipr.costValue){
				case IP_CONST_DAMAGERESIST_5: return 300000;
				default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
			}
			break;
		case ITEM_PROPERTY_SKILL_BONUS:
			switch(ipr.costValue){
				case 15: return 350000;
				default: enforce(false, "Unknown cost value " ~ ipr.costValue.to!string);
			}
			break;
		case ITEM_PROPERTY_SPELL_RESISTANCE:
			{
				NWItemproperty ipExisting = GetSimilarItemProperty(oItem, ipr);
				int nCurrentSR = IprpSRValueToInt(ipExisting.costValue);
				int nBonusSR = IprpSRValueToInt(ipr.costValue);
				if(nCurrentSR + nBonusSR <= 40){
					// Full price
					return 150000;
				}
				else{
					// Ratio of gained points
					return (150000 * ((40 - nCurrentSR) * 1.0 / nBonusSR)).to!int;
				}
			}
			//break;

		case ITEM_PROPERTY_HASTE:
		case ITEM_PROPERTY_KEEN:
			return 300000;
		case ITEM_PROPERTY_TRUE_SEEING:
			return 450000;
		case ITEM_PROPERTY_FREEDOM_OF_MOVEMENT:
			return 150000;
		case ITEM_PROPERTY_DARKVISION:
			return 75000;

		default:
			enforce(false, "Unknown iprp type " ~ ipr.type.to!string);
	}

	enforce(false, "Unknown iprp type " ~ ipr.type.to!string);
	return -1;
}


// Combine two item properties together
NWItemproperty EnhanceItemPropertyCostValue(NWItemproperty iprp, int nCostValueBonus){
	import nwn.twoda;
	static TwoDA twoDA;
	if(twoDA is null){
		twoDA = new TwoDA(`2DA V2.0

    Name  Label                          SubTypeResRef        Cost  CostTableResRef Param1ResRef GameStrRef Description Slots
0   649   Ability                        IPRP_ABILITIES       1.05  1               ****         5476       ****        1
1   652   Armor                          ****                 1     2               ****         5477       ****        1
2   653   ArmorAlignmentGroup            IPRP_ALIGNGRP        0.5   2               ****         5478       1077        1
3   654   ArmorDamageType                IPRP_COMBATDAM       0.5   2               ****         5478       ****        1
4   651   ArmorRacialGroup               racialtypes          0.5   2               ****         5478       ****        1
5   655   ArmorSpecificAlignment         IPRP_ALIGNMENT       0.3   2               ****         5478       ****        1
6   659   Enhancement                    ****                 1     2               ****         5479       1080        1
7   656   EnhancementAlignmentGroup      IPRP_ALIGNGRP        0.6   2               ****         5480       1084        1
8   657   EnhancementRacialGroup         racialtypes          0.35  2               ****         5480       1081        1
9   658   EnhancementSpecificAlignment   IPRP_ALIGNMENT       0.35  2               ****         5480       1083        1
10  660   EnhancementPenalty             ****                 0     20              ****         5481       1460        0
11  661   WeightReduction                ****                 1     10              ****         5482       1442        1
12  662   BonusFeats                     IPRP_FEATS           ****  ****            ****         5483       1445        1
13  663   SingleBonusSpellOfLevel        Classes              0.5   13              ****         5484       1444        1
14  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
15  668   CastSpell                      IPRP_SPELLS          ****  3               ****         5485       1078        1
16  650   Damage                         IPRP_DAMAGETYPE      3.5   4               ****         5486       1089        1
17  670   DamageAlignmentGroup           IPRP_ALIGNGRP        1.5   4               ****         5487       1092        1
18  673   DamageRacialGroup              racialtypes          0.75  4               ****         5487       1090        1
19  675   DamageSpecificAlignment        IPRP_ALIGNMENT       0.75  4               ****         5487       1091        1
20  680   DamageImmunity                 IPRP_DAMAGETYPE      2.3   5               ****         5488       1093        1
21  672   DamagePenalty                  ****                 0     20              ****         5489       1459        0
22  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
23  681   DamageResist                   IPRP_DAMAGETYPE      ****  7               ****         5491       1417        1
24  696   Damage_Vulnerability           IPRP_DAMAGETYPE      0     22              ****         5492       1457        0
25  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
26  1493  Darkvision                     ****                 1     ****            ****         5493       84355       1
27  677   DecreaseAbilityScore           IPRP_ABILITIES       0     21              ****         5494       1454        0
28  678   DecreaseAC                     IPRP_ACMODTYPE       0     29              ****         5495       1456        0
29  679   DecreasedSkill                 Skills               0     21              ****         5496       1455        0
30  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
31  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
32  728   EnhancedContainer_Weight       ****                 1.5   15              ****         5498       1439        1
33  669   DamageMelee                    IPRP_COMBATDAM       0.5   ****            ****         5499       1420        1
34  671   DamageRanged                   IPRP_COMBATDAM       0.5   ****            ****         5500       1421        1
35  704   Haste                          ****                 3.5   ****            ****         5501       1426        1
36  1023  HolyAvenger                    ****                 1.5   ****            ****         5502       1436        1
37  1022  Immunity                       IPRP_IMMUNITY        ****  ****            ****         5503       1449        1
38  710   ImprovedEvasion                ****                 3     ****            ****         5504       1429        1
39  666   ImprovedMagicResist            ****                 2     11              ****         5505       1422        1
40  711   ImprovedSavingThrows           IPRP_SAVEELEMENT     ****  2               ****         5506       1440        1
41  712   ImprovedSavingThrowsSpecific   IPRP_SAVINGTHROW     0.65  2               ****         5506       1441        1
42  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
43  713   Keen                           ****                 1     ****            ****         5507       1079        1
44  714   Light                          ****                 1     18              9            5508       1431        1
45  1500  Mighty                         ****                 0.25  2               ****         5509       ****        1
46  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
47  722   DamageNone                     ****                 0     ****            ****         5511       1419        0
48  723   OnHit                          IPRP_ONHIT           ****  24              ****         5512       1450        1
49  726   ReducedSavingThrows            IPRP_SAVEELEMENT     0     29              ****         5513       1461        0
50  727   ReducedSpecificSavingThrow     IPRP_SAVINGTHROW     0     29              ****         5513       1462        0
51  729   Regeneration                   ****                 2     2               ****         5515       1446        1
52  731   Skill                          skills               0.17  25              ****         5516       ****        1
53  733   SpellImmunity_Specific         ****                 0.4   16              ****         5514       1447        1
54  730   SpellSchool_Immunity           IPRP_SPELLSHL        6.1   ****            ****         5517       1448        1
55  1492  ThievesTools                   ****                 0.08  25              ****         5518       ****        1
56  735   AttackBonus                    ****                 0.5   2               ****         5519       1085        1
57  734   AttackBonusAlignmentGroup      IPRP_ALIGNGRP        0.4   2               ****         5520       1088        1
58  737   AttackBonusRacialGroup         racialtypes          0.15  2               ****         5520       1086        1
59  738   AttackBonusSpecificAlignment   IPRP_ALIGNMENT       0.15  2               ****         5520       1087        1
60  736   AttackPenalty                  ****                 0     20              ****         5521       1458        0
61  739   UnlimitedAmmo                  IPRP_AMMOTYPE        1     14              ****         5522       1452        1
62  715   UseLimitationAlignmentGroup    IPRP_ALIGNGRP        0     ****            ****         5523       1435        0
63  716   UseLimitationClass             Classes              0     ****            ****         5523       1434        0
64  724   UseLimitationRacial            racialtypes          0     ****            ****         5523       1432        0
65  717   UseLimitationSpecificAlignment IPRP_ALIGNMENT       0     ****            ****         5523       1437        0
66  718   BonusHitpoints                 ****                 0     28              ****         5524       1433        1
67  732   VampiricRegeneration           ****                 0.5   2               ****         5525       1451        1
68  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
69  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
70  1663  Trap                           IPRP_TRAPS           ****  17              ****         5528       ****        1
71  1775  True_Seeing                    ****                 6.1   ****            ****         5529       ****        1
72  1776  OnMonsterHit                   IPRP_MONSTERHIT      ****  ****            ****         5530       ****        1
73  1777  Turn_Resistance                ****                 0.5   25              ****         5531       ****        1
74  1778  Massive_Criticals              ****                 0.65  4               ****         5532       ****        1
75  1779  Freedom_of_Movement            ****                 4     ****            ****         5533       ****        1
76  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
77  5060  Monster_damage                 ****                 1     19              ****         5535       ****        1
78  5604  Immunity_To_Spell_By_Level     ****                 1.2   23              ****         5635       ****        1
79  6637  Special_Walk                   IPRP_WALK            0     ****            ****         ****       ****        1
80  8338  Healers_Kit                    ****                 0.035 25              ****         8338       ****        1
81  58325 Weight_Increase                ****                 0     ****            11           ****       ****        0
82  83400 OnHitCastSpell                 IPRP_ONHITSPELL      ****  26              ****         5512       1450        1
83  83392 VisualEffect                   IPRP_VISUALFX        ****  ****            ****         5512       1450        1
84  84321 ArcaneSpellFailure             ****                 2     27              ****         84346      84347       1
85  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
86  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
87  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
88  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
89  ****  DELETED                        ****                 ****  ****            ****         ****       ****        ****
90  674   DamageReduction                IPRP_DAMAGEREDUCTION ****  ****            ****         5490       1418        1
`
		);
	}

	int nType = iprp.type;
	int nSubType = iprp.subType;
	int nCostValue = iprp.costValue;
	switch(twoDA[nType, "CostTableResRef"].to!int){
		case 1: // IPRP_BONUSCOST
			// From 1 to 12
			nCostValue += nCostValueBonus;
			if(nCostValue > 12)
				nCostValue = 12;
			return NWItemproperty(nType, nSubType, nCostValue);

		case 2: // IPRP_MELEECOST
			// From 1 to 20
			nCostValue += nCostValueBonus;
			if(nCostValue > 20)
				nCostValue = 20;
			return NWItemproperty(nType, nSubType, nCostValue);

		case 7: // IPRP_RESISTCOST
			// resistance = costValue * 5
			// From id 1 to id 10
			nCostValue += nCostValueBonus;
			if(nCostValue > 10)
				nCostValue = 10;
			return NWItemproperty(nType, nSubType, nCostValue);

		case 11: // IPRP_SRCOST
			int nCurrBonus = IprpSRValueToInt(nCostValue);
			int nAddBonus = IprpSRValueToInt(nCostValueBonus);
			nCostValue = IntToIprpSRValue(nCurrBonus + nAddBonus);
			return NWItemproperty(nType, nSubType, nCostValue);

		default: break;
	}

	return NWItemproperty(-1);
}

NWItemproperty GetSimilarItemProperty(in GffStruct oItem, NWItemproperty ipSimilar, int bIgnoreSubType = false){
	int nType = ipSimilar.type;
	int nSubType = ipSimilar.subType;
	switch(nType){
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
			bIgnoreSubType = true;
			break;
		default: break;
	}

	foreach(ref prop ; oItem["PropertiesList"].as!(GffType.List)){
   		auto ip = NWItemproperty(
   			prop["PropertyName"].as!(GffType.Word),
   			prop["Subtype"].as!(GffType.Word),
   			prop["CostValue"].as!(GffType.Word),
   			prop["Param1Value"].as!(GffType.Byte),
   		);

		if(ip.type == nType){
			if(bIgnoreSubType || ip.subType == nSubType){
				return ip;
			}
		}
	}
	return NWItemproperty(-1);
}

int IprpSRValueToInt(int nIprpSRValue, int bRaiseBug = true){
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
		default:
			if(bRaiseBug) assert(0, "Unknown IPRP SR value int: '" ~ nIprpSRValue.to!string ~ "'");
	}
	return -1;
}
int IntToIprpSRValue(int nValue, int bRaiseBug = true){
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
	if(bRaiseBug) assert(0, "Unknown SR value int: '" ~ nValue.to!string ~ "'");
	return -1;
}


int EnchantItem(ref GffStruct oItem, NWItemproperty iprp){
	// Remove temporary properties
	//IPRemoveAllItemProperties(oItem, DURATION_TYPE_TEMPORARY); // TODO

	int nIprpType = iprp.type;
	int nIprpSubType = iprp.subType;

	NWItemproperty ipToAdd;
	NWItemproperty ipExisting = GetSimilarItemProperty(oItem, iprp);
	if(iprp.type >= 0){
		// Replace with similar property with higher cost value
		ipToAdd = EnhanceItemPropertyCostValue(ipExisting, iprp.costValue);
	}
	else
		ipToAdd = iprp;

	if(!GetIsItemPropertyValid(ipToAdd))
		return false;

	IPSafeAddItemProperty(oItem, ipToAdd, 0.0f, X2_IP_ADDPROP_POLICY_REPLACE_EXISTING);
	SetLocalInt(oItem, "DEJA_ENCHANTE", true);
	SetLocalInt(oItem, "hagbe_iprp_t", nIprpType);
	SetLocalInt(oItem, "hagbe_iprp_st", nIprpSubType);
	SetLocalInt(oItem, "hagbe_iprp_c", iprp.costValue);
	SetLocalInt(oItem, "hagbe_iprp_p1", iprp.p1);
	SetFirstName(oItem, GetName(oItem) ~ " <c=#9257FF>*</c>");
	return true;
}
