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
