-- Waypath+ profession data: Mining. Where each ore is on the Horde side by
-- skill, ore and bar prices to track, and ore -> bar pairs for smelt-or-sell.
-- Vein spawn points for ore alerts are in NodeData.lua.
local _, RG = ...
local M = { name = "Mining", kind = "gather", gathering = true, icon = "Interface\\Icons\\Trade_Mining" }
M.source = "WoW Forever ore spawn data"

-- Mining: where to find each ore on the Horde side, by skill.
M.zones = {
  { from = 1,   to = 64,  ore = "Copper",  zones = "Tirisfal Glades, Silverpine Forest, Durotar" },
  { from = 65,  to = 124, ore = "Tin (and Silver)", zones = "Silverpine Forest, Hillsbrad Foothills, The Barrens, Stonetalon Mountains" },
  { from = 125, to = 174, ore = "Iron (and Gold)", zones = "Arathi Highlands, Desolace, Thousand Needles, Stranglethorn Vale" },
  { from = 175, to = 244, ore = "Mithril (and Truesilver)", zones = "Badlands, The Hinterlands, Searing Gorge, Tanaris, Felwood" },
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
M.supplies = "Mining Pick: Trade Supplies vendors in every capital and most towns."
-- Gathering plan: what to mine at each skill (zones come from the spawn data in NodeData.lua).
M.plan = {
  { from = 1,   to = 65,  gather = "Copper Vein" },
  { from = 65,  to = 125, gather = "Tin Vein", also = "Silver Vein" },
  { from = 125, to = 175, gather = "Iron Deposit", also = "Gold Vein" },
  { from = 175, to = 245, gather = "Mithril Deposit", also = "Truesilver Deposit" },
  { from = 245, to = 300, gather = "Small Thorium Vein", also = "Rich Thorium Vein" },
}

RG.RegisterProfession("Mining", M)
