"""Waypath+ booster pack art, drawn by us. Two layers so the foil can be tinted per set while the trim stays gold:
  PackBody.tga     256x512  tintable foil wrapper below the tear line (shaded, crimped bottom, dark label panels)
  PackTop.tga      256x128  tintable crimped top strip that tears off
  PackTrim.tga     256x512  untinted gold ornament for the body (frame, banners, medallion rings, sparkles)
  PackTrimTop.tga  256x128  untinted gold trim for the strip
Run: python3 tools/arcade/art_packs.py
"""
import os, numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
D = os.path.join(os.path.dirname(__file__), "..", "..", "Media", "Arcade")
S = 3
W, H = 256 * S, 512 * S
rng = np.random.default_rng(5)
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
xs, ys = x / S, y / S

def sm(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)
def blur(a, r): return gaussian_filter(a.astype(np.float32), r * S / 3)

L, R, T, B = 6, 250, 44, 468
CT, CB = T + 54, B - 64                       # crimp zones end / start
tooth = 2.6 * (np.abs(((xs / 3.5) % 1.0) - 0.5) * 2)
mask = (xs > L) & (xs < R) & (ys > T + tooth) & (ys < B - tooth)
dx = np.minimum(xs - L, R - xs)
dy = np.minimum(ys - T - tooth, B - tooth - ys)
dist = np.minimum(dx, dy)

# ---- foil body: brushed vertical streaks, a puffed "pillow" shape, two soft specular bands
streak = blur(rng.standard_normal((H, W)), 0.7)
streak = gaussian_filter(streak, (6 * S, 0.5 * S)); streak /= streak.std()
fine = blur(rng.standard_normal((H, W)), 0.5); fine /= fine.std()
u = (xs - 128) / 114.0
pillow = 1 - 0.30 * u ** 2                               # darker toward the sides
vert = 1 - 0.18 * ((ys - 256) / 256.0) ** 2
spec1 = np.exp(-(((xs * 0.8 - ys * 0.55) - 20) / 34.0) ** 2)   # diagonal sheen bands
spec2 = np.exp(-(((xs * 0.8 - ys * 0.55) + 120) / 18.0) ** 2)
foil = 0.50 * pillow * vert + 0.04 * streak + 0.015 * fine + 0.32 * spec1 + 0.18 * spec2
# crimps: strong ridges, shaded
ridge = 0.5 + 0.5 * np.sin(xs * 2 * np.pi / 4.2)
topz = sm(CT, CT - 20, ys); botz = sm(CB, CB + 20, ys)
cz = np.maximum(topz, botz)
foil = foil * (1 - 0.45 * cz) + 0.5 * cz * (0.25 + 0.75 * ridge) * 0.8
# edge bevel
foil *= 0.55 + 0.45 * sm(0, 10, dist)
foil += 0.22 * (np.abs(dist - 1.2) < 1.0)               # bright rim
foil = np.clip(foil, 0, 1)

# ---- dark label panels (tinted dark): title banner, medallion disc, set band
def pointed(x0, x1, y0, y1, pt):
    cy = (y0 + y1) / 2; hh = (y1 - y0) / 2
    xin = np.clip((np.minimum(xs - x0, x1 - xs)), 0, None)
    half = np.where(xin < pt, hh * xin / pt, hh)
    return (xs > x0) & (xs < x1) & (np.abs(ys - cy) < half)
title = pointed(16, 240, 128, 178, 16)
band = pointed(26, 230, 352, 390, 12)
cx, cy = 128, 252
rr = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
disc = rr < 66
dark = title | band | disc
foil = np.where(dark, foil * 0.30 + 0.05, foil)
# a faint radial glow behind the medallion
foil += 0.10 * np.exp(-(rr / 110.0) ** 2) * (~dark)
foil = np.clip(foil, 0, 1)

# ---- tear line
zig = CT + 2 + 4.2 * np.abs(((xs / 13.0) % 1.0) - 0.5) * 2 + 1.5 * np.sin(xs / 7.0)
strip = mask & (ys < zig); body = mask & (ys >= zig)
edge_d = np.clip(ys - zig, 0, 8)
foil_b = foil * (0.78 + 0.22 * sm(0, 8, edge_d))

# ---- gold trim
def gold(v):
    v = np.clip(v, 0, 1)
    c0 = np.array([110, 72, 18], np.float32); c1 = np.array([255, 232, 150], np.float32)
    return c0[None, None, :] * (1 - v[..., None]) + c1[None, None, :] * v[..., None]
gv = np.zeros((H, W), np.float32); ga = np.zeros((H, W), np.float32)
def paint(m, v, a=1.0):
    global gv, ga
    gv = np.where(m, v, gv); ga = np.where(m, a, ga)
light = 0.55 + 0.45 * np.sin((xs * 0.8 - ys * 0.55) / 40.0) * 0.5 + 0.25 * (0.5 + 0.5 * np.sin(ys / 30.0))
# frame: a bright line and a fine inner line, following the wrapper, stopping at the crimps
inner = (ys > CT + 8) & (ys < CB - 8)
paint((np.abs(dist - 9) < 1.0) & inner & mask, light + 0.2)
paint((np.abs(dist - 13) < 0.5) & inner & mask, light * 0.8, 0.8)
# crimp edge lines
for yy in (CT + 2, CB - 2):
    paint((np.abs(ys - yy) < 0.9) & (xs > L + 8) & (xs < R - 8), light + 0.1)
# banners: outlines
def outline(shape, w=1.3):
    from scipy.ndimage import binary_erosion
    er = binary_erosion(shape, iterations=max(1, int(w * S)))
    return shape & ~er
paint(outline(title, 1.4), light + 0.25); paint(outline(band, 1.2), light + 0.2)
# diamonds at the ends of the title banner and corners of the frame
for (px, py, r) in [(26, 153, 6), (230, 153, 6), (L + 12, CT + 14, 4), (R - 12, CT + 14, 4), (L + 12, CB - 14, 4), (R - 12, CB - 14, 4)]:
    d = np.abs(xs - px) + np.abs(ys - py)
    paint(d < r, 0.98); paint((d < r) & (d > r - 1.4), 0.55)
# medallion: rings, ticks, petals
paint((rr > 63) & (rr < 66.5), light + 0.3)
paint((rr > 58) & (rr < 59.2), light * 0.9)
paint((rr > 69) & (rr < 70), light * 0.7, 0.8)
ang = np.arctan2(ys - cy, xs - cx)
tick = (rr > 70) & (rr < 76) & (np.abs(np.sin(ang * 12)) > 0.985)
paint(tick, 0.95)
for k in range(8):
    a = k * np.pi / 4 + np.pi / 8
    px, py = cx + 80 * np.cos(a), cy + 80 * np.sin(a)
    d = np.abs(xs - px) + np.abs(ys - py)
    paint(d < 5.5, 0.98); paint((d < 5.5) & (d > 3.6), 0.5)
# rays from the medallion, faint
ray = (rr > 86) & (rr < 118) & (np.abs(np.sin(ang * 16)) > 0.992)
paint(ray & mask & ~dark, 0.9, 0.35)
# sparkles
for (sx, sy, sz) in [(40, 214, 8), (214, 222, 6), (46, 322, 6), (208, 316, 9), (30, 262, 4), (224, 270, 4), (156, 204, 4)]:
    dd = np.minimum(np.abs(xs - sx) * 5 + np.abs(ys - sy), np.abs(xs - sx) + np.abs(ys - sy) * 5)
    paint(dd < sz, 1.0)
# soft glow on the gold so it reads as metal
ga_s = ga
rgb = gold(gv)
def save(path, m, rgb_arr, a, box):
    aa = np.where(m, a, 0)
    im = Image.fromarray(np.dstack([np.clip(rgb_arr, 0, 255).astype(np.uint8), (np.clip(aa, 0, 1) * 255).astype(np.uint8)]), "RGBA").resize((256, 512), Image.LANCZOS)
    im.crop(box).save(path)
def gray(v): return np.repeat((np.clip(v, 0, 1) * 255)[..., None], 3, axis=2)
save(os.path.join(D, "PackBody.tga"), body, gray(foil_b), 1.0, (0, 0, 256, 512))
save(os.path.join(D, "PackTop.tga"), strip, gray(foil), 1.0, (0, 0, 256, 128))
save(os.path.join(D, "PackTrim.tga"), body & (ga > 0), rgb, ga, (0, 0, 256, 512))
save(os.path.join(D, "PackTrimTop.tga"), strip & (ga > 0), rgb, ga, (0, 0, 256, 128))
# a holographic band for the sheen sweep: iridescent, soft, alpha only where the band is (512 wide so it can slide)
by, bx = np.mgrid[0:512, 0:512].astype(np.float32)
along = (bx - 256) - (by - 256) * 0.5            # distance across a diagonal band
band = np.exp(-(along / 34.0) ** 2)
hue = np.clip(along / 60.0, -1, 1)
rgb = np.dstack([np.clip(1.0 + 0.0 * hue, 0, 1), np.clip(1.0 - 0.35 * np.abs(hue) + 0.1 * hue, 0, 1), np.clip(1.0 - 0.1 * np.abs(hue) - 0.3 * hue, 0, 1)])
edge = np.clip(np.minimum(bx, 511 - bx) / 24.0, 0, 1)
sheen = np.dstack([(rgb * 255).astype(np.uint8), (np.clip(band * edge, 0, 1) * 255).astype(np.uint8)])
Image.fromarray(sheen, "RGBA").save(os.path.join(D, "PackSheen.tga"))
sy, sx2 = np.mgrid[0:128, 0:128].astype(np.float32)
rr2 = np.sqrt((sx2 - 63.5) ** 2 + (sy - 63.5) ** 2) / 63.5
sa = np.clip(1 - rr2, 0, 1) ** 1.6
Image.fromarray(np.dstack([np.full((128, 128, 3), 255, np.uint8), (sa * 255).astype(np.uint8)]), "RGBA").save(os.path.join(D, "Soft.tga"))
print("ok")
