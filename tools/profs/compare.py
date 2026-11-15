#!/usr/bin/env python3
"""Compare each profession plan (Professions/*.lua) with the saved route of wow-professions.com's WoW Forever guide
(tools/sources/profguides/<guide>.txt, kept by the hourly watcher). Prints the steps that differ: a different range,
craft or count. Steps where the guide offers choices ("one of these three") show up too: check those by eye.
Usage: python3 tools/profs/compare.py [Waypath+ folder]"""
import re, glob, os
import sys
R=(sys.argv[1] if len(sys.argv) > 1 else '.').rstrip('/') + '/'
MAP={'alchemy':'Alchemy','blacksmithing':'Blacksmithing','enchanting':'Enchanting','engineering':'Engineering','leatherworking':'Leatherworking','tailoring':'Tailoring','cooking':'Cooking','first-aid':'FirstAid'}
for slug, f in MAP.items():
    lines=open(R+'tools/sources/profguides/%s.txt'%slug).read().split('\n')
    # guide steps: a "a-b" line followed by "Nx Craft - ..." lines (the first is the main pick)
    guide=[]; i=0
    start=next((k for k,l in enumerate(lines) if re.match(r'^Apprentice', l)), 0)
    rng=None
    for l in lines[start:]:
        m=re.match(r'^(\d{1,3})\s*-\s*(\d{1,3})$', l.strip())
        if m: rng=(int(m.group(1)),int(m.group(2))); continue
        m=re.match(r'^(\d+)x (.+?) - ', l)
        if m and rng: guide.append((rng[0],rng[1],int(m.group(1)),m.group(2).strip())); rng=None
    src=open(R+'Professions/%s.lua'%f).read()
    plan=[(int(a),int(b),re.search(r'n = (\d+)',r).group(1) if re.search(r'n = (\d+)',r) else '?',re.search(r'craft = "([^"]+)"',r).group(1)) for a,b,r in re.findall(r'\{ from = (\d+),\s*to = (\d+),\s*(craft = .*)\}', src)]
    print('===', f)
    gi={(a,b):(n,c) for a,b,n,c in guide}
    pi={(a,b):(n,c) for a,b,n,c in plan}
    for k in sorted(set(gi)|set(pi)):
        g=gi.get(k); p=pi.get(k)
        same = g and p and (g[1].lower() in p[1].lower()) and str(g[0])==str(p[0])
        if not same: print('  %3d-%3d  guide: %-55s ours: %s' % (k[0],k[1], ('%sx %s'%g) if g else '-', ('%sx %s'%(p[0],p[1])) if p else '-'))
