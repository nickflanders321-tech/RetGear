# Gathering node generator

Builds `NodeData.lua`: every spot where a mining vein or an herb can spawn in WoW Forever, per
map (QuestieDB's merged Forever object data, converted to Forever's maps), with which ores or
herbs spawn there, plus the best zones for each (Alliance home zones left out). Waypath+'s ore
and herb alerts and the Professions tab's "where to gather" lists use it.

```sh
git clone --depth 1 https://github.com/Questie/QuestieDB.git /tmp/qdb
lua5.1 dump.lua /tmp/qdb/data/Forever/foreverObjectDB.lua /tmp/veins.tsv
python3 gen.py /tmp/qdb /tmp/veins.tsv ../../NodeData.lua
```
