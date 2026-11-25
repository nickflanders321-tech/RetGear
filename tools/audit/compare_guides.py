"""Compare Waypath+'s leveling route with other public route guides, to catch where ours wanders off.

Sources (read only, never copied into Waypath+):
  * Polestar's 1-60 guides (github.com/fitzforge/polestar, GPL-3.0): every step lists the quest IDs it takes and
    hands in, so quests are compared by ID.
  * The community RestedXP-format guide (github.com/craigory1591/wow-forever-guide, no licence: facts only): level
    brackets per zone ("Undead 10-14 Silverpine Forest"); its steps name quests in prose, matched by title.
Journey and RestedXP publish no route lists (their routes live inside their addons), so they aren't compared.

For every race it reports, per zone: our level window against theirs, zones only one side uses, and quests Polestar
does that we don't (and the reverse), so a reviewer can see where we differ and judge who is right.

Usage: python3 compare_guides.py <routes dir: <race>.json from run.lua --dump-route> <polestar checkout> <rxp guide dir>
(tools/audit/compare_guides.sh fetches the guides and writes the route dumps.)
"""
import json, os, re, sys

ROUTES, PS, RXP = sys.argv[1], sys.argv[2], sys.argv[3]
RXPO = sys.argv[4] if len(sys.argv) > 4 else None    # RestedXP's RXPGuides checkout (its free Forever guides)
CLASS = 'Warrior'                                    # the class the routes are compared for (every race has warriors)
CITIES = {'Orgrimmar', 'Thunder Bluff', 'Undercity', 'Stormwind City', 'Ironforge', 'Darnassus'}

# (our dump file, Polestar race word and start folder, RestedXP-format file and race word in its guide names)
RACES = [
    ('Orc', 'Horde', 'Orc', 'horde/orc', 'Orc.lua', 'Orc'),
    ('Troll', 'Horde', 'Troll', 'horde/troll', 'Troll.lua', 'Troll'),
    ('Scourge', 'Horde', 'Undead', 'horde/undead', 'Undead.lua', 'Undead'),
    ('Tauren', 'Horde', 'Tauren', 'horde/tauren', 'Tauren.lua', 'Tauren'),
    ('Skyborne-Horde', 'Horde', 'Skyborne', 'horde/skyborne', 'WindshaperSkyborne.lua', None),
    ('Human', 'Alliance', 'Human', 'alliance/human', 'Human.lua', 'Human'),
    ('Dwarf', 'Alliance', 'Dwarf', 'alliance/dwarf', 'Dwarf.lua', 'Dwarf'),
    ('Gnome', 'Alliance', 'Gnome', 'alliance/gnome', 'Gnome.lua', 'Gnome'),
    ('NightElf', 'Alliance', 'NightElf', 'alliance/nightelf', 'NightElf.lua', 'Night Elf'),
    ('Skyborne-Alliance', 'Alliance', 'Skyborne', 'alliance/skyborne', 'HighOrderSkyborne.lua', None),
]
ZONE_ALIAS = {'Western Plaguelands': 'Western & Eastern Plaguelands', 'Eastern Plaguelands': 'Western & Eastern Plaguelands',
              "Shen'Dralas": "Shen'dralas", 'Northshire Valley': 'Elwynn Forest', 'Coldridge Valley': 'Dun Morogh',
              'Valley of Trials': 'Durotar', 'Camp Narache': 'Mulgore', 'Shadowglen': 'Teldrassil'}
def zkey(z): z = (z or '').strip(); return ZONE_ALIAS.get(z, z)

# ---------------------------------------------------------------- Polestar
GDIR = os.path.join(PS, 'guides', 'forever')
def read_guide(gid):
    path = os.path.join(GDIR, gid.replace('forever/', '', 1) + '.guide')
    if not os.path.exists(path): return None
    g = {'id': gid, 'zone': None, 'levels': None, 'next': None, 'steps': []}
    step = None
    for raw in open(path, encoding='utf-8'):
        line = raw.split('--')[0].rstrip()
        if not line.strip() or line.lstrip().startswith('#'): continue
        indented = line[0] in ' \t'
        w = line.split()
        if not indented:
            if w[0] == 'zone' and not g['zone']: g['zone'] = ' '.join(w[1:])
            elif w[0] == 'levels': g['levels'] = w[1]
            elif w[0] == 'next': g['next'] = w[1]
            elif w[0] == 'step': step = {'zone': None, 'only': None, 'when': [], 'accept': [], 'turnin': []}; g['steps'].append(step)
            continue
        if step is None: continue
        k = w[0]
        if k == 'zone': step['zone'] = ' '.join(w[1:])
        elif k == 'only': step['only'] = ' '.join(w[1:])
        elif k == 'when': step['when'].append(' '.join(w[1:]))
        elif k in ('accept', 'turnin') and len(w) > 1 and w[1].isdigit(): step[k].append(int(w[1]))
    return g

def step_for(step, race, faction):
    """Does the step apply to this race (any class)? Dungeon and profession steps don't count."""
    for c in step['when']:
        if c.startswith('dungeon') or (c.startswith('skill') and 'Riding' not in c): return False
    if step['only']:
        words = [x.strip() for x in re.split(r'[ ,]+', step['only']) if x.strip()]
        classes = {'Warrior', 'Hunter', 'Rogue', 'Priest', 'Shaman', 'Mage', 'Warlock', 'Paladin', 'Druid'}
        races_or_fac = [x for x in words if x not in classes and not x.startswith('!')]
        if races_or_fac and race not in races_or_fac and faction not in races_or_fac: return False
        cls_words = [x for x in words if x in classes]
        if cls_words and CLASS not in cls_words: return False   # another class's steps (the comparison is for CLASS)
    return True

def polestar_route(start_dir, race, faction):
    d = os.path.join(GDIR, start_dir)
    if not os.path.isdir(d): return []
    first = sorted(f for f in os.listdir(d) if f.endswith('.guide'))[0][:-6]
    gid, seen, out = 'forever/' + start_dir + '/' + first, set(), []
    while gid and gid not in seen:
        seen.add(gid)
        g = read_guide(gid)
        if not g: break
        quests = []
        for s in g['steps']:
            if step_for(s, race, faction): quests += [q for q in s['accept'] if q not in quests]
        lo, hi = (int(x) for x in (g['levels'] or '0-0').split('-'))
        # a guide in the shared chain with nothing for this race (Silverpine is the Undead's) isn't a zone it visits
        if quests: out.append({'zone': g['zone'], 'from': lo, 'to': hi, 'quests': quests, 'id': gid})
        gid = g['next']
    return out

# ---------------------------------------------------------------- RestedXP's own free Forever guides (RXPGuides, CC BY-NC-SA 4.0)
RXP_RACE = {'Scourge': 'Undead', 'Skyborne-Horde': 'Skyborne', 'Skyborne-Alliance': 'Skyborne'}
def tags_ok(tags, race, cls, faction):
    """RestedXP's '<< Warrior/Warlock', '<< !Undead', '<< Undead Rogue': any alternative whose terms all hold."""
    tags = (tags or '').strip()
    if not tags: return True
    def term(t):
        neg = t.startswith('!'); t = t.lstrip('!')
        hit = t.lower() in (race.lower(), cls.lower(), faction.lower(), race.lower().replace(' ', ''))
        return hit != neg
    return any(all(term(t) for t in alt.split()) for alt in tags.split('/') if alt.split())

def rxp_official(race, cls, faction):
    """The race's start guide (#defaultfor) and the guides after it (#next), with the quests each step accepts."""
    d = os.path.join(RXPO, 'Guides', 'forever')
    if not RXPO or not os.path.isdir(d): return []
    blocks = []
    for f in sorted(os.listdir(d)):
        if not f.endswith('.lua'): continue
        for b in re.findall(r'RegisterGuide\(\[\[(.*?)\]\]\)', open(os.path.join(d, f), encoding='utf-8').read(), re.S):
            head = b.split('\nstep', 1)[0]
            g = lambda k: (re.search(r'^#%s\s+(.+)$' % k, head, re.M) or [None, None])[1]
            fac = re.search(r'^<<\s*(Horde|Alliance)', head, re.M)
            if fac and fac.group(1) != faction: continue
            blocks.append({'name': (g('name') or '').strip(), 'next': (g('next') or '').split(';')[0].strip(),
                           'default': (g('defaultfor') or ''), 'body': b})
    rword = RXP_RACE.get(race, race)
    # the race's own start: the lowest-level guide that names the race as its default (a later guide can too)
    def lo(b): m = re.match(r'(\d+)-', b['name']); return int(m.group(1)) if m else 99
    starts = [b for b in blocks if rword in b['default'].replace(' ', '')]
    start = min(starts, key=lo) if starts else None
    out, seen = [], set()
    while start and start['name'] not in seen:
        seen.add(start['name'])
        m = re.match(r'(\d+)-(\d+)\s+(.+)', start['name'])
        quests = []
        for st in re.split(r'\n(?=step)', start['body']):
            first = st.split('\n', 1)[0]
            stags = first[4:].split('<<', 1)[1] if first.startswith('step') and '<<' in first else ''
            if not tags_ok(stags, rword, cls, faction): continue
            for line in st.split('\n'):
                a = re.search(r'\.accept\s+(\d+)', line)
                if a and tags_ok(line.split('<<', 1)[1] if '<<' in line else '', rword, cls, faction) and int(a.group(1)) not in quests:
                    quests.append(int(a.group(1)))
        if m: out.append({'zone': m.group(3).strip(), 'from': int(m.group(1)), 'to': int(m.group(2)), 'quests': quests})
        start = next((b for b in blocks if b['name'] == start['next']), None)
    return out

# ---------------------------------------------------------------- the RestedXP-format guide
def rxp_route(fname, race_word):
    path = os.path.join(RXP, fname)
    if not os.path.exists(path): return []
    src = open(path, encoding='utf-8').read()
    out, group = [], None
    for block in re.findall(r'RegisterGuide\(\[\[(.*?)\]\]\)', src, re.S):
        gm = re.search(r'#group (.+)', block)
        if group is None and gm: group = gm.group(1).strip()      # one class's route is enough: zones and levels
        if not gm or gm.group(1).strip() != group: continue
        m = re.search(r'#name .*?(\d+)-(\d+) (.+)', block)
        if not m: continue
        out.append({'zone': m.group(3).strip(), 'from': int(m.group(1)), 'to': int(m.group(2)), 'text': block})
    return out

# ---------------------------------------------------------------- compare
SOURCES = [('ps', 'Polestar'), ('ro', 'RestedXP (free)'), ('rx', 'RestedXP-format')]

def zone_table(ours, src):
    """One row per zone in our order (then theirs): the levels each route is there."""
    rows, order = {}, []
    def add(key, e):
        k = zkey(e['zone'])
        if k not in rows: rows[k] = {}; order.append(k)
        r = rows[k].get(key)
        rows[k][key] = (min(r[0], e['from']), max(r[1], e['to'])) if r else (e['from'], e['to'])
    for e in ours: add('ours', e)
    for key, _ in SOURCES:
        for e in src[key]: add(key, e)
    return [(k, rows[k]) for k in order]

def fmt(w): return '%d-%d' % w if w else '-'
def qname(names, q): return '%s (%d, lvl %s)' % (names[str(q)][0], q, names[str(q)][1]) if str(q) in names else str(q)

def condensed(path):
    """A route's zones in order, cities left out and repeats next to each other merged: [(zone, from, to)]."""
    out = []
    for z, a, b in path:
        z = zkey(z)
        if z in CITIES: continue
        if out and out[-1][0] == z: out[-1] = (z, out[-1][1], b)
        else: out.append((z, a, b))
    return out

def returns(path): return sum(1 for i, p in enumerate(path) if any(q[0] == p[0] for q in path[:i]))

def report(race, faction, ours, names, src, bot):
    L = ['## %s (%s, %s)' % (race, faction, CLASS), '']
    flags = []
    if not ours: return L + ['(no route dump)', ''], flags
    L += ['| Zone | Waypath+ | ' + ' | '.join(n for _, n in SOURCES) + ' | |', '|---' * (len(SOURCES) + 3) + '|']
    for k, r in zone_table(ours, src):
        o = r.get('ours')
        others = [r[key] for key, _ in SOURCES if r.get(key)]
        note = ''
        if o and others and all(abs(o[0] - w[0]) >= 4 for w in others):
            note = 'we start %+d levels from them' % (o[0] - round(sum(w[0] for w in others) / len(others)))
        elif o and not others and o[0] <= 22 and src['ro']: note = ''   # (RestedXP's free part stops at 22)
        elif o and not others: note = 'only we go here'
        elif not o and len(others) >= 2: note = 'other guides go here, we don\'t'
        if note: flags.append((k, note))
        L.append('| %s | %s | %s | %s |' % (k, fmt(o), ' | '.join(fmt(r.get(key)) for key, _ in SOURCES), note))
    L.append('')
    ours_q = {q for e in ours for q in e['quests']}
    for key, label in (('ps', 'Polestar'), ('ro', 'RestedXP (free, to ~22)')):
        if not src[key]: continue
        their = {q for e in src[key] for q in e['quests']}
        top = max(e['to'] for e in src[key])
        mine = {q for e in ours if e['from'] <= top for q in e['quests']} if key == 'ro' else ours_q
        only_them = sorted((q for q in their - ours_q if str(q) in names), key=lambda q: names[str(q)][1])
        L.append('%s: %d quests, %d of them in our route; they do %d we don\'t%s' % (label, len(their), len(their & ours_q), len(only_them),
            (': ' + ', '.join(qname(names, q) for q in only_them[:25]) + (' ...' if len(only_them) > 25 else '')) if only_them else '.'))
        L.append('')
    if src['rx']:
        title_ids = {}
        for q, v in names.items(): title_ids.setdefault(v[0], []).append(int(q))
        text = '\n'.join(e.get('text', '') for e in src['rx'])
        named = {n for n in title_ids if len(n) > 6 and n in text}
        missing = sorted(n for n in named if not any(q in ours_q for q in title_ids[n]))
        L.append('RestedXP-format guide names %d quests we know by title; %d aren\'t in our route%s' % (len(named), len(missing),
            (': ' + ', '.join(missing[:30]) + (' ...' if len(missing) > 30 else '')) if missing else '.'))
        L.append('')
    # class quests: where each guide weaves them in, and when the bot did ours (from the tracker's class quest list)
    cq = lambda q: str(q) in names and len(names[str(q)]) > 2 and names[str(q)][2] == 1
    L.append('**Class quests (%s).**' % CLASS)
    for key, label in (('ps', 'Polestar'), ('ro', 'RestedXP (free)')):
        rows = ['%s in %s %d-%d' % (names[str(q)][0], e['zone'], e['from'], e['to']) for e in src[key] for q in e['quests'] if cq(q)]
        if src[key]: L.append('- %s weaves in %d: %s' % (label, len(rows), '; '.join(rows[:20]) + (' ...' if len(rows) > 20 else '') if rows else 'none'))
    if bot:
        done = bot.get('classDone') or []
        L.append('- Waypath+ lists them beside the route (the tracker\'s "Class quests"); the bot did %d: %s' % (len(done),
            '; '.join('%s at %s' % (c['name'], c.get('done')) for c in done[:20]) + (' ...' if len(done) > 20 else '')))
        early = [c for c in (bot.get('classSeen') or []) if c.get('tooHigh')]
        if early: L.append('- Shown as "pick up now" 4+ levels below the quest\'s level: ' + '; '.join('%s (level %s) at %s' % (c['name'], c['lvl'], c['tooHigh']) for c in early))
    L.append('')
    # zone path: how much each route goes back and forth
    L.append('**Zone path** (cities left out; a number in brackets is a return to a zone already left).')
    def show(label, path):
        p = condensed(path)
        seen, parts = set(), []
        for z, a, b in p:
            parts.append(('%s %d-%d' % (z, a, b)) + (' (back)' if z in seen else '')); seen.add(z)
        L.append('- %s: %d stretches, %d returns. %s' % (label, len(p), returns(p), ' > '.join(parts[:60]) + (' ...' if len(parts) > 60 else '')))
    for key, label in SOURCES:
        if src[key]: show(label, [(e['zone'], e['from'], e['to']) for e in src[key]])
    if bot: show('Waypath+ (the bot\'s actual path)', [(p['zone'], p['from'], p['to']) for p in bot.get('path') or []])
    else: show('Waypath+ (route entries; no bot run)', [(e['zone'], e['from'], e['to']) for e in ours])
    L.append('')
    return L, flags

out = ['# Waypath+ route compared with other public guides', '',
       'Generated by tools/audit/compare_guides.py for %ss. Polestar and RestedXP\'s free guides are compared by quest ID;' % CLASS,
       'the RestedXP-format community guide by zone brackets and quest titles. A difference marks where to look, not a mistake.',
       'Our level column is the window in which the guide will send you to a zone; theirs is when their route is there,',
       'so only start levels are flagged (4+ levels from every other guide that goes there). Journey isn\'t compared:',
       'its terms forbid extracting its routes.', '']
summary = []
for dump, faction, ps_race, ps_dir, rx_file, rx_word in RACES:
    path = os.path.join(ROUTES, dump + '.json')
    if not os.path.exists(path): continue
    data = json.load(open(path, encoding='utf-8'))
    ours = [e for e in data['route'] if e['kind'] == 'zone']
    src = {'ps': polestar_route(ps_dir, ps_race, faction), 'ro': rxp_official(dump, CLASS, faction), 'rx': rxp_route(rx_file, rx_word)}
    bp = os.path.join(ROUTES, dump + '.bot.json')
    bot = json.load(open(bp, encoding='utf-8')) if os.path.exists(bp) else None
    lines, flags = report(dump, faction, ours, data['quests'], src, bot)
    out += lines
    summary.append((dump, flags))
head = ['## Summary: zones where we differ most', '']
for dump, flags in summary:
    head.append('- **%s**: %s' % (dump, '; '.join('%s (%s)' % f for f in flags) if flags else 'no zone stands out'))
head.append('')
print('\n'.join(out[:8] + head + out[8:]))
