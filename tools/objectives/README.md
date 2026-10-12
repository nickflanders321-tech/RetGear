# Quest objective generator

Builds `Objectives.lua` from QuestieDB's WoW Forever data: for every quest an Undead paladin
can take, who gives it (and its prerequisites), where to turn it in, and where each objective
is: mobs to kill, mobs/objects that drop quest items, objects to use.

```sh
git clone --depth 1 https://github.com/Questie/QuestieDB.git /tmp/qdb
lua5.1 dump.lua /tmp/qdb/data/Forever /tmp/forever.json
python3 gen.py /tmp/qdb /tmp/forever.json ../..
```
