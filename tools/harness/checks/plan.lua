-- The plan (Guide.lua): the order of the stops the current step and Zone quests' list follow, and a stop you pick
-- yourself.
local SANCTUARY = { 1448, 51.1, 82.0 }   -- Felwood: Emerald Sanctuary

local function felwood(T)
  local RG = T.RG
  RG.SetRouteMode("log", true)   -- (only these two quests in the plan)
  T.Wd.state.done[5155] = nil
  local ok1, why1 = T.accept(5155)   -- Forces of Jaedenar: four kinds of Jaedenar mob, north-west; hand in at the Sanctuary
  local ok2, why2 = T.accept(6162)   -- A Husband's Last Battle: Overlord Ror's Claw, Deadwood Village just south; hand in at Bloodvenom Post
  T.ok(ok1 and ok2, "both Felwood quests accepted (" .. tostring(why1) .. ", " .. tostring(why2) .. ")")
  T.go(SANCTUARY)
end

return {
  {
    name = "plan-shortest-trip",
    about = "the plan looks at the whole trip: the claw close by comes before a camp of four objectives far off when that's less walking in all",
    race = "Orc", class = "WARRIOR", level = 53,
    run = function(T)
      felwood(T)
      local obj = T.RG.Objective(true)
      T.ok(obj and obj.qtitle == "A Husband's Last Battle", "the current step is the claw (" .. tostring(obj and obj.qtitle) .. ")")
      local plan = T.RG.GuidePlan()
      local order = {}
      for _, s in ipairs(plan.stops or {}) do order[#order + 1] = T.RG.StopText(s, true) end
      T.ok(#order >= 4, "the plan: " .. table.concat(order, " > "))
    end,
  },
  {
    name = "plan-manual-pick",
    about = "a quest you click on the tracker is the current step for a while, whatever the plan says; Skip goes back to the plan",
    race = "Orc", class = "WARRIOR", level = 53,
    run = function(T)
      local RG = T.RG
      felwood(T)
      local first = RG.Objective(true)
      -- pick the stop the plan has last
      local plan = RG.GuidePlan()
      local last = plan.stops[#plan.stops]
      T.ok(last and first and last.key ~= first.stop.key, "the plan has another stop to pick")
      if not last then return end
      RG.ArrowTo(last.wp); T.step(1)
      local obj = RG.Objective(true)
      T.ok(obj and obj.manual and obj.stop and obj.stop.key == last.key, "the picked stop is the current step (" .. tostring(obj and obj.text) .. ")")
      T.step(30)
      obj = RG.Objective(true)
      T.ok(obj and obj.manual, "still, half a minute on, standing still")
      RG.StepViewSkip(); T.step(1)
      obj = RG.Objective(true)
      T.ok(obj and not obj.manual and obj.key == first.key, "Skip: back to the plan (" .. tostring(obj and obj.text) .. ")")
    end,
  },
  {
    name = "plan-manual-place",
    about = "clicking a place that isn't a stop (a town with nothing of yours to do) makes the current step \"Head to\" it; a town with a stop of yours picks that stop",
    race = "Orc", class = "WARRIOR", level = 53,
    run = function(T)
      local RG = T.RG
      felwood(T)
      RG.ArrowTo({ 1448, 62.5, 24.2, "Talonbranch Glade" }); T.step(1)
      local obj = RG.Objective(true)
      T.ok(obj and obj.kind == "pick" and obj.text == "Head to Talonbranch Glade", "the current step: " .. tostring(obj and obj.text))
      RG.ArrowTo({ 1448, 62.5, 24.2, "Talonbranch Glade" }); T.step(1)   -- clicked again: the arrow off
      obj = RG.Objective(true)
      T.ok(obj and obj.kind ~= "pick", "the arrow turned off: back to the plan (" .. tostring(obj and obj.text) .. ")")
      RG.ArrowTo({ 1448, 34.4, 53.0, "Bloodvenom Post" }); T.step(1)   -- where A Husband's Last Battle is handed in
      obj = RG.Objective(true)
      T.ok(obj and obj.manual and obj.qtitle == "A Husband's Last Battle", "Bloodvenom Post: the hand-in there (" .. tostring(obj and obj.text) .. ")")
    end,
  },
}
