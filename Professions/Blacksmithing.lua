-- Waypath+ profession data: Blacksmithing. Weapon stones, the 1-300 leveling
-- plan, and bars whose Auction House prices are tracked.
local _, RG = ...
local B = { name = "Blacksmithing" }

-- Weapon stones (Blacksmithing). Sharpening stones are for swords and axes,
-- weightstones for maces. bs = Blacksmithing skill where you start making them.
-- Item IDs and level requirements checked on Wowhead.
B.stones = {
  sharp = {
    { id = 2862,  name = "Rough Sharpening Stone",  lvl = 1,  bs = 1,   dmg = 2 },
    { id = 2863,  name = "Coarse Sharpening Stone", lvl = 5,  bs = 65,  dmg = 3 },
    { id = 2871,  name = "Heavy Sharpening Stone",  lvl = 15, bs = 125, dmg = 4 },
    { id = 7964,  name = "Solid Sharpening Stone",  lvl = 25, bs = 200, dmg = 6 },
    { id = 12404, name = "Dense Sharpening Stone",  lvl = 35, bs = 250, dmg = 8 },
  },
  blunt = {
    { id = 3239,  name = "Rough Weightstone",  lvl = 1,  bs = 1,   dmg = 2 },
    { id = 3240,  name = "Coarse Weightstone", lvl = 5,  bs = 65,  dmg = 3 },
    { id = 3241,  name = "Heavy Weightstone",  lvl = 15, bs = 125, dmg = 4 },
    { id = 7965,  name = "Solid Weightstone",  lvl = 25, bs = 200, dmg = 6 },
    { id = 12643, name = "Dense Weightstone",  lvl = 35, bs = 250, dmg = 8 },
  },
}

-- Blacksmithing 1-300, Horde. Source: wow-professions.com Classic guide.
B.plan = {
  { from = 1,   to = 30,  craft = "Rough Sharpening Stone", n = 40, mats = "1 Rough Stone each" },
  { from = 30,  to = 65,  craft = "Rough Grinding Stone", n = 55, mats = "2 Rough Stone each. Keep 10." },
  { from = 65,  to = 75,  craft = "Coarse Sharpening Stone", n = 25, mats = "1 Coarse Stone each" },
  { from = 75,  to = 75,  train = "Journeyman: James Van Brunt in Undercity (needs level 10)" },
  { from = 75,  to = 90,  craft = "Coarse Grinding Stone", n = 35, mats = "2 Coarse Stone each. Keep them." },
  { from = 90,  to = 110, craft = "Runed Copper Belt", n = 15, mats = "10 Copper Bar each" },
  { from = 110, to = 125, craft = "Rough Bronze Leggings", n = 15, mats = "6 Bronze Bar each" },
  { from = 125, to = 125, train = "Expert: Saru Steelfury in Orgrimmar (needs level 20)" },
  { from = 125, to = 140, craft = "Heavy Grinding Stone", n = 35, mats = "3 Heavy Stone each. Keep them." },
  { from = 140, to = 150, craft = "Patterned Bronze Bracers", n = 10, mats = "5 Bronze Bar, 2 Coarse Grinding Stone" },
  { from = 150, to = 155, craft = "Golden Rod", n = 5, mats = "1 Gold Bar, 2 Coarse Grinding Stone" },
  { from = 155, to = 165, craft = "Green Iron Leggings", n = 10, mats = "8 Iron Bar, 1 Heavy Grinding Stone, 1 Green Dye" },
  { from = 165, to = 190, craft = "Green Iron Bracers", n = 25, mats = "6 Iron Bar, 1 Green Dye (dye from tailoring or leatherworking vendors)" },
  { from = 190, to = 200, craft = "Golden Scale Bracers", n = 10, mats = "5 Steel Bar, 2 Heavy Grinding Stone" },
  { from = 200, to = 210, craft = "Solid Grinding Stone", n = 30, mats = "4 Solid Stone each. Keep 10." },
  { from = 210, to = 225, craft = "Heavy Mithril Gauntlet", n = 15, mats = "6 Mithril Bar, 4 Mageweave Cloth" },
  { from = 225, to = 225, train = "Artisan: Brikk Keencraft in Booty Bay (needs level 35)" },
  { from = 225, to = 235, craft = "Steel Plate Helm", n = 10, mats = "14 Steel Bar, 1 Solid Grinding Stone" },
  { from = 235, to = 250, craft = "Mithril Coif", n = 15, mats = "10 Mithril Bar, 6 Mageweave Cloth (or Mithril Spurs if you have the plans)" },
  { from = 250, to = 260, craft = "Dense Sharpening Stone", n = 20, mats = "1 Dense Stone each" },
  { from = 260, to = 265, craft = "Heavy Mithril Boots", n = 8, mats = "14 Mithril Bar, 4 Thick Leather" },
  { from = 265, to = 270, craft = "Imperial Plate Belt", n = 5, mats = "22 Thorium Bar, 6 Rugged Leather, 1 Aquamarine (plans: Derotain Mudsipper, Tanaris)" },
  { from = 270, to = 295, craft = "Imperial Plate Bracers", n = 25, mats = "20 Thorium Bar, 1 Star Ruby (plans: Derotain Mudsipper, Tanaris)" },
  { from = 295, to = 300, craft = "Imperial Plate Boots", n = 5, mats = "34 Thorium Bar, 1 Star Ruby, 1 Aquamarine" },
}

-- Bars whose Auction House prices are tracked (ore and basic bars come from Mining).
B.mats = {
  2841, 3859, 6037, 12360, -- Bronze, Steel, Truesilver, Arcanite bars
}

RG.RegisterProfession("Blacksmithing", B)
