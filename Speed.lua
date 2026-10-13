-- Waypath+ speed tools (ideas from RestedXP and other speed-leveling addons):
-- auto accept/turn-in with smart rewards, a quest-mob targeting macro and
-- bar, quest item buttons, quest mob nameplate alerts, a waypoint arrow,
-- leveling pace per level, and a bag-space reminder.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local GOLDC = { 1, 0.82, 0 }

for _, o in ipairs({
  { key = "autoQuest",     label = "Auto accept and turn in quests (hold Shift to pause)", default = true },
  { key = "autoReward",    label = "Auto pick quest rewards when the choice is clear", default = true },
  { key = "targetBar",     label = "Quest target bar and WaypathTarget macro", default = true },
  { key = "questItems",    label = "Buttons for quest items I need to use", default = true },
  { key = "nameplateAlert", label = "Tell me when a quest mob shows up nearby", default = true },
  { key = "arrow",         label = "Arrow to my map pin (/wp way 45 60)", default = true },
  { key = "autoArrow",     label = "Arrow follows my next route step automatically", default = true },
  { key = "newQuests",     label = "Show new quests I can pick up nearby", default = true },
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
    local trivial, _, repeatable = GetAvailableQuestInfo and GetAvailableQuestInfo(i)
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
  availCache = list
  return list
end
RG.AvailableQuests = availableQuests

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
-- Nearest few quest givers with something for you, on your continent.
function RG.NearbyNewQuests(max)
  if not RG.Opt("newQuests") then return {} end
  local c, px, py = playerWorld()
  if not c then return {} end
  local out = {}
  for _, q in ipairs(availableQuests()) do
    local c2, x, y = toWorld(q.wp[1], q.wp[2], q.wp[3])
    if c2 == c then q.dist = math.sqrt((x - px) ^ 2 + (y - py) ^ 2); out[#out + 1] = q end
  end
  table.sort(out, function(a, b) return a.dist < b.dist end)
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
  return string.format("%d yd", d)
end

-- Every quest in your log: level, progress, whether it's ready, and the
-- nearest place to work on it (objective or turn-in) with its distance.
-- Ready quests first, then nearest, then the rest by level.
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

local MACRO = "WaypathTarget"
local function updateMacro(list)
  if not (CreateMacro and EditMacro and GetMacroIndexByName) then return end
  local body = "/cleartarget\n"
  for _, t in ipairs(list) do
    local line = "/targetexact " .. t.name .. "\n"
    if #body + #line > 250 then break end
    body = body .. line
  end
  if #list == 0 then body = body .. "/run print(\"Waypath+: no quest mobs to target\")" end
  local idx = GetMacroIndexByName(MACRO)
  if idx and idx > 0 then EditMacro(idx, MACRO, nil, body)
  else pcall(CreateMacro, MACRO, "INV_Misc_Spyglass_03", body, nil) end
end

local bar, targetBtns, itemBtns = nil, {}, {}
local function buildBar()
  if bar then return end
  bar = CreateFrame("Frame", "WaypathSpeedBar", UIParent, "BackdropTemplate")
  bar:SetSize(200, 30); bar:SetMovable(true); bar:SetClampedToScreen(true)
  local pos = WaypathDB.speedBarPos
  if pos then bar:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else bar:SetPoint("CENTER", UIParent, "CENTER", 0, -230) end
  local handle = CreateFrame("Frame", nil, bar)
  handle:SetSize(12, 30); handle:SetPoint("LEFT"); handle:EnableMouse(true); handle:RegisterForDrag("LeftButton")
  local ht = handle:CreateTexture(nil, "ARTWORK"); ht:SetAllPoints(); ht:SetColorTexture(GOLDC[1], GOLDC[2], GOLDC[3], 0.5)
  handle:SetScript("OnDragStart", function() if not combat() then bar:StartMoving() end end)
  handle:SetScript("OnDragStop", function()
    bar:StopMovingOrSizing()
    local p, _, _, x, y = bar:GetPoint(); WaypathDB.speedBarPos = { p, x, y }
  end)
  handle:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("Waypath+ quest bar"); GameTooltip:AddLine("Drag to move. Buttons: quest items to use, then quest mobs to target.", 1, 1, 1, true); GameTooltip:Show() end)
  handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function secureButton(list, i, kind)
  local b = list[i]
  if b then return b end
  b = CreateFrame("Button", "Waypath" .. kind .. i, bar, "SecureActionButtonTemplate, BackdropTemplate")
  b:SetSize(28, 28)
  b:RegisterForClicks("AnyUp", "AnyDown")
  RG.Backdrop(b, { 0.05, 0.05, 0.06, 0.9 }, { GOLDC[1], GOLDC[2], GOLDC[3], 0.6 })
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.count = b:CreateFontString(nil, "OVERLAY"); b.count:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE"); b.count:SetPoint("BOTTOMRIGHT", -1, 1)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if self.link then GameTooltip:SetHyperlink(self.link) else GameTooltip:SetText(self.label or ""); if self.sub then GameTooltip:AddLine(self.sub, 0.8, 0.8, 0.8, true) end end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  list[i] = b
  return b
end

-- Quest items: special items from your quest log, plus bag items that start a quest.
local function questItems()
  local out, seen = {}, {}
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and GetQuestLogSpecialItemInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader then
        local link, icon, charges, showComplete = GetQuestLogSpecialItemInfo(i)
        local done = info.questID and C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)
        if link and (not done or showComplete) and not seen[link] then
          seen[link] = true
          out[#out + 1] = { link = link, icon = icon, sub = info.title }
        end
      end
    end
  end
  local C = C_Container
  if C and C.GetContainerItemQuestInfo then
    for bag = 0, 4 do
      for slot = 1, (C.GetContainerNumSlots(bag) or 0) do
        local q = C.GetContainerItemQuestInfo(bag, slot)
        if q and q.questID and not q.isActive then
          local info = C.GetContainerItemInfo(bag, slot)
          if info and info.hyperlink and not seen[info.hyperlink] then
            seen[info.hyperlink] = true
            out[#out + 1] = { link = info.hyperlink, icon = info.iconFileID, sub = "Starts a quest" }
          end
        end
      end
    end
  end
  return out
end

local function refreshBar()
  if RG.IsAlt and RG.IsAlt() then if bar then bar:Hide() end return end
  if combat() then pendingAfterCombat.bar = refreshBar; return end
  local targets = RG.Opt("targetBar") and questTargets() or {}
  local items = RG.Opt("questItems") and questItems() or {}
  targetSet = {}
  for _, t in ipairs(targets) do targetSet[t.name] = t end
  if RG.Opt("targetBar") then updateMacro(targets) end
  buildBar()
  local x = 16
  for _, b in ipairs(itemBtns) do b:Hide() end
  for _, b in ipairs(targetBtns) do b:Hide() end
  for i, it in ipairs(items) do
    if i > 6 then break end
    local b = secureButton(itemBtns, i, "QuestItem")
    b:SetAttribute("type", "item"); b:SetAttribute("item", it.link)
    b.link, b.label, b.sub = it.link, nil, nil
    b.icon:SetTexture(it.icon or 134400); b.count:SetText("")
    b:ClearAllPoints(); b:SetPoint("LEFT", bar, "LEFT", x, 0); b:Show(); x = x + 31
  end
  if #items > 0 and #targets > 0 then x = x + 8 end
  for i, t in ipairs(targets) do
    if i > 8 then break end
    local b = secureButton(targetBtns, i, "QuestTarget")
    b:SetAttribute("type", "macro"); b:SetAttribute("macrotext", "/cleartarget\n/targetexact " .. t.name)
    b.link, b.label, b.sub = nil, "Target " .. t.name, (t.have and t.need and (t.have .. "/" .. t.need .. "  ·  ") or "") .. (t.quest or "")
    b.icon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot")
    b.count:SetText(t.have and t.need and (t.need - t.have) or "")
    b:ClearAllPoints(); b:SetPoint("LEFT", bar, "LEFT", x, 0); b:Show(); x = x + 31
  end
  bar:SetWidth(math.max(40, x + 2))
  bar:SetShown((#items + #targets) > 0)
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
  -- rel: 0 = straight ahead, pi = behind. green -> gold -> red
  local t = math.min(1, math.abs(rel) / math.pi)
  if t < 0.35 then local k = t / 0.35; return lerp(0.25, 1, k), lerp(1, 0.82, k), lerp(0.3, 0.1, k) end
  local k = (t - 0.35) / 0.65; return 1, lerp(0.82, 0.25, k), lerp(0.1, 0.2, k)
end
local function fmtTime(sec)
  if not sec or sec <= 0 or sec > 5999 then return nil end
  return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end
local function buildArrow()
  if arrow then return end
  arrow = CreateFrame("Frame", "WaypathArrow", UIParent)
  arrow:SetSize(84, 84); arrow:SetMovable(true); arrow:EnableMouse(true); arrow:RegisterForDrag("LeftButton"); arrow:SetClampedToScreen(true)
  arrow:SetScale(WaypathDB.arrowScale or 1)
  local pos = WaypathDB.arrowPos
  if pos then arrow:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else arrow:SetPoint("TOP", UIParent, "TOP", 0, -150) end
  arrow:SetScript("OnDragStart", arrow.StartMoving)
  arrow:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, _, x, y = self:GetPoint(); WaypathDB.arrowPos = { p, x, y } end)
  -- disc and ring
  arrow.disc = arrow:CreateTexture(nil, "BACKGROUND"); arrow.disc:SetSize(64, 64); arrow.disc:SetPoint("CENTER")
  arrow.disc:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"); arrow.disc:SetVertexColor(0, 0, 0, 0.55)
  arrow.ring = arrow:CreateTexture(nil, "BORDER"); arrow.ring:SetSize(108, 108); arrow.ring:SetPoint("TOPLEFT", arrow.disc, "TOPLEFT", -1, 1)
  arrow.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); arrow.ring:SetVertexColor(1, 0.9, 0.6, 0.9)
  arrow.glow = arrow:CreateTexture(nil, "ARTWORK"); arrow.glow:SetSize(62, 62); arrow.glow:SetPoint("CENTER")
  arrow.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); arrow.glow:SetBlendMode("ADD"); arrow.glow:SetAlpha(0)
  -- the arrow itself
  arrow.tex = arrow:CreateTexture(nil, "OVERLAY"); arrow.tex:SetSize(46, 46); arrow.tex:SetPoint("CENTER")
  arrow.tex:SetTexture("Interface\\Minimap\\MinimapArrow"); arrow.tex:SetVertexColor(GOLDC[1], GOLDC[2], GOLDC[3])
  arrow.check = arrow:CreateTexture(nil, "OVERLAY"); arrow.check:SetSize(34, 34); arrow.check:SetPoint("CENTER")
  arrow.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); arrow.check:Hide()
  -- text: destination above, distance and time below, travel hint under that
  arrow.label = arrow:CreateFontString(nil, "OVERLAY"); arrow.label:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE"); arrow.label:SetPoint("BOTTOM", arrow, "TOP", 0, -4)
  arrow.label:SetTextColor(GOLDC[1], GOLDC[2], GOLDC[3]); arrow.label:SetWidth(220); arrow.label:SetWordWrap(false)
  arrow.dist = arrow:CreateFontString(nil, "OVERLAY"); arrow.dist:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE"); arrow.dist:SetPoint("TOP", arrow, "BOTTOM", 0, 6)
  arrow.hint = arrow:CreateFontString(nil, "OVERLAY"); arrow.hint:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE"); arrow.hint:SetPoint("TOP", arrow.dist, "BOTTOM", 0, -2)
  arrow.hint:SetTextColor(0.8, 0.8, 0.8); arrow.hint:SetWidth(240); arrow.hint:SetWordWrap(true)
  -- right-click or double-click to turn it off; mouse wheel to resize
  local lastUp = 0
  arrow:SetScript("OnMouseUp", function(_, btn)
    if btn == "RightButton" then RG.ClearWaypoint(); return end
    local now = GetTime()
    if now - lastUp < 0.35 then lastUp = 0; RG.ClearWaypoint(); RG.Notify("Arrow off") else lastUp = now end
  end)
  arrow:EnableMouseWheel(true)
  arrow:SetScript("OnMouseWheel", function(self, delta)
    local sc = math.max(0.6, math.min(1.8, (WaypathDB.arrowScale or 1) + delta * 0.1))
    WaypathDB.arrowScale = sc; self:SetScale(sc)
  end)
  arrow:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Waypoint arrow", GOLDC[1], GOLDC[2], GOLDC[3])
    GameTooltip:AddLine("Green: you're facing it. Red: it's behind you.", 1, 1, 1, true)
    GameTooltip:AddLine("Drag: move  ·  Mouse wheel: resize", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Double-click or right-click: turn it off", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- a quick pulse whenever the target changes
  arrow.pulse = 0
  local shown, lastKey, arrivedAt = 0, nil, nil
  local acc = 0
  arrow:SetScript("OnUpdate", function(self, dt)
    if self.pulse > 0 then self.pulse = math.max(0, self.pulse - dt * 2); self.glow:SetAlpha(self.pulse * 0.8) end
    if arrivedAt then
      local t = GetTime() - arrivedAt
      self:SetAlpha(math.max(0, 1 - math.max(0, t - 1.2) * 2))
      if t > 1.7 then arrivedAt = nil; self.check:Hide(); self.tex:Show(); self:SetAlpha(1); if C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end; self:Hide() end
      return
    end
    acc = acc + dt; if acc < 0.03 then return end
    local step = acc; acc = 0
    local wp = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local ppos = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    local facing = GetPlayerFacing and GetPlayerFacing()
    if RG.IsSecret and RG.IsSecret(facing) then facing = nil end
    if not (wp and ppos and facing) then self:Hide(); return end
    local key = wp.uiMapID .. ":" .. math.floor(wp.position.x * 1000) .. ":" .. math.floor(wp.position.y * 1000)
    if key ~= lastKey then lastKey = key; self.pulse = 1 end
    local label = lastPlaced and samePin({ map = wp.uiMapID, x = wp.position.x * 100, y = wp.position.y * 100 }, lastPlaced) and lastLabel or nil
    if not label and C_Map.GetMapInfo then local info = C_Map.GetMapInfo(wp.uiMapID); label = info and info.name end
    self.label:SetText(label or "")
    local c1, px, py = worldPos(mapID, ppos)
    local c2, tx, ty = worldPos(wp.uiMapID, wp.position)
    if not (c1 and c2 and c1 == c2) then
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
      self.tex:Hide(); self.check:Show(); self.glow:SetAlpha(0.9)
      self.dist:SetText(GREEN .. "Arrived|r"); self.hint:SetText("")
      if RG.Opt("sounds") and PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.READY_CHECK or 8960) end
      return
    end
    -- smooth turning
    local target = math.atan2(dy, dx) - facing
    local diff = (target - shown + math.pi) % (2 * math.pi) - math.pi
    shown = shown + diff * math.min(1, step * 12)
    self.tex:SetRotation(shown)
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
    if hint == "" and math.abs(rel) > 2.6 then hint = "It's behind you" end
    self.hint:SetText(hint)
  end)
end
local refreshArrow
function RG.RefreshArrow() if refreshArrow then refreshArrow() end end
refreshArrow = function()
  if not RG.Opt("arrow") or (RG.IsAlt and RG.IsAlt() and not (RG.AltGuideActive and RG.AltGuideActive())) then if arrow then arrow:Hide() end return end
  local has = C_Map and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()
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
  local list = W and entry and W.steps[entry.zone .. "|" .. entry.from]
  return list and list[i]
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
function RG.PinWaypoint(wp, quiet)
  if not (wp and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then RG.Print("This client doesn't support map pins.") return end
  local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(wp[1], wp[2] / 100, wp[3] / 100))
  if not ok then if not quiet then RG.Print("Can't pin " .. wp[4] .. " from here.") end return end
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
  lastPlaced = { map = wp[1], x = wp[2], y = wp[3] }; lastLabel = wp[4]
  if RG.RefreshArrow then RG.RefreshArrow() end
  if not quiet then RG.Notify("Pinned " .. wp[4] .. ": follow the arrow") end
end
function RG.ClearWaypoint()
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
    if not RG.Opt("arrow") then WaypathDB.arrow = true end
    RG.PinWaypoint(wp, true)
    RG.Notify("Arrow on: " .. wp[4])
  end
  if RG.RefreshTracker then RG.RefreshTracker() end
end
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

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.*)$")
  cmd = cmd and cmd:lower()
  if cmd == "way" then
    local x, y = (rest or ""):match("([%d%.]+)[,%s]+([%d%.]+)")
    if x and y then RG.SetWaypoint(tonumber(x), tonumber(y)) else RG.Print("Usage: /wp way 45.2 60.8  (coordinates in your current zone)") end
    return
  elseif cmd == "next" then
    local s2 = RG.NearestSpot(false) or RG.NearestSpot(true)
    if s2 then RG.PinWaypoint(s2.wp) else RG.Print("No quest objectives with a known location near you.") end
    return
  elseif cmd == "auto" then
    WaypathDB.autoQuest = not RG.Opt("autoQuest"); paused = false
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
