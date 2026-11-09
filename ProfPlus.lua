-- Waypath+ profession leveling, the extras (ideas from LazyProf, CheapSkill, Forever Profession Master and RestedXP
-- Professions; all code here is Waypath+'s own):
--   * what a step costs: vendor materials at their vendor price, the rest at the last Auction House price
--   * cheapest or fastest: which of a step's recipes to make (Settings or the Professions tab)
--   * the recipe's real colour from your profession window, a "gone grey: move on", and a few extra materials for misses
--   * a shopping list for the step, the next one or the rest of the route; at a vendor, one button buys what's missing
--     (only when you click it); at the AH, a click searches a material by its exact item
--   * low-key reminders: a new ore or herb you can gather, train before you hit the cap, a gathering skill behind your level
local _, RG = ...

-- ---------------------------------------------------------------------------
-- Prices
-- ---------------------------------------------------------------------------
-- What one item costs you: a vendor material at the vendor's price; anything else at the last AH price, or what it
-- costs to make (bars, bolts) when that's cheaper or it has no AH price. nil when unknown.
function RG.MatUnitCost(id, depth)
  local info = RG.MAT_INFO and RG.MAT_INFO[id]
  if info and info[2] == "vendor" and info.p then return info.p, "vendor" end
  local ah = RG.Price and RG.Price(id)
  depth = depth or 0
  if depth < 2 and info and info[2] == "crafted" and RG.Recipe and RG.CanMake and RG.CanMake(info[1]) then
    local rec = RG.Recipe(info[1])
    if rec and rec.r and #rec.r > 0 then
      local sum = 0
      for _, r in ipairs(rec.r) do
        local c = RG.MatUnitCost(r[1], depth + 1)
        if not c then sum = nil; break end
        sum = sum + c * r[2]
      end
      if sum then
        sum = sum / math.max(1, rec.y or 1)
        if not ah or sum < ah then return sum, "make" end
      end
    end
  end
  if ah then return ah, "ah" end
  return nil
end

-- What the materials still to get cost: total (copper), how many have no price, and how much of it is in your bags.
-- mats: RG.MatsFor's list (crafted reagents you're short of carry their own materials with `via`).
function RG.MatsCost(mats)
  local total, unknown, owned = 0, 0, 0
  local expanded = {}
  for _, e in ipairs(mats or {}) do if e.via then expanded[e.via] = true end end
  for _, e in ipairs(mats or {}) do
    local c = RG.MatUnitCost(e.id)
    -- a bar or bolt you're short of: its own materials are listed (via), so it isn't bought as well
    local short = (expanded[e.name] and not e.via) and 0 or e.short
    if c then
      total = total + c * short
      owned = owned + c * math.min(e.have or 0, e.need or 0)
    elseif short > 0 then unknown = unknown + 1 end
  end
  return math.floor(total + 0.5), unknown, math.floor(owned + 0.5)
end

-- ---------------------------------------------------------------------------
-- Colours: orange gives a point every craft, yellow most, green some, grey none
-- ---------------------------------------------------------------------------
local CHANCE = { optimal = 1, medium = 0.75, easy = 0.3, trivial = 0 }
RG.SKILL_CHANCE = CHANCE
-- The recipe's colour for you now, if your profession window showed it at your current skill (nil otherwise).
function RG.RecipeColour(recipe, prof)
  local c = RG.db and RG.db.recipeCol and RG.db.recipeCol[recipe]
  if not c then return nil end
  local skill = RG.Skill and RG.Skill(prof or c.p)
  if c.at and skill and c.at ~= skill then
    -- read at another skill: grey stays grey, and orange is only trusted at the skill it was read at
    if c.c == "trivial" and skill > c.at then return "trivial" end
    return nil
  end
  return c.c
end
local COLOUR_TEXT = {
  optimal = "|cffff8040Orange|r: a point every craft",
  medium  = "|cffffff00Yellow|r: a point most crafts",
  easy    = "|cff40c040Green|r: a point now and then",
  trivial = "|cff808080Grey|r: no more points",
}
function RG.ColourText(c) return c and COLOUR_TEXT[c] or nil end
-- Extra crafts for misses: yellow +15%, green +40% (at least one more), nothing for orange or unknown.
function RG.CraftsWithMisses(left, colour)
  if not left or left <= 0 then return left end
  local extra = (colour == "medium" and 0.15) or (colour == "easy" and 0.4) or 0
  if extra == 0 then return left end
  return left + math.max(1, math.ceil(left * extra))
end

-- Cheapest or fastest (fewest materials still to get): RG.db.profPath, "cheap" by default.
function RG.ProfPathMode() return (RG.db and RG.db.profPath) or "cheap" end
function RG.ToggleProfPath()
  if not RG.db then return end
  RG.db.profPath = RG.ProfPathMode() == "cheap" and "fast" or "cheap"
  if RG.RefreshUI then RG.RefreshUI() end
end

-- ---------------------------------------------------------------------------
-- Shopping list: every material still to get for a stretch of the route
-- ---------------------------------------------------------------------------
-- scope: "step" (this step), "next" (this one and the next), "all" (to 300). Returns
-- { list = { {id, name, need, have, short, unit, src}, ... }, total, unknown, owned, steps }
function RG.ProfShopping(name, scope)
  local P = RG.PROFESSIONS and RG.PROFESSIONS[name]
  if not (P and RG.ProfNow) then return nil end
  local now = RG.ProfNow(name)
  if not now or now.done or not now.st then return { list = {}, total = 0, unknown = 0, owned = 0, steps = 0 } end
  local plan = RG.ProfPlan(P)
  local need, order = {}, {}
  local steps = 0
  local function add(id, n)
    if not need[id] then need[id] = 0; order[#order + 1] = id end
    need[id] = need[id] + n
  end
  for i = now.index, #plan do
    local st = plan[i]
    if not st.train and st.craft then
      local crafts = (i == now.index) and (now.leftWithMisses or now.left or 0) or (st.n or 0)
      local recipe = (i == now.index and now.craft) or (RG.ProfPickOption and RG.ProfPickOption(st, crafts)) or RG.StepOptions(st)[1]
      local rec = recipe and RG.Recipe(recipe)
      if rec and crafts > 0 then
        steps = steps + 1
        local runs = math.ceil(crafts / math.max(1, rec.y or 1))
        for _, r in ipairs(rec.r) do add(r[1], r[2] * runs) end
      end
      if scope == "step" or (scope == "next" and steps >= 2) then break end
    end
  end
  -- crafted reagents (bars, bolts): make them from what you're short of, one level down
  local count = RG.MatCount or function() return 0 end
  for k = 1, #order do
    local id = order[k]
    local info = RG.MAT_INFO and RG.MAT_INFO[id]
    local rec = info and info[2] == "crafted" and RG.CanMake and RG.CanMake(info[1]) and RG.Recipe(info[1])
    if rec and rec.r and #rec.r > 0 then
      local short = need[id] - count(id)
      if short > 0 then
        local runs = math.ceil(short / math.max(1, rec.y or 1))
        for _, r in ipairs(rec.r) do add(r[1], r[2] * runs) end
        need[id] = math.max(0, need[id] - runs * math.max(1, rec.y or 1))   -- (you make these instead of buying them)
      end
    end
  end
  local out = { list = {}, total = 0, unknown = 0, owned = 0, steps = steps }
  for _, id in ipairs(order) do
    if need[id] > 0 then
      local have = count(id)
      local short = math.max(0, need[id] - have)
      local unit, src = RG.MatUnitCost(id)
      local info = RG.MAT_INFO and RG.MAT_INFO[id]
      local e = { id = id, name = (RG.MatName and RG.MatName(id)) or (info and info[1]) or ("item " .. id), need = need[id], have = have, short = short, unit = unit, src = src, kind = info and info[2] }
      out.list[#out.list + 1] = e
      if unit then out.total = out.total + unit * short; out.owned = out.owned + unit * math.min(have, need[id])
      elseif short > 0 then out.unknown = out.unknown + 1 end
    end
  end
  out.total, out.owned = math.floor(out.total + 0.5), math.floor(out.owned + 0.5)
  table.sort(out.list, function(a, b) if (a.short > 0) ~= (b.short > 0) then return a.short > 0 end return a.name < b.name end)
  return out
end

-- ---------------------------------------------------------------------------
-- At a vendor: one button that buys the missing vendor materials (only when you click it)
-- (our own frame on UIParent, anchored next to the merchant window; the Blizzard frame itself is never touched)
-- ---------------------------------------------------------------------------
local buyBtn
local function vendorNeeds()
  -- missing vendor materials for this step and the next, for every profession you're leveling
  local want = {}
  for prof in pairs(RG.Professions and RG.Professions() or {}) do
    local shop = RG.ProfShopping(prof, "next")
    for _, e in ipairs(shop and shop.list or {}) do
      if e.short > 0 and e.kind == "vendor" then want[e.id] = (want[e.id] or 0) + e.short end
    end
  end
  if not (GetMerchantNumItems and GetMerchantItemInfo and GetMerchantItemLink) then return {} end
  local out = {}
  for i = 1, (GetMerchantNumItems() or 0) do
    local link = GetMerchantItemLink(i)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id and want[id] then
      local _, _, price, qty, avail = GetMerchantItemInfo(i)
      qty = math.max(1, qty or 1)
      local bundles = math.ceil(want[id] / qty)
      if avail and avail >= 0 then bundles = math.min(bundles, avail) end
      if bundles > 0 and price then out[#out + 1] = { i = i, id = id, bundles = bundles, qty = qty, price = price, cost = price * bundles, name = (RG.ItemInfo and RG.ItemInfo(id)) or ("item " .. id) } end
    end
  end
  return out
end
local function buyAll()
  local list = vendorNeeds()
  local money = GetMoney and GetMoney() or 0
  local bought, spent = {}, 0
  for _, e in ipairs(list) do
    local n = 0
    if e.qty == 1 then
      -- single items: bought a stack at a time (at most what one purchase allows)
      local maxStack = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(e.i)) or 20
      local left = math.min(e.bundles, math.floor((money - spent) / math.max(1, e.price)))
      while left > 0 do
        local q = math.min(left, math.max(1, maxStack))
        BuyMerchantItem(e.i, q)
        n = n + q; spent = spent + q * e.price; left = left - q
      end
    else
      -- bundles (a stack of 5 vials is one purchase)
      for _ = 1, e.bundles do
        if spent + e.price > money then break end
        BuyMerchantItem(e.i)
        n = n + 1; spent = spent + e.price
      end
    end
    if n > 0 then bought[#bought + 1] = (n * e.qty) .. " " .. e.name end
  end
  if #bought > 0 then RG.Print("Bought for your professions: " .. table.concat(bought, ", ") .. " (" .. RG.Money(spent) .. ").")
  else RG.Print("Not enough gold for the profession materials here.") end
  C_Timer.After(0.5, function() if buyBtn and buyBtn.refresh then buyBtn.refresh() end end)
end
local function vendorButton()
  if buyBtn then return buyBtn end
  local b = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
  b:SetSize(230, 24); b:SetFrameStrata("HIGH"); b:Hide()
  b:SetScript("OnClick", buyAll)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Waypath+: materials for your profession steps")
    for _, e in ipairs(self.list or {}) do GameTooltip:AddDoubleLine((e.bundles * e.qty) .. " " .. e.name, RG.Money(e.cost), 1, 1, 1, 1, 1, 1) end
    GameTooltip:AddLine("Buys only what this step and the next still need. Nothing is bought until you click.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b.refresh = function()
    local mf = MerchantFrame
    if not (mf and mf:IsShown()) or (RG.Opt and not RG.Opt("profBuyButton")) then b:Hide(); return end
    local list = vendorNeeds()
    if #list == 0 then b:Hide(); return end
    local total = 0
    for _, e in ipairs(list) do total = total + e.cost end
    b.list = list
    b:SetText("Buy profession materials (" .. RG.Money(total) .. ")")
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", mf, "TOPRIGHT", 4, -30)
    b:Show()
  end
  buyBtn = b
  return b
end
do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE", "BAG_UPDATE_DELAYED" }) do pcall(f.RegisterEvent, f, e) end
  f:SetScript("OnEvent", function(_, ev)
    if not RG.db then return end
    if ev == "MERCHANT_CLOSED" then if buyBtn then buyBtn:Hide() end return end
    if ev == "BAG_UPDATE_DELAYED" and not (MerchantFrame and MerchantFrame:IsShown()) then return end
    if RG.Debounce then RG.Debounce("profBuy", 0.3, function() vendorButton().refresh() end) else vendorButton().refresh() end
  end)
end

-- ---------------------------------------------------------------------------
-- At the Auction House: search a material by its exact item (a click on it in the shopping list)
-- ---------------------------------------------------------------------------
function RG.AHSearchItem(id)
  local name = RG.ItemInfo and RG.ItemInfo(id)
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() and C_AuctionHouse and C_AuctionHouse.SearchForItemKeys and C_AuctionHouse.MakeItemKey then
    local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
    local ok = pcall(C_AuctionHouse.SearchForItemKeys, { C_AuctionHouse.MakeItemKey(id) }, sorts)
    if ok then RG.Print("Searching the Auction House for " .. (name or ("item " .. id)) .. ".") end
    return ok
  elseif AuctionFrame and AuctionFrame:IsShown() and QueryAuctionItems and name then
    local ok = pcall(QueryAuctionItems, name, nil, nil, 0, nil, nil, false, true)
    if ok then RG.Print("Searching the Auction House for " .. name .. ".") end
    return ok
  end
  RG.Print("Open the Auction House, then click a material to search for it.")
  return false
end

-- ---------------------------------------------------------------------------
-- Reminders: a new ore or herb, train before the cap, a gathering skill behind your level
-- (each said once; turn them off in Settings)
-- ---------------------------------------------------------------------------
local UNLOCK = {
  Mining = { { 65, "Tin" }, { 75, "Silver" }, { 125, "Iron" }, { 155, "Gold" }, { 175, "Mithril" }, { 230, "Truesilver" }, { 245, "Small Thorium" }, { 275, "Rich Thorium" } },
  Herbalism = { { 15, "Mageroyal" }, { 50, "Swiftthistle and Bruiseweed" }, { 70, "Briarthorn" }, { 85, "Stranglekelp" }, { 100, "Bruiseweed" },
    { 115, "Wild Steelbloom" }, { 120, "Grave Moss" }, { 125, "Kingsblood" }, { 150, "Liferoot" }, { 160, "Fadeleaf" }, { 170, "Goldthorn" },
    { 185, "Khadgar's Whisker" }, { 195, "Wintersbite" }, { 205, "Firebloom" }, { 210, "Purple Lotus" }, { 220, "Arthas' Tears" },
    { 230, "Sungrass" }, { 235, "Blindweed" }, { 245, "Ghost Mushroom" }, { 250, "Gromsblood" }, { 260, "Golden Sansam" },
    { 270, "Dreamfoil" }, { 280, "Mountain Silversage" }, { 285, "Plaguebloom" }, { 290, "Icecap" }, { 300, "Black Lotus" } },
}
local CAPS = { { 75, "Journeyman", "journeyman", 10 }, { 150, "Expert", "expert", 20 }, { 225, "Artisan", "artisan", 35 } }
local function said(key)
  RG.db.profSaid = RG.db.profSaid or {}
  if RG.db.profSaid[key] then return true end
  RG.db.profSaid[key] = time and time() or true
  return false
end
local TAIL = " |cff808080(profession reminders: Settings)|r"
function RG.ProfReminders(prof, before, after)
  if not (RG.db and RG.Opt and RG.Opt("profTips")) then return end
  if RG.IsAlt and RG.IsAlt() then return end
  -- a new ore or herb
  for _, u in ipairs(UNLOCK[prof] or {}) do
    if before and before < u[1] and after >= u[1] and not said(prof .. "@" .. u[1]) then
      RG.Print(prof .. " " .. after .. ": you can " .. (prof == "Mining" and "mine " or "pick ") .. u[2] .. " now." .. TAIL)
    end
  end
  -- the cap is close: train
  local k = RG.Professions and RG.Professions()[prof]
  local max = k and k.max
  local P = RG.PROFESSIONS and RG.PROFESSIONS[prof]
  local T = P and ((RG.PLAYER_FACTION == "Alliance" and P.trainA) or P.train) or {}
  for _, c in ipairs(CAPS) do
    if max == c[1] and after >= c[1] - 5 and not said(prof .. "cap" .. c[1]) then
      local lvl = UnitLevel and UnitLevel("player") or 1
      local where = T[c[3]]
      RG.Print(prof .. " " .. after .. "/" .. max .. ": train " .. c[2] .. (lvl < c[4] and (" at level " .. c[4]) or "") .. (where and (" (" .. where .. ")") or "") .. " to keep leveling." .. TAIL)
    end
  end
end
-- A gathering skill well behind your level (once every 10 levels).
local GATHER = { Mining = true, Herbalism = true, Skinning = true }
function RG.ProfPaceCheck()
  if not (RG.db and RG.Opt and RG.Opt("profTips")) then return end
  if RG.IsAlt and RG.IsAlt() then return end
  local lvl = UnitLevel and UnitLevel("player") or 1
  if lvl < 15 then return end
  for prof, k in pairs(RG.Professions and RG.Professions() or {}) do
    local want = math.min(300, lvl * 5 - 25)
    if GATHER[prof] and k.rank and k.rank < want - 50 and not said(prof .. "pace" .. math.floor(lvl / 10)) then
      RG.Print("Your " .. prof .. " (" .. k.rank .. ") is behind for level " .. lvl .. ": what's around you now could take it to about " .. want .. ". The Professions tab says where." .. TAIL)
      return
    end
  end
end
do
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "PLAYER_LEVEL_UP")
  pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function(_, ev)
    if ev == "PLAYER_ENTERING_WORLD" then f:UnregisterEvent("PLAYER_ENTERING_WORLD") end
    C_Timer.After(ev == "PLAYER_LEVEL_UP" and 3 or 30, function() pcall(RG.ProfPaceCheck) end)
  end)
end

table.insert(RG.OPTIONS, { key = "profTips", label = "Profession reminders: a new ore or herb, train before the cap, gathering behind your level", default = true })
table.insert(RG.OPTIONS, { key = "profBuyButton", label = "At a vendor, show a button that buys the materials for my next profession steps", default = true })
