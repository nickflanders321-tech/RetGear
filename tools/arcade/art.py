#!/usr/bin/env python3
"""Draws the card-game textures (Media/Arcade/*.tga) for Waypath+'s hidden card game.
Everything is drawn here with Pillow + numpy, so the art ships without any outside files.
Run:  python3 tools/arcade/art.py  [preview]   ('preview' also writes PNGs to /tmp/arcade_preview)
Textures are 32-bit uncompressed TGA, power-of-two sizes. Cards are drawn on a 256x358 area
inside a 256x512 texture (use TexCoord 0..1, 0..358/512)."""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "Media", "Arcade")
PREV = "/tmp/arcade_preview"
os.makedirs(OUT, exist_ok=True)
PREVIEW = len(sys.argv) > 1 and sys.argv[1] == "preview"
if PREVIEW: os.makedirs(PREV, exist_ok=True)
FONT = os.path.join(os.path.dirname(__file__), "..", "..", "Media", "Fonts", "Cinzel-ExtraBold.ttf")

S = 2                      # supersampling
CW, CH = 256 * S, 358 * S  # card area at supersampled size
TW, TH = 256 * S, 512 * S  # texture at supersampled size


def save(name, img, w, h):
    """img: RGBA PIL image at any size; downsample to (w, h) and write as TGA."""
    im = img.resize((w, h), Image.LANCZOS) if img.size != (w, h) else img
    im.save(os.path.join(OUT, name + ".tga"), compression=None)
    if PREVIEW:
        bg = Image.new("RGBA", im.size, (40, 40, 52, 255)); bg.alpha_composite(im); bg.save(os.path.join(PREV, name + ".png"))
    print("wrote", name, im.size)


def canvas(w, h, rgba=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), rgba)


def mask_rrect(w, h, box, r):
    m = Image.new("L", (w, h), 0); ImageDraw.Draw(m).rounded_rectangle(box, r, fill=255); return m


def mask_poly(w, h, pts):
    m = Image.new("L", (w, h), 0); ImageDraw.Draw(m).polygon(pts, fill=255); return m


def chamfer(x0, y0, x1, y1, c):
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def sub(a, b):
    return Image.fromarray(np.clip(np.asarray(a, dtype=np.int16) - np.asarray(b, dtype=np.int16), 0, 255).astype(np.uint8))


def shift(m, dx, dy):
    return Image.fromarray(np.roll(np.roll(np.asarray(m), dy, 0), dx, 1))


def metal(w, h, mask, base=(205, 205, 210), warm=0.0, contrast=1.0):
    """A bevelled metal fill inside mask. Greyscale-ish so it can be tinted in game."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = (xx / w * 0.65 + yy / h * 0.35)
    g = 0.62 + 0.30 * np.cos(t * 9.0) * contrast + 0.10 * np.cos(t * 23.0 + 1.0)
    g = np.clip(g, 0.25, 1.0)
    col = np.stack([g * base[0] * (1 + warm), g * base[1], g * base[2] * (1 - warm)], -1)
    img = np.dstack([np.clip(col, 0, 255), np.full((h, w), 255.0)]).astype(np.uint8)
    im = Image.fromarray(img, "RGBA")
    # bevel: light edge on top-left, dark on bottom-right
    hi = sub(mask, shift(mask, S * 1, S * 1)).filter(ImageFilter.GaussianBlur(0.6 * S))
    lo = sub(mask, shift(mask, -S * 1, -S * 1)).filter(ImageFilter.GaussianBlur(0.6 * S))
    arr = np.asarray(im).astype(np.float32)
    hv = np.asarray(hi, dtype=np.float32)[..., None] / 255.0
    lv = np.asarray(lo, dtype=np.float32)[..., None] / 255.0
    arr[..., :3] = arr[..., :3] * (1 - lv * 0.55) + 255 * hv * 0.6
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    out = canvas(w, h); out.paste(im, (0, 0), mask)
    # crisp dark outline
    ol = sub(mask.filter(ImageFilter.MaxFilter(3)), mask)
    dark = Image.new("RGBA", (w, h), (10, 8, 14, 255)); out.paste(dark, (0, 0), ol)
    return out


def inset_dark(w, h, pts, alpha=235, col=(16, 12, 28)):
    m = mask_poly(w, h, pts)
    layer = Image.new("RGBA", (w, h), col + (alpha,))
    out = canvas(w, h); out.paste(layer, (0, 0), m)
    # inner glow line
    edge = sub(m, m.filter(ImageFilter.MinFilter(3 * S // 2 * 2 + 1)))
    line = Image.new("RGBA", (w, h), (255, 255, 255, 70)); out.paste(line, (0, 0), edge)
    return out


def radial(w, h, cx, cy, r, power=2.0):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    return np.clip(1 - d, 0, 1) ** power


def noise(w, h, scale, seed=1):
    rng = np.random.RandomState(seed)
    small = rng.rand(max(2, h // scale), max(2, w // scale)).astype(np.float32)
    im = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im, dtype=np.float32) / 255.0


def font(size):
    try: return ImageFont.truetype(FONT, size)
    except Exception: return ImageFont.load_default()


# ----------------------------------------------------------------------------------------------
# rune and sigil drawing
# ----------------------------------------------------------------------------------------------
def rune_glyph(d, cx, cy, size, ang, rng, fill, width):
    """a small angular rune: a vertical staff with a few strokes"""
    ca, sa = math.cos(ang), math.sin(ang)
    def P(x, y): return (cx + (x * ca - y * sa) * size, cy + (x * sa + y * ca) * size)
    d.line([P(0, -1), P(0, 1)], fill=fill, width=width)
    for _ in range(rng.randint(1, 3)):
        y0 = rng.uniform(-1, 0.6); dx = rng.choice((-1, 1)) * rng.uniform(0.4, 0.9); dy = rng.uniform(0.3, 0.9) * rng.choice((-1, 1))
        d.line([P(0, y0), P(dx, y0 + dy)], fill=fill, width=width)
    if rng.random() < 0.35:
        y0 = rng.uniform(-0.6, 0.6); d.line([P(-0.5, y0), P(0.5, y0 + rng.uniform(-0.3, 0.3))], fill=fill, width=width)


def circle(d, cx, cy, r, fill, width):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=fill, width=width)


def star_poly(cx, cy, r, n, step):
    """{n/step} star polygon points order"""
    pts = [(cx + r * math.sin(2 * math.pi * k / n), cy - r * math.cos(2 * math.pi * k / n)) for k in range(n)]
    order, k = [], 0
    for _ in range(n): order.append(pts[k % n]); k += step
    return order


def sigil(size, col=(255, 255, 255), seed=7, rings=True, glyphs=True, fine=1.0):
    """white-on-transparent magic circle: rings, rune ring, octagram, ticks"""
    im = canvas(size, size); d = ImageDraw.Draw(im)
    c = size / 2; rng = random.Random(seed)
    A = lambda a: col + (a,)
    w1 = max(1, int(size / 170 * fine)); w2 = max(1, int(size / 90 * fine))
    circle(d, c, c, c * 0.97, A(255), w2)
    circle(d, c, c, c * 0.93, A(200), w1)
    circle(d, c, c, c * 0.66, A(220), w1)
    circle(d, c, c, c * 0.62, A(255), w2)
    circle(d, c, c, c * 0.40, A(220), w1)
    # rune ring between 0.66 and 0.93
    if glyphs:
        n = 28
        for k in range(n):
            a = 2 * math.pi * k / n
            rune_glyph(d, c + math.sin(a) * c * 0.795, c - math.cos(a) * c * 0.795, c * 0.055, a, rng, A(255), w1)
    # separators
    for k in range(14):
        a = 2 * math.pi * k / 14
        d.line([(c + math.sin(a) * c * 0.66, c - math.cos(a) * c * 0.66), (c + math.sin(a) * c * 0.93, c - math.cos(a) * c * 0.93)], fill=A(150), width=w1)
    # octagram and inner star
    d.line(star_poly(c, c, c * 0.62, 8, 3) + [star_poly(c, c, c * 0.62, 8, 3)[0]], fill=A(230), width=w1)
    d.line(star_poly(c, c, c * 0.40, 5, 2) + [star_poly(c, c, c * 0.40, 5, 2)[0]], fill=A(255), width=w2)
    # ticks on the outer edge
    for k in range(72):
        a = 2 * math.pi * k / 72; L = 0.03 if k % 6 else 0.055
        d.line([(c + math.sin(a) * c * 0.97, c - math.cos(a) * c * 0.97), (c + math.sin(a) * c * (0.97 - L), c - math.cos(a) * c * (0.97 - L))], fill=A(200), width=w1)
    return im


def d20(draw, cx, cy, r, line, fill=None, width=3):
    """a d20 seen face-on: hexagon with the inner triangle fan"""
    hexp = [(cx + r * math.sin(math.radians(60 * k)), cy - r * math.cos(math.radians(60 * k))) for k in range(6)]
    if fill: draw.polygon(hexp, fill=fill)
    draw.line(hexp + [hexp[0]], fill=line, width=width)
    ri = r * 0.5
    tri = [(cx + ri * math.sin(math.radians(60 * k + 30 * 0)), cy - ri * math.cos(math.radians(60 * k))) for k in (0, 2, 4)]
    tri = [(cx + ri * math.sin(math.radians(120 * k)), cy - ri * math.cos(math.radians(120 * k))) for k in range(3)]
    draw.line(tri + [tri[0]], fill=line, width=width)
    for k in range(3):
        a = hexp[2 * k]; b = tri[k]
        draw.line([a, b], fill=line, width=width)
        for j in (2 * k - 1, 2 * k + 1):
            draw.line([hexp[j % 6], b], fill=line, width=width)


# ----------------------------------------------------------------------------------------------
# card geometry (supersampled coordinates)
# ----------------------------------------------------------------------------------------------
def X(v): return int(v * S)
NAME = (X(13), X(10), X(243), X(40))
ART = (X(16), X(44), X(240), X(200))
TYPE = (X(13), X(204), X(243), X(225))
TEXT = (X(16), X(229), X(240), X(327))
POW = (X(168), X(306), X(246), X(346))


def card_shape(w=TW, h=TH):
    return mask_rrect(w, h, (0, 0, CW - 1, CH - 1), X(13))


def make_frame():
    w, h = TW, TH
    out = canvas(w, h)
    shape = card_shape()
    # outer border band
    inner = mask_rrect(w, h, (X(6), X(6), CW - 1 - X(6), CH - 1 - X(6)), X(8))
    band = sub(shape, inner)
    out.alpha_composite(metal(w, h, band))
    # dark keyline inside the band
    keyl = sub(inner, inner.filter(ImageFilter.MinFilter(S * 2 + 1)))
    out.paste(Image.new("RGBA", (w, h), (8, 6, 14, 230)), (0, 0), keyl)
    # art window: bevelled frame around the transparent hole
    ao = (ART[0] - X(4), ART[1] - X(4), ART[2] + X(4), ART[3] + X(4))
    awin = mask_rrect(w, h, ao, X(3))
    ahole = mask_rrect(w, h, ART, X(2))
    out.alpha_composite(metal(w, h, sub(awin, ahole), contrast=0.8))
    # inner shadow inside the hole so the art sits in the frame
    sh = np.asarray(ahole, dtype=np.float32) / 255.0
    blur = np.asarray(ahole.filter(ImageFilter.GaussianBlur(X(7))), dtype=np.float32) / 255.0
    shade = np.clip(sh - blur, 0, 1) * 1.6
    layer = np.zeros((h, w, 4), np.uint8); layer[..., 3] = np.clip(shade * 170, 0, 255).astype(np.uint8)
    out.alpha_composite(Image.fromarray(layer, "RGBA"))
    # name banner
    nb = (NAME[0] - X(3), NAME[1] - X(3), NAME[2] + X(3), NAME[3] + X(3))
    npoly = chamfer(*nb, X(7))
    out.alpha_composite(metal(w, h, mask_poly(w, h, npoly)))
    out.alpha_composite(inset_dark(w, h, chamfer(NAME[0] + X(5), NAME[1] + X(3), NAME[2] - X(5), NAME[3] - X(3), X(5)), 238))
    # type banner
    tb = (TYPE[0] - X(3), TYPE[1] - X(2), TYPE[2] + X(3), TYPE[3] + X(2))
    out.alpha_composite(metal(w, h, mask_poly(w, h, chamfer(*tb, X(6)))))
    out.alpha_composite(inset_dark(w, h, chamfer(TYPE[0] + X(4), TYPE[1] + X(1), TYPE[2] - X(4), TYPE[3] - X(1), X(4)), 238))
    # gem socket on the right of the type banner
    gx, gy = TYPE[2] - X(14), (TYPE[1] + TYPE[3]) // 2
    sock = Image.new("L", (w, h), 0); dd = ImageDraw.Draw(sock); dd.ellipse([gx - X(11), gy - X(11), gx + X(11), gy + X(11)], fill=255)
    hole = Image.new("L", (w, h), 0); ImageDraw.Draw(hole).ellipse([gx - X(8), gy - X(8), gx + X(8), gy + X(8)], fill=255)
    out.alpha_composite(metal(w, h, sub(sock, hole)))
    out.alpha_composite(Image.fromarray(np.dstack([np.full((h, w, 3), 10, np.uint8), (np.asarray(hole) * 0.9).astype(np.uint8)]), "RGBA"))
    # text box frame (hole stays transparent: the parchment shows through)
    to = (TEXT[0] - X(4), TEXT[1] - X(4), TEXT[2] + X(4), TEXT[3] + X(4))
    tw = mask_rrect(w, h, to, X(3)); th = mask_rrect(w, h, TEXT, X(2))
    out.alpha_composite(metal(w, h, sub(tw, th), contrast=0.7))
    # footer rule and corner studs
    for (cx, cy) in ((X(11), X(11)), (CW - X(12), X(11)), (X(11), CH - X(12)), (CW - X(12), CH - X(12))):
        m = Image.new("L", (w, h), 0); ImageDraw.Draw(m).ellipse([cx - X(4), cy - X(4), cx + X(4), cy + X(4)], fill=255)
        out.alpha_composite(metal(w, h, m))
    # power plate (a shield-ish hexagon over the text box corner)
    pp = [(POW[0] + X(10), POW[1]), (POW[2] - X(2), POW[1]), (POW[2] - X(2), POW[3] - X(8)), (POW[2] - X(12), POW[3]), (POW[0] + X(10), POW[3]), (POW[0], POW[1] + X(14))]
    out.alpha_composite(metal(w, h, mask_poly(w, h, pp)))
    pi = [(POW[0] + X(14), POW[1] + X(4)), (POW[2] - X(6), POW[1] + X(4)), (POW[2] - X(6), POW[3] - X(11)), (POW[2] - X(14), POW[3] - X(4)), (POW[0] + X(14), POW[3] - X(4)), (POW[0] + X(5), POW[1] + X(15))]
    out.alpha_composite(inset_dark(w, h, pi, 242))
    # clip to the card shape
    final = canvas(w, h); final.paste(out, (0, 0), shape)
    return final


def make_body():
    w, h = TW, TH
    shape = card_shape()
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # night-violet leather
    t = yy / CH
    base = np.stack([14 + 18 * t, 11 + 12 * t, 30 + 26 * t], -1)
    n = noise(w, h, 3, 2) * 10 - 5
    base += n[..., None]
    # a faint arcane glow behind the art window
    ag = radial(w, h, (ART[0] + ART[2]) / 2, (ART[1] + ART[3]) / 2, X(150), 1.6)
    base += ag[..., None] * np.array([34, 22, 60], np.float32)
    img = np.dstack([np.clip(base, 0, 255), np.full((h, w), 255.0)]).astype(np.uint8)
    im = Image.fromarray(img, "RGBA")
    # parchment text box
    pm = mask_rrect(w, h, TEXT, X(2))
    pa = np.stack([226 - 0 * yy, 210 - 0 * yy, 168 - 0 * yy], -1).astype(np.float32)
    fib = noise(w, h, 2, 5) * 22 + noise(w, h, 9, 6) * 26
    pa -= fib[..., None] * np.array([1.0, 1.1, 1.5], np.float32)
    edge = 1 - np.asarray(pm.filter(ImageFilter.GaussianBlur(X(10))), dtype=np.float32) / 255.0
    cx = (TEXT[0] + TEXT[2]) / 2; cy = (TEXT[1] + TEXT[3]) / 2
    vign = np.clip(radial(w, h, cx, cy, X(150), 1.2), 0, 1)
    pa *= (0.72 + 0.28 * vign[..., None])
    pa -= edge[..., None] * np.array([40, 52, 70], np.float32) * 0.4
    pimg = Image.fromarray(np.dstack([np.clip(pa, 0, 255), np.full((h, w), 255.0)]).astype(np.uint8), "RGBA")
    im.paste(pimg, (0, 0), pm)
    # the art window gets a deep inky base (the art and glow sit above it)
    am = mask_rrect(w, h, ART, X(2))
    ink = np.stack([8 + 10 * radial(w, h, (ART[0] + ART[2]) / 2, (ART[1] + ART[3]) / 2, X(130), 1.2)] * 3, -1)
    ink = np.stack([ink[..., 0] * 1.0, ink[..., 1] * 0.9, ink[..., 2] * 1.8], -1) + 6
    iimg = Image.fromarray(np.dstack([np.clip(ink, 0, 255), np.full((h, w), 255.0)]).astype(np.uint8), "RGBA")
    im.paste(iimg, (0, 0), am)
    out = canvas(w, h); out.paste(im, (0, 0), shape)
    return out


def make_back():
    w, h = TW, TH
    shape = card_shape()
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = CW / 2, CH / 2
    r = radial(w, h, cx, cy, CW * 0.8, 1.3)
    base = np.stack([10 + 30 * r, 8 + 18 * r, 28 + 62 * r], -1) + (noise(w, h, 3, 9) * 8)[..., None]
    img = Image.fromarray(np.dstack([np.clip(base, 0, 255), np.full((h, w), 255.0)]).astype(np.uint8), "RGBA")
    # lattice of diamonds
    d = ImageDraw.Draw(img, "RGBA"); step = X(26)
    for k in range(-20, 40):
        d.line([(k * step, 0), (k * step + CH, CH)], fill=(120, 100, 190, 26), width=1)
        d.line([(k * step, 0), (k * step - CH, CH)], fill=(120, 100, 190, 26), width=1)
    # the magic circle
    sg = sigil(int(CW * 0.9), (226, 188, 98), seed=11)
    img.alpha_composite(sg, (int(cx - sg.size[0] / 2), int(cy - sg.size[1] / 2)))
    # centre: d20
    # centre: the Waypath+ logo (our own mark, tools/art/logo.png)
    lg = Image.open(os.path.join(os.path.dirname(__file__), "..", "art", "logo.png")).convert("RGBA")
    lg = lg.crop(lg.getbbox()); ld = int(CW * 0.44)
    lg = lg.resize((ld, ld), Image.LANCZOS)
    img.alpha_composite(lg, (int(cx - ld / 2), int(cy - ld / 2)))
    # glow in the centre
    gl = radial(w, h, cx, cy, CW * 0.3, 2.0)
    glow = np.zeros((h, w, 4), np.uint8); glow[..., 0] = 255; glow[..., 1] = 200; glow[..., 2] = 120; glow[..., 3] = (gl * 70).astype(np.uint8)
    img.alpha_composite(Image.fromarray(glow, "RGBA"))
    # gold border and corner studs
    inner = mask_rrect(w, h, (X(7), X(7), CW - 1 - X(7), CH - 1 - X(7)), X(8))
    out = canvas(w, h); out.paste(img, (0, 0), inner)
    band = sub(shape, inner)
    gold = metal(w, h, band, base=(235, 196, 96), warm=0.15)
    out.alpha_composite(gold)
    inner2 = mask_rrect(w, h, (X(14), X(14), CW - 1 - X(14), CH - 1 - X(14)), X(5))
    line = sub(inner2, inner2.filter(ImageFilter.MinFilter(S + 1)))
    out.paste(Image.new("RGBA", (w, h), (226, 188, 98, 220)), (0, 0), line)
    for (px, py) in ((X(26), X(26)), (CW - X(26), X(26)), (X(26), CH - X(26)), (CW - X(26), CH - X(26))):
        dd = ImageDraw.Draw(out, "RGBA"); dd.polygon([(px, py - X(8)), (px + X(8), py), (px, py + X(8)), (px - X(8), py)], fill=(236, 198, 100, 255), outline=(30, 18, 40, 255))
    final = canvas(w, h); final.paste(out, (0, 0), shape)
    return final


def make_rune(size=256):
    s = size * S
    im = sigil(s, (255, 255, 255), seed=3, fine=1.2)
    return im


def make_rays(size=256):
    s = size * S
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    c = s / 2
    ang = np.arctan2(yy - c, xx - c)
    d = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c
    rays = (0.5 + 0.5 * np.cos(ang * 12)) ** 2.5
    rays2 = (0.5 + 0.5 * np.cos(ang * 5 + 0.7)) ** 3
    a = (0.7 * rays + 0.5 * rays2) * np.clip(1 - d, 0, 1) ** 0.8 * np.clip(d * 6, 0, 1)
    out = np.zeros((s, s, 4), np.uint8); out[..., :3] = 255; out[..., 3] = np.clip(a * 255, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def make_glow(size=128):
    s = size * S
    a = radial(s, s, s / 2, s / 2, s / 2, 2.2)
    out = np.zeros((s, s, 4), np.uint8); out[..., :3] = 255; out[..., 3] = np.clip(a * 255, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def make_foil(w=512, h=256):
    W, H = w * S, h * S
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = (xx + yy * 0.55) / (W / 1.0)
    # one soft rainbow band per 512 pixels, sliding across the card
    band = np.exp(-((t * 2 - 1.0) ** 2) * 14)
    hue = (t * 1.5) % 1.0
    r = 0.5 + 0.5 * np.sin(hue * 6.283)
    g = 0.5 + 0.5 * np.sin(hue * 6.283 + 2.09)
    b = 0.5 + 0.5 * np.sin(hue * 6.283 + 4.19)
    fine = 0.85 + 0.15 * np.sin((xx - yy) / (5 * S))
    a = np.clip(band * fine, 0, 1)
    out = np.zeros((H, W, 4), np.uint8)
    out[..., 0] = (r * 255); out[..., 1] = (g * 255); out[..., 2] = (b * 255); out[..., 3] = (a * 255)
    return Image.fromarray(out, "RGBA")


def make_night(size=512):
    s = size
    rng = np.random.RandomState(4)
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    n1 = noise(s, s, 96, 11); n2 = noise(s, s, 48, 12); n3 = noise(s, s, 24, 13)
    neb = n1 * 0.6 + n2 * 0.3 + n3 * 0.1
    base = np.stack([6 + 22 * neb, 5 + 10 * neb, 18 + 50 * neb], -1)
    teal = np.clip(noise(s, s, 80, 21) - 0.45, 0, 1) * 2
    base += teal[..., None] * np.array([0, 22, 26], np.float32)
    vg = 1 - 0.55 * np.clip(np.sqrt(((xx - s / 2) / (s / 2)) ** 2 + ((yy - s / 2) / (s / 2)) ** 2) - 0.35, 0, 1)
    base *= vg[..., None]
    img = Image.fromarray(np.dstack([np.clip(base, 0, 255), np.full((s, s), 255.0)]).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(420):
        x, y = rng.randint(0, s), rng.randint(0, s); b = rng.randint(70, 200); rr = rng.choice((0, 0, 0, 1))
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(b, b, min(255, b + 40), 255))
    for _ in range(14):
        x, y = rng.randint(8, s - 8), rng.randint(8, s - 8)
        d.line([(x - 3, y), (x + 3, y)], fill=(230, 230, 255, 70)); d.line([(x, y - 3), (x, y + 3)], fill=(230, 230, 255, 70))
        d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=(255, 255, 255, 255))
    return img


def make_corner(size=128):
    s = size * S
    im = canvas(s, s)
    m = Image.new("L", (s, s), 0); d = ImageDraw.Draw(m)
    t = int(s * 0.05)
    L = int(s * 0.85)
    d.rectangle([0, 0, L, t * 2], fill=255); d.rectangle([0, 0, t * 2, L], fill=255)           # main L
    d.rectangle([t * 3, t * 3, int(L * 0.66), t * 4], fill=255); d.rectangle([t * 3, t * 3, t * 4, int(L * 0.66)], fill=255)  # inner L
    d.polygon([(L, 0), (L + t * 4, t), (L, t * 2)], fill=255); d.polygon([(0, L), (t, L + t * 4), (t * 2, L)], fill=255)    # tips
    d.ellipse([t * 4, t * 4, t * 9, t * 9], fill=255)                                          # boss
    d.polygon([(0, 0), (t * 7, 0), (t * 7, t), (t, t * 7), (0, t * 7)], fill=255)
    for k in range(3):
        o = int(s * (0.28 + k * 0.17))
        d.ellipse([o, t * 0.4, o + t * 1.6, t * 2.0], fill=255); d.ellipse([t * 0.4, o, t * 2.0, o + t * 1.6], fill=255)
    gold = metal(s, s, m, base=(238, 200, 100), warm=0.15)
    return gold


def make_plate(w=512, h=64):
    W, H = w * S, h * S
    pts = [(0, H // 2), (H * 0.45, 0), (W - H * 0.45, 0), (W, H // 2), (W - H * 0.45, H - 1), (H * 0.45, H - 1)]
    outer = mask_poly(W, H, pts)
    inner = mask_poly(W, H, [(H * 0.22 + 6 * S, H // 2), (H * 0.5, 7 * S), (W - H * 0.5, 7 * S), (W - H * 0.22 - 6 * S, H // 2), (W - H * 0.5, H - 7 * S), (H * 0.5, H - 7 * S)])
    out = metal(W, H, sub(outer, inner), base=(238, 200, 100), warm=0.15)
    dark = np.zeros((H, W, 4), np.uint8); dark[..., :3] = (12, 10, 26); dark[..., 3] = np.asarray(inner)
    out.alpha_composite(Image.fromarray(dark, "RGBA"))
    d = ImageDraw.Draw(out, "RGBA")
    for sx in (H * 0.34, W - H * 0.34):
        d.polygon([(sx, H / 2 - 8 * S), (sx + 8 * S, H / 2), (sx, H / 2 + 8 * S), (sx - 8 * S, H / 2)], fill=(238, 200, 100, 255), outline=(30, 18, 40, 255))
    return out


def make_rule(w=256, h=16):
    W, H = w * S, h * S
    im = canvas(W, H); d = ImageDraw.Draw(im, "RGBA")
    gold = (226, 188, 98)
    for x in range(W):
        a = int(255 * max(0.0, 1 - abs(x - W / 2) / (W / 2)) ** 0.7)
        d.line([(x, H // 2), (x, H // 2)], fill=gold + (a,))
    d.polygon([(W / 2, H / 2 - 5 * S), (W / 2 + 5 * S, H / 2), (W / 2, H / 2 + 5 * S), (W / 2 - 5 * S, H / 2)], fill=gold + (255,))
    for dx in (-14, 14):
        d.polygon([(W / 2 + dx * S, H / 2 - 2 * S), (W / 2 + dx * S + 2 * S, H / 2), (W / 2 + dx * S, H / 2 + 2 * S), (W / 2 + dx * S - 2 * S, H / 2)], fill=gold + (255,))
    return im


def make_seal(size=128):
    s = size * S
    rng = np.random.RandomState(3)
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    c = s / 2
    ang = np.arctan2(yy - c, xx - c)
    wob = 1 + 0.045 * np.sin(ang * 5 + 1) + 0.03 * np.sin(ang * 9 + 2) + 0.02 * np.sin(ang * 13)
    d = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / (c * 0.86 * wob)
    m = np.clip((1 - d) * 24, 0, 1)
    shade = 1 - 0.45 * np.clip(d, 0, 1) ** 2 + 0.25 * np.clip(1 - np.sqrt((xx - c * 0.75) ** 2 + (yy - c * 0.7) ** 2) / (c * 0.5), 0, 1)
    rim = np.clip((d - 0.7) / 0.3, 0, 1)
    col = np.stack([168 * shade, 22 * shade, 34 * shade], -1)
    col -= rim[..., None] * np.array([40, 8, 10])
    img = Image.fromarray(np.dstack([np.clip(col, 0, 255), m * 255]).astype(np.uint8), "RGBA")
    dr = ImageDraw.Draw(img, "RGBA")
    dr.ellipse([c - c * 0.6, c - c * 0.6, c + c * 0.6, c + c * 0.6], outline=(110, 10, 22, 255), width=2 * S)
    d20(dr, c, c, c * 0.36, (96, 8, 20, 255), fill=(150, 18, 32, 255), width=2 * S)
    dr.text((c, c), "20", font=font(int(c * 0.34)), anchor="mm", fill=(255, 190, 170, 235))
    spec = radial(s, s, c * 0.7, c * 0.6, c * 0.25, 2.0)
    sp = np.zeros((s, s, 4), np.uint8); sp[..., :3] = 255; sp[..., 3] = (spec * 140 * m).astype(np.uint8)
    img.alpha_composite(Image.fromarray(sp, "RGBA"))
    return img


def make_gem(size=32):
    s = size * S
    im = canvas(s, s); d = ImageDraw.Draw(im, "RGBA"); c = s / 2
    top = [(c, 1), (s - 3, c * 0.8), (s - 3, c * 1.2), (c, s - 1), (3, c * 1.2), (3, c * 0.8)]
    d.polygon(top, fill=(190, 190, 190, 255), outline=(20, 16, 26, 255))
    d.polygon([(c, 1), (s - 3, c * 0.8), (c, c)], fill=(255, 255, 255, 255))
    d.polygon([(c, 1), (3, c * 0.8), (c, c)], fill=(225, 225, 225, 255))
    d.polygon([(c, c), (s - 3, c * 0.8), (s - 3, c * 1.2), (c, s - 1)], fill=(120, 120, 120, 255))
    d.polygon([(c, c), (3, c * 0.8), (3, c * 1.2), (c, s - 1)], fill=(160, 160, 160, 255))
    d.line(top + [top[0]], fill=(20, 16, 26, 255), width=S)
    return im


def make_slot():
    w, h = TW, TH
    shape = card_shape()
    base = np.zeros((h, w, 4), np.uint8); base[..., :3] = (12, 10, 22); base[..., 3] = 150
    im = Image.fromarray(base, "RGBA")
    d = ImageDraw.Draw(im, "RGBA")
    gold = (150, 125, 80, 130)
    box = (X(8), X(8), CW - X(9), CH - X(9))
    # dashed rounded outline
    for k in range(0, 360, 6):
        pass
    r = X(10)
    pts = []
    x0, y0, x1, y1 = box
    dash = X(8)
    for xs in range(x0 + r, x1 - r, dash * 2):
        d.line([(xs, y0), (min(xs + dash, x1 - r), y0)], fill=gold, width=S * 2); d.line([(xs, y1), (min(xs + dash, x1 - r), y1)], fill=gold, width=S * 2)
    for ys in range(y0 + r, y1 - r, dash * 2):
        d.line([(x0, ys), (x0, min(ys + dash, y1 - r))], fill=gold, width=S * 2); d.line([(x1, ys), (x1, min(ys + dash, y1 - r))], fill=gold, width=S * 2)
    for (cx, cy, a0) in ((x0 + r, y0 + r, 180), (x1 - r, y0 + r, 270), (x0 + r, y1 - r, 90), (x1 - r, y1 - r, 0)):
        d.arc([cx - r, cy - r, cx + r, cy + r], a0, a0 + 90, fill=gold, width=S * 2)
    sg = sigil(int(CW * 0.62), (150, 125, 80), seed=5, fine=0.8)
    a = np.asarray(sg).copy(); a[..., 3] = (a[..., 3] * 0.22).astype(np.uint8)
    im.alpha_composite(Image.fromarray(a, "RGBA"), (int(CW / 2 - sg.size[0] / 2), int(CH / 2 - sg.size[1] / 2)))
    out = canvas(w, h); out.paste(im, (0, 0), shape)
    return out


def main():
    save("Frame", make_frame(), 256, 512)
    save("Body", make_body(), 256, 512)
    save("Back", make_back(), 256, 512)
    save("Slot", make_slot(), 256, 512)
    save("Rune", make_rune(), 256, 256)
    save("Rays", make_rays(), 256, 256)
    save("Glow", make_glow(), 128, 128)
    save("Foil", make_foil(), 512, 256)
    save("Night", make_night(), 512, 512)
    save("Corner", make_corner(), 128, 128)
    save("Plate", make_plate(), 512, 64)
    save("Rule", make_rule(), 256, 16)
    save("Seal", make_seal(), 128, 128)
    save("Gem", make_gem(), 32, 32)


if __name__ == "__main__":
    main()
