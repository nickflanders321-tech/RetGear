-- Waypath+ profession data: Leatherworking. Horde route from the wow-professions.com
-- WoW Forever guide (beta data) to 225, then the Classic route (not yet tested on
-- Forever). Pairs with Skinning.
local _, RG = ...
local L = { name = "Leatherworking", kind = "craft", icon = "Interface\\Icons\\INV_Misc_ArmorKit_17" }
L.train = {
  start = { O = "Kamari in the Drag, Orgrimmar", R = "Kamari in the Drag, Orgrimmar", T = "Chaw Stronghide in Bloodhoof Village", U = "Shelene Rhobart at the road junction south-east of Brill", S = "Kamari in Orgrimmar or Chaw Stronghide in Bloodhoof Village" },
  apprentice = "Kamari (Orgrimmar), Dan Golthas (Undercity), Mak (Thunder Bluff)",
  journeyman = "Karolek (Orgrimmar), Arthur Moore (Undercity), Tarn (Thunder Bluff)",
  expert = "Una (Thunder Bluff)",
  artisan = "Hahrana Ironhide (Camp Mojache, Feralas)",
}
L.supplies = "Salt, threads and dyes: the Leatherworking Supply vendor by each trainer (Brill: Abigail Shiel)."
L.plan = {
  { from = 1,   to = 30,  craft = "Light Leather", n = 33, mats = "3 Ruined Leather Scraps each (or Light Armor Kit from bought Light Leather)" },
  { from = 30,  to = 55,  craft = "Cured Light Hide", n = 27, mats = "1 Light Hide, 1 Salt each. Keep 24 for 100." },
  { from = 50,  to = 50,  train = "Journeyman (skill 50, level 10)" },
  { from = 55,  to = 75,  craft = "Embossed Leather Gloves", n = 21, mats = "3 Light Leather, 2 Coarse Thread each" },
  { from = 75,  to = 80,  craft = "Medium Leather", n = 8, mats = "4 Light Leather each" },
  { from = 80,  to = 90,  craft = "Cured Medium Hide", n = 10, mats = "1 Medium Hide, 1 Salt each. Keep them." },
  { from = 90,  to = 100, craft = "Fine Leather Belt", n = 19, mats = "6 Light Leather, 2 Coarse Thread each. Keep 10." },
  { from = 100, to = 115, craft = "Light Leather Pants", n = 24, mats = "10 Light Leather, 1 Cured Light Hide, 1 Fine Thread each" },
  { from = 115, to = 125, craft = "Dark Leather Belt", n = 10, mats = "1 Fine Leather Belt, 1 Cured Medium Hide, 2 Fine Thread, 1 Gray Dye each" },
  { from = 125, to = 125, train = "Expert (skill 125, level 20, 50 silver)" },
  { from = 125, to = 130, craft = "Heavy Leather", n = 7, mats = "5 Medium Leather each" },
  { from = 130, to = 155, craft = "Hillman's Leather Gloves", n = 30, mats = "14 Medium Leather, 4 Fine Thread each" },
  { from = 155, to = 170, craft = "Barbaric Leggings", n = 17, mats = "10 Heavy Leather, 2 Fine Thread, 1 Moss Agate each (pattern: Jandia, Thousand Needles)" },
  { from = 170, to = 175, craft = "Barbaric Harness", n = 5, mats = "14 Heavy Leather, 2 Fine Thread, 1 Iron Buckle each" },
  { from = 175, to = 195, craft = "Guardian Gloves", n = 26, mats = "4 Heavy Leather, 1 Cured Heavy Hide, 1 Silken Thread each" },
  { from = 195, to = 210, craft = "Nightscape Headband", n = 21, mats = "5 Thick Leather, 2 Silken Thread each" },
  { from = 200, to = 200, train = "Artisan (skill 200, level 35)" },
  { from = 210, to = 235, craft = "Nightscape Headband", n = 30, mats = "5 Thick Leather, 2 Silken Thread each" },
  { from = 235, to = 250, craft = "Nightscape Pants", n = 15, mats = "14 Thick Leather, 4 Silken Thread each" },
  { from = 250, to = 260, craft = "Nightscape Boots", n = 13, mats = "16 Thick Leather, 2 Heavy Silken Thread each" },
  { from = 260, to = 290, craft = "Wicked Leather Gauntlets", n = 33, mats = "8 Rugged Leather, 1 Black Dye, 1 Rune Thread each (pattern: Werg Thickblade, Tirisfal)" },
  { from = 290, to = 300, craft = "Wicked Leather Headband", n = 10, mats = "12 Rugged Leather, 1 Black Dye, 1 Rune Thread each (or Runic Leather Headband)" },
}
L.mats = { 2318, 2319, 4234, 4304, 8170, 783, 4232, 4235, 8169, 8171 }
RG.RegisterProfession("Leatherworking", L)
