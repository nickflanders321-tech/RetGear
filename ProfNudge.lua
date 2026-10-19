-- Waypath+ profession reminder. Professions are no longer part of the route (they pulled you away from your quests);
-- instead, when you walk past a profession trainer and still have a free profession slot, you get one short reminder.
local ADDON, RG = ...
RG = RG or {}
local NEAR = 140            -- yards
local REPEAT_SECS = 1800    -- the same reminder is not shown again for half an hour
local told = {}

local function trainerPins(P, name)
  local out = {}
  local T = P.train or {}
  local text = (T.start and T.start[RG.RACE_LETTER]) or T.apprentice
  if not (text and RG.PROF_TRAINERS) then return out end
  local function add(nm)
    local w = RG.PROF_TRAINERS[nm]
    if w then out[#out + 1] = w end
  end
  for nm in text:gmatch("([A-Z][%a'%.]+[%a'%. ]-) %(") do add(nm) end
  for nm in text:gmatch("([A-Z][%a']+ ?[%a']*) in ") do add(nm) end
  return out
end

-- Which professions could be learned from a trainer within reach: { { name, trainer, yards }, ... }
function RG.ProfTrainersNear(radius)
  local out = {}
  if not (RG.PROFESSIONS and RG.Professions and RG.PlayerWorld and RG.ToWorld) then return out end
  local c, px, py = RG.PlayerWorld()
  if not c then return out end
  local known, primary = RG.Professions(), 0
  for name, k in pairs(known) do
    local P = RG.PROFESSIONS[name]
    if k and P and P.kind ~= "secondary" then primary = primary + 1 end
  end
  for name, P in pairs(RG.PROFESSIONS) do
    if not known[name] and (P.kind == "secondary" or primary < 2) then
      local best
      for _, w in ipairs(trainerPins(P, name)) do
        local c2, x, y = RG.ToWorld(w[1], w[2], w[3])
        if c2 == c and x then
          local d = math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
          if d <= (radius or NEAR) and (not best or d < best.d) then best = { name = name, trainer = w[4] or "", d = d, secondary = P.kind == "secondary", wp = w } end
        end
      end
      if best then out[#out + 1] = best end
    end
  end
  table.sort(out, function(a, b) return a.d < b.d end)
  return out, primary
end

local function check()
  if not (RG.db and RG.Opt and RG.Opt("profReminder")) then return end
  if RG.IsAlt and RG.IsAlt() then return end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
  if InCombatLockdown and InCombatLockdown() then return end
  local list, primary = RG.ProfTrainersNear()
  local now = time()
  local fresh = {}
  for _, e in ipairs(list) do
    if not told[e.name] or now - told[e.name] > REPEAT_SECS then fresh[#fresh + 1] = e end
  end
  if #fresh == 0 then return end
  local parts = {}
  for i = 1, math.min(4, #fresh) do
    local e = fresh[i]
    parts[#parts + 1] = e.name .. " (" .. (e.trainer:gsub(" %(.*$", "")) .. ")"
    told[e.name] = now
  end
  local slots = 2 - primary
  local msg = "Profession trainers nearby: " .. table.concat(parts, ", ") .. "."
  if slots > 0 then msg = msg .. " You have " .. slots .. " free profession slot" .. (slots > 1 and "s" or "") .. "." end
  RG.Print(msg .. " (turn these off in Settings)")
  if RG.Notify then RG.Notify("Profession trainer nearby: " .. parts[1]) end
end
RG.ProfNudgeCheck = check

if CreateFrame then
  local f = CreateFrame("Frame")
  local acc = 0
  f:SetScript("OnUpdate", function(_, dt)
    acc = acc + (dt or 0)
    if acc < 6 then return end
    acc = 0
    pcall(check)
  end)
end
