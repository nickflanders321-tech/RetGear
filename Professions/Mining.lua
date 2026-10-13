-- Waypath+ profession data: Mining. Where each ore is on the Horde side by
-- skill, ore and bar prices to track, and ore -> bar pairs for smelt-or-sell.
-- Vein spawn points for ore alerts are in NodeData.lua.
local _, RG = ...
local M = { name = "Mining", gathering = true }

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

RG.RegisterProfession("Mining", M)
