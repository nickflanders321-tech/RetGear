-- The Ledger's Guild board with a few made-up guildmates (all three boards):
--   lua5.1 tools/harness/run.lua --shoot tools/render/scenes/guildboard.lua --out DIR
return function(T)
  local RG, G = T.RG, T.G
  G.IsInGuild = function() return true end
  G.GetGuildInfo = function() return "Roadwardens" end
  T.slash("/wp arcade"); T.step(1)
  if G.WaypathSetup then G.WaypathSetup:Hide() end
  local a = G.WaypathDB.arcade
  local wk = RG.ArcadeWeekKey()
  a.guildBoard = { guild = "Roadwardens", who = {
    Brannoch = { wk = wk, packs = 42, best = 10, gems = 3, done = 19, gold = 4, own = 1210, total = 2387, t = os.time() },
    Telwyn = { wk = wk, packs = 17, best = 9, gems = 0, done = 31, gold = 9, own = 1710, total = 2387, t = os.time() },
    Orrik = { wk = "2000-01-04", packs = 80, best = 7, gems = 0, done = 5, gold = 0, own = 300, total = 2387, t = os.time() },
    Siv = { wk = wk, packs = 6, best = 8, gems = 0, done = 12, gold = 1, own = 900, total = 2387, t = os.time() },
  } }
  a.wk = { k = wk, n = 23 }
  local v = RG.ArcadeView
  v.mode = "stats"; v.statsSub = "guild"
  for _, b in ipairs({ "packs", "grade", "sets" }) do
    v.guildBoard = b
    pcall(RG.ArcadeRefresh, true); T.step(0.4)
    T.shoot("guild-" .. b)
  end
end
