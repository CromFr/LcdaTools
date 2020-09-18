module lcda.compat.x2_inc_itemprop;

import nwn.nwscript;
import nwn.gff;


enum  X2_IP_WORK_CONTAINER_TAG = "x2_plc_ipbox";
enum X2_IP_ADDRPOP_2DA = "des_crft_props" ;
enum X2_IP_POISONWEAPON_2DA = "des_crft_poison" ;
enum X2_IP_ARMORPARTS_2DA = "des_crft_aparts" ;
enum X2_IP_ARMORAPPEARANCE_2DA = "des_crft_appear" ;
enum    XP_IP_ITEMMODCONVERSATION_CTOKENBASE = 12220;
enum    X2_IP_ITEMMODCONVERSATION_MODE_TAILOR = 0;
enum    X2_IP_ITEMMODCONVERSATION_MODE_CRAFT = 1;
enum    X2_IP_MAX_ITEM_PROPERTIES = 8;
enum    X2_IP_ARMORTYPE_NEXT = 0;
enum    X2_IP_ARMORTYPE_PREV = 1;
enum    X2_IP_ARMORTYPE_RANDOM = 2;
enum    X2_IP_WEAPONTYPE_NEXT = 0;
enum    X2_IP_WEAPONTYPE_PREV = 1;
enum    X2_IP_WEAPONTYPE_RANDOM = 2;
enum    X2_IP_ADDPROP_POLICY_REPLACE_EXISTING = 0;
enum    X2_IP_ADDPROP_POLICY_KEEP_EXISTING = 1;
enum    X2_IP_ADDPROP_POLICY_IGNORE_EXISTING =2;


void IPSafeAddItemProperty(ref GffStruct oItem, NWItemproperty ip, NWFloat fDuration = 0.0f, NWInt nAddItemPropertyPolicy = X2_IP_ADDPROP_POLICY_REPLACE_EXISTING, NWInt bIgnoreDurationType = false, NWInt bIgnoreSubType = false)
{
	int nType = GetItemPropertyType(ip);
	int nSubType = GetItemPropertySubType(ip);
	int nDuration;
	// if duration is 0.0f, make the item property permanent
	if (fDuration == 0.0f)
	{

		nDuration = DURATION_TYPE_PERMANENT;
	} else
	{

		nDuration = DURATION_TYPE_TEMPORARY;
	}

	int nDurationCompare = nDuration;
	if (bIgnoreDurationType)
	{
		nDurationCompare = -1;
	}

	if (nAddItemPropertyPolicy == X2_IP_ADDPROP_POLICY_REPLACE_EXISTING)
	{

		// remove any matching properties
		if (bIgnoreSubType)
		{
			nSubType = -1;
		}
		IPRemoveMatchingItemProperties(oItem, nType, nDurationCompare, nSubType );
	}
	else if (nAddItemPropertyPolicy == X2_IP_ADDPROP_POLICY_KEEP_EXISTING )
	{
		 // do not replace existing properties
		if(IPGetItemHasProperty(oItem, ip, nDurationCompare, bIgnoreSubType))
		{
		  return; // item already has property, return
		}
	}
	else //X2_IP_ADDPROP_POLICY_IGNORE_EXISTING
	{

	}

	if (nDuration == DURATION_TYPE_PERMANENT)
	{
		AddItemProperty(nDuration,ip, oItem);
	}
	else
	{
		AddItemProperty(nDuration,ip, oItem,fDuration);
	}
}


void IPRemoveMatchingItemProperties(ref GffStruct oItem, NWInt nItemPropertyType, NWInt nItemPropertyDuration = DURATION_TYPE_TEMPORARY, NWInt nItemPropertySubType = -1)
{
	NWItemproperty ip = GetFirstItemProperty(oItem);

	// valid ip?
	while (GetIsItemPropertyValid(ip))
	{
		// same property type?
		if ((GetItemPropertyType(ip) == nItemPropertyType))
		{
			// same duration or duration ignored?
			if (GetItemPropertyDurationType(ip) == nItemPropertyDuration || nItemPropertyDuration == -1)
			{
				 // same subtype or subtype ignored
				 if  (GetItemPropertySubType(ip) == nItemPropertySubType || nItemPropertySubType == -1)
				 {
					  // Put a warning into the logfile if someone tries to remove a permanent ip with a temporary one!
					  /*if (nItemPropertyDuration == DURATION_TYPE_TEMPORARY &&  GetItemPropertyDurationType(ip) == DURATION_TYPE_PERMANENT)
					  {
						 WriteTimestampedLogEntry("x2_inc_itemprop:: IPRemoveMatchingItemProperties() - WARNING: Permanent item property removed by temporary on "+GetTag(oItem));
					  }
					  */
					  RemoveItemProperty(oItem, ip);
				 }
			}
		}
		ip = GetNextItemProperty(oItem);
	}
}



NWInt IPGetItemHasProperty(ref GffStruct oItem, NWItemproperty ipCompareTo, NWInt nDurationCompare, NWInt bIgnoreSubType = FALSE)
{
    NWItemproperty ip = GetFirstItemProperty(oItem);

    //PrintString ("Filter - T:" + IntToString(GetItemPropertyType(ipCompareTo))+ " S: " + IntToString(GetItemPropertySubType(ipCompareTo)) + " (Ignore: " + IntToString (bIgnoreSubType) + ") D:" + IntToString(nDurationCompare));
    while (GetIsItemPropertyValid(ip))
    {
        // PrintString ("Testing - T: " + IntToString(GetItemPropertyType(ip)));
        if ((GetItemPropertyType(ip) == GetItemPropertyType(ipCompareTo)))
        {
             //PrintString ("**Testing - S: " + IntToString(GetItemPropertySubType(ip)));
             if (GetItemPropertySubType(ip) == GetItemPropertySubType(ipCompareTo) || bIgnoreSubType)
             {
               // PrintString ("***Testing - d: " + IntToString(GetItemPropertyDurationType(ip)));
                if (GetItemPropertyDurationType(ip) == nDurationCompare || nDurationCompare == -1)
                {
                    //PrintString ("***FOUND");
                      return TRUE; // if duration is not ignored and durationtypes are equal, true
                 }
            }
        }
        ip = GetNextItemProperty(oItem);
    }
    //PrintString ("Not Found");
    return FALSE;
}