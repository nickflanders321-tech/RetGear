-- Quests you can only take once you have their items (bi in Objectives.lua): talking to the giver opens the hand-in, with
-- Continue greyed out until the items are in your bags (Salve via Hunting: 6 Corrupted Soul Shards).
local HUNTING, CLEANSING, SHARD = 5887, 4102, 11515

local function salveLine(T)
  local RG = T.RG
  for _, r in ipairs(RG.ROUTE or {}) do
    local key = r.zone .. "|" .. r.from
    for i, ids in pairs(RG.STEP_QUESTS and RG.STEP_QUESTS[key] or {}) do
      for _, id in ipairs(ids) do
        if id == HUNTING then
          for _, l in ipairs(RG.StepQuestLines(r, i) or {}) do if l.id == HUNTING then return l, r, i end end
          return false, r, i
        end
      end
    end
  end
end

return {
  {
    name = "bring-items-quest",
    about = "a quest taken only with its items (Salve via Hunting) isn't a pick-up without them, doesn't hold the step open, and is a hand-in once they're in your bags",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      local d = T.quest(HUNTING)
      T.ok(d and d.bi and d.bi[1] and d.bi[1][1] == SHARD and d.bi[1][2] == 6, "Salve via Hunting needs 6 Corrupted Soul Shards to take")
      T.setLevel(54)
      T.Wd.state.done[CLEANSING] = true
      local l, r, i = salveLine(T)
      T.ok(r, "Salve via Hunting is in a route step")
      if not r then return end
      T.ok(not l, "without the shards it isn't on the step (" .. tostring(l and l.act) .. ")")
      local why, never = RG.QuestBlocked(HUNTING, d)
      T.ok(never and tostring(why):find("6", 1, true), "it says to bring them first, and the step doesn't wait: " .. tostring(why))
      T.give(SHARD, 6)
      RG.ForgetNextStep()
      l = salveLine(T)
      T.ok(l and l.act == "turnin", "with the shards it's a hand-in (" .. tostring(l and l.act) .. ")")
      T.ok(l and l.wp and l.npc == "Maybess Riverbreeze", "at Maybess Riverbreeze (" .. tostring(l and l.npc) .. ")")
    end,
  },
}
