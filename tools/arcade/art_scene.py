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
        shade = 255
        d.line([(x, yt), (x, h)], fill=(shade, shade, shade, 255))
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


def make_motifs():
    s = 64
    im = canvas(s * 4, s * 2); d = ImageDraw.Draw(im, "RGBA")
    W = (255, 255, 255, 255)
    def cell(i): return (i % 4) * s, (i // 4) * s
    # 0 pine
    x, y = cell(0)
    for k in range(4):
        d.polygon([(x + 32, y + 6 + k * 11), (x + 14 + k * 2, y + 26 + k * 11), (x + 50 - k * 2, y + 26 + k * 11)], fill=W)
    d.rectangle([x + 29, y + 50, x + 35, y + 62], fill=W)
    # 1 tower
    x, y = cell(1)
    d.rectangle([x + 22, y + 18, x + 42, y + 62], fill=W); d.polygon([(x + 18, y + 18), (x + 46, y + 18), (x + 32, y + 2)], fill=W)
    # 2 tent
    x, y = cell(2)
    d.polygon([(x + 32, y + 14), (x + 6, y + 62), (x + 58, y + 62)], fill=W)
    d.polygon([(x + 32, y + 34), (x + 24, y + 62), (x + 40, y + 62)], fill=(0, 0, 0, 0))
    # 3 arch / ruin
    x, y = cell(3)
    d.rectangle([x + 8, y + 20, x + 20, y + 62], fill=W); d.rectangle([x + 44, y + 28, x + 56, y + 62], fill=W)
    d.pieslice([x + 8, y + 6, x + 56, y + 50], 180, 360, fill=W)
    d.pieslice([x + 20, y + 18, x + 44, y + 44], 180, 360, fill=(0, 0, 0, 0))
    # 4 castle
    x, y = cell(4)
    d.rectangle([x + 8, y + 30, x + 56, y + 62], fill=W)
    for tx in (8, 26, 44):
        d.rectangle([x + tx, y + 16, x + tx + 12, y + 34], fill=W)
        for k in range(3): d.rectangle([x + tx + k * 5, y + 11, x + tx + k * 5 + 3, y + 16], fill=W)
    # 5 hut
    x, y = cell(5)
    d.rectangle([x + 14, y + 36, x + 50, y + 62], fill=W); d.polygon([(x + 8, y + 38), (x + 56, y + 38), (x + 32, y + 14)], fill=W)
    d.rectangle([x + 40, y + 16, x + 46, y + 30], fill=W)
    # 6 standing stones
    x, y = cell(6)
    for sx, sh in ((8, 30), (22, 42), (36, 36), (48, 26)):
        d.rounded_rectangle([x + sx, y + 62 - sh, x + sx + 9, y + 62], 3, fill=W)
    # 7 obelisk
    x, y = cell(7)
    d.polygon([(x + 32, y + 2), (x + 40, y + 20), (x + 38, y + 62), (x + 26, y + 62), (x + 24, y + 20)], fill=W)
    return im


def main():
    save("Sky", make_sky(), 64, 128)
    for k in range(4):
        save("Ridge%d" % (k + 1), ridge(k), 512, 128)
    save("Motifs", make_motifs(), 256, 128)


if __name__ == "__main__":
    main()
