-- Waypath+ learned paths: the arrow normally points straight at its target, which is wrong
-- when a mountain, cliff or cave entrance is in the way. Waypath+ quietly remembers where
-- you walk (a thin trail of points, shared by all your characters). When the arrow notices
-- you are not getting closer, it switches to the way you have gone before and leads you
-- point by point until the straight line is open again.
local _, RG = ...

local CELL, MERGE, MAXN = 40, 12, 20000
local nodes = {}      -- [i] = { x, y, cont, links = { j, ... } }
local grid = {}       -- "cont:cx:cy" -> { i, ... }
local prev, lastT

local function key(c, x, y) return c .. ":" .. math.floor(x / CELL) .. ":" .. math.floor(y / CELL) end
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by return math.sqrt(dx * dx + dy * dy) end

local function nearest(c, x, y, maxd)
  local best, bd = nil, maxd or MERGE
  local cx, cy = math.floor(x / CELL), math.floor(y / CELL)
  local r = math.ceil(bd / CELL)
  for gx = cx - r, cx + r do
    for gy = cy - r, cy + r do
      for _, i in ipairs(grid[c .. ":" .. gx .. ":" .. gy] or {}) do
        local n = nodes[i]
        local d = dist(n[1], n[2], x, y)
        if d <= bd then best, bd = i, d end
      end
    end
  end
  return best, bd
end

local function addNode(c, x, y)
  if #nodes >= MAXN then return nil end
  local i = #nodes + 1
  nodes[i] = { math.floor(x + 0.5), math.floor(y + 0.5), c, {} }
  local k = key(c, x, y)
  grid[k] = grid[k] or {}; grid[k][#grid[k] + 1] = i
  return i
end
local function link(a, b)
  if a == b or not a or not b then return end
  local la = nodes[a][4]
  for _, j in ipairs(la) do if j == b then return end end
  la[#la + 1] = b; nodes[b][4][#nodes[b][4] + 1] = a
end

-- save compactly: flat list per node { x, y, cont, neighbours... }
local function save()
  if not WaypathDB then return end
  local out = {}
  for i, n in ipairs(nodes) do out[i] = { n[1], n[2], n[3], unpack(n[4]) } end
  WaypathDB.trail = out
end
local function load()
  local t = WaypathDB and WaypathDB.trail
  nodes, grid = {}, {}
  if type(t) ~= "table" then return end
  for i, n in ipairs(t) do
    nodes[i] = { n[1], n[2], n[3], {} }
    local k = key(n[3], n[1], n[2])
    grid[k] = grid[k] or {}; grid[k][#grid[k] + 1] = i
  end
  for i, n in ipairs(t) do for j = 4, #n do nodes[i][4][#nodes[i][4] + 1] = n[j] end end
end
function RG.TrailSize() return #nodes end
function RG.TrailReset() nodes, grid, prev = {}, {}, nil; if WaypathDB then WaypathDB.trail = nil end end

local function here()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetWorldPosFromMapPos) then return end
  local map = C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return end
  local c, wp = C_Map.GetWorldPosFromMapPos(map, pos)
  if not wp then return end
  return c, wp.x, wp.y
end
RG.TrailHere = here

local dirty = 0

-- Sharing: the trail as plain text ("WPT1", then one node per line: x,y,continent and the earlier nodes it
-- links to), so a trail can be copied out, sent to someone, pasted in, or shipped inside the add-on (Paths.lua).
function RG.TrailExport()
  local out = { "WPT1" }
  for i, n in ipairs(nodes) do
    local row = { n[1], n[2], n[3] }
    for _, j in ipairs(n[4]) do if j < i then row[#row + 1] = j end end
    out[#out + 1] = table.concat(row, ",")
  end
  return table.concat(out, "\n")
end
-- Merge a trail in text form. Points that sit on top of ones you already have are joined to them.
-- Returns points added, or nil and a reason.
function RG.TrailImport(text)
  if type(text) ~= "string" then return nil, "nothing to read" end
  local first = true
  local map, count, added = {}, 0, 0
  for line in text:gmatch("[^\r\n]+") do
    if first then
      first = false
      if not line:find("^%s*WPT1") then return nil, "that is not Waypath+ path data (it should start with WPT1)" end
    else
      count = count + 1
      local f = {}
      for v in line:gmatch("%-?%d+") do f[#f + 1] = tonumber(v) end
      if #f >= 3 then
        local x, y, c = f[1], f[2], f[3]
        local cur = nearest(c, x, y, MERGE)
        if not cur then cur = addNode(c, x, y); if cur then added = added + 1 end end
        map[count] = cur
        for k = 4, #f do
          local o = map[f[k]]
          if cur and o and nodes[o] and nodes[o][3] == c and dist(nodes[o][1], nodes[o][2], nodes[cur][1], nodes[cur][2]) < 120 then link(cur, o) end
        end
      end
    end
  end
  dirty = (dirty or 0) + added
  if added > 0 then save() end
  return added
end
local function sample()
  if not (RG.db and RG.db.trail ~= false) then return end
  if (IsFlying and IsFlying()) or (UnitOnTaxi and UnitOnTaxi("player")) or (IsInInstance and IsInInstance()) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then prev = nil return end
  local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
  if RG.IsSecret and RG.IsSecret(speed) then return end
  if speed < 2 then return end
  local c, x, y = here()
  if not c then return end
  local cur = nearest(c, x, y, MERGE)
  if not cur then
    if prev and nodes[prev] and nodes[prev][3] == c and dist(nodes[prev][1], nodes[prev][2], x, y) < 28 then return end
    cur = addNode(c, x, y)
    dirty = dirty + 1
  end
  if prev and cur and nodes[prev] and nodes[prev][3] == c and dist(nodes[prev][1], nodes[prev][2], nodes[cur][1], nodes[cur][2]) < 90 then link(prev, cur) end
  prev = cur
end

-- shortest known way between two points on one continent, as a list of { x, y }; nil if none
function RG.TrailRoute(c, ax, ay, bx, by)
  local s, sd = nearest(c, ax, ay, 80)
  local e, ed = nearest(c, bx, by, 120)
  if not (s and e) then return nil end
  if s == e then return { { nodes[e][1], nodes[e][2] } } end
  local gs, came, open, closed = { [s] = 0 }, {}, { s }, {}
  local steps = 0
  while #open > 0 and steps < 4000 do
    steps = steps + 1
    local bi, bf = 1, nil
    for k, i in ipairs(open) do
      local f = gs[i] + dist(nodes[i][1], nodes[i][2], nodes[e][1], nodes[e][2])
      if not bf or f < bf then bi, bf = k, f end
    end
    local cur = table.remove(open, bi)
    if cur == e then
      local path, n = {}, cur
      while n do table.insert(path, 1, { nodes[n][1], nodes[n][2] }); n = came[n] end
      return path
    end
    closed[cur] = true
    for _, nb in ipairs(nodes[cur][4]) do
      if not closed[nb] then
        local g = gs[cur] + dist(nodes[cur][1], nodes[cur][2], nodes[nb][1], nodes[nb][2])
        if not gs[nb] or g < gs[nb] then
          if not gs[nb] then open[#open + 1] = nb end
          gs[nb], came[nb] = g, cur
        end
      end
    end
  end
  return nil
end

-- Called by the arrow every update. Returns nil to keep pointing straight, or
-- dx, dy (world offset to the point to head for) and a hint.
local st = { key = nil, best = 1e9, since = 0, stuck = false, path = nil, idx = 1, moved = 0 }
function RG.PathTick(c, px, py, tx, ty, d, speed, dt, targetKey)
  if not (RG.db and RG.db.trail ~= false) then return nil end
  if st.key ~= targetKey then st = { key = targetKey, best = d, since = 0, stuck = false, moved = 0 } end
  if speed and speed > 3 then
    st.since = st.since + dt
    if d < st.best - 8 then st.best = d; st.since = 0; if st.stuck and d < (st.stuckAt or 0) - 60 then st.stuck = false; st.path = nil end end
  end
  if not st.stuck and st.since > 7 and d > 40 then
    st.stuck, st.stuckAt = true, d
    st.path = RG.TrailRoute(c, px, py, tx, ty)
    st.idx = 1
  end
  if not st.stuck then return nil end
  if st.path then
    while st.path[st.idx] and dist(px, py, st.path[st.idx][1], st.path[st.idx][2]) < 18 do st.idx = st.idx + 1 end
    local p = st.path[st.idx]
    if p then return p[1] - px, p[2] - py, "Not getting closer: following the way you walked before" end
    st.stuck, st.path = false, nil; st.since = 0
    return nil
  end
  return nil, nil, "Blocked? Find the way round; Waypath+ learns it as you walk and will guide you next time", true
end

-- a small window for copying a trail out or pasting one in
local box
function RG.ShowTrailBox(mode)
  if not box then
    box = CreateFrame("Frame", "WaypathTrailBox", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetSize(560, 380); box:SetPoint("CENTER"); box:SetFrameStrata("DIALOG"); box:SetMovable(true); box:EnableMouse(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", box.StartMoving); box:SetScript("OnDragStop", box.StopMovingOrSizing)
    if RG.DialogBackdrop then RG.DialogBackdrop(box) end
    box.title = RG.NewText(box, "GameFontNormal"); box.title:SetPoint("TOPLEFT", 12, -10)
    local close = CreateFrame("Button", nil, box, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -2, -2)
    box.go = CreateFrame("Button", nil, box, "UIPanelButtonTemplate"); box.go:SetSize(110, 22); box.go:SetPoint("BOTTOMRIGHT", -12, 10); box.go:SetText("Import")
    box.note = RG.NewText(box, "GameFontHighlightSmall"); box.note:SetPoint("BOTTOMLEFT", 12, 14)
    local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -32); sf:SetPoint("BOTTOMRIGHT", -32, 40)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall); eb:SetWidth(500); eb:SetMaxLetters(0)
    eb:SetScript("OnEscapePressed", function() box:Hide() end)
    sf:SetScrollChild(eb); box.eb = eb
    box.go:SetScript("OnClick", function()
      local n, why = RG.TrailImport(eb:GetText())
      if n then box.note:SetText("Added " .. n .. " new points. You now have " .. #nodes .. "."); if RG.Print then RG.Print("Learned paths: added " .. n .. " new points.") end
      else box.note:SetText("|cffff6060" .. tostring(why) .. "|r") end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "WaypathTrailBox") end
  end
  if mode == "export" then
    box.title:SetText("Your learned paths (" .. #nodes .. " points)  ·  Ctrl+A, Ctrl+C to copy")
    box.eb:SetText(RG.TrailExport()); box.go:Hide(); box.note:SetText("")
  else
    box.title:SetText("Paste learned paths here (they must start with WPT1), then press Import")
    box.eb:SetText(""); box.go:Show(); box.note:SetText("")
  end
  box:Show(); box.eb:SetFocus(); if mode == "export" then box.eb:HighlightText() end
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LOGOUT" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    load()
    -- walking routes that ship with the add-on (Paths.lua), merged once per version
    if RG.SHARED_TRAIL and WaypathDB and WaypathDB.sharedTrailV ~= RG.SHARED_TRAIL_V then
      local ok, n = pcall(RG.TrailImport, RG.SHARED_TRAIL)
      if ok then WaypathDB.sharedTrailV = RG.SHARED_TRAIL_V end
    end
    if C_Timer and C_Timer.NewTicker then
      C_Timer.NewTicker(1, function() local ok, err = pcall(sample); if not ok and RG.RecordError then RG.RecordError("Path: " .. tostring(err)) end end)
      C_Timer.NewTicker(120, function() if dirty > 0 then dirty = 0; pcall(save) end end)
    end
  else
    pcall(save)
  end
end)
