local _, RG = ...
-- The on-screen tracker's scrolling and quest-item buttons (Tracker.lua lays out the rows; this file draws around them):
--   * the quest list scrolls (mouse wheel) once it is taller than a cap; a thin bar and a "N more quests" strip show there is
--     more, and a grip in the bottom corner sets the cap (double-click it for the automatic height)
--   * a quest with a usable item (a horn to blow, a vial to fill) gets a button beside it: click to use it
-- Quest-item buttons are secure buttons, which the game won't let an add-on move or hide during a fight. So while one is on
-- the tracker, the tracker holds still in combat (nothing is laid out again, it can't be dragged or scrolled) and catches
-- up the moment the fight ends.
local GOLDC = { 0.788, 0.635, 0.153 }
local function tr() return _G.WaypathTracker end
local function fighting() return InCombatLockdown and InCombatLockdown() end
-- (a quest-item button makes the whole tracker protected for the game, shown or not: once one exists, it holds still in a fight)
local hasButtons = false
local function frozen() local t = tr(); return fighting() and t and (hasButtons or (t.itemsShown or 0) > 0) and true or false end
RG.TrackerFrozen = frozen

-- ---------------------------------------------------------------------------------------------------------------------
-- height, scrolling
-- ---------------------------------------------------------------------------------------------------------------------
-- how tall the quest list may get before it scrolls: yours (the grip), else 60% of the screen
local function cap()
  local sc = (RG.db and RG.db.trackerScale) or 1
  local screen = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768
  local auto = math.floor(screen * 0.6 / sc)
  local h = (RG.db and RG.db.trackerMaxH) or auto
  return math.max(90, math.min(h, math.floor(screen / sc) - 120))
end
RG.TrackerCap = cap

local chrome
function RG.TrackerGrip() return chrome and chrome.grip end
local function makeChrome()
  local t = tr()
  if chrome or not (t and t.scroll) then return chrome end
  chrome = {}
  local lvl = t.scroll:GetFrameLevel() + 20
  -- the thin bar on the right, beside the rows
  chrome.bar = CreateFrame("Frame", nil, t); chrome.bar:SetFrameLevel(lvl); chrome.bar:SetWidth(3)
  chrome.track = chrome.bar:CreateTexture(nil, "BACKGROUND"); chrome.track:SetAllPoints(); chrome.track:SetColorTexture(1, 1, 1, 0.06)
  chrome.thumb = chrome.bar:CreateTexture(nil, "ARTWORK"); chrome.thumb:SetWidth(3); chrome.thumb:SetColorTexture(GOLDC[1], GOLDC[2], GOLDC[3], 0.75)
  -- "N more quests" over the bottom of the list
  chrome.more = CreateFrame("Frame", nil, t); chrome.more:SetFrameLevel(lvl); chrome.more:SetHeight(16)
  chrome.moreBg = chrome.more:CreateTexture(nil, "BACKGROUND"); chrome.moreBg:SetAllPoints(); chrome.moreBg:SetColorTexture(0.063, 0.11, 0.153, 0.94)
  chrome.moreText = chrome.more:CreateFontString(nil, "OVERLAY"); chrome.moreText:SetFont("Fonts\\ARIALN.TTF", 11, ""); chrome.moreText:SetPoint("CENTER", 0, 0)
  chrome.moreText:SetTextColor(GOLDC[1], GOLDC[2], GOLDC[3])
  chrome.more:Hide(); chrome.bar:Hide()
  -- the grip
  local g = CreateFrame("Button", nil, t); g:SetSize(16, 16); g:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -2, 2); g:SetFrameLevel(lvl + 2)
  g.tex = g:CreateTexture(nil, "OVERLAY"); g.tex:SetAllPoints(); g.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"); g.tex:SetVertexColor(1, 1, 1, 0.45)
  g:SetScript("OnEnter", function(self)
    self.tex:SetVertexColor(GOLDC[1], GOLDC[2], GOLDC[3], 1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("Tracker size", GOLDC[1], GOLDC[2], GOLDC[3])
    GameTooltip:AddLine("Drag up or down: how tall the list gets before it scrolls.", 1, 1, 1, true)
    GameTooltip:AddLine("Drag sideways: how wide it is.", 1, 1, 1, true)
    GameTooltip:AddLine("Double-click: back to the automatic size.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function(self) if not self.drag then self.tex:SetVertexColor(1, 1, 1, 0.45) end; GameTooltip:Hide() end)
  g:SetScript("OnMouseDown", function(self)
    if frozen() then return end
    local now = GetTime and GetTime() or 0
    if self.last and now - self.last < 0.35 then   -- double-click: automatic again
      self.last = nil; RG.db.trackerMaxH = nil; RG.db.trackerWidth = nil; RG.TrackerFit(); if RG.RefreshTracker then RG.RefreshTracker() end; return
    end
    self.last = now
    self.drag = true; self.startX, self.startY = GetCursorPosition(); self.startH = cap(); self.startW = RG.db.trackerWidth or 300
    self:SetScript("OnUpdate", function(s)
      local t2 = tr(); if not t2 or frozen() then return end
      -- width: the grip sits on the side the tracker can grow towards (the left one when it is pinned by its right edge)
      local dx = (GetCursorPosition() - s.startX) / (t2:GetEffectiveScale() or 1)
      local w = math.max(240, math.min(560, math.floor(s.startW + (s.leftSide and -dx or dx))))
      if math.abs(w - (RG.db.trackerWidth or 300)) >= 4 then RG.db.trackerWidth = w; if RG.RefreshTracker then RG.RefreshTracker() end end
      local dy = (s.startY - select(2, GetCursorPosition())) / (t2:GetEffectiveScale() or 1)
      local sc = RG.db.trackerScale or 1
      local maxH = math.floor(((UIParent:GetHeight() or 768) / sc)) - 120
      RG.db.trackerMaxH = math.max(90, math.min(maxH, math.floor(s.startH + dy)))
      RG.TrackerFit()
    end)
  end)
  g:SetScript("OnMouseUp", function(self) self.drag = nil; self:SetScript("OnUpdate", nil); self.tex:SetVertexColor(1, 1, 1, 0.45) end)
  chrome.grip = g
  return chrome
end

-- the bar, the "more" strip and the grip, for the scroll position now
function RG.TrackerChrome(show)
  local t = tr()
  if not (t and t.scroll) then return end
  local c = makeChrome(); if not c then return end
  if show == false then c.bar:Hide(); c.more:Hide(); c.grip:Hide(); return end
  do
    local pos = RG.db and RG.db.trackerPos
    local left = (pos and tostring(pos[1]) or "TOPRIGHT"):find("RIGHT") and true or false
    if c.grip.leftSide ~= left then
      c.grip.leftSide = left
      c.grip:ClearAllPoints()
      c.grip:SetPoint(left and "BOTTOMLEFT" or "BOTTOMRIGHT", t, left and "BOTTOMLEFT" or "BOTTOMRIGHT", left and 2 or -2, 2)
      if left then c.grip.tex:SetTexCoord(1, 0, 0, 1) else c.grip.tex:SetTexCoord(0, 1, 0, 1) end
    end
  end
  c.grip:Show()
  local content, view, v = t.contentH or 0, t.viewH or 0, t.scrollV or 0
  if content > view + 1 and view > 20 then
    local thumbH = math.max(14, view * view / content)
    local room = math.max(0, content - view)
    local y = room > 0 and (v / room) * (view - thumbH) or 0
    c.bar:ClearAllPoints(); c.bar:SetPoint("TOPLEFT", t.scroll, "TOPRIGHT", 5, 0); c.bar:SetHeight(view)
    c.thumb:ClearAllPoints(); c.thumb:SetPoint("TOPLEFT", c.bar, "TOPLEFT", 0, -y); c.thumb:SetHeight(thumbH)
    c.bar:Show()
    if content - v - view > 6 then
      local below = 0
      for _, b in pairs(t.rowList or {}) do
        if b._q and b:IsShown() and (b._top or 0) >= v + view - 2 then below = below + 1 end
      end
      c.more:ClearAllPoints(); c.more:SetPoint("BOTTOMLEFT", t.scroll, "BOTTOMLEFT", 0, 0); c.more:SetPoint("BOTTOMRIGHT", t.scroll, "BOTTOMRIGHT", 0, 0)
      c.moreText:SetText(below > 0 and ("+" .. below .. " more quest" .. (below == 1 and "" or "s") .. "  ·  scroll") or "more below  ·  scroll")
      c.more:Show()
    else c.more:Hide() end
  else
    c.bar:Hide(); c.more:Hide()
  end
end

function RG.TrackerScrollTo(v)
  local t = tr(); if not (t and t.scroll) then return end
  local room = math.max(0, (t.contentH or 0) - (t.viewH or 0))
  v = math.max(0, math.min(room, v or 0))
  t.scrollV = v
  t.scroll:SetVerticalScroll(v)
  RG.TrackerChrome()
end

function RG.TrackerScrollBy(delta)
  local t = tr(); if not t or frozen() then return end
  RG.TrackerScrollTo((t.scrollV or 0) - (delta or 0) * 44)
end

-- the visible height for the content there is (the frame, the scroll area, the scroll position)
function RG.TrackerFit()
  local t = tr(); if not (t and t.scroll) then return end
  if frozen() then return end
  local content = t.contentH or 10
  local view = math.min(content, cap())
  t.viewH = view
  t.scroll:SetHeight(math.max(10, view))
  t:SetHeight(60 + view + 14)
  RG.TrackerScrollTo(t.scrollV or 0)
end

-- the end of a layout: y is how tall the rows came to
function RG.TrackerFinish(y)
  local t = tr(); if not (t and t.scroll) then return end
  t.contentH = math.max(10, y or 10)
  t.body:SetHeight(t.contentH)
  RG.TrackerFit()
  RG.TrackerChrome(true)
end

-- ---------------------------------------------------------------------------------------------------------------------
-- quest items
-- ---------------------------------------------------------------------------------------------------------------------
-- the usable item of a quest in your log (the same list the game's own tracker uses), or nil
function RG.QuestItemFor(q)
  if not (q and q.idx and GetQuestLogSpecialItemInfo) then return nil end
  local ok, link, tex, charges, showWhenComplete = pcall(GetQuestLogSpecialItemInfo, q.idx)
  if not ok or not link then return nil end
  if q.complete and not showWhenComplete then return nil end
  local id = tonumber(tostring(link):match("item:(%d+)"))
  if not id then return nil end
  local name = GetItemInfo and GetItemInfo(link) or nil
  return { link = link, tex = tex or (GetItemIcon and GetItemIcon(id)), id = id, charges = charges, name = name }
end

local pool, used = {}, 0
local function refreshOne(b)
  local id = b.id; if not id then return end
  local start, dur = 0, 0
  if GetItemCooldown then start, dur = GetItemCooldown(id); start, dur = start or 0, dur or 0 end
  local cooling = dur > 1.5 and start > 0
  if b.cd then
    if cooling then pcall(b.cd.SetCooldown, b.cd, start, dur) elseif b.cd.Clear then pcall(b.cd.Clear, b.cd) end
  end
  local n = b.charges and b.charges > 0 and b.charges or (GetItemCount and GetItemCount(id)) or 0
  b.count:SetText(n > 1 and tostring(n) or "")
  local usable = true
  if IsUsableItem then local ok, u = pcall(IsUsableItem, id); if ok and u == false then usable = false end end
  b.icon:SetDesaturated(not usable); b.icon:SetVertexColor(usable and 1 or 0.55, usable and 1 or 0.55, usable and 1 or 0.55)
  if usable and not cooling then b.bg:SetColorTexture(1, 0.82, 0, 0.95) else b.bg:SetColorTexture(0.42, 0.36, 0.13, 0.9) end
end
local function makeButton()
  local t = tr()
  local ok, b = pcall(CreateFrame, "Button", nil, t.body, "SecureActionButtonTemplate")
  if not ok or not b then return nil end
  hasButtons = true
  b:SetSize(26, 26)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "item")
  b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(0.42, 0.36, 0.13, 0.9)
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.count = b:CreateFontString(nil, "OVERLAY"); b.count:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE"); b.count:SetPoint("BOTTOMRIGHT", -2, 2)
  local okc, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
  if okc and cd then cd:SetAllPoints(b.icon); b.cd = cd end
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if self.link then GameTooltip:SetHyperlink(self.link) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: use it" .. (self.questName and (" for " .. self.questName) or ""), GOLDC[1], GOLDC[2], GOLDC[3])
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  pool[#pool + 1] = b
  return b
end

function RG.TrackerItemBegin()
  if fighting() then return end
  used = 0
end
-- put a quest's item button on its row; false when it can't be done now (in a fight, or no room in the pool)
function RG.TrackerItemPlace(row, itm, q)
  if not (row and itm) then return false end
  if fighting() then RG.trackerDeferred = true; return false end
  used = used + 1
  local b = pool[used] or makeButton()
  if not b then used = used - 1; return false end
  b.id, b.link, b.charges, b.questName = itm.id, itm.link, itm.charges, q and q.title
  local what = itm.name or itm.link
  if b._what ~= what then b:SetAttribute("item", what); b._what = what end
  b:ClearAllPoints(); b:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 3)
  b:SetFrameLevel((row:GetFrameLevel() or 1) + 4)
  if itm.tex then b.icon:SetTexture(itm.tex) end
  b:Show()
  refreshOne(b)
  return true
end
function RG.TrackerItemEnd()
  local t = tr(); if not t or fighting() then return end
  for i = used + 1, #pool do pool[i]:Hide() end
  t.itemsShown = used
end
-- cooldowns, counts and the "can't use it here" look follow the game
do
  local f = CreateFrame("Frame")
  local queued
  for _, e in ipairs({ "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED" }) do pcall(f.RegisterEvent, f, e) end
  f:SetScript("OnEvent", function()
    if queued or not (C_Timer and C_Timer.After) then return end
    queued = true
    C_Timer.After(0.2, function()
      queued = nil
      for i = 1, used do local b = pool[i]; if b and b:IsShown() then pcall(refreshOne, b) end end
    end)
  end)
end

-- ---------------------------------------------------------------------------------------------------------------------
-- objective rows: one reading of an objective, the quest being worked on, text kept live in a fight, quest timers
-- ---------------------------------------------------------------------------------------------------------------------
-- the name without its count, the count, whether it's done, and its colour (red, orange, yellow, green)
function RG.TrackerObjective(o)
  local text = tostring(o.text or "")
  local have, need = o.numFulfilled, o.numRequired
  local a, b = text:match("(%d+)/(%d+)%s*$")
  if not a then a, b = text:match("^(%d+)/(%d+)") end
  have, need = have or tonumber(a), (need and need > 0 and need) or tonumber(b)
  local name = (text:gsub(":?%s*%d+/%d+%s*$", ""):gsub("^%d+/%d+%s+", ""))
  local f = (need and need > 0) and math.min(1, (have or 0) / need) or (o.finished and 1 or 0)
  local done = o.finished or f >= 1
  local col = done and "|cff59d973" or (f >= 0.67 and "|cffe6e05a") or (f >= 0.34 and "|cffffb347") or "|cffff7a5c"
  return name, have, need, done, col
end

-- is this the quest being worked on: the one the arrow follows, one whose objective is the mob you target, one you're at
-- (its nearest spot is close), else simply the nearest one
local nearestId, nearestT
function RG.TrackerQuestActive(q)
  if not q or q.complete or q.failed then return false end
  if q.wp and RG.ArrowTarget and RG.ArrowTarget(q.wp) then return true end
  local tn = UnitExists and UnitExists("target") and UnitName and UnitName("target")
  if type(tn) == "string" and tn ~= "" and not (UnitIsDead and UnitIsDead("target")) then
    for _, o in ipairs(q.objs or {}) do
      if not o.finished and o.text and o.text:find(tn, 1, true) then return true end
    end
  end
  if q.dist and q.dist < 250 then return true end
  local now = GetTime and GetTime() or 0
  if nearestT ~= now then
    nearestT, nearestId = now, nil
    for _, x in ipairs(RG.MyQuests and RG.MyQuests() or {}) do
      if not x.complete and not x.failed and x.dist and (not nearestId or x.dist < nearestId.dist) then nearestId = x end
    end
  end
  return nearestId ~= nil and nearestId.id == q.id
end

-- counts change in a fight but the layout holds still: only the words of the objective rows are rewritten
function RG.TrackerLiveUpdate()
  local t = tr(); if not (t and t.rowList and C_QuestLog and C_QuestLog.GetQuestObjectives) then return end
  local cache = {}
  for _, b in pairs(t.rowList) do
    local lv = b._live
    if lv and b:IsShown() and b.text and b.right then
      local objs = cache[lv[1]]; if not objs then objs = C_QuestLog.GetQuestObjectives(lv[1]) or {}; cache[lv[1]] = objs end
      local o = objs[lv[2]]
      if o and o.text then
        local name, have, need, done, col = RG.TrackerObjective(o)
        b.text:SetText((done and "|cff8a8a8a" or "|cffe6e6e6") .. name .. "|r")
        b.right:SetText((need and need > 0) and (col .. (have or 0) .. "/" .. need .. "|r") or "")
      end
    end
  end
end

-- a timed quest's time left, "4:32" (red under a minute), or "" when it isn't timed
function RG.TrackerTimerText(id)
  if not (id and C_QuestLog and C_QuestLog.GetTimeAllowed) then return "" end
  local ok, total, elapsed = pcall(C_QuestLog.GetTimeAllowed, id)
  if not ok or not total or total <= 0 then return "" end
  local left = math.max(0, total - (elapsed or 0))
  return string.format("%s%d:%02d|r  ", left < 60 and "|cffff5a4d" or "|cffffd100", math.floor(left / 60), math.floor(left % 60))
end
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(1, RG.PerfWrap("trackerTimers", function()
    local t = tr(); if not (t and t.rowList and t:IsShown()) then return end
    for _, b in pairs(t.rowList) do
      if b._timer and b:IsShown() and b.right then b.right:SetText(RG.TrackerTimerText(b._timer) .. (b._rbase or "")) end
    end
  end))
end

-- the target changes which quest is being worked on
do
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "PLAYER_TARGET_CHANGED")
  f:SetScript("OnEvent", function() if RG.Opt and RG.Opt("trackerFocus") and RG.QueueTracker then RG.QueueTracker() end end)
end

-- a quest's link into the chat box that's open (force: open one)
function RG.LinkQuestInChat(q, force)
  if not q then return false end
  local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
  if not eb and not force then return false end
  local link = (GetQuestLink and GetQuestLink(q.id)) or (C_QuestLog and C_QuestLog.GetQuestLink and C_QuestLog.GetQuestLink(q.id))
  if not link then return false end
  if not eb and ChatFrame_OpenChat then pcall(ChatFrame_OpenChat, ""); eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() end
  return (ChatEdit_InsertLink and ChatEdit_InsertLink(link)) and true or false
end
