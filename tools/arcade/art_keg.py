#!/usr/bin/env python3
"""The dungeon pack's powder keg (Waypath+ 1.45), all drawn here:
  PackKeg     the keg, standing where the pack stands (256x512; on screen 160x320): bellied oak staves lit like a
              cylinder, four iron hoops with rivets, a lid with a brass bung for the fuse, a brass name plate
              (the game writes the dungeon's name on it), a Waypath compass burnt into the wood, a worn painted flame
  PackKegHot  the keg's seams, hoops and lid rim alone, white, for the heat that leaks out before it blows (drawn ADD)
  FuseBit     one bead of braided fuse (ArcadePackFx.lua lays the fuse out of them, so it can burn back bead by bead)
  Flame       the flame on the fuse (32x64)
  Blast       the fireball (256x256, drawn ADD)
  Smoke       a puff of smoke (128x128, tinted in game)
  Stave       a broken stave flying off (32x128); HoopBit a bent piece of hoop (64x32)
Run: python3 tools/arcade/art_keg.py [preview]"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
import art
from art import S, canvas, noise, save

W, H = 256 * S, 512 * S
CX = W / 2
TOP, BOT = 118 * S, 490 * S          # the keg's lid and foot (texture pixels, supersampled)
HOOPS = (0.075, 0.27, 0.73, 0.925)   # where the hoops sit, top to bottom
BEND = 12 * S                        # how far a ring round the keg dips at the front (we look from a little above)
PLATE_Y = 300 * S                    # the name plate's middle (ArcadePackFx.lua writes the name here)


def half_w(y):
    """The keg's half-width at height y: a barrel's belly."""
    k = (y - TOP) / (BOT - TOP)
    return (94 + 20 * math.sin(math.pi * min(1, max(0, k)))) * S


def keg_masks():
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    k = np.clip((yy - TOP) / (BOT - TOP), 0, 1)
    hw = (94 + 20 * np.sin(np.pi * k)) * S
    u = (xx - CX) / hw
    uc = np.clip(u, -1, 1)
    inside = (np.abs(u) <= 1) & (yy >= TOP) & (yy <= BOT - BEND + BEND * np.sqrt(1 - uc * uc))
    return yy, xx, k, hw, uc, inside


def make_keg():
    yy, xx, k, hw, u, inside = keg_masks()
    th = np.arcsin(u)                                   # the angle round the keg
    nz = np.sqrt(np.clip(1 - u * u, 0, 1))
    # light from the upper left, a soft rim light on the right
    lam = np.clip(0.55 * nz - 0.45 * u + 0.25, 0, None)
    spec = np.exp(-((u + 0.42) / 0.11) ** 2) * 0.35
    rim = np.exp(-((u - 0.93) / 0.05) ** 2) * 0.18
    light = 0.28 + 0.9 * lam
    # staves: 11 round the front; each its own shade, grain running up the stave, dark seams between
    n = 11
    sidx = np.floor((th + math.pi / 2) / math.pi * n).astype(np.int32)
    sfrac = (th + math.pi / 2) / math.pi * n - sidx
    rs = np.random.RandomState(7)
    tone = rs.uniform(0.86, 1.1, n + 2)[np.clip(sidx, 0, n + 1)]
    gN = noise(W, H, 3, 11)
    gL = noise(W, H, 40, 12)
    grain = 0.5 + 0.5 * np.sin(sfrac * 26 + gN * 7 + yy * 0.004 + sidx * 3.1)
    grain = 0.82 + 0.13 * grain + 0.10 * (gL - 0.5)
    seam = np.clip(np.minimum(sfrac, 1 - sfrac) * n * 0.9 / (0.25 + 0.75 * nz), 0, 1) ** 0.55
    base = np.array([138, 88, 46], np.float32)
    wood = base[None, None, :] * (tone * grain * (0.35 + 0.65 * seam))[..., None]
    # soot and wear near the foot and round the bung
    soot = np.clip((k - 0.78) / 0.22, 0, 1) * 0.35 + np.exp(-(((xx - (CX + 32 * S)) / (40 * S)) ** 2 + ((yy - TOP) / (30 * S)) ** 2)) * 0.45
    wood *= (1 - soot * (0.6 + 0.4 * noise(W, H, 10, 13)))[..., None]
    col = wood * light[..., None] + (spec + rim)[..., None] * np.array([255, 214, 160], np.float32)
    # hoops: gunmetal bands, lit like the keg, a bright top edge, rust, rivets; a shadow under each on the wood
    hoopA = np.zeros((H, W), np.float32)
    for hk in HOOPS:
        hy = TOP + hk * (BOT - TOP)
        hy = hy - BEND + BEND * nz
        d = (yy - hy) / (8.5 * S)
        band = (np.abs(d) <= 1) & inside
        sh = np.clip(1 - (yy - hy - 8.5 * S) / (9 * S), 0, 1) * ((yy > hy + 8.5 * S)) * inside
        col *= (1 - 0.45 * sh)[..., None]
        edge = np.exp(-((d + 0.75) / 0.18) ** 2) * 0.9 - np.exp(-((d - 0.8) / 0.2) ** 2) * 0.4
        rust = noise(W, H, 7, int(hk * 100))
        m = np.array([92, 92, 100], np.float32)[None, None, :] * (light * (0.85 + 0.25 * edge))[..., None]
        m = m * (1 - 0.25 * rust[..., None]) + np.array([60, 28, 10], np.float32) * (0.35 * rust)[..., None]
        m += (spec * 1.4 + edge.clip(0) * 0.25 * nz)[..., None] * np.array([235, 235, 245], np.float32)
        col = np.where(band[..., None], m, col)
        hoopA = np.maximum(hoopA, band * np.exp(-((d + 0.95) / 0.12) ** 2))
    img = np.dstack([np.clip(col, 0, 255), np.where(inside, 255, 0)]).astype(np.uint8)
    out = Image.fromarray(img, "RGBA")
    d = ImageDraw.Draw(out)
    # rivets on the hoops
    for hk in HOOPS:
        hy = TOP + hk * (BOT - TOP)
        hwv = half_w(hy)
        for uu in (-0.78, -0.4, 0.0, 0.4, 0.78):
            x = CX + uu * hwv
            r = 3.2 * S * math.sqrt(1 - uu * uu) + S
            ry_ = hy - BEND + BEND * math.sqrt(1 - uu * uu)
            d.ellipse((x - r, ry_ - r, x + r, ry_ + r), fill=(48, 46, 50, 255))
            d.ellipse((x - r * 0.6 - S, ry_ - r * 0.6 - S, x + r * 0.2, ry_ + r * 0.2), fill=(190, 188, 196, 255))
    # the lid: the top of the keg seen from just above; a dark chime round it, boards across, a brass bung
    rx, ry = half_w(TOP) + 1 * S, 21 * S
    lid = Image.new("L", (W, H), 0); ImageDraw.Draw(lid).ellipse((CX - rx, TOP - ry, CX + rx, TOP + ry), fill=255)
    la = np.asarray(lid, np.float32) / 255
    boards = 0.8 + 0.12 * np.sin((yy - TOP) / (7 * S) * math.pi * 2 + noise(W, H, 4, 21) * 2) + 0.1 * noise(W, H, 30, 22)
    lidc = np.array([112, 74, 40], np.float32)[None, None, :] * boards[..., None] * (0.75 + 0.35 * (1 - (xx - CX + rx) / (2 * rx)))[..., None]
    o = np.asarray(out, np.float32)
    o[..., :3] = o[..., :3] * (1 - la[..., None]) + lidc * la[..., None]
    o[..., 3] = np.maximum(o[..., 3], la * 255)
    out = Image.fromarray(o.clip(0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(out)
    d.ellipse((CX - rx, TOP - ry, CX + rx, TOP + ry), outline=(40, 26, 14, 255), width=5 * S)
    d.ellipse((CX - rx + 6 * S, TOP - ry + 3 * S, CX + rx - 6 * S, TOP + ry - 3 * S), outline=(70, 46, 24, 255), width=S)
    bx, by = CX + 32 * S, TOP + 2 * S
    d.ellipse((bx - 11 * S, by - 6 * S, bx + 11 * S, by + 6 * S), fill=(150, 108, 46, 255), outline=(70, 44, 16, 255), width=S * 2)
    d.ellipse((bx - 6 * S, by - 3.5 * S, bx + 6 * S, by + 3.5 * S), fill=(30, 20, 10, 255))
    d.arc((bx - 11 * S, by - 6 * S, bx + 11 * S, by + 6 * S), 190, 300, fill=(240, 205, 130, 255), width=S)
    # the burnt-in compass between the top hoops
    cy = TOP + 0.17 * (BOT - TOP)
    brand = Image.new("L", (W, H), 0); db = ImageDraw.Draw(brand)
    R = 22 * S
    db.ellipse((CX - R, cy - R * 0.92, CX + R, cy + R * 0.92), outline=255, width=3 * S)
    for a in range(4):
        ang = a * math.pi / 2
        tip = (CX + math.cos(ang) * R * 0.95, cy + math.sin(ang) * R * 0.88)
        l = (CX + math.cos(ang + 0.6) * R * 0.25, cy + math.sin(ang + 0.6) * R * 0.25)
        r = (CX + math.cos(ang - 0.6) * R * 0.25, cy + math.sin(ang - 0.6) * R * 0.25)
        db.polygon([tip, l, (CX, cy), r], fill=255)
    brand = brand.filter(ImageFilter.GaussianBlur(1.2 * S))
    ba = np.asarray(brand, np.float32) / 255 * (0.75 + 0.25 * noise(W, H, 5, 31))
    o = np.asarray(out, np.float32)
    o[..., :3] = o[..., :3] * (1 - 0.72 * ba[..., None]) + np.array([30, 14, 6], np.float32) * (0.72 * ba)[..., None]
    out = Image.fromarray(o.clip(0, 255).astype(np.uint8), "RGBA")
    # a painted flame, worn, between the lower hoops
    fy = TOP + 0.83 * (BOT - TOP)
    paint = Image.new("L", (W, H), 0); dp = ImageDraw.Draw(paint)
    # a stencilled flame: a round base, a tall middle tongue, a short tongue each side (a smooth closed curve)
    ctrl = [(0, 1.0), (0.42, 0.9), (0.62, 0.6), (0.58, 0.25), (0.42, -0.25), (0.3, 0.12), (0.12, -0.35), (0.0, -1.0),
            (-0.14, -0.4), (-0.3, 0.05), (-0.44, -0.3), (-0.6, 0.2), (-0.62, 0.6), (-0.42, 0.9)]
    n = len(ctrl); pts = []
    for i in range(n):
        p0, p1, p2, p3 = ctrl[(i - 1) % n], ctrl[i], ctrl[(i + 1) % n], ctrl[(i + 2) % n]
        for j in range(12):
            u_ = j / 12
            x = 0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * u_ + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * u_ ** 2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * u_ ** 3)
            y = 0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * u_ + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * u_ ** 2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * u_ ** 3)
            pts.append((CX + x * 26 * S, fy + y * 27 * S))
    dp.polygon(pts, fill=255)
    wear = np.clip((noise(W, H, 6, 41) - 0.18) * 4, 0, 1)
    pa = np.asarray(paint.filter(ImageFilter.GaussianBlur(0.7 * S)), np.float32) / 255 * wear * 0.8
    o = np.asarray(out, np.float32)
    o[..., :3] = o[..., :3] * (1 - pa[..., None]) + np.array([170, 40, 24], np.float32) * (pa * (0.5 + 0.5 * np.clip(0.55 * nz - 0.45 * u + 0.4, 0, 1)))[..., None] / np.maximum(pa, 1e-3)[..., None] * pa[..., None]
    out = Image.fromarray(o.clip(0, 255).astype(np.uint8), "RGBA")
    # the brass name plate, nailed on, curving with the keg
    d = ImageDraw.Draw(out)
    pw, ph = 80 * S, 25 * S
    plate = Image.new("L", (W, H), 0); ImageDraw.Draw(plate).rounded_rectangle((CX - pw, PLATE_Y - ph, CX + pw, PLATE_Y + ph), 5 * S, fill=255)
    pl = np.asarray(plate, np.float32) / 255
    brass = np.array([196, 150, 72], np.float32)[None, None, :] * (0.45 + 0.75 * np.clip(0.55 * nz - 0.45 * u + 0.25, 0, None))[..., None]
    brass += (np.exp(-((u + 0.38) / 0.09) ** 2) * 0.5)[..., None] * np.array([255, 236, 190], np.float32)
    brass *= (0.92 + 0.12 * noise(W, H, 6, 51))[..., None]
    o = np.asarray(out, np.float32)
    o[..., :3] = o[..., :3] * (1 - pl[..., None]) + brass * pl[..., None]
    sh = np.asarray(plate.filter(ImageFilter.GaussianBlur(3 * S)), np.float32) / 255
    sh = np.roll(np.roll(sh, 3 * S, 0), 2 * S, 1) * (1 - pl)
    o[..., :3] *= (1 - 0.5 * sh[..., None])
    out = Image.fromarray(o.clip(0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(out)
    d.rounded_rectangle((CX - pw, PLATE_Y - ph, CX + pw, PLATE_Y + ph), 5 * S, outline=(86, 58, 22, 255), width=2 * S)
    d.rounded_rectangle((CX - pw + 6 * S, PLATE_Y - ph + 5 * S, CX + pw - 6 * S, PLATE_Y + ph - 5 * S), 3 * S, outline=(120, 84, 34, 255), width=S)
    d.rounded_rectangle((CX - pw + 8 * S, PLATE_Y - ph + 7 * S, CX + pw - 8 * S, PLATE_Y + ph - 7 * S), 3 * S, fill=(44, 28, 12, 235))
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = CX + sx * (pw - 4 * S), PLATE_Y + sy * (ph - 4 * S)
            d.ellipse((x - 2.5 * S, y - 2.5 * S, x + 2.5 * S, y + 2.5 * S), fill=(110, 80, 36, 255))
            d.ellipse((x - 1.5 * S, y - 1.5 * S, x + 0.5 * S, y + 0.5 * S), fill=(250, 226, 160, 255))
    return out


def make_hot():
    """Where the heat shows: the seams between staves, the hoops' edges and the lid's rim, white on black-alpha."""
    yy, xx, k, hw, u, inside = keg_masks()
    th = np.arcsin(u); nz = np.sqrt(np.clip(1 - u * u, 0, 1))
    n = 11
    f = (th + math.pi / 2) / math.pi * n
    fr = f - np.floor(f)
    seam = np.exp(-((np.minimum(fr, 1 - fr)) * n / (0.35 + 0.65 * nz) / 0.22) ** 2) * inside
    cracks = (noise(W, H, 9, 61) > 0.62) * seam
    hoop = np.zeros((H, W), np.float32)
    for hk in HOOPS:
        hy = TOP + hk * (BOT - TOP)
        d = np.abs(np.abs(yy - (hy - BEND + BEND * nz)) - 8.5 * S)
        hoop = np.maximum(hoop, np.exp(-(d / (1.6 * S)) ** 2) * inside)
    yl = TOP
    rx, ry = half_w(TOP), 21 * S
    e = np.abs(np.sqrt(((xx - CX) / rx) ** 2 + ((yy - yl) / ry) ** 2) - 1)
    rimh = np.exp(-(e / 0.06) ** 2)
    a = np.clip(seam * 0.55 + cracks * 0.6 + hoop * 0.9 + rimh, 0, 1)
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2 * S)), np.float32) / 255
    a = np.clip(a * 1.7, 0, 1)
    img = np.dstack([np.full((H, W), 255.0), np.full((H, W), 255.0), np.full((H, W), 255.0), a * 255]).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def make_fusebit(s=16):
    z = s * S * 2
    out = canvas(z, z); d = ImageDraw.Draw(out)
    c = z / 2
    d.ellipse((c - z * 0.42, c - z * 0.42, c + z * 0.42, c + z * 0.42), fill=(196, 170, 120, 255), outline=(96, 78, 46, 255), width=S * 2)
    for i in range(-2, 3):
        d.line((c - z * 0.35 + i * z * 0.16, c + z * 0.35, c + z * 0.05 + i * z * 0.16, c - z * 0.35), fill=(130, 108, 70, 255), width=S * 2)
    d.ellipse((c - z * 0.3, c - z * 0.32, c - z * 0.02, c - z * 0.08), fill=(236, 220, 180, 160))
    m = Image.new("L", (z, z), 0); ImageDraw.Draw(m).ellipse((c - z * 0.42, c - z * 0.42, c + z * 0.42, c + z * 0.42), fill=255)
    out.putalpha(m)
    return out


def radial(w, h, cx, cy):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return np.sqrt(((xx - cx) / (w / 2)) ** 2 + ((yy - cy) / (h / 2)) ** 2), np.arctan2(yy - cy, xx - cx)


def make_flame():
    w, h = 32 * S * 2, 64 * S * 2
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    x = (xx - w / 2) / (w / 2); y = (yy - h * 0.72) / (h * 0.62)
    width = np.where(y < 0, 0.62 * np.clip(1 + y, 0, None) ** 0.8, 0.62 * np.sqrt(np.clip(1 - (y / 0.42) ** 2, 0, 1)))
    r = np.abs(x) / np.maximum(width, 1e-3)
    a = np.nan_to_num(np.clip(1 - r, 0, 1) ** 0.7 * (y > -1))
    core = np.clip(1 - r * 1.6, 0, 1) * np.clip(1 + y * 1.4, 0, 1)
    col = np.dstack([np.full_like(a, 255), 150 + 105 * core, 40 + 200 * core ** 2])
    return Image.fromarray(np.dstack([col, a * 255]).clip(0, 255).astype(np.uint8), "RGBA")


def make_blast(size=256):
    z = size * S
    r, ang = radial(z, z, z / 2, z / 2)
    turb = np.zeros_like(r)
    rs = np.random.RandomState(5)
    for f, g in ((5, 0.5), (11, 0.3), (23, 0.2)):
        ph = rs.uniform(0, 6.28, 3)
        turb += g * (np.sin(ang * f + ph[0]) * 0.5 + np.sin(ang * (f + 2) + ph[1] + r * 7) * 0.5)
    n = noise(z, z, 6, 71)
    edge = 0.78 + 0.13 * turb + 0.12 * (n - 0.5)
    a = np.clip(1 - r / edge, 0, 1)
    body = a ** 0.6
    core = np.clip(1 - r / (0.38 + 0.08 * turb), 0, 1) ** 0.8
    lumps = 0.75 + 0.35 * noise(z, z, 4, 72)
    R = 255 * np.clip(body * 1.3, 0, 1)
    G = 255 * np.clip(body * body * (0.28 + 0.3 * lumps) + core * 0.75, 0, 1)
    B = 255 * np.clip(core ** 2 * 0.9, 0, 1)
    A = 255 * np.clip(body * 1.3, 0, 1)
    return Image.fromarray(np.dstack([R, G, B, A]).astype(np.uint8), "RGBA")


def make_smoke(size=128):
    z = size * S
    out = np.zeros((z, z), np.float32)
    rs = np.random.RandomState(3)
    yy, xx = np.mgrid[0:z, 0:z].astype(np.float32)
    for _ in range(9):
        cx, cy = z / 2 + rs.uniform(-0.18, 0.18) * z, z / 2 + rs.uniform(-0.16, 0.16) * z
        rr = rs.uniform(0.16, 0.26) * z
        out = np.maximum(out, np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (rr * rr)) * 1.4))
    out *= 0.65 + 0.45 * noise(z, z, 5, 81)
    shade = 0.75 + 0.25 * np.clip(1 - (yy / z), 0, 1)
    a = np.clip(out * 1.15, 0, 1)
    g = 200 * shade
    return Image.fromarray(np.dstack([g, g, g * 0.98, a * 235]).astype(np.uint8), "RGBA")


def make_stave():
    w, h = 32 * S, 128 * S
    out = canvas(w, h)
    rs = np.random.RandomState(9)
    left = [(w * 0.15 + math.sin(i / 10 * math.pi) * w * 0.12, h * 0.08 + i / 10 * h * 0.84) for i in range(11)]
    right = [(x + w * 0.62, y) for x, y in left]
    top = [(left[0][0] + (right[0][0] - left[0][0]) * t, h * 0.08 + rs.uniform(-0.06, 0.04) * h) for t in (0.33, 0.66)]
    bot = [(right[-1][0] + (left[-1][0] - right[-1][0]) * t, h * 0.92 + rs.uniform(-0.05, 0.06) * h) for t in (0.3, 0.7)]
    poly = left[::-1][-1:] + top + right + bot + left[::-1]
    m = Image.new("L", (w, h), 0); ImageDraw.Draw(m).polygon(poly, fill=255)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    g = 0.75 + 0.2 * np.sin(xx * 0.9 + noise(w, h, 4, 91) * 6) + 0.1 * noise(w, h, 2, 92)
    shade = 0.7 + 0.5 * (1 - xx / w)
    col = np.dstack([138 * g * shade, 88 * g * shade, 46 * g * shade, np.full((h, w), 255.0)])
    out.paste(Image.fromarray(col.clip(0, 255).astype(np.uint8), "RGBA"), (0, 0), m)
    d = ImageDraw.Draw(out)
    d.rectangle((0, h * 0.42, w, h * 0.5), fill=(84, 84, 92, 255))
    d.line((0, h * 0.42, w, h * 0.42), fill=(190, 190, 200, 255), width=S)
    out.putalpha(Image.fromarray(np.minimum(np.asarray(out.getchannel("A")), np.asarray(m))))
    return out


def make_hoopbit():
    w, h = 64 * S, 32 * S
    out = canvas(w, h); d = ImageDraw.Draw(out)
    d.arc((-w * 0.2, h * 0.15, w * 1.2, h * 2.2), 200, 340, fill=(96, 96, 104, 255), width=7 * S)
    d.arc((-w * 0.2, h * 0.15, w * 1.2, h * 2.2), 205, 335, fill=(200, 200, 210, 255), width=S * 2)
    for x in (0.3, 0.7):
        d.ellipse((w * x - 3 * S, h * 0.3 - 3 * S, w * x + 3 * S, h * 0.3 + 3 * S), fill=(50, 48, 52, 255))
    return out


def preview_sheet():
    """A strip of how the pack looks in game: the keg, hot, and the burst."""
    keg = make_keg(); hot = make_hot()
    sheet = Image.new("RGBA", (W * 3, H), (34, 24, 16, 255))
    sheet.alpha_composite(keg, (0, 0))
    k2 = keg.copy(); h2 = np.asarray(hot, np.float32)
    o = np.asarray(k2, np.float32)
    o[..., 0] = np.clip(o[..., 0] + h2[..., 3] * 1.0, 0, 255); o[..., 1] = np.clip(o[..., 1] + h2[..., 3] * 0.45, 0, 255); o[..., 2] = np.clip(o[..., 2] + h2[..., 3] * 0.1, 0, 255)
    sheet.alpha_composite(Image.fromarray(o.astype(np.uint8), "RGBA"), (W, 0))
    b = make_blast().resize((W, W))
    sheet.alpha_composite(b, (W * 2, H // 2 - W // 2))
    sheet.save("/tmp/arcade_preview/keg_sheet.png")


def main():
    save("PackKeg", make_keg(), 256, 512)
    save("PackKegHot", make_hot(), 256, 512)
    save("FuseBit", make_fusebit(), 16, 16)
    save("Flame", make_flame(), 32, 64)
    save("Blast", make_blast(), 256, 256)
    save("Smoke", make_smoke(), 128, 128)
    save("Stave", make_stave(), 32, 128)
    save("HoopBit", make_hoopbit(), 64, 32)
    if art.PREVIEW: preview_sheet()


if __name__ == "__main__":
    main()
