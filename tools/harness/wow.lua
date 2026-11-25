-- A fake World of Warcraft client for the offline harness (run.lua). It is just enough of the game's API for the
-- add-on's files to load and for the login events to run: frames, events, timers, slash commands, a simulated
-- clock, and one character (class, race, faction, level) with empty bags, an empty quest log and no money.
--
-- It also watches for taint: the add-on runs in a proxy environment, so every write to a global, to one of the
-- game's API tables (C_Timer, C_Map...) or to a frame the game owns (GameTooltip, Minimap...) is seen and recorded
-- with the add-on's file and line.
--
-- What it does NOT do: draw anything, know any item, quest, spell or map data, run OnUpdate handlers, or stand in
-- for the game's secure code. A clean run means "loads and logs in without a Lua error", not "works".
local W = {}

local G = {}          -- the game's globals: what the add-on's _G looks things up in
local E               -- the add-on's environment: an empty proxy over G, so every global write goes through __newindex
local OWNED = {}      -- names of the globals the game defines (snapshot taken just before the add-on loads)
local ABSENT = {}     -- globals that are known to be nil at login (other add-ons, load-on-demand UI): not reported
W.G = G
W.errors, W.taint, W.unknown, W.methods, W.chat, W.swallowed = {}, {}, {}, {}, {}, {}
W.now = 0
W.counts = { timers = 0, frames = 0, events = 0, updates = 0 }
W.mods = { shift = false, ctrl = false, alt = false }
W.combat = false
W.phase = nil         -- what the driver is doing (a /wp command, "events"...): shown with each error
local errorIndex, taintIndex, swallowIndex = {}, {}, {}
local function pack(...) return { n = select("#", ...), ... } end

-- ---------------------------------------------------------------------------
-- Where the add-on is (file:line of the innermost add-on function on the stack)
-- ---------------------------------------------------------------------------
-- The add-on's files get the names the game gives them (errors read "Interface/AddOns/Waypath/Core.lua:12: ...",
-- and the add-on's own error catcher looks for "Waypath" in them). The report shortens them back to "Core.lua:12".
W.PREFIX = "Interface/AddOns/Waypath/"
-- (Lua cuts a long file name to "...erface/AddOns/Waypath/x.lua": that form goes too)
function W.short(s) return (tostring(s):gsub("Interface/AddOns/Waypath/", ""):gsub("%.%.%.[%w/]*Waypath/", "")) end
local function isAddon(src) return src:sub(1, 1) == "@" and not src:find("harness/wow%.lua$") and not src:find("harness/run%.lua$") end
W.isAddon = isAddon
local function where(level)
  level = (level or 1) + 1
  while true do
    local info = debug.getinfo(level, "Sl")
    if not info then return "?" end
    if isAddon(info.source) then return W.short(info.source:sub(2)) .. ":" .. (info.currentline or 0) end
    level = level + 1
  end
end
W.where = where

W.context = "loading"   -- what the harness is doing right now (shown next to each error)

local function addError(msg, loc, trace)
  local key = loc .. "|" .. msg
  local e = errorIndex[key]
  if e then e.count = e.count + 1 return end
  e = { msg = W.short(msg), raw = msg, where = loc, trace = W.short(trace), context = W.context, phase = W.phase, count = 1 }
  errorIndex[key] = e
  W.errors[#W.errors + 1] = e
end

-- An error the add-on caught with pcall and threw away. Some are deliberate (trying an API that may not exist),
-- some are a feature failing silently; the report lists them apart from the real errors.
function W.swallow(msg, loc)
  msg = W.short(msg)
  local key = loc .. "|" .. msg
  local e = swallowIndex[key]
  if e then e.count = e.count + 1 return end
  e = { msg = msg, where = loc, context = W.context, phase = W.phase, count = 1 }
  swallowIndex[key] = e
  W.swallowed[#W.swallowed + 1] = e
end

local function addTaint(kind, name, loc)
  local key = kind .. "|" .. name .. "|" .. loc
  if taintIndex[key] then return end
  taintIndex[key] = true
  W.taint[#W.taint + 1] = { kind = kind, name = name, where = loc, context = W.context }
end

-- Call add-on code the way the game does: an error is caught, recorded and the game carries on.
function W.call(context, fn, ...)
  local n, args = select("#", ...), { ... }
  local saved = W.context
  W.context = context
  local ok, err = xpcall(function() local r = { fn(unpack(args, 1, n)) }; return unpack(r) end, function(e)
    return { msg = tostring(e), where = where(2), trace = debug.traceback("", 2), context = W.context }
  end)
  W.context = saved
  if not ok then
    local s = W.context
    W.context = err.context
    addError(err.msg, err.where, err.trace)
    W.context = s
    -- like the game: the error also goes to the error handler (the add-on's own catcher, if it set one)
    if W.errorHandler then pcall(W.errorHandler, err.msg) end
  end
  return ok
end

-- What an API function nobody modelled returns: 0 for counts, false for questions, nil otherwise.
local function generic(name)
  if name:find("^GetNum") or name:find("^Num%u") or name:find("Num%u") or name:find("Money") or name:find("Cost$")
    or name:find("Count$") then return function() return 0 end end
  if name:find("^Is") or name:find("^Can") or name:find("^Has") or name:find("^In[A-Z]") then return function() return false end end
  return function() return nil end
end

-- An API table (C_Timer, C_Map...): members we don't model are generic functions. Writing to it is taint. The
-- table handed out is an empty proxy (the members live in `t`), so every write is seen, not only new keys.
W.apis = {}          -- the members behind each API table (the simulated world fills these in, which isn't taint)
local function apiTable(tname, t)
  t = t or {}
  W.apis[tname] = t
  return setmetatable({}, {
    __index = function(_, k)
      local v = t[k]
      if v ~= nil then return v end
      if type(k) ~= "string" or not k:find("^%u") then return nil end
      v = generic(k); t[k] = v; return v
    end,
    __newindex = function(_, k, v) addTaint("field", tname .. "." .. tostring(k), where(2)); t[k] = v end,
  })
end

-- ---------------------------------------------------------------------------
-- Clock and timers
-- ---------------------------------------------------------------------------
local START = 10000          -- GetTime() at login (the game's uptime clock never starts at 0)
local timers = {}            -- { at, fn, ticker, context, seq }
local seq = 0
local function schedule(at, fn, ticker, label)
  seq = seq + 1
  local t = { at = at, fn = fn, ticker = ticker, label = label, seq = seq }
  timers[#timers + 1] = t
  return t
end
-- Run every timer that is due in the next `seconds`, in order, including ones they start.
function W.advance(seconds)
  local stop = W.now + seconds
  local guard = 0
  while true do
    local best
    for _, t in ipairs(timers) do
      if not t.cancelled and t.at <= stop and (not best or t.at < best.at or (t.at == best.at and t.seq < best.seq)) then best = t end
    end
    if not best then break end
    guard = guard + 1
    if guard > 100000 then addError("the harness stopped after 100000 timer callbacks (a timer that keeps restarting itself at 0 s?)", "?", "") break end
    W.now = math.max(W.now, best.at)
    local tk = best.ticker
    if tk then
      tk.done = tk.done + 1
      if tk.iterations and tk.done >= tk.iterations then best.cancelled = true; tk.cancelled = true
      else best.at = W.now + math.max(tk.interval, 0.01) end
    else
      best.cancelled = true
    end
    W.counts.timers = W.counts.timers + 1
    W.call(best.label, best.fn, tk and tk.handle or nil)
  end
  W.now = stop
  local live = {}
  for _, t in ipairs(timers) do if not t.cancelled then live[#live + 1] = t end end
  timers = live
end

local function timerHandle(t)
  local h = {}
  function h:Cancel() t.cancelled = true; if t.ticker then t.ticker.cancelled = true end end
  function h:IsCancelled() return t.cancelled and true or false end
  if t.ticker then t.ticker.handle = h end
  return h
end

G.C_Timer = apiTable("C_Timer", {
  After = function(sec, fn)
    if type(fn) ~= "function" then error("Usage: C_Timer.After(seconds, callback)", 2) end
    schedule(W.now + (tonumber(sec) or 0), fn, nil, "C_Timer.After(" .. tostring(sec) .. ") from " .. where(2))
  end,
  NewTimer = function(sec, fn)
    local t = schedule(W.now + (tonumber(sec) or 0), fn, nil, "C_Timer.NewTimer(" .. tostring(sec) .. ") from " .. where(2))
    local h = timerHandle(t)
    local raw = t.fn
    t.fn = function() return raw(h) end
    return h
  end,
  NewTicker = function(sec, fn, iterations)
    local tk = { interval = tonumber(sec) or 0, iterations = iterations, done = 0 }
    local t = schedule(W.now + math.max(tk.interval, 0.01), fn, tk, "C_Timer.NewTicker(" .. tostring(sec) .. ") from " .. where(2))
    return timerHandle(t)
  end,
})
G.GetTime = function() return START + W.now end
G.GetServerTime = function() return os.time() + math.floor(W.now) end
G.time = function(t) if t then return os.time(t) end return os.time() + math.floor(W.now) end
G.date = function(fmt, t) return os.date(fmt, t or G.time()) end
G.difftime = os.difftime
G.debugprofilestop = function() return os.clock() * 1000 end
G.GetGameTime = function() local d = os.date("*t", G.time()); return d.hour, d.min end

-- ---------------------------------------------------------------------------
-- Widgets (frames, textures, font strings, animations, tooltips)
-- ---------------------------------------------------------------------------
local S = setmetatable({}, { __mode = "k" })   -- each widget's state, kept off the widget so rawget sees only what the add-on set
local Methods = {}
local frames = {}                                -- every Frame-like widget in creation order (EnumerateFrames)
local events = {}                                -- event -> { frame, ... } in registration order

local function unknownMethod(k)
  local f = generic(k)
  W.methods[k] = (W.methods[k] or 0) + 1
  return f
end
-- A key nobody modelled is taken for a method only when it reads like one (GetX, SetX, IsX...): a capitalised
-- field such as WorldMapFrame.ScrollContainer is a child frame in the game, so it stays nil here.
local VERBS = { "Get", "Set", "Is", "Has", "Can", "Enable", "Disable", "Register", "Unregister", "Clear", "Create", "Start",
  "Stop", "Show", "Hide", "Hook", "Lock", "Unlock", "Add", "Remove", "Update", "Raise", "Lower", "Play", "Pause", "Adjust",
  "Highlight", "Unhighlight", "Toggle", "Refresh", "Scroll", "Insert", "Apply", "Fade", "Undress", "Try", "Use", "Release",
  "Acquire", "Reset", "Restart", "Load", "Dress", "Zoom", "Free", "Make", "Rotate", "Move", "Animate", "Flash", "Layout" }
local function looksLikeMethod(k)
  if type(k) ~= "string" then return false end
  for _, v in ipairs(VERBS) do if k:sub(1, #v) == v and (#k == #v or k:sub(#v + 1, #v + 1):find("%u")) then return true end end
  return false
end
local WidgetMT = { __index = function(_, k)
  local m = Methods[k]
  if m then return m end
  if looksLikeMethod(k) then return unknownMethod(k) end
end }
-- the game's own frames: the add-on may call their methods but must not write to them or replace their scripts
local OwnedMT = { __index = WidgetMT.__index, __newindex = function(t, k, v)
  addTaint("field", (S[t] and S[t].name or "a game frame") .. "." .. tostring(k), where(2))
  rawset(t, k, v)
end }

local function describe(w)
  local st = S[w]
  if not st then return "?" end
  if st.name then return st.name end
  return "a " .. st.type .. " made at " .. (st.madeAt or "?")
end
W.describe = describe

local FRAMEISH = { Texture = false, FontString = false, MaskTexture = false, Line = false, AnimationGroup = false, Animation = false, Font = false }
local function newWidget(otype, name, parent, owned)
  local w = {}
  local st = { type = otype, name = name, parent = parent, shown = true, scripts = {}, hooks = {}, events = {},
    points = {}, w = 0, h = 0, alpha = 1, scale = 1, level = 1, strata = "MEDIUM", children = {}, regions = {},
    attrs = {}, enabled = true, owned = owned, madeAt = owned and "the game" or where(3) }
  S[w] = st
  setmetatable(w, owned and OwnedMT or WidgetMT)
  if parent and S[parent] then
    local ps = S[parent]
    if FRAMEISH[otype] == false then ps.regions[#ps.regions + 1] = w else ps.children[#ps.children + 1] = w end
    if ps.level and FRAMEISH[otype] == nil then st.level = ps.level + 1 end
  end
  if FRAMEISH[otype] == nil then frames[#frames + 1] = w; if not owned then W.counts.frames = W.counts.frames + 1 end end
  if name then rawset(G, name, w) end
  return w, st
end

local function runScript(w, script, ...)
  local st = S[w]
  if not st then return end
  local fn = st.scripts[script]
  local label = (script == "OnEvent" and (tostring((...)) .. ", in the OnEvent of ") or (script .. " of ")) .. describe(w)
  if fn then W.call(label, fn, w, ...) end
  local hooks = st.hooks[script]
  if hooks then for _, h in ipairs(hooks) do W.call(label .. " (hook)", h, w, ...) end end
end
W.runScript = runScript

local function visible(w)
  local st = S[w]
  while st do
    if not st.shown then return false end
    st = st.parent and S[st.parent]
  end
  return true
end

-- visibility
function Methods:Show() local st = S[self]; if st and not st.shown then st.shown = true; if visible(self) then runScript(self, "OnShow") end end end
function Methods:Hide() local st = S[self]; if st and st.shown then local was = visible(self); st.shown = false; if was then runScript(self, "OnHide") end end end
function Methods:SetShown(on) if on then self:Show() else self:Hide() end end
function Methods:IsShown() return S[self].shown end
function Methods:IsVisible() return visible(self) end
-- scripts
function Methods:SetScript(script, fn)
  local st = S[self]
  if st.owned and st.scripts[script] ~= nil then addTaint("script", describe(self) .. ":SetScript(\"" .. tostring(script) .. "\") replaces the game's handler; use HookScript", where(2)) end
  st.scripts[script] = fn
end
function Methods:GetScript(script) return S[self].scripts[script] end
function Methods:HookScript(script, fn) local h = S[self].hooks; h[script] = h[script] or {}; table.insert(h[script], fn) end
function Methods:HasScript() return true end
-- events
function Methods:RegisterEvent(ev)
  if type(ev) ~= "string" then error("Usage: RegisterEvent(\"EVENT\")", 2) end
  local st = S[self]
  if st.events[ev] then return true end
  st.events[ev] = true
  events[ev] = events[ev] or {}
  table.insert(events[ev], self)
  return true
end
Methods.RegisterUnitEvent = Methods.RegisterEvent
function Methods:UnregisterEvent(ev) S[self].events[ev] = nil end
function Methods:UnregisterAllEvents() S[self].events = {} end
function Methods:IsEventRegistered(ev) return S[self].events[ev] and true or false end
-- tree
function Methods:GetName() return S[self].name end
function Methods:GetDebugName() return describe(self) end
function Methods:GetParent() return S[self].parent end
function Methods:SetParent(p) S[self].parent = p end
function Methods:GetChildren() return unpack(S[self].children) end
function Methods:GetNumChildren() return #S[self].children end
function Methods:GetRegions() return unpack(S[self].regions) end
function Methods:GetNumRegions() return #S[self].regions end
function Methods:GetObjectType() return S[self].type end
function Methods:IsObjectType(t) local ty = S[self].type; return ty == t or t == "Region" or t == "Object" or t == "ScriptObject" or (t == "Frame" and FRAMEISH[ty] == nil) end
function Methods:IsForbidden() return false end
function Methods:IsProtected() return false end
function Methods:IsDescendantOf(p)
  local q = S[self].parent
  while q do if q == p then return true end q = S[q] and S[q].parent end
  return false
end
function Methods:SetID(id) S[self].id = id end
function Methods:GetID() return S[self].id or 0 end
function Methods:SetAttribute(k, v) S[self].attrs[k] = v end
function Methods:GetAttribute(k) return S[self].attrs[k] end
-- geometry
function Methods:SetPoint(point, a, b, c, d)
  if type(point) ~= "string" then error("Usage: SetPoint(\"point\" [, relativeTo [, \"relativePoint\"]] [, x, y])", 2) end
  table.insert(S[self].points, { point, a, b, c, d })
end
function Methods:SetAllPoints(rel) S[self].points = { { "TOPLEFT", rel }, { "BOTTOMRIGHT", rel } } end
function Methods:ClearAllPoints() S[self].points = {} end
function Methods:ClearPoint() end
function Methods:GetNumPoints() return #S[self].points end
function Methods:GetPoint(i) local p = S[self].points[i or 1]; if p then return unpack(p, 1, 5) end end
function Methods:SetSize(w, h) local st = S[self]; st.w, st.h = tonumber(w) or 0, tonumber(h or w) or 0 end
function Methods:SetWidth(w) S[self].w = tonumber(w) or 0 end
function Methods:SetHeight(h) S[self].h = tonumber(h) or 0 end
function Methods:GetWidth() return S[self].w end
function Methods:GetHeight() return S[self].h end
function Methods:GetSize() local st = S[self]; return st.w, st.h end
function Methods:GetRect() local st = S[self]; return 0, 0, st.w, st.h end
function Methods:GetScaledRect() local st = S[self]; return 0, 0, st.w, st.h end
function Methods:GetCenter() local st = S[self]; return 960, 540 end
function Methods:GetLeft() return 960 - S[self].w / 2 end
function Methods:GetRight() return 960 + S[self].w / 2 end
function Methods:GetTop() return 540 + S[self].h / 2 end
function Methods:GetBottom() return 540 - S[self].h / 2 end
function Methods:SetScale(s) S[self].scale = tonumber(s) or 1 end
function Methods:GetScale() return S[self].scale end
function Methods:GetEffectiveScale()
  local s, st = 1, S[self]
  while st do s = s * (st.scale or 1); st = st.parent and S[st.parent] end
  return s
end
function Methods:SetAlpha(a) S[self].alpha = tonumber(a) or 1 end
function Methods:GetAlpha() return S[self].alpha end
function Methods:GetEffectiveAlpha() return S[self].alpha end
function Methods:SetFrameLevel(l) S[self].level = tonumber(l) or 1 end
function Methods:GetFrameLevel() return S[self].level end
function Methods:SetFrameStrata(s) S[self].strata = s end
function Methods:GetFrameStrata() return S[self].strata end
function Methods:IsMouseOver() return false end
function Methods:IsMouseEnabled() return S[self].mouse and true or false end
function Methods:EnableMouse(on) S[self].mouse = on end
function Methods:IsMovable() return S[self].movable and true or false end
function Methods:SetMovable(on) S[self].movable = on end
function Methods:GetClipsChildren() return false end
-- children
local function makeRegion(self, otype, name, layer)
  local p = S[self]
  if name and p.name then name = name:gsub("%$parent", p.name) end
  local r, st = newWidget(otype, name, self)
  st.layer = layer
  return r
end
function Methods:CreateTexture(name, layer) return makeRegion(self, "Texture", name, layer) end
function Methods:CreateMaskTexture(name, layer) return makeRegion(self, "MaskTexture", name, layer) end
function Methods:CreateLine(name, layer) return makeRegion(self, "Line", name, layer) end
function Methods:CreateFontString(name, layer, inherits)
  local r = makeRegion(self, "FontString", name, layer)
  local f = inherits and rawget(G, inherits)
  if f and S[f] and S[f].font then S[r].font = { unpack(S[f].font) } end
  return r
end
function Methods:CreateAnimationGroup(name) return makeRegion(self, "AnimationGroup", name) end
function Methods:CreateAnimation(atype, name)
  local a, st = makeRegion(self, "Animation", name)
  st.animType = atype
  return a
end
-- a tooltip's lines also go into its <name>TextLeftN / TextRightN font strings, where add-ons read them
local function syncLines(tt)
  local st = S[tt]
  if not st.lineFS then return end
  for i, pair in ipairs(st.lineFS) do
    local l = st.lines and st.lines[i]
    S[pair[1]].text = l and l[1] or nil
    S[pair[2]].text = l and l[2] or nil
  end
end
-- text
function Methods:SetText(t)
  local st = S[self]
  if st.type == "GameTooltip" then st.lines = { { tostring(t) } }; syncLines(self) return end
  st.text = t ~= nil and tostring(t) or nil
  if st.fs then S[st.fs].text = st.text end
end
function Methods:SetFormattedText(fmt, ...) self:SetText(string.format(fmt, ...)) end
function Methods:GetText()
  local st = S[self]
  if st.fs then return S[st.fs].text end
  if st.type == "EditBox" then return st.text or "" end
  return st.text
end
function Methods:GetNumber() return tonumber(S[self].text) or 0 end
function Methods:GetStringWidth() return #(S[self].text or "") * 6 end
Methods.GetUnboundedStringWidth = Methods.GetStringWidth
function Methods:GetStringHeight() return 12 end
function Methods:GetLineHeight() return 12 end
function Methods:IsTruncated() return false end
function Methods:CanWordWrap() return true end
function Methods:GetNumLines() local st = S[self]; if st.lines then return #st.lines end return 1 end
function Methods:SetFont(path, size, flags) S[self].font = { path, size, flags }; return true end
function Methods:GetFont() local f = S[self].font; if f then return f[1], f[2], f[3] end return "Fonts\\FRIZQT__.TTF", 12, "" end
function Methods:SetFontObject(fo) local f = fo and S[fo] and S[fo].font; if f then S[self].font = { unpack(f) } end end
function Methods:GetFontObject() return G.GameFontNormal end
function Methods:SetTextColor(r, g, b, a) S[self].tc = { r, g, b, a } end
function Methods:GetTextColor() local c = S[self].tc; if c then return c[1], c[2], c[3], c[4] or 1 end return 1, 1, 1, 1 end
function Methods:SetJustifyH(j) S[self].jh = j end
function Methods:GetJustifyH() return S[self].jh or "CENTER" end
function Methods:SetJustifyV(j) S[self].jv = j end
function Methods:GetJustifyV() return S[self].jv or "MIDDLE" end
function Methods:SetFontString(fs) S[self].fs = fs end
function Methods:GetFontString()
  local st = S[self]
  if not st.fs then st.fs = makeRegion(self, "FontString") end
  return st.fs
end
-- textures
function Methods:SetTexture(t) S[self].tex = t; return true end
function Methods:GetTexture() return S[self].tex end
function Methods:SetColorTexture(r, g, b, a) S[self].tex = "color" end
function Methods:SetAtlas(a) S[self].atlas = a; return true end
function Methods:GetAtlas() return S[self].atlas end
function Methods:SetTexCoord(...) S[self].tc8 = { ... } end
function Methods:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, 1 end
function Methods:SetVertexColor(r, g, b, a) S[self].vc = { r, g, b, a } end
function Methods:GetVertexColor() local c = S[self].vc; if c then return c[1], c[2], c[3], c[4] or 1 end return 1, 1, 1, 1 end
function Methods:GetDrawLayer() return S[self].layer or "ARTWORK", 0 end
local function texGetter(field)
  return function(self)
    local st = S[self]
    if not st[field] then st[field] = makeRegion(self, "Texture") end
    return st[field]
  end
end
local function texSetter(field)
  return function(self, t)
    local st = S[self]
    if type(t) == "table" then st[field] = t
    else local tx = texGetter(field)(self); tx:SetTexture(t) end
  end
end
for _, k in ipairs({ "Normal", "Highlight", "Pushed", "Disabled", "Checked", "DisabledChecked", "Thumb", "StatusBar" }) do
  Methods["Get" .. k .. "Texture"] = texGetter(k:lower() .. "Tex")
  Methods["Set" .. k .. "Texture"] = texSetter(k:lower() .. "Tex")
end
-- buttons, check buttons, edit boxes, sliders, status bars, scroll frames
function Methods:Click(button)
  if not S[self].enabled then return end
  if S[self].type == "CheckButton" then S[self].checked = not S[self].checked end
  runScript(self, "PreClick", button or "LeftButton", false)
  runScript(self, "OnClick", button or "LeftButton", false)
  runScript(self, "PostClick", button or "LeftButton", false)
end
function Methods:Enable() S[self].enabled = true end
function Methods:Disable() S[self].enabled = false end
function Methods:SetEnabled(on) S[self].enabled = on and true or false end
function Methods:IsEnabled() return S[self].enabled end
function Methods:SetChecked(on) S[self].checked = on and true or false end
function Methods:GetChecked() return S[self].checked or false end
function Methods:HasFocus() return S[self].focus and true or false end
function Methods:SetFocus() S[self].focus = true end
function Methods:ClearFocus() S[self].focus = false end
function Methods:GetCursorPosition() return 0 end
function Methods:SetMinMaxValues(a, b) S[self].min, S[self].max = tonumber(a) or 0, tonumber(b) or 0 end
function Methods:GetMinMaxValues() return S[self].min or 0, S[self].max or 0 end
function Methods:SetValue(v)
  local st = S[self]
  v = tonumber(v) or 0
  if st.min and v < st.min then v = st.min end
  if st.max and v > st.max then v = st.max end
  local old = st.value
  st.value = v
  if old ~= v then runScript(self, "OnValueChanged", v, false) end
end
function Methods:GetValue() return S[self].value or 0 end
function Methods:SetScrollChild(c) S[self].scrollChild = c end
function Methods:GetScrollChild() return S[self].scrollChild end
function Methods:SetVerticalScroll(v) S[self].vs = tonumber(v) or 0 end
function Methods:GetVerticalScroll() return S[self].vs or 0 end
function Methods:SetHorizontalScroll(v) S[self].hs = tonumber(v) or 0 end
function Methods:GetHorizontalScroll() return S[self].hs or 0 end
function Methods:GetVerticalScrollRange() return 0 end
function Methods:GetHorizontalScrollRange() return 0 end
-- things that only change how a widget looks or moves: accepted and ignored
for _, k in ipairs({ "AddMaskTexture", "RemoveMaskTexture", "EnableMouseWheel", "EnableKeyboard", "RegisterForClicks", "RegisterForDrag",
  "SetBackdropBorderColor", "SetBackdropColor", "SetBlendMode", "SetClampedToScreen", "SetClampRectInsets", "SetDesaturated",
  "SetMaxLines", "SetShadowColor", "SetShadowOffset", "SetSpacing", "SetWordWrap", "SetNonSpaceWrap", "StartMoving", "StartSizing",
  "StopMovingOrSizing", "SetUserPlaced", "SetToplevel", "SetResizable", "SetResizeBounds", "SetMinResize", "SetMaxResize",
  "SetHitRectInsets", "SetDrawLayer", "SetClipsChildren", "SetIgnoreParentAlpha", "SetIgnoreParentScale", "SetPropagateKeyboardInput",
  "SetMultiLine", "SetAutoFocus", "SetMaxLetters", "SetTextInsets", "HighlightText", "SetHorizTile", "SetVertTile", "SetRotation",
  "SetGradient", "SetGradientAlpha", "SetSnapToPixelGrid", "SetTexelSnappingBias", "SetStatusBarColor", "SetOrientation",
  "SetObeyStepOnDrag", "SetValueStep", "SetStepsPerPage", "SetLooping", "SetFromAlpha", "SetToAlpha", "SetOffset", "SetOrder",
  "SetSmoothing", "SetStartDelay", "SetEndDelay", "SetScaleFrom", "SetScaleTo", "SetOrigin", "SetChange", "SetRadians", "SetDegrees",
  "SetFixedFrameStrata", "SetFixedFrameLevel", "SetDontSavePosition", "LockHighlight", "UnlockHighlight", "SetMotionScriptsWhileDisabled",
  "SetHyperlinksEnabled", "SetFading", "SetTimeVisible", "SetInsertMode", "SetIndentedWordWrap", "SetHistoryLines", "SetCountInvisibleLetters" }) do
  Methods[k] = function() end
end
function Methods:SetBackdrop(b) S[self].backdrop = b end
function Methods:GetBackdrop() return S[self].backdrop end
-- chat frames
function Methods:AddMessage(msg) W.chat[#W.chat + 1] = tostring(msg) end
-- tooltips (their lines also go into the <name>TextLeftN font strings: see syncLines)
function Methods:SetOwner(owner) local st = S[self]; st.owner = owner; st.lines = {}; st.item = nil; syncLines(self) end
function Methods:GetOwner() return S[self].owner end
function Methods:IsOwned(f) return S[self].owner == f end
function Methods:ClearLines() S[self].lines = {}; S[self].item = nil; syncLines(self) end
function Methods:AddLine(t) local st = S[self]; st.lines = st.lines or {}; st.lines[#st.lines + 1] = { tostring(t) }; syncLines(self) end
function Methods:AddDoubleLine(a, b) local st = S[self]; st.lines = st.lines or {}; st.lines[#st.lines + 1] = { tostring(a), tostring(b) }; syncLines(self) end
function Methods:NumLines() return #(S[self].lines or {}) end
-- an item on a tooltip: with the simulated world's items (W.itemTooltip), its lines go in and the game's item
-- callbacks run (OnTooltipSetItem and TooltipDataProcessor's item post-calls); without them it stays empty
local function showItem(tt, link)
  local st = S[tt]
  st.lines, st.item = {}, nil
  if not (link and W.itemTooltip) then syncLines(tt) return end
  local name, full, id, lines = W.itemTooltip(link)
  if not name then syncLines(tt) return end
  st.item = { name = name, link = full, id = id }
  for _, l in ipairs(lines) do st.lines[#st.lines + 1] = { l.leftText, l.rightText } end
  syncLines(tt)
  runScript(tt, "OnTooltipSetItem")
  for _, pc in ipairs(W.tooltipPostCalls and W.tooltipPostCalls() or {}) do
    if pc.type == 0 then W.call("TooltipDataProcessor item post-call", pc.fn, tt, { type = 0, id = id, hyperlink = full, lines = lines }) end
  end
end
function Methods:SetHyperlink(link) showItem(self, link) end
function Methods:SetBagItem(b, s) showItem(self, W.bagItemLink and W.bagItemLink(b, s)) end
function Methods:SetInventoryItem(u, slot) showItem(self, W.inventoryItemLink and W.inventoryItemLink(u, slot)) end
function Methods:SetItemByID(id) showItem(self, id) end
function Methods:GetItem() local it = S[self].item; if it then return it.name, it.link, it.id end end
function Methods:GetUnit() return nil end
function Methods:GetSpell() return nil end
-- animations
function Methods:Play() S[self].playing = true end
function Methods:Stop() S[self].playing = false end
function Methods:Pause() S[self].playing = false end
function Methods:IsPlaying() return S[self].playing and true or false end
function Methods:SetDuration(d) S[self].duration = d end
function Methods:GetDuration() return S[self].duration or 0 end
function Methods:GetProgress() return 0 end
-- the world map (a canvas)
function Methods:GetMapID() return S[self].mapID end
function Methods:GetNormalizedCursorPosition() return 0.5, 0.5 end
function Methods:GetCanvasScale() return 1 end
function Methods:GetCanvas() local st = S[self]; if not st.canvas then st.canvas = newWidget("Frame", nil, self) end return st.canvas end

-- Templates the add-on uses: the children the game would make for them.
local function child(parent, otype, name, field, ...)
  local pn = S[parent].name
  local n = name and pn and name:gsub("%$parent", pn) or nil
  local c = otype == "FontString" and makeRegion(parent, "FontString", n) or (otype == "Texture" and makeRegion(parent, "Texture", n)) or newWidget(otype, n, parent)
  if field then rawset(parent, field, c) end
  return c
end
local TEMPLATES = {
  UIPanelButtonTemplate = function(f) local t = child(f, "FontString", "$parentText", "Text"); S[f].fs = t; f.Left = child(f, "Texture"); f.Right = child(f, "Texture"); f.Middle = child(f, "Texture") end,
  UICheckButtonTemplate = function(f) local t = child(f, "FontString", "$parentText", "Text"); rawset(f, "text", t) end,
  UIPanelScrollFrameTemplate = function(f)
    local sb = child(f, "Slider", "$parentScrollBar", "ScrollBar")
    rawset(sb, "ScrollUpButton", child(sb, "Button", "$parentScrollUpButton"))
    rawset(sb, "ScrollDownButton", child(sb, "Button", "$parentScrollDownButton"))
  end,
  InputBoxTemplate = function(f) child(f, "Texture", "$parentLeft", "Left"); child(f, "Texture", "$parentRight", "Right"); child(f, "Texture", "$parentMiddle", "Middle") end,
  UIPanelCloseButton = function() end,
  GameTooltipTemplate = function(f) W.tooltipLines(f) end,
  BackdropTemplate = function() end,
  SecureActionButtonTemplate = function() end,
}

local VALID_TYPES = { Frame = true, Button = true, CheckButton = true, EditBox = true, ScrollFrame = true, Slider = true,
  StatusBar = true, GameTooltip = true, MessageFrame = true, ScrollingMessageFrame = true, Cooldown = true, ColorSelect = true,
  Model = true, PlayerModel = true, DressUpModel = true, CinematicModel = true, TabardModel = true, ModelScene = true,
  SimpleHTML = true, Minimap = true, MovieFrame = true, Browser = true, ArchaeologyDigSiteFrame = true, QuestPOIFrame = true,
  ScenarioPOIFrame = true, FogOfWarFrame = true, UnitPositionFrame = true, OffScreenFrame = true, ItemButton = true, EventFrame = true }

G.CreateFrame = function(otype, name, parent, templates, id)
  if type(otype) ~= "string" or not VALID_TYPES[otype] then error("CreateFrame: unknown frame type '" .. tostring(otype) .. "'", 2) end
  if name and parent and S[parent] and S[parent].name then name = name:gsub("%$parent", S[parent].name) end
  local f, st = newWidget(otype, name, parent)
  st.madeAt = where(2)
  if id then st.id = id end
  if otype == "EditBox" then st.text = "" end
  for t in tostring(templates or ""):gmatch("[^,%s]+") do
    local build = TEMPLATES[t]
    if build then build(f) else W.methods["template " .. t] = (W.methods["template " .. t] or 0) + 1 end
  end
  return f
end
G.CreateFont = function(name) local f, st = newWidget("Font", name); st.font = { "Fonts\\FRIZQT__.TTF", 12, "" }; return f end
G.EnumerateFrames = function(f)
  if not f then return frames[1] end
  for i, x in ipairs(frames) do if x == f then return frames[i + 1] end end
end
G.GetMouseFocus = function() return nil end
G.GetMouseFoci = function() return {} end
G.GetCursorPosition = function() return 0, 0 end
G.GetScreenWidth = function() return 1920 end
G.GetScreenHeight = function() return 1080 end

-- Per-frame updates: `seconds` of game time at `fps`, running timers and every visible frame's OnUpdate.
function W.step(seconds, fps)
  fps = fps or 20
  local dt = 1 / fps
  for _ = 1, math.max(1, math.floor(seconds * fps + 0.5)) do
    W.advance(dt)
    local due = {}
    for _, f in ipairs(frames) do
      local st = S[f]
      if (st.scripts.OnUpdate or st.hooks.OnUpdate) and visible(f) then due[#due + 1] = f end
    end
    for _, f in ipairs(due) do W.counts.updates = W.counts.updates + 1; runScript(f, "OnUpdate", dt) end
  end
end

-- What the driver needs to see
function W.frames() local t = {}; for i, f in ipairs(frames) do t[i] = f end return t end
function W.isOwned(f) return S[f] and S[f].owned and true or false end
local QUIET = { OnEvent = true, OnUpdate = true }
function W.hasScripts(f)
  local st = S[f]
  for k in pairs(st.scripts) do if not QUIET[k] then return true end end
  for k in pairs(st.hooks) do if not QUIET[k] then return true end end
  return false
end
function W.hasScript(f, s) local st = S[f]; return st.scripts[s] ~= nil or st.hooks[s] ~= nil end
function W.hasHooks(f) local st = S[f]; for k in pairs(st.hooks) do if not QUIET[k] then return true end end return false end
function W.hasHook(f, s) return S[f].hooks[s] ~= nil end
function W.setValueQuiet(f, v) S[f].value = v end
W.exercised = setmetatable({}, { __mode = "k" })
function W.registered()
  local t = {}
  for ev, list in pairs(events) do
    for _, f in ipairs(list) do if S[f].events[ev] then t[ev] = true break end end
  end
  return t
end

-- Events
function W.fire(ev, ...)
  W.counts.events = W.counts.events + 1
  local list = events[ev]
  if not list then return end
  local snapshot = { unpack(list) }
  for _, f in ipairs(snapshot) do
    if S[f].events[ev] then runScript(f, "OnEvent", ev, ...) end
  end
end
function W.onUpdateCount()
  local n = 0
  for _, f in ipairs(frames) do if S[f].scripts.OnUpdate or S[f].hooks.OnUpdate then n = n + 1 end end
  return n
end

-- ---------------------------------------------------------------------------
-- The game's own frames
-- ---------------------------------------------------------------------------
local function gameFrame(name, otype, parent)
  local f = newWidget(otype or "Frame", name, parent, true)
  return f
end
G.UIParent = gameFrame("UIParent")
S[G.UIParent].w, S[G.UIParent].h = 1920, 1080
G.WorldFrame = gameFrame("WorldFrame")
for _, n in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }) do
  G[n] = gameFrame(n, "GameTooltip", G.UIParent); S[G[n]].shown = false
end
-- a tooltip's lines are font strings named <tooltip>TextLeft1, <tooltip>TextRight1... (add-ons read them)
local function tooltipLines(tt)
  local st = S[tt]
  if st.lineFS or not st.name then return end
  st.lineFS = {}
  for i = 1, 30 do
    local l = makeRegion(tt, "FontString", st.name .. "TextLeft" .. i)
    local r = makeRegion(tt, "FontString", st.name .. "TextRight" .. i)
    st.lineFS[i] = { l, r }
  end
end
W.tooltipLines = tooltipLines
for _, n in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }) do tooltipLines(G[n]) end
G.Minimap = gameFrame("Minimap", "Minimap", G.UIParent)
G.UIErrorsFrame = gameFrame("UIErrorsFrame", "MessageFrame", G.UIParent)
for i = 1, 10 do G["ChatFrame" .. i] = gameFrame("ChatFrame" .. i, "ScrollingMessageFrame", G.UIParent) end
G.DEFAULT_CHAT_FRAME = G.ChatFrame1
G.ChatFrame1EditBox = gameFrame("ChatFrame1EditBox", "EditBox", G.ChatFrame1); S[G.ChatFrame1EditBox].text = ""; S[G.ChatFrame1EditBox].shown = false
G.SELECTED_CHAT_FRAME = G.ChatFrame1
for _, n in ipairs({ "CharacterFrame", "WorldMapFrame", "MerchantFrame", "BankFrame", "MailFrame", "SendMailFrame",
  "MailFrameTab2", "QuestLogFrame", "QuestInfoRewardsFrame", "GameMenuFrame", "ContainerFrameCombinedBags",
  "QuestFrame", "GossipFrame", "TaxiFrame", "LootFrame", "SpellBookFrame", "FriendsFrame", "PVEFrame",
  "ObjectiveTrackerFrame", "QuestWatchFrame", "PaperDollFrame", "TradeSkillFrame", "CraftFrame", "ClassTrainerFrame" }) do
  G[n] = gameFrame(n, "Frame", G.UIParent); S[G[n]].shown = false
end
S[G.WorldMapFrame].mapID = 1414
-- (the harness fills in the game's frames with rawset: a plain write would be recorded as taint)
rawset(G.WorldMapFrame, "ScrollContainer", gameFrame(nil, "ScrollFrame", G.WorldMapFrame))
rawset(G.WorldMapFrame.ScrollContainer, "Child", gameFrame(nil, "Frame", G.WorldMapFrame.ScrollContainer))
for _, n in ipairs({ "ReputationFrame", "SkillFrame", "HonorFrame", "PVPFrame", "PetPaperDollFrame", "TokenFrame" }) do
  G[n] = gameFrame(n, "Frame", G.CharacterFrame); S[G[n]].shown = false
end
-- the character sheet's equipment slots
for _, s in ipairs({ "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist", "Legs", "Feet",
  "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" }) do
  local n = "Character" .. s .. "Slot"
  G[n] = gameFrame(n, "Button", G.PaperDollFrame)
end
for _, n in ipairs({ "SendMailNameEditBox", "SendMailSubjectEditBox" }) do G[n] = gameFrame(n, "EditBox", G.SendMailFrame); S[G[n]].text = "" end
G.QuestLogListScrollFrameScrollBar = gameFrame("QuestLogListScrollFrameScrollBar", "Slider", G.QuestLogFrame)
for i = 1, 13 do G["ContainerFrame" .. i] = gameFrame("ContainerFrame" .. i, "Frame", G.UIParent); S[G["ContainerFrame" .. i]].shown = false end
for i = 1, 6 do G["QuestLogTitle" .. i] = gameFrame("QuestLogTitle" .. i, "Button", G.QuestLogFrame) end
for _, n in ipairs({ "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge", "GameFontHighlight", "GameFontHighlightSmall",
  "GameFontHighlightLarge", "GameFontDisable", "GameFontDisableSmall", "GameFontGreen", "GameFontRed", "GameFontWhite",
  "ChatFontNormal", "NumberFontNormal", "SystemFont_Shadow_Small", "GameFontNormalHuge", "GameFontHighlightMedium", "QuestFont" }) do
  G[n] = G.CreateFont(n); S[G[n]].owned = true; setmetatable(G[n], OwnedMT)
end

-- ---------------------------------------------------------------------------
-- Lua extras the game adds
-- ---------------------------------------------------------------------------
local function strsplit(delim, s, pieces)
  s = tostring(s)
  local out, start = {}, 1
  local pat = "[" .. tostring(delim):gsub("[%]%^%-%%]", "%%%0") .. "]"
  while true do
    if pieces and #out == pieces - 1 then out[#out + 1] = s:sub(start) break end
    local a, b = s:find(pat, start)
    if not a then out[#out + 1] = s:sub(start) break end
    out[#out + 1] = s:sub(start, a - 1)
    start = b + 1
  end
  return unpack(out)
end
local function strtrim(s, chars)
  s = tostring(s)
  if not chars then return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  local c = "[" .. chars:gsub("[%]%^%-%%]", "%%%0") .. "]"
  return (s:gsub("^" .. c .. "+", ""):gsub(c .. "+$", ""))
end
local function strjoin(sep, ...) local t = { ... }; for i = 1, select("#", ...) do t[i] = tostring(t[i]) end return table.concat(t, sep) end
local function wipe(t) for k in pairs(t) do t[k] = nil end return t end
string.split, string.trim, string.join = strsplit, strtrim, strjoin
table.wipe = wipe

local function bitop(a, b, f)
  a, b = math.floor(a or 0) % 4294967296, math.floor(b or 0) % 4294967296
  local r, p = 0, 1
  for _ = 1, 32 do
    local x, y = a % 2, b % 2
    if f(x, y) then r = r + p end
    a, b, p = (a - x) / 2, (b - y) / 2, p * 2
  end
  return r
end
G.bit = {
  band = function(a, b) return bitop(a, b, function(x, y) return x == 1 and y == 1 end) end,
  bor = function(a, b) return bitop(a, b, function(x, y) return x == 1 or y == 1 end) end,
  bxor = function(a, b) return bitop(a, b, function(x, y) return x ~= y end) end,
  bnot = function(a) return 4294967295 - (math.floor(a) % 4294967296) end,
  lshift = function(a, n) return (math.floor(a) * 2 ^ n) % 4294967296 end,
  rshift = function(a, n) return math.floor((math.floor(a) % 4294967296) / 2 ^ n) end,
}

for _, k in ipairs({ "assert", "collectgarbage", "error", "gcinfo", "getfenv", "getmetatable", "ipairs", "next", "pairs",
  "pcall", "rawequal", "rawget", "rawset", "select", "setfenv", "setmetatable", "tonumber", "tostring", "type", "unpack",
  "xpcall", "coroutine", "math", "string", "table", "newproxy" }) do G[k] = _G[k] end
G.strsplit, G.strtrim, G.strjoin, G.wipe = strsplit, strtrim, strjoin, wipe
G.tinsert, G.tremove, G.sort, G.getn, G.tContains = table.insert, table.remove, table.sort, table.getn, function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
G.format, G.gsub, G.strfind, G.strmatch, G.strsub, G.strlen, G.strlower, G.strupper, G.strrep, G.strbyte, G.strchar, G.strrev, G.gmatch =
  string.format, string.gsub, string.find, string.match, string.sub, string.len, string.lower, string.upper, string.rep, string.byte, string.char, string.reverse, string.gmatch
G.abs, G.ceil, G.floor, G.max, G.min, G.sqrt, G.random, G.fastrandom, G.mod, G.exp, G.log, G.log10 =
  math.abs, math.ceil, math.floor, math.max, math.min, math.sqrt, math.random, math.random, math.fmod, math.exp, math.log, math.log10
G.tostringall = function(...) local t = { ... }; for i = 1, select("#", ...) do t[i] = tostring(t[i]) end return unpack(t, 1, select("#", ...)) end
G.print = function(...) local t = { G.tostringall(...) }; W.chat[#W.chat + 1] = table.concat(t, " ") end
G.loadstring = function(src, name) local f, err = loadstring(src, name); if f then setfenv(f, E) end return f, err end
G.debugstack = function() return debug.traceback("", 2) end
-- the game's default handler shows the error; the harness has already recorded it, so it does nothing
local defaultHandler = function() end
W.errorHandler = defaultHandler
G.geterrorhandler = function() return W.errorHandler end
G.seterrorhandler = function(h) if type(h) ~= "function" then error("Usage: seterrorhandler(errfunc)", 2) end W.errorHandler = h end
G.issecretvalue = function() return false end
G.securecall = function(fn, ...) if type(fn) == "string" then fn = G[fn] end return fn(...) end
-- pcall and xpcall as the add-on sees them: the same, except that a caught error is noted (W.swallow)
local rawpcall, rawxpcall = pcall, xpcall
G.pcall = function(f, ...)
  local r = pack(rawpcall(f, ...))
  if not r[1] then W.swallow(r[2], where(2)) end
  return unpack(r, 1, r.n)
end
G.xpcall = function(f, handler, ...)
  local a = pack(...)
  local loc = where(2)
  return rawxpcall(function() return f(unpack(a, 1, a.n)) end, function(e)
    W.swallow(e, loc)
    if handler then return handler(e) end
    return e
  end)
end

local hookedGlobals = {}
function W.hookedGlobals() return hookedGlobals end
G.hooksecurefunc = function(a, b, c)
  local t, name, hook = G, a, b
  if type(a) == "table" then t, name, hook = a, b, c end
  local orig = t[name]
  if type(orig) ~= "function" then error("hooksecurefunc(): " .. tostring(name) .. " is not a function", 2) end
  if t == G then hookedGlobals[#hookedGlobals + 1] = name end
  rawset(t, name, function(...)
    local r = { orig(...) }
    W.call("hook of " .. tostring(name), hook, ...)
    return unpack(r)
  end)
end

-- Mixins and small value types
G.Mixin = function(obj, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do obj[k] = v end end return obj end
G.CreateFromMixins = function(...) return G.Mixin({}, ...) end
G.BackdropTemplateMixin = {}
local ColorMixin = {}
function ColorMixin:GetRGB() return self.r, self.g, self.b end
function ColorMixin:GetRGBA() return self.r, self.g, self.b, self.a end
function ColorMixin:GenerateHexColor() return string.format("ff%02x%02x%02x", self.r * 255, self.g * 255, self.b * 255) end
function ColorMixin:GenerateHexColorMarkup() return "|c" .. self:GenerateHexColor() end
function ColorMixin:WrapTextInColorCode(t) return "|c" .. self:GenerateHexColor() .. tostring(t) .. "|r" end
function ColorMixin:SetRGB(r, g, b) self.r, self.g, self.b = r, g, b end
function ColorMixin:SetRGBA(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
G.ColorMixin = ColorMixin
G.CreateColor = function(r, g, b, a) return G.Mixin({ r = r or 0, g = g or 0, b = b or 0, a = a or 1 }, ColorMixin) end
local Vec = {}
Vec.__index = Vec
function Vec:GetXY() return self.x, self.y end
function Vec:SetXY(x, y) self.x, self.y = x, y end
function Vec:Clone() return G.CreateVector2D(self.x, self.y) end
G.CreateVector2D = function(x, y) return setmetatable({ x = x or 0, y = y or 0 }, Vec) end
G.UiMapPoint = { CreateFromCoordinates = function(m, x, y, z) return { uiMapID = m, position = G.CreateVector2D(x, y), z = z } end,
  CreateFromVector2D = function(m, v) return { uiMapID = m, position = v } end }
G.ItemLocation = {}
function G.ItemLocation:CreateFromBagAndSlot(bag, slot)
  local l = { bag = bag, slot = slot }
  function l:IsValid() return false end
  function l:GetBagAndSlot() return bag, slot end
  function l:IsBagAndSlot() return true end
  return l
end
function G.ItemLocation:CreateFromEquipmentSlot(slot)
  local l = { equip = slot }
  function l:IsValid() return false end
  function l:IsEquipmentSlot() return true end
  return l
end

-- ---------------------------------------------------------------------------
-- The character, the world and the rest of the API
-- ---------------------------------------------------------------------------
local CLASSES = { WARRIOR = { "Warrior", 1 }, PALADIN = { "Paladin", 2 }, HUNTER = { "Hunter", 3 }, ROGUE = { "Rogue", 4 },
  PRIEST = { "Priest", 5 }, SHAMAN = { "Shaman", 7 }, MAGE = { "Mage", 8 }, WARLOCK = { "Warlock", 9 }, DRUID = { "Druid", 11 } }
local RACES = { -- token = { name, id, faction, starting map }
  Orc = { "Orc", 2, "Horde", 1411 }, Scourge = { "Undead", 5, "Horde", 1420 }, Tauren = { "Tauren", 6, "Horde", 1412 },
  Troll = { "Troll", 8, "Horde", 1411 }, Human = { "Human", 1, "Alliance", 1429 }, Dwarf = { "Dwarf", 3, "Alliance", 1426 },
  NightElf = { "Night Elf", 4, "Alliance", 1438 }, Gnome = { "Gnome", 7, "Alliance", 1426 }, Skyborne = { "Skyborne", 90, nil, 1420 },
}
W.CLASSES, W.RACES = CLASSES, RACES
local me = {}
W.me = me

function W.setup(o)
  me.class = (o.class or "PALADIN"):upper()
  if not CLASSES[me.class] then error("unknown class " .. tostring(o.class) .. " (one of WARRIOR PALADIN HUNTER ROGUE PRIEST SHAMAN MAGE WARLOCK DRUID)") end
  me.race = o.race or "Scourge"
  if me.race == "Undead" then me.race = "Scourge" end
  if not RACES[me.race] then error("unknown race " .. tostring(o.race) .. " (one of Orc Scourge Tauren Troll Human Dwarf NightElf Gnome Skyborne)") end
  me.faction = o.faction or RACES[me.race][3] or "Horde"
  me.level = tonumber(o.level) or 1
  me.map = tonumber(o.map) or RACES[me.race][4]
  me.name, me.realm = o.name or "Tester", "Harness"
  me.money = tonumber(o.money) or 0
  me.version = o.version
end

local function isMe(u) return u == "player" or u == me.name end
G.UnitName = function(u) if isMe(u) then return me.name, nil end end
G.UnitFullName = function(u) if isMe(u) then return me.name, me.realm end end
G.UnitGUID = function(u) if isMe(u) then return "Player-0000-00000001" end end
G.UnitClass = function(u) if isMe(u) then local c = CLASSES[me.class]; return c[1], me.class, c[2] end end
G.UnitClassBase = function(u) if isMe(u) then return me.class, CLASSES[me.class][2] end end
G.UnitRace = function(u) if isMe(u) then local r = RACES[me.race]; return r[1], me.race, r[2] end end
G.UnitFactionGroup = function(u) if isMe(u) then return me.faction, me.faction end end
G.UnitLevel = function(u) if isMe(u) then return me.level end return 0 end
G.UnitEffectiveLevel = G.UnitLevel
G.UnitSex = function(u) if isMe(u) then return 2 end end
G.UnitExists = function(u) return isMe(u) end
G.UnitIsPlayer = function(u) return isMe(u) end
G.UnitIsUnit = function(a, b) return a == b or (isMe(a) and isMe(b)) end
G.UnitIsConnected = function(u) return isMe(u) end
G.UnitXP = function() return 0 end
G.UnitXPMax = function() return 400 + me.level * 100 end
G.UnitHealth = function(u) if isMe(u) then return 100 end return 0 end
G.UnitHealthMax = G.UnitHealth
G.UnitPower = G.UnitHealth
G.UnitPowerMax = G.UnitHealth
G.UnitStat = function() return 20, 20, 0, 0 end
G.UnitClassification = function() return "normal" end
G.UnitCreatureType = function() return nil end
G.UnitAura = function() return nil end
G.UnitBuff, G.UnitDebuff = G.UnitAura, G.UnitAura
G.GetUnitSpeed = function() return 0, 7, 7, 4.72 end
G.GetPlayerFacing = function() return 0 end
G.GetMoney = function() return me.money end
G.GetMaxPlayerLevel = function() return 60 end
G.GetXPExhaustion = function() return nil end
G.GetRealmName = function() return me.realm end
G.GetNormalizedRealmName = function() return me.realm end
G.GetLocale = function() return "enUS" end
G.GetCurrentRegion = function() return 1 end
G.GetBuildInfo = function() return "1.16.0", "99999", "Nov 1 2026", 16000 end
G.InCombatLockdown = function() return W.combat end
G.UnitAffectingCombat = function(u) return isMe(u) and W.combat end
G.CombatLogGetCurrentEventInfo = function()
  return G.GetTime(), "SWING_DAMAGE", false, G.UnitGUID("player"), me.name, 0x511, 0, "Creature-0-0-0-0-6-0000000001", "Kobold Vermin", 0xa48, 0, 10
end
G.IsInInstance = function() return false, "none" end
G.GetInstanceInfo = function() return "Azeroth", "none", 0, "", 0, 0, false, 0, 0, nil end
G.GetZoneText = function() return "Harness Zone" end
G.GetRealZoneText = G.GetZoneText
G.GetSubZoneText = function() return "" end
G.GetMinimapZoneText = G.GetZoneText
G.GetBindLocation = function() return "Harness Inn" end
G.GetGuildInfo = function() return nil end
G.IsInGuild = function() return false end
G.IsInGroup = function() return false end
G.IsInRaid = function() return false end
G.GetNumGroupMembers = function() return 0 end
G.GetCVar = function(k) return W.cvars[k] end
G.GetCVarBool = function(k) return W.cvars[k] == "1" end
G.SetCVar = function(k, v) W.cvars[k] = v ~= nil and tostring(v) or nil; return true end
W.cvars = {}
G.ReloadUI = function() W.chat[#W.chat + 1] = "[harness] ReloadUI() was called" end
G.PlaySound = function() return true, 1 end
G.PlaySoundFile = function() return true, 1 end
G.StopSound = function() end
G.GetChannelName = function() return 0, nil end
G.GetChannelList = function() return end
G.JoinChannelByName = function() return 1 end
G.LeaveChannelByName = function() end
G.SendChatMessage = function() end
G.SendAddonMessage = function() return true end
G.IsShiftKeyDown = function() return W.mods.shift end
G.IsControlKeyDown = function() return W.mods.ctrl end
G.IsAltKeyDown = function() return W.mods.alt end
G.IsModifierKeyDown = function() return W.mods.shift or W.mods.ctrl or W.mods.alt end
G.IsModifiedClick = function(what) if what == "DRESSUP" then return W.mods.ctrl end return W.mods.shift end
G.GetBindingKey = function() return nil end
G.GetBindingAction = function() return "" end
G.GetAddOnMetadata = function(name, field) if name == "Waypath" and field == "Version" then return me.version end end
W.otherAddons = {}   -- other add-ons a check says are loaded (e.g. the old "RetGear")
G.IsAddOnLoaded = function(name) return name == "Waypath" or W.otherAddons[name] == true end
G.GetItemCount = function() return 0 end
G.GetItemInfo = function() return nil end             -- nothing is in the item cache at login
G.GetItemInfoInstant = function(id)
  id = tonumber(id) or tonumber(tostring(id):match("item:(%d+)"))
  if id then return id, "Miscellaneous", "Junk", "", 134400, 15, 0 end
end
G.GetItemIcon = function() return 134400 end
G.GetInventoryItemLink = function() return nil end
G.GetInventoryItemID = function() return nil end
G.GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end
G.GetContainerNumFreeSlots = function(bag) return bag == 0 and 16 or 0, 0 end
G.GetNumQuestLogEntries = function() return 0, 0 end
G.GetQuestLogTitle = function() return nil end
G.GetQuestMoneyToGet = function() return 0 end
G.GetNumSkillLines = function() return 0 end
G.GetProfessions = function() return nil end
G.GetSpellInfo = function() return nil end
G.IsSpellKnown = function() return false end
G.IsPlayerSpell = function() return false end
G.GetCoinTextureString = function(c) return tostring(c or 0) .. "c" end
G.BreakUpLargeNumbers = function(n) return tostring(n) end
G.GetFrameCPUUsage = function() return 0, 0 end
G.GetFunctionCPUUsage = function() return 0, 0 end
G.GetAddOnCPUUsage = function() return 0 end
G.GetAddOnMemoryUsage = function() return collectgarbage("count") end
G.StaticPopupDialogs = {}
G.StaticPopup_Show = function(which) if G.StaticPopupDialogs[which] then return G.CreateFrame("Frame") end end
G.StaticPopup_Hide = function() end
G.UISpecialFrames = {}
G.SlashCmdList = {}
G.ChatFrameUtil = {}
G.ShowUIPanel = function(f) if f and f.Show then f:Show() end end
G.HideUIPanel = function(f) if f and f.Hide then f:Hide() end end
local postCalls = {}
function W.tooltipPostCalls() return postCalls end
G.TooltipDataProcessor = apiTable("TooltipDataProcessor", {
  AddTooltipPostCall = function(ty, fn) postCalls[#postCalls + 1] = { type = ty, fn = fn } end,
  AddLinePostCall = function() end,
})
G.SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
G.NUM_CHAT_WINDOWS, G.QUESTS_DISPLAYED, G.QUESTLOG_QUEST_HEIGHT, G.ATTACHMENTS_MAX_SEND, G.LE_PARTY_CATEGORY_INSTANCE = 10, 6, 16, 12, 2
G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
G.YES, G.NO, G.ACCEPT, G.CANCEL, G.LATER, G.RELOADUI, G.OKAY, G.CLOSE = "Yes", "No", "Accept", "Cancel", "Later", "Reload UI", "Okay", "Close"
G.LOOT_ITEM_SELF = "You receive loot: %s."
G.FACTION_STANDING_CHANGED = "You are now %s with %s."
G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
G.AUCTION_EXPIRED_MAIL_SUBJECT = "Auction expired: %s"
G.ITEM_SOULBOUND, G.ITEM_BIND_ON_PICKUP, G.ITEM_BIND_QUEST = "Soulbound", "Binds when picked up", "Quest Item"
G.ITEM_BIND_TO_ACCOUNT, G.ITEM_BIND_TO_BNETACCOUNT, G.ITEM_BNETACCOUNTBOUND = "Binds to account", "Binds to Blizzard account", "Blizzard Account Bound"
G.ITEM_ACCOUNTBOUND, G.ITEM_ACCOUNTBOUND_UNTIL_EQUIP = "Warbound", "Warbound until equipped"
for i = 1, 8 do G["FACTION_STANDING_LABEL" .. i] = ({ "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" })[i] end
G.ITEM_QUALITY_COLORS = {}
for q, hex in pairs({ [0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000", "e6cc80", "00ccff" }) do
  local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
  G.ITEM_QUALITY_COLORS[q] = { r = r, g = g, b = b, hex = "|cff" .. hex, color = G.CreateColor(r, g, b) }
end
G.GetItemQualityColor = function(q)
  local c = G.ITEM_QUALITY_COLORS[q] or G.ITEM_QUALITY_COLORS[1]
  return c.r, c.g, c.b, c.hex:sub(3)
end
G.RAID_CLASS_COLORS = {}
for k in pairs(CLASSES) do
  local c = G.CreateColor(1, 1, 1); c.colorStr = "ffffffff"
  G.RAID_CLASS_COLORS[k] = c
end
G.Enum = {
  ItemQuality = { Poor = 0, Common = 1, Standard = 1, Uncommon = 2, Good = 2, Rare = 3, Superior = 3, Epic = 4, Legendary = 5, Artifact = 6, Heirloom = 7 },
  TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4, Currency = 5, Macro = 25, Quest = 23 },
  ItemClass = { Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Reagent = 5, Projectile = 6, Tradegoods = 7, Recipe = 9, Quiver = 11, Questitem = 12, Key = 13, Miscellaneous = 15 },
  InventoryType = setmetatable({}, { __index = function() return 0 end }),
  BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, Bank = -1 },
  UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 },
  QuestTag = setmetatable({}, { __index = function() return 0 end }),
}

-- API tables
G.C_Map = apiTable("C_Map", {
  GetBestMapForUnit = function(u) if isMe(u) then return me.map end end,
  GetPlayerMapPosition = function(m, u) if isMe(u) then return G.CreateVector2D(0.5, 0.5) end end,
  GetWorldPosFromMapPos = function(m, pos) return 1, G.CreateVector2D(pos and pos.x or 0, pos and pos.y or 0) end,
  GetMapPosFromWorldPos = function(c, pos, m) return m, G.CreateVector2D(0.5, 0.5) end,
  GetMapInfo = function(m) if m then return { mapID = m, name = "Map " .. m, mapType = 3, parentMapID = 1414 } end end,
  GetMapChildrenInfo = function() return {} end,
  GetMapGroupID = function() return nil end,
  CanSetUserWaypointOnMap = function() return true end,
  HasUserWaypoint = function() return false end,
  GetUserWaypoint = function() return nil end,
})
G.C_QuestLog = apiTable("C_QuestLog", {
  GetNumQuestLogEntries = function() return 0, 0 end,
  GetInfo = function() return nil end,
  IsComplete = function() return false end,
  IsOnQuest = function() return false end,
  GetQuestObjectives = function() return {} end,
  IsQuestFlaggedCompleted = function() return false end,
  GetLogIndexForQuestID = function() return nil end,
  GetQuestIDForLogIndex = function() return nil end,
  GetMaxNumQuestsCanAccept = function() return 25 end,
  GetTitleForQuestID = function() return nil end,
})
G.C_Item = apiTable("C_Item", {
  GetItemInfo = G.GetItemInfo, GetItemInfoInstant = G.GetItemInfoInstant, GetItemCount = G.GetItemCount, GetItemIconByID = G.GetItemIcon,
  RequestLoadItemDataByID = function() end, IsItemDataCachedByID = function() return false end, DoesItemExistByID = function() return true end,
  GetItemNameByID = function() return nil end, GetItemQualityByID = function() return nil end,
})
G.C_Container = apiTable("C_Container", { GetContainerNumSlots = G.GetContainerNumSlots, GetContainerNumFreeSlots = G.GetContainerNumFreeSlots,
  GetContainerItemInfo = function() return nil end, GetContainerItemLink = function() return nil end, GetContainerItemID = function() return nil end })
G.C_AddOns = apiTable("C_AddOns", { IsAddOnLoaded = G.IsAddOnLoaded, GetAddOnMetadata = G.GetAddOnMetadata, GetNumAddOns = function() return 1 end,
  GetAddOnInfo = function(i) if i == 1 or i == "Waypath" then return "Waypath", "Waypath+", "", true, "INSECURE", false end end,
  LoadAddOn = function() return false, "MISSING" end, DoesAddOnExist = function(n) return n == "Waypath" end,
  GetAddOnEnableState = function(n) return n == "Waypath" and 2 or 0 end, DisableAddOn = function() end, EnableAddOn = function() end })
local prefixes = {}
function W.prefixes() local t = {}; for p in pairs(prefixes) do t[#t + 1] = p end table.sort(t) return t end
G.C_ChatInfo = apiTable("C_ChatInfo", { RegisterAddonMessagePrefix = function(p) prefixes[p] = true; return true end,
  IsAddonMessagePrefixRegistered = function(p) return prefixes[p] or false end,
  SendAddonMessage = function() return true end, GetChannelRosterInfo = function() return nil end })
G.C_DateAndTime = apiTable("C_DateAndTime", { GetCurrentCalendarTime = function()
  local d = os.date("*t", G.time()); return { year = d.year, month = d.month, monthDay = d.day, weekday = d.wday, hour = d.hour, minute = d.min }
end, GetServerTimeLocal = function() return G.time() end })
G.C_Calendar = apiTable("C_Calendar", { GetNumDayEvents = function() return 0 end, GetDate = function() return G.C_DateAndTime.GetCurrentCalendarTime() end,
  GetMonthInfo = function() local d = os.date("*t", G.time()); return { month = d.month, year = d.year, numDays = 30, firstWeekday = 1 } end })
G.C_Spell = apiTable("C_Spell", { GetSpellInfo = function() return nil end, GetSpellName = function() return nil end, IsSpellDataCached = function() return false end })
G.C_Minimap = apiTable("C_Minimap")
for _, n in ipairs({ "C_AuctionHouse", "C_GossipInfo", "C_TradeSkillUI", "C_ClassTalents", "C_Traits", "C_MerchantFrame", "C_EncounterJournal",
  "C_UnitAuras", "C_TooltipInfo", "C_TaxiMap", "C_SpellBook", "C_SpecializationInfo", "C_Reputation", "C_QuestLine", "C_DeathInfo",
  "C_CreatureInfo", "C_TaskQuest", "C_SuperTrack", "C_FriendList", "C_AreaPoiInfo", "C_CVar", "C_PlayerInfo", "C_CurrencyInfo",
  "C_NewItems", "C_Timer_", "C_Navigation", "C_VignetteInfo", "C_PartyInfo", "C_LFGList", "C_Housing", "C_Engraving", "C_Seasons" }) do
  if not G[n] then G[n] = apiTable(n) end
end
G.C_Timer_ = nil

-- Every other API function the add-on reads. They return the generic answer (0, false or nil): enough for an empty
-- character at login. A name the add-on reads that is in neither list is reported as unknown (it reads nil, as an
-- API the game doesn't have would).
local GENERIC = [[
AbandonQuest AcceptQuest AcknowledgeAutoAcceptQuest BuyMerchantItem BuybackItem CanMerchantRepair CanSendAuctionQuery
ChatEdit_ActivateChat ChatEdit_GetActiveWindow ChatEdit_InsertLink ChatFrame_AddMessageEventFilter ChatFrame_OpenChat
ChatFrame_RemoveChannel ClearCursor ClearOverrideBindings ClickSendMailItemButton CompleteQuest CursorHasItem DeleteMacro
DisableAddOn DoTradeSkill DressUpItemLink EquipItemByName ExpandQuestHeader GetAchievementCriteriaInfo
GetAchievementCriteriaInfoByID GetAchievementInfo GetAchievementNumCriteria GetActiveQuestID GetActiveTitle GetAuctionItemInfo
GetAuctionItemLink GetAvailableQuestInfo GetAvailableTitle GetBattlefieldWinner GetBuybackItemLink GetContainerItemInfo
GetContainerItemLink GetCorpseMapPosition GetCraftDisplaySkillLine GetCraftInfo GetCraftItemLink GetCraftNumReagents
GetCraftReagentInfo GetCraftReagentItemLink GetDetailedItemLevelInfo GetFactionInfoByID GetInboxHeaderInfo GetInboxInvoiceInfo
GetItemCooldown GetLootSlotInfo GetLootSlotLink GetLootSourceInfo GetMacroIndexByName GetMerchantItemID
GetMerchantItemInfo GetMerchantItemLink GetMerchantItemMaxStack GetPlayerInfoByGUID GetProfessionInfo GetQuestID
GetQuestItemInfo GetQuestItemLink GetQuestLink GetQuestLogIndexByID GetQuestLogSelection GetQuestLogSpecialItemInfo
GetQuestMoneyToGet GetQuestReward GetRaidRosterInfo GetRepairAllCost GetSkillLineInfo GetStatistic GetTalentInfo GetTaxiMapID
GetTitleText GetTradeSkillInfo GetTradeSkillItemLink GetTradeSkillLine GetTradeSkillNumMade GetTradeSkillNumReagents
GetTradeSkillReagentInfo GetTradeSkillReagentItemLink GetUnspentTalentPoints GetWeaponEnchantInfo IsFishingLoot IsFlying
IsIndoors IsQuestCompletable IsQuestRepeatable IsResting IsUnitOnQuest IsUsableItem JoinChannelByName PickupContainerItem
QueryAuctionItems QuestGetAutoAccept QuestLogPushQuest QuestLog_SetSelection QuestLog_Update QuestMapFrame_OpenToQuestDetails
QuestPOIGetIconInfo RepairAllItems SelectActiveQuest SelectAvailableQuest SelectQuestLogEntry SelectTradeSkill SetAbandonQuest
SetOverrideBinding SetOverrideBindingClick TaxiNodeGetType TaxiNodeName ToggleCharacter ToggleQuestLog ToggleTalentFrame
UnitCanAttack UnitChannelInfo UnitCharacterPoints UnitIsAFK UnitIsDead UnitIsDeadOrGhost UnitIsGhost UnitIsTapDenied UnitOnTaxi
UpdateAddOnCPUUsage UpdateAddOnMemoryUsage GetNumActiveQuests GetNumAvailableQuests GetNumAuctionItems GetNumBuybackItems
GetNumCrafts GetNumLootItems GetNumQuestChoices GetNumQuestRewards GetNumTalentGroups GetNumTalentTabs GetNumTalents
GetNumTradeSkills GetMerchantNumItems GetInboxNumItems NumTaxiNodes GetActiveTalentGroup GetQuestsCompleted
ContainerFrame_Update OpenAllBags OpenBackpack OpenBag ToggleAllBags ToggleBackpack ToggleBag CloseAllBags QuestLogTitleButton_OnClick
]]
for n in GENERIC:gmatch("%S+") do if G[n] == nil then G[n] = generic(n) end end

-- Not there at login on WoW Forever (other add-ons, load-on-demand windows): read as nil without a report.
for n in ([[
Questie TomTom Auctionator TSM_API ShortestPathForever AuctionHouseFrame AuctionFrame BrowseName AuctionFrameBrowse_Search
PlayerTalentFrame PlayerTalentFrame_Toggle QUEST_TRACKER_MODULE RetGearDB WaypathDB ElvUI Bagnon AdiBags ArkInventory
Baganator Questie_BaseFrame QuestieLoader EditModeManagerFrame QuestMapLogTitleButton_OnClick QuestLogQuests_OnClick
QuestObjectiveTracker_OnOpenDropDown WatchFrameLinkButtonTemplate_OnClick
]]):gmatch("%S+") do ABSENT[n] = true end

-- ---------------------------------------------------------------------------
-- The add-on's environment
-- ---------------------------------------------------------------------------
local function ownName(k) return type(k) == "string" and (k:find("^Waypath") or k:find("^SLASH_") or k:find("^BINDING_")) end
E = setmetatable({}, {
  __index = function(_, k)
    local v = G[k]
    if v ~= nil then return v end
    if type(k) == "string" and not ABSENT[k] and not ownName(k) and not W.unknown[k] then W.unknown[k] = where(2) end
  end,
  __newindex = function(_, k, v)
    if OWNED[k] then addTaint("global", tostring(k), where(2)) end
    G[k] = v
  end,
})
G._G = E
W.E = E

-- Called once everything above is defined: from here on, writing any of these names is taint.
function W.seal()
  for k in pairs(G) do OWNED[k] = true end
  OWNED._G = nil
end

-- Load one of the add-on's files the way the game does: its own chunk, (addonName, addonTable) as `...`,
-- and a runtime error in it stops that file only.
function W.loadFile(root, path, addonName, ns)
  local fh = io.open(root .. "/" .. path, "rb")
  if not fh then addError("file listed in the TOC is missing", path, "") return false end
  local src = fh:read("*a"); fh:close()
  if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
  local chunk, err = loadstring(src, "@" .. W.PREFIX .. path)
  if not chunk then addError(W.short(err), path, "") return false end
  setfenv(chunk, E)
  return W.call("loading " .. path, chunk, addonName, ns)
end

-- Every piece of text showing on a frame and everything inside it (font strings, in creation order), for checks.
function W.visibleTexts(f, out)
  out = out or {}
  local st = f and S[f]
  if not st or not visible(f) then return out end
  for _, r in ipairs(st.regions) do
    local rs = S[r]
    if rs and rs.type == "FontString" and rs.shown and rs.text and rs.text ~= "" then out[#out + 1] = rs.text end
  end
  for _, c in ipairs(st.children) do W.visibleTexts(c, out) end
  return out
end

-- JSON for a value (arrays, string-keyed tables, strings, numbers, booleans), for the audit tools
function W.json(v)
  local t = type(v)
  if t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"' end
  if t == "number" or t == "boolean" then return tostring(v) end
  if t ~= "table" then return "null" end
  if #v > 0 or next(v) == nil then local p = {}; for i, x in ipairs(v) do p[i] = W.json(x) end return "[" .. table.concat(p, ",") .. "]" end
  local p = {}
  for k, x in pairs(v) do p[#p + 1] = W.json(tostring(k)) .. ":" .. W.json(x) end
  return "{" .. table.concat(p, ",") .. "}"
end

-- Lua source for a value (tables, strings, numbers, booleans; functions and cycles are left out)
function W.serialize(v)
  local seen = {}
  local function ser(x, ind)
    local t = type(x)
    if t == "string" then return string.format("%q", x) end
    if t == "number" or t == "boolean" or t == "nil" then return tostring(x) end
    if t ~= "table" or seen[x] then return "nil" end
    seen[x] = true
    local keys = {}
    for k in pairs(x) do if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) if type(a) == type(b) then return a < b end return type(a) == "number" end)
    local parts = {}
    for _, k in ipairs(keys) do
      local kv = type(k) == "number" and ("[" .. k .. "]") or ("[" .. string.format("%q", k) .. "]")
      local val = x[k]
      if type(val) ~= "function" and type(val) ~= "userdata" and type(val) ~= "thread" then parts[#parts + 1] = ind .. "  " .. kv .. " = " .. ser(val, ind .. "  ") .. ",\n" end
    end
    seen[x] = nil
    return "{\n" .. table.concat(parts) .. ind .. "}"
  end
  return ser(v, "")
end

-- Slash commands: what the game does when you type "/wp next" in chat.
function W.slashNames()
  local t = {}
  for k, v in pairs(G) do if type(k) == "string" and k:find("^SLASH_") and type(v) == "string" then t[#t + 1] = v:lower() end end
  table.sort(t)
  return t
end
function W.slash(text)
  local cmd, rest = text:match("^(/%S+)%s*(.*)$")
  if not cmd then return false end
  for k, v in pairs(G) do
    if type(k) == "string" and type(v) == "string" and k:find("^SLASH_") and v:lower() == cmd:lower() then
      local key = k:match("^SLASH_(.-)%d+$")
      local fn = key and G.SlashCmdList[key]
      if fn then return W.call(text, fn, rest, G.ChatFrame1EditBox) end
    end
  end
  addError("there is no slash command " .. cmd, "?", "")
  return false
end

-- A load-on-demand window appears when its Blizzard add-on loads (the driver fires that ADDON_LOADED).
function W.makeGameFrame(name)
  if G[name] == nil then
    local f = newWidget("Frame", name, G.UIParent, true)
    S[f].shown = false
    ABSENT[name] = nil
  end
end

-- Saved variables: the game sets them after the files have run and just before ADDON_LOADED.
function W.setSaved(name, value) G[name] = value end
function W.getSaved(name) return G[name] end

return W
