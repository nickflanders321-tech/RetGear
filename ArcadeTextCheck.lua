local _, RG = ...
-- /wp textcheck: goes through every page of the cards window in the real game (each tab, every Album set and its
-- pages, the Shop's aisles, the Grading desk and the Guild Ledger, and a few card pages) and lists any text that:
--   * the game cuts short ("..." or a missing line),
--   * runs outside the window,
--   * runs into another text, or into a button it isn't on.
-- It only reads the screen (no buying, no clicks but the window's own page arrows), puts the window back where it was,
-- and shows the list to copy.

local DELAY = 0.12        -- (a page is laid out a moment after it's drawn)
local MAXPAGES = 12       -- (pages of one list, at most)
local running

local function strip(s)
  s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("\n", " ")
  if #s > 46 then s = s:sub(1, 44) .. ".." end
  return s
end
local function visibleText(r)
  if not (r.IsVisible and r:IsVisible()) then return false end
  local t = r:GetText(); if not t or t == "" or not t:find("%S") then return false end
  local p = r:GetParent()
  local a = (r:GetAlpha() or 1) * ((p and p.GetEffectiveAlpha and p:GetEffectiveAlpha()) or 1)
  return a > 0.08
end
-- where a text's letters really are (its own box can be wider than the words in it)
local function textBox(r)
  local L, R, T, B = r:GetLeft(), r:GetRight(), r:GetTop(), r:GetBottom()
  if not (L and R and T and B) then return nil end
  local sw = r:GetStringWidth() or 0
  local sh = r:GetStringHeight() or 0
  local w, h = R - L, T - B
  if sw <= 0 or sh <= 0 then return nil end
  local x0, x1
  local jh = r.GetJustifyH and r:GetJustifyH() or "CENTER"
  if sw >= w then x0, x1 = L, R
  elseif jh == "LEFT" then x0, x1 = L, L + sw
  elseif jh == "RIGHT" then x0, x1 = R - sw, R
  else x0 = L + (w - sw) / 2; x1 = x0 + sw end
  local y0, y1
  local jv = r.GetJustifyV and r:GetJustifyV() or "MIDDLE"
  if sh >= h then y1, y0 = T, B
  elseif jv == "TOP" then y1, y0 = T, T - sh
  elseif jv == "BOTTOM" then y1, y0 = B + sh, B
  else y1 = T - (h - sh) / 2; y0 = y1 - sh end
  -- (letters can run past the box the game was asked for: count what the words need, from the start the box sets)
  local need = r.GetUnboundedStringWidth and r:GetUnboundedStringWidth() or sw
  local over = 0
  if r.CanWordWrap and not r:CanWordWrap() and need > w + 1 and not (r.IsTruncated and r:IsTruncated()) then over = need - w end
  if over > 0 then
    if jh == "LEFT" then x1 = x1 + over elseif jh == "RIGHT" then x0 = x0 - over else x0, x1 = x0 - over / 2, x1 + over / 2 end
  end
  return { x0, y0, x1, y1 }
end
local function hits(a, b, pad)
  pad = pad or 1.5
  return a[1] < b[3] - pad and b[1] < a[3] - pad and a[2] < b[4] - pad and b[2] < a[4] - pad
end
local function within(f, root)
  local x = f
  for _ = 1, 40 do if not x then return false end; if x == root then return true end; x = x:GetParent() end
  return false
end
local function nameOf(b)
  local l = rawget(b, "label")
  local t = l and l.GetText and l:GetText()
  return (t and t ~= "") and strip(t) or "a button"
end

-- one look at one window: every text and every button in it
local function scan(root, where, out)
  if not (root and root:IsVisible()) then return end
  local texts, buttons = {}, {}
  local function walk(f, depth)
    if depth > 30 or not f:IsVisible() then return end
    if rawget(f, "label") and f.IsObjectType and f:IsObjectType("Button") and f:GetWidth() < 420 and f:GetHeight() < 60 then
      local L, R, T, B = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
      if L and R and T and B then buttons[#buttons + 1] = { f = f, box = { L, B, R, T } } end
    end
    for _, r in ipairs({ f:GetRegions() }) do
      if r.GetObjectType and r:GetObjectType() == "FontString" and visibleText(r) then
        local box = textBox(r)
        if box then texts[#texts + 1] = { r = r, box = box, owner = f } end
      end
    end
    for _, c in ipairs({ f:GetChildren() }) do walk(c, depth + 1) end
  end
  walk(root, 0)
  local rL, rR, rT, rB = root:GetLeft(), root:GetRight(), root:GetTop(), root:GetBottom()
  for i, t in ipairs(texts) do
    local s = '"' .. strip(t.r:GetText()) .. '"'
    if t.r.IsTruncated and t.r:IsTruncated() then out(where, s .. " is cut short") end
    local b = t.box
    if rL and (b[1] < rL - 2 or b[3] > rR + 2 or b[2] < rB - 2 or b[4] > rT + 2) then out(where, s .. " runs outside the window") end
    for j = i + 1, #texts do
      local o = texts[j]
      if hits(b, o.box) then out(where, s .. ' runs into "' .. strip(o.r:GetText()) .. '"') end
    end
    for _, bt in ipairs(buttons) do
      if not within(t.owner, bt.f) and hits(b, bt.box) then out(where, s .. " runs into the " .. nameOf(bt.f) .. " button") end
    end
  end
end

RG.ArcadeTextScan = scan   -- (for the add-on's own tests)

function RG.ArcadeTextCheck()
  if running then RG.Print("The text check is already running.") return end
  if InCombatLockdown and InCombatLockdown() then RG.Print("The text check waits until you're out of combat.") return end
  if not (RG.ShowArcade and RG.ArcadeRefresh and C_Timer and C_Timer.After) then return end
  RG.ShowArcade(); RG.ArcadeRefresh(true)
  local v = RG.ArcadeView
  local win = _G.WaypathArcade
  if not (v and win) then RG.Print("Open the cards window once, then try again.") return end
  running = true
  local saved = {}
  for k, x in pairs(v) do saved[k] = x end
  local found, seen, pages = {}, {}, 0
  local function out(where, msg)
    if seen[msg] or #found >= 400 then return end
    seen[msg] = true; found[#found + 1] = where .. ":  " .. msg
  end
  local u = RG.ArcadeUI
  -- the steps: each sets up one page; paged lists then follow the window's own ">" arrow
  local steps = {}
  local function add(label, setup, paged) steps[#steps + 1] = { label = label, setup = setup, paged = paged } end
  local function reset() v.set = nil; v.showcase = false; v.shopSection = nil; v.gradeCert = nil; v.gradeLedger = nil; v.kind = 0; v.page = 1 end
  add("Collection", function() reset(); v.mode = "cards" end, true)
  for k = 1, 4 do add("Collection (" .. ({ "items", "creatures", "places", "raiders" })[k] .. ")", function() reset(); v.mode = "cards"; v.kind = k end) end
  add("Collection (showcase)", function() reset(); v.mode = "cards"; v.showcase = true end)
  for _, s in ipairs((u and u.getSets and u.getSets()) or {}) do
    add("Album: " .. s.name, function() reset(); v.mode = "album"; v.album = s.name; v.albumPage = 1 end, true)
  end
  add("Sets", function() reset(); v.mode = "sets"; v.setPage = 0 end, true)
  add("Shop", function() reset(); v.mode = "shop" end)
  for _, sec in ipairs({ "dungeon", "raid", "holiday" }) do add("Shop: " .. sec .. " aisle", function() reset(); v.mode = "shop"; v.shopSection = sec; v.shopPage = 0 end, true) end
  add("Grading desk", function() reset(); v.mode = "shop"; v.shopSection = "grading" end)
  add("Guild Ledger", function() reset(); v.mode = "shop"; v.shopSection = "grading"; v.gradeLedger = true end)
  add("Today", function() reset(); v.mode = "today" end)
  add("Feats", function() reset(); v.mode = "feats" end, true)
  add("Trade", function() reset(); v.mode = "trade"; v.tradePage = 0 end, true)
  add("Ledger", function() reset(); v.mode = "stats" end)
  -- a few cards' own pages: the longest name of each kind, and a Mythic
  if u and u.CARDS and RG.ArcadeOpenDetail then
    local pick = {}
    for _, c in ipairs(u.CARDS) do
      local k = c.mythic and 9 or (c.kind or 1)
      if not pick[k] or #c.name > #pick[k].name then pick[k] = c end
    end
    for _, c in pairs(pick) do
      add("Card page: " .. c.name, function() reset(); v.mode = "cards"; RG.ArcadeOpenDetail(c) end)
    end
  end
  local i, page = 0, 0
  local step
  local function finish()
    for k in pairs(v) do v[k] = nil end
    for k, x in pairs(saved) do v[k] = x end
    if _G.WaypathArcadeCard then _G.WaypathArcadeCard:Hide() end
    pcall(RG.ArcadeRefresh, true)
    running = false
    local head = "Waypath+ text check: " .. pages .. " pages looked at, " .. #found .. " problem(s)" .. (#found >= 400 and " (the first 400)" or "")
    local lines = { head, "" }
    for _, l in ipairs(found) do lines[#lines + 1] = l end
    if #found == 0 then lines[#lines + 1] = "Every text on every page fits where it's drawn." end
    if RG.ShowErrors then RG.ShowErrors(table.concat(lines, "\n"), "Waypath+ text check  ·  Ctrl+A, Ctrl+C to copy") else RG.Print(head) end
  end
  local function look()
    local s = steps[i]
    local where = s.label .. (page > 1 and (" (page " .. page .. ")") or "")
    pages = pages + 1
    scan(win, where, out)
    local card = _G.WaypathArcadeCard
    if card and card:IsVisible() then scan(card, where, out); card:Hide() end
    -- the next page of a list, by the window's own arrow
    local nx = win.next
    if s.paged and page < MAXPAGES and nx and nx:IsVisible() and nx.enabled then
      page = page + 1
      local ok = pcall(nx.Click, nx)
      if ok then C_Timer.After(DELAY, look) return end
    end
    C_Timer.After(0.01, step)
  end
  step = function()
    if not win:IsShown() then running = false; RG.Print("The text check stopped: the cards window was closed.") return end
    i = i + 1; page = 1
    if not steps[i] then finish() return end
    local ok = pcall(steps[i].setup)
    if ok then pcall(RG.ArcadeRefresh, true) end
    C_Timer.After(DELAY, look)
  end
  RG.Print("Looking at every page of the cards window (" .. #steps .. " to go, about " .. math.ceil(#steps * DELAY * 2) .. " seconds). Leave the window open.")
  step()
end

do
  local base = SlashCmdList and SlashCmdList.WAYPATH
  if base then
    SlashCmdList.WAYPATH = function(msg)
      local cmd = (msg or ""):match("^%s*(%S+)")
      if cmd and cmd:lower() == "textcheck" then RG.ArcadeTextCheck() return end
      return base(msg)
    end
  end
end
