"""Waypath+ grading art (our own drawing): the case, its shine, the grade seals, the wear layers, the return parcel,
its wax seal (whole and cracked), the grader's cloth and the Express stamp.
Drawn as HTML/SVG and rendered with Playwright (Chromium), the wear with PIL. Output in Media/Arcade:
  GradeCase.tga     512x1024  the case: acrylic, the engraved label plate, the well (top 834 rows: 296 x 482 units)
  GradeShine.tga    256x512   a diagonal sheen over the case (added on top)
  GradeSeals.tga    512x128   four seals of 128: gold, silver, bronze, and a dark one (not graded yet)
  Wear{Corners,Edges,Surface}{1-4}.tga  256x512  wear over a card (top 358 rows), worse with each step
  GradeParcel.tga   512x512   the parcel without its seal (left 395 columns: 440 x 570 units)
  GradeWax.tga      512x512   the wax seal whole (top left cell of 256), its left half (top right) and right half (bottom left)
  GradeCloth.tga    256x256   the grader's cloth
  GradeStamp.tga    256x64    the blue EXPRESS stamp
Run: python3 tools/arcade/art_grading.py
"""
import math, os, random, sys, tempfile
from PIL import Image, ImageDraw, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "Media", "Arcade")
FONTS = os.path.join(ROOT, "Media", "Fonts")
sys.path.insert(0, HERE)
from grading_parcel import parcel

FACES = "".join("@font-face{font-family:%s;src:url(file://%s/%s);}" % (n, FONTS, f) for n, f in [
    ("Cinzel", "Cinzel-SemiBold.ttf"), ("CinzelX", "Cinzel-ExtraBold.ttf"), ("Fraunces", "Fraunces-SemiBold.ttf"),
    ("Inter", "Inter-Regular.ttf"), ("InterM", "Inter-Medium.ttf"), ("InterS", "Inter-SemiBold.ttf")])

def render(html, w, h, path):
    from playwright.sync_api import sync_playwright
    doc = "<!doctype html><html><head><meta charset=utf-8><style>%s html,body{margin:0;background:transparent}</style></head><body>%s</body></html>" % (FACES, html)
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as f: f.write(doc); hp = f.name
    with sync_playwright() as p:
        b = p.chromium.launch(args=["--allow-file-access-from-files"])
        pg = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=1)
        pg.goto("file://" + hp); pg.wait_for_timeout(300)
        pg.screenshot(path=path, omit_background=True, clip={"x": 0, "y": 0, "width": w, "height": h})
        b.close()
    os.unlink(hp)
    return Image.open(path).convert("RGBA")

def tga(im, name):
    im.save(os.path.join(OUT, name + ".tga"))
    print("wrote", name, im.size)

# ---------------------------------------------------------------------------- the case (296 x 482 units at k = 512/296)
K = 512 / 296
def case():
    k = K
    html = f"""<div style="position:relative;width:{296*k}px;height:{482*k}px">
 <div style="position:absolute;inset:0;border-radius:{14*k}px;
   background:linear-gradient(135deg,rgba(235,242,250,.30),rgba(220,230,240,.10) 30%,rgba(230,238,246,.16) 60%,rgba(210,222,235,.08));
   box-shadow:inset 0 0 0 {1.4*k}px rgba(255,255,255,.55), inset 0 0 0 {6*k}px rgba(200,215,230,.10), inset 0 {2*k}px {6*k}px rgba(255,255,255,.18)"></div>
 <div style="position:absolute;left:{10*k}px;top:{10*k}px;width:{276*k}px;height:{74*k}px;border-radius:{7*k}px;
   background:linear-gradient(180deg,#2c2721,#1a1713);
   box-shadow:inset 0 0 0 {1*k}px #7a6136, inset 0 0 0 {3*k}px #14110d, inset 0 0 0 {4*k}px #4c3c21, 0 {1*k}px {2*k}px rgba(0,0,0,.6)"></div>
 <div style="position:absolute;left:{10*k}px;top:{94*k}px;width:{276*k}px;height:{378*k}px;border-radius:{8*k}px;
   background:rgba(4,4,8,.42);box-shadow:inset 0 0 0 {1*k}px rgba(255,255,255,.16), inset 0 {3*k}px {8*k}px rgba(0,0,0,.55)"></div>
</div>"""
    im = render(html, 512, 1024, os.path.join(tempfile.gettempdir(), "gcase.png"))
    tga(im, "GradeCase")
    # the shine: a soft diagonal streak (added, so black is nothing)
    sh = Image.new("RGBA", (256, 512), (0, 0, 0, 0)); d = ImageDraw.Draw(sh)
    hcase = int(482 / 296 * 256)
    for i in range(60):
        a = int(70 * math.sin(math.pi * i / 59) ** 2)
        x = 60 + i
        d.line([(x, 0), (x - 150, hcase)], fill=(a, a, a, 255), width=1)
    for i in range(20):
        a = int(40 * math.sin(math.pi * i / 19) ** 2)
        x = 150 + i
        d.line([(x, 0), (x - 150, hcase)], fill=(a, a, a, 255), width=1)
    sh = sh.filter(ImageFilter.GaussianBlur(3))
    tga(sh, "GradeShine")

# ---------------------------------------------------------------------------- the grade seals
def seals():
    cols = [("#ffe9a3", "#d9a630", "#7a5410"), ("#f2f4f7", "#a9b2bd", "#545c66"), ("#f0c39a", "#b5733f", "#5c3417"), ("#4a4238", "#2c2721", "#17140f")]
    cells = "".join(f"""<div style="position:absolute;left:{i*128+8}px;top:8px;width:112px;height:112px;border-radius:50%;
      background:radial-gradient(circle at 35% 30%,{a},{b} 60%,{c});
      box-shadow:0 0 0 3px rgba(0,0,0,.35), inset 0 0 12px rgba(0,0,0,.5), inset 0 0 0 7px rgba(255,255,255,.10), inset 0 0 0 8px rgba(0,0,0,.25)"></div>""" for i, (a, b, c) in enumerate(cols))
    tga(render(cells, 512, 128, os.path.join(tempfile.gettempdir(), "gseal.png")), "GradeSeals")

# ---------------------------------------------------------------------------- wear (256x512, card in the top 358 rows)
W, H = 256, 358
def corners(n, rng):
    im = Image.new("RGBA", (W, 512)); d = ImageDraw.Draw(im)
    r = [0, 6, 12, 19, 27][n]; a = [0, 170, 210, 235, 245][n]
    which = [(0, 0), (W, 0), (0, H), (W, H)] if n > 1 else [(W, 0)]
    for (cx, cy) in which:
        for _ in range(int(r * 7)):
            ang = rng.random() * math.tau; rr = rng.random() ** 2 * r
            x = cx + abs(math.cos(ang)) * rr * (1 if cx == 0 else -1); y = cy + abs(math.sin(ang)) * rr * (1 if cy == 0 else -1)
            s = rng.uniform(0.6, 1.8); d.ellipse([x - s, y - s, x + s, y + s], fill=(245, 240, 228, int(a * rng.uniform(.5, 1))))
        if n >= 3:   # a rounded-off corner: the card's dark edge worn away into the case
            rr = [0, 0, 0, 5, 9][n]
            ox = cx + (rr if cx == 0 else -rr); oy = cy + (rr if cy == 0 else -rr)
            d.pieslice([ox - rr, oy - rr, ox + rr, oy + rr], 0, 360, fill=(0, 0, 0, 0))
    return im.filter(ImageFilter.GaussianBlur(0.4))
def edges(n, rng):
    im = Image.new("RGBA", (W, 512)); d = ImageDraw.Draw(im)
    count = [0, 5, 14, 28, 46][n]; a = [0, 150, 190, 220, 235][n]
    for _ in range(count):
        side = rng.randrange(4); t = rng.random(); L = rng.uniform(3, 12 + 3 * n); dep = rng.uniform(0.8, 1.2 + 0.5 * n)
        if side < 2: x = t * W; y = 0 if side == 0 else H - dep; d.rectangle([x, y, x + L, y + dep], fill=(240, 234, 220, a))
        else: y = t * H; x = 0 if side == 2 else W - dep; d.rectangle([x, y, x + dep, y + L], fill=(240, 234, 220, a))
    return im.filter(ImageFilter.GaussianBlur(0.35))
def surface(n, rng):
    im = Image.new("RGBA", (W, 512)); d = ImageDraw.Draw(im)
    k = [0, 6, 14, 24, 34][n]; a = [0, 80, 110, 135, 150][n]; mx = [0, 40, 60, 85, 110][n]
    for _ in range(k):
        x, y = rng.uniform(8, W - 8), rng.uniform(8, H - 8); ang = rng.uniform(-.5, .5) + (math.pi / 4 if rng.random() < .5 else 0)
        L = rng.uniform(mx * .3, mx); pts = [(x + math.cos(ang) * L * i / 7 + rng.uniform(-.7, .7), y + math.sin(ang) * L * i / 7 + rng.uniform(-.7, .7)) for i in range(8)]
        d.line(pts, fill=(255, 255, 255, int(a * rng.uniform(.5, 1))), width=1)
    im = im.filter(ImageFilter.GaussianBlur(0.4))
    if n >= 3:   # a dull, yellowed wash over the whole card
        wash = Image.new("RGBA", (W, 512)); ImageDraw.Draw(wash).rectangle([0, 0, W, H], fill=(205, 190, 160, 40 if n == 3 else 70))
        im = Image.alpha_composite(wash, im)
    if n >= 4:   # a crease right across, and a water stain
        c = Image.new("RGBA", (W, 512)); cd = ImageDraw.Draw(c)
        y0, y1 = H * 0.30, H * 0.47
        cd.line([(0, y0), (W, y1)], fill=(30, 22, 14, 170), width=3); cd.line([(0, y0 - 2), (W, y1 - 2)], fill=(255, 250, 235, 200), width=1)
        im = Image.alpha_composite(im, c.filter(ImageFilter.GaussianBlur(0.8)))
        s = Image.new("RGBA", (W, 512)); sd = ImageDraw.Draw(s)
        sd.ellipse([150, 215, 235, 285], fill=(120, 85, 40, 70)); sd.ellipse([159, 224, 226, 276], fill=(0, 0, 0, 0))
        sd.ellipse([153, 218, 232, 282], outline=(110, 75, 35, 110), width=2)
        im = Image.alpha_composite(im, s.filter(ImageFilter.GaussianBlur(2)))
    return im
def wear():
    for name, fn in (("Corners", corners), ("Edges", edges), ("Surface", surface)):
        for n in range(1, 5):
            tga(fn(n, random.Random(7 + n)), "Wear%s%d" % (name, n))

# ---------------------------------------------------------------------------- the parcel, its seal, the cloth, the stamp
SEAL_DEFS = """<defs>
 <radialGradient id="wax" cx=".38" cy=".32" r=".75"><stop offset="0" stop-color="#d0412f"/><stop offset=".55" stop-color="#9b1f17"/><stop offset="1" stop-color="#5a0d09"/></radialGradient>
 <radialGradient id="waxIn" cx=".6" cy=".65" r=".7"><stop offset="0" stop-color="#7d1610"/><stop offset="1" stop-color="#b22a1e"/></radialGradient>
 <filter id="soft"><feDropShadow dx="0" dy="2" stdDeviation="1.6" flood-color="#2a1606" flood-opacity=".55"/></filter>
 <path id="ring" d="M190,250 m-36,0 a36,36 0 1,1 72,0 a36,36 0 1,1 -72,0"/>
 <clipPath id="L"><path d="M120,180 L190,180 L184,214 L196,232 L186,252 L198,272 L188,296 L194,320 L120,320 Z"/></clipPath>
 <clipPath id="R"><path d="M260,180 L190,180 L184,214 L196,232 L186,252 L198,272 L188,296 L194,320 L260,320 Z"/></clipPath>
</defs>"""
BLOB = "M190,196 C214,194 234,206 242,222 C252,238 250,262 240,278 C232,294 214,306 192,306 C168,308 148,296 140,280 C130,262 128,238 140,222 C148,206 166,198 190,196 Z"
STAR = "M190,226 L196,244 L214,250 L196,256 L190,274 L184,256 L166,250 L184,244 Z"
FACE = f'<path d="{BLOB}" fill="url(#wax)"/><circle cx="190" cy="251" r="44" fill="url(#waxIn)" opacity=".9"/><circle cx="190" cy="251" r="27" fill="none" stroke="#4d0a06" stroke-opacity=".55"/><path d="{STAR}" fill="#c9442f"/>'
WHOLE = f'''<g filter="url(#soft)">{FACE}
  <circle cx="190" cy="251" r="44" fill="none" stroke="#e0644e" stroke-opacity=".35" stroke-width="1.2"/>
  <path d="{STAR}" fill="#5a0d09" opacity=".75" transform="translate(1,1.5)"/><path d="{STAR}" fill="#c9442f"/>
  <text font-family="Cinzel" font-size="7.4" fill="#f1a08a" fill-opacity=".75" letter-spacing="1.6"><textPath href="#ring" startOffset="2%">WAYPOINT · GRADING · GUILD · EST. 2026 ·</textPath></text>
  <ellipse cx="174" cy="226" rx="16" ry="7" fill="#fff" opacity=".18" transform="rotate(-30 174 226)"/></g>'''
def svgcell(x, inner):   # one 256-cell: the seal's 128x128-unit box (130..250, 190..310) at 2x
    return f'<svg style="position:absolute;left:{x}px;top:0" width="256" height="256" viewBox="126 187 128 128">{SEAL_DEFS}{inner}</svg>'
def parcelart():
    svg = parcel("sealed", "g", game=True).replace("<svg ", '<svg style="display:block" width="395" height="512" ', 1)
    tga(render(svg, 512, 512, os.path.join(tempfile.gettempdir(), "gparcel.png")), "GradeParcel")
    # (three cells of 256, each the seal's box: whole | left half (top right) | right half (bottom left); the halves sit
    # where they were on the whole seal, so the add-on can draw them over it and move them apart)
    html = (svgcell(0, WHOLE) + svgcell(256, f'<g filter="url(#soft)" clip-path="url(#L)">{FACE}</g>')
            + svgcell(0, f'<g filter="url(#soft)" clip-path="url(#R)">{FACE}</g>').replace("top:0", "top:256px"))
    tga(render(html, 512, 512, os.path.join(tempfile.gettempdir(), "gwax.png")), "GradeWax")
    cloth = '<div style="width:256px;height:256px;background:repeating-linear-gradient(100deg,#2c2438 0 12px,#251e30 12px 24px);box-shadow:inset 0 -20px 40px rgba(0,0,0,.5)"></div>'
    tga(render(cloth, 256, 256, os.path.join(tempfile.gettempdir(), "gcloth.png")), "GradeCloth")
    stamp = ('<svg width="256" height="64" viewBox="0 0 256 64"><filter id="ink"><feTurbulence type="fractalNoise" baseFrequency="1.6" numOctaves="2" seed="2"/>'
             '<feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 -2.2 1.5"/><feComposite in="SourceGraphic" operator="in"/></filter>'
             '<g filter="url(#ink)"><rect x="6" y="6" width="244" height="52" rx="5" fill="none" stroke="#1f4f9a" stroke-width="4"/>'
             '<text x="128" y="44" text-anchor="middle" font-family="CinzelX" font-size="30" fill="#1f4f9a" letter-spacing="5">EXPRESS</text></g></svg>')
    tga(render(stamp, 256, 64, os.path.join(tempfile.gettempdir(), "gstamp.png")), "GradeStamp")

if __name__ == "__main__":
    case(); seals(); wear(); parcelart()
