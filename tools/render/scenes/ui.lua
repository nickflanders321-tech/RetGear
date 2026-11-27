-- The add-on's screens, one shot each, for checking the look after a change (tools/render/ui.sh compares them with
-- the last accepted set):
--   tracker-<view>   the tracker in each of its views (ordered guide, zone quests, my quest log, professions,
--                    preobtain dungeon quests), with the main window closed
--   tracker-menu     the tracker's view menu, open
--   main-<page>      every page of the main window (Journey, Gear, Professions, Cards, Settings)
-- The first-time setup is done first, as a player who has picked "Full guide" sees it.
--
--   lua5.1 tools/harness/run.lua --shoot tools/render/scenes/ui.lua --out DIR [--race Orc --class WARRIOR]
--   ... --play --until-level 20     the leveling bot plays the route to level 20 first (quests in the log, a
--                                   character part way through), in the simulated world
return function(T, opts)
  local RG, G, W = T.RG, T.G, T.W

  -- the first-time setup: done, "Full guide" (the wizard is closed wherever it opened)
  if RG.db then RG.db.setupDone, RG.db.welcomed = true, true end
  local wiz = T.findText("Waypath+ Setup")
  while wiz and wiz:GetParent() and wiz:GetParent() ~= G.UIParent do wiz = wiz:GetParent() end
  if wiz then wiz:Hide() end
  T.step(1)

  -- part way through the route: the bot plays it (needs --play, which builds the simulated world)
  if opts.play and opts.until_level then
    local P, Wd = require("play"), require("world")
    local R = P.run(W, Wd, RG, { until_level = opts.until_level, max_actions = opts.max_actions })
    io.stdout:write(string.format("played to level %d (%d actions)\n", W.me.level, R and R.actions or 0))
    if RG.db then RG.db.setupDone, RG.db.welcomed = true, true end
    T.step(2)
  end

  local function closeMenus()
    for _, name in ipairs({ "WaypathMenu", "WaypathDropDown" }) do if G[name] and G[name].Hide then G[name]:Hide() end end
  end

  -- the tracker in each view, alone on screen
  local main = G.WaypathFrame or G.WaypathUI
  local view0 = RG.TrackerView and RG.TrackerView()
  for _, v in ipairs({ "guide", "zone", "log", "prof", "dungeon" }) do
    if RG.SetTrackerView then
      RG.SetTrackerView(v)
      if main and main.Hide then main:Hide() end
      T.step(1.5)
      T.shoot("tracker-" .. v)
    end
  end
  if RG.SetTrackerView and view0 then RG.SetTrackerView(view0) end
  T.step(1)

  -- its view menu, open (from the header's title)
  if RG.TrackerModeMenu then
    local title = T.findText("Ordered guide") or T.findText("Zone quests") or T.findText("My quest log")
    RG.TrackerModeMenu(title)
    T.step(0.5)
    T.shoot("tracker-menu")
    closeMenus()
    T.hideAll()
    T.step(0.5)
  end

  -- every page of the main window
  for _, page in ipairs({ "route", "dungeons", "plan", "flights", "guide", "gear", "raid", "spec", "heal",
                          "prof", "fish", "ah", "gold", "mail", "cards", "settings" }) do
    if RG.ShowTab then
      RG.ShowTab(page)
      T.step(1)
      T.shoot("main-" .. page)
    end
  end
end
