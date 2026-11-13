"""Raid packs for the card game -> ArcadeRaids.lua.

  python3 tools/arcade/raids.py <classic.sql> <forever_gear.json> <qdb dir> <wago dir> <addon dir>

WoW Forever's raids (The Barrow Deeps, Hyjal Summit, Onyxia's Lair), from the game client's own tables:
  - the bosses: each raid's "Conqueror" achievement lists its encounters (name and creature); a raid's top card is
    its last boss (the one with its own kill statistic, else the achievement's first)
  - their loot, once the quest data has it (blue and purple items those bosses drop)
  - the raid's elites, and its key (the attunement item) as a card you earn by being attuned
  - the encounter ids, once the client's DungeonEncounter table has them (kills are matched by name until then)
Raids join the dungeon list (same packs, Album pages and set stages); new cards go after every other card.
"""
import csv, gzip, json, os, re, sys, collections

sql_path, json_path, qdb, wago, addon = sys.argv[1:6]
if not qdb.endswith('/'): qdb += '/'
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, 'gen.py'), encoding='utf-8').read()
head = src[:src.index("cards, seen = [], set()")]
saved = sys.argv; sys.argv = ['gen.py', sql_path, qdb, addon]
ns = {}; exec(head, ns); sys.argv = saved
rows, clean, ok = ns['rows'], ns['clean'], ns['ok']

TYPE = {1: "beast", 2: "dragonkin", 3: "demon", 4: "elemental", 5: "giant", 6: "undead", 7: "humanoid", 8: "critter", 9: "mechanical"}
ctype, cdisp = {}, {}
for e, ct, m in rows('creature_template', ['Entry', 'CreatureType', 'ModelId1']):
    ctype[int(e)] = int(ct or 0); cdisp[int(e)] = int(m or 0)
fv = json.load(open(json_path))
FN = {int(k): v for k, v in fv["npcs"].items() if isinstance(v, dict)}
FI = {int(k): v for k, v in fv["items"].items() if isinstance(v, dict)}
def tab(n):
    p = os.path.join(wago, n + ".csv.gz")
    return list(csv.DictReader(gzip.open(p, "rt", encoding="utf-8"))) if os.path.exists(p) else []
quality, ilevel, iname = {}, {}, {}
for e, n, qq, il in rows('item_template', ['entry', 'name', 'Quality', 'ItemLevel']):
    quality[int(e)] = int(qq); ilevel[int(e)] = int(il); iname[int(e)] = clean(n)
for r in tab("ItemSparse"):
    i = int(r["ID"]); quality[i] = int(r["OverallQualityID"] or 0); ilevel[i] = int(r["ItemLevel"] or 0)
    if r.get("Display_lang"): iname[i] = clean(r["Display_lang"])

# name, size, where, achievement title, opening day, the attunement (key item and the quests that give it), frame art
RAIDS = [
    ("The Barrow Deeps", 10, "Mount Hyjal", "Conqueror of the Deeps", "2026-12-09", None, "RaidBarrow", ["Barrow Deeps"]),
    ("Hyjal Summit", 20, "Mount Hyjal", "Conqueror of the Wilds", "2026-12-09", None, "RaidHyjal", []),
    ("Onyxia's Lair", 40, "Dustwallow Marsh", "Conqueror of the Lair", "2026-12-09", (16309, [6502, 6602]), "RaidOnyxia", []),
]
ach = tab("Achievement"); crit = {r["ID"]: r for r in tab("Criteria")}; tree = tab("CriteriaTree")
kids = collections.defaultdict(list)
for r in tree: kids[r["Parent"]].append(r)
stat_boss = {}   # raid -> creature with its own "kills (Raid)" statistic
for a in ach:
    m = re.match(r"^(.+) kills \((.+)\)$", a["Title_lang"])
    if m:
        for r in kids.get(a["Criteria_tree"], []):
            c = crit.get(r["CriteriaID"])
            if c and c["Type"] == "0": stat_boss[m.group(2)] = int(c["Asset"])
maps = {r["MapName_lang"]: int(r["ID"]) for r in tab("Map")}
enc = collections.defaultdict(list)
for r in tab("DungeonEncounter"): enc[int(r["MapID"] or 0)].append((int(r["ID"]), clean(r["Name_lang"])))

existing = {}
for f in ("ArcadeCards.lua", "ArcadeDungeons.lua", "ArcadeField.lua"):
    p = os.path.join(addon, f)
    if not os.path.exists(p): continue
    for name in re.findall(r'^\s*\{ \d, "((?:[^"\\]|\\.)*)", \d, -?\d+, "(?:[^"\\]|\\.)*" \},', open(p, encoding="utf-8").read(), re.M):
        existing[name.replace('\\"', '"').lower()] = name.replace('\\"', '"')

out_rows, raids, displays, creatures, legacy, keys, world_only = [], [], {}, {}, {}, {}, set()
raid_stats = {}
seen = set(existing)
def card(kind, name, tier, ref, text, pool):
    k = name.lower()
    if k in existing: pool.append(existing[k]); return False
    if k in seen: return False
    seen.add(k); out_rows.append((kind, name, tier, ref, text)); pool.append(name); return True

for name, size, where, title, opens, key, art, alias in RAIDS:
    bosses, crits = [], []
    for a in ach:
        if a["Title_lang"] != title: continue
        for r in kids.get(a["Criteria_tree"], []):
            c = crit.get(r["CriteriaID"])
            if not c: continue
            crits.append((int(a["ID"]), int(r["CriteriaID"])))
            nm = clean(r["Description_lang"])
            if nm and nm not in [b[0] for b in bosses]:
                bosses.append((nm, int(c["Asset"]) if c["Type"] == "0" else 0, int(c["Asset"]) if c["Type"] == "165" else 0))
    if not bosses: print("no bosses for", name, file=sys.stderr); continue
    last = stat_boss.get(name) or (alias and stat_boss.get(alias[0]))
    bosses.sort(key=lambda b: 0 if (last and b[1] == last) else 1)   # (the top card first; the rest in the achievement's order)
    pool = []
    card(3, name, 4, 0, "Raid, %d players, level 60, %s" % (size, where), pool)
    for i, (bn, cid, eid) in enumerate(bosses):
        if not ok(bn): continue
        n = FN.get(cid, {})
        ty = TYPE.get(ctype.get(cid, 7), "humanoid") if cid in ctype else "creature"   # (WoW Forever's own bosses: no type in the data)
        lvl = min(63, n.get("maxLevel") or 63)
        card(2, bn, 5 if i == 0 else 4, ctype.get(cid, 7), "Raid boss, level %d %s" % (lvl, ty), pool)
        if cid and cdisp.get(cid): displays[bn] = cdisp[cid]
        elif cid: creatures[bn] = cid
    bids = {b[1] for b in bosses if b[1]}
    loot = sorted({i for i, f in FI.items() if any(int(x) in bids for x in (f.get("npcDrops") or [])) and quality.get(i, (f.get("quality") or 4)) >= 3},
                  key=lambda i: (-quality.get(i, 4), -ilevel.get(i, 0), iname.get(i, FI[i].get("name", ""))))
    for i in loot[:30]:
        nm = iname.get(i) or clean(FI[i].get("name") or "")
        if not nm or not ok(nm): continue
        q = quality.get(i, 4)
        card(1, nm, 4 if q >= 4 else 3, i, "%s raid drop, item level %d" % ({4: "Epic", 5: "Legendary"}.get(q, "Rare"), ilevel.get(i, 0)), pool)
    # its elites (the classic raids are in the quest data by zone)
    zones = {n.get("zone") for cid, n in FN.items() if cid in bids}
    regs = sorted({(clean(n["name"]), cid) for cid, n in FN.items() if n.get("zone") in zones and (n.get("rank") or 0) == 1 and cid not in bids})
    for nm, cid in regs[:6]:
        if ok(nm) and card(2, nm, 2, ctype.get(cid, 7), "Raid elite, level %d %s" % (FN[cid].get("maxLevel") or 60, TYPE.get(ctype.get(cid, 7), "humanoid")), pool):
            if cdisp.get(cid): displays[nm] = cdisp[cid]
            else: creatures[nm] = cid
    if key:
        item, quests = key
        kn = clean(FI.get(item, {}).get("name") or iname.get(item) or "")
        if kn:
            if card(1, kn, 4, item, "Key to %s: earned by being attuned" % name, pool): world_only.add(kn)
            keys[name] = (item, quests, kn)
    mid = maps.get(name) or next((maps[x] for x in alias if x in maps), 0)   # (the client may name it without "The")
    encs = [e for e in enc.get(mid, [])] if mid else []
    raids.append((name, mid, 60, 60, pool, size, opens, art, [b[0] for b in bosses], encs, where))
    legacy[name] = crits
    # the game's kill statistics for its bosses ("Onyxia kills (Onyxia's Lair)")
    for a in ach:
        m = re.match(r"^(.+) kills \((.+)\)$", a["Title_lang"])
        if m and (m.group(2) == name or m.group(2) in alias) and m.group(1) in [b[0] for b in bosses]:
            raid_stats.setdefault(name, {})[m.group(1)] = int(a["ID"])
    print("  %s: %d bosses, %d loot, %d cards" % (name, len(bosses), len(loot), len(pool)), file=sys.stderr)

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
L = ["-- GENERATED by tools/arcade/raids.py: do not edit by hand.",
     "-- Raid packs: WoW Forever's raids, their bosses (from the game client's raid achievements), their loot once the data",
     "-- has it, their elites and their key. They join the dungeon list: same packs, Album pages and set stages.",
     "local _, RG = ...",
     "RG.ARCADE_DATA = RG.ARCADE_DATA or {}",
     "RG.ARCADE_DUNGEONS = RG.ARCADE_DUNGEONS or {}",
     "RG.ARCADE_RAID_ROWS = {"]
for kind, name, tier, ref, text in out_rows:
    L.append("  { %d, %s, %d, %d, %s }," % (kind, q(name), tier, ref, q(text)))
L.append("}")
L.append("-- { name, instance (0 until the client has it), level, level, { cards }, raid = { size, opens, frame, { bosses }, { encounter ids }, where } }")
L.append("RG.ARCADE_RAIDS = {")
for name, mid, lo, hi, pool, size, opens, art, bosses, encs, where in raids:
    L.append("  { %s, %d, %d, %d, { %s }, raid = { size = %d, opens = %s, frame = %s, bosses = { %s }, encounters = { %s }, where = %s } }," % (
        q(name), mid, lo, hi, ", ".join(q(n) for n in pool), size, q(opens), q(art), ", ".join(q(b) for b in bosses),
        ", ".join("[%d] = %s" % (e, q(n)) for e, n in encs), q(where)))
L.append("}")
L.append("-- each boss's Conqueror criterion: { achievement id, criteria id } (a boss already beaten counts, even from before)")
L.append("RG.ARCADE_RAID_LEGACY = {")
for n, cs in legacy.items(): L.append("  [%s] = { %s }," % (q(n), ", ".join("{ %d, %d }" % c for c in cs)))
L.append("}")
L.append("-- the game's kill statistics for its bosses: [raid] = { [boss] = statistic id }")
L.append("RG.ARCADE_RAID_STATS = {")
for n, st in sorted(raid_stats.items()): L.append("  [%s] = { %s }," % (q(n), ", ".join("[%s] = %d" % (q(b), i) for b, i in sorted(st.items()))))
L.append("}")
L.append("-- the attunement: { key item, { quests that give it }, card }")
L.append("RG.ARCADE_RAID_KEYS = {")
for n, (item, quests, kn) in keys.items(): L.append("  [%s] = { %d, { %s }, %s }," % (q(n), item, ", ".join(str(x) for x in quests), q(kn)))
L.append("}")
L.append("RG.ARCADE_RAID_NPC = {")
for nm in sorted(displays): L.append("  [%s] = %d," % (q(nm), displays[nm]))
L.append("}")
L.append("RG.ARCADE_RAID_CREATURE = {")
for nm in sorted(creatures):
    if nm not in displays: L.append("  [%s] = %d," % (q(nm), creatures[nm]))
L.append("}")
L += ["-- join the lists: raids after the dungeons, each new card after every other card (only in its raid's packs; a key is",
      "-- earned, never in a pack, and can't be traded)",
      "local owner, onlyWorld = {}, { %s }" % ", ".join("[%s] = true" % q(n) for n in sorted(world_only)),
      "for _, d in ipairs(RG.ARCADE_RAIDS) do RG.ARCADE_DUNGEONS[#RG.ARCADE_DUNGEONS + 1] = d; for _, n in ipairs(d[5]) do owner[n] = owner[n] or d[1] end end",
      "RG.ARCADE_DUNGEON_OF = RG.ARCADE_DUNGEON_OF or {}",
      "for n, d in pairs(owner) do RG.ARCADE_DUNGEON_OF[n] = RG.ARCADE_DUNGEON_OF[n] or d end",
      "for _, r in ipairs(RG.ARCADE_RAID_ROWS) do r[6] = owner[r[2]]; r[7] = onlyWorld[r[2]]; RG.ARCADE_DATA[#RG.ARCADE_DATA + 1] = r end",
      "RG.ARCADE_NPC = RG.ARCADE_NPC or {}",
      "for k, v in pairs(RG.ARCADE_RAID_NPC) do if not RG.ARCADE_NPC[k] then RG.ARCADE_NPC[k] = v end end",
      "RG.ARCADE_DUNGEON_CREATURE = RG.ARCADE_DUNGEON_CREATURE or {}",
      "for k, v in pairs(RG.ARCADE_RAID_CREATURE) do if not RG.ARCADE_DUNGEON_CREATURE[k] then RG.ARCADE_DUNGEON_CREATURE[k] = v end end"]
open(os.path.join(addon, "ArcadeRaids.lua"), "w", encoding="utf-8").write("\n".join(L) + "\n")
print("raid cards: %d new, %d raids" % (len(out_rows), len(raids)), file=sys.stderr)
