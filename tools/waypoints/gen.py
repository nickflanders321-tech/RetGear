import re, sys, math, json
# Usage: python3 gen.py <QuestieDB checkout> <npcs.tsv from dump.lua> [RetGear folder]
import os
QDB = sys.argv[1].rstrip('/') + '/'
NPCS = sys.argv[2]
RET = (sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')).rstrip('/') + '/'
# --- NPCs
npcs = {}
for line in open(NPCS, encoding='utf-8'):
    nid, name, friend, flags, sub, spawns = line.rstrip('\n').split('\t')
    if len(name) < 3 or name.startswith('[') or 'Trigger' in name or 'Spawn Point' in name or 'Waypoint' in name: continue
    e = npcs.setdefault(name, {'friend': friend, 'flags': int(flags), 'sub': sub, 'spawns': {}})
    for part in spawns.split('|'):
        z, pts = part.split(':')
        e['spawns'].setdefault(int(z), []).extend(tuple(map(float, p.split(','))) for p in pts.split(';'))
# --- zones
enum = {}
for m in re.finditer(r'^\s*([A-Z_0-9]+)\s*=\s*(\d+),', open(QDB + 'src/corrections/enum/zones.lua').read(), re.M):
    enum.setdefault(m.group(1), int(m.group(2)))
ui = {int(a): int(b) for a, b in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', open(QDB + 'support/Forever/Zones/areaIdToUiMapId.lua').read())}
def area(zone):
    key = re.sub(r"[^A-Z0-9]+", "_", zone.upper().replace("'", "")).strip('_')
    return enum.get(key)
CAPITALS = [1497, 1637, 1638]  # Undercity, Orgrimmar, Thunder Bluff
WORD = re.compile(r"[A-Za-z']")
def best_point(pts):
    cx = sum(p[0] for p in pts) / len(pts); cy = sum(p[1] for p in pts) / len(pts)
    return min(pts, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
# Towns and areas the steps mention -> an NPC or mob that lives there (coordinates still come from the Forever data)
PLACES = {
  "Deathknell": "Undertaker Mordo", "Night Web's Hollow": "Night Web Spider", "Brill": "Innkeeper Renee",
  "Solliden": "Scarlet Warrior", "Agamand Mills": "Rattlecage Soldier", "Brightwater Lake": "Clyde Kellen",
  "Undercity": "Brom Killian", "The Sepulcher": "Karos Razok", "Sepulcher": "Karos Razok", "Pyrewood": "Pyrewood Watcher",
  "Orgrimmar": "Doras", "Cleft of Shadow": "Neeru Fireblade", "Crossroads": "Devrak", "Ratchet": "Bragok",
  "Camp Taurajo": "Omusa Thunderhorn", "Sun Rock Retreat": "Tharm", "Windshear Crag": "Venture Co. Logger",
  "Tarren Mill": "Zarise", "Splintertree Post": "Vhulgra", "Zoram'gar Outpost": "Andruk", "Zoram Strand": "Andruk",
  "Freewind Post": "Nyse", "Hammerfall": "Urda", "Shadowprey Village": "Thalon", "Grom'gol": "Thysta",
  "Booty Bay": "Gringer", "Nesingwary": "Hemet Nesingwary", "Brackenwall Village": "Shardi", "Kargath": "Gorrik",
  "Stonard": "Breyk", "Gadgetzan": "Bulkrek Ragefist", "Camp Mojache": "Shyn", "Revantusk Village": "Gorkas",
  "Thorium Point": "Grisha", "Marshal's Refuge": "Gryfe", "Bloodvenom Post": "Brakkar", "Flame Crest": "Vahgruk",
  "Everlook": "Yugrek", "Light's Hope": "Georgia", "Thunder Bluff": "Tal", "Tidefury Cove": "Nat Pagle",
  "Fenris Isle": "Thule Ravenclaw", "Deathknell chapel": "Shadow Priest Sarvis",
}
ROLES = [("flight path", 8), ("flight master", 8), ("innkeeper", 128), ("make it your home", 128), ("hearthstone", 128)]
def anchor_point(name, zones):
    e = npcs.get(name)
    if not e: return None
    for z in zones:
        if z in e['spawns'] and z in ui:
            pts = e['spawns'][z]
            return (z, pts[0] if len(pts) <= 2 else best_point(pts))
    for z, pts in e['spawns'].items():
        if z in ui: return (z, pts[0] if len(pts) <= 2 else best_point(pts))
    return None
role_npcs = {}
for name, e in npcs.items():
    if 'H' in e['friend']:
        for _, flag in ROLES:
            if e['flags'] & flag: role_npcs.setdefault(flag, []).append(name)
def nearest_role(flag, zone, near):
    best = None
    for name in role_npcs.get(flag, []):
        pts = npcs[name]['spawns'].get(zone)
        if not pts: continue
        p = pts[0]
        d = ((p[0] - near[0]) ** 2 + (p[1] - near[1]) ** 2) if near else 0
        if best is None or d < best[0]: best = (d, name, p)
    return best and (ui[zone], round(best[2][0], 1), round(best[2][1], 1), best[1])
missing_anchor = set()
def find_any(text, zones, hub=None):
    cands = []
    w = find(text, zones)
    if w: cands.append((w[4], w[:4]))
    for place, anchor in PLACES.items():
        i = text.find(place)
        if i >= 0:
            ap = anchor_point(anchor, zones)
            if not ap: missing_anchor.add(anchor); continue
            cands.append((i, (ui[ap[0]], round(ap[1][0], 1), round(ap[1][1], 1), place)))
    low = text.lower()
    for kw, flag in ROLES:
        i = low.find(kw)
        if i >= 0 and zones and zones[0] in ui:
            near = None
            placed = [c for c in cands if c[1][0] == ui[zones[0]]]
            if placed: near = (placed[0][1][1], placed[0][1][2])
            elif hub: near = hub
            r = nearest_role(flag, zones[0], near)
            if r: cands.append((i, r))
    if not cands: return None
    home = ui.get(zones[0]) if zones else None
    cands.sort(key=lambda c: (0 if c[1][0] == home else 1, c[0]))
    return cands[0][1]
def find(text, zones):
    hits = []
    for name, e in npcs.items():
        if len(name) < 5: continue
        i = text.find(name)
        if i < 0:
            i = text.find(name[0] + name[1:].lower())
            if i < 0 or len(name) < 8: continue
        if i > 0 and WORD.match(text[i - 1]): continue
        j = i + len(name)
        if j < len(text) and WORD.match(text[j]) and text[j] not in "s'": continue
        for rank, z in enumerate(zones):
            if z in e['spawns'] and z in ui:
                hits.append((i, rank, -len(name), name, z)); break
    if not hits: return None
    hits.sort()
    i, rank, _, name, z = hits[0]
    pts = npcs[name]['spawns'][z]
    x, y = pts[0] if len(pts) <= 2 else best_point(pts)
    return (ui[z], round(x, 1), round(y, 1), name, i)
data = open(RET + 'Data.lua', encoding='utf-8').read()
steps_block = data[data.index('RG.STEPS = {'):]
steps_block = steps_block[:steps_block.index('\n}\n')]
# Dungeon entrances (Forever percentages, Era-based table before the expansion overrides)
dsrc = open(QDB + 'support/Forever/Zones/dungeons.lua', encoding='utf-8').read()
dsrc = dsrc[:dsrc.index('if Expansions.Current')]
dungeons = {}
for name, z, x, y in re.findall(r'\{"([^"]+)",[^\n]*?\{\{(\d+),\s*([\d.]+),\s*([\d.]+)\}', dsrc):
    if int(z) in ui and name not in dungeons: dungeons[name] = (ui[int(z)], float(x), float(y), name + " entrance")
hubs = {}
for m in re.finditer(r'from = (\d+),\s*to = \d+,\s*kind = "\w+",\s*zone = "([^"]+)", hub = "([^"]*)"(?:, fp = "([^"]*)")?', data):
    frm, zone, hub, fp = m.groups()
    key = zone + '|' + frm
    for nm in (fp, hub):
        if not nm: continue
        for place, anchor in PLACES.items():
            if place in nm:
                a = area(zone); ap = anchor_point(anchor, ([a] if a else []))
                if ap: hubs[key] = ap[1]; break
        if key in hubs: break
out_steps, total, found = {}, 0, 0
missing = []
for m in re.finditer(r'\["([^"]+)\|(\d+)"\]\s*=\s*\{(.*?)\n  \},', steps_block, re.S):
    zone, frm, body = m.group(1), m.group(2), m.group(3)
    texts = re.findall(r'"((?:[^"\\]|\\.)*)"', body)
    a = area(zone)
    zones = ([a] if a else []) + CAPITALS
    res = {}
    for k, t in enumerate(texts, 1):
        total += 1
        w = find_any(t, zones, hubs.get(zone + '|' + frm))
        LOC = ('entrance', 'cave is', 'keep is', 'is in the', 'sits between', 'is here', 'right in your backyard', 'ride north')
        if zone in dungeons and any(k in t.lower() for k in LOC):
            w = dungeons[zone]
        if w: res[k] = w[:4]; found += 1
        else: missing.append(zone + ': ' + t[:70])
    if res: out_steps[zone + '|' + frm] = res
# --- people mentioned elsewhere: dungeon quest givers, mail quest givers, camp plan NPCs
def first_npc_any(text, prefer=None):
    zones = ([prefer] if prefer else []) + CAPITALS + [z for z in ui]
    return find(text, zones)
givers = {}
dq = data[data.index('RG.DUNGEON_QUESTS'):]
for q, giver, where in re.findall(r'\{ "([^"]+)", "([^"]+)", "([^"]+)" \}', dq[:dq.index('\n}\n')]):
    city = where.split(',')[0]
    w = find(giver, ([area(city)] if area(city) else []) + CAPITALS + list(ui))
    if w: givers[giver] = w[:4]
mail = open(RET + 'Mail.lua', encoding='utf-8').read()
for zone, giver in re.findall(r'zone = "([^"]+)", lvl = \d+, req = \d+, giver = "([^"]+)"', mail):
    w = find_any(giver, ([area(zone)] if area(zone) else []) + list(ui))
    if w: givers[giver] = w[:4]
camp = open(RET + 'Camp.lua', encoding='utf-8').read()
camp_out = {}
for idx, (zone, text) in enumerate(re.findall(r'\{ lvl = \d+,\s+zone = "([^"]+)", text = "((?:[^"\\]|\\.)*)"', camp), 1):
    w = find_any(text, ([area(zone)] if area(zone) else []) + CAPITALS + list(ui))
    if w: camp_out[idx] = w[:4]
print('anchors not in Forever data:', missing_anchor, file=sys.stderr)
print(f'steps: {found}/{total} with a waypoint; givers {len(givers)}; camp {len(camp_out)}', file=sys.stderr)
for m_ in missing[:200]: print('  no match:', m_, file=sys.stderr)
def lw(w): return '{ %d, %.1f, %.1f, "%s" }' % (w[0], w[1], w[2], w[3].replace('"', '\\"'))
L = ['-- RetGear waypoints for route steps, quest givers and camp/fish/cook trainers.',
     '-- Generated from QuestieDB\'s WoW Forever NPC data (game build 1.60.1, map coordinates',
     '-- already converted to Forever\'s maps): https://github.com/Questie/QuestieDB',
     '-- Each entry: { uiMapID, x, y, label }. Regenerated by the weekly update.',
     'local _, RG = ...', 'RG.WAYPOINTS = {', '  steps = {']
for key in sorted(out_steps):
    L.append('    ["%s"] = { %s },' % (key, ', '.join('[%d] = %s' % (k, lw(v)) for k, v in sorted(out_steps[key].items()))))
L.append('  },'); L.append('  givers = {')
for g in sorted(givers): L.append('    ["%s"] = %s,' % (g.replace('"', '\\"'), lw(givers[g])))
L.append('  },'); L.append('  dungeons = {')
for d in sorted(dungeons): L.append('    ["%s"] = %s,' % (d.replace('"', '\\"'), lw(dungeons[d])))
L.append('  },'); L.append('  camp = {')
for k in sorted(camp_out): L.append('    [%d] = %s,' % (k, lw(camp_out[k])))
L.append('  },'); L.append('}')
open(RET + 'Waypoints.lua', 'w', encoding='utf-8').write('\n'.join(L) + '\n')
