-- Waypath+ bag sorting: a Sort button on your bags and bank, and /wp sort.
-- Uses the game's own sort when the client has it; otherwise Waypath+ sorts
-- itself, one move at a time: stacks merged, then Hearthstone, quest items,
-- consumables, gear, profession materials, recipes, other, and grey junk last.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
local C = C_Container or {}
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
table.insert(RG.OPTIONS, { key = "sortButton", label = "Sort button on my bags and bank", default = true })

local BAGS = { 0, 1, 2, 3, 4 }
local BANK = { -1, 5, 6, 7, 8, 9, 10 }
local HEARTHSTONE = 6948

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function numSlots(bag) return (C.GetContainerNumSlots and C.GetContainerNumSlots(bag)) or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0 end
local function slotInfo(bag, slot)
  if C.GetContainerItemInfo then
    local i = C.GetContainerItemInfo(bag, slot)
    if i then return i.itemID, i.stackCount or 1, i.isLocked, i.quality, i.hyperlink end
    return nil
  end
  if GetContainerItemInfo then
    local _, count, locked, quality, _, _, link, _, _, id = GetContainerItemInfo(bag, slot)
    return id, count or 1, locked, quality, link
  end
end
local function pickup(bag, slot) if C.PickupContainerItem then C.PickupContainerItem(bag, slot) elseif PickupContainerItem then PickupContainerItem(bag, slot) end end
-- Only general-purpose bags take part (not quivers, ammo or profession bags).
local function generalBag(bag)
  if bag == 0 or bag == -1 then return true end
  local free, kind
  if C.GetContainerNumFreeSlots then free, kind = C.GetContainerNumFreeSlots(bag) elseif GetContainerNumFreeSlots then free, kind = GetContainerNumFreeSlots(bag) end
  return (kind or 0) == 0
end

-- Sort order -----------------------------------------------------------------
local function group(id, quality)
  if id == HEARTHSTONE then return 0 end
  if quality == 0 then return 9 end -- grey junk last
  local _, _, _, equipLoc, _, classID = GetItemInfoInstant(id)
  if classID == 12 then return 1 end                                   -- quest
  if classID == 0 then return 2 end                                    -- food, potions, lures
  if classID == 2 or classID == 4 then                                 -- gear
    if equipLoc and equipLoc ~= "" then return 3 end
  end
  if classID == 7 or classID == 5 then return 4 end                    -- ore, bars, fish, cloth
  if classID == 9 then return 5 end                                    -- recipes
  if classID == 1 or classID == 11 then return 6 end                   -- bags, quivers
  return 7
end
local function itemKey(id, count, quality)
  local name, _, _, ilvl = GetItemInfo(id)
  local _, _, _, _, _, classID, subID = GetItemInfoInstant(id)
  return { id = id, count = count, quality = quality or 1, group = group(id, quality), class = classID or 99, sub = subID or 99,
    ilvl = ilvl or 0, name = name or tostring(id) }
end
local function before(a, b)
  if a.group ~= b.group then return a.group < b.group end
  if a.class ~= b.class then return a.class < b.class end
  if a.sub ~= b.sub then return a.sub < b.sub end
  if a.quality ~= b.quality then return a.quality > b.quality end
  if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
  if a.name ~= b.name then return a.name < b.name end
  if a.id ~= b.id then return a.id < b.id end
  return a.count > b.count
end

-- One step of Waypath+'s own sorter. Returns "busy" (wait), "moved" or "done".
local function anyLocked(slots)
  for _, s in ipairs(slots) do local _, _, locked = slotInfo(s[1], s[2]); if locked then return true end end
  return false
end
local function step(bags)
  if CursorHasItem and CursorHasItem() then return "busy" end
  local slots = {}
  for _, bag in ipairs(bags) do
    if generalBag(bag) then for s = 1, numSlots(bag) do slots[#slots + 1] = { bag, s } end end
  end
  if anyLocked(slots) then return "busy" end
  -- 1. merge partial stacks of the same item
  local partial = {}
  for _, s in ipairs(slots) do
    local id, count = slotInfo(s[1], s[2])
    if id then
      local max = select(8, GetItemInfo(id)) or 1
      if max > 1 and count < max then
        local first = partial[id]
        -- only merge when it all fits, so nothing is left on the cursor
        if first and first[3] + count <= max then pickup(s[1], s[2]); pickup(first[1], first[2]); return "moved" end
        partial[id] = { s[1], s[2], count }
      end
    end
  end
  -- 2. put each slot's item where it belongs
  local items = {}
  for _, s in ipairs(slots) do
    local id, count, _, quality = slotInfo(s[1], s[2])
    if id then
      if not GetItemInfo(id) then return "busy" end -- item data still loading
      local k = itemKey(id, count, quality); k.at = s; items[#items + 1] = k
    end
  end
  local want = {}
  for i, k in ipairs(items) do want[i] = k end
  table.sort(want, before)
  for i, k in ipairs(want) do
    local target = slots[i]
    local id, count = slotInfo(target[1], target[2])
    if id ~= k.id or count ~= k.count then
      -- find this item further along (the first match that isn't already placed)
      for j = i + 1, #slots do
        local jid, jcount = slotInfo(slots[j][1], slots[j][2])
        if jid == k.id and jcount == k.count then
          pickup(slots[j][1], slots[j][2]); pickup(target[1], target[2])
          return "moved"
        end
      end
    end
  end
  return "done"
end

local running
local function runSort(bags, label)
  if running then return end
  if inCombat() then RG.Print("Can't sort bags in combat.") return end
  local moves, waits = 0, 0
  running = C_Timer.NewTicker(0.08, function(t)
    if inCombat() then t:Cancel(); running = nil; RG.Print("Sorting stopped: you entered combat.") return end
    local r = step(bags)
    if r == "moved" then moves = moves + 1; waits = 0
    elseif r == "busy" then waits = waits + 1 end
    if r == "done" or moves > 400 or waits > 60 then
      t:Cancel(); running = nil
      if ClearCursor then ClearCursor() end
      RG.Print(r == "done" and (GREEN .. label .. " sorted.|r") or (GREY .. label .. ": stopped early, click Sort again to finish.|r"))
    end
  end)
end

function RG.SortBags(bank)
  if inCombat() then RG.Print("Can't sort bags in combat.") return end
  if bank then
    if not (BankFrame and BankFrame:IsShown()) then RG.Print("Open your bank first.") return end
    if C.SortBankBags then C.SortBankBags() else runSort(BANK, "Bank") end
  else
    if C.SortBags then C.SortBags() else runSort(BAGS, "Bags") end
  end
  if PlaySound and SOUNDKIT and RG.Opt("sounds") then pcall(PlaySound, SOUNDKIT.IG_BACKPACK_OPEN or 862) end
end

-- Buttons ----------------------------------------------------------------------
local function makeButton(parent, bank)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(22, 22)
  b:SetNormalTexture("Interface\\Icons\\INV_Misc_Bag_10")
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  local t = b:GetNormalTexture(); if t then t:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  local border = b:CreateTexture(nil, "OVERLAY"); border:SetTexture("Interface\\Buttons\\UI-Quickslot2"); border:SetPoint("CENTER"); border:SetSize(36, 36)
  b:SetScript("OnClick", function() RG.SortBags(bank) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(bank and "Sort bank" or "Sort bags")
    GameTooltip:AddLine(bank and "Merges stacks and tidies your bank bags." or "Merges stacks, then: Hearthstone, quest items, food and potions, gear, materials, recipes, and grey junk last.", 1, 1, 1, true)
    GameTooltip:AddLine("/wp sort" .. (bank and " bank" or ""), 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end
local bagBtn, bankBtn
local function place()
  local show = RG.Opt("sortButton")
  -- combined bags (modern UI) or the classic backpack
  local host = (ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() and ContainerFrameCombinedBags) or ContainerFrame1
  if host and show then
    if not bagBtn then bagBtn = makeButton(UIParent, false) end
    bagBtn:SetParent(host); bagBtn:SetFrameLevel((host:GetFrameLevel() or 1) + 10)
    bagBtn:ClearAllPoints(); bagBtn:SetPoint("TOPRIGHT", host, "TOPRIGHT", -12, -30)
    bagBtn:Show()
  elseif bagBtn then bagBtn:Hide() end
  if BankFrame and show then
    if not bankBtn then bankBtn = makeButton(BankFrame, true) end
    bankBtn:SetFrameLevel((BankFrame:GetFrameLevel() or 1) + 10)
    bankBtn:ClearAllPoints(); bankBtn:SetPoint("TOPRIGHT", BankFrame, "TOPRIGHT", -48, -42)
    bankBtn:Show()
  elseif bankBtn then bankBtn:Hide() end
end
RG.PlaceSortButtons = place

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_OPEN", "BANKFRAME_OPENED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    if ContainerFrame1 then ContainerFrame1:HookScript("OnShow", place) end
    if ContainerFrameCombinedBags then ContainerFrameCombinedBags:HookScript("OnShow", place) end
  end
  place()
end)

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.*)$")
  if cmd and cmd:lower() == "sort" then RG.SortBags((rest or ""):lower():find("bank") ~= nil) return end
  return base(msg)
end
