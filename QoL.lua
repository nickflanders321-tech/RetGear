-- RetGear quality-of-life: toasts, upgrade pop-ups, level-up banner, vendor
-- helper, paladin and mining reminders, welcome screen and minimap button.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLDC = { 0.83, 0.71, 0.42 }

-- Settings with their defaults. The Settings tab shows these as checkboxes.
RG.OPTIONS = {
  { key = "tracker",      label = "Show the on-screen tracker",            default = true },
  { key = "upgradeToast", label = "Pop up when I get a gear upgrade",       default = true },
  { key = "levelBanner",  label = "Show a banner when I level up",          default = true },
  { key = "sellJunk",     label = "Sell grey junk at vendors",              default = true },
  { key = "autoRepair",   label = "Repair my gear at vendors",              default = true },
  { key = "reminders",    label = "Remind me about Blessings and Seals",    default = true },
  { key = "mineReminder", label = "Remind me to turn on Find Minerals",     default = true },
  { key = "tooltip",      label = "Show Ret scores on item tooltips",       default = true },
  { key = "autoScan",     label = "Check prices when I open the Auction House", default = true },
  { key = "minimap",      label = "Show the minimap button",                default = true },
  { key = "sounds",       label = "Play sounds for pop-ups",                default = true },
}
function RG.Opt(key)
  local v = RetGearDB and RetGearDB[key]
  if v == nil then for _, o in ipairs(RG.OPTIONS) do if o.key == key then return o.default end end end
  return v ~= false
end
local function sound(id) if RG.Opt("sounds") and PlaySound and id then pcall(PlaySound, id) end end
local SND = SOUNDKIT or {}

local function backdrop(f, bg, edge)
  if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropColor(unpack(bg)); f:SetBackdropBorderColor(unpack(edge))
end
RG.Backdrop = backdrop

-- ---------------------------------------------------------------------------
-- Toasts: a golden card near the top of the screen. Stacks up to three.
-- ---------------------------------------------------------------------------
local toasts = {}
local function layoutToasts()
  for i, t in ipairs(toasts) do t:ClearAllPoints(); t:SetPoint("TOP", UIParent, "TOP", 0, -120 - (i - 1) * 96) end
end
function RG.Toast(title, text, icon, button, onButton, seconds)
  local t = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  t:SetSize(380, 84); t:SetFrameStrata("DIALOG")
  backdrop(t, { 0.04, 0.035, 0.03, 0.96 }, { GOLDC[1], GOLDC[2], GOLDC[3], 0.8 })
  local glow = t:CreateTexture(nil, "BACKGROUND", nil, 1); glow:SetPoint("TOPLEFT", 1, -1); glow:SetPoint("BOTTOMRIGHT", -1, 1); glow:SetTexture(WHITE)
  if glow.SetGradient and CreateColor then glow:SetGradient("HORIZONTAL", CreateColor(GOLDC[1], GOLDC[2], GOLDC[3], 0.18), CreateColor(GOLDC[1], GOLDC[2], GOLDC[3], 0)) end
  local ib = t:CreateTexture(nil, "ARTWORK"); ib:SetSize(50, 50); ib:SetPoint("LEFT", 14, 0); ib:SetColorTexture(GOLDC[1], GOLDC[2], GOLDC[3], 0.9)
  local ic = t:CreateTexture(nil, "OVERLAY"); ic:SetPoint("TOPLEFT", ib, 2, -2); ic:SetPoint("BOTTOMRIGHT", ib, -2, 2); ic:SetTexture(icon or "Interface\\Icons\\Spell_Holy_AuraOfLight"); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local h = t:CreateFontString(nil, "OVERLAY"); h:SetFont("Fonts\\MORPHEUS.TTF", 18, ""); h:SetPoint("TOPLEFT", ib, "TOPRIGHT", 12, 0); h:SetTextColor(GOLDC[1], GOLDC[2], GOLDC[3]); h:SetText(title)
  local b = t:CreateFontString(nil, "OVERLAY"); b:SetFont("Fonts\\ARIALN.TTF", 13, ""); b:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -4); b:SetWidth(button and 210 or 290); b:SetJustifyH("LEFT"); b:SetText(text or "")
  local x = CreateFrame("Button", nil, t); x:SetSize(18, 18); x:SetPoint("TOPRIGHT", -6, -6)
  local xt = x:CreateFontString(nil, "OVERLAY"); xt:SetFont("Fonts\\ARIALN.TTF", 14, ""); xt:SetPoint("CENTER"); xt:SetText("x"); xt:SetTextColor(0.6, 0.6, 0.6)
  local function close()
    for i, v in ipairs(toasts) do if v == t then table.remove(toasts, i) break end end
    t:Hide(); layoutToasts()
  end
  x:SetScript("OnClick", close)
  if button then
    local btn = CreateFrame("Button", nil, t, "BackdropTemplate")
    btn:SetSize(84, 26); btn:SetPoint("BOTTOMRIGHT", -12, 12)
    backdrop(btn, { GOLDC[1], GOLDC[2], GOLDC[3], 0.2 }, { GOLDC[1], GOLDC[2], GOLDC[3], 0.8 })
    local bt = btn:CreateFontString(nil, "OVERLAY"); bt:SetFont("Fonts\\FRIZQT__.TTF", 12, ""); bt:SetPoint("CENTER"); bt:SetText(button); bt:SetTextColor(GOLDC[1], GOLDC[2], GOLDC[3])
    btn:SetScript("OnClick", function() if onButton then onButton() end; close() end)
  end
  -- fade in, wait, fade out
  t:SetAlpha(0); t:Show()
  local elapsed, life = 0, seconds or 8
  t:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.3 then self:SetAlpha(elapsed / 0.3)
    elseif self:IsMouseOver() then elapsed = math.min(elapsed, life - 1); self:SetAlpha(1)
    elseif elapsed > life then close()
    elseif elapsed > life - 1 then self:SetAlpha(life - elapsed) else self:SetAlpha(1) end
  end)
  table.insert(toasts, 1, t)
  while #toasts > 3 do toasts[#toasts]:Hide(); table.remove(toasts) end
  layoutToasts()
  return t
end

-- ---------------------------------------------------------------------------
-- Upgrade pop-up when an equippable upgrade lands in your bags
-- ---------------------------------------------------------------------------
local seen, primed = {}, false
local function bagLinks()
  local out = {}
  local C = C_Container
  for bag = 0, 4 do
    local n = (C and C.GetContainerNumSlots or GetContainerNumSlots)(bag) or 0
    for slot = 1, n do
      local link
      if C and C.GetContainerItemInfo then local info = C.GetContainerItemInfo(bag, slot); link = info and info.hyperlink
      elseif GetContainerItemLink then link = GetContainerItemLink(bag, slot) end
      if link then out[#out + 1] = link end
    end
  end
  return out
end
local function checkUpgrades()
  local links = bagLinks()
  if not primed then for _, l in ipairs(links) do seen[l] = true end; primed = true; return end
  for _, link in ipairs(links) do
    if not seen[link] then
      seen[link] = true
      local loc = RG.EquipLoc(link)
      local _, _, _, _, minLevel = RG.ItemInfo(link)
      if loc and RG.EQUIP_SLOTS[loc] and RG.Opt("upgradeToast") and (minLevel or 0) <= UnitLevel("player") then
        local delta = RG.Compare(link)
        if delta and delta >= 5 then
          local icon = select(5, (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(link))
          RG.Toast("Upgrade!", link .. "\n" .. GREEN .. string.format("+%.0f Ret score", delta) .. "|r" .. GREY .. " over what you're wearing|r", icon, "Equip", function()
            if InCombatLockdown() then RG.Print("You can't change gear in combat. Equip it after the fight."); return end
            local equip = (C_Item and C_Item.EquipItemByName) or EquipItemByName
            if equip then equip(link) end
          end, 12)
          sound(SND.UI_EPICLOOT_TOAST or SND.UI_LEGENDARY_LOOT_TOAST or 8959)
        end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Level-up banner
-- ---------------------------------------------------------------------------
local function plural(n) return n == 1 and "1 upgrade" or (n .. " upgrades") end
local function levelBanner(lvl)
  if not RG.Opt("levelBanner") then return end
  local lines = {}
  if lvl % 2 == 0 then lines[#lines + 1] = "Visit your class trainer for new spells." end
  local ups = 0
  for _, g in ipairs(RG.GUIDE) do if g.id and g.lvl == lvl then local d = RG.GuideDelta(g); if d and d > 0.5 then ups = ups + 1 end end end
  if ups > 0 then lines[#lines + 1] = GREEN .. plural(ups) .. "|r now in reach. Check the Gear guide." end
  for _, r in ipairs(RG.ROUTE or {}) do if r.from == lvl and r.kind ~= "pala" then lines[#lines + 1] = "Next: " .. GOLD .. r.zone .. "|r" break end end
  RG.Toast("Level " .. lvl .. "!", table.concat(lines, "\n"), "Interface\\Icons\\Spell_Holy_AuraOfLight", "Open guide", function() if RG.ToggleUI then RG.ToggleUI() end end, 10)
  sound(SND.UI_LEVEL_UP or 888)
end

-- ---------------------------------------------------------------------------
-- Vendor helper: sell junk, repair
-- ---------------------------------------------------------------------------
local function atMerchant()
  local msgs = {}
  if RG.Opt("sellJunk") then
    local before = GetMoney()
    -- Grey items worth more on the AH are left alone, so if any are in your
    -- bags we sell junk one slot at a time instead of using "sell all".
    local skip, kept = {}, 0
    if RG.ProfitSkip then skip = RG.ProfitSkip() end
    for k in pairs(skip) do
      local b, sl = k:match("(%d+):(%d+)")
      local info = C_Container and C_Container.GetContainerItemInfo(tonumber(b), tonumber(sl))
      if info and info.quality == 0 then kept = kept + 1 end
    end
    if kept > 0 then msgs[#msgs + 1] = "kept " .. kept .. " grey item" .. (kept > 1 and "s" or "") .. " worth more on the AH" end
    if kept == 0 and C_MerchantFrame and C_MerchantFrame.SellAllJunkItems then
      C_MerchantFrame.SellAllJunkItems()
      C_Timer.After(1, function() local got = GetMoney() - before; if got > 0 then RG.Print("Sold your junk for " .. RG.Money(got) .. ".") end end)
    else
      local C = C_Container
      local sold, value = 0, 0
      for bag = 0, 4 do
        for slot = 1, ((C and C.GetContainerNumSlots or GetContainerNumSlots)(bag) or 0) do
          local info = C and C.GetContainerItemInfo and C.GetContainerItemInfo(bag, slot)
          if info and info.quality == 0 and not info.hasNoValue and not skip[bag .. ":" .. slot] then
            local price = select(11, RG.ItemInfo(info.itemID)) or 0
            value = value + price * (info.stackCount or 1); sold = sold + 1
            C.UseContainerItem(bag, slot)
          end
        end
      end
      if sold > 0 then msgs[#msgs + 1] = "sold " .. sold .. " junk item" .. (sold > 1 and "s" or "") .. " for " .. RG.Money(value) end
    end
  end
  if RG.Opt("autoRepair") and CanMerchantRepair and CanMerchantRepair() then
    local cost, can = GetRepairAllCost()
    if can and cost and cost > 0 then
      if cost <= GetMoney() then RepairAllItems(); msgs[#msgs + 1] = "repaired your gear for " .. RG.Money(cost)
      else msgs[#msgs + 1] = RED .. "not enough gold to repair (" .. RG.Money(cost) .. ")|r" end
    end
  end
  if #msgs > 0 then RG.Print(table.concat(msgs, ", ") .. ".") end
end

-- ---------------------------------------------------------------------------
-- Reminders (shown in the tracker): Blessing, Seal, Find Minerals, trainer
-- ---------------------------------------------------------------------------
local function hasAura(names)
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return nil end
  for _, n in ipairs(names) do
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", n, "HELPFUL")
    if ok and aura then return true end
  end
  return false
end
local function knows(name)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(name)
    return info and (not IsPlayerSpell or IsPlayerSpell(info.spellID))
  end
  return GetSpellInfo and GetSpellInfo(name) ~= nil
end
local BLESSINGS = { "Blessing of Might", "Blessing of Kings", "Greater Blessing of Might", "Greater Blessing of Kings", "Blessing of Wisdom", "Battle Shout" }
local SEALS = { "Seal of Command", "Seal of Righteousness", "Seal of the Crusader", "Seal of Justice", "Seal of Wisdom", "Seal of Light" }

-- Find Minerals: index in the minimap tracking list, and whether it's on.
local function findMinerals()
  if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return nil end
  for i = 1, C_Minimap.GetNumTrackingTypes() do
    local info = C_Minimap.GetTrackingInfo(i)
    local name, active = info and (info.name or info[1]), info and info.active
    if type(info) ~= "table" then name, _, active = C_Minimap.GetTrackingInfo(i) end
    if name == "Find Minerals" then return i, active end
  end
end
function RG.EnableFindMinerals()
  local i, active = findMinerals()
  if i and not active and C_Minimap.SetTracking then C_Minimap.SetTracking(i, true); RG.Print("Find Minerals is on. Ore shows on your minimap.") end
  if RG.RefreshTracker then RG.RefreshTracker() end
end

-- Returns a list of { text, onClick } reminders for the tracker.
function RG.Reminders()
  local out = {}
  if UnitIsDeadOrGhost("player") then return out end
  if RG.Opt("mineReminder") and RG.Skill and RG.Skill("Mining") then
    local i, active = findMinerals()
    if i and not active then out[#out + 1] = { GOLD .. "Turn on Find Minerals|r" .. GREY .. "  (click)|r", RG.EnableFindMinerals } end
  end
  if RG.Opt("reminders") and not InCombatLockdown() then
    local _, class = UnitClass("player")
    if class == "PALADIN" then
      if knows("Blessing of Might") and hasAura(BLESSINGS) == false then out[#out + 1] = { GOLD .. "Cast Blessing of Might on yourself|r" } end
      if (knows("Seal of Command") or knows("Seal of Righteousness")) and hasAura(SEALS) == false and UnitExists("target") and UnitCanAttack("player", "target") then
        out[#out + 1] = { GOLD .. "Put a Seal up before you pull|r" .. GREY .. "  (Seal of Command)|r" }
      end
    end
  end
  if RG.db and RG.db.trainerDue then out[#out + 1] = { GOLD .. "New spells at your class trainer|r", function() RG.db.trainerDue = nil; if RG.RefreshTracker then RG.RefreshTracker() end end } end
  return out
end

-- ---------------------------------------------------------------------------
-- Welcome screen (first run)
-- ---------------------------------------------------------------------------
function RG.ShowWelcome()
  local f = CreateFrame("Frame", "RetGearWelcome", UIParent, "BackdropTemplate")
  f:SetSize(480, 420); f:SetPoint("CENTER", 0, 60); f:SetFrameStrata("DIALOG")
  backdrop(f, { 0.035, 0.035, 0.045, 0.98 }, { GOLDC[1], GOLDC[2], GOLDC[3], 0.9 })
  local glow = f:CreateTexture(nil, "BACKGROUND", nil, 1); glow:SetPoint("TOPLEFT", 1, -1); glow:SetPoint("TOPRIGHT", -1, -1); glow:SetHeight(120); glow:SetTexture(WHITE)
  if glow.SetGradient and CreateColor then glow:SetGradient("VERTICAL", CreateColor(GOLDC[1], GOLDC[2], GOLDC[3], 0), CreateColor(GOLDC[1], GOLDC[2], GOLDC[3], 0.15)) end
  local crest = f:CreateTexture(nil, "OVERLAY"); crest:SetSize(56, 56); crest:SetPoint("TOP", 0, -22); crest:SetTexture("Interface\\Icons\\Spell_Holy_AuraOfLight"); crest:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local t = f:CreateFontString(nil, "OVERLAY"); t:SetFont("Fonts\\MORPHEUS.TTF", 24, ""); t:SetPoint("TOP", crest, "BOTTOM", 0, -10); t:SetTextColor(GOLDC[1], GOLDC[2], GOLDC[3])
  t:SetText("Welcome, " .. (UnitName("player") or "Paladin") .. "!")
  local b = f:CreateFontString(nil, "OVERLAY"); b:SetFont("Fonts\\ARIALN.TTF", 14, ""); b:SetPoint("TOP", t, "BOTTOM", 0, -12); b:SetWidth(390); b:SetJustifyH("LEFT")
  b:SetWidth(410)
  b:SetText(GOLD .. "RetGear|r walks you from level 1 to 60 as a Retribution Paladin.\n\n"
    .. GOLD .. "•|r The " .. GOLD .. "tracker|r on the right shows your next steps and the most important reminders.\n"
    .. GOLD .. "•|r Quests are " .. GOLD .. "accepted and turned in for you|r (hold Shift to pause), and the best reward is picked.\n"
    .. GOLD .. "•|r The " .. GOLD .. "quest bar|r targets quest mobs and uses quest items in one click.\n"
    .. GOLD .. "•|r Tooltips show a " .. GOLD .. "Ret score|r, and better gear pops up with an Equip button.\n"
    .. GOLD .. "•|r Make " .. GOLD .. "camp|r for an hour of buffs. The DPS tab coaches you after fights.\n"
    .. GOLD .. "•|r Items worth more on the AH get a " .. GOLD .. "gold coin|r and are never vendored.\n"
    .. GOLD .. "•|r Everything else lives in " .. GOLD .. "/rg|r or the minimap button. Settings turns any of it off.")
  local function btn(label, x, fn, primary)
    local o = CreateFrame("Button", nil, f, "BackdropTemplate"); o:SetSize(150, 30); o:SetPoint("BOTTOM", x, 18)
    backdrop(o, primary and { GOLDC[1], GOLDC[2], GOLDC[3], 0.25 } or { 1, 1, 1, 0.05 }, { GOLDC[1], GOLDC[2], GOLDC[3], primary and 0.9 or 0.4 })
    local s = o:CreateFontString(nil, "OVERLAY"); s:SetFont("Fonts\\FRIZQT__.TTF", 12, ""); s:SetPoint("CENTER"); s:SetText(label); s:SetTextColor(GOLDC[1], GOLDC[2], GOLDC[3])
    o:SetScript("OnClick", function() RetGearDB.welcomed = true; f:Hide(); if fn then fn() end end)
  end
  btn("Open the guide", -80, function() if RG.ToggleUI then RG.ToggleUI() end end, true)
  btn("Got it", 80)
  f:Show()
  sound(SND.UI_QUEST_ROLLING_FORWARD_01 or 862)
end

-- ---------------------------------------------------------------------------
-- Minimap button (drag it around the minimap)
-- ---------------------------------------------------------------------------
local mm
local function placeMinimap()
  local a = math.rad(RetGearDB.mmAngle or 200)
  mm:ClearAllPoints(); mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 104, math.sin(a) * 104)
end
function RG.MinimapButton()
  if not Minimap then return end
  if not mm then
    mm = CreateFrame("Button", "RetGearMinimapButton", Minimap)
    mm:SetSize(32, 32); mm:SetFrameStrata("MEDIUM"); mm:SetFrameLevel(8)
    local ic = mm:CreateTexture(nil, "BACKGROUND"); ic:SetSize(20, 20); ic:SetPoint("CENTER", 0, 1); ic:SetTexture("Interface\\Icons\\Spell_Holy_AuraOfLight"); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local ring = mm:CreateTexture(nil, "OVERLAY"); ring:SetSize(54, 54); ring:SetPoint("TOPLEFT"); ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    mm:RegisterForClicks("LeftButtonUp", "RightButtonUp"); mm:RegisterForDrag("LeftButton")
    mm:SetScript("OnClick", function(_, btn)
      if btn == "RightButton" then RetGearDB.tracker = not RG.Opt("tracker"); if RG.RefreshTracker then RG.RefreshTracker() end
      elseif RG.ToggleUI then RG.ToggleUI() end
    end)
    mm:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter(); local cx, cy = GetCursorPosition(); local s = Minimap:GetEffectiveScale()
      RetGearDB.mmAngle = math.deg(math.atan2(cy / s - my, cx / s - mx)); placeMinimap()
    end) end)
    mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mm:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("RetGear", GOLDC[1], GOLDC[2], GOLDC[3])
      GameTooltip:AddLine("Click: open the guide", 1, 1, 1); GameTooltip:AddLine("Right-click: show or hide the tracker", 1, 1, 1); GameTooltip:AddLine("Drag: move this button", 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end)
    mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  placeMinimap()
  mm:SetShown(RG.Opt("minimap"))
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "MERCHANT_SHOW", "UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "MINIMAP_UPDATE_TRACKING", "ZONE_CHANGED_NEW_AREA" }) do pcall(f.RegisterEvent, f, e) end
local bagTimer
f:SetScript("OnEvent", function(_, event, a1)
  if RG.IsAlt and RG.IsAlt() and event ~= "MERCHANT_SHOW" then
    -- bank alt: only the vendor helper and minimap button
    if event == "PLAYER_LOGIN" then C_Timer.After(3, RG.MinimapButton) end
    return
  end
  if event == "PLAYER_LOGIN" then
    C_Timer.After(3, function()
      checkUpgrades(); RG.MinimapButton()
      if not RetGearDB.welcomed then RG.ShowWelcome() end
    end)
  elseif event == "BAG_UPDATE_DELAYED" then
    if bagTimer then return end
    bagTimer = true
    C_Timer.After(0.4, function() bagTimer = nil; checkUpgrades() end)
  elseif event == "PLAYER_LEVEL_UP" then
    if a1 and a1 % 2 == 0 then RG.db.trainerDue = true end
    C_Timer.After(1, function() levelBanner(a1) end)
  elseif event == "MERCHANT_SHOW" then
    atMerchant()
  elseif event == "UNIT_AURA" and a1 ~= "player" then
    return
  end
  if RG.QueueTracker then RG.QueueTracker() end
end)

-- More slash commands: /rg tracker, /rg welcome, /rg settings
local base = SlashCmdList.RETGEAR
SlashCmdList.RETGEAR = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  cmd = cmd and cmd:lower()
  if cmd == "tracker" then RetGearDB.tracker = not RG.Opt("tracker"); RG.RefreshTracker(); RG.Print("Tracker " .. (RG.Opt("tracker") and "shown." or "hidden.")); return end
  if cmd == "welcome" then RG.ShowWelcome(); return end
  if cmd == "settings" then if RG.ShowTab then RG.ShowTab("settings") end; return end
  return base(msg)
end
