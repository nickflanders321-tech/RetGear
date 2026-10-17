"""Waypath+ booster pack art: a foil wrapper, drawn by us, grayscale so the add-on tints it per set.
Outputs (Media/Arcade/):
  PackBody.tga  256x512  the wrapper below the tear line (the top edge is jagged and transparent above it)
  PackTop.tga   256x128  the crimped top strip that tears off (rows 0-72 hold the strip)
Run: python3 tools/arcade/art_packs.py
"""
import os, numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
D = os.path.join(os.path.dirname(__file__), "..", "..", "Media", "Arcade")
S = 3
W, H = 256 * S, 512 * S
rng = np.random.default_rng(11)
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
xs, ys = x / S, y / S   # in 256x512 units

def smooth(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

# --- foil: vertical gradient, diagonal sheen bands, fine crinkle
base = 0.70 + 0.10 * np.cos((ys / 512) * 6.283)
band = 0.5 + 0.5 * np.sin((xs * 0.9 + ys * 0.55) / 22.0)
base += 0.10 * band * smooth(0.2, 0.8, np.abs(np.sin((xs - ys * 0.3) / 60.0)))
noise = gaussian_filter(rng.standard_normal((H, W)).astype(np.float32), 5 * S / 3)
base += 0.35 * noise / noise.std() * 0.05
crinkle = gaussian_filter(rng.standard_normal((H, W)).astype(np.float32), 1.6 * S / 3)
base += 0.04 * crinkle / crinkle.std()
# --- crimped top and bottom: vertical ridges
CT, CB = 66, 446
crimp = 0.5 + 0.5 * np.sin(xs * 2 * np.pi / 5.0)
top_zone = smooth(CT + 4, CT - 14, ys)          # 1 near the top edge
bot_zone = smooth(CB - 4, CB + 14, ys)
ridge = (top_zone + bot_zone)
base = base * (1 - 0.22 * ridge) + 0.22 * ridge * crimp * 0.9
# --- wrapper outline with serrated crimp edges
L, R, T, B = 16, 240, 12, 500
tooth = 3.0 * (np.abs(((xs / 4.0) % 1.0) - 0.5) * 2)
mask = (xs > L) & (xs < R) & (ys > T + tooth) & (ys < B - tooth)
# soft darkening toward the edges and a lighter inner line
dx = np.minimum(xs - L, R - xs); dy = np.minimum(ys - T - tooth, B - tooth - ys)
dist = np.minimum(dx, dy)
base *= 0.72 + 0.28 * smooth(0, 14, dist)
base += 0.12 * (np.abs(dist - 7) < 0.9)
# --- design: title band, medallion, name band, sparkles (all grayscale, drawn on top of the foil)
def band_rect(y0, y1, x0=L + 14, x1=R - 14, dark=0.55, edge=0.95):
    inside = (xs > x0) & (xs < x1) & (ys > y0) & (ys < y1)
    e = inside & ((xs < x0 + 1.4) | (xs > x1 - 1.4) | (ys < y0 + 1.4) | (ys > y1 - 1.4))
    return inside, e
global_img = base.copy()
ins, e = band_rect(100, 148); global_img[ins] *= 0.55; global_img[e] = 1.0
ins, e = band_rect(392, 428); global_img[ins] *= 0.55; global_img[e] = 1.0
# diamonds either side of the title band
for cx in (L + 24, R - 24):
    d = np.abs(xs - cx) + np.abs(ys - 124)
    global_img[d < 7] = 0.98; global_img[(d < 7) & (d > 4.5)] = 0.4
# medallion
cx, cy = 128, 262
r = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
disc = r < 70
global_img[disc] *= 0.45
global_img[(r > 66) & (r < 70)] = 0.98
global_img[(r > 61) & (r < 63)] = 0.8
for k in range(24):
    a = k * 2 * np.pi / 24
    px, py = cx + 76 * np.cos(a), cy + 76 * np.sin(a)
    dd = np.abs(xs - px) + np.abs(ys - py)
    global_img[dd < 3.2] = 0.98
# sparkles
for (sx, sy, sz) in [(52, 190, 7), (206, 205, 6), (60, 350, 5), (200, 340, 8), (44, 270, 4), (214, 280, 4)]:
    dd = np.minimum(np.abs(xs - sx) * 5 + np.abs(ys - sy), np.abs(xs - sx) + np.abs(ys - sy) * 5)
    global_img[dd < sz] = np.maximum(global_img[dd < sz], 0.97)
img = np.clip(global_img, 0, 1.0)
img = np.where(mask, img, 0)
# --- tear line: jagged, separates strip from body
zig = 66 + 4.2 * np.abs(((xs / 13.0) % 1.0) - 0.5) * 2 + 1.5 * np.sin(xs / 7.0)
strip = mask & (ys < zig)
body = mask & (ys >= zig)
# a little shadow where the body's torn edge sits
edge_d = np.clip(ys - zig, 0, 8)
img_body = img * (0.78 + 0.22 * smooth(0, 8, edge_d))
def save(path, rgb_mask, vals, box):
    a = np.where(rgb_mask, 255, 0).astype(np.uint8)
    g = (np.clip(vals, 0, 1) * 255).astype(np.uint8)
    im = Image.fromarray(np.dstack([g, g, g, a]), "RGBA").resize((256, 512), Image.LANCZOS)
    im = im.crop(box)
    im.save(path)
save(os.path.join(D, "PackBody.tga"), body, img_body, (0, 0, 256, 512))
top = Image.fromarray(np.dstack([(np.clip(img, 0, 1) * 255).astype(np.uint8)] * 3 + [np.where(strip, 255, 0).astype(np.uint8)]), "RGBA").resize((256, 512), Image.LANCZOS).crop((0, 0, 256, 128))
top.save(os.path.join(D, "PackTop.tga"))
print("ok")
