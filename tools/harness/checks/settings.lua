-- The settings page (UI.lua): categories down the left, switches, choices, swatches, sliders and the route style cards;
-- and the tracker's route block at the top.
local function clean(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end
-- a visible button whose label (field `field`) reads `text`
local function button(T, field, text)
  for _, f in ipairs(T.W.frames()) do
    local fs = rawget(f, field)
    if fs and type(fs) == "table" and fs.GetText and f.IsVisible and f:IsVisible() and clean(fs:GetText()) == text then return f end
  end
end
local function click(f) local fn = f:GetScript("OnClick"); if fn then fn(f, "LeftButton") end end
local function page(T) return clean(table.concat(T.W.visibleTexts(T.W.G.WaypathFrame), "\n")) end
local function openSettings(T, cat)
  T.RG.ShowTab("settings"); T.step(1)
  if cat then
    local b = button(T, "text", cat)
    T.ok(b, "the category " .. cat .. " is in the list on the left")
    if b then click(b); T.step(1) end
  end
end

return {
  {
    name = "settings-every-category",
    about = "every settings category opens and shows its settings; every option is on some page",
    race = "Orc", class = "WARRIOR", level = 10,
    run = function(T)
      openSettings(T)
      local seen = {}
      for _, c in ipairs(T.RG.SETTING_CATS) do
        local b = button(T, "text", c[2])
        T.ok(b, "category " .. c[2] .. " is listed")
        if b then
          click(b); T.step(1)
          local txt = page(T)
          T.ok(not txt:find("This page hit an error", 1, true), c[2] .. " draws without an error")
          T.ok(#txt > 40, c[2] .. " shows something")
          for _, k in ipairs(c[3]) do seen[k] = true end
        end
      end
      T.ok(page(T):find("Run setup again", 1, true), "This character has the actions")
      -- the search looks through every category
      local fr = T.W.G.WaypathFrame
      openSettings(T, "Look")
      fr.search:SetText("fishing hud"); T.RG.UIState.search = "fishing hud"; T.RG.RefreshUINow(); T.step(1)
      T.ok(page(T):find("Fishing HUD", 1, true), "searching \"fishing hud\" finds it from another category")
      fr.search:SetText(""); T.RG.UIState.search = ""; T.RG.RefreshUINow(); T.step(1)
    end,
  },
  {
    name = "settings-controls",
    about = "a switch turns its option off, a choice and a swatch are picked by clicking them, a slider sets its value",
    race = "Orc", class = "WARRIOR", level = 10,
    run = function(T)
      local RG = T.RG
      -- accent: click a swatch, it's that colour (no cycling)
      openSettings(T, "Look")
      local mint = button(T, "t", "Mint")
      T.ok(mint, "there's a Mint swatch")
      if mint then click(mint); T.step(1) end
      T.eq(RG.db.accent, "mint", "clicking Mint picks Mint")
      local rose = button(T, "t", "Rose")
      if rose then click(rose); T.step(1) end
      T.eq(RG.db.accent, "rose", "clicking Rose picks Rose")
      -- the tracker size slider
      local sl
      for _, f in ipairs(T.W.frames()) do local sp = rawget(f, "spec"); if sp and sp.name == "Tracker size" and f:IsVisible() then sl = f end end
      T.ok(sl, "there's a Tracker size slider")
      if sl then
        sl:SetValue(120); local fn = sl:GetScript("OnValueChanged"); if fn then fn(sl, 120, true) end; T.step(1)
        T.ok(math.abs((RG.db.trackerScale or 1) - 1.2) < 0.001, "the slider sets the tracker to 120% (" .. tostring(RG.db.trackerScale) .. ")")
      end
      -- a segmented choice
      openSettings(T, "Tracker")
      local fold = button(T, "t", "Fold up")
      local fade = button(T, "t", "Fade")
      T.ok(fade and fold, "In a fight offers Fade and Fold up")
      if fade then click(fade); T.step(1) end
      T.ok(RG.Opt("trackerFade") and not RG.Opt("trackerCombatFold"), "picking Fade fades, and doesn't fold")
      local every = button(T, "t", "Everything")
      if every then click(every); T.step(1) end
      T.ok(not RG.Opt("compactTracker"), "picking Everything turns the short tracker off")
      -- a switch: Lock in place
      local row
      for _, f in ipairs(T.W.frames()) do local t = rawget(f, "title"); if t and f:IsVisible() and rawget(f, "onClick") and clean(t:GetText()) == "Lock in place" then row = f end end
      T.ok(row, "there's a Lock in place switch")
      local before = RG.Opt("trackerLocked")
      if row then row.onClick(row); T.step(1) end
      T.ok(RG.Opt("trackerLocked") ~= before, "clicking it flips it")
      -- route style cards
      RG.db.routeGuide = true
      openSettings(T, "Route & quests")
      T.ok(page(T):find("Stay in this zone", 1, true), "the route styles are explained")
      local stay = button(T, "t", "Stay in this zone")
      if stay then click(stay); T.step(1) end
      T.eq(RG.db.routeStyle, "zone", "clicking Stay in this zone picks it")
      local guided = button(T, "t", "Guided")
      if guided then click(guided); T.step(1) end
      T.eq(RG.db.routeStyle, "guided", "clicking Guided picks it")
      T.ok(RG.db.smart == false, "and the smart route is off")
    end,
  },
  {
    name = "tracker-route-on-top",
    about = "with the leveling route on, the route's step is above your quests, with the next steps; turned off, it's below them",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      RG.db.routeGuide = true; RG.db.trackerMore = true
      T.accept(4641)   -- Your Place In The World
      T.step(2)
      local function where()
        local route, quests
        for i, t in ipairs(T.tracker()) do
          local l = clean(t):lower()
          if not route and l:find("route:", 1, true) then route = i end
          if not quests and l:find("^%-?%s*quests") then quests = i end
        end
        return route, quests
      end
      local route, quests = where()
      T.ok(route and quests and route < quests, "the route is above the quests (route at " .. tostring(route) .. ", quests at " .. tostring(quests) .. "): " .. table.concat(T.tracker(), " | "))
      T.ok(T.trackerFind("Next"), "and says what's next")
      RG.db.trackerRouteTop = false; RG.RefreshTracker(); T.step(2)
      route, quests = where()
      T.ok(route and quests and route > quests, "turned off, the route is under the quests (route at " .. tostring(route) .. ", quests at " .. tostring(quests) .. ")")
    end,
  },
}
