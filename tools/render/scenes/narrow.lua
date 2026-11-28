-- The main window dragged down to its smallest size (640 x 480) and to a tall narrow one, every page:
--   lua5.1 tools/harness/run.lua --shoot tools/render/scenes/narrow.lua --out DIR
return function(T)
  local RG, G = T.RG, T.G
  T.slash("/wp"); T.step(1)
  if G.WaypathSetup then G.WaypathSetup:Hide() end
  local f = G.WaypathFrame
  local only = os.getenv("WP_SIZES")
  local sizes = { { 640, 480 }, { 760, 900 } }
  if only then sizes = {}; for w, h in only:gmatch("(%d+)x(%d+)") do sizes[#sizes + 1] = { tonumber(w), tonumber(h) } end end
  for _, sz in ipairs(sizes) do
    f:SetSize(sz[1], sz[2]); pcall(RG.FitMainWindow); if f.GetScript and f:GetScript("OnSizeChanged") then pcall(f:GetScript("OnSizeChanged"), f, sz[1], sz[2]) end; pcall(RG.UIRelayout); T.step(0.3)
    for _, tab in ipairs({ "route", "dungeons", "plan", "flights", "attune", "guide", "gear", "raid", "spec", "heal", "prof", "fish", "ah", "gold", "mail", "cards", "settings" }) do
      RG.UIState.tab = tab
      pcall(RG.RefreshUINow or RG.RefreshUI); T.step(0.3)
      T.shoot(("w%d-%s"):format(sz[1], tab))
    end
  end
end
