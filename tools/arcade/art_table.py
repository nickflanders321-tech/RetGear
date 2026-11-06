#!/usr/bin/env python3
"""The Fireside tabletop for the Arena (Media/Arcade/Tabletop.tga) and the frames that sit on it
(MinionFrame, MinionTaunt, HeroFrame). Our own drawing: a carved walnut frame with brass fittings, a warm
leather playfield lit from above, inlaid rows for the minions, stone alcoves for the heroes, a beam with a
compass medallion between the two sides, and a shelf for decks, mana and the End Turn button.

The window is 1180 x 700 (ArcadeBattle.lua); everything is placed in its coordinates (y up from the bottom),
painted at 2x and squeezed into a 1024 x 512 texture that the game stretches back over the window.
Run:  python3 tools/arcade/art_table.py [preview]"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "Media", "Arcade")
PREVIEW = len(sys.argv) > 1 and sys.argv[1] == "preview"
W, H, K = 1180, 700, 2
CW, CH = W * K, H * K


def P(x, y):  # window coords -> canvas pixels
    return x * K, (H - y) * K


def noise(w, h, sx, sy, seed):
    rng = np.random.RandomState(seed)
    small = rng.rand(max(2, h // sy), max(2, w // sx)).astype(np.float32)
    return np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), dtype=np.float32) / 255.0


def mask(draw_fn):
    m = Image.new("L", (CW, CH), 0); draw_fn(ImageDraw.Draw(m)); return m


def paste(img, rgb_arr, m, alpha=1.0):
    a = (np.asarray(m, dtype=np.float32) / 255.0 * alpha)[..., None]
    base = np.asarray(img, dtype=np.float32)
    base[..., :3] = base[..., :3] * (1 - a) + rgb_arr * a
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGBA")


def shade(img, m, k, blur=0):
    """multiply the image by k inside the mask (k < 1 darkens, > 1 lightens)"""
    if blur: m = m.filter(ImageFilter.GaussianBlur(blur))
    a = (np.asarray(m, dtype=np.float32) / 255.0)[..., None]
    base = np.asarray(img, dtype=np.float32)
    base[..., :3] = base[..., :3] * (1 - a + a * k)
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGBA")


def wood(seed, base=(70, 42, 20), contrast=0.35):
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    g = noise(CW, CH, 220, 7, seed) * 0.6 + noise(CW, CH, 60, 3, seed + 1) * 0.4      # long grain along x
    rings = 0.5 + 0.5 * np.sin(xx / 37.0 + g * 9.0)
    v = 1 - contrast + contrast * (0.55 * g + 0.45 * rings)
    return np.stack([base[0] * v, base[1] * v, base[2] * v], -1)


def brass(w_px):
    """a brass gradient for strokes: returns colour"""
    return (214, 170, 88)


def bevel_ring(img, box, width, col_hi=(236, 196, 112), col_lo=(120, 82, 34), radius=None, ellipse=False):
    """a metal rim: light top-left, dark bottom-right"""
    def shape(d, b, fill):
        if ellipse: d.ellipse(b, fill=fill)
        else: d.rounded_rectangle(b, radius or 0, fill=fill)
    outer = mask(lambda d: shape(d, box, 255))
    inner = mask(lambda d: shape(d, (box[0] + width, box[1] + width, box[2] - width, box[3] - width), 255))
    rim = Image.fromarray(np.clip(np.asarray(outer, np.int16) - np.asarray(inner, np.int16), 0, 255).astype(np.uint8))
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    t = np.clip(0.5 - ((xx - cx) / max(1, box[2] - box[0]) + (yy - cy) / max(1, box[3] - box[1])) * 0.9, 0, 1)[..., None]
    col = np.array(col_lo, np.float32) * (1 - t) + np.array(col_hi, np.float32) * t
    return paste(img, col, rim)


def make_tabletop():
    img = Image.new("RGBA", (CW, CH), (0, 0, 0, 255))
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    # 1. the whole board is carved walnut
    img = paste(img, wood(3), Image.new("L", (CW, CH), 255))
    # 2. the playfield: warm leather, lit from above, darker to the edges
    fx0, fx1, fy0, fy1 = 26, 982, 22, 678
    fb = (fx0 * K, (H - fy1) * K, fx1 * K, (H - fy0) * K)
    field = mask(lambda d: d.rounded_rectangle(fb, 26 * K, fill=255))
    n = noise(CW, CH, 90, 90, 11) * 0.5 + noise(CW, CH, 26, 26, 12) * 0.3 + noise(CW, CH, 7, 7, 13) * 0.2
    leather = np.stack([150 + 46 * n, 112 + 34 * n, 68 + 22 * n], -1)
    cxp, cyp = P(560, 380)
    light = np.clip(1 - np.sqrt(((xx - cxp) / (CW * 0.48)) ** 2 + ((yy - cyp) / (CH * 0.62)) ** 2), 0, 1)
    leather *= (0.72 + 0.4 * light)[..., None]
    img = paste(img, leather, field)
    # the far side is a touch cooler and darker
    foe = mask(lambda d: d.rounded_rectangle((fb[0], fb[1], fb[2], (H - 378) * K), 26 * K, fill=255))
    img = shade(img, foe, 0.86)
    # inner shadow along the field's edge
    edge = Image.fromarray(np.clip(np.asarray(field, np.int16) - np.asarray(field.filter(ImageFilter.MinFilter(41)), np.int16), 0, 255).astype(np.uint8))
    img = shade(img, edge, 0.55, blur=18)
    img = bevel_ring(img, (fb[0] - 8, fb[1] - 8, fb[2] + 8, fb[3] + 8), 7 * K, radius=30 * K)
    # a tooled line around the field, inside the brass
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle((fb[0] + 16 * K, fb[1] + 16 * K, fb[2] - 16 * K, fb[3] - 16 * K), 18 * K, outline=(92, 62, 30, 110), width=K)
    d.rounded_rectangle((fb[0] + 19 * K, fb[1] + 19 * K, fb[2] - 19 * K, fb[3] - 19 * K), 16 * K, outline=(236, 206, 150, 50), width=K)
    # 3. inlaid rows where the minions stand: a shallow recess with a stitched border
    for cy in (318, 438):
        b = (270 * K, (H - cy - 48) * K, 930 * K, (H - cy + 48) * K)
        row = mask(lambda d: d.rounded_rectangle(b, 22 * K, fill=255))
        img = shade(img, row, 0.82)
        rim = Image.fromarray(np.clip(np.asarray(row, np.int16) - np.asarray(row.filter(ImageFilter.MinFilter(13)), np.int16), 0, 255).astype(np.uint8))
        img = shade(img, rim, 0.6, blur=4)
        d = ImageDraw.Draw(img, "RGBA")
        inner = (b[0] + 12 * K, b[1] + 12 * K, b[2] - 12 * K, b[3] - 12 * K)
        x = inner[0] + 10 * K
        while x < inner[2] - 10 * K:   # stitches
            d.line([(x, inner[1]), (x + 9 * K, inner[1])], fill=(232, 204, 150, 80), width=K)
            d.line([(x, inner[3]), (x + 9 * K, inner[3])], fill=(232, 204, 150, 80), width=K)
            x += 18 * K
    # 4. the beam between the sides, with brass rivets and a compass medallion in the middle
    by = (H - 378) * K
    beam = mask(lambda d: d.rectangle((fb[0], by - 9 * K, fb[2], by + 9 * K), fill=255))
    img = paste(img, wood(21, base=(88, 54, 26), contrast=0.4), beam)
    img = shade(img, mask(lambda d: d.rectangle((fb[0], by + 9 * K, fb[2], by + 16 * K), fill=255)), 0.6, blur=6)
    d = ImageDraw.Draw(img, "RGBA")
    d.line([(fb[0], by - 9 * K), (fb[2], by - 9 * K)], fill=(220, 178, 96, 255), width=2 * K)
    d.line([(fb[0], by + 9 * K), (fb[2], by + 9 * K)], fill=(110, 72, 30, 255), width=2 * K)
    for x in range(int(fb[0] + 40 * K), int(fb[2] - 30 * K), 90 * K):
        d.ellipse((x - 4 * K, by - 4 * K, x + 4 * K, by + 4 * K), fill=(226, 186, 104, 255), outline=(96, 62, 24, 255), width=K)
    mx, my = 600 * K, by
    r = 34 * K
    img = bevel_ring(img, (mx - r, my - r, mx + r, my + r), 6 * K, ellipse=True)
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse((mx - r + 6 * K, my - r + 6 * K, mx + r - 6 * K, my + r - 6 * K), fill=(62, 40, 20, 255))
    for k in range(16):   # compass rose
        a = k * math.pi / 8
        ln = (r - 12 * K) if k % 4 == 0 else (r - 20 * K) if k % 2 == 0 else (r - 24 * K)
        wv = 5 * K if k % 4 == 0 else 3 * K
        tip = (mx + math.sin(a) * ln, my - math.cos(a) * ln)
        l = (mx + math.sin(a - math.pi / 2) * wv, my - math.cos(a - math.pi / 2) * wv)
        rr = (mx + math.sin(a + math.pi / 2) * wv, my - math.cos(a + math.pi / 2) * wv)
        d.polygon([tip, l, (mx, my), rr], fill=(226, 186, 104, 255) if k % 4 == 0 else (168, 128, 62, 255))
    d.ellipse((mx - 4 * K, my - 4 * K, mx + 4 * K, my + 4 * K), fill=(250, 220, 150, 255))
    # 5. stone alcoves for the heroes and sockets for the hero power and weapon
    def alcove(x, y, rad):
        cxp, cyp = P(x, y)
        box = (cxp - rad * K, cyp - rad * K, cxp + rad * K, cyp + rad * K)
        nonlocal img
        disk = mask(lambda dd: dd.ellipse(box, fill=255))
        st = noise(CW, CH, 60, 60, int(x + y)) * 0.6 + noise(CW, CH, 22, 22, int(x + y) + 1) * 0.4
        stone = np.stack([118 + 30 * st, 104 + 26 * st, 86 + 20 * st], -1)
        img = shade(img, mask(lambda dd: dd.ellipse((box[0] - 6 * K, box[1] + 2 * K, box[2] + 6 * K, box[3] + 12 * K), fill=255)), 0.55, blur=10)
        img = paste(img, stone, disk)
        img = bevel_ring(img, box, 5 * K, ellipse=True)
        inner = (box[0] + 12 * K, box[1] + 12 * K, box[2] - 12 * K, box[3] - 12 * K)
        img = shade(img, mask(lambda dd: dd.ellipse(inner, fill=255)), 0.5, blur=8)
    for (x, y) in ((600, 218), (600, 592)): alcove(x, y, 64)
    for (x, y) in ((696, 204), (504, 204), (696, 604), (504, 604)): alcove(x, y, 34)
    # 6. the shelf on the right: decks, mana trays and a brass plate for End Turn
    sx0 = 994
    shelf = mask(lambda dd: dd.rounded_rectangle((sx0 * K, 22 * K, (W - 22) * K, (H - 22) * K), 18 * K, fill=255))
    img = shade(img, shelf, 0.72)
    img = bevel_ring(img, (sx0 * K, 22 * K, (W - 22) * K, (H - 22) * K), 3 * K, radius=18 * K, col_hi=(170, 128, 62), col_lo=(70, 44, 18))
    for (y0, y1) in ((124, 186), (562, 624)):   # mana trays
        b = ((sx0 + 8) * K, (H - y1) * K, (W - 30) * K, (H - y0) * K)
        img = shade(img, mask(lambda dd: dd.rounded_rectangle(b, 12 * K, fill=255)), 0.55)
        img = bevel_ring(img, b, 2 * K, radius=12 * K, col_hi=(150, 110, 54), col_lo=(60, 38, 16))
    for (x, y) in ((1065, 108), (1065, 548)):  # deck alcoves
        cxp, cyp = P(x, y)
        b = (cxp - 40 * K, cyp - 30 * K, cxp + 40 * K, cyp + 30 * K)
        img = shade(img, mask(lambda dd: dd.rounded_rectangle(b, 10 * K, fill=255)), 0.75, blur=4)
    cxp, cyp = P(1065, 378)
    b = (cxp - 98 * K, cyp - 32 * K, cxp + 98 * K, cyp + 32 * K)
    img = shade(img, mask(lambda dd: dd.rounded_rectangle(b, 32 * K, fill=255)), 0.5, blur=3)
    img = bevel_ring(img, b, 5 * K, radius=32 * K)
    # 7. brass corner fittings on the frame, and warm lantern light in the near corners
    d = ImageDraw.Draw(img, "RGBA")
    for (cx0, cy0, sxs, sys_) in ((0, 0, 1, 1), (CW, 0, -1, 1), (0, CH, 1, -1), (CW, CH, -1, -1)):
        pts = [(cx0, cy0), (cx0 + sxs * 70 * K, cy0), (cx0 + sxs * 70 * K, cy0 + sys_ * 14 * K), (cx0 + sxs * 14 * K, cy0 + sys_ * 14 * K),
               (cx0 + sxs * 14 * K, cy0 + sys_ * 70 * K), (cx0, cy0 + sys_ * 70 * K)]
        d.polygon(pts, fill=(196, 152, 76, 255), outline=(92, 60, 22, 255))
        for (ox, oy) in ((40, 7), (7, 40)):
            x, y = cx0 + sxs * ox * K, cy0 + sys_ * oy * K
            d.ellipse((x - 3 * K, y - 3 * K, x + 3 * K, y + 3 * K), fill=(246, 214, 140, 255))
    glow = np.zeros((CH, CW), np.float32)
    for (x, y) in ((70, 70), (920, 70), (70, 630), (920, 630)):
        cxp, cyp = P(x, y)
        glow += np.clip(1 - np.sqrt((xx - cxp) ** 2 + (yy - cyp) ** 2) / (180 * K), 0, 1) ** 2
    arr = np.asarray(img, dtype=np.float32)
    arr[..., 0] += glow * 46; arr[..., 1] += glow * 26; arr[..., 2] += glow * 6
    # whole-board vignette
    vg = 1 - 0.35 * np.clip(np.sqrt(((xx - CW / 2) / (CW / 2)) ** 2 + ((yy - CH / 2) / (CH / 2)) ** 2) - 0.55, 0, 1)
    arr[..., :3] *= vg[..., None]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    if PREVIEW: img.resize((W, H), Image.LANCZOS).save("/tmp/tabletop_preview.png")
    out = img.resize((1024, 512), Image.LANCZOS)
    out.save(os.path.join(OUT, "Tabletop.tga"), compression=None)
    print("wrote Tabletop", out.size)


def frame_texture(name, shape):
    """128x128 frames: light stone (tinted per side in game) around a see-through window"""
    S = 512
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    outer = Image.new("L", (S, S), 0); inner = Image.new("L", (S, S), 0)
    do, di = ImageDraw.Draw(outer), ImageDraw.Draw(inner)
    if shape == "hero":
        do.ellipse((8, 8, S - 8, S - 8), fill=255); di.ellipse((86, 86, S - 86, S - 86), fill=255)
    elif shape == "taunt":
        do.polygon([(256, 2), (S - 6, 62), (S - 6, 420), (256, S - 2), (6, 420), (6, 62)], fill=255)
        di.ellipse((96, 66, S - 96, 330), fill=255); di.rectangle((96, 198, S - 96, 352), fill=255)
        di.polygon([(96, 352), (S - 96, 352), (256, 430)], fill=255)
    else:   # an arch
        do.ellipse((10, 6, S - 10, 498), fill=255); do.rounded_rectangle((10, 252, S - 10, S - 10), 56, fill=255)
        di.ellipse((78, 66, S - 78, 386), fill=255); di.rectangle((78, 226, S - 78, 440), fill=255)
    if shape != "hero":
        di_arr = np.asarray(inner).copy(); di_arr[441:, :] = 0; inner = Image.fromarray(di_arr)
    ring = np.clip(np.asarray(outer, np.int16) - np.asarray(inner, np.int16), 0, 255).astype(np.float32) / 255
    n = noise(S, S, 20, 20, 5) * 0.5 + noise(S, S, 6, 6, 6) * 0.5
    g = 0.62 + 0.3 * n - 0.25 * ((xx + yy) / (2 * S) - 0.5)   # light from the top left
    # bevel on both edges
    o_e = np.asarray(Image.fromarray(np.asarray(outer)).filter(ImageFilter.MinFilter(15)), np.float32) / 255
    i_e = np.asarray(Image.fromarray(np.asarray(inner)).filter(ImageFilter.MaxFilter(15)), np.float32) / 255
    g = g + 0.22 * (1 - o_e) * (1 - (xx + yy) / (2 * S)) - 0.25 * i_e * (1 - (xx + yy) / (2 * S)) + 0.15 * (i_e) * ((xx + yy) / (2 * S))
    g = np.clip(g, 0.15, 1.05)
    col = np.stack([235 * g, 222 * g, 196 * g], -1)
    a = np.asarray(Image.fromarray((ring * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32)
    # a thin dark line where the stone meets the picture
    line = np.clip(i_e - np.asarray(inner, np.float32) / 255, 0, 1) * (ring > 0)
    col *= (1 - 0.6 * line[..., None])
    img = Image.fromarray(np.dstack([np.clip(col, 0, 255), a]).astype(np.uint8), "RGBA").resize((128, 128), Image.LANCZOS)
    # the mask that keeps the square portrait inside the frame's outline (white = shown)
    mk = Image.fromarray(np.asarray(outer)).filter(ImageFilter.MinFilter(9)).resize((128, 128), Image.LANCZOS)
    Image.merge("RGBA", (mk, mk, mk, mk)).save(os.path.join(OUT, name + "Mask.tga"), compression=None)
    img.save(os.path.join(OUT, name + ".tga"), compression=None)
    if PREVIEW:
        bg = Image.new("RGBA", (128, 128), (150, 110, 70, 255)); bg.alpha_composite(img); bg.resize((256, 256)).save("/tmp/%s.png" % name)
    print("wrote", name)


if __name__ == "__main__":
    make_tabletop()
    frame_texture("MinionFrame", "arch")
    frame_texture("MinionTaunt", "taunt")
    frame_texture("HeroFrame", "hero")
