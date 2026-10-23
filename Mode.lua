-- Waypath+ "Cards only" mode: one switch that turns off everything except the card game (cards, packs, Arena, duels, ranks).
-- The guide, tracker, arrow, quest and vendor helpers and all their pop-ups stop. How it works: while the guide's files load
-- (between GateOn.lua and GateOff.lua in the .toc) every event handler, update loop, timer and game hook they register is wrapped
-- so that it does nothing while db.cardsOnly is set. The card files load outside that window, so they are untouched, and the
-- switch needs no per-feature checks (a new feature is covered the moment it is added between the two markers).
local _, RG = ...
RG = RG or {}
-- (RG.CardsOnly() is defined in Core.lua, which every file can rely on)

local made = setmetatable({}, { __mode = "k" })   -- frames the guide created
RG.featureFrames = made
-- /wp perf: while it samples, every wrapped handler adds the time it took to its file's total
local perf = { on = false, ms = {} }
RG.Perf = perf
local function here()
  local st = debugstack and debugstack(2, 8, 0) or ""
  for f in st:gmatch("([%w_]+%.lua)") do if f ~= "Mode.lua" then return f end end
  return "?"
end
local function guard(fn, label)
  if type(fn) ~= "function" then return fn end
  label = label or here()
  return function(...)
    if RG.CardsOnly() then return end
    if not perf.on then return fn(...) end
    local t0 = debugprofilestop()
    local a, b, c, d = fn(...)
    perf.ms[label] = (perf.ms[label] or 0) + (debugprofilestop() - t0)
    return a, b, c, d
  end
end

local saved
local HOOKED = { "GameTooltip", "ItemRefTooltip", "CharacterFrame", "GameMenuFrame", "Minimap", "WorldMapFrame", "ContainerFrame1", "ContainerFrameCombinedBags" }

function RG.GateOn()
  if saved then return end
  saved = { frames = {} }
  local origCreate = CreateFrame
  saved.CreateFrame = origCreate
  CreateFrame = function(...)
    local f = origCreate(...)
    if type(f) ~= "table" then return f end   -- (nothing to wrap)
    made[f] = true
    local ss, hs = f.SetScript, f.HookScript
    if type(ss) == "function" then
      f.SetScript = function(self, ev, fn) if ev == "OnEvent" or ev == "OnUpdate" then fn = guard(fn) end return ss(self, ev, fn) end
    end
    if type(hs) == "function" then
      f.HookScript = function(self, ev, fn) if ev == "OnEvent" or ev == "OnUpdate" then fn = guard(fn) end return hs(self, ev, fn) end
    end
    return f
  end
  if C_Timer then
    saved.After, saved.NewTicker = C_Timer.After, C_Timer.NewTicker
    if saved.After then C_Timer.After = function(d, fn) return saved.After(d, guard(fn)) end end
    if saved.NewTicker then C_Timer.NewTicker = function(d, fn, n) return saved.NewTicker(d, guard(fn), n) end end
  end
  if hooksecurefunc then
    saved.hooksecurefunc = hooksecurefunc
    hooksecurefunc = function(a, b, c)
      if type(a) == "table" then return saved.hooksecurefunc(a, b, guard(c)) end
      return saved.hooksecurefunc(a, guard(b))
    end
  end
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    saved.post = TooltipDataProcessor.AddTooltipPostCall
    TooltipDataProcessor.AddTooltipPostCall = function(t, fn) return saved.post(t, guard(fn)) end
  end
  if ChatFrame_AddMessageEventFilter then
    saved.filter = ChatFrame_AddMessageEventFilter
    ChatFrame_AddMessageEventFilter = function(ev, fn) return saved.filter(ev, function(...) if RG.CardsOnly() then return false end return fn(...) end) end
  end
  -- hooks on the game's own frames
  for _, name in ipairs(HOOKED) do
    local o = _G[name]
    if type(o) == "table" and type(o.HookScript) == "function" and rawget(o, "HookScript") == nil then
      local orig = o.HookScript
      o.HookScript = function(self, ev, fn) return orig(self, ev, guard(fn)) end
      saved.frames[#saved.frames + 1] = o
    end
  end
  local wm = _G.WorldMapFrame
  local sc = wm and wm.ScrollContainer
  if type(sc) == "table" and type(sc.HookScript) == "function" and rawget(sc, "HookScript") == nil then
    local orig = sc.HookScript
    sc.HookScript = function(self, ev, fn) return orig(self, ev, guard(fn)) end
    saved.frames[#saved.frames + 1] = sc
  end
end

function RG.GateOff()
  if not saved then return end
  CreateFrame = saved.CreateFrame
  if C_Timer then C_Timer.After, C_Timer.NewTicker = saved.After, saved.NewTicker end
  if saved.hooksecurefunc then hooksecurefunc = saved.hooksecurefunc end
  if saved.post then TooltipDataProcessor.AddTooltipPostCall = saved.post end
  if saved.filter then ChatFrame_AddMessageEventFilter = saved.filter end
  for _, o in ipairs(saved.frames) do o.HookScript = nil end
  saved = nil
end

-- Turn the mode on or off for this character. Everything the guide put on screen goes away at once.
function RG.SetCardsOnly(on)
  if not RG.db then return end
  RG.db.cardsOnly = on and true or nil
  if on then
    for f in pairs(made) do
      if f.IsShown and f:IsShown() and f.Hide then pcall(f.Hide, f) end
    end
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

-- /wp perf: ten seconds of measuring, then memory and the cost of each part of the guide, in milliseconds per second
function RG.PerfSample()
  if not (debugprofilestop and C_Timer and C_Timer.After) then RG.Print("This client can't time add-ons.") return end
  if perf.on then RG.Print("Already measuring...") return end
  perf.ms, perf.on = {}, true
  local t0 = debugprofilestop()
  RG.Print("Measuring Waypath+ for 10 seconds: play as you normally would...")
  C_Timer.After(10, function()
    perf.on = false
    local secs = math.max(0.001, (debugprofilestop() - t0) / 1000)
    local mem
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage); local ok, kb = pcall(GetAddOnMemoryUsage, "Waypath"); if ok then mem = kb end end
    local list, total = {}, 0
    for k, v in pairs(perf.ms) do list[#list + 1] = { k, v / secs }; total = total + v / secs end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local parts = {}
    for i = 1, math.min(6, #list) do parts[#parts + 1] = string.format("%s %.2f", list[i][1]:gsub("%.lua$", ""), list[i][2]) end
    RG.Print(string.format("Memory %s  ·  guide %.2f ms per second (a frame at 60 fps has 16.7 ms)%s", mem and string.format("%.1f MB", mem / 1024) or "?", total,
      #parts > 0 and ("  ·  busiest: " .. table.concat(parts, ", ")) or ""))
    if total > 2 then RG.Print("That is more than it should be. Please send this line with /wp report.") end
  end)
end
