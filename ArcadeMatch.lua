-- Waypath+ arena matchmaking: players who press "Find a match" are paired with another Waypath+ player who is
-- searching too. There is no server: searchers meet in a hidden chat channel (it is never shown in your chat
-- windows, and you only join it while searching). Each searcher announces "here I am, my rank, how long I have
-- waited"; when two of them fit (ranks close, or one of them has waited long enough) the one whose name sorts
-- first sends the normal duel challenge and the other accepts it automatically.
local ADDON, RG = ...
RG = RG or {}
local CHANNEL = "WaypathMM"
local PREFIX = "WPMM"
local BASE_WINDOW = 150      -- rating points apart that still count as a fit...
local WIDEN_PER_SEC = 6      -- ...growing by this much per second of the longer wait, so nobody waits forever
local SPAM_SECS = 8          -- how often a searcher announces itself
local STALE_SECS = 24        -- a searcher not heard from for this long has gone
local GIVE_UP_SECS = 300     -- stop searching after five minutes
local EXPECT_SECS = 40       -- how long an auto-accept stays open after pairing

local function short(n) return ((n or ""):match("^([^%- ]+)") or ""):lower() end

local function newMM(env)
  local M = { searching = false, seen = {}, expect = {}, found = nil }
  local lastSend = -100
  local function say(m) if env.print then env.print(m) end end

  local function announce(force)
    local now = env.now()
    if not force and now - lastSend < SPAM_SECS then return end
    lastSend = now
    env.broadcast(table.concat({ "Q", env.version(), env.rating(), math.floor(now - M.since) }, "|"))
  end

  function M.count()
    local n, now = 0, env.now()
    for _, s in pairs(M.seen) do if now - s.t <= STALE_SECS then n = n + 1 end end
    return n
  end

  function M.start()
    if M.searching then return false end
    local deck, why = env.deckReady()
    if not deck then say(why or "Your Arena deck is not ready.") return false, why end
    if env.busy() then say("Finish your current duel first.") return false end
    M.searching, M.since, M.seen, M.found = true, env.now(), {}, nil
    env.join()
    announce(true)
    say("Searching for another Waypath+ player... (type /wp match to stop)")
    return true
  end

  function M.stop(quiet)
    if not M.searching then return end
    M.searching = false
    env.leave()
    if not quiet then say("Stopped searching.") end
  end

  -- someone nearby announced themselves
  function M.onMessage(text, sender)
    if type(text) ~= "string" or text:sub(1, 2) ~= "Q|" then return end
    local who = short(sender)
    if who == "" or who == short(env.myName()) then return end
    local a, b, c = text:match("^Q|([^|]*)|(%-?%d*)|(%d*)")
    local isNew = not M.seen[who]
    M.seen[who] = { name = sender, ver = a, rating = tonumber(b) or 0, waited = tonumber(c) or 0, t = env.now() }
    if M.searching and isNew then announce(true) end   -- the newcomer should hear about us straight away
    if M.searching then M.consider() end
  end

  -- pick the best fit among the people we can see; the one whose name sorts first makes the challenge
  function M.consider()
    if not M.searching or M.found then return end
    local now = env.now()
    local mine, myWait = env.rating(), now - M.since
    local best, bestGap
    for who, s in pairs(M.seen) do
      if now - s.t <= STALE_SECS then
        local gap = math.abs(s.rating - mine)
        local window = BASE_WINDOW + WIDEN_PER_SEC * math.max(myWait, s.waited + (now - s.t))
        if gap <= window and (not bestGap or gap < bestGap) then best, bestGap = who, gap end
      end
    end
    if not best then return end
    local s = M.seen[best]
    if short(env.myName()) < best then
      M.found = best
      M.expect[best] = now + EXPECT_SECS
      M.tryAt = now
      say("Match found: " .. s.name .. ". Challenging them...")
      M.stop(true)
      env.challenge(s.name)
    else
      M.expect[best] = now + EXPECT_SECS       -- they sort first, so they will challenge us
    end
  end

  -- the duel code asks: is this challenger someone we matched with? (then the invite is accepted for us)
  function M.expects(sender)
    local w = short(sender)
    local t = M.expect[w]
    local s = M.seen[w]
    local here = M.searching and s and env.now() - s.t <= STALE_SECS   -- someone we saw searching
    if here or (t and env.now() <= t) then
      if M.searching then M.stop(true) end
      M.found = w
      M.expect[w] = nil
      return true
    end
    return false
  end

  function M.tick()
    local now = env.now()
    if M.searching then
      if now - M.since > GIVE_UP_SECS then M.stop(true); say("No other Waypath+ players were searching. Try again later, or invite a friend.") return end
      announce(false); M.consider()
    elseif M.found then
      -- the challenge or acceptance did not turn into a duel within a while: go back to searching
      if not env.busy() and now - (M.tryAt or now) > 25 then
        local keep = M.since
        M.found = nil
        if M.start() then M.since = keep or M.since; say("That match fell through. Searching again...") end
      elseif env.busy() then M.tryAt = now end
    end
  end
  return M
end

RG.__newMatch = newMM
if not (CreateFrame and C_ChatInfo) then return end

-- ---------------------------------------------------------------------------
-- The real client
-- ---------------------------------------------------------------------------
local joined = false
local function channelId()
  if not GetChannelName then return 0 end
  local id = GetChannelName(CHANNEL)
  return tonumber(id) or 0
end
local function hideFromChat()
  if not ChatFrame_RemoveChannel then return end
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local f = _G["ChatFrame" .. i]
    if f then pcall(ChatFrame_RemoveChannel, f, CHANNEL) end
  end
end
if ChatFrame_AddMessageEventFilter then
  local function filter(_, _, _, _, _, chStr, _, _, _, _, chBase)
    if chBase == CHANNEL or (type(chStr) == "string" and chStr:find(CHANNEL, 1, true)) then return true end
  end
  for _, ev in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
    pcall(ChatFrame_AddMessageEventFilter, ev, filter)
  end
end

local env = {}
function env.now() return GetTime and GetTime() or 0 end
function env.print(m) if RG.Print then RG.Print(m) end end
function env.myName() return (UnitName and UnitName("player")) or "" end
function env.version() return tostring(RG.VERSION or "dev") end
function env.rating() return (RG.ArenaPvPRating and RG.ArenaPvPRating()) or 0 end
function env.busy() return RG.Duel and RG.Duel.busy and RG.Duel.busy() or false end
function env.deckReady()
  if RG.ArenaPvPDeck then
    local list, why = RG.ArenaPvPDeck()
    if not list then return nil, why end
  end
  return true
end
function env.join()
  if JoinChannelByName then pcall(JoinChannelByName, CHANNEL); joined = true end
  hideFromChat()
end
function env.leave()
  if joined and LeaveChannelByName then pcall(LeaveChannelByName, CHANNEL) end
  joined = false
end
function env.broadcast(msg)
  local id = channelId()
  if id <= 0 then return false end    -- still joining; the next announcement goes out once the channel is ready
  local ok = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "CHANNEL", id)
  return ok
end
function env.challenge(name) if RG.DuelChallenge then RG.DuelChallenge(name) end end

local M = newMM(env)
RG.Match = M
function RG.MatchExpects(sender) return M.expects(sender) end
function RG.MatchToggle()
  if M.searching then M.stop() return false end
  return M.start()
end

if C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
  if prefix ~= PREFIX or channel ~= "CHANNEL" then return end
  pcall(M.onMessage, text, sender)
end)
local acc = 0
f:SetScript("OnUpdate", function(_, dt)
  acc = acc + (dt or 0)
  if acc >= 2 then
    acc = 0
    pcall(M.tick)
    if RG.MatchChanged then pcall(RG.MatchChanged) end
  end
end)
-- a search must not outlive a logout or a loading screen
local g = CreateFrame("Frame")
g:RegisterEvent("PLAYER_LEAVING_WORLD")
g:SetScript("OnEvent", function() if M.searching then M.stop(true) end end)

local base = SlashCmdList and SlashCmdList.WAYPATH
if base then
  SlashCmdList.WAYPATH = function(msg)
    local cmd = (msg or ""):match("^%s*(%S+)")
    if cmd and (cmd:lower() == "match" or cmd:lower() == "queue") then RG.MatchToggle() return end
    return base(msg)
  end
end
