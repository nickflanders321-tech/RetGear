#!/usr/bin/env python3
"""Scenery textures for the card art windows (Media/Arcade): sky, ridge silhouettes and small landmarks.
The game tints and arranges them per card so no two cards share a picture. Run: python3 tools/arcade/art_scene.py [preview]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import art
from art import canvas, save, noise


def make_sky(w=64, h=128):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = yy / h                                   # 0 top .. 1 horizon
    n = noise(w, h, 24, 51) * 0.08
    g = 0.30 + 0.70 * t ** 1.4 + n
    a = np.dstack([np.clip(g * 255, 0, 255)] * 3 + [np.full((h, w), 255.0)])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def ridge(kind, w=512, h=128):
    rng = np.random.RandomState(70 + kind)
    xs = np.arange(w, dtype=np.float32)
    y = np.zeros(w, np.float32)
    for k, (amp, harm) in enumerate(((0.30, 1), (0.16, 2), (0.09, 4), (0.05, 7), (0.03, 11))):
        ph = rng.uniform(0, 6.28)
        wave = np.sin(xs / w * 6.2832 * harm + ph)
        if kind == 1: wave = 1 - 2 * np.abs(wave)          # jagged peaks
        if kind == 3 and harm >= 4: wave = np.sign(wave) * np.abs(wave) ** 0.5
        y += amp * wave * (1.0 if kind != 0 else 0.7)
    y = (y - y.min()) / (y.max() - y.min())
    top = (0.12 + 0.7 * y) * h
    im = canvas(w, h); d = ImageDraw.Draw(im, "RGBA")
    for x in range(w):
        yt = h - int(top[x])
        d.line([(x, yt), (x, h)], fill=(205, 205, 205, 255))
        d.line([(x, yt), (x, yt + 2)], fill=(255, 255, 255, 255))      # a lit rim along the crest
    if kind == 2:                                          # pines along the crest
        for x in range(4, w, 11):
            base = h - int(top[x]) + 2; ht = int(rng.randint(10, 22))
            d.polygon([(x, base - ht), (x - 5, base), (x + 5, base)], fill=(255, 255, 255, 255))
    if kind == 3:                                          # snow caps: brighter peaks
        pass
    # darken toward the bottom so the tint gets depth
    arr = np.asarray(im).astype(np.float32)
    grad = np.linspace(1.0, 0.62, h)[:, None]
    arr[..., :3] *= grad[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


K = 4  # motif supersampling: each 128px cell is drawn at 512px and shrunk


def _cell():
    return canvas(128 * K, 128 * K)


def _poly(d, pts, fill):
    d.polygon([(x * K, y * K) for x, y in pts], fill=fill)


def _rect(d, x0, y0, x1, y1, fill):
    d.rectangle([x0 * K, y0 * K, x1 * K, y1 * K], fill=fill)


def _cut(im, fn):
    """draw with fn into a mask and punch it out of im (windows, doors)"""
    m = Image.new("L", im.size, 0); fn(ImageDraw.Draw(m))
    a = np.asarray(im).copy(); a[..., 3] = np.where(np.asarray(m) > 0, 0, a[..., 3]); return Image.fromarray(a)


W = (255, 255, 255, 255)
G = (190, 190, 190, 255)       # a second, darker tone so shapes have depth when tinted


def m_pines():
    im = _cell(); d = ImageDraw.Draw(im)
    for cx, base, h, w in ((40, 124, 78, 26), (70, 124, 104, 32), (98, 124, 66, 22), (20, 124, 50, 17)):
        col = W if cx != 40 else G
        for k in range(5):
            top = base - h + k * h * 0.17; wd = w * (0.35 + k * 0.17)
            _poly(d, [(cx, top - h * 0.12), (cx - wd, top + h * 0.26), (cx + wd, top + h * 0.26)], col)
        _rect(d, cx - 2, base - 12, cx + 2, base, col)
    return im


def m_tower():
    im = _cell(); d = ImageDraw.Draw(im)
    _rect(d, 44, 40, 84, 124, W); _rect(d, 38, 34, 90, 44, G)
    for x in range(38, 90, 14): _rect(d, x, 24, x + 8, 34, G)
    _poly(d, [(50, 24), (78, 24), (64, 4)], W)
    _rect(d, 62, 0, 63, 6, G)
    im = _cut(im, lambda c: (c.rectangle([60 * K, 52 * K, 68 * K, 66 * K], fill=255), c.rectangle([60 * K, 88 * K, 68 * K, 108 * K], fill=255)))
    return im


def m_camp():
    im = _cell(); d = ImageDraw.Draw(im)
    _poly(d, [(40, 50), (6, 124), (74, 124)], W); _poly(d, [(92, 70), (66, 124), (118, 124)], G)
    im = _cut(im, lambda c: (c.polygon([(40 * K, 78 * K), (28 * K, 124 * K), (52 * K, 124 * K)], fill=255), c.polygon([(92 * K, 94 * K), (84 * K, 124 * K), (100 * K, 124 * K)], fill=255)))
    d = ImageDraw.Draw(im); _poly(d, [(62, 124), (68, 110), (74, 124)], W)
    return im


def m_arch():
    im = _cell(); d = ImageDraw.Draw(im)
    _rect(d, 16, 44, 40, 124, W); _rect(d, 88, 60, 112, 124, G)
    d.pieslice([16 * K, 8 * K, 112 * K, 96 * K], 180, 360, fill=W)
    im = _cut(im, lambda c: c.pieslice([40 * K, 30 * K, 88 * K, 90 * K], 180, 360, fill=255))
    d = ImageDraw.Draw(im); _rect(d, 4, 116, 124, 124, G)
    return im


def m_castle():
    im = _cell(); d = ImageDraw.Draw(im)
    _rect(d, 14, 60, 114, 124, W)
    for x, w_, h in ((10, 26, 86), (51, 26, 100), (92, 26, 86)):
        _rect(d, x, 124 - h, x + w_, 124, G if x != 51 else W)
        for k in range(4): _rect(d, x + k * 7, 124 - h - 8, x + k * 7 + 4, 124 - h, G if x != 51 else W)
    _poly(d, [(50, 28), (78, 28), (64, 6)], W)
    im = _cut(im, lambda c: (c.pieslice([50 * K, 90 * K, 78 * K, 130 * K], 180, 360, fill=255), c.rectangle([50 * K, 110 * K, 78 * K, 124 * K], fill=255),
                             c.rectangle([22 * K, 50 * K, 28 * K, 62 * K], fill=255), c.rectangle([100 * K, 50 * K, 106 * K, 62 * K], fill=255), c.rectangle([60 * K, 52 * K, 68 * K, 66 * K], fill=255)))
    return im


def m_cottage():
    im = _cell(); d = ImageDraw.Draw(im)
    _rect(d, 20, 66, 100, 124, W)
    _poly(d, [(10, 70), (110, 70), (64, 28)], G)
    _rect(d, 82, 22, 94, 56, W)
    im = _cut(im, lambda c: (c.rectangle([30 * K, 82 * K, 46 * K, 98 * K], fill=255), c.rectangle([74 * K, 82 * K, 90 * K, 98 * K], fill=255), c.rectangle([54 * K, 92 * K, 68 * K, 124 * K], fill=255)))
    return im


def m_stones():
    im = _cell(); d = ImageDraw.Draw(im)
    for x, w_, h, col in ((6, 20, 70, G), (28, 24, 98, W), (54, 22, 82, W), (78, 20, 104, G), (100, 20, 60, W)):
        d.rounded_rectangle([x * K, (124 - h) * K, (x + w_) * K, 124 * K], 8 * K, fill=col)
    _rect(d, 26, 24, 80, 34, G)
    return im


def m_obelisk():
    im = _cell(); d = ImageDraw.Draw(im)
    _poly(d, [(64, 2), (78, 34), (74, 116), (54, 116), (50, 34)], W)
    _poly(d, [(64, 2), (78, 34), (74, 116), (64, 116)], G)
    _rect(d, 40, 116, 88, 124, G)
    return im


def m_windmill():
    im = _cell(); d = ImageDraw.Draw(im)
    _poly(d, [(46, 124), (82, 124), (74, 56), (54, 56)], W)
    _poly(d, [(50, 56), (78, 56), (64, 38)], G)
    cx, cy = 64, 50
    for a in (30, 120, 210, 300):
        r = math.radians(a)
        ex, ey = cx + 50 * math.cos(r), cy - 50 * math.sin(r)
        nx, ny = -math.sin(r) * 7, -math.cos(r) * 7
        _poly(d, [(cx, cy), (ex, ey), (ex + nx, ey + ny), (cx + nx * .3, cy + ny * .3)], G)
    im = _cut(im, lambda c: c.rectangle([58 * K, 100 * K, 70 * K, 124 * K], fill=255))
    return im


def m_ship():
    im = _cell(); d = ImageDraw.Draw(im)
    _poly(d, [(14, 92), (114, 92), (98, 116), (30, 116)], W)
    _rect(d, 62, 14, 66, 94, G)
    _poly(d, [(60, 18), (60, 80), (24, 80)], W); _poly(d, [(68, 14), (68, 80), (102, 80)], G)
    _poly(d, [(66, 14), (82, 18), (66, 24)], W)
    return im


def m_lighthouse():
    im = _cell(); d = ImageDraw.Draw(im)
    _poly(d, [(44, 124), (84, 124), (76, 40), (52, 40)], W)
    for y in (58, 82, 104): _poly(d, [(46 + (y - 40) * -0.04, y), (82, y), (82, y + 7), (46, y + 7)], G)
    _rect(d, 48, 30, 80, 40, G); _poly(d, [(48, 30), (80, 30), (64, 10)], W)
    im = _cut(im, lambda c: c.rectangle([57 * K, 31 * K, 71 * K, 38 * K], fill=255))
    return im


def m_deadtree():
    im = _cell(); d = ImageDraw.Draw(im)
    _poly(d, [(56, 124), (72, 124), (68, 70), (60, 70)], W)
    for pts in (((64, 80), (30, 50), (20, 22)), ((64, 72), (96, 46), (108, 18)), ((62, 60), (52, 34), (58, 6)), ((30, 50), (10, 54)), ((96, 46), (118, 56)), ((20, 22), (30, 6)), ((108, 18), (98, 4))):
        for a, b in zip(pts, pts[1:]): d.line([(a[0] * K, a[1] * K), (b[0] * K, b[1] * K)], fill=W, width=int(5 * K * (0.5 if len(pts) == 2 else 0.8)))
    return im


def m_crystals():
    im = _cell(); d = ImageDraw.Draw(im)
    for cx, w_, h, col in ((64, 20, 104, W), (36, 16, 70, G), (92, 16, 78, G), (16, 12, 44, W), (112, 12, 50, W)):
        _poly(d, [(cx, 124 - h), (cx + w_ / 2, 124 - h * 0.78), (cx + w_ / 2, 124), (cx - w_ / 2, 124), (cx - w_ / 2, 124 - h * 0.78)], col)
    return im


def m_bridge():
    im = _cell(); d = ImageDraw.Draw(im)
    _rect(d, 0, 66, 128, 76, W)
    for cx in (28, 64, 100):
        d.pieslice([(cx - 20) * K, 56 * K, (cx + 20) * K, 112 * K], 180, 360, fill=G)
    _rect(d, 0, 76, 128, 124, G)
    im = _cut(im, lambda c: [c.pieslice([(cx - 14) * K, 70 * K, (cx + 14) * K, 124 * K], 180, 360, fill=255) for cx in (28, 64, 100)] and [c.rectangle([(cx - 14) * K, 98 * K, (cx + 14) * K, 124 * K], fill=255) for cx in (28, 64, 100)])
    d = ImageDraw.Draw(im)
    for x in range(4, 128, 12): _rect(d, x, 52, x + 3, 66, W)
    return im


def m_cave():
    im = _cell(); d = ImageDraw.Draw(im)
    d.pieslice([4 * K, 28 * K, 124 * K, 150 * K], 180, 360, fill=W)
    _rect(d, 4, 88, 124, 124, W)
    im = _cut(im, lambda c: (c.pieslice([40 * K, 66 * K, 88 * K, 118 * K], 180, 360, fill=255), c.rectangle([40 * K, 92 * K, 88 * K, 124 * K], fill=255)))
    d = ImageDraw.Draw(im)
    for x, h in ((46, 20), (58, 14), (72, 18), (82, 10)): _poly(d, [(x, 66 + h * 0.2), (x + 5, 66 + h * 0.2), (x + 2.5, 66 + h)], G)
    return im


def m_temple():
    im = _cell(); d = ImageDraw.Draw(im)
    _poly(d, [(8, 52), (120, 52), (64, 14)], W)
    _rect(d, 12, 54, 116, 62, G)
    for x in (18, 40, 62, 84, 104): _rect(d, x, 64, x + 8, 112, W)
    _rect(d, 6, 112, 122, 124, G)
    return im


MOTIF_BUILDERS = (m_pines, m_tower, m_camp, m_arch, m_castle, m_cottage, m_stones, m_obelisk,
                  m_windmill, m_ship, m_lighthouse, m_deadtree, m_crystals, m_bridge, m_cave, m_temple)


def make_motifs():
    """4x4 sheet of 128px landmarks in a 512x512 texture (the game picks one per card and tints it)"""
    sheet = canvas(512, 512)
    for i, fn in enumerate(MOTIF_BUILDERS):
        cell = fn().resize((128, 128), Image.LANCZOS)
        sheet.alpha_composite(cell, ((i % 4) * 128, (i // 4) * 128))
    return sheet


def make_stars(s=256):
    rng = np.random.RandomState(9)
    im = canvas(s * 4, s * 4); d = ImageDraw.Draw(im)
    for _ in range(170):
        x, y = rng.randint(0, s * 4), rng.randint(0, s * 4); r = rng.choice((2, 2, 3, 4, 6))
        a = int(rng.randint(120, 255))
        d.ellipse([x - r / 2, y - r / 2, x + r / 2, y + r / 2], fill=(255, 255, 255, a))
        if r >= 6:
            d.line([(x - 12, y), (x + 12, y)], fill=(255, 255, 255, a // 2), width=2); d.line([(x, y - 12), (x, y + 12)], fill=(255, 255, 255, a // 2), width=2)
    return im.resize((s, s), Image.LANCZOS)


def make_mist(w=64, h=128):
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    a = np.exp(-((yy - 0.62) / 0.22) ** 2) * 0.9
    arr = np.dstack([np.full((h, w), 255.0)] * 3 + [a * 255])
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def make_fore(w=512, h=64):
    """a dark grassy strip along the bottom edge: gives every scene a foreground"""
    rng = np.random.RandomState(4)
    im = canvas(w, h); d = ImageDraw.Draw(im)
    base = np.convolve(rng.rand(w + 20), np.ones(21) / 21, "valid")[:w]
    for x in range(w):
        top = int(h * (0.58 - 0.36 * base[x]))
        d.line([(x, top), (x, h)], fill=(255, 255, 255, 255))
    for x in range(0, w, 3):
        top = int(h * (0.58 - 0.36 * base[x])) - int(rng.randint(2, 9))
        d.line([(x, top), (x + int(rng.randint(-2, 3)), top + 9)], fill=(255, 255, 255, 255), width=1)
    return im


def main():
    save("Sky", make_sky(), 64, 128)
    for k in range(4):
        save("Ridge%d" % (k + 1), ridge(k), 512, 128)
    save("Motifs", make_motifs(), 512, 512)
    save("Stars", make_stars(), 256, 256)
    save("Mist", make_mist(), 64, 128)
    save("Fore", make_fore(), 512, 64)


if __name__ == "__main__":
    main()
