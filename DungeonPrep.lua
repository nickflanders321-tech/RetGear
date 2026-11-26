local _, RG = ...
-- Waypath+ preobtain dungeon quests: collect a dungeon's quests before you run it.
-- For the dungeon you pick (the menu at the top of the tracker, or Journey > Dungeon quests), every quest for it that
-- you can still take (RG.DUNGEON_QUESTS), each with the chain of quests that must come first. The tracker then walks
-- you through it: pick up, do and hand in each earlier quest of a chain, then pick up the dungeon's own quest and
-- keep it. The planner (Guide.lua) orders it all by distance, like your quest log.
--   * A dungeon quest's own objectives wait for the run, except ones that have nothing to do with the dungeon's mobs
--     (an object to use, an item that lies about): a normal player runs the dungeon first, and kills the mobs outside
--     only if the drops didn't come.
--   * A quest whose chain goes through another quest done inside the dungeon comes after the run.
--   * Skipping a quest skips its whole chain from there (Journey > Dungeon quests, or right-click on the tracker
--     brings it back).
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY

local function isDone(id) return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) or false end
local function onQuest(id) return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) or false end
local function qd(id) return id and RG.QDATA and RG.QDATA[id] end
local function forMe(d) return d and (not RG.QuestForMe or RG.QuestForMe(d)) end

-- Where you pick a quest up outside: its giver, or an item or poster that lies about (nil: it starts inside a dungeon,
-- or from an item that only drops)
local function pickupWp(d)
  if not d then return nil end
  if d.s then return { d.s[1], d.s[2], d.s[3], d.s[4] ~= "" and d.s[4] or d.n } end
  if d.si and d.si[5] == 1 and d.si[4] and d.si[4][1] then
    local p = d.si[4][1]
    return { p[1], p[2], p[3], (d.si[3] and d.si[3][1]) or d.si[2] }
  end
end

-- The hand-written dungeon lists (Routes/Horde.lua, Routes/Alliance.lua) name their quests: give each its quest ID from
-- the quest data, so the plan can follow it (Lost Thunderbrew Recipe, Disharmony of Fire...). Of several quests with
-- that name, one this character can take, the one the dungeon's generated list has, and the last of a chain of them
-- (Dark Iron Legacy comes twice: the second, so the first is the quest before it).
do
  local byName
  local function resolve(dungeon, name)
    if not RG.QDATA then return nil end
    if not byName then
      byName = {}
      for id, d in pairs(RG.QDATA) do
        if d.n then local l = byName[d.n]; if not l then l = {}; byName[d.n] = l end; l[#l + 1] = id end
      end
    end
    local gen = ((RG.PLAYER_FACTION == "Alliance" and RG.GEN_DUNGEONS_A) or RG.GEN_DUNGEONS or {})[dungeon] or {}
    local inGen = {}
    for _, g in ipairs(gen) do inGen[g.id] = true end
    local all, listed = {}, {}
    for _, id in ipairs(byName[name] or {}) do
      if forMe(qd(id)) then all[#all + 1] = id; if inGen[id] then listed[#listed + 1] = id end end
    end
    local cands = #listed > 0 and listed or all
    if #cands == 0 then return nil end
    table.sort(cands)
    local needed = {}
    for _, id in ipairs(cands) do
      local d = qd(id)
      for _, p in ipairs(d.ps or {}) do needed[p] = true end
      for _, p in ipairs(d.pg or {}) do needed[p] = true end
    end
    for _, id in ipairs(cands) do if not needed[id] then return id end end
    return cands[#cands]
  end
  for dungeon, dq in pairs(RG.DUNGEON_QUESTS or {}) do
    for _, q in ipairs(dq.quests or {}) do
      if not q.id and q[1] then q.id = resolve(dungeon, (q[1]:gsub("%s*%(.-%)$", ""))) end
    end
  end
  byName = nil
end

-- Breadcrumbs: the quests that only send you to another one (Yuka Screwspigot to Ribbly Screwspigot)
local crumbsFor
local function breadcrumbs(id)
  if not crumbsFor then
    crumbsFor = {}
    for bid, d in pairs(RG.QDATA or {}) do
      if d.bc then local l = crumbsFor[d.bc]; if not l then l = {}; crumbsFor[d.bc] = l end; l[#l + 1] = bid end
    end
  end
  return crumbsFor[id]
end

-- a quest that can only be finished inside a dungeon: one of its objectives has nowhere outside to be done (the data
-- keeps no spawns inside instances), or it's one of a dungeon's quests and whoever it's handed to isn't outside
-- (Commander Gor'shak, in his cell in Blackrock Depths)
local function needsInside(id)
  local d = qd(id)
  if not d then return false end
  for _, o in ipairs(d.o or {}) do
    if #(o[4] or {}) == 0 then return true end
  end
  return not d.e and RG.IsDungeonQuest and RG.IsDungeonQuest(id) and true or false
end
-- an objective of a dungeon quest that's done before the run: nothing to do with mobs (an object, an item lying about)
function RG.PrepObjectiveBefore(id, label)
  local d = qd(id)
  for _, o in ipairs(d and d.o or {}) do
    if o[2] == label then return #(o[4] or {}) > 0 and (o[1] == "o" or (o[1] == "i" and #(o[3] or {}) == 0)) end
  end
  return false
end

-- The quests that must come first, not done yet (all of "pg"; one of "ps", the first this character can take), and a
-- breadcrumb to it that's in your log (hand it in first: its turn-in is where the quest starts)
local function prereqs(id)
  local d, out = qd(id), {}
  if not d then return out end
  for _, p in ipairs(d.pg or {}) do if not isDone(p) and qd(p) then out[#out + 1] = p end end
  if d.ps and #d.ps > 0 then
    local any = false
    for _, p in ipairs(d.ps) do if isDone(p) then any = true break end end
    if not any then
      for _, p in ipairs(d.ps) do if forMe(qd(p)) then out[#out + 1] = p break end end
    end
  end
  if not onQuest(id) and not isDone(id) then
    for _, b in ipairs(breadcrumbs(id) or {}) do if onQuest(b) then out[#out + 1] = b end end
  end
  return out
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Which dungeon
-- ---------------------------------------------------------------------------------------------------------------------
local function skips()
  RG.db.prepSkip = RG.db.prepSkip or {}
  return RG.db.prepSkip
end
-- the dungeons with quests, by level: { { name, from, to, dq }, ... }
function RG.PrepDungeons()
  local out, seen = {}, {}
  for _, r in ipairs(RG.ROUTE or {}) do
    local dq = r.kind == "dungeon" and RG.DUNGEON_QUESTS and RG.DUNGEON_QUESTS[r.zone]
    if dq and not seen[r.zone] and #(dq.quests or {}) > 0 then
      seen[r.zone] = true
      out[#out + 1] = { name = r.zone, from = r.from, to = r.to, dq = dq }
    end
  end
  table.sort(out, function(a, b) if a.from ~= b.from then return a.from < b.from end return a.name < b.name end)
  return out
end
-- the dungeon it's preparing for: the one you picked, else the next one for your level with quests still to collect
function RG.PrepDungeon()
  local p = RG.db and RG.db.prepDungeon
  if p and RG.DUNGEON_QUESTS and RG.DUNGEON_QUESTS[p] then return p end
  local lvl = UnitLevel and UnitLevel("player") or 1
  local best, bestD
  for _, e in ipairs(RG.PrepDungeons()) do
    local fits = lvl >= (e.dq.prep or e.from) - 2 and lvl <= e.to
    if fits and not (RG.DungeonQuestsDone and RG.DungeonQuestsDone(e.dq)) then return e.name end
    local d = math.abs(lvl - e.from)
    if not bestD or d < bestD then best, bestD = e.name, d end
  end
  return best
end
function RG.SetPrepDungeon(name)
  RG.db.prepDungeon = name
  if RG.TrackerView and RG.TrackerView() ~= "dungeon" and RG.SetTrackerView then RG.SetTrackerView("dungeon")
  elseif RG.RouteChanged then RG.RouteChanged() end
end

-- ---------------------------------------------------------------------------------------------------------------------
-- The plan for one dungeon
-- ---------------------------------------------------------------------------------------------------------------------
-- { name, quests = { target, ... }, obtained, total, skipped, after, inside, waiting,
--   ready (every one you can get is in your log), can (how many you can get before the run) }
--   target = { id, name, level, state, why, chain = { step, ... } }   (the chain: earlier quests first, the target last)
--   step   = { id, name, level, state, why, pre = { earlier quest ids }, target = true for the dungeon's own quest }
-- state: "have" (in your log), "ready" (in your log, done: hand it in), "pickup", "wait" (an earlier quest first),
--   "level", "after" (comes after the run), "inside" (picked up in the dungeon, or from an item that drops), "skipped"
local memo, memoT, memoName
function RG.PrepPlan(name)
  name = name or RG.PrepDungeon()
  local now = GetTime and GetTime() or 0
  if memo and memoName == name and memoT == now then return memo end
  local plan = { name = name, quests = {}, obtained = 0, total = 0, skipped = 0, after = 0, inside = 0, waiting = 0, can = 0 }
  local dq = name and RG.DUNGEON_QUESTS and RG.DUNGEON_QUESTS[name]
  if not dq then return plan end
  local inLog = {}
  for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do if q.id then inLog[q.id] = q end end
  local sk = skips()
  -- the dungeon's quests: its list, then the ones no one outside gives (Profile.lua)
  local ids, isTarget = {}, {}
  for _, list in ipairs({ dq.quests or {}, dq.extra or {} }) do
    for _, q in ipairs(list) do
      local id = q.id or (RG.QUEST_IDS and q[1] and RG.QUEST_IDS[(q[1]:gsub("%s*%(.-%)$", ""))])
      if id and not isTarget[id] then isTarget[id] = true; ids[#ids + 1] = id end
    end
  end
  local seenTarget = {}
  for _, id in ipairs(ids) do
    local d = qd(id)
    -- (a breadcrumb to another of the dungeon's quests isn't one of its own: in your log, it's the first of that one's chain)
    if d and not seenTarget[id] and not isDone(id) and forMe(d) and not (d.bc and isTarget[d.bc] and not isDone(d.bc)) then
      seenTarget[id] = true
      local whyT, never = RG.QuestBlocked(id, d)
      -- (one that starts from an item that may drop: the run is where it drops)
      if not never or inLog[id] or (whyT and whyT:find("^starts from")) then
        -- the chain: earlier quests (depth first, so each comes after the ones it needs), then the quest itself
        local order, seen = {}, {}
        local function walk(x, depth)
          if seen[x] or depth > 25 then return end
          seen[x] = true
          for _, p in ipairs(prereqs(x)) do walk(p, depth + 1) end
          order[#order + 1] = x
        end
        walk(id, 0)
        local t = { id = id, name = d.n or q[1], level = d.l, chain = {} }
        local skippedFrom, afterRun = false, false
        for _, x in ipairs(order) do
          local xd = qd(x)
          local s = { id = x, name = xd and xd.n or "?", level = xd and xd.l, target = x == id, pre = prereqs(x) }
          local why, nv = RG.QuestBlocked(x, xd)
          -- (an earlier quest that's itself done inside a dungeon: what comes after it waits for the run)
          local inside = x ~= id and needsInside(x)
          if sk[x] then skippedFrom = true end
          if skippedFrom then s.state = "skipped"
          elseif afterRun then s.state = "after"
          elseif inLog[x] then
            s.state = inLog[x].complete and not s.target and "ready" or "have"
            if inside and not inLog[x].complete then afterRun = true end
          elseif not pickupWp(xd) and (not nv or (why and why:find("^starts from"))) then
            -- nowhere outside to pick it up: it starts inside the dungeon (or from an item that drops there)
            s.state, afterRun = "inside", true
            s.why = (xd and xd.si and xd.si[2]) and ("starts from " .. xd.si[2]) or ("starts inside " .. tostring(name))
          elseif inside and not nv then
            -- done inside: picked up and kept like the dungeon's own quests; what comes after it waits for the run
            s.state = (why and (why:find("^at level") and "level" or "wait")) or "pickup"
            s.why, s.keep, afterRun = why, true, true
          elseif nv then s.state, s.why = "never", why
          elseif why and why:find("^at level") then s.state, s.why = "level", why
          elseif why then s.state, s.why = "wait", why
          else s.state = "pickup" end
          if s.state ~= "never" then t.chain[#t.chain + 1] = s end
        end
        local last = t.chain[#t.chain]
        t.state = last and last.state or "pickup"
        t.why = last and last.why
        -- the next thing to do in it (for the tracker's line)
        for _, s in ipairs(t.chain) do
          if s.state ~= "have" or s.target then t.nextStep = s break end
        end
        plan.quests[#plan.quests + 1] = t
        plan.total = plan.total + 1
        if t.state == "have" then plan.obtained = plan.obtained + 1
        elseif t.state == "skipped" then plan.skipped = plan.skipped + 1
        elseif t.state == "after" then plan.after = plan.after + 1
        elseif t.state == "inside" then plan.inside = plan.inside + 1
        elseif t.state == "level" or t.state == "wait" then plan.waiting = plan.waiting + 1 end
      end
    end
  end
  -- obtained last; the others by level
  local RANK = { pickup = 1, ready = 1, wait = 2, level = 3, have = 4, after = 5, inside = 6, skipped = 7 }
  table.sort(plan.quests, function(a, b)
    local ra, rb = RANK[a.state] or 3, RANK[b.state] or 3
    if ra ~= rb then return ra < rb end
    if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
    return a.name < b.name
  end)
  plan.can = plan.total - plan.skipped - plan.after - plan.inside
  plan.ready = plan.total > 0 and plan.obtained == plan.can
  memo, memoT, memoName = plan, now, name
  return plan
end

-- Each quest's place in the plan's chains (the dungeon's quests in the plan's order, each chain earliest first): the
-- planner (Guide.lua) orders the steps on another continent by it. { [id] = n }
function RG.PrepOrder(plan)
  plan = plan or RG.PrepPlan()
  local out, n = {}, 0
  for _, t in ipairs(plan.quests) do
    for _, s in ipairs(t.chain) do
      if not out[s.id] then n = n + 1; out[s.id] = n end
    end
  end
  return out
end
function RG.PrepForget() memo = nil end

-- What the planner may pick in this view (Guide.lua): { full = { [id] = true }  (do and hand in), keep = { [id] = true }
-- (pick up and keep: only its objectives that aren't about the dungeon's mobs), pickups = { { id, name, level, wp } } }
function RG.PrepWork()
  local plan = RG.PrepPlan()
  local work = { full = {}, keep = {}, pickups = {}, plan = plan }
  local picked = {}   -- (a quest several chains share is picked up once)
  for _, t in ipairs(plan.quests) do
    for _, s in ipairs(t.chain) do
      if (s.state == "have" or s.state == "ready" or s.state == "pickup") and not picked[s.id] then
        picked[s.id] = true
        -- (the dungeon's own quests, and earlier ones done inside a dungeon, are kept, not done; a finished one is handed in)
        local inside = not s.target and needsInside(s.id)
        if (s.target or inside) and s.state ~= "ready" then work.keep[s.id] = true else work.full[s.id] = true end
        if s.state == "pickup" then
          local wp = pickupWp(qd(s.id))
          if wp then work.pickups[#work.pickups + 1] = { id = s.id, name = s.name, level = s.level, wp = wp, label = wp[4] } end
        end
      end
    end
  end
  return work
end

-- Skip a quest and its chain from there (or bring it back)
function RG.PrepSkip(id, on)
  local sk = skips()
  sk[id] = on and true or nil
  RG.PrepForget()
  if RG.RouteChanged then RG.RouteChanged() end
end
function RG.PrepSkipMenu(t, s)
  local e = {}
  local skippedAt
  for _, x in ipairs(t.chain) do if RG.db.prepSkip and RG.db.prepSkip[x.id] then skippedAt = x end end
  if skippedAt then
    e[#e + 1] = { "Bring back " .. skippedAt.name .. " (and its chain)", function() RG.PrepSkip(skippedAt.id, false) end }
  else
    local at = s or t.nextStep or t.chain[1]
    if at then e[#e + 1] = { "Skip " .. at.name .. (at.target and "" or " and the rest of its chain"), function() RG.PrepSkip(at.id, true) end } end
  end
  if RG.ShowMenu then RG.ShowMenu(e, t.name) end
end

-- One line on how it's going, for the tracker's header line and the card when there's nothing left to do now
function RG.PrepSummary(plan)
  plan = plan or RG.PrepPlan()
  if plan.total == 0 then return "Nothing to collect for " .. tostring(plan.name or "this dungeon") end
  if plan.ready then return "Ready for " .. plan.name .. ": " .. plan.obtained .. " quest" .. (plan.obtained == 1 and "" or "s") .. " in your log" end
  return plan.obtained .. " of " .. plan.can .. " in your log"
end

-- how each state reads
RG.PREP_STATE = {
  have = GREEN .. "in your log|r", ready = GOLD .. "hand in|r", pickup = GOLD .. "pick up|r", wait = GREY .. "later|r",
  level = GREY .. "level|r", after = GREY .. "after the run|r", inside = GREY .. "in the run|r", skipped = GREY .. "skipped|r",
}
function RG.PrepStateText(s)
  if s.state == "level" and s.why then return GREY .. s.why:gsub("^at ", "") .. "|r" end
  return RG.PREP_STATE[s.state] or ""
end

-- Every quest of the plan once, one per line, in the order you can do them, for the tracker:
--   1. "now": the ones you can work on now (pick up, do, hand in), in the order the planner takes them (stops: its
--      steps, RG.GuidePlan().stops), so the first is the current step
--   2. "wait": the ones an earlier quest of the list opens, each after the quests it needs
--   3. "level": the ones that wait for a level
--   4. "have": the dungeon's own quests in your log, kept for the run
--   5. "after": the ones that come after a quest done inside the dungeon
--   6. "inside": the ones picked up inside the dungeon
-- { { s = step, t = the target it's for, g = group above, stop = { stop, item } (its first step in the plan, or nil),
--     before = { earlier quest ids still to do } }, ... }, skipped (how many quests are skipped)
local GROUP_RANK = { now = 1, wait = 2, level = 3, have = 4, after = 5, inside = 6 }
function RG.PrepList(plan, stops, work)
  plan = plan or RG.PrepPlan()
  work = work or RG.PrepWork()
  -- every quest of every chain once, with the target it's for (the first that needs it)
  local nodes, all = {}, {}
  for _, t in ipairs(plan.quests) do
    for _, s in ipairs(t.chain) do
      if not nodes[s.id] then nodes[s.id] = { s = s, t = t }; all[#all + 1] = nodes[s.id] end
    end
  end
  -- its first step in the plan
  local at, first = {}, {}
  for i, st in ipairs(stops or {}) do
    for _, it in ipairs(st.items or {}) do
      if it.id and not at[it.id] then at[it.id], first[it.id] = i, { stop = st, item = it } end
    end
  end
  local rows, skipped = {}, 0
  for _, nd in ipairs(all) do
    local s = nd.s
    local kept = s.target or s.keep or work.keep[s.id]
    local g
    if s.state == "skipped" then skipped = skipped + 1
    elseif at[s.id] then g = "now"
    elseif s.state == "pickup" or s.state == "ready" or (s.state == "have" and not kept) then g = "now"
    elseif s.state == "have" then g = "have"
    else g = GROUP_RANK[s.state] and s.state or "wait" end
    if g then
      nd.g, nd.stop = g, first[s.id]
      nd.before = {}
      for _, p in ipairs(s.pre or {}) do if nodes[p] and nodes[p].s.state ~= "skipped" then nd.before[#nd.before + 1] = p end end
      rows[#rows + 1] = nd
    end
  end
  -- (how many quests of the list come before it; and the place of the latest quest it waits on that you can do now)
  local depth, anchor = {}, {}
  local function dep(id, guard)
    if depth[id] then return depth[id] end
    if guard > 30 then return 0 end
    local d = 0
    for _, p in ipairs(nodes[id] and nodes[id].before or {}) do d = math.max(d, dep(p, guard + 1) + 1) end
    depth[id] = d
    return d
  end
  local function anc(id, guard)
    if anchor[id] then return anchor[id] end
    local nd = nodes[id]
    if not nd or guard > 30 then return 9999 end
    local a
    if nd.g == "now" then a = at[id] or (500 + (nd.s.level or 0))
    else
      for _, p in ipairs(nd.before or {}) do
        local v = anc(p, guard + 1)
        if not a or v > a then a = v end
      end
      a = a or (5000 + (nd.s.level or 0))
    end
    anchor[id] = a
    return a
  end
  for _, nd in ipairs(rows) do nd.depth, nd.anchor = dep(nd.s.id, 0), anc(nd.s.id, 0) end
  table.sort(rows, function(a, b)
    local ra, rb = GROUP_RANK[a.g], GROUP_RANK[b.g]
    if ra ~= rb then return ra < rb end
    if a.anchor ~= b.anchor then return a.anchor < b.anchor end
    if a.depth ~= b.depth then return a.depth < b.depth end
    if (a.s.level or 0) ~= (b.s.level or 0) then return (a.s.level or 0) < (b.s.level or 0) end
    return a.s.name < b.s.name
  end)
  return rows, skipped
end

-- What a quest of the list says on the right: the next thing to do for it ("pick up", "3/6", "hand in"), else how it stands
function RG.PrepRowAction(nd)
  local s = nd.s
  if nd.g == "now" then
    local it = nd.stop and nd.stop.item
    local act = it and it.act or (s.state == "pickup" and "pickup") or (s.state == "ready" and "turnin") or "doing"
    if act == "pickup" then return GOLD .. "pick up|r" end
    if act == "turnin" then return GOLD .. "hand in|r" end
    if it and it.need and it.need > 0 then return GOLD .. (it.have or 0) .. "/" .. it.need .. "|r" end
    return GOLD .. "to do|r"
  end
  if nd.g == "have" then return GREEN .. "in your log|r" end
  return RG.PrepStateText(s)
end

-- The quest to go and do for a quest of the list: itself when it has a step in the plan, else the first quest it waits
-- on that has one (the row, or nil)
function RG.PrepRowGoal(nd, rows)
  if nd.stop then return nd end
  local byId = {}
  for _, r in ipairs(rows or {}) do byId[r.s.id] = r end
  local best
  local seen = {}
  local function walk(id, guard)
    if seen[id] or guard > 30 then return end
    seen[id] = true
    local r = byId[id]
    if not r then return end
    if r.stop then
      if not best or (r.anchor or 9999) < (best.anchor or 9999) then best = r end
      return
    end
    for _, p in ipairs(r.before or {}) do walk(p, guard + 1) end
  end
  for _, p in ipairs(nd.before or {}) do walk(p, 0) end
  return best
end

-- What a step of the trip says: "Pick up Commander Gor'shak", "Kill Overmaster Pyron 0/1", "Hand in Disharmony of Flame"
function RG.PrepStepText(it, keep)
  if it.act == "turnin" then return "Hand in " .. tostring(it.title) end
  if it.act == "pickup" then return "Pick up " .. tostring(it.title) .. (keep and keep[it.id] and (GREY .. "  · keep|r") or "") end
  local verb = ({ k = "Kill", i = "Collect", o = "Use" })[it.okind or ""] or "Do"
  return verb .. " " .. tostring(it.label or it.title) .. ((it.need and it.need > 0) and ("  " .. (it.have or 0) .. "/" .. it.need) or "")
end
