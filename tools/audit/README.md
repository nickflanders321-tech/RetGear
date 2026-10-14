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
