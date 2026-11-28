-- A quest of places (use an item at each) whose game objectives name the thing, not our data's words: Violence Into
-- Verdure in Mount Hyjal ("Use Bag of Enchanted Seeds: the Ruined Ballista" in our data, "Ruined Ballista reclaimed:
-- 0/1" in the game). Seen in play: with two of the three done, the last place (where Celastrus the Bitter also is)
-- showed as Celastrus's stop, the quest only as an "also here" line reading "Kill Ruined Ballista reclaimed".
local GAME = { "Ruined Ballista reclaimed", "Ruined Catapult reclaimed", "Ruined Flying Machine reclaimed" }
local BALLISTA = { 2482, 66.3, 79.2 }

local function entryOf(T, id)
  for _, e in ipairs(T.Wd.state.log) do if e.id == id then return e end end
end

local function setup(T)
  local RG = T.RG
  RG.db.routeGuide = true
  RG.SetRouteMode("log", true)
  T.Wd.state.done[95568] = true
  local ok1, why1 = T.accept(93747)   -- Violence Into Verdure
  local ok2, why2 = T.accept(91923)   -- Celastrus the Bitter: its frond drops at the Ballista too
  T.ok(ok1 and ok2, "both quests accepted (" .. tostring(why1) .. ", " .. tostring(why2) .. ")")
  local e = entryOf(T, 93747)
  if not e then return end
  -- the game's words for the three places
  for i, o in ipairs(e.objs) do o.label = GAME[i] or o.label; o.kind = "o" end
  -- (and of the type the game gave them in play: a creature credit, which the tracker read as "Kill ...")
  local QL = T.W.apis.C_QuestLog
  local get = QL.GetQuestObjectives
  QL.GetQuestObjectives = function(id)
    -- (the quest log showed only the line still to do, "0/1 Ruined Ballista reclaimed", with two places done)
    local out = get(id)
    if id ~= 93747 then return out end
    local left = {}
    for _, o in ipairs(out) do o.type = "monster"; if not o.finished then left[#left + 1] = o end end
    return left
  end
  T.step(4)
  return e
end

-- the place at the Flying Machine done: the game's count goes up
local function useAt(T, e, i)
  local o = e.objs[i]
  T.go(o.spots[1] or BALLISTA)
  o.have = 1
  T.W.fire("QUEST_LOG_UPDATE"); T.W.fire("UNIT_QUEST_LOG_CHANGED", "player")
  T.step(2)
end

-- a tracker line whose text matches (colour codes stripped), and its text
local function strip(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end
local function trackerRow(T, pat)
  local function walk(f)
    for _, c in ipairs({ f:GetChildren() }) do
      local t = rawget(c, "text")
      if c:IsVisible() and t and t.GetText and t:GetText() and strip(t:GetText()):find(pat) and c:GetScript("OnClick") then return c, strip(t:GetText()) end
      local r, s = walk(c)
      if r then return r, s end
    end
  end
  return walk(T.W.G.WaypathTracker)
end

return {
  {
    name = "places-game-words",
    about = "a place's objective in the game's words (\"Ruined Ballista reclaimed\") is the data's place, not a kill of its own",
    race = "Orc", class = "WARRIOR", level = 56,
    run = function(T)
      local RG = T.RG
      local e = setup(T)
      if not e then return end
      useAt(T, e, 2); useAt(T, e, 3)
      local lines = RG.QuestObjectiveLines(93747)
      local texts = {}
      for _, l in ipairs(lines) do texts[#texts + 1] = l.text end
      local s = table.concat(texts, " | ")
      T.ok(not s:find("Kill"), "no objective reads as a kill (" .. s .. ")")
      T.ok(s:find("the Ruined Ballista", 1, true) ~= nil, "the Ballista is the data's place (" .. s .. ")")
    end,
  },
  {
    name = "places-last-one-headline",
    about = "two of the three places done: the last place is the current step, under the quest's own name, though Celastrus is there too",
    race = "Orc", class = "WARRIOR", level = 56,
    run = function(T)
      local RG = T.RG
      local e = setup(T)
      if not e then return end
      useAt(T, e, 2); useAt(T, e, 3)
      local obj = RG.Objective(true); RG.SyncObjective(obj); RG.RefreshTracker(); T.step(1)
      T.ok(obj and obj.id == 93747, "the current step is Violence Into Verdure (" .. tostring(obj and obj.qtitle) .. ": " .. tostring(obj and obj.qline) .. ")")
      T.ok(obj and obj.qline and obj.qline:find("Ruined Ballista", 1, true) ~= nil, "it says the Ballista (" .. tostring(obj and obj.qline) .. ")")
      T.ok(obj and obj.wp and T.near(obj.wp, BALLISTA, 1.5), "and points there")
      T.ok(not T.trackerFind("Kill Ruined"), "no \"Kill Ruined ...\" on the tracker: " .. table.concat(T.tracker(), " | "))
    end,
  },
  {
    name = "stop-quests-own-rows",
    about = "a stop of two quests lists the second on a line of its own; clicking it makes that quest the current step",
    race = "Orc", class = "WARRIOR", level = 56,
    run = function(T)
      local RG = T.RG
      local e = setup(T)
      if not e then return end
      RG.db.zonePick = "Mount Hyjal"; RG.SetRouteMode("zone", true)
      T.go(BALLISTA); T.step(2)
      -- Celastrus heads the Ballista's stop (no progress on the wrecks yet to say otherwise)
      local obj = RG.Objective(true); RG.RefreshTracker(); T.step(1)
      local head = obj and obj.id
      local other = head == 93747 and "Celastrus" or "Ruined Ballista"
      local row, text = trackerRow(T, other)
      T.ok(row ~= nil, "the stop's other quest has a line of its own (" .. other .. "): " .. table.concat(T.tracker(), " | "))
      if not row then return end
      row:GetScript("OnClick")(row, "LeftButton"); T.step(2)
      local now = RG.Objective(true)
      T.ok(now and now.id ~= head and now.id ~= nil, "clicking \"" .. tostring(text) .. "\" makes it the current step (was " .. tostring(obj and obj.qtitle) .. ", now " .. tostring(now and now.qtitle) .. ")")
      T.ok(T.near(T.arrow(), BALLISTA, 3), "and the arrow stays on the stop")
    end,
  },
  {
    name = "more-steps-expand",
    about = "\"+N more steps\" opens the whole list on a click, \"Show fewer steps\" folds it back",
    race = "Orc", class = "WARRIOR", level = 56,
    run = function(T)
      local RG = T.RG
      setup(T)
      for _, id in ipairs({ 95569, 93759, 93830, 96131, 91952 }) do T.Wd.state.done[id] = nil; T.accept(id) end
      RG.db.zonePick = "Mount Hyjal"; RG.SetRouteMode("zone", true)
      T.go(BALLISTA); T.step(2); RG.Objective(true); RG.RefreshTracker(); T.step(1)
      local row, text = trackerRow(T, "^%+%d+ more step")
      if not row then T.ok(true, "fewer than 7 stops here: nothing to expand (" .. #T.tracker() .. " lines)") return end
      local before = #T.tracker()
      row:GetScript("OnClick")(row, "LeftButton"); T.step(1)
      local after = #T.tracker()
      T.ok(after > before and T.trackerFind("Show fewer steps"), "\"" .. text .. "\" opens the list (" .. before .. " -> " .. after .. " lines)")
      local back = trackerRow(T, "Show fewer steps")
      if back then back:GetScript("OnClick")(back, "LeftButton"); T.step(1) end
      T.eq(#T.tracker(), before, "\"Show fewer steps\" folds it back")
    end,
  },
}
