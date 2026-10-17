-- Clickable places everywhere: quest objectives, hand-ins and pick-ups on the world map, quests in the game's own quest log and
-- tracker, and Ctrl+click anywhere on the map. Every click sends the arrow there (the same pin the arrow, the map and the
-- minimap already follow). Nothing here moves or hides the game's own frames: we only add small buttons and listen to clicks.
local _, RG = ...

local function on() return not (RG.db and RG.db.mapPins == false) end

-- ---------------------------------------------------------------------------
-- A point to send the arrow to for a quest, given its id
-- ---------------------------------------------------------------------------
function RG.QuestArrow(id)
  if not id or not RG.ArrowTo then return false end
  local d = RG.QDATA and RG.QDATA[id]
  local title = d and d.n or ("quest " .. tostring(id))
  local wp
  for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do
    if q.id == id then
      if q.complete then wp = d and d.e and { d.e[1], d.e[2], d.e[3], d.e[4] ~= "" and d.e[4] or d.n } or q.wp
      else wp = q.wp end
      title = q.title or q.name or title
      break
    end
  end
  if not wp and d and d.s and not (C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id)) then   -- not picked up yet: go to the giver
    wp = { d.s[1], d.s[2], d.s[3], d.s[4] ~= "" and d.s[4] or d.n }
  end
  if not wp then if RG.Notify then RG.Notify("No known place for " .. title .. " yet") end return false end
  local cur = RG.ArrowTarget and RG.ArrowTarget(wp)
  if not cur then RG.ArrowTo(wp) end      -- a click on the same quest again keeps the arrow on it
  return true
end

-- ---------------------------------------------------------------------------
-- The game's quest log and tracker: clicking a quest also points the arrow at it
-- ---------------------------------------------------------------------------
local function modifier() return (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) or (IsAltKeyDown and IsAltKeyDown()) end
local function questIdOf(btn)
  if not btn then return nil end
  if type(btn.questID) == "number" then return btn.questID end
  if type(btn.id) == "number" and btn.id > 0 and btn.questLogIndex == nil then return btn.id end
  local idx = btn.questLogIndex or (btn.GetID and btn:GetID())
  if idx and C_QuestLog and C_QuestLog.GetInfo then
    local info = C_QuestLog.GetInfo(idx)
    if info and not info.isHeader then return info.questID end
  end
  if idx and GetQuestLogTitle then local _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(idx); if not isHeader then return id end end
end
local function hookClick(fname, ownerTable)
  local owner = ownerTable or _G
  if not (hooksecurefunc and owner and type(owner[fname]) == "function") then return false end
  local ok = pcall(hooksecurefunc, owner, fname, function(self, button, ...)
    if not on() or (RG.db and RG.db.questClick == false) then return end
    if button and button ~= "LeftButton" then return end
    if modifier() then return end
    local id = questIdOf(self) or (type(self) == "table" and self.block and questIdOf(self.block))
    if id then pcall(RG.QuestArrow, id) end
  end)
  return ok
end
local function hookQuestFrames()
  -- every name the game has used for these over the years; the ones that do not exist here are simply skipped
  hookClick("QuestLogTitleButton_OnClick")
  hookClick("QuestMapLogTitleButton_OnClick")
  hookClick("QuestLogQuests_OnClick")
  hookClick("WatchFrameLinkButtonTemplate_OnClick")
  hookClick("QuestObjectiveTracker_OnOpenDropDown")
  if QUEST_TRACKER_MODULE and QUEST_TRACKER_MODULE.OnBlockHeaderClick then
    pcall(hooksecurefunc, QUEST_TRACKER_MODULE, "OnBlockHeaderClick", function(_, block, button)
      if not on() or (RG.db and RG.db.questClick == false) or (button and button ~= "LeftButton") or modifier() then return end
      local id = block and (block.id or block.questID)
      if type(id) == "number" then pcall(RG.QuestArrow, id) end
    end)
  end
end

-- ---------------------------------------------------------------------------
-- World map: small clickable markers for what you could go to on this map
-- ---------------------------------------------------------------------------
local pins, cache = {}, {}
local KIND = {
  turnin = { "?", 1.0, 0.82, 0.15, "Hand in" },
  obj = { "...", 0.93, 0.78, 0.42, "Objective" },   -- the same gold "..." bubble the quest log uses
}
local function canvas()
  local m = WorldMapFrame
  if not m then return nil end
  if m.GetCanvas then local ok, c = pcall(m.GetCanvas, m); if ok and c then return c end end
  return m.ScrollContainer and m.ScrollContainer.Child or nil
end
local function getPin(i)
  if pins[i] then return pins[i] end
  local c = canvas()
  if not c then return nil end
  local b = CreateFrame("Button", nil, c)
  b:SetSize(22, 22); b:SetFrameStrata("HIGH"); b:SetFrameLevel((c.GetFrameLevel and c:GetFrameLevel() or 1) + 40)
  b.disc = b:CreateTexture(nil, "ARTWORK"); b.disc:SetTexture("Interface\\AddOns\\Waypath\\Media\\Disc"); b.disc:SetAllPoints(b)
  b.ring = b:CreateTexture(nil, "OVERLAY"); b.ring:SetTexture("Interface\\AddOns\\Waypath\\Media\\Ring"); b.ring:SetAllPoints(b); b.ring:SetVertexColor(0.1, 0.08, 0.04, 1)
  b.t = b:CreateFontString(nil, "OVERLAY"); b.t:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE"); b.t:SetPoint("CENTER", 0, 0)
  b.dots = {}
  for d = 1, 3 do local t = b:CreateTexture(nil, "OVERLAY", nil, 2); t:SetColorTexture(0.16, 0.09, 0.03, 1); b.dots[d] = t end
  b.arrow = b:CreateTexture(nil, "OVERLAY"); b.arrow:SetTexture("Interface\\AddOns\\Waypath\\Media\\Ring"); b.arrow:SetSize(32, 32); b.arrow:SetPoint("CENTER"); b.arrow:SetVertexColor(1, 0.82, 0.2, 1); b.arrow:Hide()
  b:RegisterForClicks("LeftButtonUp")
  b:SetScript("OnClick", function(self) if self.wp and RG.ArrowTo then RG.ArrowTo(self.wp) end end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.title or "", 1, 1, 1)
    if self.sub and self.sub ~= "" then GameTooltip:AddLine(self.sub, 0.8, 0.8, 0.8, true) end
    GameTooltip:AddLine("|cfff5d273Click:|r arrow on / off", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  pins[i] = b
  return b
end

local lastKey
local function refreshPins(force)
  local m = WorldMapFrame
  if not (m and m.IsShown and m:IsShown() and m.GetMapID) then return end
  local mapID = m:GetMapID()
  local c = canvas()
  if not (mapID and c and c.GetWidth) then return end
  local w, h = c:GetWidth(), c:GetHeight()
  local scale = (m.GetCanvasScale and m:GetCanvasScale()) or 1
  if scale <= 0 then scale = 1 end
  local key = table.concat({ mapID, math.floor(w), math.floor(h), math.floor(scale * 100), cache.logVersion or 0, cache.arrowKey or "" }, ":")
  if not force and key == lastKey then return end
  lastKey = key
  local list = {}
  if on() then
    for _, sp in ipairs(RG.QuestSpots and RG.QuestSpots() or {}) do
      if sp.wp and sp.wp[1] == mapID then list[#list + 1] = { kind = sp.turnin and "turnin" or "obj", wp = sp.wp, title = sp.quest, sub = sp.label or "" } end
    end
  end
  local n = 0
  for _, p in ipairs(list) do
    if n >= 80 then break end
    n = n + 1
    local b = getPin(n)
    if not b then return end
    local k = KIND[p.kind]
    b.wp, b.title, b.sub = p.wp, (k[5] .. ": " .. (p.title or "")), p.sub
    b.disc:SetVertexColor(k[2], k[3], k[4], 1); b.t:SetTextColor(0.1, 0.07, 0.02)
    local sz = 22 / scale
    local dots = k[1] == "..."
    b.t:SetText(dots and "" or k[1])
    for d, t in ipairs(b.dots) do t:SetShown(dots); t:SetSize(sz * 0.14, sz * 0.14); t:ClearAllPoints(); t:SetPoint("CENTER", b, "CENTER", (d - 2) * sz * 0.23, -sz * 0.02) end
    b:SetSize(sz, sz); b.arrow:SetSize(sz * 1.5, sz * 1.5)
    b:ClearAllPoints(); b:SetPoint("CENTER", c, "TOPLEFT", p.wp[2] / 100 * w, -p.wp[3] / 100 * h)
    b.arrow:SetShown(RG.ArrowTarget and RG.ArrowTarget(p.wp) or false)
    b:Show()
  end
  for i = n + 1, #pins do pins[i]:Hide() end
end

local function hookMap()
  if not WorldMapFrame then return end
  -- Ctrl+click anywhere on the map: arrow to that spot
  local sc = WorldMapFrame.ScrollContainer
  if sc and sc.HookScript and sc.GetNormalizedCursorPosition then
    sc:HookScript("OnMouseUp", function(self, button)
      if button ~= "LeftButton" or not (IsControlKeyDown and IsControlKeyDown()) or not on() then return end
      local x, y = self:GetNormalizedCursorPosition()
      local mapID = WorldMapFrame:GetMapID()
      if mapID and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 and RG.PinWaypoint then
        if not RG.Opt("arrow") then RG.db.arrow = true end
        RG.PinWaypoint({ mapID, x * 100, y * 100, "Your map point" })
      end
    end)
  end
  WorldMapFrame:HookScript("OnShow", function() lastKey = nil; refreshPins(true) end)
  WorldMapFrame:HookScript("OnHide", function() for _, p in ipairs(pins) do p:Hide() end end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("QUEST_ACCEPTED")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("ADDON_LOADED")
local hooked
f:SetScript("OnEvent", function(_, ev, a1)
  if ev == "PLAYER_LOGIN" or (ev == "ADDON_LOADED" and (a1 == "Blizzard_WorldMap" or a1 == "Blizzard_QuestLog" or a1 == "Blizzard_ObjectiveTracker")) then
    if WorldMapFrame and not hooked then hooked = true; pcall(hookMap) end
    pcall(hookQuestFrames)
  else
    cache.logVersion = (cache.logVersion or 0) + 1
  end
end)
local acc = 0
f:SetScript("OnUpdate", function(_, dt)
  acc = acc + (dt or 0)
  if acc < 0.4 then return end
  acc = 0
  if WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown() then
    -- the arrow marker follows the current target
    local k = RG.PinIsOurs and RG.PinIsOurs() and "o" or "n"
    if RG.HasPin and RG.HasPin() then k = k .. "p" end
    cache.arrowKey = k
    pcall(refreshPins)
  end
end)

SLASH_WAYPATHMAP1 = "/wpmap"
SlashCmdList.WAYPATHMAP = function(msg)
  local m = (msg or ""):lower()
  if m == "off" then RG.db.mapPins = false; RG.Print("Map markers off.")
  elseif m == "on" then RG.db.mapPins = true; RG.Print("Map markers on.")
  elseif m == "quests" then RG.db.questClick = RG.db.questClick == false; RG.Print("Clicking a quest in the game's log points the arrow: " .. (RG.db.questClick == false and "off." or "on."))
  else RG.Print("/wpmap on|off  (markers on the world map)  ·  /wpmap quests  (arrow when you click a quest in the quest log)") end
  lastKey = nil; refreshPins(true)
end
