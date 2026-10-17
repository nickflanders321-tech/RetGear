"""Waypath+ seal art: wax seal blank, reward seal, stack of seals, ribbon.
Our own drawing, grayscale so the add-on can tint it per set. Output: Media/Arcade/Seals.tga (512x512, 2x2 cells of 256).
  cell (0,0) wax seal blank      cell (1,0) reward seal (laurel + star)
  cell (0,1) stack of seals      cell (1,1) ribbon banner
Run: python3 tools/arcade/art_seals.py
"""
import math, os, numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "Media", "Arcade", "Seals.tga")
S = 4          # supersample
N = 256 * S

def grid():
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    return (x - N / 2) / (N / 2), (y - N / 2) / (N / 2)

def smooth(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)

def blur(a, r):
    from scipy.ndimage import gaussian_filter
    return gaussian_filter(np.asarray(a, dtype=np.float32), r)

def light(h, strength=12.0, ambient=0.80):
    gy, gx = np.gradient(blur(h, 2.0 * S))
    shade = ambient + strength * (-(gx * 0.7 + gy * 0.7)) * N / 256.0 * 0.35
    return np.clip(shade, 0.35, 1.12)

def wax_height(cx=0.0, cy=0.0, scale=1.0, rot=0.0, seed=1):
    X, Y = grid()
    X = (X - cx) / scale; Y = (Y - cy) / scale
    r = np.sqrt(X * X + Y * Y); th = np.arctan2(Y, X) + rot
    edge = 0.90 + 0.022 * np.sin(7 * th + 0.6 + seed) + 0.016 * np.sin(13 * th + 2 + seed) + 0.009 * np.sin(23 * th + seed * 3)
    inside = 1 - smooth(edge - 0.012, edge + 0.004, r)
    h = np.zeros_like(r)
    flat = 0.34 - 0.05 * (r / 0.72) ** 2
    h = np.where(r < 0.70, flat, h)
    rim = 0.34 + 0.46 * smooth(0.68, 0.78, r) * (1 - smooth(0.80, edge, r))
    h = np.where((r >= 0.70) & (r < edge), rim, h)
    h = np.where(r >= edge, 0.0, h)
    h = h * inside
    # a ring of pearls on the rim
    for k in range(28):
        a = k / 28 * 2 * math.pi
        px, py = 0.80 * math.cos(a), 0.80 * math.sin(a)
        d = np.sqrt((X - px) ** 2 + (Y - py) ** 2)
        h += 0.32 * np.exp(-(d / 0.03) ** 2) * inside
    # the groove where the emblem sits
    h -= 0.10 * np.exp(-((r - 0.62) / 0.012) ** 2) * inside
    return h, inside, r, th, X, Y

def to_rgba(shade, alpha):
    g = (np.clip(shade, 0, 1) * 255).astype(np.uint8)
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    rgba = np.stack([g, g, g, a], axis=-1)
    return Image.fromarray(rgba, "RGBA")

def wax_cell(extra_height=None, seed=1, scale=1.0, cx=0.0, cy=0.0, rot=0.0):
    h, inside, r, th, X, Y = wax_height(cx, cy, scale, rot, seed)
    if extra_height is not None:
        h = h + extra_height(X, Y, r, th) * inside
    shade = light(h)
    # a little wax mottling
    rng = np.random.default_rng(seed)
    mott = blur(rng.random((N, N), dtype=np.float32), 6 * S) - 0.5
    shade = shade * (1 + mott * 0.5)
    # a soft sheen up in the top left
    sheen = np.exp(-(((X + 0.35) ** 2 + (Y + 0.4) ** 2) / 0.09)) * 0.16
    shade = shade + sheen
    return to_rgba(shade, blur(inside, 0.6 * S)), h

def star_height(X, Y, r, th, R=0.44, inner=0.21, height=0.7):
    # five point star, raised
    ang = np.arctan2(Y, X) + math.pi / 2
    sector = (ang % (2 * math.pi / 5)) / (2 * math.pi / 5)
    tri = np.abs(sector - 0.5) * 2          # 1 at the valley, 0 at the tip
    rad = R * (1 - tri) + inner * tri
    return height * (1 - smooth(rad - 0.012, rad + 0.012, r))

def laurel_height(X, Y, r, th):
    h = np.zeros_like(r)
    for side in (-1, 1):
        for k in range(10):
            t = k / 9
            a = math.pi / 2 + side * (0.28 + t * 2.15)          # sweeping from the bottom up each side
            rr = 0.55
            lx, ly = rr * math.cos(a), rr * math.sin(a)
            tang = a + side * math.pi / 2
            for off, tilt in ((0.055, 0.7), (-0.055, -0.7)):
                ox = lx + off * math.cos(a)
                oy = ly + off * math.sin(a)
                dx, dy = X - ox, Y - oy
                ca, sa = math.cos(tang + side * tilt * 0.5), math.sin(tang + side * tilt * 0.5)
                u = dx * ca + dy * sa; v = -dx * sa + dy * ca
                leaf = np.exp(-((u / 0.075) ** 2 + (v / 0.032) ** 2))
                h = np.maximum(h, 0.40 * leaf)
    return h

def stack_cell():
    base = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    specs = [(-0.26, 0.20, 0.62, 0.3, 2), (0.26, 0.16, 0.62, -0.2, 3), (0.0, -0.14, 0.70, 0.1, 4)]
    for cx, cy, sc, rot, sd in specs:
        im, _ = wax_cell(None, sd, sc, cx, cy, rot)
        # earlier seals are in the shade of the later ones
        if sd != 4:
            arr = np.asarray(im, dtype=np.float32); arr[..., :3] *= 0.80; im = Image.fromarray(arr.astype(np.uint8), "RGBA")
        base = Image.alpha_composite(base, im)
    return base

def ribbon_cell():
    X, Y = grid()
    # a banner with swallow-tail ends, folded back behind the middle
    w, hgt = 0.92, 0.26
    body = (np.abs(X) < w) & (np.abs(Y) < hgt)
    notch = hgt * 0.9 * np.clip((np.abs(X) - (w - 0.16)) / 0.16, 0, 1)
    body = body & (np.abs(Y + 0.0) < hgt) & ~((np.abs(X) > w - 0.16) & (np.abs(Y) < notch * 0.8 * (np.abs(X) - (w - 0.16)) / 0.16 + 0.0) & False)
    # swallow tail: cut a triangle from each end
    tailx = np.abs(X) - (w - 0.15)
    cut = (tailx > 0) & (np.abs(Y) < tailx * 1.05 * 0.55 + 0.0) & (np.abs(Y) < 0.13 - 0.0) & (tailx > 0.0) & (np.abs(Y) < (0.15 - tailx) * 0) 
    cut = (tailx > 0) & (np.abs(Y) < (0.15 - np.abs(0.15 - tailx)) * 1.0)
    body = body & ~cut
    h = body.astype(np.float32) * 0.5
    h += 0.10 * np.exp(-((np.abs(Y) - hgt * 0.82) / 0.02) ** 2) * body          # stitched edges
    h += 0.06 * np.sin(X * 3.0) * body
    shade = light(h, 9.0, 0.82)
    shade = shade + (0.10 * (0.5 - (Y / hgt) * 0.5))                              # lit from above
    return to_rgba(shade, blur(body.astype(np.float32), 0.6 * S))

def main():
    sheet = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    def put(im, col, row):
        im = im.resize((256, 256), Image.LANCZOS)
        sheet.paste(im, (col * 256, row * 256))
    wax, _ = wax_cell(None, 1)
    put(wax, 0, 0)
    reward, _ = wax_cell(lambda X, Y, r, th: star_height(X, Y, r, th) + laurel_height(X, Y, r, th), 5)
    put(reward, 1, 0)
    put(stack_cell(), 0, 1)
    put(ribbon_cell(), 1, 1)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print("wrote", OUT)

if __name__ == "__main__":
    main()
