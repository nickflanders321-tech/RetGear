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
  {
    name = "not-offered-leaves-zone",
    about = "when the giver didn't offer the last quest a zone has left (Salve via Hunting), the smart zone order moves on instead of holding you there",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      T.setLevel(54)
      T.Wd.state.done[CLEANSING] = true
      local _, r, at = salveLine(T)
      T.ok(r, "Salve via Hunting is in a route step")
      if not r then return end
      -- everything else in the zone done: only Maybess Riverbreeze's step is left
      local key = r.zone .. "|" .. r.from
      for i, ids in pairs(RG.STEP_QUESTS[key] or {}) do
        if i ~= at then for _, id in ipairs(ids) do T.Wd.state.done[id] = true end end
      end
      -- a Tailor and Enchanter, like the player who met it: the other Salve quests need Mining, Herbalism, Skinning
      RG.Professions = function() return { Tailoring = 260, Enchanting = 240 } end
      RG.Skill = function(n) return ({ Tailoring = 260, Enchanting = 240 })[n] end
      T.give(SHARD, 6)
      T.go(RG.StepWaypoint(r, at))
      RG.db.smart, RG.db.routeStyle, RG.db.smartKey = true, "guide", key
      T.W.fire("QUEST_LOG_UPDATE"); RG.ForgetNextStep(); T.step(2)
      T.eq(RG.CurrentRouteEntry() and RG.CurrentRouteEntry().zone, r.zone, "with the shards, Felwood is still the zone (a hand-in at Maybess)")
      -- at Maybess, she doesn't offer it (as the add-on notes when her window opens without it)
      RG.db.notOffered = { [HUNTING] = 54 }
      T.W.fire("QUEST_LOG_UPDATE"); RG.ForgetNextStep(); T.step(2)
      local work, seen = false, {}
      for i = 1, #(RG.STEPS[key] or {}) do
        if not RG.StepIsDone(r, i) then
          for _, l in ipairs(RG.StepQuestLines(r, i) or {}) do if l.act ~= "later" then work = true; seen[#seen + 1] = tostring(l.name) end end
        end
      end
      T.ok(not work, "nothing in Felwood can be done now (" .. table.concat(seen, ", ") .. ")")
      local now = RG.CurrentRouteEntry()
      T.ok(now and now.zone ~= r.zone, "the ordered guide moves on to another zone (" .. tostring(now and now.zone) .. ")")
      -- even when the ranking thinks Felwood still has work (it counts more loosely than the tracker), the smart order
      -- doesn't hold you there while the tracker has nothing to do in it
      local rank = RG.SmartRank
      RG.SmartRank = function()
        local list = { { r = r, score = 10, why = "" } }
        for _, o in ipairs(rank()) do if o.r ~= r then list[#list + 1] = o end end
        return list
      end
      RG.db.smartKey = key
      local pick = RG.SmartEntry()
      RG.SmartRank = rank
      T.ok(pick and pick ~= r, "the smart pick isn't Felwood when nothing there can be done now (" .. tostring(pick and pick.zone) .. ")")
    end,
  },
}
