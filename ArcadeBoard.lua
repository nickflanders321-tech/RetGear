-- Waypath+ arena leaderboard. There is no server, so the board is built by the add-ons themselves: each one shares
-- its own rank (once the player has finished their placement games) with the people it can reach, and passes on what
-- it has heard about others, so the list grows as players meet. Everything arrives over add-on messages:
--   B|class|rating|games                  "here is my rank"  (guild, group, and a shared hidden channel)
--   G|Name-Realm,class,rating,games,age;...  "ranks I have heard of"  (age in minutes since that player was last heard)
-- Ranks are reported by each player's own add-on, so the board is an honour system, and it only lists players the
-- messages have reached. /wp board off stops your own rank being shared.
local ADDON, RG = ...
RG = RG or {}
local PREFIX = "WPLB"
local CHANNEL = "WaypathLB"
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CLASS_ID = {}; for i, c in ipairs(CLASSES) do CLASS_ID[c] = i end
local MIN_GAMES = 5            -- placement games before a rank is shown to others
local MAX_ENTRIES = 1500
local KEEP_SECS = 30 * 86400   -- someone not heard of for 30 days drops off the board
local LAUNCH = 1793833200      -- WoW Forever launch (November 4 2026, 3 p.m. PST): beta ranks don't carry over to the live board
local GOSSIP_MAX = 7           -- entries in one gossip message
local PER_SENDER = 5           -- seconds between messages accepted from the same sender

local function norm(s) return (s or ""):lower() end

local function newBoard(env)
  local B = {}
  local db = env.db()                       -- { entries = { ["name-realm"] = { name, realm, class, rating, games, seen, near } } }
  db.entries = db.entries or {}
  local lastFrom, lastReply = {}, -100

  local function validName(n) return type(n) == "string" and #n >= 2 and #n <= 12 and not n:find("[^%a\128-\255]") end
  local function validRealm(r) return type(r) == "string" and #r >= 1 and #r <= 32 and not r:find("[^%w%- '\128-\255]") end
  local function splitName(full)
    local n, r = tostring(full or ""):match("^([^%- ]+)[%- ](.+)$")
    if not n then n, r = tostring(full or ""), env.realm() end
    return n, (r or ""):gsub("%s+", "")
  end
  local function key(n, r) return norm(n) .. "-" .. norm(r) end
  local function meKey() return key(env.myName(), env.realm()) end

  local function put(name, realm, class, rating, games, seen, near)
    if not (validName(name) and validRealm(realm)) then return false end
    rating, games = tonumber(rating), tonumber(games)
    if not rating or not games or rating < 0 or rating > 3000 or games < MIN_GAMES or games > 100000 then return false end
    class = CLASSES[tonumber(class) or 0]
    if not class then return false end
    local k = key(name, realm)
    if k == meKey() then return false end              -- nobody else decides what my rank is
    local e = db.entries[k]
    if e and e.seen >= seen and not near then return false end
    if not e then e = {}; db.entries[k] = e end
    e.name, e.realm, e.class, e.rating, e.games = name, realm, class, math.floor(rating), math.floor(games)
    e.seen = math.max(seen, e.seen or 0)
    if near then e.near = env.now() end
    return true
  end

  function B.prune()
    local now, n = env.now(), 0
    lastFrom = {}
    for k, e in pairs(db.entries) do
      if now - e.seen > KEEP_SECS or (now >= LAUNCH and (e.seen or 0) < LAUNCH) then db.entries[k] = nil else n = n + 1 end
    end
    if n > MAX_ENTRIES then
      local all = {}
      for k, e in pairs(db.entries) do all[#all + 1] = { k, e.seen } end
      table.sort(all, function(a, b) return a[2] < b[2] end)
      for i = 1, n - MAX_ENTRIES do db.entries[all[i][1]] = nil end
    end
  end

  function B.me()
    local r, g, class = env.rating(), env.games(), env.class()
    if not (r and class) then return nil end
    return { name = env.myName(), realm = env.realm(), class = class, rating = r, games = g or 0, seen = env.now(), me = true }
  end
  function B.sharing() return not db.off and (env.games() or 0) >= MIN_GAMES end

  function B.announceText()
    local id = CLASS_ID[env.class() or ""]
    if not id then return nil end
    return table.concat({ "B", id, env.rating(), env.games() }, "|")
  end
  function B.announce(channel)
    if not B.sharing() then return false end
    local t = B.announceText()
    if not t then return false end
    env.send(t, channel)
    return true
  end

  function B.gossipText(skip)
    local now, all = env.now(), {}
    for k, e in pairs(db.entries) do
      if k ~= skip and now - e.seen < 7 * 86400 then all[#all + 1] = e end
    end
    if #all == 0 then return nil end
    table.sort(all, function(a, b) return a.rating > b.rating end)
    local pick, used = {}, {}
    for i = 1, math.min(3, #all) do pick[#pick + 1] = all[i]; used[all[i]] = true end
    local rest = {}
    for _, e in ipairs(all) do if not used[e] then rest[#rest + 1] = e end end
    while #pick < GOSSIP_MAX and #rest > 0 do
      local i = env.random(1, #rest); pick[#pick + 1] = table.remove(rest, i)
    end
    local parts = {}
    for _, e in ipairs(pick) do
      parts[#parts + 1] = table.concat({ e.name .. "-" .. e.realm, CLASS_ID[e.class], e.rating, e.games, math.floor((now - e.seen) / 60) }, ",")
    end
    local text = "G|" .. table.concat(parts, ";")
    while #text > 240 and #parts > 1 do parts[#parts] = nil; text = "G|" .. table.concat(parts, ";") end
    return text
  end

  function B.onMessage(text, sender, channel)
    if type(text) ~= "string" or #text > 254 or not sender or sender == "" then return end
    local now = env.now()
    local sn, sr = splitName(sender)
    local sk = key(sn, sr)
    if sk == meKey() then return end
    local kind = text:sub(1, 2)
    local lk = sk .. kind
    if lastFrom[lk] and now - lastFrom[lk] < PER_SENDER then return end
    lastFrom[lk] = now
    if kind == "B|" then
      local c, r, g = text:match("^B|(%d)|(%d+)|(%d+)$")
      if not c then return end
      local isNew = not (db.entries[sk] and db.entries[sk].near and now - db.entries[sk].near < 1800)
      if put(sn, sr, c, r, g, now, true) and isNew and B.sharing() and now - lastReply > 20 then
        lastReply = now
        local t = B.gossipText(sk)
        if t then env.after(1 + env.random(0, 30) / 10, function() env.send(t, channel) end) end
        B.announce(channel)
      end
    elseif kind == "G|" then
      local n = 0
      for e in text:sub(3):gmatch("[^;]+") do
        n = n + 1; if n > GOSSIP_MAX + 2 then break end
        local full, c, r, g, age = e:match("^([^,]+),(%d),(%d+),(%d+),(%d+)$")
        if full then
          local nm, rl = splitName(full)
          put(nm, rl, c, r, g, now - math.min(tonumber(age) or 0, 99999) * 60, false)
        end
      end
    end
  end

  -- the list for the window: me included, best first. filter: "all", "realm", "near"
  function B.list(filter)
    local out = {}
    local me = B.me()
    local myRealm = norm(env.realm())
    local function want(e)
      if filter == "realm" then return norm(e.realm) == myRealm end
      if filter == "near" then return e.near ~= nil or e.me end
      return true
    end
    for _, e in pairs(db.entries) do if want(e) then out[#out + 1] = e end end
    if me and me.games >= MIN_GAMES then if want(me) then out[#out + 1] = me end end
    table.sort(out, function(a, b)
      if a.rating ~= b.rating then return a.rating > b.rating end
      return norm(a.name) < norm(b.name)
    end)
    return out
  end
  function B.count() local n = 0 for _ in pairs(db.entries) do n = n + 1 end return n end
  return B
end
RG.__newBoard = newBoard
if not (CreateFrame and C_ChatInfo and RG.Rank) then return end

-- ---------------------------------------------------------------------------
-- The real client
-- ---------------------------------------------------------------------------
local env = {}
function env.now() return time() end
function env.myName() return UnitName("player") or "" end
function env.realm() return ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and (GetRealmName():gsub("%s+", ""))) or "") end
function env.rating() return RG.ArenaPvPRating and RG.ArenaPvPRating() or nil end
function env.games()
  local a = RG.ArcadeUI and RG.ArcadeUI.store and RG.ArcadeUI.store()
  return a and (a.rGames or 0) or 0
end
function env.class() local _, c = UnitClass("player"); return c end
function env.random(a, b) return math.random(a, b) end
function env.after(s, fn) if C_Timer and C_Timer.After then C_Timer.After(s, fn) else fn() end end
function env.db()
  WaypathDB = WaypathDB or {}
  WaypathDB.board = WaypathDB.board or {}
  return WaypathDB.board
end
local function chanId() local id = GetChannelName and GetChannelName(CHANNEL); return tonumber(id) or 0 end
function env.send(msg, channel)
  if not msg then return end
  if channel == "CHANNEL" then
    local id = chanId(); if id <= 0 then return end
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "CHANNEL", id)
  elseif channel and channel ~= "" then
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel)
  end
end

local B
local function board() if not B then B = newBoard(env); RG.Board = B end return B end
local function groupChannel()
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
  if IsInRaid and IsInRaid() then return "RAID" end
  if IsInGroup and IsInGroup() then return "PARTY" end
end
local function shareNear()
  local b = board()
  local g = groupChannel(); if g then b.announce(g) end
  if IsInGuild and IsInGuild() then b.announce("GUILD") end
end

if C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
-- keep the hidden channel out of the chat windows, like the matchmaking one
if ChatFrame_AddMessageEventFilter then
  local function filter(_, _, _, _, _, chStr, _, _, _, _, chBase)
    if chBase == CHANNEL or (type(chStr) == "string" and chStr:find(CHANNEL, 1, true)) then return true end
  end
  for _, ev in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
    pcall(ChatFrame_AddMessageEventFilter, ev, filter)
  end
end
local joined = false
local function joinCh()
  if joined or not JoinChannelByName then return end
  pcall(JoinChannelByName, CHANNEL); joined = true
  if ChatFrame_RemoveChannel then for i = 1, (NUM_CHAT_WINDOWS or 10) do local f = _G["ChatFrame" .. i]; if f then pcall(ChatFrame_RemoveChannel, f, CHANNEL) end end end
end
local function leaveCh() if joined and LeaveChannelByName then pcall(LeaveChannelByName, CHANNEL) end joined = false end

-- A short, clock-aligned visit to the shared channel every 15 minutes (at :00, :15, :30, :45 for everyone), so
-- players who are online at the same time overlap and swap what they know.
local sessionEnd = 0
-- Only once the game's own channels (General, Trade...) are joined: a custom channel joined before them would
-- take /1 and shift the player's channel numbers, which matters on busy launch-day servers where joins are slow.
local enteredAt = 0
local function defaultChannelsReady()
  if not GetChannelList or GetTime() - enteredAt > 120 then return true end   -- someone who left every channel
  local ok, first = pcall(GetChannelList)
  return ok and first ~= nil
end
local function startSession()
  local b = board()
  if sessionEnd > GetTime() then return end
  -- a few seconds' spread so every Waypath+ player on the realm doesn't join in the same second
  -- (the 70-second visits still overlap)
  sessionEnd = GetTime() + 85
  env.after(math.random(0, 15), function()
    if InCombatLockdown and InCombatLockdown() then sessionEnd = 0 return end
    if IsInInstance then local inst, kind = IsInInstance(); if inst and kind ~= "none" then sessionEnd = 0 return end end
    if not defaultChannelsReady() then sessionEnd = 0 return end
    joinCh()
    env.after(6, function() b.announce("CHANNEL") end)
    env.after(36, function() b.announce("CHANNEL") end)
    env.after(70, function() leaveCh() end)
  end)
end
local lastSlot = -1
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:SetScript("OnEvent", function(_, ev, prefix, text, channel, sender)
  if ev == "CHAT_MSG_ADDON" then
    if prefix ~= PREFIX then return end
    pcall(board().onMessage, text, sender, channel)
    if RG.BoardChanged then pcall(RG.BoardChanged) end
  elseif ev == "PLAYER_ENTERING_WORLD" then
    if prefix then enteredAt = GetTime() end   -- first argument: isInitialLogin
    board().prune()
    env.after(15, function() shareNear(); startSession() end)
  elseif ev == "GROUP_ROSTER_UPDATE" then
    env.after(6, shareNear)
  elseif ev == "PLAYER_LEAVING_WORLD" then
    leaveCh(); sessionEnd = 0
  end
end)
local acc = 0
f:SetScript("OnUpdate", function(_, dt)
  acc = acc + (dt or 0)
  if acc < 5 then return end
  acc = 0
  local slot = math.floor(time() / 900)
  if lastSlot < 0 then lastSlot = slot end
  if slot ~= lastSlot then lastSlot = slot; shareNear(); startSession() end
end)

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------
local ROWS = 13
local win, view = nil, { filter = "all", top = 1 }
local CLASS_COL = { WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 }, ROGUE = { 1, 0.96, 0.41 },
  PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.41, 0.8, 0.94 }, WARLOCK = { 0.58, 0.51, 0.79 }, DRUID = { 1, 0.49, 0.04 } }
local function ago(secs)
  if secs < 120 then return "now" end
  if secs < 7200 then return math.floor(secs / 60) .. " min" end
  if secs < 172800 then return math.floor(secs / 3600) .. " h" end
  return math.floor(secs / 86400) .. " d"
end
local function refresh()
  if not (win and win.f:IsShown()) then return end
  local b = board()
  local list = b.list(view.filter)
  local n = #list
  local maxTop = math.max(1, n - ROWS + 1)
  view.top = math.max(1, math.min(view.top, maxTop))
  local now = env.now()
  for i = 1, ROWS do
    local r, e = win.rows[i], list[view.top + i - 1]
    if e then
      local rank = view.top + i - 1
      local info = RG.Rank.info(e.rating)
      local cc = CLASS_COL[e.class] or { 0.9, 0.9, 0.9 }
      r.num:SetText(rank)
      r.name:SetText(e.name); r.name:SetTextColor(cc[1], cc[2], cc[3])
      r.realm:SetText(e.me and "you" or e.realm)
      r.tier:SetText(info.label); r.tier:SetTextColor(info.color[1], info.color[2], info.color[3])
      r.rating:SetText(e.rating)
      r.seen:SetText(e.me and "" or ago(now - e.seen))
      r.me:SetShown(e.me and true or false)
      r.frame:Show()
    else r.frame:Hide() end
  end
  win.count:SetText(n == 0 and "Nobody listed yet" or ("Showing " .. view.top .. "-" .. math.min(n, view.top + ROWS - 1) .. " of " .. n))
  win.empty:SetShown(n == 0)
  for k, t in pairs(win.tabs) do t:SetActive(k == view.filter) end
  win.share:SetText(b.sharing() and "Sharing my rank: on" or (env.db().off and "Sharing my rank: off" or "Sharing my rank: after placement"))
end
function RG.BoardChanged() refresh() end
local function build()
  local U = RG.ArcadeUI
  local f = CreateFrame("Frame", "WaypathLeaderboard", UIParent, "BackdropTemplate")
  U.darkPanel(f, 560, 598)
  f:SetPoint("CENTER", 0, 20); f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", function(self) self:StartMoving() end); f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  if UISpecialFrames then table.insert(UISpecialFrames, "WaypathLeaderboard") end
  win = { f = f, rows = {}, tabs = {} }
  local logo = f:CreateTexture(nil, "ARTWORK"); logo:SetTexture(RG.LOGO or ""); logo:SetSize(32, 32); logo:SetPoint("TOPLEFT", 16, -14)
  local t = U.fs(f, "title", 20); t:SetPoint("TOPLEFT", 56, -18); t:SetTextColor(U.GOLDC[1], U.GOLDC[2], U.GOLDC[3]); t:SetText("WAYPATH+ LEADERBOARD")
  local sub = U.fs(f, "body", 11); sub:SetPoint("TOPLEFT", 18, -56); sub:SetWidth(524); sub:SetJustifyH("LEFT"); sub:SetTextColor(0.75, 0.72, 0.9)
  sub:SetText("Every Waypath+ player who has finished their placement games shares their rank automatically. You see the players your add-on has heard of, so the list grows as you meet people.")
  local function tab(key, label, x)
    local b = U.gbtn(f, label, 120, 26, function() view.filter, view.top = key, 1; refresh() end)
    b:SetPoint("TOPLEFT", x, -92); win.tabs[key] = b
  end
  tab("all", "Everyone", 18); tab("realm", "My realm", 144); tab("near", "Guild & party", 270)
  local jump = U.gbtn(f, "Find me", 90, 26, function()
    local list = board().list(view.filter)
    for i, e in ipairs(list) do if e.me then view.top = math.max(1, i - 5); break end end
    refresh()
  end)
  jump:SetPoint("TOPRIGHT", -18, -92)
  -- column heads
  local function head(txt, x, w, just) local h = U.fs(f, "head", 10); h:SetPoint("TOPLEFT", x, -130); h:SetWidth(w); h:SetJustifyH(just or "LEFT"); h:SetTextColor(U.GOLDC[1], U.GOLDC[2], U.GOLDC[3]); h:SetText(txt) end
  head("#", 24, 30); head("PLAYER", 60, 130); head("REALM", 196, 100); head("RANK", 300, 110); head("RATING", 410, 56, "RIGHT"); head("SEEN", 474, 56, "RIGHT")
  for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, f)
    row:SetSize(524, 28); row:SetPoint("TOPLEFT", 18, -146 - (i - 1) * 30)
    local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(row); bg:SetColorTexture(0.1, 0.08, 0.2, i % 2 == 0 and 0.45 or 0.7)
    local r = { frame = row }
    r.me = row:CreateTexture(nil, "BORDER"); r.me:SetAllPoints(row); r.me:SetColorTexture(0.85, 0.7, 0.3, 0.22); r.me:Hide()
    local function col(font, size, x, w, just) local s = U.fs(row, font, size); s:SetPoint("LEFT", x, 0); s:SetWidth(w); s:SetJustifyH(just or "LEFT"); s:SetWordWrap(false); return s end
    r.num = col("head", 12, 6, 30); r.num:SetTextColor(0.85, 0.8, 0.6)
    r.name = col("head", 13, 42, 134)
    r.realm = col("body", 11, 178, 100); r.realm:SetTextColor(0.7, 0.66, 0.85)
    r.tier = col("head", 12, 282, 112)
    r.rating = col("body", 12, 392, 56, "RIGHT"); r.rating:SetTextColor(0.95, 0.92, 0.8)
    r.seen = col("body", 11, 456, 56, "RIGHT"); r.seen:SetTextColor(0.6, 0.57, 0.7)
    row:Hide(); win.rows[i] = r
  end
  win.empty = U.fs(f, "body", 13); win.empty:SetPoint("TOP", 0, -260); win.empty:SetWidth(420); win.empty:SetTextColor(0.85, 0.8, 0.65)
  win.empty:SetText("Nobody is listed yet. Ranks appear as you meet other Waypath+ players: in your guild, your group, and a short check every 15 minutes with everyone else who is online.")
  win.count = U.fs(f, "body", 11); win.count:SetPoint("BOTTOMLEFT", 20, 56); win.count:SetTextColor(0.7, 0.65, 0.5)
  win.share = U.fs(f, "body", 11); win.share:SetPoint("BOTTOMRIGHT", -20, 56); win.share:SetTextColor(0.7, 0.65, 0.5)
  local up = U.gbtn(f, "Up", 70, 28, function() view.top = view.top - ROWS; refresh() end); up:SetPoint("BOTTOMLEFT", 18, 16)
  local dn = U.gbtn(f, "Down", 70, 28, function() view.top = view.top + ROWS; refresh() end); dn:SetPoint("BOTTOMLEFT", 94, 16)
  local sh = U.gbtn(f, "Share my rank", 130, 28, function()
    local d = env.db(); d.off = not d.off and true or nil
    RG.Print(d.off and "Your rank is no longer shared with other players. It stays on your own board." or "Your rank is shared again.")
    refresh()
  end)
  sh:SetPoint("BOTTOM", 20, 16)
  local cl = U.gbtn(f, "Close", 90, 28, function() f:Hide() end); cl:SetPoint("BOTTOMRIGHT", -18, 16)
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, d) view.top = view.top - (d or 0) * 3; refresh() end)
  f:SetScript("OnShow", function() board().prune(); refresh() end)
  local acc2 = 0
  f:SetScript("OnUpdate", function(_, dt) acc2 = acc2 + (dt or 0); if acc2 >= 5 then acc2 = 0; refresh() end end)
  f:Hide()
end
function RG.Leaderboard()
  if not RG.ArcadeUI then return end
  board()
  if not win then build() end
  if win.f:IsShown() then win.f:Hide() else win.f:Show() end
end

local base = SlashCmdList and SlashCmdList.WAYPATH
if base then
  SlashCmdList.WAYPATH = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
    if cmd and (cmd:lower() == "board" or cmd:lower() == "leaderboard") then
      local r = (rest or ""):lower()
      if r == "off" then env.db().off = true; RG.Print("Your rank is no longer shared with other players.")
      elseif r == "on" then env.db().off = nil; RG.Print("Your rank is shared with other Waypath+ players.")
      else RG.Leaderboard() end
      return
    end
    return base(msg)
  end
end
