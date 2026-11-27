"""The game's model tables, for the harness (tools/harness/.cache/models.lua) and the renderer (models.json).

From the data/wago branch (the client's own DB2 tables, the same build as the install):
  display  CreatureDisplayInfo.ID -> { model FileDataID, creature model scale, texture variations, extra display id }
  creature Creature.ID -> its first display id (and the creatures the game told the add-on about: learned_creatures)
  extra    CreatureDisplayInfoExtra.ID -> { race, sex, baked texture material id, geo, tex } (geo and tex: hair,
           face and the rest, see customizations())

    python3 tools/render/modeldata.py
"""
import csv, gzip, io, json, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "..", "harness", ".cache")


def table(name):
    raw = subprocess.run(["git", "show", "origin/data/wago:%s.csv.gz" % name], capture_output=True, check=True).stdout
    return list(csv.DictReader(io.StringIO(gzip.decompress(raw).decode("utf-8"))))


def build():
    raw = subprocess.run(["git", "show", "origin/data/wago:BUILD.txt"], capture_output=True, check=True).stdout.decode()
    return dict(l.split("=", 1) for l in raw.split() if "=" in l)["build"]


def wago_table(name):
    """A table that isn't on the data branch: wago.tools' CSV for the same build, cached."""
    import urllib.request
    b = build()
    p = os.path.join(CACHE, "wago", "%s-%s.csv" % (name, b))
    if not os.path.exists(p):
        os.makedirs(os.path.dirname(p), exist_ok=True)
        req = urllib.request.Request("https://wago.tools/db2/%s/csv?build=%s" % (name, b), headers={"User-Agent": "Mozilla/5.0"})
        data = urllib.request.urlopen(req, timeout=120).read()
        open(p, "wb").write(data)
    return list(csv.DictReader(open(p, encoding="utf-8")))


def num(v, f=int):
    try:
        return f(v)
    except (TypeError, ValueError):
        return 0


def customizations(extra, texfile):
    """What a humanoid NPC looks like besides its baked skin, added to each extra display (in place):
      geo  {geoset group: id}: the parts its choices pick (hair style 0/6 -> geoset 6, beard 1/5 -> 105; id 0 hides the
           group). Groups not named show their default (xx01).
      tex  {texture type: [[file, blend], ...]}: the layers of every texture slot other than the baked skin (type 6
           hair, 19 eyes, ...), bottom first, as the race's texture layout stacks them.
    From the client's customization tables (CreatureDisplayInfoOption -> ChrCustomizationChoice -> Element ->
    Geoset / Material, and ChrModelTextureLayer for the slots), fetched from wago.tools for the same build.
    A material that belongs to another choice (a hair style's texture for each hair color) is used only when that
    other choice is picked too."""
    chosen = {}
    for r in wago_table("CreatureDisplayInfoOption"):
        chosen.setdefault(num(r["CreatureDisplayInfoExtraID"]), set()).add(num(r["ChrCustomizationChoiceID"]))
    elements = {}
    for r in wago_table("ChrCustomizationElement"):
        elements.setdefault(num(r["ChrCustomizationChoiceID"]), []).append(r)
    geoset = {num(r["ID"]): (num(r["GeosetType"]), num(r["GeosetID"])) for r in wago_table("ChrCustomizationGeoset")}
    material = {num(r["ID"]): (num(r["ChrModelTextureTargetID"]), num(r["MaterialResourcesID"])) for r in wago_table("ChrCustomizationMaterial")}
    chrmodel = {(num(r["ChrRacesID"]), num(r["Sex"])): num(r["ChrModelID"]) for r in wago_table("ChrRaceXChrModel")}
    layout = {num(r["ID"]): num(r["CharComponentTextureLayoutID"]) for r in wago_table("ChrModel")}
    layers = {}
    for r in wago_table("ChrModelTextureLayer"):
        ty = num(r["TextureType"])
        if ty == 1:
            continue    # (the skin: baked into one texture for an NPC)
        for k in ("ChrModelTextureTargetID_0", "ChrModelTextureTargetID_1"):
            if num(r[k]):
                layers.setdefault(num(r["CharComponentTextureLayoutsID"]), []).append((ty, num(r["Layer"]), num(r["BlendMode"]), num(r[k])))
    n = 0
    for eid, ex in extra.items():
        picks = chosen.get(eid)
        if not picks:
            continue
        geo, targets = {}, {}
        for c in sorted(picks):
            for e in elements.get(c, []):
                rel = num(e["RelatedChrCustomizationChoiceID"])
                if rel and rel not in picks:
                    continue
                g = geoset.get(num(e["ChrCustomizationGeosetID"]))
                if g:
                    geo[g[0]] = g[1]
                mt = material.get(num(e["ChrCustomizationMaterialID"]))
                if mt and texfile.get(mt[1]):
                    targets[mt[0]] = texfile[mt[1]]
        tex = {}
        for ty, layer, blend, target in sorted(layers.get(layout.get(chrmodel.get((ex["race"], ex["sex"]))), []), key=lambda l: (l[0], l[1])):
            if target in targets:
                tex.setdefault(ty, []).append([targets[target], blend])
        ex["geo"], ex["tex"] = geo, tex
        n += 1
    return n


def learned_creatures():
    """Creature id -> display id for the creatures the client's Creature table leaves out (most of the card game's
    creature cards): what the game itself answered when the add-on asked it (Arcade.lua, RG.ArcadeResolveCreatures),
    as saved in the local install's WaypathDB.arcade.npcDisp (every account). Read here, never committed."""
    import glob, re
    from casc import DEFAULT_DIRS
    out = {}
    root = os.environ.get("WOW_DIR") or next((d for d in DEFAULT_DIRS if os.path.isdir(d)), None)
    if not root:
        return out
    for p in glob.glob(os.path.join(root, "_%s_" % (os.environ.get("WOW_PRODUCT") or "forever"), "WTF", "Account", "*", "SavedVariables", "Waypath.lua")):
        s = open(p, encoding="utf-8", errors="replace").read()
        i = s.find('["npcDisp"] = {')
        if i < 0:
            continue
        block = s[i:s.find("\n}", i)]
        for k, v in re.findall(r"\[(\d+)\]\s*=\s*(-?\d+)", block):
            if int(v) > 0:
                out[int(k)] = int(v)
    return out


# NPCModelItemSlotDisplayInfo.ItemSlot
HEAD, SHOULDER, SHIRT, CHEST, BELT, LEGS, BOOTS, WRIST, HANDS, TABARD, BACK = range(11)
# which geoset groups an item's GeosetGroup_0.. set (to xx01 + value), per slot (as WoW Model Viewer does it,
# WoWItem::load). Chest group 13 is the robe: a robe hides the legs' trousers (13) and the boots (5).
ITEM_GROUPS = {
    SHIRT: (8, 10, 13, 22, 28), CHEST: (8, 10, 13, 22, 28), BELT: (18,), LEGS: (11, 9, 13), BOOTS: (5,),
    HANDS: (4, 23), TABARD: (12,), BACK: (15,), HEAD: (27, 21), SHOULDER: (26,),
}


def equipment(extra):
    """What a humanoid NPC wears, added to each extra display as "items" (in place):
      geo   {group: id}: the parts its armor switches on (sleeves, robe, boots, gloves, cape...)
      hide  [group]: what its helmet hides (0: the hair, 1-3: the beard, 7: the ears...)
      att   [[attachment point, model file, texture file]]: the helmet (11) and shoulders (6 left, 5 right)
      cape  the cape's texture (the character model's texture type 2)
    The armor's own textures are already in the NPC's baked skin. From NPCModelItemSlotDisplayInfo and
    ItemDisplayInfo (data/wago) and the model, texture and helmet tables (wago.tools)."""
    slots = {}
    for r in table("NPCModelItemSlotDisplayInfo"):
        slots.setdefault(num(r["NpcModelID"]), {})[num(r["ItemSlot"])] = num(r["ItemDisplayInfoID"])
    idi = {num(r["ID"]): r for r in table("ItemDisplayInfo")}
    comp_model = {num(r["ID"]): (num(r["RaceID"]), num(r["GenderIndex"]), num(r["PositionIndex"])) for r in wago_table("ComponentModelFileData")}
    model_files = {}
    for r in wago_table("ModelFileData"):
        if num(r["ModelResourcesID"]):
            model_files.setdefault(num(r["ModelResourcesID"]), []).append(num(r["FileDataID"]))
    comp_tex = {num(r["ID"]): (num(r["RaceID"]), num(r["GenderIndex"])) for r in wago_table("ComponentTextureFileData")}
    tex_files = {}
    for r in wago_table("TextureFileData"):
        if num(r["MaterialResourcesID"]):
            tex_files.setdefault(num(r["MaterialResourcesID"]), []).append(num(r["FileDataID"]))
    helm_hide = {}
    for r in wago_table("HelmetGeosetData"):
        helm_hide.setdefault((num(r["HelmetGeosetVisDataID"]), num(r["RaceID"])), set()).add(num(r["HideGeosetGroup"]))

    def pick(files, info, race, sex, position=None):
        """The file for this race and sex (and shoulder side): an exact race first, then any race."""
        best = None
        for f in files:
            fr, fg, *fp = info.get(f, (0, 2, -1))
            if fg not in (sex, 2, 3) or (position is not None and fp and fp[0] not in (position, -1)):
                continue
            score = 2 if fr == race else (1 if fr == 0 else -1)
            if score >= 0 and (best is None or score > best[0]):
                best = (score, f)
        return best and best[1]

    n = 0
    for eid, ex in extra.items():
        worn = slots.get(eid)
        if not worn:
            continue
        race, sex = ex["race"], ex["sex"]
        gg = {s: [num(idi[d]["GeosetGroup_%d" % i]) for i in range(6)] for s, d in worn.items() if d in idi}
        robe = gg.get(CHEST, [0] * 6)[2] > 0
        geo = {}
        for s in (SHIRT, CHEST, LEGS, BOOTS, HANDS, BELT, TABARD, BACK, HEAD, SHOULDER):
            for i, g in enumerate(ITEM_GROUPS[s]):
                v = gg.get(s, [0] * 6)[i]
                if not v or (robe and ((s == LEGS and g == 13) or (s == BOOTS and g == 5))):
                    continue
                geo[g] = max(geo.get(g, 0), 1 + v)
        if BOOTS in gg:
            geo[20] = gg[BOOTS][1] or 2     # (the feet: no toes in boots)
        if geo.get(4, 1) > 1:
            geo[8] = 0                      # (gloves over the sleeves' cuffs)
        items = {"geo": geo, "hide": [], "att": []}
        h = idi.get(worn.get(HEAD))
        if h:
            items["hide"] = sorted(helm_hide.get((num(h["HelmetGeosetVis_%d" % min(sex, 1)]), race), ()))
            f = pick(model_files.get(num(h["ModelResourcesID_0"]), []), comp_model, race, sex)
            if f:
                items["att"].append([11, f, pick(tex_files.get(num(h["ModelMaterialResourcesID_0"]), []), comp_tex, race, sex) or 0])
        sh = idi.get(worn.get(SHOULDER))
        if sh:
            for k, point in ((0, 6), (1, 5)):
                f = pick(model_files.get(num(sh["ModelResourcesID_%d" % k]), []), comp_model, race, sex, position=k)
                if f:
                    items["att"].append([point, f, pick(tex_files.get(num(sh["ModelMaterialResourcesID_%d" % k]), []), comp_tex, race, sex) or 0])
        b = idi.get(worn.get(BACK))
        if b:
            items["cape"] = pick(tex_files.get(num(b["ModelMaterialResourcesID_0"]), []), comp_tex, race, sex) or 0
        ex["items"] = items
        n += 1
    return n


def main():
    subprocess.run(["git", "fetch", "-q", "origin", "data/wago"], check=False)
    models = {}
    for r in table("CreatureModelData"):
        models[num(r["ID"])] = {
            "file": num(r["FileDataID"]), "scale": num(r["ModelScale"], float) or 1.0,
            "box": [num(r["GeoBox_%d" % i], float) for i in range(6)],
            "geoset": num(r["CreatureGeosetDataID"]),
        }
    display = {}
    for r in table("CreatureDisplayInfo"):
        md = models.get(num(r["ModelID"]))
        if not md or not md["file"]:
            continue
        display[num(r["ID"])] = {
            "model": num(r["ModelID"]), "file": md["file"], "mscale": md["scale"], "box": md["box"],
            "scale": num(r["CreatureModelScale"], float) or 1.0, "alpha": num(r["CreatureModelAlpha"]),
            "tex": [num(r["TextureVariationFileDataID_%d" % i]) for i in range(4)],
            "extra": num(r["ExtendedDisplayInfoID"]),
            "geosetData": num(r.get("CreatureGeosetDataID")) if "CreatureGeosetDataID" in r else 0,
        }
    creature = {}
    for r in table("Creature"):
        for i in range(4):
            d = num(r["DisplayID_%d" % i])
            if d:
                creature[num(r["ID"])] = d
                break
    try:
        learned = learned_creatures()
    except Exception as e:
        learned = {}
        print("(no learned creature displays: %s)" % e)
    for c, d in learned.items():
        if d in display:
            creature.setdefault(c, d)
    print("creatures: %d from the game's answers to the add-on (WaypathDB.arcade.npcDisp)" % len(learned))
    extra = {}
    for r in table("CreatureDisplayInfoExtra"):
        extra[num(r["ID"])] = {"race": num(r["DisplayRaceID"]), "sex": num(r["DisplaySexID"]),
                               "bake": num(r["BakeMaterialResourcesID"]), "hdbake": num(r["HDBakeMaterialResourcesID"])}
    os.makedirs(CACHE, exist_ok=True)
    # a humanoid NPC's skin is one baked texture: its material id -> the texture file (TextureFileData, not on the
    # data branch: fetched from wago.tools for the same build and kept in the cache)
    texfile = {}
    try:
        for r in wago_table("TextureFileData"):
            mr = num(r.get("MaterialResourcesID"))
            if mr and mr not in texfile:
                texfile[mr] = num(r.get("FileDataID"))
    except Exception as e:
        print("(no TextureFileData: humanoid NPCs are drawn without skin: %s)" % e)
    with open(os.path.join(CACHE, "texturefiles.json"), "w") as f:
        json.dump(texfile, f)
    try:
        n = customizations(extra, texfile)
        print("customizations: %d humanoid displays with hair, face and geosets" % n)
    except Exception as e:
        print("(no customization tables: humanoid NPCs are drawn without hair: %s)" % e)
    try:
        n = equipment(extra)
        print("equipment: %d humanoid displays with armor shapes, helmets and shoulders" % n)
    except Exception as e:
        print("(no item tables: humanoid NPCs are drawn without armor shapes: %s)" % e)
    with open(os.path.join(CACHE, "models.json"), "w") as f:
        json.dump({"display": display, "creature": creature, "extra": extra}, f)
    # the harness only needs display -> file and creature -> display
    with open(os.path.join(CACHE, "models.lua"), "w") as f:
        f.write("-- generated by tools/render/modeldata.py from the data/wago branch\nlocal d, c = {}, {}\n")
        for k, v in sorted(display.items()):
            f.write("d[%d]={%d}\n" % (k, v["file"]))
        for k, v in sorted(creature.items()):
            f.write("c[%d]=%d\n" % (k, v))
        f.write("return { display = d, creature = c }\n")
    print("models: %d displays, %d creatures, %d extra displays" % (len(display), len(creature), len(extra)))


if __name__ == "__main__":
    main()
