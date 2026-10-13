-- Waypath+ quality-of-life: toasts, upgrade pop-ups, level-up banner, vendor
-- helper, paladin and mining reminders, welcome screen and minimap button.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLDC = { 1, 0.82, 0 }

-- Settings with their defaults. The Settings tab shows these as checkboxes.
RG.OPTIONS = {
  { key = "tracker",      label = "Show the on-screen tracker",            default = true },
  { key = "upgradeToast", label = "Pop up when I get a gear upgrade",       default = true },
  { key = "levelBanner",  label = "Show a banner when I level up",          default = true },
  { key = "sellJunk",     label = "Sell grey junk at vendors",              default = true },
  { key = "autoRepair",   label = "Repair my gear at vendors",              default = true },
  { key = "reminders",    label = "Remind me about Blessings and Seals",    default = true },
  { key = "mineReminder", label = "Remind me to turn on Find Minerals",     default = true },
  { key = "tooltip",      label = "Show upgrade scores on item tooltips",       default = true },
  { key = "autoScan",     label = "Check prices when I open the Auction House", default = true },
  { key = "minimap",      label = "Show the minimap button",                default = true },
  { key = "sounds",       label = "Play sounds for pop-ups",                default = true },
}
function RG.Opt(key)
  local v = WaypathDB and WaypathDB[key]
  if v == nil then for _, o in ipairs(RG.OPTIONS) do if o.key == key then return o.default end end end
  return v ~= false
end
local function sound(id) if RG.Opt("sounds") and PlaySound and id then pcall(PlaySound, id) end end
local SND = SOUNDKIT or {}

-- Classic tooltip-style frame: dark tooltip background with the beveled tooltip
-- border. Small frames (under 40px) get a thinner border so icons stay visible.
local function backdrop(f, bg, edge)
  if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
  local small = (f.GetHeight and (f:GetHeight() or 0) > 0 and f:GetHeight() < 40)
  f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = small and 10 or 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  f:SetBackdropBorderColor(edge[1], edge[2], edge[3], math.max(edge[4] or 1, 0.75))
end
-- Classic dialog frame: the stone-and-gold border used by Blizzard's popups.
function RG.DialogBackdrop(f)
  if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
  f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
  f:SetBackdropColor(1, 1, 1, 1); f:SetBackdropBorderColor(1, 1, 1, 1)
  -- solid dark layer underneath, so text stays readable even if a client lacks the dialog texture
  if not f.rgSolid then
    f.rgSolid = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.rgSolid:SetPoint("TOPLEFT", 11, -12); f.rgSolid:SetPoint("BOTTOMRIGHT", -12, 11)
    f.rgSolid:SetColorTexture(0.04, 0.035, 0.03, 0.92)
  end
end
-- Gold title banner across the top edge of a dialog (UI-DialogBox-Header).
function RG.DialogHeader(f, text, width)
  local h = f:CreateTexture(nil, "ARTWORK"); h:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  h:SetSize(width or 300, 64); h:SetPoint("TOP", 0, 12)
  local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); t:SetPoint("TOP", h, "TOP", 0, -14); t:SetText(text)
  return h, t
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
  t:SetSize(400, 96); t:SetFrameStrata("DIALOG")
  RG.DialogBackdrop(t)
  local ic = t:CreateTexture(nil, "ARTWORK"); ic:SetSize(40, 40); ic:SetPoint("LEFT", 24, 0); ic:SetTexture(icon or "Interface\\Icons\\Spell_Holy_AuraOfLight")
  local ring = t:CreateTexture(nil, "OVERLAY"); ring:SetSize(68, 68); ring:SetPoint("CENTER", ic, "CENTER"); ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  local h = t:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); h:SetPoint("TOPLEFT", ic, "TOPRIGHT", 14, 2); h:SetText(title)
  local b = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); b:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -5); b:SetWidth(button and 210 or 290); b:SetJustifyH("LEFT"); b:SetText(text or "")
  local x = CreateFrame("Button", nil, t, "UIPanelCloseButton"); x:SetPoint("TOPRIGHT", -2, -2)
  local function close()
    for i, v in ipairs(toasts) do if v == t then table.remove(toasts, i) break end end
    t:Hide(); layoutToasts()
  end
  x:SetScript("OnClick", close)
  if button then
    local btn = CreateFrame("Button", nil, t, "UIPanelButtonTemplate")
    btn:SetSize(96, 24); btn:SetPoint("BOTTOMRIGHT", -18, 16); btn:SetText(button)
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
          RG.Toast("Upgrade!", link .. "\n" .. GREEN .. string.format("+%.0f %s", delta, RG.SCORE_NAME) .. "|r" .. GREY .. " over what you're wearing|r", icon, "Equip", function()
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
  for _, n in ipairs(names) do
    local a, blocked = RG.PlayerBuff(n)
    if blocked then return nil end
    if a then return true end
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
      if (knows("Seal of Command") or knows("Seal of Righteousness")) and hasAura(SEALS) == false and RG.SafeCall(UnitExists, "target") and RG.SafeCall(UnitCanAttack, "player", "target") then
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
  local f = CreateFrame("Frame", "WaypathWelcome", UIParent, "BackdropTemplate")
  f:SetSize(480, 450); f:SetPoint("CENTER", 0, 60); f:SetFrameStrata("DIALOG")
  RG.DialogBackdrop(f)
  RG.DialogHeader(f, "Waypath+", 300)
  local crest = f:CreateTexture(nil, "ARTWORK"); crest:SetSize(44, 44); crest:SetPoint("TOP", 0, -34); crest:SetTexture("Interface\\Icons\\Spell_Holy_AuraOfLight")
  local ring = f:CreateTexture(nil, "OVERLAY"); ring:SetSize(74, 74); ring:SetPoint("CENTER", crest, "CENTER"); ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  local t = f:CreateFontString(nil, "OVERLAY"); t:SetFont("Fonts\\MORPHEUS.TTF", 24, ""); t:SetPoint("TOP", crest, "BOTTOM", 0, -12); t:SetTextColor(GOLDC[1], GOLDC[2], GOLDC[3]); t:SetShadowColor(0, 0, 0, 1); t:SetShadowOffset(1, -1)
  t:SetText("Welcome, " .. (UnitName("player") or "Paladin") .. "!")
  local b = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); b:SetPoint("TOP", t, "BOTTOM", 0, -12); b:SetWidth(390); b:SetJustifyH("LEFT"); b:SetSpacing(2)
  b:SetWidth(410)
  b:SetText(GOLD .. "Waypath+|r walks you from level 1 to 60.\n\n"
    .. GOLD .. "•|r The " .. GOLD .. "tracker|r on the right shows your next steps and the most important reminders.\n"
    .. GOLD .. "•|r Quests are " .. GOLD .. "accepted and turned in for you|r (hold Shift to pause), and the best reward is picked.\n"
    .. GOLD .. "•|r The " .. GOLD .. "quest bar|r targets quest mobs and uses quest items in one click.\n"
    .. GOLD .. "•|r Tooltips show a " .. GOLD .. RG.SCORE_NAME .. "|r, and better gear pops up with an Equip button.\n"
    .. GOLD .. "•|r Make " .. GOLD .. "camp|r for an hour of buffs.\n"
    .. GOLD .. "•|r Items worth more on the AH get a " .. GOLD .. "gold coin|r and are never vendored.\n"
    .. GOLD .. "•|r Everything else lives in " .. GOLD .. "/wp|r or the minimap button. Settings turns any of it off.")
  local function btn(label, x, fn, primary)
    local o = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); o:SetSize(150, 24); o:SetPoint("BOTTOM", x, 22); o:SetText(label)
    o:SetScript("OnClick", function() WaypathDB.welcomed = true; f:Hide(); if fn then fn() end end)
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
  local a = math.rad(WaypathDB.mmAngle or 200)
  mm:ClearAllPoints(); mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 104, math.sin(a) * 104)
end
function RG.MinimapButton()
  if not Minimap then return end
  if not mm then
    mm = CreateFrame("Button", "WaypathMinimapButton", Minimap)
    mm:SetSize(32, 32); mm:SetFrameStrata("MEDIUM"); mm:SetFrameLevel(8)
    local ic = mm:CreateTexture(nil, "BACKGROUND"); ic:SetSize(20, 20); ic:SetPoint("CENTER", 0, 1); ic:SetTexture("Interface\\Icons\\Spell_Holy_AuraOfLight"); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local ring = mm:CreateTexture(nil, "OVERLAY"); ring:SetSize(54, 54); ring:SetPoint("TOPLEFT"); ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    mm:RegisterForClicks("LeftButtonUp", "RightButtonUp"); mm:RegisterForDrag("LeftButton")
    mm:SetScript("OnClick", function(_, btn)
      if btn == "RightButton" then WaypathDB.tracker = not RG.Opt("tracker"); if RG.RefreshTracker then RG.RefreshTracker() end
      elseif IsShiftKeyDown and IsShiftKeyDown() then WaypathDB.arrow = not RG.Opt("arrow"); if RG.RefreshArrow then RG.RefreshArrow() end; if RG.RefreshTracker then RG.RefreshTracker() end; RG.Notify("Arrow " .. (RG.Opt("arrow") and "on" or "off"))
      elseif IsControlKeyDown and IsControlKeyDown() then if RG.ShowTab then RG.ShowTab("settings") end
      elseif RG.ToggleUI then RG.ToggleUI() end
    end)
    mm:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter(); local cx, cy = GetCursorPosition(); local s = Minimap:GetEffectiveScale()
      WaypathDB.mmAngle = math.deg(math.atan2(cy / s - my, cx / s - mx)); placeMinimap()
    end) end)
    mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mm:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("Waypath+", GOLDC[1], GOLDC[2], GOLDC[3])
      GameTooltip:AddLine("Click: open the guide", 1, 1, 1); GameTooltip:AddLine("Right-click: show or hide the tracker", 1, 1, 1)
      GameTooltip:AddLine("Shift-click: arrow on or off", 1, 1, 1); GameTooltip:AddLine("Ctrl-click: settings", 1, 1, 1); GameTooltip:AddLine("Drag: move this button", 0.6, 0.6, 0.6)
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
      if not WaypathDB.setupDone then RG.ShowWelcome() end
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

-- More slash commands: /wp tracker, /wp welcome, /wp settings
local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  cmd = cmd and cmd:lower()
  if cmd == "tracker" then WaypathDB.tracker = not RG.Opt("tracker"); RG.RefreshTracker(); RG.Print("Tracker " .. (RG.Opt("tracker") and "shown." or "hidden.")); return end
  if cmd == "welcome" then RG.ShowWelcome(); return end
  if cmd == "settings" then if RG.ShowTab then RG.ShowTab("settings") end; return end
  return base(msg)
end

-- Key Bindings (Esc > Options > Keybindings > AddOns > Waypath+)
BINDING_HEADER_WAYPATH = "Waypath+"
BINDING_NAME_WAYPATH_TOGGLE = "Open or close the guide"
BINDING_NAME_WAYPATH_NEXT = "Pin my nearest quest objective"
BINDING_NAME_WAYPATH_ARROW = "Arrow on or off"
BINDING_NAME_WAYPATH_TRACKER = "Show or hide the tracker"
BINDING_NAME_WAYPATH_UNDO = "Undo my last ticked task"
BINDING_NAME_WAYPATH_SORT = "Sort my bags"
function Waypath_Bind(action)
  if action == "toggle" then if RG.ToggleUI then RG.ToggleUI() end
  elseif action == "next" then SlashCmdList.WAYPATH("next")
  elseif action == "arrow" then WaypathDB.arrow = not RG.Opt("arrow"); if RG.RefreshArrow then RG.RefreshArrow() end; if RG.RefreshTracker then RG.RefreshTracker() end; RG.Notify("Arrow " .. (RG.Opt("arrow") and "on" or "off"))
  elseif action == "tracker" then WaypathDB.tracker = not RG.Opt("tracker"); if RG.RefreshTracker then RG.RefreshTracker() end
  elseif action == "undo" then SlashCmdList.WAYPATH("undo")
  elseif action == "sort" then if RG.SortBags then RG.SortBags(BankFrame and BankFrame:IsShown()) end end
end
