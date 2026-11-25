#!/bin/sh
# Build tools/harness/.cache/maps.lua (maps.py): the game's maps, their parents and where they sit in the world, from
# the client's UiMap and UiMapAssignment tables for the build the data/wago branch has. Run from the repo root.
set -e
C=tools/harness/.cache
mkdir -p "$C"
B=$(git show origin/data/wago:BUILD.txt 2>/dev/null | head -1 | tr -d '\r' | sed 's/^build=//')
[ -n "$B" ] || { echo "no build in the data/wago branch (try: git fetch origin data/wago)"; exit 1; }
for t in UiMap UiMapAssignment; do
  curl -sSL -A "Mozilla/5.0" -o "$C/$t.csv" "https://wago.tools/db2/$t/csv?build=$B"
  head -1 "$C/$t.csv" | grep -q ',' || { echo "wago.tools didn't return $t for build $B"; exit 1; }
done
python3 tools/harness/maps.py "$C/UiMap.csv" "$C/UiMapAssignment.csv" "$C/maps.lua"
