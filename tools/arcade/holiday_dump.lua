-- Dump the holiday quests from QuestieDB's Forever quest table: id, sort, name, starters, finishers, creatures to
-- kill or meet, items to bring (TSV).
-- Usage: lua tools/arcade/holiday_dump.lua <foreverQuestDB.lua> <out.tsv>
local src = assert(io.open(arg[1])):read("*a")
local env = setmetatable({}, { __index = _G })
local fn
if setfenv then fn = assert(loadstring(src)); setfenv(fn, env) else fn = assert(load(src, "q", "t", env)) end
local quest = fn()
local want = { [-22] = true, [-284] = true, [-366] = true, [-369] = true }
local function npcs(t)
  local out = {}
  if type(t) == "table" and type(t[1]) == "table" then for _, n in ipairs(t[1]) do out[#out + 1] = tostring(n) end end
  return table.concat(out, ",")
end
local function objs(q, k)
  local out = {}
  local o = type(q[10]) == "table" and q[10][k]
  if type(o) == "table" then for _, e in ipairs(o) do local id = type(e) == "table" and e[1] or e; if type(id) == "number" then out[#out + 1] = tostring(id) end end end
  return table.concat(out, ",")
end
local ids = {}
for id, q in pairs(quest) do if want[q[17]] then ids[#ids + 1] = id end end
table.sort(ids)
local f = assert(io.open(arg[2], "w"))
for _, id in ipairs(ids) do
  local q = quest[id]
  f:write(id, "\t", q[17], "\t", (tostring(q[1]):gsub("[\t\n]", " ")), "\t", npcs(q[2]), "\t", npcs(q[3]), "\t", objs(q, 1), "\t", objs(q, 3), "\n")
end
f:close()
