-- Waypath+ cards: the Shop tab (every pack in one place) and the sections the Sets tab and the Album are sorted into.
--   Shop: packs waiting to be opened first, then the regular packs, then each dungeon's, raid's and holiday's pack:
--   open the ones you have, buy the ones you can, and see how the others are earned. Chips pick one kind.
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
        elseif cleared then e.status = price .. " coins"; e.label = "Buy · " .. price; e.enabled = coins >= price
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

local CHIPS = { { "all", "All" }, { "waiting", "To open" }, { "regular", "Regular" }, { "dungeon", "Dungeons" }, { "raid", "Raids" }, { "holiday", "Holidays" } }
local function filtered(ctx, view)
  local all = entries(ctx, view)
  local sec = view.shopSection or "all"
  local out = {}
  for _, e in ipairs(all) do
    if sec == "all" or (sec == "waiting" and (e.count or 0) > 0) or e.section == sec then out[#out + 1] = e end
  end
  local rank = { regular = 0, dungeon = 1, raid = 2, holiday = 3 }
  table.sort(out, function(x, y)
    local wx, wy = (x.count or 0) > 0, (y.count or 0) > 0
    if wx ~= wy then return wx end                                  -- packs to open first
    if x.section ~= y.section then return (rank[x.section] or 9) < (rank[y.section] or 9) end
    if (x.order or 0) ~= (y.order or 0) then return (x.order or 0) < (y.order or 0) end   -- (unlocked before locked)
    if (x.lo or 0) ~= (y.lo or 0) then return (x.lo or 0) < (y.lo or 0) end
    return (x.art or 9) < (y.art or 9) or ((x.art or 9) == (y.art or 9) and x.title < y.title)
  end)
  return out, all
end

-- ---------------------------------------------------------------------------
-- The Shop page: chips, then a grid of pack tiles
-- ---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\Waypath\\Media\\Arcade\\"
local COLS, ROWS, TW, TH, GX, GY = 3, 3, 228, 124, 14, 12
local shop, chips, setChips

local function makeTile(parent, u)
  local t = CreateFrame("Button", nil, parent, "BackdropTemplate")
  t:SetSize(TW, TH)
  t:SetBackdrop({ bgFile = u.WHITE, edgeFile = u.WHITE, edgeSize = 1 })
  t:SetBackdropColor(0.07, 0.062, 0.048, 0.96); t:SetBackdropBorderColor(0.45, 0.37, 0.22, 0.75)
  t.glow = t:CreateTexture(nil, "BACKGROUND", nil, 1); t.glow:SetTexture(MEDIA .. "Soft"); t.glow:SetBlendMode("ADD")
  t.glow:SetPoint("TOPLEFT", 2, -2); t.glow:SetSize(96, TH - 4); t.glow:SetAlpha(0.35)
  -- the pack: its own wrapper art, or the plain foil tinted for a dungeon, raid or holiday, with the name on it
  t.pack = CreateFrame("Frame", nil, t); t.pack:SetSize(58, 88); t.pack:SetPoint("LEFT", 12, 0)
  t.body = t.pack:CreateTexture(nil, "ARTWORK", nil, 0); t.body:SetAllPoints(); t.body:SetTexCoord(6 / 256, 250 / 256, 100 / 512, 468 / 512)
  t.trim = t.pack:CreateTexture(nil, "ARTWORK", nil, 1); t.trim:SetAllPoints(); t.trim:SetTexture(MEDIA .. "PackTrim"); t.trim:SetTexCoord(6 / 256, 250 / 256, 100 / 512, 468 / 512)
  t.packName = u.fs(t.pack, "head", 7.5); t.packName:SetPoint("CENTER", 0, -4); t.packName:SetWidth(52); t.packName:SetJustifyH("CENTER")
  t.packName:SetTextColor(1, 0.96, 0.85); t.packName:SetShadowColor(0, 0, 0, 1); t.packName:SetShadowOffset(1, -1)
  t.badge = CreateFrame("Frame", nil, t, "BackdropTemplate"); t.badge:SetSize(24, 18); t.badge:SetPoint("TOPRIGHT", t.pack, "TOPRIGHT", 8, 6)
  t.badge:SetBackdrop({ bgFile = u.WHITE, edgeFile = u.WHITE, edgeSize = 1 }); t.badge:SetBackdropColor(0.18, 0.5, 0.26, 1); t.badge:SetBackdropBorderColor(0.6, 1, 0.68, 1)
  t.badge:SetFrameLevel(t.pack:GetFrameLevel() + 3)
  t.badgeText = u.fs(t.badge, "head", 11); t.badgeText:SetPoint("CENTER", 0, 0); t.badgeText:SetTextColor(1, 1, 1)
  t.title = u.fs(t, "head", 13.5); t.title:SetPoint("TOPLEFT", 84, -10); t.title:SetWidth(TW - 94); t.title:SetJustifyH("LEFT")
  if t.title.SetMaxLines then t.title:SetMaxLines(2) end   -- (a long dungeon name takes two lines)
  t.tag = u.fs(t, "head", 9.5); t.tag:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -3)
  t.status = u.fs(t, "body", 12); t.status:SetPoint("TOPLEFT", t.tag, "BOTTOMLEFT", 0, -4); t.status:SetWidth(TW - 94); t.status:SetJustifyH("LEFT")
  t.btn = u.gbtn(t, "Open", 126, 24, function() if t.entry and t.entry.enabled and t.entry.act then t.entry.act() end end)
  t.btn:SetPoint("BOTTOMRIGHT", -10, 10)
  -- the tile itself opens the set's Album page; hovering says what's in the pack and how it's earned
  t:SetScript("OnClick", function() if t.entry and t.entry.album and RG.ArcadeOpenAlbum then RG.ArcadeOpenAlbum(t.entry.album) end end)
  t:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(1, 0.84, 0.45, 1)
    local e = self.entry; if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.title, 1, 0.93, 0.74)
    GameTooltip:AddLine(e.sub, 0.9, 0.9, 0.9, true)
    local o = RG.ArcadePackOdds and RG.ArcadePackOdds(e.tipKind or "dungeon")
    if o then GameTooltip:AddLine(string.format("Mythic 1 in %d packs   ·   holo or full art %d%%", o.mythic, math.floor(o.holo * 100 + 0.5)), 1, 0.9, 0.55) end
    if e.album then GameTooltip:AddLine("Click the tile to see its cards in the Album", 0.6, 0.6, 0.6) end
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.45, 0.37, 0.22, 0.75); GameTooltip:Hide() end)
  return t
end

local function paintTile(t, e)
  t.entry = e
  if e.art then
    t.body:SetTexture(MEDIA .. "PackArt" .. e.art); t.body:SetVertexColor(1, 1, 1, 1); t.trim:Hide(); t.packName:SetText("")
    local c = ({ { 0.62, 0.52, 1 }, { 1, 0.62, 0.28 }, { 0.3, 0.92, 0.82 } })[e.art]
    t.glow:SetVertexColor(c[1], c[2], c[3])
  else
    local c = e.col or COL.dungeon
    t.body:SetTexture(MEDIA .. "PackBody"); t.body:SetVertexColor(c[1], c[2], c[3], 1); t.trim:Show()
    t.packName:SetText("")   -- (the tint says which kind; the name is beside it)
    t.glow:SetVertexColor(c[1], c[2], c[3])
  end
  t.badge:SetShown((e.count or 0) > 0); t.badgeText:SetText(tostring(e.count or 0))
  t.title:SetText(e.title)
  local tags = { regular = "|cffe8d5a8EVERY CARD|r", dungeon = "|cff8cc8ffDUNGEON PACK|r", raid = "|cffd9a5ffRAID PACK|r", holiday = "|cffff9fb0HOLIDAY PACK|r" }
  t.tag:SetText(tags[e.section] or "")
  t.status:SetText(e.status or "")
  t.btn:SetText(e.label or ""); t.btn:SetEnabled(e.enabled and true or false)
  t:SetAlpha((e.enabled or (e.count or 0) > 0) and 1 or 0.72)
  t:Show()
end

local function chipRow(u, frame, list, onPick)
  local row = {}
  local x = 34
  for _, c in ipairs(list) do
    local w = math.max(56, 24 + #c[2] * 7.5)
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

  -- the Shop
  if not shop then
    shop = CreateFrame("Frame", nil, frame); shop:SetAllPoints(frame); shop:SetFrameLevel((frame:GetFrameLevel() or 1) + 4)
    shop.tiles = {}
    local x0 = (790 - (COLS * TW + (COLS - 1) * GX)) / 2
    for i = 1, COLS * ROWS do
      local tl = makeTile(shop, u)
      tl:SetPoint("TOPLEFT", shop, "TOPLEFT", x0 + ((i - 1) % COLS) * (TW + GX), -228 - math.floor((i - 1) / COLS) * (TH + GY))
      shop.tiles[i] = tl
    end
    shop.head = u.fs(shop, "head", 12.5); shop.head:SetPoint("TOPLEFT", x0, -200); shop.head:SetTextColor(u.GOLDC[1], u.GOLDC[2], u.GOLDC[3])
    shop.right = u.fs(shop, "body", 12); shop.right:SetPoint("TOPRIGHT", shop, "TOPRIGHT", -x0, -201); shop.right:SetJustifyH("RIGHT"); shop.right:SetTextColor(0.769, 0.687, 0.522)
    shop.line = shop:CreateTexture(nil, "ARTWORK"); shop.line:SetColorTexture(0.72, 0.58, 0.3, 0.4); shop.line:SetHeight(1)
    shop.line:SetPoint("TOPLEFT", x0, -218); shop.line:SetPoint("TOPRIGHT", -x0, -218)
    shop.empty = u.fs(shop, "body", 14); shop.empty:SetPoint("TOP", 0, -260); shop.empty:SetTextColor(0.6, 0.58, 0.69)
    chips = chipRow(u, frame, CHIPS, function(k) view.shopSection = k; view.shopPage = 0; RG.ArcadeRefresh(true) end)
  end
  local on = view.mode == "shop"
  shop:SetShown(on)
  for _, b in ipairs(chips) do b:SetShown(on); b:SetActive(b.key == (view.shopSection or "all")) end
  if not on then return end

  local list = filtered(ctx, view)
  local per = COLS * ROWS
  local pages = math.max(1, math.ceil(#list / per))
  local pg = math.max(0, math.min(view.shopPage or 0, pages - 1)); view.shopPage = pg
  for i, tl in ipairs(shop.tiles) do
    local e = list[pg * per + i]
    if e then paintTile(tl, e) else tl:Hide(); tl.entry = nil end
  end
  local n = waitingCount(ctx)
  local secName = ({ all = "Every pack", waiting = "Packs to open", regular = "Regular packs", dungeon = "Dungeon packs", raid = "Raid packs", holiday = "Holiday packs" })[view.shopSection or "all"]
  shop.head:SetText(string.upper(secName))
  shop.right:SetText((n > 0 and ("|cff7be08a" .. n .. " pack" .. (n == 1 and "" or "s") .. " to open|r   ·   ") or "") .. (ctx.a.coins or 0) .. " coins")
  shop.empty:SetText(#list == 0 and ((view.shopSection == "waiting") and "No packs waiting. Earn them by playing, or buy one." or "Nothing here yet.") or "")
  frame.prev:SetShown(pages > 1); frame.next:SetShown(pages > 1); frame.pageText:SetShown(pages > 1)
  if pages > 1 then
    frame.pageText:SetText((pg + 1) .. " / " .. pages)
    frame.prev:SetEnabled(pg > 0); frame.next:SetEnabled(pg + 1 < pages)
  end
end)
