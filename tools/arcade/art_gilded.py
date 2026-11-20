"""Waypath+ Gilded print art (our own drawing): black lacquer, gold leaf, an engraved plate, gold flecks, corner
brackets and the gold card back. Output in Media/Arcade (card textures: 256x512, the card in the top 358 rows):
  GildedBody.tga          the card's body: black lacquer with a warm sheen
  GildedFrame1..4.tga     each kind's frame (Codex1..4) in hammered gold: same shapes, so the picture window fits exactly
  GildedEdge.tga          the gold double-line edge
  GildedCorner.tga        128x128, one corner bracket (top left; the add-on mirrors it for the others)
  GildedPlate.tga         512x96, the black name plate with its gold border
  GildedPanel.tga         512x160, the black glass text panel with its gold line
  GildedFlecks.tga        fine gold-leaf flecks (added over the card)
  GildedBack.tga          the gold card back a Gilded card flips from
Run: python3 tools/arcade/art_gilded.py
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "Media", "Arcade"))
W, H = 256, 358
S = 4   # supersample

def save(im, name):
    im.save(os.path.join(OUT, name + ".tga")); print("wrote", name, im.size)

def gold_field(w, h, seed=1):
    """hammered gold: a diagonal light-to-dark gradient with soft dents"""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    t = (x / w * 0.6 + y / h * 0.4)
    band = 0.5 + 0.5 * np.sin(t * 6.2 + 0.8)          # broad light bands across the metal
    rng = np.random.default_rng(seed)
    dents = np.zeros((h, w), np.float32)
    for _ in range(int(w * h / 900)):
        cx, cy, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(3, 9)
        d = ((x - cx) ** 2 + (y - cy) ** 2) / (r * r)
        dents += np.exp(-d) * rng.uniform(-0.12, 0.12)
    v = np.clip(0.55 + 0.45 * band + dents, 0, 1.2)
    dark = np.array([122, 79, 18], np.float32); mid = np.array([217, 166, 64], np.float32); hi = np.array([255, 243, 192], np.float32)
    v3 = v[..., None]
    rgb = np.where(v3 < 0.6, dark + (mid - dark) * (v3 / 0.6), mid + (hi - mid) * np.clip((v3 - 0.6) / 0.6, 0, 1))
    return np.clip(rgb, 0, 255)

def body():
    im = Image.new("RGBA", (256, 512), (0, 0, 0, 0))
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt(((x - W * 0.5) / (W * 0.62)) ** 2 + ((y - H * 0.32) / (H * 0.5)) ** 2)
    k = np.clip(1 - d, 0, 1)
    rgb = np.stack([11 + 31 * k, 8 + 21 * k, 5 + 6 * k], -1)
    a = np.full((H, W), 255, np.uint8)
    card = Image.fromarray(np.dstack([rgb.astype(np.uint8), a]), "RGBA")
    # rounded corners like the card's own body
    m = Image.new("L", (W * S, H * S), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, W * S - 1, H * S - 1], 10 * S, fill=255)
    card.putalpha(m.resize((W, H), Image.LANCZOS))
    im.paste(card, (0, 0))
    save(im, "GildedBody")

def frames():
    for k in range(1, 5):
        src = Image.open(os.path.join(OUT, "Codex%d.tga" % k)).convert("RGBA")
        a = np.asarray(src).astype(np.float32)
        lum = (a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11) / 255.0
        g = gold_field(src.width, src.height, seed=k)
        rgb = g * np.clip(0.35 + lum * 0.95, 0, 1.25)[..., None]
        out = np.dstack([np.clip(rgb, 0, 255), a[..., 3]]).astype(np.uint8)
        save(Image.fromarray(out, "RGBA"), "GildedFrame%d" % k)

def edge():
    big = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0)); d = ImageDraw.Draw(big)
    def rr(inset, width, col, r=10):
        d.rounded_rectangle([inset * S, inset * S, (W - inset) * S - 1, (H - inset) * S - 1], max(1, (r - inset * 0.6)) * S, outline=col, width=int(width * S))
    rr(0.5, 3.2, (217, 169, 62, 255))
    rr(1.2, 0.9, (255, 242, 192, 255))
    rr(3.6, 1.4, (107, 67, 12, 255))
    rr(5.0, 2.4, (217, 169, 62, 255))
    rr(6.6, 0.8, (255, 240, 184, 255))
    im = Image.new("RGBA", (256, 512)); im.paste(big.resize((W, H), Image.LANCZOS), (0, 0))
    save(im, "GildedEdge")

def corner():
    n = 128 * S; c = Image.new("RGBA", (n, n)); d = ImageDraw.Draw(c)
    def P(pts): return [(x / 60 * n, y / 60 * n) for x, y in pts]
    d.polygon(P([(2, 2), (50, 2), (44, 8), (22, 10), (15, 11), (11, 15), (10, 22), (8, 44), (2, 50)]), fill=(217, 166, 64, 255), outline=(90, 54, 8, 255))
    d.polygon(P([(2, 2), (36, 2), (31, 6), (18, 7), (11, 8), (8, 11), (7, 18), (6, 31), (2, 36)]), fill=(246, 215, 122, 255))
    w = int(1.0 / 60 * n)
    d.line(P([(12, 12), (26, 12)]), fill=(90, 54, 8, 255), width=w); d.line(P([(12, 12), (12, 26)]), fill=(90, 54, 8, 255), width=w)
    for seg in (((14, 6), (14, 4)), ((6, 14), (4, 14)), ((24, 6), (24, 4)), ((6, 24), (4, 24))):
        d.line(P(seg), fill=(122, 79, 18, 255), width=int(1.2 / 60 * n))
    d.polygon(P([(12, 7), (15, 10), (12, 13), (9, 10)]), fill=(255, 247, 214, 255), outline=(122, 79, 18, 255))
    sh = Image.new("RGBA", (n, n)); sh.paste((0, 0, 0, 150), mask=c.split()[3].filter(ImageFilter.GaussianBlur(1.5 * S)))
    out = Image.alpha_composite(sh.transform((n, n), Image.AFFINE, (1, 0, -1 * S, 0, 1, -2 * S)), c)
    save(out.resize((128, 128), Image.LANCZOS), "GildedCorner")

def plate(w, h, name, border=1.0):
    big = Image.new("RGBA", (w * S, h * S)); d = ImageDraw.Draw(big)
    r = 6 * S
    d.rounded_rectangle([0, 0, w * S - 1, h * S - 1], r, fill=(122, 79, 18, 255))
    d.rounded_rectangle([int(2 * S), int(2 * S), w * S - 1 - int(2 * S), h * S - 1 - int(2 * S)], r, fill=(233, 189, 82, 255))
    d.rounded_rectangle([int(4 * S), int(4 * S), w * S - 1 - int(4 * S), h * S - 1 - int(4 * S)], r, fill=(59, 38, 8, 255))
    d.rounded_rectangle([int(6 * S), int(6 * S), w * S - 1 - int(6 * S), h * S - 1 - int(6 * S)], r, fill=(18, 12, 6, 255))
    im = big.resize((w, h), Image.LANCZOS)
    # a soft sheen across the top of the black
    a = np.asarray(im).astype(np.float32)
    y = np.linspace(0, 1, h)[:, None]
    inner = (a[..., 0] < 40) & (a[..., 3] > 200)
    a[..., :3] += (inner[..., None] * (np.clip(0.35 - y, 0, 1) * 60)[..., None] * np.array([1, 0.8, 0.45]))
    save(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA"), name)

def flecks():
    rng = random.Random(5); im = Image.new("RGBA", (256, 512)); d = ImageDraw.Draw(im)
    n = 0
    while n < 300:
        x, y = rng.uniform(4, W - 4), rng.uniform(4, H - 4); r = rng.choice((0.5, 0.6, 0.8, 1.0, 1.3))
        # (few over the picture and the text, so they read as gold leaf on the lacquer, not noise on the art)
        inArt = 12 < x < 244 and 20 < y < 202
        inText = 14 < x < 242 and 258 < y < 324
        inPlate = 10 < x < 246 and 204 < y < 258
        if (inArt and rng.random() > 0.12) or (inText and rng.random() > 0.2) or inPlate: continue
        n += 1
        a = rng.randint(90, 230); col = rng.choice(((255, 226, 140), (255, 240, 190), (255, 200, 90)))
        d.ellipse([x - r, y - r, x + r, y + r], fill=col + (a,))
    save(im.filter(ImageFilter.GaussianBlur(0.25)), "GildedFlecks")

def back():
    big = Image.new("RGBA", (W * S, H * S)); d = ImageDraw.Draw(big)
    y, x = np.mgrid[0:H * S, 0:W * S].astype(np.float32)
    k = np.clip(1 - np.sqrt(((x - W * S / 2) / (W * S * 0.6)) ** 2 + ((y - H * S / 2) / (H * S * 0.55)) ** 2), 0, 1)
    rgb = np.stack([18 + 40 * k, 13 + 29 * k, 6 + 8 * k], -1).astype(np.uint8)
    m = Image.new("L", (W * S, H * S), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, W * S - 1, H * S - 1], 10 * S, fill=255)
    big = Image.fromarray(np.dstack([rgb, np.asarray(m)]), "RGBA"); d = ImageDraw.Draw(big)
    for inset, wd, col in ((2, 4, (217, 169, 62)), (6.5, 1.5, (59, 38, 8)), (8.5, 2, (243, 210, 122))):
        d.rounded_rectangle([inset * S, inset * S, (W - inset) * S, (H - inset) * S], (10 - inset * 0.5) * S, outline=col + (255,), width=int(wd * S))
    cx, cy, R = W * S / 2, H * S / 2, 70 * S
    for i in range(int(R), 0, -S):   # the medallion: a gold disc lit from the top left
        t = i / R
        col = (int(122 + 133 * (1 - t) ** 0.6), int(79 + 164 * (1 - t) ** 0.7), int(18 + 174 * (1 - t) ** 1.2))
        d.ellipse([cx - i - (1 - t) * 18 * S, cy - i - (1 - t) * 22 * S, cx + i - (1 - t) * 18 * S, cy + i - (1 - t) * 22 * S], fill=col + (255,))
    d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=(59, 38, 8, 255), width=3 * S)
    d.ellipse([cx - R - 5 * S, cy - R - 5 * S, cx + R + 5 * S, cy + R + 5 * S], outline=(243, 210, 122, 255), width=2 * S)
    def star(r1, r2, col):
        pts = []
        for i in range(8):
            ang = -math.pi / 2 + i * math.pi / 4; r = r1 if i % 2 == 0 else r2
            pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
        d.polygon(pts, fill=col)
    star(46 * S, 8 * S, (59, 38, 8, 255)); star(28 * S, 5 * S, (243, 210, 122, 255))
    im = Image.new("RGBA", (256, 512)); im.paste(big.resize((W, H), Image.LANCZOS), (0, 0))
    save(im, "GildedBack")

if __name__ == "__main__":
    body(); frames(); edge(); corner(); plate(512, 96, "GildedPlate"); plate(512, 160, "GildedPanel"); flecks(); back()
