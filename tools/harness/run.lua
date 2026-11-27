-- Offline harness: loads every file in Waypath.toc against a fake WoW client (wow.lua), logs a character in, then
-- drives everything it can reach (drive.lua): every event, every /wp command, every button and handler on screen,
-- the hooks on the game's windows, and per-frame updates. It reports every Lua error and every write to something
-- the game owns (taint). Run from the repo root:
--
--   lua5.1 tools/harness/run.lua [--class PALADIN] [--race Scourge] [--faction Horde] [--level 1]
--                                [--login-only] [--cmd "next,plan"] [--seconds 15] [--sv FILE] [--save-sv FILE]
--                                [--chat] [--verbose]
--
-- Exits 1 when there is a Lua error or a taint write, 0 otherwise. See README.md for what a clean run does and
-- doesn't prove.
local HERE = arg[0]:match("^(.*)[/\\]") or "."
package.path = HERE .. "/?.lua;" .. package.path
local W = require("wow")
local D = require("drive")
local Wd = require("world")
local P = require("play")
local I = require("items")
local Inv = require("inventory")
local C = require("checks")

local opts = { toc = "Waypath.toc", seconds = 15 }
local FLAGS = { chat = true, verbose = true, login_only = true, play = true, checks = true }
-- --checks [--only NAME]: every hand-written check in checks/*.lua, each in a fresh game (checks.lua)
--   (--check-one FILE --name NAME --phase run|reload [--world FILE] [--save-world FILE]: one of them; the runner uses it)
-- --play: instead of the drive, a bot plays the route in a simulated world (world.lua, play.lua)
--   [--until-level 20] [--max-actions 4000]
-- --coverage FILE: note every line of the add-on that runs, and write which lines never did (slower: a line hook)
local i = 1
while arg[i] do
  local a = arg[i]
  local flag = a:match("^%-%-(.+)$")
  flag = flag and flag:gsub("%-", "_")
  if flag and FLAGS[flag] then opts[flag] = true; i = i + 1
  elseif flag and arg[i + 1] then opts[flag] = arg[i + 1]; i = i + 2
  else io.stderr:write("unknown argument " .. a .. "\n(see the top of tools/harness/run.lua)\n") os.exit(2) end
end

local ROOT = "."
local function readFile(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end
local toc = readFile(ROOT .. "/" .. opts.toc)
if not toc then io.stderr:write("can't find " .. opts.toc .. ": run this from the repo root\n") os.exit(2) end
local version = (readFile(ROOT .. "/VERSION") or "?"):gsub("%s+", "")

-- the check runner: each check in a process of its own
if opts.checks then os.exit(C.runAll(HERE, opts.only, opts.verbose) and 0 or 1) end
-- one check: it says which character it wants
local check
if opts.check_one then
  local list = dofile(opts.check_one)
  for _, c in ipairs(list) do if c.name == opts.name then check = c end end
  if not check then io.stderr:write("no check named " .. tostring(opts.name) .. " in " .. opts.check_one .. "\n") os.exit(2) end
  opts.play = true
  opts.race, opts.class, opts.faction, opts.level = opts.race or check.race, opts.class or check.class, opts.faction or check.faction, opts.level or check.level
  for _, a in ipairs(check.addons or {}) do W.otherAddons[a] = true end
end

local ok, err = pcall(W.setup, { class = opts.class, race = opts.race, faction = opts.faction, level = opts.level,
  map = opts.map, money = opts.money, version = version })
if not ok then io.stderr:write(tostring(err) .. "\n") os.exit(2) end

-- saved variables from a file (WTF/Account/<name>/SavedVariables/Waypath.lua, or one written by --save-sv)
local saved
if opts.sv then
  local chunk, e = loadfile(opts.sv)
  if not chunk then io.stderr:write("can't read " .. opts.sv .. ": " .. tostring(e) .. "\n") os.exit(2) end
  local env = {}
  setfenv(chunk, env)
  chunk()
  saved = env.WaypathDB
  if not saved then io.stderr:write(opts.sv .. " has no WaypathDB in it\n") os.exit(2) end
end

-- the files, in the TOC's order
local files, luaFiles = {}, {}
for line in toc:gmatch("[^\r\n]+") do
  if not line:find("^%s*#") and line:find("%S") then files[#files + 1] = (line:gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", "")) end
end
for _, f in ipairs(files) do if f:find("%.lua$") then luaFiles[#luaFiles + 1] = f end end

local hits = {}
if opts.coverage then
  local getinfo = debug.getinfo
  debug.sethook(function(_, line)
    local src = getinfo(2, "S").source
    local h = hits[src]
    if not h then h = {}; hits[src] = h end
    h[line] = true
  end, "l")
end

local withItems = false
if opts.play then
  Wd.install(W)
  -- where quests that start from an object or item begin (sh tools/harness/starters.sh builds it)
  -- the game's maps: names, parents, world positions (sh tools/harness/maps.sh builds it)
  local mf = loadfile(HERE .. "/.cache/maps.lua")
  if mf then Wd.mapsData = mf() else io.stderr:write("(no maps cache: zones are 3500 yards and unconnected; sh tools/harness/maps.sh builds it)\n") end
  local sf = loadfile(HERE .. "/.cache/starters.lua")
  if sf then Wd.starters = sf() or {} else io.stderr:write("(no starters cache: quests that start from an item or object are found anywhere; sh tools/harness/starters.sh builds it)\n") end
  -- items: LibItemDB's tables from the data/itemdb branch (cached in tools/harness/.cache/itemdb)
  local cache = HERE .. "/.cache/itemdb"
  local ok, why = I.ensure(cache)
  if ok then ok, why = I.load(cache, W.G) end
  if ok then Inv.install(W, Wd, I); withItems = true
  else io.stderr:write("(no items: " .. tostring(why) .. ")\n") end
end
W.seal()
local RG = {}
local loaded = 0
W.phase = "loading"
for _, f in ipairs(luaFiles) do
  if W.loadFile(ROOT, f, "Waypath", RG) then loaded = loaded + 1 end
end
if opts.play then Wd.attach(RG); if withItems then Inv.attach(RG) end end
-- a second login (a check's /reload): the world as the first one left it
if opts.world then
  local chunk = loadfile(opts.world)
  local env = {}
  if chunk then setfenv(chunk, env); chunk() end
  Wd.restore(env.world)
  if withItems then Inv.restore(env.inv) end
end

-- the login: saved variables arrive, then the game's login events in the order it sends them
W.phase = "login"
W.setSaved("WaypathDB", saved)
if check and opts.phase ~= "reload" then for k, v in pairs(check.saved or {}) do W.setSaved(k, v) end end
local errorsBefore = {}   -- what /wp errors already had (from --sv), so only new ones are reported
for _, e in ipairs(saved and saved.errors or {}) do errorsBefore[tostring(e.msg)] = e.count or 1 end
local function fire(ev, ...) W.context = ev; W.fire(ev, ...) end
fire("ADDON_LOADED", "Waypath")
fire("VARIABLES_LOADED")
fire("SPELLS_CHANGED")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", not opts.sv, opts.sv ~= nil)
fire("QUEST_LOG_UPDATE")
fire("BAG_UPDATE_DELAYED")
fire("ZONE_CHANGED_NEW_AREA")
fire("PLAYER_MONEY")
W.context = "the first seconds after login"
W.advance(tonumber(opts.seconds) or 15)

-- --dump-route FILE: the route this character gets, as JSON (tools/audit/compare_guides.py reads it), then stop
if opts.dump_route then
  local js = W.json
  local entries = {}
  for _, r in ipairs(RG.ROUTE or {}) do
    local key = r.zone .. "|" .. r.from
    local quests, steps = {}, RG.STEPS and RG.STEPS[key] or {}
    for i = 1, #steps do for _, id in ipairs(RG.STEP_QUESTS and RG.STEP_QUESTS[key] and RG.STEP_QUESTS[key][i] or {}) do
      local d = RG.QDATA and RG.QDATA[id]
      if d and (not RG.QuestForMe or RG.QuestForMe(d)) then quests[#quests + 1] = id end
    end end
    entries[#entries + 1] = { zone = r.zone, from = r.from, to = r.to, kind = r.kind or "zone", steps = #steps, quests = quests }
  end
  local names = {}
  for id, d in pairs(RG.QDATA or {}) do if d.n then names[tostring(id)] = { d.n, d.l or d.r or 0, d.cq and 1 or 0, d.r or 1 } end end
  local fh = assert(io.open(opts.dump_route, "wb"))
  fh:write(js({ race = W.me.race, faction = W.me.faction, class = W.me.class, route = entries, quests = names }))
  fh:close()
  io.stdout:write("route written to " .. opts.dump_route .. " (" .. #entries .. " entries)\n")
  os.exit(0)
end

-- after login: drive everything (drive.lua)
local FPS = 10
local function step(s) W.step(s, FPS) end
local stats = { commands = 0, handlers = 0 }
local played
if check then
  -- one check: run it, print its results for the runner (CHECK lines), keep what a /reload needs
  local T = C.makeT(W, Wd, withItems and Inv or nil, I, RG)
  W.phase = "check " .. check.name
  local fn = opts.phase == "reload" and check.reload or check.run
  W.call("the check " .. check.name, fn, T)
  if opts.save_world then
    local fh = assert(io.open(opts.save_world, "wb"))
    fh:write("world = " .. W.serialize(Wd.snapshot()) .. "\ninv = " .. W.serialize(withItems and Inv.snapshot() or {}) .. "\n")
    fh:close()
  end
  if opts.save_sv then
    local fh = assert(io.open(opts.save_sv, "wb"))
    fh:write("WaypathDB = " .. W.serialize(W.getSaved("WaypathDB")) .. "\n")
    fh:close()
  end
  for _, r in ipairs(T.results) do io.stdout:write(string.format("CHECK\t%s\t%s\n", r.ok and "pass" or "fail", (tostring(r.msg):gsub("[\t\n]", " ")))) end
  local first = W.errors[1]
  io.stdout:write(string.format("CHECK-LUA\t%d\t%s\n", #W.errors, first and (first.msg .. " at " .. first.where .. ", during " .. tostring(first.context)):gsub("[\t\n]", " ") or ""))
  io.stdout:write(string.format("CHECK-TAINT\t%d\t\n", #W.taint))
  io.stdout:write("CHECK-DONE\t\t\n")
  os.exit(0)
elseif opts.play then
  played = P.run(W, Wd, RG, opts, withItems and Inv or nil, I)
  W.phase = "logout"
  D.logout(W)
  -- --play-dump FILE: the bot's zone path and class quests, as JSON (tools/audit/compare_guides.py reads it)
  if opts.play_dump then
    local done = {}
    for id in pairs(Wd.state.done) do done[#done + 1] = id end
    table.sort(done)
    local fh = assert(io.open(opts.play_dump, "wb"))
    fh:write(W.json({ race = W.me.race, faction = W.me.faction, class = W.me.class, path = played.path,
      classDone = played.classQuests, classSeen = played.classSeen, done = done }))
    fh:close()
  end
elseif not opts.login_only then
  local cmds, extra = D.commands(W, luaFiles)
  if opts.cmd then
    cmds, extra = {}, {}
    for c in opts.cmd:gmatch("[^,]+") do cmds[#cmds + 1] = (c:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^/wp%s*", "")) end
  else
    W.phase = "events"
    D.fireAll(W, step)
  end
  W.phase = "the screen after login"
  stats.handlers = stats.handlers + D.crawl(W, step, 400)
  local function run(text)
    W.phase = text
    W.context = text
    W.slash(text)
    stats.commands = stats.commands + 1
    step(1)
    stats.handlers = stats.handlers + D.crawl(W, step, 400)
  end
  for _, c in ipairs(cmds) do run(c == "" and "/wp" or ("/wp " .. c)) end
  for _, s in ipairs(extra) do run(s); run(s .. " help") end
  if not opts.cmd then
    W.phase = "the game's windows"
    D.gameHooks(W, step)
    W.phase = "events, again"
    D.fireAll(W, step)
  end
  W.phase = "per-frame updates"
  W.context = "per-frame updates"
  step(10)
  W.phase = "logout"
  D.logout(W)
end

-- ---------------------------------------------------------------------------
-- Report
-- ---------------------------------------------------------------------------
local coverageLine
if opts.coverage then
  debug.sethook()
  -- the lines that hold code, from luac's listing: "1 [12] GETGLOBAL ..."
  local rows, allRun, allCode = {}, 0, 0
  for _, f in ipairs(luaFiles) do
    local p = io.popen("luac5.1 -l -p '" .. f:gsub("'", "") .. "' 2>/dev/null")
    local code = {}
    if p then for n in p:read("*a"):gmatch("\t%[(%d+)%]\t") do code[tonumber(n)] = true end p:close() end
    local h = hits["@" .. W.PREFIX .. f] or {}
    local nCode, nRun, missed = 0, 0, {}
    for n in pairs(code) do nCode = nCode + 1; if h[n] then nRun = nRun + 1 else missed[#missed + 1] = n end end
    table.sort(missed)
    allRun, allCode = allRun + nRun, allCode + nCode
    rows[#rows + 1] = { f = f, run = nRun, code = nCode, missed = missed }
  end
  table.sort(rows, function(a, b) return (a.code - a.run) > (b.code - b.run) end)
  local fh = assert(io.open(opts.coverage, "wb"))
  fh:write(string.format("Lines of code run: %d of %d (%.0f%%)\n\nfile, lines run / lines of code, lines never run\n", allRun, allCode, allCode > 0 and allRun / allCode * 100 or 0))
  for _, r in ipairs(rows) do
    -- the lines never run, as ranges: 12-18, 40, ...
    local ranges, i = {}, 1
    while r.missed[i] do
      local a, b = r.missed[i], r.missed[i]
      while r.missed[i + 1] and r.missed[i + 1] <= b + 3 do i = i + 1; b = r.missed[i] end
      ranges[#ranges + 1] = a == b and tostring(a) or (a .. "-" .. b)
      i = i + 1
    end
    fh:write(string.format("%-34s %5d / %-5d %3.0f%%   %s\n", r.f, r.run, r.code, r.code > 0 and r.run / r.code * 100 or 100, table.concat(ranges, ", ")))
  end
  fh:close()
  coverageLine = string.format("Coverage: %d of %d lines of code ran (%.0f%%); per file in %s\n", allRun, allCode, allCode > 0 and allRun / allCode * 100 or 0, opts.coverage)
end

local me = W.me
local out = io.stdout
out:write(string.format("Waypath+ %s harness: %s %s (%s), level %d, %s. %d/%d files ran without an error.\n",
  version, W.RACES[me.race][1], W.CLASSES[me.class][1], me.race, me.level, me.faction, loaded, #luaFiles))
local playProblems = 0
if played then
  local st = Wd.state.stats
  local nSteps = 0; for _ in pairs(played.steps) do nSteps = nSteps + 1 end
  out:write(string.format("Played from level %d to %d in %d actions (%.1f hours of game time), through %d route steps.\n",
    played.startLevel, played.endLevel, played.actions, st.seconds / 3600, nSteps))
  out:write(string.format("Quests: %d accepted (%d by the add-on's auto-accept), %d handed in (%d by its auto hand-in). %d kills.\n",
    st.accepted, st.autoAccepted, st.handedIn, st.autoHandedIn, st.kills))
  out:write(string.format("XP: %d from quests, %d from kills (made-up numbers: see world.lua). Steps ticked by hand: %d hand-written, %d to get past a problem.\n",
    st.questXP, st.killXP, played.ticked, played.tickedHand))
  out:write(string.format("Quests found on the way (they start from an item or object): %d.\n", played.found or 0))
  do
    local late, n = 0, #played.classQuests
    for _, c in ipairs(played.classQuests) do if c.done and c.req and c.done - c.req >= 3 then late = late + 1 end end
    local zones, seen, back = #played.path, {}, 0
    for _, p in ipairs(played.path) do if seen[p.zone] then back = back + 1 end seen[p.zone] = true end
    out:write(string.format("Class quests done from the tracker: %d (%d of them 3+ levels after they opened). Zone path: %d stretches, %d of them back in a zone it had left.\n",
      n, late, zones, back))
  end
  if withItems then
    local is = Inv.stats
    out:write(string.format("Items: %d quest rewards (%d had a choice: %d picked by the add-on, %d by the bot), %d quest item stacks. %d swaps to upgrades, %d sold (%d by the add-on)%s.\n",
      is.rewards, is.pickedByAddon + is.pickedByBot, is.pickedByAddon, is.pickedByBot, is.questItems, is.equipped, is.sold, is.soldByAddon,
      is.bagFull > 0 and (", bags full " .. is.bagFull .. " times") or ""))
    if #played.gear.score > 0 then
      local t = {}
      for _, g in ipairs(played.gear.score) do t[#t + 1] = string.format("%d: %.0f (%d slots)", g.level, g.score, g.slots) end
      out:write("Gear score by the add-on's own scoring, at level " .. table.concat(t, ", ") .. ".\n")
    end
  end
  if #played.ground > 0 then
    out:write(string.format("\nLevels the bot had to grind (%d): the route had nothing to do\n", #played.ground))
    for _, g in ipairs(played.ground) do out:write(string.format("  at level %d: %s\n", g.level, g.why)) end
  end
  local KIND = {
    ["grey-prereq"] = "a quest needs one the guide skipped as grey",
    order = "a quest comes before the one it needs",
    ["not-in-route"] = "a quest needs one that isn't in the route",
    earlier = "a quest needs one from a step that counted as done without it",
    ["hidden-prereq"] = "a quest needs one the guide hides as never available",
    ["skipped-step"] = "the guide moved past an open step whose quest a later one needs",
    other = "blocked for another reason",
    empty = "a step that isn't done has nothing left to do",
    stuck = "the guide kept pointing at something that didn't change",
    pickup = "the guide said pick up a quest the game wouldn't give",
    turnin = "the guide said hand in a quest that couldn't be",
    waypoint = "a waypoint that isn't where the objective is",
    ["no-waypoint"] = "no waypoint for a quest pick-up",
    ["flip-flop"] = "gear scoring that contradicts itself (an item and the one it replaced both called upgrades)",
    downgrade = "an \"upgrade\" that made the whole outfit worse",
    starter = "a step waits on a quest that starts from an item or object the bot couldn't take",
  }
  if #played.problems > 0 then
    local byKind, kinds = {}, {}
    for _, p in ipairs(played.problems) do
      if not byKind[p.kind] then byKind[p.kind] = {}; kinds[#kinds + 1] = p.kind end
      table.insert(byKind[p.kind], p)
    end
    table.sort(kinds, function(a, b) return #byKind[a] > #byKind[b] end)
    out:write(string.format("\nGuide problems (%d):", #played.problems))
    for _, k in ipairs(kinds) do out:write(string.format("  %d %s;", #byKind[k], k)) end
    out:write("\n")
    for _, k in ipairs(kinds) do
      out:write(string.format("\n  %s (%d):\n", KIND[k] or k, #byKind[k]))
      for _, p in ipairs(byKind[k]) do
        out:write(string.format("    %s\n        at level %d, %s%s\n", p.text, p.level, tostring(p.where), p.count > 1 and (" (" .. p.count .. " times)") or ""))
      end
    end
  end
  -- trips back to a quest giver for a quest it could have taken on the visit before (not counted as a failure yet)
  local revisits, info = {}, {}
  for _, p in ipairs(played.info) do if p.kind == "revisit" then revisits[#revisits + 1] = p else info[#info + 1] = p end end
  if #revisits > 0 then
    out:write(string.format("\nTrips back (%d, not counted): the bot came back to a quest giver for a quest it could have taken on its visit before:\n", #revisits))
    for _, p in ipairs(revisits) do out:write(string.format("    %s\n        at level %d, %s\n", p.text, p.level, tostring(p.where))) end
  end
  if #info > 0 then
    out:write(string.format("\nNot counted (%d): quests blocked only because the bot skipped what they need, or because what they need starts from an item or object it couldn't take yet%s\n",
      #info, opts.verbose and ":" or "; --verbose lists them"))
    if opts.verbose then
      for _, p in ipairs(info) do out:write(string.format("    %s\n        at level %d, %s\n", p.text, p.level, tostring(p.where))) end
    end
  end
  if opts.verbose and withItems then
    out:write("\nEquipped at the end:")
    for slot = 1, 19 do
      local id = Inv.equip[slot]
      if id then
        local it = I.get(id)
        local d = RG.Compare and RG.Compare(it.link, slot)
        out:write(string.format("  %d %s;", slot, it.name))
      end
    end
    out:write("\nIn the bags:")
    for _, x in ipairs(Inv.bagItems()) do
      local it = I.get(x.id)
      if it and Inv.EQUIP[it.loc] then
        local d = RG.Compare and RG.Compare(it.link)
        out:write(string.format("  %s (%s%s);", it.name, it.loc:gsub("INVTYPE_", ""), d and string.format(", %+.0f", d) or ", can't use"))
      end
    end
    out:write("\n")
  end
  if opts.verbose then
    out:write("\nWhat the bot did:\n")
    for _, l in ipairs(played.log) do out:write("  " .. l .. "\n") end
  end
  playProblems = #played.problems
elseif opts.login_only then
  out:write(string.format("Login only: %d frames made, %d timer callbacks run, %d chat lines.\n", W.counts.frames, W.counts.timers, #W.chat))
else
  out:write(string.format("%d slash commands, %d handlers exercised, %d events fired, %d OnUpdate calls, %d timer callbacks, %d frames made, %d chat lines.\n",
    stats.commands, stats.handlers, W.counts.events, W.counts.updates, W.counts.timers, W.counts.frames, #W.chat))
end
if coverageLine then out:write(coverageLine) end

if opts.chat and #W.chat > 0 then
  out:write("\nChat:\n")
  for _, l in ipairs(W.chat) do out:write("  " .. l:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "\n") end
end

local function during(e)
  local s = e.context or "?"
  if e.phase and e.phase ~= e.context and not s:find(e.phase, 1, true) then s = s .. " (" .. e.phase .. ")" end
  return s
end

if #W.errors > 0 then
  out:write(string.format("\nLua errors (%d):\n", #W.errors))
  for _, e in ipairs(W.errors) do
    out:write(string.format("  %s\n      at %s, during %s%s\n", e.msg, e.where, during(e), e.count > 1 and (" (" .. e.count .. " times)") or ""))
    if opts.verbose and e.trace ~= "" then
      for l in e.trace:gmatch("[^\n]+") do
        l = l:gsub("^%s+", "")
        local src = l:match("^([^:]+%.lua):")
        if src and W.isAddon("@" .. src) then out:write("        " .. l .. "\n") end
      end
    end
  end
end

-- errors the add-on caught itself (pcall, its error handler) and logged for /wp errors
-- (an error listed above also reaches the add-on's catcher, as in the game: it isn't listed twice)
local logged, shown = {}, {}
for _, e in ipairs(W.errors) do shown[e.raw] = true end
local db = W.getSaved("WaypathDB")
for _, e in ipairs(type(db) == "table" and type(db.errors) == "table" and db.errors or {}) do
  local m = tostring(e.msg)
  if (e.count or 1) > (errorsBefore[m] or 0) and not shown[m] then logged[#logged + 1] = e end
end
if #logged > 0 then
  out:write(string.format("\nErrors the add-on caught and logged for /wp errors (%d):\n", #logged))
  for _, e in ipairs(logged) do
    out:write("  " .. W.short(e.msg) .. "\n")
    if opts.verbose and e.stack and e.stack ~= "" then
      for l in W.short(e.stack):gmatch("[^\n]+") do out:write("        " .. l:gsub("^%s+", "") .. "\n") end
    end
  end
end

if #W.taint > 0 then
  out:write(string.format("\nTaint risks (%d): writes to things the game owns\n", #W.taint))
  for _, t in ipairs(W.taint) do
    local what = t.kind == "global" and ("sets the game's global " .. t.name)
      or t.kind == "field" and ("writes " .. t.name)
      or t.name
    out:write(string.format("  %s  %s\n", t.where, what))
  end
end

if #W.swallowed > 0 then
  out:write(string.format("\nErrors swallowed by pcall (%d; not a failure: some are deliberate, some hide a broken feature):\n", #W.swallowed))
  for _, e in ipairs(W.swallowed) do
    out:write(string.format("  %s\n      caught at %s, during %s%s\n", e.msg, e.where, during(e), e.count > 1 and (" (" .. e.count .. " times)") or ""))
  end
end

local unknown = {}
for k, loc in pairs(W.unknown) do unknown[#unknown + 1] = { k, loc } end
table.sort(unknown, function(a, b) return a[1] < b[1] end)
local methods = {}
for k in pairs(W.methods) do methods[#methods + 1] = k end
table.sort(methods)
if opts.verbose then
  if #unknown > 0 then
    out:write(string.format("\nGlobals the harness doesn't have (read as nil; add them to wow.lua if the game has them):\n"))
    for _, u in ipairs(unknown) do out:write(string.format("  %-40s first at %s\n", u[1], u[2])) end
  end
  if #methods > 0 then
    out:write("\nWidget methods and templates the harness answers generically (0, false or nil):\n  " .. table.concat(methods, " ") .. "\n")
  end
elseif #unknown > 0 or #methods > 0 then
  out:write(string.format("\n%d globals and %d widget methods aren't modelled by the harness (--verbose lists them).\n", #unknown, #methods))
end

if opts.save_sv then
  -- write WaypathDB back out, so a second run with --sv is the next login (a /reload, or the next session)
  local seen = {}
  local function ser(v, ind)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" or t == "nil" then return tostring(v) end
    if t ~= "table" or seen[v] then return "nil" end
    seen[v] = true
    local keys = {}
    for k in pairs(v) do if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) if type(a) == type(b) then return a < b end return type(a) == "number" end)
    local parts = {}
    for _, k in ipairs(keys) do
      local kv = type(k) == "number" and ("[" .. k .. "]") or ("[" .. string.format("%q", k) .. "]")
      local val = v[k]
      if type(val) ~= "function" and type(val) ~= "userdata" and type(val) ~= "thread" then parts[#parts + 1] = ind .. "  " .. kv .. " = " .. ser(val, ind .. "  ") .. ",\n" end
    end
    seen[v] = nil
    return "{\n" .. table.concat(parts) .. ind .. "}"
  end
  local fh = assert(io.open(opts.save_sv, "wb"))
  fh:write("WaypathDB = " .. ser(W.getSaved("WaypathDB"), "") .. "\n")
  fh:close()
  out:write("\nSaved WaypathDB to " .. opts.save_sv .. "\n")
end

local bad = #W.errors + #logged + #W.taint + playProblems
out:write(bad == 0 and ("\nPASS: no Lua errors, no taint writes" .. (played and ", no guide problems" or "") .. ".\n")
  or string.format("\nFAIL: %d Lua error(s), %d caught by the add-on, %d taint write(s)%s.\n", #W.errors, #logged, #W.taint,
    played and (", " .. playProblems .. " guide problem(s)") or ""))
os.exit(bad == 0 and 0 or 1)
