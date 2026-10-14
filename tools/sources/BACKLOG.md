# Waypath+ improvement backlog

Known gaps, in rough priority order. Every twice-weekly update works on this list even
when no guide changed: it fixes at least one item (more when they're small), moves it to
"Done" with the version, and adds anything new it notices (from guides, from the audit and
cross-check warnings, or from players' bug reports). Keep entries short and concrete.

## To do

1. **Riverglades (36-44) has no route steps:** QuestieDB's Forever data has only one
   Alliance quest there and no guide lists Horde hubs yet. Known so far: Steamwheedle ship
   from Tanaris to Powderfuse Port, Horde flight point Rog'mar, Krol'dok Stronghold is a
   40-45 dungeon. Add steps as soon as Horde quest data or a guide names the hubs.
2. **Dungeon steps need an in-game check:** Excavation Site, City of Dalaran, Gnomeregan,
   Razorfen Downs and the Temple of Atal'Hakkar got steps in v0.55.0 from Forever beta
   guides (entrances, bosses, quest order). Confirm the Dalaran Horde key chain
   (Prison Break In ... Heart of Disruption) and the Atal'Hakkar statue order in game.
3. **Professions 225-300 use the Classic route** (Alchemy, Blacksmithing, Enchanting,
   Engineering, First Aid, Leatherworking, Tailoring). Replace with WoW Forever's route as
   soon as wow-professions.com or wowtbc.gg publish it.
4. **Fishing zone skill levels are Classic's** (Fish.lua `RG.FISH_ZONES`, 45 zones), and
   pole and lure bonuses are Classic values (every guide checked on 2026-10-14 says Forever's
   zone skills are unconfirmed; the Fishing tab says so). Update when a guide or the live
   game confirms them. New Forever lures/hat ("Secret" Bait, Shiny Silver Coin, Wide-Brimmed
   Fishing Hat) have no published source yet.
5. **Route steps without a map pin:** 64 of 122 hand-written steps have one. Improve the
   matching in tools/waypoints/gen.py, or name the NPC or place in the step text.
6. **Gear guide gaps at level 20:** most classes have no Head piece listed before 20, and
   some no Shoulder (see the audit's "gaps"). Add quest or dungeon pieces where guides
   name them.
7. **Pre-raid gear for 2nd specs:** only Holy Paladin has hand-picked items
   (SecondSpec.lua `RG.SPEC_HAND`). Add named pre-raid items for the other specs as
   Forever guides publish them.
8. **Dungeon drops are Classic-era** for several dungeons until Forever loot tables are
   confirmed (wowtbc.gg loot tables).
9. **14 Horde quests aren't in Objectives.lua** (crosscheck warning), e.g. Proving
   Grounds (7162) and Runes of the Sorcerer-Kings (78148). Find which filter in
   tools/objectives/gen.py drops them.

## Open questions

- None yet. Add guide disagreements here (what each source says, and the date).

## Done

- v0.55.0: route steps for Excavation Site, City of Dalaran, Gnomeregan, Razorfen Downs and
  the Temple of Atal'Hakkar (with entrance pins); fishing tab flags Classic-based zone skills
  and lists WoW Forever's new lures and hat.
- v0.54.0: Fishing tab lists everything fishing can bring up (tools/fishloot).
- v0.51.0: quest data keeps names, levels and prerequisites for every quest; the tracker
  follows the next unfinished zone; map pins stay aligned after class-only steps.
- v0.50.0: weapon lists read correctly for every class (no staves or fishing poles for
  Paladins); Alliance quests removed from Horde dungeon lists.
