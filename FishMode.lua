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
-- ---------------------------------------------------------------------------
-- Frames that stay while the rest fades (other add-ons' meters, say a catch-percentage bar). The fade is UIParent's
-- alpha, so a frame under it fades with it; SetIgnoreParentAlpha lets a chosen frame keep its own. Only frames that
-- aren't protected, and only the alpha: nothing is hidden or moved, and no game global is written.
-- ---------------------------------------------------------------------------
local kept = {}   -- frames we set, so they go back the way they were
local function keepList() return (RG.db and RG.db.fishKeep) or {} end
local function keepApply(on)
  if on then
    for name in pairs(keepList()) do
      local f = _G[name]
      if type(f) == "table" and f.SetIgnoreParentAlpha and not kept[f] and not (f.IsProtected and f:IsProtected()) then
        if pcall(f.SetIgnoreParentAlpha, f, true) then kept[f] = true end
      end
    end
  else
    for f in pairs(kept) do pcall(f.SetIgnoreParentAlpha, f, false); kept[f] = nil end
  end
end
-- the frame under the mouse: the highest named frame below UIParent (what the add-on called its meter)
local function frameUnderMouse()
  local f
  if GetMouseFoci then local t = GetMouseFoci(); f = t and t[1] elseif GetMouseFocus then f = GetMouseFocus() end
  local pick
  while f and f ~= UIParent and f ~= WorldFrame do
    local ok, name = pcall(f.GetName, f)
    if ok and name and name ~= "" then pick = name end
    f = f.GetParent and f:GetParent() or nil
  end
  return pick
end

local fader
local function fadeTo(target)
  if not fader then fader = CreateFrame("Frame", nil, WorldFrame or UIParent) end
  local from = UIParent and UIParent:GetAlpha() or 1
  if target and RG.db then RG.db.fishFaded = true end   -- (remembered, so a fade left behind by a /reload is given back)
  keepApply(target)
  local t = 0
  fader:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    local p = math.min(1, t / FADE)
    if UIParent then UIParent:SetAlpha(from + ((target and 0 or 1) - from) * p) end
    if p >= 1 then self:SetScript("OnUpdate", nil) end
  end)
end

-- the interface back at full strength, whatever state we're in
local function restoreUI()
  if not (RG.db and RG.db.fishFaded) then return end   -- only a fade that was ours
  if UIParent and (UIParent:GetAlpha() or 1) < 1 then UIParent:SetAlpha(1) end
  keepApply(false)
  if not (fader and fader:GetScript("OnUpdate")) then RG.db.fishFaded = nil end
end
RG.FishModeRestoreUI = restoreUI

-- the rescue: the interface back at full strength right now, whatever state anything is in
function RG.FishModeRescue()
  active, peeking, whisper = false, false, nil
  if fader then fader:SetScript("OnUpdate", nil) end
  if UIParent then UIParent:SetAlpha(1) end
  keepApply(false)
  if RG.db then RG.db.fishFaded = nil end
  if RG.FishHUDRefresh then pcall(RG.FishHUDRefresh, true) end
end

function RG.FishModeActive() return active end

local function setStatus(text, color) status, statusColor, statusAt = text, color, GetTime() end

-- What the HUD shows: the cast, what just happened, your catches and a whisper while the interface is hidden.
-- engaged: you cast in the last IDLE_EXIT seconds (or your line is in the water).
-- (the cast timer's two numbers without building a table: the HUD asks every frame while it animates)
function RG.FishModeCast()
  if castStart and castEnd and GetTime() < castEnd then return castStart, castEnd end
end
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
    if active then active = false end
    -- (the fade is the game's own interface alpha, and it survives a /reload: always give it back, even when this
    -- session never faded it, so a fade left behind by the last one can't leave you with no interface)
    if fader then fader:SetScript("OnUpdate", nil) end
    restoreUI()
  end
end)
-- every half second, whether or not the fishing HUD is on screen: the option turned off (in Settings or by a command) gives
-- the interface back, and so does a long wait without a cast (the HUD's own refresh only runs while the HUD is shown)
local function tick()
  if active and not RG.Opt("fishImmersive") then RG.FishModeExit() end
  pcall(RG.FishModeRefresh)
  if not active and not (fader and fader:GetScript("OnUpdate")) then restoreUI() end
end
tick = RG.PerfWrap("fishMode", tick)
RG.FishModeTick = tick
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(0.5, tick) end
-- (and once now: a fade a previous session left behind)
if C_Timer and C_Timer.After then C_Timer.After(2, restoreUI) end

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
  if cmd and cmd:lower() == "fishkeep" then
    local arg = (msg or ""):match("^%s*%S+%s+(%S+)")
    RG.db.fishKeep = RG.db.fishKeep or {}
    if arg and arg:lower() == "clear" then
      RG.db.fishKeep = {}; keepApply(false)
      RG.Print("Fishing mode keeps no other frames visible now.")
    elseif arg and arg:lower() == "list" then
      local names = {}
      for n in pairs(RG.db.fishKeep) do names[#names + 1] = n end
      table.sort(names)
      RG.Print(#names > 0 and ("Kept visible while you fish: " .. table.concat(names, ", ")) or "No frames kept yet. Point at one and type /wp fishkeep.")
    else
      -- /wp fishkeep <FrameName>, or just /wp fishkeep with the mouse over the frame; the same again takes it off
      local name = arg or frameUnderMouse()
      local f = name and _G[name]
      if not name then
        RG.Print("Point the mouse at the frame to keep (another add-on's meter, say) and type /wp fishkeep, or give its name: /wp fishkeep <FrameName>. /wp fishkeep list, /wp fishkeep clear.")
      elseif type(f) ~= "table" or not f.SetIgnoreParentAlpha then
        RG.Print("There's no frame called " .. name .. ".")
      elseif f.IsProtected and f:IsProtected() then
        RG.Print(name .. " is part of the game's own protected interface and can't be kept visible.")
      elseif RG.db.fishKeep[name] then
        RG.db.fishKeep[name] = nil; if f.SetIgnoreParentAlpha then pcall(f.SetIgnoreParentAlpha, f, false); kept[f] = nil end
        RG.Print(name .. " will fade with the rest again.")
      else
        RG.db.fishKeep[name] = true
        RG.Print(GREEN .. name .. "|r will stay visible while you fish. /wp fishkeep list shows them all.")
      end
    end
    return
  end
  if cmd and (cmd:lower() == "showui" or cmd:lower() == "restoreui") then
    RG.FishModeRescue()
    RG.Print("Interface restored.")
    return
  end
  return base(msg)
end
