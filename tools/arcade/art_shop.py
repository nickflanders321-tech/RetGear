#!/usr/bin/env python3
"""The Shop's display cases (Waypath+ 1.45):
  ShopCase   a glass-fronted display case for one of the three regular packs: dark wood, a gold inlay, a velvet back
             with a soft light from above, and a little shelf the pack stands on (256x256; shown at about 228x236)
  ShopFrame  the gilt frame round an aisle banner (Dungeons, Raids, Holidays): transparent inside (512x256)
Run: python3 tools/arcade/art_shop.py [preview]"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
from art import save, noise


def wood(w, h, seed, base=(70, 42, 24)):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    g = 0.8 + 0.18 * np.sin(yy * 0.05 + noise(w, h, 8, seed) * 6) + 0.08 * (noise(w, h, 2, seed + 1) - 0.5)
    return np.dstack([base[0] * g, base[1] * g, base[2] * g])


def make_case(z=1024):
    yy, xx = np.mgrid[0:z, 0:z].astype(np.float32)
    out = np.zeros((z, z, 4), np.float32)
    out[..., :3] = wood(z, z, 3)
    out[..., 3] = 255
    b = int(z * 0.045)
    # velvet back: deep plum to near black, a soft pool of light from above, fine nap
    ix0, iy0, ix1, iy1 = b, b, z - b, int(z * 0.86)
    inside = (xx >= ix0) & (xx < ix1) & (yy >= iy0) & (yy < iy1)
    ny = (yy - iy0) / (iy1 - iy0)
    spot = np.exp(-(((xx - z / 2) / (z * 0.32)) ** 2 + ((yy - z * 0.18) / (z * 0.42)) ** 2))
    nap = 0.92 + 0.12 * noise(z, z, 2, 9)
    vel = np.dstack([46 + 70 * spot, 26 + 34 * spot, 44 + 52 * spot]) * nap[..., None] * (1 - 0.35 * ny)[..., None]
    out[..., :3] = np.where(inside[..., None], vel, out[..., :3])
    # inner shadow round the velvet
    edge = np.minimum.reduce([xx - ix0, ix1 - xx, yy - iy0, iy1 - yy])
    sh = np.clip(1 - edge / (z * 0.04), 0, 1) * inside
    out[..., :3] *= (1 - 0.55 * sh)[..., None]
    # the shelf: a wood lip under the pack, lit on its top edge
    sy0, sy1 = int(z * 0.86), int(z * 0.955)
    shelf = (yy >= sy0) & (yy < sy1) & (xx >= b) & (xx < z - b)
    out[..., :3] = np.where(shelf[..., None], wood(z, z, 7, (96, 60, 32)) * (1.15 - 0.5 * ((yy - sy0) / (sy1 - sy0)))[..., None], out[..., :3])
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    d.line([(b, sy0), (z - b, sy0)], fill=(230, 190, 120, 255), width=int(z * 0.006))
    # gold inlay round the case, and a thin one round the velvet
    for inset, w, col in ((int(z * 0.014), int(z * 0.007), (210, 168, 92)), (b - int(z * 0.008), int(z * 0.005), (160, 120, 60))):
        d.rectangle((inset, inset, z - 1 - inset, z - 1 - inset), outline=col + (255,), width=w)
    d.rectangle((ix0, iy0, ix1, iy1), outline=(120, 86, 40, 255), width=int(z * 0.004))
    # the glass: one soft diagonal sheen
    glass = Image.new("L", (z, z), 0); dg = ImageDraw.Draw(glass)
    dg.polygon([(ix0 + z * 0.08, iy0), (ix0 + z * 0.22, iy0), (ix0 + z * 0.02, iy1 * 0.55), (ix0, iy1 * 0.55)], fill=38)
    glass = glass.filter(ImageFilter.GaussianBlur(z * 0.01))
    img.paste(Image.new("RGBA", (z, z), (255, 255, 255, 255)), (0, 0), glass)
    return img


def make_frame(w=1024, h=512):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    for inset, wd, col in ((4, 10, (120, 86, 36)), (8, 4, (236, 196, 112)), (20, 3, (180, 138, 62))):
        d.rectangle((inset, inset, w - 1 - inset, h - 1 - inset), outline=col + (255,), width=wd)
    # corner ornaments: a small diamond in each corner
    for cx, cy in ((24, 24), (w - 25, 24), (24, h - 25), (w - 25, h - 25)):
        r = 16
        d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=(236, 196, 112, 255), outline=(110, 76, 26, 255))
        d.polygon([(cx, cy - r * 0.45), (cx + r * 0.45, cy), (cx, cy + r * 0.45), (cx - r * 0.45, cy)], fill=(120, 86, 36, 255))
    return img


if __name__ == "__main__":
    save("ShopCase", make_case(), 256, 256)
    save("ShopFrame", make_frame(), 512, 256)
