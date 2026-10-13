-- Waypath+ profile: picks the class, race, route and profession data for the
-- character you're playing and merges it into the tables the rest of the
-- add-on reads (RG.GUIDE, RG.ROUTE, RG.STEPS, RG.TRAVEL, ...).
--
-- Classes and races without their own data yet fall back to the Paladin and
-- Undead data, so nothing breaks while the rest are being written.
local _, RG = ...

local FALLBACK_CLASS, FALLBACK_RACE = "PALADIN", "Scourge"
local HORDE_RACES = { Orc = true, Scourge = true, Undead = true, Tauren = true, Troll = true, BloodElf = true, Goblin = true }

local function token(fn)
  if not fn then return nil end
  local ok, _, t = pcall(fn, "player")
  if ok and type(t) == "string" and not (RG.IsSecret and RG.IsSecret(t)) then return t end
end

local classToken = token(UnitClass)
local raceToken = token(UnitRace)
local faction = (raceToken and not HORDE_RACES[raceToken]) and "Alliance" or "Horde"

local C = RG.CLASSES[classToken or ""] or RG.CLASSES[FALLBACK_CLASS]
if raceToken == "Undead" then raceToken = "Scourge" end
local R = RG.RACES[raceToken or ""] or RG.RACES[FALLBACK_RACE]
local H = RG.ROUTES[faction] or RG.ROUTES.Horde

RG.PLAYER_CLASS = classToken or FALLBACK_CLASS
RG.PLAYER_RACE = raceToken or FALLBACK_RACE
RG.PLAYER_FACTION = faction
RG.ActiveClass, RG.ActiveRace, RG.ActiveRoute = C, R, H
-- true when this class or race has data of its own (not the fallback)
RG.ClassSupported = classToken ~= nil and RG.CLASSES[classToken] ~= nil
RG.RaceSupported = raceToken ~= nil and RG.RACES[raceToken] ~= nil

function RG.IsClass(t) return RG.PLAYER_CLASS == t end

-- ---------------------------------------------------------------------------
-- Class: stat weights, gear guide, talents, rotation, class quests
-- ---------------------------------------------------------------------------
RG.DEFAULT_WEIGHTS = C.weights or {}
RG.DEFAULT_HIT_CAP = C.hitCap or 9
-- Class quests, talents, rotation and class milestones only come from your own
-- class: another class's would be wrong. Weights and the gear guide do fall
-- back (a rough melee guide is better than none until your class has its own).
local own = RG.ClassSupported and C or {}
RG.CLASS_QUESTS = own.classQuests or {}
RG.TALENT_PRIORITY = own.talents or {}
RG.ROTATION = own.rotation or {}
-- What item scores are called on tooltips and toasts ("Ret score").
RG.SCORE_NAME = own.scoreName and (own.scoreName .. " score") or "Upgrade score"

-- Gear guide: hand-written entries, then the generated list (hand-written
-- entries win when both list an item).
local guide, have = {}, {}
for _, g in ipairs(C.guide or {}) do guide[#guide + 1] = g; if g.id then have[g.id] = true end end
for _, g in ipairs((RG.CLASS_GEAR or {})[C.token] or {}) do
  if not have[g.id] then guide[#guide + 1] = g; have[g.id] = true end
end
table.sort(guide, function(a, b)
  if a.lvl ~= b.lvl then return a.lvl < b.lvl end
  return (a.tip and 0 or 1) < (b.tip and 0 or 1)
end)
RG.GUIDE = guide

-- ---------------------------------------------------------------------------
-- Route: faction zones + race starting zones + class milestones
-- ---------------------------------------------------------------------------
local route, travel, steps = {}, {}, {}
for _, src in ipairs({ H, R, own }) do
  for _, r in ipairs(src.route or {}) do route[#route + 1] = r end
  for _, t in ipairs(src.travel or {}) do travel[#travel + 1] = t end
  for k, v in pairs(src.steps or {}) do steps[k] = v end
end
-- o = position the entry was written at; entries without one go by level.
for i, r in ipairs(route) do r._i = i end
table.sort(route, function(a, b)
  local oa, ob = a.o or (a.from + 0.5), b.o or (b.from + 0.5)
  if oa ~= ob then return oa < ob end
  return a._i < b._i
end)
for i, t in ipairs(travel) do t._i = i end
table.sort(travel, function(a, b) if a.lvl ~= b.lvl then return a.lvl < b.lvl end return a._i < b._i end)
RG.ROUTE, RG.TRAVEL, RG.STEPS = route, travel, steps
RG.DUNGEON_QUESTS = H.dungeons or {}

-- ---------------------------------------------------------------------------
-- Professions (all of them for now; the tabs check your skills)
-- ---------------------------------------------------------------------------
local P = RG.PROFESSIONS
RG.MINING = P.Mining and P.Mining.zones or {}
RG.SMELT = P.Mining and P.Mining.smelt or {}
RG.STONES = P.Blacksmithing and P.Blacksmithing.stones or { sharp = {}, blunt = {} }
RG.BS_PLAN = P.Blacksmithing and P.Blacksmithing.plan or {}
local mats, seenMat = {}, {}
for _, name in ipairs({ "Mining", "Blacksmithing" }) do
  for _, id in ipairs(P[name] and P[name].mats or {}) do
    if not seenMat[id] then mats[#mats + 1] = id; seenMat[id] = true end
  end
end
for name, p in pairs(P) do
  if name ~= "Mining" and name ~= "Blacksmithing" then
    for _, id in ipairs(p.mats or {}) do if not seenMat[id] then mats[#mats + 1] = id; seenMat[id] = true end end
  end
end
RG.MATS = mats
