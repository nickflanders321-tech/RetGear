-- RetGear on-screen tracker: your current route step, next tasks, dungeon
-- quests to collect, next gear upgrade and reminders, in a small panel.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLDC = { 1, 0.82, 0 }
local W = 300
local tr, lines, collapsed

function RG.StepIsDone(entry, i)
  local key = entry.zone .. "|" .. entry.from
  RG.db.stepsDone = RG.db.stepsDone or {}
  if RG.db.stepsDone[key .. "#" .. i] then return true, "ticked" end
  local steps = RG.STEPS[key]
  if steps and RG.StepAuto then
    local ok, why = RG.StepAuto(entry, steps[i])
    if ok then return true, why end
  end
  return false
end

-- The route entry you're on: the questing zone for your level that still has
-- open steps, falling back to any zone that fits.
local function currentEntry()
  local lvl = UnitLevel("player")
  local best
  for _, r in ipairs(RG.ROUTE) do
    if r.kind == "zone" and lvl >= r.from and lvl <= r.to then
      local steps = RG.STEPS[r.zone .. "|" .. r.from] or {}
      local open = 0
      for i = 1, #steps do if not RG.StepIsDone(r, i) then open = open + 1 end end
      if open > 0 and (not best or r.from < best.r.from) then best = { r = r, open = open } end
      if not best then best = { r = r, open = 0 } end
    end
  end
  return best and best.r
end

-- True once every quest for a dungeon is turned in (nothing left to collect or do there).
function RG.DungeonQuestsDone(dq)
  if not (dq and dq.quests and #dq.quests > 0 and RG.QuestState) then return false end
  for _, q in ipairs(dq.quests) do
    if RG.QuestState((q[1]:gsub("%s*%(.-%)$", ""))) ~= "done" then return false end
  end
  return true
end
local function nextDungeon()
  local lvl = UnitLevel("player")
  for _, r in ipairs(RG.ROUTE) do
    local dq = r.kind == "dungeon" and RG.DUNGEON_QUESTS[r.zone]
    if dq and lvl >= dq.prep and lvl <= r.to and not RG.DungeonQuestsDone(dq) then return r, dq end
  end
end

local function nextUpgrade()
  local lvl, best = UnitLevel("player")
  for _, g in ipairs(RG.GUIDE) do
    if g.id and g.lvl <= lvl + 2 and g.lvl >= lvl - 8 and not RG.OwnState(g.id) then
      local d = RG.GuideDelta(g)
      if d and d > 0.5 and (not best or d > best.d) then best = { g = g, d = d } end
    end
  end
  return best
end

-- ---------------------------------------------------------------------------
-- Frame
-- ---------------------------------------------------------------------------
local function line(i)
  if lines[i] then return lines[i] end
  local b = CreateFrame("Button", nil, tr.body)
  b:SetWidth(W - 24)
  b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFont("Fonts\\ARIALN.TTF", 13, ""); b.text:SetPoint("TOPLEFT", 16, 0); b.text:SetWidth(W - 44); b.text:SetJustifyH("LEFT"); b.text:SetWordWrap(true)
  b.box = b:CreateTexture(nil, "ARTWORK"); b.box:SetSize(10, 10); b.box:SetPoint("TOPLEFT", 1, -2)
  b.check = b:CreateTexture(nil, "OVERLAY"); b.check:SetSize(16, 16); b.check:SetPoint("CENTER", b.box, "CENTER", 1, 1); b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, btn)
    if btn == "RightButton" and self.onRightClick then self.onRightClick(); return end
    if self.onClick then self.onClick() end
  end)
  b:SetScript("OnEnter", function(self) if self.tip then GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(self.tip, 1, 1, 1, 1, true); GameTooltip:Show() end end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  lines[i] = b
  return b
end

local function build()
  tr = CreateFrame("Frame", "RetGearTracker", UIParent, "BackdropTemplate")
  tr:SetWidth(W); tr:SetClampedToScreen(true); tr:SetMovable(true); tr:EnableMouse(true); tr:SetFrameStrata("MEDIUM")
  RG.Backdrop(tr, { 0.02, 0.02, 0.02, 0.6 }, { 0.6, 0.55, 0.45, 0.6 })
  local pos = RetGearDB.trackerPos
  if pos then tr:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else tr:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -260) end
  tr:RegisterForDrag("LeftButton")
  tr:SetScript("OnDragStart", tr.StartMoving)
  tr:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, rp, x, y = self:GetPoint(); RetGearDB.trackerPos = { p, rp, x, y } end)

  local crest = tr:CreateTexture(nil, "OVERLAY"); crest:SetSize(18, 18); crest:SetPoint("TOPLEFT", 10, -9); crest:SetTexture("Interface\\Icons\\Spell_Holy_AuraOfLight"); crest:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  tr.title = tr:CreateFontString(nil, "OVERLAY", "GameFontNormal"); tr.title:SetPoint("LEFT", crest, "RIGHT", 6, 0); tr.title:SetText("RetGear")
  tr.lvl = tr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); tr.lvl:SetPoint("LEFT", tr.title, "RIGHT", 8, 0); tr.lvl:SetTextColor(0.75, 0.75, 0.75)

  local function hdrBtn(label, x, fn, tip)
    local b = CreateFrame("Button", nil, tr); b:SetSize(20, 20); b:SetPoint("TOPRIGHT", x, -8)
    b.t = b:CreateFontString(nil, "OVERLAY"); b.t:SetFont("Fonts\\ARIALN.TTF", 15, ""); b.t:SetPoint("CENTER"); b.t:SetText(label); b.t:SetTextColor(0.6, 0.6, 0.6)
    b:SetScript("OnClick", fn)
    b:SetScript("OnEnter", function(self) self.t:SetTextColor(GOLDC[1], GOLDC[2], GOLDC[3]); GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(tip); GameTooltip:Show() end)
    b:SetScript("OnLeave", function(self) self.t:SetTextColor(0.6, 0.6, 0.6); GameTooltip:Hide() end)
    return b
  end
  tr.min = hdrBtn("-", -8, function() RetGearDB.trackerCollapsed = not RetGearDB.trackerCollapsed; RG.RefreshTracker() end, "Collapse or expand")
  local g = hdrBtn("", -30, function() if RG.ToggleUI then RG.ToggleUI() end end, "Open the full guide")
  local gi = g:CreateTexture(nil, "OVERLAY"); gi:SetSize(14, 14); gi:SetPoint("CENTER"); gi:SetTexture("Interface\\Icons\\INV_Misc_Book_09"); gi:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  -- XP bar under the header
  local xpBg = tr:CreateTexture(nil, "ARTWORK"); xpBg:SetHeight(4); xpBg:SetPoint("TOPLEFT", 6, -32); xpBg:SetPoint("TOPRIGHT", -6, -32)
  xpBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar"); xpBg:SetVertexColor(0.12, 0.12, 0.12, 0.9)
  tr.xp = tr:CreateTexture(nil, "OVERLAY"); tr.xp:SetHeight(4); tr.xp:SetPoint("LEFT", xpBg, "LEFT")
  tr.xp:SetTexture("Interface\\TargetingFrame\\UI-StatusBar"); tr.xp:SetVertexColor(0.58, 0.0, 0.55, 1)

  tr.body = CreateFrame("Frame", nil, tr); tr.body:SetPoint("TOPLEFT", 12, -42); tr.body:SetWidth(W - 24); tr.body:SetHeight(10)
  lines = {}
end

local function section(n, y, label)
  local b = line(n)
  b.onClick, b.tip = nil, nil
  b.box:Hide(); b.check:Hide()
  b.text:ClearAllPoints(); b.text:SetPoint("TOPLEFT", 0, 0); b.text:SetFont("Fonts\\FRIZQT__.TTF", math.floor(12 * ((RetGearDB.textSize or 1.2) / 1.2) + 0.5), "")
  b.text:SetShadowColor(0, 0, 0, 1); b.text:SetShadowOffset(1, -1)
  b.text:SetText(GOLD .. label .. "|r")
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -y); b:SetHeight(16); b:Show()
  return y + 19
end
local function item(n, y, text, opts)
  opts = opts or {}
  local b = line(n)
  b.onClick, b.tip, b.onRightClick = opts.onClick, opts.tip, opts.onRightClick
  b.text:ClearAllPoints(); b.text:SetPoint("TOPLEFT", opts.box ~= nil and 16 or 8, 0); b.text:SetFont("Fonts\\FRIZQT__.TTF", math.floor(11.5 * ((RetGearDB.textSize or 1.2) / 1.2) + 0.5), "")
  b.text:SetShadowColor(0, 0, 0, 1); b.text:SetShadowOffset(1, -1)
  b.text:SetText(text)
  if opts.box ~= nil then
    b.box:Show(); b.box:SetColorTexture(GOLDC[1], GOLDC[2], GOLDC[3], opts.box and 0.9 or 0.35)
    b.check:SetShown(opts.box and true or false)
  else b.box:Hide(); b.check:Hide() end
  local h = math.max(16, (b.text:GetStringHeight() or 14) + 4)
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -y); b:SetHeight(h); b:Show()
  return y + h + 2
end

function RG.RefreshTracker()
  if not RetGearDB or not RG.db then return end
  if not RG.Opt("tracker") then if tr then tr:Hide() end return end
  if not tr then build() end
  tr:Show()
  for _, b in ipairs(lines) do b:Hide() end
  local lvl = UnitLevel("player")
  local xp, max = UnitXP("player"), UnitXPMax("player")
  local rate, eta = RG.XPRate and RG.XPRate()
  tr.lvl:SetText("Level " .. lvl .. (max and max > 0 and lvl < 60 and string.format("  ·  %d%%", xp / max * 100) or "")
    .. (rate and string.format("  ·  %.1fk/hr  ·  %s", rate / 1000, RG.FormatETA(eta) or "") or ""))
  tr.xp:SetWidth(math.max(1, (W - 12) * ((max and max > 0) and xp / max or 1)))
  if RetGearDB.trackerCollapsed then tr.body:Hide(); tr:SetHeight(40); tr.min.t:SetText("+"); return end
  tr.body:Show(); tr.min.t:SetText("-")

  local n, y = 0, 0
  -- bank alt: just the shopping list for your main
  if RG.IsAlt and RG.IsAlt() then
    tr.lvl:SetText("Bank alt for " .. (RG.MainName() or "your main"))
    local list = RG.ShoppingList and RG.ShoppingList() or {}
    n = n + 1; y = section(n, y, #list > 0 and "Buy and mail" or "Nothing to send right now")
    for i = 1, math.min(6, #list) do
      local e = list[i]
      n = n + 1
      y = item(n, y, (RG.ItemInfo(e.id) or ("item " .. e.id)) .. "  x" .. e.need .. (e.toBuy > 0 and (GREY .. "  (buy " .. e.toBuy .. ")|r") or (GREEN .. "  (in your bags)|r")) .. "\n" .. GREY .. e.quest .. "|r", { onClick = function() if RG.ShowTab then RG.ShowTab("mail") end end })
    end
    tr.body:SetHeight(math.max(10, y)); tr:SetHeight(42 + y + 8)
    return
  end
  -- current route step
  local r = currentEntry()
  if r then
    local key = r.zone .. "|" .. r.from
    local steps = RG.STEPS[key] or {}
    local doneN = 0
    for i = 1, #steps do if RG.StepIsDone(r, i) then doneN = doneN + 1 end end
    n = n + 1; y = section(n, y, r.zone .. "  ·  " .. doneN .. "/" .. #steps)
    local shown = 0
    for i, text in ipairs(steps) do
      local done, why = RG.StepIsDone(r, i)
      if not done and shown < 4 then
        shown = shown + 1
        n = n + 1
        local sk = key .. "#" .. i
        local wp = RG.StepWaypoint and RG.StepWaypoint(r, i)
        if wp and shown == 1 and RG.AutoPin then RG.AutoPin(key .. "#" .. i, wp) end
        y = item(n, y, (wp and RG.PIN or "") .. text, { box = false, tip = "Click to tick this off." .. (wp and ("\nRight-click: show " .. wp[4] .. " on the map.") or ""), onClick = function() RG.db.stepsDone[sk] = true; RG.RefreshTracker(); if RG.RefreshUI then RG.RefreshUI() end end,
          onRightClick = wp and function() RG.PinWaypoint(wp) end or nil })
      end
    end
    if shown == 0 then n = n + 1; y = item(n, y, GREEN .. "All done here. Check the route for your next zone.|r") end
    y = y + 6
  end
  -- dungeon prep
  local dr, dq = nextDungeon()
  if dr then
    local have, total = 0, #dq.quests
    for _, q in ipairs(dq.quests) do local s = RG.QuestState and RG.QuestState((q[1]:gsub("%s*%(.-%)$", ""))); if s then have = have + 1 end end
    n = n + 1; y = section(n, y, dr.zone .. "  ·  " .. (lvl >= dq.go and "go now" or ("go at " .. dq.go)))
    for _, q in ipairs(dq.quests) do
      local s = RG.QuestState and RG.QuestState((q[1]:gsub("%s*%(.-%)$", "")))
      if s ~= "done" then
        n = n + 1
        local tag = s == "ready" and (GREEN .. "  turn in|r") or (s == "log" and (GREEN .. "  in log|r") or (GREY .. "  " .. q[3] .. "|r"))
        y = item(n, y, "|cffffd100" .. q[1] .. "|r" .. tag, { tip = q[2] .. ", " .. q[3] })
      end
    end
    y = y + 6
  end
  -- nearest quest objective and turn-in (click to pin)
  if RG.NearestSpot then
    local obj, fin = RG.NearestSpot(false), RG.NearestSpot(true)
    local new = RG.NearbyNewQuests and RG.NearbyNewQuests(2) or {}
    if obj or fin or #new > 0 then
      n = n + 1; y = section(n, y, "Quests near you")
      if fin then
        n = n + 1
        y = item(n, y, RG.PIN .. GREEN .. "Turn in:|r " .. fin.quest .. GREY .. "  ·  " .. (fin.label ~= "" and fin.label or "") .. string.format("  ·  %d yd|r", fin.dist or 0),
          { tip = "Click to show the turn-in on the map.", onClick = function() RG.PinWaypoint(fin.wp) end })
      end
      if obj then
        n = n + 1
        local prog = obj.have and obj.need and string.format(" (%d/%d)", obj.have, obj.need) or ""
        y = item(n, y, RG.PIN .. "|cffffffff" .. obj.label .. prog .. "|r" .. GREY .. ((obj.src and obj.src ~= obj.label) and ("  ·  " .. obj.src) or "") .. string.format("  ·  %d yd|r", obj.dist or 0),
          { tip = obj.quest .. "\nClick to show it on the map.  /rg next does the same.", onClick = function() RG.PinWaypoint(obj.wp) end })
      end
      for _, q in ipairs(new) do
        n = n + 1
        y = item(n, y, RG.PIN .. "|cffffd100!|r " .. "|cffffffff" .. q.name .. "|r" .. GREY .. string.format("  ·  level %d  ·  %s  ·  %d yd|r", q.lvl or 0, q.giver or "", q.dist or 0),
          { tip = "New quest you can pick up. Click to show " .. (q.giver or "the quest giver") .. " on the map.", onClick = function() RG.PinWaypoint(q.wp) end })
      end
      y = y + 4
    end
  end
  -- next upgrade
  local up = nextUpgrade()
  if up then
    local name = RG.ItemInfo(up.g.id) or "item"
    n = n + 1; y = section(n, y, "Next upgrade")
    n = n + 1; y = item(n, y, name .. "  " .. GREEN .. string.format("+%.0f", up.d) .. "|r\n" .. GREY .. up.g.src .. ", " .. up.g.zone .. "|r", { tip = "Open the Gear guide with /rg for details." })
    y = y + 6
  end
  -- reminders
  local rem = RG.Reminders and RG.Reminders() or {}
  if #rem > 0 then
    -- most important first (lower number = more urgent; class buffs and seals are 3), top 5 only
    for i, rr in ipairs(rem) do rr.i = i end
    table.sort(rem, function(a, b) local pa, pb = a[3] or 3, b[3] or 3; if pa ~= pb then return pa < pb end return a.i < b.i end)
    n = n + 1; y = section(n, y, "Reminders")
    for i = 1, math.min(5, #rem) do local rr = rem[i]; n = n + 1; y = item(n, y, rr[1], { onClick = rr[2] }) end
    if #rem > 5 then n = n + 1; y = item(n, y, GREY .. "+" .. (#rem - 5) .. " more (turn reminders off in /rg settings)|r", { onClick = function() if RG.ShowTab then RG.ShowTab("settings") end end }) end
  end
  tr.body:SetHeight(math.max(10, y))
  tr:SetHeight(42 + y + 8)
end

-- Refresh on the things that change the tracker, at most a few times a second.
local pending
local function queue() if pending then return end; pending = true; C_Timer.After(0.4, function() pending = nil; RG.RefreshTracker() end) end
RG.QueueTracker = queue
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "TAXIMAP_OPENED", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "TRAINER_SHOW" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event == "TRAINER_SHOW" and RG.db then RG.db.trainerDue = nil end
  if event == "PLAYER_LOGIN" then C_Timer.After(2, RG.RefreshTracker) else queue() end
end)
