local _, RG = ...
-- Waypath Cards: the Guild Reserve, the Vault and the Guild market, drawn (the rules are in ArcadeReserve.lua).
--   * the way in: a "Guild Reserve" button in the Waypoint Grading Guild's banner on the Shop's storefront
--   * one page with three views: Packs (Summit and Pinnacle, with their odds), Vault (every case you hold, with its
--     price today, its arrow and a week's chart) and Market (what is hot and cooling today, and what your Vault is worth)
--   * buying a pack plays the grading reveal (ArcadeGradingUI.lua) for a case that came already graded
--   * /wp reserve opens it

local function U() return RG.ArcadeUI end
local function store() local u = U(); return u and u.store and u.store() end
local MEDIA = "Interface\\AddOns\\Waypath\\Media\\Arcade\\"
local X0 = 34
local GOLD = "|cffffd36b"
local SEAL_CELL = { gold = 0, silver = 1, bronze = 2, none = 3 }
local SEAL_INK = { gold = { 1, 0.86, 0.45 }, silver = { 0.88, 0.9, 0.95 }, bronze = { 0.94, 0.72, 0.52 } }
local GRADE_HEX = { [10] = "|cffffd36b", [9] = "|cffd4dbe8", [8] = "|cffd99a61" }
local GRADE_COL = { [10] = { 1, 0.82, 0.3 }, [9] = { 0.78, 0.82, 0.9 }, [8] = { 0.85, 0.6, 0.38 } }
local PRINT = { [1] = "Common", [2] = "Rare", [3] = "Holo", [4] = "Full art", [5] = "Gilded" }
local function lvOf(f) return (f and f.GetFrameLevel and f:GetFrameLevel()) or 1 end
local function say(text) if RG.ArcadeMsg then RG.ArcadeMsg(text) elseif RG.Print then RG.Print(text) end end
local function cardOf(key) local u = U(); return u and u.byKey and u.byKey[key] end
local function pct(x) if x >= 0.095 then return string.format("%.0f%%", x * 100) end return string.format("%.1f%%", x * 100) end
local function signed(p)   -- (+8% / -4%: no arrows, the game's fonts don't have them)
  local n = math.floor(math.abs(p) * 100 + 0.5)
  if n == 0 then return "|cffa8a08a0%|r" end
  return (p > 0 and "|cff7be08a+" or "|cffff8a70-") .. n .. "%|r"
end
local function timeLeft(secs)
  secs = math.max(0, math.floor(secs))
  local h, m = math.floor(secs / 3600), math.floor(secs % 3600 / 60)
  if h > 0 then return h .. "h " .. m .. "m" end
  return math.max(1, m) .. "m"
end

local res
local sel = {}

-- ---------------------------------------------------------------------------
-- Building the page
-- ---------------------------------------------------------------------------
local function box(parent, x, y, w, h, title)
  local u = U()
  local b = CreateFrame("Frame", nil, parent, "BackdropTemplate"); b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); b:SetSize(w, h)
  b:SetBackdrop({ bgFile = u.WHITE, edgeFile = u.WHITE, edgeSize = 1 }); b:SetBackdropColor(0.13, 0.11, 0.08, 0.92); b:SetBackdropBorderColor(0.42, 0.33, 0.18, 1)
  b.h = u.fs(b, "title", 12); b.h:SetPoint("TOPLEFT", 14, -12); b.h:SetText(title or ""); b.h:SetTextColor(1, 0.83, 0.42)
  return b
end
local function sealTex(t, kind) local c = SEAL_CELL[kind] or 3; t:SetTexCoord(c * 0.25, (c + 1) * 0.25, 0, 1) end

local function buildPacks(page)
  local u = U()
  page.tiers = {}
  for i, t in ipairs(RG.ARCADE_RESERVE.TIERS) do
    local b = box(page, X0, -196 - (i - 1) * 188, 722, 176, string.upper(t.name))
    b.h:SetPoint("TOPLEFT", 112, -14); u.setfont(b.h, "title", 18); b.h:SetTextColor(t.col[1], t.col[2], t.col[3])
    b.key = t.key
    -- the seal of the pack: the guild's wax, tinted for the pack
    b.seal = b:CreateTexture(nil, "ARTWORK"); b.seal:SetTexture(MEDIA .. "GradeWax"); b.seal:SetTexCoord(0, 0.5, 0, 0.5); b.seal:SetSize(84, 84); b.seal:SetPoint("TOPLEFT", 16, -16)
    b.seal:SetVertexColor(t.col[1], t.col[2], t.col[3], 1)
    b.glow = b:CreateTexture(nil, "BACKGROUND"); b.glow:SetTexture(MEDIA .. "Glow"); b.glow:SetBlendMode("ADD"); b.glow:SetSize(150, 150); b.glow:SetPoint("CENTER", b.seal, "CENTER")
    b.glow:SetVertexColor(t.col[1], t.col[2], t.col[3], 0.35)
    b.rule = u.fs(b, "body", 12); b.rule:SetPoint("TOPLEFT", 112, -40); b.rule:SetWidth(360); b.rule:SetJustifyH("LEFT"); b.rule:SetTextColor(0.85, 0.8, 0.68)
    b.gh = u.fs(b, "head", 10.5); b.gh:SetPoint("TOPLEFT", 112, -66); b.gh:SetText("CHANCE OF EACH GRADE"); b.gh:SetTextColor(0.7, 0.62, 0.45)
    b.barBg = b:CreateTexture(nil, "ARTWORK"); b.barBg:SetColorTexture(0.18, 0.16, 0.13, 1); b.barBg:SetPoint("TOPLEFT", 112, -82); b.barBg:SetSize(360, 12)
    b.seg = {}
    for k = 1, 3 do
      local s = b:CreateTexture(nil, "OVERLAY"); s:SetHeight(12); b.seg[k] = s
    end
    b.legend = u.fs(b, "body", 11.5); b.legend:SetPoint("TOPLEFT", 112, -99); b.legend:SetWidth(360); b.legend:SetJustifyH("LEFT")
    b.ph = u.fs(b, "head", 10.5); b.ph:SetPoint("TOPLEFT", 112, -120); b.ph:SetText("PRINTS"); b.ph:SetTextColor(0.7, 0.62, 0.45)
    b.prints = u.fs(b, "body", 11.5); b.prints:SetPoint("TOPLEFT", 112, -135); b.prints:SetWidth(380); b.prints:SetJustifyH("LEFT"); b.prints:SetTextColor(0.92, 0.88, 0.78)
    b.price = u.fs(b, "title", 22); b.price:SetPoint("TOPRIGHT", -16, -14); b.price:SetJustifyH("RIGHT")
    b.worth = u.fs(b, "body", 11.5); b.worth:SetPoint("TOPRIGHT", -16, -46); b.worth:SetWidth(190); b.worth:SetJustifyH("RIGHT"); b.worth:SetTextColor(0.78, 0.74, 0.64)
    b.buy = u.gbtn(b, "", 190, 34, function()
      local ok, rec, s, g, notes = RG.ArcadeReserveBuy(t.key)
      if not ok then say(rec); if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end return end
      local bits = {}
      local c = cardOf(rec.key)
      bits[#bits + 1] = (PRINT[rec.f] or "") .. " print"
      if c and c.tier == 7 then bits[#bits + 1] = "a Mythic!" end
      if g and g.new then bits[#bits + 1] = "a new card for your collection" elseif g and g.newPrint then bits[#bits + 1] = "a new print" end
      if RG.ArcadeGradePlay then
        RG.ArcadeGradePlay(rec, s, { reserve = { name = t.name, price = t.price }, sub = t.name .. " pack  ·  graded and cased by the Waypoint Grading Guild",
          note = table.concat(bits, "  ·  ") })
      end
      if notes and #notes > 0 then say(table.concat(notes, "   ")) end
      if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
    end, true)
    b.buy:SetPoint("BOTTOMRIGHT", -16, 16); b.buy:SetActive(true)
    page.tiers[i] = b
  end
  page.foot = box(page, X0, -572, 722, 72, "")
  page.foot.t = u.fs(page.foot, "body", 12); page.foot.t:SetPoint("TOPLEFT", 14, -12); page.foot.t:SetWidth(694); page.foot.t:SetJustifyH("LEFT"); page.foot.t:SetSpacing(2)
  page.foot.t:SetTextColor(0.8, 0.75, 0.64)
  page.foot.t:SetText("A Reserve pack is one card that comes already graded and in its case, so it skips the wait at the graders. It joins your collection like any card; sell it, show it, crack it out, or hold it for a better day. Prices follow the Guild market (Market tab). Coins only.")
end

local function buildVault(page)
  local u = U()
  page.list = box(page, X0, -196, 360, 448, "YOUR CASES")
  page.rows = {}
  for i = 1, 12 do
    local b = CreateFrame("Button", nil, page.list); b:SetSize(332, 26); b:SetPoint("TOPLEFT", 14, -34 - (i - 1) * 29)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b); b.bg:SetColorTexture(1, 0.85, 0.5, 0.06)
    b.seal = b:CreateTexture(nil, "ARTWORK"); b.seal:SetTexture(MEDIA .. "GradeSeals"); b.seal:SetSize(22, 22); b.seal:SetPoint("LEFT", 2, 0)
    b.g = u.fs(b, "title", 10.5, "OVERLAY", "OUTLINE"); b.g:SetPoint("CENTER", b.seal, "CENTER", 0, 0)
    b.name = u.fs(b, "body", 12); b.name:SetPoint("LEFT", b.seal, "RIGHT", 6, 0); b.name:SetWidth(176); b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.chg = u.fs(b, "head", 11.5); b.chg:SetPoint("RIGHT", -6, 0); b.chg:SetWidth(44); b.chg:SetJustifyH("RIGHT")
    b.val = u.fs(b, "head", 12); b.val:SetPoint("RIGHT", b.chg, "LEFT", -4, 0); b.val:SetWidth(60); b.val:SetJustifyH("RIGHT")
    b:SetScript("OnClick", function(self) if self.id then sel.cert = self.id; RG.ArcadeRefresh(true) end end)
    b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(1, 0.85, 0.5, 0.14) end)
    b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 0.85, 0.5, self.on and 0.18 or 0.06) end)
    page.rows[i] = b
  end
  page.page = 1
  page.prev = u.gbtn(page.list, "<", 30, 22, function() page.page = math.max(1, page.page - 1); RG.ArcadeRefresh(true) end); page.prev:SetPoint("BOTTOMLEFT", 14, 12)
  page.next = u.gbtn(page.list, ">", 30, 22, function() page.page = page.page + 1; RG.ArcadeRefresh(true) end); page.next:SetPoint("LEFT", page.prev, "RIGHT", 6, 0)
  page.pageT = u.fs(page.list, "body", 11); page.pageT:SetPoint("LEFT", page.next, "RIGHT", 8, 0); page.pageT:SetTextColor(0.7, 0.66, 0.56)
  page.empty = u.fs(page.list, "body", 12.5); page.empty:SetPoint("TOPLEFT", 14, -40); page.empty:SetWidth(330); page.empty:SetJustifyH("LEFT"); page.empty:SetTextColor(0.8, 0.75, 0.64); page.empty:SetSpacing(2)

  page.det = box(page, X0 + 372, -196, 350, 448, "THE SLAB")
  local d = page.det
  d.case = RG.ArcadeMakeCase(d, 140); d.case:SetPoint("TOPLEFT", 14, -34)
  d.gname = u.fs(d, "title", 15); d.gname:SetPoint("TOPLEFT", 188, -38); d.gname:SetWidth(148); d.gname:SetJustifyH("LEFT")
  d.info = u.fs(d, "body", 11.5); d.info:SetPoint("TOPLEFT", 188, -62); d.info:SetWidth(148); d.info:SetJustifyH("LEFT"); d.info:SetSpacing(3); d.info:SetTextColor(0.85, 0.8, 0.68)
  d.today = u.fs(d, "title", 20); d.today:SetPoint("TOPLEFT", 188, -168); d.today:SetWidth(148); d.today:SetJustifyH("LEFT"); d.today:SetTextColor(1, 0.83, 0.42)
  d.chg = u.fs(d, "body", 11.5); d.chg:SetPoint("TOPLEFT", d.today, "BOTTOMLEFT", 0, -3); d.chg:SetWidth(148); d.chg:SetJustifyH("LEFT"); d.chg:SetSpacing(2); d.chg:SetTextColor(0.8, 0.75, 0.64)
  d.ch = u.fs(d, "head", 10.5); d.ch:SetPoint("TOPLEFT", 14, -306); d.ch:SetText("LAST 7 DAYS"); d.ch:SetTextColor(0.7, 0.62, 0.45)
  d.chBase = d:CreateTexture(nil, "ARTWORK"); d.chBase:SetColorTexture(0.42, 0.33, 0.18, 1); d.chBase:SetHeight(1)
  d.chBase:SetPoint("TOPLEFT", 14, -370); d.chBase:SetSize(322, 1)
  d.bars, d.barT = {}, {}
  for i = 1, 7 do
    local t = d:CreateTexture(nil, "OVERLAY"); t:SetWidth(34); d.bars[i] = t
    local l = u.fs(d, "body", 10); l:SetPoint("TOPLEFT", 14 + (i - 1) * 48, -373); l:SetWidth(34); l:SetJustifyH("CENTER"); l:SetTextColor(0.6, 0.56, 0.48)
    l:SetText(i == 7 and "today" or ((7 - i) .. "d")); d.barT[i] = l
  end
  d.sell = u.gbtn(d, "Sell back", 100, 28, function()
    local r = sel.rec; if not r then return end
    local v = RG.ArcadeGradeValue(r)
    local function go()
      local ok, msg = RG.ArcadeGradeSell(r.id); say(msg); if ok then sel.cert = nil end; RG.ArcadeRefresh(true)
    end
    if r.grade >= 9 then page.confirm:Ask("Sell your " .. r.grade .. " (" .. RG.ArcadeGradeName(r.grade) .. ") for " .. v .. " coins?\nIt leaves your collection for good.", "Sell it", go) else go() end
  end, true)
  d.sell:SetPoint("BOTTOMLEFT", 14, 14); d.sell:SetActive(true)
  d.pin = u.gbtn(d, "Showcase", 100, 28, function()
    local r = sel.rec; if r and RG.ArcadeGradePin(r.id) then say("Your " .. ((cardOf(r.key) or {}).name or "card") .. " case is on your showcase.") end
  end)
  d.pin:SetPoint("LEFT", d.sell, "RIGHT", 6, 0)
  d.open = u.gbtn(d, "Case page", 100, 28, function()
    local r = sel.rec; if r and RG.ArcadeGradeDesk then RG.ArcadeGradeDesk(nil, nil, r.id) end
  end)
  d.open:SetPoint("LEFT", d.pin, "RIGHT", 6, 0)
  d.none = u.fs(d, "body", 12.5); d.none:SetPoint("TOPLEFT", 14, -40); d.none:SetWidth(320); d.none:SetJustifyH("LEFT"); d.none:SetTextColor(0.8, 0.75, 0.64); d.none:SetSpacing(2)
end

local function buildMarket(page)
  local u = U()
  page.hot = box(page, X0, -196, 432, 226, "HOT TODAY")
  page.hotRows = {}
  for i = 1, 4 do
    local r = CreateFrame("Frame", nil, page.hot); r:SetSize(404, 40); r:SetPoint("TOPLEFT", 14, -36 - (i - 1) * 44)
    r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetColorTexture(0.88, 0.7, 0.35, 1); r.dot:SetSize(6, 6); r.dot:SetPoint("LEFT", 0, 0)
    r.name = u.fs(r, "head", 13); r.name:SetPoint("TOPLEFT", 16, -2); r.name:SetWidth(310); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false); r.name:SetTextColor(1, 0.94, 0.78)
    r.why = u.fs(r, "body", 11); r.why:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3); r.why:SetWidth(310); r.why:SetJustifyH("LEFT"); r.why:SetTextColor(0.7, 0.66, 0.56)
    r.p = u.fs(r, "title", 16); r.p:SetPoint("RIGHT", 0, 0); r.p:SetJustifyH("RIGHT")
    page.hotRows[i] = r
  end
  page.mine = box(page, X0 + 444, -196, 278, 226, "YOUR VAULT")
  page.mine.big = u.fs(page.mine, "title", 26); page.mine.big:SetPoint("TOPLEFT", 14, -38); page.mine.big:SetTextColor(1, 0.83, 0.42)
  page.mine.chg = u.fs(page.mine, "body", 12); page.mine.chg:SetPoint("TOPLEFT", page.mine.big, "BOTTOMLEFT", 0, -4); page.mine.chg:SetWidth(250); page.mine.chg:SetJustifyH("LEFT")
  page.mine.txt = u.fs(page.mine, "body", 11.5); page.mine.txt:SetPoint("TOPLEFT", 14, -104); page.mine.txt:SetWidth(250); page.mine.txt:SetJustifyH("LEFT"); page.mine.txt:SetSpacing(3); page.mine.txt:SetTextColor(0.8, 0.75, 0.64)
  page.mine.go = u.gbtn(page.mine, "Open the Vault", 150, 28, function() sel.tab = "vault"; RG.ArcadeRefresh(true) end)
  page.mine.go:SetPoint("BOTTOMLEFT", 14, 14)
  page.cold = box(page, X0, -442, 722, 100, "COOLING OFF")
  page.coldRows = {}
  for i = 1, 2 do
    local r = CreateFrame("Frame", nil, page.cold); r:SetSize(694, 24); r:SetPoint("TOPLEFT", 14, -34 - (i - 1) * 30)
    r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetColorTexture(0.55, 0.5, 0.45, 1); r.dot:SetSize(6, 6); r.dot:SetPoint("LEFT", 0, 0)
    r.name = u.fs(r, "head", 12.5); r.name:SetPoint("LEFT", 16, 0); r.name:SetWidth(260); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false); r.name:SetTextColor(0.92, 0.88, 0.78)
    r.why = u.fs(r, "body", 11); r.why:SetPoint("LEFT", 290, 0); r.why:SetWidth(330); r.why:SetJustifyH("LEFT"); r.why:SetWordWrap(false); r.why:SetTextColor(0.7, 0.66, 0.56)
    r.p = u.fs(r, "title", 15); r.p:SetPoint("RIGHT", 0, 0); r.p:SetJustifyH("RIGHT")
    page.coldRows[i] = r
  end
  page.note = box(page, X0, -570, 722, 74, "")
  page.note.t = u.fs(page.note, "body", 11.5); page.note.t:SetPoint("TOPLEFT", 14, -10); page.note.t:SetWidth(694); page.note.t:SetJustifyH("LEFT"); page.note.t:SetSpacing(2); page.note.t:SetTextColor(0.78, 0.74, 0.64)
end

-- a confirmation inside the window (no game popups): the same look as the grading desk's
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

local function build(frame)
  local u = U()
  res = CreateFrame("Frame", nil, frame); res:SetAllPoints(frame); res:SetFrameLevel(lvOf(frame) + 6)
  res.back = u.gbtn(res, "<  Shop", 78, 24, function() local v = RG.ArcadeView; if v then v.shopSection = nil end; RG.ArcadeRefresh(true) end)
  res.back:SetPoint("TOPLEFT", X0, -156)
  res.head = u.fs(res, "title", 15); res.head:SetPoint("LEFT", res.back, "RIGHT", 14, 0); res.head:SetTextColor(1, 0.92, 0.7); res.head:SetText("THE GUILD RESERVE")
  res.right = u.fs(res, "body", 12); res.right:SetPoint("TOPRIGHT", res, "TOPRIGHT", -X0, -163); res.right:SetJustifyH("RIGHT"); res.right:SetTextColor(0.85, 0.78, 0.6)
  res.line = res:CreateTexture(nil, "ARTWORK"); res.line:SetColorTexture(0.72, 0.58, 0.3, 0.45); res.line:SetHeight(1)
  res.line:SetPoint("TOPLEFT", X0, -184); res.line:SetPoint("TOPRIGHT", -X0, -184)
  res.tabs = {}
  local prev
  for _, tb in ipairs({ { "packs", "Packs" }, { "vault", "Vault" }, { "market", "Market" } }) do
    local b = u.gbtn(res, tb[2], 78, 24, function() sel.tab = tb[1]; RG.ArcadeRefresh(true) end)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", res.head, "RIGHT", 24, 0) end
    b.key = tb[1]; res.tabs[#res.tabs + 1] = b; prev = b
  end
  res.packs = CreateFrame("Frame", nil, res); res.packs:SetAllPoints(res); buildPacks(res.packs)
  res.vault = CreateFrame("Frame", nil, res); res.vault:SetAllPoints(res); buildVault(res.vault)
  res.market = CreateFrame("Frame", nil, res); res.market:SetAllPoints(res); buildMarket(res.market)
  res.vault.confirm = confirmBox(res)
end

-- ---------------------------------------------------------------------------
-- Painting
-- ---------------------------------------------------------------------------
local function paintPacks(a)
  local page = res.packs
  local coins = a.coins or 0
  for i, b in ipairs(page.tiers) do
    local t = RG.ARCADE_RESERVE.byKey[b.key]
    local o = RG.ArcadeReserveOdds(t.key)
    b.rule:SetText("Grade " .. t.floor .. " or better, guaranteed  ·  one card in its case")
    -- the grade bar: highest grade first
    local x = 112
    for k, s in ipairs(b.seg) do
      local e = o.grades[k]
      if e then
        local w = math.max(1, 360 * e[2])
        s:ClearAllPoints(); s:SetPoint("TOPLEFT", b, "TOPLEFT", x, -82); s:SetWidth(w)
        local c = GRADE_COL[e[1]] or { 0.7, 0.7, 0.7 }
        s:SetColorTexture(c[1], c[2], c[3], 1); s:Show(); x = x + w
      else s:Hide() end
    end
    local lg = {}
    for _, e in ipairs(o.grades) do lg[#lg + 1] = (GRADE_HEX[e[1]] or "|cffffffff") .. e[1] .. "|r  " .. pct(e[2]) end
    b.legend:SetText(table.concat(lg, "      "))
    local pr = {}
    for k = #o.prints, 1, -1 do local e = o.prints[k]; pr[#pr + 1] = e[2] .. " " .. pct(e[3]) end
    pr[#pr + 1] = "|cffffd36bMythic 1 in " .. o.mythicOneIn .. "|r"
    b.prints:SetText(table.concat(pr, "   ·   "))
    local can = coins >= t.price
    b.price:SetText(GOLD .. t.price .. "|r coins"); b.price:SetTextColor(1, 0.9, 0.6)
    local w = RG.ArcadeReserveWorth(t.key)
    b.worth:SetText(w and ("sells back for about " .. w .. " coins\non a quiet day") or "")
    b.buy:SetText(can and ("Buy  ·  " .. t.price .. " coins") or ("Need " .. (t.price - coins) .. " more coins")); b.buy:SetEnabled(can)
  end
end

local function paintVault(view, a)
  local page = res.vault
  local d = page.det
  local day = RG.ArcadeMarketDay()
  local cases = RG.ArcadeGradeCases()
  local rows = {}
  for _, r in ipairs(cases) do
    local v0, v1 = RG.ArcadeGradeValueOn(r, day), RG.ArcadeGradeValueOn(r, day - 1)
    rows[#rows + 1] = { r = r, v = v0, chg = (v1 > 0) and (v0 / v1 - 1) or 0 }
  end
  table.sort(rows, function(x, y) if x.v ~= y.v then return x.v > y.v end return (x.r.cert or 0) < (y.r.cert or 0) end)
  local per = #page.rows
  local pages = math.max(1, math.ceil(#rows / per)); page.page = math.min(page.page, pages)
  page.list.h:SetText("YOUR CASES  ·  " .. #rows)
  -- the slab shown: the one picked, or the first
  local cur
  for _, e in ipairs(rows) do if e.r.id == sel.cert then cur = e end end
  if not cur then cur = rows[1]; sel.cert = cur and cur.r.id or nil end
  for i, b in ipairs(page.rows) do
    local e = rows[(page.page - 1) * per + i]
    if e then
      local r, c = e.r, cardOf(e.r.key)
      sealTex(b.seal, RG.ArcadeGradeSeal(r.grade)); b.g:SetText(r.grade)
      local pn = PRINT[r.f] or ""
      b.name:SetText((c and c.name or "?") .. "  |cffa89bc9" .. pn .. "|r")
      b.val:SetText(GOLD .. e.v .. "|r"); b.chg:SetText(signed(e.chg))
      local room = 176
      b.name:SetWidth(room)
      if RG.ArcadeFitLine then RG.ArcadeFitLine(b.name, room, 12, 8.5) end
      local need = b.name.GetUnboundedStringWidth and b.name:GetUnboundedStringWidth() or 0
      if need > room + 0.5 then b.name:SetText(c and c.name or "?"); if RG.ArcadeFitLine then RG.ArcadeFitLine(b.name, room, 12, 8) end end
      b.id = r.id; b.on = cur and cur.r.id == r.id or false
      b.bg:SetColorTexture(1, 0.85, 0.5, b.on and 0.18 or 0.06)
      b:Show()
    else b.id = nil; b:Hide() end
  end
  page.prev:SetShown(pages > 1); page.next:SetShown(pages > 1); page.pageT:SetText(pages > 1 and (page.page .. " / " .. pages) or "")
  page.prev:SetEnabled(page.page > 1); page.next:SetEnabled(page.page < pages)
  page.empty:SetShown(#rows == 0)
  page.empty:SetText(#rows == 0 and "No cases yet.\n\nBuy a Reserve pack, or send a card to the graders, and its case is kept here, with what it sells for today." or "")
  -- the slab
  local show = cur ~= nil
  for _, w in ipairs({ d.case, d.gname, d.info, d.today, d.chg, d.ch, d.chBase, d.sell, d.pin, d.open }) do w:SetShown(show) end
  for _, t in ipairs(d.bars) do t:SetShown(show) end
  for _, t in ipairs(d.barT) do t:SetShown(show) end
  d.none:SetShown(not show); d.none:SetText(show and "" or "Pick a case on the left to see its price and its week.")
  sel.rec = cur and cur.r or nil
  if not cur then return end
  local r = cur.r
  d.case:SetRec(r)
  local kind = RG.ArcadeGradeSeal(r.grade); local ink = SEAL_INK[kind] or SEAL_INK.bronze
  d.gname:SetText(string.upper(RG.ArcadeGradeName(r.grade)) .. " " .. r.grade); d.gname:SetTextColor(ink[1], ink[2], ink[3])
  local c = cardOf(r.key)
  local lines = { (PRINT[r.f] or "") .. " print" }
  lines[#lines + 1] = "Cert " .. string.format("%07d", r.cert or 0)
  if r.paid then lines[#lines + 1] = "Bought for " .. r.paid .. " coins" elseif r.res then lines[#lines + 1] = "From the Reserve" else lines[#lines + 1] = "Graded by you" end
  d.info:SetText(table.concat(lines, "\n"))
  d.today:SetText(GOLD .. cur.v .. "|r coins")
  local hi, lo = 0, math.huge
  local vals = {}
  for i = 1, 7 do vals[i] = RG.ArcadeGradeValueOn(r, day - (7 - i)); hi = math.max(hi, vals[i]); lo = math.min(lo, vals[i]) end
  d.chg:SetText("today " .. signed(cur.chg) .. "\nweek: " .. lo .. " to " .. hi)
  -- the chart: seven bars on a baseline, the highest as tall as the chart is
  local H = 46
  for i, t in ipairs(d.bars) do
    local span = hi - lo
    local h = (span <= 0) and (H * 0.6) or (8 + (H - 8) * (vals[i] - lo) / span)
    t:ClearAllPoints(); t:SetPoint("BOTTOMLEFT", d, "TOPLEFT", 14 + (i - 1) * 48, -369); t:SetHeight(math.max(2, h))
    if i == 7 then t:SetColorTexture(0.95, 0.78, 0.29, 1) else t:SetColorTexture(0.55, 0.42, 0.22, 1) end
  end
  d.sell:SetText("Sell back")
  d.sell:SetEnabled(RG.ArcadeGradeValid and RG.ArcadeGradeValid(r) and true or false)
end

local function paintMarket(a)
  local page = res.market
  local m = RG.ArcadeMarketToday()
  for i, r in ipairs(page.hotRows) do
    local e = m.hot[i]
    if e then r.name:SetText(e.label); r.why:SetText(e.reason); r.p:SetText(signed(e.pct)); r:Show() else r:Hide() end
  end
  for i, r in ipairs(page.coldRows) do
    local e = m.cold[i]
    if e then r.name:SetText(e.label); r.why:SetText(e.reason); r.p:SetText(signed(e.pct)); r:Show() else r:Hide() end
  end
  page.hot.h:SetText("HOT TODAY  ·  NEW PRICES IN " .. string.upper(timeLeft(m.secsLeft)))
  local t0, t1, n = RG.ArcadeVaultWorth()
  page.mine.big:SetText(t0 .. " coins")
  page.mine.chg:SetText(n > 0 and ("today " .. signed(t1 > 0 and (t0 / t1 - 1) or 0) .. " on yesterday") or "")
  local best
  for _, r in ipairs(RG.ArcadeGradeCases()) do
    local v0, v1 = RG.ArcadeGradeValueOn(r, m.day), RG.ArcadeGradeValueOn(r, m.day - 1)
    local ch = v1 > 0 and (v0 / v1 - 1) or 0
    if not best or ch > best.ch then best = { r = r, ch = ch } end
  end
  local c = best and cardOf(best.r.key)
  page.mine.txt:SetText(n == 0 and "You hold no cases yet." or (n .. " case" .. (n == 1 and "" or "s") .. " worth this today.\nBest today: " .. (c and c.name or "?") .. " " .. signed(best.ch)))
  page.mine.go:SetEnabled(n > 0)
  page.note.t:SetText("The guild prices every case once a day, the same for every player, from the date. A card's price drifts a little each day (never more than 10%); four themes are hot (15 to 30% more) and two are cooling (6 to 12% less). Nothing ever sells for less than 85% or more than 140% of its usual price, so waiting for a good day can pay, but not by much.")
end

local function paint(view, a)
  sel.tab = sel.tab or "packs"
  if sel.tab ~= "packs" and sel.tab ~= "vault" and sel.tab ~= "market" then sel.tab = "packs" end
  res.right:SetText("|cffffe08a" .. (a.coins or 0) .. "|r coins")
  for _, b in ipairs(res.tabs) do b:SetActive(b.key == sel.tab) end
  res.packs:SetShown(sel.tab == "packs"); res.vault:SetShown(sel.tab == "vault"); res.market:SetShown(sel.tab == "market")
  if sel.tab == "packs" then paintPacks(a)
  elseif sel.tab == "vault" then paintVault(view, a)
  else paintMarket(a) end
end

-- ---------------------------------------------------------------------------
-- The way in, and the page's place in the Shop
-- ---------------------------------------------------------------------------
RG.ArcadeViewHooks = RG.ArcadeViewHooks or {}
table.insert(RG.ArcadeViewHooks, function(view, ctx)
  local u = U()
  local frame = ctx.frame
  -- the button in the guild's banner (ArcadeGradingUI.lua builds the banner)
  local B = RG.ArcadeGradeBanner
  if B and not rawget(B, "resBtn") then
    B.resBtn = u.gbtn(B, "Guild Reserve", 118, 26, function() view.shopSection = "reserve"; sel.tab = sel.tab or "packs"; RG.ArcadeRefresh(true) end)
    B.resBtn:SetPoint("RIGHT", B.btn, "LEFT", -6, 0)
  end
  local on = view.mode == "shop" and view.shopSection == "reserve"
  if not res then if not on then return end; build(frame) end
  res:SetShown(on)
  if not on then return end
  local shop = RG.ArcadeShopFrame
  if shop then shop:Hide() end
  frame.prev:Hide(); frame.next:Hide(); frame.pageText:Hide()
  paint(view, ctx.a)
end)

-- open the Reserve (the Packs, Vault or Market view)
function RG.ArcadeReserveOpen(tab)
  if RG.ShowArcade then RG.ShowArcade() end
  local v = RG.ArcadeView
  if not v then if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end; v = RG.ArcadeView end
  if not v then return end
  v.mode = "shop"; v.shopSection = "reserve"
  if tab == "packs" or tab == "vault" or tab == "market" then sel.tab = tab end
  RG.ArcadeRefresh(true)
end
-- (for the text check: one view at a time)
function RG.ArcadeReserveTab(tab) sel.tab = tab end

do
  local base = SlashCmdList and SlashCmdList.WAYPATH
  if base then
    SlashCmdList.WAYPATH = function(msg)
      local cmd = (msg or ""):match("^%s*(%S+)")
      cmd = cmd and cmd:lower()
      if cmd == "reserve" then RG.ArcadeReserveOpen("packs") return end
      if cmd == "vault" then RG.ArcadeReserveOpen("vault") return end
      return base(msg)
    end
  end
end
