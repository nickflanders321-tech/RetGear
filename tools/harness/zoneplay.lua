-- The zone-quests bot (run.lua --play-zone "Mount Hyjal"): picks one zone in "Zone quests" mode and does whatever the
-- tracker's step card says, one thing at a time, as a player following it would: the card's first line (pick up,
-- hand in, or the objective to work on), at the waypoint the card gives, then it looks at the card again.
--
-- Where play.lua follows the route's steps, this follows the plan (Guide.lua: RG.Objective), so it tries what the
-- route bot never reaches: the plan's order, the "right beside you" grab, what heads the card.
--
-- It reports, as failures:
--   card      the card heads with something you can't do now (a hand-in whose objectives aren't done)
--   pickup    the card says pick up a quest the game won't give
--   turnin    the card says hand in a quest that can't be
--   waypoint  the card's spot for an objective isn't where the objective is
--   stuck     the card keeps pointing at the same thing with nothing changing (the bot skips it, as you would)
--   revisit   back at a quest giver for a quest it could have taken (or handed in) on its visit before
--   no-spot   a quest in your log the card has no place for
-- and at the end, what the zone has left: quests still in the log, and the zone's quests it never took, with why.
local Z = {}

local WALK = 7          -- yards per second (running, no mount)
local LEAVE = 150       -- yards from a quest giver that count as having left it

function Z.run(W, Wd, RG, opts, Inv, I)
  local S = Wd.state
  local me = W.me
  local zone = opts.play_zone
  local maxActions = tonumber(opts.max_actions) or 800
  local untilLevel = tonumber(opts.until_level) or 61
  local R = { actions = 0, problems = {}, ticked = 0, tickedHand = 0, ground = {}, startLevel = me.level, steps = {}, log = {},
    path = {}, classQuests = {}, classSeen = {}, info = {}, gear = { equips = {}, score = {} }, found = 0, zone = zone }
  local problemSeen = {}
  local function problem(kind, text, where)
    local key = kind .. "|" .. text
    if problemSeen[key] then problemSeen[key].count = problemSeen[key].count + 1 return end
    local p = { kind = kind, text = text, where = where, level = me.level, count = 1 }
    problemSeen[key] = p
    R.problems[#R.problems + 1] = p
  end
  local function note(s) R.log[#R.log + 1] = string.format("[%2d] %s", me.level, s) end
  local function qname(id) local d = RG.QDATA[id]; return tostring(d and d.n or "?") .. " (" .. tostring(id) .. ")" end

  local function wait(secs)
    S.stats.seconds = S.stats.seconds + secs
    local framed = math.min(secs, 60)
    W.step(framed, 1)
    if secs > framed then W.advance(secs - framed) end
  end
  -- the card as the tracker has it now (worked out afresh: the bot doesn't wait for the guide's once-a-second beat)
  local function card()
    if RG.ForgetQuestSpots then RG.ForgetQuestSpots() end
    if RG.ForgetNextStep then RG.ForgetNextStep() end
    RG.lastGuideError = nil
    local obj = RG.Objective(true)
    if RG.lastGuideError then problem("plan-error", "the plan failed: " .. tostring(RG.lastGuideError), "level " .. me.level) end
    return obj
  end

  -- quest givers: where the bot talked to each, what it could have taken or handed in there then
  local zoneIds, byGiver, byFinisher = {}, {}, {}
  local visits = {}
  local function leave()
    for _, v in pairs(visits) do
      if not v.left and (S.map ~= v.map or (Wd.yards(v.map, v.x, v.y, S.map, S.x, S.y) or 0) > LEAVE) then v.left = true end
    end
  end
  -- every leg walked: { level, yards (nil: another continent), from/to map, what it went for }, for how good the order is
  R.legs, R.walked, R.travels = {}, 0, 0
  local function leg(yards, toMap, travel, tx, ty)
    R.legs[#R.legs + 1] = { level = me.level, yards = yards, from = S.map, to = toMap, fx = S.x, fy = S.y, tx = tx, ty = ty, why = R.cur, travel = travel }
    note(string.format("  LEG %s %s %d %.1f %.1f -> %d %.1f %.1f | %s", travel and "travel" or "walk", yards and string.format("%d", yards) or "?",
      S.map, S.x * 100, S.y * 100, toMap, tx * 100, ty * 100, tostring(R.cur)))
  end
  local function walk(wp)
    if not wp or not wp[1] then return end
    local tx, ty = wp[2] / 100, wp[3] / 100
    if wp[1] ~= S.map then
      local d = Wd.yards(S.map, S.x, S.y, wp[1], tx, ty)
      leg(d, wp[1], true, tx, ty)
      R.travels = R.travels + 1
      note("travels to " .. Wd.mapName(wp[1]) .. " (the card's spot is outside " .. tostring(Wd.mapName(S.map)) .. ")")
      Wd.setPos(wp[1], tx, ty)
      wait(d and math.min(d / WALK, 600) or 600)
      leave()
      return
    end
    local d = Wd.yards(S.map, S.x, S.y, wp[1], tx, ty) or 0
    if d > 5 then leg(d, wp[1], false, tx, ty); R.walked = R.walked + d end
    local secs = d / WALK
    local n = math.max(1, math.min(30, math.floor(secs / 2)))
    local x0, y0 = S.x, S.y
    W.context = "walking"
    for k = 1, n do
      Wd.setPos(S.map, x0 + (tx - x0) * k / n, y0 + (ty - y0) * k / n)
      wait(secs / n)
    end
    leave()
  end
  local function complete(e) for _, o in ipairs(e.objs) do if o.have < o.need then return false end end return true end
  local function atGiver(npc, id, act, where)
    if not npc then return end
    local prev = visits[npc]
    if prev and prev.left then
      if act == "pickup" and prev.avail[id] then
        problem("revisit", "came back to " .. tostring(prev.name) .. " to pick up " .. qname(id) .. ", which it could have taken on its visit at level " .. prev.level, where)
      elseif act == "turnin" and prev.ready[id] then
        problem("revisit", "came back to " .. tostring(prev.name) .. " to hand in " .. qname(id) .. ", which was already done on its visit at level " .. prev.level, where)
      end
    end
    local v = { avail = {}, ready = {}, level = me.level, map = S.map, x = S.x, y = S.y, name = prev and prev.name }
    for _, q in ipairs(byGiver[npc] or {}) do if Wd.canAccept(q) then v.avail[q] = true end end
    for _, q in ipairs(byFinisher[npc] or {}) do local e = Wd.entry(q); if e and complete(e) then v.ready[q] = true end end
    local d = RG.QDATA[id]
    v.name = v.name or (d and ((d.s and d.s[5] == npc and d.s[4]) or (d.e and d.e[5] == npc and d.e[4]))) or ("NPC " .. npc)
    -- (both done on this visit: what's left is what it could still have done here)
    if act == "pickup" then v.avail[id] = nil else v.ready[id] = nil end
    visits[npc] = v
  end

  -- into the zone, in "Zone quests" mode
  RG.db.routeGuide = true
  RG.SetZonePick(zone)
  wait(1)
  local r = RG.CurrentRouteEntry and RG.CurrentRouteEntry()
  if not (r and r.zone == zone) then
    problem("zone", "Zone quests for " .. zone .. " found no route entry (it follows " .. tostring(r and r.zone) .. ")", "start")
    R.endLevel = me.level
    return R
  end
  for _, rr in ipairs(RG.ROUTE or {}) do
    if rr.zone == zone then
      for _, ids in pairs((RG.STEP_QUESTS or {})[rr.zone .. "|" .. rr.from] or {}) do
        for _, id in ipairs(ids) do
          local d = RG.QDATA[id]
          if d and (not RG.QuestForMe or RG.QuestForMe(d)) and not zoneIds[id] then
            zoneIds[id] = true
            if d.s and d.s[5] then byGiver[d.s[5]] = byGiver[d.s[5]] or {}; table.insert(byGiver[d.s[5]], id) end
            if d.e and d.e[5] then byFinisher[d.e[5]] = byFinisher[d.e[5]] or {}; table.insert(byFinisher[d.e[5]], id) end
          end
        end
      end
    end
  end
  local start = RG.StepWaypoint and RG.StepWaypoint(r, 1)
  if start then Wd.setPos(start[1], start[2] / 100, start[3] / 100); wait(5) end
  note("starts in " .. zone .. " at " .. tostring(start and start[4] or Wd.mapName(S.map)) .. ", level " .. me.level)
  R.path[1] = { zone = zone, from = me.level, to = me.level, why = "zone quests" }

  -- Quests that start from a dropped item (or a giver who turns up after a kill: Anywhere But Here's Veteran of the
  -- Third War, after Forgotten Soldiers): the guide shows them only once they're in your log. The bot gets the item
  -- after killing enough of the mobs that drop it (one, for a sure drop; else by the drop rate, 10% when unknown), or by
  -- walking past where one lies, and uses it: the quest is taken there and then, or as soon as it can be.
  R.looted = 0
  local starters, inBag = {}, {}
  for id in pairs(zoneIds) do
    local d = RG.QDATA[id]
    if d and not d.s and d.si and (not RG.QuestForMe or RG.QuestForMe(d)) then starters[#starters + 1] = id end
  end
  table.sort(starters)
  local function loot()
    for _, id in ipairs(starters) do
      if not S.done[id] and not Wd.entry(id) then
        local si = RG.QDATA[id].si
        if not inBag[id] then
          if si[3] and #si[3] > 0 then
            local killed = 0
            for _, m in ipairs(si[3]) do killed = killed + (S.killed[m] or 0) end
            local pct = 0
            for _, v in ipairs(type(si[8]) == "table" and si[8] or {}) do if tonumber(v) and tonumber(v) > pct then pct = tonumber(v) end end
            if pct <= 0 then pct = 10 end
            local need = si[5] == 1 and 1 or math.max(1, math.min(40, math.ceil(100 / pct)))
            if killed >= need then inBag[id] = string.format("after %d %s", killed, table.concat(si[3], "/")) end
          else
            for _, sp in ipairs(si[4] or {}) do if Wd.near(sp, 0.02) then inBag[id] = "lying at " .. tostring(si[2]) break end end
          end
          if inBag[id] then R.looted = R.looted + 1; note("loots " .. tostring(si[2]) .. " (" .. inBag[id] .. "): starts " .. qname(id)) end
        end
        if inBag[id] and Wd.canAccept(id) then
          local ok = Wd.accept(id, true)
          if ok then note("uses " .. tostring(si[2]) .. ": picks up " .. qname(id)) end
        end
      end
    end
  end

  local lastSig, same, lastRouteKey, routeSame = nil, 0, nil, 0
  local ended
  while R.actions < maxActions and me.level < untilLevel do
    R.actions = R.actions + 1
    W.phase = "zone quests (level " .. me.level .. ")"
    loot()
    local obj = card()
    if not obj then ended = "the card is empty: the plan has nothing left in " .. zone break end
    local it = obj.stop and obj.stop.items and obj.stop.items[1]
    local what = it and (it.act .. " " .. qname(it.id)) or (tostring(obj.kind) .. ": " .. tostring(obj.text))
    local where = string.format("card: %s%s", what, obj.dist and string.format(" (%d yd)", obj.dist) or "")
    R.cur = what
    R.steps[what] = true
    -- the same card with nothing changed, three times: stuck (skip it, as a player pressing Skip would)
    local progress = 0
    for _, e in ipairs(S.log) do for _, o in ipairs(e.objs) do progress = progress + o.have end end
    local sig = tostring(obj.key) .. "|" .. what .. "|" .. #S.log .. "|" .. S.stats.handedIn .. "|" .. me.level .. "|" .. progress
    if sig == lastSig then same = same + 1 else same = 0 end
    lastSig = sig
    if same >= 3 then
      problem("stuck", "the card keeps saying " .. what .. " with nothing changing; the bot skipped it", where)
      if obj.stop and RG.SkipStop then RG.SkipStop(obj.stop) else ended = "stuck on " .. what .. " with nothing to skip" break end
      same = 0
    elseif it then
      local e = it.id and Wd.entry(it.id)
      if it.act == "pickup" then
        walk(obj.wp)
        local ok, why = Wd.accept(it.id)
        if ok then
          note("picks up " .. qname(it.id))
          local d = RG.QDATA[it.id]
          atGiver(d and d.s and d.s[5], it.id, "pickup", where)
        else problem("pickup", "the card says pick up " .. qname(it.id) .. ", but the game says: " .. tostring(why), where) end
        wait(3)
      elseif it.act == "turnin" then
        if not e then
          problem("card", "the card heads with handing in " .. qname(it.id) .. ", which isn't in the quest log", where)
        elseif not complete(e) then
          local left = {}
          for _, o in ipairs(e.objs) do if o.have < o.need then left[#left + 1] = o.label .. " " .. o.have .. "/" .. o.need end end
          problem("card", "the card heads with handing in " .. qname(it.id) .. " while its objectives aren't done (" .. table.concat(left, ", ") .. ")", where)
        end
        walk(obj.wp)
        local ok, why = Wd.handIn(it.id)
        if ok then
          note("hands in " .. qname(it.id))
          local d = RG.QDATA[it.id]
          atGiver(d and d.e and d.e[5], it.id, "turnin", where)
        elseif e and complete(e) then problem("turnin", "the card says hand in " .. qname(it.id) .. ", but: " .. tostring(why), where) end
        wait(3)
      else
        -- an objective (or items to bring): work on it where the card says
        if not e then
          problem("card", "the card heads with working on " .. qname(it.id) .. ", which isn't in the quest log", where)
          if obj.stop and RG.SkipStop then RG.SkipStop(obj.stop) end
        else
          walk(obj.wp)
          local moved, secs = Wd.work(it.id)
          if moved == 0 then
            local sp = Wd.objectiveSpot(it.id)
            if sp then
              problem("waypoint", "the card's spot for " .. qname(it.id) .. " (" .. tostring(it.label) .. ") isn't near the objective", where)
              walk(sp)
              moved, secs = Wd.work(it.id)
            end
          end
          if moved > 0 then note("works on " .. qname(it.id) .. ": " .. tostring(it.label)) end
          wait(math.max(secs, 5))
        end
      end
    elseif obj.kind == "route" and obj.act == "doing" and obj.id then
      -- a quest in the log the card has no place for: the world's own spot, if it has one
      problem("no-spot", "the card has no place for " .. qname(obj.id) .. (obj.wp and " beyond the game's map area" or ""), where)
      local sp = Wd.objectiveSpot(obj.id) or obj.wp
      walk(sp)
      local moved, secs = Wd.work(obj.id)
      if moved == 0 then
        local d = RG.QDATA[obj.id]
        local e = Wd.entry(obj.id)
        if e and complete(e) and d and d.e then walk(d.e); Wd.handIn(obj.id)
        else ended = "the card says " .. tostring(obj.text) .. " and the bot can't do it" break end
      end
      wait(math.max(secs or 0, 5))
    elseif obj.kind == "route" then
      -- "Head to ...": the route's hub for a step (nothing in the plan): go there; twice there with nothing new is the end
      walk(obj.wp)
      if lastRouteKey == obj.key then routeSame = routeSame + 1 else routeSame = 0 end
      lastRouteKey = obj.key
      note("heads to " .. tostring(obj.wp and obj.wp[4] or obj.text))
      if routeSame >= 2 then
        local lines = {}
        local key = r.zone .. "|" .. r.from
        local i = tonumber(tostring(obj.key):match("#(%d+)$"))
        for _, l in ipairs(i and RG.StepQuestLines(r, i) or {}) do lines[#lines + 1] = l.act .. " " .. tostring(l.name) .. (l.npc and (" (" .. tostring(l.npc) .. ")") or "") end
        ended = "the card says " .. tostring(obj.text) .. " (" .. key .. " step " .. tostring(i) .. "), and there's nothing to do there: " .. table.concat(lines, "; ")
        problem("dead-end", ended, "at " .. tostring(Wd.mapName(S.map)) .. " " .. string.format("%.1f, %.1f", S.x * 100, S.y * 100))
        break
      end
      wait(5)
    else
      ended = "the card shows " .. tostring(obj.kind) .. ": " .. tostring(obj.text)
      break
    end
  end
  if not ended then ended = R.actions >= maxActions and ("ran out of actions (" .. maxActions .. ")") or ("reached level " .. me.level) end
  R.ended = ended
  R.endLevel = me.level
  R.path[1].to = me.level
  -- what the zone has left
  R.left = { inLog = {}, notTaken = {} }
  for _, e in ipairs(S.log) do
    if zoneIds[e.id] then
      local left = {}
      for _, o in ipairs(e.objs) do if o.have < o.need then left[#left + 1] = o.label .. " " .. o.have .. "/" .. o.need end end
      R.left.inLog[#R.left.inLog + 1] = qname(e.id) .. (complete(e) and ": done, not handed in" or (": " .. table.concat(left, ", ")))
    end
  end
  -- (what the guide's own step says about each: its line for the quest, and whether the step counts as done)
  local guideSays = {}
  for _, rr in ipairs(RG.ROUTE or {}) do
    if rr.zone == zone then
      local key = rr.zone .. "|" .. rr.from
      for i, qids in pairs((RG.STEP_QUESTS or {})[key] or {}) do
        local lines = RG.StepQuestLines(rr, i) or {}
        local done = RG.StepIsDone(rr, i)
        for _, id in ipairs(qids) do
          local said = "not on the step's lines"
          for _, l in ipairs(lines) do
            if l.id == id then said = tostring(l.act) .. (l.npc and (" (" .. tostring(l.npc) .. ")") or "") .. (l.wp and "" or ", no waypoint") break end
          end
          guideSays[id] = guideSays[id] or (key .. " step " .. i .. (done and " (done)" or "") .. ": " .. said)
        end
      end
    end
  end
  local ids = {}
  for id in pairs(zoneIds) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    if not S.done[id] and not Wd.entry(id) then
      local ok, why = Wd.canAccept(id)
      R.left.notTaken[#R.left.notTaken + 1] = qname(id) .. ": " .. (ok and ("could be taken, but the card never sent the bot for it; the guide's " .. tostring(guideSays[id])) or tostring(why))
    end
  end
  return R
end

return Z
