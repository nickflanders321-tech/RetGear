-- Quests whose objective is an event or a place to reach (kind e in Objectives.lua: QuestieDB's triggerEnd and
-- extraObjectives, and tools/objectives/places.json), and a route step whose quest is in your log with no place known.

-- Felwood for a level-53 Orc, with step 1 (Grazle) out of the way and Corrupted Sabers' first quest done:
-- Bloodvenom Post's step is down to Corrupted Sabers
local SABERS, WELL, HUSBAND = 4506, 4505, 6162
local MOONWELL, WINNA = { 1448, 32.3, 66.6 }, { 1448, 34.3, 52.3 }
local function felwood(T, logOnly)
  local RG = T.RG
  RG.db.routeGuide = true
  T.setLevel(53)
  RG.SetZonePick("Felwood"); T.step(1)
  if logOnly then RG.SetRouteMode("log", true); T.step(1) end   -- (only your quests: the zone's pick-ups stay out of it)
  RG.db.stepsDone = RG.db.stepsDone or {}
  RG.db.stepsDone["Felwood|51#1"] = true
  T.Wd.state.done[WELL] = true; T.Wd.state.done[HUSBAND] = true
  local ok, why = T.accept(SABERS)
  T.ok(ok, "Corrupted Sabers accepted (" .. tostring(why) .. ")")
  -- (like the game: one event objective, in words that match neither place, done when Winna gets the cat)
  local e = T.Wd.entry(SABERS)
  if e then e.objs = { { kind = "e", label = "Corrupted Saber returned", mobs = {}, spots = { { WINNA[1], WINNA[2], WINNA[3], 0 } }, need = 1, have = 0 } } end
  RG.ForgetNextStep(); T.step(1)
  return ok
end
local function current(T)
  T.RG.ForgetQuestSpots(); T.RG.ForgetNextStep()
  local obj = T.RG.Objective(true); T.step(1)
  return obj
end

return {
  {
    name = "places-in-order",
    about = "a quest with two places (release the kitten at the moonwell, then bring the cat to Winna) shows the first, and the second once you've been there",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local d = T.quest(SABERS)
      local kinds = {}
      for _, o in ipairs(d and d.o or {}) do kinds[#kinds + 1] = o[1] end
      T.eq(table.concat(kinds, ","), "e,e", "Corrupted Sabers has two places in the data")
      if not felwood(T, true) then return end
      T.go({ 1448, 34.4, 54.0 })   -- Bloodvenom Post
      local obj = current(T)
      T.ok(obj and obj.wp and T.near(obj.wp, MOONWELL), "first, the moonwell (" .. tostring(obj and obj.wp and (obj.wp[2] .. ", " .. obj.wp[3])) .. ")")
      T.ok(obj and tostring(obj.qline):find("Release the kitten", 1, true), "it says what to do there: " .. tostring(obj and obj.qline))
      T.ok(obj and not tostring(obj.text):find("^Head to"), "not \"Head to Bloodvenom Post\": " .. tostring(obj and obj.text))
      T.go(MOONWELL); T.step(4)
      obj = current(T)
      T.ok(obj and obj.wp and T.near(obj.wp, WINNA), "once you've been there, Winna Hazzard (" .. tostring(obj and obj.wp and (obj.wp[2] .. ", " .. obj.wp[3])) .. ")")
      T.ok(obj and tostring(obj.qline):find("Return the corrupted cat", 1, true), "bring the cat back: " .. tostring(obj and obj.qline))
    end,
    reload = function(T)
      T.RG.SetRouteMode("log", true); T.step(1)
      T.go({ 1448, 40, 60 })
      local obj = current(T)
      T.ok(obj and obj.wp and T.near(obj.wp, WINNA), "after /reload the moonwell stays done: Winna Hazzard (" .. tostring(obj and obj.wp and (obj.wp[2] .. ", " .. obj.wp[3])) .. ")")
      T.ok(T.RG.db.areaSeen and T.RG.db.areaSeen[SABERS], "kept in the saved variables")
      T.work(SABERS)
      local ok = T.handIn(SABERS)
      T.ok(ok, "handed in")
      T.ok(not (T.RG.db.areaSeen and T.RG.db.areaSeen[SABERS]), "and then forgotten")
    end,
  },
  {
    name = "places-quest-in-log-no-place",
    about = "the guide's step is down to a quest in your log with no place known: the card shows that quest and how to do it, not \"Head to the town, its quests start here\"",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      if not felwood(T) then return end
      T.RG.QDATA[SABERS].o = nil   -- (as if the data had no place for it)
      T.go({ 1448, 34.4, 54.0 })
      T.RG.SetRouteMode("guide", true); T.step(1)   -- (the ordered guide: only the quests of the step you're on)
      local r = T.RG.CurrentRouteEntry()
      if not T.eq(r and r.zone, "Felwood", "the guide is on Felwood") then return end
      T.eq(T.RG.NextStep(r), 2, "on Bloodvenom Post's step")
      local obj = current(T)
      T.ok(obj, "there's a current step")
      if not obj then return end
      T.ok(not tostring(obj.text):find("^Head to"), "not \"Head to ...\": " .. tostring(obj.text))
      T.eq(obj.id, SABERS, "it's Corrupted Sabers")
      T.eq(obj.act, "doing", "to do")
      T.ok(not tostring(obj.why):find("start here", 1, true), "not \"its quests start here\": " .. tostring(obj.why))
      T.ok(obj.wp == nil, "no place to point the arrow at")
      T.RG.SyncObjective(obj); T.step(1)
      T.ok(not (T.RG.PinIsOurs and T.RG.PinIsOurs()), "and the guide's pin to the town is gone")
      T.RG.RefreshStepView(); T.step(1)
      local f = T.W.G.WaypathStepView
      local all = {}
      for _, t in ipairs(f and T.W.visibleTexts(f) or {}) do all[#all + 1] = tostring(t) end
      all = table.concat(all, "\n")
      T.ok(all:find("Corrupted Sabers", 1, true), "the card names the quest")
      local lines = {}
      for l in (all .. "\n"):gmatch("(.-)\n") do lines[l] = true end
      T.ok(lines.DO and not lines.GO, "as one to do (DO, not GO): " .. all:gsub("\n", " | "))
    end,
  },
}
