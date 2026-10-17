-- Usage: texlua analyze.lua CSV...   (prints win rates by card group so systematic imbalances stand out)
local dir = arg[0]:match("^(.*)/tools/balance/") or "."
local L = dofile(dir .. "/tools/balance/lib.lua")
local RG, B, defs = L.load(dir)
local files = {}; for i = 1, #arg do files[#files + 1] = arg[i] end
local st, meta, hero = L.read(files)
print(string.format("games %d  first-player win %.1f%%  draws %d  avg turns %.1f", meta.games, 100 * meta.firstW / math.max(1, meta.first), meta.draws, meta.turns / math.max(1, meta.first)))
local hs = {}
for c, v in pairs(hero) do hs[#hs + 1] = { c, v[2] / v[1], v[1] } end
table.sort(hs, function(a, b) return a[2] > b[2] end)
io.write("heroes: "); for _, h in ipairs(hs) do io.write(string.format("%s %.1f%%  ", h[1], 100 * h[2])) end print()
local groups = {}
local function add(g, k, t) local x = groups[g]; if not x then x = { dn = 0, dw = 0, pn = 0, pw = 0, cards = 0 }; groups[g] = x end
  x.dn = x.dn + t.dn; x.dw = x.dw + t.dw; x.pn = x.pn + t.pn; x.pw = x.pw + t.pw; x.cards = x.cards + 1 end
for k, t in pairs(st) do
  local d = defs[k]
  if d then
    add("type:" .. d.type, k, t)
    add(string.format("cost:%02d", d.cost), k, t)
    add(string.format("%s cost:%02d", d.type, d.cost), k, t)
    add("tier:" .. (d.tier or 1), k, t)
    if d.type == "minion" then
      add("tribe:" .. (d.tribe or "?"), k, t)
      for kw in pairs(d.kw or {}) do add("kw:" .. kw, k, t) end
      if d.bc then add("bc:" .. d.bc[1].op, k, t) end
      if d.dr then add("dr:" .. d.dr[1].op, k, t) end
      if d.eot then add("eot:" .. d.eot[1].op, k, t) end
      if not (d.bc or d.dr or d.eot or next(d.kw or {})) then add("minion:vanilla", k, t) end
    elseif d.type == "spell" then
      add("spell:" .. d.ops[1].op .. ((d.ops[1].at and d.ops[1].at ~= "t") and ("@" .. d.ops[1].at) or ""), k, t)
    end
  end
end
local names = {}; for g in pairs(groups) do names[#names + 1] = g end
table.sort(names)
print(string.format("%-26s %6s %8s %7s %7s", "group", "cards", "deckWR", "z", "playWR"))
for _, g in ipairs(names) do
  local x = groups[g]
  local wr = x.dw / math.max(1, x.dn)
  local pw = x.pw / math.max(1, x.pn)
  print(string.format("%-26s %6d %7.2f%% %7.1f %6.2f%%", g, x.cards, 100 * wr, L.z(x.dw, x.dn), 100 * pw))
end
