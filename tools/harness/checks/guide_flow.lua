-- The ordered guide in Felwood at 54: quests behind a chance drop don't hold a step, and a quest that follows a hand-in
-- from the same NPC is picked up right then (not on a trip back).
local KEY, RESCUE, RED_KEY = 5202, 5203, 5202
local SEEKING, CLEANSED, CORRUPT_WATER = 5158, 5159, 5157
local ISLEN = { 1413, 65.8, 43.8 }

local function felwoodGuide(T)
  local RG = T.RG
  RG.db.routeGuide = true
  T.setLevel(54)
  RG.SetZonePick("Felwood"); T.step(1)
  RG.SetRouteMode("guide", true); T.step(1)
  local r = RG.CurrentRouteEntry()
  return r and r.zone == "Felwood" and r or nil
end

return {
  {
    name = "guide-chance-drop-chain",
    about = "a quest that waits on one starting from a rare drop (Rescue From Jaedenar after A Strange Red Key) isn't listed as later and doesn't hold the step",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      T.setLevel(54)
      local why, never = RG.QuestBlocked(RESCUE, T.quest(RESCUE))
      T.ok(never, "Rescue From Jaedenar can't be taken now: " .. tostring(why))
      T.ok(tostring(why):find("A Strange Red Key", 1, true), "because of A Strange Red Key: " .. tostring(why))
      T.Wd.state.done[RED_KEY] = true
      why, never = RG.QuestBlocked(RESCUE, T.quest(RESCUE))
      T.ok(not never, "once A Strange Red Key is done, it's open (" .. tostring(why) .. ")")
    end,
  },
  {
    name = "guide-follow-up-pickup",
    about = "handing in Seeking Spiritual Aid at Islen Waterseer, the guide has you pick up Cleansed Water Returns to Felwood there next",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      local r = felwoodGuide(T)
      if not T.ok(r, "the guide is on Felwood") then return end
      T.Wd.state.done[CORRUPT_WATER] = true
      local ok, why = T.accept(SEEKING)
      T.ok(ok, "Seeking Spiritual Aid accepted (" .. tostring(why) .. ")")
      T.go(ISLEN)
      RG.ForgetNextStep(); RG.ForgetQuestSpots()
      local obj = RG.Objective(true); T.step(1)
      local plan = RG.GuidePlan()
      local tIdx, pIdx
      for i, st in ipairs(plan and plan.stops or {}) do
        for _, it in ipairs(st.items) do
          if it.id == SEEKING and it.act == "turnin" then tIdx = tIdx or i end
          if it.id == CLEANSED and it.act == "pickup" then pIdx = pIdx or i end
        end
      end
      T.ok(tIdx, "the plan hands in Seeking Spiritual Aid (stop " .. tostring(tIdx) .. ")")
      T.ok(pIdx and tIdx and pIdx > tIdx, "and then picks up Cleansed Water Returns to Felwood (stop " .. tostring(pIdx) .. ")")
      local hok = T.Wd.handIn(SEEKING); T.step(1)
      T.ok(hok, "handed in")
      RG.ForgetNextStep(); RG.ForgetQuestSpots()
      obj = RG.Objective(true); T.step(1)
      T.ok(obj and obj.id == CLEANSED and obj.act == "pickup", "the current step is to pick it up: " .. tostring(obj and (obj.act .. " " .. tostring(obj.qtitle or obj.text))))
    end,
  },
}
