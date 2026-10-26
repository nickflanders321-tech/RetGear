# Waypath+ improvement backlog

Known gaps, in rough priority order. Every twice-weekly update works on this list even
when no guide changed: it fixes at least one item (more when they're small), moves it to
"Done" with the version, and adds anything new it notices (from guides, from the audit and
cross-check warnings, or from players' bug reports). Keep entries short and concrete.

## To do

1. **Riverglades (36-44) has no route steps:** QuestieDB's Forever data has only one
   Alliance quest there and no guide lists Horde hubs yet. Known so far: Steamwheedle ship
   from Tanaris to Powderfuse Port (or the new fork off the Redridge road), Horde flight point
   Rog'mar (links to Kargath, Flame Crest, Hammerfall, Stonard), Krol'dok Stronghold is a
   40-45 dungeon. Still no Horde hubs or quests anywhere on 2026-10-19 (the beta stops at 30).
   Add steps as soon as Horde quest data or a guide names the hubs. (Since 2026-10-23 the generator
   builds Riverglades, Mount Hyjal and Shen'dralas steps by itself as soon as their quests are in
   QuestieDB's Forever data, and adds any other unlisted zone with 12+ quests: check the result and
   write travel notes once launch data is in.)
2. **Dungeon steps need an in-game check:** Excavation Site, City of Dalaran, Gnomeregan,
   Razorfen Downs and the Temple of Atal'Hakkar got steps in v0.55.0 from Forever beta
   guides (entrances, bosses, quest order). Confirm the Dalaran Horde key chain
   (Prison Break In ... Heart of Disruption) and the Atal'Hakkar statue order in game.
3. **Professions 225-300 use the Classic route** (Alchemy, Blacksmithing, Enchanting,
   Engineering, First Aid, Leatherworking, Tailoring). Replace with WoW Forever's route as
   soon as wow-professions.com or wowtbc.gg publish it (2026-10-19: wow-professions.com still
   calls its 225-300 untested and adapted from Classic; the beta stops at 225).
4. **Fishing: a few WoW Forever items still lack a source.** Pole and lure bonuses are
   confirmed as the Classic values on build 1.60.1.70532 (Endgame Tools: Big Iron +20; Warcraft
   Tavern's list), so the bigger beta numbers wofwforever.com reported are dropped (2026-10-26).
   The Ravaged Fishing Pole (+15, Fishing 50, level 20; foreverchanges.pro) is in the list since
   v1.6.0 but where it drops isn't published. Same for the new lures and the Wide-Brimmed Fishing
   Hat. Fill in the "how" texts in Fish.lua RG.FISH_GEAR when a source names them.
5. **Route steps without a map pin:** 46 of 82 hand-written steps have one (v1.4.0). Most
   of the rest are steps inside a dungeon, where a pin wouldn't help; still open: Old Fire Eye
   (Paladin Wolf's Bane finale, not in the Forever NPC data) and Olric Frostvale.
6. **Gear guide gaps at level 20:** most classes have no Head piece listed before 20, and
   some no Shoulder (see the audit's "gaps"). Add quest or dungeon pieces where guides
   name them.
7. **Pre-raid gear for 2nd specs:** only Holy Paladin has hand-picked items
   (SecondSpec.lua `RG.SPEC_HAND`). Add named pre-raid items for the other specs as
   Forever guides publish them.
8. **Dungeon drops are Classic-era** for several dungeons until Forever loot tables are
   confirmed (wowtbc.gg loot tables).

## Open questions

- Guides disagree on Thousand Needles (Forever Era 25-35, Decarebia 20-30, Endgame Tools 23-40) and Arathi Highlands (all say 30-40, but Forever's own quest data starts at 33). Our windows: Horde TN 26-35, Arathi 33-40 (2026-10-16).
- Blizzard's October 8 beta notes raise the Desolace Valley of Bones Gelkis and Magram quests to level 35 (was 30); QuestieDB's Forever data still says 30 (2026-10-19). The Desolace route note mentions it; follow the quest data until it changes.
- Searing Gorge (guides 43-53, ours 48-54) and Horde Azshara (guides 45-55, ours 50-58): Forever's own quest data backs our windows (Searing Gorge quests: a quarter below 48, median 50; Azshara median 57), so they stay (2026-10-19).
- Shen'dralas: Leprestore's 1-60 guide puts it at 40-50 (one coarse bucket, 2026-10-14); ours is 38-43. Wait for launch quest data or more guides before moving it (2026-10-26).
- Add guide disagreements here (what each source says, and the date).

## Done

- v1.6.0: Fishing tab: the Blump Family Fishing Pole is marked as an Alliance quest reward for
  the Horde (it pointed Horde players at a quest they can't take), the new Ravaged Fishing Pole
  is listed, and the pole/lure bonuses were checked against the launch build (Classic values
  hold). New sources: ForeverChanges, Leprestore, Warcraft Tavern fishing, Endgame Tools items.

- 2026-10-23 (launch prep): new-zone generation (Riverglades, Mount Hyjal, Shen'dralas, plus any
  unlisted zone, RG.GEN_AUTO), Alliance Azshara moved to 54-60 from the quest data, route coverage
  report in CI (tools/audit/coverage.py), the watcher accepts any product name for the live build.

- v1.4.0: the last 4 "Horde quests not in Objectives.lua" were Alliance quests (only Alliance
  NPCs give them); the cross-check now skips them like the generator, so the list is clean.
  Paladin class steps got map pins (Bandarion Keep, the Frightened Paladin, and the SFK,
  Blackfathom and Deadmines entrances for Wolf's Bane); pins no longer shift after a step was
  removed. Fishing zones: Thousand Needles, Zephras Isle, Alcaz Island, Jaguero Isle and the
  fishable dungeons added from Wowhead's Forever table. Three giver-name warnings fixed.

- v0.55.0: route steps for Excavation Site, City of Dalaran, Gnomeregan, Razorfen Downs and
  the Temple of Atal'Hakkar (with entrance pins); fishing tab flags Classic-based zone skills
  and lists WoW Forever's new lures and hat.
- v0.54.0: Fishing tab lists everything fishing can bring up (tools/fishloot).
- v0.51.0: quest data keeps names, levels and prerequisites for every quest; the tracker
  follows the next unfinished zone; map pins stay aligned after class-only steps.
- v0.50.0: weapon lists read correctly for every class (no staves or fishing poles for
  Paladins); Alliance quests removed from Horde dungeon lists.
