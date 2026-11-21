"""Waypath+ Full art print pieces (our own drawing). Output in Media/Arcade:
  FullFade.tga   32x256: the dark a Full art print's name and text sit on, from clear at the top to deep at the bottom
                 (the card's top shade is its first part, upside down)
  FullBand.tga   512x64: the name band: smoked glass with gold hairlines, both fading out at the ends
Run: python3 tools/arcade/art_fullart.py
"""
import os
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "Media", "Arcade"))
INK = (6, 4, 10)

def save(a, name):
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".tga")); print("wrote", name, a.shape[1], "x", a.shape[0])

def fade():
    h, w = 256, 32
    y = (np.arange(h) + 0.5) / h
    # clear, then a quick fall to the dark behind the type line, then deepening to the card's foot
    stops = [(0.0, 0.0), (0.16, 0.42), (0.34, 0.62), (1.0, 0.74)]
    al = np.interp(y, [s[0] for s in stops], [s[1] for s in stops])
    a = np.zeros((h, w, 4), np.float32)
    a[..., 0], a[..., 1], a[..., 2] = INK
    a[..., 3] = (al * 255)[:, None]
    save(a, "FullFade")

def band():
    h, w = 64, 512
    x = (np.arange(w) + 0.5) / w
    y = (np.arange(h) + 0.5) / h
    ends = np.interp(x, [0, 0.14, 0.86, 1], [0, 1, 1, 0])          # the glass fades out at both ends
    a = np.zeros((h, w, 4), np.float32)
    a[..., 0], a[..., 1], a[..., 2] = INK
    a[..., 3] = (0.66 * 255) * ends[None, :]
    # gold hairlines along the top and the bottom: brightest in the middle, gone at the ends
    gold = np.array([231, 196, 108], np.float32); hi = np.array([255, 240, 192], np.float32)
    t = np.clip(1 - np.abs(x - 0.5) / 0.32, 0, 1)                  # 0 at the ends, 1 in the middle
    col = gold[None, :] * (1 - t[:, None]) + hi[None, :] * t[:, None]
    lw = np.interp(x, [0, 0.18, 0.82, 1], [0, 1, 1, 0])
    for yc in (1.6, h - 1.6):
        k = np.clip(1.6 - np.abs(np.arange(h) + 0.5 - yc), 0, 1)     # a line about 3 px across
        al = k[:, None] * lw[None, :]
        for c in range(3): a[..., c] = a[..., c] * (1 - al) + col[None, :, c] * al
        a[..., 3] = np.maximum(a[..., 3], al * 255)
    save(a, "FullBand")

if __name__ == "__main__":
    fade(); band()
