#!/usr/bin/env python3
"""Draw the fishing HUD's button pieces (128 x 128 each, white, tinted in the game):

  FishBtnMask.tga   a rounded square: cuts the icon to shape (a mask texture)
  FishBtnFrame.tga  the rim: a rounded ring, bevelled (lit on top, shaded below), tinted by the button's state
  FishBtnShade.tga  over the icon: a soft inner shadow round the edge and a glassy sheen across the top
  FishBtnGlow.tga   a soft rounded halo behind the button, tinted by state
  FishBtnDrop.tga   a soft dark shadow under the button

All drawn here from rounded-rectangle distance fields; no game or other add-on art.
Usage: python3 tools/media/fishbuttons.py [out-dir]   (needs numpy and Pillow)
"""
import sys, os
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else 'Media'
N, SS = 128, 4
M = N * SS
y, x = (np.mgrid[0:M, 0:M].astype(np.float64) + 0.5) / M * 2 - 1   # -1 .. 1, y down


def rrect(half, radius):
    """signed distance to a rounded square of half-size `half` and corner `radius` (negative inside)"""
    qx, qy = np.abs(x) - (half - radius), np.abs(y) - (half - radius)
    out = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    return out + np.minimum(np.maximum(qx, qy), 0) - radius


def save(name, rgb, a):
    img = np.dstack([rgb, a[..., None]]) if rgb.ndim == 3 else np.dstack([np.repeat(rgb[..., None], 3, 2), a[..., None]])
    img = img.reshape(N, SS, N, SS, 4).mean(axis=(1, 3))
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(os.path.join(OUT, name))
    print('wrote', os.path.join(OUT, name))


os.makedirs(OUT, exist_ok=True)
aa = 2.0 / M * SS   # about one pixel of the final texture, for soft edges
white = np.ones_like(x)

# the icon's shape: a rounded square filling the texture
d = rrect(1.0, 0.30)
save('FishBtnMask.tga', white, np.clip(0.5 - d / aa, 0, 1))

# the rim: a ring around that shape; drawn on a texture 1.12x the icon, so the icon sits inside its inner edge
S = 1 / 1.12
outer = rrect(1.0, 0.34)
inner = rrect(S * 1.0, 0.30 * S)
ring = np.clip(0.5 - outer / aa, 0, 1) * np.clip(0.5 + inner / aa, 0, 1)
bevel = 0.78 + 0.22 * (-y)                      # brighter on top
edge_hi = np.exp(-((outer + 0.025) / 0.02) ** 2) * 0.35 * np.clip(-y + 0.2, 0, 1)   # a thin catch-light on the top rim
# a dark hairline where the rim meets the icon, so the two read apart
seam = np.clip(0.5 + inner / aa, 0, 1) * np.clip(0.5 - (inner - 0.035) / aa, 0, 1)
lum = np.clip(bevel + edge_hi, 0, 1) * (1 - seam)
save('FishBtnFrame.tga', lum, np.clip(ring + seam * 0.9, 0, 1))

# over the icon: darker towards the rim, and a sheen in the top half
d = rrect(1.0, 0.30)
inside = np.clip(0.5 - d / aa, 0, 1)
shadow = np.clip(1 + d / 0.32, 0, 1) ** 2.2      # 1 at the rim, 0 deeper in
sheen = np.clip((-y - 0.05) / 0.9, 0, 1) ** 1.6 * np.clip(1 - (x / 1.1) ** 2, 0, 1) * 0.22
alpha = inside * np.clip(shadow * 0.45 + sheen, 0, 1)
lum = np.where(sheen > shadow * 0.45, 1.0, 0.0)  # sheen is white, the shadow black
save('FishBtnShade.tga', lum * np.ones_like(x), alpha)

# halo: soft, rounded, fading out to the texture's edge
d = rrect(0.62, 0.24)
save('FishBtnGlow.tga', white, np.clip(1 - np.clip(d, 0, None) / 0.38, 0, 1) ** 2.2 * (d > -10))

# drop shadow: a soft dark rounded square
d = rrect(0.78, 0.30)
save('FishBtnDrop.tga', np.zeros_like(x), np.clip(1 - np.clip(d, 0, None) / 0.22, 0, 1) ** 2 * 0.85)
