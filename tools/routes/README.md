# Route generator

Builds `Routes/Generated.lua` from QuestieDB's merged WoW Forever data (see `tools/qdb`):

- **Starting-zone steps for every Horde race** (Orc and Troll: Valley of Trials, Durotar, The
  Barrens; Tauren: Camp Narache, Mulgore, The Barrens; Undead: Deathknell, Brill, Silverpine;
  Skyborne: Zephras Isle, Mulgore, The Barrens). The generator walks each zone like a player:
  it goes to the stop with the most quests you can take at your level, takes everything there
  (and the follow-ups handed out on the spot), and moves on, picking up any quests that fall
  behind your level first. Each step lists its quest IDs, so it ticks itself off when they're
  all turned in, and has a waypoint for the stop.
- **Whole quest chains.** Every quest in a step must have what it needs first on the way. Suppose a quest's earlier
  quest isn't on that race's route yet. For example, an Undead skips the Barrens at 12-20, so Serena Bloodfeather in
  the shared Barrens leg needs Harpy Lieutenants, which only the other races met. Then the earlier quest (and its own
  earlier quests) joins the leg. If the earlier quest can't be done on a questing route at all (a dungeon or raid
  quest, or one the data doesn't have), the quest is left out instead. The run lists every quest it left out, and
  why, as `left out: ...` lines. A quest whose earlier quest the data marks for other races only is kept and listed as
  `check the data: ...`: those race marks have been wrong before (see BACKLOG.md, Open questions).
- **Dungeon quests** for every dungeon on the route: quests filed under the dungeon, or whose
  objectives are mostly inside it, with the giver and a waypoint. Race- and class-only quests
  keep their letters so each character only sees its own.

```sh
sh tools/qdb/export.sh /tmp/qdb
lua5.1 tools/objectives/dump.lua /tmp/qdb/src/corrections/Forever/combined /tmp/forever.json
python3 tools/routes/gen.py /tmp/qdb /tmp/forever.json .
lua5.1 tools/audit/audit.lua        # every race/class still passes?
```

Legs and hub anchors (an NPC who stands at each town) are the `LEGS` and `ANCHORS` tables at
the top of `gen.py`. The route entries themselves (zone order, notes, travel tips) are in
`Races/<Race>.lua`.
