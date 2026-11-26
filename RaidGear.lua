-- Waypath+ raid gear: the data side of the Raid & tier page (it opens at level 58; RaidUI.lua draws it).
--   * Classes/RaidGear.lua (generated: cMaNGOS loot tables, the game's own item sets) holds every raid piece your class could
--     use, with the boss that drops it (or the boss whose token buys it), your class's tier sets, and the raids' boss order.
--   * RG.RaidScan weighs each piece against what you wear with the same comparison as every other gear list, so a gain here
--     means the same thing as a gain anywhere else in the add-on.
--   * RG.RaidRender (RaidUI.lua) draws three views on the Raid & tier page: your best upgrades (and every route to one slot),
--     the tier set grid, and a planner for each raid. UI.lua hands it its row helpers (RG.UIKit).
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local WHITE, PURPLE = "|cffffffff", "|cffA58BD8"
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local MIN_LEVEL = 58            -- the raid section opens at 58: the raid gear's own level requirement is 58 to 60
local WEAPON_SLOT = { ["2H"] = true, ["Main Hand"] = true, ["Off Hand"] = true }

local function count(id)
  if not id then return 0 end
  local f = C_Item and C_Item.GetItemCount or _G.GetItemCount
  local ok, n = pcall(f, id, true)
  return ok and tonumber(n) or 0
end

-- ---------------------------------------------------------------------------
-- Your class's raid list (for the weapon setup you chose, like the rest of the gear lists)
-- ---------------------------------------------------------------------------
local listKey, listCache
function RG.RaidList()
  local all = RG.RAID_GEAR and RG.RAID_GEAR[RG.PLAYER_CLASS]
  if not all then return {} end
  local setup = RG.WeaponSetup and RG.WeaponSetup() or nil
  -- armor below your class's best type (leather for a Warrior, cloth for a Hunter) is only offered to a healer or caster main spec
  local ms = RG.MainSpec and RG.MainSpec()
  local model = (ms and ms.model) or (RG.ActiveClass and RG.ActiveClass.model)
  local casterMain = model == "caster"
  local key = tostring(setup) .. (casterMain and "c" or "p")
  if listKey == key and listCache then return listCache end
  local out = {}
  for _, g in ipairs(all) do
    local ok
    if WEAPON_SLOT[g.slot] then
      if setup then ok = g.ws == setup else ok = not g.ws end
    else ok = true end
    if g.low and not casterMain then ok = false end
    if ok then out[#out + 1] = g end
  end
  listKey, listCache = key, out
  return out
end
function RG.RaidShown()
  return (UnitLevel("player") or 1) >= MIN_LEVEL and #RG.RaidList() > 0
end

-- raid -> { size, bosses }
local ORDER
local function orderOf(raid)
  if not ORDER then
    ORDER = {}
    for i, r in ipairs(RG.RAID_ORDER or {}) do ORDER[r.raid] = { size = r.size, bosses = r.bosses, i = i } end
  end
  return ORDER[raid]
end

-- "Garr" and nil for "Garr", "Thaddius" and "Desecrated Headpiece" for "Thaddius (Desecrated Headpiece)"
local function bossOf(src)
  src = src or ""
  local boss, tok = src:match("^(.-) %((.-)%)$")
  if boss then return boss, tok end
  return src, nil
end
RG.RaidBossOf = bossOf

-- every boss that drops a piece (or its token): its own and the "also" ones
local function bossesOf(g)
  local out, seen = {}, {}
  local function add(raid, src)
    local b = bossOf(src)
    local k = raid .. "|" .. b
    if not seen[k] then seen[k] = true; out[#out + 1] = { raid = raid, boss = b } end
  end
  add(g.zone, g.src)
  for _, a in ipairs(g.also or {}) do if a.zone and a.zone ~= "" then add(a.zone, a.src) end end
  return out
end

-- ---------------------------------------------------------------------------
-- The scan: every raid piece against what you wear (rebuilt when gear or bags change)
-- ---------------------------------------------------------------------------
local scan, scanT, scanLvl, scanKey, scanList
function RG.RaidScanReset() scan = nil end
-- RG.GuideDelta, telling "the game hasn't sent the item yet" (second result true) from "you can't use it" (no delta, not loading)
function RG.RaidDelta(g)
  local link = g.link
  if not link then
    local _, l = GetItemInfo(g.id)
    if not l then if RG.RequestItem then RG.RequestItem(g.id) end; return nil, true end
  elseif not GetItemInfo(link) then
    if RG.RequestItem then RG.RequestItem(g.id) end
    return nil, true
  end
  return RG.GuideDelta(g), false
end
function RG.RaidScan()
  local now = GetTime and GetTime() or 0
  local lvl = UnitLevel("player") or 1
  local setup = RG.WeaponSetup and RG.WeaponSetup() or nil
  local list = RG.RaidList()
  if scan and scanList == list and scanLvl == lvl and scanKey == tostring(setup) and now - scanT < (scan.loading > 0 and 2 or 10) then return scan end
  local res = { ups = {}, bySlot = {}, byBoss = {}, loading = 0, slots = 0 }
  for _, g in ipairs(list) do
    local own = RG.OwnState(g.id)
    if not own then
      local d, slot, new, old = RG.GuideDelta(g)
      if d == nil then
        local _, wait = RG.RaidDelta(g)
        if wait then res.loading = res.loading + 1 end
      elseif d > 0.5 then
        local u = { g = g, d = d, slot = slot, pct = (old and old > 0) and (d / old * 100) or nil, token = g.tk and count(g.tk) > 0 }
        res.ups[#res.ups + 1] = u
        local best = res.bySlot[g.slot]
        if not best or d > best.d then res.bySlot[g.slot] = u end
        for _, b in ipairs(bossesOf(g)) do
          local r = res.byBoss[b.raid] or {}
          res.byBoss[b.raid] = r
          local l = r[b.boss] or {}
          r[b.boss] = l
          l[#l + 1] = u
        end
      end
    end
  end
  table.sort(res.ups, function(a, b) return a.d > b.d end)
  res.top = {}
  for _, u in pairs(res.bySlot) do res.top[#res.top + 1] = u end
  table.sort(res.top, function(a, b) return a.d > b.d end)
  for _, r in pairs(res.byBoss) do for _, l in pairs(r) do table.sort(l, function(a, b) return a.d > b.d end) end end
  scan, scanT, scanLvl, scanKey, scanList = res, now, lvl, tostring(setup), list
  return res
end
do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE" }) do pcall(f.RegisterEvent, f, e) end
  f:SetScript("OnEvent", function() scan = nil end)
end

-- ---------------------------------------------------------------------------
-- Weekly raid lockouts: which bosses you have killed this reset
-- ---------------------------------------------------------------------------
local cleared, clearedAsked = {}, false
local function readLockouts()
  local out = {}
  if not (GetNumSavedInstances and GetSavedInstanceInfo and GetSavedInstanceEncounterInfo) then return out end
  for i = 1, GetNumSavedInstances() do
    local ok, name, _, _, _, locked, _, _, isRaid = pcall(GetSavedInstanceInfo, i)
    if ok and name and locked and isRaid then
      local set = {}
      for j = 1, 30 do
        local ok2, boss, _, killed = pcall(GetSavedInstanceEncounterInfo, i, j)
        if not ok2 or not boss then break end
        if killed then set[boss] = true end
      end
      out[name] = set
    end
  end
  return out
end
function RG.RaidCleared(raid, boss)
  if not clearedAsked then
    clearedAsked = true
    if RequestRaidInfo then pcall(RequestRaidInfo) end
    cleared = readLockouts()
  end
  for name, set in pairs(cleared) do
    if name == raid or name:find(raid, 1, true) or raid:find(name, 1, true) then return set[boss] and true or false end
  end
  return false
end
do
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "UPDATE_INSTANCE_INFO")
  f:SetScript("OnEvent", function() cleared = readLockouts(); if RG.RefreshUI and RG.UIKit and RG.UIKit.state.tab == "gear" then RG.RefreshUI() end end)
end

-- ---------------------------------------------------------------------------
-- Tier sets: pieces, what you have, and the set bonuses as the game words them
-- ---------------------------------------------------------------------------
local byId
local function raidEntry(id)
  if not byId then
    byId = {}
    for _, g in ipairs((RG.RAID_GEAR or {})[RG.PLAYER_CLASS] or {}) do if not byId[g.id] then byId[g.id] = g end end
  end
  return byId[id]
end
function RG.RaidEntry(id) return raidEntry(id) end

-- Tier 0.5 has no item set of its own: its pieces are the class-quest and Pix Xizzix ones the gear lists mark
local function tierHalf()
  local ids, seen = {}, {}
  for _, list in ipairs({ RG.GUIDE or {}, RG.GUIDE_ALT or {} }) do
    for _, g in ipairs(list) do
      if g.id and g.tier == "Tier 0.5" and not seen[g.id] and not g.ws then seen[g.id] = true; ids[#ids + 1] = g.id end
    end
  end
  return ids
end

function RG.TierList()
  local out = {}
  for _, s in ipairs((RG.TIER_SETS or {})[RG.PLAYER_CLASS] or {}) do out[#out + 1] = s end
  local half = tierHalf()
  if #half >= 3 then table.insert(out, 2, { tier = "Tier 0.5", name = "Class quest gear (Tier 0.5)", ids = half, half = true }) end
  return out
end

-- the entry that says where a set piece comes from: the raid list, else the gear lists
local function sourceOf(id)
  local g = raidEntry(id)
  if g then return g end
  for _, list in ipairs({ RG.GUIDE or {}, RG.GUIDE_ALT or {} }) do
    for _, e in ipairs(list) do if e.id == id and not e.ws then return e end end
  end
  return nil
end
RG.TierSource = sourceOf

-- one piece's state: "equipped", "owned" (in your bags or bank), "token" (the token that buys it is in your bags) or "missing"
function RG.TierPieceState(id)
  local own = RG.OwnState(id)
  if own == "equipped" then return "equipped" end
  if own == "owned" then return "owned" end
  local g = raidEntry(id)
  if g and g.tk and count(g.tk) > 0 then return "token" end
  return "missing"
end

function RG.TierProgress(set)
  local have, worn, pieces = 0, 0, {}
  local scanNow = RG.RaidScan()
  local upOf = {}
  for _, u in ipairs(scanNow.ups) do upOf[u.g.id] = u end
  for _, id in ipairs(set.ids) do
    local st = RG.TierPieceState(id)
    if st == "equipped" then have = have + 1; worn = worn + 1 elseif st == "owned" then have = have + 1 end
    pieces[#pieces + 1] = { id = id, state = st, g = sourceOf(id), up = upOf[id] }
  end
  return { have = have, worn = worn, pieces = pieces }
end

-- "(2) Set: ..." lines from the game's own tooltip of one piece (cached once the game has the item)
local bonusCache = {}
local scanTip
local function tipLines(id)
  local lines = {}
  local link = "item:" .. id
  local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
  if data and data.lines then
    for _, l in ipairs(data.lines) do if l.leftText then lines[#lines + 1] = l.leftText end end
    return lines
  end
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "WaypathSetScan", nil, "GameTooltipTemplate")
  end
  scanTip:SetOwner(UIParent, "ANCHOR_NONE")
  scanTip:ClearLines()
  if not pcall(scanTip.SetHyperlink, scanTip, link) then return lines end
  for i = 1, scanTip:NumLines() do
    local fs = _G["WaypathSetScanTextLeft" .. i]
    local t = fs and fs:GetText()
    if t then lines[#lines + 1] = t end
  end
  return lines
end
function RG.SetBonuses(set)
  local id = set.ids and set.ids[1]
  if not id or set.half then return nil end
  if bonusCache[set] then return bonusCache[set] end
  if not GetItemInfo(id) then if RG.RequestItem then RG.RequestItem(id) end return nil end
  local ok, lines = pcall(tipLines, id)
  if not ok then return nil end
  local out = {}
  for _, t in ipairs(lines) do
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local n, txt = t:match("^%((%d+)%)%s*Set:%s*(.+)$")
    if n then out[#out + 1] = { n = tonumber(n), text = txt } end
  end
  if #out == 0 then return nil end
  bonusCache[set] = out
  return out
end

-- ---------------------------------------------------------------------------
-- Routes: a short chain of steps for any gear entry, and how hard it is
-- ---------------------------------------------------------------------------
function RG.RouteSteps(g)
  local how, steps = g.how, {}
  if how == "Raid" then
    local boss, tok = bossOf(g.src)
    steps = { g.zone, boss }
    if tok then steps[#steps + 1] = tok .. " token"; steps[#steps + 1] = "Turn in" end
  elseif how == "Dungeon" or how == "Chest" then steps = { g.zone ~= "" and g.zone or "Dungeon", g.src }
  elseif how == "Quest" then steps = { "Quest", ((g.src or ""):gsub("%s*%(.-%)$", "")) }
  elseif g.real and g.real > 0 then steps = { "Dungeons", "Undermine Real", "Pix Xizzix" }
  elseif how == "Reputation" then steps = { (g.zone or ""):match("^(.-) · ") or "Reputation", (g.zone or ""):match("^.- · (.-) · ") or "Reach the rank", "Buy" }
  elseif how == "Vendor" then steps = { "Buy from", g.src or "a vendor" }
  elseif how == "Crafted" or how == "Craft" then steps = { g.prof or "Profession", "Craft it" }
  elseif how == "BoE" or how == "AH" then steps = { "Auction House" }
  elseif how == "Bags" then steps = { g.src or "In your bags" }
  else steps = { g.src or how or "?" } end
  return steps
end
-- "Raid · 40 players", "Dungeon · 5 players", "Solo friendly"
function RG.RouteEffort(g)
  local how = g.how
  if how == "Raid" then
    local o = orderOf(g.zone)
    return "Raid" .. (o and (" · " .. o.size .. " players") or "")
  elseif how == "Dungeon" or how == "Chest" then return "Dungeon · 5 players"
  elseif how == "Rare mob" then return "Rare mob"
  elseif how == "Crafted" or how == "Craft" then return "Profession"
  elseif how == "BoE" or how == "AH" or g.live == "ah" then return "Auction House"
  elseif how == "Reputation" then return "Reputation grind"
  elseif how == "Bags" then return "Already yours"
  end
  return "Solo friendly"
end
