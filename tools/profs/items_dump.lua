-- Dump every item's ID and name from QuestieDB's merged Forever data (Forever-only
-- reagents such as Mote of Magic aren't in the classic database).
-- Usage: lua5.1 items_dump.lua <QuestieDB>/src/corrections/Forever/combined <out.tsv>
local dir, out = arg[1], arg[2]
local QDB = {}
QuestieLoader = { ImportModule = function() return QDB end }
local r = dofile(dir .. "/foreverItemDB.lua")
if type(r) ~= "table" then r = loadstring(QDB.itemData)() end
local f = assert(io.open(out, "w"))
for id, it in pairs(r) do if it[1] then f:write(id, "\t", it[1], "\n") end end
f:close()
