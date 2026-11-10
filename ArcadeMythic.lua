-- Waypath+ Arena: the Mythics, six chase cards above every other rarity. Hand-made (not generated): original
-- Waypath-themed subjects with their own painted art (Media/Arcade/Mythic*.tga, drawn by tools/arcade/art_mythic.py),
-- plus The 1 Ring, the game's own item (8350), which shows the item's icon from the player's game files.
-- They join the card list as tier 7 rows; their effects are in Battle.lua (MYTHIC), their look in Arcade.lua.
local _, RG = ...

-- { kind, name, tier, item id / creature type, collection text }
local ROWS = {
  { 2, "The Wanderer", 7, 7, "Mythic. Sixty levels. Every road, walked once." },
  { 3, "The First Waypoint", 7, 0, "Mythic. Follow the arrow." },
  { 3, "The Last Campfire", 7, 0, "Mythic. Camping 101, the final lesson." },
  { 3, "Sixty", 7, 0, "Mythic. The last level is the loudest." },
  { 1, "The Hourglass of Forever", 7, 0, "Mythic. The sand never runs out." },
  { 1, "The 1 Ring", 7, 8350, "Mythic. Plus one to everything." },
}
-- name -> art texture, collector number, the type line on the card, an icon from the game for small views,
-- a glow colour, and (the Ring) one per account with the opener's name engraved
RG.ARCADE_MYTHIC = {
  ["The Wanderer"]             = { art = "Mythic1", num = "M-01", type = "Raider  ·  Mythic",          icon = "Ability_Tracking",          glow = { 0.71, 0.55, 1 } },
  ["The First Waypoint"]       = { art = "Mythic2", num = "M-02", type = "Place  ·  Spell  ·  Mythic", icon = "INV_Misc_Map_01",            glow = { 1, 0.82, 0.4 } },
  ["The Last Campfire"]        = { art = "Mythic3", num = "M-03", type = "Camp  ·  Mythic",            icon = "Spell_Fire_Fire",            glow = { 1, 0.48, 0.24 } },
  ["Sixty"]                    = { art = "Mythic4", num = "M-04", type = "Spell  ·  Mythic",           icon = "Spell_Holy_HolyBolt",        glow = { 1, 0.86, 0.45 } },
  ["The Hourglass of Forever"] = { art = "Mythic5", num = "M-05", type = "Artifact  ·  Spell  ·  Mythic", icon = "INV_Misc_PocketWatch_01", glow = { 1, 0.9, 0.6 } },
  ["The 1 Ring"]               = { art = "Mythic6", num = "M-00", type = "Item  ·  Spell  ·  Mythic",  one = true, itemIcon = true,          glow = { 0.47, 1, 0.35 } },
}
RG.ARCADE_MYTHIC_ORDER = {}
RG.ARCADE_DATA = RG.ARCADE_DATA or {}
for _, r in ipairs(ROWS) do
  RG.ARCADE_DATA[#RG.ARCADE_DATA + 1] = r
  RG.ARCADE_MYTHIC_ORDER[#RG.ARCADE_MYTHIC_ORDER + 1] = r[2]
end
