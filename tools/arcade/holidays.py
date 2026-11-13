"""Holiday packs for the card game -> ArcadeHolidays.lua.

  python3 tools/arcade/holidays.py <classic.sql> <forever_gear.json> <holiday.tsv> <wago dir> <addon dir>

<holiday.tsv> comes from tools/arcade/holiday_dump.lua (the holiday quests of QuestieDB's Forever quest table).
One set per holiday, from its quests: the people who give and take them (their own 3D models) and what they reward.
  - Holiday cards come from that holiday's packs, earned by doing its quests while it's on; they can't be traded.
  - The Lunar Festival's Elders are cards of their own, earned by visiting each Elder (never in a pack).
  - Each card is stamped with the year it was earned (in game), so every year is a new print.
The dates of the holidays with a fixed day each year come from the game client's Holidays table.
"""
import csv, gzip, json, os, re, sys, collections

sql_path, json_path, tsv_path, wago, addon = sys.argv[1:6]
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, 'gen.py'), encoding='utf-8').read()
head = src[:src.index("cards, seen = [], set()")]
saved = sys.argv; sys.argv = ['gen.py', sql_path, '/tmp/', addon]
ns = {}; exec(head, ns); sys.argv = saved
rows, clean, ok = ns['rows'], ns['clean'], ns['ok']

TYPE = {1: "beast", 2: "dragonkin", 3: "demon", 4: "elemental", 5: "giant", 6: "undead", 7: "humanoid", 8: "critter", 9: "mechanical"}
ctype, cdisp, cname, clvl = {}, {}, {}, {}
for e, n, ct, m, lv in rows('creature_template', ['Entry', 'Name', 'CreatureType', 'ModelId1', 'MaxLevel']):
    e = int(e); ctype[e] = int(ct or 0); cdisp[e] = int(m or 0); cname[e] = clean(n); clvl[e] = int(lv or 0)
quality, iname = {}, {}
for e, n, q in rows('item_template', ['entry', 'name', 'Quality']):
    quality[int(e)] = int(q); iname[int(e)] = clean(n)
fv = json.load(open(json_path))
FN = {int(k): v for k, v in fv["npcs"].items() if isinstance(v, dict)}
FI = {int(k): v for k, v in fv["items"].items() if isinstance(v, dict)}
rewards = collections.defaultdict(list)   # quest -> items it rewards
for iid, f in FI.items():
    for qid in (f.get("questRewards") or []):
        rewards[int(qid)].append(iid)

# the holidays: name, Questie sort, how its quests are told apart (sort -22 holds several), the Holidays table id
WV = r"Winter|Metzen|Smokywood|Mean One|Present|Gift\b|New Year|Reason for the Season|Hero of the Day|Ticking|Wrapped|Shaken|Festive Gift"
HE = r"Hallow|Wickerman|Southshore|Rotten Eggs|Power of Pine|Ruined Kegs|Honoring a Hero|Chicken Clucking|Gumdrop|Nougat|Marzipan"
LA = r"Dearest|Dangerous Love|Hunch|Assessment|Gift Giving|Tracing the Source|Source Revealed|Discovery|Bubbling Cauldron"
CW = {171, 172, 558, 910, 911, 915, 925, 1468, 1479, 1558, 1687, 1800, 4822, 5502}
HOLIDAYS = [
    ("Lunar Festival", "lunar", lambda q: q["sort"] == -366, None),
    ("Love is in the Air", "love", lambda q: q["sort"] == -22 and re.search(LA, q["name"]), 335),
    ("Children's Week", "children", lambda q: q["sort"] == -284 and q["id"] in CW, None),
    ("Midsummer Fire Festival", "midsummer", lambda q: q["sort"] == -369, 341),
    ("Hallow's End", "hallow", lambda q: q["sort"] == -22 and re.search(HE, q["name"]), 324),
    ("Feast of Winter Veil", "winterveil", lambda q: q["sort"] == -22 and re.search(WV, q["name"]) and not re.search(LA, q["name"]), 141),
]
quests = []
for line in open(tsv_path, encoding="utf-8"):
    p = line.rstrip("\n").split("\t")
    if len(p) < 5: continue
    quests.append({"id": int(p[0]), "sort": int(p[1]), "name": p[2],
                   "start": [int(x) for x in p[3].split(",") if x], "end": [int(x) for x in p[4].split(",") if x],
                   "mobs": [int(x) for x in (p[5] if len(p) > 5 else "").split(",") if x],
                   "items": [int(x) for x in (p[6] if len(p) > 6 else "").split(",") if x]})

# the yearly dates (packed: minute, hour, weekday, day, month, year; year 31 = every year)
dates = {}
p = os.path.join(wago, "Holidays.csv.gz")
if os.path.exists(p):
    for r in csv.DictReader(gzip.open(p, "rt", encoding="utf-8")):
        v = int(r["Date_0"] or 0)
        if not v: continue
        yr = (v >> 24) & 31
        if yr != 31: continue   # (a date for one year only: the game's calendar tells when it is)
        dates[int(r["ID"])] = ((v >> 20) & 15) + 1, ((v >> 14) & 63) + 1, (v >> 6) & 31, int(r["Duration_0"] or 0)

existing = set()
for f in ("ArcadeCards.lua", "ArcadeDungeons.lua", "ArcadeField.lua", "ArcadeRaids.lua"):
    path = os.path.join(addon, f)
    if os.path.exists(path):
        for name in re.findall(r'^\s*\{ \d, "((?:[^"\\]|\\.)*)", \d, -?\d+, "(?:[^"\\]|\\.)*" \},', open(path, encoding="utf-8").read(), re.M):
            existing.add(name.replace('\\"', '"').lower())

out_rows, sets, displays, creatures, seen = [], [], {}, {}, set(existing)
def add(kind, name, tier, ref, text, pool, field=False):
    k = name.lower()
    if k in seen or not ok(name): return False
    seen.add(k); out_rows.append((kind, name, tier, ref, text, field)); pool.append(name); return True

for hname, key, match, hid in HOLIDAYS:
    qs = [q for q in quests if match(q)]
    if not qs: print("no quests for", hname, file=sys.stderr); continue
    pool, elders = [], {}
    count = collections.Counter()
    for q in qs:
        for n in q["start"] + q["end"]: count[n] += 1
    people = sorted(count, key=lambda n: (-count[n], cname.get(n) or (FN.get(n) or {}).get("name") or ""))
    lead = None
    for n in people:
        nm = cname.get(n) or clean((FN.get(n) or {}).get("name") or "")
        if not nm or nm.startswith("Innkeeper") or nm.endswith("Innkeeper"): continue
        lunar_elder = key == "lunar" and nm.startswith("Elder ")
        tier = 2 if lunar_elder else (4 if lead is None else (3 if count[n] >= 3 else 2))
        lvl = clvl.get(n) or (FN.get(n) or {}).get("maxLevel") or 0
        if add(2, nm, tier, ctype.get(n, 7), "%s, level %d %s" % (hname, lvl, TYPE.get(ctype.get(n, 7), "humanoid")), pool, lunar_elder):
            if lead is None and not lunar_elder: lead = nm
            if cdisp.get(n): displays[nm] = cdisp[n]
            else: creatures[nm] = n
        if lunar_elder:
            for q in qs:
                if n in q["end"]: elders[q["id"]] = nm
    # the creatures its quests send you to (the Abominable Greench, Metzen the Reindeer...)
    for n in sorted({n for q in qs for n in q["mobs"]}):
        nm = cname.get(n) or clean((FN.get(n) or {}).get("name") or "")
        if not nm or nm.startswith("Innkeeper") or re.search(r"Counter|Trigger|Bunny|Credit|Dummy|Target|Invisible", nm): continue
        elite = ((FN.get(n) or {}).get("rank") or 0) >= 1
        lvl = clvl.get(n) or (FN.get(n) or {}).get("maxLevel") or 0
        if add(2, nm, 4 if elite else 3, ctype.get(n, 7), "%s, level %d %s" % (hname, lvl, TYPE.get(ctype.get(n, 7), "humanoid")), pool):
            if cdisp.get(n): displays[nm] = cdisp[n]
            else: creatures[nm] = n
    items = sorted({i for q in qs for i in rewards.get(q["id"], []) + q["items"]}, key=lambda i: (-quality.get(i, 1), iname.get(i, "")))
    for i in items[:24]:
        nm = iname.get(i) or clean(FI[i].get("name") or "")
        if nm: add(1, nm, max(1, min(4, quality.get(i, 1))), i, "%s reward" % hname, pool)
    d = dates.get(hid) if hid else None
    sets.append((hname, key, pool, [q["id"] for q in qs], elders, d))
    print("  %s: %d quests, %d cards (%d Elders)" % (hname, len(qs), len(pool), len(elders)), file=sys.stderr)

def q_(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
L = ["-- GENERATED by tools/arcade/holidays.py: do not edit by hand.",
     "-- Holiday packs: one set per holiday, from its quests (the people who give them, what they reward). Holiday cards",
     "-- come from that holiday's packs (earned by doing its quests while it's on) and can't be traded; the Lunar Festival's",
     "-- Elders are earned by visiting them. Each card carries the year it was earned. New cards go after every other card.",
     "local _, RG = ...",
     "RG.ARCADE_DATA = RG.ARCADE_DATA or {}",
     "RG.ARCADE_DUNGEONS = RG.ARCADE_DUNGEONS or {}",
     "RG.ARCADE_HOLIDAY_ROWS = {"]
elder_names = set()
for kind, name, tier, ref, text, field in out_rows:
    L.append("  { %d, %s, %d, %d, %s }," % (kind, q_(name), tier, ref, q_(text)))
    if field: elder_names.add(name)
L.append("}")
L.append("-- { name, 0, 1, 60, { cards }, holiday = { key, { quests }, elders = { [quest] = card }, date = { month, day, hour, hours } } }")
L.append("RG.ARCADE_HOLIDAYS = {")
for hname, key, pool, qids, elders, d in sets:
    L.append("  { %s, 0, 1, 60, { %s }, holiday = { key = %s, quests = { %s }, elders = { %s }%s } }," % (
        q_(hname), ", ".join(q_(n) for n in pool), q_(key), ", ".join(str(x) for x in qids),
        ", ".join("[%d] = %s" % (k, q_(v)) for k, v in sorted(elders.items())),
        (", date = { %d, %d, %d, %d }" % d) if d else ""))
L.append("}")
L.append("RG.ARCADE_HOLIDAY_NPC = {")
for nm in sorted(displays): L.append("  [%s] = %d," % (q_(nm), displays[nm]))
L.append("}")
L.append("RG.ARCADE_HOLIDAY_CREATURE = {")
for nm in sorted(creatures):
    if nm not in displays: L.append("  [%s] = %d," % (q_(nm), creatures[nm]))
L.append("}")
L += ["-- join the lists: each holiday after the dungeons and raids (its own packs), each new card after every other card:",
      "-- r[6] its holiday, r[7] an Elder (never in a pack), r[8] a holiday card (can't be traded)",
      "local owner, elder = {}, { %s }" % ", ".join("[%s] = true" % q_(n) for n in sorted(elder_names)),
      "RG.ARCADE_HOLIDAY_OF = owner",
      "for _, d in ipairs(RG.ARCADE_HOLIDAYS) do RG.ARCADE_DUNGEONS[#RG.ARCADE_DUNGEONS + 1] = d; for _, n in ipairs(d[5]) do owner[n] = owner[n] or d[1] end end",
      "for _, r in ipairs(RG.ARCADE_HOLIDAY_ROWS) do r[6] = owner[r[2]]; r[7] = elder[r[2]]; r[8] = true; RG.ARCADE_DATA[#RG.ARCADE_DATA + 1] = r end",
      "RG.ARCADE_NPC = RG.ARCADE_NPC or {}",
      "for k, v in pairs(RG.ARCADE_HOLIDAY_NPC) do if not RG.ARCADE_NPC[k] then RG.ARCADE_NPC[k] = v end end",
      "RG.ARCADE_DUNGEON_CREATURE = RG.ARCADE_DUNGEON_CREATURE or {}",
      "for k, v in pairs(RG.ARCADE_HOLIDAY_CREATURE) do if not RG.ARCADE_DUNGEON_CREATURE[k] then RG.ARCADE_DUNGEON_CREATURE[k] = v end end"]
open(os.path.join(addon, "ArcadeHolidays.lua"), "w", encoding="utf-8").write("\n".join(L) + "\n")
print("holiday cards: %d new, %d holidays" % (len(out_rows), len(sets)), file=sys.stderr)
