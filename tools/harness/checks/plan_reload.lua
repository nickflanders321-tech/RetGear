-- Zone quests' plan is the same before and after a /reload: what it plans is worked out again as you play, not only
-- at login.
local function planList(RG)
  local out = {}
  for _, s in ipairs((RG.GuidePlan() or {}).stops or {}) do
    for _, it in ipairs(s.items) do out[#out + 1] = it.act .. " " .. tostring(it.title) .. (it.label and (" / " .. tostring(it.label)) or "") end
  end
  table.sort(out)
  return out
end

return {
  {
    name = "plan-same-after-reload",
    about = "zone quests: after playing a while, the plan has everything a /reload would give it",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      RG.db.routeGuide = true
      RG.SetRouteMode("zone", true); T.step(6)
      for _ = 1, 14 do
        local obj = RG.Objective(true)
        if not (obj and obj.wp) then break end
        T.go(obj.wp); T.step(1)
        local it = obj.stop and obj.stop.items and obj.stop.items[1]
        if it and it.act == "pickup" then T.Wd.accept(it.id)
        elseif it and it.act == "turnin" then T.Wd.handIn(it.id)
        elseif it and it.act == "doing" then T.work(it.id)
        elseif obj.kind == "route" then RG.StepViewSkip() end
        T.step(4)
      end
      T.step(6)
      RG.Objective(true)
      RG.db.__planBefore = planList(RG)
      RG.db.__posBefore = { T.W.me.map, T.W.me.x, T.W.me.y }
    end,
    reload = function(T)
      local RG = T.RG
      local p = RG.db.__posBefore
      if p then T.W.me.map, T.W.me.x, T.W.me.y = p[1], p[2], p[3] end
      T.step(8)
      RG.Objective(true)
      local before, after = RG.db.__planBefore or {}, planList(RG)
      local had = {}
      for _, x in ipairs(before) do had[x] = true end
      local new = {}
      for _, x in ipairs(after) do if not had[x] then new[#new + 1] = x end end
      T.ok(#before > 0, "there was a plan before the reload (" .. #before .. " tasks)")
      T.ok(#new == 0, "the reload added nothing the plan didn't have: " .. table.concat(new, "; ") .. "  [before: " .. table.concat(before, "; ") .. "]")
      RG.db.__planBefore, RG.db.__posBefore = nil, nil
    end,
  },
}
