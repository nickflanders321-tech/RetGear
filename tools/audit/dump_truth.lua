-- Loads Waypath+'s hand-written data files the way the game does (no client
-- needed) and prints them as JSON, so tools/audit/crosscheck.py can compare
-- them with what the generators read and with WoW Forever's data.
-- Usage: lua5.1 tools/audit/dump_truth.lua <addon dir> > truth.json
local root = (arg[1] or "."):gsub("/$", "")

-- A stand-in for the game client: any missing global is a harmless dummy that
-- can be called, indexed and assigned, so files with UI code still load.
local dummy
dummy = setmetatable({}, {
  __index = function() return dummy end,
  __newindex = function() end,
  __call = function() return dummy end,
  __concat = function() return "" end,
})
local env = setmetatable({}, { __index = function(_, k) local v = _G[k]; if v ~= nil then return v end return dummy end })
env._G = env

local RG = { OPTIONS = {}, COLORS = setmetatable({}, { __index = function() return "" end }) }
local function load(f, optional)
  local chunk, err = loadfile(root .. "/" .. f)
  if not chunk then if optional then return end error(err) end
  setfenv(chunk, env)
  local ok, e = pcall(chunk, "Waypath", RG)
  if not ok and not optional then io.stderr:write("could not load " .. f .. ": " .. tostring(e) .. "\n") end
end
load("Data.lua")
for _, f in ipairs({ "Paladin", "Warrior", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid" }) do load("Classes/" .. f .. ".lua") end
load("Classes/Specs.lua", true)
for _, f in ipairs({ "Undead", "Durotar", "Tauren", "Skyborne" }) do load("Races/" .. f .. ".lua") end
load("Routes/Horde.lua")
for _, f in ipairs({ "Mining", "Blacksmithing", "Herbalism", "Skinning", "Alchemy", "Enchanting", "Engineering", "Leatherworking", "Tailoring", "FirstAid", "Cooking", "Fishing" }) do load("Professions/" .. f .. ".lua") end
-- tables that live next to UI code
load("Mail.lua", true); load("Camp.lua", true); load("SecondSpec.lua", true)

local function enc(v, seen)
  local t = type(v)
  if t == "string" then return (string.format("%q", v):gsub("\\\n", "\\n")) end
  if t == "number" or t == "boolean" then return tostring(v) end
  if t ~= "table" or v == dummy then return "null" end
  seen = seen or {}; if seen[v] then return "null" end; seen[v] = true
  local n, isArr = #v, #v > 0
  if isArr then for k in pairs(v) do if type(k) ~= "number" then isArr = false break end end end
  local out = {}
  if isArr then for i = 1, n do out[#out + 1] = enc(v[i], seen) end; seen[v] = nil; return "[" .. table.concat(out, ",") .. "]" end
  for k, x in pairs(v) do if type(x) ~= "function" then out[#out + 1] = string.format("%q", tostring(k)) .. ":" .. enc(x, seen) end end
  seen[v] = nil
  return "{" .. table.concat(out, ",") .. "}"
end
io.write(enc({ classes = RG.CLASSES, races = RG.RACES, routes = RG.ROUTES, profs = RG.PROFESSIONS,
  specs = RG.SPECS, spec_hand = RG.SPEC_HAND, mail = RG.MAIL_QUESTS, camp = RG.CAMP_PLAN }))
