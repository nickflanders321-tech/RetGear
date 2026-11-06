#!/usr/bin/env python3
"""Draw Waypath+'s small UI icons (Media/Icons/*.tga): white line glyphs on transparent, 64x64,
tinted in game (brass when on, parchment-grey when off). Drawn 4x larger and scaled down, so they
stay sharp at 14-22 px instead of being blurry shrunken game icons.
Run: python3 tools/media/icons.py"""
import math, os
from PIL import Image, ImageDraw
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'Media', 'Icons')
N, K = 64, 4
S = N * K
W = 18   # stroke width at 4x

def new():
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0)); return im, ImageDraw.Draw(im)
def line(d, pts, w=W): d.line(pts, fill=(255, 255, 255, 255), width=w, joint='curve')
def ring(d, cx, cy, r, w=W): d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, 255), width=w)
def dot(d, cx, cy, r): d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, 255))
def poly(d, pts): d.polygon(pts, fill=(255, 255, 255, 255))
def save(im, name):
    im = im.resize((N, N), Image.LANCZOS)
    a = im.tobytes()
    hdr = bytearray(18); hdr[2] = 2; hdr[12:14] = N.to_bytes(2, 'little'); hdr[14:16] = N.to_bytes(2, 'little'); hdr[16] = 32; hdr[17] = 0x28
    px = bytearray()
    for i in range(0, len(a), 4): px += bytes((a[i + 2], a[i + 1], a[i], a[i + 3]))
    with open(os.path.join(OUT, name + '.tga'), 'wb') as f: f.write(bytes(hdr)); f.write(bytes(px))
    im.save(os.path.join('/tmp', name + '.png'))

c = S / 2
def journey():   # compass: a ring and a needle, the north half solid
    im, d = new(); ring(d, c, c, 104)
    poly(d, [(c + 50, c - 50), (c + 16, c + 4), (c - 4, c - 16)])
    line(d, [(c - 50, c + 50), (c + 16, c + 4), (c - 4, c - 16), (c - 50, c + 50)], 10)
    save(im, 'Journey')
def gear():      # shield
    im, d = new()
    pts = [(c, 28), (c + 92, 62), (c + 92, 130), (c + 60, 196), (c, 232), (c - 60, 196), (c - 92, 130), (c - 92, 62), (c, 28)]
    line(d, pts); line(d, [(c, 70), (c, 196)], 14); line(d, [(c - 52, 118), (c + 52, 118)], 14)
    save(im, 'Gear')
def economy():   # two coins
    im, d = new()
    d.ellipse((24, 70, 168, 214), outline=(255, 255, 255, 255), width=W)
    d.ellipse((92, 34, 236, 178), fill=(0, 0, 0, 0))
    m = Image.new('L', (S, S), 0); ImageDraw.Draw(m).ellipse((82, 24, 246, 188), fill=255)
    im.putalpha(Image.fromarray(__import__('numpy').minimum(__import__('numpy').asarray(im.getchannel('A')), 255 - __import__('numpy').asarray(m))))
    d = ImageDraw.Draw(im)
    d.ellipse((92, 34, 236, 178), outline=(255, 255, 255, 255), width=W)
    line(d, [(164, 76), (164, 136)], 14)
    save(im, 'Economy')
def cards():      # a card in front of another
    import numpy as np
    back = Image.new('RGBA', (S, S), (0, 0, 0, 0)); db = ImageDraw.Draw(back)
    db.rounded_rectangle((112, 40, 210, 196), 16, outline=(255, 255, 255, 255), width=W)
    back = back.rotate(-16, resample=Image.BICUBIC, center=(160, 120))
    m = Image.new('L', (S, S), 0); ImageDraw.Draw(m).rounded_rectangle((36, 62, 146, 228), 18, fill=255)
    a = np.minimum(np.asarray(back.getchannel('A')), 255 - np.asarray(m)); back.putalpha(Image.fromarray(a))
    d = ImageDraw.Draw(back); d.rounded_rectangle((46, 72, 136, 218), 14, outline=(255, 255, 255, 255), width=W)
    dot(d, 91, 145, 14)
    save(back, 'Cards')
def settings():  # cog
    im, d = new()
    for k in range(8):
        a = k * math.pi / 4
        x, y = c + math.cos(a) * 92, c + math.sin(a) * 92
        d.ellipse((x - 22, y - 22, x + 22, y + 22), fill=(255, 255, 255, 255))
    dot(d, c, c, 84); d.ellipse((c - 34, c - 34, c + 34, c + 34), fill=(0, 0, 0, 0))
    save(im, 'Settings')
def arrow():
    im, d = new(); poly(d, [(c, 26), (c + 76, 222), (c, 178), (c - 76, 222)]); save(im, 'Arrow')
def tracker():   # a list
    im, d = new()
    for y in (70, 128, 186):
        dot(d, 58, y, 14); line(d, [(92, y), (206, y)])
    save(im, 'Tracker')
def sound():
    im, d = new(); poly(d, [(48, 100), (92, 100), (140, 52), (140, 204), (92, 156), (48, 156)])
    d.arc((120, 70, 200, 186), -55, 55, fill=(255, 255, 255, 255), width=W - 4)
    d.arc((120, 34, 236, 222), -50, 50, fill=(255, 255, 255, 255), width=W - 4)
    save(im, 'Sound')
def report():    # a note with a corner fold
    im, d = new(); line(d, [(64, 34), (156, 34), (196, 74), (196, 222), (64, 222), (64, 34)])
    line(d, [(156, 34), (156, 74), (196, 74)], 12)
    for y in (110, 148, 186): line(d, [(94, y), (166, y)], 12)
    save(im, 'Report')
def chevron(name, left):
    im, d = new()
    if left: line(d, [(156, 56), (88, c), (156, 200)], 22)
    else: line(d, [(100, 56), (168, c), (100, 200)], 22)
    save(im, name)
def bell():
    im, d = new()
    d.chord((c - 74, 44, c + 74, 210), 180, 360, outline=(255, 255, 255, 255), width=W)
    line(d, [(c - 74, 127), (c - 74, 176), (c - 96, 192), (c + 96, 192), (c + 74, 176), (c + 74, 127)])
    dot(d, c, 218, 18)
    save(im, 'Bell')

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    journey(); gear(); economy(); cards(); settings(); arrow(); tracker(); sound(); report(); bell()
    chevron('FoldLeft', True); chevron('FoldRight', False)
    print('ok')
