-- Waypath+ profession data: Leatherworking. Route from the wow-professions.com
-- WoW Forever guide, checked against the game's own recipe tables (tools/profs/check.py). Pairs with Skinning.
local _, RG = ...
local L = { name = "Leatherworking", kind = "craft", icon = "Interface\\Icons\\INV_Misc_ArmorKit_17" }
L.source = "wow-professions.com WoW Forever guide (checked against the game's recipe tables)"
L.train = {
  start = { O = "Kamari in the Drag, Orgrimmar", R = "Kamari in the Drag, Orgrimmar", T = "Chaw Stronghide in Bloodhoof Village", U = "Shelene Rhobart at the road junction south-east of Brill", S = "Kamari in Orgrimmar or Chaw Stronghide in Bloodhoof Village" },
  apprentice = "Kamari (Orgrimmar), Dan Golthas (Undercity), Mak (Thunder Bluff)",
  journeyman = "Karolek (Orgrimmar), Arthur Moore (Undercity), Tarn (Thunder Bluff)",
  expert = "Una (Thunder Bluff)",
  artisan = "Hahrana Ironhide (Camp Mojache, Feralas)",
}

-- Alliance: the same trainers, in Stormwind, Ironforge, Darnassus and the starting zones (Profile.lua uses this one for Alliance characters).
L.trainA = {
  start = { H = "Adele Fielder in Elwynn Forest", D = "Gretta Finespindle in Ironforge", G = "Gretta Finespindle in Ironforge", N = "Nadyia Maneweaver in Dolanaar", A = "Randal Worth in Stormwind" },
  apprentice = "Randal Worth (Stormwind), Gretta Finespindle (Ironforge), Darianna (Darnassus), Adele Fielder (Elwynn Forest), Nadyia Maneweaver (Dolanaar)",
  journeyman = "Randal Worth (Stormwind), Gretta Finespindle (Ironforge), Darianna (Darnassus)",
  expert = "Simon Tanner (Stormwind), Fimble Finespindle (Ironforge), Faldron (Darnassus)",
  artisan = "Drakk Stonehand (Aerie Peak, The Hinterlands)",
}
L.supplies = "Salt, threads and dyes: the Leatherworking Supply vendor by each trainer (Brill: Abigail Shiel)."
L.plan = {
  { from = 1,   to = 30,  craft = "Light Leather", n = 35, mats = "3 Ruined Leather Scraps each (or Light Armor Kit from bought Light Leather)" },
  { from = 30,  to = 50,  craft = "Cured Light Hide", n = 20, mats = "1 Light Hide, 1 Salt each. Keep them for the pants at 60. (Or 24 Light Armor Kits, 1 Light Leather each, then 5 Embossed Leather Gloves, 3 Light Leather, 2 Coarse Thread each)" },
  { from = 50,  to = 50,  train = "Journeyman (skill 50, level 10)" },
  { from = 50,  to = 60,  craft = "Embossed Leather Gloves", n = 10, mats = "3 Light Leather, 2 Coarse Thread each" },
  { from = 60,  to = 80,  craft = "Embossed Leather Pants", n = 20, mats = "1 Cured Light Hide, 6 Light Leather, 2 Coarse Thread each (or 24 Embossed Leather Gloves, 3 Light Leather, 2 Coarse Thread each)" },
  { from = 80,  to = 95,  craft = "Cured Medium Hide", n = 20, mats = "1 Medium Hide, 1 Salt each. Keep them for the belts at 105. (Or 19 Fine Leather Belts, 6 Light Leather, 2 Coarse Thread each)" },
  { from = 95,  to = 105, craft = "Fine Leather Belt", n = 22, mats = "6 Light Leather, 2 Coarse Thread each. Keep 20." },
  { from = 105, to = 125, craft = "Dark Leather Belt", n = 20, mats = "1 Fine Leather Belt, 1 Cured Medium Hide, 2 Fine Thread, 1 Gray Dye each (or 16 Dark Leather Pants, 12 Medium Leather, 1 Gray Dye, 1 Fine Thread each, then 5 Hillman's Leather Gloves)" },
  { from = 125, to = 125, train = "Expert (skill 125, level 20, 50 silver)" },
  { from = 125, to = 130, craft = "Heavy Leather", n = 7, mats = "5 Medium Leather each" },
  { from = 130, to = 143, craft = "Cured Heavy Hide", n = 25, mats = "1 Heavy Hide, 3 Salt each. Keep them for the shoulders and gloves. (No Heavy Hides? Make 21 Hillman's Leather Gloves from 130 to 150 instead)" },
  { from = 143, to = 150, craft = "Hillman's Leather Gloves", n = 8, mats = "14 Medium Leather, 4 Fine Thread each" },
  { from = 150, to = 165, craft = "Barbaric Shoulders", n = 15, mats = "8 Heavy Leather, 1 Cured Heavy Hide, 2 Fine Thread each (or 15 Barbaric Leggings, 10 Heavy Leather, 1 Moss Agate, 2 Fine Thread each)" },
  { from = 165, to = 175, craft = "Guardian Gloves", n = 10, mats = "4 Heavy Leather, 1 Cured Heavy Hide, 1 Silken Thread each (or 10 Barbaric Harness)" },
  { from = 175, to = 185, craft = "Barbaric Harness", n = 10, mats = "14 Heavy Leather, 2 Fine Thread, 1 Iron Buckle each (or 10 Thick Armor Kits, 5 Thick Leather, 1 Silken Thread each)" },
  { from = 185, to = 205, craft = "Nightscape Headband", n = 22, mats = "5 Thick Leather, 2 Silken Thread each" },
  { from = 200, to = 200, train = "Artisan (skill 200, level 35)" },
  { from = 205, to = 235, craft = "Nightscape Pants", n = 36, mats = "14 Thick Leather, 4 Silken Thread each (only the Artisan trainers teach it: they sell for more than the boots)" },
  { from = 235, to = 265, craft = "Wicked Leather Gauntlets", n = 36, mats = "8 Rugged Leather, 1 Black Dye, 1 Rune Thread each (pattern: Werg Thickblade, Tirisfal Glades; Leonard Porter, Western Plaguelands. Or Blue Suede Shoes if the pattern costs more than about 13 gold)" },
  { from = 265, to = 300, craft = "Runic Leather Headband", n = 49, mats = "14 Rugged Leather, 10 Runecloth, 1 Rune Thread each (pattern: Jase Farlane, Light's Hope Chapel. Or, with the Blue Suede patterns: 27 Blue Suede Bracers then 20 Blue Suede Hat, 10 or 16 Rugged Leather, 1 or 4 Blue Dye, 1 Rune Thread each)" },
}
L.mats = { 2318, 2319, 4234, 4304, 8170, 783, 4232, 4235, 8169, 8171 }
RG.RegisterProfession("Leatherworking", L)
