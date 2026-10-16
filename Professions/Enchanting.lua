-- Waypath+ profession data: Enchanting. Horde route from the wow-professions.com WoW
-- Forever guide (beta data; 225-300 not yet tested on Forever). You need a Tailor,
-- Herbalist or the Auction House for gear to disenchant.
local _, RG = ...
local E = { name = "Enchanting", kind = "craft", icon = "Interface\\Icons\\Trade_Engraving" }
E.source = "wow-professions.com WoW Forever guide (Classic route past 225)"
E.train = {
  start = { O = "Pa'zula in Sen'jin Village", R = "Pa'zula in Sen'jin Village", T = "Mot Dawnstrider in Thunder Bluff", U = "Vance Undergloom upstairs in the Brill inn", S = "a Zephras Isle trainer" },
  apprentice = "Jhag (Orgrimmar), Malcomb Wynn (Undercity), Mot Dawnstrider (Thunder Bluff)",
  journeyman = "Godan (Orgrimmar), Lavinia Crowe (Undercity), Teg Dawnstrider (Thunder Bluff)",
  expert = "Hgarth (Sun Rock Retreat, Stonetalon Mountains)",
  artisan = "Annora (Uldaman, back entrance: bring a group; learn every recipe from her)",
}

-- Alliance: the same trainers, in Stormwind, Ironforge, Darnassus and the starting zones (Profile.lua uses this one for Alliance characters).
E.trainA = {
  start = { H = "Betty Quin in Stormwind", D = "Thonys Pillarstone in Ironforge", G = "Thonys Pillarstone in Ironforge", N = "Alanna Raveneye in Dolanaar", A = "Betty Quin in Stormwind" },
  apprentice = "Betty Quin (Stormwind), Thonys Pillarstone (Ironforge), Lalina Summermoon (Darnassus), Alanna Raveneye (Dolanaar)",
  journeyman = "Betty Quin (Stormwind), Thonys Pillarstone (Ironforge), Lalina Summermoon (Darnassus)",
  expert = "Lucan Cordell (Stormwind), Gimble Thistlefuzz (Ironforge), Taladan (Darnassus)",
  artisan = "Kitta Firewind (Elwynn Forest, Eastvale Logging Camp: learn every recipe from her)",
}
E.supplies = "Copper Rod and Mote of Magic: the Enchanting Supply vendor near each capital trainer."
E.plan = {
  { from = 1,   to = 2,   craft = "Runed Copper Rod", n = 1, mats = "1 Copper Rod, 1 Mote of Magic" },
  { from = 2,   to = 20,  craft = "Enchant Bracer - Inferior Stamina", n = 18, mats = "1 Mote of Magic each" },
  { from = 20,  to = 70,  craft = "Enchant Chest - Inferior Stamina", n = 50, mats = "1 Strange Dust each (or Bracer - Minor Deflect: 1 Lesser Magic Essence)" },
  { from = 50,  to = 50,  train = "Journeyman (skill 50, level 10)" },
  { from = 70,  to = 100, craft = "Enchant Bracer - Minor Stamina", n = 30, mats = "2 Strange Dust each" },
  { from = 100, to = 109, craft = "Enchant Cloak - Minor Protection", n = 9, mats = "2 Strange Dust each" },
  { from = 109, to = 110, craft = "Runed Silver Rod", n = 1, mats = "1 Silver Rod, 3 Strange Dust, 4 Lesser Magic Essence, 1 Shadowgem" },
  { from = 110, to = 130, craft = "Enchant Cloak - Minor Protection", n = 32, mats = "2 Strange Dust each" },
  { from = 125, to = 125, train = "Expert (skill 125, level 20, 50 silver)" },
  { from = 130, to = 150, craft = "Enchant Boots - Minor Stamina", n = 20, mats = "4 Strange Dust each" },
  { from = 150, to = 151, craft = "Runed Golden Rod", n = 1, mats = "1 Golden Rod, 1 Iridescent Pearl, 1 Greater Astral Essence, 1 Soul Dust" },
  { from = 151, to = 165, craft = "Minor Mana Oil", n = 16, mats = "1 Soul Dust, 2 Maple Seed, 1 Leaded Vial each (formula: Kithas, Orgrimmar)" },
  { from = 165, to = 185, craft = "Enchant Boots - Lesser Agility", n = 22, mats = "1 Soul Dust each" },
  { from = 185, to = 200, craft = "Enchant Bracer - Strength", n = 15, mats = "1 Vision Dust each" },
  { from = 200, to = 201, craft = "Runed Truesilver Rod", n = 1, mats = "1 Truesilver Rod, 1 Black Pearl, 1 Greater Mystic Essence, 1 Vision Dust" },
  { from = 200, to = 200, train = "Artisan (skill 200, level 35)" },
  { from = 201, to = 220, craft = "Lesser Wizard Oil", n = 25, mats = "1 Vision Dust, 2 Stranglethorn Seed, 1 Leaded Vial each" },
  { from = 220, to = 230, craft = "Enchant Gloves - Agility", n = 10, mats = "1 Vision Dust each" },
  { from = 230, to = 235, craft = "Enchant Boots - Stamina", n = 5, mats = "2 Vision Dust each" },
  { from = 235, to = 250, craft = "Enchant Chest - Superior Stamina", n = 20, mats = "3 Vision Dust each" },
  { from = 250, to = 265, craft = "Lesser Mana Oil", n = 20, mats = "1 Dream Dust, 1 Purple Lotus, 1 Crystal Vial each (formula: Kania, Silithus)" },
  { from = 265, to = 294, craft = "Enchant Shield - Greater Stamina", n = 32, mats = "6 Dream Dust each (formula: Daniel Bartlett, Undercity)" },
  { from = 294, to = 295, craft = "Runed Arcanite Rod", n = 1, mats = "Arcanite Rod, Golden Pearl, 10 Illusion Dust, 4 Greater Eternal Essence, 4 Small and 2 Large Brilliant Shard (Lorelae Wintersong, Moonglade)" },
  { from = 295, to = 300, craft = "Enchant Cloak - Superior Defense", n = 5, mats = "8 Illusion Dust each (Lorelae Wintersong, Moonglade)" },
}
E.mats = { 10940, 10938, 10939, 11083, 11137, 11176, 16204 }
RG.RegisterProfession("Enchanting", E)
