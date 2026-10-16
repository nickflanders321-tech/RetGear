-- Waypath+ smart leveling: from where you are, your level, your quest log and what you said
-- matters in setup, pick the best questing zone to work on now and list the next best ones.
-- It only chooses between route entries that already exist, so every pick has full steps.
local _, RG = ...

-- Zones next to each other (a hop is a walk, run or ride of a few minutes). Both factions.
local LINKS = {
  { "Tirisfal Glades", "Silverpine Forest" }, { "Tirisfal Glades", "Western Plaguelands" }, { "Silverpine Forest", "Hillsbrad Foothills" },
  { "Hillsbrad Foothills", "Alterac Mountains" }, { "Hillsbrad Foothills", "Arathi Highlands" }, { "Hillsbrad Foothills", "The Hinterlands" },
  { "Alterac Mountains", "Western Plaguelands" }, { "Western Plaguelands", "Eastern Plaguelands" }, { "Arathi Highlands", "Wetlands" },
  { "Wetlands", "Loch Modan" }, { "Wetlands", "Dun Morogh" }, { "Dun Morogh", "Loch Modan" }, { "Loch Modan", "Badlands" },
  { "Badlands", "Searing Gorge" }, { "Searing Gorge", "Burning Steppes" }, { "Burning Steppes", "Redridge Mountains" },
  { "Redridge Mountains", "Duskwood" }, { "Redridge Mountains", "Elwynn Forest" }, { "Redridge Mountains", "Swamp of Sorrows" },
  { "Duskwood", "Stranglethorn Vale" }, { "Duskwood", "Westfall" }, { "Duskwood", "Elwynn Forest" }, { "Elwynn Forest", "Westfall" },
  { "Swamp of Sorrows", "Blasted Lands" }, { "Duskwood", "Deadwind Pass" }, { "Deadwind Pass", "Swamp of Sorrows" },
  { "Durotar", "The Barrens" }, { "The Barrens", "Mulgore" }, { "The Barrens", "Stonetalon Mountains" }, { "The Barrens", "Ashenvale" },
  { "The Barrens", "Thousand Needles" }, { "The Barrens", "Dustwallow Marsh" }, { "Stonetalon Mountains", "Ashenvale" },
  { "Stonetalon Mountains", "Desolace" }, { "Desolace", "Feralas" }, { "Feralas", "Thousand Needles" }, { "Thousand Needles", "Tanaris" },
  { "Tanaris", "Un'Goro Crater" }, { "Un'Goro Crater", "Silithus" }, { "Ashenvale", "Felwood" }, { "Ashenvale", "Azshara" },
  { "Ashenvale", "Darkshore" }, { "Darkshore", "Teldrassil", 2 }, { "Felwood", "Winterspring" }, { "Felwood", "Moonglade" },
  { "Dustwallow Marsh", "Wetlands", 3 }, { "The Barrens", "Stranglethorn Vale", 3 }, { "Tirisfal Glades", "Durotar", 3 },
  { "Westfall", "Stranglethorn Vale", 2 },
}
local ADJ = {}
for _, l in ipairs(LINKS) do
  local a, b, w = l[1], l[2], l[3] or 1
  ADJ[a] = ADJ[a] or {}; ADJ[b] = ADJ[b] or {}
  ADJ[a][b] = w; ADJ[b][a] = w
end

-- travel cost in hops from one zone to another (small Dijkstra; unknown zones count as far)
local cache = {}
local function hops(from, to)
  if from == to then return 0 end
  if not (ADJ[from] and ADJ[to]) then return 6 end
  cache[from] = cache[from] or (function()
    local dist, todo = { [from] = 0 }, { from }
    while #todo > 0 do
      table.sort(todo, function(a, b) return dist[a] < dist[b] end)
      local z = table.remove(todo, 1)
      for n, w in pairs(ADJ[z]) do
        if not dist[n] or dist[z] + w < dist[n] then dist[n] = dist[z] + w; todo[#todo + 1] = n end
      end
    end
    return dist
  end)()
  return cache[from][to] or 6
end
RG.ZoneHops = hops

-- How you weigh things, from the setup answers: work left, fit with your level, travel.
local PROFILES = {
  fast     = { work = 3.0, fit = 2.0, travel = 0.8, log = 2.5, label = "Fastest XP" },
  balanced = { work = 2.0, fit = 2.0, travel = 1.4, log = 3.0, label = "Balanced" },
  scenic   = { work = 1.5, fit = 2.0, travel = 2.2, log = 3.0, label = "Low travel" },
}
local function profile()
  local p = PROFILES[(RG.db and RG.db.goal) or "balanced"] or PROFILES.balanced
  local t = RG.db and RG.db.travel
  if t == "walk" then return { work = p.work, fit = p.fit, travel = p.travel * 1.6, log = p.log, label = p.label } end
  return p
end

local function hereZone()
  local z = GetRealZoneText and GetRealZoneText() or ""
  if z == "" and GetZoneText then z = GetZoneText() or "" end
  return z
end

-- open steps of an entry, and how many of its quests are already in your log
local function workOf(r, logIds)
  local steps = RG.STEPS[r.zone .. "|" .. r.from] or {}
  local open, inLog = 0, 0
  for i = 1, #steps do
    if not RG.StepIsDone(r, i) then
      open = open + 1
      for _, id in ipairs(((RG.STEP_QUESTS or {})[r.zone .. "|" .. r.from] or {})[i] or {}) do if logIds[id] then inLog = inLog + 1 end end
    end
  end
  return open, #steps, inLog
end

-- Ranked options for right now: { { r = entry, score, why }, ... } best first.
function RG.SmartRank()
  local lvl = UnitLevel and UnitLevel("player") or 1
  local p, here = profile(), hereZone()
  local group = RG.db and RG.db.playStyle == "group"
  local logIds = {}
  for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do if q.id then logIds[q.id] = true end end
  local out = {}
  for _, r in ipairs(RG.ROUTE or {}) do
    local isZone, isDungeon = r.kind == "zone", r.kind == "dungeon"
    if (isZone or (isDungeon and group)) and lvl >= r.from - 1 and lvl <= r.to then
      local open, total, inLog = workOf(r, logIds)
      if open > 0 or isDungeon then
        local mid = (r.from + r.to) / 2
        local fit = 1 - math.min(1, math.abs(lvl - mid) / math.max(4, (r.to - r.from)))
        if lvl < r.from then fit = fit - 0.3 end
        local work = total > 0 and (open / total) or 0.5
        local d = hops(here, r.zone)
        if RG.db and RG.db.travel ~= "walk" and r.fp and RG.KnowsFP and RG.KnowsFP(r.fp) then d = math.min(d, 1) end
        local score = p.work * work + p.fit * fit + p.log * math.min(1, inLog / 3) - p.travel * d * 0.35
        if isDungeon then score = score - 0.5 end
        local why = {}
        if inLog > 0 then why[#why + 1] = inLog .. " quest" .. (inLog > 1 and "s" or "") .. " already in your log" end
        if d == 0 then why[#why + 1] = "you're here" elseif d <= 1 then why[#why + 1] = "next door" elseif d >= 6 then why[#why + 1] = "a long way from here" else why[#why + 1] = d .. " zones away" end
        why[#why + 1] = open .. " of " .. total .. " steps left"
        out[#out + 1] = { r = r, score = score, why = table.concat(why, ", "), hops = d }
      end
    end
  end
  table.sort(out, function(a, b)
    if math.abs(a.score - b.score) > 0.001 then return a.score > b.score end
    return (a.r._i or 0) < (b.r._i or 0)
  end)
  return out
end

-- The pick for the tracker; nil when smart mode is off or nothing fits (the guided route then decides).
function RG.SmartEntry()
  if not RG.db or RG.db.smart == false or RG.db.routeStyle == "guided" then return nil end
  local list = RG.SmartRank()
  -- stay put unless something is clearly better: no flip-flopping between zones
  local keep = RG.db.smartKey
  if keep then
    for _, o in ipairs(list) do
      if o.r.zone .. "|" .. o.r.from == keep and list[1] and list[1].score - o.score < 0.6 then return o.r end
    end
  end
  local best = list[1]
  if not best then RG.db.smartKey = nil return nil end
  RG.db.smartKey = best.r.zone .. "|" .. best.r.from
  return best.r
end

-- a line of other good options for the tracker
function RG.SmartAlternatives(skip)
  local list, out = RG.SmartRank(), {}
  for _, o in ipairs(list) do
    if o.r ~= skip and #out < 2 then out[#out + 1] = o end
  end
  return out
end

function RG.SmartToggle(on)
  RG.db.smart = on
  RG.db.routeStyle = on and "smart" or "guided"
  RG.db.smartKey = nil
  RG.Print((on and "Smart route on: the tracker picks the best zone for where you are and your level." or "Smart route off: the tracker follows the route in order.") )
  if RG.RefreshTracker then RG.RefreshTracker() end
  if RG.RefreshUI then RG.RefreshUI() end
end
