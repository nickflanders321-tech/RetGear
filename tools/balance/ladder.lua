-- A ladder season in a box. Usage: texlua ladder.lua GENERATIONS SEED OUT.csv [DECKS_PER_CLASS] [GAMES_PER_DECK]
-- Every class starts with random decks of its own and neutral cards. Each generation every deck plays a batch of games
-- against the whole field (the built-in AI at its best level), the weaker half of each class is replaced by copies of
-- the stronger half with a few cards swapped, and so on: after a while the decks look like a "meta" - the cards people
-- would actually play. The result says which cards nearly every top deck runs (nerf candidates when they also win),
-- how each class does once its decks are tuned, and what the best lists look like.
-- OUT.csv: card, decks running it in the final field, games, wins (by the decks running it)
local gens, seed, out = tonumber(arg[1] or 20), tonumber(arg[2] or 1), arg[3] or "/tmp/ladder.csv"
local perClass, perDeck = tonumber(arg[4] or 6), tonumber(arg[5] or 16)
math.randomseed(seed)
local dir = arg[0]:match("^(.*)/tools/balance/") or "."
local RG = {}
for _, f in ipairs({ "ArcadeCards.lua", "ArcadeClasses.lua", "ArcadeBalance.lua", "Battle.lua" }) do assert(loadfile(dir .. "/" .. f))("Waypath", RG) end
local B = RG.Battle
if arg[6] then dofile(arg[6])(B, RG) end
local pool = {}
for i, c in ipairs(RG.ARCADE_DATA) do
  local cc = { id = i, kind = c[1], name = c[2], tier = c[3], ref = c[4], text = c[5] }
  B.derive(cc); pool[#pool + 1] = cc.name
end
for _, k in ipairs(B.BASIC) do pool[#pool + 1] = k end
local byClass, classOnly = {}, {}
for _, cl in ipairs(B.CLASSES) do
  local l, c = {}, {}
  for _, k in ipairs(pool) do local d = B.defs[k]; if d and not d.special and B.classOK(d, cl) then l[#l + 1] = k; if d.hclass then c[#c + 1] = k end end end
  byClass[cl], classOnly[cl] = l, c
end

local function play(d1, c1, d2, c2)
  local G = B.new({ decks = { d1, d2 }, classes = { c1, c2 }, seed = math.random(1, 2000000000) })
  B.mulligan(G, 1, {}); B.mulligan(G, 2, {})
  local guard = 0
  while not G.over and guard < 700 do
    guard = guard + 1
    local s = G.cur
    local act = B.aiPick(G, s, 3)
    if act then B.exec(G, s, act) else B.endTurn(G, s) end
    G.ev = {}
  end
  return G.over and G.winner or 0
end

local function count(deck) local c = {}; for _, k in ipairs(deck) do c[k] = (c[k] or 0) + 1 end return c end
local function mutate(deck, cl, n)
  local d = {}; for i, k in ipairs(deck) do d[i] = k end
  local list = byClass[cl]
  for _ = 1, n do
    local c = count(d)
    local out = math.random(#d)
    local old = B.defs[d[out]]
    -- prefer a card of a similar cost, so the curve stays sane
    -- (a quarter of the swaps look at the class's own cards: players build around them)
    local from = math.random(4) == 1 and classOnly[cl] or list
    for _ = 1, 40 do
      local k = from[math.random(#from)]
      local nd = B.defs[k]
      if (c[k] or 0) < B.maxCopies(nd) and math.abs(nd.cost - old.cost) <= 2 and k ~= d[out] then d[out] = k; break end
    end
  end
  return d
end

local field = {}
for _, cl in ipairs(B.CLASSES) do
  for _ = 1, perClass do
    -- start each deck with a handful of its class cards, as a player would
    local seedList = {}
    for _ = 1, 8 do seedList[#seedList + 1] = classOnly[cl][math.random(#classOnly[cl])] end
    field[#field + 1] = { cl = cl, deck = B.randomDeck(byClass[cl], 6, math.random, seedList, nil, cl), w = 0, n = 0 }
  end
end

local function season(label)
  for _, e in ipairs(field) do e.w, e.n = 0, 0 end
  for _, e in ipairs(field) do
    for _ = 1, perDeck do
      local o = field[math.random(#field)]
      if o ~= e then
        local first = math.random(2)
        local w
        if first == 1 then w = play(e.deck, e.cl, o.deck, o.cl); w = (w == 1) and 1 or (w == 2 and 0 or 0.5)
        else w = play(o.deck, o.cl, e.deck, e.cl); w = (w == 2) and 1 or (w == 1 and 0 or 0.5) end
        e.w, e.n = e.w + w, e.n + 1
        o.w, o.n = o.w + (1 - w), o.n + 1
      end
    end
  end
  local cw = {}
  for _, e in ipairs(field) do local t = cw[e.cl] or { 0, 0 }; t[1] = t[1] + e.w; t[2] = t[2] + e.n; cw[e.cl] = t end
  local l = {}
  for cl, t in pairs(cw) do l[#l + 1] = { cl, t[1] / math.max(1, t[2]) } end
  table.sort(l, function(a, b) return a[2] > b[2] end)
  local s = {}
  for _, x in ipairs(l) do s[#s + 1] = string.format("%s %.0f%%", x[1]:sub(1, 1) .. x[1]:sub(2, 4):lower(), 100 * x[2]) end
  print(label .. "  " .. table.concat(s, "  "))
  io.stdout:flush()
end

for g = 1, gens do
  season(string.format("gen %2d", g))
  -- within each class, the weaker half becomes mutated copies of the stronger half
  for _, cl in ipairs(B.CLASSES) do
    local mine = {}
    for _, e in ipairs(field) do if e.cl == cl then mine[#mine + 1] = e end end
    table.sort(mine, function(a, b) return a.w / math.max(1, a.n) > b.w / math.max(1, b.n) end)
    local half = math.floor(#mine / 2)
    for i = half + 1, #mine do
      local parent = mine[math.random(half)]
      mine[i].deck = mutate(parent.deck, cl, g < gens / 2 and 4 or 2)
    end
    -- the best deck also tries a small change each generation
    mine[1].deck = mine[1].deck
  end
end
season("final ")

-- the final field: how often each card is run, and how its decks did
local st = {}
for _, e in ipairs(field) do
  local seen = {}
  for _, k in ipairs(e.deck) do
    if not seen[k] then
      seen[k] = true
      local t = st[k] or { decks = 0, n = 0, w = 0, classes = {} }
      t.decks = t.decks + 1; t.n = t.n + e.n; t.w = t.w + e.w; t.classes[e.cl] = true
      st[k] = t
    end
  end
end
local f = assert(io.open(out, "w"))
for k, t in pairs(st) do
  local nc = 0; for _ in pairs(t.classes) do nc = nc + 1 end
  f:write(string.format("%s\t%d\t%d\t%.1f\t%d\n", k, t.decks, t.n, t.w, nc))
end
f:close()
-- the best list of each class
table.sort(field, function(a, b) return a.w / math.max(1, a.n) > b.w / math.max(1, b.n) end)
local shown = {}
for _, e in ipairs(field) do
  if not shown[e.cl] then
    shown[e.cl] = true
    local c = count(e.deck)
    local ks = {}; for k in pairs(c) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b) local x, y = B.defs[a], B.defs[b]; if x.cost ~= y.cost then return x.cost < y.cost end return a < b end)
    local parts, cls = {}, 0
    for _, k in ipairs(ks) do parts[#parts + 1] = B.defs[k].cost .. " " .. k .. (c[k] > 1 and " x2" or ""); if B.defs[k].hclass then cls = cls + c[k] end end
    print(string.format("\nbest %s deck (%.0f%%, %d class cards): %s", e.cl, 100 * e.w / math.max(1, e.n), cls, table.concat(parts, ", ")))
  end
end
