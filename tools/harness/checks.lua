-- Hand-written checks (run.lua --checks): small, exact tests of what the add-on does in a given situation, in the
-- simulated world (world.lua, inventory.lua). The checks themselves are in checks/*.lua; each file returns a list of
--   { name = "...", about = "what it checks",
--     race = "Scourge", class = "PALADIN", level = 1, faction = nil,   -- the character (all optional)
--     addons = { "RetGear" },                    -- other add-ons the game says are loaded (optional)
--     saved = { RetGearDB = {...} },             -- saved variables for the first login (optional)
--     run = function(T) ... end,                 -- the first login
--     reload = function(T) ... end,              -- optional: a second login (/reload) with the first one's saved
--                                                --   data and world (quests done, level, bags...)
--     known = "why",                             -- optional: a known bug, not fixed yet. Failing is expected
--   }                                            --   ("known"); passing means it may be fixed ("fixed?").
-- Each check runs in a process of its own (a fresh game), and a reload in a second one.
local C = {}

local function strip(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")) end
C.strip = strip

-- The API a check gets.
function C.makeT(W, Wd, Inv, I, RG)
  local G = W.G
  local T = { W = W, Wd = Wd, Inv = Inv, I = I, RG = RG, results = {} }
  function T.ok(cond, msg) T.results[#T.results + 1] = { ok = cond and true or false, msg = msg }; return cond end
  function T.eq(got, want, msg) return T.ok(got == want, msg .. " (wanted " .. tostring(want) .. ", got " .. tostring(got) .. ")") end
  function T.step(s) W.step(s or 1, 10) end
  function T.quest(id) return RG.QDATA[id] end
  -- go to a map point { uiMapID, x 0-100, y 0-100 }
  function T.go(wp) Wd.setPos(wp[1], wp[2] / 100, wp[3] / 100); T.step(1) end
  function T.accept(id)
    local d = RG.QDATA[id]
    if d and d.s then T.go(d.s) end
    local ok, why = Wd.accept(id)
    T.step(1)
    return ok, why
  end
  function T.work(id)
    for _ = 1, 10 do
      local sp = Wd.objectiveSpot(id)
      if not sp then break end
      T.go(sp); Wd.work(id)
    end
    if Wd.objectiveSpot(id) == nil then Wd.work(id) end
    T.step(1)
  end
  function T.handIn(id)
    local d = RG.QDATA[id]
    if d and d.e then T.go(d.e) end
    local ok, why = Wd.handIn(id)
    T.step(1)
    return ok, why
  end
  function T.complete(id) T.accept(id); T.work(id); return T.handIn(id) end
  function T.done(id) return Wd.state.done[id] == true end
  function T.setLevel(n) while W.me.level < n do Wd.giveXP(Wd.XPMAX[W.me.level] - Wd.state.xp, "kill") end T.step(1) end
  -- what the tracker shows (its text, colour codes stripped), and the first line matching a pattern
  function T.tracker()
    local out = {}
    for _, t in ipairs(W.visibleTexts(G.WaypathTracker)) do out[#out + 1] = strip(t) end
    return out
  end
  function T.trackerFind(pat)
    for _, t in ipairs(T.tracker()) do if t:find(pat) then return t end end
  end
  -- where the arrow points (the map pin): { uiMapID, x 0-100, y 0-100 }, or nil
  function T.arrow()
    local p = Wd.state.waypoint
    if p and p.position then return { p.uiMapID, p.position.x * 100, p.position.y * 100 } end
  end
  function T.near(a, b, tol)
    tol = tol or 3
    return a and b and a[1] == b[1] and math.abs(a[2] - b[2]) <= tol and math.abs(a[3] - b[3]) <= tol or false
  end
  function T.slash(cmd) W.slash(cmd); T.step(1) end
  function T.give(id, n) Inv.add(id, n or 1); T.step(0.5) end
  function T.equip(id)
    for _, x in ipairs(Inv.bagItems()) do if x.id == id then local ok = Inv.equipFrom(x.bag, x.slot); T.step(0.5); return ok end end
    return false
  end
  function T.link(id) local it = I.get(id); return it and it.link end
  function T.db() return W.getSaved("WaypathDB") end
  -- a route entry by zone (and its first level, when a zone has two)
  function T.entry(zone, from)
    for _, r in ipairs(RG.ROUTE or {}) do if r.zone == zone and (not from or r.from == from) then return r end end
  end
  return T
end

-- ---------------------------------------------------------------------------
-- The runner: every check in checks/*.lua, each in a process of its own
-- ---------------------------------------------------------------------------
local function shell(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

function C.list(here)
  local out = {}
  local p = io.popen("ls " .. shell(here .. "/checks") .. "/*.lua 2>/dev/null")
  for f in p:read("*a"):gmatch("[^\n]+") do
    local ok, list = pcall(dofile, f)
    if ok and type(list) == "table" then
      for _, c in ipairs(list) do out[#out + 1] = { file = f, check = c } end
    else
      out[#out + 1] = { file = f, broken = tostring(list) }
    end
  end
  p:close()
  return out
end

local function runOne(here, file, name, phase, extra)
  local cmd = "lua5.1 " .. shell(here .. "/run.lua") .. " --check-one " .. shell(file) .. " --name " .. shell(name) .. " --phase " .. phase .. (extra or "") .. " 2>&1"
  local p = io.popen(cmd)
  local text = p:read("*a")
  p:close()
  local r = { asserts = {}, lua = 0, taint = 0, firstError = nil, text = text }
  for line in text:gmatch("[^\n]+") do
    local kind, a, b = line:match("^(CHECK[%-%w]*)\t([^\t]*)\t?(.*)$")
    if kind == "CHECK" then r.asserts[#r.asserts + 1] = { ok = a == "pass", msg = b }
    elseif kind == "CHECK-LUA" then r.lua = tonumber(a) or 0; r.firstError = b ~= "" and b or nil
    elseif kind == "CHECK-TAINT" then r.taint = tonumber(a) or 0
    elseif kind == "CHECK-DONE" then r.finished = true end
  end
  return r
end

function C.runAll(here, filter, verbose)
  local list = C.list(here)
  local tmp = os.tmpname()
  local counts = { pass = 0, fail = 0, known = 0, fixed = 0 }
  local out = io.stdout
  for _, e in ipairs(list) do
    if e.broken then
      out:write("BROKEN  " .. e.file .. ": " .. e.broken .. "\n"); counts.fail = counts.fail + 1
    elseif not filter or e.check.name:find(filter, 1, true) then
      local c = e.check
      local sv, world = tmp .. "-sv.lua", tmp .. "-world.lua"
      local results = { runOne(here, e.file, c.name, "run", c.reload and (" --save-sv " .. shell(sv) .. " --save-world " .. shell(world)) or "") }
      if c.reload then results[2] = runOne(here, e.file, c.name, "reload", " --sv " .. shell(sv) .. " --world " .. shell(world)) end
      os.remove(sv); os.remove(world)
      local failed, msgs, total = false, {}, 0
      for i, r in ipairs(results) do
        local phase = i == 1 and "" or "after /reload: "
        if not r.finished then failed = true; msgs[#msgs + 1] = phase .. "the check didn't finish:\n" .. r.text:sub(-1500) end
        for _, a in ipairs(r.asserts) do
          total = total + 1
          if not a.ok then failed = true; msgs[#msgs + 1] = phase .. a.msg end
        end
        if r.lua > 0 then failed = true; msgs[#msgs + 1] = phase .. r.lua .. " Lua error(s), first: " .. tostring(r.firstError) end
        if r.taint > 0 then failed = true; msgs[#msgs + 1] = phase .. r.taint .. " taint write(s)" end
      end
      local verdict
      if c.known then verdict = failed and "KNOWN" or "FIXED?" else verdict = failed and "FAIL" or "PASS" end
      counts[({ PASS = "pass", FAIL = "fail", KNOWN = "known", ["FIXED?"] = "fixed" })[verdict]] = counts[({ PASS = "pass", FAIL = "fail", KNOWN = "known", ["FIXED?"] = "fixed" })[verdict]] + 1
      out:write(string.format("%-7s %s: %s (%d checks)\n", verdict, c.name, c.about or "", total))
      if verdict == "KNOWN" then out:write("        known bug: " .. c.known .. "\n") end
      if verdict == "FIXED?" then out:write("        this known bug now passes: if it's fixed, remove `known` from the check\n") end
      if failed and (verdict == "FAIL" or verbose) then for _, m in ipairs(msgs) do out:write("        - " .. m:gsub("\n", "\n          ") .. "\n") end end
    end
  end
  out:write(string.format("\n%d passed, %d failed, %d known bugs, %d known bugs passing (fixed?)\n", counts.pass, counts.fail, counts.known, counts.fixed))
  return counts.fail == 0
end

return C
