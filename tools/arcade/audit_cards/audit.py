"""Check every card against the game data: NPC models (in WoW Forever's model table, belonging to a creature of that
name), the level and type on the card, item names, qualities and item levels (WoW Forever's own item table).
  lua5.1 tools/arcade/audit_cards/dump.lua /tmp/cards
  python3 tools/arcade/audit_cards/audit.py <regen dir with classic.sql, qdb, wago> /tmp/cards
(Expected: "item not in WoW Forever" lists items whose icons are still in the game's main item table; "level on the
card differs" lists WoW Forever's own creatures that share a name with an older one.)
"""
import re, csv, gzip, sys, collections, os
R = sys.argv[1].rstrip('/') + '/'; C = sys.argv[2].rstrip('/') + '/'
sys.path.insert(0, 'tools/arcade')
src = open('tools/arcade/gen.py', encoding='utf-8').read()
head = src[:src.index("BAD = re.compile")]
sys.argv = ['gen.py', R + 'classic.sql', R + 'qdb', '.']
ns = {}; exec(head, ns); rows = ns['rows']
def clean(n): return re.sub(r'\s+', ' ', n).strip()
T = {}
for e, n, lo, hi, m1, m2, m3, m4, rank, ctype in rows('creature_template', ['Entry', 'Name', 'MinLevel', 'MaxLevel', 'ModelId1', 'ModelId2', 'ModelId3', 'ModelId4', 'Rank', 'CreatureType']):
    T[int(e)] = dict(name=clean(n), lo=int(lo), hi=int(hi), models={int(x) for x in (m1, m2, m3, m4) if int(x or 0)}, rank=int(rank), type=int(ctype))
spawns = collections.Counter(int(r[0]) for r in rows('creature', ['id']))
byname = collections.defaultdict(list)
for e, t in T.items(): byname[t['name'].lower()].append(e)
W = R + 'wago/'
disp_ok = {int(r['ID']) for r in csv.DictReader(gzip.open(W + 'CreatureDisplayInfo.csv.gz', 'rt'))}
items = {int(r['ID']): r for r in csv.DictReader(gzip.open(W + 'ItemSparse.csv.gz', 'rt'))}
QN = ['Poor', 'Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Artifact']
TYPE = {1: 'beast', 2: 'dragonkin', 3: 'demon', 4: 'elemental', 5: 'giant', 6: 'undead', 7: 'humanoid', 8: 'critter', 9: 'mechanical', 10: 'not specified', 11: 'totem'}
cards = [l.rstrip('\n').split('\t') for l in open(C + 'cards.tsv', encoding='utf-8')]
issues = collections.defaultdict(list)
for i, kind, name, tier, ref, text, disp, cid, owner, dup in cards:
    if kind == '2':
        d = int(disp) if disp else 0
        ents = byname.get(name.lower(), [])
        m = re.search(r'level (\d+)', text); lvl = int(m.group(1)) if m else None
        if d and d not in disp_ok: issues['model missing from the game'].append((name, d, text))
        if not ents:
            if not d and not cid and not text.startswith('Mythic'): issues['painted scene instead of a model (no creature of that name)'].append((name, '', text))
            continue
        if not d and not cid and any(T[e]['models'] for e in ents): issues['no model, though the creature has one'].append((name, text, ents[:3]))
        allm = set().union(*(T[e]['models'] for e in ents))
        if d and d not in allm:
            issues['model belongs to another creature'].append((name, d, text, sorted(allm)[:6]))
        # the creature that fits the card best: spawned, and its level matches the card
        def fit(e): t = T[e]; return ((lvl is not None and t['lo'] <= lvl <= t['hi']), spawns[e] > 0, -abs((lvl or t['hi']) - t['hi']))
        best = max(ents, key=fit)
        if d and len(ents) > 1 and d not in T[best]['models']:
            sets = {frozenset(T[e]['models']) for e in ents}
            if len(sets) > 1:
                issues['name shared: shows another creature of the same name'].append((name, d, text, best, sorted(T[best]['models'])[:4], [(e, T[e]['lo'], T[e]['hi'], spawns[e], sorted(T[e]['models'])[:3]) for e in ents][:6]))
        bt = T[best]
        if lvl is not None and not (bt['lo'] - 1 <= lvl <= bt['hi'] + 1):
            issues['level on the card differs'].append((name, lvl, (bt['lo'], bt['hi']), text))
        ty = next((v for v in TYPE.values() if text.endswith(' ' + v)), None)
        if ty and TYPE.get(bt['type']) and ty != TYPE[bt['type']]:
            issues['creature type on the card differs'].append((name, ty, TYPE[bt['type']], text))
    elif kind == '1':
        iid = int(ref or 0)
        it = items.get(iid)
        if not it:
            issues['item not in WoW Forever'].append((name, iid, text)); continue
        gname = clean(it['Display_lang'])
        if gname.lower() != name.lower(): issues['item name differs in WoW Forever'].append((name, gname, iid))
        q = int(it['OverallQualityID'] or 0); il = int(it['ItemLevel'] or 0)
        m = re.match(r'(\w+) item, item level (\d+)', text)
        if m:
            if m.group(1) != QN[q]: issues['item quality differs'].append((name, m.group(1), QN[q], iid))
            if int(m.group(2)) != il: issues['item level differs'].append((name, int(m.group(2)), il, iid))
# Real problems stop a release (tools/watch/regenerate.sh: the hourly watcher then opens a "needs-claude" issue);
# the rest are known differences, listed for a look.
ERRORS = ['model missing from the game', 'model belongs to another creature', 'name shared: shows another creature of the same name',
          'no model, though the creature has one', 'creature type on the card differs']
nerr = nwarn = 0
for k, v in sorted(issues.items(), key=lambda kv: (kv[0] not in ERRORS, kv[0])):
    bad = k in ERRORS
    if bad: nerr += len(v)
    else: nwarn += len(v)
    print('%s %s: %d' % ('ERROR' if bad else 'note:', k, len(v)))
    for x in v[:(40 if bad else 5)]: print('   ', x)
print('card audit: %d cards, %d errors, %d notes' % (len(cards), nerr, nwarn))
sys.exit(1 if nerr else 0)
