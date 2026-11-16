-- Waypath+ cards: the dungeon, raid and holiday packs' own seals, and a print that climbs as it turns (1.45).
-- A dungeon pack is a crate with a fuse: each click burns the fuse down, the third blows it open into planks.
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

local function fx(reveal)
  local f = rawget(reveal, "packfx")
  if f then return f end
  local seal = reveal.seal
  f = CreateFrame("Frame", nil, seal); f:SetAllPoints(seal)
  f:SetFrameLevel((seal:GetFrameLevel() or 1) + 4)
  local function tex(name, layer, sub)
    local t = f:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if name then t:SetTexture(MEDIA .. name) end
    t:Hide(); return t
  end
  local W, H = seal:GetWidth(), seal:GetHeight()
  if type(W) ~= "number" or W <= 0 then W, H = 160, 320 end
  f.crate = tex("PackCrate"); f.crate:SetAllPoints(f)
  f.label = f:CreateFontString(nil, "OVERLAY")
  pcall(f.label.SetFont, f.label, (RG.FONTS and (RG.FONTS.semibold or RG.FONTS.medium)) or "Fonts\\FRIZQT__.TTF", 11, "")
  f.label:SetPoint("CENTER", f, "TOP", 0, -181 * H / 320); f.label:SetTextColor(0.95, 0.84, 0.62); f.label:SetWidth(W - 30); f.label:Hide()
  f.spark = tex("Spark", "OVERLAY", 2); f.spark:SetBlendMode("ADD"); f.spark:SetSize(26, 26); f.spark:SetVertexColor(1, 0.85, 0.45)
  f.ember = tex("Glow", "OVERLAY", 1); f.ember:SetBlendMode("ADD"); f.ember:SetSize(46, 46); f.ember:SetVertexColor(1, 0.6, 0.2)
  f.chains = tex("PackChains"); f.chains:SetAllPoints(f)
  f.heat = tex("Glow", "OVERLAY", 1); f.heat:SetBlendMode("ADD"); f.heat:SetSize(110, 110); f.heat:SetPoint("CENTER", f, "CENTER", 0, -5); f.heat:SetVertexColor(1, 0.45, 0.15)
  f.lock = tex("PackLock", "OVERLAY", 2); f.lock:SetSize(46, 46)
  f.ribbon = tex("PackRibbon"); f.ribbon:SetAllPoints(f)
  f.bow = tex("PackBow", "OVERLAY", 2); f.bow:SetSize(74, 37)
  -- where the fuse burns: from its curled tip down to the crate's lid (seal coordinates, from the top-left)
  f.fusePath = { { 137, 60 }, { 131, 65 }, { 124, 64 }, { 116, 67 }, { 111, 72 } }   -- (PackCrate.tga's fuse at the pack's 160x320)
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

local function setSpark(f, k)
  -- k 0..1: how far the fuse has burnt
  local p = f.fusePath
  local s = math.min(#p - 1, k * (#p - 1))
  local i = math.floor(s) + 1
  local fr = s - (i - 1)
  local a, b = p[i], p[math.min(#p, i + 1)]
  local x, y = a[1] + (b[1] - a[1]) * fr, a[2] + (b[2] - a[2]) * fr
  f.spark:ClearAllPoints(); f.spark:SetPoint("CENTER", f, "TOPLEFT", x, -y)
  f.ember:ClearAllPoints(); f.ember:SetPoint("CENTER", f, "TOPLEFT", x, -y)
end

local hooks = {}
function hooks.setup(reveal, meta)
  local f = fx(reveal)
  local kind = sealKind(meta)
  f.kind = kind
  f.fade = 0; f:SetAlpha(1)
  for _, t in ipairs({ f.crate, f.label, f.spark, f.ember, f.chains, f.heat, f.lock, f.ribbon, f.bow }) do t:Hide() end
  -- the wrapper's own pieces: a crate covers the whole pack (its strip and name too)
  local crate = kind == "crate"
  reveal.strip:SetShown(not crate); reveal.stripTrim:SetShown(not crate)
  if crate then reveal.packName:Hide(); reveal.emb:Hide() end
  if not kind then f:Hide(); return end
  f:Show()
  if kind == "crate" then
    f.crate:Show(); f.spark:Show(); f.ember:Show(); setSpark(f, 0)
    f.label:SetText((meta.dungeon or ""):upper()); f.label:Show()
    reveal.sealHint:SetText("Click the crate three times to light the fuse")
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
  if not (f and f.kind) then return end
  if f.kind == "crate" then RG.ArcadeFx("fuse")
  elseif f.kind == "chains" then RG.ArcadeFx("clank") end
end
function hooks.tick(reveal, t, tt)
  local f = rawget(reveal, "packfx")
  if not (f and f.kind) then return end
  if f.kind == "crate" then
    setSpark(f, tt / 0.85)
    local fl = 0.6 + 0.4 * math.random()
    f.spark:SetAlpha(fl); f.ember:SetAlpha(0.5 + 0.4 * tt * fl)
    local s = 20 + 14 * tt + 6 * fl
    f.spark:SetSize(s, s)
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
function hooks.open(reveal)
  local f = rawget(reveal, "packfx")
  if not (f and f.kind) then return end
  local sh = reveal.shards or {}
  if f.kind == "crate" then
    RG.ArcadeFx("boom")
    reveal.shakeT, reveal.shakeK = 0.45, 3
    for _, s in ipairs(sh) do   -- planks
      local g = 0.35 + math.random() * 0.25
      s.tex:SetColorTexture(g * 1.6, g * 1.1, g * 0.6, 1)
      if math.random() < 0.5 then s.tex:SetSize(4 + math.random() * 3, 14 + math.random() * 12) else s.tex:SetSize(14 + math.random() * 12, 4 + math.random() * 3) end
      s.vx, s.vy = s.vx * 1.4, s.vy * 1.2 + 120
    end
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
  f.spark:Hide(); f.ember:Hide(); f.heat:Hide()
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
      if card.new then card.new:SetText("|cffffd36bUPGRADED|r  |cffe8dcc0" .. from .. " → " .. to .. "|r") end
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
