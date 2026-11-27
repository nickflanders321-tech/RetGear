"""Draw a creature model (M2) the way a model frame (DressUpModel) shows it, for render.py.

    python3 tools/render/model.py DISPLAYID [-o out.png] [--size 256x256] [--zoom 0.4] [--cam 1.0] [--facing 0.5]

The model and its textures come from the local install (casc.py); which model and skins a display id uses, from
the game's tables (modeldata.py). The camera follows the model frame's rules as far as we know them; the numbers
live in camera.json so calibration against real screenshots changes them without touching code (see README.md).
"""
import json, math, os, pickle, struct, sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "..", "harness", ".cache")
sys.path.insert(0, HERE)

_data = None
_casc = None
_cam = None


def casc():
    global _casc
    if _casc is None:
        from casc import Casc
        _casc = Casc()
    return _casc


def data():
    global _data
    if _data is None:
        p = os.path.join(CACHE, "models.json")
        if not os.path.exists(p):
            raise FileNotFoundError("no model tables: python3 tools/render/modeldata.py")
        d = json.load(open(p))
        _data = {k: {int(i): v for i, v in d[k].items()} for k in d}
        tf = os.path.join(CACHE, "texturefiles.json")
        _data["texfile"] = {int(k): v for k, v in json.load(open(tf)).items()} if os.path.exists(tf) else {}
    return _data


def camera_rules():
    global _cam
    if _cam is None:
        _cam = json.load(open(os.path.join(HERE, "camera.json")))
    return _cam


# --------------------------------------------------------------------------------------------------
# M2 and skin files
# --------------------------------------------------------------------------------------------------
class M2:
    pass


def _arr(d, off):
    return struct.unpack_from("<II", d, off)


def parse_m2(raw):
    chunks = {}
    if raw[:4] == b"MD21":
        p = 0
        while p + 8 <= len(raw):
            tag, size = raw[p:p + 4], struct.unpack_from("<I", raw, p + 4)[0]
            chunks[tag] = raw[p + 8:p + 8 + size]
            p += 8 + size
        d = chunks[b"MD21"]
    else:
        d = raw
    assert d[:4] == b"MD20", "not an M2"
    m = M2()
    m.version = struct.unpack_from("<I", d, 4)[0]
    m.flags = struct.unpack_from("<I", d, 16)[0]
    nv, ov = _arr(d, 60)
    vt = np.frombuffer(d, dtype=np.dtype([("pos", "<f4", 3), ("bw", "u1", 4), ("bi", "u1", 4), ("n", "<f4", 3), ("uv", "<f4", 2), ("uv2", "<f4", 2)]), count=nv, offset=ov)
    m.pos = vt["pos"].astype(np.float32).copy()
    m.normal = vt["n"].astype(np.float32).copy()
    m.uv = vt["uv"].astype(np.float32).copy()
    m.bw, m.bi = vt["bw"].copy(), vt["bi"].copy()
    m.nskins = struct.unpack_from("<I", d, 68)[0]
    nt, ot = _arr(d, 80)
    m.textures = []
    for i in range(nt):
        ty, fl = struct.unpack_from("<II", d, ot + 16 * i)
        m.textures.append({"type": ty, "flags": fl})
    def u16s(off):
        n, o = _arr(d, off)
        return list(struct.unpack_from("<%dH" % n, d, o)) if n else []
    def i16s(off):
        n, o = _arr(d, off)
        return list(struct.unpack_from("<%dh" % n, d, o)) if n else []
    nm, om = _arr(d, 112)
    m.materials = [struct.unpack_from("<HH", d, om + 4 * i) for i in range(nm)]
    m.texture_combos = i16s(128)
    m.weight_combos = u16s(144)
    m.bbox = struct.unpack_from("<6f", d, 160)
    m.radius = struct.unpack_from("<f", d, 184)[0]
    # texture weights (transparency) and colors: their first value
    m.weights = [_track_first(d, o, "h") for o in _track_list(d, 88, 20)]
    m.colors = [(_track_first(d, o, "3f"), _track_first(d, o + 20, "h")) for o in _track_list(d, 72, 40)]
    # cameras: portrait (type 0) and character info (1)
    m.cameras = []
    nc, oc = _arr(d, 272)
    for i in range(nc):
        o = oc + 116 * i
        ty, far, near = struct.unpack_from("<Iff", d, o)
        pos_base = struct.unpack_from("<3f", d, o + 32)
        tgt_base = struct.unpack_from("<3f", d, o + 64)
        pk = _track_first(d, o + 12, "9f")
        tk = _track_first(d, o + 44, "9f")
        fov = _track_first(d, o + 96, "3f")
        p = tuple(pos_base[j] + (pk[j] if pk else 0) for j in range(3))
        t = tuple(tgt_base[j] + (tk[j] if tk else 0) for j in range(3))
        m.cameras.append({"type": ty, "pos": p, "target": t, "fov": (fov[0] if fov else None)})
    # animation: sequences (64 bytes each) and bones (88 bytes), read when posing
    m.sequences = []
    ns_, os2 = _arr(d, 28)
    for i in range(ns_):
        o = os2 + 64 * i
        sid, var, dur = struct.unpack_from("<HHI", d, o)
        flags = struct.unpack_from("<I", d, o + 12)[0]
        bounds = struct.unpack_from("<6f", d, o + 32)
        m.sequences.append({"id": sid, "var": var, "dur": dur, "flags": flags, "bounds": bounds})
    m.bones = []
    nbn, obn = _arr(d, 44)
    for i in range(nbn):
        o = obn + 88 * i
        key, fl, parent, sub = struct.unpack_from("<iIhH", d, o)
        m.bones.append({"parent": parent, "flags": fl, "trans": o + 16, "rot": o + 36, "scale": o + 56,
                        "pivot": struct.unpack_from("<3f", d, o + 76)})
    m.afid = {}
    if b"AFID" in chunks:
        a = chunks[b"AFID"]
        for i in range(len(a) // 8):
            aid, sub, fid = struct.unpack_from("<HHI", a, 8 * i)
            if fid:
                m.afid[(aid, sub)] = fid
    m.skid = struct.unpack_from("<I", chunks[b"SKID"])[0] if b"SKID" in chunks else 0
    m.raw = bytes(d)
    m.sfid = list(struct.unpack_from("<%dI" % (len(chunks[b"SFID"]) // 4), chunks[b"SFID"])) if b"SFID" in chunks else []
    m.txid = list(struct.unpack_from("<%dI" % (len(chunks[b"TXID"]) // 4), chunks[b"TXID"])) if b"TXID" in chunks else []
    return m


def _track_list(d, off, size):
    n, o = _arr(d, off)
    return [o + size * i for i in range(n)]


def _track_first(d, off, fmt):
    """The first value of an M2Track (its first sequence's first key), or None."""
    try:
        nts, ots = _arr(d, off + 4)
        nvs, ovs = _arr(d, off + 12)
        for s in range(nvs):
            n, o = _arr(d, ovs + 8 * s)
            if n:
                v = struct.unpack_from("<" + fmt, d, o)
                if fmt == "h":
                    return v[0] / 32767.0
                return v
    except struct.error:
        pass
    return None


def parse_skin(d):
    assert d[:4] == b"SKIN"
    nv, ov = _arr(d, 4)
    ni, oi = _arr(d, 12)
    ns, os_ = _arr(d, 28)
    nb, ob = _arr(d, 36)
    verts = np.frombuffer(d, "<u2", nv, ov).astype(np.int64)
    idx = np.frombuffer(d, "<u2", ni, oi).astype(np.int64)
    subs = []
    for i in range(ns):
        sid, lvl, vs, vc, ist, ic = struct.unpack_from("<6H", d, os_ + 48 * i)
        subs.append({"id": sid, "istart": ist + (lvl << 16), "icount": ic})
    batches = []
    for i in range(nb):
        fl, prio, shader, sub, geo, color, mat, layer, tcount, tcombo, tcc, wcombo, ttcombo = struct.unpack_from("<BbHHHHHHHHHHH", d, ob + 24 * i)
        batches.append({"flags": fl, "prio": prio, "sub": sub, "color": color, "mat": mat, "layer": layer, "tcount": tcount,
                        "tcombo": tcombo, "wcombo": wcombo})
    return verts, idx, subs, batches


# --------------------------------------------------------------------------------------------------
# the pose: the first frame of an animation (Stand), from the bones
# --------------------------------------------------------------------------------------------------
def _quat(v):
    q = [((x + 32768) if x < 0 else (x - 32767)) / 32767.0 for x in v]
    return q   # x, y, z, w


def _track_key(m, anim_data, off, si, fmt, size):
    """A track's first value in sequence si (or its global sequence), or None."""
    d = m.raw
    try:
        interp, gseq = struct.unpack_from("<Hh", d, off)
        nts, ots = _arr(d, off + 4)
        nvs, ovs = _arr(d, off + 12)
    except struct.error:
        return None
    idx = 0 if gseq >= 0 else si
    if idx >= nvs:
        return None
    n, o = _arr(d, ovs + 8 * idx)
    if not n:
        return None
    src = d
    if gseq < 0 and anim_data is not None:
        src = anim_data
    try:
        return struct.unpack_from("<" + fmt, src, o)
    except struct.error:
        return None


def _mat_trs(t, q, sc, pivot):
    x, y, z, w = q
    R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                  [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                  [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]], np.float64)
    M = np.eye(4)
    M[:3, :3] = R * np.array(sc)[None, :]
    p = np.array(pivot)
    M[:3, 3] = p + np.array(t) - M[:3, :3] @ p
    return M


def find_sequence(m, anim=0):
    for i, sq in enumerate(m.sequences):
        if sq["id"] == anim and sq["var"] == 0:
            return i
    for i, sq in enumerate(m.sequences):
        if sq["id"] == 0:
            return i
    return 0 if m.sequences else None


def pose(m, anim=0):
    """The model's vertices and normals in the first frame of an animation (Stand by default)."""
    si = find_sequence(m, anim)
    if si is None or not m.bones:
        return m.pos, m.normal, None
    sq = m.sequences[si]
    anim_data = None
    if not (sq["flags"] & 0x20):   # (its keys live in an .anim file of their own)
        fid = m.afid.get((sq["id"], sq["var"]))
        raw = fid and casc().read(fid)
        if raw:
            anim_data = raw[8:8 + struct.unpack_from("<I", raw, 4)[0]] if raw[:4] == b"AFM2" else raw
        else:
            return m.pos, m.normal, sq["bounds"]
    mats = [None] * len(m.bones)
    for i, b in enumerate(m.bones):
        t = _track_key(m, anim_data, b["trans"], si, "3f", 12) or (0, 0, 0)
        q = _track_key(m, anim_data, b["rot"], si, "4h", 8)
        q = _quat(q) if q else (0, 0, 0, 1)
        sc = _track_key(m, anim_data, b["scale"], si, "3f", 12) or (1, 1, 1)
        M = _mat_trs(t, q, sc, b["pivot"])
        p = b["parent"]
        if 0 <= p < i and mats[p] is not None:
            M = mats[p] @ M
        mats[i] = M
    mats = np.array([x if x is not None else np.eye(4) for x in mats])
    nb = len(mats)
    bi = np.clip(m.bi.astype(np.int64), 0, nb - 1)
    bw = m.bw.astype(np.float64) / 255.0
    P = np.c_[m.pos, np.ones(len(m.pos))]
    out = np.zeros((len(m.pos), 3))
    nout = np.zeros((len(m.pos), 3))
    for k in range(4):
        Mk = mats[bi[:, k]]
        out += bw[:, k:k + 1] * np.einsum("nij,nj->ni", Mk[:, :3, :], P)
        nout += bw[:, k:k + 1] * np.einsum("nij,nj->ni", Mk[:, :3, :3], m.normal)
    nn = np.linalg.norm(nout, axis=1, keepdims=True)
    nout = nout / np.maximum(nn, 1e-6)
    # (a vertex with no weights stays where it is)
    none = bw.sum(1) < 1e-3
    out[none] = m.pos[none]
    nout[none] = m.normal[none]
    return out.astype(np.float32), nout.astype(np.float32), sq["bounds"]


_models = {}


def load_model(fid):
    if fid in _models:
        return _models[fid]
    cp = os.path.join(CACHE, "game", "m2", "%d.pickle" % fid)
    if os.path.exists(cp):
        m = pickle.load(open(cp, "rb"))
    else:
        raw = casc().read(fid)
        if not raw:
            raise FileNotFoundError("model file %d is not in the install" % fid)
        m = parse_m2(raw)
        if not m.sfid:
            raise ValueError("model %d has no skin file list" % fid)
        sk = casc().read(m.sfid[0])
        if not sk:
            raise FileNotFoundError("skin file %d is not in the install" % m.sfid[0])
        m.skin = parse_skin(sk)
        os.makedirs(os.path.dirname(cp), exist_ok=True)
        pickle.dump(m, open(cp, "wb"))
    _models[fid] = m
    return m


# --------------------------------------------------------------------------------------------------
# textures
# --------------------------------------------------------------------------------------------------
_tex = {}


def load_tex(fid):
    if not fid:
        return None
    if fid in _tex:
        return _tex[fid]
    if isinstance(fid, tuple):
        _tex[fid] = composite(fid)
        return _tex[fid]
    t = None
    try:
        import io
        from PIL import Image
        raw = casc().read(int(fid))
        if raw:
            t = np.asarray(Image.open(io.BytesIO(raw)).convert("RGBA"), dtype=np.float32) / 255.0
    except Exception as e:
        print("texture %s: %s" % (fid, e), file=sys.stderr)
    _tex[fid] = t
    return t


def texture_for(m, ti, disp):
    """The FileDataID of the model's texture slot ti for this display."""
    t = m.textures[ti]
    ty = t["type"]
    if ty == 0:
        return m.txid[ti] if ti < len(m.txid) else None
    if ty in (11, 12, 13):
        tex = (disp or {}).get("tex") or []
        k = ty - 11
        return tex[k] if k < len(tex) and tex[k] else None
    ex = extra_for(disp)
    if ty == 1 and ex:
        for key in ("hdbake", "bake"):
            f = data()["texfile"].get(ex.get(key) or 0)
            if f:
                return f
    if ex and (ex.get("tex") or {}).get(str(ty)):
        # hair (6), eyes (19) and the rest: the customization's layers (modeldata.customizations)
        lay = ex["tex"][str(ty)]
        return lay[0][0] if len(lay) == 1 else tuple(tuple(l) for l in lay)
    return None


def extra_for(disp):
    return data()["extra"].get(disp["extra"]) if disp and disp.get("extra") else None


def composite(layers):
    """Texture layers stacked bottom first; each later one over the earlier ones by its alpha (resized to the
    bottom layer). Only plain alpha blending (mode 1) is drawn: the other modes are rare overlays."""
    base = load_tex(layers[0][0])
    if base is None:
        return None
    out = base.copy()
    for fid, blend in layers[1:]:
        t = load_tex(fid)
        if t is None or blend != 1:
            continue
        if t.shape[:2] != out.shape[:2]:
            from PIL import Image
            img = Image.fromarray((t * 255).astype(np.uint8)).resize((out.shape[1], out.shape[0]))
            t = np.asarray(img, dtype=np.float32) / 255.0
        a = t[..., 3:4]
        out[..., :3] = t[..., :3] * a + out[..., :3] * (1 - a)
    return out


# --------------------------------------------------------------------------------------------------
# which parts show (geosets)
# --------------------------------------------------------------------------------------------------
CHAR_DEFAULT_GEOSET = {17: 0, 32: 2}


def visible_subs(subs, rules, ex=None):
    ids = sorted({s["id"] for s in subs})
    show = set()
    groups = {}
    for i in ids:
        groups.setdefault(i // 100, []).append(i)
    if ex and ex.get("geo") is not None:
        # a humanoid NPC (character model): its customization picks hair, beard, ears, face...; every other group
        # shows its default, xx01 (none of them for the groups the model has no xx01 for). Id 0 hides a group.
        # Except: the eye glows (17: death knight and primalist eyes) show only when an eye color picks them, and the
        # face (32) is 3202 in every race's model (3201 is a small stub; human face shapes pick 2-4).
        geo = {int(k): v for k, v in ex["geo"].items()}
        show.add(0)
        for g, lst in groups.items():
            if g in rules.get("hide_groups", []):
                continue
            want = g * 100 + geo.get(g, CHAR_DEFAULT_GEOSET.get(g, 1))
            if want in lst and (g > 0 or geo.get(0)):
                show.add(want)
        return show
    for g, lst in groups.items():
        if g == 0:
            show.add(0) if 0 in lst else None
            nz = [i for i in lst if i != 0]
            if nz:
                show.add(nz[0])
        elif g in rules.get("hide_groups", []):
            continue
        else:
            show.add(lst[0])
    return show


# --------------------------------------------------------------------------------------------------
# the camera
# --------------------------------------------------------------------------------------------------
def look_at(eye, target, up=(0, 0, 1)):
    eye, target, up = np.array(eye, float), np.array(target, float), np.array(up, float)
    f = target - eye
    f /= np.linalg.norm(f) or 1
    r = np.cross(f, up)
    if np.linalg.norm(r) < 1e-6:
        r = np.array([0, 1, 0], float)
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return r, u, f


def fit_size_px(it, rules):
    """The frame's height in pixels when its camera was last set (the game fixes the camera then)."""
    resets = set(rules["camera_resets_on"])
    size = None
    for e in it.get("log") or []:
        if e.get("call") in resets and isinstance(e.get("size"), list):
            size = e["size"]
    return size


def camera_for(m, it, w, h, k, rules):
    """Eye, target and vertical field of view for a model frame showing m."""
    b = m.bbox
    lo, hi = np.array(b[:3]), np.array(b[3:])
    center = (lo + hi) / 2
    height = max(1e-3, hi[2] - lo[2])
    fov = rules["fov"]
    # full body: the whole model in view, from the front (+x), at its middle. "fit" says what has to fit the frame's
    # height: "height" (the model's height), "sphere" (its bounding sphere), "box" (height or width, the larger)
    fit = rules.get("fit", "height")
    width = max(1e-3, hi[1] - lo[1])
    aspect = w / max(1, h)
    if fit == "sphere":
        span = float(np.linalg.norm(hi - lo))
    elif fit == "box":
        span = max(height, width / aspect)
    else:
        span = height
    dist = (span / 2) / math.tan(fov / 2) * rules["body_margin"]
    ex = center[0] + dist + (hi[0] - center[0] if rules.get("from_box_front") else 0)
    ex = max(ex, hi[0] + 0.1 * span)   # (never inside a long model)
    body_eye = np.array([ex, center[1], center[2]])
    body_tgt = center.copy()
    # portrait: the model's own portrait camera, else the top of the box
    pc = next((c for c in m.cameras if c["type"] == 0), None)
    if pc:
        por_eye, por_tgt = np.array(pc["pos"]), np.array(pc["target"])
    else:
        head = np.array([center[0], center[1], hi[2] - height * 0.12])
        por_tgt = head
        por_eye = head + np.array([height * 0.55, 0, 0])
    body_fov = por_fov = fov
    # the model's own cameras, as the game uses them: its "character info" camera (type 1) for the whole body, its
    # portrait camera (type 0) for SetPortraitZoom(1); the zoom goes between the two
    if rules.get("body") == "model_camera":
        bc = next((c for c in m.cameras if c["type"] == 1), None)
        if bc:
            body_eye, body_tgt = np.array(bc["pos"], float), np.array(bc["target"], float)
            body_fov = bc["fov"] or fov
        else:
            # (no body camera: the fallback, tuned on a model that lacks one, Tepolar)
            d2 = (height / 2) / math.tan(fov / 2) * rules.get("no_body_camera_margin", 1.0)
            body_eye = np.array([max(center[0] + d2, hi[0] + 0.1 * height), center[1], center[2] + rules.get("no_body_camera_raise", 0) * height])
            body_tgt = np.array([center[0], center[1], center[2] + rules.get("no_body_camera_raise", 0) * height])
        if pc and pc.get("fov"):
            por_fov = pc["fov"]
    z = max(0.0, min(1.0, float(it.get("zoom") or 0)))
    eye = body_eye * (1 - z) + por_eye * z
    tgt = body_tgt * (1 - z) + por_tgt * z
    fov = body_fov * (1 - z) + por_fov * z
    # the model's cameras store a diagonal field of view: the vertical one depends on the frame's shape
    mode = rules.get("fov_mode", "vertical")
    if mode == "diagonal":
        fov = 2 * math.atan(math.tan(fov / 2) / math.hypot(1, w / max(1, h)))
    elif mode == "horizontal":
        fov = 2 * math.atan(math.tan(fov / 2) / max(1e-3, w / max(1, h)))
    # the camera distance scale: back along the view line
    cam = float(it.get("cam") or 1)
    eye = tgt + (eye - tgt) * cam
    # a model whose camera was set while the frame was another size keeps that framing: it is drawn magnified by
    # (size now / size then)
    mag = 1.0
    if rules.get("camera_fixed_at_fit_size"):
        fs = fit_size_px(it, rules)
        if fs and fs[1] > 0:
            now_h = (it["r"][3] - it["r"][1])
            mag = now_h / fs[1]
    return eye, tgt, fov, mag


# --------------------------------------------------------------------------------------------------
# drawing
# --------------------------------------------------------------------------------------------------
BLEND = {0: "opaque", 1: "alphakey", 2: "alpha", 3: "add", 4: "add", 5: "mod", 6: "mod2x", 7: "add"}


def render(fid, disp, it, w, h, k=1.0, supersample=2):
    rules = camera_rules()
    m = load_model(fid)
    verts, idx, subs, batches = m.skin
    W, H = w * supersample, h * supersample
    # pose: scale, facing, position (model space: x forward, y left, z up)
    if rules.get("pose", True):
        p, n, seq_box = pose(m, int(it.get("anim") or 0))
        p, n = p.copy(), n.copy()
    else:
        p, n, seq_box = m.pos.copy(), m.normal.copy(), None
    s = float(it.get("scale") or 1) * float((disp or {}).get("scale") or 1) if rules.get("use_display_scale") else float(it.get("scale") or 1)
    p *= s
    f = float(it.get("facing") or 0)
    c, sn = math.cos(f), math.sin(f)
    R = np.array([[c, -sn, 0], [sn, c, 0], [0, 0, 1]], np.float32)
    p = p @ R.T
    n = n @ R.T
    pos = it.get("pos") or [0, 0, 0]
    p += np.array([pos[0] or 0, pos[1] or 0, pos[2] or 0], np.float32)
    # camera (the box is the posed one, so facing doesn't move the framing)
    m2 = M2()
    m2.__dict__.update(m.__dict__)
    if not len(p):
        raise ValueError("no vertices (a model made only of particles?)")
    lo, hi = p.min(0), p.max(0)
    # what the camera frames: "sequence" (the animation's own bounds, as the client stores them), "model" (the
    # model's box), else the posed vertices
    src = rules.get("frame_by", "vertices")
    if src == "sequence" and seq_box:
        bb = list(seq_box)
    elif src == "model":
        bb = list(m.bbox)
    else:
        bb = None
    if bb:
        # (turned with the model: its facing moves the box's corners)
        corners = np.array([[x, y, z] for x in (bb[0], bb[3]) for y in (bb[1], bb[4]) for z in (bb[2], bb[5])], np.float32) * s
        corners = corners @ R.T
        m2.bbox = list(corners.min(0)) + list(corners.max(0))
    else:
        m2.bbox = list(lo) + list(hi)
    cs = float((disp or {}).get("scale") or 1) if rules.get("use_display_scale") else 1.0
    m2.cameras = [dict(cc, pos=tuple(np.array(cc["pos"]) * cs), target=tuple(np.array(cc["target"]) * cs)) for cc in m.cameras]
    eye, tgt, fov, mag = camera_for(m2, it, w, h, k, rules)
    r, u, fw = look_at(eye, tgt)
    rel = p - eye
    cx = rel @ r
    cy = rel @ u
    cz = rel @ fw
    focal = (H / 2) / math.tan(fov / 2) * mag
    with np.errstate(divide="ignore", invalid="ignore"):
        sx = W / 2 + cx * focal / cz
        sy = H / 2 - cy * focal / cz
    # light: from the front, above and to the left
    L = np.array(rules["light_dir"], np.float32)
    L = L / np.linalg.norm(L)
    Lw = L[0] * r + L[1] * u + L[2] * (-fw)
    shade = rules["ambient"] + rules["diffuse"] * np.clip(n @ Lw, 0, 1)
    color = np.zeros((H, W, 3), np.float32)
    alpha = np.zeros((H, W), np.float32)
    zbuf = np.full((H, W), np.inf, np.float32)
    show = visible_subs(subs, rules, extra_for(disp))
    def blended(i):
        mi = batches[i]["mat"]
        mode = BLEND.get(m.materials[mi][1], "opaque") if mi < len(m.materials) else "opaque"
        return mode not in ("opaque", "alphakey")
    order = sorted(range(len(batches)), key=lambda i: (blended(i), batches[i]["prio"], i))
    for bi in order:
        bt = batches[bi]
        if bt["sub"] >= len(subs):
            continue
        sub = subs[bt["sub"]]
        if sub["id"] not in show:
            continue
        mat = m.materials[bt["mat"]] if bt["mat"] < len(m.materials) else (0, 0)
        mode = BLEND.get(mat[1], "opaque")
        unlit = mat[0] & 0x1
        two_sided = mat[0] & 0x4
        ti = m.texture_combos[bt["tcombo"]] if bt["tcombo"] < len(m.texture_combos) else -1
        fidt = texture_for(m, ti, disp) if 0 <= ti < len(m.textures) else None
        tex = load_tex(fidt)
        if tex is None and mode in ("add", "mod", "mod2x"):
            continue
        wv = 1.0
        if bt["wcombo"] < len(m.weight_combos):
            wi = m.weight_combos[bt["wcombo"]]
            if wi < len(m.weights) and m.weights[wi] is not None:
                wv = m.weights[wi]
        if wv <= 0.01:
            continue
        tri = idx[sub["istart"]:sub["istart"] + sub["icount"]]
        tri = verts[tri].reshape(-1, 3)
        _raster(tri, sx, sy, cz, m.uv, shade if not unlit else np.ones_like(shade), tex, mode, wv, color, alpha, zbuf, two_sided)
    if supersample > 1:
        # average with premultiplied alpha, so edges don't darken
        pm = (color * alpha[..., None]).reshape(h, supersample, w, supersample, 3).mean(axis=(1, 3))
        alpha = alpha.reshape(h, supersample, w, supersample).mean(axis=(1, 3))
        color = pm / np.maximum(alpha[..., None], 1e-6)
    return np.dstack([color, alpha])


def _raster(tri, sx, sy, cz, uv, shade, tex, mode, weight, color, alpha, zbuf, two_sided):
    H, W = zbuf.shape
    near = 0.05
    a, b, c = tri[:, 0], tri[:, 1], tri[:, 2]
    ok = (cz[a] > near) & (cz[b] > near) & (cz[c] > near)
    a, b, c = a[ok], b[ok], c[ok]
    if not len(a):
        return
    ax, ay, bx, by, cx, cy = sx[a], sy[a], sx[b], sy[b], sx[c], sy[c]
    area = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay)
    keep = np.abs(area) > 1e-9
    if not two_sided:
        keep &= area < 0       # (front faces wind clockwise on screen with y down)
    a, b, c = a[keep], b[keep], c[keep]
    ax, ay, bx, by, cx, cy, area = ax[keep], ay[keep], bx[keep], by[keep], cx[keep], cy[keep], area[keep]
    if not len(a):
        return
    x0 = np.clip(np.floor(np.minimum(np.minimum(ax, bx), cx)), 0, W).astype(np.int64)
    x1 = np.clip(np.ceil(np.maximum(np.maximum(ax, bx), cx)), 0, W).astype(np.int64)
    y0 = np.clip(np.floor(np.minimum(np.minimum(ay, by), cy)), 0, H).astype(np.int64)
    y1 = np.clip(np.ceil(np.maximum(np.maximum(ay, by), cy)), 0, H).astype(np.int64)
    bw, bh = x1 - x0, y1 - y0
    cnt = bw * bh
    good = cnt > 0
    if not good.any():
        return
    # every (triangle, pixel) pair inside each triangle's box, in chunks to keep memory down
    tri_ids = np.nonzero(good)[0]
    start = 0
    while start < len(tri_ids):
        acc = np.cumsum(cnt[tri_ids[start:]])
        end = start + max(1, int(np.searchsorted(acc, 4_000_000)))
        ids = tri_ids[start:end]
        start = end
        n = cnt[ids]
        t = np.repeat(ids, n)
        off = np.arange(n.sum()) - np.repeat(np.cumsum(n) - n, n)
        px = x0[t] + off % bw[t]
        py = y0[t] + off // bw[t]
        gx, gy = px + 0.5, py + 0.5
        w0 = ((bx[t] - gx) * (cy[t] - gy) - (cx[t] - gx) * (by[t] - gy)) / area[t]
        w1 = ((cx[t] - gx) * (ay[t] - gy) - (ax[t] - gx) * (cy[t] - gy)) / area[t]
        w2 = 1 - w0 - w1
        ins = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        t, px, py, w0, w1, w2 = t[ins], px[ins], py[ins], w0[ins], w1[ins], w2[ins]
        if not len(t):
            continue
        va, vb, vc = a[t], b[t], c[t]
        iz = w0 / cz[va] + w1 / cz[vb] + w2 / cz[vc]
        z = 1 / iz
        u = (w0 * uv[va, 0] / cz[va] + w1 * uv[vb, 0] / cz[vb] + w2 * uv[vc, 0] / cz[vc]) * z
        v = (w0 * uv[va, 1] / cz[va] + w1 * uv[vb, 1] / cz[vb] + w2 * uv[vc, 1] / cz[vc]) * z
        sh = (w0 * shade[va] + w1 * shade[vb] + w2 * shade[vc])
        if tex is not None:
            th, tw = tex.shape[:2]
            tx = (np.mod(u, 1.0) * tw).astype(np.int64) % tw
            ty = (np.mod(v, 1.0) * th).astype(np.int64) % th
            s = tex[ty, tx]
        else:
            s = np.tile(np.array([0.55, 0.52, 0.5, 1.0], np.float32), (len(t), 1))
        rgb = s[:, :3] * sh[:, None]
        al = s[:, 3] * weight
        if mode in ("opaque",):
            al = np.ones_like(al) * weight
        if mode == "alphakey":
            keep = al > 0.5
            rgb, al, px, py, z = rgb[keep], np.ones(keep.sum(), np.float32), px[keep], py[keep], z[keep]
        if mode in ("opaque", "alphakey"):
            # nearest fragment per pixel wins
            key = py * W + px
            ordr = np.lexsort((z, key))
            key, z, rgb, px, py = key[ordr], z[ordr], rgb[ordr], px[ordr], py[ordr]
            first = np.ones(len(key), bool)
            first[1:] = key[1:] != key[:-1]
            px, py, z, rgb = px[first], py[first], z[first], rgb[first]
            closer = z < zbuf[py, px]
            px, py, z, rgb = px[closer], py[closer], z[closer], rgb[closer]
            zbuf[py, px] = z
            color[py, px] = rgb
            alpha[py, px] = 1
        else:
            vis = z < zbuf[py, px]
            px, py, z, rgb, al = px[vis], py[vis], z[vis], rgb[vis], al[vis]
            if not len(px):
                continue
            # far to near, one layer per pixel at a time
            key = py * W + px
            ordr = np.lexsort((-z, key))
            key, rgb, al, px, py = key[ordr], rgb[ordr], al[ordr], px[ordr], py[ordr]
            first_idx = np.r_[0, np.nonzero(key[1:] != key[:-1])[0] + 1]
            rank = np.arange(len(key)) - np.repeat(first_idx, np.diff(np.r_[first_idx, len(key)]))
            for rk in range(int(rank.max()) + 1):
                sel = rank == rk
                X, Y, C, A = px[sel], py[sel], rgb[sel], al[sel][:, None]
                if mode == "add":
                    color[Y, X] = np.clip(color[Y, X] + C * A, 0, 1)
                    alpha[Y, X] = np.clip(alpha[Y, X] + A[:, 0] * 0.5, 0, 1)
                elif mode in ("mod", "mod2x"):
                    k2 = 2 if mode == "mod2x" else 1
                    color[Y, X] = np.clip(color[Y, X] * (C * k2 * A + (1 - A)), 0, 1)
                else:
                    color[Y, X] = C * A + color[Y, X] * (1 - A)
                    alpha[Y, X] = A[:, 0] + alpha[Y, X] * (1 - A[:, 0])


def render_item(it, w, h, k=1.0):
    """A scene's model item -> an h x w x 4 float image (render.py), or None when it can't be drawn."""
    d = data()
    disp = d["display"].get(it.get("disp")) if it.get("disp") else None
    fid = (disp or {}).get("file") or it.get("file")
    if not fid:
        return None
    return render(int(fid), disp, it, w, h, k)


def main():
    import argparse
    from PIL import Image
    ap = argparse.ArgumentParser()
    ap.add_argument("display", type=int)
    ap.add_argument("-o", "--out")
    ap.add_argument("--size", default="256x256")
    ap.add_argument("--zoom", type=float, default=0)
    ap.add_argument("--cam", type=float, default=1)
    ap.add_argument("--facing", type=float, default=0.5)
    a = ap.parse_args()
    w, h = (int(v) for v in a.size.split("x"))
    it = {"disp": a.display, "zoom": a.zoom, "cam": a.cam, "facing": a.facing, "pos": [0, 0, 0], "scale": 1, "r": [0, 0, w, h], "log": []}
    img = render_item(it, w, h)
    if img is None:
        print("display %d has no model" % a.display)
        return
    bg = np.zeros((h, w, 3), np.float32) + 0.15
    rgb = img[..., :3] * img[..., 3:4] + bg * (1 - img[..., 3:4])
    out = a.out or "display-%d.png" % a.display
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(out)
    print("drew", out)


if __name__ == "__main__":
    main()
