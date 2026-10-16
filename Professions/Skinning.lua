-- Waypath+ profession data: Skinning. You can skin a beast up to level skill / 5
-- (skill / 10 + 10 below 100), so the beasts in the zones you quest in are usually right.
local _, RG = ...
local K = { name = "Skinning", kind = "gather", gathering = true, icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" }
K.source = "WoW Forever creature data"
K.train = {
  start = { O = "Thuwd in Orgrimmar (closest to Durotar)", R = "Thuwd in Orgrimmar (closest to Durotar)", T = "Mooranta in Thunder Bluff", U = "Killian Hagey in Undercity", S = "a Zephras Isle trainer, or any capital" },
  apprentice = "Thuwd (Orgrimmar), Killian Hagey (Undercity), Mooranta (Thunder Bluff)",
  journeyman = "any Skinning trainer (level 10)", expert = "any Skinning trainer (level 20)", artisan = "any Skinning trainer (level 35)",
}

-- Alliance: the same trainers, in Stormwind, Ironforge, Darnassus and the starting zones (Profile.lua uses this one for Alliance characters).
K.trainA = {
  start = { H = "Maris Granger in Stormwind", D = "Balthus Stoneflayer in Ironforge", G = "Balthus Stoneflayer in Ironforge", N = "Eladriel in Darnassus", A = "Maris Granger in Stormwind" },
  apprentice = "Maris Granger (Stormwind), Balthus Stoneflayer (Ironforge), Eladriel (Darnassus)",
  journeyman = "any Skinning trainer (level 10)", expert = "any Skinning trainer (level 20)", artisan = "any Skinning trainer (level 35)",
}
K.supplies = "Skinning Knife: Trade Supplies vendors. In Forever each beast can be skinned once."
K.plan = {
  { from = 1,   to = 75,  skin = "Beasts level 1-17 (Light Leather, Light Hide)", where = "your starting zone, then The Barrens and Silverpine Forest" },
  { from = 75,  to = 125, skin = "Beasts level 17-25 (Medium Leather)", where = "The Barrens, Stonetalon Mountains, Ashenvale, Hillsbrad Foothills" },
  { from = 125, to = 175, skin = "Beasts level 25-35 (Heavy Leather)", where = "Thousand Needles, Arathi Highlands, Desolace, Stranglethorn Vale" },
  { from = 175, to = 250, skin = "Beasts level 35-50 (Thick Leather)", where = "Dustwallow Marsh, Feralas, Tanaris, The Hinterlands" },
  { from = 250, to = 300, skin = "Beasts level 50-60 (Rugged Leather)", where = "Un'Goro Crater, Felwood, Winterspring, Burning Steppes" },
}
K.mats = { 2318, 2319, 4234, 4304, 8170, 783, 4232, 4235, 8169, 8171 }
RG.RegisterProfession("Skinning", K)
