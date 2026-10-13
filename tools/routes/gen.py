"""Build Routes/Generated.lua: step-by-step quest lists for the starting zones of every
Horde race, from QuestieDB's merged WoW Forever data (see tools/qdb).

For each leg (race, zone, level range) it takes every quest that race can do there
(no class quests; those have their own tracker section), orders them by level and
quest chain, and groups them by quest hub so each step is one stop: "At Razor Hill,
pick up: A, B, C". Each step carries its quest IDs (it ticks itself off when all of
them are turned in) and a waypoint for the hub.

Usage: python3 gen.py <QuestieDB checkout> <forever.json from tools/objectives/dump.lua> [Waypath+ folder]
"""
import json, re, sys, os, math

QDB = sys.argv[1].rstrip('/') + '/'
D = json.load(open(sys.argv[2], encoding='utf-8'))
OUT = (sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')).rstrip('/') + '/'
ui = {int(a): int(b) for a, b in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', open(QDB + 'support/Forever/Zones/areaIdToUiMapId.lua').read())}

RACE_BITS = {'O': 2, 'U': 16, 'T': 32, 'R': 128, 'S': 8589934592}

# Legs of each race's start. zones = quest categories (area IDs) the leg's quests belong to.
# key must match the route entry in Races/<Race>.lua ("Zone|from").
LEGS = [
    # Orc and Troll: Valley of Trials, Durotar, then The Barrens
    ('O', 'Valley of Trials', 1, 6, [363]), ('O', 'Durotar', 6, 12, [14]), ('O', 'The Barrens', 12, 20, [17]),
    ('R', 'Valley of Trials', 1, 6, [363]), ('R', 'Durotar', 6, 12, [14]), ('R', 'The Barrens', 12, 20, [17]),
    # Tauren: Camp Narache (Red Cloud Mesa), Mulgore, then The Barrens
    ('T', 'Camp Narache', 1, 6, [220]), ('T', 'Mulgore', 6, 12, [215]), ('T', 'The Barrens', 12, 20, [17]),
    # Undead: Deathknell, Brill, then Silverpine Forest
    ('U', 'Tirisfal Glades', 1, 6, [154]), ('U', 'Tirisfal Glades', 6, 12, [85]), ('U', 'Silverpine Forest', 10, 20, [130]),
    # Skyborne (Windshapers): Zephras Isle 1-12, then Mulgore and The Barrens
    ('S', 'Zephras Isle', 1, 12, [16593]), ('S', 'Mulgore', 12, 14, [215]), ('S', 'The Barrens', 13, 20, [17]),
]

# Quest hubs, anchored to an NPC who stands there (coordinates come from the data).
ANCHORS = {
    363: [('the Den, Valley of Trials', 'Gornek')],
    14: [('the Den, Valley of Trials', 'Gornek'), ('Razor Hill', 'Innkeeper Grosk'), ("Sen'jin Village", 'Master Gadrin')],
    220: [('Camp Narache', 'Chief Hawkwind')],
    215: [('Camp Narache', 'Chief Hawkwind'), ('Bloodhoof Village', 'Innkeeper Kauth')],
    17: [('the Crossroads', 'Innkeeper Boorand Plainswind'), ('Camp Taurajo', 'Innkeeper Byula'), ('Ratchet', 'Innkeeper Wiley')],
    154: [('Deathknell', 'Shadow Priest Sarvis')],
    85: [('Deathknell', 'Shadow Priest Sarvis'), ('Brill', 'Innkeeper Renee')],
    130: [('The Sepulcher', 'Innkeeper Bates')],
    16593: [('the starting grove', 'Rorian the Dayseeker'), ("Shen'dar Village", 'Constable Aonda'),
            ('Falaath Village', 'Missionary Jasaan'), ('Valanaar', 'Valennia Stormfist')],
}
CITIES = {1637: 'Orgrimmar', 1638: 'Thunder Bluff', 1497: 'Undercity'}   # a giver anywhere in a capital = that city
HUB_RADIUS = 10.0     # map units: givers this close to an anchor belong to that hub
MAX_PER_STEP = 8

def at(a, i):
    if a is None: return None
    if isinstance(a, dict): return a.get(str(i))
    return a[i - 1] if 0 < i <= len(a) else None

def npc(id_):
    e = D['npcs'].get(str(id_))
    if not e: return None, {}
    sp = at(e, 2) or {}
    return at(e, 1), (sp if isinstance(sp, dict) else {})

def alliance_only(givers):
    givers = givers or []
    return bool(givers) and all((at(D['npcs'].get(str(i)) or [], 3) or 'AH') == 'A' for i in givers)

npc_by_name = {}
for nid, e in D['npcs'].items():
    n = at(e, 1)
    if n and n not in npc_by_name and isinstance(at(e, 2), dict) and at(e, 2): npc_by_name[n] = at(e, 2)

def first_point(spawns, prefer):
    for z in [str(p) for p in prefer] + list(spawns.keys()):
        pts = spawns.get(z)
        if pts:
            pts = [p for p in pts if p and p[0] is not None and p[0] >= 0]
            if pts: return int(z), pts[0][0], pts[0][1]
    return None

def anchor_points(zones):
    out = []
    for z in zones:
        for label, who in ANCHORS.get(z, []):
            sp = npc_by_name.get(who)
            p = sp and first_point(sp, zones)
            if p: out.append((label, p))
    return out

def lstr(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

def build(letter, zone_name, lo, hi, zones):
    bit = RACE_BITS[letter]
    quests = {}
    for qid, q in D['quests'].items():
        name, starts, ends, rl, ql, races, objs, z, sflags, classes, preG, preS, excl = [at(q, i) for i in range(1, 14)]
        races = int(races or 0)
        if z not in zones or classes: continue
        if races and not (races & bit): continue
        if (sflags or 0) & 1: continue           # repeatable
        ql = ql if (ql and ql > 0) else (rl or 1)
        if not (lo - 1 <= ql <= hi + 1): continue
        giver = None
        if alliance_only(at(starts, 1)): continue
        for i in (at(starts, 1) or []):
            gname, sp = npc(i)
            p = first_point(sp, zones)
            if p: giver = (gname, p); break
        if not giver: continue                   # item- or object-started: picked up on the way
        quests[int(qid)] = dict(id=int(qid), name=name, lvl=ql, req=rl or 1, giver=giver, pre=list(preG or []) + list(preS or []))
    if not quests: return []
    if lo == 1:  # a starting zone: only quests handed out in the zone itself
        home = {ui.get(z) for z in zones}
        quests = {k: q for k, q in quests.items() if ui.get(q['giver'][1][0]) in home}
    # chain depth so follow-ups come after what unlocks them
    depth = {}
    def d(qid, seen=()):
        if qid in depth: return depth[qid]
        q = quests.get(qid)
        if not q or qid in seen: return 0
        v = 1 + max([d(p, seen + (qid,)) for p in q['pre'] if p in quests] or [-1])
        depth[qid] = v
        return v
    for qid in quests: d(qid)
    anchors = anchor_points(zones)
    def hub_of(q):
        gz, gx, gy = q['giver'][1]
        best = None
        for label, (az, ax, ay) in anchors:
            if az != gz: continue
            dist = math.hypot(ax - gx, ay - gy)
            if dist <= HUB_RADIUS and (not best or dist < best[0]): best = (dist, label, (az, ax, ay))
        if best: return best[1], best[2]
        if gz in CITIES: return CITIES[gz], (gz, gx, gy)
        return q['giver'][0], q['giver'][1]
    # Walk the zone like a player would: go to the hub with the most quests you can
    # take now, take everything there (and follow-ups handed out on the spot), move on.
    done, steps, L = set(), [], lo
    def ready(q):
        return (q['id'] not in done and q['req'] <= L + 1 and q['lvl'] <= L + 3
                and all(p in done or p not in quests for p in q['pre']))
    last_point = None
    while len(done) < len(quests):
        cands = [q for q in quests.values() if ready(q)]
        if not cands:
            if L > hi + 3: break
            L += 1; continue
        hubs = {}
        for q in cands:
            label, point = hub_of(q)
            hubs.setdefault(label, (point, []))[1].append(q)
        def score(item):
            label, (point, qs) = item
            near = 0 if not last_point or last_point[0] != point[0] else math.hypot(point[1] - last_point[1], point[2] - last_point[2])
            # several quests at one stop beat anything else; lone givers: nearest first
            low = min(q['lvl'] for q in qs)
            # quests falling behind your level come first; then the busiest stop; then the nearest
            return (0 if low <= L - 2 else 1, 0 if len(qs) >= 2 else 1, -len(qs) if len(qs) >= 2 else 0, round(near / 8), low)
        label, (point, qs) = sorted(hubs.items(), key=score)[0]
        taken = []
        while qs:
            qs.sort(key=lambda q: (q['lvl'], depth[q['id']], q['id']))
            for q in qs: done.add(q['id'])
            taken += qs
            qs = [q for q in quests.values() if ready(q) and hub_of(q)[0] == label]
        for i in range(0, len(taken), MAX_PER_STEP):
            steps.append({'hub': label, 'point': point, 'q': taken[i:i + MAX_PER_STEP]})
        last_point = point
        L = max(L, min(hi, sorted(q['lvl'] for q in taken)[len(taken) // 2]))
    out = []
    for s in steps:
        names = []
        for q in s['q']:
            if q['name'] not in names: names.append(q['name'])   # chain parts share a name
        givers = []
        for q in s['q']:
            if q['giver'][0] not in givers: givers.append(q['giver'][0])
        lv = sorted({q['lvl'] for q in s['q']})
        lvtxt = ('level %d' % lv[0]) if len(lv) == 1 else ('levels %d-%d' % (lv[0], lv[-1]))
        if s['hub'] == s['q'][0]['giver'][0] and len(givers) == 1:
            text = '%s (%s): %s.' % (s['hub'], lvtxt, ', '.join(names))
        else:
            who = ', '.join(givers[:3]) + (' and others' if len(givers) > 3 else '')
            text = '%s%s (%s): %s. From %s.' % ('At ' if s['hub'][0].islower() or s['hub'] in CITIES.values() or s['hub'][0].isupper() else '', s['hub'], lvtxt, ', '.join(names), who)
        z, x, y = s['point']
        out.append((text, [q['id'] for q in s['q']], (ui.get(z, 0), round(x, 1), round(y, 1), s['hub'])))
    return out

# ---------------------------------------------------------------------------
# Dungeon quests: every Horde quest for each dungeon (race/class letters kept so the
# add-on shows each character only its own), with giver, where and a waypoint.
# ---------------------------------------------------------------------------
DUNGEONS = [
    ('Ruins of Lordaeron', [16611, 16612, 16614, 16615, 16617]), ('Ragefire Chasm', [2437]), ('Wailing Caverns', [718]),
    ('The Hall of Thanes', [16919]), ('Shadowfang Keep', [209]), ('Blackfathom Deeps', [719]), ('Gnomeregan', [721]),
    ('Razorfen Kraul', [491]), ('Excavation Site', [16732, 16877, 16878, 16879]), ('City of Dalaran', [16544, 16558, 16559, 16560, 16562]),
    ('Scarlet Monastery', [796]), ('Razorfen Downs', [722]), ('Uldaman', [1337]), ("Krol'dok Stronghold", [17780]),
    ("Zul'Farrak", [1176]), ('Maraudon', [2100]), ("The Temple of Atal'Hakkar", [1477]), ('Blackrock Depths', [1584]),
    ('Stratholme, Scholomance, Dire Maul, LBRS/UBRS', [2017, 2057, 2557, 1583]), ("The Shaper's Terrace", [16985]),
]
# Sub-areas (SCARLET_MONASTERY_LIBRARY -> SCARLET_MONASTERY) from QuestieDB's zone list.
ENUM = {}
for m in re.finditer(r'^\s*([A-Z_0-9]+)\s*=\s*(\d+),', open(QDB + 'src/corrections/enum/zones.lua').read(), re.M):
    ENUM.setdefault(m.group(1), int(m.group(2)))
SUBAREAS = {}
for nm, aid in ENUM.items():
    parts = nm.split('_')
    for k in range(len(parts) - 1, 0, -1):
        parent = '_'.join(parts[:k])
        if parent in ENUM and ENUM[parent] != aid: SUBAREAS[aid] = ENUM[parent]; break
MAPNAME = {}
for m in re.finditer(r'\[(\d+)\]\s*=\s*(\d+),\s*--\s*([^\n>]+?)\s*$', open(QDB + 'support/Forever/Zones/areaIdToUiMapId.lua').read(), re.M):
    MAPNAME.setdefault(int(m.group(2)), m.group(3).strip())
RL = [(2, 'O'), (16, 'U'), (32, 'T'), (128, 'R'), (8589934592, 'S')]
CL = [(1, 'W'), (2, 'P'), (4, 'H'), (8, 'R'), (16, 'I'), (64, 'S'), (128, 'M'), (256, 'L'), (1024, 'D')]
HORDE = sum(b for b, _ in RL)
def in_dungeon(objs, areas):
    """True when the quest's objectives are mostly inside the dungeon: mobs to kill, objects
    to use, and items that mostly drop there (not cloth or other drops found everywhere)."""
    def zones_of(kind, id_):
        e = D['npcs' if kind == 'npc' else 'objects'].get(str(id_))
        sp = e and at(e, 2)
        return {int(k) for k in sp.keys()} if isinstance(sp, dict) else set()
    def ids(lst):
        for o in (lst or []):
            o = o if isinstance(o, list) else ([o.get(str(i)) for i in range(1, 4)] if isinstance(o, dict) else [o])
            if o and o[0] is not None: yield o[0]
    hits = total = 0
    for i in ids(at(objs, 1)):
        zs = zones_of('npc', i); total += 1; hits += bool(zs and zs <= areas)
    for i in ids(at(objs, 2)):
        zs = zones_of('obj', i); total += 1; hits += bool(zs and zs <= areas)
    for i in ids(at(objs, 3)):
        it = D['items'].get(str(i))
        srcs = [('npc', n) for n in ((at(it, 2) or []) if it else [])] + [('obj', o) for o in ((at(it, 3) or []) if it else [])]
        if not srcs: continue
        inside = sum(1 for k, x in srcs if zones_of(k, x) and zones_of(k, x) <= areas)
        total += 1; hits += inside * 2 >= len(srcs)
    for o in (at(objs, 5) or []):
        o = o if isinstance(o, list) else []
        for n in (o[0] if o and isinstance(o[0], list) else [])[:1]:
            zs = zones_of('npc', n); total += 1; hits += bool(zs and zs <= areas)
    return total > 0 and hits * 2 >= total

def dungeon_quests(areas):
    out = []
    areas = set(areas) | {a for a in SUBAREAS if SUBAREAS[a] in areas}
    for qid, q in D['quests'].items():
        name, starts, ends, rl, ql, races, objs, z, sflags, classes, preG, preS, excl = [at(q, i) for i in range(1, 14)]
        races, classes = int(races or 0), int(classes or 0)
        if (races and not races & HORDE) or (sflags or 0) & 1: continue
        if z not in areas and not in_dungeon(objs, areas): continue
        if alliance_only(at(starts, 1)): continue
        if ql is not None and ql > 62: continue
        giver = None
        for i in (at(starts, 1) or []):
            gname, sp = npc(i)
            p = first_point(sp, [])
            if p: giver = (gname, p); break
        ra = ''.join(c for b, c in RL if races & b) if races and (races & HORDE) != HORDE else ''
        cl = ''.join(c for b, c in CL if classes & b) if classes and len([1 for b, _ in CL if classes & b]) < 9 else ''
        out.append((ql or rl or 0, int(qid), name, giver, ra, cl, rl or 1))
    out.sort()
    return out

lines = ['-- GENERATED by tools/routes/gen.py from QuestieDB\'s merged WoW Forever data: do not edit by hand.',
         '-- Starting-zone quest steps for every Horde race. Each step: t = text, q = its quest IDs',
         '-- (it ticks itself off once all of them are turned in), w = hub waypoint {uiMapID, x, y, label}.',
         '-- RG.GEN_STEPS[race letter]["Zone|from"] = { steps }. Races/<Race>.lua define the route entries.',
         'local _, RG = ...', 'RG.GEN_STEPS = {']
total = 0
by_race = {}
for letter, zone_name, lo, hi, zones in LEGS:
    steps = build(letter, zone_name, lo, hi, zones)
    by_race.setdefault(letter, []).append((zone_name, lo, steps))
    total += len(steps)
    print('%s %-18s %2d-%2d: %2d steps, %3d quests' % (letter, zone_name, lo, hi, len(steps), sum(len(s[1]) for s in steps)), file=sys.stderr)
for letter in sorted(by_race):
    lines.append('  %s = {' % letter)
    for zone_name, lo, steps in by_race[letter]:
        lines.append('    [%s] = {' % lstr('%s|%d' % (zone_name, lo)))
        for text, ids, (m, x, y, label) in steps:
            lines.append('      { t = %s, q = { %s }, w = { %d, %.1f, %.1f, %s } },' % (lstr(text), ', '.join(map(str, ids)), m, x, y, lstr(label)))
        lines.append('    },')
    lines.append('  },')
lines.append('}')
lines.append('-- RG.GEN_DUNGEONS[route name] = { {id, name, giver, where, waypoint, level, required level, ra = races, cl = classes}, ... }')
lines.append('RG.GEN_DUNGEONS = {')
for dname, areas in DUNGEONS:
    qs = dungeon_quests(areas)
    print('dungeon %-45s %2d quests' % (dname, len(qs)), file=sys.stderr)
    if not qs: continue
    lines.append('  [%s] = {' % lstr(dname))
    for lvl, qid, name, giver, ra, cl, rl in qs:
        if giver:
            gz, gx, gy = giver[1]
            m = ui.get(gz, 0)
            wp = '{ %d, %.1f, %.1f, %s }' % (m, gx, gy, lstr(giver[0] or ''))
            where = MAPNAME.get(m, '')
        else:
            wp, where = 'nil', 'starts from an item'
        extra = (', ra = "%s"' % ra if ra else '') + (', cl = "%s"' % cl if cl else '')
        lines.append('    { id = %d, n = %s, g = %s, at = %s, w = %s, l = %d, r = %d%s },' % (qid, lstr(name or '?'), lstr((giver and giver[0]) or ''), lstr(where), wp, lvl, rl, extra))
    lines.append('  },')
lines.append('}')
os.makedirs(OUT + 'Routes', exist_ok=True)
open(OUT + 'Routes/Generated.lua', 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print('%d steps written' % total, file=sys.stderr)
