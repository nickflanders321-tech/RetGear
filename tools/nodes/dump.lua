-- Dump every mining-node spawn point from QuestieDB's Forever object data.
-- Usage: lua5.1 dump.lua <QuestieDB>/data/Forever/foreverObjectDB.lua <out.tsv>
local file, out = arg[1], arg[2]
local QDB = {}
QuestieLoader = { ImportModule = function() return QDB end }
local objects = dofile(file)  -- the merged export returns the table; raw data sets QDB.objectData
if type(objects) ~= "table" then objects = loadstring(QDB.objectData)() end
local f = io.open(out, "w")
for _, o in pairs(objects) do
  local n = o[1]
  if n and (n:find("Vein") or n:find("Deposit")) and o[4] then
    for z, pts in pairs(o[4]) do
      for _, p in ipairs(pts) do f:write(n, "\t", z, "\t", p[1], "\t", p[2], "\n") end
    end
  end
end
f:close()
