"""Painted landscapes for the place cards: one original picture per place, drawn by us.

  python3 tools/arcade/art_places.py [preview]

Reads the place cards from ArcadeCards.lua, paints each (a sky for the time of day, three hazy mountain
layers, a lit landmark chosen from the place's name, foreground silhouettes, mist, bloom), packs them into
Media/Arcade/Places1..N.tga (8x12 cells of 120x84) and writes the lookup into ArcadePlaces.lua.
With "preview" it only writes a contact sheet to $PREVIEW (default /tmp/places.png) for the first 48 places.
"""
import os, re, sys, math, colorsys, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter, gaussian_filter1d

HERE = os.path.dirname(__file__)
ADDON = os.path.join(HERE, "..", "..")
CW, CH = 120, 84
SW, SH = CW * 2, CH * 2          # painted at twice the size, then reduced
COLS, ROWS = 8, 12

def seed_of(s): return int(hashlib.md5(s.encode()).hexdigest()[:8], 16)
def lerp(a, b, t): return a + (b - a) * t
def col(r, g, b): return np.array([r, g, b], np.float32) / 255.0
def mix(a, b, t): return a * (1 - t) + b * t

# ---------------------------------------------------------------- zones -> biome
BIOME_OF = {
  "Elwynn Forest": "green", "Westfall": "farm", "Redridge Mountains": "hill", "Duskwood": "dark", "Stranglethorn Vale": "jungle", "Un'Goro Crater": "jungle",
  "Dun Morogh": "snow", "Winterspring": "snow", "Alterac Mountains": "snow", "Alterac Valley": "snow", "Loch Modan": "hill", "Wetlands": "swamp",
  "Swamp of Sorrows": "swamp", "Dustwallow Marsh": "swamp", "Hillsbrad Foothills": "hill", "Arathi Highlands": "hill", "Arathi Basin": "hill",
  "The Hinterlands": "green", "Western Plaguelands": "plague", "Eastern Plaguelands": "plague", "Tirisfal Glades": "plague", "Silverpine Forest": "dark",
  "Deadwind Pass": "plague", "Blasted Lands": "blight", "Burning Steppes": "fire", "Searing Gorge": "fire", "Badlands": "desert", "Tanaris": "desert",
  "Durotar": "red", "The Barrens": "desert", "Mulgore": "plain", "Thousand Needles": "desert", "Stonetalon Mountains": "hill", "Desolace": "blight",
  "Feralas": "jungle", "Ashenvale": "green", "Darkshore": "coast", "Teldrassil": "elf", "Azshara": "coast", "Felwood": "fel", "Moonglade": "elf",
  "Silithus": "fire", "Zephras Isle": "coast", "Riverglades": "swamp", "Shen'dralas": "elf", "Mount Hyjal": "elf",
  "Stormwind City": "city", "Ironforge": "snow", "Orgrimmar": "red", "Thunder Bluff": "plain", "Undercity": "plague", "Darnassus": "elf",
}
# per biome: (sky tint colour, tint strength, ground colour, far-mountain colour, foliage colour)
BIOMES = {
  "green":  (col(150, 200, 150), 0.18, col(52, 84, 46),  col(80, 110, 120), col(24, 52, 30)),
  "farm":   (col(230, 200, 120), 0.20, col(120, 112, 58), col(120, 120, 110), col(60, 70, 34)),
  "hill":   (col(190, 170, 140), 0.15, col(92, 84, 58),  col(96, 100, 120), col(48, 58, 34)),
  "dark":   (col(80, 90, 140),  0.28, col(32, 40, 34),  col(54, 62, 90),   col(14, 24, 24)),
  "jungle": (col(120, 220, 160), 0.26, col(28, 82, 48),  col(60, 118, 100), col(10, 54, 30)),
  "snow":   (col(200, 225, 255), 0.30, col(220, 232, 245), col(150, 170, 205), col(70, 98, 90)),
  "swamp":  (col(150, 180, 120), 0.30, col(54, 68, 44),  col(84, 104, 92),  col(30, 44, 30)),
  "plague": (col(150, 190, 110), 0.34, col(62, 70, 46),  col(78, 92, 80),   col(36, 40, 26)),
  "blight": (col(220, 120, 80),  0.34, col(112, 66, 48), col(130, 84, 80),  col(70, 40, 30)),
  "fire":   (col(255, 120, 60),  0.38, col(86, 40, 28),  col(120, 62, 52),  col(40, 18, 14)),
  "desert": (col(240, 196, 120), 0.30, col(172, 134, 82), col(180, 140, 110), col(100, 80, 50)),
  "red":    (col(240, 140, 90),  0.30, col(150, 74, 46), col(170, 100, 80), col(80, 46, 30)),
  "plain":  (col(230, 210, 140), 0.18, col(124, 130, 62), col(130, 120, 110), col(62, 78, 36)),
  "coast":  (col(130, 170, 220), 0.22, col(48, 76, 74),  col(80, 106, 140), col(24, 48, 50)),
  "elf":    (col(170, 140, 230), 0.30, col(46, 66, 88),  col(88, 84, 140),  col(26, 40, 66)),
  "fel":    (col(150, 230, 90),  0.36, col(50, 60, 30),  col(86, 100, 60),  col(26, 34, 16)),
  "city":   (col(220, 210, 190), 0.12, col(98, 98, 90),  col(120, 128, 150), col(50, 56, 44)),
}
TIMES = {
  # top, mid, horizon, sun colour, sun height (0 horizon .. 1 high), star amount
  "day":   (col(70, 120, 200), col(130, 175, 225), col(196, 220, 240), col(255, 246, 210), 0.62, 0.0, 1.00),
  "dawn":  (col(70, 84, 150),  col(206, 128, 150), col(255, 196, 124), col(255, 214, 150), 0.18, 0.1, 0.80),
  "dusk":  (col(44, 46, 108),  col(172, 84, 112),  col(255, 140, 72),  col(255, 170, 90),  0.14, 0.25, 0.70),
  "night": (col(8, 12, 36),    col(22, 34, 78),    col(58, 78, 132),   col(220, 232, 255), 0.55, 1.0, 0.36),
  "storm": (col(52, 60, 78),   col(92, 100, 118),  col(150, 156, 168), col(230, 230, 220), 0.40, 0.0, 0.66),
}

# ---------------------------------------------------------------- landmark from the name
KINDS = [
  ("castle", r"keep|castle|fort|stronghold|citadel|hold\b|garrison|bastion|barracks|redoubt"),
  ("lighthouse", r"lighthouse|beacon"),
  ("tower", r"tower|spire|watch|belfry|sentinel|lookout"),
  ("bridge", r"bridge|crossing|span|ford"),
  ("mill", r"mill|farm|field|orchard|stead|grain|crop"),
  ("graveyard", r"grave|cemetery|crypt|tomb|barrow|mausoleum|necropolis|catacomb|bone|haunted|forsaken|scourge|dead|death|undead"),
  ("cave", r"cave|cavern|grotto|den\b|lair|mine\b|deeps|depths|burrow|hollow|pit\b|tunnel|warren|delve"),
  ("waterfall", r"falls|waterfall|cascade|rapids|spring"),
  ("volcano", r"volcano|crater|fire|flame|burning|magma|caldera|cinder|ember|lava|scorch|molten|ash"),
  ("crystal", r"crystal|shard|gem|jewel|prism|arcane|mana|nexus|rift|portal|moon|star"),
  ("totem", r"totem|stone|monolith|megalith|henge|circle|pillar|spirit|shaman|ritual|bluff"),
  ("ruins", r"ruin|temple|shrine|altar|gate|monument|statue|remnant|fallen|ancient|old\b|lost|vault|sanctum|abbey|cathedral|hall\b"),
  ("pyramid", r"pyramid|ziggurat|zul|sunken|sands|dune|desert|oasis|obelisk|gurub|temple of"),
  ("port", r"bay|sea|coast|shore|cove|harbor|harbour|port\b|dock|beach|isle|island|marina|wharf|lake|pond|river|strand|reef|sound|tide|deep\b"),
  ("camp", r"camp|outpost|encampment|rest\b|watchpost|post\b|settlement|village|hamlet|town|haven|stand\b|landing|crossroads|inn\b|tavern|trading"),
  ("grove", r"grove|glade|forest|wood|woods|thicket|glen|copse|bloom|leaf|timber|vale|meadow|garden|bough|root|tree"),
  ("marsh", r"marsh|swamp|bog|fen|mire|mud|reed|slough|sorrow|bayou|stagnant|rot\b|blight"),
  ("peak", r"peak|mount|mountain|pass\b|canyon|ravine|gorge|hill|ridge|cliff|summit|heights|plateau|bluff|slope|crag|rock|spur|needle|mesa|highlands|steppe|plateau"),
]
FALLBACK = {"green": ["grove", "camp", "tower", "mill"], "farm": ["mill", "camp", "tower"], "hill": ["peak", "castle", "camp", "tower"],
  "dark": ["grove", "graveyard", "tower"], "jungle": ["pyramid", "grove", "totem", "waterfall"], "snow": ["peak", "castle", "camp", "tower"],
  "swamp": ["marsh", "camp", "ruins"], "plague": ["graveyard", "tower", "ruins"], "blight": ["ruins", "peak", "totem"], "fire": ["volcano", "castle", "peak"],
  "desert": ["pyramid", "camp", "peak", "totem"], "red": ["camp", "totem", "peak"], "plain": ["totem", "camp", "peak"], "coast": ["port", "ruins", "lighthouse"],
  "elf": ["grove", "ruins", "crystal", "tower"], "fel": ["grove", "totem", "ruins"], "city": ["castle", "tower", "bridge"]}

def kind_for(name, biome, rnd):
    n = name.lower()
    for k, pat in KINDS:
        if re.search(pat, n): return k
    return FALLBACK[biome][int(rnd.random() * len(FALLBACK[biome]))]

# ---------------------------------------------------------------- helpers
def fbm1(rnd, n, octaves=5, rough=0.55):
    out = np.zeros(n, np.float32); amp = 1.0; tot = 0
    for o in range(octaves):
        k = 2 ** (o + 1)
        pts = rnd.standard_normal(k + 3).astype(np.float32)
        xs = np.linspace(0, k, n)
        i = np.floor(xs).astype(int); f = xs - i
        f = f * f * (3 - 2 * f)
        out += amp * (pts[i] * (1 - f) + pts[i + 1] * f)
        tot += amp; amp *= rough
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-6)
def noise2(rnd, h, w, s):
    n = rnd.standard_normal((h, w)).astype(np.float32)
    n = gaussian_filter(n, s); n /= (n.std() + 1e-6)
    return n

class Canvas:
    def __init__(self):
        self.img = np.zeros((SH, SW, 3), np.float32)
        self.y, self.x = np.mgrid[0:SH, 0:SW].astype(np.float32)
    def over(self, rgb, alpha):
        a = alpha[..., None] if alpha.ndim == 2 else alpha
        self.img = self.img * (1 - a) + rgb * a
    def add(self, rgb, amt):
        self.img += rgb * (amt[..., None] if amt.ndim == 2 else amt)

def draw_layer(fn, blur=0.0):
    """draw with PIL at 2x then reduce: returns rgba float arrays (h, w, 4)"""
    im = Image.new("RGBA", (SW * 2, SH * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fn(d, 2)
    im = im.resize((SW, SH), Image.LANCZOS)
    if blur: im = im.filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(im).astype(np.float32) / 255.0
    return a

# ---------------------------------------------------------------- landmarks (drawn onto a PIL draw, scale s)
def landmark(kind, d, s, cx, gy, size, c_lit, rnd):
    """Draws the silhouette in solid white (colour and light are applied afterwards), windows/fire in pure red
    so they can be picked out and lit. cx, gy = base centre in canvas px."""
    W = (255, 255, 255, 255); RED = (255, 0, 0, 255); CLR = (0, 0, 0, 0)
    z = size / 60.0
    def P(pts, f=W): d.polygon([(px * s, py * s) for px, py in pts], fill=f)
    def R(x0, y0, x1, y1, f=W): d.rectangle([x0 * s, y0 * s, x1 * s, y1 * s], fill=f)
    def win(x, y, w=2.4, h=4.0): R(x - w / 2, y - h / 2, x + w / 2, y + h / 2, RED)
    def circ(x, y, r, f=W): d.ellipse([(x - r) * s, (y - r) * s, (x + r) * s, (y + r) * s], fill=f)
    def ln(x0, y0, x1, y1, w=1.6, f=W): d.line([(x0 * s, y0 * s), (x1 * s, y1 * s)], fill=f, width=max(1, int(w * s)))
    def arch(x, base, rad, thick, top):   # a stone arch: legs and a half ring
        R(x - rad - thick, top, x - rad, base); R(x + rad, top, x + rad + thick, base)
        pts = []
        for k in range(0, 19):
            a = math.pi + math.pi * k / 18
            pts.append((x + math.cos(a) * (rad + thick), top + math.sin(a) * (rad + thick)))
        for k in range(18, -1, -1):
            a = math.pi + math.pi * k / 18
            pts.append((x + math.cos(a) * rad, top + math.sin(a) * rad))
        P(pts)
    if kind == "tower":
        w = 9 * z
        P([(cx - w, gy), (cx - w * 0.8, gy - 54 * z), (cx + w * 0.8, gy - 54 * z), (cx + w, gy)])
        R(cx - w - 3.5 * z, gy - 58 * z, cx + w + 3.5 * z, gy - 53 * z)
        for k in range(-2, 3): R(cx + k * 5.2 * z - 1.4 * z, gy - 63 * z, cx + k * 5.2 * z + 1.4 * z, gy - 58 * z)
        P([(cx - 7 * z, gy - 63 * z), (cx, gy - 82 * z), (cx + 7 * z, gy - 63 * z)])
        ln(cx, gy - 82 * z, cx, gy - 92 * z, 1.2); P([(cx, gy - 92 * z), (cx + 9 * z, gy - 89 * z), (cx, gy - 85 * z)])
        for yy in (40, 26, 14): win(cx, gy - yy * z, 3 * z, 6 * z)
        R(cx - 15 * z, gy - 8 * z, cx + 15 * z, gy)
    elif kind == "castle":
        R(cx - 40 * z, gy - 24 * z, cx + 40 * z, gy)
        for k in range(-7, 8): R(cx + k * 5.3 * z - 1.6 * z, gy - 29 * z, cx + k * 5.3 * z + 1.6 * z, gy - 24 * z)
        for dx, h, w in [(-38, 40, 7.5), (-14, 56, 8.5), (14, 64, 9), (38, 44, 7.5)]:
            x = cx + dx * z; ww = w * z
            R(x - ww, gy - h * z, x + ww, gy)
            R(x - ww - 2 * z, gy - (h + 4) * z, x + ww + 2 * z, gy - h * z)
            P([(x - ww - 1 * z, gy - (h + 4) * z), (x, gy - (h + 24) * z), (x + ww + 1 * z, gy - (h + 4) * z)])
            win(x, gy - (h - 14) * z, 2.8 * z, 5 * z)
            if h > 60: ln(x, gy - (h + 24) * z, x, gy - (h + 34) * z, 1.2); P([(x, gy - (h + 34) * z), (x + 10 * z, gy - (h + 30) * z), (x, gy - (h + 26) * z)])
        R(cx - 9 * z, gy - 20 * z, cx + 9 * z, gy, CLR); d.pieslice([(cx - 9 * z) * s, (gy - 29 * z) * s, (cx + 9 * z) * s, (gy - 11 * z) * s], 180, 360, fill=CLR)
        win(cx, gy - 7 * z, 9 * z, 14 * z)
    elif kind == "lighthouse":
        P([(cx - 10 * z, gy), (cx - 5.5 * z, gy - 56 * z), (cx + 5.5 * z, gy - 56 * z), (cx + 10 * z, gy)])
        R(cx - 9 * z, gy - 61 * z, cx + 9 * z, gy - 56 * z)
        R(cx - 5.5 * z, gy - 70 * z, cx + 5.5 * z, gy - 61 * z, RED)
        P([(cx - 8.5 * z, gy - 70 * z), (cx, gy - 82 * z), (cx + 8.5 * z, gy - 70 * z)])
        P([(cx - 36 * z, gy), (cx - 24 * z, gy - 8 * z), (cx + 26 * z, gy - 8 * z), (cx + 38 * z, gy)])
    elif kind == "bridge":
        R(cx - 62 * z, gy - 26 * z, cx + 62 * z, gy - 18 * z)
        for k in range(-6, 7): R(cx + k * 9.4 * z - 1 * z, gy - 33 * z, cx + k * 9.4 * z + 1 * z, gy - 26 * z)
        R(cx - 62 * z, gy - 34 * z, cx + 62 * z, gy - 32 * z)
        for k in range(4):
            x0 = cx - 60 * z + k * 30 * z
            P([(x0, gy - 18 * z)] + [(x0 + 15 * z + math.cos(math.pi + math.pi * m / 14) * 15 * z, gy - 18 * z + math.sin(math.pi + math.pi * m / 14) * 26 * z * -1 * -1) for m in range(15)] + [(x0 + 30 * z, gy - 18 * z), (x0 + 30 * z, gy), (x0, gy)])
        for k in range(5): R(cx - 60 * z + k * 30 * z - 3 * z, gy - 18 * z, cx - 60 * z + k * 30 * z + 3 * z, gy)
    elif kind == "mill":
        P([(cx - 12 * z, gy), (cx - 8 * z, gy - 36 * z), (cx + 8 * z, gy - 36 * z), (cx + 12 * z, gy)])
        P([(cx - 11 * z, gy - 36 * z), (cx, gy - 50 * z), (cx + 11 * z, gy - 36 * z)])
        for a in (0.45, 2.02, 3.6, 5.17):
            ex, ey = cx + math.cos(a) * 36 * z, gy - 38 * z + math.sin(a) * 36 * z
            ln(cx, gy - 38 * z, ex, ey, 2.0)
            px, py = -math.sin(a), math.cos(a)
            P([(cx + math.cos(a) * 9 * z, gy - 38 * z + math.sin(a) * 9 * z), (ex, ey), (ex + px * 10 * z, ey + py * 10 * z), (cx + math.cos(a) * 9 * z + px * 10 * z, gy - 38 * z + math.sin(a) * 9 * z + py * 10 * z)])
        win(cx, gy - 14 * z, 3.2 * z, 6 * z)
        R(cx + 24 * z, gy - 16 * z, cx + 44 * z, gy); P([(cx + 22 * z, gy - 16 * z), (cx + 34 * z, gy - 27 * z), (cx + 46 * z, gy - 16 * z)]); win(cx + 34 * z, gy - 8 * z, 3.4 * z, 4.4 * z)
        R(cx + 38 * z, gy - 30 * z, cx + 41 * z, gy - 22 * z)
    elif kind == "graveyard":
        for k in range(-4, 5):
            x = cx + k * 12.5 * z + rnd.uniform(-3, 3); h = rnd.uniform(11, 21) * z
            R(x - 3.5 * z, gy - h, x + 3.5 * z, gy); d.pieslice([(x - 3.5 * z) * s, (gy - h - 3.5 * z) * s, (x + 3.5 * z) * s, (gy - h + 3.5 * z) * s], 180, 360, fill=W)
        P([(cx - 3 * z, gy), (cx - 2 * z, gy - 38 * z), (cx + 1.5 * z, gy - 38 * z), (cx + 2 * z, gy)])
        for a, l in [(-1.1, 22), (-0.55, 18), (0.6, 22), (1.2, 16), (-1.5, 12)]:
            ln(cx, gy - 34 * z, cx + math.sin(a) * l * z, gy - 34 * z - math.cos(a) * l * z, 1.8)
        R(cx + 30 * z, gy - 28 * z, cx + 56 * z, gy); R(cx + 28 * z, gy - 31 * z, cx + 58 * z, gy - 28 * z)
        P([(cx + 29 * z, gy - 31 * z), (cx + 43 * z, gy - 44 * z), (cx + 57 * z, gy - 31 * z)]); win(cx + 43 * z, gy - 14 * z, 5 * z, 9 * z)
        ln(cx + 43 * z, gy - 44 * z, cx + 43 * z, gy - 52 * z, 1.2); ln(cx + 40 * z, gy - 49 * z, cx + 46 * z, gy - 49 * z, 1.2)
    elif kind == "cave":
        P([(cx - 78 * z, gy), (cx - 60 * z, gy - 26 * z), (cx - 38 * z, gy - 50 * z), (cx - 14 * z, gy - 64 * z), (cx + 8 * z, gy - 70 * z), (cx + 30 * z, gy - 58 * z),
           (cx + 52 * z, gy - 38 * z), (cx + 70 * z, gy - 16 * z), (cx + 78 * z, gy)])
        d.pieslice([(cx - 24 * z) * s, (gy - 50 * z) * s, (cx + 24 * z) * s, (gy + 4 * z) * s], 180, 360, fill=RED); R(cx - 24 * z, gy - 14 * z, cx + 24 * z, gy, RED)
        for k in range(-3, 4): P([(cx + k * 6 * z - 2 * z, gy - 36 * z + abs(k) * 4 * z), (cx + k * 6 * z, gy - 28 * z + abs(k) * 3 * z), (cx + k * 6 * z + 2 * z, gy - 36 * z + abs(k) * 4 * z)])
    elif kind == "waterfall":
        P([(cx - 80 * z, gy), (cx - 66 * z, gy - 46 * z), (cx - 38 * z, gy - 66 * z), (cx - 12 * z, gy - 70 * z), (cx + 12 * z, gy - 70 * z), (cx + 38 * z, gy - 64 * z), (cx + 64 * z, gy - 44 * z), (cx + 80 * z, gy)])
        R(cx - 11 * z, gy - 70 * z, cx + 11 * z, gy, RED)
    elif kind == "volcano":
        P([(cx - 84 * z, gy), (cx - 30 * z, gy - 46 * z), (cx - 12 * z, gy - 66 * z), (cx - 7 * z, gy - 72 * z), (cx + 7 * z, gy - 72 * z), (cx + 12 * z, gy - 66 * z), (cx + 30 * z, gy - 46 * z), (cx + 84 * z, gy)])
        P([(cx - 7 * z, gy - 72 * z), (cx - 3 * z, gy - 38 * z), (cx - 6 * z, gy - 10 * z), (cx + 2 * z, gy), (cx + 6 * z, gy - 30 * z), (cx + 7 * z, gy - 72 * z)], RED)
    elif kind == "crystal":
        for dx, h, w in [(-30, 34, 8), (-16, 54, 10), (0, 78, 12), (17, 58, 10), (32, 36, 8), (44, 22, 6)]:
            x = cx + dx * z
            P([(x - w * z, gy), (x - w * 0.7 * z, gy - h * 0.72 * z), (x, gy - h * z), (x + w * 0.7 * z, gy - h * 0.72 * z), (x + w * z, gy)])
            P([(x, gy - h * z), (x + w * 0.7 * z, gy - h * 0.72 * z), (x + w * z, gy), (x + 1 * z, gy - 4 * z)], RED)
    elif kind == "totem":
        for dx, h in [(-36, 40), (0, 66), (36, 36)]:
            x = cx + dx * z
            R(x - 7 * z, gy - h * z, x + 7 * z, gy)
            R(x - 9.5 * z, gy - h * z - 3 * z, x + 9.5 * z, gy - h * z)
            for k in range(3): R(x - 4 * z, gy - (h - 12 - k * 15) * z, x + 4 * z, gy - (h - 15 - k * 15) * z, RED)
        R(cx - 52 * z, gy - 4 * z, cx + 52 * z, gy)
        for x in (cx - 18 * z, cx + 20 * z): R(x - 4 * z, gy - 22 * z, x + 4 * z, gy)
    elif kind == "ruins":
        arch(cx, gy, 17 * z, 6 * z, gy - 50 * z)
        R(cx - 44 * z, gy - 30 * z, cx - 36 * z, gy); R(cx - 46 * z, gy - 33 * z, cx - 34 * z, gy - 30 * z)
        R(cx + 36 * z, gy - 22 * z, cx + 44 * z, gy); P([(cx + 34 * z, gy - 22 * z), (cx + 46 * z, gy - 22 * z), (cx + 41 * z, gy - 28 * z)])
        R(cx - 56 * z, gy - 5 * z, cx + 58 * z, gy)
        for k in range(6): R(cx - 50 * z + k * 20 * z, gy - 9 * z, cx - 42 * z + k * 20 * z, gy - 5 * z)
        win(cx, gy - 11 * z, 6 * z, 10 * z)
    elif kind == "pyramid":
        steps = [(56, 14), (46, 14), (36, 14), (26, 14), (16, 14)]
        yb = gy
        for hw, h in steps:
            R(cx - hw * z, yb - h * z, cx + hw * z, yb); yb -= h * z
        R(cx - 6 * z, gy - 18 * z, cx + 6 * z, gy, RED)
        P([(cx - 8 * z, yb), (cx, yb - 12 * z), (cx + 8 * z, yb)])
        for x in (cx - 70 * z, cx + 70 * z): R(x - 3.5 * z, gy - 40 * z, x + 3.5 * z, gy); P([(x - 4.5 * z, gy - 40 * z), (x, gy - 52 * z), (x + 4.5 * z, gy - 40 * z)])
    elif kind == "port":
        P([(cx - 36 * z, gy - 10 * z), (cx + 40 * z, gy - 10 * z), (cx + 28 * z, gy), (cx - 26 * z, gy)])
        R(cx - 22 * z, gy - 20 * z, cx - 6 * z, gy - 10 * z); win(cx - 14 * z, gy - 15 * z, 3 * z, 3 * z)
        R(cx + 4 * z, gy - 70 * z, cx + 6.2 * z, gy - 10 * z); R(cx - 20 * z, gy - 54 * z, cx - 18 * z, gy - 20 * z)
        P([(cx + 7 * z, gy - 68 * z), (cx + 36 * z, gy - 22 * z), (cx + 7 * z, gy - 18 * z)])
        P([(cx + 2 * z, gy - 60 * z), (cx - 18 * z, gy - 22 * z), (cx + 2 * z, gy - 18 * z)])
        P([(cx - 19 * z, gy - 50 * z), (cx - 34 * z, gy - 26 * z), (cx - 19 * z, gy - 24 * z)])
        ln(cx + 5 * z, gy - 70 * z, cx + 5 * z, gy - 80 * z, 1.2); P([(cx + 5 * z, gy - 80 * z), (cx + 14 * z, gy - 77 * z), (cx + 5 * z, gy - 74 * z)])
    elif kind == "camp":
        for dx, h, w, k in [(-38, 30, 24, 0), (30, 36, 28, 1), (-4, 24, 18, 2)]:
            x = cx + dx * z
            P([(x - w * z, gy), (x, gy - h * z), (x + w * z, gy)])
            P([(x - 3.5 * z, gy), (x, gy - 14 * z), (x + 3.5 * z, gy)], RED if k == 1 else W)
            ln(x, gy - h * z, x, gy - (h + 9) * z, 1.2)
        P([(cx + 56 * z, gy - 30 * z), (cx + 56 * z, gy - 22 * z), (cx + 70 * z, gy - 26 * z)])
        ln(cx + 56 * z, gy - 34 * z, cx + 56 * z, gy, 1.4)
        for k in range(3): R(cx - 66 * z + k * 6 * z, gy - 11 * z, cx - 63 * z + k * 6 * z, gy)
    elif kind == "grove":
        for dx, h, w in [(-52, 40, 13), (-30, 56, 16), (-6, 74, 20), (22, 62, 17), (46, 44, 14), (64, 30, 10)]:
            x = cx + dx * z
            R(x - 2 * z, gy - 18 * z, x + 2 * z, gy)
            for k in range(5):
                ww = w * (1 - k * 0.17) * z; yy = gy - 12 * z - k * h * 0.19 * z
                P([(x - ww, yy), (x, yy - h * 0.33 * z), (x + ww, yy)])
    elif kind == "marsh":
        P([(cx - 3 * z, gy), (cx - 2 * z, gy - 48 * z), (cx + 2 * z, gy - 48 * z), (cx + 3 * z, gy)])
        for a, l in [(-1.0, 24), (-0.5, 30), (0.45, 26), (1.0, 20), (-1.45, 14), (1.45, 14)]:
            ln(cx, gy - 44 * z, cx + math.sin(a) * l * z, gy - 44 * z - math.cos(a) * l * z, 2.0)
        for k in range(-9, 10):
            x = cx + k * 6.5 * z + rnd.uniform(-2, 2); h = rnd.uniform(10, 24) * z
            ln(x, gy, x + rnd.uniform(-2.5, 2.5) * z, gy - h, 1.2)
            if k % 3 == 0: P([(x - 1.6 * z, gy - h), (x, gy - h - 5 * z), (x + 1.6 * z, gy - h)])
        R(cx + 30 * z, gy - 18 * z, cx + 52 * z, gy - 3 * z); P([(cx + 28 * z, gy - 18 * z), (cx + 41 * z, gy - 29 * z), (cx + 54 * z, gy - 18 * z)]); win(cx + 41 * z, gy - 10 * z, 3.4 * z, 4.4 * z)
        for k in (28, 34, 40, 46, 52): R(cx + k * z - 0.8 * z, gy - 3 * z, cx + k * z + 0.8 * z, gy + 4 * z)
    else:  # peak
        pts = [(cx - 84 * z, gy)]
        for k in range(1, 20):
            t = k / 20.0
            x = cx - 84 * z + 168 * z * t
            hh = (74 * (1 - abs(t - 0.52) * 1.9) + 9 * math.sin(k * 2.3) * (1 - abs(t - 0.5))) * z
            pts.append((x, gy - max(2 * z, hh)))
        pts.append((cx + 84 * z, gy)); P(pts)
        P([(cx - 12 * z, gy - 54 * z), (cx - 1 * z, gy - 78 * z), (cx + 8 * z, gy - 60 * z), (cx + 3 * z, gy - 52 * z), (cx - 3 * z, gy - 58 * z), (cx - 7 * z, gy - 50 * z)], RED if False else W)

# ---------------------------------------------------------------- the painting
def paint_place(name, zone):
    rnd = np.random.RandomState(seed_of(name))
    r = lambda: float(rnd.random_sample())
    biome = BIOME_OF.get(zone, "green")
    tint, tstr, ground, far, foliage = BIOMES[biome]
    times = ["day", "dawn", "dusk", "night", "storm"]
    wts = {"snow": [3, 2, 1, 2, 1], "dark": [1, 0, 2, 4, 3], "plague": [1, 0, 2, 3, 4], "fire": [1, 1, 3, 1, 3], "fel": [0, 0, 1, 4, 2], "elf": [1, 1, 2, 4, 0]}.get(biome, [5, 2, 2, 2, 1])
    tm = rnd.choice(times, p=np.array(wts, np.float32) / sum(wts))
    top, midc, hor, sunc, sunh, stars, bright = TIMES[tm]
    top, midc, hor = mix(top, tint, tstr), mix(midc, tint, tstr), mix(hor, tint, tstr * 0.8)
    night = tm == "night"
    dim = 0.42 if night else (0.8 if tm == "storm" else 1.0)
    cv = Canvas()
    yy = cv.y / SH
    kind = kind_for(name, biome, rnd)
    # sky
    g = np.clip(yy / 0.7, 0, 1)
    sky = np.where(g[..., None] < 0.5, mix(top, midc, (g[..., None] / 0.5)), mix(midc, hor, (g[..., None] - 0.5) / 0.5))
    cv.img = sky.astype(np.float32)
    sx = (0.15 + 0.7 * r()) * SW; sy = (1 - sunh) * SH * 0.62
    dist = np.sqrt((cv.x - sx) ** 2 + (cv.y - sy) ** 2)
    cv.add(sunc * 0.9, np.exp(-(dist / (SW * 0.20)) ** 2) * 0.55)
    # god rays
    ang = np.arctan2(cv.y - sy, cv.x - sx)
    rays = np.clip(np.sin(ang * 11 + rnd.uniform(0, 6)) * np.sin(ang * 5 + rnd.uniform(0, 6)), 0, 1) * np.exp(-dist / (SW * 0.5)) * (0.20 if tm in ("day", "dawn", "dusk") else 0.07)
    cv.add(sunc, rays)
    if night:
        cv.over(sunc, np.clip((16 - dist) / 2.0, 0, 1) * 0.95); cv.add(sunc, np.exp(-(dist / 38) ** 2) * 0.25)
    elif tm != "storm":
        cv.over(sunc, np.clip((10 - dist) / 2.0, 0, 1) * 0.9)
    if stars > 0.05:
        st = (rnd.random_sample((SH, SW)) > 0.9965).astype(np.float32)
        st = gaussian_filter(st, 0.7) * 9 * (1 - g) ** 1.4 * stars
        cv.add(np.array([1, 1, 1], np.float32), np.clip(st, 0, 1))
    cn = noise2(rnd, SH, SW, (7, 24)) + 0.6 * noise2(rnd, SH, SW, (3, 10))
    cl = np.clip((cn - 0.4) * 0.9, 0, 1) * np.clip(1 - yy * 1.25, 0, 1) * (0.45 if night or tm == "storm" else 0.65)
    lit = mix(hor, sunc, 0.55) if not (night or tm == "storm") else mix(top, hor, 0.5)
    shade = mix(midc, top, 0.4)
    cv.over(np.where((cl > 0.0)[..., None], mix(shade, lit, np.clip(1.2 - dist[..., None] / (SW * 0.9), 0, 1)), 0).astype(np.float32), cl)
    # far mountains
    mcol = [mix(far, hor, 0.58), mix(far, hor, 0.32), mix(far, np.array([0.05, 0.06, 0.1], np.float32), 0.28)]
    if night: mcol = [c * 0.45 + 0.02 for c in mcol]
    base = [SH * 0.52, SH * 0.60, SH * 0.67]
    amp = [SH * 0.22, SH * 0.16, SH * 0.11]
    if biome in ("plain", "farm", "coast", "swamp"): amp = [a * 0.5 for a in amp]
    if biome in ("snow", "hill", "fire"): amp = [a * 1.2 for a in amp]
    for i in range(3):
        f1 = fbm1(rnd, SW, 6, 0.62); ridged = 1 - np.abs(2 * f1 - 1)
        prof = base[i] - amp[i] * (0.55 * ridged + 0.45 * fbm1(rnd, SW, 5, 0.55) - 0.3)
        prof = gaussian_filter1d(prof, 1.2)
        P2 = prof[None, :].repeat(SH, 0)
        mask = gaussian_filter((cv.y >= P2).astype(np.float32), 0.6)
        depth = np.clip((cv.y - P2) / (SH * 0.3), 0, 1)
        colr = mcol[i][None, None, :] * (1.08 - 0.38 * depth[..., None])
        # lit slopes: brightness follows the ridge slope toward the sun
        slope = np.gradient(prof)
        sd = np.sign(sx - SW / 2) or 1
        facing = np.clip(-slope * sd * 2.2, -1, 1)[None, :] * np.exp(-np.clip(cv.y - P2, 0, None) / 5.0)
        colr = colr + (facing[..., None] * 0.12) * mix(sunc, hor, 0.4)[None, None, :] * (0.4 if night else 1)
        rim = np.exp(-np.clip(cv.y - P2, 0, None) / 1.8) * np.clip(1 - np.abs(cv.x - sx) / (SW * 0.8), 0.12, 1)
        colr = colr + sunc[None, None, :] * rim[..., None] * (0.22 if not night else 0.1)
        if biome in ("snow", "hill") or (i == 0 and amp[i] > SH * 0.2):
            hi = 1 / (1 + np.exp(-(SH * (0.47 + 0.03 * i) - prof) / 2.5))[None, :]
            cap = np.exp(-np.clip(cv.y - P2, 0, None) / (SH * 0.045)) * hi
            colr = mix(colr, col(236, 244, 255) * (0.5 if night else 1) + sunc * 0.05, np.clip(cap, 0, 1)[..., None] * 0.7)
        cv.over(colr.astype(np.float32), mask)
        fog = np.exp(-((cv.y - (P2 + 14)) / 15.0) ** 2) * 0.30
        cv.over(mix(hor, sunc, 0.2), fog * (cv.y > P2))
    # water
    water = kind in ("port", "lighthouse", "waterfall") or re.search(r"lake|bay|sea|river|coast|shore|isle|island|cove|reef|falls|marsh|swamp", name.lower())
    wl = SH * 0.71
    if water:
        wm = gaussian_filter((cv.y > wl).astype(np.float32), 0.7)
        refl = cv.img[np.clip((2 * wl - np.arange(SH)).astype(int), 0, SH - 1)]
        ripple = noise2(rnd, SH, SW, (0.8, 8)) * 0.05
        wc = mix(refl, mix(top, np.array([0.02, 0.07, 0.12], np.float32), 0.6), 0.45) + ripple[..., None]
        cv.over(wc.astype(np.float32), wm)
        sh = np.exp(-((cv.x - sx) / 16.0) ** 2) * np.clip((cv.y - wl) / 30, 0, 1) * (0.4 + 0.6 * np.clip(noise2(rnd, SH, SW, (0.6, 6)), 0, 2) / 2)
        cv.add(sunc, np.clip(sh, 0, 1) * wm * 0.55)
    # ground rise, a road and the landmark
    gx = (0.32 + 0.36 * r()) * SW
    gy0 = SH * (0.77 if water else 0.73)
    hump = 6 * np.exp(-((np.arange(SW) - gx) / (SW * 0.28)) ** 2)
    prof = gy0 + 5 * fbm1(rnd, SW, 4, 0.5) - 2.5 - hump
    prof = gaussian_filter1d(prof, 2.0)
    P2 = prof[None, :].repeat(SH, 0)
    mask = gaussian_filter((cv.y >= P2).astype(np.float32), 0.6)
    gcol = ground * dim
    tex = (noise2(rnd, SH, SW, (2.2, 3.2)) * 0.05 + noise2(rnd, SH, SW, (0.8, 1.0)) * 0.02)
    depthg = np.clip((cv.y - P2) / (SH * 0.35), 0, 1)
    colr = (gcol[None, None, :] + tex[..., None]) * (1.05 - 0.5 * depthg[..., None])
    colr = colr + mix(hor, sunc, 0.4)[None, None, :] * np.exp(-np.clip(cv.y - P2, 0, None) / 3.0)[..., None] * 0.16 * dim
    cv.over(colr.astype(np.float32), mask)
    gy = float(prof[int(np.clip(gx, 0, SW - 1))]) + 1.5
    # a winding road from the landmark to the viewer
    t = np.clip((cv.y - gy) / (SH - gy), 0, 1)
    rx = gx + np.sin(t * 5 + r() * 3) * 22 * t
    rw = 2.0 + 28 * t ** 1.4
    road = np.clip(1 - np.abs(cv.x - rx) / rw, 0, 1) ** 0.5 * (cv.y > gy + 2) * (kind not in ("port", "marsh", "waterfall") or True)
    if not (water and kind in ("port", "lighthouse")):
        roadc = mix(gcol, mix(hor, col(210, 190, 150), 0.6), 0.42) * (0.55 if night else 1)
        cv.over(roadc.astype(np.float32), road * 0.55 * (gaussian_filter(mask, 0.5)))
    # landmark: silhouette, then colour, light and detail
    size = {"volcano": 56, "peak": 60, "cave": 46, "waterfall": 54, "bridge": 44, "grove": 52, "crystal": 54}.get(kind, 58) * (0.9 + 0.2 * r())
    lay = draw_layer(lambda d, s: landmark(kind, d, s, gx, gy, size, None, np.random.RandomState(seed_of(name + "k"))))
    a = lay[..., 3]
    sil_mask = (lay[..., 1] > 0.5)          # white silhouette (green channel high)
    red = ((lay[..., 0] > 0.6) & (lay[..., 1] < 0.4) & (a > 0.3)).astype(np.float32)
    shape = np.clip(a, 0, 1)
    stone = mix(foliage, mix(far, hor, 0.25), 0.55) if kind in ("castle", "tower", "ruins", "lighthouse", "pyramid", "bridge", "totem", "graveyard", "mill", "camp") else mix(foliage, far, 0.2)
    if kind in ("pyramid", "ruins", "totem") and biome in ("desert", "red"): stone = mix(ground, hor, 0.3) * 0.85
    stone = stone * dim * 0.85
    sd = np.sign(sx - gx) or 1
    xr = (cv.x - gx) / (size * 0.9)
    side = np.clip(0.5 + 0.5 * xr * sd, 0.05, 1.0)            # lighter on the sun side
    vert = np.clip(1.0 - (gy - cv.y) / (size * 2.2), 0.55, 1.0)  # darker toward the top: sky glare behind
    bcol = stone[None, None, :] * (0.55 + 0.7 * side[..., None]) * vert[..., None]
    # sun-facing rim light
    shifted = np.roll(shape, int(-sd * 2), axis=1)
    rimm = np.clip(shape - shifted, 0, 1)
    rimm = gaussian_filter(rimm, 0.7)
    bcol = bcol + sunc[None, None, :] * rimm[..., None] * (0.9 if not night else 0.5)
    # haze toward the base and the horizon
    bcol = mix(bcol, mix(hor, sunc, 0.2)[None, None, :], np.clip(0.10 + 0.0, 0, 1))
    cv.over(bcol.astype(np.float32), shape * (1 - red))
    lit_col = col(255, 190, 96) if kind not in ("crystal", "waterfall") else col(170, 200, 255)
    if kind == "waterfall": lit_col = col(230, 244, 255)
    if kind == "crystal": lit_col = col(150, 190, 255)
    cv.over(lit_col[None, None, :].repeat(SH, 0).repeat(SW, 1), red)
    cv.add(lit_col, gaussian_filter(red, 4.5) * (0.9 if kind not in ("waterfall", "cave") else 0.45))
    cv.add(lit_col, gaussian_filter(red, 1.1) * 0.35)
    if kind == "volcano":
        cv.add(col(255, 110, 40), np.exp(-((cv.x - gx) / 24) ** 2) * np.exp(-((cv.y - (gy - size * 1.05)) / 30) ** 2) * 0.9)
        cv.add(col(255, 150, 60), np.exp(-((cv.x - gx) / 8) ** 2) * np.exp(-((cv.y - gy) / 12) ** 2) * 0.4)
        smoke = np.clip(noise2(rnd, SH, SW, (6, 10)) * 0.5 + 0.3, 0, 1) * np.exp(-((cv.x - (gx + 10)) / 26) ** 2) * (cv.y < gy - size * 1.2) * np.exp(-((cv.y - (gy - size * 1.3)) / 40) ** 2)
        cv.over(mix(top, np.array([0.15, 0.12, 0.12], np.float32), 0.5), smoke * 0.6)
    if kind == "camp":
        cv.add(col(255, 150, 60), np.exp(-((cv.x - (gx + 8)) / 14) ** 2) * np.exp(-((cv.y - (gy - 3)) / 12) ** 2) * 0.9)
        cv.over(col(255, 210, 120)[None, None, :].repeat(SH, 0).repeat(SW, 1), np.clip((3.2 - np.sqrt((cv.x - (gx + 8)) ** 2 + ((cv.y - (gy - 2)) * 1.5) ** 2)) / 1.5, 0, 1))
    if kind == "waterfall":
        mistw = np.exp(-((cv.x - gx) / 22) ** 2) * np.exp(-((cv.y - gy + 6) / 12) ** 2)
        cv.over(col(230, 242, 255), np.clip(mistw, 0, 1) * 0.6)
    # trees around the base (small conifers and round bushes), lit from the sun side
    def trees_layer(d, s):
        trng = np.random.RandomState(seed_of(name + "t"))
        n = 6 + int(trng.randint(0, 5))
        for _ in range(n):
            x0 = gx + trng.uniform(-1, 1) * SW * 0.42
            if abs(x0 - gx) < size * 0.55: x0 += (1 if x0 >= gx else -1) * size * 0.6
            yb = gy + trng.uniform(-1, 8); hh = trng.uniform(10, 22)
            if biome in ("snow", "dark", "elf", "green", "fel", "jungle", "hill", "plague", "coast") and trng.random_sample() > 0.2:
                for k in range(3):
                    ww = (6.5 - k * 1.5) * hh / 16; y2 = yb - k * hh * 0.26
                    d.polygon([((x0 - ww) * s, y2 * s), (x0 * s, (y2 - hh * 0.5) * s), ((x0 + ww) * s, y2 * s)], fill=(255, 255, 255, 255))
            else:
                continue
    tl = draw_layer(trees_layer)[..., 3]
    tcol = mix(foliage, np.array([0.01, 0.02, 0.04], np.float32), 0.72)[None, None, :] * (0.5 + 0.7 * np.clip(0.5 + 0.5 * ((cv.x - gx) / SW) * sd * 2, 0, 1))[..., None] * dim
    tcol = mix(tcol, mix(hor, sunc, 0.2)[None, None, :], 0.04) * 0.75
    cv.over(tcol.astype(np.float32), tl * (1 - np.clip(shape * 1.5, 0, 1)) * 0.95)
    # mist around the base
    mist = np.exp(-((cv.y - (gy + 1)) / 8.0) ** 2) * (0.45 + 0.55 * np.clip(noise2(rnd, SH, SW, (2, 16)), -1, 1))
    cv.over(mix(hor, sunc, 0.2), np.clip(mist, 0, 1) * (0.34 if biome in ("swamp", "plague", "dark", "snow") else 0.22))
    # foreground silhouettes
    def fgdraw(d, s):
        frng = np.random.RandomState(seed_of(name + "f"))
        fr = lambda: float(frng.random_sample())
        dkk = (255, 255, 255, 255)
        side_l = fr() > 0.5
        for _ in range(2 + int(fr() * 2)):
            x0 = (fr() * 0.28 + (0.0 if (side_l ^ (_ % 2 == 1)) else 0.72)) * SW
            hh = 28 + fr() * 36
            if biome in ("snow", "dark", "elf", "green", "fel", "jungle", "hill", "plague", "coast") and fr() > 0.25:
                for k in range(5):
                    ww = (13 - k * 2.2) * (hh / 40); yb = SH + 4 - k * (hh * 0.2)
                    d.polygon([((x0 - ww) * s, yb * s), (x0 * s, (yb - hh * 0.36) * s), ((x0 + ww) * s, yb * s)], fill=dkk)
                d.rectangle([(x0 - 1.4) * s, (SH - 14) * s, (x0 + 1.4) * s, SH * s], fill=dkk)
            else:
                for k in range(9):
                    xb = x0 + (k - 4) * 2.4
                    d.line([(xb * s, SH * s), ((xb + (fr() - 0.5) * 8) * s, (SH - 10 - fr() * 20) * s)], fill=dkk, width=int(1.8 * s))
        hill = fbm1(rnd, SW, 4, 0.5)
        for xi in range(SW):
            d.line([(xi * s, SH * s), (xi * s, (SH - 2 - hill[xi] * 8) * s)], fill=dkk, width=int(s))
    fl = draw_layer(fgdraw)[..., 3]
    fgc = mix(foliage, np.array([0.01, 0.01, 0.03], np.float32), 0.78)[None, None, :] * (0.7 if night else 1)
    cv.over(np.broadcast_to(fgc, (SH, SW, 3)).astype(np.float32), fl * 0.97)
    # particles by biome
    prng = np.random.RandomState(seed_of(name + "p"))
    pk = {"snow": ("snow", col(255, 255, 255)), "fire": ("ember", col(255, 150, 60)), "swamp": ("spore", col(190, 255, 150)), "plague": ("spore", col(170, 255, 120)),
          "fel": ("spore", col(150, 255, 90)), "elf": ("fly", col(190, 160, 255)), "dark": ("fly", col(255, 240, 160)), "blight": ("ember", col(255, 120, 80))}.get(biome)
    if night and not pk: pk = ("fly", col(255, 240, 160))
    if pk:
        pn = (prng.random_sample((SH, SW)) > 0.9993).astype(np.float32)
        pn = gaussian_filter(pn, 0.8) * 8
        cv.add(pk[1], np.clip(pn, 0, 1) * (0.9 if pk[0] != "snow" else 0.7))
    # global: bloom, vignette, grade, grain
    img = cv.img
    bl = np.clip(img - 0.6, 0, 1)
    img = img + gaussian_filter(bl, (3.5, 3.5, 0)) * 0.9
    vx = (cv.x / SW - 0.5) * 2; vy = (cv.y / SH - 0.5) * 2
    vig = 1 - 0.36 * np.clip((vx ** 2 * 0.6 + vy ** 2 * 0.9), 0, 1.3)
    img = img * vig[..., None]
    img = (img - 0.5) * 1.10 + 0.5 + 0.015
    img += (rnd.random_sample((SH, SW, 1)).astype(np.float32) - 0.5) * 0.015
    img = np.clip(img, 0, 1)
    out = Image.fromarray((img * 255).astype(np.uint8), "RGB").resize((CW, CH), Image.LANCZOS)
    return out, tm, kind

# ---------------------------------------------------------------- cards
def read_places():
    txt = open(os.path.join(ADDON, "ArcadeCards.lua"), encoding="utf-8").read()
    out = []
    for m in re.finditer(r'^\s*\{ 3, "((?:[^"\\]|\\.)*)", \d, \d+, "((?:[^"\\]|\\.)*)" \},', txt, re.M):
        name = m.group(1).replace('\\"', '"'); text = m.group(2)
        zone = name if text == "Zone" else text.replace("Found in ", "")
        out.append((name, zone))
    return out

def main():
    places = read_places()
    if len(sys.argv) > 1 and sys.argv[1] == "preview":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 48
        step = max(1, len(places) // n)
        sel = places[::step][:n]
        cols = 8
        sheet = Image.new("RGB", (cols * (CW * 2 + 6), (len(sel) + cols - 1) // cols * (CH * 2 + 6)), (14, 14, 24))
        for i, (nm, z) in enumerate(sel):
            im, tm, kd = paint_place(nm, z)
            sheet.paste(im.resize((CW * 2, CH * 2), Image.LANCZOS), ((i % cols) * (CW * 2 + 6), (i // cols) * (CH * 2 + 6)))
            print(i, nm, "|", z, "|", tm, kd)
        sheet.save(os.environ.get("PREVIEW", "/tmp/places.png"))
        return
    per = COLS * ROWS
    atlases = []; lookup = {}
    for i, (nm, z) in enumerate(places):
        a, c = divmod(i, per)
        while len(atlases) <= a: atlases.append(Image.new("RGB", (1024, 1024), (0, 0, 0)))
        im, _, _ = paint_place(nm, z)
        atlases[a].paste(im, ((c % COLS) * CW, (c // COLS) * CH))
        lookup[nm] = (a + 1, c)
    for a, im in enumerate(atlases):
        im.convert("RGBA").save(os.path.join(ADDON, "Media", "Arcade", "Places%d.tga" % (a + 1)))
    def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
    out = ["-- GENERATED by tools/arcade/art_places.py: do not edit by hand.", "local _, RG = ...",
           "-- place card name -> { atlas number, cell } on Media/Arcade/PlacesN.tga (8 x 12 cells of 120 x 84)", "RG.ARCADE_PLACE = {"]
    out += ["  [%s] = { %d, %d }," % (q(k), v[0], v[1]) for k, v in sorted(lookup.items())]
    out.append("}")
    open(os.path.join(ADDON, "ArcadePlaces.lua"), "w", encoding="utf-8").write("\n".join(out) + "\n")
    print(len(places), "places in", len(atlases), "atlases")

if __name__ == "__main__":
    main()
