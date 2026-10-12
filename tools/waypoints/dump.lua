-- Dump Forever NPC names, spawns, friendliness and flags as TSV: id \t name \t friendly \t flags \t sub \t zone:x,y;x,y|zone:...
local QDB = {}
QuestieLoader = { ImportModule = function() return QDB end }
dofile(arg[1])
local npcs = loadstring(QDB.npcData)()
local zones = {}
local f = io.open(arg[2], "w")
for id, n in pairs(npcs) do
  local spawns = n[7]
  if n[1] and spawns then
    local parts = {}
    for z, list in pairs(spawns) do
      local pts = {}
      for _, p in ipairs(list) do if p[1] and p[1] >= 0 then pts[#pts + 1] = string.format("%.2f,%.2f", p[1], p[2]) end end
      if #pts > 0 then parts[#parts + 1] = z .. ":" .. table.concat(pts, ";") end
    end
    if #parts > 0 then f:write(id, "\t", n[1], "\t", n[13] or "", "\t", n[15] or 0, "\t", n[14] or "", "\t", table.concat(parts, "|"), "\n") end
  end
end
f:close()
