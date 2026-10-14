-- Dump object spawns (with IDs) and which items each object drops, from QuestieDB's merged Forever data.
-- Usage: lua5.1 dump.lua <QuestieDB>/src/corrections/Forever/combined <objects.tsv> <items.tsv>
--   objects.tsv: id <TAB> name <TAB> zone:x,y;x,y|zone:...        items.tsv: id <TAB> name <TAB> objectDrop ids (comma separated)
local dir, outO, outI = arg[1], arg[2], arg[3]
local QDB = {}
QuestieLoader = { ImportModule = function() return QDB end }
local function load(name, key)
  local r = dofile(dir .. "/" .. name)
  if type(r) ~= "table" then r = loadstring(QDB[key])() end
  return r
end
local objects, items = load("foreverObjectDB.lua", "objectData"), load("foreverItemDB.lua", "itemData")
local f = assert(io.open(outO, "w"))
for id, o in pairs(objects) do
  if o[1] then
    local parts = {}
    for z, pts in pairs(o[4] or {}) do
      local s = {}
      for _, p in ipairs(pts) do s[#s + 1] = p[1] .. "," .. p[2] end
      parts[#parts + 1] = z .. ":" .. table.concat(s, ";")
    end
    f:write(id, "\t", o[1], "\t", table.concat(parts, "|"), "\n")
  end
end
f:close()
f = assert(io.open(outI, "w"))
for id, it in pairs(items) do
  if it[1] then
    local d = {}
    for _, o in ipairs(it[3] or {}) do d[#d + 1] = o end
    f:write(id, "\t", it[1], "\t", table.concat(d, ","), "\n")
  end
end
f:close()
