local _, RG = ...
-- Waypath Cards: grading with your guild (1.53).
--   * Your guild's graded cards: everyone with Waypath+ shares their cases on the guild channel (when they log in and
--     when their cases change), so a graded card's page can say how many your guild has graded at each grade.
--     Every case is checked against its certificate (ArcadeGrading.lua: sign); any that fails is left out, and a case
--     counts once however many lists it turns up in (it's known by its id: who graded it and its number).
--   * The Guild Ledger: for each set, everyone's best graded copy of each of its cards adds up to a score (10 a card at
--     most), and the guild's best scores make a leaderboard.
--   * Card history: who graded a case, when and where, and everyone it was traded to.
--   * Trading a graded card: offer the case to your group from its page; the answer can be any card (or a case), and the
--     case changes hands with its grade, its certificate and its history. A case that fails its check can't be offered,
--     and an offer whose case fails the check is turned down.
-- The check catches cases edited by hand in the save file or sent with a changed grade. It is worked out by the add-on
-- itself, so someone who rewrote the add-on could still forge one: no add-on can stop that, only the game's servers could.

local PREFIX = "WPGRD"
local function U() return RG.ArcadeUI end
local function store() local u = U(); return u and u.store and u.store() end
local function now() return (time and time()) or 0 end
local function safe(fn, ...) if not fn then return nil end local ok, v = pcall(fn, ...); if ok and v ~= nil and not (RG.IsSecret and RG.IsSecret(v)) then return v end end
local function me() return safe(UnitName, "player") or "?" end
local function short(n) return (n or ""):match("^([^%-]+)") or n or "" end
local function cardOf(key) local u = U(); return u and u.byKey and u.byKey[key] end
local function send(msg, chan, target) if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, chan, target) end end
-- a message longer than the game allows goes in pieces: LM|id|i|n|piece (put back together, then read as one)
local function sendLong(msg, chan, target)
  local size, pieces = 220, {}
  for i = 1, math.max(1, #msg), size do pieces[#pieces + 1] = msg:sub(i, i + size - 1) end
  local id = tostring(math.random(100000, 999999))
  for i, p in ipairs(pieces) do
    local m = "LM|" .. id .. "|" .. i .. "|" .. #pieces .. "|" .. p
    if C_Timer and C_Timer.After and i > 1 then C_Timer.After(0.2 * (i - 1), function() send(m, chan, target) end) else send(m, chan, target) end
  end
end
local KEEP_DAYS = 30

-- ---------------------------------------------------------------------------
-- A case written out for the wire: fields split by ~ (anything that could clash is escaped)
-- ---------------------------------------------------------------------------
local function esc(s) return (tostring(s or ""):gsub("%%", "%%25"):gsub("~", "%%7E"):gsub(";", "%%3B"):gsub("|", "%%7C"):gsub(">", "%%3E"):gsub("@", "%%40")) end
local function unesc(s) return (tostring(s or ""):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end
local function histOut(r)
  -- the people it went to after grading, with the day (the last four)
  local t = {}
  for i, h in ipairs(r.hist or {}) do if i > 1 and h[1] == "traded" then t[#t + 1] = esc(h[2]) .. "@" .. esc(h[3]) end end
  while #t > 4 do table.remove(t, 1) end
  return table.concat(t, ">")
end
local function blob(r, withHist)
  return table.concat({ esc(r.key), r.f, r.grade, r.s, r.cert, esc(r.owner), esc(r.when), r.sig, esc(r.by), withHist and histOut(r) or "" }, "~")
end
local function unblob(text)
  local p = {}
  for field in ((text or "") .. "~"):gmatch("(.-)~") do p[#p + 1] = field end
  if #p < 8 then return nil end
  local r = { key = unesc(p[1]), f = tonumber(p[2]), grade = tonumber(p[3]), s = p[4], cert = tonumber(p[5]), owner = unesc(p[6]), when = unesc(p[7]), sig = p[8], by = unesc(p[9] or "") }
  if r.by == "" then r.by = short(r.owner) end
  r.hist = { { "graded", r.by, r.when } }
  for h in (p[10] or ""):gmatch("[^>]+") do
    local who, day = h:match("^(.-)@(.*)$")
    if who then r.hist[#r.hist + 1] = { "traded", unesc(who), unesc(day) } end
  end
  if not (cardOf(r.key) and RG.ArcadeGradeValid and RG.ArcadeGradeValid(r)) then return nil, r end
  r.id = r.owner .. "#" .. r.cert
  return r
end
RG.ArcadeGradeBlob, RG.ArcadeGradeUnblob = blob, unblob

-- ---------------------------------------------------------------------------
-- The guild's cases
-- ---------------------------------------------------------------------------
local function book()
  local a = store(); if not a then return nil end
  local guild = (IsInGuild and IsInGuild() and safe(GetGuildInfo, "player")) or nil
  a.guildGrades = a.guildGrades or {}
  local b = a.guildGrades
  if b.guild ~= guild then a.guildGrades = { guild = guild, lists = {} }; b = a.guildGrades end
  b.lists = b.lists or {}
  return b, guild
end
-- your own cases, checked (a case that fails its check stays yours but isn't shared)
local function myCases()
  local out = {}
  for _, r in ipairs(RG.ArcadeGradeCases and RG.ArcadeGradeCases() or {}) do if RG.ArcadeGradeValid(r) then out[#out + 1] = r end end
  return out
end
function RG.ArcadeGradeUnverified()
  local n = 0
  for _, r in ipairs(RG.ArcadeGradeCases and RG.ArcadeGradeCases() or {}) do if not RG.ArcadeGradeValid(r) then n = n + 1 end end
  return n
end
-- every graded case the guild knows of, once each: { id = { r = case, holder = name } }
local function allCases()
  local out = {}
  local b = book()
  local mine = me()
  for _, r in ipairs(myCases()) do out[r.id] = { r = r, holder = mine } end
  if b then
    local cut = now() - KEEP_DAYS * 86400
    for who, l in pairs(b.lists) do
      if (l.t or 0) < cut then b.lists[who] = nil
      elseif short(who) ~= mine then
        for _, r in ipairs(l.cases or {}) do if not out[r.id] then out[r.id] = { r = r, holder = short(who) } end end
      end
    end
  end
  return out
end
RG.ArcadeGradeGuildCases = allCases
-- how many of a card the guild has graded at each grade
function RG.ArcadeGradePop(key)
  local pop, n = {}, 0
  for _, e in pairs(allCases()) do if e.r.key == key then pop[e.r.grade] = (pop[e.r.grade] or 0) + 1; n = n + 1 end end
  return pop, n
end

-- sharing: your list on the guild channel, in pieces
local SIZE = 230
local lastSent, pendingSend = 0, false
local function shareList(chan, target)
  local b, guild = book()
  if not guild and chan == "GUILD" then return end
  local parts = {}
  -- (your best 300: RG.ArcadeGradeCases lists the highest grades first)
  for i, r in ipairs(myCases()) do if i > 300 then break end; parts[#parts + 1] = blob(r, false) end
  local text = table.concat(parts, ";")
  local pieces = {}
  for i = 1, math.max(1, #text), SIZE do pieces[#pieces + 1] = text:sub(i, i + SIZE - 1) end
  local id = tostring(math.random(100000, 999999))
  for i, p in ipairs(pieces) do
    local msg = "GL|" .. id .. "|" .. i .. "|" .. #pieces .. "|" .. p
    if C_Timer and C_Timer.After and i > 1 then C_Timer.After(0.25 * (i - 1), function() send(msg, chan, target) end) else send(msg, chan, target) end
  end
  lastSent = now()
end
-- your cases changed: tell the guild (once a minute at most)
function RG.ArcadeGradeShare()
  if pendingSend then return end
  pendingSend = true
  local wait = math.max(2, 60 - (now() - lastSent))
  local function go() pendingSend = false; pcall(shareList, "GUILD") end
  if C_Timer and C_Timer.After then C_Timer.After(wait, go) else go() end
end
local inbox = {}
local function takeList(sender, id, i, n, piece)
  if not (i and n) or n > 200 or i < 1 or i > n then return end
  local k = sender
  local box = inbox[k]
  if not box or box.id ~= id then box = { id = id, n = n, got = 0, parts = {} }; inbox[k] = box end
  if not box.parts[i] then box.parts[i] = piece; box.got = box.got + 1 end
  if box.got < box.n then return end
  inbox[k] = nil
  local text = table.concat(box.parts)
  local cases, bad = {}, 0
  for one in text:gmatch("[^;]+") do
    local r = unblob(one)
    if r then if #cases < 300 then cases[#cases + 1] = r end else bad = bad + 1 end
  end
  local b = book(); if not b then return end
  b.lists[sender] = { t = now(), cases = cases, bad = bad }
  if RG.ArcadeRefresh then pcall(RG.ArcadeRefresh, true) end
end

-- ---------------------------------------------------------------------------
-- The Guild Ledger
-- ---------------------------------------------------------------------------
local setSize
local function sizeOf(name)
  if not setSize then
    setSize = {}
    local u = U()
    for _, c in ipairs(u.CARDS) do local n = u.setOf(c); setSize[n] = (setSize[n] or 0) + 1 end
  end
  return setSize[name] or 0
end
-- { set = { holder = { score, graded } } }: each holder's best grade for each card of the set, added up
function RG.ArcadeGradeLedger()
  local u = U()
  local best = {}   -- holder -> key -> grade
  for _, e in pairs(allCases()) do
    best[e.holder] = best[e.holder] or {}
    local cur = best[e.holder][e.r.key]
    if not cur or e.r.grade > cur then best[e.holder][e.r.key] = e.r.grade end
  end
  local sets = {}
  for holder, keys in pairs(best) do
    for key, g in pairs(keys) do
      local c = cardOf(key)
      if c then
        local sn = u.setOf(c)
        sets[sn] = sets[sn] or {}
        local e = sets[sn][holder] or { score = 0, graded = 0 }
        e.score = e.score + g; e.graded = e.graded + 1
        sets[sn][holder] = e
      end
    end
  end
  return sets, sizeOf
end

-- ---------------------------------------------------------------------------
-- Trading a graded card (your group): OG offer, AG answer, CG confirm
-- ---------------------------------------------------------------------------
local function trade() return RG.ArcadeTrade or {} end
local function today() return date and date("%d %b %Y") or "" end
local function groupChan() return (IsInRaid and IsInRaid()) and "RAID" or "PARTY" end
function RG.ArcadeOfferCase(id)
  local r = RG.ArcadeGradeFind(id)
  if not r then return false, "That case isn't yours any more." end
  if not RG.ArcadeGradeValid(r) then return false, "This case didn't pass its certificate check, so it can't be traded." end
  if not (RG.ArcadeTradable and RG.ArcadeTradable(r.key)) then return false, "Raider, Mythic, Field Guide and holiday cards can't be traded, graded or not." end
  if not (IsInGroup and IsInGroup()) then return false, "Join a party to trade." end
  local t = trade()
  t.out = { key = r.key, finish = r.f, case = r }
  sendLong("OG|" .. blob(r, true), groupChan())
  local c = cardOf(r.key)
  return true, "Offered your graded " .. (c and c.name or r.key) .. " (" .. r.grade .. ", " .. RG.ArcadeGradeName(r.grade) .. ") to your group. Waiting for someone to answer."
end
-- answering a graded offer: with an ordinary card (c, f) or one of your cases (id)
function RG.ArcadeGradeAnswer(c, f, id)
  local a = store(); local t = trade(); local o = t.incoming
  if not (a and o and o.case) then return false, "No graded offer to answer." end
  local give
  if id then
    local r = RG.ArcadeGradeFind(id)
    if not r then return false, "That case isn't yours any more." end
    if not RG.ArcadeGradeValid(r) then return false, "This case didn't pass its certificate check, so it can't be traded." end
    if not RG.ArcadeTradable(r.key) then return false, "That card can't be traded." end
    give = { key = r.key, finish = r.f, case = r }
  else
    if not (c and RG.ArcadeTradable(c.key or c.name) and RG.ArcadeOwnsPrint(c.key or c.name, f)) then return false, "Pick one of your cards to give back." end
    give = { key = c.key or c.name, finish = f }
  end
  sendLong("AG|" .. o.case.cert .. "|" .. esc(o.case.owner) .. "|" .. esc(give.key) .. "|" .. give.finish .. "|" .. (give.case and blob(give.case, true) or ""), "WHISPER", o.from)
  t.pending = { give = give, get = { key = o.key, finish = o.finish, case = o.case }, from = o.from, graded = true }
  t.incoming = nil
  return true, "Answer sent. Waiting for " .. short(o.from) .. " to confirm."
end
local function arrive(r, from)
  r.hist = r.hist or {}
  r.hist[#r.hist + 1] = { "traded", me(), today() }
  return RG.ArcadeGradeAddCase(r)
end
local long = {}
local function onAddon(text, sender)
  local a = store(); if not a then return end
  local op, rest = text:match("^(%u+)|(.*)$")
  local t = trade()
  if op == "LM" then
    local id, i, n, piece = rest:match("^(%d+)|(%d+)|(%d+)|(.*)$")
    i, n = tonumber(i), tonumber(n)
    if not (id and i and n and n <= 20) then return end
    local box = long[sender]
    if not box or box.id ~= id then box = { id = id, n = n, got = 0, parts = {} }; long[sender] = box end
    if not box.parts[i] then box.parts[i] = piece; box.got = box.got + 1 end
    if box.got < box.n then return end
    long[sender] = nil
    local whole = table.concat(box.parts)
    if whole:match("^LM|") then return end
    return onAddon(whole, sender)
  elseif op == "GL" then
    local id, i, n, piece = rest:match("^(%d+)|(%d+)|(%d+)|(.*)$")
    if id then takeList(sender, id, tonumber(i), tonumber(n), piece) end
  elseif op == "GQ" then
    -- someone asked: answer them alone, a moment later (so the guild doesn't all answer at once)
    if C_Timer and C_Timer.After then C_Timer.After(1 + math.random() * 6, function() pcall(shareList, "WHISPER", sender) end) end
  elseif op == "OG" then
    local r = unblob(rest)
    if not r then
      if RG.ArcadeMsg then RG.ArcadeMsg(short(sender) .. " offered a graded card that didn't pass its certificate check, so it was turned down.") end
      return
    end
    t.incoming = { key = r.key, finish = r.f, from = sender, case = r }
    local c = cardOf(r.key)
    if RG.ArcadeMsg then RG.ArcadeMsg(short(sender) .. " offers a graded " .. (c and c.name or r.key) .. " (" .. r.grade .. ", " .. RG.ArcadeGradeName(r.grade) .. "). Open the Trade tab to answer.") end
    if RG.ArcadeRefresh then pcall(RG.ArcadeRefresh, true) end
  elseif op == "AG" then
    local cert, owner, key, f, b = rest:match("^(%d+)|([^|]*)|([^|]*)|(%d)|(.*)$")
    local out = t.out
    if not (cert and out and out.case and out.case.cert == tonumber(cert) and out.case.owner == unesc(owner)) then return end
    key, f = unesc(key), tonumber(f)
    local mine = RG.ArcadeGradeFind(out.case.id)
    if not (mine and RG.ArcadeGradeValid(mine)) then return end
    local theirs
    if b and b ~= "" then theirs = unblob(b); if not theirs or theirs.key ~= key or theirs.f ~= f then
      if RG.ArcadeMsg then RG.ArcadeMsg(short(sender) .. " answered with a graded card that didn't pass its certificate check: no trade.") end
      return
    end end
    if not (cardOf(key) and RG.ArcadeTradable(key)) then return end
    -- the swap: your case goes, theirs (or their card) arrives
    local gone = RG.ArcadeGradeRemoveCase(mine.id)
    if not gone then return end
    if theirs then arrive(theirs, sender) else
      local slot = a.cards[key] or {}; a.cards[key] = slot; slot[f] = (slot[f] or 0) + 1
    end
    send("CG|" .. cert .. "|" .. owner .. "|" .. esc(key) .. "|" .. f, "WHISPER", sender)
    t.out = nil
    local c1, c2 = cardOf(gone.key), cardOf(key)
    if RG.ArcadeMsg then RG.ArcadeMsg("Traded your graded " .. (c1 and c1.name or "") .. " (" .. gone.grade .. ") for " .. (c2 and c2.name or key) .. (theirs and (" (graded " .. theirs.grade .. ")") or "") .. ".") end
    RG.ArcadeGradeShare()
    if RG.ArcadeRefresh then pcall(RG.ArcadeRefresh, true) end
  elseif op == "CG" then
    local cert, owner, key, f = rest:match("^(%d+)|([^|]*)|([^|]*)|(%d)$")
    local p = t.pending
    if not (cert and p and p.graded and p.get.case and p.get.case.cert == tonumber(cert) and p.get.case.owner == unesc(owner)) then return end
    if unesc(key) ~= p.give.key or tonumber(f) ~= p.give.finish then return end
    -- your side: what you gave goes, their case arrives
    if p.give.case then RG.ArcadeGradeRemoveCase(p.give.case.id)
    else local slot = a.cards[p.give.key]; if slot and (slot[p.give.finish] or 0) > 0 then slot[p.give.finish] = slot[p.give.finish] - 1 end end
    arrive(p.get.case, sender)
    t.pending = nil
    local c = cardOf(p.get.case.key)
    if RG.ArcadeMsg then RG.ArcadeMsg("Traded for " .. short(sender) .. "'s graded " .. (c and c.name or "") .. " (" .. p.get.case.grade .. ").") end
    RG.ArcadeGradeShare()
    if RG.ArcadeRefresh then pcall(RG.ArcadeRefresh, true) end
  end
end
RG.ArcadeGradeOnAddon = onAddon

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN"); ev:RegisterEvent("CHAT_MSG_ADDON"); pcall(ev.RegisterEvent, ev, "PLAYER_GUILD_UPDATE")
ev:SetScript("OnEvent", function(_, event, prefix, text, channel, sender)
  if event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    -- a little after logging in: ask the guild for their cases and share yours
    if C_Timer and C_Timer.After then
      C_Timer.After(15 + math.random() * 10, function()
        if IsInGuild and IsInGuild() then send("GQ|", "GUILD"); pcall(shareList, "GUILD") end
      end)
    end
    return
  end
  if event ~= "CHAT_MSG_ADDON" or prefix ~= PREFIX or type(text) ~= "string" or not sender then return end
  if RG.IsSecret and (RG.IsSecret(text) or RG.IsSecret(sender)) then return end
  if short(sender) == me() then return end
  local ok, err = pcall(onAddon, text, sender)
  if not ok and RG.RecordError then pcall(RG.RecordError, err) end
end)
