#!/usr/bin/env python3
"""Build Classes/<Class>Gear.lua for every class: leveling gear upgrades for every slot,
levels 5-60, scored with that class's own stat weights and limited to what it can wear
and wield (both read from Classes/<Class>.lua, so the add-on and this list agree).

Stats come from the cMaNGOS classic database (item_template + spell_template),
sources from QuestieDB's merged WoW Forever data (quest rewards, dungeon boss drops,
vendors), so only items that exist in Forever and that a Horde character of that class
can get are listed.

It also builds Classes/SpecGear.lua: for every spec on the 2nd Spec tab (Classes/Specs.lua)
that isn't the class's leveling spec, the gear to start collecting from level 30, scored with
that spec's weights, weapon model and weapons (tanks get shields, defense, dodge, parry, block
and armor; healers get +healing, mp5 and Intellect).

Usage:
  git clone --depth 1 https://github.com/cmangos/classic-db.git /tmp/cdb
  zcat /tmp/cdb/Full_DB/*.sql.gz > /tmp/classic.sql
  lua5.1 dump.lua /tmp/qdb/src/corrections/Forever/combined /tmp/forever_gear.json
  lua5.1 specs_dump.lua <Waypath+ folder> /tmp/specs.json
  python3 gen.py /tmp/classic.sql /tmp/forever_gear.json /tmp/qdb <Waypath+ folder> [Class ...] [--specs /tmp/specs.json]
"""
import json, re, sys
from collections import defaultdict

args = sys.argv[1:]
SPECS_JSON = None
if "--specs" in args:
    i = args.index("--specs"); SPECS_JSON = args[i + 1]; del args[i:i + 2]
sql_path, json_path, qdb_dir, addon_dir = args[0:4]
import os, glob
ONLY = set(args[4:])
if addon_dir.endswith('.lua'): addon_dir = os.path.dirname(os.path.dirname(os.path.abspath(addon_dir)))  # old usage: path to PaladinGear.lua

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
# Classes: weights, weapon model and proficiencies come from Classes/<Class>.lua
# ---------------------------------------------------------------------------
def lua_table(src, name):
    m = re.search(r'^\w\.%s = \{(.*?)^\}' % name, src, re.S | re.M) or re.search(r'^\w\.%s = \{(.*?)\}' % name, src, re.S | re.M)
    return m.group(1) if m else ''
def read_class(path):
    src = open(path, encoding='utf-8').read()
    tok = re.search(r'RG\.RegisterClass\("(\w+)"', src).group(1)
    name = re.search(r'name = "([^"]+)"', src).group(1)
    spec = re.search(r'spec = "([^"]+)"', src).group(1)
    w = {k: float(v) for k, v in re.findall(r'^\s*(\w+)\s*=\s*(-?[\d.]+),', lua_table(src, 'weights'), re.M)}
    model = re.search(r'\w\.model = "(\w+)"', src).group(1)
    weapons = {int(x) for x in re.findall(r'\d+', lua_table(src, 'weapons'))}
    armor = {int(a): int(b) for a, b in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', lua_table(src, 'armor'))}
    bit = int(re.search(r'\w\.classBit = (\d+)', src).group(1))
    return dict(tok=tok, name=name, spec=spec, w=w, model=model, weapons=weapons, armor=armor, bit=bit)

STAT = {3: "AGI", 4: "STR", 5: "INT", 6: "SPI", 7: "STA"}
SCHOOL = {2: "SP_HOLY", 4: "SP_FIRE", 8: "SP_NATURE", 16: "SP_FROST", 32: "SP_SHADOW", 64: "SP_ARCANE"}
def stats_of(d):
    s = defaultdict(float)
    for k in range(1, 11):
        t, v = int(d["stat_type%d" % k]), int(d["stat_value%d" % k])
        if t in STAT and v: s[STAT[t]] += v
    if int(d.get("armor") or 0) > 0: s["ARMOR"] += int(d["armor"])
    if int(d.get("block") or 0) > 0: s["BLOCKVAL"] += int(d["block"])
    for k in range(1, 6):
        sid, trig = int(d["spellid_%d" % k]), int(d["spelltrigger_%d" % k])
        if not sid or trig != 1: continue
        sp = spells.get(sid)
        if not sp: continue
        for e in (1, 2, 3):
            aura, bp, misc = int(sp["EffectApplyAuraName%d" % e]), int(sp["EffectBasePoints%d" % e]) + 1, int(sp["EffectMiscValue%d" % e])
            if aura == 99: s["AP"] += bp
            elif aura == 124: s["RAP"] += bp
            elif aura in (52, 57): s["CRIT"] += bp          # WoW Forever merges melee and spell crit
            elif aura in (54, 55): s["HIT"] += bp           # ... and hit
            elif aura == 135: s["HEAL"] += bp
            elif aura == 85 and misc == 0: s["MP5"] += bp
            elif aura == 30 and misc == 95: s["DEF"] += bp     # Defense skill
            elif aura == 49: s["DODGE"] += bp
            elif aura == 47: s["PARRY"] += bp
            elif aura == 51: s["BLOCK"] += bp
            elif aura == 158: s["BLOCKVAL"] += bp
            elif aura == 13 and misc:
                if (misc & 126) == 126: s["SP"] += bp
                else:
                    for bitv, key in SCHOOL.items():
                        if misc & bitv: s[key] += bp
    return s

def weapon(d):
    delay = int(d["delay"]) / 1000.0
    if delay <= 0: return 0, 0
    dmg = sum((float(d["dmg_min%d" % k]) + float(d["dmg_max%d" % k])) / 2 for k in range(1, 6))
    return dmg / delay, delay

MULT_2H = {"2H": 1, "DW": 0.75, "ranged": 1, "caster": 0, "feral": 1, "tank": 0.6}
MULT_1H = {"2H": 0.55, "DW": 1, "ranged": 0.55, "caster": 0, "feral": 0.55, "tank": 1}
def score(d, slot, C):
    """Same formula as RG.Score in Core.lua."""
    W, model = C["w"], C["model"]
    s = stats_of(d)
    v = sum(W.get(k, 0) * s[k] for k in s)
    # what the item gives beyond its armor value (and, except for tanks, beyond Stamina)
    stat_only = v - W.get("ARMOR", 0) * s.get("ARMOR", 0)
    if C.get("kind") != "tank": stat_only -= W.get("STA", 0) * s.get("STA", 0)
    dps, speed = weapon(d)
    if dps > 0:
        if slot == "Ranged": v += dps * W.get("RANGED_DPS", 0)
        elif slot == "2H":
            v += dps * W.get("WEAPON_DPS", 0) * MULT_2H[model]
            if model == "2H" and speed > 3.0: v += (speed - 3.0) * 10 * W.get("SLOW_BONUS", 0)
        elif slot == "Off Hand": v += dps * W.get("WEAPON_DPS", 0) * (0.5 if model == "DW" else 0)
        else:
            v += dps * W.get("WEAPON_DPS", 0) * MULT_1H[model]
            if model == "DW" and speed > 2.6: v += (speed - 2.6) * 10 * W.get("SLOW_BONUS", 0)
    return v, s, stat_only

ARMOR_INV = {1: "Head", 2: "Neck", 3: "Shoulder", 5: "Chest", 20: "Chest", 6: "Waist", 7: "Legs", 8: "Feet", 9: "Wrist",
             10: "Hands", 11: "Ring", 12: "Trinket", 16: "Back"}
# Which weapon slots each model gets a list for
MODEL_SLOTS = {"2H": {"2H"}, "DW": {"Main Hand", "Off Hand"}, "ranged": {"Ranged", "2H"},
               "caster": {"2H", "Main Hand", "Off Hand", "Ranged"}, "feral": {"2H"}, "tank": {"Main Hand", "Off Hand"}}

def eligible(d, C):
    cls, sub, inv = int(d["class"]), int(d["subclass"]), int(d["InventoryType"])
    slots = MODEL_SLOTS[C["model"]]
    slot = None
    if cls == 2:
        if sub not in C["weapons"]: return None
        if inv == 17: slot = "2H"
        elif inv in (13, 21): slot = "Main Hand"
        elif inv == 22: slot = "Off Hand"
        elif inv in (15, 25, 26): slot = "Ranged"
        else: return None
        if slot not in slots: return None
    elif cls == 4:
        if inv == 23:   # held in off-hand
            if "Off Hand" not in slots or C["model"] != "caster": return None
            slot = "Off Hand"
        elif inv == 14 and sub == 6:   # shield
            if not C.get("shield") or "Off Hand" not in slots: return None
            slot = "Off Hand"
        elif inv in ARMOR_INV:
            if sub in (1, 2, 3, 4) and inv != 16:
                lvl_from = C["armor"].get(sub)
                if lvl_from is None: return None
                if lvl_from > 1 and int(d["RequiredLevel"]) < lvl_from: return None
            elif sub not in (0, 1): return None
            slot = ARMOR_INV[inv]
        else: return None
    else:
        return None
    ac, ar = int(d["AllowableClass"]), int(d["AllowableRace"])
    if ac not in (-1, 0) and not (ac & C["bit"]): return None
    if ar not in (-1, 0) and not (ar & 178): return None
    if int(d["Quality"]) < 2 or int(d["RandomProperty"]) != 0 or int(d["requiredhonorrank"]) != 0: return None
    if int(d["RequiredReputationFaction"]) != 0: return None
    return slot

RAID_ZONES = {2717, 2677, 2159, 1977, 3429, 3428, 3456, 19}  # MC, BWL, Onyxia, ZG, AQ, Naxx
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
HORDE = 2 | 16 | 32 | 128 | 8589934592   # Orc, Undead, Tauren, Troll, Skyborne (Horde)
CLASS_BIT = 2   # set per class below
def horde_quest(qid):
    q = FQ.get(str(qid))
    if not q or q["name"] in RAID_QUESTS: return None
    races = q.get("races") or 0
    if races and not (int(races) & HORDE): return None
    classes = q.get("classes") or 0
    if classes and not (int(classes) & CLASS_BIT): return None
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
                        "src": q["name"] + (" (" + giver + ")" if giver else ""), "zone": zname or "", "quest": q["name"], "q": int(qid)})
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
                out.append({"how": "Dungeon", "lvl": n.get("maxLevel") or 0, "src": n["name"], "zone": d, "bl": n.get("maxLevel") or 0})
            elif (n.get("rank") or 0) in (1, 2, 4) and len(drops) <= 2 and AREA.get(z):
                out.append({"how": "Rare mob", "lvl": n.get("maxLevel") or 0, "src": n["name"], "zone": zone_name(z) or "", "bl": n.get("maxLevel") or 0})
    for vid in L(f.get("vendors")):
        n = FN.get(str(vid))
        sub = (n.get("sub") or "") if n else ""
        if n and "H" in (n.get("faction") or "") and not re.search(r"Supply Officer|Quartermaster|Legionnaire|Battlemaster", sub):
            out.append({"how": "Vendor", "lvl": 0, "src": n["name"], "zone": zone_name(n.get("zone")) or ""})
    return out

# ---------------------------------------------------------------------------
# Pick the upgrades, class by class
# ---------------------------------------------------------------------------
def lua_str(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
ORDER = {"Quest": 0, "Dungeon": 1, "Vendor": 2, "Rare mob": 3}
src_cache = {}
def pick(C, lvl_from=5):
    """The upgrade path for every slot plus the best quest reward and dungeon drop per
    5-level window, from lvl_from to 60."""
    global CLASS_BIT
    CLASS_BIT = C["bit"]
    cands = defaultdict(list)
    for iid, d in items.items():
        slot = eligible(d, C)
        if not slot: continue
        key = (iid, CLASS_BIT)
        if key not in src_cache: src_cache[key] = sources(iid)
        src = [dict(x) for x in src_cache[key]]
        if not src: continue
        req = int(d["RequiredLevel"]) or max(1, int(d["ItemLevel"]) - 5)
        if req > 60: continue
        sc, st, stat_only = score(d, slot, C)
        if sc <= 0: continue
        # armor and jewelry must carry stats this class wants, not only Stamina
        if slot in ARMOR_INV.values() and stat_only <= 1.0: continue
        src.sort(key=lambda x: ORDER.get(x["how"], 9))
        s0 = src[0]
        lvl = max(req, int(s0.get("req") or 0)) if s0["how"] == "Quest" else req
        if lvl < max(5, lvl_from - 2): continue
        cands[slot].append({"id": iid, "name": d["name"], "slot": slot, "lvl": lvl, "score": sc, "q": int(d["Quality"]),
                            "how": s0["how"], "src": s0["src"], "zone": s0["zone"], "q": s0.get("q"), "bl": s0.get("bl"),
                            "also": [x for x in src[1:3]]})
    picked = []
    start = (lvl_from // 5) * 5
    for slot, lst in cands.items():
        lst.sort(key=lambda c: (c["lvl"], -c["score"]))
        by_id = {}
        # 1) the upgrade path: anything better than everything available at its level or below
        best = 0
        for c in lst:
            if c["score"] > best * 1.05:
                by_id[c["id"]] = c; best = max(best, c["score"])
        # 2) per 5-level window: the best quest reward and the best dungeon drop (easy alternatives)
        for lo in range(start, 61, 5):
            win = [c for c in lst if lo <= c["lvl"] < lo + 5]
            for how in ("Quest", "Dungeon"):
                w = [c for c in win if c["how"] == how]
                if w:
                    top = max(w, key=lambda c: c["score"])
                    prior = max([c["score"] for c in by_id.values() if c["lvl"] <= lo - 3] or [0])
                    if top["score"] > prior * 1.05: by_id[top["id"]] = top
        picked += [c for c in by_id.values() if c["lvl"] >= lvl_from - 2]
    picked.sort(key=lambda c: (c["lvl"], c["slot"]))
    return picked

def entry(c):
    extra = ""
    if c.get("q"): extra += ", q = %d" % c["q"]
    if c.get("bl"): extra += ", bl = %d" % c["bl"]
    # other places it comes from (a second quest, a dungeon boss, a vendor)
    also = []
    for x in c.get("also") or []:
        if x["how"] == c["how"] and x["src"] == c["src"]: continue
        also.append("{ how = %s, src = %s, zone = %s%s%s }" % (lua_str(x["how"]), lua_str(x["src"]), lua_str(x.get("zone") or ""),
                    (", q = %d" % x["q"]) if x.get("q") else "", (", bl = %d" % x["bl"]) if x.get("bl") else ""))
    if also: extra += ", also = { " + ", ".join(also) + " }"
    return "  { id = %d, slot = %s, lvl = %d, how = %s, src = %s, zone = %s, score = %d%s, gen = true },  -- %s\n" % (
        c["id"], lua_str(c["slot"]), c["lvl"], lua_str(c["how"]), lua_str(c["src"]), lua_str(c["zone"] or ""), round(c["score"]), extra, c["name"])

CLASSES = {}
for path in sorted(glob.glob(os.path.join(addon_dir, 'Classes', '*.lua'))):
    if path.endswith('Gear.lua') or path.endswith('Specs.lua'): continue
    C = read_class(path)
    CLASSES[C["tok"]] = C
    if ONLY and C["name"] not in ONLY and C["tok"] not in ONLY: continue
    picked = pick(C)
    cnt = defaultdict(int)
    for c in picked: cnt[c["slot"]] += 1
    print("%-8s %-14s picked %3d: %s" % (C["name"], C["spec"], len(picked), dict(sorted(cnt.items()))), file=sys.stderr)
    out_path = os.path.join(addon_dir, 'Classes', C["name"] + 'Gear.lua')
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("-- GENERATED by tools/gear/gen.py: do not edit by hand.\n")
        f.write("-- %s %s upgrades for every slot, levels 5-60: quest rewards a Horde %s can get,\n" % (C["spec"], C["name"].lower(), C["name"].lower()))
        f.write("-- dungeon boss drops, and Horde vendors, scored with Classes/%s.lua's weights.\n" % C["name"])
        f.write("-- Stats: cMaNGOS classic DB; sources: QuestieDB merged Forever data.\n")
        f.write("local _, RG = ...\n")
        f.write("RG.CLASS_GEAR = RG.CLASS_GEAR or {}\n")
        f.write("RG.CLASS_GEAR.%s = {\n" % C["tok"])
        for c in picked: f.write(entry(c))
        f.write("}\n")

# ---------------------------------------------------------------------------
# 2nd specs: gear to collect from level 30 for every other spec
# ---------------------------------------------------------------------------
SPEC_FROM = 30
if SPECS_JSON:
    specs = json.load(open(SPECS_JSON))
    out = ["-- GENERATED by tools/gear/gen.py --specs: do not edit by hand.",
           "-- Gear to start collecting for every 2nd spec (Classes/Specs.lua), levels %d-60: quest rewards" % SPEC_FROM,
           "-- a Horde character of that class can get, dungeon boss drops and Horde vendors, scored with",
           "-- the spec's own weights. Stats: cMaNGOS classic DB; sources: QuestieDB merged Forever data.",
           "-- Leveling specs use their class's gear guide instead (Classes/<Class>Gear.lua).",
           "local _, RG = ...", "RG.SPEC_GEAR = RG.SPEC_GEAR or {}"]
    for tok in sorted(specs):
        C = CLASSES.get(tok)
        if not C: continue
        out.append("RG.SPEC_GEAR.%s = {" % tok)
        for sp in specs[tok]:
            if sp.get("main"): continue
            S = dict(C)
            S["w"] = {k: float(v) for k, v in (sp.get("weights") or {}).items()}
            S["model"] = sp.get("model") or C["model"]
            if sp.get("weapons"): S["weapons"] = set(sp["weapons"])
            S["shield"] = bool(sp.get("shield"))
            S["kind"] = sp.get("kind")
            picked = pick(S, SPEC_FROM)
            cnt = defaultdict(int)
            for c in picked: cnt[c["slot"]] += 1
            print("%-8s %-14s picked %3d: %s" % (C["name"], sp["name"], len(picked), dict(sorted(cnt.items()))), file=sys.stderr)
            out.append("  %s = {" % sp["key"])
            for c in picked: out.append("  " + entry(c).rstrip("\n"))
            out.append("  },")
        out.append("}")
    with open(os.path.join(addon_dir, 'Classes', 'SpecGear.lua'), "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
