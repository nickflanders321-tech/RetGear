#!/usr/bin/env python3
"""Waypath+ accuracy cross-check: is every piece of data read the way the game reads it?

1. Generators vs the add-on: what tools/*/gen.py read from the Lua data files (class
   weights, weapons and armor; profession crafts, materials and trainers; route steps,
   dungeon quests, bank-alt quests and the camping plan) must equal what the add-on
   itself loads (tools/audit/dump_truth.lua).
2. Hand-written data vs WoW Forever: quests named in dungeon lists, bank-alt quests and
   gear sources must exist in Forever's quest data with a Horde-friendly giver; gear
   guide and 2nd-spec items must exist and be usable by that class at the listed level.
3. Generated quest data vs WoW Forever: every Horde quest with a name must be in
   Objectives.lua (catches quests a generator filter drops by mistake).

Usage: python3 tools/audit/crosscheck.py <addon dir> <forever.json> <forever_gear.json> [lua5.1]
  forever.json      = tools/objectives/dump.lua output
  forever_gear.json = tools/gear/dump.lua output
Exit code 1 when something is wrong (problems); warnings don't fail the run.
"""
import json, os, re, subprocess, sys, glob

ADDON = sys.argv[1].rstrip('/')
FOREVER = json.load(open(sys.argv[2], encoding='utf-8'))
GEAR = json.load(open(sys.argv[3], encoding='utf-8'))['items']
LUA = sys.argv[4] if len(sys.argv) > 4 else 'lua5.1'
HERE = os.path.dirname(os.path.abspath(__file__))

problems, warnings = [], []
def problem(area, msg): problems.append('%-12s %s' % (area, msg))
def warn(area, msg): warnings.append('%-12s %s' % (area, msg))

def run_lua(script, *args):
    return subprocess.run([LUA, script, *args], capture_output=True, text=True, check=True).stdout
T = json.loads(run_lua(os.path.join(HERE, 'dump_truth.lua'), ADDON))

def at(a, i):
    if a is None: return None
    if isinstance(a, dict): return a.get(str(i))
    return a[i - 1] if 0 < i <= len(a) else None
def asdict(x):
    if isinstance(x, list): return {i + 1: v for i, v in enumerate(x)}
    return {int(k): v for k, v in (x or {}).items()}
def lst(x):
    if isinstance(x, list): return x
    if isinstance(x, dict): return [x[k] for k in sorted(x, key=lambda s: int(s))]
    return []

# ---------------------------------------------------------------------------
# 1a. tools/gear/gen.py: class weights, model, weapons, armor
src = open(os.path.join(ADDON, 'tools/gear/gen.py'), encoding='utf-8').read()
ns = {'re': re}
exec(src[src.index('def lua_table'):src.index('\n', src.index('    return dict(tok=tok')) + 1], ns)
for f in sorted(glob.glob(os.path.join(ADDON, 'Classes/*.lua'))):
    if f.endswith('Gear.lua') or f.endswith('Specs.lua'): continue
    p = ns['read_class'](f); t = T['classes'].get(p['tok'])
    if not t: problem('gear gen', '%s: class not loaded by the add-on' % p['tok']); continue
    tw = {k: float(v) for k, v in (t.get('weights') or {}).items()}
    if tw != p['w']: problem('gear gen', '%s weights read wrong: add-on %s, generator %s' % (p['tok'], tw, p['w']))
    if set(t.get('weapons') or []) != p['weapons']: problem('gear gen', '%s weapons read wrong: add-on %s, generator %s' % (p['tok'], sorted(t.get('weapons') or []), sorted(p['weapons'])))
    if asdict(t.get('armor')) != p['armor']: problem('gear gen', '%s armor read wrong: add-on %s, generator %s' % (p['tok'], asdict(t.get('armor')), p['armor']))
    if t.get('model') != p['model']: problem('gear gen', '%s weapon model read wrong' % p['tok'])

# 1b. tools/profs/gen.py: crafts, materials text, trainer names
tc, tt = set(), {}
for name, P in T['profs'].items():
    for st in lst(P.get('plan')):
        c = st.get('craft') if isinstance(st, dict) else None
        if not c: continue
        for part in re.split(r",\s*|\s+or\s+", c):
            if part.strip(): tc.add(part.strip())
        if st.get('mats'): tt.setdefault(c.split(",")[0].split(" or ")[0].strip(), st['mats'])
pc, pt = set(), {}
for f in glob.glob(os.path.join(ADDON, 'Professions/*.lua')):
    if f.endswith('Generated.lua'): continue
    s = open(f, encoding='utf-8').read()
    for c, txt in re.findall(r'craft = "([^"]+)"[^\n]*?mats = "([^"]*)"', s): pt.setdefault(c.split(",")[0].split(" or ")[0].strip(), txt)
    for c in re.findall(r'craft = "([^"]+)"', s):
        for part in re.split(r",\s*|\s+or\s+", c):
            if part.strip(): pc.add(part.strip())
for c in sorted(tc - pc): problem('profs gen', 'craft not read: %s' % c)
for c in sorted(pc - tc): problem('profs gen', 'craft read that the add-on does not have: %s' % c)
for c in tt:
    if c not in pt: problem('profs gen', 'materials not read for %s (keep craft and mats on one line)' % c)
    elif pt[c] != tt[c]: problem('profs gen', 'materials read wrong for %s' % c)

# 1c. tools/waypoints/gen.py: step lists per zone (pins are numbered by position)
data = ''
for f in sorted(glob.glob(os.path.join(ADDON, 'Classes/*.lua'))) + sorted(glob.glob(os.path.join(ADDON, 'Races/*.lua'))) + [os.path.join(ADDON, 'Routes/Horde.lua')]:
    if f.endswith('Gear.lua'): continue
    data += open(f, encoding='utf-8').read() + '\n'
sb = ''.join(m.group(1) + '\n' for m in re.finditer(r'^\w\.steps = \{\n(.*?)\n\}\n', data, re.S | re.M))
py = {m.group(1) + '|' + m.group(2): [x.replace('\\"', '"') for x in re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(3))]
      for m in re.finditer(r'\["([^"]+)\|(\d+)"\]\s*=\s*\{(.*?)\n  \},', sb, re.S)}
H = T['routes'].get('Horde') or {}
seen = set()
for race, R in T['races'].items():
    for cls, C in T['classes'].items():
        merged = {}
        for srcd in (H, R, C): merged.update(srcd.get('steps') or {})
        for k, steps in merged.items():
            steps = [s for s in lst(steps) if isinstance(s, str)]
            if k in seen: continue
            if k not in py: problem('waypoint gen', 'steps for %s not read (pins missing)' % k); seen.add(k); continue
            if py[k] != steps: problem('waypoint gen', 'steps for %s read differently (pins would point at the wrong step)' % k); seen.add(k)
dq = data[data.index('H.dungeons = {'):]
n_py = len(re.findall(r'\{ "([^"]+)", "([^"]+)", "([^"]+)" \}', dq[:dq.index('\n}\n')]))
n_lua = sum(len(lst(d.get('quests'))) for d in (H.get('dungeons') or {}).values())
if n_py != n_lua: problem('waypoint gen', 'dungeon quests: generator read %d, add-on has %d' % (n_py, n_lua))
mail = open(os.path.join(ADDON, 'Mail.lua'), encoding='utf-8').read()
if T.get('mail') is not None and len(re.findall(r'zone = "([^"]+)", lvl = \d+, req = \d+, giver = "([^"]+)"', mail)) != len(lst(T['mail'])):
    problem('waypoint gen', 'bank-alt quests read differently from the add-on')
camp = open(os.path.join(ADDON, 'Camp.lua'), encoding='utf-8').read()
if T.get('camp') is not None and len(re.findall(r'\{ lvl = \d+,\s+zone = "([^"]+)", text = "((?:[^"\\]|\\.)*)"', camp)) != len(lst(T['camp'])):
    problem('waypoint gen', 'camping plan read differently from the add-on')

# ---------------------------------------------------------------------------
# 2. hand-written data vs WoW Forever
HORDE = 2 | 16 | 32 | 128 | 8589934592
qnames = {}
for qid, q in FOREVER['quests'].items():
    nm = at(q, 1)
    if nm: qnames.setdefault(nm.lower(), []).append((int(qid), q))
def npc_name(i): return at(FOREVER['npcs'].get(str(i)) or [], 1)
def npc_faction(i): return at(FOREVER['npcs'].get(str(i)) or [], 3) or 'AH'
def base(n): return re.sub(r'\s*\(.*\)$', '', n or '').strip()
def quest_ok(area, name, giver=None):
    rows = qnames.get(base(name).lower())
    if not rows: problem(area, 'quest "%s" is not in WoW Forever\'s quest data (renamed or removed?)' % name); return
    horde = [r for r in rows if not int(at(r[1], 6) or 0) or int(at(r[1], 6) or 0) & HORDE]
    if not horde: problem(area, 'quest "%s" is Alliance-only' % name); return
    if giver:
        givers = [npc_name(i) for r in horde for i in (at(at(r[1], 2), 1) or [])]
        if givers and not any(g and (g in giver or giver.split(',')[0].strip() in g) for g in givers):
            warn(area, 'quest "%s": giver written as "%s", Forever data says %s' % (name, giver, ' / '.join(sorted(set(g for g in givers if g)))))
        ids = [i for r in horde for i in (at(at(r[1], 2), 1) or [])]
        if ids and all(npc_faction(i) == 'A' for i in ids): problem(area, 'quest "%s" is given by an Alliance NPC' % name)
for dz, d in (H.get('dungeons') or {}).items():
    for q in lst(d.get('quests')):
        q = lst(q) if isinstance(q, (list, dict)) else []
        if len(q) >= 2 and 'starts the' not in (q[0] or ''): quest_ok('dungeons', q[0], q[1])
for m in lst(T.get('mail')):
    quest_ok('bank alt', m.get('quest') or m.get('name') or '', m.get('giver'))
def item_ok(area, who, g, cls_tok, weapons=None):
    iid = g.get('id')
    if not iid: return
    it = GEAR.get(str(int(iid)))
    if not it: problem(area, '%s: item %s is not in WoW Forever\'s item data' % (who, iid)); return
    C = T['classes'][cls_tok]
    w = set(weapons or C.get('weapons') or []); ar = asdict(C.get('armor'))
    if it['class'] == 2 and it['sub'] not in w: problem(area, '%s: %s is a weapon type this class/spec can\'t use' % (who, it['name']))
    if it['class'] == 4 and it['sub'] in (1, 2, 3, 4) and g.get('slot') != 'Back':
        if it['sub'] not in ar: problem(area, '%s: %s is armor this class can\'t wear' % (who, it['name']))
        elif ar[it['sub']] > 1 and (it.get('reqLevel') or 0) < ar[it['sub']]: problem(area, '%s: %s needs a higher armor skill than the class has at its level' % (who, it['name']))
    if g.get('lvl') and it.get('reqLevel') and int(g['lvl']) < it['reqLevel'] and not g.get('approx'):
        warn(area, '%s: %s listed at level %s but needs %s' % (who, it['name'], g['lvl'], it['reqLevel']))
    if g.get('how') == 'Quest' and g.get('src'): quest_ok(area, g['src'])
for tok, C in T['classes'].items():
    for g in lst(C.get('guide')):
        if isinstance(g, dict): item_ok('gear guide', tok, g, tok)
spec_weapons = {}
for tok, specs in (T.get('specs') or {}).items():
    for s in lst(specs):
        if isinstance(s, dict) and s.get('weapons'): spec_weapons[tok + ':' + s.get('key', '')] = lst(s['weapons'])
for tok, specs in (T.get('spec_hand') or {}).items():
    for key, items in (specs or {}).items():
        for g in lst(items):
            if isinstance(g, dict): item_ok('2nd spec', tok + ':' + key, g, tok, spec_weapons.get(tok + ':' + key))

# ---------------------------------------------------------------------------
# 3. generated quest data covers every Horde quest
qd = run_lua(os.path.join(HERE, 'qdata_names.lua'), ADDON)
have = set(int(x) for x in qd.split())
missing = []
for qid, q in FOREVER['quests'].items():
    races = int(at(q, 6) or 0); ql = at(q, 5)
    if not at(q, 1) or (races and not races & HORDE) or (isinstance(ql, int) and ql > 62): continue
    # quests open to every race but offered only by Alliance NPCs (Proving Grounds, Buying
    # Friendship: Gelkis...) are Alliance quests in practice: tools/objectives/gen.py skips them too
    givers = at(at(q, 2) or [], 1) or []
    if givers and all(npc_faction(i) == 'A' for i in givers): continue
    if int(qid) not in have: missing.append((int(qid), at(q, 1)))
if missing: warn('quest data', '%d Horde quests aren\'t in Objectives.lua, e.g. %s' % (len(missing), ', '.join('%s (%d)' % (n, i) for i, n in sorted(missing)[:5])))

print('Waypath+ cross-check: %d problems, %d warnings' % (len(problems), len(warnings)))
for p in problems: print('  PROBLEM  ' + p)
for w in warnings: print('  warning  ' + w)
sys.exit(1 if problems else 0)
