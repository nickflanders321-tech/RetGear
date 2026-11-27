-- Waypath+ on-screen tracker: quests first. The top line names the quest and the objective the arrow points
-- to; then your quests, pick-ups nearby and the route step. Gear, professions, dungeons and reminders live in the
-- main window now.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLDC = { 1, 0.82, 0 }   -- the tracker's gold (fixed: the restyle doesn't follow the accent setting)
local W = 300
local tr, lines, collapsed
-- The tracker's look (the restyle mockup): a WoW quest-log panel, dark leather and brass, gold titles in Marcellus.
-- Fixed colours: the accent setting tints the main window, not the tracker. StepView.lua and TrackerExtras.lua use
-- them too (RG.TPAL).
local P = {
  panel = { 0.071, 0.051, 0.035 }, border = { 0.42, 0.32, 0.15 }, inner = { 0.165, 0.122, 0.075 }, head = { 0.122, 0.086, 0.051 },
  gold = { 1, 0.82, 0 }, brass = { 0.79, 0.65, 0.29 }, light = { 0.94, 0.78, 0.37 }, ring = { 0.54, 0.416, 0.18 },
  btn = { 0.165, 0.114, 0.063 }, btnEdge = { 0.353, 0.263, 0.125 }, red = { 0.431, 0.043, 0.043 }, redEdge = { 0.69, 0.54, 0.227 },
  box = { 0.102, 0.071, 0.043 }, ink = { 0.949, 0.918, 0.847 }, muted = { 0.604, 0.541, 0.416 }, where = { 0.788, 0.722, 0.561 },
  strip = { 0.133, 0.094, 0.055 }, line = { 0.227, 0.165, 0.086 }, chip = { 0.18, 0.125, 0.063 }, dark = { 0.043, 0.031, 0.02 },
  bar = { 0.165, 0.102, 0.055 }, green = { 0.118, 1, 0 }, doneEdge = { 0.184, 0.478, 0.184 }, foot = { 0.086, 0.059, 0.035 },
  xp = { 0.54, 0.247, 0.82 },
}
RG.TPAL = P
-- the header (what it follows, and the boxed line under it) and the level bar along the bottom
local HEAD_H, FOOT_H = 64, 30
function RG.TrackerHeadH() return HEAD_H end
function RG.TrackerFootH() return FOOT_H end
local DISPLAY = "Interface\\AddOns\\Waypath\\Media\\Fonts\\Marcellus-Regular.ttf"
RG.TDISPLAY = DISPLAY
-- Marcellus for titles (the game's own font if it won't load)
local function dfont(fs, size)
  if not fs:SetFont(DISPLAY, size, "") then fs:SetFont("Fonts\\FRIZQT__.TTF", size, "") end
end
RG.TDisplayFont = dfont
-- A filled box with a 1-pixel edge, of plain textures on f itself (nothing of the game's; under f's own text, never a
-- frame over it). ox: how far it reaches out past f's sides. key: where it's kept on f, for a second box on one frame.
-- Called again, it only recolours (and shows it).
local function framed(f, fill, edge, alpha, sub, ox, key)
  key = key or "_fr"
  local fr = rawget(f, key)
  if not fr then
    sub, ox = sub or -8, ox or 0
    fr = {}
    fr.fill = f:CreateTexture(nil, "BACKGROUND", nil, sub); fr.fill:SetPoint("TOPLEFT", -ox, 0); fr.fill:SetPoint("BOTTOMRIGHT", ox, 0)
    for _, k in ipairs({ "t", "b", "l", "r" }) do fr[k] = f:CreateTexture(nil, "BORDER", nil, sub) end
    fr.t:SetPoint("TOPLEFT", -ox, 0); fr.t:SetPoint("TOPRIGHT", ox, 0); fr.t:SetHeight(1)
    fr.b:SetPoint("BOTTOMLEFT", -ox, 0); fr.b:SetPoint("BOTTOMRIGHT", ox, 0); fr.b:SetHeight(1)
    fr.l:SetPoint("TOPLEFT", -ox, 0); fr.l:SetPoint("BOTTOMLEFT", -ox, 0); fr.l:SetWidth(1)
    fr.r:SetPoint("TOPRIGHT", ox, 0); fr.r:SetPoint("BOTTOMRIGHT", ox, 0); fr.r:SetWidth(1)
    fr.SetShown = function(self, on) for _, k in ipairs({ "fill", "t", "b", "l", "r" }) do self[k]:SetShown(on and true or false) end end
    f[key] = fr
  end
  if fill then fr.fill:SetColorTexture(fill[1], fill[2], fill[3], alpha or 1); fr.fill:Show() else fr.fill:Hide() end
  for _, k in ipairs({ "t", "b", "l", "r" }) do fr[k]:SetColorTexture(edge[1], edge[2], edge[3], 1); fr[k]:Show() end
  return fr
end
RG.TFramed = framed
-- marks the line the arrow is pointing at
local ARROW = "|TInterface\\Minimap\\MinimapArrow:12:12|t"
local function isTarget(wp) return RG.ArrowTarget and RG.ArrowTarget(wp) end

function RG.StepIsDone(entry, i)
  local key = entry.zone .. "|" .. entry.from
  RG.db.stepsDone = RG.db.stepsDone or {}
  if RG.db.stepsDone[key .. "#" .. i] then return true, "ticked" end
  local steps = RG.STEPS[key]
  if steps and RG.StepAuto then
    local ok, why = RG.StepAuto(entry, steps[i])
    if ok then return true, why end
  end
  return false
end

-- The step to do next in a route entry. Not always the first open one: among the next few, a step where you can
-- hand something in, or whose quests are already in your log, or that's right where you are comes first (less
-- walking). It looks only a few steps ahead (later ones can depend on earlier ones) and keeps its pick unless another
-- is clearly better, so it doesn't flip back and forth as you move. Off in Settings: always the guide's order.
local LOOKAHEAD = 4
local stepMemo, stepMemoT = {}, nil
local stepHold = {}   -- key -> index chosen last time
function RG.ForgetNextStep() stepMemoT = nil end
function RG.NextStep(r)
  if not (r and RG.STEPS) then return nil end
  local key = r.zone .. "|" .. r.from
  local steps = RG.STEPS[key] or {}
  -- (worked out at most once a second, or straight away after a quest log change)
  local now = GetTime and GetTime() or 0
  if not stepMemoT or now - stepMemoT >= 1 or now < stepMemoT then stepMemo, stepMemoT = {}, now end
  if stepMemo[key] ~= nil then return stepMemo[key] or nil end
  local open = {}
  for i = 1, #steps do
    if not RG.StepIsDone(r, i) then open[#open + 1] = i; if #open >= LOOKAHEAD then break end end
  end
  local pick = open[1]
  if pick and #open > 1 and RG.Opt and RG.Opt("smartStepOrder") then
    local quests = RG.MyQuests and RG.MyQuests() or nil
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local px, py
    if here and C_Map.GetPlayerMapPosition then
      local pos = C_Map.GetPlayerMapPosition(here, "player")
      if pos and pos.GetXY then px, py = pos:GetXY() elseif pos then px, py = pos.x, pos.y end
      if RG.IsSecret and (RG.IsSecret(px) or RG.IsSecret(py)) then px, py = nil, nil end
    end
    local score, waits = {}, {}
    for rank, i in ipairs(open) do
      local s = rank   -- the guide's order
      local ql = RG.StepQuestLines and RG.StepQuestLines(r, i, quests)
      local turnin, doing, now, near, pickup = false, false, false, false, false
      for _, l in ipairs(ql or {}) do
        if l.act ~= "later" and not l.away then near = true end
        -- (only for something on this step's map or yours: one in another zone waits for the trip there)
        if not l.away then
          if l.act == "turnin" then turnin = true elseif l.act == "doing" then doing = true elseif l.act == "pickup" then pickup = true end
        end
        if l.act ~= "later" then now = true end
      end
      if turnin then s = s - 3 elseif doing then s = s - 2 end
      -- all it has left is in another zone: after the steps with something to do here
      if now and not near then s = s + 3 end
      -- every quest in it has to wait (for an earlier step's quest, a level...): any step with something to do
      -- now comes first, even one further on or further away (Gordo's Task before the Brill step that needs it)
      if ql and #ql > 0 and not now then s = s + 10; waits[i] = true end
      -- (standing at a step only helps one with something to do now: one that waits stays behind)
      local wp = RG.StepWaypoint and RG.StepWaypoint(r, i)
      if wp and px and wp[1] == here and not waits[i] then
        local dx, dy = (wp[2] / 100) - px, (wp[3] / 100) - py
        local d = math.sqrt(dx * dx + dy * dy)
        -- (right in a town where this step has quests to pick up or hand in: do them now, you're standing there)
        if d < 0.05 then s = s - ((pickup or turnin) and 4 or 3) elseif d < 0.12 then s = s - 1 end
      end
      score[i] = s
    end
    for _, i in ipairs(open) do if score[i] < score[pick] then pick = i end end
    -- keep last time's pick unless the new one is clearly better
    local held = stepHold[key]
    if held and held ~= pick and score[held] and score[held] - score[pick] < 1 then pick = held end
    -- standing right at the quest giver of a step further on, with a quest to take or hand in there now (beyond the
    -- next few steps: Islen Waterseer offers Cleansed Water Returns to Felwood the moment you hand in Seeking Spiritual
    -- Aid): that step, while you're there, rather than a trip back for it later
    if px and not (score[pick] and score[pick] <= -1) then
      for i = (open[#open] or 0) + 1, #steps do
        local wp = RG.StepWaypoint and RG.StepWaypoint(r, i)
        if wp and wp[1] == here then
          local dx, dy = (wp[2] / 100) - px, (wp[3] / 100) - py
          if dx * dx + dy * dy < 0.0009 and not RG.StepIsDone(r, i) then
            for _, l in ipairs(RG.StepQuestLines and RG.StepQuestLines(r, i, quests) or {}) do
              if (l.act == "pickup" or l.act == "turnin") and not l.away then pick = i break end
            end
            if pick == i then break end
          end
        end
      end
    end
    -- every one of the next few has to wait (Fragments of the Past waits on Winterspring's Troubled Spirits of
    -- Kel'Theril): the first open step further on that has something to do now, if there is one
    if waits[pick] then
      local last = open[#open]
      for i = last + 1, #steps do
        if not RG.StepIsDone(r, i) then
          for _, l in ipairs(RG.StepQuestLines and RG.StepQuestLines(r, i, quests) or {}) do
            if l.act ~= "later" then pick = i break end
          end
          if pick == i then break end
        end
      end
    end
  end
  stepHold[key] = pick
  stepMemo[key] = pick or false
  return pick
end

-- Ticking a task by hand can be undone: the last few ticks are remembered.
local UNDO_SHOW = 600   -- the tracker offers "Undo" for 10 minutes after a tick
function RG.TickStep(sk, text)
  RG.db.stepsDone = RG.db.stepsDone or {}
  RG.db.stepsDone[sk] = true
  RG.db.tickHistory = RG.db.tickHistory or {}
  local h = RG.db.tickHistory
  for i = #h, 1, -1 do if h[i].sk == sk then table.remove(h, i) end end
  h[#h + 1] = { sk = sk, text = text, t = time() }
  while #h > 10 do table.remove(h, 1) end
  if RG.Log then RG.Log("stepskip", sk) end
  RG.RefreshTracker(); if RG.RefreshUI then RG.RefreshUI() end
end
-- Puts the most recent hand-ticked task back on the list. Returns its text.
function RG.UndoTick()
  local h = RG.db and RG.db.tickHistory
  while h and #h > 0 do
    local e = table.remove(h)
    if RG.db.stepsDone and RG.db.stepsDone[e.sk] then
      RG.db.stepsDone[e.sk] = nil
      RG.RefreshTracker(); if RG.RefreshUI then RG.RefreshUI() end
      return e.text
    end
  end
end
local function lastTick(prefix)
  local h = RG.db.tickHistory
  local e = h and h[#h]
  if e and RG.db.stepsDone and RG.db.stepsDone[e.sk] and time() - (e.t or 0) <= UNDO_SHOW
    and e.sk:sub(1, #prefix) == prefix then return e end
end
local function plain(text) return ((text or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- The route entry you're on: the questing zone for your level that still has
-- open steps, falling back to any zone that fits.
local function currentEntry()
  local lvl = UnitLevel("player")
  -- standing in a new zone that has no steps yet (WoW Forever's quest data for it isn't out): stay with it
  -- instead of sending you somewhere else; the tracker shows its quests from your log
  local zoneMode = RG.RouteMode and RG.RouteMode() == "zone"
  local here = (zoneMode and RG.FollowZone and RG.FollowZone()) or RG.ZoneName() or ""
  if here ~= "" then
    for _, r in ipairs(RG.ROUTE) do
      if r.kind == "zone" and r.zone == here and lvl >= r.from - 1 and lvl <= r.to then
        local steps = RG.STEPS[r.zone .. "|" .. r.from]
        if steps and #steps == 0 then return r end
      end
    end
  end
  local function open(r)
    local steps = RG.STEPS[r.zone .. "|" .. r.from] or {}
    for i = 1, #steps do if not RG.StepIsDone(r, i) then return true end end
    return false
  end
  -- Zone quests (Smart.lua): the route never picks another zone than the one it follows (yours, or one you picked).
  -- Of that zone's route entries, the one for your level with work left, else the nearest in level with work, else a
  -- finished one (the tracker then says so and suggests where to go next); nil where the route has nothing (a city, a
  -- zone off the route).
  if zoneMode then
    -- (the zone you're in also covers the route's areas on its map: in the Valley of Trials you're "in Durotar", and
    -- at level 1 it's the Valley of Trials' steps you want; a zone you picked is just that zone)
    local _, picked = RG.FollowZone()
    -- (only an area without a map of its own, like the Valley of Trials, and only while your level fits it)
    local function onMap(r)
      if picked or not (RG.StepWaypoint and RG.MapZone) then return false end
      if (RG.ZONE_MAPS and RG.ZONE_MAPS[r.zone]) or lvl < r.from - 1 or lvl > r.to then return false end
      if r._zoneOf == nil then
        local wp = RG.StepWaypoint(r, 1)
        r._zoneOf = (wp and RG.MapZone(wp[1])) or false
      end
      return r._zoneOf == here
    end
    local best, bestD, done
    for _, r in ipairs(RG.ROUTE) do
      if r.kind == "zone" and (r.zone == here or onMap(r)) then
        if open(r) then
          local d = (lvl < r.from - 1 and (r.from - 1 - lvl)) or (lvl > r.to and (lvl - r.to)) or 0
          if not best or d < bestD then best, bestD = r, d end
        end
        done = done or r
      end
    end
    return best or done
  end
  if RG.SmartEntry then
    local ok, pick = pcall(RG.SmartEntry)
    if ok and pick then return pick end
  end
  -- 1. the first questing zone (in route order) for your level that still has work
  -- 2. else the next one coming up within 3 levels
  -- 3. else the zone for your level, finished (the tracker says so)
  local done
  for _, r in ipairs(RG.ROUTE) do
    if r.kind == "zone" and lvl >= r.from and lvl <= r.to then
      if open(r) then return r end
      done = done or r
    end
  end
  for _, r in ipairs(RG.ROUTE) do
    if r.kind == "zone" and r.from > lvl and r.from <= lvl + 3 and open(r) then return r end
  end
  return done
end

-- The zones to go to next, best first, other than skip: { { r = entry, why = text }, ... }. The smart route's ranking
-- (zones with something you can do now), then the route's next zones coming up within 3 levels (an Orc done with
-- Durotar at 10: the Barrens, from 12).
local function nextZones(skip, max)
  local out, seen = {}, {}
  local lvl = UnitLevel("player") or 1
  local function add(r, why)
    if #out < max and r ~= skip and r.kind == "zone" and not seen[r.zone] and not (skip and r.zone == skip.zone) then
      seen[r.zone] = true; out[#out + 1] = { r = r, why = why }
    end
  end
  for _, o in ipairs((RG.SmartRank and RG.SmartRank()) or {}) do add(o.r, o.why) end
  for _, r in ipairs(RG.ROUTE or {}) do
    if r.kind == "zone" and r.to >= lvl and r.from <= lvl + 3 then
      local steps = RG.STEPS[r.zone .. "|" .. r.from] or {}
      local left = false
      for i = 1, #steps do if not RG.StepIsDone(r, i) then left = true break end end
      if left then add(r, r.from > lvl and ("from level " .. r.from) or "next on the route") end
    end
  end
  return out
end
function RG.TrackerBestNext(skip) local z = nextZones(skip, 1)[1]; return z and z.r.zone end
-- "Stay" mode, nothing left here: the best zones to go to next (from the smart route's ranking). Returns the new y;
-- RG.trackerN is the row count after them. Clicking one shows the way there in your chat (no arrow is set).
function RG.TrackerNextZones(n, y, item, skip)
  local shown = 0
  for _, o in ipairs(nextZones(skip, 3)) do
    do
      shown = shown + 1
      n = n + 1
      local z = o.r.zone
      y = item(n, y, GOLD .. "Next: |r|cffffffff" .. z .. "|r" .. GREY .. "  ·  " .. o.r.from .. "-" .. o.r.to .. "|r", { single = true, indent = 2,
        tip = "|cffffffff" .. z .. "|r\n" .. GREY .. tostring(o.why or "") .. "|r\n\n" .. GOLD .. "Click:|r how to get there",
        onClick = function()
          local t = RG.TravelSummary and RG.TravelSummary(z)
          RG.Print(z .. ": " .. (t or "see the Route tab for the way there."))
        end })
    end
  end
  if shown == 0 then n = n + 1; y = item(n, y, GREY .. "The Route tab has zones for your level.|r", { single = true, indent = 2, onClick = function() if RG.ShowTab then RG.ShowTab("route") end end }) end
  RG.trackerN = n
  return y
end

-- the map point of the first step still to do in a route entry (nil when it has none)
local function destWp(r)
  if not (r and RG.STEPS and RG.StepWaypoint) then return nil end
  local steps = RG.STEPS[r.zone .. "|" .. r.from] or {}
  local i = RG.NextStep(r)
  if i then return RG.StepWaypoint(r, i) end
  return RG.StepWaypoint(r, 1)
end
function RG.CurrentRouteEntry() local ok, r = pcall(currentEntry); return ok and r or nil end

-- A generated route step split into its quests, each with the one thing to do
-- next. Returns the list (hand-ins first, then pick-ups, then quests in your
-- log, then ones that open later), how many are done, how many count, and the
-- step's place and level range. nil for hand-written steps. Things in another zone than the step's (and yours) come
-- last: away = true.
--   { id, name, act = "turnin"|"pickup"|"doing"|"later", npc, wp, prog, how = how a quest without a giver starts, away }
local ACT_ORDER = { turnin = 1, pickup = 2, doing = 3, later = 4 }
-- A quest's kind and note (QuestNotes.lua, from Polestar's forever-db, CC BY 4.0): a short coloured tag for the line and
-- a sentence for its tooltip. nil when there is nothing to say.
local QTAG = { e = { "|cffff9f43Elite|r", "Elite or group quest: bring friends, or skip it and keep going." },
  s = { "|cff9fd4ffEscort|r", "Escort: if the NPC isn't there, someone else is escorting it. Wait a moment for it to come back." },
  t = { "|cffffd36bTimed|r", "Timed quest: the clock starts when you accept it, so be ready before you do." } }
local noteMemo = { [true] = {}, [false] = {} }   -- the notes never change: worked out once per quest
local questNote
function RG.QuestNote(id, skipElite)
  if not id then return nil end
  local m = noteMemo[skipElite and true or false]
  local v = m[id]
  if v == nil then v = questNote(id, skipElite) or false; m[id] = v end
  return v or nil
end
questNote = function(id, skipElite)
  local q = id and RG.QNOTE and RG.QNOTE[id]
  if not q then return nil end
  local tags, longs = {}, {}
  for c in (q.g or ""):gmatch(".") do
    local t = QTAG[c]
    if t and not (skipElite and c == "e") then tags[#tags + 1] = t[1]; longs[#longs + 1] = t[2] end
  end
  if #tags == 0 and not q.n then return nil end
  return { tag = #tags > 0 and table.concat(tags, " ") or nil, long = #longs > 0 and table.concat(longs, "\n") or nil, n = q.n }
end
local function noteTip(qn)
  if not qn then return "" end
  local about = {}
  if qn.long then about[#about + 1] = "|cffff9f43" .. qn.long .. "|r" end
  if qn.n then about[#about + 1] = qn.n end
  return #about > 0 and ("\n\n" .. table.concat(about, "\n")) or ""
end
function RG.StepQuestLines(entry, i, myQuests)
  local key = entry and (entry.zone .. "|" .. entry.from)
  local ids = key and RG.STEP_QUESTS and RG.STEP_QUESTS[key] and RG.STEP_QUESTS[key][i]
  if not (ids and RG.QDATA) then return nil end
  local isDone = RG.QuestDone or (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or function() return false end
  local byId = {}
  for _, q in ipairs(myQuests or (RG.MyQuests and RG.MyQuests()) or {}) do if q.id then byId[q.id] = q end end
  local lvl = UnitLevel("player") or 1
  local out, doneN, total = {}, 0, 0
  local handIn = {}   -- quests in your log, finished, that a quest of this step waits on (listed once)
  for _, id in ipairs(ids) do handIn[id] = true end   -- (one of the step's own has its own line)
  for _, id in ipairs(ids) do
    local d = RG.QDATA[id]
    if d and d.n and not d.rep and (not RG.QuestForMe or RG.QuestForMe(d)) and not (RG.HideProfQuest and RG.HideProfQuest(id)) then
      local done = isDone(id)
      local q = byId[id]
      local why, never
      -- grey and not in your log: optional, so it's left out (a grey one you already have still shows)
      if not done and not q and RG.QuestIsGrey and RG.QuestIsGrey(d.l) and not (RG.GreyButNeeded and RG.GreyButNeeded(id, isDone)) then done = true end
      if not done and not q then why, never = RG.QuestBlocked(id, d, isDone) end
      if never then done = true end   -- the other branch, a later step, or not for you: nothing to do here
      -- a dungeon quest while they're left out (one in your log, finished, can still be handed in)
      if not done and not (q and q.complete) and RG.DungeonQuestHidden and RG.DungeonQuestHidden(id) then done = true end
      total = total + 1
      if done then doneN = doneN + 1
      else
        local l = { id = id, name = d.n, level = d.l }
        if q and q.complete then
          l.act, l.npc = "turnin", d.e and d.e[4]
          l.wp = d.e and { d.e[1], d.e[2], d.e[3], d.e[4] ~= "" and d.e[4] or d.n }
        elseif q then
          l.act, l.prog, l.wp = "doing", q.prog, q.wp
        else
          -- what's still in the way: an earlier quest, your level, a profession, reputation...
          if why then
            l.act, l.npc = "later", why
            -- it waits on a quest you've finished but not handed in (Chillwind Horns on Felnok Steelspring, which
            -- belongs to an earlier zone's step): hand that one in here first
            for _, list in ipairs({ d.pg or {}, d.ps or {} }) do
              for _, p in ipairs(list) do
                local pq, pd = byId[p], RG.QDATA[p]
                if pq and pq.complete and not handIn[p] and pd and pd.e then
                  handIn[p] = true
                  out[#out + 1] = { id = p, name = pd.n or pq.title, level = pd.l, act = "turnin", npc = pd.e[4],
                    wp = { pd.e[1], pd.e[2], pd.e[3], pd.e[4] ~= "" and pd.e[4] or pd.n } }
                end
              end
            end
          elseif not d.s and d.si and d.si[4] and d.si[4][1] then
            -- it starts from an object you click or an item that always drops there (one that only sometimes drops
            -- never gets here: QuestBlocked leaves it out until you have it)
            local si, p = d.si, d.si[4][1]
            local from = (si[1] == "i" and si[3] and si[3][p[4]] or si[3][1]) or si[2]
            l.act, l.npc = "pickup", from
            l.how = si[1] == "o" and ("Click " .. si[2] .. " to start this quest.")
              or (si[3] and #si[3] > 0) and ("Kill " .. from .. " and loot " .. si[2] .. ": it starts this quest.")
              or ("Pick up " .. si[2] .. " here: it starts this quest.")
            l.wp = { p[1], p[2], p[3], from }
          elseif d.bi and d.e and RG.HasBringItems(d) then
            -- its items are in your bags: talking to the giver hands them in
            l.act, l.npc, l.bi = "turnin", d.e[4], true
            l.wp = { d.e[1], d.e[2], d.e[3], d.e[4] ~= "" and d.e[4] or d.n }
          elseif d.bi and RG.BringFarmable(d) then
            -- its items drop around here (QuestBlocked lets it through only then): collect them first, then hand them
            -- in as you take it (Salve via Hunting: 6 Corrupted Soul Shards from the oozes and owls)
            local f = RG.BringFarmable(d)[1]
            local count = (C_Item and C_Item.GetItemCount) or GetItemCount
            local have = count and count(f.item) or 0
            l.act, l.farm, l.npc = "doing", true, f.o[2]
            l.prog = math.min(have, f.need) .. "/" .. f.need
            local p = f.o[4][1]
            l.wp = { p[1], p[2], p[3], f.o[2] }
          else
            l.act, l.npc = "pickup", d.s and d.s[4]
            l.noGiver = not d.s
            l.wp = d.s and { d.s[1], d.s[2], d.s[3], d.s[4] ~= "" and d.s[4] or d.n }
          end
        end
        out[#out + 1] = l
      end
    end
  end
  -- What can be done on the step's own map (or the one you're on) comes first; a hand-in or an objective in another
  -- zone waits until you go there (it's batched with the next trip instead of sending you back and forth)
  local hub = RG.StepWaypoint and RG.StepWaypoint(entry, i)
  local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  for k, l in ipairs(out) do
    l._k = k
    l.away = (l.wp and hub and l.wp[1] ~= hub[1] and l.wp[1] ~= here) and true or nil
  end
  table.sort(out, function(a, b)
    if (a.away or false) ~= (b.away or false) then return not a.away end
    if a.act ~= b.act then return ACT_ORDER[a.act] < ACT_ORDER[b.act] end
    return a._k < b._k
  end)
  local text = RG.STEPS[key] and RG.STEPS[key][i] or ""
  local place, levels = text:gsub("^At ", ""):match("^(.-) %((levels? [%d%-]+)%)")
  if place then place = place:gsub("^the ", "The ", 1) end
  return out, doneN, total, place, levels
end

-- True once every quest for a dungeon is turned in (nothing left to collect or do there).
-- Quests from the data whose earlier steps you haven't done yet don't count.
function RG.QuestPrereqsMet(id)
  local d = id and RG.QDATA and RG.QDATA[id]
  if not d then return true end
  local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
  if not done then return true end
  local why = RG.QuestBlocked(id, d, done)
  if why and not why:find("^at level") then return false end
  return (d.r or 1) <= (UnitLevel("player") or 1) + 2
end
function RG.DungeonQuestsDone(dq)
  if not (dq and dq.quests and #dq.quests > 0 and RG.QuestState) then return false end
  local anyDone = false
  for _, q in ipairs(dq.quests) do
    if RG.QuestState((q[1]:gsub("%s*%(.-%)$", ""))) == "done" then anyDone = true
    elseif not q.id or RG.QuestPrereqsMet(q.id) then return false end
  end
  return anyDone   -- quests you can't take yet don't count as finished
end
local function nextDungeon()
  local lvl = UnitLevel("player")
  for _, r in ipairs(RG.ROUTE) do
    local dq = r.kind == "dungeon" and RG.DUNGEON_QUESTS[r.zone]
    if dq and lvl >= dq.prep and lvl <= r.to and not RG.DungeonQuestsDone(dq) then return r, dq end
  end
end

local function nextUpgrade()
  local lvl, best = UnitLevel("player")
  for _, g in ipairs(RG.GUIDE) do
    if g.id and g.lvl <= lvl + 2 and g.lvl >= lvl - 8 and not RG.OwnState(g.id) and RG.GearGettable(g) then
      local d = RG.GuideDelta(g)
      if d and d > 0.5 and (not best or d > best.d) then best = { g = g, d = d } end
    end
  end
  return best
end

-- ---------------------------------------------------------------------------
-- Frame
-- ---------------------------------------------------------------------------
-- Tracker text: Inter like the window, with the game's narrow font as the fallback (and as an option).
local ARIAL = "Fonts\\ARIALN.TTF"
local function tfont(fs, size)
  if RG.Opt("trackerInter") and not RG.trInterBad and RG.FONTS then
    if fs:SetFont(RG.FONTS.medium, size, "") then return end
  end
  fs:SetFont(ARIAL, size, "")
end
-- a font that lays text out at no width is broken here: stop using it
local function tcheck(fs, text)
  if text and text ~= "" and not RG.trInterBad and RG.Opt("trackerInter") and (fs:GetStringWidth() or 0) < 1 then
    RG.trInterBad = true
    local _, size = fs:GetFont()
    fs:SetFont(ARIAL, size or 12, ""); fs:SetText(""); fs:SetText(text)
  end
end

-- A small right-click menu of our own (not a Blizzard dropdown, so nothing can be blocked or tainted).
local menuFrame, menuCatcher
function RG.ShowMenu(entries, title, anchor)
  if not entries or #entries == 0 then return end
  if not menuFrame then
    menuFrame = CreateFrame("Frame", "WaypathMenu", UIParent, "BackdropTemplate")
    menuFrame:SetFrameStrata("FULLSCREEN_DIALOG"); menuFrame:SetClampedToScreen(true)
    framed(menuFrame, P.panel, P.border, 0.98)
    menuFrame.btns = {}
    menuCatcher = CreateFrame("Button", nil, UIParent)
    menuCatcher:SetAllPoints(UIParent); menuCatcher:SetFrameStrata("FULLSCREEN"); menuCatcher:RegisterForClicks("AnyUp")
    menuCatcher:SetScript("OnClick", function() menuFrame:Hide() end)
    menuFrame:SetScript("OnHide", function() menuCatcher:Hide() end)
    menuFrame:Hide(); menuCatcher:Hide()
    tinsert(UISpecialFrames, "WaypathMenu")
  end
  for _, b in ipairs(menuFrame.btns) do b:Hide() end
  local y, wMax = 8, 150
  local function row(i, text, fn, head)
    local b = menuFrame.btns[i]
    if not b then
      b = CreateFrame("Button", nil, menuFrame)
      b:SetHeight(20)
      b.t = b:CreateFontString(nil, "OVERLAY"); b.t:SetPoint("LEFT", 10, 0); b.t:SetJustifyH("LEFT")
      b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 0.82, 0, 0.1)
      b.t:SetTextColor(P.ink[1], P.ink[2], P.ink[3])
      b:RegisterForClicks("LeftButtonUp")
      b:SetScript("OnClick", function(self) menuFrame:Hide(); if self.fn then pcall(self.fn) end end)
      menuFrame.btns[i] = b
    end
    if RG.Font then RG.Font(b.t, head and "regular" or "medium", head and 11 or 12) else b.t:SetFont("Fonts\\ARIALN.TTF", 12, "") end
    b.t:SetText(text); b.fn = not head and fn or nil
    b.hl:SetShown(not head)
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, -y); b:SetPoint("TOPRIGHT", -4, -y)
    b:Show()
    wMax = math.max(wMax, (b.t:GetStringWidth() or 100) + 28)
    y = y + 20
  end
  local i = 0
  if title then i = i + 1; row(i, GREY .. title .. "|r", nil, true) end
  -- (an entry { text, fn }; { text, head = true } is a heading, { text, off = true } a greyed-out line)
  for _, e in ipairs(entries) do
    i = i + 1
    if e.head then row(i, GREY .. e[1] .. "|r", nil, true)
    elseif e.off then row(i, "|cff6a6a6a" .. e[1] .. "|r", nil, true)
    else row(i, e[1], e[2]) end
  end
  menuFrame:SetSize(wMax, y + 8)
  if anchor and anchor.GetBottom then
    menuFrame:ClearAllPoints(); menuFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    menuCatcher:Show(); menuFrame:Show()
    return
  end
  local cx, cy = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  if type(s) ~= "number" or s <= 0 then s = 1 end
  if type(cx) ~= "number" or type(cy) ~= "number" then cx, cy = 600, 600 end
  menuFrame:ClearAllPoints(); menuFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / s - 6, cy / s + 6)
  menuCatcher:Show(); menuFrame:Show()
end

local function line(i)
  if lines[i] then return lines[i] end
  local b = CreateFrame("Button", nil, tr.body)
  b:SetWidth(W - 24)
  b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFont("Fonts\\ARIALN.TTF", 13, ""); b.text:SetPoint("TOPLEFT", 16, 0); b.text:SetWidth(W - 44); b.text:SetJustifyH("LEFT"); b.text:SetWordWrap(true)
  b.right = b:CreateFontString(nil, "OVERLAY"); b.right:SetFont("Fonts\\ARIALN.TTF", 10, ""); b.right:SetPoint("TOPRIGHT", 0, -1); b.right:SetJustifyH("RIGHT")
  b.right:SetShadowColor(0, 0, 0, 0.9); b.right:SetShadowOffset(1, -1)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetPoint("TOPLEFT", -4, 1); b.hl:SetPoint("BOTTOMRIGHT", 4, -1); b.hl:SetColorTexture(1, 1, 1, 0.06)
  b.box = b:CreateTexture(nil, "ARTWORK"); b.box:SetSize(12, 12); b.box:SetPoint("TOPLEFT", 0, -1)
  b.check = b:CreateTexture(nil, "OVERLAY"); b.check:SetSize(12, 12); b.check:SetPoint("CENTER", b.box, "CENTER", 0, 0); b.check:SetTexture("Interface\\AddOns\\Waypath\\Media\\Check"); b.check:SetVertexColor(0.05, 0.07, 0.07, 1)
  -- a route step's number in its ring, and the band behind the step you're on
  b.num = b:CreateFontString(nil, "OVERLAY"); b.num:SetFont("Fonts\\ARIALN.TTF", 9, ""); b.num:SetPoint("CENTER", b.box, "CENTER", 0, 0); b.num:Hide()
  b.band = b:CreateTexture(nil, "BACKGROUND"); b.band:SetPoint("TOPLEFT", -6, 2); b.band:SetPoint("BOTTOMRIGHT", 6, -3); b.band:SetColorTexture(P.gold[1], P.gold[2], P.gold[3], 0.07); b.band:Hide()
  -- a section's header: a brass-edged bar, its title in gold, the fold mark on the right
  b.secF = framed(b, P.bar, P.border, 1, -6, 4, "_sec"); b.secF:SetShown(false)
  b.fold = b:CreateFontString(nil, "OVERLAY"); b.fold:SetFont("Fonts\\ARIALN.TTF", 14, ""); b.fold:SetPoint("TOPRIGHT", -3, -2)
  b.fold:SetTextColor(P.gold[1], P.gold[2], P.gold[3]); b.fold:Hide()
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, btn)
    if btn == "RightButton" and self.menu and IsShiftKeyDown and IsShiftKeyDown() then RG.ShowMenu(self.menu()); return end   -- Shift + right-click: more options
    if btn == "RightButton" and self.onRightClick then self.onRightClick(); return end
    if btn == "LeftButton" and self.wpClick then
      -- a place: the line itself is the button. Your own click (tick, open) still runs; a plain click also sends the arrow.
      -- if your click already pinned this spot (Follow), the arrow is on: toggling it again would switch it straight off
      local was = RG.ArrowTarget and RG.ArrowTarget(self.wpClick)
      if self.onClick then self.onClick() end
      if not (IsShiftKeyDown and IsShiftKeyDown()) then
        if not was and RG.ArrowTarget and RG.ArrowTarget(self.wpClick) then
          if RG.RefreshArrow then RG.RefreshArrow() end
        else
          RG.ArrowTo(self.wpClick)
        end
      end
      return
    end
    if self.onDoubleClick then
      -- wait a moment so a double-click doesn't also do the single-click action
      local now = GetTime()
      if self.pending and now - self.pending < 0.3 then self.pending = nil; self.onDoubleClick(); return end
      self.pending = now
      local single = self.onClick
      C_Timer.After(0.3, function() if self.pending == now then self.pending = nil; if single then single() end end end)
      return
    end
    if self.onClick then self.onClick() end
  end)
  b:SetScript("OnEnter", function(self)
    local tip = self.tip
    if self.tipFn then local ok, t = pcall(self.tipFn); if ok and t then tip = t end end
    if tip then GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(tip, 1, 1, 1, 1, true); GameTooltip:Show() end
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  lines[i] = b
  return b
end

local function build()
  tr = CreateFrame("Frame", "WaypathTracker", UIParent, "BackdropTemplate")
  tr:SetWidth(W); tr:SetClampedToScreen(true); tr:SetMovable(true); tr:EnableMouse(true); tr:SetFrameStrata("MEDIUM")
  -- dark leather with a brass edge and a darker line inside it; the header a shade lighter, ruled off in brass
  framed(tr, P.panel, P.border, RG.db.trackerAlpha or 0.92)
  local inner = CreateFrame("Frame", nil, tr); inner:SetPoint("TOPLEFT", 1, -1); inner:SetPoint("BOTTOMRIGHT", -1, 1)
  framed(inner, nil, P.inner)
  tr.headBg = tr:CreateTexture(nil, "BACKGROUND", nil, -7); tr.headBg:SetPoint("TOPLEFT", 1, -1); tr.headBg:SetPoint("TOPRIGHT", -1, -1); tr.headBg:SetHeight(33)
  tr.headBg:SetColorTexture(P.head[1], P.head[2], P.head[3], 1)
  tr.headLine = tr:CreateTexture(nil, "BORDER"); tr.headLine:SetPoint("TOPLEFT", 1, -34); tr.headLine:SetPoint("TOPRIGHT", -1, -34); tr.headLine:SetHeight(1)
  tr.headLine:SetColorTexture(P.border[1], P.border[2], P.border[3], 1)
  local pos = RG.db.trackerPos
  if pos then tr:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else tr:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -260) end
  -- (a place saved by its middle or bottom made the tracker grow upwards, over whatever sits above it: pin its top)
  if pos and not tostring(pos[1]):find("^TOP") and C_Timer and C_Timer.After then C_Timer.After(0, function() pcall(RG.TrackerSavePos) end) end
  tr:RegisterForDrag("LeftButton")
  tr:SetScript("OnDragStart", function(self) if not RG.Opt("trackerLocked") and not (RG.TrackerFrozen and RG.TrackerFrozen()) then self:StartMoving() end end)
  -- Ctrl + mouse wheel: size  ·  Shift + mouse wheel: width
  tr:EnableMouseWheel(true)
  tr:SetScript("OnMouseWheel", function(self, delta)
    if IsControlKeyDown and IsControlKeyDown() then
      RG.db.trackerScale = math.max(0.6, math.min(1.6, (RG.db.trackerScale or 1) + delta * 0.05))
    elseif IsAltKeyDown and IsAltKeyDown() then
      RG.db.trackerAlpha = math.max(0.15, math.min(0.95, (RG.db.trackerAlpha or 0.5) + delta * 0.05))
    elseif IsShiftKeyDown and IsShiftKeyDown() then
      RG.db.trackerWidth = math.max(240, math.min(560, (RG.db.trackerWidth or 300) + delta * 20))
    else
      -- the mouse wheel on its own: scroll the list
      if RG.TrackerScrollBy then RG.TrackerScrollBy(delta) end
      return
    end
    RG.RefreshTracker()
  end)
  tr:SetScript("OnDragStop", function(self) if InCombatLockdown() then return end self:StopMovingOrSizing(); RG.TrackerSavePos() end)
  -- Edit Mode / /wp move shows it with the other pop-ups (it keeps its own saved place, by its top-right corner)
  if RG.RegisterMover then
    RG.RegisterMover(tr, "tracker", "Tracker", nil, nil, { own = {
      apply = function(f)
        local p = RG.db.trackerPos
        f:ClearAllPoints()
        if p then f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -260) end
      end,
      save = function() RG.TrackerSavePos() end,
      reset = function() RG.db.trackerPos = nil end,
    } })
  end

  -- The header: what the tracker follows (click for the menu: the guide, zone quests, your quest log, professions),
  -- a line about it under that (in zone quests: the zone, click to pick another), and the buttons on the right.
  -- The current step sits under the header (StepView.lua), then the list.
  -- the crest: the arrow in a brass ring
  local cdisc = tr:CreateTexture(nil, "ARTWORK"); cdisc:SetSize(22, 22); cdisc:SetPoint("TOPLEFT", 8, -6); cdisc:SetTexture("Interface\\AddOns\\Waypath\\Media\\Disc")
  cdisc:SetVertexColor(P.btn[1], P.btn[2], P.btn[3], 1)
  local cring = tr:CreateTexture(nil, "ARTWORK", nil, 1); cring:SetAllPoints(cdisc); cring:SetTexture("Interface\\AddOns\\Waypath\\Media\\Ring")
  cring:SetVertexColor(P.ring[1], P.ring[2], P.ring[3], 1)
  local crest = tr:CreateTexture(nil, "OVERLAY"); crest:SetSize(11, 11); crest:SetPoint("CENTER", cdisc, "CENTER", 0, 0); crest:SetTexture("Interface\\AddOns\\Waypath\\Media\\Icons\\Arrow"); crest:SetVertexColor(P.light[1], P.light[2], P.light[3], 1)
  tr.crest = crest
  -- (the old top line's texts: kept for anything that sets them, never shown)
  tr.title = RG.NewText(tr, "GameFontNormal"); tr.title:Hide()
  tr.goal = RG.NewText(tr, "GameFontHighlightSmall"); tr.goal:Hide()
  tr.dist = RG.NewText(tr, "GameFontHighlightSmall"); tr.dist:Hide()
  local function dragFrom(f)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() if not RG.Opt("trackerLocked") and not (RG.TrackerFrozen and RG.TrackerFrozen()) then tr:StartMoving() end end)
    f:SetScript("OnDragStop", function() if InCombatLockdown() then return end tr:StopMovingOrSizing(); RG.TrackerSavePos() end)
  end
  RG.TrackerDragFrom = dragFrom
  local mb = CreateFrame("Button", nil, tr); mb:SetHeight(22); mb:SetPoint("TOPLEFT", 34, -6); mb:SetPoint("TOPRIGHT", -88, -6)
  mb.text = mb:CreateFontString(nil, "OVERLAY"); mb.text:SetPoint("LEFT", 2, 0); mb.text:SetJustifyH("LEFT"); mb.text:SetWordWrap(false)
  dfont(mb.text, 15)
  mb.text:SetTextColor(P.gold[1], P.gold[2], P.gold[3]); mb.text:SetShadowColor(0, 0, 0, 0.9); mb.text:SetShadowOffset(1, -1)
  mb.chev = mb:CreateTexture(nil, "OVERLAY"); mb.chev:SetSize(10, 10); mb.chev:SetPoint("LEFT", mb.text, "RIGHT", 5, -1)
  mb.chev:SetTexture("Interface\\AddOns\\Waypath\\Media\\Icons\\FoldRight"); mb.chev:SetVertexColor(P.brass[1], P.brass[2], P.brass[3])
  if mb.chev.SetRotation then pcall(mb.chev.SetRotation, mb.chev, -math.pi / 2) end
  mb.hl = mb:CreateTexture(nil, "HIGHLIGHT"); mb.hl:SetAllPoints(); mb.hl:SetColorTexture(1, 0.82, 0, 0.06)
  mb:SetScript("OnClick", function(self) if RG.TrackerModeMenu then RG.TrackerModeMenu(self) end end)
  mb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("What the tracker follows", P.gold[1], P.gold[2], P.gold[3])
    GameTooltip:AddLine("Click: the ordered guide, one zone's quests, your quest log or your professions, and whether dungeon quests show.", 1, 1, 1, true)
    GameTooltip:AddLine(RG.Opt("trackerLocked") and "Locked (unlock in Settings)" or "Drag to move the tracker", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Mouse wheel: scroll the list  ·  Ctrl / Shift / Alt + wheel: size, width, see-through", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  mb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  dragFrom(mb)
  tr.modeBtn = mb
  -- the line under it
  -- (the button is the box: as wide as its text and caret, set as the text changes; what it counts sits at the
  -- tracker's right edge)
  local cx = CreateFrame("Button", nil, tr); cx:SetHeight(20); cx:SetPoint("TOPLEFT", 8, -40); cx:SetWidth(120)
  cx.boxF = framed(cx, P.box, P.btnEdge)
  cx.box = cx.boxF   -- (the old name)
  cx.right = cx:CreateFontString(nil, "OVERLAY"); cx.right:SetPoint("RIGHT", tr, "TOPRIGHT", -8, -50); cx.right:SetJustifyH("RIGHT"); cx.right:SetWordWrap(false)
  cx.left = cx:CreateFontString(nil, "OVERLAY"); cx.left:SetPoint("LEFT", 8, 0); cx.left:SetJustifyH("LEFT"); cx.left:SetWordWrap(false)
  tfont(cx.left, 11.5); tfont(cx.right, 11)
  cx.left:SetTextColor(P.muted[1], P.muted[2], P.muted[3]); cx.right:SetTextColor(P.muted[1], P.muted[2], P.muted[3])
  cx.chev = cx:CreateTexture(nil, "OVERLAY"); cx.chev:SetSize(9, 9); cx.chev:SetPoint("LEFT", cx.left, "RIGHT", 6, -1)
  cx.chev:SetTexture("Interface\\AddOns\\Waypath\\Media\\Icons\\FoldRight"); cx.chev:SetVertexColor(P.brass[1], P.brass[2], P.brass[3])
  if cx.chev.SetRotation then pcall(cx.chev.SetRotation, cx.chev, -math.pi / 2) end
  cx.chev:Hide()
  cx.hl = cx:CreateTexture(nil, "HIGHLIGHT"); cx.hl:SetPoint("TOPLEFT", 1, -1); cx.hl:SetPoint("BOTTOMRIGHT", -1, 1); cx.hl:SetColorTexture(1, 0.82, 0, 0.08)
  cx:SetScript("OnClick", function(self) if self.onClick then self.onClick(self) end end)
  cx:SetScript("OnEnter", function(self) if self.tip then GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(self.tip, 1, 1, 1, 1, true); GameTooltip:Show() end end)
  cx:SetScript("OnLeave", function() GameTooltip:Hide() end)
  dragFrom(cx)
  tr.ctx = cx

  -- the buttons on the right: small brass-edged squares, the fold button red like the game's close buttons
  local function hdrBtn(label, x, fn, tip, red)
    local b = CreateFrame("Button", nil, tr); b:SetSize(22, 22); b:SetPoint("TOPRIGHT", x, -6)
    framed(b, red and P.red or P.btn, red and P.redEdge or P.btnEdge)
    b.t = b:CreateFontString(nil, "OVERLAY"); b.t:SetFont("Fonts\\ARIALN.TTF", 16, ""); b.t:SetPoint("CENTER", 0, 1); b.t:SetText(label)
    local base = red and P.gold or P.brass
    b.t:SetTextColor(base[1], base[2], base[3])
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetPoint("TOPLEFT", 1, -1); b.hl:SetPoint("BOTTOMRIGHT", -1, 1); b.hl:SetColorTexture(1, 0.82, 0, 0.12)
    b:SetScript("OnClick", fn)
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(tip); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  tr.min = hdrBtn("-", -6, function() RG.db.trackerCollapsed = not RG.db.trackerCollapsed; RG.RefreshTracker() end, "Collapse or expand", true)
  local g = hdrBtn("", -32, function()
    local v = RG.TrackerView and RG.TrackerView() or "guide"
    local tab = (v == "prof" and "prof") or (v == "dungeon" and "dungeons") or "journey"
    if RG.ShowTab then RG.ShowTab(tab) elseif RG.ToggleUI then RG.ToggleUI() end
  end, "Open the full guide")
  tr.guideBtn = g
  local gi = g:CreateTexture(nil, "OVERLAY"); gi:SetSize(13, 13); gi:SetPoint("CENTER"); gi:SetTexture("Interface\\AddOns\\Waypath\\Media\\Icons\\Journey"); gi:SetVertexColor(P.brass[1], P.brass[2], P.brass[3])
  -- arrow on/off switch
  local ab = CreateFrame("Button", nil, tr); ab:SetSize(22, 22); ab:SetPoint("TOPRIGHT", -58, -6)
  framed(ab, P.btn, P.btnEdge)
  ab.hl = ab:CreateTexture(nil, "HIGHLIGHT"); ab.hl:SetPoint("TOPLEFT", 1, -1); ab.hl:SetPoint("BOTTOMRIGHT", -1, 1); ab.hl:SetColorTexture(1, 0.82, 0, 0.12)
  ab.icon = ab:CreateTexture(nil, "OVERLAY"); ab.icon:SetSize(12, 12); ab.icon:SetPoint("CENTER"); ab.icon:SetTexture("Interface\\AddOns\\Waypath\\Media\\Icons\\Arrow")
  ab:SetScript("OnClick", function(self)
    RG.db.arrow = not RG.Opt("arrow")
    if RG.RefreshArrow then RG.RefreshArrow() end
    RG.Notify("Arrow " .. (RG.Opt("arrow") and "on" or "off"))
    if PlaySound and SOUNDKIT and RG.Opt("sounds") then pcall(PlaySound, SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115) end
    RG.RefreshTracker()
    if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
  end)
  ab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Arrow: " .. (RG.Opt("arrow") and "on" or "off"))
    GameTooltip:AddLine("Click to turn the waypoint arrow " .. (RG.Opt("arrow") and "off" or "on") .. ".", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  ab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  tr.arrowBtn = ab

  -- the level bar along the bottom: your level and how far into it, the time to the next one, and the XP bar
  tr.footBg = tr:CreateTexture(nil, "BACKGROUND", nil, -7); tr.footBg:SetPoint("BOTTOMLEFT", 1, 1); tr.footBg:SetPoint("BOTTOMRIGHT", -1, 1); tr.footBg:SetHeight(FOOT_H - 1)
  tr.footBg:SetColorTexture(P.foot[1], P.foot[2], P.foot[3], 1)
  tr.footLine = tr:CreateTexture(nil, "BORDER"); tr.footLine:SetPoint("BOTTOMLEFT", 1, FOOT_H); tr.footLine:SetPoint("BOTTOMRIGHT", -1, FOOT_H); tr.footLine:SetHeight(1)
  tr.footLine:SetColorTexture(P.line[1], P.line[2], P.line[3], 1)
  tr.lvl = tr:CreateFontString(nil, "OVERLAY"); tr.lvl:SetPoint("BOTTOMLEFT", 9, 15); tr.lvl:SetJustifyH("LEFT"); tfont(tr.lvl, 10.5)
  tr.lvl:SetTextColor(P.muted[1], P.muted[2], P.muted[3])
  tr.eta = tr:CreateFontString(nil, "OVERLAY"); tr.eta:SetPoint("BOTTOMRIGHT", -9, 15); tr.eta:SetJustifyH("RIGHT"); tfont(tr.eta, 10.5)
  tr.eta:SetTextColor(P.muted[1], P.muted[2], P.muted[3])
  local xpBox = CreateFrame("Frame", nil, tr); xpBox:SetHeight(6); xpBox:SetPoint("BOTTOMLEFT", 8, 6); xpBox:SetPoint("BOTTOMRIGHT", -8, 6)
  framed(xpBox, P.dark, P.btnEdge)
  tr.xpBox = xpBox
  tr.xp = xpBox:CreateTexture(nil, "ARTWORK"); tr.xp:SetHeight(4); tr.xp:SetPoint("TOPLEFT", 1, -1)
  tr.xp:SetColorTexture(P.xp[1], P.xp[2], P.xp[3], 1)
  tr.rest = xpBox:CreateTexture(nil, "ARTWORK", nil, -1); tr.rest:SetHeight(4); tr.rest:SetPoint("TOPLEFT", tr.xp, "TOPRIGHT", 0, 0)
  tr.rest:SetColorTexture(0.3, 0.52, 0.9, 0.55); tr.rest:Hide()
  tr.foot = RG.NewText(tr, "GameFontHighlightSmall"); tr.foot:Hide()
  tr.pct = RG.NewText(tr, "GameFontHighlightSmall"); tr.pct:Hide()

  local sep = tr:CreateTexture(nil, "ARTWORK"); sep:SetHeight(1); sep:SetPoint("TOPLEFT", 1, -50); sep:SetPoint("TOPRIGHT", -1, -50); sep:SetColorTexture(P.line[1], P.line[2], P.line[3], 1); tr.sep = sep
  -- the rows live on a scroll child: the list scrolls once it is taller than its cap (TrackerExtras.lua)
  -- (it starts under the header and the current step: RG.TrackerTop)
  tr.scroll = CreateFrame("ScrollFrame", nil, tr); tr.scroll:SetPoint("TOPLEFT", 12, -56); tr.scroll:SetWidth(W - 24); tr.scroll:SetHeight(10)
  tr.body = CreateFrame("Frame", nil, tr.scroll); tr.body:SetWidth(W - 24); tr.body:SetHeight(10)
  tr.scroll:SetScrollChild(tr.body)
  lines = {}
  tr.rowList = lines
end

-- Sections fold with a click on their header (remembered between sessions).
-- Professions and Reminders start folded so the tracker stays calm; a click opens them and remembers
local DEFAULT_FOLD = { profs = true, reminders = true }
local function folded(key)
  if not key then return nil end
  local v = RG.db.trackerFold and RG.db.trackerFold[key]
  -- beside Questie's own quest tracker the quest list starts folded (one click opens it), so the two don't repeat each other
  if v == nil and key == "quests" and RG.QuestieDoes and RG.QuestieDoes("tracker") then return true end
  if v == nil then return DEFAULT_FOLD[key] end
  return v
end
local function fontSize(base) return math.floor(base * ((RG.db.textSize or 1.2) / 1.2) + 0.5) end
-- How far down the list starts: under the header (what it follows, and the line under that) and the current step.
function RG.TrackerTop()
  local h = RG.StepCardHeight and RG.StepCardHeight() or 0
  return HEAD_H + 4 + (h > 0 and (h + 6) or 0) + 4
end
-- The sections under Quests (new quests, route, class quests, dungeon, upgrade, professions, reminders) share one
-- "More" row until you open it, so the side bar stays short: the first thing it shows is what to do now.
local SECONDARY = { pala = "Class quests" }
local hints, skipped, moreOpen = {}, 0, false
local lastSkipped = false   -- the last section went into the "More" row: it drew nothing, so it leaves no gap either
local function gap(y) if lastSkipped then return y end return y + 5 end
local function section(n, y, label, key, right)
  lastSkipped = false
  if key and SECONDARY[key] and not moreOpen then
    local name = SECONDARY[key]
    if key == "dungeon" or key == "pala" then name = label:gsub("^Class quests: ", "Class quests"):gsub("%s*$", "") end
    local plain = right and right:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or ""
    hints[#hints + 1] = { name = name, note = plain, urgent = right ~= nil and right:find(GREEN, 1, true) ~= nil }
    skipped = skipped + 1
    lastSkipped = true
    if lines[n] then lines[n]:Hide() end
    return y, true
  end
  local b = line(n)
  b._sig = nil; b._q, b._top = nil, y
  b._live, b._timer, b._rbase, b.tipFn = nil, nil, nil, nil
  if rawget(b, "_tick") or rawget(b, "_step") then
    b.box:SetSize(12, 12); b.box:ClearAllPoints(); b.box:SetPoint("TOPLEFT", 0, -1); b.check:SetSize(12, 12); b.check:SetVertexColor(0.05, 0.07, 0.07, 1)
    b._tick, b._step = nil, nil
  end
  b.num:Hide(); b.band:Hide()
  b.onClick, b.onRightClick, b.tip, b.onDoubleClick, b.menu, b.wpClick = nil, nil, nil, nil, nil, nil
  b.box:Hide(); b.check:Hide()
  local isFolded = folded(key)
  if key then
    b.onClick = function()
      RG.db.trackerFold = RG.db.trackerFold or {}
      RG.db.trackerFold[key] = not folded(key)
      RG.RefreshTracker()
    end
    b.tip = isFolded and "Click to show this section." or "Click to fold this section away."
  end
  -- the bar: title in Marcellus gold on the left, what it counts on the right, then + or - (folded or open)
  b.secF:SetShown(true)
  b.fold:SetShown(key ~= nil); b.fold:SetText(isFolded and "+" or "-")
  b.text:ClearAllPoints(); b.text:SetPoint("TOPLEFT", 4, -4); dfont(b.text, fontSize(13))
  b.text:SetWordWrap(false); if b.text.SetMaxLines then b.text:SetMaxLines(1) end
  b.text:SetShadowColor(0, 0, 0, 0.9); b.text:SetShadowOffset(1, -1)
  b.text:SetTextColor(P.gold[1], P.gold[2], P.gold[3])
  b.text:SetText(label)
  tfont(b.right, fontSize(10.5)); b.right:SetText(right or ""); b.right:SetShown(right ~= nil)
  b.right:SetTextColor(P.where[1], P.where[2], P.where[3])
  b.right:ClearAllPoints(); b.right:SetPoint("TOPRIGHT", key and -16 or -4, -5)
  b.text:SetWidth(math.max(40, W - 24 - 8 - (right and ((b.right:GetStringWidth() or 0) + 8) or 0) - (key and 16 or 4)))
  if rawget(b, "pbg") then b.pbg:Hide(); b.pbar:Hide() end
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -y); b:SetHeight(20); b:Show()
  return y + 25, isFolded
end
-- opts: onClick, onRightClick, tip, box (checkbox state), right (right-hand text), single (one line, cut with ...)
local function item(n, y, text, opts)
  opts = opts or {}
  local b = line(n)
  b.onClick, b.tip, b.onRightClick, b.menu = opts.onClick, opts.tip, opts.onRightClick, opts.menu
  b.onDoubleClick = nil
  b.wpClick = (opts.wp and not opts.noArrow) and opts.wp or nil
  local indent = opts.indent or (opts.box ~= nil and 16 or 8)
  -- the same line as last refresh (most lines, most of the time): keep its text and layout, only place it. Setting text
  -- and measuring it is the costly part of a tracker refresh, and this skips it.
  local sig = tostring(text) .. "\1" .. tostring(opts.right) .. "\1" .. indent .. "\1" .. W .. "\1" .. fontSize(13) .. "\1" ..
    (opts.single and "s" or "") .. tostring(opts.box) .. (RG.trInterBad and "a" or "") .. (RG.Opt("trackerInter") and "i" or "") ..
    "\1" .. tostring(opts.progress and math.floor(opts.progress * 40)) .. (RG.Opt("trackerRoomy") and "r" or "") ..
    "\1" .. tostring(opts.rpad) .. tostring(opts.tickAt) .. "\1" .. (opts.step and (opts.step.n .. opts.step.state) or "") .. (opts.band and "b" or "")
  local spacing = RG.Opt("trackerRoomy") and 8 or 4
  b._q, b._top = opts.quest, y
  b._live, b._timer, b._rbase, b.tipFn = opts.live, opts.timer, opts.rbase, opts.tipFn
  if b._sig == sig and b._h then
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -y); b:Show()
    return y + b._h + spacing + (b._prog and 2 or 0)
  end
  b.secF:SetShown(false); b.fold:Hide()
  tfont(b.right, fontSize(11.5)); b.right:SetText(opts.right or ""); b.right:SetShown(opts.right ~= nil)
  b.right:SetTextColor(P.muted[1], P.muted[2], P.muted[3])
  b.right:ClearAllPoints(); b.right:SetPoint("TOPRIGHT", -(opts.rpad or 0), -1)
  local rw = opts.right and ((b.right:GetStringWidth() or 0) + 8) or 0
  b.text:ClearAllPoints(); b.text:SetPoint("TOPLEFT", indent, 0); tfont(b.text, fontSize(13))
  b.text:SetTextColor(P.ink[1], P.ink[2], P.ink[3])
  local avail = W - 24 - indent - rw - (opts.rpad or 0)
  b.text:SetWidth(avail)
  b.text:SetShadowColor(0, 0, 0, 0.9); b.text:SetShadowOffset(1, -1)
  local multi = not opts.single and tostring(text):find("\n", 1, true)   -- text with its own line breaks lays itself out
  -- a line that needs more than one row wraps to two at most, and its height comes from its width (the font's own
  -- height reading can lag a frame behind and let the next row print over it)
  b.text:SetWordWrap(false); if b.text.SetMaxLines then b.text:SetMaxLines(1) end
  if not opts.single and not multi then b.text:SetWidth(0) end
  b.text:SetText(text); tcheck(b.text, text)
  local rows = 1
  if not opts.single and not multi then
    local natural = b.text:GetStringWidth() or 0
    rows = math.max(1, math.min(2, math.ceil(natural / math.max(1, avail) - 0.03)))
    b.text:SetWidth(avail); b.text:SetWordWrap(true)
    if b.text.SetMaxLines then b.text:SetMaxLines(2) end
    b.text:SetText(text)
  elseif multi then
    b.text:SetWidth(avail); b.text:SetWordWrap(true)
    if b.text.SetMaxLines then b.text:SetMaxLines(0) end
    b.text:SetText(text)
  end
  if (b._tick and not opts.tickAt) or (b._step and not opts.step) then
    b.box:SetSize(12, 12); b.box:ClearAllPoints(); b.box:SetPoint("TOPLEFT", 0, -1); b.check:SetSize(12, 12); b.check:SetVertexColor(0.05, 0.07, 0.07, 1)
    b._tick, b._step = nil, nil
  end
  b.num:Hide()
  b.band:SetShown(opts.band and true or false)
  if opts.step then
    -- a route step: a ring with its number (a tick once it's done; a filled disc for the step you're on)
    local st = opts.step
    b._step = true
    b.box:Show(); b.box:SetSize(14, 14); b.box:ClearAllPoints(); b.box:SetPoint("TOPLEFT", 2, 0)
    b.box:SetTexture("Interface\\AddOns\\Waypath\\Media\\" .. (st.state == "cur" and "Disc" or "Ring"))
    if st.state == "done" then
      b.box:SetVertexColor(P.doneEdge[1], P.doneEdge[2], P.doneEdge[3], 1)
      b.check:SetSize(10, 10); b.check:SetVertexColor(P.green[1], P.green[2], P.green[3], 1); b.check:Show()
    else
      b.check:Hide()
      if st.state == "cur" then b.box:SetVertexColor(P.gold[1], P.gold[2], P.gold[3], 1); b.num:SetTextColor(0.1, 0.07, 0.02)
      else b.box:SetVertexColor(P.btnEdge[1] * 1.4, P.btnEdge[2] * 1.4, P.btnEdge[3] * 1.4, 1); b.num:SetTextColor(P.muted[1], P.muted[2], P.muted[3]) end
      b.num:SetText(tostring(st.n)); b.num:Show()
    end
  elseif opts.tickAt then
    -- a small green tick (a finished objective)
    b._tick = true
    b.box:Show(); b.box:SetTexture("Interface\\AddOns\\Waypath\\Media\\Disc"); b.box:SetVertexColor(0.35, 0.85, 0.45, 1)
    b.box:SetSize(10, 10); b.box:ClearAllPoints(); b.box:SetPoint("TOPLEFT", opts.tickAt, -2)
    b.check:SetSize(10, 10); b.check:Show()
  elseif opts.box ~= nil then
    b.box:Show(); b.box:SetTexture("Interface\\AddOns\\Waypath\\Media\\" .. (opts.box and "Disc" or "Ring"))
    if opts.box then b.box:SetVertexColor(GOLDC[1], GOLDC[2], GOLDC[3], 1) else b.box:SetVertexColor(0.42, 0.42, 0.42, 1) end
    b.check:SetShown(opts.box and true or false)
  else b.box:Hide(); b.check:Hide() end
  local rowH = fontSize(13) + 3
  local h = opts.single and math.max(16, rowH) or (multi and math.max(16, (b.text:GetStringHeight() or 14) + 2) or math.max(16, rows * rowH))
  -- a quest's progress: a thin bar under the line (gold while under way, green when done)
  if opts.progress then
    if not rawget(b, "pbg") then
      b.pbg = b:CreateTexture(nil, "BACKGROUND"); b.pbg:SetHeight(2); b.pbg:SetColorTexture(1, 1, 1, 0.08)
      b.pbar = b:CreateTexture(nil, "BORDER"); b.pbar:SetHeight(2)
    end
    local bw = math.max(20, avail - 4)
    b.pbg:ClearAllPoints(); b.pbg:SetPoint("BOTTOMLEFT", indent, -2); b.pbg:SetWidth(bw)
    b.pbar:ClearAllPoints(); b.pbar:SetPoint("BOTTOMLEFT", indent, -2); b.pbar:SetWidth(math.max(1, bw * opts.progress))
    if opts.progress >= 1 then b.pbar:SetColorTexture(0.35, 0.85, 0.45, 0.9) else b.pbar:SetColorTexture(GOLDC[1], GOLDC[2], GOLDC[3], 0.8) end
    b.pbg:Show(); b.pbar:Show()
  elseif rawget(b, "pbg") then b.pbg:Hide(); b.pbar:Hide() end
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -y); b:SetHeight(h); b:Show()
  b._sig, b._h, b._prog = sig, h, opts.progress ~= nil
  return y + h + spacing + (opts.progress and 2 or 0)
end

-- Right-click on a tracker line: point the arrow at it (turning the arrow on if it was off).
function RG.Follow(wp)
  if not wp then return end
  if not RG.Opt("arrow") then RG.db.arrow = true; if RG.RefreshArrow then RG.RefreshArrow() end end
  RG.db.arrowPaused = nil
  RG.PinWaypoint(wp)
  -- you picked it: it's the current step for a while (Guide.lua)
  if RG.PickManually then RG.PickManually(wp) end
  if RG.RefreshTracker then RG.RefreshTracker() end
end

-- Tooltip for a quest in your log.
-- the reward-upgrade mark and tooltip line for a quest (GearPlus.lua)
local function upTag(id) return (id and RG.QuestUpgradeTag and RG.QuestUpgradeTag(id)) or "" end
-- before the name, for one-line rows that cut long names short
local function upFront(id) local t = upTag(id); return t ~= "" and (t:gsub("^%s+", "") .. " ") or "" end
local function upTip(id) return (id and RG.QuestUpgradeTip and RG.QuestUpgradeTip(id)) or "" end
local function questTip(q)
  local t = RG.LevelTag(q.level) .. "|cffffffff" .. q.title .. "|r"
  if q.zone then t = t .. "\n" .. GREY .. q.zone .. "|r" end
  t = t .. noteTip(RG.QuestNote(q.id, q.group)) .. upTip(q.id)
  if q.complete then t = t .. "\n" .. GREEN .. "Complete: ready to turn in|r"
  else
    for _, o in ipairs(q.objs or {}) do
      if o.text and o.text ~= "" then t = t .. "\n" .. (o.finished and (GREY .. "  - " .. o.text .. "|r") or ("|cffffffff  - " .. o.text .. "|r")) end
    end
    if RG.DropTip then t = t .. RG.DropTip(q.id) end
  end
  if q.dist then t = t .. "\n" .. GREY .. (q.complete and "Turn in: " or "Nearest: ") .. (q.label ~= "" and q.label or "") .. ", " .. RG.FormatYards(q.dist) .. "|r" end
  if q.complete and q.wp then
    t = t .. "\n\n" .. GOLD .. "Click / right-click:|r arrow to the hand-in\n" .. GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Shift-click:|r link it in chat (chat box open), else open your quest log\n" .. GOLD .. "Shift + right-click:|r more options (link, hide)"
  else
    t = t .. "\n\n" .. GOLD .. "Click:|r open in your quest log" .. (q.wp and ("\n" .. GOLD .. "Right-click:|r the arrow follows this quest\n" .. GOLD .. "Click:|r arrow on / off") or "") .. "\n" .. GOLD .. "Shift-click:|r link it in chat (chat box open)"
  end
  return t
end

function RG.RefreshTracker()
  if RG.CardsOnly and RG.CardsOnly() then return end
  if not RG.db or not RG.db then return end
  if not RG.Opt("tracker") then if tr then tr:Hide() end return end
  if not tr then build() end
  -- a quest-item button is on screen and a fight is on: the game won't let it be moved or hidden, so the tracker holds still
  -- (it catches up when the fight ends)
  if RG.TrackerFrozen and RG.TrackerFrozen() then
    RG.trackerDeferred = true
    if RG.TrackerLiveUpdate then pcall(RG.TrackerLiveUpdate) end
    return
  end
  tr:Show()
  -- size and width (Ctrl / Shift + mouse wheel)
  W = RG.db.trackerWidth or 300
  tr:SetWidth(W); tr.body:SetWidth(W - 24); tr.scroll:SetWidth(W - 24); tr:SetScale(RG.db.trackerScale or 1)
  framed(tr, P.panel, P.border, RG.db.trackerAlpha or 0.92)
  -- pairs, not ipairs: a folded section leaves a gap in the list, and ipairs stops at the first gap (old rows stayed on screen)
  -- rows are not hidden first: every row up to the last one is placed again below, and the rest are hidden at the end
  -- (hiding and showing each row on every refresh made the game lay the whole tracker out twice)
  if tr._w ~= W then tr._w = W; for _, b in pairs(lines) do b:SetWidth(W - 24); b._sig = nil end end
  local lvl = UnitLevel("player")
  local xp, max = UnitXP("player"), UnitXPMax("player")
  local rate, eta
  if RG.XPRate then rate, eta = RG.XPRate() end
  local rested = GetXPExhaustion and GetXPExhaustion()
  if rested and RG.IsSecret and RG.IsSecret(rested) then rested = nil end
  -- the level bar: "Level 53 · 42%", "level 54 in about 3 h" (at your pace this session), rested XP a paler stretch
  local frac = (max and max > 0) and math.min(1, xp / max) or 0
  tr.lvl:SetText("Level " .. lvl .. " · " .. math.floor(frac * 100) .. "%" .. (rested and rested > 0 and "  ·  |cff7fa6e6rested|r" or ""))
  local maxLvl = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
  if lvl >= maxLvl then tr.eta:SetText("max level")
  elseif eta and RG.FormatETA then tr.eta:SetText("level " .. (lvl + 1) .. " in about " .. RG.FormatETA(eta))
  else tr.eta:SetText("") end
  -- the header: what the tracker follows (Smart.lua), the line under it, and the current step (StepView.lua)
  local view = RG.TrackerView and RG.TrackerView() or "log"
  local alt = RG.IsAlt and RG.IsAlt()
  tr.modeBtn.text:SetWidth(0); tr.modeBtn.text:SetText(alt and "Bank alt" or (RG.ModeName and RG.ModeName(view)) or "Waypath+")
  if (tr.modeBtn.text:GetStringWidth() or 0) > W - 150 then tr.modeBtn.text:SetWidth(W - 150) end
  do
    local okO, o = pcall(RG.Objective or function() end)
    tr.crest:SetDesaturated(not (okO and o and o.wp))
  end
  do
    local bw = W - 18
    tr.xp:SetWidth(math.max(1, bw * frac))
    local rw = (rested and rested > 0 and max and max > 0) and math.min(bw * (1 - frac), bw * rested / max) or 0
    if rw >= 1 then tr.rest:SetWidth(rw); tr.rest:Show() else tr.rest:Hide() end
  end
  if tr.arrowBtn then
    local on = RG.Opt("arrow")
    tr.arrowBtn.icon:SetDesaturated(not on)
    if on then tr.arrowBtn.icon:SetVertexColor(P.light[1], P.light[2], P.light[3]) else tr.arrowBtn.icon:SetVertexColor(0.45, 0.45, 0.45) end
  end
  local quests = RG.MyQuests and RG.MyQuests() or {}
  -- the line under the header: what it's following right now (click: more)
  do
    local left, right, click, tip, drop
    if alt then left = "Bank alt for " .. (RG.MainName and RG.MainName() or "your main")
    elseif view == "guide" then
      local r = RG.CurrentRouteEntry and RG.CurrentRouteEntry()
      left = r and ("|cffffffff" .. r.zone .. "|r" .. GREY .. "  ·  levels " .. r.from .. "-" .. r.to .. "|r") or (GREY .. "No route zone for your level|r")
      right = RG.db.smart == false and "in order" or "smart order"
      click = function() if RG.ShowTab then RG.ShowTab("route") end end
      tip = GOLD .. "Ordered guide|r: the route, zone by zone" .. (RG.db.smart == false and ", in its order." or ". The smart zone order picks the zone that suits your level, where you are and your quest log.") ..
        "\nSettings > Tracker switches the smart zone order.\n\n" .. GOLD .. "Click:|r the Route tab"
    elseif view == "zone" then
      local zn, picked = RG.FollowZone()
      local r = RG.CurrentRouteEntry and RG.CurrentRouteEntry()
      if r then
        local steps, d = RG.STEPS[r.zone .. "|" .. r.from] or {}, 0
        for i = 1, #steps do if RG.StepIsDone(r, i) then d = d + 1 end end
        if #steps > 0 then right = math.floor(d / #steps * 100 + 0.5) .. "% done" end
      end
      left = "Selected Zone: |cffffffff" .. tostring(zn or "?") .. "|r"
      click = function(self) if RG.TrackerZoneMenu then RG.TrackerZoneMenu(self) end end
      tip = GOLD .. "Zone quests|r: one zone's route. It follows the zone you're in" .. (picked and "" or (" (" .. tostring(zn or "?") .. " now)")) .. ", or keeps to one you pick (until you log out).\n\n" .. GOLD .. "Click:|r pick a zone"
      drop = true
    elseif view == "log" then
      local ready = 0
      for _, q in ipairs(quests) do if q.complete then ready = ready + 1 end end
      left = #quests .. "/" .. ((C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()) or 20) .. " quests" .. (ready > 0 and (GREY .. "  ·  |r" .. GREEN .. ready .. " ready|r") or "")
      right = "nearest first"
      click = function() if ToggleQuestLog then ToggleQuestLog() end end
      tip = GOLD .. "My quest log|r: only the quests you have. Pick up a quest and it joins the plan." ..
        (RG.Opt("routeGuide") and "" or ("\n" .. GREY .. "The ordered guide and zone quests need the leveling route: pick one in the menu above and it's turned on.|r")) .. "\n\n" .. GOLD .. "Click:|r open your quest log"
    elseif view == "dungeon" then
      local pl = RG.PrepPlan and RG.PrepPlan() or { total = 0, obtained = 0, can = 0 }
      left = "Selected Dungeon: |cffffffff" .. tostring(pl.name or "none") .. "|r"
      right = pl.total > 0 and (pl.obtained .. "/" .. (pl.can or pl.total)) or nil
      click = function(self) if RG.TrackerDungeonMenu then RG.TrackerDungeonMenu(self) end end
      tip = GOLD .. "Preobtain Dungeon Quests|r: every quest for the dungeon you pick, and the quests that lead to them, before you run it. The dungeon's own quests are picked up and kept for the run.\n\n" .. GOLD .. "Click:|r pick a dungeon"
      drop = true
    else
      left = "Your professions' next steps"
      tip = GOLD .. "Professions|r: the step you're on in each profession you're levelling, and what you're short of. The menu above goes back to leveling."
    end
    local cx = tr.ctx
    cx.right:SetText(right or ""); cx.onClick, cx.tip = click, tip
    cx.left:SetWidth(0); cx.left:SetText(left or "")
    local room = (W - 16) - ((right and right ~= "") and ((cx.right:GetStringWidth() or 0) + 10) or 0) - 18 - (drop and 15 or 0)
    cx.left:SetWidth(math.max(20, math.min(room, (cx.left:GetStringWidth() or 0) + 2)))
    -- (boxed like the mockup's dropdown; the caret only when it opens a list)
    cx.chev:SetShown(drop and true or false)
    local has = left and left ~= ""
    cx.boxF:SetShown(has and true or false)
    cx:SetWidth(has and ((cx.left:GetWidth() or 0) + 16 + (drop and 15 or 0)) or 1)
  end
  -- the current step under the header (it knows whether the tracker is folded)
  if RG.RefreshStepView then RG.stepCardFromTracker = true; pcall(RG.RefreshStepView); RG.stepCardFromTracker = nil end
  local top = RG.TrackerTop()
  tr.sep:ClearAllPoints(); tr.sep:SetPoint("TOPLEFT", 0, -(top - 4)); tr.sep:SetPoint("TOPRIGHT", 0, -(top - 4))
  if RG.db.trackerCollapsed or (RG.trackerInCombat and RG.Opt("trackerCombatFold")) then
    -- folded: the header and the current step
    tr.scroll:Hide(); if RG.TrackerChrome then RG.TrackerChrome(false) end
    tr.min.t:SetText("+"); tr.sep:Hide()
    tr:SetHeight(top - 2 + FOOT_H)
    return
  end
  tr.scroll:Show(); tr.min.t:SetText("-"); tr.sep:Show()

  local n, y = 0, 0
  if RG.TrackerItemBegin then RG.TrackerItemBegin() end
  hints, skipped, moreOpen = {}, 0, RG.db.trackerMore == true
  -- bank alt: just the shopping list for your main
  if RG.IsAlt and RG.IsAlt() then
    tr.lvl:SetText("Bank alt for " .. (RG.MainName() or "your main")); tr.title:SetText("Waypath+")
    -- secret guide: walk a new alt to the Auction House
    local gl, gdone, gtotal = nil, 0, 0
    if RG.AltGuideLines then gl, gdone, gtotal = RG.AltGuideLines() end
    if gl then
      local isFolded
      n = n + 1; y, isFolded = section(n, y, "Bank alt setup", "altguide", GREY .. gdone .. "/" .. gtotal .. "|r")
      if not isFolded then
        for _, l in ipairs(gl) do n = n + 1; y = item(n, y, (isTarget(l[4]) and ARROW or "") .. l[1], { onClick = l[2], tip = l[3] .. (l[4] and ("\n" .. GOLD .. "Click:|r arrow on / off") or ""), wp = l[4] }) end
        n = n + 1; y = item(n, y, GREY .. "Hide this guide|r", { single = true, onClick = function() RG.AltGuideHide() end, tip = "/wp bankalt brings it back." })
      end
      y = gap(y)
    end
    local list = RG.ShoppingList and RG.ShoppingList() or {}
    n = n + 1; y = section(n, y, #list > 0 and "Buy and mail" or "Nothing to send right now")
    for i = 1, math.min(6, #list) do
      local e = list[i]
      n = n + 1
      y = item(n, y, (RG.ItemInfo(e.id) or ("item " .. e.id)) .. "  x" .. e.need .. (e.toBuy > 0 and (GREY .. "  (buy " .. e.toBuy .. ")|r") or (GREEN .. "  (in your bags)|r")) .. "\n" .. GREY .. e.quest .. "|r", { onClick = function() if RG.ShowTab then RG.ShowTab("mail") end end })
    end
    if RG.TrackerItemEnd then RG.TrackerItemEnd() end
    if RG.TrackerFinish then RG.TrackerFinish(y) end
    return
  end
  local compact = RG.Opt and RG.Opt("compactTracker")
  local MAXQ = compact and 14 or 40   -- (the list scrolls, so this is generous; ready quests never count)
  -- 0. fishing: shows while you hold a pole or caught something in the last 10 minutes
  local fl, fright = nil, nil
  if RG.FishTrackerLines then fl, fright = RG.FishTrackerLines() end
  if fl and #fl > 0 then
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "Fishing", "fishing", fright)
    if not isFolded then
      for i, l in ipairs(fl) do
        if not compact or i <= 2 then   -- compact: your skill and the one thing to know; the rest is on the Fishing page
          n = n + 1
          y = item(n, y, l[1], { single = l[2] ~= nil, right = l[2], onClick = l[3], tip = l[4] })   -- no right-hand text: let a long line wrap instead of cutting it short
        end
      end
    end
    y = gap(y)
    MAXQ = compact and 4 or 6 -- keep the tracker short while fishing
  end
  -- 0b. now: the one thing to do next (the same objective the arrow follows)
  do
    local okN, nl = false, nil   -- (the top line says it now)
    if okN and nl and #nl > 0 then
      n = n + 1; y = section(n, y, "Now", nil, nl.right)
      for _, l in ipairs(nl) do n = n + 1; y = item(n, y, l.text, l.opts) end
      y = gap(y)
    end
  end
  -- 0c. in a dungeon: your upgrades from it, by boss (GearPlus.lua); only upgrades are listed
  if RG.DungeonUpgradesHere and RG.Opt("dungeonHelper") then
    local okD, dn, ups = pcall(RG.DungeonUpgradesHere)
    if okD and dn and ups then
      local isFolded
      n = n + 1; y, isFolded = section(n, y, "Upgrades in " .. dn, "dunUp", #ups > 0 and (GREEN .. #ups .. "|r") or nil)
      if not isFolded then
        if #ups == 0 then
          n = n + 1; y = item(n, y, GREY .. "Nothing here beats what you wear.|r", { single = true })
        else
          local shown = compact and 4 or 8
          for i, u in ipairs(ups) do
            if i > shown then break end
            local nm, link = RG.ItemInfo(u.id)
            local slotName = RG.SLOT_NAMES and RG.SLOT_NAMES[u.slot] or ""
            local later = u.lvl and u.lvl > (UnitLevel("player") or 1)
            n = n + 1
            y = item(n, y, (u.boss and (GOLD .. u.boss .. ":|r ") or "") .. (link or nm or (u.g and u.g.name) or ("item " .. u.id)),
              { single = true, indent = 12,
                right = GREEN .. "+" .. string.format("%.0f", u.d) .. "|r" .. (later and (GREY .. " L" .. u.lvl .. "|r") or ""),
                tip = (link or nm or "") .. "\n" .. GREEN .. string.format("+%.0f", u.d) .. "|r" .. GREY .. " for your " .. (slotName ~= "" and slotName or "gear") ..
                  (u.boss and (", from " .. u.boss) or ", a drop here") .. (later and (" (you can wear it at level " .. u.lvl .. ")") or "") .. "|r",
                onClick = u.g and function() RG.ShowItemSource(u.g) end or nil })
          end
          if #ups > shown then n = n + 1; y = item(n, y, GREY .. "+" .. (#ups - shown) .. " more on the Gear tab|r", { single = true, onClick = function() if RG.ShowTab then RG.ShowTab("gear") end end }) end
        end
      end
      y = gap(y)
    end
  end
  -- 1. new quests nearby (your quest log)
  local new = view == "log" and RG.NearbyNewQuests and RG.NearbyNewQuests(8) or {}
  -- 2. the route (the ordered guide and zone quests): the zone's steps, one line each, the step you're on opened up into
  -- its quests; then what comes after (the guide: the next zones and dungeons; zone quests: where to go when it's done)
  local function oneLine(t) return (plain(t or ""):gsub("%s+", " "):gsub("^ ", "")) end
  local function comingUp(r)
    local rows = {}
    for _, o in ipairs(nextZones(r, 3)) do rows[#rows + 1] = { r = o.r, why = o.why } end
    local off, left = not RG.DungeonQuestsOn(), 0
    for _, d in ipairs(RG.ROUTE or {}) do
      local dq = d.kind == "dungeon" and RG.DUNGEON_QUESTS and RG.DUNGEON_QUESTS[d.zone]
      if dq and lvl >= (dq.prep or d.from) and lvl <= d.to and not RG.DungeonQuestsDone(dq) then
        if off then left = left + 1 elseif #rows < 5 then rows[#rows + 1] = { r = d, dq = dq } end
      end
    end
    if #rows == 0 and left == 0 then return end
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "Coming up", "next")
    if isFolded then y = gap(y) return end
    for _, row in ipairs(rows) do
      local z = row.r.zone
      n = n + 1
      if row.dq then
        local missing = 0
        for _, q in ipairs(row.dq.quests or {}) do
          local st = RG.QuestState and RG.QuestState((q[1]:gsub("%s*%(.-%)$", "")))
          if not st and (not q.id or RG.QuestPrereqsMet(q.id)) then missing = missing + 1 end
        end
        y = item(n, y, "|cffffffff" .. z .. "|r  |cffb9a8ffdungeon|r", { single = true, indent = 8,
          right = GREY .. row.r.from .. "-" .. row.r.to .. "|r",
          tip = "|cffffffff" .. z .. "|r  (dungeon, levels " .. row.r.from .. "-" .. row.r.to .. ")\n" .. GREY .. (missing > 0 and (missing .. " of its quests still to pick up.") or "All its quests are in your log.") .. "|r" ..
            "\n" .. GREY .. "Leave dungeon quests out: the menu at the top of the tracker, or Settings > Tracker.|r\n\n" .. GOLD .. "Click:|r the Route tab",
          onClick = function() if RG.ShowTab then RG.ShowTab("route") end end })
      else
        y = item(n, y, "|cffffffff" .. z .. "|r", { single = true, indent = 8, right = GREY .. row.r.from .. "-" .. row.r.to .. "|r",
          tip = "|cffffffff" .. z .. "|r\n" .. GREY .. tostring(row.why or "") .. "|r\n\n" .. GOLD .. "Click:|r how to get there",
          onClick = function() local t = RG.TravelSummary and RG.TravelSummary(z); RG.Print(z .. ": " .. (t or "see the Route tab for the way there.")) end })
      end
    end
    if left > 0 then
      n = n + 1
      y = item(n, y, GREY .. left .. " dungeon" .. (left == 1 and "" or "s") .. " left out  ·  show|r", { single = true, indent = 8,
        tip = "You've left dungeon quests out (the menu at the top of the tracker, or Settings > Tracker).\n\n" .. GOLD .. "Click:|r show them again",
        onClick = function() RG.db.dungeonQuests = true; if RG.RouteChanged then RG.RouteChanged() end end })
    end
    y = gap(y)
  end
  local function routeSection()
    local r = currentEntry()
    if not r then
      if view == "zone" then
        local zn = RG.FollowZone() or "here"
        local isFolded
        n = n + 1; y, isFolded = section(n, y, "Route · " .. zn, "route", GREY .. "no steps|r")
        if not isFolded then
          n = n + 1; y = item(n, y, GREY .. "No route steps in this zone.|r", { single = true, indent = 2,
            tip = "Zone quests keeps to one zone's route, and " .. zn .. " has none. Go to a zone on the route (below), or pick one at the top of the tracker, and it follows you there." })
          y = RG.TrackerNextZones and RG.TrackerNextZones(n, y, item, nil) or y
          n = RG.trackerN or n
        end
        y = gap(y)
      end
      return
    end
    local key = r.zone .. "|" .. r.from
    local steps = RG.STEPS[key] or {}
    local cur = RG.NextStep(r)
    -- zone quests: the steps are the planner's stops, nearest first (the current step is the one the card shows); the
    -- route's own steps only when there's nothing to plan (a hand-written step, say)
    local zstops = view == "zone" and RG.GuidePlan and (RG.GuidePlan() or {}).stops or nil
    if zstops and #zstops == 0 then zstops = nil end
    local right
    if zstops then right = GREY .. #zstops .. " to do|r"
    elseif #steps == 0 then right = GOLD .. "new zone|r"
    elseif cur then right = GREY .. "step " .. cur .. " of " .. #steps .. "|r"
    else right = GREEN .. "done|r" end
    local isFolded
    n = n + 1; y, isFolded = section(n, y, (zstops and "Steps · " or "Route · ") .. r.zone, "route", right)
    if isFolded then y = gap(y) return end
    -- the smart zone order's other good zones (the ordered guide)
    if view == "guide" and RG.SmartAlternatives and RG.db.smart ~= false then
      local ok, alts = pcall(RG.SmartAlternatives, r)
      if ok and alts and #alts > 0 then
        local names = {}
        for _, o in ipairs(alts) do names[#names + 1] = o.r.zone end
        n = n + 1
        y = item(n, y, GREY .. "Also good: " .. table.concat(names, ", ") .. "|r", { single = true, indent = 2,
          tip = GOLD .. "Smart zone order|r picks the zone that suits your level, where you are and your quest log.\n\n" .. (function() local t = {} for _, o in ipairs(alts) do t[#t + 1] = "|cffffffff" .. o.r.zone .. "|r: " .. o.why end return table.concat(t, "\n") end)() .. "\n\n" .. GOLD .. "Settings > Tracker|r turns it off." })
      end
    end
    -- a flight master you haven't learned yet, close by: grab it while you're here
    if RG.NearbyFlight then
      local fe = RG.NearbyFlight()
      if fe then
        n = n + 1
        y = item(n, y, (isTarget(fe.wp) and ARROW or RG.PIN or "") .. GOLD .. "Grab the " .. fe.node .. " flight path|r", { single = true, indent = 2, wp = fe.wp,
          right = GREY .. math.floor(fe.dist) .. " yd|r",
          tip = GOLD .. "Flight path nearby:|r " .. fe.node .. " (" .. fe.zone .. ")" .. (fe.npc and (", from " .. fe.npc) or "") .. ".\nLearn it now and you can fly back here later instead of running." ..
            (fe.known == nil and ("\n" .. GREY .. "Already have it? Talk to any flight master once and Waypath+ remembers which ones you know.|r") or "") ..
            "\n\n" .. GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Right-click:|r show it on the map",
          onRightClick = function() RG.PinWaypoint(fe.wp) end })
      end
    end
    -- one step: its number in a ring (a tick once done), the place, and how much is left; the whole text in its tooltip
    local function stepRow(i, state)
      local ql, qd, qt, place, levels = RG.StepQuestLines(r, i, quests)
      local sk = key .. "#" .. i
      local wp = RG.StepWaypoint and RG.StepWaypoint(r, i)
      local full = oneLine(steps[i])
      local rt
      if state == "done" then rt = GREY .. "done|r"
      elseif ql and state == "cur" then rt = GOLD .. qd .. "/" .. qt .. "|r"
      elseif ql and #ql > 0 then rt = GREY .. #ql .. " quest" .. (#ql == 1 and "" or "s") .. "|r" end
      local drops = ""
      if state == "cur" and ql and RG.DropTip then
        for _, l in ipairs(ql) do if l.act ~= "turnin" and l.act ~= "later" then drops = drops .. RG.DropTip(l.id):gsub("^\n\n" .. GOLD:gsub("%p", "%%%0") .. "Drops:|r", "") end end
        if drops ~= "" then drops = "\n\n" .. GOLD .. "Drops:|r" .. drops end
      end
      local col = (state == "cur" and "|cffffffff") or (state == "done" and GREY) or "|cffd6d6d6"
      n = n + 1
      y = item(n, y, (isTarget(wp) and ARROW or "") .. col .. (place or full) .. "|r" .. ((state == "cur" and levels) and (GREY .. "  ·  " .. levels .. "|r") or ""),
        { single = true, indent = 22, step = { n = i, state = state }, band = state == "cur", right = rt, wp = wp,
          tip = "|cffffffff" .. full .. "|r" .. (ql and ("\n" .. GREY .. qd .. " of " .. qt .. " quests done|r") or "") .. drops .. "\n\n" ..
            (wp and (GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Right-click:|r show it on the map\n") or "") ..
            (state ~= "done" and (GOLD .. "Shift-click:|r skip this step") or GREY .. "Done|r"),
          onClick = function() if state ~= "done" and IsShiftKeyDown and IsShiftKeyDown() then RG.TickStep(sk, steps[i]) end end,
          onRightClick = wp and function() RG.Follow(wp) end or nil })
      return ql, wp, sk, full
    end
    -- what's left to do once the zone's steps are listed: the way there, and (zone quests) where to go after
    local function afterSteps()
      if RG.TravelSummary then
        local tip = RG.TravelSummary(r.zone)
        if tip then n = n + 1; y = item(n, y, GOLD .. "Getting there:|r " .. tip, { single = true, indent = 2, wp = destWp(r), tip = GOLD .. "Getting there:|r " .. tip .. "\n\nThe quickest way from here, using your hearthstone, the flight paths you know, zeppelins and boats.\n\n" .. GOLD .. "Click:|r arrow to the first stop in " .. r.zone }) end
      end
      if view == "zone" then
        local names = {}
        for _, o in ipairs(nextZones(r, 2)) do names[#names + 1] = o.r.zone end
        if #names > 0 then
          n = n + 1; y = item(n, y, GREY .. "When it's done: " .. table.concat(names, " or ") .. "|r", { single = true, indent = 2,
            tip = "Zone quests keeps to " .. r.zone .. ". When it's done, go to one of these (or pick one at the top of the tracker) and it follows you there." })
        end
      end
    end
    if zstops then
      -- zone quests: the planner's stops, the one the current step shows opened up into everything at that stop
      local okO, o = pcall(RG.Objective or function() end)
      local curStop = okO and o and o.stop or nil
      local picked = okO and o and o.kind == "pick"   -- (a place you picked that isn't a stop: none of these is current)
      local shownS = 0
      for i, st in ipairs(zstops) do
        if shownS < 6 then
          shownS = shownS + 1
          local it = st.items[1]
          local isCur = (curStop and st == curStop) or (not curStop and not picked and i == 1)
          local text = RG.PrepStepText(it)
          n = n + 1
          y = item(n, y, (isTarget(st.wp) and ARROW or "") .. (isCur and "|cffffffff" or "|cffd6d6d6") .. text .. "|r",
            { single = true, indent = 22, step = { n = i, state = isCur and "cur" or "todo" }, band = isCur, wp = st.wp,
              right = st.pd and (GREY .. RG.FormatYards(math.floor(st.pd)) .. "|r") or nil,
              tip = "|cffffffff" .. text .. "|r\n" .. GREY .. tostring(it.title) .. (st.wp and st.wp[4] and st.wp[4] ~= it.title and (", " .. st.wp[4]) or "") .. "|r" ..
                (RG.DropTip and it.act ~= "turnin" and RG.DropTip(it.id, it.act == "doing" and it.label or nil) or "") ..
                "\n\n" .. GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Right-click:|r skip this stop for an hour (/wp undo brings it back)",
              onRightClick = function() if RG.SkipStop then RG.SkipStop(st); if RG.SyncObjective then RG.SyncObjective(RG.Objective(true)) end; RG.RefreshTracker() end end })
          if isCur and #st.items > 1 then
            for k = 2, math.min(#st.items, 5) do
              local x = st.items[k]
              n = n + 1
              y = item(n, y, GREY .. RG.PrepStepText(x) .. "|r" .. ((x.act == "doing" and x.title ~= it.title) and (GREY .. "  ·  " .. tostring(x.title) .. "|r") or ""), { single = true, indent = 26, band = true })
            end
          end
        end
      end
      if #zstops > shownS then
        n = n + 1; y = item(n, y, GREY .. "+" .. (#zstops - shownS) .. " more step" .. ((#zstops - shownS) == 1 and "" or "s") .. "|r", { single = true, indent = 22 })
      end
      -- the zone's quests in your log the plan can't take you to here, and why (their mobs are in another zone, there's no
      -- known place for them, or what's left is a reputation), so the list doesn't look cut short
      do
        local inPlan = {}
        for _, st in ipairs(zstops) do for _, it in ipairs(st.items) do inPlan[it.title] = true end end
        local spotZone = {}
        for _, sp in ipairs(RG.QuestSpots and RG.QuestSpots() or {}) do
          if not sp.turnin and not spotZone[sp.quest] and sp.wp and RG.MapZone then spotZone[sp.quest] = RG.MapZone(sp.wp[1]) or false end
        end
        local rest = {}
        -- (the zone's: under its heading in your quest log, or given or handed in there)
        local function ofZone(q)
          if q.zone == r.zone then return true end
          local qd = q.id and RG.QDATA and RG.QDATA[q.id]
          if not (qd and RG.MapZone) then return false end
          return (qd.s and RG.MapZone(qd.s[1]) == r.zone) or (qd.e and RG.MapZone(qd.e[1]) == r.zone) or false
        end
        for _, q in ipairs(quests) do
          if ofZone(q) and not inPlan[q.title] and not q.failed and not (RG.DungeonQuestHidden and RG.DungeonQuestHidden(q.id, q.zone)) then
            local why
            if q.complete then
              local qd = q.id and RG.QDATA and RG.QDATA[q.id]
              local ez = qd and qd.e and RG.MapZone and RG.MapZone(qd.e[1])
              why = "hand in" .. ((ez and ez ~= r.zone) and (" in " .. ez) or "")
            else
              local z = spotZone[q.title]
              if z and z ~= r.zone then why = "in " .. z
              elseif z == nil then
                local rep = false
                for _, o in ipairs(q.objs or {}) do if o.type == "reputation" and not o.finished then rep = true end end
                why = rep and "reputation" or "no place known"
              else why = "left out" end
            end
            rest[#rest + 1] = { q = q, why = why }
          end
        end
        if #rest > 0 then
          n = n + 1; y = item(n, y, "|cffc9a54aAlso in your log|r", { single = true, indent = 2, right = "|cff9a8a6a" .. #rest .. "|r",
            tip = "Your " .. r.zone .. " quests the plan can't take you to here: their objectives are in another zone, there's no known place for them, or what's left is a reputation. Hover one for more; click to open it." })
          for i, e in ipairs(rest) do
            if i > 5 then n = n + 1; y = item(n, y, GREY .. "+" .. (#rest - 5) .. " more in your quest log|r", { single = true, indent = 12 }) break end
            local q = e.q
            n = n + 1
            y = item(n, y, RG.LevelTag(q.level) .. "|cff9a8a6a" .. q.title .. "|r", { single = true, indent = 12, right = "|cff9a8a6a" .. e.why .. "|r", wp = q.wp,
              tip = questTip(q), onClick = function() RG.OpenQuest(q.title, q.id) end })
          end
        end
      end
      afterSteps()
    elseif cur then
      -- the step done just before it (where you are in the zone)
      for i = cur - 1, 1, -1 do if RG.StepIsDone(r, i) then stepRow(i, "done") break end end
      local qlines, wp, sk, full = stepRow(cur, "cur")
      if qlines then
        -- the arrow goes to the first thing to do: a hand-in, else a pick-up, else the hub
        if RG.AutoPin and not (RG.Opt("smartPlan") and RG.Objective and RG.Objective()) then
          local first = qlines[1]
          if first and first.wp and (first.act == "turnin" or first.act == "pickup") then RG.AutoPin(sk .. "@" .. first.act .. first.id, first.wp)
          elseif wp then RG.AutoPin(sk, wp) end
        end
        -- its quests, one line each: an icon per kind of task, like the quest log (? hand in, ! pick up, sword to do, clock for later)
        local VERB = { turnin = "|TInterface\\GossipFrame\\ActiveQuestIcon:13:13:0:-1|t ", pickup = "|TInterface\\GossipFrame\\AvailableQuestIcon:13:13:0:-1|t ",
          doing = "|TInterface\\Icons\\INV_Sword_27:13:13:0:-1:64:64:5:59:5:59|t ", later = "|TInterface\\Icons\\INV_Misc_PocketWatch_01:13:13:0:-1:64:64:5:59:5:59|t " }
        local shownL = 0
        for _, l in ipairs(qlines) do
          if shownL < 6 then
            shownL = shownL + 1
            local nameCol = (l.act == "later" and GREY) or (l.act == "turnin" and "|cff8be0a4") or (l.act == "doing" and "|cff9fd4ff") or "|cffffffff"
            local rt
            if l.act == "turnin" then rt = GREEN .. "hand in|r"
            elseif l.act == "pickup" then rt = GREY .. "pick up|r"
            elseif l.act == "doing" then rt = l.prog and ("|cffffffff" .. l.prog .. "|r") or (GREY .. "in your log|r")
            else rt = GREY .. "later|r" end
            local tip
            if l.act == "turnin" then tip = "Done: take it back to " .. (l.npc or "the quest giver") .. "."
            elseif l.act == "pickup" then tip = l.how or ("Get this quest from " .. (l.npc or "the quest giver") .. ".")
            elseif l.act == "doing" then tip = "In your quest log: finish its objectives."
            else tip = "Not open yet: it becomes available " .. l.npc .. "." end
            if l.wp then tip = tip .. "\n\n" .. GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Right-click:|r show it on the map" end
            if l.act == "doing" then tip = tip .. (l.wp and "\n" or "\n\n") .. GOLD .. "Click:|r open the quest" end
            -- what kind of quest it is, and the one thing people get wrong about it (QuestNotes.lua)
            local qn = RG.QuestNote(l.id)
            tip = tip .. noteTip(qn) .. upTip(l.id) .. ((RG.DropTip and l.act ~= "turnin" and l.act ~= "later") and RG.DropTip(l.id) or "")
            n = n + 1
            y = item(n, y, (isTarget(l.wp) and ARROW or "") .. VERB[l.act] .. nameCol .. l.name .. "|r" .. ((qn and qn.tag) and ("  " .. qn.tag) or "") .. upTag(l.id),
              { single = true, indent = 26, band = true, right = rt, wp = l.wp, tip = "|cffffffff" .. l.name .. "|r\n" .. tip,
                onClick = function() if l.act == "doing" then RG.OpenQuest(l.name, l.id) elseif l.wp then RG.PinWaypoint(l.wp) end end,
                onRightClick = l.wp and function() RG.Follow(l.wp) end or nil })
          end
        end
        if #qlines > shownL then n = n + 1; y = item(n, y, GREY .. "+" .. (#qlines - shownL) .. " more on the Route tab|r", { single = true, indent = 26, band = true, noArrow = true, onClick = function() if RG.ShowTab then RG.ShowTab("route") end end }) end
      else
        -- a hand-written step: what it says, in full
        if wp and RG.AutoPin then RG.AutoPin(sk, wp) end
        n = n + 1
        y = item(n, y, GREY .. full .. "|r", { indent = 22, band = true, wp = wp,
          tip = GOLD .. "Shift-click:|r tick this off" .. (wp and ("\n" .. GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Right-click:|r show " .. tostring(wp[4]) .. " on the map") or ""),
          onClick = function() if IsShiftKeyDown and IsShiftKeyDown() then RG.TickStep(sk, steps[cur]) end end,
          onRightClick = wp and function() RG.Follow(wp) end or nil })
      end
      -- the steps after it
      local shownN, more = 0, 0
      for i = 1, #steps do
        if i ~= cur and not RG.StepIsDone(r, i) then
          if shownN < 4 then shownN = shownN + 1; stepRow(i, "todo") else more = more + 1 end
        end
      end
      if more > 0 then
        n = n + 1; y = item(n, y, GREY .. "+" .. more .. " more step" .. (more == 1 and "" or "s") .. " on the Route tab|r", { single = true, indent = 22, onClick = function() if RG.ShowTab then RG.ShowTab("route") end end })
      end
      afterSteps()
    elseif #steps == 0 then
      n = n + 1; y = item(n, y, GOLD .. "New zone: steps are coming.|r " .. GREY .. "Take the quests you find here. The Route tab has other zones for your level.|r", { onClick = function() if RG.ShowTab then RG.ShowTab("route") end end })
    elseif view == "zone" then
      n = n + 1; y = item(n, y, GREEN .. "All done in " .. r.zone .. ".|r", { single = true, onClick = function() if RG.ShowTab then RG.ShowTab("route") end end,
        tip = "Zone quests keeps to one zone, so it won't send you elsewhere. Go to the next zone yourself (below), or pick one at the top of the tracker, and it follows you there.\n\n" .. GOLD .. "Click:|r the Route tab" })
      y = RG.TrackerNextZones and RG.TrackerNextZones(n, y, item, r) or y
      n = RG.trackerN or n
    else
      n = n + 1; y = item(n, y, GREEN .. "All done here. The Route tab has your next zone.|r", { single = true, onClick = function() if RG.ShowTab then RG.ShowTab("route") end end })
    end
    local u = lastTick(key .. "#")
    if u then
      local short = oneLine(u.text); if #short > 30 then short = short:sub(1, 28) .. "..." end
      n = n + 1
      y = item(n, y, GREY .. "Skipped: " .. short .. "|r", { single = true, right = GOLD .. "Undo|r", tip = "Click to put this step back on your list.\n" .. GREY .. oneLine(u.text) .. "\n/wp undo does the same.|r",
        onClick = function() RG.UndoTick() end })
    end
    y = gap(y)
    if view == "guide" then comingUp(r) end
  end
  if view == "guide" or view == "zone" then routeSection() end
  if view == "log" and #quests > 0 then
    local ready = 0
    for _, q in ipairs(quests) do if q.complete then ready = ready + 1 end end
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "Quests", "quests", GREY .. #quests .. "/" .. ((C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()) or 20) .. (ready > 0 and ("  ·  " .. GREEN .. ready .. " ready|r") or "") .. "|r")
    if not isFolded then
      -- turn-in run: the arrow chains through every ready quest, nearest first
      local readyWp = RG.ReadyQuests and #RG.ReadyQuests() or 0
      local running = RG.TurnInRunActive and RG.TurnInRunActive()
      if readyWp >= 2 or running then
        n = n + 1
        y = item(n, y, (running and (GREEN .. "Turn-in run on|r" .. GREY .. ": " .. readyWp .. " left (click to stop)|r") or (GREEN .. "Turn-in run|r" .. GREY .. ": " .. readyWp .. " ready, nearest first|r")),
          { single = true, indent = 2, tip = "Click: the arrow takes you to each ready quest in turn, nearest first, and moves on as you hand them in.",
            onClick = function() if RG.TurnInRun then RG.TurnInRun() end end })
      end
      -- grouped by zone: the zone you're in first, then the nearest zones
      local here = RG.ZoneName()
      local groups, byZone = {}, {}
      -- quests you hid from the tracker (right-click > Hide); gone from the list once they leave your log
      local hiddenQ, hiddenN = RG.db.trackerHidden, 0
      if hiddenQ then
        local inLog = {}
        for _, q in ipairs(quests) do inLog[q.id] = true end
        for id in pairs(hiddenQ) do if not inLog[id] then hiddenQ[id] = nil end end
        if next(hiddenQ) == nil then RG.db.trackerHidden = nil; hiddenQ = nil end
      end
      local dunN = 0
      for _, q in ipairs(quests) do
        if hiddenQ and hiddenQ[q.id] then hiddenN = hiddenN + 1
        elseif not q.complete and RG.DungeonQuestHidden and RG.DungeonQuestHidden(q.id, q.zone) then dunN = dunN + 1 else
        local z = q.zone or "Other"
        local g = byZone[z]
        if not g then g = { zone = z, list = {}, here = (z == here) }; byZone[z] = g; groups[#groups + 1] = g end
        g.list[#g.list + 1] = q
        if q.dist and (not g.dist or q.dist < g.dist) then g.dist = q.dist end
        if q.complete then g.ready = (g.ready or 0) + 1 end
        g.minLevel = math.min(g.minLevel or 99, q.level or 99)
        end
      end
      table.sort(groups, function(a2, b2)
        if a2.here ~= b2.here then return a2.here end
        if (a2.dist ~= nil) ~= (b2.dist ~= nil) then return a2.dist ~= nil end
        if a2.dist and b2.dist and a2.dist ~= b2.dist then return a2.dist < b2.dist end
        return a2.minLevel < b2.minLevel
      end)
      local shownQ, hidden = 0, 0
      for _, g in ipairs(groups) do
        if shownQ >= MAXQ or (compact and not g.here and not g.ready and (g.dist or 1e9) > 2500) then hidden = hidden + #g.list   -- compact: far zones fold into "+N more"
        else
          local zf = RG.db.trackerFold and RG.db.trackerFold["zone:" .. g.zone]
          n = n + 1
          y = item(n, y, (zf and "+ " or "") .. "|cffc9a54a" .. g.zone .. "|r" .. (g.here and "|cff9a8a6a  (you're here)|r" or ""),
            { single = true, indent = 2, right = "|cff9a8a6a" .. #g.list .. (g.ready and ("  ·  |cff1eff00" .. g.ready .. " ready|r") or "") .. "|r",
              tip = "Click to fold or show this zone's quests.",
              onClick = function()
                RG.db.trackerFold = RG.db.trackerFold or {}
                RG.db.trackerFold["zone:" .. g.zone] = not RG.db.trackerFold["zone:" .. g.zone] or nil
                RG.RefreshTracker()
              end })
          if not zf then
            -- one quest line (level, name, progress, distance)
            local function questLine(q)
                local frac
                if not q.complete and q.prog then
                  local sum, k = 0, 0
                  for a, b in tostring(q.prog):gmatch("(%d+)%s*/%s*(%d+)") do
                    a, b = tonumber(a), tonumber(b)
                    if b and b > 0 then sum = sum + math.min(1, a / b); k = k + 1 end
                  end
                  if k > 0 then frac = sum / k end
                end
                local status
                if q.complete then status = "|cff1eff00turn in|r"
                elseif q.failed then status = "|cffff3333failed|r"
                else status = q.prog and ("|cffffffff" .. q.prog .. "|r") or "" end
                -- (as the quest log reads: no distance on the line, it's in the tooltip; the quest's usable item is on the
                -- current step's card, not on the list)
                local where = ""
                -- objectives under the quest (a setting)
                local objOn = RG.Opt("trackerObjectives") and not q.failed
                if objOn and RG.Opt("trackerFocus") and RG.TrackerQuestActive and not q.complete then objOn = RG.TrackerQuestActive(q) end   -- only the quest being worked on opens
                local itm = nil
                local rpad = nil
                n = n + 1
                local titleN = n
                local qn = RG.QuestNote(q.id, q.group)
                local rbase = objOn and ((q.failed and status or "") .. where) or (status .. where)
                local tm = RG.TrackerTimerText and RG.TrackerTimerText(q.id) or ""   -- a timed quest: the time left, ticking
                -- the title in its level's colour (grey, green, yellow, orange, red), green once it's ready to hand in
                local tcol = q.complete and "|cff1eff00" or ((q.level and RG.QuestColor and RG.QuestColor(q.level)) or "|cffffd100")
                y = item(n, y, (isTarget(q.wp) and ARROW or "") .. RG.LevelTag(q.level) .. upFront(q.id) .. tcol .. q.title .. "|r" .. (q.group and (GREY .. " (group)|r") or "") .. ((qn and qn.tag) and ("  " .. qn.tag) or ""),
                  { single = true, indent = 12, quest = true, rpad = rpad, right = tm .. rbase, timer = tm ~= "" and q.id or nil, rbase = rbase,
                    tip = questTip(q), wp = q.wp,
                    -- a quest ready to hand in: click points the arrow at the hand-in, right-click opens it
                    onClick = function()
                      -- Shift-click with a chat box open: link the quest in chat
                      if IsShiftKeyDown and IsShiftKeyDown() and RG.LinkQuestInChat and RG.LinkQuestInChat(q) then return end
                      if q.complete and q.wp and not (IsShiftKeyDown and IsShiftKeyDown()) then RG.Follow(q.wp) else RG.OpenQuest(q.title, q.id) end
                    end,
                    menu = function()
                      local e = {}
                      e[#e + 1] = { "Link in chat", function() if not (RG.LinkQuestInChat and RG.LinkQuestInChat(q, true)) then RG.Print("Open a chat box first (press Enter), then try again.") end end }
                      e[#e + 1] = { "Hide from the tracker", function() RG.db.trackerHidden = RG.db.trackerHidden or {}; RG.db.trackerHidden[q.id] = true; RG.RefreshTracker() end }
                      if q.wp then e[#e + 1] = { q.complete and "Arrow to the hand-in" or "Arrow to this quest", function() RG.Follow(q.wp) end } end
                      e[#e + 1] = { "Open in your quest log", function() RG.OpenQuest(q.title, q.id) end }
                      if not q.complete then e[#e + 1] = { "Skip it for now (10 min)", function() if RG.SkipQuest then RG.SkipQuest(q.title) end; RG.RefreshTracker() end } end
                      return e, RG.LevelTag(q.level) .. q.title
                    end,
                    -- right-click: the arrow follows this quest
                    onRightClick = function()
                      if q.wp then RG.Follow(q.wp)
                      else RG.Print("No location known for " .. q.title .. " yet. Click it to open the quest.") end
                    end })
                if itm and RG.TrackerItemPlace then RG.TrackerItemPlace(lines[titleN], itm, q) end
                if not objOn then return end
                if q.complete then
                  n = n + 1
                  y = item(n, y, GREEN .. "Ready to hand in|r" .. ((q.label and q.label ~= "") and (GREY .. " at " .. q.label .. "|r") or ""),
                    { single = true, indent = 24, tickAt = 10, rpad = rpad, tip = GREEN .. "Done: ready to hand in|r\n\n" .. GOLD .. "Click:|r arrow to the hand-in",
                      onClick = function() if q.wp then RG.Follow(q.wp) else RG.OpenQuest(q.title, q.id) end end })
                  return
                end
                for oi, o in ipairs(q.objs or {}) do
                  if o.text and o.text ~= "" then
                    local name, have, need, done, col = RG.TrackerObjective(o)
                    n = n + 1
                    y = item(n, y, (done and GREY or "|cffe6e6e6") .. name .. "|r",
                      { single = true, indent = 24, tickAt = done and 10 or nil, rpad = rpad, live = { q.id, oi },
                        right = (need and need > 0) and (col .. (have or 0) .. "/" .. need .. "|r") or nil,
                        -- hover: where it is (worked out when you point at it, not on every redraw)
                        tipFn = function()
                          local t = "|cffffffff" .. name .. "|r" .. ((need and need > 0) and (GREY .. "  " .. (have or 0) .. "/" .. need .. "|r") or "")
                          if not done then
                            local wp, src, dist = RG.QuestObjectiveSpot and RG.QuestObjectiveSpot(q.title, name)
                            if wp then
                              local zone = C_Map and C_Map.GetMapInfo and wp[1] and C_Map.GetMapInfo(wp[1])
                              t = t .. "\n" .. GREY .. "Nearest: " .. ((src and src ~= name) and (src .. ", ") or "") .. ((zone and zone.name) and (zone.name .. ", ") or "") ..
                                (dist and RG.FormatYards and RG.FormatYards(dist) or "") .. "|r"
                            else t = t .. "\n" .. GREY .. "No place known for it yet.|r" end
                            if RG.DropTip then t = t .. RG.DropTip(q.id, name) end
                            t = t .. "\n\n" .. GOLD .. "Click:|r the arrow to the nearest place for it\n"
                          else t = t .. "\n\n" end
                          return t .. GOLD .. "Shift-click:|r open in your quest log"
                        end,
                        onClick = function()
                          if done or (IsShiftKeyDown and IsShiftKeyDown()) then RG.OpenQuest(q.title, q.id) return end
                          local wp = RG.QuestObjectiveSpot and RG.QuestObjectiveSpot(q.title, name)
                          if wp then
                            if RG.ArrowTarget and RG.ArrowTarget(wp) and RG.ArrowTo then RG.ArrowTo(wp) else RG.Follow(wp) end
                          else RG.OpenQuest(q.title, q.id) end
                        end })
                  end
                end
            end
            -- ready-to-hand-in quests never count towards the limit and three or more fold into one line (the turn-in run
            -- takes you round them), so they can't push the quests you're still doing out of the list
            local readyL, active = {}, {}
            for _, q in ipairs(g.list) do if q.complete then readyL[#readyL + 1] = q else active[#active + 1] = q end end
            if #readyL >= 3 then
              local names = {}
              for _, q in ipairs(readyL) do names[#names + 1] = q.title end
              n = n + 1
              y = item(n, y, GREEN .. #readyL .. " ready to turn in|r" .. GREY .. ": " .. table.concat(names, ", ") .. "|r",
                { single = true, indent = 12, tip = GREEN .. "Ready to turn in:|r\n" .. table.concat(names, "\n") .. ((RG.TurnInPlanText and ("\n\n" .. GOLD .. "Plan:|r " .. RG.TurnInPlanText())) or "") .. "\n\n" .. GOLD .. "Click:|r the turn-in run: this zone first, then the others by how quickly you get there",
                  onClick = function() if RG.TurnInRun then RG.TurnInRun() end end })
            else
              for _, q in ipairs(readyL) do questLine(q) end
            end
            for k, q in ipairs(active) do
              if g.here then
                -- the zone you're in: every quest you're still doing is listed, whatever the limit
                if k > 15 then hidden = hidden + 1 else shownQ = shownQ + 1; questLine(q) end
              elseif shownQ >= MAXQ then hidden = hidden + 1
              else shownQ = shownQ + 1; questLine(q) end
            end
          end
        end
      end
      if hiddenN > 0 then
        n = n + 1; y = item(n, y, GREY .. hiddenN .. " hidden|r", { single = true, indent = 12, tip = "You hid " .. hiddenN .. " quest" .. (hiddenN == 1 and "" or "s") .. " from the tracker.\n\n" .. GOLD .. "Click:|r show them again",
          onClick = function() RG.db.trackerHidden = nil; RG.RefreshTracker() end })
      end
      if dunN > 0 then
        n = n + 1; y = item(n, y, GREY .. dunN .. " dungeon quest" .. (dunN == 1 and "" or "s") .. " hidden  ·  show|r", { single = true, indent = 12,
          tip = "Quests you can only finish inside a dungeon are left out (the menu at the top of the tracker, or Settings > Tracker).\n\n" .. GOLD .. "Click:|r show them again",
          onClick = function() RG.db.dungeonQuests = true; if RG.RouteChanged then RG.RouteChanged() end end })
      end
      if hidden > 0 then
        n = n + 1; y = item(n, y, GREY .. "+" .. hidden .. " more in your quest log|r", { single = true, indent = 12, onClick = function() if ToggleQuestLog then ToggleQuestLog() end end })
      end
    end
    y = gap(y)
  end
  -- new quests to pick up nearby (not the ones the route already lists)
  do
    local r0 = currentEntry()
    if r0 and #new > 0 then
      local steps0 = RG.STEPS[r0.zone .. "|" .. r0.from] or {}
      for i = 1, #steps0 do
        if not RG.StepIsDone(r0, i) then
          local ql = RG.StepQuestLines(r0, i, quests)
          if ql then
            local skip = {}
            for _, l in ipairs(ql) do skip[l.id] = true end
            for k = #new, 1, -1 do if new[k].id and skip[new[k].id] then table.remove(new, k) end end
          end
          break
        end
      end
    end
    for k = #new, 3, -1 do new[k] = nil end
  end
  if view == "log" and #new > 0 then
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "New quests nearby", "new")
    if not isFolded then
      for _, q in ipairs(new) do
        n = n + 1
        y = item(n, y, (isTarget(q.wp) and ARROW or "") .. RG.LevelTag(q.lvl) .. upFront(q.id) .. "|cffffffff" .. q.name .. "|r", { single = true, right = GREY .. RG.FormatYards(q.dist) .. "|r", wp = q.wp,
          tip = RG.LevelTag(q.lvl) .. "|cffffffff" .. q.name .. "|r\n" .. GREY .. "From " .. (q.giver or "a quest giver") .. "|r" .. upTip(q.id) .. "\n\n" .. GOLD .. "Click:|r show " .. (q.giver or "the quest giver") .. " on the map\n" .. GOLD .. "Click:|r arrow on / off",
          onClick = function() RG.PinWaypoint(q.wp) end, onRightClick = function() RG.Follow(q.wp) end,
          menu = function()
            return { { "Arrow to " .. (q.giver or "the quest giver"), function() RG.Follow(q.wp) end },
                     { "Don't suggest this quest", function() if RG.IgnoreQuest then RG.IgnoreQuest(q.id) end; RG.RefreshTracker() end } }, RG.LevelTag(q.lvl) .. q.name
          end })
      end
    end
    y = gap(y)
  end
  -- 3b. hand-written class chain (paladin): the next step for your level
  local shownClassSteps = view == "prof" or view == "dungeon"
  for _, pr in ipairs((view ~= "prof" and view ~= "dungeon") and RG.ROUTE or {}) do
    if pr.kind == "pala" and lvl >= pr.from and lvl <= pr.to then
      local pkey = pr.zone .. "|" .. pr.from
      local psteps = RG.STEPS[pkey] or {}
      local left, first, firstI = 0, nil, nil
      for i, text in ipairs(psteps) do
        if not RG.StepIsDone(pr, i) then left = left + 1; if not first then first, firstI = text, i end end
      end
      if first then
        local isFolded
        shownClassSteps = true
        n = n + 1; y, isFolded = section(n, y, "Class quests: " .. pr.hub, "pala", GREY .. left .. " to do|r")
        if not isFolded then
          local sk = pkey .. "#" .. firstI
          local wp = RG.StepWaypoint and RG.StepWaypoint(pr, firstI)
          n = n + 1
          y = item(n, y, (isTarget(wp) and ARROW or (wp and RG.PIN or "")) .. first, { box = false, wp = wp,
            tip = GOLD .. "Shift-click:|r tick this off" .. (wp and ("\n" .. GOLD .. "Click:|r arrow on / off\n" .. GOLD .. "Right-click:|r show " .. wp[4] .. " on the map") or "") .. "\nThe Route tab has the whole chain.",
            onClick = function() if IsShiftKeyDown and IsShiftKeyDown() then RG.TickStep(sk, first) end end, onRightClick = wp and function() RG.Follow(wp) end or nil })
        end
        y = gap(y)
      end
      break
    end
  end
  -- 3c. class quests from the quest database (every class): shown when no
  -- hand-written class chain is active right now
  if not shownClassSteps and RG.ClassQuests then
    local cq = RG.ClassQuests(3)
    if #cq > 0 then
      local isFolded
      n = n + 1; y, isFolded = section(n, y, "Class quests", "pala", cq[1].now and (GREEN .. "pick up now|r") or (GREY .. "at " .. cq[1].req .. "|r"))
      if not isFolded then
        for _, q in ipairs(cq) do
          local wp = q.wp
          n = n + 1
          y = item(n, y, (isTarget(wp) and ARROW or "") .. RG.LevelTag(q.lvl) .. (q.now and "|cffffd100" or GREY) .. q.name .. "|r", { single = true, wp = wp,
            right = q.now and (GREY .. "from " .. (q.giver or "?") .. "|r") or (GREY .. "at level " .. q.req .. "|r"),
            tip = "|cffffffff" .. q.name .. "|r\n" .. GREY .. "From " .. (q.giver or "?") .. (q.now and "" or (" at level " .. q.req)) .. "|r\n\n" .. GOLD .. "Click:|r show the quest giver on the map\n" .. GOLD .. "Click:|r arrow on / off",
            onClick = function() RG.PinWaypoint(wp) end })
        end
      end
      y = gap(y)
    end
  end
  -- 4. next dungeon: quests still to collect
  local dr, dq = nil, nil   -- dungeons: on the Route page in the main window
  if dr then
    local missing = {}
    for _, q in ipairs(dq.quests) do
      local st = RG.QuestState and RG.QuestState((q[1]:gsub("%s*%(.-%)$", "")))
      if not st and (not q.id or RG.QuestPrereqsMet(q.id)) then missing[#missing + 1] = q end
    end
    local isFolded
    n = n + 1; y, isFolded = section(n, y, dr.zone, "dungeon", lvl >= dq.go and (GREEN .. "go now|r") or (GREY .. "go at " .. dq.go .. "|r"))
    if not isFolded then
      if lvl >= dq.go and RG.TravelSummary then
        local tip = RG.TravelSummary(dr.zone)
        if tip then n = n + 1; y = item(n, y, GOLD .. "Getting there:|r " .. tip, { wp = destWp(dr), tip = "Click: arrow to " .. dr.zone }) end
      end
      if #missing == 0 then n = n + 1; y = item(n, y, GREEN .. "All its quests are in your log.|r", { single = true })
      else
        for i = 1, math.min(3, #missing) do
          local q = missing[i]
          local gw = q.wp or (RG.WAYPOINTS and RG.WAYPOINTS.givers[q[2]])
          n = n + 1
          y = item(n, y, (isTarget(gw) and ARROW or "") .. RG.LevelTag(RG.QuestLevel(q[1])) .. "|cffffd100" .. q[1] .. "|r", { single = true, right = GREY .. "pick up|r", wp = gw,
            tip = "|cffffffff" .. q[1] .. "|r\n" .. GREY .. q[2] .. ", " .. q[3] .. "|r" .. (gw and ("\n\n" .. GOLD .. "Click:|r show " .. q[2] .. " on the map\n" .. GOLD .. "Click:|r arrow on / off") or ""),
            onClick = gw and function() RG.PinWaypoint(gw) end or nil, onRightClick = gw and function() RG.Follow(gw) end or nil })
        end
        if #missing > 3 then n = n + 1; y = item(n, y, GREY .. "+" .. (#missing - 3) .. " more on the Route tab|r", { single = true, onClick = function() if RG.ShowTab then RG.ShowTab("route") end end }) end
      end
      -- what it drops for you
      local drops = RG.DungeonDrops and RG.DungeonDrops(dr.zone, 2) or {}
      if #drops > 0 then
        local parts = {}
        for _, dd in ipairs(drops) do parts[#parts + 1] = (RG.ItemInfo(dd.g.id) or "item") .. " " .. GREEN .. string.format("+%.0f", dd.d) .. "|r" end
        n = n + 1; y = item(n, y, GOLD .. "Drops for you:|r " .. table.concat(parts, GREY .. ", |r"), { tip = GREY .. "Upgrades from your gear guide that drop here.|r", onClick = function() if RG.ShowTab then RG.ShowTab("gear") end end })
      end
    end
    y = gap(y)
  end
  -- 5. next upgrade (one line)
  local up = nil   -- upgrades: the Gear guide (and the Gear badge) in the main window
  if up then
    local name = RG.ItemInfo(up.g.id) or "item"
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "Next upgrade", "upgrade")
    if not isFolded then
      n = n + 1; y = item(n, y, "|cffffffff" .. name .. "|r", { single = true, right = GREEN .. string.format("+%.0f", up.d) .. "|r",
        tip = "|cffffffff" .. name .. "|r  " .. GREEN .. string.format("+%.0f %s", up.d, RG.SCORE_NAME) .. "|r\n" .. GREY .. up.g.src .. ", " .. up.g.zone .. "|r\n\n" .. GOLD .. "Click:|r where it drops or which quest gives it\n" .. GOLD .. "Right-click:|r open the Gear guide",
        wp = RG.WaypointForText and RG.WaypointForText(up.g.src or ""),
        onClick = function() if RG.ShowItemSource then RG.ShowItemSource(up.g, { note = GREEN .. string.format("+%.0f", up.d) .. "|r" .. GREY .. " over what you wear|r" }) end end,
        onRightClick = function() if RG.ShowTab then RG.ShowTab("guide") end end })
    end
    y = gap(y)
  end
  -- 5a. preobtain dungeon quests (DungeonPrep.lua): every quest once, one per line, in the order you can do them (the
  -- ones you can work on now in the planner's order, so the first is the current step; then the ones they open, and so
  -- on). Click a quest to go and do it (one that waits: the quest it waits on).
  if view == "dungeon" and RG.PrepPlan then
    local pl = RG.PrepPlan()
    local work = RG.PrepWork()
    local gp = RG.GuidePlan and RG.GuidePlan()
    local stops = gp and gp.stops or {}
    local okO, curObj = pcall(RG.Objective or function() end)
    curObj = okO and curObj or nil
    local curIds = {}
    if curObj and curObj.stop then for _, it in ipairs(curObj.stop.items or {}) do if it.id then curIds[it.id] = true end end end
    if curObj and curObj.id then curIds[curObj.id] = true end
    local rows, skipped = RG.PrepList(pl, stops, work)
    local nowN = 0
    for _, r in ipairs(rows) do if r.g == "now" then nowN = nowN + 1 end end
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "Quests · " .. tostring(pl.name or "no dungeon"), "prepquests",
      pl.total > 0 and (GREY .. (nowN > 0 and (nowN .. " to do now") or (pl.obtained .. "/" .. pl.can .. " in your log")) .. "|r") or nil)
    if not isFolded then
      if pl.total == 0 then
        n = n + 1; y = item(n, y, GREY .. "Nothing to collect for " .. tostring(pl.name or "this dungeon") .. ". Pick another dungeon above.|r", { onClick = function() if RG.ShowTab then RG.ShowTab("dungeons") end end })
      elseif nowN == 0 then
        n = n + 1
        y = item(n, y, pl.ready and (GREEN .. "Ready for " .. pl.name .. ": every quest you can get before the run is in your log.|r")
          or (GREY .. "Nothing to go and do right now: " .. pl.waiting .. " wait for a level or an earlier quest.|r"), { indent = 2 })
      end
      local byId = {}
      for _, r in ipairs(rows) do byId[r.s.id] = r end
      for _, r in ipairs(rows) do
        local st = r.s
        local isCur = curIds[st.id] and r.g == "now"
        local goal = RG.PrepRowGoal(r, rows)
        local wp = goal and goal.stop and goal.stop.stop.wp
        local col = (r.g == "now" and "|cffffffff") or (r.g == "have" and GREEN) or "|cff9a9a9a"
        local zone = r.stop and r.stop.stop.wp and RG.MapZone and RG.MapZone(r.stop.stop.wp[1])
        -- the tooltip: what's next for it, or why it waits
        local lines = { "|cffffffff" .. st.name .. "|r" .. (st.level and (GREY .. "  (level " .. st.level .. ")|r") or "") }
        if r.stop then lines[#lines + 1] = RG.PrepStepText(r.stop.item) .. (zone and (GREY .. ", " .. zone .. "|r") or "") end
        if r.g == "have" then lines[#lines + 1] = GREY .. "In your log: one of " .. tostring(pl.name) .. "'s quests, kept for the run.|r"
        elseif r.g == "after" then lines[#lines + 1] = GREY .. "Comes after a quest you can only do inside " .. tostring(pl.name) .. ".|r"
        elseif r.g == "inside" then lines[#lines + 1] = GREY .. (st.why and (st.why:gsub("^%l", string.upper)) or "Starts inside the dungeon") .. ": pick it up during the run.|r"
        elseif st.why then lines[#lines + 1] = GREY .. (st.why:gsub("^%l", string.upper)) .. ".|r" end
        if #r.before > 0 then
          local names = {}
          for _, p in ipairs(r.before) do names[#names + 1] = byId[p] and byId[p].s.name or "?" end
          lines[#lines + 1] = GREY .. "First: " .. table.concat(names, ", ") .. "|r"
        end
        if (work.keep[st.id] or st.target) and r.g ~= "have" and r.g ~= "after" and r.g ~= "inside" then
          lines[#lines + 1] = GREY .. "One of " .. tostring(pl.name) .. "'s quests: pick it up and keep it for the run.|r"
        end
        lines[#lines + 1] = ""
        if goal and goal ~= r then lines[#lines + 1] = GOLD .. "Click:|r go and do " .. goal.s.name .. " first"
        elseif goal then lines[#lines + 1] = GOLD .. "Click:|r make it the current step"
        elseif r.g == "have" or st.state == "have" or st.state == "ready" then lines[#lines + 1] = GOLD .. "Click:|r open it in your quest log" end
        lines[#lines + 1] = GOLD .. "Right-click:|r skip it and the rest of its chain (or bring it back)"
        n = n + 1
        y = item(n, y, ((wp and isTarget(wp) and r.g == "now") and ARROW or "") .. RG.LevelTag(st.level) .. col .. st.name .. "|r",
          { single = true, indent = 2, band = isCur, right = RG.PrepRowAction(r), tip = table.concat(lines, "\n"),
            onClick = function()
              if wp then
                if RG.Follow then RG.Follow(wp) end
                if RG.SyncObjective and RG.Objective then RG.SyncObjective(RG.Objective(true)) end
                RG.RefreshTracker()
              elseif (st.state == "have" or st.state == "ready") and RG.OpenQuest then RG.OpenQuest(st.name, st.id) end
            end,
            onRightClick = function() RG.PrepSkipMenu(r.t, st) end })
      end
      if skipped > 0 then
        n = n + 1; y = item(n, y, GREY .. skipped .. " skipped  ·  bring back|r", { single = true, indent = 2,
          tip = "Quests you skipped, with their chains. Journey > Dungeon quests brings them back.\n\n" .. GOLD .. "Click:|r open it",
          onClick = function() if RG.ShowTab then RG.ShowTab("dungeons") end end })
      end
    end
    y = gap(y)
  end
  -- 5b. professions (the menu at the top: Professions): the step you're on in each, and what you're short of
  if view == "prof" then
    local entries = RG.ProfEntries and RG.ProfEntries() or {}
    n = n + 1; y = section(n, y, "Professions", nil, GREY .. #entries .. "|r")
    if #entries == 0 then
      n = n + 1; y = item(n, y, GREY .. "No profession to level right now. Learn one at a trainer, or open the Professions page for plans.|r", { onClick = function() if RG.ShowTab then RG.ShowTab("prof") end end })
    end
    for i = 1, math.min(6, #entries) do
      local e = entries[i]
      local pl = e.place
      n = n + 1
      y = item(n, y, (isTarget(pl and pl.wp) and ARROW or "") .. "|cffffffff" .. e.name .. " " .. e.rank .. "|r  " .. e.text, { single = true, wp = pl and pl.wp,
        tip = "|cffffffff" .. e.name .. "|r " .. e.rank .. "\n" .. e.text .. (pl and ("\n\n" .. GOLD .. "Click:|r arrow to " .. (pl.wp and pl.wp[4] or pl.title or "it")) or "") .. "\n" .. GOLD .. "Right-click:|r open its guide",
        onRightClick = function() if RG.ShowProf then RG.ShowProf(e.name) end end,
        onClick = (not pl or not pl.wp) and function() if RG.ShowProf then RG.ShowProf(e.name) end end or nil })
    end
    y = gap(y)
  end
  -- 6. reminders: the most important few
  local rem = {}   -- reminders: in the main window and as pop-ups
  if #rem > 0 then
    for i, rr in ipairs(rem) do rr.i = i end
    table.sort(rem, function(a, b) local pa, pb = a[3] or 3, b[3] or 3; if pa ~= pb then return pa < pb end return a.i < b.i end)
    local isFolded
    n = n + 1; y, isFolded = section(n, y, "Reminders", "reminders", GREY .. #rem .. "|r")
    if not isFolded then
      for i = 1, math.min(4, #rem) do local rr = rem[i]; n = n + 1; y = item(n, y, rr[1], { onClick = rr[2], wp = rr[4], tip = rr[4] and (GOLD .. "Click:|r arrow on / off") or nil }) end
      if #rem > 4 then n = n + 1; y = item(n, y, GREY .. "+" .. (#rem - 4) .. " more  ·  turn reminders off in Settings|r", { single = true, onClick = function() if RG.ShowTab then RG.ShowTab("settings") end end }) end
    end
  end
  -- the sections that were folded into one row
  lastSkipped = false
  if #hints > 0 and not moreOpen then
    local parts, full = {}, {}
    for _, h in ipairs(hints) do
      local t = h.name .. ((h.note and h.note ~= "") and (": " .. h.note) or "")
      parts[#parts + 1] = h.urgent and (GREEN .. t .. "|r") or (GREY .. t .. "|r")
      full[#full + 1] = (h.urgent and GREEN or "|cffffffff") .. t .. "|r"
    end
    n = n + 1
    y = item(n, y, "|cff8a8a8a+ MORE|r   " .. table.concat(parts, GREY .. "  ·  |r"),
      { single = true, indent = 2, tip = table.concat(full, "\n") .. "\n\n" .. GOLD .. "Click:|r show these sections",
        onClick = function() RG.db.trackerMore = true; RG.RefreshTracker() end })
  elseif moreOpen then
    n = n + 1
    y = item(n, y, "|cff8a8a8a- SHOW LESS|r", { single = true, indent = 2, tip = "Fold the extra sections back into one row.",
      onClick = function() RG.db.trackerMore = false; RG.RefreshTracker() end })
  end
  -- safety net: whatever the layout above did, no row past the last one it placed may stay on screen
  tr.rowCount = n
  for i, b in pairs(lines) do if i > n then b:Hide() end end
  if RG.TrackerItemEnd then RG.TrackerItemEnd() end
  if RG.TrackerFinish then RG.TrackerFinish(y) else tr.body:SetHeight(math.max(10, y)); tr:SetHeight(RG.TrackerTop() + y + 6 + FOOT_H) end
end

-- ---------------------------------------------------------------------------------------------------------------------
-- The menu at the top of the tracker, and the zone picker of zone quests (Smart.lua keeps the choices)
-- ---------------------------------------------------------------------------------------------------------------------
local DOT = "|TInterface\\AddOns\\Waypath\\Media\\Disc:10:10:0:0|t  "
local RING = "|TInterface\\AddOns\\Waypath\\Media\\Ring:10:10:0:0|t  "
local BOX_ON = "|TInterface\\Buttons\\UI-CheckBox-Check:16:16:0:0|t "
local BOX_OFF = "|TInterface\\Buttons\\UI-CheckBox-Up:16:16:0:0|t "
function RG.TrackerModeMenu(anchor)
  local view = RG.TrackerView()
  local function pick(v, name, about)
    local on = view == v
    return { (on and DOT or RING) .. (on and GOLD or "|cffffffff") .. name .. "|r" .. GREY .. "   " .. about .. "|r", function() RG.SetTrackerView(v) end }
  end
  local dun = RG.DungeonQuestsOn()
  RG.ShowMenu({
    { "Leveling", head = true },
    pick("guide", "Ordered guide", "the route, zone by zone"),
    pick("zone", "Zone quests", "one zone's route: yours, or pick one"),
    pick("log", "My quest log", "only the quests you have"),
    { "Other", head = true },
    pick("prof", "Professions", "your plans, step by step"),
    pick("dungeon", "Preobtain Dungeon Quests", "a dungeon's quests and their chains"),
    { " ", head = true },
    { (dun and BOX_ON or BOX_OFF) .. "Dungeon quests" .. GREY .. (dun and "   included" or "   left out") .. "|r", function()
      RG.db.dungeonQuests = not dun
      if RG.RouteChanged then RG.RouteChanged() end
    end },
  }, nil, anchor)
end

-- zone quests: the zone you're in, or one of the route's zones near your level (picked until you log out)
function RG.TrackerZoneMenu(anchor)
  local lvl = UnitLevel and UnitLevel("player") or 1
  local zn, picked = RG.FollowZone()
  local here = RG.ZoneName() or ""
  local e = { { "Zone quests: which zone?", head = true },
    { (not picked and DOT or RING) .. (not picked and GOLD or "|cffffffff") .. "The zone I'm in|r" .. GREY .. (here ~= "" and ("   " .. here .. " now") or "") .. "|r", function() RG.SetZonePick(nil) end } }
  local byZone, list = {}, {}
  for _, r in ipairs(RG.ROUTE or {}) do
    if r.kind == "zone" and r.to >= lvl - 6 and r.from <= lvl + 6 then
      local z = byZone[r.zone]
      if not z then z = { zone = r.zone, from = r.from, to = r.to, done = 0, total = 0 }; byZone[r.zone] = z; list[#list + 1] = z end
      z.from, z.to = math.min(z.from, r.from), math.max(z.to, r.to)
      local steps = RG.STEPS[r.zone .. "|" .. r.from] or {}
      z.total = z.total + #steps
      for i = 1, #steps do if RG.StepIsDone(r, i) then z.done = z.done + 1 end end
    end
  end
  table.sort(list, function(a, b) if a.from ~= b.from then return a.from < b.from end return a.zone < b.zone end)
  local band
  for i, z in ipairs(list) do
    if i > 18 then break end
    local b = math.floor(z.from / 10) * 10
    if b ~= band then band = b; e[#e + 1] = { "Levels " .. b .. "-" .. (b + 10), head = true } end
    local on = picked and zn == z.zone
    local pct = z.total > 0 and math.floor(z.done / z.total * 100 + 0.5) or nil
    e[#e + 1] = { (on and DOT or RING) .. (on and GOLD or (pct == 100 and GREY or "|cffffffff")) .. z.zone .. "|r" .. GREY .. "  " .. z.from .. "-" .. z.to ..
      (pct and (pct == 100 and "   done" or ("   " .. pct .. "%")) or "") .. (z.zone == here and "   (here)" or "") .. "|r",
      function() RG.SetZonePick(z.zone) end }
  end
  RG.ShowMenu(e, nil, anchor)
end

-- preobtain dungeon quests: which dungeon (the next one for your level unless you pick one)
function RG.TrackerDungeonMenu(anchor)
  local lvl = UnitLevel and UnitLevel("player") or 1
  local cur = RG.PrepDungeon and RG.PrepDungeon()
  local e = { { "Preobtain quests for which dungeon?", head = true } }
  local auto = not (RG.db and RG.db.prepDungeon)
  e[#e + 1] = { (auto and DOT or RING) .. (auto and GOLD or "|cffffffff") .. "The next one for my level|r", function() RG.db.prepDungeon = nil; if RG.PrepForget then RG.PrepForget() end; if RG.RouteChanged then RG.RouteChanged() end end }
  for _, d in ipairs(RG.PrepDungeons and RG.PrepDungeons() or {}) do
    if d.to >= lvl - 8 and d.from <= lvl + 10 then
      local on = not auto and d.name == cur
      e[#e + 1] = { (on and DOT or RING) .. (on and GOLD or "|cffffffff") .. d.name .. "|r" .. GREY .. "  " .. d.from .. "-" .. d.to .. "|r",
        function() RG.SetPrepDungeon(d.name) end }
    end
  end
  RG.ShowMenu(e, nil, anchor)
end

-- Your professions' next steps: { { name, rank, text, place = { title, wp } }, ... }, ones short of materials first
function RG.ProfEntries()
  local entries = {}
  if not (RG.ProfNow and RG.Professions) then return entries end
  for name, k in pairs(RG.Professions() or {}) do
    local now = RG.PROFESSIONS and RG.PROFESSIONS[name] and RG.ProfNow(name, k.rank)
    if now and now.st and not now.done then
      local text, short, firstShort
      if now.craft then
        short = 0
        for _, e in ipairs(now.mats or {}) do
          if not e.via and e.short > 0 then short = short + 1; firstShort = firstShort or e end
        end
        text = now.craft .. " x" .. (now.left or 0) .. (firstShort and (GREY .. "  ·  " .. firstShort.short .. " more " .. firstShort.name .. (short > 1 and (", +" .. (short - 1)) or "") .. "|r") or (GREEN .. "  ·  ready|r"))
      else
        text = (now.st.gather or now.st.skin or (now.st.fish and ("fish in " .. now.st.fish)) or "") .. GREY .. "  ·  to " .. now.st.to .. "|r"
      end
      local places = RG.ProfPlaces and RG.ProfPlaces(name, now) or {}
      entries[#entries + 1] = { name = name, rank = k.rank, text = text, now = now, place = places[1], order = now.craft and (firstShort and 0 or 1) or 2 }
    end
  end
  table.sort(entries, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.name < b.name end)
  return entries
end
-- the professions view's current step (the card under the tracker's header, StepView.lua)
function RG.ProfFocus()
  local e = RG.ProfEntries()[1]
  if not e then return nil end
  local second = RG.ProfEntries()[2]
  return { verb = e.now.craft and "Make" or "Gather", title = e.name .. " " .. e.rank, line = e.text, wp = e.place and e.place.wp,
    where = e.place and (e.place.title .. (e.place.sub and (", " .. e.place.sub) or "")) or nil,
    why = "Professions: the step you're on in " .. e.name .. ".", next = second and (second.name .. " " .. second.rank) or nil }
end

-- Where the tracker is: always by its top-right corner, so folding and unfolding grows and shrinks it downwards
-- (the game's own drag can leave it anchored by its middle or bottom).
function RG.TrackerSavePos()
  if not tr or InCombatLockdown() then return end
  local top, right = tr:GetTop(), tr:GetRight()
  if not (top and right) then return end
  tr:ClearAllPoints(); tr:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
  RG.db.trackerPos = { "TOPRIGHT", "BOTTOMLEFT", right, top }
end

-- Right after a /reload the game can draw some text in our own font blank until it's set again (the font file is
-- still loading): lay every line out afresh a moment later, and once more after that.
function RG.TrackerRepaint()
  if not tr then return end
  for _, b in pairs(lines) do b._sig = nil; if b.text then b.text:SetText("") end end
  if tr.title then
    local t = tr.title:GetText()
    if not tr.title:SetFont(RG.FONTS.display or RG.FONTS.semibold, 14, "") then tfont(tr.title, 14) end
    tr.title:SetText(""); tr.title:SetText(t or "")
  end
  if tr.goal then local g = tr.goal:GetText(); tr.goal:SetText(""); tr.goal:SetText(g or "") end
  RG.RefreshTracker()
end
local repaint = CreateFrame("Frame")
repaint:RegisterEvent("PLAYER_ENTERING_WORLD")
repaint:SetScript("OnEvent", function()
  if not (C_Timer and C_Timer.After) then return end
  for _, d in ipairs({ 0.5, 2, 5 }) do C_Timer.After(d, function() pcall(RG.TrackerRepaint) end) end
end)

-- Fade the tracker during fights so it doesn't cover the action.
table.insert(RG.OPTIONS, { key = "trackerLocked", label = "Lock the tracker in place", default = false })
table.insert(RG.OPTIONS, { key = "trackerProfs", label = "Show your professions' next step and missing materials on the tracker", default = true })
table.insert(RG.OPTIONS, { key = "trackerFade", label = "Fade the tracker during combat", default = false })
table.insert(RG.OPTIONS, { key = "trackerCombatFold", label = "Fold the tracker to one line during combat", default = true })
table.insert(RG.OPTIONS, { key = "dungeonQuests", label = "Dungeon quests: include quests you can only finish inside a dungeon in the guide, zone quests and your quest log", default = true })
table.insert(RG.OPTIONS, { key = "smart", label = "Smart zone order: the ordered guide picks the zone that suits your level, where you are and your quest log", default = true })
local fade = CreateFrame("Frame")
fade:RegisterEvent("PLAYER_REGEN_DISABLED"); fade:RegisterEvent("PLAYER_REGEN_ENABLED")
fade:SetScript("OnEvent", function(_, event)
  RG.trackerInCombat = event == "PLAYER_REGEN_DISABLED"
  if not tr then return end
  if event == "PLAYER_REGEN_DISABLED" and RG.Opt("trackerFade") then tr:SetAlpha(0.35) else tr:SetAlpha(1) end
  if RG.trackerDeferred and event == "PLAYER_REGEN_ENABLED" then RG.trackerDeferred = nil; RG.RefreshTracker()
  elseif RG.Opt("trackerCombatFold") and not RG.db.trackerCollapsed then RG.RefreshTracker() end
end)

-- Refresh on the things that change the tracker, at most a few times a second.
local pending
-- (Progress counts keep updating during a fight: the tracker only re-lays-out lines that changed, so that stays cheap.)
local function queue() if RG.CardsOnly and RG.CardsOnly() then return end; if pending then return end; pending = true; C_Timer.After(0.4, function() pending = nil; RG.RefreshTracker() end) end
RG.RefreshTracker = RG.PerfWrap("trackerRefresh", RG.RefreshTracker)
RG.QueueTracker = queue
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "TAXIMAP_OPENED", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "TRAINER_SHOW" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event == "TRAINER_SHOW" and RG.db then RG.db.trainerDue = nil end
  if event == "PLAYER_LOGIN" then
    -- what /wp perf times inside a refresh (wrapped once the other files have loaded)
    for _, n in ipairs({ "Objective", "MyQuests", "CurrentRouteEntry", "SmartRankNow", "NearbyNewQuests", "ClassQuests", "XPRate", "StepIsDone", "StepAuto" }) do
      if type(RG[n]) == "function" then RG[n] = RG.PerfWrap("  in " .. n, RG[n]) end
    end
    C_Timer.After(2, RG.RefreshTracker)
  else
    if RG.Perf and RG.Perf.on then local q = RG.Perf.q; q[event] = (q[event] or 0) + 1 end   -- (/wp perf: who asks for a refresh)
    queue()
  end
end)

-- Questie's own quest tracker shares the top-right corner: when the two overlap, sit just below
-- Questie's (only moving ours; Questie's frame and settings are left alone). Dragging ours keeps it where you put it.
local function overlap(a, b)
  local al, ab, aw, ah = a:GetRect()
  local bl, bb, bw, bh = b:GetRect()
  if not (al and bl) then return false end
  local as, bs = a:GetEffectiveScale(), b:GetEffectiveScale()
  al, ab, aw, ah = al * as, ab * as, aw * as, ah * as
  bl, bb, bw, bh = bl * bs, bb * bs, bw * bs, bh * bs
  return al < bl + bw and bl < al + aw and ab < bb + bh and bb < ab + ah
end
local function avoidQuestie()
  local q = _G.Questie_BaseFrame
  if not (tr and tr:IsShown() and q and q.IsShown and q:IsShown()) then return end
  if RG.TrackerFrozen and RG.TrackerFrozen() then return end
  local ok, hit = pcall(overlap, tr, q)
  if not (ok and hit) then return end
  -- you dragged ours onto Questie's on purpose: leave it there
  if RG.db and RG.db.trackerOverQuestie then return end
  local okB, qb = pcall(q.GetBottom, q)
  local right = tr:GetRight()
  if not (okB and qb and right) then return end
  -- offsets are in our frame's own scale; not if that pushes ours into the bottom third of the screen
  local top = qb * q:GetEffectiveScale() / tr:GetEffectiveScale() - 8
  if top * tr:GetEffectiveScale() < UIParent:GetHeight() * UIParent:GetEffectiveScale() * 0.35 then return end
  tr:ClearAllPoints()
  tr:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
end
local hooked
local function hookDrag()
  if hooked or not tr then return end
  hooked = true
  tr:HookScript("OnDragStop", function()
    local q = _G.Questie_BaseFrame
    local ok, hit = false, false
    if q and q.IsShown and q:IsShown() then ok, hit = pcall(overlap, tr, q) end
    if RG.db then RG.db.trackerOverQuestie = (ok and hit) or nil end
  end)
end
avoidQuestie = RG.PerfWrap("questieAvoid", avoidQuestie)
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(3, function() pcall(hookDrag); pcall(avoidQuestie) end)
end
