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

-- Why the giver won't offer you this quest yet, or nil when it will (race and class are QuestForMe's; done and
-- in-your-log are the caller's). The second value is true when it never will (a later step or the other branch
-- is taken, you're past its level, it needs a profession you don't have).
--   isDone(id), inLog(id): optional; the callers that already know pass their own
local SKILL_NAME = { [129] = "First Aid", [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy", [182] = "Herbalism",
  [185] = "Cooking", [186] = "Mining", [197] = "Tailoring", [202] = "Engineering", [333] = "Enchanting", [356] = "Fishing", [393] = "Skinning" }
local function qname(id) local d = RG.QDATA and RG.QDATA[id]; return (d and d.n) or "an earlier quest" end
local function repOf(faction)
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok, f = pcall(C_Reputation.GetFactionDataByID, faction)
    if ok and type(f) == "table" and f.currentStanding then return f.currentStanding end
  end
  if GetFactionInfoByID then
    local ok, name, _, _, _, _, value = pcall(GetFactionInfoByID, faction)
    if ok and name and type(value) == "number" then return value, name end
  end
end
-- A faction's standing by its name (WoW Forever's new factions have no ID in the quest data: Barkskin Burrow). The game
-- only lists the factions under expanded headers of the reputation panel, so one found once is remembered by its ID and
-- read by that afterwards. nil when it can't be read (not met yet, or under a collapsed header the first time).
local repMemo, repMemoT = {}, nil
local repByNameNow
local function repByName(name)
  -- (asked for each such quest on every refresh: one answer per frame)
  local now = GetTime and GetTime() or 0
  if now ~= repMemoT then repMemo, repMemoT = {}, now end
  local m = repMemo[name]
  if m == nil then m = repByNameNow(name) or false; repMemo[name] = m end
  return m or nil
end
repByNameNow = function(name)
  local ids = RG.db and RG.db.factionIds
  local id = ids and ids[name]
  if id then
    local v = repOf(id)
    if v then return v end
  end
  local get = C_Reputation and C_Reputation.GetFactionDataByIndex
  local num = (C_Reputation and C_Reputation.GetNumFactions) or GetNumFactions
  if not num then return nil end
  local okN, n = pcall(num)
  if not okN or type(n) ~= "number" then return nil end
  for i = 1, n do
    local fname, value, fid
    if get then
      local ok, f = pcall(get, i)
      if ok and type(f) == "table" then fname, value, fid = f.name, f.currentStanding, f.factionID end
    elseif GetFactionInfo then
      local ok, a, _, _, _, _, v, _, _, _, _, _, _, fi = pcall(GetFactionInfo, i)
      if ok then fname, value, fid = a, v, fi end
    end
    if fname == name and type(value) == "number" then
      if fid and RG.db then RG.db.factionIds = RG.db.factionIds or {}; RG.db.factionIds[name] = fid end
      return value
    end
  end
  return nil
end
local function knows(spell)
  if IsPlayerSpell then local ok, v = pcall(IsPlayerSpell, spell); if ok and v ~= nil then return v end end
  if IsSpellKnown then local ok, v = pcall(IsSpellKnown, spell); if ok and v ~= nil then return v end end
end
-- profession names are English here: only judge them on an English client that lists its skills
local function skillsReadable()
  local loc = GetLocale and GetLocale() or "enUS"
  if loc ~= "enUS" and loc ~= "enGB" then return false end
  return RG.Professions and next(RG.Professions()) ~= nil
end
-- quick: only whether it is blocked (true), without building the reason (the nearby-quests search asks this of hundreds of quests)
local function why(quick, a, b) if quick then return true end return b ~= nil and (a .. b) or a end
local function takenBy(q, isDone, inLog) return isDone(q) or inLog(q) end
local function alwaysNo() return false end
local function onQuest(q) return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(q) or false end
-- Has this quest been handed in? The game's flag, and the ones you handed in this session: the flag can lag a moment
-- behind QUEST_TURNED_IN, and the quest that follows (offered by the same NPC straight away) must count as open by then
local turnedIn = {}
local flagged   -- (the game's own check, looked up once: this is asked thousands of times a refresh)
function RG.QuestDone(id)
  if turnedIn[id] then return true end
  if flagged == nil then flagged = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or false end
  return flagged and flagged(id) and true or false
end
-- When you handed a quest in this session (GetTime), or nil: the guide follows a storyline you're in (Guide.lua)
function RG.TurnedInAt(id) local t = turnedIn[id]; return type(t) == "number" and t or nil end
if CreateFrame then   -- (the offline audit loads this file without the game's frames)
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "QUEST_TURNED_IN")
  f:SetScript("OnEvent", function(_, _, qid) if qid then turnedIn[qid] = GetTime and GetTime() or true end end)
end
-- Are a bring-items quest's items (d.bi = {{item, how many}, ...}) all in your bags?
function RG.HasBringItems(d)
  local count = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not (d and d.bi and count) then return false end
  for _, b in ipairs(d.bi) do
    local ok, n = pcall(count, b[1])
    if not ok or (n or 0) < (b[2] or 1) then return false end
  end
  return true
end
-- Do a bring-items quest's items drop somewhere the data knows (Salve via Hunting: Corrupted Soul Shards from Felwood's
-- oozes and owls)? Then the guide has you collect them, and the quest waits for that like any other.
-- Returns the item objectives (d.o entries), one per item, or nil.
function RG.BringFarmable(d)
  if not (d and d.bi and d.o) then return nil end
  local out = {}
  for _, b in ipairs(d.bi) do
    local found
    for _, o in ipairs(d.o) do if o[1] == "i" and o[6] == b[1] and o[4] and #o[4] > 0 then found = o break end end
    if not found then return nil end
    out[#out + 1] = { o = found, item = b[1], need = b[2] or 1 }
  end
  return out
end
local goneAt, goneMemo = nil, {}
function RG.QuestBlocked(id, d, isDone, inLog, quick, depth)
  d = d or (RG.QDATA and RG.QDATA[id])
  if not d then return nil end
  isDone = isDone or RG.QuestDone or alwaysNo
  inLog = inLog or onQuest
  if not depth then
    local now = GetTime and GetTime() or 0
    if goneAt ~= now then goneAt = now; goneMemo = {} end
  end
  -- an earlier quest you can never take now (it starts from an item that only sometimes drops, you took the other
  -- branch, it needs a profession you don't have): neither can this one, until that one is in your log or done
  -- (Rescue From Jaedenar waits on A Strange Red Key, which starts from a Blood Red Key that rarely drops)
  local function gone(p)
    if (depth or 0) >= 4 or isDone(p) or inLog(p) then return false end
    local pd = RG.QDATA and RG.QDATA[p]
    if not pd then return false end
    -- (asked of hundreds of quests per refresh: the answer is kept for the rest of the frame, per way of asking)
    local m = goneMemo[isDone]; if not m then m = {}; goneMemo[isDone] = m end
    local key = inLog == onQuest and p or -p
    local v = m[key]
    if v == nil then
      local _, never = RG.QuestBlocked(p, pd, isDone, inLog, true, (depth or 0) + 1)
      v = never and true or false
      m[key] = v
    end
    return v
  end
  local lvl = UnitLevel("player") or 1
  -- never again
  if d.x then for _, p in ipairs(d.x) do if takenBy(p, isDone, inLog) then return why(quick, "you took the other branch"), true end end end
  if d.nx and takenBy(d.nx, isDone, inLog) then return why(quick, "you're past this step"), true end
  if d.bc and takenBy(d.bc, isDone, inLog) then return why(quick, "you already have the quest it leads to"), true end
  if d.uc and isDone(d.uc) then return why(quick, "no longer offered"), true end
  if d.mx and lvl > d.mx then return why(quick, "only up to level ", d.mx), true end
  -- it starts from an item that only sometimes drops: nothing to go and get (it shows once it's in your log)
  if not d.s and d.si and d.si[5] ~= 1 then return why(quick, "starts from ", d.si[2] .. " (it may drop)"), true end
  if d.sk and skillsReadable() then
    local name = SKILL_NAME[d.sk[1]]
    local have = name and RG.Skill and RG.Skill(name)
    if name and not have then return why(quick, "needs ", name), true end
    if have and have < (d.sk[2] or 0) then return why(quick, "needs ", name .. " " .. d.sk[2]) end
  end
  if d.sp then
    local k = knows(math.abs(d.sp))
    if k ~= nil and k ~= (d.sp > 0) then return d.sp > 0 and "needs a spell or specialization you don't have" or "not for your specialization", true end
  end
  -- taken only with its items in your bags (Salve via Hunting: 6 Corrupted Soul Shards; talking to the giver hands them
  -- in): without them there's nothing to pick up, and the route doesn't wait for it
  if d.bi and not RG.HasBringItems(d) and not RG.BringFarmable(d) then
    if quick then return true, true end
    local need = {}
    for _, b in ipairs(d.bi) do
      local name = GetItemInfo and GetItemInfo(b[1])
      need[#need + 1] = (b[2] > 1 and (b[2] .. " ") or "") .. (name or "its items")
    end
    return "bring " .. table.concat(need, ", ") .. " first", true
  end
  -- not yet (or never, behind a quest you can't take)
  if d.pg then
    for _, p in ipairs(d.pg) do
      if not isDone(p) then
        if gone(p) then return why(quick, "after ", qname(p) .. ", which you can't take now"), true end
        return why(quick, "after ", qname(p))
      end
    end
  end
  if d.ps then
    local any, open = false, nil
    for _, p in ipairs(d.ps) do
      if isDone(p) then any = true break end
      if not open and not gone(p) then open = p end
    end
    if not any then
      if not open then return why(quick, "after ", qname(d.ps[1]) .. ", which you can't take now"), true end
      return why(quick, "after ", qname(open))
    end
  end
  if d.pa and not inLog(d.pa) then return why(quick, "only while you have ", qname(d.pa)) end
  if d.sw and not takenBy(d.sw, isDone, inLog) then return why(quick, "after ", qname(d.sw)) end
  if d.dq then for _, p in ipairs(d.dq) do if inLog(p) then return why(quick, "after you finish ", qname(p)) end end end
  if (d.r or 1) > lvl then return why(quick, "at level ", d.r) end
  if d.rp then local v = repOf(d.rp[1]); if v and v < d.rp[2] then return why(quick, "needs more reputation") end end
  if d.rn then local v = repByName(d.rn[1]); if v and v < d.rn[2] then return why(quick, "needs more reputation with ", d.rn[1]) end end
  if d.rx then local v = repOf(d.rx[1]); if v and v >= d.rx[2] then return why(quick, "your reputation is too high"), true end end
  -- the giver didn't offer it when you were there (data can't know everything): until you level or hand something in there
  local no = RG.db and RG.db.notOffered and RG.db.notOffered[id]
  if no and no == lvl then return why(quick, "not offered yet (you checked)") end
  return nil
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

-- Weapon setups the Gear tab offers besides the class's own: two weapons (DW) or a one-hander and a shield (SB).
-- The generated lists carry their weapons (ws = "DW" / "SB"); a setup scores weapons its own way.
RG.WEAPON_SETUPS = { WARRIOR = { "DW", "SB" }, PALADIN = { "SB" }, SHAMAN = { "SB" }, HUNTER = { "DW" } }
RG.SETUP_MODEL = { DW = "DW", SB = "tank" }
RG.SETUP_LABEL = { ["2H"] = "Two-hander", DW = "Two weapons", SB = "One-hander and shield", ranged = "Two-hander", caster = "Staff, or one-hander and off-hand", feral = "Staff or two-hander" }
-- the setup you picked for this class (nil = the class's own)
function RG.WeaponSetup()
  local by = RG.db and RG.db.weaponSetupByClass
  local s = by and by[C.token]
  for _, v in ipairs(RG.WEAPON_SETUPS[C.token] or {}) do if v == s then return s end end
  return nil
end
local WEAPON_SLOT = { ["2H"] = true, ["Main Hand"] = true, ["Off Hand"] = true }
-- The best piece from each kind of source, beyond the guide's own picks (the Gear tab's by-source view)
RG.GUIDE_ALT = RG.GUIDE_ALT or {}

-- Gear guide: hand-written entries, then the generated list (hand-written
-- entries win when both list an item).
-- specKey: build the guide for a leveling spec other than the class's default (generated gear lists only)
local function buildGuide(specKey)
  local guide, have = {}, {}
  -- The hand-written Paladin guide is written for an Undead paladin: on the Alliance side it keeps
  -- only the entries that work for everyone (crafting, dungeons, neutral zones).
  local HORDE_TEXT = { "Camp Taurajo", "Tok'Kar", "Camp Mojache", "Undercity", "Tirisfal", "Brill", "Horde", "Deathknell", "Silverpine", "Bandarion", "Forsaken" }
  local function hordeOnly(g)
    local t = (g.src or "") .. " " .. (g.zone or "") .. " " .. (g.text or "")
    for _, w in ipairs(HORDE_TEXT) do if t:find(w, 1, true) then return true end end
    return false
  end
  -- a weapon setup of your own (leveling spec only): its weapons replace the class's
  local setup = not specKey and RG.WeaponSetup and RG.WeaponSetup() or nil
  local function setupSkip(g) return setup and WEAPON_SLOT[g.slot] and g.ws ~= setup end
  for _, g in ipairs(specKey and (((RG.SPEC_HAND or {})[C.token] or {})[specKey] or {}) or (C.guide or {})) do
    if not (faction == "Alliance" and hordeOnly(g)) and not setupSkip(g) then guide[#guide + 1] = g; if g.id then have[g.id] = true end end
  end
  local alt = RG.GUIDE_ALT
  for i = #alt, 1, -1 do alt[i] = nil end
  -- Before level 13 you're still in or near your own starting zone: skip early
  -- items from the other races' starting zones (an Orc won't walk to Tirisfal at 8).
  local HOME = { O = { Durotar = true }, R = { Durotar = true }, T = { Mulgore = true }, U = { ["Tirisfal Glades"] = true }, S = { ["Zephras Isle"] = true, Mulgore = true },
    H = { ["Elwynn Forest"] = true }, D = { ["Dun Morogh"] = true }, G = { ["Dun Morogh"] = true }, N = { Teldrassil = true }, A = { ["Zephras Isle"] = true, Westfall = true } }
  local START = { Durotar = true, Mulgore = true, ["Tirisfal Glades"] = true, ["Zephras Isle"] = true, ["Elwynn Forest"] = true, ["Dun Morogh"] = true, Teldrassil = true }
  local home = HOME[RG.RACE_LETTER] or {}
  for _, g in ipairs(specKey and (((RG.SPEC_GEAR or {})[C.token] or {})[specKey] or {}) or ((RG.CLASS_GEAR or {})[C.token] or {})) do
    local farStart = (g.lvl or 0) < 13 and START[g.zone] and not home[g.zone]
    if g.ws and g.ws ~= setup then farStart = true end   -- (another setup's weapons)
    if setupSkip(g) then farStart = true end
    if g.alt then
      if not farStart then alt[#alt + 1] = g end
    elseif not have[g.id] and not farStart then guide[#guide + 1] = g; have[g.id] = true end
  end
  table.sort(guide, function(a, b)
    if a.lvl ~= b.lvl then return a.lvl < b.lvl end
    return (a.tip and 0 or 1) < (b.tip and 0 or 1)
  end)
  if RG.GUIDE then   -- rebuilt in place so everything holding the table sees the new guide
    for i = #RG.GUIDE, 1, -1 do RG.GUIDE[i] = nil end
    for i, g in ipairs(guide) do RG.GUIDE[i] = g end
  else RG.GUIDE = guide end
end
RG.BuildGuide = buildGuide
buildGuide(nil)

-- ---------------------------------------------------------------------------
-- Route: faction zones + race starting zones + class milestones
-- ---------------------------------------------------------------------------
local route, travel, steps = {}, {}, {}
-- Zones found in WoW Forever's quest data that no hand-written entry lists yet (Routes/Generated.lua, RG.GEN_AUTO):
-- a zone that arrives with new content is in the route, with its generated steps, before anyone writes it up.
do
  local auto = RG.GEN_AUTO and RG.GEN_AUTO[faction == "Alliance" and "F" or "X"]
  if auto and H.route then
    local have = {}
    for _, r in ipairs(H.route) do have[r.zone] = true end
    for _, z in ipairs(auto) do
      if not have[z.zone] then
        have[z.zone] = true
        H.route[#H.route + 1] = { from = z.from, to = z.to, kind = "zone", zone = z.zone, hub = z.hub or z.zone, auto = true,
          notes = "New zone, found in WoW Forever's quest data (" .. (z.n or 0) .. " quests, levels " .. z.from .. "-" .. z.to .. "). The steps are built from that data; travel tips follow in an update." }
      end
    end
  end
end
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
mergeGen(H, faction == "Alliance" and "F" or "X")      -- the zones every race of your faction shares
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
  local list, seen, extra = {}, {}, {}
  for _, q in ipairs(dq.quests or {}) do list[#list + 1] = q; seen[(q[1]:gsub("%s*%(.-%)$", ""))] = true end
  for _, g in ipairs(((faction == "Alliance" and RG.GEN_DUNGEONS_A) or RG.GEN_DUNGEONS or {})[name] or {}) do
    if not seen[g.n] and forMe(g) and g.l <= (dq.go or 0) + 12 and g.r <= (dq.go or 60) + 2 then
      if g.g ~= "" then
        seen[g.n] = true
        list[#list + 1] = { g.n, g.g, g.at, wp = g.w, id = g.id }
      else
        -- no one outside gives it (it starts inside the dungeon, or from an item or a poster): only the preobtain
        -- plan lists these (DungeonPrep.lua), so the leveling guide's dungeon lists don't change
        extra[#extra + 1] = { g.n, "", g.at, id = g.id }
      end
    end
  end
  copy.quests, copy.extra = list, extra
  dungeons[name] = copy
end
RG.DUNGEON_QUESTS = dungeons

-- ---------------------------------------------------------------------------
-- Professions (all of them for now; the tabs check your skills)
-- ---------------------------------------------------------------------------
local P = RG.PROFESSIONS
if faction == "Alliance" then   -- trainers for the Alliance towns
  for _, pd in pairs(P) do
    if pd.trainA then pd.train = pd.trainA end
    if pd.suppliesA then pd.supplies = pd.suppliesA end
  end
end
RG.MINING = P.Mining and ((faction == "Alliance" and P.Mining.zonesA) or P.Mining.zones) or {}
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
  for letter in pairs(RG.GEN_STEPS or {}) do if letter ~= RG.RACE_LETTER and letter ~= (faction == "Alliance" and "F" or "X") then RG.GEN_STEPS[letter] = nil end end
  if faction == "Alliance" then RG.GEN_DUNGEONS = nil else RG.GEN_DUNGEONS_A = nil end
  -- (Objectives.lua loads after this file and calls RG.PruneQuests when it is done)
  -- the other faction's route and the other races' definitions
  for f in pairs(RG.ROUTES) do if f ~= faction then RG.ROUTES[f] = nil end end
  for tok in pairs(RG.RACES) do if RG.RACES[tok] ~= R then RG.RACES[tok] = nil end end
  collectgarbage("collect")
end

-- Quests another race or class can never take (about a third of the quest table).
function RG.PruneQuests()
  if RG.KEEP_ALL_DATA or not RG.QDATA then return end
  for id, d in pairs(RG.QDATA) do
    if (d.ra and not d.ra:find(RG.RACE_LETTER, 1, true)) or (d.cl and not d.cl:find(RG.CLASS_LETTER, 1, true)) then RG.QDATA[id] = nil end
  end
  collectgarbage("collect")
end
