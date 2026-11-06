-- Waypath+ Auction House prices.
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

-- Every item whose price we watch: guide items you can buy, plus /wp track.
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
  if g and g.ah then return true end
  if RG.BagSellSet and RG.Opt("profitWatch") and RG.BagSellSet()[id] then return true end
  if RG.GoldIDs and select(2, RG.GoldIDs())[id] then return true end
  if RG.MAIL_QUESTS then for _, q in ipairs(RG.MAIL_QUESTS) do for _, it in ipairs(q.items) do if it[1] == id then return true end end end end
  return false
end
RG.IsPriceWatched = isTracked

-- What opening the AH checks: tracked items, plus sellable things in your bags
-- and the items from this level's gold tips.
function RG.ScanIDs()
  local ids, seen = RG.TrackedIDs(), {}
  for _, id in ipairs(ids) do seen[id] = true end
  local extra = {}
  if RG.BagSellIDs then for _, id in ipairs(RG.BagSellIDs()) do extra[#extra + 1] = id end end
  if RG.GoldIDs then for _, id in ipairs((RG.GoldIDs())) do extra[#extra + 1] = id end end
  if RG.MailIDs then for _, id in ipairs(RG.MailIDs()) do extra[#extra + 1] = id end end
  for _, id in ipairs(extra) do if not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
  return ids
end

-- Price from other addons, if present.
local function addonPrice(id)
  if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID then
    local ok, p = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "Waypath", id)
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
  if rec and rec.none then return GREY .. "none listed (" .. ageText(rec.t) .. ")" .. (rec.last and ("; last seen " .. money(rec.last)) or "") .. "|r" end
  local s = money(p)
  if src == "scan" then s = s .. GREY .. "  (" .. ageText(rec.t) .. (rec.n and rec.n > 1 and (", " .. rec.n .. " listed") or "") .. ")|r"
  else s = s .. GREY .. "  (" .. src .. ")|r" end
  return s
end

-- Remember a price and fire a price alert if one is set.
local function record(id, price, count)
  local db = RG.db
  local prev = db.prices[id]
  -- "none listed right now" keeps the last price that was seen, so one empty search doesn't erase what we knew
  db.prices[id] = { price = price or (prev and (prev.price or prev.last)), t = time(), n = count, none = price == nil or nil,
    last = price or (prev and (prev.price or prev.last)) or nil }
  if price and db.alerts and db.alerts[id] and price <= db.alerts[id] then
    local _, link = RG.ItemInfo(id)
    RG.Print(GREEN .. "Price alert:|r " .. (link or id) .. " is listed for " .. money(price) .. " (your target " .. money(db.alerts[id]) .. ").")
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN or 5274) end
  end
  if prev == nil or prev.price ~= price then
    if RG.ProfitInvalidate then RG.ProfitInvalidate() end
    if RG.RefreshUI then RG.RefreshUI() end
  end
end

-- ---------------------------------------------------------------------------
-- Scanning
--
-- Fast and out of your way:
--   1. A full scan when the server allows one (once every 15 minutes): one
--      request returns every auction, and Waypath+ reads the prices it needs a
--      chunk per frame. Modern AH: C_AuctionHouse.ReplicateItems (doesn't touch
--      the Browse list at all). Classic AH: QueryAuctionItems "get all".
--   2. Otherwise only items whose price is more than STALE old are looked up,
--      one search each, as fast as the server takes them.
--   3. The moment you search for something yourself, Waypath+ stops its own
--      searches for this visit (your searches still update its prices), so the
--      Auction House is yours. /wp scan or the Scan button finishes the rest.
-- ---------------------------------------------------------------------------
local STALE = 2 * 3600        -- re-check a price after 2 hours
local FULL_COOLDOWN = 15 * 60 -- the server allows a full scan every 15 minutes
local CHUNK = 800             -- auctions read per frame during a full scan

local queue, pending, pendingAt = {}, nil, 0
local mode = nil              -- nil, "full", "items"
local ours = false            -- true while Waypath+ itself sends a query
local yielded = false         -- you searched yourself during this visit
local runner = CreateFrame("Frame")
local wantedSet

local function wanted()
  if wantedSet then return wantedSet end
  wantedSet = {}
  for _, id in ipairs(RG.ScanIDs()) do wantedSet[id] = true end
  -- materials of every profession you have or plan, for the Professions tab's costs
  for name in pairs(RG.Professions and RG.Professions() or {}) do
    local P = RG.PROFESSIONS and RG.PROFESSIONS[name]
    for _, id in ipairs(P and P.mats or {}) do wantedSet[id] = true end
  end
  return wantedSet
end
local function watched(id) return id and (wanted()[id] or isTracked(id)) end

local batch                  -- (the modern AH's current request, below)
local function stop(msg)
  queue, pending, mode, batch = {}, nil, nil, nil
  runner:SetScript("OnUpdate", nil)
  if msg then RG.Print(msg) end
  if RG.RefreshUI then RG.RefreshUI() end
end
RG.StopAHScan = function() stop() end
function RG.AHScanState()
  if mode == "full" then return "reading the full scan" end
  if mode == "items" then return #queue + (pending and 1 or 0) .. " items left" end
  return nil
end

-- Which items still need a price: never seen, or older than STALE.
local function staleIDs()
  local out, now = {}, time()
  for id in pairs(wanted()) do
    local rec = RG.db.prices[id]
    if not rec or now - rec.t > STALE then out[#out + 1] = id end
  end
  table.sort(out)
  return out
end

-- Reading a full scan: lowest buyout per item, a chunk of auctions per frame.
local function readFull(total, getInfo, isModern)
  local best, count = {}, {}
  local i = isModern and 0 or 1
  local last = isModern and total - 1 or total
  mode = "full"
  runner:SetScript("OnUpdate", function()
    local stopAt = math.min(last, i + CHUNK - 1)
    for k = i, stopAt do
      local id, stack, buyout = getInfo(k)
      if id and buyout and buyout > 0 and watched(id) then
        local per = buyout / math.max(1, stack or 1)
        if not best[id] or per < best[id] then best[id] = per end
        count[id] = (count[id] or 0) + 1
      end
    end
    i = stopAt + 1
    if i > last then
      runner:SetScript("OnUpdate", nil)
      local n = 0
      for id in pairs(wanted()) do
        if best[id] then record(id, math.floor(best[id]), count[id]); n = n + 1 else record(id, nil, 0) end
      end
      mode = nil
      RG.Print("Auction House prices updated: " .. n .. " items from a full scan (" .. total .. " auctions).")
      if RG.RefreshUI then RG.RefreshUI() end
    end
  end)
end

-- Which auction house is open decides which way of asking works. WoW Forever has the modern one (AuctionHouseFrame,
-- C_AuctionHouse); the classic one (AuctionFrame, QueryAuctionItems) is still handled for other clients.
local function modernAH()
  if AuctionFrame and AuctionFrame:IsShown() and QueryAuctionItems then return false end
  return C_AuctionHouse and C_AuctionHouse.SearchForItemKeys and C_AuctionHouse.MakeItemKey and true or false
end
local stats = { sent = 0, events = 0, found = 0, none = 0, timeouts = 0, full = 0, fullRead = 0 }
RG.AHStats = stats

-- Modern AH: up to BATCH items in one request, by item id (no name matching, so nothing is missed for a spelling or a
-- similar name), answered as one Browse list. Items that aren't on the list once it's complete are "none listed".
local BATCH = 40
local batchAt, batchTries = 0, 0
local announce = false   -- chat lines only when you asked for the scan
local function sendBatch()
  if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then return end
  if #queue == 0 then stop(announce and "Auction House prices updated." or nil); return end
  local ids, keys = {}, {}
  while #queue > 0 and #ids < BATCH do
    local id = table.remove(queue, 1)
    ids[#ids + 1] = id; keys[#keys + 1] = C_AuctionHouse.MakeItemKey(id)
  end
  batch, batchAt, batchTries = ids, GetTime(), 0
  local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
  ours = true; local ok = pcall(C_AuctionHouse.SearchForItemKeys, keys, sorts); ours = false
  stats.sent = stats.sent + 1
  if not ok then for i = #ids, 1, -1 do table.insert(queue, 1, ids[i]) end; batch = nil end
end

-- Classic AH: one search per item, by name.
local function sendNext()
  local canQuery = CanSendAuctionQuery and CanSendAuctionQuery()
  if not canQuery then return end
  local id = table.remove(queue, 1)
  if not id then stop(announce and "Auction House prices updated." or nil); return end
  local name = RG.ItemInfo(id)
  if not name then RG.RequestItem(id); if #queue > 0 then queue[#queue + 1] = id end; return end
  pending, pendingAt = id, GetTime()
  ours = true; pcall(QueryAuctionItems, name, nil, nil, 0, nil, nil, false, true); ours = false
  stats.sent = stats.sent + 1
end
local function runItems()
  queue = staleIDs()
  if #queue == 0 then if announce then RG.Print("Auction House prices are up to date.") end return end
  mode = "items"
  if announce then RG.Print("Checking " .. #queue .. " price" .. (#queue > 1 and "s" or "") .. ". Search for anything yourself and Waypath+ steps aside.") end
  local modern = modernAH()
  runner:SetScript("OnUpdate", function()
    if modern then
      if batch then
        -- a busy server can take a while: wait up to 15 seconds, ask once more, then leave those prices as they were
        if GetTime() - batchAt > 15 then
          stats.timeouts = stats.timeouts + 1
          if batchTries == 0 then for i = #batch, 1, -1 do table.insert(queue, 1, batch[i]) end; batch = nil; batchTries = 1 else batch = nil end
        end
        return
      end
      sendBatch()
    else
      if pending then
        -- no answer: try that item again later instead of calling it "none listed"
        if GetTime() - pendingAt > 10 then stats.timeouts = stats.timeouts + 1; pending = nil end
        return
      end
      sendNext()
    end
  end)
end

local function ahOpen()
  return (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown())
end

function RG.ScanAH(manual)
  if not ahOpen() then RG.Print("Open the Auction House first, then /wp scan."); return end
  if mode then if manual then RG.Print("Already checking prices (" .. RG.AHScanState() .. ").") end return end
  wantedSet = nil
  announce = manual and true or false
  if manual then yielded = false end
  local now = time()
  local canFull = now - (RG.db.lastFullScan or 0) > FULL_COOLDOWN
  -- 1. full scan
  if canFull and modernAH() and C_AuctionHouse.ReplicateItems then
    stats.full = stats.full + 1
    RG.db.lastFullScan = now
    mode = "full"
    if announce then RG.Print("Full price scan: one request for the whole Auction House (the game allows one every 15 minutes)...") end
    ours = true; pcall(C_AuctionHouse.ReplicateItems); ours = false
    -- if the server never answers, fall back to item searches
    C_Timer.After(20, function() if mode == "full" and not runner:GetScript("OnUpdate") then mode = nil; if ahOpen() then runItems() end end end)
    return
  end
  if canFull and not modernAH() and QueryAuctionItems and CanSendAuctionQuery then
    local canQuery, canAll = CanSendAuctionQuery()
    if canAll then
      RG.db.lastFullScan = now
      mode = "full"
      if announce then RG.Print("Full price scan: one request for the whole Auction House (the game may pause for a moment)...") end
      ours = true; pcall(QueryAuctionItems, "", nil, nil, 0, nil, nil, true, false); ours = false
      return
    end
  end
  -- 2. only what's out of date
  runItems()
end

-- Prices from whatever is on the Browse list (yours or ours).
local function readBrowse()
  local results = C_AuctionHouse.GetBrowseResults and C_AuctionHouse.GetBrowseResults()
  if not results then return end
  local found = {}
  for _, r in ipairs(results) do
    local id = r.itemKey and r.itemKey.itemID
    if id and watched(id) and r.minPrice and r.minPrice > 0 then
      if not found[id] or r.minPrice < found[id].p then found[id] = { p = r.minPrice, n = r.totalQuantity } end
    end
  end
  for id, x in pairs(found) do record(id, x.p, x.n); stats.found = stats.found + 1 end
  stats.events = stats.events + 1
  if batch and (not C_AuctionHouse.HasFullBrowseResults or C_AuctionHouse.HasFullBrowseResults()) then
    -- our batch is answered in full: what isn't on the list has no auctions right now
    local inList = {}
    for _, r in ipairs(results) do local id = r.itemKey and r.itemKey.itemID; if id then inList[id] = true end end
    for _, id in ipairs(batch) do if not inList[id] then record(id, nil, 0); stats.none = stats.none + 1 end end
    batch = nil
  elseif batch and C_AuctionHouse.RequestMoreBrowseResults then
    pcall(C_AuctionHouse.RequestMoreBrowseResults)
  end
end
local function readLegacy()
  if mode == "full" and not runner:GetScript("OnUpdate") then
    local _, total = GetNumAuctionItems("list")
    readFull(total or GetNumAuctionItems("list"), function(i)
      local _, _, stack, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
      return itemID, stack, buyout
    end, false)
    return
  end
  local best, count = {}, {}
  for i = 1, (GetNumAuctionItems("list") or 0) do
    local _, _, stack, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
    if itemID and buyout and buyout > 0 and watched(itemID) then
      local per = buyout / math.max(1, stack or 1)
      if not best[itemID] or per < best[itemID] then best[itemID] = per end
      count[itemID] = (count[itemID] or 0) + 1
    end
  end
  for id, p in pairs(best) do record(id, math.floor(p), count[id]) end
  if pending then
    if not best[pending] then record(pending, nil, 0) end
    pending = nil
  end
end
local function readReplicate()
  if not (C_AuctionHouse and C_AuctionHouse.GetNumReplicateItems) or runner:GetScript("OnUpdate") then return end
  local total = C_AuctionHouse.GetNumReplicateItems() or 0
  stats.fullRead = total
  readFull(total, function(i)
    local _, _, stack, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
    if not itemID and C_AuctionHouse.GetReplicateItemLink then
      -- an item the game hasn't loaded yet has no id in the info, but its link has it
      local link = C_AuctionHouse.GetReplicateItemLink(i)
      itemID = link and tonumber(link:match("item:(%d+)"))
    end
    return itemID, stack, buyout
  end, true)
end

-- You searched yourself: Waypath+ stops its searches for this visit.
local function userSearched()
  if RG.CardsOnly and RG.CardsOnly() then return end
  if ours then return end
  if mode == "items" then
    yielded = true
    stop("Price check paused while you shop (your searches still update prices). /wp scan finishes it.")
  elseif mode == "full" and not (C_AuctionHouse and C_AuctionHouse.ReplicateItems) then
    -- a Classic full scan shares the Browse list with your search: let your search win
    yielded = true
    stop()
  end
end
if hooksecurefunc then
  if C_AuctionHouse then
    for _, fn in ipairs({ "SendBrowseQuery", "SendSearchQuery", "SearchForItemKeys", "SendSellSearchQuery", "SearchForFavorites" }) do
      if C_AuctionHouse[fn] then hooksecurefunc(C_AuctionHouse, fn, userSearched) end
    end
  end
  if QueryAuctionItems then hooksecurefunc("QueryAuctionItems", userSearched) end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_ITEM_LIST_UPDATE", "REPLICATE_ITEM_LIST_UPDATE" }) do
  pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event)
  if event == "AUCTION_HOUSE_SHOW" then
    yielded = false
    if RG.Opt("autoScan") then C_Timer.After(0.5, function() if ahOpen() and not yielded then RG.ScanAH() end end) end
  elseif event == "AUCTION_HOUSE_CLOSED" then
    -- a full scan that's already being read keeps going; searches stop
    if mode == "items" then stop() end
    pending, batch = nil, nil
  elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
    readBrowse()
  elseif event == "AUCTION_ITEM_LIST_UPDATE" then
    readLegacy()
  elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
    if mode == "full" then readReplicate() end
  end
end)

-- /wp alert [item] [gold]: tell me when it's listed at or under that price.
local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.*)$")
  if cmd and cmd:lower() == "alert" then
    local id = tonumber(rest:match("item:(%d+)") or rest:match("^(%d+)"))
    local gold = tonumber(rest:match("([%d%.]+)%s*g?%s*$"))
    if id and gold and gold ~= id then
      RG.db.alerts = RG.db.alerts or {}
      RG.db.alerts[id] = math.floor(gold * 10000); RG.db.tracked[id] = true
      RG.Print("Alert set: " .. (select(2, RG.ItemInfo(id)) or id) .. " at " .. money(RG.db.alerts[id]) .. " or less.")
    else
      RG.Print("Usage: /wp alert [shift-click item] 25   (alert when it's 25 gold or less)")
    end
    return
  elseif cmd and cmd:lower() == "scan" and rest:lower():match("^status") then
    -- what the price scanner did this session, for a bug report
    local st = RG.AHStats or {}
    local n, none, fresh = 0, 0, 0
    for _, r in pairs(RG.db.prices or {}) do n = n + 1; if r.none then none = none + 1 end; if time() - (r.t or 0) < 7200 then fresh = fresh + 1 end end
    RG.Print(string.format("AH scan: %s auction house open; this session %d requests, %d answers, %d prices found, %d none listed, %d timeouts; full scans %d (last read %d auctions, next allowed in %d min). Saved prices: %d (%d from the last 2 hours, %d none listed).",
      (AuctionHouseFrame and AuctionHouseFrame:IsShown()) and "modern" or ((AuctionFrame and AuctionFrame:IsShown()) and "classic" or "no"),
      st.sent or 0, st.events or 0, st.found or 0, st.none or 0, st.timeouts or 0, st.full or 0, st.fullRead or 0,
      math.max(0, math.ceil(((RG.db.lastFullScan or 0) + 15 * 60 - time()) / 60)), n, fresh, none))
    return
  elseif cmd and cmd:lower() == "autoscan" then
    RG.db.autoScan = not RG.Opt("autoScan")
    RG.Print("Automatic scan when you open the AH " .. (RG.db.autoScan and "on." or "off."))
    return
  end
  return base(msg)
end
