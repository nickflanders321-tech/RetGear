-- The bot (run.lua --play): plays a character by doing only what Waypath+ says, in the simulated world (world.lua).
--
-- Each turn it asks the guide for the route entry (RG.CurrentRouteEntry) and the step (RG.NextStep), then:
--   * a step with quests (RG.StepQuestLines): the first quest to hand in, else to pick up, else to work on. It walks
--     to the waypoint the guide gives for it, and hands in / accepts / does the objectives there;
--   * a hand-written step (no quests): walks to its waypoint, if any, and ticks it, as a player would;
--   * nothing to do at this level: grinds a level (noted: the route ran out of XP there).
-- It reports where the guide went wrong: a quest it can't pick up, a waypoint where the objective isn't, a step it
-- keeps coming back to without anything changing. Those are failures, like Lua errors.
local P = {}

local WALK = 7          -- yards per second (running, no mount)
local OTHER_ZONE = 600  -- seconds to get to another continent (or anywhere, without the maps cache)

function P.run(W, Wd, RG, opts, Inv, I)
  local S = Wd.state
  local me = W.me
  local untilLevel = tonumber(opts.until_level) or 20
  local maxActions = tonumber(opts.max_actions) or 4000
  local R = { actions = 0, problems = {}, ticked = 0, tickedHand = 0, ground = {}, startLevel = me.level, steps = {}, log = {} }
  local problemSeen = {}
  local function problem(kind, text, where)
    local key = kind .. "|" .. text
    if problemSeen[key] then problemSeen[key].count = problemSeen[key].count + 1 return end
    local p = { kind = kind, text = text, where = where, level = me.level, count = 1 }
    problemSeen[key] = p
    R.problems[#R.problems + 1] = p
  end
  local function note(s) R.log[#R.log + 1] = string.format("[%2d] %s", me.level, s) end

  -- time passes: timers and per-frame updates (coarse while walking: one frame a second, at most a minute of them)
  local function wait(secs)
    S.stats.seconds = S.stats.seconds + secs
    local framed = math.min(secs, 60)
    W.step(framed, 1)
    if secs > framed then W.advance(secs - framed) end
  end
  -- the zones the bot goes through, in order, with the levels it was there ({ zone, from, to }): how much it mixes zones
  R.path = {}
  local function notePlace()
    local z = Wd.mapName(S.map)
    local last = R.path[#R.path]
    if last and last.zone == z then last.to = me.level
    else R.path[#R.path + 1] = { zone = z, from = me.level, to = me.level } end
  end
  -- walk to a waypoint { uiMapID, x 0-100, y 0-100 }
  local function walk(wp)
    if not wp or not wp[1] then return end
    local tx, ty = wp[2] / 100, wp[3] / 100
    if wp[1] ~= S.map then
      notePlace()
      -- to another zone: the real distance on one continent (flights cap it at 10 minutes), a boat or zeppelin otherwise
      local d = Wd.yards(S.map, S.x, S.y, wp[1], tx, ty)
      W.context = "travelling to " .. Wd.mapName(wp[1])
      Wd.setPos(wp[1], tx, ty)
      notePlace()
      wait(d and math.min(d / WALK, 600) or OTHER_ZONE)
      R.travel = (R.travel or 0) + (d and math.min(d / WALK, 600) or OTHER_ZONE)
      return
    end
    local d = Wd.yards(S.map, S.x, S.y, wp[1], tx, ty) or 0
    local secs = d / WALK
    local n = math.max(1, math.min(30, math.floor(secs / 2)))
    local x0, y0 = S.x, S.y
    W.context = "walking"
    for k = 1, n do
      Wd.setPos(S.map, x0 + (tx - x0) * k / n, y0 + (ty - y0) * k / n)
      wait(secs / n)
    end
  end

  local function grind(why)
    local from = me.level
    note("grinds a level: " .. why)
    R.ground[#R.ground + 1] = { level = from, why = why }
    W.context = "grinding"
    local guard = 0
    while me.level == from and me.level < 60 and guard < 400 do
      guard = guard + 1
      S.stats.kills = S.stats.kills + 1
      Wd.giveXP(Wd.killXP(me.level, me.level), "kill")
      if guard % 10 == 0 then wait(250) end
    end
  end

  -- tick a step by hand, as a player clicking it would (and a moment passes: the guide works out its pick at most once a second)
  local botTicked = {}   -- steps the bot ticked to get past a problem: what they held, it never did
  local function tick(key, i, text, forced)
    RG.TickStep(key .. "#" .. i, text)
    if forced then for _, id in ipairs(RG.STEP_QUESTS[key] and RG.STEP_QUESTS[key][i] or {}) do botTicked[id] = key .. " step " .. i end end
    wait(2)
  end

  -- where each quest is in the route (entry order, step), to say why a quest's prerequisite was never done
  local routeOrder, questAt = {}, {}
  for n, r in ipairs(RG.ROUTE or {}) do routeOrder[r.zone .. "|" .. r.from] = n end
  for key, list in pairs(RG.STEP_QUESTS or {}) do
    for i, ids in pairs(list) do
      for _, id in ipairs(ids) do
        local cur = questAt[id]
        local o = routeOrder[key] or 999
        if not cur or o < cur.o or (o == cur.o and i < cur.i) then questAt[id] = { key = key, i = i, o = o } end
      end
    end
  end
  -- Why a quest of the step at (key, i) is blocked: the first missing prerequisite and what happened to it.
  -- Returns the kind ("cascade" when the bot itself skipped the prerequisite) and a sentence.
  local function blockedWhy(id, key, i)
    local Q = RG.QDATA
    local d = Q[id] or {}
    local missing = {}
    for _, p in ipairs(d.pg or {}) do if not S.done[p] then missing[#missing + 1] = p end end
    if d.ps and #d.ps > 0 then
      local any = false
      for _, p in ipairs(d.ps) do if S.done[p] then any = true end end
      if not any then for _, p in ipairs(d.ps) do missing[#missing + 1] = p end end
    end
    -- only while its parent quest is in the log
    if d.pa and not Wd.entry(d.pa) then missing[#missing + 1] = d.pa end
    if #missing == 0 then return "other", "blocked, but not by an earlier quest" end
    local p = missing[1]
    local pd = Q[p] or {}
    local pname = tostring(pd.n or ("quest " .. p)) .. " (" .. p .. ")"
    if botTicked[p] then return "cascade", "needs " .. pname .. ", which the bot skipped at " .. botTicked[p] end
    local at = questAt[p]
    -- one that starts from an item or object (no quest giver): a player finds it on the way, the bot can't
    if not at and not pd.s then return "item-start", "needs " .. pname .. ", which starts from an item or object the bot couldn't take yet" end
    if not at then return "not-in-route", "needs " .. pname .. ", which isn't in the route" end
    -- in this same step and blocked too: it follows from that quest's own problem
    if at.key == key and at.i == i then return "cascade", "needs " .. pname .. ", in this same step and blocked itself" end
    local here = routeOrder[key] or 999
    if at.o > here or (at.o == here and at.i > i) then return "order", "needs " .. pname .. ", which comes later in the route (" .. at.key .. " step " .. at.i .. ")" end
    -- why the guide counts that earlier step as done (its own words)
    local stepWhy
    for _, rr in ipairs(RG.ROUTE or {}) do
      if rr.zone .. "|" .. rr.from == at.key then local d2, w2 = RG.StepIsDone(rr, at.i); stepWhy = d2 and tostring(w2 or "done") or "not done" end
    end
    if stepWhy and stepWhy:lower():find("grey") then
      return "grey-prereq", "needs " .. pname .. " (" .. at.key .. " step " .. at.i .. "), which the guide skipped as grey (it says: " .. stepWhy .. ")"
    end
    if stepWhy == "not done" then
      return "skipped-step", "needs " .. pname .. " (" .. at.key .. " step " .. at.i .. "), whose step isn't done, but the guide moved on to this one"
    end
    -- what the guide itself thinks of the prerequisite
    local isDone = function(q) return S.done[q] == true end
    local why, never
    if RG.QuestBlocked then why, never = RG.QuestBlocked(p, pd, isDone) end
    if never then
      return "hidden-prereq", "needs " .. pname .. " (" .. at.key .. " step " .. at.i .. "), which the guide hides as never available: " .. tostring(why)
    end
    return "earlier", "needs " .. pname .. " from an earlier step (" .. at.key .. " step " .. at.i .. ") that counted as done without it" ..
      (why and (" (the guide says it's blocked: " .. tostring(why) .. ")") or "")
  end

  -- Gear: equip what the add-on calls an upgrade (RG.Compare), and check it doesn't contradict itself
  R.gear = { equips = {}, score = {} }
  local equipCount, noFlip = {}, {}
  local function gearUp()
    if not Inv then return end
    for _ = 1, 20 do
      local did = false
      for _, x in ipairs(Inv.bagItems()) do
        local it = I.get(x.id)
        if it and Inv.EQUIP[it.loc] and it.req <= me.level and not noFlip[x.id] then
          local d, slot = RG.Compare(it.link)
          if d and d > 0.5 then
            local before = Inv.gearScore(RG)
            local beforeEquip = {}
            for s2, id2 in pairs(Inv.equip) do beforeEquip[s2] = id2 end
            local ok, eslot, old = Inv.equipFrom(x.bag, x.slot, slot)
            if ok then
              did = true
              equipCount[x.id] = (equipCount[x.id] or 0) + 1
              note(string.format("equips %s (+%.0f)%s", it.name, d, old and (" over " .. I.get(old).name) or ""))
              -- the whole outfit, by the add-on's own scoring, must not get worse (a shield taking off a two-hander...)
              local after = Inv.gearScore(RG)
              if after < before - 0.5 then
                local lost = {}
                for s2, id2 in pairs(beforeEquip) do if Inv.equip[s2] ~= id2 and s2 ~= eslot then lost[#lost + 1] = I.get(id2).name end end
                problem("downgrade", string.format("the add-on called %s a +%.0f upgrade, but putting it on lowered the score of everything worn from %.0f to %.0f%s",
                  it.name, d, before, after, #lost > 0 and (" (it took off " .. table.concat(lost, ", ") .. ")") or ""), "level " .. me.level)
              end
              R.gear.equips[#R.gear.equips + 1] = { level = me.level, name = it.name, delta = d }
              wait(1)
              if equipCount[x.id] > 1 then
                problem("flip-flop", "the bot equipped " .. it.name .. " (" .. x.id .. ") more than once: the add-on keeps calling items it replaced upgrades again", "level " .. me.level)
                noFlip[x.id] = true
              end
              if old then
                local od = RG.Compare(I.get(old).link, eslot)
                if od and od > 0.5 then
                  problem("flip-flop", string.format("right after %s replaced %s, the add-on calls %s an upgrade again (+%.0f)", it.name, I.get(old).name, I.get(old).name, od), "level " .. me.level)
                  noFlip[old] = true
                end
              end
              break   -- the bags changed: look again
            end
          end
        end
      end
      if not did then break end
    end
  end
  -- a vendor visit: the add-on gets its turn first (selling junk), then the bot sells what isn't an upgrade
  local handedAtVendor = 0
  local function vendor()
    if not Inv then return end
    Inv.visitVendor(function(x)
      local it = I.get(x.id)
      if not it or it.classID == 12 then return false end
      if it.quality == 0 then return true end
      if Inv.EQUIP[it.loc] and it.req <= me.level then
        local d = RG.Compare(it.link)
        return not d or d <= 0
      end
      return false
    end)
  end
  local lastLevel, lastHanded = me.level, 0

  -- Quests that start from an object or an item aren't in the route (no giver to send you to): a player comes across
  -- them. When the step's quests wait on one, the bot goes where it starts, takes it, does it and hands it in.
  R.found = 0
  local function missingStarter(id, depth)
    depth = depth or 0
    local d = RG.QDATA[id]
    if not d or depth > 8 then return nil end
    local missing = {}
    for _, p in ipairs(d.pg or {}) do if not S.done[p] and not Wd.entry(p) then missing[#missing + 1] = p end end
    if d.ps and #d.ps > 0 then
      local any = false
      for _, p in ipairs(d.ps) do if S.done[p] or Wd.entry(p) then any = true end end
      if not any then for _, p in ipairs(d.ps) do missing[#missing + 1] = p end end
    end
    for _, p in ipairs(missing) do
      local pd = RG.QDATA[p]
      if pd and not pd.s and Wd.canAccept(p) then return p end
      -- further up the chain: Book Return waits on Shhh!, which waits on ... Nibbled-On Book, found on the way
      local deeper = pd and missingStarter(p, depth + 1)
      if deeper then return deeper end
    end
  end
  local function doFound(p)
    local pd = RG.QDATA[p]
    walk(Wd.starterSpot(p))
    local ok, why = Wd.accept(p)
    if not ok then return false, why end
    R.found = R.found + 1
    note("finds " .. tostring(pd.n) .. " (starts from " .. ((Wd.starters[p] or {}).k == "i" and "a dropped item" or "an object") .. ")")
    for _ = 1, 8 do
      local sp = Wd.objectiveSpot(p)
      if not sp then break end
      walk(sp); local _, secs = Wd.work(p); wait(math.max(secs, 5))
    end
    Wd.work(p)
    if pd.e then walk(pd.e) end
    Wd.handIn(p)
    wait(5)
    return true
  end

  -- Class quests: the tracker lists them beside the route ("Class quests: pick up now", RG.ClassQuests); a player
  -- following it does them when it says so. The bot does the same, and notes when each one became available and
  -- when it was handed in.
  R.classQuests = {}
  local cqSeen, cqSkip = {}, {}
  local function doClassQuests()
    if not RG.ClassQuests then return end
    local moment = S.stats.handedIn .. ":" .. me.level   -- (a quest it couldn't take is tried again after the next change)
    for _, q in ipairs(RG.ClassQuests(5)) do
      if not cqSeen[q.id] then cqSeen[q.id] = { id = q.id, name = q.name, lvl = q.lvl, req = q.req, listed = me.level } end
      local rec = cqSeen[q.id]
      -- "pick up now" for a quest well above your level (Brutal Armor, level 30, at 20): noted; the bot, like a
      -- player, waits until it's within 3 levels (the world can't make a quest harder for being above you)
      if q.now and q.lvl and q.lvl > me.level + 3 then rec.tooHigh = rec.tooHigh or me.level end
      if q.now and (not q.lvl or q.lvl <= me.level + 3) and cqSkip[q.id] ~= moment and not S.done[q.id] then
        rec.now = rec.now or me.level
        W.phase = "class quest " .. tostring(q.name)
        walk(q.wp)
        local ok, why = Wd.accept(q.id)
        if not ok then cqSkip[q.id] = moment; rec.failed = why
        else
          note("class quest: " .. tostring(q.name))
          local d = RG.QDATA[q.id]
          for _ = 1, 8 do local sp = Wd.objectiveSpot(q.id); if not sp then break end; walk(sp); local _, secs = Wd.work(q.id); wait(math.max(secs, 5)) end
          Wd.work(q.id)
          if d and d.e then walk(d.e) end
          local handed = Wd.handIn(q.id)
          if handed then rec.done = me.level; rec.failed = nil; R.classQuests[#R.classQuests + 1] = rec else cqSkip[q.id] = moment; rec.failed = "couldn't hand it in" end
          wait(5)
        end
        return true
      end
    end
  end

  local lastSig, same = nil, 0
  while me.level < untilLevel and R.actions < maxActions do
    -- the tracker's class quests come first when it says "pick up now"
    if doClassQuests() then R.actions = R.actions + 1 end
    -- after a hand-in or a level-up: put on upgrades; every 10 hand-ins (or with full bags), a vendor
    if Inv and (S.stats.handedIn ~= lastHanded or me.level ~= lastLevel) then
      if me.level ~= lastLevel and me.level % 10 == 0 then
        local sc, n = Inv.gearScore(RG)
        R.gear.score[#R.gear.score + 1] = { level = me.level, score = sc, slots = n }
      end
      lastHanded, lastLevel = S.stats.handedIn, me.level
      W.phase = "gear (level " .. me.level .. ")"
      gearUp()
      local freeSlots = 56 - #Inv.bagItems()
      if S.stats.handedIn - handedAtVendor >= 10 or freeSlots < 8 then handedAtVendor = S.stats.handedIn; vendor() end
    end
    R.actions = R.actions + 1
    W.phase = "playing (level " .. me.level .. ")"
    local r = RG.CurrentRouteEntry and RG.CurrentRouteEntry()
    if not r then
      grind("the guide has no route entry for this level")
    else
      local i = RG.NextStep(r)
      local key = r.zone .. "|" .. r.from
      local text = i and RG.STEPS[key] and RG.STEPS[key][i] or nil
      if not i then
        grind("every step in " .. r.zone .. " (" .. r.from .. "-" .. r.to .. ") is done")
      else
        local where = key .. " step " .. i
        R.steps[where] = true
        local lines = RG.StepQuestLines(r, i)
        local l
        for _, x in ipairs(lines or {}) do if x.act ~= "later" then l = x break end end
        local progress = 0
        for _, e in ipairs(S.log) do for _, o in ipairs(e.objs) do progress = progress + o.have end end
        local sig = where .. ":" .. (l and (l.act .. ":" .. l.id) or "none") .. ":" .. #S.log .. ":" .. Wd.state.stats.handedIn .. ":" .. me.level .. ":" .. progress
        if sig == lastSig then same = same + 1 else same = 0 end
        lastSig = sig
        if same >= 3 then
          problem("stuck", "the guide keeps sending the bot to the same thing with nothing changing: " ..
            (l and (l.act .. " " .. tostring(l.name) .. " (" .. l.id .. ")") or "this step") .. ". The bot ticked the step to move on.", where .. ": " .. tostring(text))
          tick(key, i, text, true); R.tickedHand = R.tickedHand + 1; same = 0
        elseif lines == nil then
          -- a hand-written step: go there and tick it
          local wp = RG.StepWaypoint and RG.StepWaypoint(r, i)
          walk(wp)
          if not RG.StepIsDone(r, i) then
            note("ticks: " .. tostring(text):sub(1, 90))
            tick(key, i, text); R.ticked = R.ticked + 1
          end
        elseif not l then
          if #lines == 0 then
            problem("empty", "a step that isn't done has no quests left to do; the bot ticked it", where .. ": " .. tostring(text))
            tick(key, i, text, true); R.tickedHand = R.tickedHand + 1
          else
            -- everything here opens later: for your level, grind; otherwise say why each quest is blocked
            local why, levelOnly = {}, true
            for _, x in ipairs(lines) do
              why[#why + 1] = tostring(x.name) .. ": " .. tostring(x.npc)
              if not tostring(x.npc):lower():find("level") then levelOnly = false end
            end
            local starter
            for _, x in ipairs(lines) do starter = starter or missingStarter(x.id) end
            if starter then
              local ok, why2 = doFound(starter)
              if not ok then
                problem("starter", "the step waits on " .. tostring(RG.QDATA[starter].n) .. " (" .. starter .. "), which starts from an item or object, but the bot couldn't take it: " .. tostring(why2), where)
                tick(key, i, text, true); R.tickedHand = R.tickedHand + 1
              end
            elseif levelOnly then grind("the step's quests need a higher level (" .. table.concat(why, "; ") .. ")")
            else
              -- one problem per blocked quest, by cause; a cascade (the bot skipped the prerequisite) isn't the guide's fault
              for _, x in ipairs(lines) do
                if not tostring(x.npc):lower():find("level") then
                  local kind, sentence = blockedWhy(x.id, key, i)
                  problem(kind, tostring(x.name) .. " (" .. x.id .. ") is blocked: " .. sentence, where .. ": " .. tostring(text))
                end
              end
              tick(key, i, text, true); R.tickedHand = R.tickedHand + 1
            end
          end
        elseif l.act == "pickup" then
          if not l.wp then problem("no-waypoint", "no waypoint to pick up " .. tostring(l.name) .. " (" .. l.id .. ")", where) end
          walk(l.wp)
          local ok, why = Wd.accept(l.id)
          if ok then note("accepts " .. tostring(l.name)) else
            problem("pickup", "the guide says pick up " .. tostring(l.name) .. " (" .. l.id .. "), but the game says: " .. tostring(why), where .. ": " .. tostring(text))
          end
          wait(5)
        elseif l.act == "doing" then
          local wp = l.wp
          if not wp then
            local sp = Wd.objectiveSpot(l.id)
            wp = sp
          end
          walk(wp)
          local moved, secs = Wd.work(l.id)
          if moved == 0 then
            -- the guide's waypoint isn't where the objective is: try the world's own spot, and say so
            local sp = Wd.objectiveSpot(l.id)
            if sp and l.wp then
              problem("waypoint", "the guide's waypoint for " .. tostring(l.name) .. " (" .. l.id .. ") isn't near its objective", where)
              walk(sp)
              moved, secs = Wd.work(l.id)
            end
          end
          if moved > 0 then note("works on " .. tostring(l.name)) end
          wait(math.max(secs, 5))
        elseif l.act == "turnin" then
          walk(l.wp)
          local ok, why = Wd.handIn(l.id)
          if ok then note("hands in " .. tostring(l.name)) else
            problem("turnin", "the guide says hand in " .. tostring(l.name) .. " (" .. l.id .. "), but: " .. tostring(why), where)
          end
          wait(5)
        end
      end
    end
  end
  R.endLevel = me.level
  notePlace()
  R.classSeen = {}
  for _, rec in pairs(cqSeen) do R.classSeen[#R.classSeen + 1] = rec end
  table.sort(R.classSeen, function(a, b) return (a.req or 0) < (b.req or 0) end)
  -- cascades are reported, but only the first cause counts as a failure
  R.info = {}
  local keep = {}
  for _, p in ipairs(R.problems) do if p.kind == "cascade" or p.kind == "item-start" then R.info[#R.info + 1] = p else keep[#keep + 1] = p end end
  R.problems = keep
  return R
end

return P
