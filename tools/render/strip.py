#!/usr/bin/env python3
"""Join a folder of film-*.png (from scenes/anim.lua, drawn by render.py) into contact sheets and a GIF.
   python3 tools/render/strip.py DIR [--every 2] [--cols 6] [--cell 320] [--crop l,t,r,b]   (crop in PNG pixels)"""
import sys, glob, os, argparse
from PIL import Image, ImageDraw
ap = argparse.ArgumentParser(); ap.add_argument("dir"); ap.add_argument("--every", type=int, default=2)
ap.add_argument("--cols", type=int, default=6); ap.add_argument("--cell", type=int, default=320)
ap.add_argument("--crop"); ap.add_argument("--rows", type=int, default=4)
a = ap.parse_args()
import re
files = sorted(glob.glob(os.path.join(a.dir, "film-*.png")), key=lambda f: int(re.search(r"-(\d+)\.png$", f).group(1)))[::a.every]
if not files: sys.exit("no film-*.png in " + a.dir + " (run render.py on it first)")
crop = tuple(int(v) for v in a.crop.split(",")) if a.crop else None
frames = []
for f in files:
    im = Image.open(f).convert("RGB")
    if crop: im = im.crop(crop)
    im.thumbnail((a.cell, a.cell * 3)); frames.append((os.path.basename(f)[5:-4], im))
w = max(i.size[0] for _, i in frames); h = max(i.size[1] for _, i in frames)
per = a.cols * a.rows
for s in range(0, len(frames), per):
    chunk = frames[s:s + per]
    rows = (len(chunk) + a.cols - 1) // a.cols
    sheet = Image.new("RGB", (w * a.cols, (h + 14) * rows), (12, 10, 8)); d = ImageDraw.Draw(sheet)
    for i, (n, im) in enumerate(chunk):
        x, y = (i % a.cols) * w, (i // a.cols) * (h + 14)
        sheet.paste(im, (x, y + 14)); d.text((x + 3, y + 1), n, fill=(232, 200, 120))
    p = os.path.join(a.dir, "strip-%02d.png" % (s // per + 1)); sheet.save(p); print(p)
gif = os.path.join(a.dir, "film.gif")
frames[0][1].save(gif, save_all=True, append_images=[i for _, i in frames[1:]], duration=120, loop=0); print(gif)
