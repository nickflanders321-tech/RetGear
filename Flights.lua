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
