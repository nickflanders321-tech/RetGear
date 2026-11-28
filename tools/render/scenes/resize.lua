-- Every window of the add-on on a client of any size (WP_SCREEN=1280x720): each Journey/Gear/Professions page and the
-- card window's pages, one picture each, and a line for every window that sticks out past the screen edge:
--   WP_SCREEN=1280x720 lua5.1 tools/harness/run.lua --shoot tools/render/scenes/resize.lua --out DIR
return function(T)
  local RG, G = T.RG, T.G
  local SW, SH = G.GetScreenWidth(), G.GetScreenHeight()
  local function over(tag)
    for _, f in ipairs(T.windows()) do
      local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
      local sc = f:GetEffectiveScale() / (G.UIParent:GetEffectiveScale() or 1)
      if l and r and t and b then
        l, r, t, b = l * sc, r * sc, t * sc, b * sc
        local name = f:GetName() or "?"
        local out = {}
        if l < -1 then out[#out + 1] = "left " .. math.floor(-l) end
        if b < -1 then out[#out + 1] = "bottom " .. math.floor(-b) end
        if r > SW + 1 then out[#out + 1] = "right " .. math.floor(r - SW) end
        if t > SH + 1 then out[#out + 1] = "top " .. math.floor(t - SH) end
        if #out > 0 and (name:find("Waypath") or name:find("Arcade")) then
          io.stdout:write(("OVERFLOW %dx%d %s %s: %s px (size %dx%d)\n"):format(SW, SH, tag, name, table.concat(out, ", "), (r - l), (t - b)))
        end
      end
    end
  end
  T.slash("/wp"); T.step(1)
  if G.WaypathSetup then G.WaypathSetup:Hide() end
  local ui = RG.UIState
  for _, tab in ipairs({ "route", "dungeons", "plan", "flights", "attune", "guide", "gear", "raid", "spec", "heal", "prof", "fish", "ah", "gold", "mail", "cards", "settings" }) do
    ui.tab = tab
    pcall(RG.RefreshUI); T.step(0.4)
    over("tab-" .. tab)
    T.shoot("tab-" .. tab)
  end
  T.hideAll()
  T.slash("/wp arcade"); T.step(1.5)
  local v = RG.ArcadeView
  local u = RG.ArcadeUI
  for _, c in ipairs(u and u.CARDS or {}) do if _ % 37 == 1 and _ < 1500 then pcall(RG.ArcadeAddPull, c, 1) end end
  if G.WaypathDB.arcade then G.WaypathDB.arcade.coins = 4200 end
  local pages = { { "cards", nil }, { "album" }, { "sets" }, { "shop" }, { "today" }, { "feats" }, { "trade" }, { "stats" } }
  for _, pg in ipairs(pages) do
    v.set = nil; v.showcase = false; v.shopSection = nil; v.kind = 0; v.page = 1; v.mode = pg[1]
    pcall(RG.ArcadeRefresh, true); T.step(0.5)
    over("cards-" .. pg[1])
    T.shoot("cards-" .. pg[1])
  end
  T.hideAll()
  T.slash("/wp"); T.step(0.5)
  T.shoot("tracker")
end
