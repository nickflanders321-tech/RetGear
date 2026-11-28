-- Waypath+ profession data: Tailoring. Route from the wow-professions.com WoW
-- Forever guide, checked against the game's own recipe tables (tools/profs/check.py).
-- Cloth drops from humanoids while you quest.
local _, RG = ...
local T = { name = "Tailoring", kind = "craft", icon = "Interface\\Icons\\Trade_Tailoring" }
T.source = "wow-professions.com WoW Forever guide (checked against the game's recipe tables)"
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
  artisan = "Timothy Worthington (Theramore Isle, Dustwallow Marsh)",
}
T.supplies = "Threads and dyes: the Tailoring Supply vendor by each trainer (Brill: Abigail Shiel)."
T.plan = {
  { from = 1,   to = 30,  craft = "Bolt of Linen Cloth", n = 30, mats = "2 Linen Cloth each. Keep the bolts." },
  { from = 30,  to = 55,  craft = "Linen Belt", n = 28, mats = "1 Bolt of Linen Cloth, 1 Coarse Thread each" },
  { from = 50,  to = 50,  train = "Journeyman (skill 50, level 10)" },
  { from = 55,  to = 80,  craft = "Bolt of Woolen Cloth", n = 37, mats = "3 Wool Cloth each" },
  { from = 80,  to = 95,  craft = "Woolen Cape", n = 22, mats = "1 Bolt of Woolen Cloth, 1 Fine Thread each" },
  { from = 95,  to = 100, craft = "Double-stitched Woolen Shoulders", n = 5, mats = "3 Bolt of Woolen Cloth, 2 Fine Thread each" },
  { from = 100, to = 120, craft = "Bolt of Silk Cloth", n = 55, mats = "4 Silk Cloth each. Keep them." },
  { from = 120, to = 125, craft = "Azure Silk Hood", n = 5, mats = "2 Bolt of Silk Cloth, 2 Blue Dye, 1 Fine Thread each" },
  { from = 125, to = 125, train = "Expert (skill 125, level 20, 50 silver)" },
  { from = 125, to = 140, craft = "Small Silk Pack", n = 15, mats = "3 Bolt of Silk Cloth, 2 Heavy Leather, 3 Fine Thread each" },
  { from = 140, to = 150, craft = "Bolt of Mageweave", n = 23, mats = "5 Mageweave Cloth each. Keep them." },
  { from = 150, to = 171, craft = "Crimson Silk Vest", n = 21, mats = "4 Bolt of Silk Cloth, 2 Red Dye, 2 Fine Thread each" },
  { from = 171, to = 185, craft = "Crimson Silk Pantaloons", n = 16, mats = "4 Bolt of Silk Cloth, 2 Red Dye, 2 Silken Thread each" },
  { from = 185, to = 200, craft = "Black Mageweave Leggings", n = 22, mats = "2 Bolt of Mageweave, 3 Silken Thread each" },
  { from = 200, to = 200, train = "Artisan (skill 200, level 35)" },
  { from = 200, to = 205, craft = "Black Mageweave Shoulders", n = 5, mats = "3 Bolt of Mageweave, 2 Heavy Silken Thread each (only the Artisan trainers teach it)" },
  { from = 205, to = 215, craft = "Bolt of Runecloth", n = 23, mats = "5 Runecloth each. Keep the bolts for the next steps." },
  { from = 215, to = 225, craft = "Red Mageweave Bag or Runecloth Belt", n = 17, mats = "5 Bolt of Mageweave, 2 Red Dye, 2 Heavy Silken Thread each (or Runecloth Belt: 3 Bolt of Runecloth, 1 Rune Thread; about 10 crafts)" },
  { from = 225, to = 240, craft = "Runecloth Belt", n = 24, mats = "3 Bolt of Runecloth, 1 Rune Thread each" },
  { from = 240, to = 250, craft = "Runecloth Gloves or Brightcloth Cloak", n = 11, mats = "4 Bolt of Runecloth, 4 Rugged Leather, 1 Rune Thread each (pattern: Qia, Everlook; or Brightcloth Cloak: 4 Bolt of Runecloth, 2 Gold Bar, 1 Rune Thread each)" },
  { from = 250, to = 280, craft = "Runecloth Cuffs", n = 39, mats = "5 Bolt of Runecloth, 1 Ironweb Spider Silk, 1 Rune Thread each (pattern: Pexmit, Mount Hyjal; Bind on Pickup. Without it: 19 Runecloth Gloves, 4 Bolt of Runecloth, 4 Rugged Leather, 1 Rune Thread each, or 21 Runecloth Shoulders, 7 Bolt of Runecloth, 2 Ironweb Spider Silk, 4 Rugged Leather, 1 Rune Thread each)" },
  { from = 280, to = 300, craft = "Runecloth Shoulders or Wizardweave Turban", n = 58, mats = "7 Bolt of Runecloth, 2 Ironweb Spider Silk, 4 Rugged Leather, 1 Rune Thread each (pattern: world drop, look on the Auction House; or Wizardweave Turban: 6 Bolt of Runecloth, 4 Dream Dust, 1 Star Ruby, 1 Rune Thread. With Cenarion Circle reputation and a Loom nearby, Swarmtender's or Venomspew gloves, cord and footpads from 285)" },
}
T.mats = { 2589, 2592, 4306, 4338, 14047, 2996, 2997, 4305, 4339, 14048 }
RG.RegisterProfession("Tailoring", T)
