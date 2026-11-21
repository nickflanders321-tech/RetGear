-- Waypath+ cards: the collector's side (1.45).
--  * New cards stay marked "New" in the collection until you've looked at them (hover or open one).
--  * Collector quests: today's goals (Arcade.lua's), the week's (reset on Tuesday) and the month's, with bigger rewards:
--    jumbo and super jumbo packs, and card backs you can't get any other way.
--  * Achievements (the Feats tab): points, titles, card backs and a glow round your showcase.
--  * Rivals: every honorable kill of a player of the other faction is a trophy, and that player becomes a card (their
--    race and sex, their class's raid set). Beat them again and the print climbs: Rare at 3, Holo and "Nemesis" at 5.
--    The same player counts once a day, so it can't be farmed.
local _, RG = ...
local MEDIA = "Interface\\AddOns\\Waypath\\Media\\Arcade\\"
local GOLD = "|cffe8c46a"
local GREEN = "|cff7be08a"
local DIM = "|cffa89bc9"

local function UI() return RG.ArcadeUI end
local function store() local u = UI(); return u and u.store and u.store() end
local function secret(v) return RG.IsSecret and RG.IsSecret(v) end
local function today() return date and date("%Y-%m-%d") or "today" end
local function weekKey()   -- the week starts on Tuesday (the game's own weekly reset day in the Americas)
  if not (date and time) then return "week" end
  local t = time()
  local back = (tonumber(date("%w", t)) - 2) % 7
  return date("%Y-%m-%d", t - back * 86400)
end
local function monthKey() return date and date("%Y-%m") or "month" end
local function hash(s) local h = 0; for i = 1, #s do h = (h * 31 + s:byte(i)) % 100003 end return h end

-- ---------------------------------------------------------------------------
-- A banner at the top of the screen: an achievement, a finished quest, a trophy
-- ---------------------------------------------------------------------------
local banner, queue = nil, {}
local function showNext()
  if not banner or banner:IsShown() or #queue == 0 then return end
  local b = table.remove(queue, 1)
  banner.kind:SetText(b[1]); banner.name:SetText(b[2]); banner.sub:SetText(b[3] or "")
  banner.medal:SetVertexColor(b[4] and b[4][1] or 1, b[4] and b[4][2] or 0.82, b[4] and b[4][3] or 0.4)
  -- (with the cards' window or a pack open, the banner sits just above it, never on its title)
  local over
  for _, n in ipairs({ "WaypathArcadePack", "WaypathArcade" }) do
    local w = _G[n]
    if not over and w and w.IsShown and w:IsShown() and w.GetTop and type(w:GetTop()) == "number" then over = w end
  end
  banner:ClearAllPoints()
  if over then
    local top = over:GetTop() * (over:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local room = (UIParent:GetHeight() or 768) - top
    if room >= 80 then banner:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, top + 8)
    else banner:SetPoint("TOPLEFT", over, "TOPRIGHT", 10, 0) end
  else banner:SetPoint("TOP", UIParent, "TOP", 0, -120) end
  banner.age = 0; banner:SetAlpha(0); banner:Show()
  if RG.ArcadeSound then RG.ArcadeSound("reward") end
end
local function announce(kind, name, sub, col)
  if InCombatLockdown and InCombatLockdown() then
    if RG.Print then RG.Print(kind .. ": " .. name .. (sub and (" (" .. sub .. ")") or "")) end
    return
  end
  if not banner then
    local u = UI(); if not u then return end
    banner = CreateFrame("Frame", "WaypathCardBanner", UIParent, "BackdropTemplate")
    banner:SetFrameStrata("DIALOG"); banner:SetSize(360, 70); banner:SetPoint("TOP", UIParent, "TOP", 0, -120)
    if u.darkPanel then pcall(u.darkPanel, banner, 360, 70) end
    banner.medal = banner:CreateTexture(nil, "ARTWORK"); banner.medal:SetTexture(MEDIA .. "Gem"); banner.medal:SetSize(36, 36); banner.medal:SetPoint("LEFT", 18, 0)
    banner.kind = u.fs(banner, "head", 10); banner.kind:SetPoint("TOPLEFT", banner.medal, "TOPRIGHT", 14, 2); banner.kind:SetTextColor(0.85, 0.75, 0.55)
    banner.name = u.fs(banner, "title", 15); banner.name:SetPoint("TOPLEFT", banner.kind, "BOTTOMLEFT", 0, -3); banner.name:SetWidth(280); banner.name:SetJustifyH("LEFT")
    banner.sub = u.fs(banner, "body", 11); banner.sub:SetPoint("TOPLEFT", banner.name, "BOTTOMLEFT", 0, -3); banner.sub:SetWidth(280); banner.sub:SetJustifyH("LEFT"); banner.sub:SetTextColor(0.85, 0.82, 0.7)
    banner:SetScript("OnUpdate", function(self, dt)
      self.age = self.age + dt
      if self.age < 0.25 then self:SetAlpha(self.age / 0.25)
      elseif self.age > 4.6 then self:SetAlpha(math.max(0, 5.2 - self.age) / 0.6) end
      if self.age > 5.2 then self:Hide(); showNext() end
    end)
    banner:EnableMouse(true); banner:SetScript("OnMouseUp", function(self) self:Hide(); showNext() end)
    banner:Hide()
    if RG.RegisterMover then pcall(RG.RegisterMover, banner, "cardBanner", "Card achievements", { "TOP", "TOP", 0, -120 }) end
  end
  queue[#queue + 1] = { kind, name, sub, col }
  showNext()
end
RG.ArcadeAnnounce = announce

-- ---------------------------------------------------------------------------
-- Rewards: coins, a pack, a card back, a title, the showcase glow
-- ---------------------------------------------------------------------------
local PACKNAME = { normal = "pack", jumbo = "jumbo pack", super = "super jumbo pack" }
local function rewardText(r)
  if not r then return "" end
  local bits = {}
  if r.coins then bits[#bits + 1] = RG.ArcadeBoost(r.coins) .. " coins" end
  if r.pack then bits[#bits + 1] = "a " .. PACKNAME[r.pack] end
  if r.back then bits[#bits + 1] = "the " .. r.back .. " card back" end
  if r.title then bits[#bits + 1] = "the title \"" .. r.title .. "\"" end
  if r.glow then bits[#bits + 1] = "a glow round your showcase" end
  if r.edge then bits[#bits + 1] = "an ember-gold edge on your showcase" end
  return table.concat(bits, ", ")
end
local function pay(a, r)
  if not r then return end
  if r.coins then local c = RG.ArcadeBoost(r.coins); a.coins = (a.coins or 0) + c; a.stats = a.stats or {}; a.stats.bonus = (a.stats.bonus or 0) + c end
  if r.pack then a.tok = a.tok or { normal = 0, jumbo = 0, super = 0 }; a.tok[r.pack] = (a.tok[r.pack] or 0) + 1 end
  if r.back then a.backs = a.backs or {}; a.backs[r.back] = true end
  if r.title then a.titles = a.titles or {}; a.titles[r.title] = true; a.title = a.title or r.title end
  if r.glow then a.showGlow = true end
  if r.edge then a.heartEdge = true end
end
function RG.ArcadeBackUnlocked(a, name) return a and a.backs and a.backs[name] and true or false end
local BACK_HOW = { Cartographer = "Earned by finishing a set in a month's collector quests, or the Cartographer achievement.",
  Ember = "Earned by opening a raid pack (the Chainbreaker achievement) or 8 dungeon packs in a month.",
  Radiant = "Earned by owning a Mythic (the Mythic Hands achievement)." }
function RG.ArcadeBackHow(name) return BACK_HOW[name] end

-- ---------------------------------------------------------------------------
-- Collector quests: the week's and the month's
-- ---------------------------------------------------------------------------
-- ev: the events that count (and how much each counts); the daily goals' own events come from Arcade.lua's
-- goalProgress (packs2 once a pack, new5 with the number of new cards, duel2 a duel won, sell), the rest from this file
local WEEKLY = {
  { id = "w_pack", text = "Open 10 packs", need = 10, ev = { packs2 = 1 }, reward = { coins = 30 } },
  { id = "w_shiny", text = "Pull 3 holos or full arts", need = 3, ev = { shinyCard = 1 }, reward = { coins = 40 } },
  { id = "w_new", text = "Find 15 new cards", need = 15, ev = { new5 = 1 }, reward = { coins = 35 } },
  { id = "w_duel", text = "Win 5 duels", need = 5, ev = { duel2 = 1 }, reward = { coins = 30 } },
  { id = "w_dun", text = "Open a dungeon or raid pack", need = 1, ev = { dunpack = 1 }, reward = { pack = "jumbo" } },
  { id = "w_rival", text = "Beat 3 rivals in PvP", need = 3, ev = { rival = 1 }, reward = { coins = 40 } },
  { id = "w_stage", text = "Finish a set stage", need = 1, ev = { set = 1 }, reward = { coins = 50 } },
}
local MONTHLY = {
  { id = "m_set", text = "Finish any set", need = 1, ev = { setDone = 1 }, reward = { back = "Cartographer" }, always = true },
  { id = "m_meet", text = "Meet 15 raiders or rivals", need = 15, ev = { raider = 1, rival = 1 }, reward = { pack = "super" } },
  { id = "m_leg", text = "Pull a Legendary", need = 1, ev = { legend = 1 }, reward = { coins = 150 } },
  { id = "m_pack", text = "Open 40 packs", need = 40, ev = { packs2 = 1 }, reward = { pack = "super" } },
  { id = "m_field", text = "Finish a Field Guide page", need = 1, ev = { field = 1 }, reward = { coins = 100 } },
  { id = "m_dun", text = "Open 8 dungeon or raid packs", need = 8, ev = { dunpack = 1 }, reward = { back = "Ember" } },
}
local function pick(list, key, n)
  local out, used, k = {}, {}, 0
  for i, q in ipairs(list) do if q.always then out[#out + 1] = q; used[i] = true end end
  local seed = hash(key)
  while #out < n and k < 50 do
    local i = (seed + k * 3) % #list + 1; k = k + 1
    if not used[i] then used[i] = true; out[#out + 1] = list[i] end
  end
  return out
end
local function quests(a)
  a.cq = a.cq or {}
  local q = a.cq
  local wk, mk = weekKey(), monthKey()
  if q.week ~= wk then q.week, q.wprog, q.wdone = wk, {}, {} end
  if q.month ~= mk then q.month, q.mprog, q.mdone = mk, {}, {} end
  return q, pick(WEEKLY, wk, 4), pick(MONTHLY, mk, 3)
end
local function questEvent(a, id, n)
  local q, wk, mo = quests(a)
  for _, pair in ipairs({ { wk, q.wprog, q.wdone, "This week's quest" }, { mo, q.mprog, q.mdone, "This month's quest" } }) do
    for _, d in ipairs(pair[1]) do
      local w = d.ev[id]
      if w and not pair[3][d.id] then
        pair[2][d.id] = math.min(d.need, (pair[2][d.id] or 0) + w * (n or 1))
        if pair[2][d.id] >= d.need then
          pair[3][d.id] = true
          pay(a, d.reward)
          announce(pair[4] .. " done", d.text, rewardText(d.reward), { 0.48, 0.88, 0.54 })
        end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Achievements
-- ---------------------------------------------------------------------------
local function countSets(a, pred, stage)
  local u = UI(); local n = 0
  for _, s in ipairs(u.getSets() or {}) do
    local paid = (a.setStage or {})[s.name] or (((a.setsDone or {})[s.name]) and 1 or 0)
    if paid >= (stage or 1) and (not pred or pred(s)) then n = n + 1 end
  end
  return n
end
local function ownedWhere(a, pred)
  local u = UI(); local n = 0
  for _, c in ipairs(u.CARDS) do if pred(c) and u.owned(a, c.id) > 0 then n = n + 1 end end
  return n
end
local function cnt(a, k) return (a.feat and a.feat.n and a.feat.n[k]) or 0 end
local function size(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
local CATS = { { "sets", "Sets" }, { "pulls", "Pulls" }, { "people", "Raiders & Rivals" }, { "dungeons", "Dungeons" }, { "field", "Field Guide" }, { "duels", "Duels & Arena" } }
local FEATS = {
  { id = "set1", cat = "sets", name = "First Set", text = "Finish the first stage of any set.", pts = 10, need = 1, have = function(a) return countSets(a) end, reward = { title = "Collector" } },
  { id = "set5", cat = "sets", name = "Five Sets", text = "Finish the first stage of 5 sets.", pts = 20, need = 5, have = function(a) return countSets(a) end, reward = { coins = 100 } },
  { id = "setgold", cat = "sets", name = "Gold Standard", text = "Finish all three stages of a set.", pts = 25, need = 1, have = function(a) return countSets(a, nil, 3) end, reward = { title = "Gold Collector" } },
  { id = "cards250", cat = "sets", name = "A Growing Album", text = "Own 250 different cards.", pts = 15, need = 250, have = function(a) return ownedWhere(a, function() return true end) end, reward = { coins = 75 } },
  { id = "cards1000", cat = "sets", name = "The Great Album", text = "Own 1,000 different cards.", pts = 50, need = 1000, have = function(a) return ownedWhere(a, function() return true end) end, reward = { title = "Archivist" } },
  { id = "carto", cat = "sets", name = "Cartographer", text = "Own 40 place cards.", pts = 30, need = 40, have = function(a) return ownedWhere(a, function(c) return c.kind == 3 end) end, reward = { back = "Cartographer" } },
  { id = "holo1", cat = "pulls", name = "First Light", text = "Pull a holo.", pts = 5, need = 1, have = function(a) return cnt(a, "holo") end, reward = { coins = 10 } },
  { id = "full1", cat = "pulls", name = "Edge to Edge", text = "Pull a Full art print.", pts = 10, need = 1, have = function(a) return cnt(a, "full") end, reward = { coins = 25 } },
  { id = "leg1", cat = "pulls", name = "Legend in Hand", text = "Pull a Legendary.", pts = 15, need = 1, have = function(a) return cnt(a, "legend") end, reward = { coins = 40 } },
  { id = "gilded", cat = "pulls", name = "Golden Hand", text = "Pull a Legendary in Full art.", pts = 50, need = 1, have = function(a) return cnt(a, "gilded") end, reward = { title = "the Gilded" } },
  { id = "climb", cat = "pulls", name = "Climber", text = "See a print climb as it turns over.", pts = 10, need = 1, have = function(a) return cnt(a, "upgrade") end, reward = { coins = 25 } },
  { id = "packs100", cat = "pulls", name = "Pack Rat", text = "Open 100 packs.", pts = 20, need = 100, have = function(a) return a.packs or 0 end, reward = { title = "Pack Rat" } },
  { id = "mythic", cat = "pulls", name = "Mythic Hands", text = "Own a Mythic.", pts = 100, need = 1, have = function(a) return ownedWhere(a, function(c) return c.tier == 7 end) end, reward = { back = "Radiant", glow = true } },
  { id = "meet10", cat = "people", name = "Good Company", text = "Meet 10 raiders.", pts = 10, need = 10, have = function(a) return size(a.raiders) end, reward = { coins = 30 } },
  { id = "meet25", cat = "people", name = "Many Friends", text = "Meet 25 raiders.", pts = 20, need = 25, have = function(a) return size(a.raiders) end, reward = { glow = true } },
  { id = "rival1", cat = "people", name = "First Blood", text = "Win your first rival card in PvP.", pts = 10, need = 1, have = function(a) return size(a.rivals) end, reward = { coins = 30 } },
  { id = "rivals10", cat = "people", name = "Rivalry", text = "Win rival cards of 10 different players.", pts = 25, need = 10, have = function(a) return size(a.rivals) end, reward = { title = "Duelist of the Field" } },
  { id = "nemesis", cat = "people", name = "Nemesis", text = "Beat the same rival 5 times.", pts = 20, need = 5, have = function(a) local m = 0; for _, r in pairs(a.rivals or {}) do if type(r) == "table" then m = math.max(m, r.n or 0) end end; return m end, reward = { title = "Nemesis" } },
  { id = "crate1", cat = "dungeons", name = "Crate Breaker", text = "Open a dungeon pack.", pts = 10, need = 1, have = function(a) return cnt(a, "dunpack") end, reward = { coins = 25 } },
  { id = "crate25", cat = "dungeons", name = "Delver", text = "Open 25 dungeon packs.", pts = 25, need = 25, have = function(a) return cnt(a, "dunpack") end, reward = { title = "Delver" } },
  { id = "chains", cat = "dungeons", name = "Chainbreaker", text = "Open a raid pack.", pts = 15, need = 1, have = function(a) return cnt(a, "raidpack") end, reward = { back = "Ember" } },
  { id = "dunsets", cat = "dungeons", name = "Keeper of Many Doors", text = "Finish the first stage of 5 dungeon sets.", pts = 30, need = 5, have = function(a) return countSets(a, function(s) return s.dungeon and not s.field end) end, reward = { title = "Keeper of Doors" } },
  { id = "field1", cat = "field", name = "Naturalist", text = "Finish a Field Guide page.", pts = 15, need = 1, have = function(a) return countSets(a, function(s) return s.field end) end, reward = { title = "Naturalist" } },
  { id = "field10", cat = "field", name = "Field Researcher", text = "Finish 10 Field Guide pages.", pts = 30, need = 10, have = function(a) return countSets(a, function(s) return s.field end) end, reward = { coins = 150 } },
  { id = "duel10", cat = "duels", name = "Duelist", text = "Win 10 duels.", pts = 10, need = 10, have = function(a) return cnt(a, "duel") end, reward = { coins = 30 } },
  { id = "duel50", cat = "duels", name = "Champion", text = "Win 50 duels.", pts = 30, need = 50, have = function(a) return cnt(a, "duel") end, reward = { title = "Champion" } },
  { id = "archm", cat = "duels", name = "The Archmage's Bane", text = "Beat the Archmage in the Arena.", pts = 15, need = 1, have = function(a) return cnt(a, "archm") end, reward = { coins = 50 } },
  { id = "owl", cat = "pulls", hidden = true, name = "Night Owl", text = "Open a pack between 2 and 5 in the morning.", pts = 5, need = 1, have = function(a) return cnt(a, "owl") end, reward = { coins = 15 } },
}
RG.ARCADE_FEATS = FEATS
-- more achievements from other files (ArcadeMythicPlus.lua's Hearts and the Six): a category and its list
function RG.ArcadeFeatsAdd(cat, catName, list)
  local have = false
  for _, c in ipairs(CATS) do if c[1] == cat then have = true end end
  if not have then CATS[#CATS + 1] = { cat, catName } end
  for _, f in ipairs(list) do f.cat = f.cat or cat; FEATS[#FEATS + 1] = f end
end
-- (other files' rewards: a title, a back, a glow, coins, or anything they pay themselves)
RG.ArcadeFeatPay = function(a, r) end
local function featState(a)
  a.feat = a.feat or {}; a.feat.earned = a.feat.earned or {}; a.feat.n = a.feat.n or {}
  return a.feat
end
local function points(a)
  local st, p = featState(a), 0
  for _, f in ipairs(FEATS) do if st.earned[f.id] then p = p + f.pts end end
  return p
end
RG.ArcadeFeatPoints = function() local a = store(); return a and points(a) or 0 end
local function checkFeats(a)
  local st = featState(a)
  for _, f in ipairs(FEATS) do
    if not st.earned[f.id] then
      local ok, have = pcall(f.have, a)
      if ok and (have or 0) >= f.need then
        st.earned[f.id] = today()
        pay(a, f.reward)
        announce("Achievement  ·  " .. f.pts .. " points", f.name, rewardText(f.reward), { 1, 0.82, 0.4 })
      end
    end
  end
end
local function bump(a, k, n) local st = featState(a); st.n[k] = (st.n[k] or 0) + (n or 1) end

-- every event the quests and achievements count
function RG.ArcadeQuestEvent(id, n, s, stage)
  local a = store(); if not a then return end
  if id == "duel2" then bump(a, "duel", n) elseif id == "archm" then bump(a, "archm", n) end
  if id == "set" and s then
    if stage == 1 then questEvent(a, "setDone", 1) end
    if s.field and stage == 1 then questEvent(a, "field", 1) end
  end
  questEvent(a, id, n)
  checkFeats(a)
end
-- a pack was opened (Arcade.lua): count its holos, full arts, Legendaries, climbs, and what kind of pack it was
function RG.ArcadeCollectorPack(got, meta)
  local a = store(); if not a then return end
  local shiny = 0
  for _, g in ipairs(got or {}) do
    if g.finish >= 3 then shiny = shiny + 1 end
    if g.finish == 3 then bump(a, "holo") end
    if g.finish == 4 then bump(a, "full") end
    if g.card.tier == 5 then bump(a, "legend"); questEvent(a, "legend", 1); if g.finish == 4 then bump(a, "gilded") end end
    if g.upgraded then bump(a, "upgrade") end
  end
  if shiny > 0 then questEvent(a, "shinyCard", shiny) end
  if meta and meta.dungeon then
    bump(a, "dunpack"); questEvent(a, "dunpack", 1)
    for _, d in ipairs(RG.ARCADE_DUNGEONS or {}) do if d[1] == meta.dungeon and d.raid then bump(a, "raidpack") end end
  end
  local h = date and tonumber(date("%H"))
  if h and h >= 2 and h < 5 then bump(a, "owl") end
  checkFeats(a)
end

-- ---------------------------------------------------------------------------
-- Rivals: the players of the other faction you beat
-- ---------------------------------------------------------------------------
local UNITS = { "target", "mouseover", "focus" }
for i = 1, 40 do UNITS[#UNITS + 1] = "nameplate" .. i end
local function findPlayer(name)
  for _, u in ipairs(UNITS) do
    local ok, ex = pcall(UnitExists, u)
    if ok and ex and not secret(ex) then
      local ok2, isP = pcall(UnitIsPlayer, u)
      local ok3, n = pcall(UnitName, u)
      if ok2 and isP and ok3 and type(n) == "string" and not secret(n) and n == name then
        local _, cls = UnitClass(u)
        local _, race = UnitRace(u)
        local sex = UnitSex(u)
        if type(cls) == "string" and type(race) == "string" and not secret(cls) and not secret(race) then return cls, race, sex end
      end
    end
  end
end
function RG.ArcadeRivalBeaten(name, class, race, sex, where)
  local a = store(); if not a or type(name) ~= "string" or name == "" then return end
  name = name:match("^([^-]+)") or name
  a.rivals = a.rivals or {}
  local r = a.rivals[name]
  if r and r.day == today() then return end   -- once a day for the same player
  if not r then
    if not class then return end
    if size(a.rivals) >= 150 then return end
    r = { class = class, race = race, sex = sex, n = 0 }; a.rivals[name] = r
  end
  r.n = (r.n or 0) + 1; r.day = today(); r.when = date and date("%d %b") or ""; r.where = where
  local c = RG.ArcadeAddRival(name, r.class, r.race, r.sex, r.n)
  if not c then return end
  local key = c.key
  a.cards[key] = a.cards[key] or {}
  local slot = a.cards[key]
  local f = r.n >= 5 and 3 or (r.n >= 3 and 2 or 1)
  local newPrint = (slot[f] or 0) == 0
  if newPrint then slot[f] = 1 end
  local cname = r.class:sub(1, 1) .. r.class:sub(2):lower()
  local ri = RG.ArcadeRaceInfo and RG.ArcadeRaceInfo(r.race)
  announce("Trophy", name, ((ri and ri.name) and (ri.name .. " ") or "") .. cname .. "   ·   beaten " .. r.n .. (r.n == 1 and " time" or " times")
    .. (r.n == 1 and "   ·   a new Rival card" or (newPrint and (f == 3 and "   ·   Nemesis: a Holo print" or "   ·   a Rare print") or "")), { 1, 0.42, 0.35 })
  RG.ArcadeQuestEvent("rival", 1)
  if RG.ArcadeRefresh then pcall(RG.ArcadeRefresh, true) end
end
do
  local ev = CreateFrame("Frame")
  pcall(ev.RegisterEvent, ev, "CHAT_MSG_COMBAT_HONOR_GAIN")
  ev:SetScript("OnEvent", function(_, _, text)
    if type(text) ~= "string" or secret(text) then return end
    -- "Name dies, honorable kill Rank: ... (Estimated Honor Points: ...)"
    local name = text:match("^(.-) dies, honorable kill") or text:match("^(.-) dies")
    if not name or name == "" then return end
    local cls, race, sex = findPlayer(name)
    local where = GetZoneText and GetZoneText() or nil
    local a = store()
    if cls or (a and a.rivals and a.rivals[name]) then RG.ArcadeRivalBeaten(name, cls, race, sex, where) end
  end)
end

-- ---------------------------------------------------------------------------
-- On the cards: "New" until you've looked, Nemesis, the showcase's glow
-- ---------------------------------------------------------------------------
local tags = setmetatable({}, { __mode = "k" })
local function tagFor(w)
  local t = tags[w]
  if t then return t end
  local u = UI()
  t = CreateFrame("Frame", nil, w); if RG.ArcadeLayer then RG.ArcadeLayer(w, t, 8) else t:SetFrameLevel((w:GetFrameLevel() or 1) + 8) end
  t.bg = t:CreateTexture(nil, "ARTWORK"); t.bg:SetAllPoints(); t.bg:SetColorTexture(0.96, 0.82, 0.45, 1)
  t.txt = u.fs(t, "head", 8); t.txt:SetPoint("CENTER", 0, 0); t.txt:SetTextColor(0.16, 0.1, 0.03); t.txt:SetShadowColor(0, 0, 0, 0)
  tags[w] = t
  return t
end
RG.ArcadeCardHooks = RG.ArcadeCardHooks or {}
table.insert(RG.ArcadeCardHooks, function(w, card, finish)
  local a = card and finish and store()
  local fresh = a and w.collect and a.fresh and a.fresh[card.key or card.name]
  local nem = card and finish and card.rival and (card.beaten or 0) >= 5
  local t = tags[w]
  if not (fresh or nem) or (w.cw or 0) < 70 then if t then t:Hide() end
  else
    t = tagFor(w)
    local u = w.u or 1
    -- (beside the cost, not over it)
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", w, "TOPLEFT", 47 * u, -7 * u); t:SetSize(math.max(28, 54 * u), math.max(11, 16 * u))
    t.txt:SetText(fresh and "NEW" or "NEMESIS")
    if fresh then t.bg:SetColorTexture(0.96, 0.82, 0.45, 1) else t.bg:SetColorTexture(0.85, 0.25, 0.2, 1) end
    t:Show()
  end
  -- the showcase glow (an achievement's reward): pinned cards in your collection glow gold
  if a and (a.showGlow or a.heartEdge) and w.collect and w.aura then
    for _, k in ipairs(a.showcase or {}) do
      if k == (card.key or card.name) then if a.heartEdge then w.aura:SetVertexColor(1, 0.55, 0.2, 1) else w.aura:SetVertexColor(1, 0.84, 0.4, 1) end; w.aura:SetAlpha(math.max(w.aura:GetAlpha() or 0, 0.4)); w.aura:Show() end
    end
  end
end)
function RG.ArcadeSeen(w)
  local a = store(); local c = w and w.card
  if not (a and c and a.fresh and a.fresh[c.key or c.name]) then return end
  a.fresh[c.key or c.name] = nil
  local t = tags[w]; if t then t:Hide() end
end

-- ---------------------------------------------------------------------------
-- The Today tab's three columns: today's goals, the week's, the month's
-- ---------------------------------------------------------------------------
local qcol
local function questRow(parent, u)
  -- the quest's name on its own line, its reward and progress under it, the bar along the bottom
  local r = CreateFrame("Frame", nil, parent)
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(0.94, 0.89, 0.78, 1)
  r.name = u.fs(r, "body", 12); r.name:SetPoint("TOPLEFT", 9, -6); r.name:SetPoint("TOPRIGHT", -8, -6); r.name:SetJustifyH("LEFT")
  if r.name.SetWordWrap then r.name:SetWordWrap(false) end
  r.name:SetTextColor(0.17, 0.11, 0.05); r.name:SetShadowColor(0, 0, 0, 0)
  r.rw = u.fs(r, "head", 9); r.rw:SetPoint("BOTTOMLEFT", 9, 13); r.rw:SetJustifyH("LEFT"); r.rw:SetTextColor(0.55, 0.36, 0.1); r.rw:SetShadowColor(0, 0, 0, 0)
  r.pr = u.fs(r, "head", 9); r.pr:SetPoint("BOTTOMRIGHT", -8, 13); r.pr:SetJustifyH("RIGHT"); r.pr:SetTextColor(0.42, 0.31, 0.15); r.pr:SetShadowColor(0, 0, 0, 0)
  r.barBg = r:CreateTexture(nil, "ARTWORK"); r.barBg:SetColorTexture(0.82, 0.74, 0.54, 1); r.barBg:SetHeight(4); r.barBg:SetPoint("BOTTOMLEFT", 9, 6); r.barBg:SetPoint("BOTTOMRIGHT", -8, 6)
  r.bar = r:CreateTexture(nil, "OVERLAY"); r.bar:SetHeight(4); r.bar:SetPoint("BOTTOMLEFT", r.barBg, "BOTTOMLEFT", 0, 0)
  return r
end
local function fillRow(r, name, prog, need, done, rw, bw)
  r.name:SetText(name); r.rw:SetText(rw or "")
  local k = math.max(0, math.min(1, (prog or 0) / math.max(1, need)))
  r.bar:SetWidth(math.max(1, bw * k)); r.bar:SetColorTexture(done and 0.42 or 0.72, done and 0.66 or 0.53, done and 0.3 or 0.17, 1)
  r.bg:SetColorTexture(done and 0.86 or 0.94, done and 0.91 or 0.89, done and 0.79 or 0.78, 1)
  r.pr:SetText(done and "DONE" or (math.min(prog or 0, need) .. " / " .. need))
  r:Show()
end
local function shortReward(r)
  if not r then return "" end
  if r.back then return "CARD BACK" end
  if r.pack then return (r.pack == "super" and "SUPER JUMBO" or (r.pack == "jumbo" and "JUMBO" or "PACK")) end
  if r.coins then return RG.ArcadeBoost(r.coins) .. " COINS" end
  return ""
end
function RG.ArcadeQuestColumns(ctx)
  local u = UI(); local a = ctx.a
  if not qcol then
    qcol = CreateFrame("Frame", nil, ctx.frame); qcol:SetFrameLevel((ctx.frame:GetFrameLevel() or 1) + 3)
    qcol.cols = {}
    for c = 1, 3 do
      local col = CreateFrame("Frame", nil, qcol)
      col.bg = col:CreateTexture(nil, "BACKGROUND"); col.bg:SetAllPoints(); col.bg:SetColorTexture(0.12, 0.09, 0.06, 0.92)
      col.edge = col:CreateTexture(nil, "BACKGROUND", nil, -8); col.edge:SetPoint("TOPLEFT", -1, 1); col.edge:SetPoint("BOTTOMRIGHT", 1, -1); col.edge:SetColorTexture(0.42, 0.31, 0.14, 0.9)
      col.head = u.fs(col, "title", 13); col.head:SetPoint("TOPLEFT", 10, -9); col.head:SetTextColor(1, 0.88, 0.54)
      col.when = u.fs(col, "body", 11); col.when:SetPoint("TOPRIGHT", -10, -11); col.when:SetTextColor(0.86, 0.78, 0.6)
      col.rows = {}
      for i = 1, 4 do col.rows[i] = questRow(col, u) end
      col.note = u.fs(col, "body", 11); col.note:SetJustifyH("LEFT"); col.note:SetTextColor(0.84, 0.77, 0.62)
      qcol.cols[c] = col
    end
  end
  qcol:ClearAllPoints(); qcol:SetPoint("TOPLEFT", ctx.frame, "TOPLEFT", ctx.x, -ctx.y); qcol:SetSize(ctx.w, ctx.h)
  local gap = 12
  local cw = (ctx.w - 2 * gap) / 3
  local q, wk, mo = quests(a)
  local function place(col, i)
    col:ClearAllPoints(); col:SetPoint("TOPLEFT", qcol, "TOPLEFT", (i - 1) * (cw + gap), 0); col:SetSize(cw, ctx.h)
    for k, r in ipairs(col.rows) do r:ClearAllPoints(); r:SetPoint("TOPLEFT", col, "TOPLEFT", 8, -34 - (k - 1) * 48); r:SetSize(cw - 16, 44); r:Hide() end
    col.note:ClearAllPoints(); col.note:SetPoint("BOTTOMLEFT", 10, 8); col.note:SetWidth(cw - 20)
  end
  local bw = cw - 16 - 17
  -- today
  local c1 = qcol.cols[1]; place(c1, 1)
  c1.head:SetText("TODAY"); c1.when:SetText("new goals tomorrow")
  local n = 0
  for _, id in ipairs(ctx.g.pick or {}) do
    for _, d in ipairs(ctx.GOALS) do
      if d[1] == id and n < 4 then n = n + 1; fillRow(c1.rows[n], d[2], ctx.g.prog[id] or 0, d[3], ctx.g.done[id], d[4] .. " COINS", bw) end
    end
  end
  c1.note:SetText("")
  -- the week
  local c2 = qcol.cols[2]; place(c2, 2)
  c2.head:SetText("THIS WEEK"); c2.when:SetText("resets Tuesday")
  for i, d in ipairs(wk) do fillRow(c2.rows[i], d.text, q.wprog[d.id] or 0, d.need, q.wdone[d.id], shortReward(d.reward), bw) end
  c2.note:SetText("")
  -- the month
  local c3 = qcol.cols[3]; place(c3, 3)
  c3.head:SetText("THIS MONTH")
  local endDay = ""
  if date and time then
    local t = time(); local y, m = tonumber(date("%Y", t)), tonumber(date("%m", t))
    local nextM = time({ year = m == 12 and y + 1 or y, month = m == 12 and 1 or m + 1, day = 1, hour = 0 })
    endDay = "ends " .. date("%d %b", nextM - 86400)
  end
  c3.when:SetText(endDay)
  for i, d in ipairs(mo) do fillRow(c3.rows[i], d.text, q.mprog[d.id] or 0, d.need, q.mdone[d.id], shortReward(d.reward), bw) end
  c3.note:SetText("A month's quests unlock card backs you can't get any other way.")
  qcol:Show()
  return true
end

-- ---------------------------------------------------------------------------
-- The Feats tab
-- ---------------------------------------------------------------------------
local fp
local FS = { cat = "sets", page = 0 }   -- (the tab's state, in a plain table)
local PER = 8
local function featRow(parent, u)
  local r = CreateFrame("Button", nil, parent)
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(0.94, 0.89, 0.78, 1)
  r.medal = r:CreateTexture(nil, "ARTWORK"); r.medal:SetTexture(MEDIA .. "Medal"); r.medal:SetSize(36, 36); r.medal:SetPoint("LEFT", 8, 0)
  r.name = u.fs(r, "title", 12); r.name:SetPoint("TOPLEFT", 54, -4); r.name:SetJustifyH("LEFT"); r.name:SetTextColor(0.17, 0.11, 0.05); r.name:SetShadowColor(0, 0, 0, 0)
  r.desc = u.fs(r, "body", 11); r.desc:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2); r.desc:SetJustifyH("LEFT"); r.desc:SetTextColor(0.3, 0.22, 0.12); r.desc:SetShadowColor(0, 0, 0, 0)
  r.rw = u.fs(r, "head", 8.5); r.rw:SetPoint("BOTTOMLEFT", 54, 8); r.rw:SetPoint("BOTTOMRIGHT", -40, 8); r.rw:SetJustifyH("LEFT")
  if r.rw.SetWordWrap then r.rw:SetWordWrap(false) end; r.rw:SetTextColor(0.55, 0.36, 0.1); r.rw:SetShadowColor(0, 0, 0, 0)
  r.pts = u.fs(r, "title", 15); r.pts:SetPoint("RIGHT", -10, 0); r.pts:SetTextColor(0.55, 0.42, 0.16); r.pts:SetShadowColor(0, 0, 0, 0)
  r.barBg = r:CreateTexture(nil, "ARTWORK"); r.barBg:SetColorTexture(0.82, 0.74, 0.54, 1); r.barBg:SetHeight(3); r.barBg:SetPoint("BOTTOMLEFT", 54, 3); r.barBg:SetPoint("BOTTOMRIGHT", -40, 3)   -- (a thin line under the reward)
  r.bar = r:CreateTexture(nil, "OVERLAY"); r.bar:SetHeight(4); r.bar:SetPoint("BOTTOMLEFT", r.barBg, "BOTTOMLEFT", 0, 0); r.bar:SetColorTexture(0.72, 0.53, 0.17, 1)
  r:SetScript("OnClick", function(self)
    local a = store(); local f = self.feat
    if a and f and f.reward and f.reward.title and featState(a).earned[f.id] then
      a.title = f.reward.title
      if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
    end
  end)
  return r
end
local function buildFeats(frame, u)
  fp = CreateFrame("Frame", nil, frame); fp:SetAllPoints(frame); fp:SetFrameLevel((frame:GetFrameLevel() or 1) + 4)
  FS.cats = {}
  for i, c in ipairs(CATS) do
    local b = CreateFrame("Button", nil, fp)
    b:SetSize(170, 30); b:SetPoint("TOPLEFT", fp, "TOPLEFT", 40, -196 - (i - 1) * 33)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
    b.l = u.fs(b, "head", 11); b.l:SetPoint("LEFT", 12, 0)
    b.r = u.fs(b, "body", 11); b.r:SetPoint("RIGHT", -10, 0); b.r:SetTextColor(0.66, 0.58, 0.42)
    b:SetScript("OnClick", function() FS.cat = c[1]; FS.page = 0; RG.ArcadeRefresh(true) end)
    b.key = c[1]
    FS.cats[i] = b
  end
  fp.ptsBox = CreateFrame("Frame", nil, fp); fp.ptsBox:SetSize(170, 64); fp.ptsBox:SetPoint("TOPLEFT", fp, "TOPLEFT", 40, -(196 + #CATS * 33 + 6))
  fp.ptsBox.bg = fp.ptsBox:CreateTexture(nil, "BACKGROUND"); fp.ptsBox.bg:SetAllPoints(); fp.ptsBox.bg:SetColorTexture(0.14, 0.1, 0.05, 0.95)
  fp.ptsL = u.fs(fp.ptsBox, "head", 10); fp.ptsL:SetPoint("TOPLEFT", 12, -10); fp.ptsL:SetTextColor(0.86, 0.78, 0.6); fp.ptsL:SetText("COLLECTOR POINTS")
  -- the next achievement within reach, from any category
  fp.near = CreateFrame("Frame", nil, fp); fp.near:SetSize(170, 96); fp.near:SetPoint("TOPLEFT", fp.ptsBox, "BOTTOMLEFT", 0, -10)
  fp.near.bg = fp.near:CreateTexture(nil, "BACKGROUND"); fp.near.bg:SetAllPoints(); fp.near.bg:SetColorTexture(0.14, 0.1, 0.05, 0.95)
  fp.nextL = u.fs(fp.near, "head", 10); fp.nextL:SetPoint("TOPLEFT", 12, -10); fp.nextL:SetTextColor(0.86, 0.78, 0.6); fp.nextL:SetText("CLOSEST NEXT")
  fp.nextN = u.fs(fp.near, "title", 13); fp.nextN:SetPoint("TOPLEFT", 12, -28); fp.nextN:SetWidth(148); fp.nextN:SetJustifyH("LEFT"); fp.nextN:SetTextColor(1, 0.92, 0.7)
  fp.nextT = u.fs(fp.near, "body", 11); fp.nextT:SetPoint("TOPLEFT", fp.nextN, "BOTTOMLEFT", 0, -3); fp.nextT:SetWidth(148); fp.nextT:SetJustifyH("LEFT"); fp.nextT:SetTextColor(0.82, 0.76, 0.64)
  fp.nextBg = fp.near:CreateTexture(nil, "ARTWORK"); fp.nextBg:SetColorTexture(0.3, 0.24, 0.14, 1); fp.nextBg:SetSize(146, 4); fp.nextBg:SetPoint("BOTTOMLEFT", 12, 10)
  fp.nextBar = fp.near:CreateTexture(nil, "OVERLAY"); fp.nextBar:SetColorTexture(0.91, 0.77, 0.42, 1); fp.nextBar:SetHeight(4); fp.nextBar:SetPoint("BOTTOMLEFT", fp.nextBg, "BOTTOMLEFT", 0, 0)
  fp.pts = u.fs(fp.ptsBox, "title", 26); fp.pts:SetPoint("BOTTOMLEFT", 12, 8); fp.pts:SetTextColor(1, 0.88, 0.54)
  fp.rows = {}
  for i = 1, PER do
    local r = featRow(fp, u); r:SetSize(330, 50); r:SetPoint("TOPLEFT", fp, "TOPLEFT", 222, -196 - (i - 1) * 54); fp.rows[i] = r
  end
  fp.prev = u.gbtn(fp, "<", 30, 22, function() FS.page = math.max(0, (FS.page or 0) - 1); RG.ArcadeRefresh(true) end); fp.prev:SetPoint("TOPLEFT", fp, "TOPLEFT", 222, -634)
  fp.next = u.gbtn(fp, ">", 30, 22, function() FS.page = (FS.page or 0) + 1; RG.ArcadeRefresh(true) end); fp.next:SetPoint("LEFT", fp.prev, "RIGHT", 6, 0)
  FS.pageT = u.fs(fp, "head", 11); FS.pageT:SetPoint("LEFT", fp.next, "RIGHT", 10, 0); FS.pageT:SetTextColor(0.8, 0.72, 0.52)
  -- what others see
  fp.who = CreateFrame("Frame", nil, fp); fp.who:SetSize(186, 250); fp.who:SetPoint("TOPLEFT", fp, "TOPLEFT", 564, -214)
  fp.who.bg = fp.who:CreateTexture(nil, "BACKGROUND"); fp.who.bg:SetAllPoints(); fp.who.bg:SetColorTexture(0.12, 0.09, 0.06, 0.95)
  fp.who.edge = fp.who:CreateTexture(nil, "BACKGROUND", nil, -8); fp.who.edge:SetPoint("TOPLEFT", -1, 1); fp.who.edge:SetPoint("BOTTOMRIGHT", 1, -1); fp.who.edge:SetColorTexture(0.55, 0.41, 0.16, 0.9)
  fp.whoH = u.fs(fp, "head", 10); fp.whoH:SetPoint("BOTTOMLEFT", fp.who, "TOPLEFT", 0, 6); fp.whoH:SetTextColor(0.66, 0.6, 0.72); fp.whoH:SetText("WHAT OTHERS SEE")
  fp.whoName = u.fs(fp.who, "title", 15); fp.whoName:SetPoint("TOPLEFT", 12, -12); fp.whoName:SetTextColor(1, 0.95, 0.82)
  fp.whoTitle = u.fs(fp.who, "body", 13); fp.whoTitle:SetPoint("TOPLEFT", fp.whoName, "BOTTOMLEFT", 0, -4); fp.whoTitle:SetTextColor(0.91, 0.77, 0.42)
  fp.whoCards = {}
  for i = 1, 3 do
    local c = u.makeCard(fp.who, 52); c:SetPoint("TOPLEFT", fp.who, "TOPLEFT", 12 + (i - 1) * 58, -64); c.noTip = true; c:EnableMouse(false); fp.whoCards[i] = c
  end
  fp.whoPts = u.fs(fp.who, "head", 10); fp.whoPts:SetPoint("BOTTOMLEFT", 12, 12); fp.whoPts:SetTextColor(0.86, 0.78, 0.6)
  fp.whoEmpty = u.fs(fp.who, "body", 11); fp.whoEmpty:SetPoint("TOPLEFT", 12, -70); fp.whoEmpty:SetWidth(162); fp.whoEmpty:SetJustifyH("LEFT"); fp.whoEmpty:SetTextColor(0.72, 0.66, 0.56)
  fp.whoEmpty:SetText("Your showcase is empty. Open a card you own and choose Showcase: your first three pinned cards show here.")
  fp.hint = u.fs(fp, "body", 12); fp.hint:SetPoint("TOPLEFT", fp.who, "BOTTOMLEFT", 0, -12); fp.hint:SetWidth(186); fp.hint:SetJustifyH("LEFT"); fp.hint:SetTextColor(0.8, 0.76, 0.84)
  fp.hint:SetText("Your title and points show on your showcase and in friends' albums. Click an achievement you've earned that gives a title to wear it.")
end
local function paintFeats(a)
  local u = UI()
  local st = featState(a)
  FS.cat = FS.cat or "sets"
  for _, b in ipairs(FS.cats) do
    local on = b.key == FS.cat
    local have, all = 0, 0
    for _, f in ipairs(FEATS) do if f.cat == b.key then all = all + 1; if st.earned[f.id] then have = have + 1 end end end
    for _, c in ipairs(CATS) do if c[1] == b.key then b.l:SetText(c[2]:upper()) end end
    b.r:SetText(have .. " / " .. all)
    b.bg:SetColorTexture(on and 0.3 or 0.12, on and 0.22 or 0.09, on and 0.1 or 0.06, 0.95)
    b.l:SetTextColor(on and 1 or 0.85, on and 0.88 or 0.79, on and 0.54 or 0.64)
  end
  fp.pts:SetText(tostring(points(a)))
  local list = {}
  for _, f in ipairs(FEATS) do if f.cat == FS.cat then list[#list + 1] = f end end
  local pages = math.max(1, math.ceil(#list / PER))
  FS.page = math.max(0, math.min(FS.page or 0, pages - 1))
  for i, r in ipairs(fp.rows) do
    local f = list[FS.page * PER + i]
    r.feat = f
    if not f then r:Hide()
    else
      local got = st.earned[f.id]
      local hide = f.hidden and not got
      local ok, have = pcall(f.have, a); have = ok and have or 0
      r.name:SetText(hide and "???" or f.name)
      r.desc:SetText(hide and "A hidden achievement: found by doing it." or f.text)
      r.rw:SetText(got and ("EARNED " .. tostring(got)) or (rewardText(f.reward)):upper())
      r.pts:SetText(hide and "?" or tostring(f.pts))
      r.medal:SetDesaturated(not got); r.medal:SetAlpha(got and 1 or 0.45)
      r.bg:SetColorTexture(got and 0.97 or 0.9, got and 0.92 or 0.86, got and 0.78 or 0.76, 1)
      local showBar = not got and not hide and f.need > 1
      r.barBg:SetShown(showBar); r.bar:SetShown(showBar)
      if showBar then r.bar:SetWidth(math.max(1, 236 * math.min(1, have / f.need))) end
      local wearing = got and f.reward and f.reward.title and a.title == f.reward.title
      if wearing then r.rw:SetText("WEARING THE TITLE \"" .. f.reward.title:upper() .. "\"") end
      r:Show()
    end
  end
  fp.prev:SetShown(pages > 1); fp.next:SetShown(pages > 1); FS.pageT:SetShown(pages > 1)
  FS.pageT:SetText((FS.page + 1) .. " / " .. pages)
  -- what others see: your name, your title, your first three showcase cards, your points
  local me = UnitName and UnitName("player") or "You"
  fp.whoName:SetText(type(me) == "string" and me or "You")
  fp.whoTitle:SetText(a.title or "|cff8a8090no title yet|r")
  for i, w in ipairs(fp.whoCards) do
    local k = (a.showcase or {})[i]
    local c = k and u.byKey[k]
    local best
    if c then for f = 5, 1, -1 do if a.cards[k] and (a.cards[k][f] or 0) > 0 then best = f; break end end end
    if c and best then u.paint(w, c, best, 1) else w:Hide() end
  end
  fp.whoPts:SetText(points(a) .. " COLLECTOR POINTS")
  local any = false
  for _, w in ipairs(fp.whoCards) do if w:IsShown() then any = true end end
  fp.whoEmpty:SetShown(not any)
  -- the closest next: the unearned achievement you're furthest along (not a hidden one)
  local best, bk, bh
  for _, f in ipairs(FEATS) do
    if not f.hidden and not st.earned[f.id] then
      local ok, have = pcall(f.have, a); have = ok and have or 0
      local k = math.min(0.999, have / f.need)
      if not bk or k > bk then best, bk, bh = f, k, have end
    end
  end
  if best then
    fp.nextN:SetText(best.name); fp.nextT:SetText(best.text .. "  |cffe8c46a" .. math.min(bh, best.need) .. " / " .. best.need .. "|r")
    fp.nextBar:SetWidth(math.max(1, 146 * bk)); fp.near:Show()
  else fp.near:Hide() end
  fp.who.edge:SetColorTexture(a.showGlow and 0.95 or 0.55, a.showGlow and 0.78 or 0.41, a.showGlow and 0.3 or 0.16, 0.95)
end

RG.ArcadeViewHooks = RG.ArcadeViewHooks or {}
table.insert(RG.ArcadeViewHooks, function(view, ctx)
  if qcol and view.mode ~= "today" then qcol:Hide() end
  local on = view.mode == "feats"
  if not fp and not on then return end
  local u = UI()
  if not fp then buildFeats(ctx.frame, u) end
  fp:SetShown(on)
  if not on then return end
  ctx.frame.prev:Hide(); ctx.frame.next:Hide(); ctx.frame.pageText:Hide()
  checkFeats(ctx.a)
  paintFeats(ctx.a)
end)

-- your title and points go with your album to friends (ArcadeSocial.lua)
function RG.ArcadeMyTitle()
  local a = store(); if not a then return "", 0 end
  return (a.title or ""):gsub("|", ""), points(a)
end

-- (checked once at login too: achievements a player already qualifies for are earned quietly in the background)
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function()
    if C_Timer and C_Timer.After then C_Timer.After(8, function() local a = store(); if a then pcall(checkFeats, a) end end) end
  end)
end

-- ---------------------------------------------------------------------------
-- The binder: how full this set's page is, and a filter (every card / missing / new)
-- ---------------------------------------------------------------------------
RG.ArcadeAlbumShow = 1
local ALB_SHOW = { "Show: all", "Show: missing", "Show: new" }
local alb
RG.ArcadeAlbumHooks = RG.ArcadeAlbumHooks or {}
table.insert(RG.ArcadeAlbumHooks, function(st, frame)
  local u = UI(); local a = store(); if not (u and a) then return end
  if not alb then
    alb = CreateFrame("Frame", nil, frame); alb:SetSize(330, 26); alb:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 40, 56)
    alb:SetFrameLevel((frame:GetFrameLevel() or 1) + 6)
    alb.btn = u.gbtn(alb, ALB_SHOW[1], 100, 24, function()
      RG.ArcadeAlbumShow = RG.ArcadeAlbumShow % 3 + 1
      if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
    end)
    alb.btn:SetPoint("LEFT", 0, 0)
    alb.barBg = alb:CreateTexture(nil, "ARTWORK"); alb.barBg:SetColorTexture(0.2, 0.15, 0.08, 1); alb.barBg:SetSize(70, 6); alb.barBg:SetPoint("LEFT", alb.btn, "RIGHT", 112, 0)   -- (room for ArcadeMythicPlus.lua's Trophies button)
    alb.bar = alb:CreateTexture(nil, "OVERLAY"); alb.bar:SetHeight(6); alb.bar:SetPoint("LEFT", alb.barBg, "LEFT", 0, 0)
    alb.txt = u.fs(alb, "head", 10); alb.txt:SetPoint("LEFT", alb.barBg, "RIGHT", 8, 0); alb.txt:SetTextColor(0.85, 0.78, 0.6)
    -- (hidden again whenever the window leaves the Album)
    table.insert(RG.ArcadeViewHooks, function(view) if view.mode ~= "album" then alb:Hide() end end)
  end
  local have = 0
  for _, c in ipairs(st.cards or {}) do if u.owned(a, c.id) > 0 then have = have + 1 end end
  local n = #(st.cards or {})
  local k = n > 0 and have / n or 0
  alb.bar:SetWidth(math.max(1, 70 * k))
  if k >= 1 then alb.bar:SetColorTexture(0.48, 0.88, 0.54, 1) else alb.bar:SetColorTexture(0.91, 0.77, 0.42, 1) end
  alb.txt:SetText(have .. "/" .. n .. "  " .. math.floor(k * 100 + 0.5) .. "%")
  alb.btn:SetText(ALB_SHOW[RG.ArcadeAlbumShow])
  -- (a message on the window's bottom line, such as "Sold 32 extra cards", has the line to itself)
  local msg = frame.msg and frame.msg.GetText and frame.msg:GetText()
  alb:SetShown(not st.soon and not (type(msg) == "string" and msg ~= ""))
  -- (the set's progress is in the header above; down here the bar only crowded the Mythic button)
  alb.barBg:Hide(); alb.bar:Hide(); alb.txt:Hide()
end)
