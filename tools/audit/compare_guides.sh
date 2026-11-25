#!/bin/sh
# Compare Waypath+'s route with Polestar's and the community RestedXP-format guide (compare_guides.py).
# Fetches both into tools/audit/.cache (ignored by git), dumps our route for every race through the harness, and
# writes the report. Run from the repo root:  sh tools/audit/compare_guides.sh [report.md]
set -e
C=tools/audit/.cache
mkdir -p "$C/routes"
if [ -d "$C/polestar/.git" ]; then git -C "$C/polestar" pull -q --depth 1 || true
else
  git clone -q --depth 1 --filter=blob:none --sparse https://github.com/fitzforge/polestar "$C/polestar"
  git -C "$C/polestar" sparse-checkout set guides/forever
fi
if [ -d "$C/wfg/.git" ]; then git -C "$C/wfg" pull -q || true
else git clone -q --depth 1 https://github.com/craigory1591/wow-forever-guide "$C/wfg"; fi
for r in "Orc Orc Horde" "Troll Troll Horde" "Scourge Scourge Horde" "Tauren Tauren Horde" "Skyborne-Horde Skyborne Horde" \
         "Human Human Alliance" "Dwarf Dwarf Alliance" "Gnome Gnome Alliance" "NightElf NightElf Alliance" "Skyborne-Alliance Skyborne Alliance"; do
  set -- $r
  lua5.1 tools/harness/run.lua --race "$2" --faction "$3" --class WARRIOR --dump-route "$C/routes/$1.json" > /dev/null
done
python3 tools/audit/compare_guides.py "$C/routes" "$C/polestar" "$C/wfg/RXP_WoWForeverGuide" > "${1:-/dev/stdout}"
