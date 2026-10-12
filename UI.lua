-- RetGear window. Holy/Retribution look: dark glass panel, gold trim, card
-- rows with item-quality borders, status pills and progress bars.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY

-- ---------------------------------------------------------------------------
-- Theme
-- ---------------------------------------------------------------------------
local T = {
  bg      = { 0.035, 0.035, 0.045, 0.97 },
  panel   = { 1, 1, 1, 0.035 },
  edge    = { 1, 1, 1, 0.08 },
  gold    = { 0.83, 0.71, 0.42 },
  goldDim = { 0.54, 0.45, 0.26 },
  green   = { 0.31, 0.68, 0.48 },
  red     = { 0.84, 0.38, 0.31 },
  purple  = { 0.65, 0.55, 0.85 },
  blue    = { 0.44, 0.66, 0.86 },
  text    = { 0.96, 0.96, 0.95 },
  dim     = { 0.56, 0.56, 0.55 },
}
local FONT_TITLE = "Fonts\\MORPHEUS.TTF"
local FONT_BODY  = "Fonts\\FRIZQT__.TTF"
local FONT_NUM   = "Fonts\\ARIALN.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local W, H = 680, 600
-- Text size: 1.0 = original, saved per account. A- / A+ in the header change it.
local function TS() return (RG.db and RG.db.textSize) or 1.2 end
local function sz(n) return math.floor(n * TS() + 0.5) end
local GAP = 4
local function ROW_H() return sz(48) end
local function HEAD_H() return sz(30) end
local function SUB_H() return sz(34) end
local function BAR_H() return sz(44) end

local frame, scroll, content, tabs, footer, sectionTitle
local rows = {}
local state = { tab = "route", near = true, open = {} }

local function backdrop(f, bg, edge)
  if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropColor(unpack(bg)); f:SetBackdropBorderColor(unpack(edge))
end
local function font(fs, path, size, flags) fs:SetFont(path, size, flags or "") end
local function gradient(tex, orient, a, b)
  if tex.SetGradient and CreateColor then tex:SetGradient(orient, CreateColor(unpack(a)), CreateColor(unpack(b)))
  elseif tex.SetGradientAlpha then tex:SetGradientAlpha(orient, unpack(a), unpack(b)) end
end

local function itemIcon(id)
  local _, _, _, _, icon = (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(id)
  return icon or 134400
end
local function itemName(id)
  local name, link, quality = RG.ItemInfo(id)
  if not name then RG.RequestItem(id); return GREY .. "Loading item " .. id .. "...|r", nil, nil end
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
  return (c and c.hex or "|cffffffff") .. name .. "|r", link, quality
end

-- Pick a pill color from the first color code in a status string.
local function pillKind(s)
  if not s or s == "" then return nil end
  if s:find(GREEN, 1, true) then return "green" end
  if s:find(GOLD, 1, true) then return "gold" end
  if s:find(RED, 1, true) then return "red" end
  return "muted"
end
local PILL = {
  green = { bg = { 0.31, 0.68, 0.48, 0.14 }, edge = { 0.31, 0.68, 0.48, 0.55 } },
  gold  = { bg = { 0.83, 0.71, 0.42, 0.14 }, edge = { 0.83, 0.71, 0.42, 0.55 } },
  red   = { bg = { 0.84, 0.38, 0.31, 0.14 }, edge = { 0.84, 0.38, 0.31, 0.55 } },
  muted = { bg = { 1, 1, 1, 0.04 },          edge = { 1, 1, 1, 0.12 } },
}

-- ---------------------------------------------------------------------------
-- Rows: header, item card, sub-row (indented quest) and progress bar
-- ---------------------------------------------------------------------------
local function getRow(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Button", nil, content, "BackdropTemplate")
  r:SetWidth(W - 56)
  r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetAllPoints(); r.hl:SetColorTexture(T.gold[1], T.gold[2], T.gold[3], 0.07)

  -- accent stripe on the left edge (current zone, equipped, etc.)
  r.stripe = r:CreateTexture(nil, "ARTWORK"); r.stripe:SetPoint("TOPLEFT", 0, 0); r.stripe:SetPoint("BOTTOMLEFT", 0, 0); r.stripe:SetWidth(2)

  -- icon with a quality-colored border
  r.iconBorder = r:CreateTexture(nil, "ARTWORK"); r.iconBorder:SetSize(32, 32); r.iconBorder:SetPoint("LEFT", 8, 0)
  r.icon = r:CreateTexture(nil, "OVERLAY"); r.icon:SetPoint("TOPLEFT", r.iconBorder, 1, -1); r.icon:SetPoint("BOTTOMRIGHT", r.iconBorder, -1, 1)
  r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  r.title = r:CreateFontString(nil, "OVERLAY"); font(r.title, FONT_BODY, 12)
  r.title:SetPoint("TOPLEFT", r.iconBorder, "TOPRIGHT", 10, -2); r.title:SetJustifyH("LEFT"); r.title:SetWordWrap(false)
  r.sub = r:CreateFontString(nil, "OVERLAY"); font(r.sub, FONT_NUM, 12); r.sub:SetTextColor(unpack(T.dim))
  r.sub:SetPoint("BOTTOMLEFT", r.iconBorder, "BOTTOMRIGHT", 10, 1); r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)

  -- status pill (top right) and meta text (bottom right)
  r.pill = CreateFrame("Frame", nil, r, "BackdropTemplate"); r.pill:SetHeight(18); r.pill:SetPoint("TOPRIGHT", -10, -6)
  r.pillText = r.pill:CreateFontString(nil, "OVERLAY"); font(r.pillText, FONT_NUM, 11); r.pillText:SetPoint("CENTER", 0, 0)
  r.meta = r:CreateFontString(nil, "OVERLAY"); font(r.meta, FONT_NUM, 11); r.meta:SetPoint("BOTTOMRIGHT", -12, 6); r.meta:SetJustifyH("RIGHT")

  -- section header pieces
  r.head = r:CreateFontString(nil, "OVERLAY"); font(r.head, FONT_BODY, 11); r.head:SetPoint("BOTTOMLEFT", 2, 7); r.head:SetTextColor(unpack(T.gold))
  r.headLine = r:CreateTexture(nil, "ARTWORK"); r.headLine:SetHeight(1); r.headLine:SetPoint("LEFT", r.head, "RIGHT", 10, 0); r.headLine:SetPoint("RIGHT", r, "RIGHT", 0, 0)
  r.headLine:SetColorTexture(T.gold[1], T.gold[2], T.gold[3], 0.25)

  -- progress bar pieces
  r.barBg = r:CreateTexture(nil, "ARTWORK"); r.barBg:SetHeight(8); r.barBg:SetPoint("BOTTOMLEFT", 12, 10); r.barBg:SetPoint("BOTTOMRIGHT", -12, 10); r.barBg:SetColorTexture(1, 1, 1, 0.07)
  r.barFill = r:CreateTexture(nil, "OVERLAY"); r.barFill:SetHeight(8); r.barFill:SetPoint("LEFT", r.barBg, "LEFT", 0, 0); r.barFill:SetTexture(WHITE)
  r.barMark = r:CreateTexture(nil, "OVERLAY"); r.barMark:SetSize(2, 14); r.barMark:SetColorTexture(1, 1, 1, 0.8)
  r.barLabel = r:CreateFontString(nil, "OVERLAY"); font(r.barLabel, FONT_BODY, 12); r.barLabel:SetPoint("TOPLEFT", 12, -7)
  r.barValue = r:CreateFontString(nil, "OVERLAY"); font(r.barValue, FONT_NUM, 13); r.barValue:SetPoint("TOPRIGHT", -12, -7)

  r:RegisterForClicks("AnyUp")
  r:SetScript("OnEnter", function(self)
    if self.tip then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(self.tip, 1, 1, 1, 1, true); GameTooltip:Show(); return end
    if not self.itemID and not self.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.link then GameTooltip:SetHyperlink(self.link) else GameTooltip:SetItemByID(self.itemID) end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r:SetScript("OnClick", function(self)
    if self.onClick then self.onClick(self); return end
    local link = self.link or (self.itemID and select(2, RG.ItemInfo(self.itemID)))
    if not link then return end
    local insert = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
    if IsModifiedClick("CHATLINK") and insert then insert(link)
    elseif IsModifiedClick("DRESSUP") and DressUpItemLink then DressUpItemLink(link) end
  end)
  rows[i] = r
  return r
end

local function hideAll(r)
  r.onClick = nil; r.tip = nil
  r.title:SetWordWrap(false)
  for _, k in ipairs({ "iconBorder", "icon", "title", "sub", "pill", "meta", "head", "headLine", "barBg", "barFill", "barMark", "barLabel", "barValue", "stripe" }) do r[k]:Hide() end
end

local function setHeader(r, text)
  hideAll(r); r.itemID, r.link = nil, nil
  r.kind, r.h = "head", HEAD_H()
  font(r.head, FONT_BODY, sz(11))
  r:SetBackdrop(nil); r.hl:Hide()
  r.head:SetText(text:upper()); r.head:Show(); r.headLine:Show()
  r:Show()
end

-- accent: "gold" | "green" | "purple" | nil  ·  quality: item quality for the icon border
local function setItem(r, id, link, title, sub, right, right2, accent, quality, small)
  hideAll(r); r.itemID, r.link = id, link
  r.kind, r.h = small and "sub" or "item", small and SUB_H() or ROW_H()
  backdrop(r, small and { 1, 1, 1, 0.018 } or T.panel, accent == "gold" and { T.gold[1], T.gold[2], T.gold[3], 0.45 } or T.edge)
  r.hl:Show()
  local size = small and sz(22) or sz(32)
  r.iconBorder:SetSize(size, size)
  r.iconBorder:ClearAllPoints(); r.iconBorder:SetPoint("LEFT", small and 34 or 8, 0)
  r.iconBorder:Show(); r.icon:Show()
  r.icon:SetTexture(id and itemIcon(id) or 134400); r.icon:SetDesaturated(false)
  r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); r.icon:SetVertexColor(1, 1, 1, 1)
  local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  if qc then r.iconBorder:SetColorTexture(qc.r, qc.g, qc.b, 0.9) else r.iconBorder:SetColorTexture(1, 1, 1, 0.15) end
  font(r.title, FONT_BODY, small and sz(11.5) or sz(13))
  font(r.sub, FONT_NUM, small and sz(11.5) or sz(12.5))
  font(r.pillText, FONT_NUM, sz(11)); font(r.meta, FONT_NUM, sz(11))
  r.pill:SetHeight(sz(18))
  r.title:SetText(title or ""); r.title:Show()
  r.title:ClearAllPoints()
  if small then r.title:SetPoint("LEFT", r.iconBorder, "RIGHT", 10, sz(6)); r.sub:ClearAllPoints(); r.sub:SetPoint("LEFT", r.iconBorder, "RIGHT", 10, -sz(7))
  else r.title:SetPoint("TOPLEFT", r.iconBorder, "TOPRIGHT", 10, -2); r.sub:ClearAllPoints(); r.sub:SetPoint("BOTTOMLEFT", r.iconBorder, "BOTTOMRIGHT", 10, 1) end
  r.sub:SetText(sub or ""); r.sub:Show()
  -- pill
  local kind = pillKind(right)
  if kind then
    r.pillText:SetText(right); r.pill:SetWidth(r.pillText:GetStringWidth() + 18)
    backdrop(r.pill, PILL[kind].bg, PILL[kind].edge)
    r.pill:ClearAllPoints(); r.pill:SetPoint(small and "RIGHT" or "TOPRIGHT", -10, small and 0 or -6)
    r.pill:Show()
  end
  if right2 and right2 ~= "" and not small then r.meta:SetText(right2); r.meta:Show() end
  if small and right2 and right2 ~= "" and not kind then r.meta:SetText(right2); r.meta:ClearAllPoints(); r.meta:SetPoint("RIGHT", -12, 0); r.meta:Show() end
  -- keep titles clear of the right column
  local rightW = math.max(kind and r.pill:GetWidth() or 0, r.meta:IsShown() and r.meta:GetStringWidth() or 0)
  local leftX = (small and 34 or 8) + size + 10
  r.title:SetWidth(math.max(120, (W - 56) - leftX - rightW - 26))
  r.sub:SetWidth(math.max(120, (W - 56) - leftX - (r.meta:IsShown() and r.meta:GetStringWidth() or 0) - 26))
  if accent then
    local c = accent == "green" and T.green or (accent == "purple" and T.purple or (accent == "blue" and T.blue or T.gold))
    r.stripe:SetColorTexture(c[1], c[2], c[3], 0.9); r.stripe:Show()
  end
  r:Show()
end

-- Progress bar row: label, value/max, optional marker (e.g. the hit cap)
local function setBar(r, label, value, max, color, valueText, mark)
  hideAll(r); r.itemID, r.link = nil, nil
  r.kind, r.h = "bar", BAR_H()
  font(r.barLabel, FONT_BODY, sz(12)); font(r.barValue, FONT_NUM, sz(13))
  backdrop(r, T.panel, T.edge); r.hl:Hide()
  r.barLabel:SetText(label); r.barLabel:Show()
  r.barValue:SetText(valueText or ""); r.barValue:Show()
  r.barBg:Show()
  local width = (W - 56) - 24
  local pct = max > 0 and math.min(1, value / max) or 0
  r.barFill:SetWidth(math.max(1, width * pct)); r.barFill:SetVertexColor(color[1], color[2], color[3], 0.95); r.barFill:Show()
  if mark and max > 0 then
    r.barMark:ClearAllPoints(); r.barMark:SetPoint("CENTER", r.barBg, "LEFT", width * math.min(1, mark / max), 0); r.barMark:Show()
  end
  r:Show()
end

-- A numbered to-do line under a route step. Wraps long text; click to tick it off.
local function setStep(r, num, text, done, onClick, auto)
  hideAll(r); r.itemID, r.link = nil, nil
  r.kind = "step"
  backdrop(r, { 1, 1, 1, done and 0.012 or 0.025 }, { 1, 1, 1, 0.06 })
  r.hl:Show()
  local box = sz(16)
  r.iconBorder:SetSize(box, box); r.iconBorder:ClearAllPoints(); r.iconBorder:SetPoint("TOPLEFT", 34, -sz(9))
  local bc = auto and T.green or T.gold
  r.iconBorder:SetColorTexture(bc[1], bc[2], bc[3], done and 0.9 or 0.35); r.iconBorder:Show()
  r.icon:SetTexture(done and "Interface\\Buttons\\UI-CheckBox-Check" or WHITE); r.icon:SetTexCoord(0, 1, 0, 1)
  if done then r.icon:SetVertexColor(1, 1, 1, 1) else r.icon:SetVertexColor(0.05, 0.05, 0.06, 1) end
  r.icon:Show()
  font(r.title, FONT_NUM, sz(13))
  r.title:ClearAllPoints(); r.title:SetPoint("TOPLEFT", r.iconBorder, "TOPRIGHT", 10, 1)
  r.title:SetWidth((W - 56) - 34 - box - 10 - 18)
  r.title:SetWordWrap(true)
  r.title:SetText((done and GREY or "|cffffffff") .. num .. ".  " .. text .. "|r"); r.title:Show()
  local th = r.title.GetStringHeight and r.title:GetStringHeight() or sz(14)
  r.h = math.max(sz(32), (th or sz(14)) + sz(16))
  r.onClick = onClick
  if auto then r.tip = "Done: " .. auto .. "\n|cff8E8E8C(detected from your game)|r"
  elseif done then r.tip = "Ticked by you. Click to untick." else r.tip = "Click to tick this off." end
  r:Show()
end

-- ---------------------------------------------------------------------------
-- Tabs
-- ---------------------------------------------------------------------------
local function guideRows()
  local list, lvl = {}, UnitLevel("player")
  local brackets = { { 1, 19, "Levels 1-19" }, { 20, 29, "Levels 20-29" }, { 30, 39, "Levels 30-39" }, { 40, 49, "Levels 40-49" }, { 50, 57, "Levels 50-57" }, { 58, 60, "Levels 58-60 · pre-raid" } }
  for _, b in ipairs(brackets) do
    local items = {}
    for _, g in ipairs(RG.GUIDE) do
      if g.lvl >= b[1] and g.lvl <= b[2] and (not state.near or (g.lvl <= lvl + 6 and g.lvl >= lvl - 12)) then items[#items + 1] = g end
    end
    if #items > 0 then
      list[#list + 1] = { header = b[3] }
      for _, g in ipairs(items) do list[#list + 1] = { g = g } end
    end
  end
  return list
end

local function renderGuide()
  local list = guideRows()
  local lvl = UnitLevel("player")
  if #list == 0 then list = { { header = "Nothing near your level · untick Near my level" } } end
  for i, e in ipairs(list) do
    local r = getRow(i)
    if e.header then setHeader(r, e.header)
    elseif e.g.tip then
      setItem(r, nil, nil, GOLD .. "Tip|r" .. GREY .. "  ·  level " .. e.g.lvl .. "|r", e.g.text, "", "", "gold")
      r.icon:SetTexture(135920)
    else
      local g = e.g
      local name, link, quality = itemName(g.id)
      local own = RG.OwnState(g.id)
      local d = link and RG.GuideDelta(g)
      local right, accent
      if own == "equipped" then right = GREEN .. "Equipped|r"; accent = "green"
      elseif own == "owned" then right = GOLD .. "In your bags|r"
      elseif g.bs and (RG.Skill("Blacksmithing") or 0) < g.bs then
        local sk = RG.Skill("Blacksmithing")
        right = GREY .. "Smithing " .. g.bs .. (sk and (" · you " .. sk) or "") .. "|r"
      elseif g.lvl > lvl then right = GREY .. "Level " .. (g.approx and "~" or "") .. g.lvl .. "|r"
      elseif d then
        if d > 0.5 then right = GREEN .. "Upgrade " .. string.format("+%.0f", d) .. "|r"; accent = "gold"
        else right = GREY .. "Not an upgrade|r" end
      else right = GREY .. "Loading|r" end
      local right2 = g.ah and RG.PriceText(g.id) or (GREY .. g.how .. "|r")
      if g.bs and (RG.Skill("Blacksmithing") or 0) >= g.bs and not own then right2 = GREEN .. "You can make this|r" end
      setItem(r, g.id, link, name .. GREY .. "   " .. g.slot .. "  ·  lvl " .. (g.approx and "~" or "") .. g.lvl .. "|r", g.src .. GREY .. "  ·  " .. g.zone .. "|r", right, right2, accent, quality)
    end
  end
  return #list
end

local SLOT_GUIDE = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [7] = "Legs", [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket", [15] = "Back", [16] = "2H" }
local function renderGear()
  local n, total = 0, 0
  local hit, cap = RG.CurrentHit(), RG.db.hitCap
  -- summary bars first
  n = n + 1; local scoreRow = getRow(n)
  n = n + 1
  setBar(getRow(n), "Hit chance", math.min(hit, cap), cap, hit >= cap and T.green or T.gold, string.format("%s%.0f%%|r / %d%% cap", hit >= cap and GREEN or "|cffffffff", hit, cap))
  n = n + 1; setHeader(getRow(n), "Equipped")
  local lvl = UnitLevel("player")
  for _, slot in ipairs(RG.SLOT_ORDER) do
    local link = GetInventoryItemLink("player", slot)
    n = n + 1
    local r = getRow(n)
    local score = link and RG.Score(link) or 0
    total = total + score
    local nextUp
    for _, g in ipairs(RG.GUIDE) do
      if g.id and SLOT_GUIDE[slot] == g.slot and g.lvl <= lvl + 6 and not RG.OwnState(g.id) then
        local d = RG.GuideDelta(g)
        if d and d > 0.5 and (not nextUp or g.lvl < nextUp.g.lvl) then nextUp = { g = g, d = d } end
      end
    end
    local id = link and tonumber(link:match("item:(%d+)"))
    local quality = link and select(3, RG.ItemInfo(link))
    local sub = RG.SLOT_NAMES[slot]
    if nextUp then
      local nm = RG.ItemInfo(nextUp.g.id) or ("item " .. nextUp.g.id)
      sub = sub .. GREY .. "  ·  next: |r" .. nm .. GREY .. " · " .. nextUp.g.zone .. "|r"
    end
    setItem(r, id, link, link or (GREY .. "Empty slot|r"), sub, nextUp and (GREEN .. "Upgrade +" .. string.format("%.0f", nextUp.d) .. "|r") or "", string.format("%s%.0f|r", GOLD, score), nil, quality)
    if not link then r.icon:SetTexture(136516); r.icon:SetDesaturated(true) else r.icon:SetDesaturated(false) end
  end
  setBar(scoreRow, "Ret gear score", total, math.max(total, 1), T.gold, string.format("%s%.0f|r", GOLD, total))
  return n
end

local function renderProf()
  local prof = RG.Professions()
  local mining, bs = prof["Mining"], prof["Blacksmithing"]
  local n = 0
  local function head(t) n = n + 1; setHeader(getRow(n), t) end
  local function line(id, title, sub, right, right2, icon, accent, quality)
    n = n + 1; local r = getRow(n)
    local link = id and select(2, RG.ItemInfo(id))
    setItem(r, id, link, title, sub, right, right2, accent, quality)
    if icon then r.icon:SetTexture(icon) end
  end
  n = n + 1; setBar(getRow(n), "Mining", mining and mining.rank or 0, mining and math.max(mining.max, 1) or 300, T.gold, mining and (mining.rank .. " / " .. mining.max) or (GREY .. "Not learned|r"))
  n = n + 1; setBar(getRow(n), "Blacksmithing", bs and bs.rank or 0, bs and math.max(bs.max, 1) or 300, { 0.85, 0.55, 0.3 }, bs and (bs.rank .. " / " .. bs.max) or (GREY .. "Not learned|r"))
  head("Where to mine · Horde side")
  local skill = mining and mining.rank or 0
  for _, m in ipairs(RG.MINING) do
    local here = skill >= m.from and skill <= m.to
    local done = skill > m.to
    line(nil, (here and GOLD or (done and GREY or "|cffffffff")) .. m.ore .. "|r" .. GREY .. "   skill " .. m.from .. "-" .. m.to .. "|r", m.zones,
      here and (GREEN .. "Mine here now|r") or (done and (GREY .. "Done|r") or ""), "", 136248, here and "gold" or nil)
  end
  head("Blacksmithing upgrades for Ret")
  local lvl = UnitLevel("player")
  for _, g in ipairs(RG.GUIDE) do
    if g.bs then
      local name, link, quality = itemName(g.id)
      local can = bs and bs.rank >= g.bs
      local d = link and RG.GuideDelta(g)
      local own = RG.OwnState(g.id)
      local right = own == "equipped" and (GREEN .. "Equipped|r") or (can and (GREEN .. "You can make this|r") or (GREY .. "Needs " .. g.bs .. "|r"))
      local right2 = (g.lvl > lvl and (GREY .. "Wear at " .. g.lvl .. "|r")) or (d and d > 0.5 and (GREEN .. "Upgrade +" .. string.format("%.0f", d) .. "|r")) or ""
      line(g.id, name .. GREY .. "   " .. g.slot .. "  ·  lvl " .. g.lvl .. "|r", g.src .. GREY .. "  ·  " .. g.zone .. "|r", right, right2, nil, can and not own and "green" or nil, quality)
    end
  end
  head("Ore and bar prices · lowest buyout")
  for _, id in ipairs(RG.MATS) do
    local nm2, _, quality = itemName(id)
    local cnt = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, true)) or 0
    line(id, nm2, cnt > 0 and ("You have " .. cnt) or (GREY .. "None in your bags|r"), "", RG.PriceText(id) or (GREY .. "not seen yet|r"), nil, nil, quality)
  end
  return n
end

local function renderRoute()
  local lvl = UnitLevel("player")
  local mining = RG.Skill("Mining") or 0
  local n, lastBracket = 0, nil
  local KIND = { zone = GREY .. "Questing|r", dungeon = "|cffA58BD8Dungeon|r", pala = GOLD .. "Paladin|r", travel = "|cff6FA8DCTravel|r" }
  local ICON = { zone = 134269, dungeon = 136058, pala = 135920, travel = "Interface\\Icons\\Ability_Mount_Wyvern_01" }
  local list = {}
  for i, r in ipairs(RG.ROUTE) do list[i] = r end
  for _, t in ipairs(RG.TRAVEL or {}) do list[#list + 1] = { from = t.lvl, to = t.lvl, kind = "travel", zone = "Travel", hub = "", notes = t.text, fp = t.fp, travel = true } end
  local ORDER = { pala = 0, travel = 1, zone = 2, dungeon = 3 }
  table.sort(list, function(a, b) if a.from ~= b.from then return a.from < b.from end return (ORDER[a.kind] or 9) < (ORDER[b.kind] or 9) end)
  for _, r in ipairs(list) do
    if not state.near or (r.to >= lvl - 3 and r.from <= lvl + 12) then
      local bracket = r.from < 10 and "Levels 1-9" or ("Levels " .. (math.floor(r.from / 10) * 10) .. "-" .. (math.floor(r.from / 10) * 10 + 9))
      if r.from >= 60 then bracket = "Level 60" end
      if bracket ~= lastBracket then n = n + 1; setHeader(getRow(n), bracket); lastBracket = bracket end
      n = n + 1
      local row = getRow(n)
      local now = lvl >= r.from and lvl <= r.to
      local past = lvl > r.to
      local col = now and GOLD or (past and GREY or "|cffffffff")
      local ore = ""
      for _, m in ipairs(RG.MINING) do
        if m.zones:find(r.zone, 1, true) and mining >= m.from - 25 then ore = ore .. (ore == "" and "" or ", ") .. m.ore end
      end
      local sub = (r.notes ~= "" and r.notes or r.hub)
      if ore ~= "" then sub = sub .. GREY .. "  ·  Ore: " .. ore .. "|r" end
      local fpPill
      if r.fp then
        local k = RG.KnowsFP(r.fp)
        if k == true then fpPill = GREEN .. "Flight path learned|r"
        elseif k == false then fpPill = GOLD .. "Grab the " .. r.fp .. " flight path|r"
        else fpPill = GREY .. "Flight path: " .. r.fp .. "|r" end
      end
      local range = r.from == r.to and ("Level " .. r.from) or ("Levels " .. r.from .. "-" .. r.to)
      local dq = r.kind == "dungeon" and RG.DUNGEON_QUESTS[r.zone]
      local status = now and (GREEN .. "You are here|r") or (GREY .. range .. "|r")
      local accent = now and "gold" or (r.kind == "pala" and "gold" or (r.kind == "dungeon" and "purple" or (r.kind == "travel" and "blue" or nil)))
      if r.kind == "travel" then
        status = fpPill or (now and (GREEN .. "Now|r") or (GREY .. "Level " .. r.from .. "|r"))
      elseif fpPill and (now or lvl >= r.from - 1) and not past then
        status = (now and RG.KnowsFP(r.fp) == false) and fpPill or status
        sub = sub .. "  ·  " .. fpPill
      end
      if dq then
        if lvl >= dq.prep and lvl < dq.go then status = GOLD .. "Collect quests now|r"
        elseif lvl >= dq.go and lvl <= r.to then status = GREEN .. "Go now|r" end
        sub = "Head over at level " .. dq.go .. GREY .. "  ·  " .. (dq.note or r.notes) .. "|r"
      end
      local titleText = r.kind == "travel" and ("|cff6FA8DC" .. "Travel" .. "|r" .. GREY .. "   level " .. r.from .. "|r") or (col .. r.zone .. "|r" .. GREY .. (r.kind == "pala" and "" or ("   " .. r.hub)) .. "|r")
      local key = r.zone .. "|" .. r.from
      local steps = RG.STEPS and RG.STEPS[key]
      local open = steps and ((state.open[key] == nil and now) or state.open[key] == true)
      local meta = KIND[r.kind] or ""
      RG.db.stepsDone = RG.db.stepsDone or {}
      local doneN, autoMap = 0, {}
      if steps then
        for i, text in ipairs(steps) do
          local ok, why = RG.StepAuto and RG.StepAuto(r, text)
          if ok then autoMap[i] = why end
          if ok or RG.db.stepsDone[key .. "#" .. i] or past then doneN = doneN + 1 end
        end
        meta = meta .. GREY .. "   ·   " .. doneN .. "/" .. #steps .. (open and "  ·  hide" or "") .. "|r"
        if doneN == #steps and not now then status = GREEN .. "Done|r" end
      end
      setItem(row, nil, nil, titleText, sub, status, meta, accent)
      if steps then row.onClick = function() state.open[key] = not open; RG.RefreshUI() end end
      row.icon:SetTexture(ICON[r.kind] or 134269)
      if open then
        RG.db.stepsDone = RG.db.stepsDone or {}
        for i, text in ipairs(steps) do
          n = n + 1
          local sk = key .. "#" .. i
          local auto = autoMap[i]
          setStep(getRow(n), i, text, auto or RG.db.stepsDone[sk] or past, function()
            RG.db.stepsDone[sk] = not RG.db.stepsDone[sk] or nil
            RG.RefreshUI()
          end, auto or (past and not RG.db.stepsDone[sk] and "you've outleveled this part of the route" or nil))
        end
      end
      if dq and lvl <= r.to and (lvl >= dq.prep - 4 or not state.near) then
        for _, q in ipairs(dq.quests) do
          n = n + 1
          local qr = getRow(n)
          local qs = RG.QuestState and RG.QuestState((q[1]:gsub("%s*%(.-%)$", "")))
          local pill = qs == "done" and (GREEN .. "Done|r") or (qs == "ready" and (GREEN .. "Ready to turn in|r") or (qs == "log" and (GOLD .. "In your log|r") or ""))
          setItem(qr, nil, nil, (qs == "done" and GREY or "|cffffd100") .. q[1] .. "|r", q[2] .. GREY .. "  ·  " .. q[3] .. "|r", pill, pill == "" and (GREY .. "Quest|r") or "", qs == "done" and "green" or nil, nil, true)
          qr.icon:SetTexture(136797)
        end
      end
    end
  end
  if n == 0 then n = 1; setHeader(getRow(1), "Untick Near my level to see the whole route") end
  return n
end

local function renderAH()
  local ids = RG.TrackedIDs()
  table.sort(ids, function(a, b) local ga, gb = RG.GuideByID[a], RG.GuideByID[b]; return (ga and ga.lvl or 99) < (gb and gb.lvl or 99) end)
  local n = 0
  local gear, mats = {}, {}
  for _, id in ipairs(ids) do if RG.GuideByID[id] or RG.db.tracked[id] then gear[#gear + 1] = id else mats[#mats + 1] = id end end
  local function block(title, list)
    if #list == 0 then return end
    n = n + 1; setHeader(getRow(n), title)
    for _, id in ipairs(list) do
      n = n + 1
      local r = getRow(n)
      local name, link, quality = itemName(id)
      local g = RG.GuideByID[id]
      local alert = RG.db.alerts and RG.db.alerts[id]
      local sub = g and (g.src .. GREY .. "  ·  level " .. g.lvl .. "|r") or (GREY .. "Tracked by you|r")
      if alert then sub = sub .. GREY .. "  ·  alert at |r" .. RG.Money(alert) end
      setItem(r, id, link, name, sub, alert and (GOLD .. "Alert set|r") or "", RG.PriceText(id) or (GREY .. "not seen yet|r"), nil, quality)
    end
  end
  block("Gear you can buy", gear)
  block("Ore and bars", mats)
  if n == 0 then n = 1; setHeader(getRow(1), "Nothing tracked yet · /rg track [item link]") end
  return n
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------
local TITLES = {
  route = { "Leveling route", "Undead Horde path from Deathknell to 60" },
  guide = { "Gear guide", "Ret upgrades by level, and where they come from" },
  gear  = { "My gear", "What you're wearing and what to chase next" },
  prof  = { "Professions", "Mining routes, smithing upgrades and material prices" },
  ah    = { "Auction House", "Lowest buyout from your last scan" },
}
local FOOTERS = {
  route = "Click a step to open its to-do list  ·  click a task to tick it off  ·  A- / A+ change the text size",
  guide = "Shift-click to link  ·  Ctrl-click to preview  ·  green means better than what you wear",
  gear  = "Scores are Attack Power equivalents  ·  tune them with /rg weight",
  prof  = "Ore and bar prices refresh when you open the Auction House",
  ah    = "Opening the AH refreshes prices  ·  /rg alert [item] 25 pings you at 25g or less",
}

local function updateHeader()
  local lvl = UnitLevel("player")
  local p = RG.Professions()
  local bits = { "Level " .. lvl, "Undead Retribution" }
  if p["Mining"] then bits[#bits + 1] = "Mining " .. p["Mining"].rank end
  if p["Blacksmithing"] then bits[#bits + 1] = "Blacksmithing " .. p["Blacksmithing"].rank end
  frame.subtitle:SetText(table.concat(bits, "   ·   "))
  local xp, max = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
  if max and max > 0 and lvl < (GetMaxPlayerLevel and GetMaxPlayerLevel() or 60) then
    frame.xpFill:SetWidth(math.max(1, (W - 2) * xp / max)); frame.xpFill:Show()
    frame.xpText:SetText(string.format("%d%% to %d", math.floor(xp / max * 100), lvl + 1))
  else
    frame.xpFill:SetWidth(W - 2); frame.xpText:SetText("Max level")
  end
end

function RG.RefreshUI()
  if not frame or not frame:IsShown() then return end
  for _, r in ipairs(rows) do r:Hide() end
  updateHeader()
  local n
  if state.tab == "guide" then n = renderGuide()
  elseif state.tab == "gear" then n = renderGear()
  elseif state.tab == "route" then n = renderRoute()
  elseif state.tab == "prof" then n = renderProf()
  else n = renderAH() end
  sectionTitle:SetText(TITLES[state.tab][1]); frame.sectionSub:SetText(TITLES[state.tab][2])
  footer:SetText(FOOTERS[state.tab])
  frame.near:SetShown(state.tab == "guide" or state.tab == "route")
  frame.scan:SetShown(state.tab == "ah")
  -- stack rows with their own heights
  local y = 0
  for i = 1, n do
    local r = rows[i]
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetHeight(r.h or ROW_H())
    y = y + (r.h or ROW_H()) + GAP
  end
  content:SetHeight(math.max(1, y))
  for k, b in pairs(tabs) do
    local on = k == state.tab
    b.text:SetTextColor(unpack(on and T.gold or T.dim)); b.underline:SetShown(on)
  end
end

local function flatButton(parent, text, w)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, 24)
  backdrop(b, { 1, 1, 1, 0.05 }, { T.gold[1], T.gold[2], T.gold[3], 0.45 })
  b.text = b:CreateFontString(nil, "OVERLAY"); font(b.text, FONT_BODY, 11); b.text:SetPoint("CENTER"); b.text:SetText(text); b.text:SetTextColor(unpack(T.gold))
  b:SetScript("OnEnter", function(self) self:SetBackdropColor(T.gold[1], T.gold[2], T.gold[3], 0.15) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 1, 1, 0.05) end)
  return b
end

local function build()
  frame = CreateFrame("Frame", "RetGearFrame", UIParent, "BackdropTemplate")
  frame:SetSize(W, H); frame:SetPoint("CENTER")
  backdrop(frame, T.bg, { T.goldDim[1], T.goldDim[2], T.goldDim[3], 0.9 })
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true); frame:SetFrameStrata("HIGH")
  tinsert(UISpecialFrames, "RetGearFrame")

  -- soft holy glow across the top
  local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  glow:SetPoint("TOPLEFT", 1, -1); glow:SetPoint("TOPRIGHT", -1, -1); glow:SetHeight(110); glow:SetTexture(WHITE)
  gradient(glow, "VERTICAL", { T.gold[1], T.gold[2], T.gold[3], 0 }, { T.gold[1], T.gold[2], T.gold[3], 0.13 })

  -- crest icon
  local crestBorder = frame:CreateTexture(nil, "ARTWORK"); crestBorder:SetSize(46, 46); crestBorder:SetPoint("TOPLEFT", 16, -14); crestBorder:SetColorTexture(T.gold[1], T.gold[2], T.gold[3], 0.9)
  local crest = frame:CreateTexture(nil, "OVERLAY"); crest:SetPoint("TOPLEFT", crestBorder, 2, -2); crest:SetPoint("BOTTOMRIGHT", crestBorder, -2, 2)
  crest:SetTexture("Interface\\Icons\\Spell_Holy_AuraOfLight"); crest:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  local title = frame:CreateFontString(nil, "OVERLAY"); font(title, FONT_TITLE, 26); title:SetPoint("TOPLEFT", crestBorder, "TOPRIGHT", 12, 2)
  title:SetText("RetGear"); title:SetTextColor(unpack(T.gold)); title:SetShadowColor(0, 0, 0, 1); title:SetShadowOffset(1, -1)
  frame.subtitle = frame:CreateFontString(nil, "OVERLAY"); font(frame.subtitle, FONT_NUM, 12); frame.subtitle:SetPoint("BOTTOMLEFT", crestBorder, "BOTTOMRIGHT", 12, 2); frame.subtitle:SetTextColor(unpack(T.dim))

  local close = CreateFrame("Button", nil, frame)
  close:SetSize(28, 28); close:SetPoint("TOPRIGHT", -10, -10)
  close.t = close:CreateFontString(nil, "OVERLAY"); font(close.t, FONT_NUM, 18); close.t:SetPoint("CENTER"); close.t:SetText("x"); close.t:SetTextColor(unpack(T.dim))
  close:SetScript("OnEnter", function(self) self.t:SetTextColor(unpack(T.gold)) end)
  close:SetScript("OnLeave", function(self) self.t:SetTextColor(unpack(T.dim)) end)
  close:SetScript("OnClick", function() frame:Hide() end)
  local function sizeBtn(label, delta, anchor)
    local b = CreateFrame("Button", nil, frame, "BackdropTemplate")
    b:SetSize(30, 22); b:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
    backdrop(b, { 1, 1, 1, 0.05 }, { T.gold[1], T.gold[2], T.gold[3], 0.35 })
    b.t = b:CreateFontString(nil, "OVERLAY"); font(b.t, FONT_BODY, delta > 0 and 13 or 10); b.t:SetPoint("CENTER"); b.t:SetText(label); b.t:SetTextColor(unpack(T.gold))
    b:SetScript("OnClick", function()
      RG.db.textSize = math.max(0.9, math.min(1.7, (RG.db.textSize or 1.2) + delta))
      RG.RefreshUI()
    end)
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(delta > 0 and "Bigger text" or "Smaller text"); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  local plus = sizeBtn("A+", 0.1, close)
  sizeBtn("A-", -0.1, plus)

  -- XP bar under the header
  local xpBg = frame:CreateTexture(nil, "ARTWORK"); xpBg:SetHeight(3); xpBg:SetPoint("TOPLEFT", 1, -72); xpBg:SetPoint("TOPRIGHT", -1, -72); xpBg:SetColorTexture(1, 1, 1, 0.06)
  frame.xpFill = frame:CreateTexture(nil, "OVERLAY"); frame.xpFill:SetHeight(3); frame.xpFill:SetPoint("LEFT", xpBg, "LEFT"); frame.xpFill:SetTexture(WHITE)
  gradient(frame.xpFill, "HORIZONTAL", { T.goldDim[1], T.goldDim[2], T.goldDim[3], 1 }, { T.gold[1], T.gold[2], T.gold[3], 1 })
  frame.xpText = frame:CreateFontString(nil, "OVERLAY"); font(frame.xpText, FONT_NUM, 11); frame.xpText:SetPoint("BOTTOMRIGHT", xpBg, "TOPRIGHT", -14, 8); frame.xpText:SetTextColor(unpack(T.dim))

  -- tabs: text with a gold underline on the active one
  tabs = {}
  local defs = { { "route", "Route" }, { "guide", "Gear guide" }, { "gear", "My gear" }, { "prof", "Professions" }, { "ah", "Auction House" } }
  local x = 18
  for _, d in ipairs(defs) do
    local b = CreateFrame("Button", nil, frame)
    b.text = b:CreateFontString(nil, "OVERLAY"); font(b.text, FONT_BODY, 12); b.text:SetText(d[2]); b.text:SetPoint("CENTER", 0, 1)
    local w = b.text:GetStringWidth() + 26
    b:SetSize(w, 30); b:SetPoint("TOPLEFT", x, -80); x = x + w + 2
    b.underline = b:CreateTexture(nil, "OVERLAY"); b.underline:SetHeight(2); b.underline:SetPoint("BOTTOMLEFT", 8, 0); b.underline:SetPoint("BOTTOMRIGHT", -8, 0); b.underline:SetColorTexture(unpack(T.gold))
    b:SetScript("OnEnter", function(self) if state.tab ~= d[1] then self.text:SetTextColor(unpack(T.text)) end end)
    b:SetScript("OnLeave", function(self) if state.tab ~= d[1] then self.text:SetTextColor(unpack(T.dim)) end end)
    b:SetScript("OnClick", function() state.tab = d[1]; scroll:SetVerticalScroll(0); RG.RefreshUI() end)
    tabs[d[1]] = b
  end
  local tabLine = frame:CreateTexture(nil, "ARTWORK"); tabLine:SetHeight(1); tabLine:SetPoint("TOPLEFT", 1, -110); tabLine:SetPoint("TOPRIGHT", -1, -110); tabLine:SetColorTexture(1, 1, 1, 0.07)

  -- section title row
  sectionTitle = frame:CreateFontString(nil, "OVERLAY"); font(sectionTitle, FONT_TITLE, 18); sectionTitle:SetPoint("TOPLEFT", 20, -122); sectionTitle:SetTextColor(unpack(T.text))
  frame.sectionSub = frame:CreateFontString(nil, "OVERLAY"); font(frame.sectionSub, FONT_NUM, 12); frame.sectionSub:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -3); frame.sectionSub:SetTextColor(unpack(T.dim))

  frame.near = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  frame.near:SetSize(24, 24); frame.near:SetPoint("TOPRIGHT", -112, -124)
  frame.near:SetChecked(state.near)
  frame.near.label = frame.near:CreateFontString(nil, "OVERLAY"); font(frame.near.label, FONT_NUM, 12)
  frame.near.label:SetPoint("LEFT", frame.near, "RIGHT", 2, 0); frame.near.label:SetText("Near my level"); frame.near.label:SetTextColor(unpack(T.dim))
  frame.near:SetScript("OnClick", function(self) state.near = self:GetChecked(); RG.RefreshUI() end)

  frame.scan = flatButton(frame, "Scan prices", 110); frame.scan:SetPoint("TOPRIGHT", -20, -124)
  frame.scan:SetScript("OnClick", function() RG.ScanAH() end)

  scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 18, -164); scroll:SetPoint("BOTTOMRIGHT", -38, 40)
  content = CreateFrame("Frame", nil, scroll); content:SetSize(W - 56, 10)
  scroll:SetScrollChild(content)

  local footLine = frame:CreateTexture(nil, "ARTWORK"); footLine:SetHeight(1); footLine:SetPoint("BOTTOMLEFT", 1, 32); footLine:SetPoint("BOTTOMRIGHT", -1, 32); footLine:SetColorTexture(1, 1, 1, 0.07)
  footer = frame:CreateFontString(nil, "OVERLAY"); font(footer, FONT_NUM, 11); footer:SetPoint("BOTTOMLEFT", 20, 12); footer:SetTextColor(unpack(T.dim))

  frame:SetScript("OnShow", RG.RefreshUI)
  frame:Hide()
end

function RG.ToggleUI()
  if not frame then build() end
  if frame:IsShown() then frame:Hide() else frame:Show(); RG.RefreshUI() end
end

-- Item data arrives a moment after it's first asked for; redraw once it does.
local pendingRefresh
local ev = CreateFrame("Frame")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("PLAYER_XP_UPDATE")
ev:RegisterEvent("SKILL_LINES_CHANGED")
ev:SetScript("OnEvent", function()
  if pendingRefresh or not frame or not frame:IsShown() then return end
  pendingRefresh = true
  C_Timer.After(0.3, function() pendingRefresh = nil; RG.RefreshUI() end)
end)
