-- Waypath+ cards: the dungeon, raid and holiday packs' own seals, and a print that climbs as it turns (1.45).
-- A dungeon pack is a powder keg: a click lights its fuse, it burns down bead by bead throwing sparks and smoke, the keg
-- strains and glows at the seams, and it goes up in a fireball, staves and hoops flying, smoke rolling out.
-- A raid pack is bound in chains: each click heats the lock, the third snaps them in sparks.
-- A holiday pack is wrapped like a gift: each click loosens the bow, the third pops the lid in a puff of snow.
-- Ordinary packs keep the tear. Arcade.lua calls RG.ArcadeSealHooks ("setup", "pick", "tick", "open") and
-- RG.ArcadeUpgradeMoment when an upgraded card turns over. The art is tools/arcade/art_packfx.py's.
local _, RG = ...
local MEDIA = "Interface\\AddOns\\Waypath\\Media\\Arcade\\"

-- which seal a pack gets: a raid's chains, a holiday's ribbon, any other dungeon's crate (nil: the ordinary tear)
local function sealKind(meta)
  if not (meta and meta.dungeon) or meta.many or meta.gift then return nil end
  for _, d in ipairs(RG.ARCADE_DUNGEONS or {}) do
    if d[1] == meta.dungeon then return d.holiday and "gift" or (d.raid and "chains" or "crate") end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- The powder keg (a dungeon pack): art from tools/arcade/art_keg.py, drawn at the pack's own 160x320
-- ---------------------------------------------------------------------------
local K = 160 / 256                       -- art pixels to the pack's
local BURN, RUMBLE = 1.9, 0.85            -- seconds: the fuse burning down, then the keg straining before it goes
-- the fuse, from its curled tip back to the bung in the lid (art pixels)
local FUSE = { { 186, 57 }, { 200, 54 }, { 210, 70 }, { 198, 88 }, { 178, 86 }, { 165, 100 }, { 160, 117 } }
local BEADS = 26
local function catmull(p, t)
  local n = #p - 1
  local s = math.min(n - 1e-6, math.max(0, t * n))
  local i = math.floor(s) + 1
  local u = s - (i - 1)
  local p0, p1, p2, p3 = p[math.max(1, i - 1)], p[i], p[i + 1], p[math.min(#p, i + 2)]
  local function c(k)
    return 0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * u + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * u * u + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * u * u * u)
  end
  return c(1), c(2)
end

local function fx(reveal)
  local f = rawget(reveal, "packfx")
  if f then return f end
  local seal = reveal.seal
  f = CreateFrame("Frame", nil, seal); f:SetSize(160, 320); f:SetPoint("CENTER", seal, "CENTER", 0, 0)
  f:SetFrameLevel((seal:GetFrameLevel() or 1) + 4)
  local function tex(parent, name, layer, sub, add)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if name then t:SetTexture(MEDIA .. name) end
    if add then t:SetBlendMode("ADD") end
    t:Hide(); return t
  end
  -- the keg: its warm light, the keg, the heat in its seams, the name on its plate
  f.kegLight = tex(f, "Glow", "BACKGROUND", 0, true); f.kegLight:SetSize(330, 420); f.kegLight:SetPoint("CENTER", f, "CENTER", 0, -10)
  f.keg = tex(f, "PackKeg"); f.keg:SetAllPoints(f)
  f.hot = tex(f, "PackKegHot", "ARTWORK", 3, true); f.hot:SetAllPoints(f); f.hot:SetVertexColor(1, 0.45, 0.1)
  f.label = f:CreateFontString(nil, "OVERLAY")
  pcall(f.label.SetFont, f.label, (RG.FONTS and (RG.FONTS.semibold or RG.FONTS.medium)) or "Fonts\\FRIZQT__.TTF", 8, "")   -- (two lines fit "EXCAVATION SITE: WETLANDS")
  f.label:SetPoint("CENTER", f, "TOPLEFT", 80, -300 * K); f.label:SetWidth(90); f.label:SetTextColor(1, 0.86, 0.55)
  if f.label.SetMaxLines then f.label:SetMaxLines(2) end
  f.label:SetShadowColor(0, 0, 0, 1); f.label:SetShadowOffset(1, -1); f.label:Hide()
  -- the fuse, bead by bead, and what burns at its end
  f.beads = {}
  for i = 1, BEADS do
    local b = tex(f, "FuseBit", "ARTWORK", 4); b:SetSize(7, 7)
    local x, y = catmull(FUSE, (i - 1) / (BEADS - 1))
    b:SetPoint("CENTER", f, "TOPLEFT", x * K, -y * K); b.x, b.y = x * K, y * K
    f.beads[i] = b
  end
  f.ember = tex(f, "Glow", "OVERLAY", 1, true); f.ember:SetSize(54, 54); f.ember:SetVertexColor(1, 0.55, 0.15)
  f.flame = tex(f, "Flame", "OVERLAY", 2, true); f.flame:SetSize(11, 22)
  f.spark = tex(f, "Spark", "OVERLAY", 3, true); f.spark:SetVertexColor(1, 0.9, 0.55)
  f.sparks = {}   -- little sparks thrown off the burning end
  for i = 1, 10 do local sp = tex(f, "Spark", "OVERLAY", 3, true); sp:SetVertexColor(1, 0.75, 0.3); f.sparks[i] = { t = sp, life = 0 } end
  f.wisps = {}    -- a thread of smoke rising from it
  for i = 1, 6 do local w = tex(f, "Smoke", "OVERLAY", 0); w:SetVertexColor(0.5, 0.47, 0.44); f.wisps[i] = { t = w, life = 0 } end
  -- the chains (a raid pack) and the ribbon (a holiday pack)
  f.chains = tex(f, "PackChains"); f.chains:SetAllPoints(f)
  f.heat = tex(f, "Glow", "OVERLAY", 1, true); f.heat:SetSize(110, 110); f.heat:SetPoint("CENTER", f, "CENTER", 0, -5); f.heat:SetVertexColor(1, 0.45, 0.15)
  f.lock = tex(f, "PackLock", "OVERLAY", 2); f.lock:SetSize(46, 46)
  f.ribbon = tex(f, "PackRibbon"); f.ribbon:SetAllPoints(f)
  f.bow = tex(f, "PackBow", "OVERLAY", 2); f.bow:SetSize(74, 37)
  -- the blast lives on the reveal (it outlasts the keg)
  local B = CreateFrame("Frame", nil, reveal); B:SetSize(10, 10); B:SetPoint("CENTER", reveal, "CENTER", 0, -12)
  B:SetFrameLevel((reveal:GetFrameLevel() or 1) + 46); B:Hide()
  B.flash = tex(B, nil, "OVERLAY", 7, true); B.flash:SetPoint("TOPLEFT", reveal, "TOPLEFT"); B.flash:SetPoint("BOTTOMRIGHT", reveal, "BOTTOMRIGHT"); B.flash:SetColorTexture(1, 0.85, 0.6, 1)
  B.light = tex(B, "Glow", "BACKGROUND", 0, true); B.light:SetPoint("CENTER"); B.light:SetVertexColor(1, 0.5, 0.15)
  B.shock = tex(B, "Shock", "ARTWORK", 0, true); B.shock:SetPoint("CENTER"); B.shock:SetVertexColor(1, 0.75, 0.45)
  B.ball = tex(B, "Blast", "ARTWORK", 2, true); B.ball:SetPoint("CENTER")
  B.ball2 = tex(B, "Blast", "ARTWORK", 3, true); B.ball2:SetPoint("CENTER")
  B.smoke, B.bits, B.embers = {}, {}, {}
  for i = 1, 12 do B.smoke[i] = { t = tex(B, "Smoke", "BORDER", 0) } end
  for i = 1, 14 do B.bits[i] = { t = tex(B, i <= 10 and "Stave" or "HoopBit", "ARTWORK", 5) } end
  for i = 1, 22 do B.embers[i] = { t = tex(B, "Spark", "OVERLAY", 2, true) } end
  B:SetScript("OnUpdate", function(self, dt)
    self.t = self.t + dt
    local t = self.t
    self.flash:SetAlpha(math.max(0, 0.85 - t / 0.3) ^ 1.5)
    local e = 1 - (1 - math.min(1, t / 0.45)) ^ 3
    self.ball:SetSize(70 + 330 * e, 70 + 330 * e); self.ball:SetAlpha(math.max(0, 1 - math.max(0, t - 0.18) / 0.5))
    if self.ball.SetRotation then self.ball:SetRotation(t * 0.6) end
    local e2 = 1 - (1 - math.min(1, t / 0.7)) ^ 2
    self.ball2:SetSize(40 + 240 * e2, 40 + 240 * e2); self.ball2:SetAlpha(math.max(0, 0.9 - t / 0.75))
    if self.ball2.SetRotation then self.ball2:SetRotation(-t * 0.9 + 1.3) end
    local es = math.min(1, t / 0.55)
    self.shock:SetSize(60 + 700 * es, 60 + 700 * es); self.shock:SetAlpha(math.max(0, 0.9 * (1 - es)))
    self.light:SetSize(500, 500); self.light:SetAlpha(math.max(0, 0.9 - t / 1.2))
    for _, p in ipairs(self.smoke) do
      local k = math.max(0, t - p.delay) / p.life
      if k > 0 and k < 1 then
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt; p.vx, p.vy = p.vx * (1 - 1.8 * dt), p.vy * (1 - 1.2 * dt) + 22 * dt
        local z = p.z0 + p.z1 * (1 - (1 - k) ^ 2)
        p.t:ClearAllPoints(); p.t:SetPoint("CENTER", self, "CENTER", p.x, p.y); p.t:SetSize(z, z)
        local g = 0.22 + 0.5 * math.max(0, 1 - k * 4)   -- lit orange at first, then dark smoke
        p.t:SetVertexColor(g + 0.35 * math.max(0, 1 - k * 5), g * 0.85, g * 0.7, 1)
        p.t:SetAlpha(0.8 * math.min(1, k * 6) * (1 - k) ^ 1.3)
        if p.t.SetRotation then p.t:SetRotation(p.r + k * p.vr) end
        p.t:Show()
      else p.t:Hide() end
    end
    for _, p in ipairs(self.bits) do
      if t < p.life then
        p.vy = p.vy - 950 * dt; p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt; p.r = p.r + p.vr * dt
        p.t:ClearAllPoints(); p.t:SetPoint("CENTER", self, "CENTER", p.x, p.y)
        if p.t.SetRotation then p.t:SetRotation(p.r) end
        p.t:SetAlpha(math.min(1, (p.life - t) / 0.35)); p.t:Show()
      else p.t:Hide() end
    end
    for _, p in ipairs(self.embers) do
      if t < p.life then
        p.vy = p.vy - 380 * dt; p.vx = p.vx * (1 - 0.8 * dt); p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p.t:ClearAllPoints(); p.t:SetPoint("CENTER", self, "CENTER", p.x, p.y)
        p.t:SetAlpha((0.55 + 0.45 * math.random()) * math.min(1, (p.life - t) / 0.4)); p.t:Show()
      else p.t:Hide() end
    end
    if t > 2.4 then self:Hide() end
  end)
  f.boom = B
  f.fade = 0
  f:SetScript("OnUpdate", function(self, dt)
    if self.fade > 0 then
      self.fade = self.fade - dt
      local k = math.max(0, self.fade) / 0.45
      self:SetAlpha(k)
      if self.kind == "gift" then self.bow:ClearAllPoints(); self.bow:SetPoint("CENTER", self, "CENTER", 0, 18 + 120 * (1 - k)) end
      if self.fade <= 0 then self:Hide(); self:SetAlpha(1) end
    end
  end)
  reveal.packfx = f
  return f
end

-- the keg's fuse, burnt back to k (0 none, 1 down to the bung)
local function burnTo(f, k, t, dt)
  local head = math.min(BEADS, math.floor(k * (BEADS - 1)) + 1)
  for i, b in ipairs(f.beads) do
    if i < head then b:Hide()
    else b:Show(); local near = i - head; b:SetVertexColor(near < 2 and 1 or 1, near < 2 and 0.55 + near * 0.2 or 1, near < 2 and 0.3 + near * 0.2 or 1) end
  end
  local hb = f.beads[head]
  local hx, hy = hb.x, hb.y
  if f.lit then
    local fl = 0.75 + 0.25 * math.sin(t * 31) * math.sin(t * 17)
    f.flame:ClearAllPoints(); f.flame:SetPoint("BOTTOM", f, "TOPLEFT", hx, -hy - 2); f.flame:SetSize(10 * fl + 2, 20 * fl + 4); f.flame:SetAlpha(0.9)
    f.spark:ClearAllPoints(); f.spark:SetPoint("CENTER", f, "TOPLEFT", hx, -hy); local z = 16 + 10 * math.random(); f.spark:SetSize(z, z)
    if f.spark.SetRotation then f.spark:SetRotation(t * 7) end
    f.ember:ClearAllPoints(); f.ember:SetPoint("CENTER", f, "TOPLEFT", hx, -hy); f.ember:SetAlpha(0.45 + 0.25 * fl)
    -- sparks spit off the burning end, smoke threads up from it
    for _, sp in ipairs(f.sparks) do
      if sp.life <= 0 and math.random() < dt * 14 then
        sp.life, sp.x, sp.y = 0.25 + math.random() * 0.3, hx, -hy
        local a = math.random() * 6.283; local v = 30 + math.random() * 70
        sp.vx, sp.vy = math.cos(a) * v, math.sin(a) * v + 30
        local z = 3 + math.random() * 5; sp.t:SetSize(z, z)
      end
      if sp.life > 0 then
        sp.life = sp.life - dt; sp.vy = sp.vy - 200 * dt; sp.x, sp.y = sp.x + sp.vx * dt, sp.y + sp.vy * dt
        sp.t:ClearAllPoints(); sp.t:SetPoint("CENTER", f, "TOPLEFT", sp.x, sp.y); sp.t:SetAlpha(math.min(1, sp.life * 5)); sp.t:Show()
      else sp.t:Hide() end
    end
    for _, w in ipairs(f.wisps) do
      if w.life <= 0 and math.random() < dt * 4 then w.life, w.max, w.x, w.y, w.vx = 1.4, 1.4, hx, -hy, (math.random() - 0.3) * 10 end
      if w.life > 0 then
        w.life = w.life - dt; local k2 = 1 - w.life / w.max
        w.x, w.y = w.x + (w.vx + math.sin(t * 2 + w.max) * 6) * dt, w.y + 26 * dt
        w.t:ClearAllPoints(); w.t:SetPoint("CENTER", f, "TOPLEFT", w.x, w.y); local z = 8 + 26 * k2; w.t:SetSize(z, z)
        w.t:SetAlpha(0.35 * math.sin(k2 * 3.1416)); w.t:Show()
      else w.t:Hide() end
    end
  end
end

local function kegShow(f, on)
  for _, t in ipairs({ f.keg, f.label, f.kegLight }) do t:SetShown(on) end
  for _, b in ipairs(f.beads) do b:SetShown(on) end
  if not on then
    f.hot:Hide(); f.flame:Hide(); f.spark:Hide(); f.ember:Hide()
    for _, sp in ipairs(f.sparks) do sp.t:Hide(); sp.life = 0 end
    for _, w in ipairs(f.wisps) do w.t:Hide(); w.life = 0 end
  end
end

-- the pack's own wrapper hides under the keg (and comes back for every other pack)
local function wrapper(reveal, on)
  -- (Arcade.lua sets the trim, the name, the emblem and the stacked packs for every pack; the rest only this hides)
  for _, k in ipairs({ "sealTex", "strip", "stripTrim", "sheenF", "packKind", "sealCount" }) do
    local w = rawget(reveal, k); if w then w:SetShown(on) end
  end
  if not on then
    for _, k in ipairs({ "trim", "packName", "emb" }) do local w = rawget(reveal, k); if w then w:Hide() end end
    for _, bt in ipairs(rawget(reveal, "packBack") or {}) do bt:Hide() end
  end
end

local hooks = {}
local DEFAULT_HINT = "Drag across the top to rip it open   ·   or click it three times"
function hooks.setup(reveal, meta)
  local f = fx(reveal)
  local kind = sealKind(meta)
  f.kind = kind
  f.fade = 0; f:SetAlpha(1); f.lit = false; f.t0 = nil
  f:ClearAllPoints(); f:SetPoint("CENTER", reveal.seal, "CENTER", 0, 0)
  kegShow(f, false)
  for _, t in ipairs({ f.chains, f.heat, f.lock, f.ribbon, f.bow }) do t:Hide() end
  f.boom:Hide()
  reveal.sealHint:SetText(DEFAULT_HINT)   -- (every pack starts from the ordinary hint: no crate's left over)
  local keg = kind == "crate"
  wrapper(reveal, not keg)
  if not kind then f:Hide(); return end
  f:Show()
  if keg then
    reveal.sealOwn = true
    kegShow(f, true); f.hot:Show(); f.hot:SetAlpha(0)
    f.kegLight:SetVertexColor(1, 0.55, 0.2, 0.35)
    f.label:SetText((meta.dungeon or ""):upper())
    burnTo(f, 0, 0, 0)
    reveal.sealHint:SetText("Click the keg to light the fuse")
  elseif kind == "chains" then
    f.chains:Show(); f.lock:Show(); f.heat:Show(); f.heat:SetAlpha(0)
    f.lock:ClearAllPoints(); f.lock:SetPoint("CENTER", f, "CENTER", 0, -5)
    f.chains:SetVertexColor(1, 1, 1); f.lock:SetVertexColor(1, 1, 1)
    reveal.sealHint:SetText("Click the lock three times to break the chains")
  else
    f.ribbon:Show(); f.bow:Show()
    f.bow:ClearAllPoints(); f.bow:SetPoint("CENTER", f, "CENTER", 0, 18)
    reveal.sealHint:SetText("Click the bow three times to unwrap it")
  end
end
function hooks.pick(reveal, n)
  local f = rawget(reveal, "packfx")
  if not (f and rawget(f, "kind")) then return end
  if f.kind == "crate" then
    if not f.lit then
      -- lit: it burns down by itself; clicking again fans it (a little faster), never past the last moment
      f.lit = true; reveal.sealAt = BURN + RUMBLE
      RG.ArcadeFx("fuse")
      reveal.sealHint:SetText("Stand back...")
    elseif (rawget(reveal, "sealAt") or 0) > RUMBLE + 0.25 then
      reveal.sealAt = math.max(RUMBLE + 0.2, reveal.sealAt - 0.3)
    end
  elseif f.kind == "chains" then RG.ArcadeFx("clank") end
end
function hooks.tick(reveal, t, tt)
  local f = rawget(reveal, "packfx")
  if not (f and rawget(f, "kind")) then return end
  if f.kind == "crate" then
    local dt = rawget(f, "lastT") and math.min(0.1, t - f.lastT) or 0; f.lastT = t
    local left = rawget(reveal, "sealAt")
    local burnt = f.lit and left and math.min(1, (BURN + RUMBLE - left) / BURN) or 0
    burnTo(f, burnt, t, dt)
    -- the keg strains: the heat shows in its seams, it shakes harder and harder, its light pulses
    local strain = (f.lit and left and left < RUMBLE) and (1 - left / RUMBLE) or 0
    local h = 0.12 * burnt + 0.9 * strain
    f.hot:SetAlpha(h * (0.75 + 0.25 * math.sin(t * (12 + 30 * strain))))
    f.kegLight:SetVertexColor(1, 0.5, 0.15, 0.3 + 0.25 * burnt + 0.4 * strain)
    local m = (f.lit and 0.6 or 0) + 4.5 * strain * strain
    f:ClearAllPoints(); f:SetPoint("CENTER", reveal.seal, "CENTER", (math.random() - 0.5) * 2 * m, (math.random() - 0.5) * 2 * m)
    if strain > 0 and not rawget(f, "rumbled") then f.rumbled = true; RG.ArcadeFx("rumble") end
    if strain == 0 then f.rumbled = nil end
    if burnt >= 1 then f.flame:Hide(); f.spark:SetSize(26 + 14 * math.random(), 26 + 14 * math.random()) else f.flame:SetShown(f.lit) end
    f.spark:SetShown(f.lit); f.ember:SetShown(f.lit)
  elseif f.kind == "chains" then
    local h = math.min(1, tt / 0.85)
    f.heat:SetAlpha(h * (0.75 + 0.25 * math.sin(t * 9)))
    f.chains:SetVertexColor(1, 1 - 0.45 * h, 1 - 0.7 * h)
    f.lock:SetVertexColor(1, 1 - 0.35 * h, 1 - 0.6 * h)
    f.lock:ClearAllPoints(); f.lock:SetPoint("CENTER", f, "CENTER", math.sin(t * 50) * 1.5 * h, -5)
  else
    f.bow:ClearAllPoints(); f.bow:SetPoint("CENTER", f, "CENTER", math.sin(t * 6) * 2 * tt, 18 + 10 * tt)
    f.ribbon:SetAlpha(1 - 0.35 * tt)
  end
end

local function blowUp(reveal, f)
  local B = f.boom
  B.t = 0
  for _, p in ipairs(B.smoke) do
    local a = math.random() * 6.283; local v = 60 + math.random() * 140
    p.x, p.y, p.vx, p.vy = math.cos(a) * 12, math.sin(a) * 12, math.cos(a) * v, math.sin(a) * v * 0.7 + 30
    p.z0, p.z1, p.delay, p.life = 40 + math.random() * 30, 120 + math.random() * 110, math.random() * 0.15, 1.5 + math.random() * 0.8
    p.r, p.vr = math.random() * 6.283, (math.random() - 0.5) * 2
  end
  for i, p in ipairs(B.bits) do
    local a = -0.3 + math.random() * 3.74   -- mostly up and out
    local v = 260 + math.random() * 320
    p.x, p.y = (math.random() - 0.5) * 70, (math.random() - 0.5) * 120
    p.vx, p.vy = math.cos(a) * v * (p.x < 0 and -1 or 1) * (math.random() < 0.5 and 1 or -1), math.abs(math.sin(a)) * v + 120
    p.r, p.vr = math.random() * 6.283, (math.random() - 0.5) * 18
    p.life = 1.1 + math.random() * 0.5
    local z = 0.65 + math.random() * 0.5
    if i <= 10 then p.t:SetSize(16 * z, 64 * z) else p.t:SetSize(40 * z, 20 * z) end
  end
  for _, p in ipairs(B.embers) do
    local a = math.random() * 6.283; local v = 120 + math.random() * 360
    p.x, p.y, p.vx, p.vy = 0, 0, math.cos(a) * v, math.sin(a) * v + 140
    p.life = 0.6 + math.random() * 0.9
    local z = 5 + math.random() * 10; p.t:SetSize(z, z); p.t:SetVertexColor(1, 0.55 + math.random() * 0.4, 0.2)
  end
  B.flash:SetAlpha(0.85); B.flash:Show(); B.light:Show(); B.shock:Show(); B.ball:Show(); B.ball2:Show()
  B:Show()
end

function hooks.open(reveal)
  local f = rawget(reveal, "packfx")
  if not (f and rawget(f, "kind")) then return end
  local sh = reveal.shards or {}
  if f.kind == "crate" then
    RG.ArcadeFx("boom")
    reveal.shakeT, reveal.shakeK = 0.6, 5
    for _, s in ipairs(sh) do s.tex:Hide() end
    reveal.shardT = 0
    kegShow(f, false)
    blowUp(reveal, f)
    f:SetAlpha(1); f.fade = 0.01
    reveal.sealHint:SetText(DEFAULT_HINT)
    return
  elseif f.kind == "chains" then
    RG.ArcadeFx("snap")
    reveal.shakeT, reveal.shakeK = 0.35, 2
    for i, s in ipairs(sh) do   -- links and sparks
      if i % 2 == 0 then s.tex:SetColorTexture(0.75, 0.75, 0.8, 1); s.tex:SetSize(9, 5)
      else s.tex:SetColorTexture(1, 0.6 + math.random() * 0.3, 0.2, 1); s.tex:SetSize(3, 3) end
    end
  else
    RG.ArcadeFx("giftpop")
    for _, s in ipairs(sh) do   -- snow
      s.tex:SetColorTexture(1, 1, 1, 0.95); local z = 3 + math.random() * 4; s.tex:SetSize(z, z)
      s.vx, s.vy = s.vx * 0.6, math.abs(s.vy) * 0.8 + 200
    end
  end
  f.heat:Hide()
  f.fade = 0.45
end
RG.ArcadeSealHooks = RG.ArcadeSealHooks or {}
table.insert(RG.ArcadeSealHooks, function(event, reveal, ...)
  local fn = hooks[event]
  if fn then fn(reveal, ...) end
end)

-- A print that climbs as it turns: a beat after the card turns over it shivers, light cracks round its frame, a white
-- flash, and it settles as the better print with a tag ("Rare -> Holo"). The card was already saved as the better
-- print (Arcade.lua's pack opening rolls it); this only shows it.
local upfx = setmetatable({}, { __mode = "k" })
function RG.ArcadeUpgradeMoment(card, g, reveal)
  local UI = RG.ArcadeUI
  if not (UI and card and g and g.upgraded) then return end
  local fr = upfx[card]
  if not fr then
    fr = CreateFrame("Frame", nil, card); fr:SetAllPoints(card)
    fr.flash = fr:CreateTexture(nil, "OVERLAY", nil, 7); fr.flash:SetAllPoints(card); fr.flash:SetColorTexture(1, 1, 1, 1); fr.flash:SetBlendMode("ADD")
    fr.sparks = {}
    for i = 1, 5 do
      local s = fr:CreateTexture(nil, "OVERLAY", nil, 6); s:SetTexture(MEDIA .. "Spark"); s:SetBlendMode("ADD"); fr.sparks[i] = s
    end
    upfx[card] = fr
  end
  fr:SetFrameLevel((card:GetFrameLevel() or 1) + 30)
  fr.flash:SetAlpha(0); for _, s in ipairs(fr.sparks) do s:Hide() end
  local p1, rel, p2, x0, y0 = card:GetPoint(1)
  local t, done = 0, false
  local FIN = UI.FINISH or {}
  fr:Show()
  fr:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    if t >= 0.45 and t < 1.05 then
      if not self.started then self.started = true; RG.ArcadeFx("upgrade") end
      local k = (t - 0.45) / 0.6
      if p1 and type(x0) == "number" then card:ClearAllPoints(); card:SetPoint(p1, rel, p2, x0 + math.sin(t * 80) * 2.5 * k, y0 + math.cos(t * 65) * 1.5 * k) end
      for i, s in ipairs(self.sparks) do   -- light cracking along the edge
        if math.random() < 0.25 then
          local side = math.random(4)
          local w, h = card:GetWidth() or 100, card:GetHeight() or 140
          local x = side <= 2 and math.random() * w or (side == 3 and 0 or w)
          local y = side >= 3 and -math.random() * h or (side == 1 and 0 or -h)
          s:ClearAllPoints(); s:SetPoint("CENTER", card, "TOPLEFT", x, y); local z = 10 + math.random() * 16; s:SetSize(z, z); s:Show()
        end
        s:SetAlpha(0.5 + 0.5 * math.random())
      end
    elseif t >= 1.05 and not done then
      done = true
      if p1 and type(x0) == "number" then card:ClearAllPoints(); card:SetPoint(p1, rel, p2, x0, y0) end
      for _, s in ipairs(self.sparks) do s:Hide() end
      self.flash:SetAlpha(1)
      pcall(UI.paint, card, g.card, g.finish, 1)
      local from, to = FIN[g.upgraded] and FIN[g.upgraded][1] or "?", FIN[g.finish] and FIN[g.finish][1] or "?"
      -- (the game's font has no arrow, and the space over the card holds one word)
      if card.new then card.new:SetText("|cffffd36b" .. string.upper(to) .. "!|r") end
      -- the burst in the reveal, in the new print's light
      local b = reveal and rawget(reveal, "burst")
      if b then
        b:ClearAllPoints(); b:SetPoint("CENTER", card, "CENTER", 0, 0)
        local sz = (card.cw or 136) * 3.2; b:SetSize(sz, sz); b:SetVertexColor(1, 0.92, 0.7, 1)
        reveal.burstLeft, reveal.burstMax, reveal.burstSpin = 1.4, 1.4, 0
        b:Show()
      end
    elseif done then
      local k = math.max(0, 1 - (t - 1.05) / 0.35)
      self.flash:SetAlpha(k * k)
      if k <= 0 then self:SetScript("OnUpdate", nil); self.started = nil; self:Hide() end
    end
  end)
end
