-- Dump QuestieDB Forever quests, items, NPCs and objects to JSON for gen.py.
-- Usage: lua5.1 dump.lua <QuestieDB>/data/Forever <out.json>
local dir, out = arg[1], arg[2]
local QDB = {}
QuestieLoader = { ImportModule = function() return QDB end }
-- Works with QuestieDB's raw data/Forever files and with its merged export
-- (tools/export-forever.lua --include-authored -> src/corrections/Forever/combined),
-- which adds the new Forever quests, NPCs and level changes.
local function load(file, field)
  local r = dofile(dir .. "/" .. file)
  if type(r) == "table" then return r end
  return loadstring(QDB[field])()
end
local quests = load("foreverQuestDB.lua", "questData")
local items = load("foreverItemDB.lua", "itemData")
local npcs = load("foreverNpcDB.lua", "npcData")
local objects = load("foreverObjectDB.lua", "objectData")
local function enc(v)
  local t = type(v)
  if t == "nil" then return "null" elseif t == "number" then return string.format("%.17g", v)
  elseif t == "boolean" then return tostring(v)
  elseif t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
  elseif t == "table" then
    if v.__obj then   -- spawn tables are keyed by area id: always an object (area 1 alone would look like a list)
      local p = {}
      for k, x in pairs(v.__obj) do p[#p + 1] = enc(tostring(k)) .. ":" .. enc(x) end
      return "{" .. table.concat(p, ",") .. "}"
    end
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
local f = io.open(out, "w")
local Q = {}
for id, q in pairs(quests) do Q[id] = { q[1], q[2], q[3], q[4], q[5], q[6], q[10], q[17], q[24], q[7], q[12], q[13], q[16] } end
local I = {}
for id, it in pairs(items) do if it[2] or it[3] then I[id] = { it[1], it[2], it[3] } end end
local N = {}
for id, n in pairs(npcs) do N[id] = { n[1], n[7] and { __obj = n[7] } or nil, n[13] } end
local O = {}
for id, o in pairs(objects) do O[id] = { o[1], o[4] and { __obj = o[4] } or nil } end
f:write('{"quests":', enc(Q), ',"items":', enc(I), ',"npcs":', enc(N), ',"objects":', enc(O), '}')
f:close()
