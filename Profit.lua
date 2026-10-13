-- Waypath+ "Don't vendor that!" guard.
-- Watches your bags for items that sell for more on the Auction House than at
-- a vendor, marks them in your bags and tooltips, keeps them out of the junk
-- auto-sell, warns you at vendors, and offers a one-click buy back if you sell
-- one by mistake.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local AH_CUT = 0.05 -- the Auction House keeps 5% of the sale
local COIN = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"

table.insert(RG.OPTIONS, { key = "profitWatch", label = "Warn me before I vendor items worth more on the AH", default = true })

local function on() return RG.Opt("profitWatch") end
local function pdb()
  RG.db.profitIgnore = RG.db.profitIgnore or {}
  return RG.db
end
-- Smallest extra profit (whole stack, in copper) worth bothering with. Default 10 silver.
function RG.ProfitMin() return pdb().profitMin or 1000 end

local function classOf(id)
  local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not fn then return nil end
  return select(6, fn(id))
end

-- ---------------------------------------------------------------------------
-- Pricing one item
-- ---------------------------------------------------------------------------
-- Returns a table for one unit of an item, or nil if it can't be sold:
--   { ah = lowest listing, net = what you keep after the AH cut,
--     vendor = vendor price, gain = net - vendor, src = price source }
function RG.ProfitInfo(id)
  if not id then return nil end
  local vendor = select(11, RG.ItemInfo(id)) or 0
  local ah, src, rec = RG.Price(id)
  if not ah or (rec and rec.none) then return { vendor = vendor, unpriced = true } end
  local net = math.floor(ah * (1 - AH_CUT))
  return { ah = ah, net = net, vendor = vendor, gain = net - vendor, src = src, age = rec and rec.t }
end

-- Is this stack worth taking to the AH instead of a vendor?
local function worthIt(p, count)
  if not p or p.unpriced then return false end
  if p.gain <= 0 then return false end
  if p.vendor > 0 and p.net < p.vendor * 1.25 then return false end -- tiny margins aren't worth the trip
  return p.gain * (count or 1) >= RG.ProfitMin()
end

-- ---------------------------------------------------------------------------
-- Bag scan
-- ---------------------------------------------------------------------------
local C = C_Container
local function numSlots(bag) return ((C and C.GetContainerNumSlots) or GetContainerNumSlots)(bag) or 0 end
local function slotInfo(bag, slot) return C and C.GetContainerItemInfo and C.GetContainerItemInfo(bag, slot) end

-- Items in your bags that could go on the AH: not soulbound, not quest items.
local sellable, sellStamp = {}, nil
function RG.BagSellSet()
  if sellStamp and GetTime() - sellStamp < 2 then return sellable end
  sellStamp = GetTime()
  local set = {}
  for bag = 0, 4 do
    for slot = 1, numSlots(bag) do
      local info = slotInfo(bag, slot)
      if info and info.itemID and not info.isBound and classOf(info.itemID) ~= 12 then set[info.itemID] = (set[info.itemID] or 0) + (info.stackCount or 1) end
    end
  end
  sellable = set
  return set
end
function RG.BagSellIDs()
  local out = {}
  if not on() then return out end
  for id in pairs(RG.BagSellSet()) do
    local q = select(3, RG.ItemInfo(id))
    if (q == nil or q >= 1) and not pdb().profitIgnore[id] then out[#out + 1] = id end
  end
  return out
end

-- Everything in your bags you'd lose money vendoring, best first.
-- Each entry: { id, link, count, quality, p = ProfitInfo, total = gain for the stack, slots = { {bag, slot}, ... } }
-- Unpriced tradeable greens and better are returned separately so you know to check them.
local listCache, listStamp = nil, nil
function RG.ProfitList()
  if listStamp and GetTime() - listStamp < 1 then return listCache.items, listCache.unpriced, listCache.total end
  listStamp = GetTime()
  local byID = {}
  if on() then
    for bag = 0, 4 do
      for slot = 1, numSlots(bag) do
        local info = slotInfo(bag, slot)
        local id = info and info.itemID
        if id and not info.isBound and not pdb().profitIgnore[id] and classOf(id) ~= 12 and not (RG.IsHealKeeper and RG.IsHealKeeper(id)) then
          local e = byID[id]
          if not e then e = { id = id, link = info.hyperlink, count = 0, quality = info.quality, slots = {} }; byID[id] = e end
          e.count = e.count + (info.stackCount or 1)
          e.slots[#e.slots + 1] = { bag, slot }
        end
      end
    end
  end
  local items, unpriced, total = {}, {}, 0
  for id, e in pairs(byID) do
    e.p = RG.ProfitInfo(id)
    if worthIt(e.p, e.count) then
      e.total = e.p.gain * e.count
      total = total + e.total
      items[#items + 1] = e
    elseif e.p and e.p.unpriced and (e.quality or 0) >= 2 then
      unpriced[#unpriced + 1] = e
    end
  end
  table.sort(items, function(a, b) return a.total > b.total end)
  table.sort(unpriced, function(a, b) return (a.quality or 0) > (b.quality or 0) end)
  listCache = { items = items, unpriced = unpriced, total = total }
  return items, unpriced, total
end
local function invalidate() listStamp = nil; sellStamp = nil end
RG.ProfitInvalidate = invalidate

-- Set of "bag:slot" the junk seller must leave alone.
function RG.ProfitSkip()
  local skip = {}
  if not on() then return skip end
  invalidate()
  local items = RG.ProfitList()
  for _, e in ipairs(items) do for _, s in ipairs(e.slots) do skip[s[1] .. ":" .. s[2]] = true end end
  return skip, items
end
function RG.IsProfitItem(id)
  if not on() or not id then return false end
  local items = RG.ProfitList()
  for _, e in ipairs(items) do if e.id == id then return e end end
  return false
end

-- ---------------------------------------------------------------------------
-- Tooltip line
-- ---------------------------------------------------------------------------
local function OnTooltip(tooltip, data)
  if not on() or tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  local id = data and data.id
  if not id and tooltip.GetItem then local _, link = tooltip:GetItem(); id = link and tonumber(link:match("item:(%d+)")) end
  if not id or pdb().profitIgnore[id] then return end
  local p = RG.ProfitInfo(id)
  if not p or p.unpriced then return end
  if worthIt(p, 1) or (p.gain > 0 and RG.BagSellSet()[id] and worthIt(p, RG.BagSellSet()[id])) then
    tooltip:AddLine(COIN .. " " .. GOLD .. "Sell this on the Auction House|r", 1, 1, 1)
    tooltip:AddDoubleLine(GREY .. "  You keep " .. "|r" .. RG.Money(p.net) .. GREY .. " each after the AH cut|r", GREY .. "vendor " .. "|r" .. RG.Money(p.vendor))
    tooltip:Show()
  end
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)
elseif GameTooltip and GameTooltip.HookScript then
  GameTooltip:HookScript("OnTooltipSetItem", OnTooltip)
end

-- ---------------------------------------------------------------------------
-- Gold coin on the bag slots of items worth keeping
-- ---------------------------------------------------------------------------
local marks = {}
local function mark(button, show)
  local m = marks[button]
  if not m then
    if not show then return end
    m = button:CreateTexture(nil, "OVERLAY", nil, 7)
    m:SetSize(14, 14); m:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    m:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    marks[button] = m
  end
  m:SetShown(show and true or false)
end
local function eachBagButton(fn)
  -- Modern bags (one frame per bag, or the combined backpack)
  local frames = {}
  if ContainerFrameCombinedBags then frames[#frames + 1] = ContainerFrameCombinedBags end
  for i = 1, 13 do local f = _G["ContainerFrame" .. i]; if f then frames[#frames + 1] = f end end
  for _, f in ipairs(frames) do
    if f:IsShown() then
      if f.EnumerateValidItems then
        for _, b in f:EnumerateValidItems() do
          local bag = b.GetBagID and b:GetBagID()
          if bag then fn(b, bag, b:GetID()) end
        end
      else
        local bag = f.GetID and f:GetID()
        local name = f.GetName and f:GetName()
        for j = 1, 36 do
          local b = name and _G[name .. "Item" .. j]
          if not b then break end
          fn(b, bag, b:GetID())
        end
      end
    end
  end
end
RG.EachBagButton = eachBagButton
function RG.UpdateBagMarks()
  local skip = on() and RG.ProfitSkip() or {}
  pcall(eachBagButton, function(b, bag, slot) mark(b, skip[bag .. ":" .. slot]) end)
end
local function queueMarks() C_Timer.After(0.05, RG.UpdateBagMarks) end
if hooksecurefunc then
  for _, fn in ipairs({ "ToggleBag", "OpenBag", "OpenAllBags", "ToggleAllBags", "OpenBackpack", "ToggleBackpack", "ContainerFrame_Update" }) do
    if _G[fn] then hooksecurefunc(fn, queueMarks) end
  end
end

-- ---------------------------------------------------------------------------
-- At the vendor: warn, and offer buy back if one gets sold anyway
-- ---------------------------------------------------------------------------
local atVendor, watched = false, {}
local function counts()
  local out = {}
  for bag = 0, 4 do
    for slot = 1, numSlots(bag) do
      local info = slotInfo(bag, slot)
      if info and info.itemID then out[info.itemID] = (out[info.itemID] or 0) + (info.stackCount or 1) end
    end
  end
  return out
end
local function buybackIndex(id)
  if not (GetNumBuybackItems and GetBuybackItemLink) then return nil end
  for i = GetNumBuybackItems(), 1, -1 do
    local link = GetBuybackItemLink(i)
    if link and tonumber(link:match("item:(%d+)")) == id then return i end
  end
end

local function onVendor()
  atVendor = true
  invalidate()
  local items, _, total = RG.ProfitList()
  watched = {}
  local have = counts()
  for _, e in ipairs(items) do watched[e.id] = { count = have[e.id] or e.count, e = e } end
  -- your 2nd spec's set: watch it too
  if RG.HealSet and RG.SecondSetOn and RG.SecondSetOn() then
    local _, _, keep = RG.HealSet()
    for id in pairs(keep) do
      if have[id] and not watched[id] then watched[id] = { count = have[id], e = { id = id, heal = true } } end
    end
  end
  if #items == 0 then return end
  local names = {}
  for i = 1, math.min(3, #items) do names[i] = items[i].link or (RG.ItemInfo(items[i].id)) or "item" end
  local more = #items > 3 and (GREY .. " and " .. (#items - 3) .. " more|r") or ""
  RG.Print(GOLD .. "Don't vendor these|r, they're worth more on the AH (about " .. RG.Money(total) .. " extra): " .. table.concat(names, ", ") .. more)
  if RG.Toast then
    RG.Toast("Keep for the AH", #items .. " item" .. (#items > 1 and "s" or "") .. " in your bags (marked with a " .. COIN .. ") sell for about " .. RG.Money(total) .. " more on the Auction House.", "Interface\\Icons\\INV_Misc_Coin_01", "Show me", function() if RG.ShowTab then RG.ShowTab("ah") end end, 8)
  end
end

local function checkSold()
  if not atVendor or not next(watched) then return end
  local have = counts()
  for id, w in pairs(watched) do
    local now = have[id] or 0
    if now < w.count then
      local sold = w.count - now
      w.count = now
      local idx = buybackIndex(id)
      if idx and w.e.heal then
        local link = select(2, RG.ItemInfo(id)) or "that item"
        RG.Print(RED .. "Careful:|r you sold " .. link .. ", a piece of your " .. (RG.SecondSpecName and RG.SecondSpecName() or "2nd spec") .. " set. Buy it back from the vendor's Buyback tab.")
        if RG.Toast then
          RG.Toast("2nd spec item sold", link .. " was in your " .. (RG.SecondSpecName and RG.SecondSpecName() or "2nd spec") .. " set.", select(10, RG.ItemInfo(id)), "Buy back", function()
            local i = buybackIndex(id)
            if i and MerchantFrame and MerchantFrame:IsShown() then BuybackItem(i); RG.Print("Bought back " .. link .. ".") else RG.Print("Open the vendor again to buy it back.") end
          end, 10)
        end
      elseif idx then
        local link = w.e.link or select(2, RG.ItemInfo(id)) or "that item"
        local lost = w.e.p.gain * sold
        RG.Print(RED .. "Oops:|r you sold " .. link .. (sold > 1 and (" x" .. sold) or "") .. ", which is worth about " .. RG.Money(lost) .. " more on the AH. Buy it back from the vendor's Buyback tab.")
        if RG.Toast then
          RG.Toast("Sold by mistake?", link .. " is worth about " .. RG.Money(lost) .. " more on the Auction House.", select(10, RG.ItemInfo(id)), "Buy back", function()
            local i = buybackIndex(id)
            if i and MerchantFrame and MerchantFrame:IsShown() then BuybackItem(i); RG.Print("Bought back " .. link .. ".") else RG.Print("Open the vendor again to buy it back.") end
          end, 10)
        end
      end
    end
  end
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "BAG_UPDATE_DELAYED", "AUCTION_HOUSE_CLOSED", "PLAYER_LOGIN" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event)
  if event == "MERCHANT_SHOW" then
    -- let the junk seller run first so its sales don't count as mistakes
    if on() then C_Timer.After(1.2, onVendor) end
  elseif event == "MERCHANT_CLOSED" then
    atVendor = false; watched = {}
  elseif event == "BAG_UPDATE_DELAYED" then
    invalidate()
    if on() then checkSold() end
    RG.Debounce("bagMarks", 0.3, RG.UpdateBagMarks)
    return
  else
    invalidate(); queueMarks()
    if RG.RefreshUI then RG.RefreshUI() end
  end
end)

-- Tracker reminder: "3 items worth 1g 20s more on the AH"
local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  if on() then
    local items, _, total = RG.ProfitList()
    if #items > 0 then
      out[#out + 1] = { COIN .. " " .. GOLD .. #items .. " bag item" .. (#items > 1 and "s" or "") .. " to sell on the AH|r" .. GREY .. "  (+" .. RG.Money(total) .. ")|r", function() if RG.ShowTab then RG.ShowTab("ah") end end, 7 }
    end
  end
  return out
end

-- /wp profit            list what to keep for the AH
-- /wp profit min 25     only flag items worth 25 silver more than vendoring
-- /wp profit ignore [item]  stop flagging an item (again to undo)
local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.*)$")
  if cmd and cmd:lower() == "gold" then if RG.ShowTab then RG.ShowTab("gold") end return end
  if not (cmd and cmd:lower() == "profit") then return base(msg) end
  local sub, arg = rest:match("^(%S+)%s*(.*)$")
  sub = sub and sub:lower()
  if sub == "min" and tonumber(arg) then
    pdb().profitMin = math.floor(tonumber(arg) * 100)
    invalidate(); RG.Print("Only flagging items worth at least " .. RG.Money(RG.ProfitMin()) .. " more on the AH.")
  elseif sub == "ignore" then
    local id = tonumber(arg:match("item:(%d+)") or arg:match("^(%d+)"))
    if not id then RG.Print("Usage: /wp profit ignore [shift-click item]") return end
    local ig = pdb().profitIgnore
    ig[id] = not ig[id] or nil
    invalidate()
    RG.Print((select(2, RG.ItemInfo(id)) or id) .. (ig[id] and " won't be flagged any more." or " will be flagged again."))
  else
    invalidate()
    local items, unpriced, total = RG.ProfitList()
    if #items == 0 then RG.Print("Nothing in your bags is worth more on the AH right now." .. (#unpriced > 0 and (" " .. #unpriced .. " item(s) haven't been priced yet: open the AH to check them.") or ""))
    else
      RG.Print("Sell these on the AH (about " .. RG.Money(total) .. " more than vendoring):")
      for _, e in ipairs(items) do RG.Print("  " .. (e.link or e.id) .. (e.count > 1 and (" x" .. e.count) or "") .. GREY .. "  AH " .. "|r" .. RG.Money(e.p.ah) .. GREY .. " vs vendor |r" .. RG.Money(e.p.vendor)) end
    end
  end
  if RG.RefreshUI then RG.RefreshUI() end
  if RG.QueueTracker then RG.QueueTracker() end
end
