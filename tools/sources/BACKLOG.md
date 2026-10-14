# Waypath+ improvement backlog

Known gaps, in rough priority order. Every twice-weekly update works on this list even
when no guide changed: it fixes at least one item (more when they're small), moves it to
"Done" with the version, and adds anything new it notices (from guides, from the audit and
cross-check warnings, or from players' bug reports). Keep entries short and concrete.

## To do

1. **Dungeons without route steps:** Excavation Site (26-31), City of Dalaran (28-33),
   Gnomeregan (29-38), Razorfen Downs (37-46), The Temple of Atal'Hakkar (50-56). Add
   where the entrance is, which quests to collect first and what to watch for
   (Routes/Horde.lua `H.steps` and `H.dungeons`).
2. **Zone without route steps:** Riverglades (36-44), a new WoW Forever zone. Add its
   steps once Horde guides cover it.
3. **Professions 225-300 use the Classic route** (Alchemy, Blacksmithing, Enchanting,
   Engineering, First Aid, Leatherworking, Tailoring). Replace with WoW Forever's route as
   soon as wow-professions.com or wowtbc.gg publish it.
4. **Fishing zone skill levels are Classic's** (Fish.lua `RG.FISH_ZONES`, 45 zones), and
   pole and lure bonuses are Classic values. Update from Forever data or guides.
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

- v0.51.0: quest data keeps names, levels and prerequisites for every quest; the tracker
  follows the next unfinished zone; map pins stay aligned after class-only steps.
- v0.50.0: weapon lists read correctly for every class (no staves or fishing poles for
  Paladins); Alliance quests removed from Horde dungeon lists.
