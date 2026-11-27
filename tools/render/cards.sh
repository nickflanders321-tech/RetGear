#!/bin/sh
# Every card through the reveal, the collection and the big card view, drawn and checked, offline.
#   sh tools/render/cards.sh OUTDIR [--cards 1-120] [--models 1] [--finish 1] [--views reveal,collection,detail]
# Then read OUTDIR/report.md and OUTDIR/sheet-*.png. (WSL: write OUTDIR outside /tmp, which is wiped between calls.)
set -e
OUT=${1:?usage: sh tools/render/cards.sh OUTDIR [options]}
shift
LUA=${LUA:-lua5.1}
mkdir -p "$OUT"
rm -f "$OUT"/*.json "$OUT"/*.png
[ -s tools/harness/.cache/models.lua ] || python3 tools/render/modeldata.py
[ -s tools/harness/.cache/fontmetrics.lua ] || python3 tools/render/fonts.py
$LUA tools/harness/run.lua --shoot tools/render/scenes/cards.lua --out "$OUT" "$@" | tail -3
python3 tools/render/render.py "$OUT" > /dev/null
python3 tools/render/check_cards.py "$OUT"
