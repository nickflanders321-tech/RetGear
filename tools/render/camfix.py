"""Cards whose creature model has no camera of its own for the whole body (the model file's "character info"
camera, type 1). Without one the game falls back to framing that is too close: the head or the legs run off the
card (Tepolar, the centaurs, Atiesh). For each such card this finds the camera distance (RG.ARCADE_CAMFIX in
Arcade.lua) at which the whole creature fits, the way the card frames everything else.

    lua5.1 tools/harness/run.lua --shoot tools/render/scenes/npcs.lua --out DIR
    python3 tools/render/camfix.py DIR/npc.json        # prints the cards and a camera distance for each

Needs the local install (casc.py) and the model tables (modeldata.py).
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import model
from render import silhouette

W, H = 204, 160          # a card's model frame (the big card view; the collection's is the same shape)
TOP_ROOM = 0.05          # room above the head


def framing(c, cam):
    it = {"disp": c["disp"], "zoom": c["zoom"], "cam": cam, "facing": 0.5, "pos": [0, 0, 0], "scale": 1, "r": [0, 0, W, H], "log": []}
    img = model.render_item(it, W, H)
    return silhouette(img[..., 3])


def main():
    cards = json.load(open(sys.argv[1]))
    data = model.data()["display"]
    out = []
    for c in cards:
        disp = data.get(c["disp"])
        if not disp:
            continue
        try:
            m = model.load_model(disp["file"])
        except Exception as e:
            print("-- %s: %s" % (c["name"], e), file=sys.stderr)
            continue
        if any(x["type"] == 1 for x in m.cameras):
            continue
        now = framing(c, c["cam"])
        best = None
        cam = c["cam"]
        # the head clear of the top; the feet may touch the bottom (the card's foreground is there). A card that
        # zooms in toward the face (an upright humanoid's portrait, zoom 0.3 and more) only needs its head in.
        for _ in range(60):
            st = framing(c, cam)
            b = st["box"]
            if b and b[1] >= TOP_ROOM and (c["zoom"] >= 0.3 or b[3] <= 1.0 - 0.5 / H):
                best = cam
                break
            cam = round(cam * 1.04, 2)
        out.append((c["name"], c["cam"], best, now))
    for name, was, best, now in out:
        b = now["box"]
        print('  ["%s"] = %s,   -- now %.2f: model %s' % (name.replace('"', '\\"'), best, was,
              "runs off the " + "/".join(e for e in now["edges"] if e in ("top", "bottom")) if set(now["edges"]) & {"top", "bottom"} else "fits"))


if __name__ == "__main__":
    main()
