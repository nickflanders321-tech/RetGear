local _, RG = ...
-- Waypath Cards: the Guild Reserve and the Guild market (the rules; ArcadeReserveUI.lua draws them).
--   * the Reserve: two kinds of pack from the Waypoint Grading Guild, Summit and Pinnacle. A pack is one card that
--     comes already graded and in its case (the same case as a card you sent to the graders: ArcadeGrading.lua), so it
--     skips the wait. Its print is rolled from a table (Full art or Gilded; no Rare or Holo) and a Mythic can come instead;
--     its grade is rolled from a table with a floor (Summit: 8 or better; Pinnacle: 9 or better). The odds are shown
--     before you buy, and a pack costs coins, never anything else.
--   * the Guild market: every day the guild prices the cases anew (the same prices for every player, worked out from
--     the date and the card, no server). A card's price drifts a little each day (never more than 10% either way);
--     four themes are "hot" that day (15 to 30% more) and two are "cooling" (6 to 12% less). The price a case sells for
--     is its grade's price times the day's index, so waiting for a good day can pay, and nothing sells for much less or
--     more than its usual price (the index stays between 0.85 and 1.4).
--   * a Reserve slab counts as a case in every way (sell it, show it on your showcase, crack it out, offer it to your
--     group, share it with your guild), but not as one you graded yourself: the grading feats and quests are for the
--     copies you sent to the graders.

local function U() return RG.ArcadeUI end
local function store() local u = U(); return u and u.store and u.store() end
local function now() return (time and time()) or 0 end
local function cardOf(key) local u = U(); return u and u.byKey and u.byKey[key] end

-- ---------------------------------------------------------------------------
-- The two packs
-- ---------------------------------------------------------------------------
-- grades: the chance of each grade (adds up to 1); prints: { finish, chance } (Rare 2, Holo 3, Full art 4, Gilded 5);
-- mythic: the chance that the card is a Mythic instead (always its Full art print, the grade from the same table)
local TIERS = {
  { key = "summit", name = "Summit", price = 120, floor = 8, mythic = 1 / 60, col = { 0.9, 0.78, 0.45 },
    grades = { [10] = 0.14, [9] = 0.36, [8] = 0.50 },
    prints = { { 4, 0.94 }, { 5, 0.06 } } },
  { key = "pinnacle", name = "Pinnacle", price = 200, floor = 9, mythic = 1 / 18, col = { 1, 0.9, 0.55 },
    grades = { [10] = 0.32, [9] = 0.68 },
    prints = { { 4, 0.80 }, { 5, 0.20 } } },
}
local byKey = {}
for _, t in ipairs(TIERS) do byKey[t.key] = t end
RG.ARCADE_RESERVE = { TIERS = TIERS, byKey = byKey }

local function pickWeighted(list)   -- list of { value, chance }
  local x = math.random()
  for _, e in ipairs(list) do x = x - e[2]; if x <= 0 then return e[1] end end
  return list[#list][1]
end
local function rollGrade(t)
  local x = math.random()
  for g = 10, 1, -1 do
    local p = t.grades[g]
    if p then x = x - p; if x <= 0 then return g end end
  end
  return t.floor
end

-- the Mythics a pack can hold: every Mythic but The 1 Ring (that one is found once, in a pack, and engraved)
local mythics, mythCount
local function mythicPool()
  local u = U(); if not u then return {} end
  if mythics and mythCount == #u.CARDS then return mythics end
  mythics, mythCount = {}, #u.CARDS
  for _, c in ipairs(u.CARDS) do if c.tier == 7 and not (c.mythic and c.mythic.one) then mythics[#mythics + 1] = c end end
  return mythics
end

-- one pull: the card, its print and its grade. The print comes first; the card is drawn again until it can come in that
-- print (a Gilded print needs a card that can be gilded, a Raider is always Holo or better), so the odds shown are the odds
local function roll(t)
  local grade = rollGrade(t)
  if math.random() < t.mythic then
    local pool = mythicPool()
    if #pool > 0 then return pool[math.random(#pool)], 4, grade, true end
  end
  local f = pickWeighted(t.prints)
  local c
  for _ = 1, 60 do
    c = RG.ArcadePickCard and RG.ArcadePickCard()
    if not c then return nil end
    local ok = true
    if f == 5 and not (RG.ArcadeCanGild and RG.ArcadeCanGild(c)) then ok = false end
    if c.kind == 4 and f < 3 then ok = false end
    if ok then break end
    c = nil
  end
  if not c then return nil end
  return c, f, grade, false
end
RG.ArcadeReserveRoll = roll

-- buy a pack: coins go, the card goes into your collection, and its case is made. Returns true, the case, its scores,
-- the pull and the notes; or false and why
function RG.ArcadeReserveBuy(key)
  local a = store(); local t = byKey[key]
  if not (a and t) then return false, "Pick a pack." end
  if (a.coins or 0) < t.price then return false, "A " .. t.name .. " pack costs " .. t.price .. " coins. You have " .. (a.coins or 0) .. "." end
  local u = U()
  local c, f, grade, myth = roll(t)
  if not (c and f and u and u.byKey[c.key or c.name]) then return false, "No cards loaded." end
  local ckey = c.key or c.name
  local g, notes = RG.ArcadeAddPull(c, f)
  if not g then return false, "No cards loaded." end
  a.coins = a.coins - t.price
  local s = RG.ArcadeGradeRollFor(grade)
  local rec = RG.ArcadeGradeIssue(ckey, f, s, "reserve")
  if not rec then
    -- (never reached in practice: undo the copy and the coins)
    local slot = a.cards[ckey]; if slot then slot[f] = math.max(0, (slot[f] or 1) - 1) end
    a.coins = a.coins + t.price
    return false, "The guild couldn't make that case. Nothing was taken."
  end
  rec.res, rec.paid = t.key, t.price
  a.reserve = a.reserve or { bought = {} }
  a.reserve.bought = a.reserve.bought or {}
  a.reserve.bought[t.key] = (a.reserve.bought[t.key] or 0) + 1
  a.reserve.spent = (a.reserve.spent or 0) + t.price
  a.stats = a.stats or {}; a.stats.reserveSpent = (a.stats.reserveSpent or 0) + t.price
  if RG.ArcadeFirstMark then pcall(RG.ArcadeFirstMark, c.name) end
  if RG.ArcadeCollectorPack then pcall(RG.ArcadeCollectorPack, { g }, { reserve = true, size = 1, kind = "reserve" }) end
  if RG.ArcadeRefresh then pcall(RG.ArcadeRefresh, true) end
  return true, rec, s, g, notes
end

-- how many of each Reserve pack you have bought, and what you have spent there
function RG.ArcadeReserveStats()
  local a = store(); local r = a and a.reserve
  return (r and r.bought) or {}, (r and r.spent) or 0
end

-- ---------------------------------------------------------------------------
-- The odds, in words (what the screen shows) and what a pack sells back for on an average day
-- ---------------------------------------------------------------------------
local PRINT_NAME = { [2] = "Rare", [3] = "Holo", [4] = "Full art", [5] = "Gilded" }
function RG.ArcadeReserveOdds(key)
  local t = byKey[key]; if not t then return nil end
  local grades = {}
  for g = 10, 1, -1 do if t.grades[g] then grades[#grades + 1] = { g, t.grades[g] } end end
  local prints = {}
  for _, e in ipairs(t.prints) do prints[#prints + 1] = { e[1], PRINT_NAME[e[1]], e[2] * (1 - t.mythic) } end
  return { grades = grades, prints = prints, mythic = t.mythic, mythicOneIn = math.floor(1 / t.mythic + 0.5), pool = #mythicPool() }
end
local evCache = {}
-- (what its cards sell for on a day when no theme is hot or cooling: tried on a few thousand pulls, once)
function RG.ArcadeReserveWorth(key)
  if evCache[key] then return evCache[key] end
  local t = byKey[key]; local u = U()
  if not (t and u and RG.ArcadePickCard and RG.ArcadeGradeBaseValue) then return nil end
  local total, n = 0, 0
  for _ = 1, 3000 do
    local c, f, grade = roll(t)
    if c then
      local v = RG.ArcadeGradeBaseValue({ key = c.key or c.name, f = f, grade = grade })
      total = total + v; n = n + 1
    end
  end
  if n == 0 then return nil end
  evCache[key] = math.floor(total / n + 0.5)
  return evCache[key]
end

-- ---------------------------------------------------------------------------
-- The Guild market
-- ---------------------------------------------------------------------------
local M = 2147483647
local function hash(str)
  local h = 5381
  for i = 1, #str do h = (h * 33 + str:byte(i)) % M end
  h = (h * 48271) % M; h = (h * 48271) % M
  return h
end
local function noise(str) return hash(str) / M end                 -- 0 up to (not including) 1
local function utcDay(t) return math.floor((t or now()) / 86400) end
RG.ArcadeMarketDay = function() return utcDay() end
function RG.ArcadeMarketSecsLeft() local t = now(); return 86400 - (t % 86400) end

-- a card's own drift on a day: smoothed with the day before so a price moves more like a price (at most 10% either way)
local function drift(key, d)
  return ((noise(key .. "|" .. d) + noise(key .. "|" .. (d - 1))) / 2 - 0.5) * 0.2
end

-- the themes the market can talk about: each dungeon, raid and holiday set that is open, a print, a grade, the Mythics
local setMap, setMapCount
local function setsOfCard()
  local u = U(); if not u then return {}, {} end
  if setMap and setMapCount == #u.CARDS then return setMap.of, setMap.list end
  local of, list = {}, {}
  for _, s in ipairs(u.getSets and u.getSets() or {}) do
    if s.dungeon and not s.soon and #s.cards >= 3 then
      list[#list + 1] = s
      for _, c in ipairs(s.cards) do local k = c.key or c.name; of[k] = of[k] or {}; of[k][s.name] = true end
    end
  end
  setMap, setMapCount = { of = of, list = list }, #u.CARDS
  return of, list
end
local function dayOfWeek(d) return (d + 4) % 7 end   -- (0 is Sunday; the epoch's day 0 was a Thursday)

local function themesFor(d)
  local out = {}
  local of, list = setsOfCard()
  local today = date and date("%Y-%m-%d") or ""
  local dow = dayOfWeek(d)
  for _, s in ipairs(list) do
    local name = s.name
    local ok = true
    local WHY = { "A favourite with collectors", "Collectors are chasing the set", "In demand today" }
    local reason = WHY[hash(name .. "|why|" .. d) % #WHY + 1]
    if s.holiday then
      reason = "The holiday is on"
      local on = false
      for _, h in ipairs(RG.ARCADE_HOLIDAYS or {}) do
        if h[1] == name and RG.ArcadeHolidayActive then local okc, act = pcall(RG.ArcadeHolidayActive, h); on = okc and act and true or false end
      end
      ok = on
    elseif s.raid then
      reason = (dow == 2 or dow == 3) and "Raid reset" or "Raiders are after these"
      for _, x in ipairs(RG.ARCADE_DUNGEONS or {}) do
        if x[1] == name and x.raid and x.raid.opens and today ~= "" and today < x.raid.opens then ok = false end
      end
    end
    if ok then
      out[#out + 1] = { id = "set:" .. name, label = name .. " cards", reason = reason,
        match = function(card) return of[card.key or card.name] and of[card.key or card.name][name] or false end }
    end
  end
  out[#out + 1] = { id = "print:4", label = "Full art prints", reason = "Bright prints are in", match = function(card, r) return r.f == 4 and card.tier ~= 7 end }
  out[#out + 1] = { id = "print:5", label = "Gilded prints", reason = "Gold is in", match = function(card, r) return r.f == 5 end }
  out[#out + 1] = { id = "grade:10", label = "Grade 10 slabs", reason = "Gem Mint day", match = function(card, r) return r.grade >= 10 end }
  out[#out + 1] = { id = "grade:9", label = "Grade 9 slabs", reason = "Mint is wanted", match = function(card, r) return r.grade == 9 end }
  out[#out + 1] = { id = "mythic", label = "Mythic cards", reason = "Mythic hunters are buying", match = function(card) return card.tier == 7 end }
  return out
end

local dayCache = {}
-- the day's hot (4) and cooling (2) themes, each with its percentage
local function marketDay(d)
  local c = dayCache[d]; if c then return c end
  local themes = themesFor(d)
  table.sort(themes, function(x, y)
    local hx, hy = hash(x.id .. "|" .. d), hash(y.id .. "|" .. d)
    if hx ~= hy then return hx < hy end
    return x.id < y.id
  end)
  c = { hot = {}, cold = {} }
  for i, t in ipairs(themes) do
    if #c.hot < 4 then
      t.pct = 0.15 + 0.15 * noise(t.id .. "|b|" .. d); c.hot[#c.hot + 1] = t
    elseif #c.cold < 2 then
      t.pct = -(0.06 + 0.06 * noise(t.id .. "|b|" .. d))
      local COOL = { "Cooling off today", "Plenty to go round", "A quiet day" }
      t.reason = COOL[hash(t.id .. "|cool|" .. d) % #COOL + 1]
      c.cold[#c.cold + 1] = t
    else break end
  end
  dayCache[d] = c
  return c
end

-- the market's index for a case on a day: 1 is its usual price
function RG.ArcadeMarketIndex(rec, d)
  d = d or utcDay()
  local card = cardOf(rec.key)
  local m = 1 + drift(rec.key, d)
  if card then
    local day = marketDay(d)
    local hot, cold = 0, 0
    for _, t in ipairs(day.hot) do if t.match(card, rec) then hot = math.max(hot, t.pct) end end
    for _, t in ipairs(day.cold) do if t.match(card, rec) then cold = math.min(cold, t.pct) end end
    m = m + hot + cold
  end
  return math.max(0.85, math.min(1.4, m))
end

-- what the day's hot and cooling themes are, for the screen
function RG.ArcadeMarketToday(d)
  d = d or utcDay()
  local day = marketDay(d)
  local function copy(l) local o = {}; for i, t in ipairs(l) do o[i] = { label = t.label, reason = t.reason, pct = t.pct, id = t.id } end; return o end
  return { day = d, hot = copy(day.hot), cold = copy(day.cold), secsLeft = RG.ArcadeMarketSecsLeft() }
end

-- the case's price: the grade's usual price (ArcadeGrading.lua) times the day's index. (ArcadeGradeSell and the card
-- page both ask RG.ArcadeGradeValue, so what you see is what you get)
local baseValue = RG.ArcadeGradeValue
RG.ArcadeGradeBaseValue = baseValue
function RG.ArcadeGradeValue(r)
  local v, base = baseValue(r)
  local ok, idx = pcall(RG.ArcadeMarketIndex, r)
  if not ok or type(idx) ~= "number" then idx = 1 end
  return math.max(1, math.floor(v * idx + 0.5)), base
end
-- a case's price on any day (the Vault's chart and its arrow)
function RG.ArcadeGradeValueOn(r, d)
  local v = baseValue(r)
  local ok, idx = pcall(RG.ArcadeMarketIndex, r, d)
  if not ok or type(idx) ~= "number" then idx = 1 end
  return math.max(1, math.floor(v * idx + 0.5))
end
-- every case you hold: what they sell for today, and yesterday
function RG.ArcadeVaultWorth()
  local d = utcDay()
  local t0, t1, n = 0, 0, 0
  for _, r in ipairs(RG.ArcadeGradeCases()) do
    t0 = t0 + RG.ArcadeGradeValueOn(r, d); t1 = t1 + RG.ArcadeGradeValueOn(r, d - 1); n = n + 1
  end
  return t0, t1, n
end
