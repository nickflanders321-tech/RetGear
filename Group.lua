-- Waypath+ group play: evaluate how grouping goes (XP/hr solo vs grouped,
-- dungeon run reports) and help you be a great paladin in a party
-- (Blessings, Auras, dispels, emergencies, shared quests, finding a group).
local _, RG = ...
-- bitwise AND (WoW ships the bit library; this fallback keeps it working anywhere)
local band = (bit and bit.band) or function(a, b)
  local r, m = 0, 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then r = r + m end
    a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
  end
  return r
end
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY

table.insert(RG.OPTIONS, { key = "groupDuties", label = "Group helper in a party: buff and aura reminders, shared quests, LFG posts", default = true })
table.insert(RG.OPTIONS, { key = "groupAlerts", label = "Group alerts: a party member to dispel, or one about to die", default = true })

local function grouped() return (GetNumGroupMembers and GetNumGroupMembers() or 0) > 1 end
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function knows(name)
  if C_Spell and C_Spell.GetSpellInfo then local i = C_Spell.GetSpellInfo(name); return i and (not IsPlayerSpell or IsPlayerSpell(i.spellID)) end
  return GetSpellInfo and GetSpellInfo(name) ~= nil
end
local function db()
  RG.db.xpMode = RG.db.xpMode or {}
  RG.db.runs = RG.db.runs or {}
  return RG.db
end
local function partyUnits()
  local out = {}
  if IsInRaid and IsInRaid() then return out end
  for i = 1, 4 do local u = "party" .. i; if RG.SafeCall(UnitExists, u) then out[#out + 1] = u end end
  return out
end

-- ---------------------------------------------------------------------------
-- 1. XP per hour, solo vs grouped (per character level)
-- ---------------------------------------------------------------------------
local lastXP, lastMax
local function addXP()
  local xp, max = UnitXP("player"), UnitXPMax("player")
  if lastXP then
    local gained = xp >= lastXP and (xp - lastXP) or ((lastMax or 0) - lastXP + xp)
    if gained > 0 and gained < 200000 then
      local m = db().xpMode
      local lvl = UnitLevel("player")
      m[lvl] = m[lvl] or { 0, 0, 0, 0 } -- solo xp, solo sec, group xp, group sec
      if grouped() then m[lvl][3] = m[lvl][3] + gained else m[lvl][1] = m[lvl][1] + gained end
    end
  end
  lastXP, lastMax = xp, max
end
local function timeTick()
  if UnitIsAFK and UnitIsAFK("player") then return end
  if (UnitLevel("player") or 60) >= 60 then return end
  local m = db().xpMode
  local lvl = UnitLevel("player")
  m[lvl] = m[lvl] or { 0, 0, 0, 0 }
  if grouped() then m[lvl][4] = m[lvl][4] + 30 else m[lvl][2] = m[lvl][2] + 30 end
end
-- XP per hour solo and grouped over your last few levels (nil when there isn't enough data).
function RG.XPModes(levels)
  local m = db().xpMode
  local lvl = UnitLevel("player")
  local sx, st, gx, gt = 0, 0, 0, 0
  for l = lvl, math.max(1, lvl - (levels or 5) + 1), -1 do
    local e = m[l]
    if e then sx, st, gx, gt = sx + e[1], st + e[2], gx + e[3], gt + e[4] end
  end
  local solo = st >= 600 and sx / st * 3600 or nil
  local group = gt >= 600 and gx / gt * 3600 or nil
  return solo, group, st, gt
end

-- ---------------------------------------------------------------------------
-- 2. Dungeon run reports
-- ---------------------------------------------------------------------------
local run
local function startRun()
  local name, instType = GetInstanceInfo and GetInstanceInfo()
  if instType ~= "party" then return end
  run = { name = name or "Dungeon", t = time(), start = GetTime(), xp = 0, kills = 0, deaths = 0, myDeaths = 0, loot = {}, size = GetNumGroupMembers and GetNumGroupMembers() or 1, level = UnitLevel("player") }
  RG.Print(GOLD .. run.name .. "|r: run started. Waypath+ will report when you leave.")
end
local function finishRun()
  if not run then return end
  local r = run; run = nil
  r.dur = GetTime() - r.start; r.start = nil
  if r.dur < 120 then return end -- zoned in and out
  r.xpHr = r.dur > 0 and r.xp / r.dur * 3600 or 0
  table.insert(db().runs, 1, r)
  for i = #RG.db.runs, 16, -1 do RG.db.runs[i] = nil end
  RG.Print(string.format("%s%s|r run: %s, %d kills, %d deaths, %s XP (%.1fk/hr)",
    GOLD, r.name, RG.FormatDuration and RG.FormatDuration(r.dur) or (math.floor(r.dur / 60) .. "m"), r.kills, r.deaths, BreakUpLargeNumbers and BreakUpLargeNumbers(r.xp) or r.xp, r.xpHr / 1000))
  if #r.loot > 0 then RG.Print("  Loot: " .. table.concat(r.loot, " ")) end
  if RG.RefreshUI then RG.RefreshUI() end
end

-- ---------------------------------------------------------------------------
-- 3. Paladin duties: Blessings and Auras
-- ---------------------------------------------------------------------------
local MIGHT_CLASSES = { WARRIOR = true, ROGUE = true, PALADIN = true }
function RG.SuggestBlessing(unit)
  local _, class = RG.SafeUnit(UnitClass, unit)
  if class and MIGHT_CLASSES[class] then return "Blessing of Might" end
  if knows("Blessing of Wisdom") then return "Blessing of Wisdom" end
  return "Blessing of Might"
end
-- Returns the Blessing name, or nil; second value true when auras can't be read (combat).
local function myBlessingOn(unit)
  return RG.FindAura(unit, "HELPFUL", function(a)
    return a.name:find("Blessing of") and (a.sourceUnit == "player" or a.isFromPlayerOrPlayerPet) and a.name
  end)
end
RG.MyBlessingOn = myBlessingOn
local lastAura
local function myAura()
  local name, blocked = RG.FindAura("player", "HELPFUL", function(a)
    return a.name:find(" Aura$") and (a.sourceUnit == "player" or a.isFromPlayerOrPlayerPet) and a.name
  end)
  if blocked then return lastAura end
  lastAura = name
  return name
end
RG.MyAura = myAura
-- Party members missing a Blessing from you: { {unit, name, suggest}, ... }
function RG.UnblessedParty()
  local out = {}
  if not knows("Blessing of Might") then return out end
  for _, u in ipairs(partyUnits()) do
    local has, blocked = myBlessingOn(u)
    if blocked then return {} end
    if not RG.SafeCall(UnitIsDeadOrGhost, u) and not has then out[#out + 1] = { unit = u, name = RG.SafeName(u) or u, suggest = RG.SuggestBlessing(u) } end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- 4. Group quests and shared quests
-- ---------------------------------------------------------------------------
local function tagOf(questID)
  if C_QuestLog and C_QuestLog.GetQuestTagInfo then
    local ok, info = pcall(C_QuestLog.GetQuestTagInfo, questID)
    if ok and info and info.tagName then return info.tagName end
  end
end
local function onQuest(unit, questID, logIndex)
  if C_QuestLog and C_QuestLog.IsUnitOnQuest then
    local ok, v = pcall(C_QuestLog.IsUnitOnQuest, unit, questID)
    if ok and v ~= nil then return v and true or false end
  end
  if IsUnitOnQuest and logIndex then local ok, v = pcall(IsUnitOnQuest, logIndex, unit); if ok then return v and true or false end end
  return nil
end
-- Your quests with a group tag (Group, Elite, Dungeon) and who in your party has each quest.
function RG.GroupQuestInfo()
  local list = {}
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return list end
  local units = partyUnits()
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHeader and info.questID then
      local e = { id = info.questID, title = info.title, index = i, tag = tagOf(info.questID), have = {}, missing = {},
        complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) }
      for _, u in ipairs(units) do
        local on = onQuest(u, info.questID, i)
        if on == true then e.have[#e.have + 1] = RG.SafeName(u) or u elseif on == false then e.missing[#e.missing + 1] = RG.SafeName(u) or u end
      end
      list[#list + 1] = e
    end
  end
  return list
end
function RG.ShareQuest(questID)
  if C_QuestLog and C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(questID) end
  if QuestLogPushQuest then QuestLogPushQuest(); RG.Print("Sharing the quest with your party.") end
end

-- ---------------------------------------------------------------------------
-- 5. Find a group: what to ask for and a ready-made LFG post
-- ---------------------------------------------------------------------------
function RG.GroupSuggestions()
  local lvl = UnitLevel("player")
  local out = {}
  for _, r in ipairs(RG.ROUTE or {}) do
    if r.kind == "dungeon" and lvl >= r.from - 1 and lvl <= r.to then
      local dq = RG.DUNGEON_QUESTS and RG.DUNGEON_QUESTS[r.zone]
      out[#out + 1] = { kind = "dungeon", name = r.zone, note = dq and ("Go at " .. dq.go .. ", " .. #dq.quests .. " quests") or r.notes, from = r.from, to = r.to }
    end
  end
  for _, q in ipairs(RG.GroupQuestInfo()) do
    if q.tag and (q.tag:find("Group") or q.tag:find("Elite")) and not q.complete then out[#out + 1] = { kind = "quest", name = q.title, note = q.tag } end
  end
  return out
end
function RG.LFGMessage(what)
  local cls = RG.ActiveClass or {}
  local who = (RG.ClassSupported and cls.lfgName) or (RG.ClassSupported and cls.spec) and (cls.spec .. " " .. (cls.name or "")) or (UnitClass("player") or "")
  local extra = RG.ClassSupported and cls.lfgNote and (" (" .. cls.lfgNote .. ")") or ""
  return string.format("LFG %s - %s %d%s", what, who, UnitLevel("player"), extra)
end
function RG.PostLFG(what)
  local msg = RG.LFGMessage(what)
  local id = GetChannelName and GetChannelName("LookingForGroup")
  if id and id > 0 and SendChatMessage then
    SendChatMessage(msg, "CHANNEL", nil, id)
    RG.Print("Posted in LookingForGroup: " .. msg)
  elseif ChatFrame_OpenChat then
    ChatFrame_OpenChat(msg)
    RG.Print("Pick a channel and press Enter. (/join LookingForGroup to post there with one click.)")
  end
end

-- ---------------------------------------------------------------------------
-- 6. Alerts: dispels and party members about to die
-- ---------------------------------------------------------------------------
local alerted = {}
local function center(msg)
  if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(msg, 1, 0.82, 0, 1, 4) else RG.Print(msg) end
end
local function throttle(key, sec) if alerted[key] and GetTime() - alerted[key] < sec then return false end alerted[key] = GetTime(); return true end
local function checkDispel(unit)
  if not RG.Opt("groupAlerts") then return end
  local purify, cleanse = knows("Purify"), knows("Cleanse")
  if not (purify or cleanse) then return end
  -- Debuffs are hidden from addons in combat on this client; then this stays quiet.
  RG.FindAura(unit, "HARMFUL", function(a)
    local t = a.dispelName
    local spell = (t == "Magic" and cleanse and "Cleanse") or ((t == "Poison" or t == "Disease") and (cleanse and "Cleanse" or "Purify")) or nil
    if spell and throttle(unit .. t, 8) then
      center(string.format("%s: %s %s (%s)", spell, RG.SafeName(unit) or unit, "has " .. (a.name or t), t))
      return true
    end
  end)
end
local function checkHealth(unit)
  if not RG.Opt("groupAlerts") or not inCombat() then return end
  local hp, max = RG.SafeUnit(UnitHealth, unit), RG.SafeUnit(UnitHealthMax, unit)
  if not hp or not max or max == 0 or RG.SafeUnit(UnitIsDeadOrGhost, unit) then return end
  if hp / max < 0.25 and throttle("hp" .. unit, 20) then
    local saves = {}
    if knows("Lay on Hands") then saves[#saves + 1] = "Lay on Hands" end
    if knows("Blessing of Protection") then saves[#saves + 1] = "Blessing of Protection" end
    if #saves > 0 then center(string.format("%s is dying! %s", RG.SafeName(unit) or unit, table.concat(saves, " or "))) end
  end
end

-- ---------------------------------------------------------------------------
-- Tracker reminders
-- ---------------------------------------------------------------------------
local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  if RG.IsAlt and RG.IsAlt() or inCombat() then return out end
  if grouped() and RG.Opt("groupDuties") then
    local need = RG.UnblessedParty()
    if #need > 0 then
      local who = {}
      for i = 1, math.min(4, #need) do who[i] = need[i].name .. GREY .. " (" .. need[i].suggest:gsub("Blessing of ", "") .. ")|r" end
      out[#out + 1] = { "|TInterface\\Icons\\Spell_Holy_FistOfJustice:14:14|t " .. GOLD .. "Bless your group:|r " .. table.concat(who, ", "), function() if RG.ShowTab then RG.ShowTab("group") end end, 2 }
    end
    if knows("Devotion Aura") and not myAura() then
      out[#out + 1] = { "|TInterface\\Icons\\Spell_Holy_DevotionAura:14:14|t " .. GOLD .. "Turn on an Aura|r" .. GREY .. " (Retribution for damage, Devotion if the tank struggles)|r", nil, 2 }
    end
  elseif not grouped() then
    local n = 0
    for _, q in ipairs(RG.GroupQuestInfo()) do if q.tag and (q.tag:find("Group") or q.tag:find("Elite")) and not q.complete then n = n + 1 end end
    if n > 0 then out[#out + 1] = { "|TInterface\\Icons\\INV_Misc_GroupNeedMore:14:14|t " .. GOLD .. n .. " group quest" .. (n > 1 and "s" or "") .. " in your log|r" .. GREY .. ": find a group (Group tab)|r", function() if RG.ShowTab then RG.ShowTab("group") end end, 6 } end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_XP_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "UNIT_AURA", "UNIT_HEALTH", "COMBAT_LOG_EVENT_UNFILTERED", "CHAT_MSG_LOOT", "PLAYER_DEAD" }) do pcall(f.RegisterEvent, f, e) end
local myGUID
f:SetScript("OnEvent", function(_, event, a1, ...)
  if RG.IsAlt and RG.IsAlt() then return end
  if event == "PLAYER_LOGIN" then
    myGUID = UnitGUID("player"); lastXP, lastMax = UnitXP("player"), UnitXPMax("player")
    C_Timer.NewTicker(30, timeTick)
  elseif event == "PLAYER_XP_UPDATE" then
    local before = lastXP
    addXP()
    if run and before then local gained = (UnitXP("player") >= before) and (UnitXP("player") - before) or 0; run.xp = run.xp + gained end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    local inInst, instType = IsInInstance and IsInInstance()
    if inInst and instType == "party" then
      local name = GetInstanceInfo and GetInstanceInfo()
      if not run or run.name ~= name then if run then finishRun() end; startRun() end
    elseif run then finishRun() end
  elseif event == "GROUP_ROSTER_UPDATE" then
    if RG.QueueTracker then RG.QueueTracker() end
  elseif event == "UNIT_AURA" then
    if a1 and a1:find("^party%d") then checkDispel(a1); if not inCombat() and RG.QueueTracker then RG.QueueTracker() end end
  elseif event == "UNIT_HEALTH" then
    if a1 and a1:find("^party%d") then pcall(checkHealth, a1) end
  elseif event == "CHAT_MSG_LOOT" then
    if run and a1 then
      local link = a1:match("|c%x+|Hitem:.-|h.-|h|r")
      local q = link and select(3, RG.ItemInfo(link))
      if link and a1:find("^You ") and (q or 0) >= 2 then run.loot[#run.loot + 1] = link end
    end
  elseif event == "PLAYER_DEAD" then
    if run then run.myDeaths = run.myDeaths + 1 end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and run then
    local ok, _, sub, _, _, _, _, _, _, _, dstFlags = pcall(CombatLogGetCurrentEventInfo)
    if ok and sub == "PARTY_KILL" then run.kills = run.kills + 1
    elseif ok and sub == "UNIT_DIED" and type(dstFlags) == "number" and band(dstFlags, 0x400) ~= 0 and band(dstFlags, 0x7) ~= 0 then run.deaths = run.deaths + 1 end
  end
end)

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.*)$")
  cmd = cmd and cmd:lower()
  if cmd == "group" then if RG.ShowTab then RG.ShowTab("group") end return end
  if cmd == "lfg" then
    local s = RG.GroupSuggestions()[1]
    if rest and rest ~= "" then RG.PostLFG(rest) elseif s then RG.PostLFG(s.name) else RG.Print("Usage: /wp lfg Scarlet Monastery") end
    return
  end
  return base(msg)
end
