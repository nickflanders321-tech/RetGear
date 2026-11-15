-- Waypath+ profession data: Tailoring. Horde route from the wow-professions.com WoW
-- Forever guide (beta data) to 225, then WoW Forever's own skill ranges from the game's tables (tools/profs/check.py).
-- Cloth drops from humanoids while you quest.
local _, RG = ...
local T = { name = "Tailoring", kind = "craft", icon = "Interface\\Icons\\Trade_Tailoring" }
T.source = "wow-professions.com WoW Forever guide to 225; past that, WoW Forever's own recipe ranges"
T.train = {
  start = { O = "Snang in the Drag, Orgrimmar", R = "Snang in the Drag, Orgrimmar", T = "Vhan, middle rise of Thunder Bluff", U = "Bowen Brisboise at Cold Hearth Manor, south-west of Brill", S = "Vhan in Thunder Bluff or Snang in Orgrimmar" },
  apprentice = "Snang (Orgrimmar), Victor Ward (Undercity), Vhan (Thunder Bluff)",
  journeyman = "Magar (Orgrimmar), Rhiannon Davis (Undercity), Tepa (Thunder Bluff)",
  expert = "Josef Gregorian (Undercity)",
  artisan = "Daryl Stack (Tarren Mill, Hillsbrad Foothills)",
}

-- Alliance: the same trainers, in Stormwind, Ironforge, Darnassus and the starting zones (Profile.lua uses this one for Alliance characters).
T.trainA = {
  start = { H = "Eldrin in Elwynn Forest", D = "Uthrar Threx in Ironforge", G = "Uthrar Threx in Ironforge", N = "Trianna in Darnassus", A = "Lawrence Schneider in Stormwind" },
  apprentice = "Eldrin (Elwynn Forest), Lawrence Schneider (Stormwind), Uthrar Threx (Ironforge), Trianna (Darnassus)",
  journeyman = "Lawrence Schneider (Stormwind), Uthrar Threx (Ironforge), Trianna (Darnassus)",
  expert = "Sellandus (Stormwind), Jormund Stonebrow (Ironforge), Me'lynn (Darnassus)",
  artisan = "Georgio Bolero (Stormwind)",
}
T.supplies = "Threads and dyes: the Tailoring Supply vendor by each trainer (Brill: Abigail Shiel)."
T.plan = {
  { from = 1,   to = 30,  craft = "Bolt of Linen Cloth", n = 30, mats = "2 Linen Cloth each. Keep the bolts." },
  { from = 30,  to = 55,  craft = "Linen Belt", n = 28, mats = "1 Bolt of Linen Cloth, 1 Coarse Thread each" },
  { from = 50,  to = 50,  train = "Journeyman (skill 50, level 10)" },
  { from = 55,  to = 80,  craft = "Bolt of Woolen Cloth", n = 45, mats = "3 Wool Cloth each" },
  { from = 80,  to = 95,  craft = "Woolen Cape", n = 22, mats = "1 Bolt of Woolen Cloth, 1 Fine Thread each" },
  { from = 95,  to = 100, craft = "Double-stitched Woolen Shoulders", n = 5, mats = "3 Bolt of Woolen Cloth, 2 Fine Thread each" },
  { from = 100, to = 120, craft = "Bolt of Silk Cloth", n = 40, mats = "4 Silk Cloth each. Keep them." },
  { from = 120, to = 125, craft = "Double-stitched Woolen Shoulders", n = 8, mats = "3 Bolt of Woolen Cloth, 2 Fine Thread each" },
  { from = 125, to = 125, train = "Expert (skill 125, level 20, 50 silver)" },
  { from = 125, to = 140, craft = "Gloves of Meditation", n = 20, mats = "4 Bolt of Woolen Cloth, 3 Fine Thread, 1 Elixir of Wisdom each" },
  { from = 140, to = 150, craft = "Bolt of Mageweave", n = 17, mats = "5 Mageweave Cloth each. Keep them." },
  { from = 150, to = 170, craft = "Crimson Silk Vest", n = 20, mats = "4 Bolt of Silk Cloth, 2 Red Dye, 2 Fine Thread each" },
  { from = 170, to = 190, craft = "Crimson Silk Pantaloons", n = 24, mats = "4 Bolt of Silk Cloth, 2 Red Dye, 2 Silken Thread each" },
  { from = 190, to = 205, craft = "Black Mageweave Gloves", n = 19, mats = "2 Bolt of Mageweave, 2 Heavy Silken Thread each" },
  { from = 200, to = 200, train = "Artisan (skill 200, level 35)" },
  -- (from here: WoW Forever's own skill ranges, which run 25 to 45 points lower than Classic's)
  { from = 205, to = 215, craft = "Mageweave Bag", n = 14, mats = "4 Bolt of Mageweave, 2 Silken Thread each" },
  { from = 215, to = 225, craft = "Runecloth Belt", n = 11, mats = "3 Bolt of Runecloth, 1 Rune Thread each (Bolt of Runecloth: 5 Runecloth; it gives skill-ups only to 215)" },
  { from = 225, to = 230, craft = "Runecloth Bag", n = 6, mats = "5 Bolt of Runecloth, 2 Rugged Leather, 1 Rune Thread, 4 Magenta Dye, 2 Cerulean Dye each (pattern: Qia, Everlook)" },
  { from = 230, to = 250, craft = "Runecloth Gloves", n = 23, mats = "4 Bolt of Runecloth, 4 Rugged Leather, 1 Rune Thread each (pattern: Qia, Everlook)" },
  { from = 250, to = 265, craft = "Runecloth Boots", n = 23, mats = "4 Bolt of Runecloth, 2 Ironweb Spider Silk, 4 Rugged Leather, 1 Rune Thread each (pattern: Darnall, Moonglade)" },
  { from = 265, to = 275, craft = "Runecloth Headband", n = 14, mats = "4 Bolt of Runecloth, 2 Ironweb Spider Silk, 1 Rune Thread each (the pattern drops from level 50-60 mobs: look on the Auction House)" },
  { from = 275, to = 300, craft = "Runecloth Shoulders or Mooncloth Robe", n = 30, mats = "7 Bolt of Runecloth, 2 Ironweb Spider Silk, 4 Rugged Leather, 1 Rune Thread each (Runecloth Shoulders: the pattern drops from level 55-60 mobs, look on the Auction House; or Mooncloth Robe, pattern from Darnall, Moonglade: 6 Bolt of Runecloth, 4 Mooncloth, 2 Golden Pearl, 2 Rune Thread)" },
}
T.mats = { 2589, 2592, 4306, 4338, 14047, 2996, 2997, 4305, 4339, 14048 }
RG.RegisterProfession("Tailoring", T)
