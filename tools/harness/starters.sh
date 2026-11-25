#!/bin/sh
# Build tools/harness/.cache/starters.lua: where quests that start from an object or an item begin (starters.py),
# for the simulated world. Downloads QuestieDB the first time (a few minutes), as tools/watch/regenerate.sh does.
# Run from the repo root:  sh tools/harness/starters.sh [QuestieDB folder]
set -e
C=tools/harness/.cache
Q="${1:-$C/qdb}"
mkdir -p "$C"
[ -d "$Q/.git" ] || sh tools/qdb/export.sh "$Q"
[ -d "$Q/src/corrections/Forever/combined" ] || (cd "$Q" && { L=./tools/lua-binary/linux-x64/lua; [ -x "$L" ] || L=lua5.1; "$L" tools/export-forever.lua --include-authored; })
lua5.1 tools/objectives/dump.lua "$Q/src/corrections/Forever/combined" "$C/forever.json"
python3 tools/harness/starters.py "$Q" "$C/forever.json" "$C/starters.lua"
