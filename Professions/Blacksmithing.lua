-- Waypath+ profession data: Blacksmithing. Weapon stones, the 1-300 leveling
-- plan, and bars whose Auction House prices are tracked.
local _, RG = ...
local B = { name = "Blacksmithing", kind = "craft", icon = "Interface\\Icons\\Trade_BlackSmithing" }
B.source = "wow-professions.com WoW Forever guide (beta-tested to 240; checked against the game's recipe tables)"

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
  { from = 25,  to = 75,  craft = "Rough Grinding Stone", n = 84, mats = "2 Rough Stone each" },
  { from = 50,  to = 50,  train = "Journeyman (skill 50, level 10)" },
  { from = 75,  to = 84,  craft = "Coarse Grinding Stone", n = 60, mats = "2 Coarse Stone each. Keep all 60 for the bracers at 95 and 115 and the gauntlets at 125." },
  { from = 84,  to = 95,  craft = "Rough Bronze Leggings", n = 11, mats = "6 Bronze Bar each" },
  { from = 95,  to = 100, craft = "Patterned Bronze Bracers", n = 5, mats = "5 Bronze Bar, 2 Coarse Grinding Stone each" },
  { from = 100, to = 115, craft = "Heavy Grinding Stone", n = 30, mats = "3 Heavy Stone each. Keep all 30 for the Golden Scale Bracers at 185." },
  { from = 115, to = 125, craft = "Patterned Bronze Bracers", n = 10, mats = "5 Bronze Bar, 2 Coarse Grinding Stone each" },
  { from = 125, to = 125, train = "Expert (skill 125, level 20, 50 silver)" },
  { from = 125, to = 140, craft = "Silvered Bronze Gauntlets", n = 15, mats = "8 Bronze Bar, 1 Silver Bar, 2 Coarse Grinding Stone each (the last 30 stones from 75; or 15 Bronze Warhammer: 8 Bronze Bar, 1 Strong Flux, 1 Medium Leather each)" },
  { from = 140, to = 175, craft = "Green Iron Bracers", n = 40, mats = "6 Iron Bar, 1 Green Dye each" },
  { from = 175, to = 180, craft = "Solid Grinding Stone", n = 8, mats = "4 Solid Stone each. Keep 6 for the Heavy Mithril Axes at 210." },
  { from = 180, to = 185, craft = "Solid Sharpening Stone", n = 28, mats = "1 Solid Stone each" },
  { from = 185, to = 195, craft = "Golden Scale Bracers", n = 15, mats = "5 Steel Bar, 2 Heavy Grinding Stone each (the 30 stones from 100)" },
  { from = 195, to = 210, craft = "Mithril Plate Pants", n = 17, mats = "12 Mithril Bar each" },
  { from = 200, to = 200, train = "Artisan (skill 200, level 35)" },
  { from = 210, to = 215, craft = "Heavy Mithril Axe", n = 6, mats = "12 Mithril Bar, 2 Citrine, 1 Solid Grinding Stone, 4 Heavy Leather each (or, with the Plans: Mithril Spurs, 15 Mithril Spurs from 210 to 225 instead of the axes and coifs: 4 Mithril Bar, 3 Solid Grinding Stone each)" },
  { from = 215, to = 225, craft = "Mithril Coif", n = 10, mats = "10 Mithril Bar, 6 Mageweave Cloth each (or the Mithril Spurs from 210, if you have the plans)" },
  { from = 225, to = 235, craft = "Dense Sharpening Stone", n = 16, mats = "1 Dense Stone each" },
  { from = 235, to = 240, craft = "Heavy Mithril Boots", n = 11, mats = "14 Mithril Bar, 4 Thick Leather each (or with the Mithril Spurs plans: 28 Mithril Spurs from 235 to 245 instead of the boots and the belt)" },
  { from = 240, to = 245, craft = "Imperial Plate Belt", n = 5, mats = "22 Thorium Bar, 6 Rugged Leather, 1 Aquamarine each (plans: Derotain Mudsipper, Tanaris, level 50 quest; he gives the next three plans too, so bring about 250 Thorium Bar. With the world-drop plans for Dazzling Mithril Rapier, Runed Mithril Hammer or Thorium Bracers, make those from 240 to 255 instead: 27 Rapiers, 20 Hammers or 17 Bracers)" },
  { from = 245, to = 270, craft = "Imperial Plate Bracers", n = 27, mats = "20 Thorium Bar, 1 Star Ruby each (Derotain Mudsipper)" },
  { from = 270, to = 290, craft = "Imperial Plate Boots or Radiant Boots", n = 20, mats = "34 Thorium Bar, 1 Star Ruby, 1 Aquamarine each (Derotain Mudsipper; or about 22 Radiant Boots: 14 Thorium Bar, 4 Heart of Fire each, or from 275 15 Thorium Leggings: 26 Thorium Bar, 4 Red Power Crystal each)" },
  { from = 290, to = 300, craft = "Imperial Plate Leggings or Radiant Leggings or Thorium Leggings", n = 10, mats = "44 Thorium Bar, 2 Star Ruby each (Derotain Mudsipper; or 10 Radiant Leggings: 20 Thorium Bar, 4 Heart of Fire each, or 12 Thorium Leggings: 26 Thorium Bar, 4 Red Power Crystal each)" },
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
B.suppliesA = "Blacksmith Hammer and Weak Flux: the Blacksmithing Supply vendor next to each capital trainer (Stormwind, Ironforge, Darnassus). Green Dye: a Blacksmithing or dye vendor in your capital."
B.supplies = "Blacksmith Hammer and Weak Flux: the Blacksmithing Supply vendor next to each capital trainer. Green Dye: Tamar (Orgrimmar), Millie Gregorian (Undercity), Mahu (Thunder Bluff)."

-- Bars whose Auction House prices are tracked (ore and basic bars come from Mining).
B.mats = {
  2841, 3859, 6037, 12360, -- Bronze, Steel, Truesilver, Arcanite bars
}

RG.RegisterProfession("Blacksmithing", B)
