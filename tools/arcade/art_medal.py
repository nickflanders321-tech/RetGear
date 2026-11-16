#!/usr/bin/env python3
"""IconRim (an item icon's rim on a card) and an achievement's medal for the Feats tab (Waypath+ 1.45): a gold disc with a raised star on two ribbon tails.
Earned medals show as drawn; ones still to earn are greyed in game. Run: python3 tools/arcade/art_medal.py [preview]"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
from art import save


def make_medal(z=256):
    out = Image.new("RGBA", (z, z), (0, 0, 0, 0)); d = ImageDraw.Draw(out)
    c = z / 2; cy = z * 0.42; R = z * 0.32
    # ribbon tails behind the disc
    for side in (-1, 1):
        x0 = c + side * z * 0.07
        pts = [(x0 - z * 0.09, cy + R * 0.3), (x0 + z * 0.09, cy + R * 0.3), (x0 + side * z * 0.05 + z * 0.09, z * 0.96), (x0 + side * z * 0.05, z * 0.88), (x0 + side * z * 0.05 - z * 0.09, z * 0.96)]
        d.polygon(pts, fill=(150, 34, 30, 255), outline=(80, 14, 12, 255))
        d.line([(x0 - z * 0.02, cy + R * 0.5), (x0 + side * z * 0.04 - z * 0.02, z * 0.86)], fill=(196, 64, 52, 255), width=int(z * 0.025))
    # the disc: a lit gold dome with a bevelled rim
    yy, xx = np.mgrid[0:z, 0:z].astype(np.float32)
    r = np.sqrt((xx - c) ** 2 + (yy - cy) ** 2) / R
    nx, ny = (xx - c) / R, (yy - cy) / R
    lam = np.clip(0.55 - 0.45 * nx - 0.55 * ny, 0, 1)
    rim = (r > 0.82) & (r <= 1)
    g = np.where(rim, 0.55 + 0.6 * np.clip(-0.5 * nx - 0.7 * ny, -1, 1) * 0.5 + 0.25, 0.55 + 0.55 * lam)
    gold = np.dstack([235 * g, 180 * g, 80 * g, (r <= 1) * 255.0])
    disc = Image.fromarray(np.clip(gold, 0, 255).astype(np.uint8), "RGBA")
    out.alpha_composite(disc)
    d = ImageDraw.Draw(out)
    d.ellipse((c - R, cy - R, c + R, cy + R), outline=(110, 72, 20, 255), width=max(2, int(z * 0.012)))
    d.ellipse((c - R * 0.82, cy - R * 0.82, c + R * 0.82, cy + R * 0.82), outline=(130, 88, 26, 255), width=max(1, int(z * 0.008)))
    # a raised five-point star: a dark side and a light side
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = R * (0.6 if i % 2 == 0 else 0.25)
        pts.append((c + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=(170, 116, 36, 255))
    for i in range(10):
        a, b = pts[i], pts[(i + 1) % 10]
        mid = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        light = (mid[0] - c) * -0.6 + (mid[1] - cy) * -0.8 > 0
        d.polygon([a, b, (c, cy)], fill=(255, 226, 140, 255) if light else (190, 132, 44, 255))
    return out


def make_iconrim(z=128):
    """The gold rim round an item's icon on a card: a dark slot with a faint question mark (an icon still loading)."""
    from PIL import ImageFont
    im = Image.new("RGBA", (z, z), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle((0, 0, z - 1, z - 1), fill=(232, 196, 106, 255))
    d.rectangle((3, 3, z - 4, z - 4), fill=(20, 15, 24, 255))
    try:
        f = ImageFont.truetype(os.path.join(os.path.dirname(__file__), "..", "..", "Media", "Fonts", "Cinzel-ExtraBold.ttf"), 70)
        w = d.textlength("?", font=f); d.text(((z - w) / 2, 18), "?", font=f, fill=(90, 74, 50, 255))
    except Exception: pass
    return im


if __name__ == "__main__":
    save("Medal", make_medal(), 64, 64)
    save("IconRim", make_iconrim(), 128, 128)
