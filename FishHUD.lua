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
local HUB, SLOT, MAXS = 44, 42, 9   -- (all about one size; the ring sits well clear of the middle button)
local OPEN_TIME, TWIST = 0.38, 1.5    -- opening: how long, and how far round the buttons spin on their way out
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

-- right-click the lure button: which lure to use (or the best one each time)
local function lureMenu()
  if RG.FishModeActive and RG.FishModeActive() and RG.FishModeExit then RG.FishModeExit() end   -- (the menu is on the interface)
  local skill = RG.FishSkill and RG.FishSkill() or 0
  local pick = RG.db.fishLurePick
  local entries = { { (pick and "" or (GREEN .. "> |r")) .. "The best one I carry, each time", function() RG.db.fishLurePick = nil; RG.FishHUDRefresh(true) end } }
  local list = {}
  for _, g in ipairs(RG.FISH_GEAR or {}) do if g.kind == "lure" and count(g.id) > 0 then list[#list + 1] = g end end
  table.sort(list, function(a, b) return a.bonus > b.bonus end)
  for _, g in ipairs(list) do
    local id = g.id
    local low = g.skill and skill < g.skill
    local ic = itemIcon(id)
    entries[#entries + 1] = { (pick == id and (GREEN .. "> |r") or "") .. (ic and ("|T" .. ic .. ":14:14|t ") or "") .. itemName(id) .. GREY .. "  +" .. g.bonus .. ", " .. g.mins .. " min, x" .. count(id) .. (low and ("  (needs Fishing " .. g.skill .. ")") or "") .. "|r",
      function() if low then RG.Print("That lure needs Fishing " .. g.skill .. ".") return end; RG.db.fishLurePick = id; RG.FishHUDRefresh(true) end }
  end
  if #list == 0 then entries[#entries + 1] = { GREY .. "No lures in your bags|r", function() end } end
  if RG.ShowMenu then RG.ShowMenu(entries, "Lure to use") end
end

local function lureDef()
  local d = { key = "lure", icon = "Interface\\Icons\\INV_Misc_Food_26", rfn = lureMenu, rclick = "choose which lure" }
  local id, g, buy = bestLure()
  local pick = RG.db and RG.db.fishLurePick
  if pick and count(pick) > 0 then id = pick end
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

-- What's in your bags, by name: { id, name, icon, count } for the first item whose name passes test(lowercase name).
-- (WoW Forever's campfires and camp objects are items you carry and use)
local function bagFind(test)
  local C = C_Container
  local slotsOf = (C and C.GetContainerNumSlots) or _G.GetContainerNumSlots
  local infoOf = C and C.GetContainerItemInfo
  if not (slotsOf and infoOf) then return nil end
  for bag = 0, 4 do
    for slot = 1, (slotsOf(bag) or 0) do
      local info = infoOf(bag, slot)
      local id = info and info.itemID
      if id then
        local name = info.itemName or (info.hyperlink and info.hyperlink:match("%[(.-)%]")) or (RG.ItemInfo and RG.ItemInfo(id))
        if type(name) == "string" and test(name:lower()) then
          return { id = id, name = name, icon = info.iconFileID or itemIcon(id), count = count(id) }
        end
      end
    end
  end
end
-- the best of several names: the first one found in your bags, then the first you know as a spell
local function bestOf(names)
  for _, n in ipairs(names) do
    local low = n:lower()
    local it = bagFind(function(x) return x == low or x:find(low, 1, true) ~= nil end)
    if it then return it end
  end
  for _, n in ipairs(names) do
    local ic, nm = known(n)
    if nm then return { spell = nm, name = nm, icon = ic } end
  end
end
local function useOf(it) return it.id and { type = "item", item = "item:" .. it.id } or { type = "spell", spell = it.spell } end

local function fireDef()
  local d = { key = "fire", icon = "Interface\\Icons\\Spell_Fire_Fire" }
  local names, woodOf = {}, {}
  for i = #(RG.CAMPFIRES or {}), 1, -1 do local f = RG.CAMPFIRES[i]; names[#names + 1] = f.name; woodOf[f.name:lower()] = f.wood end
  names[#names + 1] = "Campfire"
  local it = bestOf(names)
  local st, left = RG.CampState and RG.CampState()
  if not it then
    d.state = "off"; d.tip = { "Campfire", "No campfire in your bags and none learned yet. Basic Campfire comes with Cooking (Camping on the Professions tab)." }
    return d
  end
  d.icon, d.secure = it.icon or d.icon, useOf(it)
  local wood
  for n, w in pairs(woodOf) do if it.name:lower():find(n, 1, true) then wood = w end end
  local woodN = wood and count(wood) or nil
  d.count = it.id and it.count or woodN
  if st == "active" and left then d.state, d.big = "ready", mmss(left)
  else d.state = (cookMode and st ~= "near" and st ~= "sitting") and "main" or "ready" end
  d.tip = { it.name, (st == "active" and ("Camp Benefits: " .. RG.FmtLeft(left) .. " left.\n") or (st == "near" and "A fire is close by.\n" or "")) ..
    (wood and ("Needs " .. wood .. " (you have " .. (woodN or 0) .. "). ") or "") .. "Sit by it a minute for Camp Benefits." }
  return d
end

-- the camp object for fishing: the best you carry (Fishing Hut, Fishing Rack, Fish Bowl), or the one you picked
local FISH_OBJECTS = { "Fishing Hut", "Fishing Rack", "Fish Bowl", "Fishing Bowl" }
local function campMenu()
  if RG.FishModeActive and RG.FishModeActive() and RG.FishModeExit then RG.FishModeExit() end
  local entries = { { (cfg().campPick and "" or (GREEN .. "> |r")) .. "The best fishing one I carry, each time", function() cfg().campPick = nil; RG.FishHUDRefresh(true) end } }
  local seen = {}
  for _, o in ipairs(RG.CAMP_OBJECTS or {}) do
    local low = o.name:lower()
    local it = bagFind(function(x) return x:find(low, 1, true) ~= nil end)
    if it and not seen[it.id] then
      seen[it.id] = true
      local pick = it.name
      entries[#entries + 1] = { (cfg().campPick == pick and (GREEN .. "> |r") or "") .. (it.icon and ("|T" .. it.icon .. ":14:14|t ") or "") .. it.name .. GREY .. "  " .. (o.buff or "") .. "|r",
        function() cfg().campPick = pick; RG.FishHUDRefresh(true) end }
    end
  end
  if #entries == 1 then entries[#entries + 1] = { GREY .. "No camp objects in your bags|r", function() end } end
  if RG.ShowMenu then RG.ShowMenu(entries, "Camp object to place") end
end
local function campDef()
  local d = { key = "camp", icon = "Interface\\Icons\\INV_Misc_Bowl_01", rfn = campMenu, rclick = "choose which camp object" }
  local names = FISH_OBJECTS
  if cfg().campPick then names = { cfg().campPick, "Fishing Hut", "Fishing Rack", "Fish Bowl", "Fishing Bowl" } end
  local it = bestOf(names)
  if it then
    d.icon, d.state, d.secure, d.count = it.icon or d.icon, "ready", useOf(it), it.id and it.count or nil
    local buff
    for _, o in ipairs(RG.CAMP_OBJECTS or {}) do if it.name:lower():find(o.name:lower(), 1, true) then buff = o.buff end end
    d.tip = { "Place " .. it.name, (buff and (buff .. ". ") or "") .. "One camp object an hour, next to your campfire." }
  else
    d.state = "off"
    d.tip = { "Fish Bowl", "No fishing camp object in your bags. Fish Bowl comes at Fishing 20, the Fishing Rack at 140 (see Camping on the Professions tab)." }
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
  local d = { key = "cook", icon = "Interface\\Icons\\INV_Misc_Food_15" }   -- (a cooked meal: the spell's own icon on this client is a gem)
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
    local d = { key = "hub", state = "main", icon = "Interface\\Icons\\INV_Misc_Food_15" }
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
  -- your line is in the water: a click here would only throw it again, so it waits for the splash
  local info = RG.FishModeInfo and RG.FishModeInfo()
  if info and info.castEnd then
    local k = RG.FishKey and RG.FishKey()
    return { key = "hub", icon = ic or "Interface\\Icons\\Trade_Fishing", state = "main",
      tip = { "Watch your bobber", "At the splash, " .. (k and ("press " .. k .. " or ") or "") .. "right-click the bobber to hook the fish. Clicking here now would only cast again, so it waits." } }
  end
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
    GameTooltip:AddLine("Shift-drag: move the HUD", 0.5, 0.5, 0.5)
  else
    GameTooltip:AddLine(d.tip and d.tip[1] or "", 1, 0.93, 0.74)
    if d.tip and d.tip[2] then GameTooltip:AddLine(d.tip[2], 0.9, 0.9, 0.9, true) end
    if d.click then GameTooltip:AddLine("Click: " .. d.click, 0.6, 0.6, 0.6, true) end
    if d.rclick then GameTooltip:AddLine("Right-click: " .. d.rclick, 0.6, 0.6, 0.6, true) end
    GameTooltip:AddLine("Shift-drag: move the HUD", 0.5, 0.5, 0.5)
  end
  GameTooltip:Show()
end

local hoverUntil = 0
local function makeButton(name, size)
  local b = CreateFrame("Button", name, root, "SecureActionButtonTemplate")
  b:SetSize(size, size)
  b:RegisterForClicks("AnyUp", "AnyDown")
  -- a black rim, the coloured edge, then the icon: the edge reads clearly at any size
  b.black = b:CreateTexture(nil, "BACKGROUND"); b.black:SetPoint("TOPLEFT", -3, 3); b.black:SetPoint("BOTTOMRIGHT", 3, -3); b.black:SetColorTexture(0, 0, 0, 0.9)
  b.edge = b:CreateTexture(nil, "BORDER"); b.edge:SetPoint("TOPLEFT", -2, 2); b.edge:SetPoint("BOTTOMRIGHT", 2, -2)
  b.inner = b:CreateTexture(nil, "BORDER", nil, 1); b.inner:SetAllPoints(); b.inner:SetColorTexture(0, 0, 0, 1)
  b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -1); b.glow:SetTexture(MEDIA .. "Arcade\\Glow"); b.glow:SetBlendMode("ADD")
  b.glow:SetPoint("CENTER"); b.glow:SetSize(size * 1.9, size * 1.9); b.glow:Hide()
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.16)
  b.big = b:CreateFontString(nil, "OVERLAY"); font(b.big, 16); b.big:SetPoint("CENTER", 0, 0)
  b.cnt = b:CreateFontString(nil, "OVERLAY"); font(b.cnt, 12); b.cnt:SetPoint("BOTTOMRIGHT", -1, 2); b.cnt:SetJustifyH("RIGHT")
  b.keyt = b:CreateFontString(nil, "OVERLAY"); font(b.keyt, 11); b.keyt:SetPoint("TOPRIGHT", -2, -2); b.keyt:SetJustifyH("RIGHT")
  -- Shift + drag moves the whole HUD (out of a fight); a Shift-click does nothing, so a drag never casts
  b:SetAttribute("shift-type1", "macro"); b:SetAttribute("shift-macrotext1", "")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function()
    if not (IsShiftKeyDown and IsShiftKeyDown()) or inCombat() then return end
    root:SetMovable(true); root:SetClampedToScreen(true); root:StartMoving(); root.__dragging = true
  end)
  b:SetScript("OnDragStop", function()
    if not root.__dragging then return end
    root.__dragging = nil
    root:StopMovingOrSizing()
    -- kept like Edit Mode keeps it: by its middle, from the middle of the screen, in its own units
    local cx, cy = root:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local sc, us = root:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if cx and ux and not inCombat() then
      local x, y = math.floor(cx - ux * us / sc + 0.5), math.floor(cy - uy * us / sc + 0.5)
      RG.db.movers = RG.db.movers or {}
      RG.db.movers.fishHUD = { "CENTER", "CENTER", x, y }
      root:ClearAllPoints(); root:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
  end)
  b:SetScript("PostClick", function(self, mouse, down)
    if down or (IsShiftKeyDown and IsShiftKeyDown()) then return end
    local d = self.def
    local fn = d and ((mouse == "RightButton" and d.rfn) or (mouse ~= "RightButton" and not d.secure and d.fn) or (mouse == "RightButton" and not d.secure and d.fn))
    if fn then
      local ok, err = pcall(fn)
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
  b.icon:SetVertexColor(1, 1, 1, (d.state == "off") and 0.8 or 1)
  b.big:SetText(d.big or "")
  b.cnt:SetText(d.count and d.count > 0 and tostring(d.count) or "")
  -- (a key letter only when it's short, like R or F5: long names stay in the tooltip)
  b.keyt:SetText((d.keytext and #d.keytext <= 2) and d.keytext or "")
  b.glow:SetVertexColor(c[1], c[2], c[3], 1)
  b.glow:SetAlpha((d.state == "main" or d.state == "bad") and 0.55 or (d.state == "off" and 0 or 0.22)); b.glow:Show()
end
-- (a button with a right-click of its own: the right button does nothing secure, an empty macro, and PostClick runs it)
local function sameSecure(b, s, right)
  return (b.__type or false) == ((s and s.type) or false) and (b.__val or false) == ((s and (s.spell or s.macrotext or s.item)) or false) and (b.__right or false) == (right and true or false)
end
local function setSecure(b, s, right)
  if sameSecure(b, s, right) then return end
  b:SetAttribute("type", s and s.type or nil)
  b:SetAttribute("spell", s and s.spell or nil)
  b:SetAttribute("macrotext", s and s.macrotext or nil)
  b:SetAttribute("item", s and s.item or nil)
  b:SetAttribute("type2", right and "macro" or nil)
  b:SetAttribute("macrotext2", right and "" or nil)
  b.__type, b.__val, b.__right = (s and s.type) or false, (s and (s.spell or s.macrotext or s.item)) or false, right and true or false
end
-- (in a fight a button can only keep what it does; its picture and numbers still update)
local function apply(b, d, structural)
  if d.click == nil and d.key ~= "hub" then d.click = clickText(d) or false end
  if structural then setSecure(b, d.secure, d.rfn); b.def, b.dkey = d, d.key
  elseif b.dkey == d.key and sameSecure(b, d.secure, d.rfn) then b.def = d
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
    -- (clear of the middle button: about two and a half buttons out, more when there are many)
    local R = math.max(SLOT * 2.3, (SLOT + 14) * n / (2 * math.pi))
    for i = 1, n do
      local a = math.pi / 2 - (i - 1) / n * 2 * math.pi
      out[i] = { math.cos(a) * R, math.sin(a) * R }
    end
    return out, R
  elseif l == "bar" then
    for i = 1, n do out[i] = { HUB / 2 + 12 + SLOT / 2 + (i - 1) * (SLOT + 8), 0 } end
  else
    for i = 1, n do out[i] = { 0, -(HUB / 2 + 26 + SLOT / 2 + (i - 1) * (SLOT + 8)) } end
  end
  return out, 0
end

local function scale()
  local k = (UIParent and UIParent:GetEffectiveScale() or 1) / ((WorldFrame or UIParent):GetEffectiveScale() or 1)
  return k * (cfg().scale or 1)
end

local function wanted()
  if not RG.db or not RG.Opt("fishHud") or (RG.CardsOnly and RG.CardsOnly()) then return false end
  if RG.__fishHudPlace then return true end
  return RG.FishSkill and RG.FishSkill() ~= nil
end

-- Opening and closing: the buttons spin out from the middle one to their places on a rising swirl of water, and
-- spin back in when it closes. open = 0 (closed) .. 1 (open); target is where it's heading.
local open, target, finalPos, ringR = 0, 0, {}, 0
local ringBurst, ringAlpha, ringFull, ringAngle = 0, 0, 200, 0
local function ease(p) local q = 1 - p; return 1 - q * q * q end
local function place()
  local e = ease(open)
  local twist = (layout() == "ring") and (1 - e) * TWIST or 0
  for i, b in ipairs(slots) do
    local fp = rawget(b, "def") and finalPos[i]
    if fp and open > 0 then
      local x, y = fp[1], fp[2]
      local r, a = math.sqrt(x * x + y * y) * e, math.atan2(y, x) + twist
      b:ClearAllPoints(); b:SetPoint("CENTER", root, "CENTER", math.cos(a) * r, math.sin(a) * r)
      b:SetAlpha(math.min(1, open * 1.6)); b:SetScale(0.55 + 0.45 * e)
      if not b:IsShown() then b:Show() end
    elseif b:IsShown() then b:Hide() end
  end
end

function RG.FishHUDRefresh(force)
  if not RG.db then return end
  if not root then if not wanted() or not build() then return end end
  local combat = inCombat()
  local info = RG.FishModeInfo and RG.FishModeInfo() or {}
  local now = GetTime()
  local holding = RG.HasPole and RG.HasPole()
  local isOpen = RG.__fishHudPlace or cookMode or info.engaged or holding or now < hoverUntil
  local show = wanted() and (isOpen or RG.Opt("fishHudIdle") or open > 0)
  if not combat then
    if show and not root:IsShown() then root:Show() elseif not show and root:IsShown() then root:Hide() end
    local sc = scale(); if math.abs((root:GetScale() or 1) - sc) > 0.001 then root:SetScale(sc) end
  end
  if not show then return end
  -- Alt-Z hides the interface: the HUD goes with it (it sits on the game world)
  root:SetAlpha((UIParent and not UIParent:IsShown()) and 0 or 1)

  local defs, list = slotDefs()
  apply(hub, hubDef(list), not combat)
  local skill = RG.FishSkill and RG.FishSkill()
  skillText:SetText(cookMode and ((cookRank() and ("|cffffb060" .. cookRank() .. "|r")) or "") or (skill and tostring(skill) or ""))
  if not combat then
    local pos, R = positions(#defs)
    finalPos, ringR = pos, R
    for i, b in ipairs(slots) do
      local d = defs[i]
      if d then apply(b, d, true) else b.def, b.dkey = nil, nil end
    end
    target = isOpen and 1 or 0
    if force then place() end
    -- the water: as big as the ring
    local sz = ((layout() == "ring") and (R + SLOT / 2 + 30) or (HUB / 2 + 46)) * 2
    ringFull = sz
    -- floaters and the status line sit above the ring (or the middle button)
    local top = (layout() == "ring" and isOpen) and (R + SLOT / 2 + 10) or (HUB / 2 + 10)
    statusText:ClearAllPoints(); statusText:SetPoint("BOTTOM", root, "CENTER", 0, top)
    for i, f in ipairs(floaters) do f:ClearAllPoints(); f:SetPoint("BOTTOM", statusText, "TOP", 0, 2 + (i - 1) * 16) end
  else
    -- (in a fight the buttons keep what they do; their pictures and numbers still update)
    for i, b in ipairs(slots) do if b:IsShown() and defs[i] then apply(b, defs[i], false) end end
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

-- every frame: opening and closing, the water, the cast timer; four times a second: everything else
local driver = CreateFrame("Frame")
local acc, refreshFailed, counting = 0, false, false
local function step(_, dt)
  acc = acc + dt
  if root and root:IsShown() then
    -- open or close a little more (buttons can only move outside a fight)
    if open ~= target and not inCombat() then
      local was = open
      open = target > open and math.min(1, open + dt / OPEN_TIME) or math.max(0, open - dt / (OPEN_TIME * 0.8))
      ringBurst = 1   -- (the swirl rises with every opening and closing)
      if was ~= open then place() end
    end
    local info = RG.FishModeInfo and RG.FishModeInfo()
    local left, total = 0, 1
    if info and info.castStart and info.castEnd and info.castEnd > info.castStart then left, total = math.max(0, info.castEnd - GetTime()), info.castEnd - info.castStart end
    local lit = math.ceil(ARCN * left / total)
    for i = 1, ARCN do if i <= lit then arc[i]:Show() else arc[i]:Hide() end end
    -- the swirl: strong while opening or closing, then it settles; faint while your line is in the water
    local burst = ringBurst
    if open == target then burst = math.max(0, burst - dt * 1.6) end
    ringBurst = burst
    local want = math.max(burst * 0.95, (left > 0 and open > 0.5) and 0.28 or 0)
    local cur = ringAlpha
    cur = want > cur and math.min(want, cur + dt * 4) or math.max(want, cur - dt * 1.2)
    ringAlpha = cur
    if cur > 0.01 then
      local e = ease(open)
      local sz = ringFull * (0.35 + 0.75 * e)
      ring:SetSize(sz, sz); ring:SetAlpha(cur); ring:Show()
      if ring.SetRotation then ringAngle = (ringAngle - dt * (1.2 + 2.5 * burst)) % (2 * math.pi); ring:SetRotation(ringAngle) end
    elseif ring:IsShown() then ring:Hide() end
    -- the seconds left on the middle button
    if left > 0 and not cookMode then hub.big:SetText(tostring(math.ceil(left))); hub.icon:SetAlpha(0.5); counting = true
    elseif counting then counting = false; hub.big:SetText(""); hub.icon:SetAlpha(1) end
  end
  if acc < 0.25 then return end
  acc = 0
  if RG.FishModeRefresh then pcall(RG.FishModeRefresh) end
  local ok, err = pcall(RG.FishHUDRefresh)
  if not ok and not refreshFailed then refreshFailed = true; if RG.RecordError then RG.RecordError(err) end end
end
driver:SetScript("OnUpdate", step)
RG.__fishHudStep = step   -- (tests)

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
