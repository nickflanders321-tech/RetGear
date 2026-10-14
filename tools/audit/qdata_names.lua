-- Prints the IDs of every quest in Objectives.lua that has a name (for crosscheck.py).
local root = (arg[1] or "."):gsub("/$", "")
local RG = {}
assert(loadfile(root .. "/Objectives.lua"))("Waypath", RG)
for id, d in pairs(RG.QDATA) do if d.n then io.write(id, "\n") end end
