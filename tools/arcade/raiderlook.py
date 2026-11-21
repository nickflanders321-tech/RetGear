#!/usr/bin/env python3
"""A stand-in model for each Raider card: one of the game's own NPCs of the raider's race and sex, dressed most like
their class's raid set.

A Raider card draws the raider's race in their class's raid set (Arcade.lua: dressModel). On a client that can't change
a model's race (RG.ArcadeRaceProbe finds out), it shows this instead: an NPC of exactly that race and sex (from the
game's CreatureDisplayInfoExtra), never anyone else. No NPC wears the Naxxramas sets, so each NPC's armor (its
NPCModelItemSlotDisplayInfo) is scored against the class:
  +3 a piece from one of the class's raid sets (tier 1, 2 or 3: Might, Wrath, Dreadnaught...)
  +1 a piece of the class's armor type (plate, mail, leather, cloth: from the game's Item table)
  -2 a tabard (a guard's livery is not raid gear); -1 for each of head, shoulders, chest, legs left bare
and the best-dressed one is picked (ties: the lower display id, so the choice is stable).

Usage: python3 tools/arcade/raiderlook.py <wago dir> <addon dir> <classic.sql> <qdb dir>
"""
import collections, csv, gzip, os, re, sys
W, ROOT, SQL, QDB = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
# the SQL reader from tools/arcade/gen.py (the raid sets' tier 1 and 2 pieces are only in the original game's data)
_src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen.py"), encoding="utf-8").read()
_saved, sys.argv = sys.argv, ["gen.py", SQL, QDB if QDB.endswith("/") else QDB + "/", ROOT]
_ns = {}
exec(_src[:_src.index("cards, seen = [], set()")], _ns)
sys.argv = _saved
rows = _ns["rows"]
def table(n): return csv.DictReader(gzip.open(os.path.join(W, n + ".csv.gz"), "rt", encoding="utf-8"))

SETS = {"WARRIOR": ("Might", "Wrath", "Dreadnaught"), "PALADIN": ("Lawbringer", "Judgement", "Redemption"),
        "HUNTER": ("Giantstalker", "Dragonstalker", "Cryptstalker"), "ROGUE": ("Nightslayer", "Bloodfang", "Bonescythe"),
        "PRIEST": ("Prophecy", "Transcendence", "Faith"), "SHAMAN": ("Earthfury", "Ten Storms", "Earthshatter"),
        "MAGE": ("Arcanist", "Netherwind", "Frostfire"), "WARLOCK": ("Felheart", "Nemesis", "Plagueheart"),
        "DRUID": ("Cenarion", "Stormrage", "Dreamwalker")}
ARMOR = {"WARRIOR": 4, "PALADIN": 4, "HUNTER": 3, "SHAMAN": 3, "ROGUE": 2, "DRUID": 2, "PRIEST": 1, "MAGE": 1, "WARLOCK": 1}
ARMOR_SLOTS = {0, 1, 3, 4, 5, 6, 7, 8}          # head, shoulders, chest, waist, legs, feet, wrists, hands
MAIN = (0, 1, 3, 5)                              # head, shoulders, chest, legs
TABARD = 9
LOOKS = 6                                        # NPCs to choose from per race, sex and class

appearance = {}
for r in table("ItemModifiedAppearance"): appearance.setdefault(r["ItemID"], r["ItemAppearanceID"])
display_of = {r["ID"]: r["ItemDisplayInfoID"] for r in table("ItemAppearance")}
item_kind = {r["ID"]: (int(r["ClassID"]), int(r["SubclassID"])) for r in table("Item")}
# each item display: the armor types of the items that use it, and the class whose raid set it belongs to
armor_of = collections.defaultdict(set)
for iid, app in appearance.items():
    d = display_of.get(app); k = item_kind.get(iid)
    if d and k and k[0] == 4: armor_of[d].add(k[1])
set_display = collections.defaultdict(set)
for iid, name, iset in rows("item_template", ["entry", "name", "itemset"]):
    if not int(iset or 0): continue
    for cls, words in SETS.items():
        if any(re.search(r"^%s\b|\bof %s$" % (w, w), name) for w in words):
            d = display_of.get(appearance.get(str(iid)))
            if d: set_display[cls].add(d)

slots = collections.defaultdict(dict)
for r in table("NPCModelItemSlotDisplayInfo"):
    if r["ItemDisplayInfoID"] != "0": slots[r["NpcModelID"]][int(r["ItemSlot"])] = r["ItemDisplayInfoID"]
extra = {r["ID"]: (int(r["DisplayRaceID"]), int(r["DisplaySexID"])) for r in table("CreatureDisplayInfoExtra")}
displays = collections.defaultdict(list)
for r in table("CreatureDisplayInfo"):
    if r["ExtendedDisplayInfoID"] not in ("", "0"): displays[r["ExtendedDisplayInfoID"]].append(int(r["ID"]))

# models real creatures use (an unused one can be a half-made test model): the original game's creatures and WoW
# Forever's own
used = set()
for row in rows("creature_template", ["ModelId1", "ModelId2", "ModelId3", "ModelId4"]):
    for m in row:
        if int(m or 0): used.add(int(m))
for r in table("Creature"):
    for i in range(4):
        d = r.get("DisplayID_%d" % i)
        if d and d != "0": used.add(int(d))

def score(cls, s):
    v = 0
    for slot, d in s.items():
        if slot in ARMOR_SLOTS:
            if d in set_display[cls]: v += 3
            if ARMOR[cls] in armor_of.get(d, ()): v += 1
    if TABARD in s: v -= 2
    v -= sum(1 for m in MAIN if m not in s)
    return v

best = {}
cands = collections.defaultdict(list)    # every dressed NPC of the race and sex, for each class: (score, display)
for eid, (race, sex) in extra.items():
    if not (1 <= race <= 8 and sex in (0, 1)) or eid not in displays: continue
    s = slots.get(eid, {})
    real = [d for d in displays[eid] if d in used]
    if not real: continue
    did = min(real)
    for cls in SETS:
        key = (cls, race, sex)
        cand = (score(cls, s), -did)
        if key not in best or cand > best[key][0]: best[key] = (cand, did)
        cands[key].append((score(cls, s), did))

with open(os.path.join(ROOT, "ArcadeRaiderLook.lua"), "w", encoding="utf-8", newline="\n") as f:
    f.write("local _, RG = ...\n")
    f.write("-- Raider cards on a client that can't change a model's race: an NPC of exactly the raider's race and sex,\n"
            "-- dressed most like their class's raid set (RG.ARCADE_RAIDER_LOOK[class][\"race:sex\"] = display id; sex 0 male,\n"
            "-- 1 female). Generated by tools/arcade/raiderlook.py from the game's own tables: don't edit by hand.\n")
    f.write("RG.ARCADE_RAIDER_LOOK = {\n")
    for cls in sorted(SETS):
        f.write("  %s = { %s },\n" % (cls, ", ".join('["%d:%d"] = %d' % (r, x, best[(cls, r, x)][1])
                                                for r in range(1, 9) for x in (0, 1) if (cls, r, x) in best)))
    f.write("}\n")
    # (several to choose from, so two raiders of the same race, sex and class don't look the same: every NPC dressed
    # nearly as well as the best one, best first, up to LOOKS; a raider takes one by its name)
    f.write("-- the choice for each: RG.ARCADE_RAIDER_LOOKS[class][\"race:sex\"] = { display ids, best dressed first }\n")
    f.write("RG.ARCADE_RAIDER_LOOKS = {\n")
    for cls in sorted(SETS):
        parts = []
        for r in range(1, 9):
            for x in (0, 1):
                k = (cls, r, x)
                if k not in best: continue
                top = best[k][0][0]
                lst = sorted(set(cands[k]), key=lambda v: (-v[0], v[1]))
                pick = [d for sc, d in lst if sc >= max(1, top - 2)][:LOOKS]
                # (too few dressed that well: the next best-dressed, as long as they wear something of the class's kind)
                if len(pick) < 4: pick += [d for sc, d in lst if d not in pick and sc >= 1][:4 - len(pick)]
                if best[k][1] in pick: pick.remove(best[k][1])
                pick = [best[k][1]] + pick[:LOOKS - 1]
                parts.append('["%d:%d"] = { %s }' % (r, x, ", ".join(map(str, pick))))
        f.write("  %s = { %s },\n" % (cls, ", ".join(parts)))
    f.write("}\n")
weak = [(k, v[0][0]) for k, v in best.items() if v[0][0] < 3]
print("raider stand-ins: %d race, sex and class looks; set pieces known: %s; weakest: %s" % (
    len(best), {c: len(v) for c, v in set_display.items()}, sorted(weak, key=lambda x: x[1])[:6]))
missing = [(c, r, x) for c in SETS for r in range(1, 9) for x in (0, 1) if (c, r, x) not in best]
if missing: raise SystemExit("raider stand-ins missing for %s" % missing)
