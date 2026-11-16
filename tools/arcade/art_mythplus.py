#!/usr/bin/env python3
"""The Mythics' extras (Waypath+ 1.45), all drawn here:
  WaxSeal     the red wax seal stamped on a dungeon's Mythic (the opener's name and the day are written over it in game)
  GoldSeal    the gold seal on one of the six Waypath Mythics
  Plinth      the stone plinth a Mythic stands on in the trophy hall (256x128)
  GemPrism    the rainbow gem beside a dungeon whose heart you hold (32x32)
  Cog         a cog for Gnomeregan's card (64x64)
  Foot        a footprint for The Wanderer (32x64)
  Pin         the golden waypoint pin for The First Waypoint (64x96; our own drawing, not the add-on's 3D arrow)
Run: python3 tools/arcade/art_mythplus.py [preview]"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
from art import save, noise


def blob(z, seed, r0=0.4, wob=0.06):
    rs = np.random.RandomState(seed)
    ph = rs.uniform(0, 6.28, 5)
    pts = []
    for i in range(72):
        a = i / 72 * 2 * math.pi
        r = r0 + wob * (math.sin(a * 3 + ph[0]) * 0.5 + math.sin(a * 5 + ph[1]) * 0.3 + math.sin(a * 8 + ph[2]) * 0.2)
        pts.append((z / 2 + math.cos(a) * r * z, z / 2 + math.sin(a) * r * z))
    return pts


def lit_disc(z, mask, base, hi):
    yy, xx = np.mgrid[0:z, 0:z].astype(np.float32)
    nx, ny = (xx - z / 2) / (z / 2), (yy - z / 2) / (z / 2)
    lam = np.clip(0.6 - 0.5 * nx - 0.6 * ny, 0, 1.2)
    col = np.array(base, np.float32)[None, None, :] * (0.55 + 0.6 * lam)[..., None]
    col += (np.exp(-(((nx + 0.35) ** 2 + (ny + 0.4) ** 2) / 0.04)) * 0.5)[..., None] * np.array(hi, np.float32)
    m = np.asarray(mask, np.float32)
    return Image.fromarray(np.dstack([np.clip(col, 0, 255), m]).astype(np.uint8), "RGBA")


def make_seal(z=512, base=(170, 30, 26), hi=(255, 170, 150), ring=(90, 12, 10), star=(250, 200, 180), seed=3):
    m = Image.new("L", (z, z), 0); ImageDraw.Draw(m).polygon(blob(z, seed), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(z * 0.004))
    out = lit_disc(z, m, base, hi)
    d = ImageDraw.Draw(out)
    c = z / 2
    for r, w in ((0.31, 0.012), (0.25, 0.006)):
        d.ellipse((c - z * r, c - z * r, c + z * r, c + z * r), outline=ring + (255,), width=int(z * w))
    # a pressed star: a dark side and a light side, like the stamp left it
    pts = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        rr = z * (0.2 if i % 2 == 0 else 0.07)
        pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
    for i in range(8):
        a, b = pts[i], pts[(i + 1) % 8]
        mid = ((a[0] + b[0]) / 2 - c, (a[1] + b[1]) / 2 - c)
        light = -0.6 * mid[0] - 0.8 * mid[1] > 0
        d.polygon([a, b, (c, c)], fill=(star if light else tuple(int(v * 0.55) for v in star)) + (255,))
    return out


def make_plinth(w=512, h=256):
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(out)
    cx = w / 2
    # a soft shadow on the floor
    sh = Image.new("L", (w, h), 0); ImageDraw.Draw(sh).ellipse((cx - w * 0.44, h * 0.8, cx + w * 0.44, h * 0.98), fill=150)
    out.paste(Image.new("RGBA", (w, h), (0, 0, 0, 255)), (0, 0), sh.filter(ImageFilter.GaussianBlur(10)))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    def stone(poly, shade):
        m = Image.new("L", (w, h), 0); ImageDraw.Draw(m).polygon(poly, fill=255)
        n = 0.85 + 0.2 * noise(w, h, 6, 7) + 0.06 * noise(w, h, 2, 8)
        lit = 0.75 + 0.35 * (1 - (xx - cx + w * 0.4) / (w * 0.8))
        g = np.clip(shade * n * lit, 0, 1.4)
        img = np.dstack([118 * g, 114 * g, 128 * g, np.full((h, w), 255.0)])
        out.paste(Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA"), (0, 0), m)
    # base step, column, top slab (seen a little from above)
    stone([(cx - w * 0.42, h * 0.74), (cx + w * 0.42, h * 0.74), (cx + w * 0.44, h * 0.9), (cx - w * 0.44, h * 0.9)], 0.8)
    stone([(cx - w * 0.3, h * 0.3), (cx + w * 0.3, h * 0.3), (cx + w * 0.34, h * 0.76), (cx - w * 0.34, h * 0.76)], 0.9)
    stone([(cx - w * 0.38, h * 0.16), (cx + w * 0.38, h * 0.16), (cx + w * 0.4, h * 0.3), (cx - w * 0.4, h * 0.3)], 1.0)
    top = Image.new("L", (w, h), 0); ImageDraw.Draw(top).ellipse((cx - w * 0.38, h * 0.08, cx + w * 0.38, h * 0.24), fill=255)
    tg = np.dstack([170 * (0.9 + 0.15 * noise(w, h, 5, 9)), 166 * (0.9 + 0.15 * noise(w, h, 5, 9)), 180 * (0.9 + 0.15 * noise(w, h, 5, 9)), np.full((h, w), 255.0)])
    out.paste(Image.fromarray(np.clip(tg, 0, 255).astype(np.uint8), "RGBA"), (0, 0), top)
    d = ImageDraw.Draw(out)
    d.line([(cx - w * 0.3, h * 0.3), (cx + w * 0.3, h * 0.3)], fill=(40, 38, 46, 255), width=3)
    d.line([(cx - w * 0.42, h * 0.74), (cx + w * 0.42, h * 0.74)], fill=(40, 38, 46, 255), width=3)
    # a brass plate on the column (the game writes on it)
    d.rounded_rectangle((cx - w * 0.2, h * 0.42, cx + w * 0.2, h * 0.62), radius=6, fill=(196, 150, 72, 255), outline=(110, 76, 26, 255), width=3)
    d.rounded_rectangle((cx - w * 0.18, h * 0.445, cx + w * 0.18, h * 0.595), radius=4, fill=(60, 40, 16, 235))
    return out


def make_gem(z=128):
    out = Image.new("RGBA", (z, z), (0, 0, 0, 0))
    yy, xx = np.mgrid[0:z, 0:z].astype(np.float32)
    c = z / 2
    inside = (np.abs(xx - c) + np.abs(yy - c)) <= z * 0.44
    ang = np.arctan2(yy - c, xx - c)
    h = (ang / (2 * np.pi)) % 1
    i = np.floor(h * 6); f = h * 6 - i
    q, t = 1 - f, f
    r = np.select([i == 0, i == 1, i == 2, i == 3, i == 4], [1, q, 0, 0, t], 1)
    g = np.select([i == 0, i == 1, i == 2, i == 3, i == 4], [t, 1, 1, q, 0], 0)
    b = np.select([i == 0, i == 1, i == 2, i == 3, i == 4], [0, 0, t, 1, 1], q)
    light = 0.55 + 0.45 * np.clip(1 - np.sqrt((xx - c * 0.8) ** 2 + (yy - c * 0.7) ** 2) / (z * 0.5), 0, 1)
    img = np.dstack([(0.45 + 0.55 * r) * 255 * light, (0.45 + 0.55 * g) * 255 * light, (0.45 + 0.55 * b) * 255 * light, inside * 255.0])
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(out)
    d.polygon([(c, z * 0.06), (z * 0.94, c), (c, z * 0.94), (z * 0.06, c)], outline=(255, 255, 255, 255), width=int(z * 0.04))
    d.line([(c, z * 0.06), (c, z * 0.94)], fill=(255, 255, 255, 120), width=2); d.line([(z * 0.06, c), (z * 0.94, c)], fill=(255, 255, 255, 120), width=2)
    return out


def make_cog(z=256):
    out = Image.new("RGBA", (z, z), (0, 0, 0, 0)); d = ImageDraw.Draw(out)
    c = z / 2
    pts = []
    for i in range(10 * 4):
        a = i / 40 * 2 * math.pi
        r = z * (0.46 if (i % 4) in (1, 2) else 0.36)
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    d.polygon(pts, fill=(200, 210, 222, 255), outline=(80, 90, 104, 255))
    d.ellipse((c - z * 0.15, c - z * 0.15, c + z * 0.15, c + z * 0.15), fill=(0, 0, 0, 0))
    d.ellipse((c - z * 0.15, c - z * 0.15, c + z * 0.15, c + z * 0.15), outline=(80, 90, 104, 255), width=4)
    return out


def make_foot(w=128, h=256):
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(out)
    d.ellipse((w * 0.2, h * 0.28, w * 0.8, h * 0.72), fill=(255, 255, 255, 230))
    d.ellipse((w * 0.28, h * 0.66, w * 0.72, h * 0.95), fill=(255, 255, 255, 230))
    for i, (x, y, r) in enumerate(((0.3, 0.2, 0.08), (0.45, 0.14, 0.085), (0.6, 0.15, 0.08), (0.72, 0.2, 0.07), (0.8, 0.27, 0.06))):
        d.ellipse((w * (x - r), h * (y - r / 2), w * (x + r), h * (y + r / 2)), fill=(255, 255, 255, 230))
    return out.filter(ImageFilter.GaussianBlur(2))


def make_pin(w=256, h=384):
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    m = Image.new("L", (w, h), 0); dm = ImageDraw.Draw(m)
    cx, cy, R = w / 2, h * 0.36, w * 0.36
    dm.ellipse((cx - R, cy - R, cx + R, cy + R), fill=255)
    dm.polygon([(cx - R * 0.86, cy + R * 0.5), (cx + R * 0.86, cy + R * 0.5), (cx, h * 0.96)], fill=255)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    lam = np.clip(0.75 - 0.5 * (xx - cx) / R - 0.4 * (yy - cy) / R, 0, 1.3)
    col = np.dstack([240 * (0.5 + 0.5 * lam), 186 * (0.5 + 0.5 * lam), 70 * (0.5 + 0.5 * lam), np.asarray(m, np.float32)])
    out = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(out)
    d.ellipse((cx - R * 0.42, cy - R * 0.42, cx + R * 0.42, cy + R * 0.42), fill=(90, 60, 18, 255))
    d.ellipse((cx - R * 0.7, cy - R * 0.78, cx - R * 0.2, cy - R * 0.4), fill=(255, 246, 210, 150))
    return out


def main():
    save("WaxSeal", make_seal(), 128, 128)
    save("GoldSeal", make_seal(base=(214, 160, 64), hi=(255, 240, 190), ring=(120, 80, 20), star=(255, 238, 180), seed=5), 128, 128)
    save("Plinth", make_plinth(), 256, 128)
    save("GemPrism", make_gem(), 32, 32)
    save("Cog", make_cog(), 64, 64)
    save("Foot", make_foot(), 32, 64)
    save("Pin", make_pin(), 64, 96)


if __name__ == "__main__":
    main()
