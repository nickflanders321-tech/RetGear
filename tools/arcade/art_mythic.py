"""The Mythic cards' own art (Media/Arcade/Mythic1..6.tga), their turning prismatic edges (Prism.tga, PrismRing.tga)
and the card-shaped mask (CardMask.tga).

Each card is drawn from an SVG scene in tools/arcade/mythic/ (original Waypath+ art), with the name plate, type line,
rarity badge and collector number painted on, then cut to the card's shape. The rules text, the engraving and the
numbers are drawn by the add-on on top (Arcade.lua). The 1 Ring is full art: the ring is painted in its SVG too.

Needs Python Playwright with Chromium (to render the SVG and the lettering):  python3 tools/arcade/art_mythic.py
"""
import math, os, sys
from PIL import Image
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "Media", "Arcade")
FONT = os.path.abspath(os.path.join(HERE, "..", "..", "Media", "Fonts", "Cinzel-ExtraBold.ttf"))
PREVIEW = len(sys.argv) > 1 and sys.argv[1] == "preview"
PREV = "/tmp/arcade_preview"
W, H = 256, 358          # the card, in card units (the texture is 256x512: the card is its top 358 rows)
S = 2                    # drawn at twice the size, then scaled down

# name, svg, plate text size, type line, badge, number, dark ground (for the fade under the text), type colour, flavour
CARDS = [
    ("The Wanderer", "1_wanderer", 19, "RAIDER  ·  MYTHIC", "MYTHIC", "M-01", "10,8,24", "#e9dcff", "Sixty levels. Every road, walked once."),
    ("The First Waypoint", "2_waypoint", 17, "PLACE  ·  SPELL  ·  MYTHIC", "MYTHIC", "M-02", "6,13,28", "#d6e8ff", "Follow the arrow."),
    ("The Last Campfire", "3_campfire", 17, "CAMP  ·  MYTHIC", "MYTHIC", "M-03", "15,7,6", "#ffd9c2", "Camping 101, the final lesson."),
    ("SIXTY", "4_sixty", 20, "SPELL  ·  MYTHIC", "MYTHIC", "M-04", "18,13,4", "#ffeec2", "The last level is the loudest."),
    ("The Hourglass of Forever", "5_hourglass", 14, "ARTIFACT  ·  SPELL  ·  MYTHIC", "MYTHIC", "M-05", "6,5,4", "#ffeec2", "The sand never runs out."),
    ("The 1 Ring", "6_ring", 20, "ITEM  ·  SPELL  ·  MYTHIC", "1 OF 1", "M-00", "4,6,3", "#d6f5c8", ""),
]

def page_html(name, svg, size, typ, badge, num, dark, typecol, flavour, ring):
    slot = ""
    if ring:
        # the five +1s under the Ring (the Ring itself is painted in the SVG, full art, since 1.43.4)
        stats = "".join('<span style="padding:%dpx %dpx;border-radius:99px;background:rgba(6,8,5,.8);border:1px solid #5cff3b">+1 %s</span>'
                        % (1 * S, 4 * S, s) for s in ("STR", "AGI", "STA", "INT", "SPI"))
        slot += ('<div style="position:absolute;left:0;top:%dpx;width:%dpx;display:flex;justify-content:center;gap:%dpx;'
                 'font:800 %dpx Cz;letter-spacing:%dpx;color:#b9ffa6">%s</div>' % (212 * S, W * S, 3 * S, 6 * S, 0, stats))
    badge_css = ("background:linear-gradient(180deg,#fff7d6,#d9a441);border:1px solid #fff;color:#1d1405" if ring
                 else "background:rgba(%s,.8);border:1px solid rgba(255,233,168,.75);color:#ffe9a8" % dark)
    return """<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:Cz;src:url('file://%(font)s')}
html,body{margin:0;background:transparent}
#c{position:relative;width:%(w)dpx;height:%(h)dpx;overflow:hidden}
#c>svg{position:absolute;left:0;top:0;width:100%%;height:100%%}
text{font-family:Cz}
</style></head><body><div id="c">%(svg)s%(slot)s
<div style="position:absolute;left:0;top:%(fadeTop)dpx;width:100%%;height:%(fadeH)dpx;background:linear-gradient(180deg,rgba(%(dark)s,0),rgba(%(dark)s,.92) 22%%,rgba(%(dark)s,.98))"></div>
<div style="position:absolute;left:%(pl)dpx;top:%(pt)dpx;width:%(pw)dpx;height:%(ph)dpx;box-sizing:border-box;border-radius:%(pr)dpx;background:linear-gradient(180deg,#ffffff,#f6e7b4 28%%,#c99a3f 62%%,#8a6220);border:1px solid #fff3c9;box-shadow:0 %(sh)dpx %(sh2)dpx rgba(0,0,0,.6);display:flex;align-items:center;justify-content:center;font:800 %(size)dpx Cz;letter-spacing:%(ls)dpx;color:#1d1405;white-space:nowrap">%(name)s</div>
<div style="position:absolute;left:0;top:%(tt)dpx;width:100%%;text-align:center;font:800 %(ts)dpx Cz;letter-spacing:%(tls)dpx;color:%(typecol)s">%(typ)s</div>
<div style="position:absolute;left:0;top:%(ft)dpx;width:100%%;text-align:center;font:italic %(fs)dpx Georgia,serif;color:%(typecol)s;opacity:.85">%(flavour)s</div>
<div style="position:absolute;right:%(br)dpx;top:%(bt)dpx;padding:%(bp)dpx %(bp2)dpx;border-radius:99px;%(badge_css)s;font:800 %(bs)dpx Cz;letter-spacing:%(bls)dpx">%(badge)s</div>
<div style="position:absolute;left:0;top:%(nt)dpx;width:100%%;text-align:center;font:800 %(ns)dpx Cz;letter-spacing:%(bls)dpx;color:#f4efe2;text-shadow:0 1px 3px rgba(0,0,0,.9)">%(num)s</div>
</div></body></html>""" % dict(font=FONT, w=W * S, h=H * S, svg=svg, slot=slot, dark=dark, fadeTop=214 * S, fadeH=(H - 214) * S,
                               pl=14 * S, pt=232 * S, pw=228 * S, ph=30 * S, pr=6 * S, sh=2 * S, sh2=5 * S, size=size * S, ls=int(0.5 * S),
                               name=name, tt=266 * S, ts=7 * S, tls=int(1.2 * S), typecol=typecol, typ=typ,
                               ft=337 * S, fs=int(7.5 * S), flavour=flavour,
                               br=10 * S, bt=11 * S, bp=3 * S, bp2=7 * S, badge_css=badge_css, bs=int(7.5 * S), bls=2 * S, badge=badge,
                               nt=4 * S, ns=7 * S, num=num)

def save(name, im):
    im.save(os.path.join(OUT, name + ".tga"), compression=None)
    if PREVIEW:
        os.makedirs(PREV, exist_ok=True)
        bg = Image.new("RGBA", im.size, (40, 40, 52, 255)); bg.alpha_composite(im); bg.save(os.path.join(PREV, name + ".png"))
    print("wrote", name, im.size)

def conic(stops, size=256):
    """A colour wheel: stops go once around."""
    im = Image.new("RGBA", (size, size)); px = im.load()
    n = len(stops)
    for y in range(size):
        for x in range(size):
            a = (math.atan2(y - size / 2 + 0.5, x - size / 2 + 0.5) / (2 * math.pi)) % 1.0 * n
            i = int(a) % n; f = a - int(a)
            c0, c1 = stops[i], stops[(i + 1) % n]
            px[x, y] = tuple(int(c0[k] + (c1[k] - c0[k]) * f) for k in range(3)) + (255,)
    return im

def hexs(*cols): return [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in cols]

# The letters The 1 Ring engraves its opener's name with, in game (Arcade.lua places them round the band): one 32 px
# cell each on an 8x8 sheet, drawn like the line baked into the art (dark Cinzel, a light edge below), and each letter's
# width (in ems) written into ArcadeMythic.lua between its "ring glyphs" markers.
GLYPHS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ") + ["\u2726", "'", "-", " "] + list("\u00c0\u00c1\u00c2\u00c3\u00c4\u00c5\u00c6\u00c7\u00c8\u00c9\u00ca\u00cb\u00cc\u00cd\u00ce\u00cf\u00d0\u00d1\u00d2\u00d3\u00d4\u00d5\u00d6\u00d8\u00d9\u00da\u00db\u00dc\u00dd\u00de\u00df")
GCELL, GEM = 32, 22

def glyph_sheet(pg):
    import base64, json
    font64 = base64.b64encode(open(FONT, "rb").read()).decode()
    pg.set_content("""<!doctype html><html><head><meta charset="utf-8"><style>@font-face{font-family:Cz;src:url(data:font/ttf;base64,%s)}
html,body{margin:0;background:transparent}</style></head><body><canvas id="g" width="256" height="256"></canvas>
<span style="font-family:Cz">x</span></body></html>""" % font64)
    pg.wait_for_timeout(300)
    out = pg.evaluate("""([chars, cell, em]) => document.fonts.load(em + 'px Cz').then(() => {
      const c = document.getElementById('g'), x = c.getContext('2d'), w = [];
      x.font = em + 'px Cz'; x.textAlign = 'center'; x.textBaseline = 'middle';
      chars.forEach((ch, i) => {
        const cx = (i % 8) * cell + cell / 2, cy = Math.floor(i / 8) * cell + cell / 2 + 1;
        x.fillStyle = 'rgba(255,246,216,0.7)'; x.fillText(ch, cx + 1.2, cy + 1.5);
        x.fillStyle = '#4a2d05'; x.fillText(ch, cx, cy);
        w.push(x.measureText(ch).width / em);
      });
      return [c.toDataURL('image/png'), w];
    })""", [GLYPHS, GCELL, GEM])
    import io
    im = Image.open(io.BytesIO(base64.b64decode(out[0].split(",")[1]))).convert("RGBA")
    save("RingGlyphs", im)
    lua = os.path.join(HERE, "..", "..", "ArcadeMythic.lua")
    src = open(lua, encoding="utf-8").read()
    rows = ", ".join('["%s"] = { %d, %.3f }' % (ch.replace("\\", "\\\\").replace('"', '\\"'), i, wd) for i, (ch, wd) in enumerate(zip(GLYPHS, out[1])))
    block = "-- ring glyphs (written by tools/arcade/art_mythic.py): letter -> { cell on RingGlyphs.tga, width in ems }\n" \
            "RG.ARCADE_RING_GLYPHS = { cell = %d, em = %d, %s }\n-- ring glyphs end\n" % (GCELL, GEM, rows)
    a, b = src.find("-- ring glyphs ("), src.find("-- ring glyphs end\n")
    src = src[:a] + block + src[b + len("-- ring glyphs end\n"):] if a >= 0 and b > a else src.rstrip("\n") + "\n\n" + block
    open(lua, "w", encoding="utf-8").write(src)

def main():
    body = Image.open(os.path.join(OUT, "Body.tga")).convert("RGBA")
    alpha = body.split()[3].point(lambda v: 255 if v > 200 else (0 if v < 8 else v))   # the card's shape
    mask = Image.new("RGBA", body.size, (255, 255, 255, 0)); mask.putalpha(alpha); save("CardMask", mask)
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={"width": W * S, "height": H * S}, device_scale_factor=1)
        for i, (name, svgname, size, typ, badge, num, dark, typecol, flavour) in enumerate(CARDS, 1):
            svg = open(os.path.join(HERE, "mythic", svgname + ".svg")).read()
            pg.set_content(page_html(name, svg, size, typ, badge, num, dark, typecol, flavour, i == 6))
            pg.wait_for_timeout(250)
            tmp = "/tmp/mythic_%d.png" % i
            pg.locator("#c").screenshot(path=tmp, omit_background=True)
            art = Image.open(tmp).convert("RGBA").resize((W, H), Image.LANCZOS)
            out = Image.new("RGBA", body.size, (0, 0, 0, 0)); out.paste(art, (0, 0))
            out.putalpha(alpha)
            save("Mythic%d" % i, out)
        glyph_sheet(pg)
        b.close()
    save("Prism", conic(hexs("#ffe08a", "#ff9ecb", "#b58cff", "#6fd6ff", "#8affc9") * 2))
    save("PrismRing", conic(hexs("#060805", "#fff7d6", "#5cff3b", "#060805", "#ffffff", "#d9a441") * 2))

if __name__ == "__main__":
    main()
