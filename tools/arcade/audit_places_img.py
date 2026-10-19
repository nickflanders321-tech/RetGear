"""Every place card's painting cell must hold a real picture (not blank or flat). Run: python3 tools/arcade/audit_places_img.py"""
import re, sys
from PIL import Image, ImageStat
atlas = {i: Image.open(f"Media/Arcade/Places{i}.tga").convert("RGB") for i in range(1, 5)}
bad = 0
for name, a, cell in re.findall(r'\["(.+?)"\] = \{ (\d+), (\d+) \}', open("ArcadePlaces.lua", encoding="utf8").read()):
    a, cell = int(a), int(cell)
    x, y = (cell % 8) * 120, (cell // 8) * 84
    sd = max(ImageStat.Stat(atlas[a].crop((x, y, x + 120, y + 84))).stddev)
    if sd < 8:
        print("PROBLEM: blank or flat painting:", name, f"(atlas {a}, cell {cell}, detail {sd:.1f})"); bad += 1
print("Place paintings checked;", bad, "problem(s)")
sys.exit(1 if bad else 0)
