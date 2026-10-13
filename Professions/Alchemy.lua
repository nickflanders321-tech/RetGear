-- Waypath+ profession data: Alchemy. Horde route from the wow-professions.com WoW
-- Forever guide (beta data; 225-300 not yet tested on Forever). In Forever, Healing
-- Potions moved to First Aid.
local _, RG = ...
local A = { name = "Alchemy", kind = "craft", icon = "Interface\\Icons\\Trade_Alchemy" }
A.source = "wow-professions.com WoW Forever guide (Classic route past 225)"
A.train = {
  start = { O = "a capital trainer: Yelmak in Orgrimmar", R = "a capital trainer: Yelmak in Orgrimmar", T = "Bena Winterhoof in Thunder Bluff", U = "Doctor Marsh in Undercity", S = "a Zephras Isle trainer, or any capital" },
  apprentice = "Yelmak (Orgrimmar), Doctor Marsh (Undercity), Bena Winterhoof (Thunder Bluff)",
  journeyman = "Yelmak (Orgrimmar), Doctor Marsh (Undercity), Bena Winterhoof (Thunder Bluff)",
  expert = "Doctor Herbert Halsey (Undercity)",
  artisan = "Rogvar (Stonard, Swamp of Sorrows)",
}
A.supplies = "Empty, Leaded and Crystal Vials: Alchemy and Trade Supply vendors (not in the shopping counts)."
A.plan = {
  { from = 1,   to = 10,  craft = "Minor Arcane Elixir", n = 9, mats = "1 Peacebloom, 1 Empty Vial each (or Elixir of Minor Force: 1 Silverleaf)" },
  { from = 10,  to = 55,  craft = "Elixir of Minor Defense", n = 45, mats = "1 Silverleaf, 1 Peacebloom, 1 Empty Vial each" },
  { from = 50,  to = 50,  train = "Journeyman (skill 50, level 10)" },
  { from = 55,  to = 65,  craft = "Minor Mana Potion", n = 10, mats = "1 Mageroyal, 1 Peacebloom, 1 Empty Vial each" },
  { from = 65,  to = 90,  craft = "Elixir of Minor Fortitude", n = 27, mats = "2 Earthroot, 1 Peacebloom, 1 Empty Vial each" },
  { from = 90,  to = 120, craft = "Elixir of Wisdom", n = 30, mats = "1 Mageroyal, 2 Briarthorn, 1 Empty Vial each (tailors use them later)" },
  { from = 120, to = 130, craft = "Lesser Mana Potion", n = 10, mats = "1 Mageroyal, 1 Stranglekelp, 1 Empty Vial each" },
  { from = 125, to = 125, train = "Expert (skill 125, level 20, 50 silver)" },
  { from = 130, to = 150, craft = "Fire Oil", n = 20, mats = "2 Firefin Snapper, 1 Empty Vial each (keep 30 oils; or Lesser Mana Potion)" },
  { from = 150, to = 165, craft = "Elixir of Fire Power", n = 15, mats = "2 Fire Oil, 1 Kingsblood, 1 Leaded Vial each" },
  { from = 165, to = 195, craft = "Mana Potion", n = 36, mats = "1 Stranglekelp, 1 Kingsblood, 1 Leaded Vial each" },
  { from = 195, to = 225, craft = "Nature Protection Potion", n = 36, mats = "1 Liferoot, 1 Stranglekelp, 1 Leaded Vial each (recipe: Bronk in Feralas)" },
  { from = 200, to = 200, train = "Artisan (skill 200, level 35)" },
  { from = 225, to = 230, craft = "Nature Protection Potion", n = 12, mats = "1 Liferoot, 1 Stranglekelp, 1 Leaded Vial each" },
  { from = 230, to = 265, craft = "Draught of Detect Undead", n = 45, mats = "1 Arthas' Tears, 1 Crystal Vial each" },
  { from = 265, to = 290, craft = "Superior Mana Potion", n = 30, mats = "2 Sungrass, 2 Blindweed, 1 Crystal Vial each (recipe: Algernon, Undercity)" },
  { from = 290, to = 300, craft = "Major Frenzy Potion", n = 17, mats = "3 Plaguebloom, 2 Blindweed, 1 Imbued Vial each (Apothecary Durelle, Merchant's Favor, outside the Crossroads)" },
}
A.mats = { 2447, 765, 785, 2449, 2450, 3820, 3356, 3357, 8836, 8838, 8839, 13466 }
RG.RegisterProfession("Alchemy", A)
