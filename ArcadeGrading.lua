local _, RG = ...
-- Waypath Cards: grading by the Waypoint Grading Guild (1.53). The rules and the save; ArcadeGradingUI.lua draws it.
--   * Every copy of a card has a hidden condition, fixed when the game first sees that copy (a pull, a trade, a craft,
--     or a copy you already had when grading arrived): four scores, Centering, Corners, Edges and Surface (1 to 10 in
--     halves). Nobody sees them until the copy comes back from the graders.
--   * The grade comes from the four scores: a 10 (Gem Mint) needs every score 9.5 or better and three of them 10;
--     otherwise the average, but never more than one above the lowest score. About 1 card in 15 grades a 10.
--   * Standard: back in 12 hours, 40 coins. Express: 1 hour, 150 coins. Five cards at the graders at once.
--     The first 5 Standard gradings are free (once per account), and one more each week (it doesn't pile up).
--   * A graded copy sits in a case: it can't be sold as an extra, crafted, refunded or given away, but it can be sold
--     for its grade, pinned to your showcase, or cracked out of its case (its condition is rolled again: send it back
--     for another chance).

local GRADE_NAME = { "Poor", "Fair", "Good", "Very Good", "Fine", "Very Fine", "Excellent", "Near Mint", "Mint", "Gem Mint" }
local SUBS = { "Centering", "Corners", "Edges", "Surface" }
-- how often each grade comes back (10 down to 1): 1 in 15 for a Gem Mint
local ODDS = { [10] = 1 / 15, [9] = 0.18, [8] = 0.24, [7] = 0.20, [6] = 0.13, [5] = 0.08, [4] = 0.05, [3] = 0.03, [2] = 0.015 }
do local s = 0; for g = 2, 10 do s = s + ODDS[g] end; ODDS[1] = 1 - s end
local SERVICE = {
  standard = { name = "Standard", secs = 12 * 3600, price = 40 },
  express = { name = "Express", secs = 3600, price = 150 },
}
local SLOTS, FIRST_FREE = 5, 5
local SELL_MULT = { [10] = 8, [9] = 4, [8] = 2 }   -- (7 and below: 1)
RG.ARCADE_GRADE = { NAME = GRADE_NAME, SUBS = SUBS, ODDS = ODDS, SERVICE = SERVICE, SLOTS = SLOTS, FIRST_FREE = FIRST_FREE, SELL_MULT = SELL_MULT }

local function U() return RG.ArcadeUI end
local function store() local u = U(); return u and u.store and u.store() end
local function now() return (time and time()) or 0 end
local function rnd(n) return math.random(n) end
local function weekKey()   -- (Tuesday, as the collector's weekly quests)
  if not (date and time) then return "week" end
  local t = time()
  local back = (tonumber(date("%w", t)) - 2) % 7
  return date("%Y-%m-%d", t - back * 86400)
end

-- ---------------------------------------------------------------------------
-- Scores and grades
-- ---------------------------------------------------------------------------
-- a condition is stored as 4 two-digit numbers, each score doubled: "20191820" = 10, 9.5, 9, 10
local function decode(s)
  if type(s) ~= "string" or #s ~= 8 then return nil end
  local t = {}
  for i = 1, 4 do local v = tonumber(s:sub(i * 2 - 1, i * 2)); if not v or v < 2 or v > 20 then return nil end; t[i] = v / 2 end
  return t
end
local function encode(t) return string.format("%02d%02d%02d%02d", t[1] * 2, t[2] * 2, t[3] * 2, t[4] * 2) end
local function gradeOf(s)
  local mn, sum, tens = 10, 0, 0
  for i = 1, 4 do mn = math.min(mn, s[i]); sum = sum + s[i]; if s[i] >= 10 then tens = tens + 1 end end
  if mn >= 9.5 and tens >= 3 then return 10 end
  return math.max(1, math.min(9, math.floor(sum / 4), math.floor(mn) + 1))
end
-- roll a condition: the grade first (so the odds are exactly the table's), then four scores that give it
local function rollCondition()
  local x, g = math.random(), 1
  for k = 10, 1, -1 do x = x - ODDS[k]; if x <= 0 then g = k; break end end
  local s = {}
  if g == 10 then
    for i = 1, 4 do s[i] = 10 end
    if math.random() < 0.6 then s[rnd(4)] = 9.5 end
    return s
  end
  for _ = 1, 400 do
    for i = 1, 4 do
      -- scores sit around the grade: most a little above it, one or two holding it down
      local v = g + 0.5 + (math.random() * 2.2 - 0.6)
      if math.random() < 0.3 then v = g - 0.5 + math.random() * 1.5 end
      s[i] = math.max(1, math.min(10, math.floor(v * 2 + 0.5) / 2))
    end
    if gradeOf(s) == g then return s end
  end
  for i = 1, 4 do s[i] = math.max(1, g) end   -- (never reached in practice)
  return s
end
RG.ArcadeGradeOf, RG.ArcadeGradeRoll, RG.ArcadeGradeDecode, RG.ArcadeGradeEncode = gradeOf, rollCondition, decode, encode

-- the line before the last score: what it needs ("Surface: a 10 makes this Gem Mint. A 9 keeps it Mint.")
function RG.ArcadeGradeStakes(first3)
  local function with(v) return gradeOf({ first3[1], first3[2], first3[3], v }) end
  local best = with(10)
  local function need(g) for v = 1, 10, 0.5 do if with(v) >= g then return v end end end
  local vb = need(best)
  local function vtext(v) local n = (v == math.floor(v)) and tostring(v) or string.format("%.1f", v); return (v >= 10) and "a 10" or (n .. " or better") end
  local t = SUBS[4] .. ": " .. vtext(vb) .. " makes this " .. GRADE_NAME[best] .. " " .. best .. "."
  if best > 1 then
    local v2 = need(best - 1)
    if v2 and v2 < vb then t = t .. " " .. (v2 >= 10 and "A 10" or ((v2 == math.floor(v2) and tostring(v2) or string.format("%.1f", v2)) .. " or better")) .. " keeps it " .. GRADE_NAME[best - 1] .. "." end
  end
  return t, best
end
-- after: the one score that kept it from the next grade, if a single score did ("Corners kept this from a 9.")
function RG.ArcadeGradeNearMiss(s)
  local g = gradeOf(s)
  if g >= 10 then return nil end
  local bestI, bestGain
  for i = 1, 4 do
    local t = { s[1], s[2], s[3], s[4] }; t[i] = 10
    if gradeOf(t) > g and (not bestI or s[i] < s[bestI]) then bestI = i end
  end
  if bestI then return SUBS[bestI] .. " kept this from " .. ((g + 1 == 8) and "an 8" or ("a " .. (g + 1))) .. ".", bestI end
end
-- how worn each part looks (0 none .. 4 the worst) from its score, and the centering offset
function RG.ArcadeGradeWear(s)
  local function lvl(v) if v >= 9.5 then return 0 elseif v >= 8 then return 1 elseif v >= 6.5 then return 2 elseif v >= 4.5 then return 3 end return 4 end
  return { centering = lvl(s[1]), corners = lvl(s[2]), edges = lvl(s[3]), surface = lvl(s[4]) }
end
function RG.ArcadeGradeName(g) return GRADE_NAME[g] or "" end
function RG.ArcadeGradeSeal(g) return (g >= 10 and "gold") or (g >= 8 and "silver") or "bronze" end

-- ---------------------------------------------------------------------------
-- Certificates: who graded it (its owner: "Name-Realm") and its number make it one of a kind (its id); the check
-- (sig) is worked out from the case's own facts, so a case edited by hand in the save file, or sent with its grade
-- changed, no longer passes (ArcadeGradingGuild.lua checks every case it's sent, and leaves out any that fail).
-- ---------------------------------------------------------------------------
local SALT = "Waypoint Grading Guild / est. 2026 / every print graded the same"
local function hash(str, seed, m)
  local h = seed
  for i = 1, #str do h = (h * 31 + str:byte(i)) % m end
  return h
end
local function sign(r)
  local body = table.concat({ tostring(r.cert), tostring(r.owner), tostring(r.key), tostring(r.f), tostring(r.grade), tostring(r.s), tostring(r.when) }, "|") .. SALT
  return string.format("%08x%06x", hash(body, 7, 4294967291), hash(body:reverse(), 13, 16777213))
end
local function valid(r)
  if type(r) ~= "table" or type(r.key) ~= "string" or type(r.owner) ~= "string" or type(r.cert) ~= "number" then return false end
  local s = decode(r.s); if not s then return false end
  if r.grade ~= gradeOf(s) or not (r.f and r.f >= 1 and r.f <= 5) then return false end
  return r.sig == sign(r)
end
local function meOwner()
  local n = (UnitName and select(2, pcall(UnitName, "player"))) or "?"
  local realm = (GetNormalizedRealmName and select(2, pcall(GetNormalizedRealmName))) or (GetRealmName and select(2, pcall(GetRealmName))) or ""
  if type(n) ~= "string" then n = "?" end
  if type(realm) ~= "string" then realm = "" end
  return n .. (realm ~= "" and ("-" .. realm:gsub("%s", "")) or "")
end
RG.ArcadeGradeSign, RG.ArcadeGradeValid, RG.ArcadeGradeOwner = sign, valid, meOwner

-- ---------------------------------------------------------------------------
-- The save: a.grading = { queue = {...}, back = {...}, cases = {...}, firstUsed, weekUsed, nextCert }, a.cond[key][f] = { conditions }
-- ---------------------------------------------------------------------------
local function G(a)
  a.grading = a.grading or {}
  local g = a.grading
  g.queue = g.queue or {}; g.back = g.back or {}; g.cases = g.cases or {}
  g.firstUsed = g.firstUsed or 0
  if not g.nextCert then g.nextCert = (hash(meOwner(), 3, 9000) + 1000) * 1000 + 1 end   -- (7 digits, different for each grader)
  -- (cases from before certificates: yours, made by this version; sign them once)
  if not g.signed then
    for _, r in ipairs(g.cases) do
      r.owner = r.owner or meOwner(); r.id = r.id or (r.owner .. "#" .. r.cert)
      if not r.sig then r.sig = sign(r) end
    end
    g.signed = true
  end
  return g
end
-- copies of a print that are graded, at the graders or waiting to be opened (they stay in your collection)
local function held(a, key, f)
  local g = G(a); local n = 0
  for _, q in ipairs(g.queue) do if q.key == key and q.f == f then n = n + 1 end end
  for _, q in ipairs(g.back) do if q.key == key and q.f == f then n = n + 1 end end
  for _, r in ipairs(g.cases) do if r.key == key and r.f == f then n = n + 1 end end
  return n
end
local function count(a, key, f) local s = a.cards and a.cards[key]; return s and (s[f] or 0) or 0 end
-- the hidden conditions of the copies not in a case: one for each, rolled the first time a copy is seen
local function conditions(a, key, f)
  a.cond = a.cond or {}
  local free = math.max(0, count(a, key, f) - held(a, key, f))
  local t = a.cond[key]; if not t then t = {}; a.cond[key] = t end
  local l = t[f]; if not l then l = {}; t[f] = l end
  while #l > free do table.remove(l) end
  while #l < free do l[#l + 1] = encode(rollCondition()) end
  if free == 0 then t[f] = nil; if not next(t) then a.cond[key] = nil end end
  return l
end
RG.ArcadeGradeHeld = function(key, f) local a = store(); return a and held(a, key, f) or 0 end
function RG.ArcadeGradeFree(a, key, f) return math.max(0, count(a, key, f) - held(a, key, f)) end
RG.ArcadeGradeConditions = function(key, f) local a = store(); return a and conditions(a, key, f) or {} end

-- free gradings: the first five, then one a week
function RG.ArcadeGradeFreeLeft()
  local a = store(); if not a then return 0, false end
  local g = G(a)
  local first = math.max(0, FIRST_FREE - g.firstUsed)
  local weekly = g.weekUsed ~= weekKey()
  return first, weekly
end
local function cardOf(key) local u = U(); return u and u.byKey and u.byKey[key] end
function RG.ArcadeGradeable(c) return c and c.kind ~= nil end   -- (every card: items, creatures, places, raiders, rivals, Mythics)

function RG.ArcadeGradeSend(key, f, svc, which)
  local a = store(); if not a then return false, "Nothing to grade yet." end
  local c = cardOf(key); local sv = SERVICE[svc]
  if not (c and sv and f and f >= 1 and f <= 5) then return false, "Pick a card and a service." end
  local g = G(a)
  if #g.queue >= SLOTS then return false, "All " .. SLOTS .. " grading slots are busy. One comes back soon." end
  local l = conditions(a, key, f)
  if #l == 0 then return false, "You have no ungraded copy of that print." end
  which = math.max(1, math.min(#l, tonumber(which) or 1))
  local first, weekly = RG.ArcadeGradeFreeLeft()
  local free
  if svc == "standard" and first > 0 then free = "first"
  elseif svc == "standard" and weekly then free = "week"
  elseif (a.coins or 0) < sv.price then return false, sv.name .. " grading costs " .. sv.price .. " coins. You have " .. (a.coins or 0) .. "." end
  local cond = table.remove(l, which)
  if free == "first" then g.firstUsed = g.firstUsed + 1
  elseif free == "week" then g.weekUsed = weekKey()
  else a.coins = a.coins - sv.price; a.stats = a.stats or {}; a.stats.gradeSpent = (a.stats.gradeSpent or 0) + sv.price end
  local t = now()
  g.queue[#g.queue + 1] = { key = key, f = f, svc = svc, sent = t, due = t + sv.secs, cond = cond, free = free }
  if RG.ArcadeQuestEvent then pcall(RG.ArcadeQuestEvent, "graded", 1) end
  if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
  -- (short enough for the window's one message line)
  return true, c.name .. " is off to the graders: back in " .. (svc == "express" and "1 hour" or "12 hours") ..
    (free == "first" and ", free." or (free == "week" and ", this week's free one." or (", " .. sv.price .. " coins.")))
end

-- parcels whose time is up move to the doorstep (unopened); returns how many arrived
function RG.ArcadeGradeTick()
  local a = store(); if not a then return 0 end
  local g = G(a); local t = now(); local n = 0
  for i = #g.queue, 1, -1 do
    local q = g.queue[i]
    if (q.due or 0) <= t then table.remove(g.queue, i); g.back[#g.back + 1] = q; n = n + 1 end
  end
  if n > 0 and RG.ArcadeGradeArrived then pcall(RG.ArcadeGradeArrived, n) end
  return n
end
-- open a parcel: its case, with the grade (the reveal shows it first)
function RG.ArcadeGradeOpen(i)
  local a = store(); if not a then return nil end
  local g = G(a)
  local q = table.remove(g.back, i or 1); if not q then return nil end
  local s = decode(q.cond) or rollCondition()
  local grade = gradeOf(s)
  local cert = g.nextCert; g.nextCert = g.nextCert + 1
  local zone = (GetRealZoneText and select(2, pcall(GetRealZoneText))) or nil
  local r = { cert = cert, key = q.key, f = q.f, grade = grade, s = encode(s), when = date and date("%d %b %Y") or "", t = now(), svc = q.svc,
    by = (UnitName and select(2, pcall(UnitName, "player"))) or "?", where = type(zone) == "string" and zone or nil, owner = meOwner() }
  r.id = r.owner .. "#" .. cert
  r.sig = sign(r)
  r.hist = { { "graded", r.by, r.when } }
  g.cases[#g.cases + 1] = r
  a.stats = a.stats or {}; a.stats.graded = (a.stats.graded or 0) + 1
  a.feat = a.feat or {}; a.feat.n = a.feat.n or {}
  local n = a.feat.n
  n.graded = (n.graded or 0) + 1
  if grade >= 10 then n.gem = (n.gem or 0) + 1 end
  if grade >= 9 then n.grade9 = (n.grade9 or 0) + 1 end
  if q.f == 4 and grade >= 9 then n.gradeFull = (n.gradeFull or 0) + 1 end
  local c = cardOf(q.key)
  if c and c.tier == 7 and grade >= 10 then n.gradeMythic = (n.gradeMythic or 0) + 1 end
  if RG.ArcadeQuestEvent then pcall(RG.ArcadeQuestEvent, "gradeOpened", 1) end
  if RG.ArcadeGradeShare then pcall(RG.ArcadeGradeShare) end   -- (your guild sees it: ArcadeGradingGuild.lua)
  return r, s
end
function RG.ArcadeGradeCases(key, f)
  local a = store(); if not a then return {} end
  local out = {}
  for _, r in ipairs(G(a).cases) do if (not key or r.key == key) and (not f or r.f == f) then out[#out + 1] = r end end
  table.sort(out, function(x, y) if x.grade ~= y.grade then return x.grade > y.grade end return x.cert < y.cert end)
  return out
end
function RG.ArcadeGradeBest(key)
  local best
  for _, r in ipairs(RG.ArcadeGradeCases(key)) do if not best or r.grade > best.grade then best = r end end
  return best
end
function RG.ArcadeGradeState()
  local a = store(); if not a then return { queue = {}, back = {}, cases = {} } end
  return G(a)
end
-- a case by its id ("Owner#cert")
local function findCase(id)
  local a = store(); if not a or id == nil then return nil end
  for i, r in ipairs(G(a).cases) do if r.id == id then return r, i, a end end
end
RG.ArcadeGradeFind = findCase

-- what a graded copy sells for: its grade times the print's value
function RG.ArcadeGradeValue(r)
  local c = cardOf(r.key); local u = U()
  local sell = (u and u.FINISH and u.FINISH[r.f] and u.FINISH[r.f][4]) or 1
  local base = sell + 4 * math.min(7, (c and c.tier) or 1) + 4
  return base * (SELL_MULT[r.grade] or 1), base
end
function RG.ArcadeGradeSell(cert)
  local r, i, a = findCase(cert); if not r then return false, "That case isn't yours any more." end
  if not valid(r) then return false, "This case didn't pass its certificate check, so it can't be sold for its grade. You can still crack it out of its case." end
  local c = cardOf(r.key)
  local v = RG.ArcadeGradeValue(r)
  table.remove(G(a).cases, i)
  local slot = a.cards[r.key]
  if slot and (slot[r.f] or 0) > 0 then slot[r.f] = slot[r.f] - 1 end
  a.coins = (a.coins or 0) + v
  a.stats = a.stats or {}; a.stats.gradeSold = (a.stats.gradeSold or 0) + v
  if slot and (slot[1] or 0) + (slot[2] or 0) + (slot[3] or 0) + (slot[4] or 0) + (slot[5] or 0) == 0 and a.showcase then
    for k = #a.showcase, 1, -1 do if a.showcase[k] == r.key then table.remove(a.showcase, k) end end
  end
  conditions(a, r.key, r.f)
  if RG.ArcadeGradeShare then pcall(RG.ArcadeGradeShare) end
  if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
  return true, (c and c.name or "The card") .. " (" .. r.grade .. ", " .. GRADE_NAME[r.grade] .. ") sold for " .. v .. " coins."
end
-- crack the case: the card is ungraded again, and its condition is rolled again
function RG.ArcadeGradeCrack(cert)
  local r, i, a = findCase(cert); if not r then return false, "That case isn't yours any more." end
  local c = cardOf(r.key)
  table.remove(G(a).cases, i)
  local l = conditions(a, r.key, r.f)   -- (the copy is free again: a fresh condition joins the list)
  a.stats = a.stats or {}; a.stats.cracked = (a.stats.cracked or 0) + 1
  if RG.ArcadeGradeShare then pcall(RG.ArcadeGradeShare) end
  if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
  return true, "You cracked the case. " .. (c and c.name or "The card") .. " is ungraded again: send it back for another chance."
end
-- a case leaving in a trade (its copy goes with it), and one arriving
function RG.ArcadeGradeRemoveCase(id)
  local r, i, a = findCase(id); if not r then return nil end
  table.remove(G(a).cases, i)
  local slot = a.cards[r.key]
  if slot and (slot[r.f] or 0) > 0 then slot[r.f] = slot[r.f] - 1 end
  if slot and (slot[1] or 0) + (slot[2] or 0) + (slot[3] or 0) + (slot[4] or 0) + (slot[5] or 0) == 0 and a.showcase then
    for k = #a.showcase, 1, -1 do if a.showcase[k] == r.key then table.remove(a.showcase, k) end end
  end
  if a.gradePin and a.gradePin[r.key] == id then a.gradePin[r.key] = nil end
  conditions(a, r.key, r.f)
  return r
end
function RG.ArcadeGradeAddCase(r)
  local a = store(); if not (a and valid(r)) then return false end
  r.id = r.owner .. "#" .. r.cert
  if findCase(r.id) then return false end
  local slot = a.cards[r.key] or {}; a.cards[r.key] = slot
  slot[r.f] = (slot[r.f] or 0) + 1
  local g = G(a); g.cases[#g.cases + 1] = r
  conditions(a, r.key, r.f)
  return true
end

-- the case on your showcase: which graded copy stands for the card (its best, unless you chose one)
function RG.ArcadeGradePin(cert)
  local r, _, a = findCase(cert); if not r then return false end
  a.gradePin = a.gradePin or {}
  a.gradePin[r.key] = r.id
  if RG.ArcadePin then
    a.showcase = a.showcase or {}
    local on = false; for _, k in ipairs(a.showcase) do if k == r.key then on = true end end
    if not on then RG.ArcadePin(cardOf(r.key)) end
  end
  if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
  return true
end
function RG.ArcadeGradeShown(key)
  local a = store(); if not a then return nil end
  local pin = a.gradePin and a.gradePin[key]
  if pin then local r = findCase(pin); if r and r.key == key then return r end end
  return RG.ArcadeGradeBest(key)
end

-- ---------------------------------------------------------------------------
-- Feats
-- ---------------------------------------------------------------------------
if RG.ArcadeFeatsAdd then
  local function n(a, k) return (a.feat and a.feat.n and a.feat.n[k]) or 0 end
  RG.ArcadeFeatsAdd("grading", "Grading", {
    { id = "grade1", name = "Sent to the Guild", text = "Get a card graded.", pts = 5, need = 1, have = function(a) return n(a, "graded") end, reward = { coins = 20 } },
    { id = "grade10", name = "A Steady Hand", text = "Get 10 cards graded.", pts = 15, need = 10, have = function(a) return n(a, "graded") end, reward = { coins = 60 } },
    { id = "grade9", name = "Mint Condition", text = "Grade a 9 or better.", pts = 10, need = 1, have = function(a) return n(a, "grade9") end, reward = { coins = 30 } },
    { id = "gem1", name = "Gem Mint", text = "Grade a 10.", pts = 25, need = 1, have = function(a) return n(a, "gem") end, reward = { title = "Gem Hunter" } },
    { id = "gem5", name = "Five Gems", text = "Grade five 10s.", pts = 50, need = 5, have = function(a) return n(a, "gem") end, reward = { title = "Master Grader" } },
    { id = "gemfull", name = "Edge to Edge, Perfect", text = "Grade a Full art print 9 or better.", pts = 30, need = 1, have = function(a) return n(a, "gradeFull") end, reward = { coins = 100 } },
    { id = "gemmythic", name = "Flawless Legend", text = "Grade a Mythic a 10.", pts = 100, need = 1, have = function(a) return n(a, "gradeMythic") end, reward = { title = "the Flawless" } },
  })
end

-- parcels come back while you play: look every 30 seconds
if C_Timer and C_Timer.NewTicker then
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:SetScript("OnEvent", function()
    C_Timer.After(8, function() pcall(RG.ArcadeGradeTick) end)
    C_Timer.NewTicker(30, function() pcall(RG.ArcadeGradeTick) end)
  end)
end
