#!/usr/bin/env python3
"""Build Classes/PaladinGear.lua: Ret paladin gear upgrades for every slot, levels 10-60.

Stats come from the cMaNGOS classic database (item_template + spell_template),
sources from QuestieDB's WoW Forever data (quest rewards, dungeon boss drops,
vendors), so only items that exist in Forever and that an Undead paladin can
get are listed. Items are scored with Waypath+'s default Ret weights.

Usage:
  git clone --depth 1 https://github.com/cmangos/classic-db.git /tmp/cdb
  zcat /tmp/cdb/Full_DB/*.sql.gz > /tmp/classic.sql
  lua5.1 dump.lua <QuestieDB>/data/Forever /tmp/forever_gear.json
  python3 gen.py /tmp/classic.sql /tmp/forever_gear.json <QuestieDB> ../../Classes/PaladinGear.lua
"""
import json, re, sys
from collections import defaultdict

sql_path, json_path, qdb_dir, out_path = sys.argv[1:5]

# ---------------------------------------------------------------------------
# SQL parsing (only the tables we need)
# ---------------------------------------------------------------------------
def columns(sql, table):
    m = re.search(r"CREATE TABLE `%s` \((.*?)\) ENGINE" % table, sql, re.S)
    return re.findall(r"^\s*`(\w+)`", m.group(1), re.M)

def rows(sql, table):
    out = []
    for m in re.finditer(r"INSERT INTO `%s` VALUES " % table, sql):
        i = m.end()
        n = len(sql)
        while i < n:
            if sql[i] != '(':
                break
            i += 1
            row, cur, inq = [], [], False
            while True:
                c = sql[i]
                if inq:
                    if c == '\\':
                        cur.append(sql[i + 1]); i += 2; continue
                    if c == "'":
                        if i + 1 < n and sql[i + 1] == "'":
                            cur.append("'"); i += 2; continue
                        inq = False; i += 1; continue
                    cur.append(c); i += 1; continue
                if c == "'":
                    inq = True; i += 1; continue
                if c == ',':
                    row.append(''.join(cur)); cur = []; i += 1; continue
                if c == ')':
                    row.append(''.join(cur)); i += 1; break
                cur.append(c); i += 1
            out.append(row)
            if sql[i] == ',':
                i += 1
            elif sql[i] == ';':
                break
    return out

print("reading SQL...", file=sys.stderr)
sql = open(sql_path, encoding="utf-8", errors="replace").read()
icol = columns(sql, "item_template")
items = {}
for r in rows(sql, "item_template"):
    d = dict(zip(icol, r))
    items[int(d["entry"])] = d
scol = columns(sql, "spell_template")
want = ["Id"] + ["EffectApplyAuraName%d" % k for k in (1, 2, 3)] + ["EffectBasePoints%d" % k for k in (1, 2, 3)] + ["EffectMiscValue%d" % k for k in (1, 2, 3)] + ["Effect%d" % k for k in (1, 2, 3)]
idx = [scol.index(w) for w in want]
spells = {}
for r in rows(sql, "spell_template"):
    spells[int(r[idx[0]])] = {w: r[j] for w, j in zip(want, idx)}
del sql
print("items %d, spells %d" % (len(items), len(spells)), file=sys.stderr)

fv = json.load(open(json_path))
FI, FN, FQ = fv["items"], fv["npcs"], fv["quests"]

def L(v):
    """Questie lists can arrive as dicts with string keys."""
    if v is None: return []
    if isinstance(v, dict): return [v[k] for k in sorted(v, key=lambda x: int(x))]
    return v

# ---------------------------------------------------------------------------
# Zones and dungeons
# ---------------------------------------------------------------------------
AREA = {1: "Dun Morogh", 3: "Badlands", 4: "Blasted Lands", 8: "Swamp of Sorrows", 10: "Duskwood", 11: "Wetlands", 12: "Elwynn Forest",
  14: "Durotar", 15: "Dustwallow Marsh", 16: "Azshara", 17: "The Barrens", 28: "Western Plaguelands", 33: "Stranglethorn Vale",
  36: "Alterac Mountains", 38: "Loch Modan", 40: "Westfall", 41: "Deadwind Pass", 44: "Redridge Mountains", 45: "Arathi Highlands",
  46: "Burning Steppes", 47: "The Hinterlands", 51: "Searing Gorge", 85: "Tirisfal Glades", 130: "Silverpine Forest",
  139: "Eastern Plaguelands", 141: "Teldrassil", 148: "Darkshore", 215: "Mulgore", 267: "Hillsbrad Foothills", 331: "Ashenvale",
  357: "Feralas", 361: "Felwood", 400: "Thousand Needles", 405: "Desolace", 406: "Stonetalon Mountains", 440: "Tanaris",
  490: "Un'Goro Crater", 493: "Moonglade", 618: "Winterspring", 1377: "Silithus", 1497: "Undercity", 1519: "Stormwind City",
  1537: "Ironforge", 1769: "Timbermaw Hold", 1637: "Orgrimmar", 1638: "Thunder Bluff", 1657: "Darnassus", 2597: "Alterac Valley"}
DUNGEON = {}
dsrc = open(qdb_dir + "/support/Forever/Zones/dungeons.lua", encoding="utf-8").read()
for m in re.finditer(r'\[(\d+)\] = \{"([^"]+)",(?:\{([\d,]*)\}|nil)', dsrc):
    DUNGEON[int(m.group(1))] = m.group(2)
    for alt in (m.group(3) or "").split(","):
        if alt: DUNGEON[int(alt)] = m.group(2)
RAIDS = {"Molten Core", "Blackwing Lair", "Onyxia's Lair", "Zul'Gurub", "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj", "Naxxramas",
         "Utgarde Keep"}  # (Utgarde: not a classic-level dungeon)
HORDE_FAR = {"The Stockade"}  # inside Stormwind
def zone_name(z):
    if z is None: return None
    return DUNGEON.get(z) or AREA.get(z)

# ---------------------------------------------------------------------------
# Scoring (Waypath+ default Ret weights)
# ---------------------------------------------------------------------------
W = dict(STR=2.2, AGI=1.0, AP=1.0, CRIT=22, HIT=25, STA=0.15, INT=0.15, SPI=0.05, SP=0.3, DPS=14, SLOW=4)
STAT = {3: "AGI", 4: "STR", 5: "INT", 6: "SPI", 7: "STA"}
def stats_of(d):
    s = defaultdict(float)
    for k in range(1, 11):
        t, v = int(d["stat_type%d" % k]), int(d["stat_value%d" % k])
        if t in STAT and v: s[STAT[t]] += v
    for k in range(1, 6):
        sid, trig = int(d["spellid_%d" % k]), int(d["spelltrigger_%d" % k])
        if not sid or trig != 1: continue
        sp = spells.get(sid)
        if not sp: continue
        for e in (1, 2, 3):
            aura, bp, misc = int(sp["EffectApplyAuraName%d" % e]), int(sp["EffectBasePoints%d" % e]) + 1, int(sp["EffectMiscValue%d" % e])
            if aura == 99: s["AP"] += bp
            elif aura == 52: s["CRIT"] += bp
            elif aura == 54: s["HIT"] += bp
            elif aura == 13 and (misc & 2): s["SP"] += bp
    return s

def weapon(d):
    delay = int(d["delay"]) / 1000.0
    if delay <= 0: return 0, 0
    dmg = sum((float(d["dmg_min%d" % k]) + float(d["dmg_max%d" % k])) / 2 for k in range(1, 6))
    return dmg / delay, delay

def score(d, slot):
    s = stats_of(d)
    v = sum(W[k] * s[k] for k in s)
    if slot == "2H":
        dps, speed = weapon(d)
        v += dps * W["DPS"] + max(0, (speed - 3.0) * 10) * W["SLOW"]
    return v, s

INV = {1: "Head", 2: "Neck", 3: "Shoulder", 5: "Chest", 20: "Chest", 6: "Waist", 7: "Legs", 8: "Feet", 9: "Wrist",
       10: "Hands", 11: "Ring", 12: "Trinket", 16: "Back", 17: "2H"}
TWOH = {1, 5, 8}  # 2H axe, 2H mace, 2H sword (paladins can't use polearms or staves)

def eligible(d):
    cls, sub, inv = int(d["class"]), int(d["subclass"]), int(d["InventoryType"])
    if inv not in INV: return None
    if cls == 2:
        if inv != 17 or sub not in TWOH: return None
    elif cls == 4:
        if sub not in (0, 1, 2, 3, 4): return None
        if inv == 17: return None
    else:
        return None
    ac, ar = int(d["AllowableClass"]), int(d["AllowableRace"])
    if ac not in (-1, 0) and not (ac & 2): return None
    if ar not in (-1, 0) and not (ar & 16): return None
    if int(d["Quality"]) < 2 or int(d["RandomProperty"]) != 0 or int(d["requiredhonorrank"]) != 0: return None
    if int(d["RequiredReputationFaction"]) != 0: return None
    return INV[inv]

# ---------------------------------------------------------------------------
# Sources (Forever data)
# ---------------------------------------------------------------------------
RAID_ZONES = {2717, 2677, 2159, 1977, 3429, 3428, 3456, 19, 2437}
def givers_of(q):
    st = q.get("start") or []
    if isinstance(st, dict): return L(st.get("1")), L(st.get("3"))
    st = L(st)
    return (L(st[0]) if len(st) > 0 else []), (L(st[2]) if len(st) > 2 else [])

def raid_item(iid):
    f = FI.get(str(iid))
    for nid in L(f and f.get("npcDrops")):
        n = FN.get(str(nid))
        if n and (n.get("zone") in RAID_ZONES or DUNGEON.get(n.get("zone")) in RAIDS): return True
    return False

# quests that need a raid boss's drop to start or finish
RAID_QUESTS = {"The Lord of Blackrock", "The Nightmare Manifests", "Victory for the Horde", "The Savior of Kalimdor"}
def horde_quest(qid):
    q = FQ.get(str(qid))
    if not q or q["name"] in RAID_QUESTS: return None
    races = q.get("races") or 0
    if races and not (int(races) & 16): return None
    classes = q.get("classes") or 0
    if classes and not (int(classes) & 2): return None
    z = q.get("zone")
    if z in RAID_ZONES or DUNGEON.get(z) in RAIDS: return None
    if z == 1377 and (q.get("reqLevel") or 0) >= 60: return None  # Silithus: Ahn'Qiraj war quests
    givers, starters = givers_of(q)
    if any(raid_item(i) for i in starters): return None  # e.g. Head of Nefarian / Onyxia
    if givers:
        ok = False
        for g in givers:
            n = FN.get(str(g))
            if n and "H" in (n.get("faction") or ""): ok = True
        if not ok: return None
    return q

def sources(iid):
    f = FI.get(str(iid))
    if not f: return []
    out = []
    for qid in L(f.get("questRewards")):
        q = horde_quest(qid)
        if q:
            z = q.get("zone")
            zname = zone_name(z) if isinstance(z, int) and z > 0 else None
            giver = None
            gv, _ = givers_of(q)
            if gv:
                n = FN.get(str(gv[0])); giver = n and n.get("name")
            out.append({"how": "Quest", "lvl": q.get("level") or q.get("reqLevel") or 0, "req": q.get("reqLevel") or 0,
                        "src": q["name"] + (" (" + giver + ")" if giver else ""), "zone": zname or "", "quest": q["name"]})
    drops = L(f.get("npcDrops"))
    if 0 < len(drops) <= 4:
        for nid in drops:
            n = FN.get(str(nid))
            if not n: continue
            z = n.get("zone")
            d = DUNGEON.get(z)
            if d:
                if d in RAIDS or d in HORDE_FAR: continue
                if (n.get("rank") or 0) < 1: continue
                out.append({"how": "Dungeon", "lvl": n.get("maxLevel") or 0, "src": n["name"], "zone": d})
            elif (n.get("rank") or 0) in (1, 2, 4) and len(drops) <= 2 and AREA.get(z):
                out.append({"how": "Rare mob", "lvl": n.get("maxLevel") or 0, "src": n["name"], "zone": zone_name(z) or ""})
    for vid in L(f.get("vendors")):
        n = FN.get(str(vid))
        sub = (n.get("sub") or "") if n else ""
        if n and "H" in (n.get("faction") or "") and not re.search(r"Supply Officer|Quartermaster|Legionnaire|Battlemaster", sub):
            out.append({"how": "Vendor", "lvl": 0, "src": n["name"], "zone": zone_name(n.get("zone")) or ""})
    return out

# ---------------------------------------------------------------------------
# Pick the upgrades
# ---------------------------------------------------------------------------
cands = defaultdict(list)
for iid, d in items.items():
    slot = eligible(d)
    if not slot: continue
    src = sources(iid)
    if not src: continue
    req = int(d["RequiredLevel"]) or max(1, int(d["ItemLevel"]) - 5)
    if req > 60: continue
    sc, st = score(d, slot)
    if sc <= 0: continue
    # armor and jewelry must carry melee stats (skip caster and tank-only pieces)
    if slot != "2H" and sum(st.get(k, 0) for k in ("STR", "AGI", "AP", "CRIT", "HIT")) <= 0: continue
    # prefer quest rewards, then dungeon, then the rest
    order = {"Quest": 0, "Dungeon": 1, "Vendor": 2, "Rare mob": 3}
    src.sort(key=lambda x: order.get(x["how"], 9))
    s0 = src[0]
    lvl = max(req, int(s0.get("req") or 0)) if s0["how"] == "Quest" else req
    if lvl < 8: continue
    cands[slot].append({"id": iid, "name": d["name"], "slot": slot, "lvl": lvl, "score": sc, "q": int(d["Quality"]),
                        "how": s0["how"], "src": s0["src"], "zone": s0["zone"], "stats": dict(st)})

picked = []
for slot, lst in cands.items():
    lst.sort(key=lambda c: (c["lvl"], -c["score"]))
    by_id = {}
    # 1) the upgrade path: anything better than everything available at its level or below
    best = 0
    for c in lst:
        if c["score"] > best * 1.05:
            by_id[c["id"]] = c; best = max(best, c["score"])
    # 2) per 5-level window: the best quest reward and the best dungeon drop (easy alternatives)
    for lo in range(8, 61, 5):
        win = [c for c in lst if lo <= c["lvl"] < lo + 5]
        for how in ("Quest", "Dungeon"):
            w = [c for c in win if c["how"] == how]
            if w:
                top = max(w, key=lambda c: c["score"])
                # only if it's a real upgrade over what the path offered 5 levels earlier
                prior = max([c["score"] for c in by_id.values() if c["lvl"] <= lo - 3] or [0])
                if top["score"] > prior * 1.05: by_id[top["id"]] = top
    picked += list(by_id.values())

picked.sort(key=lambda c: (c["lvl"], c["slot"]))
cnt = defaultdict(int)
for c in picked: cnt[c["slot"]] += 1
print("picked %d: %s" % (len(picked), dict(cnt)), file=sys.stderr)

def lua_str(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
with open(out_path, "w", encoding="utf-8") as f:
    f.write("-- GENERATED by tools/gear/gen.py: do not edit by hand.\n")
    f.write("-- Ret paladin upgrades for every slot, levels 8-60: quest rewards an Undead paladin can get,\n")
    f.write("-- dungeon boss drops, and Horde vendors. Stats: cMaNGOS classic DB; sources: QuestieDB Forever data.\n")
    f.write("local _, RG = ...\n")
    f.write("RG.CLASS_GEAR = RG.CLASS_GEAR or {}\n")
    f.write("RG.CLASS_GEAR.PALADIN = {\n")
    for c in picked:
        f.write("  { id = %d, slot = %s, lvl = %d, how = %s, src = %s, zone = %s, score = %d, gen = true },  -- %s\n" % (
            c["id"], lua_str(c["slot"]), c["lvl"], lua_str(c["how"]), lua_str(c["src"]), lua_str(c["zone"] or ""), round(c["score"]), c["name"]))
    f.write("}\n")
