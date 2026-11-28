-- Waypath+ profession data: First Aid (secondary: doesn't use a profession slot).
-- In WoW Forever it also makes Healing Potions. Route: wow-professions.com WoW Forever
-- guide (beta data; 225-300 not yet tested on Forever).
local _, RG = ...
local F = { name = "First Aid", kind = "secondary", icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" }
F.source = "wow-professions.com WoW Forever guide (checked against the game's recipe tables)"
F.train = {
  start = { O = "Rawrk in the Razor Hill barracks", R = "Rawrk in the Razor Hill barracks", T = "Vira Younghoof in the Bloodhoof Village inn", U = "Nurse Neela in the Brill inn", S = "the Zephras Isle First Aid trainers" },
  apprentice = "Arnok (Orgrimmar), Mary Edras (Undercity), Pand Stonebinder (Thunder Bluff)",
  journeyman = "any First Aid trainer (skill 50)",
  expert = "the book Expert First Aid - Under Wraps from Balai Lok'Wein (Dustwallow Marsh), with the Heavy Silk and Mageweave Bandage manuals",
  artisan = "the Triage quest from Doctor Gregory Victor (Hammerfall, Arathi Highlands; skill 225, level 35)",
}

-- Alliance: the same trainers, in Stormwind, Ironforge, Darnassus and the starting zones (Profile.lua uses this one for Alliance characters).
F.trainA = {
  start = { H = "Shaina Fuller in Stormwind", D = "Nissa Firestone in Ironforge", G = "Nissa Firestone in Ironforge", N = "Byancie in Dolanaar", A = "Shaina Fuller in Stormwind" },
  apprentice = "Shaina Fuller (Stormwind), Nissa Firestone (Ironforge), Dannelor (Darnassus), Byancie (Dolanaar)",
  journeyman = "any First Aid trainer (skill 50)",
  expert = "the book Expert First Aid - Under Wraps from Doctor Gustaf VanHowzen (Theramore Isle), with the Heavy Silk and Mageweave Bandage manuals",
  artisan = "the Triage quest from Doctor Gustaf VanHowzen (Theramore Isle; skill 225, level 35)",
}
F.supplies = "Only cloth (or Peacebloom, Spider Ichor, Bruiseweed, spices and vials for the potion and poultice route)."
F.plan = {
  { from = 1,   to = 40,  craft = "Linen Bandage", n = 50, mats = "1 Linen Cloth each (or 86 Minor Healing Potions to 75: 1 Peacebloom, 1 Mild Spices, 1 Empty Vial each)" },
  { from = 40,  to = 75,  craft = "Heavy Linen Bandage", n = 49, mats = "2 Linen Cloth each" },
  { from = 50,  to = 50,  train = "Journeyman (skill 50)" },
  { from = 75,  to = 80,  craft = "Heavy Linen Bandage", n = 16, mats = "2 Linen Cloth each" },
  { from = 80,  to = 90,  craft = "Wool Bandage", n = 12, mats = "1 Wool Cloth each" },
  { from = 90,  to = 115, craft = "Wool Bandage", n = 43, mats = "1 Wool Cloth each (or 90-125: 54 Simple Poultices, 1 Spider Ichor, 1 Mild Spices, 1 Bottle of Dalaran Noir each)" },
  { from = 115, to = 150, craft = "Heavy Wool Bandage", n = 54, mats = "2 Wool Cloth each (or 125-150: 31 Healing Potions, 1 Bruiseweed, 1 Hot Spices, 1 Leaded Vial each)" },
  { from = 125, to = 125, train = "Expert: buy Expert First Aid - Under Wraps (Balai Lok'Wein, Dustwallow Marsh)" },
  { from = 150, to = 180, craft = "Silk Bandage", n = 47, mats = "1 Silk Cloth each" },
  { from = 180, to = 210, craft = "Heavy Silk Bandage", n = 47, mats = "2 Silk Cloth each" },
  { from = 210, to = 225, craft = "Mageweave Bandage", n = 19, mats = "1 Mageweave Cloth each" },
  { from = 225, to = 225, train = "Artisan: the Triage quest at Hammerfall (level 35)" },
  { from = 225, to = 240, craft = "Mageweave Bandage", n = 29, mats = "1 Mageweave Cloth each" },
  { from = 240, to = 260, craft = "Heavy Mageweave Bandage", n = 30, mats = "2 Mageweave Cloth each" },
  { from = 260, to = 290, craft = "Runecloth Bandage", n = 47, mats = "1 Runecloth each (or 30 Major Healing Potions: 1 Golden Sansam, 3 Soothing Spices, 1 Crystal Vial each)" },
  { from = 290, to = 300, craft = "Heavy Runecloth Bandage", n = 12, mats = "2 Runecloth each" },
}
F.mats = { 2589, 2592, 4306, 4338, 14047 }
RG.RegisterProfession("First Aid", F)
