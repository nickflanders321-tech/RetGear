-- A simulated game world for the harness (run.lua --play): where the player stands, their quest log, the quests
-- they've done, XP and levels. It answers the game's quest, map and quest-dialog functions, and keeps the game's
-- rules: you must stand at the quest giver to accept, near an objective to make progress, and at the finisher to
-- hand in; required level, earlier quests in a chain, race and class, and a full quest log all stop an accept.
--
-- Quests come from the add-on's own data (RG.QDATA, Objectives.lua). That data has no objective counts and no XP, so
-- those are made up (KILLS/ITEMS below and questXP): the levels the bot reaches are approximate.
local Wd = {}

local KILLS, ITEMS, OBJECTS = 6, 4, 1   -- how many of each an objective asks for (the data doesn't say)
local NEAR_NPC, NEAR_OBJ = 0.03, 0.06   -- how close (in map fractions) counts as "at" an NPC / an objective spot
local MAX_LOG = 40   -- (WoW Forever's quest log holds 40)
local ZONE_YARDS = { 3500, 2333 }       -- a zone's size, for distances (the real sizes aren't in the repo's data)

-- XP to go from each level to the next (the classic table)
local XPMAX = { 400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8800, 10100, 11400, 12900, 14400, 16000,
  17700, 19400, 21300, 23200, 25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400, 50800, 54500,
  58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700, 95800, 101000, 106300, 111800, 117500, 123200, 129100,
  135100, 141200, 147500, 153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800 }
Wd.XPMAX = XPMAX

local W, G, me, Q, RG
local S = { log = {}, done = {}, killed = {}, xp = 0, map = nil, x = 0.5, y = 0.5, money = 0, dialog = nil, waypoint = nil,
  stats = { accepted = 0, handedIn = 0, autoAccepted = 0, autoHandedIn = 0, kills = 0, questXP = 0, killXP = 0, seconds = 0 } }
Wd.state = S
local zoneName = {}     -- uiMapID -> zone name

local function fire(ev, ...) W.fire(ev, ...) end

-- ---------------------------------------------------------------------------
-- XP and levels
-- ---------------------------------------------------------------------------
local function questXP(q, plvl)
  local base = math.max(40, 95 * (q or plvl) - 150)
  local diff = plvl - (q or plvl)
  if diff <= 5 then return base end
  local f = ({ [6] = 0.8, [7] = 0.6, [8] = 0.4, [9] = 0.2 })[diff] or 0.1
  return math.floor(base * f / 5 + 0.5) * 5
end
local function killXP(mlvl, plvl)
  if mlvl < plvl - 5 then return 0 end
  return math.max(0, math.floor((45 + 5 * mlvl) * (1 + 0.05 * (mlvl - plvl)) + 0.5))
end
function Wd.giveXP(n, from)
  if me.level >= 60 then return end
  S.xp = S.xp + n
  if from == "quest" then S.stats.questXP = S.stats.questXP + n else S.stats.killXP = S.stats.killXP + n end
  while me.level < 60 and S.xp >= XPMAX[me.level] do
    S.xp = S.xp - XPMAX[me.level]
    me.level = me.level + 1
    W.context = "PLAYER_LEVEL_UP (" .. me.level .. ")"
    fire("PLAYER_LEVEL_UP", me.level, 10, 1, 0, 1, 1, 1, 1, 1)
  end
  if me.level >= 60 then S.xp = 0 end
  fire("PLAYER_XP_UPDATE", "player")
end
Wd.killXP = killXP

-- ---------------------------------------------------------------------------
-- Places and moving
-- ---------------------------------------------------------------------------
-- The game's maps (maps.lua from the client's UiMap tables, loaded by run.lua when tools/harness/.cache/maps.lua
-- exists): real names, parents and world positions. Without them every zone is ZONE_YARDS big and on its own.
Wd.mapsData = nil
local function mapName(m)
  local md = Wd.mapsData and Wd.mapsData.maps[m]
  if md then return md[1] end
  if zoneName[m] then return zoneName[m] end
  return "Map " .. tostring(m)
end
Wd.mapName = mapName
-- where a map point (x, y 0-1) is in the world: continent, world x, world y (nil without map data)
local function worldPos(m, x, y)
  local a = Wd.mapsData and Wd.mapsData.at[m]
  if not a then return nil end
  local fu, fv = (x - a[2]) / (a[4] - a[2]), (y - a[3]) / (a[5] - a[3])
  return a[1], a[8] - fv * (a[8] - a[6]), a[9] - fu * (a[9] - a[7])
end
Wd.worldPos = worldPos
-- yards between two points (nil on different continents, or different maps without map data)
function Wd.yards(m1, x1, y1, m2, x2, y2)
  local c1, ax, ay = worldPos(m1, x1, y1)
  local c2, bx, by = worldPos(m2, x2, y2)
  if c1 and c2 then
    if c1 ~= c2 then return nil end
    return math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
  end
  if m1 ~= m2 then return nil end
  local dx, dy = (x2 - x1) * ZONE_YARDS[1], (y2 - y1) * ZONE_YARDS[2]
  return math.sqrt(dx * dx + dy * dy)
end
-- Teleport (the bot walks by calling this a bit at a time). x and y are 0-1.
function Wd.setPos(m, x, y)
  local changed = m ~= S.map
  S.map, S.x, S.y = m, x, y
  if changed then
    W.context = "ZONE_CHANGED_NEW_AREA (" .. mapName(m) .. ")"
    fire("ZONE_CHANGED_NEW_AREA"); fire("ZONE_CHANGED")
  end
end
local function near(spot, dist)
  -- spot = { uiMapID, x 0-100, y 0-100 }
  return spot and spot[1] == S.map and math.abs(spot[2] / 100 - S.x) <= dist and math.abs(spot[3] / 100 - S.y) <= dist
end
Wd.near = near

-- ---------------------------------------------------------------------------
-- Quests
-- ---------------------------------------------------------------------------
local RACE = { Orc = "O", Scourge = "U", Tauren = "T", Troll = "R", Human = "H", Dwarf = "D", NightElf = "N", Gnome = "G" }
local CLASS = { WARRIOR = "W", PALADIN = "P", HUNTER = "H", ROGUE = "R", PRIEST = "I", SHAMAN = "S", MAGE = "M", WARLOCK = "L", DRUID = "D" }
local function raceLetter()
  if me.race == "Skyborne" then return me.faction == "Alliance" and "A" or "S" end
  return RACE[me.race]
end
local function logIndex(id) for i, e in ipairs(S.log) do if e.id == id then return i end end end
local function entry(id) local i = logIndex(id); return i and S.log[i] end
local function complete(e)
  for _, o in ipairs(e.objs) do if o.have < o.need then return false end end
  return true
end
Wd.entry = entry

-- Can this character take quest `id` now? true, or false and why.
function Wd.canAccept(id)
  local d = Q[id]
  if not d then return false, "the game has no quest " .. tostring(id) end
  if S.done[id] then return false, "already done" end
  if entry(id) then return false, "already in the log" end
  if #S.log >= MAX_LOG then return false, "the quest log is full (" .. MAX_LOG .. ")" end
  if d.r and me.level < d.r then return false, "needs level " .. d.r .. " (you are " .. me.level .. ")" end
  if d.mx and me.level > d.mx then return false, "only up to level " .. d.mx end
  if d.ra and not d.ra:find(raceLetter() or "?", 1, true) then return false, "not for this race" end
  if d.cl and not d.cl:find(CLASS[me.class] or "?", 1, true) then return false, "not for this class" end
  for _, p in ipairs(d.pg or {}) do if not S.done[p] then return false, "needs quest " .. p .. (Q[p] and (" (" .. tostring(Q[p].n) .. ")") or "") .. " done first" end end
  if d.ps and #d.ps > 0 then
    local any = false
    for _, p in ipairs(d.ps) do if S.done[p] then any = true end end
    if not any then return false, "needs one of quests " .. table.concat(d.ps, ", ") .. " done first" end
  end
  for _, x in ipairs(d.x or {}) do if S.done[x] or entry(x) then return false, "gone: quest " .. x .. " was taken instead" end end
  if d.nx and (S.done[d.nx] or entry(d.nx)) then return false, "gone: the next quest in the chain is taken" end
  return true
end

local function addToLog(id)
  local d = Q[id]
  local e = { id = id, title = d.n, level = d.l or d.r or me.level, objs = {} }
  for _, o in ipairs(d.o or {}) do
    local kind = o[1]
    local need = kind == "k" and KILLS or kind == "i" and ITEMS or OBJECTS
    e.objs[#e.objs + 1] = { kind = kind, label = o[2] or "?", mobs = o[3] or {}, spots = o[4] or {}, need = need, have = 0 }
  end
  S.log[#S.log + 1] = e
  S.stats.accepted = S.stats.accepted + 1
  local idx = #S.log
  fire("QUEST_ACCEPTED", idx, id)
  fire("QUEST_LOG_UPDATE"); fire("UNIT_QUEST_LOG_CHANGED", "player")
  return e
end

local function removeFromLog(id)
  local i = logIndex(id)
  if i then table.remove(S.log, i) end
end

-- hooks for inventory.lua (items): a reward chosen at hand-in, an objective done, the reward window opening
Wd.hooks = {}
local function turnIn(id, choice)
  local e = entry(id)
  local d = Q[id]
  if Wd.hooks.turnIn then Wd.hooks.turnIn(id, choice, e) end
  local xp = questXP(e and e.level or (d and d.l), me.level)
  local money = math.max(0, (d and d.l or 1) * 25)
  removeFromLog(id)
  S.done[id] = true
  S.money = S.money + money
  S.stats.handedIn = S.stats.handedIn + 1
  fire("QUEST_TURNED_IN", id, xp, money)
  fire("QUEST_REMOVED", id)
  fire("QUEST_LOG_UPDATE"); fire("UNIT_QUEST_LOG_CHANGED", "player")
  fire("PLAYER_MONEY")
  Wd.giveXP(xp, "quest")
end

-- Talk to the giver: the quest window opens (QUEST_DETAIL); the add-on may accept on its own (auto-accept),
-- otherwise the player presses Accept. Returns true, or false and why.
-- Quests that start from an object or an item (no NPC giver): where they begin (starters.lua, from QuestieDB), loaded
-- by run.lua when tools/harness/.cache/starters.lua exists. One with no known place is "found on the way" anywhere.
Wd.starters = {}
function Wd.starterSpot(id)
  local st = Wd.starters[id]
  return st and st.s and st.s[1] or nil
end
-- (fromBag: a quest started from an item in your bags, looted earlier: it can be taken anywhere)
function Wd.accept(id, fromBag)
  local d = Q[id]
  if not d then return false, "the game has no quest " .. tostring(id) end
  if d.s and not near(d.s, NEAR_NPC) then return false, "not at the quest giver" end
  if not d.s and not fromBag then
    local st = Wd.starters[id]
    if st and st.s and #st.s > 0 then
      local here = false
      for _, sp in ipairs(st.s) do if near(sp, NEAR_OBJ) then here = true end end
      if not here then return false, "not where it starts (" .. (st.k == "o" and "an object" or "a dropped item") .. ")" end
    end
  end
  local ok, why = Wd.canAccept(id)
  if not ok then return false, why end
  S.dialog = { id = id, stage = "detail" }
  W.context = "QUEST_DETAIL (" .. tostring(d.n) .. ")"
  fire("QUEST_DETAIL")
  if S.dialog and not S.dialog.accepted then G.AcceptQuest() else S.stats.autoAccepted = S.stats.autoAccepted + 1 end
  S.dialog = nil
  fire("QUEST_FINISHED")
  return entry(id) ~= nil or S.done[id] == true, "the quest window didn't accept it"
end

-- Work on a quest's objectives here: every objective with a spot near the player is done (kills give XP).
-- Returns how many objectives moved, and the seconds it took.
function Wd.work(id)
  local e = entry(id)
  if not e then return 0, 0 end
  local moved, secs = 0, 0
  for _, o in ipairs(e.objs) do
    if o.have < o.need then
      local here = #o.spots == 0
      for _, sp in ipairs(o.spots) do if near(sp, NEAR_OBJ) then here = true break end end
      if here then
        local mobs = #o.mobs > 0 and o.kind ~= "o"
        local tries = o.kind == "i" and mobs and (o.need - o.have) * 2 or (o.need - o.have)
        for _ = 1, tries do
          if mobs then
            S.stats.kills = S.stats.kills + 1
            -- (kills by mob name, for what they drop: an objective with several mobs counts each kill for each of them)
            for _, m in ipairs(o.mobs) do S.killed[m] = (S.killed[m] or 0) + 1 end
            Wd.giveXP(killXP(e.level, me.level), "kill")
            secs = secs + 25
          else
            secs = secs + 8
          end
        end
        if Wd.hooks.objective then Wd.hooks.objective(e, o, o.need - o.have) end
        o.have = o.need
        moved = moved + 1
        W.context = "UI_INFO_MESSAGE (" .. o.label .. ")"
        fire("UI_INFO_MESSAGE", 0, string.format("%s: %d/%d", o.label, o.have, o.need))
        fire("QUEST_WATCH_UPDATE", logIndex(id))
        fire("QUEST_LOG_UPDATE"); fire("UNIT_QUEST_LOG_CHANGED", "player")
      end
    end
  end
  return moved, secs
end

-- Hand in at the finisher: QUEST_PROGRESS, then QUEST_COMPLETE (the add-on may click through on its own).
function Wd.handIn(id)
  local e, d = entry(id), Q[id]
  if not e then return false, "not in the quest log" end
  if not complete(e) then return false, "not complete" end
  if d and d.e and not near(d.e, NEAR_NPC) then return false, "not at the finisher" end
  S.dialog = { id = id, stage = "progress" }
  W.context = "QUEST_PROGRESS (" .. tostring(e.title) .. ")"
  fire("QUEST_PROGRESS")
  if S.dialog and S.dialog.stage == "progress" then G.CompleteQuest() end
  -- the reward window is open: give the add-on a moment (it may be waiting for the rewards' item data)
  if S.dialog and S.dialog.stage == "complete" and not S.dialog.rewarded then W.step(1.5, 10) end
  if S.dialog and S.dialog.stage == "complete" and not S.dialog.rewarded then
    S.dialog.botPicked = true
    G.GetQuestReward(Wd.hooks.pickReward and Wd.hooks.pickReward(id) or 1)
  elseif S.dialog and S.dialog.rewarded then S.stats.autoHandedIn = S.stats.autoHandedIn + 1 end
  S.dialog = nil
  fire("QUEST_FINISHED")
  return S.done[id] == true, "the quest window didn't hand it in"
end

-- the spot of a quest's first unfinished objective (the world's own knowledge, for when the guide gives none)
function Wd.objectiveSpot(id)
  local e = entry(id)
  if not e then return nil end
  for _, o in ipairs(e.objs) do
    if o.have < o.need and o.spots[1] then return o.spots[1] end
  end
end

-- ---------------------------------------------------------------------------
-- The game's functions, answered from the world
-- ---------------------------------------------------------------------------
function Wd.install(w)
  W, G, me = w, w.G, w.me
  S.map = me.map
  local A = W.apis
  local QL = A.C_QuestLog
  local function info(i)
    local e = S.log[i]
    if not e then return nil end
    return { title = e.title, questID = e.id, level = e.level, isHeader = false, suggestedGroup = 0, isComplete = complete(e) and 1 or nil,
      frequency = 0, isTask = false, isHidden = false, isOnMap = true, hasLocalPOI = false, isCollapsed = false, startEvent = false }
  end
  local function objectives(id)
    local e = entry(id)
    if not e then return {} end
    local out = {}
    for _, o in ipairs(e.objs) do
      local t = o.kind == "k" and (o.label .. " slain") or o.label
      out[#out + 1] = { text = string.format("%s: %d/%d", t, o.have, o.need), type = o.kind == "k" and "monster" or o.kind == "i" and "item" or o.kind == "e" and "event" or "object",
        finished = o.have >= o.need, numFulfilled = o.have, numRequired = o.need }
    end
    return out
  end
  -- S.collapsed: the whole log under one zone header you've collapsed (the game then lists only the header)
  QL.GetNumQuestLogEntries = function() if S.collapsed then return 1, #S.log end return #S.log, #S.log end
  QL.GetInfo = function(i)
    if S.collapsed then return i == 1 and { title = "Winterspring", isHeader = true, isCollapsed = true } or nil end
    return info(i)
  end
  QL.IsComplete = function(id) local e = entry(id); return e and complete(e) or false end
  QL.IsOnQuest = function(id) return entry(id) ~= nil end
  QL.GetQuestObjectives = objectives
  -- the quest log's selected entry, and its text (the objectives summary: made up from the objectives here)
  G.SelectQuestLogEntry = function(i) S.selected = i end
  G.GetQuestLogSelection = function() return S.selected or 0 end
  G.GetQuestLogQuestText = function(i)
    local e = S.log[i or S.selected or 0]
    if not e then return "", "" end
    local what = {}
    for _, o in ipairs(e.objs) do what[#what + 1] = o.need .. " " .. o.label end
    return "The story of " .. e.title .. ".", "Bring back " .. table.concat(what, " and ") .. " for " .. e.title .. "."
  end
  QL.IsQuestFlaggedCompleted = function(id) return S.done[id] == true end
  QL.GetAllCompletedQuestIDs = function() local t = {}; for id in pairs(S.done) do t[#t + 1] = id end table.sort(t) return t end
  QL.GetTitleForQuestID = function(id) local d = Q and Q[id]; return d and d.n end
  QL.GetLogIndexForQuestID = function(id) return logIndex(id) end
  QL.GetQuestIDForLogIndex = function(i) return S.log[i] and S.log[i].id end
  QL.RequestLoadQuestByID = function(id) G.C_Timer.After(0, function() fire("QUEST_DATA_LOAD_RESULT", id, true) end) end
  QL.IsRepeatableQuest = function() return false end
  QL.GetMaxNumQuestsCanAccept = function() return MAX_LOG end
  QL.GetQuestTagInfo = function() return nil end
  QL.GetNextWaypoint = function() return nil end
  -- the older quest log functions
  G.GetNumQuestLogEntries = function() return #S.log, #S.log end
  G.GetQuestLogTitle = function(i)
    local e = S.log[i]
    if not e then return nil end
    return e.title, e.level, 0, false, false, complete(e) and 1 or nil, 0, e.id
  end
  G.GetQuestLogIndexByID = logIndex
  G.IsQuestComplete = function(id) local e = entry(id); return e and complete(e) or false end
  G.IsUnitOnQuest = function() return false end
  G.GetQuestsCompleted = function(t) t = t or {}; for id in pairs(S.done) do t[id] = true end return t end
  G.GetNumQuestLeaderBoards = function(i) local e = S.log[i or 0]; return e and #e.objs or 0 end
  G.GetQuestLogLeaderBoard = function(j, i)
    local e = S.log[i or 0]
    local o = e and e.objs[j]
    if not o then return nil end
    return string.format("%s: %d/%d", o.label, o.have, o.need), o.kind == "k" and "monster" or o.kind == "i" and "item" or o.kind == "e" and "event" or "object", o.have >= o.need
  end
  -- the quest window (talking to a giver or finisher)
  G.GetQuestID = function() return S.dialog and S.dialog.id or 0 end
  G.GetTitleText = function() local d = S.dialog and Q[S.dialog.id]; return d and d.n or "" end
  G.AcceptQuest = function()
    local dlg = S.dialog
    if not (dlg and dlg.stage == "detail") then return end
    dlg.accepted = true
    if Wd.canAccept(dlg.id) then addToLog(dlg.id) end
  end
  G.DeclineQuest = function() S.dialog = nil end
  G.IsQuestCompletable = function() local e = S.dialog and entry(S.dialog.id); return e and complete(e) or false end
  G.CompleteQuest = function()
    local dlg = S.dialog
    if not (dlg and dlg.stage == "progress") then return end
    dlg.stage = "complete"
    if Wd.hooks.rewardWindow then Wd.hooks.rewardWindow(dlg.id) end
    W.context = "QUEST_COMPLETE"
    fire("QUEST_COMPLETE")
  end
  G.GetQuestReward = function(choice)
    local dlg = S.dialog
    if not (dlg and dlg.stage == "complete") or dlg.rewarded then return end
    -- with reward choices, the game won't hand in until one is picked
    local n = G.GetNumQuestChoices()
    if n > 1 and not (tonumber(choice) and choice >= 1 and choice <= n) then return end
    dlg.rewarded = true
    dlg.pickedBy = dlg.botPicked and "bot" or "add-on"
    turnIn(dlg.id, tonumber(choice))
  end
  G.GetNumQuestChoices = function() return 0 end
  G.GetNumQuestRewards = function() return 0 end
  G.GetQuestMoneyToGet = function() return 0 end
  G.QuestGetAutoAccept = function() return false end
  G.CloseQuest = function() S.dialog = nil end
  -- the character
  G.UnitXP = function(u) return (u == "player") and S.xp or 0 end
  G.UnitXPMax = function(u) return (u == "player") and (XPMAX[me.level] or 0) or 0 end
  G.GetMoney = function() return S.money end
  G.GetZoneText = function() return mapName(S.map) end
  G.GetRealZoneText = G.GetZoneText
  G.GetMinimapZoneText = G.GetZoneText
  -- maps: every zone is ZONE_YARDS big and its own "continent" (the real layout isn't in the repo)
  local CM = A.C_Map
  CM.GetBestMapForUnit = function(u) if u == "player" then return S.map end end
  CM.GetPlayerMapPosition = function(m, u) if u == "player" and m == S.map then return G.CreateVector2D(S.x, S.y) end end
  CM.GetWorldPosFromMapPos = function(m, pos)
    if not (m and pos) then return nil end
    local c, wx, wy = worldPos(m, pos.x, pos.y)
    if c then return c, G.CreateVector2D(wx, wy) end
    return m, G.CreateVector2D(pos.x * ZONE_YARDS[1], pos.y * ZONE_YARDS[2])
  end
  CM.GetMapInfo = function(m)
    if not m then return nil end
    local md = Wd.mapsData and Wd.mapsData.maps[m]
    if md then return { mapID = m, name = md[1], parentMapID = md[2], mapType = md[3] } end
    if m == 1414 or m == 1415 or m == 947 then return { mapID = m, name = m == 1415 and "Eastern Kingdoms" or "Kalimdor", mapType = 2, parentMapID = 947 } end
    return { mapID = m, name = mapName(m), mapType = 3, parentMapID = 1414 }
  end
  CM.SetUserWaypoint = function(p) S.waypoint = p end
  CM.GetUserWaypoint = function() return S.waypoint end
  CM.HasUserWaypoint = function() return S.waypoint ~= nil end
  CM.ClearUserWaypoint = function() S.waypoint = nil end
end

-- Once the add-on has loaded: its quest data and zone names.
function Wd.attach(rg)
  RG = rg
  Q = RG.QDATA or {}
  for z, m in pairs(RG.ZONE_MAPS or {}) do zoneName[m] = z end
  for m, z in pairs({ [1454] = "Orgrimmar", [1456] = "Thunder Bluff", [1458] = "Undercity", [1453] = "Stormwind City", [1455] = "Ironforge", [1457] = "Darnassus" }) do zoneName[m] = z end
end
function Wd.quest(id) return Q[id] end

-- What the game's servers keep across a /reload (quests done, the log, level, place, money, the map pin).
function Wd.snapshot()
  local done = {}
  for id in pairs(S.done) do done[#done + 1] = id end
  local wp = S.waypoint and { m = S.waypoint.uiMapID, x = S.waypoint.position and S.waypoint.position.x, y = S.waypoint.position and S.waypoint.position.y }
  return { done = done, log = S.log, xp = S.xp, level = me.level, map = S.map, x = S.x, y = S.y, money = S.money, waypoint = wp }
end
function Wd.restore(t)
  if not t then return end
  S.done = {}
  for _, id in ipairs(t.done or {}) do S.done[id] = true end
  S.log = t.log or {}
  for _, e in ipairs(S.log) do for _, o in ipairs(e.objs or {}) do o.mobs, o.spots = o.mobs or {}, o.spots or {} end end
  S.xp, me.level, S.money = t.xp or 0, t.level or me.level, t.money or 0
  S.map, S.x, S.y = t.map or S.map, t.x or S.x, t.y or S.y
  if t.waypoint and t.waypoint.m then S.waypoint = G.UiMapPoint.CreateFromCoordinates(t.waypoint.m, t.waypoint.x, t.waypoint.y) end
end

return Wd
