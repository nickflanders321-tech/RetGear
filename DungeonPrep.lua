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
local function qd(id) return id and RG.QDATA and RG.QDATA[id] end
local function forMe(d) return d and (not RG.QuestForMe or RG.QuestForMe(d)) end

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

-- The quests that must come first, not done yet (all of "pg"; one of "ps", the first this character can take)
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
-- { name, quests = { target, ... }, obtained, total, skipped, after, ready (every one you can get is in your log) }
--   target = { id, name, level, state, why, chain = { step, ... } }   (the chain: earlier quests first, the target last)
--   step   = { id, name, level, state, why, target = true for the dungeon's own quest }
-- state: "have" (in your log), "ready" (in your log, done: hand it in), "pickup", "wait" (an earlier quest first),
--   "level", "after" (comes after the run), "skipped"
local memo, memoT, memoName
function RG.PrepPlan(name)
  name = name or RG.PrepDungeon()
  local now = GetTime and GetTime() or 0
  if memo and memoName == name and memoT == now then return memo end
  local plan = { name = name, quests = {}, obtained = 0, total = 0, skipped = 0, after = 0, waiting = 0 }
  local dq = name and RG.DUNGEON_QUESTS and RG.DUNGEON_QUESTS[name]
  if not dq then return plan end
  local lvl = UnitLevel and UnitLevel("player") or 1
  local inLog = {}
  for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do if q.id then inLog[q.id] = q end end
  local sk = skips()
  local seenTarget = {}
  for _, q in ipairs(dq.quests or {}) do
    local id = q.id or (RG.QUEST_IDS and RG.QUEST_IDS[(q[1]:gsub("%s*%(.-%)$", ""))])
    local d = qd(id)
    if d and not seenTarget[id] and not isDone(id) and forMe(d) then
      seenTarget[id] = true
      local _, never = RG.QuestBlocked(id, d)
      if not never or inLog[id] then
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
          local s = { id = x, name = xd and xd.n or "?", level = xd and xd.l, target = x == id }
          local why, nv = RG.QuestBlocked(x, xd)
          -- (an earlier quest that's itself done inside a dungeon: what comes after it waits for the run)
          local inside = x ~= id and needsInside(x)
          if sk[x] then skippedFrom = true end
          if skippedFrom then s.state = "skipped"
          elseif afterRun then s.state = "after"
          elseif inLog[x] then
            s.state = inLog[x].complete and not s.target and "ready" or "have"
            if inside and not inLog[x].complete then afterRun = true end
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
        elseif t.state == "level" or t.state == "wait" then plan.waiting = plan.waiting + 1 end
      end
    end
  end
  -- obtained last; the others by level
  local RANK = { pickup = 1, ready = 1, wait = 2, level = 3, have = 4, after = 5, skipped = 6 }
  table.sort(plan.quests, function(a, b)
    local ra, rb = RANK[a.state] or 3, RANK[b.state] or 3
    if ra ~= rb then return ra < rb end
    if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
    return a.name < b.name
  end)
  plan.ready = plan.total > 0 and plan.obtained + plan.skipped + plan.after == plan.total
  memo, memoT, memoName = plan, now, name
  return plan
end
function RG.PrepForget() memo = nil end

-- What the planner may pick in this view (Guide.lua): { full = { [id] = true }  (do and hand in), keep = { [id] = true }
-- (pick up and keep: only its objectives that aren't about the dungeon's mobs), pickups = { { id, name, level, wp } } }
function RG.PrepWork()
  local plan = RG.PrepPlan()
  local work = { full = {}, keep = {}, pickups = {}, plan = plan }
  for _, t in ipairs(plan.quests) do
    for _, s in ipairs(t.chain) do
      if s.state == "have" or s.state == "ready" or s.state == "pickup" then
        -- (the dungeon's own quests, and earlier ones done inside a dungeon, are kept, not done; a finished one is handed in)
        local inside = not s.target and needsInside(s.id)
        if (s.target or inside) and s.state ~= "ready" then work.keep[s.id] = true else work.full[s.id] = true end
        if s.state == "pickup" then
          local d = qd(s.id)
          local wp
          if d.s then wp = { d.s[1], d.s[2], d.s[3], d.s[4] ~= "" and d.s[4] or d.n }
          elseif d.si and d.si[5] == 1 and d.si[4] and d.si[4][1] then
            local p = d.si[4][1]
            wp = { p[1], p[2], p[3], (d.si[3] and d.si[3][1]) or d.si[2] }
          end
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
  return plan.obtained .. " of " .. (plan.total - plan.skipped) .. " in your log"
end

-- how each state reads
RG.PREP_STATE = {
  have = GREEN .. "in your log|r", ready = GREEN .. "hand in|r", pickup = GOLD .. "pick up|r", wait = GREY .. "later|r",
  level = GREY .. "level|r", after = GREY .. "after the run|r", skipped = GREY .. "skipped|r",
}
function RG.PrepStateText(s)
  if s.state == "level" and s.why then return GREY .. s.why:gsub("^at ", "") .. "|r" end
  return RG.PREP_STATE[s.state] or ""
end
