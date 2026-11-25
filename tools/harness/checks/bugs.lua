-- Regression checks for bugs the bot found (run.lua --play). A new one is marked `known` until it's fixed (a known
-- bug that fails is expected; once it passes, the runner says "FIXED?" and the `known` line should go). All of the
-- ones below are fixed: they now guard against the bugs coming back.

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
    race = "Scourge", class = "PALADIN", level = 12,
    run = function(T)
      local r, i = stepOf(T, 5481)   -- Gordo's Task (level 5); Doom Weed (5482) needs it
      local r2, i2 = stepOf(T, 5482)
      T.ok(r and r2, "Gordo's Task and Doom Weed are both in the route")
      if not (r and r2) then return end
      T.ok(not T.RG.StepIsDone(r, i), "Gordo's Task's step isn't done while Doom Weed, later in the route, needs it")
      local act
      for _, l in ipairs(T.RG.StepQuestLines(r, i) or {}) do if l.id == 5481 then act = l.act end end
      T.eq(act, "pickup", "the tracker offers Gordo's Task to pick up")
      -- and once Doom Weed (and what follows it) is done, the grey quest is optional again
      markDone(T, { 5482, 99142 })
      T.ok(not T.RG.GreyButNeeded(5481), "with Doom Weed done, nothing needs Gordo's Task any more")
    end,
  },
  {
    name = "next-step-has-something-to-do",
    about = "the guide's next step is one with something to do, not one whose quests all have to wait",
    race = "Scourge", class = "PALADIN", level = 11,
    run = function(T)
      local r, i = stepOf(T, 5481)   -- Gordo's Task: the step before the Brill step whose Doom Weed needs it
      T.ok(r, "Gordo's Task is in the route")
      if not r then return end
      -- the earlier Tirisfal steps done, and the Brill step after it done except Doom Weed (which needs Gordo's Task);
      -- standing in Brill, where that next step's waypoint is
      local sq = T.RG.STEP_QUESTS[r.zone .. "|" .. r.from]
      for j = 1, i - 1 do for _, id in ipairs(sq[j] or {}) do T.Wd.state.done[id] = true end end
      for _, id in ipairs(sq[i + 1] or {}) do if id ~= 5482 then T.Wd.state.done[id] = true end end
      T.W.fire("QUEST_LOG_UPDATE")
      T.go({ 1420, 61.7, 52.0 })
      T.step(2)
      -- the guide had picked the Brill step while it still had quests to do (it keeps its pick unless another is clearly better)
      T.RG.ForgetNextStep()
      T.ok(not T.RG.StepIsDone(r, i), "Gordo's Task's step is still open")
      local pick = T.RG.NextStep(r)
      local acts = {}
      for _, l in ipairs(T.RG.StepQuestLines(r, pick) or {}) do acts[#acts + 1] = l.act end
      local doable = false
      for _, a in ipairs(acts) do if a ~= "later" then doable = true end end
      T.ok(doable, string.format("the next step (%s step %d) has something to do now (its quests: %s)", r.zone, pick or 0, table.concat(acts, ", ")))
    end,
  },
  {
    name = "next-step-looks-further",
    about = "when the next few steps of a zone all have to wait, the guide finds a later one with something to do",
    race = "Human", class = "MAGE", level = 58,
    run = function(T)
      local r = T.entry("Eastern Plaguelands")
      T.ok(r, "Eastern Plaguelands is on the Alliance route")
      if not r then return end
      local key = r.zone .. "|" .. r.from
      -- the earlier steps done, except the ones whose quests wait on Winterspring's Kel'Theril chain
      local waiting = { [5246] = true, [5247] = true, [5248] = true }
      local open = {}
      for i, ids in pairs(T.RG.STEP_QUESTS[key] or {}) do
        local hold = false
        for _, id in ipairs(ids) do if waiting[id] then hold = true end end
        if hold then open[#open + 1] = i else for _, id in ipairs(ids) do T.Wd.state.done[id] = true end end
      end
      table.sort(open)
      T.ok(#open > 0, "a Plaguelands step holds the Kel'Theril follow-ups")
      if #open == 0 then return end
      -- keep three more steps after the first waiting one open, but waiting too, and one further on with work
      local steps = T.RG.STEPS[key] or {}
      local work
      for i = open[#open] + 1, #steps do work = work or i end
      if work then for _, id in ipairs(T.RG.STEP_QUESTS[key][work] or {}) do T.Wd.state.done[id] = nil end end
      T.W.fire("QUEST_LOG_UPDATE"); T.RG.ForgetNextStep(); T.step(2)
      local pick = T.RG.NextStep(r)
      local acts = {}
      for _, l in ipairs(T.RG.StepQuestLines(r, pick) or {}) do acts[#acts + 1] = l.act end
      local doable = false
      for _, a in ipairs(acts) do if a ~= "later" then doable = true end end
      T.ok(doable or not work, string.format("the guide picks a step with something to do (step %d: %s)", pick or 0, table.concat(acts, ", ")))
    end,
  },
  {
    name = "chain-start-in-route",
    about = "every quest in a step can be reached: its earlier quests are in the route (Undead, Barrens)",
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
