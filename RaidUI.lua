-- Waypath+ raid gear: the "Raid & tier" page (UI.lua hands over its row helpers as RG.UIKit and calls RG.RaidRender).
-- Three views behind one switch row: Upgrades (your best raid upgrades, and every route to one slot), Tier sets (a grid of
-- every set of your class: one row per tier, one icon per slot) and Raids (the bosses of each raid, with what they drop for
-- you). The page and its tab only exist from level 58.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local WHITE, PURPLE = "|cffffffff", "|cffA58BD8"

local SHORT = { ["Molten Core"] = "Molten Core", ["Onyxia's Lair"] = "Onyxia", ["Blackwing Lair"] = "Blackwing Lair", ["Zul'Gurub"] = "Zul'Gurub",
  ["Ruins of Ahn'Qiraj"] = "Ahn'Qiraj 20", ["Temple of Ahn'Qiraj"] = "Ahn'Qiraj 40", ["Naxxramas"] = "Naxxramas" }

local function pctText(u)
  if u.pct and u.pct >= 1 then return string.format("+%d%%", math.floor(u.pct + 0.5)) end
  return string.format("+%.0f", u.d)
end
-- "Garr, Molten Core" / "Thaddius (Desecrated Headpiece), Naxxramas"
local function whereText(g)
  local boss, tok = RG.RaidBossOf(g.src)
  return boss .. (tok and (" (" .. tok .. " token)") or "") .. ", " .. (g.zone or "")
end
local function steps(g) return table.concat(RG.RouteSteps(g), GREY .. "  ›  |r" .. WHITE) end
local function wornName(slot)
  local link = slot and ((RG.WornLink and RG.WornLink(slot)) or GetInventoryItemLink("player", slot))
  if link then return (RG.ItemInfo(link)) or "your item" end
  return "an empty slot"
end

-- a click-to-cycle row, like Weapon setup (left-click next, right-click previous)
local function cycleRow(K, n, title, labels, idx, icon, tip, onSet)
  local parts = {}
  for i, l in ipairs(labels) do parts[#parts + 1] = (i == idx and GOLD or GREY) .. l .. "|r" end
  K.setItem(K.getRow(n), nil, nil, WHITE .. title .. "|r", table.concat(parts, GREY .. "  ·  |r"), GOLD .. labels[idx] .. "|r", "", nil, nil, true)
  local r = K.rows[n]
  r.icon:SetTexture(icon)
  r.onClick = function() onSet(idx % #labels + 1) end
  r.onRightClick = function() onSet((idx - 2) % #labels + 1) end
  r.tip = tip
end

-- a small grey text row (no icon, no click)
local function note(K, n, text)
  K.setStep(K.getRow(n), "", text, false, nil)
  local r = K.rows[n]
  r.iconBorder:Hide(); r.icon:Hide(); r.tip = nil
end
local function stepRow(K, n, text, fn)
  K.setStep(K.getRow(n), "", text, false, fn)
  local r = K.rows[n]
  r.iconBorder:Hide(); r.icon:Hide(); r.tip = nil
end

-- ---------------------------------------------------------------------------
-- View 1: upgrades
-- ---------------------------------------------------------------------------
local function upRow(K, n, u, big)
  local g = u.g
  local name, link, quality = K.itemName(g.id)
  local sub = GREY .. "Replaces " .. wornName(u.slot) .. "  ·  " .. whereText(g) .. (g.tier and ("  ·  " .. g.tier .. " set") or "") .. "|r"
  K.setItem(K.getRow(n), g.id, link, name .. GREY .. "   " .. (K.slotLabel[g.slot] or g.slot) .. "|r", sub,
    GREEN .. pctText(u) .. "|r", u.token and (GOLD .. "Token in bags|r") or (GOLD .. "Raid|r"), big and "gold" or nil, quality, not big)
  K.rows[n].onClick = function() K.state.raidSlot = g.slot; RG.RefreshUI() end
  K.rows[n].onRightClick = function() RG.ShowItemSource(g, { note = GREEN .. pctText(u) .. "|r" .. GREY .. " over " .. wornName(u.slot) .. "|r" }) end
  K.rows[n].tip = "Click for every route to this slot. Right-click for where this piece drops and a map pin."
end

local function viewUpgrades(K, n, sc)
  local state = K.state
  if #sc.top == 0 then
    n = n + 1; K.setItem(K.getRow(n), nil, nil, GREEN .. "No raid piece beats your gear yet.|r", GREY .. "Every raid piece your class can use was weighed against what you wear.|r", "", "", "green", nil, true)
    return n
  end
  local best = sc.top[1]
  n = n + 1; K.setHeader(K.getRow(n), "Best next upgrade  ·  " .. (K.slotLabel[best.g.slot] or best.g.slot))
  n = n + 1; upRow(K, n, best, true)
  n = n + 1
  K.setItem(K.getRow(n), nil, nil, WHITE .. "Route|r", WHITE .. steps(best.g) .. "|r", GREY .. RG.RouteEffort(best.g) .. "|r", "", nil, nil, true)
  K.rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  K.rows[n].tip = nil
  n = n + 1; K.setHeader(K.getRow(n), "All slots, biggest gain first  ·  " .. #sc.top .. " have an upgrade")
  local SHOWN = state.raidAll and #sc.top or 6
  for i = 1, math.min(SHOWN, #sc.top) do n = n + 1; upRow(K, n, sc.top[i], false) end
  if #sc.top > 6 then
    n = n + 1
    stepRow(K, n, GREY .. (state.raidAll and "Show fewer" or ("Show " .. (#sc.top - 6) .. " more slots")) .. "|r", function() state.raidAll = not state.raidAll; RG.RefreshUI() end)
  end
  return n
end

-- every route to one slot: raid and every other source, biggest gain first
local function viewRoutes(K, n, slotName)
  local state = K.state
  n = n + 1; K.setHeader(K.getRow(n), (K.slotLabel[slotName] or slotName) .. "  ·  every route")
  n = n + 1; stepRow(K, n, GREY .. "Back to your best upgrades|r", function() state.raidSlot = nil; RG.RefreshUI() end)
  local lvl = UnitLevel("player") or 1
  local routes, seen, loading = {}, {}, 0
  local function consider(g)
    if not g.id or g.slot ~= slotName or seen[g.id] or RG.OwnState(g.id) then return end
    if RG.GearShown and not RG.GearShown(g) then return end
    seen[g.id] = true
    local d, slot, _, old = RG.GuideDelta(g)
    if d == nil then local _, wait = RG.RaidDelta(g); if wait then loading = loading + 1 end elseif d > 0.5 then routes[#routes + 1] = { g = g, d = d, slot = slot, pct = (old and old > 0) and (d / old * 100) or nil } end
  end
  for _, g in ipairs(RG.RaidList()) do consider(g) end
  for _, g in ipairs((RG.GearCandidates and (RG.GearCandidates())) or {}) do if (g.lvl or 0) <= lvl + 3 then consider(g) end end
  table.sort(routes, function(a, b) if a.d ~= b.d then return a.d > b.d end return (a.g.lvl or 0) < (b.g.lvl or 0) end)
  if routes[1] then
    n = n + 1
    K.setItem(K.getRow(n), nil, nil, WHITE .. "You wear|r  " .. wornName(routes[1].slot), "", "", "", nil, nil, true)
    K.rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08"); K.rows[n].tip = nil
  end
  if #routes == 0 then
    n = n + 1; note(K, n, GREEN .. "Nothing for this slot beats what you wear." .. (loading > 0 and (GREY .. "  (" .. loading .. " still loading)") or "") .. "|r")
    return n
  end
  local SHOWN = state.routeAll and #routes or 6
  for i = 1, math.min(SHOWN, #routes) do
    local u = routes[i]
    local g = u.g
    local name, link, quality = K.itemName(g.id)
    local price = RG.GearPriceText and RG.GearPriceText(g)
    n = n + 1
    K.setItem(K.getRow(n), g.id, link, GOLD .. i .. ".|r  " .. name,
      WHITE .. steps(g) .. "|r" .. GREY .. "  ·  " .. RG.RouteEffort(g) .. "  ·  Cost: " .. (price and price:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or "Free") .. "|r",
      GREEN .. pctText(u) .. "|r", RG.GearHowPill and g.how ~= "Raid" and RG.GearHowPill(g, true) or "", i == 1 and "gold" or nil, quality, true)
    K.rows[n].onClick = function() RG.ShowItemSource(g, { note = GREEN .. pctText(u) .. "|r" .. GREY .. " over " .. wornName(u.slot) .. "|r" }) end
    K.rows[n].tip = "Click for the details and a map pin."
  end
  if #routes > 6 then
    n = n + 1
    stepRow(K, n, GREY .. (state.routeAll and "Show fewer" or ("Show " .. (#routes - 6) .. " more routes")) .. "|r", function() state.routeAll = not state.routeAll; RG.RefreshUI() end)
  end
  n = n + 1; note(K, n, GREY .. "Each route is a drop, vendor or quest from the game's own data. Ranked by gain first, then the lower level.|r")
  return n
end

-- ---------------------------------------------------------------------------
-- Small widgets that live inside one list row (the row is the card; these are its children)
-- ---------------------------------------------------------------------------
local function kids(r)
  if not rawget(r, "rgKids") then
    local kd = { segs = {}, cells = {}, named = {} }
    r.rgKids = kd
    r:HookScript("OnHide", function(self)
      local k = rawget(self, "rgKids")
      for _, list in pairs({ k.segs, k.cells, k.named }) do for _, w in pairs(list) do w:Hide() end end
    end)
  end
  return rawget(r, "rgKids")
end
local function namedFS(K, r, key, fontPath, size)
  local kd = kids(r)
  local fs = kd.named[key]
  if not fs then fs = r:CreateFontString(nil, "OVERLAY"); kd.named[key] = fs end
  K.font(fs, fontPath, K.sz(size))
  return fs
end
local function namedTex(r, key, layer)
  local kd = kids(r)
  local t = kd.named[key]
  if not t then t = r:CreateTexture(nil, layer or "ARTWORK"); kd.named[key] = t end
  return t
end
-- a row that holds widgets: reset it like a header, then size it ourselves
local function widgetRow(K, n, h)
  local r = K.getRow(n)
  K.setHeader(r, "")
  r.head:Hide(); r.headLine:Hide()
  r.kind, r.h = "widgets", K.sz(h)
  r:Show()
  return r
end

-- the Upgrades / Tier sets / Raids switch
local function segRow(K, n, labels, idx, onSet)
  local r = widgetRow(K, n, 36)
  local kd = kids(r)
  local x = 2
  for i, l in ipairs(labels) do
    local b = kd.segs[i]
    if not b then
      b = CreateFrame("Button", nil, r)
      b.t = b:CreateFontString(nil, "OVERLAY"); b.t:SetPoint("CENTER", 0, 1)
      b.line = b:CreateTexture(nil, "OVERLAY"); b.line:SetHeight(2)
      b.line:SetPoint("BOTTOMLEFT", 0, 0); b.line:SetPoint("BOTTOMRIGHT", 0, 0)
      b.line:SetColorTexture(K.T.gold[1], K.T.gold[2], K.T.gold[3], 1)
      kd.segs[i] = b
    end
    local on = i == idx
    K.font(b.t, on and K.FONT_SEMI or K.FONT_BODY, K.sz(13))
    b.t:SetText(l); b.t:SetTextColor(unpack(on and K.T.gold or K.T.dim))
    b.line:SetShown(on)
    local w = (b.t:GetStringWidth() or 40) + K.sz(26)
    b:SetSize(w, K.sz(30)); b:ClearAllPoints(); b:SetPoint("LEFT", r, "LEFT", x, 0)
    b:SetScript("OnClick", function() onSet(i) end)
    b:Show()
    x = x + w + K.sz(6)
  end
  for i = #labels + 1, #kd.segs do kd.segs[i]:Hide() end
end

-- ---------------------------------------------------------------------------
-- View 2: tier sets, one row per tier, one icon per slot
-- ---------------------------------------------------------------------------
local COLS = { "Head", "Shoulder", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Ring" }
local COL_NAME = { Head = "Head", Shoulder = "Shoulders", Chest = "Chest", Wrist = "Wrists", Hands = "Hands", Waist = "Waist", Legs = "Legs", Feet = "Feet", Ring = "Ring" }
local COL_OF = {}
for i, c in ipairs(COLS) do COL_OF[c] = i end
local EQUIP = { INVTYPE_HEAD = "Head", INVTYPE_SHOULDER = "Shoulder", INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest", INVTYPE_WRIST = "Wrist",
  INVTYPE_HAND = "Hands", INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_FINGER = "Ring" }
local STATE_TXT = { equipped = GREEN .. "Equipped|r", owned = "|cff4aa3ffIn your bags or bank|r", token = GOLD .. "The token for it is in your bags|r", missing = GREY .. "Not yet|r" }
local BORDER = { equipped = { 0.37, 0.82, 0.54 }, owned = { 0.29, 0.64, 1.0 }, token = { 0.85, 0.71, 0.35 }, missing = { 0.26, 0.28, 0.30 } }

local function slotOf(pc)
  if pc.g and COL_OF[pc.g.slot] then return pc.g.slot end
  if GetItemInfoInstant then
    local _, _, _, loc = GetItemInfoInstant(pc.id)
    if loc and EQUIP[loc] then return EQUIP[loc] end
  end
  return nil
end
local function iconOf(id)
  local ic = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))
  if not ic and GetItemInfoInstant then ic = select(5, GetItemInfoInstant(id)) end
  return ic or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function plain(t) return ((t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- the short source under an icon: the boss, or the quest / vendor / dungeon boss
local function shortSrc(g)
  if not g then return "no source" end
  if g.how == "Raid" then return (RG.RaidBossOf(g.src)) end
  return plain(g.src)
end

-- the grid: pieces of one set laid into slot columns; a slot with two pieces (the class quest set offers a choice) starts another row
local function layoutSet(pieces)
  local variants = {}
  local function put(col, pc)
    for _, v in ipairs(variants) do if not v[col] then v[col] = pc; return end end
    variants[#variants + 1] = { [col] = pc }
  end
  local unknown = {}
  for _, pc in ipairs(pieces) do
    local sl = slotOf(pc)
    if sl then put(COL_OF[sl], pc) else unknown[#unknown + 1] = pc end
  end
  for _, pc in ipairs(unknown) do
    local col
    for c = 1, #COLS do if not (variants[1] and variants[1][c]) then col = c; break end end
    put(col or 1, pc)
  end
  if #variants == 0 then variants[1] = {} end
  return variants
end

local function cellEnter(self)
  local d = self.data
  if not d then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local ok = pcall(function()
    if d.link then GameTooltip:SetHyperlink(d.link) else GameTooltip:SetItemByID(d.id) end
  end)
  if not ok then GameTooltip:SetText(d.name or "Item", 1, 1, 1) end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(STATE_TXT[d.state] or "", 1, 1, 1)
  if d.where then GameTooltip:AddLine(d.where, 0.8, 0.8, 0.8, true) end
  if d.upText then GameTooltip:AddLine(d.upText, 1, 1, 1, true) end
  GameTooltip:AddLine("Click for where it drops  ·  Shift-click to link  ·  Ctrl-click to preview", 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end
local function cellClick(self, btn)
  local d = self.data
  if not d then return end
  local link = d.link or select(2, RG.ItemInfo(d.id))
  local insert = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
  if link and IsModifiedClick and IsModifiedClick("CHATLINK") and insert then insert(link); return end
  if link and IsModifiedClick and IsModifiedClick("DRESSUP") and DressUpItemLink then DressUpItemLink(link); return end
  if d.g and RG.ShowItemSource then RG.ShowItemSource(d.g, d.upNote and { note = d.upNote } or nil) end
end

local LABEL_W = 112
local function metrics(K, r)
  local w = r:GetWidth()
  if not w or w < 200 then w = 560 end
  local lw = math.min(K.sz(LABEL_W), math.floor(w * 0.22))
  local cw = (w - lw - K.sz(10)) / #COLS
  local isz = math.max(K.sz(16), math.min(K.sz(36), math.floor(cw) - 8))
  return w, lw, cw, isz
end

local function cell(K, r, i)
  local kd = kids(r)
  local c = kd.cells[i]
  if c then return c end
  c = CreateFrame("Button", nil, r)
  c.bd = c:CreateTexture(nil, "ARTWORK")
  c.ic = c:CreateTexture(nil, "OVERLAY"); c.ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  c.up = c:CreateFontString(nil, "OVERLAY")
  c.lb = c:CreateFontString(nil, "OVERLAY"); c.lb:SetJustifyH("CENTER"); c.lb:SetJustifyV("TOP"); c.lb:SetWordWrap(true)
  c:RegisterForClicks("AnyUp")
  c:SetScript("OnEnter", cellEnter)
  c:SetScript("OnLeave", function() GameTooltip:Hide() end)
  c:SetScript("OnClick", cellClick)
  kd.cells[i] = c
  return c
end

-- the column names above the grid
local function columnHeads(K, n)
  local r = widgetRow(K, n, 18)
  local _, lw, cw = metrics(K, r)
  for i, name in ipairs(COLS) do
    local fs = namedFS(K, r, "col" .. i, K.FONT_BODY, 10)
    fs:ClearAllPoints(); fs:SetPoint("CENTER", r, "LEFT", lw + (i - 0.5) * cw, 0)
    fs:SetText(COL_NAME[name]:upper()); fs:SetTextColor(unpack(K.T.dim)); fs:Show()
  end
end

-- one row of the grid: the set's label, then its pieces in their slot columns
local function gridRow(K, n, set, label, variant, info, selected, onSelect)
  local r = widgetRow(K, n, 8 + 36 + 3 + 24 + 6)
  local _, lw, cw, isz = metrics(K, r)
  K.backdrop(r, selected and K.T.raised or K.T.small, nil, 10)
  r.hl:Show()
  r.onClick = onSelect
  r.tip = "Click to see this set's bonuses and what to get next."
  -- the label column: tier, set name, slots filled, bar
  local t1 = namedFS(K, r, "tier", K.FONT_SEMI, 12)
  t1:ClearAllPoints(); t1:SetPoint("TOPLEFT", r, "TOPLEFT", K.sz(12), -K.sz(10)); t1:SetJustifyH("LEFT")
  t1:SetText(label.tier); t1:SetTextColor(unpack(selected and K.T.gold or K.T.text)); t1:Show()
  local t2 = namedFS(K, r, "name", K.FONT_BODY, 10.5)
  t2:ClearAllPoints(); t2:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, -K.sz(2)); t2:SetJustifyH("LEFT")
  t2:SetWidth(lw - K.sz(14)); t2:SetWordWrap(false)
  t2:SetText(label.name); t2:SetTextColor(unpack(K.T.dim)); t2:Show()
  local t3 = namedFS(K, r, "count", K.FONT_NUM, 12)
  local bg, fill = namedTex(r, "barBg", "ARTWORK"), namedTex(r, "barFill", "OVERLAY")
  if info then
    t3:ClearAllPoints(); t3:SetPoint("TOPLEFT", t2, "BOTTOMLEFT", 0, -K.sz(5)); t3:SetJustifyH("LEFT")
    local done = info.have >= info.total
    t3:SetText(string.format("%d / %d", info.have, info.total)); t3:SetTextColor(unpack(done and K.T.green or K.T.text)); t3:Show()
    local bw = lw - K.sz(18)
    bg:ClearAllPoints(); bg:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", K.sz(12), K.sz(8)); bg:SetSize(bw, K.sz(4)); bg:SetColorTexture(0.12, 0.17, 0.22, 0.9); bg:Show()
    fill:ClearAllPoints(); fill:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 0, 0); fill:SetSize(math.max(1, bw * (info.total > 0 and info.have / info.total or 0)), K.sz(4))
    local fc = done and K.T.green or K.T.gold
    fill:SetColorTexture(fc[1], fc[2], fc[3], 1); fill:SetShown(info.have > 0)
  else t3:Hide(); bg:Hide(); fill:Hide() end
  -- the icons
  local kd = kids(r)
  for ci = 1, #COLS do
    local c = cell(K, r, ci)
    local pc = variant[ci]
    if not pc then
      c:Hide()
    else
      local g = pc.g
      local name, link = K.itemName(pc.id)
      local col = BORDER[pc.state] or BORDER.missing
      c:SetSize(cw, r.h); c:ClearAllPoints(); c:SetPoint("TOPLEFT", r, "TOPLEFT", lw + (ci - 1) * cw, 0)
      c.bd:ClearAllPoints(); c.bd:SetPoint("TOP", c, "TOP", 0, -K.sz(8)); c.bd:SetSize(isz + 4, isz + 4)
      c.bd:SetColorTexture(col[1], col[2], col[3], 1)
      c.ic:ClearAllPoints(); c.ic:SetPoint("CENTER", c.bd, "CENTER", 0, 0); c.ic:SetSize(isz, isz)
      c.ic:SetTexture(iconOf(pc.id))
      local have = pc.state ~= "missing"
      c.ic:SetDesaturated(not have); c.ic:SetAlpha(have and 1 or 0.6)
      c.up:ClearAllPoints(); c.up:SetPoint("BOTTOMRIGHT", c.ic, "BOTTOMRIGHT", -1, 2)
      K.font(c.up, K.FONT_SEMI, K.sz(10), "OUTLINE")
      if pc.up and not have then c.up:SetText(pctText(pc.up)); c.up:SetTextColor(0.37, 0.82, 0.54); c.up:Show() else c.up:Hide() end
      K.font(c.lb, K.FONT_BODY, K.sz(9.5))
      c.lb:ClearAllPoints(); c.lb:SetPoint("TOP", c.bd, "BOTTOM", 0, -K.sz(3)); c.lb:SetWidth(cw - 2); c.lb:SetHeight(K.sz(24))
      c.lb:SetText(shortSrc(g)); c.lb:SetTextColor(unpack(have and K.T.text or K.T.dim)); c.lb:Show()
      c.data = {
        id = pc.id, link = link, name = name, state = pc.state, g = g, up = pc.up,
        where = g and ((g.how == "Raid") and whereText(g) or (RG.GearSourceText and plain(RG.GearSourceText(g)) or plain(g.src))) or "Source not listed",
        upText = pc.up and (pctText(pc.up) .. " over " .. wornName(pc.up.slot)) or nil,
        upNote = pc.up and (GREEN .. pctText(pc.up) .. "|r" .. GREY .. " over " .. wornName(pc.up.slot) .. "|r") or nil,
      }
      c:Show()
    end
  end
end

local function viewTiers(K, n, sc)
  local state = K.state
  local sets = RG.TierList()
  if #sets == 0 then n = n + 1; note(K, n, GREY .. "No tier sets for your class.|r"); return n end
  local idx = state.raidTier
  if not idx or idx > #sets then
    -- the first view: the newest set you already wear a piece of, else the first raid set
    idx = 1
    for i, s in ipairs(sets) do
      if s.raid then
        local pp = RG.TierProgress(s)
        if pp.have > 0 then idx = i end
      end
    end
    if idx == 1 then for i, s in ipairs(sets) do if s.tier == "Tier 1" then idx = i end end end
    state.raidTier = idx
  end
  n = n + 1; columnHeads(K, n)
  local progress = {}
  for i, set in ipairs(sets) do
    local p = RG.TierProgress(set)
    progress[i] = p
    local variants = layoutSet(p.pieces)
    -- slots filled (a set that offers a choice per slot counts the slot once)
    local filled, slots = {}, {}
    for _, v in ipairs(variants) do
      for ci, pc in pairs(v) do
        slots[ci] = true
        if pc.state == "equipped" or pc.state == "owned" then filled[ci] = true end
      end
    end
    local nf, ns = 0, 0
    for _ in pairs(filled) do nf = nf + 1 end
    for _ in pairs(slots) do ns = ns + 1 end
    for vi, v in ipairs(variants) do
      n = n + 1
      local label = { tier = vi == 1 and set.tier or (set.tier .. " (alt)"), name = vi == 1 and (set.half and "Class quest set" or set.name) or "other choice" }
      gridRow(K, n, set, label, v, vi == 1 and { have = nf, total = ns } or nil, i == idx, function() state.raidTier = i; RG.RefreshUINow() end)
    end
  end
  -- the selected set: its bonuses, then the piece to chase
  local set, p = sets[idx], progress[idx]
  local total = #set.ids
  n = n + 1; K.setHeader(K.getRow(n), set.name)
  local bonuses = RG.SetBonuses(set)
  if bonuses then
    for _, b in ipairs(bonuses) do
      n = n + 1
      K.setStep(K.getRow(n), "", GOLD .. b.n .. " pieces|r  " .. b.text, p.have >= b.n, nil)
      K.rows[n].tip = (p.have >= b.n) and "Active." or ((b.n - p.have) .. " more piece" .. ((b.n - p.have) > 1 and "s" or "") .. " to go.")
    end
  elseif set.half then
    n = n + 1; note(K, n, GREY .. "The class quest set and Pix Xizzix's pieces have no set bonus. Pick the pieces that suit your spec.|r")
  end
  -- the missing piece that is the biggest upgrade for you (or, with none, the first one missing)
  local nextP
  for _, pc in ipairs(p.pieces) do
    if pc.state == "missing" or pc.state == "token" then
      if not nextP or (pc.up and (not nextP.up or pc.up.d > nextP.up.d)) then nextP = pc end
    end
  end
  if nextP then
    local nm = (RG.ItemInfo(nextP.id)) or (nextP.g and nextP.g.name) or "a piece"
    local where = nextP.g and (nextP.g.how == "Raid" and (RG.RaidBossOf(nextP.g.src) .. " drops it" .. (select(2, RG.RaidBossOf(nextP.g.src)) and " (as a token)" or "")) or (nextP.g.src or "")) or ""
    n = n + 1; note(K, n, WHITE .. "Next piece worth getting:|r " .. nm .. GREY .. (where ~= "" and ("  ·  " .. plain(where)) or "") .. "|r")
  elseif p.have >= total then n = n + 1; note(K, n, GREEN .. "You have the whole set.|r") end
  n = n + 1; note(K, n, GREY .. "Border: green worn, blue in bags or bank, gold token in bags, grey not yet. A green +% on a grey icon is how much it would upgrade you. Hover for the item and where it comes from.|r")
  return n
end

-- ---------------------------------------------------------------------------
-- View 3: raids
-- ---------------------------------------------------------------------------
local function viewRaids(K, n, sc)
  local state = K.state
  local raids = RG.RAID_ORDER or {}
  if #raids == 0 then return n end
  local idx = state.raidIdx
  if not idx then
    -- the first view: the raid with the most upgrades for you
    local bestN = -1
    idx = 1
    for i, r in ipairs(raids) do
      local c = 0
      for _, l in pairs(sc.byBoss[r.raid] or {}) do c = c + #l end
      if c > bestN then bestN, idx = c, i end
    end
    state.raidIdx = idx
  end
  local labels = {}
  for i, r in ipairs(raids) do labels[i] = SHORT[r.raid] or r.raid end
  n = n + 1
  cycleRow(K, n, "Raid", labels, idx, "Interface\\Icons\\INV_Misc_Map_01", "Click for the next raid, right-click for the previous.", function(i) state.raidIdx = i; RG.RefreshUI() end)
  local raid = raids[idx]
  local per = sc.byBoss[raid.raid] or {}
  local total = 0
  local ranked = {}
  for _, b in ipairs(raid.bosses) do
    local l = per[b] or {}
    total = total + #l
    local sum = 0
    for _, u in ipairs(l) do sum = sum + u.d end
    ranked[#ranked + 1] = { b = b, c = #l, sum = sum, cleared = RG.RaidCleared(raid.raid, b) }
  end
  table.sort(ranked, function(a, b) if a.c ~= b.c then return a.c > b.c end return a.sum > b.sum end)
  local order = {}
  for _, r in ipairs(ranked) do if r.c > 0 and #order < 3 then order[#order + 1] = r.b end end
  n = n + 1
  K.setItem(K.getRow(n), nil, nil, (total > 0 and GREEN or GREY) .. total .. " upgrade" .. (total == 1 and "" or "s") .. " for you in " .. raid.raid .. "|r",
    GREY .. (#order > 0 and ("Most upgrades: " .. table.concat(order, ", ")) or "Nothing here beats your gear yet") .. "  ·  " .. raid.size .. " players|r", "", "", total > 0 and "green" or nil, nil, true)
  K.rows[n].icon:SetTexture("Interface\\Icons\\INV_Misc_Head_Dragon_01"); K.rows[n].tip = nil
  for _, b in ipairs(raid.bosses) do
    local l = per[b] or {}
    local names = {}
    for i = 1, math.min(3, #l) do
      local nm = RG.ItemInfo(l[i].g.id) or l[i].g.name or "item"
      local tok = select(2, RG.RaidBossOf(l[i].g.src))
      names[#names + 1] = (tok and (tok .. " token") or nm) .. GREEN .. " " .. pctText(l[i]) .. "|r"
    end
    local cleared = RG.RaidCleared(raid.raid, b)
    n = n + 1
    K.setItem(K.getRow(n), nil, nil, (cleared and (GOLD .. "✓ |r") or "") .. ((#l > 0) and (WHITE .. b .. "|r") or (GREY .. b .. "|r")),
      (#l > 0) and (GREY .. table.concat(names, GREY .. "  ·  |r") .. (#l > 3 and (GREY .. "  +" .. (#l - 3) .. " more") or "") .. "|r") or (GREY .. "Nothing for you|r"),
      (#l > 0) and (GREEN .. #l .. (#l == 1 and " upgrade|r" or " upgrades|r")) or "", cleared and (GOLD .. "Cleared this week|r") or "", nil, nil, true)
    K.rows[n].icon:SetTexture(#l > 0 and "Interface\\Icons\\INV_Misc_Head_Dragon_01" or "Interface\\Icons\\INV_Misc_QuestionMark")
    local first = l[1]
    if first then K.rows[n].onClick = function() RG.ShowItemSource(first.g, { note = GREEN .. pctText(first) .. "|r" .. GREY .. " over " .. wornName(first.slot) .. "|r" }) end end
    K.rows[n].tip = first and "Click for the best piece it drops for you." or nil
  end
  n = n + 1; note(K, n, GREY .. "Drops come from the game's loot tables. A ✓ means you killed it this week (your saved raid lockouts).|r")
  return n
end

-- ---------------------------------------------------------------------------
-- The section
-- ---------------------------------------------------------------------------
function RG.RaidRender(n, K)
  if not RG.RaidShown() then return n end
  local state = K.state
  local KEYS = { "up", "tier", "raid" }
  local view = state.raidView
  local vi = 1
  for i, k in ipairs(KEYS) do if k == view then vi = i end end
  view = KEYS[vi]
  local sc = RG.RaidScan()
  n = n + 1
  segRow(K, n, { "Upgrades", "Tier sets", "Raids" }, vi, function(i) state.raidView = KEYS[i]; state.raidSlot = nil; RG.RefreshUINow() end)
  if sc.loading > 0 then n = n + 1; note(K, n, GREY .. sc.loading .. " items are still loading from the game. This updates itself.|r") end
  local ok, res = pcall(function()
    local m = n
    if view == "up" then
      if state.raidSlot then m = viewRoutes(K, m, state.raidSlot) else m = viewUpgrades(K, m, sc) end
    elseif view == "tier" then m = viewTiers(K, m, sc)
    elseif view == "raid" then m = viewRaids(K, m, sc) end
    return m
  end)
  if ok then return res end
  if RG.RecordError then RG.RecordError("RaidRender: " .. tostring(res)) end
  return n
end
