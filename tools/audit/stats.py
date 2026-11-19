#!/usr/bin/env python3
"""Score audit: every weapon and armor piece in WoW Forever through Waypath+'s own stat reader and scorer.

Waypath+ reads an item's stats in the game from two places: the client's stat table (GetItemStats) and the tooltip's
"Equip:" lines (Core.lua: RG.ParseItemStats). The same stat is often in both, or only in one, and the client can word it
as a percent ("Improves your chance to hit by 1%") or as a rating. A stat read twice or missed makes a wrong upgrade
arrow, so this checks every item in each form the game could show it:

  real      the stat table as the client gives it, plus the item's own Equip: lines (the game's spell text, from the
            client's Spell table) - what the game shows today
  doubled   the same, plus every stat also written out as Classic Equip: text (as the game shows spell power)
  textonly  only the base stats in the table; everything else as Classic Equip: text
  ratings   only the base stats in the table; hit, crit, haste, dodge, parry, block, defense and expertise as ratings in text

Each answer must equal the item's true stats (LibItemDB's walk of the WoW Forever client, the same data the gear
lists use). Then RG.ScoreStats (tooltips, upgrade arrows) must give exactly the score tools/gear/gen.py's score()
gives (the gear lists), for every class's and spec's weights, every weapon model and at levels 10, 30, 47 and 60.

Usage: python3 tools/audit/stats.py <addon dir> <LibItemDB dir> <wago dir> [lua]
Exit 1 with a list when anything differs.
"""
import csv, gzip, json, os, re, subprocess, sys, tempfile
from collections import defaultdict, Counter

ROOT, IDB, WAGO = sys.argv[1], sys.argv[2], sys.argv[3]
LUA = sys.argv[4] if len(sys.argv) > 4 else os.environ.get("LUA", "lua5.1")
sys.path.insert(0, os.path.join(ROOT, "tools", "gear"))
import itemdb

items = itemdb.load(IDB)
core = os.path.join(IDB, "Forever", "_core") if os.path.isdir(os.path.join(IDB, "Forever")) else IDB
equip_rows = itemdb._rows(os.path.join(core, "EquipStats.lua"))
blobs = {}
for fname in ("Armor.lua", "Weapon.lua"):
    for iid, packed in itemdb._rows(os.path.join(core, fname)).items():
        p = packed.split("\x1f")
        blobs[iid] = p[4] if len(p) > 4 else ""

def kv(blob):
    out = {}
    for part in (blob or "").split(","):
        if "=" in part:
            k, v = part.split("=", 1)
            try: out[k] = float(v)
            except ValueError: pass
    return out

# ---------------------------------------------------------------------------
# the game's own Equip: text for each item (client tables: ItemXItemEffect -> ItemEffect -> Spell, SpellEffect)
def table(name):
    return csv.DictReader(gzip.open(os.path.join(WAGO, name + ".csv.gz"), "rt", encoding="utf-8"))
effect = {d["ID"]: d for d in table("ItemEffect")}
desc = {int(d["ID"]): d["Description_lang"] for d in table("Spell")}
points = defaultdict(dict)
for d in table("SpellEffect"):
    try: points[int(d["SpellID"])][int(d["EffectIndex"])] = float(d["EffectBasePointsF"])
    except ValueError: pass
equip_spells = defaultdict(list)
for d in table("ItemXItemEffect"):
    e = effect.get(d["ItemEffectID"])
    if e and e["TriggerType"] == "1": equip_spells[int(d["ItemID"])].append(int(e["SpellID"]))

def render(spell):
    """the spell's text as the tooltip shows it, or None when it uses tokens this can't fill in"""
    text = desc.get(spell)
    if not text: return None
    pts = points.get(spell, {})
    def sv(m):
        i = int(m.group(2) or 1) - 1
        sid = int(m.group(1)) if m.group(1) else spell
        v = points.get(sid, {}).get(i)
        return None if v is None else abs(v)
    def num(v, dec=None):
        if dec is not None: return ("%%.%df" % dec) % v
        return str(int(v)) if float(v).is_integer() else ("%g" % v)
    # ${expression}.N  (an expression of $sN with one decimal place, say)
    def expr(m):
        inner = re.sub(r'\$(\d+)?[sSmM](\d)', lambda x: repr(sv(x)), m.group(1))
        if "None" in inner or not re.fullmatch(r'[\d.\s*/+()-]+', inner): return m.group(0)
        v = eval(inner, {"__builtins__": {}})
        return num(v, int(m.group(2)) if m.group(2) else None)
    text = re.sub(r'\$\{([^}]*)\}(?:\.(\d))?', expr, text)
    # $/10;s1  (a value divided)
    text = re.sub(r'\$/(\d+);(\d+)?[sSmM](\d)', lambda m: num(sv(re.match(r'(\d+)?\w(\d)', (m.group(2) or '') + 's' + m.group(3))) / float(m.group(1))), text)
    text = re.sub(r'\$(\d+)?[sSmM](\d)', lambda m: num(sv(m)) if sv(m) is not None else m.group(0), text)
    text = re.sub(r'\$l([^:;]*):([^;]*);', lambda m: m.group(2), text)
    if "$" in text: return None
    return re.sub(r"\s+", " ", text).strip()

# ---------------------------------------------------------------------------
# what the client's stat table (GetItemStats) gives: the ITEM_MOD_ keys as they are, and the ratings LibItemDB turned
# into percents (its README: Forever stores hit, crit, haste, dodge, parry and block as ratings) back as ratings
RATING = {"CRIT_PCT": ("ITEM_MOD_CRIT_RATING_SHORT", 14), "HIT_PCT": ("ITEM_MOD_HIT_RATING_SHORT", 10),
          "MELEE_HASTE_PCT": ("ITEM_MOD_HASTE_RATING_SHORT", 10), "RANGED_HASTE_PCT": ("ITEM_MOD_HASTE_RANGED_RATING_SHORT", 10),
          "DODGE_PCT": ("ITEM_MOD_DODGE_RATING_SHORT", 12), "PARRY_PCT": ("ITEM_MOD_PARRY_RATING_SHORT", 15),
          "BLOCK_PCT": ("ITEM_MOD_BLOCK_RATING_SHORT", 5), "DEFENSE": ("ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", 1),
          "EXPERTISE": ("ITEM_MOD_EXPERTISE_RATING_SHORT", 1), "BLOCK_VALUE": ("ITEM_MOD_BLOCK_VALUE_SHORT", 1),
          "FERAL_ATTACK_POWER": ("ITEM_MOD_FERAL_ATTACK_POWER_SHORT", 1)}
BASE = {"ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_INTELLECT_SHORT",
        "ITEM_MOD_SPIRIT_SHORT", "RESISTANCE0_NAME", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"}

def raw_table(blob, base_only=False):
    out = {}
    for k, v in kv(blob).items():
        if k in ("SPELL_CRIT_PCT", "SPELL_HIT_PCT"): continue      # (the same stat as CRIT_PCT and HIT_PCT)
        if k.startswith("ITEM_MOD_") or k == "RESISTANCE0_NAME":
            if base_only and k not in BASE and v > 0: continue
            out[k] = v
        elif k in RATING and (not base_only or v < 0):
            name, div = RATING[k]
            out[name] = out.get(name, 0) + v * div
    return out

def pct(v): return ("%g" % v)
def classic_text(st, sp):
    """every stat beyond the base ones as Classic Equip: text; sp: the item's spell power, damage and healing stats"""
    L = []
    if st.get("CRIT"): L.append("Equip: Improves your chance to get a critical strike by %s%%." % pct(st["CRIT"]))
    if st.get("HIT"): L.append("Equip: Improves your chance to hit by %s%%." % pct(st["HIT"]))
    power, dmg, heal = sp
    if power: L.append("Equip: Increases damage and healing done by magical spells and effects by up to %d." % power)
    if dmg: L.append("Equip: Increases damage done by magical spells and effects by up to %d." % dmg)
    if heal: L.append("Equip: Increases healing done by spells and effects by up to %d." % heal)
    if st.get("AP"): L.append("Equip: +%d Attack Power." % st["AP"])
    if st.get("RAP"): L.append("Equip: +%d ranged Attack Power." % st["RAP"])
    if st.get("FAP"): L.append("Equip: +%d Attack Power in Cat, Bear, and Dire Bear forms only." % st["FAP"])
    if st.get("MP5"): L.append("Equip: Restores %d mana per 5 sec." % st["MP5"])
    if st.get("DEF"): L.append("Equip: Increased Defense +%d." % st["DEF"])
    if st.get("DODGE"): L.append("Equip: Increases your chance to dodge an attack by %s%%." % pct(st["DODGE"]))
    if st.get("PARRY"): L.append("Equip: Increases your chance to parry an attack by %s%%." % pct(st["PARRY"]))
    if st.get("BLOCK"): L.append("Equip: Increases your chance to block attacks with a shield by %s%%." % pct(st["BLOCK"]))
    if st.get("BLOCKVAL"): L.append("Equip: Increases the block value of your shield by %d." % st["BLOCKVAL"])
    if st.get("HASTE"): L.append("Equip: Increases your attack speed by %s%%." % pct(st["HASTE"]))
    if st.get("RHASTE"): L.append("Equip: Increases your ranged attack speed by %s%%." % pct(st["RHASTE"]))
    if st.get("EXPERTISE"): L.append("Equip: Increases your expertise by %s%%." % pct(st["EXPERTISE"] / 10))
    return L
def rating_text(st, spell_power_both):
    """hit, crit, haste, dodge, parry, block, defense and expertise in the later "rating" wording; the rest Classic"""
    L = [l for l in classic_text(st, spell_power_both) if not re.search(r"critical strike|chance to hit|dodge|parry|chance to block|attack speed|expertise|Defense", l)]
    for k, name, div in (("CRIT", "critical strike rating", 14), ("HIT", "hit rating", 10), ("HASTE", "haste rating", 10),
                         ("DODGE", "dodge rating", 12), ("PARRY", "parry rating", 15), ("BLOCK", "block rating", 5),
                         ("DEF", "defense rating", 1), ("EXPERTISE", "expertise rating", 0.1)):
        v = st.get(k)
        if v: L.append("Equip: Increases your %s by %d." % (name, round(v * div if k != "EXPERTISE" else v)))
    return L

KEYS = ["STR", "AGI", "STA", "INT", "SPI", "ARMOR", "AP", "RAP", "FAP", "SP", "HEAL", "MP5", "CRIT", "HIT", "HASTE", "RHASTE",
        "EXPERTISE", "DEF", "DODGE", "PARRY", "BLOCK", "BLOCKVAL"]

cases, truth = [], {}
SEP1, SEP2, SEP3 = "\x01", "\x02", "\x03"
def enc(d): return SEP2.join("%s%s%r" % (k, SEP3, v) for k, v in sorted(d.items()))
n_real_lines = 0
for iid, it in sorted(items.items()):
    st = {k: v for k, v in it["stats"].items() if k in KEYS and v}
    if not st: continue
    b = blobs.get(iid, "")
    if re.search(r"\btest\b", it["name"], re.I): continue        # the developers' test items
    bk = kv(b)
    both = (bk.get("ITEM_MOD_SPELL_POWER", 0) + bk.get("ITEM_MOD_SPELL_POWER_SHORT", 0),
            bk.get("ITEM_MOD_SPELL_DAMAGE_DONE", 0), bk.get("ITEM_MOD_SPELL_HEALING_DONE", 0))
    truth[iid] = st
    real = [t for t in (render(sp) for sp in equip_spells.get(iid, [])) if t]
    real = ["Equip: " + t for t in real]
    n_real_lines += len(real)
    # the stats the client's stat table has (written out again as text in "doubled", the way the game shows spell
    # power), and the ones only an Equip: spell gives (LibItemDB's EquipStats): when the client's spell text for them
    # isn't in the tables above (an original Classic item), they are written out as the Classic text the game shows
    blob_st = {}
    for k, v in bk.items():
        key = itemdb.STAT.get(k)
        if key in KEYS and v > 0: blob_st[key] = max(blob_st.get(key, 0), v)
    eq = {}
    itemdb._stats(str(equip_rows.get(iid, "")), eq)
    eq_only = {k: v for k, v in eq.items() if k in KEYS and v > 0 and not blob_st.get(k)}
    if not real and eq_only: real = classic_text(eq_only, (0, 0, 0))
    sp_blob = both if any(both) else (0, 0, 0)
    forms = {
        "real": (raw_table(b), real),
        "doubled": (raw_table(b), real + classic_text(blob_st, sp_blob)),
        "textonly": (raw_table(b, True), real + classic_text(blob_st, sp_blob)),
        "ratings": (raw_table(b, True), real + rating_text(blob_st, sp_blob)),
    }
    for form, (raw, lines) in forms.items():
        raw = {("ITEM_MOD_SPELL_POWER_SHORT" if k == "ITEM_MOD_SPELL_POWER" else k): v for k, v in raw.items()}
        cases.append(SEP1.join(["P", str(iid), form, enc(raw), SEP2.join(lines)]))

# ---------------------------------------------------------------------------
# scores: RG.ScoreStats against gen.py's score() for every class's and spec's weights
gen_src = open(os.path.join(ROOT, "tools", "gear", "gen.py")).read()
ns = {"defaultdict": defaultdict}
exec(gen_src[gen_src.index("MULT_2H = {"):gen_src.index("ARMOR_INV = {")], ns)   # level_factor, score
exec("def stats_of(d): return defaultdict(float, d['_idb']['stats'])\n"
     "def weapon(d):\n    it = d['_idb']\n    return it['dps'], it['speed']\n", ns)
specs = json.load(open(os.path.join(ROOT, "tools", "sims", "weights.json")))
weights = []
for cls, ks in specs["weights"].items():
    for key, w in ks.items(): weights.append(("%s.%s" % (cls, key), w))
# plus the hand-made weights of every class (Classes/<Class>.lua), as the gear lists read them
exec(gen_src[gen_src.index("def lua_table"):gen_src.index("STAT = {")], ns)
for f in sorted(os.listdir(os.path.join(ROOT, "Classes"))):
    if re.fullmatch(r"[A-Z][a-z]+\.lua", f) and f not in ("Specs.lua", "SimWeights.lua"):
        try: C = ns["read_class"](os.path.join(ROOT, "Classes", f))
        except Exception: continue
        weights.append(("%s.class" % C["tok"], C["w"]))
SLOT_OF = {1: "Head", 2: "Neck", 3: "Shoulder", 5: "Chest", 20: "Chest", 6: "Waist", 7: "Legs", 8: "Feet", 9: "Wrist",
           10: "Hands", 11: "Ring", 12: "Trinket", 16: "Back", 13: "Main Hand", 21: "Main Hand", 22: "Off Hand",
           17: "2H", 15: "Ranged", 26: "Ranged", 25: "Ranged", 14: "Shield", 23: "Held", 28: "Relic"}
LOC_OF = {13: "INVTYPE_WEAPON", 21: "INVTYPE_WEAPONMAINHAND", 22: "INVTYPE_WEAPONOFFHAND", 17: "INVTYPE_2HWEAPON",
          15: "INVTYPE_RANGED", 26: "INVTYPE_RANGEDRIGHT", 25: "INVTYPE_THROWN", 28: "INVTYPE_RELIC", 14: "INVTYPE_SHIELD"}
score_expect = {}
sample = [iid for iid in sorted(truth) if items[iid]["inv"] in SLOT_OF]
for wkey, w in weights:
    for model in ("2H", "DW", "ranged", "caster", "feral", "tank"):
        C = {"w": {k: float(v) for k, v in w.items()}, "model": model, "tok": wkey.split(".")[0]}
        for iid in sample[::3]:                                   # a third of all items for each, every item somewhere
            it = items[iid]
            slot = SLOT_OF[it["inv"]]
            loc = LOC_OF.get(it["inv"], "INVTYPE_HEAD")
            lslot = 17 if slot == "Off Hand" else 16
            d = {"_idb": it, "ItemLevel": it["ilvl"]}
            for lvl in (10, 30, 47, 60):
                v, _, _ = ns["score"](d, slot, C, lvl)
                key = "%s:%s:%d:%d" % (wkey, model, iid, lvl)
                score_expect[key] = v
                stats = dict(st for st in it["stats"].items() if st[1])
                stats["DPS"] = it["dps"] or 0; stats["SPEED"] = it["speed"] or 0
                cases.append(SEP1.join(["S", key, loc, str(lslot), model, repr(ns["level_factor"](lvl)), str(it["ilvl"]),
                                        enc(C["w"]), enc(stats), C["tok"]]))

tmp = tempfile.NamedTemporaryFile("w", delete=False, suffix=".txt", encoding="utf-8")
tmp.write("\n".join(cases) + "\n"); tmp.close()
out = subprocess.run([LUA, os.path.join(ROOT, "tools", "audit", "stats_check.lua"), ROOT, tmp.name], capture_output=True, text=True)
os.unlink(tmp.name)
if out.returncode != 0 or not out.stdout:
    print(out.stderr); raise SystemExit("stats_check.lua failed")

# Known and accepted: forms the game doesn't use for that item, where no reading can be right.
#   Icicle Rod: 18 spell power (damage and healing) plus 10 spell damage. Written only as text, the two lines can't be
#   told from one stat shown twice (the game does show spell power twice: Witherseed Gloves), and counting it once is
#   the safe side. The game gives both in its stat table, where they add up (the "real" form checks that).
ACCEPT = {("textonly", 2950), ("ratings", 2950)}
bad = defaultdict(list)
checked = Counter()
for line in out.stdout.splitlines():
    parts = line.split(" ", 3)
    if parts[0] == "P":
        iid, form = int(parts[1]), parts[2]
        got = {k: float(v) for k, v in (x.split("=") for x in (parts[3].split(",") if len(parts) > 3 and parts[3] else []))}
        want = truth[iid]
        checked[form] += 1
        diffs = []
        for k in KEYS:
            g, w_ = got.get(k, 0.0), want.get(k, 0.0)
            if abs(g - w_) > 0.011 * max(1, abs(w_)): diffs.append("%s %g (should be %g)" % (k, g, w_))
        if diffs and (form, iid) not in ACCEPT: bad[form].append("%d %s: %s" % (iid, items[iid]["name"], "; ".join(diffs)))
    elif parts[0] == "S":
        key, v = parts[1], float(parts[2])
        checked["score"] += 1
        e = score_expect[key]
        if abs(v - e) > 0.01 + 1e-6 * abs(e): bad["score"].append("%s: tooltip %.2f, gear list %.2f" % (key, v, e))

print("items with stats: %d, Equip: lines from the game's spell text: %d" % (len(truth), n_real_lines))
for form in ("real", "doubled", "textonly", "ratings", "score"):
    print("%-9s %7d checked, %d wrong" % (form, checked[form], len(bad[form])))
    for b in bad[form][:25]: print("   ", b)
    if len(bad[form]) > 25: print("    ... and %d more" % (len(bad[form]) - 25))
if any(bad.values()): sys.exit(1)
print("Score audit: every item reads right in every form, and tooltips score exactly as the gear lists do.")
