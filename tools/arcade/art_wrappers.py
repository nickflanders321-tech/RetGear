"""The three booster wrappers' own pictures: PackArt1..3.tga (the wrapper below the tear line) and PackArtTop1..3.tga
(the strip that tears off). 1 = Pack (night violet, the compass), 2 = Jumbo (ember copper, the camp under the peaks),
3 = Super Jumbo (deep teal, the hourglass). Original Waypath+ art.

The picture is drawn as a web page (Playwright), then given the foil's shading (crimps, bevel, sheen bands) and the
wrapper's exact shape from PackBody.tga / PackTop.tga, which tools/arcade/art_packs.py draws: run that one first.
    python3 tools/arcade/art_wrappers.py [preview]
"""
import base64, io, os, sys
import numpy as np
from PIL import Image
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "Media", "Arcade")
FONT = os.path.abspath(os.path.join(HERE, "..", "..", "Media", "Fonts", "Cinzel-ExtraBold.ttf"))
PREVIEW = len(sys.argv) > 1 and sys.argv[1] == "preview"
S = 2

COMPASS = '''<svg viewBox="0 0 200 200" width="{d}" height="{d}">
<circle cx="100" cy="100" r="92" fill="#17112f" stroke="#f5d273" stroke-width="4"/>
<circle cx="100" cy="100" r="78" fill="none" stroke="#f5d273" stroke-width="1.5" stroke-dasharray="2 7"/>
<polygon points="100,16 113,87 184,100 113,113 100,184 87,113 16,100 87,87" fill="#f5d273"/>
<polygon points="100,16 100,100 113,87" fill="#fff3c4"/><polygon points="100,184 100,100 87,113" fill="#b98b2e"/>
<polygon points="184,100 100,100 113,113" fill="#b98b2e"/><polygon points="16,100 100,100 87,87" fill="#fff3c4"/>
<polygon points="100,52 108,92 148,100 108,108 100,148 92,108 52,100 92,92" fill="#17112f" transform="rotate(45 100 100)"/>
<circle cx="100" cy="100" r="9" fill="#fff3c4" stroke="#17112f" stroke-width="3"/></svg>'''
CAMP = '''<svg viewBox="0 0 200 200" width="{d}" height="{d}">
<defs><radialGradient id="s" cx="0.5" cy="0.8" r="0.85"><stop offset="0" stop-color="#ffb347"/><stop offset="0.5" stop-color="#7a2a10"/><stop offset="1" stop-color="#1c0b06"/></radialGradient>
<clipPath id="cl"><circle cx="100" cy="100" r="90"/></clipPath></defs>
<circle cx="100" cy="100" r="92" fill="url(#s)" stroke="#ffe2a8" stroke-width="4"/>
<g clip-path="url(#cl)"><polygon points="0,160 56,66 84,108 118,46 200,160 200,200 0,200" fill="#2a1009"/>
<polygon points="118,46 133,70 122,66 113,80 105,68" fill="#ffe9c2"/><polygon points="56,66 67,84 56,80 48,90" fill="#ffe9c2"/>
<rect x="0" y="158" width="200" height="50" fill="#1c0b06"/></g>
<path d="M100 176 C82 160 89 140 100 122 C111 140 118 160 100 176 Z" fill="#ffd36b"/>
<path d="M100 176 C91 167 94 156 100 147 C106 156 109 167 100 176 Z" fill="#fff6d8"/>
<path d="M76 180 L124 171 M76 171 L124 180" stroke="#5a2a10" stroke-width="7" stroke-linecap="round"/>
<circle cx="150" cy="52" r="2.5" fill="#fff6d8"/><circle cx="42" cy="44" r="2" fill="#fff6d8"/><circle cx="92" cy="30" r="1.8" fill="#fff6d8"/></svg>'''
GLASS = '''<svg viewBox="0 0 200 200" width="{d}" height="{d}">
<circle cx="100" cy="100" r="92" fill="#04201f" stroke="#fff3c4" stroke-width="4"/>
<circle cx="100" cy="100" r="78" fill="none" stroke="#fff3c4" stroke-width="1.5" stroke-dasharray="2 7"/>
<rect x="58" y="34" width="84" height="11" rx="4" fill="#f5d273"/><rect x="58" y="155" width="84" height="11" rx="4" fill="#f5d273"/>
<path d="M67 45 H133 C133 78 110 89 105 100 C110 111 133 122 133 155 H67 C67 122 90 111 95 100 C90 89 67 78 67 45 Z" fill="#0c4a46" stroke="#fff3c4" stroke-width="3"/>
<path d="M76 56 H124 C120 75 107 84 100 93 C93 84 80 75 76 56 Z" fill="#f5d273"/>
<path d="M100 97 V144" stroke="#f5d273" stroke-width="3" stroke-dasharray="3 5"/>
<path d="M79 153 C83 139 93 135 100 132 C107 135 117 139 121 153 Z" fill="#f5d273"/>
<path d="M30 100 l7 -7 l7 7 l-7 7 Z M156 100 l7 -7 l7 7 l-7 7 Z" fill="#fff3c4"/></svg>'''

# name, emblem, foil gradient, gold line, ribbon gradient, ribbon ink, name size
PACKS = [
    ("PACK", COMPASS, "#2b2158 0%,#5b47b0 22%,#2a2057 40%,#6a58c4 58%,#241b4c 78%,#4b3a96 100%", "#f5d273", "#fff3c4,#f5d273 50%,#b98b2e", "#1d1405", 21),
    ("JUMBO", CAMP, "#6e2c0c 0%,#d9772a 22%,#6a2a0b 40%,#e8913c 58%,#5a2208 78%,#b85d1e 100%", "#ffe2a8", "#fff6d8,#ffd36b 50%,#c98a1e", "#2a1206", 21),
    ("SUPER JUMBO", GLASS, "#073c3a 0%,#1fa79a 22%,#06302f 40%,#36c9b8 58%,#052826 78%,#128377 100%", "#fff3c4", "#ffffff,#fff3c4 45%,#d9a441", "#062624", 16),
]

def logo_uri():
    im = Image.open(os.path.join(HERE, "..", "..", "Media", "LogoLarge.tga")).convert("RGBA")
    b = io.BytesIO(); im.save(b, "PNG")
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()

def page(name, emblem, foil, line, ribbon, ink, size, logo):
    px = lambda v: "%dpx" % round(v * S)
    return """<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:Cz;src:url('file://%(font)s')}
html,body{margin:0}
#c{position:relative;width:%(w)s;height:%(h)s;overflow:hidden;background:linear-gradient(120deg,%(foil)s)}
#c>*{position:absolute}
</style></head><body><div id="c">
<div style="left:%(fx)s;top:%(fy)s;width:%(fw)s;height:%(fh)s;box-sizing:border-box;border:%(b1)s solid %(line)s;border-radius:%(r)s"></div>
<div style="left:0;top:%(ty)s;width:%(w)s;display:flex;align-items:center;justify-content:center;gap:%(g)s;font:800 %(ts)s Cz;letter-spacing:%(tl)s;color:%(line)s">
<img src="%(logo)s" style="width:%(ls)s;height:%(ls)s"><span>WAYPATH ARENA</span></div>
<div style="left:%(ex)s;top:%(ey)s">%(emblem)s</div>
<div style="left:%(rx)s;top:%(ry)s;width:%(rw)s;height:%(rh)s;box-sizing:border-box;border-radius:%(rr)s;background:linear-gradient(180deg,%(ribbon)s);border:%(b1)s solid #fffbe8;display:flex;align-items:center;justify-content:center;font:800 %(ns)s Cz;letter-spacing:%(nl)s;color:%(ink)s;white-space:nowrap">%(name)s</div>
</div></body></html>""" % dict(font=FONT, w=px(256), h=px(512), foil=foil, line=line, ribbon=ribbon, ink=ink, name=name, logo=logo,
        fx=px(16), fy=px(110), fw=px(224), fh=px(284), b1=px(1.2), r=px(8),
        ty=px(118), g=px(5), ts=px(10), tl=px(2.2), ls=px(22),
        ex=px(128 - 71), ey=px(142), emblem=emblem.format(d=round(142 * S)),
        rx=px(30), ry=px(296), rw=px(196), rh=px(34), rr=px(6), ns=px(size), nl=px(2))

def shading(grey, panels):
    """The foil's light and dark (crimps, bevel, sheen bands) from the grey wrapper; its dark label panels are filled in."""
    g = np.asarray(grey.convert("RGBA"), dtype=np.float32)[..., 0] / 255.0
    if panels:
        ys, xs = np.mgrid[0:g.shape[0], 0:g.shape[1]].astype(np.float32)
        def pointed(x0, x1, y0, y1, pt):
            cy = (y0 + y1) / 2; hh = (y1 - y0) / 2
            xin = np.clip(np.minimum(xs - x0, x1 - xs), 0, None)
            return (xs > x0) & (xs < x1) & (np.abs(ys - cy) < np.where(xin < pt, hh * xin / pt, hh))
        dark = pointed(15, 241, 127, 179, 16) | pointed(25, 231, 351, 391, 12) | (np.sqrt((xs - 128) ** 2 + (ys - 252) ** 2) < 67.5)
        # fill the panels from the foil around them
        from scipy.ndimage import gaussian_filter, binary_dilation
        dark = binary_dilation(dark, iterations=3)
        keep = (~dark).astype(np.float32)
        fill = (gaussian_filter(g * keep, 14) + 0.5 * 0.03) / (gaussian_filter(keep, 14) + 0.03)   # (far from any foil: mid grey)
        g = np.where(dark, fill, g)
    return np.clip(0.42 + 1.15 * g, 0.35, 1.5)

def main():
    body = Image.open(os.path.join(OUT, "PackBody.tga")).convert("RGBA")
    top = Image.open(os.path.join(OUT, "PackTop.tga")).convert("RGBA")
    sb, st = shading(body, True), shading(top, False)
    logo = logo_uri()
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={"width": 256 * S, "height": 512 * S}, device_scale_factor=1)
        for i, (name, emblem, foil, line, ribbon, ink, size) in enumerate(PACKS, 1):
            pg.set_content(page(name, emblem, foil, line, ribbon, ink, size, logo)); pg.wait_for_timeout(300)
            tmp = "/tmp/wrapper_%d.png" % i
            pg.locator("#c").screenshot(path=tmp)
            art = np.asarray(Image.open(tmp).convert("RGB").resize((256, 512), Image.LANCZOS), dtype=np.float32)
            for nm, shade, src, hgt in (("PackArt%d" % i, sb, body, 512), ("PackArtTop%d" % i, st, top, 128)):
                rgb = np.clip(art[:hgt] * shade[..., None], 0, 255).astype(np.uint8)
                im = Image.fromarray(np.dstack([rgb, np.asarray(src)[..., 3]]), "RGBA")
                im.save(os.path.join(OUT, nm + ".tga"), compression=None)
                if PREVIEW:
                    os.makedirs("/tmp/arcade_preview", exist_ok=True)
                    bg = Image.new("RGBA", im.size, (30, 30, 40, 255)); bg.alpha_composite(im); bg.save("/tmp/arcade_preview/%s.png" % nm)
                print("wrote", nm)
        b.close()

if __name__ == "__main__":
    main()
