-- RetGear Auction House prices.
-- Live prices come from scanning while you're at the Auction House: opening
-- the AH scans every tracked item, and any search you do yourself updates
-- prices too. Auctionator or TradeSkillMaster prices are used when installed,
-- so you still see a number away from the AH.
local _, RG = ...
local GREEN, GREY, GOLD = RG.COLORS.GREEN, RG.COLORS.GREY, RG.COLORS.GOLD

local function money(c)
  if not c then return "?" end
  if GetCoinTextureString then return GetCoinTextureString(c) end
  local g, s = math.floor(c / 10000), math.floor((c % 10000) / 100)
  return (g > 0 and (g .. "g ") or "") .. s .. "s"
end
RG.Money = money

local function ageText(t)
  local m = math.floor((time() - t) / 60)
  if m < 1 then return "just now" elseif m < 60 then return m .. "m ago"
  elseif m < 1440 then return math.floor(m / 60) .. "h ago" end
  return math.floor(m / 1440) .. "d ago"
end

-- Every item whose price we watch: guide items you can buy, plus /rg track.
function RG.TrackedIDs()
  local ids, seen = {}, {}
  for _, g in ipairs(RG.GUIDE) do if g.ah and not seen[g.id] then ids[#ids + 1] = g.id; seen[g.id] = true end end
  for id in pairs(RG.db.tracked) do if not seen[id] then ids[#ids + 1] = id; seen[id] = true end end
  local prof = RG.Professions()
  if prof["Mining"] or prof["Blacksmithing"] then
    for _, id in ipairs(RG.MATS) do if not seen[id] then ids[#ids + 1] = id; seen[id] = true end end
  end
  return ids
end
local MAT = {}
for _, id in ipairs(RG.MATS) do MAT[id] = true end
local function isTracked(id)
  if RG.db.tracked[id] or MAT[id] then return true end
  local g = RG.GuideByID[id]
  return g and g.ah
end

-- Price from other addons, if present.
local function addonPrice(id)
  if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID then
    local ok, p = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "RetGear", id)
    if ok and p then return p, "Auctionator" end
  end
  if TSM_API and TSM_API.GetCustomPriceValue then
    local ok, p = pcall(TSM_API.GetCustomPriceValue, "dbminbuyout", "i:" .. id)
    if ok and p then return p, "TSM" end
  end
end

function RG.Price(id)
  local rec = RG.db.prices[id]
  local ap, src = addonPrice(id)
  if rec and (not ap or time() - rec.t < 6 * 3600) then return rec.price, "scan", rec end
  if ap then return ap, src end
  if rec then return rec.price, "scan", rec end
end

function RG.PriceText(id)
  if not isTracked(id) and not RG.db.prices[id] then return nil end
  local p, src, rec = RG.Price(id)
  if not p then return GREY .. "not seen yet (open the AH to scan)|r" end
  if rec and rec.none then return GREY .. "none listed (" .. ageText(rec.t) .. ")|r" end
  local s = money(p)
  if src == "scan" then s = s .. GREY .. "  (" .. ageText(rec.t) .. (rec.n and rec.n > 1 and (", " .. rec.n .. " listed") or "") .. ")|r"
  else s = s .. GREY .. "  (" .. src .. ")|r" end
  return s
end

-- Remember a price and fire a price alert if one is set.
local function record(id, price, count)
  local db = RG.db
  local prev = db.prices[id]
  db.prices[id] = { price = price, t = time(), n = count, none = price == nil or nil }
  if price and db.alerts and db.alerts[id] and price <= db.alerts[id] then
    local _, link = RG.ItemInfo(id)
    RG.Print(GREEN .. "Price alert:|r " .. (link or id) .. " is listed for " .. money(price) .. " (your target " .. money(db.alerts[id]) .. ").")
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN or 5274) end
  end
  if prev == nil or prev.price ~= price then if RG.RefreshUI then RG.RefreshUI() end end
end

-- ---------------------------------------------------------------------------
-- Modern Auction House (C_AuctionHouse)
-- ---------------------------------------------------------------------------
local queue, scanning, pending = {}, false, nil
local ticker

local function nextQuery()
  if #queue == 0 then
    scanning = false; pending = nil
    if ticker then ticker:Cancel(); ticker = nil end
    RG.Print("Auction House prices updated.")
    if RG.RefreshUI then RG.RefreshUI() end
    return
  end
  if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then return end
  local id = table.remove(queue, 1)
  local name = RG.ItemInfo(id)
  if not name then RG.RequestItem(id); queue[#queue + 1] = id; return end
  pending = id
  local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
  C_AuctionHouse.SendBrowseQuery({ searchString = '"' .. name .. '"', sorts = sorts, filters = {}, itemClassFilters = {} })
  -- If nothing comes back, call it "none listed".
  C_Timer.After(2.5, function() if pending == id then record(id, nil, 0); pending = nil end end)
end

function RG.ScanAH()
  if not (C_AuctionHouse and C_AuctionHouse.SendBrowseQuery) then
    if RG.LegacyScan then return RG.LegacyScan() end
    RG.Print("Open the Auction House first."); return
  end
  if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then RG.Print("Open the Auction House first, then /rg scan."); return end
  if scanning then return end
  queue = RG.TrackedIDs()
  if #queue == 0 then return end
  scanning = true
  RG.Print("Checking prices for " .. #queue .. " items...")
  ticker = C_Timer.NewTicker(1.2, function() if not pending then nextQuery() end end)
end

local function readBrowse()
  local results = C_AuctionHouse.GetBrowseResults and C_AuctionHouse.GetBrowseResults()
  if not results then return end
  local found = {}
  for _, r in ipairs(results) do
    local id = r.itemKey and r.itemKey.itemID
    if id and isTracked(id) and r.minPrice and r.minPrice > 0 then
      if not found[id] or r.minPrice < found[id].p then found[id] = { p = r.minPrice, n = r.totalQuantity } end
    end
  end
  for id, x in pairs(found) do record(id, x.p, x.n) end
  if pending and found[pending] then pending = nil
  elseif pending and C_AuctionHouse.HasFullBrowseResults and C_AuctionHouse.HasFullBrowseResults() then record(pending, nil, 0); pending = nil end
end

-- ---------------------------------------------------------------------------
-- Older-style Auction House (in case the client uses the Classic AH)
-- ---------------------------------------------------------------------------
local legacyQueue, legacyPending = {}, nil
function RG.LegacyScan()
  if not (QueryAuctionItems and AuctionFrame and AuctionFrame:IsShown()) then RG.Print("Open the Auction House first."); return end
  legacyQueue = RG.TrackedIDs()
  RG.Print("Checking prices for " .. #legacyQueue .. " items...")
  local t
  t = C_Timer.NewTicker(1.0, function()
    if legacyPending then return end
    if #legacyQueue == 0 then t:Cancel(); RG.Print("Auction House prices updated."); return end
    local canQuery = CanSendAuctionQuery and CanSendAuctionQuery()
    if not canQuery then return end
    local id = table.remove(legacyQueue, 1)
    local name = RG.ItemInfo(id)
    if not name then return end
    legacyPending = id
    QueryAuctionItems(name, nil, nil, 0, nil, nil, false, true)
  end)
end
local function readLegacy()
  if not legacyPending then return end
  local best, count = nil, 0
  local n = GetNumAuctionItems("list")
  for i = 1, n do
    local _, _, stack, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
    if itemID == legacyPending and buyout and buyout > 0 then
      local per = buyout / math.max(1, stack or 1)
      count = count + 1
      if not best or per < best then best = per end
    end
  end
  record(legacyPending, best and math.floor(best) or nil, count)
  legacyPending = nil
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_ITEM_LIST_UPDATE" }) do
  pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event)
  if event == "AUCTION_HOUSE_SHOW" then
    if RG.db.autoScan ~= false then C_Timer.After(1.5, RG.ScanAH) end
  elseif event == "AUCTION_HOUSE_CLOSED" then
    queue = {}; legacyQueue = {}; pending = nil; legacyPending = nil
    if ticker then ticker:Cancel(); ticker = nil end
    scanning = false
  elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
    readBrowse()
  elseif event == "AUCTION_ITEM_LIST_UPDATE" then
    readLegacy()
  end
end)

-- /rg alert [item] [gold]: tell me when it's listed at or under that price.
local base = SlashCmdList.RETGEAR
SlashCmdList.RETGEAR = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.*)$")
  if cmd and cmd:lower() == "alert" then
    local id = tonumber(rest:match("item:(%d+)") or rest:match("^(%d+)"))
    local gold = tonumber(rest:match("([%d%.]+)%s*g?%s*$"))
    if id and gold and gold ~= id then
      RG.db.alerts = RG.db.alerts or {}
      RG.db.alerts[id] = math.floor(gold * 10000); RG.db.tracked[id] = true
      RG.Print("Alert set: " .. (select(2, RG.ItemInfo(id)) or id) .. " at " .. money(RG.db.alerts[id]) .. " or less.")
    else
      RG.Print("Usage: /rg alert [shift-click item] 25   (alert when it's 25 gold or less)")
    end
    return
  elseif cmd and cmd:lower() == "autoscan" then
    RG.db.autoScan = RG.db.autoScan == false
    RG.Print("Automatic scan when you open the AH " .. (RG.db.autoScan and "on." or "off."))
    return
  end
  return base(msg)
end
