-- Waypath+ 2nd spec: pick any spec of your class as your second spec (dual spec
-- unlocks at level 40 in WoW Forever). Waypath+ scores gear with that spec's
-- weights, tracks the best piece you own for every slot as your 2nd set, lists
-- what to hunt for from level 30 on, never sells or auctions that set, and
-- swaps it on when you change spec (QoL2.lua).
--
-- Spec data (builds, weights, tips): Classes/Specs.lua. Generated gear lists:
-- Classes/SpecGear.lua. The leveling spec uses the class's own gear guide.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY

table.insert(RG.OPTIONS, { key = "healSet", label = "Collect a gear set for my 2nd spec (2nd Spec tab)", default = true })

-- ---------------------------------------------------------------------------
-- Which spec
-- ---------------------------------------------------------------------------
-- Paladins had a Holy set before there was a choice: they keep it by default.
local LEGACY_DEFAULT = { PALADIN = "holy" }

function RG.SpecList() return (RG.SPECS or {})[RG.PLAYER_CLASS] or {} end
local invalidate
-- The spec you level as. Pick it in setup or on the Spec tab; until you do, it is the class's usual leveling spec.
local function dataMain()
  for _, s in ipairs(RG.SpecList()) do if s.main then return s end end
end
function RG.MainSpecChosen()
  local by = RG.db and RG.db.mainSpecByClass
  return by and by[RG.PLAYER_CLASS] ~= nil and ((RG.SPEC_BY or {})[RG.PLAYER_CLASS] or {})[by[RG.PLAYER_CLASS]] ~= nil
end
function RG.MainSpec()
  local by = RG.db and RG.db.mainSpecByClass
  local key = by and by[RG.PLAYER_CLASS]
  local chosen = key and ((RG.SPEC_BY or {})[RG.PLAYER_CLASS] or {})[key]
  return chosen or dataMain()
end
function RG.IsMainSpec(s) local m = RG.MainSpec(); return s ~= nil and m ~= nil and s.key == m.key end
-- Is the main spec one that melees or tanks? (seal and blessing reminders only make sense then)
function RG.MainIsMelee() local m = RG.MainSpec(); return not m or m.kind == "melee" or m.kind == "tank" end

local C0 = RG.ActiveClass or {}
local W0, HIT0, MODEL0, SCORE0 = RG.DEFAULT_WEIGHTS, RG.DEFAULT_HIT_CAP, RG.WEAPON_MODEL, RG.SCORE_NAME
-- Make everything follow the main spec: stat weights, weapon model, gear guide, score name.
-- fresh = the player just picked it: replace the saved weights too (they belonged to the old spec).
function RG.ApplyMainSpec(quiet, fresh)
  local m = RG.MainSpec()
  if not m then return end
  local default = dataMain()
  local isDefault = (not default) or m.key == default.key
  if isDefault then
    RG.DEFAULT_WEIGHTS, RG.WEAPON_MODEL, RG.SCORE_NAME = W0, MODEL0, SCORE0
  else
    RG.DEFAULT_WEIGHTS = m.weights or W0
    RG.WEAPON_MODEL = m.model or C0.model or MODEL0
    RG.SCORE_NAME = m.name .. " score"
  end
  RG.DEFAULT_HIT_CAP = HIT0
  local dw = RG.WEAPON_MODEL == "DW" or RG.PLAYER_CLASS == "HUNTER"
  RG.EQUIP_SLOTS.INVTYPE_WEAPON = dw and { 16, 17 } or { 16 }
  if RG.BuildGuide then RG.BuildGuide(not isDefault and m.key or nil) end
  if RG.GuideByID then
    for k in pairs(RG.GuideByID) do RG.GuideByID[k] = nil end
    for _, g in ipairs(RG.GUIDE or {}) do if g.id then RG.GuideByID[g.id] = g end end
  end
  if fresh and RG.db then
    local w = RG.db.weights
    if w then
      for k in pairs(w) do w[k] = nil end
      for k, v in pairs(RG.DEFAULT_WEIGHTS) do w[k] = v end
    end
  end
  if RG.ClearScoreCache then RG.ClearScoreCache() end
end
function RG.SetMainSpec(key)
  local by = (RG.SPEC_BY or {})[RG.PLAYER_CLASS]
  if not (by and by[key]) then return end
  RG.db.mainSpecByClass = RG.db.mainSpecByClass or {}
  RG.db.mainSpecByClass[RG.PLAYER_CLASS] = key
  RG.db.secondSpecByClass = RG.db.secondSpecByClass or {}
  if RG.db.secondSpecByClass[RG.PLAYER_CLASS] == key or (RG.db.secondSpecByClass[RG.PLAYER_CLASS] == nil and LEGACY_DEFAULT[RG.PLAYER_CLASS] == key) then
    RG.db.secondSpecByClass[RG.PLAYER_CLASS] = false
  end
  RG.db.healBank = {}
  RG.ApplyMainSpec(false, true)
  if invalidate then invalidate() end
  RG.Print("You level as " .. GOLD .. by[key].name .. "|r. Gear scores and the Gear guide now follow it.")
  if RG.RefreshUI then RG.RefreshUI() end
  if RG.RefreshTracker then RG.RefreshTracker() end
end
function RG.SecondSpec()
  local db = RG.db
  if not db then return nil end
  db.secondSpecByClass = db.secondSpecByClass or {}
  local key = db.secondSpecByClass[RG.PLAYER_CLASS]
  if key == nil then key = LEGACY_DEFAULT[RG.PLAYER_CLASS] end
  local by = (RG.SPEC_BY or {})[RG.PLAYER_CLASS]
  return key and key ~= false and by and by[key] or nil
end
function RG.SetSecondSpec(key)
  RG.db.secondSpecByClass = RG.db.secondSpecByClass or {}
  RG.db.secondSpecByClass[RG.PLAYER_CLASS] = key or false
  RG.db.healBank = {}   -- the bank memory was scored for the old spec; it refills next bank visit
  if invalidate then invalidate() end
  local s = RG.SecondSpec()
  if s then RG.Print("2nd spec set to " .. GOLD .. s.name .. "|r. The 2nd Spec tab now lists " .. s.name .. " gear to collect.") end
  if RG.RefreshUI then RG.RefreshUI() end
end
-- A 2nd set only makes sense for a spec other than the one you level with.
local function active()
  local s = RG.SecondSpec()
  return s and not RG.IsMainSpec(s) and s or nil
end
RG.SecondSpecActive = active
local function on() return RG.Opt("healSet") and not RG.IsAlt() and active() ~= nil end
RG.SecondSetOn = on

function RG.SpecWeights(s)
  s = s or active()
  if not s then return nil end
  if RG.IsMainSpec(s) then return RG.DEFAULT_WEIGHTS end
  return s.weights or {}
end
function RG.SpecModel(s)
  s = s or active()
  return s and (s.model or (RG.ActiveClass and RG.ActiveClass.model)) or RG.WEAPON_MODEL
end

-- Can this spec use it? (class armor and weapons, then the spec's own weapon list and shield)
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
local function specCanUse(link, s)
  if not RG.CanUse(link) then return false end
  if not (s and GetItemInfoInstant) then return true end
  local _, _, _, _, _, classID, subID = GetItemInfoInstant(link)
  if classID == 2 and s.weapons and subID ~= 14 and subID ~= 20 then
    for _, w in ipairs(s.weapons) do if w == subID then return true end end
    return false
  elseif classID == 4 and subID == 6 then
    return s.shield and true or false
  end
  return true
end

-- Score an item for your 2nd spec (or any spec you pass).
function RG.SpecScore(link, s)
  s = s or active()
  if not (link and s) then return 0 end
  if not specCanUse(link, s) then return 0 end
  return RG.Score(link, nil, nil, RG.SpecWeights(s), RG.SpecModel(s))
end

-- ---------------------------------------------------------------------------
-- What to collect: hand-written entries first, then the generated list
-- ---------------------------------------------------------------------------
-- Hand-written healing list for Holy paladins (crafts, AH finds and the pieces
-- the old Healing tab listed); generated lists cover every other spec.
RG.SPEC_HAND = {
  PALADIN = { holy = {
    { id = 7720,  slot = "Head",      lvl = 39, how = "Drop",  src = "High Inquisitor Whitemane", zone = "Scarlet Monastery Cathedral" },
    { id = 7722,  slot = "Neck",      lvl = 39, how = "Drop",  src = "High Inquisitor Whitemane", zone = "Scarlet Monastery Cathedral" },
    { id = 7721,  slot = "Main Hand", lvl = 39, how = "Drop",  src = "High Inquisitor Whitemane", zone = "Scarlet Monastery Cathedral", note = "+15 healing mace, your first real healing weapon" },
    { id = 18083, slot = "Hands",     lvl = 42, how = "Drop",  src = "Witch Doctor Zum'rah", zone = "Zul'Farrak" },
    { id = 17755, slot = "Waist",     lvl = 45, how = "Drop",  src = "Lord Vyletongue", zone = "Maraudon" },
    { id = 17748, slot = "Feet",      lvl = 46, how = "Drop",  src = "Razorlash", zone = "Maraudon" },
    { id = 17737, slot = "Off Hand",  lvl = 48, how = "Drop",  src = "Landslide", zone = "Maraudon" },
    { id = 17715, slot = "Head",      lvl = 49, how = "Drop",  src = "Princess Theradras", zone = "Maraudon" },
    { id = 10751, slot = "Head",      lvl = 50, approx = true, how = "Quest", src = "The God Hakkar", zone = "Sunken Temple" },
    { id = 11923, slot = "Main Hand", lvl = 54, approx = true, how = "Drop", src = "Chest of The Seven", zone = "Blackrock Depths", note = "Pre-raid healing mace" },
    { id = 11928, slot = "Off Hand",  lvl = 55, approx = true, how = "Drop", src = "Emperor Dagran Thaurissan", zone = "Blackrock Depths" },
    { id = 12633, slot = "Head",      lvl = 57, approx = true, how = "Crafted", bs = 300, src = "Blacksmithing 300 (Whitesoul Helm plan)", zone = "Your own anvil", note = "You can make this yourself" },
    { id = 18702, slot = "Waist",     lvl = 58, approx = true, how = "BoE", ah = true, src = "Rare world drop (Scholomance trash)", zone = "Auction House" },
    { id = 13346, slot = "Chest",     lvl = 58, approx = true, how = "Drop", src = "Baron Rivendare", zone = "Stratholme" },
    { id = 16058, slot = "Ring",      lvl = 58, approx = true, how = "Quest", src = "In Dreams (Western Plaguelands chain)", zone = "Western Plaguelands" },
  } },
}
local SPEC_FROM = 28
local guideCache = {}
function RG.SpecGuide(s)
  s = s or active()
  if not s then return {} end
  local ck = s.class .. ":" .. s.key
  if guideCache[ck] then return guideCache[ck] end
  local out, have = {}, {}
  for _, g in ipairs(((RG.SPEC_HAND[s.class] or {})[s.key]) or {}) do out[#out + 1] = g; have[g.id] = true end
  local gen = (s.main and RG.IsMainSpec(s)) and ((RG.CLASS_GEAR or {})[s.class] or {}) or (((RG.SPEC_GEAR or {})[s.class] or {})[s.key] or {})
  for _, g in ipairs(gen) do
    if not have[g.id] and g.lvl >= SPEC_FROM then
      local e = {}
      for k, v in pairs(g) do e[k] = v end
      if e.slot == "2H" then e.slot = "Two-Hand" end
      out[#out + 1] = e; have[g.id] = true
    end
  end
  table.sort(out, function(a, b) if a.lvl ~= b.lvl then return a.lvl < b.lvl end return (a.score or 0) > (b.score or 0) end)
  guideCache[ck] = out
  return out
end
function RG.SpecGuideByID(id)
  for _, g in ipairs(RG.SpecGuide()) do if g.id == id then return g end end
end

-- ---------------------------------------------------------------------------
-- Your 2nd set: the best piece you own for each slot
-- ---------------------------------------------------------------------------
local LOC_GROUP = {
  INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder", INVTYPE_CLOAK = "Back",
  INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest", INVTYPE_WRIST = "Wrist", INVTYPE_HAND = "Hands",
  INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_FINGER = "Ring",
  INVTYPE_TRINKET = "Trinket", INVTYPE_WEAPON = "Main Hand", INVTYPE_WEAPONMAINHAND = "Main Hand",
  INVTYPE_2HWEAPON = "Two-Hand", INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_HOLDABLE = "Off Hand",
  INVTYPE_SHIELD = "Off Hand", INVTYPE_RELIC = "Relic", INVTYPE_RANGED = "Ranged", INVTYPE_RANGEDRIGHT = "Ranged",
  INVTYPE_THROWN = "Ranged",
}
RG.SPEC_LOC_GROUP = LOC_GROUP
local BASE_SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Ring", "Ring", "Trinket", "Trinket", "Main Hand", "Off Hand" }
function RG.SpecSlots(s)
  s = s or active()
  local out = {}
  for i, v in ipairs(BASE_SLOTS) do out[i] = v end
  local w = RG.SpecWeights(s) or {}
  if (w.RANGED_DPS or 0) > 0 then out[#out + 1] = "Ranged" end
  return out
end
RG.HEAL_SLOTS = BASE_SLOTS
local SLOT_COUNT = { Ring = 2, Trinket = 2 }
local MIN_SCORE = 4 -- anything under this isn't really gear for the spec (items on the list always count)

local C = C_Container
local function numSlots(bag) return ((C and C.GetContainerNumSlots) or GetContainerNumSlots)(bag) or 0 end

local function collect(s)
  RG.db.healBank = RG.db.healBank or {}
  local pieces, seen = {}, {}
  local function add(link, where)
    if not link then return end
    local loc = RG.EquipLoc(link)
    local group = loc and LOC_GROUP[loc]
    if not group then return end
    local score = RG.SpecScore(link, s)
    local id = tonumber(link:match("item:(%d+)"))
    if score < MIN_SCORE and not (RG.SpecGuideByID(id) and specCanUse(link, s)) then return end
    local key = link .. where
    if seen[key] then return end
    seen[key] = true
    pieces[#pieces + 1] = { link = link, id = id, group = group, score = score, where = where }
  end
  for slot = 1, 18 do add(GetInventoryItemLink("player", slot), "worn") end
  for bag = 0, 4 do
    for slot = 1, numSlots(bag) do
      local info = C and C.GetContainerItemInfo and C.GetContainerItemInfo(bag, slot)
      if info and info.hyperlink then add(info.hyperlink, "bags") end
    end
  end
  for _, link in ipairs(RG.db.healBank) do add(link, "bank") end
  return pieces
end

-- set[group] = { piece, piece } sorted best first, plus the set's total score.
local setCache, setStamp
local EMPTY = { set = {}, total = 0, keep = {} }
function RG.SpecSet()
  local s = active()
  if not s then return EMPTY.set, EMPTY.total, EMPTY.keep end
  if setStamp and GetTime() - setStamp < 1 and setCache.spec == s then return setCache.set, setCache.total, setCache.keep end
  setStamp = GetTime()
  local set, keep, total = {}, {}, 0
  for _, p in ipairs(collect(s)) do set[p.group] = set[p.group] or {}; table.insert(set[p.group], p) end
  local dw = RG.SpecModel(s) == "DW"
  for group, list in pairs(set) do
    table.sort(list, function(a, b) return a.score > b.score end)
    local n = SLOT_COUNT[group] or ((dw and group == "Main Hand") and 2 or 1)
    for i = n + 1, #list do list[i] = nil end
  end
  -- Dual wielders: the second-best one-hander can go in the off hand.
  if dw and set["Main Hand"] and set["Main Hand"][2] then
    local second = table.remove(set["Main Hand"], 2)
    local oh = set["Off Hand"] and set["Off Hand"][1]
    if not oh or second.score > oh.score then set["Off Hand"] = { second } end
  end
  -- A two-hander competes with main hand + off hand together.
  local mh = set["Main Hand"] and set["Main Hand"][1]
  local oh = set["Off Hand"] and set["Off Hand"][1]
  local th = set["Two-Hand"] and set["Two-Hand"][1]
  if th and th.score > (mh and mh.score or 0) + (oh and oh.score or 0) then set["Main Hand"] = { th }; set["Off Hand"] = nil
  else set["Two-Hand"] = nil end
  for _, list in pairs(set) do for _, p in ipairs(list) do total = total + p.score; if p.id then keep[p.id] = true end end end
  setCache = { set = set, total = total, keep = keep, spec = s }
  return set, total, keep
end
invalidate = function() setStamp = nil end
RG.SpecInvalidate = invalidate

-- Is this item part of your 2nd set? (so nothing sells it)
function RG.IsSpecKeeper(id)
  if not on() or not id then return false end
  local _, _, keep = RG.SpecSet()
  return keep[id] and true or false
end

-- How much would this item add to your 2nd set?
function RG.SpecDelta(link)
  if not active() then return nil end
  local loc = RG.EquipLoc(link)
  local group = loc and LOC_GROUP[loc]
  if not group then return nil end
  local score = RG.SpecScore(link)
  if score <= 0 then return nil end
  local set = RG.SpecSet()
  local id = tonumber(link:match("item:(%d+)"))
  if group == "Two-Hand" then
    local cur = 0
    for _, g in ipairs({ "Main Hand", "Off Hand" }) do local p = set[g] and set[g][1]; if p then cur = cur + p.score end end
    return score - cur, group, score
  end
  local list = set[group] or {}
  for _, p in ipairs(list) do if p.id == id then return 0, group, score, true end end
  local n = SLOT_COUNT[group] or 1
  local worst = (#list >= n) and list[#list].score or 0
  return score - worst, group, score
end

-- Old names, still used around the add-on.
RG.HealSet, RG.HealScore, RG.HealDelta, RG.IsHealKeeper, RG.HealInvalidate = RG.SpecSet, RG.SpecScore, RG.SpecDelta, RG.IsSpecKeeper, invalidate

-- ---------------------------------------------------------------------------
-- Tooltip: 2nd spec score and whether to keep it
-- ---------------------------------------------------------------------------
local function icon(s) return "|T" .. (s.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":14:14:0:0:64:64:5:59:5:59|t " end
local function OnTooltip(tooltip, data)
  if not on() or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then return end
  if (UnitLevel("player") or 1) < 25 then return end
  local link
  if tooltip.GetItem then link = select(2, tooltip:GetItem()) end
  if not link and data and data.id then link = select(2, RG.ItemInfo(data.id)) end
  if not link then return end
  local loc = RG.EquipLoc(link)
  if not (loc and LOC_GROUP[loc]) then return end
  local s = active()
  local score = RG.SpecScore(link)
  local g = RG.SpecGuideByID(tonumber(link:match("item:(%d+)")))
  if score < MIN_SCORE and not g then return end
  local delta, group, _, inSet = RG.SpecDelta(link)
  local right
  if inSet then right = GREEN .. "in your " .. s.name .. " set, keep it|r"
  elseif delta and delta > 0.5 then right = GREEN .. string.format("+%.0f %s set upgrade", delta, s.name) .. "|r"
  else right = GREY .. "not better than your " .. s.name .. " " .. (group or "") .. "|r" end
  tooltip:AddDoubleLine(icon(s) .. "|cffF58CBA" .. s.name .. " score|r  " .. string.format("%.0f", score), right)
  if g then tooltip:AddLine(GREY .. "On your " .. s.name .. " list: " .. g.src .. ", " .. g.zone .. "|r", 1, 1, 1, true) end
  tooltip:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)
elseif GameTooltip and GameTooltip.HookScript then
  GameTooltip:HookScript("OnTooltipSetItem", OnTooltip)
end

-- ---------------------------------------------------------------------------
-- Bank memory, toasts for new pieces, dual spec reminder
-- ---------------------------------------------------------------------------
local function readBank()
  local out = {}
  if not active() then return end
  for _, bag in ipairs({ -1, 5, 6, 7, 8, 9, 10, 11 }) do
    for slot = 1, numSlots(bag) do
      local info = C and C.GetContainerItemInfo and C.GetContainerItemInfo(bag, slot)
      if info and info.hyperlink then
        local loc = RG.EquipLoc(info.hyperlink)
        if loc and LOC_GROUP[loc] and RG.SpecScore(info.hyperlink) >= MIN_SCORE then out[#out + 1] = info.hyperlink end
      end
    end
  end
  RG.db.healBank = out
  invalidate()
end

local known, knownSpec = nil, nil
local function checkNew()
  if not on() or (UnitLevel("player") or 1) < 30 then return end
  local s = active()
  local _, _, keep = RG.SpecSet()
  if known and knownSpec == s then
    for id in pairs(keep) do
      if not known[id] then
        local name, link, _, _, _, _, _, _, _, tex = RG.ItemInfo(id)
        local isWorn = false
        for slot = 1, 18 do local l = GetInventoryItemLink("player", slot); if l and tonumber(l:match("item:(%d+)")) == id then isWorn = true end end
        local p = link and RG.SpecScore(link) or 0
        if not isWorn and p >= 8 and RG.Toast then
          RG.Toast(s.name .. " set upgrade", (link or name or "New item") .. " is now in your " .. s.name .. " set. Waypath+ won't sell it.", tex, nil, nil, 6)
        end
      end
    end
  end
  known, knownSpec = {}, s
  for id in pairs(keep) do known[id] = true end
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED", "BANKFRAME_CLOSED" }) do pcall(f.RegisterEvent, f, e) end
local bankOpen = false
f:SetScript("OnEvent", function(_, event)
  if not RG.db or RG.IsAlt() then return end
  if event == "BANKFRAME_OPENED" then bankOpen = true; readBank()
  elseif event == "BANKFRAME_CLOSED" then if bankOpen then readBank() end; bankOpen = false
  elseif event == "PLAYERBANKSLOTS_CHANGED" then if bankOpen then readBank() end
  elseif event == "PLAYER_LOGIN" then C_Timer.After(4, function() invalidate(); checkNew() end); return
  else
    if bankOpen and event == "BAG_UPDATE_DELAYED" then readBank() end
    invalidate()
    RG.Debounce("healCheck", 0.6, checkNew)
  end
  if RG.RefreshUI then RG.RefreshUI() end
end)

local function hasDualSpec()
  if GetNumTalentGroups then return (GetNumTalentGroups() or 1) > 1 end
  if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecGroups then return (C_SpecializationInfo.GetNumSpecGroups() or 1) > 1 end
  return nil
end
RG.HasDualSpec = hasDualSpec
RG.DUAL_SPEC_LEVEL = 40

local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  local s = active()
  if s and not RG.IsAlt() and (UnitLevel("player") or 1) >= RG.DUAL_SPEC_LEVEL and hasDualSpec() == false and not RG.db.dualSpecSeen then
    out[#out + 1] = { icon(s) .. GOLD .. "Dual spec is unlocked|r" .. GREY .. "  (learn it at your class trainer; click to hide)|r", function() RG.db.dualSpecSeen = true; if RG.ShowTab then RG.ShowTab("spec") end end, 4 }
  end
  return out
end

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
  cmd = cmd and cmd:lower()
  if cmd == "heal" or cmd == "holy" or cmd == "spec" or cmd == "spec2" then
    rest = (rest or ""):lower()
    if rest ~= "" then
      for _, s in ipairs(RG.SpecList()) do
        if s.key == rest or s.name:lower():find(rest, 1, true) == 1 then RG.SetSecondSpec(s.key); break end
      end
    end
    local tab = ((cmd == "heal" or cmd == "holy") and rest == "") and "heal" or "spec"
    if RG.ShowTab then RG.ShowTab(tab) end
    return
  end
  return base(msg)
end

-- Existing characters never picked a main spec: ask once, never assume silently.
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function()
    local function ask()
      if not RG.db or RG.db.specAsked or not RG.db.setupDone or (RG.IsAlt and RG.IsAlt()) then return end
      if #RG.SpecList() < 2 or (RG.MainSpecChosen and RG.MainSpecChosen()) then return end
      RG.db.specAsked = true
      RG.Print("Which spec do you level as? Waypath+ is assuming " .. GOLD .. (RG.MainSpec() and RG.MainSpec().name or "your usual spec") .. "|r. Pick yours on the Spec tab: /wp spec")
    end
    if C_Timer and C_Timer.After then C_Timer.After(8, ask) end
  end)
end
