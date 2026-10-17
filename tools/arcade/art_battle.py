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
    # structure: lanes inlaid in the table, a halo under each hero, a plaque on the divide and a plate for each side's
    # mana and deck (positions follow ArcadeBattle.lua; the texture is stretched 1.15 x 1.37 on screen, so rings are ellipses here)
    K = 2
    ov = Image.new("RGBA", (w * K, h * K), (0, 0, 0, 0)); od = ImageDraw.Draw(ov, "RGBA")
    def R(x0, y0, x1, y1): return [x0 * K, y0 * K, x1 * K, y1 * K]
    gold = (214, 178, 100)
    for (y0, y1) in ((cy - 87, cy - 5), (cy + 5, cy + 88)):
        od.rounded_rectangle(R(214, y0, 832, y1), 16 * K, fill=(40, 26, 58, 120), outline=gold + (110,), width=2 * K)
        od.rounded_rectangle(R(220, y0 + 5, 826, y1 - 5), 12 * K, outline=gold + (45,), width=1 * K)
    # plates for mana and deck on the right
    for (y0, y1) in ((354, 446), (34, 126)):
        od.rounded_rectangle(R(842, y0, 1012, y1), 12 * K, fill=(22, 14, 40, 190), outline=gold + (150,), width=2 * K)
        od.rounded_rectangle(R(847, y0 + 5, 1007, y1 - 5), 9 * K, outline=gold + (50,), width=1 * K)
    # halos under the heroes
    for (hx, hy) in ((523, 361), (523, 79)):
        for rr, al, wd in ((72, 40, 1), (66, 150, 2), (60, 70, 1)):
            od.ellipse(R(hx - rr * 1.0, hy - rr * 0.84, hx + rr * 1.0, hy + rr * 0.84), outline=gold + (al,), width=wd * K)
        od.ellipse(R(hx - 58, hy - 49, hx + 58, hy + 49), fill=(12, 8, 26, 200))
        for sx in (-1, 1):
            px, py = hx + sx * 72, hy
            od.polygon([(px * K, (py - 7) * K), ((px + 6) * K, py * K), (px * K, (py + 7) * K), ((px - 6) * K, py * K)], fill=gold + (230,), outline=(40, 24, 8, 255))
    ov = ov.resize((w, h), Image.LANCZOS)
    img.alpha_composite(ov)
    d = ImageDraw.Draw(img, "RGBA")
    # the dividing line, broken by a plaque for the turn text
    for i in range(3):
        d.line([(60, cy + i - 1), (w - 60, cy + i - 1)], fill=(214, 178, 100, 150 - i * 40), width=1)
    pl = Image.new("RGBA", (w * K, h * K), (0, 0, 0, 0)); pd = ImageDraw.Draw(pl, "RGBA")
    pd.rounded_rectangle(R(w // 2 - 110, cy - 14, w // 2 + 110, cy + 14), 13 * K, fill=(16, 10, 32, 255), outline=gold + (240,), width=2 * K)
    pd.rounded_rectangle(R(w // 2 - 105, cy - 9, w // 2 + 105, cy + 9), 9 * K, outline=gold + (70,), width=1 * K)
    for sx in (-1, 1):
        px = w // 2 + sx * 122
        pd.polygon([(px * K, (cy - 8) * K), ((px + 8) * K, cy * K), (px * K, (cy + 8) * K), ((px - 8) * K, cy * K)], fill=gold + (240,), outline=(40, 24, 8, 255))
    img.alpha_composite(pl.resize((w, h), Image.LANCZOS))
    d = ImageDraw.Draw(img, "RGBA")
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


def make_backs():
    """Four more card backs (Back2..Back5) by recolouring the original: crimson, emerald, azure and gilt."""
    src = Image.open(os.path.join(art.OUT, "Back.tga")).convert("RGBA")
    a = np.asarray(src).astype(np.float32)
    rgb, al = a[..., :3], a[..., 3:]
    lum = rgb.mean(axis=2, keepdims=True)
    gold = (rgb[..., 0] - rgb[..., 2]) > 18   # warm pixels are the gold work (and its soft edge): keep them
    out = {}
    mixes = {"Back2": [2, 1, 0], "Back3": [1, 2, 0], "Back4": [1, 0, 2]}
    for name, order in mixes.items():
        c = rgb[..., order]
        c = np.where(gold[..., None], rgb, c)
        out[name] = Image.fromarray(np.dstack([np.clip(c, 0, 255), al]).astype(np.uint8), "RGBA")
    g = np.clip(lum * np.array([1.22, 1.0, 0.62]) * 1.1, 0, 255)
    g = np.where(gold[..., None], rgb, g)
    out["Back5"] = Image.fromarray(np.dstack([g, al]).astype(np.uint8), "RGBA")
    for name, im in out.items():
        save(name, im, 256, 512)


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
    if len(sys.argv) > 1 and sys.argv[1] == "only":
        save("Board", make_board(), 1024, 512); make_backs()
    else:
        main()
