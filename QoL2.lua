-- Waypath+ quality of life, part two:
--   * upgrade arrows on bag icons (upgrades for you, pieces for your 2nd spec)
--   * error catcher: Waypath+'s own errors are logged quietly (/wp errors)
--   * turn-in run: the arrow chains through every quest that's ready
--   * abandon grey quests in one click (asks first)
--   * dual-spec gear swap: offers your 2nd spec's set when you switch to that spec
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
table.insert(RG.OPTIONS, { key = "bagArrows", label = "Mark upgrades on bag icons (green arrow: an upgrade for you, light: a piece for your 2nd spec)", default = true })
table.insert(RG.OPTIONS, { key = "specSwap", label = "Offer to swap gear when I change to or from my 2nd spec", default = true })
table.insert(RG.OPTIONS, { key = "quietErrors", label = "Catch Waypath+ errors quietly (see them with /wp errors)", default = true })

local function notify(msg) if RG.Notify then RG.Notify(msg) else RG.Print(msg) end end
local function inCombat() return InCombatLockdown and InCombatLockdown() end

-- ===========================================================================
-- 1. Error catcher
-- ===========================================================================
local MAX_ERRORS = 25
local told = false
local function recordError(msg)
  if not WaypathDB then return end
  WaypathDB.errors = WaypathDB.errors or {}
  local list = WaypathDB.errors
  msg = tostring(msg)
  for _, e in ipairs(list) do
    if e.msg == msg then e.count = (e.count or 1) + 1; e.t = time and time() or 0; return end
  end
  local stack = debugstack and debugstack(3, 12, 0) or ""
  table.insert(list, 1, { msg = msg, stack = stack, count = 1, t = time and time() or 0, v = RG.VERSION })
  while #list > MAX_ERRORS do table.remove(list) end
  if not told then
    told = true
    if C_Timer then C_Timer.After(0.1, function()
      RG.Print(GOLD .. "Waypath+ hit an error|r" .. GREY .. " (it kept running). Type|r /wp errors " .. GREY .. "to see and copy it for a bug report.|r")
    end) end
  end
end
RG.RecordError = recordError

-- When the game blocks something Waypath+ tried (the "blocked from an action only
-- available to the Blizzard UI" pop-up), note exactly what it was, with the game
-- build, so a bug report names it. Blizzard changes which actions add-ons may take.
do
  local bf = CreateFrame("Frame")
  for _, e in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do pcall(bf.RegisterEvent, bf, e) end
  bf:SetScript("OnEvent", function(_, event, addon, func)
    if type(addon) ~= "string" or not addon:find("Waypath", 1, true) then return end
    local build = GetBuildInfo and select(2, GetBuildInfo()) or "?"
    pcall(recordError, "The game blocked Waypath+ from calling " .. tostring(func) .. (event == "ADDON_ACTION_BLOCKED" and " during combat" or "") .. " (game build " .. tostring(build) .. ")")
  end)
end

if seterrorhandler and geterrorhandler then
  local original = geterrorhandler()
  local busy = false
  seterrorhandler(function(msg, ...)
    if not busy and type(msg) == "string" and msg:find("Waypath", 1, true) then
      busy = true
      pcall(recordError, msg)
      busy = false
      local quiet = true
      if RG.Opt and RG.db then local ok, v = pcall(RG.Opt, "quietErrors"); if ok then quiet = v end end
      if quiet then return end
    end
    if original then return original(msg, ...) end
  end)
end

local errFrame
function RG.ShowErrors()
  local list = (WaypathDB and WaypathDB.errors) or {}
  local lines = { "Waypath+ " .. tostring(RG.VERSION or "?") .. "  ·  " .. #list .. " error(s) caught",
    "Paste this when reporting a problem: " .. (RG.DetectLine and RG.DetectLine() or "?") .. "  ·  " .. tostring(RG.PLAYER_FACTION)
      .. "  ·  " .. (GetBuildInfo and select(1, GetBuildInfo()) or "?") .. "  ·  " .. string.format("%.1f MB", (collectgarbage("count") or 0) / 1024) .. " Lua memory", "" }
  for i, e in ipairs(list) do
    lines[#lines + 1] = string.format("#%d  x%d  %s%s", i, e.count or 1, e.v and (tostring(e.v):gsub("^v?", "v") .. "  ") or "", e.t and date and date("%Y-%m-%d %H:%M", e.t) or "")
    lines[#lines + 1] = e.msg or "?"
    if e.stack and e.stack ~= "" then lines[#lines + 1] = e.stack end
    lines[#lines + 1] = ""
  end
  if #list == 0 then lines[#lines + 1] = "No errors. Nice." end
  local text = table.concat(lines, "\n")
  if not errFrame then
    errFrame = CreateFrame("Frame", "WaypathErrors", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    errFrame:SetSize(560, 380); errFrame:SetPoint("CENTER")
    errFrame:SetFrameStrata("DIALOG"); errFrame:SetMovable(true); errFrame:EnableMouse(true)
    errFrame:RegisterForDrag("LeftButton")
    errFrame:SetScript("OnDragStart", errFrame.StartMoving)
    errFrame:SetScript("OnDragStop", errFrame.StopMovingOrSizing)
    if errFrame.SetBackdrop then
      errFrame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
      errFrame:SetBackdropColor(0.05, 0.05, 0.07, 0.95); errFrame:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
    end
    local title = errFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10); title:SetText("Waypath+ errors  ·  Ctrl+A, Ctrl+C to copy")
    local close = CreateFrame("Button", nil, errFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local clear = CreateFrame("Button", nil, errFrame, "UIPanelButtonTemplate")
    clear:SetSize(80, 20); clear:SetPoint("BOTTOMRIGHT", -12, 10); clear:SetText("Clear")
    clear:SetScript("OnClick", function() if WaypathDB then WaypathDB.errors = {} end; RG.ShowErrors() end)
    local sf = CreateFrame("ScrollFrame", nil, errFrame, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -32); sf:SetPoint("BOTTOMRIGHT", -32, 38)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    eb:SetWidth(500)
    eb:SetScript("OnEscapePressed", function() errFrame:Hide() end)
    sf:SetScrollChild(eb)
    errFrame.eb = eb
    if UISpecialFrames then table.insert(UISpecialFrames, "WaypathErrors") end
  end
  errFrame.eb:SetText(text)
  errFrame:Show()
  errFrame.eb:SetFocus(); errFrame.eb:HighlightText()
end

-- ===========================================================================
-- 2. Upgrade arrows on bag icons
-- ===========================================================================
local marks = {}
local function getMark(b)
  local m = marks[b]
  if not m then
    m = {}
    m.up = b:CreateTexture(nil, "OVERLAY", nil, 6)
    m.up:SetSize(15, 15); m.up:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    m.up:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
    m.up:SetTexCoord(0, 1, 1, 0) -- point up
    m.heal = b:CreateTexture(nil, "OVERLAY", nil, 6)
    m.heal:SetSize(13, 13); m.heal:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 2)
    m.heal:SetTexture("Interface\\Icons\\Spell_Holy_HolyBolt")
    m.heal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    marks[b] = m
  end
  return m
end
local cache = {}
local function judge(link)
  local c = cache[link]
  if c and GetTime() - c.t < 5 then return c.up, c.heal end
  local up, heal = false, false
  local loc = RG.EquipLoc(link)
  if loc and RG.EQUIP_SLOTS and RG.EQUIP_SLOTS[loc] then
    local _, _, _, _, minLevel = RG.ItemInfo(link)
    if (minLevel or 0) <= (UnitLevel("player") or 1) then
      local ok, d = pcall(RG.Compare, link)
      up = ok and d and d >= 1 or false
    end
    if RG.HealDelta and (UnitLevel("player") or 1) >= 30 then
      local id = tonumber(link:match("item:(%d+)"))
      local okK, keep = pcall(RG.IsHealKeeper, id)
      local okD, hd = pcall(RG.HealDelta, link)
      heal = (okK and keep) or (okD and hd and hd > 0.5) or false
    end
  end
  cache[link] = { t = GetTime(), up = up, heal = heal }
  return up, heal
end
local function linkAt(bag, slot)
  local C = C_Container
  if C and C.GetContainerItemLink then return C.GetContainerItemLink(bag, slot) end
  if GetContainerItemLink then return GetContainerItemLink(bag, slot) end
end
function RG.UpdateBagArrows()
  if not (RG.db and RG.EachBagButton) then return end
  local enabled = RG.Opt("bagArrows") and not (RG.IsAlt and RG.IsAlt())
  pcall(RG.EachBagButton, function(b, bag, slot)
    local link = enabled and bag and slot and linkAt(bag, slot)
    local up, heal = false, false
    if link then up, heal = judge(link) end
    if up or heal or marks[b] then
      local m = getMark(b)
      m.up:SetShown(up and true or false)
      if heal then
        local s = RG.SecondSpecActive and RG.SecondSpecActive()
        m.heal:SetTexture(s and s.icon or "Interface\\Icons\\Spell_Holy_HolyBolt")
      end
      m.heal:SetShown(heal and true or false)
    end
  end)
end
local function queueArrows() if C_Timer then C_Timer.After(0.1, function() pcall(RG.UpdateBagArrows) end) end end
if hooksecurefunc then
  for _, fn in ipairs({ "ToggleBag", "OpenBag", "OpenAllBags", "ToggleAllBags", "OpenBackpack", "ToggleBackpack", "ContainerFrame_Update" }) do
    if _G[fn] then hooksecurefunc(fn, queueArrows) end
  end
end

-- ===========================================================================
-- 3. Turn-in run
-- ===========================================================================
local run = nil
local function readyQuests()
  local out = {}
  for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do
    if q.complete and q.wp then out[#out + 1] = q end
  end
  return out -- MyQuests sorts ready ones first, nearest first
end
RG.ReadyQuests = readyQuests
function RG.TurnInRunActive() return run ~= nil end
local function runNext()
  if not run then return end
  local list = readyQuests()
  if #list == 0 then
    run = nil
    notify("Turn-in run done: " .. GREEN .. "every ready quest handed in|r")
    if RG.ClearWaypoint then RG.ClearWaypoint() end
  else
    local q = list[1]
    run.current = q.id
    RG.PinWaypoint(q.wp, true)
    notify("Turn in " .. GOLD .. q.title .. "|r" .. (#list > 1 and (GREY .. "  (" .. (#list - 1) .. " more after this)|r") or ""))
  end
  if RG.RefreshTracker then RG.RefreshTracker() end
end
function RG.TurnInRun()
  if run then
    run = nil
    notify("Turn-in run stopped")
    if RG.RefreshTracker then RG.RefreshTracker() end
    return
  end
  local list = readyQuests()
  if #list == 0 then notify("No ready quests with a known turn-in spot"); return end
  run = { started = GetTime() }
  RG.Print(GOLD .. "Turn-in run:|r " .. #list .. " quest" .. (#list > 1 and "s" or "") .. " ready. The arrow takes you to each one, nearest first.")
  runNext()
end

-- ===========================================================================
-- 4. Abandon grey quests
-- ===========================================================================
local GREY_CODE = "|cff808080"
local function greyQuests()
  local out = {}
  for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do
    if not q.complete and RG.QuestColor(q.level) == GREY_CODE then out[#out + 1] = q end
  end
  return out
end
RG.GreyQuests = greyQuests
local function abandonOne(q)
  local Q = C_QuestLog
  if Q and Q.SetSelectedQuest and Q.SetAbandonQuest and Q.AbandonQuest then
    Q.SetSelectedQuest(q.id); Q.SetAbandonQuest(); Q.AbandonQuest(); return true
  end
  if SelectQuestLogEntry and SetAbandonQuest and AbandonQuest then
    local idx = Q and Q.GetLogIndexForQuestID and Q.GetLogIndexForQuestID(q.id)
    if not idx and GetNumQuestLogEntries and GetQuestLogTitle then
      for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader and title == q.title then idx = i; break end
      end
    end
    if idx then SelectQuestLogEntry(idx); SetAbandonQuest(); AbandonQuest(); return true end
  end
  return false
end
local pendingGrey
local function doAbandon()
  local list = pendingGrey or {}
  pendingGrey = nil
  local i, dropped = 0, 0
  local function step()
    i = i + 1
    local q = list[i]
    if not q then
      RG.Print("Abandoned " .. dropped .. " grey quest" .. (dropped == 1 and "" or "s") .. ".")
      if RG.RefreshTracker then RG.RefreshTracker() end
      return
    end
    if pcall(abandonOne, q) then dropped = dropped + 1 end
    C_Timer.After(0.35, step)
  end
  step()
end
if StaticPopupDialogs then
  StaticPopupDialogs.WAYPATH_ABANDON_GREY = {
    text = "%s", button1 = ACCEPT or "Abandon", button2 = CANCEL or "Cancel",
    OnAccept = function() doAbandon() end, OnCancel = function() pendingGrey = nil end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end
function RG.AbandonGreyQuests()
  local list = greyQuests()
  if #list == 0 then notify("No unfinished grey quests in your log"); return end
  pendingGrey = list
  local names = {}
  for i, q in ipairs(list) do
    if i > 8 then names[#names + 1] = "and " .. (#list - 8) .. " more"; break end
    names[#names + 1] = "[" .. (q.level or "?") .. "] " .. q.title
  end
  local text = "Abandon " .. #list .. " grey quest" .. (#list > 1 and "s" or "") .. "? They give almost no XP.\n\n" .. table.concat(names, "\n")
  if StaticPopup_Show then StaticPopup_Show("WAYPATH_ABANDON_GREY", text) else doAbandon() end
end

-- ===========================================================================
-- 5. Dual-spec gear swap
-- ===========================================================================
local SLOT_FOR = { Head = { 1 }, Neck = { 2 }, Shoulder = { 3 }, Back = { 15 }, Chest = { 5 }, Wrist = { 9 }, Hands = { 10 },
  Waist = { 6 }, Legs = { 7 }, Feet = { 8 }, Ring = { 11, 12 }, Trinket = { 13, 14 }, ["Main Hand"] = { 16 }, ["Two-Hand"] = { 16 },
  ["Off Hand"] = { 17 }, Relic = { 18 }, Ranged = { 18 } }
local GROUP_ORDER = { "Main Hand", "Two-Hand", "Off Hand", "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Ring", "Trinket", "Relic", "Ranged" }

-- Which talent tree has the most points (1-3), or nil early on.
function RG.CurrentTree()
  local t = RG.ReadTalents and RG.ReadTalents()
  if not t then return nil end
  local by = {}
  for _, v in pairs(t) do if v.tab then by[v.tab] = (by[v.tab] or 0) + (tonumber(v.rank) or 0) end end
  local best, bestN = nil, 0
  for tab, n in pairs(by) do if n > bestN then best, bestN = tab, n end end
  if not best or bestN < 5 then return nil end
  return best
end
-- "second" when your talents are in your 2nd spec's tree, "main" when they're in
-- your leveling spec's tree, nil otherwise (or when both specs share a tree, like
-- Cat and Bear: swap those by hand).
function RG.CurrentRole()
  local tree = RG.CurrentTree()
  local second, main = RG.SecondSpecActive and RG.SecondSpecActive(), RG.MainSpec and RG.MainSpec()
  if not (tree and second and main) or second.tab == main.tab then return nil end
  if tree == second.tab then return "second" elseif tree == main.tab then return "main" end
end
local function secondName() local s = RG.SecondSpecActive and RG.SecondSpecActive(); return s and s.name or "2nd spec" end
local function mainName() local s = RG.MainSpec and RG.MainSpec(); return s and s.name or "main" end
RG.SecondSpecName, RG.MainSpecName = secondName, mainName

local function equipQueue(jobs, done)
  local equip = (C_Item and C_Item.EquipItemByName) or EquipItemByName
  local i = 0
  local function step()
    i = i + 1
    local j = jobs[i]
    if not j then if done then done() end; return end
    if inCombat() then RG.Print("Gear swap paused: you're in combat. Run it again after the fight."); return end
    pcall(equip, j[1], j[2])
    C_Timer.After(0.3, step)
  end
  step()
end

local function idAt(slot) return GetInventoryItemID and GetInventoryItemID("player", slot) end

function RG.EquipHealSet()
  if inCombat() then RG.Print("You can't change gear in combat."); return end
  if not (RG.HealSet and RG.SecondSpecActive and RG.SecondSpecActive()) then RG.Print("Pick a 2nd spec on the 2nd Spec tab first (/wp spec)."); return end
  if RG.HealInvalidate then RG.HealInvalidate() end
  local set = RG.HealSet()
  -- remember what you wear now (only if it isn't the 2nd set already)
  if not RG.db.wearingHeal then
    local saved = {}
    for slot = 1, 18 do saved[slot] = GetInventoryItemLink("player", slot) or false end
    RG.db.retGear = saved
  end
  local jobs, inBank = {}, 0
  for _, group in ipairs(GROUP_ORDER) do
    local list, slots = set[group], SLOT_FOR[group]
    if list and slots then
      -- slots already holding one of the set's pieces stay as they are
      local used = {}
      for _, p in ipairs(list) do
        if p.where == "worn" then
          for _, s in ipairs(slots) do if not used[s] and idAt(s) == p.id then used[s] = true; break end end
        end
      end
      for _, p in ipairs(list) do
        if p.where == "bags" then
          local target
          for _, s in ipairs(slots) do if not used[s] then target = s; break end end
          if target then used[target] = true; jobs[#jobs + 1] = { p.link, target } end
        elseif p.where == "bank" then inBank = inBank + 1 end
      end
    end
  end
  RG.db.wearingHeal = true
  if #jobs == 0 then
    RG.Print(secondName() .. " set: nothing to change" .. (inBank > 0 and (" (" .. inBank .. " piece" .. (inBank > 1 and "s are" or " is") .. " in your bank)") or "") .. ".")
    return
  end
  RG.Print(GOLD .. "Equipping your " .. secondName() .. " set|r (" .. #jobs .. " piece" .. (#jobs > 1 and "s" or "") .. ")" .. (inBank > 0 and (GREY .. ". " .. inBank .. " more in your bank.|r") or "."))
  equipQueue(jobs, function() notify(GREEN .. secondName() .. " set on|r") end)
end

function RG.EquipRetSet()
  if inCombat() then RG.Print("You can't change gear in combat."); return end
  local saved = RG.db.retGear
  RG.db.wearingHeal = nil
  if not saved then RG.Print("No saved " .. mainName() .. " gear yet: Waypath+ saves it when it puts your " .. secondName() .. " set on."); return end
  local jobs = {}
  -- weapons first so a two-hander/one-hander swap lands cleanly
  for _, slot in ipairs({ 16, 17, 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 18 }) do
    local link = saved[slot]
    if link then
      local id = tonumber(link:match("item:(%d+)"))
      if id and idAt(slot) ~= id then jobs[#jobs + 1] = { link, slot } end
    end
  end
  if #jobs == 0 then RG.Print(mainName() .. " gear: nothing to change."); return end
  RG.Print(GOLD .. "Equipping your " .. mainName() .. " gear|r (" .. #jobs .. " piece" .. (#jobs > 1 and "s" or "") .. ").")
  equipQueue(jobs, function() notify(GREEN .. mainName() .. " gear on|r") end)
end

function RG.SwapGear()
  if RG.db.wearingHeal then RG.EquipRetSet() else RG.EquipHealSet() end
end

if StaticPopupDialogs then
  StaticPopupDialogs.WAYPATH_SPEC_SWAP = {
    text = "%s", button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function(_, data) if data == "second" then RG.EquipHealSet() else RG.EquipRetSet() end end,
    timeout = 0, whileDead = false, hideOnEscape = true, preferredIndex = 3,
  }
end
local function checkRole()
  if not RG.db or (RG.IsAlt and RG.IsAlt()) then return end
  local role = RG.CurrentRole()
  if not role then return end
  local last = RG.db.lastRole
  if last ~= role and inCombat() then RG.pendingRoleSwap = true; return end
  RG.db.lastRole = role
  if not last or last == role or not RG.Opt("specSwap") then return end
  if (UnitLevel("player") or 1) < 10 then return end
  local text
  if role == "second" and not RG.db.wearingHeal then text = "You switched to " .. secondName() .. ".\nEquip your " .. secondName() .. " set?"
  elseif role == "main" and RG.db.wearingHeal then text = "You switched back to " .. mainName() .. ".\nPut your " .. mainName() .. " gear back on?"
  else return end
  if StaticPopup_Show then
    local dlg = StaticPopup_Show("WAYPATH_SPEC_SWAP", text)
    if dlg then dlg.data = role end
  end
end

-- ===========================================================================
-- Events
-- ===========================================================================
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "QUEST_TURNED_IN", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if not RG.db then return end
  if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
    wipe(cache); queueArrows()
  elseif event == "QUEST_TURNED_IN" then
    if run then C_Timer.After(1, runNext) end
  elseif event == "PLAYER_LOGIN" then
    C_Timer.After(5, function()
      local r = RG.CurrentRole()
      -- saved roles from before 2nd specs were "heal" and "ret"
      if RG.db.lastRole == "heal" then RG.db.lastRole = "second" elseif RG.db.lastRole == "ret" then RG.db.lastRole = "main" end
      if r then RG.db.lastRole = RG.db.lastRole or r end
    end)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if RG.pendingRoleSwap then RG.pendingRoleSwap = nil; C_Timer.After(1, checkRole) end
  else
    RG.Debounce("roleCheck", 1, checkRole)
  end
end)

-- ===========================================================================
-- Slash commands
-- ===========================================================================
local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
  cmd = cmd and cmd:lower(); rest = rest and rest:lower() or ""
  if cmd == "errors" or cmd == "error" or cmd == "debug" or cmd == "bug" then
    if rest == "clear" then WaypathDB.errors = {}; RG.Print("Error log cleared.") else RG.ShowErrors() end
    return
  elseif cmd == "gear" and (rest == "heal" or rest == "holy" or rest == "2" or rest == "second" or rest == "spec") then RG.EquipHealSet(); return
  elseif cmd == "gear" and (rest == "ret" or rest == "1" or rest == "main") then RG.EquipRetSet(); return
  elseif cmd == "turnin" or cmd == "turnins" then RG.TurnInRun(); return
  elseif cmd == "greys" or cmd == "grey" then RG.AbandonGreyQuests(); return
  end
  return base(msg)
end
