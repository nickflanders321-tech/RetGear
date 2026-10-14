-- Waypath+ window, in the classic WoW style: the stone-and-gold dialog frame,
-- a gold title banner, tooltip-bordered rows, quest-log highlights, classic
-- status bars and Character-window tabs along the bottom.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY

-- ---------------------------------------------------------------------------
-- Theme
-- ---------------------------------------------------------------------------
local T = {
  bg      = { 0.05, 0.045, 0.04, 0.97 },
  panel   = { 0.09, 0.08, 0.07, 0.92 },   -- row background (tooltip texture tinted)
  edge    = { 0.55, 0.5, 0.42, 0.85 },    -- tooltip border, classic grey-gold
  gold    = { 1, 0.82, 0 },               -- NORMAL_FONT_COLOR
  goldDim = { 0.62, 0.5, 0.14 },
  green   = { 0.25, 0.75, 0.25 },
  red     = { 1, 0.2, 0.2 },
  purple  = { 0.64, 0.21, 0.93 },         -- epic purple
  blue    = { 0.0, 0.44, 0.87 },          -- rare blue
  text    = { 1, 1, 1 },
  dim     = { 0.62, 0.62, 0.62 },
}
local TOOLTIP_BG, TOOLTIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Background", "Interface\\Tooltips\\UI-Tooltip-Border"
local STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"
local FONT_TITLE = "Fonts\\MORPHEUS.TTF"
local FONT_BODY  = "Fonts\\FRIZQT__.TTF"
local FONT_NUM   = "Fonts\\ARIALN.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local W, H = 780, 620
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
local function saveTab() if RG.db then RG.db.lastTab = state.tab end end

-- Tabs, merged: Professions holds Mining & smithing + Camp; Gold & AH holds
-- prices, gold tips and the bank alt. Sub-tabs pick the section.
local GROUPS = { prof = { "prof", "fish", "camp" }, money = { "ah", "gold", "mail" }, spec2 = { "spec", "heal" } }
local SUBLABEL = { prof = "Professions", fish = "Fishing & cooking", camp = "Camping", ah = "Sell & prices", gold = "Gold tips", mail = "Bank alt", spec = "Spec", heal = "Gear to collect" }
local PARENT = {}
for parent, subs in pairs(GROUPS) do for _, sub in ipairs(subs) do PARENT[sub] = parent end end
local function parentOf(tab) return PARENT[tab] or tab end
state.lastSub = {}

local function setTabLook(b, on)
  -- The Character-window "active" tab art blends into the frame on this client and
  -- nearly vanishes, so every tab uses the inactive art and the open one is lit up.
  for _, t in ipairs(b.parts) do
    t:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
    if on then t:SetVertexColor(1, 1, 1) else t:SetVertexColor(0.62, 0.62, 0.62) end
  end
  if b.glow then b.glow:SetShown(on) end
  b.text:SetFontObject(on and "GameFontHighlightSmall" or "GameFontNormalSmall")
  b.text:ClearAllPoints(); b.text:SetPoint("CENTER", 0, on and 1 or 2)
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", b.x, on and 4 or 7)
  b:SetFrameLevel((frame:GetFrameLevel() or 1) + (on and 3 or 1))
end

-- Tooltip-style box (rows, tags, small buttons). edge = border size.
local function backdrop(f, bg, edge, size)
  if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
  size = size or 12
  local inset = size >= 12 and 3 or 2
  f:SetBackdrop({ bgFile = TOOLTIP_BG, edgeFile = TOOLTIP_EDGE, tile = true, tileSize = 16, edgeSize = size, insets = { left = inset, right = inset, top = inset, bottom = inset } })
  f:SetBackdropColor(unpack(bg)); f:SetBackdropBorderColor(unpack(edge))
end
local function font(fs, path, size, flags) fs:SetFont(path, size, flags or "") end
-- Wraps a font string to `width` and gives it room for every line. Re-setting the
-- text makes the client lay it out again at the final width, and the line count
-- from the text's one-line width backs up GetStringHeight (which can report a
-- single line for text that was laid out before it was allowed to wrap).
local function fitText(fs, width)
  fs:SetWidth(width); fs:SetWordWrap(true)
  if fs.SetMaxLines then fs:SetMaxLines(0) end
  local txt = fs:GetText() or ""
  fs:SetText(""); fs:SetText(txt)
  local h = fs:GetStringHeight() or 0
  if txt ~= "" and fs.GetUnboundedStringWidth and width > 20 then
    local uw = fs:GetUnboundedStringWidth() or 0
    local _, size = fs:GetFont()
    local lines = math.max(1, math.ceil(uw * 1.08 / width))   -- whole words need a little slack
    h = math.max(h, lines * (size or 12) * 1.22)
  end
  fs:SetHeight(math.max(1, h))
  return h
end
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
  green = { bg = { 0.25, 0.75, 0.25, 0.14 }, edge = { 0.25, 0.75, 0.25, 0.75 } },
  gold  = { bg = { 1, 0.82, 0, 0.14 }, edge = { 1, 0.82, 0, 0.75 } },
  red   = { bg = { 1, 0.2, 0.2, 0.14 }, edge = { 1, 0.2, 0.2, 0.75 } },
  muted = { bg = { 0.1, 0.1, 0.1, 0.8 },   edge = { 0.5, 0.5, 0.5, 0.6 } },
}

-- ---------------------------------------------------------------------------
-- Rows: header, item card, sub-row (indented quest) and progress bar
-- ---------------------------------------------------------------------------
local function getRow(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Button", nil, content, "BackdropTemplate")
  r:SetWidth(W - 56)
  r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetPoint("TOPLEFT", 3, -3); r.hl:SetPoint("BOTTOMRIGHT", -3, 3)
  r.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); r.hl:SetBlendMode("ADD"); r.hl:SetAlpha(0.45)

  -- accent stripe on the left edge (current zone, equipped, etc.)
  r.stripe = r:CreateTexture(nil, "ARTWORK"); r.stripe:SetPoint("TOPLEFT", 3, -3); r.stripe:SetPoint("BOTTOMLEFT", 3, 3); r.stripe:SetWidth(3)

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
  r.headLine:SetColorTexture(T.gold[1], T.gold[2], T.gold[3], 0.3)

  -- progress bar pieces
  r.barBg = r:CreateTexture(nil, "ARTWORK"); r.barBg:SetHeight(10); r.barBg:SetPoint("BOTTOMLEFT", 12, 9); r.barBg:SetPoint("BOTTOMRIGHT", -12, 9); r.barBg:SetTexture(STATUSBAR); r.barBg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
  r.barFill = r:CreateTexture(nil, "OVERLAY"); r.barFill:SetHeight(10); r.barFill:SetPoint("LEFT", r.barBg, "LEFT", 0, 0); r.barFill:SetTexture(STATUSBAR)
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
  r:SetScript("OnClick", function(self, btn)
    if btn == "RightButton" and self.onRightClick then self.onRightClick(self); return end
    if self.onDoubleClick then
      -- wait a moment so a double-click doesn't also do the single-click action
      local now = GetTime()
      if self.pending and now - self.pending < 0.35 then self.pending = nil; self.onDoubleClick(self); return end
      self.pending = now
      local single = self.onClick
      C_Timer.After(0.35, function() if self.pending == now then self.pending = nil; if single then single(self) end end end)
      return
    end
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
  r.onClick = nil; r.onRightClick = nil; r.tip = nil; r.onDoubleClick = nil
  r.title:SetWordWrap(false); r.sub:SetWordWrap(false)
  for _, k in ipairs({ "iconBorder", "icon", "title", "sub", "pill", "meta", "head", "headLine", "barBg", "barFill", "barMark", "barLabel", "barValue", "stripe" }) do r[k]:Hide() end
end

local function setHeader(r, text)
  hideAll(r); r.itemID, r.link = nil, nil
  r.kind, r.h = "head", HEAD_H()
  font(r.head, FONT_BODY, sz(12.5))
  r:SetBackdrop(nil); r.hl:Hide()
  r.head:SetText(text); r.head:SetTextColor(unpack(T.gold)); r.head:SetShadowColor(0, 0, 0, 1); r.head:SetShadowOffset(1, -1); r.head:Show(); r.headLine:Show()
  -- a header too long for one line wraps (and drops its rule line) instead of running off the edge
  local maxW = (W - 56) - 8
  r.head:SetWidth(0); r.head:SetHeight(0); r.head:SetWordWrap(false)
  if (r.head:GetStringWidth() or 0) > maxW then
    r.headLine:Hide()
    r.h = math.max(r.h, math.ceil(fitText(r.head, maxW) + 12))
  end
  r:Show()
end

-- accent: "gold" | "green" | "purple" | nil  ·  quality: item quality for the icon border
local function setItem(r, id, link, title, sub, right, right2, accent, quality, small)
  hideAll(r); r.itemID, r.link = id, link
  r.kind, r.h = small and "sub" or "item", small and SUB_H() or ROW_H()
  backdrop(r, small and { 0.07, 0.065, 0.06, 0.85 } or T.panel, accent == "gold" and { T.gold[1], T.gold[2], T.gold[3], 0.9 } or (accent == "green" and { T.green[1], T.green[2], T.green[3], 0.9 } or T.edge), small and 10 or 12)
  r.hl:Show()
  local size = small and sz(22) or sz(32)
  r.iconBorder:SetSize(size, size)
  r.iconBorder:ClearAllPoints(); r.iconBorder:SetPoint("LEFT", small and 34 or 8, 0)
  r.iconBorder:Show(); r.icon:Show()
  r.icon:SetTexture(id and itemIcon(id) or 134400); r.icon:SetDesaturated(false)
  r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); r.icon:SetVertexColor(1, 1, 1, 1)
  local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  r.iconBorder:SetVertexColor(1, 1, 1, 1)
  if qc then r.iconBorder:SetColorTexture(qc.r, qc.g, qc.b, 0.95) else r.iconBorder:SetColorTexture(0.35, 0.33, 0.3, 0.9) end
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
    backdrop(r.pill, PILL[kind].bg, PILL[kind].edge, 8)
    r.pill:ClearAllPoints(); r.pill:SetPoint(small and "RIGHT" or "TOPRIGHT", -10, small and 0 or -6)
    r.pill:Show()
  end
  if right2 and right2 ~= "" and not small then r.meta:SetText(right2); r.meta:Show() end
  if small and right2 and right2 ~= "" and not kind then r.meta:SetText(right2); r.meta:ClearAllPoints(); r.meta:SetPoint("RIGHT", -12, 0); r.meta:Show() end
  -- keep titles clear of the right column
  local rightW = math.max(kind and r.pill:GetWidth() or 0, r.meta:IsShown() and r.meta:GetStringWidth() or 0)
  local leftX = (small and 34 or 8) + size + 10
  -- long text wraps and the row grows to fit it (nothing is cut off with "...")
  local th = fitText(r.title, math.max(120, (W - 56) - leftX - rightW - 26))
  local hasSub = sub and sub ~= ""
  local shh = fitText(r.sub, math.max(120, (W - 56) - leftX - (r.meta:IsShown() and r.meta:GetStringWidth() or 0) - 26))
  if not hasSub then shh = 0 end
  local gap = hasSub and 2 or 0
  local content = th + gap + shh
  local pad = small and 5 or 7
  r.h = math.max(r.h, math.ceil(content + pad * 2))
  local top = math.max(pad, (r.h - content) / 2)
  r.title:ClearAllPoints(); r.title:SetPoint("TOPLEFT", r, "TOPLEFT", leftX, -top)
  r.sub:ClearAllPoints(); r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -gap)
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
  backdrop(r, T.panel, T.edge, 12); r.hl:Hide()
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
  backdrop(r, { 0.07, 0.065, 0.06, done and 0.6 or 0.85 }, { 0.45, 0.42, 0.36, done and 0.4 or 0.7 }, 10)
  r.hl:Show()
  local box = sz(16)
  r.iconBorder:SetSize(box, box); r.iconBorder:ClearAllPoints(); r.iconBorder:SetPoint("TOPLEFT", 34, -sz(9))
  local bc = auto and T.green or T.gold
  -- the classic checkbox: an empty box, with a gold check (green when the game ticked it)
  r.iconBorder:SetTexture("Interface\\Buttons\\UI-CheckBox-Up"); r.iconBorder:SetVertexColor(1, 1, 1, 1); r.iconBorder:SetTexCoord(0, 1, 0, 1); r.iconBorder:Show()
  r.icon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); r.icon:SetTexCoord(0, 1, 0, 1)
  r.icon:SetVertexColor(auto and 0.4 or 1, auto and 1 or 1, auto and 0.4 or 1, 1)
  r.icon:SetShown(done and true or false)
  font(r.title, FONT_NUM, sz(13))
  r.title:ClearAllPoints(); r.title:SetPoint("TOPLEFT", r.iconBorder, "TOPRIGHT", 10, 1)
  r.title:SetText((done and GREY or "|cffffffff") .. ((num ~= nil and num ~= "") and (num .. ".  ") or "") .. text .. "|r"); r.title:Show()
  local th = fitText(r.title, (W - 56) - 34 - box - 10 - 18)
  r.h = math.max(sz(32), (th or sz(14)) + sz(16))
  r.onClick = onClick
  if auto then r.tip = "Done: " .. auto .. "\n|cffa0a0a0(detected from your game)|r"
  elseif done then r.tip = "Ticked by you. Click to untick." else r.tip = "Click to tick this off." end
  r:Show()
end

-- ---------------------------------------------------------------------------
-- Tabs
-- ---------------------------------------------------------------------------
-- Gear guide order: the two-hander first (your biggest upgrade), then head to toe.
local GUIDE_SLOTS = { "2H", "Main Hand", "Off Hand", "Ranged", "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Ring", "Trinket" }
local GUIDE_SLOT_LABEL = { ["2H"] = "Two-handed weapon", ["Main Hand"] = "One-handed weapon", ["Off Hand"] = "Off hand", ["Ranged"] = "Ranged / wand" }
local function guideRows()
  local list, lvl = {}, UnitLevel("player")
  if state.near then
    -- near your level: per slot, what's coming in the next few levels (up to 4 each)
    local lo, hi = lvl - 3, lvl + 8
    local tips = {}
    for _, g in ipairs(RG.GUIDE) do if g.tip and g.lvl >= lo - 5 and g.lvl <= hi then tips[#tips + 1] = g end end
    if #tips > 0 then list[#list + 1] = { header = "Tips" }; for _, g in ipairs(tips) do list[#list + 1] = { g = g } end end
    for _, slot in ipairs(GUIDE_SLOTS) do
      local items = {}
      for _, g in ipairs(RG.GUIDE) do
        if g.id and g.slot == slot and g.lvl >= lo and g.lvl <= hi and RG.OwnState(g.id) ~= "equipped" then items[#items + 1] = g end
      end
      table.sort(items, function(a, b) if a.lvl ~= b.lvl then return a.lvl < b.lvl end return (a.score or 0) > (b.score or 0) end)
      if #items > 0 then
        list[#list + 1] = { header = (GUIDE_SLOT_LABEL[slot] or slot) .. GREY .. "   levels " .. math.max(1, lo) .. "-" .. hi .. "|r" }
        for i = 1, math.min(4, #items) do list[#list + 1] = { g = items[i] } end
      end
    end
  else
    -- the whole guide: by level bracket, then slot
    local brackets = { { 1, 19, "Levels 1-19" }, { 20, 29, "Levels 20-29" }, { 30, 39, "Levels 30-39" }, { 40, 49, "Levels 40-49" }, { 50, 57, "Levels 50-57" }, { 58, 60, "Levels 58-60 · pre-raid" } }
    local order = {}
    for i, sl in ipairs(GUIDE_SLOTS) do order[sl] = i end
    for _, b in ipairs(brackets) do
      local items = {}
      for _, g in ipairs(RG.GUIDE) do if g.lvl >= b[1] and g.lvl <= b[2] then items[#items + 1] = g end end
      table.sort(items, function(x, y)
        local ox, oy = x.tip and 0 or (order[x.slot] or 99), y.tip and 0 or (order[y.slot] or 99)
        if ox ~= oy then return ox < oy end
        return x.lvl < y.lvl
      end)
      if #items > 0 then
        list[#list + 1] = { header = b[3] }
        for _, g in ipairs(items) do list[#list + 1] = { g = g } end
      end
    end
  end
  return list
end

local function renderGuide()
  local list = guideRows()
  local lvl = UnitLevel("player")
  if #list == 0 then list = { { header = "Nothing near your level · untick Near my level" } } end
  -- your 2nd spec: a link to its gear list
  local off = 0
  local s2 = RG.SecondSpecActive and RG.SecondSpecActive()
  if s2 or lvl >= 20 then
    off = 1
    local r = getRow(1)
    if s2 then
      local soon = 0
      for _, g in ipairs(RG.SpecGuide(s2)) do if g.lvl <= lvl + 5 and not RG.OwnState(g.id) then soon = soon + 1 end end
      setItem(r, nil, nil, "|cffffffff2nd spec: " .. s2.name .. "|r", (soon > 0 and (soon .. " " .. s2.name .. " piece" .. (soon > 1 and "s" or "") .. " to start collecting near your level") or ("Your " .. s2.name .. " set and what to hunt for")) .. GREY .. "  ·  this list is for your leveling spec|r", GOLD .. "Show|r", "", "gold", nil, true)
      r.icon:SetTexture(s2.icon)
      r.onClick = function() state.tab = "heal"; scroll:SetVerticalScroll(0); RG.RefreshUINow() end
    else
      setItem(r, nil, nil, GREY .. "No 2nd spec yet|r", GREY .. "Pick one on the 2nd Spec tab and its gear to collect shows up there.|r", GOLD .. "Choose|r", "", nil, nil, true)
      r.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
      r.onClick = function() state.tab = "spec"; scroll:SetVerticalScroll(0); RG.RefreshUINow() end
    end
  end
  for i, e in ipairs(list) do
    local r = getRow(i + off)
    if e.header then setHeader(r, e.header)
    elseif e.g.tip then
      setItem(r, nil, nil, GOLD .. "Tip|r" .. GREY .. "  ·  level " .. e.g.lvl .. "|r", e.g.text, "", "", "gold")
      r.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
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
      local qsrc = g.how == "Quest" and g.src and g.src:gsub("%s*%(.-%)$", "")
      local qIn = qsrc and RG.InLog and RG.InLog(qsrc)
      if qIn and not own then right2 = GOLD .. "Quest in your log|r" end
      setItem(r, g.id, link, name .. GREY .. "   " .. g.slot .. "  ·  lvl " .. (g.approx and "~" or "") .. g.lvl .. "|r", g.src .. GREY .. "  ·  " .. g.zone .. "|r", right, right2, accent, quality)
      r.onClick = function() RG.ShowItemSource(g, d and d > 0.5 and { note = GREEN .. string.format("+%.0f", d) .. "|r" .. GREY .. " over what you wear|r" } or nil) end
      if qIn then r.onRightClick = function() RG.OpenQuest(qsrc) end end
    end
  end
  return #list + off
end

local SLOT_GUIDE = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket", [15] = "Back", [16] = "2H", [17] = "Off Hand", [18] = "Ranged" }
-- the gear guide's weapon list for a slot: two-handers, or one-handers for dual wielders
-- and casters holding a one-hander
local function guideSlotFor(slot)
  if slot == 16 then
    local m = RG.WEAPON_MODEL
    if m == "DW" then return "Main Hand" end
    if m == "caster" then
      local worn = GetInventoryItemLink("player", 16)
      if worn and RG.EquipLoc(worn) ~= "INVTYPE_2HWEAPON" then return "Main Hand" end
    end
    return "2H"
  end
  if slot == 17 and RG.WEAPON_MODEL == "DW" then return "Main Hand" end   -- any one-hander fits the off hand
  return SLOT_GUIDE[slot]
end
local function renderGear()
  local n, total = 0, 0
  local hit, cap = RG.CurrentHit(), RG.db.hitCap
  -- summary bars first
  n = n + 1; local scoreRow = getRow(n)
  n = n + 1
  setBar(getRow(n), "Hit chance", math.min(hit, cap), cap, hit >= cap and T.green or T.gold, string.format("%s%.0f%%|r / %d%% cap", hit >= cap and GREEN or "|cffffffff", hit, cap))
  -- gear check: every guide item compared with what you wear right now
  local lvl = UnitLevel("player")
  local ups, loading = {}, 0
  for _, g in ipairs(RG.GUIDE) do
    if g.id and g.lvl <= lvl + 8 and g.lvl >= lvl - 15 and not RG.OwnState(g.id) then
      local d, slot, new, old = RG.GuideDelta(g)
      if d == nil then loading = loading + 1
      elseif d > 0.5 then ups[#ups + 1] = { g = g, d = d, slot = slot, now = g.lvl <= lvl, pct = (old and old > 0) and (d / old * 100) or nil } end
    end
  end
  table.sort(ups, function(a, b) if a.now ~= b.now then return a.now end return a.d > b.d end)
  n = n + 1; setHeader(getRow(n), "Gear check  ·  your best upgrades from the guide" .. (loading > 0 and (GREY .. "   (" .. loading .. " items still loading)|r") or ""))
  if #ups == 0 then
    n = n + 1; setItem(getRow(n), nil, nil, GREEN .. "Nothing in the guide beats your gear for the next 8 levels.|r", "Keep an eye on quest rewards: the Equip pop-up tells you when one is better.", "", "", "green", nil, true)
  end
  for i = 1, math.min(8, #ups) do
    local u = ups[i]
    n = n + 1
    local name, link2, quality = itemName(u.g.id)
    local worn = u.slot and ((RG.WornLink and RG.WornLink(u.slot)) or GetInventoryItemLink("player", u.slot))
    local mhNow = GetInventoryItemLink("player", 16)
    local wornName = worn and (RG.ItemInfo(worn) or "your item")
      or ((u.slot == 16 and RG.IsFishingPole and RG.IsFishingPole(mhNow)) and "your fishing pole" or "an empty slot")
    setItem(getRow(n), u.g.id, link2, name .. GREY .. "   " .. (GUIDE_SLOT_LABEL[u.g.slot] or u.g.slot) .. "|r",
      GREY .. "Replaces " .. wornName .. "  ·  " .. u.g.src .. (u.g.zone ~= "" and (", " .. u.g.zone) or "") .. "|r",
      (u.now and GREEN or GOLD) .. "+" .. string.format("%.0f", u.d) .. (u.pct and string.format(" (%d%%)", math.floor(u.pct + 0.5)) or "") .. "|r",
      u.now and (GREEN .. "Usable now|r") or (GREY .. "Level " .. u.g.lvl .. "|r"), u.now and "gold" or nil, quality, true)
    rows[n].onClick = function() RG.ShowItemSource(u.g, { note = GREEN .. string.format("+%.0f", u.d) .. "|r" .. GREY .. " over " .. wornName .. "|r" }) end
  end
  -- which dungeons are worth running for you
  local dung = {}
  for _, u in ipairs(ups) do
    if u.g.how == "Dungeon" and u.g.zone ~= "" then
      local e = dung[u.g.zone] or { zone = u.g.zone, total = 0, items = {}, lvl = 99 }
      dung[u.g.zone] = e
      e.total = e.total + u.d; e.lvl = math.min(e.lvl, u.g.lvl)
      e.items[#e.items + 1] = u
    end
  end
  local dl = {}
  for _, e in pairs(dung) do dl[#dl + 1] = e end
  table.sort(dl, function(a, b) return a.total > b.total end)
  if #dl > 0 then
    n = n + 1; setHeader(getRow(n), "Dungeons with upgrades for you")
    for i = 1, math.min(5, #dl) do
      local e = dl[i]
      table.sort(e.items, function(a, b) return a.d > b.d end)
      local parts = {}
      for j = 1, math.min(4, #e.items) do
        local it = e.items[j]
        parts[#parts + 1] = (RG.ItemInfo(it.g.id) or "item") .. " " .. GREEN .. string.format("+%.0f", it.d) .. "|r" .. GREY .. " (" .. it.g.src .. ")|r"
      end
      n = n + 1
      setItem(getRow(n), nil, nil, "|cffA58BD8" .. e.zone .. "|r" .. GREY .. "   " .. #e.items .. " upgrade" .. (#e.items > 1 and "s" or "") .. "|r", table.concat(parts, GREY .. "  ·  |r"),
        GREEN .. "+" .. string.format("%.0f", e.total) .. " total|r", e.lvl > lvl and (GREY .. "from level " .. e.lvl .. "|r") or "", nil, nil, true)
      rows[n].icon:SetTexture(136058)
      local ew = RG.WAYPOINTS and RG.WAYPOINTS.dungeons[e.zone]
      if ew then rows[n].onClick = function() RG.PinWaypoint(ew) end; rows[n].tip = "Click to show the " .. e.zone .. " entrance on the map." end
    end
  end
  n = n + 1; setHeader(getRow(n), "Equipped")
  for _, slot in ipairs(RG.SLOT_ORDER) do
    local link = GetInventoryItemLink("player", slot)
    n = n + 1
    local r = getRow(n)
    local score = link and RG.Score(link) or 0
    total = total + score
    local nextUp
    for _, g in ipairs(RG.GUIDE) do
      if g.id and guideSlotFor(slot) == g.slot and g.lvl <= lvl + 6 and not RG.OwnState(g.id) then
        local d = RG.GuideDelta(g)
        -- prefer the biggest upgrade you can use within 3 levels, else the soonest one
        if d and d > 0.5 then
          local soon = g.lvl <= lvl + 3
          if not nextUp or (soon and (not nextUp.soon or d > nextUp.d)) or (not soon and not nextUp.soon and g.lvl < nextUp.g.lvl) then nextUp = { g = g, d = d, soon = soon } end
        end
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
    local slotName = RG.SLOT_NAMES[slot]
    if nextUp then
      r.onClick = function() RG.ShowItemSource(nextUp.g, { note = GOLD .. "Next upgrade for your " .. slotName .. ":|r " .. GREEN .. string.format("+%.0f", nextUp.d) .. "|r" }) end
      r.tip = nil
    elseif id then
      r.onClick = function() RG.ShowItemSource(id, { note = GREY .. "You're wearing this. Nothing on your list beats it yet.|r" }) end
    end
    if not link then r.icon:SetTexture(136516); r.icon:SetDesaturated(true) else r.icon:SetDesaturated(false) end
  end
  setBar(scoreRow, (RG.SCORE_NAME or "Upgrade score"):gsub(" score$", "") .. " gear score", total, math.max(total, 1), T.gold, string.format("%s%.0f|r", GOLD, total))
  -- pre-raid checklist: the level 52+ picks from the gear guide, one row per item
  n = n + 1; setHeader(getRow(n), "Pre-raid checklist · best dungeon and quest pieces, level 52 to 60")
  for _, slot in ipairs(GUIDE_SLOTS) do
    local best = {}
    for _, g in ipairs(RG.GUIDE) do if g.id and g.slot == slot and g.lvl >= 52 then best[#best + 1] = g end end
    table.sort(best, function(a, b) return (a.score or 999) > (b.score or 999) end)
    for i = 1, math.min((slot == "Ring" or slot == "Trinket") and 2 or 1, #best) do
      local g = best[i]
      n = n + 1
      local name, link2, quality = itemName(g.id)
      local own = RG.OwnState(g.id)
      local pill = own == "equipped" and (GREEN .. "Equipped|r") or (own == "owned" and (GOLD .. "In your bags|r") or (GREY .. "Not yet|r"))
      setItem(getRow(n), g.id, link2, name .. GREY .. "   " .. (GUIDE_SLOT_LABEL[g.slot] or g.slot) .. "|r", g.src .. GREY .. "  ·  " .. g.zone .. "|r", pill, g.ah and RG.PriceText(g.id) or "", own == "equipped" and "green" or nil, quality)
    end
  end
  return n
end

local PROF_ORDER = { "Mining", "Herbalism", "Skinning", "Blacksmithing", "Engineering", "Alchemy", "Leatherworking", "Tailoring", "Enchanting", "Cooking", "Fishing", "First Aid" }
local RANKS = { { "apprentice", "Apprentice", 0, 1 }, { "journeyman", "Journeyman", 50, 10 }, { "expert", "Expert", 125, 20 }, { "artisan", "Artisan", 200, 35 } }
local KIND_WORD = { vendor = "vendor", herb = "herb", ore = "ore", stone = "stone", gem = "gem", cloth = "cloth", leather = "leather",
  meat = "meat", fish = "fish", elemental = "elemental", enchant = "enchanting", crafted = "you make it", drop = "drop" }
function RG.ShowProf(name)
  state.profSel = name
  if RG.ShowTab then RG.ShowTab("prof") end
end
local function renderProf()
  local known = RG.Professions()
  local lvl = UnitLevel("player")
  local n = 0
  local function head(t) n = n + 1; setHeader(getRow(n), t) end
  local function line(id, title, sub, right, right2, icon, accent, quality, small)
    n = n + 1; local r = getRow(n)
    local link = id and select(2, RG.ItemInfo(id))
    setItem(r, id, link, title, sub, right, right2, accent, quality, small)
    if icon then r.icon:SetTexture(icon) end
    return r
  end
  -- a place you can double-click to send the arrow there
  local function place(pl, icon)
    local r = line(nil, "|cffffffff" .. pl.title .. "|r", pl.sub or "", pl.wp and (GOLD .. "Double-click|r") or "", pl.wp and (GREY .. "arrow|r") or "", icon or "Interface\\Icons\\INV_Misc_Map_01", pl.wp and "gold" or nil)
    if pl.wp then
      r.onDoubleClick = function() RG.ArrowTo(pl.wp) end
      r.tip = "Double-click to put " .. pl.wp[4] .. " on your map and point the arrow at it."
    end
    return r
  end
  -- which profession: yours first, then the one you picked from the full list
  local mine = {}
  for _, name in ipairs(PROF_ORDER) do
    if RG.PROFESSIONS[name] and (known[name] or (RG.Plans and RG.Plans(name))) then mine[#mine + 1] = name end
  end
  if not state.profSel or not RG.PROFESSIONS[state.profSel] then state.profSel = mine[1] or "Mining" end
  local sel = state.profSel
  -- your professions: a bar each, click to open
  head("Your professions  ·  click one to open its guide")
  if #mine == 0 then
    line(nil, "|cffffffffTwo main professions, plus Cooking, Fishing and First Aid|r", "Good pairs: Mining + Blacksmithing or Engineering, Herbalism + Alchemy, Skinning + Leatherworking, Tailoring + Enchanting. Two gathering professions make the most gold while leveling. Run /wp setup to pick yours, or open any profession below.", "", "", 136240, nil, nil, true)
  end
  for _, name in ipairs(mine) do
    local k = known[name]
    local P = RG.PROFESSIONS[name]
    local now = RG.ProfNow(name)
    local what
    if not k then what = GOLD .. "Not learned yet|r"
    elseif now and now.done then what = GREEN .. "Done: 300|r"
    elseif now and now.craft then
      local short = 0
      for _, e in ipairs(now.mats or {}) do if not e.via then short = short + e.short end end
      what = now.craft .. " x" .. (now.left or 0) .. (short > 0 and (GREY .. "  ·  " .. short .. " materials to get|r") or (GREEN .. "  ·  you have everything|r"))
    elseif now and now.st then what = (now.st.gather or now.st.skin or (now.st.fish and ("Fish in " .. now.st.fish)) or "") .. GREY .. "  ·  until " .. now.st.to .. "|r" end
    local r = line(nil, (name == sel and GOLD or "|cffffffff") .. name .. "|r" .. GREY .. "   " .. (k and (k.rank .. " / " .. (k.max or "?")) or "") .. "|r", what or "", name == sel and (GREEN .. "Open|r") or (GOLD .. "Show|r"), "", P.icon, name == sel and "gold" or nil, nil, true)
    r.onClick = function() state.profSel = name; RG.RefreshUINow() end
  end

  -- the selected profession
  local P = RG.PROFESSIONS[sel]
  local k = known[sel]
  local rank, max = k and k.rank or 0, k and k.max or 0
  if k and not k.max then max = rank end
  n = n + 1; setBar(getRow(n), sel, rank, math.max(max, rank, 1), T.gold, k and (rank .. " / " .. max) or (GREY .. "Not learned yet|r"))
  local now = RG.ProfNow(sel, rank)
  local T2 = P.train or {}
  -- training
  if not k then
    local start = T2.start and T2.start[RG.RACE_LETTER]
    local pin = RG.TrainerPin(start or T2.apprentice)
    local r = line(nil, GOLD .. "Learn " .. sel .. "|r" .. GREY .. "  ·  no level needed|r", start and ("Closest trainer: " .. start) or (T2.apprentice or ""), pin and (GOLD .. "Double-click|r") or (GOLD .. "Train|r"), pin and (GREY .. "arrow|r") or "", P.icon, "gold")
    if pin then r.onDoubleClick = function() RG.ArrowTo(pin) end; r.tip = "Double-click to put " .. pin[4] .. " on your map." end
  else
    for ri = 2, #RANKS do
      local key, label, needSkill, needLvl = RANKS[ri][1], RANKS[ri][2], RANKS[ri][3], RANKS[ri][4]
      local cap = ({ 75, 150, 225, 300 })[ri - 1]
      if max <= cap and max < 300 and rank >= needSkill - 10 and T2[key] then
        local ready = rank >= needSkill and lvl >= needLvl
        local pin = RG.TrainerPin(T2[key])
        local r = line(nil, (ready and GOLD or "|cffffffff") .. "Train " .. label .. "|r" .. GREY .. "  ·  skill " .. needSkill .. ", level " .. needLvl .. "|r", T2[key],
          ready and (GOLD .. "Train now|r") or (GREY .. (rank < needSkill and ("at skill " .. needSkill) or ("at level " .. needLvl)) .. "|r"), pin and (GREY .. "double-click: arrow|r") or "", P.icon, ready and "gold" or nil)
        if pin then r.onDoubleClick = function() RG.ArrowTo(pin) end; r.tip = "Double-click to put " .. pin[4] .. " on your map." end
        break
      end
    end
  end
  -- now: the current step and its materials
  if now and now.done then
    line(nil, GREEN .. sel .. " is maxed|r", "Nothing left to level. Its recipes and gold tips are still on the Gold tab.", "", "", P.icon, "green")
  elseif now and now.st then
    local st = now.st
    if now.craft then
      head("Now: " .. now.craft .. "  ·  skill " .. st.from .. "-" .. st.to)
      local others = {}
      for _, o in ipairs(now.options or {}) do if o ~= now.craft then others[#others + 1] = o end end
      line(nil, "|cffffffffMake " .. (now.left or 0) .. " more " .. now.craft .. "|r", (st.mats or "") .. (#others > 0 and (GREY .. "  ·  or: " .. table.concat(others, ", ") .. "|r") or ""),
        GOLD .. (now.left or 0) .. " left|r", GREY .. "to skill " .. st.to .. "|r", P.icon, "gold")
      if now.mats then
        local allReady = true
        for _, e in ipairs(now.mats) do
          if not e.via then
            local info = RG.MAT_INFO and RG.MAT_INFO[e.id]
            local kind = info and KIND_WORD[info[2]] or ""
            local name, _, quality = RG.ItemInfo(e.id)
            local title = (e.short > 0 and "|cffffffff" or GREEN) .. (name or e.name) .. "|r" .. GREY .. "   " .. kind .. "|r"
            local sub = "Need " .. e.need .. "  ·  you have " .. e.have .. GREY .. " (bags and bank)|r"
            local price = RG.Price and RG.Price(e.id)
            local r = line(e.id, title, sub, e.short > 0 and ("|cffff6060" .. e.short .. " more|r") or (GREEN .. "Ready|r"),
              (e.short > 0 and price) and (GREY .. "AH ~" .. RG.Money(price * e.short) .. "|r") or "", nil, e.short > 0 and nil or "green", quality, true)
            if e.short > 0 then
              allReady = false
              local pl = RG.MatPlaces(e.id, 1)[1]
              if pl and pl.wp then
                r.onDoubleClick = function() RG.ArrowTo(pl.wp) end
                r.tip = pl.title .. ": " .. pl.wp[4] .. "\nDouble-click to point the arrow there."
              end
            end
          end
        end
        -- crafted reagents you're short of: what they take
        for _, e in ipairs(now.mats) do
          if e.via then
            local name, _, quality = RG.ItemInfo(e.id)
            line(e.id, GREY .. "for " .. e.via .. ":|r " .. (e.short > 0 and "|cffffffff" or GREEN) .. (name or e.name) .. "|r", "Need " .. e.need .. "  ·  you have " .. e.have,
              e.short > 0 and ("|cffff6060" .. e.short .. " more|r") or (GREEN .. "Ready|r"), "", nil, nil, quality, true)
            if e.short > 0 then allReady = false end
          end
        end
        if allReady then line(nil, GREEN .. "You have everything for this step|r", "Open your " .. sel .. " window and craft away. Waypath+ tells you when the step is done.", "", "", P.icon, "green", nil, true) end
      else
        line(nil, GREY .. "Materials: " .. (st.mats or "see the guide") .. "|r", "Open your " .. sel .. " window once and Waypath+ reads the exact recipe from it.", "", "", P.icon, nil, nil, true)
      end
    elseif st.gather then
      head("Now: " .. st.gather .. (st.also and (" and " .. st.also) or "") .. "  ·  skill " .. st.from .. "-" .. st.to)
      local zonesOf = (sel == "Mining" and RG.ORE_ZONES) or RG.HERB_ZONES or {}
      line(nil, "|cffffffff" .. (sel == "Mining" and "Mine " or "Pick ") .. st.gather .. "|r", (zonesOf[st.gather] or "") .. (sel == "Herbalism" and (GREY .. "  ·  needs character level " .. math.max(1, math.floor(st.from / 5)) .. "|r") or ""), GOLD .. (st.to - rank) .. " points|r", GREY .. "to skill " .. st.to .. "|r", P.icon, "gold")
    elseif st.fish then
      head("Now: fishing  ·  skill " .. st.from .. "-" .. st.to)
      line(nil, "|cffffffffFish in " .. st.fish .. "|r", (st.where or "") .. (st.lvl and (GREY .. "  ·  from character level " .. st.lvl .. "|r") or ""), GOLD .. (st.to - rank) .. " points|r", GREY .. "to skill " .. st.to .. "|r", P.icon, "gold")
    elseif st.skin then
      head("Now: skinning  ·  skill " .. st.from .. "-" .. st.to)
      line(nil, "|cffffffff" .. st.skin .. "|r", (st.where or "") .. GREY .. "  ·  you can skin up to level " .. RG.SkinMaxLevel(rank) .. "|r", GOLD .. (st.to - rank) .. " points|r", "", P.icon, "gold")
    end
    -- where to go
    local places = RG.ProfPlaces(sel, now)
    if #places > 0 then
      head("Where to go  ·  double-click a place and follow the arrow")
      for _, pl in ipairs(places) do place(pl) end
    end
    -- what comes next
    if now.next then
      local nx = now.next
      local opts = RG.StepOptions(nx)
      local label = opts[1] or nx.gather or nx.skin or (nx.fish and ("Fish in " .. nx.fish))
      local sub = nx.mats or ""
      if opts[1] then
        local m = RG.MatsFor(opts[1], nx.n or 0)
        if m then
          local parts = {}
          for _, e in ipairs(m) do if not e.via and e.short > 0 then parts[#parts + 1] = e.short .. " " .. e.name end end
          sub = #parts > 0 and ("Still to get: " .. table.concat(parts, ", ")) or (GREEN .. "You already have the materials|r")
        end
      end
      head("Next")
      line(nil, "|cffffffff" .. label .. (nx.n and (GREY .. "   x" .. nx.n .. "|r") or "") .. "|r" .. GREY .. "  ·  skill " .. nx.from .. "-" .. nx.to .. "|r", sub, "", "", P.icon, nil, nil, true)
    end
  end
  -- the whole route
  head(sel .. " 1-300  ·  " .. (P.source or "WoW Forever guide") .. (state.profFull and "" or "  ·  click below for every step"))
  if state.profFull then
    for _, st in ipairs(RG.ProfPlan(P)) do
      local here = now and now.st == st
      local passed = rank >= st.to and not st.train
      local title
      if st.train then title = GOLD .. "Train: " .. st.train .. "|r"
      elseif st.craft then title = st.craft .. GREY .. "   x" .. (st.n or "?") .. "|r"
      elseif st.gather then title = st.gather .. (st.also and (GREY .. " and " .. st.also .. "|r") or "")
      elseif st.skin then title = st.skin
      elseif st.fish then title = "Fish in " .. st.fish end
      title = (here and GOLD or (passed and GREY or "|cffffffff")) .. (title or "") .. "|r"
      line(nil, title .. GREY .. "  ·  " .. st.from .. (st.to ~= st.from and ("-" .. st.to) or "") .. "|r", st.mats or st.where or "", here and (GREEN .. "You're here|r") or (passed and (GREY .. "Done|r") or ""), "", P.icon, here and "gold" or nil, nil, true)
    end
  end
  n = n + 1
  setStep(getRow(n), "", "Show every step of the route", state.profFull, function() state.profFull = not state.profFull; RG.RefreshUI() end)
  if P.fishTab then line(nil, "|cffffffffFishing guide|r", "Zones by skill, lures, poles and the derby are on the Fishing tab (/wp fish).", "", "", P.icon, nil, nil, true) end
  if P.supplies then line(nil, GREY .. "Supplies|r", P.supplies, "", "", P.icon, nil, nil, true) end

  -- Mining and Blacksmithing extras
  if sel == "Mining" and known["Mining"] then
    head("Smelt or sell")
    local any = false
    for _, sm in ipairs(RG.SMELT) do
      local ore, bar = RG.Price(sm.ore), RG.Price(sm.bar)
      local oreName, barName = RG.ItemInfo(sm.ore), RG.ItemInfo(sm.bar)
      if ore and bar and oreName and barName then
        any = true
        local better = bar > ore
        line(sm.bar, barName, GREY .. "Bar " .. RG.Money(bar) .. "  vs  ore " .. RG.Money(ore) .. "|r", better and (GREEN .. "Smelt it|r") or (GOLD .. "Sell the ore|r"), "", nil, better and "green" or nil)
      end
    end
    if not any then n = n + 1; setStep(getRow(n), "", "Open the Auction House once to compare ore and bar prices here.", false, nil); rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil end
  end
  if sel == "Blacksmithing" and known["Blacksmithing"] then
    local bs = known["Blacksmithing"]
    head("Blacksmithing upgrades for you")
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
  end
  -- material prices for this profession
  local ids = P.mats or {}
  if #ids > 0 and k then
    head("Material prices  ·  lowest buyout")
    for _, id in ipairs(ids) do
      local nm2, _, quality = itemName(id)
      local cnt = RG.MatCount and RG.MatCount(id) or 0
      line(id, nm2, cnt > 0 and ("You have " .. cnt) or (GREY .. "None in your bags or bank|r"), "", RG.PriceText(id) or (GREY .. "not seen yet|r"), nil, nil, quality, true)
    end
  end
  -- every other profession's route
  head("Every profession's leveling route  ·  click one to read it")
  for _, name in ipairs(PROF_ORDER) do
    local isMine = false
    for _, m in ipairs(mine) do if m == name then isMine = true end end
    local P2 = RG.PROFESSIONS[name]
    if P2 and not isMine then
      local steps = 0
      for _, st in ipairs(RG.ProfPlan(P2)) do if not st.train then steps = steps + 1 end end
      local r = line(nil, (name == sel and GOLD or "|cffffffff") .. name .. "|r", steps .. " steps from 1 to 300" .. GREY .. "  ·  " .. (P2.kind == "gather" and "gathering" or (P2.kind or "")) .. "|r", name == sel and (GREEN .. "Open|r") or "", "", P2.icon, name == sel and "gold" or nil, nil, true)
      r.onClick = function() state.profSel = name; state.profFull = true; RG.RefreshUINow() end
    end
  end
  return n
end

local function renderRoute()
  local lvl = UnitLevel("player")
  local mining = RG.Skill("Mining") or 0
  local n = 0
  local KIND = { zone = GREY .. "Questing|r", dungeon = "|cffA58BD8Dungeon|r", pala = GOLD .. "Paladin|r", travel = "|cff6FA8DCTravel|r" }
  local ICON = { zone = 134269, dungeon = 136058, pala = 135920, travel = "Interface\\Icons\\Ability_Mount_Wyvern_01" }
  RG.db.stepsDone = RG.db.stepsDone or {}
  state.showDone = state.showDone or {}
  local list = {}
  for i, r in ipairs(RG.ROUTE) do list[i] = r end
  for _, t in ipairs(RG.TRAVEL or {}) do list[#list + 1] = { from = t.lvl, to = t.lvl, kind = "travel", zone = "Travel", hub = "", notes = t.text, fp = t.fp, travel = true } end
  local ORDER = { pala = 0, travel = 1, zone = 2, dungeon = 3 }
  table.sort(list, function(a, b) if a.from ~= b.from then return a.from < b.from end return (ORDER[a.kind] or 9) < (ORDER[b.kind] or 9) end)

  -- work out each entry: its steps, which are done, and where it belongs (now / next / later / done)
  local entries = {}
  for _, r in ipairs(list) do
    local e = { r = r, key = r.zone .. "|" .. r.from }
    e.steps = RG.STEPS and RG.STEPS[e.key]
    e.past = lvl > r.to
    e.dq = r.kind == "dungeon" and RG.DUNGEON_QUESTS[r.zone]
    e.dqDone = e.dq and RG.DungeonQuestsDone and RG.DungeonQuestsDone(e.dq)
    e.auto, e.doneN = {}, 0
    if e.steps then
      for i, text in ipairs(e.steps) do
        local ok, why
        if RG.StepAuto then ok, why = RG.StepAuto(r, text) end
        if not ok and e.dqDone then ok, why = true, "all of this dungeon's quests are turned in" end
        if ok then e.auto[i] = why end
        if ok or RG.db.stepsDone[e.key .. "#" .. i] or e.past then e.doneN = e.doneN + 1 end
      end
    end
    if r.kind == "travel" then
      local k = r.fp and RG.KnowsFP(r.fp)
      e.done = (k == true) or lvl > r.from + 2
    elseif e.dq then
      e.done = e.dqDone or e.past
    elseif e.steps then
      e.done = e.doneN >= #e.steps
    else
      e.done = e.past
    end
    if e.done then e.where = "done"
    elseif lvl >= r.from and lvl <= r.to then e.where = "now"
    elseif r.from <= lvl + 5 then e.where = "next"
    else e.where = "later" end
    -- a dungeon you're collecting quests for counts as "now"
    if e.dq and not e.done and lvl >= e.dq.prep and lvl <= r.to then e.where = "now" end
    entries[#entries + 1] = e
  end

  -- one route entry: a card, then (when open) its unfinished steps, dungeon quests, camp and bank-alt items
  local function card(e, openDefault)
    local r = e.r
    local now = e.where == "now"
    n = n + 1
    local row = getRow(n)
    local col = e.done and GREY or (now and GOLD or "|cffffffff")
    local gather = not e.done and RG.GatherHere and RG.GatherHere(r.zone)
    local sub = (r.notes ~= "" and r.notes or r.hub)
    if gather then sub = sub .. GREY .. "  ·  " .. gather .. "|r" end
    local range = r.from == r.to and ("Level " .. r.from) or ("Levels " .. r.from .. "-" .. r.to)
    local status = e.done and (GREEN .. "Done|r") or (now and (GREEN .. "You are here|r") or (GREY .. range .. "|r"))
    if r.fp and not e.done then
      local k = RG.KnowsFP(r.fp)
      if k == false and lvl >= r.from - 1 then status = GOLD .. "Grab the " .. r.fp .. " flight path|r"
      elseif k == true and r.kind ~= "travel" then sub = sub .. GREY .. "  ·  flight path learned|r" end
    end
    if e.dq then
      if e.dqDone then status = GREEN .. "Quests done|r"
      elseif lvl >= e.dq.prep and lvl < e.dq.go then status = GOLD .. "Collect quests now|r"
      elseif lvl >= e.dq.go and lvl <= r.to then status = GREEN .. "Go now|r" end
      sub = "Head over at level " .. e.dq.go .. GREY .. "  ·  " .. (e.dq.note or r.notes) .. "|r"
    end
    local titleText = r.kind == "travel" and ("|cff6FA8DC" .. "Travel" .. "|r" .. GREY .. "   level " .. r.from .. "|r") or (col .. r.zone .. "|r" .. GREY .. (r.kind == "pala" and "" or ("   " .. r.hub)) .. "|r")
    local open = e.steps and not e.done and ((state.open[e.key] == nil and openDefault) or state.open[e.key] == true)
    local left = e.steps and (#e.steps - e.doneN) or 0
    local meta = (KIND[r.kind] or "") .. (e.steps and (GREY .. "   ·   " .. (e.done and ("all " .. #e.steps .. " done") or (left .. " to do")) .. (open and "  ·  hide" or "") .. "|r") or "")
    local accent = e.done and nil or (now and "gold" or (r.kind == "pala" and "gold" or (r.kind == "dungeon" and "purple" or (r.kind == "travel" and "blue" or nil))))
    setItem(row, nil, nil, titleText, e.done and "" or sub, status, meta, accent, nil, e.done)
    if e.steps and not e.done then row.onClick = function() state.open[e.key] = not open; RG.RefreshUI() end end
    local ew = RG.WAYPOINTS and (RG.WAYPOINTS.dungeons[r.zone] or (RG.StepWaypoint and RG.StepWaypoint(r, 1)))
    if ew then row.onRightClick = function() RG.PinWaypoint(ew) end; row.tip = (e.steps and not e.done and "Click to open the steps. " or "") .. "Right-click: show " .. ew[4] .. " on the map." end
    row.icon:SetTexture(ICON[r.kind] or 134269)
    if e.done then return end
    -- how to get there from where you are
    if (now or open) and r.kind ~= "pala" and r.kind ~= "travel" and RG.TravelPlan and RG.Opt("travelTips") then
      local legs, to = RG.TravelPlan(r.zone)
      if legs and #legs > 0 then
        local parts = {}
        for i, l in ipairs(legs) do parts[#parts + 1] = (l.how == "tip" and GREY or "|cffffffff") .. i .. ". " .. l.text .. "|r" end
        n = n + 1
        setItem(getRow(n), nil, nil, GOLD .. "Getting to " .. to .. "|r", table.concat(parts, GREY .. "   |r"), "", "", "blue", nil, true)
        rows[n].icon:SetTexture("Interface\\Icons\\Ability_Mount_Wyvern_01")
      end
    end
    -- unfinished steps (finished ones hidden behind a "show" line)
    if open then
      local showAll = state.showDone[e.key]
      local num = 0
      for i, text in ipairs(e.steps) do
        local sk = e.key .. "#" .. i
        local auto = e.auto[i]
        local isDone = auto or RG.db.stepsDone[sk] or e.past
        if not isDone or showAll then
          num = num + 1
          n = n + 1
          local wp = RG.StepWaypoint and RG.StepWaypoint(r, i)
          local srow = getRow(n)
          -- generated steps: a short title here, the quests one per row below
          local ql, qd, qt, place, levels
          if RG.StepQuestLines then ql, qd, qt, place, levels = RG.StepQuestLines(r, i) end
          local shown = text
          if ql and place then shown = place .. (levels and (" (" .. levels .. ")") or "") .. GREY .. "  ·  " .. qd .. "/" .. qt .. " quests done|r" end
          setStep(srow, i, (wp and RG.PIN or "") .. shown, isDone, function()
            if RG.db.stepsDone[sk] then RG.db.stepsDone[sk] = nil; RG.RefreshUI(); if RG.RefreshTracker then RG.RefreshTracker() end
            elseif RG.TickStep then RG.TickStep(sk, text) else RG.db.stepsDone[sk] = true; RG.RefreshUI() end
          end, auto or (e.past and not RG.db.stepsDone[sk] and "you've outleveled this part of the route" or nil))
          if wp then
            srow.onRightClick = function() RG.PinWaypoint(wp) end
            srow.tip = (srow.tip or "") .. "\n|cffffd100Right-click: show " .. wp[4] .. " on the map and follow the arrow|r"
          end
          -- quests this step names that are in your log: click to open them
          if not isDone and ql then
            local VERB = { turnin = GREEN .. "Hand in|r ", pickup = "|cffffd100Pick up|r ", doing = "|cffffffffDo|r ", later = GREY .. "Later:|r " }
            for _, l in ipairs(ql) do
              n = n + 1
              local qr = getRow(n)
              local sub
              if l.act == "turnin" then sub = GREEN .. "Done: take it to " .. (l.npc or "the quest giver") .. "|r"
              elseif l.act == "pickup" then sub = GREY .. (l.npc and ("Get it from " .. l.npc) or "Starts from an item or object") .. "|r"
              elseif l.act == "doing" then sub = GREY .. "In your quest log" .. (l.prog and (": " .. l.prog) or "") .. "|r"
              else sub = GREY .. "Opens " .. l.npc .. "|r" end
              setItem(qr, nil, nil, VERB[l.act] .. RG.LevelTag(l.level) .. (l.act == "later" and GREY or "|cffffffff") .. l.name .. "|r", sub, nil, "", nil, nil, true)
              qr.icon:SetTexture(136797)
              local lw = l.wp
              qr.onClick = function() if l.act == "doing" then RG.OpenQuest(l.name, l.id) elseif lw then RG.PinWaypoint(lw) end end
              qr.onRightClick = lw and function() RG.PinWaypoint(lw) end or nil
              qr.onDoubleClick = lw and function() RG.ArrowTo(lw) end or nil
              qr.tip = (l.act == "doing" and "Click to open it in your quest log." or (lw and ("Click: show " .. lw[4] .. " on the map\nDouble-click: arrow on / off") or "")) 
            end
          elseif not isDone then
            for _, q in ipairs(RG.QuestsInText and RG.QuestsInText(text) or {}) do
              n = n + 1
              local qr = getRow(n)
              setItem(qr, nil, nil, RG.LevelTag(q.level or RG.QuestLevel(q.title)) .. "|cffffd100" .. q.title .. "|r", GREY .. "Click to open it in your quest log|r",
                q.complete and (GREEN .. "Ready to turn in|r") or (GOLD .. "In your log|r"), "", nil, nil, true)
              qr.icon:SetTexture(136797)
              qr.onClick = function() RG.OpenQuest(q.title, q.id) end
              qr.tip = "Click to open " .. q.title .. " in your quest log."
            end
          end
        end
      end
      if e.doneN > 0 then
        n = n + 1
        local tr = getRow(n)
        setStep(tr, "", GREY .. (showAll and ("Hide the " .. e.doneN .. " finished step" .. (e.doneN > 1 and "s" or "")) or ("+ " .. e.doneN .. " finished step" .. (e.doneN > 1 and "s" or "") .. " hidden  ·  click to show")) .. "|r", false, function() state.showDone[e.key] = not showAll; RG.RefreshUI() end)
        tr.iconBorder:Hide(); tr.icon:Hide(); tr.tip = nil
      end
    end
    -- dungeon quests still to do
    if e.dq and lvl >= e.dq.prep - 4 then
      for _, q in ipairs(e.dq.quests) do
        local qs = RG.QuestState and RG.QuestState((q[1]:gsub("%s*%(.-%)$", "")))
        if qs ~= "done" then
          n = n + 1
          local qr = getRow(n)
          local pill = qs == "ready" and (GREEN .. "Ready to turn in|r") or (qs == "log" and (GOLD .. "In your log|r") or (GREY .. "Pick up|r"))
          local gw = q.wp or (RG.WAYPOINTS and RG.WAYPOINTS.givers[q[2]])
          setItem(qr, nil, nil, RG.LevelTag(RG.QuestLevel(q[1])) .. "|cffffd100" .. q[1] .. "|r", (gw and RG.PIN or "") .. q[2] .. GREY .. "  ·  " .. q[3] .. "|r", pill, "", nil, nil, true)
          qr.icon:SetTexture(136797)
          local title = q[1]
          if qs == "log" or qs == "ready" then
            qr.onClick = function() RG.OpenQuest(title) end
            qr.tip = "Click to open it in your quest log." .. (gw and ("\nRight-click: show " .. q[2] .. " on the map.") or "")
            if gw then qr.onRightClick = function() RG.PinWaypoint(gw) end end
          elseif gw then qr.onClick = function() RG.PinWaypoint(gw) end; qr.onRightClick = qr.onClick; qr.tip = "Click to show " .. q[2] .. " on the map." end
        end
      end
    end
    -- the dungeon's best drops for you
    if e.dq and lvl >= e.dq.prep - 4 and RG.DungeonDrops then
      for _, dd in ipairs(RG.DungeonDrops(r.zone, 3)) do
        n = n + 1
        local name, link2, quality = itemName(dd.g.id)
        setItem(getRow(n), dd.g.id, link2, name .. GREY .. "   " .. (GUIDE_SLOT_LABEL[dd.g.slot] or dd.g.slot) .. "|r", GREY .. "Drops from " .. dd.g.src .. "|r",
          GREEN .. string.format("+%.0f", dd.d) .. "|r", dd.g.lvl > lvl and (GREY .. "level " .. dd.g.lvl .. "|r") or "", nil, quality, true)
      end
    end
    -- camping / fishing / cooking and bank-alt items for the zone you're in
    if now and RG.CampForEntry then
      for _, cs in ipairs(RG.CampForEntry(r)) do
        if not RG.CampPlanDone(cs) then
          n = n + 1
          local cr = getRow(n)
          setItem(cr, nil, nil, "|cffffffff" .. cs.text .. "|r", "", GOLD .. "Camp · fish · cook|r", "", nil, nil, true)
          cr.icon:SetTexture("Interface\\Icons\\Spell_Fire_Fire")
          cr.onClick = function() RG.ShowTab("camp") end
          local cw = RG.CampWaypoint and RG.CampWaypoint(cs)
          if cw then cr.onRightClick = function() RG.PinWaypoint(cw) end; cr.tip = "Click for the Camp tab. Right-click: show " .. cw[4] .. " on the map." end
        end
      end
    end
    if now and RG.MailForEntry then
      for _, m in ipairs(RG.MailForEntry(r)) do
        if not m.done then
          n = n + 1
          local mr = getRow(n)
          local have = m.missing == 0 and (GREEN .. "Have it|r") or (m.selfMade and (GREEN .. "You can make it|r") or (GOLD .. "Bank alt: mail it|r"))
          local what = m.q.any and (m.missing .. " of " .. #m.items .. " pages missing") or (m.items[1].count .. "x " .. m.items[1].name)
          setItem(mr, not m.q.any and m.items[1].id or nil, nil, "|cffffd100" .. m.q.quest .. "|r" .. GREY .. "   level " .. m.q.lvl .. "|r", what .. GREY .. "  ·  " .. m.q.giver .. "|r", have, m.q.any and "" or (RG.PriceText(m.items[1].id) or ""), m.missing == 0 and "green" or nil, nil, true)
          mr.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
          local mq = m.q.quest
          local inLog = RG.InLog and RG.InLog(mq)
          mr.onClick = function() if not (inLog and RG.OpenQuest(mq)) then RG.ShowTab("mail") end end
          local mw = RG.WaypointForText and RG.WaypointForText(m.q.giver)
          mr.tip = (inLog and "Click to open it in your quest log." or "Click for the Bank alt tab.") .. (mw and (" Right-click: show " .. mw[4] .. " on the map.") or "")
          if mw then mr.onRightClick = function() RG.PinWaypoint(mw) end end
        end
      end
    end
  end

  -- a foldable section header
  local function section(label, key, count, defaultOpen)
    n = n + 1
    local r = getRow(n)
    local isOpen = state[key]
    if isOpen == nil then isOpen = defaultOpen end
    setHeader(r, (isOpen and "- " or "+ ") .. label .. (count and (GREY .. "   " .. count .. "|r") or ""))
    r.onClick = function() state[key] = not isOpen; RG.RefreshUI() end
    r.tip = isOpen and "Click to fold this section." or "Click to show this section."
    return isOpen
  end
  local function count(where) local c = 0; for _, e in ipairs(entries) do if e.where == where then c = c + 1 end end; return c end

  -- leveling pace: one line (click for splits)
  if RG.Pace and not (RG.IsAlt and RG.IsAlt()) then
    local cur, last, avg = RG.Pace()
    local eta
    if RG.XPRate then eta = select(2, RG.XPRate()) end
    n = n + 1
    local pr = getRow(n)
    setItem(pr, nil, nil, "|cffffffffLevel " .. lvl .. "|r" .. GREY .. "   " .. RG.FormatDuration(cur) .. " so far" .. (eta and ("  ·  next level in about " .. (RG.FormatETA(eta) or "?")) or "") .. "|r",
      last and (GREY .. "Last level " .. RG.FormatDuration(last) .. "  ·  average of last 5: " .. RG.FormatDuration(avg) .. "|r") or (GREY .. "Times for earlier levels appear after your next level-up|r"),
      state.pace and (GREY .. "hide splits|r") or (GREY .. "show splits|r"), "", "gold", nil, true)
    pr.icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
    pr.onClick = function() state.pace = not state.pace; RG.RefreshUI() end
    if state.pace then
      local t = RG.db.levelTime or {}
      local maxT = 1
      for l = math.max(1, lvl - 12), lvl do if t[l] and t[l] > maxT then maxT = t[l] end end
      for l = lvl, math.max(1, lvl - 12), -1 do
        if t[l] then
          n = n + 1
          setBar(getRow(n), "Level " .. l .. (l == lvl and "  (now)" or ""), t[l], maxT, l == lvl and T.gold or T.goldDim, RG.FormatDuration(t[l]))
        end
      end
    end
  end

  -- Now: always open, steps showing
  if section("Now  ·  level " .. lvl, "secNow", nil, true) then
    local any = false
    for _, e in ipairs(entries) do if e.where == "now" then card(e, true); any = true end end
    if not any then
      n = n + 1; setItem(getRow(n), nil, nil, GREEN .. "Everything for your level is done.|r", "Your next zones are under Coming up.", "", "", "green", nil, true)
    end
  end
  -- Coming up: the next 5 levels, closed until you open them
  local nNext = count("next")
  if nNext > 0 and section("Coming up  ·  next 5 levels", "secNext", nNext .. " to do", true) then
    for _, e in ipairs(entries) do if e.where == "next" then card(e, false) end end
  end
  -- Later: the rest of the route, by level bracket
  local nLater = count("later")
  if nLater > 0 and section("Later", "secLater", nLater .. " to do", false) then
    local lastBracket
    for _, e in ipairs(entries) do
      if e.where == "later" then
        local r = e.r
        local bracket = r.from >= 60 and "Level 60" or ("Levels " .. (math.floor(r.from / 10) * 10) .. "-" .. (math.floor(r.from / 10) * 10 + 9))
        if bracket ~= lastBracket then
          n = n + 1; setStep(getRow(n), "", GOLD .. bracket .. "|r", false, nil)
          rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
          lastBracket = bracket
        end
        card(e, false)
      end
    end
  end
  -- Done: hidden unless you open it
  local nDone = count("done")
  if nDone > 0 and section("Done", "secDone", nDone .. " finished", false) then
    for i = #entries, 1, -1 do local e = entries[i]; if e.where == "done" then card(e, false) end end
  end
  return n
end

local function renderAH()
  local ids = RG.TrackedIDs()
  table.sort(ids, function(a, b) local ga, gb = RG.GuideByID[a], RG.GuideByID[b]; return (ga and ga.lvl or 99) < (gb and gb.lvl or 99) end)
  local n = 0
  -- scan status
  local st = RG.AHScanState and RG.AHScanState()
  local last = RG.db.lastFullScan
  local mins = last and math.floor((time() - last) / 60)
  n = n + 1
  setItem(getRow(n), nil, nil, st and (GOLD .. "Checking prices: " .. st .. "|r") or "|cffffffffPrices|r",
    st and "Search for anything yourself and Waypath+ steps aside right away." or ((mins and ("Last full scan " .. (mins < 60 and (mins .. " min") or (math.floor(mins / 60) .. " h")) .. " ago.  ") or "") .. "Opening the AH checks only out-of-date prices, or does one full scan when the server allows it (every 15 min)."),
    st and (GREY .. "click to stop|r") or "", "", st and "gold" or nil, nil, true)
  rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  if st then rows[n].onClick = function() if RG.StopAHScan then RG.StopAHScan() end end end
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
  -- Things in your bags worth more on the AH than at a vendor
  if RG.ProfitList and RG.Opt("profitWatch") then
    local items, unpriced, total = RG.ProfitList()
    if #items > 0 then
      n = n + 1; setHeader(getRow(n), "In your bags: sell on the AH, not the vendor  (+" .. RG.Money(total) .. ")")
      for _, e in ipairs(items) do
        n = n + 1
        local name, link, quality = itemName(e.id)
        setItem(getRow(n), e.id, link or e.link, name .. (e.count > 1 and (GREY .. "  x" .. e.count .. "|r") or ""),
          GREY .. "You keep |r" .. RG.Money(e.p.net) .. GREY .. " each after the AH cut  ·  vendor pays |r" .. RG.Money(e.p.vendor),
          GREEN .. "+" .. RG.Money(e.total) .. "|r", RG.PriceText(e.id) or "", "gold", quality)
      end
    end
    if #unpriced > 0 then
      n = n + 1; setHeader(getRow(n), "In your bags: not priced yet (open the AH to check)")
      for _, e in ipairs(unpriced) do
        n = n + 1
        local name, link, quality = itemName(e.id)
        setItem(getRow(n), e.id, link or e.link, name, GREY .. "Tradeable, so it might sell well. Vendor pays |r" .. RG.Money(e.p and e.p.vendor or 0), GOLD .. "Check price|r", "", nil, quality)
      end
    end
  end
  block("Gear you can buy", gear)
  block("Ore and bars", mats)
  if n == 0 then n = 1; setHeader(getRow(1), "Nothing tracked yet · /wp track [item link]") end
  return n
end


local GOLD_ICON = {
  ["Auction House"] = "Interface\\Icons\\INV_Misc_Coin_01",
  Mining = "Interface\\Icons\\Trade_Mining",
  Blacksmithing = "Interface\\Icons\\Trade_BlackSmithing",
  Farming = "Interface\\Icons\\INV_Fabric_Linen_01",
  Forever = "Interface\\Icons\\INV_Misc_Note_01",
  Fishing = "Interface\\Icons\\Trade_Fishing",
}
local function renderGold()
  local n = 0
  local G = RG.GOLD
  -- live: what your bags are worth on the AH
  if RG.ProfitList and RG.Opt("profitWatch") then
    local items, _, total = RG.ProfitList()
    n = n + 1
    if #items > 0 then
      setItem(getRow(n), nil, nil, GOLD .. "Your bags right now|r", #items .. " item" .. (#items > 1 and "s" or "") .. " sell for more on the AH than at a vendor. Click to see them.", GREEN .. "+" .. RG.Money(total) .. "|r", "", "gold")
      rows[n].onClick = function() state.tab = "ah"; RG.RefreshUI() end
    else
      setItem(getRow(n), nil, nil, GOLD .. "Your bags right now|r", "Nothing to take to the AH yet. Open the Auction House now and then so Waypath+ knows the prices.", "", "", "gold")
    end
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
  end
  local prof = RG.Professions()
  local tips = RG.GoldTips(state.goldAll)
  local order, byCat = {}, {}
  for _, t in ipairs(tips) do
    if not byCat[t.cat] then byCat[t.cat] = {}; order[#order + 1] = t.cat end
    table.insert(byCat[t.cat], t)
  end
  for _, cat in ipairs(order) do
    n = n + 1; setHeader(getRow(n), cat == "Forever" and "New in WoW Forever" or cat)
    for _, t in ipairs(byCat[cat]) do
      n = n + 1
      local missing = t.prof and not prof[t.prof]
      local right = missing and (GREY .. "needs " .. t.prof .. "|r") or (GREY .. "levels " .. t.from .. "-" .. t.to .. "|r")
      setItem(getRow(n), nil, nil, (missing and GREY or "|cffffffff") .. t.title .. "|r", t.text, right, "", nil)
      rows[n].icon:SetTexture(GOLD_ICON[cat] or (RG.PROFESSIONS[cat] and RG.PROFESSIONS[cat].icon) or "Interface\\Icons\\INV_Misc_Coin_02")
      if t.ids and not missing then
        for _, id in ipairs(t.ids) do
          n = n + 1
          local name, link, quality = itemName(id)
          local p = RG.ProfitInfo and RG.ProfitInfo(id)
          local vend = p and p.vendor and p.vendor > 0 and (GREY .. "vendor |r" .. RG.Money(p.vendor)) or ""
          setItem(getRow(n), id, link, name, vend, "", RG.PriceText(id) or (GREY .. "not seen yet|r"), nil, quality, true)
        end
      end
    end
  end
  n = n + 1
  setStep(getRow(n), "", "Show tips for every level, not just mine", state.goldAll, function() state.goldAll = not state.goldAll; RG.RefreshUI() end)
  n = n + 1; setHeader(getRow(n), "Tips updated " .. G.updated .. "  ·  " .. G.note)
  return n
end

-- ---------------------------------------------------------------------------
-- 2nd Spec: pick any spec of your class, its build and tips (Classes/Specs.lua)
-- ---------------------------------------------------------------------------
local KIND_COLOR = { heal = "|cff7CFC9A", tank = "|cff9FB8FF", melee = "|cffFF9F7A", ranged = "|cffFFD27A", caster = "|cffC9A0FF" }
local function specIcon(r, s) r.icon:SetTexture(s and s.icon or "Interface\\Icons\\INV_Misc_QuestionMark") end
local function dualSpecRows(n, s)
  local lvl = UnitLevel("player")
  local ds = RG.HasDualSpec and RG.HasDualSpec()
  local at = RG.DUAL_SPEC_LEVEL or 40
  n = n + 1
  local dsText = lvl < at and ("Unlocks at level " .. at .. " (" .. (at - lvl) .. " to go). Start saving " .. s.name .. " pieces now: the Gear tab lists them.")
    or (ds and ("You have dual spec. Switch at your class trainer, then put on your " .. s.name .. " set.") or "Unlocked! Visit your class trainer in a capital city to learn it.")
  setItem(getRow(n), nil, nil, "|cffF58CBADual spec: " .. s.name .. "|r", dsText, ds and (GREEN .. "Ready|r") or (lvl >= at and (GOLD .. "Go learn it|r") or (GREY .. "Level " .. at .. "|r")), "", "gold")
  specIcon(rows[n], s)
  local _, total = RG.SpecSet()
  if total > 0 then
    n = n + 1
    local wearing = RG.db.wearingHeal
    local main = RG.MainSpec and RG.MainSpec()
    local mainName = main and main.name or "main"
    setItem(getRow(n), nil, nil, wearing and ("|cffffffffPut your " .. mainName .. " gear back on|r") or ("|cffffffffEquip your " .. s.name .. " set|r"),
      wearing and ("Re-equips the " .. mainName .. " gear you wore before the swap.") or ("Puts on the best " .. s.name .. " piece from your bags for each slot and remembers your " .. mainName .. " gear. Also: /wp gear 2, /wp gear 1."),
      GOLD .. "Swap|r", "", "gold")
    if wearing then specIcon(rows[n], main) else specIcon(rows[n], s) end
    rows[n].onClick = function() if RG.SwapGear then RG.SwapGear() end end
  end
  return n
end

local function renderSpec()
  local n = 0
  local list = RG.SpecList and RG.SpecList() or {}
  if #list == 0 then n = n + 1; setHeader(getRow(n), "No spec data for your class yet"); return n end
  local cur = RG.SecondSpec and RG.SecondSpec()
  n = n + 1; setHeader(getRow(n), "Pick your 2nd spec  ·  click one")
  for _, s in ipairs(list) do
    n = n + 1
    local chosen = cur and cur.key == s.key
    local pill
    if chosen and s.main then pill = GOLD .. "You level as this|r"
    elseif chosen then pill = GREEN .. "Your 2nd spec|r"
    elseif s.main then pill = GREY .. "Leveling spec|r"
    else pill = GOLD .. "Choose|r" end
    setItem(getRow(n), nil, nil, (chosen and "|cffffffff" or "|cffd8d0c0") .. s.name .. "|r  " .. (KIND_COLOR[s.kind] or "") .. s.role .. "|r",
      GREY .. s.stats .. "|r", pill, "", chosen and "green" or nil)
    specIcon(rows[n], s)
    rows[n].onClick = function() RG.SetSecondSpec(s.key) end
  end
  if not cur then
    n = n + 1
    setItem(getRow(n), nil, nil, GREY .. "No 2nd spec yet|r", GREY .. "Pick one above: Waypath+ then collects gear for it, never sells it, and swaps it on when you change spec. Dual spec unlocks at level " .. (RG.DUAL_SPEC_LEVEL or 40) .. ".|r", "", "", nil, nil, true)
    return n
  end
  if cur.main then
    n = n + 1
    setItem(getRow(n), nil, nil, GOLD .. cur.name .. " is the spec you level with|r", GREY .. "Your Gear guide already follows it. Pick one of the other specs to collect a second set.|r", "", "", nil, nil, true)
  else
    n = dualSpecRows(n, cur)
    local guide = RG.SpecGuide(cur)
    local lvl = UnitLevel("player")
    local soon = 0
    for _, g in ipairs(guide) do if g.lvl <= lvl + 5 and not RG.OwnState(g.id) then soon = soon + 1 end end
    n = n + 1
    setItem(getRow(n), nil, nil, "|cffffffff" .. cur.name .. " gear to collect|r", soon > 0 and (soon .. " piece" .. (soon > 1 and "s" or "") .. " you can get within 5 levels, slot by slot, with where they drop.") or "Your set, slot by slot, and what to hunt for next.", GOLD .. "Open|r", "", "gold")
    specIcon(rows[n], cur)
    rows[n].onClick = function() state.tab = "heal"; scroll:SetVerticalScroll(0); RG.RefreshUINow() end
  end
  n = n + 1
  setItem(getRow(n), nil, nil, GOLD .. "Stats:|r " .. cur.stats, "", "", "", nil, nil, true)
  rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
  n = n + 1; setHeader(getRow(n), "Playing " .. cur.name)
  for _, t in ipairs(cur.tips or {}) do
    n = n + 1
    setItem(getRow(n), nil, nil, "|cffffffff" .. t .. "|r", "", "", "", nil, nil, true)
    specIcon(rows[n], cur)
  end
  if cur.forever and #cur.forever > 0 then
    n = n + 1; setHeader(getRow(n), "New in WoW Forever")
    for _, t in ipairs(cur.forever) do
      n = n + 1
      setItem(getRow(n), nil, nil, "|cffffffff" .. t .. "|r", "", "", "", nil, nil, true)
      rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Pearl_04")
    end
  end
  n = n + 1; setHeader(getRow(n), "Guide: " .. ((cur.source or ""):gsub("^https?://", ""):gsub("^www%.", "")) .. "  ·  updated " .. (RG.SPECS_UPDATED or ""))
  return n
end

-- ---------------------------------------------------------------------------
-- 2nd Spec > Gear: your 2nd set slot by slot, then what to hunt for by level
-- ---------------------------------------------------------------------------
local HOW_ICON = { Drop = 133639, Quest = 136797, Crafted = 136241, BoE = 133784, Dungeon = 136058, Vendor = 133784, ["Rare mob"] = 133639 }
local function renderHeal()
  local n = 0
  local s = RG.SecondSpec and RG.SecondSpec()
  if not s or s.main then
    n = n + 1
    setItem(getRow(n), nil, nil, GOLD .. (s and (s.name .. " is your leveling spec") or "Pick a 2nd spec first") .. "|r", GREY .. "Choose any other spec of your class on the Spec page: this page then lists the gear to start collecting for it.|r", GOLD .. "Choose|r", "", "gold")
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    rows[n].onClick = function() state.tab = "spec"; RG.RefreshUINow() end
    return n
  end
  local lvl = UnitLevel("player")
  local set, total = RG.SpecSet()
  local guide = RG.SpecGuide(s)
  n = dualSpecRows(n, s)
  -- your set, slot by slot
  local slots = RG.SpecSlots(s)
  local filled = 0
  for _, g in pairs(set) do filled = filled + #g end
  n = n + 1; setHeader(getRow(n), string.format("Your %s set  ·  %d of %d slots  ·  %s score %.0f", s.name, filled, #slots, s.name, total))
  local used = {}
  local hasTwoHand = set["Main Hand"] and set["Main Hand"][1] and RG.EquipLoc(set["Main Hand"][1].link) == "INVTYPE_2HWEAPON"
  for _, slot in ipairs(slots) do
    used[slot] = (used[slot] or 0) + 1
    local p = set[slot] and set[slot][used[slot]]
    if not (slot == "Off Hand" and hasTwoHand) then
      -- next thing on the list for this slot that you can use soon and don't own
      local nextG
      for _, g in ipairs(guide) do
        local gs = g.slot == "Two-Hand" and "Main Hand" or g.slot
        if gs == slot and g.lvl <= lvl + 5 and not RG.OwnState(g.id) then
          local link = select(2, RG.ItemInfo(g.id))
          local better = not p or not link or RG.SpecScore(link, s) > p.score + 0.5
          if better then nextG = g; break end
        end
      end
      n = n + 1
      local r = getRow(n)
      local hunt = nextG and ((RG.ItemInfo(nextG.id) or "item") .. GREY .. "  ·  " .. nextG.src .. ", " .. nextG.zone .. "|r") or nil
      if p then
        local name, _, quality = RG.ItemInfo(p.link)
        local where = p.where == "worn" and "wearing it" or (p.where == "bank" and "in your bank" or "in your bags")
        setItem(r, p.id, p.link, (name or p.link) .. GREY .. "   " .. slot .. "|r", hunt and (GOLD .. "Next: |r" .. hunt) or (GREY .. "Nothing better on the list yet|r"), GREEN .. string.format("%.0f", p.score) .. "|r", GREY .. where .. "|r", nil, quality, true)
      else
        setItem(r, nextG and nextG.id or nil, nil, GREY .. slot .. ": nothing yet|r", hunt and (GOLD .. "Look for: |r" .. hunt) or (GREY .. "Any piece with " .. s.stats:match("^[^,]+") .. " will do|r"), "", "", nil, nil, true)
        if not nextG then r.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot") end
      end
      if nextG then r.onClick = function() RG.ShowItemSource(nextG, { note = GOLD .. "Next for your " .. s.name .. " " .. slot .. "|r" }) end end
    end
  end
  -- the hunting list, in 5-level steps, each named after where most of it comes from
  local bs = RG.Skill and RG.Skill("Blacksmithing") or 0
  for lo = 25, 60, 5 do
    local hi = lo + 4
    if state.healAll or hi >= lvl - 3 then
      local inBand, zones, zcount = {}, {}, {}
      for _, g in ipairs(guide) do
        if g.lvl >= lo and g.lvl <= hi then
          inBand[#inBand + 1] = g
          if g.zone and g.zone ~= "" then
            if not zcount[g.zone] then zones[#zones + 1] = g.zone end
            zcount[g.zone] = (zcount[g.zone] or 0) + 1
          end
        end
      end
      if #inBand > 0 then
        table.sort(zones, function(a, b) return zcount[a] > zcount[b] end)
        local top = {}
        for i = 1, math.min(3, #zones) do top[i] = zones[i] end
        n = n + 1; setHeader(getRow(n), "Levels " .. math.max(lo, 28) .. "-" .. math.min(hi, 60) .. (#top > 0 and ("  ·  " .. table.concat(top, ", ")) or ""))
        for _, g in ipairs(inBand) do
          n = n + 1
          local name, link, quality = itemName(g.id)
          local own = RG.OwnState(g.id)
          local pill
          if own == "equipped" then pill = GREEN .. "Wearing it|r"
          elseif own then pill = GREEN .. "Saved|r"
          elseif g.bs then pill = bs >= g.bs and (GREEN .. "You can make it|r") or (GOLD .. "Blacksmithing " .. g.bs .. "|r")
          elseif lvl < g.lvl then pill = GREY .. "Level " .. g.lvl .. (g.approx and "ish" or "") .. "|r"
          else pill = GOLD .. "Go get it|r" end
          local score = link and RG.SpecScore(link, s) or (g.score or 0)
          local sub = g.src .. GREY .. "  ·  " .. g.zone .. "  ·  " .. g.slot .. (g.note and ("  ·  " .. g.note) or "") .. "|r"
          setItem(getRow(n), g.id, link, name, sub, pill, g.ah and RG.PriceText(g.id) or (GREY .. s.name .. " " .. string.format("%.0f", score) .. "|r"), own and "green" or nil, quality)
          if not link then rows[n].icon:SetTexture(HOW_ICON[g.how] or 134400) end
          rows[n].onClick = function() RG.ShowItemSource(g) end
        end
      end
    end
  end
  n = n + 1
  setStep(getRow(n), "", "Show the list for every level, not just mine", state.healAll, function() state.healAll = not state.healAll; RG.RefreshUI() end)
  n = n + 1; setHeader(getRow(n), "Collecting a 2nd set")
  local tips = {
    "Collect from level 30: dual spec unlocks at " .. (RG.DUAL_SPEC_LEVEL or 40) .. " in WoW Forever, at your class trainer in a capital city.",
    "Everything in your " .. s.name .. " set is marked in your bags, and Waypath+ won't vendor or auction it.",
    "Two sets fill your bags fast: buy bigger bags and park the set in your bank between runs (open your bank once so Waypath+ remembers it).",
    "Save the set in the game's Equipment Manager too, or use the Swap button above (/wp gear 2, /wp gear 1).",
    "Scores use " .. s.name .. "'s own stat values. Forever loot is still being mapped: the list updates twice a week.",
  }
  for _, t in ipairs(tips) do
    n = n + 1
    setItem(getRow(n), nil, nil, "|cffffffff" .. t .. "|r", "", "", "", nil, nil, true)
    specIcon(rows[n], s)
  end
  return n
end

local function ago(t)
  local m = math.floor((time() - (t or time())) / 60)
  if m < 1 then return "just now" elseif m < 60 then return m .. "m ago" elseif m < 1440 then return math.floor(m / 60) .. "h ago" end
  return math.floor(m / 1440) .. "d ago"
end

local function renderMail()
  local n = 0
  local alt = RG.IsAlt()
  local main = RG.MainName() or "your main"
  n = n + 1
  setItem(getRow(n), nil, nil, alt and ("|cffffffffBank alt for " .. main .. "|r") or "|cffffffffYour bank alt|r",
    alt and "Buy what's below on the AH (click an item to search for it), then open a mailbox and press the Waypath+ button to attach it all."
      or "These quests use items you can buy. Have your bank alt buy them and mail them here. Log in on the alt to see the same list.",
    alt and (GOLD .. "Main: " .. main .. "|r") or (GREY .. "Main: " .. (RG.db.main and main or "not set") .. "|r"), "", "gold")
  rows[n].icon:SetTexture("Interface\\Icons\\INV_Letter_15")
  -- secret bank-alt guide: open on an alt still setting up, folded on your main (/wp bankalt opens it)
  if RG.ALT_STEPS then
    local open = state.altGuide
    if open == nil then open = RG.altGuideOpen or (alt and RG.AltGuideActive and RG.AltGuideActive()) or false end
    n = n + 1
    local done, total = 0, #RG.ALT_STEPS
    if alt and RG.AltGuideProgress then done = RG.AltGuideProgress() end
    setItem(getRow(n), nil, nil, GOLD .. "Secret: a bank alt in ten minutes|r", open and GREY .. RG.ALT_INTRO .. "|r" or (GREY .. "Make a new Undead and Waypath+ walks it to the Undercity Auction House with the arrow. Click to see the steps.|r"),
      alt and (done >= total and (GREEN .. "Done|r") or (GOLD .. done .. "/" .. total .. "|r")) or (GREY .. (open and "hide" or "show") .. "|r"), "", "gold", nil, not open)
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
    rows[n].onClick = function() state.altGuide = not open; RG.altGuideOpen = nil; RG.RefreshUI() end
    if open then
      for i, s in ipairs(RG.ALT_STEPS) do
        n = n + 1
        local isDone = alt and RG.AltStepDone and RG.AltStepDone(i) or false
        local wp = s.wp
        setStep(getRow(n), i, (wp and RG.PIN or "") .. GOLD .. s.title .. ":|r " .. s.text, isDone, function() if wp then RG.PinWaypoint(wp) end end, isDone and "done on this character" or nil)
        if wp then rows[n].tip = "Click to point the arrow at " .. wp[4] .. "." end
      end
      for _, line in ipairs(RG.ALT_LEVELING) do
        n = n + 1; setStep(getRow(n), "", GREY .. line .. "|r", false, nil)
        rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
      end
      if not alt then
        n = n + 1; setStep(getRow(n), "", GREY .. "On your main, everything is already linked: once the alt logs in, Waypath+ treats it as your bank alt and shows the shopping list there.|r", false, nil)
        rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
      end
    end
  end
  -- shopping list
  local list = RG.ShoppingList()
  local total, unknown = 0, 0
  n = n + 1; setHeader(getRow(n), #list > 0 and "Shopping list  ·  next few levels for " .. main or "Nothing to buy for the next few levels")
  for _, e in ipairs(list) do
    n = n + 1
    local r = getRow(n)
    local name, link, quality = itemName(e.id)
    local price = RG.Price(e.id)
    if price then total = total + price * e.toBuy elseif e.toBuy > 0 then unknown = unknown + 1 end
    local status = e.toBuy == 0 and (GREEN .. "In the alt's bags|r") or (GOLD .. "Buy " .. e.toBuy .. "|r")
    if not alt then status = GOLD .. "Need " .. e.need .. "|r" end
    setItem(r, e.id, link, name, e.quest .. GREY .. "  ·  quest level " .. e.lvl .. "|r", status, RG.PriceText(e.id) or (GREY .. "not priced yet|r"), nil, quality, true)
    r.onClick = function() RG.SearchAH(e.id) end
  end
  if #list > 0 then
    n = n + 1; setHeader(getRow(n), "About " .. RG.Money(total) .. " to buy everything" .. (unknown > 0 and (" (" .. unknown .. " not priced yet: open the AH)") or ""))
  end
  -- every quest
  n = n + 1; setHeader(getRow(n), "Quests you can skip the farming for")
  for _, m in ipairs(RG.MailQuests(nil, true)) do
    n = n + 1
    local pill
    if m.done then pill = GREEN .. "Done|r"
    elseif m.missing == 0 then pill = GREEN .. (m.q.any and "All pages|r" or "Have it|r")
    elseif m.selfMade then pill = GREEN .. "Make it yourself|r"
    elseif m.q.bs then pill = GOLD .. "Blacksmithing " .. m.q.bs .. "|r"
    else pill = GOLD .. "Mail it|r" end
    local what = m.q.any and (#m.items - m.missing .. " of " .. #m.items .. " pages") or (m.items[1].count .. "x " .. m.items[1].name)
    setItem(getRow(n), (not m.q.any) and m.items[1].id or nil, nil, (m.done and GREY or "|cffffd100") .. m.q.quest .. "|r" .. GREY .. "   " .. m.q.zone .. "  ·  level " .. m.q.lvl .. "|r",
      what .. GREY .. "  ·  " .. m.q.giver .. "  ·  " .. m.q.why .. "|r", pill, "", m.done and "green" or nil)
    if m.q.any then rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Note_02") end
    local mw = RG.WaypointForText and RG.WaypointForText(m.q.giver)
    if mw then rows[n].onClick = function() RG.PinWaypoint(mw) end; rows[n].tip = "Click to show " .. mw[4] .. " on the map." end
  end
  return n
end

local function renderCamp()
  local n = 0
  local p = RG.Professions()
  local function sk(name) return p[name] and p[name].rank or 0 end
  -- status
  local state, left = RG.CampState()
  n = n + 1
  local st = state == "active" and (GREEN .. (left and string.format("%d min left", math.ceil(left / 60)) or "Active") .. "|r")
    or (state == "sitting" and (GOLD .. "Keep sitting...|r") or (state == "near" and (GOLD .. "Sit down by the fire|r") or (GREY .. "No camp buff|r")))
  setItem(getRow(n), nil, nil, "|cffffffffCamp Benefits|r", "Place a campfire, add an object, /sit for about a minute, and the buffs last an hour. You can place one object per hour, and friends can add theirs.", st, "", "gold")
  rows[n].icon:SetTexture("Interface\\Icons\\Spell_Fire_Fire")
  -- recommendation
  local best, opts = RG.CampPick()
  n = n + 1; setHeader(getRow(n), "What to place when you camp alone")
  if best then
    for i, o in ipairs(opts) do
      n = n + 1
      setItem(getRow(n), nil, nil, (i == 1 and GOLD or "|cffffffff") .. o.name .. "|r" .. (i == 1 and (GREEN .. "   best for you right now|r") or ""), o.why, (o.value >= 1e6 and ((i == 1 and GREEN or GREY) .. "XP|r") or string.format("%s+%.0f|r", i == 1 and GREEN or GREY, o.value)), "", i == 1 and "gold" or nil, nil, true)
    end
  else
    n = n + 1; setItem(getRow(n), nil, nil, "|cffffffffGet any profession to 20|r", "Every profession, plus Fishing and First Aid, has a camp object at skill 20 (listed below).", "", "", nil, nil, true)
  end
  n = n + 1; setItem(getRow(n), nil, nil, GREY .. "Camp objects don't stack with the matching class buff (Sharpening Wheel and Strength of Earth Totem, Lodestone and Blessing of Might, Fish Bowl and Blessing of Kings...): in a group, bring one nobody's buff covers.|r", "", "", "", nil, nil, true)
  -- campfires
  n = n + 1; setHeader(getRow(n), string.format("Campfires  ·  Cooking %d", sk("Cooking")))
  for _, c in ipairs(RG.CAMPFIRES) do
    n = n + 1
    local have = sk("Cooking") >= c.cook
    setItem(getRow(n), nil, nil, (have and "|cffffffff" or GREY) .. c.name .. "|r" .. GREY .. "   " .. c.slots .. " object slots  ·  " .. c.wood .. "|r", c.how, have and (GREEN .. "Ready|r") or (GOLD .. "Cooking " .. c.cook .. "|r"), c.learn and (GREY .. "learn at " .. c.learn .. "|r") or "", have and "green" or nil, nil, true)
    rows[n].icon:SetTexture("Interface\\Icons\\Spell_Fire_Fire")
  end
  -- objects
  n = n + 1; setHeader(getRow(n), "Your camp objects")
  for _, o in ipairs(RG.CAMP_OBJECTS) do
   if p[o.prof] or (RG.Plans and RG.Plans(o.prof)) then
    n = n + 1
    local have = sk(o.prof) >= o.skill
    setItem(getRow(n), nil, nil, (have and "|cffffffff" or GREY) .. o.name .. "|r" .. GREY .. "   " .. o.prof .. " " .. o.skill .. "|r", o.buff .. GREY .. "  ·  " .. o.how .. (o.mats and ("  ·  " .. o.mats) or "") .. "|r", have and (GREEN .. "Unlocked|r") or (GOLD .. o.prof .. " " .. o.skill .. "|r"), "", have and "green" or nil, nil, true)
    local PD = RG.PROFESSIONS[o.prof]
    rows[n].icon:SetTexture(PD and PD.icon or "Interface\\Icons\\Spell_Fire_Fire")
   end
  end
  -- plan
  n = n + 1; setHeader(getRow(n), string.format("Fishing %d  ·  Cooking %d  ·  leveling plan along your route", sk("Fishing"), sk("Cooking")))
  local lvl = UnitLevel("player")
  for _, s in ipairs(RG.CAMP_PLAN) do
   if not RG.CampPlanned or RG.CampPlanned(s) then
    n = n + 1
    local done = RG.CampPlanDone(s)
    local soon = not done and s.lvl <= lvl + 2
    local cw = RG.CampWaypoint and RG.CampWaypoint(s)
    setStep(getRow(n), "", (cw and RG.PIN or "") .. s.text .. GREY .. "   (level " .. s.lvl .. ", " .. s.zone .. ")|r", done, cw and function() RG.PinWaypoint(cw) end or function() end, done and "your skill is already there" or nil)
    if cw then rows[n].tip = "Click to show " .. cw[4] .. " on the map." end
    if soon then rows[n].title:SetText(GOLD .. "Now: |r" .. (cw and RG.PIN or "") .. s.text .. GREY .. "   (" .. s.zone .. ")|r") end
   end
  end
  return n
end

local function renderFish()
  local n = 0
  local p = RG.Professions()
  local fsk, fmax = (p.Fishing and p.Fishing.rank) or 0, (p.Fishing and p.Fishing.max) or 0
  local csk, cmax = (p.Cooking and p.Cooking.rank) or 0, (p.Cooking and p.Cooking.max) or 0
  local lvl = UnitLevel("player")
  local ORANGE = "|cffff8040"
  -- skill bars
  local rankName = "not learned"
  for _, r in ipairs(RG.FISH_RANKS) do if fmax >= r.max then rankName = r.name end end
  n = n + 1; setBar(getRow(n), "Fishing  ·  " .. rankName, fsk, math.max(fmax, 1), T.blue or T.gold, p.Fishing and (fsk .. " / " .. fmax) or "learn it from a trainer")
  n = n + 1; setBar(getRow(n), "Cooking", csk, math.max(cmax, 1), T.gold, p.Cooking and (csk .. " / " .. cmax) or "learn it from a trainer")
  -- right now
  n = n + 1; setHeader(getRow(n), "Right now")
  local nextR, st = RG.FishNextRank()
  if nextR then
    n = n + 1
    local pill = st == "ready" and (GREEN .. "Do it now|r") or (st == "learn" and (GOLD .. "Learn Fishing|r") or (GREY .. "Fishing " .. nextR.at .. ", level " .. nextR.lvl .. "|r"))
    setItem(getRow(n), nil, nil, "|cffffffffNext rank: " .. nextR.name .. "|r" .. GREY .. "   (cap " .. nextR.max .. ")|r", nextR.how, pill, "", st == "ready" and "gold" or nil)
    rows[n].icon:SetTexture("Interface\\Icons\\Trade_Fishing")
    if nextR.wp then local wp = nextR.wp; rows[n].onClick = function() RG.PinWaypoint(wp) end; rows[n].tip = "Click to show " .. wp[4] .. " on the map." end
  end
  local z, zoneName = RG.FishZone()
  n = n + 1
  if z then
    local pill = z.status == "all" and (GREEN .. "Every fish bites|r") or (z.status == "some" and (GOLD .. "Some get away|r") or (RED .. "Too low|r"))
    setItem(getRow(n), nil, nil, "|cffffffff" .. z.zone .. "|r" .. GREY .. string.format("   fishing starts at %d, every fish bites at %d|r", math.max(1, z.min), z.full),
      string.format("Your skill %d%s%s = %d.%s", z.skill, z.pole > 0 and (" + pole " .. z.pole) or "", z.lure and (" + lure " .. z.lure) or "", z.eff,
        z.status ~= "all" and (" A lure (+25 to +100) closes the gap.") or "") .. GREY .. "  Zone skill levels are Classic's: WoW Forever hasn't published its own yet.|r", pill, "", z.status == "all" and "green" or nil)
  else
    setItem(getRow(n), nil, nil, "|cffffffff" .. (zoneName ~= "" and zoneName or "This zone") .. "|r", "No fishing level known for this zone.", "", "")
  end
  rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_02")
  local s = RG.FishSession()
  if s and s.catches > 0 then
    n = n + 1
    local top = {}
    for id, c in pairs(s.items) do top[#top + 1] = { id = id, c = c } end
    table.sort(top, function(a, b) return a.c > b.c end)
    local parts = {}
    for i = 1, math.min(3, #top) do parts[#parts + 1] = (itemName(top[i].id) or "?") .. " x" .. top[i].c end
    setItem(getRow(n), nil, nil, string.format("|cffffffffThis session: %d fish|r", s.catches) .. (s.perHour and (GREY .. "   " .. s.perHour .. " per hour|r") or ""),
      table.concat(parts, ", "), s.gained > 0 and (GREEN .. "+" .. s.gained .. " skill|r") or "", "")
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_14")
  end
  -- cook now
  local cook, total = RG.CookNow()
  if not RG.db.cookRecipes then
    n = n + 1; setItem(getRow(n), nil, nil, GOLD .. "Open your Cooking window once|r", "Then Waypath+ knows your recipes and shows which fish in your bags still give Cooking skill.", "", "", nil, nil, true)
  elseif total > 0 then
    n = n + 1; setHeader(getRow(n), string.format("Cook these at your campfire  ·  %d raw fish still give skill", total))
    for _, e in ipairs(cook) do
      n = n + 1
      local name, link, quality = itemName(e.c.id)
      local col = e.st == "optimal" and ORANGE or (e.st == "medium" and "|cffffff00" or GREEN)
      setItem(getRow(n), e.c.id, link, name .. GREY .. "  x" .. e.have .. "|r", "Cook into " .. e.c.dish, col .. (e.st == "optimal" and "Skill every cook" or (e.st == "medium" and "Skill most cooks" or "Skill sometimes")) .. "|r", "", nil, quality, true)
    end
  end
  -- where to fish
  n = n + 1; setHeader(getRow(n), "Where to fish for your skill (Horde)")
  for _, r in ipairs(RG.FISH_ROUTE) do
    n = n + 1
    local here = fsk >= r.from and fsk < r.to
    local done = fsk >= r.to
    setItem(getRow(n), nil, nil, (here and GOLD or (done and GREY or "|cffffffff")) .. r.from .. "-" .. r.to .. "  ·  " .. r.spot .. "|r" .. GREY .. "   " .. r.zone .. "|r", r.text,
      here and (GREEN .. "You're here|r") or (done and (GREY .. "Done|r") or (GREY .. "level " .. r.lvl .. "+|r")), "", here and "gold" or nil)
    rows[n].icon:SetTexture("Interface\\Icons\\Trade_Fishing")
    if r.wp then local wp = r.wp; rows[n].onClick = function() RG.PinWaypoint(wp) end; rows[n].tip = "Click to show " .. wp[4] .. " on the map." end
  end
  -- fish to catch and cook
  local night = RG.FishNight()
  n = n + 1; setHeader(getRow(n), string.format("Fish to catch and cook  ·  Cooking %d  ·  it's %s on the server", csk, night and "night" or "day"))
  for _, c in ipairs(RG.FISH_COOK) do
    if c.cook <= csk + 75 or c.ret then
      n = n + 1
      local name, link, quality = itemName(c.id)
      local have = GetItemCount and GetItemCount(c.id) or 0
      local cst = RG.CookState(c.dish)
      local pill
      if c.time == "night" and not night then pill = GREY .. "Night only|r"
      elseif c.time == "day" and night then pill = GREY .. "Day only|r"
      elseif fsk < c.fish then pill = GREY .. "Fishing " .. c.fish .. "|r"
      elseif csk < c.cook then pill = GREY .. "Cooking " .. c.cook .. "|r"
      elseif cst == "optimal" or cst == "medium" or cst == "easy" then pill = GREEN .. "Levels Cooking|r"
      elseif cst == "trivial" then pill = GREY .. "No more skill|r"
      elseif cst == "missing" then pill = GOLD .. "Get the recipe|r"
      else pill = "" end
      local sub = "-> " .. c.dish .. GREY .. "  ·  " .. c.where .. "  ·  Cooking " .. c.cook .. (c.recipe and ("  ·  recipe: " .. c.recipe) or "") .. (c.note and ("  ·  " .. c.note) or "") .. (c.season and ("  ·  " .. c.season .. " only") or "") .. "|r"
      setItem(getRow(n), c.id, link, name .. (have > 0 and (GREY .. "  x" .. have .. " in bags|r") or ""), sub, pill, "", c.ret and "gold" or nil, quality, true)
    end
  end
  -- gear
  n = n + 1; setHeader(getRow(n), "Poles, lures and fishing gear")
  for _, g in ipairs(RG.FISH_GEAR) do
    n = n + 1
    local name, link, quality = itemName(g.id)
    local have = GetItemCount and GetItemCount(g.id, true) or 0
    local pill
    if have > 0 then pill = GREEN .. (g.kind == "lure" and ("You have " .. have) or "You have it") .. "|r"
    elseif g.skill and fsk < g.skill then pill = GREY .. "Fishing " .. g.skill .. "|r"
    else pill = "" end
    setItem(getRow(n), g.id, link, name .. GREY .. "   +" .. g.bonus .. (g.mins and (" for " .. g.mins .. " min") or "") .. "|r", g.how, pill, "", have > 0 and "green" or nil, quality, true)
  end
  -- extravaganza
  n = n + 1; setHeader(getRow(n), "Stranglethorn Fishing Extravaganza (Booty Bay)")
  for _, line in ipairs(RG.FISH_DERBY) do
    n = n + 1; setStep(getRow(n), "", line, false, nil)
    rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
  end
  -- everything fishing can bring up
  local FL = RG.FISH_LOOT
  local idx = FL and RG.FishLootIndex()
  if idx then
    state.fishOpen = state.fishOpen or {}
    local function note(text)
      n = n + 1; setStep(getRow(n), "", text, false, nil)
      rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
    end
    local function lootName(id)
      local name, link, quality = RG.ItemInfo(id)
      if not name then
        RG.RequestItem(id)
        local info = FL.info[id]
        return GREY .. (info and info[1] or ("Item " .. id)) .. "|r", nil, info and info[3]
      end
      local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
      return (c and c.hex or "|cffffffff") .. name .. "|r", link, quality
    end
    local function plain(id) local info = FL.info[id]; return info and info[1] or ("Item " .. id) end
    local function pct(p) return p >= 10 and string.format("%d%%", math.floor(p + 0.5)) or (p >= 1 and string.format("%.1f%%", p) or string.format("%.2f%%", p)) end
    local function pillFor(p) return (p >= 20 and GREEN or (p >= 5 and GOLD or GREY)) .. pct(p) .. "|r" end
    local function holds(id, limit)
      local c = FL.contents[id]
      if not c then return nil end
      local t = {}
      for i = 1, math.min(limit, #c) do t[#t + 1] = plain(c[i][1]) .. " " .. pct(c[i][2]) end
      return table.concat(t, ", ") .. (#c > limit and (", +" .. (#c - limit) .. " more") or "")
    end
    -- item row: where it comes from, at what skill, and what a container holds
    local function lootRow(e, chance)
      local nm, link, quality = lootName(e.id)
      local where = {}
      for i = 1, math.min(3, #e.zones) do where[#where + 1] = e.zones[i][1] .. " " .. pct(e.zones[i][2]) end
      local extra = #e.zones - 3
      local sub = (#where > 0 and ("Where: " .. table.concat(where, ", ") .. (extra > 0 and (" and " .. extra .. " more zone" .. (extra > 1 and "s" or "")) or "")) or "")
      if #e.pools > 0 then sub = sub .. (sub ~= "" and "  ·  " or "") .. "Pool: " .. e.pools[1][1].name .. (#e.pools > 1 and (" +" .. (#e.pools - 1)) or "") end
      if e.skill then sub = sub .. "  ·  starts at skill " .. e.skill end
      local h = holds(e.id, 6)
      if h then sub = sub .. "\nHolds: " .. h end
      n = n + 1
      setItem(getRow(n), e.id, link, nm, sub, pillFor(chance or e.best), "", nil, quality, true)
      local tip = { "Where it comes from (chance per catch):" }
      for _, z in ipairs(e.zones) do
        local full = RG.FISH_ZONES[z[1]]
        tip[#tip + 1] = z[1] .. "  " .. pct(z[2]) .. (full and ("  (skill " .. math.max(1, full - 95) .. "+, every fish bites at " .. full .. ")") or "")
      end
      for _, p in ipairs(e.pools) do tip[#tip + 1] = "Pool: " .. p[1].name .. "  " .. pct(p[2]) .. "  (" .. p[1].spots[1][4] .. ")" end
      local hh = holds(e.id, 20)
      if hh then tip[#tip + 1] = "\nHolds: " .. hh end
      rows[n].tip = table.concat(tip, "\n")
      local pool = e.pools[1] and e.pools[1][1]
      if pool and pool.spots[1] then local wp = pool.spots[1]; rows[n].onClick = function() RG.PinWaypoint(wp) end end
    end
    n = n + 1; setHeader(getRow(n), "Everything fishing can bring up")
    note(GREY .. "Chances are per catch, from the game's fishing loot tables (WoW Forever's own numbers aren't published). Hover a row for every zone; click a pool to pin it on your map.|r")
    -- this zone
    local here = FL.zones[zoneName or ""]
    if here then
      note("|cffffffffIn " .. zoneName .. " you can catch:|r")
      for _, c in ipairs(here) do
        local e = idx.byId[c[1]]
        if e then lootRow(e, c[2]) end
      end
    else
      note(GREY .. "Stand in a zone with water to see what it gives. The groups below cover every zone.|r")
    end
    -- groups, closed until you open them
    local CATS = { { "fish", "Fish and cooking ingredients" }, { "container", "Chests, crates, trunks, clams and bottles" },
      { "material", "Materials, water and other catches" }, { "misc", "Potions and miscellaneous" }, { "gear", "Gear" }, { "junk", "Junk" } }
    for _, cat in ipairs(CATS) do
      local lst = idx.byKind[cat[1]]
      if lst and #lst > 0 then
        local open = state.fishOpen[cat[1]]
        n = n + 1
        setStep(getRow(n), "", GOLD .. (open and "- " or "+ ") .. cat[2] .. "|r" .. GREY .. "  (" .. #lst .. ")  ·  click to " .. (open and "hide" or "show") .. "|r", false,
          function() state.fishOpen[cat[1]] = not open; RG.RefreshUI() end)
        rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
        if open then for _, e in ipairs(lst) do lootRow(e) end end
      end
    end
    -- pools
    local open = state.fishOpen.pools
    n = n + 1
    setStep(getRow(n), "", GOLD .. (open and "- " or "+ ") .. "Pools, schools, wreckage and fishing spots|r" .. GREY .. "  (" .. #FL.pools .. ")  ·  click to " .. (open and "hide" or "show") .. "|r", false,
      function() state.fishOpen.pools = not open; RG.RefreshUI() end)
    rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
    if open then
      for _, p in ipairs(FL.pools) do
        local first = p.items[1]
        local gives = {}
        for i = 1, math.min(4, #p.items) do gives[#gives + 1] = plain(p.items[i][1]) .. " " .. pct(p.items[i][2]) end
        local where = {}
        for i = 1, math.min(3, #p.spots) do where[#where + 1] = p.spots[i][4] end
        n = n + 1
        local spot = p.spots[1]
        setItem(getRow(n), first and first[1] or nil, nil, "|cffffffff" .. p.name .. "|r", "Gives: " .. table.concat(gives, ", ") .. (#p.items > 4 and (", +" .. (#p.items - 4) .. " more") or "") .. "\nWhere: " .. table.concat(where, "; "),
          first and pillFor(first[2]) or "", "", nil, nil, true)
        local tip = { "Gives (chance per catch):" }
        for _, c in ipairs(p.items) do tip[#tip + 1] = plain(c[1]) .. "  " .. pct(c[2]) end
        tip[#tip + 1] = "\nWhere:"
        for _, sp in ipairs(p.spots) do tip[#tip + 1] = sp[4] end
        rows[n].tip = table.concat(tip, "\n") .. "\n\nClick to show the nearest cluster on the map."
        rows[n].onClick = function() RG.PinWaypoint(spot) end
      end
    end
  end
  -- sell
  n = n + 1; setHeader(getRow(n), "Fish other professions buy")
  for _, f in ipairs(RG.FISH_SELL) do
    n = n + 1
    local name, link, quality = itemName(f.id)
    setItem(getRow(n), f.id, link, name, f.note, "", RG.PriceText(f.id) or (GREY .. "not priced yet|r"), nil, quality, true)
  end
  -- lifetime
  local d = RG.db.fish
  if d and (d.total or 0) > 0 then
    local top = {}
    for id, c in pairs(d.caught or {}) do top[#top + 1] = { id = id, c = c } end
    table.sort(top, function(a, b) return a.c > b.c end)
    local parts = {}
    for i = 1, math.min(5, #top) do parts[#parts + 1] = (itemName(top[i].id) or "?") .. " " .. top[i].c end
    n = n + 1; setHeader(getRow(n), string.format("Since you installed Waypath+: %d catches", d.total))
    n = n + 1; setStep(getRow(n), "", table.concat(parts, "  ·  "), false, nil)
    rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
  end
  return n
end

local SETTING_GROUPS = {
  { "Leveling and quests", { "tracker", "trackerFade", "trackerLocked", "fishTracker", "trackerProfs", "levelBanner", "autoQuest", "newQuests", "autoArrow", "autoReward", "rewardPicker", "targetBar", "questItems", "nameplateAlert", "arrow", "travelTips", "efficiency", "talentReminder", "reminders", "wellFed", "campReminder" } },
  { "Gear and combat", { "tooltip", "upgradeToast", "paperdoll", "exorcism", "stoneReminder", "healSet", "specSwap", "bagArrows" } },
  { "Group play", { "groupDuties", "groupAlerts" } },
  { "Professions, bags and gold", { "mineReminder", "oreAlert", "oreAlertAll", "herbAlert", "sellJunk", "autoRepair", "bagReminder", "sortButton", "fishImmersive", "fishSound", "fishRecast", "profitWatch", "autoScan" } },
  { "Interface", { "minimap", "sounds", "quietErrors" } },
}
local function renderGroup()
  local n = 0
  local inGroup = (GetNumGroupMembers and GetNumGroupMembers() or 0) > 1
  -- how grouping is going for you
  local solo, grp, st, gt = RG.XPModes(5)
  n = n + 1
  local verdict, pill
  if solo and grp then
    local d = (grp - solo) / solo
    verdict = string.format("Grouped %s%.1fk XP/hr|r vs solo %s%.1fk|r over your last 5 levels.", GOLD, grp / 1000, GOLD, solo / 1000)
    pill = d >= 0.05 and (GREEN .. string.format("Grouping +%d%%", math.floor(d * 100 + 0.5)) .. "|r") or (d <= -0.05 and (GOLD .. string.format("Solo +%d%%", math.floor(-d / (1 + d) * 100 + 0.5)) .. "|r") or (GREY .. "About even|r"))
  else
    verdict = string.format("Keep playing: Waypath+ compares solo and grouped XP/hr once it has 10 minutes of each (now %dm solo, %dm grouped).", math.floor((st or 0) / 60), math.floor((gt or 0) / 60))
  end
  setItem(getRow(n), nil, nil, inGroup and string.format("|cffffffffIn a party of %d|r", GetNumGroupMembers()) or "|cffffffffPlaying solo|r", verdict, pill or "", "", "gold")
  rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")

  if inGroup and RG.IsClass("PALADIN") then
    -- paladin duties
    n = n + 1; setHeader(getRow(n), "Your paladin duties")
    local aura = RG.MyAura and RG.MyAura()
    n = n + 1
    setItem(getRow(n), nil, nil, "|cffffffffAura|r", aura and ("You're running " .. aura .. ". Retribution adds damage; switch to Devotion if the tank struggles.") or "No Aura on. Turn on Retribution Aura (or Devotion for a shaky tank).",
      aura and (GREEN .. "On|r") or (GOLD .. "Turn one on|r"), "", aura and "green" or nil, nil, true)
    rows[n].icon:SetTexture("Interface\\Icons\\Spell_Holy_DevotionAura")
    for i = 1, 4 do
      local u = "party" .. i
      if RG.SafeCall(UnitExists, u) then
        n = n + 1
        local mine = RG.MyBlessingOn and RG.MyBlessingOn(u)
        local _, class = RG.SafeUnit(UnitClass, u)
        local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        local name = (cc and string.format("|cff%02x%02x%02x", cc.r * 255, cc.g * 255, cc.b * 255) or "|cffffffff") .. (RG.SafeName(u) or u) .. "|r"
        local hpNow, hpMax = RG.SafeUnit(UnitHealth, u), RG.SafeUnit(UnitHealthMax, u)
        local hp = (hpNow and hpMax and hpMax > 0) and math.floor(hpNow / hpMax * 100) or nil
        setItem(getRow(n), nil, nil, name .. GREY .. "   level " .. (RG.SafeUnit(UnitLevel, u) or "?") .. "|r", mine and ("Has your " .. mine) or ("Suggested: " .. RG.SuggestBlessing(u)),
          mine and (GREEN .. "Blessed|r") or (GOLD .. "Needs a Blessing|r"), (hp and (GREY .. hp .. "% health|r") or ""), mine and "green" or nil, nil, true)
        rows[n].icon:SetTexture("Interface\\Icons\\Spell_Holy_FistOfJustice")
      end
    end
  end
  -- quests
  local qs = RG.GroupQuestInfo()
  local any = false
  for _, q in ipairs(qs) do
    local groupTag = q.tag and (q.tag:find("Group") or q.tag:find("Elite") or q.tag:find("Dungeon"))
    if inGroup or groupTag then
      if not any then n = n + 1; setHeader(getRow(n), inGroup and "Quests and who has them  ·  click to share" or "Group quests in your log"); any = true end
      n = n + 1
      local sub
      if inGroup then
        sub = (#q.have > 0 and (GREEN .. "Has it: " .. table.concat(q.have, ", ") .. "|r") or "") .. ((#q.have > 0 and #q.missing > 0) and GREY .. "  ·  |r" or "") .. (#q.missing > 0 and (GOLD .. "Missing: " .. table.concat(q.missing, ", ") .. "|r") or "")
      else sub = GREY .. "Easier with a group. See Find a group below.|r" end
      local pill = q.complete and (GREEN .. "Ready to turn in|r") or (groupTag and (GOLD .. q.tag .. "|r") or "")
      setItem(getRow(n), nil, nil, RG.LevelTag(q.level or RG.QuestLevel(q.title)) .. "|cffffd100" .. q.title .. "|r", sub, pill, (inGroup and #q.missing > 0) and (GOLD .. "Share|r") or "", nil, nil, true)
      rows[n].icon:SetTexture(136797)
      local id, title = q.id, q.title
      if inGroup and #q.missing > 0 then
        rows[n].onClick = function() RG.ShareQuest(id) end
        rows[n].onRightClick = function() RG.OpenQuest(title, id) end
        rows[n].tip = "Click to share this quest with your party. Right-click: open it in your quest log."
      else
        rows[n].onClick = function() RG.OpenQuest(title, id) end
        rows[n].tip = "Click to open it in your quest log."
      end
    end
  end
  -- find a group
  local sug = RG.GroupSuggestions()
  if #sug > 0 then
    n = n + 1; setHeader(getRow(n), "Find a group  ·  click to post in LookingForGroup")
    for _, sgg in ipairs(sug) do
      n = n + 1
      setItem(getRow(n), nil, nil, (sgg.kind == "dungeon" and "|cffa58bd8" or "|cffffd100") .. sgg.name .. "|r", GREY .. (sgg.note or "") .. "|r  ·  \"" .. RG.LFGMessage(sgg.name) .. "\"", GOLD .. "Post LFG|r", "", nil, nil, true)
      rows[n].icon:SetTexture(sgg.kind == "dungeon" and 136058 or 136797)
      local what = sgg.name
      rows[n].onClick = function() RG.PostLFG(what) end
      rows[n].tip = "Click to post: " .. RG.LFGMessage(what)
    end
  end
  -- dungeon runs
  local runs = RG.db.runs or {}
  n = n + 1; setHeader(getRow(n), #runs > 0 and "Dungeon runs" or "Dungeon runs  ·  run a dungeon and Waypath+ reports it here")
  for i = 1, math.min(10, #runs) do
    local r = runs[i]
    n = n + 1
    setItem(getRow(n), nil, nil, "|cffa58bd8" .. r.name .. "|r" .. GREY .. "   level " .. (r.level or "?") .. "  ·  " .. ago(r.t) .. "|r",
      string.format("%s  ·  %d kills  ·  %d deaths  ·  %.1fk XP/hr", RG.FormatDuration and RG.FormatDuration(r.dur) or "", r.kills or 0, r.deaths or 0, (r.xpHr or 0) / 1000),
      (#(r.loot or {}) > 0) and (GREEN .. #r.loot .. " loot|r") or "", "", nil, nil, true)
    rows[n].icon:SetTexture(136058)
    if r.loot and #r.loot > 0 then rows[n].tip = "Loot: " .. table.concat(r.loot, ", ") end
  end
  return n
end

local function renderSettings()
  local n = 0
  local byKey, used, ordered = {}, {}, {}
  for _, o in ipairs(RG.OPTIONS or {}) do byKey[o.key] = o end
  for _, g in ipairs(SETTING_GROUPS) do
    local list = {}
    for _, k in ipairs(g[2]) do if byKey[k] then list[#list + 1] = byKey[k]; used[k] = true end end
    ordered[#ordered + 1] = { g[1], list }
  end
  local other = {}
  for _, o in ipairs(RG.OPTIONS or {}) do if not used[o.key] then other[#other + 1] = o end end
  if #other > 0 then ordered[#ordered + 1] = { "Other", other } end
  -- search box: keep only options whose label (or group) matches
  local q = state.search and state.search:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
  if q ~= "" then
    local hits = 0
    for _, grp in ipairs(ordered) do
      local gmatch = grp[1]:lower():find(q, 1, true)
      local keep = {}
      for _, o in ipairs(grp[2]) do if gmatch or o.label:lower():find(q, 1, true) then keep[#keep + 1] = o end end
      grp[2] = keep; hits = hits + #keep
    end
    if hits == 0 then n = n + 1; setHeader(getRow(n), "No settings match \"" .. state.search .. "\"") end
  end
  for _, grp in ipairs(ordered) do
   if #grp[2] > 0 then
    n = n + 1; setHeader(getRow(n), grp[1])
   end
   for _, o in ipairs(grp[2]) do
    n = n + 1
    local on = RG.Opt(o.key)
    setStep(getRow(n), "", o.label, on, function()
      RG.db[o.key] = not on
      if o.key == "minimap" and RG.MinimapButton then RG.MinimapButton() end
      if RG.RefreshTracker then RG.RefreshTracker() end
      RG.RefreshUI()
    end)
    rows[n].title:SetText((on and "|cffffffff" or GREY) .. o.label .. "|r")
    rows[n].tip = on and "On. Click to turn off." or "Off. Click to turn on."
   end
  end
  local function action(label, sub, fn)
    n = n + 1
    setItem(getRow(n), nil, nil, label, sub, GOLD .. "Run|r", "", "gold")
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    rows[n].onClick = fn
  end
  -- this character's profile
  local mode = RG.CharMode and RG.CharMode()
  local isMain = RG.IsMain and RG.IsMain()
  n = n + 1; setHeader(getRow(n), "This character  ·  " .. (UnitName("player") or "") .. "  ·  " .. (mode == "alt" and "bank alt" or "own profile") .. (isMain and ", your main" or ""))
  if mode == "alt" then
    action("Give this character its own profile", "Turns off bank alt mode: the full leveling guide with this character's own settings and progress (reloads)", function() RG.SetCharMode("profile"); ReloadUI() end)
  else
    action("Make this character a bank alt", "No leveling guide here: a shopping list of quest items to buy and mail to " .. (RG.MainName() or "your main") .. ", plus the vendor and mailbox helpers (reloads)", function() RG.SetCharMode("alt"); ReloadUI() end)
    if not isMain then action("Make this my main", "Your bank alts buy and mail for this character", function() RG.db.main = RG.PlayerKey(); RG.Print(UnitName("player") .. " is now your main."); RG.RefreshUI() end) end
  end
  action("Start this character over", "A brand new, empty profile for this character: settings back to defaults, route, quests and plans cleared (reloads; asks first)", function()
    if StaticPopupDialogs and StaticPopup_Show then
      StaticPopupDialogs.WAYPATH_RESET_PROFILE = { text = "Start " .. (UnitName("player") or "this character") .. " over with a brand new Waypath+ profile?\n\nIts settings, ticked steps, quests and plans are cleared. Other characters and Auction House prices aren't touched.",
        button1 = YES or "Yes", button2 = NO or "No", OnAccept = function() RG.ResetProfile() end, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3 }
      StaticPopup_Show("WAYPATH_RESET_PROFILE")
    end
  end)
  local others = {}
  for _, c in ipairs(RG.KnownChars and RG.KnownChars() or {}) do
    if c.key ~= RG.PlayerKey() then others[#others + 1] = c.key:match("^(.-)%-") .. (c.mode == "alt" and " (bank alt)" or "") .. ((RG.db.main == c.key) and " (main)" or "") end
  end
  if #others > 0 then
    n = n + 1
    setItem(getRow(n), nil, nil, GREY .. "Your other characters|r", table.concat(others, ", "), "", "", nil, nil, true)
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
  end
  n = n + 1; setHeader(getRow(n), "Actions")
  action("Run setup again", "Help level, professions, automation and extras, in six short pages", function() if RG.ShowSetup then RG.ShowSetup() end end)
  action("Reset ticked tasks", "Untick every route task you ticked by hand", function() RG.db.stepsDone = {}; RG.RefreshUI(); if RG.RefreshTracker then RG.RefreshTracker() end; RG.Print("Ticked tasks reset.") end)
  action("Move the tracker back", "Puts the on-screen tracker back on the right side at its normal size", function() RG.db.trackerPos = nil; RG.db.trackerScale = nil; RG.db.trackerWidth = nil; if WaypathTracker then WaypathTracker:ClearAllPoints(); WaypathTracker:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -260) end; if RG.RefreshTracker then RG.RefreshTracker() end end)
  action("Abandon grey quests", "Drops quests too low to give useful XP (asks first)", function() if RG.AbandonGreyQuests then RG.AbandonGreyQuests() end end)
  action("Swap to 2nd spec gear / back", "Swap between your 2nd spec's set and your main gear (pick the spec on the 2nd Spec tab)", function() if RG.SwapGear then RG.SwapGear() end end)
  action("Show Waypath+ errors", (RG.db.errors and #RG.db.errors or 0) .. " caught. Opens a window you can copy from", function() if RG.ShowErrors then RG.ShowErrors() end end)
  return n
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------
local TITLES = {
  route = { "Leveling route", "Your path from your starting zone to 60" },
  guide = { "Gear guide", "Upgrades for your spec by level, and where they come from" },
  gear  = { "My gear", "What you're wearing and what to chase next" },
  prof  = { "Professions", "Where you are in each profession, what you still need, and where to go for it" },
  ah    = { "Auction House", "Lowest buyout from your last scan" },
  settings = { "Settings", "Turn Waypath+'s helpers on or off" },
  gold  = { "Gold making", "Up-to-date ways to make money as a miner and smith" },
  camp  = { "Camping", "Campfire buffs, what to place, and the camp steps along your route" },
  fish  = { "Fishing & cooking", "Where to fish for your skill, ranks, gear, and fish that level your Cooking" },
  mail  = { "Bank alt", "Quest items to buy and mail instead of farming" },
  group = { "Group play", "How grouping is going, your class duties, shared quests and finding a group" },
  spec  = { "2nd spec", "Pick any spec of your class: its stats, how to play it and its gear" },
  heal  = { "2nd spec gear", "Gear to start collecting for your 2nd spec, and where to find it" },
}
local FOOTERS = {
  route = "Click a zone to open its tasks  ·  click a task to tick it off  ·  finished steps are hidden",
  guide = "Click an item to see where it drops or which quest gives it  ·  Shift-click to link  ·  Ctrl-click to preview",
  gear  = "Click an item to see where it drops or which quest gives it  ·  /wp weight tunes the score",
  prof  = "Double-click a place for the arrow  ·  counts include your bank (open it once)",
  ah    = "Opening the AH refreshes old prices  ·  your own searches pause the scan  ·  /wp alert [item] 25",
  settings = "Settings are saved per character (prices and window positions are shared)",
  gold  = "Updated weekly from the newest Forever gold guides  ·  /wp profit lists what to keep for the AH",
  fish  = "Open your Cooking window once so Waypath+ knows your recipes  ·  /wp fishmode: immersive fishing on/off",
  camp  = "One camp object per hour  ·  camp buffs don't stack with the matching class buff  ·  /wp camp",
  mail  = "Click an item to search the AH for it  ·  /wp main makes the current character your main",
  group = "Click a quest to share it  ·  click a suggestion to post LFG  ·  /wp lfg Scarlet Monastery posts your own",
  spec  = "Dual spec unlocks at level 40 at your class trainer  ·  /wp spec",
  heal  = "Pieces in your 2nd set are never sold  ·  the list updates twice a week  ·  /wp heal",
}

local function updateHeader()
  local lvl = UnitLevel("player")
  local p = RG.Professions()
  local cls = RG.ActiveClass or {}
  local bits = { "Level " .. lvl .. " " .. (UnitRace("player") or "") .. " " .. ((RG.ClassSupported and cls.spec) and (cls.spec .. " " .. (cls.name or "")) or (UnitClass("player") or "")) }
  for _, prof in ipairs({ "Mining", "Blacksmithing", "Fishing", "Cooking" }) do
    if p[prof] then bits[#bits + 1] = prof .. " " .. p[prof].rank end
  end
  frame.subtitle:SetText(table.concat(bits, "  ·  "))
  local xp, max = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
  local rested = GetXPExhaustion and GetXPExhaustion() or nil
  if rested and rested > 0 then frame.xp:SetStatusBarColor(0.0, 0.39, 0.88) else frame.xp:SetStatusBarColor(0.58, 0.0, 0.55) end
  if max and max > 0 and lvl < (GetMaxPlayerLevel and GetMaxPlayerLevel() or 60) then
    frame.xp:SetMinMaxValues(0, max); frame.xp:SetValue(xp)
    frame.xpText:SetText(string.format("XP %d / %d  (%d%%)%s", xp, max, math.floor(xp / max * 100), rested and rested > 0 and "  ·  rested" or ""))
  else
    frame.xp:SetMinMaxValues(0, 1); frame.xp:SetValue(1); frame.xpText:SetText("Max level")
  end
end

-- Many events ask for a redraw at once (looting fires several); coalesce them
-- into a single rebuild a tenth of a second later.
local refreshQueued
function RG.RefreshUI()
  if not frame or not frame:IsShown() or refreshQueued then return end
  refreshQueued = true
  C_Timer.After(0.1, function() refreshQueued = nil; RG.RefreshUINow() end)
end
function RG.RefreshUINow()
  if not frame or not frame:IsShown() then return end
  for _, r in ipairs(rows) do r:Hide() end
  updateHeader()
  local n
  if state.tab == "guide" then n = renderGuide()
  elseif state.tab == "gear" then n = renderGear()
  elseif state.tab == "route" then n = renderRoute()
  elseif state.tab == "prof" then n = renderProf()
  elseif state.tab == "settings" then n = renderSettings()
  elseif state.tab == "gold" then n = renderGold()
  elseif state.tab == "heal" then n = renderHeal()
  elseif state.tab == "spec" then n = renderSpec()
  elseif state.tab == "group" then n = renderGroup()
  elseif state.tab == "mail" then n = renderMail()
  elseif state.tab == "camp" then n = renderCamp()
  elseif state.tab == "fish" then n = renderFish()
  else n = renderAH() end
  sectionTitle:SetText(TITLES[state.tab][1]); frame.sectionSub:SetText(TITLES[state.tab][2])
  footer:SetText(FOOTERS[state.tab])
  frame.near:SetShown(state.tab == "guide")
  if frame.search then frame.search:SetShown(state.tab == "settings") end
  frame.scan:SetShown(state.tab == "ah")
  -- stack rows with their own heights
  local y = 0
  for i = 1, n do
    local r = rows[i]
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetHeight(r.h or ROW_H())
    y = y + (r.h or ROW_H()) + GAP
  end
  content:SetHeight(math.max(1, y))
  local parent = parentOf(state.tab)
  for k, b in pairs(tabs) do setTabLook(b, k == parent) end
  -- sub-tabs (right side of the section title) for merged tabs
  for _, b in pairs(frame.subBtns) do b:Hide() end
  local subs = GROUPS[parent]
  local anchor
  if subs then
    state.lastSub[parent] = state.tab
    for i = #subs, 1, -1 do
      local b = frame.subBtns[subs[i]]
      local on = subs[i] == state.tab
      backdrop(b, on and { 0.25, 0.2, 0.05, 0.9 } or { 0.08, 0.07, 0.06, 0.85 }, on and { T.gold[1], T.gold[2], T.gold[3], 1 } or { 0.5, 0.47, 0.4, 0.8 }, 10)
      b.text:SetFontObject(on and "GameFontHighlightSmall" or "GameFontNormalSmall")
      b:ClearAllPoints()
      if anchor then b:SetPoint("RIGHT", anchor, "LEFT", -4, 0) else b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -86) end
      b:Show(); anchor = b
    end
  end
  frame.scan:ClearAllPoints()
  if anchor then frame.scan:SetPoint("RIGHT", anchor, "LEFT", -10, 0) else frame.scan:SetPoint("TOPRIGHT", -20, -86) end
end

-- Classic red Blizzard button
local function panelButton(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h or 22); b:SetText(text)
  return b
end

local function build()
  frame = CreateFrame("Frame", "WaypathFrame", UIParent, "BackdropTemplate")
  frame:SetSize(W, H)
  local pos = RG.db and RG.db.windowPos
  if pos then frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else frame:SetPoint("CENTER") end
  if RG.db and RG.db.lastTab and TITLES[RG.db.lastTab] then state.tab = RG.db.lastTab end
  RG.DialogBackdrop(frame)
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, rp, x, y = self:GetPoint(); RG.db.windowPos = { p, rp, x, y } end)
  frame:SetScript("OnHide", saveTab)
  frame:SetClampedToScreen(true); frame:SetFrameStrata("HIGH")
  tinsert(UISpecialFrames, "WaypathFrame")

  -- gold title banner
  RG.DialogHeader(frame, "Waypath+", 320)

  -- crest, framed like an action button
  local crest = frame:CreateTexture(nil, "ARTWORK"); crest:SetSize(44, 44); crest:SetPoint("TOPLEFT", 20, -22)
  crest:SetTexture(RG.LOGO_LARGE)

  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); frame.subtitle:SetPoint("TOPLEFT", crest, "TOPRIGHT", 14, -2)
  frame.subtitle:SetJustifyH("LEFT")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function() frame:Hide() end)
  local function sizeBtn(label, delta, anchor)
    local b = panelButton(frame, label, 34, 20)
    b:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
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

  -- classic XP bar: purple, blue while rested
  frame.xp = CreateFrame("StatusBar", nil, frame, "BackdropTemplate")
  frame.xp:SetPoint("TOPLEFT", crest, "BOTTOMRIGHT", 14, 14); frame.xp:SetPoint("RIGHT", frame, "RIGHT", -24, 0); frame.xp:SetHeight(12)
  frame.xp:SetStatusBarTexture(STATUSBAR)
  backdrop(frame.xp, { 0, 0, 0, 0.6 }, { 0.6, 0.55, 0.45, 0.9 }, 8)
  frame.xpText = frame.xp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); frame.xpText:SetPoint("CENTER", 0, 0)

  local div = frame:CreateTexture(nil, "ARTWORK"); div:SetHeight(1); div:SetPoint("TOPLEFT", 16, -74); div:SetPoint("TOPRIGHT", -16, -74)
  div:SetColorTexture(T.gold[1], T.gold[2], T.gold[3], 0.35)

  -- Character-window style tabs along the bottom edge
  tabs = {}
  local defs = { { "route", "Route" }, { "guide", "Gear guide" }, { "gear", "My gear" }, { "group", "Group" },
    { "spec2", "2nd Spec" }, { "prof", "Professions" }, { "money", "Gold & AH" }, { "settings", "Settings" } }
  local x = 12
  for _, d in ipairs(defs) do
    local b = CreateFrame("Button", nil, frame)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.text:SetText(d[2])
    local w = math.max(64, b.text:GetStringWidth() + 32)
    b.x = x
    b:SetSize(w, 32); b:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", x, 7); x = x + w - 12
    local L = b:CreateTexture(nil, "BACKGROUND"); L:SetSize(20, 32); L:SetPoint("TOPLEFT"); L:SetTexCoord(0, 0.15625, 0, 1)
    local R = b:CreateTexture(nil, "BACKGROUND"); R:SetSize(20, 32); R:SetPoint("TOPRIGHT"); R:SetTexCoord(0.84375, 1, 0, 1)
    local M = b:CreateTexture(nil, "BACKGROUND"); M:SetPoint("TOPLEFT", L, "TOPRIGHT"); M:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT"); M:SetTexCoord(0.15625, 0.84375, 0, 1)
    b.parts = { L, M, R }
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight"); hl:SetBlendMode("ADD")
    hl:SetPoint("TOPLEFT", 10, -4); hl:SetPoint("BOTTOMRIGHT", -10, 4)
    b.glow = b:CreateTexture(nil, "ARTWORK"); b.glow:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight"); b.glow:SetBlendMode("ADD")
    b.glow:SetPoint("TOPLEFT", 10, -4); b.glow:SetPoint("BOTTOMRIGHT", -10, 4); b.glow:SetAlpha(0.7); b.glow:Hide()
    b:SetScript("OnClick", function()
      if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB or 841) end
      local subs = GROUPS[d[1]]
      state.tab = subs and (state.lastSub[d[1]] or subs[1]) or d[1]
      scroll:SetVerticalScroll(0); RG.RefreshUINow()
    end)
    tabs[d[1]] = b
  end

  -- section title
  sectionTitle = frame:CreateFontString(nil, "OVERLAY"); font(sectionTitle, FONT_BODY, 16); sectionTitle:SetPoint("TOPLEFT", 22, -86); sectionTitle:SetTextColor(unpack(T.gold))
  sectionTitle:SetShadowColor(0, 0, 0, 1); sectionTitle:SetShadowOffset(1, -1)
  frame.sectionSub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); frame.sectionSub:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -4); frame.sectionSub:SetTextColor(unpack(T.dim))

  -- sub-tabs for merged tabs (top right of the section)
  frame.subBtns = {}
  for _, subs in pairs(GROUPS) do
    for _, sub in ipairs(subs) do
      local b = CreateFrame("Button", nil, frame, "BackdropTemplate")
      b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.text:SetPoint("CENTER"); b.text:SetText(SUBLABEL[sub])
      b:SetSize(b.text:GetStringWidth() + 26, 24)
      b:SetScript("OnClick", function() state.tab = sub; scroll:SetVerticalScroll(0); RG.RefreshUINow() end)
      frame.subBtns[sub] = b
    end
  end

  frame.near = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  frame.near:SetSize(24, 24); frame.near:SetPoint("TOPRIGHT", -112, -86)
  frame.near:SetChecked(state.near)
  frame.near.label = frame.near:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.near.label:SetPoint("LEFT", frame.near, "RIGHT", 2, 0); frame.near.label:SetText("Near my level")
  frame.near:SetScript("OnClick", function(self) state.near = self:GetChecked(); RG.RefreshUI() end)
  -- settings search
  frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  frame.search:SetSize(150, 20); frame.search:SetPoint("TOPRIGHT", -40, -88)
  frame.search:SetAutoFocus(false)
  frame.search.hint = frame.search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.search.hint:SetPoint("LEFT", 4, 0); frame.search.hint:SetText("Search settings")
  frame.search:SetScript("OnTextChanged", function(self)
    local t = self:GetText() or ""
    self.hint:SetShown(t == "")
    if state.search ~= t then state.search = t; RG.RefreshUI() end
  end)
  frame.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  frame.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  frame.search:Hide()

  frame.scan = panelButton(frame, "Scan prices", 110, 22)
  frame.scan:SetScript("OnClick", function() RG.ScanAH(true) end)

  scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 18, -128); scroll:SetPoint("BOTTOMRIGHT", -38, 36)
  content = CreateFrame("Frame", nil, scroll); content:SetSize(W - 56, 10)
  scroll:SetScrollChild(content)

  local footLine = frame:CreateTexture(nil, "ARTWORK"); footLine:SetHeight(1); footLine:SetPoint("BOTTOMLEFT", 16, 30); footLine:SetPoint("BOTTOMRIGHT", -16, 30); footLine:SetColorTexture(T.gold[1], T.gold[2], T.gold[3], 0.25)
  footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); footer:SetPoint("BOTTOMLEFT", 22, 7)
  -- long footers wrap onto a second line instead of running off the window
  footer:SetWidth(W - 44); footer:SetHeight(22); footer:SetJustifyH("LEFT"); footer:SetJustifyV("MIDDLE"); footer:SetWordWrap(true)
  if footer.SetMaxLines then footer:SetMaxLines(2) end

  frame:SetScript("OnShow", function() if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839) end; RG.RefreshUI() end)
  frame:SetScript("OnHide", function() if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840) end end)
  frame:Hide()
end

function RG.ShowTab(tab)
  if not frame then build() end
  if GROUPS[tab] then tab = state.lastSub[tab] or GROUPS[tab][1] end
  if not TITLES[tab] then tab = "route" end
  state.tab = tab; saveTab(); frame:Show(); RG.RefreshUI()
end

function RG.ToggleUI()
  if not frame then build() end
  if frame:IsShown() then frame:Hide() else frame:Show(); RG.RefreshUINow() end
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
