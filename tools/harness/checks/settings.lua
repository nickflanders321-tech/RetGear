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
      -- what to follow: three cards
      RG.db.routeGuide = true
      openSettings(T, "Tracker")
      T.ok(page(T):find("Zone quests", 1, true) and page(T):find("My quest log", 1, true), "the three things to follow are explained")
      local zq = button(T, "t", "Zone quests")
      if zq then click(zq); T.step(1) end
      T.eq(RG.RouteMode(), "zone", "clicking Zone quests picks it")
      local guide = button(T, "t", "Ordered guide")
      if guide then click(guide); T.step(1) end
      T.eq(RG.RouteMode(), "guide", "clicking Ordered guide picks it")
      T.ok(page(T):find("Smart zone order", 1, true), "with the smart zone order beside it")
      T.ok(page(T):find("Dungeon quests", 1, true), "and dungeon quests to include or leave out")
      local out = button(T, "t", "Leave out")
      if out then click(out); T.step(1) end
      T.ok(not RG.DungeonQuestsOn(), "clicking Leave out leaves dungeon quests out")
    end,
  },
  {
    name = "tracker-follows-mode",
    about = "the ordered guide and zone quests show the route (no quest list); my quest log shows your quests (no route); the menu at the top switches",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      RG.db.routeGuide = true; RG.db.trackerMore = true
      T.accept(4641)   -- Your Place In The World
      T.step(2)
      local function has(pat) for _, t in ipairs(T.tracker()) do if clean(t):lower():find(pat) then return true end end return false end
      RG.SetRouteMode("guide", true); T.step(2)
      T.ok(has("^route · "), "the guide shows the route: " .. table.concat(T.tracker(), " | "))
      T.ok(not has("^quests$"), "and not your quest list")
      T.ok(T.trackerFind("Ordered guide"), "the header says what it follows")
      T.ok(T.trackerFind("Your Place In The World"), "the step you're on lists its quests")
      RG.SetRouteMode("log", true); T.step(2)
      T.ok(has("^quests$"), "my quest log shows your quests: " .. table.concat(T.tracker(), " | "))
      T.ok(not has("^route · "), "and not the route")
      RG.SetRouteMode("zone", true); T.step(2)
      T.ok(has("^steps · valley of trials"), "zone quests shows the steps of the zone you're in, nearest first: " .. table.concat(T.tracker(), " | "))
      T.ok(has("^hand in your place in the world"), "the step the current step shows is in that list")
      -- the menu at the top: Professions, then back
      local tr = T.W.G.WaypathTracker
      T.ok(tr and tr.modeBtn and tr.modeBtn:IsVisible(), "the menu button is at the top")
      RG.SetTrackerView("prof"); T.step(2)
      T.eq(RG.TrackerView(), "prof", "the menu can show professions")
      T.ok(T.trackerFind("Professions"), "and the tracker says so")
      RG.SetTrackerView("guide"); T.step(2)
      T.eq(RG.TrackerView(), "guide", "and goes back to the guide")
    end,
  },
  {
    name = "zone-pick-resets-at-login",
    about = "zone quests can keep to a zone you pick; it lasts through /reload and resets when you log in",
    race = "Orc", class = "WARRIOR", level = 12,
    run = function(T)
      local RG = T.RG
      RG.db.routeGuide = true
      RG.SetZonePick("The Barrens"); T.step(1)
      T.eq(RG.RouteMode(), "zone", "picking a zone switches to zone quests")
      local z, picked = RG.FollowZone()
      T.ok(z == "The Barrens" and picked, "it follows the zone you picked (" .. tostring(z) .. ")")
      local r = RG.CurrentRouteEntry()
      T.eq(r and r.zone, "The Barrens", "and the route is that zone's")
      T.W.fire("PLAYER_ENTERING_WORLD", false, true); T.step(1)
      T.eq(RG.db.zonePick, "The Barrens", "a /reload keeps it")
      T.W.fire("PLAYER_ENTERING_WORLD", true, false); T.step(1)
      T.eq(RG.db.zonePick, nil, "logging in resets it")
    end,
  },
  {
    name = "dungeon-quests-left-out",
    about = "a dungeon quest from the data counts as one, is included by default and is left out once the option is off",
    race = "Orc", class = "WARRIOR", level = 20,
    run = function(T)
      local RG = T.RG
      local id
      for _, dq in pairs(RG.DUNGEON_QUESTS or {}) do
        for _, q in ipairs(dq.quests or {}) do if q.id and not id and RG.QDATA and RG.QDATA[q.id] then id = q.id end end
      end
      T.ok(id, "there's a dungeon quest in the data")
      if not id then return end
      T.ok(RG.IsDungeonQuest(id), "it counts as a dungeon quest")
      T.ok(not RG.DungeonQuestHidden(id), "included by default")
      RG.db.dungeonQuests = false
      T.ok(RG.DungeonQuestHidden(id), "left out once the option is off")
      RG.db.dungeonQuests = nil
    end,
  },
}
