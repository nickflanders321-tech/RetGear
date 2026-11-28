local _, RG = ...
-- Waypath Cards: the Guild board (Cards > Ledger > Guild board).
-- Everyone in your guild with Waypath+ shares a few numbers about their collection on the guild channel, and the board
-- ranks them three ways: packs opened this week, best grade, and the most finished sets.
--   B|week|packs|best grade|Gem Mints|sets done|gold sets|cards|total     "here are my numbers" (when you log in, when asked,
--                                                                         and now and then after opening packs)
--   Q|                                                                    "send me yours"
-- The numbers come from each player's own add-on, so the board is an honour system, like the Arena's. Nothing is sent to
-- anyone but your guild, and /wp board off (the Arena board's switch) is separate from this: /wp guildboard off stops
-- sharing these.
local PREFIX = "WPCGB"
local KEEP_DAYS = 30
local function U() return RG.ArcadeUI end
local function store() local u = U(); return u and u.store and u.store() end
local function now() return (time and time()) or 0 end
local function safe(fn, ...) if not fn then return nil end local ok, v = pcall(fn, ...); if ok and v ~= nil and not (RG.IsSecret and RG.IsSecret(v)) then return v end end
local function me() return safe(UnitName, "player") or "?" end
local function short(n) return (n or ""):match("^([^%-]+)") or n or "" end
local function send(msg) if C_ChatInfo and C_ChatInfo.SendAddonMessage and IsInGuild and IsInGuild() then pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD") end end

-- the week the packs are counted in: it starts on Tuesday, like the grading desk's free grading and the weekly quests
local function weekKey()
  if not (date and time) then return "week" end
  local t = time()
  local back = (tonumber(date("%w", t)) - 2) % 7
  return date("%Y-%m-%d", t - back * 86400)
end
RG.ArcadeWeekKey = weekKey

-- a pack was opened: count it for this week
function RG.ArcadeCountWeek(a, n)
  if not a then return end
  local k = weekKey()
  if not a.wk or a.wk.k ~= k then a.wk = { k = k, n = 0 } end
  a.wk.n = a.wk.n + (n or 1)
  if RG.ArcadeGuildShare then RG.ArcadeGuildShare() end
end

-- my numbers
function RG.ArcadeGuildMine()
  local a = store(); if not a then return nil end
  local k = weekKey()
  local packs = (a.wk and a.wk.k == k) and a.wk.n or 0
  local best, gems = 0, 0
  for _, r in ipairs(RG.ArcadeGradeCases and RG.ArcadeGradeCases() or {}) do
    if r.grade > best then best = r.grade end
    if r.grade >= 10 then gems = gems + 1 end
  end
  local done, gold = 0, 0
  for _, st in pairs(a.setStage or {}) do if st >= 1 then done = done + 1 end; if st >= 3 then gold = gold + 1 end end
  local _, own, total = RG.ArcadeStats()
  return { wk = k, packs = packs, best = best, gems = gems, done = done, gold = gold, own = own or 0, total = total or 0 }
end

local function book()
  local a = store(); if not a then return nil end
  local guild = (IsInGuild and IsInGuild() and safe(GetGuildInfo, "player")) or nil
  local b = a.guildBoard
  if not b or b.guild ~= guild then b = { guild = guild, who = {} }; a.guildBoard = b end
  b.who = b.who or {}
  return b, guild
end

local lastSent, pending = 0, false
local function share()
  local a = store(); if not a or a.guildBoardOff then return end
  local m = RG.ArcadeGuildMine(); if not m then return end
  send(table.concat({ "B", m.wk, m.packs, m.best, m.gems, m.done, m.gold, m.own, m.total }, "|"))
  lastSent = now()
end
-- (at most every two minutes)
function RG.ArcadeGuildShare()
  if pending then return end
  pending = true
  local wait = math.max(3, 120 - (now() - lastSent))
  local function go() pending = false; pcall(share) end
  if C_Timer and C_Timer.After then C_Timer.After(wait, go) else go() end
end

local lastFrom = {}
local function num(x, hi) x = tonumber(x); if not x or x < 0 or x > hi then return nil end return math.floor(x) end
local function onAddon(text, sender)
  local op, rest = text:match("^(%a)|?(.*)$")
  if op == "Q" then
    if now() - lastSent > 20 then pcall(share) end
  elseif op == "B" then
    local who = short(sender)
    if who == me() or (lastFrom[who] and now() - lastFrom[who] < 10) then return end
    lastFrom[who] = now()
    local wk, packs, best, gems, done, gold, own, total = strsplit("|", rest)
    packs, best, gems, done, gold, own, total = num(packs, 5000), num(best, 10), num(gems, 5000), num(done, 500), num(gold, 500), num(own, 5000), num(total, 5000)
    if not (wk and #wk <= 12 and packs and best and gems and done and gold and own and total) then return end
    local b = book(); if not b then return end
    b.who[who] = { wk = wk, packs = packs, best = best, gems = gems, done = done, gold = gold, own = own, total = total, t = now() }
    if RG.ArcadeRefresh then pcall(RG.ArcadeRefresh, true) end
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN"); ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function(_, event, prefix, text, channel, sender)
  if event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    if C_Timer and C_Timer.After then
      C_Timer.After(20 + math.random() * 10, function() if IsInGuild and IsInGuild() then send("Q|"); pcall(share) end end)
    end
    return
  end
  if prefix ~= PREFIX or type(text) ~= "string" or not sender or channel ~= "GUILD" then return end
  if RG.IsSecret and (RG.IsSecret(text) or RG.IsSecret(sender)) then return end
  local ok, err = pcall(onAddon, text, sender)
  if not ok and RG.RecordError then pcall(RG.RecordError, err) end
end)

-- the three boards
local BOARDS = {
  { key = "packs", name = "Packs opened this week",
    value = function(e) return e.packs end, text = function(e) return e.packs .. (e.packs == 1 and " pack" or " packs") end },
  { key = "grade", name = "Best grade",
    value = function(e) return e.best * 10000 + e.gems end, text = function(e) return (e.best > 0 and (e.best .. "") or "none") .. (e.gems > 0 and ("   ·   " .. e.gems .. " Gem Mint") or "") end },
  { key = "sets", name = "Most finished sets",
    value = function(e) return e.gold * 100000 + e.done * 1000 + e.own / 10 end, text = function(e) return e.done .. " done   ·   " .. e.gold .. " gold" end },
}
function RG.ArcadeGuildBoards() return BOARDS end

-- the list for one board: { name, entry, me }, best first (this week's numbers only for the weekly board)
function RG.ArcadeGuildList(key)
  local b = book(); if not b then return {}, nil end
  local def
  for _, d in ipairs(BOARDS) do if d.key == key then def = d end end
  def = def or BOARDS[1]
  local list = {}
  local cut = now() - KEEP_DAYS * 86400
  local wk = weekKey()
  for who, e in pairs(b.who) do
    if e.t < cut then b.who[who] = nil
    else
      local x = e
      if def.key == "packs" and e.wk ~= wk then x = setmetatable({ packs = 0 }, { __index = e }) end
      list[#list + 1] = { name = who, e = x }
    end
  end
  local mine = RG.ArcadeGuildMine()
  if mine then list[#list + 1] = { name = me(), e = mine, me = true } end
  table.sort(list, function(x, y)
    local vx, vy = def.value(x.e), def.value(y.e)
    if vx ~= vy then return vx > vy end
    return x.name < y.name
  end)
  return list, def
end

-- the Ledger's Guild board page (Arcade.lua hands over its page helpers)
local lastAsk = 0
function RG.ArcadeGuildView(ctx)
  local frame, view, PGW = ctx.frame, ctx.view, ctx.PGW
  local a = ctx.a
  local guild = IsInGuild and IsInGuild() and safe(GetGuildInfo, "player")
  if guild and now() - lastAsk > 60 then lastAsk = now(); send("Q|"); pcall(share) end
  view.guildBoard = view.guildBoard or "packs"
  local list, def = RG.ArcadeGuildList(view.guildBoard)
  ctx.pgBox(1, 196, 76, guild and ("<" .. guild .. ">  guild board") or "Guild board",
    guild and "Everyone in your guild with Waypath+ shares a few numbers about their collection, so you can see who is opening, grading and finishing the most. The numbers come from each player's own add-on."
      or "Join a guild to see how you compare. Guildmates with Waypath+ share these numbers with each other.", ctx.GOLDC)
  local y = 296
  ctx.pgHead(1, y, def.name, #list > 1 and ((#list - 1) .. " guildmate" .. (#list == 2 and "" or "s") .. " with you") or "")
  local rows = {}
  -- the first row picks the board
  local nextDef
  for i, d in ipairs(BOARDS) do if d.key == def.key then nextDef = BOARDS[i % #BOARDS + 1] end end
  rows[#rows + 1] = { left = "Showing: |cfff4ecd8" .. def.name .. "|r", right = "Next: " .. nextDef.name, act = function() view.guildBoard = nextDef.key; RG.ArcadeRefresh(true) end }
  local top = 0
  for _, r in ipairs(list) do top = math.max(top, def.value(r.e)) end
  for i, r in ipairs(list) do
    if #rows >= 10 then break end
    local v = def.value(r.e)
    local medal = i == 1 and "|cffffd24a" or (i == 2 and "|cffd8dce4" or (i == 3 and "|cffd08a4a" or "|cff9a96b0"))
    rows[#rows + 1] = { left = medal .. i .. ".|r  " .. (r.me and ("|cff7be08a" .. r.name .. "  (you)|r") or r.name), right = def.text(r.e), frac = top > 0 and v / top or 0 }
  end
  if #list <= 1 then
    rows[#rows + 1] = { left = "|cff9a96b0Nobody else yet. Guildmates with Waypath+ answer within a few seconds of the window opening.|r", right = "" }
  end
  if a and a.guildBoardOff then
    rows[#rows + 1] = { left = "|cff9a96b0You are not sharing your numbers. Click to share them.|r", right = "Share", act = function() a.guildBoardOff = nil; pcall(share); RG.ArcadeRefresh(true) end }
  else
    rows[#rows + 1] = { left = "|cff9a96b0Your numbers are shared with your guild.|r", right = "Stop sharing", act = function() if a then a.guildBoardOff = true end; RG.ArcadeRefresh(true) end }
  end
  ctx.showRows(#rows)
  for i, r in ipairs(rows) do
    local b = frame.rows[i]
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 40, -(y + 30) - (i - 1) * 29)
    b.left:SetText(r.left); b.right:SetText(r.right or "")
    if r.frac then b.fillBg:Show(); b.fill:Show(); b.fill:SetColorTexture(0.85, 0.66, 0.26, 0.95); b.fill:SetWidth(math.max(1, (PGW - 2) * r.frac)) else b.fill:Hide(); b.fillBg:Hide() end
    b.act = r.act
  end
end

-- /wp guildboard off | on
local base = SlashCmdList and SlashCmdList.WAYPATH
if base then
  SlashCmdList.WAYPATH = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
    if cmd and cmd:lower() == "guildboard" then
      local a = store()
      local r = (rest or ""):lower()
      if r == "off" and a then a.guildBoardOff = true; RG.Print("Your card numbers are no longer shared with your guild.")
      elseif r == "on" and a then a.guildBoardOff = nil; RG.Print("Your card numbers are shared with your guild."); pcall(share)
      else RG.Print("/wp guildboard off or on: whether your guild sees your card numbers (open the Guild board in Cards > Ledger).") end
      return
    end
    return base(msg)
  end
end
