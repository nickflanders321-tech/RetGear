-- Waypath+ immersive fishing: when you cast Fishing, the whole interface fades
-- away and a small fishing display stays near the bottom of the screen:
-- your skill, a cast timer, the session so far and what you just caught.
-- Moving, a fight, Esc, opening chat or ~25 seconds without a cast bring
-- everything back. The display sits on the game world (not the interface),
-- so it stays when the rest fades, and it never takes mouse clicks, so
-- clicking your bobber always works.
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
-- Display
-- ---------------------------------------------------------------------------
local hud, fader, refreshFailed
local function font(fs, size, flags) RG.Font(fs, "semibold", size, flags); fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1) end
local function build()
  if hud then return end
  local parent = WorldFrame or UIParent
  hud = CreateFrame("Frame", "WaypathFishHUD", parent)
  hud:SetSize(340, 120); hud:SetPoint("BOTTOM", parent, "BOTTOM", 0, 120)
  hud:SetFrameStrata("HIGH"); hud:EnableMouse(false)
  hud:SetAlpha(0); hud:Hide()
  -- soft dark band behind the text so it reads on any water
  hud.bg = hud:CreateTexture(nil, "BACKGROUND"); hud.bg:SetPoint("TOPLEFT", -40, 10); hud.bg:SetPoint("BOTTOMRIGHT", 40, -10)
  hud.bg:SetColorTexture(0, 0, 0, 0.35)
  if hud.bg.SetGradient and CreateColor then
    pcall(hud.bg.SetGradient, hud.bg, "HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.45))
  end
  hud.title = hud:CreateFontString(nil, "OVERLAY"); font(hud.title, 15, "OUTLINE"); hud.title:SetPoint("TOP", 0, 0)
  -- cast timer
  hud.barBg = hud:CreateTexture(nil, "ARTWORK"); hud.barBg:SetSize(220, 4); hud.barBg:SetPoint("TOP", hud.title, "BOTTOM", 0, -6); hud.barBg:SetColorTexture(1, 1, 1, 0.12)
  hud.bar = hud:CreateTexture(nil, "OVERLAY"); hud.bar:SetHeight(4); hud.bar:SetPoint("LEFT", hud.barBg, "LEFT", 0, 0); hud.bar:SetColorTexture(0.35, 0.75, 1, 0.9); hud.bar:SetWidth(1)
  hud.status = hud:CreateFontString(nil, "OVERLAY"); font(hud.status, 13); hud.status:SetPoint("TOP", hud.barBg, "BOTTOM", 0, -6)
  hud.stats = hud:CreateFontString(nil, "OVERLAY"); font(hud.stats, 11); hud.stats:SetPoint("TOP", hud.status, "BOTTOM", 0, -5)
  hud.feed = {}
  for i = 1, 3 do
    local f = hud:CreateFontString(nil, "OVERLAY"); font(f, 11)
    f:SetPoint("TOP", i == 1 and hud.stats or hud.feed[i - 1], "BOTTOM", 0, i == 1 and -6 or -2)
    hud.feed[i] = f
  end
  hud.hint = hud:CreateFontString(nil, "OVERLAY"); font(hud.hint, 9); hud.hint:SetPoint("BOTTOM", hud, "BOTTOM", 0, -6)
  hud.hint:SetText(GREY .. "Move, Esc or Enter brings your interface back|r")
  local acc = 0
  hud:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    -- cast timer runs smoothly; the text refreshes four times a second
    if castStart and castEnd and castEnd > castStart then
      local now = GetTime()
      local left = math.max(0, castEnd - now)
      self.bar:SetWidth(math.max(1, 220 * left / (castEnd - castStart)))
      self.bar:Show()
    else self.bar:Hide() end
    -- a failed refresh is logged once (/wp errors) and never blanks the display again
    if acc >= 0.25 then
      acc = 0
      local ok, err = pcall(RG.FishModeRefresh)
      if not ok and not refreshFailed then refreshFailed = true; if RG.RecordError then RG.RecordError(err) end end
    end
  end)
end

-- The Cast button: your action bars fade with the rest of the interface, so
-- the display brings its own. It's a secure spell button (a real click casts
-- Fishing), kept on the game world like the display. Shown and hidden only
-- out of combat, as the game requires for buttons that cast.
local castBtn
local function buildCast()
  if castBtn or not CreateFrame then return castBtn end
  local ok, b = pcall(CreateFrame, "Button", "WaypathFishCast", WorldFrame or UIParent, "SecureActionButtonTemplate")
  if not ok or not b then return nil end
  castBtn = b
  b:SetSize(52, 52); b:SetPoint("BOTTOM", WorldFrame or UIParent, "BOTTOM", 0, 52)
  b:SetFrameStrata("HIGH")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "spell"); b:SetAttribute("spell", "Fishing")
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexture("Interface\\Icons\\Trade_Fishing"); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.edge = b:CreateTexture(nil, "BACKGROUND"); b.edge:SetPoint("TOPLEFT", -2, 2); b.edge:SetPoint("BOTTOMRIGHT", 2, -2); b.edge:SetColorTexture(0.83, 0.71, 0.42, 0.9)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.18)
  b.label = b:CreateFontString(nil, "OVERLAY"); font(b.label, 12, "OUTLINE"); b.label:SetPoint("TOP", b, "BOTTOM", 0, -4); b.label:SetText(GOLD .. "Cast|r")
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Cast Fishing", 1, 1, 1)
    GameTooltip:AddLine("Click to cast. Your usual Fishing key still works too.", 0.7, 0.7, 0.7, true); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:SetAlpha(0); b:Hide()
  return b
end
local function showCast(on)
  if InCombatLockdown and InCombatLockdown() then return end
  local b = buildCast()
  if not b then return end
  if on then b:Show() else b:Hide() end
end
RG.FishCastButton = function() return castBtn end

-- UIParent fades out while the display fades in (and back), on one timer
local function fadeTo(target)
  build()
  if not fader then fader = CreateFrame("Frame", nil, WorldFrame or UIParent) end
  local from = UIParent and UIParent:GetAlpha() or 1
  local hudFrom = hud:GetAlpha() or 0
  local t = 0
  hud:Show()
  fader:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    local p = math.min(1, t / FADE)
    if UIParent then UIParent:SetAlpha(from + ((target and 0 or 1) - from) * p) end
    hud:SetAlpha(hudFrom + ((target and 1 or 0) - hudFrom) * p)
    if castBtn and castBtn:IsShown() then castBtn:SetAlpha(hud:GetAlpha() or 1) end
    if p >= 1 then
      self:SetScript("OnUpdate", nil)
      if not target then hud:Hide() end
    end
  end)
end

function RG.FishModeActive() return active end

local function setStatus(text, color) status, statusColor, statusAt = text, color, GetTime() end

function RG.FishModeRefresh()
  if not hud then return end
  local skill, max
  if RG.FishSkill then skill, max = RG.FishSkill() end
  local title = GOLD .. "Fishing|r"
  if skill then title = title .. "  |cffffffff" .. skill .. "|r" .. ((max and max > 0) and (GREY .. " / " .. max .. "|r") or "") end
  local s = RG.FishSession and RG.FishSession()
  if s and s.gained and s.gained > 0 then title = title .. GREEN .. "  +" .. s.gained .. "|r" end
  hud.title:SetText(title)
  -- what's happening now
  local now = GetTime()
  local st
  if whisper and now - (whisperAt or 0) > 30 then whisper = nil end
  if whisper then st = "|cffff80ffWhisper from " .. whisper .. "|r" .. GREY .. ": press Enter to read|r"
  elseif castStart and castEnd and now < castEnd then st = "|cffffffffWatch your bobber|r" .. GREY .. "  ·  " .. math.ceil(castEnd - now) .. "s|r"
  elseif status and now - (statusAt or 0) < 8 then st = (statusColor or "|cffffffff") .. status .. "|r"
  else st = GREY .. "Cast when you're ready|r" end
  hud.status:SetText(st)
  -- session, lure and zone on one line
  local parts = {}
  if s and s.catches > 0 then parts[#parts + 1] = "|cffffffff" .. s.catches .. " fish|r" .. (s.perHour and (GREY .. " (" .. s.perHour .. "/hr)|r") or "") end
  local lure = RG.FishLure and RG.FishLure()
  if lure then parts[#parts + 1] = (lure < 60 and ORANGE or GREY) .. "lure " .. math.ceil(lure / 60) .. " min|r" end
  local z = RG.FishZone and RG.FishZone()
  if z then
    if z.status == "all" then parts[#parts + 1] = GREEN .. "every fish bites|r"
    elseif z.status == "some" then parts[#parts + 1] = ORANGE .. "some get away|r"
    else parts[#parts + 1] = "|cffff4040too low here|r" end
  end
  if skill and max and skill >= max and max < 300 then parts[#parts + 1] = ORANGE .. "capped: train|r" end
  hud.stats:SetText(table.concat(parts, GREY .. "  ·  |r"))
  -- last catches, fading after a while
  for i = 1, 3 do
    local e = feed[i]
    local age = e and (now - e.t)
    if e and age < 20 then
      hud.feed[i]:SetText(e.text); hud.feed[i]:SetAlpha(age < 14 and 1 or math.max(0, 1 - (age - 14) / 6)); hud.feed[i]:Show()
    else hud.feed[i]:Hide() end
  end
  -- nothing cast for a while: give the interface back
  if active and not peeking and lastActivity and now - lastActivity > IDLE_EXIT and not (castEnd and now < castEnd) then RG.FishModeExit() end
end

function RG.FishModeEnter()
  if not RG.Opt("fishImmersive") or (RG.IsAlt and RG.IsAlt()) then return end
  if InCombatLockdown and InCombatLockdown() then return end
  lastActivity = GetTime()
  if active and not peeking then return end
  active, peeking = true, false
  whisper = nil
  showCast(true)
  fadeTo(true)
end
function RG.FishModeExit()
  if not active then return end
  active, peeking = false, false
  castStart, castEnd, whisper = nil, nil, nil
  showCast(false)
  fadeTo(false)
end
-- show the interface for a moment (a loot window you need to click), stay in fishing mode
local function peek()
  if not active or peeking then return end
  peeking = true
  build()
  if fader then fader:SetScript("OnUpdate", nil) end
  if UIParent then UIParent:SetAlpha(1) end
  hud:Show(); hud:SetAlpha(1)
  if castBtn then castBtn:SetAlpha(1) end
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
    if not active then return end
    local now = GetTime()
    castStart, castEnd = now, now + 21
    if UnitChannelInfo then
      local ok, _, _, _, startMS, endMS = pcall(UnitChannelInfo, "player")
      if ok and startMS and endMS and not secret(startMS) and not secret(endMS) and endMS > startMS then castStart, castEnd = startMS / 1000, endMS / 1000 end
    end
    status = nil
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    if a1 ~= "player" or not isFishing(a3) or not active then return end
    local ended = GetTime()
    castStart, castEnd, lastActivity = nil, nil, ended
    C_Timer.After(1.2, function()
      if active and not (lootedAt and lootedAt >= ended - 0.5) and not castEnd then setStatus("Got away: cast again", ORANGE) end
    end)
  elseif event == "LOOT_OPENED" then
    lootedAt = GetTime()
    if not active or not (IsFishingLoot and IsFishingLoot()) then return end
    lastActivity = GetTime()
    local names = {}
    for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
      local ok, icon, name, qty, _, quality = pcall(GetLootSlotInfo, i)
      if ok and name and not secret(name) then
        local c = ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality]
        local col = (c and c.hex) or "|cffffffff"
        local text = (icon and not secret(icon) and ("|T" .. icon .. ":14:14|t ") or "") .. col .. name .. "|r" .. ((qty and not secret(qty) and qty > 1) and (GREY .. " x" .. qty .. "|r") or "")
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
    if not auto then peek() end
  elseif event == "LOOT_CLOSED" then
    if active and peeking then unpeek() end
  elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
    if active then whisperAt = GetTime(); whisper = (not secret(a2) and type(a2) == "string" and (a2:match("^[^-]+") or a2)) or "someone" end
  elseif event == "PLAYER_STARTED_MOVING" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_DEAD" then
    RG.FishModeExit()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGOUT" then
    if active then active = false; if UIParent then UIParent:SetAlpha(1) end; if hud then hud:Hide() end; showCast(false) end
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
