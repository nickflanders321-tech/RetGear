-- Waypath+ ore and herb alerts: tells you when you walk near a spot where a vein or herb you can
-- mine (and that still gives Mining skill) can spawn. The game doesn't let addons
-- read the minimap's ore dots, so this uses WoW Forever's known vein spawn points
-- (NodeData.lua): a spot may be empty if someone mined it. Find Minerals shows
-- whether it's up.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
table.insert(RG.OPTIONS, { key = "oreAlert", label = "Alert me near ore I can mine (still gives Mining skill)", default = true })
table.insert(RG.OPTIONS, { key = "oreAlertAll", label = "Ore and herb alerts for every node I can gather, even ones that no longer give skill", default = false })
table.insert(RG.OPTIONS, { key = "herbAlert", label = "Alert me near herbs I can pick (still gives Herbalism skill)", default = true })

-- Gathering kinds: which profession, which node list and which option turns it on.
-- Herbs in WoW Forever also need character level = the herb's skill / 5.
local KINDS = {
  { key = "ore",  prof = "Mining",    opt = "oreAlert",  types = function() return RG.NODE_ORES end,  spots = function() return RG.NODE_SPOTS end,
    icon = "Interface\\Icons\\Trade_Mining", word = "spot" },
  { key = "herb", prof = "Herbalism", opt = "herbAlert", types = function() return RG.HERB_TYPES end, spots = function() return RG.HERB_SPOTS end,
    icon = "Interface\\Icons\\Trade_Herbalism", word = "patch", levelGate = true },
}

local RANGE = 90       -- yards: close enough to see it on the minimap and walk over
local SPOT_COOLDOWN = 600
local GLOBAL_COOLDOWN = 20

-- Parse a map's spots once: { {x, y, mask}, ... }
local parsed = {}
local function spotsFor(kind, map)
  local key = kind.key .. map
  if parsed[key] ~= nil then return parsed[key] end
  local all = kind.spots()
  local s = all and all[map]
  if not s then parsed[key] = false; return false end
  local out = {}
  for x, y, m in s:gmatch("([%d.]+),([%d.]+),(%d+)") do out[#out + 1] = { tonumber(x), tonumber(y), tonumber(m) } end
  parsed[key] = out
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
local function wanted(kind, skill)
  local mask, names = 0, {}
  local lvl = UnitLevel("player") or 1
  for i, o in ipairs(kind.types() or {}) do
    local levelOk = not kind.levelGate or lvl * 5 >= o[2] or o[2] <= 1
    if skill >= o[2] and levelOk and (RG.Opt("oreAlertAll") or skill < o[2] + 100) then mask = mask + 2 ^ (i - 1); names[i] = o[1] end
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
  if RG.IsAlt and RG.IsAlt() then return end
  if (InCombatLockdown and InCombatLockdown()) or (IsInInstance and IsInInstance()) then return end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map then return end
  local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  local size = mapSize(map)
  if not pos or not size then return end
  local px, py = pos.x * 100, pos.y * 100
  if RG.IsSecret and (RG.IsSecret(px) or RG.IsSecret(py)) then return end
  local best, bestD, bestKind, bestNames
  for _, kind in ipairs(KINDS) do
    local skill = RG.Opt(kind.opt) and RG.Skill and RG.Skill(kind.prof)
    local spots = skill and spotsFor(kind, map)
    if spots then
      local mask, names = wanted(kind, skill)
      if mask > 0 then
        for _, s in ipairs(spots) do
          if band(s[3], mask) > 0 then
            local dx, dy = (s[1] - px) / 100 * size[1], (s[2] - py) / 100 * size[2]
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= RANGE and (not bestD or d < bestD) then best, bestD, bestKind, bestNames = s, d, kind, names end
          end
        end
      end
    end
  end
  if not best then return end
  -- name the best node type that can spawn there
  local ore
  local types = bestKind.types()
  for i = #types, 1, -1 do if bestNames[i] and band(best[3], 2 ^ (i - 1)) > 0 then ore = bestNames[i]; break end end
  local key = bestKind.key .. map .. ":" .. best[1] .. ":" .. best[2]
  nearest = { ore = ore, dist = bestD, kind = bestKind, wp = { map, best[1], best[2], ore or "Node" }, dir = direction((best[1] - px) * size[1], (best[2] - py) * size[2]) }
  local now = GetTime()
  if lastSpot[key] and now - lastSpot[key] < SPOT_COOLDOWN then return end
  if now - lastAlert < GLOBAL_COOLDOWN then return end
  lastSpot[key], lastAlert = now, now
  local msg = string.format("%s %s %d yd %s: check your minimap", ore or "Node", bestKind.word, bestD, nearest.dir)
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
  if n then
    local wp = n.wp
    out[#out + 1] = { "|T" .. n.kind.icon .. ":14:14|t " .. GOLD .. (n.ore or "Node") .. "|r" .. GREY .. string.format(" %s %d yd %s (click to pin)|r", n.kind.word, n.dist, n.dir), function() RG.PinWaypoint(wp) end, 3 }
  end
  return out
end

RG.OreCheck = function() pcall(check) end

-- "Ore: Tin, Silver  ·  Herbs: Briarthorn" for a zone: what you can gather there
-- that still gives you skill (from the spawn data's best zones).
function RG.GatherHere(zone)
  local parts = {}
  for _, kind in ipairs(KINDS) do
    local skill = RG.Skill and RG.Skill(kind.prof)
    local zones = kind.key == "ore" and RG.ORE_ZONES or RG.HERB_ZONES
    if skill and zones then
      local list = {}
      for _, o in ipairs(kind.types() or {}) do
        local z = zones[o[1]]
        if z and z:find(zone, 1, true) and skill >= o[2] - 25 and skill < o[2] + 100 then
          list[#list + 1] = (o[1]:gsub(" Vein$", ""):gsub(" Deposit$", ""):gsub(" Mineral$", ""))
        end
      end
      if #list > 0 then parts[#parts + 1] = (kind.key == "ore" and "Ore: " or "Herbs: ") .. table.concat(list, ", ") end
    end
  end
  return #parts > 0 and table.concat(parts, "  ·  ") or nil
end
