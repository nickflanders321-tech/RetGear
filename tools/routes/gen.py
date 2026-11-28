"""Build Routes/Generated.lua: step-by-step quest lists for the starting zones of every
Horde race, from QuestieDB's merged WoW Forever data (see tools/qdb).

For each leg (race, zone, level range) it takes every quest that race can do there,
orders them by level and quest chain, and groups them by quest hub so each step is one
stop: "At Razor Hill, pick up: A, B, C". Each step carries its quest IDs (it ticks itself
off when all of them are turned in) and a waypoint for the hub. Class quests and quests
from an item that only sometimes drops ride along in the step nearest where they start
(or end) without being named: the add-on shows them to the right class, or once you have them.

Usage: python3 gen.py <QuestieDB checkout> <forever.json from tools/objectives/dump.lua> [Waypath+ folder]
"""
import json, re, sys, os, math

# --fixes <Polestar forever-db>: its hand-checked quest sides (CC BY 4.0), as tools/objectives/gen.py uses them
FIXES = None
if '--fixes' in sys.argv:
    i = sys.argv.index('--fixes'); FIXES = sys.argv[i + 1]; del sys.argv[i:i + 2]
QDB = sys.argv[1].rstrip('/') + '/'
def _sorted_pairs(kv):
    """Dicts from the Lua dumps come in random order; sort keys (numbers first) so every run picks the same spawn."""
    def k(x):
        s = x[0]
        return (0, int(s), '') if s.lstrip('-').isdigit() else (1, 0, s)
    return dict(sorted(kv, key=k))
D = json.load(open(sys.argv[2], encoding='utf-8'), object_pairs_hook=_sorted_pairs)
# Hand-checked NPC facts QuestieDB has wrong (tools/objectives/npcs.json): a giver's faction, which makes their quests one faction's
for _nid, _fix in json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'objectives', 'npcs.json'), encoding='utf-8')).items():
    _e = D['npcs'].get(_nid)
    if _nid.startswith('_') or _e is None or 'faction' not in _fix: continue
    if isinstance(_e, dict): _e['3'] = _fix['faction']
    else: _e = list(_e) + [None] * max(0, 3 - len(_e)); _e[2] = _fix['faction']; D['npcs'][_nid] = _e
if FIXES and os.path.exists(os.path.join(FIXES, 'corrections', 'quests.json')):
    _corr = json.load(open(os.path.join(FIXES, 'corrections', 'quests.json'), encoding='utf-8'))
    for _k, _v in _corr.items():
        _q = D['quests'].get(_k)
        if _v.get('remove'): D['quests'].pop(_k, None); continue
        _st = _v.get('set') or {}
        for _f, _i in (('races', 6), ('classes', 10)):     # who can take it (a class quest stays out of the route)
            if _q is None or _f not in _st: continue
            if isinstance(_q, dict): _q[str(_i)] = _st[_f]
            else:
                _q = list(_q) + [None] * max(0, _i - len(_q)); _q[_i - 1] = _st[_f]; D['quests'][_k] = _q
# How often an item drops, from forever-db's item sources (CC BY 4.0): (item, 'npc' or 'object', id) -> percent.
# A quest that starts from an item that always drops (or lies in a chest) goes in the route like any other: the step
# sends you to the mob or the object. One that only sometimes drops goes in the step where it's handed in, and the
# add-on shows it only once you have it (Objectives.lua's si; keep SURE_DROP the same in tools/objectives/gen.py).
CHANCE = {}
SURE_DROP = 90
if FIXES and os.path.exists(os.path.join(FIXES, 'data', 'item_source.jsonl')):
    for _line in open(os.path.join(FIXES, 'data', 'item_source.jsonl'), encoding='utf-8'):
        _r = json.loads(_line)
        if _r.get('chance') is not None: CHANCE[(_r['item'], _r['kind'], _r['id'])] = _r['chance']
OUT = (sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')).rstrip('/') + '/'
ui = {int(a): int(b) for a, b in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', open(QDB + 'support/Forever/Zones/areaIdToUiMapId.lua').read())}
def areas_of(uimap, also=()):
    """Every area (and sub-area) that sits on one world map: a new zone's quests are filed under its sub-areas too."""
    return sorted({a for a, m in ui.items() if m == uimap} | set(also))
RIVERGLADES, HYJAL, SHENDRALAS = areas_of(2548), areas_of(2482, [616]), areas_of(2652, [16651])

RACE_BITS = {'O': 2, 'U': 16, 'T': 32, 'R': 128, 'S': 8589934592,
             'H': 1, 'D': 4, 'N': 8, 'G': 64, 'A': 4294967296}
HORDE_ALL = 2 | 16 | 32 | 128 | 8589934592
ALLY_ALL = 1 | 4 | 8 | 64 | 4294967296
RACE_BITS['F'] = ALLY_ALL     # F = steps shared by every Alliance race
RACE_BITS['X'] = HORDE_ALL    # X = steps shared by every Horde race

# Alliance zones after the starting zones: (name, from, to, [area ids]). The route entries in
# Routes/Alliance.lua use the same names and starting levels as their keys ("Zone|from").
ALLIANCE_ZONES = [
    ('Westfall', 10, 18, [40]), ('Loch Modan', 10, 18, [38]), ('Darkshore', 12, 21, [148]),
    ('Redridge Mountains', 15, 24, [44]), ('Stonetalon Mountains', 18, 27, [406]), ('Duskwood', 22, 30, [10]),
    ('Ashenvale', 20, 30, [331]), ('Wetlands', 21, 31, [11]), ('Hillsbrad Foothills', 22, 35, [267]),
    ('Dustwallow Marsh', 35, 45, [15]), ('Thousand Needles', 30, 42, [400]), ('Desolace', 31, 41, [405]),
    ('Arathi Highlands', 33, 40, [45]), ('Stranglethorn Vale', 32, 48, [33]), ('Swamp of Sorrows', 35, 42, [8]),
    ('Badlands', 37, 44, [3]), ('Alterac Mountains', 33, 40, [36]), ("Shen'Dralas", 38, 43, SHENDRALAS),
    ('Riverglades', 36, 44, RIVERGLADES), ('Mount Hyjal', 57, 60, HYJAL),
    ('Feralas', 41, 48, [357]), ('The Hinterlands', 43, 49, [47]), ('Searing Gorge', 45, 50, [51]),
    ('Tanaris', 41, 50, [440]), ("Un'Goro Crater", 50, 55, [490]), ('Felwood', 50, 56, [361]),
    ('Burning Steppes', 50, 58, [46]), ('Blasted Lands', 50, 58, [4]), ('Western Plaguelands', 51, 58, [28]),
    ('Azshara', 54, 60, [16]), ('Winterspring', 53, 59, [618]), ('Silithus', 55, 60, [1377]),
    ('Eastern Plaguelands', 54, 60, [139]),
]

# Legs of each race's start. zones = quest categories (area IDs) the leg's quests belong to.
# key must match the route entry in Races/<Race>.lua ("Zone|from").
# Horde zones after the starting zones, keyed like Routes/Horde.lua ("Zone|from"): (name, from, to, [area ids], min quest level).
# Quests below the minimum level belong to an earlier leg (The Barrens 12-20 is each race's own).
HORDE_ZONES = [
    ('The Barrens', 18, 26, [17], 20), ('Stonetalon Mountains', 18, 27, [406], 0), ('Hillsbrad Foothills', 21, 31, [267], 0),
    ('Ashenvale', 22, 30, [331], 0), ('Thousand Needles', 26, 35, [400], 0), ('Arathi Highlands', 33, 40, [45], 0),
    ('Desolace', 31, 40, [405], 0), ('Stranglethorn Vale', 32, 45, [33], 0), ('Dustwallow Marsh', 36, 45, [15], 0),
    ('Badlands', 38, 45, [3], 0), ('Swamp of Sorrows', 38, 45, [8], 0), ('Tanaris', 41, 50, [440], 0),
    ('Feralas', 42, 50, [357], 0), ('The Hinterlands', 44, 52, [47], 0), ('Searing Gorge', 48, 54, [51], 0),
    ("Un'Goro Crater", 50, 55, [490], 0), ('Felwood', 51, 55, [361], 0), ('Burning Steppes', 50, 58, [46], 0),
    ('Winterspring', 55, 60, [618], 0), ('Western & Eastern Plaguelands', 52, 60, [28, 139], 0),
    ('Azshara', 50, 58, [16], 0), ('Silithus', 55, 60, [1377], 0),
    # new WoW Forever zones: their quests arrive with the launch data, and the steps build themselves then
    ('Riverglades', 36, 44, RIVERGLADES, 0), ("Shen'dralas", 38, 43, SHENDRALAS, 0), ('Mount Hyjal', 57, 60, HYJAL, 0),
]
HORDE_ANCHORS = {
    406: [('Sun Rock Retreat', 'Innkeeper Jayka')], 267: [('Tarren Mill', 'Innkeeper Shay')],
    331: [('Splintertree Post', 'Innkeeper Kaylisk'), ("Zoram'gar Outpost", 'Vhulgra')],
    400: [('Freewind Post', 'Innkeeper Abeqwa')], 45: [('Hammerfall', 'Innkeeper Adegwa')],
    405: [('Shadowprey Village', 'Innkeeper Sikewa')], 33: [("Grom'gol Base Camp", 'Innkeeper Thulbek')],
    15: [('Brackenwall Village', 'Shardi')], 3: [('Kargath', "Innkeeper Shul'kar")], 8: [('Stonard', 'Innkeeper Karakul')],
    357: [('Camp Mojache', 'Innkeeper Greul')], 490: [("Marshal's Refuge", 'Gryfe')], 361: [('Bloodvenom Post', 'Brakkar')],
    46: [('Flame Crest', 'Vahgruk')], 16: [('Valormok', 'Kaerbrus')], 1377: [('Cenarion Hold', 'Commander Mar\'alith')], 139: [("Light's Hope Chapel", 'Georgia')],
}

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
    # Alliance: Human (Northshire, Elwynn), Dwarf and Gnome (Coldridge, Dun Morogh), Night Elf (Shadowglen,
    # Teldrassil), Skyborne (Zephras Isle); everything after that is shared by the whole faction (letter F)
    ('H', 'Northshire Valley', 1, 6, [9]), ('H', 'Elwynn Forest', 6, 12, [12]),
    ('D', 'Coldridge Valley', 1, 6, [132]), ('D', 'Dun Morogh', 6, 12, [1]),
    ('G', 'Coldridge Valley', 1, 6, [132]), ('G', 'Dun Morogh', 6, 12, [1]),
    ('N', 'Shadowglen', 1, 6, [188]), ('N', 'Teldrassil', 6, 12, [141]),
    ('A', 'Zephras Isle', 1, 12, [16593]),
] + [('F',) + z + (0,) for z in ALLIANCE_ZONES] + [('X',) + z for z in HORDE_ZONES]

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
    # Alliance hubs (inns and the people who stand at each start)
    9: [('Northshire Abbey', 'Marshal McBride')],
    132: [('Anvilmar', 'Sten Stoutarm')],
    12: [('Northshire Abbey', 'Marshal McBride'), ('Goldshire', 'Innkeeper Farley')],
    188: [('Shadowglen', 'Melithar Staghelm')],
    141: [('Shadowglen', 'Melithar Staghelm'), ('Dolanaar', 'Innkeeper Keldamyr')],
    40: [('Sentinel Hill', 'Innkeeper Heather')],
    44: [('Lakeshire', 'Innkeeper Brianna')],
    10: [('Darkshire', 'Innkeeper Trelayne')],
    38: [('Thelsamar', 'Innkeeper Hearthstove')],
    11: [('Menethil Harbor', 'Innkeeper Helbrek')],
    267: [('Southshore', 'Innkeeper Anderson')],
    148: [('Auberdine', 'Innkeeper Shaussiy')],
    331: [('Astranaar', 'Innkeeper Kimlya')],
    15: [('Theramore Isle', 'Innkeeper Janene')],
    33: [('Booty Bay', 'Innkeeper Skindle')],
    47: [('Aerie Peak', 'Innkeeper Thulfram')],
    357: [('Feathermoon Stronghold', 'Innkeeper Shyria')],
    405: [("Nijel's Point", 'Innkeeper Lyshaerya')],
    440: [('Gadgetzan', 'Innkeeper Fizzgrimble')],
    618: [('Everlook', 'Innkeeper Vizzie')],
    16593: [('the starting grove', 'Rorian the Dayseeker'), ("Shen'dar Village", 'Constable Aonda'),
            ('Falaath Village', 'Missionary Jasaan'), ('Valanaar', 'Valennia Stormfist')],
}
for _z, _a in HORDE_ANCHORS.items(): ANCHORS.setdefault(_z, []).extend(_a)
CITIES = {1637: 'Orgrimmar', 1638: 'Thunder Bluff', 1497: 'Undercity', 1519: 'Stormwind City', 1537: 'Ironforge', 1657: 'Darnassus'}   # a giver anywhere in a capital = that city
HUB_RADIUS = 10.0     # map units: givers this close to an anchor belong to that hub
START_RADIUS = 15.0   # map units: a quest filed elsewhere belongs to a starting zone when its giver is this close to the hub
CAMPING = -666        # QuestieDB's category for Forever's Camping quests (The Great Outdoors, Camping 101: ...)
CLASS_CATEGORIES = {-81, -82, -61, -141, -161, -162, -261, -262, -263}   # QuestieDB's class quest categories (Warrior -81 ...)
ALL_CLASSES = 1 | 2 | 4 | 8 | 16 | 64 | 128 | 256 | 1024
CAPITAL = {'O': 1637, 'R': 1637, 'T': 1638, 'S': 1638, 'U': 1497, 'H': 1519, 'D': 1537, 'G': 1537, 'N': 1657}
# (a stop's quests are split into steps of at most this many: at 8, quests open on the same visit were split into two
# steps and the bot came back for the second; at 14 its runs to 60 had fewer trips back and more quests done)
MAX_PER_STEP = 14

def at(a, i):
    if a is None: return None
    if isinstance(a, dict): return a.get(str(i))
    return a[i - 1] if 0 < i <= len(a) else None

def npc(id_):
    e = D['npcs'].get(str(id_))
    if not e: return None, {}
    sp = at(e, 2) or {}
    return at(e, 1), (sp if isinstance(sp, dict) else {})

# Alliance cities and zones without Horde quest givers (area IDs): a giver who only
# stands there is Alliance even when the data doesn't mark its faction.
ALLIANCE_AREAS = {1, 12, 38, 40, 44, 141, 148, 1519, 1537, 1657, 11, 10}
def alliance_only(givers):
    givers = givers or []
    def ally(i):
        e = D['npcs'].get(str(i)) or []
        if (at(e, 3) or 'AH') == 'A': return True
        sp = at(e, 2) or {}
        zones = {int(z) for z in sp.keys()} if isinstance(sp, dict) else set()
        return bool(zones) and zones <= ALLIANCE_AREAS
    return bool(givers) and all(ally(i) for i in givers)

HORDE_AREAS = {14, 17, 85, 130, 154, 215, 220, 363, 1497, 1637, 1638, 406, 331, 400, 405, 357, 440, 15, 33, 47, 618, 1377}
HORDE_HOME = {14, 85, 130, 154, 215, 220, 363, 1497, 1637, 1638}     # zones with no Alliance presence
def horde_only(givers):
    givers = givers or []
    def hord(i):
        e = D['npcs'].get(str(i)) or []
        if (at(e, 3) or 'AH') == 'H': return True
        sp = at(e, 2) or {}
        zones = {int(z) for z in sp.keys()} if isinstance(sp, dict) else set()
        return bool(zones) and zones <= HORDE_HOME
    return bool(givers) and all(hord(i) for i in givers)
FACTION = ['Horde']        # which faction the leg being built belongs to

npc_by_name = {}
for nid, e in D['npcs'].items():
    n = at(e, 1)
    if n and n not in npc_by_name and isinstance(at(e, 2), dict) and at(e, 2): npc_by_name[n] = at(e, 2)

def first_point(spawns, prefer):
    # preferred zones first, then Horde-side zones before Alliance cities (an NPC who
    # stands in both, like a festival keeper, gets the Horde spot)
    other = HORDE_HOME if FACTION[0] == 'Alliance' else ALLIANCE_AREAS
    rest = sorted(spawns.keys(), key=lambda z: (int(z) in other if str(z).isdigit() else False, str(z)))
    for z in [str(p) for p in prefer] + rest:
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

# The quests each race letter's route has listed so far (legs are built in LEGS order: each race's own legs come
# before the shared ones), so a leg can tell whether a quest's earlier quests were already on the way.
COVERED = {}
WARNINGS = set()   # quests kept although their earlier quest is marked for other races (printed at the end)
LEFT_OUT = []      # quests left out because what they need first can't be had on a questing route (printed at the end)
HORDE_LETTERS, ALLY_LETTERS = 'OURTS', 'HDNGA'
def covered(letter, qid):
    """Is quest qid on this route before the leg being built? For a shared leg (X, F): on every race's route."""
    if letter in ('X', 'F'):
        races = HORDE_LETTERS if letter == 'X' else ALLY_LETTERS
        return all(qid in COVERED.get(r, ()) or qid in COVERED.get(letter, ()) for r in races)
    shared = 'F' if letter in ALLY_LETTERS else 'X'
    return qid in COVERED.get(letter, ()) or qid in COVERED.get(shared, ())

def starter(q, zones):
    """Where a quest that no NPC hands out begins: an object you click, or an item from a mob or a chest. A dict
    (src = the mob or object, point, item = what starts it, sure = it always drops), or None when nothing is known."""
    starts = at(q, 2)
    for oid in (at(starts, 2) or []):
        e = D['objects'].get(str(oid)) or []
        sp = at(e, 2)
        p = isinstance(sp, dict) and first_point(sp, zones)
        if p: return dict(src=at(e, 1) or '?', point=p, item=at(e, 1) or '?', sure=True)
    for iid in (at(starts, 3) or []):
        it = D['items'].get(str(iid))
        if not it: continue
        best = None
        for kind, sid in [('npc', n) for n in (at(it, 2) or [])] + [('object', o) for o in (at(it, 3) or [])]:
            e = D['npcs' if kind == 'npc' else 'objects'].get(str(sid)) or []
            sp = at(e, 2)
            p = isinstance(sp, dict) and first_point(sp, zones)
            if not p: continue
            ch = CHANCE.get((int(iid), kind, int(sid)), 0)
            if not best or ch > best[0]: best = (ch, at(e, 1) or '?', p)
        if best: return dict(src=best[1], point=best[2], item=at(it, 1) or '?', sure=best[0] >= SURE_DROP)
    return None

def make_quest(qid, q, letter, zones):
    """A quest record for a leg, or None when this race can't take it (other race or faction, a repeatable quest, or
    one that starts from an item or object nobody knows the place of). Zone and level are the caller's to check.
    Class quests are kept (cls): the add-on shows each character only its own class's."""
    name, starts, ends, rl, ql, races, objs, z, sflags, classes, preG, preS, excl = [at(q, i) for i in range(1, 14)]
    races = int(races or 0)
    ally = letter in 'HDNGAF'
    cls = bool(classes) and (int(classes) & ALL_CLASSES) != ALL_CLASSES
    if letter in ('F', 'X'):
        shared = ALLY_ALL if letter == 'F' else HORDE_ALL
        if races and (races & shared) != shared: return None      # a quest for some races only isn't shared
    elif races and not (races & RACE_BITS[letter]): return None
    if (sflags or 0) & 1: return None            # repeatable
    ql = ql if (ql and ql > 0) else (rl or 1)
    if (horde_only if ally else alliance_only)(at(starts, 1)): return None
    giver, start = None, None
    for i in (at(starts, 1) or []):
        gname, sp = npc(i)
        p = first_point(sp, zones)
        if p: giver = (gname, p); break
    if not giver and not at(starts, 1):          # starts from an object or an item
        start = starter(q, zones)
        if start: giver = (start['src'], start['point'])
    if not giver: return None
    ends = [i for i in (at(ends, 1) or []) if npc(i)[1]]
    return dict(id=int(qid), name=name, lvl=ql, req=rl or 1, giver=giver, pre=list(preG or []) + list(preS or []),
                preG=list(preG or []), preS=list(preS or []), start=start,
                maybe=bool(start and not start['sure']), ender=ends[0] if ends else None, cls=cls)

def owner_lo(letter, z):
    """The lowest starting level of the legs on this race's route that take quests filed under zone z (None: no leg)."""
    shared = 'F' if letter in ALLY_LETTERS + 'F' else 'X'
    los = [l[2] for l in LEGS if l[0] in (letter, shared) and z in l[4]]
    return min(los) if los else None

def homeless(letter, z, ql):
    """A quest no leg of this race's route would take by where it's filed: one filed under a theme instead of a zone
    (Forever's Camping quests), or under a zone whose leg starts well above its level (Wayward Weapons is filed under
    Durotar at level 2, but Gornek hands it out in the Valley of Trials), or a class quest filed under its class.
    It goes where its giver stands."""
    if z == CAMPING or z in CLASS_CATEGORIES: return True
    if not isinstance(z, int) or z <= 0: return False
    lo = owner_lo(letter, z)
    return lo is not None and ql < lo - 1

def build(letter, zone_name, lo, hi, zones, qmin=0):
    ally = letter in 'HDNGAF'
    FACTION[0] = 'Alliance' if ally else 'Horde'
    maps = {ui.get(z) for z in zones}
    # the race's capital, for its own legs up to level 20 (Orgrimmar's Hidden Enemies, Meal Appeal...)
    city = CAPITAL.get(letter) if lo > 1 and hi <= 20 else None
    anchors = anchor_points(zones)
    quests = {}
    for qid, q in D['quests'].items():
        z, rl, ql = at(q, 8), at(q, 4), at(q, 5)
        ql = ql if (ql and ql > 0) else (rl or 1)
        # (a class quest filed under its class may come a few levels early: Path of Defense, level 10, is handed out in
        # the Crossroads, where the Barrens leg starts at 12)
        if not ((lo - 3 if z in CLASS_CATEGORIES else lo - 1) <= ql <= hi + 1) or ql < qmin: continue
        if int(qid) in LEADS_IN: continue    # (it leads into a dungeon: in that dungeon's list instead)
        loose = z not in zones and ((city and z == city) or homeless(letter, z, ql))
        if z not in zones and not loose: continue
        if loose and (covered(letter, int(qid)) or dungeon_quest(q, qid)): continue    # (already on the way: an earlier leg took it)
        rec = make_quest(qid, q, letter, zones)
        if not rec: continue
        if loose and z != city:
            # where its giver stands: on this leg's map, and in a starting zone near its hub (Brakk's Camping quests are
            # in Razor Hill, on the same map as the Valley of Trials, but they belong to the Durotar leg)
            gz, gx, gy = rec['giver'][1]
            if ui.get(gz) not in maps: continue
            if lo == 1 and not any(ui.get(az) == ui.get(gz) and math.hypot(ax - gx, ay - gy) <= START_RADIUS for _, (az, ax, ay) in anchors): continue
        quests[int(qid)] = rec
    if not quests: return []
    if lo == 1:  # a starting zone: only quests handed out in the zone itself
        quests = {k: q for k, q in quests.items() if ui.get(q['giver'][1][0]) in maps}
    # Every quest's earlier quests must be on the way. One this route hasn't listed before (an Undead skips the
    # Barrens at 12-20, so Serena Bloodfeather in the shared Barrens leg needs Harpy Lieutenants, which only the
    # other races met) joins this leg, and its own earlier quests with it; a quest whose earlier quest can't be
    # taken here (another race's, a class quest, started by an item) is left out, since it could never be done.
    dropped, why = set(), {}
    def reachable(p, dep):
        """Can quest p be had some other way (started by an item or an object on the way, a class quest)?
        Not a dungeon or raid quest (a questing step mustn't wait for one), nor one the data doesn't have.
        One marked for other races only still counts (with a warning): the data's race marks have been wrong
        in a starting zone (Zephras Isle), and leaving a whole chain out on that alone would be worse."""
        if p in dropped: why[dep] = '%s (%d) is left out too' % (at(D['quests'].get(str(p)), 1), p); return False
        raw = D['quests'].get(str(p))
        if not raw: why[dep] = 'quest %d isn\'t in the data' % p; return False
        if dungeon_quest(raw, p): why[dep] = '%s (%d) is a dungeon or raid quest' % (at(raw, 1), p); return False
        races = int(at(raw, 6) or 0)
        mask = (HORDE_ALL if letter == 'X' else ALLY_ALL) if letter in ('X', 'F') else RACE_BITS[letter]
        if races and not (races & mask):
            WARNINGS.add('%s %s: %s (%d) needs %s (%d), which the data gives only to other races' % (letter, zone_name, D['quests'][str(dep)] and at(D['quests'][str(dep)], 1), dep, at(raw, 1), p))
        return True
    def add(p):
        if p in quests: return True
        if p in dropped: return False
        raw = D['quests'].get(str(p))
        rec = raw and not dungeon_quest(raw, p) and make_quest(p, raw, letter, zones)
        if not rec: return False
        quests[p] = rec
        return True
    def have(p): return p in quests or covered(letter, p)
    changed = True
    while changed:
        changed = False
        for qid in list(quests):
            q = quests.get(qid)
            if not q: continue
            ok = True
            for p in q['preG']:
                if not have(p):
                    if add(p): changed = True
                    elif not reachable(p, qid): ok = False
            if q['preS'] and not any(have(p) for p in q['preS']):
                if any(add(p) for p in q['preS']): changed = True
                elif not any(reachable(p, qid) for p in q['preS']): ok = False
            if not ok:
                del quests[qid]; dropped.add(qid); changed = True
                LEFT_OUT.append('%s %s: %s (%d), needs %s' % (letter, zone_name, q['name'], qid, why.get(qid, '?')))
    if not quests: return []
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
    # (class quests and quests from an item that only sometimes drops aren't walked to: they join a step further down)
    walked = {k: q for k, q in quests.items() if not (q['maybe'] or q['cls'])}
    done, steps, L = set(), [], lo
    def ready(q):
        return (q['id'] not in done and q['req'] <= L + 1 and q['lvl'] <= L + 3
                and all(p in done or p not in walked for p in q['pre']))
    last_point = None
    while len(done) < len(walked):
        cands = [q for q in walked.values() if ready(q)]
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
            qs = [q for q in walked.values() if ready(q) and hub_of(q)[0] == label]
        for i in range(0, len(taken), MAX_PER_STEP):
            steps.append({'hub': label, 'point': point, 'q': taken[i:i + MAX_PER_STEP]})
        last_point = point
        L = max(L, min(hi, sorted(q['lvl'] for q in taken)[len(taken) // 2]))
    # A class quest joins the step at the hub where its giver stands, or the nearest one (Paladins see a Paladin quest
    # there, nobody else does). A quest from an item that only sometimes drops joins the step where it's handed in
    # (the add-on shows it once you have it), or the one nearest its drop. Only steps at or after its level, if any.
    def step_of(qid):
        for i, s in enumerate(steps):
            if any(x['id'] == qid for x in s['q']): return i
        return -1
    for q in sorted((q for q in quests.values() if q['maybe'] or q['cls']), key=lambda q: (q['lvl'], q['id'])):
        if not steps: break
        after = max([step_of(p) for p in q['pre'] if p in quests] or [-1])   # (Armaments of War after The Calling)
        target = q['giver'][1]
        if q['maybe'] and q['ender']:
            _, sp = npc(q['ender'])
            target = (sp and first_point(sp, zones)) or target
        def far(i, q=q, target=target):
            pz, px, py = steps[i]['point']
            lvl = min(x['lvl'] for x in steps[i]['q'] if not (x['maybe'] or x['cls']))
            return (ui.get(pz) != ui.get(target[0]), lvl < q['lvl'] - 2, round(math.hypot(px - target[1], py - target[2]) / 5), i)
        steps[min(range(max(0, min(after, len(steps) - 1)), len(steps)), key=far)]['q'].append(q)
    out = []
    for s in steps:
        names = []
        for q in s['q']:
            if q['maybe'] or q['cls']: continue      # (not named: it shows once you have it / to its class only)
            if q['start']: q = dict(q, name='%s (starts from %s)' % (q['name'], q['start']['item']))
            if q['name'] not in names: names.append(q['name'])   # chain parts share a name
        # quests named alike say their shared part once ("Camping 101: Cooking, Mining, Skinning")
        for i in range(len(names) - 1, 0, -1):
            pre = names[i - 1].split(': ')[0] if ': ' in names[i - 1] else None
            if pre and names[i].startswith(pre + ': '):
                names[i] = names[i][len(pre) + 2:]
        givers, shown = [], [q for q in s['q'] if not (q['maybe'] or q['cls'])]
        for q in shown:
            if q['giver'][0] not in givers: givers.append(q['giver'][0])
        lv = sorted({q['lvl'] for q in shown})
        lvtxt = ('level %d' % lv[0]) if len(lv) == 1 else ('levels %d-%d' % (lv[0], lv[-1]))
        if s['hub'] == shown[0]['giver'][0] and len(givers) == 1:
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
    ("Zul'Farrak", [1176]), ('Maraudon', [2100]), ("The Temple of Atal'Hakkar", [1477, 1417]), ('Blackrock Depths', [1584]),
    ('Stratholme, Scholomance, Dire Maul, LBRS/UBRS', [2017, 2057, 2557, 1583]), ("The Shaper's Terrace", [16985]),
]
ALLY_DUNGEONS = [
    ('The Deadmines', [1581]), ('The Stockade', [717]), ('Wailing Caverns', [718]), ('Shadowfang Keep', [209]),
    ('Blackfathom Deeps', [719]), ('Gnomeregan', [721]), ('Razorfen Kraul', [491]), ('Excavation Site', [16732, 16877, 16878, 16879]),
    ('City of Dalaran', [16544, 16558, 16559, 16560, 16562]), ('Scarlet Monastery', [796]), ('Razorfen Downs', [722]),
    ('Uldaman', [1337]), ("Zul'Farrak", [1176]), ('Maraudon', [2100]), ("The Temple of Atal'Hakkar", [1477, 1417]),
    ('Blackrock Depths', [1584]), ('The Hall of Thanes', [16919]), ("The Shaper's Terrace", [16985]),
    ('Stratholme, Scholomance, Dire Maul, LBRS/UBRS', [2017, 2057, 2557, 1583]),
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
RL = [(2, 'O'), (16, 'U'), (32, 'T'), (128, 'R'), (8589934592, 'S'), (1, 'H'), (4, 'D'), (8, 'N'), (64, 'G'), (4294967296, 'A')]
CL = [(1, 'W'), (2, 'P'), (4, 'H'), (8, 'R'), (16, 'I'), (64, 'S'), (128, 'M'), (256, 'L'), (1024, 'D')]
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

_DUNGEON_AREAS = []
# instances by QuestieDB's area names (some aren't marked "dungeon area" in the map data, e.g. SUNKEN_TEMPLE, the raids)
INSTANCE_NAMES = ('RAGEFIRE_CHASM', 'WAILING_CAVERNS', 'THE_DEADMINES', 'THE_STOCKADE', 'SHADOWFANG_KEEP', 'BLACKFATHOM_DEEPS',
    'GNOMEREGAN', 'RAZORFEN_KRAUL', 'SCARLET_MONASTERY', 'RAZORFEN_DOWNS', 'ULDAMAN', 'ZUL_FARRAK', 'MARAUDON', 'SUNKEN_TEMPLE',
    'THE_TEMPLE_OF_ATAL_HAKKAR', 'BLACKROCK_DEPTHS', 'BLACKROCK_SPIRE', 'DIRE_MAUL', 'STRATHOLME', 'SCHOLOMANCE', 'MOLTEN_CORE',
    'ONYXIAS_LAIR', 'BLACKWING_LAIR', 'ZUL_GURUB', 'RUINS_OF_AHN_QIRAJ', 'AHN_QIRAJ', 'NAXXRAMAS')
# Quests filed outside a dungeon that only lead into its quests: in that dungeon's list (so the guide gets them only for
# a dungeon you've picked), never in a questing step. The Stone Circle (Tanaris) is the step between The Sunken Temple
# (Witch Doctor Uzer'i for the Horde, filed under the temple; Angelas Moonbreeze for the Alliance) and Into the Depths
# and Secret of the Circle, both done inside.
DUNGEON_LEADS = {"The Temple of Atal'Hakkar": {3444, 3445}}
LEADS_IN = set().union(*DUNGEON_LEADS.values())
def dungeon_quest(raw, qid=None):
    """A dungeon or raid quest: filed under one (built on first use: the dungeon lists and sub-areas are read below),
    or one that only leads into a dungeon's quests (DUNGEON_LEADS).
    Only where it's filed counts: judging by its objectives (in_dungeon) wrongly caught ordinary quests."""
    if qid is not None and int(qid) in LEADS_IN: return True
    if not _DUNGEON_AREAS:
        areas = set()
        for _, a in DUNGEONS + ALLY_DUNGEONS: areas |= set(a)
        for m in re.finditer(r'\[(\d+)\]\s*=\s*(\d+),\s*--\s*Referenced dungeon area', open(QDB + 'support/Forever/Zones/areaIdToUiMapId.lua').read()):
            areas.add(int(m.group(1)))
        areas |= {ENUM[n] for n in INSTANCE_NAMES if n in ENUM}
        areas |= {a for a in SUBAREAS if SUBAREAS[a] in areas}
        _DUNGEON_AREAS.append(areas)
    z = at(raw, 8)
    return isinstance(z, int) and z in _DUNGEON_AREAS[0]

def dungeon_quests(areas, ally=False, dname=None):
    FAC = ALLY_ALL if ally else HORDE_ALL
    FACTION[0] = 'Alliance' if ally else 'Horde'
    out = []
    areas = set(areas) | {a for a in SUBAREAS if SUBAREAS[a] in areas}
    for qid, q in D['quests'].items():
        name, starts, ends, rl, ql, races, objs, z, sflags, classes, preG, preS, excl = [at(q, i) for i in range(1, 14)]
        races, classes = int(races or 0), int(classes or 0)
        if (races and not races & FAC) or (sflags or 0) & 1: continue
        if z not in areas and int(qid) not in DUNGEON_LEADS.get(dname, ()) and not in_dungeon(objs, areas): continue
        if (horde_only if ally else alliance_only)(at(starts, 1)): continue
        if ql is not None and ql > 62: continue
        giver = None
        for i in (at(starts, 1) or []):
            gname, sp = npc(i)
            p = first_point(sp, [])
            if p: giver = (gname, p); break
        ra = ''.join(c for b, c in RL if races & b) if races and (races & FAC) != FAC else ''
        cl = ''.join(c for b, c in CL if classes & b) if classes and len([1 for b, _ in CL if classes & b]) < 9 else ''
        out.append((ql or rl or 0, int(qid), name, giver, ra, cl, rl or 1))
    out.sort()
    return out

lines = ['-- GENERATED by tools/routes/gen.py from QuestieDB\'s merged WoW Forever data: do not edit by hand.',
         '-- Quest steps for the starting zones of each race (letters) and the later Alliance zones (F). Each step: t = text, q = its quest IDs',
         '-- (it ticks itself off once all of them are turned in), w = hub waypoint {uiMapID, x, y, label}.',
         '-- RG.GEN_STEPS[race letter]["Zone|from"] = { steps }. Races/<Race>.lua define the route entries.',
         'local _, RG = ...', 'RG.GEN_STEPS = {']
total = 0
by_race = {}
for leg in LEGS:
    letter, zone_name, lo, hi, zones = leg[:5]
    steps = build(letter, zone_name, lo, hi, zones, leg[5] if len(leg) > 5 else 0)
    for _, ids, _ in steps: COVERED.setdefault(letter, set()).update(ids)
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

# ---------------------------------------------------------------------------
# Zones nobody has listed yet: any world map with enough quests for a faction that no leg, dungeon or city
# covers becomes a route entry of its own (RG.GEN_AUTO, added to the route by Profile.lua), with generated steps.
# On launch day a brand-new zone shows up in the route within an hour of its quest data, without a code change.
# ---------------------------------------------------------------------------
AUTO_MIN = 12
listed = set()   # (not "covered": build() still calls covered())
for leg in LEGS: listed |= {ui.get(z) for z in leg[4]} | set(leg[4])
for _, areas in DUNGEONS + ALLY_DUNGEONS: listed |= {ui.get(a) for a in areas} | set(areas)
SKIP_MAPS = set()
for m in re.finditer(r'\[(\d+)\]\s*=\s*(\d+),\s*--\s*Referenced dungeon area', open(QDB + 'support/Forever/Zones/areaIdToUiMapId.lua').read()):
    SKIP_MAPS.add(int(m.group(2)))
SKIP_NAMES = ('Warsong Gulch', 'Arathi Basin', 'Alterac Valley', 'Orgrimmar', 'Thunder Bluff', 'Undercity', 'Stormwind', 'Ironforge', 'Darnassus')
auto = {'X': [], 'F': []}
by_map = {}
for qid, q in D['quests'].items():
    z, ql, races, classes, sflags = at(q, 8), at(q, 5), int(at(q, 6) or 0), at(q, 10), at(q, 9)
    if not isinstance(z, int) or z <= 0 or classes or (sflags or 0) & 1: continue
    m = ui.get(z)
    if not m or m in listed or z in listed or m in SKIP_MAPS: continue
    if not ql or ql < 10 or ql > 60: continue
    for letter, mask in (('X', HORDE_ALL), ('F', ALLY_ALL)):
        if races and not races & mask: continue
        by_map.setdefault((letter, m), []).append((ql, z))
for (letter, m), qs in sorted(by_map.items()):
    name = MAPNAME.get(m) or ''
    if len(qs) < AUTO_MIN or not name or any(n in name for n in SKIP_NAMES): continue
    lv = sorted(q[0] for q in qs)
    lo, hi = lv[len(lv) // 5], lv[min(len(lv) - 1, len(lv) * 9 // 10)]
    if hi - lo < 2: lo, hi = max(1, hi - 3), hi
    areas = sorted({q[1] for q in qs})
    steps = build(letter, name, lo, hi, areas)
    if not steps: continue
    auto[letter].append((name, lo, hi, len(qs), steps[0][2][3]))
    by_race.setdefault(letter, []).append((name, lo, steps))
    print('AUTO new zone %s %-22s %2d-%2d: %2d steps, %3d quests' % (letter, name, lo, hi, len(steps), len(qs)), file=sys.stderr)
lines.append('-- RG.GEN_AUTO[X = Horde, F = Alliance] = zones found in the quest data that no hand-written route entry lists yet')
lines.append('RG.GEN_AUTO = {')
for letter in ('X', 'F'):
    lines.append('  %s = {' % letter)
    for name, lo, hi, n, hub in auto[letter]:
        lines.append('    { zone = %s, from = %d, to = %d, n = %d, hub = %s },' % (lstr(name), lo, hi, n, lstr(hub)))
    lines.append('  },')
lines.append('}')
# the auto zones' steps go into GEN_STEPS too
extra = []
for letter in ('X', 'F'):
    for zone_name, lo, steps in [e for e in by_race.get(letter, []) if any(e[0] == a[0] and e[1] == a[1] for a in auto[letter])]:
        extra.append('RG.GEN_STEPS.%s[%s] = {' % (letter, lstr('%s|%d' % (zone_name, lo))))
        for text, ids, (mm, x, y, label) in steps:
            extra.append('  { t = %s, q = { %s }, w = { %d, %.1f, %.1f, %s } },' % (lstr(text), ', '.join(map(str, ids)), mm, x, y, lstr(label)))
        extra.append('}')
lines.extend(extra)
def emit_dungeons(var, dlist, ally):
    lines.append('-- %s[route name] = { {id, name, giver, where, waypoint, level, required level, ra = races, cl = classes}, ... }' % var)
    lines.append('%s = {' % var)
    for dname, areas in dlist:
        qs = dungeon_quests(areas, ally, dname)
        print('%s %-45s %2d quests' % ('ally' if ally else 'dungeon', dname, len(qs)), file=sys.stderr)
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
emit_dungeons('RG.GEN_DUNGEONS', DUNGEONS, False)
emit_dungeons('RG.GEN_DUNGEONS_A', ALLY_DUNGEONS, True)
os.makedirs(OUT + 'Routes', exist_ok=True)
open(OUT + 'Routes/Generated.lua', 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
for w in LEFT_OUT: print('left out: ' + w, file=sys.stderr)
for w in sorted(WARNINGS): print('check the data: ' + w, file=sys.stderr)
print('%d steps written' % total, file=sys.stderr)
