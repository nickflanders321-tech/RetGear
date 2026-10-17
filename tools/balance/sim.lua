-- Self-play simulator for the Waypath Arena. Usage: texlua sim.lua GAMES SEED OUT.csv [LEVEL]
-- Plays random decks against each other with the built-in AI and records, for every card, how often the side that had it
-- in its deck (and the side that actually played it) won. Cards that win far more or less than 50% need a nudge.
local games, seed, out, level = tonumber(arg[1] or 2000), tonumber(arg[2] or 1), arg[3] or "/tmp/sim.csv", tonumber(arg[4] or 3)
math.randomseed(seed)
local dir = arg[0]:match("^(.*)/tools/balance/") or "."
local RG = {}
for _, f in ipairs({ "ArcadeCards.lua", "ArcadeBalance.lua", "Battle.lua" }) do assert(loadfile(dir .. "/" .. f))("Waypath", RG) end
local B = RG.Battle
local keys = {}
for i, c in ipairs(RG.ARCADE_DATA) do
  local cc = { id = i, kind = c[1], name = c[2], tier = c[3], ref = c[4], text = c[5] }
  B.derive(cc); keys[#keys + 1] = cc.name
end
local st = {}
local function S(k) local t = st[k]; if not t then t = { dn = 0, dw = 0, pn = 0, pw = 0 }; st[k] = t end return t end
local heroN, heroW = {}, {}
local firstW, firstN, turns, draws = 0, 0, 0, 0
for g = 1, games do
  local d = { B.randomDeck(keys, 6, math.random), B.randomDeck(keys, 6, math.random) }
  local cl = { B.CLASSES[math.random(#B.CLASSES)], B.CLASSES[math.random(#B.CLASSES)] }
  local G = B.new({ decks = d, classes = cl, seed = math.random(1, 2000000000) })
  B.mulligan(G, 1, {}); B.mulligan(G, 2, {})
  local guard = 0
  while not G.over and guard < 700 do
    guard = guard + 1
    local s = G.cur
    local act = B.aiPick(G, s, level)
    if act then B.exec(G, s, act) else B.endTurn(G, s) end
    G.ev = {}   -- we only need the plays: collected below
  end
  -- plays were cleared each step; recount from the decks instead (cards left in deck were never drawn)
  if G.over and G.winner and G.winner > 0 then
    turns = turns + G.turn; firstN = firstN + 1
    if G.winner == G.first then firstW = firstW + 1 end
    for s = 1, 2 do
      local won = G.winner == s and 1 or 0
      local seen = {}
      for _, k in ipairs(d[s]) do if not seen[k] then seen[k] = true; local t = S(k); t.dn = t.dn + 1; t.dw = t.dw + won end end
      heroN[cl[s]] = (heroN[cl[s]] or 0) + 1; heroW[cl[s]] = (heroW[cl[s]] or 0) + won
      for k in pairs(G.p[s].played or {}) do local t = S(k); t.pn = t.pn + 1; t.pw = t.pw + won end
    end
  else draws = draws + 1 end
end
local f = assert(io.open(out, "w"))
f:write(string.format("#meta,%d,%d,%d,%d,%.3f\n", games, firstN, firstW, draws, turns / math.max(1, firstN)))
for c, n in pairs(heroN) do f:write(string.format("#hero,%s,%d,%d\n", c, n, heroW[c])) end
for k, t in pairs(st) do f:write(string.format("%s\t%d\t%d\t%d\t%d\n", k, t.dn, t.dw, t.pn, t.pw)) end
f:close()
