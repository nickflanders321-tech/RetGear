# QuestieDB Forever data

All generators read QuestieDB's **merged** WoW Forever data: the classic database plus
Forever's own quests, NPCs and changes (Zephras Isle, the new class quests such as the
Forsaken paladin chain, new dungeons, changed quest levels). Build it with:

```sh
sh tools/qdb/export.sh /tmp/qdb
C=/tmp/qdb/src/corrections/Forever/combined
lua5.1 tools/objectives/dump.lua $C /tmp/forever.json && python3 tools/objectives/gen.py /tmp/qdb /tmp/forever.json .
lua5.1 tools/waypoints/dump.lua $C/foreverNpcDB.lua /tmp/npcs.tsv && python3 tools/waypoints/gen.py /tmp/qdb /tmp/npcs.tsv .
lua5.1 tools/nodes/dump.lua $C/foreverObjectDB.lua /tmp/veins.tsv && python3 tools/nodes/gen.py /tmp/qdb /tmp/veins.tsv NodeData.lua
```

The dump scripts also still accept the raw `data/Forever` files.
