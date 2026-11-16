#!/usr/bin/env python3
"""The dungeon, raid and holiday packs' own seals (Waypath+ 1.45), drawn over the pack's wrapper (256x512, the pack's
own size on screen is 160x320):
  PackCrate   a dungeon pack: a wooden crate with a fuse (ArcadePackFx.lua burns it down, then it bursts into planks)
  PackChains  a raid pack: two crossed chains, light grey (tinted in game: they glow as the lock heats)
  PackLock    the padlock where they cross (64x64)
  PackRibbon  a holiday pack: a ribbon round the wrapper; PackBow its bow (128x64)
All drawn here. Run: python3 tools/arcade/art_packfx.py [preview]"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
import art
from art import S, canvas, mask_rrect, mask_poly, sub, shift, noise, save

W, H = 256 * S, 512 * S


def P(v): return int(v * S)


def wood(w, h, seed=3, base=(122, 84, 46)):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    grain = np.sin(xx * 0.09 + noise(w, h, 6, seed) * 9) * 0.5 + 0.5
    g = 0.72 + 0.22 * grain + (noise(w, h, 2, seed + 1) - 0.5) * 0.12
    col = np.stack([g * base[0], g * base[1], g * base[2]], -1)
    return Image.fromarray(np.dstack([np.clip(col, 0, 255), np.full((h, w), 255.0)]).astype(np.uint8), "RGBA")


def make_crate():
    out = canvas(W, H)
    x0, y0, x1, y1 = P(10), P(112), P(246), P(482)
    body = mask_rrect(W, H, (x0, y0, x1, y1), P(6))
    # shadow
    out.paste(Image.new("RGBA", (W, H), (0, 0, 0, 140)), (0, 0), shift(body, P(3), P(4)).filter(ImageFilter.GaussianBlur(P(4))))
    # vertical planks, each its own grain
    n = 5
    pw = (x1 - x0) / n
    for i in range(n):
        m = mask_rrect(W, H, (int(x0 + i * pw) + P(1), y0, int(x0 + (i + 1) * pw) - P(1), y1), P(3))
        m = Image.fromarray(np.minimum(np.asarray(m), np.asarray(body)))
        shade = (122 + (i % 2) * 10, 84 + (i % 2) * 6, 46)
        out.paste(wood(W, H, seed=11 + i, base=shade), (0, 0), m)
        gap = sub(m, m.filter(ImageFilter.MinFilter(3)))
        out.paste(Image.new("RGBA", (W, H), (40, 24, 12, 255)), (0, 0), gap)
    # two battens and a brace
    for yb in (0.22, 0.78):
        yc = int(y0 + (y1 - y0) * yb)
        m = mask_rrect(W, H, (x0 - P(4), yc - P(20), x1 + P(4), yc + P(20)), P(4))
        out.paste(wood(W, H, seed=31, base=(98, 64, 32)), (0, 0), m)
        e = sub(m, m.filter(ImageFilter.MinFilter(3)))
        out.paste(Image.new("RGBA", (W, H), (30, 18, 8, 255)), (0, 0), e)
        for xn in (x0 + P(12), x1 - P(12)):
            for yn in (yc - P(9), yc + P(9)):
                ImageDraw.Draw(out).ellipse((xn - P(3), yn - P(3), xn + P(3), yn + P(3)), fill=(60, 60, 66, 255), outline=(20, 20, 24, 255))
    ya, yb2 = int(y0 + (y1 - y0) * 0.22) + P(20), int(y0 + (y1 - y0) * 0.78) - P(20)
    brace = mask_poly(W, H, [(x0 + P(6), yb2 - P(10)), (x0 + P(6), yb2 + P(8)), (x1 - P(6), ya + P(10)), (x1 - P(6), ya - P(8))])
    out.paste(wood(W, H, seed=41, base=(104, 70, 36)), (0, 0), brace)
    e = sub(brace, brace.filter(ImageFilter.MinFilter(3)))
    out.paste(Image.new("RGBA", (W, H), (30, 18, 8, 255)), (0, 0), e)
    # a stencilled band in the middle for the dungeon's name (the game writes it)
    band = mask_rrect(W, H, (x0 + P(18), P(266), x1 - P(18), P(316)), P(4))
    out.paste(Image.new("RGBA", (W, H), (20, 12, 6, 150)), (0, 0), band)
    # the fuse: a cord from the top of the crate, curling up
    d = ImageDraw.Draw(out)
    pts = [(P(178), y0 + P(4)), (P(186), y0 - P(4)), (P(198), y0 - P(10)), (P(210), y0 - P(8)), (P(220), y0 - P(16))]
    d.line(pts, fill=(200, 178, 126, 255), width=P(3), joint="curve")
    d.line(pts, fill=(120, 96, 60, 255), width=P(1))
    return out


def link(d, cx, cy, ang, rx, ry, col, width):
    # an oval chain link at an angle
    pts = []
    for k in range(40):
        a = 2 * math.pi * k / 40
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * math.cos(ang) - y * math.sin(ang), cy + x * math.sin(ang) + y * math.cos(ang)))
    d.line(pts + [pts[0]], fill=col, width=width)


def make_chains():
    out = canvas(W, H)
    shadow = canvas(W, H); ds = ImageDraw.Draw(shadow)
    d = ImageDraw.Draw(out)
    for (ax, ay, bx, by) in ((P(-10), P(120), P(266), P(400)), (P(-10), P(400), P(266), P(120))):
        ang = math.atan2(by - ay, bx - ax)
        L = math.hypot(bx - ax, by - ay)
        step = P(22)
        for i in range(int(L / step) + 1):
            cx, cy = ax + math.cos(ang) * step * i, ay + math.sin(ang) * step * i
            flat = i % 2 == 1
            link(ds, cx + P(3), cy + P(4), ang, P(15), P(4 if flat else 8), (0, 0, 0, 150), P(5))
            link(d, cx, cy, ang, P(15), P(4 if flat else 8), (232, 232, 238, 255), P(5))
            link(d, cx, cy, ang, P(15), P(4 if flat else 8), (130, 130, 140, 255), P(1))
    shadow = shadow.filter(ImageFilter.GaussianBlur(P(2)))
    shadow.alpha_composite(out)
    return shadow


def make_lock(size=64):
    s = size * S
    out = canvas(s, s); d = ImageDraw.Draw(out)
    c = s / 2
    d.arc((c - s * 0.22, s * 0.06, c + s * 0.22, s * 0.52), 180, 360, fill=(220, 220, 228, 255), width=int(s * 0.08))
    body = (c - s * 0.32, s * 0.36, c + s * 0.32, s * 0.92)
    d.rounded_rectangle(body, radius=int(s * 0.08), fill=(200, 200, 208, 255), outline=(40, 40, 46, 255), width=S * 2)
    d.rounded_rectangle((body[0] + S * 3, body[1] + S * 3, body[2] - S * 3, body[1] + s * 0.12), radius=S * 2, fill=(245, 245, 250, 255))
    d.ellipse((c - s * 0.06, s * 0.56, c + s * 0.06, s * 0.68), fill=(30, 30, 36, 255))
    d.polygon([(c - s * 0.03, s * 0.64), (c + s * 0.03, s * 0.64), (c + s * 0.02, s * 0.8), (c - s * 0.02, s * 0.8)], fill=(30, 30, 36, 255))
    return out


def make_ribbon():
    out = canvas(W, H)
    col = (232, 196, 106, 255)
    m = Image.new("L", (W, H), 0); dm = ImageDraw.Draw(m)
    dm.rectangle((P(112), P(108), P(144), P(486)), fill=255)
    dm.rectangle((P(8), P(240), P(248), P(272)), fill=255)
    sh = shift(m, P(2), P(3)).filter(ImageFilter.GaussianBlur(P(2)))
    out.paste(Image.new("RGBA", (W, H), (0, 0, 0, 130)), (0, 0), sh)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    g = 0.82 + 0.18 * np.sin(xx * 0.05 + yy * 0.05)
    img = np.dstack([g * col[0], g * col[1], g * col[2], np.full((H, W), 255.0)]).astype(np.uint8)
    out.paste(Image.fromarray(img, "RGBA"), (0, 0), m)
    e = sub(m, m.filter(ImageFilter.MinFilter(3)))
    out.paste(Image.new("RGBA", (W, H), (140, 100, 30, 255)), (0, 0), e)
    return out


def make_bow(w=128, h=64):
    Wb, Hb = w * S, h * S
    out = canvas(Wb, Hb); d = ImageDraw.Draw(out)
    c = Wb / 2
    for side in (-1, 1):
        loop = [(c, Hb * 0.55), (c + side * Wb * 0.42, Hb * 0.12), (c + side * Wb * 0.46, Hb * 0.62), (c, Hb * 0.62)]
        d.polygon(loop, fill=(232, 196, 106, 255), outline=(140, 100, 30, 255))
        d.polygon([(c, Hb * 0.58), (c + side * Wb * 0.3, Hb * 0.95), (c + side * Wb * 0.18, Hb * 0.98), (c, Hb * 0.66)], fill=(214, 172, 80, 255), outline=(140, 100, 30, 255))
    d.ellipse((c - Wb * 0.07, Hb * 0.42, c + Wb * 0.07, Hb * 0.72), fill=(245, 214, 130, 255), outline=(140, 100, 30, 255))
    return out


def main():
    save("PackCrate", make_crate(), 256, 512)
    save("PackChains", make_chains(), 256, 512)
    save("PackLock", make_lock(), 64, 64)
    save("PackRibbon", make_ribbon(), 256, 512)
    save("PackBow", make_bow(), 128, 64)


if __name__ == "__main__":
    main()
