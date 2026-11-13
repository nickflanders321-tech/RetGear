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
# (an entry can come through as a list in a fresh dump: only proper records are used)
FI = {k: v for k, v in fv["items"].items() if isinstance(v, dict)}
FN = {k: v for k, v in fv["npcs"].items() if isinstance(v, dict)}
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
            if (FN.get(str(x), {}).get("rank") or 0) >= 1: found[d][x].add(iid)
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
creatures = {}   # NPC cards with no display id in the data: their creature id (the game looks the model up)
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
        else: creatures[nm] = x
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
            else: creatures[nm] = x
    pools.append((d, IID[d], max(1, lo - 2), hi, pool))

# ---------------------------------------------------------------------------
# WoW Forever's own dungeons. Their creatures have no spawn zone in the quest data (or the zone of the entrance),
# so each is built from the game client's tables: the instance number from Map, the last boss from its Legacy
# challenge criterion, and the other bosses from loot: each boss drops its own run of items, and a dungeon's bosses
# drop neighbouring runs (and have neighbouring creature numbers). Dungeons with no loot in the data yet are left
# out until it arrives.
# ---------------------------------------------------------------------------
soon = []   # WoW Forever dungeons whose bosses and loot aren't in the data yet (the Album shows them as coming soon)
NEW_DUNS = ["The Hall of Thanes", "Ruins of Lordaeron", "Excavation Site: Wetlands", "City of Dalaran", "The Drowned City",
            "Krol'dok Stronghold", "Alcaz Prison", "Blackmaw Hold", "The Shaper's Terrace"]
if wago and os.path.exists(os.path.join(wago, "Map.csv.gz")):
    def _t(n): return list(csv.DictReader(gzip.open(os.path.join(wago, n + ".csv.gz"), "rt", encoding="utf-8")))
    map_id = {r["MapName_lang"]: int(r["ID"]) for r in _t("Map") if r["InstanceType"] == "1"}
    crit = {r["ID"]: r for r in _t("Criteria")}
    final_of = {}
    for r in _t("CriteriaTree"):
        c = crit.get(r["CriteriaID"])
        if c and c["Type"] == "0" and r["Description_lang"] in NEW_DUNS: final_of[r["Description_lang"]] = int(c["Asset"])
    zone_ids = collections.defaultdict(set)
    for m in re.finditer(r'\[(\d+)\] = \{"([^"]+)"', open(qdb + "support/Forever/Zones/dungeons.lua", encoding="utf-8").read()):
        if m.group(2) in NEW_DUNS: zone_ids[m.group(2)].add(int(m.group(1)))
    droppers = collections.defaultdict(list); loot_of = collections.defaultdict(set)
    for iid, f in FI.items():
        for x in L(f.get("npcDrops")): droppers[int(iid)].append(int(x)); loot_of[int(x)].add(int(iid))
    def own(n): return sorted(i for i in loot_of.get(n, ()) if len(droppers[i]) <= 2)   # items only it (or a pair) drops
    taken = set()
    for p in pools:
        for nm in p[4]: taken.add(nm.lower())
    for d in NEW_DUNS:
        iid = map_id.get(d)
        zones = zone_ids.get(d, set())
        seeds = {n for n, v in FN.items() if v.get("zone") in zones and int(n) > 240000 and own(int(n))}
        seeds = {int(n) for n in seeds}
        fb = final_of.get(d)
        if fb and own(fb): seeds.add(fb)
        if not iid or not seeds: print("no loot data yet for", d, file=sys.stderr); soon.append(d); continue
        anchor = fb or min(seeds)
        allowed = zones | {None, 0} | ({FN[str(fb)].get("zone")} if fb and str(fb) in FN else set())
        bosses = set(seeds)
        items = {i for n in bosses for i in own(n)}
        grew = True
        while grew:
            grew = False
            for n, v in FN.items():
                n = int(n)
                if n in bosses or n < 240000 or abs(n - anchor) > 6000 or v.get("zone") not in allowed: continue
                mine = own(n)
                if mine and any(abs(i - j) <= 6 for i in mine for j in items):
                    bosses.add(n); items |= set(mine); grew = True
        if len(bosses) < 2: print("too few bosses for", d, file=sys.stderr); soon.append(d); continue
        # the last boss: its Legacy criterion's, else the one with the highest item numbers
        last = fb if fb in bosses else max(bosses, key=lambda n: max(own(n)))
        req = [int((FI.get(str(i)) or {}).get("reqLevel") or 0) for i in items]
        req = [r for r in req if r > 0]
        lo, hi = (min(req), max(req)) if req else (1, 60)
        pool = []
        card(3, d, 3, 0, ("Dungeon, level %d" % lo) if lo == hi else ("Dungeon, levels %d-%d" % (lo, hi)), pool)
        order = [last] + sorted((n for n in bosses if n != last), key=lambda n: min(own(n)))
        for n in order:
            nm = clean(FN[str(n)]["name"])
            if ok(nm) and nm.lower() not in taken:
                card(2, nm, 4 if n == last else 3, 7, "Dungeon boss, level %d humanoid" % hi, pool)
                if cdisp.get(n): displays[nm] = cdisp[n]
                else: creatures[nm] = n
        shown = 0
        for i in sorted(items):
            nm = clean((FI.get(str(i)) or {}).get("name") or iname.get(i) or "")
            if not nm or not ok(nm) or shown >= 16: continue
            before = len(pool)
            card(1, nm, 2, i, "Rare dungeon drop, required level %d" % int((FI.get(str(i)) or {}).get("reqLevel") or lo), pool)
            if len(pool) > before: shown += 1
        # its regulars: other creatures of the dungeon that drop something
        regs = sorted({int(n) for n, v in FN.items() if v.get("zone") in zones and int(n) > 240000 and int(n) not in bosses and loot_of.get(int(n))})
        nreg = 0
        for n in regs:
            nm = clean(FN[str(n)]["name"])
            if nreg >= 8 or not ok(nm) or nm.lower() in taken: continue
            before = len(pool)
            card(2, nm, 1, 7, "Dungeon elite, level %d humanoid" % max(lo, hi - 1), pool)
            if len(pool) > before:
                nreg += 1
                if cdisp.get(n): displays[nm] = cdisp[n]
                else: creatures[nm] = n
        pools.append((d, iid, lo, hi, pool))
        IID[d] = iid
        print("  %s: instance %d, levels %d-%d, %d bosses, %d cards" % (d, iid, lo, hi, len(bosses), len(pool)), file=sys.stderr)
pools.sort(key=lambda p: (p[2], p[0]))

# WoW Forever's Legacy challenges (Novice, Experienced and Master Spelunker) list each dungeon as its own
# achievement criterion: a cleared one in game unlocks that dungeon's packs, even for clears from before them
LEGACY_NAME = {"Ragefire Chasm or Hall of Thanes": "Ragefire Chasm", "Lower Blackrock Spire": "Blackrock Spire", "Upper Blackrock Spire": "Blackrock Spire"}
legacy = collections.defaultdict(list)
if wago and os.path.exists(os.path.join(wago, "Achievement.csv.gz")):
    def _t(n): return list(csv.DictReader(gzip.open(os.path.join(wago, n + ".csv.gz"), "rt", encoding="utf-8")))
    roots = {r["Criteria_tree"]: int(r["ID"]) for r in _t("Achievement") if r["Title_lang"].endswith("Spelunker")}
    for r in _t("CriteriaTree"):
        if r["Parent"] not in roots or not int(r["CriteriaID"] or 0): continue
        d = r["Description_lang"]
        n = LEGACY_NAME.get(d) or (d if d in IID else d.split(":")[0])   # ("Scarlet Monastery: Library" is a wing; "Excavation Site: Wetlands" a name)
        if n in IID: legacy[n].append((roots[r["Parent"]], int(r["CriteriaID"])))
        # (Ragefire Chasm or Hall of Thanes is one criterion: the Horde and Alliance versions of the first dungeon)
        if d == "Ragefire Chasm or Hall of Thanes" and "The Hall of Thanes" in IID: legacy["The Hall of Thanes"].append((roots[r["Parent"]], int(r["CriteriaID"])))
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
L_.append("-- WoW Forever dungeons with no bosses or loot in the game data yet: the Album shows them as coming soon")
L_.append("RG.ARCADE_DUNGEONS_SOON = { %s }" % ", ".join(q(d) for d in soon))
L_.append("-- Legacy challenge criteria for each dungeon: { achievement id, criteria id } (any one done = cleared)")
L_.append("RG.ARCADE_DUNGEON_LEGACY = {")
for n in sorted(legacy):
    L_.append("  [%s] = { %s }," % (q(n), ", ".join("{ %d, %d }" % x for x in sorted(legacy[n]))))
L_.append("}")
L_.append("-- boss and elite models (shown from the player's own game files), added to ArcadeArt.lua's list")
L_.append("RG.ARCADE_DUNGEON_NPC = {")
for nm in sorted(displays):
    L_.append("  [%s] = %d," % (q(nm), displays[nm]))
L_.append("}")
L_.append("-- NPC cards with no display id in the data: their creature id. The game is asked for the model in the background")
L_.append("-- (Arcade.lua), and the display id it reports is remembered, so these cards show their 3D model like the others")
L_.append("RG.ARCADE_DUNGEON_CREATURE = {")
for nm in sorted(creatures):
    if nm not in displays: L_.append("  [%s] = %d," % (q(nm), creatures[nm]))
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
