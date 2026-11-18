#!/usr/bin/env python3
"""Stat weights from wowsims/forever (https://github.com/wowsims/forever, MIT licence, (c) the wowsims team).

wowsims simulates WoW Forever at level 60 and publishes "EP" stat weights for most specs (ui/specs/*/*/presets.ts).
This reads those numbers (data only), turns them into Waypath+'s units and writes:
  Classes/SimWeights.lua   the weights for every spec wowsims covers (merged over the hand-made ones at load)
  tools/sims/weights.json  the same, for tools/gear/gen.py and the audits

Units: Waypath+ scores crit and hit per 1% (WoW Forever's tooltips show percents), so a rating weight is multiplied by
the rating per percent (ui/sim/constants/mechanics.ts). Main-hand DPS is WEAPON_DPS, ranged DPS is RANGED_DPS.
Each preset is put on Waypath+'s scale: Attack Power = 1 for physical specs (Ranged Attack Power for hunters),
spell damage = 1 for casters, healing = 1 for healers, Stamina = 1 for tanks.
Stats wowsims leaves out (Stamina for damage dealers, Spirit, weapon speed) keep Waypath+'s own levelling values.

Usage: python3 tools/sims/wowsims.py <wowsims/forever checkout> <Waypath+ folder>
"""
import json, os, re, subprocess, sys

SRC, OUT = sys.argv[1], sys.argv[2]

# Waypath+ spec (class, key) -> wowsims preset file and export name
PICK = {
    ("WARRIOR", "arms"): ("warrior/dps", "PreBiSArmsEpWeights"),
    ("WARRIOR", "fury"): ("warrior/dps", "PreBiSFuryEpWeights"),
    ("WARRIOR", "prot"): ("warrior/protection", "PreBiSEpWeights"),
    ("PALADIN", "ret"): ("paladin/retribution", "UnsealedWrathEpWeights"),
    ("HUNTER", "bm"): ("hunter/dps", "WeaveEpWeights"),
    ("HUNTER", "mm"): ("hunter/dps", "WeaveEpWeights"),
    ("HUNTER", "sv"): ("hunter/dps", "MeleeEpWeights"),
    ("ROGUE", "assassination"): ("rogue/dps", "EP_PRESET_ASSASSINATION"),
    ("ROGUE", "combat"): ("rogue/dps", "EP_PRESET_COMBAT_SINISTER"),
    ("ROGUE", "subtlety"): ("rogue/dps", "EP_PRESET_SUBTLETY"),
    ("PRIEST", "shadow"): ("priest/dps", "ShadowEpWeights"),
    ("PRIEST", "disc"): ("priest/healer", "DiscSingleTargetEpWeights"),
    ("PRIEST", "holy"): ("priest/healer", "HolySingleTargetEpWeights"),
    ("SHAMAN", "ele"): ("shaman/elemental", "DefaultEpWeights"),
    ("SHAMAN", "enh"): ("shaman/enhancement", "PreBiSEpWeights"),
    ("DRUID", "balance"): ("druid/balance", "PreBiSEpWeights"),
    ("DRUID", "feral"): ("druid/feralcat", "DefaultEpWeights"),
    ("DRUID", "bear"): ("druid/feralbear", "DefaultEpWeights"),
}
KIND = {"prot": "tank", "bear": "tank", "disc": "heal", "holy": "heal", "shadow": "caster", "ele": "caster", "balance": "caster",
        "bm": "ranged", "mm": "ranged"}

mech = open(os.path.join(SRC, "ui/sim/constants/mechanics.ts")).read()
CONST = {k: float(v) for k, v in re.findall(r'export const (\w+) = ([\d.]+);', mech)}
PER = {"StatHitRating": CONST["HIT_RATING_PER_HIT_PERCENT"], "StatCritRating": CONST["CRIT_RATING_PER_CRIT_PERCENT"],
       "StatDodgeRating": CONST["DODGE_RATING_PER_DODGE_PERCENT"], "StatParryRating": CONST["PARRY_RATING_PER_PARRY_PERCENT"],
       "StatBlockRating": CONST["BLOCK_RATING_PER_BLOCK_PERCENT"], "StatDefenseRating": CONST["DEFENSE_RATING_PER_DEFENSE_LEVEL"],
       "StatHasteRating": CONST["HASTE_RATING_PER_HASTE_PERCENT"]}
# Expertise stays per rating point: WoW Forever items list it as a rating (Edgemaster's Handguards: 10)
MAP = {"StatStrength": "STR", "StatAgility": "AGI", "StatStamina": "STA", "StatIntellect": "INT", "StatSpirit": "SPI",
       "StatSpellDamage": "SP", "StatHealingPower": "HEAL", "StatArcaneDamage": "SP_ARCANE", "StatFireDamage": "SP_FIRE",
       "StatFrostDamage": "SP_FROST", "StatHolyDamage": "SP_HOLY", "StatNatureDamage": "SP_NATURE", "StatShadowDamage": "SP_SHADOW",
       "StatAttackPower": "AP", "StatRangedAttackPower": "RAP", "StatHitRating": "HIT", "StatCritRating": "CRIT",
       "StatMP5": "MP5", "StatArmor": "ARMOR", "StatDefenseRating": "DEF", "StatDodgeRating": "DODGE",
       "StatParryRating": "PARRY", "StatBlockRating": "BLOCK", "StatBlockValue": "BLOCKVAL",
       "StatHasteRating": "HASTE", "StatExpertiseRating": "EXPERTISE", "StatFeralAttackPower": "FAP",
       "PseudoStatMainHandDps": "WEAPON_DPS", "PseudoStatRangedDps": "RANGED_DPS"}

# Alternatives a player can pick in the Gear tab (Ret: the Holy Shock build instead of Unsealed Wrath)
ALT = {("PALADIN", "ret_holyshock"): ("paladin/retribution", "HolyShockEpWeights", "ret")}

# Presets measured on gear that already sits at the hit cap give hit only its value past the cap, close to 0. Waypath+
# stops counting hit at the cap itself, so it needs hit's value below the cap: taken from the class's preset that was
# measured below it (Arms: "Hit is its value below the 8% cap"), as hit per point of Strength, times this spec's
# Strength. Fury misses more with two weapons, so its hit is worth at least as much as Arms' per Strength.
HIT_FROM = {("WARRIOR", "fury"): ("warrior/dps", "PreBiSArmsEpWeights"),
            ("WARRIOR", "prot"): ("warrior/dps", "PreBiSArmsEpWeights")}

# Specs wowsims has no weights for, estimated from its Holy Priest single-target healing weights. Crit is worth more to
# a Holy Paladin (Illumination refunds the spell's mana on a crit); Spirit regenerates less for a paladin or a shaman.
ESTIMATE = {("PALADIN", "holy"): {"CRIT": 1.5, "SPI": 0.3}, ("DRUID", "resto"): {}, ("SHAMAN", "resto"): {"SPI": 0.5}}
EST_FROM = ("priest/healer", "HolySingleTargetEpWeights")

def value(expr):
    expr = re.sub(r'Mechanics\.(\w+)', lambda m: repr(CONST[m.group(1)]), expr.strip())
    if not re.fullmatch(r'[\d.\s*/+()-]+', expr): raise ValueError(expr)
    return float(eval(expr, {"__builtins__": {}}))

def block(src, start):
    """the text of the {...} that starts at src[start]"""
    depth, i = 0, start
    while True:
        c = src[i]
        if c == "{": depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0: return src[start + 1:i], i + 1
        i += 1

def from_map(src, at):
    """parse Stats.fromMap({stats}, {pseudo}) at src[at:]"""
    i = src.index("{", at)
    stats, j = block(src, i)
    out = {}
    for k, v in re.findall(r'\[(?:Stat|PseudoStat)\.(\w+)\]:\s*([^,\n]+)', stats): out[k] = value(v)
    rest = src[j:j + 40]
    if re.match(r'\s*,\s*\{', rest):
        pseudo, _ = block(src, src.index("{", j))
        for k, v in re.findall(r'\[(?:Stat|PseudoStat)\.(\w+)\]:\s*([^,\n]+)', pseudo): out[k] = value(v)
    return out

def preset(spec_dir, name):
    src = open(os.path.join(SRC, "ui/specs", spec_dir, "presets.ts")).read()
    m = re.search(r'export const %s = PresetUtils\.makePresetEpWeights\(\s*\'([^\']+)\',\s*' % re.escape(name), src)
    if not m: raise SystemExit("no preset %s in %s" % (name, spec_dir))
    label, at = m.group(1), m.end()
    if src[at:].startswith("Stats.fromMap"): return label, from_map(src, at)
    ref = re.match(r'(\w+)', src[at:]).group(1)
    # an alias (DefaultEp = CatEp), and a table imported from another file (../feral_ep)
    a = re.search(r'export const %s = (\w+);' % ref, src)
    if a: ref = a.group(1)
    r = re.search(r'const %s = Stats\.fromMap\(' % ref, src)
    if r: return label, from_map(src, r.end())
    imp = re.search(r"import \{[^}]*\b%s\b[^}]*\} from '([^']+)'" % ref, src).group(1)
    other = open(os.path.normpath(os.path.join(SRC, "ui/specs", spec_dir, imp + ".ts"))).read()
    r = re.search(r'const %s = Stats\.fromMap\(' % ref, other)
    return label, from_map(other, r.end())

def convert(raw, kind):
    w = {}
    for k, v in raw.items():
        if k not in MAP or v <= 0: continue
        key = MAP[k]
        w[key] = w.get(key, 0) + v * PER.get(k, 1)
    base = {"tank": "STA", "heal": "HEAL", "caster": "SP", "ranged": "RAP"}.get(kind, "AP")
    if base == "RAP" and not w.get("RAP"): base = "AP"
    if not w.get(base):
        base = max(w, key=lambda k: w[k] if k in ("AP", "RAP", "SP", "HEAL", "STA") else 0)
    b = w[base]
    w = {k: v / b for k, v in w.items()}
    # Haste on WoW Forever gear is rare (about 40 items, 1-2% each) and a preset's haste weight is measured at the edge
    # of one proc build (Unsealed Wrath gives 1% haste 5x the value of 1% crit): keep it at most 1.5x crit so a 1% haste
    # piece can't outrank a much bigger item on that one number
    if w.get("HASTE") and w.get("CRIT"): w["HASTE"] = min(w["HASTE"], 1.5 * w["CRIT"])
    return {k: round(v, 3) for k, v in sorted(w.items())}, base

def finish(w, kind):
    # a damage sim gives Stamina nothing: while levelling it keeps Waypath+'s own small value (and near-zero Spirit too)
    if kind not in ("tank",): w.pop("STA", None)
    if w.get("SPI", 1) < 0.05: w.pop("SPI", None)
    return w

rev = subprocess.run(["git", "-C", SRC, "log", "-1", "--format=%h %cs"], capture_output=True, text=True).stdout.strip()
out, notes = {}, {}
for (cls, key), (spec_dir, name) in sorted(PICK.items()):
    label, raw = preset(spec_dir, name)
    kind = KIND.get(key, "melee")
    w, base = convert(raw, kind)
    note = "%s / %s (%s), per %s" % (spec_dir, name, label, base)
    if (cls, key) in HIT_FROM:
        _, ref = preset(*HIT_FROM[(cls, key)])
        braw = raw.get("StatStrength", 0) / sum(v for k, v in raw.items() if MAP.get(k) == base)
        below = ref["StatHitRating"] / ref["StatStrength"] * PER["StatHitRating"] * braw
        if below > w.get("HIT", 0): w["HIT"] = round(below, 3); note += "; hit below the cap from " + HIT_FROM[(cls, key)][1]
    # a ranged hunter's haste is ranged haste ("Increases ranged attack speed by 1%" on quivers and some gear)
    if kind == "ranged" and w.get("HASTE"): w["RHASTE"] = w["HASTE"]
    out.setdefault(cls, {})[key] = finish(w, kind)
    notes["%s %s" % (cls, key)] = note
for (cls, key), (spec_dir, name, like) in sorted(ALT.items()):
    label, raw = preset(spec_dir, name)
    w, base = convert(raw, KIND.get(like, "melee"))
    out.setdefault(cls, {})[key] = finish(w, KIND.get(like, "melee"))
    notes["%s %s" % (cls, key)] = "%s / %s (%s), per %s" % (spec_dir, name, label, base)
est = {}
label, raw = preset(*EST_FROM)
for (cls, key), mult in sorted(ESTIMATE.items()):
    w, base = convert(raw, "heal")
    for k, m in mult.items():
        if k in w: w[k] = round(w[k] * m, 3)
    est.setdefault(cls, []).append(key)
    out.setdefault(cls, {})[key] = finish(w, "heal")
    notes["%s %s" % (cls, key)] = "estimated from %s / %s (%s), per %s" % (EST_FROM[0], EST_FROM[1], label, base)

# each class's levelling spec (main = true in Classes/Specs.lua): its weights are the class's own
specs_src = open(os.path.join(OUT, "Classes/Specs.lua"), encoding="utf-8").read()
main, cur = {}, None
for line in specs_src.splitlines():
    m = re.match(r'S\("(\w+)"', line)
    if m: cur = m.group(1)
    m = re.search(r'key = "(\w+)".*\bmain = true', line)
    if m and cur: main[cur] = m.group(1)
os.makedirs(os.path.join(OUT, "tools/sims"), exist_ok=True)
json.dump({"source": "wowsims/forever " + rev, "weights": out, "estimated": est, "presets": notes, "main": main}, open(os.path.join(OUT, "tools/sims/weights.json"), "w"), indent=1, sort_keys=True)
L = ["-- Waypath+ stat weights from wowsims/forever (https://github.com/wowsims/forever, MIT licence, (c) the wowsims team),",
     "-- the WoW Forever simulator's own EP presets (%s). Generated by tools/sims/wowsims.py: don't edit by hand." % rev,
     "-- Merged over the hand-made weights at load (Data.lua's RegisterClass, Classes/Specs.lua): crit and hit per 1%,",
     "-- weapon DPS per point; stats wowsims leaves out (Stamina for damage dealers, Spirit, weapon speed) keep",
     "-- Waypath+'s own levelling values. Specs wowsims has no weights for yet keep the hand-made ones.",
     "local _, RG = ...", "RG.SIM_SOURCE = %s" % json.dumps("wowsims/forever " + rev), "RG.SIM_WEIGHTS = {"]
for cls in sorted(out):
    L.append("  %s = {" % cls)
    for key in sorted(out[cls]):
        L.append("    %s = { %s },   -- %s" % ('["%s"]' % key if not key.isidentifier() else key,
            ", ".join("%s = %s" % (k, ("%.3f" % v).rstrip("0").rstrip(".")) for k, v in sorted(out[cls][key].items())), notes["%s %s" % (cls, key)]))
    L.append("  },")
L.append("}")
L.append("RG.SIM_ESTIMATED = { %s }   -- not simulated: estimated from the Holy Priest weights" % ", ".join("%s = { %s }" % (c, ", ".join("%s = true" % k for k in sorted(ks))) for c, ks in sorted(est.items())))
L.append("RG.SIM_MAIN = { %s }" % ", ".join('%s = "%s"' % (c, k) for c, k in sorted(main.items())))
open(os.path.join(OUT, "Classes/SimWeights.lua"), "w").write("\n".join(L) + "\n")
for k, v in notes.items(): print(k, "<-", v)
