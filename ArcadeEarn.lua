local _, RG = ...
-- Waypath Cards: coins for what you do at level 60 (1.53), when XP, level-ups and most quests stop paying.
--   dungeon bosses      3 coins each (20 bosses a day)
--   raid bosses         15 coins each, 40 for a raid's last boss; once per boss per weekly lockout
--   world bosses        30 coins for being in the kill (your raid had the tag); once a week per boss
--   rare elites         8 coins for one whose Field Guide card you already have (5 a day)
--   elite mobs          1 coin for every 3 elites at your level or near it, at level 60 (40 coins a day)
--   reputation          25 coins each time a faction moves up to Friendly, Honored, Revered or Exalted
--   gathering           1 coin for every 5 herbs, ore or skins, at level 60 (20 coins a day)
--   battlegrounds       8 coins a win, 3 a loss (6 games a day)
-- These amounts are what you get (they are new, so the +20% on older coin sources doesn't apply on top).
-- The combat log is closed to add-ons on this client: kills are read from the corpse after the fight (as the
-- Field Guide does), bosses from the game's encounter events.

local function A() return RG.ArcadeUI and RG.ArcadeUI.store and RG.ArcadeUI.store() end
local function today() return date and date("%Y-%m-%d") or "today" end
local function level() return (UnitLevel and UnitLevel("player")) or 1 end
local function secret(x) return RG.IsSecret and RG.IsSecret(x) end
local function safe(fn, ...) if not fn then return nil end local ok, v = pcall(fn, ...); if ok and v ~= nil and not secret(v) then return v end end
local function charKey() return (safe(UnitName, "player") or "?") .. "-" .. (safe(GetRealmName) or "?") end
local MAX_LEVEL = 60

local RATES = {
  dunboss = { coins = 3, day = 20 },        -- day: how many a day pay
  raidboss = { coins = 15, last = 40 },
  world = { coins = 30 },
  rare = { coins = 8, day = 5 },
  elite = { coins = 1 / 3, dayCoins = 40 },
  rep = { coins = 25 },
  gather = { coins = 1 / 5, dayCoins = 20 },
  bg = { win = 8, loss = 3, day = 6 },
}
RG.ARCADE_EARN60 = RATES

-- the day's counts (reset each day) and the fractions carried over
local function book(a)
  a.e60 = a.e60 or {}
  local b = a.e60
  if b.day ~= today() then b.day, b.n, b.coins = today(), {}, {} end
  b.acc = b.acc or {}
  return b
end
-- pay: whole coins now, fractions carried; returns the coins paid (0 when today's limit is reached)
local function pay(kind, amount, label)
  local a = A(); if not a or not amount or amount <= 0 then return 0 end
  local b = book(a)
  local r = RATES[kind] or {}
  if r.day and (b.n[kind] or 0) >= r.day then return 0 end
  b.n[kind] = (b.n[kind] or 0) + 1
  b.acc[kind] = (b.acc[kind] or 0) + amount
  local coins = math.floor(b.acc[kind] + 1e-9)
  if r.dayCoins then coins = math.max(0, math.min(coins, r.dayCoins - (b.coins[kind] or 0))) end
  if coins <= 0 then
    if r.dayCoins and (b.coins[kind] or 0) >= r.dayCoins then b.acc[kind] = 0 end
    return 0
  end
  b.acc[kind] = b.acc[kind] - coins
  b.coins[kind] = (b.coins[kind] or 0) + coins
  a.coins = (a.coins or 0) + coins
  a.stats = a.stats or {}; a.stats.e60 = (a.stats.e60 or 0) + coins
  if label then
    local msg = "|cffffd36bWaypath Cards:|r " .. label .. "  (+" .. coins .. " coins)"
    if RG.Notify then RG.Notify(msg) elseif RG.Print then RG.Print(msg) end
  end
  if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
  return coins
end
RG.ArcadeEarnPay = pay

-- ---------------------------------------------------------------------------
-- Bosses: dungeons and raids (the game's encounter events)
-- ---------------------------------------------------------------------------
-- the last boss of each raid (its encounter id): the original game's, and WoW Forever's own from its boss list
local FINAL = { [672] = true, [617] = true, [793] = true, [723] = true, [717] = true, [1114] = true, [1084] = true }
local finalName = {}
for _, d in ipairs(RG.ARCADE_RAIDS or {}) do
  local bl = d.raid and d.raid.bosses
  if bl and #bl > 0 then finalName[bl[#bl]:lower()] = true end
end
local recent = {}   -- an encounter counts once (ENCOUNTER_END and BOSS_KILL can both arrive)
local function encounter(id, name)
  if not (IsInInstance and GetInstanceInfo) then return end
  local inside, kind = IsInInstance()
  if not inside then return end
  name = (type(name) == "string" and not secret(name)) and name or nil
  id = (type(id) == "number" and not secret(id)) and id or nil
  local key = tostring(id or name or "?")
  local t = (GetTime and GetTime()) or 0
  if recent[key] and t - recent[key] < 600 then return end
  recent[key] = t
  local a = A(); if not a then return end
  if kind == "party" then
    pay("dunboss", RATES.dunboss.coins)   -- (quiet: the clear's own reward says the rest)
  elseif kind == "raid" then
    a.raidCoins = a.raidCoins or {}
    local lock = RG.ArcadeLockout and RG.ArcadeLockout() or today()
    if a.raidCoins.id ~= lock then a.raidCoins = { id = lock, done = {} } end
    if a.raidCoins.done[key] then return end
    a.raidCoins.done[key] = true
    local last = (id and FINAL[id]) or (name and finalName[name:lower()])
    pay("raidboss", last and RATES.raidboss.last or RATES.raidboss.coins, (name or "Raid boss") .. " defeated" .. (last and ", the raid's last boss" or ""))
  end
end

-- ---------------------------------------------------------------------------
-- The Field Guide: world bosses and rares you already have (called from ArcadeFieldGuide.lua)
-- ---------------------------------------------------------------------------
local function weekKey()
  if RG.ArcadeLockout then return RG.ArcadeLockout() end
  local t = (time and time()) or 0
  return math.floor(t / (7 * 86400))
end
function RG.ArcadeEarnField(name, witness, kills)
  local a = A(); if not a or type(name) ~= "string" then return end
  if witness then
    a.worldCoins = a.worldCoins or {}
    local wk = weekKey()
    if a.worldCoins[name] == wk then return end
    a.worldCoins[name] = wk
    pay("world", RATES.world.coins, "World boss: " .. name:gsub("^Witness: ", ""))
  elseif (kills or 0) > 1 then
    pay("rare", RATES.rare.coins, "Rare elite: " .. name)
  end
end

-- ---------------------------------------------------------------------------
-- Elite mobs at level 60: an elite you saw, dead, and yours (not tapped by someone else)
-- ---------------------------------------------------------------------------
local seen, credited = {}, {}
local function eliteOf(unit)
  if level() < MAX_LEVEL then return nil end
  local g = safe(UnitGUID, unit)
  if type(g) ~= "string" or not g:find("^Creature") then return nil end
  local cls = safe(UnitClassification, unit)
  if cls ~= "elite" and cls ~= "rareelite" then return nil end
  if safe(UnitIsPlayer, unit) then return nil end
  local lv = safe(UnitLevel, unit)
  if type(lv) ~= "number" or (lv ~= -1 and lv < MAX_LEVEL - 5) then return nil end   -- (not one far below you)
  local id = tonumber((select(6, strsplit("-", g))))
  if id and RG.ARCADE_FIELD_NPC and RG.ARCADE_FIELD_NPC[id] then return nil end    -- (rares pay through the Field Guide)
  return g
end
local function look(unit)
  local g = eliteOf(unit)
  if g then seen[g] = true end
end
local function sweep()
  if level() < MAX_LEVEL then return end
  local units = { "target", "mouseover", "focus" }
  for i = 1, 40 do units[#units + 1] = "nameplate" .. i end
  for _, u in ipairs(units) do
    local g = safe(UnitGUID, u)
    if type(g) == "string" and seen[g] and not credited[g] then
      local dead = safe(UnitIsDead, u)
      local denied = UnitIsTapDenied and safe(UnitIsTapDenied, u)
      if dead == true and denied == false then
        credited[g] = true; seen[g] = nil
        pay("elite", RATES.elite.coins)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Reputation: "You are now Honored with ..."
-- ---------------------------------------------------------------------------
local repPattern, standingOf
local function buildRep()
  if repPattern ~= nil then return end
  repPattern = false
  local fmt = _G.FACTION_STANDING_CHANGED   -- "You are now %s with %s."
  if type(fmt) ~= "string" then return end
  local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)")
  repPattern = "^" .. p .. "$"
  standingOf = {}
  for i = 5, 8 do
    for _, k in ipairs({ "FACTION_STANDING_LABEL" .. i, "FACTION_STANDING_LABEL" .. i .. "_FEMALE" }) do
      local v = _G[k]; if type(v) == "string" then standingOf[v] = i end
    end
  end
end
local function repChanged(text)
  buildRep()
  if not repPattern or type(text) ~= "string" or secret(text) then return end
  local standing, faction = text:match(repPattern)
  local i = standing and standingOf[standing]
  if not (i and faction) then return end
  local a = A(); if not a then return end
  a.repCoins = a.repCoins or {}
  local key = charKey() .. ":" .. faction
  if (a.repCoins[key] or 0) >= i then return end
  a.repCoins[key] = i
  pay("rep", RATES.rep.coins, faction .. ": " .. standing)
end

-- ---------------------------------------------------------------------------
-- Gathering at level 60: herbs, ore and skins
-- ---------------------------------------------------------------------------
local gatherNames
local function isGather(spellID)
  if not gatherNames then
    gatherNames = {}
    local info = GetSpellInfo or (C_Spell and C_Spell.GetSpellName)
    for _, id in ipairs({ 2366, 2575, 8613 }) do   -- Herb Gathering, Mining, Skinning
      local n = info and safe(info, id)
      if type(n) == "table" then n = n.name end
      if type(n) == "string" then gatherNames[n] = true end
    end
  end
  local info = GetSpellInfo or (C_Spell and C_Spell.GetSpellName)
  local n = info and safe(info, spellID)
  if type(n) == "table" then n = n.name end
  return type(n) == "string" and gatherNames[n] or false
end

-- ---------------------------------------------------------------------------
-- Battlegrounds: the result, once per battleground
-- ---------------------------------------------------------------------------
local bgPaid = false
local function bgScore()
  if bgPaid or not GetBattlefieldWinner then return end
  local w = safe(GetBattlefieldWinner)
  if type(w) ~= "number" then return end
  bgPaid = true
  local fac = safe(UnitFactionGroup, "player")
  local mine = (fac == "Horde" and 0) or (fac == "Alliance" and 1) or nil
  if mine == nil then return end
  local won = (w == mine)
  pay("bg", won and RATES.bg.win or RATES.bg.loss, won and "Battleground won" or "Battleground over")
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ENCOUNTER_END", "BOSS_KILL", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "PLAYER_REGEN_ENABLED",
  "UNIT_FLAGS", "CHAT_MSG_SYSTEM", "CHAT_MSG_COMBAT_FACTION_CHANGE", "UNIT_SPELLCAST_SUCCEEDED", "UPDATE_BATTLEFIELD_SCORE", "PLAYER_ENTERING_WORLD" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
  if event == "ENCOUNTER_END" then
    if a5 == 1 or a5 == true then pcall(encounter, a1, a2) end
  elseif event == "BOSS_KILL" then pcall(encounter, a1, a2)
  elseif event == "PLAYER_TARGET_CHANGED" then pcall(look, "target"); pcall(sweep)
  elseif event == "UPDATE_MOUSEOVER_UNIT" then pcall(look, "mouseover")
  elseif event == "NAME_PLATE_UNIT_ADDED" then pcall(look, a1)
  elseif event == "UNIT_FLAGS" then if a1 == "target" and not (InCombatLockdown and InCombatLockdown()) then pcall(sweep) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    pcall(sweep)
    if C_Timer and C_Timer.After then C_Timer.After(1.5, function() pcall(sweep) end) end
  elseif event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then pcall(repChanged, a1)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if a1 == "player" and level() >= MAX_LEVEL then
      local ok, g = pcall(isGather, a3)
      if ok and g then pay("gather", RATES.gather.coins) end
    end
  elseif event == "UPDATE_BATTLEFIELD_SCORE" then pcall(bgScore)
  elseif event == "PLAYER_ENTERING_WORLD" then
    bgPaid = false
    -- (a battleground left before it ended pays nothing; one still showing its result counts once)
    local inside, kind = IsInInstance and IsInInstance()
    if not (inside and kind == "pvp") then wipe(credited); wipe(seen) end
  end
end)

RG.ArcadeEarn = { pay = pay, encounter = encounter, look = look, sweep = sweep, repChanged = repChanged, isGather = isGather, bgScore = bgScore,
  reset = function() bgPaid = false end }
