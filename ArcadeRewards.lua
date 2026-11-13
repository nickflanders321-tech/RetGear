local _, RG = ...
-- Waypath Cards: bonuses for what you do in the world.
--   level milestones (10, 20, 30, 40, 45, 50, 55, 56, 57, 58, 59) and a present at 60
--   clearing a dungeon (3 different bosses), finishing a quest line, and every gear upgrade
-- Packs and coins arrive through RG.ArcadeGrant; nothing here can be farmed (each reward has its own once-only or daily limit).

local function A() return RG.ArcadeUI and RG.ArcadeUI.store and RG.ArcadeUI.store() end
local function today() return date and date("%Y-%m-%d") or "today" end
local function level() return (UnitLevel and UnitLevel("player")) or 1 end
local function secret(x) return RG.IsSecret and RG.IsSecret(x) end

-- ---------------------------------------------------------------------------
-- Level milestones (once per account)
-- ---------------------------------------------------------------------------
local MILESTONES = {
  { 10, 25, { normal = 1 } }, { 20, 40, { normal = 1 } }, { 30, 60, { jumbo = 1 } }, { 40, 80, { jumbo = 1 } }, { 45, 80, { jumbo = 1 } },
  { 50, 120, { super = 1 } }, { 55, 120, { super = 1 } },
  { 56, 40, { normal = 1 } }, { 57, 40, { normal = 1 } }, { 58, 40, { normal = 1 } }, { 59, 40, { normal = 1 } },
}
RG.ARCADE_MILESTONES = MILESTONES
local function milestones(lvl)
  local a = A(); if not a then return end
  a.ms = a.ms or {}
  local coins, packs, labels = 0, { normal = 0, jumbo = 0, super = 0 }, {}
  for _, m in ipairs(MILESTONES) do
    if lvl >= m[1] and not a.ms[m[1]] then
      a.ms[m[1]] = true
      coins = coins + m[2]
      for k, n in pairs(m[3]) do packs[k] = packs[k] + n end
      labels[#labels + 1] = tostring(m[1])
    end
  end
  if #labels > 0 then
    RG.ArcadeGrant(#labels == 1 and ("Level " .. labels[1] .. "!") or ("Levels " .. table.concat(labels, ", ")), coins, packs)
  end
  if lvl >= 60 and not a.giftDone then
    a.giftPending = true
    if C_Timer and C_Timer.After then C_Timer.After(5, function() if RG.ArcadeClaimGift then RG.ArcadeClaimGift() end end) end
    if RG.Notify then RG.Notify("|cffffd36bWaypath Cards:|r a level 60 present is on its way: three cards rated 105 or higher and 5 packs of every size!") end
  end
end

-- ---------------------------------------------------------------------------
-- Dungeons: three different bosses in one instance
-- ---------------------------------------------------------------------------
local bossSet
local function bosses()
  if bossSet then return bossSet end
  bossSet = {}
  for _, c in ipairs(RG.ARCADE_CARDS or {}) do
    if c.kind == 2 and c.text and (c.text:find("^Boss,") or c.text:find("^Dungeon boss,")) then bossSet[c.name] = true end
  end
  return bossSet
end
local run = { key = nil, names = {}, n = 0 }
-- the dungeon's English name (its pack's name) from the instance number
local function dungeonOf(iid)
  for _, d in ipairs(RG.ARCADE_DUNGEONS or {}) do if d[2] == iid then return d[1] end end
end
local function dungeonDone(name, iid)
  local a = A(); if not a then return end
  a.dun = a.dun or {}; a.dunDay = a.dunDay or {}
  local lvl = level()
  local dn = dungeonOf(iid)
  if not a.dun[name] then
    a.dun[name] = true
    RG.ArcadeGrant(name .. " cleared for the first time", 15 + math.floor(lvl / 3), { jumbo = 1 })
    -- (two the first time; one if its Legacy challenge already counted this clear)
    if dn and RG.ArcadeGrantDungeon then
      local before = a.dunClear and a.dunClear[dn]
      RG.ArcadeGrantDungeon(dn, before and 1 or 2, dn .. " cleared")
    end
  elseif a.dunDay.day == today() and (a.dunDay.n or 0) >= 2 then
    if dn and RG.ArcadeGrantDungeon then RG.ArcadeGrantDungeon(dn, 0) end
    return
  else
    if a.dunDay.day ~= today() then a.dunDay = { day = today(), n = 0 } end
    a.dunDay.n = a.dunDay.n + 1
    RG.ArcadeGrant(name .. " cleared again", 8 + math.floor(lvl / 6), { normal = 1 })
    if dn and RG.ArcadeGrantDungeon then RG.ArcadeGrantDungeon(dn, 1, dn .. " cleared again") end
  end
end
local function onDeath(destName)
  if not destName or secret(destName) or not bosses()[destName] then return end
  if not (IsInInstance and GetInstanceInfo) then return end
  local inside, kind = IsInInstance()
  if not inside or (kind ~= "party" and kind ~= "raid") then return end
  local name, _, _, _, _, _, _, id = GetInstanceInfo()
  if not name then return end
  local key = tostring(id or name) .. ":" .. today()
  if run.key ~= key then run = { key = key, names = {}, n = 0, paid = false } end
  if run.names[destName] then return end
  run.names[destName] = true; run.n = run.n + 1
  if run.n >= 3 and not run.paid then run.paid = true; dungeonDone(name, id) end
end

-- ---------------------------------------------------------------------------
-- Quest lines: the last quest of a chain
-- ---------------------------------------------------------------------------
local followers, depthMemo
local function chainInfo(id)
  local qd = RG.QDATA
  if not (qd and id and qd[id]) then return nil end
  if not followers then
    followers, depthMemo = {}, {}
    for _, d in pairs(qd) do
      for _, k in ipairs({ "ps", "pg" }) do if d[k] then for _, p in ipairs(d[k]) do followers[p] = true end end end
    end
  end
  local function depth(q, seen)
    if depthMemo[q] then return depthMemo[q] end
    local d = qd[q]; if not d or not d.ps or seen[q] then return 1 end
    seen[q] = true
    local best = 0
    for _, p in ipairs(d.ps) do best = math.max(best, depth(p, seen)) end
    depthMemo[q] = best + 1
    return depthMemo[q]
  end
  local d = qd[id]
  if followers[id] or d.rep or not (d.ps and #d.ps > 0) then return nil end
  return depth(id, {})
end
local function questTurnedIn(id)
  local a = A(); if not a or type(id) ~= "number" then return end
  local depth = chainInfo(id); if not depth then return end
  a.chains = a.chains or {}
  if a.chains[id] then return end
  a.chains[id] = true
  local lvl = level()
  local name = RG.QDATA[id] and RG.QDATA[id].n or "A quest line"
  a.chainDay = a.chainDay or {}
  if a.chainDay.day ~= today() then a.chainDay = { day = today(), n = 0 } end
  if depth >= 3 and a.chainDay.n < 2 then
    a.chainDay.n = a.chainDay.n + 1
    RG.ArcadeGrant("Quest line finished: " .. name, 6 + math.floor(lvl / 6), { normal = 1 })
  else
    RG.ArcadeGrant("Quest line finished: " .. name, 4 + math.floor(lvl / 10))
  end
end

-- ---------------------------------------------------------------------------
-- Gear: every time a slot gets better than it has ever been on this character
-- ---------------------------------------------------------------------------
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local function charKey() return (UnitName and UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "?") end
local function slotLevel(slot)
  if not GetInventoryItemLink then return nil end
  local link = GetInventoryItemLink("player", slot)
  if not link or secret(link) then return nil end
  -- item level: the detailed lookup first, then whichever item-info call this game build has
  local il
  if GetDetailedItemLevelInfo then local ok, v = pcall(GetDetailedItemLevelInfo, link); if ok then il = v end end
  if type(il) ~= "number" then
    local info = GetItemInfo or (C_Item and C_Item.GetItemInfo)
    if info then local ok, _, _, _, v = pcall(info, link); if ok then il = v end end
  end
  if type(il) == "number" and il > 0 then return il end
  return nil
end
local function gearBest()
  local a = A(); if not a then return nil end
  a.gear = a.gear or {}
  local k = charKey()
  if not a.gear[k] then
    -- the first time we see this character: remember what it wears, no reward
    local t = {}
    for _, s in ipairs(SLOTS) do t[s] = slotLevel(s) or 0 end
    a.gear[k] = t
    return nil
  end
  return a.gear[k]
end
local function gearChanged(slot)
  local a = A(); if not a then return end
  local best = gearBest(); if not best then return end
  local il = slotLevel(slot)
  if not il then return end
  local isSlot = false
  for _, s in ipairs(SLOTS) do if s == slot then isSlot = true end end
  if not isSlot then return end
  if il > (best[slot] or 0) then
    best[slot] = il
    a.gearDay = a.gearDay or {}
    if a.gearDay.day ~= today() then a.gearDay = { day = today(), n = 0 } end
    local coins = math.min(30, 3 + math.floor(il / 10))
    if a.gearDay.n < 2 then
      a.gearDay.n = a.gearDay.n + 1
      RG.ArcadeGrant("Gear upgrade", coins, { normal = 1 })
    else
      RG.ArcadeGrant("Gear upgrade", math.max(2, math.floor(coins / 2)))
    end
  end
end

-- ---------------------------------------------------------------------------
-- Dungeons you've already cleared: WoW Forever's Legacy challenges (Novice, Experienced and Master Spelunker)
-- tick off each dungeon. Every one ticked, and every one the card game saw you clear before dungeon packs,
-- unlocks that dungeon's packs and gives the two a first clear gives, once.
-- ---------------------------------------------------------------------------
local function criterionDone(ach, crit)
  if GetAchievementCriteriaInfoByID then
    local ok, _, _, done = pcall(GetAchievementCriteriaInfoByID, ach, crit)
    if ok and done == true then return true end
  end
  if GetAchievementNumCriteria and GetAchievementCriteriaInfo then
    local ok, n = pcall(GetAchievementNumCriteria, ach)
    if ok and type(n) == "number" then
      for i = 1, n do
        local ok2, _, _, done, _, _, _, _, _, _, id = pcall(GetAchievementCriteriaInfo, ach, i)
        if ok2 and id == crit and done == true then return true end
      end
    end
  end
  -- the whole challenge finished: every dungeon in it is done
  if GetAchievementInfo then
    local ok, _, _, _, done = pcall(GetAchievementInfo, ach)
    if ok and done == true then return true end
  end
  return false
end
-- the game's own kill statistic for a dungeon's last boss: how many times (its wings and versions: the highest)
local function statKills(id)
  if not GetStatistic then return 0 end
  local ok, v = pcall(GetStatistic, id)
  if not ok or v == nil or secret(v) then return 0 end
  return tonumber((tostring(v):gsub("[^%d]", ""))) or 0
end
function RG.ArcadeDungeonKills(dn)
  local best = 0
  for _, id in ipairs((RG.ARCADE_DUNGEON_STATS or {})[dn] or {}) do best = math.max(best, statKills(id)) end
  return best
end
RG.ArcadeStatKills = statKills
function RG.ArcadeLegacyCleared(dn)
  for _, e in ipairs((RG.ARCADE_DUNGEON_LEGACY or {})[dn] or {}) do
    if criterionDone(e[1], e[2]) then return true end
  end
  -- (or its last boss's kill statistic: The Stockade isn't in the Legacy challenges)
  return RG.ArcadeDungeonKills(dn) > 0
end
local function legacyCheck(quiet)
  local a = A(); if not a or not RG.ArcadeGrantDungeon then return end
  a.dunRetro = a.dunRetro or {}
  local got = {}
  for _, d in ipairs(RG.ARCADE_DUNGEONS or {}) do
    local dn = d[1]
    if not a.dunRetro[dn] and (RG.ArcadeLegacyCleared(dn) or (a.dun and a.dun[dn]) or (a.dunClear and a.dunClear[dn])) then
      a.dunRetro[dn] = true
      -- (a clear the card game already paid packs for doesn't pay twice)
      local paid = a.dunClear and a.dunClear[dn]
      RG.ArcadeGrantDungeon(dn, paid and 0 or 2)
      if not paid then got[#got + 1] = dn end
    end
  end
  -- veterans: runs from before dungeon packs existed count too, one pack for every five times the last boss fell
  -- (beyond the first), three at most per dungeon, paid once
  a.dunVet = a.dunVet or {}
  local vet = 0
  for _, d in ipairs(RG.ARCADE_DUNGEONS or {}) do
    local dn = d[1]
    if not a.dunVet[dn] and RG.ARCADE_DUNGEON_STATS and RG.ARCADE_DUNGEON_STATS[dn] then
      local k = RG.ArcadeDungeonKills(dn)
      if k > 0 then
        a.dunVet[dn] = k
        local n = math.min(3, math.floor((k - 1) / 5))
        if n > 0 then RG.ArcadeGrantDungeon(dn, n); vet = vet + n end
      end
    end
  end
  if vet > 0 and not quiet then
    local msg = "|cffffd36bWaypath Cards:|r your earlier dungeon runs count: " .. vet .. " more dungeon pack" .. (vet > 1 and "s" or "") .. " (one for every five clears, from the game's own kill counts). Open them from the Shop."
    if RG.Notify then RG.Notify(msg) elseif RG.Print then RG.Print(msg) end
  end
  if #got > 0 and not quiet then
    local msg = "|cffffd36bWaypath Cards:|r dungeons you've cleared unlocked their card packs: " .. table.concat(got, ", ") ..
      " (2 packs each, " .. (#got * 2) .. " in all). Open them from the Album; you can also buy more of those."
    if RG.Notify then RG.Notify(msg) elseif RG.Print then RG.Print(msg) end
  end
  return got
end
RG.ArcadeLegacyCheck = legacyCheck

local ev = CreateFrame("Frame")
-- (Boss kills come from the game's encounter events. Add-ons may no longer listen to the combat log: just asking
-- for it is what the game answered with "Waypath has been blocked from an action only available to the Blizzard UI".)
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "PLAYER_EQUIPMENT_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
for _, e in ipairs({ "ENCOUNTER_END", "BOSS_KILL", "ACHIEVEMENT_EARNED", "CRITERIA_EARNED" }) do pcall(ev.RegisterEvent, ev, e) end
local legacyPending = false
ev:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
  if event == "ENCOUNTER_END" then
    if arg5 == 1 or arg5 == true then onDeath(arg2) end   -- encounterID, encounterName, difficulty, size, success
  elseif event == "BOSS_KILL" then
    onDeath(arg2)                                            -- encounterID, encounterName
  elseif event == "ACHIEVEMENT_EARNED" or event == "CRITERIA_EARNED" then
    -- a Legacy challenge ticked off a dungeon: look again in a moment (once, however many fire)
    if not legacyPending and C_Timer and C_Timer.After then
      legacyPending = true
      C_Timer.After(2, function() legacyPending = false; pcall(legacyCheck) end)
    end
  elseif event == "PLAYER_LEVEL_UP" then
    milestones(tonumber(arg1) or level())
  elseif event == "QUEST_TURNED_IN" then
    pcall(questTurnedIn, arg1)
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    if type(arg1) == "number" then
      -- the item is in the slot a moment later
      if C_Timer and C_Timer.After then C_Timer.After(0.5, function() pcall(gearChanged, arg1) end) else pcall(gearChanged, arg1) end
    end
  elseif event == "PLAYER_LOGIN" then
    local function start() milestones(level()); gearBest(); pcall(legacyCheck) end
    if C_Timer and C_Timer.After then C_Timer.After(6, start) else start() end
  end
end)

RG.ArcadeRewards = { milestones = milestones, onDeath = onDeath, questTurnedIn = questTurnedIn, gearChanged = gearChanged, chainInfo = chainInfo }
