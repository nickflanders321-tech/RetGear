-- Waypath+ ammo reminder: anyone with a bow, crossbow or gun gets a reminder to stock up on arrows
-- or bullets while in town (a rested area), with the nearest ammo vendor on the map, and a button at
-- a vendor that sells your ammo to buy enough in one click. Vendors: Professions/Generated.lua
-- RG.AMMO_VENDORS (cMaNGOS vendor lists, WoW Forever spawn points). Nothing is bought without your click.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
local C = C_Container or {}
table.insert(RG.OPTIONS, { key = "ammoReminder", label = "Remind me to buy arrows or bullets while I'm in town", default = true })

-- standard vendor ammo, worst to best, with the level each needs
local AMMO = {
  arrow  = { { id = 2512, lvl = 1, name = "Rough Arrow" }, { id = 2515, lvl = 10, name = "Sharp Arrow" }, { id = 3030, lvl = 25, name = "Razor Arrow" }, { id = 11285, lvl = 40, name = "Jagged Arrow" } },
  bullet = { { id = 2516, lvl = 1, name = "Light Shot" }, { id = 2519, lvl = 10, name = "Heavy Shot" }, { id = 3033, lvl = 25, name = "Solid Shot" }, { id = 11284, lvl = 40, name = "Accurate Slugs" } },
}
local WORD = { arrow = "arrows", bullet = "bullets" }
local PROJECTILE, ARROW_SUB, BULLET_SUB = 6, 2, 3

local function instant(x) return (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(x) end

-- "arrow", "bullet" or nil for what your ranged weapon fires (thrown weapons and wands need none)
function RG.AmmoKind()
  local link = GetInventoryItemLink("player", 18)
  if not link then return nil end
  local _, _, _, _, _, classID, sub = instant(link)
  if classID ~= 2 then return nil end
  if sub == 2 or sub == 18 then return "arrow" end   -- bows, crossbows
  if sub == 3 then return "bullet" end               -- guns
end

-- how many of that kind you carry (every bag, quivers and ammo pouches included)
function RG.AmmoCount(kind)
  local want = kind == "arrow" and ARROW_SUB or BULLET_SUB
  local n = 0
  for bag = 0, 4 do
    local slots = (C.GetContainerNumSlots and C.GetContainerNumSlots(bag)) or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
    for slot = 1, slots do
      local id, count
      if C.GetContainerItemInfo then
        local i = C.GetContainerItemInfo(bag, slot)
        if i then id, count = i.itemID, i.stackCount end
      elseif GetContainerItemInfo then
        local _, c, _, _, _, _, _, _, _, iid = GetContainerItemInfo(bag, slot)
        id, count = iid, c
      end
      if id then
        local _, _, _, _, _, classID, sub = instant(id)
        if classID == PROJECTILE and sub == want then n = n + (count or 1) end
      end
    end
  end
  return n
end

-- the best vendor ammo for your level
local function bestAmmo(kind)
  local lvl = UnitLevel("player") or 1
  local best
  for _, a in ipairs(AMMO[kind]) do if a.lvl <= lvl then best = a end end
  return best
end

-- Hunters fire every shot: keep five stacks. Everyone else only pulls with it: one stack.
local function target()
  local _, class = UnitClass("player")
  if class == "HUNTER" then return 1000, 600 end   -- fill to, remind below
  return 200, 100
end

-- the nearest ammo vendor on your map for your faction that sells your best ammo (or any of your kind)
local function nearestVendor(kind, best)
  local list = RG.AMMO_VENDORS
  if not list then return nil end
  local fac = RG.PLAYER_FACTION == "Alliance" and "A" or "H"
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map then return nil end
  local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  local px, py = pos and pos.x, pos and pos.y
  if px and RG.IsSecret and (RG.IsSecret(px) or RG.IsSecret(py)) then px = nil end
  local pick, pickD, pickBest
  for _, v in ipairs(list) do
    if v[1] == map and (v[5] == fac or v[5] == "AH") then
      local sellsBest, sellsKind = false, false
      for _, id in ipairs(v[6] or {}) do
        if best and id == best.id then sellsBest = true end
        for _, a in ipairs(AMMO[kind]) do if a.id == id then sellsKind = true end end
      end
      if sellsKind then
        local d = px and ((v[2] / 100 - px) ^ 2 + (v[3] / 100 - py) ^ 2) or 0
        -- a vendor with your best ammo beats a closer one without it
        if not pick or (sellsBest and not pickBest) or (sellsBest == pickBest and d < pickD) then pick, pickD, pickBest = v, d, sellsBest end
      end
    end
  end
  return pick
end

local function inTown()
  if not (IsResting and IsResting()) then return false end
  local inInst = IsInInstance and IsInInstance()
  return not inInst
end

-- what to tell you, or nil: { kind, have, fill, best, vendor }
local function need()
  if not RG.db or not RG.Opt("ammoReminder") or (RG.IsAlt and RG.IsAlt()) or (RG.CardsOnly and RG.CardsOnly()) then return nil end
  local kind = RG.AmmoKind()
  if not kind then return nil end
  local have = RG.AmmoCount(kind)
  local fill, below = target()
  if have >= below then return nil end
  local best = bestAmmo(kind)
  return { kind = kind, have = have, fill = fill, best = best, vendor = inTown() and nearestVendor(kind, best) or nil }
end
RG.AmmoNeed = need

-- the tracker line while you're in town and low
local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  if InCombatLockdown and InCombatLockdown() then return out end
  if not inTown() then return out end
  local ok, n = pcall(need)
  if not (ok and n) then return out end
  local what = n.best and n.best.name .. "s" or WORD[n.kind]
  local v = n.vendor
  local text = "|TInterface\\Icons\\INV_Ammo_Arrow_02:14:14|t " .. GOLD .. "Buy " .. WORD[n.kind] .. "|r" .. GREY .. ": " .. n.have .. " left"
    .. (v and (", " .. what .. " at " .. (v[4]:gsub(" %(.-%)$", "")) .. " (click to pin)") or (", " .. what .. " from a general goods vendor")) .. "|r"
  local wp = v and { v[1], v[2], v[3], (v[4]:gsub(" <.-$", "")) } or nil
  out[#out + 1] = { text, wp and function() RG.PinWaypoint(wp) end or nil, 2, wp }
  return out
end

-- once each time you come into town while low: a line in chat
local told = false
local function onRest()
  if not inTown() then told = false; return end
  if told then return end
  local ok, n = pcall(need)
  if not (ok and n) then return end
  told = true
  local v = n.vendor
  RG.Print(GOLD .. "Low on " .. WORD[n.kind] .. "|r" .. GREY .. " (" .. n.have .. " left). Stock up while you're in town"
    .. (n.best and (": " .. n.best.name .. "s") or "") .. (v and (" at " .. v[4]) or "") .. ".|r")
  if RG.QueueTracker then RG.QueueTracker() end
end

-- ---------------------------------------------------------------------------
-- At a vendor that sells your ammo: one button buys enough to fill up
-- ---------------------------------------------------------------------------
local buyBtn
local function merchantIndex(id)
  for i = 1, (GetMerchantNumItems and GetMerchantNumItems() or 0) do
    local mid = GetMerchantItemID and GetMerchantItemID(i)
    if not mid then
      local link = GetMerchantItemLink and GetMerchantItemLink(i)
      mid = link and tonumber(link:match("item:(%d+)"))
    end
    if mid == id then return i end
  end
end
-- the best ammo of your kind this vendor sells that you can use
local function vendorAmmo(kind)
  local lvl = UnitLevel("player") or 1
  for i = #AMMO[kind], 1, -1 do
    local a = AMMO[kind][i]
    if a.lvl <= lvl then
      local idx = merchantIndex(a.id)
      if idx then return a, idx end
    end
  end
end
local function money(c)
  if GetCoinTextureString then return GetCoinTextureString(c) end
  return string.format("%dg %ds %dc", c / 10000, (c / 100) % 100, c % 100)
end
local function updateBuy()
  if not MerchantFrame then return end
  local show = false
  local kind = RG.Opt("ammoReminder") and not (RG.IsAlt and RG.IsAlt()) and RG.AmmoKind()
  if kind then
    local a, idx = vendorAmmo(kind)
    local have = RG.AmmoCount(kind)
    local fill = target()
    local want = fill - have
    if a and idx and want > 0 then
      local price, perBuy = RG.MerchantItemInfo(idx)
      perBuy = (perBuy and perBuy > 0) and perBuy or 1
      price = price or 0
      local unit = price / perBuy
      -- whole stacks of 200, as many as you can afford
      local qty = math.ceil(want / 200) * 200
      local afford = unit > 0 and math.floor(GetMoney() / unit) or qty
      qty = math.min(qty, afford - afford % 200)
      if qty > 0 then
        if not buyBtn then
          buyBtn = CreateFrame("Button", "WaypathAmmoBuy", MerchantFrame, "UIPanelButtonTemplate")
          buyBtn:SetSize(220, 24)
          buyBtn:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 6, -60)
          buyBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Waypath+ ammo")
            GameTooltip:AddLine(self.tip or "", 1, 1, 1, true)
            GameTooltip:Show()
          end)
          buyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
          buyBtn:SetScript("OnClick", function(self)
            local d = self.data
            if not d then return end
            local i = merchantIndex(d.id)
            if not i then return end
            if d.perBuy > 1 then
              -- sold in bundles (a stack of 200 per purchase): buy that many bundles
              for _ = 1, math.floor(d.qty / d.perBuy) do BuyMerchantItem(i) end
            else
              local left = d.qty
              local maxStack = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(i)) or 200
              while left > 0 do
                local n = math.min(left, maxStack)
                BuyMerchantItem(i, n)
                left = left - n
              end
            end
            RG.Print(GREEN .. "Bought " .. d.qty .. " " .. d.name .. "s.|r")
            self:Hide()
            if C_Timer then C_Timer.After(1, function() pcall(updateBuy) end) end
          end)
        end
        buyBtn.data = { id = a.id, qty = qty, name = a.name, perBuy = perBuy }
        buyBtn:SetText("Buy " .. qty .. " " .. a.name .. "s")
        buyBtn.tip = "You have " .. have .. " " .. WORD[kind] .. ". This buys " .. qty .. " (" .. math.floor(qty / 200) .. (qty > 200 and " stacks" or " stack") .. ") for " .. money(math.floor(unit * qty + 0.5)) .. "."
        buyBtn:Show()
        show = true
      end
    end
  end
  if buyBtn and not show then buyBtn:Hide() end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE", "BAG_UPDATE_DELAYED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if not RG.db then return end
  if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" or (event == "BAG_UPDATE_DELAYED" and MerchantFrame and MerchantFrame:IsShown()) then
    local ok, err = pcall(updateBuy)
    if not ok and RG.RecordError then RG.RecordError(err) end
  elseif event == "MERCHANT_CLOSED" then
    if buyBtn then buyBtn:Hide() end
  elseif event ~= "BAG_UPDATE_DELAYED" then
    -- a moment after arriving, so the map and resting state have settled
    if C_Timer then C_Timer.After(3, function() pcall(onRest) end) else pcall(onRest) end
  end
end)
