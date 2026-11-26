-- Waypath+ guide brain: one "current objective" that the arrow, tracker and window all read,
-- a route planner over your quest log, a requirements checklist, worth-it ratings,
-- "what's near me", your own goals, party sharing and a play-test log.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
local R_NEAR = 70        -- yards: tasks this close to each other share one stop
local RUN = 7            -- yards per second on foot
local ARROWTAG = "|TInterface\\Minimap\\MinimapArrow:12:12|t "
local VERB_ICON = {
  turnin = "|TInterface\\GossipFrame\\ActiveQuestIcon:13:13:0:-1|t ",
  pickup = "|TInterface\\GossipFrame\\AvailableQuestIcon:13:13:0:-1|t ",
  doing = "|TInterface\\Icons\\INV_Sword_27:13:13:0:-1:64:64:5:59:5:59|t ",
  goal = "|TInterface\\Icons\\INV_Misc_Map_01:13:13:0:-1:64:64:5:59:5:59|t ",
}
local ACT_RANK = { turnin = 1, pickup = 2, doing = 3 }

local function opt(k) return RG.Opt and RG.Opt(k) end
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end
local function isDone(id) return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) end
local function inCombat() return InCombatLockdown and InCombatLockdown() end

-- ===========================================================================
-- Play-test log: a short ring buffer of what the guide did and what you did about it
-- ===========================================================================
function RG.Log(ev, a, b)
  if not RG.db then return end
  local l = RG.db.ptlog
  if not l then l = {}; RG.db.ptlog = l end
  l[#l + 1] = { t = time and time() or 0, ev = ev, a = a, b = b, lvl = UnitLevel and UnitLevel("player") or 0,
    z = RG.ZoneName() }
  while #l > 200 do table.remove(l, 1) end
end

local function fmtAgo(t)
  local d = (time and time() or 0) - (t or 0)
  if d < 90 then return d .. "s" elseif d < 5400 then return math.floor(d / 60) .. "m" end
  return string.format("%.1fh", d / 3600)
end
function RG.LogSummary()
  local l = (RG.db and RG.db.ptlog) or {}
  if #l == 0 then return "The play-test log is empty. It fills as you play: arrivals, skips, pins you set yourself, hand-ins." end
  local cnt, arriveSum, arriveN, skips, zones = {}, 0, 0, {}, {}
  for _, e in ipairs(l) do
    cnt[e.ev] = (cnt[e.ev] or 0) + 1
    if e.ev == "arrive" and type(e.b) == "number" then arriveSum = arriveSum + e.b; arriveN = arriveN + 1 end
    if e.ev == "skip" or e.ev == "stepskip" or e.ev == "override" then
      local k = tostring(e.a or "?")
      skips[k] = (skips[k] or 0) + 1
      zones[e.z or "?"] = (zones[e.z or "?"] or 0) + 1
    end
  end
  local out = { string.format("Play-test log  ·  %d entries  ·  v%s", #l, tostring(RG.VERSION or "?")) }
  out[#out + 1] = string.format("Arrivals %d%s  ·  stops skipped %d  ·  steps skipped by hand %d  ·  pins you set yourself %d  ·  hand-ins %d",
    cnt.arrive or 0, arriveN > 0 and string.format(" (average %.0fs from pin to arrival)", arriveSum / arriveN) or "",
    cnt.skip or 0, cnt.stepskip or 0, cnt.override or 0, cnt.turnin or 0)
  local top = {}
  for k, v in pairs(skips) do top[#top + 1] = { k = k, v = v } end
  table.sort(top, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.k < b.k end)
  if #top > 0 then
    out[#out + 1] = "Most skipped or overridden:"
    for i = 1, math.min(5, #top) do out[#out + 1] = string.format("  %dx  %s", top[i].v, top[i].k) end
  end
  local zt = {}
  for k, v in pairs(zones) do zt[#zt + 1] = { k = k, v = v } end
  table.sort(zt, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.k < b.k end)
  if #zt > 0 then
    local p = {}
    for i = 1, math.min(4, #zt) do p[#p + 1] = zt[i].k .. " " .. zt[i].v end
    out[#out + 1] = "Where it went wrong most: " .. table.concat(p, ", ")
  end
  out[#out + 1] = ""
  out[#out + 1] = "Latest:"
  for i = math.max(1, #l - 11), #l do
    local e = l[i]
    out[#out + 1] = string.format("  %s ago  L%d  %s  %s%s%s", fmtAgo(e.t), e.lvl or 0, e.ev, tostring(e.a or ""), e.b and (" · " .. tostring(e.b)) or "", (e.z and e.z ~= "") and ("  [" .. e.z .. "]") or "")
  end
  return table.concat(out, "\n")
end

-- ===========================================================================
-- Worth it: how good a quest is for you right now
-- ===========================================================================
local followers
local function chainAfter(id)
  if not (id and RG.QDATA) then return 0 end
  if not followers then
    followers = {}
    for qid, d in pairs(RG.QDATA) do
      if d.ps then for _, p in ipairs(d.ps) do followers[p] = (followers[p] or 0) + 1 end end
      if d.pg then for _, p in ipairs(d.pg) do followers[p] = (followers[p] or 0) + 1 end end
    end
  end
  return followers[id] or 0
end
-- tag, color, note, rank (4 best .. 0 skip)
function RG.QuestWorth(level, group, id)
  local lvl = UnitLevel("player") or 1
  if not level or level <= 0 then return nil end
  local col = RG.QuestColor(level)
  local tag, c, note, rank
  if col == "|cffff1a1a" then tag, c, rank, note = "Too hard", col, 0, "5 or more levels above you: come back later"
  elseif col == "|cffff8040" then tag, c, rank, note = "Tough", col, 3, "Good XP, but a hard fight"
  elseif col == "|cffffff00" then tag, c, rank, note = "Great", col, 4, "Full XP for your level"
  elseif col == "|cff40c040" then tag, c, rank, note = "Okay", col, 2, "Less XP: fine when it's on your way"
  else tag, c, rank, note = "Skip", col, 0, "Grey: no XP; only worth it for its reward or the chain" end
  local extra = {}
  if group then extra[#extra + 1] = "a group is recommended"; rank = math.max(0, rank - 1) end
  local ch = chainAfter(id)
  if ch > 0 and rank > 0 then extra[#extra + 1] = "opens " .. ch .. " more quest" .. (ch > 1 and "s" or "") end
  if #extra > 0 then note = note .. "; " .. table.concat(extra, "; ") end
  return tag, c, note, rank
end

-- ===========================================================================
-- Requirements: what a quest needs, ticked live
-- ===========================================================================
-- { { text, ok = true|false|nil, kind = "req"|"obj" }, ... }
function RG.QuestRequirements(id)
  local d = id and RG.QDATA and RG.QDATA[id]
  local out = {}
  if not d then return out end
  local lvl = UnitLevel("player") or 1
  local inLog = C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id)
  -- once a quest is in your log its level and earlier quests no longer matter
  if not inLog and (d.r or 1) > 1 then out[#out + 1] = { text = "Level " .. d.r, ok = lvl >= d.r, kind = "req" } end
  if d.pg and not inLog then
    for _, p in ipairs(d.pg) do
      local pd = RG.QDATA[p]
      out[#out + 1] = { text = "Finish " .. ((pd and pd.n) or ("quest " .. p)), ok = isDone(p) and true or false, kind = "req" }
    end
  end
  if d.ps and not inLog then
    local any = false
    for _, p in ipairs(d.ps) do if isDone(p) then any = true end end
    local names = {}
    for i, p in ipairs(d.ps) do local pd = RG.QDATA[p]; if i <= 2 then names[#names + 1] = (pd and pd.n) or tostring(p) end end
    out[#out + 1] = { text = "Finish " .. table.concat(names, " or ") .. (#d.ps > 2 and " or another" or ""), ok = any, kind = "req" }
  end
  -- anything else that keeps the giver from offering it (profession, reputation, a branch you didn't take...)
  if not inLog and not isDone(id) and RG.QuestBlocked then
    local why = RG.QuestBlocked(id, d)
    if why and not why:find("^after ") and not why:find("^at level") then
      out[#out + 1] = { text = (why:gsub("^%l", string.upper)), ok = false, kind = "req" }
    end
  end
  -- objectives: live from the quest log when you have it, else from the database
  if inLog and C_QuestLog.GetQuestObjectives then
    for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
      if o.text and o.text ~= "" then out[#out + 1] = { text = o.text, ok = o.finished and true or false, kind = "obj" } end
    end
  elseif d.o then
    for _, o in ipairs(d.o) do
      local verb = (o[1] == "k" and "Kill ") or (o[1] == "i" and "Collect ") or "Find "
      out[#out + 1] = { text = verb .. (o[2] or "?"), ok = nil, kind = "obj" }
    end
  end
  return out
end

-- One objective as the current step says it: "Kill 15 Hillsbrad Farmers", "9/15" (the progress nil when there's none)
function RG.ObjectiveLine(okind, label, have, need)
  local verb = ({ k = "Kill", i = "Collect", o = "Use" })[okind or ""] or "Get"
  label = tostring(label or "?")
  local many = need and need > 1
  if many and verb == "Kill" and not label:find("s$") then label = label .. "s" end
  return verb .. " " .. (many and (need .. " ") or "") .. label, (have and need and need > 0) and (have .. "/" .. need) or nil
end
-- Every objective of a quest in your log, in the quest log's order, each with its own progress:
-- { { text = "Collect 8 Putrescent Bear Organs", prog = "4/8", done, label, okind }, ... } (the database's name for the
-- thing when it has one; an objective of another kind, a reputation say, keeps the game's words)
function RG.QuestObjectiveLines(id)
  local out = {}
  if not (id and C_QuestLog and C_QuestLog.GetQuestObjectives) then return out end
  local objs = C_QuestLog.GetQuestObjectives(id) or {}
  local qd = RG.QDATA and RG.QDATA[id]
  for _, o in ipairs(objs) do
    if o.text and o.text ~= "" then
      local okind, label
      for k, d in ipairs((qd and qd.o) or {}) do
        if RG.MatchObjective(objs, qd.o, k) == o then okind, label = d[1], d[2] break end
      end
      if not label then
        okind = (o.type == "monster" and "k") or (o.type == "item" and "i") or (o.type == "object" and "o") or nil
        label = RG.ObjKey and RG.ObjKey(o.text) or o.text
        if okind == "k" then label = label:gsub("%s+slain$", "") end
      end
      local text, prog
      if okind then text, prog = RG.ObjectiveLine(okind, label, o.numFulfilled, o.numRequired) else text = o.text end
      out[#out + 1] = { text = text, prog = prog, done = o.finished and true or false, label = label, okind = okind }
    end
  end
  return out
end

-- ===========================================================================
-- The planner: your quest log (and the route's next pick-ups) as an ordered trip
-- ===========================================================================
local skipUntil, skipQuest = {}, {}
function RG.SkipQuest(title) skipQuest[title] = (GetTime and GetTime() or 0) + 600; if RG.MarkObjectiveDirty then RG.MarkObjectiveDirty() end end
local function taskKey(t) return t.act .. ":" .. tostring(t.id or t.title) .. ":" .. tostring(t.label or "") end

local objGroups   -- (see buildTasks)
local ptCache, ptN = {}, 0   -- spot -> its point in world coordinates (a spot never moves); emptied now and then (the game's Lua can't drop entries whose value points back at the key)
local function buildTasks()
  local c, px, py = RG.PlayerWorld()
  if not c then return nil end
  local tasks, elsewhere = {}, 0
  local quests = RG.MyQuests and RG.MyQuests() or {}
  local byTitle = {}
  for _, q in ipairs(quests) do byTitle[q.title] = q end
  -- what the tracker follows decides what the plan may pick (Smart.lua):
  --   zone quests: only what's in that zone (the arrow never leaves it); the guide: only the quests of the step the
  --   tracker shows you're on, so the current step and the route agree (a zone of hand-written steps, with no quest
  --   list: all of yours); your quest log: only your quests
  local mode = RG.RouteMode and RG.RouteMode() or "log"
  local zoneName = mode == "zone" and RG.FollowZone and RG.FollowZone() or nil
  local function inZone(wp) return not zoneName or (wp and RG.MapZone and RG.MapZone(wp[1]) == zoneName) end
  local routeIds
  if mode == "guide" then
    local r0 = RG.CurrentRouteEntry and RG.CurrentRouteEntry()
    local sq = r0 and RG.STEP_QUESTS and RG.STEP_QUESTS[r0.zone .. "|" .. r0.from]
    if sq then
      routeIds = {}
      local cur = RG.NextStep and RG.NextStep(r0)
      -- (the step's quest lines, not just its list: they add a quest you've finished that one of the step's waits on)
      for _, l in ipairs(cur and RG.StepQuestLines and RG.StepQuestLines(r0, cur, quests) or {}) do routeIds[l.id] = true end
      for _, id in ipairs(cur and sq[cur] or {}) do routeIds[id] = true end
    end
  end
  -- preobtaining a dungeon's quests (DungeonPrep.lua): only its chains, and its own quests are picked up and kept
  local prep = RG.TrackerView and RG.TrackerView() == "dungeon" and RG.PrepWork and RG.PrepWork() or nil
  if prep then mode, zoneName, routeIds = "prep", nil, nil end
  local function wanted(q, id, title)
    id = id or (q and q.id)
    if prep then return (id and (prep.full[id] or prep.keep[id])) and true or false end
    if routeIds and not (id and routeIds[id]) then return false end
    -- a dungeon quest while they're left out (one that's finished can still be handed in)
    if not (q and q.complete) and RG.DungeonQuestHidden and RG.DungeonQuestHidden(id, q and q.zone) then return false end
    return true
  end
  local function pt(wp)
    local e = ptCache[wp]
    if e and e.c == c then return e.p end
    local c2, x, y
    if RG.WpWorld then c2, x, y = RG.WpWorld(wp) else c2, x, y = RG.ToWorld(wp[1], wp[2], wp[3]) end
    if c2 == c and x then
      local p = { x = x, y = y, wp = wp }
      if ptN > 4000 then ptCache, ptN = {}, 0 end
      ptN = ptN + 1; ptCache[wp] = { c = c, p = p }
      return p
    end
  end
  -- objectives still to do (kill, collect, use): one task per objective, any of its spots will do
  -- (grouping every known quest spot and turning each into world coordinates made most of this function's garbage and none of it
  -- depends on where you stand: it is kept for as long as the list of spots is the same one, on the same continent)
  local spots = RG.QuestSpots and RG.QuestSpots() or {}
  local order
  if objGroups and objGroups.spots == spots and objGroups.c == c then order = objGroups.order
  else
    local groups = {}
    order = {}
    for _, sp in ipairs(spots) do
      if not sp.turnin then
        local k = sp.quest .. "\0" .. tostring(sp.label)
        local g = groups[k]
        if not g then
          g = { quest = sp.quest, label = sp.label, pts = {}, have = sp.have, need = sp.need, okind = sp.okind }
          groups[k] = g; order[#order + 1] = g
        end
        local p = pt(sp.wp)
        if p then
          -- one spot per 6-yard square is enough (a mob camp lists dozens a few steps apart, and every one of them was weighed
          -- against every other in each round of the plan; 6 yards is well inside the arrival distance)
          local ck = math.floor(p.x / 6) * 65536 + math.floor(p.y / 6)
          local seen = g.seen
          if not seen then seen = {}; g.seen = seen end
          if not seen[ck] then seen[ck] = true; g.pts[#g.pts + 1] = p end
        else g.off = true end
      end
    end
    objGroups = { spots = spots, c = c, order = order }
  end
  local objOf = {}
  for _, g in ipairs(order) do
    local q = byTitle[g.quest]
    local pts = g.pts
    if zoneName and #pts > 0 then
      pts = {}
      for _, p in ipairs(g.pts) do if inZone(p.wp) then pts[#pts + 1] = p end end
    end
    if not wanted(q, nil, g.quest) or (prep and q and prep.keep[q.id] and not (RG.PrepObjectiveBefore and RG.PrepObjectiveBefore(q.id, g.label))) then
      -- (left out on purpose: not counted as somewhere else; a dungeon's own quest waits for the run, except an
      -- objective that has nothing to do with its mobs)
    elseif #pts > 0 then
      local t = { act = "doing", title = g.quest, id = q and q.id, label = g.label, pts = pts, level = q and q.level, group = q and q.group, have = g.have, need = g.need, okind = g.okind }
      tasks[#tasks + 1] = t
      objOf[g.quest] = objOf[g.quest] or {}
      table.insert(objOf[g.quest], t)
    else elsewhere = elsewhere + 1 end
  end
  -- hand-ins: ready quests now, the rest after their objectives
  for _, q in ipairs(quests) do
    local qd = q.id and RG.QDATA and RG.QDATA[q.id]
    local ewp
    if qd and qd.e and qd.e[1] then ewp = { qd.e[1], qd.e[2], qd.e[3], (qd.e[4] and qd.e[4] ~= "") and qd.e[4] or q.title }
    elseif q.complete and q.wp then ewp = q.wp end   -- not in our data: where the game says to hand it in
    if ewp and wanted(q) and inZone(ewp) and not (prep and q.id and prep.keep[q.id]) then
      local p = pt(ewp)
      if p and (q.complete or objOf[q.title]) then
        tasks[#tasks + 1] = { act = "turnin", title = q.title, id = q.id, label = ewp[4], pts = { p }, level = q.level, group = q.group,
          deps = (not q.complete) and objOf[q.title] or nil }
      elseif not p and q.complete then elsewhere = elsewhere + 1 end
    end
  end
  -- the route's pick-ups, so a giver on your way gets bundled with the rest: the guide, those of the step the tracker
  -- shows you're on; zone quests, those of every step of the zone still open (it plans the whole zone, so walking
  -- into a town with quests to pick up has you pick them up)
  local r = mode ~= "log" and mode ~= "prep" and opt("routeGuide") and RG.CurrentRouteEntry and RG.CurrentRouteEntry()
  local cur = r and RG.STEPS and RG.StepQuestLines and RG.NextStep and RG.NextStep(r)
  if cur then
    local nSteps = #(RG.STEPS[r.zone .. "|" .. r.from] or {})
    local picked = {}
    for i = (mode == "zone" and 1 or cur), (mode == "zone" and nSteps or cur) do
      if i == cur or not RG.StepIsDone(r, i) then
        for _, l in ipairs(RG.StepQuestLines(r, i, quests) or {}) do
          if l.act == "pickup" and l.wp and not picked[l.id] and not byTitle[l.name] and inZone(l.wp) then
            local p = pt(l.wp)
            if p then picked[l.id] = true; tasks[#tasks + 1] = { act = "pickup", title = l.name, id = l.id, label = l.npc, pts = { p }, level = l.level } end
          end
        end
      end
    end
  end
  -- the dungeon's chains: their quests to pick up
  if prep then
    for _, pk in ipairs(prep.pickups) do
      if not byTitle[pk.name] then
        local p = pt(pk.wp)
        if p then tasks[#tasks + 1] = { act = "pickup", title = pk.name, id = pk.id, label = pk.label, pts = { p }, level = pk.level } end
      end
    end
  end
  -- worthwhile quests just around you, even when the route has not reached them yet (not for the guide, which keeps to
  -- its route, nor for your quest log, which keeps to what you have)
  if mode ~= "prep" and (mode == "zone" or not opt("routeGuide")) then
  if RG.Opt("newQuests") and RG.NearbyNewQuests then
    local have = {}
    for _, t in ipairs(tasks) do have[t.title] = true end
    local added = 0
    for _, q in ipairs(RG.NearbyNewQuests(6, true)) do
      if added >= 3 then break end
      if not have[q.name] and not byTitle[q.name] and (q.dist or 99999) <= 900 then
        local p = pt(q.wp)
        if p and inZone(q.wp) and not (RG.DungeonQuestHidden and RG.DungeonQuestHidden(q.id)) then tasks[#tasks + 1] = { act = "pickup", title = q.name, id = q.id, label = q.giver, pts = { p }, level = q.lvl }; have[q.name] = true; added = added + 1 end
      end
    end
  end
  end
  return tasks, elsewhere, c, px, py
end

-- how much a task is worth to you: XP-giving quests of your level first, grey ones last
local WORTH_W = { [0] = 0.2, [1] = 0.45, [2] = 0.7, [3] = 0.95, [4] = 1.15 }
local function taskWeight(t)
  local w = 1
  if t.level and RG.QuestWorth then
    local _, _, _, rank = RG.QuestWorth(t.level, t.group, t.id)
    w = WORTH_W[rank or 2] or 1
  end
  if t.act == "turnin" then return math.max(0.8, w * 1.5) end   -- hand-ins bank the XP and open the next quest
  if t.act == "pickup" then return w * 0.85 end
  return w
end

local function planFromTasks(tasks, px, py)
  local stops, total = {}, 0
  local pending = {}
  local now = GetTime and GetTime() or 0
  -- (what a task is worth and whether you skipped it do not change while planning: worked out once, not per spot and per round)
  for _, t in ipairs(tasks) do
    t.done = false; pending[#pending + 1] = t
    t._w = taskWeight(t)
    t._sk = (skipUntil[taskKey(t)] or 0) > now or (skipQuest[t.title] or 0) > now
  end
  local R2 = R_NEAR * R_NEAR
  -- is (ax,ay) within R_NEAR of (bx,by)? Squared, and only the borderline cases take the square root, so the answers are the same
  local function near(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    local d2 = dx * dx + dy * dy
    if d2 < R2 * 0.999999999 then return true end
    if d2 > R2 * 1.000000001 then return false end
    return math.sqrt(d2) <= R_NEAR
  end
  -- which tasks have a spot close to each spot, in task order: found once, since only "is that task still ready" changes between rounds
  -- (spots are filed in a grid of R_NEAR-yard cells so only the neighbouring cells are compared)
  local cells, nearTasks = {}, {}
  for i, t in ipairs(tasks) do
    t._i = i
    for _, p in ipairs(t.pts) do
      local k = math.floor(p.x / R_NEAR) * 65536 + math.floor(p.y / R_NEAR)
      local c = cells[k]; if not c then c = {}; cells[k] = c end
      c[#c + 1] = { p, t }
    end
  end
  local stamp, mark = 0, {}
  for _, t in ipairs(tasks) do
    for _, p in ipairs(t.pts) do
      stamp = stamp + 1
      local list = {}
      local gx, gy = math.floor(p.x / R_NEAR), math.floor(p.y / R_NEAR)
      for ix = gx - 1, gx + 1 do
        for iy = gy - 1, gy + 1 do
          local c = cells[ix * 65536 + iy]
          if c then
            for _, e in ipairs(c) do
              local u = e[2]
              if mark[u] ~= stamp and near(p.x, p.y, e[1].x, e[1].y) then mark[u] = stamp; list[#list + 1] = u end
            end
          end
        end
      end
      if #list > 1 then table.sort(list, function(a, b) return a._i < b._i end) end
      nearTasks[p] = list
    end
  end
  local function ready(t)
    if t.done then return false end
    if t.deps then for _, d in ipairs(t.deps) do if not d.done then return false end end end
    return true
  end
  -- The rule of thumb: from (cx, cy), the spot that's cheapest for what's done there (a spot where several tasks wait
  -- counts for each of them; a quest worth more XP counts for more; a skipped one goes last). With k: also the k
  -- cheapest different spots in cand[1..n] (cand[1] the cheapest), plus the nearest spot not skipped.
  local function cheapest(cx, cy, k, cand, candC)
    local n, nearest, nearD, best, bestCost = 0, nil, nil, nil, nil
    for _, t in ipairs(pending) do
      if ready(t) then
        local w, extra = t._w, t._sk and 20000 or 0
        for _, p in ipairs(t.pts) do
          local d = dist(cx, cy, p.x, p.y)
          local cover = 0
          for _, u in ipairs(nearTasks[p]) do if ready(u) then cover = cover + 1 end end
          local cost = (d + 40) / math.max(1, cover) / w + extra
          if not bestCost or cost < bestCost then best, bestCost = p, cost end
          if k then
            if not t._sk and (not nearD or d < nearD) then nearest, nearD = p, d end
            -- (kept sorted, k at most; a spot at the same place as one already kept is the same stop)
            local same = false
            for i = 1, n do if math.abs(cand[i].x - p.x) < 1 and math.abs(cand[i].y - p.y) < 1 then same = i break end end
            if same then
              if cost < candC[same] then cand[same], candC[same] = p, cost end
            elseif n < k or cost < candC[n] then
              if n < k then n = n + 1 end
              cand[n], candC[n] = p, cost
            end
            for i = 2, n do
              local j = i
              while j > 1 and candC[j] < candC[j - 1] do
                cand[j], cand[j - 1], candC[j], candC[j - 1] = cand[j - 1], cand[j], candC[j - 1], candC[j]
                j = j - 1
              end
            end
          end
        end
      end
    end
    if k and nearest then
      local have = false
      for i = 1, n do if cand[i] == nearest then have = true end end
      if not have then n = n + 1; cand[n], candC[n] = nearest, math.huge end
    end
    return best, n
  end
  -- everything ready at spot p is done there: the tasks (added to marked), and 20000 yards' worth when one was skipped
  local function visit(p, marked)
    local first, pen = #marked + 1, 0
    for _, u in ipairs(nearTasks[p]) do if ready(u) then marked[#marked + 1] = u end end
    for i = first, #marked do marked[i].done = true; if marked[i]._sk then pen = 20000 end end
    return pen
  end
  -- the walk that's left from (cx, cy) following the rule of thumb to the end (then everything is put back as it was)
  local function rollout(cx, cy)
    local marked, walk = {}, 0
    for _ = 1, 60 do
      local p = cheapest(cx, cy)
      if not p then break end
      walk = walk + dist(cx, cy, p.x, p.y) + visit(p, marked)
      cx, cy = p.x, p.y
    end
    for _, u in ipairs(marked) do u.done = false end
    return walk
  end
  -- The first few stops (the current step and the next ones the tracker lists) look at the whole trip: each of the
  -- best few next spots is tried, the rest of the trip finished from it by the rule of thumb, and the spot with the
  -- least walking in all is taken. So a camp of four objectives a long way off doesn't come before a quick one close
  -- by, and a hand-in on the way is done on the way. (Further stops: the rule of thumb alone, as the list moves on.)
  local LOOK, K = 3, (#tasks > 40 and 3 or 4)
  local cand, candC = {}, {}
  local cx, cy = px, py
  for round = 1, 60 do
    local bestPt, n
    if round <= LOOK then
      bestPt, n = cheapest(cx, cy, K, cand, candC)
      if n > 1 then
        local bestTotal
        for i = 1, n do
          local p, marked = cand[i], {}
          local tot = dist(cx, cy, p.x, p.y) + visit(p, marked)
          tot = tot + rollout(p.x, p.y)
          for _, u in ipairs(marked) do u.done = false end
          -- (the rule of thumb's own pick, tried first, keeps a tie)
          if not bestTotal or tot < bestTotal - 1 then bestTotal, bestPt = tot, p end
        end
      end
    else bestPt = cheapest(cx, cy) end
    if not bestPt then break end
    local items = {}
    visit(bestPt, items)
    table.sort(items, function(a, b)
      if a.act ~= b.act then return ACT_RANK[a.act] < ACT_RANK[b.act] end
      return (a.title or "") < (b.title or "")
    end)
    local d = dist(cx, cy, bestPt.x, bestPt.y)
    total = total + d
    stops[#stops + 1] = { items = items, x = bestPt.x, y = bestPt.y, wp = bestPt.wp, dist = d, pd = dist(px, py, bestPt.x, bestPt.y), act = items[1].act, key = taskKey(items[1]) }
    cx, cy = bestPt.x, bestPt.y
    local rest = {}
    for _, t in ipairs(pending) do if not t.done then rest[#rest + 1] = t end end
    pending = rest
    if #pending == 0 then break end
  end
  return stops, total
end

-- ---------------------------------------------------------------------------
-- Describing a stop
-- ---------------------------------------------------------------------------
local function itemText(it, short)
  if it.act == "turnin" then return "Hand in " .. it.title .. ((not short and it.label and it.label ~= "") and (" to " .. it.label) or "") end
  if it.act == "pickup" then return "Pick up " .. it.title .. ((not short and it.label and it.label ~= "") and (" from " .. it.label) or "") end
  local prog = (it.have and it.need and it.need > 0) and (" (" .. it.have .. "/" .. it.need .. ")") or ""
  return tostring(it.label or it.title) .. prog .. (short and "" or (" for " .. it.title))
end
local function stopText(stop, short)
  local t = itemText(stop.items[1], short)
  if #stop.items > 1 then t = t .. (short and "" or ("  +" .. (#stop.items - 1) .. " more here")) end
  return t
end

RG.StopText = stopText
local function stopWhy(stop, prev)
  local it = stop.items[1]
  local bits = {}
  if it.act == "turnin" then bits[#bits + 1] = "Quest complete: hand it in" .. ((it.label and it.label ~= "") and (" to " .. it.label) or "")
  elseif it.act == "pickup" then bits[#bits + 1] = "Next quest on your route" .. ((it.label and it.label ~= "") and (", from " .. it.label) or "")
  else bits[#bits + 1] = "Closest spot to finish an objective in your log" end
  if #stop.items > 1 then
    local names = {}
    for i = 2, math.min(#stop.items, 4) do names[#names + 1] = itemText(stop.items[i], true) end
    bits[#bits + 1] = "also here: " .. table.concat(names, ", ") .. (#stop.items > 4 and ", ..." or "")
  end
  if stop.pd then bits[#bits + 1] = RG.FormatYards(math.floor(stop.pd)) .. " away" end
  return table.concat(bits, "  ·  ")
end

-- ---------------------------------------------------------------------------
-- The shared objective
-- ---------------------------------------------------------------------------
local cache = { dirty = true, t = -99 }
local lastObjKey, objSince

-- A stop you picked yourself (a quest or step clicked on the tracker): it's the current step for 3 minutes whatever the
-- plan says; then only while you're on your way (closer than a minute ago) or there (working on it). Done, or
-- turned off: back to the plan.
local MANUAL_HOLD, MANUAL_IDLE, MANUAL_THERE = 180, 60, 100
local manual
function RG.PickManually(wp)
  manual = wp and { wp = wp, t = GetTime and GetTime() or 0 } or nil
  -- (and the plan doesn't hold on to the stop you were heading to: a new pick, or back to what the plan says)
  cache.obj = nil; cache.dirty = true
end
local function sameSpot(a, b) return a and b and a[1] == b[1] and math.abs((a[2] or 0) - (b[2] or 0)) < 0.15 and math.abs((a[3] or 0) - (b[3] or 0)) < 0.15 end
-- the plan's stop you picked (its index), or nil and how far away it is (nil when there's no pick, or it has run out)
local function manualStop(stops, c, px, py)
  local m = manual
  if not m then return nil end
  local now = GetTime and GetTime() or 0
  local c2, mx, my = RG.ToWorld(m.wp[1], m.wp[2], m.wp[3])
  local d = (c2 and c and c2 == c and px) and dist(px, py, mx, my) or nil
  if d then
    if not m.best or d < m.best - 25 then m.best, m.bestT = d, now end
    if d <= MANUAL_THERE then m.bestT = now end
  end
  if now - m.t > MANUAL_HOLD and now - (m.bestT or m.t) > MANUAL_IDLE then manual = nil; cache.obj = nil return nil end
  -- the stop at that spot, or with a task at it (a quest's objective spot, its giver), else the stop nearest it
  local nearI, nearD
  for i, s in ipairs(stops) do
    if sameSpot(s.wp, m.wp) then m.matched = true return i, d end
    for _, it in ipairs(s.items) do
      for _, p in ipairs(it.pts or {}) do if sameSpot(p.wp, m.wp) then m.matched = true return i, d end end
    end
    if mx and c2 == c then
      local sd = dist(s.x, s.y, mx, my)
      if sd <= 120 and (not nearD or sd < nearD) then nearI, nearD = i, sd end
    end
  end
  if nearI then m.matched = true return nearI, d end
  -- it was a stop of the plan and isn't any more: done
  if m.matched then manual = nil; cache.obj = nil return nil end
  -- a place, not a stop of the plan (a step's town, a flight master): until you get there
  if d and d <= 25 then manual = nil; cache.obj = nil return nil end
  return false, d
end
local function goals() RG.db.goals = RG.db.goals or {}; return RG.db.goals end

local function buildObjective()
  local obj = { }
  local plan = { stops = {}, total = 0, elsewhere = 0 }
  -- your own goals come first
  local g = RG.db and RG.db.goals and RG.db.goals[1]
  -- planner
  local tasks, elsewhere, c, px, py = buildTasks()
  if tasks then
    plan.stops, plan.total = planFromTasks(tasks, px, py)
    plan.elsewhere = elsewhere or 0
    plan.eta = plan.total / RUN
  end
  cache.plan = plan
  -- in a dungeon the arrow rests; the quest log carries the objectives
  if IsInInstance and select(2, IsInInstance()) and (select(2, IsInInstance()) == "party" or select(2, IsInInstance()) == "raid") then
    local name = GetInstanceInfo and (GetInstanceInfo()) or "the dungeon"
    local here
    for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do
      if not q.complete and q.zone == name then here = q break end
    end
    here = here or (function() for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do if not q.complete then return q end end end)()
    obj.kind, obj.key = "dungeon", "dungeon:" .. tostring(name)
    obj.text = "In " .. tostring(name) .. (here and (": " .. here.title .. (here.prog and (" " .. here.prog) or "")) or ": follow your group")
    obj.why = "Dungeon quests are tracked from your quest log; the arrow rests inside instances."
    obj.id = here and here.id
    obj.reqs = obj.id and RG.QuestRequirements(obj.id) or {}
    obj.count, obj.index = 0, 0
    return obj, plan
  end
  if g then
    obj.kind, obj.key = "goal", "goal:" .. tostring(g[1]) .. ":" .. tostring(g[2]) .. ":" .. tostring(g[3])
    obj.text, obj.wp = g[4] or "Your goal", g
    local n = #RG.db.goals
    obj.why = "Your own goal" .. (n > 1 and ("  ·  " .. (n - 1) .. " more queued") or "")
    local c2, x2, y2 = RG.ToWorld(g[1], g[2], g[3])
    local cc, ax, ay = RG.PlayerWorld()
    if c2 and cc == c2 then obj.dist = dist(ax, ay, x2, y2) end
    obj.reqs = {}
    obj.count, obj.index = n, 1
    return obj, plan
  end
  local stops = plan.stops
  -- a stop you picked yourself
  local mi, md = manualStop(stops, c, px, py)
  if mi == false then
    local m = manual
    obj.kind, obj.key, obj.manual = "pick", "pick:" .. m.wp[1] .. ":" .. m.wp[2] .. ":" .. m.wp[3], true
    obj.text = "Head to " .. tostring(m.wp[4] or "your pick")
    obj.wp, obj.dist, obj.reqs = m.wp, md, {}
    obj.why = "You picked it. The plan picks up again once you're there, or after a while if you go elsewhere"
    obj.count, obj.index = #stops, 0
    if stops[1] then obj.nextText, obj.nextWp = stopText(stops[1], true), stops[1].wp end
    return obj, plan
  end
  if #stops > 0 then
    local pick = 1
    -- keep the stop you were already heading to unless another is clearly closer (one you can do now: not a hand-in
    -- still waiting on its objectives)
    if cache.obj and cache.obj.stopKey then
      for i, s in ipairs(stops) do
        for _, it in ipairs(s.items) do
          if taskKey(it) == cache.obj.stopKey and not it.deps then
            local first = stops[1]
            if i ~= 1 and first.pd and s.pd and not (first.pd < s.pd * 0.5 and s.pd - first.pd > 150) then pick = i end
            break
          end
        end
        if pick ~= 1 then break end
      end
    end
    if mi then pick = mi end
    local s = stops[pick]
    local it = s.items[1]
    obj.kind, obj.act = (it.act == "doing" and "doing" or it.act), it.act
    obj.key = "q:" .. s.key
    obj.stopKey = taskKey(it)
    obj.text, obj.wp, obj.dist, obj.stop = stopText(s), s.wp, s.pd, s
    obj.why = stopWhy(s)
    if mi then obj.manual = true; obj.why = "You picked it  ·  " .. obj.why end
    -- the tracker's top line: the quest, and the one thing to do for it ("Kill 15 Hillsbrad Farmers  9/15")
    obj.qtitle = it.title
    if it.act == "turnin" then obj.qline = "Hand in" .. ((it.label and it.label ~= "") and (" to " .. it.label) or "")
    elseif it.act == "pickup" then obj.qline = "Pick up" .. ((it.label and it.label ~= "") and (" from " .. it.label) or "")
    else
      local text, prog = RG.ObjectiveLine(it.okind, it.label or it.title, it.have, it.need)
      obj.qline = text .. (prog and ("  " .. prog) or "")
    end
    obj.id = it.id
    obj.level, obj.group = it.level, it.group
    obj.reqs = it.id and RG.QuestRequirements(it.id) or {}
    obj.tag, obj.tagColor, obj.tagNote, obj.rank = RG.QuestWorth(it.level, it.group, it.id)
    obj.count, obj.index = #stops, pick
    if stops[pick + 1] then obj.nextText, obj.nextWp = stopText(stops[pick + 1], true), stops[pick + 1].wp
    elseif pick > 1 then obj.nextText, obj.nextWp = stopText(stops[1], true), stops[1].wp end
    return obj, plan
  end
  -- preobtaining a dungeon's quests, nothing to go and do right now: how it stands
  if RG.TrackerView and RG.TrackerView() == "dungeon" and RG.PrepPlan then
    local pl = RG.PrepPlan()
    obj.kind, obj.key = "prep", "prep:" .. tostring(pl.name)
    obj.text = RG.PrepSummary(pl)
    obj.why = pl.ready and ("Every quest for " .. tostring(pl.name) .. " you can get before the run is in your log.")
      or (pl.waiting > 0 and (pl.waiting .. " wait for a level or an earlier quest.") or "Nothing to go and do right now.")
    obj.reqs, obj.count, obj.index = {}, 0, 0
    return obj, plan
  end
  -- nothing in the log to plan: the route's hub for this step
  local r = opt("routeGuide") and RG.CurrentRouteEntry and RG.CurrentRouteEntry()
  if r and RG.STEPS then
    local steps = RG.STEPS[r.zone .. "|" .. r.from] or {}
    local nx = RG.NextStep and RG.NextStep(r)
    for i = 1, #steps do
      if i == (nx or i) and not RG.StepIsDone(r, i) then
        local wp = RG.StepWaypoint and RG.StepWaypoint(r, i)
        if wp then
          local place = steps[i]:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^At (.-) %(") or wp[4] or r.zone
          obj.kind, obj.key = "route", "route:" .. r.zone .. "|" .. r.from .. "#" .. i
          obj.text = "Head to " .. place:gsub("^the ", "The ", 1)
          obj.wp, obj.reqs = wp, {}
          obj.why = "Next step of your " .. r.zone .. " route; its quests start here."
          obj.count, obj.index = 1, 1
          local c2, x2, y2 = RG.ToWorld(wp[1], wp[2], wp[3])
          local cc, ax, ay = RG.PlayerWorld()
          if c2 and cc == c2 then obj.dist = dist(ax, ay, x2, y2) end
          return obj, plan
        end
        break
      end
    end
  end
  return nil, plan
end

local shared
local function announce(obj)
  if not (opt("shareObjective") and obj and obj.wp and IsInGroup and IsInGroup()) then return end
  local key = obj.key
  if shared == key then return end
  shared = key
  local msg = table.concat({ "O", obj.wp[1], obj.wp[2], obj.wp[3], (obj.text or ""):sub(1, 80) }, "|")
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    pcall(C_ChatInfo.SendAddonMessage, "WPOBJ", msg, (IsInRaid and IsInRaid()) and "RAID" or "PARTY")
  end
end

-- Keep the arrow on the objective (or leave a pin you placed yourself alone).
local lastOverride
function RG.SyncObjective(obj)
  obj = obj or cache.obj
  if not obj then return end
  if obj.key ~= lastObjKey then
    lastObjKey = obj.key; objSince = GetTime and GetTime() or 0
    announce(obj)
  end
  -- the arrow switched off for one step (RG.ArrowOff) comes back by itself for the next
  local paused = RG.db and RG.db.arrowPaused
  if paused == true then RG.db.arrowPaused = obj.key
  elseif paused and paused ~= obj.key and not (RG.CorpseRun and RG.CorpseRun()) then RG.db.arrowPaused = nil end
  if not obj.wp or (IsInInstance and IsInInstance()) then return end
  if not (opt("arrow") and (opt("autoArrow") or obj.kind == "goal")) then return end
  if RG.ArrowPaused and RG.ArrowPaused() then return end
  if obj.kind == "goal" then
    if obj.pinned ~= obj.key and cache.pinnedGoal ~= obj.key then
      cache.pinnedGoal = obj.key
      RG.PinWaypoint(obj.wp, true)
    end
    return
  end
  if not opt("smartPlan") then return end
  if RG.HasPin and RG.HasPin() and RG.PinIsOurs and not RG.PinIsOurs() then
    if lastOverride ~= obj.key then lastOverride = obj.key; RG.Log("override", obj.text) end
  end
  if RG.AutoPin then RG.AutoPin("obj:" .. obj.key, obj.wp) end
end

-- The current objective (recomputed at most every couple of seconds, or at once after a change).
function RG.Objective(force)
  if not (RG.db and UnitLevel) then return nil end
  local now = GetTime and GetTime() or 0
  if force or cache.dirty or now - cache.t > 2 then
    local ok, obj = pcall(buildObjective)
    cache.t, cache.dirty = now, false
    if ok then
      cache.obj = obj
    else cache.obj = nil; RG.lastGuideError = obj end
  end
  return cache.obj
end
function RG.MarkObjectiveDirty() cache.dirty = true end
-- The arrow's target is a hunting area (a kill, loot or use objective): how close counts as "there", in yards.
function RG.ObjectiveArea(map, x, y)
  local o = cache.obj
  if not (o and o.act == "doing" and o.wp and o.wp[1] == map) then return nil end
  if math.abs((o.wp[2] or 0) - x) > 0.6 or math.abs((o.wp[3] or 0) - y) > 0.6 then return nil end
  local it = o.stop and o.stop.items and o.stop.items[1]
  if it and it.okind == "o" then return 15 end   -- an object to use: closer
  return 45
end
function RG.GuidePlan() RG.Objective(); return cache.plan end
function RG.GuideReset() cache = { dirty = true, t = -99 }; lastObjKey = nil; skipUntil = {}; skipQuest = {} end

-- Skip the current stop for a while (Next key, right-click in the plan).
function RG.SkipStop(stop)
  if not stop then return end
  local until_ = (GetTime and GetTime() or 0) + 3600   -- an hour: a skipped stop should not come straight back
  local keys = {}
  for _, it in ipairs(stop.items) do skipUntil[taskKey(it)] = until_; keys[#keys + 1] = taskKey(it) end
  RG.lastStopSkip = { keys = keys, text = stopText(stop, true), t = time and time() or 0 }
  RG.Log("skip", stopText(stop, true))
  cache.obj = nil; cache.dirty = true
end
-- /wp undo: the stop skipped last comes back. Returns what it was.
function RG.UnskipStop()
  local l = RG.lastStopSkip
  if not l then return nil end
  for _, k in ipairs(l.keys) do skipUntil[k] = nil end
  RG.lastStopSkip = nil
  cache.obj = nil; cache.dirty = true
  if RG.RefreshTracker then RG.RefreshTracker() end
  return l.text
end

-- One key that does the useful thing: point at the objective, or move on to the next one.
function RG.SmartNext()
  local obj = RG.Objective(true)
  if not obj then RG.Print("Nothing planned yet. Accept a quest, or add your own goal with " .. GOLD .. "/wp goto 45 60 Name|r.") return end
  if not obj.wp then RG.Notify(obj.text); return end
  local targeting = RG.ArrowTarget and RG.ArrowTarget(obj.wp)
  if targeting and obj.stop and obj.count and obj.count > 1 then
    RG.SkipStop(obj.stop)
    obj = RG.Objective(true)
    if not obj or not obj.wp then return end
    RG.Follow(obj.wp)
    RG.Notify("Next: " .. obj.text)
  elseif targeting and obj.kind == "goal" then
    RG.Notify("Heading to " .. obj.text)
  else
    RG.Follow(obj.wp)
    RG.Notify((obj.index and obj.count and obj.count > 1) and (obj.text .. "  (" .. obj.index .. " of " .. obj.count .. ")") or obj.text)
  end
  if RG.RefreshTracker then RG.RefreshTracker() end
  if RG.RefreshUI then RG.RefreshUI() end
end

-- ===========================================================================
-- Your own goals (works anywhere, including zones with no quest data)
-- ===========================================================================
function RG.AddGoal(wp)
  local g = goals()
  g[#g + 1] = wp
  while #g > 12 do table.remove(g, 1) end
  cache.dirty = true; cache.pinnedGoal = nil
  RG.SyncObjective(RG.Objective(true))
  if RG.RefreshTracker then RG.RefreshTracker() end
  if RG.RefreshUI then RG.RefreshUI() end
end
function RG.RemoveGoal(i)
  local g = goals()
  table.remove(g, i or 1)
  cache.dirty = true; cache.pinnedGoal = nil
  if #g == 0 and RG.ClearWaypoint then RG.ClearWaypoint() end
  lastObjKey = nil
  RG.SyncObjective(RG.Objective(true))
  if RG.RefreshTracker then RG.RefreshTracker() end
  if RG.RefreshUI then RG.RefreshUI() end
end
local function goalSlash(rest)
  rest = rest or ""
  local low = rest:lower()
  if low == "" or low == "list" then
    local g = goals()
    if #g == 0 then RG.Print("No goals yet. " .. GOLD .. "/wp goto 45.2 60.8 Camp|r adds one in this zone, " .. GOLD .. "/wp goto pin|r turns your map pin into one.") return end
    for i, w in ipairs(g) do RG.Print(i .. ". " .. tostring(w[4]) .. GREY .. string.format("  (%.0f, %.0f)", w[2], w[3]) .. "|r") end
    return
  elseif low == "clear" then
    RG.db.goals = {}; cache.dirty = true; cache.pinnedGoal = nil; lastObjKey = nil
    if RG.ClearWaypoint then RG.ClearWaypoint() end
    RG.Print("Goals cleared."); if RG.RefreshTracker then RG.RefreshTracker() end
    return
  elseif low == "done" or low == "skip" or low == "next" then
    if #goals() > 0 then RG.RemoveGoal(1); RG.Print("Goal done.") else RG.Print("No goals.") end
    return
  elseif low == "pin" then
    local wp = C_Map and C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    if not wp then RG.Print("Put a pin on the map first (right-click the map, or " .. GOLD .. "/wp way x y|r).") return end
    RG.AddGoal({ wp.uiMapID, wp.position.x * 100, wp.position.y * 100, "My pin" })
    RG.Print("Goal added from your map pin.")
    return
  end
  local x, y, name = rest:match("^([%d%.]+)[,%s]+([%d%.]+)%s*(.*)$")
  if not (x and y) then RG.Print("Usage: " .. GOLD .. "/wp goto 45.2 60.8 Name|r  ·  " .. GOLD .. "/wp goto pin|r  ·  " .. GOLD .. "/wp goto list|r  ·  " .. GOLD .. "/wp goto done|r  ·  " .. GOLD .. "/wp goto clear|r") return end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map then RG.Print("Can't tell which zone you're in.") return end
  if name == "" then name = string.format("%s %.0f, %.0f", (C_Map.GetMapInfo and C_Map.GetMapInfo(map) and C_Map.GetMapInfo(map).name) or "Goal", tonumber(x), tonumber(y)) end
  RG.AddGoal({ map, tonumber(x), tonumber(y), name })
  RG.Print("Goal added: " .. GOLD .. name .. "|r. The arrow follows your goals one at a time.")
end

-- reached a goal / log an arrival
function RG.OnArrive(label)
  local o = cache.obj
  RG.Log("arrive", (o and o.text) or label, objSince and math.floor((GetTime() - objSince) + 0.5) or nil)
  if o and o.kind == "goal" then
    local k = o.key
    C_Timer.After(0.5, function()
      if RG.db and RG.db.goals and #RG.db.goals > 0 and cache.obj and cache.obj.key == k then RG.RemoveGoal(1) end
    end)
  end
end

-- ===========================================================================
-- What's worth doing near me
-- ===========================================================================
function RG.WhatsNear(radius)
  radius = radius or 500
  local plan = RG.GuidePlan() or { stops = {} }
  local out, seen = {}, {}
  for _, s in ipairs(plan.stops) do
    for _, it in ipairs(s.items) do
      local k = taskKey(it)
      if not seen[k] then
        seen[k] = true
        local tag, col, note, rank = RG.QuestWorth(it.level, it.group, it.id)
        out[#out + 1] = { text = itemText(it, true), title = it.title, act = it.act, wp = s.wp, dist = s.pd or 0, tag = tag, color = col, note = note, rank = rank or 0, level = it.level, stop = s }
      end
    end
  end
  -- quest givers close by that the route has not asked for yet
  local newQ = RG.NearbyNewQuests and RG.NearbyNewQuests(8) or {}
  for _, q in ipairs(newQ) do
    local k = "new:" .. tostring(q.id or q.name)
    if not seen[k] and q.wp then
      seen[k] = true
      local tag, col, note, rank = RG.QuestWorth(q.lvl, nil, q.id)
      out[#out + 1] = { text = "Pick up " .. q.name .. (q.giver and (" from " .. q.giver) or ""), title = q.name, act = "pickup", wp = q.wp, dist = q.dist or 0, tag = tag, color = col, note = note, rank = rank or 0, level = q.lvl }
    end
  end
  table.sort(out, function(a, b)
    local aw, bw = (a.rank or 0) > 0, (b.rank or 0) > 0
    local ac = (a.dist or 0) <= radius and aw
    local bc = (b.dist or 0) <= radius and bw
    if ac ~= bc then return ac end
    return (a.dist or 0) < (b.dist or 0)
  end)
  return out
end

-- ===========================================================================
-- Minimal tracker preset
-- ===========================================================================
local MIN_FOLD = { quests = true, new = true, route = true, profs = true, reminders = true, fishing = true, upgrade = true }
function RG.SetMinimal(on)
  if on == nil then on = not RG.db.minimal end
  if on and not RG.db.minimal then
    RG.db.foldBefore = RG.db.trackerFold or {}
    local f = {}
    for k, v in pairs(RG.db.foldBefore) do f[k] = v end
    for k in pairs(MIN_FOLD) do f[k] = true end
    RG.db.trackerFold = f; RG.db.minimal = true
  elseif not on and RG.db.minimal then
    RG.db.trackerFold = RG.db.foldBefore or {}; RG.db.foldBefore = nil; RG.db.minimal = nil
  end
  RG.Print("Minimal tracker " .. (RG.db.minimal and "on: just your current objective. " or "off: all sections back. ") .. GOLD .. "/wp minimal|r switches.")
  if RG.RefreshTracker then RG.RefreshTracker() end
end

-- ===========================================================================
-- Tracker block
-- ===========================================================================
local function dtext(d) return d and (GREY .. RG.FormatYards(math.floor(d)) .. "|r") or nil end
function RG.NowLines()
  local obj = RG.Objective()
  local out = {}
  if obj then
    local act = obj.kind == "goal" and "goal" or (obj.act or obj.kind)
    local head = (RG.ArrowTarget and obj.wp and RG.ArrowTarget(obj.wp) and ARROWTAG or "") .. (VERB_ICON[act] or "") .. "|cffffffff" .. obj.text .. "|r"
    local tip = "|cffffffff" .. obj.text .. "|r"
    if obj.why then tip = tip .. "\n" .. GREY .. obj.why .. "|r" end
    if obj.tag then tip = tip .. "\n\n" .. obj.tagColor .. obj.tag .. "|r: " .. (obj.tagNote or "") end
    local lines = {}
    for _, rq in ipairs(obj.reqs or {}) do
      if rq.ok ~= nil or rq.kind == "obj" then lines[#lines + 1] = (rq.ok and GREEN .. "[x] |r" or (rq.ok == false and "[ ] " or "[?] ")) .. rq.text end
    end
    if #lines > 0 then tip = tip .. "\n\n" .. GOLD .. "Needs:|r\n" .. table.concat(lines, "\n", 1, math.min(#lines, 8)) end
    if obj.wp then
      tip = tip .. "\n\n" .. GOLD .. "Click:|r arrow to it\n" .. GOLD .. "Right-click:|r skip to the next stop\n" .. GOLD .. "Double-click:|r arrow on / off\n" .. GOLD .. "Key:|r bind \"Next objective\" in Key Bindings, or /wp next"
    end
    out[#out + 1] = { text = head, opts = { indent = 2, right = dtext(obj.dist), tip = tip, wp = obj.wp,
      menu = function()
        local e = {}
        if obj.wp then e[#e + 1] = { "Arrow to it", function() RG.Follow(obj.wp) end } end
        if obj.stop and obj.count and obj.count > 1 then e[#e + 1] = { "Skip this stop", function() RG.SkipStop(obj.stop); RG.SyncObjective(RG.Objective(true)); RG.RefreshTracker() end } end
        e[#e + 1] = { "Open the quest plan", function() if RG.ShowTab then RG.ShowTab("plan") end end }
        return e, "Now"
      end,
      onClick = function() if obj.wp then RG.Follow(obj.wp) end end,
      onRightClick = (obj.stop and obj.count and obj.count > 1) and function() RG.SkipStop(obj.stop); RG.SyncObjective(RG.Objective(true)); RG.RefreshTracker() end
        or (obj.kind == "goal" and function() RG.RemoveGoal(1) end) or nil } }
    -- how good it is, in a line of its own so the objective can use the full width
    if obj.tag and not (opt("compactTracker") and (obj.tag == "Great" or obj.tag == "Okay")) then   -- compact: say it only when it is a warning
      out[#out + 1] = { text = obj.tagColor .. obj.tag .. "|r" .. GREY .. " · " .. ((obj.tagNote or ""):match("^[^;]*")) .. "|r", opts = { indent = 14, tip = tip, wp = obj.wp,
        onClick = function() if obj.wp then RG.Follow(obj.wp) end end } }
    end
    -- the one thing in the way, or the live objective list
    local shown = 0
    for _, rq in ipairs(obj.reqs or {}) do
      if shown < (opt("compactTracker") and 2 or 3) and ((obj.act == "doing" and rq.kind == "obj") or (obj.act == "pickup" and rq.kind == "req" and rq.ok == false)) then
        shown = shown + 1
        out[#out + 1] = { text = (rq.ok and GREY or "|cffffffff") .. rq.text .. "|r", opts = { single = true, indent = 14, box = rq.ok and true or false } }
      end
    end
    if obj.nextText then
      out[#out + 1] = { text = GREY .. "Then: " .. obj.nextText .. "|r", opts = { indent = 2, wp = obj.nextWp,
        right = (obj.count and obj.count > 1) and (GREY .. (obj.index or 1) .. "/" .. obj.count .. "|r") or nil,
        tip = "Your next stop.\n\n" .. GOLD .. "Double-click:|r arrow to it", onClick = function() if RG.ShowTab then RG.ShowTab("plan") end end } }
    end
    out.right = obj.count and obj.count > 1 and (GREY .. obj.count .. " stops" .. (cache.plan and cache.plan.eta and cache.plan.eta >= 60 and (" · ~" .. math.floor(cache.plan.eta / 60 + 0.5) .. " min") or "") .. "|r") or nil
  end
  -- friends' goals
  if opt("shareObjective") then
    local now = GetTime and GetTime() or 0
    for who, p in pairs(RG.PartyGoals or {}) do
      if now - p.t < 900 then
        out[#out + 1] = { text = GREY .. who .. ": |r|cffffffff" .. p.text .. "|r", opts = { single = true, indent = 2, wp = p.wp,
          tip = who .. "'s current objective.\n\n" .. GOLD .. "Click:|r arrow to it", onClick = function() RG.Follow(p.wp) end } }
      end
    end
  end
  return out
end

-- ===========================================================================
-- Events
-- ===========================================================================
RG.PartyGoals = {}
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
  if event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, "WPOBJ") end
    -- after a reload or login: put the arrow back on what you were doing
    C_Timer.After(4, function() if RG.db then cache.dirty = true; RG.SyncObjective(RG.Objective(true)); if RG.RefreshTracker then RG.RefreshTracker() end end end)
    return
  end
  if event == "CHAT_MSG_ADDON" then
    if a1 == "WPOBJ" and a4 then
      local who = tostring(a4):match("^[^-]+") or tostring(a4)
      if who == (UnitName and UnitName("player")) then return end
      local m, x, y, text = tostring(a2):match("^O|(%d+)|([%d%.]+)|([%d%.]+)|(.*)$")
      if m then RG.PartyGoals[who] = { wp = { tonumber(m), tonumber(x), tonumber(y), who .. ": " .. text }, text = text, t = GetTime() }; if RG.QueueTracker then RG.QueueTracker() end end
    end
    return
  end
  if event == "GROUP_ROSTER_UPDATE" then
    if not (IsInGroup and IsInGroup()) then RG.PartyGoals = {}; shared = nil
    else shared = nil end
    return
  end
  if event == "QUEST_TURNED_IN" then RG.Log("turnin", a1) end
  cache.dirty = true
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    C_Timer.After(1.5, function() cache.dirty = true; if RG.db and not inCombat() then RG.SyncObjective(RG.Objective(true)) end; if RG.QueueTracker then RG.QueueTracker() end end)
  end
end)

-- a slow heartbeat: re-plan as you move, reach goals, keep the arrow honest
local function beat()
  if RG.CardsOnly and RG.CardsOnly() then return end   -- (Cards only: the guide's heartbeat stops; switching back reloads)
  if RG.db and UnitLevel and not (RG.IsAlt and RG.IsAlt()) then
    local ok = pcall(function()
      local obj = RG.Objective()
      if obj and obj.kind == "goal" and obj.wp then
        local c2, x2, y2 = RG.ToWorld(obj.wp[1], obj.wp[2], obj.wp[3])
        local cc, ax, ay = RG.PlayerWorld()
        if c2 and cc == c2 and dist(ax, ay, x2, y2) < 12 then
          RG.Notify("Goal reached: " .. tostring(obj.text))
          RG.Log("arrive", obj.text, objSince and math.floor((GetTime() - objSince) + 0.5) or nil)
          RG.RemoveGoal(1)
          return
        end
      end
      if not inCombat() then RG.SyncObjective(obj) end
    end)
    if not ok then cache.dirty = true end
  end
  C_Timer.After(3, beat)
end
C_Timer.After(6, beat)

-- ===========================================================================
-- Options and slash commands
-- ===========================================================================
table.insert(RG.OPTIONS, { key = "smartPlan", label = "Plan the quest trip (the arrow picks the best next stop)", default = true })
table.insert(RG.OPTIONS, { key = "shareObjective", label = "Share my current objective with my party", default = false })

local function planChat()
  local plan = RG.GuidePlan()
  if not plan or #plan.stops == 0 then RG.Print("No planned stops: accept a quest or add a goal with " .. GOLD .. "/wp goto|r.") return end
  RG.Print(GOLD .. "Quest plan:|r " .. #plan.stops .. " stops" .. (plan.eta and plan.eta >= 60 and (", about " .. math.floor(plan.eta / 60 + 0.5) .. " min on foot") or "") .. (plan.elsewhere > 0 and (", " .. plan.elsewhere .. " task(s) on another continent") or ""))
  for i = 1, math.min(8, #plan.stops) do
    local s = plan.stops[i]
    RG.Print(string.format("%d. %s%s", i, stopText(s), s.dist and (GREY .. "  " .. RG.FormatYards(math.floor(s.dist)) .. "|r") or ""))
  end
end

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
  cmd = cmd and cmd:lower()
  rest = rest or ""
  if cmd == "next" then RG.SmartNext(); return
  elseif cmd == "plan" then
    if rest:lower() == "chat" then planChat() elseif RG.ShowTab then RG.ShowTab("plan") else planChat() end
    return
  elseif cmd == "goto" or cmd == "goal" or cmd == "goals" then goalSlash(rest); return
  elseif cmd == "minimal" or cmd == "mini" then
    local r = rest:lower()
    RG.SetMinimal(r == "on" and true or (r == "off" and false or nil)); return
  elseif cmd == "why" then
    local o = RG.Objective(true)
    if not o then RG.Print("Nothing planned right now.") return end
    RG.Print(GOLD .. "Now:|r " .. o.text)
    if o.why then RG.Print(o.why) end
    if o.tag then RG.Print(o.tagColor .. o.tag .. "|r: " .. (o.tagNote or "")) end
    for _, rq in ipairs(o.reqs or {}) do RG.Print((rq.ok and GREEN .. "[x]|r " or (rq.ok == false and "[ ] " or "[?] ")) .. rq.text) end
    return
  elseif cmd == "near" then
    local list = RG.WhatsNear(500)
    if #list == 0 then RG.Print("Nothing worth doing nearby right now.") return end
    if rest:lower() == "go" then RG.Follow(list[1].wp); RG.Notify(list[1].text); return end
    RG.Print(GOLD .. "Near you:|r " .. GREY .. "(/wp near go points the arrow at the first)|r")
    for i = 1, math.min(6, #list) do
      local e = list[i]
      RG.Print(string.format("%d. %s%s  %s%s|r", i, e.text, GREY .. "  " .. RG.FormatYards(math.floor(e.dist or 0)) .. "|r", e.color or "", e.tag or ""))
    end
    return
  elseif cmd == "share" then
    local r = rest:lower()
    RG.db.shareObjective = (r == "on") or (r ~= "off" and not opt("shareObjective"))
    shared = nil
    RG.Print("Sharing your objective with your party: " .. (RG.db.shareObjective and "on" or "off"))
    if RG.db.shareObjective then announce(RG.Objective()) end
    return
  elseif cmd == "log" then
    local r = rest:lower()
    if r == "clear" then RG.db.ptlog = {}; RG.Print("Play-test log cleared.")
    elseif r == "copy" and RG.ShowErrors then RG.ShowErrors(RG.LogSummary(), "Waypath+ play-test log  ·  Ctrl+A, Ctrl+C to copy")
    else for line in RG.LogSummary():gmatch("[^\n]+") do RG.Print(line) end end
    return
  end
  return base(msg)
end
