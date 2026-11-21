-- Waypath+ cards: the Shop tab (every pack in one place) and the sections the Sets tab and the Album are sorted into.
--   Shop: a storefront with the three regular packs in display cases and an aisle each for dungeons, raids and
--   holidays; an aisle lists its packs (ready to open, to buy, locked): open the ones you have, buy the ones you can,
--   and see how the others are earned.
--   Sections: Dungeons, Raids, Holidays, Field Guide and the Collection sets; the Sets tab shows one at a time and the
--   Album's < > step through the section of the page you're on.
local _, RG = ...

local function U() return RG.ArcadeUI end

-- ---------------------------------------------------------------------------
-- Sections
-- ---------------------------------------------------------------------------
local SECTIONS = {
  { "all", "All sets" }, { "dungeon", "Dungeons" }, { "raid", "Raids" }, { "holiday", "Holidays" }, { "field", "Field Guide" }, { "collection", "Collection" },
}
local TAG = {
  dungeon = "|cff8cc8ffDUNGEON|r  ", raid = "|cffd9a5ffRAID|r  ", holiday = "|cffff9fb0HOLIDAY|r  ", field = "|cff9fd8a0FIELD GUIDE|r  ",
}
function RG.ArcadeSetSection(s)
  if not s then return "collection" end
  if s.field then return "field" elseif s.holiday then return "holiday" elseif s.raid then return "raid" elseif s.dungeon then return "dungeon" end
  return "collection"
end
function RG.ArcadeSetTag(s) return TAG[RG.ArcadeSetSection(s)] or "" end
function RG.ArcadeSectionName(key) for _, e in ipairs(SECTIONS) do if e[1] == key then return e[2] end end return "All sets" end

-- ---------------------------------------------------------------------------
-- What the Shop lists
-- ---------------------------------------------------------------------------
local MON = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }
local function niceDay(t) local d = date and date("*t", t); return d and (d.day .. " " .. MON[d.month]) or "" end
local COL = { dungeon = { 0.55, 0.8, 1 }, raid = { 0.78, 0.5, 1 }, holiday = { 1, 0.55, 0.65 } }

-- each entry: { kind, title, sub, status, count, action label, enabled, act, art (1..3 or nil), col, album, tip, section }
local function entries(ctx, view)
  local a, P = ctx.a, ctx.PACKS
  local list = {}
  local coins = a.coins or 0
  -- the regular packs
  for i, k in ipairs(ctx.PACK_ORDER) do
    local n = ctx.tokens(k)
    local price = ctx.price(k)
    local def = P[k]
    list[#list + 1] = {
      section = "regular", title = def.name, art = i, count = n,
      sub = def.size .. " cards, from every card in the game. " .. (def.rares > 1 and ("The last " .. def.rares .. " are rare or better.") or "The last is rare or better."),
      status = n > 0 and ("|cff7be08a" .. n .. " to open|r") or (price .. " coins"),
      label = n > 0 and ("Open (" .. n .. ")") or ("Buy · " .. price), enabled = n > 0 or coins >= price,
      act = function() ctx.frame.buyNow(k) end, tipKind = k,
    }
  end
  -- dungeons, raids and holidays: each set with its own pack
  local u = U()
  for _, s in ipairs(u.getSets()) do
    if s.dungeon and not s.soon and RG.ArcadeDunPools and RG.ArcadeDunPools[s.name] then
      local sec = RG.ArcadeSetSection(s)
      local have, cleared = RG.ArcadeDungeonPacks(s.name)
      local e = { section = sec, title = s.name, count = have, col = COL[sec] or COL.dungeon, album = s.name, label = "", enabled = false }
      local price = P.dungeon.price
      if sec == "holiday" then
        local on, _, ends = RG.ArcadeHolidayActive and RG.ArcadeHolidayActive(RG.ARCADE_HOLIDAYS and (function() for _, d in ipairs(RG.ARCADE_HOLIDAYS) do if d[1] == s.name then return d end end end)())
        e.sub = "5 cards from " .. s.name .. " only, each stamped with the year. Earned by doing its quests while it's on; never sold."
        e.status = have > 0 and ("|cff7be08a" .. have .. " to open|r") or (on and ("|cff7be08aon now|r" .. (ends and (" until " .. niceDay(ends)) or "")) or "|cffa89bc9not on now|r")
        e.label = have > 0 and ("Open (" .. have .. ")") or "Earned only"
        e.enabled = have > 0
        e.order = on and 0 or 1
      else
        local raid = sec == "raid"
        local d
        for _, x in ipairs(RG.ARCADE_DUNGEONS or {}) do if x[1] == s.name then d = x end end
        local opens = raid and d and d.raid and d.raid.opens
        local notYet = opens and date and date("%Y-%m-%d") < opens
        e.sub = "5 cards from " .. s.name .. " only: " .. (raid and "its bosses, their loot, its elites." or "the place, its bosses, their drops and its elites.")
        if have > 0 then e.status = "|cff7be08a" .. have .. " to open|r"; e.label = "Open (" .. have .. ")"; e.enabled = true
        elseif cleared then e.status = coins >= price and (price .. " coins") or ("|cffa89bc9need " .. (price - coins) .. " more coins|r"); e.label = "Buy · " .. price; e.enabled = coins >= price; e.unlocked = true
        elseif notYet then
          local y, m, dd = opens:match("^(%d+)-(%d+)-(%d+)$")
          e.status = "|cffa89bc9opens " .. tonumber(dd) .. " " .. MON[tonumber(m)] .. "|r"; e.label = "Not open yet"
        else
          e.status = "|cffa89bc9" .. (raid and "defeat one of its bosses" or "clear it once") .. " to unlock|r"; e.label = "Locked"
        end
        e.order = have > 0 and 0 or (cleared and 1 or 2)
        e.lo = s.lo
      end
      e.act = function() ctx.frame.buyNow("dungeon", s.name) end
      list[#list + 1] = e
    end
  end
  return list
end

-- ---------------------------------------------------------------------------
-- The Shop: a storefront (the three regular packs in their display cases, and an aisle each for dungeons, raids
-- and holidays); an aisle opens a clean list of its packs, ready ones first, then the ones to buy, then the locked
-- ---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\Waypath\\Media\\Arcade\\"
local X0, PW = 34, 722                      -- the page's left edge and width in the window
local CW, CH, CG = 230, 248, 16             -- a display case
local AH = 154                              -- an aisle banner
local RH, RP, ROWS = 46, 50, 8              -- a list row, its pitch, rows a page
local AISLES = { { "dungeon", "Dungeons", "Dungeon packs" }, { "raid", "Raids", "Raid packs" }, { "holiday", "Holidays", "Holiday packs" } }
local PACKCOL = { { 0.62, 0.52, 1 }, { 1, 0.62, 0.28 }, { 0.3, 0.92, 0.82 } }
local shop, setChips

-- a place's picture in a round medallion: its painting, its loading screen (below the logo), or its first card's icon
local function medal(tex, title)
  local pl = RG.ARCADE_PLACE and RG.ARCADE_PLACE[title]
  local scr = RG.ARCADE_PLACE_FILE and RG.ARCADE_PLACE_FILE[title]
  if pl then
    local col, row = pl[2] % 8, math.floor(pl[2] / 8)
    tex:SetTexture(MEDIA .. "Places" .. pl[1])
    local x0, y0 = col * 120 / 1024, row * 84 / 1024
    pcall(tex.SetTexCoord, tex, x0 + 18 / 1024, x0 + 102 / 1024, y0, y0 + 84 / 1024); return true
  elseif scr then
    tex:SetTexture(scr[1])
    if scr[2] == 1 then pcall(tex.SetTexCoord, tex, 0.29, 0.71, 0.25, 1) else pcall(tex.SetTexCoord, tex, 0.22, 0.78, 0.25, 1) end
    return true
  end
  local u = U()
  for _, st in ipairs(u.getSets()) do
    if st.name == title and st.cards[1] then
      local ic = u.iconFor(st.cards[1])
      if ic then tex:SetTexture(ic); pcall(tex.SetTexCoord, tex, 0.08, 0.92, 0.08, 0.92); return true end
    end
  end
  return false
end
local function roundMask(parent, tex)
  pcall(function()
    local mk = parent:CreateMaskTexture(); mk:SetAllPoints(tex)
    mk:SetTexture("Interface\\AddOns\\Waypath\\Media\\Disc", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    tex:AddMaskTexture(mk)
  end)
end
-- a small foil pack tinted for its kind, with its place in the medallion
local function miniPack(parent, w, h)
  local p = CreateFrame("Frame", nil, parent); p:SetSize(w, h)
  p.body = p:CreateTexture(nil, "ARTWORK", nil, 0); p.body:SetAllPoints(); p.body:SetTexture(MEDIA .. "PackBody"); p.body:SetTexCoord(6 / 256, 250 / 256, 100 / 512, 468 / 512)
  p.trim = p:CreateTexture(nil, "ARTWORK", nil, 1); p.trim:SetAllPoints(); p.trim:SetTexture(MEDIA .. "PackTrim"); p.trim:SetTexCoord(6 / 256, 250 / 256, 100 / 512, 468 / 512)
  p.emb = p:CreateTexture(nil, "ARTWORK", nil, 2); p.emb:SetSize(w * 0.46, w * 0.46); p.emb:SetPoint("CENTER", p, "TOPLEFT", w / 2, -h * 0.415)
  roundMask(p, p.emb)
  return p
end
local function paintMini(p, title, col)
  p.body:SetVertexColor(col[1], col[2], col[3], 1)
  p.emb:SetShown(medal(p.emb, title))
end
local function badge(parent, u)
  local b = CreateFrame("Frame", nil, parent, "BackdropTemplate"); b:SetSize(24, 18)
  b:SetBackdrop({ bgFile = u.WHITE, edgeFile = u.WHITE, edgeSize = 1 }); b:SetBackdropColor(0.18, 0.5, 0.26, 1); b:SetBackdropBorderColor(0.6, 1, 0.68, 1)
  b.t = u.fs(b, "head", 11); b.t:SetPoint("CENTER", 0, 0); b.t:SetTextColor(1, 1, 1)
  return b
end
local function tip(self, e)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(e.title, 1, 0.93, 0.74)
  GameTooltip:AddLine(e.sub, 0.9, 0.9, 0.9, true)
  local o = RG.ArcadePackOdds and RG.ArcadePackOdds(e.tipKind or "dungeon", e.album)
  if o then GameTooltip:AddLine(string.format("Mythic 1 in %d packs   ·   holo or full art %d%%   ·   Gilded 1 in %d", o.mythic, math.floor(o.holo * 100 + 0.5), o.gilded or 0), 1, 0.9, 0.55) end
  if e.album then GameTooltip:AddLine("Click to see its cards in the Album", 0.6, 0.6, 0.6) end
  GameTooltip:Show()
end

-- one of the three regular packs, in its display case
local function makeCase(parent, u)
  local c = CreateFrame("Button", nil, parent); c:SetSize(CW, CH)
  c.bg = c:CreateTexture(nil, "BACKGROUND"); c.bg:SetAllPoints(); c.bg:SetTexture(MEDIA .. "ShopCase")
  c.glow = c:CreateTexture(nil, "BORDER"); c.glow:SetTexture(MEDIA .. "Glow"); c.glow:SetBlendMode("ADD"); c.glow:SetSize(220, 220); c.glow:SetPoint("CENTER", c, "BOTTOM", 0, 110)
  c.name = u.fs(c, "title", 15); c.name:SetPoint("TOP", 0, -18); c.name:SetTextColor(1, 0.94, 0.78)
  c.sub = u.fs(c, "body", 11); c.sub:SetPoint("TOP", c.name, "BOTTOM", 0, -3); c.sub:SetTextColor(0.86, 0.8, 0.86); c.sub:SetWidth(CW - 30)
  c.pack = c:CreateTexture(nil, "ARTWORK"); c.pack:SetSize(84, 127); c.pack:SetPoint("BOTTOM", c, "BOTTOM", 0, CH * 0.142)
  c.pack:SetTexCoord(6 / 256, 250 / 256, 100 / 512, 468 / 512)
  c.shadow = c:CreateTexture(nil, "BORDER", nil, 1); c.shadow:SetTexture(MEDIA .. "Soft"); c.shadow:SetVertexColor(0, 0, 0, 0.75); c.shadow:SetSize(120, 18); c.shadow:SetPoint("CENTER", c.pack, "BOTTOM", 0, 2)
  c.badge = badge(c, u); c.badge:SetPoint("CENTER", c.pack, "TOPRIGHT", -2, -4); c.badge:SetFrameLevel(c:GetFrameLevel() + 3)
  c.btn = u.gbtn(c, "", 150, 24, function() if c.entry and c.entry.enabled and c.entry.act then c.entry.act() end end)
  c.btn:SetPoint("BOTTOM", c, "BOTTOM", 0, 3)
  c:SetScript("OnEnter", function(self) self.glow:SetAlpha(0.75); if self.entry then tip(self, self.entry) end end)
  c:SetScript("OnLeave", function(self) self.glow:SetAlpha(0.45); GameTooltip:Hide() end)
  c:SetScript("OnClick", function(self) if self.entry and self.entry.enabled and self.entry.act then self.entry.act() end end)
  return c
end
local function paintCase(c, e)
  c.entry = e
  c.pack:SetTexture(MEDIA .. "PackArt" .. e.art)
  local col = PACKCOL[e.art] or { 1, 0.9, 0.6 }
  c.glow:SetVertexColor(col[1], col[2], col[3]); c.glow:SetAlpha(0.45)
  c.name:SetText(e.title)
  local def = e.def
  c.sub:SetText(def and (def.size .. " cards   ·   " .. (def.rares > 1 and ("last " .. def.rares .. " rare or better") or "last one rare or better")) or "")
  c.badge:SetShown((e.count or 0) > 0); c.badge.t:SetText(tostring(e.count or 0))
  c.btn:SetText(e.label or ""); c.btn:SetEnabled(e.enabled and true or false)
  c:Show()
end

-- an aisle: dungeons, raids or holidays, with three of its packs fanned out and how many are waiting
local function makeAisle(parent, u)
  local b = CreateFrame("Button", nil, parent); b:SetSize(CW, AH)
  b.bd = b:CreateTexture(nil, "BACKGROUND"); b.bd:SetPoint("TOPLEFT", 6, -6); b.bd:SetPoint("BOTTOMRIGHT", -6, 6)
  b.shade = b:CreateTexture(nil, "BACKGROUND", nil, 1); b.shade:SetPoint("TOPLEFT", 6, -6); b.shade:SetPoint("BOTTOMRIGHT", -6, 6)
  b.shade:SetColorTexture(0.03, 0.025, 0.04, 0.72)
  b.glow = b:CreateTexture(nil, "BORDER"); b.glow:SetTexture(MEDIA .. "Glow"); b.glow:SetBlendMode("ADD"); b.glow:SetSize(200, 200); b.glow:SetPoint("CENTER", b, "LEFT", 62, -8)
  b.frame = b:CreateTexture(nil, "OVERLAY"); b.frame:SetAllPoints(); b.frame:SetTexture(MEDIA .. "ShopFrame")
  b.packs = {}
  for i = 1, 3 do
    local p = miniPack(b, 44, 66); p:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 16 + (i - 1) * 26, 18 + (i == 2 and 10 or 0)); p:SetFrameLevel(b:GetFrameLevel() + (i == 2 and 3 or 1))
    b.packs[i] = p
  end
  b.title = u.fs(b, "title", 17); b.title:SetPoint("TOPLEFT", 18, -18); b.title:SetTextColor(1, 0.94, 0.78)
  b.line1 = u.fs(b, "head", 11); b.line1:SetPoint("TOPRIGHT", -16, -60); b.line1:SetWidth(120); b.line1:SetJustifyH("RIGHT")
  b.line2 = u.fs(b, "body", 11); b.line2:SetPoint("TOPRIGHT", b.line1, "BOTTOMRIGHT", 0, -4); b.line2:SetWidth(120); b.line2:SetJustifyH("RIGHT"); b.line2:SetTextColor(0.84, 0.8, 0.72)
  b.go = u.fs(b, "head", 11); b.go:SetPoint("BOTTOMRIGHT", -18, 16); b.go:SetText("BROWSE  >"); b.go:SetTextColor(1, 0.86, 0.5)
  b.badge = badge(b, u); b.badge:SetPoint("TOPRIGHT", -14, -14); b.badge:SetFrameLevel(b:GetFrameLevel() + 5)
  b:SetScript("OnEnter", function(self) self.glow:SetAlpha(0.7); self.shade:SetColorTexture(0.03, 0.025, 0.04, 0.6) end)
  b:SetScript("OnLeave", function(self) self.glow:SetAlpha(0.4); self.shade:SetColorTexture(0.03, 0.025, 0.04, 0.72) end)
  return b
end
local function paintAisle(b, key, title, list, ctx)
  local col = COL[key]
  b.key = key
  b.title:SetText(string.upper(title))
  b.glow:SetVertexColor(col[1], col[2], col[3]); b.glow:SetAlpha(0.4)
  local ready, open, locked, onNow, onUntil = 0, 0, 0, nil, nil
  for _, e in ipairs(list) do
    ready = ready + (e.count or 0)
    local unl = e.enabled or e.unlocked
    if unl and (e.count or 0) == 0 then open = open + 1 elseif not unl and (e.count or 0) == 0 then locked = locked + 1 end
    if key == "holiday" and e.order == 0 and not onNow then onNow = e.title end
  end
  -- the banner's picture: a place in this aisle with a loading screen (one with packs waiting first)
  local pick
  for _, e in ipairs(list) do if RG.ARCADE_PLACE_FILE and RG.ARCADE_PLACE_FILE[e.title] and (not pick or ((e.count or 0) > 0 and (pick.count or 0) == 0)) then pick = e end end
  local scr = pick and RG.ARCADE_PLACE_FILE[pick.title]
  if scr then
    b.bd:SetTexture(scr[1]); b.bd:SetVertexColor(1, 1, 1, 1)
    -- (cut to the banner's shape, below the logo at the top of the loading screen)
    local have = ((scr[2] == 1) and 16 / 9 or 4 / 3) / 0.78
    local want = (CW - 12) / (AH - 12)
    if have > want then local cut = (1 - want / have) / 2; b.bd:SetTexCoord(cut, 1 - cut, 0.22, 1) else b.bd:SetTexCoord(0, 1, 0.22, 1) end
  else b.bd:SetColorTexture(col[1] * 0.25, col[2] * 0.25, col[3] * 0.25, 1) end
  for i, p in ipairs(b.packs) do
    local e = list[i]
    if e then paintMini(p, e.title, col); p:Show() else p:Hide() end
  end
  b.badge:SetShown(ready > 0); b.badge.t:SetText(tostring(ready))
  if ready > 0 then b.line1:SetText("|cff7be08a" .. ready .. " TO OPEN|r")
  elseif key == "holiday" then b.line1:SetText(onNow and "|cff7be08aON NOW|r" or "|cffa89bc9NONE ON NOW|r")
  else b.line1:SetText(open > 0 and ("|cffe8c46a" .. open .. " UNLOCKED|r") or "|cffa89bc9ALL LOCKED|r") end
  if key == "holiday" then b.line2:SetText(onNow and onNow or (#list .. " holidays\nearned while on"))
  else b.line2:SetText(#list .. " " .. (key == "raid" and "raids" or "dungeons") .. (locked > 0 and ("\n" .. locked .. " still locked") or "\nall unlocked")) end
  b:Show()
end

-- a row in an aisle's list
local function makeRow(parent, u)
  local r = CreateFrame("Button", nil, parent, "BackdropTemplate"); r:SetSize(PW, RH)
  r:SetBackdrop({ bgFile = u.WHITE, edgeFile = u.WHITE, edgeSize = 1 }); r:SetBackdropColor(0.07, 0.062, 0.05, 0.96); r:SetBackdropBorderColor(0.3, 0.25, 0.16, 0.8)
  r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetPoint("TOPLEFT", 1, -1); r.bar:SetPoint("BOTTOMLEFT", 1, 1); r.bar:SetWidth(3)
  r.pack = miniPack(r, 26, 40); r.pack:SetPoint("LEFT", 12, 0)
  r.badge = badge(r, u); r.badge:SetSize(20, 15); r.badge:SetPoint("CENTER", r.pack, "TOPRIGHT", 2, -2); r.badge:SetFrameLevel(r:GetFrameLevel() + 4)
  r.name = u.fs(r, "head", 13); r.name:SetPoint("TOPLEFT", 50, -8); r.name:SetTextColor(1, 0.94, 0.78)
  r.sub = u.fs(r, "body", 11); r.sub:SetPoint("BOTTOMLEFT", 50, 8); r.sub:SetTextColor(0.78, 0.74, 0.66)
  r.status = u.fs(r, "body", 12); r.status:SetPoint("RIGHT", -142, 0); r.status:SetJustifyH("RIGHT")
  r.btn = u.gbtn(r, "", 120, 24, function() if r.entry and r.entry.enabled and r.entry.act then r.entry.act() end end); r.btn:SetPoint("RIGHT", -10, 0)
  r.head = u.fs(r, "head", 10.5); r.head:SetPoint("LEFT", 6, 0); r.head:SetTextColor(0.85, 0.72, 0.42)
  r:SetScript("OnClick", function(self) if self.entry and self.entry.album and RG.ArcadeOpenAlbum then RG.ArcadeOpenAlbum(self.entry.album) end end)
  r:SetScript("OnEnter", function(self) if self.entry then self:SetBackdropBorderColor(1, 0.84, 0.45, 1); tip(self, self.entry) end end)
  r:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.3, 0.25, 0.16, 0.8); GameTooltip:Hide() end)
  return r
end
local function paintRow(r, e, sec)
  r.entry = e.header and nil or e
  local isHead = e.header and true or false
  for _, w in ipairs({ r.pack, r.badge, r.name, r.sub, r.status, r.btn, r.bar }) do w:SetShown(not isHead) end
  r.head:SetShown(isHead)
  if isHead then
    r:SetHeight(22); r:SetBackdropColor(0, 0, 0, 0); r:SetBackdropBorderColor(0, 0, 0, 0)
    r.head:SetText(e.header); r:Show(); return
  end
  r:SetHeight(RH); r:SetBackdropColor(0.07, 0.062, 0.05, 0.96); r:SetBackdropBorderColor(0.3, 0.25, 0.16, 0.8)
  paintMini(r.pack, e.title, e.col or COL.dungeon)
  r.badge:SetShown((e.count or 0) > 0); r.badge.t:SetText(tostring(e.count or 0))
  r.name:SetText(e.title)
  local bits = {}
  local sets = U().getSets()
  for _, st in ipairs(sets) do
    if st.name == e.title then
      if st.lo then bits[#bits + 1] = (st.lo == st.hi) and ("level " .. st.lo) or ("levels " .. st.lo .. "-" .. st.hi) end
      bits[#bits + 1] = #st.cards .. " cards"
      if RG.ArcadeSetHeart then local h = RG.ArcadeSetHeart(st); if h ~= "" then bits[#bits + 1] = "heart found" .. h end end
      break
    end
  end
  r.sub:SetText(table.concat(bits, "   ·   "))
  local ready, buy = (e.count or 0) > 0, (e.enabled or e.unlocked) and (e.count or 0) == 0
  r.status:SetText((ready or (buy and e.enabled)) and "" or (e.status or ""))   -- (the button already says "Open (2)" or "Buy · 70")
  local c = ready and { 0.48, 0.88, 0.54 } or (buy and { 0.91, 0.77, 0.42 } or { 0.4, 0.38, 0.46 })
  r.bar:SetColorTexture(c[1], c[2], c[3], 1)
  r.btn:SetText(e.label or ""); r.btn:SetEnabled(e.enabled and true or false)
  r:SetAlpha((ready or buy) and 1 or 0.78)
  r:Show()
end

local function chipRow(u, frame, list, onPick)
  local row = {}
  local x = 34
  for _, c in ipairs(list) do
    local w = math.max(60, 32 + #c[2] * 8.5)   -- (the chips use capitals: room for the widest letters)
    local b = u.gbtn(frame, c[2], w, 24, function() onPick(c[1]) end)
    b:SetPoint("TOPLEFT", x, -160); x = x + w + 6
    b.key = c[1]
    row[#row + 1] = b
  end
  return row
end

local function waitingCount(ctx)
  local n = 0
  for _, k in ipairs(ctx.PACK_ORDER) do n = n + ctx.tokens(k) end
  for _, v in pairs(ctx.a.dpk or {}) do n = n + (v or 0) end
  return n
end

local function buildShop(frame, u, view)
  shop = CreateFrame("Frame", nil, frame); shop:SetAllPoints(frame); shop:SetFrameLevel((frame:GetFrameLevel() or 1) + 4)
  shop.head = u.fs(shop, "title", 15); shop.head:SetPoint("TOPLEFT", X0, -160); shop.head:SetTextColor(1, 0.92, 0.7)
  shop.right = u.fs(shop, "body", 12); shop.right:SetPoint("TOPRIGHT", shop, "TOPRIGHT", -X0, -163); shop.right:SetJustifyH("RIGHT"); shop.right:SetTextColor(0.85, 0.78, 0.6)
  shop.line = shop:CreateTexture(nil, "ARTWORK"); shop.line:SetColorTexture(0.72, 0.58, 0.3, 0.45); shop.line:SetHeight(1)
  shop.line:SetPoint("TOPLEFT", X0, -184); shop.line:SetPoint("TOPRIGHT", -X0, -184)
  shop.back = u.gbtn(shop, "<  Shop", 78, 24, function() view.shopSection = nil; view.shopPage = 0; RG.ArcadeRefresh(true) end)
  shop.back:SetPoint("TOPLEFT", X0, -156)
  shop.cases, shop.aisles, shop.rows = {}, {}, {}
  for i = 1, 3 do
    local c = makeCase(shop, u); c:SetPoint("TOPLEFT", shop, "TOPLEFT", X0 + (i - 1) * (CW + CG), -240); shop.cases[i] = c
    local b = makeAisle(shop, u); b:SetPoint("TOPLEFT", shop, "TOPLEFT", X0 + (i - 1) * (CW + CG), -500); shop.aisles[i] = b
    b:SetScript("OnClick", function(self) view.shopSection = self.key; view.shopPage = 0; RG.ArcadeRefresh(true) end)
  end
  for i = 1, ROWS + 3 do shop.rows[i] = makeRow(shop, u) end
  shop.empty = u.fs(shop, "body", 14); shop.empty:SetPoint("TOP", 0, -260); shop.empty:SetTextColor(0.6, 0.58, 0.69)
  RG.ArcadeShopFrame = shop
end

RG.ArcadeViewHooks = RG.ArcadeViewHooks or {}
table.insert(RG.ArcadeViewHooks, function(view, ctx)
  local u = U(); local frame = ctx.frame
  -- the Shop tab says how many packs are waiting
  local t = frame.modes and frame.modes.shop
  if t and t.label then local n = waitingCount(ctx); t.label:SetText(n > 0 and ("SHOP  |cff7be08a" .. n .. "|r") or "SHOP") end

  -- the Sets tab's section chips
  if not setChips then
    setChips = chipRow(u, frame, SECTIONS, function(k) view.setSection = k; view.setPage = 0; RG.ArcadeRefresh(true) end)
  end
  for _, b in ipairs(setChips) do b:SetShown(view.mode == "sets"); b:SetActive(b.key == (view.setSection or "all")) end

  if not shop then buildShop(frame, u, view) end
  local on = view.mode == "shop"
  shop:SetShown(on)
  if not on then return end

  local n = waitingCount(ctx)
  shop.right:SetText((n > 0 and ("|cff7be08a" .. n .. " pack" .. (n == 1 and "" or "s") .. " to open|r     ") or "") .. "|cffffe08a" .. (ctx.a.coins or 0) .. "|r coins")
  -- (the dungeons' pools are built the first time anything needs them: the odds do that)
  if not (RG.ArcadeDunPools and next(RG.ArcadeDunPools)) and RG.ArcadePackOdds then pcall(RG.ArcadePackOdds, "normal") end
  local all = entries(ctx, view)
  local sec = view.shopSection
  if sec == "grading" then shop:Hide(); return end   -- (the grading desk: ArcadeGradingUI.lua)
  if sec ~= "dungeon" and sec ~= "raid" and sec ~= "holiday" then sec = nil; view.shopSection = nil end
  for _, r in ipairs(shop.rows) do r:Hide() end
  shop.empty:SetText("")

  if not sec then
    -- the storefront
    shop.back:Hide(); shop.head:ClearAllPoints(); shop.head:SetPoint("TOPLEFT", X0, -160); shop.head:SetText("THE PACK SHOP")
    for i, k in ipairs(ctx.PACK_ORDER) do
      for _, e in ipairs(all) do if e.section == "regular" and e.tipKind == k then e.def = ctx.PACKS[k]; pcall(paintCase, shop.cases[i], e) end end
    end
    for i, ai in ipairs(AISLES) do
      local list = {}
      for _, e in ipairs(all) do if e.section == ai[1] then list[#list + 1] = e end end
      table.sort(list, function(x, y)
        local wx, wy = (x.count or 0) > 0, (y.count or 0) > 0
        if wx ~= wy then return wx end
        if (x.order or 0) ~= (y.order or 0) then return (x.order or 0) < (y.order or 0) end
        if (x.lo or 0) ~= (y.lo or 0) then return (x.lo or 0) < (y.lo or 0) end
        return x.title < y.title
      end)
      local ok, err = pcall(paintAisle, shop.aisles[i], ai[1], ai[2], list, ctx)
      if not ok then shop.aisles[i]:Hide(); if RG.RecordError then RG.RecordError(err) end end
    end
    frame.prev:Hide(); frame.next:Hide(); frame.pageText:Hide()
    return
  end

  -- an aisle: its packs, ready to open first, then to buy, then locked (a header over each group)
  for _, c in ipairs(shop.cases) do c:Hide() end
  for _, b in ipairs(shop.aisles) do b:Hide() end
  shop.back:Show(); shop.head:ClearAllPoints(); shop.head:SetPoint("LEFT", shop.back, "RIGHT", 14, 0)
  local name = sec == "raid" and "RAID PACKS" or (sec == "holiday" and "HOLIDAY PACKS" or "DUNGEON PACKS")
  shop.head:SetText(name)
  local groups = { {}, {}, {} }
  for _, e in ipairs(all) do
    if e.section == sec then
      local g = (e.count or 0) > 0 and 1 or ((e.enabled or e.unlocked) and 2 or 3)
      local gl = groups[g]; gl[#gl + 1] = e
    end
  end
  for _, gl in ipairs(groups) do
    table.sort(gl, function(x, y)
      if (x.order or 0) ~= (y.order or 0) then return (x.order or 0) < (y.order or 0) end
      if (x.lo or 0) ~= (y.lo or 0) then return (x.lo or 0) < (y.lo or 0) end
      return x.title < y.title
    end)
  end
  local HEADS = { "READY TO OPEN", sec == "holiday" and "ON NOW" or "TO BUY", sec == "holiday" and "EARNED WHILE THEY'RE ON" or "LOCKED" }
  local list = {}
  for g, gl in ipairs(groups) do
    if #gl > 0 then list[#list + 1] = { header = HEADS[g] .. "   ·   " .. #gl }; for _, e in ipairs(gl) do list[#list + 1] = e end end
  end
  -- pages by height: a header row is short
  local pages, cur, used = {}, {}, 0
  local LIMIT = ROWS * RP
  local lastHead
  for _, e in ipairs(list) do
    if e.header then lastHead = e.header end
    local h = e.header and 26 or RP
    if used + h > LIMIT and #cur > 0 then
      pages[#pages + 1] = cur; cur, used = {}, 0
      -- (a group that runs onto the next page keeps its header there)
      if not e.header and lastHead then cur[1] = { header = lastHead:gsub("   ·   %d+$", "") .. "   ·   continued" }; used = 26 end
    end
    cur[#cur + 1] = e; used = used + h
  end
  if #cur > 0 then pages[#pages + 1] = cur end
  local np = math.max(1, #pages)
  local pg = math.max(0, math.min(view.shopPage or 0, np - 1)); view.shopPage = pg
  local y = -194
  for i, e in ipairs(pages[pg + 1] or {}) do
    local r = shop.rows[i]
    if r then
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", shop, "TOPLEFT", X0, y)
      local ok, err = pcall(paintRow, r, e, sec)
      if not ok then r:Hide(); if RG.RecordError then RG.RecordError(err) end end
      y = y - (e.header and 26 or RP)
    end
  end
  if #list == 0 then shop.empty:SetText("Nothing here yet.") end
  frame.prev:SetShown(np > 1); frame.next:SetShown(np > 1); frame.pageText:SetShown(np > 1)
  if np > 1 then
    frame.pageText:SetText((pg + 1) .. " / " .. np)
    frame.prev:SetEnabled(pg > 0); frame.next:SetEnabled(pg + 1 < np)
  end
end)
