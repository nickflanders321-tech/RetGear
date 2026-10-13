# Profession data generator

Builds `Professions/Generated.lua`, which the Professions tab uses to count materials and to send
you somewhere (double-click a place and the arrow takes you there):

- `RG.RECIPES`: the reagents for every craft in `Professions/*.lua` plans (and for crafted reagents
  such as bolts, bars and elixirs), from the classic database's trade skill spells. Forever-only
  recipes fall back to the guide's own material text. In game, opening a profession window replaces
  these with what the client shows.
- `RG.MAT_INFO`, `RG.MAT_SPOTS`, `RG.MAT_VENDORS`, `RG.MAT_NODES`, `RG.MAT_FISH`: what kind of material
  each reagent is and where it comes from: mobs (loot tables, Horde-safe, not elite, not in dungeons),
  Horde vendors, herb and ore nodes, fishing zones.
- `RG.GATHER_SPOTS`: the densest cluster of each herb and vein per zone (from `NodeData.lua`).
- `RG.SKIN_SPOTS`: skinnable beasts by level. `RG.FISH_SPOTS`: fishing pools.
- `RG.PROF_TRAINERS`: a map pin for every trainer named in the plans. `RG.ZONE_MAPS`: zone name to map.

Coordinates come from QuestieDB's merged WoW Forever data (already on Forever's maps).

```sh
C=/tmp/qdb/src/corrections/Forever/combined
lua5.1 tools/waypoints/dump.lua $C/foreverNpcDB.lua /tmp/npcs.tsv
lua5.1 tools/nodes/dump.lua $C/foreverObjectDB.lua /tmp/objects.tsv
lua5.1 tools/gear/dump.lua $C /tmp/forever_gear.json
lua5.1 tools/profs/items_dump.lua $C /tmp/items.tsv
python3 tools/profs/gen.py /tmp/classic.sql /tmp/forever_gear.json /tmp/qdb /tmp/npcs.tsv /tmp/objects.tsv . /tmp/items.tsv
```

Run it after `tools/nodes` (it reads `NodeData.lua`).
