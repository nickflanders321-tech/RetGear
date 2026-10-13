-- RetGear ore alerts: tells you when you walk near a spot where a vein you can
-- mine (and that still gives Mining skill) can spawn. The game doesn't let addons
-- read the minimap's ore dots, so this uses WoW Forever's known vein spawn points
-- (NodeData.lua): a spot may be empty if someone mined it. Find Minerals shows
-- whether it's up.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
table.insert(RG.OPTIONS, { key = "oreAlert", label = "Alert me near ore I can mine (still gives Mining skill)", default = true })
table.insert(RG.OPTIONS, { key = "oreAlertAll", label = "Ore alerts for every vein I can mine, even ones that no longer give skill", default = false })

local RANGE = 90       -- yards: close enough to see it on the minimap and walk over
local SPOT_COOLDOWN = 600
local GLOBAL_COOLDOWN = 20

-- Parse a map's spots once: { {x, y, mask}, ... }
local parsed = {}
local function spotsFor(map)
  if parsed[map] ~= nil then return parsed[map] end
  local s = RG.NODE_SPOTS and RG.NODE_SPOTS[map]
  if not s then parsed[map] = false; return false end
  local out = {}
  for x, y, m in s:gmatch("([%d.]+),([%d.]+),(%d+)") do out[#out + 1] = { tonumber(x), tonumber(y), tonumber(m) } end
  parsed[map] = out
  return out
end

-- Map size in yards (for distances), cached per map.
local sizes = {}
local function mapSize(map)
  if sizes[map] ~= nil then return sizes[map] end
  sizes[map] = false
  if not (C_Map and C_Map.GetWorldPosFromMapPos) then return false end
  local ok1, _, a = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D and CreateVector2D(0, 0) or { x = 0, y = 0 })
  local ok2, _, b = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D and CreateVector2D(1, 1) or { x = 1, y = 1 })
  -- world x runs north-south and world y east-west, so map width comes from y and height from x
  if ok1 and ok2 and a and b then sizes[map] = { math.abs(b.y - a.y), math.abs(b.x - a.x) } end
  return sizes[map]
end

-- Which ore types are worth an alert at your skill: you can mine it, and (unless
-- "every vein" is on) it still gives skill (grey at 100 above its requirement).
local function wanted(skill)
  local mask, names = 0, {}
  for i, o in ipairs(RG.NODE_ORES or {}) do
    if skill >= o[2] and (RG.Opt("oreAlertAll") or skill < o[2] + 100) then mask = mask + 2 ^ (i - 1); names[i] = o[1] end
  end
  return mask, names
end
local function band(a, b)
  local r, bit = 0, 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then r = r + bit end
    a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
  end
  return r
end

local function direction(dx, dy)
  -- dx east+, dy south+ (map percent axes); facing: radians, 0 = north, counter-clockwise
  local facing = GetPlayerFacing and GetPlayerFacing()
  if not facing or (RG.IsSecret and RG.IsSecret(facing)) then
    local a = math.deg(math.atan2(dx, -dy)) % 360
    local dirs = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }
    return dirs[math.floor((a + 22.5) / 45) % 8 + 1]
  end
  local bearing = math.atan2(-dx, -dy) -- counter-clockwise from north
  local rel = math.deg((bearing - facing) % (2 * math.pi))
  if rel < 30 or rel > 330 then return "ahead" elseif rel < 150 then return "to your left" elseif rel < 210 then return "behind you" else return "to your right" end
end

local lastSpot, lastAlert, nearest = {}, 0, nil
RG.OreNearby = function() return nearest end

local function check()
  nearest = nil
  if not RG.Opt("oreAlert") or (RG.IsAlt and RG.IsAlt()) then return end
  if (InCombatLockdown and InCombatLockdown()) or (IsInInstance and IsInInstance()) then return end
  local skill = RG.Skill and RG.Skill("Mining")
  if not skill then return end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map then return end
  local spots = spotsFor(map)
  if not spots then return end
  local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  local size = mapSize(map)
  if not pos or not size then return end
  local px, py = pos.x * 100, pos.y * 100
  if RG.IsSecret and (RG.IsSecret(px) or RG.IsSecret(py)) then return end
  local mask, names = wanted(skill)
  if mask == 0 then return end
  local best, bestD
  for _, s in ipairs(spots) do
    if band(s[3], mask) > 0 then
      local dx, dy = (s[1] - px) / 100 * size[1], (s[2] - py) / 100 * size[2]
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= RANGE and (not bestD or d < bestD) then best, bestD = s, d end
    end
  end
  if not best then return end
  -- name the best ore that can spawn there
  local ore
  for i = #RG.NODE_ORES, 1, -1 do if names[i] and band(best[3], 2 ^ (i - 1)) > 0 then ore = names[i]; break end end
  local key = map .. ":" .. best[1] .. ":" .. best[2]
  nearest = { ore = ore, dist = bestD, wp = { map, best[1], best[2], ore or "Ore" }, dir = direction((best[1] - px) * size[1], (best[2] - py) * size[2]) }
  local now = GetTime()
  if lastSpot[key] and now - lastSpot[key] < SPOT_COOLDOWN then return end
  if now - lastAlert < GLOBAL_COOLDOWN then return end
  lastSpot[key], lastAlert = now, now
  local msg = string.format("%s spot %d yd %s: check your minimap", ore or "Ore", bestD, nearest.dir)
  if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, 0.95, 0.75, 0.3) end
  if RG.Opt("sounds") and PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.MAP_PING or 3175) end
  if RG.QueueTracker then RG.QueueTracker() end
end

if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(2, function() if RG.db then pcall(check) end end)
end

-- A tracker reminder while you're near one (click: pin it and follow the arrow).
local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  local n = nearest
  if n and RG.Opt("oreAlert") then
    local wp = n.wp
    out[#out + 1] = { "|TInterface\\Icons\\Trade_Mining:14:14|t " .. GOLD .. (n.ore or "Ore") .. "|r" .. GREY .. string.format(" spot %d yd %s (click to pin)|r", n.dist, n.dir), function() RG.PinWaypoint(wp) end, 3 }
  end
  return out
end

RG.OreCheck = function() pcall(check) end
