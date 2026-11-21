local _, RG = ...
-- Waypath Cards: the Gilded print (1.53), the fifth print after Common, Rare, Holo and Full art.
--   * any card a pack can hold, but a Mythic, can come Gilded on its own roll: about 1 in 15 five-card packs
--     (Arcade.lua: RG.ARCADE_GILDED_RATE, and FINISH[5]); never crafted, never a level 60 gift, never a climb
--   * the look (tools/arcade/art_gilded.py): black lacquer for the body, each kind's frame in hammered gold (the same
--     shapes as Codex1..4, so the picture window fits exactly), a gold double edge, a black name plate with gold letters,
--     a black glass text panel below the type line, gold-leaf flecks, gold corner brackets that stand a little past the
--     card's edge, gold glints and a gold sweep, and a gold glow round it (the collection grid too)
--   * in a pack it waits face down on its gold back (Arcade.lua), and turns over with a gold burst
--   * /wp gildedcheck draws every card that can come Gilded at every size it's shown and lists anything wrong;
--     /wp gildedtour shows one of each kind, Holo beside Gilded, big and at the grid's size, and the gold back
-- Also here: a long name on a big card goes onto two lines instead of being cut short (every print).

local MEDIA = "Interface\\AddOns\\Waypath\\Media\\Arcade\\"
local CARD_V = 358 / 512
local GOLD_TEXT = { 0.96, 0.83, 0.48 }
local INK = { 0.07, 0.06, 0.1 }
local function U() return RG.ArcadeUI end

function RG.ArcadeCanGild(c)
  return c and c.tier ~= 7 and not c.mythic and not c.field and not c.bound and not c.hero and true or false
end

-- the pieces a card needs for its gold: the flecks (over the frame), and the corner brackets (above the card's stamps' frame)
local function gildOf(w)
  local g = rawget(w, "gild")
  if g then return g end
  local u = w.u or (w:GetWidth() / 256)
  g = CreateFrame("Frame", nil, w); g:SetAllPoints(w)
  if RG.ArcadeLayer then RG.ArcadeLayer(w, g, 5) end
  g.flecks = g:CreateTexture(nil, "OVERLAY"); g.flecks:SetTexture(MEDIA .. "GildedFlecks"); g.flecks:SetTexCoord(0, 1, 0, CARD_V)
  g.flecks:SetAllPoints(w); g.flecks:SetBlendMode("ADD"); g.flecks:SetAlpha(0.9)
  g.corners = CreateFrame("Frame", nil, w); g.corners:SetAllPoints(w)
  if RG.ArcadeLayer then RG.ArcadeLayer(w, g.corners, 7) end
  g.c = {}
  local cs, o = 74 * u, 7 * u
  -- (one drawing, mirrored for the other three corners)
  local spec = { { "TOPLEFT", -o, o, 0, 1, 0, 1 }, { "TOPRIGHT", o, o, 1, 0, 0, 1 }, { "BOTTOMLEFT", -o, -o, 0, 1, 1, 0 }, { "BOTTOMRIGHT", o, -o, 1, 0, 1, 0 } }
  for i, s in ipairs(spec) do
    local t = g.corners:CreateTexture(nil, "OVERLAY"); t:SetTexture(MEDIA .. "GildedCorner")
    t:SetSize(cs, cs); t:SetPoint(s[1], w, s[1], s[2], s[3]); t:SetTexCoord(s[4], s[5], s[6], s[7])
    g.c[i] = t
  end
  rawset(w, "gild", g)
  return g
end
local function setGold(w, on)
  rawset(w, "gildOn", on or nil)
end

-- after every paint: the gold, or the ordinary card back again
RG.ArcadeCardHooks = RG.ArcadeCardHooks or {}
table.insert(RG.ArcadeCardHooks, function(w, card, finish)
  local g = rawget(w, "gild")
  if not card then
    -- (the start of a paint: undo anything a Gilded print changed that the paint itself doesn't set again)
    if rawget(w, "gildOn") then
      w.body:SetTexture(MEDIA .. "Body"); w.body:SetTexCoord(0, 1, 0, CARD_V)
      w.win:SetVertexColor(1, 1, 1); w.crest:SetVertexColor(1, 1, 1); w.aura:SetVertexColor(1, 1, 1)
      w.name:SetTextColor(INK[1], INK[2], INK[3]); w.nameB:SetTextColor(INK[1], INK[2], INK[3])
      w.name:SetShadowColor(0, 0, 0, 0); w.nameB:SetShadowColor(0, 0, 0, 0)
      w.iconEdge:SetVertexColor(1, 1, 1)
      for _, sp in ipairs(w.sparks or {}) do sp:SetVertexColor(1, 1, 1) end
      setGold(w, false)
    end
    if g then g:Hide(); g.corners:Hide() end
    if rawget(w, "nameWrap") then
      w.name:SetWordWrap(false); if w.name.SetMaxLines then w.name:SetMaxLines(1) end
      rawset(w, "nameWrap", nil)
    end
    return
  end
  -- every print: a long name on a big card wraps onto two lines (it was shrunk to one line, and could be cut short)
  if (w.cw or 0) >= 190 and w.name and not card.mythic then
    local u = w.u or 1
    local wd = w.name.GetUnboundedStringWidth and w.name:GetUnboundedStringWidth() or w.name:GetStringWidth()
    if type(wd) == "number" and wd > 188 * u + 0.5 then
      local f = U()
      f.setfont(w.name, "title", math.max(7.5, 11 * u))   -- (two lines of 11 fit the plate's 28)
      w.name:SetWordWrap(true); if w.name.SetMaxLines then w.name:SetMaxLines(2) end
      w.name:SetText(card.name)
      rawset(w, "nameWrap", true)
    end
  end
  if finish ~= 5 or not RG.ArcadeCanGild(card) then
    if g then g:Hide(); g.corners:Hide() end
    return
  end
  -- the Gilded print
  local u = w.u or 1
  local kind = (card.kind and card.kind >= 1 and card.kind <= 4) and card.kind or 1
  w.body:SetTexture(MEDIA .. "GildedBody"); w.body:SetTexCoord(0, 1, 0, CARD_V)
  w.frameTex:SetTexture(MEDIA .. "GildedFrame" .. kind); w.frameTex:SetVertexColor(1, 1, 1, 1)
  w.win:SetVertexColor(0.55, 0.4, 0.22)
  w.edge:SetTexture(MEDIA .. "GildedEdge")
  w.plate:SetTexture(MEDIA .. "GildedPlate"); w.plate:SetVertexColor(1, 1, 1, 1)
  w.panel:SetTexture(MEDIA .. "GildedPanel"); w.panel:SetVertexColor(1, 1, 1, 1)
  if (w.cw or 0) >= 190 then
    -- (the panel starts below the type line, so its gold line never runs through it)
    w.panel:ClearAllPoints(); w.panel:SetPoint("TOPLEFT", w, "TOPLEFT", 12 * u, -258 * u); w.panel:SetPoint("BOTTOMRIGHT", w, "TOPLEFT", 244 * u, -324 * u)
  end
  w.gem:Hide()
  w.crest:SetVertexColor(1, 0.84, 0.46)
  w.iconEdge:SetVertexColor(1, 0.84, 0.46)
  w.name:SetTextColor(GOLD_TEXT[1], GOLD_TEXT[2], GOLD_TEXT[3]); w.name:SetShadowColor(0.23, 0.15, 0.03, 1); w.name:SetShadowOffset(0, -1)
  w.nameB:SetTextColor(GOLD_TEXT[1], GOLD_TEXT[2], GOLD_TEXT[3]); w.nameB:SetShadowColor(0.23, 0.15, 0.03, 1); w.nameB:SetShadowOffset(0, -1)
  w.type:SetTextColor(0.91, 0.74, 0.32); w.type:SetShadowColor(0, 0, 0, 0.8)
  w.text:SetTextColor(0.91, 0.86, 0.72); w.text:SetShadowColor(0, 0, 0, 0.8)
  w.num:SetTextColor(0.91, 0.74, 0.32)
  -- the light: a gold halo behind the picture, a gold glow round the card, gold glints
  w.glow:SetVertexColor(1, 0.78, 0.35, 0.6)
  if w.spot:IsShown() then w.spot:SetVertexColor(1, 0.8, 0.4, 0.6) end
  w.aura:SetVertexColor(1, 0.78, 0.3); w.aura:Show()
  -- (in the collection grid the glow is a little stronger, so a Gilded card stands out among the others; the card's
  -- shimmer reads its strength from fxset each frame)
  local fx = rawget(w, "fxset")
  if rawget(w, "collect") and fx then w.fxset = setmetatable({ aura = math.max(0.85, fx.aura or 0) }, { __index = fx }); w.aura:SetAlpha(0.85) end
  for _, sp in ipairs(w.sparks or {}) do sp:SetVertexColor(1, 0.86, 0.45, 0.8); sp:Show() end
  g = gildOf(w)
  g:Show(); g.corners:Show()
  setGold(w, true)
end)

-- turning over in a pack: a gold burst and the best sound
RG.ArcadeRevealHooks = RG.ArcadeRevealHooks or {}
table.insert(RG.ArcadeRevealHooks, function(card, g, reveal)
  if not (g and g.finish == 5) then return end
  if RG.ArcadeSound then RG.ArcadeSound("best") end
  if reveal then reveal.shakeT, reveal.shakeK = 0.5, 2 end
  if reveal and reveal.title and not reveal.record then reveal.title:SetText("A Gilded card!") end
end)

-- ---------------------------------------------------------------------------
-- /wp gildedcheck and /wp gildedtour
-- ---------------------------------------------------------------------------
local SIZES = { { "Collection grid", 104 }, { "Pack", 136 }, { "Card page", 230 } }
local checking
function RG.ArcadeGildedCheck()
  if checking then RG.Print("The Gilded check is already running.") return end
  local u = U(); if not u then return end
  checking = true
  local host = CreateFrame("Frame", nil, UIParent); host:SetSize(10, 10); host:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -3000, 3000); host:Show()
  local ws = {}
  for i, s in ipairs(SIZES) do ws[i] = u.makeCard(host, s[2]); ws[i]:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0); ws[i].noTip = true end
  local list = {}
  for _, c in ipairs(u.CARDS) do if RG.ArcadeCanGild(c) then list[#list + 1] = c end end
  local bad, n, i = {}, 0, 0
  local function problem(t) if #bad < 400 then bad[#bad + 1] = t end end
  -- (which texture a region shows: the game can answer with the file's path or with its file number, so each is
  -- compared with what the same file gives on a texture of our own)
  local probe, refs = host:CreateTexture(nil, "ARTWORK"), {}
  probe:SetSize(1, 1); probe:SetPoint("TOPLEFT"); probe:SetAlpha(0)
  local function ref(file)
    if refs[file] == nil then probe:SetTexture(MEDIA .. file); refs[file] = probe:GetTexture() or false end
    return refs[file]
  end
  local function is(t, file)
    local r, v = ref(file), t and t.GetTexture and t:GetTexture()
    if r == false or v == nil then return false end
    if type(r) == "string" and type(v) == "string" then return r:lower() == v:lower() end
    return r == v
  end
  local function checkOne(c)
    n = n + 1
    for k, w in ipairs(ws) do
      local where = c.name .. " (" .. SIZES[k][1] .. ")"
      local ok, err = pcall(u.paint, w, c, 5, 1)
      if not ok then problem(where .. ": " .. tostring(err)) else
        local kind = (c.kind and c.kind >= 1 and c.kind <= 4) and c.kind or 1
        if not is(w.body, "GildedBody") then problem(where .. ": the lacquer body didn't load") end
        if w.frameTex:IsShown() and not is(w.frameTex, "GildedFrame" .. kind) then problem(where .. ": its gold frame is the wrong one") end
        if not is(w.edge, "GildedEdge") then problem(where .. ": the gold edge didn't load") end
        if not is(w.plate, "GildedPlate") then problem(where .. ": the gold name plate didn't load") end
        if not is(w.panel, "GildedPanel") then problem(where .. ": the glass text panel didn't load") end
        local nm = w.cw >= 190 and w.name or w.nameB
        if nm.IsTruncated and nm:IsTruncated() then problem(where .. ": its name is cut short") end
        local g = rawget(w, "gild")
        if not (g and g:IsShown() and g.corners:IsShown()) then problem(where .. ": the flecks or corners are missing")
        else
          local top = w.top:GetFrameLevel()
          if g:GetFrameLevel() <= top then problem(where .. ": the flecks are under the card's frame") end
          if g.corners:GetFrameLevel() <= g:GetFrameLevel() then problem(where .. ": the corners are under the flecks") end
          local m = rawget(w, "model")
          if m and m:IsShown() and m:GetFrameLevel() >= top then problem(where .. ": the 3D model is above the frame") end
        end
        -- and painted again as a Holo, nothing of the gold is left
        pcall(u.paint, w, c, 3, 1)
        if is(w.body, "GildedBody") or is(w.plate, "GildedPlate") or (g and (g:IsShown() or g.corners:IsShown())) then problem(where .. ": the gold stays after the card is drawn as a Holo") end
        if w.cw >= 190 and w.name.IsTruncated and w.name:IsTruncated() then problem(where .. ": its name is cut short (Holo)") end
      end
    end
  end
  RG.Print("Drawing " .. #list .. " cards as Gilded at " .. #SIZES .. " sizes... about a minute.")
  local function step()
    for _ = 1, 20 do
      i = i + 1
      local c = list[i]
      if not c then
        checking = false; host:Hide()
        local out = { "Waypath+ Gilded check: " .. n .. " cards drawn Gilded at " .. #SIZES .. " sizes (" .. n * #SIZES .. " cards), " .. #bad .. " problem(s)", "" }
        for _, l in ipairs(bad) do out[#out + 1] = l end
        if #bad == 0 then out[#out + 1] = "Every card that can come Gilded draws its gold at every size, with every layer in its place." end
        if RG.ShowErrors then RG.ShowErrors(table.concat(out, "\n"), "Waypath+ Gilded check  ·  Ctrl+A, Ctrl+C to copy") else RG.Print(out[1]) end
        return
      end
      local ok, err = pcall(checkOne, c)
      if not ok then problem(c.name .. ": " .. tostring(err)) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.02, step) else step() end
  end
  step()
end

local tour
function RG.ArcadeGildedTour()
  local u = U(); if not u then return end
  if not tour then
    tour = CreateFrame("Frame", "WaypathGildedTour", UIParent, "BackdropTemplate"); tour:SetFrameStrata("FULLSCREEN_DIALOG"); tour:SetPoint("CENTER")
    u.darkPanel(tour, 900, 470); tour:EnableMouse(true); tour:SetMovable(true); tour:RegisterForDrag("LeftButton")
    tour:SetScript("OnDragStart", tour.StartMoving); tour:SetScript("OnDragStop", tour.StopMovingOrSizing)
    tinsert(UISpecialFrames, "WaypathGildedTour")
    tour.title = u.fs(tour, "title", 17); tour.title:SetPoint("TOPLEFT", 30, -24); tour.title:SetTextColor(1, 0.83, 0.42)
    tour.big1 = u.makeCard(tour, 230); tour.big1:SetPoint("TOPLEFT", 30, -60)
    tour.big2 = u.makeCard(tour, 230); tour.big2:SetPoint("TOPLEFT", 280, -60)
    tour.sm1 = u.makeCard(tour, 104); tour.sm1:SetPoint("TOPLEFT", 540, -60)
    tour.sm2 = u.makeCard(tour, 104); tour.sm2:SetPoint("TOPLEFT", 660, -60)
    for _, w in ipairs({ tour.big1, tour.big2, tour.sm1, tour.sm2 }) do w.noTip = true; w:SetFrameLevel(tour:GetFrameLevel() + 3) end
    tour.back = tour:CreateTexture(nil, "ARTWORK"); tour.back:SetTexture(MEDIA .. "GildedBack"); tour.back:SetTexCoord(0, 1, 0, CARD_V)
    tour.back:SetSize(104, 145); tour.back:SetPoint("TOPLEFT", 600, -230)
    local function cap(text, x, y) local t = u.fs(tour, "body", 12); t:SetPoint("TOPLEFT", x, y); t:SetText(text); t:SetTextColor(0.75, 0.7, 0.6) end
    cap("Holo", 30, -386); cap("Gilded", 280, -386); cap("Holo and Gilded at the grid's size", 540, -210); cap("The gold back it flips from", 560, -382)
    tour.i = 1
    tour.prev = u.gbtn(tour, "<", 36, 24, function() tour.i = math.max(1, tour.i - 1); tour:Paint() end); tour.prev:SetPoint("TOPRIGHT", -100, -22)
    tour.next = u.gbtn(tour, ">", 36, 24, function() tour.i = math.min(#tour.list, tour.i + 1); tour:Paint() end); tour.next:SetPoint("LEFT", tour.prev, "RIGHT", 6, 0)
    tour.close = u.gbtn(tour, "X", 28, 24, function() tour:Hide() end); tour.close:SetPoint("TOPRIGHT", -18, -18)
    function tour:Paint()
      local e = self.list[self.i]; if not e then return end
      self.title:SetText("Gilded tour  ·  " .. self.i .. " / " .. #self.list .. "  ·  " .. e[1] .. "  ·  " .. e[2].name)
      u.paint(self.big1, e[2], 3, 1); u.paint(self.big2, e[2], 5, 1); u.paint(self.sm1, e[2], 3, 1); u.paint(self.sm2, e[2], 5, 1)
    end
  end
  local list = {}
  local function add(label, pred) for _, c in ipairs(u.CARDS) do if RG.ArcadeCanGild(c) and pred(c) then list[#list + 1] = { label, c }; return end end end
  add("An item", function(c) return c.kind == 1 end)
  add("A creature", function(c) return c.kind == 2 and not c.dun end)
  add("A place", function(c) return c.kind == 3 end)
  add("A raider", function(c) return c.kind == 4 end)
  add("A dungeon boss", function(c) return c.dun and c.kind == 2 end)
  add("A raid card", function(c) return c.dun and RG.ArcadeIsRaid and RG.ArcadeIsRaid(c.dun) end)
  add("A Legendary", function(c) return c.tier == 5 end)
  local longest
  for _, c in ipairs(u.CARDS) do if RG.ArcadeCanGild(c) and (not longest or #c.name > #longest.name) then longest = c end end
  if longest then list[#list + 1] = { "The longest name", longest } end
  tour.list = list
  tour:Show(); tour:Paint()
end

do
  local base = SlashCmdList and SlashCmdList.WAYPATH
  if base then
    SlashCmdList.WAYPATH = function(msg)
      local cmd = (msg or ""):match("^%s*(%S+)")
      cmd = cmd and cmd:lower()
      if cmd == "gildedcheck" then RG.ArcadeGildedCheck() return end
      if cmd == "gildedtour" then RG.ArcadeGildedTour() return end
      return base(msg)
    end
  end
end
