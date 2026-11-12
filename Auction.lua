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
  local g, s, cp = math.floor(c / 10000), math.floor((c % 10000) / 100), math.floor(c % 100)
  if g == 0 and s == 0 then return cp .. "c" end
  return (g > 0 and (g .. "g ") or "") .. s .. "s" .. ((g == 0 and cp > 0) and (" " .. cp .. "c") or "")
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
    local ok, p = pcall(TSM_API.GetCustomPriceValue, "dbmarket", "i:" .. id)
    if ok and p then return p, "TSM" end
  end
end

-- ---------------------------------------------------------------------------
-- Market value, the way TradeSkillMaster's AuctionDB describes its own (support.tradeskillmaster.com, "AuctionDB
-- Market Value"; written fresh here, no code borrowed):
--   1. a scan's value: auctions sorted by price; at most the cheapest 30% count, and past the cheapest 15% a jump of
--      20% or more to the next one ends the list; then prices more than 1.5 standard deviations from the average are
--      dropped and the rest averaged.
--   2. each day's scans are averaged into one value for the day.
--   3. the market value weighs the last 14 days, recent days much more (each day back counts 0.75 as much: a
--      half-life of a little over two days).
-- Ours on top: listings under 40% of the middle price are left out first.
-- So one cheap listing or one greedy one doesn't move the price Waypath+ compares against; the cheapest listing
-- right now is still shown next to it.
-- ---------------------------------------------------------------------------
local function scanValue(prices)            -- prices: unit prices, one per auction (or per item in a stack)
  local n = #prices
  if n == 0 then return nil end
  table.sort(prices)
  -- one addition of ours: a listing under 40% of the middle price is a mistake or a bait listing, not the market
  -- (without it a single 10c listing among 1g ones would be the whole value, since the 20% jump cuts right after it)
  local mid = prices[math.floor((n + 1) / 2)]
  local first = 1
  while first < n and prices[first] < mid * 0.4 do first = first + 1 end
  if first > 1 then
    local rest = {}
    for i = first, n do rest[#rest + 1] = prices[i] end
    prices, n = rest, #rest
  end
  local keep = { prices[1] }
  local cap = math.max(1, math.floor(n * 0.30 + 0.5))
  for i = 2, math.min(n, cap) do
    if i > n * 0.15 and prices[i] >= prices[i - 1] * 1.2 then break end
    keep[#keep + 1] = prices[i]
  end
  local sum = 0
  for _, v in ipairs(keep) do sum = sum + v end
  local avg = sum / #keep
  if #keep < 3 then return avg end
  local sq = 0
  for _, v in ipairs(keep) do sq = sq + (v - avg) ^ 2 end
  local sd = math.sqrt(sq / (#keep - 1))
  local s2, c2 = 0, 0
  for _, v in ipairs(keep) do if math.abs(v - avg) <= 1.5 * sd then s2 = s2 + v; c2 = c2 + 1 end end
  return c2 > 0 and s2 / c2 or avg
end
RG.__scanValue = scanValue   -- (tests)
local function dayIndex() return math.floor(time() / 86400) end
local function marketOf(rec)
  if not (rec and rec.d) then return nil end
  local today, num, den = dayIndex(), 0, 0
  for day, v in pairs(rec.d) do
    local age = today - day
    if age >= 0 and age <= 14 and v[2] > 0 then local w = 0.75 ^ age; num = num + w * (v[1] / v[2]); den = den + w end
  end
  return den > 0 and math.floor(num / den + 0.5) or nil
end
RG.MarketValue = function(id) return marketOf(RG.db and RG.db.prices and RG.db.prices[id]) end

function RG.Price(id)
  -- Bind on Pickup and quest items never sell there, whatever another add-on's price list says
  if RG.NeverAuctioned and id and RG.NeverAuctioned(id) then return nil end
  local rec = RG.db.prices[id]
  local mv = marketOf(rec)
  if mv then return mv, "market", rec end
  local ap, src = addonPrice(id)
  -- your own scan wins for a day after it was seen; after that another price add-on's (often fresher) value is used
  if rec and rec.price and (not ap or time() - (rec.seen or rec.t) < 24 * 3600) then return rec.price, "scan", rec end
  if ap then return ap, src end
  if rec then return rec.price, "scan", rec end
end

-- ---------------------------------------------------------------------------
-- What an item really sells for. Learned from TradeSkillMaster's way of looking at it (its own pricing guides; no
-- code borrowed):
--   * a random-enchant piece ("... of the Monkey") is its own item: TSM prices each variant separately, so a weak
--     variant doesn't borrow the price of a good one. Waypath+ now records variants apart and won't guess.
--   * the market value is what things are listed for. To sell you have to be the cheapest, so when the cheapest
--     listing right now is lower than the market value, that's what you'll get.
--   * your own sales count most (TSM's Accounting): what you actually sold an item for in the last 30 days.
--   * an item whose auctions keep coming back unsold isn't worth taking to the AH, whatever the listings say.
-- ---------------------------------------------------------------------------
-- the random-enchant variant in a link (the suffix field of item:id:enchant:gem1:gem2:gem3:gem4:suffix), or nil
local function suffixOf(link)
  if type(link) ~= "string" then return nil end
  local sfx = link:match("item:%-?%d+:%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*:(%-?%d+)")
  sfx = tonumber(sfx)
  return (sfx and sfx ~= 0) and sfx or nil
end
RG.ItemSuffix = suffixOf
local function variantKey(id, sfx) return sfx and (id .. ":" .. sfx) or id end
RG.PriceKey = function(id, link) return variantKey(id, suffixOf(link)) end

local function hist()
  RG.db.ahHistory = RG.db.ahHistory or { sold = {}, expired = {}, mail = {} }
  return RG.db.ahHistory
end
local DAY = 86400
-- your sales of an item in the last 30 days: median price each, how many, the last one
local function mySales(id)
  local h = RG.db and RG.db.ahHistory
  local L = h and h.sold[id]
  if not L then return nil end
  local now, ps, last = time(), {}, 0
  for _, e in ipairs(L) do if now - e[2] <= 30 * DAY then ps[#ps + 1] = e[1]; last = math.max(last, e[2]) end end
  if #ps == 0 then return nil end
  table.sort(ps)
  return ps[math.floor((#ps + 1) / 2)], #ps, last
end
RG.MySales = mySales
-- your auctions of it that came back unsold in the last 14 days, after your last sale
local function myExpired(id, lastSale)
  local h = RG.db and RG.db.ahHistory
  local L = h and h.expired[id]
  if not L then return 0 end
  local now, n = time(), 0
  for _, t in ipairs(L) do if now - t <= 14 * DAY and t > (lastSale or 0) then n = n + 1 end end
  return n
end

-- The price you can expect each, and how it was worked out: { market, cheapest, mine, mineN, slow, variant }
function RG.SellPrice(id, link)
  if not id or (RG.NeverAuctioned and RG.NeverAuctioned(id)) then return nil end
  local sfx = suffixOf(link)
  local why = { variant = sfx }
  local base, src, rec
  if sfx then
    -- a random-enchant piece: only its own variant's price counts
    rec = RG.db.prices[variantKey(id, sfx)]
    if not rec then return nil, why end
    base, src = marketOf(rec) or rec.price, marketOf(rec) and "market" or "scan"
  else
    base, src, rec = RG.Price(id)
  end
  if not base then return nil, why end
  why.market, why.src = base, src
  local p = base
  -- you have to undercut the cheapest one listed now (a price checked within the last two days)
  if rec and rec.price and not rec.none and time() - (rec.t or 0) < 2 * DAY and rec.price < p then
    p = rec.price; why.cheapest = rec.price
  end
  -- what you sold it for yourself lately
  local med, n, last = mySales(id)
  if med and not sfx then
    why.mine, why.mineN = med, n
    p = why.cheapest and math.min(med, why.cheapest) or med
  end
  local exp = myExpired(id, last)
  if exp >= 2 then why.slow = exp end
  return math.floor(p + 0.5), why
end

-- Whether the Auction House has been looked at at all on this realm (lists show one "open the AH" line until then).
function RG.HasPrices() return RG.db and RG.db.prices and next(RG.db.prices) ~= nil or false end
function RG.PriceText(id, link)
  if suffixOf(link) then
    -- a random-enchant piece: its own variant, or nothing
    local sp, why = RG.SellPrice(id, link)
    if not sp then return nil end
    return money(sp) .. GREY .. "  this variant" .. (why.cheapest and " · cheapest now" or "") .. "|r"
  end
  if not isTracked(id) and not RG.db.prices[id] then return nil end
  local p, src, rec = RG.Price(id)
  if not p then return nil end   -- (no price yet: lists show nothing rather than the same reminder on every row)
  -- what you'd really get, when that's less than the market value: the cheapest listing now, or your own sales
  local sp, why = RG.SellPrice(id)
  if sp and why and (sp < p or why.mine or why.slow) then
    local bits = {}
    if why.mine then bits[#bits + 1] = "you sold " .. why.mineN .. " for ~" .. money(why.mine) end
    if why.cheapest then bits[#bits + 1] = "cheapest now " .. money(why.cheapest) end
    bits[#bits + 1] = "market " .. money(p)
    if why.slow then bits[#bits + 1] = "|cffff7f50came back unsold " .. why.slow .. "x|r" .. GREY end
    return money(sp) .. GREY .. "  to sell · " .. table.concat(bits, " · ") .. "|r"
  end
  if src == "market" then
    -- the steady value first, then what the cheapest one costs right now
    local now = rec.none and "none listed now" or (rec.price and ("cheapest " .. money(rec.price) .. (rec.n and rec.n > 1 and (", " .. rec.n .. " listed") or "")) or nil)
    return money(p) .. GREY .. "  market" .. (now and (" · " .. now) or "") .. " · " .. ageText(rec.t) .. "|r"
  end
  -- none listed right now: the last price seen is still the price (that's what it sells for when someone lists it)
  if rec and rec.none and src == "scan" then return money(p) .. GREY .. "  last seen " .. ageText(rec.seen or rec.t) .. " · none listed now|r" end
  local s = money(p)
  if src == "scan" then s = s .. GREY .. "  (" .. ageText(rec.seen or rec.t) .. (rec.n and rec.n > 1 and (", " .. rec.n .. " listed") or "") .. ")|r"
  else s = s .. GREY .. "  (" .. src .. ")|r" end
  return s
end

-- Any other item seen on the AH: its lowest price, when, and how many (no daily history, so it stays small).
-- Kept for good, so a tooltip or list can show the last price you saw for anything.
local function remember(id, price, count, variant)
  local db = RG.db
  local prev = db.prices[id]
  if prev and prev.d and not variant then return end   -- (a watched item: its full record is kept by record())
  if variant and prev and prev.d then prev.price, prev.t, prev.seen, prev.n, prev.last, prev.none = price, time(), time(), count, price, nil return end
  db.prices[id] = { price = price, t = time(), seen = time(), n = count, last = price }
end
-- Remember a price and fire a price alert if one is set.
local function record(id, price, count, value)
  local db = RG.db
  local prev = db.prices[id]
  -- "none listed right now" keeps the last price that was seen, so one empty search doesn't erase what we knew
  -- (seen: when a price was last actually on the AH; t: when it was last checked)
  db.prices[id] = { price = price or (prev and (prev.price or prev.last)), t = time(), n = count, none = price == nil or nil,
    last = price or (prev and (prev.price or prev.last)) or nil, d = prev and prev.d or nil,
    seen = price and time() or (prev and (prev.seen or (prev.price and prev.t))) or nil }
  -- the day's value: a full scan gives the market value of every listing; a single search only knows the cheapest one,
  -- which counts for the day only when nothing better is known yet
  local v = value or price
  if v then
    local rec, today = db.prices[id], dayIndex()
    rec.d = rec.d or {}
    local e = rec.d[today]
    if value then
      if not e or not e[3] then e = { 0, 0, true } end   -- the first full scan of the day replaces cheapest-only values
      e[1], e[2] = e[1] + value, e[2] + 1
    elseif not e then e = { price, 1 } elseif not e[3] then e[1], e[2] = e[1] + price, e[2] + 1 end
    rec.d[today] = e
    for day in pairs(rec.d) do if today - day > 14 then rec.d[day] = nil end end
  end
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
-- progress, for the bar on the Auction House (below)
local prog = { total = 0, start = 0, fullI = 0, fullTotal = 0, doneAt = nil, doneText = nil }
local function finished(text)
  prog.doneAt, prog.doneText = GetTime(), text
  RG.Print(text)
end
local function stop(msg)
  queue, pending, mode, batch = {}, nil, nil, nil
  runner:SetScript("OnUpdate", nil)
  if msg then RG.Print(msg) end
  if RG.RefreshUI then RG.RefreshUI() end
end
RG.StopAHScan = function() stop() end
function RG.AHScanState()
  if mode == "full" then return "reading the full scan" end
  if mode == "items" then return #queue + (pending and 1 or 0) + (batch and #batch or 0) .. " items left" end
  return nil
end
-- How far the scan is: done, total, phase ("wait" = waiting for the server's full-scan answer).
function RG.AHScanProgress()
  if mode == "full" then
    if prog.fullTotal > 0 then return prog.fullI, prog.fullTotal, "read" end
    return 0, 0, "wait"
  elseif mode == "items" then
    local left = #queue + (pending and 1 or 0) + (batch and #batch or 0)
    return math.max(0, prog.total - left), prog.total, "items"
  end
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
local function readFull(total, getInfo, isModern, getLink)
  local best, count, all = {}, {}, {}
  local vBest, vAll, vCount = {}, {}, {}   -- random-enchant variants of watched gear, by "id:suffix"
  local unknown = 0   -- auctions whose item the game hadn't loaded (no id): their items can't be called "none listed"
  local i = isModern and 0 or 1
  local last = isModern and total - 1 or total
  mode = "full"
  prog.fullI, prog.fullTotal = 0, math.max(1, total)
  runner:SetScript("OnUpdate", function()
    local stopAt = math.min(last, i + CHUNK - 1)
    for k = i, stopAt do
      local id, stack, buyout = getInfo(k)
      if not id then unknown = unknown + 1 end
      if id and buyout and buyout > 0 then
        local per = buyout / math.max(1, stack or 1)
        if not best[id] or per < best[id] then best[id] = per end
        count[id] = (count[id] or 0) + 1
        -- watched items: every item counts once in the market value (a stack of 20 is 20 items), up to 400 per item
        if watched(id) then
          local L = all[id]; if not L then L = {}; all[id] = L end
          for _ = 1, math.min(stack or 1, 400 - #L) do L[#L + 1] = per end
          -- gear can come in random-enchant variants: each one priced on its own
          if getLink and (stack or 1) == 1 then
            local _, _, _, _, _, classID = GetItemInfoInstant(id)
            if classID == 2 or classID == 4 then
              local sfx = suffixOf(getLink(k))
              if sfx then
                local key = variantKey(id, sfx)
                if not vBest[key] or per < vBest[key] then vBest[key] = per end
                vCount[key] = (vCount[key] or 0) + 1
                local V = vAll[key]; if not V then V = {}; vAll[key] = V end
                if #V < 100 then V[#V + 1] = per end
              end
            end
          end
        end
      end
    end
    i = stopAt + 1
    prog.fullI = math.min(prog.fullTotal, i - (isModern and 0 or 1))
    if i > last then
      runner:SetScript("OnUpdate", nil)
      local n, w = 0, wanted()
      -- "none listed" only when the scan saw (nearly) every auction; otherwise a missing item keeps its last price
      local complete = total > 0 and unknown <= total * 0.02
      for id in pairs(w) do
        if best[id] then
          local v = scanValue(all[id] or {})
          record(id, math.floor(best[id]), count[id], v and math.floor(v + 0.5)); n = n + 1
        elseif complete then record(id, nil, 0) end
      end
      for key, p in pairs(vBest) do
        local v = scanValue(vAll[key] or {})
        record(key, math.floor(p), vCount[key], v and math.floor(v + 0.5))
      end
      -- and every other item on the AH, so its last price is there next time
      local others = 0
      for id, p in pairs(best) do if not w[id] and not isTracked(id) then remember(id, math.floor(p), count[id]); others = others + 1 end end
      mode = nil; prog.fullTotal = 0
      finished("Auction House scan finished: " .. n .. " price" .. (n == 1 and "" or "s") .. " updated from a full scan (" .. total .. " auctions)" .. (others > 0 and (", and the last price of " .. others .. " other items remembered") or "") .. ".")
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
  if #queue == 0 then local n = prog.total; stop(); finished("Auction House scan finished: " .. n .. " price" .. (n == 1 and "" or "s") .. " checked."); return end
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
  if not id then local n = prog.total; stop(); finished("Auction House scan finished: " .. n .. " price" .. (n == 1 and "" or "s") .. " checked."); return end
  local name = RG.ItemInfo(id)
  if not name then RG.RequestItem(id); if #queue > 0 then queue[#queue + 1] = id end; return end
  pending, pendingAt = id, GetTime()
  ours = true; pcall(QueryAuctionItems, name, nil, nil, 0, nil, nil, false, true); ours = false
  stats.sent = stats.sent + 1
end
local function runItems()
  queue = staleIDs()
  if #queue == 0 then
    prog.doneAt, prog.doneText = GetTime(), "Auction House prices are up to date."
    if announce then RG.Print("Auction House prices are up to date.") end
    return
  end
  mode = "items"
  prog.total, prog.start = #queue, GetTime()
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
  if RG.ShowAHProgress then RG.ShowAHProgress() end
  prog.doneAt = nil
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
    mode = "full"; prog.fullTotal, prog.start = 0, GetTime()
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
      mode = "full"; prog.fullTotal, prog.start = 0, GetTime()
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
    if id and r.minPrice and r.minPrice > 0 then
      if not found[id] or r.minPrice < found[id].p then found[id] = { p = r.minPrice, n = r.totalQuantity } end
      -- each random-enchant variant also gets its own price
      local sfx = r.itemKey.itemSuffix
      if sfx and sfx ~= 0 then remember(variantKey(id, sfx), r.minPrice, r.totalQuantity, true) end
    end
  end
  for id, x in pairs(found) do
    if watched(id) then record(id, x.p, x.n); stats.found = stats.found + 1 else remember(id, x.p, x.n) end
  end
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
    end, false, GetAuctionItemLink and function(i) return GetAuctionItemLink("list", i) end)
    return
  end
  local best, count = {}, {}
  for i = 1, (GetNumAuctionItems("list") or 0) do
    local _, _, stack, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
    if itemID and buyout and buyout > 0 then
      local per = buyout / math.max(1, stack or 1)
      if not best[itemID] or per < best[itemID] then best[itemID] = per end
      count[itemID] = (count[itemID] or 0) + 1
    end
  end
  for id, p in pairs(best) do if watched(id) then record(id, math.floor(p), count[id]) else remember(id, math.floor(p), count[id]) end end
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
  end, true, C_AuctionHouse.GetReplicateItemLink)
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
-- Progress bar on top of the Auction House: what's being scanned, how far along, and when it's finished.
-- (our own frame on UIParent, only anchored to the AH window: the Blizzard frame itself is never touched)
-- ---------------------------------------------------------------------------
local pbar
local function fmtNum(n) n = math.floor(n); return n >= 1000 and string.format("%d,%03d", math.floor(n / 1000), n % 1000) or tostring(n) end
local function ahWindow() return (AuctionHouseFrame and AuctionHouseFrame:IsShown() and AuctionHouseFrame) or (AuctionFrame and AuctionFrame:IsShown() and AuctionFrame) end
local function progressBar()
  if pbar then return pbar end
  local b = CreateFrame("Frame", nil, UIParent)
  b:SetSize(380, 30); b:SetFrameStrata("HIGH"); b:Hide()
  local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.063, 0.11, 0.153, 0.94)
  local edge = b:CreateTexture(nil, "BORDER"); edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1); edge:SetColorTexture(0.847, 0.71, 0.416, 0.55)
  bg:SetDrawLayer("BORDER", 1)
  local track = b:CreateTexture(nil, "ARTWORK"); track:SetPoint("BOTTOMLEFT", 8, 5); track:SetPoint("BOTTOMRIGHT", -8, 5); track:SetHeight(4); track:SetColorTexture(1, 1, 1, 0.08)
  local fill = b:CreateTexture(nil, "ARTWORK", nil, 1); fill:SetPoint("TOPLEFT", track); fill:SetPoint("BOTTOMLEFT", track); fill:SetWidth(1)
  local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pcall(text.SetFont, text, RG.FONTS and RG.FONTS.medium or STANDARD_TEXT_FONT, 11, "")
  text:SetPoint("TOPLEFT", 9, -5); text:SetPoint("TOPRIGHT", -9, -5); text:SetJustifyH("LEFT"); text:SetTextColor(0.94, 0.89, 0.78)
  local right = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pcall(right.SetFont, right, RG.FONTS and RG.FONTS.medium or STANDARD_TEXT_FONT, 11, "")
  right:SetPoint("TOPRIGHT", -9, -5); right:SetJustifyH("RIGHT"); right:SetTextColor(0.62, 0.66, 0.70)
  b.track, b.fill, b.text, b.right = track, fill, text, right
  b:EnableMouse(true)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Waypath+ price scan")
    GameTooltip:AddLine("Waypath+ checks the prices of your gear upgrades and profession materials. Searching for anything yourself pauses it; /wp scan or the Scan prices button finishes it.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local acc = 0
  b:SetScript("OnUpdate", function(self, el)
    acc = acc + el; if acc < 0.15 then return end; acc = 0
    local win = ahWindow()
    if not win then self:Hide(); return end
    local a = RG.ACCENT or { 0.847, 0.71, 0.416 }
    local done, total, phase = RG.AHScanProgress()
    local w = math.max(1, self.track:GetWidth() or 1)
    if phase then
      local frac = total > 0 and done / total or 0
      if phase == "wait" then
        -- the server is putting the full list together: a slow sweep so it's clearly working
        frac = (GetTime() * 0.35) % 1
        self.text:SetText("Scanning the Auction House: waiting for the server...")
        self.right:SetText(math.floor(GetTime() - prog.start) .. "s")
      elseif phase == "read" then
        self.text:SetText("Scanning the Auction House: reading the full list")
        self.right:SetText(fmtNum(done) .. " / " .. fmtNum(total))
      else
        local eta = ""
        local spent = GetTime() - prog.start
        if done >= 5 and spent > 3 then
          local left = (total - done) * spent / done
          eta = left >= 60 and ("  ~" .. math.ceil(left / 60) .. " min left") or ("  ~" .. math.max(1, math.floor(left)) .. "s left")
        end
        self.text:SetText("Checking prices: " .. done .. " / " .. total .. " items")
        self.right:SetText(math.floor(frac * 100 + 0.5) .. "%" .. eta)
      end
      self.fill:SetColorTexture(a[1], a[2], a[3], 0.95)
      self.fill:SetWidth(math.max(1, w * math.min(1, frac)))
      self:SetAlpha(1); self:Show()
    elseif prog.doneAt and GetTime() - prog.doneAt < 25 then
      self.text:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t " .. (prog.doneText or "Auction House scan finished."))
      self.right:SetText("")
      self.fill:SetColorTexture(0.42, 0.78, 0.48, 0.95); self.fill:SetWidth(w)
      local age = GetTime() - prog.doneAt
      self:SetAlpha(age > 22 and math.max(0, (25 - age) / 3) or 1); self:Show()
    else
      self:Hide()
    end
  end)
  pbar = b
  return b
end
local function showProgress()
  if RG.CardsOnly and RG.CardsOnly() then return end
  if RG.Opt and RG.Opt("ahProgress") == false then return end
  local win = ahWindow(); if not win then return end
  local b = progressBar()
  b:ClearAllPoints(); b:SetPoint("BOTTOM", win, "TOP", 0, 6)
  b:Show()
end
RG.ShowAHProgress = showProgress
-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
-- Your sales and the auctions that came back, read from the mailbox (TSM's Accounting does the same): an "Auction
-- successful" mail says what one sold for, an "Auction expired" one that it didn't sell. Each mail counts once.
local function idByName(name)
  if not name or name == "" then return nil end
  local _, link = RG.ItemInfo(name)
  return link and tonumber(link:match("item:(%d+)"))
end
-- "Auction expired: %s" in the game's own language, as a pattern
local function expiredPattern()
  local f = AUCTION_EXPIRED_MAIL_SUBJECT
  if type(f) ~= "string" then return nil end
  local esc = f:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)"):gsub("%%s", "(.+)")
  return "^" .. esc .. "$"
end
local function readMail()
  if not (GetInboxNumItems and GetInboxHeaderInfo) then return end
  local expiredPat = expiredPattern()
  local h, now = hist(), time()
  for i = 1, GetInboxNumItems() do
    local _, _, sender, subject, mailMoney, _, daysLeft = GetInboxHeaderInfo(i)
    if subject and daysLeft then
      -- the same mail always has the same subject, money and expiry day (rounded: the clock moves while you look)
      local key = subject .. "|" .. tostring(mailMoney) .. "|" .. math.floor(now / DAY + daysLeft + 0.5)
      if not h.mail[key] then
        local invoiceType, itemName, _, bid, _, _, _, _, _, _, count
        if GetInboxInvoiceInfo then invoiceType, itemName, _, bid, _, _, _, _, _, _, count = GetInboxInvoiceInfo(i) end
        if invoiceType == "seller" and itemName and bid and bid > 0 then
          local id = idByName(itemName)
          if id then
            h.mail[key] = now
            local L = h.sold[id] or {}; h.sold[id] = L
            L[#L + 1] = { math.floor(bid / math.max(1, count or 1)), now }
            while #L > 20 do table.remove(L, 1) end
          end
        elseif expiredPat and subject:match(expiredPat) then
          local id = idByName(subject:match(expiredPat))
          if id then
            h.mail[key] = now
            local L = h.expired[id] or {}; h.expired[id] = L
            L[#L + 1] = now
            while #L > 20 do table.remove(L, 1) end
          end
        end
      end
    end
  end
  -- forget mails long gone
  for k, t in pairs(h.mail) do if now - t > 40 * DAY then h.mail[k] = nil end end
  if RG.ProfitInvalidate then RG.ProfitInvalidate() end
end
RG.__readAHMail = readMail   -- (tests)

for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_ITEM_LIST_UPDATE", "REPLICATE_ITEM_LIST_UPDATE", "MAIL_INBOX_UPDATE" }) do
  pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event)
  if event == "AUCTION_HOUSE_SHOW" then
    yielded = false
    if RG.Opt("autoScan") then C_Timer.After(0.5, function() if ahOpen() and not yielded then RG.ScanAH() end; showProgress() end) end
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
  elseif event == "MAIL_INBOX_UPDATE" then
    pcall(readMail)
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
