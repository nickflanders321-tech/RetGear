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

local opts = { toc = "Waypath.toc", seconds = 15 }
local FLAGS = { chat = true, verbose = true, login_only = true }
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

W.seal()
local RG = {}
local loaded = 0
W.phase = "loading"
for _, f in ipairs(luaFiles) do
  if W.loadFile(ROOT, f, "Waypath", RG) then loaded = loaded + 1 end
end

-- the login: saved variables arrive, then the game's login events in the order it sends them
W.phase = "login"
W.setSaved("WaypathDB", saved)
local errorsBefore = {}   -- what /wp errors already had (from --sv), so only new ones are reported
for _, e in ipairs(saved and saved.errors or {}) do errorsBefore[tostring(e.msg)] = e.count or 1 end
local function fire(ev, ...) W.context = ev; W.fire(ev, ...) end
fire("ADDON_LOADED", "Waypath")
fire("VARIABLES_LOADED")
fire("SPELLS_CHANGED")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", not opts.sv, false)
fire("QUEST_LOG_UPDATE")
fire("BAG_UPDATE_DELAYED")
fire("ZONE_CHANGED_NEW_AREA")
fire("PLAYER_MONEY")
W.context = "the first seconds after login"
W.advance(tonumber(opts.seconds) or 15)

-- after login: drive everything (drive.lua)
local FPS = 10
local function step(s) W.step(s, FPS) end
local stats = { commands = 0, handlers = 0 }
if not opts.login_only then
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
if opts.login_only then
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

local bad = #W.errors + #logged + #W.taint
out:write(bad == 0 and "\nPASS: no Lua errors, no taint writes.\n"
  or string.format("\nFAIL: %d Lua error(s), %d caught by the add-on, %d taint write(s).\n", #W.errors, #logged, #W.taint))
os.exit(bad == 0 and 0 or 1)
