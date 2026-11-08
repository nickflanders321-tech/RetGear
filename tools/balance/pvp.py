"""Arena duels between players, class against class, from /wp share reports.

Each report may carry lines `A|<card update>|<your class>|<their class>|<won>|<lost>` (totals on that character for
that update, no names). Reports come from GitHub issues labelled "quests" and from text files in
tools/community/reports/, as for tools/community/import.py. A report pasted twice (same lines) counts once, and a
newer report from the same character supersedes nothing (there is no name to match), so treat small samples with care.

Usage: python3 tools/balance/pvp.py [repo] [update, e.g. 1.24]   (default: the newest update seen)
Prints each class's win rate against players and the class-against-class table.
"""
import collections, json, os, re, subprocess, sys

REPO = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('GITHUB_REPOSITORY', 'nickflanders321-tech/RetGear')
WANT = sys.argv[2] if len(sys.argv) > 2 else None
HERE = os.path.dirname(os.path.abspath(__file__))
REPORTS = os.path.join(HERE, '..', 'community', 'reports')

texts = []
try:
    raw = subprocess.run(['gh', 'api', '--paginate', 'repos/%s/issues?state=all&labels=quests&per_page=100' % REPO],
                         capture_output=True, text=True, check=True, timeout=60).stdout
    for chunk in re.findall(r'\[.*?\](?=\[|\s*$)', raw, re.S) or [raw]:
        try:
            for it in json.loads(chunk): texts.append(it.get('body') or '')
        except ValueError: pass
except Exception as e:
    print('note: could not read issues (%s); using local reports only' % e, file=sys.stderr)
if os.path.isdir(REPORTS):
    for fn in sorted(os.listdir(REPORTS)):
        if fn.endswith('.txt'): texts.append(open(os.path.join(REPORTS, fn), encoding='utf-8').read())

seen = set()
by = collections.defaultdict(lambda: collections.defaultdict(lambda: [0, 0]))   # update -> (me, foe) -> [won, lost]
pat = re.compile(r'^A\|(\d+\.\d+)\|([A-Z]+)\|([A-Z]+)\|(\d+)\|(\d+)\s*$', re.M)
for t in texts:
    lines = tuple(sorted(m.group(0).strip() for m in pat.finditer(t)))
    if not lines or lines in seen: continue
    seen.add(lines)
    for m in pat.finditer(t):
        ver, me, foe, w, l = m.group(1), m.group(2), m.group(3), int(m.group(4)), int(m.group(5))
        e = by[ver][(me, foe)]; e[0] += w; e[1] += l

if not by:
    print('No Arena lines in any report yet.'); sys.exit(0)
ver = WANT or max(by, key=lambda v: tuple(int(x) for x in v.split('.')))
t = by[ver]
print('Arena duels between players, card update %s  (%d reports)' % (ver, len(seen)))
cls = sorted({c for k in t for c in k})
tot = collections.defaultdict(lambda: [0, 0])
for (me, foe), (w, l) in t.items():
    if me == foe: continue   # mirror games are always 50%
    tot[me][0] += w; tot[me][1] += l
print('\n%-8s %6s %6s %6s' % ('class', 'won', 'lost', 'win%'))
for c in sorted(tot, key=lambda c: -tot[c][0] / max(1, sum(tot[c]))):
    w, l = tot[c]
    print('%-8s %6d %6d %5.0f%%' % (c[:8], w, l, 100 * w / max(1, w + l)))
print('\nrow beats column (win%, games):')
print('%-8s' % '' + ''.join('%10s' % c[:8] for c in cls))
for a in cls:
    row = '%-8s' % a[:8]
    for b in cls:
        w, l = t.get((a, b), [0, 0])
        row += '%10s' % ('-' if w + l == 0 else '%d%% %d' % (round(100 * w / (w + l)), w + l))
    print(row)
