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
   Add steps as soon as Horde quest data or a guide names the hubs.
2. **Dungeon steps need an in-game check:** Excavation Site, City of Dalaran, Gnomeregan,
   Razorfen Downs and the Temple of Atal'Hakkar got steps in v0.55.0 from Forever beta
   guides (entrances, bosses, quest order). Confirm the Dalaran Horde key chain
   (Prison Break In ... Heart of Disruption) and the Atal'Hakkar statue order in game.
3. **Professions 225-300 use the Classic route** (Alchemy, Blacksmithing, Enchanting,
   Engineering, First Aid, Leatherworking, Tailoring). Replace with WoW Forever's route as
   soon as wow-professions.com or wowtbc.gg publish it (2026-10-19: wow-professions.com still
   calls its 225-300 untested and adapted from Classic; the beta stops at 225).
4. **Fishing pole and lure bonuses are Classic values** (zone skills now follow Wowhead's
   WoW Forever beta table, v1.4.0; Blizzard hasn't confirmed either). Beta tooltips reported by
   wofwforever.com show bigger pole bonuses (Strong 45, Blump 27, Big Iron 42) and a new
   Ravaged Fishing Pole (+31, Fishing 50, level 20, source unknown): update when confirmed. New Forever lures/hat ("Secret" Bait, Shiny Silver Coin, Wide-Brimmed
   Fishing Hat) have no published source yet.
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
- Add guide disagreements here (what each source says, and the date).

## Done

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
