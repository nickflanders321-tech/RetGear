-- What you're working on (Guide.lua): the quest whose objective count went up is the current step, and the arrow
-- points at it, whatever the plan had first; it lets go once you leave.
local SANCTUARY = { 1448, 51.1, 82.0 }   -- Felwood: Emerald Sanctuary

-- one kill or item for a quest's first unfinished objective, the way the game reports it
local function credit(T, id)
  for _, e in ipairs(T.Wd.state.log) do
    if e.id == id then
      for _, o in ipairs(e.objs) do
        if o.have < o.need then
          o.have = o.have + 1
          T.W.fire("UI_INFO_MESSAGE", 0, string.format("%s: %d/%d", o.label, o.have, o.need))
          T.W.fire("QUEST_LOG_UPDATE"); T.W.fire("UNIT_QUEST_LOG_CHANGED", "player")
          return true
        end
      end
    end
  end
  return false
end

local function setup(T)
  local RG = T.RG
  RG.db.routeGuide = true
  RG.SetRouteMode("log", true)
  T.Wd.state.done[5155] = nil
  local ok1 = T.accept(5155)   -- Forces of Jaedenar: Jaedenar mobs, north-west
  local ok2 = T.accept(6162)   -- A Husband's Last Battle: Ror's claw, Deadwood Village (the plan's first stop from the Sanctuary)
  T.ok(ok1 and ok2, "both Felwood quests accepted")
  T.go(SANCTUARY); T.step(4)
  local obj = RG.Objective(true); RG.SyncObjective(obj); T.step(1)
  T.ok(obj and obj.id == 6162, "the plan starts with the claw (" .. tostring(obj and obj.qtitle) .. ")")
end

return {
  {
    name = "working-on-moves-arrow",
    about = "you're killing for a quest the plan doesn't have first: the arrow turns to that quest's objective",
    race = "Orc", class = "WARRIOR", level = 53,
    run = function(T)
      local RG = T.RG
      setup(T)
      -- heading for Ror, you turn off to Jaedenar and start killing there, short of where the quest data's spots are:
      -- closer to Jaedenar than to the claw, but not so much closer that the plan lets go of the stop it was heading to
      local sp = T.Wd.objectiveSpot(5155)
      local claw = RG.Objective().wp
      T.ok(sp ~= nil and claw ~= nil, "Forces of Jaedenar has an objective spot")
      if not (sp and claw) then return end
      local f = 0.45
      T.go({ sp[1], sp[2] + (claw[2] - sp[2]) * f, sp[3] + (claw[3] - sp[3]) * f }); T.step(1)
      local before = RG.Objective(true); RG.SyncObjective(before); T.step(1)
      T.ok(before and before.id == 6162, "the plan still heads for the claw before any kill (" .. tostring(before and before.qtitle) .. ")")
      T.ok(credit(T, 5155), "a Jaedenar kill counted")
      T.step(2)
      local obj = RG.Objective()
      T.ok(obj and obj.id == 5155 and obj.working, "the current step is Forces of Jaedenar (was " .. tostring(before and before.qtitle)
        .. ", now " .. tostring(obj and obj.qtitle) .. ", " .. tostring(obj and obj.why) .. ")")
      local a = T.arrow()
      T.ok(obj and obj.wp and T.near(a, obj.wp, 0.5), "the arrow points at it (" .. (a and string.format("%.1f,%.1f", a[2], a[3]) or "off") .. ")")
      -- and it holds through the plan's own re-planning
      T.step(8)
      local still = RG.Objective(true)
      T.ok(still and still.id == 5155, "still on it a few seconds later (" .. tostring(still and still.qtitle) .. ")")
    end,
  },
  {
    name = "working-on-lets-go",
    about = "the quest you were working on lets go once you've gone far from where it last counted",
    race = "Orc", class = "WARRIOR", level = 53,
    run = function(T)
      local RG = T.RG
      setup(T)
      local sp = T.Wd.objectiveSpot(5155)
      local claw = RG.Objective().wp
      if not (sp and claw) then T.ok(false, "Forces of Jaedenar has an objective spot") return end
      T.go({ sp[1], sp[2] + (claw[2] - sp[2]) * 0.45, sp[3] + (claw[3] - sp[3]) * 0.45 }); credit(T, 5155); T.step(2)
      T.ok(RG.WorkingOn() == 5155, "working on Forces of Jaedenar")
      T.go(SANCTUARY); T.step(4)
      local obj = RG.Objective(true)
      T.ok(RG.WorkingOn() == nil and obj and not obj.working, "back at the Sanctuary it's the plan again (" .. tostring(obj and obj.qtitle) .. ")")
    end,
  },
  {
    name = "working-on-not-at-login",
    about = "objectives already done when you log in, or a quest accepted with its items in your bags, don't count as working on it",
    race = "Orc", class = "WARRIOR", level = 53,
    run = function(T)
      setup(T)
      T.ok(T.RG.WorkingOn() == nil, "nothing counted as worked on (" .. tostring(T.RG.WorkingOn()) .. ")")
    end,
  },
}
