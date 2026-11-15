#!/usr/bin/env python3
"""Check every profession plan (Professions/*.lua) against WoW Forever's own crafting tables (the game client's
SkillLineAbility, SpellReagents, SpellEffect and ItemSparse, exported to the data/wago branch by fetch-wago.yml).

For every craft step { from, to, craft, n, mats }:
  * the craft is a recipe of that profession in the game (each of "A, B or C" when a step lists choices)
  * you can learn it by the step's start (its learn rank is at or below `from`)
  * it still gives skill-ups at the step's end (`to` is below the point it turns grey)
  * `n`, the crafts the plan asks for, is close to what the game's skill-up chances need (orange always gives a point,
    yellow and green less often: chance = (grey - skill) / (grey - yellow))
  * the materials text names the game's reagents, with the game's counts
For every training step: the rank is trained at the skill the game needs (Journeyman 50, Expert 125, Artisan 200).

Errors (wrong for the current game) fail the run, so the hourly watcher opens a "needs-claude" issue instead of
releasing; warnings are printed. Usage: python3 tools/profs/check.py <wago folder> [Waypath+ folder] [--json out.json]
  --fix-n   set n to the crafts the game's chances need, plus 10%, on new steps (n = 0) and steps asking for too few
"""
import csv, glob, gzip, io, json, math, os, re, sys

WAGO = sys.argv[1].rstrip('/') + '/'
ADDON = (sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith('--') else '.').rstrip('/') + '/'
JSON_OUT = sys.argv[sys.argv.index('--json') + 1] if '--json' in sys.argv else None
FIX_N = '--fix-n' in sys.argv   # rewrite each step's n to what the game's chances need (+10%), for Claude's updates


def table(name):
    for p in (WAGO + name + '.csv.gz', WAGO + name + '.csv'):
        if os.path.exists(p):
            raw = gzip.open(p, 'rt', encoding='utf-8') if p.endswith('.gz') else open(p, encoding='utf-8')
            return csv.DictReader(raw)
    sys.exit('missing %s in %s' % (name, WAGO))


SKILL = {'Alchemy': 171, 'Blacksmithing': 164, 'Enchanting': 333, 'Engineering': 202, 'Leatherworking': 165,
         'Tailoring': 197, 'Cooking': 185, 'First Aid': 129, 'Mining': 186}
LINE_PROF = {v: k for k, v in SKILL.items()}

spell_name = {int(r['ID']): r['Name_lang'] for r in table('SpellName')}
item_name = {int(r['ID']): r['Display_lang'] for r in table('ItemSparse')}
abil = {}    # (prof, lower-case name) -> [ {spell, learn, yellow, grey, ups, acquire} ]
for r in table('SkillLineAbility'):
    prof = LINE_PROF.get(int(r['SkillLine']))
    if not prof: continue
    sp = int(r['Spell'])
    nm = spell_name.get(sp)
    if not nm: continue
    abil.setdefault((prof, nm.lower()), []).append({
        'spell': sp, 'learn': int(r['MinSkillLineRank'] or 0), 'yellow': int(r['TrivialSkillLineRankLow'] or 0),
        'grey': int(r['TrivialSkillLineRankHigh'] or 0), 'ups': max(1, int(r['NumSkillUps'] or 1)), 'acquire': int(r['AcquireMethod'] or 0)})
reagents = {}
for r in table('SpellReagents'):
    rs = []
    for i in range(8):
        it, n = int(r['Reagent_%d' % i] or 0), int(r['ReagentCount_%d' % i] or 0)
        if it > 0 and n > 0: rs.append((it, n))
    reagents[int(r['SpellID'])] = rs


def recipe(prof, name):
    """the game's recipe for a craft name (the one that gives skill-ups and is still taught, if there are several)"""
    rs = abil.get((prof, name.lower()))
    if not rs and prof == 'Mining': rs = abil.get((prof, 'smelt ' + name.lower()))
    if not rs: return None
    rs = [x for x in rs if x['grey'] > 0] or rs
    return max(rs, key=lambda x: (x['grey'], -x['learn']))


def chance(rec, skill):
    if skill < rec['yellow']: return 1.0
    if skill >= rec['grey']: return 0.0
    return (rec['grey'] - skill) / float(rec['grey'] - rec['yellow'])


def crafts_needed(recs, a, b):
    """how many crafts take you from a to b, always making the choice with the best chance at each point"""
    total = 0.0
    for s in range(a, b):
        best = max(((chance(r, s), r['ups'] if s < r['yellow'] else 1) for r in recs), default=(0, 1))
        if best[0] <= 0: return None
        total += 1.0 / best[0] / best[1]
    return total


def choices(craft):
    return [c.strip() for c in re.split(r',\s*|\s+or\s+', craft) if c.strip()]


STEP = re.compile(r'\{\s*from\s*=\s*(\d+),\s*to\s*=\s*(\d+),\s*(.*)\}\s*,?\s*(?:--.*)?$')
def field(body, key):
    m = re.search(key + r'\s*=\s*"((?:[^"\\]|\\.)*)"', body)
    if m: return m.group(1)
    m = re.search(key + r'\s*=\s*(\d+)', body)
    return int(m.group(1)) if m else None


RANK_AT = {'journeyman': 50, 'expert': 125, 'artisan': 200}
errors, warnings, report = [], [], []
fixes = {}   # path -> [(old line, new line)]
for path in sorted(glob.glob(ADDON + 'Professions/*.lua')):
    src = open(path, encoding='utf-8').read()
    m = re.search(r'name\s*=\s*"([^"]+)"', src)
    if not m or os.path.basename(path) == 'Generated.lua': continue
    prof = m.group(1)
    if prof not in SKILL: continue     # gathering and fishing: nothing to craft
    lists = re.findall(r'\w\.(plan\w*)\s*=\s*\{(.*?)\n\}', src, re.S)
    for plan_name, body in lists:
        for ln, line in enumerate(body.split('\n')):
            sm = STEP.search(line.strip())
            if not sm: continue
            a, b, rest = int(sm.group(1)), int(sm.group(2)), sm.group(3)
            where = '%s %s %d-%d' % (prof, plan_name, a, b)
            tr = field(rest, 'train')
            if tr:
                rk = tr.split()[0].lower()
                if rk in RANK_AT and a != RANK_AT[rk]:
                    errors.append('%s: %s is trained at skill %d in the game, not %d' % (where, tr.split()[0], RANK_AT[rk], a))
                continue
            craft = field(rest, 'craft')
            if not craft: continue
            n, mats = field(rest, 'n'), field(rest, 'mats') or ''
            recs, missing = [], []
            for c in choices(craft):
                r = recipe(prof, c)
                if r: recs.append(dict(r, name=c))
                else: missing.append(c)
            for c in missing:
                errors.append('%s: "%s" is not a %s recipe in WoW Forever' % (where, c, prof))
            if not recs: continue
            learn = min(r['learn'] for r in recs)
            grey = max(r['grey'] for r in recs)
            if learn > a:
                errors.append('%s: %s can only be learned at %d' % (where, craft, learn))
            if b > grey:
                errors.append('%s: %s turns grey at %d, before the step ends at %d' % (where, craft, grey, b))
            need = crafts_needed(recs, max(a, learn), min(b, grey))
            entry = {'prof': prof, 'plan': plan_name, 'from': a, 'to': b, 'craft': craft, 'n': n,
                     'need': round(need, 1) if need else None, 'learn': learn, 'grey': grey,
                     'yellow': min(r['yellow'] for r in recs), 'spells': [r['spell'] for r in recs]}
            report.append(entry)
            # (only a new step, n = 0, or one asking for too few: a bigger n is often on purpose, extras kept for later steps)
            if FIX_N and need and b > a and n is not None and (n == 0 or n < need * 0.85 - 1):
                want = int(math.ceil(need * 1.1))
                if want != n:
                    fixes.setdefault(path, []).append((line, re.sub(r'\bn\s*=\s*\d+', 'n = %d' % want, line, count=1)))
                    n = want
            if need and n and b > a:
                # the plan should cover the average with a little to spare, but not ask for far more than needed
                if n < need * 0.85 - 1:
                    errors.append('%s: %d x %s is too few; the game needs about %d' % (where, n, craft, round(need)))
                elif n > need * 1.6 + 3:
                    warnings.append('%s: %d x %s is more than needed (about %d)' % (where, n, craft, round(need)))
            # the materials of the first choice: every "N Name" in the text before "each" must match the game
            # (a step with several choices describes them loosely: not checked)
            if len(recs) > 1 or missing: continue
            r0 = recs[0]
            game = {item_name.get(i, '').lower(): (i, k) for i, k in reagents.get(r0['spell'], [])}
            head = mats.split(' each')[0].split(' (')[0]
            said = {}
            for cnt, nm in re.findall(r'(\d+)\s+([A-Z][A-Za-z\' -]+?)(?=,|$| and )', head):
                said[nm.strip().lower()] = int(cnt)
            for nm, cnt in said.items():
                key = nm if nm in game else (nm.rstrip('s') if nm.rstrip('s') in game else None)
                if key is None:
                    if game: warnings.append('%s: the materials text names %s, which %s doesn\'t use' % (where, nm, r0['name']))
                elif game[key][1] != cnt:
                    errors.append('%s: %s takes %d %s in the game, the text says %d' % (where, r0['name'], game[key][1], item_name[game[key][0]], cnt))
            if said:
                for nm, (i, k) in game.items():
                    if nm not in said and nm + 's' not in said and not any(nm in s or s in nm for s in said):
                        warnings.append('%s: %s also takes %d %s (not in the materials text)' % (where, r0['name'], k, item_name.get(i, i)))

for path, fx in fixes.items():
    s = open(path, encoding='utf-8').read()
    for old, new in fx: s = s.replace(old, new, 1)
    open(path, 'w', encoding='utf-8').write(s)
    print('fixed n in %d steps of %s' % (len(fx), os.path.basename(path)))
for w in warnings: print('warning: ' + w)
for e in errors: print('ERROR: ' + e)
print('%d craft steps checked: %d errors, %d warnings (game tables: %s)' % (len(report), len(errors), len(warnings),
      open(WAGO + 'BUILD.txt').read().split()[0] if os.path.exists(WAGO + 'BUILD.txt') else '?'))
if JSON_OUT: json.dump(report, open(JSON_OUT, 'w'), indent=1)
sys.exit(1 if errors else 0)
