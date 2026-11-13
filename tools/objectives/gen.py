"""Build Objectives.lua: for every quest a Horde character can take (any race, any class),
who gives it, where to finish it and where its objectives are (kill / loot / use), from
QuestieDB's merged WoW Forever data (see tools/qdb). Race- and class-only quests carry
ra = race letters and cl = class letters; the add-on filters them for your character.
Objective spots: each mob's real spawns are grouped into a few hunting areas per zone (nearest area wins in game),
and for "collect an item" objectives the mobs that drop it most often come first (drop chances from the cMaNGOS
loot tables when --sql is given).
Hand-checked fixes from Polestar's forever-db (its corrections layer, CC BY 4.0, each fix backed by players' recordings,
live client data or an in-game check) go on top of QuestieDB's data when --fixes <forever-db folder> is given: who can
take a quest (races, classes), what comes first, levels, givers, turn-ins, objectives, and quests not in the game.
Usage: python3 gen.py <QuestieDB checkout> <forever.json from dump.lua> [Waypath+ folder] [--sql classic.sql] [--fixes forever-db]"""
import json, re, sys, os
SQL = None
FIXES = None
if '--fixes' in sys.argv:
    i = sys.argv.index('--fixes'); FIXES = sys.argv[i + 1]; del sys.argv[i:i + 2]
if '--sql' in sys.argv:
    i = sys.argv.index('--sql'); SQL = sys.argv[i + 1]; del sys.argv[i:i + 2]
QDB = sys.argv[1].rstrip('/') + '/'
def _sorted_pairs(kv):
    """Dicts from the Lua dumps come in random order; sort keys (numbers first) so every run picks the same spawn."""
    def k(x):
        s = x[0]
        return (0, int(s), '') if s.lstrip('-').isdigit() else (1, 0, s)
    return dict(sorted(kv, key=k))
D = json.load(open(sys.argv[2], encoding='utf-8'), object_pairs_hook=_sorted_pairs)
RET = (sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')).rstrip('/') + '/'
ui = {int(a): int(b) for a, b in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', open(QDB + 'support/Forever/Zones/areaIdToUiMapId.lua').read())}
# Horde races: Orc, Undead, Tauren, Troll, Skyborne (Windshaper)
RACES = [(2, 'O'), (16, 'U'), (32, 'T'), (128, 'R'), (8589934592, 'S'), (1, 'H'), (4, 'D'), (8, 'N'), (64, 'G'), (4294967296, 'A')]
HORDE = sum(b for b, _ in RACES)   # every playable race, both factions
CLASSES = [(1, 'W'), (2, 'P'), (4, 'H'), (8, 'R'), (16, 'I'), (64, 'S'), (128, 'M'), (256, 'L'), (1024, 'D')]
ALL_CLASSES = sum(b for b, _ in CLASSES)

def at(arr, i):  # 1-based access to a Lua array that may have been encoded as a dict
    if arr is None: return None
    if isinstance(arr, dict): return arr.get(str(i))
    return arr[i - 1] if 0 < i <= len(arr) else None
def spawns_of(kind, id_):
    e = D['npcs' if kind == 'npc' else 'objects'].get(str(id_))
    if not e: return (None, {})
    sp = at(e, 2) or {}
    if isinstance(sp, list): sp = {}
    return (at(e, 1), sp)
def rep_points(sp, prefer_zone, maxzones=3):
    """One representative point per zone: the real spawn closest to that zone's centroid."""
    out = []
    zones = sorted(sp.items(), key=lambda kv: (0 if int(kv[0]) == prefer_zone else 1, -len(kv[1])))
    for z, pts in zones:
        z = int(z)
        if z not in ui: continue
        pts = [p for p in pts if p and p[0] is not None and p[0] >= 0]
        if not pts: continue
        cx = sum(p[0] for p in pts) / len(pts); cy = sum(p[1] for p in pts) / len(pts)
        x, y = min(pts, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)[:2]   # (a spawn can carry a phase after x, y)
        out.append((ui[z], round(x, 1), round(y, 1)))
        if len(out) >= maxzones: break
    return out
def cluster_points(sp, prefer_zone, maxzones=2, per_zone=4):
    """Hunting areas: each zone's spawns grouped (k-means) into up to per_zone areas, biggest first; each area is
    the real spawn nearest its middle. Returned biggest areas first across zones."""
    out = []
    zones = sorted(sp.items(), key=lambda kv: (0 if int(kv[0]) == prefer_zone else 1, -len(kv[1])))
    nz = 0
    for z, pts in zones:
        z = int(z)
        if z not in ui: continue
        pts = sorted([(p[0], p[1]) for p in pts if p and p[0] is not None and p[0] >= 0])
        if not pts: continue
        k = max(1, min(per_zone, len(pts) // 5 or 1))
        # deterministic start: spread the seeds along the sorted list
        cent = [pts[int(i * (len(pts) - 1) / max(1, k - 1))] if k > 1 else (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)) for i in range(k)]
        for _ in range(12):
            groups = [[] for _ in cent]
            for p in pts:
                j = min(range(len(cent)), key=lambda j: (p[0] - cent[j][0]) ** 2 + (p[1] - cent[j][1]) ** 2)
                groups[j].append(p)
            cent = [(sum(q[0] for q in g) / len(g), sum(q[1] for q in g) / len(g)) if g else cent[j] for j, g in enumerate(groups)]
        areas = []
        for c, g in zip(cent, groups):
            if not g: continue
            if len(g) < 2 and len(pts) >= 6: continue   # a lone spawn far from the rest is not a hunting area
            x, y = min(g, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2)
            areas.append((len(g), ui[z], round(x, 1), round(y, 1)))
        if not areas:
            c = (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
            x, y = min(pts, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2)
            areas = [(len(pts), ui[z], round(x, 1), round(y, 1))]
        areas.sort(key=lambda a: -a[0])
        out += [a[1:] for a in areas]
        nz += 1
        if nz >= maxzones: break
    return out
# drop chances: creature entry -> loot id -> {item: chance %}
DROP = {}
if SQL:
    print('reading drop chances...', file=sys.stderr)
    sqltxt = open(SQL, encoding='utf-8', errors='replace').read()
    def _cols(t):
        m = re.search(r"CREATE TABLE `%s` \((.*?)\) ENGINE" % t, sqltxt, re.S)
        return re.findall(r"^\s*`(\w+)`", m.group(1), re.M)
    def _rows(t):
        """every row of a table's INSERTs, honouring quoted strings (names hold commas and brackets)"""
        for m in re.finditer(r"INSERT INTO `%s` VALUES " % t, sqltxt):
            i, n = m.end(), len(sqltxt)
            while i < n and sqltxt[i] == '(':
                i += 1; row, cur, inq = [], [], False
                while True:
                    c = sqltxt[i]
                    if inq:
                        if c == '\\': cur.append(sqltxt[i + 1]); i += 2; continue
                        if c == "'":
                            if sqltxt[i + 1] == "'": cur.append("'"); i += 2; continue
                            inq = False; i += 1; continue
                        cur.append(c); i += 1; continue
                    if c == "'": inq = True; i += 1; continue
                    if c == ',': row.append(''.join(cur)); cur = []; i += 1; continue
                    if c == ')': row.append(''.join(cur)); i += 1; break
                    cur.append(c); i += 1
                yield row
                if sqltxt[i] == ',': i += 1
                else: break
    cc = _cols('creature_template'); ie, il = cc.index('Entry'), cc.index('LootId')
    lootof = {}
    for r in _rows('creature_template'):
        try: lootof[int(r[ie])] = int(r[il])
        except Exception: pass
    lc = _cols('creature_loot_template'); le, li, lch = lc.index('entry'), lc.index('item'), lc.index('ChanceOrQuestChance')
    byloot = {}
    for r in _rows('creature_loot_template'):
        try: byloot.setdefault(int(r[le]), {})[int(r[li])] = abs(float(r[lch]))
        except Exception: pass
    for e, l in lootof.items():
        if l and l in byloot: DROP[e] = byloot[l]
    del sqltxt
    print('drop tables for %d creatures' % len(DROP), file=sys.stderr)
def L(o):  # objective entry as a 1-based list
    if isinstance(o, dict): return [o.get(str(i)) for i in range(1, 5)]
    return list(o) + [None] * 4
def lstr(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

# ---------------------------------------------------------------------------
# Polestar forever-db's hand-checked quest fixes (CC BY 4.0), on top of QuestieDB's data
# (fields of the dumped quest: 1 name, 2 givers, 3 turn-ins, 4 required level, 5 level, 6 races, 7 objectives,
# 10 classes, 11 all-of prerequisites, 12 any-of prerequisites, 13 exclusive with, 17 next, 19 breadcrumb for)
# ---------------------------------------------------------------------------
FIXED = 0
if FIXES and os.path.exists(os.path.join(FIXES, 'corrections', 'quests.json')):
    corr = json.load(open(os.path.join(FIXES, 'corrections', 'quests.json'), encoding='utf-8'))
    Q = D['quests']
    def qlist(q):
        if isinstance(q, dict): return [q.get(str(i)) for i in range(1, 25)]
        return list(q) + [None] * (24 - len(q))
    gone = {k for k, v in corr.items() if v.get('remove')}
    for k in gone: Q.pop(k, None)
    for k, v in corr.items():
        st = v.get('set')
        if not st or k not in Q: continue
        q = qlist(Q[k])
        def put(i, val): q[i - 1] = val
        if 'title' in st: put(1, st['title'])
        if 'minLevel' in st: put(4, st['minLevel'])
        if 'level' in st: put(5, st['level'])
        if 'races' in st: put(6, st['races'])
        if 'classes' in st: put(10, st['classes'])
        if 'preAll' in st or 'preAny' in st:
            if 'preAll' in st: put(11, st['preAll'] or None)
            if 'preAny' in st: put(12, st['preAny'] or None)
        elif 'pre' in st: put(11, None); put(12, st['pre'] or None)
        if 'excl' in st: put(13, st['excl'] or None)
        if 'next' in st: put(17, st['next'])
        if 'breadcrumbFor' in st: put(19, st['breadcrumbFor'])
        if 'start' in st:
            s_ = st['start']; put(2, [s_.get('npc') or [], s_.get('object') or [], s_.get('item') or []])
        if 'end' in st:
            e_ = st['end']; put(3, [e_.get('npc') or [], e_.get('object') or []])
        if 'objectives' in st:
            objs = st['objectives']
            have = [o for o in objs if o.get('type') in ('kill', 'object', 'item')]
            # (talking to someone or an event has no spot to show: those fixes keep the objectives the map can show)
            if have or not objs:
                old = qlist(q[6]) if q[6] else [None] * 24
                kills = [[o['id'], o.get('text')] for o in objs if o.get('type') == 'kill']
                obs = [[o['id'], o.get('text')] for o in objs if o.get('type') == 'object']
                its = [[o['id'], o.get('text')] for o in objs if o.get('type') == 'item']
                put(7, [kills or None, obs or None, its or None, old[3], None])
        Q[k] = q
        FIXED += 1
    # quests not in the game: nothing else waits for them
    for k, q in Q.items():
        ql = qlist(q)
        for i in (11, 12):
            pre = ql[i - 1]
            if isinstance(pre, (list, dict)):
                vals = list(pre.values()) if isinstance(pre, dict) else pre
                keep = [x for x in vals if str(x) not in gone]
                if len(keep) != len(vals): ql[i - 1] = keep or None; Q[k] = ql
    print('forever-db fixes: %d quests changed, %d taken out (not in the game)' % (FIXED, len(gone)), file=sys.stderr)

out, nq, nobj, npts = [], 0, 0, 0
for qid, q in sorted(D['quests'].items(), key=lambda kv: int(kv[0])):
    name, starts, ends, reqlvl, qlvl, races, objectives, zone, sflags, classes, preG, preS, excl = [at(q, i) for i in range(1, 14)]
    reqSkill, minRep, maxRep, nextQ, parentQ, crumbFor, reqSpell, maxLvl, untilDone, startWith, disabledBy = [at(q, i) for i in range(14, 25)]
    races = int(races or 0); classes = int(classes or 0)
    if races and not (races & HORDE): continue
    if qlvl and qlvl > 62: continue
    if qlvl is not None and qlvl < 0: qlvl = None   # -1 = scales with you
    ra = ''.join(c for b, c in RACES if races & b) if races and (races & HORDE) != HORDE else ''
    cl = ''.join(c for b, c in CLASSES if classes & b) if classes and (classes & ALL_CLASSES) != ALL_CLASSES else ''
    if classes and not cl and (classes & ALL_CLASSES) == 0: continue
    zone = zone if isinstance(zone, int) else 0
    # where to turn it in
    end = None
    for kind, ids in (('npc', at(ends, 1)), ('obj', at(ends, 2))):
        for i in ids or []:
            n, sp = spawns_of(kind, i)
            pts = rep_points(sp, zone, 1)
            if pts: end = (pts[0], n); break
        if end: break
    objs = []
    def add(kind, label, sources):
        global npts
        pts, mobs = [], []
        for si, (skind, sid) in enumerate(sources[:4]):
            sname, sp = spawns_of(skind, sid)
            if not sname: continue
            if skind == 'npc' and sname not in mobs: mobs.append(sname)
            for p in cluster_points(sp, zone, 2, 4 if si == 0 else 2): pts.append(p + (len(mobs) if skind == 'npc' else 0,))
        if pts or mobs:
            objs.append((kind, label, mobs, pts[:8])); npts += len(pts[:8])
    for o in map(L, at(objectives, 1) or []):          # kill
        n, _ = spawns_of('npc', o[0]); add('kill', (o[1] if len(o) > 1 and o[1] else n) or '?', [('npc', o[0])])
    for o in map(L, at(objectives, 2) or []):          # use / interact with an object
        n, _ = spawns_of('obj', o[0]); add('object', (o[1] if len(o) > 1 and o[1] else n) or '?', [('obj', o[0])])
    for o in map(L, at(objectives, 3) or []):          # loot an item
        it = D['items'].get(str(o[0]))
        if not it: continue
        npcs = list(at(it, 2) or [])
        # the mobs that drop it most often first; the rarely-dropping ones only if nothing better is known
        ch = {n: DROP.get(n, {}).get(int(o[0])) for n in npcs}
        known = [c for c in ch.values() if c]
        if known:
            best = max(known)
            npcs = sorted([n for n in npcs if ch[n] and ch[n] >= best * 0.35], key=lambda n: -ch[n]) + [n for n in npcs if not ch[n]]
        srcs = [('npc', i) for i in npcs] + [('obj', i) for i in (at(it, 3) or [])]
        add('item', at(it, 1) or '?', srcs)
    for o in map(L, at(objectives, 5) or []):          # kill credit (several mobs count)
        ids = o[0] if isinstance(o[0], list) else []
        add('kill', (o[2] if len(o) > 2 and o[2] else '?'), [('npc', i) for i in ids])
    # who gives it (NPC only; item-started quests show up by themselves)
    start = None
    givers = at(starts, 1) or []
    if givers and all((at(D['npcs'].get(str(i)) or [], 3) or 'AH') == 'A' for i in givers): continue   # Alliance-only quest giver
    for i in givers:
        n, sp = spawns_of('npc', i)
        pts = rep_points(sp, zone, 1)
        if pts: start = (pts[0], n); break
    if not objs and not end and not start and not name: continue
    nq += 1; nobj += len(objs)
    parts = []
    if end: parts.append('e={%d,%.1f,%.1f,%s}' % (end[0][0], end[0][1], end[0][2], lstr(end[1] or '')))
    # s = where to pick it up (only for quests offered as "new": not repeatables)
    if start and not ((sflags or 0) & 1):
        parts.append('s={%d,%.1f,%.1f,%s}' % (start[0][0], start[0][1], start[0][2], lstr(start[1] or '')))
    # name, levels and prerequisites for every quest, even ones that start from an
    # item or object or whose giver has no map position (steps, chains and dungeon
    # lists still need to know them)
    if name:
        parts.append('n=%s' % lstr(name))
        parts.append('r=%d' % (reqlvl or 1))
        parts.append('l=%d' % (qlvl or reqlvl or 1))
        if preG: parts.append('pg={%s}' % ','.join(str(x) for x in preG))
        if preS: parts.append('ps={%s}' % ','.join(str(x) for x in preS))
        if excl: parts.append('x={%s}' % ','.join(str(x) for x in excl))
        # the rest of what decides whether the giver offers it (QuestieDB's quest fields 18-36)
        def pair(v):
            v = [at(v, 1), at(v, 2)] if v is not None else None
            return v if v and v[0] is not None and v[1] is not None else None
        if pair(reqSkill): parts.append('sk={%d,%d}' % tuple(pair(reqSkill)))
        if pair(minRep): parts.append('rp={%d,%d}' % tuple(pair(minRep)))
        if pair(maxRep): parts.append('rx={%d,%d}' % tuple(pair(maxRep)))
        if isinstance(nextQ, int) and nextQ > 0: parts.append('nx=%d' % nextQ)
        if isinstance(parentQ, int) and parentQ > 0: parts.append('pa=%d' % parentQ)
        if isinstance(crumbFor, int) and crumbFor > 0: parts.append('bc=%d' % crumbFor)
        if isinstance(reqSpell, int) and reqSpell != 0: parts.append('sp=%d' % reqSpell)
        if isinstance(maxLvl, int) and maxLvl > 0: parts.append('mx=%d' % maxLvl)
        if isinstance(untilDone, int) and untilDone > 0: parts.append('uc=%d' % untilDone)
        if isinstance(startWith, int) and startWith > 0: parts.append('sw=%d' % startWith)
        dis = [disabledBy] if isinstance(disabledBy, int) else [x for x in (disabledBy.values() if isinstance(disabledBy, dict) else disabledBy or []) if isinstance(x, int)]
        if dis: parts.append('dq={%s}' % ','.join(str(x) for x in dis))
    if (sflags or 0) & 1: parts.append('rep=true')
    if ra: parts.append('ra="%s"' % ra)
    if cl: parts.append('cl="%s"' % cl)
    if cl and len(cl) <= 4: parts.append('cq=true')   # a real class quest (not a "most classes" variant)
    if objs:
        os_ = []
        for kind, label, mobs, pts in objs:
            os_.append('{%s,%s,{%s},{%s}}' % (lstr(kind[0]), lstr(label), ','.join(lstr(m) for m in mobs),
                       ','.join('{%d,%.1f,%.1f,%d}' % p for p in pts)))
        parts.append('o={' + ','.join(os_) + '}')
    out.append('[%s]={%s}' % (qid, ','.join(parts)))
head = ['-- Waypath+ quest objectives: where to finish each quest and where its objectives are.',
        "-- Generated from QuestieDB's WoW Forever data (coordinates already converted to Forever's maps), with the hand-checked",
        "-- fixes of Polestar's forever-db (corrections layer, CC BY 4.0, by the Polestar authors) on top:",
        '-- https://github.com/Questie/QuestieDB  ·  rebuild with tools/objectives.',
        '-- [questID] = { e = {uiMapID, x, y, finisher}, s = {uiMapID, x, y, giver}, n = name, r = required level, l = quest level,',
        '--   pg = {all of these first}, ps = {any of these first}, x = {done one of these: this one is gone},',
        '--   sk = {skill, rank}, rp = {faction, min rep}, rx = {faction, max rep}, nx = next in chain (taken or done: this one is gone),',
        '--   pa = parent quest (only while it is in your log), bc = breadcrumb for (that one taken or done: gone), sp = spell known (negative: not known),',
        '--   mx = max level, uc = gone once this is done, sw = only once this is taken or done, dq = {not while these are in your log},',
        '--   ra = only these races (Horde: O Orc, U Undead, T Tauren, R Troll, S Skyborne; Alliance: H Human, D Dwarf, N Night Elf, G Gnome, A Skyborne), cl = only these classes',
        '--   (W Warrior, P Paladin, H Hunter, R Rogue, I Priest, S Shaman, M Mage, L Warlock, D Druid), cq = a class quest,',
        '--   o = { {kind k/o/i, label, {mob names}, {{uiMapID, x, y, mob#}, ...}}, ... } }',
        'local _, RG = ...', 'RG.QDATA = {']
open(RET + 'Objectives.lua', 'w', encoding='utf-8').write('\n'.join(head) + '\n' + ',\n'.join(out) + '\n}\n')
print(f'{nq} quests, {nobj} objectives, {npts} points', file=sys.stderr)
