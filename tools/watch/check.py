#!/usr/bin/env python3
"""Waypath+ watcher, step 1: has anything changed since tools/sources/watch.json?

Checks, cheaply and without Claude:
  * the live WoW Forever game build (Blizzard's patch server, BlizzTrack as a fallback),
  * QuestieDB's WoW Forever data folder (its git tree hash),
  * the game client's own tables (the data/wago branch the fetch-wago workflow exports),
  * new GitHub issues (bug reports) since the last one seen.
Prints GitHub Actions outputs (build_changed, new_build, interface, data_changed, new_tree,
new_issues) and writes the new values to watch.json.new for the workflow to commit once the
work for them is done. Usage: python3 tools/watch/check.py [repo-root]
"""
import json, os, re, subprocess, sys, urllib.request

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
WATCH = os.path.join(ROOT, 'tools/sources/watch.json')
REPO = os.environ.get('GITHUB_REPOSITORY', 'nickflanders321-tech/RetGear')
state = json.load(open(WATCH))
out = {}

def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers={'User-Agent': 'Waypath-watch (github.com/%s)' % REPO})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode('utf-8', 'replace')

# --- 1. game build -----------------------------------------------------------
# WoW Forever builds are 1.60 and up. The live game runs under the product `wowf` (BlizzTrack labels it "Stress
# Test"; it carried the launch build 1.60.1.70790 on November 4, 2026), the beta under wow_classic_beta. Every likely
# product is asked and the newest Forever build wins (Classic Era, 1.15, and the other Classic versions are ignored
# by the version check).
FOREVER = re.compile(r'^1\.(6\d|[7-9]\d)\.\d+\.\d{4,6}$')
def _ver(v): return tuple(int(x) for x in v.split('.'))
def live_build():
    products = (os.environ.get('FOREVER_PRODUCT') or 'wowf wow_forever wow_camelot wowcamelot wow_classic_forever wow_classic_era wow_classic wow_classic_beta wow_camelot_ptr').split()
    best = (None, None)
    for product in products:
        for url in ('http://us.patch.battle.net:1119/%s/versions' % product,
                    'https://us.version.battle.net/%s/versions' % product):
            try:
                txt = fetch(url)
                for line in txt.splitlines():
                    if line.startswith('us|'):
                        for v in re.findall(r'\|(\d+\.\d+\.\d+\.\d+)\|', line):
                            if FOREVER.match(v) and (not best[0] or _ver(v) > _ver(best[0])): best = (v, url)
                break
            except Exception as e:
                print('note: %s: %s' % (url, e), file=sys.stderr)
    if best[0]: return best
    srcs = [state.get('game_build_source') or 'https://blizztrack.com/view/wowf?type=versions',
            'https://blizztrack.com/view/wowf?type=versions', 'https://blizztrack.com/view/wow_classic_beta?type=versions']
    for src in dict.fromkeys(srcs):
        try:
            found = [v for v in re.findall(r'\b(1\.\d{2}\.\d+\.\d{4,6})\b', fetch(src)) if FOREVER.match(v)]
            if found and (not best[0] or _ver(max(found, key=_ver)) > _ver(best[0])): best = (max(found, key=_ver), src)
        except Exception as e:
            print('note: %s: %s' % (src, e), file=sys.stderr)
    return best

build, where = live_build()
out['build_changed'] = 'false'
if build and build != state.get('game_build'):
    out['build_changed'] = 'true'
    print('Game build changed: %s -> %s (%s)' % (state.get('game_build'), build, where), file=sys.stderr)
    state['game_build'] = build
if build:
    a, b, c = (int(x) for x in build.split('.')[:3])
    out['interface'] = str(a * 10000 + b * 100 + c)
    out['new_build'] = build
else:
    print('warning: could not read the live game build', file=sys.stderr)

# --- 2. QuestieDB WoW Forever data -------------------------------------------
tree = None
try:
    tmp = os.path.join(os.environ.get('RUNNER_TEMP', '/tmp'), 'qw')
    subprocess.run(['rm', '-rf', tmp], check=True)
    subprocess.run(['git', 'clone', '-q', '--depth', '1', '--filter=blob:none', '--no-checkout',
                    'https://github.com/Questie/QuestieDB', tmp], check=True)
    tree = subprocess.run(['git', '-C', tmp, 'rev-parse', 'HEAD:src/corrections/Forever'],
                          capture_output=True, text=True, check=True).stdout.strip()
except Exception as e:
    print('warning: could not read QuestieDB: %s' % e, file=sys.stderr)
out['data_changed'] = 'false'
if tree and tree != state.get('questiedb_forever_tree'):
    out['data_changed'] = 'true'
    out['new_tree'] = tree
    print('QuestieDB Forever data changed: %s -> %s' % (state.get('questiedb_forever_tree'), tree), file=sys.stderr)
    state['questiedb_forever_tree'] = tree

# --- 2b. the game client's own tables (data/wago, from .github/workflows/fetch-wago.yml) -----------------------
# New raids, bosses, encounters, loading screens and item icons arrive there with a patch: a new export rebuilds too.
try:
    head = subprocess.run(['git', 'ls-remote', 'https://github.com/%s.git' % REPO, 'refs/heads/data/wago'],
                          capture_output=True, text=True, check=True).stdout.split()
    wago = head[0] if head else None
except Exception as e:
    wago = None
    print('warning: could not read the data/wago branch: %s' % e, file=sys.stderr)
if wago and wago != state.get('wago_export'):
    print('Game client tables changed: %s -> %s' % (state.get('wago_export'), wago), file=sys.stderr)
    state['wago_export'] = wago
    out['data_changed'] = 'true'

# --- 2c. wow-professions.com's WoW Forever profession guides --------------------------------------------------
# Our profession plans follow these guides. Each guide's route (its lines with a skill range or a craft count) is
# kept in tools/sources/profguides/<guide>.txt; when it changes, the workflow opens a "needs-claude" issue with the
# diff so the plan gets updated (and checked against the game's tables by tools/profs/check.py). The first time a
# guide is seen, or when a page can't be read, nothing is reported.
PG = 'https://www.wow-professions.com/forever/'
GUIDES = ['alchemy', 'blacksmithing', 'enchanting', 'engineering', 'leatherworking', 'tailoring', 'cooking', 'first-aid',
          'fishing', 'mining', 'herbalism', 'skinning']
PG_DIR = os.path.join(ROOT, 'tools/sources/profguides')
ROUTE_LINE = re.compile(r'\b\d{1,3}\s*(?:-|\u2013|\u2014|to)\s*\d{1,3}\b|\b\d+\s*x\s+[A-Z]|\bx\s*\d+\b|\(\d+\)')
def page_text(html):
    import html as _h
    html = re.sub(r'(?is)<(script|style|noscript|svg|nav|footer|header|form|aside)\b.*?</\1>', ' ', html)
    html = re.sub(r'(?i)<br\s*/?>|</(p|div|li|tr|h\d|td|th|table|ul|ol)>', '\n', html)
    txt = _h.unescape(re.sub(r'<[^>]+>', ' ', html))
    lines = [re.sub(r'\s+', ' ', l).strip() for l in txt.split('\n')]
    return [l for l in lines if 3 <= len(l) <= 400 and ROUTE_LINE.search(l) and not re.search(r'(?i)cookie|copyright|\u00a9|comment|reply|ago\b', l)]
changed_guides = []
os.makedirs(PG_DIR, exist_ok=True)
pg_state = state.get('profguides') or {}
for g in GUIDES:
    path = os.path.join(PG_DIR, g + '.txt')
    try:
        lines = page_text(fetch(PG + g + '-leveling-guide', timeout=30))
    except Exception as e:
        print('note: %s guide: %s' % (g, e), file=sys.stderr)
        continue
    if len(lines) < 5:
        print('note: %s guide: no route found on the page' % g, file=sys.stderr)
        continue
    import hashlib
    h = hashlib.sha1('\n'.join(lines).encode('utf-8')).hexdigest()
    if pg_state.get(g) and pg_state[g] != h: changed_guides.append(g)
    if pg_state.get(g) != h:
        open(path, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
        pg_state[g] = h
state['profguides'] = pg_state
out['guides_changed'] = ' '.join(changed_guides)
if changed_guides: print('wow-professions.com guides changed: %s' % ', '.join(changed_guides), file=sys.stderr)

# --- 3. new bug reports ------------------------------------------------------
new = []
try:
    raw = subprocess.run(['gh', 'api', 'repos/%s/issues?state=all&sort=created&direction=desc&per_page=30' % REPO],
                         capture_output=True, text=True, check=True).stdout
    last = int(state.get('last_issue_seen') or 0)
    for it in json.loads(raw):
        if 'pull_request' in it: continue
        if it['number'] > last and not any(l['name'] in ('needs-claude', 'quests') for l in it.get('labels', [])) \
           and it.get('user', {}).get('login') != 'github-actions[bot]':
            new.append(it['number'])
    if new: state['last_issue_seen'] = max(new)
except Exception as e:
    print('warning: could not read issues: %s' % e, file=sys.stderr)
out['new_issues'] = ' '.join(str(n) for n in sorted(new))

json.dump(state, open(WATCH + '.new', 'w'), indent=2)
gh_out = os.environ.get('GITHUB_OUTPUT')
lines = ['%s=%s' % (k, v) for k, v in out.items()]
if gh_out:
    with open(gh_out, 'a') as f: f.write('\n'.join(lines) + '\n')
print('\n'.join(lines))
