# How to update Waypath+

> Routine watching (new game build, new Forever quest data, new bug reports) and data regeneration
> now run free in GitHub Actions (.github/workflows/watch.yml, tools/watch/). Claude only handles
> issues labeled `needs-claude`; step 4 below is `sh tools/watch/regenerate.sh`.

The full update procedure. Both scheduled tasks follow it: the twice-weekly guide update,
and the hourly patch watcher when it sees a new game build, new WoW Forever quest data or a
new bug report. Standing goal: **every update makes Waypath+ more accurate and more complete
by compiling ALL available leveling and WoW Forever guides and data**, and keeps it working
on the newest game build.

Waypath+ deliberately gives **no talent advice** (the Talents tab was removed in v0.49.0):
never add talent builds, talent orders, "goal" talents or rotations, and don't maintain the
old talents/rotation/build/goal fields in Classes/*.lua or Classes/Specs.lua.

## Where things live

Classes/<Class>.lua (leveling stat weights, weapon model and proficiencies, hand-written gear
tips), Classes/<Class>Gear.lua (GENERATED leveling gear), Classes/Specs.lua (every spec of
every class for the 2nd Spec tab: role, talent tab, stat weights, weapon model, stat priority,
tips, Forever changes, source URL; RG.SPECS_UPDATED), Classes/SpecGear.lua (GENERATED 2nd-spec
gear, levels 30-60), SecondSpec.lua (RG.SPEC_HAND hand-written 2nd-spec gear), SourceInfo.lua,
Races/<Race>.lua (route entries, travel tips, R.prefer), Routes/Horde.lua (H.route, H.steps,
H.travel, H.dungeons), Routes/Generated.lua (GENERATED starting zones and dungeon quests),
Professions/<Name>.lua (P.source, P.train, P.plan 1-300 steps {from, to, craft, n, mats} /
{gather, also} / {skin, where} / {train}, P.mats, P.supplies), Professions/Generated.lua
(GENERATED recipes, material sources, gathering and skinning spots, fishing pools, trainer
pins), ProfGuide.lua, NodeData.lua (GENERATED ore and herb spawns), Waypoints.lua (GENERATED
pins), Objectives.lua (GENERATED quest data for every Horde quest), Compat.lua (the game
functions Waypath+ needs, checked on every new game build). Profile.lua merges them at load.
Read README.md, tools/*/README.md, tools/sources/SOURCES.md and tools/sources/BACKLOG.md first.

## 1. Compatibility with the newest game build (always first when the build changed)

- Find what changed: Blizzard's patch notes and WoW Forever forum posts for that build,
  addon-author notes (for example github.com/Thunderz96/forever-addon-kit, which keeps an
  API baseline), and the game's FrameXML/API docs if available. Look for renamed or removed
  functions, events and frames, new "secret value" restrictions, and actions add-ons may no
  longer take (they cause the "blocked from an action only available to the Blizzard UI"
  pop-up: never hide or move protected Blizzard frames like the Minimap).
- Update Compat.lua's NEEDS list and every call site of a changed function, keeping the
  old function as a fallback (`C_New.Func or OldFunc`) so older builds still work.
- Make sure the .toc `## Interface:` lines include the new build's interface number
  (1.60.4 -> 16004, 1.61.0 -> 16100).
- Ship compatibility fixes as a patch release right away (step 7) before anything else.

## 2. Compile the guides

Work through tools/sources/SOURCES.md: for every listed source, check what changed since its
"Last checked" date. Then actively look for NEW sources with several web searches every time
(for example "WoW Forever leveling guide Horde", "WoW Forever patch notes", "WoW Forever <zone>
quests" for the zones on the route, "WoW Forever <class> guide" for all nine classes, "WoW
Forever <profession> leveling guide" for all twelve professions, "WoW Forever new dungeon",
"WoW Forever fishing skill zones", "WoW Forever gold farming"); use "extended" search mode for
recent or hard-to-find facts. Add every useful new guide to SOURCES.md with what it feeds.
When sources disagree prefer WoW Forever's own data (QuestieDB) > official Blizzard posts >
the newest dated guide > older guides; put disagreements you can't settle under "Open
questions" in BACKLOG.md instead of guessing. Update the "Last checked" dates. Apply:

- **Quest guide:** routes and zone level ranges, quests added/removed/moved, new zones and
  dungeons and their Horde quests, flight paths and boats, starting-zone changes, class
  quests -> Routes/Horde.lua (route entries with o = position; dungeon quest rows
  { "exact quest name", "giver", "where" }), Races/<Race>.lua, Classes/Paladin.lua, Travel.lua
  (FP, INN_TOWN, BORDERS, RIDES, DESTINATION). Keep zone names consistent between route
  entries, step keys ("Zone|from"), RG.MAIL_QUESTS and RG.CAMP_PLAN; add MOVED_STEPS in
  Core.lua when a route entry's starting level changes. Lines for one class start with
  "Paladins: " (etc.), ore/herb tips with "Miners: " / "Herbalists: ". Name the NPC or place in
  a step's text so it gets a map pin.
- **Gear guide:** hand-written entries in Classes/<Class>.lua ({id, slot, lvl, approx?, how,
  src, zone, bs?, ah?, note?}; quest entries use the exact quest name as src, optionally
  "(Giver)"); adjust class weights when guides change a stat priority.
- **Gold:** RG.GOLD in Gold.lua (update RG.GOLD.updated/note/sources).
- **Specs (2nd Spec tab):** stat priorities, playstyle tips, Forever changes, dual spec
  level/cost, named pre-raid items (not talent builds) -> Classes/Specs.lua (bump
  RG.SPECS_UPDATED), RG.SPEC_HAND and RG.DUAL_SPEC_LEVEL in SecondSpec.lua.
- **Bank-alt quests:** RG.MAIL_QUESTS in Mail.lua.
- **Professions:** Forever 1-300 plans, trainers, Forever-only recipes, camping ->
  Professions/<Name>.lua (keep `craft` names exactly as in game, and `craft` and `mats` on the
  SAME line as "N Item, N Item each"), Camp.lua, Fish.lua (RG.FISH_ZONES, RG.FISH_ROUTE,
  RG.FISH_GEAR, RG.FISH_COOK, RG.FISH_DERBY).

Only use item and quest IDs you verified (Wowhead/warcraft.wiki.gg, or present in QuestieDB's
Forever data), and keep table shapes identical.

## 3. Work the backlog

Every run fixes at least one item from BACKLOG.md "To do" (more if small), moves it to "Done"
with the version, and adds anything new noticed. Check player reports with `gh api "repos/nickflanders321-tech/RetGear/issues?state=open"` (GraphQL commands like `gh issue list` are blocked)
and treat them as top priority.

## 4. Regenerate everything from QuestieDB's merged Forever data

`sh tools/qdb/export.sh /tmp/qdb` (QuestieDB ships tools/lua-binary/linux-x64/lua),
C=/tmp/qdb/src/corrections/Forever/combined, build Lua 5.1 (github.com/lua/lua tag v5.1) if no
lua5.1 is available, then in this order:

```
lua5.1 tools/objectives/dump.lua $C /tmp/forever.json && python3 tools/objectives/gen.py /tmp/qdb /tmp/forever.json .
python3 tools/routes/gen.py /tmp/qdb /tmp/forever.json .
lua5.1 tools/nodes/dump.lua $C/foreverObjectDB.lua /tmp/veins.tsv && python3 tools/nodes/gen.py /tmp/qdb /tmp/veins.tsv NodeData.lua
GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 https://github.com/cmangos/classic-db.git /tmp/cdb && zcat /tmp/cdb/Full_DB/*.sql.gz > /tmp/classic.sql
lua5.1 tools/gear/dump.lua $C /tmp/forever_gear.json && lua5.1 tools/gear/specs_dump.lua . /tmp/specs.json
python3 tools/gear/gen.py /tmp/classic.sql /tmp/forever_gear.json /tmp/qdb . --specs /tmp/specs.json
lua5.1 tools/waypoints/dump.lua $C/foreverNpcDB.lua /tmp/npcs.tsv && python3 tools/waypoints/gen.py /tmp/qdb /tmp/npcs.tsv .
cp /tmp/veins.tsv /tmp/objects.tsv && lua5.1 tools/profs/items_dump.lua $C /tmp/items.tsv
python3 tools/profs/gen.py /tmp/classic.sql /tmp/forever_gear.json /tmp/qdb /tmp/npcs.tsv /tmp/objects.tsv . /tmp/items.tsv
lua5.1 tools/fishloot/dump.lua $C /tmp/fl_obj.tsv /tmp/fl_items.tsv && python3 tools/fishloot/gen.py /tmp/classic.sql /tmp/qdb /tmp/fl_obj.tsv /tmp/fl_items.tsv .
```

Fix wrong output with hand-written entries or generator filters, never by editing generated
files. Changes to the generated files count as meaningful changes.

## 5. Check everything (all must pass)

- `lua5.1 tools/audit/audit.lua` (every Horde race/class, every profession, every 2nd spec);
- `python3 tools/audit/crosscheck.py . /tmp/forever.json /tmp/forever_gear.json lua5.1`
  (generators read the Lua data exactly as the add-on does; hand-written quests, givers and
  items exist in WoW Forever, are Horde-friendly and usable). Fix its warnings where you can,
  or add them to BACKLOG.md;
- syntax-check every .lua file with Lua 5.1 loadfile; every file in Waypath.toc and
  Waypath_Forever.toc exists (and new files are listed in both);
- watch for the Lua pitfall `local a, b = F and F()` (only one value survives; write
  `if F then a, b = F() end`).

## 6. Nothing to ship?

If nothing meaningful changed and no backlog item was finished, stop without committing.

## 7. Release

Bump VERSION (patch bump for compatibility-only fixes, minor bump otherwise), add a short
CHANGELOG.md entry written for players (shown in game and on CurseForge), commit as
"Claude" <noreply@anthropic.com> with a message ending in
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, `git pull --rebase`, push to main.
The release workflow builds the zip, the GitHub release and the CurseForge upload.

## 8. Report

A short summary for the owner: the new version, what got more accurate, complete or fixed,
new sources found, backlog progress and what's next, or plainly that nothing changed.


## Route windows and guide comparison (added v0.67)

`tools/sources/evidence.json` holds each guide's published level range per zone (with source and date).
Every update: refresh it from the sources in SOURCES.md, then run `python3 tools/sources/compare.py`.
It prints our start/end level for every Horde and Alliance zone next to the median of the guides and
marks any that are 5+ levels apart. A guide range is a zone's whole range; ours is the window to come
and quest, so a narrower window is normal. Move a window only when most guides agree (change the
route entry in Routes/Horde.lua or Routes/Alliance.lua AND the zone's tuple in tools/routes/gen.py
HORDE_ZONES / ALLIANCE_ZONES, then run tools/watch/regenerate.sh). Write real disagreements in
BACKLOG.md under "Open questions".
