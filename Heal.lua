-- RetGear Healing: a Holy off-set for dual spec (unlocks at level 40 in WoW Forever).
-- Scores healing gear, tracks the best healing piece you own for every slot,
-- lists what to hunt for from level 40 on, and makes sure you don't vendor
-- or auction your healing set by accident.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local HOLY_ICON = "|TInterface\\Icons\\Spell_Holy_HolyBolt:14:14:0:0:64:64:5:59:5:59|t "

table.insert(RG.OPTIONS, { key = "healSet", label = "Collect a healing set for dual spec (Healing tab)", default = true })
local function on() return RG.Opt("healSet") end

-- Holy Paladin stat values in "healing power" (Classic-style: +Healing first,
-- then Intellect, MP5 and spell crit; Spirit and Stamina barely matter).
RG.HEAL_WEIGHTS = { HEAL = 1, INT = 0.6, MP5 = 2.2, SCRIT = 13, SPI = 0.25, STA = 0.05 }

function RG.HealScore(link)
  local s = link and RG.GetStats(link)
  if not s then return 0 end
  local w = RG.HEAL_WEIGHTS
  return (s.HEAL or 0) * w.HEAL + (s.INT or 0) * w.INT + (s.MP5 or 0) * w.MP5 + (s.SCRIT or 0) * w.SCRIT
    + (s.SPI or 0) * w.SPI + (s.STA or 0) * w.STA
end

-- Healing gear to look for from level 40, Horde-friendly.
-- lvl = level you can wear it (approx = roughly); how = Drop/Quest/Crafted/BoE.
-- These are Classic-era drops: Forever loot tables are still being mapped, so
-- the weekly update moves anything that changed.
RG.HEAL_GUIDE = {
  -- 39-45: Scarlet Monastery
  { id = 7711,  slot = "Shoulder",  lvl = 33, how = "Drop",  src = "Arcanist Doan", zone = "Scarlet Monastery Library" },
  { id = 7712,  slot = "Chest",     lvl = 33, how = "Drop",  src = "Arcanist Doan", zone = "Scarlet Monastery Library" },
  { id = 7720,  slot = "Head",      lvl = 39, how = "Drop",  src = "High Inquisitor Whitemane", zone = "Scarlet Monastery Cathedral" },
  { id = 7722,  slot = "Neck",      lvl = 39, how = "Drop",  src = "High Inquisitor Whitemane", zone = "Scarlet Monastery Cathedral" },
  { id = 7721,  slot = "Main Hand", lvl = 39, how = "Drop",  src = "High Inquisitor Whitemane", zone = "Scarlet Monastery Cathedral", note = "+15 healing mace, your first real healing weapon" },
  -- 42-50: Zul'Farrak and Maraudon
  { id = 18083, slot = "Hands",     lvl = 42, how = "Drop",  src = "Witch Doctor Zum'rah", zone = "Zul'Farrak" },
  { id = 17755, slot = "Waist",     lvl = 45, how = "Drop",  src = "Lord Vyletongue", zone = "Maraudon" },
  { id = 17748, slot = "Feet",      lvl = 46, how = "Drop",  src = "Razorlash", zone = "Maraudon" },
  { id = 17743, slot = "Two-Hand",  lvl = 46, approx = true, how = "Quest", src = "Corruption of Earth and Seed (Celebras)", zone = "Maraudon", note = "Healer staff from the Princess quest" },
  { id = 17737, slot = "Off Hand",  lvl = 48, how = "Drop",  src = "Landslide", zone = "Maraudon" },
  { id = 17715, slot = "Head",      lvl = 49, how = "Drop",  src = "Princess Theradras", zone = "Maraudon" },
  -- 50-55: Sunken Temple and Blackrock Depths
  { id = 10751, slot = "Head",      lvl = 50, approx = true, how = "Quest", src = "The God Hakkar", zone = "Sunken Temple" },
  { id = 12466, slot = "Waist",     lvl = 50, approx = true, how = "Drop", src = "Any of the dragons", zone = "Sunken Temple" },
  { id = 10787, slot = "Hands",     lvl = 50, approx = true, how = "Drop", src = "Atal'ai mini-bosses", zone = "Sunken Temple" },
  { id = 11623, slot = "Back",      lvl = 52, approx = true, how = "Drop", src = "Houndmaster Grebmar", zone = "Blackrock Depths" },
  { id = 11624, slot = "Shoulder",  lvl = 52, approx = true, how = "Drop", src = "High Interrogator Gerstahn", zone = "Blackrock Depths" },
  { id = 11841, slot = "Legs",      lvl = 54, approx = true, how = "Drop", src = "Fineous Darkvire", zone = "Blackrock Depths" },
  { id = 12554, slot = "Hands",     lvl = 54, approx = true, how = "Drop", src = "Princess Moira Bronzebeard", zone = "Blackrock Depths" },
  { id = 11819, slot = "Trinket",   lvl = 54, approx = true, how = "Drop", src = "Golem Lord Argelmach", zone = "Blackrock Depths" },
  { id = 11923, slot = "Main Hand", lvl = 54, approx = true, how = "Drop", src = "Chest of The Seven", zone = "Blackrock Depths", note = "Pre-raid healing mace" },
  { id = 11928, slot = "Off Hand",  lvl = 55, approx = true, how = "Drop", src = "Emperor Dagran Thaurissan", zone = "Blackrock Depths" },
  -- 55-60: Blackrock Spire, Dire Maul, Stratholme, Scholomance
  { id = 13178, slot = "Ring",      lvl = 55, approx = true, how = "Drop", src = "Urok Doomhowl", zone = "Lower Blackrock Spire" },
  { id = 12930, slot = "Trinket",   lvl = 56, approx = true, how = "Drop", src = "Jed Runewatcher (rare)", zone = "Upper Blackrock Spire" },
  { id = 18327, slot = "Waist",     lvl = 56, approx = true, how = "Drop", src = "Alzzin the Wildshaper", zone = "Dire Maul East" },
  { id = 18386, slot = "Legs",      lvl = 57, approx = true, how = "Drop", src = "Illyanna Ravenoak", zone = "Dire Maul West" },
  { id = 18490, slot = "Head",      lvl = 57, approx = true, how = "Drop", src = "Cho'Rush the Observer", zone = "Dire Maul North" },
  { id = 18527, slot = "Hands",     lvl = 57, approx = true, how = "Drop", src = "King Gordok (tribute run)", zone = "Dire Maul North" },
  { id = 18459, slot = "Wrist",     lvl = 57, approx = true, how = "Drop", src = "Gordok guards", zone = "Dire Maul North" },
  { id = 12633, slot = "Head",      lvl = 57, approx = true, how = "Crafted", bs = 300, src = "Blacksmithing 300 (Whitesoul Helm plan)", zone = "Your own anvil", note = "You can make this yourself" },
  { id = 18702, slot = "Waist",     lvl = 58, approx = true, how = "BoE", ah = true, src = "Rare world drop (Scholomance trash)", zone = "Auction House" },
  { id = 13969, slot = "Wrist",     lvl = 58, approx = true, how = "Drop", src = "Kirtonos the Herald", zone = "Scholomance" },
  { id = 18681, slot = "Shoulder",  lvl = 58, approx = true, how = "Drop", src = "Shared loot", zone = "Scholomance" },
  { id = 13386, slot = "Back",      lvl = 58, approx = true, how = "Drop", src = "Archivist Galford", zone = "Stratholme" },
  { id = 13954, slot = "Feet",      lvl = 58, approx = true, how = "Drop", src = "Stonespine (rare)", zone = "Stratholme" },
  { id = 18723, slot = "Neck",      lvl = 58, approx = true, how = "Drop", src = "Ramstein the Gorger", zone = "Stratholme" },
  { id = 13346, slot = "Chest",     lvl = 58, approx = true, how = "Drop", src = "Baron Rivendare", zone = "Stratholme" },
  { id = 18103, slot = "Ring",      lvl = 58, approx = true, how = "Drop", src = "Warchief Rend Blackhand", zone = "Upper Blackrock Spire" },
  { id = 16058, slot = "Ring",      lvl = 58, approx = true, how = "Quest", src = "In Dreams (Western Plaguelands chain)", zone = "Western Plaguelands" },
}
RG.HealByID = {}
for _, g in ipairs(RG.HEAL_GUIDE) do RG.HealByID[g.id] = g end

-- Healing tips for a part-time Holy paladin.
RG.HEAL_TIPS = {
  "Dual spec unlocks at level 40 in WoW Forever. Visit your class trainer in a capital city to switch.",
  "Start collecting now: the Healing tab marks every healing piece you own, and RetGear won't vendor or auction it.",
  "Plate isn't required to heal. Cloth with Intellect, Spirit or +Healing works for a healer paladin.",
  "Flash of Light is your main heal; save Holy Light for big hits. Keep an eye on mana when the group chain-pulls.",
  "Your bags fill up fast with two sets. Buy bigger bags, and park off-set pieces in the bank between runs.",
  "Use the game's Equipment Manager (character screen) to save a Holy set so you can swap it in one click.",
}

-- ---------------------------------------------------------------------------
-- Your healing set: the best healing piece you own for each slot
-- ---------------------------------------------------------------------------
local LOC_GROUP = {
  INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder", INVTYPE_CLOAK = "Back",
  INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest", INVTYPE_WRIST = "Wrist", INVTYPE_HAND = "Hands",
  INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_FINGER = "Ring",
  INVTYPE_TRINKET = "Trinket", INVTYPE_WEAPON = "Main Hand", INVTYPE_WEAPONMAINHAND = "Main Hand",
  INVTYPE_2HWEAPON = "Two-Hand", INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_HOLDABLE = "Off Hand",
  INVTYPE_SHIELD = "Off Hand", INVTYPE_RELIC = "Relic",
}
RG.HEAL_SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Ring", "Ring", "Trinket", "Trinket", "Main Hand", "Off Hand" }
local SLOT_COUNT = { Ring = 2, Trinket = 2 }
local MIN_SCORE = 4 -- anything under this isn't really healing gear (items on the healing list always count)

local C = C_Container
local function numSlots(bag) return ((C and C.GetContainerNumSlots) or GetContainerNumSlots)(bag) or 0 end

local function collect()
  RG.db.healBank = RG.db.healBank or {}
  local pieces, seen = {}, {}
  local function add(link, where)
    if not link then return end
    local loc = RG.EquipLoc(link)
    local group = loc and LOC_GROUP[loc]
    if not group then return end
    local score = RG.HealScore(link)
    local id = tonumber(link:match("item:(%d+)"))
    if score < MIN_SCORE and not RG.HealByID[id] then return end
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

-- set[group] = { piece, piece } sorted best first, plus the total Holy score.
local setCache, setStamp
function RG.HealSet()
  if setStamp and GetTime() - setStamp < 1 then return setCache.set, setCache.total, setCache.keep end
  setStamp = GetTime()
  local set, keep, total = {}, {}, 0
  for _, p in ipairs(collect()) do set[p.group] = set[p.group] or {}; table.insert(set[p.group], p) end
  -- A two-hander competes with main hand + off hand together.
  for group, list in pairs(set) do
    table.sort(list, function(a, b) return a.score > b.score end)
    local n = SLOT_COUNT[group] or 1
    for i = n + 1, #list do list[i] = nil end
  end
  local mh = set["Main Hand"] and set["Main Hand"][1]
  local oh = set["Off Hand"] and set["Off Hand"][1]
  local th = set["Two-Hand"] and set["Two-Hand"][1]
  if th and th.score > (mh and mh.score or 0) + (oh and oh.score or 0) then set["Main Hand"] = { th }; set["Off Hand"] = nil
  else set["Two-Hand"] = nil end
  for _, list in pairs(set) do for _, p in ipairs(list) do total = total + p.score; if p.id then keep[p.id] = true end end end
  setCache = { set = set, total = total, keep = keep }
  return set, total, keep
end
local function invalidate() setStamp = nil end
RG.HealInvalidate = invalidate

-- Is this item part of your healing set? (so nothing sells it)
function RG.IsHealKeeper(id)
  if not on() or not id then return false end
  local _, _, keep = RG.HealSet()
  return keep[id] and true or false
end

-- How much would this item add to your healing set?
function RG.HealDelta(link)
  local loc = RG.EquipLoc(link)
  local group = loc and LOC_GROUP[loc]
  if not group then return nil end
  local score = RG.HealScore(link)
  local set = RG.HealSet()
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

-- ---------------------------------------------------------------------------
-- Tooltip: Holy score and whether to keep it
-- ---------------------------------------------------------------------------
local function OnTooltip(tooltip, data)
  if not on() or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then return end
  if (UnitLevel("player") or 1) < 30 then return end
  local link
  if tooltip.GetItem then link = select(2, tooltip:GetItem()) end
  if not link and data and data.id then link = select(2, RG.ItemInfo(data.id)) end
  if not link then return end
  local loc = RG.EquipLoc(link)
  if not (loc and LOC_GROUP[loc]) then return end
  local score = RG.HealScore(link)
  if score < MIN_SCORE and not RG.HealByID[tonumber(link:match("item:(%d+)"))] then return end
  local delta, group, _, inSet = RG.HealDelta(link)
  local right
  if inSet then right = GREEN .. "in your healing set, keep it|r"
  elseif delta and delta > 0.5 then right = GREEN .. string.format("+%.0f healing set upgrade", delta) .. "|r"
  else right = GREY .. "not better than your healing " .. (group or "") .. "|r" end
  tooltip:AddDoubleLine(HOLY_ICON .. "|cffF58CBAHoly score|r  " .. string.format("%.0f", score), right)
  local g = RG.HealByID[tonumber(link:match("item:(%d+)"))]
  if g then tooltip:AddLine(GREY .. "On the healing list: " .. g.src .. ", " .. g.zone .. "|r", 1, 1, 1, true) end
  tooltip:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)
elseif GameTooltip and GameTooltip.HookScript then
  GameTooltip:HookScript("OnTooltipSetItem", OnTooltip)
end

-- ---------------------------------------------------------------------------
-- Bank memory, toasts for new healing pieces, dual spec reminder
-- ---------------------------------------------------------------------------
local function readBank()
  local out = {}
  local bags = { -1, 5, 6, 7, 8, 9, 10, 11 }
  for _, bag in ipairs(bags) do
    for slot = 1, numSlots(bag) do
      local info = C and C.GetContainerItemInfo and C.GetContainerItemInfo(bag, slot)
      if info and info.hyperlink then
        local loc = RG.EquipLoc(info.hyperlink)
        if loc and LOC_GROUP[loc] and RG.HealScore(info.hyperlink) >= MIN_SCORE then out[#out + 1] = info.hyperlink end
      end
    end
  end
  RG.db.healBank = out
  invalidate()
end

local known = nil
local function checkNew()
  if not on() or (UnitLevel("player") or 1) < 38 then return end
  local _, _, keep = RG.HealSet()
  if known then
    for id in pairs(keep) do
      if not known[id] then
        local name, link, _, _, _, _, _, _, _, icon = RG.ItemInfo(id)
        local isWorn = false
        for slot = 1, 18 do local l = GetInventoryItemLink("player", slot); if l and tonumber(l:match("item:(%d+)")) == id then isWorn = true end end
        local p = link and RG.HealScore(link) or 0
        if not isWorn and p >= 8 and RG.Toast then
          RG.Toast("Healing set upgrade", (link or name or "New item") .. " is now in your healing set. RetGear won't sell it.", icon, nil, nil, 6)
        end
      end
    end
  end
  known = {}
  for id in pairs(keep) do known[id] = true end
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED", "BANKFRAME_CLOSED" }) do pcall(f.RegisterEvent, f, e) end
local bankOpen = false
f:SetScript("OnEvent", function(_, event)
  if event == "BANKFRAME_OPENED" then bankOpen = true; readBank()
  elseif event == "BANKFRAME_CLOSED" then if bankOpen then readBank() end; bankOpen = false
  elseif event == "PLAYERBANKSLOTS_CHANGED" then if bankOpen then readBank() end
  elseif event == "PLAYER_LOGIN" then C_Timer.After(4, function() invalidate(); checkNew() end); return
  else
    if bankOpen and event == "BAG_UPDATE_DELAYED" then readBank() end
    invalidate()
    C_Timer.After(0.5, checkNew)
  end
  if RG.RefreshUI then RG.RefreshUI() end
end)

local function hasDualSpec()
  if GetNumTalentGroups then return (GetNumTalentGroups() or 1) > 1 end
  if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecGroups then return (C_SpecializationInfo.GetNumSpecGroups() or 1) > 1 end
  return nil
end
RG.HasDualSpec = hasDualSpec

local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  if on() and (UnitLevel("player") or 1) >= 40 and hasDualSpec() == false and not RG.db.dualSpecSeen then
    out[#out + 1] = { HOLY_ICON .. GOLD .. "Dual spec is unlocked|r" .. GREY .. "  (see your class trainer; click to hide)|r", function() RG.db.dualSpecSeen = true; if RG.ShowTab then RG.ShowTab("heal") end end }
  end
  return out
end

local base = SlashCmdList.RETGEAR
SlashCmdList.RETGEAR = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  if cmd and (cmd:lower() == "heal" or cmd:lower() == "holy") then if RG.ShowTab then RG.ShowTab("heal") end return end
  return base(msg)
end
