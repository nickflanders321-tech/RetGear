"""A model's particles (fire, smoke, water, glows) as one still frame, for model.py.

The game runs each emitter over time. A still frame of a model that has been on screen a while holds about
(emission rate x lifespan) particles of every age, so each emitter gets that many: born at random moments over one
lifespan, sent off at its speed and spread, pulled by gravity, and colored, faded and sized by their age as the
emitter's tracks say. They are drawn as sprites facing the camera, after the model, with the emitter's blending.
Close to the game's look, not exact: no drag, wind, twinkle, spin, tails or ribbons.
"""
import math, struct

import numpy as np

STRIDE = 492        # M2Particle (Legion+): M2ParticleOld (476 bytes) and four multi-texture parameters
MAX_PER_EMITTER = 300


def _arr(d, off):
    return struct.unpack_from("<II", d, off)


def _first(d, off, fmt):
    """An M2Track's first value (its first sequence that has keys), or None."""
    try:
        nvs, ovs = _arr(d, off + 12)
        for s in range(nvs):
            n, o = _arr(d, ovs + 8 * s)
            if n:
                return struct.unpack_from("<" + fmt, d, o)
    except struct.error:
        pass
    return None


def _fblock(d, off, fmt, size):
    """An M2PartTrack (over a particle's life): times 0..1 and values."""
    nt, ot = _arr(d, off)
    nv, ov = _arr(d, off + 8)
    if not nv:
        return None
    ts = np.array(struct.unpack_from("<%dh" % nt, d, ot), np.float64) / 32767.0 if nt == nv else np.linspace(0, 1, nv)
    vs = np.array([struct.unpack_from("<" + fmt, d, ov + size * k) for k in range(nv)], np.float64)
    return ts, vs


def _at(track, f, default):
    """A part track at life fractions f (array) -> values (len(f) x k)."""
    if track is None:
        return np.tile(np.array(default, np.float64), (len(f), 1))
    ts, vs = track
    return np.stack([np.interp(f, ts, vs[:, k]) for k in range(vs.shape[1])], 1)


def emitters(m):
    """The model's particle emitters, read from its file (cached on the model)."""
    if hasattr(m, "_emitters"):
        return m._emitters
    d = m.raw
    out = []
    n, o = _arr(d, 296)
    for i in range(n):
        e = o + STRIDE * i
        try:
            fl = struct.unpack_from("<I", d, e + 4)[0]
            pos = struct.unpack_from("<3f", d, e + 8)
            bone, tex = struct.unpack_from("<HH", d, e + 0x14)
            blend, etype = struct.unpack_from("<BB", d, e + 0x28)
            rows, cols = struct.unpack_from("<HH", d, e + 0x30)
            f = lambda off: (_first(d, e + off, "f") or (0.0,))[0]
            grav = 0.0, 0.0, -f(0x84)
            if fl & 0x800000:     # (gravity as a compressed vector: a direction and a strength)
                g = _first(d, e + 0x84, "bbh")
                if g:
                    x, y = g[0] / 128.0, g[1] / 128.0
                    z = math.sqrt(max(0.0, 1 - x * x - y * y))
                    mag = g[2] * 0.04238648
                    if mag < 0:
                        z, mag = -z, -mag
                    grav = x * mag, y * mag, z * mag
            enabled = _first(d, e + 0x1C8, "B")
            out.append({
                "flags": fl, "pos": pos, "bone": bone, "tex": tex & 0x1F if fl & 0x10000000 else tex,
                "blend": blend, "type": etype, "rows": max(1, rows), "cols": max(1, cols),
                "speed": f(0x34), "speed_vary": f(0x48), "vrange": f(0x5C), "hrange": f(0x70), "gravity": grav,
                "life": f(0x98), "life_vary": struct.unpack_from("<f", d, e + 0xAC)[0], "rate": f(0xB0),
                "length": f(0xC8), "width": f(0xDC),
                "color": _fblock(d, e + 0x104, "3f", 12), "alpha": _fblock(d, e + 0x114, "h", 2),
                "scale": _fblock(d, e + 0x124, "2f", 8), "scale_vary": struct.unpack_from("<2f", d, e + 0x134),
                "enabled": (enabled[0] if enabled else 1) != 0,
            })
        except struct.error:
            break
    m._emitters = out
    return out


def spawn(m, mats, seed=0):
    """Every emitter's particles in the posed model's space: a list of
    (emitter, centers N x 3, half sizes N x 2, colors N x 4 (rgb, alpha), cells N)."""
    rng = np.random.default_rng(seed)
    out = []
    for em in emitters(m):
        life = em["life"]
        if not em["enabled"] or life <= 0 or em["rate"] <= 0 or not math.isfinite(life + em["rate"]):
            continue
        n = int(min(MAX_PER_EMITTER, round(em["rate"] * life)))
        if n <= 0:
            continue
        lives = life * (1 + rng.uniform(-1, 1, n) * em["life_vary"])
        age = rng.uniform(0, 1, n) * lives
        frac = np.clip(age / np.maximum(lives, 1e-6), 0, 1)
        # where each is born and which way it goes, in the emitter's space (z up)
        h = rng.uniform(-1, 1, n) * em["hrange"]
        v = rng.uniform(-1, 1, n) * em["vrange"]
        if em["type"] == 2:       # sphere: from the middle outward (inward when the speed is negative)
            r = rng.uniform(0, 1, n) * max(em["length"], em["width"])
            polar = math.pi / 2 - v
            dirs = np.stack([np.sin(polar) * np.cos(h), np.sin(polar) * np.sin(h), np.cos(polar)], 1)
            start = dirs * r[:, None]
        else:                     # plane (and splines, drawn as a plane): up from a rectangle, within the spread
            start = np.stack([rng.uniform(-0.5, 0.5, n) * em["length"], rng.uniform(-0.5, 0.5, n) * em["width"], np.zeros(n)], 1)
            dirs = np.stack([np.sin(v) * np.cos(h), np.sin(v) * np.sin(h), np.cos(v)], 1)
        speed = em["speed"] * (1 + rng.uniform(-1, 1, n) * em["speed_vary"])
        vel = dirs * speed[:, None]
        # into the model's space, on its bone
        M = np.eye(4)
        M[:3, 3] = em["pos"]
        if mats is not None and 0 <= em["bone"] < len(mats):
            M = mats[em["bone"]] @ M
        start = start @ M[:3, :3].T + M[:3, 3]
        vel = vel @ M[:3, :3].T
        g = np.array(em["gravity"], np.float64)
        pos = start + vel * age[:, None] + 0.5 * g[None, :] * (age ** 2)[:, None]
        col = _at(em["color"], frac, (255, 255, 255)) / 255.0
        alpha = _at(em["alpha"], frac, (32767,))[:, 0] / 32767.0
        size = _at(em["scale"], frac, (0.1, 0.1))
        sv = em["scale_vary"]
        size = size * (1 + rng.uniform(-1, 1, n)[:, None] * np.array([sv[0], sv[1] or sv[0]])[None, :])
        cells = rng.integers(0, em["rows"] * em["cols"], n)
        keep = alpha > 0.01
        if keep.any():
            out.append((em, pos[keep], np.abs(size[keep]), np.c_[np.clip(col[keep], 0, 1), np.clip(alpha[keep], 0, 1)], cells[keep]))
    return out


_blob = None


def blob():
    """A soft round sprite, for an emitter whose texture can't be read."""
    global _blob
    if _blob is None:
        y, x = np.mgrid[-1:1:64j, -1:1:64j]
        a = np.clip(1 - np.sqrt(x * x + y * y), 0, 1) ** 2
        _blob = np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a]).astype(np.float32)
    return _blob


def quads(em, centers, half, colors, cells, right, up):
    """Camera-facing quads: vertices (4N x 3), uvs (4N x 2), per-vertex color (4N x 4), triangles (2N x 3)."""
    n = len(centers)
    corners = np.array([[-1, -1], [1, -1], [1, 1], [-1, 1]], np.float64)
    verts = (centers[:, None, :] + corners[None, :, 0:1] * half[:, None, 0:1] * right[None, None, :]
             + corners[None, :, 1:2] * half[:, None, 1:2] * up[None, None, :]).reshape(-1, 3)
    rows, cols = em["rows"], em["cols"]
    cu, cv = (cells % cols) / cols, (cells // cols) / rows
    uv = np.array([[0, 1], [1, 1], [1, 0], [0, 0]], np.float64)
    uvs = (np.stack([cu, cv], 1)[:, None, :] + uv[None, :, :] * np.array([1 / cols, 1 / rows])[None, None, :]).reshape(-1, 2)
    col = np.repeat(colors, 4, axis=0)
    b = np.arange(n) * 4
    tri = np.concatenate([np.stack([b, b + 1, b + 2], 1), np.stack([b, b + 2, b + 3], 1)])
    return verts.astype(np.float32), uvs.astype(np.float32), col.astype(np.float32), tri
