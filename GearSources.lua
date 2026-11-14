-- Waypath+ gear sources: every place an upgrade can come from, in one list the Gear tab, the gear guide and the
-- panel beside the Character window all read, so they always agree.
--   * the gear lists (Classes/<Class>Gear.lua): quest rewards, dungeon drops and chests, vendors, reputation
--     quartermasters, rare mobs, crafted pieces and Bind on Equip world drops
--   * what you already have: gear in your bags and your bank
--   * the Auction House: every piece of gear the last full scan saw, random enchants ("of the Bear") included,
--     with its price
--   * crafts: what your own recipes make, and what your other characters' recipes make (if it can be traded)
local _, RG = ...
local GOLD, GREEN, GREY, WHITE = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY, "|cffffffff"
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant or function() end
local DAY = 86400
local AH_FRESH = 3 * DAY   -- listings older than this are forgotten (they've sold or expired by now)

-- where an item goes, in the gear lists' slot names
local LOC_GUIDE = {
  INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder", INVTYPE_CLOAK = "Back", INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest",
  INVTYPE_WRIST = "Wrist", INVTYPE_HAND = "Hands", INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_FINGER = "Ring",
  INVTYPE_TRINKET = "Trinket", INVTYPE_2HWEAPON = "2H", INVTYPE_WEAPON = "Main Hand", INVTYPE_WEAPONMAINHAND = "Main Hand",
  INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_SHIELD = "Off Hand", INVTYPE_HOLDABLE = "Off Hand", INVTYPE_RANGED = "Ranged",
  INVTYPE_RANGEDRIGHT = "Ranged", INVTYPE_THROWN = "Ranged", INVTYPE_RELIC = "Ranged",
}
function RG.GuideSlotOfLink(link)
  local _, _, _, loc = GetItemInfoInstant(link)
  local gs = loc and LOC_GUIDE[loc]
  -- two weapons: an off-hand-only weapon is on the one-handed list too
  if loc == "INVTYPE_WEAPONOFFHAND" and RG.WEAPON_MODEL == "DW" then gs = "Main Hand" end
  return gs, loc
end
RG.LOC_GUIDE = LOC_GUIDE

local function idOf(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end
local function secret(v) return RG.IsSecret and RG.IsSecret(v) end
-- gear worth looking at: armour or a weapon that goes in a slot the lists know, that you can wear
local function wearable(link)
  if type(link) ~= "string" or secret(link) then return nil end
  local id, _, _, loc, _, classID = GetItemInfoInstant(link)
  if not id or (classID ~= 2 and classID ~= 4) or not LOC_GUIDE[loc] then return nil end
  if RG.IsFishingPole and RG.IsFishingPole(link) then return nil end
  if RG.CanUse and not RG.CanUse(link) then return nil end
  return id, loc
end
-- the level you can wear it at (nil while the game is still loading the item)
local function reqLevel(link, id)
  local name, _, _, _, minLevel = GetItemInfo(link)
  if not name then RG.RequestItem(id); return nil end
  return minLevel or 1
end
local function quality(link)
  local q = select(3, GetItemInfo(link))
  return q
end

-- ---------------------------------------------------------------------------
-- Your bags and bank
-- ---------------------------------------------------------------------------
local function numSlots(bag) local C = C_Container; local f = (C and C.GetContainerNumSlots) or _G.GetContainerNumSlots; return f and f(bag) or 0 end
local function itemLink(bag, slot) local C = C_Container; local f = (C and C.GetContainerItemLink) or _G.GetContainerItemLink; return f and f(bag, slot) end
local BANK_BAGS = { -1, 5, 6, 7, 8, 9, 10, 11 }
local function readBags(bags)
  local out = {}
  for _, bag in ipairs(bags) do
    local okN, n = pcall(numSlots, bag)
    for slot = 1, (okN and type(n) == "number" and n or 0) do
      local ok, l = pcall(itemLink, bag, slot)
      if ok and l and wearable(l) then out[#out + 1] = l end
    end
  end
  return out
end
local bankOpen = false
local function readBank() if bankOpen and RG.db then RG.db.bankGear = readBags(BANK_BAGS) end end

-- ---------------------------------------------------------------------------
-- Recipes you and your other characters know (read from the profession windows: RG.db.recipeBook)
-- ---------------------------------------------------------------------------
-- does this character know the recipe that makes item id for prof? nil = we haven't seen that profession's window
function RG.KnowsCraft(prof, id)
  local book = RG.db and RG.db.recipeBook and RG.db.recipeBook[prof]
  if not book or not next(book) then return nil end
  for _, r in pairs(book) do if r.i == id then return true end end
  return false
end
local function charName(key) return (type(key) == "string" and key:match("^(.-)%-")) or key end
local function myKey() return (UnitName("player") or "?") .. "-" .. ((GetRealmName and GetRealmName()) or "") end
-- what the materials cost on the Auction House (nil when a price is missing)
local function matsCost(r)
  if not (r and RG.Price) then return nil end
  local total = 0
  for _, re in ipairs(r) do
    local p = RG.Price(re[1])
    if not p then
      -- vendor-sold materials (thread, dyes, flux) have no AH price: count them as free rather than give up
      if not (RG.MAT_VENDORS and RG.MAT_VENDORS[re[1]]) then return nil end
    else total = total + p * (re[2] or 1) end
  end
  return math.floor(total + 0.5)
end

-- ---------------------------------------------------------------------------
-- The Auction House: gear seen in the last full scan (Auction.lua hands every gear auction to RG.NoteAHGear)
-- ---------------------------------------------------------------------------
-- RG.db.ahGear[key] = { l = item string, p = cheapest buyout, n = how many listed, t = when }   (shared by the account)
local pendingAH
function RG.NoteAHGear(list, complete)
  if not RG.db or type(list) ~= "table" then return end
  local now = time()
  local store = RG.db.ahGear or {}
  -- a full scan replaces what we knew: anything it didn't see has sold or expired
  if complete then store = {} end
  for key, e in pairs(list) do store[key] = { l = e.l, p = e.p, n = e.n, t = now } end
  for key, e in pairs(store) do if now - (e.t or 0) > AH_FRESH then store[key] = nil end end
  RG.db.ahGear = store
  if RG.GearSourcesChanged then RG.GearSourcesChanged() end
end
-- the item string with the parts the game needs to rebuild the random enchant, nothing else
function RG.GearItemString(link)
  if type(link) ~= "string" then return nil end
  local s = link:match("(item:[%-%d:]+)")
  if not s then return nil end
  -- keep id, enchant, the 4 gem fields and the suffix; drop the unique id and anything after
  local parts = {}
  for p in (s .. ":"):gmatch("([^:]*):") do parts[#parts + 1] = p end
  local keep = {}
  for i = 1, math.min(8, #parts) do keep[i] = parts[i] end
  return table.concat(keep, ":")
end

-- ---------------------------------------------------------------------------
-- The candidate list
-- ---------------------------------------------------------------------------
-- Every entry looks like a gear list entry: { id, slot, lvl, how, src, zone, ... }; the live ones also carry
-- live = "bags" | "bank" | "ah" | "craft" | "altcraft", link (their own, random enchant included), price.
local cache, cacheT, loading = nil, 0, 0
function RG.GearSourcesChanged() cache = nil; if RG.GearStatusInvalidate then RG.GearStatusInvalidate() end end

local function liveEntry(link, how, src, zone, live, extra)
  local id = idOf(link)
  local gs = RG.GuideSlotOfLink(link)
  if not (id and gs) then return nil end
  local lvl = reqLevel(link, id)
  if not lvl then loading = loading + 1; return nil end
  local e = { id = id, link = link, slot = gs, lvl = math.max(1, lvl), how = how, src = src, zone = zone or "", live = live }
  if extra then for k, v in pairs(extra) do e[k] = v end end
  return e
end

local function build()
  local out, seen = {}, {}
  loading = 0
  local lvl = UnitLevel("player") or 1
  -- 1. the gear lists (their own picks and the best of each kind of source)
  for _, list in ipairs({ RG.GUIDE or {}, RG.GUIDE_ALT or {} }) do
    for _, g in ipairs(list) do
      if g.id and not g.tip and not seen[g.id] and RG.GearShown(g) then out[#out + 1] = g; seen[g.id] = true end
    end
  end
  -- 2. what you carry and what's in your bank (only the copy the game would put on: one entry per item string)
  local mine = {}
  for _, l in ipairs(readBags({ 0, 1, 2, 3, 4 })) do
    local key = RG.GearItemString(l) or l
    if not mine[key] then
      mine[key] = true
      local e = liveEntry(l, "Bags", "In your bags", "", "bags")
      if e then out[#out + 1] = e end
    end
  end
  for _, l in ipairs(RG.db and RG.db.bankGear or {}) do
    local key = RG.GearItemString(l) or l
    if not mine[key] and RG.ItemCount(idOf(l) or 0, true) > RG.ItemCount(idOf(l) or 0, false) then
      mine[key] = true
      local e = liveEntry(l, "Bags", "In your bank", "", "bank")
      if e then out[#out + 1] = e end
    end
  end
  -- 3. crafts: your recipes, and your other characters' (if what they make can be traded)
  local me = myKey()
  local root = RG.root
  for key, prof in pairs((root and root.profiles) or {}) do
    if type(prof) == "table" and type(prof.recipeBook) == "table" and (key == me or (root.chars and root.chars[key])) then
      local own = key == me
      for pname, book in pairs(prof.recipeBook) do
        for _, r in pairs(book) do
          local id = r.i
          if id and not (own and seen[id] and RG.KnowsCraft(pname, id)) then
            local _, l, _, _, _, _, _, _, _, _, _, _, _, bind = GetItemInfo(id)
            if l and wearable(l) and (own or bind ~= 1) then
              local cost = matsCost(r.r)
              local e = liveEntry(l, "Craft", own and ("You can make it  ·  " .. pname) or ("Your " .. charName(key) .. " can make it  ·  " .. pname),
                cost and ("materials about " .. (RG.Money and RG.Money(cost) or (math.floor(cost / 10000) .. "g"))) or "", own and "craft" or "altcraft",
                { prof = own and nil or pname, price = cost, crafter = not own and charName(key) or nil })
              if e then
                -- the list's own entry for it says the same thing: keep the one with the recipe's details
                if seen[id] and own then e = nil end
                if e then out[#out + 1] = e; seen[id] = true end
              end
            elseif not l then RG.RequestItem(id) end
          end
        end
      end
    end
  end
  -- 4. the Auction House: listings from the last full scan, cheapest first for each variant
  local now = time()
  for key, a in pairs(RG.db and RG.db.ahGear or {}) do
    if type(a) == "table" and a.l and now - (a.t or 0) <= AH_FRESH then
      local id = idOf(a.l)
      local plain = id and not (RG.ItemSuffix and RG.ItemSuffix(a.l))
      -- (a plain piece already on the lists: the list entry shows the price; random-enchant ones are their own item)
      if id and not (plain and seen[id]) and wearable(a.l) then
        local e = liveEntry(a.l, "AH", "Auction House", (a.n and a.n > 1) and (a.n .. " listed") or "1 listed", "ah", { price = a.p, seenAt = a.t })
        if e and e.lvl <= lvl + 10 then out[#out + 1] = e end
      end
    end
  end
  return out
end

-- (rebuilt at most every few seconds, and whenever your bags, recipes or the Auction House scan change)
function RG.GearCandidates()
  local now = GetTime and GetTime() or 0
  if cache and now - cacheT < 15 then return cache, loading end
  local ok, res = pcall(build)
  if not ok then
    if RG.RecordError then RG.RecordError("GearCandidates: " .. tostring(res)) end
    res = {}
    for _, list in ipairs({ RG.GUIDE or {}, RG.GUIDE_ALT or {} }) do for _, g in ipairs(list) do if g.id and not g.tip then res[#res + 1] = g end end end
  end
  cache, cacheT = res, now
  return cache, loading
end

-- is this entry something you have, or can go and get, now? (level, profession skill, a quest you can take)
function RG.GearNow(g, lvl)
  lvl = lvl or UnitLevel("player") or 1
  if (g.lvl or 0) > lvl then return false end
  if g.live then return true end
  return RG.GearGettable(g)
end

-- The source group a list entry falls in (the Gear tab's "best from each source" view)
local GROUP = { Quest = "Quest", Dungeon = "Dungeon", Chest = "Dungeon", Crafted = "Crafted", Craft = "Crafted", BoE = "Auction House", AH = "Auction House",
  Bags = "Your bags", Vendor = "Vendor", Reputation = "Reputation", ["Rare mob"] = "Rare mob", Drop = "Rare mob" }
RG.SOURCE_GROUPS = { "Your bags", "Quest", "Dungeon", "Crafted", "Auction House", "Vendor", "Reputation", "Rare mob", "Other" }
function RG.GearGroupOf(g) return GROUP[g.how] or "Other" end

-- A short "where from" line for any entry (the panel and the lists use it)
function RG.GearSourceText(g)
  local t = g.src or ""
  if g.zone and g.zone ~= "" then t = t .. ", " .. g.zone end
  return t
end
-- its price, if it's bought: the Auction House listing, the list entry's Auction House price, or the materials
function RG.GearPriceText(g)
  local money = RG.Money or function(c) return math.floor(c / 10000) .. "g" end
  if g.live == "ah" and g.price then
    local age = g.seenAt and (time() - g.seenAt) or 0
    return money(g.price) .. (age > 6 * 3600 and (GREY .. "  (" .. math.floor(age / 3600) .. "h ago)|r") or "")
  end
  if (g.live == "craft" or g.live == "altcraft") and g.price then return GREY .. "materials |r" .. money(g.price) end
  if g.ah and not g.live and RG.Price then
    local p = RG.Price(g.id)
    if p then return money(p) end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Events: bags, bank, profession windows, level and equipment
-- ---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "TRADE_SKILL_SHOW",
  "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_CLOSE", "CRAFT_SHOW", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do pcall(ev.RegisterEvent, ev, e) end
local infoTimer
ev:SetScript("OnEvent", function(_, event)
  if not RG.db then return end
  if event == "BANKFRAME_OPENED" then bankOpen = true; pcall(readBank)
  elseif event == "BANKFRAME_CLOSED" then pcall(readBank); bankOpen = false
  elseif event == "PLAYERBANKSLOTS_CHANGED" or (event == "BAG_UPDATE_DELAYED" and bankOpen) then pcall(readBank)
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    -- items still loading: rebuild once things settle, not on every item
    if loading == 0 or infoTimer then return end
    infoTimer = true
    C_Timer.After(1.5, function() infoTimer = nil; RG.GearSourcesChanged(); if RG.RefreshUI then RG.RefreshUI() end end)
    return
  end
  if event == "PLAYER_EQUIPMENT_CHANGED" then if RG.GearStatusInvalidate then RG.GearStatusInvalidate() end return end
  RG.GearSourcesChanged()
end)
