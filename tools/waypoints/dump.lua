-- Dump Forever NPC names, spawns, friendliness and flags as TSV: id \t name \t friendly \t flags \t sub \t zone:x,y;x,y|zone:...
local QDB = {}
QuestieLoader = { ImportModule = function() return QDB end }
local npcs = dofile(arg[1])  -- the merged export returns the table; raw data sets QDB.npcData
if type(npcs) ~= "table" then npcs = loadstring(QDB.npcData)() end
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
    -- some Forever rows carry an empty table instead of a string/number (e.g. friendly = {}), so only write plain values
    local function plain(v, default) local t = type(v); if t == "string" or t == "number" then return v end; return default end
    if #parts > 0 and plain(n[1]) then f:write(id, "\t", n[1], "\t", plain(n[13], ""), "\t", plain(n[15], 0), "\t", plain(n[14], ""), "\t", table.concat(parts, "|"), "\n") end
  end
end
f:close()
