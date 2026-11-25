-- Route content checks: quests other guides do that the route used to leave out, and quests that start from an item
-- or an object (tools/routes/gen.py builds them).

-- the step (route entry, index) that holds a quest
local function stepOf(T, qid)
  for _, r in ipairs(T.RG.ROUTE or {}) do
    local key = r.zone .. "|" .. r.from
    for i, ids in pairs(T.RG.STEP_QUESTS[key] or {}) do
      for _, id in ipairs(ids) do if id == qid then return r, i end end
    end
  end
end
-- the tracker's line for a quest in a step (nil when the step doesn't show it)
local function lineOf(T, r, i, qid)
  for _, l in ipairs(T.RG.StepQuestLines(r, i) or {}) do if l.id == qid then return l end end
end
local function name(T, id) local d = T.RG.QDATA[id]; return (d and d.n or "?") .. " (" .. id .. ")" end

return {
  {
    name = "orc-early-quests-in-route",
    about = "an Orc's route has the quests every other guide does early on: the starting area's, Camping, Orgrimmar's",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      -- Wayward Weapons: filed under Durotar at level 2, handed out by Gornek in the Valley of Trials
      -- The Adventurer, The Great Outdoors, Camping 101: Cooking: Forever's Camping quests (filed under no zone)
      -- Hidden Enemies, Meal Appeal: Orgrimmar's
      for _, id in ipairs({ 97279, 96652, 96604, 96655, 5726, 97246 }) do
        T.ok(stepOf(T, id), name(T, id) .. " is in the route")
      end
      local r = stepOf(T, 97279)
      T.eq(r and r.zone, "Valley of Trials", "Wayward Weapons is in the Valley of Trials part, where Gornek hands it out")
    end,
  },
  {
    name = "undead-tauren-early-quests",
    about = "the starting areas' quests filed under the next zone are in the route (A Light in the Darkness)",
    race = "Scourge", class = "MAGE", level = 1,
    run = function(T)
      local r = stepOf(T, 98389)
      T.ok(r, name(T, 98389) .. " is in the route")
      T.ok(r and r.from == 1, "in the starting part (Deathknell), where its giver stands")
    end,
  },
  {
    name = "item-start-always-drops",
    about = "a quest from an item that always drops: the step sends you to the mob and says which item starts it",
    race = "Orc", class = "WARRIOR", level = 12,
    run = function(T)
      local r, i = stepOf(T, 832)   -- Burning Shadows: Eye of Burning Shadow, always dropped by Gazz'uz
      T.ok(r, name(T, 832) .. " is in the route")
      if not r then return end
      local l = lineOf(T, r, i, 832)
      T.ok(l and l.act == "pickup", "the tracker says to pick it up")
      if not l then return end
      T.eq(l.npc, "Gazz'uz", "from the mob that drops it")
      T.ok(l.how and l.how:find("Eye of Burning Shadow", 1, true), "and says which item starts it: " .. tostring(l.how))
      T.ok(l.wp, "with a waypoint")
      if l.wp then T.go(l.wp) end
      local ok, why = T.Wd.accept(832)
      T.ok(ok, "at that waypoint the quest can be started (" .. tostring(why) .. ")")
    end,
  },
  {
    name = "item-start-sometimes-drops",
    about = "a quest from an item that only sometimes drops waits in the route until you have it",
    race = "Orc", class = "WARRIOR", level = 9,
    run = function(T)
      local id = 97281   -- A Simmering Storm: Dull Storm Orb, a chance drop
      local r, i = stepOf(T, id)
      T.ok(r, name(T, id) .. " is in the route")
      if not r then return end
      T.ok(not lineOf(T, r, i, id), "the tracker doesn't send you for it")
      local _, never = T.RG.QuestBlocked(id, T.RG.QDATA[id])
      T.ok(never, "and the step doesn't wait for it")
      T.go(T.Wd.starterSpot(id))
      local ok, why = T.Wd.accept(id)
      T.ok(ok, "the item dropped: the quest starts (" .. tostring(why) .. ")")
      T.RG.ForgetNextStep()
      local l = lineOf(T, r, i, id)
      T.ok(l and (l.act == "doing" or l.act == "turnin"), "now the step shows it (" .. tostring(l and l.act) .. ")")
    end,
  },
}
