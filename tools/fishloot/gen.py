#!/usr/bin/env python3
"""Build FishLoot.lua: everything you can fish up, and where.

  RG.FISH_LOOT.zones[zone name] = { { itemID, chance % }, ... }   what a cast in that zone can bring up
  RG.FISH_LOOT.pools            = { { name, items = { {itemID, chance %}, ... }, spots = { {uiMapID, x, y, label}, ... } }, ... }
                                  fishing pools / wreckage / traps (classic DB loot, plus Forever's own pools)
  RG.FISH_LOOT.contents[itemID] = { { itemID, chance % }, ... }   what the chests, crates, trunks, clams and bottles hold
  RG.FISH_LOOT.info[itemID]     = { name, kind, quality }        kind: fish, material, container, gear, junk, misc

Inputs: the cMaNGOS classic DB (fishing, pool, container loot), QuestieDB's merged Forever data
(pool spawns, Forever-only pools and item names; see tools/fishloot/dump.lua) and Fish.lua's zone table.

Usage:
  lua5.1 tools/fishloot/dump.lua $C /tmp/fl_obj.tsv /tmp/fl_items.tsv
  python3 tools/fishloot/gen.py /tmp/classic.sql /tmp/qdb /tmp/fl_obj.tsv /tmp/fl_items.tsv .
"""
import math, os, re, sys
from collections import defaultdict

sql_path, qdb, objs_tsv, items_tsv, addon = sys.argv[1:6]
qdb = qdb.rstrip('/') + '/'
sql = open(sql_path, encoding="utf-8", errors="replace").read()

def columns(table):
    m = re.search(r"CREATE TABLE `%s` \((.*?)\) ENGINE" % table, sql, re.S)
    return re.findall(r"^\s*`(\w+)`", m.group(1), re.M)
def rows(table):
    cols = columns(table)
    out = []
    for m in re.finditer(r"INSERT INTO `%s` VALUES " % table, sql):
        i, n = m.end(), len(sql)
        while i < n and sql[i] == '(':
            i += 1
            row, cur, inq = [], [], False
            while True:
                c = sql[i]
                if inq:
                    if c == '\\': cur.append(sql[i + 1]); i += 2; continue
                    if c == "'":
                        if sql[i + 1] == "'": cur.append("'"); i += 2; continue
                        inq = False; i += 1; continue
                    cur.append(c); i += 1; continue
                if c == "'": inq = True; i += 1; continue
                if c == ',': row.append(''.join(cur)); cur = []; i += 1; continue
                if c == ')': row.append(''.join(cur)); i += 1; break
                cur.append(c); i += 1
            out.append(dict(zip(cols, row)))
            if sql[i] == ',': i += 1
            else: break
    return out

items = {int(r["entry"]): r for r in rows("item_template")}
floot, rloot, gloot, iloot = rows("fishing_loot_template"), rows("reference_loot_template"), rows("gameobject_loot_template"), rows("item_loot_template")
gobj = {int(r["entry"]): r for r in rows("gameobject_template")}
del sql

FOREVER_NAMES, FOREVER_OBJ_DROPS = {}, defaultdict(list)
for line in open(items_tsv, encoding="utf-8"):
    iid, nm, objs = line.rstrip("\n").split("\t")
    FOREVER_NAMES[int(iid)] = nm
    for o in objs.split(","):
        if o: FOREVER_OBJ_DROPS[int(o)].append(int(iid))

# --------------------------------------------------------------------------- loot rolling
def tables(rowlist):
    d = defaultdict(list)
    for r in rowlist: d[int(r["entry"])].append(r)
    return d
refs = tables(rloot)

def roll(rowlist, mult=1.0, depth=0, out=None):
    """Chance (0-1) of each item from a loot table: independent rows, groups (explicit chances, the
    rest share what is left) and reference tables."""
    out = defaultdict(float) if out is None else out
    groups = defaultdict(list)
    for r in rowlist:
        g = int(r["groupid"])
        if g == 0: groups[("solo", id(r))].append(r)
        else: groups[g].append(r)
    for key, rs in groups.items():
        if isinstance(key, tuple):
            r = rs[0]; ch = abs(float(r["ChanceOrQuestChance"])) / 100.0 or 1.0
            picks = [(r, ch)]
        else:
            explicit = sum(abs(float(r["ChanceOrQuestChance"])) for r in rs if float(r["ChanceOrQuestChance"]) != 0)
            zeros = [r for r in rs if float(r["ChanceOrQuestChance"]) == 0]
            share = max(0.0, 100.0 - explicit) / len(zeros) if zeros else 0
            picks = [(r, (abs(float(r["ChanceOrQuestChance"])) if float(r["ChanceOrQuestChance"]) != 0 else share) / 100.0) for r in rs]
        for r, p in picks:
            mc = int(r["mincountOrRef"])
            if mc < 0:
                if depth < 3: roll(refs.get(-mc, []), mult * p, depth + 1, out)
            else:
                iid = int(r["item"])
                out[iid] = 1 - (1 - out[iid]) * (1 - mult * p)     # same item from two rows
    return out

# --------------------------------------------------------------------------- zones
ui = {int(a): int(b) for a, b in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', open(qdb + 'support/Forever/Zones/areaIdToUiMapId.lua').read())}
AREA = {1: "Dun Morogh", 3: "Badlands", 4: "Blasted Lands", 8: "Swamp of Sorrows", 10: "Duskwood", 11: "Wetlands", 12: "Elwynn Forest",
  14: "Durotar", 15: "Dustwallow Marsh", 16: "Azshara", 17: "The Barrens", 28: "Western Plaguelands", 33: "Stranglethorn Vale",
  36: "Alterac Mountains", 38: "Loch Modan", 40: "Westfall", 41: "Deadwind Pass", 44: "Redridge Mountains", 45: "Arathi Highlands",
  46: "Burning Steppes", 47: "The Hinterlands", 51: "Searing Gorge", 85: "Tirisfal Glades", 130: "Silverpine Forest",
  139: "Eastern Plaguelands", 141: "Teldrassil", 148: "Darkshore", 215: "Mulgore", 267: "Hillsbrad Foothills", 331: "Ashenvale",
  357: "Feralas", 361: "Felwood", 400: "Thousand Needles", 405: "Desolace", 406: "Stonetalon Mountains", 440: "Tanaris",
  490: "Un'Goro Crater", 493: "Moonglade", 618: "Winterspring", 1377: "Silithus", 1497: "Undercity", 1519: "Stormwind City",
  1537: "Ironforge", 1637: "Orgrimmar", 1638: "Thunder Bluff", 1657: "Darnassus"}
for m in re.finditer(r'^\s*([A-Z_0-9]+)\s*=\s*(\d+),', open(qdb + 'src/corrections/enum/zones.lua').read(), re.M):
    a = int(m.group(2))
    if a not in AREA and a in ui: AREA[a] = m.group(1).replace("_", " ").title().replace("'S", "'s")
DUNGEON_AREAS = set()
for m in re.finditer(r'\[(\d+)\] = \{"([^"]+)",(?:\{([\d,]*)\}|nil)', open(qdb + "support/Forever/Zones/dungeons.lua", encoding="utf-8").read()):
    DUNGEON_AREAS.add(int(m.group(1)))
    for a in (m.group(3) or "").split(","):
        if a: DUNGEON_AREAS.add(int(a))
# zones the add-on knows a fishing skill for (Fish.lua), so the list matches what the Fishing tab says
fish_src = open(os.path.join(addon, "Fish.lua"), encoding="utf-8").read()
KNOWN = set(re.findall(r'\["([^"]+)"\] = \d+', fish_src.split("RG.FISH_ZONES = {")[1].split("\n}\n")[0]))

by_area = tables(floot)
zones = {}
used = set()
for a, rs in by_area.items():
    if a == 0 or a not in AREA or a in DUNGEON_AREAS: continue
    nm = AREA[a]
    pr = roll(rs)
    lst = sorted(((i, p * 100) for i, p in pr.items() if p >= 0.0005), key=lambda t: -t[1])
    if lst: zones[nm] = lst; used.update(i for i, _ in lst)

# --------------------------------------------------------------------------- pools
POOL_RE = re.compile(r"School|Wreckage|Floating Debris|Shipwreck Debris|Oil Spill|Elemental Water|Eel Swarm|Fishing Location|Fishing Trap|Steam Pump Flotsam|Pure Water|Muddy Churning")
def centre(pts):
    best, bc = None, -1
    for p in pts:
        c = sum(1 for q in pts if (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 <= 64)
        if c > bc: best, bc = p, c
    return best, bc
spawns = {}
oname = {}
for line in open(objs_tsv, encoding="utf-8"):
    oid, nm, sp = line.rstrip("\n").split("\t")
    oid = int(oid); oname[oid] = nm
    d = {}
    for part in (sp.split("|") if sp else []):
        z, pts = part.split(":")
        d[int(z)] = [tuple(map(float, p.split(","))) for p in pts.split(";") if p]
    spawns[oid] = d
gl = tables(gloot)
cand = {}
for oid, g in gobj.items():                       # classic fishing holes: loot id in data1
    if int(g["type"]) == 25: cand[oid] = g["name"]
for oid, nm in oname.items():                     # Forever's own pools and traps
    if oid not in cand and POOL_RE.search(nm) and oid in FOREVER_OBJ_DROPS: cand[oid] = nm
pool_items = {}
for oid, nm in cand.items():
    if oid in gobj and int(gobj[oid]["type"]) == 25:
        pr = roll(gl.get(int(gobj[oid]["data1"] or 0), []))
        lst = sorted(((i, p * 100) for i, p in pr.items() if p >= 0.005), key=lambda t: -t[1])
    else:
        lst = [(i, 100.0) for i in FOREVER_OBJ_DROPS[oid]]
    if lst: pool_items[oid] = (nm, lst)
groupd = defaultdict(list)                        # (name, items) -> object ids
for oid, (nm, lst) in pool_items.items():
    groupd[(nm, tuple((i, round(p, 1)) for i, p in lst))].append(oid)
pools = []
for (nm, lst), oids in groupd.items():
    perzone = defaultdict(list)
    for oid in oids:
        for z, pts in spawns.get(oid, {}).items():
            if z in ui and z not in DUNGEON_AREAS: perzone[z].extend(pts)
    spots = []
    for z, pts in perzone.items():
        p, c = centre(pts)
        spots.append((len(pts), ui[z], p, "%s: %d spot%s (nearest cluster)" % (AREA.get(z, "?"), len(pts), "" if len(pts) == 1 else "s")))
    spots.sort(key=lambda s: -s[0])
    if not spots: continue                        # no known position: nothing useful to show
    pools.append({"name": nm, "items": list(lst), "spots": spots[:6]})
    used.update(i for i, _ in lst)
pools.sort(key=lambda p: (p["name"], -len(p["spots"])))

# --------------------------------------------------------------------------- containers
by_item_loot = tables(iloot)
contents = {}
for iid in sorted(used):
    if iid in by_item_loot:
        pr = roll(by_item_loot[iid])
        lst = sorted(((i, p * 100) for i, p in pr.items() if p >= 0.005), key=lambda t: -t[1])
        if lst: contents[iid] = lst

FISH_RE = re.compile(r"Fish|Snapper|Catfish|Mackerel|Albacore|Cod\b|Trout|Yellowtail|Squid|Bass|Salmon|Lobster|Mightfish|Redgill|Blackmouth|Eel|Sunfish|Crushfish|Angelfish|Queenfish|Racer|Striker|Mahi|Ahi\b|Sailfin|Frenzy|Grouper", re.I)
for lst in contents.values(): used.update(i for i, _ in lst)       # names for what the containers hold
def kind_of(iid):
    it = items.get(iid)
    if iid in contents: return "container"
    if not it: return "material"
    cl, q = int(it["class"]), int(it["Quality"])
    if FISH_RE.search(it["name"]) or FISH_RE.search(FOREVER_NAMES.get(iid, "")): return "fish"
    if cl in (2, 4): return "gear"
    if q == 0: return "junk"
    if cl in (15, 0): return "misc"
    return "material"
INFO = {}
for iid in sorted(used):
    it = items.get(iid)
    nm = FOREVER_NAMES.get(iid) or (it["name"] if it else "Item %d" % iid)
    INFO[iid] = (nm, kind_of(iid), int(it["Quality"]) if it else 1)

# --------------------------------------------------------------------------- write
def lua_str(s): return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'
def pct(p): return ("%.1f" % p).rstrip("0").rstrip(".") if p >= 0.1 else "%.2f" % p
def lst_s(lst): return "{ " + ", ".join("{ %d, %s }" % (i, pct(p)) for i, p in lst) + " }"
L = ["-- GENERATED by tools/fishloot/gen.py: do not edit by hand.",
     "-- Everything fishing can bring up, per zone and per pool, and what the chests, crates and clams hold.",
     "-- Sources: cMaNGOS classic DB (fishing, pool and container loot) and QuestieDB's merged WoW Forever data",
     "-- (pool positions, Forever-only pools, item names). Chances are percent per catch; Forever's own",
     "-- tuning is not published, so treat them as a guide.",
     "local _, RG = ...", "RG.FISH_LOOT = {", "  zones = {"]
for z in sorted(zones): L.append("    [%s] = %s," % (lua_str(z), lst_s(zones[z])))
L.append("  },"); L.append("  pools = {")
for p in pools:
    L.append("    { name = %s, items = %s, spots = { %s } }," % (lua_str(p["name"]), lst_s(p["items"]),
        ", ".join("{ %d, %.1f, %.1f, %s }" % (s[1], s[2][0], s[2][1], lua_str(s[3])) for s in p["spots"])))
L.append("  },"); L.append("  contents = {")
for c in sorted(contents): L.append("    [%d] = %s," % (c, lst_s(contents[c])))
L.append("  },"); L.append("  info = {")
for i in sorted(INFO): L.append("    [%d] = { %s, %s, %d }," % (i, lua_str(INFO[i][0]), lua_str(INFO[i][1]), INFO[i][2]))
L.append("  },"); L.append("}")
open(os.path.join(addon, "FishLoot.lua"), "w", encoding="utf-8").write("\n".join(L) + "\n")
print("zones %d, pools %d, containers %d, items %d (missing zone skill: %s)" % (len(zones), len(pools), len(contents), len(INFO),
      ", ".join(sorted(z for z in zones if z not in KNOWN))), file=sys.stderr)
