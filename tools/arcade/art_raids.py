"""Waypath+ raid card frames: our own drawing, one per WoW Forever raid, laid over a raid card's edge.
  RaidBarrow.tga  The Barrow Deeps: weathered barrow stone, roots twisting along it, a dim green spirit light
  RaidHyjal.tga   Hyjal Summit: a silver vine with leaves, moonlit, a crescent at the top
  RaidOnyxia.tga  Onyxia's Lair: overlapping black dragon scales with embers glowing between them
Each is 256x512 like the card textures (the card fills the top 358 rows); the middle is clear so the card shows.
Run: python3 tools/arcade/art_raids.py
"""
import math, os, numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "Media", "Arcade")
S = 4
W, H, CH = 256 * S, 512 * S, 358 * S
rng = np.random.default_rng(7)
y, x = np.mgrid[0:H, 0:W].astype(np.float32)

def rrect_dist(x0, y0, x1, y1, r):
    """signed distance (in pixels) to a rounded rectangle, negative inside"""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(x - cx) - hx, np.abs(y - cy) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r

def smooth(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)

def noise(scale, octaves=4):
    out = np.zeros((H, W), np.float32); amp = 1.0; tot = 0
    for o in range(octaves):
        n = rng.random((H, W)).astype(np.float32)
        out += amp * gaussian_filter(n, scale / (2 ** o) * S); tot += amp; amp *= 0.5
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-6)

def shade(h, k=9.0):
    gy, gx = np.gradient(gaussian_filter(h, 1.5 * S))
    return np.clip(0.82 + k * (-(gx * 0.6 + gy * 0.8)) * 256 / W * S, 0.4, 1.25)

d = rrect_dist(0, 0, W, CH, 12 * S)          # 0 at the card's outer edge, negative inside
inside = -d                                   # depth into the card
card = (d <= 0) & (y < CH)
BAND = 15 * S                                 # how far the frame reaches in

def band_alpha(width=BAND, soft=2.5):
    return smooth(width + soft * S, width - soft * S, inside) * smooth(-1.0 * S, 0.6 * S, inside)

# an angle along the edge (0..1 around the card), for patterns that follow it
perim = np.where(np.abs(x - W / 2) / W > np.abs(y - CH / 2) / CH, y / CH, x / W)

def corners():
    """distance to the nearest of the four corners (for corner ornaments)"""
    pts = [(14 * S, 14 * S), (W - 14 * S, 14 * S), (14 * S, CH - 14 * S), (W - 14 * S, CH - 14 * S)]
    return np.min([np.hypot(x - px, y - py) for px, py in pts], axis=0)

def save(rgb, a, name):
    a = np.where(y < CH, a, 0)
    img = np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])
    im = Image.fromarray((img * 255).astype(np.uint8), "RGBA").resize((256, 512), Image.LANCZOS)
    im.save(os.path.join(OUT, name))
    print("wrote", name)

# ---------------------------------------------------------------------------
# The Barrow Deeps: weathered barrow stone, roots, spirit light at the corners
# ---------------------------------------------------------------------------
def barrow():
    a = band_alpha()
    st = noise(10) * 0.6 + noise(3) * 0.4
    cracks = smooth(0.48, 0.5, np.abs(noise(6, 3) - 0.5) * 2) < 0.5
    base = np.dstack([0.30 + 0.18 * st, 0.31 + 0.17 * st, 0.29 + 0.15 * st])
    base *= shade(st)[..., None]
    base[cracks] *= 0.55
    # roots: wavy lines that follow the edge, a little in from it
    root = np.zeros((H, W), np.float32)
    for k, (off, freq, ph, th) in enumerate([(6.5, 11, 0.3, 1.7), (10.5, 7, 1.9, 1.3), (4.0, 17, 4.1, 1.0)]):
        line = inside - (off * S + 2.2 * S * np.sin(perim * freq * 2 * math.pi + ph))
        root = np.maximum(root, smooth(th * S, 0.2 * S, np.abs(line)))
    rootc = np.dstack([0.24 + 0.1 * st, 0.17 + 0.05 * st, 0.11 + 0.03 * st]) * shade(root * 3, 14)[..., None]
    rgb = base * (1 - root[..., None]) + rootc * root[..., None]
    # moss and the spirit light in the corners
    cd = corners()
    glow = np.exp(-(cd / (16 * S)) ** 2)
    moss = smooth(0.62, 0.75, noise(5)) * (1 - smooth(BAND * 0.3, BAND, inside))
    rgb = rgb * (1 - 0.6 * moss[..., None]) + np.array([0.22, 0.36, 0.2]) * 0.6 * moss[..., None]
    rgb += np.array([0.25, 0.85, 0.6]) * (0.55 * glow)[..., None]
    # a carved rune at the top centre
    ry = np.hypot(x - W / 2, y - 7 * S)
    rune = smooth(5.5 * S, 4.5 * S, ry) * (1 - smooth(3.6 * S, 2.6 * S, ry)) + smooth(1.3 * S, 0.4 * S, np.abs(x - W / 2)) * smooth(9 * S, 8 * S, ry)
    rgb = rgb * (1 - rune[..., None]) + np.array([0.45, 1.0, 0.75]) * rune[..., None]
    a = np.maximum(a, rune * card) * card
    # a soft inner shadow so the band sits on the card
    a = np.maximum(a, 0.45 * smooth(BAND + 6 * S, BAND, inside) * card * (inside > BAND - 2 * S))
    rgb = np.where((inside > BAND)[..., None], np.zeros(3), rgb)
    save(rgb, a, "RaidBarrow.tga")

# ---------------------------------------------------------------------------
# Hyjal Summit: a silver vine with leaves, moonlit; a crescent at the top
# ---------------------------------------------------------------------------
def hyjal():
    a = band_alpha(12 * S)
    t = noise(8)
    base = np.dstack([0.16 + 0.08 * t, 0.22 + 0.1 * t, 0.30 + 0.12 * t]) * shade(t)[..., None]
    # a fine silver rule at the edge and the vine running along the band
    rule = smooth(1.2 * S, 0.3 * S, np.abs(inside - 2.2 * S))
    vine_path = inside - (7 * S + 2.5 * S * np.sin(perim * 13 * 2 * math.pi))
    vine = smooth(1.3 * S, 0.3 * S, np.abs(vine_path))
    # leaves: little ellipses at regular points along the vine
    leaf = np.zeros((H, W), np.float32)
    n = 52
    for i in range(n):
        p = (i + 0.5) / n
        # walk the edge: top, right, bottom, left
        if p < 0.25: px, py, nx, ny = W * (p / 0.25), 0.0, 0, 1
        elif p < 0.5: px, py, nx, ny = float(W), CH * ((p - 0.25) / 0.25), -1, 0
        elif p < 0.75: px, py, nx, ny = W * (1 - (p - 0.5) / 0.25), float(CH), 0, -1
        else: px, py, nx, ny = 0.0, CH * (1 - (p - 0.75) / 0.25), 1, 0
        side = 1 if i % 2 else -1
        cx, cy = px + nx * (7 + side * 3.2) * S, py + ny * (7 + side * 3.2) * S
        ang = math.atan2(ny, nx) + side * 0.9 + (0.3 if i % 3 == 0 else -0.2)
        dx, dy = x - cx, y - cy
        u = dx * math.cos(ang) + dy * math.sin(ang); v = -dx * math.sin(ang) + dy * math.cos(ang)
        leaf = np.maximum(leaf, smooth(1.0, 0.8, (u / (3.6 * S)) ** 2 + (v / (1.7 * S)) ** 2))
    silver = np.array([0.82, 0.9, 0.98]); green = np.array([0.55, 0.85, 0.6])
    rgb = base * (1 - rule[..., None]) + silver * rule[..., None]
    rgb = rgb * (1 - vine[..., None]) + silver * 0.75 * vine[..., None]
    rgb = rgb * (1 - leaf[..., None]) + (green * 0.7 + silver * 0.3) * shade(leaf * 2, 8)[..., None] * leaf[..., None]
    # motes of moonlight
    motes = (rng.random((H, W)) > 0.99965).astype(np.float32)
    motes = gaussian_filter(motes, 1.2 * S) * 60
    rgb += np.array([0.7, 0.85, 1.0]) * np.clip(motes, 0, 1)[..., None] * (inside < 13 * S)[..., None]
    # the crescent at the top centre
    c1 = np.hypot(x - W / 2, y - 6 * S); c2 = np.hypot(x - W / 2 - 2.2 * S, y - 4.8 * S)
    moon = smooth(5.6 * S, 4.8 * S, c1) * smooth(3.9 * S, 4.7 * S, c2)
    rgb = rgb * (1 - moon[..., None]) + np.array([0.95, 0.97, 1.0]) * moon[..., None]
    halo = np.exp(-(c1 / (10 * S)) ** 2) * 0.35
    rgb += np.array([0.6, 0.75, 1.0]) * halo[..., None]
    a = np.maximum(np.maximum(a, leaf * card), moon) * card
    a = np.maximum(a, 0.4 * smooth(12 * S + 6 * S, 12 * S, inside) * card * (inside > 10 * S))
    rgb = np.where((inside > 12.5 * S)[..., None], np.zeros(3), rgb)
    save(rgb, a, "RaidHyjal.tga")

# ---------------------------------------------------------------------------
# Onyxia's Lair: overlapping black scales, embers between them
# ---------------------------------------------------------------------------
def onyxia():
    a = band_alpha(15 * S)
    # scales: rows of circles along the edge (u along the edge, v into the card)
    L = 2 * (W + CH)
    u = np.where(y < 1, x, 0)  # placeholder
    # position along the perimeter in pixels
    top = (inside <= np.minimum.reduce([x, W - x, CH - y, y]) + 1)
    dl, dr, dt, db = x, W - x, y, CH - y
    m = np.argmin(np.stack([dt, dr, db, dl]), axis=0)
    along = np.select([m == 0, m == 1, m == 2, m == 3], [x, W + y, W + CH + (W - x), 2 * W + CH + (CH - y)])
    depth = np.select([m == 0, m == 1, m == 2, m == 3], [dt, dr, db, dl])
    sc = 9.0 * S
    rowh = sc * 0.55
    best_r = np.full((H, W), 9e9, np.float32); best_du = np.zeros((H, W), np.float32); best_dv = np.zeros((H, W), np.float32)
    row0 = np.floor(depth / rowh)
    for dr in (-1, 0, 1):
        row = row0 + dr
        shift = (row % 2) * sc * 0.5
        for dc in (-1, 0, 1):
            cu = (np.floor((along + shift) / sc) + dc + 0.5) * sc - shift
            cv = (row + 0.5) * rowh
            du, dv = along - cu, depth - cv
            rr = np.hypot(du, dv * 1.25)
            # (the scale nearer the card's edge lies on top)
            better = (rr < sc * 0.62) & ((best_r > sc * 0.62) | (row < np.floor(best_dv * 0 + row0 + 5)) & (dv < best_dv)) | (rr < best_r) & (best_r > sc * 0.62)
            best_r = np.where(better, rr, best_r); best_du = np.where(better, du, best_du); best_dv = np.where(better, dv, best_dv)
    r, du, dv = best_r, best_du, best_dv
    scale = smooth(sc * 0.64, sc * 0.56, r)
    edge = smooth(sc * 0.07, 0.0, np.abs(r - sc * 0.58))
    sh = np.clip(0.75 + 0.9 * (-dv / sc) + 0.2 * (du / sc), 0.3, 1.15)
    t = noise(4, 3)
    base = np.array([0.13, 0.12, 0.15]) * sh[..., None] * (0.85 + 0.3 * t)[..., None]
    sheen = smooth(0.18, 0.0, np.abs(dv / sc + 0.22)) * scale * 0.35
    rgb = base + np.array([0.55, 0.5, 0.68]) * sheen[..., None]
    ember = np.clip((1 - scale) + edge * 0.6, 0, 1) * (depth < 15 * S)
    ember_c = np.array([1.0, 0.38, 0.06]) * (0.35 + 0.65 * noise(2, 2))[..., None]
    rgb = rgb * (1 - ember[..., None] * 0.85) + ember_c * ember[..., None] * 0.85
    # a horned crest at the top centre
    hx, hy = np.abs(x - W / 2), y
    crest = smooth(1.0, 0.85, (hx / (9 * S)) ** 1.6 + ((hy - 2 * S) / (12 * S)) ** 2) * (hy < 12 * S)
    horn = smooth(1.4 * S, 0.4 * S, np.abs(hx - (3 * S + hy * 0.5))) * (hy < 9 * S) * (hy > 1 * S)
    rgb = rgb * (1 - crest[..., None]) + np.array([0.08, 0.07, 0.09]) * crest[..., None]
    rgb += np.array([1.0, 0.45, 0.1]) * (horn * 0.9)[..., None]
    eye = smooth(1.6 * S, 0.8 * S, np.hypot(hx - 2.5 * S, hy - 6.5 * S))
    rgb += np.array([1.0, 0.65, 0.2]) * eye[..., None]
    a = np.maximum(a, crest * card) * card
    a = np.maximum(a, 0.5 * smooth(14 * S + 6 * S, 14 * S, inside) * card * (inside > 12 * S))
    rgb = np.where((inside > 14.5 * S)[..., None], np.zeros(3), rgb)
    save(rgb, a, "RaidOnyxia.tga")

barrow(); hyjal(); onyxia()
