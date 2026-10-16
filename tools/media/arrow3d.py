#!/usr/bin/env python3
"""Render the 3D waypoint arrow as sprite sheets (Media/Arrow3D.tga, Media/Arrow3DSpec.tga).

100 frames, 10 x 10 cells of 102 px on a 1024 px sheet; frame i shows the arrow turned
i * 3.6 degrees counter-clockwise (0 = pointing straight up the screen). The body sheet is
grey shading with alpha, tinted in game with SetVertexColor; the spec sheet is the
highlight, added on top. Everything is drawn here: no game art, no third-party files.
Usage: python3 tools/media/arrow3d.py [out-dir]   (needs numpy)
"""
import sys, math, os
import numpy as np

FRAMES, COLS, CELL, SHEET, SS = 100, 10, 102, 1024, 4
OUT = sys.argv[1] if len(sys.argv) > 1 else 'Media'
EL = math.radians(58)          # camera elevation above the ground
H = 0.30                       # arrow thickness

# Crystal arrow: a faceted body with a ridge down the middle, flat-shaded like cut glass.
P = [(-0.21, -0.68), (0.21, -0.68), (0.21, 0.02), (0.56, 0.02), (0.0, 0.84), (-0.56, 0.02), (-0.21, 0.02)]
cx = sum(p[0] for p in P) / len(P); cy = sum(p[1] for p in P) / len(P)
def inset(p, k): return (cx + (p[0] - cx) * k, cy + (p[1] - cy) * k)
TOPK = 0.78
A = [inset(p, TOPK) for p in P]
A[2] = (A[2][0], 0.02); A[6] = (A[6][0], 0.02); A[3] = (A[3][0], 0.02); A[5] = (A[5][0], 0.02)
AZ = [H, H, H, H, H * 1.25, H, H]
S0 = (0.0, -0.62, H * 1.4); S1 = (0.0, 0.10, H * 1.8); C1 = (0.0, 0.42, H * 1.6)
def V(i): return (*A[i], AZ[i])
FACES = [
    (V(0), V(1), S0), (V(0), S0, S1), (V(0), S1, V(6)), (V(1), V(2), S1), (V(1), S1, S0),
    (V(5), V(6), S1), (V(3), S1, V(2)),
    (V(5), S1, C1), (V(5), C1, V(4)), (V(3), C1, S1), (V(3), V(4), C1),
]
for i in range(len(P)):
    j = (i + 1) % len(P)
    lo_a, lo_b = (*P[i], 0.0), (*P[j], 0.0)
    FACES.append((lo_a, lo_b, V(j))); FACES.append((lo_a, V(j), V(i)))
def mesh():
    out = []
    mid = np.array([cx, cy, H * 0.7])
    for tri in FACES:
        a, b, c = (np.array(p, float) for p in tri)
        n = np.cross(b - a, c - a)
        if np.linalg.norm(n) < 1e-9: continue
        n /= np.linalg.norm(n)
        if n @ ((a + b + c) / 3 - mid) < 0: n = -n
        out.append(([tuple(a), tuple(b), tuple(c)], tuple(n)))
    return out
MESH = mesh()

LIGHT = np.array([-0.45, -0.35, 0.82]); LIGHT /= np.linalg.norm(LIGHT)
VIEW = np.array([0.0, -math.cos(EL), math.sin(EL)])   # towards the camera
FILL = 0.92   # leave room around the arrow for its shadow

def render(theta, size):
    s = size
    zbuf = np.full((s, s), -1e9); body = np.zeros((s, s)); spec = np.zeros((s, s)); alpha = np.zeros((s, s)); ids = np.full((s, s), -1)
    ct, st = math.cos(theta), math.sin(theta)
    scale = s / 2.05 * FILL
    for fi, (pts, nrm) in enumerate(MESH):
        sp, cam = [], []
        for x, y, z in pts:
            rx, ry = x * ct - y * st, x * st + y * ct
            sx = rx * scale + s / 2
            sy = s / 2 - (ry * math.sin(EL) + (z - H) * math.cos(EL)) * scale * 0.95 - s * 0.05
            sp.append((sx, sy)); cam.append(-ry * math.cos(EL) + z * math.sin(EL))
        nx, ny, nz = nrm
        n = np.array([nx * ct - ny * st, nx * st + ny * ct, nz]); n /= np.linalg.norm(n)
        diff = max(0.0, float(n @ LIGHT))
        rr = 2 * float(n @ LIGHT) * n - LIGHT
        sh = 0.18 + 0.82 * diff ** 0.8
        sc = max(0.0, float(rr @ VIEW)) ** 14 * 0.7
        (x0, y0), (x1, y1), (x2, y2) = sp
        minx, maxx = int(max(0, math.floor(min(x0, x1, x2)))), int(min(s - 1, math.ceil(max(x0, x1, x2))))
        miny, maxy = int(max(0, math.floor(min(y0, y1, y2)))), int(min(s - 1, math.ceil(max(y0, y1, y2))))
        if maxx < minx or maxy < miny: continue
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-9: continue
        X, Y = np.meshgrid(np.arange(minx, maxx + 1) + 0.5, np.arange(miny, maxy + 1) + 0.5)
        w0 = ((y1 - y2) * (X - x2) + (x2 - x1) * (Y - y2)) / den
        w1 = ((y2 - y0) * (X - x2) + (x0 - x2) * (Y - y2)) / den
        w2 = 1 - w0 - w1
        inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        d = w0 * cam[0] + w1 * cam[1] + w2 * cam[2]
        sub = zbuf[miny:maxy + 1, minx:maxx + 1]
        win = inside & (d > sub)
        sub[win] = d[win]
        # a vertical gradient: brighter towards the tip, deeper towards the tail
        grad = 0.72 + 0.5 * np.clip((s * 0.9 - Y) / (s * 0.8), 0, 1)
        body[miny:maxy + 1, minx:maxx + 1][win] = np.clip(sh * grad[win], 0, 1)
        spec[miny:maxy + 1, minx:maxx + 1][win] = sc
        alpha[miny:maxy + 1, minx:maxx + 1][win] = 1
        ids[miny:maxy + 1, minx:maxx + 1][win] = fi
    # glowing facet edges and a soft rim
    edge = np.zeros((s, s))
    for dx, dy in ((1, 0), (0, 1), (1, 1)):
        a1 = ids[:s - dy, :s - dx]; b1 = ids[dy:, dx:]
        e = (a1 != b1) & (a1 >= 0) & (b1 >= 0)
        edge[:s - dy, :s - dx] = np.maximum(edge[:s - dy, :s - dx], e)
    spec = np.clip(spec + edge * 0.55, 0, 1)
    return body, spec, alpha

def blur(a, r):
    k = 2 * r + 1
    p = np.pad(a, r, mode='edge'); c = np.cumsum(np.cumsum(p, 0), 1)
    c = np.pad(c, ((1, 0), (1, 0)))
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)

def down(a, k): return a.reshape(CELL, k, CELL, k).mean(axis=(1, 3))

def main():
    big = CELL * SS
    sheet_b = np.zeros((SHEET, SHEET, 4), np.uint8); sheet_s = np.zeros((SHEET, SHEET, 4), np.uint8)
    for i in range(FRAMES):
        b, sp, a = render(math.radians(i * 360 / FRAMES), big)
        # soft ground shadow below the arrow, drawn dark into the body sheet
        shadow = blur(np.roll(a, int(big * 0.13), axis=0), int(big * 0.045)) * 0.42
        halo = np.clip(blur(a, int(big * 0.03)) - a, 0, 1)
        A = np.clip(down(a, SS) + down(np.maximum(shadow - a, 0), SS) * (1 - down(a, SS)), 0, 1)
        B = np.where(down(a, SS) > 0.01, down(b * a, SS) / np.maximum(down(a, SS), 1e-6), 0.0)
        S = down(sp * a, SS) + down(halo, SS) * 0.5
        r, c = divmod(i, COLS)
        y0, x0 = r * CELL, c * CELL
        g = np.clip(B * 255, 0, 255).astype(np.uint8)
        sheet_b[y0:y0 + CELL, x0:x0 + CELL, 0] = g; sheet_b[y0:y0 + CELL, x0:x0 + CELL, 1] = g; sheet_b[y0:y0 + CELL, x0:x0 + CELL, 2] = g
        sheet_b[y0:y0 + CELL, x0:x0 + CELL, 3] = np.clip(A * 255, 0, 255).astype(np.uint8)
        s8 = np.clip(S * 255, 0, 255).astype(np.uint8)
        for k in range(3): sheet_s[y0:y0 + CELL, x0:x0 + CELL, k] = s8
        sheet_s[y0:y0 + CELL, x0:x0 + CELL, 3] = 255   # additive: the colour alone carries the light
    os.makedirs(OUT, exist_ok=True)
    for name, arr in (('Arrow3D.tga', sheet_b), ('Arrow3DSpec.tga', sheet_s)):
        write_tga(os.path.join(OUT, name), arr)

def write_tga(path, rgba):
    h, w, _ = rgba.shape
    hdr = bytearray(18); hdr[2] = 2; hdr[12:14] = w.to_bytes(2, 'little'); hdr[14:16] = h.to_bytes(2, 'little'); hdr[16] = 32; hdr[17] = 0x28  # top-left origin, 8 alpha bits
    bgra = rgba[:, :, [2, 1, 0, 3]]
    with open(path, 'wb') as f: f.write(bytes(hdr)); f.write(bgra.tobytes())

if __name__ == '__main__': main()
