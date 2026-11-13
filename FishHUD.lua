-- Waypath+ fishing HUD: one button in the middle (cast, or put your pole on) with your fishing buttons around it,
-- each showing the game's own icon, a coloured edge for its state and its count or time left on it.
--   Layouts: a ring (the default), a bar or a column (/wp fishhud ring | bar | column, or the Fishing tab).
--   Idle it's only the middle button; casting, holding your pole or hovering opens the rest.
--   Cook mode: the Cook button puts your raw fish around the middle; pick one and the middle button cooks it,
--   one per click, at a fire (the fire button is there too).
-- Edges: green ready, orange the main action or your pick, red can't right now, grey not in your bags or not known.
-- Every action is a secure button or a plain button under your own click: nothing casts, cooks or buys by itself.
-- Buttons change only out of combat, as the game requires; in a fight the HUD keeps what it had.
-- The water ring behind it is our own drawing (tools/media/fishring.py). The general idea (a ring of action buttons
-- around one) comes from fishing HUDs like FishFry; nothing of theirs is used.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
local ORANGE, RED = "|cffff8040", "|cffff4040"

table.insert(RG.OPTIONS, { key = "fishHud", label = "Fishing HUD: your fishing buttons around one button (move it in Edit Mode)", default = true })
table.insert(RG.OPTIONS, { key = "fishHudIdle", label = "Keep the fishing HUD's middle button on screen when I'm not fishing", default = true })

local MEDIA = "Interface\\AddOns\\Waypath\\Media\\"
local EDGE = { ready = { 0.32, 0.78, 0.36 }, main = { 0.96, 0.56, 0.17 }, bad = { 0.92, 0.22, 0.22 }, off = { 0.42, 0.42, 0.38 } }
local HUB, SLOT, MAXS = 32, 28, 9   -- (tight: the buttons almost touch, like an action bar bent round)
local LAYOUTS = { "ring", "bar", "column" }

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function cfg() RG.db.fishHudCfg = RG.db.fishHudCfg or {}; return RG.db.fishHudCfg end
local function layout() local l = RG.db and cfg().layout; return (l == "bar" or l == "column") and l or "ring" end

-- ---------------------------------------------------------------------------
-- Small helpers: icons, counts, known spells
-- ---------------------------------------------------------------------------
local function count(item) local f = (C_Item and C_Item.GetItemCount) or GetItemCount; return (f and f(item)) or 0 end
local function itemIcon(id)
  if not id then return nil end
  if C_Item and C_Item.GetItemIconByID then local ic = C_Item.GetItemIconByID(id); if ic then return ic end end
  if GetItemIcon then local ic = GetItemIcon(id); if ic then return ic end end
  return RG.ItemInfo and select(10, RG.ItemInfo(id)) or nil
end
local function itemName(id) return (RG.ItemInfo and RG.ItemInfo(id)) or ("item " .. tostring(id)) end
-- a spell you know, by name: its icon and its name (nil when you don't know it)
local function known(name)
  local ok, ic, n = pcall(function()
    if C_Spell and C_Spell.GetSpellInfo then local i = C_Spell.GetSpellInfo(name); if i then return i.iconID or i.originalIconID, i.name end return nil end
    if GetSpellInfo then local nm, _, icon = GetSpellInfo(name); return icon, nm end
  end)
  if ok and n then return ic or "Interface\\Icons\\INV_Misc_QuestionMark", n end
  return nil
end
local function mmss(sec)
  sec = math.max(0, math.floor(sec + 0.5))
  if sec >= 3600 then return math.floor(sec / 3600) .. "h" end
  if sec >= 60 then return math.floor(sec / 60) .. "m" end
  return tostring(sec)
end
local function cookRank() local p = RG.Professions and RG.Professions().Cooking; return p and p.rank or nil end

-- ---------------------------------------------------------------------------
-- What each button is: { key, icon, state, big, count, keytext, desat, secure = {type, spell | macrotext}, fn, tip = {...} }
-- ---------------------------------------------------------------------------
local cookMode = false
local cookOpen = false   -- the Cooking window is open

local function bestLure()
  local skill = RG.FishSkill and RG.FishSkill() or 0
  local have, haveG, buy
  for _, g in ipairs(RG.FISH_GEAR or {}) do
    if g.kind == "lure" then
      if count(g.id) > 0 and (not g.skill or skill >= g.skill) and (not haveG or g.bonus > haveG.bonus) then have, haveG = g.id, g end
      if g.how and g.how:find("vendor") and (not g.skill or skill >= g.skill) and (not buy or g.bonus > buy.bonus) then buy = g end
    end
  end
  return have, haveG, buy
end

local function lureDef()
  local d = { key = "lure", icon = "Interface\\Icons\\INV_Misc_Food_26" }
  local id, g, buy = bestLure()
  if id then d.icon = itemIcon(id) or d.icon; d.count = count(id) end
  if not (RG.HasPole and RG.HasPole()) then
    d.state = "off"; d.tip = { "Lure", "Put your fishing pole on first: a lure goes on the pole." }
    return d
  end
  local left, bonus = RG.FishLure()
  local choice = RG.FishBoostChoice and RG.FishBoostChoice().lure
  if left and left >= 60 then
    d.state, d.big = "ready", mmss(left)
    d.tip = { "Lure on your pole", (bonus and ("+" .. bonus .. " Fishing skill, ") or "") .. RG.FmtLeft(left) .. " left." .. (id and ("\nYou have " .. d.count .. " more.") or "") }
  elseif choice then
    d.state, d.secure = left and "main" or "ready", { type = "macro", macrotext = choice.macro }
    if left then d.big = mmss(left) end
    d.tip = { choice.title, choice.tip .. (left and ("\nYours runs out in " .. RG.FmtLeft(left) .. ".") or "") }
  else
    d.state = left and "ready" or "off"
    if left then d.big = mmss(left) end
    d.tip = { "Lure", left and (RG.FmtLeft(left) .. " left. No more lures in your bags.") or
      ("No lure in your bags." .. (buy and ("\n" .. itemName(buy.id) .. " (+" .. buy.bonus .. "): " .. buy.how .. ".") or "")) }
  end
  return d
end

local function foodDef()
  local d = { key = "food", icon = "Interface\\Icons\\INV_Misc_Fish_13" }
  local choice = RG.FishBoostChoice and RG.FishBoostChoice().food
  local fed
  for _, b in ipairs(RG.FishBuffs and RG.FishBuffs() or {}) do if b.key == "food" then fed = b end end
  if choice then
    d.icon, d.state, d.secure = choice.icon or d.icon, fed and "main" or "ready", { type = "macro", macrotext = choice.macro }
    if fed and fed.left then d.big = mmss(fed.left) end
    d.tip = { choice.title, choice.tip }
  elseif fed then
    d.icon, d.state = fed.icon or d.icon, "ready"
    if fed.left then d.big = mmss(fed.left) end
    d.tip = { fed.label, fed.tip }
  else
    d.state = "off"; d.tip = { "Food", "No cooked fish in your bags. Cook some (the Cook button) for Well Fed." }
  end
  return d
end

local function outfitDef()
  local holding = RG.HasPole and RG.HasPole()
  local pole; if RG.FishOutfitState then pole = select(2, RG.FishOutfitState()) end
  local d = { key = "outfit" }
  if holding then
    local main = RG.db and RG.db.fishTools and RG.db.fishTools.normal and RG.db.fishTools.normal[16]
    d.icon = (main and itemIcon(main)) or "Interface\\Icons\\INV_Sword_04"
    d.state, d.fn = "ready", function() RG.FishGearOff() end
    d.tip = { "Weapons back", "Puts your weapons and gear back on. A fight does it for you too.\n/wp weapons" }
  elseif pole then
    d.icon, d.state, d.fn = itemIcon(pole) or "Interface\\Icons\\INV_Fishingpole_02", "ready", function() RG.FishGearOn() end
    d.tip = { "Go fishing", "Puts on " .. itemName(pole) .. " and any fishing gear in your bags.\n/wp gofish" }
  else
    d.icon, d.state = "Interface\\Icons\\INV_Fishingpole_02", "off"
    d.tip = { "Fishing pole", "No fishing pole in your bags. Any fishing vendor sells one (Fishing tab)." }
  end
  return d
end

local function fireDef()
  local d = { key = "fire", icon = "Interface\\Icons\\Spell_Fire_Fire" }
  local best
  for _, f in ipairs(RG.CAMPFIRES or {}) do
    local ic, n = known(f.name)
    if n then best = { f = f, icon = ic, name = n } end
  end
  local st, left = RG.CampState and RG.CampState()
  if not best then
    d.state = "off"; d.tip = { "Campfire", "Learn Cooking to make a campfire (Basic Campfire)." }
    return d
  end
  d.icon, d.count = best.icon, count(best.f.wood)
  d.secure = { type = "spell", spell = best.name }
  if st == "active" and left then d.state, d.big = "ready", mmss(left)
  elseif d.count == 0 then d.state = "bad"
  else d.state = (cookMode and st ~= "near" and st ~= "sitting") and "main" or "ready" end
  d.tip = { best.name, (st == "active" and ("Camp Benefits: " .. RG.FmtLeft(left) .. " left.\n") or (st == "near" and "A fire is close by.\n" or "")) ..
    "Needs " .. best.f.wood .. " (you have " .. d.count .. ") and Flint and Tinder. Sit by it a minute for Camp Benefits." }
  return d
end

local function campDef()
  local d = { key = "camp", icon = "Interface\\Icons\\INV_Misc_Bowl_01" }
  local pick = RG.CampPick and RG.CampPick()
  local name = pick and pick.name or "Fish Bowl"
  local ic, n = known(name)
  if n then
    d.icon, d.state, d.secure = ic, "ready", { type = "spell", spell = n }
    d.tip = { "Place " .. n, (pick and pick.why and (pick.why .. ". ") or "") .. "One camp object an hour, next to your campfire." }
  else
    d.state = "off"
    d.tip = { name, "Your best camp object" .. (pick and pick.why and (" (" .. pick.why .. ")") or "") .. ". You haven't learned it yet: see Camping on the Professions tab." }
  end
  return d
end

local function findDef()
  local ic, n = known("Find Fish")
  if not n then return nil end
  return { key = "find", icon = ic, state = "ready", secure = { type = "spell", spell = n }, tip = { n, "Shows fishing pools on your minimap." } }
end

local function guideDef()
  return { key = "guide", icon = "Interface\\Icons\\INV_Misc_Book_09", state = "ready",
    fn = function() if RG.FishModeExit then RG.FishModeExit() end; if RG.ShowTab then RG.ShowTab("fish") end end,
    tip = { "Fishing guide", "Where to fish next, poles, lures and your goals (the Fishing tab)." } }
end

-- your raw fish that cook into something, best for your skill first
local function cookList()
  local out = {}
  local rank = cookRank() or 0
  local RANK = { optimal = 1, medium = 2, easy = 3, trivial = 4 }
  for _, c in ipairs(RG.FISH_COOK or {}) do
    local have = count(c.id)
    if have > 0 then
      local st = RG.CookState and RG.CookState(c.dish)
      local can = rank >= (c.cook or 1) and st ~= "missing"
      out[#out + 1] = { c = c, have = have, st = st, can = can, order = can and (RANK[st or ""] or 3.5) or 9 }
    end
  end
  table.sort(out, function(a, b) if a.order ~= b.order then return a.order < b.order end return (a.c.cook or 0) > (b.c.cook or 0) end)
  return out
end
local function picked(list)
  local want = cfg().cookPick
  for _, e in ipairs(list) do if e.c.dish == want and e.can then return e end end
  for _, e in ipairs(list) do if e.can then return e end end
end
local function cookDef(total)
  local ic = known("Cooking")
  local d = { key = "cook", icon = ic or "Interface\\Icons\\INV_Misc_Food_15" }
  if cookMode then
    d.state, d.fn = "main", function() RG.FishHUDCook(false) end
    d.tip = { "Back to fishing", "Puts your fishing buttons back." }
  elseif not ic then
    d.state = "off"; d.tip = { "Cooking", "Learn Cooking from a trainer to cook your catch." }
  else
    d.state, d.count = "ready", total > 0 and total or nil
    d.fn = function() RG.FishHUDCook(true) end
    d.tip = { "Cook your catch", total > 0 and (total .. " raw fish in your bags cook into something. Click to put them around the middle button.") or "No raw fish in your bags yet." }
  end
  return d
end

-- cook the picked fish: with the Cooking window open, one per click
local function craft(dish)
  if GetNumTradeSkills and GetTradeSkillInfo and DoTradeSkill then
    for i = 1, (GetNumTradeSkills() or 0) do
      local name, kind = GetTradeSkillInfo(i)
      if name == dish and kind ~= "header" then
        if SelectTradeSkill then pcall(SelectTradeSkill, i) end
        DoTradeSkill(i, 1); return true
      end
    end
  end
  if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.CraftRecipe then
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
      local info = C_TradeSkillUI.GetRecipeInfo(id)
      if info and info.name == dish then C_TradeSkillUI.CraftRecipe(id, 1); return true end
    end
  end
  RG.Print("You don't know the recipe for " .. dish .. " yet.")
  return false
end

local function hubDef(list)
  if cookMode then
    local e = picked(list)
    local d = { key = "hub", state = "main", icon = known("Cooking") or "Interface\\Icons\\INV_Misc_Food_15" }
    if not e then
      d.state = "off"; d.tip = { "Nothing to cook", "None of your raw fish cook into something you know yet." }
      return d
    end
    d.icon, d.count = itemIcon(e.c.id) or d.icon, e.have
    if cookOpen then
      d.fn = function() craft(e.c.dish) end
      d.tip = { "Cook " .. e.c.dish, "One per click (" .. e.have .. " raw). You need a fire close by." }
    else
      local _, n = known("Cooking")
      d.secure = { type = "spell", spell = n or "Cooking" }
      d.tip = { "Cook " .. e.c.dish, "Click to open Cooking, then click again to cook one at a time. You need a fire close by." }
    end
    return d
  end
  if not (RG.HasPole and RG.HasPole()) then
    local pole; if RG.FishOutfitState then pole = select(2, RG.FishOutfitState()) end
    if pole then
      return { key = "hub", icon = itemIcon(pole) or "Interface\\Icons\\INV_Fishingpole_02", state = "main", fn = function() RG.FishGearOn() end,
        tip = { "Go fishing", "Puts on " .. itemName(pole) .. " and your fishing gear. Click again to cast." } }
    end
    return { key = "hub", icon = "Interface\\RaidFrame\\ReadyCheck-NotReady", state = "bad",
      tip = { "No fishing pole", "Buy one from any fishing vendor (the Fishing tab has where). The middle button casts once it's in your hands." } }
  end
  local ic, n = known(RG.FishSpellName and RG.FishSpellName() or "Fishing")
  return { key = "hub", icon = ic or "Interface\\Icons\\Trade_Fishing", state = "main", secure = { type = "spell", spell = n or "Fishing" },
    keytext = RG.FishKey and RG.FishKey() or nil, tip = "cast" }
end

-- what a click does, for the tooltip's last line
local CLICK = { lure = "put it on your pole", food = "eat it", fire = "light the fire", camp = "place it by your fire", guide = "open the Fishing tab",
  find = "show fishing pools on the minimap" }
local function clickText(d)
  if not (d.secure or d.fn) then return nil end
  if d.key == "outfit" then return d.tip and d.tip[1] == "Weapons back" and "put your weapons back" or "put your pole and fishing gear on" end
  if d.key == "cook" then return cookMode and "back to your fishing buttons" or "your raw fish around the middle button" end
  if d.key and d.key:find("^fish%d") then return "cook this one with the middle button" end
  return CLICK[d.key]
end
local function slotDefs()
  local list = cookList()
  local total = 0
  for _, e in ipairs(list) do if e.can then total = total + e.have end end
  local out = {}
  if cookMode then
    out[#out + 1] = fireDef()
    local e0 = picked(list)
    for _, e in ipairs(list) do
      if #out >= MAXS - 1 then break end
      local st = (e0 and e == e0) and "main" or (not e.can and "bad" or ((e.st == "trivial") and "off" or "ready"))
      local skillTxt = not e.can and (RED .. "needs Cooking " .. (e.c.cook or "?") .. (e.st == "missing" and " and the recipe" or "") .. "|r")
        or (e.st == "optimal" and (ORANGE .. "skill up every time|r") or (e.st == "medium" and ("|cffffff00usually a skill up|r") or (e.st == "easy" and (GREEN .. "sometimes a skill up|r") or (GREY .. "no skill left|r"))))
      local dish = e.c.dish
      out[#out + 1] = { key = "fish" .. e.c.id, icon = itemIcon(e.c.id), state = st, count = e.have, desat = not e.can,
        fn = function() if e.can then cfg().cookPick = dish; RG.FishHUDRefresh(true) end end,
        tip = { dish, e.have .. " raw  ·  " .. skillTxt .. (e.c.note and ("\n" .. e.c.note) or "") } }
    end
    out[#out + 1] = cookDef(total)
    return out, list
  end
  out[#out + 1] = lureDef()
  out[#out + 1] = outfitDef()
  out[#out + 1] = foodDef()
  out[#out + 1] = campDef()
  out[#out + 1] = guideDef()
  local f = findDef(); if f then out[#out + 1] = f end
  out[#out + 1] = fireDef()
  out[#out + 1] = cookDef(total)
  return out, list
end

-- ---------------------------------------------------------------------------
-- The frames
-- ---------------------------------------------------------------------------
local root, hub, slots, ring, arc, skillText, floaters, statusText
local function font(fs, size) RG.Font(fs, "semibold", size, "OUTLINE"); fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1) end

local function setTip(self)
  local d = self.def
  if not (d and GameTooltip) then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  if d.tip == "cast" then
    local skill, max = RG.FishSkill()
    GameTooltip:AddLine("Cast Fishing", 1, 0.93, 0.74)
    if skill then GameTooltip:AddLine("Fishing " .. skill .. (max and max > 0 and (" / " .. max) or ""), 1, 1, 1) end
    local z = RG.FishZone and RG.FishZone()
    if z then GameTooltip:AddLine(z.zone .. ": " .. (z.status == "all" and (GREEN .. "every fish bites|r") or (z.status == "some" and (ORANGE .. "some get away|r") or (RED .. "too low here|r"))) .. GREY .. "  (" .. z.eff .. " of " .. z.full .. ")|r", 1, 1, 1) end
    local s = RG.FishSession and RG.FishSession()
    if s and s.catches > 0 then GameTooltip:AddLine("This session: " .. s.catches .. " fish" .. ((s.value or 0) > 0 and (", " .. RG.FishMoney(s.value)) or "") .. (s.gained > 0 and (", +" .. s.gained .. " skill") or ""), 0.85, 0.85, 0.85) end
    local best = RG.FishBest and RG.FishBest()
    if best and best.list and best.list[1] then
      local bits = {}
      for i = 1, math.min(3, #best.list) do bits[#bits + 1] = best.list[i].name .. string.format(" %.0f%%", best.list[i].chance) end
      GameTooltip:AddLine("Here: " .. table.concat(bits, "  ·  "), 0.85, 0.85, 0.85, true)
      if best.bestEv and best.bestEv.ev > 0 then GameTooltip:AddLine("Worth the most: " .. best.bestEv.name, 0.5, 0.9, 0.5) end
    end
    local k = RG.FishKey and RG.FishKey()
    GameTooltip:AddLine(k and ("Click or press " .. k .. " to cast; " .. k .. " again at the splash hooks it.") or "Click to cast. Pick a one-key fishing key on the Fishing tab.", 0.6, 0.6, 0.6, true)
    local bk = GetBindingKey and GetBindingKey("CLICK WaypathFishHUDHub:LeftButton")
    GameTooltip:AddLine("Key for this button: " .. (bk or "none (Key Bindings, Waypath+)"), 0.6, 0.6, 0.6)
  else
    GameTooltip:AddLine(d.tip and d.tip[1] or "", 1, 0.93, 0.74)
    if d.tip and d.tip[2] then GameTooltip:AddLine(d.tip[2], 0.9, 0.9, 0.9, true) end
    if d.click then GameTooltip:AddLine("Click: " .. d.click, 0.6, 0.6, 0.6, true) end
  end
  GameTooltip:Show()
end

local hoverUntil = 0
local function makeButton(name, size)
  local b = CreateFrame("Button", name, root, "SecureActionButtonTemplate")
  b:SetSize(size, size)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b.black = b:CreateTexture(nil, "BACKGROUND"); b.black:SetPoint("TOPLEFT", -2, 2); b.black:SetPoint("BOTTOMRIGHT", 2, -2); b.black:SetColorTexture(0, 0, 0, 0.85)
  b.edge = b:CreateTexture(nil, "BORDER"); b.edge:SetPoint("TOPLEFT", -1.5, 1.5); b.edge:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
  b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -1); b.glow:SetTexture(MEDIA .. "Arcade\\Glow"); b.glow:SetBlendMode("ADD")
  b.glow:SetPoint("CENTER"); b.glow:SetSize(size * 2.1, size * 2.1); b.glow:Hide()
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.16)
  b.big = b:CreateFontString(nil, "OVERLAY"); font(b.big, size >= HUB and 15 or 13); b.big:SetPoint("CENTER", 0, 0)
  b.cnt = b:CreateFontString(nil, "OVERLAY"); font(b.cnt, 10); b.cnt:SetPoint("BOTTOMRIGHT", 0, 1); b.cnt:SetJustifyH("RIGHT")
  b.keyt = b:CreateFontString(nil, "OVERLAY"); font(b.keyt, 9); b.keyt:SetPoint("TOPRIGHT", 0, -1); b.keyt:SetJustifyH("RIGHT")
  b:SetScript("PostClick", function(self, _, down)
    if down then return end
    local d = self.def
    if d and d.fn and not d.secure then
      local ok, err = pcall(d.fn)
      if not ok and RG.RecordError then RG.RecordError(err) end
      if C_Timer then C_Timer.After(0.3, function() RG.FishHUDRefresh(true) end) end
    end
  end)
  b:SetScript("OnEnter", function(self) hoverUntil = GetTime() + 4; setTip(self); if self == hub then RG.FishHUDRefresh(true) end end)
  b:SetScript("OnLeave", function() hoverUntil = GetTime() + 3; if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local function paint(b, d)
  local c = EDGE[d.state or "ready"] or EDGE.ready
  b.edge:SetColorTexture(c[1], c[2], c[3], 1)
  b.icon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  b.icon:SetDesaturated((d.state == "off" or d.desat) and true or false)
  b.icon:SetVertexColor(1, 1, 1, (d.state == "off") and 0.75 or 1)
  b.big:SetText(d.big or "")
  b.cnt:SetText(d.count and d.count > 0 and tostring(d.count) or "")
  b.keyt:SetText(d.keytext and (#d.keytext > 4 and d.keytext:sub(-3) or d.keytext) or "")
  if d.state == "main" or d.state == "bad" then b.glow:SetVertexColor(c[1], c[2], c[3], 1); b.glow:SetAlpha(0.45); b.glow:Show() else b.glow:Hide() end
end
local function sameSecure(b, s)
  return (b.__type or false) == ((s and s.type) or false) and (b.__val or false) == ((s and (s.spell or s.macrotext)) or false)
end
local function setSecure(b, s)
  if sameSecure(b, s) then return end
  b:SetAttribute("type", s and s.type or nil)
  b:SetAttribute("spell", s and s.spell or nil)
  b:SetAttribute("macrotext", s and s.macrotext or nil)
  b.__type, b.__val = (s and s.type) or false, (s and (s.spell or s.macrotext)) or false
end
-- (in a fight a button can only keep what it does; its picture and numbers still update)
local function apply(b, d, structural)
  if d.click == nil and d.key ~= "hub" then d.click = clickText(d) or false end
  if structural then setSecure(b, d.secure); b.def, b.dkey = d, d.key
  elseif b.dkey == d.key and sameSecure(b, d.secure) then b.def = d
  else return end
  paint(b, d)
end

local ARCN = 48
local function build()
  if root or not CreateFrame or inCombat() then return root end
  local parent = WorldFrame or UIParent
  root = CreateFrame("Frame", "WaypathFishHUD", parent)
  root:SetSize(HUB, HUB); root:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
  root:SetFrameStrata("MEDIUM"); root:Hide()
  -- the water behind the ring
  ring = root:CreateTexture(nil, "BACKGROUND", nil, -8); ring:SetTexture(MEDIA .. "FishRing"); ring:SetPoint("CENTER"); ring:SetAlpha(0); ring:Hide()
  -- the cast timer: a ring of dots around the middle button
  arc = {}
  for i = 1, ARCN do
    local t = root:CreateTexture(nil, "ARTWORK", nil, 1); t:SetSize(3, 3); t:SetColorTexture(0.45, 0.8, 1, 0.95)
    local a = math.pi / 2 - (i - 1) / ARCN * 2 * math.pi
    t:SetPoint("CENTER", root, "CENTER", math.cos(a) * (HUB / 2 + 5), math.sin(a) * (HUB / 2 + 5)); t:Hide()
    arc[i] = t
  end
  hub = makeButton("WaypathFishHUDHub", HUB); hub:SetPoint("CENTER")
  skillText = root:CreateFontString(nil, "OVERLAY"); font(skillText, 12); skillText:SetPoint("TOP", hub, "BOTTOM", 0, -3); skillText:SetTextColor(0.44, 0.88, 0.66)
  slots = {}
  for i = 1, MAXS do slots[i] = makeButton("WaypathFishHUDSlot" .. i, SLOT); slots[i]:Hide() end
  statusText = root:CreateFontString(nil, "OVERLAY"); font(statusText, 11)
  floaters = {}
  for i = 1, 3 do floaters[i] = root:CreateFontString(nil, "OVERLAY"); font(floaters[i], 11); floaters[i]:Hide() end
  if RG.RegisterMover then
    RG.RegisterMover(root, "fishHUD", "Fishing HUD", { "BOTTOM", "BOTTOM", 0, 200 }, function() RG.__fishHudPlace = true; RG.FishHUDRefresh(true) end,
      { done = function() RG.__fishHudPlace = nil; RG.FishHUDRefresh(true) end })
  end
  return root
end

-- where the buttons go around the middle one
local function positions(n)
  local out, l = {}, layout()
  if l == "ring" then
    local R = math.max(42, (SLOT + 5) * n / (2 * math.pi))
    for i = 1, n do
      local a = math.pi / 2 - (i - 1) / n * 2 * math.pi
      out[i] = { math.cos(a) * R, math.sin(a) * R }
    end
    return out, R
  elseif l == "bar" then
    for i = 1, n do out[i] = { HUB / 2 + 8 + SLOT / 2 + (i - 1) * (SLOT + 5), 0 } end
  else
    for i = 1, n do out[i] = { 0, -(HUB / 2 + 22 + SLOT / 2 + (i - 1) * (SLOT + 5)) } end
  end
  return out, 0
end

local function scale()
  local k = (UIParent and UIParent:GetEffectiveScale() or 1) / ((WorldFrame or UIParent):GetEffectiveScale() or 1)
  return k * (cfg().scale or 1)
end

local laid, lastN, lastLayout, dirty = false, 0, nil, false
local function wanted()
  if not RG.db or not RG.Opt("fishHud") or (RG.CardsOnly and RG.CardsOnly()) then return false end
  if RG.__fishHudPlace then return true end
  return RG.FishSkill and RG.FishSkill() ~= nil
end

function RG.FishHUDRefresh(force)
  if not RG.db then return end
  if not root then if not wanted() or not build() then return end end
  local combat = inCombat()
  local info = RG.FishModeInfo and RG.FishModeInfo() or {}
  local now = GetTime()
  local holding = RG.HasPole and RG.HasPole()
  local open = RG.__fishHudPlace or cookMode or info.engaged or holding or now < hoverUntil
  local show = wanted() and (open or RG.Opt("fishHudIdle"))
  if not combat then
    if show and not root:IsShown() then root:Show() elseif not show and root:IsShown() then root:Hide() end
    local sc = scale(); if math.abs((root:GetScale() or 1) - sc) > 0.001 then root:SetScale(sc) end
  end
  if not show then return end
  -- Alt-Z hides the interface: the HUD goes with it (it sits on the game world)
  root:SetAlpha((UIParent and not UIParent:IsShown()) and 0 or 1)

  local defs, list = slotDefs()
  local structural = not combat
  apply(hub, hubDef(list), structural)
  local skill = RG.FishSkill and RG.FishSkill()
  skillText:SetText(cookMode and ((cookRank() and ("|cffffb060" .. cookRank() .. "|r")) or "") or (skill and tostring(skill) or ""))
  local n = open and #defs or 0
  if structural then
    local pos, R = positions(#defs)
    for i, b in ipairs(slots) do
      local d = defs[i]
      if d and i <= n then
        apply(b, d, true)
        if not laid or lastN ~= #defs or lastLayout ~= layout() or force then b:ClearAllPoints(); b:SetPoint("CENTER", root, "CENTER", pos[i][1], pos[i][2]) end
        b:Show()
      else b:Hide(); b.def, b.dkey = nil, nil end
    end
    laid, lastN, lastLayout = true, #defs, layout()
    -- the water ring: the ring layout, while your line is in the water (it fades in and out, below)
    ring.want = layout() == "ring" and n > 0
    if ring.want then local s = (R + SLOT / 2 + 18) * 2; ring:SetSize(s, s) end
    -- floaters and the status line sit above the top button
    local top = (layout() == "ring" and n > 0) and (R + SLOT / 2 + 8) or (HUB / 2 + 8)
    statusText:ClearAllPoints(); statusText:SetPoint("BOTTOM", root, "CENTER", 0, top)
    for i, f in ipairs(floaters) do f:ClearAllPoints(); f:SetPoint("BOTTOM", statusText, "TOP", 0, 2 + (i - 1) * 16) end
    dirty = false
  else
    for i, b in ipairs(slots) do if b:IsShown() and defs[i] then apply(b, defs[i], false) end end
    dirty = true
  end
  -- what's happening: a whisper, "got away", then your last catches rising and fading
  if info.whisper then statusText:SetText("|cffff80ffWhisper from " .. info.whisper .. "|r" .. GREY .. ": press Enter|r")
  elseif info.status then statusText:SetText((info.statusColor or "|cffffffff") .. info.status .. "|r")
  else statusText:SetText("") end
  local fi = 0
  for _, e in ipairs(info.feed or {}) do
    local age = now - e.t
    if age < 12 and fi < 3 then
      fi = fi + 1
      local f = floaters[fi]
      f:SetText(e.text); f:SetAlpha(age < 8 and 1 or math.max(0, 1 - (age - 8) / 4)); f:Show()
    end
  end
  for i = fi + 1, 3 do floaters[i]:Hide() end
end

-- every frame: the cast timer and the turning water; four times a second: everything else
local driver = CreateFrame("Frame")
local acc, refreshFailed = 0, false
driver:SetScript("OnUpdate", function(_, dt)
  acc = acc + dt
  if root and root:IsShown() then
    local info = RG.FishModeInfo and RG.FishModeInfo()
    local lit = 0
    if info and info.castStart and info.castEnd and info.castEnd > info.castStart then
      lit = math.ceil(ARCN * math.max(0, info.castEnd - GetTime()) / (info.castEnd - info.castStart))
    end
    for i = 1, ARCN do if i <= lit then arc[i]:Show() else arc[i]:Hide() end end
    -- the water: in while the line is in the water, out after
    local target = (lit > 0 and ring.want) and 0.9 or 0
    local cur = ring.alpha or 0
    if cur ~= target then
      cur = target > cur and math.min(target, cur + dt * 2.5) or math.max(target, cur - dt * 1.5)
      ring.alpha = cur; ring:SetAlpha(cur)
      if cur > 0 then ring:Show() else ring:Hide() end
    end
    if cur > 0 and ring.SetRotation then ring.__a = ((ring.__a or 0) + dt * 0.35) % (2 * math.pi); ring:SetRotation(ring.__a) end
    -- the seconds left on the middle button
    if lit > 0 and not cookMode then hub.big:SetText(tostring(math.ceil(info.castEnd - GetTime()))); hub.icon:SetAlpha(0.45); hub.__counting = true
    elseif hub.__counting then hub.__counting = nil; hub.big:SetText(""); hub.icon:SetAlpha(1) end
  end
  if acc < 0.25 then return end
  acc = 0
  if RG.FishModeRefresh then pcall(RG.FishModeRefresh) end
  local ok, err = pcall(RG.FishHUDRefresh)
  if not ok and not refreshFailed then refreshFailed = true; if RG.RecordError then RG.RecordError(err) end end
end)

-- cook mode on and off
function RG.FishHUDCook(on)
  if inCombat() then RG.Print("Not during a fight.") return end
  cookMode = on and true or false
  if not cookMode then hoverUntil = GetTime() + 3 end
  RG.FishHUDRefresh(true)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if not RG.db then return end
  if event == "TRADE_SKILL_SHOW" then
    local ok, line = pcall(function() return GetTradeSkillLine and GetTradeSkillLine() end)
    cookOpen = ok and line == "Cooking" or false
    if cookOpen and cookMode then
      -- the picked fish is shown in the window too
      local e = picked(cookList())
      if e and GetNumTradeSkills and SelectTradeSkill then
        for i = 1, (GetNumTradeSkills() or 0) do if GetTradeSkillInfo(i) == e.c.dish then pcall(SelectTradeSkill, i) break end end
      end
    end
  elseif event == "TRADE_SKILL_CLOSE" then cookOpen = false end
  if event == "PLAYER_LOGIN" then build() end
  pcall(RG.FishHUDRefresh, true)
end)

-- /wp fishhud [ring | bar | column | size 80-150 | idle | off | on | reset]
local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
  if cmd and cmd:lower() == "fishhud" then
    rest = (rest or ""):lower()
    local c = cfg()
    if rest == "ring" or rest == "bar" or rest == "column" then c.layout = rest; RG.Print("Fishing HUD: " .. rest .. ".")
    elseif rest:match("^size") then
      local pct = tonumber(rest:match("(%d+)"))
      if pct then c.scale = math.max(0.6, math.min(1.6, pct / 100)) end
      RG.Print("Fishing HUD size: " .. math.floor((c.scale or 1) * 100 + 0.5) .. "%  (/wp fishhud size 80 to 160)")
    elseif rest == "idle" then RG.db.fishHudIdle = not RG.Opt("fishHudIdle"); RG.Print("Middle button when you're not fishing: " .. (RG.db.fishHudIdle and "shown." or "hidden."))
    elseif rest == "off" or rest == "on" then RG.db.fishHud = rest == "on"; RG.Print("Fishing HUD " .. rest .. ".")
    elseif rest == "reset" then c.scale, c.layout = nil, nil; if RG.db.movers then RG.db.movers.fishHUD = nil end; RG.Print("Fishing HUD back to the ring, its usual size and place (a /reload puts it back in place).")
    else RG.Print("/wp fishhud ring | bar | column  ·  size 80-160  ·  idle  ·  on | off  ·  reset. Move it in Edit Mode or with /wp move.") end
    if inCombat() then RG.Print("It changes when the fight is over.") end
    RG.FishHUDRefresh(true)
    return
  end
  return base(msg)
end

-- the Fishing tab's line: the layout now, and the next one
function RG.FishHUDLayout() return RG.Opt("fishHud") and layout() or nil end
function RG.FishHUDNextLayout()
  if not RG.Opt("fishHud") then RG.db.fishHud = true; cfg().layout = "ring"
  else
    local l = layout()
    if l == "column" then RG.db.fishHud = false
    else for i, x in ipairs(LAYOUTS) do if x == l then cfg().layout = LAYOUTS[i + 1] break end end end
  end
  RG.FishHUDRefresh(true)
end
