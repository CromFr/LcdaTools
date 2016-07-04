import nwnconstants;
import std.conv: to;




mixin((){
		string ret = `enum EnchantmentId{`;
		foreach(m ; __traits(allMembers, mixin(__MODULE__))){
			static if(m.length>12 && m[0..12]=="IP_CONST_WS_"){

				ret ~= m[12..$]~" = "~m~",";
			}
		}
		ret ~= `DAMAGETYPE_ACID       = IP_CONST_DAMAGETYPE_ACID,`;
		ret ~= `DAMAGETYPE_FIRE       = IP_CONST_DAMAGETYPE_FIRE,`;
		ret ~= `DAMAGETYPE_COLD       = IP_CONST_DAMAGETYPE_COLD,`;
		ret ~= `DAMAGETYPE_ELECTRICAL = IP_CONST_DAMAGETYPE_ELECTRICAL,`;
		ret ~= `DAMAGETYPE_NEGATIVE   = IP_CONST_DAMAGETYPE_NEGATIVE,`;
		ret ~= `DAMAGETYPE_POSITIVE   = IP_CONST_DAMAGETYPE_POSITIVE,`;
		ret ~= `DAMAGETYPE_DIVINE     = IP_CONST_DAMAGETYPE_DIVINE,`;
		ret ~= `}`;
		return ret;
	}());



// Copy/paste from LCDA lib_forge_epique.nss
// Added default: assert(0, "Could not get gold value for enchantment id="~nService.to!string);
// to PrixDuService(...)


const int WS_COST_ACID_PROPERTY = 300000; // All elemental damages use this.
const int WS_COST_ATTACK_BONUS = 100000;
const int WS_COST_ENHANCEMENT_BONUS = 150000;
const int WS_COST_HASTE = 300000;
const int WS_COST_KEEN = 300000;
const int WS_COST_TRUESEEING = 800000;
const int WS_COST_SPELLRESISTANCE = 150000;
const int WS_COST_REGENERATION2 = 300000;
const int WS_COST_MIGHTY_5 = 100000;
const int WS_COST_MIGHTY_10 = 300000;
const int WS_COST_UNLIMITED_3 = 200000;
const int WS_COST_ARMOR_BONUS_CA2 = 300000;
const int WS_COST_ARMOR_FREEACTION = 150000;
const int WS_COST_ARMOR_STAT_BONUS2 = 450000; // All stat bonuses use this.
const int WS_COST_SHIELD_REGENERATION1 = 150000;
const int WS_COST_SHIELD_SPELLRESISTANCE10 = 150000;
const int WS_COST_SHIELD_BONUS_JS7 = 75000; // ALL DD bonuses for shield use this.
const int WS_COST_HELM_DAMAGERESISTANCE5 = 300000; // All damage resitances for helm use this.
const int WS_COST_RING_FREEACTION = 150000 ;
const int WS_COST_RING_IMMUNE_DEATH = 500000 ;
const int WS_COST_RING_IMMUNE_TERROR = 150000 ;
const int WS_COST_RING_IMMUNE_ABSORBTION = 150000 ;
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








int PrixDuService(int nService)
{
	int nGoldNeed = 0;
	//SpeakString("Determination du prix");
	switch (nService)
		{
		// ARMES ***************************************************************
			case IP_CONST_DAMAGETYPE_ACID:
			case IP_CONST_DAMAGETYPE_FIRE:
			case IP_CONST_DAMAGETYPE_COLD:
			case IP_CONST_DAMAGETYPE_ELECTRICAL:
			case IP_CONST_DAMAGETYPE_NEGATIVE:
			case IP_CONST_DAMAGETYPE_POSITIVE:
			case IP_CONST_DAMAGETYPE_DIVINE:
				nGoldNeed = WS_COST_ACID_PROPERTY; break;
			case IP_CONST_WS_ATTACK_BONUS: nGoldNeed = WS_COST_ATTACK_BONUS; break;
			case IP_CONST_WS_ENHANCEMENT_BONUS:
			{
				nGoldNeed = WS_COST_ENHANCEMENT_BONUS;
				break;
			}
			case IP_CONST_WS_HASTE: nGoldNeed = WS_COST_HASTE; break;
			case IP_CONST_WS_KEEN: nGoldNeed = WS_COST_KEEN;break;
			case IP_CONST_WS_TRUESEEING: nGoldNeed = WS_COST_TRUESEEING;break;
			case IP_CONST_WS_SPELLRESISTANCE: nGoldNeed = WS_COST_SPELLRESISTANCE; break;
			case IP_CONST_WS_REGENERATION: nGoldNeed = WS_COST_REGENERATION2; break; // utilisé par tous les items d'equipements
			case IP_CONST_WS_MIGHTY_5: nGoldNeed = WS_COST_MIGHTY_5; break;
			case IP_CONST_WS_MIGHTY_10: nGoldNeed = WS_COST_MIGHTY_10; break;
			case IP_CONST_WS_UNLIMITED_3: nGoldNeed = WS_COST_UNLIMITED_3; break;
		// ARMURES *************************************************************
			case IP_CONST_WS_ARMOR_BONUS_CA2: nGoldNeed = WS_COST_ARMOR_BONUS_CA2; break;
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