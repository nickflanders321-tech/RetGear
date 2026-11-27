-- Every card through the places it shows up, using the add-on's own code all the way:
--   reveal      a pack holding 12 of the cards: the seal torn, the deal, "Turn all", shots while they turn
--               and once they've settled (reveal-NNN-turning, reveal-NNN)
--   collection  the binder pages with those cards in them (collection-NNN)
--   detail      the big card view of each card (detail-<id>)
-- Each scene marks every card on screen (its name and box) for tools/render/check_cards.py.
--
--   lua5.1 tools/harness/run.lua --shoot tools/render/scenes/cards.lua --out DIR [--cards 1-120 | --cards "Hogger;Ragnaros"]
--                                [--finish 1] [--views reveal,collection,detail] [--models 1]
-- (--models 1: only the cards that show a creature model; --cards then counts among those)
--
-- (the cards go into the harness character's collection, a fresh one each run: nothing of a real player's)
return function(T, opts)
  local RG, G, W = T.RG, T.G, T.W
  local UI = RG.ArcadeUI
  local finish = tonumber(opts.finish) or 1
  local views = {}
  for v in (opts.views or "reveal,collection,detail"):gmatch("[^,]+") do views[v] = true end

  -- which cards
  local list = {}
  local sel = opts.cards
  local lo, hi = tostring(sel or ""):match("^(%d+)%-(%d+)$")
  local names = {}
  if sel and not lo then for n in sel:gmatch("[^;]+") do names[n:lower()] = true end end
  -- --models: only cards that show a creature model
  local function hasModel(c) return (RG.ARCADE_NPC and RG.ARCADE_NPC[c.name]) or (RG.ARCADE_DUNGEON_CREATURE and RG.ARCADE_DUNGEON_CREATURE[c.name]) end
  local pool = {}
  for _, c in ipairs(UI.CARDS) do if not opts.models or hasModel(c) then pool[#pool + 1] = c end end
  for i, c in ipairs(pool) do
    if (lo and i >= tonumber(lo) and i <= tonumber(hi)) or (sel and not lo and names[c.name:lower()]) or not sel then list[#list + 1] = c end
  end
  io.stdout:write(string.format("%d cards, finish %d\n", #list, finish))

  local function cardMarks(root)
    local m = {}
    for _, f in ipairs(W.allFrames) do
      local c = rawget(f, "card")
      if type(c) == "table" and c.name and c.tier and rawget(f, "pic") and W.visible(f) and (not root or f:IsDescendantOf(root)) then
        local cover = rawget(f, "cover")
        m[#m + 1] = { label = c.name, frame = f, info = { id = c.id, tier = c.tier, kind = c.kind, ref = c.ref, finish = rawget(f, "finish"),
          covered = (cover and cover.IsShown and cover:IsShown()) and true or nil } }
      end
    end
    return m
  end
  local function waitFor(cond, limit)
    local t = 0
    while not cond() and t < (limit or 10) do T.step(0.1); t = t + 0.1 end
    return cond()
  end

  T.slash("/wp arcade")
  T.step(1)
  local frame = G.WaypathArcade
  if not frame then io.stdout:write("no card window\n") return end

  -- 1. pack reveals: the shop's pack button opens "a pack" that holds our cards
  local realOpen = RG.ArcadeOpenPack
  local batch
  RG.ArcadeOpenPack = function()
    local got = {}
    for _, c in ipairs(batch) do
      local g = RG.ArcadeAddPull(c, finish)
      if g then got[#got + 1] = g end
    end
    return got, true, {}, { kind = "normal", free = true, pityBefore = 0, sets = {}, streak = 0 }
  end
  local n = 0
  if views.reveal then
    for i = 1, #list, 12 do
      n = n + 1
      batch = {}
      for j = i, math.min(i + 11, #list) do batch[#batch + 1] = list[j] end
      frame.buyNow("normal")
      local reveal = G.WaypathArcadePack
      if not (reveal and reveal:IsShown()) then io.stdout:write("pack " .. n .. ": no reveal\n") break end
      T.step(0.5)
      -- the seal: three clicks chip it open
      for _ = 1, 3 do
        if reveal.phase ~= "seal" then break end
        T.run(reveal.seal, "OnMouseDown", "LeftButton"); T.step(0.05)
        T.run(reveal.seal, "OnMouseUp", "LeftButton"); T.step(0.15)
      end
      waitFor(function() return not reveal.phase end, 8)
      local tag = string.format("%03d", n)
      T.shoot("reveal-" .. tag .. "-dealt")
      T.click(reveal.all)
      -- partway through the turning, then once everything has stopped moving
      waitFor(function() return (reveal.flipped or 0) >= math.floor(#batch / 2) end, 20)
      T.step(0.15)
      T.shoot("reveal-" .. tag .. "-turning", { marks = cardMarks(reveal) })
      waitFor(function() return (reveal.flipped or 0) >= #batch end, 30)
      T.step(2)
      T.shoot("reveal-" .. tag, { marks = cardMarks(reveal) })
      reveal:Hide()
      -- a Mythic's moment and the like sit on top: away with them
      for _, f in ipairs(T.windows()) do if f ~= frame then f:Hide() end end
      T.step(0.2)
    end
  else
    -- the cards still go into the collection for the other views
    for _, c in ipairs(list) do RG.ArcadeAddPull(c, finish) end
  end
  RG.ArcadeOpenPack = realOpen

  -- 2. the collection, page by page (all the cards owned now are ours)
  if views.collection then
    frame:Show(); RG.ArcadeRefresh(true); T.step(0.5)
    -- (pages with none of our cards are skipped; it stops once every one has been seen)
    local want, left = {}, 0
    for _, c in ipairs(list) do want[c.name] = true; left = left + 1 end
    local seen, page, shots = {}, 0, 0
    for _ = 1, 400 do
      page = page + 1
      T.step(1)
      local marks = cardMarks(frame)
      local key, ours = {}, false
      for _, m in ipairs(marks) do
        key[#key + 1] = m.label
        if want[m.label] then ours = true; want[m.label] = nil; left = left - 1 end
      end
      key = table.concat(key, "|")
      if seen[key] or #marks == 0 then break end
      seen[key] = true
      if ours then shots = shots + 1; T.shoot(string.format("collection-%03d", page), { marks = marks }) end
      if left <= 0 then break end
      T.click(frame.next)
    end
  end

  -- 3. the big card view of each card
  if views.detail then
    for _, c in ipairs(list) do
      RG.ArcadeOpenDetail(c)
      T.step(1)
      T.shoot("detail-" .. c.id, { marks = cardMarks(G.WaypathArcadeCard) })
      if G.WaypathArcadeCard then G.WaypathArcadeCard:Hide() end
    end
  end
end
