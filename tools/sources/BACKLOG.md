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
   Since v1.9.0 the travel tips route into Riverglades (Steamwheedle ship, walk-ins from Redridge and the
   Burning Steppes, Rog'mar flights); since v1.12.0 also from the Badlands (north of Twilight's Shroud) and the
   Swamp of Sorrows (Redridge Pass), confirmed by Warcraft Wiki on top of Mmonster. Rog'mar's wind rider master
   is Grakna (59.6, 45.2; NPC 255993 in QuestieDB's Forever data).
   2026-11-05 (launch day +1): QuestieDB's Forever data unchanged since November 2, so still no Horde quests;
   Overgear and LFCarry (launch-updated) name only Rog'mar (59.6, 45.1) and the Redridge / Blackrock Pass walk-in.
   2026-11-06: QuestieDB's Forever data still unchanged (tree 010e05f); Warcraft Wiki lists Bolder'ok as a second
   Horde settlement (unconfirmed elsewhere, so not in the notes yet). Still no Horde quest names anywhere.
   2026-11-07: QuestieDB's Forever data still unchanged (tree f59c42a); Timesaver's new Riverglades guide confirms
   Bolder'ok (ogres, north), so the Horde route note names it since v1.19.0. Blizzard's November 6 hotfix fixes
   Riverglades quest items and Krek the Noxious, but still no Horde quest names published.
   2026-11-08: QuestieDB's Forever data unchanged since the November 8 01:25 UTC update (tree 394e044): still no
   Riverglades or Mount Hyjal quests (coverage.py: no steps), Shen'dralas still only 4 Horde quests. wowforeverleveling.com
   (updated November 7) names the same two Horde hubs and no quests.
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
   2026-11-07: Warcraft Wiki (patch 1.60.1, Fishing 50, level 20), ForeverChanges and QuestieDB's Forever item data
   (no drop, vendor or quest) still give no source for the Ravaged Fishing Pole (285094) or the Wide-Brimmed
   Fishing Hat (259846, level 48).
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
9. **WoW Forever's new crafting recipes are not in the gear guide** (2026-11-07). About 900 new
   recipe items (ids above 250000: "Pattern: Shining Circlet", "Pattern: Pristine Gown", the SAF-T and
   EZ-Thro schematics...), about 630 of them make green-or-better gear and about 380 have a known
   source in QuestieDB. tools/gear/gen.py only links recipes to what they make through cMaNGOS
   spell data, which doesn't have them, and LibItemDB's Recipe.lua has no product or skill. Matching
   by name ("Pattern: X" makes "X") would work for most, but the skill each one needs is unknown.
   **Don't add them until a source gives the real data** (the recipe's spell, the item it makes and the
   required skill), for example a Wowhead or ForeverChanges recipe page, a wago.tools SkillLineAbility /
   Spell DB2 export for the Forever build, or a LibItemDB release that adds it. Then feed CRAFT in gen.py.

10. **Camp blueprints without a source** (Camp.lua "Blueprint source not found yet"): the Expert Campfire and every
   skill-300 object except the Trapper's Workbench. QuestieDB's Forever item data has the blueprint items for the
   Anarchist's Workbench (273117) and Plague Doctor's Laboratory (273118) but no drop yet; Mmonster and
   wow-professions.com (2026-11-08) list them all as unknown. Fill in as soon as QuestieDB or a guide names a drop.

## Open questions

- Guides disagree on Thousand Needles (Forever Era 25-35, Decarebia 20-30, Endgame Tools 23-40) and Arathi Highlands (all say 30-40, but Forever's own quest data starts at 33). Our windows: Horde TN 26-35, Arathi 33-40 (2026-10-16).
- Blizzard's October 8 beta notes raise the Desolace Valley of Bones Gelkis and Magram quests to level 35 (was 30); QuestieDB's Forever data still says 30 (2026-10-19). The Desolace route note mentions it; follow the quest data until it changes.
- Searing Gorge (guides 43-53, ours 48-54) and Horde Azshara (guides 45-55, ours 50-58): Forever's own quest data backs our windows (Searing Gorge quests: a quarter below 48, median 50; Azshara median 57), so they stay (2026-10-19).
- Shen'dralas: Leprestore 40-50 (2026-10-14), Skycoach 40-45 (2026-09-30, "40+, not confirmed"), Eternadex's route window 41-43 (2026-10-18), Mmonster no range yet (2026-10-21); ours is 38-43. Guides agree it starts around 40, so it may move up 2 levels; wait for launch quest data before moving it (2026-11-02).
- Ruins of Lordaeron: Blizzard's November 2 launch notes say every dungeon quest needs level 15; QuestieDB's Forever data still has 16 for The New Plague, Crest of Lordaeron and Unending Torment (2026-11-05). The route note says 15, the route entry stays at 16; drop the entry to 15 (with MOVED_STEPS) once the quest data agrees. 2026-11-07: Blizzard's November 6 hotfix had to lower Unending Torment (Horde) from 16 to 15 on the live realms, so the launch notes' "15" wasn't live for every quest; QuestieDB still says 16 for all three. The Paladin step says 15 for Unending Torment; the entry stays at 16.
- Shen'dralas, 2026-11-06: eXputer (2026-10-28) reports guides split between 40-45 and 45-53. Ours stays 38-43
  until launch quest data is in QuestieDB.
- Add guide disagreements here (what each source says, and the date).

## Done

- v1.22.0: Trapper's Workbench blueprint source from QuestieDB's Forever data (Houndmaster Loksey, Scarlet
  Monastery Library), in the Camping tab (item 10, partial; the guides still list it
  as unknown).

- v1.19.0: Blizzard's November 5-6 hotfixes applied: Tanning Rack at Leatherworking 125 (was 140), Zaetar's Spirit and
  Seed of Life after Princess Theradras (Maraudon, both factions), Unending Torment at 15, Lotheluum Starbreeze as
  the Zephras Isle Druid trainer; Bolder'ok named in the Horde Riverglades note (item 1, partial).

- v1.12.0: travel tips walk into Riverglades from the Badlands and the Swamp of Sorrows too (Warcraft Wiki +
  Mmonster); route notes for both factions name every way in and Rog'mar's wind rider master Grakna (item 1, partial).

- v1.10.0: the October 23-31 server hotfixes on the 2nd Spec tab (Righteous Fury at 10, Shadow Word: Death
  30% backlash) are confirmed by Blizzard's November 2 launch notes (open question closed); launch-build changes
  added (Bear Form 115% and Defensive Stance 80% threat, Totemic Call, Lava Burst and Frost Blast removed, shared
  trap cooldown, Mutilate moved to 31 points, Riptide, Stormstrike, Ice Lance); Ruins of Lordaeron quests at 15;
  training-cost gold tip. v1.9.3: the watcher reads the live `wowf` product (it was stuck on the beta's build).

- v1.9.0: travel tips know the new zones (Riverglades on the Eastern Kingdoms with the Steamwheedle
  ship and walk-ins, Shen'dralas from Desolace, Mount Hyjal from Winterspring with the Tainted
  Foothills flight path, the Zephras Isle skyship, the Valanaar inn); before, Riverglades was treated as
  Kalimdor and travel only sent you to Tanaris. 2nd Spec notes from the October 30-31 server hotfixes.
  Six new sources (SOURCES.md), evidence.json gains Mount Hyjal and second opinions on Shen'dralas.

- v1.7.0 (launch prep): new zones without quest data show "steps coming" (not "Done") and the
  tracker stays with one you're standing in; card packs cost coins from the launch on (were
  free forever); launch time fixed to 3 p.m. PST; the leaderboard channel waits for the default
  channels and spreads check-ins; CurseForge uploads go out as Release and always include the
  newest WoW Forever game version; CURSEFORGE.md rewritten to lead with leveling.

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
