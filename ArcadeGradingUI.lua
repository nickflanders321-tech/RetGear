local _, RG = ...
-- Waypath Cards: grading, drawn (1.53). The rules are in ArcadeGrading.lua.
--   * the case: an acrylic case with an engraved plate (the guild, the card's name, its set and print, the certificate)
--     and a seal with the grade: gold for a 10, silver for 8 and 9, bronze below. Below the card page's size it shows
--     only the name and the grade number. Worn cards show it (Wear*.tga over the card, each part from its own score).
--   * the grading desk: in the Shop (its own section), and from any card's page (Grade a copy)
--   * the parcel and the reveal: the seal cracks, the case comes out under the grader's cloth, the four scores roll
--     in, the last one says what it needs, the cloth comes off and the seal lands
--   * /wp gradecheck puts every card in a case at every size and lists anything that doesn't fit;
--     /wp gradetour steps through every kind of card in a case, at every size and wear, and can play the reveal

local function U() return RG.ArcadeUI end
local function store() local u = U(); return u and u.store and u.store() end
local MEDIA = "Interface\\AddOns\\Waypath\\Media\\Arcade\\"
local CARD_V = 358 / 512
local CASE_V = 834 / 1024
local CASE_W, CASE_H = 296, 482          -- units: the card is 256 wide inside it
local SMALL = 200                         -- below this card width the case shows only the name and the grade number
local GR = function() return RG.ARCADE_GRADE end
local SEAL_CELL = { gold = 0, silver = 1, bronze = 2, none = 3 }
local SEAL_INK = { gold = { 1, 0.86, 0.45 }, silver = { 0.88, 0.9, 0.95 }, bronze = { 0.94, 0.72, 0.52 }, none = { 0.55, 0.5, 0.42 } }
local GOLD = "|cffffd36b"

local function lvOf(f) return (f and f.GetFrameLevel and f:GetFrameLevel()) or 1 end
local function decode(s) return RG.ArcadeGradeDecode and RG.ArcadeGradeDecode(s) end
local function cardOf(key) local u = U(); return u and u.byKey and u.byKey[key] end

-- ---------------------------------------------------------------------------
-- Wear on a card: a layer over the card (above its frame, below stamps and badges)
-- ---------------------------------------------------------------------------
local function wearLayer(w)
  local wl = rawget(w, "wear")
  if wl then return wl end
  wl = CreateFrame("Frame", nil, w); wl:SetAllPoints(w)
  if RG.ArcadeLayer then RG.ArcadeLayer(w, wl, 5) end
  wl.parts = {}
  for _, k in ipairs({ "Surface", "Edges", "Corners" }) do
    local t = wl:CreateTexture(nil, "OVERLAY"); t:SetAllPoints(wl); t:SetTexCoord(0, 1, 0, CARD_V); t:Hide()
    wl.parts[k] = t
  end
  rawset(w, "wear", wl)
  return wl
end
-- the grid's sign of a graded card: a small seal with the grade, and the case's sheen
local function gridBadge(w)
  local b = rawget(w, "gradeBadge")
  if b then return b end
  b = CreateFrame("Frame", nil, w); b:SetAllPoints(w)
  if RG.ArcadeLayer then RG.ArcadeLayer(w, b, 6) end
  local u = w.u or (w:GetWidth() / 256)
  b.shine = b:CreateTexture(nil, "ARTWORK"); b.shine:SetTexture(MEDIA .. "GradeShine"); b.shine:SetBlendMode("ADD"); b.shine:SetAllPoints(w)
  b.shine:SetTexCoord(0, 1, 0, CARD_V); b.shine:SetAlpha(0.55)
  b.seal = b:CreateTexture(nil, "OVERLAY", nil, 1); b.seal:SetTexture(MEDIA .. "GradeSeals"); b.seal:SetSize(50 * u, 50 * u)
  b.seal:SetPoint("CENTER", w, "TOPLEFT", 224 * u, -186 * u)
  b.num = U().fs(b, "title", math.max(9, 22 * u), "OVERLAY", "OUTLINE"); b.num:SetPoint("CENTER", b.seal, "CENTER", 0, 0)
  rawset(w, "gradeBadge", b)
  return b
end
local function sealTex(t, kind) local c = SEAL_CELL[kind] or 3; t:SetTexCoord(c * 0.25, (c + 1) * 0.25, 0, 1) end

RG.ArcadeCardHooks = RG.ArcadeCardHooks or {}
table.insert(RG.ArcadeCardHooks, function(w, card, finish)
  local wl = rawget(w, "wear")
  local bd = rawget(w, "gradeBadge")
  if not card then
    if wl then wl:Hide() end
    if bd then bd:Hide() end
    if rawget(w, "slabOn") then local sl = rawget(w, "slab"); if sl then sl:Hide() end; w.slabOn = nil; w:SetAlpha(1) end
    return
  end
  -- a card in a case: its wear
  local rec = rawget(w, "gradeRec")
  local s = rec and (rec.sv or decode(rec.s))
  if s and RG.ArcadeGradeWear then
    local wr = RG.ArcadeGradeWear(s)
    local layer = wearLayer(w)
    for k, t in pairs(layer.parts) do
      local n = wr[k:lower()] or 0
      if n > 0 then t:SetTexture(MEDIA .. "Wear" .. k .. n); t:Show() else t:Hide() end
    end
    layer:Show()
  elseif wl then wl:Hide() end
  -- a card in the collection grid with a graded copy: in its case (the slab), drawn over the bare card
  if rawget(w, "collect") and RG.ArcadeGradeShown and RG.ArcadeMakeCase then
    local r = RG.ArcadeGradeShown(card.key or card.name)
    if r and r.f == finish and (w.cw or 0) >= 90 and (w.cw or 0) <= 130 then
      local sl = rawget(w, "slab")
      if not sl then
        sl = RG.ArcadeMakeCase(w:GetParent() or UIParent, 76)
        w.slab = sl
        -- (it is the window's child, not the card's, so the card can fade out under it without fading the case)
        w:HookScript("OnHide", function(self) local x = rawget(self, "slab"); if x then x:Hide() end end)
        local function follow(self) local x = rawget(self, "slab"); if x and x:IsShown() then x:SetFrameLevel((self:GetFrameLevel() or 1) + 1) end end
        w:HookScript("OnEnter", follow); w:HookScript("OnLeave", follow)
      end
      sl:ClearAllPoints(); sl:SetPoint("TOPLEFT", w, "TOPLEFT", (w.cw - sl:GetWidth()) / 2, 2)
      sl:SetRec(r)
      sl:SetFrameLevel((w:GetFrameLevel() or 1) + 1)
      sl:Show()
      -- (the bare card under the slab: faded out, but a 3D model ignores its parent's fade, so it is put away too)
      w:SetAlpha(0); w.slabOn = true
      local bm = rawget(w, "model"); if bm then bm:Hide() end
      if bd then bd:Hide() end
      return
    end
  end
  if rawget(w, "slabOn") then
    local sl = rawget(w, "slab"); if sl then sl:Hide() end
    w.slabOn = nil; w:SetAlpha(1)
  end
  if bd then bd:Hide() end
end)

-- ---------------------------------------------------------------------------
-- The case
-- ---------------------------------------------------------------------------
local function fitName(t, text, maxW, size, minSize)
  -- one line, a step smaller if it must; then two lines, as large as fits (the name is never cut short)
  local u = U()
  local function width(str) t:SetText(str); local wd = t.GetUnboundedStringWidth and t:GetUnboundedStringWidth() or t:GetStringWidth(); return type(wd) == "number" and wd or 0 end
  t:SetWordWrap(false); if t.SetMaxLines then t:SetMaxLines(1) end
  t:SetWidth(0)
  for sz = size, size * 0.86, -0.5 do
    u.setfont(t, "title", sz)
    if width(text) <= maxW + 0.5 then t:SetText(text); t:SetWidth(maxW); return 1 end
  end
  -- two lines: the break that makes the longer line shortest, at the largest size where that line fits
  local words = {}
  for w in text:gmatch("%S+") do words[#words + 1] = w end
  local best = size * 0.86
  for sz = size * 0.86, minSize, -0.5 do
    best = sz
    u.setfont(t, "title", sz)
    local ok = false
    for cut = 1, #words - 1 do
      local a = table.concat(words, " ", 1, cut); local b = table.concat(words, " ", cut + 1)
      if width(a) <= maxW + 0.5 and width(b) <= maxW + 0.5 then ok = true; break end
    end
    if ok then break end
  end
  u.setfont(t, "title", best)
  t:SetWidth(maxW); t:SetWordWrap(true); if t.SetMaxLines then t:SetMaxLines(2) end
  t:SetText(text)
  return 2
end

-- makeCase(parent, cardWidth): the case and the card inside it; case:SetRec(rec) shows a graded copy,
-- case:SetPending(card, finish, svc) a copy on its way (a dark seal with a "?")
local function makeCase(parent, cw)
  local u = U()
  local k = cw / 256
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(CASE_W * k, CASE_H * k)
  f.k, f.cw, f.small = k, cw, cw < SMALL
  f.grid = cw <= 90   -- the collection grid's slab: a seal with the grade, no words
  f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetTexture(MEDIA .. "GradeCase"); f.bg:SetTexCoord(0, 1, 0, CASE_V); f.bg:SetAllPoints(f)
  f.card = u.makeCard(f, cw)
  f.card.noTip = true; f.card.hover = false; f.card:EnableMouse(false)
  f.card:SetPoint("TOPLEFT", f, "TOPLEFT", 20 * k, -104 * k)
  f.card:SetFrameLevel(lvOf(f) + 2)
  f.glass = CreateFrame("Frame", nil, f); f.glass:SetAllPoints(f); f.glass:SetFrameLevel(lvOf(f) + 16)
  f.shine = f.glass:CreateTexture(nil, "ARTWORK"); f.shine:SetTexture(MEDIA .. "GradeShine"); f.shine:SetBlendMode("ADD"); f.shine:SetAllPoints(f)
  f.shine:SetTexCoord(0, 1, 0, CASE_H / CASE_W * 256 / 512); f.shine:SetAlpha(0.6)
  f.label = CreateFrame("Frame", nil, f); f.label:SetFrameLevel(lvOf(f) + 17)
  -- (the case's own stack: put back whenever the case's level changes, as a card's is)
  local setLevel = f.SetFrameLevel
  f.SetFrameLevel = function(self, l)
    setLevel(self, l)
    self.card:SetFrameLevel(l + 2); self.glass:SetFrameLevel(l + 16); self.label:SetFrameLevel(l + 17)
    if rawget(self, "cloth") then self.cloth:SetFrameLevel(l + 14) end
  end
  f.label:SetPoint("TOPLEFT", f, "TOPLEFT", 10 * k, -10 * k); f.label:SetSize(276 * k, 74 * k)
  local L = f.label
  L.guild = u.fs(L, "head", 9 * k); L.guild:SetPoint("TOPLEFT", 12 * k, -9 * k); L.guild:SetText("WAYPOINT GRADING GUILD"); L.guild:SetTextColor(0.79, 0.64, 0.29)
  L.guild:SetShadowColor(0, 0, 0, 0)
  L.name = u.fs(L, "title", 15 * k); L.name:SetJustifyH("LEFT"); L.name:SetJustifyV("TOP"); L.name:SetTextColor(0.95, 0.92, 0.84)
  L.meta = u.fs(L, "head", 10 * k); L.meta:SetJustifyH("LEFT"); L.meta:SetTextColor(0.66, 0.62, 0.54); L.meta:SetShadowColor(0, 0, 0, 0)
  L.cert = u.fs(L, "body", 9 * k); L.cert:SetJustifyH("LEFT"); L.cert:SetTextColor(0.48, 0.45, 0.39); L.cert:SetShadowColor(0, 0, 0, 0)
  L.seal = L:CreateTexture(nil, "ARTWORK"); L.seal:SetTexture(MEDIA .. "GradeSeals"); L.seal:SetSize(64 * k, 64 * k)
  L.seal:SetPoint("TOPRIGHT", L, "TOPRIGHT", -7 * k, -5 * k)
  L.halo = L:CreateTexture(nil, "BACKGROUND"); L.halo:SetTexture(MEDIA .. "Glow"); L.halo:SetBlendMode("ADD"); L.halo:SetSize(110 * k, 110 * k)
  L.halo:SetPoint("CENTER", L.seal, "CENTER"); L.halo:SetVertexColor(1, 0.85, 0.4, 0.8); L.halo:Hide()
  L.g = u.fs(L, "title", (f.small and 30 or 26) * k, "OVERLAY", nil); L.g:SetPoint("CENTER", L.seal, "CENTER", 0, f.small and 0 or 3 * k)
  L.w = u.fs(L, "head", 7 * k); L.w:SetPoint("TOP", L.g, "BOTTOM", 0, 0); L.w:SetTextColor(1, 0.95, 0.82)
  if f.grid then
    -- the grid's slab: "GRADING GUILD" in two small lines, and the seal with the grade
    u.setfont(L.guild, "head", 6); L.guild:ClearAllPoints(); L.guild:SetPoint("LEFT", L, "LEFT", 7, 0); L.guild:SetWidth(40); L.guild:SetJustifyH("LEFT")
    if L.guild.SetWordWrap then L.guild:SetWordWrap(true) end
    L.guild:SetText("GRADING\nGUILD")
    L.seal:SetSize(26, 26); L.seal:ClearAllPoints(); L.seal:SetPoint("RIGHT", L, "RIGHT", -4, 0)
    u.setfont(L.g, "title", 14, "OUTLINE"); L.g:ClearAllPoints(); L.g:SetPoint("CENTER", L.seal, "CENTER", 0, 0)
    L.halo:SetSize(40, 40)
    if f.card.SetClipsChildren then f.card:SetClipsChildren(true) end
  end
  function f:Layout(lines)
    L.name:ClearAllPoints()
    if self.grid then
      L.name:Hide(); L.meta:Hide(); L.cert:Hide(); L.w:Hide(); L.guild:Show()
      return
    end
    L.name:Show()
    if self.small then
      L.guild:Hide(); L.meta:Hide(); L.cert:Hide(); L.w:Hide()
      L.name:SetPoint("LEFT", L, "LEFT", 12 * k, 0)
    else
      L.guild:Show(); L.meta:Show(); L.cert:Show(); L.w:Show()
      L.name:SetPoint("TOPLEFT", L, "TOPLEFT", 12 * k, -20 * k)
      L.meta:ClearAllPoints(); L.meta:SetPoint("TOPLEFT", L.name, "BOTTOMLEFT", 0, -3 * k)
      L.cert:ClearAllPoints(); L.cert:SetPoint("TOPLEFT", L.meta, "BOTTOMLEFT", 0, -2 * k)
      L.cert:SetShown(lines ~= 2)   -- (a two-line name: the certificate is on the card's page)
    end
  end
  local function nameIn(text)
    if f.grid then f.lines = 1; f:Layout(1) return end
    local maxW = (276 - 12 - 76) * k
    local size = (f.small and 19 or 15) * k
    local lines = fitName(L.name, text, maxW, size, 6)
    f.lines = lines
    f:Layout(lines)
  end
  function f:Seal(kind, grade)
    sealTex(L.seal, kind)
    L.g:SetText(grade and tostring(grade) or "?")
    local ink = SEAL_INK[kind] or SEAL_INK.none
    L.g:SetTextColor(kind == "none" and ink[1] or 1, kind == "none" and ink[2] or 0.98, kind == "none" and ink[3] or 0.92)
    L.w:SetText(grade and RG.ArcadeGradeName(grade):upper() or "")
    L.halo:SetShown(kind == "gold")
  end
  function f:SetRec(rec, sv)
    local c = rec and cardOf(rec.key)
    self.rec = rec
    if not c then self:Hide() return end
    rawset(self.card, "gradeRec", { s = rec.s, sv = sv })
    local s = sv or decode(rec.s)
    -- centering: an off-centre card sits a little off in its well
    local off = 0
    if s and RG.ArcadeGradeWear then off = RG.ArcadeGradeWear(s).centering or 0 end
    self.card:ClearAllPoints(); self.card:SetPoint("TOPLEFT", self, "TOPLEFT", (20 + off * 1.2) * k, -(104 + off * 0.8) * k)
    u.paint(self.card, c, rec.f, nil)
    nameIn(c.name)
    local set = (u.setOf and u.setOf(c)) or ""
    local FN = u.FINISH[rec.f] and u.FINISH[rec.f][1] or ""
    L.meta:SetText((set ~= "" and (set:upper() .. "  ·  ") or "") .. FN:upper())
    L.cert:SetText("CERT " .. string.format("%07d", rec.cert or 0) .. "  ·  " .. (rec.when or ""):upper())
    if rec.grade then self:Seal(RG.ArcadeGradeSeal(rec.grade), rec.grade) else self:Seal("none", nil) end
    self:Show()
  end
  function f:SetPending(c, fin)
    rawset(self.card, "gradeRec", nil)
    self.rec = nil
    self.card:ClearAllPoints(); self.card:SetPoint("TOPLEFT", self, "TOPLEFT", 20 * k, -104 * k)
    u.paint(self.card, c, fin, nil)
    nameIn(c.name)
    L.meta:SetText(((u.setOf and u.setOf(c)) or ""):upper() .. "  ·  " .. (u.FINISH[fin] and u.FINISH[fin][1]:upper() or ""))
    L.cert:SetText("NOT GRADED YET")
    self:Seal("none", nil)
    self:Show()
  end
  return f
end
RG.ArcadeMakeCase = makeCase

-- the collection grid's hover: a graded copy of the card under the mouse is shown in its case, full size beside the window
function RG.ArcadeGradeInspect(win, cell, toRight)
  if not (cell.card and RG.ArcadeGradeShown) then return nil end
  local r = RG.ArcadeGradeShown(cell.card.key or cell.card.name)
  if not (r and r.f == cell.finish) then
    if rawget(win, "inspCase") then win.inspCase:Hide() end
    return nil
  end
  if not rawget(win, "inspCase") then
    win.inspCase = makeCase(win, 200)
    win.inspCase:SetFrameLevel((win:GetFrameLevel() or 1) + 40)
  end
  local ic = win.inspCase
  ic:ClearAllPoints()
  if toRight then ic:SetPoint("TOPLEFT", win, "TOPRIGHT", 8, -90) else ic:SetPoint("TOPRIGHT", win, "TOPLEFT", -8, -90) end
  ic:SetRec(r)
  ic:Show()
  return ic
end
function RG.ArcadeGradeInspectHide(win) local ic = rawget(win, "inspCase"); if ic then ic:Hide() end end

-- ---------------------------------------------------------------------------
-- A confirmation inside a window (no game popups): two buttons over a dimmed panel
-- ---------------------------------------------------------------------------
local function confirmBox(parent)
  local u = U()
  local c = CreateFrame("Frame", nil, parent, "BackdropTemplate"); c:SetFrameLevel(lvOf(parent) + 60)
  c:SetSize(380, 132); c:SetPoint("CENTER", parent, "CENTER", 0, 0)
  c:SetBackdrop({ bgFile = u.WHITE, edgeFile = u.WHITE, edgeSize = 2 }); c:SetBackdropColor(0.12, 0.08, 0.04, 0.98); c:SetBackdropBorderColor(0.85, 0.66, 0.3, 1)
  c:EnableMouse(true)
  c.text = u.fs(c, "body", 13); c.text:SetPoint("TOP", 0, -16); c.text:SetWidth(340); c.text:SetJustifyH("CENTER"); c.text:SetTextColor(1, 0.94, 0.8)
  c.yes = u.gbtn(c, "Yes", 150, 26, function() c:Hide(); if c.onYes then c.onYes() end end); c.yes:SetPoint("BOTTOMLEFT", 30, 16)
  c.no = u.gbtn(c, "Keep it", 150, 26, function() c:Hide() end); c.no:SetPoint("BOTTOMRIGHT", -30, 16)
  c:Hide()
  function c:Ask(text, yes, onYes) self.text:SetText(text); self.yes:SetText(yes); self.onYes = onYes; self:Show() end
  return c
end

-- ---------------------------------------------------------------------------
-- The grading desk: a section of the Shop
-- ---------------------------------------------------------------------------
local desk
local sel = { key = nil, f = nil, copy = 1, svc = "standard", cert = nil }
local function timeLeft(secs)
  secs = math.max(0, math.floor(secs))
  local h, m = math.floor(secs / 3600), math.floor(secs % 3600 / 60)
  if h > 0 then return h .. "h " .. m .. "m" end
  if m > 0 then return m .. "m" end
  return "a moment"
end
-- (the window's message line: it fits the note to its line and clears it after a while, Arcade.lua)
local function say(text) if RG.ArcadeMsg then RG.ArcadeMsg(text) elseif RG.Print then RG.Print(text) end end

local function buildDesk(frame)
  local u = U()
  desk = CreateFrame("Frame", nil, frame); desk:SetAllPoints(frame); desk:SetFrameLevel(lvOf(frame) + 6)
  local X0 = 34
  desk.back = u.gbtn(desk, "<  Shop", 78, 24, function() local v = RG.ArcadeView; if v then v.shopSection = nil; v.gradeCert = nil; v.gradeLedger = nil end; RG.ArcadeRefresh(true) end)
  desk.back:SetPoint("TOPLEFT", X0, -156)
  desk.head = u.fs(desk, "title", 15); desk.head:SetPoint("LEFT", desk.back, "RIGHT", 14, 0); desk.head:SetTextColor(1, 0.92, 0.7)
  desk.right = u.fs(desk, "body", 12); desk.right:SetPoint("TOPRIGHT", desk, "TOPRIGHT", -X0, -163); desk.right:SetJustifyH("RIGHT"); desk.right:SetTextColor(0.85, 0.78, 0.6)
  desk.line = desk:CreateTexture(nil, "ARTWORK"); desk.line:SetColorTexture(0.72, 0.58, 0.3, 0.45); desk.line:SetHeight(1)
  desk.line:SetPoint("TOPLEFT", X0, -184); desk.line:SetPoint("TOPRIGHT", -X0, -184)
  local function box(x, y, w, h, title)
    local b = CreateFrame("Frame", nil, desk, "BackdropTemplate"); b:SetPoint("TOPLEFT", desk, "TOPLEFT", x, y); b:SetSize(w, h)
    b:SetBackdrop({ bgFile = u.WHITE, edgeFile = u.WHITE, edgeSize = 1 }); b:SetBackdropColor(0.13, 0.11, 0.08, 0.92); b:SetBackdropBorderColor(0.42, 0.33, 0.18, 1)
    b.h = u.fs(b, "title", 12); b.h:SetPoint("TOPLEFT", 14, -12); b.h:SetText(title); b.h:SetTextColor(1, 0.83, 0.42)
    return b
  end
  -- the desk: the card to send (left), the case it will go in (middle), how fast and the slots (right)
  -- (every box ends above the window's message line, which runs from 652 down)
  desk.pick = box(X0, -196, 236, 448, "YOUR COPIES")
  desk.pick.hint = u.fs(desk.pick, "body", 12.5); desk.pick.hint:SetPoint("TOPLEFT", 14, -36); desk.pick.hint:SetWidth(208); desk.pick.hint:SetJustifyH("LEFT")
  desk.pick.hint:SetTextColor(0.8, 0.75, 0.64); desk.pick.hint:SetSpacing(2)
  desk.copies = {}
  for i = 1, 8 do
    local b = u.gbtn(desk.pick, "", 208, 26, function()
      local v = RG.ArcadeView
      if v and v.gradeBatch then RG.ArcadeGradeBatchRemove(i) else sel.copy = i end
      RG.ArcadeRefresh(true)
    end)
    b:SetPoint("TOPLEFT", 14, -36 - (i - 1) * 30); desk.copies[i] = b
  end
  desk.pick.foot = u.fs(desk.pick, "body", 11.5); desk.pick.foot:SetPoint("BOTTOMLEFT", 14, 14); desk.pick.foot:SetWidth(208); desk.pick.foot:SetJustifyH("LEFT")
  desk.pick.foot:SetTextColor(0.62, 0.58, 0.5); desk.pick.foot:SetSpacing(2)
  desk.pick.foot:SetText("Every print is graded the same way. A copy in a case can't be sold as an extra or crafted, but it can be sold for its grade.")
  desk.case = makeCase(desk, 172); desk.case:SetPoint("TOP", desk, "TOPLEFT", X0 + 236 + 12 + 100, -200)
  desk.caseNote = u.fs(desk, "body", 11.5); desk.caseNote:SetPoint("TOP", desk.case, "BOTTOM", 0, -8); desk.caseNote:SetTextColor(0.7, 0.66, 0.56)
  desk.svcBox = box(X0 + 236 + 224, -196, 262, 226, "HOW FAST")
  desk.svc = {}
  for i, key in ipairs({ "standard", "express" }) do
    local b = u.gbtn(desk.svcBox, "", 234, 44, function() sel.svc = key; RG.ArcadeRefresh(true) end)
    b:SetPoint("TOPLEFT", 14, -34 - (i - 1) * 50)
    b.label:ClearAllPoints(); b.label:SetPoint("LEFT", 12, 7); b.label:SetJustifyH("LEFT")
    b.sub = u.fs(b, "body", 11); b.sub:SetPoint("LEFT", 12, -9); b.sub:SetTextColor(0.75, 0.7, 0.6)
    b.price = u.fs(b, "head", 12.5); b.price:SetPoint("RIGHT", -12, 0); b.price:SetJustifyH("RIGHT")
    desk.svc[key] = b
  end
  desk.freeLine = u.fs(desk.svcBox, "body", 11.5); desk.freeLine:SetPoint("TOPLEFT", 14, -140); desk.freeLine:SetWidth(234); desk.freeLine:SetJustifyH("LEFT"); desk.freeLine:SetTextColor(0.62, 0.83, 1)
  desk.send = u.gbtn(desk.svcBox, "Send to the graders", 234, 30, function()
    local v = RG.ArcadeView
    if v and v.gradeBatch then
      local ok, msg = RG.ArcadeGradeBatchSend(sel.svc); say(msg)
      if ok and RG.ArcadeSound then RG.ArcadeSound("pick") end
      if #RG.ArcadeGradeBatchList() == 0 then v.gradeBatch = false end
      RG.ArcadeRefresh(true); return
    end
    if not (sel.key and sel.f) then return end
    local ok, msg = RG.ArcadeGradeSend(sel.key, sel.f, sel.svc, sel.copy); say(msg)
    if ok then sel.copy = 1; if RG.ArcadeSound then RG.ArcadeSound("pick") end end
    RG.ArcadeRefresh(true)
  end, true)
  desk.send:SetPoint("BOTTOMLEFT", 14, 14)
  -- the batch: a button at the top right of the copies box opens it (and closes it), and one under the copies adds
  desk.bView = u.gbtn(desk.pick, "Batch", 72, 20, function()
    local v = RG.ArcadeView; if not v then return end
    v.gradeBatch = not v.gradeBatch; RG.ArcadeRefresh(true)
  end); desk.bView:SetPoint("TOPRIGHT", -8, -8)
  desk.bAdd = u.gbtn(desk.pick, "Add this copy to the batch", 208, 26, function()
    if not (sel.key and sel.f) then return end
    local ok, msg = RG.ArcadeGradeBatchAdd(sel.key, sel.f); say(msg)
    RG.ArcadeRefresh(true)
  end); desk.bAdd:SetPoint("BOTTOMLEFT", 14, 96)
  desk.slotBox = box(X0 + 236 + 224, -432, 262, 212, "AT THE GRADERS")
  desk.slots = {}
  for i = 1, 5 do
    local r = CreateFrame("Frame", nil, desk.slotBox); r:SetSize(234, 34); r:SetPoint("TOPLEFT", 14, -32 - (i - 1) * 35)
    r.name = u.fs(r, "body", 12); r.name:SetPoint("TOPLEFT", 0, -2); r.name:SetWidth(150); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.t = u.fs(r, "head", 11.5); r.t:SetPoint("TOPRIGHT", 0, -2); r.t:SetJustifyH("RIGHT"); r.t:SetTextColor(0.62, 0.83, 1)
    r.barBg = r:CreateTexture(nil, "ARTWORK"); r.barBg:SetColorTexture(0.18, 0.16, 0.13, 1); r.barBg:SetPoint("BOTTOMLEFT", 0, 6); r.barBg:SetSize(234, 5)
    r.bar = r:CreateTexture(nil, "OVERLAY"); r.bar:SetColorTexture(0.42, 0.65, 1, 1); r.bar:SetPoint("BOTTOMLEFT", 0, 6); r.bar:SetSize(1, 5)
    r.open = u.gbtn(r, "Open", 70, 22, function() if RG.ArcadeGradeReveal then RG.ArcadeGradeReveal(r.backIndex) end end); r.open:SetPoint("RIGHT", 0, 0); r.open:Hide()
    desk.slots[i] = r
  end
  -- your cases (a list under the desk's title when no card is picked; the page for one)
  desk.cases = {}
  for i = 1, 8 do
    local b = CreateFrame("Button", nil, desk.pick); b:SetSize(208, 26); b:SetPoint("TOPLEFT", 14, -112 - (i - 1) * 29)   -- 8 rows end at -341: above the page arrows (-348) and the note under them
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b); b.bg:SetColorTexture(1, 0.85, 0.5, 0.06)
    b.seal = b:CreateTexture(nil, "ARTWORK"); b.seal:SetTexture(MEDIA .. "GradeSeals"); b.seal:SetSize(22, 22); b.seal:SetPoint("LEFT", 2, 0)
    b.g = u.fs(b, "title", 10.5, "OVERLAY", "OUTLINE"); b.g:SetPoint("CENTER", b.seal, "CENTER", 0, 0)
    b.name = u.fs(b, "body", 12); b.name:SetPoint("LEFT", b.seal, "RIGHT", 6, 0); b.name:SetWidth(170); b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b:SetScript("OnClick", function(self) local v = RG.ArcadeView; if v and self.cert then v.gradeCert = self.cert; RG.ArcadeRefresh(true) end end)
    b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(1, 0.85, 0.5, 0.14) end)
    b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 0.85, 0.5, 0.06) end)
    desk.cases[i] = b
  end
  desk.casePage = 1
  desk.casePrev = u.gbtn(desk.pick, "<", 30, 22, function() desk.casePage = math.max(1, desk.casePage - 1); RG.ArcadeRefresh(true) end); desk.casePrev:SetPoint("BOTTOMLEFT", 14, 78)
  desk.caseNext = u.gbtn(desk.pick, ">", 30, 22, function() desk.casePage = desk.casePage + 1; RG.ArcadeRefresh(true) end); desk.caseNext:SetPoint("LEFT", desk.casePrev, "RIGHT", 6, 0)
  desk.casePageT = u.fs(desk.pick, "body", 11); desk.casePageT:SetPoint("LEFT", desk.caseNext, "RIGHT", 8, 0); desk.casePageT:SetTextColor(0.7, 0.66, 0.56)

  -- a graded card's page
  desk.page = CreateFrame("Frame", nil, desk); desk.page:SetAllPoints(desk)
  desk.big = makeCase(desk.page, 220); desk.big:SetPoint("TOPLEFT", desk, "TOPLEFT", X0 + 6, -196)
  desk.info = box(X0 + 290, -196, 432, 478, "THE GRADERS' NOTES")
  desk.info:SetParent(desk.page)
  desk.subs = {}
  for i = 1, 4 do
    local r = CreateFrame("Frame", nil, desk.info); r:SetSize(400, 22); r:SetPoint("TOPLEFT", 16, -38 - (i - 1) * 28)
    r.l = u.fs(r, "body", 13); r.l:SetPoint("LEFT", 0, 0); r.l:SetWidth(100); r.l:SetJustifyH("LEFT")
    r.bg = r:CreateTexture(nil, "ARTWORK"); r.bg:SetColorTexture(0.18, 0.16, 0.13, 1); r.bg:SetPoint("LEFT", 108, 0); r.bg:SetSize(240, 8)
    r.bar = r:CreateTexture(nil, "OVERLAY"); r.bar:SetColorTexture(0.85, 0.66, 0.26, 1); r.bar:SetPoint("LEFT", 108, 0); r.bar:SetSize(1, 8)
    r.v = u.fs(r, "head", 13); r.v:SetPoint("RIGHT", 0, 0); r.v:SetJustifyH("RIGHT")
    desk.subs[i] = r
  end
  desk.gname = u.fs(desk.info, "title", 24); desk.gname:SetPoint("TOPLEFT", 16, -158); desk.gname:SetTextColor(1, 0.83, 0.42)
  desk.ginfo = u.fs(desk.info, "body", 11.5); desk.ginfo:SetPoint("TOPLEFT", 16, -190); desk.ginfo:SetWidth(400); desk.ginfo:SetJustifyH("LEFT"); desk.ginfo:SetSpacing(3)
  desk.ginfo:SetTextColor(0.85, 0.8, 0.68)
  desk.pin = u.gbtn(desk.info, "Showcase", 96, 28, function()
    if desk.rec and RG.ArcadeGradePin(desk.rec.id) then say("Your " .. (cardOf(desk.rec.key) or {}).name .. " case is on your showcase.") end
  end); desk.pin:SetPoint("BOTTOMLEFT", 16, 16)
  desk.sell = u.gbtn(desk.info, "Sell", 96, 28, function()
    local r = desk.rec; if not r then return end
    local v = RG.ArcadeGradeValue(r)
    local function go() local ok, msg = RG.ArcadeGradeSell(r.id); say(msg); local vv = RG.ArcadeView; if ok and vv then vv.gradeCert = nil end; RG.ArcadeRefresh(true) end
    if r.grade >= 9 then desk.confirm:Ask("Sell your " .. r.grade .. " (" .. RG.ArcadeGradeName(r.grade) .. ") for " .. v .. " coins?\nIt leaves your collection for good.", "Sell it", go) else go() end
  end); desk.sell:SetPoint("LEFT", desk.pin, "RIGHT", 6, 0)
  desk.crack = u.gbtn(desk.info, "Crack case", 96, 28, function()
    local r = desk.rec; if not r then return end
    local function go() local ok, msg = RG.ArcadeGradeCrack(r.id); say(msg); local vv = RG.ArcadeView; if ok and vv then vv.gradeCert = nil; sel.key, sel.f, sel.copy = r.key, r.f, 1 end; RG.ArcadeRefresh(true) end
    if r.grade >= 9 then desk.confirm:Ask("Crack the case of your " .. r.grade .. " (" .. RG.ArcadeGradeName(r.grade) .. ")?\nThe grade is lost for good, and the card is graded fresh next time.", "Crack it", go) else go() end
  end); desk.crack:SetPoint("LEFT", desk.sell, "RIGHT", 6, 0)
  -- trading it: offer it to your group, or answer a graded offer with it (ArcadeGradingGuild.lua)
  desk.offer = u.gbtn(desk.info, "Offer", 96, 28, function()
    local r = desk.rec; if not r then return end
    local t = RG.ArcadeTrade
    local ok, msg
    if t and t.incoming and t.incoming.case and RG.ArcadeGradeAnswer then ok, msg = RG.ArcadeGradeAnswer(nil, nil, r.id)
    elseif RG.ArcadeOfferCase then ok, msg = RG.ArcadeOfferCase(r.id) end
    say(msg); RG.ArcadeRefresh(true)
  end); desk.offer:SetPoint("LEFT", desk.crack, "RIGHT", 6, 0)
  -- the guild's graded copies of this card
  desk.popH = u.fs(desk.info, "title", 12); desk.popH:SetPoint("TOPLEFT", 16, -302); desk.popH:SetTextColor(1, 0.83, 0.42)
  desk.pop = {}
  local PL = { { 10, 10, "10" }, { 9, 9, "9" }, { 8, 8, "8" }, { 7, 7, "7" }, { 6, 6, "6" }, { 1, 5, "1-5" } }
  for i, e in ipairs(PL) do
    local r = CreateFrame("Frame", nil, desk.info); r:SetSize(400, 15); r:SetPoint("TOPLEFT", 16, -320 - (i - 1) * 17)
    r.lo, r.hi = e[1], e[2]
    r.l = u.fs(r, "head", 11); r.l:SetPoint("LEFT"); r.l:SetWidth(34); r.l:SetJustifyH("LEFT"); r.l:SetText(e[3])
    r.bg = r:CreateTexture(nil, "ARTWORK"); r.bg:SetColorTexture(0.18, 0.16, 0.13, 1); r.bg:SetPoint("LEFT", 40, 0); r.bg:SetSize(300, 9)
    r.bar = r:CreateTexture(nil, "OVERLAY"); r.bar:SetColorTexture(0.79, 0.64, 0.29, 1); r.bar:SetPoint("LEFT", 40, 0); r.bar:SetSize(1, 9)
    r.n = u.fs(r, "head", 11); r.n:SetPoint("RIGHT"); r.n:SetJustifyH("RIGHT")
    desk.pop[i] = r
  end
  desk.confirm = confirmBox(desk)

  -- the Guild Ledger: sets (left), the guild's best scores for the one picked (right)
  desk.ledgerBtn = u.gbtn(desk, "Guild Ledger", 120, 24, function()
    local v = RG.ArcadeView; if not v then return end
    v.gradeLedger = not v.gradeLedger; v.gradeCert = nil; RG.ArcadeRefresh(true)
  end)
  desk.ledgerBtn:SetPoint("LEFT", desk.head, "RIGHT", 18, 0)
  desk.ledger = CreateFrame("Frame", nil, desk); desk.ledger:SetAllPoints(desk)
  local lb = box(X0, -196, 300, 478, "SETS")
  lb:SetParent(desk.ledger); desk.lsets = lb
  lb.rows = {}
  for i = 1, 13 do
    local b = CreateFrame("Button", nil, lb); b:SetSize(272, 28); b:SetPoint("TOPLEFT", 14, -34 - (i - 1) * 31)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b); b.bg:SetColorTexture(1, 0.85, 0.5, 0.06)
    b.name = u.fs(b, "body", 12); b.name:SetPoint("TOPLEFT", 6, -3); b.name:SetWidth(200); b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.sub = u.fs(b, "body", 10.5); b.sub:SetPoint("BOTTOMLEFT", 6, 2); b.sub:SetTextColor(0.62, 0.58, 0.5)
    b.score = u.fs(b, "head", 12); b.score:SetPoint("RIGHT", -6, 0); b.score:SetJustifyH("RIGHT")
    b:SetScript("OnClick", function(self) local v = RG.ArcadeView; if v and self.set then v.ledgerSet = self.set; RG.ArcadeRefresh(true) end end)
    lb.rows[i] = b
  end
  lb.page = 1
  lb.prev = u.gbtn(lb, "<", 30, 22, function() lb.page = math.max(1, lb.page - 1); RG.ArcadeRefresh(true) end); lb.prev:SetPoint("BOTTOMLEFT", 14, 12)
  lb.next = u.gbtn(lb, ">", 30, 22, function() lb.page = lb.page + 1; RG.ArcadeRefresh(true) end); lb.next:SetPoint("LEFT", lb.prev, "RIGHT", 6, 0)
  lb.pageT = u.fs(lb, "body", 11); lb.pageT:SetPoint("LEFT", lb.next, "RIGHT", 8, 0); lb.pageT:SetTextColor(0.7, 0.66, 0.56)
  local bb = box(X0 + 312, -196, 410, 478, "THE LEADERBOARD")
  bb:SetParent(desk.ledger); desk.lboard = bb
  bb.note = u.fs(bb, "body", 12); bb.note:SetPoint("TOPLEFT", 14, -34); bb.note:SetWidth(380); bb.note:SetJustifyH("LEFT"); bb.note:SetTextColor(0.8, 0.75, 0.64); bb.note:SetSpacing(2)
  bb.rows = {}
  for i = 1, 10 do
    local r = CreateFrame("Frame", nil, bb); r:SetSize(380, 26); r:SetPoint("TOPLEFT", 14, -96 - (i - 1) * 30)
    r.rank = u.fs(r, "title", 13); r.rank:SetPoint("LEFT", 0, 0); r.rank:SetWidth(28); r.rank:SetJustifyH("LEFT")
    r.name = u.fs(r, "body", 13); r.name:SetPoint("LEFT", 30, 0); r.name:SetWidth(170); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.bg = r:CreateTexture(nil, "ARTWORK"); r.bg:SetColorTexture(0.18, 0.16, 0.13, 1); r.bg:SetPoint("LEFT", 204, 0); r.bg:SetSize(110, 8)
    r.bar = r:CreateTexture(nil, "OVERLAY"); r.bar:SetColorTexture(0.85, 0.66, 0.26, 1); r.bar:SetPoint("LEFT", 204, 0); r.bar:SetSize(1, 8)
    r.score = u.fs(r, "head", 12); r.score:SetPoint("RIGHT", 0, 0); r.score:SetJustifyH("RIGHT")
    bb.rows[i] = r
  end
end

local function paintLedger(view)
  local sets, sizeOf = RG.ArcadeGradeLedger()
  local myName = (UnitName and select(2, pcall(UnitName, "player"))) or "?"
  local list = {}
  for name, holders in pairs(sets) do
    local mine = holders[myName]
    local top = 0; for _, e in pairs(holders) do top = math.max(top, e.score) end
    list[#list + 1] = { name = name, mine = mine and mine.score or 0, top = top, max = 10 * math.max(1, sizeOf(name)), n = sizeOf(name) }
  end
  table.sort(list, function(x, y) if x.mine ~= y.mine then return x.mine > y.mine end; if x.top ~= y.top then return x.top > y.top end; return x.name < y.name end)
  local lb, bb = desk.lsets, desk.lboard
  local per = #lb.rows
  local pages = math.max(1, math.ceil(#list / per)); lb.page = math.min(lb.page, pages)
  if not (view.ledgerSet and sets[view.ledgerSet]) then view.ledgerSet = list[1] and list[1].name end
  for i, b in ipairs(lb.rows) do
    local e = list[(lb.page - 1) * per + i]
    if e then
      b.set = e.name; b.name:SetText(e.name); b.sub:SetText(e.n .. " cards")
      b.score:SetText((e.mine > 0 and ("|cffffd36b" .. e.mine .. "|r") or "|cff7d776a0|r") .. " / " .. e.max)
      b.bg:SetColorTexture(1, 0.85, 0.5, e.name == view.ledgerSet and 0.18 or 0.06)
      b:Show()
    else b:Hide() end
  end
  lb.prev:SetShown(pages > 1); lb.next:SetShown(pages > 1); lb.pageT:SetText(pages > 1 and (lb.page .. " / " .. pages) or "")
  lb.prev:SetEnabled(lb.page > 1); lb.next:SetEnabled(lb.page < pages)
  for _, r in ipairs(bb.rows) do r:Hide() end
  local guild = IsInGuild and IsInGuild()
  if not view.ledgerSet then
    bb.h:SetText("THE LEADERBOARD")
    bb.note:SetText("Nobody " .. (guild and "in your guild " or "") .. "has a graded card yet. Every graded card adds its grade to its set's score: the best graded copy of each card counts, 10 at most." ..
      (guild and "" or "\n\nJoin a guild to see your guildmates' scores here."))
    return
  end
  local holders = sets[view.ledgerSet] or {}
  local rows = {}
  for name, e in pairs(holders) do rows[#rows + 1] = { name = name, score = e.score, graded = e.graded } end
  table.sort(rows, function(x, y) if x.score ~= y.score then return x.score > y.score end return x.name < y.name end)
  local max = 10 * math.max(1, sizeOf(view.ledgerSet))
  bb.h:SetText(view.ledgerSet:upper())
  bb.note:SetText("Each card's best graded copy adds its grade (10 at most): a full set of Gem Mints scores " .. max .. "." ..
    (guild and "\nYour guildmates with Waypath+ share their cases when they log in." or "\nJoin a guild to see your guildmates here."))
  for i, r in ipairs(bb.rows) do
    local e = rows[i]
    if e then
      local isMe = e.name == myName
      r.rank:SetText(i); r.rank:SetTextColor(i == 1 and 1 or 0.85, i == 1 and 0.83 or 0.8, i == 1 and 0.42 or 0.7)
      r.name:SetText((isMe and "|cffffd36b" or "") .. e.name .. (isMe and "|r" or "") .. "  |cff8f8a7c" .. e.graded .. " graded|r")
      r.bar:SetWidth(math.max(1, 110 * e.score / max)); r.score:SetText(e.score .. " / " .. max)
      r:Show()
    end
  end
end

local function paintSlots(a, st)
  local t = (time and time()) or 0
  local rows = {}
  for i, q in ipairs(st.back) do rows[#rows + 1] = { q = q, back = i } end
  for _, q in ipairs(st.queue) do rows[#rows + 1] = { q = q } end
  local SV = GR().SERVICE
  for i, r in ipairs(desk.slots) do
    local e = rows[i]
    if e then
      local c = cardOf(e.q.key)
      r.name:SetText((c and c.name or "?") .. "  |cffa89bc9" .. (U().FINISH[e.q.f] and U().FINISH[e.q.f][1] or "") .. "|r")
      if e.back then
        r.t:SetText(""); r.open:Show(); r.open.backIndex = e.back; r.backIndex = e.back
        r.bar:SetWidth(234); r.bar:SetColorTexture(0.48, 0.88, 0.54, 1)
      else
        r.open:Hide()
        local total = math.max(1, (e.q.due or t) - (e.q.sent or t))
        local p = math.max(0, math.min(1, (t - (e.q.sent or t)) / total))
        r.t:SetText("back in " .. timeLeft((e.q.due or t) - t)); r.bar:SetWidth(math.max(1, 234 * p)); r.bar:SetColorTexture(0.42, 0.65, 1, 1)
      end
      -- (the name and print in the room the time or the Open button leaves: a little smaller if it needs, then cut short)
      local tw = r.open:IsShown() and 70 or (r.t:GetStringWidth() or 0)
      local room = 234 - tw - 10
      r.name:SetWidth(room)
      if RG.ArcadeFitLine then RG.ArcadeFitLine(r.name, room, 12, 8.5) end
      -- (still too long: the name alone; the print shows on the case page)
      local need = r.name.GetUnboundedStringWidth and r.name:GetUnboundedStringWidth() or 0
      if need > room + 0.5 then r.name:SetText(c and c.name or "?"); if RG.ArcadeFitLine then RG.ArcadeFitLine(r.name, room, 12, 8) end end
      r:Show()
    elseif i <= GR().SLOTS then
      r.name:SetText("|cff7d776aAn open slot|r"); r.t:SetText(""); r.open:Hide(); r.bar:SetWidth(1); r.name:SetWidth(224)
      if RG.ArcadeFitLine then RG.ArcadeFitLine(r.name, 224, 12, 10) end
      r:Show()
    else r:Hide() end
  end
  desk.slotBox.h:SetText("AT THE GRADERS  ·  " .. #st.queue .. " OF " .. GR().SLOTS .. " SLOTS")
end

local function paintDesk(view, a)
  local u = U()
  local st = RG.ArcadeGradeState()
  desk.head:SetText(view.gradeLedger and "THE GUILD LEDGER" or (view.gradeCert and "A GRADED CARD" or "THE GRADING DESK"))
  desk.ledgerBtn:SetText(view.gradeLedger and "Grading desk" or "Guild Ledger")
  if view.gradeLedger then
    desk.ledger:Show(); desk.page:Hide()
    for _, w in ipairs({ desk.pick, desk.case, desk.caseNote, desk.svcBox, desk.slotBox }) do w:Hide() end
    paintLedger(view)
    return
  end
  desk.ledger:Hide()
  desk.right:SetText("|cffffe08a" .. (a.coins or 0) .. "|r coins")
  -- a case's page
  if view.gradeCert then
    local r = RG.ArcadeGradeFind(view.gradeCert)
    if not r then view.gradeCert = nil else
      desk.page:Show()
      for _, w in ipairs({ desk.pick, desk.case, desk.caseNote, desk.svcBox, desk.slotBox }) do w:Hide() end
      desk.rec = r
      desk.big:SetRec(r)
      local s = decode(r.s) or { 0, 0, 0, 0 }
      for i, row in ipairs(desk.subs) do
        row.l:SetText(GR().SUBS[i]); row.bar:SetWidth(math.max(1, 240 * s[i] / 10))
        row.v:SetText((s[i] == math.floor(s[i])) and tostring(s[i]) or string.format("%.1f", s[i]))
      end
      local kind = RG.ArcadeGradeSeal(r.grade)
      local ink = SEAL_INK[kind]
      desk.gname:SetText(RG.ArcadeGradeName(r.grade):upper() .. " " .. r.grade); desk.gname:SetTextColor(ink[1], ink[2], ink[3])
      local miss = RG.ArcadeGradeNearMiss(s)
      local v, base = RG.ArcadeGradeValue(r)
      local mine = RG.ArcadeGradeCases(r.key)
      local same = 0; for _, x in ipairs(mine) do if x.grade == r.grade then same = same + 1 end end
      local lines = {}
      if miss then lines[#lines + 1] = "|cffd9b48a" .. miss .. "|r" end
      lines[#lines + 1] = "Certificate |cffffffff" .. string.format("%07d", r.cert) .. "|r  ·  graded " .. (r.when or "") .. (r.by and (" by " .. r.by) or "")
      -- its history: everyone it was traded to
      local went = {}
      for i, h in ipairs(r.hist or {}) do if i > 1 and h[1] == "traded" then went[#went + 1] = h[2] .. " (" .. (h[3] or "") .. ")" end end
      while #went > 3 do table.remove(went, 1) end   -- (the last three: room for the guild's count below)
      if #went > 0 then lines[#lines + 1] = "Traded to " .. table.concat(went, ", ") .. "." end
      lines[#lines + 1] = "Sells for " .. GOLD .. v .. "|r coins (ungraded " .. base .. ")  ·  you have " .. #mine .. " graded"
      local okSig = RG.ArcadeGradeValid and RG.ArcadeGradeValid(r)
      if not okSig then lines[#lines + 1] = "|cffff8a70This case didn't pass its certificate check: it stays yours, but isn't shared with your guild or tradable.|r" end
      desk.ginfo:SetText(table.concat(lines, "\n"))
      -- the guild's population of this card
      local pop, total = {}, 0
      if RG.ArcadeGradePop then pop, total = RG.ArcadeGradePop(r.key) end
      local most = 1
      for _, row in ipairs(desk.pop) do local n = 0; for g = row.lo, row.hi do n = n + (pop[g] or 0) end; row.cnt = n; most = math.max(most, n) end
      for _, row in ipairs(desk.pop) do
        local mineRow = r.grade >= row.lo and r.grade <= row.hi
        row.bar:SetWidth(math.max(1, 300 * row.cnt / most)); row.n:SetText(row.cnt)
        row.bar:SetColorTexture(mineRow and 1 or 0.6, mineRow and 0.85 or 0.48, mineRow and 0.45 or 0.22, 1)
        row.l:SetTextColor(mineRow and 1 or 0.75, mineRow and 0.85 or 0.7, mineRow and 0.45 or 0.6)
      end
      local guild = IsInGuild and IsInGuild()
      desk.popH:SetText((guild and "YOUR GUILD" or "YOUR CASES") .. "  ·  " .. total .. " GRADED" .. ((total > 0 and pop[r.grade] == 1 and total > 1) and "  ·  THE ONLY " .. r.grade or ""))
      local t = RG.ArcadeTrade
      local answering = t and t.incoming and t.incoming.case
      desk.offer:SetText(answering and "Answer" or "Offer")
      desk.offer:SetEnabled(okSig and RG.ArcadeTradable and RG.ArcadeTradable(r.key) and IsInGroup and IsInGroup() and true or false)
      desk.sell:SetEnabled(okSig and true or false)
      return
    end
  end
  desk.page:Hide()
  for _, w in ipairs({ desk.pick, desk.svcBox, desk.slotBox }) do w:Show() end
  local batch = RG.ArcadeGradeBatchList()
  if view.gradeBatch then
    -- the batch: every copy picked from the collection, sent together
    for _, b in ipairs(desk.copies) do b:Hide() end
    for _, b in ipairs(desk.cases) do b:Hide() end
    desk.casePrev:Hide(); desk.caseNext:Hide(); desk.casePageT:SetText("")
    desk.case:Hide(); desk.caseNote:Hide(); desk.bAdd:Hide()
    local cap = RG.ArcadeGradeBatchCap()
    desk.pick.h:SetText("YOUR BATCH")
    desk.pick.hint:SetText(#batch > 0 and (#batch .. " of " .. cap .. " free slot" .. (cap == 1 and "" or "s") .. ". Click a card to take it out.") or
      (cap == 0 and "All the grading slots are busy: a batch can go when one comes back." or "Nothing here yet. Open a card in your collection and press |cffffd36bAdd to batch|r, up to " .. cap .. " card" .. (cap == 1 and "" or "s") .. "."))
    for i, b in ipairs(desk.copies) do
      local e = batch[i]
      if e then
        local cc = cardOf(e.key)
        b:SetText((cc and cc.name or "?") .. "  |cffa89bc9" .. (u.FINISH[e.f] and u.FINISH[e.f][1] or "") .. "|r   |cffff9a8ax|r"); b:SetActive(false)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 14, -76 - (i - 1) * 30); b:Show()
      end
    end
    desk.bView:SetText("One card"); desk.bView:Show()
    local first, weekly = RG.ArcadeGradeFreeLeft()
    for key, b in pairs(desk.svc) do
      local sv = GR().SERVICE[key]
      b:SetText(sv.name); b.sub:SetText(key == "express" and "Back in 1 hour" or "Back in 12 hours")
      local isFree = key == "standard" and (first > 0 or weekly)
      b.price:SetText(isFree and "|cff7be08aFREE|r" or (GOLD .. sv.price .. " coins|r"))
      b:SetActive(sel.svc == key)
    end
    local cost, free = RG.ArcadeGradeBatchCost(sel.svc)
    desk.freeLine:SetText(#batch == 0 and "Add cards from their collection page, then send them all at once." or
      ((free > 0 and (free .. " free  ·  ") or "") .. "Total " .. cost .. " coins" .. ((a.coins or 0) < cost and "  |cffff9a8a(you have " .. (a.coins or 0) .. ")|r" or "")))
    desk.send:SetEnabled(#batch > 0 and (a.coins or 0) >= cost and cap > 0)
    desk.send:SetText(#batch > 0 and ("Send " .. #batch .. " to the graders") or "Nothing in the batch")
    paintSlots(a, st)
    return
  end
  desk.bView:SetText(#batch > 0 and ("Batch " .. #batch) or "Batch"); desk.bView:Show()
  -- the card to send
  local c = sel.key and cardOf(sel.key)
  local free = c and RG.ArcadeGradeFree(a, sel.key, sel.f) or 0
  if c and free == 0 then c = nil end
  for _, b in ipairs(desk.copies) do b:Hide() end
  for _, b in ipairs(desk.cases) do b:Hide() end
  desk.casePrev:Hide(); desk.caseNext:Hide(); desk.casePageT:SetText("")
  if c then
    desk.pick.h:SetText("YOUR COPIES"); desk.pick.hint:SetText("")
    sel.copy = math.max(1, math.min(sel.copy or 1, free))
    for i, b in ipairs(desk.copies) do
      if i <= math.min(free, #desk.copies) then
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 14, -36 - (i - 1) * 30)
        b:SetText("Copy " .. i .. "   |cffa89bc9" .. (u.FINISH[sel.f] and u.FINISH[sel.f][1] or "") .. "  ·  not graded|r"); b:SetActive(i == sel.copy); b:Show()
      end
    end
    desk.bAdd:Show()
    local room = RG.ArcadeGradeBatchCap() - #batch
    desk.bAdd:SetText(room > 0 and "Add this copy to the batch" or "No free slot for the batch"); desk.bAdd:SetEnabled(room > 0)
    desk.case:SetPending(c, sel.f); desk.case:Show()
    desk.caseNote:SetText("Centering ?  ·  Corners ?  ·  Edges ?  ·  Surface ?"); desk.caseNote:Show()
    if RG.ArcadeFitLine then RG.ArcadeFitLine(desk.caseNote, 214, 11.5, 8, "body") end
  else
    sel.key = nil
    desk.bAdd:Hide()
    desk.pick.h:SetText("YOUR CASES")
    desk.case:Hide(); desk.caseNote:Hide()
    local cases = RG.ArcadeGradeCases()
    desk.pick.hint:SetText(#cases == 0 and "Open any card in your collection and press |cffffd36bGrade a copy|r to send one here.\n\nYour graded cards will be listed here." or
      "Open any card in your collection and press |cffffd36bGrade a copy|r to send one here.")
    local per = #desk.cases
    local pages = math.max(1, math.ceil(#cases / per)); desk.casePage = math.min(desk.casePage, pages)
    for i, b in ipairs(desk.cases) do
      local r = cases[(desk.casePage - 1) * per + i]
      if r then
        local cc = cardOf(r.key)
        sealTex(b.seal, RG.ArcadeGradeSeal(r.grade)); b.g:SetText(r.grade)
        b.name:SetText((cc and cc.name or "?") .. "  |cffa89bc9" .. (u.FINISH[r.f] and u.FINISH[r.f][1] or "") .. "|r"); b.cert = r.id; b:Show()
      end
    end
    if pages > 1 then desk.casePrev:Show(); desk.caseNext:Show(); desk.casePrev:SetEnabled(desk.casePage > 1); desk.caseNext:SetEnabled(desk.casePage < pages); desk.casePageT:SetText(desk.casePage .. " / " .. pages) end
  end
  -- how fast, and what's free
  local first, weekly = RG.ArcadeGradeFreeLeft()
  for key, b in pairs(desk.svc) do
    local sv = GR().SERVICE[key]
    b:SetText(sv.name); b.sub:SetText(key == "express" and "Back in 1 hour" or "Back in 12 hours")
    local isFree = key == "standard" and (first > 0 or weekly)
    b.price:SetText(isFree and "|cff7be08aFREE|r" or (GOLD .. sv.price .. " coins|r"))
    b:SetActive(sel.svc == key)
  end
  desk.freeLine:SetText(first > 0 and ("Your first " .. GR().FIRST_FREE .. " Standard gradings are free  ·  " .. first .. " left") or
    (weekly and "This week's free Standard grading is waiting." or "One free Standard grading every week (next on Tuesday)."))
  local busy = #st.queue >= GR().SLOTS
  desk.send:SetEnabled(c ~= nil and not busy)
  desk.send:SetText(busy and "All slots are busy" or "Send to the graders")
  paintSlots(a, st)
end

RG.ArcadeViewHooks = RG.ArcadeViewHooks or {}
table.insert(RG.ArcadeViewHooks, function(view, ctx)
  RG.ArcadeView = view
  local frame = ctx.frame
  if not desk then buildDesk(frame) end
  -- the Shop's storefront: a way in
  local shop = RG.ArcadeShopFrame
  if shop and not rawget(desk, "door") then
    -- the guild's banner across the top of the storefront: what the guild is, what's waiting, and the way in
    local open = function() view.shopSection = "grading"; view.gradeCert = nil; view.gradeLedger = nil; RG.ArcadeRefresh(true) end
    local B = CreateFrame("Frame", nil, shop, "BackdropTemplate")
    B:SetSize(722, 40); B:SetPoint("TOPLEFT", shop, "TOPLEFT", 34, -192)
    B:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    B:SetBackdropColor(0.2, 0.12, 0.06, 0.97); B:SetBackdropBorderColor(0.54, 0.4, 0.19, 0.95)
    B.seal = B:CreateTexture(nil, "ARTWORK"); B.seal:SetTexture(MEDIA .. "GradeWax"); B.seal:SetTexCoord(0, 0.5, 0, 0.5); B.seal:SetSize(30, 30); B.seal:SetPoint("LEFT", 10, 0)
    B.title = U().fs(B, "head", 13); B.title:SetPoint("TOPLEFT", 50, -6); B.title:SetTextColor(0.95, 0.88, 0.7); B.title:SetText("Waypoint Grading Guild")
    B.sub = U().fs(B, "body", 11.5); B.sub:SetPoint("BOTTOMLEFT", 50, 6); B.sub:SetTextColor(0.8, 0.72, 0.55); B.sub:SetJustifyH("LEFT")
    B.btn = U().gbtn(B, "Open desk", 118, 26, open); B.btn:SetPoint("RIGHT", -10, 0); B.btn:SetActive(true)
    desk.door = B
    RG.ArcadeGradeBanner = B   -- (the Guild Reserve's button joins it: ArcadeReserveUI.lua)
  end
  local st = RG.ArcadeGradeState()
  if rawget(desk, "door") then
    local nb, nq = #st.back, #st.queue
    local sub
    if nb > 0 then sub = "|cff7be08a" .. nb .. " parcel" .. (nb == 1 and " is" or "s are") .. " back|r from the guild: open the desk to see the grades."
    elseif nq > 0 then sub = nq .. " parcel" .. (nq == 1 and " is" or "s are") .. " at the guild, back soon."
    else sub = "Send your best cards to be graded: a graded card sells for more." end
    desk.door.sub:SetText(sub)
    if RG.ArcadeFitLine then RG.ArcadeFitLine(desk.door.sub, 410, 11.5, 9, "body") end   -- (room for the two buttons at the right)
    desk.door:SetShown(view.mode == "shop" and view.shopSection == nil)
  end
  local on = view.mode == "shop" and view.shopSection == "grading"
  desk:SetShown(on)
  if not on then return end
  if shop then shop:Hide() end
  frame.prev:Hide(); frame.next:Hide(); frame.pageText:Hide()
  paintDesk(view, ctx.a)
end)

-- open the desk for a card ("Grade a copy" on its page)
function RG.ArcadeGradeDesk(key, f, cert)
  if RG.ShowArcade then RG.ShowArcade() end
  local v = RG.ArcadeView
  if not v then if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end; v = RG.ArcadeView end
  if not v then return end
  v.mode = "shop"; v.shopSection = "grading"; v.gradeCert = cert; v.gradeLedger = nil; v.gradeBatch = false
  if key then
    sel.key, sel.f, sel.copy = key, f, 1
    -- "Grade a copy" puts that copy in the batch and shows the batch, so going back to the collection for another card adds to it
    -- (the one-card view is still a click away: Back)
    local ok, msg = RG.ArcadeGradeBatchAdd(key, f)
    if ok then v.gradeBatch = true elseif msg then say(msg) end
  end
  RG.ArcadeRefresh(true)
end

-- the card's page: two buttons under the card
function RG.ArcadeGradeDetailBuild(detail)
  local u = U()
  detail.gradeBtn = u.gbtn(detail, "Grade a copy", 113, 26, function()
    local c = detail.data; if not c then return end
    detail:Hide(); RG.ArcadeGradeDesk(c.key or c.name, detail.finish)
  end)
  detail.gradeBtn:SetPoint("TOPLEFT", detail, "TOPLEFT", 30, -372)
  detail.gradeCases = u.gbtn(detail, "Cases", 113, 26, function()
    local c = detail.data; if not c then return end
    local r = RG.ArcadeGradeShown(c.key or c.name)
    detail:Hide(); RG.ArcadeGradeDesk(nil, nil, r and r.id)
  end)
  detail.gradeCases:SetPoint("LEFT", detail.gradeBtn, "RIGHT", 4, 0)
  -- sell the graded copy shown here, at today's Vault price (the same price as the Vault and the desk)
  detail.gradeSell = u.gbtn(detail, "Sell graded", 230, 26, function()
    local r = detail.gradeRec; if not r then return end
    local v = RG.ArcadeGradeValue(r)
    local function go() local ok, msg = RG.ArcadeGradeSell(r.id); say(msg); if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end end
    if r.grade >= 9 then
      detail.confirm = detail.confirm or confirmBox(detail)
      detail.confirm:Ask("Sell your " .. r.grade .. " (" .. RG.ArcadeGradeName(r.grade) .. ") for " .. v .. " coins?\nIt leaves your collection for good.", "Sell it", go)
    else go() end
  end)
  detail.gradeSell:SetPoint("TOPLEFT", detail, "TOPLEFT", 30, -402)
  -- add a copy of the print shown to the batch the desk sends together
  detail.gradeBatch = u.gbtn(detail, "Add to batch", 230, 26, function()
    local c = detail.data; if not c then return end
    local ok, msg = RG.ArcadeGradeBatchAdd(c.key or c.name, detail.finish); say(msg)
    if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
  end)
  detail.gradeBatch:SetPoint("TOPLEFT", detail, "TOPLEFT", 30, -432)
end
function RG.ArcadeGradeDetailRefresh(detail, c, f)
  if not detail.gradeBtn then return end
  local a = store(); if not a then return end
  local key = c.key or c.name
  local free = RG.ArcadeGradeFree(a, key, f)
  detail.gradeBtn:SetEnabled(free > 0)
  detail.gradeBtn:SetText(free > 0 and "Grade a copy" or "None to grade")
  -- a graded copy of this print is shown in its case (the slab), not as a bare card
  local r = RG.ArcadeGradeShown(key)
  if r and r.f == f then
    if not rawget(detail, "slab") then
      detail.slab = makeCase(detail, 176); detail.slab:SetPoint("TOPLEFT", detail, "TOPLEFT", 30, -36)
      detail.slab:SetFrameLevel((detail:GetFrameLevel() or 1) + 3)
    end
    detail.slab:SetRec(r)
    detail.card:Hide()
  else
    if rawget(detail, "slab") then detail.slab:Hide() end
    detail.card:Show()
  end
  local n = #RG.ArcadeGradeCases(key)
  detail.gradeCases:SetEnabled(n > 0)
  detail.gradeCases:SetText(n > 0 and ("Cases  ·  " .. n) or "No cases")
  if detail.gradeBatch then
    local nb = #RG.ArcadeGradeBatchList()
    detail.gradeBatch:SetText("Add to batch" .. (nb > 0 and ("  ·  " .. nb .. " in it") or ""))
    detail.gradeBatch:SetEnabled(free > 0 and RG.ArcadeGradeBatchCap() > nb)
  end
  if detail.gradeSell then
    -- the case shown for this print (the one you pinned, else the best), sold at its Vault price
    local sr = r and r.f == f and r or RG.ArcadeGradeCases(key, f)[1]
    detail.gradeRec = sr
    if sr then
      detail.gradeSell:SetText("Sell graded " .. sr.grade .. "  ·  " .. RG.ArcadeGradeValue(sr) .. " coins")
      detail.gradeSell:SetEnabled(RG.ArcadeGradeValid and RG.ArcadeGradeValid(sr) and true or false)
    else
      detail.gradeSell:SetText("No graded copy to sell"); detail.gradeSell:SetEnabled(false)
    end
  end
end

-- ---------------------------------------------------------------------------
-- The reveal
-- ---------------------------------------------------------------------------
local rv
local PW, PH = 300, 389                  -- the parcel on screen (its texture: 395 x 512 of 512)
local PS = PW / 395
local SEAL_X, SEAL_Y, SEAL_S = 197.5, 252.3, 115   -- the seal's centre and box in the parcel texture's pixels

local function buildReveal()
  local u = U()
  rv = CreateFrame("Frame", "WaypathGradeReveal", UIParent, "BackdropTemplate")
  rv:SetFrameStrata("FULLSCREEN_DIALOG"); rv:SetPoint("CENTER", 0, 20)
  u.darkPanel(rv, 820, 600)
  rv:EnableMouse(true); rv:SetMovable(true); rv:RegisterForDrag("LeftButton")
  rv:SetScript("OnDragStart", rv.StartMoving); rv:SetScript("OnDragStop", rv.StopMovingOrSizing)
  tinsert(UISpecialFrames, "WaypathGradeReveal")
  rv.title = u.fs(rv, "title", 20); rv.title:SetPoint("TOP", 0, -26); rv.title:SetTextColor(1, 0.83, 0.42)
  rv.sub = u.fs(rv, "body", 13); rv.sub:SetPoint("TOP", rv.title, "BOTTOM", 0, -6); rv.sub:SetTextColor(0.85, 0.8, 0.68)
  local base = lvOf(rv)
  -- rays behind the case (a 10)
  rv.rays = rv:CreateTexture(nil, "BACKGROUND", nil, 3); rv.rays:SetTexture(MEDIA .. "Rays"); rv.rays:SetBlendMode("ADD"); rv.rays:SetSize(560, 560)
  rv.rays:SetPoint("CENTER", rv, "CENTER", -150, -30); rv.rays:SetVertexColor(1, 0.85, 0.45, 0); rv.rays:Hide()
  -- the parcel
  rv.parcel = CreateFrame("Button", nil, rv); rv.parcel:SetSize(PW, PH); rv.parcel:SetPoint("CENTER", rv, "CENTER", 0, -20); rv.parcel:SetFrameLevel(base + 4)
  rv.paper = rv.parcel:CreateTexture(nil, "ARTWORK"); rv.paper:SetTexture(MEDIA .. "GradeParcel"); rv.paper:SetTexCoord(0, 395 / 512, 0, 1); rv.paper:SetAllPoints(rv.parcel)
  rv.who = u.fs(rv.parcel, "title", 15 * 0.8977 * PS, "OVERLAY"); rv.who:SetPoint("BOTTOMLEFT", rv.parcel, "TOPLEFT", 57 * PS, -122 * PS); rv.who:SetTextColor(0.17, 0.1, 0.05)
  rv.who:SetShadowColor(0, 0, 0, 0)
  rv.svcT = u.fs(rv.parcel, "head", 9 * 0.8977 * PS, "OVERLAY"); rv.svcT:SetPoint("BOTTOMLEFT", rv.parcel, "TOPLEFT", 57 * PS, -175 * PS); rv.svcT:SetTextColor(0.17, 0.1, 0.05)
  rv.svcT:SetShadowColor(0, 0, 0, 0)
  rv.stamp = rv.parcel:CreateTexture(nil, "OVERLAY"); rv.stamp:SetTexture(MEDIA .. "GradeStamp"); rv.stamp:SetSize(104 * 0.8977 * PS, 34 * 0.8977 * PS)
  rv.stamp:SetPoint("CENTER", rv.parcel, "TOPLEFT", 104 * PS, -320.5 * PS); rv.stamp:SetAlpha(0.85)
  if rv.stamp.SetRotation then pcall(rv.stamp.SetRotation, rv.stamp, math.rad(6)) end
  rv.wax = CreateFrame("Button", nil, rv.parcel); rv.wax:SetSize(SEAL_S * PS, SEAL_S * PS); rv.wax:SetFrameLevel(base + 6)
  rv.wax:SetPoint("CENTER", rv.parcel, "TOPLEFT", SEAL_X * PS, -SEAL_Y * PS)
  rv.whole = rv.wax:CreateTexture(nil, "ARTWORK"); rv.whole:SetTexture(MEDIA .. "GradeWax"); rv.whole:SetTexCoord(0, 0.5, 0, 0.5); rv.whole:SetAllPoints(rv.wax)
  rv.halfL = rv.wax:CreateTexture(nil, "ARTWORK"); rv.halfL:SetTexture(MEDIA .. "GradeWax"); rv.halfL:SetTexCoord(0.5, 1, 0, 0.5); rv.halfL:SetSize(rv.wax:GetWidth(), rv.wax:GetHeight())
  rv.halfR = rv.wax:CreateTexture(nil, "ARTWORK"); rv.halfR:SetTexture(MEDIA .. "GradeWax"); rv.halfR:SetTexCoord(0, 0.5, 0.5, 1); rv.halfR:SetSize(rv.wax:GetWidth(), rv.wax:GetHeight())
  rv.spark = rv.wax:CreateTexture(nil, "OVERLAY"); rv.spark:SetTexture(MEDIA .. "Glow"); rv.spark:SetBlendMode("ADD"); rv.spark:SetSize(SEAL_S * PS * 2.4, SEAL_S * PS * 2.4); rv.spark:SetPoint("CENTER")
  rv.spark:SetVertexColor(1, 0.85, 0.5, 0)
  local function crack() if rv.stage == "parcel" then rv:Go("crack") end end
  rv.wax:SetScript("OnClick", crack); rv.parcel:SetScript("OnClick", crack)
  rv.hint = u.fs(rv, "body", 12.5); rv.hint:SetPoint("BOTTOM", 0, 34); rv.hint:SetTextColor(0.75, 0.7, 0.6)
  -- the case, the cloth, the notes
  rv.case = makeCase(rv, 250); rv.case:SetPoint("CENTER", rv, "CENTER", -150, -30); rv.case:SetFrameLevel(base + 4)
  rv.cloth = CreateFrame("Frame", nil, rv.case); rv.cloth:SetFrameLevel(lvOf(rv.case) + 14); rawset(rv.case, "cloth", rv.cloth)
  local k = rv.case.k
  rv.cloth:SetPoint("TOPLEFT", rv.case, "TOPLEFT", 10 * k, -94 * k); rv.cloth:SetSize(276 * k, 378 * k)
  rv.clothT = rv.cloth:CreateTexture(nil, "ARTWORK"); rv.clothT:SetTexture(MEDIA .. "GradeCloth"); rv.clothT:SetAllPoints(rv.cloth)
  rv.notes = CreateFrame("Frame", nil, rv, "BackdropTemplate"); rv.notes:SetSize(300, 300); rv.notes:SetPoint("TOPLEFT", rv, "CENTER", 40, 200); rv.notes:SetFrameLevel(base + 4)
  rv.notes:SetBackdrop({ bgFile = u.WHITE, edgeFile = u.WHITE, edgeSize = 1 }); rv.notes:SetBackdropColor(0.13, 0.11, 0.08, 0.92); rv.notes:SetBackdropBorderColor(0.42, 0.33, 0.18, 1)
  rv.notes.h = u.fs(rv.notes, "title", 13); rv.notes.h:SetPoint("TOPLEFT", 16, -14); rv.notes.h:SetText("THE GRADERS' NOTES"); rv.notes.h:SetTextColor(1, 0.83, 0.42)
  rv.rows = {}
  for i = 1, 4 do
    local r = CreateFrame("Frame", nil, rv.notes); r:SetSize(268, 26); r:SetPoint("TOPLEFT", 16, -42 - (i - 1) * 32)
    r.l = u.fs(r, "body", 14); r.l:SetPoint("LEFT"); r.l:SetText(GR().SUBS[i])
    r.v = u.fs(r, "title", 16); r.v:SetPoint("RIGHT"); r.v:SetJustifyH("RIGHT")
    r.line = r:CreateTexture(nil, "ARTWORK"); r.line:SetColorTexture(0.3, 0.26, 0.2, 1); r.line:SetHeight(1); r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
    rv.rows[i] = r
  end
  rv.stake = u.fs(rv.notes, "head", 12); rv.stake:SetPoint("TOPLEFT", 16, -178); rv.stake:SetWidth(268); rv.stake:SetJustifyH("LEFT"); rv.stake:SetTextColor(1, 0.83, 0.42); rv.stake:SetSpacing(2)
  rv.big = u.fs(rv, "title", 30); rv.big:SetPoint("TOPLEFT", rv, "CENTER", 40, -120); rv.big:SetJustifyH("LEFT")
  rv.line = u.fs(rv, "body", 13); rv.line:SetPoint("TOPLEFT", rv.big, "BOTTOMLEFT", 0, -6); rv.line:SetWidth(300); rv.line:SetJustifyH("LEFT"); rv.line:SetTextColor(0.92, 0.88, 0.78); rv.line:SetSpacing(2)
  rv.dim = rv:CreateTexture(nil, "OVERLAY", nil, 7); rv.dim:SetColorTexture(0, 0, 0, 1); rv.dim:SetPoint("TOPLEFT", 11, -11); rv.dim:SetPoint("BOTTOMRIGHT", -11, 11); rv.dim:SetAlpha(0)
  -- buttons
  rv.skip = u.gbtn(rv, "Skip", 80, 24, function() rv:Go("done") end); rv.skip:SetPoint("BOTTOMRIGHT", -24, 22); rv.skip:SetFrameLevel(base + 30)
  rv.b1 = u.gbtn(rv, "", 150, 28, nil); rv.b1:SetPoint("BOTTOMLEFT", rv, "CENTER", 40, -250); rv.b1:SetFrameLevel(base + 30)
  rv.b2 = u.gbtn(rv, "", 150, 28, nil); rv.b2:SetPoint("LEFT", rv.b1, "RIGHT", 8, 0); rv.b2:SetFrameLevel(base + 30)
  rv.b1:SetScript("OnClick", function(self) if self.enabled and self.fn then self.fn() end end)
  rv.b2:SetScript("OnClick", function(self) if self.enabled and self.fn then self.fn() end end)
  rv.close = u.gbtn(rv, "X", 28, 24, function() rv:Hide() end); rv.close:SetPoint("TOPRIGHT", -18, -18); rv.close:SetFrameLevel(base + 30)
  rv.confirm = confirmBox(rv)
  -- holding the mouse down speeds it up
  rv:SetScript("OnMouseDown", function() rv.fast = true end)
  rv:SetScript("OnMouseUp", function() rv.fast = false end)
  rv:SetScript("OnHide", function() rv.fast = false; rv.stage = nil; if RG.ArcadeRefresh then pcall(RG.ArcadeRefresh, true) end end)
end

local function fmt(v) return (v == math.floor(v)) and tostring(v) or string.format("%.1f", v) end
local function setButtons(b1, f1, b2, f2)
  rv.b1:SetText(b1 or ""); rv.b1.fn = f1; rv.b1:SetShown(b1 ~= nil); rv.b1:SetEnabled(true)
  rv.b2:SetText(b2 or ""); rv.b2.fn = f2; rv.b2:SetShown(b2 ~= nil); rv.b2:SetEnabled(true)
end
-- the case shows the scores revealed so far: the rest as if perfect, so wear only appears as each score lands
local function showPartial(n)
  local s = rv.s
  local t = { 10, 10, 10, 10 }
  for i = 1, n do t[i] = s[i] end
  rv.case:SetRec({ key = rv.rec.key, f = rv.rec.f, cert = rv.rec.cert, when = rv.rec.when }, t)
  rv.case:Seal("none", nil)
end

local TIMES = { crack = 0.9, sub = 1.1, last = 1.7, stake = 1.2, cloth = 0.55, hush = 0.8, land = 0.35 }
function RG.ArcadeGradePlay(rec, s, opts)
  if not rv then buildReveal() end
  opts = opts or {}
  rv.rec, rv.s, rv.opts = rec, s, opts
  local c = cardOf(rec.key)
  rv.title:SetText(opts.reserve and "FROM THE GUILD RESERVE" or "BACK FROM THE GRADERS"); rv.sub:SetText(opts.sub or "A parcel from the Waypoint Grading Guild")
  rv.who:SetText(((UnitName and select(2, pcall(UnitName, "player"))) or ""))
  local express = rec.svc == "express"
  rv.svcT:SetText(opts.reserve and (string.upper(opts.reserve.name or "") .. "  ·  RESERVE") or (express and "EXPRESS  ·  1 HOUR" or "STANDARD")); rv.stamp:SetShown(express)
  rv:Show()
  function rv:Go(stage)
    self.stage, self.t = stage, 0
    if stage == "parcel" then
      self.parcel:Show(); self.parcel:SetAlpha(1); self.whole:Show(); self.halfL:Hide(); self.halfR:Hide(); self.wax:Show()
      self.case:Hide(); self.notes:Hide(); self.big:SetText(""); self.line:SetText(""); self.rays:Hide(); self.dim:SetAlpha(0)
      self.hint:SetText("Click the seal to open it"); self.skip:Show(); setButtons(nil, nil, nil, nil)
    elseif stage == "crack" then
      self.whole:Hide(); self.halfL:Show(); self.halfR:Show(); self.hint:SetText("")
      if RG.ArcadeSound then RG.ArcadeSound("crack") end
    elseif stage == "notes" then
      self.parcel:Hide(); self.case:Show(); self.case:SetAlpha(1); self.cloth:Show(); self.cloth:SetHeight(378 * self.case.k)
      showPartial(0)
      self.notes:Show(); self.stake:SetText(""); self.staked = false
      for _, r in ipairs(self.rows) do r.v:SetText("|cff6d6658–|r") end
      self.n = 0; self.rolling = 1
    elseif stage == "done" then
      self:Final()
    end
  end
  function rv:Final()
    self.stage = "final"
    self.parcel:Hide(); self.cloth:Hide(); self.case:Show(); self.case:SetAlpha(1); self.notes:Show(); self.dim:SetAlpha(0); self.hint:SetText(""); self.skip:Hide()
    for i, r in ipairs(self.rows) do r.v:SetText(fmt(self.s[i])) end
    self.stake:SetText("")
    local g = RG.ArcadeGradeOf(self.s)
    local full = {}; for kk, vv in pairs(self.rec) do full[kk] = vv end; full.grade = g
    self.case:SetRec(full, self.s)
    local kind = RG.ArcadeGradeSeal(g); local ink = SEAL_INK[kind]
    self.big:SetText(RG.ArcadeGradeName(g):upper() .. " " .. g); self.big:SetTextColor(ink[1], ink[2], ink[3])
    local miss = RG.ArcadeGradeNearMiss(self.s)
    local first = (not self.opts.demo) and g >= 10 and #RG.ArcadeGradeCases(self.rec.key) <= 1
    self.line:SetText(g >= 10 and ("Flawless." .. (first and ("\nYour first Gem Mint " .. (cardOf(self.rec.key) or {}).name .. ".") or ""))
      or (g >= 8 and (miss and ("\"" .. miss .. "\"") or "A fine copy.") or ("\"This one's seen some roads.\"" .. (miss and ("\n" .. miss) or ""))))
    if self.opts.note and self.opts.note ~= "" then self.line:SetText((self.line:GetText() or "") .. "\n" .. self.opts.note) end   -- (a Reserve pack: its print, and whether it is new)
    self.rays:SetShown(g >= 10); self.rays:SetVertexColor(1, 0.85, 0.45, g >= 10 and 0.55 or 0)
    if RG.ArcadeSound then RG.ArcadeSound(g >= 10 and "best" or (g >= 8 and "reward" or "pick")) end
    if RG.ArcadeFx and g >= 10 then pcall(RG.ArcadeFx, "best") end
    local more = (not self.opts.demo) and #RG.ArcadeGradeState().back or 0
    local cert = self.rec.id
    local function nextOne() if more > 0 then RG.ArcadeGradeReveal(1) else self:Hide() end end
    if self.opts.demo then setButtons("Close", function() self:Hide() end, nil, nil)
    elseif self.opts.reserve then
      -- a Reserve pack: sell it back now (today's price), or keep it (it is in your collection and your Vault already)
      local v = RG.ArcadeGradeValue(full)
      local function sellIt() local ok, msg = RG.ArcadeGradeSell(cert); say(msg); self:Hide() end
      setButtons("Sell back  ·  " .. v, function()
        if g >= 9 then
          self.confirm:Ask("Sell your " .. g .. " (" .. RG.ArcadeGradeName(g) .. ") for " .. v .. " coins?\nIt leaves your collection for good.", "Sell it", sellIt)
        else sellIt() end
      end, "Keep it", function() self:Hide() end)
    elseif g <= 7 then
      setButtons("Crack the case", function()
        local ok, msg = RG.ArcadeGradeCrack(cert); say(msg); nextOne()
      end, more > 0 and ("Keep it  ·  next (" .. more .. ")") or "Keep it", nextOne)
    else
      setButtons("Pin to showcase", function() RG.ArcadeGradePin(cert); say("On your showcase."); self.b1:SetEnabled(false) end,
        more > 0 and ("Next parcel (" .. more .. ")") or "Done", nextOne)
    end
  end
  rv:SetScript("OnUpdate", function(self, dt)
    if not self.stage or self.stage == "final" then
      if self.rays:IsShown() and self.rays.SetRotation then self.rot = ((self.rot or 0) + dt * 0.15) % 6.2832; self.rays:SetRotation(self.rot) end
      return
    end
    dt = dt * (self.fast and 3 or 1)
    self.t = (self.t or 0) + dt
    local t = self.t
    if self.stage == "parcel" then
      local p = 1 + 0.035 * math.sin(GetTime() * 3)
      self.whole:SetSize(self.wax:GetWidth() * p, self.wax:GetHeight() * p); self.whole:ClearAllPoints(); self.whole:SetPoint("CENTER")
    elseif self.stage == "crack" then
      local p = math.min(1, t / TIMES.crack)
      local w = self.wax:GetWidth()
      self.halfL:ClearAllPoints(); self.halfL:SetPoint("CENTER", self.wax, "CENTER", -28 * p, -10 * p); self.halfL:SetAlpha(1 - p)
      self.halfR:ClearAllPoints(); self.halfR:SetPoint("CENTER", self.wax, "CENTER", 30 * p, 6 * p); self.halfR:SetAlpha(1 - p)
      if self.halfL.SetRotation then self.halfL:SetRotation(-0.35 * p); self.halfR:SetRotation(0.3 * p) end
      self.spark:SetVertexColor(1, 0.85, 0.5, math.max(0, 0.9 * (1 - p * 1.6)))
      self.parcel:SetAlpha(1 - math.max(0, (p - 0.4) / 0.6))
      if p >= 1 then self.spark:SetVertexColor(1, 0.85, 0.5, 0); self:Go("notes") end
    elseif self.stage == "notes" then
      local i = self.n + 1
      if i > 4 then self.stage, self.t = "cloth", 0; return end
      local dur = (i == 4) and TIMES.last or TIMES.sub
      if i == 4 and not self.staked then
        -- before the last score: what it needs
        self.stake:SetText(RG.ArcadeGradeStakes({ self.s[1], self.s[2], self.s[3] }))
        if t < TIMES.stake then return end
        self.staked = true; self.t = 0; t = 0
      end
      local p = math.min(1, t / dur)
      -- a dial: fast at first, slowing, wobbling between neighbours before it lands
      if p < 1 then
        self.tick = (self.tick or 0) + dt
        local every = 0.04 + 0.22 * p * p
        if self.tick >= every then
          self.tick = 0
          local v = math.max(1, math.min(10, self.s[i] + (math.random(-4, 4) * 0.5) * (1 - p)))
          self.rows[i].v:SetText("|cff9fd4ff" .. fmt(v) .. "|r")
          if RG.ArcadeSound and p > 0.5 then RG.ArcadeSound("hover") end
        end
      else
        self.rows[i].v:SetText(fmt(self.s[i]))
        self.n = i; self.t = 0; self.staked = (i == 4) and self.staked or false
        showPartial(i)
        if RG.ArcadeSound then RG.ArcadeSound("pick") end
      end
    elseif self.stage == "cloth" then
      local p = math.min(1, t / TIMES.cloth)
      self.cloth:SetHeight(math.max(1, 378 * self.case.k * (1 - p)))
      if p >= 1 then self.cloth:Hide(); self.stage, self.t = "hush", 0 end
    elseif self.stage == "hush" then
      self.dim:SetAlpha(0.45 * math.min(1, t / 0.2))
      if t >= TIMES.hush then self.staked = false; self:Final() end
    end
  end)
  rv:Go("parcel")
  rv.staked = false
end

-- open the next parcel on the doorstep (or the one at i)
function RG.ArcadeGradeReveal(i)
  local r, s = RG.ArcadeGradeOpen(i or 1)
  if not r then return end
  RG.ArcadeGradePlay(r, s)
  if RG.ArcadeRefresh then pcall(RG.ArcadeRefresh, true) end
end
-- a parcel arrived: a toast with "Open now"
function RG.ArcadeGradeArrived(n)
  local st = RG.ArcadeGradeState()
  local total = #st.back
  if RG.Toast then
    RG.Toast("Back from the graders", (total > 1 and (total .. " parcels from the Waypoint Grading Guild have arrived.") or "A parcel from the Waypoint Grading Guild has arrived."),
      "Interface\\Icons\\INV_Letter_15", "Open now", function() RG.ArcadeGradeReveal(1) end, 12)
  elseif RG.Print then RG.Print("A parcel from the Waypoint Grading Guild has arrived: /wp cards, Shop, Grading desk.") end
  if RG.ArcadeRefresh then pcall(RG.ArcadeRefresh, true) end
end

-- ---------------------------------------------------------------------------
-- /wp gradetour and /wp gradecheck
-- ---------------------------------------------------------------------------
-- (every size a case is drawn at: the reveal and the tour, a graded card's page, the desk; the collection grid shows a seal instead)
local SIZES = { { "Reveal", 250 }, { "Card page", 220 }, { "Desk", 172 } }
local function demoRec(c, f, grade)
  local s
  for _ = 1, 400 do s = RG.ArcadeGradeRoll(); if RG.ArcadeGradeOf(s) == grade then break end end
  return { key = c.key or c.name, f = f, grade = RG.ArcadeGradeOf(s), s = RG.ArcadeGradeEncode(s), cert = 4127, when = date and date("%d %b %Y") or "" }, s
end
local function tourList()
  local u = U(); local list = {}
  local function add(label, pred, f, grade)
    for _, c in ipairs(u.CARDS) do if pred(c) then list[#list + 1] = { label = label, c = c, f = f, grade = grade }; return end end
  end
  add("Item · Common", function(c) return c.kind == 1 end, 1, 8)
  add("Creature · Rare", function(c) return c.kind == 2 and not c.dun end, 2, 10)
  add("Place · Holo", function(c) return c.kind == 3 end, 3, 6)
  add("Full art", function(c) return c.kind == 2 and c.tier == 5 end, 4, 4)
  add("Mythic", function(c) return c.tier == 7 end, 1, 10)
  add("Mythic, worn", function(c) return c.tier == 7 end, 1, 2)
  add("Dungeon boss", function(c) return c.dun and c.kind == 2 end, 2, 9)
  add("Field Guide rare", function(c) return c.field end, 1, 7)
  add("Raid card", function(c) return RG.ArcadeIsRaid and c.dun and RG.ArcadeIsRaid(c.dun) end, 3, 9)
  add("Raider", function(c) return c.kind == 4 end, 1, 8)
  local longest
  for _, c in ipairs(u.CARDS) do if not longest or #c.name > #longest.name then longest = c end end
  if longest then list[#list + 1] = { label = "The longest name", c = longest, f = 3, grade = 9 } end
  for g = 10, 1, -1 do list[#list + 1] = { label = "Wear: " .. g .. " " .. RG.ArcadeGradeName(g), c = list[2] and list[2].c or u.CARDS[1], f = 2, grade = g } end
  return list
end
local tour
function RG.ArcadeGradeTour()
  local u = U()
  if not tour then
    tour = CreateFrame("Frame", "WaypathGradeTour", UIParent, "BackdropTemplate"); tour:SetFrameStrata("FULLSCREEN_DIALOG"); tour:SetPoint("CENTER")
    u.darkPanel(tour, 1060, 560); tour:EnableMouse(true); tour:SetMovable(true); tour:RegisterForDrag("LeftButton")
    tour:SetScript("OnDragStart", tour.StartMoving); tour:SetScript("OnDragStop", tour.StopMovingOrSizing)
    tinsert(UISpecialFrames, "WaypathGradeTour")
    tour.title = u.fs(tour, "title", 17); tour.title:SetPoint("TOPLEFT", 30, -24); tour.title:SetTextColor(1, 0.83, 0.42)
    tour.cases = {}
    local x = 30
    for i, sz in ipairs(SIZES) do
      local cs = makeCase(tour, sz[2]); cs:SetPoint("BOTTOMLEFT", tour, "BOTTOMLEFT", x, 70)
      cs.cap = u.fs(tour, "body", 11.5); cs.cap:SetPoint("TOP", cs, "BOTTOM", 0, -6); cs.cap:SetText(sz[1]); cs.cap:SetTextColor(0.75, 0.7, 0.6)
      x = x + cs:GetWidth() + 14
      tour.cases[i] = cs
    end
    tour.i = 1
    tour.prev = u.gbtn(tour, "<", 36, 24, function() tour.i = math.max(1, tour.i - 1); tour:Paint() end); tour.prev:SetPoint("TOPRIGHT", -250, -22)
    tour.next = u.gbtn(tour, ">", 36, 24, function() tour.i = math.min(#tour.list, tour.i + 1); tour:Paint() end); tour.next:SetPoint("LEFT", tour.prev, "RIGHT", 6, 0)
    tour.play = u.gbtn(tour, "Play the reveal", 130, 24, function() local e = tour.list[tour.i]; local r, s = demoRec(e.c, e.f, e.grade); r.svc = "standard"; RG.ArcadeGradePlay(r, s, { demo = true, sub = "A demonstration: nothing in your collection changes" }) end)
    tour.play:SetPoint("LEFT", tour.next, "RIGHT", 6, 0)
    tour.close = u.gbtn(tour, "X", 28, 24, function() tour:Hide() end); tour.close:SetPoint("TOPRIGHT", -18, -18)
    function tour:Paint()
      local e = self.list[self.i]; if not e then return end
      self.title:SetText("Grading tour  ·  " .. self.i .. " / " .. #self.list .. "  ·  " .. e.label .. "  ·  " .. e.c.name)
      local r, s = demoRec(e.c, e.f, e.grade)
      for _, cs in ipairs(self.cases) do cs:SetRec(r, s) end
    end
  end
  tour.list = tourList()
  tour:Show(); tour:Paint()
end

-- every card in a case at every size: does everything fit and stack in the right order?
local checking
function RG.ArcadeGradeCheck()
  if checking then RG.Print("The grading check is already running.") return end
  local u = U()
  checking = true
  local host = CreateFrame("Frame", nil, UIParent); host:SetSize(10, 10); host:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -3000, 3000); host:Show()
  local cs = {}
  for i, sz in ipairs(SIZES) do cs[i] = makeCase(host, sz[2]); cs[i]:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0) end
  local cards = u.CARDS
  local bad, n, i = {}, 0, 0
  local function problem(text) if #bad < 400 then bad[#bad + 1] = text end end
  local function checkOne(c)
    n = n + 1
    local grade = (n % 10) + 1
    local r, s = demoRec(c, (n % 4) + 1, grade)
    for k, case in ipairs(cs) do
      local ok, err = pcall(case.SetRec, case, r, s)
      if not ok then problem(c.name .. " (" .. SIZES[k][1] .. "): " .. tostring(err)) else
        local L = case.label
        -- the name: never cut short, and clear of the seal
        if L.name.IsTruncated and L.name:IsTruncated() then problem(c.name .. " (" .. SIZES[k][1] .. "): its name is cut short on the case") end
        local nw = L.name.GetStringWidth and L.name:GetStringWidth() or 0
        local maxW = (276 - 12 - 76) * case.k
        if case.lines == 1 and nw > maxW + 1 then problem(c.name .. " (" .. SIZES[k][1] .. "): its name runs into the seal") end
        -- the label's lines stay on the plate
        if not case.small then
          local bottom = L:GetBottom(); local cb = (L.cert:IsShown() and L.cert or L.meta):GetBottom()
          if bottom and cb and cb < bottom - 0.5 then problem(c.name .. " (" .. SIZES[k][1] .. "): the plate's lines run off the plate") end
        end
        -- the layers: the card under the glass, the plate over everything; wear over the card's frame
        local cl, gl, ll = case.card:GetFrameLevel(), case.glass:GetFrameLevel(), case.label:GetFrameLevel()
        if not (cl < gl and gl < ll) then problem(c.name .. " (" .. SIZES[k][1] .. "): the case's layers are out of order") end
        local top4 = case.card.top and case.card.top:GetFrameLevel()
        local wl = rawget(case.card, "wear")
        if wl and wl:IsShown() and top4 and wl:GetFrameLevel() <= top4 then problem(c.name .. " (" .. SIZES[k][1] .. "): the wear is under the card's frame") end
        local mdl = rawget(case.card, "model")
        if mdl and mdl:IsShown() and mdl:GetFrameLevel() >= gl then problem(c.name .. " (" .. SIZES[k][1] .. "): the 3D model is above the case's glass") end
        -- everything inside the case
        local L0, R0, T0, B0 = case:GetLeft(), case:GetRight(), case:GetTop(), case:GetBottom()
        local l1, r1, t1, b1 = case.card:GetLeft(), case.card:GetRight(), case.card:GetTop(), case.card:GetBottom()
        if L0 and R0 and T0 and B0 and l1 and r1 and t1 and b1 and (l1 < L0 - 0.5 or r1 > R0 + 0.5 or t1 > T0 + 0.5 or b1 < B0 - 0.5) then problem(c.name .. " (" .. SIZES[k][1] .. "): the card sticks out of the case") end
        if not L.seal:GetTexture() then problem(c.name .. " (" .. SIZES[k][1] .. "): no seal") end
      end
    end
  end
  RG.Print("Putting " .. #cards .. " cards in cases at " .. #SIZES .. " sizes... about a minute.")
  local function step()
    for _ = 1, 25 do
      i = i + 1
      local c = cards[i]
      if not c then
        checking = false; host:Hide()
        local out = { "Waypath+ grading check: " .. n .. " cards in cases at " .. #SIZES .. " sizes (" .. n * #SIZES .. " cases), " .. #bad .. " problem(s)", "" }
        for _, l in ipairs(bad) do out[#out + 1] = l end
        if #bad == 0 then out[#out + 1] = "Every card fits its case at every size, and every layer is in its place." end
        if RG.ShowErrors then RG.ShowErrors(table.concat(out, "\n"), "Waypath+ grading check  ·  Ctrl+A, Ctrl+C to copy") else RG.Print(out[1]) end
        return
      end
      local ok, err = pcall(checkOne, c)
      if not ok then problem(c.name .. ": " .. tostring(err)) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.02, step) else step() end
  end
  step()
end

do
  local base = SlashCmdList and SlashCmdList.WAYPATH
  if base then
    SlashCmdList.WAYPATH = function(msg)
      local cmd = (msg or ""):match("^%s*(%S+)")
      cmd = cmd and cmd:lower()
      if cmd == "gradecheck" then RG.ArcadeGradeCheck() return end
      if cmd == "gradetour" then RG.ArcadeGradeTour() return end
      if cmd == "grading" then RG.ArcadeGradeDesk() return end
      return base(msg)
    end
  end
end
