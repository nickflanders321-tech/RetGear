-- Waypath+ arcade (hidden): the XP you earn while levelling pays out coins, and coins buy
-- packs of "Waymon" cards, a collectible set of original creatures. Nothing here is announced;
-- /wp arcade opens it. Coins, packs and cards are saved for the whole account (WaypathDB.arcade).
local _, RG = ...

local TYPES = {
  ember = { "Ember", "Interface\\Icons\\Spell_Fire_Fire", { 1, 0.45, 0.2 } },
  tide  = { "Tide",  "Interface\\Icons\\Spell_Frost_ChillingBlast", { 0.35, 0.65, 1 } },
  leaf  = { "Leaf",  "Interface\\Icons\\Spell_Nature_Regeneration", { 0.4, 0.85, 0.4 } },
  spark = { "Spark", "Interface\\Icons\\Spell_Nature_Lightning", { 1, 0.9, 0.3 } },
  stone = { "Stone", "Interface\\Icons\\INV_Stone_15", { 0.7, 0.62, 0.5 } },
  shade = { "Shade", "Interface\\Icons\\Spell_Shadow_ShadowBolt", { 0.65, 0.4, 0.9 } },
}
local ORDER = { "ember", "tide", "leaf", "spark", "stone", "shade" }
-- what each type beats (Shade has no edge, but hits a little harder)
local BEATS = { ember = "leaf", leaf = "stone", stone = "spark", spark = "tide", tide = "ember" }
local NAMES = {
  ember = { "Emberwisp", "Cindermoth", "Ashfang", "Pyrelark", "Magmole", "Solarch" },
  tide  = { "Brinelet", "Ripplefin", "Kelpwyrm", "Tidecrab", "Gloamray", "Leviathelm" },
  leaf  = { "Mossling", "Thornpup", "Fernwing", "Barkbeetle", "Bloomtoad", "Elderoak" },
  spark = { "Zipkit", "Static Hare", "Arcowl", "Crackleback", "Thunderling", "Tempestra" },
  stone = { "Pebblin", "Cragmole", "Geodrake", "Boulderback", "Quartzel", "Mountainheart" },
  shade = { "Dimmoth", "Gloomcat", "Dusksnail", "Wraithkit", "Nightjar", "Umbraxis" },
}
local RARITY = {
  { "Common", { 0.75, 0.75, 0.75 }, 55 }, { "Common", { 0.75, 0.75, 0.75 }, 0 },
  { "Uncommon", { 0.3, 0.85, 0.3 }, 25 }, { "Rare", { 0.3, 0.55, 1 }, 12 },
  { "Epic", { 0.7, 0.35, 0.95 }, 6 }, { "Legendary", { 1, 0.6, 0.1 }, 2 },
}
local CARDS = {}
for ti, t in ipairs(ORDER) do
  for k = 1, 6 do
    local id = (ti - 1) * 6 + k
    CARDS[id] = { id = id, type = t, name = NAMES[t][k], tier = k, power = 20 + k * 14 + ((id * 7) % 6) * 2 }
  end
end
RG.ARCADE_CARDS = CARDS
local PACK_PRICE, PACK_SIZE = 30, 5

local function store()
  if not WaypathDB then return nil end
  WaypathDB.arcade = WaypathDB.arcade or { coins = 0, cards = {}, acc = 0, packs = 0, wins = 0, losses = 0 }
  local a = WaypathDB.arcade
  a.cards = a.cards or {}
  return a
end

-- ---------------------------------------------------------------------------
-- Coins from XP: 1 coin for every 2% of a level you gain
-- ---------------------------------------------------------------------------
local lastXP, lastMax
local function earn(gainPct)
  local a = store(); if not a then return end
  a.acc = (a.acc or 0) + gainPct
  local coins = math.floor(a.acc / 2)
  if coins > 0 then a.acc = a.acc - coins * 2; a.coins = (a.coins or 0) + coins end
  if RG.ArcadeRefresh then RG.ArcadeRefresh() end
end
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN"); ev:RegisterEvent("PLAYER_XP_UPDATE"); ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, event)
  if not (UnitXP and UnitXPMax) then return end
  local xp, max = UnitXP("player"), UnitXPMax("player")
  if not xp or not max or max <= 0 or (RG.IsSecret and (RG.IsSecret(xp) or RG.IsSecret(max))) then return end
  if event == "PLAYER_LOGIN" then lastXP, lastMax = xp, max; return end
  if event == "PLAYER_LEVEL_UP" then return end -- the XP update that follows carries the numbers
  if lastXP then
    local gain
    if xp >= lastXP then gain = xp - lastXP else gain = (lastMax or max) - lastXP + xp end
    if gain > 0 and gain < (lastMax or max) * 3 then earn(gain / max * 100) end
  end
  lastXP, lastMax = xp, max
end)

-- ---------------------------------------------------------------------------
-- Packs and duels
-- ---------------------------------------------------------------------------
local function roll()
  local total = 0
  for _, r in ipairs(RARITY) do total = total + r[3] end
  local x = math.random() * total
  local tier = 1
  for i, r in ipairs(RARITY) do x = x - r[3]; if x <= 0 then tier = i; break end end
  if tier == 2 then tier = 1 end
  -- tiers 1 and 2 are both common
  if tier == 1 and math.random() < 0.5 then tier = 2 end
  local ti = math.random(#ORDER)
  return CARDS[(ti - 1) * 6 + tier]
end

function RG.ArcadeOpenPack()
  local a = store(); if not a then return nil end
  if (a.coins or 0) < PACK_PRICE then return nil, "A pack costs " .. PACK_PRICE .. " coins." end
  a.coins = a.coins - PACK_PRICE; a.packs = (a.packs or 0) + 1
  local got = {}
  for i = 1, PACK_SIZE do
    local c = roll()
    local isNew = (a.cards[c.id] or 0) == 0
    a.cards[c.id] = (a.cards[c.id] or 0) + 1
    got[#got + 1] = { card = c, new = isNew }
  end
  return got
end

local function best(a)
  local b
  for id, n in pairs(a.cards) do if n > 0 and (not b or CARDS[id].power > b.power) then b = CARDS[id] end end
  return b
end
local lastDuel = 0
function RG.ArcadeDuel()
  local a = store(); if not a then return end
  local mine = best(a)
  if not mine then return nil, "Open a pack first." end
  local now = GetTime and GetTime() or 0
  if lastDuel > 0 and now - lastDuel < 60 then return nil, "Your card is resting. Try again in a minute." end
  lastDuel = now
  local foe = CARDS[math.random(#CARDS)]
  local function score(c, o) local s = c.power + math.random(0, 20); if BEATS[c.type] == o.type then s = s + 25 end; if c.type == "shade" then s = s + 5 end; return s end
  local win = score(mine, foe) >= score(foe, mine)
  if win then a.coins = a.coins + 6; a.wins = (a.wins or 0) + 1 else a.losses = (a.losses or 0) + 1 end
  return win, mine, foe
end

function RG.ArcadeStats()
  local a = store() or { coins = 0, cards = {} }
  local own = 0
  for id, n in pairs(a.cards) do if n > 0 then own = own + 1 end end
  return a, own, #CARDS
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------
local frame, cells
local COLS, CW, CH = 6, 82, 72

local function cardTip(self)
  local c = self.card
  if not c then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local a = store()
  local n = a and a.cards[c.id] or 0
  if n == 0 then GameTooltip:AddLine("Not found yet", 0.6, 0.6, 0.6)
  else
    local r = RARITY[c.tier]
    GameTooltip:AddLine(c.name, r[2][1], r[2][2], r[2][3])
    GameTooltip:AddLine(TYPES[c.type][1] .. " · " .. r[1] .. " · Power " .. c.power, 1, 1, 1)
    if BEATS[c.type] then GameTooltip:AddLine("Beats " .. TYPES[BEATS[c.type]][1], 0.7, 0.9, 0.7) end
    GameTooltip:AddLine("You own " .. n, 0.7, 0.7, 0.7)
  end
  GameTooltip:Show()
end

local function build()
  frame = CreateFrame("Frame", "WaypathArcade", UIParent, "BackdropTemplate")
  frame:SetSize(COLS * CW + 44, 6 * CH + 150); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  RG.DialogBackdrop(frame)
  tinsert(UISpecialFrames, "WaypathArcade")
  frame.title = RG.NewText(frame, "GameFontNormalLarge"); frame.title:SetPoint("TOPLEFT", 22, -18); frame.title:SetText("Waymon cards")
  frame.coins = RG.NewText(frame, "GameFontNormal"); frame.coins:SetPoint("TOPRIGHT", -44, -22)
  frame.sub = RG.NewText(frame, "GameFontHighlightSmall"); frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6); frame.sub:SetTextColor(0.6, 0.6, 0.6)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
  cells = {}
  for i, c in ipairs(CARDS) do
    local cell = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    cell:SetSize(CW - 6, CH - 6)
    cell:SetPoint("TOPLEFT", 22 + ((i - 1) % COLS) * CW, -74 - math.floor((i - 1) / COLS) * CH)
    RG.Round(cell, 0.12, 0.12, 0.12, 1, 8)
    cell.icon = cell:CreateTexture(nil, "ARTWORK"); cell.icon:SetSize(30, 30); cell.icon:SetPoint("TOP", 0, -6)
    cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    cell.name = RG.NewText(cell, "GameFontHighlightSmall"); cell.name:SetPoint("BOTTOM", 0, 6); cell.name:SetWidth(CW - 12)
    cell.count = RG.NewText(cell, "GameFontNormalSmall"); cell.count:SetPoint("TOPRIGHT", -6, -5)
    cell.card = c
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", cardTip); cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cells[i] = cell
  end
  local function btn(label, x, fn)
    local o = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate"); o:SetSize(150, 26); o:SetPoint("BOTTOM", x, 18); o:SetText(label); o:SetScript("OnClick", fn)
    return o
  end
  frame.msg = RG.NewText(frame, "GameFontHighlight"); frame.msg:SetPoint("BOTTOM", 0, 54); frame.msg:SetWidth(COLS * CW - 20)
  frame.buy = btn("Open pack (" .. PACK_PRICE .. ")", -90, function()
    local got, err = RG.ArcadeOpenPack()
    if not got then frame.msg:SetText(err or "") return end
    local parts = {}
    for _, g in ipairs(got) do
      local r = RARITY[g.card.tier][2]
      parts[#parts + 1] = string.format("|cff%02x%02x%02x%s|r%s", r[1] * 255, r[2] * 255, r[3] * 255, g.card.name, g.new and " (new!)" or "")
    end
    frame.msg:SetText("Pack: " .. table.concat(parts, ", "))
    RG.ArcadeRefresh(true)
  end)
  frame.duel = btn("Duel for coins", 90, function()
    local win, mine, foe = RG.ArcadeDuel()
    if win == nil then frame.msg:SetText(mine or "") return end
    frame.msg:SetText((win and "Won! +6 coins. " or "Lost. ") .. mine.name .. " (" .. TYPES[mine.type][1] .. ") vs " .. foe.name .. " (" .. TYPES[foe.type][1] .. ")")
    RG.ArcadeRefresh(true)
  end)
end

function RG.ArcadeRefresh(keepMsg)
  if not (frame and frame:IsShown()) then return end
  local a, own, total = RG.ArcadeStats()
  frame.coins:SetText("|cffffd100" .. (a.coins or 0) .. "|r coins")
  frame.sub:SetText(own .. " of " .. total .. " cards  ·  XP pays 1 coin per 2% of a level  ·  " .. (a.wins or 0) .. " duel wins")
  if keepMsg ~= true then frame.msg:SetText("") end
  for i, c in ipairs(CARDS) do
    local cell, n = cells[i], a.cards[c.id] or 0
    local r = RARITY[c.tier][2]
    if n > 0 then
      cell.icon:SetTexture(TYPES[c.type][2]); cell.icon:SetDesaturated(false); cell.icon:SetVertexColor(1, 1, 1)
      cell.name:SetText(c.name); cell.name:SetTextColor(r[1], r[2], r[3])
      cell.count:SetText(n > 1 and ("x" .. n) or "")
    else
      cell.icon:SetTexture(TYPES[c.type][2]); cell.icon:SetDesaturated(true); cell.icon:SetVertexColor(0.3, 0.3, 0.3)
      cell.name:SetText("???"); cell.name:SetTextColor(0.4, 0.4, 0.4); cell.count:SetText("")
    end
  end
  frame.buy:SetEnabled((a.coins or 0) >= PACK_PRICE)
end

function RG.ShowArcade()
  if not frame then build() end
  frame:Show(); RG.ArcadeRefresh()
end

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  cmd = cmd and cmd:lower()
  if cmd == "arcade" or cmd == "waymon" or cmd == "cards" then RG.ShowArcade() return end
  return base(msg)
end
