-- Waypath+ movers: our pop-up alerts can be placed wherever you like.
--   Open the game's Edit Mode (or type /wp move) and each alert shows a sample with a green outline and its name:
--   drag it where you want it, right-click it to put it back. Leave Edit Mode (or /wp move again) to finish.
--   Only our own frames are moved; Blizzard's Edit Mode is only watched (HookScript), never changed.
local _, RG = ...

local movers, on = {}, false
local function pos() RG.db.movers = RG.db.movers or {}; return RG.db.movers end

local function place(m)
  local p = RG.db and pos()[m.key] or m.default
  m.frame:ClearAllPoints()
  m.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function overlay(m)
  if m.ov then return m.ov end
  local f = m.frame
  local ov = CreateFrame("Button", nil, f)
  ov:SetAllPoints(f); ov:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
  ov.bg = ov:CreateTexture(nil, "OVERLAY"); ov.bg:SetAllPoints(); ov.bg:SetColorTexture(0.25, 0.85, 0.45, 0.16)
  for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
    local l = ov:CreateTexture(nil, "OVERLAY"); l:SetHeight(1); l:SetPoint(side[1]); l:SetPoint(side[2]); l:SetColorTexture(0.4, 1, 0.55, 0.9)
  end
  for _, side in ipairs({ { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
    local l = ov:CreateTexture(nil, "OVERLAY"); l:SetWidth(1); l:SetPoint(side[1]); l:SetPoint(side[2]); l:SetColorTexture(0.4, 1, 0.55, 0.9)
  end
  ov.name = ov:CreateFontString(nil, "OVERLAY"); RG.Font(ov.name, "semibold", 11); ov.name:SetPoint("BOTTOM", ov, "TOP", 0, 3)
  ov.name:SetTextColor(0.55, 1, 0.65); ov.name:SetShadowColor(0, 0, 0, 1); ov.name:SetShadowOffset(1, -1)
  ov.name:SetText("Waypath+: " .. m.label)
  ov:RegisterForDrag("LeftButton"); ov:RegisterForClicks("RightButtonUp")
  ov:SetScript("OnDragStart", function() f:SetMovable(true); f:StartMoving() end)
  ov:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    -- (kept by its centre, relative to the middle of the screen: the same spot at any screen size)
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local s, us = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if cx and ux then
      local x, y = cx * s / us - ux, cy * s / us - uy
      pos()[m.key] = { "CENTER", "CENTER", math.floor(x + 0.5), math.floor(y + 0.5) }
      place(m)
    end
  end)
  ov:SetScript("OnClick", function() pos()[m.key] = nil; place(m) end)
  ov:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Waypath+: " .. m.label, 1, 0.93, 0.74)
    GameTooltip:AddLine("Drag to move  ·  right-click to put it back", 0.85, 0.85, 0.85)
    GameTooltip:Show()
  end)
  ov:SetScript("OnLeave", function() GameTooltip:Hide() end)
  m.ov = ov
  return ov
end

local function show(m)
  m.wasShown = m.frame:IsShown()
  if m.preview then pcall(m.preview, m.frame) end
  m.frame:SetAlpha(1); m.frame:Show()
  overlay(m):Show()
end
local function hide(m)
  if m.ov then m.ov:Hide() end
  if not m.wasShown then m.frame:Hide() end
end

-- frame: ours; key: where its place is saved; label: its name while placing; default: { point, relativePoint, x, y }
-- preview(frame): fill it with a sample while it's being placed
function RG.RegisterMover(frame, key, label, default, preview)
  local m = { frame = frame, key = key, label = label, default = default, preview = preview }
  movers[#movers + 1] = m
  place(m)
  if on then show(m) end
  return m
end
function RG.MoversOn() return on end

-- the alerts made only when first needed: make them now so they can be placed
local makers = {}
function RG.RegisterMoverMaker(fn) makers[#makers + 1] = fn end

function RG.MoveMode(state)
  if state == nil then state = not on end
  if state == on then return end
  if state and InCombatLockdown and InCombatLockdown() then RG.Print("Not during a fight: try again once it's over.") return end
  on = state
  if on then for _, fn in ipairs(makers) do pcall(fn) end end
  for _, m in ipairs(movers) do if on then show(m) else hide(m) end end
  if on and not RG.__moveHint then
    RG.__moveHint = true
    RG.Print("Placing Waypath+ alerts: drag the green boxes, right-click one to put it back. " .. (RG.__editMode and "Close Edit Mode" or "Type /wp move again") .. " when you're done.")
  end
end

-- the alerts that exist: the Exorcism alert (Extras.lua)
RG.RegisterMoverMaker(function() if RG.ExorcismFrame then RG.ExorcismFrame() end end)

-- the game's Edit Mode, when this client has it: follow it in and out
local function hookEdit()
  local em = _G.EditModeManagerFrame
  if not em or RG.__editHooked then return end
  RG.__editHooked = true
  em:HookScript("OnShow", function() RG.__editMode = true; RG.MoveMode(true) end)
  em:HookScript("OnHide", function() RG.MoveMode(false); RG.__editMode = nil end)
end
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then pcall(hookEdit)
  elseif event == "PLAYER_REGEN_DISABLED" and on and not RG.__editMode then RG.MoveMode(false) end   -- (a fight starts: done placing)
end)

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  if cmd and cmd:lower() == "move" then
    local rest = (msg or ""):match("^%s*%S+%s+(%S+)")
    if rest and rest:lower() == "reset" then
      RG.db.movers = nil; for _, m in ipairs(movers) do place(m) end; RG.Print("Waypath+ alerts are back in their usual places.")
    else RG.MoveMode() end
    return
  end
  return base(msg)
end
