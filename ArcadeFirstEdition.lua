-- Waypath+ cards: WoW Forever originals (ArcadeFirst.lua lists them, with the day each arrived).
--   First Edition: a WoW Forever original you get in the first four weeks after it arrived is a First Edition print,
--   marked with a seal in the corner of its picture. It never comes back once the four weeks are over.
--   Discovery: until you or someone in your guild finds one (meets the creature, loots the item, walks into the place,
--   or gets the card), its Album slot is a "???". Finds are shared with your guild, with the finder's name.
local _, RG = ...

local FIRST = RG.ARCADE_FIRST or {}
local WINDOW = 28 * 86400
local PREFIX = "WPCDISC"

local function U() return RG.ArcadeUI end
local function store() local u = U(); return u and u.store and u.store() end
local function safe(fn, ...) if not fn then return nil end local ok, v = pcall(fn, ...); if ok and v ~= nil and not (RG.IsSecret and RG.IsSecret(v)) then return v end end
local function now() return (time and time()) or 0 end
local function dayOf(iso)
  local y, m, d = (iso or ""):match("^(%d+)-(%d+)-(%d+)$")
  return y and time and time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0 }) or nil
end
local function inWindow(name)
  local s = dayOf(FIRST[name]); if not s then return false end
  local t = now()
  return t >= s and t < s + WINDOW
end
RG.ArcadeFirstWindow = inWindow

-- what finds a card: its creature, its item, its place
local byCreature, byItem, byPlace = {}, {}, {}
local function index()
  local u = U(); if not u then return end
  for name in pairs(FIRST) do
    local c = u.byKey[name]
    if c then
      if c.kind == 1 and c.ref and c.ref > 0 then byItem[c.ref] = name
      elseif c.kind == 3 then byPlace[name:lower()] = name end
    end
  end
  for name, cid in pairs(RG.ARCADE_DUNGEON_CREATURE or {}) do if FIRST[name] then byCreature[cid] = name end end
  for cid, e in pairs(RG.ARCADE_FIELD_NPC or {}) do if FIRST[e[1]] then byCreature[cid] = e[1] end end
end

-- ---------------------------------------------------------------------------
-- Discovery
-- ---------------------------------------------------------------------------
local outbox, sending = {}, false
local function flush()
  if sending or #outbox == 0 then return end
  sending = true
  local msg = table.remove(outbox, 1)
  if IsInGuild and IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg[1], msg[2], msg[3]) end
  if C_Timer and C_Timer.After then C_Timer.After(1, function() sending = false; flush() end) else sending = false end
end
local function discovered(name) local a = store(); return a and a.disc and a.disc[name] end
local function discover(name, by, quiet)
  local a = store(); if not (a and FIRST[name]) then return end
  a.disc = a.disc or {}
  if a.disc[name] then return end
  local me = safe(UnitName, "player")
  a.disc[name] = { by = by or me or "?", t = now() }
  if not by then
    outbox[#outbox + 1] = { "D|" .. name, "GUILD" }; flush()
    if not quiet and RG.Toast and RG.Opt and RG.Opt("arcadeToasts") ~= false then
      RG.Toast("Discovered", name .. ": you found it first. Its card shows in the Album now, for your guild too.", "Interface\\Icons\\INV_Misc_Spyglass_03", nil, nil, 6)
    end
  end
  if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
end
RG.ArcadeDiscover = discover
function RG.ArcadeUndiscovered(c)
  if not (c and FIRST[c.name]) then return false end
  if discovered(c.name) then return false end
  local u = U(); local a = store()
  if a and u and (u.owned(a, c.id) or 0) > 0 then discover(c.name, nil, true); return false end
  return true
end

local function npcOf(unit)
  local g = UnitGUID and safe(UnitGUID, unit)
  if type(g) ~= "string" then return nil end
  local kind, _, _, _, _, id = strsplit("-", g)
  if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
  return tonumber(id)
end
-- a creature card still waiting for its model: once the game has seen the creature it can say which model it is, so
-- ask again a few seconds later (at most every two minutes) instead of waiting for the next login
local modelCids, lastAsk = nil, -999
local function wantModel(id)
  if not modelCids then
    modelCids = {}
    for _, cid in pairs(RG.ARCADE_DUNGEON_CREATURE or {}) do modelCids[cid] = true end
  end
  if not modelCids[id] then return end
  local a = store()
  local nd = a and a.npcDisp
  if nd and nd[id] then return end
  local t = GetTime and GetTime() or 0
  if t - lastAsk < 120 or not (C_Timer and C_Timer.After and RG.ArcadeResolveCreatures) then return end
  lastAsk = t
  C_Timer.After(3, function() pcall(RG.ArcadeResolveCreatures) end)
end
local function look(unit)
  local id = npcOf(unit)
  if not id then return end
  if byCreature[id] then discover(byCreature[id]) end
  wantModel(id)
end
local function looted()
  if not (GetNumLootItems and GetLootSlotLink) then return end
  for i = 1, (safe(GetNumLootItems) or 0) do
    local link = safe(GetLootSlotLink, i)
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if id and byItem[id] then discover(byItem[id]) end
  end
end
local function place()
  if not GetInstanceInfo then return end
  local name = safe(GetInstanceInfo)
  if type(name) == "string" and byPlace[name:lower()] then discover(byPlace[name:lower()]) end
end

-- ---------------------------------------------------------------------------
-- First Edition: cards got in their four weeks
-- ---------------------------------------------------------------------------
local function mark(name, n)
  if not (FIRST[name] and inWindow(name)) then return end
  local a = store(); if not a then return end
  a.first = a.first or {}
  a.first[name] = (a.first[name] or 0) + (n or 1)
  discover(name, nil, true)
end
do
  local open = RG.ArcadeOpenPack
  if open then
    RG.ArcadeOpenPack = function(...)
      local got, free, notes, meta = open(...)
      if type(got) == "table" then for _, g in ipairs(got) do pcall(mark, g.card.name) end end
      return got, free, notes, meta
    end
  end
  local give = RG.ArcadeGiveCard
  if give then
    RG.ArcadeGiveCard = function(key, f, ...)
      local ok = give(key, f, ...)
      if ok then pcall(mark, key) end
      return ok
    end
  end
end

-- the seal: a small gold "1st" in the top corner of the picture
local seals = setmetatable({}, { __mode = "k" })
local function seal(w, card, finish)
  local s = seals[w]
  local a = card and finish and FIRST[card.name] and store()
  if not (a and a.first and (a.first[card.name] or 0) > 0) or (w.cw or 0) < 70 then if s then s:Hide() end return end
  local u = w.u or 1
  if not s then
    s = CreateFrame("Frame", nil, w)
    s.ring = s:CreateTexture(nil, "OVERLAY", nil, 1); s.ring:SetAllPoints(); s.ring:SetTexture("Interface\\AddOns\\Waypath\\Media\\Disc"); s.ring:SetVertexColor(0.95, 0.76, 0.3, 1)
    s.core = s:CreateTexture(nil, "OVERLAY", nil, 2); s.core:SetPoint("TOPLEFT", 2, -2); s.core:SetPoint("BOTTOMRIGHT", -2, 2)
    s.core:SetTexture("Interface\\AddOns\\Waypath\\Media\\Disc"); s.core:SetVertexColor(0.16, 0.1, 0.04, 1)
    s.t = s:CreateFontString(nil, "OVERLAY"); s.t:SetPoint("CENTER", 0, 0)
    seals[w] = s
  end
  local sz = math.max(16, 30 * math.max(0.55, u))
  s:SetSize(sz, sz)
  s:SetFrameLevel((w:GetFrameLevel() or 1) + 7)
  s:ClearAllPoints(); s:SetPoint("TOPRIGHT", w.artClip, "TOPRIGHT", -3 * u, -3 * u)
  local font = (RG.FONTS and (RG.FONTS.semibold or RG.FONTS.medium)) or "Fonts\\FRIZQT__.TTF"
  pcall(s.t.SetFont, s.t, font, math.max(6.5, sz * 0.34), "")
  s.t:SetTextColor(1, 0.86, 0.45); s.t:SetText("1st")
  s:Show()
end
RG.ArcadeCardHooks = RG.ArcadeCardHooks or {}
table.insert(RG.ArcadeCardHooks, seal)

-- the Album: "???" until found; who found it; when First Edition ends
RG.ArcadeTipHooks = RG.ArcadeTipHooks or {}
table.insert(RG.ArcadeTipHooks, 1, function(cd)
  if not FIRST[cd.name] then return false end
  local d = discovered(cd.name)
  if not d then
    GameTooltip:AddLine("Undiscovered: nobody in your guild has found this yet. Meet it, loot it or walk into it to be the first.", 0.55, 0.8, 1, true)
    return true
  end
  local me = safe(UnitName, "player")
  GameTooltip:AddLine("A WoW Forever original, found by " .. (d.by == me and "you" or d.by), 0.55, 0.8, 1, true)
  local s = dayOf(FIRST[cd.name])
  if s and now() < s then GameTooltip:AddLine("Arrives " .. date("%d %B", s), 1, 0.82, 0.45)
  elseif inWindow(cd.name) then GameTooltip:AddLine("First Edition prints until " .. date("%d %B", s + WINDOW), 1, 0.82, 0.45) end
  return false   -- (the card's own source line follows)
end)

-- ---------------------------------------------------------------------------
-- What you did before this update counts
-- ---------------------------------------------------------------------------
-- cards you already have: they could only be had since their day, so every copy you hold of one still in its four
-- weeks is a First Edition; dungeons and raids you've already cleared: you've met their bosses and walked their halls
local function retro()
  local a = store(); local u = U(); if not (a and u) then return end
  if not a.firstRetro then
    a.firstRetro = true
    a.first = a.first or {}
    for name in pairs(FIRST) do
      local s = a.cards and a.cards[name]
      if s and inWindow(name) then
        local n = (s[1] or 0) + (s[2] or 0) + (s[3] or 0) + (s[4] or 0)
        if n > (a.first[name] or 0) then a.first[name] = n end
      end
    end
  end
  local me = safe(UnitName, "player") or "you"
  for _, d in ipairs(RG.ARCADE_DUNGEONS or {}) do
    local dn = d[1]
    local cleared = (a.dunClear and a.dunClear[dn]) or (a.dun and a.dun[dn])
    if d.raid then
      cleared = false
      for k in pairs(a.raidFirst or {}) do if k:find(dn .. ":", 1, true) == 1 then cleared = true end end
    end
    if cleared and not d.holiday then
      for _, n in ipairs(d[5]) do
        local c = u.byKey[n]
        if FIRST[n] and c and (c.kind == 3 or (c.kind == 2 and (c.text or ""):find("boss"))) then discover(n, me, true) end
      end
    end
  end
end
RG.ArcadeFirstRetro = retro

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "LOOT_OPENED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "CHAT_MSG_ADDON" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
  if event == "PLAYER_TARGET_CHANGED" then pcall(look, "target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then pcall(look, "mouseover")
  elseif event == "NAME_PLATE_UNIT_ADDED" then pcall(look, a1)
  elseif event == "LOOT_OPENED" then pcall(looted)
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then pcall(place)
  elseif event == "CHAT_MSG_ADDON" then
    if a1 ~= PREFIX or type(a2) ~= "string" then return end
    local from = (a4 or ""):match("^[^%-]+")
    if from == safe(UnitName, "player") then return end
    local name = a2:match("^D|(.+)$")
    local finder, found = a2:match("^F|([^|]+)|(.+)$")
    if name then pcall(discover, name, from)
    elseif finder and found then pcall(discover, found, finder)
    elseif a2 == "S" then
      -- a guildmate just logged in: tell them what this guild has found (newest first, thirty at most)
      local a = store(); local list = {}
      for n, d in pairs((a and a.disc) or {}) do list[#list + 1] = { n, d } end
      table.sort(list, function(x, y) return (x[2].t or 0) > (y[2].t or 0) end)
      for i = 1, math.min(30, #list) do outbox[#outbox + 1] = { "F|" .. (list[i][2].by or "?") .. "|" .. list[i][1], "WHISPER", a4 } end
      flush()
    end
  elseif event == "PLAYER_LOGIN" then
    pcall(index)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    if C_Timer and C_Timer.After then
      C_Timer.After(15, function() outbox[#outbox + 1] = { "S", "GUILD" }; flush() end)
      C_Timer.After(12, function() pcall(retro) end)   -- (after the Legacy and raid checks have counted your clears)
    end
  end
end)
