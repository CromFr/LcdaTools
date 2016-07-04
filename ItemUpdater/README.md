Tool to update items stored in characters (bic file) and in the SQL database (using StoreCampaignObject).

Items are matched with their tag, and updated with a blueprint file.

Note: This won't work on other nwn2 servers.

```sh
dub build
./lcdaupdater --help


./lcdaupdater --update ITEM_TAG_A=new_item_resref_a,ITEM_TAG_B=new_item_resref_b
```