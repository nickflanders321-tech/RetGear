#!/usr/bin/env python3
"""Draw the water ring behind the fishing HUD (Media/FishRing.tga, 256 x 256).

A soft blue glow shaped like a ring, three ripple circles and a scatter of short light glints on the water's
surface (arcs at different distances from the middle). The game turns it slowly, so the glints drift around the
hub. Everything is drawn here: no game art, no other add-on's art.
Usage: python3 tools/media/fishring.py [out-dir]   (needs numpy and Pillow)
"""
import sys, os, math
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else 'Media'
N, SS = 256, 4                       # size, supersampling
M = N * SS
y, x = np.mgrid[0:M, 0:M].astype(np.float64)
c = (M - 1) / 2
dx, dy = (x - c) / (M / 2), (y - c) / (M / 2)
r = np.hypot(dx, dy)                 # 0 at the middle, 1 at the edge
a = np.arctan2(dy, dx)

alpha = np.zeros_like(r)
light = np.zeros_like(r)             # how much toward white

# 1. the glow: strongest a little outside the hub, gone by the edge
glow = np.exp(-((r - 0.48) / 0.26) ** 2)
glow *= np.clip((1.0 - r) / 0.12, 0, 1)
alpha += 0.62 * glow

# 2. three ripple circles
for rr, w, k in ((0.34, 0.010, 0.55), (0.62, 0.008, 0.40), (0.84, 0.007, 0.25)):
    ring = np.exp(-((r - rr) / w) ** 2)
    alpha += k * ring
    light += 0.5 * ring

# 3. glints: short arcs on the surface, seeded so the file is the same every time
rng = np.random.default_rng(7)
for _ in range(26):
    rr = rng.uniform(0.30, 0.90)
    start = rng.uniform(-math.pi, math.pi)
    span = rng.uniform(0.15, 0.55)
    w = rng.uniform(0.006, 0.013)
    k = rng.uniform(0.25, 0.6) * (1.1 - rr * 0.6)
    d = (a - start) % (2 * math.pi)
    inside = d < span
    t = np.where(inside, d / span, 0)
    taper = np.sin(np.pi * t) ** 1.5           # thin at both ends
    arc = np.exp(-((r - rr) / w) ** 2) * taper * inside
    alpha += k * arc
    light += 0.9 * arc

alpha = np.clip(alpha, 0, 1)
light = np.clip(light, 0, 1)
# water blue, toward pale cyan where it's lit
base = np.array([0.20, 0.55, 0.92])
hi = np.array([0.80, 0.95, 1.00])
rgb = base[None, None, :] * (1 - light[..., None]) + hi[None, None, :] * light[..., None]

img = np.dstack([rgb, alpha[..., None]])
img = img.reshape(N, SS, N, SS, 4).mean(axis=(1, 3))
im = Image.fromarray((img * 255 + 0.5).astype(np.uint8), 'RGBA')
os.makedirs(OUT, exist_ok=True)
im.save(os.path.join(OUT, 'FishRing.tga'))
print('wrote', os.path.join(OUT, 'FishRing.tga'))
