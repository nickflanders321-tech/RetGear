# Gear guide generator

Builds `Classes/<Class>Gear.lua` for every class: leveling upgrades for every slot it uses
(two-hander or one-handers, off-hand, ranged or wand, head to feet, rings, trinkets), levels
5-60, that a Horde character of that class can actually get in WoW Forever:

- **Quest rewards** from quests open to that class (Horde quest givers), not raid quests.
- **Dungeon boss drops** from 5-player dungeons (no raids, no Stockade).
- **Horde vendors** (no PvP quartermasters) and a few named rare mobs.

Each class's stat weights, weapon model (`2H`, `DW` dual wield, `ranged`, `caster`, `feral`),
weapon skills and armor types come from `Classes/<Class>.lua`, the same table the add-on scores
items with in game, so the list and the tooltips agree. Stats and equip effects (Attack Power,
spell damage by school, crit, hit, mp5) come from the cMaNGOS classic database; whether an item
exists in Forever and where it comes from comes from QuestieDB's merged Forever data. Per slot
the generator keeps the upgrade path (anything 5% better than everything at or below its
level), plus the best quest reward and the best dungeon drop in each 5-level window. Armor and
jewelry that only carry Stamina for that class are skipped.

```sh
git clone --depth 1 https://github.com/cmangos/classic-db.git /tmp/cdb
zcat /tmp/cdb/Full_DB/*.sql.gz > /tmp/classic.sql
sh tools/qdb/export.sh /tmp/qdb
lua5.1 tools/gear/dump.lua /tmp/qdb/src/corrections/Forever/combined /tmp/forever_gear.json
lua5.1 tools/gear/specs_dump.lua . /tmp/specs.json
python3 tools/gear/gen.py /tmp/classic.sql /tmp/forever_gear.json /tmp/qdb . [Class ...] --specs /tmp/specs.json
```

With `--specs` it also writes `Classes/SpecGear.lua`: for every spec in `Classes/Specs.lua` that
isn't the class's leveling spec, the gear to start collecting from level 30 (the 2nd Spec tab),
scored with that spec's weights and weapon model. Tanks (`model = "tank"`) get one-handers and
shields and value Stamina, armor, Defense, dodge, parry and block; healers value +healing, mp5
and Intellect; specs can narrow the class's weapons (daggers for Assassination and Subtlety).

Hand-written entries in each class's `guide` table (tips, Forever-only items, crafts) take
priority over generated ones.
