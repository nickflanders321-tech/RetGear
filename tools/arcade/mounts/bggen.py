"""Painterly backdrops for the Mythic mount cards: layered sky, hazy ridges, a landmark, light, motes. 390x550 art space, drawn at 2x."""
import numpy as np, math, random
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter, gaussian_filter1d, zoom
W, H = 780, 1100
def hexc(h): h = h.lstrip("#"); return np.array([int(h[i:i+2], 16) for i in (0, 2, 4)], np.float32) / 255
def fbm(seed, shape, base=6, octaves=5, persist=0.5):
    rng = np.random.RandomState(seed); out = np.zeros(shape, np.float32); amp = 1; tot = 0
    for o in range(octaves):
        n = max(2, int(base * (2 ** o)))
        small = rng.rand(max(2, int(n * shape[0] / shape[1])) + 1, n + 1).astype(np.float32)
        out += amp * zoom(small, (shape[0] / small.shape[0], shape[1] / small.shape[1]), order=3)[:shape[0], :shape[1]]
        tot += amp; amp *= persist
    out /= tot; out -= out.min(); out /= max(out.max(), 1e-6); return out
def grad(stops, y0=0.0, y1=1.0):
    ys = np.linspace(0, 1, H)[:, None]; img = np.zeros((H, W, 3), np.float32)
    pos = [s[0] for s in stops]; cols = [hexc(s[1]) for s in stops]
    for c in range(3): img[..., c] = np.interp(np.clip((ys - y0) / (y1 - y0), 0, 1), pos, [k[c] for k in cols])
    return img
def ridge(seed, y, amp, rough, w=W):
    rng = np.random.RandomState(seed); n = rng.randn(w).astype(np.float32)
    big = gaussian_filter1d(rng.randn(w).astype(np.float32), 60) * 8 + gaussian_filter1d(n, 16) * 3 + gaussian_filter1d(n, 4) * rough * 0.35
    big = (big - big.mean()) / (big.std() + 1e-6)
    return y + big * amp
def mask_below(line):
    ys = np.arange(H)[:, None]; return (ys >= line[None, :]).astype(np.float32)
def over(img, col, m, a=1.0):
    img[:] = img * (1 - m[..., None] * a) + np.asarray(col, np.float32) * (m[..., None] * a)
def blend_add(img, layer): img += layer
def radial(cx, cy, r, power=2.0):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32); d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    return np.clip(1 - d, 0, 1) ** power
def landmark(kind, col, base_y, cx, scale=1.0, seed=0):
    im = Image.new("L", (W, H), 0); d = ImageDraw.Draw(im); s = scale * 2; rng = random.Random(seed)
    def P(pts): return [(cx + x * s, base_y + y * s) for x, y in pts]
    if kind == "temple":
        for i, (hw, hh) in enumerate([(90, 22), (74, 22), (58, 22), (42, 20)]):
            d.rectangle(P([(-hw, -22 * (i + 1) - 0)])[0] + P([(hw, -22 * i)])[0], fill=255)
        d.rectangle(P([(-26, -112)])[0] + P([(26, -86)])[0], fill=255); d.polygon(P([(-30, -112), (0, -138), (30, -112)]), fill=255)
        for x in (-110, 120): d.rectangle(P([(x - 10, -70)])[0] + P([(x + 10, 0)])[0], fill=255)
    elif kind == "obelisk":
        for x, h, w in ((-130, 190, 14), (150, 140, 12), (-40, 90, 10), (60, 230, 16)):
            d.polygon(P([(x - w, 0), (x - w * .6, -h), (x, -h - w * 1.6), (x + w * .6, -h), (x + w, 0)]), fill=255)
    elif kind == "pines":
        for k in range(26):
            x = rng.uniform(-260, 260); h = rng.uniform(60, 170); w = h * .28
            d.polygon(P([(x - w, 0), (x, -h), (x + w, 0)]), fill=255)
            for t in (.3, .55): d.polygon(P([(x - w * (1 - t) - 8, -h * t), (x, -h * t - h * .35), (x + w * (1 - t) + 8, -h * t)]), fill=255)
    elif kind == "castle":
        d.rectangle(P([(-120, -70)])[0] + P([(120, 0)])[0], fill=255)
        for x, h in ((-130, 150), (-60, 120), (0, 190), (70, 130), (140, 160)):
            d.rectangle(P([(x - 16, -h)])[0] + P([(x + 16, 0)])[0], fill=255); d.polygon(P([(x - 20, -h), (x, -h - 40), (x + 20, -h)]), fill=255)
        for x in range(-120, 121, 16): d.rectangle(P([(x, -82)])[0] + P([(x + 8, -70)])[0], fill=255)
    elif kind == "mesa":
        for x, w, h in ((-170, 60, 120), (10, 80, 190), (190, 50, 100)):
            d.polygon(P([(x - w - 30, 0), (x - w - 6, -h * .55), (x - w + 4, -h * .6), (x - w * .5, -h), (x + w * .6, -h * .96), (x + w - 4, -h * .6), (x + w + 8, -h * .5), (x + w + 34, 0)]), fill=255)
    elif kind == "icepeaks":
        for x, h, w in ((-170, 230, 90), (-60, 330, 120), (80, 270, 100), (200, 210, 80)):
            d.polygon(P([(x - w, 0), (x - w * .3, -h * .8), (x - w * .1, -h * .7), (x + 4, -h), (x + w * .3, -h * .6), (x + w, 0)]), fill=255)
    elif kind == "orcgate":
        for x in (-120, 120):
            d.polygon(P([(x - 30, 0), (x - 22, -200), (x - 6, -250), (x + 8, -200), (x + 30, 0)]), fill=255)
            for t in range(-3, 4): d.polygon(P([(x + t * 8 - 4, -150), (x + t * 8, -190 - abs(t) * 6), (x + t * 8 + 4, -150)]), fill=255)
        d.polygon(P([(-120, -190), (0, -150), (120, -190), (120, -170), (0, -126), (-120, -170)]), fill=255)
    elif kind == "gears":
        for x, r in ((-110, 70), (40, 110), (170, 60)):
            n = 12
            for k in range(n):
                a = k * 2 * math.pi / n
                d.polygon(P([(x + math.cos(a - .12) * r * .9, -r + math.sin(a - .12) * r * .9), (x + math.cos(a - .12) * r * 1.15, -r + math.sin(a - .12) * r * 1.15), (x + math.cos(a + .12) * r * 1.15, -r + math.sin(a + .12) * r * 1.15), (x + math.cos(a + .12) * r * .9, -r + math.sin(a + .12) * r * .9)]), fill=255)
            d.ellipse(P([(x - r, -2 * r)])[0] + P([(x + r, 0)])[0], fill=255)
    elif kind == "spires":
        for x, h, w in ((-180, 200, 26), (-90, 120, 20), (-20, 280, 30), (70, 170, 24), (150, 240, 28), (230, 130, 20)):
            d.polygon(P([(x - w, 0), (x - w * .5, -h * .7), (x - 3, -h), (x + w * .3, -h * .6), (x + w, 0)]), fill=255)
    elif kind == "arch":
        d.rectangle(P([(-110, -240)])[0] + P([(-70, 0)])[0], fill=255); d.rectangle(P([(70, -240)])[0] + P([(110, 0)])[0], fill=255)
        d.pieslice(P([(-110, -330)])[0] + P([(110, -150)])[0], 180, 360, fill=255)
        d.pieslice(P([(-70, -290)])[0] + P([(70, -190)])[0], 180, 360, fill=0)
    elif kind == "dunes":
        pass
    a = np.asarray(im.filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
    return a
def mist(img, y, col, a, seed, spread=140):
    n = fbm(seed, (H, W), 4, 4); band = np.exp(-((np.arange(H)[:, None] - y) ** 2) / (2 * spread ** 2)).astype(np.float32)
    over(img, col, np.clip(n * band * 1.6, 0, 1), a)
def motes(img, col, n, seed, ymax=0.75, size=(1, 3), a=0.9):
    rng = np.random.RandomState(seed); lay = np.zeros((H, W), np.float32)
    for _ in range(n):
        x, y = rng.randint(0, W), int(rng.rand() ** 1.4 * H * ymax); r = rng.uniform(*size) * 2
        lay = np.maximum(lay, radial(x, y, r * 2.5, 1.5) * rng.uniform(.3, 1))
    over(img, col, np.clip(lay, 0, 1), a)
def rays(img, cx, cy, col, n, seed, a=0.12, spread=0.5):
    rng = np.random.RandomState(seed); yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    ang = np.arctan2(yy - cy, xx - cx); out = np.zeros((H, W), np.float32)
    for _ in range(n):
        t = rng.uniform(0.15, 0.85) * math.pi; w = rng.uniform(.02, .07)
        out += np.exp(-((ang - t) ** 2) / (2 * w * w)) * rng.uniform(.4, 1)
    fall = np.clip(1 - np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (H * spread), 0, 1)
    over(img, col, np.clip(out * fall, 0, 1), a)
def paint(t, seed=1):
    """t: dict(sky=[(pos,hex)...], horizon=y(0-1), sun=(x,y,r,hex) or None, far, mid, ground=(top,bottom), fog, landmark, lm_x, lm_scale, stars, motes, rays, snow, embers)"""
    img = grad(t["sky"])
    cl = fbm(seed + 3, (H, W), 3, 5); cl = np.clip((cl - .45) * 2.2, 0, 1) * np.clip(1 - np.arange(H)[:, None] / (H * .6), 0, 1)
    over(img, hexc(t.get("cloud", "#ffffff")), cl, t.get("cloud_a", 0.25))
    if t.get("stars"):
        rng = np.random.RandomState(seed); lay = np.zeros((H, W), np.float32)
        for _ in range(t["stars"]): x, y = rng.randint(0, W), int(rng.rand() ** 1.8 * H * .55); lay[max(0, y - 1):y + 2, max(0, x - 1):x + 2] = rng.uniform(.4, 1)
        over(img, (1, .98, .88), np.clip(lay, 0, 1), .85)
    if t.get("sun"):
        sx, sy, sr, sc = t["sun"]; sx *= W; sy *= H; sr *= 2
        over(img, hexc(sc), radial(sx, sy, sr * 4.5, 2.2), .55); over(img, hexc(sc), radial(sx, sy, sr * 2, 2.0), .65)
        yy, xx = np.mgrid[0:H, 0:W]; disk = np.clip(1.6 - np.sqrt((xx - sx) ** 2 + (yy - sy) ** 2) / sr, 0, 1); over(img, (1, .98, .9), disk, .95)
    hy = t["horizon"] * H; fog = hexc(t["fog"])
    layers = [("far", hy - 150, 70, 2.0, .62), ("mid", hy - 70, 52, 3.0, .38)]
    for i, (k, y, amp, rough, fa) in enumerate(layers):
        if t.get(k) is None: continue
        ln = ridge(seed * 10 + i, y, amp, rough); m = mask_below(ln); over(img, hexc(t[k]), m, 1.0)
        # haze toward the horizon, atmospheric depth
        over(img, fog, m * np.clip((np.arange(H)[:, None] - ln[None, :]) / 260, 0, 1)[..., 0:1].repeat(1, 2).reshape(H, W) if False else m * np.clip(1 - (np.arange(H)[:, None] - ln[None, :]) / 260, 0, 1), fa * .55)
    if t.get("landmark"):
        lm = landmark(t["landmark"], 0, hy + 10, t.get("lm_x", .5) * W, t.get("lm_scale", 1.0), seed)
        over(img, hexc(t.get("lm_col", t.get("mid", "#222222"))), lm, 1.0)
        over(img, fog, lm * np.clip(t.get("lm_haze", .35), 0, 1), 1.0)
    # ground
    gl = ridge(seed + 77, hy + 8, 6, 1.5); gm = mask_below(gl); g0, g1 = hexc(t["ground"][0]), hexc(t["ground"][1])
    f = np.clip((np.arange(H)[:, None] - hy) / (H - hy), 0, 1)
    gimg = g0 * (1 - f[..., None]) + g1 * f[..., None]; gtex = fbm(seed + 9, (H, W), 14, 4)[..., None] * .22 + .89
    img[:] = img * (1 - gm[..., None]) + gimg * gtex * gm[..., None]
    mist(img, hy + 4, fog, .55, seed + 5, 90)
    if t.get("sun") and t.get("rays", True): rays(img, t["sun"][0] * W, t["sun"][1] * H, hexc(t["sun"][3]), 9, seed + 2, t.get("ray_a", .10))
    if t.get("glow"):
        gx, gy, gr, gc = t["glow"]; over(img, hexc(gc), radial(gx * W, gy * H, gr * 2, 1.8), t.get("glow_a", .5))
    if t.get("motes"): motes(img, hexc(t["motes"]), t.get("n_motes", 70), seed + 4, .8, (1, 3))
    if t.get("snow"): motes(img, (1, 1, 1), 160, seed + 8, 1.0, (.7, 2.2), .9)
    # warm/cool grade and vignette
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32); v = np.sqrt(((xx - W / 2) / (W * .62)) ** 2 + ((yy - H * .42) / (H * .7)) ** 2)
    img *= (1 - np.clip(v - .45, 0, 1) ** 1.6 * .75)[..., None]
    img = np.clip(img, 0, 1)
    return Image.fromarray((img * 255).astype(np.uint8)).resize((390, 550), Image.LANCZOS)
