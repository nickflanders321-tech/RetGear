#!/usr/bin/env python3
"""Creature silhouettes for NPC cards (Media/Arcade/Creatures.tga, a 4x4 sheet of 128px cells) and slot emblems for
item cards (Media/Arcade/Slots.tga, same layout). Everything is drawn here; shapes are generic, nothing is copied from
any existing artwork. The game tints them per card. Run: python3 tools/arcade/art_creatures.py [preview]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import art
from art import canvas, save

K = 4
N = 128 * K


class Shape:
    """a silhouette built from simple pieces, rounded off by blur+threshold so it reads as one organic outline"""
    def __init__(self):
        self.m = Image.new("L", (N, N), 0); self.c = Image.new("L", (N, N), 0)
        self.d = ImageDraw.Draw(self.m); self.k = ImageDraw.Draw(self.c)

    @staticmethod
    def _p(pts): return [(x * K, y * K) for x, y in pts]

    def poly(self, pts): self.d.polygon(self._p(pts), fill=255); return self
    def ell(self, cx, cy, rx, ry): self.d.ellipse([(cx - rx) * K, (cy - ry) * K, (cx + rx) * K, (cy + ry) * K], fill=255); return self
    def rect(self, x0, y0, x1, y1): self.d.rectangle([x0 * K, y0 * K, x1 * K, y1 * K], fill=255); return self
    def line(self, pts, w):
        p = self._p(pts); self.d.line(p, fill=255, width=int(w * K), joint="curve")
        for x, y in (p[0], p[-1]): self.d.ellipse([x - w * K / 2, y - w * K / 2, x + w * K / 2, y + w * K / 2], fill=255)
        return self
    def cpoly(self, pts): self.k.polygon(self._p(pts), fill=255); return self
    def cell(self, cx, cy, rx, ry): self.k.ellipse([(cx - rx) * K, (cy - ry) * K, (cx + rx) * K, (cy + ry) * K], fill=255); return self
    def cline(self, pts, w): self.k.line(self._p(pts), fill=255, width=int(w * K)); return self

    def limb(self, a, b, r0, r1):
        """a tapered capsule from a (radius r0) to b (radius r1)"""
        (x0, y0), (x1, y1) = a, b
        dx, dy = x1 - x0, y1 - y0; L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L, dx / L
        self.poly([(x0 + nx * r0, y0 + ny * r0), (x1 + nx * r1, y1 + ny * r1), (x1 - nx * r1, y1 - ny * r1), (x0 - nx * r0, y0 - ny * r0)])
        self.ell(x0, y0, r0, r0).ell(x1, y1, r1, r1)
        return self

    def spline(self, pts, r0, r1, steps=14):
        """a smooth tapering tube through pts (Catmull-Rom)"""
        P = [pts[0]] + list(pts) + [pts[-1]]; out = []
        for i in range(1, len(P) - 2):
            p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
            for t in range(steps):
                u = t / steps
                out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * u + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * u * u + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * u ** 3) for j in (0, 1)))
        out.append(pts[-1])
        for i in range(len(out) - 1):
            r_a = r0 + (r1 - r0) * i / (len(out) - 1); r_b = r0 + (r1 - r0) * (i + 1) / (len(out) - 1)
            self.limb(out[i], out[i + 1], r_a, r_b)
        return self

    def build(self, smooth=1.6):
        m = self.m.filter(ImageFilter.GaussianBlur(smooth * K)).point(lambda v: 255 if v > 118 else 0)
        a = np.asarray(m).astype(np.uint8).copy()
        a[np.asarray(self.c) > 0] = 0
        im = np.zeros((N, N, 4), np.uint8); im[..., :3] = 255; im[..., 3] = a
        return Image.fromarray(im, "RGBA").resize((128, 128), Image.LANCZOS)


# ---------------------------------------------------------------- creatures (facing right, standing on y=124)
def wolf():
    s = Shape()
    s.ell(58, 70, 30, 15).ell(36, 72, 14, 14).ell(80, 66, 14, 15)                       # body, haunch, chest
    s.spline([(84, 58), (92, 50), (100, 50)], 9, 8)                                       # neck
    s.poly([(94, 44), (118, 56), (122, 62), (108, 64), (96, 62)]).poly([(94, 46), (96, 32), (103, 44)]).poly([(102, 46), (108, 33), (110, 46)])
    s.limb((82, 78), (90, 102), 6, 3.5).limb((90, 102), (88, 122), 3.5, 3)               # fore legs
    s.limb((74, 82), (68, 104), 5.5, 3.5).limb((68, 104), (70, 122), 3.5, 3)
    s.limb((38, 78), (30, 100), 8, 4).limb((30, 100), (38, 112), 4, 3).limb((38, 112), (36, 123), 3, 3.5)  # hind leg bent
    s.limb((46, 82), (46, 110), 6, 3.5).limb((46, 110), (48, 122), 3.5, 3)
    s.spline([(26, 64), (14, 62), (8, 50), (6, 38)], 6, 2)                               # brushy tail
    s.cell(105, 55, 1.8, 1.4)
    return s.build()


def spider():
    s = Shape()
    s.ell(64, 88, 17, 20).ell(64, 62, 12, 11)
    for k in range(4):
        for sg in (1, -1):
            s.spline([(64 + sg * 8, 60 + k * 3), (64 + sg * (16 + 9 * k), 26 + 7 * k), (64 + sg * (30 + 10 * k), 50 + 9 * k), (64 + sg * (32 + 10.5 * k), 122)], 3.2, 1.3, 8)
    s.cell(60, 58, 1.6, 1.6).cell(68, 58, 1.6, 1.6).cell(57, 63, 1.2, 1.2).cell(71, 63, 1.2, 1.2)
    s.cpoly([(64, 80), (60, 94), (64, 102), (68, 94)])
    return s.build(0.9)


def dragon():
    s = Shape()
    s.ell(52, 78, 26, 14).ell(36, 80, 14, 13)
    s.spline([(68, 72), (82, 60), (88, 46), (98, 38)], 10, 5)
    s.poly([(92, 32), (120, 36), (124, 44), (108, 48), (96, 46)]).poly([(94, 32), (88, 16), (100, 30)]).poly([(102, 32), (102, 16), (110, 32)])
    s.poly([(56, 66), (44, 30), (24, 2), (30, 30), (10, 30), (26, 46), (12, 60), (36, 62), (46, 78)])
    s.line([(56, 66), (24, 2)], 3).line([(56, 66), (10, 30)], 3).line([(56, 68), (12, 60)], 3)
    s.spline([(30, 84), (14, 98), (10, 112), (24, 120)], 7, 1.5)
    s.limb((64, 86), (66, 106), 7, 4).limb((66, 106), (72, 122), 4, 4)
    s.limb((38, 90), (30, 108), 8, 4).limb((30, 108), (38, 122), 4, 4)
    s.cell(109, 40, 1.8, 1.5)
    return s.build(1.2)


def wyrm():
    s = Shape()
    s.spline([(8, 118), (30, 112), (44, 96), (30, 80), (44, 62), (70, 58), (82, 42), (90, 30)], 3, 12, 14)
    s.poly([(84, 28), (112, 30), (122, 38), (108, 42), (88, 40)]).poly([(86, 28), (80, 12), (94, 26)]).poly([(94, 28), (98, 10), (104, 28)])
    for (x, y) in ((40, 90), (40, 70), (56, 60), (74, 52), (82, 40)): s.poly([(x - 4, y - 7), (x, y - 17), (x + 4, y - 8)])
    s.cell(104, 33, 1.8, 1.5)
    return s.build(1.1)


def demon():
    s = Shape()
    s.poly([(46, 50), (82, 50), (76, 90), (52, 90)]).ell(64, 38, 12, 12)
    s.spline([(54, 30), (44, 18), (46, 6)], 5, 2, 6).spline([(74, 30), (84, 18), (82, 6)], 5, 2, 6)
    s.poly([(46, 54), (4, 22), (14, 44), (4, 64), (22, 62), (14, 80), (46, 84)]).poly([(82, 54), (124, 22), (114, 44), (124, 64), (106, 62), (114, 80), (82, 84)])
    s.limb((52, 88), (46, 106), 8, 5).limb((46, 106), (50, 122), 5, 4).limb((76, 88), (82, 106), 8, 5).limb((82, 106), (78, 122), 5, 4)
    s.limb((48, 54), (36, 72), 6, 4).limb((36, 72), (32, 54), 4, 3).limb((80, 54), (92, 72), 6, 4).limb((92, 72), (96, 54), 4, 3)
    s.cell(60, 37, 2, 1.4).cell(68, 37, 2, 1.4)
    return s.build()


def demonlord():
    s = Shape()
    s.poly([(42, 50), (78, 50), (74, 94), (46, 94)]).ell(60, 38, 12, 12)
    s.spline([(50, 30), (38, 18), (44, 4)], 5, 2, 6).spline([(70, 30), (82, 18), (76, 4)], 5, 2, 6)
    s.limb((48, 94), (44, 110), 8, 5).limb((44, 110), (48, 123), 5, 4).limb((72, 94), (76, 110), 8, 5).limb((76, 110), (72, 123), 5, 4)
    s.limb((76, 56), (94, 50), 6, 4).limb((94, 50), (104, 38), 4, 3).line([(104, 6), (104, 124)], 3)
    s.poly([(96, 14), (104, 4), (112, 14), (110, 18), (104, 12), (98, 18)])
    s.limb((46, 56), (34, 74), 6, 4).limb((34, 74), (40, 90), 4, 3)
    s.poly([(42, 54), (10, 90), (20, 70), (6, 56), (34, 60)])
    s.cell(56, 37, 2, 1.4).cell(64, 37, 2, 1.4)
    return s.build()


def flame():
    s = Shape()
    s.spline([(64, 124), (44, 100), (40, 72), (54, 48), (50, 22), (64, 4)], 24, 3, 12)
    s.spline([(64, 124), (86, 100), (90, 72), (78, 52), (86, 30), (80, 14)], 24, 3, 12)
    s.spline([(64, 124), (24, 96), (18, 70), (30, 58)], 14, 2, 10).spline([(64, 124), (106, 96), (112, 70), (100, 52)], 14, 2, 10)
    s.ell(64, 96, 28, 26)
    s.cell(53, 84, 4.5, 6).cell(75, 84, 4.5, 6)
    return s.build(1.0)


def rockling():
    s = Shape()
    s.poly([(34, 56), (92, 52), (100, 100), (84, 124), (44, 124), (30, 98)]).poly([(46, 24), (78, 22), (84, 52), (40, 54)])
    s.poly([(28, 60), (6, 84), (14, 116), (32, 100)]).poly([(98, 60), (122, 80), (116, 116), (96, 100)])
    s.cpoly([(50, 36), (60, 34), (60, 40), (50, 42)]).cpoly([(68, 34), (78, 36), (78, 42), (68, 40)])
    s.cline([(50, 70), (70, 80), (60, 100)], 2).cline([(76, 66), (84, 90)], 2)
    return s.build(1.0)


def giant():
    s = Shape()
    s.poly([(34, 40), (92, 40), (100, 98), (28, 98)]).ell(62, 28, 14, 14)
    s.line([(36, 52), (18, 80), (22, 100)], 15).line([(90, 50), (110, 40), (118, 10)], 15)
    s.line([(114, 6), (120, 24)], 14).ell(116, 14, 11, 14)
    s.line([(46, 98), (44, 124)], 17).line([(80, 98), (82, 124)], 17)
    s.cell(58, 27, 2, 1.4).cell(67, 27, 2, 1.4)
    return s.build()


def brute():
    s = Shape()
    s.poly([(30, 44), (96, 44), (92, 100), (34, 100)]).ell(64, 32, 13, 13)
    s.line([(34, 54), (24, 82), (36, 96)], 15).line([(92, 54), (104, 30), (92, 8)], 15)
    s.poly([(70, 4), (116, 4), (122, 20), (90, 28), (66, 18)])
    s.line([(46, 100), (44, 124)], 16).line([(80, 100), (82, 124)], 16)
    s.cell(60, 31, 2, 1.4).cell(68, 31, 2, 1.4)
    return s.build()


def skeleton():
    s = Shape()
    s.ell(60, 24, 13, 13).rect(52, 30, 68, 40)
    s.line([(60, 38), (60, 90)], 6)
    for y in (48, 58, 68): s.line([(40, y - 2), (60, y), (80, y - 2)], 4)
    s.line([(48, 92), (72, 92)], 9).line([(52, 92), (50, 124)], 6).line([(70, 92), (72, 124)], 6)
    s.line([(40, 46), (28, 66), (32, 84)], 5).line([(82, 46), (100, 56), (108, 40)], 5)
    s.line([(108, 6), (108, 70)], 4).poly([(100, 66), (116, 66), (108, 74)])
    s.cell(55, 24, 3, 3.5).cell(65, 24, 3, 3.5).cpoly([(60, 28), (58, 33), (62, 33)])
    for x in (52, 56, 60, 64, 68): s.cline([(x, 34), (x, 38)], 1.2)
    return s.build(1.1)


def wraith():
    s = Shape()
    s.poly([(60, 6), (82, 22), (88, 56), (104, 100), (86, 92), (80, 118), (68, 100), (56, 122), (46, 98), (30, 112), (34, 70), (40, 24)])
    s.line([(86, 56), (106, 64), (114, 52)], 6).line([(36, 66), (18, 72), (10, 62)], 6)
    s.cpoly([(50, 26), (70, 26), (66, 44), (54, 44)])
    s.ell(56, 34, 0.01, 0.01)
    s2 = s.build(1.4)
    d = ImageDraw.Draw(s2)
    return s2


def warrior():
    s = Shape()
    s.poly([(46, 44), (80, 44), (76, 90), (50, 90)]).ell(63, 31, 11, 12).poly([(50, 22), (76, 22), (63, 8)])
    s.line([(50, 90), (47, 124)], 11).line([(76, 90), (79, 124)], 11)
    s.line([(46, 52), (36, 74)], 8).line([(80, 52), (100, 44)], 8)
    s.line([(100, 44), (110, 14)], 4).poly([(106, 20), (114, 20), (110, 4)]).rect(96, 42, 106, 46)
    s.poly([(18, 50), (42, 50), (42, 80), (30, 94), (18, 80)])
    s.cpoly([(30, 58), (36, 62), (30, 86), (24, 62)])
    s.cpoly([(58, 28), (68, 28), (68, 33), (58, 33)])
    return s.build(1.2)


def mage():
    s = Shape()
    s.poly([(44, 44), (80, 44), (92, 120), (32, 120)]).ell(62, 30, 11, 12).poly([(48, 26), (62, 4), (80, 26)])
    s.line([(44, 50), (30, 68)], 8).line([(80, 50), (96, 40)], 8)
    s.line([(100, 14), (100, 122)], 4).ell(100, 12, 8, 8)
    s.cell(100, 12, 3.5, 3.5).cpoly([(52, 34), (72, 34), (70, 40), (54, 40)])
    return s.build(1.2)


def golem():
    s = Shape()
    s.rect(38, 44, 90, 94).rect(46, 14, 82, 44).rect(16, 48, 36, 62).rect(92, 48, 112, 62)
    s.rect(18, 60, 30, 100).rect(98, 60, 110, 100).rect(42, 94, 58, 124).rect(70, 94, 86, 124)
    s.ell(64, 70, 22, 22).rect(62, 6, 66, 14)
    s.cell(64, 70, 10, 10).cell(56, 28, 4, 3).cell(72, 28, 4, 3)
    for a in range(0, 360, 45):
        r = math.radians(a); s.cell(64 + 16 * math.cos(r), 70 + 16 * math.sin(r), 2.6, 2.6)
    return s.build(0.6)


def horror():
    s = Shape()
    s.ell(64, 46, 30, 26)
    for i, a in enumerate((200, 230, 260, 290, 320, 340)):
        r = math.radians(a)
        x0, y0 = 64 + 22 * math.cos(r) * -1, 62
        s.line([(64 + (i - 2.5) * 10, 66), (64 + (i - 2.5) * 20 + (6 if i % 2 else -6), 96), (64 + (i - 2.5) * 22, 120)], 6)
    s.cell(64, 46, 20, 16).ell(64, 46, 8, 14)
    s.poly([(30, 30), (20, 10), (40, 24)]).poly([(98, 30), (108, 10), (88, 24)])
    return s.build(1.0)


CREATURES = (wolf, spider, dragon, wyrm, demon, demonlord, flame, rockling, giant, brute, skeleton, wraith, warrior, mage, golem, horror)


# ---------------------------------------------------------------- item slot emblems (shown faintly behind the icon)
def s_helm():
    s = Shape()
    s.poly([(30, 100), (30, 52), (44, 26), (64, 18), (84, 26), (98, 52), (98, 100), (84, 104), (80, 84), (48, 84), (44, 104)])
    s.poly([(60, 8), (68, 8), (70, 30), (58, 30)])
    s.cpoly([(42, 56), (86, 56), (86, 68), (72, 72), (72, 82), (56, 82), (56, 72), (42, 68)])
    return s.build(1.0)


def s_shoulder():
    s = Shape()
    s.poly([(10, 96), (14, 56), (34, 30), (64, 22), (94, 30), (114, 56), (118, 96), (96, 88), (64, 82), (32, 88)])
    for x in (30, 64, 98): s.poly([(x - 6, 30), (x, 8), (x + 6, 30)])
    s.cline([(24, 70), (64, 60), (104, 70)], 3)
    return s.build(1.0)


def s_chest():
    s = Shape()
    s.poly([(36, 18), (54, 26), (74, 26), (92, 18), (112, 34), (104, 56), (92, 54), (94, 112), (34, 112), (36, 54), (24, 56), (16, 34)])
    s.cpoly([(54, 26), (74, 26), (64, 44)]).cline([(64, 46), (64, 108)], 2.5).cline([(40, 74), (88, 74)], 2.5).cline([(40, 92), (88, 92)], 2.5)
    return s.build(0.9)


def s_gloves():
    s = Shape()
    s.poly([(34, 112), (28, 66), (42, 62), (44, 40), (54, 38), (56, 56), (60, 28), (70, 28), (70, 54), (76, 34), (86, 36), (82, 62), (92, 46), (100, 52), (92, 88), (94, 112)])
    s.rect(30, 96, 98, 116)
    s.cline([(30, 98), (98, 98)], 2.5)
    return s.build(1.0)


def s_boots():
    s = Shape()
    s.poly([(38, 12), (74, 12), (76, 80), (112, 92), (118, 112), (34, 112)])
    s.cpoly([(34, 100), (118, 100), (118, 104), (34, 104)]).cline([(38, 30), (74, 30)], 2.5)
    return s.build(1.0)


def s_belt():
    s = Shape()
    s.rect(6, 44, 122, 84)
    s.cpoly([(52, 52), (76, 52), (76, 76), (52, 76)]).cline([(8, 64), (46, 64)], 2).cline([(82, 64), (120, 64)], 2)
    s.rect(54, 54, 74, 74)
    s.cell(64, 64, 4, 4)
    return s.build(0.8)


def s_legs():
    s = Shape()
    s.poly([(30, 14), (98, 14), (104, 60), (84, 118), (68, 118), (64, 54), (60, 118), (44, 118), (24, 60)])
    s.cline([(30, 26), (98, 26)], 3).cline([(34, 62), (56, 62)], 2).cline([(72, 62), (94, 62)], 2)
    return s.build(0.9)


def s_bracers():
    s = Shape()
    s.poly([(34, 12), (94, 12), (100, 112), (28, 112)])
    s.cpoly([(46, 30), (82, 30), (82, 40), (46, 40)]).cpoly([(46, 52), (82, 52), (82, 62), (46, 62)]).cpoly([(46, 74), (82, 74), (82, 84), (46, 84)])
    return s.build(0.9)


def s_ring():
    s = Shape()
    s.ell(64, 74, 38, 38).ell(64, 28, 14, 14)
    s.cell(64, 78, 26, 26).cell(64, 28, 7, 7)
    return s.build(1.0)


def s_amulet():
    s = Shape()
    s.spline([(24, 6), (34, 50), (64, 70), (94, 50), (104, 6)], 3, 3, 10)
    s.poly([(64, 66), (88, 86), (64, 120), (40, 86)]).cpoly([(64, 80), (76, 90), (64, 108), (52, 90)])
    return s.build(0.9)


def s_cloak():
    s = Shape()
    s.poly([(30, 10), (98, 10), (118, 118), (84, 106), (64, 120), (44, 106), (10, 118)])
    s.cline([(64, 16), (64, 108)], 2).cline([(44, 18), (30, 100)], 2).cline([(84, 18), (98, 100)], 2)
    s.rect(54, 4, 74, 14).ell(64, 14, 8, 6)
    return s.build(1.0)


def s_sword():
    s = Shape()
    s.poly([(60, 4), (68, 4), (72, 84), (56, 84)]).rect(38, 84, 90, 94).rect(60, 94, 68, 112).ell(64, 116, 8, 7)
    s.cline([(64, 12), (64, 80)], 2)
    return s.build(0.8)


def s_staff():
    s = Shape()
    s.rect(60, 36, 68, 124).ell(64, 22, 16, 16)
    s.poly([(44, 12), (50, 28), (40, 30)]).poly([(84, 12), (78, 28), (88, 30)])
    s.cell(64, 22, 7, 7)
    return s.build(0.9)


def s_bow():
    s = Shape()
    s.spline([(40, 6), (92, 36), (96, 64), (92, 92), (40, 122)], 4, 4, 10)
    s.rect(38, 8, 41, 120).line([(20, 64), (100, 64)], 2.5).poly([(100, 64), (88, 58), (88, 70)])
    return s.build(0.8)


def s_shield():
    s = Shape()
    s.poly([(16, 14), (112, 14), (112, 66), (96, 98), (64, 120), (32, 98), (16, 66)])
    s.cpoly([(30, 28), (98, 28), (98, 62), (86, 86), (64, 102), (42, 86), (30, 62)])
    s.rect(58, 36, 70, 92).rect(40, 52, 88, 62)
    return s.build(0.9)


def s_trinket():
    s = Shape()
    s.ell(64, 70, 36, 36).rect(54, 14, 74, 30).ell(64, 12, 8, 8)
    s.cell(64, 70, 26, 26)
    s.ell(64, 70, 14, 14).poly([(64, 48), (70, 64), (86, 70), (70, 76), (64, 92), (58, 76), (42, 70), (58, 64)])
    return s.build(0.9)


SLOTS = (s_helm, s_shoulder, s_chest, s_gloves, s_boots, s_belt, s_legs, s_bracers, s_ring, s_amulet, s_cloak, s_sword, s_staff, s_bow, s_shield, s_trinket)


def sheet(fns):
    sh = canvas(512, 512)
    for i, fn in enumerate(fns): sh.alpha_composite(fn(), ((i % 4) * 128, (i // 4) * 128))
    return sh


def main():
    save("Creatures", sheet(CREATURES), 512, 512)
    save("Slots", sheet(SLOTS), 512, 512)


if __name__ == "__main__":
    main()
