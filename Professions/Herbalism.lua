-- Waypath+ profession data: Herbalism. What to pick at each skill; the best zones
-- for each herb come from WoW Forever's spawn data (NodeData.lua). In Forever you
-- also need character level = the herb's skill / 5 to pick it.
local _, RG = ...
local H = { name = "Herbalism", kind = "gather", gathering = true, icon = "Interface\\Icons\\Trade_Herbalism" }
H.source = "WoW Forever herb spawn data"
H.train = {
  start = { O = "Jandi in Orgrimmar (closest to Durotar)", R = "Jandi in Orgrimmar (closest to Durotar)", T = "Komin Winterhoof in Thunder Bluff", U = "Martha Alliestar in Undercity", S = "the Zephras Isle Herbalism trainers" },
  apprentice = "Jandi (Orgrimmar), Martha Alliestar (Undercity), Komin Winterhoof (Thunder Bluff)",
  journeyman = "any Herbalism trainer (level 10)", expert = "any Herbalism trainer (level 20)", artisan = "any Herbalism trainer (level 35)",
}
H.supplies = "Nothing to buy: just learn Find Herbs and watch your minimap."
H.plan = {
  { from = 1,   to = 50,  gather = "Peacebloom", also = "Silverleaf" },
  { from = 50,  to = 70,  gather = "Mageroyal", also = "Earthroot" },
  { from = 70,  to = 100, gather = "Briarthorn", also = "Stranglekelp" },
  { from = 100, to = 125, gather = "Bruiseweed", also = "Wild Steelbloom" },
  { from = 125, to = 160, gather = "Kingsblood", also = "Liferoot" },
  { from = 160, to = 205, gather = "Goldthorn", also = "Khadgar's Whisker" },
  { from = 205, to = 230, gather = "Firebloom", also = "Purple Lotus" },
  { from = 230, to = 270, gather = "Sungrass", also = "Golden Sansam" },
  { from = 270, to = 300, gather = "Dreamfoil", also = "Mountain Silversage" },
}
H.mats = { 2447, 765, 2449, 785, 2450, 3820, 2453, 3355, 3369, 3356, 3357, 3818, 3821, 3358, 3819, 4625, 8831, 8836, 8838, 8839, 8845, 8846, 13464, 13463, 13465, 13466, 13467, 13468 }
RG.RegisterProfession("Herbalism", H)
