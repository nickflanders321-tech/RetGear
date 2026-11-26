-- The arrow moves on by itself: once a step is done, it points at the next one (no click needed).
local function follow(T, mode, rounds)
  local RG = T.RG
  RG.db.routeGuide = true
  RG.SetRouteMode(mode, true); T.step(6)
  local seen, misses = 0, {}
  for i = 1, rounds do
    local obj = RG.Objective(true)
    if not (obj and obj.wp) then break end
    -- walk there and do what it says straight away (an auto accept / hand-in is quicker than the arrow letting go of
    -- the pin you reached)
    T.go(obj.wp); T.step(1)
    -- (once along the way: the arrow switched off for this step comes back for the next)
    if i == 2 then RG.ArrowOff(); T.step(1) end
    local it = obj.stop and obj.stop.items and obj.stop.items[1]
    if it and it.act == "pickup" then T.Wd.accept(it.id)
    elseif it and it.act == "turnin" then T.Wd.handIn(it.id)
    elseif it and it.act == "doing" then T.work(it.id)
    elseif obj.kind == "route" then RG.StepViewSkip() end
    local trace = {}
    for s = 1, 7 do
      T.step(1)
      local a0 = T.arrow()
      local o = RG.Objective()
      trace[#trace + 1] = string.format("t+%d pin=%s obj=%s paused=%s", s, a0 and string.format("%.1f,%.1f", a0[2], a0[3]) or "off", tostring(o and o.key), tostring(RG.db.arrowPaused))
    end
    local now = RG.Objective()
    if not (now and now.wp) then break end
    seen = seen + 1
    local a = T.arrow()
    if not T.near(a, now.wp, 0.5) then
      misses[#misses + 1] = string.format("after \"%s\" the current step is \"%s\" (%.1f,%.1f) but the arrow is %s", tostring(obj.text), tostring(now.text),
        now.wp[2], now.wp[3], a and string.format("at %.1f,%.1f", a[2], a[3]) or "off") .. "\n            " .. table.concat(trace, "\n            ")
    end
  end
  T.ok(seen >= 3, mode .. ": followed " .. seen .. " steps")
  T.ok(#misses == 0, mode .. ": the arrow moved on by itself every time" .. (#misses > 0 and (":\n          " .. table.concat(misses, "\n          ")) or ""))
end

return {
  {
    name = "arrow-moves-on-guide",
    about = "the ordered guide: once a step is done the arrow points at the next one by itself",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T) follow(T, "guide", 10) end,
  },
  {
    name = "arrow-moves-on-zone",
    about = "zone quests: once a step is done the arrow points at the next one by itself",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T) follow(T, "zone", 10) end,
  },
}
