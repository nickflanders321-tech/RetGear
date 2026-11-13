"""The Field Guide for the card game -> ArcadeField.lua.

  python3 tools/arcade/field.py <classic.sql> <forever_gear.json> <qdb dir> <npcs.tsv> <addon dir>

Every rare and rare elite out in the world (not in a dungeon), by zone, with where it spawns, and the world bosses.
  - A rare that already is a card (ArcadeCards.lua) stays that card: its Field Guide page lists it too.
  - A rare that isn't a card yet gets one here. These new cards come only from the world (killing the rare), never
    from a pack, and can't be traded.
  - Each world boss gets a "Witness" card, earned by being in the fight when it dies.
Rarity: a rare is Renowned, a rare elite Epic; one that has a single spawn point is a step rarer. Witness cards are
Legendary. New cards go after every other card, so existing card numbers never move.
"""
import json, os, re, sys, collections

sql_path, json_path, qdb, npcs_tsv, addon = sys.argv[1:6]
if not qdb.endswith('/'): qdb += '/'
here = os.path.dirname(os.path.abspath(__file__))

# the SQL reader from gen.py (same parser)
src = open(os.path.join(here, 'gen.py'), encoding='utf-8').read()
head = src[:src.index("cards, seen = [], set()")]
saved = sys.argv
sys.argv = ['gen.py', sql_path, qdb, addon]
ns = {}
exec(head, ns)
sys.argv = saved
rows, clean, ok = ns['rows'], ns['clean'], ns['ok']

TYPE = {1: "beast", 2: "dragonkin", 3: "demon", 4: "elemental", 5: "giant", 6: "undead", 7: "humanoid", 8: "critter", 9: "mechanical"}
ctype, cdisp = {}, {}
for e, ct, m in rows('creature_template', ['Entry', 'CreatureType', 'ModelId1']):
    ctype[int(e)] = int(ct or 0); cdisp[int(e)] = int(m or 0)

fv = json.load(open(json_path))
FN = {int(k): v for k, v in fv["npcs"].items() if isinstance(v, dict)}

# zone names: the same tables the gear guide uses
gsrc = open(os.path.join(here, '..', 'gear', 'gen.py'), encoding='utf-8').read()
AREA = eval(re.search(r'^AREA = (\{.*?\})\n', gsrc, re.S | re.M).group(1))
NEW_AREA = {16593: "Zephras Isle", 616: "Mount Hyjal", 16651: "Shen'dralas", 16591: "Riverglades"}
UI = {int(a): int(b) for a, b in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', open(qdb + "support/Forever/Zones/areaIdToUiMapId.lua", encoding="utf-8").read())}
try:
    PARENT = {int(a): int(b) for a, b in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', open(qdb + "support/Forever/Zones/subZoneToParentZone.lua", encoding="utf-8").read())}
except OSError:
    PARENT = {}
DUNZ = set()
for m in re.finditer(r'\[(\d+)\] = \{"([^"]+)",(?:\{([\d,]*)\}|nil)', open(qdb + "support/Forever/Zones/dungeons.lua", encoding="utf-8").read()):
    DUNZ.add(int(m.group(1)))
    for a in (m.group(3) or "").split(","):
        if a: DUNZ.add(int(a))
CITIES = {1519, 1537, 1657, 1497, 1637, 1638}
def zone_of(z):
    z = PARENT.get(z, z)
    return z, (AREA.get(z) or NEW_AREA.get(z))

# spawn points: "zone:x,y;x,y|zone:x,y"
spawns = {}
for line in open(npcs_tsv, encoding="utf-8"):
    p = line.rstrip("\n").split("\t")
    if len(p) < 6 or not p[5]: continue
    pts = []
    for part in p[5].split("|"):
        if ":" not in part: continue
        z, coords = part.split(":", 1)
        for xy in coords.split(";"):
            if "," in xy:
                x, y = xy.split(",")
                try: pts.append((int(z), float(x), float(y)))
                except ValueError: pass
    if pts: spawns[int(p[0])] = pts

# cards that exist already (and their display ids)
existing = {}
for f in ("ArcadeCards.lua", "ArcadeDungeons.lua"):
    path = os.path.join(addon, f)
    if not os.path.exists(path): continue
    for kind, name in re.findall(r'^\s*\{ (\d), "((?:[^"\\]|\\.)*)", \d, -?\d+, "(?:[^"\\]|\\.)*" \},', open(path, encoding="utf-8").read(), re.M):
        existing[name.replace('\\"', '"').lower()] = name.replace('\\"', '"')

# the world bosses that walk the open world (not the faction leaders in their cities)
WORLD = ["Azuregos", "Lord Kazzak", "Ysondre", "Lethon", "Emeriss", "Taerar", "Teremus the Devourer", "Twilight Corrupter",
         "Prince Skaldrenox", "High Marshal Whirlaxis", "Baron Kazum", "Lord Skwol"]

out_rows, pages, npc_map, displays, creatures = [], collections.OrderedDict(), {}, {}, {}
seen_new = set()
def add_row(kind, name, tier, ref, text):
    if name.lower() in seen_new: return
    seen_new.add(name.lower()); out_rows.append((kind, name, tier, ref, text))

rares = []
for nid, n in FN.items():
    if (n.get("rank") or 0) not in (2, 4) or nid not in spawns: continue
    nm = clean(n.get("name") or "")
    if not ok(nm): continue
    z0 = spawns[nid][0][0]
    if z0 in DUNZ or z0 in CITIES or (n.get("zone") in DUNZ): continue
    z, zn = zone_of(z0)
    if not zn: continue
    rares.append((zn, nm, nid, n))
rares.sort(key=lambda r: (r[0], -(r[3].get("maxLevel") or 0), r[1]))
for zn, nm, nid, n in rares:
    pg = "Field Guide: " + zn
    pages.setdefault(pg, {"zone": zn, "cards": []})
    if nm.lower() in existing:
        card = existing[nm.lower()]
    else:
        card = nm
        elite = n.get("rank") == 2
        tier = 4 if elite else 3
        pts = {(round(x), round(y)) for _, x, y in spawns[nid]}
        if len(pts) <= 1: tier += 1   # (one spot to find it in)
        ty = TYPE.get(ctype.get(nid, 7), "humanoid")
        add_row(2, nm, tier, ctype.get(nid, 7), "%s, level %d %s" % ("Rare elite" if elite else "Rare", n.get("maxLevel") or 0, ty))
        if cdisp.get(nid): displays[nm] = cdisp[nid]
        elif nm not in displays: creatures[nm] = nid
    if card not in pages[pg]["cards"]: pages[pg]["cards"].append(card)
    z, x, y = spawns[nid][0]
    npc_map[nid] = (card, pg, UI.get(PARENT.get(z, z)) or UI.get(z) or 0, x, y, "r")

wpage = "Field Guide: World bosses"
for wname in WORLD:
    ids = [nid for nid, n in FN.items() if clean(n.get("name") or "") == wname and (n.get("rank") or 0) == 3 and nid in spawns]
    if not ids: print("no spawn for world boss", wname, file=sys.stderr); continue
    card = "Witness: " + wname
    pages.setdefault(wpage, {"zone": "World bosses", "cards": []})
    lvl = max(FN[i].get("maxLevel") or 0 for i in ids)
    lvl = 63 if lvl > 63 else lvl
    add_row(2, card, 5, ctype.get(ids[0], 2), "World boss, witnessed, level %d %s" % (lvl, TYPE.get(ctype.get(ids[0], 2), "dragonkin")))
    pages[wpage]["cards"].append(card)
    for nid in ids:
        z, x, y = spawns[nid][0]
        npc_map[nid] = (card, wpage, UI.get(PARENT.get(z, z)) or UI.get(z) or 0, x, y, "w")
        if cdisp.get(nid): displays.setdefault(card, cdisp[nid])
    if card not in displays: creatures[card] = ids[0]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
L = ["-- GENERATED by tools/arcade/field.py: do not edit by hand.",
     "-- The Field Guide: every rare and rare elite out in the world, by zone, and the world bosses' Witness cards.",
     "-- New cards go after every other card ({ kind, name, tier, ref, text } like ArcadeCards.lua), so existing card numbers",
     "-- never move. They come only from the world (never from packs) and can't be traded.",
     "local _, RG = ...",
     "RG.ARCADE_DATA = RG.ARCADE_DATA or {}",
     "RG.ARCADE_FIELD_ROWS = {"]
for kind, name, tier, ref, text in out_rows:
    L.append("  { %d, %s, %d, %d, %s }," % (kind, q(name), tier, ref, q(text)))
L.append("}")
L.append("-- { set name, zone, { card names } }: one page per zone, then the world bosses")
L.append("RG.ARCADE_FIELD_PAGES = {")
order = sorted((p for p in pages if p != wpage)) + ([wpage] if wpage in pages else [])
for p in order:
    L.append("  { %s, %s, { %s } }," % (q(p), q(pages[p]["zone"]), ", ".join(q(c) for c in pages[p]["cards"])))
L.append("}")
L.append("-- [creature id] = { card, page, map, x, y, \"r\" rare or \"w\" world boss }: where it spawns (its first spawn point)")
L.append("RG.ARCADE_FIELD_NPC = {")
for nid in sorted(npc_map):
    c, p, m, x, y, k = npc_map[nid]
    L.append("  [%d] = { %s, %s, %d, %.1f, %.1f, %s }," % (nid, q(c), q(p), m, x, y, q(k)))
L.append("}")
L.append("-- models (from the player's own game files) for the new cards")
L.append("RG.ARCADE_FIELD_DISPLAY = {")
for nm in sorted(displays): L.append("  [%s] = %d," % (q(nm), displays[nm]))
L.append("}")
L.append("RG.ARCADE_FIELD_CREATURE = {")
for nm in sorted(creatures):
    if nm not in displays: L.append("  [%s] = %d," % (q(nm), creatures[nm]))
L.append("}")
L += ["-- join the card list: each new card after every other card, marked with its page (so it's never in a pack) and as",
      "-- a world-only card (r[7]: can't be traded)",
      "local owner = {}",
      "RG.ARCADE_FIELD_OF = owner   -- every card on a Field Guide page -> that page",
      "for _, p in ipairs(RG.ARCADE_FIELD_PAGES) do for _, n in ipairs(p[3]) do owner[n] = owner[n] or p[1] end end",
      "for _, r in ipairs(RG.ARCADE_FIELD_ROWS) do r[6] = owner[r[2]]; r[7] = true; RG.ARCADE_DATA[#RG.ARCADE_DATA + 1] = r end",
      "RG.ARCADE_NPC = RG.ARCADE_NPC or {}",
      "for k, v in pairs(RG.ARCADE_FIELD_DISPLAY) do if not RG.ARCADE_NPC[k] then RG.ARCADE_NPC[k] = v end end",
      "RG.ARCADE_DUNGEON_CREATURE = RG.ARCADE_DUNGEON_CREATURE or {}",
      "for k, v in pairs(RG.ARCADE_FIELD_CREATURE) do if not RG.ARCADE_DUNGEON_CREATURE[k] then RG.ARCADE_DUNGEON_CREATURE[k] = v end end"]
open(os.path.join(addon, "ArcadeField.lua"), "w", encoding="utf-8").write("\n".join(L) + "\n")
print("field guide: %d new cards, %d pages, %d creatures" % (len(out_rows), len(pages), len(npc_map)), file=sys.stderr)
