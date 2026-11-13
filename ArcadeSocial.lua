-- Waypath+ cards: friends' and guildmates' albums, and trades of your spare cards for the ones you're missing.
-- Asks go out on the guild and group channels and as whispers to online friends; answers come back as whispers.
-- A trade is a swap of one spare card each, agreed on both sides: you propose, they accept, you swap, they swap.
local _, RG = ...

local PREFIX = "WPCSOC"
local S = { peers = {}, inbox = {}, matches = {}, out = nil, incoming = nil }
RG.ArcadeSocialState = S

local function U() return RG.ArcadeUI end
local function now() return (GetTime and GetTime()) or 0 end
local function me() return (UnitName and UnitName("player")) or "" end
local function short(name) return (name or ""):match("^([^%-]+)") or name or "" end
local function send(msg, chan, target)
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, chan, target) end
end

-- the cards that can change hands, numbered the same way for everyone with the same card data
local function tradeList()
  local u = U(); if not u then return {}, "0" end
  local list, sum = {}, 0
  for _, c in ipairs(u.CARDS) do
    if c.kind ~= 4 then
      list[#list + 1] = c
      sum = (sum + #(c.name or "") * #list) % 1000003
    end
  end
  return list, #list .. "-" .. sum
end
local function keyOf(c) return c.key or c.name end
local function counts(a, c) return (a and a.cards and a.cards[keyOf(c)]) or {} end

-- your spares (a print you have two or more of) and the cards you have none of
local function mySparesAndMissing()
  local u = U(); local a = u and u.store()
  local list = tradeList()
  local spares, missing = {}, {}
  if not a then return spares, missing, list end
  for i, c in ipairs(list) do
    if RG.ArcadeTradable(keyOf(c)) then
      local n, any = counts(a, c), false
      for f = 1, 4 do if (n[f] or 0) > 0 then any = true end end
      for f = 1, 4 do if (n[f] or 0) >= 2 then spares[#spares + 1] = { i = i, f = f }; break end end
      if not any then missing[i] = true end
    end
  end
  return spares, missing, list
end

-- an album summary: cards owned, cards in all, sets at gold / silver / bronze, sets in all, spares
local function summary()
  local u = U(); if not u then return nil end
  local a, own, total = RG.ArcadeStats()
  local g, s, b, n = 0, 0, 0, 0
  for _, st in ipairs(u.getSets() or {}) do
    if #(st.cards or {}) > 0 then
      n = n + 1
      local paid = ((a.setStage or {})[st.name]) or (((a.setsDone or {})[st.name]) and 1 or 0)
      if paid >= 3 then g = g + 1 elseif paid == 2 then s = s + 1 elseif paid == 1 then b = b + 1 end
    end
  end
  local spares = mySparesAndMissing()
  local _, sig = tradeList()
  local badges = RG.ArcadeExplorerBadges and RG.ArcadeExplorerBadges() or 0
  return table.concat({ sig, own, total, g, s, b, n, #spares, badges }, "|")
end

-- long lists go out in pieces
local function sendLong(kind, target, text)
  local size, parts = 220, {}
  for i = 1, math.max(1, #text), size do parts[#parts + 1] = text:sub(i, i + size - 1) end
  for i, p in ipairs(parts) do
    local msg = kind .. "|" .. i .. "|" .. #parts .. "|" .. p
    if C_Timer and C_Timer.After and i > 1 then C_Timer.After(0.15 * (i - 1), function() send(msg, "WHISPER", target) end)
    else send(msg, "WHISPER", target) end
  end
end
local function takeLong(sender, kind, i, n, piece)
  local k = sender .. "/" .. kind
  local box = S.inbox[k]
  if not box or box.n ~= n or i == 1 then box = { n = n, got = 0, parts = {} }; S.inbox[k] = box end
  if not box.parts[i] then box.parts[i] = piece; box.got = box.got + 1 end
  if box.got < n then return nil end
  S.inbox[k] = nil
  return table.concat(box.parts)
end

local function encodeSpares(spares)
  local t = {}
  for k = 1, math.min(#spares, 150) do t[#t + 1] = spares[k].i .. "." .. spares[k].f end
  return table.concat(t, ",")
end
local function decodeSpares(text)
  local out = {}
  for i, f in (text or ""):gmatch("(%d+)%.(%d)") do out[#out + 1] = { i = tonumber(i), f = tonumber(f) } end
  return out
end

-- ask everyone you can reach for their album
function RG.ArcadeSocialAsk()
  S.asked = now()
  if IsInGuild and IsInGuild() then send("Q", "GUILD") end
  if IsInGroup and IsInGroup() then send("Q", IsInRaid and IsInRaid() and "RAID" or "PARTY") end
  local FL = C_FriendList
  if FL and FL.GetNumFriends and FL.GetFriendInfoByIndex then
    local sent = 0
    for i = 1, (FL.GetNumFriends() or 0) do
      local f = FL.GetFriendInfoByIndex(i)
      if f and f.connected and f.name and sent < 25 then send("Q", "WHISPER", f.name); sent = sent + 1 end
    end
  end
end

-- look for swaps with one person: send your spares, they answer with the ones they want and their own spares
function RG.ArcadeSocialFind(name)
  local p = S.peers[name]; if not p then return false, "Ask for albums first." end
  local _, sig = tradeList()
  if p.sig ~= sig then return false, short(name) .. " has a different version of Waypath+, so cards can't be matched. Both of you need the latest version." end
  local spares = mySparesAndMissing()
  if #spares == 0 then return false, "You have no spare cards to trade yet (a spare is a second copy of the same print)." end
  S.matches[name] = { looking = true }
  sendLong("H", name, sig .. ";" .. encodeSpares(spares))
  return true, "Comparing albums with " .. short(name) .. "..."
end

local function cardText(list, i, f)
  local u = U(); local c = list[i]
  return (c and c.name or "?") .. " |cff9a96b0(" .. ((u and u.FINISH[f] and u.FINISH[f][1]) or "?") .. ")|r"
end

-- propose one swap: you give list[gi] in print gf, you get list[ti] in print tf
function RG.ArcadeSocialPropose(name, gi, gf, ti, tf)
  local list = tradeList()
  local give, get = list[gi], list[ti]
  if not (give and get) then return false, "That card isn't there any more." end
  if not RG.ArcadeOwnsPrint(keyOf(give), gf) then return false, "You don't have that card any more." end
  S.out = { name = name, gi = gi, gf = gf, ti = ti, tf = tf, t = now() }
  send("T|" .. gi .. "." .. gf .. "|" .. ti .. "." .. tf, "WHISPER", name)
  return true, "Asked " .. short(name) .. " to swap " .. give.name .. " for " .. get.name .. ". Waiting for an answer."
end

-- our own yes / no box for an incoming swap
local prompt
-- (made on first use, or when Edit Mode / /wp move shows where it will appear)
local function makePrompt(u)
  if prompt or not u then return prompt end
  prompt = CreateFrame("Frame", "WaypathCardSwapPrompt", UIParent, "BackdropTemplate")
  prompt:SetSize(380, 132); prompt:SetPoint("TOP", 0, -160); prompt:SetFrameStrata("DIALOG")
  prompt:SetBackdrop({ bgFile = u.WHITE, edgeFile = u.WHITE, edgeSize = 1 })
  prompt:SetBackdropColor(0.06, 0.053, 0.041, 0.97); prompt:SetBackdropBorderColor(u.GOLDC[1], u.GOLDC[2], u.GOLDC[3], 0.9)
  prompt.title = u.fs(prompt, "head", 14); prompt.title:SetPoint("TOP", 0, -12); prompt.title:SetTextColor(u.GOLDC[1], u.GOLDC[2], u.GOLDC[3])
  prompt.text = u.fs(prompt, "body", 13); prompt.text:SetPoint("TOP", 0, -36); prompt.text:SetWidth(350); prompt.text:SetSpacing(4)
  prompt.yes = u.gbtn(prompt, "Swap", 110, 26, function() RG.ArcadeSocialAnswer(true) end); prompt.yes:SetPoint("BOTTOMRIGHT", prompt, "BOTTOM", -6, 12)
  prompt.no = u.gbtn(prompt, "No thanks", 110, 26, function() RG.ArcadeSocialAnswer(false) end); prompt.no:SetPoint("BOTTOMLEFT", prompt, "BOTTOM", 6, 12)
  prompt:Hide()
  if RG.RegisterMover then
    RG.RegisterMover(prompt, "cardSwap", "Card swap from a friend", { "TOP", "TOP", 0, -160 }, function(f, was)
      if was then return end
      f.title:SetText("CARD SWAP FROM A FRIEND"); f.text:SetText("You give one of your spare cards\nYou get one of theirs")
    end)
  end
  return prompt
end
if RG.RegisterMoverMaker then RG.RegisterMoverMaker(function() makePrompt(U()) end) end
local function showPrompt()
  local u = U(); local inc = S.incoming
  if not (u and inc) then if prompt then prompt:Hide() end return end
  makePrompt(u)
  local list = tradeList()
  prompt.title:SetText("CARD SWAP FROM " .. string.upper(short(inc.name)))
  -- from your side: you give what they asked for (ti), you get what they offer (gi)
  prompt.text:SetText("You give " .. cardText(list, inc.ti, inc.tf) .. "\nYou get " .. cardText(list, inc.gi, inc.gf))
  prompt:Show()
end

function RG.ArcadeSocialAnswer(yes)
  local inc = S.incoming; S.incoming = nil
  if prompt then prompt:Hide() end
  if not inc then return end
  local list = tradeList()
  local mine = list[inc.ti]
  local payload = inc.gi .. "." .. inc.gf .. "|" .. inc.ti .. "." .. inc.tf
  if yes and mine and RG.ArcadeOwnsPrint(keyOf(mine), inc.tf) then
    S.waiting = { name = inc.name, payload = payload, t = now() }
    send("TA|" .. payload, "WHISPER", inc.name)
  else
    send("TN|" .. payload, "WHISPER", inc.name)
    if yes then RG.Print("You don't have that card any more, so the swap is off.") end
  end
end

local function parsePair(text)
  local gi, gf, ti, tf = (text or ""):match("^(%d+)%.(%d)|(%d+)%.(%d)$")
  return tonumber(gi), tonumber(gf), tonumber(ti), tonumber(tf)
end

local handlers = {}
handlers.Q = function(sender)
  local s = summary(); if s then send("S|" .. s, "WHISPER", sender) end
end
handlers.S = function(sender, rest)
  local sig, own, total, g, s, b, n, sp, ex = strsplit("|", rest)
  S.peers[sender] = { sig = sig, own = tonumber(own) or 0, total = tonumber(total) or 0, g = tonumber(g) or 0, s = tonumber(s) or 0, b = tonumber(b) or 0, n = tonumber(n) or 0, spares = tonumber(sp) or 0, badges = tonumber(ex) or 0, t = now() }
  if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
end
-- someone's spares came in: answer with the ones you want and your own spares
handlers.H = function(sender, rest)
  local i, n, piece = rest:match("^(%d+)|(%d+)|(.*)$")
  local text = takeLong(sender, "H", tonumber(i) or 1, tonumber(n) or 1, piece or "")
  if not text then return end
  local sig, list = text:match("^([^;]*);(.*)$")
  local mine, missing = mySparesAndMissing()
  local _, mysig = tradeList()
  if sig ~= mysig then return end
  local want = {}
  for _, e in ipairs(decodeSpares(list)) do if missing[e.i] then want[#want + 1] = e.i .. "." .. e.f end end
  sendLong("R", sender, table.concat(want, ",") .. ";" .. encodeSpares(mine))
end
-- the answer: pair what they want from you with what you want from them
handlers.R = function(sender, rest)
  local i, n, piece = rest:match("^(%d+)|(%d+)|(.*)$")
  local text = takeLong(sender, "R", tonumber(i) or 1, tonumber(n) or 1, piece or "")
  if not text then return end
  local wantText, theirText = text:match("^([^;]*);(.*)$")
  local _, missing = mySparesAndMissing()
  local give, get = decodeSpares(wantText), {}
  for _, e in ipairs(decodeSpares(theirText)) do if missing[e.i] then get[#get + 1] = e end end
  local pairs_ = {}
  for k = 1, math.min(#give, #get) do pairs_[#pairs_ + 1] = { give = give[k], get = get[k] } end
  S.matches[sender] = { give = #give, get = #get, pairs = pairs_ }
  if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
end
handlers.T = function(sender, rest)
  local gi, gf, ti, tf = parsePair(rest)
  if not gi then return end
  local list = tradeList()
  if not (list[gi] and list[ti] and RG.ArcadeTradable(keyOf(list[gi])) and RG.ArcadeTradable(keyOf(list[ti]))) then return end
  if S.incoming then send("TN|" .. rest, "WHISPER", sender) return end   -- (one at a time)
  S.incoming = { name = sender, gi = gi, gf = gf, ti = ti, tf = tf, t = now() }
  showPrompt()
end
-- they said yes: you swap first and tell them to swap
handlers.TA = function(sender, rest)
  local o = S.out
  local gi, gf, ti, tf = parsePair(rest)
  if not (o and o.name == sender and o.gi == gi and o.gf == gf and o.ti == ti and o.tf == tf) then return end
  S.out = nil
  local list = tradeList()
  if RG.ArcadeApplyTrade(keyOf(list[gi]), gf, keyOf(list[ti]), tf) then
    S.lastDone = { name = sender, gi = gi, gf = gf, ti = ti, tf = tf }
    send("TC|" .. rest, "WHISPER", sender)
    RG.Print("Swapped " .. list[gi].name .. " for " .. list[ti].name .. " with " .. short(sender) .. ".")
    if S.matches[sender] then S.matches[sender] = nil; RG.ArcadeSocialFind(sender) end
  else
    send("TN|" .. rest, "WHISPER", sender)
    RG.Print("You don't have " .. list[gi].name .. " any more, so the swap is off.")
  end
end
-- confirmed: your side of the swap
handlers.TC = function(sender, rest)
  local w = S.waiting
  local gi, gf, ti, tf = parsePair(rest)
  if not (w and w.name == sender and w.payload == rest) then return end
  S.waiting = nil
  local list = tradeList()
  if RG.ArcadeApplyTrade(keyOf(list[ti]), tf, keyOf(list[gi]), gf) then
    RG.Print("Swapped " .. list[ti].name .. " for " .. list[gi].name .. " with " .. short(sender) .. ".")
  else
    send("TX|" .. rest, "WHISPER", sender)   -- (they get their card back)
  end
end
-- the other side couldn't finish: undo your half
handlers.TX = function(sender, rest)
  local d = S.lastDone
  local gi, gf, ti, tf = parsePair(rest)
  if not (d and d.name == sender and d.gi == gi and d.gf == gf and d.ti == ti and d.tf == tf) then return end
  S.lastDone = nil
  local list = tradeList()
  RG.ArcadeApplyTrade(keyOf(list[ti]), tf, keyOf(list[gi]), gf)
  RG.Print("The swap with " .. short(sender) .. " couldn't finish, so you have your card back.")
end
handlers.TN = function(sender)
  if S.out and S.out.name == sender then
    S.out = nil
    RG.Print(short(sender) .. " said no to the swap.")
    if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function(_, event, prefix, text, channel, sender)
  if event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    return
  end
  if prefix ~= PREFIX or type(text) ~= "string" or not sender then return end
  if short(sender) == me() then return end
  local kind, rest = text:match("^(%u+)|?(.*)$")
  local h = kind and handlers[kind]
  if h then pcall(h, sender, rest or "") end
end)

-- the Friends' albums page in the Trade tab
function RG.ArcadeSocialView(ctx)
  local frame, view, PGW = ctx.frame, ctx.view, ctx.PGW
  ctx.pgBox(1, 196, 86, "Friends' and guildmates' albums", "Guildmates, group members and online friends with Waypath+. Open one to see which of your spares they're missing and which of theirs you're missing, then swap one for one.\n|cff9a96b0Raiders, Mythics, Field Guide and holiday cards can't be traded.|r")
  local names = {}
  for name in pairs(S.peers) do names[#names + 1] = name end
  table.sort(names, function(x, y) return (S.peers[x].own or 0) > (S.peers[y].own or 0) end)
  local y = 298
  local rows = {}
  local sel = view.socialSel and S.peers[view.socialSel] and view.socialSel
  local GOLD, SIL, BRZ = "|cffffd24a", "|cffd8dce4", "|cffd08a4a"
  if sel then
    local p, m = S.peers[sel], S.matches[sel]
    ctx.pgHead(1, y, short(sel) .. "'s album", "|cff9a96b0click to go back|r")
    rows[#rows + 1] = { left = string.format("%d of %d cards   ·   %s%d gold|r  %s%d silver|r  %s%d bronze|r sets   ·   %d Explorer badges", p.own, p.total, GOLD, p.g, SIL, p.s, BRZ, p.b, p.badges or 0),
      right = "Back", act = function() view.socialSel = nil; RG.ArcadeRefresh(true) end, frac = p.total > 0 and p.own / p.total or 0 }
    if not m then
      rows[#rows + 1] = { left = "Find swaps with " .. short(sel), right = "Compare", act = function()
        local ok, msg = RG.ArcadeSocialFind(sel); ctx.say(msg); RG.ArcadeRefresh(true) end }
    elseif m.looking then
      rows[#rows + 1] = { left = "|cff9a96b0Comparing albums...|r", right = "" }
    elseif #m.pairs == 0 then
      rows[#rows + 1] = { left = string.format("|cff9a96b0No swaps right now: they want %d of your spares, and you want %d of theirs.|r", m.give, m.get), right = "Again",
        act = function() local ok, msg = RG.ArcadeSocialFind(sel); ctx.say(msg); RG.ArcadeRefresh(true) end }
    else
      local list = tradeList()
      for _, pr in ipairs(m.pairs) do
        if #rows >= 10 then break end
        rows[#rows + 1] = { left = "Give " .. cardText(list, pr.give.i, pr.give.f) .. "   for   " .. cardText(list, pr.get.i, pr.get.f), right = "Propose",
          act = function() local ok, msg = RG.ArcadeSocialPropose(sel, pr.give.i, pr.give.f, pr.get.i, pr.get.f); ctx.say(msg); RG.ArcadeRefresh(true) end }
      end
    end
    if RG.ArcadeHolidayGiftRow then local g = RG.ArcadeHolidayGiftRow(sel); if g then table.insert(rows, 2, g) end end
    if S.out and S.out.name == sel then rows[#rows + 1] = { left = "|cffffd24aWaiting for " .. short(sel) .. " to answer your swap.|r", right = "" } end
  else
    ctx.pgHead(1, y, "Who's collecting", #names > 0 and (#names .. " found") or "")
    rows[#rows + 1] = { left = "Ask again", right = S.asked and "asked " .. math.floor(now() - S.asked) .. "s ago" or "", act = function() RG.ArcadeSocialAsk(); ctx.say("Asking your guild, group and online friends"); RG.ArcadeRefresh(true) end }
    for _, name in ipairs(names) do
      if #rows >= 10 then break end
      local p = S.peers[name]
      rows[#rows + 1] = { left = short(name) .. "   |cff9a96b0" .. p.own .. " / " .. p.total .. " cards   ·   " .. p.g .. " gold set" .. (p.g == 1 and "" or "s") .. "   ·   " .. p.spares .. " spare" .. (p.spares == 1 and "" or "s") .. ((p.badges or 0) > 0 and ("   ·   " .. p.badges .. " Explorer badge" .. (p.badges == 1 and "" or "s")) or "") .. "|r",
        right = "Open", frac = p.total > 0 and p.own / p.total or 0, act = function() view.socialSel = name; RG.ArcadeRefresh(true) end }
    end
    if #names == 0 then rows[#rows + 1] = { left = "|cff9a96b0Nobody yet. Guildmates, group members and online friends with Waypath+ answer within a few seconds.|r", right = "" } end
  end
  ctx.showRows(#rows)
  for i, r in ipairs(rows) do
    local b = frame.rows[i]
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 40, -(y + 30) - (i - 1) * 29)
    b.left:SetText(r.left); b.right:SetText(r.right or "")
    if r.frac then b.fillBg:Show(); b.fill:Show(); b.fill:SetWidth(math.max(1, (PGW - 2) * r.frac)) else b.fill:Hide(); b.fillBg:Hide() end
    b.act = r.act
  end
end
