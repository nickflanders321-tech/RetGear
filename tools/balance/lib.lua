-- shared by analyze.lua and tune.lua: load the engine and the simulation results
local M = {}
function M.load(dir)
  local RG = {}
  for _, f in ipairs({ "ArcadeCards.lua", "ArcadeBalance.lua", "Battle.lua" }) do assert(loadfile(dir .. "/" .. f))("Waypath", RG) end
  local B = RG.Battle
  local patch = os.getenv("BAL_PATCH")
  if patch then dofile(patch)(B, RG) end
  local defs = {}
  for i, c in ipairs(RG.ARCADE_DATA) do
    local cc = { id = i, kind = c[1], name = c[2], tier = c[3], ref = c[4], text = c[5] }
    defs[cc.name] = B.derive(cc)
  end
  return RG, B, defs
end
function M.read(files)
  local st, meta, hero = {}, { games = 0, first = 0, firstW = 0, draws = 0, turns = 0 }, {}
  for _, fn in ipairs(files) do
    local f = io.open(fn)
    if f then
      for line in f:lines() do
        if line:sub(1, 5) == "#meta" then
          local _, g, fn2, fw, dr, tu = line:match("^(#meta),(%d+),(%d+),(%d+),(%d+),([%d%.]+)")
          meta.games = meta.games + tonumber(g); meta.first = meta.first + tonumber(fn2); meta.firstW = meta.firstW + tonumber(fw)
          meta.draws = meta.draws + tonumber(dr); meta.turns = meta.turns + tonumber(tu) * tonumber(fn2)
        elseif line:sub(1, 5) == "#hero" then
          local c, n, w = line:match("^#hero,(%u+),(%d+),(%d+)")
          hero[c] = hero[c] or { 0, 0 }; hero[c][1] = hero[c][1] + tonumber(n); hero[c][2] = hero[c][2] + tonumber(w)
        else
          local k, a, b, c, d = line:match("^(.-)\t(%d+)\t(%d+)\t(%d+)\t(%d+)$")
          if k then
            local t = st[k] or { dn = 0, dw = 0, pn = 0, pw = 0 }
            t.dn = t.dn + a; t.dw = t.dw + b; t.pn = t.pn + c; t.pw = t.pw + d; st[k] = t
          end
        end
      end
      f:close()
    end
  end
  return st, meta, hero
end
function M.z(w, n) if n == 0 then return 0 end return (w / n - 0.5) / math.sqrt(0.25 / n) end
return M
