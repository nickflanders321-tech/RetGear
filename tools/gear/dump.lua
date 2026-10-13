-- Dump QuestieDB Forever items, NPCs and quests (the fields gen.py needs) to JSON.
-- Usage: lua5.1 dump.lua <QuestieDB>/data/Forever <out.json>
local dir, out = arg[1], arg[2]
local QDB = {}
QuestieLoader = { ImportModule = function() return QDB end }
local function load(file, field)  -- raw data/Forever or the merged export (see tools/qdb)
  local r = dofile(dir .. "/" .. file)
  if type(r) == "table" then return r end
  return loadstring(QDB[field])()
end
local quests = load("foreverQuestDB.lua", "questData")
local items = load("foreverItemDB.lua", "itemData")
local npcs = load("foreverNpcDB.lua", "npcData")
local function enc(v)
  local t = type(v)
  if t == "nil" then return "null" elseif t == "number" then return string.format("%.17g", v)
  elseif t == "boolean" then return tostring(v)
  elseif t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
  elseif t == "table" then
    local n, max = 0, 0
    for k in pairs(v) do n = n + 1; if type(k) == "number" and k > max then max = k end end
    if n > 0 and max == n then local p = {} for i = 1, n do p[i] = enc(v[i]) end return "[" .. table.concat(p, ",") .. "]" end
    if n == 0 then return "[]" end
    local p = {}
    for k, x in pairs(v) do p[#p + 1] = enc(tostring(k)) .. ":" .. enc(x) end
    return "{" .. table.concat(p, ",") .. "}"
  end
  return "null"
end
local I = {}
for id, it in pairs(items) do
  if it[12] == 2 or it[12] == 4 then
    I[id] = { name = it[1], npcDrops = it[2], objectDrops = it[3], questRewards = it[6], reqLevel = it[10], class = it[12], sub = it[13], vendors = it[14] }
  end
end
local N = {}
for id, n in pairs(npcs) do N[id] = { name = n[1], minLevel = n[4], maxLevel = n[5], rank = n[6], zone = n[9], faction = n[13], sub = n[14] } end
local Q = {}
for id, q in pairs(quests) do Q[id] = { name = q[1], start = q[2], reqLevel = q[4], level = q[5], races = q[6], classes = q[7], zone = q[17] } end
local f = io.open(out, "w")
f:write('{"items":', enc(I), ',"npcs":', enc(N), ',"quests":', enc(Q), '}')
f:close()
