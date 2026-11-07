"""Read LibItemDB's WoW Forever item data (MIT, by Pimptasty: curseforge.com/wow/addons/libitemdb).

Its item stats come from a scan of the WoW Forever game client, so they cover WoW Forever's own
items (new zones, scaling quest rewards) that the cMaNGOS Classic database doesn't have, and they
match the live game where Forever changed an item. The .github/workflows/fetch-itemdb.yml workflow
puts the library's Forever folder on the data/itemdb branch:
  git clone --depth 1 -b data/itemdb https://github.com/nickflanders321-tech/RetGear.git /tmp/itemdb
load(dir) -> { id: {name, q, cls, sub, inv, ilvl, req, stats{...}, dps, speed, classes, races, faction} }
"""
import re, os

INV = {"INVTYPE_HEAD": 1, "INVTYPE_NECK": 2, "INVTYPE_SHOULDER": 3, "INVTYPE_BODY": 4, "INVTYPE_CHEST": 5, "INVTYPE_ROBE": 20,
       "INVTYPE_WAIST": 6, "INVTYPE_LEGS": 7, "INVTYPE_FEET": 8, "INVTYPE_WRIST": 9, "INVTYPE_HAND": 10, "INVTYPE_FINGER": 11,
       "INVTYPE_TRINKET": 12, "INVTYPE_WEAPON": 13, "INVTYPE_SHIELD": 14, "INVTYPE_RANGED": 15, "INVTYPE_CLOAK": 16,
       "INVTYPE_2HWEAPON": 17, "INVTYPE_TABARD": 19, "INVTYPE_WEAPONMAINHAND": 21, "INVTYPE_WEAPONOFFHAND": 22,
       "INVTYPE_HOLDABLE": 23, "INVTYPE_THROWN": 25, "INVTYPE_RANGEDRIGHT": 26, "INVTYPE_RELIC": 28}
# LibItemDB stat names -> Waypath+ score keys (Classes/<Class>.lua weights)
STAT = {"ITEM_MOD_STRENGTH_SHORT": "STR", "ITEM_MOD_AGILITY_SHORT": "AGI", "ITEM_MOD_STAMINA_SHORT": "STA",
        "ITEM_MOD_INTELLECT_SHORT": "INT", "ITEM_MOD_SPIRIT_SHORT": "SPI", "RESISTANCE0_NAME": "ARMOR",
        "ITEM_MOD_ATTACK_POWER_SHORT": "AP", "ITEM_MOD_MELEE_ATTACK_POWER_SHORT": "AP", "ITEM_MOD_RANGED_ATTACK_POWER_SHORT": "RAP",
        "ITEM_MOD_SPELL_DAMAGE_DONE": "SP", "ITEM_MOD_SPELL_HEALING_DONE": "HEAL",
        "ITEM_MOD_POWER_REGEN0_SHORT": "MP5", "CRIT_PCT": "CRIT", "SPELL_CRIT_PCT": "CRIT", "HIT_PCT": "HIT", "SPELL_HIT_PCT": "HIT",
        "DEFENSE": "DEF", "DODGE_PCT": "DODGE", "PARRY_PCT": "PARRY", "BLOCK_PCT": "BLOCK", "BLOCK_VALUE": "BLOCKVAL"}
# Forever counts melee and spell crit (and hit) as one stat: an item listing both gives it once
MERGED = {"CRIT", "HIT"}
ROW = re.compile(r'^\[(\d+)\]=(?:"((?:[^"\\]|\\.)*)"|(-?[\d.]+)),?\s*$')

def _unesc(s):
    return re.sub(r'\\(\d{1,3})', lambda m: chr(int(m.group(1))), s).replace('\\"', '"').replace('\\\\', '\\')

def _rows(path):
    out = {}
    if not os.path.exists(path): return out
    for line in open(path, encoding="utf-8"):
        m = ROW.match(line.strip())
        if m: out[int(m.group(1))] = _unesc(m.group(2)) if m.group(2) is not None else m.group(3)
    return out

def _stats(blob, into):
    for part in (blob or "").split(","):
        if "=" not in part: continue
        k, v = part.split("=", 1)
        try: v = float(v)
        except ValueError: continue
        if k == "ITEM_MOD_SPELL_POWER":   # damage and healing: both, as RG.Score counts it in the game
            into["SP"] = into.get("SP", 0) + v; into["HEAL"] = into.get("HEAL", 0) + v; continue
        key = STAT.get(k)
        if not key: continue
        if key in MERGED: into[key] = max(into.get(key, 0), v)
        else: into[key] = into.get(key, 0) + v

def load(d):
    core = os.path.join(d, "Forever", "_core") if os.path.isdir(os.path.join(d, "Forever")) else d
    names = _rows(os.path.join(os.path.dirname(core), "enUS", "Names.lua"))
    req = _rows(os.path.join(core, "ReqLevels.lua"))
    equip = _rows(os.path.join(core, "EquipStats.lua"))
    classes = _rows(os.path.join(core, "Classes.lua"))
    races = _rows(os.path.join(core, "Races.lua"))
    fac = _rows(os.path.join(core, "Factions.lua"))
    items = {}
    for fname, cls in (("Armor.lua", 4), ("Weapon.lua", 2)):
        for iid, packed in _rows(os.path.join(core, fname)).items():
            p = packed.split("\x1f")
            if len(p) < 4: continue
            q, sub, inv, ilvl = int(p[0] or 1), int(p[1] or -1), INV.get(p[2], 0), int(float(p[3] or 0))
            st, dps, speed = {}, 0.0, 0.0
            blob = p[4] if len(p) > 4 else ""
            for part in blob.split(","):
                if part.startswith("ITEM_MOD_DAMAGE_PER_SECOND_SHORT="): dps = float(part.split("=")[1])
            _stats(blob, st)
            e = equip.get(iid)
            if e:
                for part in str(e).split(","):
                    if part.startswith("MELEE_WEAPON_SPEED=") or part.startswith("WEAPON_SPEED="): speed = float(part.split("=")[1])
                _stats(str(e), st)
            items[iid] = {"name": names.get(iid, ""), "q": q, "cls": cls, "sub": sub, "inv": inv, "ilvl": ilvl,
                          "req": int(float(req.get(iid, 0) or 0)), "stats": st, "dps": dps, "speed": speed,
                          "classes": int(float(classes[iid])) if iid in classes else 0,
                          "races": races.get(iid), "faction": fac.get(iid)}
    return items

if __name__ == "__main__":
    import sys
    it = load(sys.argv[1])
    print(len(it), "items")
    for i in (271940, 2042, 12584):
        print(i, it.get(i))
