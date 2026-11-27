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
  local z = RG.ZoneName()
  return z
end

-- Open steps of an entry that you can actually work on now, and how many of its quests are already in your log.
-- A step only counts when one of its quests is in your log or can be picked up right now: not grey, not waiting on
-- an earlier quest, a level, a profession or reputation. (Hand-written steps without a quest list always count.)
local function workOf(r, logIds)
  local key = r.zone .. "|" .. r.from
  local steps = RG.STEPS[key] or {}
  local sq = (RG.STEP_QUESTS or {})[key] or {}
  local isDone = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or function() return false end
  local open, inLog = 0, 0
  for i = 1, #steps do
    if not RG.StepIsDone(r, i) then
      local ids = sq[i]
      local doable = not ids or #ids == 0
      for _, id in ipairs(ids or {}) do
        if logIds[id] then inLog = inLog + 1; doable = true
        elseif not doable and not isDone(id) then
          local d = RG.QDATA and RG.QDATA[id]
          if d and not d.rep and (not RG.QuestForMe or RG.QuestForMe(d)) and not (RG.HideProfQuest and RG.HideProfQuest(id)) and not (RG.QuestIsGrey and RG.QuestIsGrey(d.l) and not (RG.GreyButNeeded and RG.GreyButNeeded(id, isDone))) and not (RG.QuestBlocked and RG.QuestBlocked(id, d, isDone, function(q) return logIds[q] or false end, true)) then doable = true end
        end
      end
      if doable then open = open + 1 end
    end
  end
  return open, #steps, inLog
end

RG.SmartWorkOf = workOf   -- (the harness's bot asks it why a zone still counts)
-- Ranked options for right now: { { r = entry, score, why }, ... } best first.
local rankCache, rankT
function RG.SmartRank()
  -- (asked twice per tracker refresh: within one frame the answer is the same; callers only read it)
  local now = GetTime and GetTime()
  if rankCache and now and rankT == now then return rankCache end
  rankCache, rankT = RG.SmartRankNow(), now
  return rankCache
end
function RG.SmartRankNow()
  local lvl = UnitLevel and UnitLevel("player") or 1
  local p, here = profile(), hereZone()
  local group = RG.db and RG.db.playStyle == "group"
  local logIds = {}
  for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do if q.id then logIds[q.id] = true end end
  local out = {}
  for _, r in ipairs(RG.ROUTE or {}) do
    local isZone, isDungeon = r.kind == "zone", r.kind == "dungeon"
    if (isZone or (isDungeon and group and RG.DungeonQuestsOn())) and lvl >= r.from - 1 and lvl <= r.to then
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
        why[#why + 1] = open .. " step" .. (open == 1 and "" or "s") .. " you can do now"
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

-- Does the tracker have something to do in this entry now: a quest line of an open step that isn't waiting ("later")
-- and isn't in another zone? The ranking above counts work more loosely (any quest of a step in your log), so a zone
-- could rank as having work while the tracker could only show a dead end there (in Felwood, Salve via Hunting that
-- Maybess Riverbreeze didn't offer): the pick asks this too. (Asked of a few entries per refresh; kept for the frame.)
local nowMemo, nowT = {}, nil
local function workNow(r)
  if not (RG.StepQuestLines and RG.STEPS) then return true end
  local t = GetTime and GetTime()
  if t ~= nowT then nowMemo, nowT = {}, t end
  local key = r.zone .. "|" .. r.from
  if nowMemo[key] ~= nil then return nowMemo[key] end
  local mine = RG.MyQuests and RG.MyQuests()
  local yes = false
  for i = 1, #(RG.STEPS[key] or {}) do
    if not RG.StepIsDone(r, i) then
      local ql = RG.StepQuestLines(r, i, mine)
      if not ql then yes = true break end   -- (a hand-written step: it always counts)
      for _, l in ipairs(ql) do if l.act ~= "later" and not l.away then yes = true break end end
      if yes then break end
    end
  end
  nowMemo[key] = yes
  return yes
end
RG.SmartWorkNow = workNow

-- The pick for the tracker; nil when the smart zone order is off or nothing fits (the route's order then decides).
local STAY = 1.5   -- how much better another zone must score before you're sent away from the one you're working on
function RG.SmartEntry()
  if not RG.db or RG.db.smart == false then return nil end
  local list = RG.SmartRank()
  -- finish the zone you're working on while it still has something you can do now, unless another zone is much
  -- better for you (a wide zone like Stranglethorn mustn't hold you while the zones of your level go grey): no
  -- flip-flopping between zones
  local keep = RG.db.smartKey
  if keep then
    for _, o in ipairs(list) do
      if o.r.zone .. "|" .. o.r.from == keep and list[1] and list[1].score - o.score < STAY and workNow(o.r) then return o.r end
    end
  end
  -- the best zone where the tracker has something to do now (the best by score if none of the first few has)
  local best
  for k, o in ipairs(list) do
    if k > 5 then break end
    if workNow(o.r) then best = o break end
  end
  best = best or list[1]
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

-- ---------------------------------------------------------------------------------------------------------------------
-- What the tracker follows (the menu at its top, Settings > Tracker, /wp route):
--   "guide"  the ordered guide: the route, zone by zone (RG.db.smart: the smart zone order picks the zone)
--   "zone"   zone quests: one zone's route, the zone you're in or one you picked (RG.db.zonePick, until you log out)
--   "log"    my quest log: only the quests you have
-- With the leveling route switched off (an old setting), it's your quest log. The tracker can also show your
-- professions or preobtain a dungeon's quests instead (RG.db.trackerView = "prof" / "dungeon", DungeonPrep.lua);
-- picking one of the three goes back to it.
-- ---------------------------------------------------------------------------------------------------------------------
function RG.RouteMode()
  local db = RG.db
  if not db then return "log" end
  local s = db.routeStyle
  if s == "smart" or s == "guided" then   -- (saved by an older version: Smart and Guided are the ordered guide now)
    if s == "guided" then db.smart = false end
    db.routeStyle, s = "guide", "guide"
  end
  if not (RG.Opt and RG.Opt("routeGuide")) then return "log" end
  if s == "zone" or s == "log" then return s end
  return "guide"
end
function RG.TrackerView()
  local v = RG.db and RG.db.trackerView
  if v == "prof" or v == "dungeon" then return v end
  return RG.RouteMode()
end
local MODE_NAME = { guide = "Ordered guide", zone = "Zone quests", log = "My quest log", prof = "Professions", dungeon = "Dungeon quests" }
function RG.ModeName(m) return MODE_NAME[m or RG.TrackerView()] or "Waypath+" end

local function changed()
  if RG.ForgetNextStep then RG.ForgetNextStep() end
  if RG.MarkObjectiveDirty then RG.MarkObjectiveDirty() end
  if RG.RefreshTracker then RG.RefreshTracker() end
  if RG.RefreshStepView then pcall(RG.RefreshStepView) end
  if RG.RefreshUI then RG.RefreshUI() end
end
RG.RouteChanged = changed

function RG.SetRouteMode(mode, quiet)
  if mode ~= "zone" and mode ~= "log" then mode = "guide" end
  RG.db.routeStyle = mode
  RG.db.smartKey, RG.db.trackerView = nil, nil
  -- the guide and zone quests need the leveling route: picking one turns it on
  if mode ~= "log" and not RG.Opt("routeGuide") then RG.db.routeGuide = true end
  if not quiet then
    RG.Print(({ guide = "Ordered guide: the tracker follows the route, zone by zone" .. (RG.db.smart == false and ", in its order." or " (the smart zone order picks the zone that suits you best)."),
      zone = "Zone quests: the tracker follows one zone's route (" .. (RG.FollowZone() or "the zone you're in") .. "). Pick another zone at the top of the tracker.",
      log = "My quest log: the tracker follows only the quests you have." })[mode])
  end
  changed()
end
-- (older name) "smart" and "guided" are the ordered guide with the smart zone order on or off
function RG.SetRouteStyle(style, quiet)
  if style == "smart" or style == "guided" then RG.db.smart = style == "smart"; style = "guide" end
  RG.SetRouteMode(style, quiet)
end
function RG.SetTrackerView(view)
  if view == "prof" or view == "dungeon" then
    RG.db.trackerView = view
    if RG.PrepForget then RG.PrepForget() end
    changed()
  else RG.SetRouteMode(view, true) end
end

-- The smart zone order (the ordered guide picks the zone that suits your level, where you are and your quest log)
function RG.SmartToggle(on, quiet)
  RG.db.smart = on and true or false
  RG.db.smartKey = nil
  if not quiet then RG.Print(on and "Smart zone order on: the guide picks the zone that suits you best." or "Smart zone order off: the guide follows the route in its order.") end
  changed()
end

-- Zone quests: the zone it follows. The one you picked (until you log out), else the one you're in. Second value:
-- true when you picked it.
function RG.FollowZone()
  local p = RG.db and RG.db.zonePick
  if p and p ~= "" then return p, true end
  return RG.ZoneName and RG.ZoneName() or nil, false
end
function RG.SetZonePick(zone)
  if zone == "" then zone = nil end
  RG.db.zonePick = zone
  if zone and RG.RouteMode() ~= "zone" then RG.SetRouteMode("zone", true) else changed() end
end
do   -- a picked zone lasts until you log out (a /reload keeps it)
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function(_, _, isLogin) if isLogin and RG.db then RG.db.zonePick = nil end end)
end

-- Dungeon quests: ones you can only finish inside a dungeon (the quests our data files under a dungeon, and any your
-- quest log files under one). Settings, or the menu at the top of the tracker, can leave them out.
function RG.DungeonQuestsOn() return not RG.Opt or RG.Opt("dungeonQuests") ~= false end
local dqIds, dqZones
function RG.IsDungeonQuest(id, zone)
  if not dqIds then
    dqIds, dqZones = {}, {}
    -- (the quest log files a dungeon's quests under the dungeon: these names, plus the route's own)
    for _, name in ipairs({ "Ragefire Chasm", "Wailing Caverns", "The Deadmines", "Deadmines", "Shadowfang Keep", "The Stockade",
      "Stormwind Stockade", "Blackfathom Deeps", "Gnomeregan", "Razorfen Kraul", "Scarlet Monastery", "Razorfen Downs", "Uldaman",
      "Zul'Farrak", "Maraudon", "The Temple of Atal'Hakkar", "Sunken Temple", "Blackrock Depths", "Blackrock Spire",
      "Lower Blackrock Spire", "Upper Blackrock Spire", "Stratholme", "Scholomance", "Dire Maul", "Molten Core", "Onyxia's Lair",
      "Blackwing Lair", "Zul'Gurub", "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj", "Ahn'Qiraj", "Naxxramas" }) do dqZones[name] = true end
    for name, dq in pairs(RG.DUNGEON_QUESTS or {}) do
      dqZones[name] = true
      for _, q in ipairs(dq.quests or {}) do if q.id then dqIds[q.id] = true end end
    end
    for _, r in ipairs(RG.ROUTE or {}) do if r.kind == "dungeon" then dqZones[r.zone] = true end end
  end
  return (id and dqIds[id]) or (zone and dqZones[zone]) or false
end
-- left out: true for a dungeon quest while they're left out
function RG.DungeonQuestHidden(id, zone)
  return not RG.DungeonQuestsOn() and RG.IsDungeonQuest(id, zone) and true or false
end
