#!/usr/bin/env python3
"""Build Professions/Generated.lua: the data the Professions tab uses to count materials
and to send you somewhere (double-click a place and the arrow takes you there).

  RG.RECIPES[craft name]  = { s = spell, i = item made, y = how many per craft, r = { {itemID, count}, ... } }
                            for every craft in Professions/*.lua plans, plus the recipes for crafted
                            reagents (bars, bolts, elixirs, ...)
  RG.MAT_INFO[itemID]     = { name, kind, made-by recipe? }   kind: vendor, herb, ore, stone, gem, cloth,
                            leather, meat, fish, elemental, enchant, crafted, drop
  RG.MAT_SPOTS[itemID]    = { {uiMapID, x, y, label, lvl, score}, ... }   mobs that drop it (Horde-safe,
                            not in dungeons, not elite), best first
  RG.MAT_VENDORS[itemID]  = { {uiMapID, x, y, label}, ... }   Horde vendors that sell it
  RG.MAT_NODES[itemID]    = { node name, ... }               herb or ore nodes it comes from
  RG.GATHER_SPOTS[node]   = { {uiMapID, x, y, label}, ... }   the densest clusters of that herb/vein
  RG.SKIN_SPOTS           = { {uiMapID, x, y, label, lvl}, ... }  skinnable beasts by level
  RG.FISH_SPOTS[uiMapID]  = { x, y, label }                  fishing pools, when the zone has them
  RG.PROF_TRAINERS[name]  = { uiMapID, x, y, label }        every trainer named in the plans
  RG.ZONE_MAPS[zone name] = uiMapID

Inputs: the cMaNGOS classic DB (recipes, loot tables, vendors), QuestieDB's merged Forever data
(NPC and object spawns in Forever's map coordinates, levels, factions) and NodeData.lua.

Usage:
  lua5.1 tools/waypoints/dump.lua $C/foreverNpcDB.lua /tmp/npcs.tsv
  lua5.1 tools/nodes/dump.lua $C/foreverObjectDB.lua /tmp/objects.tsv     (all objects)
  lua5.1 tools/profs/items_dump.lua $C /tmp/items.tsv
  python3 tools/profs/gen.py /tmp/classic.sql /tmp/forever_gear.json /tmp/qdb /tmp/npcs.tsv /tmp/objects.tsv . /tmp/items.tsv
"""
import json, math, os, re, sys, glob
from collections import defaultdict

sql_path, gear_json, qdb, npcs_tsv, objs_tsv, addon = sys.argv[1:7]
fitems_tsv = sys.argv[7] if len(sys.argv) > 7 else None   # Forever item names (tools/profs/items_dump.lua)
qdb = qdb.rstrip('/') + '/'

# ---------------------------------------------------------------------------
# SQL
# ---------------------------------------------------------------------------
print("reading SQL...", file=sys.stderr)
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
spells = rows("spell_template")
creatures = {int(r["Entry"]): r for r in rows("creature_template")}
cloot, rloot, sloot, vend = rows("creature_loot_template"), rows("reference_loot_template"), rows("skinning_loot_template"), rows("npc_vendor")
gobj = {int(r["entry"]): r for r in rows("gameobject_template")}
try: gloot = rows("gameobject_loot_template")
except Exception: gloot = []
try: floot = rows("fishing_loot_template")
except Exception: floot = []
del sql
print("items %d spells %d creatures %d" % (len(items), len(spells), len(creatures)), file=sys.stderr)

# ---------------------------------------------------------------------------
# Forever data (QuestieDB): NPC levels/factions, spawns, zones
# ---------------------------------------------------------------------------
FN = json.load(open(gear_json))["npcs"]
ui = {int(a): int(b) for a, b in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', open(qdb + 'support/Forever/Zones/areaIdToUiMapId.lua').read())}
DUNGEON_AREAS = set()
for m in re.finditer(r'\[(\d+)\] = \{"([^"]+)",(?:\{([\d,]*)\}|nil)', open(qdb + "support/Forever/Zones/dungeons.lua", encoding="utf-8").read()):
    DUNGEON_AREAS.add(int(m.group(1)))
    for a in (m.group(3) or "").split(","):
        if a: DUNGEON_AREAS.add(int(a))
AREA = {1: "Dun Morogh", 3: "Badlands", 4: "Blasted Lands", 8: "Swamp of Sorrows", 10: "Duskwood", 11: "Wetlands", 12: "Elwynn Forest",
  14: "Durotar", 15: "Dustwallow Marsh", 16: "Azshara", 17: "The Barrens", 28: "Western Plaguelands", 33: "Stranglethorn Vale",
  36: "Alterac Mountains", 38: "Loch Modan", 40: "Westfall", 41: "Deadwind Pass", 44: "Redridge Mountains", 45: "Arathi Highlands",
  46: "Burning Steppes", 47: "The Hinterlands", 51: "Searing Gorge", 85: "Tirisfal Glades", 130: "Silverpine Forest",
  139: "Eastern Plaguelands", 141: "Teldrassil", 148: "Darkshore", 215: "Mulgore", 267: "Hillsbrad Foothills", 331: "Ashenvale",
  357: "Feralas", 361: "Felwood", 400: "Thousand Needles", 405: "Desolace", 406: "Stonetalon Mountains", 440: "Tanaris",
  490: "Un'Goro Crater", 493: "Moonglade", 618: "Winterspring", 1377: "Silithus", 1497: "Undercity", 1519: "Stormwind City",
  1537: "Ironforge", 1637: "Orgrimmar", 1638: "Thunder Bluff", 1657: "Darnassus"}
# Forever zones the table above doesn't know: name them from QuestieDB's zone enum
for m in re.finditer(r'^\s*([A-Z_0-9]+)\s*=\s*(\d+),', open(qdb + 'src/corrections/enum/zones.lua').read(), re.M):
    a = int(m.group(2))
    if a not in AREA and a in ui and a not in DUNGEON_AREAS:
        AREA[a] = m.group(1).replace("_", " ").title().replace("'S", "'s")
MAPNAME = {}
for a, nm in AREA.items():
    if a in ui and ui[a] not in MAPNAME: MAPNAME[ui[a]] = nm
ALLIANCE_ZONES = {1, 12, 38, 40, 141, 148, 1519, 1537, 1657, 44, 10}  # where the Horde rarely goes to farm

npc_spawns, npc_name = {}, {}
for line in open(npcs_tsv, encoding="utf-8"):
    nid, name, friend, flags, sub, spawns = line.rstrip("\n").split("\t")
    nid = int(nid)
    npc_name[nid] = name
    sp = {}
    if spawns:
        for part in spawns.split("|"):
            z, pts = part.split(":")
            sp.setdefault(int(z), []).extend(tuple(map(float, p.split(","))) for p in pts.split(";") if p)
    npc_spawns[nid] = (sp, friend, sub, int(flags or 0))

def centre(pts):
    """The point with the most other points within 8 map units."""
    best, bc = None, -1
    for p in pts:
        c = sum(1 for q in pts if (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 <= 64)
        if c > bc: best, bc = p, c
    return best, bc

def r1(v): return round(v, 1)
def lua_str(s): return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'

# ---------------------------------------------------------------------------
# Recipes: every craft in the plans, and recipes for crafted reagents
# ---------------------------------------------------------------------------
plan_crafts = set()
plan_text = {}
trainer_names = set()
trainer_ctx = {}
for p in glob.glob(os.path.join(addon, "Professions", "*.lua")):
    if p.endswith("Generated.lua"): continue
    src = open(p, encoding="utf-8").read()
    for c, txt in re.findall(r'craft = "([^"]+)"[^\n]*?mats = "([^"]*)"', src):
        plan_text.setdefault(c.split(",")[0].split(" or ")[0].strip(), txt)
    for c in re.findall(r'craft = "([^"]+)"', src):
        for part in re.split(r",\s*|\s+or\s+", c):
            if part.strip(): plan_crafts.add(part.strip())
    tm = re.search(r'\w\.train = \{(.*?)^\}', src, re.S | re.M)
    if tm:
        for nm, ctx in re.findall(r"([A-Z][A-Za-z'\.]+(?: [A-Z][A-Za-z'\.]+){0,3}) \(([^)]*)", tm.group(1)):
            trainer_names.add(nm); trainer_ctx[nm] = ctx
        for nm in re.findall(r'"([A-Z][A-Za-z\']+(?: [A-Z][A-Za-z\']+){0,2}) (?:in|at) ', tm.group(1)):
            trainer_names.add(nm)
by_name = defaultdict(list)
made_by = {}
for s in spells:
    reag = [(int(s["Reagent%d" % k]), int(s["ReagentCount%d" % k])) for k in range(1, 9) if int(s["Reagent%d" % k] or 0) > 0]
    if not reag: continue
    eff = int(s["Effect1"])
    if eff not in (24, 53, 157): continue
    made = int(s["EffectItemType1"] or 0)
    y = int(s["EffectBasePoints1"]) + int(s["EffectBaseDice1"] or 0) if eff == 24 else 0
    rec = {"s": int(s["Id"]), "i": made, "y": max(1, y), "r": reag, "name": s["SpellName"]}
    by_name[s["SpellName"].lower()].append(rec)
    if eff == 24 and made and made not in made_by: made_by[made] = rec
RECIPES = {}
def resolve(name):
    lst = by_name.get(name.lower())
    if not lst:
        # item name differs from the spell name (e.g. "Smelt Copper" makes "Copper Bar")
        for iid, it in items.items():
            if it["name"].lower() == name.lower() and iid in made_by: return made_by[iid]
        return None
    return sorted(lst, key=lambda r: (-len(r["r"]), r["s"]))[0]
missing = []
item_by_name = {}
for iid, it in items.items(): item_by_name.setdefault(it["name"].lower(), iid)
FOREVER_ITEMS = {}
if fitems_tsv:
    for line in open(fitems_tsv, encoding="utf-8"):
        a, nm = line.rstrip("\n").split("\t", 1)
        FOREVER_ITEMS[int(a)] = nm
        item_by_name.setdefault(nm.lower(), int(a))
def from_text(c):
    """Forever-only recipes: read the reagents from the guide's text ("2 Linen Cloth, 1 Coarse Thread each")."""
    txt = plan_text.get(c)
    if not txt: return None
    txt = re.split(r"\(| or |;", txt)[0]
    reag = []
    for cnt, nm in re.findall(r"(\d+)\s+([A-Z][A-Za-z' :-]+?)(?=,| each|\.|$)", txt):
        iid = item_by_name.get(nm.strip().lower())
        if iid: reag.append((iid, int(cnt)))
    if not reag: return None
    return {"s": 0, "i": item_by_name.get(c.lower(), 0), "y": 1, "r": reag, "name": c, "guide": True}
for c in sorted(plan_crafts):
    r = resolve(c) or from_text(c)
    if r: RECIPES[c] = r
    else: missing.append(c)
# crafted reagents (one level down is enough: bars, bolts, elixirs, oils, rods)
for c in list(RECIPES):
    for iid, _ in RECIPES[c]["r"]:
        if iid in made_by:
            rec = made_by[iid]
            nm = items[iid]["name"] if iid in items else rec["name"]
            if nm not in RECIPES: RECIPES[nm] = rec
print("recipes %d, not found: %s" % (len(RECIPES), ", ".join(missing)), file=sys.stderr)

mats = set()
for r in RECIPES.values():
    for iid, _ in r["r"]: mats.add(iid)

# ---------------------------------------------------------------------------
# Where materials come from
# ---------------------------------------------------------------------------
herb_names = [n.replace("\\'", "'") for n, _ in re.findall(r'\{ "([^"]+)", (\d+) \}', open(os.path.join(addon, "NodeData.lua"), encoding="utf-8").read().split("RG.HERB_TYPES = {")[1].split("\n}\n")[0])]
ore_nodes = [n.replace("\\'", "'") for n, _ in re.findall(r'\{ "([^"]+)", (\d+) \}', open(os.path.join(addon, "NodeData.lua"), encoding="utf-8").read().split("RG.NODE_ORES = {")[1].split("\n}\n")[0])]
node_items = defaultdict(list)    # item -> node names
gobj_by_loot = defaultdict(list)
for e, g in gobj.items():
    nm = g["name"]
    if nm in ore_nodes or nm in herb_names:
        lid = int(g.get("data1") or 0)
        gobj_by_loot[lid].append(nm)
for row in gloot:
    for nm in gobj_by_loot.get(int(row["entry"]), []):
        iid = int(row["item"])
        if int(row["mincountOrRef"]) > 0 and nm not in node_items[iid]: node_items[iid].append(nm)
for nm in herb_names:                       # herb item named like its plant
    for iid, it in items.items():
        if it["name"] == nm and nm not in node_items[iid]: node_items[iid].append(nm)
ORE_OF = {"Copper Ore": "Copper Vein", "Tin Ore": "Tin Vein", "Silver Ore": "Silver Vein", "Iron Ore": "Iron Deposit", "Gold Ore": "Gold Vein",
          "Mithril Ore": "Mithril Deposit", "Truesilver Ore": "Truesilver Deposit", "Thorium Ore": "Small Thorium Vein", "Dark Iron Ore": "Dark Iron Deposit",
          "Rough Stone": "Copper Vein", "Coarse Stone": "Tin Vein", "Heavy Stone": "Iron Deposit", "Solid Stone": "Mithril Deposit", "Dense Stone": "Small Thorium Vein",
          "Incendicite Ore": "Incendicite Mineral Vein", "Lesser Bloodstone Ore": "Lesser Bloodstone Deposit", "Indurium Ore": "Indurium Mineral Vein"}
for iid, it in items.items():
    if it["name"] in ORE_OF and ORE_OF[it["name"]] not in node_items[iid]: node_items[iid].append(ORE_OF[it["name"]])

# creature drops (resolving reference loot tables) and skinning
refs = defaultdict(list)
for row in rloot: refs[int(row["entry"])].append(row)
def expand(rowlist, chance=100.0, depth=0):
    for row in rowlist:
        ch = float(row["ChanceOrQuestChance"])
        mc = int(row["mincountOrRef"])
        if mc < 0:
            if depth < 3: yield from expand(refs.get(-mc, []), chance * (abs(ch) if ch else 100) / 100.0, depth + 1)
        else:
            yield int(row["item"]), chance * (abs(ch) if ch else 10) / 100.0
by_loot = defaultdict(list)
for row in cloot: by_loot[int(row["entry"])].append(row)
by_skin = defaultdict(list)
for row in sloot: by_skin[int(row["entry"])].append(row)
drop_of = defaultdict(dict)   # item -> creature -> chance
skin_of = defaultdict(dict)
for cid, c in creatures.items():
    lid = int(c["LootId"] or 0)
    if lid:
        for iid, ch in expand(by_loot.get(lid, [])):
            if iid in mats and ch >= 3: drop_of[iid][cid] = max(drop_of[iid].get(cid, 0), ch)
    sid = int(c["SkinningLootId"] or 0)
    if sid:
        for iid, ch in expand(by_skin.get(sid, [])):
            if iid in mats and ch >= 10: skin_of[iid][cid] = max(skin_of[iid].get(cid, 0), ch)

def mob_spots(cands, limit=8):
    """cands: {creature: chance} -> best farm spots (Horde-safe, outdoors, not elite)."""
    out = []
    for cid, ch in cands.items():
        n = FN.get(str(cid))
        sp = npc_spawns.get(cid)
        if not n or not sp: continue
        if (n.get("rank") or 0) not in (0,): continue
        # hostile ("") or neutral ("AH") mobs; not one faction's NPCs/guards, not vendors or quest givers
        if sp[1] in ("A", "H") or sp[3]: continue
        for z, pts in sp[0].items():
            if z in DUNGEON_AREAS or z not in ui or z in ALLIANCE_ZONES: continue
            if len(pts) < 4: continue
            p, cnt = centre(pts)
            lo, hi = n.get("minLevel") or 1, n.get("maxLevel") or 1
            score = ch * min(cnt, 20)
            lab = "%s (%s, level %s, %.0f%%)" % (npc_name.get(cid, n["name"]), AREA.get(z, "?"), lo if lo == hi else "%d-%d" % (lo, hi), min(ch, 100))
            out.append((score, ui[z], p, lab, hi))
    out.sort(key=lambda o: -o[0])
    seen, res = set(), []
    for o in out:
        key = (o[1], o[3].split(" (")[0])
        if key in seen: continue
        seen.add(key); res.append(o)
        if len(res) >= limit: break
    return res

# vendors
vendors_of = defaultdict(list)
for row in vend:
    if int(row.get("maxcount") or 0) != 0: continue
    vendors_of[int(row["item"])].append(int(row["entry"]))
CAPITAL_MAPS = {1454: 0, 1458: 0, 1456: 0}   # Orgrimmar, Undercity, Thunder Bluff first
def vendor_spots(iid, limit=6):
    out = []
    for vid in vendors_of.get(iid, []):
        sp = npc_spawns.get(vid)
        if not sp or "H" not in sp[1]: continue
        for z, pts in sp[0].items():
            if z not in ui or z in DUNGEON_AREAS: continue
            p = pts[0]
            out.append((CAPITAL_MAPS.get(ui[z], 1), ui[z], p, "%s%s (%s)" % (npc_name[vid], (" <" + sp[2] + ">") if sp[2] else "", AREA.get(z, "?"))))
    out.sort(key=lambda o: (o[0], o[3]))
    return out[:limit]

def kind_of(iid):
    it = items.get(iid)
    nm = it["name"] if it else ""
    if vendors_of.get(iid) and vendor_spots(iid, 1): return "vendor"
    if skin_of.get(iid): return "leather"          # skinned, even if a recipe can also make it
    if iid in made_by: return "crafted"
    if any(n in herb_names for n in node_items.get(iid, [])): return "herb"
    if nm.endswith(" Ore"): return "ore"
    if nm.endswith(" Stone"): return "stone"
    if node_items.get(iid): return "gem"
    if nm.lower().endswith("cloth"): return "cloth"
    if skin_of.get(iid) or nm.endswith("Leather") or nm.endswith("Hide") or "Scale" in nm: return "leather"
    if re.search(r"Dust|Essence|Shard|Crystal", nm) and it and int(it["class"]) == 7: return "enchant"
    if re.search(r"Elemental|Essence of|Heart of|Breath of|Core of|Globe of|Ichor", nm): return "elemental"
    if nm.startswith("Raw ") or "Fish" in nm or "Snapper" in nm or "Catfish" in nm: return "fish"
    if re.search(r"Meat|Flank|Egg|Leg|Wing|Steak|Chunk|Tail|Venison|Ribs|Tongue", nm): return "meat"
    return "drop"

# fish: the zones whose fishing loot has it (area -> zone)
fish_in = defaultdict(list)
by_area = defaultdict(list)
for row in floot: by_area[int(row["entry"])].append(row)
for a, rl in by_area.items():
    if a not in AREA or a in ALLIANCE_ZONES: continue
    got = defaultdict(float)
    for iid, ch in expand(rl): got[iid] = max(got[iid], ch)
    for iid, ch in got.items():
        if iid in mats and ch >= 5: fish_in[iid].append((ch, AREA[a]))
MAT_FISH = {iid: [z for _, z in sorted(v, key=lambda t: -t[0])][:3] for iid, v in fish_in.items()}
MAT_INFO, MAT_SPOTS, MAT_VENDORS, MAT_NODES = {}, {}, {}, {}
for iid in sorted(mats):
    it = items.get(iid)
    if not it:
        if iid in FOREVER_ITEMS: MAT_INFO[iid] = (FOREVER_ITEMS[iid], "drop")
        continue
    k = kind_of(iid)
    MAT_INFO[iid] = (it["name"], k)
    if k == "vendor": MAT_VENDORS[iid] = vendor_spots(iid)
    if node_items.get(iid): MAT_NODES[iid] = node_items[iid]
    if k in ("cloth", "meat", "drop", "elemental", "fish", "leather", "enchant", "gem"):
        cands = dict(drop_of.get(iid, {}))
        for cid, ch in skin_of.get(iid, {}).items(): cands[cid] = max(cands.get(cid, 0), ch * 0.6)
        sp = mob_spots(cands)
        if sp: MAT_SPOTS[iid] = sp

# ---------------------------------------------------------------------------
# Gathering: densest herb/vein clusters, skinnable beasts, fishing pools
# ---------------------------------------------------------------------------
nd = open(os.path.join(addon, "NodeData.lua"), encoding="utf-8").read()
def spots_of(block, names):
    out = defaultdict(lambda: defaultdict(list))   # name -> map -> points
    body = nd.split(block)[1].split("\n}\n")[0]
    for m, s in re.findall(r'\[(\d+)\] = "([^"]*)"', body):
        for p in s.split(";"):
            x, y, mask = p.split(",")
            x, y, mask = float(x), float(y), int(mask)
            if x < 0: continue
            for i, nm in enumerate(names):
                if mask & (1 << i): out[nm][int(m)].append((x, y))
    return out
HORDE_MAPS = set(ui[a] for a in AREA if a in ui and a not in ALLIANCE_ZONES)
GATHER = {}
for block, names in (("RG.NODE_SPOTS = {", ore_nodes), ("RG.HERB_SPOTS = {", herb_names)):
    for nm, maps in spots_of(block, names).items():
        cl = []
        for m, pts in maps.items():
            if m not in HORDE_MAPS: continue
            p, c = centre(pts)
            if c >= 3: cl.append((c, m, p, "%s: %d %s nearby (%d in the zone)" % (MAPNAME.get(m, "?"), c, nm + ("s" if not nm.endswith("s") else ""), len(pts))))
        cl.sort(key=lambda o: -o[0])
        if cl: GATHER[nm] = cl[:8]

skin_spots = []
for cid, c in creatures.items():
    if not int(c["SkinningLootId"] or 0): continue
    n = FN.get(str(cid)); sp = npc_spawns.get(cid)
    if not n or not sp or (n.get("rank") or 0) != 0 or sp[1] in ("A", "H") or sp[3]: continue
    for z, pts in sp[0].items():
        if z in DUNGEON_AREAS or z not in ui or z in ALLIANCE_ZONES or len(pts) < 6: continue
        p, cnt = centre(pts)
        hi = n.get("maxLevel") or 1
        skin_spots.append((hi, cnt, ui[z], p, "%s (%s, level %d)" % (npc_name.get(cid, n["name"]), AREA.get(z, "?"), hi)))
SKIN = []
for lvl in range(1, 64):
    band = sorted([s for s in skin_spots if s[0] == lvl], key=lambda s: -s[1])[:6]
    SKIN += band

fish = defaultdict(list)
POOL = re.compile(r"School|Floating Wreckage|Floating Debris|Shipwreck Debris|Oil Spill|Elemental Water")
for line in open(objs_tsv, encoding="utf-8"):
    nm, z, x, y = line.rstrip("\n").split("\t")
    z = int(z)
    if POOL.search(nm) and z in ui and z not in DUNGEON_AREAS: fish[ui[z]].append((float(x), float(y), nm))
FISH = {}
for m, pts in fish.items():
    p, c = centre([(a, b) for a, b, _ in pts])
    nm = next(n for a, b, n in pts if (a, b) == p)
    FISH[m] = (p, "%s (%d pools around here)" % (nm, c))

# dungeon entrances, for trainers who stand inside one (Annora in Uldaman)
dsrc = open(qdb + 'support/Forever/Zones/dungeons.lua', encoding='utf-8').read()
if 'if Expansions.Current' in dsrc: dsrc = dsrc[:dsrc.index('if Expansions.Current')]
ENTRANCE = {}
for dn, z, x, y in re.findall(r'\{"([^"]+)",[^\n]*?\{\{(\d+),\s*([\d.]+),\s*([\d.]+)\}', dsrc):
    if int(z) in ui and dn not in ENTRANCE: ENTRANCE[dn] = (ui[int(z)], (float(x), float(y)))
TRAINERS = {}
for nm in sorted(trainer_names):
    ctx = trainer_ctx.get(nm, "")
    for dn, (m, p) in ENTRANCE.items():
        if ctx.startswith(dn):
            TRAINERS[nm] = (m, p, nm + " (inside " + dn + ")")
    if nm in TRAINERS: continue
    nid = next((i for i, n in npc_name.items() if n == nm), None)
    sp = nid and npc_spawns.get(nid)
    if not sp: continue
    for z, pts in sp[0].items():
        if z in ui:
            TRAINERS[nm] = (ui[z], pts[0], nm); break
print("mats %d (spots %d, vendors %d, nodes %d), gather %d, skin spots %d, fish maps %d, trainers %d/%d" % (
    len(MAT_INFO), len(MAT_SPOTS), len(MAT_VENDORS), len(MAT_NODES), len(GATHER), len(SKIN), len(FISH), len(TRAINERS), len(trainer_names)), file=sys.stderr)

# ---------------------------------------------------------------------------
# Write
# ---------------------------------------------------------------------------
def wp(m, p, label, extra=""): return "{ %d, %s, %s, %s%s }" % (m, r1(p[0]), r1(p[1]), lua_str(label), extra)
L = ["-- GENERATED by tools/profs/gen.py: do not edit by hand.",
     "-- Recipes, where every profession material comes from, and places to gather, skin and fish",
     "-- (Forever coordinates). Sources: cMaNGOS classic DB (recipes, loot, vendors) and QuestieDB's",
     "-- merged WoW Forever data (spawns, levels, factions). In game, opening a profession window",
     "-- replaces these recipes with the ones your client actually shows.",
     "local _, RG = ...", "RG.RECIPES = {"]
for nm in sorted(RECIPES):
    r = RECIPES[nm]
    L.append("  [%s] = { s = %d, i = %d, y = %d, r = { %s }%s }," % (lua_str(nm), r["s"], r["i"], r["y"], ", ".join("{ %d, %d }" % x for x in r["r"]), ", guide = true" if r.get("guide") else ""))
L.append("}"); L.append("RG.MAT_INFO = {")
for iid in sorted(MAT_INFO): L.append("  [%d] = { %s, %s }," % (iid, lua_str(MAT_INFO[iid][0]), lua_str(MAT_INFO[iid][1])))
L.append("}"); L.append("RG.MAT_SPOTS = {")
for iid in sorted(MAT_SPOTS): L.append("  [%d] = { %s }," % (iid, ", ".join(wp(o[1], o[2], o[3], ", %d" % o[4]) for o in MAT_SPOTS[iid])))
L.append("}"); L.append("RG.MAT_VENDORS = {")
for iid in sorted(MAT_VENDORS):
    if MAT_VENDORS[iid]: L.append("  [%d] = { %s }," % (iid, ", ".join(wp(o[1], o[2], o[3]) for o in MAT_VENDORS[iid])))
L.append("}"); L.append("RG.MAT_FISH = {")
for iid in sorted(MAT_FISH):
    if iid in MAT_INFO and MAT_FISH[iid]: L.append("  [%d] = { %s }," % (iid, ", ".join(lua_str(z) for z in MAT_FISH[iid])))
L.append("}"); L.append("RG.MAT_NODES = {")
for iid in sorted(MAT_NODES): L.append("  [%d] = { %s }," % (iid, ", ".join(lua_str(n) for n in MAT_NODES[iid])))
L.append("}"); L.append("RG.GATHER_SPOTS = {")
for nm in sorted(GATHER): L.append("  [%s] = { %s }," % (lua_str(nm), ", ".join(wp(o[1], o[2], o[3]) for o in GATHER[nm])))
L.append("}"); L.append("RG.SKIN_SPOTS = {")
for s in SKIN: L.append("  %s," % wp(s[2], s[3], s[4], ", %d" % s[0]))
L.append("}"); L.append("RG.FISH_SPOTS = {")
for m in sorted(FISH): L.append("  [%d] = %s," % (m, wp(m, FISH[m][0], FISH[m][1])))
L.append("}"); L.append("RG.PROF_TRAINERS = {")
for nm in sorted(TRAINERS): t = TRAINERS[nm]; L.append("  [%s] = %s," % (lua_str(nm), wp(t[0], t[1], t[2])))
L.append("}"); L.append("RG.ZONE_MAPS = {")
for a in sorted(AREA, key=lambda a: AREA[a]):
    if a in ui and a not in DUNGEON_AREAS: L.append("  [%s] = %d," % (lua_str(AREA[a]), ui[a]))
L.append("}")
open(os.path.join(addon, "Professions", "Generated.lua"), "w", encoding="utf-8").write("\n".join(L) + "\n")
