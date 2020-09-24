// LEGACY hagbe stuff
deprecated module lcda.compat.lib_forge_epique;

import nwn.types;
import std.conv: to;


mixin((){
		string ret = `enum EnchantmentId{`;
		foreach(m ; __traits(allMembers, lcda.compat.lib_forge_epique)){
			static if(m.length>12 && m[0..12]=="IP_CONST_WS_"){

				ret ~= m[12..$] ~ " = " ~ m ~ ",";
			}
		}
		foreach(s ; ["ACID", "SONIC", "FIRE", "COLD", "ELECTRICAL", "NEGATIVE", "POSITIVE", "DIVINE"]){
			ret ~= "DAMAGETYPE_" ~ s ~ " = IP_CONST_DAMAGETYPE_" ~ s ~ ",";
		}
		ret ~= `}`;
		return ret;
	}());



// Copy/paste from LCDA lib_forge_epique.nss
// Added default: assert(0, "Could not get gold value for enchantment id="~nService.to!string);
// to PrixDuService(...)


const int WS_COST_ACID_PROPERTY = 300000; // All elemental damages use this.
const int WS_COST_ATTACK_BONUS = 100000;
const int WS_COST_ATTACK_BONUS2 = 200000;
const int WS_COST_ATTACK_BONUS4 = 450000;
const int WS_COST_ENHANCEMENT_BONUS = 150000;
const int WS_COST_ENHANCEMENT_BONUS2 = 450000;
const int WS_COST_HASTE = 300000;
const int WS_COST_KEEN = 300000;
const int WS_COST_TRUESEEING = 450000;
const int WS_COST_SPELLRESISTANCE = 150000;
const int WS_COST_REGENERATION2 = 450000;
const int WS_COST_MIGHTY_5 = 100000;
const int WS_COST_MIGHTY_10 = 300000;
const int WS_COST_MIGHTY_15 = 400000;
const int WS_COST_MIGHTY_20 = 500000;
const int WS_COST_UNLIMITED_3 = 200000;
const int WS_COST_ARMOR_BONUS_CA2 = 450000;
const int WS_COST_ARMOR_FREEACTION = 150000;
const int WS_COST_ARMOR_STAT_BONUS2 = 450000; // All stat bonuses use this.
const int WS_COST_SHIELD_REGENERATION1 = 150000;
const int WS_COST_SHIELD_SPELLRESISTANCE10 = 150000;
const int WS_COST_SHIELD_BONUS_JS7 = 150000; // ALL DD bonuses for shield use this.
const int WS_COST_HELM_DAMAGERESISTANCE5 = 300000; // All damage resitances for helm use this.
const int WS_COST_RING_FREEACTION = 300000 ;
const int WS_COST_RING_IMMUNE_DEATH = 1000000 ;
const int WS_COST_RING_IMMUNE_TERROR = 150000 ;
const int WS_COST_RING_IMMUNE_ABSORBTION = 300000 ;
const int WS_COST_AMULET_COMPETENCE_BONUS15 = 350000 ; // All competence bonuses for amulettes use this.
const int WS_COST_BOOTS_DARKVISION = 75000;
const int WS_COST_BOOTS_REGENERATION1 = 150000;
const int WS_COST_CLOAK_PARADE_BONUS2 = 300000;
const int WS_COST_BRACERS_BELT_CA_VS_BONUS5 = 300000 ; //All ca bonuses for belt or bracers use this

// * Other Constants -- needed to make "fake" constants for some item property
const int IP_CONST_WS_ATTACK_BONUS = 19000;
const int IP_CONST_WS_ENHANCEMENT_BONUS = 19001;
const int IP_CONST_WS_HASTE = 19002;
const int IP_CONST_WS_KEEN = 19003;
const int IP_CONST_WS_TRUESEEING = 19005;
const int IP_CONST_WS_SPELLRESISTANCE = 19006;
const int IP_CONST_WS_REGENERATION = 19007;
const int IP_CONST_WS_MIGHTY_5 = 19008;
const int IP_CONST_WS_MIGHTY_10 = 19009;
const int IP_CONST_WS_UNLIMITED_3 = 19010;
const int IP_CONST_WS_ARMOR_BONUS_CA2 = 19011;
const int IP_CONST_WS_ARMOR_FREEACTION = 19012;
const int IP_CONST_WS_ARMOR_STRENGTH_BONUS2 = 19013;
const int IP_CONST_WS_ARMOR_DEXTERITY_BONUS2 = 19027;
const int IP_CONST_WS_ARMOR_CONSTITUTION_BONUS2 = 19028;
const int IP_CONST_WS_ARMOR_INTELLIGENCE_BONUS2 = 19029;
const int IP_CONST_WS_ARMOR_WISDOM_BONUS2 = 19030;
const int IP_CONST_WS_ARMOR_CHARISMA_BONUS2 = 19031;
const int IP_CONST_WS_SHIELD_REGENERATION1 = 19014;
const int IP_CONST_WS_SHIELD_SPELLRESISTANCE10 = 19015;
const int IP_CONST_WS_SHIELD_BONUS_VIG_PLUS7 = 19016;
const int IP_CONST_WS_SHIELD_BONUS_REF_PLUS7 = 19032;
const int IP_CONST_WS_SHIELD_BONUS_VOL_PLUS7 = 19033;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_ACID = 19017;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_BLUDGEONING = 19034;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_COLD = 19035;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_DIVINE = 19036;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_ELECTRICAL = 19037;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_FIRE = 19038;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_MAGICAL = 19039;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_NEGATIVE = 19040;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_PIERCING = 19041;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_POSITIVE = 19042;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_SLASHING = 19043;
const int IP_CONST_WS_HELM_DAMAGERESISTANCE5_SONIC = 19044;
const int IP_CONST_WS_RING_FREEACTION =  19018;
const int IP_CONST_WS_RING_IMMUNE_DEATH =  19019;
const int IP_CONST_WS_RING_IMMUNE_TERROR =  19020;
const int IP_CONST_WS_RING_IMMUNE_ABSORBTION =  19021;
const int IP_CONST_WS_AMULET_SKILL_APPRAISE_BONUS15 =  19045;
const int IP_CONST_WS_AMULET_SKILL_BLUFF_BONUS15 =  19046;
const int IP_CONST_WS_AMULET_SKILL_CONCENTRATION_BONUS15 =  19047;
const int IP_CONST_WS_AMULET_SKILL_CRAFT_ARMOR_BONUS15 =  19048;
const int IP_CONST_WS_AMULET_SKILL_CRAFT_TRAP_BONUS15 =  19049;
const int IP_CONST_WS_AMULET_SKILL_CRAFT_WEAPON_BONUS15 =  19050;
const int IP_CONST_WS_AMULET_SKILL_DISABLE_TRAP_BONUS15 =  19051;
const int IP_CONST_WS_AMULET_SKILL_DISCIPLINE_BONUS15 =  19052;
const int IP_CONST_WS_AMULET_SKILL_HEAL_BONUS15 =  19053;
const int IP_CONST_WS_AMULET_SKILL_HIDE_BONUS15 =  19054;
const int IP_CONST_WS_AMULET_SKILL_INTIMIDATE_BONUS15 =  19055;
const int IP_CONST_WS_AMULET_SKILL_LISTEN_BONUS15 =  19056;
const int IP_CONST_WS_AMULET_SKILL_LORE_BONUS15 =  19057;
const int IP_CONST_WS_AMULET_SKILL_MOVE_SILENTLY_BONUS15 =  19058;
const int IP_CONST_WS_AMULET_SKILL_OPEN_LOCK_BONUS15 =  19059;
const int IP_CONST_WS_AMULET_SKILL_PARRY_BONUS15 =  19060;
const int IP_CONST_WS_AMULET_SKILL_PERFORM_BONUS15 =  19061;
const int IP_CONST_WS_AMULET_SKILL_PERSUADE_BONUS15 =  19062;
const int IP_CONST_WS_AMULET_SKILL_PICK_POCKET_BONUS15 =  19063;
const int IP_CONST_WS_AMULET_SKILL_SEARCH_BONUS15 =  19064;
const int IP_CONST_WS_AMULET_SKILL_SET_TRAP_BONUS15 =  19065;
const int IP_CONST_WS_AMULET_SKILL_SPELLCRAFT_BONUS15 =  19066;
const int IP_CONST_WS_AMULET_SKILL_SPOT_BONUS15 =  19067;
const int IP_CONST_WS_AMULET_SKILL_TAUNT_BONUS15 =  19068;
const int IP_CONST_WS_AMULET_SKILL_TUMBLE_BONUS15 =  19069;
const int IP_CONST_WS_AMULET_SKILL_USE_MAGIC_DEVICE_BONUS15 =  19070;
const int IP_CONST_WS_AMULET_SKILL_DIPLOMACY_BONUS15 = 19073;
const int IP_CONST_WS_AMULET_SKILL_CRAFT_ALCHEMY_BONUS15 = 19074;
const int IP_CONST_WS_AMULET_SKILL_SLEIGHT_OF_HAND_BONUS15 = 19075;
const int IP_CONST_WS_AMULET_SKILL_SURVIVAL_BONUS15 = 19076;
const int IP_CONST_WS_BOOTS_DARKVISION = 19023;
const int IP_CONST_WS_BOOTS_REGENERATION1 = 19024;
const int IP_CONST_WS_CLOAK_PARADE_BONUS2 = 19025;
const int IP_CONST_WS_BRACERS_BELT_CA_VS_BLUDGEONING_BONUS5 =  19026;
const int IP_CONST_WS_BRACERS_BELT_CA_VS_PIERCING_BONUS5 =  19071;
const int IP_CONST_WS_BRACERS_BELT_CA_VS_SLASHING_BONUS5 =  19072;
const int IP_CONST_WS_BRACERS_BELT_CONSTITUTION_BONUS2 = 19077;
const int IP_CONST_WS_BRACERS_BELT_WISDOM_BONUS2 = 19078;
const int IP_CONST_WS_BRACERS_BELT_INTELLIGENCE_BONUS2 = 19079;
const int IP_CONST_WS_BRACERS_BELT_STRENGTH_BONUS2 = 19080;
const int IP_CONST_WS_BRACERS_BELT_DEXTERITY_BONUS2 = 19081;
const int IP_CONST_WS_BRACERS_BELT_CHARISMA_BONUS2 = 19082;
const int IP_CONST_WS_HELM_CONSTITUTION_BONUS2 = 19083;
const int IP_CONST_WS_HELM_WISDOM_BONUS2 = 19084;
const int IP_CONST_WS_HELM_INTELLIGENCE_BONUS2 = 19085;
const int IP_CONST_WS_HELM_STRENGTH_BONUS2 = 19086;
const int IP_CONST_WS_HELM_DEXTERITY_BONUS2 = 19087;
const int IP_CONST_WS_HELM_CHARISMA_BONUS2 = 19088;
const int IP_CONST_WS_AMULET_CONSTITUTION_BONUS2 = 19089;
const int IP_CONST_WS_AMULET_WISDOM_BONUS2 = 19090;
const int IP_CONST_WS_AMULET_INTELLIGENCE_BONUS2 = 19091;
const int IP_CONST_WS_AMULET_STRENGTH_BONUS2 = 19092;
const int IP_CONST_WS_AMULET_DEXTERITY_BONUS2 = 19093;
const int IP_CONST_WS_AMULET_CHARISMA_BONUS2 = 19094;
const int IP_CONST_WS_RING_CONSTITUTION_BONUS2 = 19095;
const int IP_CONST_WS_RING_WISDOM_BONUS2 = 19096;
const int IP_CONST_WS_RING_INTELLIGENCE_BONUS2 = 19097;
const int IP_CONST_WS_RING_STRENGTH_BONUS2 = 19098;
const int IP_CONST_WS_RING_DEXTERITY_BONUS2 = 19099;
const int IP_CONST_WS_RING_CHARISMA_BONUS2 = 19100;
const int IP_CONST_WS_BOOTS_CONSTITUTION_BONUS2 = 19101;
const int IP_CONST_WS_BOOTS_WISDOM_BONUS2 = 19102;
const int IP_CONST_WS_BOOTS_INTELLIGENCE_BONUS2 = 19103;
const int IP_CONST_WS_BOOTS_STRENGTH_BONUS2 = 19104;
const int IP_CONST_WS_BOOTS_DEXTERITY_BONUS2 = 19105;
const int IP_CONST_WS_BOOTS_CHARISMA_BONUS2 = 19106;
const int IP_CONST_WS_CLOAK_CONSTITUTION_BONUS2 = 19107;
const int IP_CONST_WS_CLOAK_WISDOM_BONUS2 = 19108;
const int IP_CONST_WS_CLOAK_INTELLIGENCE_BONUS2 = 19109;
const int IP_CONST_WS_CLOAK_STRENGTH_BONUS2 = 19110;
const int IP_CONST_WS_CLOAK_DEXTERITY_BONUS2 = 19111;
const int IP_CONST_WS_CLOAK_CHARISMA_BONUS2 = 19112;
const int IP_CONST_WS_SHIELD_CONSTITUTION_BONUS2 = 19113;
const int IP_CONST_WS_SHIELD_WISDOM_BONUS2 = 19114;
const int IP_CONST_WS_SHIELD_INTELLIGENCE_BONUS2 = 19115;
const int IP_CONST_WS_SHIELD_STRENGTH_BONUS2 = 19116;
const int IP_CONST_WS_SHIELD_DEXTERITY_BONUS2 = 19117;
const int IP_CONST_WS_SHIELD_CHARISMA_BONUS2 = 19118;
const int IP_CONST_WS_ATTACK_BONUS2 = 19119;
const int IP_CONST_WS_ATTACK_BONUS3 = 19120;
const int IP_CONST_WS_ATTACK_BONUS4 = 19121;
const int IP_CONST_WS_ENHANCEMENT_BONUS2 = 19122;
const int IP_CONST_WS_MIGHTY_15 = 19123;
const int IP_CONST_WS_MIGHTY_20 = 19124;



enum IP_CONST_DAMAGETYPE_BLUDGEONING             = 0;
enum IP_CONST_DAMAGETYPE_PIERCING                = 1;
enum IP_CONST_DAMAGETYPE_SLASHING                = 2;
enum IP_CONST_DAMAGETYPE_SUBDUAL                 = 3;
enum IP_CONST_DAMAGETYPE_PHYSICAL                = 4;
enum IP_CONST_DAMAGETYPE_MAGICAL                 = 5;
enum IP_CONST_DAMAGETYPE_ACID                    = 6;
enum IP_CONST_DAMAGETYPE_COLD                    = 7;
enum IP_CONST_DAMAGETYPE_DIVINE                  = 8;
enum IP_CONST_DAMAGETYPE_ELECTRICAL              = 9;
enum IP_CONST_DAMAGETYPE_FIRE                    = 10;
enum IP_CONST_DAMAGETYPE_NEGATIVE                = 11;
enum IP_CONST_DAMAGETYPE_POSITIVE                = 12;
enum IP_CONST_DAMAGETYPE_SONIC                   = 13;




int PrixDuService(int nService)
{
	int nGoldNeed = 0;
	//SpeakString("Determination du prix");
	switch (nService)
		{
			// ARMES ***************************************************************
			case IP_CONST_DAMAGETYPE_ACID:
			case IP_CONST_DAMAGETYPE_SONIC:
			case IP_CONST_DAMAGETYPE_FIRE:
			case IP_CONST_DAMAGETYPE_COLD:
			case IP_CONST_DAMAGETYPE_ELECTRICAL:
			case IP_CONST_DAMAGETYPE_NEGATIVE:
			case IP_CONST_DAMAGETYPE_POSITIVE:
			case IP_CONST_DAMAGETYPE_DIVINE:
				nGoldNeed = WS_COST_ACID_PROPERTY; break;
			case IP_CONST_WS_ATTACK_BONUS: nGoldNeed = WS_COST_ATTACK_BONUS; break;
			case IP_CONST_WS_ATTACK_BONUS2: nGoldNeed = WS_COST_ATTACK_BONUS2; break;
			case IP_CONST_WS_ATTACK_BONUS4: nGoldNeed = WS_COST_ATTACK_BONUS4; break;
			case IP_CONST_WS_ENHANCEMENT_BONUS:
			{
				nGoldNeed = WS_COST_ENHANCEMENT_BONUS;
				break;
			}
			case IP_CONST_WS_ENHANCEMENT_BONUS2:
			{
				nGoldNeed = WS_COST_ENHANCEMENT_BONUS2;
				break;
			}
			case IP_CONST_WS_HASTE: nGoldNeed = WS_COST_HASTE; break;
			case IP_CONST_WS_KEEN: nGoldNeed = WS_COST_KEEN;break;
			case IP_CONST_WS_TRUESEEING: nGoldNeed = WS_COST_TRUESEEING;break;
			case IP_CONST_WS_SPELLRESISTANCE: nGoldNeed = WS_COST_SPELLRESISTANCE; break;
			case IP_CONST_WS_REGENERATION: nGoldNeed = WS_COST_REGENERATION2; break; // utilisé par tous les items d'equipements
			case IP_CONST_WS_MIGHTY_5: nGoldNeed = WS_COST_MIGHTY_5; break;
			case IP_CONST_WS_MIGHTY_10: nGoldNeed = WS_COST_MIGHTY_10; break;
			case IP_CONST_WS_MIGHTY_15: nGoldNeed = WS_COST_MIGHTY_15; break;
			case IP_CONST_WS_MIGHTY_20: nGoldNeed = WS_COST_MIGHTY_20; break;
			case IP_CONST_WS_UNLIMITED_3: nGoldNeed = WS_COST_UNLIMITED_3; break;
		// ARMURES *************************************************************
			case IP_CONST_WS_ARMOR_BONUS_CA2: nGoldNeed = WS_COST_ARMOR_BONUS_CA2; break; // N&B : utilisé pour bouclier egalement
			case IP_CONST_WS_ARMOR_FREEACTION: nGoldNeed =WS_COST_ARMOR_FREEACTION; break;
			case IP_CONST_WS_ARMOR_STRENGTH_BONUS2:
			case IP_CONST_WS_ARMOR_DEXTERITY_BONUS2:
			case IP_CONST_WS_ARMOR_CONSTITUTION_BONUS2:
			case IP_CONST_WS_ARMOR_INTELLIGENCE_BONUS2:
			case IP_CONST_WS_ARMOR_WISDOM_BONUS2:
			case IP_CONST_WS_ARMOR_CHARISMA_BONUS2:nGoldNeed =WS_COST_ARMOR_STAT_BONUS2; break;
		// BOUCLIERS ***********************************************************
			case IP_CONST_WS_SHIELD_REGENERATION1: nGoldNeed =WS_COST_SHIELD_REGENERATION1; break;
			case IP_CONST_WS_SHIELD_SPELLRESISTANCE10: nGoldNeed =WS_COST_SHIELD_SPELLRESISTANCE10; break;
			case IP_CONST_WS_SHIELD_BONUS_VIG_PLUS7:
			case IP_CONST_WS_SHIELD_BONUS_REF_PLUS7:
			case IP_CONST_WS_SHIELD_BONUS_VOL_PLUS7:nGoldNeed =WS_COST_SHIELD_BONUS_JS7; break;
			case IP_CONST_WS_SHIELD_STRENGTH_BONUS2:
			case IP_CONST_WS_SHIELD_DEXTERITY_BONUS2:
			case IP_CONST_WS_SHIELD_CONSTITUTION_BONUS2:
			case IP_CONST_WS_SHIELD_INTELLIGENCE_BONUS2:
			case IP_CONST_WS_SHIELD_WISDOM_BONUS2:
			case IP_CONST_WS_SHIELD_CHARISMA_BONUS2:nGoldNeed =WS_COST_ARMOR_STAT_BONUS2; break;
		 // CASQUES ************************************************************
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_ACID:
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_BLUDGEONING:
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_COLD:
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_DIVINE:
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_ELECTRICAL:
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_FIRE:
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_MAGICAL:
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_NEGATIVE:
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_PIERCING:
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_POSITIVE:
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_SLASHING:
			case IP_CONST_WS_HELM_DAMAGERESISTANCE5_SONIC: nGoldNeed =WS_COST_HELM_DAMAGERESISTANCE5; break;
			case IP_CONST_WS_HELM_STRENGTH_BONUS2:
			case IP_CONST_WS_HELM_DEXTERITY_BONUS2:
			case IP_CONST_WS_HELM_CONSTITUTION_BONUS2:
			case IP_CONST_WS_HELM_INTELLIGENCE_BONUS2:
			case IP_CONST_WS_HELM_WISDOM_BONUS2:
			case IP_CONST_WS_HELM_CHARISMA_BONUS2:nGoldNeed =WS_COST_ARMOR_STAT_BONUS2; break;
		// ANNEAUX *************************************************************
			case IP_CONST_WS_RING_FREEACTION: nGoldNeed =WS_COST_RING_FREEACTION; break;
			case IP_CONST_WS_RING_IMMUNE_DEATH: nGoldNeed =WS_COST_RING_IMMUNE_DEATH; break;
			case IP_CONST_WS_RING_IMMUNE_TERROR: nGoldNeed =WS_COST_RING_IMMUNE_TERROR; break;
			case IP_CONST_WS_RING_IMMUNE_ABSORBTION: nGoldNeed =WS_COST_RING_IMMUNE_ABSORBTION; break;
			case IP_CONST_WS_RING_STRENGTH_BONUS2:
			case IP_CONST_WS_RING_DEXTERITY_BONUS2:
			case IP_CONST_WS_RING_CONSTITUTION_BONUS2:
			case IP_CONST_WS_RING_INTELLIGENCE_BONUS2:
			case IP_CONST_WS_RING_WISDOM_BONUS2:
			case IP_CONST_WS_RING_CHARISMA_BONUS2:nGoldNeed =WS_COST_ARMOR_STAT_BONUS2; break;
		// AMULETTES ***********************************************************
			case IP_CONST_WS_AMULET_SKILL_APPRAISE_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_BLUFF_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_CONCENTRATION_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_CRAFT_ARMOR_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_CRAFT_TRAP_BONUS15  :
			case IP_CONST_WS_AMULET_SKILL_CRAFT_WEAPON_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_DISABLE_TRAP_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_DISCIPLINE_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_HEAL_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_HIDE_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_INTIMIDATE_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_LISTEN_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_LORE_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_MOVE_SILENTLY_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_OPEN_LOCK_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_PARRY_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_PERFORM_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_SEARCH_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_SET_TRAP_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_SPELLCRAFT_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_SPOT_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_TAUNT_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_TUMBLE_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_DIPLOMACY_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_CRAFT_ALCHEMY_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_SLEIGHT_OF_HAND_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_SURVIVAL_BONUS15 :
			case IP_CONST_WS_AMULET_SKILL_USE_MAGIC_DEVICE_BONUS15 : nGoldNeed =WS_COST_AMULET_COMPETENCE_BONUS15; break;
			case IP_CONST_WS_AMULET_STRENGTH_BONUS2:
			case IP_CONST_WS_AMULET_DEXTERITY_BONUS2:
			case IP_CONST_WS_AMULET_CONSTITUTION_BONUS2:
			case IP_CONST_WS_AMULET_INTELLIGENCE_BONUS2:
			case IP_CONST_WS_AMULET_WISDOM_BONUS2:
			case IP_CONST_WS_AMULET_CHARISMA_BONUS2:nGoldNeed =WS_COST_ARMOR_STAT_BONUS2; break;
		// BOTTES **************************************************************
			case IP_CONST_WS_BOOTS_DARKVISION: nGoldNeed =WS_COST_BOOTS_DARKVISION; break;
			case IP_CONST_WS_BOOTS_REGENERATION1: nGoldNeed =WS_COST_BOOTS_REGENERATION1; break;
			case IP_CONST_WS_BOOTS_STRENGTH_BONUS2:
			case IP_CONST_WS_BOOTS_DEXTERITY_BONUS2:
			case IP_CONST_WS_BOOTS_CONSTITUTION_BONUS2:
			case IP_CONST_WS_BOOTS_INTELLIGENCE_BONUS2:
			case IP_CONST_WS_BOOTS_WISDOM_BONUS2:
			case IP_CONST_WS_BOOTS_CHARISMA_BONUS2:nGoldNeed =WS_COST_ARMOR_STAT_BONUS2; break;
		// CAPES ***************************************************************
			case IP_CONST_WS_CLOAK_PARADE_BONUS2: nGoldNeed =WS_COST_CLOAK_PARADE_BONUS2; break;
			case IP_CONST_WS_CLOAK_STRENGTH_BONUS2:
			case IP_CONST_WS_CLOAK_DEXTERITY_BONUS2:
			case IP_CONST_WS_CLOAK_CONSTITUTION_BONUS2:
			case IP_CONST_WS_CLOAK_INTELLIGENCE_BONUS2:
			case IP_CONST_WS_CLOAK_WISDOM_BONUS2:
			case IP_CONST_WS_CLOAK_CHARISMA_BONUS2:nGoldNeed =WS_COST_ARMOR_STAT_BONUS2; break;
		// BRACELETS/CEINTUREs *************************************************
			case IP_CONST_WS_BRACERS_BELT_CA_VS_BLUDGEONING_BONUS5:
			case IP_CONST_WS_BRACERS_BELT_CA_VS_PIERCING_BONUS5 :
				case IP_CONST_WS_BRACERS_BELT_CA_VS_SLASHING_BONUS5 :nGoldNeed =WS_COST_BRACERS_BELT_CA_VS_BONUS5; break;
				case IP_CONST_WS_BRACERS_BELT_WISDOM_BONUS2 :
				case IP_CONST_WS_BRACERS_BELT_INTELLIGENCE_BONUS2 :
				case IP_CONST_WS_BRACERS_BELT_STRENGTH_BONUS2 :
				case IP_CONST_WS_BRACERS_BELT_DEXTERITY_BONUS2 :
				case IP_CONST_WS_BRACERS_BELT_CHARISMA_BONUS2 :
				case IP_CONST_WS_BRACERS_BELT_CONSTITUTION_BONUS2 :nGoldNeed =WS_COST_ARMOR_STAT_BONUS2; break;

			default: assert(0, "Could not get gold value for enchantment id="~nService.to!string);
		}
	return nGoldNeed;
}








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
				default: throw new Exception("Cannot add Unlimited enchantment to item type "~baseItemType.to!string);
			}
		case TRUESEEING:                            return NWItemproperty(71);
		case RING_FREEACTION:                       return NWItemproperty(75);
		case ARMOR_FREEACTION:                      return NWItemproperty(75);
	}
}