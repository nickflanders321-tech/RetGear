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
Usage: python3 gen.py <QuestieDB checkout> <forever.json from dump.lua> [Waypath+ folder] [--sql classic.sql] [--fixes forever-db]
       [--guides <Polestar>/guides]: where Polestar's guides (GPL-3.0) do objectives none of the data shows"""
import json, re, sys, os
SQL = None
FIXES = None
GUIDES = None   # Polestar's guides folder: where they do objectives the data has no spot for
if '--guides' in sys.argv:
    i = sys.argv.index('--guides'); GUIDES = sys.argv[i + 1]; del sys.argv[i:i + 2]
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
HORDE_BITS = 2 | 16 | 32 | 128 | 8589934592      # Orc, Undead, Tauren, Troll, Skyborne (Horde)
ALLY_BITS = 1 | 4 | 8 | 64 | 4294967296           # Human, Dwarf, Night Elf, Gnome, Skyborne (Alliance)
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
# How often an item drops, from forever-db's item sources (CC BY 4.0): (item, 'npc' or 'object', id) -> percent.
# Read before the cMaNGOS tables: it knows Forever's own items too. SURE_DROP: the same as tools/routes/gen.py's.
CHANCE = {}
REQ = {}   # quest -> {item: how many} (cMaNGOS quest_template, with --sql)
BOND = {}  # item -> 1 bound when picked up, 4 a quest item (cMaNGOS item_template, with --sql): neither can be bought
SURE_DROP = 90
if FIXES and os.path.exists(os.path.join(FIXES, 'data', 'item_source.jsonl')):
    for _line in open(os.path.join(FIXES, 'data', 'item_source.jsonl'), encoding='utf-8'):
        _r = json.loads(_line)
        if _r.get('chance') is not None: CHANCE[(_r['item'], _r['kind'], _r['id'])] = _r['chance']
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
    # how many of each item a quest asks for (QuestieDB's objectives don't say): for quests you can only take once you
    # have the items (see bi below)
    qc = _cols('quest_template'); qe = qc.index('entry')
    qi = [(qc.index('ReqItemId%d' % n), qc.index('ReqItemCount%d' % n)) for n in range(1, 5)]
    for r in _rows('quest_template'):
        try: REQ[int(r[qe])] = {int(r[a]): int(r[b]) for a, b in qi if int(r[a]) > 0}
        except Exception: pass
    ic = _cols('item_template'); ii, ib = ic.index('entry'), ic.index('bonding')
    for r in _rows('item_template'):
        try: BOND[int(r[ii])] = int(r[ib])
        except Exception: pass
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
        if isinstance(q, dict): return [q.get(str(i)) for i in range(1, 28)]
        return list(q) + [None] * (27 - len(q))
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

# Hand-checked places for quests QuestieDB has no spot for (an event, somewhere to go): places.json, each with where it
# was checked
PLACES = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'places.json'), encoding='utf-8'))
PLACES = {k: v for k, v in PLACES.items() if not k.startswith('_')}
def vals(v):   # a Lua array from the dump (a list, or a dict when it had holes), as a list
    if v is None: return []
    if isinstance(v, dict): return [v[k] for k in sorted(v, key=lambda k: int(k) if k.isdigit() else 0)]
    return list(v)
def places(spawn, prefer_zone):
    """QuestieDB's {[areaID] = {{x, y}, ...}} as {(uiMapID, x, y, 0), ...}, the preferred zone first."""
    out = []
    if isinstance(spawn, list): spawn = {str(i + 1): v for i, v in enumerate(spawn) if v}   # (area 1 alone dumps as a list)
    if not isinstance(spawn, dict): return out
    for z, pts in sorted(spawn.items(), key=lambda kv: 0 if str(kv[0]) == str(prefer_zone) else 1):
        if not str(z).lstrip('-').isdigit() or int(z) not in ui: continue
        for p in vals(pts):
            p = vals(p)
            if len(p) >= 2 and p[0] is not None and p[1] is not None and p[0] >= 0:
                pt = (ui[int(z)], round(p[0], 1), round(p[1], 1), 0)
                if pt not in out: out.append(pt)
    return out

# Where Polestar's guides (GPL-3.0, like Waypath+; by the Polestar authors) do a quest's objective: for quests none of
# the data above has a spot for. Their lines give the spot (@x,y, on the step's or guide's zone unless "map N" says), the
# objective (quest N.k) and a note ("-- fill the gourd"). Guides on other coordinates ("coords era": exploration and
# professions) are left out, and so are items you bring rather than go somewhere for ("in your bags", "made by", "bought").
PS = {}
PS_VERBS = ('complete', 'use', 'interact', 'explore', 'kill', 'collect', 'talk')
PS_SKIP = re.compile(r'in your bags|made by|bought|\bbuy\b|vendor|auction house|raid of|play (a )?games?|\binside\b|\braid\b', re.I)
PS_BRING = re.compile(r'\s*(Bring|Obtain|Acquire|Deliver|Turn in|Earn|Gain)\b')
PS_NOMAP = {1459, 1460, 1461}   # (the battlegrounds: Alterac Valley, Warsong Gulch, Arathi Basin)
PS_DUNGEON = set()   # (the area IDs of dungeons and raids: their quests are done inside, where the arrow rests)
if GUIDES and os.path.isdir(GUIDES):
    dsrc = open(QDB + 'support/Forever/Zones/dungeons.lua', encoding='utf-8').read()
    for m in re.finditer(r'^\s*\[(\d+)\]\s*=\s*\{"[^"]*",(\{[\d,]*\}|nil)', dsrc, re.M):
        PS_DUNGEON.add(int(m.group(1)))
        PS_DUNGEON |= {int(x) for x in re.findall(r'\d+', m.group(2))}
    for m in re.finditer(r'\[(\d+)\]\s*=\s*(\d+),\s*--\s*Referenced dungeon area', open(QDB + 'support/Forever/Zones/areaIdToUiMapId.lua').read()):
        PS_DUNGEON.add(int(m.group(1)))
    zname = {}
    for m in re.finditer(r'\[(\d+)\]\s*=\s*(\d+),\s*--\s*([^\n]+?)\s*$', open(QDB + 'support/Forever/Zones/areaIdToUiMapId.lua').read(), re.M):
        zname.setdefault(m.group(3).split(' -> ')[0].strip(), int(m.group(2)))
    # (WoW Forever's own zones, which QuestieDB's area table doesn't name: their uiMapIDs in the client's UiMap table)
    zname.update({'Mount Hyjal': 2482, 'Zephras Isle': 2521, 'Riverglades': 2548, "Shen'dralas": 2652, 'Darkspear Islands': 2524})
    nozone = set()
    for root, _, files in os.walk(GUIDES):
        for fn in sorted(files):
            if not fn.endswith('.guide') or fn.startswith('dungeon-set') or 'collectibles' in root: continue   # (armour sets, mounts and pets)
            path = os.path.join(root, fn)
            text = open(path, encoding='utf-8').read()
            if re.search(r'^coords era', text, re.M): continue
            gzone = szone = None
            for n, raw in enumerate(text.splitlines(), 1):
                s = raw.strip()
                if not s or s.startswith('#'): continue
                if not raw.startswith((' ', '\t')):
                    if s.startswith('zone '): gzone = s[5:].strip()
                    if s.startswith('step'): szone = None
                    continue
                if s.startswith('zone '): szone = s[5:].strip(); continue
                verb = s.split(' ', 1)[0]
                if verb not in PS_VERBS: continue
                code, _, note = s.partition('--')
                pos = re.search(r'@([\d.]+),([\d.]+)', code)
                if not pos or PS_SKIP.search(note): continue
                qs = [(int(a), int(b) if b else 0) for a, b in re.findall(r'quest (\d+)(?:\.(\d+))?', code)]
                m = re.match(r'complete (\d+)', s)
                if m: qs.append((int(m.group(1)), 0))
                mm = re.search(r'\bmap (\d+)', code)
                zn = szone or gzone or ''
                zm = re.match(r'map (\d+)$', zn)   # (a zone given by its map: "zone map 2521")
                mp = int(mm.group(1)) if mm else (int(zm.group(1)) if zm else zname.get(zn))
                if not mp: nozone.add(szone or gzone); continue
                if mp in PS_NOMAP: continue
                for q, k in qs:
                    PS.setdefault(q, []).append((k, verb, note.strip(), (mp, round(float(pos.group(1)), 1), round(float(pos.group(2)), 1), 0)))
    print('Polestar guides: spots for %d quests%s' % (len(PS), ('; zones not known: ' + ', '.join(sorted(z for z in nozone if z))) if nozone else ''), file=sys.stderr)
def ps_label(verb, note, qname):
    note = re.split(r'\s*\(', note)[0].strip().rstrip(',.;:')
    if not note: return qname
    # (a note that names something, "Tree Sprouting Kit", gets the line's verb; one that already says what to do,
    # "grind the eight cones into the Pine Salve", is the label as it is)
    pre = {'talk': 'Talk to ', 'kill': 'Kill ', 'use': 'Use ', 'collect': 'Collect '}.get(verb, '') if note[0].isupper() else ''
    return pre + note if pre else note[0].upper() + note[1:]
def ps_places(qid, qname):
    """A quest's spots in Polestar's guides as places: one per objective (quest N.k), in the objectives' order, the
    spots of the lines that only say where it's finished last; the same spot from several guides once."""
    groups = {}
    for k, verb, note, pt in PS.get(qid, []):
        g = groups.setdefault(k, {'label': None, 'pts': []})
        if not g['label'] and note: g['label'] = ps_label(verb, note, qname)
        if not any(p[0] == pt[0] and abs(p[1] - pt[1]) < 1 and abs(p[2] - pt[2]) < 1 for p in g['pts']): g['pts'].append(pt)
    return [(g['label'] or qname, g['pts'][:8]) for k, g in sorted(groups.items(), key=lambda kv: (kv[0] == 0, kv[0]))]

out, nq, nobj, npts = [], 0, 0, 0
for qid, q in sorted(D['quests'].items(), key=lambda kv: int(kv[0])):
    name, starts, ends, reqlvl, qlvl, races, objectives, zone, sflags, classes, preG, preS, excl = [at(q, i) for i in range(1, 14)]
    reqSkill, minRep, maxRep, nextQ, parentQ, crumbFor, reqSpell, maxLvl, untilDone, startWith, disabledBy = [at(q, i) for i in range(14, 25)]
    trigger, extras, otext = at(q, 25), at(q, 26), ' '.join(str(t) for t in vals(at(q, 27)) if t)
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
            if pts: end = (pts[0], n, i if kind == 'npc' else None); break
        if end: break
    objs = []
    def add(kind, label, sources, thing=None, item=None):
        """thing = the item or object the objective is about (its ID, for its icon); item = the item to loot, for the
        drop chance of each mob (Polestar forever-db's item sources first, else the cMaNGOS loot tables)."""
        global npts
        pts, mobs, ids, chances = [], [], [], []
        for si, (skind, sid) in enumerate(sources[:4]):
            sname, sp = spawns_of(skind, sid)
            if not sname: continue
            if skind == 'npc' and sname not in mobs:
                mobs.append(sname); ids.append(int(sid))
                ch = item and CHANCE.get((int(item), 'npc', int(sid)))
                if item and ch is None: ch = DROP.get(sid, {}).get(int(item))
                chances.append(ch or 0)
            for p in cluster_points(sp, zone, 2, 4 if si == 0 else 2): pts.append(p + (len(mobs) if skind == 'npc' else 0,))
        if pts or mobs:
            objs.append((kind, label, mobs, pts[:8], ids, thing, chances if item and any(chances) else None)); npts += len(pts[:8])
    for o in map(L, at(objectives, 1) or []):          # kill
        n, _ = spawns_of('npc', o[0]); add('kill', (o[1] if len(o) > 1 and o[1] else n) or '?', [('npc', o[0])])
    for o in map(L, at(objectives, 2) or []):          # use / interact with an object
        n, _ = spawns_of('obj', o[0]); add('object', (o[1] if len(o) > 1 and o[1] else n) or '?', [('obj', o[0])], thing=o[0])
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
        add('item', at(it, 1) or '?', srcs, thing=o[0], item=o[0])
    for o in map(L, at(objectives, 5) or []):          # kill credit (several mobs count)
        ids = o[0] if isinstance(o[0], list) else []
        add('kill', (o[2] if len(o) > 2 and o[2] else '?'), [('npc', i) for i in ids])
    # places: an event or somewhere to reach, which the objectives above can't show (release the kitten at the moonwell,
    # scout the mine). In the order they're done: what to do first (QuestieDB's extraObjectives, only for a quest with
    # no other spot to show), then the place the quest's event ends (triggerEnd). A hand-checked place replaces them.
    hand = PLACES.get(str(qid))
    if hand:
        for h in hand['o']:
            pts = [(int(h['map']), round(float(x), 1), round(float(y), 1), 0) for x, y in h['pts']][:8]
            objs.append(('event', h['text'], [], pts, [], h.get('item'), None)); npts += len(pts)
    else:
        if not any(o[3] for o in objs):
            for e in map(lambda e: [at(e, i) for i in range(1, 6)], vals(extras)):
                spawn, text, refs = e[0], e[2], e[4]
                pts = places(spawn, zone)
                for r in vals(refs):
                    if pts: break
                    kind, rid = at(r, 1), at(r, 2)
                    if kind in ('object', 'monster') and rid:
                        _, sp = spawns_of('obj' if kind == 'object' else 'npc', rid)
                        pts = [p + (0,) for p in cluster_points(sp, zone, 2, 4)]
                if pts and text:
                    objs.append(('event', text, [], pts[:8], [], None, None)); npts += len(pts[:8])
        if trigger:
            text, pts = at(trigger, 1), places(at(trigger, 2), zone)
            if pts and text:
                objs.append(('event', text, [], pts[:8], [], None, None)); npts += len(pts[:8])
        # nothing in the data shows where: Polestar's guides (not for a quest that asks you to bring something, where their
        # line is only where they had it: armour set pieces, crafted goods, raid drops)
        if not any(o[3] for o in objs) and not PS_BRING.match(otext) and zone not in PS_DUNGEON:
            for text, pts in ps_places(int(qid), name or '?'):
                objs.append(('event', text, [], pts, [], None, None)); npts += len(pts)
    # who gives it (NPC only; item-started quests show up by themselves)
    start = None
    givers = at(starts, 1) or []
    # a quest only one faction's NPCs hand out is that faction's: its race letters say so (Alliance quests used to be
    # left out here, from when the add-on was Horde-only; Horde ones carried no letters, so Alliance characters were
    # told they could take them). The add-on drops the other faction's quests at load (RG.PruneQuests).
    gfac = None
    if givers:
        facs = {(at(D['npcs'].get(str(i)) or [], 3) or 'AH') for i in givers}
        if facs == {'A'}: gfac = ALLY_BITS
        elif facs == {'H'}: gfac = HORDE_BITS
    if gfac:
        eff = (races or HORDE) & gfac
        if not eff: continue                      # e.g. an Alliance giver for a Horde-race quest: nobody can take it
        ra = ''.join(c for b, c in RACES if eff & b)
    for i in givers:
        n, sp = spawns_of('npc', i)
        pts = rep_points(sp, zone, 1)
        if pts: start = (pts[0], n, i); break
    # where a quest no NPC hands out begins: an object to click, or an item from a mob or a chest (si; sure = it
    # always drops there, so the route can send you; otherwise the add-on shows the quest once you have it)
    si = None
    if not givers:
        for oid in (at(starts, 2) or []):
            n, sp = spawns_of('obj', oid)
            pts = rep_points(sp, zone, 2)
            if pts: si = ('o', n or '?', [], [p + (0,) for p in pts], 1, [], oid, None); break
        for iid in ([] if si else (at(starts, 3) or [])):
            it = D['items'].get(str(iid))
            if not it: continue
            srcs = []
            for kind, sid in [('npc', n) for n in (at(it, 2) or [])] + [('object', o) for o in (at(it, 3) or [])]:
                ch = CHANCE.get((int(iid), kind, int(sid)))
                if ch is None and kind == 'npc': ch = DROP.get(sid, {}).get(int(iid))
                srcs.append((-(ch or 0), kind, sid))
            srcs.sort(key=lambda x: x[0])
            mobs, pts, ids, chances = [], [], [], []
            for ch, kind, sid in srcs[:3]:
                n, sp = spawns_of('npc' if kind == 'npc' else 'obj', sid)
                if not n: continue
                if kind == 'npc' and n not in mobs: mobs.append(n); ids.append(int(sid)); chances.append(-ch)
                for p in cluster_points(sp, zone, 2, 2): pts.append(p + (len(mobs) if kind == 'npc' else 0,))
            if pts:
                si = ('i', at(it, 1) or '?', mobs, pts[:4], 1 if srcs and -srcs[0][0] >= SURE_DROP else 0, ids, int(iid),
                      chances if any(chances) else None); break
    if not objs and not end and not start and not name: continue
    nq += 1; nobj += len(objs)
    parts = []
    if end: parts.append('e={%d,%.1f,%.1f,%s%s}' % (end[0][0], end[0][1], end[0][2], lstr(end[1] or ''), (',%d' % end[2]) if end[2] else ''))
    # s = where to pick it up (only for quests offered as "new": not repeatables)
    if start and not ((sflags or 0) & 1):
        parts.append('s={%d,%.1f,%.1f,%s,%d}' % (start[0][0], start[0][1], start[0][2], lstr(start[1] or ''), start[2]))
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
    if si and not ((sflags or 0) & 1):
        parts.append('si={%s,%s,{%s},{%s},%d,{%s},%d%s}' % (lstr(si[0]), lstr(si[1]), ','.join(lstr(m) for m in si[2]),
                     ','.join('{%d,%.1f,%.1f,%d}' % p for p in si[3]), si[4], ','.join(str(i) for i in si[5]), si[6],
                     (',{%s}' % ','.join('%g' % round(c, 1) for c in si[7])) if si[7] else ''))
    if (sflags or 0) & 1: parts.append('rep=true')
    # a quest you can only take once you have its items: items to bring and no words for its objectives (Salve via
    # Hunting, cloth donations, library books: talking to the giver opens the hand-in, Continue greyed out without them)
    bring = [L(o)[0] for o in (at(objectives, 3) or [])]
    if bring and not (at(objectives, 1) or at(objectives, 2) or at(objectives, 5)) and not otext.strip():
        parts.append('bi={%s}' % ','.join('{%d,%d}' % (int(i), REQ.get(int(qid), {}).get(int(i), 1)) for i in bring))
    # what it asks you to bring that nothing drops out in the world: bought from a vendor (v: where, and for which
    # faction), or crafted and sold on the auction house (a); not quest items, nor ones bound when picked up (they come
    # from the quest itself), and not for repeatable or donation quests (only reputation)
    br = []
    # (nor where the quest has you gather or fish them yourself: "Gather 10 Nightmare Moss in the Duskwood Nightmare
    # Incursions", "Fish up 10 Winter Squid"; nor quests no longer in the game)
    gather = re.match(r'\s*(Gather|Fish|Collect|Mine|Loot|Kill|Recover|Search|Hunt|Slay)\b', otext) or 'no longer available' in otext
    if not ((sflags or 0) & 1) and not gather and not re.match(r'(A Donation of|Additional Runecloth)', name or ''):
        for i in bring:
            it = D['items'].get(str(i))
            if not it or at(it, 2) or at(it, 3): continue
            n = REQ.get(int(qid), {}).get(int(i))
            if n is None:   # (a quest cMaNGOS doesn't have, WoW Forever's own: "Bring 2 Dense Sharpening Stones")
                m = re.search(r'(\d+)\s+' + re.escape(str(at(it, 1) or '')[:12]), otext)
                n = int(m.group(1)) if m else 1
            # one vendor per faction, the one on the quest's own map when there is one
            target = end[0][0] if end else ui.get(zone)
            byfac = {}
            for v in vals(at(it, 5)):
                vn, sp = spawns_of('npc', v)
                pts = rep_points(sp, zone, 1)
                fac = at(D['npcs'].get(str(v)) or [], 3) or 'AH'
                if pts and vn and (fac not in byfac or (byfac[fac][0][0] != target and pts[0][0] == target)):
                    byfac[fac] = (pts[0], vn, fac)
            vend = sorted(byfac.values(), key=lambda x: (x[0][0] != target, x[2]))
            if vend:
                for (m, x, y), vn, fac in vend[:2]:
                    br.append('{%d,%d,"v",%d,%.1f,%.1f,%s,"%s"}' % (int(i), n, m, x, y, lstr(vn), fac))
            elif at(it, 4) != 12 and BOND.get(int(i)) not in (1, 4):
                br.append('{%d,%d,"a"}' % (int(i), n))
    if br: parts.append('br={%s}' % ','.join(br))
    if ra: parts.append('ra="%s"' % ra)
    if cl: parts.append('cl="%s"' % cl)
    if cl and len(cl) <= 4: parts.append('cq=true')   # a real class quest (not a "most classes" variant)
    if objs:
        os_ = []
        for kind, label, mobs, pts, ids, thing, chances in objs:
            extra = ''
            if ids or thing or chances:
                extra = ',{%s},%s' % (','.join(str(i) for i in ids), str(int(thing)) if thing else 'nil')
                if chances: extra += ',{%s}' % ','.join('%g' % round(c, 1) for c in chances)
            os_.append('{%s,%s,{%s},{%s}%s}' % (lstr(kind[0]), lstr(label), ','.join(lstr(m) for m in mobs),
                       ','.join('{%d,%.1f,%.1f,%d}' % p for p in pts), extra))
        parts.append('o={' + ','.join(os_) + '}')
    out.append('[%s]={%s}' % (qid, ','.join(parts)))
head = ['-- Waypath+ quest objectives: where to finish each quest and where its objectives are.',
        "-- Generated from QuestieDB's WoW Forever data (coordinates already converted to Forever's maps), with the hand-checked",
        "-- fixes of Polestar's forever-db (corrections layer, CC BY 4.0, by the Polestar authors) on top, and the places where",
        "-- Polestar's guides (GPL-3.0, by the Polestar authors) do objectives the data has no spot for:",
        '-- https://github.com/Questie/QuestieDB  ·  rebuild with tools/objectives.',
        '-- [questID] = { e = {uiMapID, x, y, finisher}, s = {uiMapID, x, y, giver}, n = name, r = required level, l = quest level,',
        '--   pg = {all of these first}, ps = {any of these first}, x = {done one of these: this one is gone},',
        '--   sk = {skill, rank}, rp = {faction, min rep}, rx = {faction, max rep}, nx = next in chain (taken or done: this one is gone),',
        '--   pa = parent quest (only while it is in your log), bc = breadcrumb for (that one taken or done: gone), sp = spell known (negative: not known),',
        '--   mx = max level, uc = gone once this is done, sw = only once this is taken or done, dq = {not while these are in your log},',
        '--   bi = {{item, how many}, ...}: taken only with these items in your bags (talking to the giver hands them in),',
        '--   br = {{item, how many, "a"}, {item, how many, "v", uiMapID, x, y, vendor, factions}, ...}: what it asks you to bring that',
        '--     nothing drops: bought on the auction house (a) or from a vendor (v; factions A/H/AH),',
        '--   ra = only these races (Horde: O Orc, U Undead, T Tauren, R Troll, S Skyborne; Alliance: H Human, D Dwarf, N Night Elf, G Gnome, A Skyborne), cl = only these classes',
        '--   (W Warrior, P Paladin, H Hunter, R Rogue, I Priest, S Shaman, M Mage, L Warlock, D Druid), cq = a class quest,',
        '--   (e and s: a 5th value is the NPC\'s ID)',
        '--   o = { {kind k/o/i, label, {mob names}, {{uiMapID, x, y, mob#}, ...}, {mob NPC IDs}, item or object ID, {drop % per mob}}, ... },',
        '--     (kind e: an event or a place to reach, its label says what to do there; done in the order listed)',
        '--   si = {o/i, object or item that starts it, {mob names}, {{uiMapID, x, y, mob#}, ...}, 1 = always drops there / 0 = only sometimes,',
        '--         {mob NPC IDs}, item or object ID, {drop % per mob}} }',
        'local _, RG = ...', 'RG.QDATA = {']
# where the auction houses are: an auctioneer per map and faction (for the guide's shopping stop before a zone)
ahs = {}
for nid, npc in sorted(D['npcs'].items(), key=lambda kv: int(kv[0])):
    n = at(npc, 1)
    if not (isinstance(n, str) and n.startswith('Auctioneer ')): continue
    _, sp = spawns_of('npc', nid)
    pts = rep_points(sp, 0, 1)
    fac = at(npc, 3) or 'AH'
    if pts and (pts[0][0], fac) not in ahs: ahs[(pts[0][0], fac)] = (pts[0], n, fac)
tail = ["-- the auction houses: { uiMapID, x, y, auctioneer, factions (A, H or AH) }", 'RG.AUCTIONEERS = {']
tail += ['  {%d,%.1f,%.1f,%s,"%s"},' % (p[0], p[1], p[2], lstr(n), fac) for (p, n, fac) in sorted(ahs.values())]
tail.append('}')
open(RET + 'Objectives.lua', 'w', encoding='utf-8').write('\n'.join(head) + '\n' + ',\n'.join(out) + '\n}\n' + '\n'.join(tail) + '\n')
print(f'{nq} quests, {nobj} objectives, {npts} points', file=sys.stderr)
