# Coverage audit

`lua5.1 tools/audit/audit.lua [--markdown]` loads the add-on's data once for every playable
Horde race and class (28 combinations) and checks that each gets the same guide:

- the route covers levels 1-60 with a questing zone and the starting zone has steps;
- every quest a generated step names can be taken by that race and class;
- no step or note speaks to another class (class-only lines start with "Paladins: ", etc.
  and are hidden from other classes) or assumes a profession ("Miners: ...");
- how many class quests and dungeon quests each combination gets.

It exits non-zero on a questing problem, and runs on every push (the table appears in the
GitHub Actions summary). Gear and profession columns show what's still to come.

# Accuracy cross-check

`python3 tools/audit/crosscheck.py . /tmp/forever.json /tmp/forever_gear.json [lua5.1]`
(the two JSON files come from `tools/objectives/dump.lua` and `tools/gear/dump.lua`) checks
that everything is *read* correctly, not just present:

- **Generators vs the add-on:** what tools/*/gen.py read out of the Lua data files (class
  weights, weapons and armor; profession crafts, materials and trainers; route steps,
  dungeon and bank-alt quests, the camping plan) must equal what the add-on itself loads
  (`dump_truth.lua`). This is the check that would have caught Paladins being offered staves
  and fishing poles (a one-line `weapons = { ... }` table was read past its end).
- **Hand-written data vs WoW Forever:** quests in dungeon lists, bank-alt quests and gear
  sources must exist in Forever's quest data and be Horde-friendly; gear guide and 2nd-spec
  items must exist and be usable by that class at the listed level.
- **Quest data coverage:** every Horde quest with a name should be in Objectives.lua.

It exits 1 on a problem; warnings (a giver written differently, a few uncovered quests) are
listed for the next update to look at. The twice-weekly update runs it before committing.

## Gear scores (stats.py)

`python3 tools/audit/stats.py <addon dir> <LibItemDB dir> <wago dir> [lua]` runs every weapon and armor piece in WoW
Forever through the add-on's own stat reader (Core.lua `RG.ParseItemStats`, through `stats_check.lua`) in four forms:
the stat table plus the game's own Equip: spell text (from the client's Spell table), the same with every stat also
written out as Equip: text (the way the game shows spell power twice), stats only as Classic text, and stats as ratings
in text. Each must equal the item's true stats (LibItemDB's walk of the client). Then `RG.ScoreStats` (tooltips and
upgrade arrows) must equal tools/gear/gen.py's `score()` (the gear lists) for every class's and spec's weights, every
weapon model and levels 10, 30, 47 and 60. tools/watch/regenerate.sh runs it; any difference stops the release.

# Other route guides

`sh tools/audit/compare_guides.sh [report.md]` compares Waypath+'s route, race by race, with other public route
guides. It runs `compare_guides.py` after fetching the guides into `tools/audit/.cache` (ignored by git) and dumping our
route for every race through the harness (`run.lua --dump-route`).

- **Polestar's 1-60 guides** (github.com/fitzforge/polestar, GPL-3.0). Every step lists the quest IDs it takes, so
  quests are compared by ID: which ones Polestar does that we don't, and the reverse.
- **RestedXP's own free Forever guides** (github.com/RestedXP/RXPGuides, `Guides/forever`, CC BY-NC-SA 4.0). These
  cover each race's start to about level 22, compared by quest ID with RestedXP's race and class tags applied.
- **The community RestedXP-format guide** (github.com/craigory1591/wow-forever-guide). It has no licence, so only
  facts are read from it: the level bracket of each zone, and the quest titles its steps name.

Journey isn't compared: its Terms of Service forbid extracting its route data or collecting it with scripts. Nothing
from any of these guides is copied into Waypath+: the report only says where we differ.

The comparison is for Warriors (every race has them). For each race the report gives:

- the zone table, with each guide's levels;
- quests each guide does that our route doesn't;
- the class quests each guide weaves into its route, and when the bot did ours;
- each route's zone path, counting how often it goes back to a zone it had left.

With `BOT=1 sh tools/audit/compare_guides.sh report.md`, the bot plays every race to 60 first, about 4 minutes each.
The report then uses the bot's actual path and class quests rather than just the route's zone list.

The report has one table per race: zone, our level window, theirs, and a flag when we start a zone 4+ levels away
from every guide that goes there, or go where neither does. Our window is when the guide will send you to a zone;
theirs is when their route is there, so only start levels are compared. A difference marks where to look, not
necessarily a mistake.
