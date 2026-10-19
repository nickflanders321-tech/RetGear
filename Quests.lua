-- Waypath+ quest sync: reads your quest log and completed quests so the route
-- can tick off steps and dungeon quests on its own.
local _, RG = ...

-- Quest IDs we know for certain (checked on Wowhead), so completion can be
-- read straight from the game even for quests done before Waypath+ was installed.
RG.QUEST_IDS = {
  ["weapons of choice"] = 893,
  ["threat from the sea"] = 1427,
  ["weapons of spirit"] = 3129,
  ["arugal's folly"] = 424,
  ["arugal must die"] = 1014,
}

local function db()
  RG.db.questsDone = RG.db.questsDone or {}
  return RG.db.questsDone
end
local function norm(s) return s and s:lower():gsub("^%s+", ""):gsub("%s+$", "") or nil end

-- ---------------------------------------------------------------------------
-- Quest log
-- ---------------------------------------------------------------------------
-- Returns a table of lowercased quest titles in your log -> { complete = bool }
local logCache, logStamp = {}, nil
function RG.QuestLog()
  if logStamp and GetTime() - logStamp < 1 then return logCache end
  logStamp = GetTime()
  local out = {}
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.title then
        local complete = info.questID and C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)
        out[norm(info.title)] = { complete = complete and true or false, id = info.questID, title = info.title, level = info.level }
      end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() do
      local title, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
      if title and not isHeader then out[norm(title)] = { complete = isComplete == 1 or isComplete == true, title = title } end
    end
  end
  logCache = out
  return out
end

-- "done" | "ready" (complete, turn it in) | "log" (in your log) | nil
function RG.QuestState(name)
  local key = norm(name)
  if not key then return nil end
  if db()[key] then return "done" end
  local id = RG.QUEST_IDS[key]
  if id and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) then
    db()[key] = true; return "done"
  end
  local q = RG.QuestLog()[key]
  if q then return q.complete and "ready" or "log" end
  return nil
end

-- ---------------------------------------------------------------------------
-- Completed-quest history: map every completed quest ID to its title once.
-- ---------------------------------------------------------------------------
local waiting = {}
local function learnTitle(id)
  local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
  if title then db()[norm(title)] = true; return true end
  return false
end
local function scanHistory()
  if not (C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs) then return end
  local ids = C_QuestLog.GetAllCompletedQuestIDs() or {}
  RG.db.historyScanned = RG.db.historyScanned or {}
  local seen = RG.db.historyScanned
  local pending = 0
  for _, id in ipairs(ids) do
    if not seen[id] then
      if learnTitle(id) then seen[id] = true
      elseif C_QuestLog.RequestLoadQuestByID then
        waiting[id] = true; pending = pending + 1
        C_QuestLog.RequestLoadQuestByID(id)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Auto-detected steps. Returns true when the game confirms a step is done.
-- ---------------------------------------------------------------------------
local QUEST_NAMES -- every quest name the route mentions, longest first
local function questNames()
  if QUEST_NAMES then return QUEST_NAMES end
  local set = {}
  for _, dq in pairs(RG.DUNGEON_QUESTS or {}) do for _, q in ipairs(dq.quests) do set[q[1]:gsub("%s*%(.-%)$", "")] = true end end
  for _, g in ipairs(RG.GUIDE or {}) do if g.how == "Quest" and g.src then set[(g.src:gsub("%s*%(.-%)$", ""))] = true end end
  for k in pairs(RG.QUEST_IDS) do set[k] = true end
  for _, n in ipairs(RG.CLASS_QUESTS or {}) do set[n] = true end
  QUEST_NAMES = {}
  for n in pairs(set) do if #n > 6 then QUEST_NAMES[#QUEST_NAMES + 1] = n end end
  table.sort(QUEST_NAMES, function(a, b) return #a > #b end)
  return QUEST_NAMES
end

local function knowsSpell(name)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(name)
    if not info then return false end
    if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then return C_SpellBook.FindSpellBookSlotForSpell(info.spellID) ~= nil end
    if IsPlayerSpell then return IsPlayerSpell(info.spellID) end
    return true
  end
  return GetSpellInfo and GetSpellInfo(name) ~= nil
end

-- Profession starter quests (Camping 101, Craftsman's Writ, ...) are not part of the levelling route: they pull you off
-- your quests to a trainer. They stay out of the route and the new-quest list unless you turn "profQuests" on or
-- have already picked one up. A reminder near the trainers (ProfNudge.lua) covers professions instead.
local PROF_QUEST = { "^Camping 101", "^Craftsman's Writ", "^An Enchanting Lesson", "^Stolen Enchanting Supplies", "^My First Alchemy Set",
  "^My First Real Potion", "^I Need a Tailor", "^Leather Technique" }
function RG.IsProfQuestName(name)
  if not name then return false end
  for _, p in ipairs(PROF_QUEST) do if name:find(p) then return true end end
  return false
end
function RG.HideProfQuest(id, name)
  if RG.Opt and RG.Opt("profQuests") then return false end
  name = name or (id and RG.QDATA and RG.QDATA[id] and RG.QDATA[id].n)
  if not RG.IsProfQuestName(name) then return false end
  if id and C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id) then return false end   -- you picked it up yourself
  return true
end

-- entry = the route entry the step belongs to; text = the step text.
-- Returns done (bool), reason (short text for the tooltip).
function RG.StepAuto(entry, text)
  local key = entry and (entry.zone .. "|" .. entry.from)
  local sq = key and RG.STEP_QUESTS and RG.STEP_QUESTS[key]
  if sq and text then
    for i, t in ipairs(RG.STEPS[key] or {}) do
      if t == text and sq[i] then
        local left = 0
        local isDone = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
        for _, id in ipairs(sq[i]) do
          -- repeatable quests are never marked done by the game: they don't hold a step open
          local rq = RG.QDATA and RG.QDATA[id]
          local ok = (rq and rq.rep) or (isDone and isDone(id)) or RG.HideProfQuest(id)
          -- one of a pair of either/or quests counts for both
          local d = not ok and RG.QDATA and RG.QDATA[id]
          if d and d.x and isDone then for _, x in ipairs(d.x) do if isDone(x) then ok = true break end end end
          if not ok then left = left + 1 end
        end
        if left == 0 then return true, "All its quests are turned in" end
        return false
      end
    end
  end
  local t = text:lower()
  -- flight paths
  if t:find("flight path", 1, true) then
    -- every flight master in the game (both factions), so Alliance steps tick off too
    local places = { entry.fp }
    for _, f in ipairs(RG.FLIGHTS or {}) do places[#places + 1] = f[1] end
    for _, place in ipairs(places) do
      if place and t:find(place:lower(), 1, true) and RG.KnowsFP(place) then return true, "You know the " .. place .. " flight path" end
    end
    if entry.fp and t:find("grab the flight path", 1, true) and RG.KnowsFP(entry.fp) then return true, "You know this flight path" end
  end
  -- hearthstone
  if (t:find("make it your home", 1, true) or t:find("hearthstone", 1, true)) and GetBindLocation then
    local bind = (GetBindLocation() or ""):lower()
    if bind ~= "" and (t:find(bind, 1, true) or (entry.hub and entry.hub:lower():find(bind, 1, true))) then return true, "Your hearthstone is set to " .. GetBindLocation() end
  end
  -- professions
  if t:find("learn your professions", 1, true) or t:find("train mining and blacksmithing", 1, true) then
    local p, n = RG.Professions(), 0
    for _, name in ipairs({ "Mining", "Blacksmithing", "Herbalism", "Alchemy", "Skinning", "Leatherworking", "Tailoring", "Enchanting", "Engineering" }) do if p[name] then n = n + 1 end end
    if n >= 2 then return true, "You know two professions" end
  end
  -- spells
  if t:find("seal of command", 1, true) and knowsSpell("Seal of Command") then return true, "You know Seal of Command" end
  -- named quests
  for _, n in ipairs(questNames()) do
    if t:find(n:lower(), 1, true) then
      if RG.QuestState(n) == "done" then return true, "Quest turned in: " .. n end
    end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_DATA_LOAD_RESULT", "PLAYER_LEVEL_UP", "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED" }) do pcall(f.RegisterEvent, f, e) end
local refreshQueued
local function queueRefresh()
  if refreshQueued then return end
  refreshQueued = true
  C_Timer.After(0.5, function() refreshQueued = nil; logStamp = nil; if RG.RefreshUI then RG.RefreshUI() end end)
end
f:SetScript("OnEvent", function(_, event, a1, a2)
  if RG.IsAlt and RG.IsAlt() then return end -- a bank alt's quests aren't your main's
  if event == "PLAYER_LOGIN" then
    C_Timer.After(5, scanHistory)
  elseif event == "QUEST_TURNED_IN" then
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(a1)
    if title then
      db()[norm(title)] = true
      for _, n in ipairs(questNames()) do
        if norm(n) == norm(title) then RG.Print("Route step done: " .. title) break end
      end
    end
    queueRefresh()
  elseif event == "QUEST_DATA_LOAD_RESULT" then
    if waiting[a1] then
      waiting[a1] = nil
      if a2 and learnTitle(a1) then RG.db.historyScanned[a1] = true end
      queueRefresh()
    end
  else
    queueRefresh()
  end
end)

-- ---------------------------------------------------------------------------
-- Open a quest in the game's own quest log (by title and/or quest ID).
-- Returns true if the quest is in your log and the log was opened to it.
-- ---------------------------------------------------------------------------
local function findInLog(key, qid)
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and ((qid and info.questID == qid) or (key and info.title and norm(info.title) == key)) then return i, info.questID end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() do
      local title, _, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
      if title and not isHeader and ((qid and id == qid) or (key and norm(title) == key)) then return i, id end
    end
  end
end

function RG.InLog(title, qid)
  return findInLog(norm(title and (title:gsub("%s*%(.-%)$", ""))), qid) ~= nil
end

function RG.OpenQuest(title, qid)
  local key = norm(title and (title:gsub("%s*%(.-%)$", "")))
  local idx, id = findInLog(key, qid)
  if not idx and ExpandQuestHeader then
    -- the quest may sit under a collapsed zone header
    pcall(ExpandQuestHeader, 0)
    idx, id = findInLog(key, qid)
  end
  if not idx then return false end
  qid = qid or id
  local ok = pcall(function()
    local frame = QuestLogFrame
    if frame then
      -- clicking the quest that's already open closes the log again
      if frame:IsShown() and GetQuestLogSelection and GetQuestLogSelection() == idx then
        if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
        return
      end
      if not frame:IsShown() then if ShowUIPanel then ShowUIPanel(frame) else frame:Show() end end
      if QuestLog_SetSelection then QuestLog_SetSelection(idx) elseif SelectQuestLogEntry then SelectQuestLogEntry(idx) end
      -- scroll the list so the quest is in view
      local bar = QuestLogListScrollFrameScrollBar
      local shown = QUESTS_DISPLAYED or 6
      local h = QUESTLOG_QUEST_HEIGHT or 16
      if bar and bar.SetValue then bar:SetValue(math.max(0, idx - math.floor(shown / 2) - 1) * h) end
      if QuestLog_Update then QuestLog_Update() end
    elseif qid and QuestMapFrame_OpenToQuestDetails then
      QuestMapFrame_OpenToQuestDetails(qid)
    elseif ToggleQuestLog then
      if C_QuestLog and C_QuestLog.SetSelectedQuest and qid then C_QuestLog.SetSelectedQuest(qid) end
      ToggleQuestLog()
    end
  end)
  if not ok then RG.Print("Couldn't open the quest log right now (try again out of combat).") end
  return true
end

-- Quests in your log that a piece of guide text names (e.g. a route step or a
-- gear source). Returns a list of { title, id, complete, level }.
function RG.QuestsInText(text)
  local out = {}
  if not text or text == "" then return out end
  local t = text:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  for key, q in pairs(RG.QuestLog()) do
    if #key >= 5 and t:find(key, 1, true) then
      out[#out + 1] = { title = q.title or key, id = q.id, complete = q.complete, level = q.level }
    end
  end
  table.sort(out, function(a, b) return (a.title or "") < (b.title or "") end)
  return out
end
