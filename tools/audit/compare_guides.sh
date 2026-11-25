#!/bin/sh
# Compare Waypath+'s route with Polestar's and the community RestedXP-format guide (compare_guides.py).
# Fetches both into tools/audit/.cache (ignored by git), dumps our route for every race through the harness, and
# writes the report. Run from the repo root:  sh tools/audit/compare_guides.sh [report.md]
set -e
OUT="${1:-/dev/stdout}"   # (kept apart: the loop below reuses $1)
C=tools/audit/.cache
mkdir -p "$C/routes"
if [ -d "$C/polestar/.git" ]; then git -C "$C/polestar" pull -q --depth 1 || true
else
  git clone -q --depth 1 --filter=blob:none --sparse https://github.com/fitzforge/polestar "$C/polestar"
  git -C "$C/polestar" sparse-checkout set guides/forever
fi
if [ -d "$C/wfg/.git" ]; then git -C "$C/wfg" pull -q || true
else git clone -q --depth 1 https://github.com/craigory1591/wow-forever-guide "$C/wfg"; fi
# RestedXP's own free Forever guides (CC BY-NC-SA 4.0)
if [ -d "$C/rxpguides/.git" ]; then git -C "$C/rxpguides" pull -q --depth 1 || true
else
  git clone -q --depth 1 --filter=blob:none --sparse https://github.com/RestedXP/RXPGuides "$C/rxpguides"
  git -C "$C/rxpguides" sparse-checkout set Guides/forever
fi
for r in "Orc Orc Horde" "Troll Troll Horde" "Scourge Scourge Horde" "Tauren Tauren Horde" "Skyborne-Horde Skyborne Horde" \
         "Human Human Alliance" "Dwarf Dwarf Alliance" "Gnome Gnome Alliance" "NightElf NightElf Alliance" "Skyborne-Alliance Skyborne Alliance"; do
  set -- $r
  lua5.1 tools/harness/run.lua --race "$2" --faction "$3" --class WARRIOR --dump-route "$C/routes/$1.json" > /dev/null
  # with BOT=1: the bot plays each race to 60 too (about 4 minutes each), for the actual zone path and class quests
  if [ -n "$BOT" ]; then
    lua5.1 tools/harness/run.lua --play --until-level 60 --race "$2" --faction "$3" --class WARRIOR --play-dump "$C/routes/$1.bot.json" > /dev/null || true
  fi
done
python3 tools/audit/compare_guides.py "$C/routes" "$C/polestar" "$C/wfg/RXP_WoWForeverGuide" "$C/rxpguides" > "$OUT"
