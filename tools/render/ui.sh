#!/bin/sh
# The add-on's screens (scenes/ui.lua: the tracker in every view, its menu, every page of the main window) for a few
# characters, drawn and compared with the last accepted set, so a change that moves something shows up.
#   sh tools/render/ui.sh OUTDIR              draw and compare: read OUTDIR/report/report.md
#   sh tools/render/ui.sh OUTDIR --accept     ... and make this set the accepted one (once the changes are wanted)
#   CHARS="fresh" sh tools/render/ui.sh ...   only some of the characters
# The accepted set lives in tools/harness/.cache/ui-baseline (git-ignored: the pictures hold the game's art).
# (WSL: write OUTDIR outside /tmp, which is wiped between calls.)
set -e
OUT=${1:?usage: sh tools/render/ui.sh OUTDIR [--accept]}
ACCEPT=$2
LUA=${LUA:-lua5.1}
BASE=tools/harness/.cache/ui-baseline
CHARS=${CHARS:-"fresh horde20 alliance12"}
[ -s tools/harness/.cache/models.lua ] || python3 tools/render/modeldata.py
[ -s tools/harness/.cache/fontmetrics.lua ] || python3 tools/render/fonts.py
rm -rf "$OUT"
mkdir -p "$OUT"
for c in $CHARS; do
  case $c in
    fresh)      args="" ;;                                                   # level 1, the harness's default character
    horde20)    args="--race Orc --class WARRIOR --play --until-level 20" ;;  # part way through, quests in the log
    alliance12) args="--race Human --class MAGE --play --until-level 12" ;;
    *) echo "unknown character $c"; exit 2 ;;
  esac
  mkdir -p "$OUT/$c"
  echo "== $c"
  # shellcheck disable=SC2086
  $LUA tools/harness/run.lua --shoot tools/render/scenes/ui.lua --out "$OUT/$c" $args | grep -v "^scene " || true
  python3 tools/render/render.py "$OUT/$c" > /dev/null
done
if [ ! -d "$BASE" ] && [ "$ACCEPT" != "--accept" ]; then
  echo "no accepted set yet: look at the pictures in $OUT, then run again with --accept"
  exit 0
fi
if [ "$ACCEPT" = "--accept" ]; then
  python3 tools/render/uidiff.py "$OUT" "$BASE" --out "$OUT/report" --accept
else
  python3 tools/render/uidiff.py "$OUT" "$BASE" --out "$OUT/report"
fi
