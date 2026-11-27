local _, RG = ...
-- Waypath+ current step and drop rates.
--   * Drop rates: how often a quest's items drop and from what (Objectives.lua carries them, from Polestar forever-db's
--     item sources and the cMaNGOS loot tables). Shown in the tracker's tooltips (RG.DropTip) and on the current step.
--   * The current step: a card under the tracker's header that says what to do right now (it follows RG.Objective):
--     where, how often its items drop, a 3D model of the mob (or the item's icon, or the quest giver) to look for,
--     why it's next and what comes after.
-- Models are only asked for out in the world: never inside an instance (as the card game does, see v1.60.2).
local GOLD, GREY, GREEN = RG.COLORS.GOLD, RG.COLORS.GREY, RG.COLORS.GREEN
local GOLDC = { 1, 0.82, 0 }   -- the tracker's gold (the restyle's fixed colours, Tracker.lua's RG.TPAL)


-- ---------------------------------------------------------------------------------------------------------------------
-- Drop rates
-- ---------------------------------------------------------------------------------------------------------------------
local function pct(c)
  if not c or c <= 0 then return nil end
  if c >= 10 then return string.format("%d%%", math.floor(c + 0.5)) end
  return (string.format("%.1f", c):gsub("%.0$", "")) .. "%"
end
-- "from Riverpaw Gnoll, Riverpaw Mongrel and 2 more · 80%", or "from Burning Blade Fanatic · 20%, Burning Blade Apprentice · 5%";
-- without chances (a quest the loot tables don't have yet), just who drops it: "from Angerclaw Bear, Angerclaw Grizzly and 1 more"
local function names(list)
  local n = {}
  for i = 1, math.min(2, #list) do n[i] = list[i][1] end
  return table.concat(n, #list == 2 and " and " or ", ") .. (#list > 2 and (" and " .. (#list - 2) .. " more") or "")
end
local function dropPhrase(mobs, chances)
  if not mobs then return nil end
  local list = {}
  if not chances then
    for _, name in ipairs(mobs) do list[#list + 1] = { name } end
    return #list > 0 and ("from " .. names(list)) or nil
  end
  for i, name in ipairs(mobs) do if chances[i] and chances[i] > 0 then list[#list + 1] = { name, chances[i] } end end
  if #list == 0 then return nil end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  local same = true
  for _, x in ipairs(list) do if pct(x[2]) ~= pct(list[1][2]) then same = false end end
  if same then return "from " .. names(list) .. " · " .. pct(list[1][2]) end
  local parts = {}
  for i = 1, math.min(3, #list) do parts[i] = list[i][1] .. " · " .. pct(list[i][2]) end
  return "from " .. table.concat(parts, ", ") .. (#list > 3 and (", " .. (#list - 3) .. " more") or "")
end
RG.DropPhrase = dropPhrase
-- The quest's items and how they drop: { { item = name, text = phrase, rate = true when the chances are known }, ... }
-- (objectives with known rates, or at least known mobs that drop them).
-- label: just the objective with that name (the quest log's wording may differ a little: a match either way counts).
function RG.DropInfo(id, label)
  local d = id and RG.QDATA and RG.QDATA[id]
  if not d then return {} end
  local out, want = {}, label and label:lower()
  for _, o in ipairs(d.o or {}) do
    -- (no chances: only when the item's sources are mobs, o[5] their NPC ids; an item from a chest isn't "dropped")
    if o[1] == "i" and (o[7] or (o[5] and #o[5] > 0)) then
      local name = tostring(o[2] or "?")
      local l = name:lower()
      if not want or l == want or want:find(l, 1, true) or l:find(want, 1, true) then
        local text = dropPhrase(o[3], o[7])
        if text then out[#out + 1] = { item = name, text = text, rate = o[7] and true or nil } end
      end
    end
  end
  -- a quest that starts from an item: how often that drops
  local si = d.si
  if not label and si and si[1] == "i" and si[8] then
    local text = dropPhrase(si[3], si[8])
    if text then out[#out + 1] = { item = tostring(si[2]), text = text, starts = true } end
  end
  return out
end
-- A tooltip section for a quest's drop rates ("" when nothing is known).
function RG.DropTip(id, label)
  local info = RG.DropInfo(id, label)
  if #info == 0 then return "" end
  local t = {}
  for _, x in ipairs(info) do
    t[#t + 1] = "|cffe6e6e6" .. x.item .. (x.starts and " (starts the quest)" or "") .. ":|r " .. GREY .. "drops " .. x.text .. "|r"
  end
  return "\n\n" .. GOLD .. "Drops:|r\n" .. table.concat(t, "\n")
end

-- ---------------------------------------------------------------------------------------------------------------------
-- What to look for: the NPC (a 3D model), or the item's icon
-- ---------------------------------------------------------------------------------------------------------------------
-- the quest's objective the planner points at (its kind and label), else its first one of that kind
local function objectiveOf(d, okind, label)
  if not (d and d.o) then return nil end
  local want = label and tostring(label):lower()
  local first
  for _, o in ipairs(d.o) do
    if not okind or o[1] == okind then
      first = first or o
      local l = tostring(o[2] or ""):lower()
      if want and (l == want or want:find(l, 1, true) or (l ~= "" and l:find(want, 1, true))) then return o end
    end
  end
  return first
end
-- { npc = id, name = label, icon = file id or path } for the thing to do now
local function lookFor(obj, it)
  local d = it and it.id and RG.QDATA and RG.QDATA[it.id]
  if not d then return nil end
  if it.act == "turnin" then
    local e = d.e
    return e and { npc = e[5], name = e[4] } or nil
  elseif it.act == "pickup" then
    if d.s then return { npc = d.s[5], name = d.s[4] } end
    local si = d.si
    if si then
      local npc = si[6] and si[6][1]
      return { npc = npc, name = npc and si[3] and si[3][1] or si[2], icon = (si[1] == "i" and si[7]) and (GetItemIcon and GetItemIcon(si[7])) or nil, item = si[1] == "i" and si[2] or nil }
    end
    return nil
  end
  local o = objectiveOf(d, it.okind, it.label)
  if not o then return nil end
  local npc = o[5] and o[5][1]
  local icon = (o[1] == "i" and o[6] and GetItemIcon) and GetItemIcon(o[6]) or nil
  return { npc = (o[1] ~= "o") and npc or nil, name = (npc and o[3] and o[3][1]) or o[2], icon = icon, item = o[1] == "i" and o[2] or nil, obj = o }
end

-- ---------------------------------------------------------------------------------------------------------------------
-- The current step: a card under the tracker's header (it's part of the tracker, not a window of its own)
-- ---------------------------------------------------------------------------------------------------------------------
-- What to do (Do / Hand in / Pick up / Go), the quest, how far, and its objective with the progress; then where it is,
-- how often its items drop, a picture of the mob, item or quest giver to look for, why it's next, what comes after and
-- a Skip button. Folded, the tracker keeps only the first two lines. In the professions view it shows the profession
-- step you're on (RG.ProfFocus).
local MODEL = 66
local STRIP = 27   -- the strip across the card's top: what to do, the quest, how far
local f, model
local cardH = 0
function RG.StepCardHeight() return (f and f:IsShown()) and cardH or 0 end
-- Skip what the card shows: a stop of your quests for an hour (it comes back after), or a route step (ticked:
-- /wp undo puts it back). "Never" stops suggesting the quests to pick up there.
local function afterSkip(what)
  if RG.ForgetNextStep then RG.ForgetNextStep() end
  if RG.SyncObjective then RG.SyncObjective(RG.Objective(true)) end
  if RG.RefreshTracker then RG.RefreshTracker() end
  if RG.Notify then RG.Notify("Skipped: " .. what) end
end
local function routeKey(obj) return obj and obj.kind == "route" and obj.key and obj.key:match("^route:(.+)$") end
local function skipNow()
  local obj = RG.Objective and RG.Objective()
  if not obj then return end
  local rk = routeKey(obj)
  if obj.manual and RG.PickManually then
    -- one you picked yourself: back to what the plan says
    RG.PickManually(nil); afterSkip("your pick (" .. tostring(obj.qtitle or obj.text or "") .. ")")
  elseif rk and RG.TickStep then RG.TickStep(rk, obj.text); afterSkip((obj.text or "this step") .. " (/wp undo brings it back)")
  elseif obj.kind == "shop" and obj.shopKey then
    -- the shopping stop: not again for this zone
    RG.db.shopDone = RG.db.shopDone or {}
    RG.db.shopDone[obj.shopKey] = true
    afterSkip(obj.qtitle or "the shopping stop")
  elseif obj.stop and RG.SkipStop then
    RG.SkipStop(obj.stop)
    local after = RG.Objective(true)
    if after and after.key == obj.key then
      -- nothing else to go to, so the same stop came straight back. The ordered guide: this stop was all that's left of
      -- the route step you're on, so skip the step and move on to the next one
      local r = RG.TrackerView and RG.TrackerView() == "guide" and RG.CurrentRouteEntry and RG.CurrentRouteEntry()
      local cur = r and RG.NextStep and RG.NextStep(r)
      local key = r and (r.zone .. "|" .. r.from)
      if cur and RG.TickStep then
        -- (the stop's own skip is taken back, so /wp undo brings back the step)
        if RG.UnskipStop then RG.UnskipStop() end
        RG.TickStep(key .. "#" .. cur, RG.STEPS[key] and RG.STEPS[key][cur] or "")
        afterSkip("this step (/wp undo brings it back)")
      else
        afterSkip((obj.qtitle or "this stop") .. " for an hour")
        RG.Print("Nothing else to go to" .. ((RG.TrackerView and RG.TrackerView() == "zone" and RG.FollowZone and RG.FollowZone()) and (" in " .. RG.FollowZone()) or "") .. ", so it stays the current step.")
      end
    else afterSkip((obj.qtitle or "this stop") .. " for an hour") end
  else RG.Print("Nothing here to skip.") end
end
RG.SkipCurrentStep = skipNow   -- (the main window's Route page has a Skip step button too)
local function skipMenu()
  local obj = RG.Objective and RG.Objective()
  local e = {}
  if routeKey(obj) then e[#e + 1] = { "Skip this route step (/wp undo brings it back)", skipNow }
  elseif obj and obj.stop then
    e[#e + 1] = { "Skip this stop for an hour", skipNow }
    local seen = {}
    for _, it in ipairs(obj.stop.items or {}) do
      if it.act == "pickup" and it.id and not seen[it.id] and RG.IgnoreQuest then
        seen[it.id] = true
        e[#e + 1] = { "Never suggest " .. tostring(it.title) .. " again", function() RG.IgnoreQuest(it.id); afterSkip(tostring(it.title)) end }
      end
    end
  end
  if #e <= 1 then skipNow() return end
  if RG.ShowMenu then RG.ShowMenu(e, "Current step") end
end
RG.StepViewSkip = skipNow

local function inInstance() return IsInInstance and select(1, IsInInstance()) and true or false end
local function newText(parent, size, kind)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  if RG.Font then RG.Font(fs, kind or "medium", size) else fs:SetFontObject("GameFontHighlightSmall") end
  fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP")
  return fs
end
local function build()
  if f then return f end
  local t = _G.WaypathTracker
  if not t then return nil end
  f = CreateFrame("Button", "WaypathStepView", t)
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  -- the restyle (Tracker.lua's RG.TPAL): a brass-edged card, a darker strip across its top for what to do and the quest
  local P = RG.TPAL
  if RG.TFramed then RG.TFramed(f, P.box, P.border) end
  local strip = f:CreateTexture(nil, "BACKGROUND", nil, -6); strip:SetPoint("TOPLEFT", 1, -1); strip:SetPoint("TOPRIGHT", -1, -1); strip:SetHeight(STRIP - 1)
  strip:SetColorTexture(P.strip[1], P.strip[2], P.strip[3], 1)
  local rule = f:CreateTexture(nil, "BORDER"); rule:SetPoint("TOPLEFT", 1, -STRIP); rule:SetPoint("TOPRIGHT", -1, -STRIP); rule:SetHeight(1)
  rule:SetColorTexture(P.line[1], P.line[2], P.line[3], 1)
  local hl = f:CreateTexture(nil, "HIGHLIGHT"); hl:SetPoint("TOPLEFT", 1, -1); hl:SetPoint("BOTTOMRIGHT", -1, 1); hl:SetColorTexture(1, 0.82, 0, 0.03)
  if RG.TrackerDragFrom then RG.TrackerDragFrom(f) end
  -- what to do (a small brass-edged tag), the quest in Marcellus gold, how far
  f.chipF = CreateFrame("Frame", nil, f); f.chipF:SetHeight(15); f.chipF:SetPoint("TOPLEFT", 8, -6)
  if RG.TFramed then RG.TFramed(f.chipF, P.chip, P.ring) end
  f.verb = newText(f.chipF, 9.5, "semibold"); f.verb:SetPoint("CENTER", 0, 0); f.verb:SetJustifyH("CENTER")
  f.dist = newText(f, 11.5, "semibold"); f.dist:SetPoint("TOPRIGHT", -8, -8); f.dist:SetJustifyH("RIGHT"); f.dist:SetTextColor(P.light[1], P.light[2], P.light[3])
  f.title = f:CreateFontString(nil, "OVERLAY"); f.title:SetJustifyH("LEFT"); f.title:SetJustifyV("MIDDLE")
  if RG.TDisplayFont then RG.TDisplayFont(f.title, 14) else RG.Font(f.title, "semibold", 13) end
  f.title:SetPoint("LEFT", f.chipF, "RIGHT", 8, 0); f.title:SetPoint("RIGHT", f.dist, "LEFT", -6, 0)
  f.title:SetWordWrap(false); f.title:SetTextColor(P.gold[1], P.gold[2], P.gold[3]); f.title:SetShadowColor(0, 0, 0, 0.9); f.title:SetShadowOffset(1, -1)
  -- the objective and its progress (more lines are added beside it for a quest with several)
  f.prog = newText(f, 12, "semibold"); f.prog:SetJustifyH("RIGHT")
  f.obj = newText(f, 12); f.obj:SetWordWrap(false)
  f.obj:SetTextColor(P.ink[1], P.ink[2], P.ink[3])
  -- details: the picture (a 3D model of the NPC, or an icon) in a round brass frame, and beside it where, drops and how
  f.pic = CreateFrame("Frame", nil, f); f.pic:SetSize(MODEL, MODEL); f.pic:SetPoint("TOPLEFT", 8, -(STRIP + 8))
  local pbg = f.pic:CreateTexture(nil, "BACKGROUND"); pbg:SetAllPoints(); pbg:SetTexture("Interface\\AddOns\\Waypath\\Media\\Disc")
  pbg:SetVertexColor(P.dark[1], P.dark[2], P.dark[3], 1)
  -- (the ring on a frame of its own, above the model)
  local ringF = CreateFrame("Frame", nil, f.pic); ringF:SetAllPoints(); ringF:SetFrameLevel(f.pic:GetFrameLevel() + 10)
  local pring = ringF:CreateTexture(nil, "OVERLAY"); pring:SetAllPoints(); pring:SetTexture("Interface\\AddOns\\Waypath\\Media\\Ring")
  pring:SetVertexColor(P.ring[1], P.ring[2], P.ring[3], 1)
  f.pic.ring = pring
  f.icon = f.pic:CreateTexture(nil, "ARTWORK"); f.icon:SetSize(46, 46); f.icon:SetPoint("CENTER"); f.icon:Hide()
  -- (the icon round too, where the game has the mask)
  if f.icon.SetMask then pcall(f.icon.SetMask, f.icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
  f.picName = newText(f, 9); f.picName:SetPoint("TOP", f.pic, "BOTTOM", 0, -3); f.picName:SetWidth(MODEL + 8); f.picName:SetJustifyH("CENTER")
  f.picName:SetTextColor(P.muted[1], P.muted[2], P.muted[3])
  f.body = newText(f, 11); f.body:SetSpacing(2); f.body:SetTextColor(P.ink[1], P.ink[2], P.ink[3])
  -- what comes after, and Skip (red, like the game's close buttons)
  f.line = f:CreateTexture(nil, "ARTWORK"); f.line:SetHeight(1); f.line:SetColorTexture(P.line[1], P.line[2], P.line[3], 1)
  f.skip = CreateFrame("Button", nil, f); f.skip:SetSize(44, 18); f.skip:SetPoint("BOTTOMRIGHT", -7, 5)
  f.skip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  if RG.TFramed then RG.TFramed(f.skip, P.red, P.redEdge) end
  local sbg = f.skip:CreateTexture(nil, "ARTWORK"); sbg:SetPoint("TOPLEFT", 1, -1); sbg:SetPoint("BOTTOMRIGHT", -1, 1); sbg:SetColorTexture(1, 0.82, 0, 0);
  f.skip.label = newText(f.skip, 10.5, "semibold"); f.skip.label:SetPoint("CENTER", 0, 0); f.skip.label:SetJustifyH("CENTER"); f.skip.label:SetText("Skip")
  f.skip.label:SetTextColor(P.gold[1], P.gold[2], P.gold[3])
  f.skip:SetScript("OnClick", function(_, button) if button == "RightButton" then skipMenu() else skipNow() end end)
  f.skip:SetScript("OnEnter", function(self)
    sbg:SetColorTexture(1, 0.82, 0, 0.14)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Skip this step", 1, 0.93, 0.74)
    GameTooltip:AddLine("Click: skip it (a stop of your quests for an hour; a route step until /wp undo)", 1, 1, 1, true)
    GameTooltip:AddLine("Right-click: never suggest a quest here again", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Skipped something by mistake? /wp undo brings back the last skip.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  f.skip:SetScript("OnLeave", function() sbg:SetColorTexture(1, 0.82, 0, 0); GameTooltip:Hide() end)
  f.foot = newText(f, 11); f.foot:SetPoint("BOTTOMLEFT", 8, 8); f.foot:SetPoint("RIGHT", f.skip, "LEFT", -6, 0); f.foot:SetWordWrap(false)
  f.foot:SetTextColor(P.muted[1], P.muted[2], P.muted[3])
  -- click: the arrow to it; right-click: skip, and more
  f:SetScript("OnClick", function(self, button)
    if button == "RightButton" then if not self.prof then skipNow() end return end
    if self.wp and RG.Follow then RG.Follow(self.wp) end
  end)
  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(self.tipTitle or "The current step", 1, 0.93, 0.74, true)
    if self.tipText then GameTooltip:AddLine(self.tipText, 0.8, 0.82, 0.85, true) end
    GameTooltip:AddLine("Click: the arrow to it" .. (self.prof and "" or "  ·  Right-click: skip it"), 1, 1, 1, true)
    if not self.prof then GameTooltip:AddLine("Skipped something by mistake? /wp undo brings back the last skip.", 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f:Hide()
  return f
end

-- the model: asked for once per NPC, checked a moment later (the game may still be fetching it); the icon otherwise
local modelTry = 0
local function showModel(npc, icon)
  if npc and not inInstance() then
    if not model then
      local ok, m = pcall(CreateFrame, "DressUpModel", nil, f.pic)
      -- (inside the round frame: a little in from its edge, so the model's square corners stay within the ring)
      if ok and m then model = m; m:SetPoint("TOPLEFT", 6, -6); m:SetPoint("BOTTOMRIGHT", -6, 6) end
    end
    if model and model.SetCreature then
      if model.cur ~= npc then
        model.cur, modelTry = npc, 0
        if model.ClearModel then pcall(model.ClearModel, model) end
        local ok = pcall(model.SetCreature, model, npc)
        if ok then
          if model.SetPortraitZoom then pcall(model.SetPortraitZoom, model, 0) end
          if model.SetFacing then pcall(model.SetFacing, model, 0.45) end
          -- not there yet? look again shortly, twice at most; then the icon
          local function check()
            if not (model and model.cur == npc) then return end
            local okF, fid = false, nil
            if model.GetModelFileID then okF, fid = pcall(model.GetModelFileID, model) end
            if okF and (not fid or fid == 0) and modelTry < 2 then
              modelTry = modelTry + 1; pcall(model.SetCreature, model, npc); C_Timer.After(1, check)
            elseif okF and (not fid or fid == 0) then
              model.bad = model.bad or {}; model.bad[npc] = true; model:Hide()
              if icon then f.icon:SetTexture(icon); f.icon:Show() end
            end
          end
          if C_Timer and C_Timer.After then C_Timer.After(0.6, check) end
        else model.cur = nil end
      end
      if model.cur == npc and not (model.bad and model.bad[npc]) then model:Show(); f.icon:Hide(); return true end
    end
  end
  if model then model:Hide() end
  if icon then f.icon:SetTexture(icon); f.icon:Show() else f.icon:Hide() end
  return icon ~= nil
end

local VERB = { turnin = { "Hand in", { 0.55, 0.88, 0.64 } }, pickup = { "Pick up", { 1, 0.82, 0 } }, doing = { "Do", { 0.62, 0.83, 1 } } }
local function zoneName(map)
  if RG.MapZone and RG.MapZone(map) then return RG.MapZone(map) end
  local i = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  return i and i.name
end
local function plain(t) return ((t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- How to do a quest in your log, in the game's own words: the objectives summary of its quest log entry ("Fill the
-- Hardened Flasket at the moonwell..."). The game only gives it for the selected entry: it's selected for a moment and
-- your selection put back. Asked once per quest (the words never change).
local questText = {}
function RG.QuestObjectivesText(id)
  if not id then return nil end
  if questText[id] ~= nil then return questText[id] or nil end
  if not GetQuestLogQuestText then return nil end
  local QL = C_QuestLog or {}
  local byIndex = SelectQuestLogEntry and GetQuestLogSelection
  local byId = QL.SetSelectedQuest and QL.GetSelectedQuest
  if not (byIndex or byId) then return nil end
  local idx
  for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do if q.id == id then idx = q.idx break end end
  if not idx then return nil end   -- (not in your log: asked again once it is)
  local ok, text = pcall(function()
    local objectives
    if byIndex then
      local sel = GetQuestLogSelection()
      SelectQuestLogEntry(idx)
      objectives = select(2, GetQuestLogQuestText(idx))
      if sel ~= idx then SelectQuestLogEntry(sel or 0) end
    else
      local sel = QL.GetSelectedQuest()
      QL.SetSelectedQuest(id)
      objectives = select(2, GetQuestLogQuestText(idx))
      if sel ~= id then QL.SetSelectedQuest(sel or 0) end
    end
    return objectives
  end)
  text = ok and type(text) == "string" and text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "") or ""
  questText[id] = text ~= "" and text or false
  return questText[id] or nil
end
-- (a long one cut at a word, the whole of it in the card's tooltip)
local function shortText(t, n)
  if #t <= n then return t end
  return (t:sub(1, n):gsub("%s+%S*$", "")) .. "..."
end

-- What the card says, from the current objective (RG.Objective), or the profession step in the professions view.
local function cardInfo()
  if RG.TrackerView and RG.TrackerView() == "prof" then
    local p = RG.ProfFocus and RG.ProfFocus()
    if not p then return nil end
    return { verb = p.verb, col = { GOLDC[1], GOLDC[2], GOLDC[3] }, title = p.title, line = p.line, wp = p.wp, where = p.where,
      why = p.why, next = p.next, prof = true }
  end
  local obj = RG.Objective and RG.Objective()
  if not obj then return nil end
  local it = obj.stop and obj.stop.items and obj.stop.items[1]
  local v = (it and VERB[it.act]) or (obj.kind == "route" and obj.act and VERB[obj.act]) or ((obj.kind == "route" or obj.kind == "pick") and { "Go", { 1, 0.82, 0 } }) or (obj.kind == "dungeon" and { "In", { 0.62, 0.83, 1 } })
    or (obj.kind == "goal" and { "Goal", { 1, 0.82, 0 } }) or (obj.kind == "prep" and { "Prep", { 0.74, 0.68, 1 } })
    or (obj.kind == "shop" and { "Buy", { 1, 0.82, 0 } }) or { "Next", { 1, 0.82, 0 } }
  local info = { verb = v[1], col = v[2], obj = obj, it = it, wp = obj.wp, dist = obj.dist }
  info.title = obj.qtitle or plain(obj.text)
  local line, prog = obj.qline, nil
  if line then
    local a, b = line:match("^(.-)%s%s+(%d+/%d+)$")
    if a then line, prog = a, b end
  end
  if not line and obj.kind ~= "goal" and obj.kind ~= "route" and obj.kind ~= "prep" then line = obj.wp and zoneName(obj.wp[1]) or nil end
  info.line, info.prog = line, prog
  if prog then
    local h, n = prog:match("(%d+)/(%d+)")
    info.done = h and n and tonumber(h) >= tonumber(n)
  end
  -- a quest with several objectives (bear organs and wolf organs): each on its own line with its own progress
  if it and it.act == "doing" and it.id and RG.QuestObjectiveLines then
    local ls = RG.QuestObjectiveLines(it.id)
    if #ls > 1 then info.lines = ls end
  end
  -- where (the zone, and the place's name when it says more than the quest's; an objective's spot is named after the
  -- objective, which the lines above already say)
  local zone = obj.wp and zoneName(obj.wp[1])
  local place = obj.wp and obj.wp[4]
  if place and (place == info.title or place == zone or obj.kind == "route" or ("Head to " .. place) == info.title or (it and it.act == "doing")) then place = nil end
  info.where = zone and (zone .. (place and (": " .. place) or "")) or place
  -- what it says about the step: for a quest you're doing, how to do it (the game's own words); otherwise the reason
  -- only where it tells you something (a route step's town, your own goal, how the dungeon prep stands). Not what the
  -- header and the lines above already say: what the tracker follows, the zone, the giver, that you picked it.
  local why = ""
  if it then
    if it.act == "doing" then
      local t = RG.QuestObjectivesText and RG.QuestObjectivesText(it.id)
      if t then why, info.whyFull = shortText(t, 170), t end
    end
  elseif ((obj.kind == "route" and obj.act == "doing") or obj.kind == "shop") and obj.why then
    -- (a route step whose quest is in your log but has no known spot: how to do it, in the quest log's words)
    why, info.whyFull = shortText(obj.why, 170), obj.why
  elseif obj.kind ~= "pick" then
    why = obj.why and (obj.why:match("^(.-)%s+·%s+") or obj.why) or ""
    why = why:gsub("%.+$", "")
    if why ~= "" then why = why .. "." end
  end
  info.why = why
  -- the others at the same stop
  if obj.stop and #obj.stop.items > 1 then
    local names, seen = {}, { [info.title] = true }
    for i = 2, #obj.stop.items do
      local x = obj.stop.items[i]
      local t = (x.act == "turnin" and "hand in " or (x.act == "pickup" and "pick up " or "")) .. tostring(x.title)
      if not seen[t] and #names < 3 then seen[t] = true; names[#names + 1] = t end
    end
    if #names > 0 then info.also = "Also here: " .. table.concat(names, ", ") end
  end
  info.next = obj.nextText
  info.skip = (obj.stop or obj.manual or routeKey(obj) or obj.kind == "shop") and true or false
  return info
end

local lastH
function RG.RefreshStepView()
  local t = _G.WaypathTracker
  if not (t and t:IsShown()) or (RG.CardsOnly and RG.CardsOnly()) or not (RG.Opt and RG.Opt("tracker")) then
    if f then f:Hide() end
    if RG.TrackerCardItem then RG.TrackerCardItem(nil) end
    return
  end
  if not build() then return end
  -- (a quest-item button on the tracker and a fight on: the tracker holds still, and so does the card's size)
  local frozen = RG.TrackerFrozen and RG.TrackerFrozen()
  local info = cardInfo()
  local itm, itmQ
  if not info then
    if not frozen then f:Hide(); if RG.TrackerCardItem then RG.TrackerCardItem(nil) end end
    if lastH ~= 0 and not frozen then lastH = 0; if not RG.stepCardFromTracker and RG.RefreshTracker then RG.RefreshTracker() end end
    return
  end
  local W = (t:GetWidth() or 300) - 16
  local folded = RG.db.trackerCollapsed or (RG.trackerInCombat and RG.Opt("trackerCombatFold"))
  local details = not folded
  local P = RG.TPAL
  -- the strip: what to do (a brass-edged tag), the quest, how far
  f.verb:SetText(info.verb:upper())
  f.verb:SetTextColor(P.gold[1], P.gold[2], P.gold[3])
  f.chipF:SetWidth(math.max(22, (f.verb:GetStringWidth() or 20) + 12))
  f.title:SetText(info.title or "")
  f.dist:SetText(info.dist and RG.FormatYards and RG.FormatYards(math.floor(info.dist)) or "")
  -- the picture first: the lines go beside it when there is one (folded: no picture, the objective under the strip)
  -- (it isn't hidden and shown again on every refresh: a 3D model loads afresh each time it's shown, which made it flash
  -- once a second)
  local look, shown
  if details then
    look = info.obj and RG.StepLookFor and RG.StepLookFor(info.obj, info.it)
    shown = look and showModel(look.npc, look.icon or (look.item and 134400) or nil)
  end
  local picShown = shown and true or false
  local x = picShown and (8 + MODEL + 10) or 8
  local top = STRIP + 7
  -- the objective and its progress; a quest with several, one line each
  local lines = info.lines or ((info.line and info.line ~= "") and { { text = info.line, prog = info.prog, done = info.done } }) or {}
  f.objs = f.objs or { { f.obj, f.prog } }
  local LH = 16
  for k = 1, math.max(#lines, #f.objs) do
    local pair, l = f.objs[k], lines[k]
    if l and not pair then
      local p = newText(f, 12, "semibold"); p:SetJustifyH("RIGHT")
      local o = newText(f, 12); o:SetWordWrap(false)
      o:SetTextColor(P.ink[1], P.ink[2], P.ink[3])
      pair = { o, p }; f.objs[k] = pair
    end
    if pair then
      local y = -(top + (k - 1) * LH)
      pair[2]:ClearAllPoints(); pair[2]:SetPoint("TOPRIGHT", -8, y)
      pair[1]:ClearAllPoints(); pair[1]:SetPoint("TOPLEFT", x, y); pair[1]:SetPoint("RIGHT", pair[2], "LEFT", -6, 0)
      pair[1]:SetText(l and l.text or ""); pair[2]:SetText(l and l.prog or "")
      if l and l.done then pair[2]:SetTextColor(P.green[1], P.green[2], P.green[3]) else pair[2]:SetTextColor(1, 1, 1) end
    end
  end
  local h = top + #lines * LH
  f.picName:SetText(""); f.body:Hide(); f.line:Hide(); f.skip:Hide(); f.foot:SetText("")
  if details then
    -- beside the picture: where (parchment), who drops it (green, like the game's quest items), what else is here,
    -- how to do it (muted), the one thing people get wrong (orange)
    local body = {}
    if info.where then body[#body + 1] = "|cffc9b88f" .. info.where .. "|r" end
    if info.it and info.it.act ~= "turnin" and RG.DropInfo then
      -- (several objectives: the drops of each one still to do; else the one the stop is for)
      local done = {}
      for _, l in ipairs(info.lines or {}) do if l.done and l.label then done[l.label:lower()] = true end end
      for _, d in ipairs(RG.DropInfo(info.it.id, (info.it.act == "doing" and not info.lines) and info.it.label or nil)) do
        if not done[d.item:lower()] and not (d.starts and info.it.act == "doing") then
          body[#body + 1] = "|cff1eff00" .. ((d.starts and (d.item .. " (starts the quest): drops ") or "Drops ") .. d.text) .. "|r"
        end
      end
    end
    if info.also then body[#body + 1] = info.also end
    if info.why and info.why ~= "" then body[#body + 1] = "|cff9a8a6a" .. info.why .. "|r" end
    local qn = info.it and info.it.id and RG.QuestNote and RG.QuestNote(info.it.id)
    if qn and qn.n then body[#body + 1] = "|cffff9f43" .. qn.n .. "|r" end
    if picShown then
      f.pic:ClearAllPoints(); f.pic:SetPoint("TOPLEFT", 8, -(STRIP + 8))
      f.picName:SetText(look.name or "")
    end
    local by = h + (#lines > 0 and 3 or 0)
    f.body:ClearAllPoints(); f.body:SetPoint("TOPLEFT", x, -by); f.body:SetWidth(W - x - 8)
    f.body:SetText(table.concat(body, "\n")); f.body:SetShown(#body > 0)
    local bh = #body > 0 and (f.body:GetStringHeight() or 0) or 0
    local ph = picShown and (STRIP + 8 + MODEL + 3 + math.max(10, (f.picName:GetStringHeight() or 10))) or 0
    h = math.max(by + bh, ph) + 8
    -- the quest's usable item (a flask to fill, a horn to blow): a button beside Skip
    if info.it and info.it.id and info.it.act == "doing" and RG.QuestItemFor and RG.Opt("trackerItems") ~= false then
      for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do
        if q.id == info.it.id then itm, itmQ = RG.QuestItemFor(q), q break end
      end
    end
    -- what comes after, and Skip
    if info.next or info.skip or itm then
      f.line:ClearAllPoints(); f.line:SetPoint("TOPLEFT", 1, -h); f.line:SetPoint("TOPRIGHT", -1, -h); f.line:Show()
      f.foot:SetText(info.next and ("|cffffd100Next|r  " .. info.next) or "")
      f.skip:SetShown(info.skip and true or false)
      f.foot:SetPoint("RIGHT", f.skip, "LEFT", itm and -34 or -6, 0)
      h = h + 28
    end
  else
    h = h + 4
  end
  if f.pic:IsShown() ~= picShown then f.pic:SetShown(picShown) end
  f.wp, f.prof = info.wp, info.prof
  f.tipTitle, f.tipText = info.title, info.whyFull
  if frozen and lastH and lastH > 0 then h = lastH end
  local headH = (RG.TrackerHeadH and RG.TrackerHeadH() or 50) + 4
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", t, "TOPLEFT", 8, -headH); f:SetPoint("TOPRIGHT", t, "TOPRIGHT", -8, -headH)
  f:SetHeight(h); f:Show()
  cardH = h
  -- (the item button: to the left of Skip, at the card's foot; it hangs off the tracker, so it's placed from there)
  if not frozen and RG.TrackerCardItem then
    if itm then RG.TrackerCardItem(itm, itmQ, -(8 + 7 + 44 + 6), -(headH + h - 26)) else RG.TrackerCardItem(nil) end
  end
  if h ~= lastH then
    lastH = h
    -- the list under it moves with it
    if not RG.stepCardFromTracker and not frozen and RG.RefreshTracker then RG.RefreshTracker() end
  end
end
RG.StepLookFor = function(obj, it) return lookFor(obj, it) end

-- kept up to date: a second's tick (the objective itself is worked out at most every couple of seconds)
do
  local tick = function() if f or (RG.Opt and RG.Opt("tracker")) then pcall(RG.RefreshStepView) end end
  if RG.PerfWrap then tick = RG.PerfWrap("stepView", tick) end
  local boot = CreateFrame("Frame")
  boot:RegisterEvent("PLAYER_ENTERING_WORLD")
  boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(1, tick) end
    tick()
  end)
end
