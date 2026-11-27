-- Zone quests in Winterspring: as objectives are done and quests handed in, the plan keeps up (no error freezing it on
-- an old plan until /reload, every quest with something left still in it).
local EVERLOOK = { 1452, 61.4, 38.8 }

local function planIds(RG)
  local ids = {}
  for _, st in ipairs((RG.GuidePlan() or {}).stops or {}) do
    for _, it in ipairs(st.items) do if it.id then ids[it.id] = true end end
  end
  return ids
end

return {
  {
    name = "zone-quests-keep-updating",
    about = "zone quests in Winterspring: working through the quests, the plan rebuilds every time and keeps every quest with something left",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      RG.db.routeGuide = true
      T.setLevel(55)
      RG.SetZonePick("Winterspring"); T.step(1)
      T.go(EVERLOOK)
      local r = RG.CurrentRouteEntry()
      if not T.ok(r and r.zone == "Winterspring", "zone quests follow Winterspring") then return end
      -- take what the zone's first steps offer
      local taken = {}
      for i = 1, 4 do
        for _, l in ipairs(RG.StepQuestLines(r, i) or {}) do
          if l.act == "pickup" and #taken < 8 then
            local d = T.quest(l.id)
            for _, p in ipairs(d and d.ps or {}) do T.Wd.state.done[p] = true end
            for _, p in ipairs(d and d.pg or {}) do T.Wd.state.done[p] = true end
            local ok = T.accept(l.id)
            if ok then taken[#taken + 1] = l.id end
          end
        end
      end
      T.ok(#taken >= 4, "took " .. #taken .. " Winterspring quests")
      -- work through them one objective at a time; after each, the plan is rebuilt without an error
      local errors, missing = 0, {}
      for round = 1, 12 do
        local any = false
        for _, id in ipairs(taken) do
          local sp = T.Wd.objectiveSpot(id)
          if sp then T.go(sp); T.Wd.work(id); any = true; break end
        end
        if not any then break end
        T.step(3)
        RG.lastGuideError = nil
        RG.ForgetQuestSpots(); RG.ForgetNextStep()
        RG.Objective(true); T.step(1)
        if RG.lastGuideError then errors = errors + 1; T.ok(false, "round " .. round .. ": the plan failed: " .. tostring(RG.lastGuideError)) end
        local ids = planIds(RG)
        for _, id in ipairs(taken) do
          local e = T.Wd.entry(id)
          if e and not ids[id] and T.Wd.objectiveSpot(id) then missing[#missing + 1] = round .. ":" .. tostring(T.quest(id).n) end
        end
      end
      T.eq(errors, 0, "the plan never failed")
      T.ok(#missing == 0, "every quest with an objective left stayed in the plan (" .. table.concat(missing, ", ") .. ")")
    end,
  },
  {
    name = "collapsed-quest-log",
    about = "quests under a zone header you've collapsed in the quest log still count: in your quests, the plan and the tracker",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      RG.db.routeGuide = true
      T.setLevel(55)
      RG.SetZonePick("Winterspring"); T.step(1)
      T.go(EVERLOOK)
      local r = RG.CurrentRouteEntry()
      if not r then return end
      local taken = {}
      for _, l in ipairs(RG.StepQuestLines(r, 1) or {}) do
        if l.act == "pickup" and #taken < 3 then
          local d = T.quest(l.id)
          for _, p in ipairs(d and d.ps or {}) do T.Wd.state.done[p] = true end
          if T.accept(l.id) then taken[#taken + 1] = l.id end
        end
      end
      if not T.ok(#taken >= 2, "took " .. #taken .. " quests") then return end
      T.step(2)
      RG.ForgetQuestSpots(); RG.ForgetNextStep(); RG.Objective(true); T.step(1)
      local before = {}
      for _, st in ipairs((RG.GuidePlan() or {}).stops or {}) do for _, it in ipairs(st.items) do if it.id then before[it.id] = true end end end
      T.Wd.state.collapsed = true   -- (you collapse the Winterspring header)
      T.W.fire("QUEST_LOG_UPDATE"); T.step(3)
      RG.ForgetMyQuests(); RG.ForgetQuestSpots(); RG.ForgetNextStep()
      local mine = {}
      for _, q in ipairs(RG.MyQuests()) do mine[q.id] = true end
      local inPlan = {}
      RG.Objective(true); T.step(1)
      for _, st in ipairs((RG.GuidePlan() or {}).stops or {}) do for _, it in ipairs(st.items) do if it.id then inPlan[it.id] = true end end end
      local lostMine, lostPlan = {}, {}
      for _, id in ipairs(taken) do
        if not mine[id] then lostMine[#lostMine + 1] = T.quest(id).n end
        if before[id] and not inPlan[id] then lostPlan[#lostPlan + 1] = T.quest(id).n end
      end
      T.ok(#lostMine == 0, "all still in your quests (" .. table.concat(lostMine, ", ") .. ")")
      T.ok(#lostPlan == 0, "all that were in the plan still are (" .. table.concat(lostPlan, ", ") .. ")")
      for _, l in ipairs(RG.StepQuestLines(r, 1) or {}) do
        for _, id in ipairs(taken) do
          T.ok(not (l.id == id and l.act == "pickup"), "the step doesn't say to pick up " .. tostring(l.name) .. " again")
        end
      end
      T.Wd.state.collapsed = nil
    end,
  },
  {
    name = "tracker-follows-replan",
    about = "the tracker redraws when the plan changes without a quest event (re-planned as you move), not only on the next event",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      RG.db.routeGuide = true
      T.setLevel(55)
      RG.SetZonePick("Winterspring"); T.step(1)
      T.go(EVERLOOK)
      local r = RG.CurrentRouteEntry()
      if not r then return end
      for i = 1, 3 do
        for _, l in ipairs(RG.StepQuestLines(r, i) or {}) do
          if l.act == "pickup" then
            local d = T.quest(l.id)
            for _, p in ipairs(d and d.ps or {}) do T.Wd.state.done[p] = true end
            T.accept(l.id)
          end
        end
      end
      T.go(EVERLOOK); T.step(8)
      -- far across the zone, quietly (no quest event): the beat re-plans, and the tracker must show it
      local far = { 1452, 31.3, 45.2 }   -- Donova Snowden's camp, west
      T.W.G.C_Timer.After(0, function() end)
      T.Wd.setPos(far[1], far[2] / 100, far[3] / 100)
      T.step(10)
      local plan = RG.GuidePlan()
      local first = plan and plan.stops[1]
      local want = first and RG.PrepStepText(first.items[1])
      T.ok(want, "the plan has a first stop")
      local shown = want and T.trackerFind(want:gsub("%p", "%%%0"):sub(1, 40))
      T.ok(shown, "the tracker shows the plan's first stop (" .. tostring(want) .. ")")
    end,
  },
}
