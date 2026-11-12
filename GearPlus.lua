-- Waypath+ gear extras: where you stand slot by slot (also beside the Character window), the best piece from each
-- kind of source, how close an item comes to the best for your level, upgrade arrows in Baganator, and stat
-- weight profiles you can edit or import from Pawn.
-- (Ideas taken from leveling gear add-ons; the code and data are Waypath+'s own.)
local _, RG = ...
local GOLD, GREEN, GREY, WHITE = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY, "|cffffffff"

table.insert(RG.OPTIONS, { key = "gearPanel", label = "Show my gear status beside the Character window", default = true })
table.insert(RG.OPTIONS, { key = "tooltipBest", label = "Item tooltips say how close an item is to the best for my level", default = true })

-- ---------------------------------------------------------------------------
-- Slot status: what you wear, whether it's the best for your level, and the next upgrade
-- ---------------------------------------------------------------------------
local SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
local function guideSlot(slot) return RG.GuideSlotFor and RG.GuideSlotFor(slot) end
local function emptyOK(slot)
  -- an empty off hand is right for a two-hander; an empty ranged slot for classes that have none
  if slot == 17 then
    local mh = GetInventoryItemLink("player", 16)
    return mh and RG.EquipLoc(mh) == "INVTYPE_2HWEAPON"
  end
  return false
end

-- { slot, link, score, best = true when nothing usable now beats it, next = { g, d, soon } }
local statusCache, statusT
function RG.GearStatus()
  local now = GetTime and GetTime() or 0
  if statusCache and statusT and now - statusT < 2 then return statusCache end
  local lvl = UnitLevel("player") or 1
  local out, atBest, counted = {}, 0, 0
  for _, slot in ipairs(SLOTS) do
    local gs = guideSlot(slot)
    if gs then
      local link = GetInventoryItemLink("player", slot)
      local e = { slot = slot, link = link, score = link and RG.Score(link) or 0 }
      local nowBest, nextUp
      for _, list in ipairs({ RG.GUIDE or {}, RG.GUIDE_ALT or {} }) do
        for _, g in ipairs(list) do
          if g.id and g.slot == gs and (g.lvl or 0) <= lvl + 6 and not RG.OwnState(g.id) and RG.GearShown(g) then
            local d = RG.GuideDelta(g)
            if d and d > 0.5 then
              local soon = (g.lvl or 0) <= lvl
              if soon and (not nowBest or d > nowBest.d) then nowBest = { g = g, d = d, soon = true } end
              if not nextUp or (soon and (not nextUp.soon or d > nextUp.d)) or (not soon and not nextUp.soon and g.lvl < nextUp.g.lvl) then nextUp = { g = g, d = d, soon = soon } end
            end
          end
        end
      end
      e.next = nowBest or nextUp
      e.best = not nowBest and (link ~= nil or emptyOK(slot))
      out[#out + 1] = e
      counted = counted + 1
      if e.best then atBest = atBest + 1 end
    end
  end
  statusCache, statusT = { slots = out, atBest = atBest, total = counted }, now
  return statusCache
end
function RG.GearStatusInvalidate() statusCache = nil end

-- ---------------------------------------------------------------------------
-- The best piece from each kind of source for a slot, around your level
-- ---------------------------------------------------------------------------
local GROUP = { Quest = "Quest", Dungeon = "Dungeon", Chest = "Dungeon", Crafted = "Crafted", BoE = "Auction House" }
RG.SOURCE_GROUPS = { "Quest", "Dungeon", "Crafted", "Auction House", "Other" }
-- { [group] = { g, d } } for guide slot gs: pieces usable within 5 levels, best upgrade first (or the best there is)
function RG.GearBySource(gs)
  local lvl = UnitLevel("player") or 1
  local best = {}
  for _, list in ipairs({ RG.GUIDE or {}, RG.GUIDE_ALT or {} }) do
    for _, g in ipairs(list) do
      if g.id and g.slot == gs and (g.lvl or 0) <= lvl + 5 and (g.lvl or 0) >= lvl - 12 and RG.GearShown(g) then
        local grp = GROUP[g.how] or "Other"
        local d = RG.GuideDelta(g)
        if d then
          local cur = best[grp]
          local own = RG.OwnState(g.id)
          if not cur or d > cur.d then best[grp] = { g = g, d = d, own = own } end
        end
      end
    end
  end
  return best
end

-- ---------------------------------------------------------------------------
-- How close an item comes to the best for your level (tooltips)
-- ---------------------------------------------------------------------------
local bestCache, bestLvl, bestT = {}, nil, 0
local function bestFor(gs)
  local lvl = UnitLevel("player") or 1
  local now = GetTime and GetTime() or 0
  if bestLvl ~= lvl or now - bestT > 60 then bestCache, bestLvl, bestT = {}, lvl, now end
  if bestCache[gs] ~= nil then return bestCache[gs] or nil end
  local top, topG = nil, nil
  for _, list in ipairs({ RG.GUIDE or {}, RG.GUIDE_ALT or {} }) do
    for _, g in ipairs(list) do
      if g.id and g.slot == gs and (g.lvl or 0) <= lvl and RG.GearShown(g) then
        local _, link = RG.ItemInfo(g.id)
        if link then
          local sc = RG.Score(link)
          if sc and (not top or sc > top) then top, topG = sc, g end
        else RG.RequestItem(g.id) end
      end
    end
  end
  bestCache[gs] = top and { score = top, g = topG } or false
  return bestCache[gs] or nil
end
local LOC_GUIDE = {
  INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder", INVTYPE_CLOAK = "Back", INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest",
  INVTYPE_WRIST = "Wrist", INVTYPE_HAND = "Hands", INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_FINGER = "Ring",
  INVTYPE_TRINKET = "Trinket", INVTYPE_2HWEAPON = "2H", INVTYPE_WEAPON = "Main Hand", INVTYPE_WEAPONMAINHAND = "Main Hand",
  INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_SHIELD = "Off Hand", INVTYPE_HOLDABLE = "Off Hand", INVTYPE_RANGED = "Ranged",
  INVTYPE_RANGEDRIGHT = "Ranged", INVTYPE_THROWN = "Ranged",
}
-- percent of the best for your level, and that best piece (nil when the guide has nothing for the slot yet)
function RG.PercentOfBest(link)
  local loc = link and RG.EquipLoc(link)
  local gs = loc and LOC_GUIDE[loc]
  if not gs or not RG.CanUse(link) then return nil end
  local b = bestFor(gs)
  if not b or b.score <= 0 then return nil end
  return RG.Score(link) / b.score * 100, b.g
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tooltip)
    if not RG.db or (RG.CardsOnly and RG.CardsOnly()) or not RG.Opt("tooltip") or not RG.Opt("tooltipBest") or not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    if not link then return end
    local pct, g = RG.PercentOfBest(link)
    if not pct then return end
    local id = tonumber(link:match("item:(%d+)"))
    local col = pct >= 100 and GREEN or (pct >= 85 and GOLD or GREY)
    local txt = pct >= 100 and "The best for your level" .. (pct > 101 and string.format(" (%d%% of the guide's pick)", math.floor(pct + 0.5)) or "")
      or string.format("%d%% of the best for your level", math.floor(pct + 0.5))
    local bestName = g and g.id ~= id and RG.ItemInfo(g.id)
    tooltip:AddLine(col .. txt .. "|r" .. (bestName and pct < 100 and (GREY .. "  (" .. bestName .. ")|r") or ""), 1, 1, 1, true)
  end)
end

-- ---------------------------------------------------------------------------
-- Beside the Character window: your slots, which are at their best, and the next upgrades
-- ---------------------------------------------------------------------------
local panel
local ROWS = 9
-- the Character window has side tabs (character, reputation, skills...) sticking out of its right edge:
-- sit to the right of whatever sticks out, so nothing of Blizzard's is covered
function RG.PlaceGearPanel()
  if not panel or not CharacterFrame then return end
  local right, scale = CharacterFrame:GetRight(), CharacterFrame:GetEffectiveScale()
  local out = 0
  if right then
    local kids = { CharacterFrame:GetChildren() }
    for _, k in ipairs(kids) do
      if k ~= panel and k.IsShown and k:IsShown() and k.GetRight then
        local ok, r = pcall(k.GetRight, k)
        local ok2, l = pcall(k.GetLeft, k)
        if ok and ok2 and type(r) == "number" and type(l) == "number" and l < right + 10 and r > right then
          local d = (r * k:GetEffectiveScale() - right * scale) / scale
          if d > out and d < 140 then out = d end
        end
      end
    end
  end
  -- nothing found (tabs not parented to the window): leave room for WoW Forever's side tabs anyway
  if out == 0 then out = 48 end
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", out + 4, -12)
end
local function makePanel()
  panel = CreateFrame("Frame", "WaypathGearPanel", CharacterFrame, "BackdropTemplate")
  panel:SetSize(248, 360)
  RG.PlaceGearPanel()
  RG.Backdrop(panel, { 0.05, 0.045, 0.04, 0.94 }, { 0.6, 0.5, 0.3, 0.8 })
  panel.title = panel:CreateFontString(nil, "OVERLAY"); RG.Font(panel.title, "semibold", 13); panel.title:SetPoint("TOPLEFT", 12, -10)
  panel.title:SetText((RG.LOGO_INLINE or "") .. GOLD .. "Waypath+ gear|r")
  panel.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton"); panel.close:SetSize(22, 22); panel.close:SetPoint("TOPRIGHT", -2, -4)
  panel.close:SetScript("OnClick", function() RG.db.gearPanel = false; panel:Hide(); RG.Print("Gear panel off. Turn it back on in Settings, or /wp gearpanel.") end)
  panel.sub = panel:CreateFontString(nil, "OVERLAY"); RG.Font(panel.sub, "regular", 11); panel.sub:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -6)
  panel.barBg = panel:CreateTexture(nil, "ARTWORK"); panel.barBg:SetPoint("TOPLEFT", panel.sub, "BOTTOMLEFT", 0, -5); panel.barBg:SetSize(224, 8); panel.barBg:SetColorTexture(0.2, 0.18, 0.14, 1)
  panel.bar = panel:CreateTexture(nil, "OVERLAY"); panel.bar:SetPoint("LEFT", panel.barBg, "LEFT"); panel.bar:SetHeight(8); panel.bar:SetColorTexture(0.31, 0.68, 0.48, 1)
  panel.rows = {}
  for i = 1, ROWS do
    local r = CreateFrame("Button", nil, panel)
    r:SetSize(228, 30); r:SetPoint("TOPLEFT", panel.barBg, "BOTTOMLEFT", -2, -8 - (i - 1) * 32)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(26, 26); r.icon:SetPoint("LEFT", 2, 0); r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.name = r:CreateFontString(nil, "OVERLAY"); RG.Font(r.name, "medium", 11); r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -1); r.name:SetPoint("RIGHT", -44, 0); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.src = r:CreateFontString(nil, "OVERLAY"); RG.Font(r.src, "regular", 10); r.src:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, 1); r.src:SetPoint("RIGHT", -4, 0); r.src:SetJustifyH("LEFT"); r.src:SetWordWrap(false)
    r.d = r:CreateFontString(nil, "OVERLAY"); RG.Font(r.d, "semibold", 11); r.d:SetPoint("TOPRIGHT", -4, -2)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 0.85, 0.4, 0.08)
    r:SetScript("OnClick", function(self) if self.g then RG.ShowItemSource(self.g, { note = self.note }) end end)
    panel.rows[i] = r
  end
  panel.more = panel:CreateFontString(nil, "OVERLAY"); RG.Font(panel.more, "regular", 11); panel.more:SetPoint("BOTTOMLEFT", 12, 12); panel.more:SetTextColor(0.6, 0.6, 0.6)
  panel.open = CreateFrame("Button", nil, panel)
  panel.open:SetSize(110, 18); panel.open:SetPoint("BOTTOMRIGHT", -10, 9)
  panel.open.t = panel.open:CreateFontString(nil, "OVERLAY"); RG.Font(panel.open.t, "semibold", 11); panel.open.t:SetPoint("RIGHT"); panel.open.t:SetText(GOLD .. "Gear tab »|r")
  panel.open:SetScript("OnClick", function() if RG.ShowTab then RG.ShowTab("gear") end end)
end
-- the Character window's other tabs: the panel hides while one of them is open
local OTHER_TABS_LIST = { "ReputationFrame", "SkillFrame", "HonorFrame", "TokenFrame", "PetPaperDollFrame", "PVPFrame" }
function RG.OtherCharacterTab()
  for _, name in ipairs(OTHER_TABS_LIST) do
    local f = _G[name]
    if f and f.IsShown and f:IsShown() then return name end
  end
end
-- why the panel isn't showing (nil = it should show)
function RG.GearPanelBlocked()
  if not CharacterFrame then return "the game has no Character window frame" end
  if not RG.Opt("gearPanel") then return "it's turned off (Settings > Gear and combat, or /wp gearpanel)" end
  if RG.CardsOnly and RG.CardsOnly() then return "Waypath+ is in cards-only mode" end
  if RG.IsAlt and RG.IsAlt() then return "this character is marked as a bank alt" end
  if not CharacterFrame:IsShown() then return "the Character window is closed" end
  local other = RG.OtherCharacterTab()
  if other then return "another tab of the Character window is open (" .. other .. ")" end
end
function RG.UpdateGearPanel()
  if not CharacterFrame or not RG.db then return end
  local want = RG.Opt("gearPanel") and not (RG.CardsOnly and RG.CardsOnly()) and not (RG.IsAlt and RG.IsAlt()) and CharacterFrame:IsShown()
    and not RG.OtherCharacterTab()
  if not want then if panel then panel:Hide() end return end
  if not panel then makePanel() else RG.PlaceGearPanel() end
  RG.GearStatusInvalidate()
  local st = RG.GearStatus()
  panel.sub:SetText(WHITE .. st.atBest .. " of " .. st.total .. "|r" .. GREY .. " slots at their best for your level|r")
  panel.bar:SetWidth(math.max(1, 224 * st.atBest / math.max(1, st.total)))
  local list = {}
  for _, e in ipairs(st.slots) do if e.next then list[#list + 1] = e end end
  table.sort(list, function(a, b)
    if (a.next.soon and true or false) ~= (b.next.soon and true or false) then return a.next.soon and true or false end
    return a.next.d > b.next.d
  end)
  for i, r in ipairs(panel.rows) do
    local e = list[i]
    if e then
      local g = e.next.g
      local name, _, quality, _, _, _, _, _, _, tex = RG.ItemInfo(g.id)
      local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
      r.icon:SetTexture(tex or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(g.id)) or (GetItemIcon and GetItemIcon(g.id)) or 134400)
      r.name:SetText((c and c.hex or WHITE) .. (name or ("Item " .. g.id)) .. "|r")
      r.src:SetText(GREY .. (RG.SLOT_NAMES[e.slot] or "") .. " · " .. (g.src or "") .. ((g.zone and g.zone ~= "") and (", " .. g.zone) or "") .. "|r")
      r.d:SetText((e.next.soon and GREEN or GOLD) .. "+" .. string.format("%.0f", e.next.d) .. "|r" .. (e.next.soon and "" or (GREY .. " L" .. g.lvl .. "|r")))
      r.g, r.note = g, GREEN .. string.format("+%.0f", e.next.d) .. "|r" .. GREY .. " for your " .. (RG.SLOT_NAMES[e.slot] or "slot") .. "|r"
      r:Show()
    else r:Hide() end
  end
  if #list == 0 then panel.more:SetText(GREEN .. "Every slot is at its best for now.|r")
  elseif #list > ROWS then panel.more:SetText("+" .. (#list - ROWS) .. " more on the Gear tab")
  else panel.more:SetText("") end
  panel:SetHeight(64 + math.min(ROWS, math.max(1, #list)) * 32 + 30)
  panel:Show()
end

-- ---------------------------------------------------------------------------
-- Baganator: the same upgrade arrows as the game's own bags
-- ---------------------------------------------------------------------------
local function baganator()
  local B = _G.Baganator
  if not (B and B.API and B.API.RegisterUpgradePlugin) then return end
  pcall(B.API.RegisterUpgradePlugin, "Waypath+", "waypath", function(link)
    if not (RG.db and RG.UpgradeJudge) or (RG.IsAlt and RG.IsAlt()) then return false end
    local ok, up = pcall(RG.UpgradeJudge, link)
    return ok and up and true or false
  end)
end

-- ---------------------------------------------------------------------------
-- Stat weight profiles: edit your weights, save them under a name, or import a Pawn scale
-- ---------------------------------------------------------------------------
-- Pawn's stat names -> Waypath+'s (anything else in a Pawn scale is skipped and listed)
local PAWN = {
  Strength = "STR", Agility = "AGI", Stamina = "STA", Intellect = "INT", Spirit = "SPI", Armor = "ARMOR",
  Ap = "AP", Rap = "RAP", FeralAp = "AP", SpellDamage = "SP", SpellPower = "SP", Healing = "HEAL",
  FireSpellDamage = "SP_FIRE", FrostSpellDamage = "SP_FROST", ShadowSpellDamage = "SP_SHADOW", ArcaneSpellDamage = "SP_ARCANE",
  NatureSpellDamage = "SP_NATURE", HolySpellDamage = "SP_HOLY", Mp5 = "MP5", Hp5 = "HP5",
  HitRating = "HIT", Hit = "HIT", HitPercent = "HIT", CritRating = "CRIT", Crit = "CRIT", CritPercent = "CRIT",
  SpellHitRating = "HIT", SpellHit = "HIT", SpellCritRating = "CRIT", SpellCrit = "CRIT",
  DefenseRating = "DEF", Defense = "DEF", DodgeRating = "DODGE", Dodge = "DODGE", DodgePercent = "DODGE",
  ParryRating = "PARRY", Parry = "PARRY", BlockRating = "BLOCK", Block = "BLOCK", BlockValue = "BLOCKVALUE",
  Dps = "WEAPON_DPS", MeleeDps = "WEAPON_DPS", RangedDps = "RANGED_DPS",
}
-- a Pawn scale string: ( Pawn: v1: "Name": Strength=2, Agility=1.1, ... )  -> name, weights, skipped stats
function RG.ParsePawnScale(text)
  if type(text) ~= "string" then return nil end
  local name, body = text:match('%(%s*Pawn%s*:%s*v%d+%s*:%s*"([^"]*)"%s*:%s*(.-)%s*%)')
  if not body then return nil end
  local w, skipped = {}, {}
  for k, v in body:gmatch("([%a_]+)%s*=%s*(%-?[%d%.]+)") do
    local ours = PAWN[k]
    local n = tonumber(v)
    if ours and n then w[ours] = (w[ours] or 0) + n
    elseif n and k ~= "Class" and k ~= "Spec" then skipped[#skipped + 1] = k end
  end
  return name, w, skipped
end
-- our own text form: STR = 2, AGI = 1.1, ...
local function parseOwn(text)
  local w, n = {}, 0
  for k, v in (text or ""):gmatch("([%u_]+)%s*=%s*(%-?[%d%.]+)") do w[k] = tonumber(v); n = n + 1 end
  return n > 0 and w or nil
end
local function weightText(w)
  local keys = {}
  for k in pairs(w or {}) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return (w[a] or 0) > (w[b] or 0) end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = k .. " = " .. (math.floor(w[k] * 100 + 0.5) / 100) end
  return table.concat(parts, ", ")
end
RG.WeightText = weightText
local function profiles()
  RG.db.weightProfiles = RG.db.weightProfiles or {}
  local cls = RG.PLAYER_CLASS or "?"
  RG.db.weightProfiles[cls] = RG.db.weightProfiles[cls] or {}
  return RG.db.weightProfiles[cls]
end
function RG.WeightProfiles() return profiles() end
function RG.WeightProfileName() return RG.db.weightProfileByClass and RG.db.weightProfileByClass[RG.PLAYER_CLASS or "?"] end
local function applyWeights(w, name)
  for k in pairs(RG.db.weights) do RG.db.weights[k] = 0 end
  for k, v in pairs(w) do RG.db.weights[k] = v end
  RG.db.weightProfileByClass = RG.db.weightProfileByClass or {}
  RG.db.weightProfileByClass[RG.PLAYER_CLASS or "?"] = name
  if RG.GearStatusInvalidate then RG.GearStatusInvalidate() end
  bestCache = {}
  if RG.HealInvalidate then pcall(RG.HealInvalidate) end
  if RG.UpdateBagArrows then pcall(RG.UpdateBagArrows) end
  if RG.RefreshUI then RG.RefreshUI() end
end
function RG.UseWeightProfile(name)
  if not name then
    -- back to Waypath+'s own weights for your spec
    applyWeights(RG.DEFAULT_WEIGHTS or {}, nil)
    RG.Print("Stat weights: Waypath+'s own for your spec.")
    return
  end
  local w = profiles()[name]
  if not w then return end
  applyWeights(w, name)
  RG.Print("Stat weights: " .. GOLD .. name .. "|r.")
end
function RG.DeleteWeightProfile(name)
  profiles()[name] = nil
  if RG.WeightProfileName() == name then RG.UseWeightProfile(nil) end
end

-- the editor: one box with your weights as text; paste a Pawn scale there to import it
local ed
local function makeEditor()
  ed = CreateFrame("Frame", "WaypathWeightEditor", UIParent, "BackdropTemplate")
  ed:SetSize(460, 300); ed:SetPoint("CENTER"); ed:SetFrameStrata("DIALOG"); ed:EnableMouse(true); ed:SetMovable(true)
  ed:RegisterForDrag("LeftButton"); ed:SetScript("OnDragStart", ed.StartMoving); ed:SetScript("OnDragStop", ed.StopMovingOrSizing)
  RG.Backdrop(ed, { 0.05, 0.045, 0.04, 0.97 }, { 0.6, 0.5, 0.3, 0.9 })
  ed.t = ed:CreateFontString(nil, "OVERLAY"); RG.Font(ed.t, "semibold", 14); ed.t:SetPoint("TOPLEFT", 14, -12); ed.t:SetText(GOLD .. "Stat weights|r")
  ed.h = ed:CreateFontString(nil, "OVERLAY"); RG.Font(ed.h, "regular", 11); ed.h:SetPoint("TOPLEFT", ed.t, "BOTTOMLEFT", 0, -6); ed.h:SetWidth(430); ed.h:SetJustifyH("LEFT")
  ed.h:SetText(GREY .. "Points per stat (Hit and crit per 1%). Change the numbers, or paste a Pawn scale here to import it. Scores, tooltips and upgrade arrows follow your weights; the gear lists themselves come from Waypath+'s own.|r")
  local sf = CreateFrame("ScrollFrame", nil, ed, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 14, -74); sf:SetPoint("BOTTOMRIGHT", -34, 84)
  ed.box = CreateFrame("EditBox", nil, sf); ed.box:SetMultiLine(true); ed.box:SetAutoFocus(false); ed.box:SetWidth(400)
  ed.box:SetFontObject(ChatFontNormal); ed.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  sf:SetScrollChild(ed.box)
  ed.name = CreateFrame("EditBox", nil, ed, "InputBoxTemplate"); ed.name:SetSize(150, 20); ed.name:SetPoint("BOTTOMLEFT", 22, 52); ed.name:SetAutoFocus(false)
  ed.nl = ed:CreateFontString(nil, "OVERLAY"); RG.Font(ed.nl, "regular", 11); ed.nl:SetPoint("BOTTOMLEFT", ed.name, "TOPLEFT", -6, 2); ed.nl:SetText(GREY .. "Profile name|r")
  ed.msg = ed:CreateFontString(nil, "OVERLAY"); RG.Font(ed.msg, "regular", 11); ed.msg:SetPoint("BOTTOMLEFT", 16, 34); ed.msg:SetWidth(430); ed.msg:SetJustifyH("LEFT")
  local function btn(text, x, fn)
    local b = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate"); b:SetSize(104, 22); b:SetPoint("BOTTOMRIGHT", x, 10); b:SetText(text); b:SetScript("OnClick", fn); return b
  end
  btn("Close", -12, function() ed:Hide() end)
  btn("Waypath+ default", -120, function() RG.UseWeightProfile(nil); ed.box:SetText(weightText(RG.db.weights)); ed.name:SetText(""); ed.msg:SetText(GREEN .. "Back to Waypath+'s weights for your spec.|r") end)
  btn("Save and use", -228, function()
    local text = ed.box:GetText()
    local pname, w, skipped = RG.ParsePawnScale(text)
    if not w then w = parseOwn(text) end
    if not w then ed.msg:SetText("|cffff7f50Nothing to read: write STAT = number pairs, or paste a Pawn scale.|r") return end
    local name = ed.name:GetText()
    if not name or name == "" then name = pname or "My weights" end
    profiles()[name] = w
    RG.UseWeightProfile(name)
    ed.box:SetText(weightText(w)); ed.name:SetText(name)
    ed.msg:SetText(GREEN .. "Saved as " .. name .. " and in use." .. "|r" .. ((skipped and #skipped > 0) and (GREY .. "  Skipped from Pawn: " .. table.concat(skipped, ", ") .. "|r") or ""))
  end)
  ed:Hide()
end
function RG.OpenWeightEditor()
  if not ed then makeEditor() end
  ed.box:SetText(weightText(RG.db.weights)); ed.name:SetText(RG.WeightProfileName() or ""); ed.msg:SetText("")
  ed:Show()
end

-- ---------------------------------------------------------------------------
-- Weapon setup (the Gear tab's picker): two-hander, two weapons, or a one-hander and a shield
-- ---------------------------------------------------------------------------
-- the choices for your class: { { key = nil (the class's own) or "DW"/"SB", label }, ... }, or nil when there's no choice
function RG.WeaponSetupChoices()
  local opts = RG.WEAPON_SETUPS and RG.WEAPON_SETUPS[RG.PLAYER_CLASS]
  if not opts or #opts == 0 then return nil end
  -- (only for the spec the class levels with: the other specs' lists have their own weapons)
  local m = RG.MainSpec and RG.MainSpec()
  if m and not m.main then return nil end
  local own = RG.ActiveClass and RG.ActiveClass.model or "2H"
  local out = { { key = nil, label = (RG.SETUP_LABEL and RG.SETUP_LABEL[own]) or "Two-hander" } }
  for _, k in ipairs(opts) do if k ~= own then out[#out + 1] = { key = k, label = RG.SETUP_LABEL[k] or k } end end
  return out
end
-- one-handers go in either hand when you fight with two weapons
local function weaponSlots()
  if not RG.EQUIP_SLOTS then return end
  local dw = RG.WEAPON_MODEL == "DW" or RG.PLAYER_CLASS == "HUNTER"
  RG.EQUIP_SLOTS.INVTYPE_WEAPON = dw and { 16, 17 } or { 16 }
end
RG.UpdateWeaponSlots = weaponSlots
function RG.SetWeaponSetup(key)
  RG.db.weaponSetupByClass = RG.db.weaponSetupByClass or {}
  RG.db.weaponSetupByClass[RG.PLAYER_CLASS] = key or false
  if RG.BuildGuide then RG.BuildGuide(nil) end
  if RG.ApplyMainSpec then pcall(RG.ApplyMainSpec, true) end
  weaponSlots()
  RG.GearStatusInvalidate(); bestCache = {}
  if RG.UpdateBagArrows then pcall(RG.UpdateBagArrows) end
  if RG.RefreshUI then RG.RefreshUI() end
end

-- ---------------------------------------------------------------------------
-- Events and commands
-- ---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "ADDON_LOADED", "GET_ITEM_INFO_RECEIVED" }) do pcall(ev.RegisterEvent, ev, e) end
-- update the panel; an error goes to /wp errors instead of silently leaving the panel closed
local function refresh()
  local ok, err = pcall(RG.UpdateGearPanel)
  if not ok and RG.RecordError then RG.RecordError(err) end
end
local pending = false
local function soon()
  if pending or not C_Timer then return end
  pending = true
  C_Timer.After(0.3, function() pending = false; if CharacterFrame and CharacterFrame:IsShown() then refresh() end end)
end
ev:SetScript("OnEvent", function(_, event, a1)
  if event == "PLAYER_LOGIN" then
    -- show with the gear tab: when the Character window opens, and when you switch back to its gear
    -- tab from reputation or skills; once more a moment later, after the window and its side tabs settle
    local function opened()
      refresh()
      if C_Timer then C_Timer.After(0.15, refresh) end
    end
    if CharacterFrame then
      CharacterFrame:HookScript("OnShow", opened)
      CharacterFrame:HookScript("OnHide", function() if panel then panel:Hide() end end)
    end
    -- switching tabs inside the open window: hide on reputation, skills, honor or currency, show again after
    for _, name in ipairs(OTHER_TABS_LIST) do
      local f = _G[name]
      if f and f.HookScript then
        f:HookScript("OnShow", function() if panel then panel:Hide() end end)
        f:HookScript("OnHide", function() if C_Timer then C_Timer.After(0, refresh) else refresh() end end)
      end
    end
    baganator()
    if C_Timer then C_Timer.After(0, weaponSlots) end
  elseif event == "ADDON_LOADED" then
    if a1 == "Baganator" then baganator() end
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    if panel and panel:IsShown() then soon() end
  else
    RG.GearStatusInvalidate(); bestCache = {}
    soon()
  end
end)

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  cmd = cmd and cmd:lower()
  if cmd == "weights" then RG.OpenWeightEditor() return end
  if cmd == "gearpanel" then
    local arg = (msg or ""):match("^%s*%S+%s+(%S+)")
    if arg == "why" then
      local why = RG.GearPanelBlocked()
      local ok, err = pcall(RG.UpdateGearPanel)
      if not ok then RG.Print("Gear panel error: " .. tostring(err):sub(1, 200))
      elseif why then RG.Print("Gear panel isn't showing because " .. why .. ".")
      else RG.Print("Gear panel should be showing" .. ((panel and panel:IsShown()) and " (and it is)." or ", but it isn't: please send a screenshot.")) end
      return
    end
    RG.db.gearPanel = not RG.Opt("gearPanel")
    RG.Print("Gear panel beside the Character window " .. (RG.db.gearPanel and "on." or "off.") .. GREY .. " (/wp gearpanel why tells you why it isn't showing)|r")
    pcall(RG.UpdateGearPanel)
    return
  end
  return base(msg)
end
