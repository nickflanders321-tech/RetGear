# Gear guide generator

Builds `GearData.lua`: Ret paladin upgrades for every slot (two-hander, head to feet, rings,
trinkets), levels 8-60, that an Undead paladin can actually get in WoW Forever:

- **Quest rewards** from quests open to Undead paladins (Horde quest givers), not raid quests.
- **Dungeon boss drops** from 5-player dungeons (no raids, no Stockade).
- **Horde vendors** (no PvP quartermasters) and a few named rare mobs.

Stats and equip effects (Attack Power, crit, hit) come from the cMaNGOS classic database; whether
an item exists in Forever and where it comes from comes from QuestieDB's Forever data. Each item
is scored with RetGear's default Ret weights. Per slot the generator keeps the upgrade path
(anything 5% better than everything at or below its level), plus the best quest reward and the
best dungeon drop in each 5-level window. Caster pieces without melee stats are skipped.

```sh
git clone --depth 1 https://github.com/cmangos/classic-db.git /tmp/cdb
zcat /tmp/cdb/Full_DB/*.sql.gz > /tmp/classic.sql
git clone --depth 1 https://github.com/Questie/QuestieDB.git /tmp/qdb
lua5.1 dump.lua /tmp/qdb/data/Forever /tmp/forever_gear.json
python3 gen.py /tmp/classic.sql /tmp/forever_gear.json /tmp/qdb ../../GearData.lua
```

Hand-written entries in `Data.lua` (`RG.GUIDE`, e.g. your Blacksmithing crafts) take priority.
