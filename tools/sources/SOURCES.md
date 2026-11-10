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
| [QuestieDB](https://github.com/Questie/QuestieDB) merged WoW Forever export (`tools/qdb`) | Objectives.lua (quests, objectives, givers), Routes/Generated.lua (starting zones, dungeon quests), Waypoints.lua, NodeData.lua (ore and herb spawns), Professions/Generated.lua (spots, trainers), item and NPC checks in `tools/audit/crosscheck.py`, camp blueprint drops (Camp.lua: Blueprint: Trapper's Workbench from Houndmaster Loksey) | 2026-11-08 |
| [LibItemDB](https://www.curseforge.com/wow/addons/libitemdb) by Pimptasty (MIT; new 2026-11-07) | WoW Forever item stats from a scan of the game client (build 1.60.1): used first for gear scores (Classes/*Gear.lua, Classes/SpecGear.lua), adds WoW Forever's own items (3,558 the cMaNGOS database doesn't have) and Forever's changes to Classic items (1,355 green-or-better items score differently). Fetched weekly onto the data/itemdb branch by .github/workflows/fetch-itemdb.yml | 2026-11-07 |
| [cMaNGOS classic-db](https://github.com/cmangos/classic-db) | Item stats for gear scores where LibItemDB has none (Classes/*Gear.lua, Classes/SpecGear.lua), vendors (npc_vendor, also for gear QuestieDB lists no vendor for), recipes, loot (Professions/Generated.lua) | 2026-11-07 |
| [Gethe/wow-ui-source `forever` branch](https://github.com/Gethe/wow-ui-source/tree/forever) (new 2026-11-07; newest build still 1.60.1.70862 on 2026-11-09) | The Forever client's own Blizzard UI code and generated API docs, one commit per build: `git diff <old> <new>` shows exactly which functions, events and frames a build changed (Compat.lua, step 1 of UPDATE.md). 1.60.1.70840 (November 6): only character select, subscription pop-up and shard-transfer toast code, no API changes; 1.60.1.70862: only gamepad navigation (SmartNavigation, FrameControlsManager unfocus) and Barber Shop code, no API changes | 2026-11-09 |

## Leveling and quest routes (Routes/Horde.lua, Races/*.lua, Travel.lua)

| Source | Feeds | Last checked |
|---|---|---|
| [Warcraft Tavern: WoW Forever](https://www.warcrafttavern.com/forever/) | Zone order, new zones and dungeons (Drowned City and Krol'dok entrance guides), patch notes | 2026-11-09 |
| [Wowhead](https://www.wowhead.com/) WoW Forever guides and database | Quest names, IDs, rewards, level ranges | 2026-11-02 |
| [Icy Veins](https://www.icy-veins.com/) WoW Forever leveling guides | Zone order, class leveling tips | 2026-11-02 |
| [wowforeverguides.com](https://wowforeverguides.com/) | Horde leveling route | 2026-11-02 |
| [theforeverera.com](https://theforeverera.com/) | Zone level ranges, new content | 2026-11-02 |
| [classicwowforever.com](https://classicwowforever.com/) | New zones, starting zones | 2026-11-02 |
| [zockify.com/forever](https://zockify.com/forever/) | Leveling, dungeons | 2026-11-02 |
| Official Blizzard WoW Forever posts and patch notes | Anything they change (final say after game data) | 2026-11-10 |
| [Blizzard: Dungeon Enemy XP Increased - 8 November](https://eu.forums.blizzard.com/en/wow/t/dungeon-enemy-xp-increased-8-november/640598/1) (new 2026-11-10) | Kill XP in dungeons +50% since November 8 (Group.lua RG.DUNGEON_XP_TIP on the route's dungeon cards) | 2026-11-10 |
| [Bind on Forever: Riverglades](https://bindonforever.com/zones/riverglades) (new 2026-11-10; game files of build 1.60.1.70862) | Riverglades from the client files: Rog'mar flight node 3203, Rog'mar subzone level 38, a retired "zzOLD Bolder'ok" flight node, Powderfuse Port neutral; no quest names (they're server-side) | 2026-11-10 |
| [Mmonster: The Drowned City](https://mmonster.co/wow-forever/guides/dungeons/the-drowned-city), [Krol'dok Stronghold](https://mmonster.co/wow-forever/guides/dungeons/kroldok-stronghold), [Alcaz Prison](https://mmonster.co/wow-forever/guides/dungeons/alcaz-prison), [Blackmaw Hold](https://mmonster.co/wow-forever/guides/dungeons/blackmaw-hold) and [The Shaper's Terrace](https://mmonster.co/wow-forever/guides/dungeons/shapers-terrace) | Dungeon entrances with coordinates and Horde routes, quest names and givers, boss quest items (all updated 2026-11-07) | 2026-11-09 |
| [Warcraft Tavern dungeon guides](https://www.warcrafttavern.com/forever/guides/alcaz-island-prison/) (Alcaz Island Prison, [Blackmaw Hold](https://www.warcrafttavern.com/forever/guides/blackmaw-hold/), [Shaper's Terrace](https://www.warcrafttavern.com/forever/guides/shapers-terrace/); new 2026-11-09) | Second source for the entrance coordinates (Alcaz 75, 15; Blackmaw tunnel 38.7, 33.4; Shaper's Terrace 48.1, 6.1); no quests known | 2026-11-09 |
| [wowforeverguides.com dungeon guides](https://wowforeverguides.com/dungeons/alcaz-prison) (new 2026-11-09) | Horde route to Alcaz Island (Brackenwall Village, swim across), Alcaz Prison 48-53; last updated October 7, no coordinates | 2026-11-09 |
| [Blizzard class tuning for November 10](https://www.mmo-champion.com/threads/2670995-WoW-Forever-Class-Tuning-Incoming-November-10) (MMO-Champion repost of the November 6 blue post; new 2026-11-09) | Planned pet and Voidwalker durability, Affliction DoTs vs Wrack, Enhancement Strength over Intellect (Classes/Specs.lua notes) | 2026-11-09 |
| [allthings.how hotfix log](https://allthings.how/wow-forever-hotfixes-patch-notes/) (new 2026-11-09) | Every hotfix since launch (updated November 7: still only the November 5 and 6 batches) | 2026-11-09 |
| [ForeverChanges patch notes](https://foreverchanges.pro/patch-notes) | Hotfixes and client changes per build (November 8 dungeon kill XP +50%; nothing November 9; November 10 class tuning not live yet) | 2026-11-10 |
| [MMOHuts: dungeon kill XP hotfix](https://mmohuts.com/news/wow-forever-hotfix-boosts-dungeon-kill-xp-by-50), [Timesaver: dungeons vs questing](https://timesaver.gg/blog/wow-forever-dungeon-leveling-vs-questing) | November 8 hotfix: +50% XP from dungeon kills; dungeon quest XP still at the October 1 level, so quest first and repeat runs only with a fast group (dungeon cards since v1.29.0) | 2026-11-10 |
| [MMONerds: Riverglades](https://mmonerds.com/wow-forever-riverglades-zone-explained/) | Riverglades hubs and inns (no Horde quest names) | 2026-11-09 |
| [outputlag: dungeons and raids list](https://outputlag.com/guides/wow-forever-dungeons-and-raids-list/) | New dungeon levels and locations (no entrances for Alcaz, Blackmaw, Shaper's Terrace) | 2026-11-09 |
| [Blizzard forum: Forever Beta Development Notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-15/2360696/5) | Official per-build change list (quest fixes, level requirements, class changes for the 2nd Spec tab notes) | 2026-11-02 |
| [The Forever Era patch notes](https://theforeverera.com/en/patch-notes/) | Every beta build in order (November 3-4: UI fixes only, nothing for routes) | 2026-11-05 |
| [ForeverChanges patch notes](https://foreverchanges.pro/patch-notes) (new 2026-10-26) | Per-build changes including unannounced hotfixes (beta builds up to 1.60.1.70755 on November 3, November 3 Hunter hotfix; no live-server entries yet on November 5; November 6: a November 4 Warrior hotfix (Defiance, Defensive Stance as in the launch notes) and Chain Lightning still 2.5 sec on live realms, nothing for routes; November 7 client changes for build 1.60.1.70862: quest-item Use lines, Hyjal flask tooltips, five new dungeons in the client, the Adventurer's Tent rested tent, which is China-only, so nothing for routes), item tooltips (foreverchanges.pro/item/<id>) | 2026-11-08 |
| [Leprestore Riverglades guide](https://leprestore.com/guides/world-of-warcraft-forever/wow-forever-riverglades-guide/) and [1-60 guide](https://leprestore.com/guides/world-of-warcraft-forever/wow-forever-leveling-guide-1-60/) (new 2026-10-26) | Riverglades 35-45 (Rog'mar the only named Horde hub, no Horde quests yet), Shen'dralas 40-50 (evidence.json); unchanged since October 26 | 2026-11-06 |
| [Eternadex Horde route](https://eternadex.com/en/leveling/horde/) (new 2026-11-02) | Narrow 2-3 level windows per zone (Shen'dralas 41-43 before Riverglades 43-45); a route, not zone ranges, so not in evidence.json | 2026-11-02 |
| [Mmonster new zones](https://mmonster.co/wow-forever/guides/leveling/new-zones) (new 2026-11-02) | Riverglades 36-44 and its walk-ins, Mount Hyjal 55-60 with the Everlook - Tainted Foothills - Summit of Eternity flights, Valanaar inn (evidence.json, Travel.lua) | 2026-11-02 |
| [Skycoach new zones](https://skycoach.gg/blog/wow-forever/articles/all-new-zones-guide) (new 2026-11-02) | Shen'dralas 40-45, Riverglades 35-45, Zephras Isle skyship from the Skywatcher Plateau (evidence.json, Travel.lua) | 2026-11-02 |
| [Endgame Tools Riverglades atlas](https://endgametools.com/en/wow-forever/atlas/riverglades), [Forever Atlas Riverglades](https://wowforeveratlas.com/riverglades-guide) (new 2026-11-02) | Rog'mar and Farholde Keep flight links, Steamwheedle ship; still no Horde quest givers named | 2026-11-02 |
| [BlizzTrack `wowf` versions](https://blizztrack.com/view/wowf?type=versions) (new 2026-11-05) | The live game's build (product `wowf`, labeled "Stress Test"; 1.60.1.70790 since November 4). tools/watch/check.py asks it first | 2026-11-05 |
| [Timesaver launch patch notes and hotfix log](https://timesaver.gg/blog/wow-forever-launch-patch-notes) (new 2026-11-05) | Blizzard's November 2 launch notes by date: Ruins of Lordaeron quests at 15, training costs (Gold.lua), threat and class changes for the 2nd Spec tab | 2026-11-05 |
| [Overgear: how to get to Riverglades](https://overgear.com/guides/how-to-get/wow-forever/how-to-get-to-riverglades/), [LFCarry new zones](https://lfcarry.com/guides/wow-forever-new-zones) (new 2026-11-05) | Riverglades 36-44 (evidence.json), Rog'mar at 59.6, 45.1, walk-in through Blackrock Pass; no Horde quest givers named, no Badlands or Swamp of Sorrows walk-ins | 2026-11-05 |
| [Blizzard: WoW Forever Hotfixes, November 6, 2026](https://news.blizzard.com/en-us/article/24315281/wow-forever-hotfixes-november-6-2026) (with November 5), [Wowhead summary](https://www.wowhead.com/forever/news/many-class-dungeon-and-quest-fixes-wow-forever-hotfixes-for-november-6th-383794) (new 2026-11-07) | Tanning Rack at Leatherworking 125 (Camp.lua), Zaetar's Spirit after Princess Theradras (Maraudon steps), Unending Torment at 15 for Horde (Ruins of Lordaeron), Lotheluum Starbreeze trains Druids on Zephras Isle (Skyborne route), Riverglades quest-item sharing (no quest names) | 2026-11-07 |
| [Timesaver Riverglades guide](https://timesaver.gg/blog/wow-forever-riverglades-zone-guide) (new 2026-11-07, published that day) | Riverglades 35-45 (Wowhead's database 36-44), Horde hubs Rog'mar and Bolder'ok (ogres in the north, second source after Warcraft Wiki), no Horde quest names | 2026-11-07 |
| [Warcraft Wiki: Riverglades](https://warcraft.wiki.gg/wiki/Riverglades) (new 2026-11-06) | Riverglades 35-45, every walk-in (Badlands north of Twilight's Shroud, Swamp of Sorrows and Redridge through Redridge Pass, Burning Steppes through Blackrock Pass), settlements incl. Bolder'ok (Travel.lua BORDERS, route notes, evidence.json) | 2026-11-06 |
| [Blizzard: Known Issues, updated Nov. 5](https://us.forums.blizzard.com/en/wow/t/known-issues-wow-forever-updated-nov-5/2402363), [Aggrend on lost boats and zeppelins](https://us.forums.blizzard.com/en/wow/t/zeppelins-broken/2401777/15) (new 2026-11-06) | Live-server problems: Vorsha the Lasher (Ashenvale) was disabled for a crash and is struck through (fixed); temporary portals at docks and zeppelin towers while transports got lost in the Maelstrom, proper fix November 5 (temporary, so no travel tip) | 2026-11-06 |
| [eXputer new leveling zones](https://exputer.com/?p=445380) (new 2026-11-06) | Riverglades 35-45, Shen'dralas 40-45 vs 45-53 disagreement (BACKLOG open questions) | 2026-11-06 |
| [wowforeverleveling.com Horde guide](https://wowforeverleveling.com/guides/wow-forever-horde-leveling-guide) (new 2026-11-08, updated November 7) | Horde 1-60 zone order (Wowdee-based, tested only to 30); Riverglades: Rog'mar and Bolder'ok, Krol'dok 40-45, no Horde quest names; Mount Hyjal and Shen'dralas not covered | 2026-11-08 |
| [Mobalytics zone map](https://mobalytics.gg/wow-forever/guides/zone-map-level-ranges) | Zone level ranges (tools/sources/evidence.json) | 2026-11-02 |
| [wow4ever.quest 1-60 guide](https://wow4ever.quest/en/articles/guia-subida-1-60-wow-forever) | Zone level ranges, Horde 10-35 route (evidence.json) | 2026-11-02 |
| [wowf.io Riverglades](https://wowf.io/en/zones/riverglades), [wowclassicforever.info Riverglades](https://wowclassicforever.info/zones/riverglades/) | Riverglades: Rog'mar flight links, Krol'dok Stronghold 40-45 (corrected from 40-55), routes in | 2026-11-05 |

## Classes, specs and gear (Classes/*.lua, Classes/Specs.lua, SecondSpec.lua)

| Source | Feeds | Last checked |
|---|---|---|
| [Mobalytics WoW Forever class and spec guides](https://mobalytics.gg/wow-forever/) | Stat priorities and weights, playstyle tips, Forever changes per spec | 2026-11-05 |
| Icy Veins / Wowhead WoW Forever class guides | Stat priorities, pre-raid gear (RG.SPEC_HAND) | 2026-11-02 |
| [Endgame Tools hotfix article](https://endgametools.com/en/wow-forever/news/wow-forever-beta-hotfix-class-changes), [Playfulls game-data hotfixes](https://playfulls.com/patch-notes/game-data-2026-10-31), [ConquestCapped patch notes](https://conquestcapped.com/guides/wow-forever/wow-forever-patch-notes/) (new 2026-11-02) | Server hotfixes read from the game data (October 23-31: Righteous Fury at 10, Shadow Word: Death backlash 30%, racials); unofficial until Blizzard posts them. Talent changes are not collected | 2026-11-02 |
| [wowtbc.gg WoW Forever loot tables](https://wowtbc.gg/warcraftforever/) | Dungeon drops that changed in Forever | 2026-11-02 |

Waypath+ gives no talent advice on purpose: talent builds are not collected.

## Professions, fishing, camping (Professions/*.lua, Fish.lua, Camp.lua)

| Source | Feeds | Last checked |
|---|---|---|
| [wow-professions.com WoW Forever guides](https://www.wow-professions.com/forever) | 1-300 leveling plans, trainers, materials | 2026-11-02 |
| [wowtbc.gg WoW Forever professions](https://wowtbc.gg/warcraftforever/professions) | Cross-check for plans, Forever-only recipes, camping | 2026-11-02 |
| Warcraft Wiki ([warcraft.wiki.gg](https://warcraft.wiki.gg/)) | Recipe names, trainer names, fishing ranks | 2026-11-02 |
| [wowforever.be fishing](https://wowforever.be/tradeskills/forever/fishing/), [wofwforever.com fishing](https://wofwforever.com/en/guides/wow-forever-fishing-guide/), [wowforeverguides.com fishing](https://wowforeverguides.com/professions/fishing) | Fishing zone skill table (Wowhead's WoW Forever beta table), poles, lures, Extravaganza items, camp objects | 2026-11-02 |
| [Mmonster camping guide](https://mmonster.co/wow-forever/guides/professions/camping), [wow-professions.com camping guide](https://www.wow-professions.com/forever/camping-guide) (new 2026-11-08) | Every camp object, buff, materials and blueprint source (Camp.lua). Both still list the skill-300 blueprints and the Expert Campfire as unknown; Mmonster alone names tools (Runed Truesilver Rod, Arclight Spanner) for some objects, unconfirmed so not used | 2026-11-08 |
| [Warcraft Tavern fishing overview](https://www.warcrafttavern.com/forever/guides/fishing/), [Endgame Tools item pages](https://endgametools.com/en/wow-forever/items/6367) (new 2026-10-26) | Pole and lure bonuses on build 1.60.1.70532 (Classic values: Big Iron +20), Blump pole is Alliance-only | 2026-11-02 |

## Gold (Gold.lua)

| Source | Feeds | Last checked |
|---|---|---|
| WoW Forever gold-making guides (Icy Veins, Wowhead, Warcraft Tavern, zockify) | RG.GOLD tips | 2026-11-02 |
