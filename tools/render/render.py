"""Draw a scene (a draw list written by the harness: run.lua --shoot) to a PNG, the way the game would draw it.

    python3 tools/render/render.py SCENE.json [-o OUT.png] [--scale 1] [--crop l,b,r,t | --crop-frame NAME] [--bg FILE]
    python3 tools/render/render.py DIR           # every scene in DIR (its index.json), each to DIR/<name>.png

Textures come from the add-on's Media folder and from the game's files (casc.py, read from the local install);
fonts from the game and Media/Fonts. Models are drawn by model.py. See tools/render/README.md.
"""
import argparse, json, math, os, sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CACHE = os.path.join(HERE, "..", "harness", ".cache")
sys.path.insert(0, HERE)

ADDON_PREFIX = "INTERFACE\\ADDONS\\WAYPATH\\"
_casc = None
MISSING = set()
WARNED = set()


def casc():
    global _casc
    if _casc is None:
        try:
            from casc import Casc
            _casc = Casc()
        except Exception as e:  # no install: game textures are left out (reported)
            print("(no game files: %s)" % e, file=sys.stderr)
            _casc = False
    return _casc or None


# --------------------------------------------------------------------------------------------------
# textures
# --------------------------------------------------------------------------------------------------
class Tex:
    """A texture as float RGBA (0..1), with a mip chain made on demand."""
    def __init__(self, img):
        a = np.asarray(img.convert("RGBA"), dtype=np.float32) / 255.0
        self.levels = [a]

    def level(self, n):
        while len(self.levels) <= n:
            prev = self.levels[-1]
            h, w = prev.shape[:2]
            if h < 2 and w < 2:
                break
            h2, w2 = max(1, h // 2), max(1, w // 2)
            p = prev[:h2 * 2 if h > 1 else 1, :w2 * 2 if w > 1 else 1]
            if h > 1 and w > 1:
                p = (p[0::2, 0::2] + p[1::2, 0::2] + p[0::2, 1::2] + p[1::2, 1::2]) / 4
            elif h > 1:
                p = (p[0::2] + p[1::2]) / 2
            else:
                p = (p[:, 0::2] + p[:, 1::2]) / 2
            self.levels.append(p)
        return self.levels[min(n, len(self.levels) - 1)]

    @property
    def size(self):
        h, w = self.levels[0].shape[:2]
        return w, h


_texcache = {}


def load_image_bytes(data):
    import io
    return Image.open(io.BytesIO(data))


def find_texture(ref):
    """A texture reference as the add-on gives it (a path or a FileDataID) -> PIL image, or None."""
    if ref is None:
        return None
    if isinstance(ref, (int, float)) or (isinstance(ref, str) and ref.isdigit()):
        c = casc()
        d = c and c.read(int(ref))
        return load_image_bytes(d) if d else None
    p = ref.replace("/", "\\")
    up = p.upper()
    if up.startswith(ADDON_PREFIX):
        rel = p[len(ADDON_PREFIX):].replace("\\", os.sep)
        base = os.path.join(ROOT, rel)
        cands = [base] if os.path.splitext(base)[1] else [base + e for e in (".tga", ".blp", ".png", ".jpg")]
        for cnd in cands:
            if os.path.exists(cnd):
                return Image.open(cnd)
            # (case-insensitive file systems in the game; not here)
            d, n = os.path.split(cnd)
            if os.path.isdir(d):
                for f in os.listdir(d):
                    if f.lower() == n.lower():
                        return Image.open(os.path.join(d, f))
        return None
    c = casc()
    if not c:
        return None
    for cand in ([p] if os.path.splitext(p)[1] else [p + ".blp", p + ".BLP", p + ".tga"]):
        d = c.read(cand)
        if d:
            return load_image_bytes(d)
    return None


def texture(ref):
    key = str(ref)
    if key in _texcache:
        return _texcache[key]
    img = None
    try:
        img = find_texture(ref)
    except Exception as e:
        print("can't read texture %s: %s" % (ref, e), file=sys.stderr)
    t = Tex(img) if img is not None else None
    if t is None:
        MISSING.add(key)
    _texcache[key] = t
    return t


# --------------------------------------------------------------------------------------------------
# the canvas
# --------------------------------------------------------------------------------------------------
class Canvas:
    def __init__(self, screen, scale=1.0, crop=None, bg=None):
        self.sw, self.sh = screen
        self.k = scale
        self.models = []
        # crop: l, b, r, t in screen units
        self.crop = crop or (0, 0, self.sw, self.sh)
        l, b, r, t = self.crop
        self.W = max(1, int(round((r - l) * scale)))
        self.H = max(1, int(round((t - b) * scale)))
        if bg is not None:
            img = Image.open(bg).convert("RGB").resize((self.W, self.H))
            self.px = np.asarray(img, dtype=np.float32) / 255.0
        else:
            self.px = np.zeros((self.H, self.W, 3), np.float32)
            self.px[:] = (0.09, 0.1, 0.12)   # a dark, neutral "game world" behind the UI

    def to_px(self, x, y):
        l, b, r, t = self.crop
        return (x - l) * self.k, (t - y) * self.k

    def clip_box(self, clip):
        """A clip rect (screen units) -> pixel box x0, y0, x1, y1 (end exclusive)."""
        if not clip:
            return 0, 0, self.W, self.H
        x0, y1 = self.to_px(clip[0], clip[1])
        x1, y0 = self.to_px(clip[2], clip[3])
        return max(0, int(math.floor(x0 + 0.5))), max(0, int(math.floor(y0 + 0.5))), min(self.W, int(math.floor(x1 + 0.5))), min(self.H, int(math.floor(y1 + 0.5)))

    def blend(self, x0, y0, rgb, a, mode):
        """Composite a block (rgb: h x w x 3, a: h x w) at pixel x0, y0."""
        h, w = a.shape
        dst = self.px[y0:y0 + h, x0:x0 + w]
        a3 = a[..., None]
        if mode == "ADD":
            dst += rgb * a3
            np.clip(dst, 0, 1, out=dst)
        elif mode == "MOD":
            dst *= (rgb * a3 + (1 - a3))
        elif mode == "DISABLE":
            dst[:] = rgb
        else:
            if mode == "ALPHAKEY":
                a3 = (a3 > 0.5).astype(np.float32)
            dst[:] = rgb * a3 + dst * (1 - a3)

    def save(self, path):
        Image.fromarray((np.clip(self.px, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(path)


def sample(tex, u, v, wrap_u, wrap_v, scale_px):
    """Bilinear samples of a texture at (u, v) arrays; the mip level from how many texels fall in a pixel."""
    lvl = 0
    if scale_px > 1.5:
        lvl = int(math.floor(math.log2(scale_px)))
    a = tex.level(lvl)
    h, w = a.shape[:2]
    x = u * w - 0.5
    y = v * h - 0.5
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    def idx(i, n, wrap):
        return np.mod(i, n) if wrap else np.clip(i, 0, n - 1)
    xa, xb = idx(x0, w, wrap_u), idx(x0 + 1, w, wrap_u)
    ya, yb = idx(y0, h, wrap_v), idx(y0 + 1, h, wrap_v)
    c = (a[ya, xa] * (1 - fx) * (1 - fy) + a[ya, xb] * fx * (1 - fy) + a[yb, xa] * (1 - fx) * fy + a[yb, xb] * fx * fy)
    return c


def draw_quad(cv, corners, uvs, tex=None, color=(1, 1, 1, 1), vcols=None, alpha=1.0, blend="BLEND", clip=None,
              wrap=(False, False), desat=False, masks=None):
    """A textured quad: corners (UL, LL, UR, LR) in pixels, uvs the same order. vcols: a color per corner."""
    cx0, cy0, cx1, cy1 = cv.clip_box(clip)
    xs = [p[0] for p in corners]
    ys = [p[1] for p in corners]
    x0, x1 = max(cx0, int(math.floor(min(xs)))), min(cx1, int(math.ceil(max(xs))))
    y0, y1 = max(cy0, int(math.floor(min(ys)))), min(cy1, int(math.ceil(max(ys))))
    if x1 <= x0 or y1 <= y0:
        return
    gx, gy = np.meshgrid(np.arange(x0, x1, dtype=np.float32) + 0.5, np.arange(y0, y1, dtype=np.float32) + 0.5)
    H, W = gy.shape
    U = np.zeros((H, W), np.float32)
    V = np.zeros((H, W), np.float32)
    inside = np.zeros((H, W), bool)
    C = np.zeros((H, W, 4), np.float32) if vcols else None
    UL, LL, UR, LR = range(4)
    for tri in ((UL, LL, UR), (UR, LL, LR)):
        (ax, ay), (bx, by), (qx, qy) = corners[tri[0]], corners[tri[1]], corners[tri[2]]
        den = (by - qy) * (ax - qx) + (qx - bx) * (ay - qy)
        if abs(den) < 1e-9:
            continue
        w0 = ((by - qy) * (gx - qx) + (qx - bx) * (gy - qy)) / den
        w1 = ((qy - ay) * (gx - qx) + (ax - qx) * (gy - qy)) / den
        w2 = 1 - w0 - w1
        m = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4) & ~inside
        if not m.any():
            continue
        ua, ub, uc = uvs[tri[0]], uvs[tri[1]], uvs[tri[2]]
        U[m] = (w0 * ua[0] + w1 * ub[0] + w2 * uc[0])[m]
        V[m] = (w0 * ua[1] + w1 * ub[1] + w2 * uc[1])[m]
        if C is not None:
            ca, cb, cc = (np.array(vcols[i], np.float32) for i in tri)
            for ch in range(4):
                C[..., ch][m] = (w0 * ca[ch] + w1 * cb[ch] + w2 * cc[ch])[m]
        inside |= m
    if not inside.any():
        return
    if tex is not None:
        tw, th = tex.size
        # texels per pixel, for the mip level
        du = abs(uvs[UR][0] - uvs[UL][0]) * tw + abs(uvs[UR][1] - uvs[UL][1]) * th
        dl = math.hypot(corners[UR][0] - corners[UL][0], corners[UR][1] - corners[UL][1]) or 1
        dv = abs(uvs[LL][0] - uvs[UL][0]) * tw + abs(uvs[LL][1] - uvs[UL][1]) * th
        dh = math.hypot(corners[LL][0] - corners[UL][0], corners[LL][1] - corners[UL][1]) or 1
        s = sample(tex, U, V, wrap[0], wrap[1], max(du / dl, dv / dh))
        rgb, a = s[..., :3], s[..., 3]
    else:
        rgb = np.ones((H, W, 3), np.float32)
        a = np.ones((H, W), np.float32)
    if desat:
        lum = (rgb[..., 0] * 0.3 + rgb[..., 1] * 0.59 + rgb[..., 2] * 0.11)[..., None]
        rgb = np.repeat(lum, 3, axis=2)
    rgb = rgb * np.array(color[:3], np.float32)
    a = a * (color[3] if len(color) > 3 else 1) * alpha
    if C is not None:
        rgb = rgb * C[..., :3]
        a = a * C[..., 3]
    if masks:
        for mk in masks:
            mt = texture(mk["tex"])
            if mt is None:
                continue
            mx0, my1 = cv.to_px(mk["r"][0], mk["r"][1])
            mx1, my0 = cv.to_px(mk["r"][2], mk["r"][3])
            mu = (gx - mx0) / max(1e-6, mx1 - mx0)
            mv = (gy - my0) / max(1e-6, my1 - my0)
            ms = sample(mt, mu, mv, False, False, 1)
            inb = (mu >= 0) & (mu <= 1) & (mv >= 0) & (mv <= 1)
            a = a * np.where(inb, ms[..., 3] if mt.levels[0][..., 3].min() < 0.999 else ms[..., 0], 0)
    a = np.where(inside, a, 0)
    cv.blend(x0, y0, rgb, a, blend or "BLEND")


def rect_corners(cv, r, rot=None):
    """A rect (l, b, r, t in screen units) -> pixel corners UL, LL, UR, LR, rotated about its middle."""
    x0, y0 = cv.to_px(r[0], r[3])
    x1, y1 = cv.to_px(r[2], r[1])
    pts = [(x0, y0), (x0, y1), (x1, y0), (x1, y1)]
    if rot:
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        c, s = math.cos(rot), math.sin(rot)
        # (counter-clockwise on screen, y down)
        pts = [(cx + (x - cx) * c + (y - cy) * s, cy - (x - cx) * s + (y - cy) * c) for x, y in pts]
    return pts


def grad_colors(item):
    g = item.get("grad")
    if not g:
        return None
    o, c1, c2 = g[0], g[1], g[2]
    c1 = list(c1) + [1] * (4 - len(c1))
    c2 = list(c2) + [1] * (4 - len(c2))
    if str(o).upper() == "VERTICAL":
        return [c2, c1, c2, c1]          # min at the bottom, max at the top (UL, LL, UR, LR)
    return [c1, c1, c2, c2]              # min on the left


def draw_tex(cv, it):
    r = it["r"]
    if r[2] - r[0] <= 0 or r[3] - r[1] <= 0:
        return
    tc = it.get("tc") or [0, 0, 0, 1, 1, 0, 1, 1]
    tc = [0 if v is None else v for v in tc] + [0] * (8 - len(tc))
    uvs = [(tc[0], tc[1]), (tc[2], tc[3]), (tc[4], tc[5]), (tc[6], tc[7])]
    tex = None
    color = [1, 1, 1, 1]
    if it.get("tex") == "color":
        c = it.get("color") or [1, 1, 1, 1]
        color = [c[i] if i < len(c) and c[i] is not None else 1 for i in range(4)]
    else:
        tex = texture(it.get("tex"))
        if tex is None:
            return
    vc = it.get("vc")
    if vc:
        color = [color[i] * (vc[i] if i < len(vc) and vc[i] is not None else 1) for i in range(4)]
    wrap = it.get("wrap") or [None, None]
    wu = bool(wrap[0]) and wrap[0] not in ("CLAMP", "CLAMPTOBLACK", "CLAMPTOBLACKADDITIVE", "CLAMPTOWHITE")
    wv = bool(wrap[1]) and wrap[1] not in ("CLAMP", "CLAMPTOBLACK", "CLAMPTOBLACKADDITIVE", "CLAMPTOWHITE")
    if tex is not None and (it.get("htile") or it.get("vtile")):
        tw, th = tex.size
        sx = (r[2] - r[0]) / tw if it.get("htile") else 1
        sy = (r[3] - r[1]) / th if it.get("vtile") else 1
        uvs = [(u * sx, v * sy) for u, v in uvs]
        wu = wu or bool(it.get("htile"))
        wv = wv or bool(it.get("vtile"))
    draw_quad(cv, rect_corners(cv, r, it.get("rot")), uvs, tex, color, grad_colors(it), it.get("a", 1), it.get("blend"),
              it.get("clip"), (wu, wv), it.get("desat"), it.get("masks"))


# the classic backdrop edge file: 8 pieces side by side (FrameXML Backdrop.lua's coordinates)
def draw_backdrop(cv, it):
    r = it["r"]
    es = it.get("scale", 1)
    a = it.get("a", 1)
    color = list(it.get("color") or [1, 1, 1, 1]) + [1] * 4
    color = [1 if v is None else v for v in color[:4]]
    if it["part"] == "bg":
        tex = texture(it.get("bg")) if it.get("bg") else None
        if tex is None:
            return
        ins = it.get("insets") or [0, 0, 0, 0]
        rr = [r[0] + ins[0] * es, r[1] + ins[3] * es, r[2] - ins[1] * es, r[3] - ins[2] * es]
        if rr[2] <= rr[0] or rr[3] <= rr[1]:
            return
        uvs = [(0, 0), (0, 1), (1, 0), (1, 1)]
        wrap = (False, False)
        if it.get("tile"):
            ts = (it.get("tileSize") or 0) * es or tex.size[0]
            sx, sy = (rr[2] - rr[0]) / ts, (rr[3] - rr[1]) / ts
            uvs = [(0, 0), (0, sy), (sx, 0), (sx, sy)]
            wrap = (True, True)
        draw_quad(cv, rect_corners(cv, rr), uvs, tex, color, None, a, "BLEND", it.get("clip"), wrap)
        return
    tex = texture(it.get("edge")) if it.get("edge") else None
    if tex is None:
        return
    e = (it.get("edgeSize") or 0) * es or tex.size[1]
    L, B, R, T = r
    w, h = R - L, T - B
    if w <= 0 or h <= 0:
        return
    rx = max(0, (w - 2 * e) / e)
    ry = max(0, (h - 2 * e) / e)
    pad = 1 / 128
    def piece(i):
        return i / 8 + pad, (i + 1) / 8 - pad
    def quad(rect, uvs, wrapv):
        draw_quad(cv, rect_corners(cv, rect), uvs, tex, color, None, a, "BLEND", it.get("clip"), (False, wrapv))
    l0, l1 = piece(0)
    quad([L, B + e, L + e, T - e], [(l0, 0), (l0, ry), (l1, 0), (l1, ry)], True)
    r0, r1 = piece(1)
    quad([R - e, B + e, R, T - e], [(r0, 0), (r0, ry), (r1, 0), (r1, ry)], True)
    t0, t1 = piece(2)
    quad([L + e, T - e, R - e, T], [(t0, rx), (t1, rx), (t0, 0), (t1, 0)], True)
    b0, b1 = piece(3)
    quad([L + e, B, R - e, B + e], [(b0, rx), (b1, rx), (b0, 0), (b1, 0)], True)
    for i, rect in ((4, [L, T - e, L + e, T]), (5, [R - e, T - e, R, T]), (6, [L, B, L + e, B + e]), (7, [R - e, B, R, B + e])):
        c0, c1 = piece(i)
        quad(rect, [(c0, 0), (c0, 1), (c1, 0), (c1, 1)], False)


# --------------------------------------------------------------------------------------------------
# text
# --------------------------------------------------------------------------------------------------
_fonts = {}


def font_file(path):
    p = path.replace("/", "\\")
    up = p.upper()
    if up.startswith(ADDON_PREFIX):
        f = os.path.join(ROOT, p[len(ADDON_PREFIX):].replace("\\", os.sep))
        if os.path.exists(f):
            return f
    f = os.path.join(CACHE, "game", "fonts", os.path.basename(p).upper())
    if os.path.exists(f):
        return f
    c = casc()
    d = c and c.read(p)
    if d:
        os.makedirs(os.path.dirname(f), exist_ok=True)
        open(f, "wb").write(d)
        return f
    return os.path.join(CACHE, "game", "fonts", "FRIZQT__.TTF")


def font(path, px):
    key = (path.upper(), int(round(px * 4)))
    if key not in _fonts:
        try:
            _fonts[key] = ImageFont.truetype(font_file(path), max(1, int(round(px))))
        except OSError:
            _fonts[key] = ImageFont.load_default()
    return _fonts[key]


def parse_line(raw, color):
    """A line's escape codes -> segments (text or an inline texture) with their color; the color it ends with."""
    segs = []
    cur = color
    i, n = 0, len(raw)
    buf = []
    def flush():
        if buf:
            segs.append(("t", "".join(buf), cur))
            buf.clear()
    while i < n:
        ch = raw[i]
        if ch == "|" and i + 1 < n:
            nx = raw[i + 1]
            if nx == "|":
                buf.append("|"); i += 2; continue
            if nx == "c" and i + 10 <= n:
                flush()
                hx = raw[i + 2:i + 10]
                try:
                    cur = (int(hx[2:4], 16) / 255, int(hx[4:6], 16) / 255, int(hx[6:8], 16) / 255, 1)
                except ValueError:
                    pass
                i += 10; continue
            if nx == "r":
                flush(); cur = color; i += 2; continue
            if nx in "TA":
                flush()
                close = "|t" if nx == "T" else "|a"
                e = raw.find(close, i + 2)
                e = n if e < 0 else e
                segs.append(("i", raw[i + 2:e], cur))
                i = e + 2; continue
            if nx == "H":
                e = raw.find("|h", i + 2)
                i = n if e < 0 else e + 2; continue
            if nx in "hn":
                i += 2; continue
            if nx == "K":
                e = raw.find("|k", i + 2)
                i = n if e < 0 else e + 2; continue
        buf.append(ch)
        i += 1
    flush()
    return segs, cur


def draw_text(cv, it):
    r = it["r"]
    k = cv.k
    size = it["size"] * k
    if size < 1:
        return
    f = font(it["font"], size)
    lines = it.get("lines") or []
    spacing = it.get("spacing", 0) * k
    lh = it["size"] * k
    total = len(lines) * lh + max(0, len(lines) - 1) * spacing
    x0, ytop = cv.to_px(r[0], r[3])
    x1, ybot = cv.to_px(r[2], r[1])
    jv = (it.get("jv") or "MIDDLE").upper()
    if jv == "TOP":
        y = ytop
    elif jv == "BOTTOM":
        y = ybot - total
    else:
        y = (ytop + ybot) / 2 - total / 2
    asc, desc = f.getmetrics()
    base_off = lh * asc / max(1, asc + desc)
    color = tuple((list(it.get("color") or [1, 1, 1, 1]) + [1, 1, 1, 1])[:4])
    color = tuple(1 if c is None else c for c in color)
    shadow = it.get("shadow")
    flags = (it.get("flags") or "").upper()
    stroke = 2 if "THICK" in flags else (1 if "OUTLINE" in flags else 0)
    alpha = it.get("a", 1)
    clip = cv.clip_box(it.get("clip"))
    cur = color
    width_box = x1 - x0
    for raw, lw in lines:
        segs, cur_next = parse_line(raw, cur)
        lw_px = lw * k
        jh = (it.get("jh") or "CENTER").upper()
        if jh == "LEFT":
            x = x0
        elif jh == "RIGHT":
            x = x1 - lw_px
        else:
            x = (x0 + x1) / 2 - lw_px / 2
        draw_line(cv, segs, x, y + base_off, f, size, shadow, stroke, alpha, clip, it.get("truncated") and False)
        cur = cur_next
        y += lh + spacing


def draw_line(cv, segs, x, baseline, f, size, shadow, stroke, alpha, clip, _):
    # draw onto a small RGBA image, then composite
    widths = []
    total = 0
    for kind, val, col in segs:
        if kind == "t":
            wd = f.getlength(val)
        else:
            parts = val.split(":")
            h = float(parts[1]) if len(parts) > 1 and parts[1] not in ("", "0") else size
            wd = float(parts[2]) if len(parts) > 2 and parts[2] not in ("", "0") else h
            wd = wd * (cv.k if len(parts) > 1 and parts[1] not in ("", "0") else 1)
        widths.append(wd)
        total += wd
    pad = int(size) + 4
    Wd = int(math.ceil(total)) + 2 * pad
    Hd = int(math.ceil(size * 2)) + 2 * pad
    if Wd <= 0 or Hd <= 0:
        return
    img = Image.new("RGBA", (Wd, Hd), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    by = pad + size * 1.2
    ox = pad
    if shadow and len(shadow) >= 6 and (shadow[3] or 0) > 0:
        sx, sy = (shadow[4] or 0) * cv.k, -(shadow[5] or 0) * cv.k
        shade = tuple(int(255 * (c if c is not None else 0)) for c in shadow[:3]) + (int(255 * (shadow[3] or 1)),)
        xx = ox
        for (kind, val, col), wd in zip(segs, widths):
            if kind == "t":
                dr.text((xx + sx, by + sy), val, font=f, fill=shade, anchor="ls")
            xx += wd
    xx = ox
    inline = []
    for (kind, val, col), wd in zip(segs, widths):
        if kind == "t":
            fill = tuple(int(255 * max(0, min(1, c))) for c in col[:3]) + (255,)
            if stroke:
                dr.text((xx, by), val, font=f, fill=fill, anchor="ls", stroke_width=stroke, stroke_fill=(0, 0, 0, 255))
            else:
                dr.text((xx, by), val, font=f, fill=fill, anchor="ls")
        else:
            inline.append((xx, wd, val))
        xx += wd
    a = np.asarray(img, dtype=np.float32) / 255.0
    px0 = int(round(x - pad))
    py0 = int(round(baseline - by))
    blit(cv, a, px0, py0, alpha, clip)
    # inline textures: |Tpath:h:w:x:y|t, centred on the line
    for xx, wd, val in inline:
        parts = val.split(":")
        t = texture(parts[0])
        if t is None:
            continue
        h = wd
        tl = x - pad + xx
        top = baseline - size * 0.8 - (h - size) / 2
        rect = [0, 0, 0, 0]
        l, b, rr, tt = cv.crop
        rect = [tl / cv.k + l, tt - (top + h) / cv.k, (tl + wd) / cv.k + l, tt - top / cv.k]
        tc = [0, 0, 0, 1, 1, 0, 1, 1]
        if len(parts) >= 11:
            try:
                tw, th = float(parts[5]), float(parts[6])
                L_, R_, T_, B_ = float(parts[7]) / tw, float(parts[8]) / tw, float(parts[9]) / th, float(parts[10]) / th
                tc = [L_, T_, L_, B_, R_, T_, R_, B_]
            except (ValueError, ZeroDivisionError):
                pass
        draw_tex(cv, {"r": rect, "tex": parts[0], "tc": tc, "a": alpha})


def blit(cv, a, x0, y0, alpha, clip):
    h, w = a.shape[:2]
    cx0, cy0, cx1, cy1 = clip
    sx0, sy0 = max(x0, cx0), max(y0, cy0)
    sx1, sy1 = min(x0 + w, cx1), min(y0 + h, cy1)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    sub = a[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0]
    cv.blend(sx0, sy0, sub[..., :3], sub[..., 3] * alpha, "BLEND")


# --------------------------------------------------------------------------------------------------
# models
# --------------------------------------------------------------------------------------------------
def draw_model(cv, it, opts):
    try:
        import model
    except ImportError:
        model = None
    l, b, r, t = it["r"]
    x0, y0 = cv.to_px(l, t)
    x1, y1 = cv.to_px(r, b)
    w, h = int(round(x1 - x0)), int(round(y1 - y0))
    if w <= 0 or h <= 0:
        return
    img = None
    why = None
    if model is not None and it.get("loaded"):
        try:
            img = model.render_item(it, w, h, cv.k)
            if img is None:
                why = "no model file for it"
        except Exception as e:
            why = str(e)
            if why not in WARNED:
                WARNED.add(why)
                print("model %s (%s): %s" % (it.get("disp") or it.get("id"), it.get("frame"), e), file=sys.stderr)
    elif not it.get("loaded"):
        why = "not loaded"
    stat = {"frame": it.get("frame"), "disp": it.get("disp"), "kind": it.get("kind"), "id": it.get("id"), "r": it["r"], "drawn": img is not None, "why": why}
    if img is None:
        # not drawn: a marked box, so it shows in the picture
        img = np.zeros((h, w, 4), np.float32)
        img[:2, :, :] = img[-2:, :, :] = img[:, :2, :] = img[:, -2:, :] = (1, 0, 1, 0.8)
    else:
        stat.update(silhouette(img[..., 3]))
    cv.models.append(stat)
    clip = cv.clip_box(it.get("clip"))
    blit(cv, img, int(round(x0)), int(round(y0)), it.get("a", 1), clip)


def silhouette(a):
    """How a model sits in its frame: the share it covers, the edges it runs off, its box (0..1, from the top left)."""
    m = a > 0.5
    h, w = m.shape
    cov = float(m.mean()) if m.size else 0.0
    if not m.any():
        return {"cover": 0.0, "edges": [], "box": None}
    ys, xs = np.nonzero(m)
    edges = [e for e, hit in (("top", m[0].any()), ("bottom", m[-1].any()), ("left", m[:, 0].any()), ("right", m[:, -1].any())) if hit]
    return {"cover": round(cov, 3), "edges": edges,
            "box": [round(xs.min() / w, 3), round(ys.min() / h, 3), round((xs.max() + 1) / w, 3), round((ys.max() + 1) / h, 3)]}


# --------------------------------------------------------------------------------------------------
def render(scene, out, scale=1.0, crop=None, bg=None, opts=None):
    sw, sh = scene["screen"]
    if crop == "auto":
        crop = auto_crop(scene)
    cv = Canvas((sw, sh), scale, crop, bg)
    for it in scene["items"]:
        k = it.get("k")
        if k == "tex":
            draw_tex(cv, it)
        elif k == "text":
            draw_text(cv, it)
        elif k == "backdrop":
            draw_backdrop(cv, it)
        elif k == "model":
            draw_model(cv, it, opts or {})
    cv.save(out)
    if cv.models:
        json.dump(cv.models, open(os.path.splitext(out)[0] + ".models.json", "w"))
    return cv


def auto_crop(scene, pad=12):
    """The box around everything drawn (but not something filling the whole screen)."""
    sw, sh = scene["screen"]
    l, b, r, t = sw, sh, 0, 0
    for it in scene["items"]:
        x0, y0, x1, y1 = it["r"]
        if x1 - x0 >= sw * 0.98 and y1 - y0 >= sh * 0.98:
            continue
        l, b, r, t = min(l, x0), min(b, y0), max(r, x1), max(t, y1)
    if r <= l:
        return None
    return (max(0, l - pad), max(0, b - pad), min(sw, r + pad), min(sh, t + pad))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scene")
    ap.add_argument("-o", "--out")
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--crop", help="l,b,r,t in screen units, or 'auto'")
    ap.add_argument("--bg")
    a = ap.parse_args()
    crop = None
    if a.crop == "auto":
        crop = "auto"
    elif a.crop:
        crop = tuple(float(v) for v in a.crop.split(","))
    if os.path.isdir(a.scene):
        names = json.load(open(os.path.join(a.scene, "index.json")))
        for n in names:
            sc = json.load(open(os.path.join(a.scene, n + ".json")))
            out = os.path.join(a.scene, n + ".png")
            render(sc, out, a.scale, crop, a.bg)
            print("drew", out)
    else:
        sc = json.load(open(a.scene))
        out = a.out or os.path.splitext(a.scene)[0] + ".png"
        render(sc, out, a.scale, crop, a.bg)
        print("drew", out)
    if MISSING:
        print("textures not found (%d): %s" % (len(MISSING), ", ".join(sorted(MISSING)[:20])), file=sys.stderr)


if __name__ == "__main__":
    main()
