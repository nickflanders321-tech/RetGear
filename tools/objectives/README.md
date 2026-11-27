# Quest objective generator

Builds `Objectives.lua` from QuestieDB's WoW Forever data: for every quest an Undead paladin
can take, who gives it (and its prerequisites), where to turn it in, and where each objective
is: mobs to kill, mobs/objects that drop quest items, objects to use.

```sh
git clone --depth 1 https://github.com/Questie/QuestieDB.git /tmp/qdb
lua5.1 dump.lua /tmp/qdb/data/Forever /tmp/forever.json
python3 gen.py /tmp/qdb /tmp/forever.json ../..
```

Places (kind `e`): an event or somewhere to reach that the objectives above can't show. They come from
QuestieDB's `extraObjectives` (what to do first, only for a quest with no other spot) and `triggerEnd`
(where the quest's event ends), in that order; the add-on shows the next one once you've been to the one
before. `places.json` holds hand-checked places for quests QuestieDB has none for, each with the page that
confirms it (Wowhead or warcraft.wiki.gg); an entry there replaces QuestieDB's places for that quest.
