-- Every page of the cards window (the pages /wp textcheck goes through), one picture each:
--   lua5.1 tools/harness/run.lua --shoot tools/render/scenes/pages.lua --out DIR [--only collection,shop]
-- then python3 tools/render/render.py DIR
return function(T, opts)
  local RG, G = T.RG, T.G
  local u = RG.ArcadeUI
  -- a player with some cards, coins and a few of everything
  T.slash("/wp arcade"); T.step(1)
  if G.WaypathSetup then G.WaypathSetup:Hide() end   -- (the first-run chooser a fresh character gets)
  local frame = G.WaypathArcade
  if not frame then io.stdout:write("no card window\n") return end
  for i, c in ipairs(u.CARDS) do
    if i % 37 == 1 and i < 1500 then pcall(RG.ArcadeAddPull, c, (i % 5 == 1) and 3 or ((i % 7 == 1) and 2 or 1)) end
  end
  local a = G.WaypathDB.arcade
  if a then a.coins = 4200 end
  local v = RG.ArcadeView
  local want = {}
  for w in tostring(opts.only or ""):gmatch("[^,]+") do want[w] = true end
  local function reset() v.set = nil; v.showcase = false; v.shopSection = nil; v.gradeCert = nil; v.gradeLedger = nil; v.kind = 0; v.page = 1 end
  local steps = {}
  local function add(name, setup) steps[#steps + 1] = { name = name, setup = setup } end
  add("collection", function() reset(); v.mode = "cards" end)
  for k, nm in ipairs({ "items", "npcs", "places", "raiders" }) do add("collection-" .. nm, function() reset(); v.mode = "cards"; v.kind = k end) end
  add("showcase", function() reset(); v.mode = "cards"; v.showcase = true end)
  add("album", function() reset(); v.mode = "album"; v.albumPage = 1 end)
  add("sets", function() reset(); v.mode = "sets"; v.setPage = 0 end)
  add("shop", function() reset(); v.mode = "shop" end)
  for _, sec in ipairs({ "dungeon", "raid", "holiday", "grading", "reserve" }) do
    add("shop-" .. sec, function() reset(); v.mode = "shop"; v.shopSection = sec; v.shopPage = 0 end)
  end
  add("ledger-guild", function() reset(); v.mode = "shop"; v.shopSection = "grading"; v.gradeLedger = true end)
  add("today", function() reset(); v.mode = "today" end)
  add("feats", function() reset(); v.mode = "feats" end)
  add("trade", function() reset(); v.mode = "trade"; v.tradePage = 0 end)
  add("ledger", function() reset(); v.mode = "stats" end)
  for _, s in ipairs(steps) do
    if not next(want) or want[s.name] then
      local ok, err = pcall(s.setup)
      if not ok then io.stdout:write("setup " .. s.name .. ": " .. tostring(err) .. "\n") end
      pcall(RG.ArcadeRefresh, true); T.step(0.6)
      T.shoot("page-" .. s.name)
    end
  end
end
