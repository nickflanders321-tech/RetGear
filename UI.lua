-- Waypath+ window, in the classic WoW style: the stone-and-gold dialog frame,
-- a gold title banner, tooltip-bordered rows, quest-log highlights, classic
-- status bars and Character-window tabs along the bottom.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local GetItemInfo = function(...) return RG.ItemInfo(...) end   -- the game has no global GetItemInfo here; Core wraps C_Item.GetItemInfo

-- ---------------------------------------------------------------------------
-- Theme
-- ---------------------------------------------------------------------------
-- Cartographer: deep ink panels, brass accent, parchment text
local T = {
  bg      = { 0.063, 0.11, 0.153, 0.97 },
  side    = { 0.047, 0.086, 0.125, 1 },  -- the sidebar
  panel   = { 0.082, 0.133, 0.176, 1 },
  raised  = { 0.106, 0.165, 0.212, 1 },
  edge    = { 0.169, 0.227, 0.278, 1 },
  line    = { 0.122, 0.176, 0.224, 1 },
  gold    = RG.ACCENT,                    -- the accent (brass)
  goldDim = { 0.55, 0.45, 0.26 },
  green   = { 0.37, 0.82, 0.54 },
  red     = { 0.95, 0.38, 0.38 },
  purple  = { 0.64, 0.21, 0.93 },         -- epic purple
  blue    = { 0.0, 0.44, 0.87 },          -- rare blue
  text    = { 0.937, 0.902, 0.824 },
  dim     = { 0.663, 0.624, 0.541 },
  row     = { 0.082, 0.133, 0.176 },
  rowEdge = { 0.169, 0.227, 0.278 },
  small   = { 0.067, 0.118, 0.161, 1 },
}
local TOOLTIP_BG, TOOLTIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Background", "Interface\\Tooltips\\UI-Tooltip-Border"
local STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"
local FONT_TITLE = RG.FONTS.display or RG.FONTS.semibold
local FONT_SEMI  = RG.FONTS.semibold
local FONT_BODY  = RG.FONTS.medium
local FONT_NUM   = RG.FONTS.regular
local WHITE = "Interface\\Buttons\\WHITE8X8"
local W, H = 1000, 680
local CW = W - 56   -- the width of the list (follows the window as you resize it)
-- Text size: 1.0 = original, saved per account. A- / A+ in the header change it.
local function TS() return (RG.db and RG.db.textSize) or 1.2 end
local function sz(n) return math.floor(n * TS() + 0.5) end
local GAP = 8
local function ROW_H() return sz(54) end
local function HEAD_H() return sz(34) end
local function SUB_H() return sz(38) end
local function BAR_H() return sz(44) end

local frame, scroll, content, tabs, footer, sectionTitle
local rows = {}
local state = { tab = "route", near = true, onlyUp = false, bySlot = false, src = nil, open = {} }
RG.UIState = state
local function saveTab() if RG.db then RG.db.lastTab = state.tab end end

-- Sections in the sidebar, each with its pages as tabs along the top. (The Group page is gone.)
local SECTIONS = {
  { key = "journey", label = "Journey", icon = "Interface\\AddOns\\Waypath\\Media\\Icons\\Journey", tabs = { "route", "plan", "flights" } },
  { key = "equip",   label = "Gear",    icon = "Interface\\AddOns\\Waypath\\Media\\Icons\\Gear", tabs = { "guide", "gear", "spec", "heal" } },
  { key = "economy", label = "Professions", icon = "Interface\\AddOns\\Waypath\\Media\\Icons\\Economy", tabs = { "prof", "fish", "ah", "gold", "mail" } },
  { key = "cards",   label = "Cards",   icon = "Interface\\AddOns\\Waypath\\Media\\Icons\\Cards", tabs = { "cards" } },
}
local GROUPS, PARENT = {}, {}
for _, sec in ipairs(SECTIONS) do GROUPS[sec.key] = sec.tabs; for _, t in ipairs(sec.tabs) do PARENT[t] = sec.key end end
-- old section names still work (/wp money, minimap menu entries...)
local ALIAS = { money = "economy", spec2 = "equip", group = "journey" }
local SUBLABEL = { route = "Route", plan = "Quest plan", flights = "Flight paths", guide = "Gear guide", gear = "What I wear", spec = "2nd spec",
  heal = "2nd spec gear", prof = "Professions", fish = "Fishing & cooking", camp = "Camping", ah = "Sell & prices", gold = "Gold tips", mail = "Bank alt",
  cards = "Cards", settings = "Settings" }
local function parentOf(tab) return PARENT[tab] or tab end
state.lastSub = {}

-- Rounded card (rows, tags, small buttons). The edge colour is no longer drawn; the fill is the look.
local function backdrop(f, bg, edge, size, radius)
  size = size or 12
  radius = radius or (size <= 9 and 5 or 9)
  if rawget(f, "rgLine") then f.rgLine:Hide() end
  RG.Round(f, bg[1], bg[2], bg[3], bg[4] or 1, radius)
end
local function font(fs, path, size, flags) if not fs:SetFont(path, size, flags or "") then fs:SetFont("Fonts\\ARIALN.TTF", size, flags or "") end end
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
-- a guide item's name from the gear data, for items whose details the game hasn't sent (or never sends)
local guideNames, guideNamesFor
function RG.GuideItemName(id)
  if guideNamesFor ~= RG.GUIDE then
    guideNames, guideNamesFor = {}, RG.GUIDE
    for _, list in ipairs({ RG.GUIDE or {}, RG.GUIDE_ALT or {} }) do
      for _, g in ipairs(list) do if g.id and g.name then guideNames[g.id] = g.name end end
    end
  end
  return guideNames[id]
end
local function itemName(id)
  local name, link, quality = RG.ItemInfo(id)
  if not name then
    RG.RequestItem(id)
    local known = RG.GuideItemName(id)
    if known then return GREY .. known .. "|r", nil, nil end
    return GREY .. "Loading item " .. id .. "...|r", nil, nil
  end
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
  green = { bg = { 0.2, 0.55, 0.3, 0.45 }, edge = { 0.25, 0.75, 0.25, 0.75 } },
  gold  = { bg = { 0.42, 0.33, 0.16, 0.55 }, edge = { 1, 0.82, 0, 0.75 } },
  red   = { bg = { 0.6, 0.2, 0.2, 0.5 }, edge = { 1, 0.2, 0.2, 0.75 } },
  muted = { bg = { 0.13, 0.19, 0.24, 1 }, edge = { 0.5, 0.5, 0.5, 0.6 } },
}

-- ---------------------------------------------------------------------------
-- Rows: header, item card, sub-row (indented quest) and progress bar
-- ---------------------------------------------------------------------------
local function getRow(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Button", nil, content, "BackdropTemplate")
  r:SetWidth(CW)
  r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetPoint("TOPLEFT", 3, -3); r.hl:SetPoint("BOTTOMRIGHT", -3, 3)
  r.hl:SetColorTexture(1, 1, 1, 0.05)

  -- accent stripe on the left edge (current zone, equipped, etc.)
  r.stripe = r:CreateTexture(nil, "ARTWORK"); r.stripe:SetPoint("TOPLEFT", 6, -11); r.stripe:SetPoint("BOTTOMLEFT", 6, 11); r.stripe:SetWidth(3)

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
  r.barBg = r:CreateTexture(nil, "ARTWORK"); r.barBg:SetHeight(10); r.barBg:SetPoint("BOTTOMLEFT", 12, 9); r.barBg:SetPoint("BOTTOMRIGHT", -12, 9); r.barBg:SetTexture(STATUSBAR); r.barBg:SetVertexColor(0.12, 0.17, 0.22, 0.9)
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
    -- a place: one click sends the arrow there
    if btn ~= "RightButton" and not self.onClick and self.onDoubleClick and RG.ARROWFN[self.onDoubleClick] then self.onDoubleClick(self); return end
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
  if rawget(r, "rgLine") then r.rgLine:Hide() end
  r.title:SetWordWrap(false); r.sub:SetWordWrap(false)
  for _, k in ipairs({ "iconBorder", "icon", "title", "sub", "pill", "meta", "head", "headLine", "barBg", "barFill", "barMark", "barLabel", "barValue", "stripe" }) do r[k]:Hide() end
end

local function setHeader(r, text)
  hideAll(r); r.itemID, r.link = nil, nil
  r.kind, r.h = "head", HEAD_H()
  font(r.head, FONT_TITLE, sz(12))
  r:SetBackdrop(nil); r.hl:Hide()
  -- small caps-style section label (only when the text has no colour codes to break)
  local label = text
  if not label:find("|", 1, true) then label = label:upper() end
  r.head:SetText(label); r.head:SetTextColor(unpack(T.dim)); r.head:SetShadowColor(0, 0, 0, 0); r.head:ClearAllPoints(); r.head:SetPoint("BOTTOMLEFT", 4, 6); r.head:Show()
  -- a header too long for one line wraps instead of running off the edge
  local maxW = CW - 8
  r.head:SetWidth(0); r.head:SetHeight(0); r.head:SetWordWrap(false)
  if (r.head:GetStringWidth() or 0) > maxW then
    r.h = math.max(r.h, math.ceil(fitText(r.head, maxW) + 12))
  end
  r:Show()
end

-- accent: "gold" | "green" | "purple" | nil  ·  quality: item quality for the icon border
local function setItem(r, id, link, title, sub, right, right2, accent, quality, small)
  hideAll(r); r.itemID, r.link = id, link
  local hero = state.hero and not small
  r.kind, r.h = small and "sub" or "item", small and SUB_H() or (hero and sz(84) or ROW_H())
  local fill = small and T.small or T.panel
  if hero then fill = { 0.118, 0.165, 0.2, 1 } elseif accent == "gold" then fill = { 0.118, 0.153, 0.18, 1 } elseif accent == "green" then fill = { 0.078, 0.149, 0.149, 1 } end
  backdrop(r, fill, nil, small and 10 or 12)
  r.hl:Show()
  local size = small and sz(24) or (hero and sz(48) or sz(38))
  r.iconBorder:SetSize(size, size)
  r.iconBorder:ClearAllPoints(); r.iconBorder:SetPoint("LEFT", small and 40 or 14, 0)
  r.iconBorder:Show(); r.icon:Show()
  r.icon:SetTexture(id and itemIcon(id) or 134400); r.icon:SetDesaturated(false)
  r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); r.icon:SetVertexColor(1, 1, 1, 1)
  local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  r.iconBorder:SetVertexColor(1, 1, 1, 1)
  if qc then r.iconBorder:SetColorTexture(qc.r, qc.g, qc.b, 0.95) else r.iconBorder:SetColorTexture(0.35, 0.33, 0.3, 0.9) end
  font(r.title, hero and FONT_TITLE or FONT_BODY, small and sz(12.5) or (hero and sz(16) or sz(14)))
  font(r.sub, FONT_NUM, small and sz(12) or (hero and sz(13.5) or sz(13)))
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
    backdrop(r.pill, PILL[kind].bg, PILL[kind].edge, 8, math.floor(sz(18) / 2))
    r.pill:ClearAllPoints(); r.pill:SetPoint(small and "RIGHT" or "TOPRIGHT", -10, small and 0 or -6)
    r.pill:Show()
  end
  if right2 and right2 ~= "" and not small then r.meta:SetText(right2); r.meta:Show() end
  if small and right2 and right2 ~= "" and not kind then r.meta:SetText(right2); r.meta:ClearAllPoints(); r.meta:SetPoint("RIGHT", -12, 0); r.meta:Show() end
  -- keep titles clear of the right column
  local rightW = math.max(kind and r.pill:GetWidth() or 0, r.meta:IsShown() and r.meta:GetStringWidth() or 0)
  local leftX = (small and 40 or 14) + size + 14
  -- long text wraps and the row grows to fit it (nothing is cut off with "...")
  local th = fitText(r.title, math.max(120, CW - leftX - rightW - 26))
  local hasSub = sub and sub ~= ""
  -- small rows centre the pill, so the second line has to stay clear of it too
  local shh = fitText(r.sub, math.max(120, CW - leftX - (small and rightW or (r.meta:IsShown() and r.meta:GetStringWidth() or 0)) - 26))
  if not hasSub then shh = 0 end
  local gap = hasSub and 2 or 0
  local content = th + gap + shh
  local pad = small and 7 or (hero and 14 or 10)
  r.h = math.max(r.h, math.ceil(content + pad * 2))
  local top = math.max(pad, (r.h - content) / 2)
  r.title:ClearAllPoints(); r.title:SetPoint("TOPLEFT", r, "TOPLEFT", leftX, -top)
  r.sub:ClearAllPoints(); r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -gap)
  if accent then
    local c = accent == "green" and T.green or ((accent == "purple" or accent == "blue") and T.dim or T.gold)   -- brass for what matters, grey for the rest
    r.stripe:SetColorTexture(c[1], c[2], c[3], 0.9); r.stripe:Show()
  end
  r:Show()
end

-- Progress bar row: label, value/max, optional marker (e.g. the hit cap)
local function setBar(r, label, value, max, color, valueText, mark)
  hideAll(r); r.itemID, r.link = nil, nil
  r.kind, r.h = "bar", BAR_H()
  font(r.barLabel, FONT_BODY, sz(12)); font(r.barValue, FONT_NUM, sz(13))
  backdrop(r, T.panel, nil, 12); r.hl:Hide()
  r.barLabel:SetText(label); r.barLabel:Show()
  r.barValue:SetText(valueText or ""); r.barValue:Show()
  r.barBg:Show()
  local width = CW - 24
  local pct = max > 0 and math.min(1, value / max) or 0
  r.barFill:SetWidth(math.max(1, width * pct)); r.barFill:SetVertexColor(color[1], color[2], color[3], 0.95); r.barFill:Show()
  if mark and max > 0 then
    r.barMark:ClearAllPoints(); r.barMark:SetPoint("CENTER", r.barBg, "LEFT", width * math.min(1, mark / max), 0); r.barMark:Show()
  end
  r:Show()
end

-- A numbered to-do line under a route step. Wraps long text; Shift-click to tick it off by hand.
local function setStep(r, num, text, done, onClick, auto)
  hideAll(r); r.itemID, r.link = nil, nil
  r.kind = "step"
  backdrop(r, { T.small[1], T.small[2], T.small[3], done and 0.55 or 1 }, nil, 10)
  r.hl:Show()
  local box = sz(16)
  r.iconBorder:SetSize(box, box); r.iconBorder:ClearAllPoints(); r.iconBorder:SetPoint("TOPLEFT", 34, -sz(9))
  local bc = auto and T.green or T.gold
  -- the classic checkbox: an empty box, with a gold check (green when the game ticked it)
  local MEDIA = "Interface\\AddOns\\Waypath\\Media\\"
  r.iconBorder:SetTexture(MEDIA .. (done and "Disc" or "Ring")); r.iconBorder:SetTexCoord(0, 1, 0, 1); r.iconBorder:Show()
  if done then r.iconBorder:SetVertexColor(bc[1], bc[2], bc[3], 1) else r.iconBorder:SetVertexColor(0.42, 0.42, 0.42, 1) end
  r.icon:SetTexture(MEDIA .. "Check"); r.icon:SetTexCoord(0, 1, 0, 1)
  r.icon:SetVertexColor(0.05, 0.07, 0.07, 1)
  r.icon:SetShown(done and true or false)
  font(r.title, FONT_NUM, sz(13))
  r.title:ClearAllPoints(); r.title:SetPoint("TOPLEFT", r.iconBorder, "TOPRIGHT", 10, 1)
  r.title:SetText((done and GREY or "|cffffffff") .. ((num ~= nil and num ~= "") and (num .. ".  ") or "") .. text .. "|r"); r.title:Show()
  local th = fitText(r.title, CW - 34 - box - 10 - 18)
  r.h = math.max(sz(32), (th or sz(14)) + sz(16))
  r.onClick = onClick
  if auto then r.tip = "Done: " .. auto .. "\n|cffa0a0a0(detected from your game)|r"
  elseif done then r.tip = "Ticked by you. Click to untick." else r.tip = "This ticks itself when you finish it.\n|cffffd100Shift-click|r to skip it by hand." end
  r:Show()
end

-- ---------------------------------------------------------------------------
-- Tabs
-- ---------------------------------------------------------------------------
-- Gear guide order: the two-hander first (your biggest upgrade), then head to toe.
local GUIDE_SLOTS = { "2H", "Main Hand", "Off Hand", "Ranged", "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Ring", "Trinket" }
local GUIDE_SLOT_LABEL = { ["2H"] = "Two-handed weapon", ["Main Hand"] = "One-handed weapon", ["Off Hand"] = "Off hand", ["Ranged"] = "Ranged / wand" }
-- "Upgrades only": hide pieces you already beat; keep tips, things you cannot use yet, and ones still loading
local SRC_CYCLE = { false, "Dungeon", "Quest", "Vendor", "Crafted", "Rare mob", "Chest", "Reputation", "BoE", "Drop" }
local function guideKeep(g, lvl)
  if g.tip or not g.id then return true end
  if not RG.GearShown(g) then return false end
  if state.src and g.how ~= state.src then return false end
  if not state.onlyUp then return true end
  local own = RG.OwnState(g.id)
  if own == "equipped" then return false end
  if g.lvl > lvl then return true end
  local _, link = GetItemInfo(g.id)
  if not link then return true end
  local d = RG.GuideDelta(g)
  return d == nil or d > 0.5
end
local function guideRank(g)   -- bigger = better: real gain first, then what you already carry, then the rest
  if not g.id then return 0 end
  local own = RG.OwnState(g.id)
  if own == "equipped" then return -1000 end
  local d = g.lvl <= UnitLevel("player") and RG.GuideDelta(g) or nil
  return (d or -50) + (own == "owned" and 5 or 0)
end
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
        if g.id and g.slot == slot and g.lvl >= lo and g.lvl <= hi and RG.OwnState(g.id) ~= "equipped" and guideKeep(g, lvl) then items[#items + 1] = g end
      end
      local rank = {}
      for _, g in ipairs(items) do rank[g] = guideRank(g) end
      table.sort(items, function(a, b) if rank[a] ~= rank[b] then return rank[a] > rank[b] end return a.lvl < b.lvl end)
      if #items > 0 then
        list[#list + 1] = { header = (GUIDE_SLOT_LABEL[slot] or slot) }   -- (the level window is the same for every slot)
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
      for _, g in ipairs(RG.GUIDE) do if g.lvl >= b[1] and g.lvl <= b[2] and guideKeep(g, lvl) then items[#items + 1] = g end end
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

local function fillGuideItem(r, g, lvl)
      local name, link, quality = itemName(g.id)
      local own = RG.OwnState(g.id)
      local d = link and RG.GuideDelta(g)
      local right, accent
      if own == "equipped" then right = GREEN .. "Equipped|r"; accent = "green"
      elseif own == "owned" then right = GOLD .. "In your bags|r"
      elseif g.bs and (RG.Skill("Blacksmithing") or 0) < g.bs then
        local sk = RG.Skill("Blacksmithing")
        right = GREY .. "Smithing " .. g.bs .. (sk and (" · you " .. sk) or "") .. "|r"
      elseif g.prof and RG.CraftState(g) == "skill" then
        local _, prof, need, have = RG.CraftState(g)
        right = GREY .. prof .. " " .. need .. (have and (" · you " .. have) or "") .. "|r"
      elseif g.lvl > lvl then right = GREY .. "Level " .. (g.approx and "~" or "") .. g.lvl .. "|r"
      elseif d then
        if d > 0.5 then right = GREEN .. "Upgrade " .. string.format("+%.0f", d) .. "|r"; accent = "gold"
        else right = GREY .. "Not an upgrade|r" end
      else right = GREY .. "Loading|r" end
      local right2 = g.ah and RG.PriceText(g.id) or (GREY .. g.how .. "|r")
      if g.bs and (RG.Skill("Blacksmithing") or 0) >= g.bs and not own then right2 = GREEN .. "You can make this|r" end
      if g.prof and RG.CraftState(g) == "make" and not own then right2 = GREEN .. "You can make this|r" end
      local qsrc = g.how == "Quest" and g.src and g.src:gsub("%s*%(.-%)$", "")
      local qIn = qsrc and RG.InLog and RG.InLog(qsrc)
      if qIn and not own then right2 = GOLD .. "Quest in your log|r" end
      local repl = ""
      if d and d > 0.5 and link then
        local _, slot = RG.Compare(link)
        local worn = slot and GetInventoryItemLink("player", slot)
        local wn = worn and GetItemInfo(worn)
        repl = GREY .. "  ·  " .. (wn and ("replaces " .. wn) or "fills an empty slot") .. "|r"
      end
      setItem(r, g.id, link, name .. GREY .. "   " .. g.slot .. "  ·  lvl " .. (g.approx and "~" or "") .. g.lvl .. "|r", g.src .. ((g.zone and g.zone ~= "") and (((g.zone and g.zone ~= "") and (GREY .. "  ·  " .. g.zone .. "|r") or "")) or "") .. repl, right, right2, accent, quality)
      r.onClick = function() RG.ShowItemSource(g, d and d > 0.5 and { note = GREEN .. string.format("+%.0f", d) .. "|r" .. GREY .. " over what you wear|r" } or nil) end
      if qIn then r.onRightClick = function() RG.OpenQuest(qsrc) end end
end

local function renderGuide()
  local list = guideRows()
  local lvl = UnitLevel("player")
  if #list == 0 then list = { { header = "Nothing near your level · untick Near my level" } } end
  -- the best pieces you could go and get right now
  do
    local best = {}
    for _, g in ipairs(RG.GUIDE) do
      if g.id and not g.tip and g.lvl <= lvl and (not state.src or g.how == state.src) and not RG.OwnState(g.id) and not (g.bs and (RG.Skill("Blacksmithing") or 0) < g.bs) and RG.GearGettable(g) then
        local _, link = GetItemInfo(g.id)
        local d = link and RG.GuideDelta(g)
        if d and d > 0.5 then best[#best + 1] = { g = g, d = d + ((g.how == "Quest" and g.src and RG.InLog and RG.InLog((g.src:gsub("%s*%(.-%)$", "")))) and 3 or 0) } end
      end
    end
    table.sort(best, function(a, b) return a.d > b.d end)
    if #best > 0 then
      local top = { { header = "Best upgrades you can get now", top = true } }
      local inTop = {}
      for i = 1, math.min(4, #best) do top[#top + 1] = { g = best[i].g }; inTop[best[i].g] = true end
      top[#top + 1] = { header = state.near and "Coming up near your level" or "The whole guide", top = true }
      -- (a piece already in the list above isn't listed twice)
      for _, e in ipairs(list) do if not (e.g and inTop[e.g]) then top[#top + 1] = e end end
      -- and a slot left with nothing under its header loses the header too
      local clean = {}
      for i, e in ipairs(top) do
        local nx = top[i + 1]
        if not (e.header and not e.top and (not nx or nx.header)) then clean[#clean + 1] = e end
      end
      top = clean
      list = top
    end
  end
  -- your 2nd spec: a link to its gear list
  -- slot by slot: what you wear and the best piece you could swap in
  if state.bySlot then
    local SLOTNUM = { Head = 1, Neck = 2, Shoulder = 3, Back = 15, Chest = 5, Wrist = 9, Hands = 10, Waist = 6, Legs = 7, Feet = 8, Ring = 11, Trinket = 13, ["2H"] = 16, ["Main Hand"] = 16, ["Off Hand"] = 17, Ranged = 18 }
    list = {}
    for _, slot in ipairs(GUIDE_SLOTS) do
      local items = {}
      for _, g in ipairs(RG.GUIDE) do
        if g.id and not g.tip and g.slot == slot and g.lvl <= lvl and RG.OwnState(g.id) ~= "equipped" and guideKeep(g, lvl) then items[#items + 1] = g end
      end
      local rank = {}
      for _, g in ipairs(items) do rank[g] = guideRank(g) end
      table.sort(items, function(a, b) return rank[a] > rank[b] end)
      local worn = SLOTNUM[slot] and GetInventoryItemLink("player", SLOTNUM[slot])
      local wn = worn and GetItemInfo(worn)
      list[#list + 1] = { header = (GUIDE_SLOT_LABEL[slot] or slot) .. GREY .. "   wearing " .. (wn or "nothing") .. "|r" }
      local g = items[1]
      local d = g and RG.GuideDelta(g)
      if g and (d == nil or d > 0.5) then list[#list + 1] = { g = g }
      else list[#list + 1] = { note = items[1] and "Nothing better at your level yet" or "No guide piece for this slot at your level" } end
    end
  end
  -- one compact control line (the 2nd spec's own gear list is on its tab, next to this one)
  table.insert(list, 1, { ctl = "view" })
  local off = 0
  for i, e in ipairs(list) do
    local r = getRow(i + off)
    if e.header then setHeader(r, e.header)
    elseif e.ctl == "view" then
      setItem(r, nil, nil, GREY .. "View|r  " .. (state.bySlot and "slot by slot" or "by level") .. GREY .. "     ·     Source|r  " .. (state.src or "any"), "", "", "", nil, nil, true)
      r.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
      r.tip = "Click: switch between by level and slot by slot.\nRight-click: show only gear from one source (Dungeon, Quest, Vendor, Crafted, Rare mob, Chest, Reputation, BoE world drops, Drop)."
      r.onClick = function() state.bySlot = not state.bySlot; scroll:SetVerticalScroll(0); RG.RefreshUINow() end
      r.onRightClick = function()
        local cur = 1
        for i, v in ipairs(SRC_CYCLE) do if (v or nil) == state.src then cur = i end end
        state.src = SRC_CYCLE[cur % #SRC_CYCLE + 1] or nil
        scroll:SetVerticalScroll(0); RG.RefreshUINow()
      end
    elseif e.note then
      setItem(r, nil, nil, GREY .. e.note .. "|r", "", "", "", nil, nil, true)
      r.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    elseif e.g.tip then
      setItem(r, nil, nil, GOLD .. "Tip|r" .. GREY .. "  ·  level " .. e.g.lvl .. "|r", e.g.text, "", "", "gold")
      r.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    else
      fillGuideItem(r, e.g, lvl)
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
RG.GuideSlotFor = guideSlotFor
local function renderGear()
  local n, total = 0, 0
  local hit, cap = RG.CurrentHit(), RG.db.hitCap
  -- summary bars first
  n = n + 1; local scoreRow = getRow(n)
  n = n + 1
  setBar(getRow(n), "Hit chance", math.min(hit, cap), cap, hit >= cap and T.green or T.gold, string.format("%s%.0f%%|r / %d%% cap", hit >= cap and GREEN or "|cffffffff", hit, cap))
  -- slots at their best for your level
  if RG.GearStatus then
    local st = RG.GearStatus()
    n = n + 1
    setBar(getRow(n), "Slots at their best for your level", st.atBest, math.max(1, st.total), st.atBest >= st.total and T.green or T.gold,
      string.format("%s%d|r / %d", st.atBest >= st.total and GREEN or "|cffffffff", st.atBest, st.total))
  end
  -- how you fight, and the weights your scores use
  local setups = RG.WeaponSetupChoices and RG.WeaponSetupChoices()
  if setups then
    local cur = RG.WeaponSetup and RG.WeaponSetup()
    local idx = 1
    for i, o in ipairs(setups) do if o.key == cur then idx = i end end
    n = n + 1
    local labels = {}
    for i, o in ipairs(setups) do labels[#labels + 1] = (i == idx and GOLD or GREY) .. o.label .. "|r" end
    setItem(getRow(n), nil, nil, "|cffffffffWeapon setup|r", table.concat(labels, GREY .. "  ·  |r"), GOLD .. setups[idx].label .. "|r", "", nil, nil, true)
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Sword_04")
    rows[n].onClick = function() local nx = setups[idx % #setups + 1]; RG.SetWeaponSetup(nx.key) end
    rows[n].tip = "Click for the next setup. Your weapon lists and upgrade scores follow how you fight."
  end
  if RG.OpenWeightEditor then
    n = n + 1
    local pname = RG.WeightProfileName and RG.WeightProfileName()
    setItem(getRow(n), nil, nil, "|cffffffffStat weights|r", GREY .. (pname and ("Your profile \"" .. pname .. "\"") or "Waypath+'s own for your spec") .. "  ·  edit them or import a Pawn scale|r",
      GOLD .. "Edit|r", "", nil, nil, true)
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    rows[n].onClick = function() RG.OpenWeightEditor() end
    local profs = RG.WeightProfiles and RG.WeightProfiles() or {}
    local names = {}
    for k in pairs(profs) do names[#names + 1] = k end
    table.sort(names)
    if #names > 0 then
      rows[n].onRightClick = function()
        local i = 0
        for j, k in ipairs(names) do if k == pname then i = j end end
        local nx = names[i + 1]
        RG.UseWeightProfile(nx)
      end
      rows[n].tip = "Click to edit. Right-click to switch profile: " .. table.concat(names, ", ") .. ", then Waypath+'s own."
    else rows[n].tip = "Click to edit your weights, save them as a profile, or paste a Pawn scale to import it." end
  end
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
    if (u.g.how == "Dungeon" or u.g.how == "Chest") and u.g.zone ~= "" then
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
      -- the quests to pick up before going in
      local dq = RG.DUNGEON_QUESTS and RG.DUNGEON_QUESTS[e.zone]
      local qn = dq and dq.quests and #dq.quests or 0
      if qn > 0 then parts[#parts + 1] = GOLD .. qn .. " quest" .. (qn > 1 and "s" or "") .. " to pick up first|r" end
      n = n + 1
      setItem(getRow(n), nil, nil, "|cffA58BD8" .. e.zone .. "|r" .. GREY .. "   " .. #e.items .. " upgrade" .. (#e.items > 1 and "s" or "") .. "|r", table.concat(parts, GREY .. "  ·  |r"),
        GREEN .. "+" .. string.format("%.0f", e.total) .. " total|r", e.lvl > lvl and (GREY .. "from level " .. e.lvl .. "|r") or "", nil, nil, true)
      rows[n].icon:SetTexture(136058)
      local ew = RG.WAYPOINTS and RG.WAYPOINTS.dungeons[e.zone]
      local zone = e.zone
      rows[n].onClick = function() state.gearDungeon = state.gearDungeon ~= zone and zone or nil; RG.RefreshUI() end
      if ew then rows[n].onRightClick = function() RG.PinWaypoint(ew) end end
      rows[n].tip = "Click for its upgrades and the quests to bring" .. (ew and "; right-click to show the entrance on the map." or ".")
      if state.gearDungeon == zone then
        for _, it in ipairs(e.items) do
          n = n + 1
          local nm, l2, q2 = itemName(it.g.id)
          setItem(getRow(n), it.g.id, l2, nm, GREY .. it.g.src .. (it.g.lvl > lvl and ("  ·  level " .. it.g.lvl) or "") .. "|r", GREEN .. string.format("+%.0f", it.d) .. "|r", "", nil, q2, true)
          local gg = it.g
          rows[n].onClick = function() RG.ShowItemSource(gg) end
        end
        for _, q in ipairs(dq and dq.quests or {}) do
          n = n + 1
          setItem(getRow(n), nil, nil, GOLD .. "Quest|r  " .. q[1], GREY .. (q[2] or "") .. ((q[3] and q[3] ~= "") and ("  ·  " .. q[3]) or "") .. "|r", "", "", nil, nil, true)
          rows[n].icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
          if q.wp then local wp = q.wp; rows[n].onClick = function() RG.Follow(wp) end; rows[n].tip = "Click to point the arrow at the quest giver." end
        end
      end
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
      local nm = RG.ItemInfo(nextUp.g.id) or nextUp.g.name or ("item " .. nextUp.g.id)
      sub = sub .. GREY .. "  ·  next: |r" .. nm .. ((nextUp.g.zone and nextUp.g.zone ~= "") and (GREY .. " · " .. nextUp.g.zone .. "|r") or "")
    end
    setItem(r, id, link, link or (GREY .. "Empty slot|r"), sub, nextUp and (GREEN .. "Upgrade +" .. string.format("%.0f", nextUp.d) .. "|r") or "", string.format("%s%.0f|r", GOLD, score), nil, quality)
    local slotName = RG.SLOT_NAMES[slot]
    -- click: the best piece from each kind of source for this slot
    r.onClick = function() state.gearSlot = state.gearSlot ~= slot and slot or nil; RG.RefreshUI() end
    r.onRightClick = nextUp and function() RG.ShowItemSource(nextUp.g, { note = GOLD .. "Next upgrade for your " .. slotName .. ":|r " .. GREEN .. string.format("+%.0f", nextUp.d) .. "|r" }) end or nil
    r.tip = "Click for the best quest reward, dungeon drop, crafted piece and Auction House find for this slot" .. (nextUp and "; right-click for the next upgrade." or ".")
    if not link then r.icon:SetTexture(136516); r.icon:SetDesaturated(true) else r.icon:SetDesaturated(false) end
    if state.gearSlot == slot and RG.GearBySource then
      local by = RG.GearBySource(guideSlotFor(slot))
      local any = false
      for _, grp in ipairs(RG.SOURCE_GROUPS) do
        local b = by[grp]
        if b then
          any = true
          n = n + 1
          local nm, l2, q2 = itemName(b.g.id)
          local pill = b.own == "equipped" and (GREEN .. "Wearing it|r") or (b.own and (GOLD .. "In your bags|r"))
            or (b.d > 0.5 and (GREEN .. string.format("+%.0f", b.d) .. "|r") or (GREY .. "no better|r"))
          setItem(getRow(n), b.g.id, l2, GOLD .. grp .. "|r  " .. nm, GREY .. (b.g.src or "") .. ((b.g.zone and b.g.zone ~= "") and (", " .. b.g.zone) or "") .. "|r",
            pill, b.g.lvl > lvl and (GREY .. "Level " .. b.g.lvl .. "|r") or "", nil, q2, true)
          local gg = b.g
          rows[n].onClick = function() RG.ShowItemSource(gg) end
        end
      end
      if not any then n = n + 1; setStep(getRow(n), "", GREY .. "Nothing in the guide for this slot near your level yet.|r", false, nil); rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil end
    end
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
      setItem(getRow(n), g.id, link2, name .. GREY .. "   " .. (GUIDE_SLOT_LABEL[g.slot] or g.slot) .. "|r", g.src .. ((g.zone and g.zone ~= "") and (GREY .. "  ·  " .. g.zone .. "|r") or ""), pill, g.ah and RG.PriceText(g.id) or "", own == "equipped" and "green" or nil, quality)
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
    local r = line(nil, "|cffffffff" .. pl.title .. "|r", pl.sub or "", "", "", icon or "Interface\\Icons\\INV_Misc_Map_01", pl.wp and "gold" or nil)
    if pl.wp then
      r.onDoubleClick = RG.ArrowFn(pl.wp)
      r.tip = "Click to put " .. pl.wp[4] .. " on your map and point the arrow at it."
    end
    return r
  end
  -- your professions: one section each, open or folded
  local mine = {}
  for _, name in ipairs(PROF_ORDER) do
    local def = RG.PROFESSIONS[name]
    -- side professions (Cooking, Fishing, First Aid) always have their section: anyone can learn them
    if def and not (RG.db.profIgnore and RG.db.profIgnore[name]) and (known[name] or def.kind == "secondary" or (RG.Plans and RG.Plans(name))) then mine[#mine + 1] = name end
  end
  local browsing = state.profSel and RG.PROFESSIONS[state.profSel] and state.profSel
  for _, m in ipairs(mine) do if m == browsing then browsing = nil end end
  RG.db.profOpen = RG.db.profOpen or {}
  local function isOpen(name)
    local v = RG.db.profOpen[name]
    if v == nil then return #mine <= 2 or name == mine[1] or name == state.profSel end
    return v
  end
  local mains = 0
  for _, m in ipairs(mine) do if RG.PROFESSIONS[m].kind ~= "secondary" then mains = mains + 1 end end
  if mains == 0 then
    head("Your professions")
    line(nil, "|cffffffffTwo main professions, plus Cooking, Fishing and First Aid|r", "Learn one and it appears here on its own. Good pairs: Mining + Blacksmithing or Engineering, Herbalism + Alchemy, Skinning + Leatherworking, Tailoring + Enchanting. Two gathering professions make the most gold while leveling.", "", "", 136240, nil, nil, true)
  end

  -- the camp object (and, for Cooking, the campfire) that goes with a profession
  local function campBlock(sel)
    local lines = {}
    for _, o in ipairs(RG.CAMP_OBJECTS or {}) do if o.prof == sel then lines[#lines + 1] = o end end
    if sel ~= "Cooking" and #lines == 0 then return end
    head("Camp")
    if sel == "Cooking" then
      local st, left = RG.CampState()
      local txt = st == "active" and (GREEN .. (left and string.format("%d min left", math.ceil(left / 60)) or "Active") .. "|r") or (st == "sitting" and (GOLD .. "Keep sitting...|r") or (st == "near" and (GOLD .. "Sit by the fire|r") or (GREY .. "No camp buff|r")))
      line(nil, "|cffffffffCamp buffs|r", "Place a campfire, add a camp object, /sit for a minute: the buffs last an hour.", txt, "", "Interface\\Icons\\Spell_Fire_Fire", "gold", nil, true)
      for _, c in ipairs(RG.CAMPFIRES or {}) do
        local have = (known.Cooking and known.Cooking.rank or 0) >= c.cook
        line(nil, (have and "|cffffffff" or GREY) .. c.name .. "|r" .. GREY .. "   " .. c.slots .. " slots|r", c.how, have and (GREEN .. "Ready|r") or (GOLD .. "Cooking " .. c.cook .. "|r"), "", "Interface\\Icons\\Spell_Fire_Fire", have and "green" or nil, nil, true)
      end
    end
    for _, o in ipairs(lines) do
      local have = (known[sel] and known[sel].rank or 0) >= o.skill
      line(nil, (have and "|cffffffff" or GREY) .. o.name .. "|r" .. GREY .. "   skill " .. o.skill .. "|r", o.buff .. GREY .. "  ·  " .. o.how .. (o.mats and ("  ·  " .. o.mats) or "") .. "|r", have and (GREEN .. "Unlocked|r") or (GOLD .. "Skill " .. o.skill .. "|r"), "", RG.PROFESSIONS[sel] and RG.PROFESSIONS[sel].icon, have and "green" or nil, nil, true)
    end
  end

  local function body(sel)
  -- a section: its bar (click to fold or open), then the guide
  local P = RG.PROFESSIONS[sel]
  local k = known[sel]
  local rank, max = k and k.rank or 0, k and k.max or 0
  if k and not k.max then max = rank end
  local open = isOpen(sel)
  n = n + 1; setBar(getRow(n), (open and "[-]  " or "[+]  ") .. sel, rank, math.max(max, rank, 1), T.gold, k and (rank .. " / " .. max) or (GREY .. "Not learned yet|r"))
  rows[n].onClick = function() RG.db.profOpen[sel] = not isOpen(sel); RG.RefreshUINow() end
  rows[n].tip = open and "Click to fold this profession." or "Click to open this profession."
  local now = RG.ProfNow(sel, rank)
  if not open then
    local what
    if not k then what = GOLD .. "Not learned yet|r"
    elseif now and now.done then what = GREEN .. "Done: 300|r"
    elseif now and now.craft then
      local short = 0
      for _, e in ipairs(now.mats or {}) do if not e.via then short = short + e.short end end
      what = "Now: " .. now.craft .. " x" .. (now.left or 0) .. (short > 0 and (GREY .. "  ·  " .. short .. " materials to get|r") or (GREEN .. "  ·  you have everything|r"))
    elseif now and now.st then what = "Now: " .. (now.st.gather or now.st.skin or (now.st.fish and ("fish in " .. now.st.fish)) or "") .. GREY .. "  ·  until " .. now.st.to .. "|r" end
    if what and k then line(nil, what, "", "", "", P.icon, nil, nil, true) end   -- (not learned: the bar already says so)
    return
  end
  local T2 = P.train or {}
  -- training
  if not k then
    local start = T2.start and T2.start[RG.RACE_LETTER]
    local pin = RG.TrainerPin(start or T2.apprentice)
    local r = line(nil, GOLD .. "Learn " .. sel .. "|r" .. GREY .. "  ·  no level needed|r", start and ("Closest trainer: " .. start) or (T2.apprentice or ""), GOLD .. "Train|r", "", P.icon, "gold")
    if pin then r.onDoubleClick = RG.ArrowFn(pin); r.tip = "Click to put " .. pin[4] .. " on your map." end
  else
    for ri = 2, #RANKS do
      local key, label, needSkill, needLvl = RANKS[ri][1], RANKS[ri][2], RANKS[ri][3], RANKS[ri][4]
      local cap = ({ 75, 150, 225, 300 })[ri - 1]
      if max <= cap and max < 300 and rank >= needSkill - 10 and T2[key] then
        local ready = rank >= needSkill and lvl >= needLvl
        local pin = RG.TrainerPin(T2[key])
        local r = line(nil, (ready and GOLD or "|cffffffff") .. "Train " .. label .. "|r" .. GREY .. "  ·  skill " .. needSkill .. ", level " .. needLvl .. "|r", T2[key],
          ready and (GOLD .. "Train now|r") or (GREY .. (rank < needSkill and ("at skill " .. needSkill) or ("at level " .. needLvl)) .. "|r"), "", P.icon, ready and "gold" or nil)
        if pin then r.onDoubleClick = RG.ArrowFn(pin); r.tip = "Click to put " .. pin[4] .. " on your map." end
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
      local col = RG.ColourText and RG.ColourText(now.colour)
      local extra = (now.leftWithMisses or 0) - (now.left or 0)
      local sub = col or (GREY .. "Open your " .. sel .. " window once and Waypath+ reads the recipe's colour.|r")
      if now.expected then
        sub = sub .. GREY .. "  ·  about " .. now.expected .. " crafts by the game's odds (learned from your crafting)" .. ((now.greyAt and now.greyAt < st.to) and (", grey at " .. now.greyAt) or "") .. "|r"
      elseif extra > 0 then sub = sub .. GREY .. "  ·  materials include " .. extra .. " extra for misses|r" end
      if #others > 0 then sub = sub .. GREY .. "\nor: " .. table.concat(others, ", ") .. "|r" end
      -- how many you can make right now (bags), after making the bars/bolts, and with vendor materials too
      if now.canNow then
        local parts = { (now.canNow > 0 and "|cffffffff" or GREY) .. "You can make " .. now.canNow .. " now|r" }
        if (now.canCrafted or 0) > now.canNow then parts[#parts + 1] = now.canCrafted .. " after making the bars or bolts" end
        if now.canVendor and now.canVendor > (now.canCrafted or 0) then parts[#parts + 1] = now.canVendor .. " with vendor materials" end
        sub = parts[1] .. (#parts > 1 and (GREY .. "  ·  " .. table.concat(parts, "  ·  ", 2) .. "|r") or "") .. "\n" .. sub
      end
      local mr = line(nil, "|cffffffffMake " .. (now.left or 0) .. " more " .. now.craft .. "|r", sub,
        GOLD .. (now.left or 0) .. " left|r", GREY .. "to skill " .. st.to .. "|r", P.icon, "gold")
      mr.tip = (st.mats and (st.mats .. "\n\n") or "") .. "Crafts left are the guide's count for the rest of this step (it already includes some misses)."
      -- a recipe learned from an item (pattern, plans, formula): where to get it
      if now.learnSrc then
        local txt = RG.RecipeSourceText(now.craft)
        if txt then
          local lr = line(nil, (now.known == false and (GOLD .. "Learn it first|r") or (GREY .. "Not from a trainer|r")) .. "|cffffffff  " .. now.craft .. "|r",
            txt .. (now.known == nil and (GREY .. "\n(Open your " .. sel .. " window and Waypath+ knows if you have it.)|r") or ""),
            now.learnSrc.how and (GOLD .. now.learnSrc.how .. "|r") or "", now.learnSrc.rank and now.learnSrc.rank > 0 and (GREY .. "skill " .. now.learnSrc.rank .. "|r") or "", "Interface\\Icons\\INV_Scroll_03", now.known == false and "gold" or nil)
          if now.learnSrc.best then
            lr.onDoubleClick = RG.ArrowFn({ now.learnSrc.best[1], now.learnSrc.best[2], now.learnSrc.best[3], now.learnSrc.best[4] })
          end
          local more = {}
          for i = 2, math.min(4, #now.learnSrc.vendors) do more[#more + 1] = "also sold by " .. now.learnSrc.vendors[i][4] end
          for _, d in ipairs(now.learnSrc.drops) do more[#more + 1] = "drops from " .. d[4] end
          lr.tip = (now.learnSrc.best and "Double-click: point the arrow there.\n" or "") .. table.concat(more, "\n")
        end
      end
      if now.skippedGrey then
        line(nil, GREY .. tostring(now.skippedGrey.craft) .. " has gone grey for you|r", GREY .. "No more points from it, so Waypath+ moved on to this step.|r", "", "", P.icon, nil, nil, true)
      end
      if #others > 0 then
        -- cheapest or fastest: which of the step's recipes to make
        local mode = RG.ProfPathMode and RG.ProfPathMode() or "cheap"
        n = n + 1
        setStep(getRow(n), "", GREY .. "Picking: |r" .. (mode == "cheap" and "the cheapest" or "the fewest materials to get") .. GREY .. "  ·  click for " .. (mode == "cheap" and "the fewest materials to get" or "the cheapest") .. "|r", false,
          function() if RG.ToggleProfPath then RG.ToggleProfPath() end end)
        rows[n].iconBorder:Hide(); rows[n].icon:Hide()
        rows[n].tip = "Cheapest: the recipe whose missing materials cost the least (vendor prices, then your last Auction House prices).\nFewest materials: the one you're closest to making from your bags (less to farm or buy)."
      end
      -- shopping list: this step, the next one too, or the rest of the route
      state.profShop = state.profShop or {}
      local scope = state.profShop[sel] or "step"
      local shop = RG.ProfShopping and RG.ProfShopping(sel, scope)
      if shop then
        local SC = { step = "this step", next = "this step and the next", all = "the rest of the route" }
        local NEXT = { step = "next", next = "all" }
        local PREV = { next = "step", all = "next" }
        local function go(to) if to then state.profShop[sel] = to; RG.RefreshUI() end end
        local missing = 0
        for _, e in ipairs(shop.list) do if e.short > 0 then missing = missing + 1 end end
        local cost = shop.total > 0 and (" ~" .. RG.Money(shop.total)) or ""
        head("Shopping list  ·  " .. SC[scope])
        rows[n].onClick = function() go(NEXT[scope]) end
        rows[n].onRightClick = function() go(PREV[scope]) end
        rows[n].tip = (NEXT[scope] and ("Click: " .. SC[NEXT[scope]] .. ".") or "") .. (PREV[scope] and ((NEXT[scope] and "\n" or "") .. "Right-click: back to " .. SC[PREV[scope]] .. ".") or "")
        n = n + 1
        local summary = missing == 0 and #(shop.learn or {}) == 0 and (GREEN .. "You have everything for " .. SC[scope] .. "|r")
          or ("|cffffffff" .. missing .. " to get|r" .. (shop.total > 0 and (GREY .. "  ·  about |r" .. RG.Money(shop.total) .. GREY .. " to buy|r") or "")
            .. (shop.unknown > 0 and (GREY .. "  ·  " .. shop.unknown .. " without a price|r") or "")
            .. (shop.owned > 0 and (GREY .. "  ·  you already have " .. RG.Money(shop.owned) .. " of it|r") or ""))
        setStep(getRow(n), "", summary, false, nil)
        rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
        -- what it really costs you: less what you gather yourself, less what the crafts sell back for at a vendor
        if (shop.gathered or 0) > 0 or (shop.sellBack or 0) > 0 then
          local parts = {}
          if (shop.gathered or 0) > 0 then parts[#parts + 1] = "you gather " .. RG.Money(shop.gathered) .. GREY .. " worth yourself (not in the total)" end
          if (shop.sellBack or 0) > 0 then parts[#parts + 1] = "what you make sells back for |r" .. RG.Money(shop.sellBack) .. GREY .. " at a vendor" end
          local net = (shop.total or 0) - (shop.sellBack or 0)
          n = n + 1
          setStep(getRow(n), "", GREY .. table.concat(parts, "  ·  ") .. ((shop.sellBack or 0) > 0 and ("  ·  |r" .. (net > 0 and ("|cffffffffreally costs about " .. RG.Money(net) .. "|r") or (GREEN .. "pays for itself|r"))) or "|r"), false, nil)
          rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = "Gathered: ore, herbs, leather or fish from a gathering profession you have count as free (they cost time, not gold).\nSells back: what a vendor pays for the items you'll make (often more on the Auction House)."
        end
        -- move between the three views both ways: back to a shorter list, or on to a longer one
        if PREV[scope] then
          n = n + 1
          setStep(getRow(n), "", GOLD .. "< Back|r" .. GREY .. "  to " .. SC[PREV[scope]] .. "|r", false, function() go(PREV[scope]) end)
          rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
        end
        if NEXT[scope] then
          n = n + 1
          setStep(getRow(n), "", GOLD .. "Show more >|r" .. GREY .. "  " .. SC[NEXT[scope]] .. "|r", false, function() go(NEXT[scope]) end)
          rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
        end
        local ahOpen = (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown())
        for _, l in ipairs(shop.learn or {}) do
          local known = RG.RecipeKnown(l.recipe, sel)
          local r = line(l.src.item, "|cffffffff" .. (RG.ItemInfo(l.src.item) or ("Recipe: " .. l.recipe)) .. "|r" .. GREY .. "   recipe, skill " .. (l.src.rank or l.from) .. "|r",
            RG.RecipeSourceText(l.recipe) or "", known == false and ("|cffff6060Learn it|r") or (GREY .. "if you don't have it|r"),
            (l.src.how == "Vendor" and l.src.price and l.src.price > 0) and (GREY .. "vendor ~|r" .. RG.Money(l.src.price)) or "", "Interface\\Icons\\INV_Scroll_03", nil, nil, true)
          if l.src.best then r.onDoubleClick = RG.ArrowFn({ l.src.best[1], l.src.best[2], l.src.best[3], l.src.best[4] }); r.tip = "Double-click: point the arrow there." end
        end
        for _, e in ipairs(shop.list) do
          local info = RG.MAT_INFO and RG.MAT_INFO[e.id]
          local kind = info and KIND_WORD[info[2]] or ""
          local name, _, quality = RG.ItemInfo(e.id)
          local title = (e.short > 0 and "|cffffffff" or GREEN) .. (name or e.name) .. "|r" .. GREY .. "   " .. kind .. "|r"
          local sub = "Need " .. e.need .. "  ·  you have " .. e.have .. (e.alts and (GREY .. "  ·  " .. e.alts .. "|r") or "")
          local price = ""
          if e.short > 0 and e.gather then
            price = GREEN .. "you gather it|r"
          elseif e.short > 0 and e.unit then
            price = GREY .. ((e.src == "vendor" and "vendor ") or (e.src == "make" and "to make ") or "AH ") .. "~|r" .. RG.Money(math.floor(e.unit * e.short + 0.5))
          end
          local r = line(e.id, title, sub, e.short > 0 and ("|cffff6060" .. e.short .. " more|r") or (GREEN .. "Ready|r"), price, nil, e.short > 0 and nil or "green", quality, true)
          if e.short > 0 then
            local pl = RG.MatPlaces(e.id, 1)[1]
            local tips = {}
            if pl and pl.wp then r.onDoubleClick = RG.ArrowFn(pl.wp); tips[#tips + 1] = pl.title .. ": " .. pl.wp[4] .. "\nDouble-click: point the arrow there." end
            if e.src ~= "vendor" then
              r.onClick = function() if RG.AHSearchItem then RG.AHSearchItem(e.id) end end
              tips[#tips + 1] = (ahOpen and "Click: search the Auction House for it." or "At the Auction House, click to search for it.")
            else
              tips[#tips + 1] = "Sold by profession supply vendors: at one, the \"Buy profession materials\" button buys what's missing (only when you click it)."
            end
            r.tip = table.concat(tips, "\n")
          end
        end
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
      head("Where to go")
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
  head(sel .. " 1-300"); rows[n].tip = "Source: " .. (P.source or "WoW Forever guide")
  if (state.profFullOf or {})[sel] then
    for _, st in ipairs(RG.ProfPlan(P)) do
      local here = now and now.st == st
      local passed = rank >= st.to and not st.train
      local title
      if st.train then title = GOLD .. "Train: " .. st.train .. "|r"
      elseif st.craft then
        title = st.craft .. GREY .. "   x" .. (st.n or "?") .. "|r"
        if not passed and RG.ProfPickOption and RG.HasPrices and RG.HasPrices() then
          local _, _, c = RG.ProfPickOption(st, st.n or 0, sel)
          if c and c > 0 then title = title .. GREY .. "  ~|r" .. RG.Money(c) end
        end
      elseif st.gather then title = st.gather .. (st.also and (GREY .. " and " .. st.also .. "|r") or "")
      elseif st.skin then title = st.skin
      elseif st.fish then title = "Fish in " .. st.fish end
      title = (here and GOLD or (passed and GREY or "|cffffffff")) .. (title or "") .. "|r"
      line(nil, title .. GREY .. "  ·  " .. st.from .. (st.to ~= st.from and ("-" .. st.to) or "") .. "|r", st.mats or st.where or "", here and (GREEN .. "You're here|r") or (passed and (GREY .. "Done|r") or ""), "", P.icon, here and "gold" or nil, nil, true)
    end
  end
  n = n + 1
  state.profFullOf = state.profFullOf or {}
  setStep(getRow(n), "", "Show every step of the " .. sel .. " route", state.profFullOf[sel], function() state.profFullOf[sel] = not state.profFullOf[sel]; RG.RefreshUI() end)
  if P.fishTab then line(nil, "|cffffffffFishing guide|r", "Zones by skill, lures, poles and the derby are on the Fishing tab (/wp fish).", "", "", P.icon, nil, nil, true) end
  if P.supplies then line(nil, GREY .. "Supplies|r", P.supplies, "", "", P.icon, nil, nil, true) end

  -- Mining and Blacksmithing extras
  if sel == "Mining" and known["Mining"] and RG.HasPrices and RG.HasPrices() then   -- (before any AH visit there's nothing to compare)
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
  if known[sel] and (sel == "Blacksmithing" or sel == "Leatherworking" or sel == "Tailoring" or sel == "Engineering") then
    local bs = known[sel]
    local headed = false
    for _, g in ipairs(RG.GUIDE) do
      local needs = (g.prof == sel and g.sk) or (sel == "Blacksmithing" and not g.prof and g.bs)
      if needs and g.id then
        if not headed then head(sel .. " upgrades for you"); headed = true end
        local name, link, quality = itemName(g.id)
        local can = bs and bs.rank >= needs
        local d = link and RG.GuideDelta(g)
        local own = RG.OwnState(g.id)
        local right = own == "equipped" and (GREEN .. "Equipped|r") or (can and (GREEN .. "You can make this|r") or (GREY .. "Needs " .. needs .. "|r"))
        local right2 = (g.lvl > lvl and (GREY .. "Wear at " .. g.lvl .. "|r")) or (d and d > 0.5 and (GREEN .. "Upgrade +" .. string.format("%.0f", d) .. "|r")) or ""
        line(g.id, name .. GREY .. "   " .. g.slot .. "  ·  lvl " .. g.lvl .. "|r", g.src .. ((g.zone and g.zone ~= "") and (GREY .. "  ·  " .. g.zone .. "|r") or ""), right, right2, nil, can and not own and "green" or nil, quality)
      end
    end
  end
  -- material prices for this profession
  local ids = P.mats or {}
  if #ids > 0 and k then
    -- only what has a price or is in your bags; the rest is one line (it would only say "no price yet")
    local rest = 0
    local headed = false
    for _, id in ipairs(ids) do
      local cnt = RG.MatCount and RG.MatCount(id) or 0
      if (RG.Price and RG.Price(id)) or cnt > 0 then
        if not headed then head("Material prices"); headed = true end
        local nm2, _, quality = itemName(id)
        line(id, nm2, cnt > 0 and ("You have " .. cnt) or "", "", RG.PriceText(id) or "", nil, nil, quality, true)
      else rest = rest + 1 end
    end
    if rest > 0 and not (RG.HasPrices and RG.HasPrices()) then
      if not headed then head("Material prices") end
      n = n + 1; setStep(getRow(n), "", GREY .. "Open the Auction House once to see what " .. sel .. "'s " .. rest .. " materials cost.|r", false, nil)
      rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
    end
  end
  campBlock(sel)
  end -- body

  local shownMain, shownSide
  for _, name in ipairs(mine) do
    local side = RG.PROFESSIONS[name].kind == "secondary"
    if side and not shownSide then shownSide = true; head("Side professions  ·  no slot needed") end
    if not side and not shownMain and mains > 0 then shownMain = true; head("Main professions") end
    body(name)
  end
  if browsing then head("Reading: " .. browsing); body(browsing) end

  -- the most profitable things you can make right now (recipes your profession windows showed, at today's prices)
  if RG.ProfitCrafts and RG.HasPrices and RG.HasPrices() then
    local any = false
    for _, name in ipairs(mine) do
      local list, total = RG.ProfitCrafts(name, 5)
      if list and #list > 0 then
        if not any then head("Most profitable crafts you know"); any = true end
        for _, c in ipairs(list) do
          local nm, _, quality = RG.ItemInfo(c.item)
          local r = line(c.item, (nm or c.name) .. GREY .. "   " .. name .. "|r",
            GREY .. "Materials |r" .. RG.Money(math.floor(c.cost + 0.5)) .. GREY .. "  ·  sells for |r" .. RG.Money(math.floor(c.sell + 0.5)) .. GREY .. " (" .. c.where .. ")|r",
            GREEN .. "+" .. RG.Money(math.floor(c.profit + 0.5)) .. "|r", "", nil, nil, quality, true)
          r.tip = "Profit per craft at your last Auction House prices (after the 5% cut), or what a vendor pays if that's more. Out of " .. total .. " " .. name .. " recipes with prices for every material."
        end
      end
    end
  end

  -- every other profession's route
  head("Other professions")
  for _, name in ipairs(PROF_ORDER) do
    local isMine = false
    for _, m in ipairs(mine) do if m == name then isMine = true end end
    local P2 = RG.PROFESSIONS[name]
    if P2 and not isMine then
      local steps = 0
      for _, st in ipairs(RG.ProfPlan(P2)) do if not st.train then steps = steps + 1 end end
      local r = line(nil, (name == browsing and GOLD or "|cffffffff") .. name .. "|r", steps .. " steps from 1 to 300" .. GREY .. "  ·  " .. (P2.kind == "gather" and "gathering" or (P2.kind or "")) .. "|r", name == browsing and (GREEN .. "Open|r") or "", "", P2.icon, name == browsing and "gold" or nil, nil, true)
      r.onClick = function() state.profSel = name; state.profFullOf = state.profFullOf or {}; state.profFullOf[name] = true; RG.RefreshUINow() end
    end
  end
  return n
end

-- The current objective as a row (shared by the Route and Quest plan tabs).
local ACT_ICON = { turnin = "Interface\\GossipFrame\\ActiveQuestIcon", pickup = "Interface\\GossipFrame\\AvailableQuestIcon",
  doing = "Interface\\Icons\\INV_Sword_27", goal = "Interface\\Icons\\INV_Misc_Map_01", route = "Interface\\Icons\\INV_Misc_Map_01", dungeon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" }
local function nowRow(n, withReqs)
  local obj = RG.Objective and RG.Objective()
  if not obj then return n, nil end
  n = n + 1
  local r = getRow(n)
  local more = (obj.count and obj.count > 1) and (GREY .. "  ·  stop " .. (obj.index or 1) .. " of " .. obj.count .. "|r") or ""
  setItem(r, nil, nil, "|cffffffff" .. obj.text .. "|r", (obj.why or "") .. more, obj.tag and (obj.tagColor .. obj.tag .. "|r") or "", obj.dist and RG.FormatYards(math.floor(obj.dist)) or "", "gold")
  r.icon:SetTexture(ACT_ICON[obj.act or obj.kind] or ACT_ICON.route)
  local wp = obj.wp
  r.onClick = function() if wp then RG.Follow(wp) end end
  r.onDoubleClick = RG.ArrowFn(wp)
  r.onRightClick = (obj.stop and obj.count and obj.count > 1) and function() RG.SkipStop(obj.stop); RG.SyncObjective(RG.Objective(true)); RG.RefreshUI(); RG.RefreshTracker() end or nil
  r.tip = (obj.tag and (obj.tagColor .. obj.tag .. "|r: " .. (obj.tagNote or "") .. "\n\n") or "") .. "Click for the map pin and arrow. Double-click turns the arrow on or off." .. (r.onRightClick and " Right-click skips this stop." or "")
  if withReqs then
    for _, rq in ipairs(obj.reqs or {}) do
      if rq.ok ~= nil or rq.kind == "obj" then
        n = n + 1
        local sr = getRow(n)
        setItem(sr, nil, nil, (rq.ok and GREY or "|cffffffff") .. rq.text .. "|r", "", "", "", nil, nil, true)
        sr.icon:SetTexture("Interface\\AddOns\\Waypath\\Media\\" .. (rq.ok and "Disc" or "Ring")); sr.icon:SetTexCoord(0, 1, 0, 1)
        sr.icon:SetVertexColor(rq.ok and T.gold[1] or 0.5, rq.ok and T.gold[2] or 0.5, rq.ok and T.gold[3] or 0.5, 1)
      end
    end
  end
  return n, obj
end

local function renderRoute()
  local lvl = UnitLevel("player")
  local mining = RG.Skill("Mining") or 0
  local n = 0
  if (state.search or "") == "" then n = nowRow(n) end
  -- reminders (bags, hearth, trainer, repairs...): they left the tracker and live here now
  if (state.search or "") == "" and RG.Reminders then
    local okR, rem = pcall(RG.Reminders)
    if okR and type(rem) == "table" and #rem > 0 then
      for i, rr in ipairs(rem) do rr.i = i end
      table.sort(rem, function(a, b) local pa, pb = a[3] or 3, b[3] or 3; if pa ~= pb then return pa < pb end return a.i < b.i end)
      n = n + 1; setHeader(getRow(n), "Reminders")
      for i = 1, math.min(4, #rem) do
        local rr = rem[i]
        n = n + 1
        setItem(getRow(n), nil, nil, rr[1], "", "", "", (rr[3] or 3) <= 1 and "gold" or nil, nil, true)
        local rw = getRow(n)
        rw.icon:SetTexture("Interface\\AddOns\\Waypath\\Media\\Icons\\Bell"); rw.icon:SetTexCoord(0, 1, 0, 1); rw.icon:SetVertexColor(T.gold[1], T.gold[2], T.gold[3], 0.95)
        rw.iconBorder:SetColorTexture(0, 0, 0, 0)
        getRow(n).onClick = rr[2]
        if rr[4] and RG.ArrowTo then local wp = rr[4]; getRow(n).onClick = function() if rr[2] then rr[2]() end; RG.ArrowTo(wp) end end
      end
    end
  end
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
    -- a new zone whose quests aren't in WoW Forever's data yet has an empty step list: that's "steps coming", not "done"
    if e.steps and #e.steps == 0 then e.steps, e.pending = nil, true end
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
    local sub = (r.notes ~= "" and r.notes or "")   -- (the hub is already in the title)
    if gather then sub = sub .. GREY .. "  ·  " .. gather .. "|r" end
    local range = r.from == r.to and ("Level " .. r.from) or ("Levels " .. r.from .. "-" .. r.to)
    -- "You are here" only where you are; the entry the tracker follows says "Now", the others at your level just their range
    local hereZone = RG.ZoneName() == r.zone
    local status = e.done and (GREEN .. "Done|r") or (now and ((hereZone and (GREEN .. "You are here|r")) or (e.focus and (GOLD .. "Now|r")) or (GREY .. range .. "|r")) or (GREY .. range .. "|r"))
    if r.fp and not e.done then
      local k = RG.KnowsFP(r.fp)
      if k == false and lvl >= r.from - 1 then status = GOLD .. "Grab the " .. r.fp .. " flight path|r"
      elseif k == true and r.kind ~= "travel" then sub = sub .. GREY .. "  ·  flight path learned|r" end
    elseif r.kind == "zone" and not e.done and RG.ZoneFlights and lvl >= r.from - 1 then
      -- no flight path written on the entry: name the zone's own flight paths you don't have yet
      local missing = {}
      for _, node in ipairs(RG.ZoneFlights(r.zone)) do if RG.KnowsFP(node) == false then missing[#missing + 1] = node end end
      if #missing == 1 then status = GOLD .. "Grab the " .. missing[1] .. " flight path|r"
      elseif #missing > 1 then status = GOLD .. "Grab " .. #missing .. " flight paths|r"; sub = sub .. GREY .. "  ·  flight paths here: " .. table.concat(missing, ", ") .. "|r" end
    end
    if e.dq then
      if e.dqDone then status = GREEN .. "Quests done|r"
      elseif lvl >= e.dq.prep and lvl < e.dq.go then status = GOLD .. "Collect quests now|r"
      elseif lvl >= e.dq.go and lvl <= r.to then status = GREEN .. "Go now|r" end
      sub = "Head over at level " .. e.dq.go .. GREY .. "  ·  " .. (e.dq.note or r.notes) .. "|r"
    end
    if r.kind == "dungeon" and not e.done and (now or e.where == "next") and RG.DUNGEON_XP_TIP then
      sub = sub .. GREY .. "  ·  " .. RG.DUNGEON_XP_TIP .. "|r"
    end
    local titleText = r.kind == "travel" and ("|cff6FA8DC" .. "Travel" .. "|r" .. GREY .. "   level " .. r.from .. "|r") or (col .. r.zone .. "|r" .. GREY .. (r.kind == "pala" and "" or ("   " .. r.hub)) .. "|r")
    local open = e.steps and not e.done and ((state.open[e.key] == nil and openDefault) or state.open[e.key] == true)
    local left = e.steps and (#e.steps - e.doneN) or 0
    local meta = (KIND[r.kind] or "") .. (e.steps and (GREY .. "   ·   " .. (e.done and ("all " .. #e.steps .. " done") or (left .. " to do")) .. "|r") or "")
    if e.pending and not e.done then
      meta = (KIND[r.kind] or "") .. GOLD .. "   ·   steps coming|r"
      if now then sub = sub .. GREY .. "  ·  Until the steps arrive, take the quests you find here: the tracker follows them.|r" end
    end
    local accent = e.done and nil or (now and "gold" or (r.kind == "pala" and "gold" or (r.kind == "dungeon" and "purple" or (r.kind == "travel" and "blue" or nil))))
    setItem(row, nil, nil, titleText, e.done and "" or sub, status, meta, accent, nil, e.done)
    if e.steps and not e.done then row.onClick = function() state.open[e.key] = not open; RG.RefreshUI() end end
    if e.steps and not e.done then row.tip = open and "Click to fold the steps." or "Click to open the steps." end
    local ew = RG.WAYPOINTS and (RG.WAYPOINTS.dungeons[r.zone] or (RG.StepWaypoint and RG.StepWaypoint(r, 1)))
    if ew then row.onRightClick = function() RG.PinWaypoint(ew) end; row.tip = (row.tip and (row.tip .. "\n") or "") .. "Right-click: show " .. ew[4] .. " on the map." end
    row.icon:SetTexture(ICON[r.kind] or 134269)
    if e.done then return end
    -- how to get there from where you are
    if open and r.kind ~= "pala" and r.kind ~= "travel" and RG.TravelPlan and RG.Opt("travelTips") then
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
      -- step pager: one unfinished step at a time (click: next, right-click: back)
      state.pager = state.pager or {}
      local total = 0
      for i = 1, #e.steps do if not (e.auto[i] or RG.db.stepsDone[e.key .. "#" .. i] or e.past) then total = total + 1 end end
      local page = state.pager[e.key]
      if page then page = math.max(1, math.min(page, math.max(total, 1))); state.pager[e.key] = page end
      local pk = e.key
      if total > 1 and page then
        n = n + 1
        do
          setItem(getRow(n), nil, nil, GOLD .. "Step " .. page .. " of " .. total .. "|r", "Click for the next step, right-click for the previous one.", GOLD .. "Next|r", GREY .. "Show all|r", nil, nil, true)
          rows[n].onClick = function() state.pager[pk] = page % total + 1; RG.RefreshUI() end
          rows[n].onRightClick = function() state.pager[pk] = (page - 2) % total + 1; RG.RefreshUI() end
          rows[n].onDoubleClick = function() state.pager[pk] = nil; RG.RefreshUI() end
          rows[n].tip = "Click: next step. Right-click: previous step. Double-click: show every step again."
        end
        rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
      end
      local seen = 0
      local nextI = (not e.done and not e.past and RG.NextStep) and RG.NextStep(r) or nil
      for i, text in ipairs(e.steps) do
        local sk = e.key .. "#" .. i
        local auto = e.auto[i]
        local isDone = auto or RG.db.stepsDone[sk] or e.past
        if not isDone then seen = seen + 1 end
        if (not isDone or showAll) and (not page or (not isDone and seen == page)) then
          num = num + 1
          n = n + 1
          local wp = RG.StepWaypoint and RG.StepWaypoint(r, i)
          local srow = getRow(n)
          -- generated steps: a short title here, the quests one per row below
          local ql, qd, qt, place, levels
          if RG.StepQuestLines then ql, qd, qt, place, levels = RG.StepQuestLines(r, i) end
          local shown = text
          if ql and place then shown = place .. (levels and (" (" .. levels .. ")") or "") .. GREY .. "  ·  " .. qd .. "/" .. qt .. " quests done|r" end
          if i == nextI and not isDone then shown = GOLD .. "Next:|r " .. shown end
          setStep(srow, i, (wp and RG.PIN or "") .. shown, isDone, function()
            -- steps tick themselves from your quest log; a hand tick needs Shift so a stray click can't skip a step
            if RG.db.stepsDone[sk] then RG.db.stepsDone[sk] = nil; RG.RefreshUI(); if RG.RefreshTracker then RG.RefreshTracker() end
            elseif IsShiftKeyDown and IsShiftKeyDown() then
              if RG.TickStep then RG.TickStep(sk, text) else RG.db.stepsDone[sk] = true; RG.RefreshUI() end
            end
          end, auto or (e.past and not RG.db.stepsDone[sk] and "you've outleveled this part of the route" or nil))
          if wp then
            srow.onRightClick = function() RG.PinWaypoint(wp) end
            srow.tip = (srow.tip or "") .. "\n|cffffd100Right-click: show " .. wp[4] .. " on the map and follow the arrow|r"
          end
          -- quests this step names that are in your log: click to open them
          if not isDone and ql then
            local VERB = { turnin = GREEN .. "Hand in|r ", pickup = "|cffffd100Pick up|r ", doing = "|cffffffffDo|r ", later = GREY .. "Later:|r " }
            -- quests that open later in a chain share one grey line (hover it for why each is waiting)
            local laters, laterTip = {}, {}
            for _, l in ipairs(ql) do if l.act == "later" then laters[#laters + 1] = l.name; laterTip[#laterTip + 1] = l.name .. ": opens " .. tostring(l.npc) end end
            for _, l in ipairs(ql) do if l.act ~= "later" then
              n = n + 1
              local qr = getRow(n)
              local sub
              if l.act == "turnin" then sub = GREEN .. "Done: take it to " .. (l.npc or "the quest giver") .. "|r"
              elseif l.act == "pickup" and l.npc and l.npc == place then sub = ""   -- (the step above already names the giver)
              elseif l.act == "pickup" then sub = GREY .. (l.npc and ("Get it from " .. l.npc) or "Starts from an item or object") .. "|r"
              elseif l.act == "doing" then sub = GREY .. "In your quest log" .. (l.prog and (": " .. l.prog) or "") .. "|r"
              else sub = GREY .. "Opens " .. l.npc .. "|r" end
              setItem(qr, nil, nil, VERB[l.act] .. RG.LevelTag(l.level) .. (l.act == "later" and GREY or "|cffffffff") .. l.name .. "|r", sub, nil, "", nil, nil, true)
              qr.icon:SetTexture(136797)
              local lw = l.wp
              qr.onClick = function() if l.act == "doing" then RG.OpenQuest(l.name, l.id) elseif lw then RG.PinWaypoint(lw) end end
              qr.onRightClick = lw and function() RG.PinWaypoint(lw) end or nil
              qr.onDoubleClick = lw and RG.ArrowFn(lw) or nil
              qr.tip = (l.act == "doing" and "Click to open it in your quest log." or (lw and ("Click: show " .. lw[4] .. " on the map\nDouble-click: arrow on / off") or "")) 
            end end
            if #laters > 0 then
              local seenL, uniq = {}, {}
              for _, nm in ipairs(laters) do if not seenL[nm] then seenL[nm] = true; uniq[#uniq + 1] = nm end end
              n = n + 1
              setStep(getRow(n), "", GREY .. "Later here: " .. table.concat(uniq, ", ") .. "|r", false, nil)
              rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = table.concat(laterTip, "\n")
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
      -- paging: one unfinished step at a time
      if total > 1 and not page then
        n = n + 1
        setStep(getRow(n), "", GREY .. "Show one step at a time|r", false, function() state.pager[pk] = 1; RG.RefreshUI() end)
        rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = "Pages through the " .. total .. " steps left here, one at a time."
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
    setHeader(r, label .. (count and (GREY .. "   " .. count .. "|r") or ""))
    r.onClick = function() state[key] = not isOpen; RG.RefreshUI() end
    r.tip = isOpen and "Click to fold this section." or "Click to show this section."
    return isOpen
  end
  local function count(where) local c = 0; for _, e in ipairs(entries) do if e.where == where then c = c + 1 end end; return c end

  -- search box: every entry whose zone, hub, notes or steps mention the words
  local sq = (state.search or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if sq ~= "" then
    local hits = 0
    for _, e in ipairs(entries) do
      local hay = (e.r.zone .. " " .. (e.r.hub or "") .. " " .. (e.r.notes or "")):lower()
      if e.steps then for _, t in ipairs(e.steps) do hay = hay .. " " .. t:lower() end end
      if hay:find(sq, 1, true) then hits = hits + 1; card(e, true) end
    end
    if hits == 0 then n = n + 1; setHeader(getRow(n), "No route entry matches \"" .. state.search .. "\"") end
    return n
  end
  -- nothing at your exact level (a new character that ticked its starting zone, say): the next zone is "Now"
  if count("now") == 0 then
    for _, e in ipairs(entries) do if e.where == "next" then e.where = "now"; e.upNext = true; break end end
  end
  -- Now: always open, steps showing
  local upNext = false
  for _, e in ipairs(entries) do if e.upNext then upNext = true end end
  if section((upNext and "Up next" or "Now") .. "  ·  level " .. lvl, "secNow", nil, true) then
    -- the entry the tracker follows comes first, open; the others at your level stay folded below it
    local cur = RG.CurrentRouteEntry and RG.CurrentRouteEntry()
    local focus
    for _, e in ipairs(entries) do if e.where == "now" and cur and e.r == cur then focus = e end end
    if not focus then for _, e in ipairs(entries) do if e.where == "now" and not e.pending and e.r.kind ~= "travel" then focus = e; break end end end
    local any = false
    if focus then focus.focus = true; state.hero = true; card(focus, true); state.hero = nil; any = true end
    local others = 0
    for _, e in ipairs(entries) do if e.where == "now" and e ~= focus then others = others + 1 end end
    if focus and others > 0 then
      n = n + 1; setStep(getRow(n), "", GREY .. "Also at your level  ·  click one to open its steps|r", false, nil)
      rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
    end
    for _, e in ipairs(entries) do if e.where == "now" and e ~= focus then card(e, false); any = true end end
    if not any then
      n = n + 1; setItem(getRow(n), nil, nil, GREEN .. "Everything for your level is done.|r", "Your next zones are under Coming up.", "", "", "green", nil, true)
    end
  end
  -- leveling pace: one line (click for splits)
  if RG.Pace and not (RG.IsAlt and RG.IsAlt()) then
    local cur, last, avg = RG.Pace()
    local eta
    if RG.XPRate then eta = select(2, RG.XPRate()) end
    n = n + 1
    local pr = getRow(n)
    setItem(pr, nil, nil, "|cffffffffLevel " .. lvl .. "|r" .. GREY .. "   " .. RG.FormatDuration(cur) .. " so far" .. (eta and ("  ·  next level in about " .. (RG.FormatETA(eta) or "?")) or "") .. "|r",
      last and (GREY .. "Last level " .. RG.FormatDuration(last) .. "  ·  average of last 5: " .. RG.FormatDuration(avg) .. "|r") or (GREY .. "Times for earlier levels appear after your next level-up|r"),
      state.pace and (GREY .. "hide splits|r") or (GREY .. "show splits|r"), "", nil, nil, true)
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

  -- Coming up: the next 5 levels, closed until you open them
  local nNext = count("next")
  if nNext > 0 and section("Coming up  ·  next 5 levels", "secNext", nNext .. " to do", true) then
    for _, e in ipairs(entries) do if e.where == "next" then card(e, false) end end
  end
  -- Later: the rest of the route, by level bracket
  local nLater = count("later")
  if nLater > 0 and lvl > 10 and section("Later", "secLater", nLater .. " to do", false) then
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
  local has = RG.HasPrices and RG.HasPrices()
  setItem(getRow(n), nil, nil, st and (GOLD .. "Checking prices: " .. st .. "|r") or "|cffffffffPrices|r",
    st and "Search for anything yourself and Waypath+ steps aside right away."
      or (not has and "Open the Auction House once and the prices fill in here."
      or ((mins and ("Last full scan " .. (mins < 60 and (mins .. " min") or (math.floor(mins / 60) .. " h")) .. " ago") or "Prices from your visits") .. GREY .. "  ·  opening the AH updates them|r")),
    st and (GREY .. "click to stop|r") or "", "", st and "gold" or nil, nil, true)
  rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  if st then rows[n].onClick = function() if RG.StopAHScan then RG.StopAHScan() end end end
  local gear, mats = {}, {}
  for _, id in ipairs(ids) do if RG.GuideByID[id] or RG.db.tracked[id] then gear[#gear + 1] = id else mats[#mats + 1] = id end end
  local function block(title, list, key)
    if #list == 0 then return end
    -- items with a price first; the ones never seen on the AH fold into one line (click to list them)
    local priced, unseen = {}, {}
    for _, id in ipairs(list) do if RG.Price(id) then priced[#priced + 1] = id else unseen[#unseen + 1] = id end end
    local showAll = state[key]
    local shown = showAll and list or priced
    n = n + 1; setHeader(getRow(n), title .. "  ·  " .. #list)
    if #unseen > 0 then
      n = n + 1
      setStep(getRow(n), "", GREY .. (showAll and "Hide the ones without a price" or ("+ " .. #unseen .. " not seen on the AH yet  ·  click to list them")) .. "|r", false, function() state[key] = not showAll; RG.RefreshUI() end)
      rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
    end
    for _, id in ipairs(shown) do
      n = n + 1
      local r = getRow(n)
      local name, link, quality = itemName(id)
      local g = RG.GuideByID[id]
      local alert = RG.db.alerts and RG.db.alerts[id]
      local sub = g and (g.src .. GREY .. "  ·  level " .. g.lvl .. "|r") or (GREY .. "Tracked by you|r")
      if alert then sub = sub .. GREY .. "  ·  alert at |r" .. RG.Money(alert) end
      setItem(r, id, link, name, sub, alert and (GOLD .. "Alert set|r") or "", RG.PriceText(id) or "", nil, quality)
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
          GREEN .. "+" .. RG.Money(e.total) .. "|r", RG.PriceText(e.id, e.link) or "", "gold", quality)
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
  block("Gear you can buy", gear, "ahAllGear")
  block("Materials", mats, "ahAllMats")
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
      setItem(getRow(n), nil, nil, GOLD .. "Your bags right now|r", (RG.HasPrices and RG.HasPrices()) and "Nothing in your bags sells for more on the AH than at a vendor." or "Open the Auction House once and the prices of what you carry (and of the items below) fill in.", "", "", "gold")
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
      local right = missing and (GREY .. "needs " .. t.prof .. "|r") or ((t.from <= 1 and t.to >= 60) and "" or (GREY .. "levels " .. t.from .. "-" .. t.to .. "|r"))
      setItem(getRow(n), nil, nil, (missing and GREY or "|cffffffff") .. t.title .. "|r", t.text, right, "", nil)
      rows[n].icon:SetTexture(GOLD_ICON[cat] or (RG.PROFESSIONS[cat] and RG.PROFESSIONS[cat].icon) or "Interface\\Icons\\INV_Misc_Coin_02")
      if t.ids and not missing then
        -- the tip's items, only once the AH has a price for them (otherwise they'd only repeat "no price yet")
        for _, id in ipairs(t.ids) do
          if RG.Price(id) then
            n = n + 1
            local name, link, quality = itemName(id)
            local p = RG.ProfitInfo and RG.ProfitInfo(id)
            local vend = p and p.vendor and p.vendor > 0 and (GREY .. "vendor |r" .. RG.Money(p.vendor)) or ""
            setItem(getRow(n), id, link, name, vend, "", RG.PriceText(id) or "", nil, quality, true)
          end
        end
      end
    end
  end
  n = n + 1
  setStep(getRow(n), "", "Show tips for every level, not just mine", state.goldAll, function() state.goldAll = not state.goldAll; RG.RefreshUI() end)
  n = n + 1; setStep(getRow(n), "", GREY .. "Tips updated " .. G.updated .. "|r", false, nil)
  rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = G.note
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
  local sure = RG.MainSpecChosen and RG.MainSpecChosen()
  n = n + 1; setHeader(getRow(n), "Your main spec  ·  the one you level as" .. (sure and "" or "  ·  not confirmed yet"))
  for _, s in ipairs(list) do
    n = n + 1
    local isMain = RG.IsMainSpec and RG.IsMainSpec(s)
    local pill = isMain and (sure and (GREEN .. "Your main spec|r") or (GOLD .. "Assumed: click to confirm|r")) or (GOLD .. "Level as this|r")
    setItem(getRow(n), nil, nil, (isMain and "|cffffffff" or "|cffd8d0c0") .. s.name .. "|r  " .. (KIND_COLOR[s.kind] or "") .. s.role .. "|r",
      GREY .. s.stats .. "|r", pill, "", isMain and sure and "green" or nil)
    specIcon(rows[n], s)
    rows[n].onClick = function() RG.SetMainSpec(s.key) end
  end
  n = n + 1; setHeader(getRow(n), "Pick your 2nd spec  ·  click one")
  for _, s in ipairs(list) do
    n = n + 1
    local chosen = cur and cur.key == s.key
    local isMain = RG.IsMainSpec and RG.IsMainSpec(s)
    local pill
    if chosen and isMain then pill = GOLD .. "You level as this|r"
    elseif chosen then pill = GREEN .. "Your 2nd spec|r"
    elseif isMain then pill = GREY .. "Your main spec|r"
    else pill = GOLD .. "Choose|r" end
    setItem(getRow(n), nil, nil, (chosen and "|cffffffff" or "|cffd8d0c0") .. s.name .. "|r  " .. (KIND_COLOR[s.kind] or "") .. s.role .. "|r",
      GREY .. s.stats .. "|r", pill, "", chosen and "green" or nil)
    specIcon(rows[n], s)
    rows[n].onClick = function() if isMain then RG.Print(s.name .. " is your main spec. Pick a different spec for your second set.") else RG.SetSecondSpec(s.key) end end
  end
  if not cur then
    n = n + 1
    setItem(getRow(n), nil, nil, GREY .. "No 2nd spec yet|r", GREY .. "Pick one above: Waypath+ then collects gear for it, never sells it, and swaps it on when you change spec. Dual spec unlocks at level " .. (RG.DUAL_SPEC_LEVEL or 40) .. ".|r", "", "", nil, nil, true)
    return n
  end
  if RG.IsMainSpec(cur) then
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
  -- (the stats are on the spec's row above)
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
local HOW_ICON = { Drop = 133639, Quest = 136797, Crafted = 136241, BoE = 133784, Dungeon = 136058, Vendor = 133784, ["Rare mob"] = 133639, Chest = 132596, Reputation = 236681 }
local function renderHeal()
  local n = 0
  local s = RG.SecondSpec and RG.SecondSpec()
  if not s or RG.IsMainSpec(s) then
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
  -- empty slots fold into one line (the hunting list below fills them); click it to see each slot's next piece
  local empty = {}
  for _, slot in ipairs(slots) do
    used[slot] = (used[slot] or 0) + 1
    if not (set[slot] and set[slot][used[slot]]) and not (slot == "Off Hand" and hasTwoHand) then empty[#empty + 1] = slot end
  end
  used = {}
  local showEmpty = state.healSlots
  for _, slot in ipairs(slots) do
    used[slot] = (used[slot] or 0) + 1
    local p = set[slot] and set[slot][used[slot]]
    if not (slot == "Off Hand" and hasTwoHand) and (p or showEmpty) then
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
      local hunt = nextG and ((RG.ItemInfo(nextG.id) or "item") .. GREY .. "  ·  " .. nextG.src .. ((nextG.zone and nextG.zone ~= "") and (", " .. nextG.zone) or "") .. "|r") or nil
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
  if #empty > 0 then
    n = n + 1
    local names, seen = {}, {}
    for _, sl in ipairs(empty) do if not seen[sl] then seen[sl] = true; names[#names + 1] = sl end end
    setStep(getRow(n), "", GREY .. (showEmpty and "Hide the empty slots" or ("+ " .. #empty .. " empty: " .. table.concat(names, ", ") .. "  ·  click for what to look for")) .. "|r", false,
      function() state.healSlots = not showEmpty; RG.RefreshUI() end)
    rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
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
    setItem(getRow(n), nil, nil, GOLD .. "Secret: a bank alt in ten minutes|r", open and GREY .. RG.ALT_INTRO .. "|r" or (GREY .. "Make a new " .. ((RG.PLAYER_FACTION == "Alliance") and "Human" or "Undead") .. " and Waypath+ walks it to the " .. ((RG.ALT_HUB and RG.ALT_HUB.ah) or "Auction House") .. " with the arrow. Click to see the steps.|r"),
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
    setItem(r, e.id, link, name, e.quest .. GREY .. "  ·  quest level " .. e.lvl .. "|r", status, RG.PriceText(e.id) or "", nil, quality, true)
    r.onClick = function() RG.SearchAH(e.id) end
  end
  if #list > 0 then
    n = n + 1
    local tl = total > 0 and ("About " .. RG.Money(total) .. " to buy everything" .. (unknown > 0 and (GREY .. "  ·  " .. unknown .. " without a price yet|r") or ""))
      or (GREY .. "Open the Auction House once to see what it all costs.|r")
    setStep(getRow(n), "", tl, false, nil); rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
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

local function renderFlights()
  local n = 0
  local list = RG.FlightList and RG.FlightList() or {}
  local sq = (state.search or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local learned, todo, hits = {}, {}, 0
  for _, e in ipairs(list) do
    local hay = (e.node .. " " .. e.zone .. " " .. (e.npc or "")):lower()
    if sq == "" or hay:find(sq, 1, true) then
      hits = hits + 1
      if e.known == true then learned[#learned + 1] = e else todo[#todo + 1] = e end
    end
  end
  local function row(e)
    n = n + 1
    local r = getRow(n)
    local status = e.known == true and (GREEN .. "Learned|r") or (e.known == false and (GOLD .. "Not learned|r") or "")
    local right2 = e.dist and (e.dist >= 1000 and string.format("%.1f km", e.dist / 1000) or string.format("%d yd", e.dist)) or ""
    setItem(r, nil, nil, "|cffffffff" .. e.node .. "|r", e.zone .. GREY .. "  ·  " .. (e.npc or "") .. "  ·  " .. string.format("%.0f, %.0f", e.x, e.y) .. "|r", status, right2, e.known == false and "gold" or nil)
    r.icon:SetTexture("Interface\\Icons\\Ability_Mount_Gryphon_01")
    local wp = e.wp
    r.onClick = function() RG.Follow(wp) end
    r.onDoubleClick = RG.ArrowFn(wp)
    r.onRightClick = function() RG.PinWaypoint(wp) end
    r.tip = "Click to be guided to " .. e.node .. " (map pin and arrow). Right-click to pin only."
  end
  if hits == 0 then n = n + 1; setHeader(getRow(n), sq ~= "" and ("No flight path matches \"" .. state.search .. "\"") or "No flight path data") return n end
  local unknown = false
  for _, e in ipairs(todo) do if e.known == nil then unknown = true end end
  if #todo > 0 then
    n = n + 1; setHeader(getRow(n), (sq == "" and "Flight paths to learn" or "Not learned") .. "  ·  " .. #todo)
    if unknown then
      n = n + 1; setStep(getRow(n), "", GREY .. "Talk to any flight master once and Waypath+ learns which of these you already have.|r", false, nil)
      rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
    end
    for _, e in ipairs(todo) do row(e) end
  end
  if #learned > 0 then
    n = n + 1; setHeader(getRow(n), "Learned  ·  " .. #learned)
    for _, e in ipairs(learned) do row(e) end
  end
  return n
end

local function renderPlan()
  local n = 0
  local obj
  n = n + 1; setHeader(getRow(n), "Right now")
  n, obj = nowRow(n, true)
  if not obj then
    n = n + 1
    setItem(getRow(n), nil, nil, "|cffffffffNothing planned yet|r", "Accept a quest and Waypath+ plans the trip. Zones with no quest data: add your own goal with /wp goto 45 60 Name.", "", "")
    getRow(n).icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  end
  local plan = RG.GuidePlan and RG.GuidePlan() or { stops = {}, elsewhere = 0 }
  local stops = plan.stops or {}
  if #stops > 0 then
    local mins = plan.eta and math.max(1, math.floor(plan.eta / 60 + 0.5))
    n = n + 1; setHeader(getRow(n), "Your trip  ·  " .. #stops .. " stop" .. (#stops > 1 and "s" or "") .. (mins and ("  ·  about " .. mins .. " min on foot") or ""))
    for i, st in ipairs(stops) do
      n = n + 1
      local r = getRow(n)
      local cur = obj and obj.stop == st
      local rest = {}
      for k = 2, #st.items do rest[#rest + 1] = RG.StopText and RG.StopText({ items = { st.items[k] } }, true) or st.items[k].title end
      local it = st.items[1]
      local tag, col = RG.QuestWorth(it.level, it.group, it.id)
      setItem(r, nil, nil, "|cffffffff" .. i .. ".  " .. (RG.StopText and RG.StopText(st) or it.title) .. "|r",
        (#rest > 0 and ("Also here: " .. table.concat(rest, ", ")) or ((it.act == "doing" and "Quest: " .. it.title) or "")) .. (cur and (GREY .. "   (you are heading here)|r") or ""),
        tag and (col .. tag .. "|r") or "", st.dist and ("+" .. RG.FormatYards(math.floor(st.dist))) or "", cur and "gold" or nil)
      r.icon:SetTexture(ACT_ICON[it.act] or ACT_ICON.route)
      local wp = st.wp
      r.onClick = function() RG.Follow(wp) end
      r.onDoubleClick = RG.ArrowFn(wp)
      r.onRightClick = function() RG.SkipStop(st); RG.SyncObjective(RG.Objective(true)); RG.RefreshUI(); RG.RefreshTracker() end
      r.tip = "Click to be guided here. Right-click to skip this stop for 10 minutes."
    end
  end
  if (plan.elsewhere or 0) > 0 then
    n = n + 1
    setItem(getRow(n), nil, nil, "|cffffffff" .. plan.elsewhere .. " task" .. (plan.elsewhere > 1 and "s are" or " is") .. " on another continent|r", "They join the plan when you arrive. The travel tips on the Route tab show how to get there.", "", "")
    getRow(n).icon:SetTexture("Interface\\Icons\\Ability_Mount_Wyvern_01")
  end
  -- quests that are not worth your time right now
  local weak = {}
  for _, q in ipairs(RG.MyQuests and RG.MyQuests() or {}) do
    if not q.complete then
      local tag, col, note, rank = RG.QuestWorth(q.level, q.group, q.id)
      if tag and rank <= 1 then weak[#weak + 1] = { q = q, tag = tag, col = col, note = note } end
    end
  end
  if #weak > 0 then
    n = n + 1; setHeader(getRow(n), "Worth a second look  ·  " .. #weak)
    for i = 1, math.min(6, #weak) do
      local w = weak[i]
      n = n + 1
      local r = getRow(n)
      setItem(r, nil, nil, "|cffffffff" .. w.q.title .. "|r", w.note, w.col .. w.tag .. "|r", w.q.level and ("L" .. w.q.level) or "")
      r.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
      local q = w.q
      r.onClick = function() RG.OpenQuest(q.title, q.id) end
      r.tip = "Click to open this quest in your log. /wp greys offers to drop the grey ones."
    end
  end
  -- quest givers close by
  local near = RG.WhatsNear and RG.WhatsNear(500) or {}
  local newOnes = {}
  for _, e in ipairs(near) do if e.act == "pickup" and (e.dist or 0) < 600 then newOnes[#newOnes + 1] = e end end
  if #newOnes > 0 then
    n = n + 1; setHeader(getRow(n), "New quests near you")
    for i = 1, math.min(4, #newOnes) do
      local e = newOnes[i]
      n = n + 1
      local r = getRow(n)
      setItem(r, nil, nil, "|cffffffff" .. e.text .. "|r", e.note or "", e.tag and (e.color .. e.tag .. "|r") or "", RG.FormatYards(math.floor(e.dist or 0)))
      r.icon:SetTexture(ACT_ICON.pickup)
      local wp = e.wp
      r.onClick = function() RG.Follow(wp) end
      r.tip = "Click to be guided to the quest giver."
    end
  end
  -- your own goals
  local goals = RG.db.goals or {}
  n = n + 1; setHeader(getRow(n), "Your own goals" .. (#goals > 0 and ("  ·  " .. #goals) or ""))
  for i, g in ipairs(goals) do
    n = n + 1
    local r = getRow(n)
    setItem(r, nil, nil, "|cffffffff" .. i .. ".  " .. tostring(g[4]) .. "|r", string.format("%.1f, %.1f", g[2], g[3]), i == 1 and (GOLD .. "Heading here|r") or "", "", i == 1 and "gold" or nil)
    r.icon:SetTexture(ACT_ICON.goal)
    r.onClick = function() RG.Follow(g) end
    r.onRightClick = function() RG.RemoveGoal(i) end
    r.tip = "Click for the arrow. Right-click removes this goal."
  end
  n = n + 1
  setItem(getRow(n), nil, nil, "|cffffffffAdd a goal|r", "/wp goto 45.2 60.8 Camp  ·  /wp goto pin turns your map pin into one  ·  works in zones with no quest data", "", "")
  getRow(n).icon:SetTexture("Interface\\Icons\\INV_Misc_Map02")
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
        z.status ~= "all" and (" A lure (+25 to +100) closes the gap.") or "") .. GREY .. "  Zone skill levels follow Wowhead's WoW Forever beta table (the same as Classic); Blizzard hasn't confirmed them.|r", pill, "", z.status == "all" and "green" or nil)
  else
    setItem(getRow(n), nil, nil, "|cffffffff" .. (zoneName ~= "" and zoneName or "This zone") .. "|r", "No fishing level known for this zone.", "", "")
  end
  rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_02")
  local pool = RG.NearestPool and RG.NearestPool()
  if pool then
    n = n + 1
    setItem(getRow(n), nil, nil, "|cffffffffNearest pool: " .. pool.name .. "|r", pool.where .. GREY .. "  ·  /wp pool|r", GOLD .. "Guide me|r", "", nil, nil, true)
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_06")
    local wp = pool.wp
    rows[n].onClick = function() RG.Follow(wp) end
    rows[n].tip = "Click to pin the nearest pool cluster and turn the arrow on."
  end
  local s = RG.FishSession()
  if s and s.catches > 0 then
    n = n + 1
    local top = {}
    for id, c in pairs(s.items) do top[#top + 1] = { id = id, c = c } end
    table.sort(top, function(a, b) return a.c > b.c end)
    local parts = {}
    for i = 1, math.min(3, #top) do parts[#parts + 1] = (itemName(top[i].id) or "?") .. " x" .. top[i].c end
    setItem(getRow(n), nil, nil, string.format("|cffffffffThis session: %d fish|r", s.catches) .. (s.perHour and (GREY .. "   " .. s.perHour .. " per hour|r") or ""),
      table.concat(parts, ", "), s.gained > 0 and (GREEN .. "+" .. s.gained .. " skill|r") or "", (s.value or 0) > 0 and ("|cffffffff" .. RG.FishMoney(s.value) .. "|r" .. (s.goldPerHour and (GREY .. "  ·  " .. RG.FishMoney(s.goldPerHour) .. "/hr|r") or "")) or "")
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_14")
  end
  -- a quiet "+ more / fewer" line under a list
  local function foldLine(open, text, key)
    n = n + 1
    setStep(getRow(n), "", GREY .. (open and "Show fewer" or text) .. "|r", false, function() state[key] = not open; RG.RefreshUI() end)
    rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
  end
  local function onOff(v) return v and (GREEN .. "On|r") or (GREY .. "Off|r") end
  local function toggle(key) RG.db[key] = not RG.Opt(key); RG.RefreshUI() end
  -- your fishing tools: one row each, click to change
  n = n + 1; setHeader(getRow(n), "Your fishing tools")
  rows[n].tip = "Everything here waits for your own click or key press: the game doesn't let add-ons fish for you."
  n = n + 1
  local key = RG.FishKey and RG.FishKey()
  setItem(getRow(n), nil, nil, "|cffffffffOne-key fishing|r", key and ("Press " .. key .. " to cast (it puts a lure on first if yours ran out), then press it again at the splash to hook the fish. It's only taken over while your pole is in your hands.") or "Pick a key: it casts, then hooks the fish when you press it at the splash.",
    key and (GOLD .. key .. "|r") or (GOLD .. "Set a key|r"), "", nil, nil, true)
  rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
  rows[n].onClick = function() if RG.FishPickKey then RG.FishPickKey(function() RG.RefreshUI() end) end end
  rows[n].onRightClick = function() if RG.FishSetKey then RG.FishSetKey(nil); RG.RefreshUI() end end
  rows[n].tip = "Click to pick a key" .. (key and ", right-click to stop using " .. key or "") .. ". Hooking uses the game's interact key on your bobber."
  n = n + 1
  setItem(getRow(n), nil, nil, "|cffffffffAuto-loot while fishing|r", "Your catch goes straight to your bags; your own setting comes back 30 seconds after your last cast.", onOff(RG.Opt("fishAutoLoot")), "", nil, nil, true)
  rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10"); rows[n].onClick = function() toggle("fishAutoLoot") end; rows[n].tip = "Click to turn it " .. (RG.Opt("fishAutoLoot") and "off" or "on") .. "."
  if RG.FishOutfitState then
    local st, pole = RG.FishOutfitState()
    n = n + 1
    local poleName = pole and itemName(pole)
    setItem(getRow(n), nil, nil, "|cffffffffFishing outfit|r", st == "on" and "Your pole is in your hands. Click for your weapons and gear back; a fight puts your weapons back too." or (pole and ("Puts on " .. poleName .. GREY .. " and any fishing gear in your bags.|r") or "No fishing pole in your bags yet: see Poles, lures and fishing gear below."),
      st == "on" and (GOLD .. "Weapons back|r") or (pole and (GOLD .. "Go fishing|r") or ""), "", nil, nil, true)
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Fishingpole_02")
    rows[n].onClick = function() if st == "on" then RG.FishGearOff() else RG.FishGearOn() end; if C_Timer then C_Timer.After(0.5, RG.RefreshUI) end end
    rows[n].onRightClick = function() RG.FishSaveOutfit() end
    rows[n].tip = "Click to " .. (st == "on" and "put your weapons back" or "put your fishing outfit on") .. ". Right-click while wearing your fishing hat, boots or gloves to make them part of the outfit.  /wp gofish  ·  /wp weapons"
  end
  -- goals: Artisan, the Extravaganza, your camp
  local pg = RG.FishPagle and RG.FishPagle()
  local dst, dmin
  if RG.FishDerby then dst, dmin = RG.FishDerby() end
  local ct = RG.FishCampTip and RG.FishCampTip()
  if pg or dst or ct then n = n + 1; setHeader(getRow(n), "Goals") end
  if pg then
    n = n + 1
    setItem(getRow(n), nil, nil, "|cffffffffArtisan Fishing: Nat Pagle's four fish|r", "Take Nat Pagle, Angler Extreme at Tidefury Cove, Dustwallow Marsh first: these fish only bite once you have it. Click a fish to pin where it bites.",
      (pg.done == 4 and GREEN or GOLD) .. pg.done .. " / 4|r", "", pg.done == 4 and "green" or "gold")
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_31")
    for _, f in ipairs(pg.list) do
      n = n + 1
      local name, link, quality = itemName(f.id)
      setItem(getRow(n), f.id, link, name, GREY .. f.where .. "|r", f.have > 0 and (GREEN .. "Got it|r") or (GREY .. "Not yet|r"), "", nil, quality, true)
      if f.wp then local wp = f.wp; rows[n].onClick = function() RG.Follow(wp) end; rows[n].tip = "Click to pin where it bites and turn the arrow on." end
    end
  end
  if dst then
    n = n + 1
    local h, m = math.floor(dmin / 60), dmin % 60
    local when = (h >= 24 and (math.floor(h / 24) .. " d " .. (h % 24) .. " h") or (h > 0 and (h .. " h " .. m .. " min") or (m .. " min")))
    local tf, school = 0, nil
    if RG.FishTastyfish then tf, school = RG.FishTastyfish() end
    local sub = dst == "on" and ("Speckled Tastyfish: " .. tf .. " / 40. Turn in 40 to Riggle Bassbait in Booty Bay to win; every 5 also pay out at Jang.") or
      ("Sundays from 2 pm server time in Stranglethorn Vale." .. (tf > 0 and (" You have " .. tf .. " Speckled Tastyfish: Jang in Booty Bay pays out for every 5.") or ""))
    setItem(getRow(n), nil, nil, "|cffffffffStranglethorn Fishing Extravaganza|r", sub,
      dst == "on" and (GREEN .. "On: " .. h .. "h " .. m .. "m left|r") or (GREY .. "in " .. when .. "|r"), "", dst == "on" and "gold" or nil, nil, true)
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_30")
    rows[n].onClick = function() if school then RG.Follow(school) else state.fishDerby = not state.fishDerby; RG.RefreshUI() end end
    rows[n].onRightClick = function() state.fishDerby = not state.fishDerby; RG.RefreshUI() end
    rows[n].tip = (school and "Click to pin the Tastyfish schools. " or "") .. "Right-click for how it works and the prizes."
    if state.fishDerby then
      for _, line in ipairs(RG.FISH_DERBY) do
        n = n + 1; setStep(getRow(n), "", GREY .. line .. "|r", false, nil)
        rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
      end
    end
  end
  if ct then
    n = n + 1
    setItem(getRow(n), nil, nil, "|cffffffffYour " .. ct.name .. "|r", "Set it down where you fish: " .. ct.what .. ". Needs " .. ct.mats .. ".", GREY .. "Camp tab|r", "", nil, nil, true)
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_24")
    rows[n].onClick = function() if RG.ShowTab then RG.ShowTab("camp") end end
    rows[n].tip = "Click for the Camp tab: blueprints, materials and where to get them."
  end
  -- what this zone can bring up, and what is worth your time
  local best = RG.FishBest and RG.FishBest()
  if best then
    local mine, myN = nil, 0
    if RG.FishMyRates then mine, myN = RG.FishMyRates(best.zone) end
    if myN < 20 then mine = nil end   -- (too few catches to say)
    n = n + 1; setHeader(getRow(n), "What you can catch here  ·  " .. best.zone .. GREY .. "  (about " .. RG.FishMoney(best.perCatch) .. " per catch" .. (mine and (", your " .. myN .. " catches here in brackets") or "") .. ")|r")
    local shown = 0
    for _, e in ipairs(best.list) do
      if shown >= 8 then break end
      shown = shown + 1
      n = n + 1
      local name, link, quality = itemName(e.id)
      local pill = (e == best.bestEv and e.ev > 0) and (GREEN .. "Worth the most|r") or (e == best.bestValue and e.value > 0 and (GOLD .. "Priciest fish|r")) or ""
      setItem(getRow(n), e.id, link, name .. GREY .. string.format("   %.1f%% of catches", e.chance) .. (mine and string.format("  (you: %d%%)", math.floor((mine[e.id] or 0) + 0.5)) or "") .. "|r", e.value > 0 and ("Worth " .. RG.FishMoney(e.value) .. GREY .. " each (" .. (e.src == "AH" and "auction house" or "vendor") .. ")  ·  about " .. RG.FishMoney(e.ev) .. " per catch|r") or (GREY .. "No price yet: scan the auction house|r"), pill, "", pill ~= "" and "gold" or nil, quality, true)
    end
  end
  -- catch log
  local flog = RG.db.fish and RG.db.fish.log
  if flog and #flog > 0 then
    local shownLog = state.fishLogAll and math.min(30, #flog) or math.min(5, #flog)
    n = n + 1; setHeader(getRow(n), string.format("Catch log  ·  all time %s", RG.FishMoney(RG.db.fish.goldTotal or 0)))
    for i = 1, shownLog do
      local e = flog[i]
      n = n + 1
      local name, link, quality = itemName(e.id)
      local ago = time() - (e.t or 0)
      local when = ago < 90 and "just now" or (ago < 5400 and (math.floor(ago / 60) .. " min ago") or (math.floor(ago / 3600) .. " h ago"))
      local adv, advTip
      if RG.FishAdvice then adv, advTip = RG.FishAdvice(e.id) end
      setItem(getRow(n), e.id, link, name .. GREY .. "   x" .. (e.qty or 1) .. "|r", GREY .. (e.zone or "") .. "  ·  " .. when .. "|r" .. (adv and ("  ·  " .. adv) or ""), (e.v or 0) > 0 and (GOLD .. RG.FishMoney((e.v or 0) * (e.qty or 1)) .. "|r") or "", "", nil, quality, true)
    end
    if #flog > 5 then foldLine(state.fishLogAll, "+ " .. (math.min(30, #flog) - 5) .. " more catches", "fishLogAll") end
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
  n = n + 1; setHeader(getRow(n), "Where to fish for your skill")
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
  -- a grey "+ more / hide" line under a list
  local function moreLine(open, count, what, key)
    n = n + 1
    setStep(getRow(n), "", GREY .. (open and "Show fewer" or ("+ " .. count .. " " .. what)) .. "|r", false, function() state[key] = not open; RG.RefreshUI() end)
    rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
  end
  -- gear: what you have and what you can use now; the rest folds away
  n = n + 1; setHeader(getRow(n), "Poles, lures and fishing gear")
  local useful, other = {}, {}
  for _, g in ipairs(RG.FISH_GEAR) do
    local have = GetItemCount and GetItemCount(g.id, true) or 0
    if have > 0 or (not g.skill or g.skill <= math.max(fsk, 1) + 25) and not tostring(g.how):find("Extravaganza") then useful[#useful + 1] = g else other[#other + 1] = g end
  end
  local gearList = useful
  if state.fishGearAll then gearList = {}; for _, g in ipairs(useful) do gearList[#gearList + 1] = g end; for _, g in ipairs(other) do gearList[#gearList + 1] = g end end
  for _, g in ipairs(gearList) do
    n = n + 1
    local name, link, quality = itemName(g.id)
    local have = GetItemCount and GetItemCount(g.id, true) or 0
    local pill
    if have > 0 then pill = GREEN .. (g.kind == "lure" and ("You have " .. have) or "You have it") .. "|r"
    elseif g.skill and fsk < g.skill then pill = GREY .. "Fishing " .. g.skill .. "|r"
    else pill = "" end
    setItem(getRow(n), g.id, link, name .. GREY .. "   +" .. g.bonus .. (g.mins and (" for " .. g.mins .. " min") or "") .. "|r", g.how, pill, "", have > 0 and "green" or nil, quality, true)
  end
  if #other > 0 then moreLine(state.fishGearAll, #other, "more for higher skill and the Extravaganza", "fishGearAll") end
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
      local seenHere = zoneName and RG.FishLearned and RG.FishLearned(zoneName, e.id) and chance ~= nil
      if seenHere then sub = "|cff66dd88You caught this here|r" .. (sub ~= "" and ("  ·  " .. sub) or "") end
      setItem(getRow(n), e.id, link, nm, sub, seenHere and (GREEN .. "caught|r") or pillFor(chance or e.best), "", nil, quality, true)
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
    rows[n].tip = "Chances are per catch, from the game's fishing loot tables (WoW Forever's own numbers aren't published). Hover a row for every zone; click a pool to pin it on your map."
    -- this zone
    local here = FL.zones[zoneName or ""]
    if here then
      note("|cffffffffIn " .. zoneName .. " you can catch:|r")
      for _, c in ipairs(here) do
        local e = idx.byId[c[1]]
        if e then lootRow(e, c[2]) end
      end
    end
    -- groups, closed until you open them
    local CATS = { { "fish", "Fish and cooking ingredients" }, { "container", "Chests, crates, trunks, clams and bottles" },
      { "material", "Materials, water and other catches" }, { "misc", "Potions and miscellaneous" }, { "gear", "Gear" }, { "junk", "Junk" } }
    for _, cat in ipairs(CATS) do
      local lst = idx.byKind[cat[1]]
      if lst and #lst > 0 then
        local open = state.fishOpen[cat[1]]
        n = n + 1
        setStep(getRow(n), "", GOLD .. (open and "- " or "+ ") .. cat[2] .. "|r" .. GREY .. "  " .. #lst .. "|r", false,
          function() state.fishOpen[cat[1]] = not open; RG.RefreshUI() end)
        rows[n].iconBorder:Hide(); rows[n].icon:Hide(); rows[n].tip = nil
        if open then for _, e in ipairs(lst) do lootRow(e) end end
      end
    end
    -- pools
    local open = state.fishOpen.pools
    n = n + 1
    setStep(getRow(n), "", GOLD .. (open and "- " or "+ ") .. "Pools, schools, wreckage and fishing spots|r" .. GREY .. "  " .. #FL.pools .. "|r", false,
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
    setItem(getRow(n), f.id, link, name, f.note, "", RG.PriceText(f.id) or "", nil, quality, true)
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
  { "Leveling and quests", { "tracker", "trackerFade", "trackerLocked", "compactTracker", "trackerCombatFold", "trackerInter", "mapClicks", "spf", "fishTracker", "trackerProfs", "levelBanner", "autoQuest", "newQuests", "autoArrow", "smartStepOrder", "smartPlan", "shareObjective", "autoReward", "rewardPicker", "nameplateAlert", "arrow", "travelTips", "fpNudge", "efficiency", "talentReminder", "reminders", "wellFed", "campReminder" } },
  { "Gear and combat", { "tooltip", "tooltipBest", "upgradeToast", "paperdoll", "gearPanel", "questUpgradeMarks", "dungeonHelper", "exorcism", "stoneReminder", "ammoReminder", "healSet", "specSwap", "bagArrows", "weaponTips", "levelReport" } },
  { "Group play", { "groupDuties", "groupAlerts", "arcadeToasts" } },
  { "Professions, bags and gold", { "mineReminder", "oreAlert", "oreAlertAll", "herbAlert", "sellJunk", "autoRepair", "bagReminder", "sortButton", "fishImmersive", "fishSound", "fishRecast", "fishCombatSwap", "fishCampTip", "profitWatch", "autoScan", "ahProgress", "profReminder", "profQuests", "profTips", "profBuyButton", "profTooltip" } },
  { "Interface", { "minimap", "sounds", "quietErrors", "sharePrompt" } },
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
      -- every word you type must appear somewhere (any order), in the setting or its group: "arrow sound", "ah scan"
      local keep = {}
      for _, o in ipairs(grp[2]) do
        local hay = (grp[1] .. " " .. o.label .. " " .. o.key):lower()
        local all = true
        for w in q:gmatch("%S+") do if not hay:find(w, 1, true) then all = false; break end end
        if all then keep[#keep + 1] = o end
      end
      grp.any = {}
      for _, o in ipairs(grp[2]) do
        local hay = (grp[1] .. " " .. o.label .. " " .. o.key):lower()
        for w in q:gmatch("%S+") do if #w > 2 and hay:find(w, 1, true) then grp.any[#grp.any + 1] = o; break end end
      end
      grp[2] = keep; hits = hits + #keep
    end
    -- nothing has every word: show what has any of them
    if hits == 0 then for _, grp in ipairs(ordered) do grp[2] = grp.any or {}; hits = hits + #grp[2] end end
    if hits == 0 then n = n + 1; setHeader(getRow(n), "No settings match \"" .. state.search .. "\"") end
  end
  if q == "" then
    n = n + 1; setHeader(getRow(n), "Look")
    n = n + 1
    local cur = RG.db.accent or "mint"
    setItem(getRow(n), nil, nil, "Accent colour", "Click to change: Mint, Gold, Sky, Rose, Violet or High contrast. Some text keeps its colour until /reload.", GOLD .. (RG.ACCENTS[cur] or RG.ACCENTS.mint)[1] .. "|r", "", "gold")
    rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Variety_01")
    rows[n].onClick = function() RG.SetAccent(nil) end
    -- arrow size: click to step bigger (it wraps back to the smallest), or use the mouse wheel over the arrow
    n = n + 1
    local sizes = { 0.6, 0.8, 1, 1.25, 1.5, 2, 2.5, 3 }
    local cs = RG.db.arrowScale or 1
    setItem(getRow(n), nil, nil, "Arrow size", "Click to make the arrow bigger (it wraps round). Mouse wheel over the arrow, or /wp arrowsize 150, also work.", GOLD .. math.floor(cs * 100 + 0.5) .. "%|r", "")
    rows[n].icon:SetTexture("Interface\\Icons\\Ability_Hunter_MarkedForDeath")
    rows[n].onClick = function()
      local nxt = sizes[1]
      for _, v in ipairs(sizes) do if v > cs + 0.01 then nxt = v break end end
      RG.SetArrowScale(nxt)
      if RG.ArrowTo and RG.RefreshArrow then RG.RefreshArrow() end
      RG.RefreshUI()
    end
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
  action(RG.CardsOnly() and "Turn Cards only off" or "Cards only mode", RG.CardsOnly() and "Brings the guide, tracker and helpers back (reloads)" or "Turns off the guide, tracker, arrow and every helper and pop-up: only the trading cards, packs and Arena stay (reloads)", function()
    RG.SetCardsOnly(not RG.CardsOnly())
    if ReloadUI then ReloadUI() end
  end)
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
local function renderCards()
  local n = 0
  local a, own, total, prints = { coins = 0 }, 0, 0, 0
  if RG.ArcadeStats then a, own, total, prints = RG.ArcadeStats() end
  local price = RG.ArcadePackPrice or 25
  local coins = a.coins or 0
  n = n + 1
  setItem(getRow(n), nil, nil, "|cffffffffWaypath Arena|r", "Duel the computer with the cards you have found. Every card plays as a minion, a spell or a weapon.  " .. GREY .. "Record " .. (a.bWins or 0) .. " won, " .. (a.bLoss or 0) .. " lost.|r", GOLD .. "Play|r", "", "gold")
  getRow(n).icon:SetTexture("Interface\\Icons\\Ability_Warrior_Challange")
  getRow(n).onClick = function() if RG.ShowBattle then RG.ShowBattle() end end
  n = n + 1
  setItem(getRow(n), nil, nil, "|cffffffffOpen a pack|r", "Five cards: items, NPCs and places from the world, some as rare, holo or full art prints.", price == 0 and (GREEN .. "Free in the beta|r") or (GOLD .. price .. " coins|r"), "", price == 0 and "green" or ((coins >= price) and "gold" or nil))
  getRow(n).icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
  getRow(n).onClick = function() if RG.ArcadeBuyNow then RG.ArcadeBuyNow() end end
  n = n + 1
  setItem(getRow(n), nil, nil, "|cffffffffYour collection|r", own .. " of " .. total .. " cards  ·  " .. prints .. " prints. Browse, sort, pin favourites to your showcase and trade extras.", GOLD .. "Open|r", "", nil)
  getRow(n).icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  getRow(n).onClick = function() if RG.ShowArcade then RG.ShowArcade() end end
  n = n + 1
  setItem(getRow(n), nil, nil, "|cffffffffCoins|r", "You earn coins from quests, kills, skill-ups and duel wins." .. GREY .. "  Today's goals and the full ledger are in the collection window.|r", GOLD .. coins .. "|r", "", nil)
  getRow(n).icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  return n
end

local TITLES = {
  route = { "Leveling route", "Your path from your starting zone to 60" },
  guide = { "Gear guide", "Upgrades for your spec by level, and where they come from" },
  gear  = { "My gear", "What you're wearing and what to chase next" },
  prof  = { "Professions", "Where you are in each profession, what you still need, and where to go for it" },
  ah    = { "Auction House", "Lowest buyout from your last scan" },
  settings = { "Settings", "Turn Waypath+'s helpers on or off" },
  gold  = { "Gold making", "Up-to-date ways to make money as a miner and smith" },
  camp  = { "Camping", "Campfire buffs, what to place, and the camp steps along your route" },
  plan = { "Quest plan", "The best order for the quests in your log, with what each one needs" },
  flights = { "Flight paths", "Every flight master for your faction: click one and Waypath+ guides you there" },
  fish  = { "Fishing & cooking", "Where to fish for your skill, ranks, gear, and fish that level your Cooking" },
  mail  = { "Bank alt", "Quest items to buy and mail instead of farming" },
  cards = { "Cards", "Collect cards from the world and duel with them in Waypath Arena" },
  group = { "Group play", "How grouping is going, your class duties, shared quests and finding a group" },
  spec  = { "2nd spec", "Pick any spec of your class: its stats, how to play it and its gear" },
  heal  = { "2nd spec gear", "Gear to start collecting for your 2nd spec, and where to find it" },
}
local FOOTERS = {
  route = "Click a zone to open its tasks  ·  steps tick themselves  ·  Shift-click to skip one  ·  finished steps are hidden",
  guide = "Click an item to see where it drops or which quest gives it  ·  Shift-click to link  ·  Ctrl-click to preview",
  gear  = "Click an item to see where it drops or which quest gives it  ·  /wp weight tunes the score",
  prof  = "Double-click a place for the arrow  ·  counts include your bank (open it once)",
  ah    = "Opening the AH refreshes old prices  ·  your own searches pause the scan  ·  /wp alert [item] 25",
  settings = "Settings are saved per character (prices and window positions are shared)",
  gold  = "Updated weekly from the newest Forever gold guides  ·  /wp profit lists what to keep for the AH",
  plan = "Click a stop for the arrow  ·  right-click skips it for 10 minutes  ·  /wp next does it from the keyboard  ·  /wp goto adds your own goal",
  flights = "Click a flight path for the arrow  ·  fly there once to learn it  ·  /wp fp points at the nearest one you haven't learned",
  fish  = "Open your Cooking window once so Waypath+ knows your recipes  ·  /wp fishmode: immersive fishing on/off",
  camp  = "One camp object per hour  ·  camp buffs don't stack with the matching class buff  ·  /wp camp",
  mail  = "Click an item to search the AH for it  ·  /wp main makes the current character your main",
  cards = "Click a row to play, open a pack or browse your collection  ·  /wp arena  ·  /wp cards",
  group = "Click a quest to share it  ·  click a suggestion to post LFG  ·  /wp lfg Scarlet Monastery posts your own",
  spec  = "Dual spec unlocks at level 40 at your class trainer  ·  /wp spec",
  heal  = "Pieces in your 2nd set are never sold  ·  the list updates twice a week  ·  /wp heal",
}

-- ---------------------------------------------------------------------------
-- The sidebar (the traveler's satchel): you, the four sections with their badges, your satchel
-- ---------------------------------------------------------------------------
local SIDE_W, SIDE_MIN = 212, 60
local function sideWidth()
  if not frame then return SIDE_W end
  if (RG.db and RG.db.sideCollapsed) or (frame:GetWidth() or W) < 820 then return SIDE_MIN end
  return SIDE_W
end
-- badges: quests ready to hand in (Journey) and card packs waiting to be opened (Cards)
local function turnInsReady()
  local n = 0
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.IsComplete then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.questID and C_QuestLog.IsComplete(info.questID) then n = n + 1 end
    end
  end
  return n
end
local function packsWaiting() return (RG.ArcadePacksWaiting and RG.ArcadePacksWaiting()) or 0 end
RG.UITurnInsReady, RG.UIPacksWaiting = turnInsReady, packsWaiting

local function updateHeader()
  local sd = frame.side
  if not sd then return end
  local lvl = UnitLevel("player") or 1
  local xp, max = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
  local capLvl = GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
  local rested = GetXPExhaustion and GetXPExhaustion() or nil
  local pct = (max and max > 0 and lvl < capLvl) and (xp / max) or 1
  sd.name:SetText(UnitName("player") or "")
  sd.level:SetText(lvl); sd.ringLevel:SetText(lvl)
  sd.xp:SetMinMaxValues(0, 1); sd.xp:SetValue(pct)
  if rested and rested > 0 then sd.xp:SetStatusBarColor(0.38, 0.62, 0.95) else sd.xp:SetStatusBarColor(unpack(T.gold)) end
  local cls = RG.ActiveClass or {}
  local bits = { (RG.ClassSupported and cls.name) or (UnitClass("player") or "") }
  if lvl < capLvl and max and max > 0 then
    bits[#bits + 1] = math.floor(pct * 100) .. "%"
    local avg
    if RG.Pace then local _, _, a = RG.Pace(); avg = a end
    if avg and avg > 0 then bits[#bits + 1] = "~" .. math.max(1, math.floor(avg * (1 - pct) / 60 + 0.5)) .. "m" end
    if rested and rested > 0 then bits[#bits + 1] = "|cff6fa8f0rested|r" end
  else bits[#bits + 1] = "max level" end
  sd.sub:SetText(table.concat(bits, " · "))
  sd.ring:SetVertexColor(unpack(T.gold))
  -- sections
  local cur = parentOf(state.tab)
  local badge = { journey = turnInsReady(), cards = packsWaiting() }
  for _, b in ipairs(sd.nav) do
    local on = b.key == cur
    b.bg:SetShown(on); b.bar:SetShown(on)
    b.text:SetTextColor(unpack(on and T.text or T.dim))
    if on then b.icon:SetVertexColor(T.gold[1], T.gold[2], T.gold[3], 1) else b.icon:SetVertexColor(T.dim[1], T.dim[2], T.dim[3], 0.9) end
    local n = badge[b.key] or 0
    local full = sideWidth() == SIDE_W
    b.badge:SetShown(n > 0 and full); b.badgeT:SetText(n > 9 and "9+" or n); b.dot:SetShown(n > 0 and not full)
  end
  sd.settings.text:SetTextColor(unpack(state.tab == "settings" and T.gold or T.dim))
  local sc = state.tab == "settings" and T.gold or T.dim
  sd.settings.ic:SetVertexColor(sc[1], sc[2], sc[3], 0.95)
  -- the satchel
  sd.hearth:SetText(GetBindLocation and GetBindLocation() or "?")
  sd.gold:SetText(RG.Money and RG.Money(GetMoney and GetMoney() or 0) or "")
  local ok, _, _, total = false
  if RG.ProfitList then ok, _, _, total = pcall(RG.ProfitList) end
  sd.sell:SetText((ok and type(total) == "number" and total > 0 and RG.Money) and RG.Money(total) or GREY .. "nothing yet|r")
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
  for _, r in pairs(rows) do r:Hide() end
  updateHeader()
  for _, r in pairs(rows) do r:SetWidth(CW) end
  local n
  local okRender, errRender = pcall(function()
  if state.tab == "guide" then n = renderGuide()
  elseif state.tab == "gear" then n = renderGear()
  elseif state.tab == "route" then n = renderRoute()
  elseif state.tab == "prof" then n = renderProf()
  elseif state.tab == "settings" then n = renderSettings()
  elseif state.tab == "gold" then n = renderGold()
  elseif state.tab == "heal" then n = renderHeal()
  elseif state.tab == "spec" then n = renderSpec()
  elseif state.tab == "group" then n = renderGroup()
  elseif state.tab == "cards" then n = renderCards()
  elseif state.tab == "mail" then n = renderMail()
  elseif state.tab == "camp" then n = renderCamp()
  elseif state.tab == "fish" then n = renderFish()
  elseif state.tab == "flights" then n = renderFlights()
  elseif state.tab == "plan" then n = renderPlan()
  else n = renderAH() end
  end)
  if not okRender then
    for _, r in pairs(rows) do r:Hide() end
    n = 0
    if RG.RecordError then pcall(RG.RecordError, tostring(errRender)) end
    local er = getRow(math.max(1, (type(n) == "number" and n or 0) + 1))
    setItem(er, nil, nil, RED .. "This page hit an error|r", GREY .. tostring(errRender):sub(1, 220) .. "|r", "", "", nil, nil, true)
    er.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    n = math.max(1, (type(n) == "number" and n or 0) + 1)
  end
  sectionTitle:SetText(TITLES[state.tab][1]); frame.sectionSub:SetText(TITLES[state.tab][2])
  footer:SetText(FOOTERS[state.tab])
  frame.near:SetShown(state.tab == "guide")
  if frame.onlyUp then frame.onlyUp:SetShown(state.tab == "guide") end
  if state.searchFor ~= state.tab then
    state.searchFor = state.tab; state.search = ""
    if frame.search then frame.search:SetText("") end
  end
  if frame.search then
    frame.search:SetShown(state.tab == "settings" or state.tab == "route" or state.tab == "flights")
    frame.search.hint:SetText(state.tab == "route" and "Search the route" or (state.tab == "flights" and "Search flight paths" or "Search settings"))
  end
  for _, b in ipairs(frame.hdr or {}) do
    local on = b.isOn()
    b.ic:SetVertexColor(on and T.gold[1] or T.dim[1] * 0.8, on and T.gold[2] or T.dim[2] * 0.8, on and T.gold[3] or T.dim[3] * 0.8, 1)
  end
  frame.scan:SetShown(state.tab == "ah")
  -- stack rows with their own heights
  local y = 0
  for i = 1, n do
    local r = rows[i]
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetHeight(r.h or ROW_H())
    y = y + (r.h or ROW_H()) + GAP
  end
  content:SetHeight(math.max(1, y))
  -- this section's pages as tabs along the top
  for _, b in pairs(frame.subBtns) do b:Hide() end
  local subs = GROUPS[parentOf(state.tab)]
  local x = frame.contentLeft or 230
  if subs and #subs > 1 then
    state.lastSub[parentOf(state.tab)] = state.tab
    for _, sub in ipairs(subs) do
      local b = frame.subBtns[sub]
      local on = sub == state.tab
      font(b.text, on and FONT_SEMI or FONT_BODY, sz(12.5)); b.text:SetTextColor(unpack(on and T.text or T.dim))
      b:SetWidth(b.text:GetStringWidth() + 4); b.line:SetShown(on)
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -8); b:Show()
      x = x + b:GetWidth() + 22
    end
  elseif subs then state.lastSub[parentOf(state.tab)] = state.tab end
  -- page tools sit on the title line, right side
  local anchor
  for _, f in ipairs({ frame.scan, frame.search, frame.near, frame.onlyUp }) do
    if f and f:IsShown() then
      f:ClearAllPoints()
      local lw = (f == frame.near or f == frame.onlyUp) and (f.label:GetStringWidth() + 6) or 0
      if anchor then f:SetPoint("RIGHT", anchor, "LEFT", -(14 + lw), 0) else f:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(24 + lw), -62) end
      anchor = f
    end
  end
end

-- Classic red Blizzard button
local function panelButton(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h or 22)
  backdrop(b, T.raised, nil, 8, 7)
  b.label = b:CreateFontString(nil, "OVERLAY"); font(b.label, FONT_BODY, 12); b.label:SetPoint("CENTER", 0, 0); b.label:SetTextColor(unpack(T.text))
  b.SetText = function(self, t) self.label:SetText(t) end
  b.GetText = function(self) return self.label:GetText() end
  b:SetScript("OnEnter", function(self) self:SetBackdropColor(T.edge[1], T.edge[2], T.edge[3], 1); self.label:SetTextColor(unpack(T.gold)) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropColor(T.raised[1], T.raised[2], T.raised[3], 1); self.label:SetTextColor(unpack(T.text)) end)
  b:SetText(text)
  return b
end

-- Lay the window out for its current size: sidebar (full or icons), tabs, title, list.
local function relayout()
  if not frame then return end
  local sw = sideWidth()
  local sd = frame.side
  sd:SetWidth(sw)
  local full = sw == SIDE_W
  for _, k in ipairs({ "logoText", "card", "satchel", "collapse" }) do if sd[k] then sd[k]:SetShown(full) end end
  sd.ringBox:SetShown(not full); sd.expand:SetShown(not full)
  for _, b in ipairs(sd.nav) do
    b:SetWidth(full and (SIDE_W - 20) or (SIDE_MIN - 12))
    b.text:SetShown(full)
    b.icon:ClearAllPoints(); if full then b.icon:SetPoint("LEFT", 12, 0) else b.icon:SetPoint("CENTER") end
    b.dotAnchor = not full
  end
  sd.settings.text:SetShown(full)
  sd.settings.ic:ClearAllPoints(); if full then sd.settings.ic:SetPoint("LEFT", 12, 0) else sd.settings.ic:SetPoint("CENTER") end
  sd.settings:SetWidth(full and (SIDE_W - 20) or (SIDE_MIN - 12))
  local L = sw + 22
  frame.contentLeft = L
  sectionTitle:ClearAllPoints(); sectionTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", L, -54)
  scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", L, -108); scroll:SetPoint("BOTTOMRIGHT", -30, 36)
  frame.footLine:ClearAllPoints(); frame.footLine:SetPoint("BOTTOMLEFT", sw + 16, 30); frame.footLine:SetPoint("BOTTOMRIGHT", -16, 30)
  footer:ClearAllPoints(); footer:SetPoint("BOTTOMLEFT", L + 4, 7)
  local fw = frame:GetWidth() or W
  -- a narrow window keeps the page tabs clear: the quick switches step aside (they're in Settings too)
  for _, b in ipairs(frame.hdr or {}) do b:SetShown(fw >= 900) end
  CW = math.max(300, fw - L - 38)
  footer:SetWidth(CW)
  content:SetWidth(CW)
end
RG.UIRelayout = function() relayout(); RG.RefreshUI() end

-- Small brass-accented text button (header tools, satchel collapse...)
local function iconButton(parent, tex, size, tip, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b.ic = b:CreateTexture(nil, "ARTWORK"); b.ic:SetSize(size - 12, size - 12); b.ic:SetPoint("CENTER"); b.ic:SetTexture(tex); b.ic:SetVertexColor(T.dim[1], T.dim[2], T.dim[3], 1)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.06)
  b:SetScript("OnClick", onClick)
  if tip then
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(tip); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return b
end

local function buildSidebar()
  local sd = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.side = sd
  sd:SetPoint("TOPLEFT", 0, 0); sd:SetPoint("BOTTOMLEFT", 0, 0); sd:SetWidth(SIDE_W)
  sd:SetFrameLevel((frame:GetFrameLevel() or 1) + 2)
  RG.Round(sd, T.side[1], T.side[2], T.side[3], 1, 10)
  local edge = sd:CreateTexture(nil, "ARTWORK"); edge:SetWidth(1); edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetColorTexture(T.edge[1], T.edge[2], T.edge[3], 1)
  -- name and the fold button
  sd.logoText = sd:CreateFontString(nil, "OVERLAY"); font(sd.logoText, FONT_TITLE, 19); sd.logoText:SetPoint("TOPLEFT", 16, -16)
  sd.logoText:SetText("Waypath" .. GOLD .. "+|r"); sd.logoText:SetTextColor(unpack(T.text))
  sd.collapse = iconButton(sd, "Interface\\AddOns\\Waypath\\Media\\Icons\\FoldLeft", 24, "Fold the sidebar", function() RG.db.sideCollapsed = true; relayout(); RG.RefreshUINow() end)
  sd.collapse:SetPoint("TOPRIGHT", -10, -12)
  sd.expand = iconButton(sd, "Interface\\AddOns\\Waypath\\Media\\Icons\\FoldRight", 24, "Open the sidebar", function() RG.db.sideCollapsed = nil; relayout(); RG.RefreshUINow() end)
  sd.expand:SetPoint("BOTTOM", 0, 44)
  -- the character card: name, level, XP bar, a line about your pace
  local card = CreateFrame("Frame", nil, sd, "BackdropTemplate"); sd.card = card
  card:SetPoint("TOPLEFT", 12, -48); card:SetPoint("TOPRIGHT", -12, -48); card:SetHeight(70)
  RG.Round(card, T.bg[1], T.bg[2], T.bg[3], 1, 8)
  sd.name = card:CreateFontString(nil, "OVERLAY"); font(sd.name, FONT_SEMI, 13); sd.name:SetPoint("TOPLEFT", 12, -12); sd.name:SetTextColor(unpack(T.text))
  sd.level = card:CreateFontString(nil, "OVERLAY"); font(sd.level, FONT_TITLE, 20); sd.level:SetPoint("TOPRIGHT", -12, -8); sd.level:SetTextColor(unpack(T.gold))
  sd.xp = CreateFrame("StatusBar", nil, card); sd.xp:SetPoint("TOPLEFT", 12, -36); sd.xp:SetPoint("TOPRIGHT", -12, -36); sd.xp:SetHeight(4); sd.xp:SetStatusBarTexture(WHITE)
  local xb = sd.xp:CreateTexture(nil, "BACKGROUND"); xb:SetAllPoints(); xb:SetColorTexture(T.edge[1], T.edge[2], T.edge[3], 1)
  sd.sub = card:CreateFontString(nil, "OVERLAY"); font(sd.sub, FONT_NUM, 11); sd.sub:SetPoint("TOPLEFT", 12, -48); sd.sub:SetPoint("TOPRIGHT", -12, -48); sd.sub:SetJustifyH("LEFT"); sd.sub:SetWordWrap(false); sd.sub:SetTextColor(unpack(T.dim))
  -- folded: a level ring instead of the card
  local rb = CreateFrame("Frame", nil, sd); sd.ringBox = rb
  rb:SetSize(44, 44); rb:SetPoint("TOP", 0, -14)
  sd.ring = rb:CreateTexture(nil, "ARTWORK"); sd.ring:SetAllPoints(); sd.ring:SetTexture("Interface\\AddOns\\Waypath\\Media\\Ring")
  sd.ringLevel = rb:CreateFontString(nil, "OVERLAY"); font(sd.ringLevel, FONT_TITLE, 16); sd.ringLevel:SetPoint("CENTER", 0, 0); sd.ringLevel:SetTextColor(unpack(T.text))
  -- the four sections
  sd.nav = {}
  for i, sec in ipairs(SECTIONS) do
    local b = CreateFrame("Button", nil, sd)
    b.key = sec.key
    b:SetSize(SIDE_W - 20, 40); b:SetPoint("TOPLEFT", 10, -132 - (i - 1) * 44)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(T.panel[1], T.panel[2], T.panel[3], 1)
    b.bar = b:CreateTexture(nil, "ARTWORK"); b.bar:SetWidth(2); b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetColorTexture(T.gold[1], T.gold[2], T.gold[3], 1)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.05)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(18, 18); b.icon:SetPoint("LEFT", 12, 0); b.icon:SetTexture(sec.icon)
    b.text = b:CreateFontString(nil, "OVERLAY"); font(b.text, FONT_BODY, 14); b.text:SetPoint("LEFT", b.icon, "RIGHT", 12, 0); b.text:SetText(sec.label)
    b.badge = CreateFrame("Frame", nil, b); b.badge:SetSize(20, 20); b.badge:SetPoint("RIGHT", -10, 0)
    local bb = b.badge:CreateTexture(nil, "ARTWORK"); bb:SetAllPoints(); bb:SetTexture("Interface\\AddOns\\Waypath\\Media\\Disc"); bb:SetVertexColor(T.gold[1], T.gold[2], T.gold[3], 1)
    b.badgeT = b.badge:CreateFontString(nil, "OVERLAY"); font(b.badgeT, FONT_SEMI, 11); b.badgeT:SetPoint("CENTER", 0, 0); b.badgeT:SetTextColor(0.08, 0.06, 0.04)
    b.dot = b:CreateTexture(nil, "OVERLAY"); b.dot:SetSize(8, 8); b.dot:SetPoint("TOPRIGHT", -6, -6); b.dot:SetTexture("Interface\\AddOns\\Waypath\\Media\\Disc"); b.dot:SetVertexColor(T.gold[1], T.gold[2], T.gold[3], 1)
    b:SetScript("OnClick", function()
      state.tab = state.lastSub[sec.key] or sec.tabs[1]
      scroll:SetVerticalScroll(0); saveTab(); RG.RefreshUINow()
    end)
    b:SetScript("OnEnter", function(self)
      if sideWidth() ~= SIDE_W then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(sec.label)
        if sec.key == "journey" and turnInsReady() > 0 then GameTooltip:AddLine(turnInsReady() .. " ready to hand in", 1, 1, 1) end
        if sec.key == "cards" and packsWaiting() > 0 then GameTooltip:AddLine(packsWaiting() .. " packs to open", 1, 1, 1) end
        GameTooltip:Show() end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    sd.nav[i] = b
  end
  -- the satchel: hearth, gold, what your bags would sell for
  local sat = CreateFrame("Frame", nil, sd); sd.satchel = sat
  sat:SetPoint("BOTTOMLEFT", 16, 50); sat:SetPoint("BOTTOMRIGHT", -16, 50); sat:SetHeight(92)
  local line = sat:CreateTexture(nil, "ARTWORK"); line:SetHeight(1); line:SetPoint("TOPLEFT", -4, 0); line:SetPoint("TOPRIGHT", 4, 0); line:SetColorTexture(T.line[1], T.line[2], T.line[3], 1)
  local head = sat:CreateFontString(nil, "OVERLAY"); font(head, FONT_SEMI, 10); head:SetPoint("TOPLEFT", 0, -12); head:SetText("IN YOUR SATCHEL"); head:SetTextColor(unpack(T.dim))
  local function satRow(i, label)
    local l = sat:CreateFontString(nil, "OVERLAY"); font(l, FONT_NUM, 12); l:SetPoint("TOPLEFT", 0, -14 - i * 20); l:SetText(label); l:SetTextColor(unpack(T.dim))
    local v = sat:CreateFontString(nil, "OVERLAY"); font(v, FONT_BODY, 12); v:SetPoint("TOPRIGHT", 0, -14 - i * 20); v:SetJustifyH("RIGHT"); v:SetTextColor(unpack(T.text))
    v:SetPoint("LEFT", l, "RIGHT", 8, 0); v:SetWordWrap(false)
    return v
  end
  sd.hearth = satRow(1, "Hearth"); sd.gold = satRow(2, "Gold"); sd.sell = satRow(3, "Sellable")
  -- settings at the very bottom
  local st = CreateFrame("Button", nil, sd); sd.settings = st
  st:SetSize(SIDE_W - 20, 34); st:SetPoint("BOTTOMLEFT", 10, 10)
  st.ic = st:CreateTexture(nil, "ARTWORK"); st.ic:SetSize(16, 16); st.ic:SetPoint("LEFT", 13, 0); st.ic:SetTexture("Interface\\AddOns\\Waypath\\Media\\Icons\\Settings"); st.ic:SetVertexColor(T.dim[1], T.dim[2], T.dim[3], 0.9)
  st.text = st:CreateFontString(nil, "OVERLAY"); font(st.text, FONT_BODY, 13); st.text:SetPoint("LEFT", st.ic, "RIGHT", 10, 0); st.text:SetText("Settings")
  local sh = st:CreateTexture(nil, "HIGHLIGHT"); sh:SetAllPoints(); sh:SetColorTexture(1, 1, 1, 0.05)
  st:SetScript("OnClick", function() state.tab = "settings"; scroll:SetVerticalScroll(0); saveTab(); RG.RefreshUINow() end)
end

local function build()
  frame = CreateFrame("Frame", "WaypathFrame", UIParent, "BackdropTemplate")
  local size = RG.db and RG.db.windowSize
  frame:SetSize(size and size[1] or W, size and size[2] or H)
  local pos = RG.db and RG.db.windowPos
  if pos then frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else frame:SetPoint("CENTER") end
  if RG.db and RG.db.lastTab and TITLES[RG.db.lastTab] and RG.db.lastTab ~= "group" then state.tab = RG.db.lastTab end
  RG.DialogBackdrop(frame)
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, rp, x, y = self:GetPoint(); RG.db.windowPos = { p, rp, x, y } end)
  frame:SetClampedToScreen(true); frame:SetFrameStrata("HIGH")
  tinsert(UISpecialFrames, "WaypathFrame")
  frame:SetScale((RG.db and RG.db.windowScale) or 1)
  -- drag the bottom-right corner to resize the window (it remembers its size)
  frame:SetResizable(true)
  if frame.SetResizeBounds then frame:SetResizeBounds(640, 480, 1600, 1200) elseif frame.SetMinResize then frame:SetMinResize(640, 480); if frame.SetMaxResize then frame:SetMaxResize(1600, 1200) end end
  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -4, 4); grip:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"); grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    if RG.db then RG.db.windowSize = { math.floor(frame:GetWidth() + 0.5), math.floor(frame:GetHeight() + 0.5) }; local p, _, rp, x, y = frame:GetPoint(); RG.db.windowPos = { p, rp, x, y } end
    relayout(); RG.RefreshUINow()
  end)
  grip:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT"); GameTooltip:SetText("Drag to resize"); GameTooltip:AddLine("Double-click for the standard size", 1, 1, 1); GameTooltip:Show() end)
  grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
  grip:SetScript("OnDoubleClick", function() frame:SetSize(W, H); frame:SetScale(1); if RG.db then RG.db.windowSize = nil; RG.db.windowScale = nil end; relayout(); RG.RefreshUINow() end)
  local lastW, lastH
  frame:SetScript("OnSizeChanged", function(self, w, h)
    if lastW and math.abs((w or 0) - lastW) < 2 and math.abs((h or 0) - lastH) < 2 then return end
    lastW, lastH = w, h
    if scroll then relayout(); RG.RefreshUI() end
  end)

  buildSidebar()

  -- top right: quick switches, text size, close
  local close = CreateFrame("Button", nil, frame)
  close:SetSize(26, 26); close:SetPoint("TOPRIGHT", -10, -9)
  close.x = close:CreateFontString(nil, "OVERLAY"); font(close.x, FONT_BODY, 20); close.x:SetPoint("CENTER", 0, 1); close.x:SetText("\195\151"); close.x:SetTextColor(unpack(T.dim))
  close:SetScript("OnEnter", function(self) self.x:SetTextColor(unpack(T.gold)) end)
  close:SetScript("OnLeave", function(self) self.x:SetTextColor(unpack(T.dim)) end)
  close:SetScript("OnClick", function() frame:Hide() end)
  local function sizeBtn(label, delta, anchor)
    local b = panelButton(frame, label, 30, 20)
    b:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
    b:SetScript("OnClick", function()
      RG.db.textSize = math.max(0.9, math.min(1.7, (RG.db.textSize or 1.2) + delta))
      RG.RefreshUI()
    end)
    local enter, leave = b:GetScript("OnEnter"), b:GetScript("OnLeave")
    b:SetScript("OnEnter", function(self) enter(self); GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(delta > 0 and "Bigger text" or "Smaller text"); GameTooltip:Show() end)
    b:SetScript("OnLeave", function(self) leave(self); GameTooltip:Hide() end)
    return b
  end
  local plus = sizeBtn("A+", 0.1, close)
  local minus = sizeBtn("A-", -0.1, plus)
  frame.hdr = {}
  local function hdrToggle(key, iconPath, tipTitle, tipText, action, isOn, anchor)
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(26, 24); b:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.06)
    b.ic = b:CreateTexture(nil, "OVERLAY"); b.ic:SetSize(15, 15); b.ic:SetPoint("CENTER"); b.ic:SetTexture(iconPath)
    b.isOn = isOn
    b:SetScript("OnClick", function() action(); RG.RefreshUI() end)
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(tipTitle); if tipText then GameTooltip:AddLine(tipText, 1, 1, 1, true) end; GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.hdr[#frame.hdr + 1] = b
    return b
  end
  local a1 = hdrToggle("arrow", "Interface\\AddOns\\Waypath\\Media\\Icons\\Arrow", "Arrow", "Turn the waypoint arrow on or off.",
    function() RG.ToggleArrow() end, function() return RG.ArrowOnState() end, minus)
  local a2 = hdrToggle("tracker", "Interface\\AddOns\\Waypath\\Media\\Icons\\Tracker", "Tracker", "Show or hide the quest tracker.",
    function() RG.db.tracker = not RG.Opt("tracker"); if RG.RefreshTracker then RG.RefreshTracker() end end, function() return RG.Opt("tracker") end, a1)
  local a3 = hdrToggle("sounds", "Interface\\AddOns\\Waypath\\Media\\Icons\\Sound", "Sounds", "Pop-up sounds on or off.",
    function() RG.db.sounds = not RG.Opt("sounds") end, function() return RG.Opt("sounds") end, a2)
  hdrToggle("report", "Interface\\AddOns\\Waypath\\Media\\Icons\\Report", "Report this step", "Copy what you are on (step, quests, position) to paste into a bug report.",
    function() if RG.ReportStep then RG.ReportStep() end end, function() return true end, a3)
  tabs = {}

  -- the line under the page tabs
  frame.tabLine = frame:CreateTexture(nil, "ARTWORK"); frame.tabLine:SetHeight(1)
  frame.tabLine:SetPoint("TOPLEFT", frame.side, "TOPRIGHT", 0, -40); frame.tabLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -40)
  frame.tabLine:SetColorTexture(T.line[1], T.line[2], T.line[3], 1)
  -- page tabs (this section's pages), drawn in RefreshUINow
  frame.subBtns = {}
  for _, sec in ipairs(SECTIONS) do
    for _, sub in ipairs(sec.tabs) do
      local b = CreateFrame("Button", nil, frame)
      b.text = b:CreateFontString(nil, "OVERLAY"); font(b.text, FONT_BODY, 12.5); b.text:SetPoint("CENTER", 0, 0); b.text:SetText(SUBLABEL[sub] or sub)
      b:SetSize(b.text:GetStringWidth() + 4, 32)
      b.line = b:CreateTexture(nil, "OVERLAY"); b.line:SetHeight(2); b.line:SetPoint("BOTTOMLEFT", 0, -1); b.line:SetPoint("BOTTOMRIGHT", 0, -1); b.line:SetColorTexture(T.gold[1], T.gold[2], T.gold[3], 1)
      b:SetScript("OnEnter", function(self) if not self.line:IsShown() then self.text:SetTextColor(unpack(T.text)) end end)
      b:SetScript("OnLeave", function(self) if not self.line:IsShown() then self.text:SetTextColor(unpack(T.dim)) end end)
      b:SetScript("OnClick", function() state.tab = sub; scroll:SetVerticalScroll(0); saveTab(); RG.RefreshUINow() end)
      frame.subBtns[sub] = b
    end
  end

  -- page title (serif) and its one-line description
  sectionTitle = frame:CreateFontString(nil, "OVERLAY"); font(sectionTitle, FONT_TITLE, 22); sectionTitle:SetPoint("TOPLEFT", 234, -54); sectionTitle:SetTextColor(unpack(T.text))
  frame.sectionSub = RG.NewText(frame, "GameFontHighlightSmall"); frame.sectionSub:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -4); frame.sectionSub:SetTextColor(unpack(T.dim))

  frame.near = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  frame.near:SetSize(24, 24)
  frame.near:SetChecked(state.near)
  frame.near.label = RG.NewText(frame.near, "GameFontNormalSmall")
  frame.near.label:SetPoint("LEFT", frame.near, "RIGHT", 2, 0); frame.near.label:SetText("Near my level"); frame.near.label:SetTextColor(unpack(T.text))
  frame.near:SetScript("OnClick", function(self) state.near = self:GetChecked(); RG.RefreshUI() end)
  frame.onlyUp = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  frame.onlyUp:SetSize(24, 24)
  frame.onlyUp:SetChecked(state.onlyUp)
  frame.onlyUp.label = RG.NewText(frame.onlyUp, "GameFontNormalSmall")
  frame.onlyUp.label:SetPoint("LEFT", frame.onlyUp, "RIGHT", 2, 0); frame.onlyUp.label:SetText("Upgrades only"); frame.onlyUp.label:SetTextColor(unpack(T.text))
  frame.onlyUp:SetScript("OnClick", function(self) state.onlyUp = self:GetChecked() and true or false; RG.RefreshUI() end)
  frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  frame.search:SetSize(170, 20)
  frame.search:SetAutoFocus(false)
  frame.search.hint = RG.NewText(frame.search, "GameFontDisableSmall")
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
  scroll:SetPoint("TOPLEFT", 234, -108); scroll:SetPoint("BOTTOMRIGHT", -30, 36)
  pcall(function()   -- slim scroll bar: no arrow buttons, a thin thumb
    local sb = scroll.ScrollBar
    if not sb then return end
    for _, k in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do if sb[k] then sb[k]:Hide(); sb[k]:SetAlpha(0); sb[k]:EnableMouse(false) end end
    local th = sb.GetThumbTexture and sb:GetThumbTexture()
    if th then th:SetTexture(WHITE); th:SetVertexColor(T.edge[1] * 1.6, T.edge[2] * 1.6, T.edge[3] * 1.6, 1); th:SetWidth(5) end
    if sb.SetWidth then sb:SetWidth(8) end
    local track = sb:CreateTexture(nil, "BACKGROUND"); track:SetAllPoints(sb); track:SetColorTexture(1, 1, 1, 0.04)
    local function sizeThumb()
      if not th then return end
      local range, view = scroll:GetVerticalScrollRange() or 0, scroll:GetHeight() or 0
      th:SetHeight(range > 0 and math.max(40, view * view / (view + range)) or 40)
    end
    scroll:HookScript("OnScrollRangeChanged", sizeThumb)
    sizeThumb()
  end)
  content = CreateFrame("Frame", nil, scroll); content:SetSize(CW, 10)
  scroll:SetScrollChild(content)

  frame.footLine = frame:CreateTexture(nil, "ARTWORK"); frame.footLine:SetHeight(1); frame.footLine:SetColorTexture(T.line[1], T.line[2], T.line[3], 1)
  footer = RG.NewText(frame, "GameFontDisableSmall"); footer:SetTextColor(unpack(T.dim))
  -- long footers wrap onto a second line instead of running off the window
  footer:SetWidth(CW); footer:SetHeight(22); footer:SetJustifyH("LEFT"); footer:SetJustifyV("MIDDLE"); footer:SetWordWrap(true)
  if footer.SetMaxLines then footer:SetMaxLines(2) end

  relayout()
  frame:SetScript("OnShow", function() if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839) end; relayout(); RG.RefreshUI() end)
  frame:SetScript("OnHide", function() saveTab(); if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840) end end)
  frame:Hide()
end

function RG.ShowTab(tab)
  if not frame then build() end
  tab = ALIAS[tab] or tab
  if GROUPS[tab] then tab = state.lastSub[tab] or GROUPS[tab][1] end
  if tab == "camp" then tab = "prof"; RG.db.profOpen = RG.db.profOpen or {}; RG.db.profOpen.Cooking = true; state.profSel = "Cooking" end
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
