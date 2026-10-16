#!/usr/bin/env python3
"""Waypath+ watcher, step 1: has anything changed since tools/sources/watch.json?

Checks, cheaply and without Claude:
  * the live WoW Forever game build (Blizzard's patch server, BlizzTrack as a fallback),
  * QuestieDB's WoW Forever data folder (its git tree hash),
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
def live_build():
    product = os.environ.get('FOREVER_PRODUCT', 'wow_classic_beta')
    for url in ('http://us.patch.battle.net:1119/%s/versions' % product,
                'https://us.version.battle.net/%s/versions' % product):
        try:
            txt = fetch(url)
            for line in txt.splitlines():
                if line.startswith('us|'):
                    m = re.search(r'\|(\d+\.\d+\.\d+\.\d+)\|', line)
                    if m: return m.group(1), url
        except Exception as e:
            print('note: %s: %s' % (url, e), file=sys.stderr)
    src = state.get('game_build_source') or 'https://blizztrack.com/view/wow_classic_beta?type=versions'
    try:
        m = re.search(r'\b(1\.\d{2}\.\d+\.\d{4,6})\b', fetch(src))
        if m: return m.group(1), src
    except Exception as e:
        print('note: %s: %s' % (src, e), file=sys.stderr)
    return None, None

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

# --- 3. new bug reports ------------------------------------------------------
new = []
try:
    raw = subprocess.run(['gh', 'api', 'repos/%s/issues?state=all&sort=created&direction=desc&per_page=30' % REPO],
                         capture_output=True, text=True, check=True).stdout
    last = int(state.get('last_issue_seen') or 0)
    for it in json.loads(raw):
        if 'pull_request' in it: continue
        if it['number'] > last and not any(l['name'] == 'needs-claude' for l in it.get('labels', [])) \
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
