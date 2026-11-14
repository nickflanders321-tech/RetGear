-- Waypath+ Waylaid Crates: hover one and its tooltip shows the cheapest way to fill it from the Auction House.
--   Each crate takes any one of its bundles (Waylaid.lua). For each bundle: what you still need after what you carry
--   (bags and bank), times the cheapest price the Auction House scan last saw (or its market value), cheapest first.
--   The materials of the crates you carry are watched by the price scan, so their prices are there next time.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY

-- the price to buy one now: the cheapest listing last seen, else the market value
local function unitPrice(id)
  if not RG.Price then return nil end
  local p, _, rec = RG.Price(id)
  local now = rec and not rec.none and rec.price
  if now and p then return math.min(now, p) end
  return now or p
end

-- every bundle of a crate, cheapest to finish first: { id, count, name, have, need, each, cost }
function RG.WaylaidOptions(crateId)
  local c = RG.WAYLAID and RG.WAYLAID[crateId]
  if not c then return nil end
  local out = {}
  for _, m in ipairs(c[2]) do
    local have = RG.ItemCount(m[1], true)
    local need = math.max(0, m[2] - have)
    local each = unitPrice(m[1])
    out[#out + 1] = { id = m[1], count = m[2], name = (RG.ItemInfo and RG.ItemInfo(m[1])) or m[3], have = have, need = need, each = each,
      cost = need == 0 and 0 or (each and need * each) or nil }
  end
  table.sort(out, function(a, b)
    if (a.cost ~= nil) ~= (b.cost ~= nil) then return a.cost ~= nil end
    if a.cost and b.cost and a.cost ~= b.cost then return a.cost < b.cost end
    return a.name < b.name
  end)
  return out, c[1]
end

local function onTip(tt, data)
  if not RG.db or (RG.CardsOnly and RG.CardsOnly()) or not RG.WAYLAID then return end
  if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
  local id = data and data.id
  if not id and tt.GetItem then local _, link = tt:GetItem(); id = link and tonumber(link:match("item:(%d+)")) end
  if not id or not RG.WAYLAID[id] then return end
  local opts = RG.WaylaidOptions(id)
  tt:AddLine(" ")
  tt:AddLine((RG.LOGO_INLINE or "") .. GOLD .. "Cheapest way to fill it|r" .. GREY .. "  (any one bundle)|r")
  local shown = 0
  for i, o in ipairs(opts) do
    if shown >= 3 then break end
    shown = shown + 1
    local left = (i == 1 and "|cffffffff" or GREY) .. o.count .. " " .. o.name .. "|r"
    local right
    if o.need == 0 then right = GREEN .. "you have enough|r"
    elseif o.cost then
      right = (i == 1 and "|cffffffff" or GREY) .. RG.Money(o.cost) .. "|r" .. GREY .. "  (" .. (o.have > 0 and ("buy " .. o.need .. ", ") or "") .. RG.Money(o.each) .. " each)|r"
    else right = GREY .. "no price yet|r" end
    tt:AddDoubleLine("  " .. left, right)
  end
  if #opts > 3 then tt:AddLine(GREY .. "  +" .. (#opts - 3) .. " more bundle" .. (#opts - 3 > 1 and "s" or "") .. " cost more|r") end
  local unpriced = false
  for _, o in ipairs(opts) do if not o.cost and o.need > 0 then unpriced = true end end
  if unpriced then tt:AddLine(GREY .. "  Prices come from your Auction House scans: open the Auction House to fill in the rest.|r", 1, 1, 1, true) end
  tt:Show()
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) pcall(onTip, tt, data) end)
elseif GameTooltip and GameTooltip.HookScript then
  GameTooltip:HookScript("OnTooltipSetItem", function(tt) pcall(onTip, tt) end)
end

-- the materials of the crates you carry: the price scan watches them
local watch = {}
local function rescan()
  watch = {}
  for cid, c in pairs(RG.WAYLAID or {}) do
    if RG.ItemCount(cid, true) > 0 then for _, m in ipairs(c[2]) do watch[m[1]] = true end end
  end
end
function RG.WaylaidMatWatched(id) return watch[id] or false end
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN"); ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:SetScript("OnEvent", function() if RG.db then pcall(rescan) end end)
