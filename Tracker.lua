-- Waypath+ on-screen tracker: your current route step, next tasks, dungeon
-- quests to collect, next gear upgrade and reminders, in a small panel.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLDC = { 0.31, 0.82, 0.77 }
local W = 300
local tr, lines, collapsed
-- marks the line the arrow is pointing at
local ARROW = "|TInterface\\Minimap\\MinimapArrow:12:12|t"
local function isTarget(wp) return RG.ArrowTarget and RG.ArrowTarget(wp) end

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

-- Ticking a task by hand can be undone: the last few ticks are remembered.
local UNDO_SHOW = 600   -- the tracker offers "Undo" for 10 minutes after a tick
function RG.TickStep(sk, text)
  RG.db.stepsDone = RG.db.stepsDone or {}
  RG.db.stepsDone[sk] = true
  RG.db.tickHistory = RG.db.tickHistory or {}
  local h = RG.db.tickHistory
  for i = #h, 1, -1 do if h[i].sk == sk then table.remove(h, i) end end
  h[#h + 1] = { sk = sk, text = text, t = time() }
  while #h > 10 do table.remove(h, 1) end
  if RG.Log then RG.Log("stepskip", sk) end
  RG.RefreshTracker(); if RG.RefreshUI then RG.RefreshUI() end
end
-- Puts the most recent hand-ticked task back on the list. Returns its text.
function RG.UndoTick()
  local h = RG.db and RG.db.tickHistory
  while h and #h > 0 do
    local e = table.remove(h)
    if RG.db.stepsDone and RG.db.stepsDone[e.sk] then
      RG.db.stepsDone[e.sk] = nil
      RG.RefreshTracker(); if RG.RefreshUI then RG.RefreshUI() end
      return e.text
    end
  end
end
local function lastTick(prefix)
  local h = RG.db.tickHistory
  local e = h and h[#h]
  if e and RG.db.stepsDone and RG.db.stepsDone[e.sk] and time() - (e.t or 0) <= UNDO_SHOW
    and e.sk:sub(1, #prefix) == prefix then return e end
end
local function plain(text) return ((text or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- The route entry you're on: the questing zone for your level that still has
-- open steps, falling back to any zone that fits.
local function currentEntry()
  local lvl = UnitLevel("player")
  if RG.SmartEntry then
    local ok, pick = pcall(RG.SmartEntry)
    if ok and pick then return pick end
  end
  local function open(r)
    local steps = RG.STEPS[r.zone .. "|" .. r.from] or {}
    for i = 1, #steps do if not RG.StepIsDone(r, i) then return true end end
    return false
  end
  -- 1. the first questing zone (in route order) for your level that still has work
  -- 2. else the next one coming up within 3 levels
  -- 3. else the zone for your level, finished (the tracker says so)
  local done
  for _, r in ipairs(RG.ROUTE) do
    if r.kind == "zone" and lvl >= r.from and lvl <= r.to then
      if open(r) then return r end
      done = done or r
    end
  end
  for _, r in ipairs(RG.ROUTE) do
    if r.kind == "zone" and r.from > lvl and r.from <= lvl + 3 and open(r) then return r end
  end
  return done
end

-- the map point of the first step still to do in a route entry (nil when it has none)
local function destWp(r)
  if not (r and RG.STEPS and RG.StepWaypoint) then return nil end
  local steps = RG.STEPS[r.zone .. "|" .. r.from] or {}
  for i = 1, #steps do if not RG.StepIsDone(r, i) then return RG.StepWaypoint(r, i) end end
  return RG.StepWaypoint(r, 1)
end
function RG.CurrentRouteEntry() local ok, r = pcall(currentEntry); return ok and r or nil end

-- A generated route step split into its quests, each with the one thing to do
-- next. Returns the list (hand-ins first, then pick-ups, then quests in your
-- log, then ones that open later), how many are done, how many count, and the
-- step's place and level range. nil for hand-written steps.
--   { id, name, act = "turnin"|"pickup"|"doing"|"later", npc, wp, prog }
local ACT_ORDER = { turnin = 1, pickup = 2, doing = 3, later = 4 }
function RG.StepQuestLines(entry, i, myQuests)
  local key = entry and (entry.zone .. "|" .. entry.from)
  local ids = key and RG.STEP_QUESTS and RG.STEP_QUESTS[key] and RG.STEP_QUESTS[key][i]
  if not (ids and RG.QDATA) then return nil end
  local isDone = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or function() return false end
  local byId = {}
  for _, q in ipairs(myQuests or (RG.MyQuests and RG.MyQuests()) or {}) do if q.id then byId[q.id] = q end end
  local lvl = UnitLevel("player") or 1
  local out, doneN, total = {}, 0, 0
  for _, id in ipairs(ids) do
    local d = RG.QDATA[id]
    if d and d.n and not d.rep and (not RG.QuestForMe or RG.QuestForMe(d)) then
      local done = isDone(id)
      if not done and d.x then for _, x in ipairs(d.x) do if isDone(x) then done = true break end end end
      total = total + 1
      if done then doneN = doneN + 1
      else
        local q = byId[id]
        local l = { id = id, name = d.n, level = d.l }
        if q and q.complete then
          l.act, l.npc = "turnin", d.e and d.e[4]
          l.wp = d.e and { d.e[1], d.e[2], d.e[3], d.e[4] ~= "" and d.e[4] or d.n }
        elseif q then
          l.act, l.prog, l.wp = "doing", q.prog, q.wp
        else
          -- what's still in the way: an earlier quest, or your level
          local need
          if d.pg then for _, p in ipairs(d.pg) do if not isDone(p) then need = p break end end end
          if not need and d.ps then
            local any = false
            for _, p in ipairs(d.ps) do if isDone(p) then any = true break end end
            if not any then need = d.ps[1] end
          end
          if need then
            local pd = RG.QDATA[need]
            l.act, l.npc = "later", "after " .. ((pd and pd.n) or "an earlier quest")
          elseif (d.r or 1) > lvl then
            l.act, l.npc = "later", "at level " .. d.r
          else
            l.act, l.npc = "pickup", d.s and d.s[4]
            l.noGiver = not d.s
            l.wp = d.s and { d.s[1], d.s[2], d.s[3], d.s[4] ~= "" and d.s[4] or d.n }
          end
        end
        out[#out + 1] = l
      end
    end
  end
  for k, l in ipairs(out) do l._k = k end
  table.sort(out, function(a, b)
    if a.act ~= b.act then return ACT_ORDER[a.act] < ACT_ORDER[b.act] end
    return a._k < b._k
  end)
  local text = RG.STEPS[key] and RG.STEPS[key][i] or ""
  local place, levels = text:gsub("^At ", ""):match("^(.-) %((levels? [%d%-]+)%)")
  if place then place = place:gsub("^the ", "The ", 1) end
  return out, doneN, total, place, levels
end

-- True once every quest for a dungeon is turned in (nothing left to collect or do there).
-- Quests from the data whose earlier steps you haven't done yet don't count.
function RG.QuestPrereqsMet(id)
  local d = id and RG.QDATA and RG.QDATA[id]
  if not d then return true end
  local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
  if not done then return true end
  if d.pg then for _, p in ipairs(d.pg) do if not done(p) then return false end end end
  if d.ps then local any = false; for _, p in ipairs(d.ps) do if done(p) then any = true break end end; if not any then return false end end
  if d.x then for _, p in ipairs(d.x) do if done(p) then return false end end end
  return (d.r or 1) <= (UnitLevel("player") or 1) + 2
end
function RG.DungeonQuestsDone(dq)
  if not (dq and dq.quests and #dq.quests > 0 and RG.QuestState) then return false end
  local anyDone = false
  for _, q in ipairs(dq.quests) do
    if RG.QuestState((q[1]:gsub("%s*%(.-%)$", ""))) == "done" then anyDone = true
    elseif not q.id or RG.QuestPrereqsMet(q.id) then return false end
  end
  return anyDone   -- quests you can't take yet don't count as finished
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
-- Tracker text: Inter like the window, with the game's narrow font as the fallback (and as an option).
local ARIAL = "Fonts\\ARIALN.TTF"
local function tfont(fs, size)
  if RG.Opt("trackerInter") and not RG.trInterBad and RG.FONTS then
    if fs:SetFont(RG.FONTS.medium, size, "") then return end
  end
  fs:SetFont(ARIAL, size, "")
end
-- a font that lays text out at no width is broken here: stop using it
local function tcheck(fs, text)
  if text and text ~= "" and not RG.trInterBad and RG.Opt("trackerInter") and (fs:GetStringWidth() or 0) < 1 then
    RG.trInterBad = true
    local _, size = fs:GetFont()
    fs:SetFont(ARIAL, size or 12, ""); fs:SetText(""); fs:SetText(text)
  end
end

-- A small right-click menu of our own (not a Blizzard dropdown, so nothing can be blocked or tainted).
local menuFrame, menuCatcher
function RG.ShowMenu(entries, title)
  if not entries or #entries == 0 then return end
  if not menuFrame then
    menuFrame = CreateFrame("Frame", "WaypathMenu", UIParent, "BackdropTemplate")
    menuFrame:SetFrameStrata("FULLSCREEN_DIALOG"); menuFrame:SetClampedToScreen(true)
    if RG.Round then RG.Round(menuFrame, 0.07, 0.07, 0.08, 0.97, 8) end
    menuFrame.btns = {}
    menuCatcher = CreateFrame("Button", nil, UIParent)
    menuCatcher:SetAllPoints(UIParent); menuCatcher:SetFrameStrata("FULLSCREEN"); menuCatcher:RegisterForClicks("AnyUp")
    menuCatcher:SetScript("OnClick", function() menuFrame:Hide() end)
    menuFrame:SetScript("OnHide", function() menuCatcher:Hide() end)
    menuFrame:Hide(); menuCatcher:Hide()
    tinsert(UISpecialFrames, "WaypathMenu")
  end
  for _, b in ipairs(menuFrame.btns) do b:Hide() end
  local y, wMax = 8, 150
  local function row(i, text, fn, head)
    local b = menuFrame.btns[i]
    if not b then
      b = CreateFrame("Button", nil, menuFrame)
      b:SetHeight(20)
      b.t = b:CreateFontString(nil, "OVERLAY"); b.t:SetPoint("LEFT", 10, 0); b.t:SetJustifyH("LEFT")
      b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.1)
      b:RegisterForClicks("LeftButtonUp")
      b:SetScript("OnClick", function(self) menuFrame:Hide(); if self.fn then pcall(self.fn) end end)
      menuFrame.btns[i] = b
    end
    if RG.Font then RG.Font(b.t, head and "regular" or "medium", head and 11 or 12) else b.t:SetFont("Fonts\\ARIALN.TTF", 12, "") end
    b.t:SetText(text); b.fn = not head and fn or nil
    b.hl:SetShown(not head)
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, -y); b:SetPoint("TOPRIGHT", -4, -y)
    b:Show()
    wMax = math.max(wMax, (b.t:GetStringWidth() or 100) + 28)
    y = y + 20
  end
  local i = 0
  if title then i = i + 1; row(i, GREY .. title .. "|r", nil, true) end
  for _, e in ipairs(entries) do i = i + 1; row(i, e[1], e[2]) end
  menuFrame:SetSize(wMax, y + 8)
  local cx, cy = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  if type(s) ~= "number" or s <= 0 then s = 1 end
  if type(cx) ~= "number" or type(cy) ~= "number" then cx, cy = 600, 600 end
  menuFrame:ClearAllPoints(); menuFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / s - 6, cy / s + 6)
  menuCatcher:Show(); menuFrame:Show()
end

local function line(i)
  if lines[i] then return lines[i] end
  local b = CreateFrame("Button", nil, tr.body)
  b:SetWidth(W - 24)
  b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFont("Fonts\\ARIALN.TTF", 13, ""); b.text:SetPoint("TOPLEFT", 16, 0); b.text:SetWidth(W - 44); b.text:SetJustifyH("LEFT"); b.text:SetWordWrap(true)
  b.right = b:CreateFontString(nil, "OVERLAY"); b.right:SetFont("Fonts\\ARIALN.TTF", 10, ""); b.right:SetPoint("TOPRIGHT", 0, -1); b.right:SetJustifyH("RIGHT")
  b.right:SetShadowColor(0, 0, 0, 0.9); b.right:SetShadowOffset(1, -1)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetPoint("TOPLEFT", -4, 1); b.hl:SetPoint("BOTTOMRIGHT", 4, -1); b.hl:SetColorTexture(1, 1, 1, 0.06)
  b.box = b:CreateTexture(nil, "ARTWORK"); b.box:SetSize(12, 12); b.box:SetPoint("TOPLEFT", 0, -1)
  b.check = b:CreateTexture(nil, "OVERLAY"); b.check:SetSize(12, 12); b.check:SetPoint("CENTER", b.box, "CENTER", 0, 0); b.check:SetTexture("Interface\\AddOns\\Waypath\\Media\\Check"); b.check:SetVertexColor(0.05, 0.07, 0.07, 1)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, btn)
    if btn == "RightButton" and self.menu and IsShiftKeyDown and IsShiftKeyDown() then RG.ShowMenu(self.menu()); return end   -- Shift + right-click: more options
    if btn == "RightButton" and self.onRightClick then self.onRightClick(); return end
    if btn == "LeftButton" and self.wpClick then
      -- a place: the line itself is the button. Your own click (tick, open) still runs; a plain click also sends the arrow.
      if self.onClick then self.onClick() end
      if not (IsShiftKeyDown and IsShiftKeyDown()) then RG.ArrowTo(self.wpClick) end
      return
    end
    if self.onDoubleClick then
      -- wait a moment so a double-click doesn't also do the single-click action
      local now = GetTime()
      if self.pending and now - self.pending < 0.3 then self.pending = nil; self.onDoubleClick(); return end
      self.pending = now
      local single = self.onClick
      C_Timer.After(0.3, function() if self.pending == now then self.pending = nil; if single then single() end end end)
      return
    end
    if self.onClick then self.onClick() end
  end)
  b:SetScript("OnEnter", function(self) if self.tip then GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(self.tip, 1, 1, 1, 1, true); GameTooltip:Show() end end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  lines[i] = b
  return b
end

local function build()
  tr = CreateFrame("Frame", "WaypathTracker", UIParent, "BackdropTemplate")
  tr:SetWidth(W); tr:SetClampedToScreen(true); tr:SetMovable(true); tr:EnableMouse(true); tr:SetFrameStrata("MEDIUM")
  RG.Round(tr, 0.06, 0.06, 0.065, RG.db.trackerAlpha or 0.5, 12)   -- dense enough to read over snow and sand
  local pos = RG.db.trackerPos
  if pos then tr:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else tr:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -260) end
  tr:RegisterForDrag("LeftButton")
  tr:SetScript("OnDragStart", function(self) if not RG.Opt("trackerLocked") then self:StartMoving() end end)
  -- Ctrl + mouse wheel: size  ·  Shift + mouse wheel: width
  tr:EnableMouseWheel(true)
  tr:SetScript("OnMouseWheel", function(self, delta)
    if IsControlKeyDown and IsControlKeyDown() then
      RG.db.trackerScale = math.max(0.6, math.min(1.6, (RG.db.trackerScale or 1) + delta * 0.05))
    elseif IsAltKeyDown and IsAltKeyDown() then
      RG.db.trackerAlpha = math.max(0.15, math.min(0.95, (RG.db.trackerAlpha or 0.5) + delta * 0.05))
    elseif IsShiftKeyDown and IsShiftKeyDown() then
      RG.db.trackerWidth = math.max(240, math.min(460, (RG.db.trackerWidth or 300) + delta * 20))
    else return end
    RG.RefreshTracker()
  end)
  tr:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, rp, x, y = self:GetPoint(); RG.db.trackerPos = { p, rp, x, y } end)

  local crest = tr:CreateTexture(nil, "OVERLAY"); crest:SetSize(18, 18); crest:SetPoint("TOPLEFT", 10, -9); crest:SetTexture(RG.LOGO); crest:SetTexCoord(0, 1, 0, 1)
  tr.title = RG.NewText(tr, "GameFontNormal"); tr.title:SetPoint("LEFT", crest, "RIGHT", 6, 0); tr.title:SetText("Waypath+"); tfont(tr.title, 16); tr.title:SetTextColor(0.93, 0.95, 0.97); tr.title:SetShadowColor(0, 0, 0, 0)
  -- hover the header for the tracker's controls
  local hint = CreateFrame("Frame", nil, tr); hint:SetPoint("TOPLEFT", 6, -4); hint:SetSize(120, 26)
  hint:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("Waypath+ tracker", GOLDC[1], GOLDC[2], GOLDC[3])
    GameTooltip:AddLine(RG.Opt("trackerLocked") and "Locked (unlock in Settings)" or "Drag to move", 1, 1, 1)
    GameTooltip:AddLine("Ctrl + mouse wheel: bigger or smaller", 1, 1, 1)
    GameTooltip:AddLine("Shift + mouse wheel: wider or narrower", 1, 1, 1)
    GameTooltip:AddLine("Alt + mouse wheel: more or less see-through", 1, 1, 1)
    GameTooltip:AddLine("Click a gold heading to fold it", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  hint:SetScript("OnLeave", function() GameTooltip:Hide() end)
  tr.lvl = RG.NewText(tr, "GameFontHighlightSmall"); tr.lvl:SetPoint("LEFT", tr.title, "RIGHT", 8, 0); tr.lvl:SetTextColor(0.75, 0.75, 0.75)

  local function hdrBtn(label, x, fn, tip)
    local b = CreateFrame("Button", nil, tr); b:SetSize(20, 20); b:SetPoint("TOPRIGHT", x, -8)
    b.t = b:CreateFontString(nil, "OVERLAY"); b.t:SetFont("Fonts\\ARIALN.TTF", 15, ""); b.t:SetPoint("CENTER"); b.t:SetText(label); b.t:SetTextColor(0.6, 0.6, 0.6)
    b:SetScript("OnClick", fn)
    b:SetScript("OnEnter", function(self) self.t:SetTextColor(GOLDC[1], GOLDC[2], GOLDC[3]); GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(tip); GameTooltip:Show() end)
    b:SetScript("OnLeave", function(self) self.t:SetTextColor(0.6, 0.6, 0.6); GameTooltip:Hide() end)
    return b
  end
  tr.min = hdrBtn("-", -8, function() RG.db.trackerCollapsed = not RG.db.trackerCollapsed; RG.RefreshTracker() end, "Collapse or expand")
  local g = hdrBtn("", -30, function() if RG.ToggleUI then RG.ToggleUI() end end, "Open the full guide")
  local gi = g:CreateTexture(nil, "OVERLAY"); gi:SetSize(14, 14); gi:SetPoint("CENTER"); gi:SetTexture("Interface\\Icons\\INV_Misc_Book_09"); gi:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  -- arrow on/off switch
  local ab = CreateFrame("Button", nil, tr); ab:SetSize(20, 20); ab:SetPoint("TOPRIGHT", -52, -8)
  ab.icon = ab:CreateTexture(nil, "OVERLAY"); ab.icon:SetSize(16, 16); ab.icon:SetPoint("CENTER"); ab.icon:SetTexture("Interface\\Minimap\\MinimapArrow")
  ab:SetScript("OnClick", function(self)
    RG.db.arrow = not RG.Opt("arrow")
    if RG.RefreshArrow then RG.RefreshArrow() end
    RG.Notify("Arrow " .. (RG.Opt("arrow") and "on" or "off"))
    if PlaySound and SOUNDKIT and RG.Opt("sounds") then pcall(PlaySound, SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115) end
    RG.RefreshTracker()
    if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
  end)
  ab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Arrow: " .. (RG.Opt("arrow") and "on" or "off"))
    GameTooltip:AddLine("Click to turn the waypoint arrow " .. (RG.Opt("arrow") and "off" or "on") .. ".", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  ab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  tr.arrowBtn = ab

  -- thin XP bar along the bottom, with the pace and time to level above it
  local xpBg = tr:CreateTexture(nil, "ARTWORK"); xpBg:SetHeight(4); xpBg:SetPoint("BOTTOMLEFT", 12, 8); xpBg:SetPoint("BOTTOMRIGHT", -12, 8)
  xpBg:SetTexture("Interface\\Buttons\\WHITE8X8"); xpBg:SetVertexColor(1, 1, 1, 0.08)
  tr.xp = tr:CreateTexture(nil, "OVERLAY"); tr.xp:SetHeight(4); tr.xp:SetPoint("BOTTOMLEFT", 12, 8)
  tr.xp:SetTexture("Interface\\Buttons\\WHITE8X8"); tr.xp:SetVertexColor(GOLDC[1], GOLDC[2], GOLDC[3], 1)
  tr.foot = RG.NewText(tr, "GameFontHighlightSmall"); tr.foot:SetPoint("BOTTOMLEFT", 12, 16); tr.foot:SetTextColor(0.62, 0.62, 0.62)
  tr.pct = RG.NewText(tr, "GameFontHighlightSmall"); tr.pct:SetPoint("BOTTOMRIGHT", -12, 16); tr.pct:SetTextColor(0.62, 0.62, 0.62)

  tr.body = CreateFrame("Frame", nil, tr); tr.body:SetPoint("TOPLEFT", 12, -42); tr.body:SetWidth(W - 24); tr.body:SetHeight(10)
  lines = {}
end

-- Sections fold with a click on their header (remembered between sessions).
-- Professions and Reminders start folded so the tracker stays calm; a click opens them and remembers
local DEFAULT_FOLD = { profs = true, reminders = true }
local function folded(key)
  if not key then return nil end
  local v = RG.db.trackerFold and RG.db.trackerFold[key]
  if v == nil then return DEFAULT_FOLD[key] end
  return v
end
local function fontSize(base) return math.floor(base * ((RG.db.textSize or 1.2) / 1.2) + 0.5) end
-- The sections under Quests (new quests, route, class quests, dungeon, upgrade, professions, reminders) share one
-- "More" row until you open it, so the side bar stays short: the first thing it shows is what to do now.
local SECONDARY = { new = "New quests", route = "Route", pala = "Class quests", dungeon = "Dungeon", upgrade = "Upgrade", profs = "Professions", reminders = "Reminders" }
local hints, skipped, moreOpen = {}, 0, false
local function section(n, y, label, key, right)
  if key and SECONDARY[key] and not moreOpen then
    local name = SECONDARY[key]
    if key == "dungeon" or key == "pala" then name = label:gsub("^Class quests: ", "Class quests"):gsub("%s*$", "") end
    local plain = right and right:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or ""
    hints[#hints + 1] = { name = name, note = plain, urgent = right ~= nil and right:find(GREEN, 1, true) ~= nil }
    skipped = skipped + 1
    return y, true
  end
  local b = line(n)
  b.onClick, b.onRightClick, b.tip, b.onDoubleClick, b.menu, b.wpClick = nil, nil, nil, nil, nil, nil
  b.box:Hide(); b.check:Hide()
  local isFolded = folded(key)
  if key then
    b.onClick = function()
      RG.db.trackerFold = RG.db.trackerFold or {}
      RG.db.trackerFold[key] = not folded(key)
      RG.RefreshTracker()
    end
    b.tip = isFolded and "Click to show this section." or "Click to fold this section away."
  end
  b.text:ClearAllPoints(); b.text:SetPoint("TOPLEFT", 0, 0); tfont(b.text, fontSize(12))
  b.text:SetWidth(W - 24); b.text:SetWordWrap(false)
  b.text:SetShadowColor(0, 0, 0, 0.9); b.text:SetShadowOffset(1, -1)
  local lab = label:find("|", 1, true) and label or label:upper()
  b.text:SetText((key and ("|cff8a8a8a" .. (isFolded and "+ " or "- ") .. "|r") or "") .. "|cffb4b4b4" .. lab .. "|r")
  tfont(b.right, fontSize(11)); b.right:SetText(right or ""); b.right:SetShown(right ~= nil)
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -y); b:SetHeight(16); b:Show()
  return y + 24, isFolded
end
-- opts: onClick, onRightClick, tip, box (checkbox state), right (right-hand text), single (one line, cut with ...)
local function item(n, y, text, opts)
  opts = opts or {}
  local b = line(n)
  b.onClick, b.tip, b.onRightClick, b.menu = opts.onClick, opts.tip, opts.onRightClick, opts.menu
  b.onDoubleClick = nil
  b.wpClick = (opts.wp and not opts.noArrow) and opts.wp or nil
  local indent = opts.indent or (opts.box ~= nil and 16 or 8)
  tfont(b.right, fontSize(11.5)); b.right:SetText(opts.right or ""); b.right:SetShown(opts.right ~= nil)
  local rw = opts.right and ((b.right:GetStringWidth() or 0) + 8) or 0
  b.text:ClearAllPoints(); b.text:SetPoint("TOPLEFT", indent, 0); tfont(b.text, fontSize(13))
  local avail = W - 24 - indent - rw
  b.text:SetWidth(avail)
  b.text:SetShadowColor(0, 0, 0, 0.9); b.text:SetShadowOffset(1, -1)
  local multi = not opts.single and tostring(text):find("\n", 1, true)   -- text with its own line breaks lays itself out
  -- a line that needs more than one row wraps to two at most, and its height comes from its width (the font's own
  -- height reading can lag a frame behind and let the next row print over it)
  b.text:SetWordWrap(false); if b.text.SetMaxLines then b.text:SetMaxLines(1) end
  if not opts.single and not multi then b.text:SetWidth(0) end
  b.text:SetText(text); tcheck(b.text, text)
  local rows = 1
  if not opts.single and not multi then
    local natural = b.text:GetStringWidth() or 0
    rows = math.max(1, math.min(2, math.ceil(natural / math.max(1, avail) - 0.03)))
    b.text:SetWidth(avail); b.text:SetWordWrap(true)
    if b.text.SetMaxLines then b.text:SetMaxLines(2) end
    b.text:SetText(text)
  elseif multi then
    b.text:SetWidth(avail); b.text:SetWordWrap(true)
    if b.text.SetMaxLines then b.text:SetMaxLines(0) end
    b.text:SetText(text)
  end
  if opts.box ~= nil then
    b.box:Show(); b.box:SetTexture("Interface\\AddOns\\Waypath\\Media\\" .. (opts.box and "Disc" or "Ring"))
    if opts.box then b.box:SetVertexColor(GOLDC[1], GOLDC[2], GOLDC[3], 1) else b.box:SetVertexColor(0.42, 0.42, 0.42, 1) end
    b.check:SetShown(opts.box and true or false)
  else b.box:Hide(); b.check:Hide() end
  local rowH = fontSize(13) + 3
  local h = opts.single and math.max(16, rowH) or (multi and math.max(16, (b.text:GetStringHeight() or 14) + 2) or math.max(16, rows * rowH))
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -y); b:SetHeight(h); b:Show()
  return y + h + 4
end

-- Right-click on a tracker line: point the arrow at it (turning the arrow on if it was off).
function RG.Follow(wp)
  if not wp then return end
  if not RG.Opt("arrow") then RG.db.arrow = true; if RG.RefreshArrow then RG.RefreshArrow() end end
  RG.PinWaypoint(wp)
  if RG.RefreshTracker then RG.RefreshTracker() end
end

-- Tooltip for a quest in your log.
local function questTip(q)
  local t = RG.LevelTag(q.level) .. "|cffffffff" .. q.title .. "|r"
  if q.zone then t = t .. "\n" .. GREY .. q.zone .. "|r" end
  if q.complete then t = t .. "\n" .. GREEN .. "Complete: ready to turn in|r"
  else
    for _, o in ipairs(q.objs or {}) do
      if o.text and o.text ~= "" then t = t .. "\n" .. (o.finished and (GREY .. "  - " .. o.text .. "|r") or ("|cffffffff  - " .. o.text .. "|r")) end
    end
  end
  if q.dist then t = t .. "\n" .. GREY .. (q.complete and "Turn in: " or "Nearest: ") .. (q.label ~= "" and q.label or "") .. ", " .. RG.FormatYards(q.dist) .. "|r" end
  if q.complete and q.wp then
    t = t .. "\n\n" .. GOLD .. "Click / right-click:|r arrow to the hand-in\n" .. GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Shift-click:|r open in your quest log\n" .. GOLD .. "Shift + right-click:|r more options"
  else
    t = t .. "\n\n" .. GOLD .. "Click:|r open in your quest log" .. (q.wp and ("\n" .. GOLD .. "Right-click:|r the arrow follows this quest\n" .. GOLD .. "Click:|r arrow on / off") or "")
  end
  return t
end

function RG.RefreshTracker()
  if not RG.db or not RG.db then return end
  if not RG.Opt("tracker") then if tr then tr:Hide() end return end
  if not tr then build() end
  tr:Show()
  -- size and width (Ctrl / Shift + mouse wheel)
  W = RG.db.trackerWidth or 300
  tr:SetWidth(W); tr.body:SetWidth(W - 24); tr:SetScale(RG.db.trackerScale or 1)
  tr:SetBackdropColor(0.06, 0.06, 0.065, RG.db.trackerAlpha or 0.5)
  for _, b in ipairs(lines) do b:Hide(); b:SetWidth(W - 24) end
  local lvl = UnitLevel("player")
  local xp, max = UnitXP("player"), UnitXPMax("player")
  local rate, eta
  if RG.XPRate then rate, eta = RG.XPRate() end
  local rested = GetXPExhaustion and GetXPExhaustion()
  if rested and RG.IsSecret and RG.IsSecret(rested) then rested = nil end
  tr.lvl:SetText("Level " .. lvl .. (rested and rested > 0 and "  ·  |cff4d85e6rested|r" or ""))
  -- the header names the zone you are working through
  do
    local ze = not (RG.IsAlt and RG.IsAlt()) and RG.CurrentRouteEntry and RG.CurrentRouteEntry()
    tr.title:SetText(ze and ze.zone or "Waypath+"); tr.title:SetWidth(0)
    if (tr.title:GetStringWidth() or 0) > W - 160 then tr.title:SetWidth(W - 160) end
    if tr.title.SetWordWrap then tr.title:SetWordWrap(false) end
  end
  tr.foot:SetText(rate and string.format("%.0f XP/h  ·  %s to level", rate, RG.FormatETA(eta) or "?") or "")
  tr.pct:SetText(max and max > 0 and lvl < 60 and string.format("%d%%", xp / max * 100) or "")
  tr.xp:SetWidth(math.max(1, (W - 24) * ((max and max > 0) and xp / max or 1)))
  if tr.arrowBtn then
    local on = RG.Opt("arrow")
    tr.arrowBtn.icon:SetDesaturated(not on)
    if on then tr.arrowBtn.icon:SetVertexColor(GOLDC[1], GOLDC[2], GOLDC[3]) else tr.arrowBtn.icon:SetVertexColor(0.45, 0.45, 0.45) end
  end
  if RG.db.trackerCollapsed then
    tr.body:Hide(); tr.min.t:SetText("+")
    -- compact: one calm line with the next thing to do
    local txt
    local okO, objc = pcall(RG.Objective or function() end)
    if okO and objc and objc.text then
      txt = plain(objc.text)
      if #txt > 110 then txt = txt:sub(1, 107):gsub("[%s%p]+$", "") .. "..." end
    end
    if not txt and not (RG.IsAlt and RG.IsAlt()) then
      local ok, r = pcall(currentEntry)
      local steps = ok and r and RG.STEPS[r.zone .. "|" .. r.from]
      if steps then
        for i = 1, #steps do
          if not RG.StepIsDone(r, i) then
            txt = plain(steps[i]):gsub("%s+", " ")
            if #txt > 110 then txt = txt:sub(1, 107):gsub("[%s%p]+$", "") .. "..." end
            break
          end
        end
      end
    end
    if not rawget(tr, "nextLine") then
      tr.nextLine = RG.NewText(tr, "GameFontHighlightSmall")
      tr.nextLine:SetPoint("TOPLEFT", 12, -38); tr.nextLine:SetJustifyH("LEFT"); tr.nextLine:SetTextColor(0.85, 0.85, 0.85)
    end
    tr.nextLine:SetWidth(W - 24)
    if txt then tr.nextLine:SetText(GOLD .. "Next:|r " .. txt); tr.nextLine:Show(); tr:SetHeight(66 + math.max(12, tr.nextLine:GetStringHeight() or 12))
    else tr.nextLine:Hide(); tr:SetHeight(58) end
    return
  end
  if rawget(tr, "nextLine") then tr.nextLine:Hide() end
  tr.body:Show(); tr.min.t:SetText("-")

  local n, y = 0, 0
  hints, skipped, moreOpen = {}, 0, RG.db.trackerMore == true
  -- bank alt: just the shopping list for your main
  if RG.IsAlt and RG.IsAlt() then
    tr.lvl:SetText("Bank alt for " .. (RG.MainName() or "your main")); tr.title:SetText("Waypath+")
    -- secret guide: walk a new alt to the Auction House
    local gl, gdone, gtotal = nil, 0, 0
    if RG.AltGuideLines then gl, gdone, gtotal = RG.AltGuideLines() end
    if gl then
      local isFolded
      n = n + 1; y, isFolded = section(n, y, "Bank alt setup", "altguide", GREY .. gdone .. "/" .. gtotal .. "|r")
      if not isFolded then
        for _, l in ipairs(gl) do n = n + 1; y = item(n, y, (isTarget(l[4]) and ARROW or "") .. l[1], { onClick = l[2], tip = l[3] .. (l[4] and ("\n" .. GOLD .. "Click:|r arrow on / off") or ""), wp = l[4] }) end
        n = n + 1; y = item(n, y, GREY .. "Hide this guide|r", { single = true, onClick = function() RG.AltGuideHide() end, tip = "/wp bankalt brings it back." })
      end
      y = y + 5
    end
    local list = RG.ShoppingList and RG.ShoppingList() or {}
    n = n + 1; y = section(n, y, #list > 0 and "Buy and mail" or "Nothing to send right now")
    for i = 1, math.min(6, #list) do
      local e = list[i]
      n = n + 1
      y = item(n, y, (RG.ItemInfo(e.id) or ("item " .. e.id)) .. "  x" .. e.need .. (e.toBuy > 0 and (GREY .. "  (buy " .. e.toBuy .. ")|r") or (GREEN .. "  (in your bags)|r")) .. "\n" .. GREY .. e.quest .. "|r", { onClick = function() if RG.ShowTab then RG.ShowTab("mail") end end })
    end
    tr.body:SetHeight(math.max(10, y)); tr:SetHeight(42 + y + 40)
    return
  end
  local compact = RG.Opt and RG.Opt("compactTracker")
  local MAXQ = compact and 6 or 10
  -- 0. fishing: shows while you hold a pole or caught something in the last 10 minutes
  local fl, fright = nil, nil
  if RG.FishTrackerLines then fl, fright = RG.FishTrackerLines() end
  if fl and #fl > 0 then
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "Fishing", "fishing", fright)
    if not isFolded then
      for i, l in ipairs(fl) do
        if not compact or i <= 2 then   -- compact: your skill and the one thing to know; the rest is on the Fishing page
          n = n + 1
          y = item(n, y, l[1], { single = true, right = l[2], onClick = l[3], tip = l[4] })
        end
      end
    end
    y = y + 5
    MAXQ = compact and 4 or 6 -- keep the tracker short while fishing
  end
  -- 0b. now: the one thing to do next (the same objective the arrow follows)
  do
    local okN, nl = pcall(RG.NowLines or function() end)
    if okN and nl and #nl > 0 then
      n = n + 1; y = section(n, y, "Now", nil, nl.right)
      for _, l in ipairs(nl) do n = n + 1; y = item(n, y, l.text, l.opts) end
      y = y + 5
    end
  end
  -- 1. your quests: level, name, progress, distance
  local quests = RG.MyQuests and RG.MyQuests() or {}
  local new = RG.NearbyNewQuests and RG.NearbyNewQuests(8) or {}
  if #quests > 0 then
    local ready = 0
    for _, q in ipairs(quests) do if q.complete then ready = ready + 1 end end
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "Quests", "quests", GREY .. #quests .. "/" .. ((C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()) or 20) .. (ready > 0 and ("  ·  " .. GREEN .. ready .. " ready|r") or "") .. "|r")
    if not isFolded then
      -- turn-in run: the arrow chains through every ready quest, nearest first
      local readyWp = RG.ReadyQuests and #RG.ReadyQuests() or 0
      local running = RG.TurnInRunActive and RG.TurnInRunActive()
      if readyWp >= 2 or running then
        n = n + 1
        y = item(n, y, (running and (GREEN .. "Turn-in run on|r" .. GREY .. ": " .. readyWp .. " left (click to stop)|r") or (GREEN .. "Turn-in run|r" .. GREY .. ": " .. readyWp .. " quests ready, nearest first|r")),
          { single = true, indent = 2, tip = "Click: the arrow takes you to each ready quest in turn, nearest first, and moves on as you hand them in.",
            onClick = function() if RG.TurnInRun then RG.TurnInRun() end end })
      end
      -- grouped by zone: the zone you're in first, then the nearest zones
      local here = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
      local groups, byZone = {}, {}
      for _, q in ipairs(quests) do
        local z = q.zone or "Other"
        local g = byZone[z]
        if not g then g = { zone = z, list = {}, here = (z == here) }; byZone[z] = g; groups[#groups + 1] = g end
        g.list[#g.list + 1] = q
        if q.dist and (not g.dist or q.dist < g.dist) then g.dist = q.dist end
        if q.complete then g.ready = (g.ready or 0) + 1 end
        g.minLevel = math.min(g.minLevel or 99, q.level or 99)
      end
      table.sort(groups, function(a2, b2)
        if a2.here ~= b2.here then return a2.here end
        if (a2.dist ~= nil) ~= (b2.dist ~= nil) then return a2.dist ~= nil end
        if a2.dist and b2.dist and a2.dist ~= b2.dist then return a2.dist < b2.dist end
        return a2.minLevel < b2.minLevel
      end)
      local shownQ, hidden = 0, 0
      for _, g in ipairs(groups) do
        if shownQ >= MAXQ or (compact and not g.here and not g.ready and (g.dist or 1e9) > 2500) then hidden = hidden + #g.list   -- compact: far zones fold into "+N more"
        else
          local zf = RG.db.trackerFold and RG.db.trackerFold["zone:" .. g.zone]
          n = n + 1
          y = item(n, y, (zf and "+ " or "") .. "|cffc9a227" .. g.zone .. "|r" .. (g.here and (GREY .. "  (you're here)|r") or ""),
            { single = true, indent = 2, right = GREY .. #g.list .. (g.ready and ("  ·  " .. GREEN .. g.ready .. " ready|r") or "") .. "|r",
              tip = "Click to fold or show this zone's quests.",
              onClick = function()
                RG.db.trackerFold = RG.db.trackerFold or {}
                RG.db.trackerFold["zone:" .. g.zone] = not RG.db.trackerFold["zone:" .. g.zone] or nil
                RG.RefreshTracker()
              end })
          if not zf then
            for _, q in ipairs(g.list) do
              if shownQ >= MAXQ then hidden = hidden + 1
              else
                shownQ = shownQ + 1
                local status
                if q.complete then status = GREEN .. "turn in|r"
                elseif q.failed then status = "|cffff3333failed|r"
                else status = q.prog and ("|cffffffff" .. q.prog .. "|r") or "" end
                local where = q.dist and (GREY .. "  " .. RG.FormatYards(q.dist) .. "|r") or ""
                n = n + 1
                y = item(n, y, (isTarget(q.wp) and ARROW or "") .. RG.LevelTag(q.level) .. (q.complete and GREEN or "|cffffd100") .. q.title .. "|r" .. (q.group and (GREY .. " (group)|r") or ""),
                  { single = true, indent = 12, right = status .. where, tip = questTip(q), wp = q.wp,
                    -- a quest ready to hand in: click points the arrow at the hand-in, right-click opens it
                    onClick = function()
                      if q.complete and q.wp and not (IsShiftKeyDown and IsShiftKeyDown()) then RG.Follow(q.wp) else RG.OpenQuest(q.title, q.id) end
                    end,
                    menu = function()
                      local e = {}
                      if q.wp then e[#e + 1] = { q.complete and "Arrow to the hand-in" or "Arrow to this quest", function() RG.Follow(q.wp) end } end
                      e[#e + 1] = { "Open in your quest log", function() RG.OpenQuest(q.title, q.id) end }
                      if not q.complete then e[#e + 1] = { "Skip it for now (10 min)", function() if RG.SkipQuest then RG.SkipQuest(q.title) end; RG.RefreshTracker() end } end
                      return e, RG.LevelTag(q.level) .. q.title
                    end,
                    -- right-click: the arrow follows this quest
                    onRightClick = function()
                      if q.wp then RG.Follow(q.wp)
                      else RG.Print("No location known for " .. q.title .. " yet. Click it to open the quest.") end
                    end })
              end
            end
          end
        end
      end
      if hidden > 0 then
        n = n + 1; y = item(n, y, GREY .. "+" .. hidden .. " more in your quest log|r", { single = true, indent = 12, onClick = function() if ToggleQuestLog then ToggleQuestLog() end end })
      end
    end
    y = y + 5
  end
  -- 2. new quests to pick up nearby (not the ones the route already lists)
  do
    local r0 = currentEntry()
    if r0 and #new > 0 then
      local steps0 = RG.STEPS[r0.zone .. "|" .. r0.from] or {}
      for i = 1, #steps0 do
        if not RG.StepIsDone(r0, i) then
          local ql = RG.StepQuestLines(r0, i, quests)
          if ql then
            local skip = {}
            for _, l in ipairs(ql) do skip[l.id] = true end
            for k = #new, 1, -1 do if new[k].id and skip[new[k].id] then table.remove(new, k) end end
          end
          break
        end
      end
    end
    for k = #new, 3, -1 do new[k] = nil end
  end
  if #new > 0 then
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "New quests nearby", "new")
    if not isFolded then
      for _, q in ipairs(new) do
        n = n + 1
        y = item(n, y, (isTarget(q.wp) and ARROW or "") .. RG.LevelTag(q.lvl) .. "|cffffffff" .. q.name .. "|r", { single = true, right = GREY .. RG.FormatYards(q.dist) .. "|r", wp = q.wp,
          tip = RG.LevelTag(q.lvl) .. "|cffffffff" .. q.name .. "|r\n" .. GREY .. "From " .. (q.giver or "a quest giver") .. "|r\n\n" .. GOLD .. "Click:|r show " .. (q.giver or "the quest giver") .. " on the map\n" .. GOLD .. "Click:|r arrow on / off",
          onClick = function() RG.PinWaypoint(q.wp) end, onRightClick = function() RG.Follow(q.wp) end,
          menu = function()
            return { { "Arrow to " .. (q.giver or "the quest giver"), function() RG.Follow(q.wp) end },
                     { "Don't suggest this quest", function() if RG.IgnoreQuest then RG.IgnoreQuest(q.id) end; RG.RefreshTracker() end } }, RG.LevelTag(q.lvl) .. q.name
          end })
      end
    end
    y = y + 5
  end
  -- 3. route: the zone you're in and its next tasks
  local r = currentEntry()
  if r then
    local key = r.zone .. "|" .. r.from
    local steps = RG.STEPS[key] or {}
    local doneN = 0
    for i = 1, #steps do if RG.StepIsDone(r, i) then doneN = doneN + 1 end end
    -- the first open step, split into its quests when it's a generated one
    local firstOpen
    for i = 1, #steps do if not RG.StepIsDone(r, i) then firstOpen = i break end end
    local qlines, qdone, qtotal, place, levels
    if firstOpen then qlines, qdone, qtotal, place, levels = RG.StepQuestLines(r, firstOpen, quests) end
    local isFolded
    local right = GREY .. doneN .. "/" .. #steps .. " steps|r"
    if qlines then right = GREY .. "step " .. firstOpen .. " of " .. #steps .. "|r" end
    n = n + 1; y, isFolded = section(n, y, "Route: " .. r.zone, "route", right)
    if not isFolded and RG.SmartAlternatives and RG.db.smart ~= false and RG.db.routeStyle ~= "guided" then
      local ok, alts = pcall(RG.SmartAlternatives, r)
      if ok and alts and #alts > 0 then
        local names = {}
        for _, o in ipairs(alts) do names[#names + 1] = o.r.zone end
        n = n + 1
        y = item(n, y, GREY .. "Also good: " .. table.concat(names, ", ") .. "|r", { single = true, indent = 2,
          tip = GOLD .. "Smart route|r picks the zone that suits your level, position and quest log.\n\n" .. (function() local t = {} for _, o in ipairs(alts) do t[#t + 1] = "|cffffffff" .. o.r.zone .. "|r: " .. o.why end return table.concat(t, "\n") end)() .. "\n\n" .. GOLD .. "/wp smart|r turns this off." })
      end
    end
    if not isFolded and qlines then
      local sk = key .. "#" .. firstOpen
      local wp = RG.StepWaypoint and RG.StepWaypoint(r, firstOpen)
      -- where this step happens
      n = n + 1
      y = item(n, y, (isTarget(wp) and ARROW or (wp and RG.PIN or "")) .. "|cffc9a227" .. (place or r.zone) .. "|r" .. (levels and (GREY .. "  ·  " .. levels .. "|r") or ""),
        { indent = 2, wp = wp, right = GREY .. qdone .. "/" .. qtotal .. " quests done|r",
          tip = GOLD .. "This step:|r the quests below, all from " .. (place or r.zone) .. ".\nIt ticks itself off once they're all handed in.\n\n" ..
            (wp and (GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Right-click:|r show it on the map\n") or "") .. GOLD .. "Shift-click:|r skip this step",
          onClick = function() if IsShiftKeyDown and IsShiftKeyDown() then RG.TickStep(sk, steps[firstOpen]) end end,
          onRightClick = wp and function() RG.Follow(wp) end or nil })
      -- the arrow goes to the first thing to do: a hand-in, else a pick-up, else the hub
      if RG.AutoPin and not (RG.Opt("smartPlan") and RG.Objective and RG.Objective()) then
        local first = qlines[1]
        if first and first.wp and (first.act == "turnin" or first.act == "pickup") then RG.AutoPin(sk .. "@" .. first.act .. first.id, first.wp)
        elseif wp then RG.AutoPin(sk, wp) end
      end
      -- an icon per kind of task, like the quest log: ? hand in, ! pick up, sword to do, clock for later
      local VERB = { turnin = "|TInterface\\GossipFrame\\ActiveQuestIcon:13:13:0:-1|t ", pickup = "|TInterface\\GossipFrame\\AvailableQuestIcon:13:13:0:-1|t ",
        doing = "|TInterface\\Icons\\INV_Sword_27:13:13:0:-1:64:64:5:59:5:59|t ", later = "|TInterface\\Icons\\INV_Misc_PocketWatch_01:13:13:0:-1:64:64:5:59:5:59|t " }
      local shownL = 0
      for _, l in ipairs(qlines) do
        if shownL < 6 then
          shownL = shownL + 1
          local nameCol = (l.act == "later" and GREY) or (l.act == "turnin" and "|cff8be0a4") or (l.act == "doing" and "|cff9fd4ff") or "|cffffffff"
          local rt
          if l.act == "turnin" then rt = GREEN .. "to " .. (l.npc or "the quest giver") .. "|r"
          elseif l.act == "pickup" then rt = GREY .. (l.npc and ("from " .. l.npc) or "starts from an item or object") .. "|r"
          elseif l.act == "doing" then rt = l.prog and ("|cffffffff" .. l.prog .. "|r") or (GREY .. "in your log|r")
          else rt = GREY .. l.npc .. "|r" end
          local tip
          if l.act == "turnin" then tip = "Done: take it back to " .. (l.npc or "the quest giver") .. "."
          elseif l.act == "pickup" then tip = "Get this quest from " .. (l.npc or "the quest giver") .. "."
          elseif l.act == "doing" then tip = "In your quest log: finish its objectives."
          else tip = "Not open yet: it becomes available " .. l.npc .. "." end
          if l.wp then tip = tip .. "\n\n" .. GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Right-click:|r show it on the map" end
          if l.act == "doing" then tip = tip .. (l.wp and "\n" or "\n\n") .. GOLD .. "Click:|r open the quest" end
          n = n + 1
          y = item(n, y, (isTarget(l.wp) and ARROW or "") .. VERB[l.act] .. nameCol .. l.name .. "|r",
            { indent = 12, right = rt, wp = l.wp, tip = "|cffffffff" .. l.name .. "|r\n" .. tip,
              onClick = function() if l.act == "doing" then RG.OpenQuest(l.name, l.id) elseif l.wp then RG.PinWaypoint(l.wp) end end,
              onRightClick = l.wp and function() RG.Follow(l.wp) end or nil })
        end
      end
      if #qlines > shownL then n = n + 1; y = item(n, y, GREY .. "+" .. (#qlines - shownL) .. " more on the Route tab|r", { single = true, indent = 12, noArrow = true, onClick = function() if RG.ShowTab then RG.ShowTab("route") end end }) end
      -- what comes after this step
      local nextI
      for i = firstOpen + 1, #steps do if not RG.StepIsDone(r, i) then nextI = i break end end
      if nextI then
        local _, _, nt, np, nl = RG.StepQuestLines(r, nextI, quests)
        n = n + 1
        y = item(n, y, GREY .. "Then: " .. (np or plain(steps[nextI]):sub(1, 40)) .. (nl and (", " .. nl) or "") .. (nt and (" (" .. nt .. " quests)") or "") .. "|r",
          { single = true, indent = 2, wp = RG.StepWaypoint and RG.StepWaypoint(r, nextI), tip = "The next step of this zone's route.\nThe Route tab has every step.\n\n" .. GOLD .. "Click:|r open the route", noArrow = true, onClick = function() if RG.ShowTab then RG.ShowTab("route") end end })
      end
      if RG.TravelSummary then
        local tip = RG.TravelSummary(r.zone)
        if tip then n = n + 1; y = item(n, y, GOLD .. "Getting there:|r " .. tip, { wp = destWp(r), tip = "The quickest way from here, using your hearthstone, the flight paths you know, zeppelins and boats.\n\n" .. GOLD .. "Click:|r arrow to the first stop in " .. r.zone }) end
      end
      local u = lastTick(key .. "#")
      if u then
        n = n + 1
        y = item(n, y, GREY .. "Skipped a step|r", { single = true, right = GOLD .. "Undo|r", tip = "Click to put it back on your list.\n/wp undo does the same.",
          onClick = function() RG.UndoTick() end })
      end
    elseif not isFolded then
      local shown = 0
      for i, text in ipairs(steps) do
        local done = RG.StepIsDone(r, i)
        if not done and shown < 2 then
          shown = shown + 1
          n = n + 1
          local sk = key .. "#" .. i
          local wp = RG.StepWaypoint and RG.StepWaypoint(r, i)
          if wp and shown == 1 and RG.AutoPin then RG.AutoPin(key .. "#" .. i, wp) end
          y = item(n, y, (isTarget(wp) and ARROW or (wp and RG.PIN or "")) .. text, { box = false, wp = wp, tip = GOLD .. "Shift-click:|r tick this off" .. (wp and ("\n" .. GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Right-click:|r show " .. wp[4] .. " on the map") or ""), onClick = function() if IsShiftKeyDown and IsShiftKeyDown() then RG.TickStep(sk, text) end end,
            onRightClick = wp and function() RG.Follow(wp) end or nil })
        end
      end
      if shown == 0 then n = n + 1; y = item(n, y, GREEN .. "All done here. The Route tab has your next zone.|r", { onClick = function() if RG.ShowTab then RG.ShowTab("route") end end }) end
      if shown > 0 and RG.TravelSummary then
        local tip = RG.TravelSummary(r.zone)
        if tip then n = n + 1; y = item(n, y, GOLD .. "Getting there:|r " .. tip, { wp = destWp(r), tip = "The quickest way from here, using your hearthstone, the flight paths you know, zeppelins and boats.\n\n" .. GOLD .. "Click:|r arrow to the first stop in " .. r.zone }) end
      end
      local u = lastTick(key .. "#")
      if u then
        local short = plain(u.text); if #short > 30 then short = short:sub(1, 28) .. "..." end
        n = n + 1
        y = item(n, y, GREY .. "Ticked: " .. short .. "|r", { single = true, right = GOLD .. "Undo|r", tip = "Click to put this task back on your list.\n" .. GREY .. plain(u.text) .. "\n/wp undo does the same.|r",
          onClick = function() RG.UndoTick() end })
      end
    end
    y = y + 5
  end
  -- 3b. hand-written class chain (paladin): the next step for your level
  local shownClassSteps = false
  for _, pr in ipairs(RG.ROUTE) do
    if pr.kind == "pala" and lvl >= pr.from and lvl <= pr.to then
      local pkey = pr.zone .. "|" .. pr.from
      local psteps = RG.STEPS[pkey] or {}
      local left, first, firstI = 0, nil, nil
      for i, text in ipairs(psteps) do
        if not RG.StepIsDone(pr, i) then left = left + 1; if not first then first, firstI = text, i end end
      end
      if first then
        local isFolded
        shownClassSteps = true
        n = n + 1; y, isFolded = section(n, y, "Class quests: " .. pr.hub, "pala", GREY .. left .. " to do|r")
        if not isFolded then
          local sk = pkey .. "#" .. firstI
          local wp = RG.StepWaypoint and RG.StepWaypoint(pr, firstI)
          n = n + 1
          y = item(n, y, (isTarget(wp) and ARROW or (wp and RG.PIN or "")) .. first, { box = false, wp = wp,
            tip = GOLD .. "Shift-click:|r tick this off" .. (wp and ("\n" .. GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Right-click:|r show " .. wp[4] .. " on the map") or "") .. "\nThe Route tab has the whole chain.",
            onClick = function() if IsShiftKeyDown and IsShiftKeyDown() then RG.TickStep(sk, first) end end, onRightClick = wp and function() RG.Follow(wp) end or nil })
        end
        y = y + 5
      end
      break
    end
  end
  -- 3c. class quests from the quest database (every class): shown when no
  -- hand-written class chain is active right now
  if not shownClassSteps and RG.ClassQuests then
    local cq = RG.ClassQuests(3)
    if #cq > 0 then
      local isFolded
      n = n + 1; y, isFolded = section(n, y, "Class quests", "pala", cq[1].now and (GREEN .. "pick up now|r") or (GREY .. "at " .. cq[1].req .. "|r"))
      if not isFolded then
        for _, q in ipairs(cq) do
          local wp = q.wp
          n = n + 1
          y = item(n, y, (isTarget(wp) and ARROW or "") .. RG.LevelTag(q.lvl) .. (q.now and "|cffffd100" or GREY) .. q.name .. "|r", { single = true, wp = wp,
            right = q.now and (GREY .. "from " .. (q.giver or "?") .. "|r") or (GREY .. "at level " .. q.req .. "|r"),
            tip = "|cffffffff" .. q.name .. "|r\n" .. GREY .. "From " .. (q.giver or "?") .. (q.now and "" or (" at level " .. q.req)) .. "|r\n\n" .. GOLD .. "Click:|r show the quest giver on the map\n" .. GOLD .. "Click:|r arrow on / off",
            onClick = function() RG.PinWaypoint(wp) end })
        end
      end
      y = y + 5
    end
  end
  -- 4. next dungeon: quests still to collect
  local dr, dq = nextDungeon()
  if dr then
    local missing = {}
    for _, q in ipairs(dq.quests) do
      local st = RG.QuestState and RG.QuestState((q[1]:gsub("%s*%(.-%)$", "")))
      if not st and (not q.id or RG.QuestPrereqsMet(q.id)) then missing[#missing + 1] = q end
    end
    local isFolded
    n = n + 1; y, isFolded = section(n, y, dr.zone, "dungeon", lvl >= dq.go and (GREEN .. "go now|r") or (GREY .. "go at " .. dq.go .. "|r"))
    if not isFolded then
      if lvl >= dq.go and RG.TravelSummary then
        local tip = RG.TravelSummary(dr.zone)
        if tip then n = n + 1; y = item(n, y, GOLD .. "Getting there:|r " .. tip, { wp = destWp(dr), tip = "Click: arrow to " .. dr.zone }) end
      end
      if #missing == 0 then n = n + 1; y = item(n, y, GREEN .. "All its quests are in your log.|r", { single = true })
      else
        for i = 1, math.min(3, #missing) do
          local q = missing[i]
          local gw = q.wp or (RG.WAYPOINTS and RG.WAYPOINTS.givers[q[2]])
          n = n + 1
          y = item(n, y, (isTarget(gw) and ARROW or "") .. RG.LevelTag(RG.QuestLevel(q[1])) .. "|cffffd100" .. q[1] .. "|r", { single = true, right = GREY .. "pick up|r", wp = gw,
            tip = "|cffffffff" .. q[1] .. "|r\n" .. GREY .. q[2] .. ", " .. q[3] .. "|r" .. (gw and ("\n\n" .. GOLD .. "Click:|r show " .. q[2] .. " on the map\n" .. GOLD .. "Click:|r arrow on / off") or ""),
            onClick = gw and function() RG.PinWaypoint(gw) end or nil, onRightClick = gw and function() RG.Follow(gw) end or nil })
        end
        if #missing > 3 then n = n + 1; y = item(n, y, GREY .. "+" .. (#missing - 3) .. " more on the Route tab|r", { single = true, onClick = function() if RG.ShowTab then RG.ShowTab("route") end end }) end
      end
      -- what it drops for you
      local drops = RG.DungeonDrops and RG.DungeonDrops(dr.zone, 2) or {}
      if #drops > 0 then
        local parts = {}
        for _, dd in ipairs(drops) do parts[#parts + 1] = (RG.ItemInfo(dd.g.id) or "item") .. " " .. GREEN .. string.format("+%.0f", dd.d) .. "|r" end
        n = n + 1; y = item(n, y, GOLD .. "Drops for you:|r " .. table.concat(parts, GREY .. ", |r"), { tip = GREY .. "Upgrades from your gear guide that drop here.|r", onClick = function() if RG.ShowTab then RG.ShowTab("gear") end end })
      end
    end
    y = y + 5
  end
  -- 5. next upgrade (one line)
  local up = nextUpgrade()
  if up then
    local name = RG.ItemInfo(up.g.id) or "item"
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "Next upgrade", "upgrade")
    if not isFolded then
      n = n + 1; y = item(n, y, "|cffffffff" .. name .. "|r", { single = true, right = GREEN .. string.format("+%.0f", up.d) .. "|r",
        tip = "|cffffffff" .. name .. "|r  " .. GREEN .. string.format("+%.0f %s", up.d, RG.SCORE_NAME) .. "|r\n" .. GREY .. up.g.src .. ", " .. up.g.zone .. "|r\n\n" .. GOLD .. "Click:|r where it drops or which quest gives it\n" .. GOLD .. "Right-click:|r open the Gear guide",
        wp = RG.WaypointForText and RG.WaypointForText(up.g.src or ""),
        onClick = function() if RG.ShowItemSource then RG.ShowItemSource(up.g, { note = GREEN .. string.format("+%.0f", up.d) .. "|r" .. GREY .. " over what you wear|r" }) end end,
        onRightClick = function() if RG.ShowTab then RG.ShowTab("guide") end end })
    end
    y = y + 5
  end
  -- 5b. professions: the step you're on and what you're short of
  if RG.Opt("trackerProfs") and RG.ProfNow then
    local entries = {}
    for name, k in pairs(RG.Professions and RG.Professions() or {}) do
      local now = RG.PROFESSIONS and RG.PROFESSIONS[name] and RG.ProfNow(name, k.rank)
      if now and now.st and not now.done then
        local text, short, firstShort
        if now.craft then
          short = 0
          for _, e in ipairs(now.mats or {}) do
            if not e.via and e.short > 0 then short = short + 1; firstShort = firstShort or e end
          end
          text = now.craft .. " x" .. (now.left or 0) .. (firstShort and (GREY .. "  ·  " .. firstShort.short .. " more " .. firstShort.name .. (short > 1 and (", +" .. (short - 1)) or "") .. "|r") or (GREEN .. "  ·  ready|r"))
        else
          text = (now.st.gather or now.st.skin or (now.st.fish and ("fish in " .. now.st.fish)) or "") .. GREY .. "  ·  to " .. now.st.to .. "|r"
        end
        entries[#entries + 1] = { name = name, rank = k.rank, text = text, now = now, order = now.craft and (firstShort and 0 or 1) or 2 }
      end
    end
    if #entries > 0 then
      table.sort(entries, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.name < b.name end)
      local isFolded
      n = n + 1; y, isFolded = section(n, y, "Professions", "profs", GREY .. #entries .. "|r")
      if not isFolded then
        for i = 1, math.min(3, #entries) do
          local e = entries[i]
          local places = RG.ProfPlaces and RG.ProfPlaces(e.name, e.now) or {}
          local pl = places[1]
          n = n + 1
          y = item(n, y, "|cffffffff" .. e.name .. " " .. e.rank .. "|r  " .. e.text, { single = true, wp = pl and pl.wp,
            tip = "|cffffffff" .. e.name .. "|r " .. e.rank .. "\n" .. e.text .. (pl and ("\n\n" .. GOLD .. "Click:|r arrow to " .. (pl.wp and pl.wp[4] or pl.title)) or "") .. "\n" .. GOLD .. "Click:|r open its guide",
            onClick = function() if RG.ShowProf then RG.ShowProf(e.name) end end })
        end
      end
      y = y + 5
    end
  end
  -- 6. reminders: the most important few
  local rem = RG.Reminders and RG.Reminders() or {}
  if #rem > 0 then
    for i, rr in ipairs(rem) do rr.i = i end
    table.sort(rem, function(a, b) local pa, pb = a[3] or 3, b[3] or 3; if pa ~= pb then return pa < pb end return a.i < b.i end)
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "Reminders", "reminders", GREY .. #rem .. "|r")
    if not isFolded then
      for i = 1, math.min(4, #rem) do local rr = rem[i]; n = n + 1; y = item(n, y, rr[1], { onClick = rr[2], wp = rr[4], tip = rr[4] and (GOLD .. "Click:|r arrow on / off") or nil }) end
      if #rem > 4 then n = n + 1; y = item(n, y, GREY .. "+" .. (#rem - 4) .. " more  ·  turn reminders off in Settings|r", { single = true, onClick = function() if RG.ShowTab then RG.ShowTab("settings") end end }) end
    end
  end
  -- the sections that were folded into one row
  y = y - 5 * skipped
  if #hints > 0 and not moreOpen then
    local parts, full = {}, {}
    for _, h in ipairs(hints) do
      local t = h.name .. ((h.note and h.note ~= "") and (": " .. h.note) or "")
      parts[#parts + 1] = h.urgent and (GREEN .. t .. "|r") or (GREY .. t .. "|r")
      full[#full + 1] = (h.urgent and GREEN or "|cffffffff") .. t .. "|r"
    end
    n = n + 1
    y = item(n, y, "|cff8a8a8a+ MORE|r   " .. table.concat(parts, GREY .. "  ·  |r"),
      { single = true, indent = 2, tip = table.concat(full, "\n") .. "\n\n" .. GOLD .. "Click:|r show these sections",
        onClick = function() RG.db.trackerMore = true; RG.RefreshTracker() end })
  elseif moreOpen then
    n = n + 1
    y = item(n, y, "|cff8a8a8a- SHOW LESS|r", { single = true, indent = 2, tip = "Fold the extra sections back into one row.",
      onClick = function() RG.db.trackerMore = false; RG.RefreshTracker() end })
  end
  tr.body:SetHeight(math.max(10, y))
  tr:SetHeight(42 + y + 40)
end

-- Fade the tracker during fights so it doesn't cover the action.
table.insert(RG.OPTIONS, { key = "trackerLocked", label = "Lock the tracker in place", default = false })
table.insert(RG.OPTIONS, { key = "trackerProfs", label = "Show your professions' next step and missing materials on the tracker", default = true })
table.insert(RG.OPTIONS, { key = "trackerFade", label = "Fade the tracker during combat", default = true })
local fade = CreateFrame("Frame")
fade:RegisterEvent("PLAYER_REGEN_DISABLED"); fade:RegisterEvent("PLAYER_REGEN_ENABLED")
fade:SetScript("OnEvent", function(_, event)
  if not tr then return end
  if event == "PLAYER_REGEN_DISABLED" and RG.Opt("trackerFade") then tr:SetAlpha(0.35) else tr:SetAlpha(1) end
end)

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
