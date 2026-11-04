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
local perf = { on = false, ms = {} }
RG.Perf = perf

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
local CARD_CMDS = { arcade = true, cards = true, match = true, queue = true, board = true, cardscan = true, cardcheck = true, cardcam = true, setup = true, cardsonly = true, help = true, report = true }
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
  perf.on = true
  local cpu0 = GetAddOnCPUUsage and pcall(UpdateAddOnCPUUsage) and GetAddOnCPUUsage("Waypath") or nil
  RG.Print("Measuring Waypath+ for 10 seconds: play as you normally would...")
  C_Timer.After(10, function()
    perf.on = false
    local mem, cpu
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage); local ok, kb = pcall(GetAddOnMemoryUsage, "Waypath"); if ok then mem = kb end end
    if cpu0 and UpdateAddOnCPUUsage then pcall(UpdateAddOnCPUUsage); local ok, c = pcall(GetAddOnCPUUsage, "Waypath"); if ok and c then cpu = (c - cpu0) / 10 end end
    RG.Print(string.format("Memory %s%s", mem and string.format("%.1f MB", mem / 1024) or "?",
      (cpu and cpu > 0) and string.format("  ·  %.2f ms of CPU per second (a frame at 60 fps has 16.7 ms)", cpu) or "  ·  CPU time needs the game's script profiler (/console scriptProfile 1, then /reload)"))
  end)
end
