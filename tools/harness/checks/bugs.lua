-- Regression checks for bugs the bot found (run.lua --play). Each is marked `known` until it's fixed: a known bug
-- that fails is expected; once it passes, the runner says "FIXED?" and the `known` line should go.

-- the step (route entry, index) that holds a quest
local function stepOf(T, qid)
  for _, r in ipairs(T.RG.ROUTE or {}) do
    local key = r.zone .. "|" .. r.from
    for i, ids in pairs(T.RG.STEP_QUESTS[key] or {}) do
      for _, id in ipairs(ids) do if id == qid then return r, i end end
    end
  end
end
-- mark quests done in the world (as if handed in earlier) and let the add-on hear about it
local function markDone(T, ids)
  for _, id in ipairs(ids) do T.Wd.state.done[id] = true end
  T.W.fire("QUEST_LOG_UPDATE")
  T.step(2)
end

local BRUTE_HAMMER, DEADSKULL_SHIELD = 15464, 3761   -- a two-hander and a shield the bot met at level 30

return {
  {
    name = "shield-over-two-hander",
    about = "a shield isn't called an upgrade when it would take off a better two-hander",
    known = "RG.Compare (Core.lua compareRaw) scores an off-hand against the empty off-hand slot and ignores the two-hander it takes off",
    race = "Orc", class = "WARRIOR", level = 30,
    run = function(T)
      T.give(BRUTE_HAMMER); T.equip(BRUTE_HAMMER)
      T.eq(T.Inv.equip[16], BRUTE_HAMMER, "Brute Hammer is in the main hand")
      T.give(DEADSKULL_SHIELD)
      local d = T.RG.Compare(T.link(DEADSKULL_SHIELD))
      local hammer = T.RG.Score(T.link(BRUTE_HAMMER), nil, 16)
      T.ok(not d or d <= 0.5, string.format("Deadskull Shield isn't an upgrade over Brute Hammer (score %.0f): the add-on says %s",
        hammer or 0, d and string.format("%+.0f", d) or "nothing"))
    end,
  },
  {
    name = "two-hander-over-shield",
    about = "after a shield has taken a two-hander off, the two-hander is an upgrade again",
    known = "with a shield worn, RG.Compare gives a two-hander no score of its own (it came out at -0.7 for a 180-point weapon)",
    race = "Orc", class = "WARRIOR", level = 30,
    run = function(T)
      -- as the bot met it: the two-hander worn first, then the shield (which takes it off)
      T.give(BRUTE_HAMMER); T.equip(BRUTE_HAMMER)
      T.give(DEADSKULL_SHIELD); T.equip(DEADSKULL_SHIELD)
      T.ok(T.Inv.equip[16] == nil and T.Inv.equip[17] == DEADSKULL_SHIELD, "the shield is on and the main hand is empty")
      local d = T.RG.Compare(T.link(BRUTE_HAMMER))
      local hammer = T.RG.Score(T.link(BRUTE_HAMMER), nil, 16)
      T.ok(d and d > 0.5, string.format("Brute Hammer (score %.0f on its own) is an upgrade over just a shield: the add-on says %s",
        hammer or 0, d and string.format("%+.0f", d) or "nothing"))
    end,
  },
  {
    name = "breadcrumb-step-completes",
    about = "a step whose only quest is a breadcrumb that's gone (its follow-up already taken) counts as done",
    known = "Quests.lua stepAuto doesn't excuse a breadcrumb the tracker hides as gone, so the step never completes",
    race = "Tauren", class = "WARRIOR", level = 26,
    run = function(T)
      local r, i = stepOf(T, 4542)   -- Message to Freewind Post, a breadcrumb for 4841
      T.ok(r, "Message to Freewind Post (4542) is in the route")
      if not r then return end
      markDone(T, { 4841 })
      local lines = T.RG.StepQuestLines(r, i)
      T.eq(lines and #lines, 0, "the tracker has nothing left to do in the step")
      T.ok(T.RG.StepIsDone(r, i), "so the step counts as done (" .. r.zone .. " step " .. i .. ")")
    end,
  },
  {
    name = "grey-prerequisite-kept",
    about = "a quest that went grey isn't skipped while a later step still needs it",
    known = "stepAuto and StepQuestLines skip grey quests even when a later quest needs them (Gordo's Task -> Doom Weed)",
    race = "Scourge", class = "PALADIN", level = 12,
    run = function(T)
      local r, i = stepOf(T, 5481)   -- Gordo's Task (level 5); Doom Weed (5482) needs it
      local r2, i2 = stepOf(T, 5482)
      T.ok(r and r2, "Gordo's Task and Doom Weed are both in the route")
      if not (r and r2) then return end
      T.ok(not T.RG.StepIsDone(r, i), "Gordo's Task's step isn't done while Doom Weed, later in the route, needs it")
    end,
  },
  {
    name = "chain-start-in-route",
    about = "every quest in a step can be reached: its earlier quests are in the route (Undead, Barrens)",
    known = "the shared Barrens steps list Serena Bloodfeather (876), which needs Harpy Lieutenants (875): that's only in the Orc/Troll/Tauren route",
    race = "Scourge", class = "PALADIN", level = 20,
    run = function(T)
      local r, i = stepOf(T, 876)
      T.ok(r, "Serena Bloodfeather (876) is in the Undead route")
      if not r then return end
      local r0 = stepOf(T, 875)
      T.ok(r0 ~= nil, "Harpy Lieutenants (875), which Serena Bloodfeather needs, is in the Undead route too")
    end,
  },
}
