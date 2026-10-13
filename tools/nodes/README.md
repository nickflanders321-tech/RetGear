# Mining node generator

Builds `NodeData.lua`: every spot where a mining vein can spawn in WoW Forever, per map
(QuestieDB Forever object data, converted to Forever's maps), with which ores spawn there.
RetGear's ore alert uses it to tell you when you walk near a vein you can mine.

```sh
git clone --depth 1 https://github.com/Questie/QuestieDB.git /tmp/qdb
lua5.1 dump.lua /tmp/qdb/data/Forever/foreverObjectDB.lua /tmp/veins.tsv
python3 gen.py /tmp/qdb /tmp/veins.tsv ../../NodeData.lua
```
