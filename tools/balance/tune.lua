-- Usage: texlua tune.lua [--apply] [--z 2.5] [--min 0.01] CSV...
-- Nudges the cards whose deck win rate is clearly off 50%: a nerf costs one more mana (or a stat point once the cost
-- has moved as far as it may), a buff one less. Writes ArcadeBalance.lua when --apply is given.
local dir = arg[0]:match("^(.*)/tools/balance/") or "."
local L = dofile(dir .. "/tools/balance/lib.lua")
local RG, B, defs = L.load(dir)
local apply, Z, MIN, files = false, 2.5, 0.01, {}
local i = 1
while i <= #arg do
  if arg[i] == "--apply" then apply = true
  elseif arg[i] == "--z" then i = i + 1; Z = tonumber(arg[i])
  elseif arg[i] == "--min" then i = i + 1; MIN = tonumber(arg[i])
  else files[#files + 1] = arg[i] end
  i = i + 1
end
local st = L.read(files)
local bal = RG.ARCADE_BALANCE
local nerf, buff, stuck = 0, 0, 0
local rows = {}
for k, t in pairs(st) do
  local d = defs[k]
  if d and t.dn >= 300 then
    local wr = t.dw / t.dn
    local z = L.z(t.dw, t.dn)
    if math.abs(z) >= Z and math.abs(wr - 0.5) >= MIN then
      local b = bal[k] or {}
      local dir2 = wr > 0.5 and 1 or -1       -- +1 nerf, -1 buff
      local c = b.cost or 0
      local done = false
      if dir2 == 1 then
        if c < 2 and d.cost < 10 then b.cost = c + 1; done = true
        elseif d.type == "minion" then
          if d.hp >= d.atk and d.hp > 1 then b.hp = (b.hp or 0) - 1; done = true elseif d.atk > 1 then b.atk = (b.atk or 0) - 1; done = true end
        elseif d.type == "weapon" and d.dur > 1 then b.dur = (b.dur or 0) - 1; done = true end
        if done then nerf = nerf + 1 end
      else
        if c > -2 and d.cost > 0 then b.cost = c - 1; done = true
        elseif d.type == "minion" then b.hp = (b.hp or 0) + 1; done = true
        elseif d.type == "weapon" then b.dur = (b.dur or 0) + 1; done = true end
        if done then buff = buff + 1 end
      end
      if done then bal[k] = b else stuck = stuck + 1 end
      rows[#rows + 1] = { k, wr, z, d.type, d.cost, done }
    end
  end
end
table.sort(rows, function(a, b) return math.abs(a[3]) > math.abs(b[3]) end)
for n = 1, math.min(25, #rows) do local r = rows[n]; print(string.format("%-40s %-7s cost %2d  WR %.1f%%  z %.1f  %s", r[1], r[4], r[5], 100 * r[2], r[3], r[6] and "" or "(no room)")) end
print(string.format("flagged %d: nerfs %d, buffs %d, no room %d", #rows, nerf, buff, stuck))
if apply then
  local names = {}; for k in pairs(bal) do names[#names + 1] = k end
  table.sort(names)
  local f = assert(io.open(dir .. "/ArcadeBalance.lua", "w"))
  f:write("-- Per-card balance nudges, written by tools/balance/tune.lua from simulated duels. Do not edit by hand.\nlocal _, RG = ...\nRG.ARCADE_BALANCE = {\n")
  for _, k in ipairs(names) do
    local b = bal[k]; local parts = {}
    for _, f2 in ipairs({ "cost", "atk", "hp", "dur" }) do if b[f2] and b[f2] ~= 0 then parts[#parts + 1] = f2 .. " = " .. b[f2] end end
    if #parts > 0 then f:write(string.format("  [%q] = { %s },\n", k, table.concat(parts, ", "))) end
  end
  f:write("}\n"); f:close()
  print("wrote ArcadeBalance.lua")
end
