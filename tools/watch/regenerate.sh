#!/bin/sh
# Rebuild every generated data file from QuestieDB's merged WoW Forever data and the
# cMaNGOS item database, then run both checks. Used by the GitHub Actions watcher
# (.github/workflows/watch.yml) and by the Claude updates (tools/sources/UPDATE.md step 4).
# Usage: sh tools/watch/regenerate.sh   (from the repo root; needs lua5.1, python3, git)
set -e
export PYTHONHASHSEED=0   # same output every run for the same data
T=${TMPDIR:-/tmp}
LUA=${LUA:-lua5.1}
sh tools/qdb/export.sh "$T/qdb"
C="$T/qdb/src/corrections/Forever/combined"
if [ ! -s "$T/classic.sql" ]; then
  rm -rf "$T/cdb"
  GIT_LFS_SKIP_SMUDGE=1 git clone -q --depth 1 https://github.com/cmangos/classic-db.git "$T/cdb"
  zcat "$T"/cdb/Full_DB/*.sql.gz > "$T/classic.sql"
fi
$LUA tools/objectives/dump.lua "$C" "$T/forever.json"
python3 tools/objectives/gen.py "$T/qdb" "$T/forever.json" . --sql "$T/classic.sql"
python3 tools/routes/gen.py "$T/qdb" "$T/forever.json" .
$LUA tools/nodes/dump.lua "$C/foreverObjectDB.lua" "$T/veins.tsv"
python3 tools/nodes/gen.py "$T/qdb" "$T/veins.tsv" NodeData.lua
$LUA tools/gear/dump.lua "$C" "$T/forever_gear.json"
# WoW Forever's own item stats (LibItemDB, MIT: the data/itemdb branch, kept fresh by .github/workflows/fetch-itemdb.yml)
if [ ! -d "$T/itemdb/Forever" ]; then
  rm -rf "$T/itemdb"
  git clone -q --depth 1 -b data/itemdb "https://github.com/${GITHUB_REPOSITORY:-nickflanders321-tech/RetGear}.git" "$T/itemdb" || true
fi
IDB=""; [ -d "$T/itemdb/Forever" ] && IDB="--itemdb $T/itemdb"
$LUA tools/gear/specs_dump.lua . "$T/specs.json"
python3 tools/gear/gen.py "$T/classic.sql" "$T/forever_gear.json" "$T/qdb" . --specs "$T/specs.json" $IDB
$LUA tools/waypoints/dump.lua "$C/foreverNpcDB.lua" "$T/npcs.tsv"
python3 tools/waypoints/gen.py "$T/qdb" "$T/npcs.tsv" .
cp "$T/veins.tsv" "$T/objects.tsv"
$LUA tools/profs/items_dump.lua "$C" "$T/items.tsv"
python3 tools/profs/gen.py "$T/classic.sql" "$T/forever_gear.json" "$T/qdb" "$T/npcs.tsv" "$T/objects.tsv" . "$T/items.tsv"
$LUA tools/fishloot/dump.lua "$C" "$T/fl_obj.tsv" "$T/fl_items.tsv"
python3 tools/fishloot/gen.py "$T/classic.sql" "$T/qdb" "$T/fl_obj.tsv" "$T/fl_items.tsv" .
python3 tools/flights/gen.py "$T/classic.sql" "$T/qdb" "$T/npcs.tsv" .
python3 tools/arcade/gen.py "$T/classic.sql" "$T/qdb" .
python3 tools/arcade/gear.py "$T/classic.sql" .
# players' /wp share reports (GitHub issues labelled "quests"): quests the published data doesn't have yet
python3 tools/community/import.py "${GITHUB_REPOSITORY:-nickflanders321-tech/RetGear}" Objectives.lua || true
# quest tags and notes from Polestar's forever-db (CC BY 4.0 layer); a failed download keeps the last QuestNotes.lua
rm -rf "$T/ps"
if git clone -q --depth 1 --filter=blob:none --sparse https://github.com/fitzforge/polestar "$T/ps" && git -C "$T/ps" sparse-checkout set forever-db; then
  python3 tools/questnotes/gen.py "$T/ps/forever-db" . || true
fi
# both checks must pass
$LUA tools/audit/audit.lua > "$T/audit.txt" || { cat "$T/audit.txt"; exit 1; }
python3 tools/audit/crosscheck.py . "$T/forever.json" "$T/forever_gear.json" "$LUA"
