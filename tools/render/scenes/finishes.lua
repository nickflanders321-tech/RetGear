-- One card of every tier in every finish (plain, holo, full art, gilded) on its big view and as a small card in the collection:
--   lua5.1 tools/harness/run.lua --shoot tools/render/scenes/finishes.lua --out DIR
return function(T, opts)
  local RG, G = T.RG, T.G
  local u = RG.ArcadeUI
  T.slash("/wp arcade"); T.step(1)
  if G.WaypathSetup then G.WaypathSetup:Hide() end
  local byTier = {}
  for _, c in ipairs(u.CARDS) do
    local t = c.tier
    if t and not byTier[t] and c.name and #c.name < 26 then byTier[t] = c end
  end
  for t = 1, 7 do
    local c = byTier[t]
    if c then
      for fin = 1, 4 do
        local g = RG.ArcadeAddPull(c, fin)
        RG.ArcadeOpenDetail(c); T.step(0.6)
        T.shoot(string.format("tier%d-fin%d", t, fin))
        if G.WaypathArcadeCard then G.WaypathArcadeCard:Hide() end
      end
    end
  end
  io.stdout:write("tiers: ")
  for t = 1, 7 do io.stdout:write(t .. "=" .. (byTier[t] and byTier[t].name or "none") .. " ") end
  io.stdout:write("\n")
end
