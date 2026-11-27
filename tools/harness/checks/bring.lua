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
    about = "a quest taken only with its items (Salve via Hunting) has you collect them where they drop, and is a hand-in once they're in your bags",
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
      T.ok(l and l.act == "doing" and l.farm, "without the shards the step has you collect them (" .. tostring(l and l.act) .. ")")
      T.eq(l and l.prog, "0/6", "6 Corrupted Soul Shards to collect")
      T.ok(l and l.wp and l.wp[1] == 1448, "in Felwood, where they drop")
      local why, never = RG.QuestBlocked(HUNTING, d)
      T.ok(not never, "it isn't left out: the shards drop around here (" .. tostring(why) .. ")")
      -- Salve via Disenchanting: a Lesser Nether Essence, which nothing drops: left out (it needs Enchanting too)
      local _, nev2 = RG.QuestBlocked(5891, T.quest(5891))
      T.ok(nev2, "Salve via Disenchanting, whose essence nothing drops, is left out")
      T.give(SHARD, 3)
      RG.ForgetNextStep()
      l = salveLine(T)
      T.eq(l and l.prog, "3/6", "3 shards in your bags: 3/6")
      T.give(SHARD, 3)
      RG.ForgetNextStep()
      l = salveLine(T)
      T.ok(l and l.act == "turnin", "with the shards it's a hand-in (" .. tostring(l and l.act) .. ")")
      T.ok(l and l.wp and l.npc == "Maybess Riverbreeze", "at Maybess Riverbreeze (" .. tostring(l and l.npc) .. ")")
    end,
  },
}
