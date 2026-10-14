# Fishing loot generator

Builds `FishLoot.lua`, the data behind the Fishing tab's "Everything fishing can bring up":

- `zones`: what a cast in each zone can bring up, with the chance per catch (cMaNGOS classic
  fishing loot, references and groups resolved).
- `pools`: schools, wreckage, oil spills, Elemental Water patches and Forever's own fishing
  locations, with what they give and where they are (spawn positions from QuestieDB's merged
  WoW Forever data, nearest cluster per zone).
- `contents`: what the chests, crates, trunks, clams, bloated fish and bottles hold.
- `info`: name, kind (fish, material, container, gear, junk, misc) and quality for each item.

Chances are the classic tables' values; Forever has not published its own, so the tab says so.
Zone fishing skills come from `RG.FISH_ZONES` in `Fish.lua`.

```sh
C=/tmp/qdb/src/corrections/Forever/combined
lua5.1 tools/fishloot/dump.lua $C /tmp/fl_obj.tsv /tmp/fl_items.tsv
python3 tools/fishloot/gen.py /tmp/classic.sql /tmp/qdb /tmp/fl_obj.tsv /tmp/fl_items.tsv .
```
