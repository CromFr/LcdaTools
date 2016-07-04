Tool to update items stored in characters (bic file) and in the SQL database (using StoreCampaignObject).

Items are matched with their tag, and updated with a blueprint file.

Note: This won't work on other nwn2 servers.

```sh
# Build - debug
dub build
# Build - optimized debug
DFLAGS="-g -inline -O" dub build

# Help
./lcdaupdater --help

# Example
./lcdaupdater --update ITEM_TAG_A=new_item_resref_a&ITEM_TAG_B=new_item_resref_b --policy ITEM_TAG_A='["Cursed":Keep, "Var.nMyLocVar":Override]' -j8
```