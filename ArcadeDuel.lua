-- Waypath+ : player-versus-player card duels.
--
-- Both players run the same rules engine (Battle.lua), which is deterministic: the same decks, the same seed and the
-- same moves always give the same game. So the two add-ons only have to agree on the decks, the seed and who goes
-- first, and then pass each move to the other. Every move carries the engine's random seed afterwards; if the two
-- games ever disagree the duel stops with a draw instead of showing two different boards.
--
-- Messages (add-on whispers, prefix WPDUEL, same realm and faction as the game allows):
--   C|proto|cards|version|class|name|deck     challenge (the host's deck)
--   A|class|name|deck                         accepted (the guest's deck)
--   X|reason                                  declined, busy or can't play
--   S|seed|first                              host starts the game
--   M|bits                                    my mulligan, one 0/1 per card in hand
--   P|seq|seed|slot|target                    played a card
--   T|seq|seed|attacker|target                attacked
--   W|seq|seed|target                         hero power
--   E|seq|seed                                end of turn
--   F                                         conceded      Z   ran out of time      Y   games out of step
local ADDON, RG = ...
if not (RG and RG.Battle) then return end

local PREFIX = "WPDUEL"
local PROTO = 1
local INVITE_SECS = 90      -- how long a challenge stays open
local TURN_SECS = 120       -- the opponent must act within this long on their turn
local WARN_SECS = 90

-- Players come as "Name-Realm", and on this client the chat events spell it "Name Realm" (a space): both mean the player "Name"
local function short(n) return ((n or ""):match("^([^%- ]+)") or ""):lower() end
local function whisperName(n) n = tostring(n or ""); return (n:gsub(" ", "-")) end

-- what was sent and received, for /wp duel log (a duel that "does nothing" is nearly always a message that never arrived)
local dlog = {}
local function duelLog(line)
  dlog[#dlog + 1] = string.format("%.0f  %s", GetTime and GetTime() or 0, line)
  if #dlog > 60 then table.remove(dlog, 1) end
end
RG.duelLog = duelLog
local onHello   -- defined further down; the message handler below needs it

-- ---------------------------------------------------------------------------
-- The protocol, written against an "env" so it can be tested with two simulated players
-- ---------------------------------------------------------------------------
local function newDuel(env)
  local D = { state = nil }
  local mySide, seq, rseq

  local function reset()
    D.state, D.peer, D.peerShort, D.side, D.mull, D.deck, D.class, D.name = nil, nil, nil, nil, {}, nil, nil, nil
    D.foeName = nil
    seq, rseq, D.lastRecv, D.invite = 0, 0, 0, nil
  end
  reset()

  local function send(msg)
    if #msg > 254 then env.print("Duel message too long (" .. #msg .. ").") return end
    env.send(msg, D.peer)
  end

  local function fail(why)
    env.print(why)
    if env.closeInvite then env.closeInvite() end
    reset()
  end

  -- tokens for a deck
  local function packDeck(list)
    local t = {}
    for i, k in ipairs(list) do t[i] = env.encode(k) or "?" end
    return table.concat(t, ",")
  end
  local function unpackDeck(str)
    local out = {}
    for tok in (str or ""):gmatch("[^,]+") do
      local k = env.decode(tok)
      if not k then return nil end
      out[#out + 1] = k
    end
    if #out ~= env.deckSize then return nil end
    return out
  end

  function D.busy() return D.state ~= nil end

  -- ----- starting -----
  function D.challenge(name)
    name = name and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then env.print("Usage: /wp duel PlayerName") return false end
    if short(name) == short(env.myName()) then env.print("You cannot duel yourself.") return false end
    if D.state then env.print("You are already in a duel or waiting for an answer.") return false end
    local deck, class, me = env.deck()
    if not deck then env.print(class) return false end
    reset()
    D.state, D.peer, D.peerShort, D.side = "out", name, short(name), 1
    D.deck, D.class, D.name = deck, class, me
    D.lastRecv = env.now()
    D.deadline = env.now() + INVITE_SECS
    send(table.concat({ "C", PROTO, env.cardCount, env.version, class, me, packDeck(deck), env.rating() }, "|"))
    env.print("Challenge sent to " .. name .. ". Waiting up to " .. INVITE_SECS .. " seconds for an answer. They need Waypath+ too.")
    return true
  end

  function D.accept()
    local inv = D.invite
    if D.state ~= "in" or not inv then env.print("Nobody has challenged you.") return false end
    local deck, class, me = env.deck()
    if not deck then
      env.print(class)
      send("X|My deck is not ready: " .. class)
      fail("Challenge declined: " .. class)
      return false
    end
    D.deck, D.class, D.name = deck, class, me
    D.hostDeck, D.hostClass, D.hostName, D.hostRating = inv.deck, inv.class, inv.name, inv.rating
    D.state = "wait"
    D.lastRecv = env.now(); D.deadline = env.now() + INVITE_SECS
    env.print("Accepted. Waiting for " .. (D.peer or "the host") .. " to start the duel...")
    send(table.concat({ "A", class, me, packDeck(deck), env.rating() }, "|"))
    if env.closeInvite then env.closeInvite() end
    return true
  end

  function D.decline(why)
    if D.state ~= "in" then env.print("Nobody has challenged you.") return false end
    send("X|" .. (why or "declined"))
    if env.closeInvite then env.closeInvite() end
    reset()
    return true
  end

  local function startGame(o)
    D.state = "mull"
    D.lastRecv = env.now()
    D.mull = {}
    mySide = o.me
    D.foeName = o.foeName
    env.start(o)
  end

  -- ----- the game -----
  function D.mulligan(side, set)
    if D.state ~= "mull" then return end
    local n = env.handSize(side)
    local bits = {}
    for i = 1, n do bits[i] = set[i] and "1" or "0" end
    D.mull[side] = set
    send("M|" .. table.concat(bits))
    D.checkMull()
  end
  function D.checkMull()
    if D.state == "mull" and D.mull[1] and D.mull[2] then
      D.state = "play"; D.lastRecv = env.now(); D.turnSince = env.now()
      env.applyMull(D.mull[1], D.mull[2])
    end
  end

  function D.sendMove(act)
    if D.state ~= "play" then return end
    seq = seq + 1
    local sd = env.seed()
    local tgt = act.tgt ~= nil and tostring(act.tgt) or ""
    if act.t == "play" then send(table.concat({ "P", seq, sd, act.i, tgt }, "|"))
    elseif act.t == "att" then send(table.concat({ "T", seq, sd, tostring(act.a), tostring(act.d) }, "|"))
    elseif act.t == "hp" then send(table.concat({ "W", seq, sd, tgt }, "|"))
    elseif act.t == "end" then send(table.concat({ "E", seq, sd }, "|")); D.lastRecv = env.now() end
  end

  function D.sendEnd(op) if D.peer then send(op) end D.closeSoon = true end

  function D.ended()
    reset()
  end

  local function ref(x) if x == nil or x == "" then return nil end return tonumber(x) or x end

  local function desync(why)
    send("Y")
    env.over(0, "The two games got out of step (" .. why .. "). Make sure you both have the same Waypath+ version.")
    reset()
  end

  -- ----- receiving -----
  function D.onMessage(msg, sender)
    if type(msg) ~= "string" then return end
    local op, a, b, c, d, e, f, g = strsplit("|", msg)
    if op == "C" then
      if D.state then
        env.send("X|busy", sender)
        return
      end
      if tonumber(a) ~= PROTO or tonumber(b) ~= env.cardCount then
        env.send("X|Different Waypath+ versions (" .. tostring(env.version) .. " here, " .. tostring(c) .. " there). Both of you need the same version.", sender)
        return
      end
      local deck = unpackDeck(f)
      if not deck then env.send("X|I could not read your deck. Both of you need the same Waypath+ version.", sender) return end
      reset()
      D.state, D.peer, D.peerShort, D.side = "in", sender, short(sender), 2
      D.invite = { deck = deck, class = d, name = e or sender, from = sender, rating = tonumber(g) }
      D.lastRecv = env.now(); D.deadline = env.now() + INVITE_SECS
      env.invite(sender, d, function() D.accept() end, function() D.decline() end)
      return
    end
    if short(sender) ~= D.peerShort then return end
    D.lastRecv = env.now()
    if op == "X" then
      fail((D.peer or "Your opponent") .. " did not accept: " .. (a or "declined") .. ".")
    elseif op == "A" and D.state == "out" then
      local deck = unpackDeck(c)
      if not deck then fail("Could not read " .. D.peer .. "'s deck.") return end
      local o = { me = 1, decks = { D.deck, deck }, classes = { D.class, a }, names = { D.name, b or D.peer },
                  seed = env.random(1, 2000000000), first = env.random(1, 2), foeName = b or D.peer, foeRating = tonumber(d) }
      env.print((b or D.peer) .. " accepted. Starting the duel...")
      send("S|" .. o.seed .. "|" .. o.first)
      startGame(o)
    elseif op == "S" and D.state == "wait" then
      local o = { me = 2, decks = { D.hostDeck, D.deck }, classes = { D.hostClass, D.class }, names = { D.hostName, D.name },
                  seed = tonumber(a), first = tonumber(b), foeName = D.hostName, foeRating = D.hostRating }
      if not (o.seed and (o.first == 1 or o.first == 2)) then fail("The start message was garbled.") return end
      startGame(o)
    elseif op == "M" and D.state == "mull" then
      local set = {}
      for i = 1, #(a or "") do if a:sub(i, i) == "1" then set[i] = true end end
      D.mull[3 - mySide] = set
      D.checkMull()
    elseif (op == "P" or op == "T" or op == "W" or op == "E") and D.state == "play" then
      local n, sd = tonumber(a), tonumber(b)
      if n ~= rseq + 1 then desync("a move was lost") return end
      local act
      if op == "P" then act = { t = "play", i = tonumber(c), tgt = ref(d) }
      elseif op == "T" then act = { t = "att", a = ref(c), d = ref(d) }
      elseif op == "W" then act = { t = "hp", tgt = ref(c) }
      else act = { t = "end" } end
      local ok, seedNow = env.move(act)
      if not ok then desync("that move was not legal here") return end
      rseq = n
      if seedNow ~= sd then desync("different dice") return end
      D.turnSince = env.now()
    elseif op == "F" and D.state then
      env.over(mySide, (D.foeName or "Your opponent") .. " conceded.")
      reset()
    elseif op == "Z" and D.state then
      env.over(3 - mySide, "You ran out of time.")
      reset()
    elseif op == "Y" and D.state then
      env.over(0, "The two games got out of step. Make sure you both have the same Waypath+ version.")
      reset()
    end
  end

  -- seconds the opponent has left to act on their turn (nil when it is not their turn)
  function D.opponentLeft()
    if D.state ~= "play" or env.curSide() == mySide or not D.lastRecv then return nil end
    return math.max(0, TURN_SECS - (env.now() - D.lastRecv))
  end

  -- ----- clocks: call about once a second -----
  function D.tick()
    local t = env.now()
    if (D.state == "out" or D.state == "in" or D.state == "wait") and D.deadline and t > D.deadline then
      if D.state == "in" and env.closeInvite then env.closeInvite() end
      env.print(D.state == "out" and "No answer: the challenge ran out." or "The challenge ran out.")
      reset()
      return
    end
    if D.state == "wait" and t - D.lastRecv > INVITE_SECS then fail("The host did not start the duel.") return end
    if D.state == "mull" and t - D.lastRecv > TURN_SECS * 2 then
      env.over(0, "The duel timed out before it began.")
      reset()
      return
    end
    if D.state == "play" then
      local mine = env.curSide() == mySide
      if not mine then
        if t - D.lastRecv > TURN_SECS then
          send("Z")
          env.over(mySide, (D.foeName or "Your opponent") .. " ran out of time.")
          reset()
        end
      else
        D.myStart = D.myStart or t
        if env.curSide() == mySide and D.turnSince and t - D.turnSince > WARN_SECS and not D.warned then
          D.warned = true
          env.say("Hurry up: your opponent is waiting.", 5)
        end
      end
      if not mine then D.warned = nil end
    end
  end

  return D
end
RG.DuelNew = newDuel

-- ---------------------------------------------------------------------------
-- The real thing
-- ---------------------------------------------------------------------------
local function realEnv()
  local env = { deckSize = RG.Battle.DECK }
  local function BATTLE() return RG.Battle end
  env.cardCount = #(RG.ARCADE_DATA or {})
  env.version = RG.VERSION or "dev"
  function env.now() return GetTime and GetTime() or 0 end
  function env.print(m) if RG.Print then RG.Print(m) end end
  function env.say(m, hold) end
  function env.myName() return (UnitName and UnitName("player")) or "" end
  function env.random(a, b) return math.random(a, b) end
  function env.send(msg, target) RG.DuelXmit(msg, target) end
  function env.deck()
    local list, class, me, swapped, auto = RG.ArenaPvPDeck()
    if list and auto then env.print("You had no finished Arena deck, so one was built for this duel.") end
    if list and swapped and swapped > 0 then env.print(swapped .. " Raider card(s) in your deck were swapped for other cards for this duel (Raiders only exist on your own collection).") end
    return list, class, me
  end
  function env.handSize(side) local g = RG.ArenaPvPState(); return g and #g.p[side].hand or 0 end
  function env.seed() return RG.ArenaPvPSeed() end
  function env.rating() return RG.ArenaPvPRating() end
  function env.curSide() local g = RG.ArenaPvPState(); return g and g.cur or 0 end
  function env.start(o) RG.ArenaPvPStart(o) end
  function env.applyMull(a, b) RG.ArenaPvPApplyMull(a, b) end
  function env.move(act) return RG.ArenaPvPMove(act) end
  function env.over(w, why) RG.ArenaPvPOver(w, why) end
  -- cards travel as numbers: the collection id for found cards, "b<n>" for the basic cards everyone has
  function env.encode(key)
    local U = RG.ArcadeUI
    local Bt = RG.Battle
    for i, k in ipairs(Bt.BASIC) do if k == key then return "b" .. i end end
    local c = U.byKey[key]
    if not c or c.kind == 4 then return nil end
    return tostring(c.id)
  end
  function env.decode(tok)
    local U, Bt = RG.ArcadeUI, RG.Battle
    local n = tok:match("^b(%d+)$")
    if n then return Bt.BASIC[tonumber(n)] end
    local c = U.CARDS[tonumber(tok) or 0]
    if not c or c.kind == 4 then return nil end
    local key = c.key or c.name
    if not Bt.defs[key] then Bt.derive(c) end
    return Bt.defs[key] and key or nil
  end
  -- the invitation box
  function env.invite(from, class, onYes, onNo)
    local U = RG.ArcadeUI
    if not U then onNo() return end
    local f = RG.__duelInvite
    if not f then
      f = CreateFrame("Frame", "WaypathDuelInvite", UIParent, "BackdropTemplate")
      U.darkPanel(f, 380, 120)
      f:SetPoint("TOP", UIParent, "TOP", 0, -120); f:SetFrameStrata("DIALOG")
      f.t = U.fs(f, "title", 15); f.t:SetPoint("TOP", 0, -16); f.t:SetTextColor(U.GOLDC[1], U.GOLDC[2], U.GOLDC[3]); f.t:SetText("CARD DUEL")
      f.b = U.fs(f, "body", 13); f.b:SetPoint("TOP", 0, -44); f.b:SetWidth(340)
      f.yes = U.gbtn(f, "Accept", 120, 28, function() end, true); f.yes:SetPoint("BOTTOMLEFT", 40, 16)
      f.no = U.gbtn(f, "Decline", 120, 28, function() end); f.no:SetPoint("BOTTOMRIGHT", -40, 16)
      RG.__duelInvite = f
    end
    f.b:SetText("|cfff5d273" .. from .. "|r challenges you to a friendly card duel. Your selected Arena deck will be used. No coins are won or lost.")
    f.yes:SetScript("OnClick", function() f:Hide(); onYes() end)
    f.no:SetScript("OnClick", function() f:Hide(); onNo() end)
    f:Show()
    env.print(from .. " challenges you to a card duel. Accept or decline in the box at the top of your screen, or type /wp duel accept.")
    if PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK then pcall(PlaySound, SOUNDKIT.READY_CHECK) end
  end
  function env.closeInvite() if RG.__duelInvite then RG.__duelInvite:Hide() end end
  return env
end

RG.__duelEnv = realEnv   -- for tests
local D
local function ensure()
  if D then return D end
  D = newDuel(realEnv())
  RG.Duel = D
  RG.ArenaPvPSetSend(function(act) D.sendMove(act) end)
  return D
end

function RG.DuelChallenge(name) return ensure().challenge(name) end
function RG.DuelTarget()
  if not (UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target")) then
    return false, "Target the player you want to duel, or type /wp duel PlayerName."
  end
  local n = UnitName("target")
  if not n or n == UnitName("player") then return false, "Pick another player to duel." end
  return ensure().challenge(n), nil, n
end

do
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
  local f = CreateFrame("Frame")
  f:RegisterEvent("CHAT_MSG_ADDON")
  f:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
    if prefix ~= PREFIX then return end
    local me = UnitName and UnitName("player")
    if sender and me and short(sender) == short(me) then return end
    if type(text) ~= "string" then return end
    -- a message sent over the party channel because the whisper did not go through: "@Name|message"
    if text:sub(1, 1) == "@" then
      local to, rest = text:match("^@([^|]*)|(.*)$")
      if not to or not me or short(to) ~= short(me) then return end
      text = rest
    end
    duelLog("got  " .. tostring(channel) .. " from " .. tostring(sender) .. "  " .. text:sub(1, 30) .. " (" .. #text .. ")")
    local k = text:sub(1, 2)
    if k == "H|" or k == "R|" then pcall(onHello, text, sender) return end
    if k == "K|" then pcall(RG.__cardShown, text, sender) return end
    local ok, err = xpcall(function() ensure().onMessage(text, sender) end, function(e) return tostring(e) end)
    if not ok then
      duelLog("ERROR " .. tostring(err))
      if RG.Print then RG.Print("The duel hit an error: " .. tostring(err):sub(1, 200)) end
      if RG.RecordError then pcall(RG.RecordError, "duel: " .. tostring(err)) end
    end
  end)
  local acc = 0
  f:SetScript("OnUpdate", function(_, dt)
    acc = acc + (dt or 0)
    if acc >= 1 then acc = 0; if D then pcall(D.tick) end end
  end)
end

-- ---------------------------------------------------------------------------
-- Party: who in your group has Waypath+, and a way to challenge them
-- ---------------------------------------------------------------------------
RG.duelSeen = RG.duelSeen or {}
local function groupChannel()
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
  if IsInRaid and IsInRaid() then return "RAID" end
  if IsInGroup and IsInGroup() then return "PARTY" end
end
-- One way out for every duel message. Someone in your group is reached over the party channel (addressed to them as
-- "@Name|message"): that works across realms and never depends on how the game spells a whisper target. Anyone else
-- gets a whisper. If the first way is refused, the other is tried.
local function inMyGroup(name)
  local want = short(name)
  if want == "" then return false end
  for _, m in ipairs(RG.DuelRoster and RG.DuelRoster() or {}) do if short(m.name) == want then return true end end
  return false
end
function RG.DuelXmit(msg, target)
  target = whisperName(target)
  local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
  if not send then duelLog("no SendAddonMessage on this client") return false end
  local function good(ok, res) return ok and not (res == false or (type(res) == "number" and res ~= 0)) end
  local function viaGroup()
    local ch = groupChannel()
    if not ch then return false end
    local wrapped = "@" .. tostring(target) .. "|" .. msg
    if #wrapped > 254 then duelLog("too long for the party channel (" .. #wrapped .. ")") return false end
    local ok, res = pcall(send, PREFIX, wrapped, ch)
    duelLog("sent " .. ch .. " to " .. tostring(target) .. "  " .. msg:sub(1, 30) .. " (" .. #msg .. ")  result " .. tostring(ok and res or ("error: " .. tostring(res))))
    return good(ok, res)
  end
  local function viaWhisper()
    local ok, res = pcall(send, PREFIX, msg, "WHISPER", target)
    duelLog("sent WHISPER to " .. tostring(target) .. "  " .. msg:sub(1, 30) .. " (" .. #msg .. ")  result " .. tostring(ok and res or ("error: " .. tostring(res))))
    return good(ok, res)
  end
  if inMyGroup(target) then
    if viaGroup() then return true end
    return viaWhisper()
  end
  if viaWhisper() then return true end
  return viaGroup()
end
-- ask the group who has the add-on; answers arrive as whispers and are remembered in RG.duelSeen
function RG.DuelPing()
  local ch = groupChannel()
  if not ch then return false end
  RG.duelPingT = GetTime and GetTime() or 0
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then local okp, resp = pcall(C_ChatInfo.SendAddonMessage, PREFIX, "H|" .. tostring(RG.VERSION or "dev"), ch); duelLog("sent " .. ch .. " hello  result " .. tostring(okp and resp or "error")) end
  return true
end
-- the people in your group (not you): { name, full, class, online, seen = { ver, rating } or nil }
function RG.DuelRoster()
  local out = {}
  if not (GetNumGroupMembers and UnitName) then return out end
  local n = GetNumGroupMembers() or 0
  local raid = IsInRaid and IsInRaid()
  for i = 1, raid and n or (n - 1) do
    local unit = raid and ("raid" .. i) or ("party" .. i)
    if UnitExists(unit) and not (UnitIsUnit and UnitIsUnit(unit, "player")) then
      local name, realm = UnitName(unit)
      if name and name ~= "" and name ~= "Unknown" then
        local _, class = UnitClass(unit)
        out[#out + 1] = { name = name, full = (realm and realm ~= "") and (name .. "-" .. realm) or name, class = class,
          online = UnitIsConnected == nil or UnitIsConnected(unit) and true or false, level = UnitLevel and UnitLevel(unit) or 0, seen = RG.duelSeen[short(name)] }
      end
    end
  end
  table.sort(out, function(a, b)
    if (a.seen ~= nil) ~= (b.seen ~= nil) then return a.seen ~= nil end
    return a.name < b.name
  end)
  return out
end
-- Show off a card: players in your group or guild who have Waypath+ see it as a small pop-up (K|key|finish|class|race)
function RG.ArcadeShareCard(card, finish)
  if not (card and finish and C_ChatInfo and C_ChatInfo.SendAddonMessage) then return 0 end
  local key = tostring(card.key or card.name):gsub("|", "")
  local msg = "K|" .. key .. "|" .. finish .. "|" .. (card.class or "") .. "|" .. (card.race or "")
  local n = 0
  local ch = groupChannel()
  if ch then pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, ch); n = n + 1 end
  if IsInGuild and IsInGuild() then pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD"); n = n + 1 end
  return n
end
RG.__cardShown = function(text, sender)
  local key, finish, class, race = text:match("^K|([^|]+)|(%d)|?([^|]*)|?([^|]*)")
  finish = tonumber(finish)
  if not key or #key > 40 or not finish or finish < 1 or finish > 4 or not sender then return end
  local U = RG.ArcadeUI
  local card = U and U.byKey and U.byKey[key]
  if not card and key:sub(1, 1) == "@" and class:match("^%u+$") and #class <= 12 and (race == "" or (race:match("^%a+$") and #race <= 16)) and RG.ArcadeAddRaider then
    if RG.ArcadeAddRaider(key:sub(2), class, race ~= "" and race or nil, nil) then card = U.byKey[key] end   -- a character you have just met
  end
  if card and RG.ArcadeShowPull then RG.ArcadeShowPull(sender:match("^([^-]+)") or sender, card, finish) end
end

onHello = function(text, sender)
  local kind, ver, rating = text:match("^(%a)|([^|]*)|?([^|]*)")
  if not sender or sender == "" then return end
  RG.duelSeen[short(sender)] = { ver = ver, rating = tonumber(rating), t = GetTime and GetTime() or 0 }
  if kind == "H" and C_ChatInfo and C_ChatInfo.SendAddonMessage then
    local r = RG.ArenaPvPRating and RG.ArenaPvPRating() or 0
    pcall(RG.DuelXmit, "R|" .. tostring(RG.VERSION or "dev") .. "|" .. tostring(r), sender)
  end
  if RG.DuelRosterChanged then RG.DuelRosterChanged() end
end
RG.__duelHello = onHello

local slashBase = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
  if cmd and cmd:lower() == "duel" and (not rest or rest == "" or rest:lower() == "party") then
    if RG.ArenaPartyPanel then RG.ArenaPartyPanel() else RG.Print("Duel a player with /wp duel PlayerName, or target them and use the Arena lobby.") end
    return
  end
  if cmd and cmd:lower() == "duel" and rest and rest ~= "" then
    local r = rest:lower()
    if r == "log" then
      if RG.ShowErrors then RG.ShowErrors(#dlog > 0 and table.concat(dlog, "\n") or "Nothing sent or received yet.", "Duel log") else for _, l in ipairs(dlog) do RG.Print(l) end end
      return
    end
    if r == "ping" then
      if not RG.DuelPing() then RG.Print("You are not in a group.") return end
      RG.Print("Asking your group who has Waypath+...")
      C_Timer.After(2, function()
        local n = 0
        for who, v in pairs(RG.duelSeen) do n = n + 1; RG.Print(who .. ": Waypath+ " .. tostring(v.ver)) end
        if n == 0 then RG.Print("No answers. They may not have Waypath+, or messages are not getting through (see /wp duel log).") end
      end)
      return
    end
    if r == "accept" then ensure().accept() return end
    if r == "decline" then ensure().decline() return end
    ensure().challenge(rest)
    return
  end
  return slashBase(msg)
end
