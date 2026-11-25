-- Route content checks: quests other guides do that the route used to leave out, quests that start from an item or
-- an object, and class quests carried in the route's steps (tools/routes/gen.py builds all of them).

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
  {
    name = "class-quest-in-step",
    about = "a class quest is carried by the step at its giver's hub, for its own class",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local r, i = stepOf(T, 2383)   -- Simple Parchment: Warriors, from Frang in the Valley of Trials
      T.ok(r, name(T, 2383) .. " is in the route")
      if not r then return end
      T.complete(788)   -- Cutting Teeth comes first
      T.RG.ForgetNextStep()
      local l = lineOf(T, r, i, 2383)
      T.ok(l and l.act == "pickup", "after Cutting Teeth, a Warrior is told to pick it up (" .. tostring(l and l.act) .. ")")
      T.ok(not T.RG.STEPS[r.zone .. "|" .. r.from][i]:find("Simple Parchment", 1, true), "the step's text doesn't name it (other classes read it too)")
      local listed = false
      for _, q in ipairs(T.RG.ClassQuests() or {}) do if q.id == 2383 then listed = true end end
      T.ok(not listed, "and the Class quests list doesn't show it twice")
    end,
  },
  {
    name = "other-class-quest-ignored",
    about = "another class's quest in a step neither shows nor holds the step open",
    race = "Orc", class = "MAGE", level = 1,
    run = function(T)
      local r, i = stepOf(T, 2383)   -- Simple Parchment (Warriors only)
      T.ok(r, name(T, 2383) .. " is in the route")
      if not r then return end
      T.ok(not lineOf(T, r, i, 2383), "a Mage isn't shown the Warrior quest")
      -- everything else in the step done: the step is done
      local others = {}
      for _, id in ipairs(T.RG.STEP_QUESTS[r.zone .. "|" .. r.from][i]) do if id ~= 2383 then others[#others + 1] = id end end
      for _, id in ipairs(others) do T.Wd.state.done[id] = true end
      T.W.fire("QUEST_LOG_UPDATE"); T.step(2)
      T.ok(T.RG.StepIsDone(r, i), "the step is done once the Mage's own quests in it are")
    end,
  },
  {
    name = "class-quest-not-early",
    about = "the Class quests list doesn't say \"pick up now\" for a quest well above your level",
    race = "Orc", class = "WARRIOR", level = 20,
    run = function(T)
      local early = {}
      for _, q in ipairs(T.RG.ClassQuests() or {}) do
        if q.now and q.lvl and q.lvl > 23 then early[#early + 1] = q.name .. " (level " .. q.lvl .. ")" end
      end
      T.ok(#early == 0, "nothing more than 3 levels above you is \"pick up now\"" .. (#early > 0 and (": " .. table.concat(early, ", ")) or ""))
    end,
  },
}
