# Waypoint generator

Builds `Waypoints.lua` (route-step, quest-giver, dungeon-entrance and camp waypoints) from
QuestieDB's WoW Forever NPC data, whose coordinates are already converted to Forever's maps.

```sh
git clone --depth 1 https://github.com/Questie/QuestieDB.git /tmp/qdb
lua5.1 dump.lua /tmp/qdb/data/Forever/foreverNpcDB.lua /tmp/npcs.tsv
python3 gen.py /tmp/qdb /tmp/npcs.tsv ../..
```

Steps are matched to the first NPC or mob they name, to a town (via an NPC who lives there,
see `PLACES` in gen.py), or to a role ("flight path", "innkeeper"). Add a town to `PLACES`
when new route text mentions one. Steps with nothing to point at get no pin.
