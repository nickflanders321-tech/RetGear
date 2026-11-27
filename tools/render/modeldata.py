"""The game's model tables, for the harness (tools/harness/.cache/models.lua) and the renderer (models.json).

From the data/wago branch (the client's own DB2 tables, the same build as the install):
  display  CreatureDisplayInfo.ID -> { model FileDataID, creature model scale, texture variations, extra display id }
  creature Creature.ID -> its first display id
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
