-- Items in the simulated world (run.lua --play): bags, equipped gear, the client's item cache, quest rewards, quest
-- items, item tooltips and a vendor. Item facts come from items.lua (LibItemDB's Forever tables).
--
-- Quest rewards: the repo has no table of them, so each quest offers the gear the class gear lists (RG.CLASS_GEAR and
-- RG.CLASS_GEAR_A, every class) name as its reward. That is gear some class would want, which is what the add-on's
-- reward picking has to choose between; quests with no such gear give no item.
local Inv = {}

local BAG_SIZES = { [0] = 16, 10, 10, 10, 10 }   -- a backpack and four 10-slot bags
local EQUIP = { INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
  INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 }, INVTYPE_TABARD = { 19 } }
Inv.EQUIP = EQUIP
local SLOT_NAMES = { HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5, WaistSlot = 6, LegsSlot = 7, FeetSlot = 8,
  WristSlot = 9, HandsSlot = 10, Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13, Trinket1Slot = 14, BackSlot = 15,
  MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18, TabardSlot = 19 }

local W, G, Wd, I, S, me
local bags, equip = {}, {}          -- bags[bag][slot] = { id, count }; equip[slot] = id
local cached = {}                   -- item ids the client has the data for (true), or has asked the server about ("pending")
local rewards = {}                  -- questID -> { itemID, ... }
local stats = { received = 0, rewards = 0, questItems = 0, equipped = 0, sold = 0, soldByAddon = 0, bagFull = 0, pickedByAddon = 0, pickedByBot = 0, offered = 0 }
Inv.stats, Inv.bags, Inv.equip = stats, bags, equip

local function fire(ev, ...) W.fire(ev, ...) end
local function isMe(u) return u == "player" end

-- ---------------------------------------------------------------------------
-- The item cache: like the game, an item's full data (GetItemInfo) arrives a moment after it's first asked for.
-- Your own items (bags, equipped) are always known.
-- ---------------------------------------------------------------------------
local function request(id)
  if cached[id] then return end
  cached[id] = "pending"
  G.C_Timer.After(0.1, function()
    cached[id] = true
    fire("GET_ITEM_INFO_RECEIVED", id, true)
    fire("ITEM_DATA_LOAD_RESULT", id, true)
  end)
end
local function known(id) return cached[id] == true end

local function itemInfo(x)
  local id = I.id(x)
  local it = id and I.get(id)
  if not it then return nil end
  if not known(id) then request(id) return nil end
  return it.name, it.link, it.quality, it.ilvl, it.req, it.className, "", (it.loc ~= "" and 1 or 20), it.loc, 134400, it.sell,
    it.classID, it.subID, 1, 0, nil, false
end
local function itemInfoInstant(x)
  local id = I.id(x)
  local it = id and I.get(id)
  if not it then return nil end
  return id, it.className, "", it.loc, 134400, it.classID, it.subID
end

-- ---------------------------------------------------------------------------
-- Bags and equipment
-- ---------------------------------------------------------------------------
local function free()
  local n = 0
  for b = 0, 4 do for s = 1, BAG_SIZES[b] do if not bags[b][s] then n = n + 1 end end end
  return n
end
-- put `count` of item `id` in the bags; false when they're full
function Inv.add(id, count, how)
  local it = I.get(id)
  if not it then return false end
  count = count or 1
  cached[id] = true
  local stack = it.loc == "" and 20 or 1
  for b = 0, 4 do
    for s = 1, BAG_SIZES[b] do
      local e = bags[b][s]
      if e and e.id == id and e.count < stack then
        local add = math.min(count, stack - e.count); e.count = e.count + add; count = count - add
        fire("BAG_UPDATE", b)
      end
      if count == 0 then break end
    end
    if count == 0 then break end
  end
  for b = 0, 4 do
    for s = 1, BAG_SIZES[b] do
      if count > 0 and not bags[b][s] then
        local add = math.min(count, stack)
        bags[b][s] = { id = id, count = add }; count = count - add
        fire("BAG_UPDATE", b)
      end
    end
  end
  if count > 0 then stats.bagFull = stats.bagFull + 1; fire("UI_ERROR_MESSAGE", 3, "Inventory is full.") end
  stats.received = stats.received + 1
  fire("CHAT_MSG_LOOT", "You receive " .. (how == "loot" and "loot" or "item") .. ": " .. it.link .. ".", "", "", "", me.name, "", 0, 0, "", 0, 1, G.UnitGUID("player"))
  fire("BAG_UPDATE_DELAYED")
  return count == 0
end
function Inv.remove(id, count)
  count = count or math.huge
  for b = 0, 4 do
    for s = 1, BAG_SIZES[b] do
      local e = bags[b][s]
      if e and e.id == id and count > 0 then
        local take = math.min(count, e.count); e.count = e.count - take; count = count - take
        if e.count <= 0 then bags[b][s] = nil end
        fire("BAG_UPDATE", b)
      end
    end
  end
  fire("BAG_UPDATE_DELAYED")
end
local function count(id)
  local n = 0
  for b = 0, 4 do for s = 1, BAG_SIZES[b] do local e = bags[b][s]; if e and e.id == id then n = n + e.count end end end
  return n
end
local function find(id)
  for b = 0, 4 do for s = 1, BAG_SIZES[b] do local e = bags[b][s]; if e and e.id == id then return b, s end end end
end
function Inv.bagItems()
  local t = {}
  for b = 0, 4 do for s = 1, BAG_SIZES[b] do local e = bags[b][s]; if e then t[#t + 1] = { bag = b, slot = s, id = e.id, count = e.count } end end end
  return t
end

-- Equip the item in bag b, slot s (into `slot`, or the first fitting one). Returns true, or false and why.
function Inv.equipFrom(b, s, slot)
  local e = bags[b] and bags[b][s]
  if not e then return false, "nothing there" end
  local it = I.get(e.id)
  local slots = it and EQUIP[it.loc]
  if not slots then return false, "can't be equipped" end
  if it.req > me.level then fire("UI_ERROR_MESSAGE", 2, "You must reach level " .. it.req .. " to use that item."); return false, "needs level " .. it.req end
  if slot then
    local ok = false
    for _, x in ipairs(slots) do if x == slot then ok = true end end
    if not ok then return false, "doesn't go in slot " .. slot end
  else
    slot = slots[1]
    for _, x in ipairs(slots) do if not equip[x] then slot = x break end end
  end
  bags[b][s] = nil
  local old = equip[slot]
  equip[slot] = e.id
  if old then bags[b][s] = { id = old, count = 1 } end
  -- a two-hander takes both hands; an off-hand item takes the place of a two-hander
  if it.loc == "INVTYPE_2HWEAPON" and equip[17] then local off = equip[17]; equip[17] = nil; Inv.add(off, 1); fire("PLAYER_EQUIPMENT_CHANGED", 17, true) end
  if slot == 17 and equip[16] then
    local main = I.get(equip[16])
    if main and main.loc == "INVTYPE_2HWEAPON" then local m = equip[16]; equip[16] = nil; Inv.add(m, 1); fire("PLAYER_EQUIPMENT_CHANGED", 16, true) end
  end
  stats.equipped = stats.equipped + 1
  fire("PLAYER_EQUIPMENT_CHANGED", slot, old ~= nil)
  fire("UNIT_INVENTORY_CHANGED", "player")
  fire("BAG_UPDATE", b); fire("BAG_UPDATE_DELAYED")
  return true, slot, old
end

-- ---------------------------------------------------------------------------
-- A vendor: while it's open, using an item in the bags sells it
-- ---------------------------------------------------------------------------
local merchant = false
local selling = "add-on"
local function sell(b, s)
  local e = bags[b][s]
  if not e then return end
  local it = I.get(e.id)
  bags[b][s] = nil
  S.money = S.money + (it and it.sell or 0) * e.count
  stats.sold = stats.sold + 1
  if selling == "add-on" then stats.soldByAddon = stats.soldByAddon + 1 end
  fire("BAG_UPDATE", b); fire("PLAYER_MONEY"); fire("BAG_UPDATE_DELAYED")
end
-- Open a vendor, let the add-on do what it does there (sell junk...), then `botSell(item)` decides what else goes.
function Inv.visitVendor(botSell)
  merchant, selling = true, "add-on"
  G.MerchantFrame:Show()
  W.context = "MERCHANT_SHOW"
  fire("MERCHANT_SHOW")
  W.step(2, 10)
  selling = "bot"
  for _, x in ipairs(Inv.bagItems()) do if botSell(x) then sell(x.bag, x.slot) end end
  W.context = "MERCHANT_CLOSED"
  fire("MERCHANT_CLOSED")
  G.MerchantFrame:Hide()
  merchant = false
end

-- ---------------------------------------------------------------------------
-- The game's functions
-- ---------------------------------------------------------------------------
function Inv.install(w, wd, items)
  W, G, Wd, I = w, w.G, wd, items
  S, me = Wd.state, w.me
  for b = 0, 4 do bags[b] = {} end
  local A = W.apis
  G.GetItemInfo, G.GetItemInfoInstant = itemInfo, itemInfoInstant
  A.C_Item.GetItemInfo, A.C_Item.GetItemInfoInstant = itemInfo, itemInfoInstant
  A.C_Item.RequestLoadItemDataByID = function(x) local id = I.id(x); if id then request(id) end end
  A.C_Item.IsItemDataCachedByID = function(x) local id = I.id(x); return id and known(id) or false end
  A.C_Item.GetItemNameByID = function(x) local id = I.id(x); local it = id and known(id) and I.get(id); return it and it.name end
  A.C_Item.GetItemQualityByID = function(x) local id = I.id(x); local it = id and I.get(id); return it and it.quality end
  A.C_Item.GetItemCount = function(x) local id = I.id(x); return id and count(id) or 0 end
  G.GetItemCount = A.C_Item.GetItemCount
  local function itemStats(link) local id = I.id(link); if id and known(id) then return I.stats(id) end end
  G.GetItemStats = itemStats
  A.C_Item.GetItemStats = itemStats
  local function tip(link)
    local id = I.id(link)
    if not (id and known(id)) then if id then request(id) end return { lines = {} } end
    return { type = 0, id = id, hyperlink = I.get(id).link, lines = I.tooltipLines(id) or {} }
  end
  local TI = A.C_TooltipInfo
  TI.GetHyperlink = tip
  TI.GetBagItem = function(b, s) local e = bags[b] and bags[b][s]; return e and tip(e.id) or nil end
  TI.GetInventoryItem = function(u, slot) return isMe(u) and equip[slot] and tip(equip[slot]) or nil end
  -- tooltips on screen (GameTooltip:SetHyperlink, :SetBagItem, :SetInventoryItem): wow.lua asks these
  W.itemTooltip = function(link)
    local id = I.id(link)
    if not id then return nil end
    local it = I.get(id)
    if not it then return nil end
    request(id)
    return it.name, it.link, id, I.tooltipLines(id) or {}
  end
  W.bagItemLink = function(b, s) local e = bags[b] and bags[b][s]; return e and I.get(e.id) and I.get(e.id).link end
  W.inventoryItemLink = function(u, slot) local id = isMe(u) and equip[slot]; return id and I.get(id) and I.get(id).link end
  -- equipment
  G.GetInventoryItemLink = function(u, slot) return W.inventoryItemLink(u, slot) end
  G.GetInventoryItemID = function(u, slot) return isMe(u) and equip[slot] or nil end
  G.GetInventoryItemTexture = function(u, slot) return isMe(u) and equip[slot] and 134400 or nil end
  G.GetInventoryItemQuality = function(u, slot) local id = isMe(u) and equip[slot]; return id and I.get(id).quality or nil end
  G.GetInventoryItemCount = function(u, slot) return isMe(u) and equip[slot] and 1 or 0 end
  G.GetInventorySlotInfo = function(name) local s = SLOT_NAMES[name]; if s then return s, 0 end end
  G.EquipItemByName = function(x, slot)
    local id = I.id(x)
    local b, s = id and find(id)
    if b then Inv.equipFrom(b, s, tonumber(slot)) end
  end
  -- bags
  local C = A.C_Container
  local function numSlots(b) return BAG_SIZES[b] or 0 end
  local function numFree(b) local n = 0; for s = 1, numSlots(b) do if not bags[b][s] then n = n + 1 end end return n, 0 end
  local function containerInfo(b, s)
    local e = bags[b] and bags[b][s]
    local it = e and I.get(e.id)
    if not it then return nil end
    return { iconFileID = 134400, stackCount = e.count, isLocked = false, quality = it.quality, isReadable = false, hasLoot = false,
      hyperlink = it.link, isFiltered = false, hasNoValue = (it.sell or 0) == 0, itemID = e.id, isBound = it.classID == 2 or it.classID == 4 }
  end
  C.GetContainerNumSlots, C.GetContainerNumFreeSlots, C.GetContainerItemInfo = numSlots, numFree, containerInfo
  C.GetContainerItemLink = function(b, s) return W.bagItemLink(b, s) end
  C.GetContainerItemID = function(b, s) local e = bags[b] and bags[b][s]; return e and e.id end
  C.GetContainerItemQuestInfo = function(b, s)
    local e = bags[b] and bags[b][s]; local it = e and I.get(e.id)
    return { isQuestItem = it and it.classID == 12 or false, questID = nil, isActive = false }
  end
  C.GetItemCooldown = function() return 0, 0, 0 end
  C.GetContainerItemCooldown = function() return 0, 0, 0 end
  C.GetBagName = function(b) return b == 0 and "Backpack" or (BAG_SIZES[b] and "Bag") or nil end
  C.UseContainerItem = function(b, s)
    local e = bags[b] and bags[b][s]
    if not e then return end
    if merchant then sell(b, s) return end
    local it = I.get(e.id)
    if it and EQUIP[it.loc] then Inv.equipFrom(b, s) end
  end
  G.GetContainerNumSlots, G.GetContainerNumFreeSlots = numSlots, numFree
  G.GetContainerItemLink, G.GetContainerItemID, G.UseContainerItem = C.GetContainerItemLink, C.GetContainerItemID, C.UseContainerItem
  G.GetContainerItemInfo = function(b, s)
    local t = containerInfo(b, s)
    if not t then return nil end
    return t.iconFileID, t.stackCount, t.isLocked, t.quality, t.isReadable, t.hasLoot, t.hyperlink, t.isFiltered, t.hasNoValue, t.itemID
  end
  -- the vendor
  G.CanMerchantRepair = function() return merchant end
  G.GetRepairAllCost = function() return 0, false end
  G.GetMerchantNumItems = function() return 0 end
  -- quest rewards (while the reward window is open)
  local function choices() local d = S.dialog; return d and rewards[d.id] or {} end
  G.GetNumQuestChoices = function() return #choices() end
  G.GetNumQuestRewards = function() return 0 end
  G.GetQuestItemLink = function(kind, i)
    if kind ~= "choice" then return nil end
    local id = choices()[i]
    return id and I.get(id) and I.get(id).link
  end
  G.GetQuestItemInfo = function(kind, i)
    if kind ~= "choice" then return nil end
    local id = choices()[i]
    local it = id and I.get(id)
    if not it then return nil end
    return it.name, 134400, 1, it.quality, true, id
  end

  -- the world's hooks
  Wd.hooks.rewardWindow = function(qid)
    for _, id in ipairs(rewards[qid] or {}) do request(id) end   -- the client asks about the rewards it shows
    if #(rewards[qid] or {}) > 0 then stats.offered = stats.offered + 1 end
  end
  Wd.hooks.turnIn = function(qid, choice, e)
    -- the quest's items go; the chosen reward arrives
    for _, o in ipairs(e and e.objs or {}) do if o.itemID then Inv.remove(o.itemID) end end
    local list = rewards[qid] or {}
    local id = list[choice or 1]
    if #list > 1 then
      if S.dialog and S.dialog.botPicked then stats.pickedByBot = stats.pickedByBot + 1 else stats.pickedByAddon = stats.pickedByAddon + 1 end
    end
    if id then stats.rewards = stats.rewards + 1; Inv.add(id, 1, "reward") end
  end
  Wd.hooks.objective = function(e, o, n)
    -- an item objective puts the items in the bags (when the game has an item by that name)
    if o.kind ~= "i" then return end
    local id = o.itemID
    if id == nil then id = I.id(o.label) or false; o.itemID = id end
    if id then stats.questItems = stats.questItems + 1; Inv.add(id, n, "loot") end
  end
  Wd.hooks.pickReward = function(qid)
    -- the add-on didn't pick: take the choice it scores best (its "your call" cases), else the first
    local best, bestD = 1, nil
    for i, id in ipairs(rewards[qid] or {}) do
      local d = Inv.RG and Inv.RG.Compare and Inv.RG.Compare(I.get(id).link)
      if d and (not bestD or d > bestD) then best, bestD = i, d end
    end
    return best
  end
end

function Inv.attach(RG)
  Inv.RG = RG
  local seen = {}
  for _, lists in ipairs({ RG.CLASS_GEAR or {}, RG.CLASS_GEAR_A or {} }) do
    for _, list in pairs(lists) do
      for _, g in ipairs(list) do
        if g.how == "Quest" and g.q and g.id and I.get(g.id) and not seen[g.q .. ":" .. g.id] then
          seen[g.q .. ":" .. g.id] = true
          rewards[g.q] = rewards[g.q] or {}
          table.insert(rewards[g.q], g.id)
        end
      end
    end
  end
  for _, list in pairs(rewards) do table.sort(list) end
end

-- the score of what's equipped, by the add-on's own scoring (RG.Score)
function Inv.gearScore(RG)
  local total, n = 0, 0
  for slot, id in pairs(equip) do
    local it = I.get(id)
    if it then
      n = n + 1
      local ok, s = pcall(RG.Score, it.link, nil, slot)
      if ok and type(s) == "number" then total = total + s end
    end
  end
  return total, n
end

return Inv
