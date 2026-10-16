-- Waypath+ profession data: Blacksmithing. Weapon stones, the 1-300 leveling
-- plan, and bars whose Auction House prices are tracked.
local _, RG = ...
local B = { name = "Blacksmithing", kind = "craft", icon = "Interface\\Icons\\Trade_BlackSmithing" }
B.source = "wow-professions.com WoW Forever guide (Classic route past 225)"

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

-- Blacksmithing 1-300, Horde. 1-225: wow-professions.com WoW Forever guide (beta data);
-- 225-300: the Classic route (not yet tested on Forever).
B.plan = {
  { from = 1,   to = 25,  craft = "Rough Sharpening Stone", n = 30, mats = "1 Rough Stone each. Buy a Blacksmith Hammer when you learn the profession." },
  { from = 25,  to = 50,  craft = "Rough Grinding Stone", n = 30, mats = "2 Rough Stone each. Keep 26 (16 for gauntlets, 10 for Silver Rods)." },
  { from = 50,  to = 67,  craft = "Coarse Grinding Stone", n = 36, mats = "2 Coarse Stone each. Keep all 36 (10 at 95, 26 at 112)." },
  { from = 50,  to = 50,  train = "Journeyman (skill 50, level 10)" },
  { from = 67,  to = 75,  craft = "Runed Copper Gauntlets", n = 8, mats = "8 Copper Bar, 2 Rough Grinding Stone each" },
  { from = 75,  to = 80,  craft = "Runed Copper Belt", n = 5, mats = "10 Copper Bar each (or Silver Rods: 1 Silver Bar, 2 Rough Grinding Stone)" },
  { from = 80,  to = 95,  craft = "Rough Bronze Leggings", n = 15, mats = "6 Bronze Bar each" },
  { from = 95,  to = 100, craft = "Patterned Bronze Bracers", n = 5, mats = "5 Bronze Bar, 2 Coarse Grinding Stone each" },
  { from = 100, to = 112, craft = "Heavy Grinding Stone", n = 20, mats = "3 Heavy Stone each. Keep them." },
  { from = 112, to = 125, craft = "Patterned Bronze Bracers", n = 13, mats = "5 Bronze Bar, 2 Coarse Grinding Stone each" },
  { from = 125, to = 125, train = "Expert (skill 125, level 20, 50 silver)" },
  { from = 125, to = 140, craft = "Bronze Shortsword", n = 24, mats = "5 Bronze Bar, 4 Weak Flux, 2 Medium Leather each" },
  { from = 140, to = 165, craft = "Bronze Warhammer", n = 29, mats = "8 Bronze Bar, 1 Strong Flux, 1 Medium Leather each" },
  { from = 165, to = 175, craft = "Green Iron Bracers", n = 15, mats = "6 Iron Bar, 1 Green Dye each" },
  { from = 175, to = 185, craft = "Solid Grinding Stone", n = 40, mats = "4 Solid Stone each. Keep 21 for the helms." },
  { from = 185, to = 215, craft = "Mithril Plate Pants", n = 36, mats = "12 Mithril Bar each" },
  { from = 200, to = 200, train = "Artisan (skill 200, level 35)" },
  { from = 215, to = 225, craft = "Steel Plate Helm", n = 21, mats = "14 Steel Bar, 1 Solid Grinding Stone each" },
  { from = 225, to = 235, craft = "Steel Plate Helm", n = 10, mats = "14 Steel Bar, 1 Solid Grinding Stone each (Classic route from here)" },
  { from = 235, to = 250, craft = "Mithril Coif", n = 15, mats = "10 Mithril Bar, 6 Mageweave Cloth each (or Mithril Spurs if you have the plans)" },
  { from = 250, to = 260, craft = "Dense Sharpening Stone", n = 20, mats = "1 Dense Stone each" },
  { from = 260, to = 265, craft = "Heavy Mithril Boots", n = 8, mats = "14 Mithril Bar, 4 Thick Leather each" },
  { from = 265, to = 270, craft = "Imperial Plate Belt", n = 5, mats = "22 Thorium Bar, 6 Rugged Leather, 1 Aquamarine each (plans: Derotain Mudsipper, Tanaris, level 50 quest)" },
  { from = 270, to = 295, craft = "Imperial Plate Bracers", n = 25, mats = "20 Thorium Bar, 1 Star Ruby each (Derotain Mudsipper)" },
  { from = 295, to = 300, craft = "Imperial Plate Boots", n = 5, mats = "34 Thorium Bar, 1 Star Ruby, 1 Aquamarine each (Derotain Mudsipper)" },
}
B.train = {
  start = { O = "Dwukk at the Razor Hill forge", R = "Dwukk at the Razor Hill forge", T = "Thrag Stonehoof, lower rise of Thunder Bluff", U = "Angus Hammerhand at Bandarion Keep, Tirisfal", S = "a Zephras Isle trainer, or any capital" },
  apprentice = "Ug'thok (Orgrimmar), Basil Frye (Undercity), Thrag Stonehoof (Thunder Bluff)",
  journeyman = "Snarl (Orgrimmar), James Van Brunt (Undercity), Karn Stonehoof (Thunder Bluff)",
  expert = "Saru Steelfury (Orgrimmar)",
  artisan = "Brikk Keencraft (Booty Bay, Stranglethorn Vale)",
}

-- Alliance: the same trainers, in Stormwind, Ironforge, Darnassus and the starting zones (Profile.lua uses this one for Alliance characters).
B.trainA = {
  start = { H = "Smith Argus in Goldshire", D = "Tognus Flintfire in Kharanos", G = "Tognus Flintfire in Kharanos", N = "Dane Lindgren in Stormwind", A = "Dane Lindgren in Stormwind" },
  apprentice = "Smith Argus (Goldshire), Dane Lindgren (Stormwind), Groum Stonebeard (Ironforge), Tognus Flintfire (Dun Morogh)",
  journeyman = "Dane Lindgren (Stormwind), Groum Stonebeard (Ironforge)",
  expert = "Therum Deepforge (Stormwind), Rotgath Stonebeard (Ironforge)",
  artisan = "Bengus Deepforge (Ironforge)",
}
B.supplies = "Blacksmith Hammer, Weak and Strong Flux: the Blacksmithing Supply vendor next to each capital trainer. Green Dye: Tamar (Orgrimmar), Millie Gregorian (Undercity), Mahu (Thunder Bluff)."

-- Bars whose Auction House prices are tracked (ore and basic bars come from Mining).
B.mats = {
  2841, 3859, 6037, 12360, -- Bronze, Steel, Truesilver, Arcanite bars
}

RG.RegisterProfession("Blacksmithing", B)
