-- Waypath+ immersive fishing: when you cast Fishing, the whole interface fades
-- away and only the fishing HUD (FishHUD.lua) stays. Moving, a fight, Esc,
-- opening chat or ~25 seconds without a cast bring everything back.
-- This file also keeps what the HUD shows about your cast: the cast timer,
-- "got away", what you just caught and a whisper that came in.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
local ORANGE = "|cffff8040"

table.insert(RG.OPTIONS, { key = "fishImmersive", label = "Immersive fishing: hide the interface while I fish (move, Esc or Enter brings it back)", default = true })

local FISHING_IDS = { [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true, [51294] = true, [131474] = true }
local function secret(v) return RG.IsSecret and RG.IsSecret(v) end
local function isFishing(spellID)
  if secret(spellID) then return false end
  if spellID and FISHING_IDS[spellID] then return true end
  local ok, name = pcall(function()
    if C_Spell and C_Spell.GetSpellInfo then local i = C_Spell.GetSpellInfo(spellID); return i and i.name end
    return GetSpellInfo and GetSpellInfo(spellID)
  end)
  return ok and name == "Fishing"
end

local IDLE_EXIT = 25        -- seconds without a cast before the interface comes back
local FADE = 0.6            -- seconds to fade in or out
local active, peeking = false, false
local lastActivity, castStart, castEnd, lootedAt
local status, statusColor, statusAt
local feed = {}             -- { text, t }
local whisper, whisperAt

-- ---------------------------------------------------------------------------
-- The fade (the display itself is the fishing HUD, FishHUD.lua: it sits on the game world, so it stays when the
-- interface fades)
-- ---------------------------------------------------------------------------
local fader
local function fadeTo(target)
  if not fader then fader = CreateFrame("Frame", nil, WorldFrame or UIParent) end
  local from = UIParent and UIParent:GetAlpha() or 1
  local t = 0
  fader:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    local p = math.min(1, t / FADE)
    if UIParent then UIParent:SetAlpha(from + ((target and 0 or 1) - from) * p) end
    if p >= 1 then self:SetScript("OnUpdate", nil) end
  end)
end

function RG.FishModeActive() return active end

local function setStatus(text, color) status, statusColor, statusAt = text, color, GetTime() end

-- What the HUD shows: the cast, what just happened, your catches and a whisper while the interface is hidden.
-- engaged: you cast in the last IDLE_EXIT seconds (or your line is in the water).
function RG.FishModeInfo()
  local now = GetTime()
  if whisper and now - (whisperAt or 0) > 30 then whisper = nil end
  local casting = castStart and castEnd and now < castEnd
  return { active = active, peeking = peeking, castStart = casting and castStart or nil, castEnd = casting and castEnd or nil,
    status = (status and now - (statusAt or 0) < 8) and status or nil, statusColor = statusColor, feed = feed, whisper = whisper,
    engaged = casting or (lastActivity and now - lastActivity < IDLE_EXIT) or false }
end

-- (the HUD calls this a few times a second) nothing cast for a while: give the interface back
function RG.FishModeRefresh()
  local now = GetTime()
  if active and not peeking and lastActivity and now - lastActivity > IDLE_EXIT and not (castEnd and now < castEnd) then RG.FishModeExit() end
end

function RG.FishModeEnter()
  lastActivity = GetTime()
  if not RG.Opt("fishImmersive") or (RG.IsAlt and RG.IsAlt()) then return end
  if InCombatLockdown and InCombatLockdown() then return end
  if active and not peeking then return end
  active, peeking = true, false
  whisper = nil
  fadeTo(true)
end
function RG.FishModeExit()
  if not active then return end
  active, peeking = false, false
  whisper = nil
  fadeTo(false)
end
-- show the interface for a moment (a loot window you need to click), stay in fishing mode
local function peek()
  if not active or peeking then return end
  peeking = true
  if fader then fader:SetScript("OnUpdate", nil) end
  if UIParent then UIParent:SetAlpha(1) end
end
local function unpeek()
  if not (active and peeking) then return end
  peeking = false
  fadeTo(true)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "LOOT_OPENED", "LOOT_CLOSED", "PLAYER_STARTED_MOVING",
  "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "PLAYER_DEAD" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
  if event == "UNIT_SPELLCAST_CHANNEL_START" then
    if a1 ~= "player" or not isFishing(a3) then return end
    RG.FishModeEnter()
    local now = GetTime()
    castStart, castEnd = now, now + 21
    if UnitChannelInfo then
      local ok, _, _, _, startMS, endMS = pcall(UnitChannelInfo, "player")
      if ok and startMS and endMS and not secret(startMS) and not secret(endMS) and endMS > startMS then castStart, castEnd = startMS / 1000, endMS / 1000 end
    end
    status = nil
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    if a1 ~= "player" or not isFishing(a3) then return end
    local ended = GetTime()
    castStart, castEnd, lastActivity = nil, nil, ended
    C_Timer.After(1.2, function()
      if not (lootedAt and lootedAt >= ended - 0.5) and not castEnd then setStatus("Got away: cast again", ORANGE) end
    end)
  elseif event == "LOOT_OPENED" then
    lootedAt = GetTime()
    if not (IsFishingLoot and IsFishingLoot()) then return end
    lastActivity = GetTime()
    local names = {}
    for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
      local ok, icon, name, qty, _, quality = pcall(GetLootSlotInfo, i)
      if ok and name and not secret(name) then
        local c = ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality]
        local col = (c and c.hex) or "|cffffffff"
        local text = (icon and not secret(icon) and ("|T" .. icon .. ":14:14|t ") or "") .. col .. name .. "|r" .. ((qty and not secret(qty) and qty > 1) and (GREY .. " x" .. qty .. "|r") or "")
        local lootLink = GetLootSlotLink and GetLootSlotLink(i)
        local lootId = lootLink and tonumber(lootLink:match("item:(%d+)"))
        local advice = lootId and RG.FishAdvice and RG.FishAdvice(lootId)
        if advice then text = text .. GREY .. "  ·  |r" .. advice end
        table.insert(feed, 1, { text = text, t = GetTime() }); feed[4] = nil
        names[#names + 1] = name
      end
    end
    setStatus(#names > 0 and ("Caught " .. names[1]) or "Caught!", GREEN)
    -- auto loot handles it; otherwise show the loot window so you can click it
    local auto = a1
    if auto == nil and GetCVarBool then
      auto = GetCVarBool("autoLootDefault")
      if IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") then auto = not auto end
    end
    if not auto and active then peek() end
  elseif event == "LOOT_CLOSED" then
    if active and peeking then unpeek() end
  elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
    if active then whisperAt = GetTime(); whisper = (not secret(a2) and type(a2) == "string" and (a2:match("^[^-]+") or a2)) or "someone" end
  elseif event == "PLAYER_STARTED_MOVING" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_DEAD" then
    RG.FishModeExit()
    if event ~= "PLAYER_STARTED_MOVING" then castStart, castEnd = nil, nil end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGOUT" then
    if active then active = false; if UIParent then UIParent:SetAlpha(1) end end
  end
end)
-- Esc (game menu) and Enter (chat) bring the interface back
if GameMenuFrame and GameMenuFrame.HookScript then GameMenuFrame:HookScript("OnShow", function() RG.FishModeExit() end) end
if hooksecurefunc and ChatEdit_ActivateChat then pcall(hooksecurefunc, "ChatEdit_ActivateChat", function() RG.FishModeExit() end) end
if hooksecurefunc and ChatFrameUtil and ChatFrameUtil.ActivateChat then pcall(hooksecurefunc, ChatFrameUtil, "ActivateChat", function() RG.FishModeExit() end) end

-- /wp fishmode: turn it on or off
local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  if cmd and cmd:lower() == "fishmode" then
    RG.db.fishImmersive = not RG.Opt("fishImmersive")
    if not RG.db.fishImmersive then RG.FishModeExit() end
    RG.Print("Immersive fishing " .. (RG.db.fishImmersive and (GREEN .. "on|r: the interface fades when you cast Fishing.") or "off."))
    return
  end
  return base(msg)
end
