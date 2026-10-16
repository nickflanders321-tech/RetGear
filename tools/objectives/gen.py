"""Build Objectives.lua: for every quest a Horde character can take (any race, any class),
who gives it, where to finish it and where its objectives are (kill / loot / use), from
QuestieDB's merged WoW Forever data (see tools/qdb). Race- and class-only quests carry
ra = race letters and cl = class letters; the add-on filters them for your character.
Usage: python3 gen.py <QuestieDB checkout> <forever.json from dump.lua> [Waypath+ folder]"""
import json, re, sys, os
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
RACES = [(2, 'O'), (16, 'U'), (32, 'T'), (128, 'R'), (8589934592, 'S')]
HORDE = sum(b for b, _ in RACES)
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
        x, y = min(pts, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
        out.append((ui[z], round(x, 1), round(y, 1)))
        if len(out) >= maxzones: break
    return out
def L(o):  # objective entry as a 1-based list
    if isinstance(o, dict): return [o.get(str(i)) for i in range(1, 5)]
    return list(o) + [None] * 4
def lstr(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

out, nq, nobj, npts = [], 0, 0, 0
for qid, q in sorted(D['quests'].items(), key=lambda kv: int(kv[0])):
    name, starts, ends, reqlvl, qlvl, races, objectives, zone, sflags, classes, preG, preS, excl = [at(q, i) for i in range(1, 14)]
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
            for p in rep_points(sp, zone, 2): pts.append(p + (len(mobs) if skind == 'npc' else 0,))
        if pts or mobs:
            objs.append((kind, label, mobs, pts[:6])); npts += len(pts[:6])
    for o in map(L, at(objectives, 1) or []):          # kill
        n, _ = spawns_of('npc', o[0]); add('kill', (o[1] if len(o) > 1 and o[1] else n) or '?', [('npc', o[0])])
    for o in map(L, at(objectives, 2) or []):          # use / interact with an object
        n, _ = spawns_of('obj', o[0]); add('object', (o[1] if len(o) > 1 and o[1] else n) or '?', [('obj', o[0])])
    for o in map(L, at(objectives, 3) or []):          # loot an item
        it = D['items'].get(str(o[0]))
        if not it: continue
        srcs = [('npc', i) for i in (at(it, 2) or [])] + [('obj', i) for i in (at(it, 3) or [])]
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
        "-- Generated from QuestieDB's WoW Forever data (coordinates already converted to Forever's maps):",
        '-- https://github.com/Questie/QuestieDB  ·  rebuild with tools/objectives.',
        '-- [questID] = { e = {uiMapID, x, y, finisher}, s = {uiMapID, x, y, giver}, n = name, r = required level, l = quest level,',
        '--   pg = {all of these first}, ps = {any of these first}, x = {done one of these: this one is gone},',
        '--   ra = only these races (O Orc, U Undead, T Tauren, R Troll, S Skyborne), cl = only these classes',
        '--   (W Warrior, P Paladin, H Hunter, R Rogue, I Priest, S Shaman, M Mage, L Warlock, D Druid), cq = a class quest,',
        '--   o = { {kind k/o/i, label, {mob names}, {{uiMapID, x, y, mob#}, ...}}, ... } }',
        'local _, RG = ...', 'RG.QDATA = {']
open(RET + 'Objectives.lua', 'w', encoding='utf-8').write('\n'.join(head) + '\n' + ',\n'.join(out) + '\n}\n')
print(f'{nq} quests, {nobj} objectives, {npts} points', file=sys.stderr)
