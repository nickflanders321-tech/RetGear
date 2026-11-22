-- Waypath+ "Cards only" mode: one switch that turns off everything except the card game (cards, packs, Arena, duels, ranks).
-- The guide, tracker, arrow, quest and vendor helpers and all their pop-ups stop. How it works: while the guide's files load
-- (between GateOn.lua and GateOff.lua in the .toc) every event handler, update loop, timer and game hook they register is wrapped
-- so that it does nothing while db.cardsOnly is set. The card files load outside that window, so they are untouched, and the
-- switch needs no per-feature checks (a new feature is covered the moment it is added between the two markers).
local _, RG = ...
RG = RG or {}
-- (RG.CardsOnly() is defined in Core.lua, which every file can rely on)

-- IMPORTANT: nothing here replaces or writes to anything that belongs to the game (CreateFrame, C_Timer, hooksecurefunc,
-- GameTooltip...). Writing to those, even putting the same value back, "taints" them for the whole session, and the game
-- then blocks its own actions and blames Waypath+ ("blocked from an action only available to the Blizzard UI"). Up to
-- 1.9.1 this file did exactly that; it now only reads the list of frames.
--
-- How the switch works: the frames the guide's files create while they load (between GateOn.lua and GateOff.lua in the .toc)
-- are noted by walking the game's frame list before and after. With Cards only on, at login those frames are silenced
-- (no events, no update loop, hidden). The few things that don't live on a frame (game hooks and timers) check
-- RG.CardsOnly() themselves.
local made = {}          -- the guide's frames
RG.featureFrames = made
local lastBefore         -- the last frame that existed when a gated block of files began
local function lastFrame()
  if not EnumerateFrames then return nil end
  local f, last = EnumerateFrames(), nil
  while f do last = f; f = EnumerateFrames(f) end
  return last
end
function RG.GateOn()
  lastBefore = lastFrame() or false
end
function RG.GateOff()
  if lastBefore == nil or not EnumerateFrames then return end
  local f = lastBefore and EnumerateFrames(lastBefore) or EnumerateFrames()
  while f do made[#made + 1] = f; f = EnumerateFrames(f) end
  lastBefore = nil
end
local function silence()
  for _, f in ipairs(made) do
    pcall(function()
      if f.UnregisterAllEvents then f:UnregisterAllEvents() end
      if f.GetScript and f.SetScript and f:GetScript("OnUpdate") then f:SetScript("OnUpdate", nil) end
      if f.IsShown and f:IsShown() and not (f.IsProtected and f:IsProtected()) then f:Hide() end
    end)
  end
end
RG.SilenceGuide = silence
if CreateFrame then
  local lf = CreateFrame("Frame")
  lf:RegisterEvent("ADDON_LOADED"); lf:RegisterEvent("PLAYER_LOGIN")
  lf:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Waypath" then return end
    if RG.CardsOnly and RG.CardsOnly() then silence() end
  end)
end
-- /wp perf: memory now, and the add-on's CPU time when the game's script profiler is on
local perf = RG.Perf

-- Turn the mode on or off for this character. Everything the guide put on screen goes away at once.
function RG.SetCardsOnly(on)
  if not RG.db then return end
  RG.db.cardsOnly = on and true or nil
  if on then
    silence()
    if _G.WaypathTracker and _G.WaypathTracker.Hide then _G.WaypathTracker:Hide() end
  end
end

-- the slash command: with the mode on, /wp opens the cards, and only the card commands are answered
local CARD_CMDS = { arcade = true, cards = true, match = true, queue = true, board = true, cardscan = true, cardcheck = true, gradecheck = true, gradetour = true, grading = true, gildedcheck = true, gildedtour = true, textcheck = true, cardcam = true, setup = true, cardsonly = true, help = true, report = true }
function RG.WrapCardsOnlySlash()
  local base = SlashCmdList and SlashCmdList.WAYPATH
  if not base then return end
  SlashCmdList.WAYPATH = function(msg)
    local cmd = (msg or ""):match("^%s*(%S+)")
    cmd = cmd and cmd:lower()
    if cmd == "cardsonly" then
      local arg = (msg or ""):match("^%s*%S+%s+(%S+)")
      arg = arg and arg:lower()
      if arg == "on" or (not arg and not RG.CardsOnly()) then RG.SetCardsOnly(true); RG.Print("Cards only is on: the guide and helpers are off. /wp cardsonly off brings them back (reloads).")
      else RG.SetCardsOnly(false); RG.Print("Cards only is off. Reloading...") if ReloadUI then ReloadUI() end end
      return
    end
    if cmd == "perf" then RG.PerfSample() return end
    if RG.CardsOnly() and not CARD_CMDS[cmd or ""] then
      if RG.ShowArcade then RG.ShowArcade() end
      return
    end
    return base(msg)
  end
end

-- /wp perf: ten seconds of measuring, then memory and (with the game's script profiler on) CPU time
function RG.PerfSample()
  if not (C_Timer and C_Timer.After) then return end
  if perf.on then RG.Print("Already measuring...") return end
  perf.on = true; perf.ms, perf.kb, perf.n, perf.q = {}, {}, {}, {}
  -- the game's own profiler (only with the script profiler on): every function Waypath+ shares and every frame it names, before and after
  local function snapshot()
    local fnT, frT = {}, {}
    if GetFunctionCPUUsage then
      for k, v in pairs(RG) do if type(v) == "function" then local ok, ms = pcall(GetFunctionCPUUsage, v, false); if ok and type(ms) == "number" then fnT[k] = ms end end end
    end
    if GetFrameCPUUsage then
      for k, v in pairs(_G) do
        if type(k) == "string" and k:find("^Waypath") and type(v) == "table" and v.GetObjectType then
          local ok, ms = pcall(GetFrameCPUUsage, v, false); if ok and type(ms) == "number" then frT[k] = ms end
        end
      end
    end
    return fnT, frT
  end
  local fn0, fr0 = snapshot()
  -- every frame on screen, ours or not (a frame without a name is shown by its parent's): for the CPU nobody has labelled
  local function allFrames()
    local t = {}
    if GetFrameCPUUsage and EnumerateFrames then
      local f = EnumerateFrames()
      while f do local ok, ms = pcall(GetFrameCPUUsage, f, false); if ok and type(ms) == "number" and ms > 0 then t[f] = ms end; f = EnumerateFrames(f) end
    end
    return t
  end
  local af0 = allFrames()
  local cpu0 = GetAddOnCPUUsage and pcall(UpdateAddOnCPUUsage) and GetAddOnCPUUsage("Waypath") or nil
  RG.Print("Measuring Waypath+ for 10 seconds: play as you normally would...")
  C_Timer.After(10, function()
    perf.on = false
    local mem, cpu
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage); local ok, kb = pcall(GetAddOnMemoryUsage, "Waypath"); if ok then mem = kb end end
    if cpu0 and UpdateAddOnCPUUsage then pcall(UpdateAddOnCPUUsage); local ok, c = pcall(GetAddOnCPUUsage, "Waypath"); if ok and c then cpu = (c - cpu0) / 10 end end
    local out = { "Waypath+ " .. tostring(RG.VERSION), string.format("Memory %s%s", mem and string.format("%.1f MB", mem / 1024) or "?",
      (cpu and cpu > 0) and string.format("  ·  %.2f ms of CPU per second (a frame at 60 fps has 16.7 ms)", cpu) or "  ·  CPU not measured (needs /console scriptProfile 1, then /reload)") }
    -- which recurring tasks cost the time: milliseconds per second, calls per second, and garbage made per second
    local rows = {}
    for k, ms in pairs(perf.ms) do rows[#rows + 1] = { k, ms / 10, (perf.n[k] or 0) / 10, (perf.kb[k] or 0) / 10 } end
    table.sort(rows, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[4] > b[4] end)
    if #rows == 0 then out[#out + 1] = "nothing recurring ran in those ten seconds." end
    for i = 1, math.min(12, #rows) do
      local r = rows[i]
      out[#out + 1] = string.format("%-16s %.3f ms/s  ·  %.1f calls/s  ·  %.1f KB/s of garbage", r[1], r[2], r[3], r[4])
    end
    local fn1, fr1 = snapshot()
    local prof = {}
    for k, ms in pairs(fn1) do local d = (ms - (fn0[k] or 0)) / 10; if d > 0.01 then prof[#prof + 1] = { "RG." .. k, d } end end
    for k, ms in pairs(fr1) do local d = (ms - (fr0[k] or 0)) / 10; if d > 0.01 then prof[#prof + 1] = { "frame " .. k, d } end end
    table.sort(prof, function(a, b) return a[2] > b[2] end)
    if #prof > 0 then
      out[#out + 1] = "the game's own profiler, own time (ms/s):"
      for i = 1, math.min(10, #prof) do out[#out + 1] = string.format("  %-34s %.3f", prof[i][1], prof[i][2]) end
    end
    local af1, all = allFrames(), {}
    for f, ms in pairs(af1) do
      local d = (ms - (af0[f] or 0)) / 10
      if d > 0.05 then
        local nm = f.GetName and f:GetName()
        if not nm then local pf = f.GetParent and f:GetParent(); nm = "(unnamed, in " .. ((pf and pf.GetName and pf:GetName()) or "?") .. ")" end
        all[#all + 1] = { nm, d }
      end
    end
    table.sort(all, function(a, b) return a[2] > b[2] end)
    if #all > 0 then
      out[#out + 1] = "busiest frames of any add-on (ms/s):"
      for i = 1, math.min(8, #all) do out[#out + 1] = string.format("  %-34s %.3f", all[i][1], all[i][2]) end
    end
    local qs = {}
    for ev, n in pairs(perf.q or {}) do qs[#qs + 1] = { ev, n } end
    table.sort(qs, function(a, b) return a[2] > b[2] end)
    if #qs > 0 then
      local t = {}
      for i = 1, math.min(5, #qs) do t[#t + 1] = qs[i][1] .. " " .. qs[i][2] end
      out[#out + 1] = "tracker refreshes asked by (10 s): " .. table.concat(t, ", ")
    end
    for _, l in ipairs(out) do RG.Print(l) end
    if RG.ShowTrailBox then pcall(RG.ShowTrailBox, "text", "Waypath+ performance report", table.concat(out, "\n")) end
  end)
end
