#!/usr/bin/env python3
"""Draw the whirlpool behind the fishing HUD (Media/FishRing.tga, 256 x 256).

Water spinning into the middle: a soft blue body, five curling arms that tighten toward the centre (logarithmic
spirals) and thin bright foam streaks riding on them. The game turns it while the HUD opens and closes, so the arms
appear to pour inward. Everything is drawn here: no game art, no other add-on's art.
Usage: python3 tools/media/fishring.py [out-dir]   (needs numpy and Pillow)
"""
import sys, os, math
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else 'Media'
N, SS = 256, 4
M = N * SS
y, x = np.mgrid[0:M, 0:M].astype(np.float64)
c = (M - 1) / 2
dx, dy = (x - c) / (M / 2), (y - c) / (M / 2)
r = np.hypot(dx, dy) + 1e-6
a = np.arctan2(dy, dx)

# where the water is: from a calm eye in the middle out to a soft edge
body = np.clip((r - 0.10) / 0.18, 0, 1) * np.clip((1.0 - r) / 0.22, 0, 1)

# five arms curling inward: along a log spiral the phase  a - k*ln(r)  is constant
ARMS, K = 5, 2.4
phase = (a - K * np.log(r)) * ARMS
arm = (0.5 + 0.5 * np.cos(phase)) ** 3                 # broad bands of deeper water
foam = (0.5 + 0.5 * np.cos(phase + 0.9)) ** 18         # thin bright crests just ahead of them
ripple = (0.5 + 0.5 * np.cos(phase * 2.0 + r * 30)) ** 10 * 0.35

alpha = body * (0.38 + 0.42 * arm + 0.55 * foam + ripple)
light = np.clip(0.15 + 0.85 * foam + 0.5 * ripple, 0, 1) * body
# a brighter rim where the water meets the edge, and the eye a little lighter
alpha += np.exp(-((r - 0.80) / 0.05) ** 2) * 0.25 * (0.6 + 0.4 * arm)
alpha = np.clip(alpha, 0, 1)

deep = np.array([0.10, 0.38, 0.78])
mid = np.array([0.25, 0.62, 0.95])
hi = np.array([0.85, 0.97, 1.00])
rgb = deep[None, None, :] * (1 - arm[..., None]) + mid[None, None, :] * arm[..., None]
rgb = rgb * (1 - light[..., None]) + hi[None, None, :] * light[..., None]

img = np.dstack([rgb, alpha[..., None]])
img = img.reshape(N, SS, N, SS, 4).mean(axis=(1, 3))
im = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')
os.makedirs(OUT, exist_ok=True)
im.save(os.path.join(OUT, 'FishRing.tga'))
print('wrote', os.path.join(OUT, 'FishRing.tga'))
