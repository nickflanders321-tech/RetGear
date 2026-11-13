-- Waypath+ fishing tools: one key to cast and hook (a lure put on first when yours ran out),
-- loot taken while you fish, and a fishing outfit you put on and take off with one click.
--
-- Everything that casts or uses an item goes through a secure button and your own click or key press: the
-- game allows that, never an add-on acting by itself. Bindings only change out of combat, as the game requires.
--   One key:   a key you choose (Fishing tab). It casts while your bobber is out of the water and, once it's
--              in, uses the game's own interact key on it, so pressing it at the splash hooks the fish. The key
--              is only taken over while your pole is in your hands; otherwise it does what it always did.
--   Auto-loot: on while you fish, back to your own setting 30 seconds after your last cast.
--   Outfit:    your best pole and any fishing gear in your bags on, and your weapons and gear back after.
--              A fight while you hold the pole puts your weapons back (the game allows weapon swaps then).
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY

table.insert(RG.OPTIONS, { key = "fishAutoLoot", label = "Auto-loot while I fish", default = true })
table.insert(RG.OPTIONS, { key = "fishDoubleRight", label = "Double-right-click the world to cast Fishing while I hold my pole", default = false })
table.insert(RG.OPTIONS, { key = "fishCombatSwap", label = "Weapons back on when a fight starts while I hold my fishing pole", default = true })

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function secret(v) return RG.IsSecret and RG.IsSecret(v) end
local function db()
  RG.db.fishTools = RG.db.fishTools or {}
  return RG.db.fishTools
end

-- Fishing in the game client's own language (WoW Forever's spell first)
local FISH_SPELLS = { 131474, 7620, 7731, 7732, 18248, 33095, 51294 }
local spellName
local function fishSpell()
  if spellName then return spellName end
  for _, id in ipairs(FISH_SPELLS) do
    local ok, n = pcall(function()
      if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
      return GetSpellInfo and (GetSpellInfo(id))
    end)
    if ok and type(n) == "string" and n ~= "" and not secret(n) then spellName = n break end
  end
  return spellName or "Fishing"
end
RG.FishSpellName = fishSpell
local FISH_IDS = {}
for _, id in ipairs(FISH_SPELLS) do FISH_IDS[id] = true end
local function isFishing(id)
  if secret(id) then return false end
  if FISH_IDS[id] then return true end
  local ok, n = pcall(function() if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end return GetSpellInfo and (GetSpellInfo(id)) end)
  return ok and n ~= nil and n == fishSpell()
end

-- ---------------------------------------------------------------------------
-- The secure button both easy cast and the one key click: it casts, or puts a lure on first
-- ---------------------------------------------------------------------------
local btn
local function button()
  if btn or not CreateFrame then return btn end
  -- (on the game world, so it stays shown while immersive fishing hides the interface)
  local parent = WorldFrame or UIParent
  local ok, b = pcall(CreateFrame, "Button", "WaypathFishEasy", parent, "SecureActionButtonTemplate")
  if not ok or not b then return nil end
  b:SetSize(1, 1); b:SetPoint("TOPLEFT", parent, "TOPLEFT", -10, 10); b:SetAlpha(0)
  -- both, so it works whichever way your "cast on key down" setting is: the game acts on one of them only
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "spell"); b:SetAttribute("spell", fishSpell())
  b:Show()
  btn = b
  return b
end
local lureNext = false   -- the next click puts a lure on
-- set the button up for the next click (out of combat only)
local function prepare()
  local b = button()
  if not b or inCombat() then return end
  local c = RG.FishBoostChoice and RG.FishBoostChoice()
  local lure = c and c.lure
  if lure then
    b:SetAttribute("type", "macro"); b:SetAttribute("macrotext", lure.macro); lureNext = true
  else
    b:SetAttribute("type", "spell"); b:SetAttribute("spell", fishSpell()); lureNext = false
  end
end
RG.FishToolsPrepare = prepare

local channeling = false   -- your bobber is in the water
-- ---------------------------------------------------------------------------
-- One key: cast while the bobber is out of the water, the interact key while it's in
-- ---------------------------------------------------------------------------
local keyOwner = CreateFrame and CreateFrame("Frame")
local softSaved
local function softOn()
  if softSaved or not (GetCVar and SetCVar) then return end
  local ok, cur = pcall(GetCVar, "SoftTargetInteract")
  if ok and cur and cur ~= "3" then softSaved = cur; pcall(SetCVar, "SoftTargetInteract", "3") end
end
local function softOff()
  if softSaved and SetCVar then pcall(SetCVar, "SoftTargetInteract", softSaved) end
  softSaved = nil
end
local keyMode   -- nil, "cast" or "hook"
local function applyKey()
  if not keyOwner or inCombat() or not ClearOverrideBindings then return end
  local key = db().key
  local want = key and RG.HasPole and RG.HasPole() and (channeling and "hook" or "cast") or nil
  if want == keyMode and want ~= "cast" then return end
  ClearOverrideBindings(keyOwner)
  keyMode = want
  if want == "hook" then
    softOn()
    SetOverrideBinding(keyOwner, true, key, "INTERACTTARGET")
  elseif want == "cast" then
    prepare()
    SetOverrideBindingClick(keyOwner, true, key, "WaypathFishEasy")
  else softOff() end
end
RG.FishApplyKey = applyKey
function RG.FishKey() return db().key end
function RG.FishSetKey(key)
  if inCombat() then RG.Print("Set your fishing key after the fight.") return end
  db().key = key
  keyMode = "?"
  applyKey()
end

-- the key picker for the Fishing tab: the next key you press (Esc cancels, Backspace clears)
local picker
function RG.FishPickKey(done)
  if inCombat() then RG.Print("Set your fishing key after the fight.") return end
  if not picker then
    picker = CreateFrame("Frame", "WaypathFishKeyPicker", UIParent, "BackdropTemplate")
    picker:SetSize(340, 96); picker:SetPoint("CENTER", 0, 120); picker:SetFrameStrata("FULLSCREEN_DIALOG")
    if RG.DialogBackdrop then RG.DialogBackdrop(picker) end
    picker.t = picker:CreateFontString(nil, "OVERLAY"); RG.Font(picker.t, "display", 16); picker.t:SetTextColor(0.937, 0.902, 0.824); picker.t:SetPoint("TOP", 0, -18); picker.t:SetText("Press the key you want to fish with")
    picker.s = picker:CreateFontString(nil, "OVERLAY"); RG.Font(picker.s, "regular", 12); picker.s:SetPoint("TOP", picker.t, "BOTTOM", 0, -10)
    picker.s:SetText("It casts, then hooks the fish at the splash.\nEsc cancels  ·  Backspace removes the key"); picker.s:SetTextColor(0.75, 0.75, 0.75)
    picker:EnableKeyboard(true)
    if picker.SetPropagateKeyboardInput then picker:SetPropagateKeyboardInput(false) end
    picker:SetScript("OnKeyDown", function(self, k)
      if k == "LSHIFT" or k == "RSHIFT" or k == "LCTRL" or k == "RCTRL" or k == "LALT" or k == "RALT" then return end
      self:Hide()
      if k == "ESCAPE" then return end
      if k == "BACKSPACE" or k == "DELETE" then RG.FishSetKey(nil); if self.done then self.done(nil) end return end
      local mods = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
      RG.FishSetKey(mods .. k)
      if self.done then self.done(mods .. k) end
    end)
  end
  picker.done = done
  picker:Show()
end

-- ---------------------------------------------------------------------------
-- Auto-loot while fishing
-- ---------------------------------------------------------------------------
local lootSaved, lastCast
local function lootOn()
  if lootSaved or not RG.Opt("fishAutoLoot") or not (GetCVar and SetCVar) then return end
  local ok, cur = pcall(GetCVar, "autoLootDefault")
  if ok and cur and cur ~= "1" then lootSaved = cur; pcall(SetCVar, "autoLootDefault", "1") end
end
local function lootOff()
  if lootSaved and SetCVar then pcall(SetCVar, "autoLootDefault", lootSaved) end
  lootSaved = nil
end

-- ---------------------------------------------------------------------------
-- Fishing outfit
-- ---------------------------------------------------------------------------
local SLOTS = { 1, 8, 10, 16, 17 }   -- head, feet, hands, main hand, off hand
local POLES = {}
local GEAR_SLOT = {}   -- fishing gear id -> slot
for _, g in ipairs(RG.FISH_GEAR or {}) do
  if g.kind == "pole" then POLES[g.id] = g.bonus end
end
local INVTYPE_SLOT = { INVTYPE_HEAD = 1, INVTYPE_FEET = 8, INVTYPE_HAND = 10 }
local function equipped(slot) return GetInventoryItemID and GetInventoryItemID("player", slot) end
local function equippedLink(slot) return GetInventoryItemLink and GetInventoryItemLink("player", slot) end
local function count(id) return (GetItemCount and GetItemCount(id)) or 0 end
-- the best pole you carry (bags or hands)
local function bestPole()
  local best, bb
  for id, bonus in pairs(POLES) do
    if count(id) > 0 and (not bb or bonus > bb) then best, bb = id, bonus end
  end
  return best
end
-- what goes on: the pole, fishing gear with a skill bonus, and what you told us is part of your outfit
local function outfit()
  local want = {}
  local pole = bestPole()
  if pole then want[16] = pole end
  for _, g in ipairs(RG.FISH_GEAR or {}) do
    if g.kind == "gear" and count(g.id) > 0 then
      local loc = select(9, RG.ItemInfo(g.id))
      local slot = INVTYPE_SLOT[loc or ""]
      if slot and not want[slot] then want[slot] = g.id end
    end
  end
  for slot, id in pairs(db().extra or {}) do if count(id) > 0 then want[slot] = want[slot] or id end end
  return want
end
RG.FishOutfit = outfit
-- remember what you wear now (your weapons and the pieces the outfit replaces)
local function remember()
  local d = db()
  d.normal = d.normal or {}
  local pole = equipped(16) and POLES[equipped(16)]
  for _, slot in ipairs(SLOTS) do
    local id = equipped(slot)
    -- not the fishing pieces themselves
    if not (slot == 16 and pole) and not (slot == 17 and pole) then
      local isFishGear = false
      for _, g in ipairs(RG.FISH_GEAR or {}) do if g.id == id then isFishGear = true end end
      for _, x in pairs(d.extra or {}) do if x == id then isFishGear = true end end
      if not isFishGear then d.normal[slot] = id or false end
    end
  end
end
function RG.FishGearOn()
  if inCombat() then RG.Print("You can't change gear in a fight.") return false end
  local want = outfit()
  if not want[16] then RG.Print("No fishing pole in your bags. Buy one from a fishing vendor (Fishing tab).") return false end
  if not (equipped(16) and POLES[equipped(16)]) then remember() end
  for slot, id in pairs(want) do
    if equipped(slot) ~= id and EquipItemByName then pcall(EquipItemByName, id, slot) end
  end
  return true
end
function RG.FishGearOff(quiet)
  local d = db()
  if not d.normal then if not quiet then RG.Print("Waypath+ doesn't know what you wore before fishing.") end return false end
  local fight = inCombat()
  for _, slot in ipairs(SLOTS) do
    local id = d.normal[slot]
    -- in a fight only weapons can change
    if (not fight or slot >= 16) and id and equipped(slot) ~= id and count(id) > 0 and EquipItemByName then pcall(EquipItemByName, id, slot) end
  end
  return true
end
-- remember the outfit pieces you wear now (beyond the pole) as part of your fishing outfit
function RG.FishSaveOutfit()
  local d = db()
  d.extra = {}
  for _, slot in ipairs({ 1, 8, 10 }) do
    local id = equipped(slot)
    if id and d.normal and d.normal[slot] ~= id then d.extra[slot] = id end
  end
  local n = 0; for _ in pairs(d.extra) do n = n + 1 end
  RG.Print(n > 0 and ("Your fishing outfit now includes " .. n .. " piece" .. (n > 1 and "s" or "") .. " you're wearing.") or "Nothing beyond your pole to remember: put on the pieces you fish in first.")
end
function RG.FishOutfitState()
  local holding = RG.HasPole and RG.HasPole()
  return holding and "on" or "off", bestPole(), db().normal ~= nil
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local ev = CreateFrame and CreateFrame("Frame")
if ev then
  for _, e in ipairs({ "PLAYER_LOGIN", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "UNIT_INVENTORY_CHANGED", "PLAYER_LOGOUT" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event, a1, _, a3)
    if not RG.db or (RG.IsAlt and RG.IsAlt()) then return end
    if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
      if a1 ~= "player" or not isFishing(a3) then return end
      channeling = event == "UNIT_SPELLCAST_CHANNEL_START"
      if channeling then rcDisarm() end
      if channeling then lastCast = GetTime(); lootOn() end
      applyKey()
    elseif event == "PLAYER_REGEN_DISABLED" then
      -- the last moment bindings can change: give your keys back for the fight
      if keyOwner and ClearOverrideBindings then ClearOverrideBindings(keyOwner) end
      keyMode = nil; softOff(); lootOff()
      if rcOwner and rcArmed and ClearOverrideBindings then ClearOverrideBindings(rcOwner) end; rcArmed = false
      if RG.Opt("fishCombatSwap") and RG.HasPole and RG.HasPole() then
        RG.FishGearOff(true)
        if UIErrorsFrame then UIErrorsFrame:AddMessage("Fight! Weapons back on", 1, 0.3, 0.2) end
      end
    elseif event == "PLAYER_LOGOUT" then softOff(); lootOff()
    else
      if lureNext and event == "BAG_UPDATE_DELAYED" then lureNext = false end
      -- a pole in your hands for the first time: remember the weapons it replaced
      if event == "PLAYER_EQUIPMENT_CHANGED" and a1 == 16 and RG.HasPole and not RG.HasPole() then remember() end
      applyKey()
    end
  end)
  if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(5, function()
      if lootSaved and lastCast and GetTime() - lastCast > 30 and not channeling and not inCombat() then lootOff() end
    end)
  end
end

-- ---------------------------------------------------------------------------
-- Double-right-click to cast (off unless you turn it on): the first right-click on the world, with your pole in
-- your hands and your line out of the water, makes the right mouse button cast for a moment, so a second click right
-- after casts. Your right button is yours again 0.4 seconds later, the moment you cast, and in any fight.
-- ---------------------------------------------------------------------------
local rcOwner = CreateFrame and CreateFrame("Frame")
local rcArmed = false
local function rcDisarm()
  if rcArmed and rcOwner and not inCombat() and ClearOverrideBindings then ClearOverrideBindings(rcOwner) end
  rcArmed = false
end
RG.FishDoubleRightDisarm = rcDisarm
if WorldFrame and WorldFrame.HookScript and rcOwner then
  WorldFrame:HookScript("OnMouseDown", function(_, mouse)
    if mouse ~= "RightButton" or rcArmed or not RG.db or not RG.Opt("fishDoubleRight") then return end
    if inCombat() or channeling or not (RG.HasPole and RG.HasPole()) or not SetOverrideBindingClick then return end
    prepare()
    if not button() then return end
    SetOverrideBindingClick(rcOwner, true, "BUTTON2", "WaypathFishEasy")
    rcArmed = true
    if C_Timer then C_Timer.After(0.4, rcDisarm) end
  end)
end

-- /wp fishcheck: what the tools see, to tell why a cast didn't happen
local function fishCheck()
  local key = db().key
  local cv = GetCVar and GetCVar("ActionButtonUseKeyDown")
  local lines = {
    "pole in hand: " .. tostring(RG.HasPole and RG.HasPole()) .. "  ·  in a fight: " .. tostring(inCombat() and true or false) .. "  ·  bobber out: " .. tostring(channeling),
    "spell: " .. fishSpell(),
    "one key: " .. tostring(key) .. "  ·  now does: " .. tostring(key and GetBindingAction and GetBindingAction(key, true)) .. "  ·  mode: " .. tostring(keyMode),
    "cast on key down: " .. tostring(cv) .. "  ·  soft interact: " .. tostring(GetCVar and GetCVar("SoftTargetInteract")),
  }
  for _, l in ipairs(lines) do RG.Print(l) end
end
local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
  cmd = cmd and cmd:lower()
  if cmd == "fishgear" or cmd == "gofish" then RG.FishGearOn() return end
  if cmd == "weapons" then RG.FishGearOff() return end
  if cmd == "fishcheck" then fishCheck() return end
  return base(msg)
end
