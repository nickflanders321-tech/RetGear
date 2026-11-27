"""Check every card's model in a card sweep (scenes/cards.lua, drawn by render.py): flag the ones that look wrong,
and put them side by side on contact sheets to look at.

    python3 tools/render/check_cards.py DIR      # DIR: the sweep's scenes, already drawn (render.py DIR)

Per card and view (reveal, collection, detail) it reads where the model sits in its frame (render.py's
*.models.json) and flags:
  blank      the model frame shows nothing (no model, or it didn't load)
  zoomed     the model runs off the top and the bottom of its frame and fills most of it (a leg, a belly)
  tiny       the model covers almost none of its frame
  differs    the same card is framed very differently in two views (the reveal against the collection)
Writes DIR/report.md and DIR/sheet-*.png (each flagged card, in every view, with its flags).
"""
import json, os, sys

from PIL import Image, ImageDraw, ImageFont


def load(d):
    names = json.load(open(os.path.join(d, "index.json")))
    cards = {}   # name -> view -> [entry]
    for n in names:
        sc_path = os.path.join(d, n + ".json")
        mp = os.path.join(d, n + ".models.json")
        if not os.path.exists(sc_path):
            continue
        sc = json.load(open(sc_path))
        models = json.load(open(mp)) if os.path.exists(mp) else []
        view = "reveal" if n.startswith("reveal") else ("collection" if n.startswith("collection") else ("detail" if n.startswith("detail") else n))
        if n.endswith("-dealt"):
            continue
        if n.endswith("-turning"):
            view = "reveal-turning"
        for mk in sc.get("marks") or []:
            if (mk.get("info") or {}).get("covered"):
                continue   # (still face down)
            if not mk.get("models"):
                continue   # (a card with no model: an item, a place)
            # the drawn models that are this card's own (same frame box and display)
            inside = []
            for own in mk["models"]:
                for m in models:
                    if own.get("r") and all(abs(m["r"][i] - own["r"][i]) < 0.6 for i in range(4)) and m.get("disp") == own.get("disp"):
                        inside.append(m)
                        break
            if not inside:
                inside = [{"drawn": False, "why": "not drawn (hidden or not loaded)", "disp": mk["models"][0].get("disp")}]
            e = {"scene": n, "r": mk["r"], "screen": sc["screen"], "models": inside, "info": mk.get("info")}
            cards.setdefault(mk["label"], {}).setdefault(view, []).append(e)
    return cards


def judge(e):
    flags = []
    if not e["models"]:
        return ["blank"]
    m = e["models"][0]
    if not m.get("drawn"):
        why = m.get("why") or ""
        # (one we can't draw is our renderer's limit, not necessarily the card's: reported apart)
        return ["blank"] if why in ("not loaded", "no model file for it") or "not drawn" in why else ["undrawable: " + why]
    cov = m.get("cover", 0)
    edges = set(m.get("edges") or [])
    if cov < 0.01:
        flags.append("blank")
    elif cov < 0.06:
        flags.append("tiny")
    if {"top", "bottom"} <= edges and cov > 0.45:
        flags.append("zoomed")
    return flags


def height(e):
    m = e["models"][0] if e["models"] else None
    b = m and m.get("box")
    return (b[3] - b[1]) if b else 0


def crop(d, e, scale=1.0):
    img = Image.open(os.path.join(d, e["scene"] + ".png"))
    sw, sh = e["screen"]
    l, b, r, t = e["r"]
    k = img.size[1] / sh
    return img.crop((int(l * k), int((sh - t) * k), int(r * k), int((sh - b) * k)))


def main():
    d = sys.argv[1]
    cards = load(d)
    bad = []
    lines = ["# Card check", "", "%d cards with models" % len(cards), ""]
    for name, views in sorted(cards.items()):
        why = {}
        for v, es in views.items():
            for e in es:
                for f in judge(e):
                    why.setdefault(f, set()).add(v)
        # the same card framed differently: the model's height in its frame, reveal against collection and detail
        hs = {v: height(es[-1]) for v, es in views.items() if es and es[-1]["models"]}
        ref = hs.get("collection") or hs.get("detail")
        for v in ("reveal", "reveal-turning"):
            if v in hs and ref and (hs[v] > ref * 1.35 or hs[v] < ref / 1.35):
                why.setdefault("differs", set()).add("%s %.2f vs %.2f" % (v, hs[v], ref))
        if why:
            bad.append((name, views, why))
            lines.append("- **%s**: %s" % (name, "; ".join("%s (%s)" % (k, ", ".join(sorted(v))) for k, v in sorted(why.items()))))
    lines.insert(3, "%d flagged" % len(bad))
    # contact sheets: a row per flagged card, its views side by side
    try:
        fnt = ImageFont.load_default()
    except Exception:
        fnt = None
    rows_per = 8
    order = ["reveal-turning", "reveal", "collection", "detail"]
    for si in range(0, len(bad), rows_per):
        chunk = bad[si:si + rows_per]
        tiles = []
        for name, views, why in chunk:
            row = []
            for v in order:
                if v in views:
                    try:
                        row.append((v, crop(d, views[v][-1])))
                    except Exception:
                        pass
            tiles.append((name, why, row))
        th = 260
        W = 1400
        sheet = Image.new("RGB", (W, th * len(tiles)), (20, 20, 24))
        dr = ImageDraw.Draw(sheet)
        for ri, (name, why, row) in enumerate(tiles):
            y = ri * th
            dr.text((8, y + 6), name, fill=(255, 220, 120), font=fnt)
            dr.text((8, y + 22), "; ".join("%s: %s" % (k, ", ".join(sorted(v))) for k, v in sorted(why.items()))[:180], fill=(230, 120, 120), font=fnt)
            x = 8
            for v, im in row:
                sc = min(220 / max(1, im.size[1]), 300 / max(1, im.size[0]))
                im2 = im.resize((max(1, int(im.size[0] * sc)), max(1, int(im.size[1] * sc))))
                sheet.paste(im2, (x, y + 38))
                dr.text((x, y + 38 + im2.size[1] + 2 - 14), v, fill=(200, 200, 200), font=fnt)
                x += im2.size[0] + 12
        out = os.path.join(d, "sheet-%02d.png" % (si // rows_per + 1))
        sheet.save(out)
        lines.append("")
        lines.append("![%s](%s)" % (os.path.basename(out), os.path.basename(out)))
    open(os.path.join(d, "report.md"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines[:4]))
    print("report: %s" % os.path.join(d, "report.md"))


if __name__ == "__main__":
    main()
