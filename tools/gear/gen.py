#!/usr/bin/env python3
"""Build Classes/<Class>Gear.lua for every class: leveling gear upgrades for every slot,
levels 5-60, scored with that class's own stat weights and limited to what it can wear
and wield (both read from Classes/<Class>.lua, so the add-on and this list agree).

Stats come from LibItemDB's scan of the WoW Forever game client when it has the item (--itemdb: WoW Forever's
own items, and Classic items Forever changed), otherwise from the cMaNGOS classic database (item_template + spell_template),
sources from QuestieDB's merged WoW Forever data (quest rewards, dungeon boss drops,
vendors), so only items that exist in Forever and that a Horde character of that class
can get are listed. Crafted gear (Blacksmithing, Leatherworking, Tailoring, Engineering) joins
when it clearly beats everything else by then: its recipe must come from a trainer, a vendor of
your faction, a quest or a dungeon boss (prof = profession, sk = skill, boe = Bind on Equip).

It also builds Classes/SpecGear.lua: for every spec on the 2nd Spec tab (Classes/Specs.lua)
that isn't the class's leveling spec, the gear to start collecting from level 30, scored with
that spec's weights, weapon model and weapons (tanks get shields, defense, dodge, parry, block
and armor; healers get +healing, mp5 and Intellect).

Usage:
  git clone --depth 1 https://github.com/cmangos/classic-db.git /tmp/cdb
  zcat /tmp/cdb/Full_DB/*.sql.gz > /tmp/classic.sql
  lua5.1 dump.lua /tmp/qdb/src/corrections/Forever/combined /tmp/forever_gear.json
  lua5.1 specs_dump.lua <Waypath+ folder> /tmp/specs.json
  git clone --depth 1 -b data/itemdb https://github.com/nickflanders321-tech/RetGear.git /tmp/itemdb   (LibItemDB, MIT)
  git clone --depth 1 -b data/wago https://github.com/nickflanders321-tech/RetGear.git /tmp/wago   (the client's DB2 tables, .github/workflows/fetch-wago.yml)
  python3 gen.py /tmp/classic.sql /tmp/forever_gear.json /tmp/qdb <Waypath+ folder> [Class ...] [--specs /tmp/specs.json] [--itemdb /tmp/itemdb] [--wago /tmp/wago]

With --wago, WoW Forever's own recipes join: the game client's tables say which craft makes which item, which recipe
item teaches it and the skill it needs (a craft no recipe item teaches is learned from the trainer). Where a recipe
comes from is QuestieDB's (vendors, drops, quests), including the Merchant's Favor vendors of the Waylaid Crates
(Durotar Supply and Logistics / Azeroth Commerce Authority).
"""
import json, re, sys
from collections import defaultdict

args = sys.argv[1:]
SPECS_JSON = None
ITEMDB = None
WAGO = None
if "--wago" in args:
    i = args.index("--wago"); WAGO = args[i + 1]; del args[i:i + 2]
if "--itemdb" in args:
    i = args.index("--itemdb"); ITEMDB = args[i + 1]; del args[i:i + 2]
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
want = ["Id", "SpellName", "EffectItemType1", "EffectTriggerSpell1"] + ["EffectApplyAuraName%d" % k for k in (1, 2, 3)] + ["EffectBasePoints%d" % k for k in (1, 2, 3)] + ["EffectMiscValue%d" % k for k in (1, 2, 3)] + ["Effect%d" % k for k in (1, 2, 3)]
idx = [scol.index(w) for w in want]
spells = {}
for r in rows(sql, "spell_template"):
    spells[int(r[idx[0]])] = {w: r[j] for w, j in zip(want, idx)}
# profession trainers: which crafts they teach and at what skill
TRAINER = {}
for t in ("npc_trainer", "npc_trainer_template"):
    tcol = columns(sql, t)
    for r in rows(sql, t):
        d = dict(zip(tcol, r))
        sk, val = int(d["reqskill"] or 0), int(d["reqskillvalue"] or 0)
        if sk: TRAINER.setdefault(int(d["spell"]), (sk, val))
# who sells what (cMaNGOS): adds vendors QuestieDB doesn't list, like reputation quartermasters
VEND = defaultdict(set)
for t in ("npc_vendor", "npc_vendor_template"):
    try: vcol = columns(sql, t)
    except AttributeError: continue
    for r in rows(sql, t):
        dv = dict(zip(vcol, r))
        VEND[int(dv["item"])].add(int(dv["entry"]))
VTEMPLATE = defaultdict(set)   # creatures that use a vendor template
ccol = columns(sql, "creature_template")
if "VendorTemplateId" in ccol:
    for r in rows(sql, "creature_template"):
        dc = dict(zip(ccol, r))
        if int(dc.get("VendorTemplateId") or 0): VTEMPLATE[int(dc["VendorTemplateId"])].add(int(dc["Entry"]))
for it, ents in list(VEND.items()):
    for e in list(ents):
        if e in VTEMPLATE: ents |= VTEMPLATE[e]
del sql
print("items %d, spells %d, trainer crafts %d, vendor items %d" % (len(items), len(spells), len(TRAINER), len(VEND)), file=sys.stderr)

# ---------------------------------------------------------------------------
# WoW Forever's own item data (LibItemDB, from the game client): its stats win, and WoW Forever's own items
# (new zones, scaling quest rewards) join with the fields eligible() and pick() read
# ---------------------------------------------------------------------------
IDB = {}
if ITEMDB:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import itemdb
    IDB = itemdb.load(ITEMDB)
    added = changed = 0
    FACTION_RACES = {"A": 1 | 4 | 8 | 64, "H": 2 | 16 | 32 | 128}
    for iid, it in IDB.items():
        if iid in items:
            d = items[iid]
            d["_idb"] = it
            if it["q"]: d["Quality"] = str(it["q"])
            if it["req"]: d["RequiredLevel"] = str(it["req"])
            changed += 1
            continue
        if it["inv"] == 0: continue
        items[iid] = {"entry": str(iid), "name": it["name"], "class": str(it["cls"]), "subclass": str(it["sub"]),
                      "InventoryType": str(it["inv"]), "Quality": str(it["q"]), "RequiredLevel": str(it["req"]),
                      "ItemLevel": str(it["ilvl"]), "AllowableClass": str(it["classes"] or -1),
                      "AllowableRace": str(FACTION_RACES.get(it["faction"], -1)), "RandomProperty": "0", "requiredhonorrank": "0",
                      "RequiredReputationFaction": "0", "RequiredReputationRank": "0", "bonding": "0", "_idb": it}
        added += 1
    print("LibItemDB (WoW Forever client data): %d items, stats used for %d Classic items, %d WoW Forever items added" % (len(IDB), changed, added), file=sys.stderr)

def _sorted_pairs(kv):
    """Dicts from the Lua dumps come in random order; sort keys (numbers first) so every run picks the same spawn."""
    def k(x):
        s = x[0]
        return (0, int(s), '') if s.lstrip('-').isdigit() else (1, 0, s)
    return dict(sorted(kv, key=k))
fv = json.load(open(json_path), object_pairs_hook=_sorted_pairs)
FI, FN, FQ = fv["items"], fv["npcs"], fv["quests"]
FO = fv.get("objects") or {}

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
# Alliance home zones: no quest rewards, rare mobs or vendors from there for the Horde
ALLIANCE_ZONES = {"Dun Morogh", "Elwynn Forest", "Teldrassil", "Darkshore", "Westfall", "Loch Modan", "Redridge Mountains",
                  "Duskwood", "Stormwind City", "Ironforge", "Darnassus"}
# Horde home zones and Horde-only dungeons: nothing from there for the Alliance
HORDE_ZONES = {"Durotar", "Mulgore", "Tirisfal Glades", "Silverpine Forest", "Orgrimmar", "Thunder Bluff", "Undercity"}
HORDE_FAR_A = {"Ragefire Chasm", "Ruins of Lordaeron", "Krol'dok Stronghold"}
# WoW Forever's new zones (their quests are filed under the zone's sub-areas) and sub-areas of the old ones
_UI = {int(a): int(b) for a, b in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', open(qdb_dir + "/support/Forever/Zones/areaIdToUiMapId.lua").read())}
NEW_ZONE_BY_MAP = {2548: "Riverglades", 2482: "Mount Hyjal", 2652: "Shen'dralas"}
NEW_AREA = {16593: "Zephras Isle", 616: "Mount Hyjal", 16651: "Shen'dralas"}
try:
    PARENT = {int(a): int(b) for a, b in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', open(qdb_dir + "/support/Forever/Zones/subZoneToParentZone.lua").read())}
except OSError: PARENT = {}
def zone_name(z):
    if z is None: return None
    n = DUNGEON.get(z) or AREA.get(z) or NEW_AREA.get(z) or NEW_ZONE_BY_MAP.get(_UI.get(z))
    if not n and z in PARENT: n = DUNGEON.get(PARENT[z]) or AREA.get(PARENT[z]) or NEW_AREA.get(PARENT[z]) or NEW_ZONE_BY_MAP.get(_UI.get(PARENT[z]))
    return n

# ---------------------------------------------------------------------------
# Classes: weights, weapon model and proficiencies come from Classes/<Class>.lua
# ---------------------------------------------------------------------------
def lua_table(src, name):
    # a one-line table first ("P.weapons = { 0, 1, 4 }"), then a multi-line one closed by a "}" line
    m = re.search(r'^\w\.%s = \{([^\n]*)\}[^\n]*$' % name, src, re.M) or re.search(r'^\w\.%s = \{(.*?)^\}' % name, src, re.S | re.M)
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
    if d.get("_idb"): return defaultdict(float, d["_idb"]["stats"])
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
    if d.get("_idb"):
        it = d["_idb"]
        if it["dps"] > 0: return it["dps"], it["speed"] or (int(d.get("delay") or 0) / 1000.0)
        if "delay" not in d: return 0, 0
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
        if sub == 20: return None   # fishing poles are never a weapon upgrade
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
ALLY = 1 | 4 | 8 | 64 | 4294967296       # Human, Dwarf, Night Elf, Gnome, Skyborne (Alliance)
CLASS_BIT = 2   # set per class below
def horde_quest(qid, ally=False):
    q = FQ.get(str(qid))
    if not q or q["name"] in RAID_QUESTS: return None
    races = q.get("races") or 0
    if races and not (int(races) & (ALLY if ally else HORDE)): return None
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
            if n and ("A" if ally else "H") in (n.get("faction") or ""): ok = True
        if not ok: return None
    return q

def sources(iid, ally=False):
    other = HORDE_ZONES if ally else ALLIANCE_ZONES
    far = HORDE_FAR_A if ally else HORDE_FAR
    f = FI.get(str(iid))
    if not f: return []
    out = []
    for qid in L(f.get("questRewards")):
        q = horde_quest(qid, ally)
        if q:
            z = q.get("zone")
            zname = zone_name(z) if isinstance(z, int) and z > 0 else None
            giver = None
            gv, _ = givers_of(q)
            if gv:
                n = FN.get(str(gv[0])); giver = n and n.get("name")
            if zname in other: continue
            out.append({"how": "Quest", "lvl": q.get("level") or q.get("reqLevel") or 0, "req": q.get("reqLevel") or 0,
                        "src": q["name"] + (" (" + giver + ")" if giver else ""), "zone": zname or "", "quest": q["name"], "q": int(qid)})
    drops = L(f.get("npcDrops"))
    # a chest inside a dungeon that holds it (only a few chests: not the random loot of every strongbox in the world)
    objs = L(f.get("objectDrops"))
    if 0 < len(objs) <= 3:
        for oid in objs:
            o = FO.get(str(oid))
            d = o and DUNGEON.get(o.get("zone"))
            if not d or d in RAIDS or d in far: continue
            out.append({"how": "Chest", "lvl": 0, "src": o["name"], "zone": d})
            break
    if 0 < len(drops) <= 4:
        for nid in drops:
            n = FN.get(str(nid))
            if not n: continue
            z = n.get("zone")
            d = DUNGEON.get(z)
            if d:
                if d in RAIDS or d in far: continue
                if (n.get("rank") or 0) < 1: continue
                out.append({"how": "Dungeon", "lvl": n.get("maxLevel") or 0, "src": n["name"], "zone": d, "bl": n.get("maxLevel") or 0})
            elif (n.get("rank") or 0) in (1, 2, 4) and len(drops) <= 2 and AREA.get(z) and AREA.get(z) not in other:
                out.append({"how": "Rare mob", "lvl": n.get("maxLevel") or 0, "src": n["name"], "zone": zone_name(z) or "", "bl": n.get("maxLevel") or 0})
    d = items.get(int(iid)) or {}
    # a blue or purple Bind on Equip piece many mobs drop: not something to farm, but anyone can sell it on the
    # Auction House (not raid trash: everything that drops it must be outside the raids)
    if len(drops) > 4 and str(d.get("bonding")) == "2" and int(d.get("Quality") or 0) >= 3:
        zs = [FN.get(str(n), {}).get("zone") for n in drops]
        if not any(z in RAID_ZONES or DUNGEON.get(z) in RAIDS for z in zs):
            out.append({"how": "BoE", "lvl": 0, "src": "World drop", "zone": "Auction House"})
    rep_rank = int(d.get("RequiredReputationRank") or 0) if int(d.get("RequiredReputationFaction") or 0) else 0
    for vid in sorted(set(int(v) for v in L(f.get("vendors"))) | VEND.get(int(iid), set())):
        n = FN.get(str(vid))
        sub = (n.get("sub") or "") if n else ""
        if not (n and ("A" if ally else "H") in (n.get("faction") or "") and (zone_name(n.get("zone")) or "") not in other): continue
        # PvP: ranks and battleground reputations are not leveling gear
        if re.search(r"Legionnaire|Battlemaster|Supply Officer|Frostwolf|Warsong|Defilers|League of Arathor|Stormpike|Silverwing", sub): continue
        if rep_rank or re.search(r"Quartermaster", sub):
            # a reputation reward: bought once you're friendly enough with them
            if not rep_rank: continue
            out.append({"how": "Reputation", "lvl": 0, "src": n["name"], "zone": (sub or "Quartermaster") + " · " + REP_RANK.get(rep_rank, "Friendly") + " · " + (zone_name(n.get("zone")) or "")})
        else:
            out.append({"how": "Vendor", "lvl": 0, "src": n["name"], "zone": zone_name(n.get("zone")) or ""})
    return out
REP_RANK = {3: "Neutral", 4: "Friendly", 5: "Honored", 6: "Revered", 7: "Exalted"}

# ---------------------------------------------------------------------------
# Crafted gear: what the gear professions make, the skill it takes and where the recipe comes from
# (a trainer, a vendor of your faction, a quest, or a dungeon boss; recipes that are only a rare
# world drop are left out, since nobody can plan on them)
# ---------------------------------------------------------------------------
PROF = {164: "Blacksmithing", 165: "Leatherworking", 197: "Tailoring", 202: "Engineering", 333: "Enchanting"}
# The Merchant's Favor recipe vendors (Waylaid Crates): Horde at the Crossroads, Alliance at Three Corners (Redridge).
# What a recipe costs there and the standing it needs, by profession and skill (method.gg and wowhandbook.com,
# November 2026: "Azeroth Commerce Authority and Durotar Supply and Logistics Reputation Guide", "Merchant's Favor")
MF_VENDORS = {248197, 248201, 248202, 248199, 248200, 256730, 256734, 256735, 256732, 256733}
MF_PRICE = {   # profession: [(highest skill, favor, standing), ...]
    "Blacksmithing": [(125, 30, None), (210, 60, "Friendly"), (250, 90, "Honored"), (300, 120, "Honored")],
    "Leatherworking": [(125, 30, None), (210, 60, "Friendly"), (300, 90, "Honored")],
    "Tailoring": [(125, 30, None), (215, 60, "Friendly"), (300, 90, "Honored")],
    "Enchanting": [(140, 45, None), (220, 120, "Friendly"), (275, 180, "Honored"), (300, 240, "Honored")],
    "Engineering": [(145, 45, None), (200, 180, "Friendly"), (285, 270, "Honored"), (300, 360, "Honored")],
}
def mf_note(prof, sk):
    for top, cost, rank in MF_PRICE.get(prof, []):
        if sk <= top: return "%d favor%s" % (cost, (" at " + rank) if rank else "")
    return "Merchant's Favor"
FR = fv.get("recipes") or {}
def craft_of(spell_id, depth=0):
    """The item a spell makes, following 'learn' spells to the craft they teach."""
    sp = spells.get(spell_id)
    if not sp or depth > 2: return None
    if int(sp["Effect1"]) == 24 and int(sp["EffectItemType1"] or 0): return int(sp["EffectItemType1"])
    if int(sp["Effect1"]) == 36 and int(sp["EffectTriggerSpell1"] or 0): return craft_of(int(sp["EffectTriggerSpell1"]), depth + 1)
    return None
CRAFT = defaultdict(list)   # item made -> [ {prof, sk, spec, rec, recA(lliance-ok), recH} ]
for sid, (sk, val) in TRAINER.items():
    it = craft_of(sid)
    if it and sk in PROF: CRAFT[it].append({"prof": PROF[sk], "sk": val, "spec": None, "rec": "Trainer", "H": True, "A": True})
def recipe_source(rid, ally, prof=None, sk=0):
    f = FR.get(str(rid))
    if not f: return None
    other = HORDE_ZONES if ally else ALLIANCE_ZONES
    for vid in L(f.get("vendors")):
        n = FN.get(str(vid))
        # (not reputation quartermasters: those plans take raid materials or exalted standing)
        if n and ("A" if ally else "H") in (n.get("faction") or "") and (zone_name(n.get("zone")) or "") not in other \
           and not re.search(r"Quartermaster|Supply Officer|Brotherhood|Argent Dawn|Cenarion|Zandalar|Timbermaw|Brood", n.get("sub") or ""):
            z = zone_name(n.get("zone"))
            if int(vid) in MF_VENDORS:   # Waylaid Crates: paid in Merchant's Favor
                return "Merchant's Favor: " + n["name"] + (" (" + z + ")" if z else "") + " · " + mf_note(prof, sk)
            return "Vendor: " + n["name"] + (" (" + z + ")" if z else "")
    for qid in L(f.get("questRewards")):
        q = horde_quest(qid, ally)
        if q: return "Quest: " + q["name"]
    drops = L(f.get("npcDrops"))
    if 0 < len(drops) <= 3:
        for nid in drops:
            n = FN.get(str(nid))
            d = n and DUNGEON.get(n.get("zone"))
            if d and d not in RAIDS and (n.get("rank") or 0) >= 1: return "Dungeon: " + n["name"] + " (" + d + ")"
    return None
for rid, d in items.items():
    if int(d["class"]) != 9: continue
    sk = int(d["RequiredSkill"] or 0)
    if sk not in PROF: continue
    made = None
    for k in range(1, 6):
        sid = int(d["spellid_%d" % k] or 0)
        if sid and sid != 483: made = made or craft_of(sid)
    if not made: continue
    spec = int(d.get("requiredspell") or 0)
    spec_name = spells[spec]["SpellName"] if spec in spells else None
    CRAFT[made].append({"prof": PROF[sk], "sk": int(d["RequiredSkillRank"] or 0), "spec": spec_name, "rid": rid})
# WoW Forever's own crafts, from the game client's tables (--wago)
WAGO_CRAFTS = 0
if WAGO:
    import csv, gzip
    def _wago(name):
        path = os.path.join(WAGO, name + ".csv")
        fh = open(path, encoding="utf-8") if os.path.exists(path) else gzip.open(path + ".gz", "rt", encoding="utf-8")
        return csv.DictReader(fh)
    makes = defaultdict(set)                     # craft spell -> items it creates
    for r in _wago("SpellEffect"):
        if r["Effect"] == "24" and int(r["EffectItemType"] or 0): makes[int(r["SpellID"])].add(int(r["EffectItemType"]))
    effect_spell = {r["ID"]: int(r["SpellID"] or 0) for r in _wago("ItemEffect")}
    item_class = {int(r["ID"]): int(r["ClassID"] or 0) for r in _wago("Item")}
    sparse = {int(r["ID"]): r for r in _wago("ItemSparse")}
    taught_by = defaultdict(list)                # craft spell -> recipe items that teach it
    for r in _wago("ItemXItemEffect"):
        it = int(r["ItemID"])
        if item_class.get(it) == 9: taught_by[effect_spell.get(r["ItemEffectID"], 0)].append(it)
    for it, r in sparse.items():               # the client knows each item's binding
        if it in items and items[it].get("_idb") and int(r.get("Bonding") or 0): items[it]["bonding"] = str(r["Bonding"])
    for r in _wago("SkillLineAbility"):
        sk_line, spell = int(r["SkillLine"] or 0), int(r["Spell"] or 0)
        if sk_line not in PROF: continue
        for made in makes.get(spell, ()):
            if made not in items: continue
            known = CRAFT.get(made, [])
            recs = [rid for rid in taught_by.get(spell, []) if int(sparse.get(rid, {}).get("RequiredSkill") or 0) == sk_line]
            if recs:
                for rid in recs:
                    if any(c.get("rid") == rid for c in known): continue
                    CRAFT[made].append({"prof": PROF[sk_line], "sk": int(sparse[rid].get("RequiredSkillRank") or 0), "spec": None, "rid": rid})
                    WAGO_CRAFTS += 1
            elif int(r["MinSkillLineRank"] or 0) > 1 and not any(c.get("rec") == "Trainer" for c in known):
                # no recipe item teaches it: the trainer does
                CRAFT[made].append({"prof": PROF[sk_line], "sk": int(r["MinSkillLineRank"]), "spec": None, "rec": "Trainer", "H": True, "A": True})
                WAGO_CRAFTS += 1
    print("wago (WoW Forever client tables): %d more ways to craft gear" % WAGO_CRAFTS, file=sys.stderr)
def craft_source(iid, ally=False):
    """The easiest way to learn to make this item, or None."""
    best = None
    for c in CRAFT.get(iid, []):
        if c.get("rid"):
            rec = recipe_source(c["rid"], ally, c["prof"], c["sk"])
            if not rec: continue
        else: rec = c["rec"]
        cand = dict(c, rec=rec)
        if not best or (cand["rec"] == "Trainer") > (best["rec"] == "Trainer") or cand["sk"] < best["sk"]: best = cand
    if not best: return None
    d = items[iid]
    boe = int(d["bonding"]) != 1
    return {"how": "Crafted", "lvl": 0, "src": best["prof"] + (" (" + best["spec"] + ")" if best["spec"] else ""),
            "zone": ("Bind on Equip" if boe else "Bind on Pickup") + " · " + best["rec"],
            "prof": best["prof"], "sk": best["sk"], "boe": boe}

# ---------------------------------------------------------------------------
# Pick the upgrades, class by class
# ---------------------------------------------------------------------------
def lua_str(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
ORDER = {"Quest": 0, "Dungeon": 1, "Vendor": 2, "Chest": 3, "Rare mob": 4, "Reputation": 5, "Crafted": 6, "BoE": 7}
EXTRA = ("Crafted", "BoE")   # only listed when clearly better than what your route gives
src_cache = {}
# The Gear tab's "best from each source" view: every source falls in one of these groups
SRC_GROUP = {"Quest": "Quest", "Dungeon": "Dungeon", "Crafted": "Crafted", "BoE": "BoE"}
SRC_GROUPS = ("Quest", "Dungeon", "Crafted", "BoE", "Other")
# Weapon setups a leveling character can pick on the Gear tab besides the class's own (Classes/<Class>.lua
# model): two weapons, or a one-hander and a shield. Their weapon lists are generated with that setup's scoring.
SETUPS = {"WARRIOR": ("DW", "SB"), "PALADIN": ("SB",), "SHAMAN": ("SB",), "HUNTER": ("DW",)}
SETUP_MODEL = {"DW": "DW", "SB": "tank"}
WEAPON_SLOTS = {"2H", "Main Hand", "Off Hand"}

def pick(C, lvl_from=5, ally=False, only_slots=None, alts=True):
    """The upgrade path for every slot plus the best quest reward and dungeon drop per
    5-level window, from lvl_from to 60. alts: also the best piece from each kind of source per
    window (marked alt, for the Gear tab's by-source view)."""
    global CLASS_BIT
    CLASS_BIT = C["bit"]
    cands = defaultdict(list)
    for iid, d in items.items():
        slot = eligible(d, C)
        if not slot: continue
        if only_slots and slot not in only_slots: continue
        key = (iid, CLASS_BIT, ally)
        if key not in src_cache: src_cache[key] = sources(iid, ally)
        src = [dict(x) for x in src_cache[key]]
        ck = ("craft", iid, ally)
        if ck not in src_cache: src_cache[ck] = craft_source(iid, ally) if str(iid) in FI else None
        craft = src_cache[ck]
        if craft and src: src.append(dict(craft))       # also craftable: shown as another source
        if not src and craft: src = [dict(craft)]
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
                            "prof": s0.get("prof"), "sk": s0.get("sk"), "boe": s0.get("boe"),
                            "also": [x for x in src[1:3] if x["how"] != "Crafted"]})
    picked = []
    start = (lvl_from // 5) * 5
    for slot, all_c in cands.items():
        all_c.sort(key=lambda c: (c["lvl"], -c["score"]))
        lst = [c for c in all_c if c["how"] not in EXTRA]
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
        # 3) crafted gear and Auction House world drops, only when they clearly beat everything else you can get by
        #    then (15% or more) and the last such piece picked for the slot (10%), so they don't crowd out your
        #    route's rewards
        for how in EXTRA:
            best_x = 0
            for c in all_c:
                if c["how"] != how: continue
                other = max([x["score"] for x in lst if x["lvl"] <= c["lvl"]] or [0])
                if c["score"] > other * 1.15 and c["score"] > best_x * 1.10:
                    by_id[c["id"]] = c; best_x = c["score"]
        picked += [c for c in by_id.values() if c["lvl"] >= lvl_from - 2]
        # 4) the best piece from each kind of source per 5-level window (the Gear tab's by-source view)
        if alts:
            extra = {}
            for lo in range(start, 61, 5):
                win = [c for c in all_c if lo <= c["lvl"] < lo + 5]
                for grp in SRC_GROUPS:
                    w = [c for c in win if SRC_GROUP.get(c["how"], "Other") == grp]
                    if not w: continue
                    top = max(w, key=lambda c: c["score"])
                    if top["id"] not in by_id and top["id"] not in extra and top["lvl"] >= lvl_from - 2:
                        extra[top["id"]] = dict(top, alt=True)
            picked += list(extra.values())
    picked.sort(key=lambda c: (c["lvl"], c["slot"]))
    return picked

def entry(c):
    extra = ""
    if c.get("q"): extra += ", q = %d" % c["q"]
    if c.get("bl"): extra += ", bl = %d" % c["bl"]
    if c.get("prof"):
        extra += ", prof = %s, sk = %d" % (lua_str(c["prof"]), c["sk"] or 0)
        if c.get("boe"): extra += ", boe = true, ah = true"
    elif c["how"] == "BoE": extra += ", ah = true"
    # other places it comes from (a second quest, a dungeon boss, a vendor)
    also = []
    for x in c.get("also") or []:
        if x["how"] == c["how"] and x["src"] == c["src"]: continue
        also.append("{ how = %s, src = %s, zone = %s%s%s }" % (lua_str(x["how"]), lua_str(x["src"]), lua_str(x.get("zone") or ""),
                    (", q = %d" % x["q"]) if x.get("q") else "", (", bl = %d" % x["bl"]) if x.get("bl") else ""))
    if also: extra += ", also = { " + ", ".join(also) + " }"
    if c.get("alt"): extra += ", alt = true"
    if c.get("ws"): extra += ", ws = %s" % lua_str(c["ws"])
    return "  { id = %d, slot = %s, lvl = %d, how = %s, src = %s, zone = %s, score = %d%s, gen = true },  -- %s\n" % (
        c["id"], lua_str(c["slot"]), c["lvl"], lua_str(c["how"]), lua_str(c["src"]), lua_str(c["zone"] or ""), round(c["score"]), extra, c["name"])

CLASSES = {}
for path in sorted(glob.glob(os.path.join(addon_dir, 'Classes', '*.lua'))):
    if path.endswith('Gear.lua') or path.endswith('Specs.lua'): continue
    C = read_class(path)
    CLASSES[C["tok"]] = C
    if ONLY and C["name"] not in ONLY and C["tok"] not in ONLY: continue
    picked = pick(C)
    picked_a = pick(C, ally=True)
    # weapon lists for the other weapon setups the Gear tab offers this class
    for setup in SETUPS.get(C["tok"], ()):
        C2 = dict(C, model=SETUP_MODEL[setup], shield=(setup == "SB"))
        for lst, ally in ((picked, False), (picked_a, True)):
            ws = [dict(c, ws=setup) for c in pick(C2, ally=ally, only_slots=WEAPON_SLOTS) if c["slot"] in MODEL_SLOTS[C2["model"]]]
            lst += ws
            lst.sort(key=lambda c: (c["lvl"], c["slot"]))
    cnt = defaultdict(int)
    for c in picked: cnt[c["slot"]] += 1
    print("%-8s %-14s picked %3d (Alliance %3d): %s" % (C["name"], C["spec"], len(picked), len(picked_a), dict(sorted(cnt.items()))), file=sys.stderr)
    out_path = os.path.join(addon_dir, 'Classes', C["name"] + 'Gear.lua')
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("-- GENERATED by tools/gear/gen.py: do not edit by hand.\n")
        f.write("-- %s %s upgrades for every slot, levels 5-60: quest rewards a %s can get,\n" % (C["spec"], C["name"].lower(), C["name"].lower()))
        f.write("-- dungeon boss drops, and vendors, scored with Classes/%s.lua's weights. CLASS_GEAR is for the Horde, CLASS_GEAR_A for the Alliance.\n" % C["name"])
        f.write("-- Stats: cMaNGOS classic DB; sources: QuestieDB merged Forever data.\n")
        f.write("local _, RG = ...\n")
        f.write("RG.CLASS_GEAR = RG.CLASS_GEAR or {}\n")
        f.write("RG.CLASS_GEAR.%s = {\n" % C["tok"])
        for c in picked: f.write(entry(c))
        f.write("}\n")
        f.write("RG.CLASS_GEAR_A = RG.CLASS_GEAR_A or {}\n")
        f.write("RG.CLASS_GEAR_A.%s = {\n" % C["tok"])
        for c in picked_a: f.write(entry(c))
        f.write("}\n")

# ---------------------------------------------------------------------------
# 2nd specs: gear to collect from level 30 for every other spec
# ---------------------------------------------------------------------------
SPEC_FROM = 30
if SPECS_JSON:
    specs = json.load(open(SPECS_JSON))
    out = ["-- GENERATED by tools/gear/gen.py --specs: do not edit by hand.",
           "-- Gear to start collecting for every 2nd spec (Classes/Specs.lua), levels %d-60: quest rewards" % SPEC_FROM,
           "-- a character of that class can get, dungeon boss drops and vendors, scored with",
           "-- the spec's own weights. SPEC_GEAR is for the Horde, SPEC_GEAR_A for the Alliance.",
           "-- Stats: cMaNGOS classic DB; sources: QuestieDB merged Forever data.",
           "-- Leveling specs use their class's gear guide instead (Classes/<Class>Gear.lua).",
           "local _, RG = ..."]
    for var, ally in (("RG.SPEC_GEAR", False), ("RG.SPEC_GEAR_A", True)):
        out.append("%s = %s or {}" % (var, var))
        for tok in sorted(specs):
            C = CLASSES.get(tok)
            if not C: continue
            out.append("%s.%s = {" % (var, tok))
            for sp in specs[tok]:
                if sp.get("main"): continue
                S = dict(C)
                S["w"] = {k: float(v) for k, v in (sp.get("weights") or {}).items()}
                S["model"] = sp.get("model") or C["model"]
                if sp.get("weapons"): S["weapons"] = set(sp["weapons"])
                S["shield"] = bool(sp.get("shield"))
                S["kind"] = sp.get("kind")
                picked = pick(S, SPEC_FROM, ally, alts=False)
                cnt = defaultdict(int)
                for c in picked: cnt[c["slot"]] += 1
                print("%-8s %-14s %s picked %3d: %s" % (C["name"], sp["name"], "Alliance" if ally else "Horde", len(picked), dict(sorted(cnt.items()))), file=sys.stderr)
                out.append("  %s = {" % sp["key"])
                for c in picked: out.append("  " + entry(c).rstrip("\n"))
                out.append("  },")
            out.append("}")
    with open(os.path.join(addon_dir, 'Classes', 'SpecGear.lua'), "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
