#!/usr/bin/env python3
"""Textures for the card duel board (Media/Arcade/*.tga). Reuses the helpers in art.py.
Run:  python3 tools/arcade/art_battle.py [preview]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import art
from art import S, canvas, save, metal, noise, radial, sigil, font, mask_rrect, make_corner, sub


def make_board(w=1024, h=512):
    rng = np.random.RandomState(9)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n = noise(w, h, 64, 31) * 0.5 + noise(w, h, 24, 32) * 0.3 + noise(w, h, 8, 33) * 0.2
    base = np.stack([14 + 18 * n, 11 + 12 * n, 30 + 34 * n], -1)
    # worn stone blocks
    for gy in range(0, h, 64):
        base[gy:gy + 1, :] *= 0.72
    for gy in range(0, h, 64):
        off = 0 if (gy // 64) % 2 == 0 else 64
        for gx in range(off, w, 128):
            base[gy:gy + 64, gx:gx + 1] *= 0.76
    # a pool of warm light on each side of the divide and a dark vignette
    for cy, tint in ((h * 0.27, (26, 14, 4)), (h * 0.73, (26, 14, 4))):
        d = np.sqrt(((xx - w / 2) / (w * 0.5)) ** 2 + ((yy - cy) / (h * 0.28)) ** 2)
        base += np.clip(1 - d, 0, 1)[..., None] * np.array(tint, np.float32)
    vg = 1 - 0.7 * np.clip(np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) - 0.45, 0, 1)
    base *= vg[..., None]
    img = Image.fromarray(np.dstack([np.clip(base, 0, 255), np.full((h, w), 255.0)]).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    # the great circle in the middle
    cy = int(h * 0.46)   # the dividing line sits where the two rows of minions meet
    sg = sigil(int(h * 0.92), (214, 178, 100), seed=11, fine=1.0)
    a = np.asarray(sg).copy(); a[..., 3] = (a[..., 3] * 0.20).astype(np.uint8)
    img.alpha_composite(Image.fromarray(a, "RGBA"), (int(w / 2 - sg.size[0] / 2), int(cy - sg.size[1] / 2)))
    # the dividing line
    for i in range(3):
        d.line([(60, cy + i - 1), (w - 60, cy + i - 1)], fill=(214, 178, 100, 150 - i * 40), width=1)
    d.rectangle([w // 2 - 70, cy - 5, w // 2 + 70, cy + 5], fill=(14, 10, 28, 255), outline=(214, 178, 100, 220))
    # frame
    for k, al in ((3, 255), (7, 120)):
        d.rectangle([k, k, w - 1 - k, h - 1 - k], outline=(180, 146, 80, al))
    return img


def sphere(size, rim, hi, lo, spec=1.0):
    s = size * S
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    c = s / 2
    d = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / (c * 0.92)
    m = np.clip((1 - d) * 18, 0, 1)
    k = np.clip(1 - np.sqrt((xx - c * 0.75) ** 2 + (yy - c * 0.65) ** 2) / (c * 1.15), 0, 1)
    col = np.array(lo, np.float32) * (1 - k[..., None]) + np.array(hi, np.float32) * k[..., None]
    rimm = np.clip((d - 0.80) / 0.20, 0, 1)[..., None]
    col = col * (1 - rimm) + np.array(rim, np.float32) * rimm
    img = Image.fromarray(np.dstack([np.clip(col, 0, 255), m * 255]).astype(np.uint8), "RGBA")
    sp = radial(s, s, c * 0.72, c * 0.58, c * 0.28, 2.2)
    a = np.zeros((s, s, 4), np.uint8); a[..., :3] = 255; a[..., 3] = (sp * 190 * spec * m).astype(np.uint8)
    img.alpha_composite(Image.fromarray(a, "RGBA"))
    return img


def make_badge_atk(size=64):
    im = sphere(size, (60, 40, 8), (255, 226, 120), (214, 140, 24))
    d = ImageDraw.Draw(im, "RGBA"); s = size * S; c = s / 2
    d.ellipse([c * 0.12, c * 0.12, s - c * 0.12, s - c * 0.12], outline=(70, 44, 8, 255), width=2 * S)
    return im


def make_badge_hp(size=64):
    im = sphere(size, (58, 6, 12), (255, 120, 110), (180, 24, 36))
    d = ImageDraw.Draw(im, "RGBA"); s = size * S; c = s / 2
    d.ellipse([c * 0.12, c * 0.12, s - c * 0.12, s - c * 0.12], outline=(64, 6, 12, 255), width=2 * S)
    return im


def make_badge_cost(size=64):
    s = size * S; c = s / 2
    im = canvas(s, s); d = ImageDraw.Draw(im, "RGBA")
    pts = [(c, s * 0.03), (s * 0.92, s * 0.27), (s * 0.92, s * 0.73), (c, s * 0.97), (s * 0.08, s * 0.73), (s * 0.08, s * 0.27)]
    d.polygon(pts, fill=(34, 70, 190, 255))
    d.polygon([pts[0], pts[1], (c, c), pts[5]], fill=(110, 170, 255, 255))
    d.polygon([pts[1], pts[2], (c, c)], fill=(60, 110, 230, 255))
    d.polygon([pts[5], pts[4], (c, c)], fill=(40, 84, 205, 255))
    d.polygon([pts[2], pts[3], pts[4], (c, c)], fill=(20, 44, 140, 255))
    d.polygon([(c, s * 0.1), (s * 0.55, s * 0.28), (c, c), (s * 0.3, s * 0.3)], fill=(200, 228, 255, 190))
    d.line(pts + [pts[0]], fill=(10, 18, 60, 255), width=2 * S)
    return im


def make_crystal(size=64, lit=True):
    s = size * S; c = s / 2
    im = canvas(s, s); d = ImageDraw.Draw(im, "RGBA")
    pts = [(c, s * 0.04), (s * 0.84, s * 0.34), (c, s * 0.97), (s * 0.16, s * 0.34)]
    if lit:
        d.polygon(pts, fill=(50, 120, 255, 255))
        d.polygon([pts[0], pts[1], (c, s * 0.44)], fill=(150, 210, 255, 255))
        d.polygon([pts[0], pts[3], (c, s * 0.44)], fill=(100, 170, 255, 255))
        d.polygon([pts[1], pts[2], (c, s * 0.44)], fill=(30, 80, 220, 255))
        d.polygon([pts[3], pts[2], (c, s * 0.44)], fill=(24, 60, 190, 255))
        d.line(pts + [pts[0]], fill=(12, 24, 80, 255), width=2 * S)
    else:
        d.polygon(pts, fill=(16, 22, 44, 200))
        d.line(pts + [pts[0]], fill=(60, 84, 140, 220), width=2 * S)
    return im


def make_tile(size=128, iron=False):
    s = size * S
    outer = mask_rrect(s, s, (4 * S, 4 * S, s - 4 * S, s - 4 * S), 22 * S)
    inset = 15 if not iron else 19
    inner = mask_rrect(s, s, (inset * S, inset * S, s - inset * S, s - inset * S), 13 * S)
    ring = sub(outer, inner)
    base = (205, 205, 210)
    im = metal(s, s, ring, base=base, warm=0.0, contrast=1.0)
    d = ImageDraw.Draw(im, "RGBA")
    # studs at the corners and a fine inner line
    for (x, y) in ((14, 14), (size - 14, 14), (14, size - 14), (size - 14, size - 14)):
        d.ellipse([(x - 4) * S, (y - 4) * S, (x + 4) * S, (y + 4) * S], fill=(240, 240, 240, 255), outline=(20, 16, 26, 255), width=S)
    if iron:
        for x in range(26, size - 20, 22):   # spikes along the top
            d.polygon([(x * S, 8 * S), ((x + 6) * S, 8 * S), ((x + 3) * S, 0)], fill=(215, 215, 220, 255), outline=(20, 16, 26, 255))
    d.rounded_rectangle([inset * S - S, inset * S - S, s - inset * S + S, s - inset * S + S], 13 * S, outline=(20, 16, 26, 255), width=S * 2)
    return im


def make_bubble(size=128):
    s = size * S
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    c = s / 2
    d = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / (c * 0.96)
    edge = np.clip(1 - np.abs(d - 0.93) / 0.07, 0, 1)
    fill = np.clip(1 - d, 0, 1) ** 0.5 * 0.22 * (d < 1)
    a = np.clip(edge * 0.9 + fill, 0, 1)
    spec = radial(s, s, c * 0.62, c * 0.5, c * 0.34, 2.0) * 0.8
    a = np.clip(a + spec, 0, 1)
    col = np.stack([255 * np.ones_like(a), 238 * np.ones_like(a), 190 * np.ones_like(a)], -1)
    return Image.fromarray(np.dstack([col, a * 255]).astype(np.uint8), "RGBA")


def make_ice(size=128):
    s = size * S
    rng = np.random.RandomState(5)
    im = canvas(s, s); d = ImageDraw.Draw(im, "RGBA")
    d.rounded_rectangle([6 * S, 6 * S, s - 6 * S, s - 6 * S], 20 * S, fill=(120, 190, 255, 70), outline=(210, 240, 255, 230), width=3 * S)
    for _ in range(26):
        x, y = rng.randint(10 * S, s - 10 * S), rng.randint(10 * S, s - 10 * S)
        ln = rng.randint(10 * S, 30 * S); ang = rng.uniform(0, 3.14)
        x2, y2 = x + ln * math.cos(ang), y + ln * math.sin(ang)
        d.line([(x, y), (x2, y2)], fill=(235, 250, 255, 190), width=S)
    for _ in range(10):
        x, y = rng.randint(14 * S, s - 14 * S), rng.randint(14 * S, s - 14 * S)
        r = rng.randint(4 * S, 11 * S)
        d.polygon([(x, y - r), (x + r * 0.6, y), (x, y + r), (x - r * 0.6, y)], fill=(225, 245, 255, 150))
    return im


def main():
    save("Board", make_board(), 1024, 512)
    save("BadgeAtk", make_badge_atk(), 64, 64)
    save("BadgeHp", make_badge_hp(), 64, 64)
    save("BadgeCost", make_badge_cost(), 64, 64)
    save("Crystal", make_crystal(), 64, 64)
    save("CrystalDim", make_crystal(lit=False), 64, 64)
    save("Tile", make_tile(), 128, 128)
    save("TileIron", make_tile(iron=True), 128, 128)
    save("Bubble", make_bubble(), 128, 128)
    save("Ice", make_ice(), 128, 128)


if __name__ == "__main__":
    main()
