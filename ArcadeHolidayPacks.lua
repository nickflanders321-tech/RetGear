-- Waypath+ cards: holiday packs (ArcadeHolidays.lua has the holidays and their cards).
--   Doing a holiday's quests while it's on earns its packs (one per quest, once a year).
--   The Lunar Festival's Elders are cards of their own: visit an Elder (turn in its quest) and its card is yours.
--   Every holiday card carries the year it was earned, so each year is a new print and old years can't be had again.
--   During the Feast of Winter Veil a wrapped present waits for you; it opens on Winter Veil morning (25 December).
--   While a holiday is on you can send a friend a wrapped card (one of your extra copies) from Friends' albums.
local _, RG = ...

local HOL = RG.ARCADE_HOLIDAYS or {}
local OF = RG.ARCADE_HOLIDAY_OF or {}
local GIFT_PREFIX = "WPCGIFT"
local byName, byKey, questTo, elderOf = {}, {}, {}, {}
for _, d in ipairs(HOL) do
  byName[d[1]] = d; byKey[d.holiday.key] = d
  for _, q in ipairs(d.holiday.quests or {}) do questTo[q] = d end
  for q, card in pairs(d.holiday.elders or {}) do elderOf[q] = card end
end
function RG.ArcadeIsHoliday(dn) return byName[dn] ~= nil end

local function U() return RG.ArcadeUI end
local function store() local u = U(); return u and u.store and u.store() end
local function safe(fn, ...) if not fn then return nil end local ok, v = pcall(fn, ...); if ok and v ~= nil and not (RG.IsSecret and RG.IsSecret(v)) then return v end end
local function now() return (time and time()) or 0 end
local function ymd(t) return date and date("*t", t or now()) or { year = 2026, month = 1, day = 1 } end
local MON = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }

-- ---------------------------------------------------------------------------
-- When a holiday is on, and which year's print it makes
-- ---------------------------------------------------------------------------
-- the window this year (and last year's, for one that runs over New Year): start, finish (epoch, local time)
local function window(d, year)
  local dt = d.holiday.date; if not (dt and time) then return nil end
  local s = time({ year = year, month = dt[1], day = dt[2], hour = dt[3], min = 0, sec = 0 })
  return s, s + dt[4] * 3600
end
-- (the game's calendar names the holidays that move from year to year)
local calCache = { t = -999 }
local function calendarHas(name)
  if not (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent) then return false end
  local t = GetTime and GetTime() or 0
  if t - calCache.t > 300 then
    calCache = { t = t }
    local today = ymd()
    local ok, n = pcall(C_Calendar.GetNumDayEvents, 0, today.day)
    for i = 1, (ok and n or 0) do
      local ok2, e = pcall(C_Calendar.GetDayEvent, 0, today.day, i)
      if ok2 and type(e) == "table" and type(e.title) == "string" then calCache[e.title] = true end
    end
  end
  return calCache[name] and true or false
end
-- on now? (its dates, the calendar, or a quest of it turned in during the last three days); and the year of its print
local function active(d)
  local t = now(); local y = ymd(t).year
  for _, yr in ipairs({ y, y - 1 }) do
    local s, e = window(d, yr)
    if s and t >= s and t < e then return true, yr, e end
  end
  if calendarHas(d[1]) then return true, (d.holiday.key == "winterveil" and ymd(t).month == 1) and y - 1 or y end
  local a = store()
  local last = a and a.hlast and a.hlast[d.holiday.key]
  if last and t - last < 3 * 86400 then return true, (d.holiday.key == "winterveil" and ymd(t).month == 1) and y - 1 or y end
  return false, nil
end
RG.ArcadeHolidayActive = active
local function nextStart(d)
  local t = now(); local y = ymd(t).year
  for _, yr in ipairs({ y, y + 1 }) do local s = window(d, yr); if s and s > t then return s end end
end

-- ---------------------------------------------------------------------------
-- Packs and years
-- ---------------------------------------------------------------------------
local function grant(d, year, n, label)
  local a = store(); if not (a and RG.ArcadeGrantDungeon) then return end
  a.hpk = a.hpk or {}; a.hpk[d.holiday.key] = a.hpk[d.holiday.key] or {}
  local t = a.hpk[d.holiday.key]
  t[year] = (t[year] or 0) + n
  RG.ArcadeGrantDungeon(d[1], n, label)
end
local function stampYear(name, year, n)
  local a = store(); if not a then return end
  a.hyear = a.hyear or {}; a.hyear[name] = a.hyear[name] or {}
  a.hyear[name][year] = (a.hyear[name][year] or 0) + (n or 1)
end
RG.ArcadeHolidayStamp = stampYear

local function questDone(qid)
  local d = questTo[qid]; if not d then return end
  local a = store(); if not a or not RG.db or RG.db.arcade == false then return end
  a.hlast = a.hlast or {}; a.hlast[d.holiday.key] = now()
  local _, year = active(d); year = year or ymd().year
  a.hq = a.hq or {}
  local k = year .. ":" .. qid
  if a.hq[k] then return end
  a.hq[k] = true
  local elder = elderOf[qid]
  if elder and RG.ArcadeGiveCard then
    RG.ArcadeGiveCard(elder, 1)
    stampYear(elder, year)
    a.helders = a.helders or {}; a.helders[year] = (a.helders[year] or 0) + 1
    local n = a.helders[year]
    if RG.Toast then
      RG.Toast("Lunar Festival", elder .. "'s card is yours (" .. year .. "). " .. n .. " Elder" .. (n > 1 and "s" or "") .. " this year" ..
        (n % 10 == 0 and ": a Lunar Festival pack for every ten!" or (", " .. (10 - n % 10) .. " more for a Lunar Festival pack.")),
        "Interface\\Icons\\INV_Misc_ElvenCoins", "See it", function() if RG.ArcadeOpenAlbum then RG.ArcadeOpenAlbum(d[1]) end end, 8)
    end
    if n % 10 == 0 then grant(d, year, 1) end
    if RG.ArcadeFx then RG.ArcadeFx("reward") end
    return
  end
  grant(d, year, 1, d[1] .. ": " .. (RG.QDATA and RG.QDATA[qid] and RG.QDATA[qid].n or "a holiday quest") .. " (" .. year .. ")")
end

-- the Winter Veil present: one a year, waiting under the tree until 25 December
local function presentDay(year) return time and time({ year = year, month = 12, day = 25, hour = 0 }) or 0 end
local function giftCheck()
  local d = byKey.winterveil; if not d then return end
  local on, year = active(d)
  local a = store(); if not (on and a) then return end
  a.wvGift = a.wvGift or {}
  if a.wvGift[year] then return end
  a.wvGift[year] = "wrapped"
  if RG.Toast then
    RG.Toast("A present for you", "Greatfather Winter left you a wrapped Winter Veil present (" .. year .. "). It opens on Winter Veil morning, 25 December.",
      "Interface\\Icons\\INV_Holiday_Christmas_Present_01", "See it", function() if RG.ArcadeOpenAlbum then RG.ArcadeOpenAlbum(d[1]) end end, 10)
  end
end
local function unwrap()
  local d = byKey.winterveil; local a = store(); if not (d and a and a.wvGift) then return end
  for year, st in pairs(a.wvGift) do
    if st == "wrapped" and now() >= presentDay(year) then
      a.wvGift[year] = "opened"
      a.coins = (a.coins or 0) + 50
      grant(d, year, 3, "Your Winter Veil present: 3 packs and 50 coins")
      if RG.ArcadeFx then RG.ArcadeFx("best") end
      return true
    end
  end
end
local function wrappedState()
  local a = store(); if not (a and a.wvGift) then return nil end
  for year, st in pairs(a.wvGift) do if st == "wrapped" then return year, now() >= presentDay(year) end end
end

-- opening: the oldest year's packs first; every card in it carries that year. Holiday packs can't be bought.
do
  local orig = RG.ArcadeOpenPack
  if orig then
    RG.ArcadeOpenPack = function(kind, dn, ...)
      local d = kind == "dungeon" and dn and byName[dn]
      if not d then return orig(kind, dn, ...) end
      local a = store()
      if not a or ((a.dpk and a.dpk[dn]) or 0) <= 0 then return nil, d[1] .. " packs are earned by doing its quests while it's on, not bought." end
      a.hpk = a.hpk or {}; a.hpk[d.holiday.key] = a.hpk[d.holiday.key] or {}
      local t, year = a.hpk[d.holiday.key], nil
      for y, n in pairs(t) do if n > 0 and (not year or y < year) then year = y end end
      local got, free, notes, meta = orig(kind, dn, ...)
      if type(got) == "table" then
        year = year or ymd().year
        if t[year] then t[year] = math.max(0, t[year] - 1) end
        for _, g in ipairs(got) do stampYear(g.card.name, year) end
        if meta then meta.year = year end
      end
      return got, free, notes, meta
    end
  end
end

-- ---------------------------------------------------------------------------
-- Gifts: a wrapped card to a friend (one of your extra copies of this holiday's cards)
-- ---------------------------------------------------------------------------
local function giftable()
  local a = store(); local u = U(); if not (a and u) then return nil end
  for _, d in ipairs(HOL) do
    local on, year = active(d)
    if on then
      local best
      for _, n in ipairs(d[5]) do
        local c = u.byKey[n]
        local s = a.cards[n]
        if c and not c.field and s then
          for f = 4, 1, -1 do if (s[f] or 0) >= 2 and (not best or f > best[2]) then best = { n, f, d, year } end end
        end
      end
      if best then return best end
    end
  end
end
function RG.ArcadeHolidayGiftRow(friend)
  local g = giftable(); if not g then return nil end
  local u = U()
  return { left = "Send " .. friend:match("^[^%-]+") .. " a wrapped " .. g[3][1] .. " card  |cff9a96b0(" .. g[1] .. ", " .. u.FINISH[g[2]][1] .. ", one of your extras)|r",
    right = "Send gift", act = function()
      local a = store(); local today = date and date("%Y-%m-%d") or ""
      a.giftDay = a.giftDay or {}; if a.giftDay.d ~= today then a.giftDay = { d = today, n = 0 } end
      if a.giftDay.n >= 3 then RG.Print("You've sent three gifts today: more tomorrow.") return end
      if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
      if RG.ArcadeTakeCard and RG.ArcadeTakeCard(g[1], g[2]) then
        a.giftDay.n = a.giftDay.n + 1
        local yr = a.hyear and a.hyear[g[1]]
        local year = g[4]
        if yr then for y, n in pairs(yr) do if n > 0 and y < year then year = y end end; yr[year] = math.max(0, (yr[year] or 1) - 1) end
        pcall(C_ChatInfo.SendAddonMessage, GIFT_PREFIX, "G|" .. g[1] .. "|" .. g[2] .. "|" .. year, "WHISPER", friend)
        RG.Print("Sent " .. friend:match("^[^%-]+") .. " a wrapped " .. g[1] .. " card.")
        if RG.ArcadeFx then RG.ArcadeFx("toast") end
      end
    end }
end
local function onGift(text, sender)
  local name, f, year = (text or ""):match("^G|(.+)|(%d)|(%d+)$")
  f, year = tonumber(f), tonumber(year)
  local u = U()
  if not (name and f and year and OF[name] and u and u.byKey[name] and not u.byKey[name].field) then return end
  if RG.ArcadeGiveCard and RG.ArcadeGiveCard(name, f) then
    stampYear(name, year)
    if RG.Toast then
      RG.Toast("A wrapped gift", (sender or "A friend"):match("^[^%-]+") .. " sent you " .. name .. " (" .. u.FINISH[f][1] .. ", " .. OF[name] .. " " .. year .. ").",
        "Interface\\Icons\\INV_Holiday_Christmas_Present_01", "See it", function() if RG.ArcadeOpenAlbum then RG.ArcadeOpenAlbum(OF[name]) end end, 10)
    end
    if RG.ArcadeFx then RG.ArcadeFx("reward") end
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_TURNED_IN", "CHAT_MSG_ADDON" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
  if event == "QUEST_TURNED_IN" then pcall(questDone, a1)
  elseif event == "CHAT_MSG_ADDON" then if a1 == GIFT_PREFIX and a3 == "WHISPER" then pcall(onGift, a2, a4) end
  elseif event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, GIFT_PREFIX) end
    if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end   -- (so the calendar knows today's holidays)
    if C_Timer and C_Timer.After then C_Timer.After(8, function() pcall(giftCheck) end) else pcall(giftCheck) end
  end
end)
RG.ArcadeHolidayQuestDone, RG.ArcadeHolidayGiftCheck, RG.ArcadeHolidayUnwrap = questDone, giftCheck, unwrap

-- ---------------------------------------------------------------------------
-- The cards: the year stamp; tooltips; the Album page
-- ---------------------------------------------------------------------------
local stamps = setmetatable({}, { __mode = "k" })
local function yearStamp(w, card, finish)
  local s = stamps[w]
  local h = card and finish and OF[card.name]
  local a = h and store()
  local yrs = a and a.hyear and a.hyear[card.name]
  local first, count = nil, 0
  for y, n in pairs(yrs or {}) do if n > 0 then count = count + 1; if not first or y < first then first = y end end end
  if not first or (w.cw or 0) < 90 then if s then s:Hide() end return end
  if not s then
    s = CreateFrame("Frame", nil, w)
    s.bg = s:CreateTexture(nil, "OVERLAY"); s.bg:SetAllPoints(); s.bg:SetColorTexture(0.12, 0.03, 0.05, 0.78)
    s.edge = s:CreateTexture(nil, "OVERLAY"); s.edge:SetHeight(1); s.edge:SetPoint("BOTTOMLEFT"); s.edge:SetPoint("BOTTOMRIGHT"); s.edge:SetColorTexture(1, 0.78, 0.45, 0.9)
    s.t = s:CreateFontString(nil, "OVERLAY"); s.t:SetPoint("CENTER")
    stamps[w] = s
  end
  local u = w.u or 1
  s:SetFrameLevel((w:GetFrameLevel() or 1) + 6)
  s:ClearAllPoints(); s:SetPoint("TOPLEFT", w.artClip, "TOPLEFT", 0, 0); s:SetPoint("TOPRIGHT", w.artClip, "TOPRIGHT", 0, 0)
  local big = (w.cw or 0) >= 200
  s:SetHeight((big and 20 or 15) * math.max(0.6, u))
  local font = (RG.FONTS and (RG.FONTS.semibold or RG.FONTS.medium)) or "Fonts\\FRIZQT__.TTF"
  pcall(s.t.SetFont, s.t, font, math.max(7, (big and 10 or 7.5) * math.max(0.7, u)), "")
  s.t:SetTextColor(1, 0.86, 0.6)
  s.t:SetText(string.upper(h:gsub("^Feast of ", "")) .. "  " .. first .. (count > 1 and ("  +" .. (count - 1)) or ""))
  s:Show()
end
RG.ArcadeCardHooks = RG.ArcadeCardHooks or {}
table.insert(RG.ArcadeCardHooks, yearStamp)

RG.ArcadeTipHooks = RG.ArcadeTipHooks or {}
table.insert(RG.ArcadeTipHooks, function(cd)
  local h = OF[cd.name]; if not h then return false end
  local d = byName[h]
  if cd.field then
    GameTooltip:AddLine("Visit " .. cd.name .. " during the Lunar Festival (turn in the Elder's quest) for this card", 0.55, 0.8, 1, true)
  else
    GameTooltip:AddLine("From " .. h .. " packs: earned by doing its quests while it's on", 0.55, 0.8, 1, true)
  end
  local on = active(d)
  if on then GameTooltip:AddLine(h .. " is on now", 0.48, 0.88, 0.54)
  else
    local s = nextStart(d)
    if s then local t = ymd(s); GameTooltip:AddLine("Back on " .. t.day .. " " .. MON[t.month], 1, 0.82, 0.45) end
  end
  return true
end)

RG.ArcadeAlbumHooks = RG.ArcadeAlbumHooks or {}
table.insert(RG.ArcadeAlbumHooks, function(st, frame)
  local btn = rawget(frame.albOpen, "giftBtn")
  local d = st.holiday and byName[st.name]
  if not d then if btn then btn:Hide() end return end
  local on, year, ends = active(d)
  local when
  if on then
    when = "|cff7be08aon now" .. (ends and (" until " .. ymd(ends).day .. " " .. MON[ymd(ends).month]) or "") .. "|r"
  else
    local s = nextStart(d)
    when = s and ("back on " .. ymd(s).day .. " " .. MON[ymd(s).month]) or "back next year"
  end
  frame.albTitle:SetText("|cffff9fb0HOLIDAY|r  " .. st.name .. "  |cffa89bc9·  " .. when .. "|r")
  frame.albNext:ClearAllPoints()
  frame.albNext:SetPoint("LEFT", frame.albTitle, "LEFT", math.min(frame.albTitle:GetStringWidth() or 300, 430) + 10, 0)
  local have = select(1, RG.ArcadeDungeonPacks(st.name))
  if have <= 0 then
    frame.albOpen:SetText(d.holiday.key == "lunar" and "Visit the Elders to earn packs" or "Do its quests while it's on")
    frame.albOpen:SetEnabled(false); frame.albOpen:Show()
  end
  -- the Winter Veil present
  if d.holiday.key == "winterveil" then
    pcall(giftCheck)   -- (in case Winter Veil began while you were logged in)
    local yr, ready = wrappedState()
    if not btn then
      local u = U()
      btn = u.gbtn(frame.albOpen, "Unwrap your present", 170, 24, function() if unwrap() and RG.ArcadeRefresh then RG.ArcadeRefresh(true) end end)
      btn:SetPoint("RIGHT", frame.prev, "LEFT", -14, 0)   -- (beside the page arrows, clear of the title row)
      frame.albOpen.giftBtn = btn
    end
    btn:SetShown(yr ~= nil)
    if yr then btn:SetText(ready and "Unwrap your present" or "Present: opens 25 December"); btn:SetEnabled(ready) end
  elseif btn then btn:Hide() end
end)
