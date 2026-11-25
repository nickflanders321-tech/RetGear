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
        if not races_or_fac and all(x in classes for x in words): return False   # class-only steps: class quests
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
def zone_table(ours, ps, rx):
    """One row per zone in our order (then theirs): our first entry's window, theirs."""
    rows, order = {}, []
    def add(src, e):
        k = zkey(e['zone'])
        if k not in rows: rows[k] = {}; order.append(k)
        r = rows[k].get(src)
        if r: rows[k][src] = (min(r[0], e['from']), max(r[1], e['to']))
        else: rows[k][src] = (e['from'], e['to'])
    for e in ours: add('ours', e)
    for e in ps: add('ps', e)
    for e in rx: add('rx', e)
    return [(k, rows[k]) for k in order]

def fmt(w): return '%d-%d' % w if w else '-'

def report(race, faction, ours, names, ps, rx):
    L = ['## %s (%s)' % (race, faction), '']
    if not ours: return L + ['(no route dump)', ''], []
    flags = []
    L += ['| Zone | Waypath+ | Polestar | RestedXP-format | |', '|---|---|---|---|---|']
    for k, r in zone_table(ours, ps, rx):
        o, p, x = r.get('ours'), r.get('ps'), r.get('rx')
        note = ''
        others = [w for w in (p, x) if w]
        if o and others and all(abs(o[0] - w[0]) >= 4 for w in others): note = 'we start %+d levels from them' % (o[0] - round(sum(w[0] for w in others) / len(others)))
        elif o and not others: note = 'only we go here'
        elif not o and p and x: note = 'both guides go here, we don\'t'
        if note: flags.append((k, note))
        L.append('| %s | %s | %s | %s | %s |' % (k, fmt(o), fmt(p), fmt(x), note))
    L.append('')
    # quests (by ID) against Polestar
    ours_q = {q for e in ours for q in e['quests']}
    ps_q = {q for e in ps for q in e['quests']}
    if ps:
        theirs_only = sorted(ps_q - ours_q, key=lambda q: names.get(str(q), ['', 0])[1])
        ours_only = sorted(ours_q - ps_q, key=lambda q: names.get(str(q), ['', 0])[1])
        both = len(ours_q & ps_q)
        L.append('Quests: we route %d, Polestar %d, %d in both. Polestar does %d we don\'t; we do %d it doesn\'t.' % (len(ours_q), len(ps_q), both, len(theirs_only), len(ours_only)))
        def show(lst, label):
            known = [q for q in lst if str(q) in names]
            if not known: return
            L.append('')
            L.append('%s (%d with data, lowest level first):' % (label, len(known)))
            L.append(', '.join('%s (%d, lvl %s)' % (names[str(q)][0], q, names[str(q)][1]) for q in known[:40]) + (' ...' if len(known) > 40 else ''))
        show(theirs_only, 'Polestar does, we don\'t')
        show(ours_only, 'We do, Polestar doesn\'t')
    # quests named in the RestedXP-format text that we don't route (title match: rough)
    if rx:
        title_ids = {}
        for q, (n, _) in names.items(): title_ids.setdefault(n, []).append(int(q))
        text = '\n'.join(e['text'] for e in rx)
        named = {n for n in title_ids if len(n) > 6 and n in text}
        missing = sorted(n for n in named if not any(q in ours_q for q in title_ids[n]))
        L.append('')
        L.append('RestedXP-format guide names %d quests we know by title; %d of them aren\'t in our route%s' % (
            len(named), len(missing), (': ' + ', '.join(missing[:40]) + (' ...' if len(missing) > 40 else '')) if missing else '.'))
    L.append('')
    return L, flags

out = ['# Waypath+ route compared with other public guides', '',
       'Generated by tools/audit/compare_guides.py. Polestar quests are compared by ID; the RestedXP-format guide by zone',
       'brackets and quest titles in its text. A difference isn\'t necessarily ours to fix: it marks where to look.',
       'Our level column is the window in which the guide will send you to a zone; theirs is when their route is there.',
       'So only the start levels are compared (flagged when we start 4+ levels from every other guide that goes there).', '']
summary = []
for dump, faction, ps_race, ps_dir, rx_file, rx_word in RACES:
    path = os.path.join(ROUTES, dump + '.json')
    if not os.path.exists(path): continue
    data = json.load(open(path, encoding='utf-8'))
    ours = [e for e in data['route'] if e['kind'] == 'zone']
    ps = polestar_route(ps_dir, ps_race, faction)
    rx = rxp_route(rx_file, rx_word)
    lines, flags = report(dump, faction, ours, data['quests'], ps, rx)
    out += lines
    summary.append((dump, flags))
head = ['## Summary: zones where we differ most', '']
for dump, flags in summary:
    head.append('- **%s**: %s' % (dump, '; '.join('%s (%s)' % f for f in flags) if flags else 'no zone stands out'))
head.append('')
print('\n'.join(out[:5] + head + out[5:]))
