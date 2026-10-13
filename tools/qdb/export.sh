#!/bin/sh
# Fetch QuestieDB and build its merged WoW Forever data: classic data + Forever's
# own quests, NPCs and changes (new starting zones, class quests, new dungeons).
# Usage: sh tools/qdb/export.sh [/tmp/qdb]   -> data in <dir>/src/corrections/Forever/combined
set -e
DIR="${1:-/tmp/qdb}"
if [ -d "$DIR/.git" ]; then git -C "$DIR" pull -q; else git clone -q --depth 1 https://github.com/Questie/QuestieDB.git "$DIR"; fi
cd "$DIR"
LUA=./tools/lua-binary/linux-x64/lua
[ -x "$LUA" ] || LUA=lua5.1
"$LUA" tools/export-forever.lua --include-authored
echo "Merged Forever data: $DIR/src/corrections/Forever/combined"
