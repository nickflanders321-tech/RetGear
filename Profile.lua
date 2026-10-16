-- Waypath+ profile: picks the class, race, route and profession data for the
-- character you're playing and merges it into the tables the rest of the
-- add-on reads (RG.GUIDE, RG.ROUTE, RG.STEPS, RG.TRAVEL, ...).
--
-- Classes and races without their own data yet fall back to the Paladin and
-- Undead data, so nothing breaks while the rest are being written.
local _, RG = ...

local FALLBACK_CLASS, FALLBACK_RACE = "PALADIN", "Scourge"
local HORDE_RACES = { Orc = true, Scourge = true, Undead = true, Tauren = true, Troll = true, Skyborne = true }

local function token(fn)
  if not fn then return nil end
  local ok, _, t = pcall(fn, "player")
  if ok and type(t) == "string" and not (RG.IsSecret and RG.IsSecret(t)) then return t end
end

local classToken = token(UnitClass)
local raceToken = token(UnitRace)
local skyborne = raceToken and raceToken:find("Sky") and true or false
if skyborne then raceToken = "Skyborne" end
local factionNow = UnitFactionGroup and select(1, pcall(UnitFactionGroup, "player")) and UnitFactionGroup("player")
local faction = (factionNow == "Alliance" or factionNow == "Horde") and factionNow
  or ((raceToken and not HORDE_RACES[raceToken]) and "Alliance" or "Horde")

local C = RG.CLASSES[classToken or ""] or RG.CLASSES[FALLBACK_CLASS]
if raceToken == "Undead" then raceToken = "Scourge" end
-- Skyborne exist on both sides: the Alliance ones have their own race entry
if skyborne and faction == "Alliance" then raceToken = "SkyborneA" end
local R = RG.RACES[raceToken or ""] or RG.RACES[faction == "Alliance" and "Human" or FALLBACK_RACE]
local H = RG.ROUTES[faction] or RG.ROUTES.Horde

RG.PLAYER_CLASS = classToken or FALLBACK_CLASS
RG.PLAYER_RACE = raceToken or FALLBACK_RACE
RG.PLAYER_FACTION = faction
RG.ActiveClass, RG.ActiveRace, RG.ActiveRoute = C, R, H
-- true when this class or race has data of its own (not the fallback)
RG.ClassSupported = classToken ~= nil and RG.CLASSES[classToken] ~= nil
RG.RaceSupported = raceToken ~= nil and RG.RACES[raceToken] ~= nil

function RG.IsClass(t) return RG.PLAYER_CLASS == t end

-- Quest data (Objectives.lua) marks race- and class-only quests with letters.
local RACE_LETTER = { Orc = "O", Scourge = "U", Tauren = "T", Troll = "R", Skyborne = "S",
  Human = "H", Dwarf = "D", NightElf = "N", Gnome = "G", SkyborneA = "A" }
local CLASS_LETTER = { WARRIOR = "W", PALADIN = "P", HUNTER = "H", ROGUE = "R", PRIEST = "I", SHAMAN = "S", MAGE = "M", WARLOCK = "L", DRUID = "D" }
RG.RACE_LETTER = RACE_LETTER[RG.PLAYER_RACE] or ((RG.PLAYER_RACE or ""):find("Sky") and "S") or (faction == "Alliance" and "H") or "?"
RG.CLASS_LETTER = CLASS_LETTER[RG.PLAYER_CLASS] or "?"
-- Can this character take the quest? (race and class only; level and prerequisites are checked elsewhere)
function RG.QuestForMe(d)
  if not d then return false end
  if d.ra and not d.ra:find(RG.RACE_LETTER, 1, true) then return false end
  if d.cl and not d.cl:find(RG.CLASS_LETTER, 1, true) then return false end
  return true
end

-- ---------------------------------------------------------------------------
-- Class: stat weights, gear guide, talents, rotation, class quests
-- ---------------------------------------------------------------------------
if faction == "Alliance" then   -- the generated gear lists come in a Horde and an Alliance version
  RG.CLASS_GEAR, RG.SPEC_GEAR = RG.CLASS_GEAR_A or RG.CLASS_GEAR, RG.SPEC_GEAR_A or RG.SPEC_GEAR
end
RG.CLASS_GEAR_A, RG.SPEC_GEAR_A = nil, nil
RG.DEFAULT_WEIGHTS = C.weights or {}
RG.WEAPON_MODEL = C.model or "2H"
-- Dual wielders put one-handers in either hand; every class has a ranged slot.
RG.EQUIP_SLOTS.INVTYPE_RANGEDRIGHT = { 18 }
RG.EQUIP_SLOTS.INVTYPE_THROWN = { 18 }
if C.model == "DW" or C.token == "HUNTER" then RG.EQUIP_SLOTS.INVTYPE_WEAPON = { 16, 17 } end
RG.DEFAULT_HIT_CAP = C.hitCap or 9
-- Class quests and class milestones only come from your own class: another
-- class's would be wrong. Weights and the gear guide do fall back (a rough
-- melee guide is better than none until your class has its own).
local own = RG.ClassSupported and C or {}
RG.CLASS_QUESTS = own.classQuests or {}
-- What item scores are called on tooltips and toasts ("Ret score").
RG.SCORE_NAME = own.scoreName and (own.scoreName .. " score") or "Upgrade score"

-- Gear guide: hand-written entries, then the generated list (hand-written
-- entries win when both list an item).
local guide, have = {}, {}
-- The hand-written Paladin guide is written for an Undead paladin: on the Alliance side it keeps
-- only the entries that work for everyone (crafting, dungeons, neutral zones).
local HORDE_TEXT = { "Camp Taurajo", "Tok'Kar", "Camp Mojache", "Undercity", "Tirisfal", "Brill", "Horde", "Deathknell", "Silverpine", "Bandarion", "Forsaken" }
local function hordeOnly(g)
  local t = (g.src or "") .. " " .. (g.zone or "") .. " " .. (g.text or "")
  for _, w in ipairs(HORDE_TEXT) do if t:find(w, 1, true) then return true end end
  return false
end
for _, g in ipairs(C.guide or {}) do
  if not (faction == "Alliance" and hordeOnly(g)) then guide[#guide + 1] = g; if g.id then have[g.id] = true end end
end
-- Before level 13 you're still in or near your own starting zone: skip early
-- items from the other races' starting zones (an Orc won't walk to Tirisfal at 8).
local HOME = { O = { Durotar = true }, R = { Durotar = true }, T = { Mulgore = true }, U = { ["Tirisfal Glades"] = true }, S = { ["Zephras Isle"] = true, Mulgore = true },
  H = { ["Elwynn Forest"] = true }, D = { ["Dun Morogh"] = true }, G = { ["Dun Morogh"] = true }, N = { Teldrassil = true }, A = { ["Zephras Isle"] = true, Westfall = true } }
local START = { Durotar = true, Mulgore = true, ["Tirisfal Glades"] = true, ["Zephras Isle"] = true, ["Elwynn Forest"] = true, ["Dun Morogh"] = true, Teldrassil = true }
local home = HOME[RG.RACE_LETTER] or {}
for _, g in ipairs((RG.CLASS_GEAR or {})[C.token] or {}) do
  local farStart = (g.lvl or 0) < 13 and START[g.zone] and not home[g.zone]
  if not have[g.id] and not farStart then guide[#guide + 1] = g; have[g.id] = true end
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
if faction == "Alliance" and own.token == "PALADIN" then   -- Forsaken paladin quests, not yours
  own = { weights = own.weights }
  RG.CLASS_QUESTS = {}
end
for _, src in ipairs({ H, R, own }) do
  for _, r in ipairs(src.route or {}) do route[#route + 1] = r end
  for _, t in ipairs(src.travel or {}) do travel[#travel + 1] = t end
  for k, v in pairs(src.steps or {}) do steps[k] = v end
end
-- A race can move shared entries (its home dungeons come first: R.prefer = { zone = o }).
for _, r in ipairs(route) do
  if R.prefer and R.prefer[r.zone] then r.o = R.prefer[r.zone] end
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
-- Starting zones with generated quest steps (Routes/Generated.lua): text, the
-- quests each step covers (so it ticks itself off) and the hub's waypoint.
local stepQuests, stepWp = {}, {}
local function mergeGen(src, letter)
  local gen = src.gen and RG.GEN_STEPS and RG.GEN_STEPS[letter]
  if not gen then return end
  for _, r in ipairs(src.route or {}) do
    local key = r.zone .. "|" .. r.from
    local g = gen[key]
    if g and not (src.steps and src.steps[key]) then
      local texts, qs, ws = {}, {}, {}
      for i, s in ipairs(g) do texts[i], qs[i], ws[i] = s.t, s.q, s.w end
      steps[key], stepQuests[key], stepWp[key] = texts, qs, ws
    end
  end
end
mergeGen(R, RG.RACE_LETTER)
mergeGen(H, "F")      -- Alliance: the zones every race shares
-- Lines for one class ("Paladins: ...") only show for that class.
local CLASS_PLURAL = { Warriors = "WARRIOR", Paladins = "PALADIN", Hunters = "HUNTER", Rogues = "ROGUE", Priests = "PRIEST",
  Shamans = "SHAMAN", Mages = "MAGE", Warlocks = "WARLOCK", Druids = "DRUID" }
-- Map pins (Waypoints.lua) are numbered by a step's place in the data file, so
-- RG.STEP_ORIG remembers where each kept line sat before the others were removed.
local stepOrig = {}
for key, list in pairs(steps) do
  local keep, orig, changed = {}, {}, false
  for i, text in ipairs(list) do
    local who = type(text) == "string" and text:match("^(%a+): ")
    if who and CLASS_PLURAL[who] and CLASS_PLURAL[who] ~= RG.PLAYER_CLASS then changed = true
    else keep[#keep + 1] = text; orig[#keep] = i end
  end
  if changed and not stepQuests[key] then steps[key] = keep; stepOrig[key] = orig end
end
RG.STEP_ORIG = stepOrig
RG.ROUTE, RG.TRAVEL, RG.STEPS = route, travel, steps
RG.STEP_QUESTS, RG.STEP_WP = stepQuests, stepWp
-- Dungeon quests: the hand-written list for each dungeon plus every other quest
-- for it in the quest data (Routes/Generated.lua), only the ones this race and
-- class can take.
local function forMe(g)
  if g.ra and not g.ra:find(RG.RACE_LETTER, 1, true) then return false end
  if g.cl and not g.cl:find(RG.CLASS_LETTER, 1, true) then return false end
  return true
end
local dungeons = {}
for name, dq in pairs(H.dungeons or {}) do
  local copy = {}
  for k, v in pairs(dq) do copy[k] = v end
  local list, seen = {}, {}
  for _, q in ipairs(dq.quests or {}) do list[#list + 1] = q; seen[(q[1]:gsub("%s*%(.-%)$", ""))] = true end
  for _, g in ipairs(((faction == "Alliance" and RG.GEN_DUNGEONS_A) or RG.GEN_DUNGEONS or {})[name] or {}) do
    if not seen[g.n] and g.g ~= "" and forMe(g) and g.l <= (dq.go or 0) + 12 and g.r <= (dq.go or 60) + 2 then
      seen[g.n] = true
      list[#list + 1] = { g.n, g.g, g.at, wp = g.w, id = g.id }
    end
  end
  copy.quests = list
  dungeons[name] = copy
end
RG.DUNGEON_QUESTS = dungeons

-- ---------------------------------------------------------------------------
-- Professions (all of them for now; the tabs check your skills)
-- ---------------------------------------------------------------------------
local P = RG.PROFESSIONS
if faction == "Alliance" then   -- trainers for the Alliance towns
  for _, pd in pairs(P) do if pd.trainA then pd.train = pd.trainA end end
end
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

-- Only this character's class and race data is ever used: let the rest go so
-- the other eight classes' gear lists and other races' starting routes don't
-- sit in memory. (The data audit keeps everything.)
if not RG.KEEP_ALL_DATA then
  for _, t in ipairs({ RG.CLASS_GEAR, RG.SPEC_GEAR, RG.SPEC_HAND }) do
    for cls in pairs(t or {}) do if cls ~= RG.PLAYER_CLASS then t[cls] = nil end end
  end
  for letter in pairs(RG.GEN_STEPS or {}) do if letter ~= RG.RACE_LETTER and letter ~= "F" then RG.GEN_STEPS[letter] = nil end end
  if faction == "Alliance" then RG.GEN_DUNGEONS = nil else RG.GEN_DUNGEONS_A = nil end
  collectgarbage("collect")
end
