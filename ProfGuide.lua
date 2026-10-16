-- Waypath+ profession guide: works out where you are in each profession's
-- leveling route (Professions/<Name>.lua, from the WoW Forever guides), how many
-- crafts are left in the current step, how many more of each material you need
-- for it (counting your bags and bank, and the materials for crafted reagents
-- like bolts and bars), and places to go: the best herb/ore clusters, skinning
-- mobs and fishing pools for your skill, the mobs, nodes and vendors for the
-- materials you're short of, and your next trainer. Double-click a place on the
-- Professions tab and the arrow takes you there.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY

-- ---------------------------------------------------------------------------
-- Recipes: what your client shows wins over the generated data
-- ---------------------------------------------------------------------------
function RG.Recipe(name)
  local seen = RG.db and RG.db.recipes and RG.db.recipes[name]
  return seen or (RG.RECIPES or {})[name]
end

local function itemIDFromLink(l) return l and tonumber(l:match("item:(%d+)")) end
local function wanted(name) return (RG.RECIPES or {})[name] ~= nil end
local function remember(name, reagents, yield)
  if not (name and wanted(name) and #reagents > 0) then return end
  RG.db.recipes = RG.db.recipes or {}
  RG.db.recipes[name] = { r = reagents, y = yield or ((RG.RECIPES[name] or {}).y) or 1, seen = true }
end
-- Read the open profession window (classic trade skill API, the enchanting craft
-- API, or the modern C_TradeSkillUI) and remember the reagents of every recipe
-- on the leveling routes.
local function readWindow()
  if not RG.db then return end
  if GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillNumReagents then
    for i = 1, (GetNumTradeSkills() or 0) do
      local name, kind = GetTradeSkillInfo(i)
      if name and kind ~= "header" and wanted(name) then
        local r = {}
        for j = 1, (GetTradeSkillNumReagents(i) or 0) do
          local _, _, count = GetTradeSkillReagentInfo(i, j)
          local id = itemIDFromLink(GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, j))
          if id and count then r[#r + 1] = { id, count } end
        end
        local lo, hi = 1, 1
        if GetTradeSkillNumMade then lo, hi = GetTradeSkillNumMade(i) end
        remember(name, r, math.floor(((lo or 1) + (hi or lo or 1)) / 2))
      end
    end
  end
  if GetNumCrafts and GetCraftInfo and GetCraftNumReagents then
    for i = 1, (GetNumCrafts() or 0) do
      local name, _, kind = GetCraftInfo(i)
      if name and kind ~= "header" and wanted(name) then
        local r = {}
        for j = 1, (GetCraftNumReagents(i) or 0) do
          local _, _, count = GetCraftReagentInfo(i, j)
          local id = itemIDFromLink(GetCraftReagentItemLink and GetCraftReagentItemLink(i, j))
          if id and count then r[#r + 1] = { id, count } end
        end
        remember(name, r, 1)
      end
    end
  end
  local T = C_TradeSkillUI
  if T and T.GetAllRecipeIDs and T.GetRecipeInfo and T.GetRecipeSchematic then
    local ok, ids = pcall(T.GetAllRecipeIDs)
    for _, rid in ipairs(ok and ids or {}) do
      local info = T.GetRecipeInfo(rid)
      if info and info.name and wanted(info.name) then
        local okS, sch = pcall(T.GetRecipeSchematic, rid, false)
        if okS and sch and sch.reagentSlotSchematics then
          local r = {}
          for _, slot in ipairs(sch.reagentSlotSchematics) do
            local re = slot.reagents and slot.reagents[1]
            if re and re.itemID and slot.quantityRequired then r[#r + 1] = { re.itemID, slot.quantityRequired } end
          end
          remember(info.name, r, math.floor(((sch.quantityMin or 1) + (sch.quantityMax or 1)) / 2))
        end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Where you are on the route, and what you still need
-- ---------------------------------------------------------------------------
local function count(id)
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  return (f and f(id, true)) or 0   -- bags and bank
end
RG.MatCount = count
local function matName(id)
  local n = RG.ItemInfo(id)
  if n then return n end
  local m = RG.MAT_INFO and RG.MAT_INFO[id]
  return m and m[1] or ("item " .. id)
end
RG.MatName = matName
local function options(st)
  local out = {}
  if st.craft then
    for part in (st.craft .. ","):gmatch("%s*(.-)%s*,") do
      for o in (part .. " or "):gmatch("(.-) or ") do
        o = o:gsub("^%s+", ""):gsub("%s+$", "")
        if o ~= "" then out[#out + 1] = o end
      end
    end
  end
  return out
end
RG.StepOptions = options

-- How many crafts of a step are left at this skill (the guides' counts include
-- the crafts that don't give a point).
function RG.StepCraftsLeft(st, skill)
  if not st.n or not st.to then return 0 end
  if skill >= st.to then return 0 end
  if skill <= st.from or st.to <= st.from then return st.n end
  return math.max(1, math.ceil(st.n * (st.to - skill) / (st.to - st.from)))
end

-- Materials for `crafts` crafts of a recipe: { {id, name, need, have, short, via?}, ... }
-- Short crafted reagents (bolts, bars, elixirs) add the materials to make them.
function RG.MatsFor(recipeName, crafts)
  local rec = RG.Recipe(recipeName)
  if not rec then return nil end
  local out, idx = {}, {}
  local function add(id, need, via)
    local e = idx[id]
    if e then e.need = e.need + need
    else e = { id = id, name = matName(id), need = need, via = via }; idx[id] = e; out[#out + 1] = e end
  end
  local runs = math.ceil(crafts / math.max(1, rec.y or 1))
  for _, r in ipairs(rec.r) do add(r[1], r[2] * runs) end
  -- one level down: make the reagents you're short of (bolts, bars, elixirs:
  -- things you craft, not leather you'd rather skin)
  for i = 1, #out do
    local e = out[i]
    local sub = RG.Recipe(e.name)
    local info = RG.MAT_INFO and RG.MAT_INFO[e.id]
    if sub and sub.r and #sub.r > 0 and (not info or info[2] == "crafted") then
      local short = e.need - count(e.id)
      if short > 0 then
        local subRuns = math.ceil(short / math.max(1, sub.y or 1))
        for _, r in ipairs(sub.r) do add(r[1], r[2] * subRuns, e.name) end
      end
    end
  end
  for _, e in ipairs(out) do e.have = count(e.id); e.short = math.max(0, e.need - e.have) end
  return out
end

-- Fishing's route lives in Fish.lua (RG.FISH_ROUTE): the same step shape as the others.
local fishPlan
function RG.ProfPlan(P)
  if P.plan then return P.plan end
  if P.fishTab and RG.FISH_ROUTE then
    if not fishPlan then
      fishPlan = {}
      for _, f in ipairs(RG.FISH_ROUTE) do fishPlan[#fishPlan + 1] = { from = f.from, to = f.to, fish = f.zone, where = f.spot, lvl = f.lvl } end
    end
    return fishPlan
  end
  return {}
end

-- The step you're on (or the next one), for any profession.
function RG.ProfNow(name, skillOverride)
  local P = RG.PROFESSIONS and RG.PROFESSIONS[name]
  if not P then return nil end
  local skill = skillOverride or RG.Skill(name) or 0
  local plan = RG.ProfPlan(P)
  local now, idx
  for i, st in ipairs(plan) do
    if not st.train and skill < st.to then now, idx = st, i; break end
  end
  if not now then return { done = true, skill = skill, P = P } end
  local res = { st = now, index = idx, skill = skill, P = P }
  -- crafting: pick the option you're closest to making from your bags; on a tie,
  -- skip options that need fish if you don't fish
  local opts = options(now)
  if #opts > 0 then
    res.left = RG.StepCraftsLeft(now, skill)
    local fisher = RG.Skill("Fishing") ~= nil
    local best, bestScore
    for _, o in ipairs(opts) do
      local m = RG.MatsFor(o, res.left)
      if m then
        local short, fishy = 0, false
        for _, e in ipairs(m) do
          if not e.via then short = short + e.short end
          local info = RG.MAT_INFO and RG.MAT_INFO[e.id]
          if info and info[2] == "fish" and e.short > 0 then fishy = true end
        end
        local score = short + ((fishy and not fisher) and 0.5 or 0)
        if not best or score < bestScore then best, bestScore, res.mats = o, score, m end
      end
    end
    res.craft = best or opts[1]
    res.options = opts
  end
  -- the next craft step after this one
  for i = idx + 1, #plan do
    local st = plan[i]
    if not st.train and (st.craft or st.gather or st.skin or st.fish) then res.next = st; break end
  end
  return res
end

-- ---------------------------------------------------------------------------
-- Places to go
-- ---------------------------------------------------------------------------
local CAPITAL = { U = 1458, O = 1454, R = 1454, T = 1456, S = 1456, H = 1453, D = 1455, G = 1455, N = 1457, A = 1453 }
local function playerMap()
  local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  return m
end
-- Spots near you first: the zone you're in, then your continent, then your
-- race's home zones; `extra(w)` adds its own points (e.g. a better level).
local HOME_MAPS = { O = { [1411] = true, [1413] = true }, R = { [1411] = true, [1413] = true }, T = { [1412] = true, [1413] = true },
  U = { [1420] = true, [1421] = true }, S = { [1412] = true, [1413] = true },
  H = { [1429] = true, [1436] = true }, D = { [1426] = true, [1432] = true }, G = { [1426] = true, [1432] = true },
  N = { [1438] = true, [1439] = true }, A = { [2521] = true, [1436] = true } }
local contCache = {}
local function continentOf(map)
  if not map then return nil end
  if contCache[map] ~= nil then return contCache[map] or nil end
  local m, cont = map, false
  for _ = 1, 6 do
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    if not info then break end
    if info.mapType == 2 then cont = m; break end
    m = info.parentMapID
    if not m or m == 0 then break end
  end
  contCache[map] = cont
  return cont or nil
end
function RG.RankSpots(list, extra)
  local here = playerMap()
  local hc = continentOf(here)
  local home = HOME_MAPS[RG.RACE_LETTER] or {}
  local scored = {}
  for i, w in ipairs(list or {}) do
    local sc = (w[1] == here and 100 or 0) + ((hc and continentOf(w[1]) == hc) and 40 or 0) + (home[w[1]] and 25 or 0) + (extra and extra(w) or 0)
    scored[#scored + 1] = { w = w, s = sc, i = i }
  end
  table.sort(scored, function(a, b) if a.s ~= b.s then return a.s > b.s end return a.i < b.i end)
  local out = {}
  for i, e in ipairs(scored) do out[i] = e.w end
  return out
end
local function pickNear(list, filter)
  if not list then return nil end
  local here, home = playerMap(), CAPITAL[RG.RACE_LETTER]
  local first, homeHit
  for _, w in ipairs(list) do
    if not filter or filter(w) then
      if w[1] == here then return w end
      if not homeHit and w[1] == home then homeHit = w end
      first = first or w
    end
  end
  return homeHit or first
end

-- The trainer (with a map pin) for a rank: "Yelmak (Orgrimmar), Doctor Marsh (Undercity)"
function RG.TrainerPin(text)
  if not (text and RG.PROF_TRAINERS) then return nil end
  local list = {}
  for nm in text:gmatch("([A-Z][%a'%.]+[%a'%. ]-) %(") do
    local w = RG.PROF_TRAINERS[nm]
    if w then list[#list + 1] = w end
  end
  for nm in text:gmatch("([A-Z][%a']+ ?[%a']*) in ") do
    local w = RG.PROF_TRAINERS[nm]
    if w then list[#list + 1] = w end
  end
  return pickNear(list)
end

local function lvl() return UnitLevel("player") or 1 end
-- The highest-level beast you can still skin at this skill.
local function skinMax(skill)
  if skill < 100 then return math.floor(10 + skill / 10) end
  return math.floor(skill / 5)
end
RG.SkinMaxLevel = skinMax

-- Best places for one material: { title, sub, wp }
function RG.MatPlaces(id, max)
  max = max or 2
  local out = {}
  local info = RG.MAT_INFO and RG.MAT_INFO[id]
  local kind = info and info[2]
  local name = matName(id)
  local function add(title, sub, wp) if #out < max then out[#out + 1] = { title = title, sub = sub, wp = wp } end end
  if kind == "fish" and RG.MAT_FISH and RG.MAT_FISH[id] then
    for _, zone in ipairs(RG.MAT_FISH[id]) do
      local map = RG.ZONE_MAPS and RG.ZONE_MAPS[zone]
      local pool = map and RG.FISH_SPOTS and RG.FISH_SPOTS[map]
      add("Fish for " .. name, "fish in " .. zone .. (pool and ("  ·  pools: " .. pool[4]) or ""), pool)
      break
    end
  end
  if RG.MAT_VENDORS and RG.MAT_VENDORS[id] then
    local v = pickNear(RG.MAT_VENDORS[id])
    if v then add("Buy " .. name, v[4], v) end
  end
  for _, node in ipairs((RG.MAT_NODES or {})[id] or {}) do
    local spots = RG.GATHER_SPOTS and RG.RankSpots(RG.GATHER_SPOTS[node], function(w) return (tonumber(w[4]:match(": (%d+)")) or 0) / 5 end)
    if spots and spots[1] then add((kind == "herb" and "Pick " or "Mine ") .. node, spots[1][4], spots[1]) end
    break
  end
  local spots = RG.MAT_SPOTS and RG.MAT_SPOTS[id]
  if spots then
    local me = lvl()
    local ok = {}
    for _, s in ipairs(spots) do if (s[5] or 0) <= me + 2 then ok[#ok + 1] = s end end
    -- near you, a level you can handle, and a good drop rate (list order)
    local best = RG.RankSpots(ok, function(w) return math.max(0, 20 - (me - (w[5] or 0))) end)[1] or spots[#spots]
    if best then add((kind == "leather" and "Skin or loot " or "Farm ") .. name, best[4], best) end
  end
  return out, kind
end

-- Places for a profession right now: gathering spots, skinning mobs, fishing
-- pools, material sources for what you're short of, and your next trainer.
function RG.ProfPlaces(name, now)
  now = now or RG.ProfNow(name)
  local out = {}
  if not now or now.done then return out end
  local P, st, skill = now.P, now.st, now.skill
  local function add(title, sub, wp, icon) out[#out + 1] = { title = title, sub = sub, wp = wp, icon = icon } end
  if st.gather then
    for _, node in ipairs({ st.gather, st.also }) do
      for i, s in ipairs(RG.RankSpots((RG.GATHER_SPOTS or {})[node], function(w) return (tonumber(w[4]:match(": (%d+)")) or 0) / 5 end)) do
        if i > 2 then break end
        add((name == "Mining" and "Mine " or "Pick ") .. node, s[4], s)
      end
    end
  elseif name == "Skinning" then
    local top = math.min(skinMax(skill), lvl() + 3)
    local picks = {}
    for _, s in ipairs(RG.SKIN_SPOTS or {}) do
      if s[5] <= top and s[5] >= top - 4 then picks[#picks + 1] = s end
    end
    picks = RG.RankSpots(picks, function(w) return w[5] * 2 end)
    for i = 1, math.min(3, #picks) do add("Skin " .. picks[i][4]:match("^(.-) %(") , picks[i][4], picks[i]) end
  elseif P.fishTab and RG.FISH_ROUTE then
    for _, f in ipairs(RG.FISH_ROUTE) do
      if skill < f.to then
        local map = RG.ZONE_MAPS and RG.ZONE_MAPS[f.zone]
        local pool = map and RG.FISH_SPOTS and RG.FISH_SPOTS[map]
        add("Fish in " .. f.zone, (f.spot or "") .. (pool and (GREY .. "  ·  pools: " .. pool[4] .. "|r") or ""), pool)
        break
      end
    end
  end
  -- materials you're short of
  local shown = 0
  for _, e in ipairs(now.mats or {}) do
    local info = RG.MAT_INFO and RG.MAT_INFO[e.id]
    local crafted = RG.Recipe(e.name) and (not info or info[2] == "crafted")
    if e.short > 0 and not crafted and shown < 4 then
      local places = RG.MatPlaces(e.id, 1)
      if places[1] then
        add(places[1].title, GREY .. e.short .. " more needed  ·  |r" .. places[1].sub, places[1].wp)
        shown = shown + 1
      end
    end
  end
  -- the next trainer
  local T = P.train or {}
  local RANKS = { { "journeyman", 50, 10 }, { "expert", 125, 20 }, { "artisan", 200, 35 } }
  local k = RG.Professions()[name]
  if not k then
    local pin = RG.TrainerPin((T.start and T.start[RG.RACE_LETTER]) or T.apprentice)
    if pin then add("Learn " .. name, pin[4], pin) end
  else
    for _, r in ipairs(RANKS) do
      local kmax = k.max or skill
      if kmax <= r[2] + 25 and kmax < 300 and skill >= r[2] - 15 and T[r[1]] then
        local pin = RG.TrainerPin(T[r[1]])
        if pin then add("Train " .. r[1]:gsub("^%l", string.upper) .. " at " .. pin[4], "skill " .. r[2] .. ", level " .. r[3], pin) end
        break
      end
    end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Events: remember recipes, refresh as you level, and say when a step is done
-- ---------------------------------------------------------------------------
local lastSkill = {}
local f = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "PLAYER_LOGIN" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event)
  if not RG.db then return end
  if event:find("^TRADE") or event:find("^CRAFT") then RG.Debounce("profRead", 0.5, readWindow); return end
  if event == "PLAYER_LOGIN" then
    for n, p in pairs(RG.Professions()) do lastSkill[n] = p.rank end
    return
  end
  -- a skill went up: tell you when a step is finished and what's next
  RG.Debounce("profSkill", 0.5, function()
    for n, p in pairs(RG.Professions()) do
      local before = lastSkill[n]
      lastSkill[n] = p.rank
      local P = RG.PROFESSIONS and RG.PROFESSIONS[n]
      if before and p.rank > before and P and not (RG.IsAlt and RG.IsAlt()) then
        for _, st in ipairs(RG.ProfPlan(P)) do
          if not st.train and before < st.to and p.rank >= st.to then
            local now = RG.ProfNow(n)
            local nxt = now and now.st and (now.craft or now.st.gather or now.st.skin or (now.st.fish and ("fish in " .. now.st.fish)))
            if nxt and RG.Toast then
              RG.Toast(n .. " " .. p.rank, "Step done. Next: " .. nxt .. (now.left and now.left > 0 and (" x" .. now.left) or "") .. ". The Professions tab has the materials and where to go.", P.icon, "Show me", function() if RG.ShowTab then RG.ShowProf(n) end end, 8)
            end
            break
          end
        end
      end
    end
    if RG.RefreshUI then RG.RefreshUI() end
  end)
end)
