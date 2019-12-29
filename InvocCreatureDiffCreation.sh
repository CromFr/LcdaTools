#!/bin/bash

D1_ITEM='{"type": "struct", "__struct_id": 1024, "value": {
    "__struct_id": 1024,
    "Repos_PosY": {
      "type": "word",
      "value": 0
    },
    "Pickpocketable": {
      "type": "byte",
      "value": 0
    },
    "EquippedRes": {
      "type": "resref",
      "value": "invoc_1cyan"
    },
    "Repos_PosX": {
      "type": "word",
      "value": 0
    },
    "Dropable": {
      "type": "byte",
      "value": 0
    }
  }}'
D2_ITEM=$(echo "$D1_ITEM" | jq ".value.EquippedRes.value = \"invoc_2yellow\"")
D3_ITEM=$(echo "$D1_ITEM" | jq ".value.EquippedRes.value = \"invoc_3orange\"")
D4_ITEM=$(echo "$D1_ITEM" | jq ".value.EquippedRes.value = \"invoc_4red\"")

for FILE in invoc_*.UTC; do

	FIRSTNAME=$(nwn-gff -i $FILE -k json | jq '.FirstName.value[]' -r)

	nwn-gff -i "$FILE" --set "FirstName=<c=cyan>$FIRSTNAME</c>" --set "TemplateResRef=d1_$FILE" --set "Equip_ItemList.\$=$D1_ITEM" -o "d1_$FILE"
	nwn-gff -i "$FILE" --set "FirstName=<c=yellow>$FIRSTNAME</c>" --set "TemplateResRef=d2_$FILE" --set "Equip_ItemList.\$=$D2_ITEM" -o "d2_$FILE"
	nwn-gff -i "$FILE" --set "FirstName=<c=orange>$FIRSTNAME</c>" --set "TemplateResRef=d3_$FILE" --set "Equip_ItemList.\$=$D3_ITEM" -o "d3_$FILE"
	nwn-gff -i "$FILE" --set "FirstName=<c=red>$FIRSTNAME</c>" --set "TemplateResRef=d4_$FILE" --set "Equip_ItemList.\$=$D4_ITEM" -o "d4_$FILE"
done
