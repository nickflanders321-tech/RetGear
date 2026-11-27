-- Waypath+ profession data: Mining. Where each ore is, for the Horde (zones) and the Alliance (zonesA), by
-- skill, ore and bar prices to track, and ore -> bar pairs for smelt-or-sell.
-- Vein spawn points for ore alerts are in NodeData.lua.
local _, RG = ...
local M = { name = "Mining", kind = "gather", gathering = true, icon = "Interface\\Icons\\Trade_Mining" }
M.source = "wow-professions.com's WoW Forever Mining guide (smelting) and WoW Forever ore spawn data"

-- Mining: where to find each ore on the Horde side, by skill.
M.zones = {
  { from = 1,   to = 64,  ore = "Copper",  zones = "Tirisfal Glades, Silverpine Forest, Durotar" },
  { from = 65,  to = 124, ore = "Tin (and Silver)", zones = "Silverpine Forest, Hillsbrad Foothills, The Barrens, Stonetalon Mountains" },
  { from = 125, to = 174, ore = "Iron (and Gold)", zones = "Arathi Highlands, Desolace, Thousand Needles, Stranglethorn Vale" },
  { from = 175, to = 244, ore = "Mithril (and Truesilver)", zones = "Badlands, The Hinterlands, Searing Gorge, Tanaris, Felwood" },
  { from = 245, to = 300, ore = "Thorium", zones = "Un'Goro Crater, Burning Steppes, Winterspring, Eastern Plaguelands, Silithus" },
}

-- The same, for the Alliance: the ore zones on the Alliance side (counted from WoW Forever's ore spawn data).
M.zonesA = {
  { from = 1,   to = 64,  ore = "Copper",  zones = "Elwynn Forest, Westfall, Dun Morogh, Loch Modan, Darkshore" },
  { from = 65,  to = 124, ore = "Tin (and Silver)", zones = "Westfall, Loch Modan, Duskwood, Redridge Mountains, Wetlands, Arathi Highlands" },
  { from = 125, to = 174, ore = "Iron (and Gold)", zones = "Arathi Highlands, Wetlands, Duskwood, Stranglethorn Vale, Desolace" },
  { from = 175, to = 244, ore = "Mithril (and Truesilver)", zones = "Badlands, The Hinterlands, Searing Gorge, Burning Steppes, Tanaris, Felwood" },
  { from = 245, to = 300, ore = "Thorium", zones = "Un'Goro Crater, Burning Steppes, Winterspring, Eastern Plaguelands, Silithus" },
}

-- Ore and bars whose Auction House prices are tracked.
M.mats = {
  2770, 2771, 2772, 3858, 10620, -- ores
  2840, 3576, 3575, 3860, 12359, -- bars
}

-- Ore -> bar pairs for the smelt-or-sell check.
M.smelt = {
  { ore = 2770, bar = 2840 },   -- Copper
  { ore = 2771, bar = 3576 },   -- Tin
  { ore = 2772, bar = 3575 },   -- Iron
  { ore = 3858, bar = 3860 },   -- Mithril
  { ore = 10620, bar = 12359 }, -- Thorium
}

-- Any Mining trainer teaches every rank (Journeyman at level 10, Expert 20, Artisan 35).
M.train = {
  start = { O = "Makaru in Orgrimmar (closest to Durotar)", R = "Makaru in Orgrimmar (closest to Durotar)", T = "Brek Stonehoof in Thunder Bluff", U = "Brom Killian in Undercity", S = "the Zephras Isle Mining trainers" },
  apprentice = "Makaru (Orgrimmar), Brom Killian (Undercity), Brek Stonehoof (Thunder Bluff)",
  journeyman = "any Mining trainer (level 10)", expert = "any Mining trainer (level 20)", artisan = "any Mining trainer (level 35)",
}

-- Alliance: the same trainers, in Stormwind, Ironforge, Darnassus and the starting zones (Profile.lua uses this one for Alliance characters).
M.trainA = {
  start = { H = "Gelman Stonehand in Stormwind", D = "Yarr Hammerstone in Dun Morogh", G = "Yarr Hammerstone in Dun Morogh", N = "Kurdram Stonehammer in Darkshore (Auberdine)", A = "Halavuul Cragwind on Zephras Isle" },
  apprentice = "Gelman Stonehand (Stormwind), Geofram Bouldertoe (Ironforge), Yarr Hammerstone (Dun Morogh), Kurdram Stonehammer (Auberdine)",
  journeyman = "any Mining trainer (level 10)", expert = "any Mining trainer (level 20)", artisan = "any Mining trainer (level 35)",
}
M.supplies = "Mining Pick: Trade Supplies vendors in every capital and most towns."
-- The plan (wow-professions.com's WoW Forever Mining guide, tools/sources/profguides/mining.txt): smelt to 120, mine 120-125,
-- smelt Iron to about 138, mine to 155, smelt Gold to 175, then mine (zones come from the spawn data in NodeData.lua).
-- Smelting needs a forge; the ore for it is what you mine on the way (140 Copper, 70 Tin, 43 Silver, 20 Iron, 25 Gold).
M.plan = {
  { from = 1,   to = 65,  craft = "Smelt Copper", n = 140, mats = "1 Copper Ore each, at a forge. Keep 70 Copper Bars for the Bronze at 75." },
  { from = 65,  to = 75,  craft = "Smelt Tin", n = 70, mats = "1 Tin Ore each. It turns grey at 75, but keep making all 70: the Bronze needs the bars." },
  { from = 75,  to = 105, craft = "Smelt Bronze", n = 70, mats = "1 Copper Bar, 1 Tin Bar each (you end up between 100 and 110)" },
  { from = 105, to = 120, craft = "Smelt Silver", n = 43, mats = "1 Silver Ore each. Check the Auction House price of Silver Ore and Silver Bar first: this part can get expensive." },
  { from = 120, to = 125, gather = "Tin Vein", also = "Silver Vein" },
  { from = 125, to = 138, craft = "Smelt Iron", n = 20, mats = "1 Iron Ore each (you reach about 138)" },
  { from = 138, to = 155, gather = "Iron Deposit", also = "Gold Vein" },
  { from = 155, to = 175, craft = "Smelt Gold", n = 25, mats = "1 Gold Ore each (you reach about 177)" },
  { from = 175, to = 245, gather = "Mithril Deposit", also = "Truesilver Deposit" },
  { from = 245, to = 300, gather = "Small Thorium Vein", also = "Rich Thorium Vein" },
}

RG.RegisterProfession("Mining", M)
