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

Run it after `tools/nodes` (it reads `NodeData.lua`). With `--wago <dir>` (the data/wago branch: WoW Forever's own
client tables) every recipe takes Forever's reagents, item made and yield, recipe items their Forever skill
requirement, and each recipe gets `c = { yellow, grey }`, the skill where it turns yellow and grey. In game the
Professions tab uses those colours until your own profession window shows the real ones.

## Keeping the plans right: `compare.py` and `check.py`

`python3 tools/profs/compare.py .` lists every step where a plan differs from wow-professions.com's WoW Forever
guide (the routes the hourly watcher saves in tools/sources/profguides/). Run it after the watcher reports a
changed guide, update the plan, then run `check.py`.


```sh
python3 tools/profs/check.py /tmp/wago .            # report; exits 1 on an error
python3 tools/profs/check.py /tmp/wago . --fix-n    # after editing a plan: fill in n for new steps (n = 0)
```

Checks every craft step of every plan against WoW Forever's own tables: the craft is a recipe of that profession,
you can learn it by the step's start, it doesn't turn grey before the step ends, `n` covers what the game's
skill-up chances need (orange always gives a point, then `(grey - skill) / (grey - yellow)`), the materials text
matches the game's reagents, and ranks are trained at 50, 125 and 200. `tools/watch/regenerate.sh` runs it every
hour, so a game patch that moves a recipe's range stops the release and opens a `needs-claude` issue.

WoW Forever's ranges differ from Classic's past about 200: in Blacksmithing, Leatherworking and Tailoring most
recipes turn grey 20 to 45 points earlier, and their patterns need that much less skill. Plans from Classic guides
go grey there; plan from the tables (yellow and grey per recipe), not from Classic sites.
