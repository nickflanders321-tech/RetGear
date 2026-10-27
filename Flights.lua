-- Waypath+ flight paths: every Classic flight master for your faction, which of them
-- you have learned, how far each is, and one click to be guided there (map pin + arrow).
-- Data: FlightPaths.lua (generated). /wp fp  = arrow to the nearest flight path you haven't learned.
local _, RG = ...

local function myFaction()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return f == "Horde" and "H" or (f == "Alliance" and "A" or nil)
end

-- continent id + world x/y of a map position (percent), or nil
local function world(map, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos) then return nil end
  local v = CreateVector2D and CreateVector2D(x / 100, y / 100) or { x = x / 100, y = y / 100 }
  local ok, cont, wp = pcall(C_Map.GetWorldPosFromMapPos, map, v)
  if not ok or not wp then return nil end
  return cont, wp.x, wp.y
end
local function me()
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  if not pos or (RG.IsSecret and (RG.IsSecret(pos.x) or RG.IsSecret(pos.y))) then return nil end
  return world(map, pos.x * 100, pos.y * 100)
end

-- { node, zone, map, x, y, faction, npc, npcName, known = true/false/nil, dist = yards or nil, wp = waypoint }
function RG.FlightList(all)
  local out = {}
  local fac = myFaction()
  local pc, px, py = me()
  for _, f in ipairs(RG.FLIGHTS or {}) do
    if all or not fac or f[6] == "N" or f[6] == fac then
      local e = { node = f[1], zone = f[2], map = f[3], x = f[4], y = f[5], faction = f[6], npc = f[8],
                  wp = { f[3], f[4], f[5], f[1] .. " flight master" } }
      e.known = RG.KnowsFP(f[1])
      if pc then
        local c, x, y = world(f[3], f[4], f[5])
        if c == pc and x then e.dist = math.sqrt((x - px) ^ 2 + (y - py) ^ 2) end
      end
      out[#out + 1] = e
    end
  end
  table.sort(out, function(a, b)
    if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
    if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
    if a.zone ~= b.zone then return a.zone < b.zone end
    return a.node < b.node
  end)
  return out
end

function RG.NearestFlight(unlearnedOnly)
  for _, e in ipairs(RG.FlightList()) do
    if not unlearnedOnly or e.known ~= true then return e end
  end
end

function RG.FlightGo(e)
  if not e then RG.Print("No flight path to point at.") return end
  RG.Follow(e.wp)
end

RG.FlightSlash = function()
  local e = RG.NearestFlight(true)
  if not e then RG.Print("You know every flight path in this list.") return end
  RG.Print(string.format("Nearest flight path to learn: %s (%s)%s", e.node, e.zone, e.dist and string.format(", %d yd", e.dist) or ""))
  RG.FlightGo(e)
end

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  cmd = cmd and cmd:lower()
  if cmd == "fp" or cmd == "flight" or cmd == "flights" then
    if (msg or ""):lower():find("list", 1, true) and RG.ShowTab then RG.ShowTab("flights") return end
    RG.FlightSlash() return
  end
  return base(msg)
end

-- ---------------------------------------------------------------------------
-- Flight path reminders: walking past a flight master you haven't learned yet is the cheapest
-- time to grab it (it saves a long run later). The tracker shows the nearest one in range, the
-- Route tab names a zone's flight paths, and a chat line says so once per flight path.
-- ---------------------------------------------------------------------------
table.insert(RG.OPTIONS, { key = "fpNudge", label = "Remind me to grab flight paths I walk past", default = true })
local NEAR_YARDS, NUDGE_YARDS = 350, 160

-- the flight paths of your faction (and neutral ones) in a zone: { "Crossroads", ... }
function RG.ZoneFlights(zone)
  local out, fac = {}, myFaction()
  zone = (zone or ""):lower()   -- "Shen'dralas" / "Shen'Dralas"
  for _, f in ipairs(RG.FLIGHTS or {}) do
    if f[2]:lower() == zone and (not fac or f[6] == "N" or f[6] == fac) then out[#out + 1] = f[1] end
  end
  return out
end

-- the nearest flight path you haven't learned (or may not have: no data yet) within range, or nil
local near, nearAt = nil, -10
function RG.NearbyFlight()
  if not RG.Opt("fpNudge") then return nil end
  local now = GetTime and GetTime() or 0
  if now - nearAt < 2 then return near end
  nearAt, near = now, nil
  if UnitOnTaxi and UnitOnTaxi("player") then return nil end
  if IsInInstance then local inst = IsInInstance(); if inst then return nil end end
  for _, e in ipairs(RG.FlightList()) do
    if not e.dist or e.dist > NEAR_YARDS then break end      -- sorted nearest first
    if e.known ~= true then near = e break end
  end
  return near
end

-- once per flight path and character: a chat line when you come close to one you don't have
local acc = 0
local nf = CreateFrame("Frame")
nf:SetScript("OnUpdate", function(_, dt)
  acc = acc + (dt or 0)
  if acc < 3 then return end
  acc = 0
  if not RG.db or (RG.CardsOnly and RG.CardsOnly()) then return end
  if InCombatLockdown and InCombatLockdown() then return end
  local e = RG.NearbyFlight()
  if not (e and e.dist and e.dist <= NUDGE_YARDS) then return end
  RG.db.fpNudged = RG.db.fpNudged or {}
  if RG.db.fpNudged[e.node] then return end
  RG.db.fpNudged[e.node] = true
  local who = e.npc and (" from " .. e.npc) or ""
  RG.Print(RG.COLORS.GOLD .. "Flight path nearby:|r " .. e.node .. " (" .. e.zone .. "), " .. math.floor(e.dist) .. " yd. Learn it" .. who ..
    " now and you can fly back here later." .. (e.known == nil and " (Already have it? Talk to any flight master once and Waypath+ remembers which ones you know.)" or "") .. " /wp fp points the arrow.")
  if RG.RefreshTracker then RG.RefreshTracker() end
end)

-- Nearest fishing pool/school on this zone's map (spots are the centre of each pool cluster).
function RG.NearestPool()
  local FL = RG.FISH_LOOT
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  if not (FL and FL.pools and map and pos) or (RG.IsSecret and (RG.IsSecret(pos.x) or RG.IsSecret(pos.y))) then return nil end
  local best, bd
  for _, p in ipairs(FL.pools) do
    for _, s in ipairs(p.spots or {}) do
      if s[1] == map then
        local d = math.sqrt((s[2] - pos.x * 100) ^ 2 + (s[3] - pos.y * 100) ^ 2)
        if not bd or d < bd then bd, best = d, { p.name, s } end
      end
    end
  end
  if not best then return nil end
  local s = best[2]
  return { name = best[1], wp = { s[1], s[2], s[3], best[1] }, where = s[4], pct = bd }
end

local base2 = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  cmd = cmd and cmd:lower()
  if cmd == "pool" or cmd == "pools" then
    local p = RG.NearestPool()
    if not p then RG.Print("No fishing pool is known on this map.") return end
    RG.Print("Nearest pool: " .. p.name .. " (" .. p.where .. ")")
    RG.Follow(p.wp) return
  end
  return base2(msg)
end
