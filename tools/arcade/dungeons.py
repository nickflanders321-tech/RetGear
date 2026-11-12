"""Dungeon packs for the card game -> ArcadeDungeons.lua.

  python3 tools/arcade/dungeons.py <classic.sql> <forever_gear.json> <qdb dir> <addon dir> [--wago <dir>]

One card pool per levelling dungeon, from the game data:
  - the dungeon itself (a place card)
  - its bosses: elites in the dungeon that drop blue or purple items only a few creatures drop (the last and
    highest boss is the dungeon's top card)
  - those boss drops (blue and purple)
  - a few of its elite regulars (the common cards)
Cards that already exist in ArcadeCards.lua (by name) are reused, not repeated. New cards are appended to the
card list after every other card, so the numbers of the existing cards (deck codes use them) never move.
"""
import gzip, csv, io, json, os, re, sys, collections

args = sys.argv[1:]
wago = None
if "--wago" in args:
    i = args.index("--wago"); wago = args[i + 1]; del args[i:i + 2]
sql_path, json_path, qdb, addon = args[:4]
if not qdb.endswith('/'): qdb += '/'

# the SQL reader from gen.py (same parser)
src = open(os.path.join(os.path.dirname(__file__), 'gen.py'), encoding='utf-8').read()
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
quality, ilevel, iname = {}, {}, {}
for e, n, q, il in rows('item_template', ['entry', 'name', 'Quality', 'ItemLevel']):
    quality[int(e)] = int(q); ilevel[int(e)] = int(il); iname[int(e)] = clean(n)
# WoW Forever's own items (and its changes): the game client's item table
if wago:
    with gzip.open(os.path.join(wago, "ItemSparse.csv.gz"), "rt", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            i = int(r["ID"])
            quality[i] = int(r["OverallQualityID"] or 0); ilevel[i] = int(r["ItemLevel"] or 0)
            if r.get("Display_lang"): iname[i] = clean(r["Display_lang"])

def _sorted_pairs(kv):
    def k(x):
        s = x[0]
        return (0, int(s), '') if s.lstrip('-').isdigit() else (1, 0, s)
    return dict(sorted(kv, key=k))
fv = json.load(open(json_path), object_pairs_hook=_sorted_pairs)
FI, FN = fv["items"], fv["npcs"]
def L(v):
    if v is None: return []
    if isinstance(v, dict): return [v[k] for k in sorted(v, key=lambda x: int(x))]
    return v

# the levelling dungeons, by the names the add-on uses in game (Core.lua INSTANCE_EN)
DUNS = ["Ragefire Chasm", "Wailing Caverns", "The Deadmines", "Shadowfang Keep", "The Stockade", "Blackfathom Deeps", "Gnomeregan",
        "Razorfen Kraul", "Scarlet Monastery", "Razorfen Downs", "Uldaman", "Zul'Farrak", "Maraudon", "The Temple of Atal'Hakkar",
        "Blackrock Depths", "Blackrock Spire", "Dire Maul", "Stratholme", "Scholomance"]
IID = {"Ragefire Chasm": 389, "Wailing Caverns": 43, "The Deadmines": 36, "Shadowfang Keep": 33, "The Stockade": 34, "Blackfathom Deeps": 48,
       "Gnomeregan": 90, "Razorfen Kraul": 47, "Scarlet Monastery": 189, "Razorfen Downs": 129, "Uldaman": 70, "Zul'Farrak": 209,
       "Maraudon": 349, "The Temple of Atal'Hakkar": 109, "Blackrock Depths": 230, "Blackrock Spire": 229, "Dire Maul": 429,
       "Stratholme": 329, "Scholomance": 289}
zone_dun = {}
for m in re.finditer(r'\[(\d+)\] = \{"([^"]+)",(?:\{([\d,]*)\}|nil)', open(qdb + "support/Forever/Zones/dungeons.lua", encoding="utf-8").read()):
    if m.group(2) in DUNS:
        zone_dun[int(m.group(1))] = m.group(2)
        for a in (m.group(3) or "").split(","):
            if a: zone_dun[int(a)] = m.group(2)

# cards that exist already
existing = {}
for kind, name, tier, text in re.findall(r'^\s*\{ (\d), "((?:[^"\\]|\\.)*)", (\d), \d+, "((?:[^"\\]|\\.)*)" \},', open(os.path.join(addon, "ArcadeCards.lua"), encoding="utf-8").read(), re.M):
    existing[name.replace('\\"', '"').lower()] = name.replace('\\"', '"')

npc_dun = {}
for nid, n in FN.items():
    d = zone_dun.get(n.get("zone"))
    if d: npc_dun[int(nid)] = d
# boss loot: blue or better, dropped by at most 4 creatures, all of them in the same dungeon
# (Ragefire Chasm drops only greens: a dungeon with no blue boss loot is read again with greens)
def find_bosses(min_q):
    found = collections.defaultdict(lambda: collections.defaultdict(set))   # dungeon -> npc -> items
    for iid, f in FI.items():
        iid = int(iid)
        drops = [int(x) for x in L(f.get("npcDrops"))]
        if not (0 < len(drops) <= 4) or quality.get(iid, 0) < min_q: continue
        ds = {npc_dun.get(x) for x in drops}
        if len(ds) != 1 or None in ds: continue
        d = ds.pop()
        for x in drops:
            if (FN[str(x)].get("rank") or 0) >= 1: found[d][x].add(iid)
    return found
boss_items = find_bosses(3)
greens = find_bosses(2)
for d in DUNS:
    if not boss_items.get(d) and greens.get(d): boss_items[d] = greens[d]

out_rows, pools, seen = [], [], set(existing)
def card(kind, name, tier, ref, text, pool):
    k = name.lower()
    if k in existing:
        pool.append(existing[k]); return
    if k in seen: return
    seen.add(k); out_rows.append((kind, name, tier, ref, text)); pool.append(name)
displays = {}
for d in DUNS:
    bosses = boss_items.get(d, {})
    if not bosses: print("no bosses found for", d, file=sys.stderr); continue
    blist = sorted(bosses, key=lambda x: (-(FN[str(x)].get("maxLevel") or 0), -len(bosses[x]), FN[str(x)]["name"]))
    levels = [FN[str(x)].get("maxLevel") or 0 for x in blist]
    lo, hi = min(levels), max(levels)
    pool = []
    card(3, d, 3, 0, "Dungeon, levels %d-%d" % (max(1, lo - 2), hi), pool)
    for i, x in enumerate(blist):
        n = FN[str(x)]
        nm = clean(n["name"])
        if not ok(nm): continue
        ty = TYPE.get(ctype.get(x, 7), "humanoid")
        card(2, nm, 4 if i == 0 else 3, ctype.get(x, 7), "Dungeon boss, level %d %s" % (n.get("maxLevel") or 0, ty), pool)
        if cdisp.get(x): displays[nm] = cdisp[x]
    # the loot: every purple, and the best blues
    loot = sorted({i for s in bosses.values() for i in s}, key=lambda i: (-quality.get(i, 0), -ilevel.get(i, 0), iname.get(i, "")))
    blues = 0
    for i in loot:
        nm = iname.get(i) or (FI.get(str(i)) or {}).get("name")
        if not nm or not ok(nm): continue
        q = quality.get(i, 3)
        if q <= 3:
            if blues >= 16: continue
            blues += 1
        card(1, nm, 4 if q >= 4 else (2 if q == 3 else 1), i, "%s dungeon drop, item level %d" % ({4: "Epic", 3: "Rare"}.get(q, "Uncommon") if q < 5 else "Legendary", ilevel.get(i, 0)), pool)
    # the regulars: elites living there that aren't bosses
    regs = sorted({(clean(FN[str(x)]["name"]), x) for x, dd in npc_dun.items() if dd == d and (FN[str(x)].get("rank") or 0) == 1 and x not in bosses},
                  key=lambda t: (-(FN[str(t[1])].get("maxLevel") or 0), t[0]))
    nreg = 0
    for nm, x in regs:
        if nreg >= 8 or not ok(nm): continue
        before = len(pool)
        card(2, nm, 1, ctype.get(x, 7), "Dungeon elite, level %d %s" % (FN[str(x)].get("maxLevel") or 0, TYPE.get(ctype.get(x, 7), "humanoid")), pool)
        if len(pool) > before:
            nreg += 1
            if cdisp.get(x): displays[nm] = cdisp[x]
    pools.append((d, IID[d], max(1, lo - 2), hi, pool))
pools.sort(key=lambda p: (p[2], p[0]))

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
L_ = ["-- GENERATED by tools/arcade/dungeons.py: do not edit by hand.",
      "-- Dungeon packs: each levelling dungeon's own cards (the place, its bosses, their drops and its elites), from the game",
      "-- data. New cards go after every other card ({ kind, name, tier, ref, text } like ArcadeCards.lua), so existing card",
      "-- numbers never move.",
      "local _, RG = ...",
      "RG.ARCADE_DATA = RG.ARCADE_DATA or {}",
      "RG.ARCADE_DUNGEON_ROWS = {"]
for kind, name, tier, ref, text in out_rows:
    L_.append("  { %d, %s, %d, %d, %s }," % (kind, q(name), tier, ref, q(text)))
L_.append("}")
L_.append("-- { name, instance id, lowest level, highest level, { card names } }, easiest first")
L_.append("RG.ARCADE_DUNGEONS = {")
for d, iid, lo, hi, pool in pools:
    L_.append("  { %s, %d, %d, %d, { %s } }," % (q(d), iid, lo, hi, ", ".join(q(n) for n in pool)))
L_.append("}")
L_.append("-- boss and elite models (shown from the player's own game files), added to ArcadeArt.lua's list")
L_.append("RG.ARCADE_DUNGEON_NPC = {")
for nm in sorted(displays):
    L_.append("  [%s] = %d," % (q(nm), displays[nm]))
L_.append("}")
L_ += ["-- join the card list: each new card after every other card, marked with its dungeon (it is only in that",
       "-- dungeon's packs); reused cards stay where they are and are in the dungeon's set as well",
       "local owner = {}",
       "RG.ARCADE_DUNGEON_OF = owner   -- every card in a dungeon's pack -> that dungeon",
       "for _, d in ipairs(RG.ARCADE_DUNGEONS) do for _, n in ipairs(d[5]) do owner[n] = owner[n] or d[1] end end",
       "for _, r in ipairs(RG.ARCADE_DUNGEON_ROWS) do r[6] = owner[r[2]]; RG.ARCADE_DATA[#RG.ARCADE_DATA + 1] = r end",
       "RG.ARCADE_NPC = RG.ARCADE_NPC or {}",
       "for k, v in pairs(RG.ARCADE_DUNGEON_NPC) do if not RG.ARCADE_NPC[k] then RG.ARCADE_NPC[k] = v end end"]
open(os.path.join(addon, "ArcadeDungeons.lua"), "w", encoding="utf-8").write("\n".join(L_) + "\n")
print("dungeon cards: %d new, %d dungeons, pool sizes %s" % (len(out_rows), len(pools), [len(p[4]) for p in pools]), file=sys.stderr)
