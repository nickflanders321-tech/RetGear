-- Waypath+ speed tools (ideas from RestedXP and other speed-leveling addons):
-- auto accept/turn-in with smart rewards, a quest-mob targeting macro and
-- bar, quest item buttons, quest mob nameplate alerts, a waypoint arrow,
-- leveling pace per level, and a bag-space reminder.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local GOLDC = { 0.31, 0.82, 0.77 }

for _, o in ipairs({
  { key = "autoQuest",     label = "Auto accept and turn in quests (hold Shift to pause)", default = true },
  { key = "autoReward",    label = "Auto pick quest rewards when the choice is clear", default = true },
  { key = "nameplateAlert", label = "Tell me when a quest mob shows up nearby", default = true },
  { key = "arrow",         label = "Arrow to my map pin (/wp way 45 60)", default = true },
  { key = "spf",           label = "Let Shortest Path Forever give walking directions (when it is installed)", default = true },
  { key = "autoArrow",     label = "Arrow follows my next route step automatically", default = true },
  { key = "newQuests",     label = "Show new quests I can pick up nearby", default = true },
  { key = "compactTracker", label = "Keep the tracker short (fewer lines: quests near you first, a one-line fishing readout)", default = true },
  { key = "mapClicks",     label = "Let map clicks drive the arrow (quests picked on the map, minimap Ctrl-click, Questie and TomTom pins)", default = true },
  { key = "bagReminder",   label = "Warn me before my bags fill up", default = true },
}) do table.insert(RG.OPTIONS, o) end

local function combat() return InCombatLockdown and InCombatLockdown() end
local pendingAfterCombat = {}
local function afterCombat(key, fn) if combat() then pendingAfterCombat[key] = fn else fn() end end

-- ===========================================================================
-- 1. Auto accept / turn in
-- ===========================================================================
local paused = false -- set when the game refuses (full quest log, full bags)
local function auto() return RG.Opt("autoQuest") and not paused and not (IsShiftKeyDown and IsShiftKeyDown()) end

local function onGossip()
  if not auto() or not C_GossipInfo then return end
  for _, q in ipairs(C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or {}) do
    if q.isComplete then C_GossipInfo.SelectActiveQuest(q.questID); return end
  end
  for _, q in ipairs(C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests() or {}) do
    if not q.isTrivial and not q.repeatable then C_GossipInfo.SelectAvailableQuest(q.questID); return end
  end
end
local function onGreeting()
  if not auto() then return end
  for i = 1, (GetNumActiveQuests and GetNumActiveQuests() or 0) do
    local _, complete = GetActiveTitle(i)
    if complete then SelectActiveQuest(i); return end
  end
  for i = 1, (GetNumAvailableQuests and GetNumAvailableQuests() or 0) do
    local trivial, _, repeatable
    if GetAvailableQuestInfo then trivial, _, repeatable = GetAvailableQuestInfo(i) end
    if not trivial and not repeatable then SelectAvailableQuest(i); return end
  end
end
local function onDetail()
  if not auto() then return end
  if QuestGetAutoAccept and QuestGetAutoAccept() then if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end return end
  AcceptQuest()
end
local function onProgress()
  if not auto() then return end
  if GetQuestMoneyToGet and GetQuestMoneyToGet() > 0 then return end -- costs gold: you decide
  if IsQuestCompletable and IsQuestCompletable() then CompleteQuest() end
end
local function onComplete(retry)
  if not auto() then return end
  local n = GetNumQuestChoices and GetNumQuestChoices() or 0
  if n <= 1 then GetQuestReward(n == 1 and 1 or nil); return end
  if not RG.Opt("autoReward") or not RG.ScoreRewards then return end
  local r = RG.ScoreRewards()
  if r.unknown and not retry then C_Timer.After(0.6, function() onComplete(true) end); return end
  if r.unknown then return end
  local pick, why
  if r.upI and (not r.healI or r.healI == r.upI) then pick, why = r.upI, string.format("+%.0f %s", r.up, RG.SCORE_NAME)
  elseif not r.upI and not r.healI and r.goldI then pick, why = r.goldI, "sells for the most"
  end
  if pick then
    RG.Print("Picked " .. (GetQuestItemLink("choice", pick) or "a reward") .. GREY .. " (" .. why .. ")|r")
    GetQuestReward(pick)
  elseif r.upI and r.healI then
    RG.Print("Your call: " .. (GetQuestItemLink("choice", r.upI) or "") .. " is an upgrade for you, " .. (GetQuestItemLink("choice", r.healI) or "") .. " is an upgrade for your " .. (RG.SecondSpecName and RG.SecondSpecName() or "2nd spec") .. " set.")
  end
end

-- ===========================================================================
-- 2. Quest mobs: targeting macro + bar + nameplate alerts
-- ===========================================================================
local function questTargets()
  local names, seen = {}, {}
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return names end
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHeader and info.questID and not (C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)) then
      for _, o in ipairs(C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(info.questID) or {}) do
        if o.type == "monster" and not o.finished and o.text then
          local name = o.text:match("^(.-) slain:") or o.text:match("^(.-):%s*%d")
          if name and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = { name = name, have = o.numFulfilled, need = o.numRequired, quest = info.title }
          end
        end
      end
    end
  end
  -- "collect X" objectives: target the mobs that drop it (QuestieDB Forever data)
  if RG.QDATA then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      local qd = info and not info.isHeader and info.questID and RG.QDATA[info.questID]
      if qd and qd.o and not (C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)) then
        for _, o in ipairs(C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(info.questID) or {}) do
          if not o.finished and o.text and o.type ~= "monster" then
            for _, d in ipairs(qd.o) do
              if d[1] == "i" and o.text:find(d[2], 1, true) then
                for _, mob in ipairs(d[3]) do
                  if not seen[mob] then
                    seen[mob] = true
                    names[#names + 1] = { name = mob, have = o.numFulfilled, need = o.numRequired, quest = info.title, drop = d[2] }
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return names
end
RG.QuestTargets = questTargets

-- ---------------------------------------------------------------------------
-- Nearest quest objective / turn-in (QuestieDB Forever coordinates)
-- ---------------------------------------------------------------------------
local function toWorld(map, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos) then return nil end
  local v = CreateVector2D and CreateVector2D(x / 100, y / 100) or { x = x / 100, y = y / 100 }
  local ok, cont, wp = pcall(C_Map.GetWorldPosFromMapPos, map, v)
  if not ok or not wp then return nil end
  return cont, wp.x, wp.y
end
local function playerWorld()
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return nil end
  return toWorld(map, pos.x * 100, pos.y * 100)
end
RG.ToWorld, RG.PlayerWorld = toWorld, playerWorld
-- Every place you could go right now: unfinished objectives and quests ready to turn in.
function RG.QuestSpots()
  local spots = {}
  if not (RG.QDATA and C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return spots end
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    local qd = info and not info.isHeader and info.questID and RG.QDATA[info.questID]
    if qd then
      if C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) then
        if qd.e then spots[#spots + 1] = { turnin = true, quest = info.title, label = qd.e[4], wp = { qd.e[1], qd.e[2], qd.e[3], qd.e[4] ~= "" and qd.e[4] or info.title } } end
      elseif qd.o then
        local objs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(info.questID) or {}
        for _, d in ipairs(qd.o) do
          local game
          for _, o in ipairs(objs) do if o.text and o.text:find(d[2], 1, true) then game = o end end
          if not (game and game.finished) then
            for _, p in ipairs(d[4]) do
              local src = d[3][p[4]] or d[2]
              spots[#spots + 1] = { quest = info.title, label = d[2], src = src, have = game and game.numFulfilled, need = game and game.numRequired,
                wp = { p[1], p[2], p[3], (d[1] == "i" and (d[2] .. " (" .. src .. ")") or d[2]) } }
            end
          end
        end
      end
    end
  end
  return spots
end
-- Quests you can pick up: high enough level, not done, not in your log, prerequisites met.
-- Rebuilt when you level, turn in or accept quests (it checks a couple of thousand quests).
local availCache, availDirty = nil, true
function RG.MarkQuestsDirty() availDirty = true end
local function done(id) return C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) end
local function availableQuests()
  if not availDirty and availCache then return availCache end
  availDirty = false
  local list, inLog = {}, {}
  if not (RG.QDATA and C_QuestLog) then availCache = list; return list end
  for i = 1, (C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0) do
    local info = C_QuestLog.GetInfo(i)
    if info and info.questID then inLog[info.questID] = true end
  end
  local lvl = UnitLevel("player")
  for id, d in pairs(RG.QDATA) do
    if d.s and d.n and lvl >= (d.r or 1) and (d.l or 1) >= lvl - 5 and (d.l or 1) <= lvl + 3 and not inLog[id] and not done(id) and RG.QuestForMe(d) then
      local ok = true
      if d.x then for _, p in ipairs(d.x) do if done(p) or inLog[p] then ok = false break end end end
      if d.pg then for _, p in ipairs(d.pg) do if not done(p) then ok = false break end end end
      if ok and d.ps then ok = false; for _, p in ipairs(d.ps) do if done(p) then ok = true break end end end
      if ok then list[#list + 1] = { id = id, name = d.n, lvl = d.l, giver = d.s[4], wp = { d.s[1], d.s[2], d.s[3], d.s[4] ~= "" and d.s[4] or d.n } } end
    end
  end
  -- quests the game has shown you that our data does not know (new WoW Forever content): remembered from when you talked to the giver
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  for id, g in pairs((RG.db and RG.db.givers) or {}) do
    local ql = g.l or lvl
    if type(g) == "table" and g.m and not inLog[id] and not done(id) and not (RG.QDATA and RG.QDATA[id] and RG.QDATA[id].s)
       and ql >= lvl - 5 and ql <= lvl + 3 and (not g.f or g.f == faction) then
      list[#list + 1] = { id = id, name = g.n, lvl = ql, giver = g.g, wp = { g.m, g.x, g.y, g.g or g.n }, learned = true }
    end
  end
  availCache = list
  return list
end
RG.AvailableQuests = availableQuests

-- Quests the game itself marks as available on this map (quest-line starters and offers), for givers our data lacks.
local function offeredOnMap()
  local out = {}
  if not (C_Map and C_Map.GetBestMapForUnit) then return out end
  local map, guard = C_Map.GetBestMapForUnit("player"), 0
  local inLog = {}
  for i = 1, (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0) do
    local info = C_QuestLog.GetInfo(i)
    if info and info.questID then inLog[info.questID] = true end
  end
  local lvl = UnitLevel("player") or 1
  while map and map > 0 and guard < 3 do
    if C_QuestLine and C_QuestLine.GetAvailableQuestLines then
      local ok, list = pcall(C_QuestLine.GetAvailableQuestLines, map)
      if ok and type(list) == "table" then
        for _, e in ipairs(list) do
          local id = e.questID
          if id and e.x and e.y and not inLog[id] and not done(id) and not (RG.QDATA and RG.QDATA[id] and RG.QDATA[id].s) then
            local ql = lvl
            if C_QuestLog.GetQuestDifficultyLevel then local ok2, v = pcall(C_QuestLog.GetQuestDifficultyLevel, id); if ok2 and type(v) == "number" and v > 0 then ql = v end end
            if ql >= lvl - 5 and ql <= lvl + 3 then
              out[#out + 1] = { id = id, name = e.questName or ("Quest " .. id), lvl = ql, giver = nil, wp = { map, e.x * 100, e.y * 100, e.questName or "Quest giver" } }
            end
          end
        end
      end
    end
    local inf = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    map = inf and inf.parentMapID; guard = guard + 1
  end
  return out
end

-- Your class quests from the quest database (every class, including Forever's
-- new ones): the ones you can take now, then the next ones coming up (up to
-- 3 levels ahead), lowest level first. Raid tier-set turn-ins are left out.
local classCache, classDirty = nil, true
function RG.ClassQuests(max)
  if classDirty or not classCache then
    classDirty = false
    local list, inLog = {}, {}
    if RG.QDATA and C_QuestLog then
      for i = 1, (C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0) do
        local info = C_QuestLog.GetInfo(i)
        if info and info.questID then inLog[info.questID] = true end
      end
      local lvl = UnitLevel("player")
      for id, d in pairs(RG.QDATA) do
        if d.cq and d.s and d.n and (d.r or 1) < 58 and (d.r or 1) <= lvl + 3 and (d.l or 1) >= lvl - 8 and not inLog[id] and not done(id) and RG.QuestForMe(d) then
          local ok = true
          if d.x then for _, p in ipairs(d.x) do if done(p) or inLog[p] then ok = false break end end end
          if ok and d.pg then for _, p in ipairs(d.pg) do if not (done(p) or inLog[p]) then ok = false break end end end
          if ok and d.ps then ok = false; for _, p in ipairs(d.ps) do if done(p) or inLog[p] then ok = true break end end end
          if ok then
            list[#list + 1] = { id = id, name = d.n, lvl = d.l, req = d.r or 1, now = lvl >= (d.r or 1), giver = d.s[4],
              wp = { d.s[1], d.s[2], d.s[3], d.s[4] ~= "" and d.s[4] or d.n } }
          end
        end
      end
      table.sort(list, function(a, b) if a.now ~= b.now then return a.now end if a.req ~= b.req then return a.req < b.req end return a.id < b.id end)
    end
    classCache = list
  end
  local out = {}
  for i = 1, math.min(max or #classCache, #classCache) do out[i] = classCache[i] end
  return out
end
local markBase = RG.MarkQuestsDirty
function RG.MarkQuestsDirty() classDirty = true; markBase() end
function RG.IgnoreQuest(id) if id and RG.db then RG.db.ignoredQuests = RG.db.ignoredQuests or {}; RG.db.ignoredQuests[id] = true; RG.MarkQuestsDirty(); RG.Print("Won't suggest that quest again. " .. "/wp unhide brings them all back.") end end
-- Nearest few quest givers with something for you, on your continent.
function RG.NearbyNewQuests(max, valued)
  if not RG.Opt("newQuests") then return {} end
  local c, px, py = playerWorld()
  if not c then return {} end
  local out = {}
  local seen = {}
  local ign = RG.db and RG.db.ignoredQuests or {}
  local function take(q)
    if seen[q.id] or ign[q.id] then return end
    local c2, x, y = toWorld(q.wp[1], q.wp[2], q.wp[3])
    if c2 == c and x then seen[q.id] = true; q.dist = math.sqrt((x - px) ^ 2 + (y - py) ^ 2); q.x, q.y = x, y; out[#out + 1] = q end
  end
  for _, q in ipairs(availableQuests()) do take(q) end
  for _, q in ipairs(offeredOnMap()) do take(q) end
  -- rank by what the quest is worth for the distance: yellow and orange quests first, grey ones last,
  -- quests that open a chain or sit in a busy hub (several givers close together) a little higher
  local W = { [0] = 0.12, [1] = 0.3, [2] = 0.6, [3] = 0.9, [4] = 1.0 }
  for _, q in ipairs(out) do
    local rank = 2
    if RG.QuestWorth and q.lvl then local _, _, _, r = RG.QuestWorth(q.lvl, nil, q.id); rank = r or 2 end
    local hub = 0
    for _, o in ipairs(out) do
      if o ~= q and (o.x - q.x) ^ 2 + (o.y - q.y) ^ 2 <= 150 * 150 then hub = hub + 1 end
    end
    q.rank = rank
    q.score = (W[rank] or 0.6) * (1 + 0.12 * math.min(hub, 4)) / (q.dist + 250)
  end
  table.sort(out, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.dist < b.dist end)
  if valued then   -- the planner only wants quests worth walking to
    for i = #out, 1, -1 do if out[i].rank == 0 then table.remove(out, i) end end
  end
  for i = #out, (max or 2) + 1, -1 do out[i] = nil end
  return out
end

-- ---------------------------------------------------------------------------
-- Quest levels and your quest list (for the tracker)
-- ---------------------------------------------------------------------------
-- Quest level by title, from the quest database (built once, on first use).
local levelByName
function RG.QuestLevel(title)
  if not title then return nil end
  if not levelByName then
    levelByName = {}
    for _, d in pairs(RG.QDATA or {}) do
      if d.n and d.l then
        local k = d.n:lower()
        if not levelByName[k] or d.l < levelByName[k] then levelByName[k] = d.l end
      end
    end
  end
  return levelByName[(title:gsub("%s*%(.-%)$", "")):lower()]
end

-- The game's quest colors: red (far above you), orange, yellow, green, grey (no XP).
function RG.QuestColor(level)
  local lvl = UnitLevel("player") or 1
  level = level or lvl
  local d = level - lvl
  if d >= 5 then return "|cffff1a1a" end
  if d >= 3 then return "|cffff8040" end
  if d >= -2 then return "|cffffff00" end
  local grey = lvl <= 5 and 0 or (lvl <= 39 and (lvl - 5 - math.floor(lvl / 10)) or (lvl - 1 - math.floor(lvl / 5)))
  if level > grey then return "|cff40c040" end
  return "|cff808080"
end
-- "[30]" in the quest's color.
function RG.LevelTag(level)
  if not level or level <= 0 then return "" end
  return RG.QuestColor(level) .. "[" .. level .. "]|r "
end

function RG.FormatYards(d)
  if not d then return nil end
  if d >= 1000 then return string.format("%.1fk yd", d / 1000) end
  return string.format("%d yd", math.floor(d + 0.5))
end

-- Every quest in your log: level, progress, whether it's ready, and the
-- nearest place to work on it (objective or turn-in) with its distance.
-- Ready quests first, then nearest, then the rest by level.
-- Where the game itself says a finished quest is handed in (for quests our data does not know yet).
local function liveTurnIn(qid, title)
  if C_QuestLog and C_QuestLog.GetNextWaypoint then
    local ok, m, x, y = pcall(C_QuestLog.GetNextWaypoint, qid)
    if ok and m and x and y then return { m, x * 100, y * 100, title } end
  end
  if C_QuestLog and C_QuestLog.GetQuestsOnMap and C_Map and C_Map.GetBestMapForUnit then
    local map, guard = C_Map.GetBestMapForUnit("player"), 0
    while map and map > 0 and guard < 6 do
      local ok, list = pcall(C_QuestLog.GetQuestsOnMap, map)
      if ok and type(list) == "table" then
        for _, e in ipairs(list) do
          if e.questID == qid and e.x and e.y then return { map, e.x * 100, e.y * 100, title } end
        end
      end
      local inf = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
      map = inf and inf.parentMapID; guard = guard + 1
    end
  end
  -- last resort: Questie's own database, when it is installed
  if RG.QuestieWaypoint then
    local w = RG.QuestieWaypoint(qid, "finish")
    if w then return { w[1], w[2], w[3], title or w[4] } end
  end
end
RG.QuestTurnInPoint = liveTurnIn

function RG.MyQuests()
  local out = {}
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return out end
  local c, px, py = playerWorld()
  local near = {}
  if c then
    for _, sp in ipairs(RG.QuestSpots()) do
      local c2, x, y = toWorld(sp.wp[1], sp.wp[2], sp.wp[3])
      if c2 == c then
        local dd = math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
        local cur = near[sp.quest]
        if not cur or dd < cur.dist then near[sp.quest] = { dist = dd, wp = sp.wp, label = sp.label } end
      end
    end
  end
  local zone
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    if info and info.isHeader then zone = info.title
    elseif info and info.title and info.questID then
      local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) and true or false
      local objs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(info.questID) or {}
      local prog, total, doneN
      total, doneN = #objs, 0
      for _, o in ipairs(objs) do
        if o.finished then doneN = doneN + 1
        elseif not prog and o.numRequired and o.numRequired > 0 then prog = string.format("%d/%d", o.numFulfilled or 0, o.numRequired) end
      end
      if not prog and total > 1 and not complete then prog = doneN .. "/" .. total end
      local n = near[info.title]
      local qd = RG.QDATA and RG.QDATA[info.questID]
      local level = (info.level and info.level > 0 and info.level) or (qd and qd.l) or RG.QuestLevel(info.title)
      -- a finished quest always knows where to hand in: the quest data's finisher, even on another continent
      if complete and qd and qd.e and qd.e[1] then
        local ewp = { qd.e[1], qd.e[2], qd.e[3], qd.e[4] or info.title }
        local d
        local c2, x, y = toWorld(ewp[1], ewp[2], ewp[3])
        if c and c2 == c then d = math.sqrt((x - px) ^ 2 + (y - py) ^ 2) end
        n = { dist = d, wp = ewp, label = ewp[4] }
      end
      if complete and not (n and n.wp) then
        local lw = liveTurnIn(info.questID, info.title)
        if lw then
          local d
          local c2, x, y = toWorld(lw[1], lw[2], lw[3])
          if c and c2 == c then d = math.sqrt((x - px) ^ 2 + (y - py) ^ 2) end
          n = { dist = d, wp = lw, label = lw[4] }
        end
      end
      out[#out + 1] = { id = info.questID, title = info.title, level = level, complete = complete, failed = info.isFailed,
        prog = prog, objs = objs, zone = zone, dist = n and n.dist, wp = n and n.wp, label = n and n.label,
        group = (info.suggestedGroup or 0) > 1 }
    end
  end
  table.sort(out, function(a, b)
    if a.complete ~= b.complete then return a.complete end
    if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
    if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
    return (a.level or 0) < (b.level or 0)
  end)
  return out
end

-- Nearest spot on your continent; turnin = true only looks at turn-ins.
function RG.NearestSpot(turnin)
  local c, px, py = playerWorld()
  if not c then return nil end
  local best, bestD
  for _, s in ipairs(RG.QuestSpots()) do
    if (turnin and s.turnin) or (not turnin and not s.turnin) then
      local c2, x, y = toWorld(s.wp[1], s.wp[2], s.wp[3])
      if c2 == c then
        local d = math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
        if not bestD or d < bestD then best, bestD = s, d end
      end
    end
  end
  if best then best.dist = bestD end
  return best
end
local targetSet = {}

-- The old quest target bar and WaypathTarget macro were removed. Delete the leftover macro once, out of combat.
local function refreshBar()
  if WaypathSpeedBar then WaypathSpeedBar:Hide() end
  if RG.db and not RG.db.targetMacroGone and GetMacroIndexByName and DeleteMacro and not (InCombatLockdown and InCombatLockdown()) then
    local idx = GetMacroIndexByName("WaypathTarget")
    if idx and idx > 0 then pcall(DeleteMacro, idx) end
    RG.db.targetMacroGone = true
  end
end
RG.RefreshSpeedBar = refreshBar

local lastAlert = {}
local function nameplate(unit)
  if not RG.Opt("nameplateAlert") or (RG.IsAlt and RG.IsAlt()) then return end
  local name = RG.SafeName(unit)
  local t = name and targetSet[name]
  if not t or RG.SafeUnit(UnitIsDead, unit) then return end
  if lastAlert[name] and GetTime() - lastAlert[name] < 180 then return end
  lastAlert[name] = GetTime()
  RG.Print(GOLD .. "Quest mob nearby:|r " .. name .. (t.drop and (GREY .. " (drops " .. t.drop .. ")|r") or "") .. GREY .. (t.have and t.need and string.format("  (%d/%d)", t.have, t.need) or "") .. "  ·  press your WaypathTarget macro|r")
  if RG.Opt("sounds") and PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.MAP_PING or 3175) end
end

-- ===========================================================================
-- 3. Waypoint arrow (points at your map pin)
-- ===========================================================================
local lastAuto, lastPlaced, lastLabel
local function samePin(a, b) return a and b and a.map == b.map and math.abs(a.x - b.x) < 0.2 and math.abs(a.y - b.y) < 0.2 end
local arrow
local function worldPos(mapID, pos)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and mapID and pos) then return nil end
  local cont, wp = C_Map.GetWorldPosFromMapPos(mapID, pos)
  if not wp then return nil end
  return cont, wp.x, wp.y
end
-- The arrow: a dark disc with a gold ring, an arrow that turns smoothly and goes
-- green when you face your target (gold when close to it, red when it's behind
-- you), the destination's name, distance and time to get there, travel steps
-- when it's in another zone, and a check mark when you arrive.
local function lerp(a, b, t) return a + (b - a) * t end
local function angleColor(rel)
  -- rel: 0 = straight ahead, pi = behind. green when you face it, amber to the side, soft red behind
  local t = math.min(1, math.abs(rel) / math.pi)
  if t < 0.35 then local k = t / 0.35; return lerp(0.28, 1, k), lerp(0.9, 0.78, k), lerp(0.38, 0.30, k) end
  local k = (t - 0.35) / 0.65; return 1, lerp(0.78, 0.35, k), lerp(0.30, 0.35, k)
end
local function fmtTime(sec)
  if not sec or sec <= 0 or sec > 5999 then return nil end
  return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end
-- Arrow size: 50% to 300%. Mouse wheel over the arrow, /wp arrowsize 150, or the Settings tab.
function RG.SetArrowScale(sc, quiet)
  sc = math.max(0.5, math.min(3, tonumber(sc) or 1))
  RG.db.arrowScale = sc
  if arrow then arrow:SetScale(sc) end
  if not quiet and RG.Notify then RG.Notify(string.format("Arrow size %d%%", math.floor(sc * 100 + 0.5))) end
  return sc
end
local function buildArrow()
  if arrow then return end
  arrow = CreateFrame("Frame", "WaypathArrow", UIParent)
  arrow:SetSize(110, 110); arrow:SetMovable(true); arrow:EnableMouse(true); arrow:RegisterForDrag("LeftButton"); arrow:SetClampedToScreen(true)
  arrow:SetScale(RG.db.arrowScale or 1)
  local pos = RG.db.arrowPos
  if pos then arrow:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else arrow:SetPoint("TOP", UIParent, "TOP", 0, -150) end
  arrow:SetScript("OnDragStart", arrow.StartMoving)
  arrow:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, _, x, y = self:GetPoint(); RG.db.arrowPos = { p, x, y } end)
  -- disc and ring
  arrow.glow = arrow:CreateTexture(nil, "ARTWORK"); arrow.glow:SetAlpha(0)   -- kept for old callers; the arrow has no disc or ring any more
  -- the arrow itself
  arrow.tex = arrow:CreateTexture(nil, "OVERLAY"); arrow.tex:SetSize(62, 62); arrow.tex:SetPoint("CENTER")
  arrow.tex:SetTexture("Interface\\Minimap\\MinimapArrow"); arrow.tex:SetVertexColor(GOLDC[1], GOLDC[2], GOLDC[3])
  -- 3D look: a pre-rendered solid arrow (tools/media/arrow3d.py), one sprite-sheet frame per heading,
  -- tinted like the flat arrow, with a highlight added on top
  arrow.sheet = arrow:CreateTexture(nil, "OVERLAY"); arrow.sheet:SetSize(100, 100); arrow.sheet:SetPoint("CENTER", 0, 0)
  arrow.sheet:SetTexture("Interface\\AddOns\\Waypath\\Media\\Arrow3D")
  arrow.spec = arrow:CreateTexture(nil, "OVERLAY", nil, 2); arrow.spec:SetSize(100, 100); arrow.spec:SetPoint("CENTER", 0, 0)
  arrow.spec:SetTexture("Interface\\AddOns\\Waypath\\Media\\Arrow3DSpec"); arrow.spec:SetBlendMode("ADD")
  -- the next frame, blended in by the fraction between two headings, so turning is continuous
  arrow.sheet2 = arrow:CreateTexture(nil, "OVERLAY", nil, 1); arrow.sheet2:SetSize(100, 100); arrow.sheet2:SetPoint("CENTER", 0, 0)
  arrow.sheet2:SetTexture("Interface\\AddOns\\Waypath\\Media\\Arrow3D")
  arrow.spec2 = arrow:CreateTexture(nil, "OVERLAY", nil, 3); arrow.spec2:SetSize(100, 100); arrow.spec2:SetPoint("CENTER", 0, 0)
  arrow.spec2:SetTexture("Interface\\AddOns\\Waypath\\Media\\Arrow3DSpec"); arrow.spec2:SetBlendMode("ADD")
  arrow.check = arrow:CreateTexture(nil, "OVERLAY"); arrow.check:SetSize(44, 44); arrow.check:SetPoint("CENTER")
  arrow.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); arrow.check:Hide()
  -- text: destination above, distance and time below, travel hint under that
  arrow.label = arrow:CreateFontString(nil, "OVERLAY"); RG.Font(arrow.label, "semibold", 13); arrow.label:SetPoint("BOTTOM", arrow, "TOP", 0, 2); arrow.label:SetShadowColor(0, 0, 0, 0.9); arrow.label:SetShadowOffset(1, -1)
  arrow.label:SetTextColor(GOLDC[1], GOLDC[2], GOLDC[3]); arrow.label:SetWidth(260); arrow.label:SetWordWrap(false)
  arrow.dist = arrow:CreateFontString(nil, "OVERLAY"); RG.Font(arrow.dist, "medium", 16); arrow.dist:SetPoint("TOP", arrow, "BOTTOM", 0, 2); arrow.dist:SetShadowColor(0, 0, 0, 0.9); arrow.dist:SetShadowOffset(1, -1)
  arrow.hint = arrow:CreateFontString(nil, "OVERLAY"); RG.Font(arrow.hint, "regular", 11); arrow.hint:SetPoint("TOP", arrow.dist, "BOTTOM", 0, -2)
  arrow.hint:SetTextColor(0.78, 0.82, 0.85); arrow.hint:SetShadowColor(0, 0, 0, 0.9); arrow.hint:SetShadowOffset(1, -1); arrow.hint:SetWidth(260); arrow.hint:SetWordWrap(true)
  -- right-click or double-click to turn it off; mouse wheel to resize
  local lastUp = 0
  arrow:SetScript("OnDragStart", function(self) self.dragged = true; self:StartMoving() end)
  arrow:SetScript("OnMouseDown", function(self) self.dragged = false end)
  arrow:SetScript("OnMouseUp", function(self, btn)
    if btn == "LeftButton" and not self.dragged and IsShiftKeyDown and IsShiftKeyDown() and RG.SmartNext then RG.SmartNext(); return end   -- Shift-click: on to the next stop
    if btn == "RightButton" then RG.ClearWaypoint(); return end
    local now = GetTime()
    if now - lastUp < 0.35 then lastUp = 0; RG.ClearWaypoint(); RG.Notify("Arrow off") else lastUp = now end
  end)
  arrow:EnableMouseWheel(true)
  arrow:SetScript("OnMouseWheel", function(self, delta)
    RG.SetArrowScale((RG.db.arrowScale or 1) + delta * 0.1, true)
  end)
  arrow:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Waypoint arrow", GOLDC[1], GOLDC[2], GOLDC[3])
    GameTooltip:AddLine("Green: you're facing it. Red: it's behind you.", 1, 1, 1, true)
    GameTooltip:AddLine("Drag: move  ·  Mouse wheel: resize (or /wp arrowsize 150)", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Shift-click: on to the next stop", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Double-click or right-click: turn it off", 0.7, 0.7, 0.7)
    if not RG.SPFInstalled() then GameTooltip:AddLine("Tip: install Shortest Path Forever and this arrow plans routes around walls and mountains.", 0.9, 0.75, 0.35, true) end
    GameTooltip:Show()
  end)
  arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- a quick pulse whenever the target changes
  arrow.pulse = 0
  local shown, lastKey, arrivedAt = 0, nil, nil
  local acc = 0
  -- The game knows the next leg of a quest's way (a door, a cave mouth, a stair). When we are blocked and
  -- have no learned path, lead to that point first.
  local legQuest = {}
  local function gameLeg(wp, key, cont, px, py, d)
    if not (C_QuestLog and C_QuestLog.GetNextWaypoint) then return end
    local qid = legQuest[key]
    if qid == nil then
      qid = false
      for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do
        if q.id and q.wp and samePin({ map = wp.uiMapID, x = wp.position.x * 100, y = wp.position.y * 100 }, { map = q.wp[1], x = q.wp[2], y = q.wp[3] }) then qid = q.id; break end
      end
      legQuest[key] = qid
    end
    if not qid then return end
    local ok, m, x, y = pcall(C_QuestLog.GetNextWaypoint, qid)
    if not (ok and m and x and y) then return end
    local c, lx, ly = worldPos(m, CreateVector2D and CreateVector2D(x, y) or { x = x, y = y })
    if not (c and c == cont) then return end
    local dl = math.sqrt((lx - px) ^ 2 + (ly - py) ^ 2)
    if dl < 25 or dl > d + 150 then return end
    return lx - px, ly - py, "Blocked: the game's own next leg of this quest"
  end
  local FR, COLS3, CELL3, SHEET3 = 64, 8, 256, 2048
  local function sync3d(self)
    local on = RG.db.arrow3d ~= false and self.tex:IsShown()
    self.tex:SetAlpha(on and 0 or 1)
    self.sheet:SetShown(on); self.spec:SetShown(on); self.sheet2:SetShown(on); self.spec2:SetShown(on)
    if not on then return end
    local r, g, b = self.tex:GetVertexColor()
    -- two neighbouring frames, weighted by where the heading falls between them
    local pos = ((self.rot or 0) % (2 * math.pi)) / (2 * math.pi) * FR
    local i0 = math.floor(pos); local f = pos - i0
    i0 = i0 % FR
    local i1 = (i0 + 1) % FR
    local function uv(idx)
      local col = idx % COLS3; local row = (idx - col) / COLS3
      return col * CELL3 / SHEET3, (col + 1) * CELL3 / SHEET3, row * CELL3 / SHEET3, (row + 1) * CELL3 / SHEET3
    end
    local l, rr, t, bt = uv(i0)
    self.sheet:SetTexCoord(l, rr, t, bt); self.spec:SetTexCoord(l, rr, t, bt)
    l, rr, t, bt = uv(i1)
    self.sheet2:SetTexCoord(l, rr, t, bt); self.spec2:SetTexCoord(l, rr, t, bt)
    self.sheet:SetVertexColor(r or 1, g or 1, b or 1); self.sheet2:SetVertexColor(r or 1, g or 1, b or 1)
    self.sheet:SetAlpha(1); self.sheet2:SetAlpha(f)
    self.spec:SetAlpha(1 - f); self.spec2:SetAlpha(f)
  end
  arrow:SetScript("OnUpdate", function(self, dt)
    sync3d(self)
    if self.pulse > 0 then self.pulse = math.max(0, self.pulse - dt * 2.5); local k = 1 + 0.18 * self.pulse; local z = 100 * k; self.sheet:SetSize(z, z); self.spec:SetSize(z, z); self.sheet2:SetSize(z, z); self.spec2:SetSize(z, z) end
    if arrivedAt then
      local t = GetTime() - arrivedAt
      self:SetAlpha(math.max(0, 1 - math.max(0, t - 1.2) * 2))
      if t > 1.7 then arrivedAt = nil; self.check:Hide(); self.tex:Show(); self:SetAlpha(1); if not (InCombatLockdown and InCombatLockdown()) and C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end; self:Hide() end
      return
    end
    -- every frame: ease towards the heading found by the slower pass below, so turning follows the display's frame rate
    if rawget(self, "wang") then
      local f = GetPlayerFacing and GetPlayerFacing()
      if f and not (RG.IsSecret and RG.IsSecret(f)) then
        local tg = self.wang - f
        local df = (tg - shown + math.pi) % (2 * math.pi) - math.pi
        shown = shown + df * (1 - math.exp(-dt * 20))
        self.tex:SetRotation(shown); self.rot = shown
      end
    end
    acc = acc + dt; if acc < 0.05 then return end
    local step = acc; acc = 0
    local wp = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local ppos = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    -- some maps (a new zone, a small sub-area) give no position: ask the pin's own map, then the maps above yours
    if not ppos and wp and C_Map.GetPlayerMapPosition then
      local tries, seen = { wp.uiMapID }, {}
      local m = mapID
      for _ = 1, 5 do
        if not (m and C_Map.GetMapInfo) then break end
        local info = C_Map.GetMapInfo(m); m = info and info.parentMapID
        if m and m > 0 then tries[#tries + 1] = m end
      end
      for _, tm in ipairs(tries) do
        if tm and not seen[tm] then
          seen[tm] = true
          local pp = C_Map.GetPlayerMapPosition(tm, "player")
          if pp then mapID, ppos = tm, pp; break end
        end
      end
    end
    local facing = GetPlayerFacing and GetPlayerFacing()
    if RG.IsSecret and RG.IsSecret(facing) then facing = nil end
    -- no heading for a moment (mounted turns, cutscenes): keep the last one rather than losing the arrow
    if facing then self.lastFacing = facing else facing = self.lastFacing end
    if not (wp and ppos and facing) then self.wang = nil; self:Hide(); return end
    local key = wp.uiMapID .. ":" .. math.floor(wp.position.x * 1000) .. ":" .. math.floor(wp.position.y * 1000)
    if key ~= lastKey then lastKey = key; self.pulse = 1 end
    local label = lastPlaced and samePin({ map = wp.uiMapID, x = wp.position.x * 100, y = wp.position.y * 100 }, lastPlaced) and lastLabel or nil
    if not label and C_Map.GetMapInfo then local info = C_Map.GetMapInfo(wp.uiMapID); label = info and info.name end
    self.label:SetText(label or "")
    local c1, px, py = worldPos(mapID, ppos)
    local c2, tx, ty = worldPos(wp.uiMapID, wp.position)
    local entHint
    if not (c1 and c2 and c1 == c2) and RG.DungeonEntrance then
      -- the target is inside a dungeon: lead to its door on the outside map
      local ent = RG.DungeonEntrance(wp.uiMapID)
      if ent then
        local ec, ex, ey = worldPos(ent.map, CreateVector2D and CreateVector2D(ent.x, ent.y) or { x = ent.x, y = ent.y })
        if ec and ec == c1 then c2, tx, ty = ec, ex, ey; entHint = "Dungeon entrance: " .. ent.name end
      end
    end
    if not (c1 and c2 and c1 == c2) then
      self.wang = nil
      -- another continent: point the way with travel steps instead
      self.tex:SetVertexColor(0.6, 0.6, 0.6); self.dist:SetText(GREY .. "another continent|r")
      local info = C_Map.GetMapInfo and C_Map.GetMapInfo(wp.uiMapID)
      local legs = info and RG.TravelPlan and RG.TravelPlan(info.name)
      self.hint:SetText(legs and legs[1] and ("Next: " .. legs[1].text) or "")
      return
    end
    local dx, dy = tx - px, ty - py -- x = north, y = west
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 10 then
      arrivedAt = GetTime()
      if RG.OnArrive then pcall(RG.OnArrive, label) end
      self.tex:Hide(); self.check:Show()
      self.dist:SetText(GREEN .. "Arrived|r"); self.hint:SetText("")
      if RG.Opt("sounds") and PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.READY_CHECK or 8960) end
      return
    end
    -- learned paths: when you are not getting closer, lead the way you went before
    local pathHint
    if RG.PathTick then
      local ok, ox, oy, h, stuck = pcall(RG.PathTick, c1, px, py, tx, ty, d, GetUnitSpeed and GetUnitSpeed("player") or 0, step, key)
      if ok then
        if ox then dx, dy = ox, oy end
        pathHint = h
        if stuck and not ox then
          local okg, gx, gy, gh = pcall(gameLeg, wp, key, c1, px, py, d)
          if okg and gx then dx, dy = gx, gy; pathHint = gh
          elseif not RG.SPFInstalled() then pathHint = (h or "Blocked?") .. "  (Shortest Path Forever plans around this)" end
        end
      end
    end
    -- smooth turning
    self.wang = math.atan2(dy, dx)
    local target = self.wang - facing
    local rel = (target + math.pi) % (2 * math.pi) - math.pi
    self.tex:SetVertexColor(angleColor(rel))
    -- distance and time to arrive at your current speed
    local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
    if RG.IsSecret and RG.IsSecret(speed) then speed = 0 end
    local eta = speed > 0.5 and fmtTime(d / speed) or nil
    self.dist:SetText(string.format("%d yd", d) .. (eta and (GREY .. "  ·  " .. eta .. "|r") or ""))
    -- in another zone: the first travel step
    local hint = ""
    if wp.uiMapID ~= mapID and d > 600 and RG.TravelPlan and C_Map.GetMapInfo then
      local info = C_Map.GetMapInfo(wp.uiMapID)
      local legs = info and RG.TravelPlan(info.name)
      if legs and legs[1] and legs[1].how ~= "walk" then hint = "Fastest: " .. legs[1].text end
    end
    if pathHint then hint = pathHint end
    if entHint and hint == "" then hint = entHint end
    if hint == "" and math.abs(rel) > 2.6 then hint = "It's behind you" end
    self.hint:SetText(hint)
  end)
end
-- Shortest Path Forever (a separate add-on with a baked walking map of the whole world) plans routes
-- around mountains, walls and cave mouths. When it is installed it takes over the directions for the
-- pin Waypath+ places, and its arrow is shown instead of ours.
local function spfApi()
  local api = ShortestPathForever and ShortestPathForever.API
  if RG.Opt("spf") and api and type(api.Navigate) == "function" then return api end
end
RG.SPFApi = spfApi
function RG.SPFInstalled() return ShortestPathForever ~= nil and type(ShortestPathForever.API) == "table" end
local function spfActive()
  local api = spfApi()
  if not (api and api.CurrentStop) then return false end
  local ok, cur = pcall(api.CurrentStop, "Waypath+")
  return ok and cur ~= nil
end
local refreshArrow
function RG.RefreshArrow() if refreshArrow then refreshArrow() end end
refreshArrow = function()
  if not RG.Opt("arrow") or (RG.IsAlt and RG.IsAlt() and not (RG.AltGuideActive and RG.AltGuideActive())) then if arrow then arrow:Hide() end return end
  local has = C_Map and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()
  if has and spfActive() then if arrow then arrow:Hide() end return end
  if has then buildArrow(); arrow:Show() elseif arrow then arrow:Hide() end
end
-- ---------------------------------------------------------------------------
-- Route waypoints (Waypoints.lua: { uiMapID, x, y, label })
-- ---------------------------------------------------------------------------
RG.PIN = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:13:13|t "
function RG.StepWaypoint(entry, i)
  local gw = entry and RG.STEP_WP and RG.STEP_WP[entry.zone .. "|" .. entry.from]
  if gw and gw[i] then return gw[i] end
  local W = RG.WAYPOINTS
  local key = entry and (entry.zone .. "|" .. entry.from)
  local list = W and key and W.steps[key]
  local orig = key and RG.STEP_ORIG and RG.STEP_ORIG[key]
  return list and list[(orig and orig[i]) or i]
end
function RG.WaypointForText(text)
  local W = RG.WAYPOINTS
  if not (W and text) then return nil end
  for name, wp in pairs(W.givers) do if text:find(name, 1, true) then return wp end end
end
function RG.CampWaypoint(step)
  local W = RG.WAYPOINTS
  if not (W and RG.CAMP_PLAN) then return nil end
  for i, s in ipairs(RG.CAMP_PLAN) do if s == step then return W.camp[i] end end
end
local function currentPin()
  local wp = C_Map and C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
  return wp and { map = wp.uiMapID, x = wp.position.x * 100, y = wp.position.y * 100 }
end
-- The game's map code reacts to a new pin by running protected calls; if that is triggered from our
-- (insecure) code in combat it gets blocked. So pins and clears wait until combat ends.
local deferredPin, deferredClear
local combatWatch = CreateFrame("Frame")
combatWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatch:SetScript("OnEvent", function()
  if deferredClear then deferredClear = nil; deferredPin = nil; RG.ClearWaypoint() end
  if deferredPin then local d = deferredPin; deferredPin = nil; RG.PinWaypoint(d[1], d[2]) end
end)
local function inCombat() return InCombatLockdown and InCombatLockdown() end
function RG.PinWaypoint(wp, quiet)
  if not (wp and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then RG.Print("This client doesn't support map pins.") return end
  if inCombat() then deferredPin = { wp, quiet }; deferredClear = nil; if not quiet then RG.Notify("Pin for " .. wp[4] .. " is set as soon as combat ends") end return end
  local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(wp[1], wp[2] / 100, wp[3] / 100))
  if not ok then if not quiet then RG.Print("Can't pin " .. wp[4] .. " from here.") end return end
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
  lastPlaced = { map = wp[1], x = wp[2], y = wp[3] }; lastLabel = wp[4]
  local api = spfApi()
  if api then pcall(api.Navigate, "Waypath+", wp[1], wp[2] / 100, wp[3] / 100, wp[4]) end
  -- you asked for it (a click, not the route moving on by itself): if the arrow was switched off, it comes back on
  if not quiet and RG.db and not RG.Opt("arrow") then RG.db.arrow = true end
  if RG.RefreshArrow then RG.RefreshArrow() end
  if not quiet then RG.Notify("Pinned " .. wp[4] .. ": follow the arrow") end
end
function RG.ClearWaypoint()
  if inCombat() then deferredClear = true; return end
  local api = spfApi()
  if api and api.Cancel then pcall(api.Cancel, "Waypath+") end
  if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
  if arrow then arrow:Hide() end
end
-- Double-click a quest, step or quest giver: arrow on to it, or off if it's already the target.
function RG.ArrowTo(wp)
  if not wp then return end
  local cur = currentPin()
  if cur and samePin(cur, { map = wp[1], x = wp[2], y = wp[3] }) then
    RG.ClearWaypoint()
    RG.Notify("Arrow off")
  else
    if not RG.Opt("arrow") then RG.db.arrow = true end
    RG.PinWaypoint(wp, true)
    RG.Notify("Arrow on: " .. wp[4])
  end
  if RG.RefreshTracker then RG.RefreshTracker() end
end
-- a click handler that sends the arrow to wp; remembered so list rows know a plain click may run it
RG.ARROWFN = setmetatable({}, { __mode = "k" })
function RG.ArrowFn(wp)
  if not wp then return nil end
  local f = function() RG.ArrowTo(wp) end
  RG.ARROWFN[f] = true
  return f
end
-- true when the pin on the map is one Waypath+ placed (not one you set yourself)
function RG.PinIsOurs()
  local cur = currentPin()
  return cur and lastPlaced and samePin(cur, lastPlaced) or false
end
function RG.HasPin() return currentPin() ~= nil end
function RG.ArrowTarget(wp)
  local cur = currentPin()
  return wp and cur and samePin(cur, { map = wp[1], x = wp[2], y = wp[3] }) or false
end
-- Called by the tracker with the next unfinished step that has a waypoint.
function RG.AutoPin(key, wp)
  if not RG.Opt("autoArrow") or not RG.Opt("arrow") or key == lastAuto then return end
  if IsInInstance and IsInInstance() then return end
  local cur = currentPin()
  if cur and not samePin(cur, lastPlaced) then return end -- you placed your own pin: leave it
  lastAuto = key
  RG.PinWaypoint(wp, true)
end

function RG.SetWaypoint(x, y)
  if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint) then RG.Print("This client doesn't support map pins.") return end
  if inCombat() then RG.Print("Can't place a pin during combat.") return end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID or (C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID)) then RG.Print("Can't place a pin here.") return end
  C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
  lastPlaced = nil -- a pin you chose: auto-follow leaves it alone
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
  refreshArrow()
  RG.Notify(string.format("Pin set at %.1f, %.1f: follow the arrow", x, y))
end

-- ===========================================================================
-- 4. Leveling pace: time played at each level
-- ===========================================================================
local function paceTick()
  if RG.IsAlt and RG.IsAlt() then return end
  if UnitIsAFK and UnitIsAFK("player") then return end
  RG.db.levelTime = RG.db.levelTime or {}
  local lvl = UnitLevel("player")
  RG.db.levelTime[lvl] = (RG.db.levelTime[lvl] or 0) + 30
end
function RG.Pace()
  local t = RG.db.levelTime or {}
  local lvl = UnitLevel("player")
  local sum, n = 0, 0
  for l = lvl - 1, math.max(1, lvl - 5), -1 do if t[l] then sum = sum + t[l]; n = n + 1 end end
  return t[lvl] or 0, t[lvl - 1], n > 0 and sum / n or nil
end
function RG.FormatDuration(s)
  if not s then return "?" end
  local h, m = math.floor(s / 3600), math.floor((s % 3600) / 60)
  return h > 0 and string.format("%dh %02dm", h, m) or string.format("%dm", m)
end

-- ===========================================================================
-- 5. Bag space
-- ===========================================================================
local function freeSlots()
  local C, free = C_Container, 0
  for bag = 0, 4 do free = free + ((C and C.GetContainerNumFreeSlots and C.GetContainerNumFreeSlots(bag)) or 0) end
  return free
end
RG.FreeSlots = freeSlots

local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  if RG.Opt("bagReminder") then
    local free = freeSlots()
    if free <= 3 then
      out[#out + 1] = { "|TInterface\\Icons\\INV_Misc_Bag_08:14:14|t " .. (free == 0 and RED or GOLD) .. "Bags " .. (free == 0 and "full" or ("almost full: " .. free .. " free")) .. "|r" .. GREY .. ". Vendor, bank" .. ((RG.IsAlt and not RG.IsAlt() and RG.db.main) and ", or mail spare mats to your bank alt" or "") .. "|r", nil, free == 0 and 1 or 2 }
    end
  end
  return out
end

-- ===========================================================================
-- Events
-- ===========================================================================
local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
  "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED", "NAME_PLATE_UNIT_ADDED",
  "UI_ERROR_MESSAGE", "USER_WAYPOINT_UPDATED", "SUPER_TRACKING_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN" }) do pcall(f.RegisterEvent, f, e) end
local barQueued
local function queueBar() if barQueued then return end; barQueued = true; C_Timer.After(0.5, function() barQueued = nil; refreshBar() end) end
f:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "PLAYER_LOGIN" then
    C_Timer.NewTicker(30, paceTick)
    C_Timer.NewTicker(5, function() if not combat() and RG.QueueTracker then RG.QueueTracker() end end)
    C_Timer.After(3, function() refreshBar(); refreshArrow() end)
  elseif event == "GOSSIP_SHOW" then onGossip()
  elseif event == "QUEST_GREETING" then onGreeting()
  elseif event == "QUEST_DETAIL" then onDetail()
  elseif event == "QUEST_PROGRESS" then onProgress()
  elseif event == "QUEST_COMPLETE" then onComplete()
  elseif event == "PLAYER_REGEN_ENABLED" then
    for k, fn in pairs(pendingAfterCombat) do pendingAfterCombat[k] = nil; fn() end
  elseif event == "NAME_PLATE_UNIT_ADDED" then nameplate(a1)
  elseif event == "UI_ERROR_MESSAGE" then
    local msg = tostring(a2 or a1 or ""):lower()
    if msg:find("quest log is full") or msg:find("inventory is full") or msg:find("bags are full") then
      if not paused then paused = true; RG.Print("Auto quests paused: " .. msg .. ". They'll resume when you have room.") end
    end
  elseif event == "USER_WAYPOINT_UPDATED" or event == "SUPER_TRACKING_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
    refreshArrow()
  elseif event == "PLAYER_LEVEL_UP" or event == "QUEST_TURNED_IN" then
    RG.MarkQuestsDirty(); queueBar()
  else
    if paused and (event == "QUEST_REMOVED" or event == "BAG_UPDATE_DELAYED") and freeSlots() > 0 then paused = false end
    if event ~= "BAG_UPDATE_DELAYED" then RG.MarkQuestsDirty() end
    queueBar()
  end
end)

-- ===========================================================================
-- Everything can drive the arrow: the world map, the minimap, Questie and TomTom-style pins
-- ===========================================================================
do
  local function on() return RG.Opt and RG.Opt("mapClicks") end
  local function title(qid) return (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)) or "Quest" end

  -- 1. Pick a quest on the world map or in the quest log (the game "super-tracks" it): the arrow goes there
  local lastQ
  local function followSuper()
    if not on() then return end
    local S = C_SuperTrack
    if not S then return end
    if S.IsSuperTrackingUserWaypoint and S.IsSuperTrackingUserWaypoint() then return end   -- our own pin
    local qid = S.GetSuperTrackedQuestID and S.GetSuperTrackedQuestID()
    if not qid or qid == 0 then lastQ = nil; return end
    if qid == lastQ then return end
    lastQ = qid
    local wp
    for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do if q.id == qid and q.wp then wp = q.wp; break end end
    wp = wp or liveTurnIn(qid, title(qid))
    if wp and RG.Follow then RG.Follow({ wp[1], wp[2], wp[3], wp[4] or title(qid) }) end
  end
  local sf = CreateFrame("Frame")
  pcall(sf.RegisterEvent, sf, "SUPER_TRACKING_CHANGED")
  sf:SetScript("OnEvent", function() if C_Timer then C_Timer.After(0.1, followSuper) end end)

  -- 2. Questie, and anything else that sets a TomTom waypoint on a Ctrl-click: send it to our arrow
  local function installTomTom()
    if rawget(_G, "TomTom") or not on() then return end
    local T, uids = {}, {}
    function T:AddWaypoint(map, x, y, opts)
      if type(self) ~= "table" or self ~= T then map, x, y, opts = self, map, x, y end
      if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return end
      local label = type(opts) == "table" and (opts.title or opts.name) or nil
      if RG.Follow then RG.Follow({ map, x * 100, y * 100, label or "Waypoint" }) end
      local uid = { map, x, y, label }
      uids[#uids + 1] = uid
      return uid
    end
    function T:RemoveWaypoint() if RG.ClearWaypoint then RG.ClearWaypoint() end end
    function T:ClearAllWaypoints() if RG.ClearWaypoint then RG.ClearWaypoint() end end
    function T:SetCrazyArrow() end
    function T:SetClosestWaypoint() end
    function T:GetClosestWaypoint() return uids[#uids] end
    function T:GetDistanceToWaypoint() return nil end
    _G.TomTom = T
  end

  -- 3. Ctrl-click the minimap: the arrow goes to that spot
  local OUT = { 466.6667, 400, 333.3333, 266.6667, 200, 133.3333 }
  local INN = { 300, 240, 180, 120, 80, 50 }
  local function minimapClick(_, btn)
    if btn ~= "LeftButton" or not on() or not (IsControlKeyDown and IsControlKeyDown()) then return end
    if not (Minimap and C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return end
    local c, px, py = playerWorld()
    local map = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not (c and map and GetCursorPosition) then return end
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local dx, dy = cx / scale - mx, cy / scale - my
    local radius = Minimap:GetWidth() / 2
    if (dx * dx + dy * dy) > radius * radius then return end
    local zoom = (Minimap.GetZoom and Minimap:GetZoom() or 0) + 1
    local tbl = (IsIndoors and IsIndoors()) and INN or OUT
    local k = (tbl[zoom] or tbl[1]) / Minimap:GetWidth()   -- yards per pixel
    local f = 0
    if GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing then f = GetPlayerFacing() or 0 end
    local E = (dx * math.cos(f) - dy * math.sin(f)) * k
    local N = (dx * math.sin(f) + dy * math.cos(f)) * k
    local ok, m2, pos = pcall(C_Map.GetMapPosFromWorldPos, c, CreateVector2D(px + N, py - E), map)   -- world x = north, y = west
    if not ok then return end
    if type(m2) == "table" then pos, m2 = m2, map end
    if pos and pos.x and pos.y and RG.Follow then
      RG.Follow({ m2 or map, pos.x * 100, pos.y * 100, "Minimap spot" })
    end
  end
  local mf = CreateFrame("Frame")
  mf:RegisterEvent("PLAYER_LOGIN")
  mf:SetScript("OnEvent", function()
    installTomTom()
    if Minimap and Minimap.HookScript then pcall(Minimap.HookScript, Minimap, "OnMouseUp", minimapClick) end   -- a hook only: the minimap itself is never touched
  end)
end

-- Remember where quests were offered, so a giver our data lacks is guided to next time (shared by all your characters).
do
  local lf = CreateFrame("Frame")
  for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_GREETING" }) do pcall(lf.RegisterEvent, lf, e) end
  local function learn(id, title, level)
    if not (id and id > 0 and title and RG.db) then return end
    if RG.QDATA and RG.QDATA[id] and RG.QDATA[id].s then return end
    local c, px, py = playerWorld()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    RG.db.givers = RG.db.givers or {}
    local npc = (UnitName and (UnitName("npc") or UnitName("target"))) or nil
    local old = RG.db.givers[id]
    RG.db.givers[id] = { n = title, l = (level and level > 0 and level) or (old and old.l), m = map, x = pos.x * 100, y = pos.y * 100, g = npc,
      f = UnitFactionGroup and UnitFactionGroup("player") or nil }
    RG.MarkQuestsDirty()
  end
  lf:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_SHOW" and C_GossipInfo and C_GossipInfo.GetAvailableQuests then
      for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do learn(q.questID, q.title, q.questLevel) end
    elseif event == "QUEST_DETAIL" and GetQuestID then
      learn(GetQuestID(), GetTitleText and GetTitleText(), nil)
    end
  end)
end

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.*)$")
  cmd = cmd and cmd:lower()
  if cmd == "way" then
    local x, y = (rest or ""):match("([%d%.]+)[,%s]+([%d%.]+)")
    if x and y then RG.SetWaypoint(tonumber(x), tonumber(y)) else RG.Print("Usage: /wp way 45.2 60.8  (coordinates in your current zone)") end
    return
  elseif cmd == "arrowsize" or cmd == "arrowscale" then
    local v = tonumber((rest or ""):match("[%d%.]+"))
    if not v then RG.Print("Arrow size is " .. math.floor((RG.db.arrowScale or 1) * 100 + 0.5) .. "%. Use " .. "/wp arrowsize 150 (50 to 300), or the mouse wheel over the arrow.") return end
    if v > 3 then v = v / 100 end
    RG.SetArrowScale(v)
    if RG.RefreshArrow then RG.RefreshArrow() end
  elseif cmd == "unhide" then
    RG.db.ignoredQuests = {}; RG.MarkQuestsDirty(); RG.Print("Hidden quests are suggested again.")
  elseif cmd == "next" then
    local s2 = RG.NearestSpot(false) or RG.NearestSpot(true)
    if s2 then RG.PinWaypoint(s2.wp) else RG.Print("No quest objectives with a known location near you.") end
    return
  elseif cmd == "auto" then
    RG.db.autoQuest = not RG.Opt("autoQuest"); paused = false
    RG.Print("Auto accept and turn in " .. (RG.Opt("autoQuest") and "on (hold Shift to pause)." or "off."))
    return
  elseif cmd == "undo" then
    local t = RG.UndoTick and RG.UndoTick()
    if t then RG.Print("Back on your list: " .. t) else RG.Print("Nothing to undo: no tasks ticked off by hand.") end
    return
  elseif cmd == "pace" then
    local cur, last, avg = RG.Pace()
    RG.Print(string.format("This level: %s  ·  last level: %s  ·  average of last 5: %s", RG.FormatDuration(cur), last and RG.FormatDuration(last) or "not recorded yet", avg and RG.FormatDuration(avg) or "not recorded yet"))
    return
  end
  return base(msg)
end

-- Small public API for other add-ons (WaypathAPI).
_G.WaypathAPI = {
  version = function() return RG.VERSION end,
  -- Pin a map point ({ uiMapID, x, y, label }, x and y in map percent) and point the arrow at it.
  Pin = function(uiMapID, x, y, label) if RG.PinWaypoint then RG.PinWaypoint({ uiMapID, x, y, label or "Waypath+" }) end end,
  Clear = function() if RG.ClearWaypoint then RG.ClearWaypoint() end end,
  -- The step Waypath+ is guiding you on: { zone, from, to } or nil.
  CurrentZone = function() local e = RG.CurrentRouteEntry and RG.CurrentRouteEntry(); return e and { zone = e.zone, from = e.from, to = e.to } or nil end,
}
