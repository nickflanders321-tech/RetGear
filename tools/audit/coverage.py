"""Route coverage, zone by zone: how many generated steps, quests and map pins each questing zone has, per faction.
Runs on every push (GitHub Actions summary). A zone with quest data but no steps is flagged; a zone still waiting for
WoW Forever's data (Riverglades, Mount Hyjal before launch) is listed as waiting, not as a failure.
Usage: python3 tools/audit/coverage.py [--markdown]"""
import re, sys
md = '--markdown' in sys.argv
gen = open('Routes/Generated.lua', encoding='utf-8').read()

def gen_steps(letter):
    """{ "Zone|from": (steps, quests, pins) } for one letter of RG.GEN_STEPS (X = Horde, F = Alliance)."""
    out = {}
    m = re.search(r'^  %s = \{\n(.*?)^  \},' % letter, gen, re.S | re.M)
    body = m.group(1) if m else ''
    for key, block in re.findall(r'^    \["(.+?)"\] = \{\n(.*?)^    \},', body, re.S | re.M):
        steps = re.findall(r'q = \{ ([\d, ]*) \}, w = \{ (\d+)', block)
        out[key] = (len(steps), sum(len([x for x in q.split(',') if x.strip()]) for q, _ in steps), sum(1 for _, w in steps if w != '0'))
    for key, block in re.findall(r'^RG\.GEN_STEPS\.%s\["(.+?)"\] = \{\n(.*?)^\}' % letter, gen, re.S | re.M):
        steps = re.findall(r'q = \{ ([\d, ]*) \}, w = \{ (\d+)', block)
        out[key] = (len(steps), sum(len([x for x in q.split(',') if x.strip()]) for q, _ in steps), sum(1 for _, w in steps if w != '0'))
    return out

def route(path):
    src = open(path, encoding='utf-8').read()
    return [(z, int(f), int(t)) for f, t, z in re.findall(r'from = (\d+), to = (\d+), kind = "zone",\s*zone = "(.+?)"', src)]

rows, waiting = [], []
for faction, path, letter in (('Horde', 'Routes/Horde.lua', 'X'), ('Alliance', 'Routes/Alliance.lua', 'F')):
    gs = gen_steps(letter)
    for zone, lo, hi in sorted(route(path), key=lambda r: (r[1], r[0])):
        st = gs.get('%s|%d' % (zone, lo))
        if st is None or st[0] == 0:
            waiting.append('%s %s %d-%d' % (faction, zone, lo, hi))
            continue
        rows.append((faction, zone, lo, hi) + st)
if md:
    print('### Route coverage\n\n| Faction | Zone | Levels | Steps | Quests | Pins |\n|---|---|---|---|---|---|')
    for f, z, lo, hi, s, q, p in rows: print('| %s | %s | %d-%d | %d | %d | %d%% |' % (f, z, lo, hi, s, q, round(100 * p / max(1, s))))
    if waiting: print('\n**No steps yet (waiting for WoW Forever quest data, or hand-written steps):** ' + ', '.join(waiting))
else:
    for f, z, lo, hi, s, q, p in rows: print('%-8s %-30s %2d-%2d  %3d steps  %3d quests  pins %3d%%' % (f, z, lo, hi, s, q, round(100 * p / max(1, s))))
    print('\nNo steps yet:', ', '.join(waiting) or 'none')
    thin = [r for r in rows if r[5] < 6]
    if thin: print('Thin zones (fewer than 6 quests):', ', '.join('%s %s' % (r[0], r[1]) for r in thin))
