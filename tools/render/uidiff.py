"""Compare a set of UI shots (scenes/ui.lua, drawn by render.py) with the last accepted set, and show what moved.

    python3 tools/render/uidiff.py NEW_DIR BASE_DIR [--out REPORT_DIR] [--accept]

NEW_DIR and BASE_DIR hold one folder per character (fresh, mid, ...), each with <shot>.png and <shot>.json.
For every shot it reports:
  same      nothing changed (a few stray pixels are ignored)
  changed   these parts of the screen changed: boxed in red on a picture of the new shot beside the accepted one,
            with the texts that appeared or went away
  new       a shot the accepted set doesn't have
  missing   a shot the accepted set has and this run didn't take
Writes REPORT_DIR/report.md and REPORT_DIR/<character>-<shot>.png for each changed shot. --accept then copies the
new set over the accepted one (do that once the changes are the ones you meant).
Exits 1 when anything changed, so a script can stop on it.
"""
import argparse, json, os, re, shutil, sys

import numpy as np
from PIL import Image, ImageDraw

CELL = 8            # changes are grouped in cells of this many pixels
THRESH = 24         # a pixel counts as changed when a channel moved by more than this (0-255)
MIN_CELLS = 2       # a region smaller than this many cells is noise


def texts(path):
    """Every text on screen in a scene file: (frame, text) pairs."""
    try:
        sc = json.load(open(path, encoding="utf-8"))
    except (OSError, ValueError):
        return set()
    out = set()
    for it in sc.get("items") or []:
        if it.get("k") == "text":
            s = " ".join(l[0] for l in it.get("lines") or [] if l and l[0])
            s = re.sub(r"\|c[0-9a-fA-F]{8}|\|r|\|T.-\|t", "", s).strip()
            if s:
                out.add((it.get("frame") or "", s))
    return out


def regions(mask):
    """Changed cells -> boxes (x0, y0, x1, y1 in pixels), by joining touching cells."""
    h, w = mask.shape
    seen = np.zeros_like(mask)
    boxes = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            stack, cells = [(y, x)], []
            seen[y, x] = True
            while stack:
                cy, cx = stack.pop()
                cells.append((cy, cx))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
            if len(cells) >= MIN_CELLS:
                ys = [c[0] for c in cells]
                xs = [c[1] for c in cells]
                boxes.append((min(xs) * CELL, min(ys) * CELL, (max(xs) + 1) * CELL, (max(ys) + 1) * CELL))
    return boxes


def compare(new_png, base_png):
    a = np.asarray(Image.open(new_png).convert("RGB"), dtype=np.int16)
    b = np.asarray(Image.open(base_png).convert("RGB"), dtype=np.int16)
    if a.shape != b.shape:
        return None, a.shape, b.shape
    diff = (np.abs(a - b).max(axis=2) > THRESH)
    h, w = diff.shape
    hc, wc = (h + CELL - 1) // CELL, (w + CELL - 1) // CELL
    pad = np.zeros((hc * CELL, wc * CELL), bool)
    pad[:h, :w] = diff
    cells = pad.reshape(hc, CELL, wc, CELL).any(axis=(1, 3))
    return regions(cells), float(diff.mean()), None


def picture(new_png, base_png, boxes, out):
    """The accepted shot and the new one side by side, cut to the changed area, the changes boxed in red."""
    a = Image.open(new_png).convert("RGB")
    b = Image.open(base_png).convert("RGB")
    x0 = max(0, min(x for x, _, _, _ in boxes) - 40)
    y0 = max(0, min(y for _, y, _, _ in boxes) - 40)
    x1 = min(a.width, max(x for _, _, x, _ in boxes) + 40)
    y1 = min(a.height, max(y for _, _, _, y in boxes) + 40)
    ca, cb = a.crop((x0, y0, x1, y1)), b.crop((x0, y0, x1, y1))
    for im in (ca,):
        d = ImageDraw.Draw(im)
        for bx in boxes:
            d.rectangle((bx[0] - x0, bx[1] - y0, bx[2] - x0 - 1, bx[3] - y0 - 1), outline=(255, 40, 40), width=2)
    w, h = ca.width, ca.height
    sheet = Image.new("RGB", (w * 2 + 12, h + 22), (24, 24, 24))
    sheet.paste(cb, (0, 22))
    sheet.paste(ca, (w + 12, 22))
    d = ImageDraw.Draw(sheet)
    d.text((4, 5), "accepted", fill=(200, 200, 200))
    d.text((w + 16, 5), "now", fill=(255, 120, 120))
    sheet.save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("new")
    ap.add_argument("base")
    ap.add_argument("--out")
    ap.add_argument("--accept", action="store_true")
    a = ap.parse_args()
    out = a.out or a.new
    os.makedirs(out, exist_ok=True)
    lines = ["# UI check", ""]
    counts = {"same": 0, "changed": 0, "new": 0, "missing": 0}
    detail = []
    seen_change = {}
    chars = sorted(set(os.listdir(a.new)) | (set(os.listdir(a.base)) if os.path.isdir(a.base) else set()))
    skip = os.path.basename(os.path.normpath(out))
    for ch in chars:
        if ch == skip:
            continue    # (the report's own folder)
        nd, bd = os.path.join(a.new, ch), os.path.join(a.base, ch)
        if not os.path.isdir(nd) and not os.path.isdir(bd):
            continue
        shots_new = {f[:-4] for f in os.listdir(nd) if f.endswith(".png")} if os.path.isdir(nd) else set()
        shots_base = {f[:-4] for f in os.listdir(bd) if f.endswith(".png")} if os.path.isdir(bd) else set()
        for s in sorted(shots_new | shots_base):
            np_, bp = os.path.join(nd, s + ".png"), os.path.join(bd, s + ".png")
            label = "%s / %s" % (ch, s)
            if s not in shots_base:
                counts["new"] += 1
                detail.append("- **%s**: new (no accepted shot yet)" % label)
                continue
            if s not in shots_new:
                counts["missing"] += 1
                detail.append("- **%s**: missing (the accepted set has it, this run didn't take it)" % label)
                continue
            boxes, frac, other = compare(np_, bp)
            if boxes is None:
                counts["changed"] += 1
                detail.append("- **%s**: changed size (%s, was %s)" % (label, frac[:2], other[:2]))
                continue
            if not boxes:
                counts["same"] += 1
                continue
            counts["changed"] += 1
            tn, tb = texts(os.path.join(nd, s + ".json")), texts(os.path.join(bd, s + ".json"))
            added = sorted(t for _, t in tn - tb)
            gone = sorted(t for _, t in tb - tn)
            # the same change on several shots (the tracker shows on every page): told once, the others listed
            sig = (tuple(added), tuple(gone), tuple(boxes))
            if sig in seen_change:
                seen_change[sig].append(label)
                continue
            seen_change[sig] = []
            pic = "%s-%s.png" % (ch, s)
            picture(np_, bp, boxes, os.path.join(out, pic))
            detail.append("- **%s**: changed, %d area%s, %.2f%% of the screen" % (label, len(boxes), "" if len(boxes) == 1 else "s", frac * 100))
            detail.append(("  - also in: ", sig))
            for t in added[:8]:
                detail.append("  - now: `%s`" % t[:120])
            for t in gone[:8]:
                detail.append("  - was: `%s`" % t[:120])
            if len(added) > 8 or len(gone) > 8:
                detail.append("  - (%d texts appeared and %d went away in all)" % (len(added), len(gone)))
            detail.append("")
            detail.append("  ![%s](%s)" % (label, pic))
            detail.append("")
    lines.append("%d same, %d changed, %d new, %d missing" % (counts["same"], counts["changed"], counts["new"], counts["missing"]))
    lines.append("")
    for d in detail:
        if isinstance(d, tuple):
            others = seen_change.get(d[1]) or []
            if others:
                lines.append(d[0] + ", ".join(others))
        else:
            lines.append(d)
    with open(os.path.join(out, "report.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(lines[2])
    print("report: " + os.path.join(out, "report.md"))
    if a.accept:
        if os.path.isdir(a.base):
            shutil.rmtree(a.base)
        shutil.copytree(a.new, a.base, ignore=shutil.ignore_patterns(skip, "report.md", "*.models.json", "index.json"))
        print("accepted: " + a.base)
    sys.exit(1 if (counts["changed"] or counts["missing"]) and not a.accept else 0)


if __name__ == "__main__":
    main()
