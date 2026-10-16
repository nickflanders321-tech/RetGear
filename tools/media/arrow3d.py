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
EL = math.radians(52)          # camera elevation above the ground
H = 0.26                       # arrow thickness

P = [(-0.17, -0.72), (0.17, -0.72), (0.17, 0.02), (0.52, 0.02), (0.0, 0.82), (-0.52, 0.02), (-0.17, 0.02)]
TRI = [(0, 1, 2), (0, 2, 6), (5, 6, 4), (6, 2, 4), (2, 3, 4)]
cx = sum(p[0] for p in P) / len(P); cy = sum(p[1] for p in P) / len(P)
def inset(p, k): return (cx + (p[0] - cx) * k, cy + (p[1] - cy) * k)
TOP = [inset(p, 0.80) for p in P]

def tris():
    """Triangles as ((x,y,z) * 3, normal-or-None for flat); bevelled sides are smooth-shaded."""
    out = []
    for a, b, c in TRI:
        out.append(([(*TOP[a], H), (*TOP[b], H), (*TOP[c], H)], (0, 0, 1)))
    n = len(P)
    for i in range(n):
        j = (i + 1) % n
        lo_a, lo_b = (*P[i], 0.0), (*P[j], 0.0)
        hi_a, hi_b = (*TOP[i], H), (*TOP[j], H)
        # the side faces slope inwards: normal from the edge and the slope
        ex, ey = P[j][0] - P[i][0], P[j][1] - P[i][1]
        L = math.hypot(ex, ey) or 1
        nx, ny = ey / L, -ex / L
        nz = 0.7
        m = math.sqrt(nx * nx + ny * ny + nz * nz)
        nrm = (nx / m * 0.714, ny / m * 0.714, nz / m * 0.9)
        out.append(([lo_a, lo_b, hi_b], nrm)); out.append(([lo_a, hi_b, hi_a], nrm))
    return out
MESH = tris()

LIGHT = np.array([-0.45, -0.55, 0.70]); LIGHT /= np.linalg.norm(LIGHT)
VIEW = np.array([0.0, -math.cos(EL), math.sin(EL)])   # towards the camera

def render(theta, size):
    s = size
    zbuf = np.full((s, s), -1e9); body = np.zeros((s, s)); spec = np.zeros((s, s)); alpha = np.zeros((s, s))
    ct, st = math.cos(theta), math.sin(theta)
    scale = s / 2.05
    for pts, nrm in MESH:
        sp, cam = [], []
        for x, y, z in pts:
            rx, ry = x * ct - y * st, x * st + y * ct
            sx = rx * scale + s / 2
            sy = s / 2 - (ry * math.sin(EL) + (z - H / 2) * math.cos(EL)) * scale * 0.95 - s * 0.02
            sp.append((sx, sy)); cam.append(-ry * math.cos(EL) + z * math.sin(EL))
        nx, ny, nz = nrm
        n = np.array([nx * ct - ny * st, nx * st + ny * ct, nz]); n /= np.linalg.norm(n)
        diff = max(0.0, float(n @ LIGHT))
        rr = 2 * float(n @ LIGHT) * n - LIGHT
        sh = 0.30 + 0.70 * diff
        sc = max(0.0, float(rr @ VIEW)) ** 18 * (0.9 if nrm == (0, 0, 1) else 0.5)
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
        body[miny:maxy + 1, minx:maxx + 1][win] = sh
        spec[miny:maxy + 1, minx:maxx + 1][win] = sc
        alpha[miny:maxy + 1, minx:maxx + 1][win] = 1
    return body, spec, alpha

def down(a, k): return a.reshape(CELL, k, CELL, k).mean(axis=(1, 3))

def main():
    big = CELL * SS
    sheet_b = np.zeros((SHEET, SHEET, 4), np.uint8); sheet_s = np.zeros((SHEET, SHEET, 4), np.uint8)
    for i in range(FRAMES):
        b, sp, a = render(math.radians(i * 360 / FRAMES), big)
        A = down(a, SS)
        B = down(b * a, SS) / np.maximum(A, 1e-6)
        S = down(sp * a, SS)
        r, c = divmod(i, COLS)
        y0, x0 = r * CELL, c * CELL
        g = np.clip(B * 255, 0, 255).astype(np.uint8)
        sheet_b[y0:y0 + CELL, x0:x0 + CELL, 0] = g; sheet_b[y0:y0 + CELL, x0:x0 + CELL, 1] = g; sheet_b[y0:y0 + CELL, x0:x0 + CELL, 2] = g
        sheet_b[y0:y0 + CELL, x0:x0 + CELL, 3] = np.clip(A * 255, 0, 255).astype(np.uint8)
        s8 = np.clip(S * 255, 0, 255).astype(np.uint8)
        for k in range(3): sheet_s[y0:y0 + CELL, x0:x0 + CELL, k] = s8
        sheet_s[y0:y0 + CELL, x0:x0 + CELL, 3] = np.clip(A * 255, 0, 255).astype(np.uint8)
    os.makedirs(OUT, exist_ok=True)
    for name, arr in (('Arrow3D.tga', sheet_b), ('Arrow3DSpec.tga', sheet_s)):
        write_tga(os.path.join(OUT, name), arr)

def write_tga(path, rgba):
    h, w, _ = rgba.shape
    hdr = bytearray(18); hdr[2] = 2; hdr[12:14] = w.to_bytes(2, 'little'); hdr[14:16] = h.to_bytes(2, 'little'); hdr[16] = 32; hdr[17] = 0x28  # top-left origin, 8 alpha bits
    bgra = rgba[:, :, [2, 1, 0, 3]]
    with open(path, 'wb') as f: f.write(bytes(hdr)); f.write(bgra.tobytes())

if __name__ == '__main__': main()
