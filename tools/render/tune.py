"""Creature cards the real-art sweep (cards.sh) flagged as "tiny" or "zoomed": the camera distance at which each one
fills its frame the way the other cards do (RG.ARCADE_CAMFIX in Arcade.lua).

    lua5.1 tools/harness/run.lua --shoot tools/render/scenes/npcs.lua --out DIR
    python3 tools/render/tune.py DIR/npc.json CARDS_REPORT/report.md [OUT.lua]

Prints one ARCADE_CAMFIX line per card. A card with a portrait zoom (an upright humanoid, zoom 0.3 and more) is
meant to fill its frame, so only "tiny" is acted on for those. Needs the local install (casc.py) and modeldata.py.
"""
import json, re, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import model
from camfix import framing

TARGET = 0.66      # the creature's height as a share of the frame
TOP_ROOM = 0.05


def score(st):
    b = st["box"]
    if not b:
        return None
    h = b[3] - b[1]
    if b[1] < TOP_ROOM or b[3] > 1.0 or b[2] - b[0] > 0.95:
        return None
    return abs(h - TARGET)


def best_cam(c):
    best = None
    cam = 0.4
    while cam < 6:
        s = score(framing(c, cam))
        if s is not None and (best is None or s < best[0]):
            best = (s, cam)
        cam = round(cam * 1.06, 3)
    return best and round(best[1], 2)


def main():
    cards = {c["name"]: c for c in json.load(open(sys.argv[1]))}
    flagged = {}
    for line in open(sys.argv[2], encoding="utf-8"):
        m = re.match(r"- \*\*(.+?)\*\*: (tiny|zoomed)", line)
        if m:
            flagged[m.group(1)] = m.group(2)
    out = []
    for name, why in flagged.items():
        c = cards.get(name)
        if not c:
            continue
        if why == "zoomed" and c["zoom"] >= 0.3:
            continue
        try:
            cam = best_cam(c)
        except Exception as e:
            print("-- %s: %s" % (name, e), file=sys.stderr)
            continue
        if cam and abs(cam - c["cam"]) > 0.05:
            out.append('  ["%s"] = %s,   -- was %s (%s)' % (name.replace('"', '\\"'), cam, c["cam"], why))
    text = "\n".join(out)
    print(text)
    if len(sys.argv) > 3:
        open(sys.argv[3], "w", encoding="utf-8").write(text + "\n")


main()
