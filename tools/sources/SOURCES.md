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
| [QuestieDB](https://github.com/Questie/QuestieDB) merged WoW Forever export (`tools/qdb`) | Objectives.lua (quests, objectives, givers), Routes/Generated.lua (starting zones, dungeon quests), Waypoints.lua, NodeData.lua (ore and herb spawns), Professions/Generated.lua (spots, trainers), item and NPC checks in `tools/audit/crosscheck.py` | 2026-10-13 |
| [cMaNGOS classic-db](https://github.com/cmangos/classic-db) | Item stats for gear scores (Classes/*Gear.lua, Classes/SpecGear.lua), recipes, loot and vendors (Professions/Generated.lua) | 2026-10-13 |

## Leveling and quest routes (Routes/Horde.lua, Races/*.lua, Travel.lua)

| Source | Feeds | Last checked |
|---|---|---|
| [Warcraft Tavern: WoW Forever](https://www.warcrafttavern.com/forever/) | Zone order, new zones and dungeons, patch notes | 2026-10-13 |
| [Wowhead](https://www.wowhead.com/) WoW Forever guides and database | Quest names, IDs, rewards, level ranges | 2026-10-13 |
| [Icy Veins](https://www.icy-veins.com/) WoW Forever leveling guides | Zone order, class leveling tips | 2026-10-13 |
| [wowforeverguides.com](https://wowforeverguides.com/) | Horde leveling route | 2026-10-13 |
| [theforeverera.com](https://theforeverera.com/) | Zone level ranges, new content | 2026-10-13 |
| [classicwowforever.com](https://classicwowforever.com/) | New zones, starting zones | 2026-10-13 |
| [zockify.com/forever](https://zockify.com/forever/) | Leveling, dungeons | 2026-10-13 |
| Official Blizzard WoW Forever posts and patch notes | Anything they change (final say after game data) | 2026-10-13 |

## Classes, specs and gear (Classes/*.lua, Classes/Specs.lua, SecondSpec.lua)

| Source | Feeds | Last checked |
|---|---|---|
| [Mobalytics WoW Forever class and spec guides](https://mobalytics.gg/wow-forever/) | Stat priorities and weights, playstyle tips, Forever changes per spec | 2026-10-13 |
| Icy Veins / Wowhead WoW Forever class guides | Stat priorities, pre-raid gear (RG.SPEC_HAND) | 2026-10-13 |
| [wowtbc.gg WoW Forever loot tables](https://wowtbc.gg/warcraftforever/) | Dungeon drops that changed in Forever | 2026-10-13 |

Waypath+ gives no talent advice on purpose: talent builds are not collected.

## Professions, fishing, camping (Professions/*.lua, Fish.lua, Camp.lua)

| Source | Feeds | Last checked |
|---|---|---|
| [wow-professions.com WoW Forever guides](https://www.wow-professions.com/forever) | 1-300 leveling plans, trainers, materials | 2026-10-13 |
| [wowtbc.gg WoW Forever professions](https://wowtbc.gg/warcraftforever/professions) | Cross-check for plans, Forever-only recipes, camping | 2026-10-13 |
| Warcraft Wiki ([warcraft.wiki.gg](https://warcraft.wiki.gg/)) | Recipe names, trainer names, fishing ranks | 2026-10-13 |

## Gold (Gold.lua)

| Source | Feeds | Last checked |
|---|---|---|
| WoW Forever gold-making guides (Icy Veins, Wowhead, Warcraft Tavern, zockify) | RG.GOLD tips | 2026-10-13 |
