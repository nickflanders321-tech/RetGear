#!/usr/bin/env python3
"""The "Gilded Codex" card look (Waypath+ 1.45): the pieces drawn over every ordinary card.
  Win1..4    the card's body around the picture window, cut to the card kind's shape (item: a cut gem, creature: an
             arch, place: a panorama, raider: a shield). Drawn ABOVE the picture, so 3D models get the shape too.
  Codex1..4  the metal: a band inside the card's edge and a rim round the window. Light grey: the game tints it by
             rarity (iron, bronze, silver, gold, bright gold, crimson).
  Crests     the kind's badge at the top of the card, one 64 px cell each (item, creature, place, raider).
  Ribbon     the name's parchment ribbon. Panel / Glass: the text's parchment (and a Full art print's smoked glass).
All drawn here; the cards' pictures stay the game's own (models, icons, map art).
Run: python3 tools/arcade/art_codex.py [preview]"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
import art
from art import S, X, TW, TH, CW, CH, canvas, mask_rrect, mask_poly, sub, shift, noise, save, card_shape, make_body

ART = art.ART
EDGE = art.EDGE


def window(kind, w=TW, h=TH):
    """the picture window's shape for a card kind (a white mask)"""
    x0, y0, x1, y1 = ART
    if kind == 1:   # item: a cut gem
        return mask_poly(w, h, art.chamfer(x0, y0, x1, y1, X(20)))
    if kind == 2:   # creature: an arch
        m = mask_rrect(w, h, (x0, y0 + X(52), x1, y1), X(6))
        ImageDraw.Draw(m).ellipse((x0, y0, x1, y0 + X(120)), fill=255)
        return m
    if kind == 4:   # raider: a shield
        ym = y0 + int((y1 - y0) * 0.72)
        return mask_poly(w, h, [(x0, y0), (x1, y0), (x1, ym), ((x0 + x1) // 2, y1), (x0, ym)])
    return mask_rrect(w, h, (x0, y0, x1, y1), X(4))   # place: a panorama


def make_win(kind):
    """the card's own body everywhere in the art box outside the window's shape"""
    body = make_body()
    box = mask_rrect(TW, TH, (ART[0] - X(1), ART[1] - X(1), ART[2] + X(1), ART[3] + X(1)), 0)
    cut = sub(box, window(kind))
    out = canvas(TW, TH); out.paste(body, (0, 0), cut)
    # a soft shadow falling into the window from the cover
    sh = cut.filter(ImageFilter.GaussianBlur(X(3)))
    shade = Image.new("RGBA", (TW, TH), (0, 0, 0, 150))
    m = Image.fromarray((np.asarray(sh, dtype=np.float32) * (np.asarray(window(kind), dtype=np.float32) / 255.0)).astype(np.uint8))
    out.paste(shade, (0, 0), m)
    return out


def make_codex(kind):
    """light-grey metal (tinted in game by rarity): a band inside the card's edge and the window's rim"""
    shape = card_shape()
    outer = mask_rrect(TW, TH, (EDGE + X(1), EDGE + X(1), CW - 1 - EDGE - X(1), CH - 1 - EDGE - X(1)), X(9))
    inner = mask_rrect(TW, TH, (EDGE + X(4), EDGE + X(4), CW - 1 - EDGE - X(4), CH - 1 - EDGE - X(4)), X(7))
    band = sub(outer, inner)
    win = window(kind)
    rim = sub(win.filter(ImageFilter.MaxFilter(X(3) * 2 + 1)), win)
    m = Image.fromarray(np.maximum(np.asarray(band), np.asarray(rim)))
    out = art.metal(TW, TH, m, base=(236, 236, 240), contrast=0.7)
    # a fine dark line inside the band, and a light one on the rim's outer side
    il = sub(inner.filter(ImageFilter.MaxFilter(S + 1)), inner)
    out.paste(Image.new("RGBA", (TW, TH), (8, 8, 14, 200)), (0, 0), il)
    return out


def glyph(d, kind, c, r, col):
    """the crest's picture: a sword, a paw, a peak, a shield"""
    if kind == 1:
        d.polygon([(c - r * 0.12, c - r * 0.95), (c + r * 0.12, c - r * 0.95), (c + r * 0.16, c + r * 0.35), (c, c + r * 0.55), (c - r * 0.16, c + r * 0.35)], fill=col)
        d.rectangle([c - r * 0.55, c + r * 0.32, c + r * 0.55, c + r * 0.48], fill=col)
        d.rectangle([c - r * 0.1, c + r * 0.48, c + r * 0.1, c + r * 0.85], fill=col)
    elif kind == 2:
        d.ellipse([c - r * 0.42, c - r * 0.05, c + r * 0.42, c + r * 0.7], fill=col)
        for dx, dy in ((-0.62, -0.32), (-0.24, -0.72), (0.24, -0.72), (0.62, -0.32)):
            d.ellipse([c + (dx - 0.2) * r, c + (dy - 0.2) * r, c + (dx + 0.2) * r, c + (dy + 0.2) * r], fill=col)
    elif kind == 3:
        d.polygon([(c - r * 0.9, c + r * 0.6), (c - r * 0.25, c - r * 0.55), (c + r * 0.1, c + r * 0.05), (c + r * 0.4, c - r * 0.3), (c + r * 0.9, c + r * 0.6)], fill=col)
    else:
        d.polygon([(c - r * 0.7, c - r * 0.75), (c + r * 0.7, c - r * 0.75), (c + r * 0.7, c + r * 0.1), (c, c + r * 0.85), (c - r * 0.7, c + r * 0.1)], fill=col)


CREST = {1: ((227, 162, 74), (42, 22, 6), (243, 196, 106)), 2: ((92, 199, 138), (11, 36, 22), (143, 224, 173)),
         3: ((90, 156, 240), (10, 26, 51), (156, 196, 255)), 4: ((176, 124, 240), (34, 16, 46), (214, 180, 255))}


def make_crests():
    cell = 64 * S
    out = canvas(cell * 4, cell)
    for k in (1, 2, 3, 4):
        ring, fill, ink = CREST[k]
        im = canvas(cell, cell); d = ImageDraw.Draw(im)
        c = cell / 2; r = cell * 0.46
        d.ellipse([c - r, c - r, c + r, c + r], fill=(0, 0, 0, 120))   # its shadow
        r = cell * 0.42
        d.ellipse([c - r, c - r, c + r, c + r], fill=ring + (255,))
        r2 = cell * 0.34
        d.ellipse([c - r2, c - r2, c + r2, c + r2], fill=fill + (255,))
        glyph(d, k, c, cell * 0.2, ink + (255,))
        # a light catch on the ring
        d.arc([c - r, c - r, c + r, c + r], 200, 300, fill=(255, 255, 255, 140), width=S * 2)
        out.paste(im, ((k - 1) * cell, 0))
    return out


def parchment(W, H, mask, top=(243, 229, 191), bottom=(216, 192, 138), seed=5):
    yy = np.mgrid[0:H, 0:W][0].astype(np.float32) / max(1, H - 1)
    col = np.array(top, np.float32) * (1 - yy[..., None]) + np.array(bottom, np.float32) * yy[..., None]
    col += (noise(W, H, 4, seed)[..., None] - 0.5) * 14 + (noise(W, H, 1, seed + 1)[..., None] - 0.5) * 8
    img = Image.fromarray(np.dstack([np.clip(col, 0, 255), np.full((H, W), 255.0)]).astype(np.uint8), "RGBA")
    out = canvas(W, H); out.paste(img, (0, 0), mask)
    return out


def make_ribbon(w=256, h=32):
    W, H = w * S, h * S
    t = X(10)   # the folded tails
    pts = [(0, X(2)), (W - 1, X(2)), (W - 1 - t, H // 2), (W - 1, H - 1 - X(3)), (0, H - 1 - X(3)), (t, H // 2)]
    m = mask_poly(W, H, pts)
    out = canvas(W, H)
    shd = shift(m, 0, X(2)).filter(ImageFilter.GaussianBlur(X(1.5)))
    out.paste(Image.new("RGBA", (W, H), (0, 0, 0, 160)), (0, 0), shd)
    out.alpha_composite(parchment(W, H, m))
    edge = sub(m, m.filter(ImageFilter.MinFilter(3)))
    out.paste(Image.new("RGBA", (W, H), (120, 84, 32, 200)), (0, 0), edge)
    # the folds where the tails tuck behind
    fold = mask_poly(W, H, [(t, H // 2), (t + X(6), X(2)), (t + X(6), H - 1 - X(3))])
    out.paste(Image.new("RGBA", (W, H), (120, 84, 32, 70)), (0, 0), fold)
    fold = mask_poly(W, H, [(W - 1 - t, H // 2), (W - 1 - t - X(6), X(2)), (W - 1 - t - X(6), H - 1 - X(3))])
    out.paste(Image.new("RGBA", (W, H), (120, 84, 32, 70)), (0, 0), fold)
    return out


def make_panel(w=256, h=128, glass=False):
    W, H = w * S, h * S
    m = mask_rrect(W, H, (X(1), X(1), W - 1 - X(1), H - 1 - X(1)), X(7))
    if glass:
        yy = np.mgrid[0:H, 0:W][0].astype(np.float32) / (H - 1)
        a = 120 + 110 * yy
        img = np.zeros((H, W, 4), np.uint8); img[..., 0] = 10; img[..., 1] = 10; img[..., 2] = 20; img[..., 3] = a.astype(np.uint8)
        out = canvas(W, H); out.paste(Image.fromarray(img, "RGBA"), (0, 0), m)
        top = sub(m, shift(m, 0, X(1)))
        out.paste(Image.new("RGBA", (W, H), (255, 255, 255, 70)), (0, 0), top)
        return out
    out = parchment(W, H, m, top=(239, 228, 198), bottom=(226, 210, 168), seed=9)
    edge = sub(m, m.filter(ImageFilter.MinFilter(3)))
    out.paste(Image.new("RGBA", (W, H), (106, 75, 34, 150)), (0, 0), edge)
    # a faint inner rule
    ins = mask_rrect(W, H, (X(4), X(4), W - 1 - X(4), H - 1 - X(4)), X(5))
    il = sub(ins, ins.filter(ImageFilter.MinFilter(3)))
    out.paste(Image.new("RGBA", (W, H), (106, 75, 34, 60)), (0, 0), il)
    return out


def back_frame(img, border):
    """a card back's shape, its metal border, an inner line and corner studs (as the original back)"""
    shape = card_shape()
    inner = mask_rrect(TW, TH, (X(7), X(7), CW - 1 - X(7), CH - 1 - X(7)), X(8))
    out = canvas(TW, TH); out.paste(img, (0, 0), inner)
    out.alpha_composite(art.metal(TW, TH, sub(shape, inner), base=border, warm=0.1))
    inner2 = mask_rrect(TW, TH, (X(14), X(14), CW - 1 - X(14), CH - 1 - X(14)), X(5))
    line = sub(inner2, inner2.filter(ImageFilter.MinFilter(S + 1)))
    out.paste(Image.new("RGBA", (TW, TH), border + (210,)), (0, 0), line)
    final = canvas(TW, TH); final.paste(out, (0, 0), shape)
    return final


def star4(d, cx, cy, r, fill, thin=0.18):
    d.polygon([(cx, cy - r), (cx + r * thin, cy - r * thin), (cx + r, cy), (cx + r * thin, cy + r * thin), (cx, cy + r), (cx - r * thin, cy + r * thin), (cx - r, cy), (cx - r * thin, cy - r * thin)], fill=fill)


def make_back_carto():
    """Cartographer: an old map, contour lines and a compass rose"""
    yy, xx = np.mgrid[0:TH, 0:TW].astype(np.float32)
    n = noise(TW, TH, 30, 21) * 0.6 + noise(TW, TH, 9, 22) * 0.4
    base = np.stack([62 + 40 * n, 74 + 44 * n, 46 + 26 * n], -1)
    img = Image.fromarray(np.dstack([np.clip(base, 0, 255), np.full((TH, TW), 255.0)]).astype(np.uint8), "RGBA")
    # contour lines where the noise crosses its levels
    lv = (n * 14) % 1.0
    lines = ((lv < 0.07) * 160).astype(np.uint8)
    img.paste(Image.new("RGBA", (TW, TH), (214, 190, 130, 255)), (0, 0), Image.fromarray(lines).filter(ImageFilter.GaussianBlur(0.6)))
    d = ImageDraw.Draw(img, "RGBA"); cx, cy = CW / 2, CH / 2
    for r in (X(64), X(58)): d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(232, 206, 140, 230), width=S * 2)
    star4(d, cx, cy, X(56), (236, 214, 150, 255), 0.16)
    star4(d, cx, cy, X(30), (120, 92, 46, 255), 0.22)
    d.polygon([(cx, cy - X(56)), (cx + X(9), cy - X(9)), (cx, cy)], fill=(255, 240, 200, 255))
    return back_frame(img, (196, 150, 90))


def make_back_ember():
    """Ember: dark red, a flame in the middle, embers drifting up"""
    yy, xx = np.mgrid[0:TH, 0:TW].astype(np.float32)
    r = art.radial(TW, TH, CW / 2, CH * 0.55, CW * 0.8, 1.3)
    base = np.stack([30 + 110 * r, 6 + 26 * r, 6 + 12 * r], -1) + (noise(TW, TH, 3, 31) * 10)[..., None]
    img = Image.fromarray(np.dstack([np.clip(base, 0, 255), np.full((TH, TW), 255.0)]).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img, "RGBA"); cx, cy = CW / 2, CH / 2 + X(10)
    def flame(sc, col):
        pts = [(cx, cy - X(80) * sc), (cx + X(30) * sc, cy - X(20) * sc), (cx + X(16) * sc, cy - X(34) * sc), (cx + X(46) * sc, cy + X(10) * sc),
               (cx + X(30) * sc, cy + X(54) * sc), (cx, cy + X(64) * sc), (cx - X(30) * sc, cy + X(54) * sc), (cx - X(46) * sc, cy + X(10) * sc),
               (cx - X(16) * sc, cy - X(34) * sc), (cx - X(30) * sc, cy - X(20) * sc)]
        d.polygon(pts, fill=col)
    flame(1.0, (240, 110, 40, 235)); flame(0.62, (255, 190, 90, 245)); flame(0.3, (255, 240, 190, 255))
    import random
    rng = random.Random(4)
    for _ in range(40):
        x, y, z = rng.uniform(X(20), CW - X(20)), rng.uniform(X(20), CH - X(20)), rng.uniform(1, 3) * S
        d.ellipse((x - z, y - z, x + z, y + z), fill=(255, 170, 80, rng.randint(90, 220)))
    return back_frame(img, (120, 116, 122))


def make_back_radiant():
    """Radiant: pale gold rays from a waypoint star"""
    yy, xx = np.mgrid[0:TH, 0:TW].astype(np.float32)
    cx, cy = CW / 2, CH / 2
    ang = np.arctan2(yy - cy, xx - cx)
    rays = (np.cos(ang * 16) * 0.5 + 0.5) ** 3
    r = art.radial(TW, TH, cx, cy, CW * 0.9, 1.1)
    base = np.stack([150 + 90 * r + 15 * rays, 112 + 90 * r + 12 * rays, 52 + 70 * r + 8 * rays], -1)
    img = Image.fromarray(np.dstack([np.clip(base, 0, 255), np.full((TH, TW), 255.0)]).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    star4(d, cx, cy, X(88), (255, 250, 232, 255), 0.14)
    star4(d, cx, cy, X(46), (255, 236, 180, 255), 0.2)
    for rr in (X(100), X(106)): d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=(255, 244, 210, 200), width=S * 2)
    return back_frame(img, (250, 220, 140))


def main():
    for k in (1, 2, 3, 4):
        save("Win%d" % k, make_win(k), 256, 512)
        save("Codex%d" % k, make_codex(k), 256, 512)
    save("Crests", make_crests(), 256, 64)
    save("Ribbon", make_ribbon(), 256, 32)
    save("Panel", make_panel(), 256, 128)
    save("Glass", make_panel(glass=True), 256, 128)
    save("Back6", make_back_carto(), 256, 512)
    save("Back7", make_back_ember(), 256, 512)
    save("Back8", make_back_radiant(), 256, 512)


if __name__ == "__main__":
    main()
