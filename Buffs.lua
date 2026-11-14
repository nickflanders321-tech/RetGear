-- Waypath+ buff reminder: a small row of icons, WeakAuras-style, for a buff of your own that's missing or about to
-- run out, and for a consumable in your bags worth using now. Click an icon to cast or use it; right-click it to
-- hide that one until you log in again. Move the row in Edit Mode (or /wp move); /wp buffs turns it off and on.
--   Your buffs: only spells you know, checked by name (a spell this client doesn't have is simply never shown).
--     When a class has several of a kind (mage armors, paladin blessings and auras, hunter aspects, shaman weapon
--     imbues) any one of them counts, and the icon casts the one you used last.
--   Rogue poisons and shaman imbues: a weapon with nothing on it.
--   Consumables: food that gives Well Fed when you're out of town (not resting), and elixirs, flasks and scrolls
--     only inside a dungeon or raid, where they matter (your quest elixirs stay in your bags the rest of the time).
-- It shows only out of a fight (the game hides it in one: buttons can't change then) and never casts by itself.
local _, RG = ...
local GOLD, GREY = RG.COLORS.GOLD, RG.COLORS.GREY

table.insert(RG.OPTIONS, { key = "buffReminder", label = "Buff reminder: an icon when one of your own buffs is missing (move it in Edit Mode)", default = true })
table.insert(RG.OPTIONS, { key = "buffConsumables", label = "Buff reminder: also food for Well Fed, and elixirs and scrolls in dungeons", default = true })

local MEDIA = "Interface\\AddOns\\Waypath\\Media\\"
local EDGE = { miss = { 0.96, 0.56, 0.17 }, low = { 1, 0.85, 0.2 }, item = { 0.32, 0.78, 0.36 } }
local SIZE, GAP, MAXB = 36, 8, 8
local SOON = 60   -- seconds left that count as running out

-- Each group: any = aura names that count (a "^" entry is a pattern), cast = your spells, best first.
-- weapon = a weapon imbue (checked on your main hand). The first one you know shows; the one you cast last wins.
local CLASS = {
  MAGE = {
    { key = "int", label = "Arcane Intellect", any = { "Arcane Intellect", "Arcane Brilliance" }, cast = { "Arcane Intellect" } },
    { key = "armor", label = "Armor", any = { "Molten Armor", "Mage Armor", "Ice Armor", "Frost Armor" }, cast = { "Molten Armor", "Mage Armor", "Ice Armor", "Frost Armor" } },
  },
  PRIEST = {
    { key = "fort", label = "Power Word: Fortitude", any = { "Power Word: Fortitude", "Prayer of Fortitude" }, cast = { "Power Word: Fortitude" } },
    { key = "inner", label = "Inner Fire", any = { "Inner Fire" }, cast = { "Inner Fire" } },
  },
  DRUID = {
    { key = "motw", label = "Mark of the Wild", any = { "Mark of the Wild", "Gift of the Wild" }, cast = { "Mark of the Wild" } },
    { key = "thorns", label = "Thorns", any = { "Thorns" }, cast = { "Thorns" } },
  },
  WARLOCK = {
    { key = "armor", label = "Demon Armor", any = { "Fel Armor", "Demon Armor", "Demon Skin" }, cast = { "Fel Armor", "Demon Armor", "Demon Skin" } },
  },
  SHAMAN = {
    { key = "shield", label = "Shield", any = { "Lightning Shield", "Water Shield", "Earth Shield" }, cast = { "Lightning Shield", "Water Shield" } },
    { key = "imbue", label = "Weapon imbue", weapon = true, cast = { "Windfury Weapon", "Flametongue Weapon", "Rockbiter Weapon", "Frostbrand Weapon" } },
  },
  PALADIN = {
    { key = "blessing", label = "Blessing", any = { "^Greater Blessing of ", "^Blessing of " }, cast = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Sanctuary" } },
    { key = "aura", label = "Aura", any = { "Devotion Aura", "Retribution Aura", "Concentration Aura", "Sanctity Aura", "Shadow Resistance Aura", "Frost Resistance Aura", "Fire Resistance Aura", "Crusader Aura" },
      cast = { "Devotion Aura", "Retribution Aura", "Concentration Aura", "Sanctity Aura" }, noTimer = true },
  },
  HUNTER = {
    { key = "aspect", label = "Aspect", any = { "^Aspect of the " }, cast = { "Aspect of the Hawk", "Aspect of the Monkey" }, noTimer = true },
    { key = "trueshot", label = "Trueshot Aura", any = { "Trueshot Aura" }, cast = { "Trueshot Aura" }, noTimer = true },
  },
}
-- poisons for a rogue's weapons, main hand first choice first (any poison in your bags is used when these aren't)
local POISON_MAIN = { "Instant Poison", "Deadly Poison", "Wound Poison", "Mind-numbing Poison", "Crippling Poison" }
local POISON_OFF = { "Deadly Poison", "Instant Poison", "Wound Poison", "Mind-numbing Poison", "Crippling Poison" }

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function db() RG.db.buffs = RG.db.buffs or { last = {} }; RG.db.buffs.last = RG.db.buffs.last or {}; return RG.db.buffs end
local snoozed = {}   -- right-clicked away until the next login
local function secret(x) return RG.IsSecret and RG.IsSecret(x) end

-- a spell you know, by name: its icon and name (nil when you don't know it)
local function known(name)
  local ok, ic, n = pcall(function()
    if C_Spell and C_Spell.GetSpellInfo then local i = C_Spell.GetSpellInfo(name); if i then return i.iconID or i.originalIconID, i.name end return nil end
    if GetSpellInfo then local nm, _, icon = GetSpellInfo(name); return icon, nm end
  end)
  if ok and n and not secret(n) then return ic or "Interface\\Icons\\INV_Misc_QuestionMark", n end
end
local function itemIcon(id)
  if C_Item and C_Item.GetItemIconByID then local ic = C_Item.GetItemIconByID(id); if ic then return ic end end
  return RG.ItemIcon and RG.ItemIcon(id) or nil
end
local function itemSpell(id)
  local f = (C_Item and C_Item.GetItemSpell) or _G.GetItemSpell
  if not f then return nil end
  local ok, n = pcall(f, id)
  if ok and type(n) == "string" and not secret(n) then return n end
end

-- your buffs right now: name -> seconds left (false when it doesn't run out); nil when they can't be read
local function myAuras()
  local out = {}
  local _, locked = RG.FindAura("player", "HELPFUL", function(a)
    local n = a.name
    if type(n) == "string" then
      local exp = a.expirationTime
      local left = (type(exp) == "number" and not secret(exp) and exp > 0) and (exp - GetTime()) or false
      if left == false then out[n] = false
      elseif out[n] ~= false and (out[n] == nil or left > out[n]) then out[n] = left end
    end
  end)
  if locked then return nil end
  return out
end
-- the best match of a group in your buffs: true when found with time to spare, or its seconds left when running out
local function groupState(g, auras)
  local best
  for n, left in pairs(auras) do
    for _, want in ipairs(g.any) do
      local hit = (want:sub(1, 1) == "^") and n:find(want) or n == want
      if hit then
        if left == false or g.noTimer then return true end
        if not best or left > best then best = left end
      end
    end
  end
  if best and best >= SOON then return true end
  return best
end

-- every item in your bags: { id, name, count }, one per item
local function bagItems()
  local C = C_Container
  local slotsOf = (C and C.GetContainerNumSlots) or _G.GetContainerNumSlots
  local infoOf = C and C.GetContainerItemInfo
  local out, seen = {}, {}
  if not (slotsOf and infoOf) then return out end
  for bag = 0, 4 do
    for slot = 1, (slotsOf(bag) or 0) do
      pcall(function()
        local info = infoOf(bag, slot)
        local id = info and info.itemID
        if not id or secret(id) or seen[id] then return end
        local name = info.itemName or (type(info.hyperlink) == "string" and info.hyperlink:match("%[(.-)%]")) or (RG.ItemInfo and RG.ItemInfo(id))
        if type(name) ~= "string" or secret(name) then return end
        seen[id] = true
        local _, _, _, _, _, classID = ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(id)
        local cnt = ((C_Item and C_Item.GetItemCount) or GetItemCount)(id) or 1
        out[#out + 1] = { id = id, name = name, count = cnt, use = classID == 0 }
      end)
    end
  end
  return out
end
-- food that gives Well Fed, read from its tooltip once per item
local wellFedCache = {}
local function givesWellFed(id)
  if wellFedCache[id] ~= nil then return wellFedCache[id] end
  local yes, lines = false, 0
  pcall(function()
    local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink("item:" .. id)
    for _, line in ipairs(data and data.lines or {}) do
      lines = lines + 1
      local t = line.leftText
      if type(t) == "string" and not secret(t) and t:lower():find("well fed", 1, true) then yes = true end
    end
  end)
  -- (an item the client hasn't loaded yet has a one-line tooltip: asked again next time)
  if yes or lines > 1 then wellFedCache[id] = yes end
  return yes
end

local function weaponEnchants()
  if not GetWeaponEnchantInfo then return nil end
  local ok, hasMain, _, _, _, hasOff = pcall(GetWeaponEnchantInfo)
  if not ok then return nil end
  return hasMain and true or false, hasOff and true or false
end
local function hasWeapon(slot)
  local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
  if not link then return false end
  local _, _, _, _, _, classID = ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(link)
  return classID == 2
end

-- ---------------------------------------------------------------------------
-- What to show: a list of { key, icon, state, secure, tip, big, count }
-- ---------------------------------------------------------------------------
local function pickSpell(g)
  local last = db().last[g.key]
  if last then local ic, n = known(last); if n then return ic, n end end
  for _, s in ipairs(g.cast) do local ic, n = known(s); if n then return ic, n end end
end
local function mmss(sec)
  sec = math.max(0, math.floor(sec + 0.5))
  if sec >= 60 then return math.floor(sec / 60) .. "m" end
  return tostring(sec)
end

local function wanted()
  if not RG.db or (RG.CardsOnly and RG.CardsOnly()) or (RG.IsAlt and RG.IsAlt()) then return false end
  if not (RG.Opt("buffReminder") or RG.Opt("buffConsumables")) then return false end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
  if UnitOnTaxi and UnitOnTaxi("player") then return false end
  return true
end

local function defs()
  local out = {}
  if not wanted() or inCombat() then return out end
  local auras = myAuras()
  if not auras then return out end
  local _, class = UnitClass("player")
  local mainOn, offOn = weaponEnchants()
  if RG.Opt("buffReminder") then
    for _, g in ipairs(CLASS[class] or {}) do
      if not snoozed[g.key] then
        local ic, spell = pickSpell(g)
        if spell then
          local st
          if g.weapon then
            st = true
            if mainOn == false and hasWeapon(16) then st = nil end
          else st = groupState(g, auras) end
          if st ~= true then
            out[#out + 1] = { key = g.key, icon = ic, state = st and "low" or "miss", big = st and mmss(st) or nil,
              secure = { type = "spell", spell = spell },
              tip = { spell, (g.weapon and "Nothing on your weapon." or (st and ("Runs out in " .. mmss(st) .. ".") or "Not on you.")) .. "\nClick to cast it" .. (g.weapon and "" or " on yourself") .. "." } }
          end
        end
      end
    end
    -- rogue poisons: a weapon in hand with nothing on it, and a poison in your bags
    if class == "ROGUE" and mainOn ~= nil then
      local items = bagItems()
      local function poison(order)
        for _, want in ipairs(order) do
          for _, it in ipairs(items) do if it.use and it.name:find(want, 1, true) then return it end end
        end
        for _, it in ipairs(items) do if it.use and (it.name:find(" Poison$") or it.name:find(" Poison [IVX]+$")) then return it end end
      end
      for _, h in ipairs({ { 16, mainOn, POISON_MAIN, "main hand" }, { 17, offOn, POISON_OFF, "off hand" } }) do
        local key = "poison" .. h[1]
        if not snoozed[key] and h[2] == false and hasWeapon(h[1]) then
          local it = poison(h[3])
          if it then
            out[#out + 1] = { key = key, icon = itemIcon(it.id), state = "miss", count = it.count,
              secure = { type = "macro", macrotext = "/use " .. it.name .. "\n/use " .. h[1] },
              tip = { it.name, "Nothing on your " .. h[4] .. " weapon.\nClick to put " .. it.name .. " on it." } }
          end
        end
      end
    end
  end
  if RG.Opt("buffConsumables") then
    local resting = IsResting and IsResting()
    local inInst, kind = false, nil
    if IsInInstance then inInst, kind = IsInInstance() end
    local dungeon = inInst and (kind == "party" or kind == "raid")
    local items
    -- Well Fed: out of town, when you carry food that gives it
    local fed = auras["Well Fed"]
    if not snoozed.food and not resting and not (fed == false or (fed and fed >= SOON)) then
      items = items or bagItems()
      for _, it in ipairs(items) do
        if it.use and givesWellFed(it.id) then
          out[#out + 1] = { key = "food", icon = itemIcon(it.id), state = fed and "low" or "item", count = it.count, big = fed and mmss(fed) or nil,
            secure = { type = "macro", macrotext = "/use " .. it.name },
            tip = { it.name, (fed and ("Well Fed runs out in " .. mmss(fed) .. ".") or "You're not Well Fed.") .. "\nClick to eat it (sit still while you eat)." } }
          break
        end
      end
    end
    -- elixirs, flasks and scrolls: in a dungeon or raid, one per effect
    if dungeon then
      items = items or bagItems()
      local seen = {}
      for _, it in ipairs(items) do
        local n = it.name
        if it.use and (n:find("Elixir", 1, true) or n:find("^Flask of") or n:find("^Scroll of")) and not snoozed["i" .. it.id] then
          local sp = itemSpell(it.id)
          local left = sp and auras[sp]
          if sp and not seen[sp] and not (left == false or (left and left >= SOON)) then
            seen[sp] = true
            out[#out + 1] = { key = "i" .. it.id, icon = itemIcon(it.id), state = left and "low" or "item", count = it.count, big = left and mmss(left) or nil,
              secure = { type = "macro", macrotext = "/use " .. n },
              tip = { n, (left and (sp .. " runs out in " .. mmss(left) .. ".") or ("You don't have " .. sp .. ".")) .. "\nClick to use it." } }
          end
        end
      end
    end
  end
  while #out > MAXB do table.remove(out) end
  return out
end
RG.BuffReminders = defs   -- (for tests and /wp buffs)

-- ---------------------------------------------------------------------------
-- The frames
-- ---------------------------------------------------------------------------
local holder, root, buttons = nil, nil, {}
local function font(fs, size) RG.Font(fs, "semibold", size, "OUTLINE"); fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1) end

local function makeButton(i)
  local b = CreateFrame("Button", "WaypathBuffButton" .. i, root, "SecureActionButtonTemplate")
  b:SetSize(SIZE, SIZE)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -1); b.glow:SetTexture(MEDIA .. "FishBtnGlow"); b.glow:SetBlendMode("ADD")
  b.glow:SetPoint("CENTER"); b.glow:SetSize(SIZE * 2, SIZE * 2)
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  pcall(function()
    local mk = b:CreateMaskTexture(); mk:SetAllPoints(b.icon)
    mk:SetTexture(MEDIA .. "FishBtnMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.icon:AddMaskTexture(mk)
  end)
  b.shade = b:CreateTexture(nil, "ARTWORK", nil, 2); b.shade:SetTexture(MEDIA .. "FishBtnShade"); b.shade:SetAllPoints()
  b.edge = b:CreateTexture(nil, "OVERLAY", nil, -1); b.edge:SetTexture(MEDIA .. "FishBtnFrame"); b.edge:SetPoint("CENTER"); b.edge:SetSize(SIZE * 1.12, SIZE * 1.12)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetTexture(MEDIA .. "FishBtnMask"); b.hl:SetAllPoints(); b.hl:SetBlendMode("ADD"); b.hl:SetVertexColor(1, 1, 1, 0.18)
  b.big = b:CreateFontString(nil, "OVERLAY"); font(b.big, 13); b.big:SetPoint("CENTER", 0, 0)
  b.cnt = b:CreateFontString(nil, "OVERLAY"); font(b.cnt, 11); b.cnt:SetPoint("BOTTOMRIGHT", -1, 2); b.cnt:SetJustifyH("RIGHT")
  -- right-click: an empty macro (nothing secure), and PostClick hides this one until the next login
  b:SetAttribute("type2", "macro"); b:SetAttribute("macrotext2", "")
  b:SetScript("PostClick", function(self, mouse, down)
    if down then return end
    local d = self.def
    if mouse == "RightButton" and d and d.key then
      snoozed[d.key] = true
      RG.Print(GREY .. "Buff reminder: " .. (d.tip and d.tip[1] or d.key) .. " hidden until you log in again. /wp buffs turns all of it off.|r")
    end
    if C_Timer then C_Timer.After(0.5, function() RG.BuffRefresh(true) end) end
  end)
  b:SetScript("OnEnter", function(self)
    local d = self.def
    if not (d and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(d.tip and d.tip[1] or "", 1, 0.93, 0.74)
    if d.tip and d.tip[2] then GameTooltip:AddLine(d.tip[2], 1, 1, 1, true) end
    GameTooltip:AddLine("Right-click: hide this one until you log in again", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local function paint(b, d)
  local c = EDGE[d.state] or EDGE.miss
  b.edge:SetVertexColor(c[1], c[2], c[3], 1)
  b.glow:SetVertexColor(c[1], c[2], c[3], 1); b.glow:SetAlpha(d.state == "miss" and 0.55 or 0.3)
  b.icon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  b.big:SetText(d.big or "")
  b.cnt:SetText((d.count and d.count > 1) and tostring(d.count) or "")
end
local function setSecure(b, s)
  b:SetAttribute("type1", s and s.type or nil)
  b:SetAttribute("spell1", s and s.spell or nil)
  b:SetAttribute("macrotext1", s and s.macrotext or nil)
  b:SetAttribute("unit1", (s and s.type == "spell") and "player" or nil)
end

local function build()
  if root or not CreateFrame or inCombat() then return root end
  -- the holder hides itself in a fight (the game's own secure switch); our row lives inside it
  holder = CreateFrame("Frame", "WaypathBuffHolder", UIParent, "SecureHandlerStateTemplate")
  holder:SetAllPoints(UIParent)
  if RegisterStateDriver then pcall(RegisterStateDriver, holder, "visibility", "[combat] hide; show") end
  root = CreateFrame("Frame", "WaypathBuffReminder", holder)
  root:SetSize(SIZE, SIZE); root:SetFrameStrata("MEDIUM"); root:SetClampedToScreen(true)
  root:SetPoint("TOP", UIParent, "TOP", 0, -150)
  root:Hide()
  for i = 1, MAXB do buttons[i] = makeButton(i); buttons[i]:Hide() end
  if RG.RegisterMover then
    RG.RegisterMover(root, "buffReminder", "Buff reminder", { "TOP", "TOP", 0, -150 }, function(f)
      local sample = { { icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", state = "miss" }, { icon = "Interface\\Icons\\INV_Misc_Fish_13", state = "item", count = 5 } }
      for i, b in ipairs(buttons) do
        if sample[i] then
          setSecure(b, nil); b.def = nil; paint(b, sample[i])
          b:ClearAllPoints(); b:SetPoint("LEFT", f, "LEFT", (i - 1) * (SIZE + GAP), 0); b:Show()
        else b:Hide() end
      end
      f:SetWidth(#sample * SIZE + (#sample - 1) * GAP)
    end, { done = function() if C_Timer then C_Timer.After(0, function() RG.BuffRefresh(true) end) end end })
  end
  return root
end

local last = 0
function RG.BuffRefresh(force)
  if not RG.db or inCombat() then return end
  if RG.MoversOn and RG.MoversOn() then return end   -- (being placed: leave the sample up)
  local now = GetTime()
  if not force and now - last < 0.4 then return end
  last = now
  local ok, list = pcall(defs)
  if not ok then if RG.RecordError then RG.RecordError("Buff reminder: " .. tostring(list)) end list = {} end
  if #list == 0 then if root then root:Hide() end return end
  if not build() then return end
  for i, b in ipairs(buttons) do
    local d = list[i]
    if d then
      b.def = d; setSecure(b, d.secure); paint(b, d)
      b:ClearAllPoints(); b:SetPoint("LEFT", root, "LEFT", (i - 1) * (SIZE + GAP), 0); b:Show()
    else
      b.def = nil; setSecure(b, nil); b:Hide()
    end
  end
  root:SetWidth(#list * SIZE + (#list - 1) * GAP)
  root:Show()
end

-- remember the one of a kind you cast last (that's the one the icon offers next time)
local function onCast(spellID)
  local ok, name = pcall(function()
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return GetSpellInfo and (GetSpellInfo(spellID)) or nil
  end)
  if not ok or type(name) ~= "string" or secret(name) then return end
  local _, class = UnitClass("player")
  for _, g in ipairs(CLASS[class] or {}) do
    for _, s in ipairs(g.cast) do if s == name then db().last[g.key] = name end end
  end
end

local dirty = true
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UNIT_AURA", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED",
  "UNIT_INVENTORY_CHANGED", "PLAYER_UPDATE_RESTING", "ZONE_CHANGED_NEW_AREA", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_CONTROL_GAINED",
  "UNIT_SPELLCAST_SUCCEEDED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, unit, _, spellID)
  if (event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED") and unit ~= "player" then return end
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    if unit == "player" and spellID and not secret(spellID) then onCast(spellID) end
    return
  end
  dirty = true
end)
-- (throttled: auras change a lot; the timers on the icons tick every second)
local acc = 0
ev:SetScript("OnUpdate", function(_, el)
  acc = acc + el
  if acc < (dirty and 0.5 or 1) then return end
  acc = 0
  if dirty or (root and root:IsShown()) then dirty = false; RG.BuffRefresh(true) end
end)

if RG.RegisterMoverMaker then RG.RegisterMoverMaker(function() build() end) end

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  if cmd and cmd:lower() == "buffs" then
    local on = not RG.Opt("buffReminder")
    RG.db.buffReminder, RG.db.buffConsumables = on, on
    RG.Print(GOLD .. "Buff reminder|r " .. (on and "on" or "off") .. GREY .. " (Options has one switch for your buffs and one for food and elixirs).|r")
    RG.BuffRefresh(true)
    return
  end
  return base(msg)
end
