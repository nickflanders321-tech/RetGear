-- Waypath+ cards: raid packs (ArcadeRaids.lua has the raids, their bosses and cards).
--   Each boss killed gives one of its raid's packs once per weekly lockout; the first kill of a boss gives two, unlocks
--   buying its raid's packs, and takes a raid photo: a one-of-a-kind keepsake with everyone who was there.
--   Bosses beaten before (the raid's Conqueror achievement) count once, the first time you log in.
--   A raid's key (the attunement item) is a card of its own, earned by being attuned.
--   Raid cards wear their raid's frame; pulling a raid boss makes it roar; your raid sees your best raid-pack pull.
local _, RG = ...

local RAIDS = RG.ARCADE_RAIDS or {}
local KEYS = RG.ARCADE_RAID_KEYS or {}
local LEGACY = RG.ARCADE_RAID_LEGACY or {}
local CARD_V = 358 / 512
local MEDIA = "Interface\\AddOns\\Waypath\\Media\\Arcade\\"
local PREFIX = "WPCRAID"

local byName, bossOf, encOf, frameOf = {}, {}, {}, {}
for _, d in ipairs(RAIDS) do
  byName[d[1]] = d
  for _, b in ipairs(d.raid.bosses or {}) do bossOf[b:lower()] = d[1] end
  for id, b in pairs(d.raid.encounters or {}) do encOf[id] = { d[1], b } end
  for _, n in ipairs(d[5]) do frameOf[n] = d.raid.frame end
end
function RG.ArcadeIsRaid(dn) return byName[dn] ~= nil end
function RG.ArcadeRaidOf(cardName) local r = RG.ARCADE_DUNGEON_OF and RG.ARCADE_DUNGEON_OF[cardName]; return r and byName[r] and r end

local function U() return RG.ArcadeUI end
local function store() local u = U(); return u and u.store and u.store() end
local function safe(fn, ...) if not fn then return nil end local ok, v = pcall(fn, ...); if ok and v ~= nil and not (RG.IsSecret and RG.IsSecret(v)) then return v end end
local function today() return date and date("%Y-%m-%d") or "" end
local function isOpen(d) return today() >= (d.raid.opens or "") end
local function niceDay(iso)
  local y, m, dd = (iso or ""):match("^(%d+)-(%d+)-(%d+)$")
  local MON = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }
  return y and (tonumber(dd) .. " " .. MON[tonumber(m)]) or iso
end

-- the weekly lockout this kill belongs to: the time of the next weekly reset (to the hour)
local function lockout()
  local now = (GetServerTime and GetServerTime()) or (time and time()) or 0
  local secs = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and safe(C_DateAndTime.GetSecondsUntilWeeklyReset)
  if type(secs) == "number" and secs > 0 then return math.floor((now + secs) / 3600) end
  -- (no answer from the game: Tuesday 15:00 UTC in the Americas, Wednesday 07:00 UTC elsewhere)
  local region = GetCurrentRegion and safe(GetCurrentRegion) or 1
  local anchor = (region == 1) and (5 * 86400 + 15 * 3600) or (6 * 86400 + 7 * 3600)   -- (1 Jan 1970 was a Thursday)
  return math.floor((now - anchor) / (7 * 86400)) + 1
end

-- ---------------------------------------------------------------------------
-- Raid photos
-- ---------------------------------------------------------------------------
local function roster()
  local list = {}
  local n = (GetNumGroupMembers and safe(GetNumGroupMembers)) or 0
  if IsInRaid and IsInRaid() then
    for i = 1, n do
      local ok, name, _, _, _, _, token = pcall(GetRaidRosterInfo, i)
      if ok and name and not (RG.IsSecret and RG.IsSecret(name)) then list[#list + 1] = { name:match("^[^%-]+"), token } end
    end
  else
    local me = safe(UnitName, "player"); if me then list[#list + 1] = { me, select(2, pcall(function() return select(2, UnitClass("player")) end)) } end
    for i = 1, 4 do
      local nm = safe(UnitName, "party" .. i)
      if nm then local ok, _, tok = pcall(UnitClass, "party" .. i); list[#list + 1] = { nm, ok and tok or nil } end
    end
  end
  table.sort(list, function(a, b) return a[1] < b[1] end)
  return list
end
local function takePhoto(raid, boss)
  local a = store(); if not a then return end
  a.photos = a.photos or {}
  local p = { raid = raid, boss = boss, when = date and date("%d %b %Y") or "", t = time and time() or 0, names = roster(),
              guild = (IsInGuild and IsInGuild() and safe(GetGuildInfo, "player")) or nil }
  a.photos[#a.photos + 1] = p
  if RG.ArcadeFx then RG.ArcadeFx("shutter") end
  return p
end

local viewer
local function photosOf(raid)
  local a = store(); local out = {}
  for _, p in ipairs((a and a.photos) or {}) do if not raid or p.raid == raid then out[#out + 1] = p end end
  return out
end
local function bossModel(m, boss)
  m:ClearModel()
  local disp = RG.ARCADE_NPC and RG.ARCADE_NPC[boss]
  local cid = RG.ARCADE_DUNGEON_CREATURE and RG.ARCADE_DUNGEON_CREATURE[boss]
  local ok = false
  if disp and m.SetDisplayInfo then ok = pcall(m.SetDisplayInfo, m, disp) elseif cid and m.SetCreature then ok = pcall(m.SetCreature, m, cid) end
  m:SetShown(ok)
  if ok then
    if m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, 0.15) end
    if m.SetFacing then pcall(m.SetFacing, m, 0.45) end
  end
end
function RG.ArcadeShowPhotos(raid, index)
  local u = U(); if not u then return end
  local list = photosOf(raid)
  if #list == 0 then return end
  if not viewer then
    local G = u.GOLDC
    viewer = CreateFrame("Frame", "WaypathRaidPhoto", UIParent, "BackdropTemplate")
    viewer:SetSize(600, 400); viewer:SetPoint("CENTER", 0, 30); viewer:SetFrameStrata("FULLSCREEN_DIALOG")
    viewer:SetBackdrop({ bgFile = u.WHITE, edgeFile = u.WHITE, edgeSize = 1 })
    viewer:SetBackdropColor(0.05, 0.045, 0.035, 0.98); viewer:SetBackdropBorderColor(G[1], G[2], G[3], 0.85)
    viewer:EnableMouse(true); viewer:SetMovable(true); viewer:RegisterForDrag("LeftButton")
    viewer:SetScript("OnDragStart", viewer.StartMoving); viewer:SetScript("OnDragStop", viewer.StopMovingOrSizing)
    tinsert(UISpecialFrames, "WaypathRaidPhoto")
    -- the boss, in its raid's frame (a card-shaped portrait)
    viewer.pic = CreateFrame("Frame", nil, viewer); viewer.pic:SetSize(220, 308); viewer.pic:SetPoint("TOPLEFT", 22, -46)
    viewer.bg = viewer.pic:CreateTexture(nil, "BACKGROUND"); viewer.bg:SetAllPoints(); viewer.bg:SetColorTexture(0.1, 0.09, 0.08, 1)
    viewer.model = CreateFrame("DressUpModel", nil, viewer.pic); viewer.model:SetPoint("TOPLEFT", 12, -14); viewer.model:SetPoint("BOTTOMRIGHT", -12, 12)
    viewer.edge = CreateFrame("Frame", nil, viewer.pic); viewer.edge:SetAllPoints(); viewer.edge:SetFrameLevel(viewer.model:GetFrameLevel() + 3)
    viewer.art = viewer.edge:CreateTexture(nil, "OVERLAY"); viewer.art:SetAllPoints(); viewer.art:SetTexCoord(0, 1, 0, CARD_V)
    viewer.eyebrow = u.fs(viewer, "head", 11); viewer.eyebrow:SetPoint("TOP", 0, -16); viewer.eyebrow:SetTextColor(0.72, 0.58, 0.3)
    viewer.eyebrow:SetText("R A I D     P H O T O")
    viewer.title = u.fs(viewer, "title", 20); viewer.title:SetPoint("TOPLEFT", viewer.pic, "TOPRIGHT", 22, -2); viewer.title:SetTextColor(1, 0.93, 0.74)
    viewer.title:SetWidth(330); viewer.title:SetJustifyH("LEFT")
    viewer.sub = u.fs(viewer, "body", 13); viewer.sub:SetPoint("TOPLEFT", viewer.title, "BOTTOMLEFT", 0, -6); viewer.sub:SetTextColor(0.85, 0.8, 0.68)
    viewer.sub:SetWidth(330); viewer.sub:SetJustifyH("LEFT")
    viewer.names = {}
    for i = 1, 40 do
      local t = u.fs(viewer, "body", 11.5); t:SetJustifyH("LEFT"); t:SetWidth(108)
      local col, row = math.floor((i - 1) / 14), (i - 1) % 14
      t:SetPoint("TOPLEFT", viewer.pic, "TOPRIGHT", 22 + col * 112, -78 - row * 16)
      viewer.names[i] = t
    end
    viewer.close = u.gbtn(viewer, "Close", 90, 24, function() viewer:Hide() end); viewer.close:SetPoint("BOTTOMRIGHT", -18, 14)
    viewer.prev = u.gbtn(viewer, "<", 36, 24, function() RG.ArcadeShowPhotos(viewer.raid, viewer.i - 1) end); viewer.prev:SetPoint("BOTTOMLEFT", 22, 14)
    viewer.next = u.gbtn(viewer, ">", 36, 24, function() RG.ArcadeShowPhotos(viewer.raid, viewer.i + 1) end); viewer.next:SetPoint("LEFT", viewer.prev, "RIGHT", 6, 0)
    viewer.count = u.fs(viewer, "body", 12); viewer.count:SetPoint("LEFT", viewer.next, "RIGHT", 10, 0); viewer.count:SetTextColor(0.7, 0.66, 0.56)
  end
  local i = math.max(1, math.min(index or #list, #list))
  local p = list[i]
  viewer.raid, viewer.i = raid, i
  local d = byName[p.raid]
  viewer.art:SetTexture(MEDIA .. ((d and d.raid.frame) or "RaidOnyxia"))
  bossModel(viewer.model, p.boss)
  viewer.title:SetText(p.boss)
  viewer.sub:SetText(p.raid .. "  ·  first kill  ·  " .. (p.when or "") .. (p.guild and ("\n<" .. p.guild .. ">") or "") .. "\n" .. #p.names .. " in the raid")
  for k, t in ipairs(viewer.names) do
    local e = p.names[k]
    if e then
      local c = e[2] and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e[2]]
      t:SetText(e[1]); t:SetTextColor(c and c.r or 0.9, c and c.g or 0.86, c and c.b or 0.74); t:Show()
    else t:Hide() end
  end
  viewer.prev:SetEnabled(i > 1); viewer.next:SetEnabled(i < #list)
  viewer.count:SetText(i .. " of " .. #list .. " photos")
  viewer:Show()
end

-- ---------------------------------------------------------------------------
-- Kills, lockouts, the first kill
-- ---------------------------------------------------------------------------
local function bossDown(raid, boss, quiet)
  local a = store(); if not a or not RG.ArcadeGrantDungeon then return end
  a.raidFirst = a.raidFirst or {}; a.raidLock = a.raidLock or {}
  local key = raid .. ":" .. boss
  local lock = lockout()
  if a.raidLock.id ~= lock then a.raidLock = { id = lock, done = {} } end
  if a.raidLock.done[key] then return end
  a.raidLock.done[key] = true
  if not a.raidFirst[key] then
    a.raidFirst[key] = date and date("%Y-%m-%d") or true
    RG.ArcadeGrantDungeon(raid, 2, boss .. " defeated for the first time")
    if not quiet and C_Timer and C_Timer.After then
      C_Timer.After(2, function()
        local p = takePhoto(raid, boss)
        if p and RG.Toast then
          RG.Toast("Raid photo", boss .. ", " .. raid .. ": " .. #p.names .. " in the photo. Two " .. raid:gsub("^The ", "") .. " packs are waiting.",
            "Interface\\Icons\\INV_Misc_Spyglass_02", "See it", function() RG.ArcadeShowPhotos(raid) end, 10)
        end
      end)
    end
  else
    RG.ArcadeGrantDungeon(raid, 1, boss .. " defeated")
  end
end
RG.ArcadeRaidBossDown = bossDown

-- bosses beaten before (the Conqueror achievements tick each one off): counted once, without a photo
local function criterionDone(ach, crit)
  if not GetAchievementCriteriaInfoByID then return false end
  local ok, _, _, done = pcall(GetAchievementCriteriaInfoByID, ach, crit)
  return ok and done == true
end
local function legacyCheck()
  local a = store(); if not a then return end
  a.raidFirst = a.raidFirst or {}
  local got = {}
  for raid, cs in pairs(LEGACY) do
    local d = byName[raid]
    for _, c in ipairs(cs) do
      if criterionDone(c[1], c[2]) and d then
        -- the criterion's boss: the same position in the boss list as in the achievement
        local boss
        if GetAchievementCriteriaInfoByID then local ok, desc = pcall(GetAchievementCriteriaInfoByID, c[1], c[2]); boss = ok and desc or nil end
        if boss and not a.raidFirst[raid .. ":" .. boss] then
          a.raidFirst[raid .. ":" .. boss] = "before"
          RG.ArcadeGrantDungeon(raid, 2)
          got[#got + 1] = boss
        end
      end
    end
  end
  if #got > 0 and RG.Notify then
    RG.Notify("|cffffd36bWaypath Cards:|r raid bosses you've already beaten count: " .. table.concat(got, ", ") .. " (2 packs each, open them from the Album).")
  end
end
RG.ArcadeRaidLegacyCheck = legacyCheck

-- the key: holding it, or having done the quest that gives it
local function keyCheck()
  local a = store(); if not a then return end
  a.raidKeys = a.raidKeys or {}
  for raid, k in pairs(KEYS) do
    if not a.raidKeys[raid] then
      local have = false
      local n = (C_Item and C_Item.GetItemCount and safe(C_Item.GetItemCount, k[1], true)) or (GetItemCount and safe(GetItemCount, k[1], true)) or 0
      if n > 0 then have = true end
      for _, qid in ipairs(k[2]) do
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and safe(C_QuestLog.IsQuestFlaggedCompleted, qid) then have = true end
      end
      if have and RG.ArcadeGiveCard then
        a.raidKeys[raid] = date and date("%Y-%m-%d") or true
        RG.ArcadeGiveCard(k[3], 3)   -- (a key card is a Holo)
        if RG.Toast then
          RG.Toast("Key card", "You're attuned to " .. raid .. ": the " .. k[3] .. " card is yours.", "Interface\\Icons\\INV_Jewelry_Talisman_11", "See it",
            function() if RG.ArcadeOpenAlbum then RG.ArcadeOpenAlbum(raid) end end, 10)
        end
      end
    end
  end
end
RG.ArcadeRaidKeyCheck = keyCheck

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "ENCOUNTER_END", "ACHIEVEMENT_EARNED", "CRITERIA_EARNED", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED", "CHAT_MSG_ADDON" }) do pcall(ev.RegisterEvent, ev, e) end
local pending = {}
local function later(key, delay, fn)
  if pending[key] then return end
  pending[key] = true
  if C_Timer and C_Timer.After then C_Timer.After(delay, function() pending[key] = nil; pcall(fn) end) else pending[key] = nil; pcall(fn) end
end
local onShare
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
  if event == "ENCOUNTER_END" then
    if not (a5 == 1 or a5 == true) then return end
    local hit = encOf[a1]
    local name = (not (RG.IsSecret and RG.IsSecret(a2))) and type(a2) == "string" and a2 or nil
    local raid = hit and hit[1] or (name and bossOf[name:lower()])
    if raid then bossDown(raid, hit and hit[2] or name) end
  elseif event == "ACHIEVEMENT_EARNED" or event == "CRITERIA_EARNED" then later("legacy", 3, legacyCheck)
  elseif event == "QUEST_TURNED_IN" or event == "BAG_UPDATE_DELAYED" then later("key", 2, keyCheck)
  elseif event == "CHAT_MSG_ADDON" then if a1 == PREFIX and onShare then pcall(onShare, a2, a4) end
  elseif event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    later("login", 7, function() legacyCheck(); keyCheck() end)
  end
end)

-- ---------------------------------------------------------------------------
-- Your raid sees your best raid-pack pull (and you see theirs)
-- ---------------------------------------------------------------------------
local function chan() if IsInRaid and IsInRaid() then return "RAID" elseif IsInGroup and IsInGroup() then return "PARTY" end end
onShare = function(text, sender)
  local me = safe(UnitName, "player")
  if not text or (sender and me and sender:match("^[^%-]+") == me) then return end
  if RG.Opt and RG.Opt("arcadeToasts") == false then return end
  local raid, card, f, new = text:match("^W|([^|]+)|([^|]+)|(%d)|(%d)$")
  if not raid or not byName[raid] then return end
  local u = U(); local fin = u and u.FINISH[tonumber(f)] and u.FINISH[tonumber(f)][1] or ""
  if RG.Toast then
    RG.Toast((sender or "?"):match("^[^%-]+") .. "'s pull", card .. " (" .. fin .. ") from a " .. raid:gsub("^The ", "") .. " pack" .. (new == "1" and ": new for them!" or "."),
      "Interface\\Icons\\INV_Misc_Book_09", nil, nil, 6)
  end
end
do
  local orig = RG.ArcadeOpenPack
  if orig then
    RG.ArcadeOpenPack = function(kind, dn, ...)
      local got, free, notes, meta = orig(kind, dn, ...)
      if type(got) == "table" and kind == "dungeon" and dn and byName[dn] and chan() and C_ChatInfo and C_ChatInfo.SendAddonMessage then
        local best
        for _, g in ipairs(got) do
          local sc = (g.card.tier or 1) * 10 + (g.finish or 1)
          if not best or sc > best[1] then best = { sc, g } end
        end
        if best then
          local g = best[2]
          pcall(C_ChatInfo.SendAddonMessage, PREFIX, "W|" .. dn .. "|" .. g.card.name .. "|" .. (g.finish or 1) .. "|" .. (g.new and 1 or 0), chan())
        end
      end
      return got, free, notes, meta
    end
  end
end

-- ---------------------------------------------------------------------------
-- The cards: raid frames, the roar, the Album page
-- ---------------------------------------------------------------------------
local frames = setmetatable({}, { __mode = "k" })
local function raidFrame(w, card, finish)
  local f = frames[w]
  local art = card and finish and frameOf[card.name]
  if not art then if f then f:Hide() end return end
  if not f then
    f = CreateFrame("Frame", nil, w)
    f.tex = f:CreateTexture(nil, "OVERLAY", nil, 1); f.tex:SetAllPoints(); f.tex:SetTexCoord(0, 1, 0, CARD_V)
    f.glow = f:CreateTexture(nil, "OVERLAY", nil, 2); f.glow:SetAllPoints(); f.glow:SetTexCoord(0, 1, 0, CARD_V); f.glow:SetBlendMode("ADD")
    f.t = 0
    f:SetScript("OnUpdate", function(self, dt)
      if not self.pulse then return end
      self.t = self.t + dt
      self.glow:SetAlpha(0.18 + 0.22 * (0.5 + 0.5 * math.sin(self.t * 2.2)))
    end)
    frames[w] = f
  end
  f:SetAllPoints(w)
  f:SetFrameLevel((w:GetFrameLevel() or 1) + 5)
  f.tex:SetTexture(MEDIA .. art); f.glow:SetTexture(MEDIA .. art)
  f.pulse = (finish or 1) >= 3
  f.glow:SetShown(f.pulse)
  f:Show()
end
RG.ArcadeCardHooks = RG.ArcadeCardHooks or {}
table.insert(RG.ArcadeCardHooks, raidFrame)

local function isRaidBoss(c) return c and c.kind == 2 and bossOf[(c.name or ""):lower()] ~= nil end
RG.ArcadeRevealHooks = RG.ArcadeRevealHooks or {}
table.insert(RG.ArcadeRevealHooks, function(card, g, reveal)
  if not isRaidBoss(g.card) then return end
  if RG.ArcadeFx then RG.ArcadeFx("roar") end
  if reveal then reveal.shakeT, reveal.shakeK = 0.9, 3 end
  local m = rawget(card, "model")
  if m and m.SetAnimation then
    pcall(m.SetAnimation, m, 55)   -- (the battle roar)
    if C_Timer and C_Timer.After then C_Timer.After(2.6, function() if card.card == g.card then pcall(m.SetAnimation, m, 0) end end) end
  end
end)

RG.ArcadeTipHooks = RG.ArcadeTipHooks or {}
table.insert(RG.ArcadeTipHooks, function(cd)
  local raid = RG.ArcadeRaidOf(cd.name); if not raid then return false end
  local d = byName[raid]
  for r, k in pairs(KEYS) do
    if k[3] == cd.name then GameTooltip:AddLine("The key to " .. r .. ": earned by being attuned, never in a pack", 0.55, 0.8, 1, true) return true end
  end
  if cd.dun then
    GameTooltip:AddLine("From " .. raid .. " packs: each boss you defeat gives one a week (two the first time)", 0.55, 0.8, 1, true)
  else
    GameTooltip:AddLine("From any pack or a " .. raid .. " pack", 0.55, 0.8, 1, true)
  end
  if not isOpen(d) then GameTooltip:AddLine(raid .. " opens on " .. niceDay(d.raid.opens), 1, 0.82, 0.45) end
  return true
end)

RG.ArcadeAlbumHooks = RG.ArcadeAlbumHooks or {}
table.insert(RG.ArcadeAlbumHooks, function(st, frame)
  local btn = rawget(frame.albOpen, "photoBtn")
  local d = st.raid and byName[st.name]
  if not d then if btn then btn:Hide() end return end
  local a = store()
  local beaten, total = 0, #(d.raid.bosses or {})
  for _, b in ipairs(d.raid.bosses or {}) do if a and a.raidFirst and a.raidFirst[st.name .. ":" .. b] then beaten = beaten + 1 end end
  local extra = isOpen(d) and (beaten .. " of " .. total .. " bosses defeated") or ("opens " .. niceDay(d.raid.opens))
  frame.albTitle:SetText("|cffd9a5ffRAID|r  " .. st.name .. "  |cffa89bc9·  " .. d.raid.size .. " players  ·  " .. extra .. "|r")
  frame.albNext:ClearAllPoints()
  frame.albNext:SetPoint("LEFT", frame.albTitle, "LEFT", math.min(frame.albTitle:GetStringWidth() or 300, 400) + 10, 0)
  if not btn then
    local u = U()
    btn = u.gbtn(frame.albOpen, "Raid photos", 150, 24, function() RG.ArcadeShowPhotos(frame.albOpen.photoRaid) end)
    btn:SetPoint("RIGHT", frame.prev, "LEFT", -14, 0)   -- (beside the page arrows, clear of the title row)
    frame.albOpen.photoBtn = btn
  end
  local n = #photosOf(st.name)
  frame.albOpen.photoRaid = st.name
  btn:SetText(n > 0 and ("Raid photos (" .. n .. ")") or "No raid photos yet")
  btn:SetEnabled(n > 0)
  btn:Show()
end)
