-- The current step (StepView.lua: the card under the tracker's header, with its details) and drop rates in the
-- tracker's tooltips.
local function texts(T, frame)
  local out = {}
  for _, t in ipairs(T.W.visibleTexts(frame)) do out[#out + 1] = (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end
  return table.concat(out, "\n")
end

return {
  {
    name = "drop-rates-known",
    about = "a quest's item drop rates come from the quest data (Gnoll Paw from the Riverpaw gnolls)",
    race = "Human", class = "MAGE", level = 12,
    run = function(T)
      local info = T.RG.DropInfo(102)   -- Patrolling Westfall: Gnoll Paws
      T.ok(#info > 0, "Patrolling Westfall has drop rates")
      local x = info[1]
      T.ok(x and x.item == "Gnoll Paw" and x.text:find("%d+%%") and x.text:find("Riverpaw", 1, true), "Gnoll Paw: " .. tostring(x and x.text))
      T.ok(T.RG.DropTip(102):find("Drops:", 1, true), "the tooltip section says so")
      T.eq(#T.RG.DropInfo(102, "Gnoll Paw"), 1, "asked for one objective by name, it's that one")
      local st = T.RG.DropInfo(832)   -- Burning Shadows: starts from Eye of Burning Shadow (Gazz'uz, always)
      T.eq(#st, 0, "a Human isn't told about a Horde quest's item")
    end,
  },
  {
    name = "item-start-drop-rate",
    about = "a quest that starts from an item says how often that item drops",
    race = "Orc", class = "WARRIOR", level = 12,
    run = function(T)
      local info = T.RG.DropInfo(832)   -- Burning Shadows: Eye of Burning Shadow, 100% from Gazz'uz
      local x = info[1]
      T.ok(x and x.starts and x.text:find("100%", 1, true) and x.text:find("Gazz'uz", 1, true), "Eye of Burning Shadow: " .. tostring(x and x.text))
    end,
  },
  {
    name = "step-view-shows-step",
    about = "the current step explains the quest you're doing, how often its item drops and what to look for",
    race = "Human", class = "MAGE", level = 12,
    run = function(T)
      T.RG.SetRouteMode("log", true)   -- (the card follows your quest log here, not a route step)
      local ok = T.accept(102)   -- Patrolling Westfall
      T.ok(ok, "Patrolling Westfall accepted")
      T.go(T.Wd.objectiveSpot(102))   -- out among the gnolls
      T.RG.Objective(true); T.RG.RefreshStepView(); T.step(1)
      local f = T.W.G.WaypathStepView
      T.ok(f and f:IsShown(), "the current step is on screen")
      T.ok(f and f:GetParent() == T.W.G.WaypathTracker, "it's part of the tracker, not a window of its own")
      if not (f and f:IsShown()) then return end
      local all = texts(T, f)
      T.ok(all:find("Patrolling Westfall", 1, true), "it names the quest")
      T.ok(all:find("Gnoll Paw", 1, true), "and the item to collect")
      T.ok(all:find("Drops from [^\n]- · %d+%%"), "and how often it drops (\"Drops from <mob> · <rate>\")")
      T.ok(f.pic and f.pic:IsShown(), "with a picture of what to look for")
      T.ok(all:find("Bring back %d+ Gnoll Paw for Patrolling Westfall"), "and how to do it, in the quest log's words")
      T.ok(not (all:find("Zone quests:", 1, true) or all:find("The guide:", 1, true) or all:find("My quest log", 1, true) or all:find("You picked it", 1, true)),
        "not what the header already says")
      -- a quest you picked yourself: the card still says how to do it, not that you picked it
      T.RG.ArrowTo(T.Wd.objectiveSpot(102)); T.RG.Objective(true); T.RG.RefreshStepView(); T.step(1)
      local picked = texts(T, f)
      T.ok(picked:find("Bring back", 1, true) and not picked:find("You picked it", 1, true), "picked yourself: still how to do it")
      T.RG.PickManually(nil)
      -- the distance shows once (in the header)
      local _, n = all:gsub("%d+ yd", "")
      T.eq(n, 1, "the distance is shown once")
      -- the tracker folded: the step stays, its picture and drop rates fold away
      T.RG.db.trackerCollapsed = true; T.RG.RefreshTracker(); T.step(1)
      T.ok(f:IsShown(), "with the tracker folded, the current step is still there")
      T.ok(not f.pic:IsShown(), "without its picture")
      T.ok(not texts(T, f):find("Drops from"), "or its drop rates")
      T.RG.db.trackerCollapsed = nil
    end,
  },
  {
    name = "step-view-every-objective",
    about = "a quest with several objectives shows each one with its own progress, and how each one's item drops",
    race = "Human", class = "MAGE", level = 12,
    run = function(T)
      T.RG.SetRouteMode("log", true)
      T.Wd.state.done[36] = true   -- (Westfall Stew needs quest 36 first)
      local ok, why = T.accept(38)   -- Westfall Stew: Stringy Vulture Meat, Murloc Eye, Goretusk Snout, Okra
      T.ok(ok, "Westfall Stew accepted (" .. tostring(why) .. ")")
      T.go(T.Wd.objectiveSpot(38))
      T.RG.Objective(true); T.RG.RefreshStepView(); T.step(1)
      local f = T.W.G.WaypathStepView
      T.ok(f and f:IsShown(), "the current step is on screen")
      if not (f and f:IsShown()) then return end
      local all = texts(T, f)
      local n = 0
      for _, item in ipairs({ "Stringy Vulture Meat", "Murloc Eye", "Goretusk Snout" }) do
        if all:find(item, 1, true) then n = n + 1 end
      end
      T.eq(n, 3, "every objective is on the card")
      local _, progs = all:gsub("\n%d+/%d+", "")
      T.ok(progs >= 3, "each with its own progress (" .. progs .. " counts)")
      local _, drops = all:gsub("Drops from", "")
      T.ok(drops >= 2, "and a drop line for each item still to collect (" .. drops .. ")")
    end,
  },
  {
    name = "guide-card-is-the-step",
    about = "the ordered guide: the current step is always one of the quests of the step the route highlights, even with a closer quest of another step in your log",
    race = "Human", class = "MAGE", level = 12,
    run = function(T)
      local RG = T.RG
      RG.SetRouteMode("guide", true)
      T.accept(102)   -- Patrolling Westfall: in your log, its gnolls right here
      T.go(T.Wd.objectiveSpot(102))
      RG.ForgetNextStep(); local obj = RG.Objective(true); T.step(1)
      local r = RG.CurrentRouteEntry()
      local cur = r and RG.NextStep(r)
      T.ok(cur, "the route has a step you're on")
      if not (obj and cur) then return end
      local ids = {}
      for _, l in ipairs(RG.StepQuestLines(r, cur) or {}) do ids[l.id] = true end
      local onStep = (obj.id and ids[obj.id]) or (obj.kind == "route" and obj.key:find("#" .. cur .. "$"))
      T.ok(onStep, "the current step (" .. tostring(obj.qtitle or obj.text) .. ") belongs to the highlighted step " .. cur)
    end,
  },
  {
    name = "guide-skip-always-moves-on",
    about = "the ordered guide: Skip always moves the current step on, even when the stop is all that's left of the route step (then the route step is skipped, and /wp undo brings it back)",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      RG.SetRouteMode("guide", true)
      T.step(2)
      local moved = 0
      for i = 1, 4 do
        RG.ForgetNextStep()
        local before = RG.Objective(true)
        if not before then break end
        RG.StepViewSkip(); T.step(1)
        local after = RG.Objective(true)
        if T.ok(not after or after.key ~= before.key, "skip " .. i .. " moves on from " .. tostring(before.qtitle or before.text) .. " (now " .. tostring(after and (after.qtitle or after.text)) .. ")") then moved = moved + 1 end
      end
      T.ok(moved >= 2, "it moved on each time (" .. moved .. ")")
    end,
  },
  {
    name = "step-view-skip",
    about = "the current step's Skip moves on from it",
    race = "Human", class = "MAGE", level = 12,
    run = function(T)
      T.accept(102)   -- Patrolling Westfall (the guide's step has more to do besides)
      T.go(T.Wd.objectiveSpot(102))
      T.RG.Objective(true); T.RG.RefreshStepView(); T.step(1)
      local f = T.W.G.WaypathStepView
      T.ok(f and f.skip and f.skip:IsShown(), "there's a Skip button")
      local before = T.RG.Objective(true)
      T.ok(before and before.stop, "the view is on a stop (" .. tostring(before and before.qtitle) .. ")")
      T.RG.StepViewSkip(); T.step(1)
      local after = T.RG.Objective(true)
      T.ok(not after or after.key ~= before.key, "after Skip it's on something else (" .. tostring(after and after.text) .. ")")
    end,
  },
}
