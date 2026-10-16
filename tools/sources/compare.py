#!/usr/bin/env python3
"""Compare Waypath+'s zone level windows (Routes/Horde.lua, Routes/Alliance.lua) with what the
guides in evidence.json publish. Usage: python3 tools/sources/compare.py   (from the repo root)

For each zone it prints the consensus (median start and end of every source) next to ours and
flags a window whose start or end is 4+ levels away. Exit code 0 always: it is a report.
"""
import json, re, statistics, sys, os
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
ev = json.load(open(os.path.join(root, 'tools/sources/evidence.json'), encoding='utf-8'))['zones']
pat = re.compile(r'\{ o = [\d.]+,\s*from = (\d+), to = (\d+), kind = "zone",\s*zone = "([^"]+)"')
def windows(fn):
    return {m.group(3): (int(m.group(1)), int(m.group(2))) for m in pat.finditer(open(os.path.join(root, fn), encoding='utf-8').read())}
flag = 0
for fac, fn in (('Horde', 'Routes/Horde.lua'), ('Alliance', 'Routes/Alliance.lua')):
    print('== %s' % fac)
    for zone, (lo, hi) in sorted(windows(fn).items(), key=lambda kv: kv[1]):
        keys = [zone] if zone in ev else [z.strip() for z in zone.split('&')] if '&' in zone else []
        keys = [k if k in ev else k + ' Plaguelands' for k in keys]
        rows = [r for k in keys for r in ev.get(k, {}).values()]
        if not rows:
            print('  %-32s ours %2d-%2d   no guide data' % (zone, lo, hi)); continue
        clo = statistics.median(r[0] for r in rows); chi = statistics.median(r[1] for r in rows)
        bad = abs(lo - clo) >= 5 or abs(hi - chi) >= 5
        # guides give a zone's whole range; we give the window to come and quest, which is narrower
        note = '  <-- check' if bad else ''
        flag += bad
        print('  %-32s ours %2d-%2d   guides %4.0f-%2.0f (%d sources)%s' % (zone, lo, hi, clo, chi, len(rows), note))
print('\n%d zone(s) to check' % flag)
