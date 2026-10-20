"""Shrinks the big painted card textures: colours are rounded to 32 steps per channel (invisible at card size, but the files
compress to about a third of the size). Run after regenerating any of these with the art scripts: python3 tools/arcade/shrink_media.py"""
from PIL import Image
FILES = ["Media/Arcade/Places%d.tga" % i for i in range(1, 5)] + ["Media/Arcade/Back%s.tga" % s for s in ("", "2", "3", "4", "5")] + \
        ["Media/Arcade/Board.tga", "Media/Arcade/Body.tga", "Media/Arcade/PackBody.tga", "Media/Arcade/Night.tga", "Media/Arcade/Seals.tga"]
for f in FILES:
    r, g, b, a = Image.open(f).convert("RGBA").split()
    Image.merge("RGBA", [c.point(lambda v: min(255, (v // 8) * 8 + 4)) for c in (r, g, b)] + [a]).save(f)
    print("shrunk", f)
