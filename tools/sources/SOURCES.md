# Waypath+ sources

Every guide and data source Waypath+ draws on, what it feeds, and when it was last checked.
The twice-weekly update reads this file first, checks every source for changes since its
"last checked" date, searches for **new** WoW Forever guides and adds them here, and updates
the dates. When two sources disagree, prefer (in order): WoW Forever's own data (QuestieDB's
merged Forever export) > official Blizzard posts > the newest dated guide > older guides.
Write down any disagreement under "Open questions" in BACKLOG.md instead of guessing.

## Game data (machine-readable, regenerated every run)

| Source | Feeds | Last checked |
|---|---|---|
| [QuestieDB](https://github.com/Questie/QuestieDB) merged WoW Forever export (`tools/qdb`) | Objectives.lua (quests, objectives, givers), Routes/Generated.lua (starting zones, dungeon quests), Waypoints.lua, NodeData.lua (ore and herb spawns), Professions/Generated.lua (spots, trainers), item and NPC checks in `tools/audit/crosscheck.py` | 2026-10-26 |
| [cMaNGOS classic-db](https://github.com/cmangos/classic-db) | Item stats for gear scores (Classes/*Gear.lua, Classes/SpecGear.lua), recipes, loot and vendors (Professions/Generated.lua) | 2026-10-26 |

## Leveling and quest routes (Routes/Horde.lua, Races/*.lua, Travel.lua)

| Source | Feeds | Last checked |
|---|---|---|
| [Warcraft Tavern: WoW Forever](https://www.warcrafttavern.com/forever/) | Zone order, new zones and dungeons, patch notes | 2026-10-26 |
| [Wowhead](https://www.wowhead.com/) WoW Forever guides and database | Quest names, IDs, rewards, level ranges | 2026-10-26 |
| [Icy Veins](https://www.icy-veins.com/) WoW Forever leveling guides | Zone order, class leveling tips | 2026-10-26 |
| [wowforeverguides.com](https://wowforeverguides.com/) | Horde leveling route | 2026-10-26 |
| [theforeverera.com](https://theforeverera.com/) | Zone level ranges, new content | 2026-10-26 |
| [classicwowforever.com](https://classicwowforever.com/) | New zones, starting zones | 2026-10-26 |
| [zockify.com/forever](https://zockify.com/forever/) | Leveling, dungeons | 2026-10-26 |
| Official Blizzard WoW Forever posts and patch notes | Anything they change (final say after game data) | 2026-10-26 |
| [Blizzard forum: Forever Beta Development Notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-15/2360696/5) | Official per-build change list (quest fixes, level requirements, class changes for the 2nd Spec tab notes) | 2026-10-26 |
| [The Forever Era patch notes](https://theforeverera.com/en/patch-notes/) | Every beta build in order (October 16: five bug fixes, nothing for routes; nothing newer by October 26) | 2026-10-26 |
| [ForeverChanges patch notes](https://foreverchanges.pro/patch-notes) (new 2026-10-26) | Per-build changes including unannounced hotfixes (build 1.60.1.70532 from October 22, beta closed October 23, launch November 4), item tooltips (foreverchanges.pro/item/<id>) | 2026-10-26 |
| [Leprestore Riverglades guide](https://leprestore.com/guides/world-of-warcraft-forever/wow-forever-riverglades-guide/) and [1-60 guide](https://leprestore.com/guides/world-of-warcraft-forever/wow-forever-leveling-guide-1-60/) (new 2026-10-26) | Riverglades 35-45 (Rog'mar the only named Horde hub, no Horde quests yet), Shen'dralas 40-50 (evidence.json) | 2026-10-26 |
| [Mobalytics zone map](https://mobalytics.gg/wow-forever/guides/zone-map-level-ranges) | Zone level ranges (tools/sources/evidence.json) | 2026-10-26 |
| [wow4ever.quest 1-60 guide](https://wow4ever.quest/en/articles/guia-subida-1-60-wow-forever) | Zone level ranges, Horde 10-35 route (evidence.json) | 2026-10-26 |
| [wowf.io Riverglades](https://wowf.io/en/zones/riverglades), [wowclassicforever.info Riverglades](https://wowclassicforever.info/zones/riverglades/) | Riverglades: Rog'mar flight links, Krol'dok Stronghold 40-45 (corrected from 40-55), routes in | 2026-10-26 |

## Classes, specs and gear (Classes/*.lua, Classes/Specs.lua, SecondSpec.lua)

| Source | Feeds | Last checked |
|---|---|---|
| [Mobalytics WoW Forever class and spec guides](https://mobalytics.gg/wow-forever/) | Stat priorities and weights, playstyle tips, Forever changes per spec | 2026-10-26 |
| Icy Veins / Wowhead WoW Forever class guides | Stat priorities, pre-raid gear (RG.SPEC_HAND) | 2026-10-26 |
| [wowtbc.gg WoW Forever loot tables](https://wowtbc.gg/warcraftforever/) | Dungeon drops that changed in Forever | 2026-10-26 |

Waypath+ gives no talent advice on purpose: talent builds are not collected.

## Professions, fishing, camping (Professions/*.lua, Fish.lua, Camp.lua)

| Source | Feeds | Last checked |
|---|---|---|
| [wow-professions.com WoW Forever guides](https://www.wow-professions.com/forever) | 1-300 leveling plans, trainers, materials | 2026-10-26 |
| [wowtbc.gg WoW Forever professions](https://wowtbc.gg/warcraftforever/professions) | Cross-check for plans, Forever-only recipes, camping | 2026-10-26 |
| Warcraft Wiki ([warcraft.wiki.gg](https://warcraft.wiki.gg/)) | Recipe names, trainer names, fishing ranks | 2026-10-26 |
| [wowforever.be fishing](https://wowforever.be/tradeskills/forever/fishing/), [wofwforever.com fishing](https://wofwforever.com/en/guides/wow-forever-fishing-guide/), [wowforeverguides.com fishing](https://wowforeverguides.com/professions/fishing) | Fishing zone skill table (Wowhead's WoW Forever beta table), poles, lures, Extravaganza items, camp objects | 2026-10-26 |
| [Warcraft Tavern fishing overview](https://www.warcrafttavern.com/forever/guides/fishing/), [Endgame Tools item pages](https://endgametools.com/en/wow-forever/items/6367) (new 2026-10-26) | Pole and lure bonuses on build 1.60.1.70532 (Classic values: Big Iron +20), Blump pole is Alliance-only | 2026-10-26 |

## Gold (Gold.lua)

| Source | Feeds | Last checked |
|---|---|---|
| WoW Forever gold-making guides (Icy Veins, Wowhead, Warcraft Tavern, zockify) | RG.GOLD tips | 2026-10-26 |
