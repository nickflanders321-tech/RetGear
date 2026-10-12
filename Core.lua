-- RetGear core: reads item stats, scores them for Ret, compares against what
-- you're wearing, and adds an upgrade line to every item tooltip.
local ADDON, RG = ...
_G.RetGear = RG

-- Classic WoW text colors: quest-log gold, quest-complete green, error red, poor-quality grey
local GOLD = "|cffffd100"
local GREEN, RED, GREY = "|cff40c040", "|cffff3333", "|cffa0a0a0"
RG.COLORS = { GOLD = GOLD, GREEN = GREEN, RED = RED, GREY = GREY }

function RG.Print(msg) DEFAULT_CHAT_FRAME:AddMessage(GOLD .. "RetGear|r " .. tostring(msg)) end

-- ---------------------------------------------------------------------------
-- Saved settings
-- ---------------------------------------------------------------------------
local function InitDB()
  RetGearDB = RetGearDB or {}
  local db = RetGearDB
  db.weights = db.weights or {}
  for k, v in pairs(RG.DEFAULT_WEIGHTS) do if db.weights[k] == nil then db.weights[k] = v end end
  if db.hitCap == nil then db.hitCap = RG.DEFAULT_HIT_CAP end
  if db.talentHit == nil then db.talentHit = 0 end
  if db.tooltip == nil then db.tooltip = true end
  if db.levelAlerts == nil then db.levelAlerts = true end
  db.prices = db.prices or {}     -- [itemID] = { price = copper, t = time(), n = listings }
  db.tracked = db.tracked or {}   -- [itemID] = true (extra items you asked to watch)
  RG.db = db
end

-- ---------------------------------------------------------------------------
-- Main character vs bank alt. Saved data is shared by every character on the
-- account, so other characters run in "bank alt" mode and never overwrite
-- your main's quests, flight paths, fights or healing set.
-- ---------------------------------------------------------------------------
function RG.PlayerKey()
  return (UnitName("player") or "?") .. "-" .. ((GetRealmName and GetRealmName()) or "")
end
function RG.IsAlt()
  local m = RG.db and RG.db.main
  return m ~= nil and m ~= RG.PlayerKey()
end
-- Run fn once, `delay` seconds after the last call with this key (bursts of
-- bag and quest events collapse into one piece of work).
local debounced = {}
function RG.Debounce(key, delay, fn)
  if debounced[key] then debounced[key].fn = fn; return end
  debounced[key] = { fn = fn }
  C_Timer.After(delay, function() local d = debounced[key]; debounced[key] = nil; if d then d.fn() end end)
end

function RG.MainName()
  local m = RG.db and RG.db.main
  return m and m:match("^(.-)%-") or m
end

-- ---------------------------------------------------------------------------
-- Item info helpers (modern client API with fallbacks)
-- ---------------------------------------------------------------------------
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
local GetItemStats = (C_Item and C_Item.GetItemStats) or _G.GetItemStats

function RG.ItemInfo(item) return GetItemInfo(item) end
function RG.EquipLoc(item)
  local _, _, _, equipLoc = GetItemInfoInstant(item)
  return equipLoc
end
function RG.RequestItem(id)
  if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
end

-- ---------------------------------------------------------------------------
-- Stat extraction: the stat table plus vanilla-style "Equip:" lines
-- ---------------------------------------------------------------------------
local STAT_KEYS = {
  ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
  ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI",
  ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_MELEE_ATTACK_POWER_SHORT = "AP",
  ITEM_MOD_CRIT_RATING_SHORT = "CRIT_RATING", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT_RATING",
  ITEM_MOD_HIT_RATING_SHORT = "HIT_RATING", ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT_RATING",
  ITEM_MOD_HASTE_RATING_SHORT = "HASTE_RATING", ITEM_MOD_MASTERY_RATING_SHORT = "MASTERY_RATING",
  ITEM_MOD_VERSATILITY = "VERS_RATING", ITEM_MOD_SPELL_POWER_SHORT = "SP",
  ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP",
  ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL", ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
  ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
}

-- Text patterns for "Equip:" effects that many Classic-era items use.
local LINE_PATTERNS = {
  { "improves your chance to get a critical strike by (%d+)%%", "CRIT" },
  { "improves your chance to hit by (%d+)%%", "HIT" },
  { "^equip: %+(%d+) attack power%.?$", "AP" },
  { "increases attack power by (%d+)", "AP" },
  { "increases damage and healing done by magical spells and effects by up to (%d+)", "SP" },
  { "increases damage done by holy spells and effects by up to (%d+)", "SP" },
  -- healing (used by the Healing tab's Holy score)
  { "increases damage and healing done by magical spells and effects by up to (%d+)", "HEAL" },
  { "increases healing done by spells and effects by up to (%d+)", "HEAL" },
  { "restores (%d+) mana per 5 sec", "MP5" },
  { "improves your chance to get a critical strike with spells by (%d+)%%", "SCRIT" },
}

local cache = {}
function RG.GetStats(link)
  if not link then return nil end
  if cache[link] then return cache[link] end
  local s = { STR = 0, AGI = 0, STA = 0, INT = 0, SPI = 0, AP = 0, CRIT = 0, HIT = 0, SP = 0,
              CRIT_RATING = 0, HIT_RATING = 0, HASTE_RATING = 0, MASTERY_RATING = 0, VERS_RATING = 0,
              DPS = 0, SPEED = 0, HEAL = 0, MP5 = 0, SCRIT = 0 }
  local raw = GetItemStats and GetItemStats(link)
  if raw then
    for k, v in pairs(raw) do
      local key = STAT_KEYS[k]
      if key then s[key] = s[key] + v end
      if k == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then s.DPS = v end
    end
    -- modern "spell power" heals too
    if (raw.ITEM_MOD_SPELL_POWER_SHORT or 0) > 0 then s.HEAL = s.HEAL + raw.ITEM_MOD_SPELL_POWER_SHORT end
  end
  local fromTable = { AP = raw and (raw.ITEM_MOD_ATTACK_POWER_SHORT or 0) > 0, HEAL = s.HEAL > 0, MP5 = s.MP5 > 0 }
  -- Tooltip text for Equip: lines and weapon speed.
  local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
  local equipSeen = {}
  if data and data.lines then
    for _, line in ipairs(data.lines) do
      local t = line.leftText and line.leftText:lower()
      if t then
        local r = line.rightText and line.rightText:lower()
        local sp = r and r:match("speed (%d+%.%d+)")
        if sp then s.SPEED = tonumber(sp) end
        local dps = t:match("^%(([%d%.]+) damage per second%)")
        if dps and s.DPS == 0 then s.DPS = tonumber(dps) end
        if t:find("^equip:") then
          for _, p in ipairs(LINE_PATTERNS) do
            local n = t:match(p[1])
            -- Ignore situational bonuses like "when fighting Beasts", and don't
            -- count Attack Power twice when the stat table already has it.
            if n and not t:find("when fighting") and not equipSeen[t .. p[2]] and not fromTable[p[2]] then
              s[p[2]] = s[p[2]] + tonumber(n)
              equipSeen[t .. p[2]] = true
            end
          end
        end
      end
    end
  end
  -- Only remember the result once the item's data has actually loaded.
  if raw or (data and data.lines and #data.lines > 1) then cache[link] = s end
  return s
end

-- ---------------------------------------------------------------------------
-- Scoring
-- ---------------------------------------------------------------------------
local function isTwoHander(link)
  return RG.EquipLoc(link) == "INVTYPE_2HWEAPON"
end

-- Score an item. hitRoom = how much hit % still counts before the cap
-- (nil = all of it).
function RG.Score(link, hitRoom)
  local s = RG.GetStats(link)
  if not s then return 0 end
  local w = RG.db.weights
  local hit = s.HIT
  if hitRoom then hit = math.max(0, math.min(hit, hitRoom)) end
  local score = s.STR * w.STR + s.AGI * w.AGI + s.AP * w.AP + s.CRIT * w.CRIT + hit * w.HIT
    + s.STA * w.STA + s.INT * w.INT + s.SPI * w.SPI + s.SP * w.SP
    + s.CRIT_RATING * w.CRIT_RATING + s.HIT_RATING * w.HIT_RATING + s.HASTE_RATING * w.HASTE_RATING
    + s.MASTERY_RATING * w.MASTERY_RATING + s.VERS_RATING * w.VERS_RATING
  if s.DPS > 0 then
    local mult = isTwoHander(link) and 1 or 0.55  -- a one-hander alone is a big step down for Ret
    score = score + s.DPS * w.WEAPON_DPS * mult
    if s.SPEED > 3.0 and isTwoHander(link) then score = score + (s.SPEED - 3.0) * 10 * w.SLOW_BONUS end
  end
  return score
end

-- Total hit % from equipped gear plus talents.
function RG.CurrentHit()
  local total = RG.db.talentHit or 0
  for slot = 1, 18 do
    local link = GetInventoryItemLink("player", slot)
    if link then total = total + (RG.GetStats(link).HIT or 0) end
  end
  return total
end

-- Compare an item with what you'd replace. Returns delta, replacedSlot, newScore, oldScore.
function RG.Compare(link)
  local loc = RG.EquipLoc(link)
  local slots = loc and RG.EQUIP_SLOTS[loc]
  if not slots then return nil end
  local cap = RG.db.hitCap
  local curHit = RG.CurrentHit()
  local best
  for _, slot in ipairs(slots) do
    local old = GetInventoryItemLink("player", slot)
    local oldScore, oldHit = 0, 0
    if old then oldHit = RG.GetStats(old).HIT; oldScore = RG.Score(old) end
    -- Two-hander replaces main hand and off hand together.
    if loc == "INVTYPE_2HWEAPON" then
      local off = GetInventoryItemLink("player", 17)
      if off then oldScore = oldScore + RG.Score(off); oldHit = oldHit + RG.GetStats(off).HIT end
    end
    local hitWithout = curHit - oldHit
    local newScore = RG.Score(link, math.max(0, cap - hitWithout))
    -- Count the old item's hit only up to the cap too.
    if old and oldHit > 0 then
      local capped = math.max(0, math.min(oldHit, cap - hitWithout))
      oldScore = oldScore - (oldHit - capped) * RG.db.weights.HIT
    end
    local delta = newScore - oldScore
    if not best or delta > best.delta then best = { delta = delta, slot = slot, new = newScore, old = oldScore } end
  end
  return best.delta, best.slot, best.new, best.old
end

function RG.FormatDelta(d)
  if not d then return "" end
  if d > 0.5 then return GREEN .. string.format("+%.0f", d) .. "|r"
  elseif d < -0.5 then return RED .. string.format("%.0f", d) .. "|r" end
  return GREY .. "±0|r"
end

-- ---------------------------------------------------------------------------
-- Tooltip line
-- ---------------------------------------------------------------------------
local function OnTooltip(tooltip)
  if not RG.db or not RG.Opt("tooltip") or not tooltip.GetItem then return end
  local _, link = tooltip:GetItem()
  if not link then return end
  local loc = RG.EquipLoc(link)
  if not loc or not RG.EQUIP_SLOTS[loc] then return end
  local score = RG.Score(link)
  local delta = RG.Compare(link)
  local icon = "|TInterface\\Icons\\Spell_Holy_AuraOfLight:14:14:0:0:64:64:5:59:5:59|t "
  local right
  if delta and delta > 0.5 then right = GREEN .. string.format("+%.0f upgrade", delta) .. "|r"
  elseif delta and delta < -0.5 then right = RED .. string.format("%.0f", delta) .. "|r" .. GREY .. " vs worn|r"
  elseif delta then right = GREY .. "same as worn|r" end
  tooltip:AddLine(" ")
  if right then tooltip:AddDoubleLine(icon .. GOLD .. "Ret score|r  " .. string.format("%.0f", score), right)
  else tooltip:AddLine(icon .. GOLD .. "Ret score|r  " .. string.format("%.0f", score)) end
  local id = tonumber(link:match("item:(%d+)"))
  if id then
    local guide = RG.GuideByID and RG.GuideByID[id]
    if guide then tooltip:AddLine(GREY .. "Leveling pick: " .. guide.src .. ", " .. guide.zone .. "|r", 1, 1, 1, true) end
    local price = RG.PriceText and RG.PriceText(id)
    if price then tooltip:AddLine(GREY .. "Auction House: |r" .. price) end
  end
  tooltip:Show()
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)
else
  GameTooltip:HookScript("OnTooltipSetItem", OnTooltip)
  if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltip) end
end

-- ---------------------------------------------------------------------------
-- Guide lookups
-- ---------------------------------------------------------------------------
RG.GuideByID = {}
for _, g in ipairs(RG.GUIDE) do if g.id then RG.GuideByID[g.id] = g end end

-- Is this guide item an upgrade for you right now? Returns delta or nil if
-- the item data hasn't loaded yet.
function RG.GuideDelta(g)
  local _, link = GetItemInfo(g.id)
  if not link then RG.RequestItem(g.id); return nil end
  return (RG.Compare(link))
end

function RG.OwnState(id)
  for slot = 1, 18 do
    local l = GetInventoryItemLink("player", slot)
    if l and tonumber(l:match("item:(%d+)")) == id then return "equipped" end
  end
  local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, true) or (GetItemCount and GetItemCount(id, true)) or 0
  if count and count > 0 then return "owned" end
  return nil
end

-- ---------------------------------------------------------------------------
-- Professions: returns { Mining = {rank, max}, Blacksmithing = {rank, max} }
-- ---------------------------------------------------------------------------
function RG.Professions()
  local out = {}
  if GetProfessions and GetProfessionInfo then
    local p = { GetProfessions() }
    for i = 1, 6 do
      if p[i] then
        local name, _, rank, max = GetProfessionInfo(p[i])
        if name then out[name] = { rank = rank or 0, max = max or 0 } end
      end
    end
  elseif GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
      if name and not header then out[name] = { rank = rank or 0, max = max or 0 } end
    end
  end
  return out
end
-- Do we know a flight path whose name contains this text? nil = never seen a flight master yet.
function RG.KnowsFP(part)
  if not RG.db.fps or not next(RG.db.fps) then return nil end
  part = part:lower()
  for name in pairs(RG.db.fps) do if name:lower():find(part, 1, true) then return true end end
  return false
end
function RG.Skill(name) local p = RG.Professions()[name]; return p and p.rank or nil end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("TAXIMAP_OPENED")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    InitDB()
  elseif event == "PLAYER_LOGIN" then
    for _, g in ipairs(RG.GUIDE) do if g.id then RG.RequestItem(g.id) end end
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    if not RG.db.main and class == "PALADIN" then RG.db.main = RG.PlayerKey() end
    if RG.IsAlt() then
      RG.Print("Bank alt mode: buying and mailing for " .. GOLD .. (RG.MainName() or "your main") .. "|r. /rg mail shows the shopping list. (/rg main makes this character your main.)")
      return
    end
    if class == "PALADIN" and race ~= "Scourge" then RG.Print("Loaded. The leveling guide is set up for an Undead (Horde) paladin, so some quests may not be on your side.") end
    if class ~= "PALADIN" then RG.Print("Loaded. It's tuned for Retribution Paladins, but the scores still work as a Strength DPS guide.") end
  elseif RG.IsAlt() then
    return
  elseif event == "PLAYER_LEVEL_UP" then
    if not RG.db.levelAlerts then return end
    local lvl = arg1
    local found = {}
    for _, g in ipairs(RG.GUIDE) do
      if g.id and (g.lvl == lvl or (g.lvl < lvl and g.lvl >= lvl - 1)) then
        local d = RG.GuideDelta(g)
        if d and d > 0.5 and not RG.OwnState(g.id) then
          local _, link = GetItemInfo(g.id)
          found[#found + 1] = (link or ("item " .. g.id)) .. " " .. RG.FormatDelta(d) .. GREY .. " (" .. g.src .. ", " .. g.zone .. ")|r"
        end
      end
    end
    local go = {}
    for _, r in ipairs(RG.ROUTE or {}) do if r.from == lvl then go[#go + 1] = r.zone .. (r.kind == "dungeon" and " (dungeon)" or "") end end
    if #go > 0 then RG.Print("Level " .. lvl .. ": time for " .. table.concat(go, ", ") .. ". /rg for the route.") end
    for _, t in ipairs(RG.TRAVEL or {}) do
      if t.lvl == lvl and not (t.fp and RG.KnowsFP(t.fp)) then RG.Print("Travel: " .. t.text) end
    end
    for name, dq in pairs(RG.DUNGEON_QUESTS or {}) do
      if dq.prep == lvl then
        local where = {}
        for _, q in ipairs(dq.quests) do where[#where + 1] = q[1] .. GREY .. " (" .. q[3] .. ")|r" end
        RG.Print("Start collecting " .. GOLD .. name .. "|r quests now (head over at " .. dq.go .. "):")
        for _, w in ipairs(where) do DEFAULT_CHAT_FRAME:AddMessage("   " .. w) end
      elseif dq.go == lvl then
        RG.Print("You're ready for " .. GOLD .. name .. "|r. Grab a group!")
      end
    end
    if #found > 0 then
      RG.Print("Level " .. lvl .. "! New upgrades in reach:")
      for _, s in ipairs(found) do DEFAULT_CHAT_FRAME:AddMessage("   " .. s) end
    end
  elseif event == "TAXIMAP_OPENED" then
    -- Remember every flight path this character knows.
    RG.db.fps = RG.db.fps or {}
    local nodes
    if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
      local mapID = (GetTaxiMapID and GetTaxiMapID()) or (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
      nodes = mapID and C_TaxiMap.GetAllTaxiNodes(mapID)
    end
    if nodes then
      for _, n in ipairs(nodes) do
        if n.name and n.state ~= (Enum.FlightPathState and Enum.FlightPathState.Unreachable or 2) then RG.db.fps[n.name] = true end
      end
    elseif NumTaxiNodes and TaxiNodeName then
      for i = 1, NumTaxiNodes() do
        local t = TaxiNodeGetType and TaxiNodeGetType(i)
        if t ~= "NONE" then RG.db.fps[TaxiNodeName(i)] = true end
      end
    end
    if RG.RefreshUI then RG.RefreshUI() end
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    if RG.RefreshUI then RG.RefreshUI() end
  end
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
SLASH_RETGEAR1, SLASH_RETGEAR2 = "/rg", "/retgear"
SlashCmdList.RETGEAR = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = msg:match("^(%S+)%s*(.*)$")
  cmd = cmd and cmd:lower() or ""
  if cmd == "" then
    if RG.ToggleUI then RG.ToggleUI() end
  elseif cmd == "weight" then
    local stat, val = rest:match("^(%S+)%s+([%d%.]+)$")
    stat = stat and stat:upper()
    if stat and RG.db.weights[stat] ~= nil then
      RG.db.weights[stat] = tonumber(val); wipe(cache)
      RG.Print(RG.STAT_LABELS[stat] .. " weight set to " .. val)
      if RG.RefreshUI then RG.RefreshUI() end
    else
      RG.Print("Weights (AP = 1):")
      for k, v in pairs(RG.db.weights) do DEFAULT_CHAT_FRAME:AddMessage(string.format("   %s%s|r %s = %s", GOLD, k, RG.STAT_LABELS[k] or "", v)) end
      RG.Print("Change one with /rg weight STR 2.5")
    end
  elseif cmd == "reset" then
    RG.db.weights = {}; InitDB(); wipe(cache); RG.Print("Weights reset to the defaults.")
  elseif cmd == "hitcap" and tonumber(rest) then
    RG.db.hitCap = tonumber(rest); RG.Print("Hit cap set to " .. rest .. "%.")
  elseif cmd == "talenthit" and tonumber(rest) then
    RG.db.talentHit = tonumber(rest); RG.Print("Hit from talents set to " .. rest .. "%.")
  elseif cmd == "tooltip" then
    RG.db.tooltip = not RG.Opt("tooltip"); RG.Print("Tooltip scores " .. (RG.db.tooltip and "on." or "off."))
  elseif cmd == "track" then
    local id = tonumber(rest:match("item:(%d+)") or rest)
    if id then RG.db.tracked[id] = true; RG.Print("Tracking Auction House prices for item " .. (select(2, GetItemInfo(id)) or id) .. ".") end
  elseif cmd == "untrack" then
    local id = tonumber(rest:match("item:(%d+)") or rest)
    if id then RG.db.tracked[id] = nil; RG.Print("Stopped tracking item " .. id .. ".") end
  elseif cmd == "scan" then
    if RG.ScanAH then RG.ScanAH() end
  else
    RG.Print("Commands (type /rg on its own to open the guide):")
    for _, line in ipairs({
      "|cffffd100Guide|r  /rg  ·  /rg setup  ·  /rg settings  ·  /rg tracker  ·  /rg welcome",
      "|cffffd100Questing|r  /rg next  ·  /rg way 45 60  ·  /rg auto  ·  /rg pace  ·  /rg session",
      "|cffffd100Tabs|r  /rg dps  ·  /rg group  ·  /rg heal  ·  /rg camp  ·  /rg gold  ·  /rg mail  ·  /rg talents",
      "|cffffd100Group|r  /rg lfg Scarlet Monastery",
      "|cffffd100Auction House|r  /rg scan  ·  /rg autoscan  ·  /rg track [item]  ·  /rg untrack [item]  ·  /rg alert [item] 25",
      "|cffffd100Selling|r  /rg profit  ·  /rg profit min 25  ·  /rg profit ignore [item]",
      "|cffffd100Ret score|r  /rg weight STR 2.5  ·  /rg hitcap 9  ·  /rg talenthit 3  ·  /rg reset  ·  /rg tooltip",
      "|cffffd100Characters|r  /rg main  ·  /rg dps reset",
    }) do DEFAULT_CHAT_FRAME:AddMessage("   " .. line) end
  end
end

-- Addon compartment (the addons button by the minimap)
function RetGear_OnAddonCompartmentClick() if RG.ToggleUI then RG.ToggleUI() end end
function RetGear_OnAddonCompartmentEnter(_, frame)
  GameTooltip:SetOwner(frame or UIParent, "ANCHOR_LEFT")
  GameTooltip:SetText("RetGear"); GameTooltip:AddLine("Click to open the Ret gear guide.", 1, 1, 1)
  GameTooltip:Show()
end
function RetGear_OnAddonCompartmentLeave() GameTooltip:Hide() end
