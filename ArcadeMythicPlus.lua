-- Waypath+ cards: every Mythic pull is an event of its own (1.45).
--  * A dungeon's Mythic ("the heart" of its dungeon): the dungeon's loading screen spreads behind the pack screen, the
--    boss plays its roar (and its own voice, where the game's data has one), "THE HEART OF <DUNGEON>" drops in, and a
--    wax seal stamps onto the card with who pulled it and when.
--  * The six Waypath Mythics: an entrance each (footsteps, a waypoint pin, rising flames, a pillar of light and "60",
--    time slowing and sand pouring), their own name as the title, and a gold seal. The 1 Ring keeps its engraving.
--  * On the cards, everywhere they show: an effect in the card's own style (ghosts, embers, water, sand, cogs, mist,
--    snow, motes; footprints, glints, a pillar, falling sand), faint at rest and full while you hover; a dungeon
--    Mythic's backdrop drifts and its boss comes to life now and then.
--  * The trophy hall (the Album's Trophies button, or a dungeon page's Mythic button): The Six on plinths, and a gem for
--    every dungeon whose heart you hold. A rainbow gem beside those dungeons in the Sets list too.
--  * Hearts and the Six as achievements, and your guild hears about a Mythic pull (Waypath+ players get the card in a
--    toast; it can be turned off on the Feats tab).
-- All the effects are textures drawn by tools/arcade/art_mythplus.py, art_keg.py and art.py; models, animations,
-- loading screens and voices are the game's own.
local _, RG = ...
local MEDIA = "Interface\\AddOns\\Waypath\\Media\\Arcade\\"
local function UI() return RG.ArcadeUI end
local function store() local u = UI(); return u and u.store and u.store() end
local function keyOf(c) return c and (c.key or c.name) end
local function today() return date and date("%d %b %Y") or "" end
local function dungeonOf(c) return c and RG.ARCADE_SET_MYTHIC_OF and RG.ARCADE_SET_MYTHIC_OF[keyOf(c) or ""] end
local function sixOf(c) return c and c.tier == 7 and c.mythic and not c.mythic.one and c.name or nil end
local function isRing(c) return c and c.mythic and c.mythic.one end
local function clamp(v) return v < 0 and 0 or (v > 1 and 1 or v) end
local function back(v) local c1 = 1.70158; return 1 + (c1 + 1) * (v - 1) ^ 3 + c1 * (v - 1) ^ 2 end
local function fx(name) if RG.ArcadeFx then RG.ArcadeFx(name) end end
local function muted() local a = store(); return a and a.mute end

-- ---------------------------------------------------------------------------
-- Each Mythic's style
-- ---------------------------------------------------------------------------
local DSTYLE = {
  ["Ragefire Chasm"] = { "ember", { 1, 0.45, 0.15 } }, ["Wailing Caverns"] = { "mist", { 0.55, 0.95, 0.6 } },
  ["The Deadmines"] = { "cogs", { 1, 0.8, 0.45 } }, ["Shadowfang Keep"] = { "ghost", { 0.82, 0.9, 1 } },
  ["Blackfathom Deeps"] = { "water", { 0.6, 0.9, 1 } }, ["The Stockade"] = { "sand", { 0.78, 0.72, 0.64 } },
  ["Gnomeregan"] = { "cogs", { 0.65, 0.9, 1 } }, ["Razorfen Kraul"] = { "mist", { 0.78, 0.92, 0.42 } },
  ["Scarlet Monastery"] = { "motes", { 1, 0.85, 0.45 } }, ["Razorfen Downs"] = { "snow", { 0.75, 0.9, 1 } },
  ["Uldaman"] = { "sand", { 0.88, 0.78, 0.56 } }, ["Zul'Farrak"] = { "sand", { 0.98, 0.78, 0.42 } },
  ["Maraudon"] = { "mist", { 0.72, 0.56, 1 } }, ["The Temple of Atal'Hakkar"] = { "mist", { 0.42, 0.9, 0.52 } },
  ["Blackrock Depths"] = { "ember", { 1, 0.5, 0.15 } }, ["Blackrock Spire"] = { "ember", { 1, 0.36, 0.15 } },
  ["Dire Maul"] = { "motes", { 0.6, 0.8, 1 } }, ["Scholomance"] = { "mist", { 0.55, 1, 0.45 } },
  ["Stratholme"] = { "ghost", { 0.75, 0.95, 0.8 } }, ["Alcaz Prison"] = { "ember", { 1, 0.55, 0.2 } },
  ["Blackmaw Hold"] = { "mist", { 0.62, 0.52, 0.82 } }, ["City of Dalaran"] = { "motes", { 0.78, 0.62, 1 } },
  ["Excavation Site: Wetlands"] = { "sand", { 0.78, 0.68, 0.48 } }, ["Krol'dok Stronghold"] = { "ember", { 1, 0.5, 0.22 } },
  ["Ruins of Lordaeron"] = { "ghost", { 0.72, 1, 0.62 } }, ["The Drowned City"] = { "water", { 0.5, 0.86, 0.9 } },
  ["The Hall of Thanes"] = { "snow", { 0.86, 0.93, 1 } }, ["The Shaper's Terrace"] = { "motes", { 0.62, 1, 0.86 } },
}
local SSTYLE = {
  ["The Wanderer"] = { "steps", { 0.85, 0.78, 1 } }, ["The First Waypoint"] = { "glints", { 1, 0.86, 0.45 } },
  ["The Last Campfire"] = { "ember", { 1, 0.55, 0.22 } }, ["Sixty"] = { "pillar", { 1, 0.88, 0.5 } },
  ["The Hourglass of Forever"] = { "fall", { 0.98, 0.84, 0.5 } }, ["The 1 Ring"] = { "glints", { 1, 0.85, 0.5 } },
}
local function styleOf(c)
  local dn = dungeonOf(c)
  if dn then return DSTYLE[dn] or { "motes", { 1, 0.9, 0.6 } } end
  return c and c.tier == 7 and c.mythic and SSTYLE[c.name] or nil
end
-- a dungeon boss's own voice, where the game's data has one (sound kits: the creature's aggro sound, or its yell)
local VOICE = { ["Blackfathom Deeps"] = 5375, ["Gnomeregan"] = 1982, ["Stratholme"] = 3611, ["The Deadmines"] = 5780, ["Razorfen Downs"] = 5825 }

-- the loading screen behind a dungeon, cut below the game's logo and to the shape it's shown in
local function screenOf(dn, tex, w, h)
  local scr = RG.ARCADE_PLACE_FILE and RG.ARCADE_PLACE_FILE[dn]
  if not scr then return false end
  tex:SetTexture(scr[1])
  local TOP = 0.22
  local have = ((scr[2] == 1) and (16 / 9) or (4 / 3)) / (1 - TOP)
  local want = w / math.max(1, h)
  if have > want then local cut = (1 - want / have) / 2; tex:SetTexCoord(cut, 1 - cut, TOP, 1)
  else local keep = (1 - TOP) * have / want; tex:SetTexCoord(0, 1, 1 - keep, 1) end
  return true
end

-- a model plays something lively (its roar where it has one), then goes back to standing
local LIVELY = { 55, 53, 54, 57, 17, 16 }
local function liven(m)
  if not (m and m.IsShown and m:IsShown() and m.SetAnimation) then return end
  local pick = 55
  if m.HasAnimation then
    pick = nil
    for _, id in ipairs(LIVELY) do local ok, has = pcall(m.HasAnimation, m, id); if ok and has then pick = id; break end end
    if not pick then return end
  end
  pcall(m.SetAnimation, m, pick)
  if C_Timer and C_Timer.After then C_Timer.After(1.9, function() if m.SetAnimation then pcall(m.SetAnimation, m, 0) end end) end
end

-- ---------------------------------------------------------------------------
-- Who pulled each Mythic, and when (also the guild's toast, and the first-pull achievements)
-- ---------------------------------------------------------------------------
local function pullOf(a, c) return a and a.mythPull and a.mythPull[keyOf(c) or ""] end
local orig = RG.ArcadeCollectorPack
RG.ArcadeCollectorPack = function(got, meta)
  local a = store()
  if a then
    for _, g in ipairs(got or {}) do
      local c = g.card
      if c and c.tier == 7 then
        a.mythPull = a.mythPull or {}
        local k = keyOf(c)
        if not a.mythPull[k] then
          a.mythPull[k] = { by = (UnitName and UnitName("player")) or "?", date = today() }
          if a.announce ~= false and RG.ArcadeShareCard then pcall(RG.ArcadeShareCard, c, g.finish or 4) end
        end
      end
    end
  end
  if orig then return orig(got, meta) end
end
-- a guildmate's Mythic: a line in your chat as well as the toast
do
  local show = RG.ArcadeShowPull
  if show then
    RG.ArcadeShowPull = function(sender, card, finish)
      if card and card.tier == 7 and RG.Print then
        local dn = dungeonOf(card)
        RG.Print("|cffffe58c" .. tostring(sender) .. " pulled " .. (dn and ("the Heart of " .. dn) or card.name) .. "!|r")
      end
      return show(sender, card, finish)
    end
  end
end

-- ---------------------------------------------------------------------------
-- The effects on a card: a few particles in its style, clipped to its art
-- ---------------------------------------------------------------------------
local live = setmetatable({}, { __mode = "k" })     -- card widget -> its effect state
local seals = setmetatable({}, { __mode = "k" })    -- card widget -> its seal overlay
local NPART = { ember = 12, ghost = 4, water = 10, sand = 9, cogs = 6, mist = 5, snow = 12, motes = 9, steps = 6, glints = 6, pillar = 8, fall = 14 }
local TEX = { ember = "Spark", ghost = "Smoke", water = "Spark", sand = "Soft", cogs = "Cog", mist = "Smoke", snow = "Spark", motes = "Glow", steps = "Foot", glints = "Spark", pillar = "Glow", fall = "Spark" }
local ADD = { ember = true, water = true, snow = true, motes = true, glints = true, pillar = true, fall = true }

local function fxFor(w)
  local st = live[w]
  if st then return st end
  st = { parts = {}, k = 0.45 }
  local f = CreateFrame("Frame", nil, w); if RG.ArcadeLayer then RG.ArcadeLayer(w, f, 3) else f:SetFrameLevel((w:GetFrameLevel() or 1) + 3) end
  if f.SetClipsChildren then f:SetClipsChildren(true) end
  st.f = f
  st.glow = f:CreateTexture(nil, "BACKGROUND"); st.glow:SetTexture(MEDIA .. "Glow"); st.glow:SetBlendMode("ADD"); st.glow:Hide()
  live[w] = st
  return st
end
local function setupFx(w, c, style)
  local st = fxFor(w)
  local kind, tint = style[1], style[2]
  st.card, st.kind, st.tint = c, kind, tint
  local area = rawget(w, "artClip")
  if c.mythic or not area then area = w end
  st.f:ClearAllPoints(); st.f:SetAllPoints(area); st.f:Show()
  local n = NPART[kind] or 8
  for i = 1, math.max(n, #st.parts) do
    local p = st.parts[i]
    if i <= n then
      if not p then p = { t = st.f:CreateTexture(nil, "ARTWORK") }; st.parts[i] = p end
      p.t:SetTexture(MEDIA .. TEX[kind]); p.t:SetBlendMode(ADD[kind] and "ADD" or "BLEND"); p.t:SetVertexColor(tint[1], tint[2], tint[3]); p.t:Hide()
      p.life, p.max = 0, 1
      p.delay = math.random() * 3
    elseif p then p.t:Hide(); p.life = 0; p.off = true end
    if p and i <= n then p.off = nil end
  end
  st.glow:Hide()
  if kind == "pillar" then st.glow:Show(); st.glow:SetVertexColor(tint[1], tint[2], tint[3]) end
end

-- one particle's life in each style (x, y from the area's bottom-left; W, H its size)
local function spawn(st, p, W, H)
  local kind = st.kind
  local r = math.random
  p.r, p.vr = r() * 6.28, 0
  if kind == "ember" then p.x, p.y, p.vx, p.vy, p.max, p.z = r() * W, -4, (r() - 0.5) * 10, 18 + r() * 26, 1.6 + r() * 1.4, 3 + r() * 5
  elseif kind == "ghost" then p.x, p.y, p.vx, p.vy, p.max, p.z = -20 + r() * W * 0.5, H * (0.25 + r() * 0.6), 8 + r() * 10, 2, 3.5 + r() * 2, 26 + r() * 22
  elseif kind == "water" then
    if r() < 0.5 then p.x, p.y, p.vx, p.vy, p.max, p.z = r() * W, H + 4, 0, -60 - r() * 30, 1.6, 2 + r() * 2   -- a drip
    else p.x, p.y, p.vx, p.vy, p.max, p.z = r() * W, -4, (r() - 0.5) * 4, 14 + r() * 12, 2.4, 3 + r() * 3 end   -- a bubble
  elseif kind == "sand" then p.x, p.y, p.vx, p.vy, p.max, p.z = -30, r() * H, 40 + r() * 40, (r() - 0.5) * 4, 2 + r(), 14 + r() * 14
  elseif kind == "cogs" then p.x, p.y, p.vx, p.vy, p.max, p.z, p.vr = (r() < 0.5 and 0.12 or 0.88) * W, (0.2 + r() * 0.6) * H, 0, 0, 5 + r() * 3, 14 + r() * 12, (r() - 0.5) * 1.2
  elseif kind == "mist" then p.x, p.y, p.vx, p.vy, p.max, p.z = r() * W, H * r() * 0.35, (r() - 0.5) * 8, 3, 4 + r() * 2, 34 + r() * 26
  elseif kind == "snow" then p.x, p.y, p.vx, p.vy, p.max, p.z = r() * W, H + 4, (r() - 0.5) * 8, -12 - r() * 12, 4, 2 + r() * 3
  elseif kind == "motes" then p.x, p.y, p.vx, p.vy, p.max, p.z = r() * W, r() * H * 0.6, (r() - 0.5) * 6, 6 + r() * 8, 3 + r() * 2, 6 + r() * 8
  elseif kind == "steps" then
    -- footprints walk up across the card, one after another
    st.step = ((st.step or 0) % 6) + 1
    local s = st.step
    p.x, p.y, p.vx, p.vy, p.max, p.z = W * (0.22 + s * 0.1) + (s % 2 == 0 and 6 or -6), H * (0.12 + s * 0.12), 0, 0, 2.4, 9
    p.r = -0.6
  elseif kind == "glints" then p.x, p.y, p.vx, p.vy, p.max, p.z, p.vr = r() * W, r() * H, 0, 0, 0.9 + r() * 0.6, 10 + r() * 14, 2
  elseif kind == "pillar" then p.x, p.y, p.vx, p.vy, p.max, p.z = W * (0.4 + r() * 0.2), H * r() * 0.3, (r() - 0.5) * 3, 16 + r() * 14, 2.5, 4 + r() * 5
  elseif kind == "fall" then p.x, p.y, p.vx, p.vy, p.max, p.z = W * 0.5 + (r() - 0.5) * 6, H * 0.62, (r() - 0.5) * 3, -30 - r() * 12, 1.2, 2 + r() * 2
  end
  p.life = p.max
  p.t:SetSize(kind == "steps" and p.z or p.z, kind == "steps" and p.z * 2 or (kind == "sand" and p.z * 0.25 or p.z))
end
local function stepFx(w, st, dt, t)
  local f = st.f
  local W, H = f:GetWidth(), f:GetHeight()
  if type(W) ~= "number" or W <= 0 then return end
  local k = st.k
  if st.hoverUntil and t < st.hoverUntil then k = 1 end
  for _, p in ipairs(st.parts) do
    if not p.off then
      if p.life <= 0 then
        p.delay = (p.delay or 0) - dt * (0.5 + k)
        if p.delay <= 0 then spawn(st, p, W, H); p.delay = math.random() * (st.kind == "steps" and 0.2 or 1.2) end
        p.t:Hide()
      else
        p.life = p.life - dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        if st.kind == "ghost" or st.kind == "mist" then p.y = p.y + math.sin(t * 0.8 + p.r) * 4 * dt end
        local q = 1 - p.life / p.max
        local a = math.sin(q * 3.1416)
        if st.kind == "steps" then a = q < 0.15 and q / 0.15 or (1 - q) end
        if st.kind == "glints" then local z = p.z * (1 - math.abs(q * 2 - 1)); p.t:SetSize(z, z) end
        local base = (st.kind == "ghost" or st.kind == "mist") and 0.35 or ((st.kind == "steps") and 0.55 or 0.85)
        p.t:ClearAllPoints(); p.t:SetPoint("CENTER", f, "BOTTOMLEFT", p.x, p.y)
        if p.t.SetRotation and (p.vr ~= 0 or st.kind == "steps") then p.t:SetRotation(p.r + p.vr * (p.max - p.life)) end
        p.t:SetAlpha(math.max(0, a) * base * (0.35 + 0.65 * k)); p.t:Show()
      end
    end
  end
  if st.kind == "pillar" then
    st.glow:ClearAllPoints(); st.glow:SetPoint("BOTTOM", f, "BOTTOM", 0, -H * 0.1); st.glow:SetSize(W * 0.45, H * 1.4)
    st.glow:SetAlpha((0.25 + 0.15 * math.sin(t * 1.3)) * (0.4 + 0.6 * k))
  end
  -- a dungeon Mythic's backdrop drifts slowly across
  local bg = rawget(w, "smBg")
  if bg and bg:IsShown() then
    local base = rawget(w, "mpTC")
    if not base then local l, tp, _, b0, r, _, _, b1 = bg:GetTexCoord(); base = { l or 0, r or 1, tp or 0, b1 or b0 or 1 }; w.mpTC = base end
    local zoom = 1.08
    local wd, ht = (base[2] - base[1]) / zoom, (base[4] - base[3]) / zoom
    local px = 0.5 + 0.5 * math.sin(t * 0.06 + (st.ph or 0))
    local l = base[1] + (base[2] - base[1] - wd) * px
    local tp = base[3] + (base[4] - base[3] - ht) * 0.5
    bg:SetTexCoord(l, l + wd, tp, tp + ht)
  end
  -- and its boss comes to life now and then
  if dungeonOf(st.card) then
    st.nextLive = st.nextLive or (t + 6 + math.random() * 20)
    if t >= st.nextLive then st.nextLive = t + 20 + math.random() * 20; liven(rawget(w, "model")) end
  end
end
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, dt)
  if not next(live) then return end
  dt = math.min(0.1, dt or 0)
  local t = GetTime and GetTime() or 0
  for w, st in pairs(live) do
    if st.card and w.card == st.card and w:IsVisible() then pcall(stepFx, w, st, dt, t)
    elseif st.card and w.card ~= st.card then st.card = nil; st.f:Hide(); w.mpTC = nil end
  end
end)
local function hoverOn(w)
  local st = live[w]
  if not (st and st.card) then return end
  local t = GetTime and GetTime() or 0
  st.hoverUntil = t + 2.5
  if dungeonOf(st.card) and (not st.lastHover or t - st.lastHover > 4) then st.lastHover = t; liven(rawget(w, "model")) end
end

-- the seal: who pulled it and when, on the card's corner and along its foot
local function sealFor(w)
  local s = seals[w]
  if s then return s end
  local u = UI()
  s = CreateFrame("Frame", nil, w); s:SetAllPoints(w); if RG.ArcadeLayer then RG.ArcadeLayer(w, s, 9) else s:SetFrameLevel((w:GetFrameLevel() or 1) + 9) end
  s.tex = s:CreateTexture(nil, "OVERLAY")
  s.foot = u.fs(s, "head", 8); s.foot:SetPoint("BOTTOM", w, "BOTTOM", 0, 6); s.foot:SetTextColor(1, 0.91, 0.66)
  seals[w] = s
  return s
end
local function layoutSeal(w, s, c)
  local cw, ch = w.cw or w:GetWidth() or 100, w.ch or w:GetHeight() or 140
  local z = math.max(18, cw * 0.24)
  s.tex:ClearAllPoints(); s.tex:SetPoint("CENTER", w, "BOTTOMRIGHT", -cw * 0.16, ch * (c.mythic and 0.22 or 0.2)); s.tex:SetSize(z, z)
  s.z = z
end
function RG.ArcadeMythicCardHook(w, card, finish)
  local style = card and finish and card.tier == 7 and styleOf(card)
  local st = live[w]
  if not style then
    if st then st.card = nil; st.f:Hide() end
    local s = seals[w]; if s then s:Hide() end
    return
  end
  w.mpTC = nil
  setupFx(w, card, style)
  st = live[w]
  st.k = rawget(w, "mpMoment") and 1 or 0.45
  st.ph = math.random() * 6
  if not rawget(w, "mpHooked") and w.HookScript then
    w.mpHooked = true
    pcall(w.HookScript, w, "OnEnter", function(self) hoverOn(self) end)
  end
  -- the seal (not on The 1 Ring: it has its engraving), only on a card someone actually pulled
  local a = store()
  local pull = pullOf(a, card)
  local s = seals[w]
  if pull and not isRing(card) and (w.cw or 0) >= 60 then
    s = sealFor(w)
    s.tex:SetTexture(MEDIA .. (dungeonOf(card) and "WaxSeal" or "GoldSeal"))
    layoutSeal(w, s, card)
    s.tex:SetAlpha(rawget(w, "mpMoment") and 0 or 1)
    local big = (w.cw or 0) >= 150
    s.foot:SetText(big and ((pull.by or "?"):upper() .. "   ·   " .. (pull.date or ""):upper()) or "")
    s.foot:SetAlpha(rawget(w, "mpMoment") and 0 or 0.9)
    if card.mythic then s.foot:SetPoint("BOTTOM", w, "BOTTOM", 0, 3) end
    s:Show()
  elseif s then s:Hide() end
end
table.insert(RG.ArcadeCardHooks, function(w, card, finish)
  if card and card.mythic then return end   -- (the six: ArcadePaintMythic's own call)
  pcall(RG.ArcadeMythicCardHook, w, card, finish)
end)

-- ---------------------------------------------------------------------------
-- The moment: each Mythic's entrance, title and seal
-- ---------------------------------------------------------------------------
local function plus(m)
  local p = rawget(m, "mplus")
  if p then return p end
  p = {}
  -- behind the card: the dungeon's picture, the flames, the pillar, the footsteps
  p.back = CreateFrame("Frame", nil, m); p.back:SetAllPoints(m); p.back:SetFrameLevel((m:GetFrameLevel() or 1) + 1)
  p.bd = p.back:CreateTexture(nil, "BACKGROUND"); p.bd:SetPoint("CENTER")
  p.dim = p.back:CreateTexture(nil, "BORDER"); p.dim:SetAllPoints(m); p.dim:SetColorTexture(0, 0, 0, 0.45)
  p.pillar = p.back:CreateTexture(nil, "ARTWORK"); p.pillar:SetTexture(MEDIA .. "Glow"); p.pillar:SetBlendMode("ADD"); p.pillar:SetPoint("CENTER")
  p.flames, p.feet = {}, {}
  for i = 1, 9 do local t = p.back:CreateTexture(nil, "ARTWORK", nil, 1); t:SetTexture(MEDIA .. "Flame"); t:SetBlendMode("ADD"); p.flames[i] = t end
  for i = 1, 12 do local t = p.back:CreateTexture(nil, "ARTWORK", nil, 2); t:SetTexture(MEDIA .. "Foot"); t:SetVertexColor(0.85, 0.78, 1); p.feet[i] = t end
  -- in front of the card: the pin, "60", the grey of slowed time, the sand, the seal stamping down
  p.front = CreateFrame("Frame", nil, m); p.front:SetAllPoints(m); p.front:SetFrameLevel((m:GetFrameLevel() or 1) + 11)
  p.grey = p.front:CreateTexture(nil, "BACKGROUND"); p.grey:SetAllPoints(m); p.grey:SetColorTexture(0.42, 0.42, 0.46, 1)
  p.pin = p.front:CreateTexture(nil, "ARTWORK"); p.pin:SetTexture(MEDIA .. "Pin"); p.pin:SetSize(64, 96)
  p.pinGlint = p.front:CreateTexture(nil, "OVERLAY"); p.pinGlint:SetTexture(MEDIA .. "Spark"); p.pinGlint:SetBlendMode("ADD")
  local u = UI()
  p.sixty = u.fs(p.front, "title", 96); p.sixty:SetPoint("CENTER", m, "CENTER", 0, 0); p.sixty:SetText("60"); p.sixty:SetTextColor(1, 0.92, 0.62)
  p.sand = {}
  for i = 1, 26 do local t = p.front:CreateTexture(nil, "ARTWORK", nil, 1); t:SetTexture(MEDIA .. "Spark"); t:SetBlendMode("ADD"); t:SetVertexColor(1, 0.85, 0.5); p.sand[i] = t end
  p.seal = p.front:CreateTexture(nil, "OVERLAY", nil, 2)
  p.foot = u.fs(p.front, "head", 11); p.foot:SetTextColor(1, 0.91, 0.66)
  m.mplus = p
  return p
end
local function hideAll(p)
  for _, t in ipairs({ p.bd, p.dim, p.pillar, p.grey, p.pin, p.pinGlint, p.sixty, p.seal, p.foot }) do t:Hide() end
  for _, l in ipairs({ p.flames, p.feet, p.sand }) do for _, t in ipairs(l) do t:Hide() end end
end

local EXTRA_D, EXTRA_S = 1.4, 1.0   -- (how much longer a heart's and one of the six's moments run, for the entrance and the seal)
RG.ArcadeMythicHooks = RG.ArcadeMythicHooks or {}
table.insert(RG.ArcadeMythicHooks, function(event, m, g, a1, a2, a3)
  local c = g and g.card
  if not c then return end
  local p = plus(m)
  if event == "start" then
    local spec = a1
    hideAll(p)
    local dn, six = dungeonOf(c), sixOf(c)
    p.kind = dn and "heart" or (six and "six" or nil)
    p.dn, p.six, p.roared, p.stamped, p.started = dn, six, false, false, false
    -- the card in the middle shows its effects at full strength, and waits for its seal
    m.card.mpMoment = true
    pcall(RG.ArcadeMythicCardHook, m.card, c, g.finish)
    if dn then
      spec.pre = "THE HEART OF"
      spec.word = dn:upper()
      spec.sub = (c.name or ""):upper()
      spec.extra = EXTRA_D
      local W, H = m:GetWidth() or 760, m:GetHeight() or 640
      if type(W) ~= "number" or W <= 0 then W, H = 760, 640 end
      p.bd:SetSize(W * 1.12, H * 1.12)
      if screenOf(dn, p.bd, W * 1.12, H * 1.12) then p.bd:SetAlpha(0); p.bd:Show(); p.dim:SetAlpha(0); p.dim:Show() end
    elseif six then
      spec.word = six:upper()
      spec.sub = "M Y T H I C   ·   O N E   O F   S I X"
      spec.extra = EXTRA_S
    end
    p.endAt = nil
  elseif event == "tick" then
    local e, t, st = a1, a2, a3
    p.endAt = st.endAt
    local W, H = m:GetWidth() or 760, m:GetHeight() or 640
    if type(W) ~= "number" or W <= 0 then W, H = 760, 640 end
    local skip = e >= st.endAt
    if p.kind == "heart" then
      -- the dungeon's picture spreads behind everything, slowly closer
      local k = clamp((e - 0.15) / 0.75)
      p.bd:SetAlpha(0.85 * k); p.dim:SetAlpha(0.45 * k)
      local z = 1.12 + 0.05 * clamp(e / 4)
      p.bd:SetSize(W * z, H * z)
      -- the boss roars as it lands
      if not p.roared and (e >= 0.85 or skip) then
        p.roared = true
        liven(rawget(m.card, "model"))
        if not skip then
          local kit = VOICE[p.dn]
          if kit and PlaySound and not muted() then pcall(PlaySound, kit, "SFX") else fx("roar") end
          local r = m:GetParent(); if r then r.shakeT, r.shakeK = 0.45, 3 end
        end
      end
    elseif p.six == "The Wanderer" then
      -- footsteps cross the screen and walk up to the card
      if not p.started then p.started = true; if not skip then fx("steps") end end
      for i, f in ipairs(p.feet) do
        local at = 0.05 + (i - 1) * 0.11
        local q = clamp((e - at) / 0.15)
        local fade = clamp(1 - (e - at - 0.9) / 0.5)
        if q > 0 and fade > 0 and not skip then
          local fx_ = -W * 0.45 + (i - 1) * (W * 0.42 / 11)
          local fy = -H * 0.32 + (i - 1) * (H * 0.28 / 11) + ((i % 2 == 0) and 9 or -9)
          f:ClearAllPoints(); f:SetPoint("CENTER", m, "CENTER", fx_, fy); f:SetSize(16, 32)
          if f.SetRotation then f:SetRotation(-1.0) end
          f:SetAlpha(0.8 * q * fade); f:Show()
        else f:Hide() end
      end
    elseif p.six == "The First Waypoint" then
      if not p.started then p.started = true; if not skip then fx("toast") end end
      local q = clamp((e - 0.1) / 0.45)
      local land = 60
      local y = H * 0.55 + (land - H * 0.55) * back(q)
      local fade = clamp(1 - (e - 1.1) / 0.4)
      if fade > 0 and not skip then
        p.pin:ClearAllPoints(); p.pin:SetPoint("BOTTOM", m, "CENTER", 0, y); p.pin:SetAlpha(fade); p.pin:Show()
        local gq = clamp((e - 0.55) / 0.4)
        if gq > 0 and gq < 1 then local z = 70 * (1 - gq) + 10; p.pinGlint:ClearAllPoints(); p.pinGlint:SetPoint("CENTER", p.pin, "CENTER", 0, 18); p.pinGlint:SetSize(z, z); p.pinGlint:SetAlpha(1 - gq); p.pinGlint:Show() else p.pinGlint:Hide() end
      else p.pin:Hide(); p.pinGlint:Hide() end
    elseif p.six == "The Last Campfire" then
      if not p.started then p.started = true; if not skip then fx("crackle") end end
      local up = clamp((e - 0.05) / 0.6) * clamp(1 - (e - 1.4) / 0.5)
      for i, f in ipairs(p.flames) do
        if up > 0 and not skip then
          local fl = 0.8 + 0.2 * math.sin(t * (13 + i) + i)
          local h = (120 + 160 * ((i * 37) % 5) / 4) * up * fl
          f:ClearAllPoints(); f:SetPoint("BOTTOM", m, "BOTTOM", -W * 0.44 + (i - 1) * (W * 0.88 / 8), 0); f:SetSize(h * 0.5, h)
          f:SetAlpha(0.85 * up); f:Show()
        else f:Hide() end
      end
    elseif p.six == "Sixty" then
      if not p.started then p.started = true; if not skip then fx("sixty") end end
      local k = clamp((e - 0.05) / 0.4) * clamp(1 - (e - 2.0) / 0.6)
      if k > 0 then p.pillar:SetSize(260, H * 1.3); p.pillar:SetVertexColor(1, 0.86, 0.45); p.pillar:SetAlpha(0.8 * k); p.pillar:Show() else p.pillar:Hide() end
      local q = clamp((e - 0.5) / 0.22)
      local fade = clamp(1 - (e - 1.2) / 0.4)
      if q > 0 and fade > 0 and not skip then
        p.sixty:SetScale(math.max(0.2, 3.2 - 2.2 * q)); p.sixty:SetAlpha(q * fade); p.sixty:Show()
        if q >= 1 and not p.thumped then p.thumped = true; fx("stamp"); local r = m:GetParent(); if r then r.shakeT, r.shakeK = 0.25, 2 end end
      else p.sixty:Hide() end
    elseif p.six == "The Hourglass of Forever" then
      if not p.started then p.started = true; if not skip then fx("sandfall") end end
      local grey = clamp(e / 0.2) * clamp(1 - (e - 1.1) / 0.5)
      if grey > 0 and not skip then p.grey:SetAlpha(0.55 * grey); p.grey:Show() else p.grey:Hide() end
      for i, s in ipairs(p.sand) do
        local ph = ((i * 0.37) % 1)
        local q = ((e * 0.9 + ph) % 1)
        local on = e > 0.1 and e < 1.5 and not skip
        if on then
          s:ClearAllPoints(); s:SetPoint("CENTER", m, "CENTER", math.sin(i * 1.7) * 3, H * 0.5 - q * (H * 0.5 - 150)); local z = 3 + (i % 3); s:SetSize(z, z)
          s:SetAlpha(0.9 * math.sin(q * 3.1416)); s:Show()
        else s:Hide() end
      end
    end
    -- the seal stamps down once the card has landed and the title is in
    if p.kind then
      local at = st.endAt - (p.kind == "heart" and 0.9 or 0.7)
      local s = seals[m.card]
      if s and s:IsShown() then
        local q = clamp((e - at) / 0.18)
        if skip then q = 1 end
        if q > 0 then
          local z = (s.z or 60) * (1 + 2 * (1 - q) ^ 2)
          s.tex:SetSize(z, z); s.tex:SetAlpha(q)
          if q >= 1 and not p.stamped then
            p.stamped = true
            if not skip then fx("stamp"); local r = m:GetParent(); if r then r.shakeT, r.shakeK = 0.18, 2 end end
          end
          s.foot:SetAlpha(clamp((e - at - 0.2) / 0.4) * 0.9 + (skip and 0.9 or 0))
        else s.tex:SetAlpha(0); s.foot:SetAlpha(0) end
      end
    end
  end
end)

-- ---------------------------------------------------------------------------
-- The trophy hall: The Six on plinths, every dungeon's heart; or one dungeon's heart on its plinth
-- ---------------------------------------------------------------------------
local SIX_ORDER = { "The Wanderer", "The First Waypoint", "The Last Campfire", "Sixty", "The Hourglass of Forever", "The 1 Ring" }
local hall
local function owned(a, c) local u = UI(); return a and c and u.owned(a, c.id) > 0 end
local function heartCount(a)
  local n, all = 0, 0
  for dn, key in pairs(RG.ARCADE_SET_MYTHIC or {}) do
    all = all + 1
    local c = UI().byKey[key]
    if owned(a, c) then n = n + 1 end
  end
  return n, all
end
function RG.ArcadeSetHeart(s)
  local key = s and s.dungeon and RG.ARCADE_SET_MYTHIC and RG.ARCADE_SET_MYTHIC[s.name]
  local c = key and UI().byKey[key]
  local a = store()
  if c and owned(a, c) then return "  |T" .. MEDIA .. "GemPrism:12:12|t" end
  return ""
end
local function buildHall(frame)
  local u = UI()
  hall = CreateFrame("Frame", nil, frame); hall:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -146); hall:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 92)
  hall:SetFrameLevel((frame:GetFrameLevel() or 1) + 40); hall:EnableMouse(true)
  hall.bg = hall:CreateTexture(nil, "BACKGROUND"); hall.bg:SetAllPoints(); hall.bg:SetColorTexture(0.05, 0.04, 0.07, 0.97)
  hall.bd = hall:CreateTexture(nil, "BACKGROUND", nil, 1); hall.bd:SetAllPoints()
  hall.spot = hall:CreateTexture(nil, "BORDER"); hall.spot:SetTexture(MEDIA .. "Glow"); hall.spot:SetBlendMode("ADD")
  hall.title = u.fs(hall, "title", 18); hall.title:SetPoint("TOP", 0, -12); hall.title:SetTextColor(1, 0.92, 0.7)
  hall.sub = u.fs(hall, "body", 12); hall.sub:SetPoint("TOP", hall.title, "BOTTOM", 0, -4); hall.sub:SetTextColor(0.82, 0.78, 0.68)
  hall.close = u.gbtn(hall, "Back", 70, 22, function() hall:Hide() end); hall.close:SetPoint("TOPRIGHT", -8, -8)
  -- six plinths (the hall), or one (a dungeon's heart)
  hall.pl = {}
  for i = 1, 6 do
    local e = {}
    e.plinth = hall:CreateTexture(nil, "ARTWORK"); e.plinth:SetTexture(MEDIA .. "Plinth")
    e.card = u.makeCard(hall, 74); e.card.noTip = false
    e.empty = hall:CreateTexture(nil, "ARTWORK", nil, 1); e.empty:SetColorTexture(0.2, 0.18, 0.26, 0.6)
    e.q = u.fs(hall, "title", 20); e.q:SetText("?"); e.q:SetTextColor(0.5, 0.47, 0.6)
    e.cap = u.fs(hall, "body", 10); e.cap:SetTextColor(0.85, 0.8, 0.68); e.cap:SetWidth(108)
    hall.pl[i] = e
  end
  hall.big = u.makeCard(hall, 170)
  hall.bigPl = hall:CreateTexture(nil, "ARTWORK"); hall.bigPl:SetTexture(MEDIA .. "Plinth")
  hall.bigQ = u.fs(hall, "title", 46); hall.bigQ:SetText("?"); hall.bigQ:SetTextColor(0.5, 0.47, 0.6)
  hall.bigSlot = hall:CreateTexture(nil, "ARTWORK", nil, 1); hall.bigSlot:SetColorTexture(0.2, 0.18, 0.26, 0.6)
  hall.plate = u.fs(hall, "head", 11); hall.plate:SetTextColor(1, 0.9, 0.62)
  -- every dungeon's heart: a gem and its name, four columns
  hall.hearts = {}
  for i = 1, 32 do
    local b = CreateFrame("Button", nil, hall); b:SetSize(176, 18)
    b.gem = b:CreateTexture(nil, "ARTWORK"); b.gem:SetSize(11, 11); b.gem:SetPoint("LEFT", 2, 0); b.gem:SetTexture(MEDIA .. "GemPrism")
    b.t = u.fs(b, "body", 11); b.t:SetPoint("LEFT", 18, 0); b.t:SetWidth(156); b.t:SetJustifyH("LEFT")
    b:SetScript("OnClick", function(self) if self.dn then RG.ArcadeTrophy(self.dn) end end)
    hall.hearts[i] = b
  end
  hall.heartsHead = u.fs(hall, "head", 11); hall.heartsHead:SetTextColor(1, 0.9, 0.62)
  hall:Hide()
end
local function hideHall()
  for _, e in ipairs(hall.pl) do e.plinth:Hide(); e.card:Hide(); e.empty:Hide(); e.q:Hide(); e.cap:Hide() end
  hall.big:Hide(); hall.bigPl:Hide(); hall.bigQ:Hide(); hall.bigSlot:Hide(); hall.plate:Hide(); hall.bd:Hide()
  for _, b in ipairs(hall.hearts) do b:Hide() end
  hall.heartsHead:Hide()
end
local function frameOf() return _G.WaypathArcade end
function RG.ArcadeTrophy(dn)
  local frame = frameOf(); if not frame then return end
  if not hall then buildHall(frame) end
  hideHall()
  local u, a = UI(), store()
  if dn then
    -- one dungeon's heart on its plinth, its loading screen faint behind
    local key = RG.ARCADE_SET_MYTHIC and RG.ARCADE_SET_MYTHIC[dn]
    local c = key and u.byKey[key]
    local have = c and owned(a, c)
    local W, H = hall:GetWidth() or 730, hall:GetHeight() or 490
    if type(W) ~= "number" or W <= 0 then W, H = 730, 490 end
    if screenOf(dn, hall.bd, W, H) then hall.bd:SetAlpha(0.22); hall.bd:Show() end
    hall.title:SetText("THE HEART OF " .. dn:upper())
    local pull = c and pullOf(a, c)
    local left = math.max(1, (RG.ARCADE_MYTH_PITY or 30) - ((a and a.mpity and a.mpity[dn]) or 0))
    hall.sub:SetText(have and ((c.name or "") .. (pull and ("   ·   found " .. pull.date .. " by " .. pull.by) or "")) or ("Not found yet   ·   certain within " .. left .. " of " .. dn .. "'s packs"))
    hall.spot:ClearAllPoints(); hall.spot:SetPoint("CENTER", hall, "CENTER", 0, -10); hall.spot:SetSize(420, 420); hall.spot:SetVertexColor(1, 0.86, 0.55, have and 0.5 or 0.15); hall.spot:Show()
    hall.bigPl:ClearAllPoints(); hall.bigPl:SetPoint("BOTTOM", hall, "BOTTOM", 0, 18); hall.bigPl:SetSize(300, 150); hall.bigPl:Show()
    if have then
      hall.big:ClearAllPoints(); hall.big:SetPoint("BOTTOM", hall.bigPl, "TOP", 0, -24); u.paint(hall.big, c, u.bestFinish(a, c.id), 1); hall.big:Show()
    else
      hall.bigSlot:ClearAllPoints(); hall.bigSlot:SetPoint("BOTTOM", hall.bigPl, "TOP", 0, -24); hall.bigSlot:SetSize(140, 196); hall.bigSlot:Show()
      hall.bigQ:ClearAllPoints(); hall.bigQ:SetPoint("CENTER", hall.bigSlot, "CENTER", 0, 0); hall.bigQ:Show()
    end
    hall.plate:ClearAllPoints(); hall.plate:SetPoint("CENTER", hall.bigPl, "TOP", 0, -78); hall.plate:SetText(have and (pull and pull.date or "FOUND"):upper() or "WAITING"); hall.plate:Show()
  else
    -- the hall: the six on their plinths, then every dungeon's heart
    hall.title:SetText("TROPHY HALL")
    local n, all = heartCount(a)
    local six = 0
    for _, nm in ipairs(SIX_ORDER) do if owned(a, u.byKey[nm]) then six = six + 1 end end
    hall.sub:SetText("The Six  " .. six .. " / 6      ·      Hearts  " .. n .. " / " .. all)
    hall.spot:ClearAllPoints(); hall.spot:SetPoint("CENTER", hall, "TOP", 0, -130); hall.spot:SetSize(760, 260); hall.spot:SetVertexColor(1, 0.86, 0.55, 0.25); hall.spot:Show()
    for i, e in ipairs(hall.pl) do
      local nm = SIX_ORDER[i]
      local c = u.byKey[nm]
      local x = (i - 3.5) * 116
      e.plinth:ClearAllPoints(); e.plinth:SetPoint("TOP", hall, "TOP", x, -170); e.plinth:SetSize(108, 54); e.plinth:Show()
      if c and owned(a, c) then
        e.card:ClearAllPoints(); e.card:SetPoint("BOTTOM", e.plinth, "TOP", 0, -10); u.paint(e.card, c, u.bestFinish(a, c.id), 1); e.card:Show()
      else
        e.empty:ClearAllPoints(); e.empty:SetPoint("BOTTOM", e.plinth, "TOP", 0, -10); e.empty:SetSize(64, 90); e.empty:Show()
        e.q:ClearAllPoints(); e.q:SetPoint("CENTER", e.empty, "CENTER"); e.q:Show()
      end
      e.cap:ClearAllPoints(); e.cap:SetPoint("TOP", e.plinth, "BOTTOM", 0, 0); e.cap:SetText(nm); e.cap:Show()
    end
    hall.heartsHead:ClearAllPoints(); hall.heartsHead:SetPoint("TOPLEFT", hall, "TOPLEFT", 26, -262); hall.heartsHead:SetText("HEARTS OF THE DUNGEONS   ·   click one to see its plinth"); hall.heartsHead:Show()
    local list = {}
    for dn in pairs(RG.ARCADE_SET_MYTHIC or {}) do list[#list + 1] = dn end
    table.sort(list)
    for i, b in ipairs(hall.hearts) do
      local dn = list[i]
      if dn then
        local c = u.byKey[RG.ARCADE_SET_MYTHIC[dn]]
        local have = owned(a, c)
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", hall, "TOPLEFT", 26 + col * 178, -282 - row * 19)
        b.dn = dn
        b.gem:SetDesaturated(not have); b.gem:SetAlpha(have and 1 or 0.3)
        b.t:SetText(have and ("|cfffff1c4" .. dn .. "|r") or ("|cff8a8598" .. dn .. "|r"))
        b:Show()
      else b:Hide() end
    end
  end
  hall:Show()
end
-- the Album: a Trophies button, and a dungeon's Mythic button opens its plinth
RG.ArcadeAlbumHooks = RG.ArcadeAlbumHooks or {}
table.insert(RG.ArcadeAlbumHooks, function(st, frame)
  local u = UI()
  local b = rawget(frame, "mpTrophy")
  if not b then
    b = u.gbtn(frame, "Trophies", 92, 24, function() RG.ArcadeTrophy(nil) end)
    b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 148, 56)
    frame.mpTrophy = b
    RG.ArcadeViewHooks = RG.ArcadeViewHooks or {}
    table.insert(RG.ArcadeViewHooks, function(view) if view.mode ~= "album" then b:Hide(); if hall then hall:Hide() end end end)
  end
  local msg = frame.msg and frame.msg.GetText and frame.msg:GetText()
  b:SetShown(not (type(msg) == "string" and msg ~= ""))
  -- (the dungeon page's Mythic button: its plinth instead of the bare card)
  local mb = rawget(frame.albOpen, "mythBtn")
  if mb and not rawget(mb, "mpHooked") then
    mb.mpHooked = true
    mb:SetWidth(170)
    mb:SetScript("OnClick", function() local cc = frame.albOpen.mythCard; local dn = cc and dungeonOf(cc); if dn then RG.ArcadeTrophy(dn) end end)
  end
  if mb then mb:SetEnabled(true) end
end)

-- ---------------------------------------------------------------------------
-- Achievements: the Hearts and the Six
-- ---------------------------------------------------------------------------
do
  local hearts = {}
  local names = {}
  for dn in pairs(RG.ARCADE_SET_MYTHIC or {}) do names[#names + 1] = dn end
  table.sort(names)
  local function heartsHeld(a) return (heartCount(a)) end
  hearts[#hearts + 1] = { id = "hearts7", name = "Seven Hearts", text = "Hold the hearts of 7 dungeons.", pts = 30, need = 7, have = heartsHeld, reward = { edge = true } }
  hearts[#hearts + 1] = { id = "hearts28", name = "Keeper of Hearts", text = "Hold the heart of every dungeon.", pts = 100, need = #names, have = heartsHeld, reward = { title = "Keeper of Hearts" } }
  for _, dn in ipairs(names) do
    local key = RG.ARCADE_SET_MYTHIC[dn]
    hearts[#hearts + 1] = { id = "heart:" .. dn, name = "Heart of " .. dn:gsub("^The ", "the "), text = "Pull " .. dn .. (dn:sub(-1) == "s" and "'" or "'s") .. " Mythic.", pts = 15, need = 1,
      have = function(a) local c = UI().byKey[key]; return owned(a, c) and 1 or 0 end, reward = { coins = 50 } }
  end
  if RG.ArcadeFeatsAdd then RG.ArcadeFeatsAdd("hearts", "Hearts", hearts) end
  local six = {}
  local function sixHeld(a) local n = 0; for _, nm in ipairs(SIX_ORDER) do if owned(a, UI().byKey[nm]) then n = n + 1 end end; return n end
  six[#six + 1] = { id = "six6", name = "Keeper of the Six", text = "Hold all six Waypath Mythics.", pts = 150, need = 6, have = sixHeld, reward = { title = "Keeper of the Six", back = "Radiant" } }
  for _, nm in ipairs(SIX_ORDER) do
    six[#six + 1] = { id = "six:" .. nm, name = nm, text = "Pull " .. nm .. ".", pts = nm == "The 1 Ring" and 50 or 20, need = 1,
      have = function(a) return owned(a, UI().byKey[nm]) and 1 or 0 end, reward = { coins = nm == "The 1 Ring" and 250 or 75 } }
  end
  if RG.ArcadeFeatsAdd then RG.ArcadeFeatsAdd("six", "The Six", six) end
end

-- the Feats tab: tell my guild about my Mythics (on by default)
RG.ArcadeViewHooks = RG.ArcadeViewHooks or {}
table.insert(RG.ArcadeViewHooks, function(view, ctx)
  local u = UI()
  local b = rawget(ctx.frame, "mpAnnounce")
  if view.mode ~= "feats" then if b then b:Hide() end return end
  if not b then
    b = u.gbtn(ctx.frame, "", 186, 22, function()
      local a = store(); if not a then return end
      a.announce = (a.announce == false) and true or false
      RG.ArcadeRefresh(true)
    end)
    b:SetPoint("BOTTOMRIGHT", ctx.frame, "BOTTOMRIGHT", -40, 98)
    ctx.frame.mpAnnounce = b
  end
  local a = ctx.a
  b:SetText("Guild alerts: " .. ((a and a.announce == false) and "off" or "on"))
  b:Show()
end)
