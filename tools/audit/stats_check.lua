-- Runs Waypath+'s own stat reader and scorer (Core.lua: RG.ParseItemStats, RG.ScoreStats) over the cases
-- tools/audit/stats.py writes, and prints the answers for it to check. No game client needed.
-- Usage: lua5.1 tools/audit/stats_check.lua <addon dir> <cases.lua> > answers.txt
local root, casesFile = (arg[1] or "."):gsub("/$", ""), arg[2]

-- a stand-in for the game client: any missing global is a harmless dummy
local dummy
dummy = setmetatable({}, {
  __index = function() return dummy end, __newindex = function() end,
  __call = function() return dummy end, __concat = function() return "" end,
})
local env = setmetatable({ wipe = function(t) for k in pairs(t) do t[k] = nil end return t end },
  { __index = function(_, k) local v = _G[k]; if v ~= nil then return v end return dummy end })
env._G = env
local RG = { OPTIONS = {}, COLORS = setmetatable({}, { __index = function() return "" end }), LOGO_INLINE = "" }
local chunk = assert(loadfile(root .. "/Core.lua"))
setfenv(chunk, env)
local ok, e = pcall(chunk, "Waypath", RG)
if not ok then io.stderr:write("Core.lua stopped loading: " .. tostring(e) .. "\n") end
assert(RG.ParseItemStats and RG.ScoreStats, "Core.lua has no RG.ParseItemStats / RG.ScoreStats")

-- cases: one per line, fields split by \1, lists by \2, key=value by \3:
--   P <id> <form> <raw k=v list> <tooltip lines (left text only)>
--   S <key> <loc> <slot> <model> <f> <ilvl> <weights k=v list> <stats k=v list> <class>
local function kv(field)
  local t = {}
  for part in (field or ""):gmatch("[^\2]+") do
    local k, v = part:match("^(.-)\3(.*)$")
    if k then t[k] = tonumber(v) end
  end
  return t
end
local function split(line)
  local f = {}
  for part in (line .. "\1"):gmatch("(.-)\1") do f[#f + 1] = part end
  return f
end
local function fmt(s)
  local keys = {}
  for k, v in pairs(s) do if type(v) == "number" and math.abs(v) > 1e-9 then keys[#keys + 1] = k end end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. string.format("%.4f", s[k]) end
  return table.concat(out, ",")
end
for line in io.lines(casesFile) do
  local f = split(line)
  if f[1] == "P" then
    local lines = {}
    for t in (f[5] or ""):gmatch("[^\2]+") do lines[#lines + 1] = { leftText = t } end
    local raw = kv(f[4])
    io.write("P ", f[2], " ", f[3], " ", fmt(RG.ParseItemStats(next(raw) and raw or nil, lines)), "\n")
  elseif f[1] == "S" then
    local s = { DPS = 0, SPEED = 0 }
    for k, v in pairs(kv(f[9])) do s[k] = v end
    local score = RG.ScoreStats(s, f[3], tonumber(f[4]), kv(f[8]), f[5], tonumber(f[6]), nil, tonumber(f[7]), f[10])
    io.write("S ", f[2], " ", string.format("%.4f", score), "\n")
  end
end
