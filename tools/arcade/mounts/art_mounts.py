"""The mount Mythics' own art (Media/Arcade/MythicMount01..26.tga): each card is a mount's model from the game (rendered by
tools/render, kept in models/) on a painted backdrop made by bggen.py, with the name plate, type line, badge and number
painted on, then cut to the card's shape. The rules text is drawn by the add-on (Arcade.lua), like the other Mythics.

Needs Python Playwright with Chromium:  python3 tools/arcade/mounts/art_mounts.py [preview]
"""
import os, sys, base64, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bggen
from PIL import Image
from playwright.sync_api import sync_playwright
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "..", "Media", "Arcade")
FONT = os.path.abspath(os.path.join(OUT, "..", "Fonts", "Cinzel-ExtraBold.ttf"))
U = U3 = os.path.join(HERE, "models") + os.sep
W, H, S = 256, 358, 2
def T(**k): return k
SK = lambda *c: [(i / (len(c) - 1), h) for i, h in enumerate(c)]
# key, name, model file, theme, glow rgb, ground glow, flavour, dark rgb, type colour
CARDS = [
 ("steed", "Black War Steed", U + "black_war_steed_750.png", T(sky=SK("#0a0a24", "#3a2a64", "#c0507a", "#f2a65a", "#2a1a2a"), horizon=.56, sun=(.7, .5, 34, "#ffd9a0"), far="#1c1838", mid="#12102a", ground=("#1a1424", "#08060c"), fog="#b27aa0", landmark="castle", lm_x=.3, lm_scale=1.15, lm_col="#150f2a", stars=90, motes="#ffd9a0"), "255,200,130", "Armour for the long road.", "14,10,28", "#e6dcff"),
 ("dread", "Dreadsteed", U + "dreadsteed_750.png", T(sky=SK("#120404", "#4a0c0c", "#c8321a", "#ff8a2a", "#200806"), horizon=.56, sun=(.5, .56, 60, "#ff9a3a"), far="#2a0a0a", mid="#1a0606", ground=("#2a0c08", "#080202"), fog="#d85a2a", landmark="spires", lm_x=.5, lm_scale=1.3, lm_col="#160606", motes="#ff9a3a", n_motes=140, glow=(.5, .6, 260, "#ff5a1f"), glow_a=.4), "255,120,40", "Summoned, never stabled.", "16,5,4", "#ffd0b8"),
 ("wsteed", "Swift White Steed", U + "swift_white_steed_750.png", T(sky=SK("#2a3a78", "#7a8ad0", "#ffc9a0", "#fff0c8", "#6a7a58"), horizon=.56, sun=(.5, .42, 36, "#fff6d0"), far="#7a8aa8", mid="#4a6a70", ground=("#3a5a38", "#10200f"), fog="#f0d8b8", landmark="arch", lm_x=.5, lm_scale=.8, lm_col="#6a789a", lm_haze=.72, motes="#fff6d0", cloud_a=.4), "255,236,190", "Fast enough to outrun the quest log.", "12,16,24", "#f0f4ff"),
 ("bwkodo", "Black War Kodo", U + "black_war_kodo_750.png", T(sky=SK("#2a1a44", "#b0406a", "#ff8a4a", "#ffd18a", "#6a3a22"), horizon=.56, sun=(.28, .5, 44, "#ffe0a0"), far="#6a3040", mid="#442432", ground=("#6a3a22", "#1a0e08"), fog="#ffb078", landmark="mesa", lm_x=.72, lm_scale=1.1, lm_col="#4a2634", lm_haze=.5, motes="#ffd18a", n_motes=40), "255,170,100", "Three tons of bad intentions.", "20,10,8", "#ffe2c8"),
 ("gwkodo", "Great White Kodo", U + "great_white_kodo_750.png", T(sky=SK("#3a5a8a", "#8ab0d0", "#f6dcc0", "#fff2d8", "#a89a78"), horizon=.56, sun=(.7, .46, 36, "#fffbe8"), far="#8a98a8", mid="#6a7a80", ground=("#8a8260", "#3a3624"), fog="#f0e6d0", landmark="mesa", lm_x=.25, lm_scale=1.05, lm_col="#7a8690", lm_haze=.6, cloud_a=.5), "255,246,220", "It remembers every road.", "20,18,14", "#fff4dc"),
 ("bwram", "Black War Ram", U + "black_war_ram_750.png", T(sky=SK("#0a1230", "#2a3a78", "#8a6aa8", "#e89a8a", "#2a3040"), horizon=.56, sun=(.3, .45, 30, "#ffd0c0"), far="#4a5a88", mid="#2a3558", ground=("#c0cce0", "#4a5878"), fog="#b0a0d0", landmark="icepeaks", lm_x=.6, lm_scale=1.2, lm_col="#303c6a", snow=True, stars=60), "200,170,255", "Horns first.", "8,10,22", "#dce4ff"),
 ("swram", "Swift White Ram", U + "swift_white_ram_750.png", T(sky=SK("#3a4a98", "#9a8ac8", "#f6b0a8", "#fff0d0", "#c8d4e8"), horizon=.56, sun=(.7, .46, 34, "#fff6e0"), far="#a0a8d0", mid="#7a88b8", ground=("#e6ecf8", "#8a98b8"), fog="#fce0d8", landmark="icepeaks", lm_x=.35, lm_scale=1.25, lm_col="#7884b8", lm_haze=.5, snow=True), "255,226,220", "Surefooted on every slope.", "14,18,34", "#eef2ff"),
 ("bwraptor", "Black War Raptor", U + "black_war_raptor_750.png", T(sky=SK("#050a14", "#102a38", "#1a5a50", "#3a8a6a", "#10180c"), horizon=.56, sun=(.5, .4, 30, "#d8ffd0"), far="#0c2a2a", mid="#081a1c", ground=("#12200e", "#040804"), fog="#2a7a62", landmark="temple", lm_x=.5, lm_scale=1.25, lm_col="#07191a", stars=70, motes="#9affc0", n_motes=100), "140,255,190", "Teeth, then manners.", "4,12,12", "#d0ffe8"),
 ("sbraptor", "Swift Blue Raptor", U + "swift_blue_raptor_750.png", T(sky=SK("#0a2a5a", "#1a7aa8", "#58c8c8", "#f8e8a0", "#20401c"), horizon=.56, sun=(.5, .44, 36, "#fff4b0"), far="#1a5a6a", mid="#0e3a48", ground=("#1c4a20", "#071208"), fog="#8ae0d0", landmark="temple", lm_x=.72, lm_scale=1.1, lm_col="#0e3a44", motes="#fff4b0"), "180,250,240", "Faster than the one that bit you.", "6,18,22", "#d0fcff"),
 ("bwtiger", "Black War Tiger", U + "black_war_tiger_750.png", T(sky=SK("#04041a", "#1a1850", "#4a3a8a", "#9a7ac0", "#1a1830"), horizon=.56, sun=(.72, .3, 34, "#f0eaff"), far="#241f58", mid="#14123a", ground=("#1a1a30", "#06060e"), fog="#7a6ac0", landmark="pines", lm_x=.5, lm_scale=1.2, lm_col="#0c0b28", stars=140, motes="#d8c8ff", n_motes=60), "190,160 ,255".replace(" ", ""), "Moonlit and purring.", "8,6,22", "#e6dcff"),
 ("bwwolf", "Black War Wolf", U + "black_war_wolf_750.png", T(sky=SK("#2a0808", "#8a2a1a", "#e8602a", "#ffb060", "#4a2210"), horizon=.56, sun=(.5, .5, 44, "#ffc070"), far="#5a1a14", mid="#3a100c", ground=("#6a3418", "#1a0c06"), fog="#f08a50", landmark="orcgate", lm_x=.5, lm_scale=1.2, lm_col="#2a0a08", motes="#ffb060", n_motes=70), "255,150,80", "The Horde's idea of a pet.", "22,8,6", "#ffddc0"),
 ("stwolf", "Swift Timber Wolf", U + "swift_timber_wolf_750.png", T(sky=SK("#0a2a28", "#2a6a50", "#c8a040", "#ffd878", "#1a2a10"), horizon=.56, sun=(.3, .5, 36, "#ffe898"), far="#1a4a3a", mid="#0e2e24", ground=("#1e3a1a", "#060e06"), fog="#9ac078", landmark="pines", lm_x=.5, lm_scale=1.3, lm_col="#0a2a1e", motes="#ffe898", n_motes=90), "255,226,150", "Straight through the forest.", "6,16,10", "#e4ffd8"),
 ("fwhowler", "Frostwolf Howler", U + "frostwolf_howler_750.png", T(sky=SK("#0a1a40", "#2a5a98", "#8ac0e8", "#e8f4ff", "#a0b8d0"), horizon=.56, sun=(.7, .38, 30, "#ffffff"), far="#6a8ab8", mid="#486898", ground=("#dce8f4", "#6a84a8"), fog="#d8ecff", landmark="icepeaks", lm_x=.4, lm_scale=1.35, lm_col="#506e9a", lm_haze=.45, snow=True, cloud_a=.5), "210,236,255", "The clan's call, on the wind.", "8,14,28", "#e8f4ff"),
 ("mist", "Swift Mistsaber", U + "swift_mistsaber_750.png", T(sky=SK("#05122a", "#14405a", "#3a8a96", "#9ad8d0", "#143030"), horizon=.56, sun=(.7, .32, 32, "#e8ffff"), far="#1a4a58", mid="#0e2e3c", ground=("#163a3a", "#050e10"), fog="#6ab8b0", landmark="pines", lm_x=.4, lm_scale=1.2, lm_col="#0a2430", stars=90, motes="#bafff0", n_motes=60), "160,255,240", "Silent over Darkshore.", "4,14,20", "#d8fffa"),
 ("frost", "Swift Frostsaber", U + "swift_frostsaber_750.png", T(sky=SK("#041030", "#0e4a78", "#2ab8a0", "#8aff9a", "#1a3a50"), horizon=.56, sun=None, far="#386a98", mid="#244a78", ground=("#d0e4f4", "#5a7aa0"), fog="#9ae0ec", landmark="icepeaks", lm_x=.5, lm_scale=1.3, lm_col="#2a4a7a", snow=True, stars=100, glow=(.5, .2, 330, "#3aff9a"), glow_a=.45), "170,255,220", "Winterspring's finest.", "4,12,26", "#d8fff0"),
 ("storm", "Swift Stormsaber", U + "swift_stormsaber_750.png", T(sky=SK("#080a18", "#242a48", "#4a5a88", "#8a9ac0", "#1c2236"), horizon=.56, sun=None, far="#2a3250", mid="#181e38", ground=("#222a40", "#080a14"), fog="#6a7aa8", landmark="icepeaks", lm_x=.6, lm_scale=1.2, lm_col="#141a30", glow=(.55, .22, 240, "#9ab8ff"), glow_a=.55, snow=True), "170,190,255", "It brings the weather.", "6,8,18", "#dce4ff"),
 ("mechy", "Swift Yellow Mechanostrider", U + "mech_yellow_750.png", T(sky=SK("#1a1008", "#5a3a18", "#c8782a", "#ffd070", "#3a2410"), horizon=.56, sun=(.5, .46, 40, "#ffe8a0"), far="#4a2e14", mid="#2e1c0c", ground=("#4a3418", "#120a04"), fog="#e8a850", landmark="gears", lm_x=.5, lm_scale=1.15, lm_col="#24160a", motes="#ffd070", n_motes=90), "255,200,100", "Some assembly required.", "18,10,4", "#ffecc8"),
 ("mechw", "Swift White Mechanostrider", U + "mech_white_750.png", T(sky=SK("#101a2a", "#3a5a82", "#9ab8d8", "#f0f6ff", "#3a4a5a"), horizon=.56, sun=(.5, .46, 40, "#ffffff"), far="#4a6a90", mid="#2e4668", ground=("#4a5a6a", "#10161e"), fog="#d0e0f0", landmark="gears", lm_x=.5, lm_scale=1.15, lm_col="#243a58", motes="#ffffff", n_motes=70), "230,240,255", "Do not feed after midnight.", "8,12,20", "#eaf2ff"),
 ("mechg", "Swift Green Mechanostrider", U + "mech_green_750.png", T(sky=SK("#08180e", "#1e4a2a", "#48a05a", "#d8ff9a", "#1e3a1a"), horizon=.56, sun=(.5, .46, 40, "#eaffb0"), far="#1e4a2a", mid="#10301a", ground=("#24421a", "#08120a"), fog="#9ae08a", landmark="gears", lm_x=.5, lm_scale=1.15, lm_col="#0c2a14", motes="#d8ff9a", n_motes=90), "190,255,150", "Runs on spite and steam.", "4,14,8", "#e0ffd8"),
 ("qblack", "Black Qiraji Battle Tank", U3 + "qiraji_625.png", T(sky=SK("#0a0620", "#3a1a62", "#a84a88", "#ffa060", "#3a2218"), horizon=.56, sun=(.5, .44, 46, "#ffc890"), far="#4a2058", mid="#2e1440", ground=("#6a4228", "#160c08"), fog="#e88aa0", landmark="obelisk", lm_x=.5, lm_scale=1.2, lm_col="#220e32", stars=80, motes="#e0b0ff", n_motes=50), "190,120,255", "It was never a small bug.", "14,8,22", "#e8d6ff"),
 ("qblue", "Blue Qiraji Battle Tank", U + "qiraji_blue_750.png", T(sky=SK("#041030", "#12388a", "#3a88d8", "#aef0ff", "#1a3a58"), horizon=.56, sun=(.5, .44, 44, "#e0ffff"), far="#1a3a78", mid="#0e2458", ground=("#2a4a68", "#08121c"), fog="#7ac8f0", landmark="obelisk", lm_x=.5, lm_scale=1.2, lm_col="#0c1e4a", stars=70, motes="#aef0ff", n_motes=60), "130,200,255", "Cool under pressure.", "4,10,26", "#d6ecff"),
 ("qred", "Red Qiraji Battle Tank", U + "qiraji_red_750.png", T(sky=SK("#1a0404", "#6a1010", "#d8402a", "#ffb060", "#40160c"), horizon=.56, sun=(.5, .44, 46, "#ffd090"), far="#601818", mid="#3a0e0e", ground=("#7a3a1c", "#1c0a06"), fog="#f08a50", landmark="obelisk", lm_x=.5, lm_scale=1.2, lm_col="#2e0808", motes="#ffb060", n_motes=80), "255,130,70", "Hot-headed, thin-shelled.", "20,6,4", "#ffd8c8"),
 ("qyellow", "Yellow Qiraji Battle Tank", U + "qiraji_yellow_750.png", T(sky=SK("#1a1204", "#6a4a10", "#d8a02a", "#fff0a0", "#4a3414"), horizon=.56, sun=(.5, .44, 48, "#fff6c0"), far="#6a4a1a", mid="#40300e", ground=("#9a7a38", "#241a0a"), fog="#f8e090", landmark="obelisk", lm_x=.5, lm_scale=1.2, lm_col="#3a2a0a", motes="#fff0a0", n_motes=70), "255,226,130", "Sand in every joint.", "20,14,4", "#fff0c8"),
 ("qgreen", "Green Qiraji Battle Tank", U + "qiraji_green_750.png", T(sky=SK("#041a10", "#10603a", "#38b878", "#c8ffb0", "#1a3a24"), horizon=.56, sun=(.5, .44, 46, "#e8ffd0"), far="#10583a", mid="#08382a", ground=("#2a5a3a", "#08140c"), fog="#7ae0a0", landmark="obelisk", lm_x=.5, lm_scale=1.2, lm_col="#07281c", motes="#c8ffb0", n_motes=70), "150,255,180", "The hive's quiet colour.", "4,18,12", "#d8ffe4"),
 ("razz", "Swift Razzashi Raptor", U3 + "razzashi_750.png", T(sky=SK("#06201c", "#14574a", "#d9a24a", "#ffe0a0", "#20260e"), horizon=.56, sun=(.5, .4, 40, "#fff2b0"), far="#0f3a33", mid="#0a2a26", ground=("#1a2210", "#060804"), fog="#7aae80", landmark="temple", lm_x=.5, lm_scale=1.25, lm_col="#0a2622", motes="#ffe9a8", n_motes=100), "255,226,150", "Swift as a rumour.", "6,22,20", "#c8f5e2"),
 ("zul", "Swift Zulian Tiger", U3 + "zulian_750.png", T(sky=SK("#1c0a24", "#6a1e3a", "#e0662a", "#ffc860", "#3a1a10"), horizon=.56, sun=(.7, .46, 44, "#ffe0a0"), far="#4a1a30", mid="#2e1020", ground=("#4a2a14", "#120804"), fog="#f09050", landmark="temple", lm_x=.28, lm_scale=1.1, lm_col="#260c1a", motes="#ffc860", n_motes=90), "255,180,80", "Stripes at full gallop.", "22,10,6", "#ffe0b8"),
]
def b64(im): 
    import io; b = io.BytesIO(); im.save(b, "PNG"); return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()
def crop(p):
    im = Image.open(p).convert("RGBA"); a = np.array(im)[..., 3]; ys, xs = np.where(a > 20); return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
def html(c, i):
    key, name, mp, theme, glow, fl, dark, tc = c
    bg = bggen.paint(theme, seed=i + 3); m = crop(mp)
    maxw, maxh = 345, 300; sc = min(maxw / m.size[0], maxh / m.size[1]); w, h = m.size[0] * sc, m.size[1] * sc
    x, y = 195 - w / 2, 322 - h
    mdl = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 390 550" preserveAspectRatio="none" style="position:absolute;left:0;top:0;width:100%%;height:100%%"><defs><radialGradient id="rg"><stop offset="0" stop-color="rgb(%s)" stop-opacity=".5"/><stop offset="1" stop-color="rgb(%s)" stop-opacity="0"/></radialGradient><radialGradient id="sh"><stop offset="0" stop-color="#000" stop-opacity=".75"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient></defs><ellipse cx="195" cy="%d" rx="%d" ry="%d" fill="url(#rg)"/><ellipse cx="195" cy="318" rx="%d" ry="14" fill="url(#sh)"/><image href="%s" x="%d" y="%d" width="%d" height="%d"/></svg>' % (glow, glow, y + h * .55, w * .62, h * .6, w * .55, b64(m), x, y, w, h)
    S2 = S
    return """<!doctype html><html><head><meta charset="utf-8"><style>@font-face{font-family:Cz;src:url('file://%s')}html,body{margin:0;background:#18181f}#c{position:relative;width:%dpx;height:%dpx;overflow:hidden;border-radius:%dpx}</style></head><body><div id="c"><img src="%s" style="position:absolute;left:0;top:0;width:100%%;height:100%%">%s
<div style="position:absolute;left:0;top:%dpx;width:100%%;height:%dpx;background:linear-gradient(180deg,rgba(%s,0),rgba(%s,.92) 22%%,rgba(%s,.98))"></div>
<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;box-sizing:border-box;border-radius:%dpx;background:linear-gradient(180deg,#fff,#f6e7b4 28%%,#c99a3f 62%%,#8a6220);border:1px solid #fff3c9;display:flex;align-items:center;justify-content:center;font:800 %dpx Cz;color:#2a1a05;white-space:nowrap">%s</div>
<div style="position:absolute;left:0;top:%dpx;width:100%%;text-align:center;font:800 %dpx Cz;letter-spacing:%dpx;color:%s">MOUNT  ·  BEAST  ·  MYTHIC</div>
<div style="position:absolute;left:0;top:%dpx;width:100%%;text-align:center;font:italic %dpx Georgia,serif;color:%s;opacity:.85">%s</div>
<div style="position:absolute;right:%dpx;top:%dpx;padding:%dpx %dpx;border-radius:99px;background:rgba(%s,.8);border:1px solid rgba(255,233,168,.75);color:#ffe9a8;font:800 %dpx Cz;letter-spacing:%dpx">MYTHIC</div>
<div style="position:absolute;left:0;top:%dpx;width:100%%;text-align:center;font:800 %dpx Cz;letter-spacing:%dpx;color:#f4efe2">M-%02d</div></div></body></html>""" % (
        FONT, W * S, H * S, 12 * S, b64(bg), mdl, 214 * S, (H - 214) * S, dark, dark, dark, 14 * S, 232 * S, 228 * S, 30 * S, 6 * S,
        (14 if len(name) < 22 else 11.5 if len(name) < 27 else 10) * S, name, 266 * S, 7 * S, S, tc, 337 * S, 8 * S, tc, fl, 10 * S, 11 * S, 3 * S, 7 * S, dark, 7 * S, 2 * S, 4 * S, 7 * S, 2 * S, 6 + i)
PREVIEW = len(sys.argv) > 1 and sys.argv[1] == "preview"
def main():
    body = Image.open(os.path.join(OUT, "Body.tga")).convert("RGBA")
    alpha = body.split()[3].point(lambda v: 255 if v > 200 else (0 if v < 8 else v))   # the card's shape
    previews = []
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page(viewport={"width": W * S, "height": H * S})
        for i, c in enumerate(CARDS):
            pg.set_content(html(c, i)); pg.wait_for_timeout(250)
            tmp = "/tmp/mount_%02d.png" % (i + 1)
            pg.locator("#c").screenshot(path=tmp, omit_background=True)
            art = Image.open(tmp).convert("RGBA").resize((W, H), Image.LANCZOS)
            out = Image.new("RGBA", body.size, (0, 0, 0, 0)); out.paste(art, (0, 0)); out.putalpha(alpha)
            name = "MythicMount%02d" % (i + 1)
            out.save(os.path.join(OUT, name + ".tga"), compression=None); print("wrote", name, c[1])
            previews.append(out)
        b.close()
    if PREVIEW:
        for si in range(0, len(previews), 9):
            ch = previews[si:si + 9]; sh = Image.new("RGB", (W * 3 + 40, H * 3 + 40), (24, 24, 31))
            for k, im in enumerate(ch): sh.paste(im.crop((0, 0, W, H)), (10 + (k % 3) * (W + 10), 10 + (k // 3) * (H + 10)), im.crop((0, 0, W, H)))
            sh.save("/tmp/mounts_prev_%d.png" % (si // 9 + 1))

if __name__ == "__main__":
    main()
