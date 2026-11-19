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
# Polestar's forever-db: hand-checked quest fixes (on top of QuestieDB's data) and quest tags and notes, CC BY 4.0
rm -rf "$T/ps"
git clone -q --depth 1 --filter=blob:none --sparse https://github.com/fitzforge/polestar "$T/ps" && git -C "$T/ps" sparse-checkout set forever-db || rm -rf "$T/ps"
FX=""; [ -s "$T/ps/forever-db/corrections/quests.json" ] && FX="--fixes $T/ps/forever-db"
python3 tools/objectives/gen.py "$T/qdb" "$T/forever.json" . --sql "$T/classic.sql" $FX
python3 tools/routes/gen.py "$T/qdb" "$T/forever.json" . $FX
$LUA tools/nodes/dump.lua "$C/foreverObjectDB.lua" "$T/veins.tsv"
python3 tools/nodes/gen.py "$T/qdb" "$T/veins.tsv" NodeData.lua
$LUA tools/gear/dump.lua "$C" "$T/forever_gear.json"
# WoW Forever's own item stats (LibItemDB, MIT: the data/itemdb branch, kept fresh by .github/workflows/fetch-itemdb.yml)
if [ ! -d "$T/itemdb/Forever" ]; then
  rm -rf "$T/itemdb"
  git clone -q --depth 1 -b data/itemdb "https://github.com/${GITHUB_REPOSITORY:-nickflanders321-tech/RetGear}.git" "$T/itemdb" || true
fi
IDB=""; [ -d "$T/itemdb/Forever" ] && IDB="--itemdb $T/itemdb"
# WoW Forever's own crafting tables (wago.tools DB2 export: the data/wago branch, kept fresh by .github/workflows/fetch-wago.yml)
if [ ! -s "$T/wago/SkillLineAbility.csv.gz" ] && [ ! -s "$T/wago/SkillLineAbility.csv" ]; then
  rm -rf "$T/wago"
  git clone -q --depth 1 -b data/wago "https://github.com/${GITHUB_REPOSITORY:-nickflanders321-tech/RetGear}.git" "$T/wago" || true
fi
[ -s "$T/wago/SkillLineAbility.csv.gz" ] || [ -s "$T/wago/SkillLineAbility.csv" ] && IDB="$IDB --wago $T/wago"
# wowsims/forever's stat weights (MIT): the WoW Forever simulator's own EP presets for every spec it covers
rm -rf "$T/wowsims"
GIT_LFS_SKIP_SMUDGE=1 git clone -q --depth 1 https://github.com/wowsims/forever.git "$T/wowsims" && python3 tools/sims/wowsims.py "$T/wowsims" . || echo "wowsims: kept the weights from the last update"
$LUA tools/gear/specs_dump.lua . "$T/specs.json"
python3 tools/gear/gen.py "$T/classic.sql" "$T/forever_gear.json" "$T/qdb" . --specs "$T/specs.json" $IDB
$LUA tools/waypoints/dump.lua "$C/foreverNpcDB.lua" "$T/npcs.tsv"
python3 tools/waypoints/gen.py "$T/qdb" "$T/npcs.tsv" .
cp "$T/veins.tsv" "$T/objects.tsv"
$LUA tools/profs/items_dump.lua "$C" "$T/items.tsv"
WGP=""; [ -s "$T/wago/SpellReagents.csv.gz" ] && WGP="--wago $T/wago"
python3 tools/profs/gen.py "$T/classic.sql" "$T/forever_gear.json" "$T/qdb" "$T/npcs.tsv" "$T/objects.tsv" . "$T/items.tsv" $WGP
# every profession plan against WoW Forever's own recipe ranges and reagents (an error stops the release and asks Claude)
[ -s "$T/wago/SkillLineAbility.csv.gz" ] && python3 tools/profs/check.py "$T/wago" .
$LUA tools/fishloot/dump.lua "$C" "$T/fl_obj.tsv" "$T/fl_items.tsv"
python3 tools/fishloot/gen.py "$T/classic.sql" "$T/qdb" "$T/fl_obj.tsv" "$T/fl_items.tsv" .
python3 tools/flights/gen.py "$T/classic.sql" "$T/qdb" "$T/npcs.tsv" .
python3 tools/arcade/gen.py "$T/classic.sql" "$T/qdb" .
# NPC cards' 3D models and place cards' map art, by name (kept in step with the card list above)
python3 tools/arcade/gen_art.py "$T/classic.sql" .
python3 tools/arcade/gear.py "$T/classic.sql" .
# dungeon packs: each levelling dungeon's own cards (WoW Forever's item names and qualities when the client tables are there)
WG=""; [ -s "$T/wago/ItemSparse.csv.gz" ] && WG="--wago $T/wago"
python3 tools/arcade/dungeons.py "$T/classic.sql" "$T/forever_gear.json" "$T/qdb" . $WG
# the Field Guide: every rare out in the world, by zone, and the world bosses
python3 tools/arcade/field.py "$T/classic.sql" "$T/forever_gear.json" "$T/qdb" "$T/npcs.tsv" .
# raid packs: WoW Forever's raids from the game client's own tables (needs the data/wago export)
[ -s "$T/wago/Achievement.csv.gz" ] && python3 tools/arcade/raids.py "$T/classic.sql" "$T/forever_gear.json" "$T/qdb" "$T/wago" .
# holiday packs: each holiday's quests, the people in them and what they reward
$LUA tools/arcade/holiday_dump.lua "$C/foreverQuestDB.lua" "$T/holiday.tsv"
python3 tools/arcade/holidays.py "$T/classic.sql" "$T/forever_gear.json" "$T/holiday.tsv" "$T/wago" .
# First Edition: the day each WoW Forever original card arrived (kept in tools/arcade/firstseen.json)
python3 tools/arcade/firstseen.py .
# how close each NPC card's camera sits, from its model's proportions in the game's model table
[ -s "$T/wago/CreatureModelData.csv.gz" ] && python3 tools/arcade/frame.py "$T/wago" .
# raider cards' stand-ins (a client that can't change a model's race): an NPC of the raider's race and sex in armor most
# like their class's raid set
[ -s "$T/wago/NPCModelItemSlotDisplayInfo.csv.gz" ] && python3 tools/arcade/raiderlook.py "$T/wago" . "$T/classic.sql" "$T/qdb"
# card art the game can't find by itself: item icons on appearances, dungeons' loading screens
[ -s "$T/wago/ItemAppearance.csv.gz" ] && python3 tools/arcade/artfix.py "$T/classic.sql" "$T/wago" .
# players' /wp share reports (GitHub issues labelled "quests"): quests the published data doesn't have yet
python3 tools/community/import.py "${GITHUB_REPOSITORY:-nickflanders321-tech/RetGear}" Objectives.lua || true
# quest tags and notes from Polestar's forever-db (CC BY 4.0 layer); a failed download keeps the last QuestNotes.lua
if [ -d "$T/ps/forever-db" ]; then
  python3 tools/questnotes/gen.py "$T/ps/forever-db" . || true
fi
# every card against the game data: its 3D model, level and type, item names and qualities (an error stops the release)
mkdir -p "$T/cards" && $LUA tools/arcade/audit_cards/dump.lua "$T/cards" > /dev/null
python3 tools/arcade/audit_cards/audit.py "$T" "$T/cards"
# both checks must pass
$LUA tools/audit/audit.lua > "$T/audit.txt" || { cat "$T/audit.txt"; exit 1; }
python3 tools/audit/crosscheck.py . "$T/forever.json" "$T/forever_gear.json" "$LUA"
# every weapon and armor piece through the add-on's own stat reader and scorer, in every form the game could show it,
# and tooltips against the gear lists for every class, spec and level (an error stops the release)
if [ -d "$T/itemdb/Forever" ] && [ -s "$T/wago/Spell.csv.gz" ]; then
  python3 tools/audit/stats.py . "$T/itemdb" "$T/wago" "$LUA"
else
  echo "score audit skipped: needs the data/itemdb and data/wago branches (with the Spell table)"
fi
