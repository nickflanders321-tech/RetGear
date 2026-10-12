-- RetGear speed tools (ideas from RestedXP and other speed-leveling addons):
-- auto accept/turn-in with smart rewards, a quest-mob targeting macro and
-- bar, quest item buttons, quest mob nameplate alerts, a waypoint arrow,
-- leveling pace per level, and a bag-space reminder.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local GOLDC = { 0.83, 0.71, 0.42 }

for _, o in ipairs({
  { key = "autoQuest",     label = "Auto accept and turn in quests (hold Shift to pause)", default = true },
  { key = "autoReward",    label = "Auto pick quest rewards when the choice is clear", default = true },
  { key = "targetBar",     label = "Quest target bar and RetGearTarget macro", default = true },
  { key = "questItems",    label = "Buttons for quest items you need to use", default = true },
  { key = "nameplateAlert", label = "Tell me when a quest mob shows up nearby", default = true },
  { key = "arrow",         label = "Arrow to your map pin (/rg way 45 60)", default = true },
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
  if r.upI and (not r.healI or r.healI == r.upI) then pick, why = r.upI, string.format("+%.0f Ret score", r.up)
  elseif not r.upI and not r.healI and r.goldI then pick, why = r.goldI, "sells for the most"
  end
  if pick then
    RG.Print("Picked " .. (GetQuestItemLink("choice", pick) or "a reward") .. GREY .. " (" .. why .. ")|r")
    GetQuestReward(pick)
  elseif r.upI and r.healI then
    RG.Print("Your call: " .. (GetQuestItemLink("choice", r.upI) or "") .. " is a Ret upgrade, " .. (GetQuestItemLink("choice", r.healI) or "") .. " is a healing set upgrade.")
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
  return names
end
RG.QuestTargets = questTargets
local targetSet = {}

local MACRO = "RetGearTarget"
local function updateMacro(list)
  if not (CreateMacro and EditMacro and GetMacroIndexByName) then return end
  local body = "/cleartarget\n"
  for _, t in ipairs(list) do
    local line = "/targetexact " .. t.name .. "\n"
    if #body + #line > 250 then break end
    body = body .. line
  end
  if #list == 0 then body = body .. "/run print(\"RetGear: no quest mobs to target\")" end
  local idx = GetMacroIndexByName(MACRO)
  if idx and idx > 0 then EditMacro(idx, MACRO, nil, body)
  else pcall(CreateMacro, MACRO, "INV_Misc_Spyglass_03", body, nil) end
end

local bar, targetBtns, itemBtns = nil, {}, {}
local function buildBar()
  if bar then return end
  bar = CreateFrame("Frame", "RetGearSpeedBar", UIParent, "BackdropTemplate")
  bar:SetSize(200, 30); bar:SetMovable(true); bar:SetClampedToScreen(true)
  local pos = RetGearDB.speedBarPos
  if pos then bar:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else bar:SetPoint("CENTER", UIParent, "CENTER", 0, -230) end
  local handle = CreateFrame("Frame", nil, bar)
  handle:SetSize(12, 30); handle:SetPoint("LEFT"); handle:EnableMouse(true); handle:RegisterForDrag("LeftButton")
  local ht = handle:CreateTexture(nil, "ARTWORK"); ht:SetAllPoints(); ht:SetColorTexture(GOLDC[1], GOLDC[2], GOLDC[3], 0.5)
  handle:SetScript("OnDragStart", function() if not combat() then bar:StartMoving() end end)
  handle:SetScript("OnDragStop", function()
    bar:StopMovingOrSizing()
    local p, _, _, x, y = bar:GetPoint(); RetGearDB.speedBarPos = { p, x, y }
  end)
  handle:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("RetGear quest bar"); GameTooltip:AddLine("Drag to move. Buttons: quest items to use, then quest mobs to target.", 1, 1, 1, true); GameTooltip:Show() end)
  handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function secureButton(list, i, kind)
  local b = list[i]
  if b then return b end
  b = CreateFrame("Button", "RetGear" .. kind .. i, bar, "SecureActionButtonTemplate, BackdropTemplate")
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
  local name = UnitName(unit)
  local t = name and targetSet[name]
  if not t or UnitIsDead(unit) then return end
  if lastAlert[name] and GetTime() - lastAlert[name] < 45 then return end
  lastAlert[name] = GetTime()
  RG.Print(GOLD .. "Quest mob nearby:|r " .. name .. GREY .. (t.have and t.need and string.format("  (%d/%d)", t.have, t.need) or "") .. "  ·  press your RetGearTarget macro|r")
  if RG.Opt("sounds") and PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.MAP_PING or 3175) end
end

-- ===========================================================================
-- 3. Waypoint arrow (points at your map pin)
-- ===========================================================================
local arrow
local function worldPos(mapID, pos)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and mapID and pos) then return nil end
  local cont, wp = C_Map.GetWorldPosFromMapPos(mapID, pos)
  if not wp then return nil end
  return cont, wp.x, wp.y
end
local function buildArrow()
  if arrow then return end
  arrow = CreateFrame("Frame", "RetGearArrow", UIParent)
  arrow:SetSize(56, 70); arrow:SetMovable(true); arrow:EnableMouse(true); arrow:RegisterForDrag("LeftButton"); arrow:SetClampedToScreen(true)
  local pos = RetGearDB.arrowPos
  if pos then arrow:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else arrow:SetPoint("TOP", UIParent, "TOP", 0, -160) end
  arrow:SetScript("OnDragStart", arrow.StartMoving)
  arrow:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, _, x, y = self:GetPoint(); RetGearDB.arrowPos = { p, x, y } end)
  arrow.tex = arrow:CreateTexture(nil, "ARTWORK"); arrow.tex:SetSize(42, 42); arrow.tex:SetPoint("TOP")
  arrow.tex:SetTexture("Interface\\Minimap\\MinimapArrow"); arrow.tex:SetVertexColor(GOLDC[1], GOLDC[2], GOLDC[3])
  arrow.dist = arrow:CreateFontString(nil, "OVERLAY"); arrow.dist:SetFont("Fonts\\ARIALN.TTF", 13, "OUTLINE"); arrow.dist:SetPoint("TOP", arrow.tex, "BOTTOM", 0, -2)
  arrow:SetScript("OnMouseUp", function(_, btn) if btn == "RightButton" and C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint(); arrow:Hide() end end)
  local acc = 0
  arrow:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt; if acc < 0.05 then return end; acc = 0
    local wp = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local ppos = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    local facing = GetPlayerFacing and GetPlayerFacing()
    if not (wp and ppos and facing) then self:Hide(); return end
    local c1, px, py = worldPos(mapID, ppos)
    local c2, tx, ty = worldPos(wp.uiMapID, wp.position)
    if not (c1 and c2 and c1 == c2) then self.dist:SetText(GREY .. "other continent|r"); return end
    local dx, dy = tx - px, ty - py -- x = north, y = west
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 8 then RG.Print(GREEN .. "Arrived.|r"); if C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end; self:Hide(); return end
    local bearing = math.atan2(dy, dx)
    self.tex:SetRotation(bearing - facing)
    self.dist:SetText(string.format("%d yd", d))
  end)
end
local function refreshArrow()
  if not RG.Opt("arrow") or (RG.IsAlt and RG.IsAlt()) then if arrow then arrow:Hide() end return end
  local has = C_Map and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()
  if has then buildArrow(); arrow:Show() elseif arrow then arrow:Hide() end
end
function RG.SetWaypoint(x, y)
  if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint) then RG.Print("This client doesn't support map pins.") return end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID or (C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID)) then RG.Print("Can't place a pin here.") return end
  C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
  refreshArrow()
  RG.Print(string.format("Pin set at %.1f, %.1f. Follow the arrow (right-click it to clear).", x, y))
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
      out[#out + 1] = { "|TInterface\\Icons\\INV_Misc_Bag_08:14:14|t " .. (free == 0 and RED or GOLD) .. "Bags " .. (free == 0 and "full" or ("almost full: " .. free .. " free")) .. "|r" .. GREY .. ". Vendor, bank" .. ((RG.IsAlt and not RG.IsAlt() and RG.db.main) and ", or mail spare mats to your bank alt" or "") .. "|r" }
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
  "UI_ERROR_MESSAGE", "USER_WAYPOINT_UPDATED", "SUPER_TRACKING_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do pcall(f.RegisterEvent, f, e) end
local barQueued
local function queueBar() if barQueued then return end; barQueued = true; C_Timer.After(0.5, function() barQueued = nil; refreshBar() end) end
f:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "PLAYER_LOGIN" then
    C_Timer.NewTicker(30, paceTick)
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
  else
    if paused and (event == "QUEST_REMOVED" or event == "BAG_UPDATE_DELAYED") and freeSlots() > 0 then paused = false end
    queueBar()
  end
end)

local base = SlashCmdList.RETGEAR
SlashCmdList.RETGEAR = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.*)$")
  cmd = cmd and cmd:lower()
  if cmd == "way" then
    local x, y = (rest or ""):match("([%d%.]+)[,%s]+([%d%.]+)")
    if x and y then RG.SetWaypoint(tonumber(x), tonumber(y)) else RG.Print("Usage: /rg way 45.2 60.8  (coordinates in your current zone)") end
    return
  elseif cmd == "auto" then
    RetGearDB.autoQuest = not RG.Opt("autoQuest"); paused = false
    RG.Print("Auto accept and turn in " .. (RG.Opt("autoQuest") and "on (hold Shift to pause)." or "off."))
    return
  elseif cmd == "pace" then
    local cur, last, avg = RG.Pace()
    RG.Print(string.format("This level: %s  ·  last level: %s  ·  average of last 5: %s", RG.FormatDuration(cur), RG.FormatDuration(last), RG.FormatDuration(avg)))
    return
  end
  return base(msg)
end
