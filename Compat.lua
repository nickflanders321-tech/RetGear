-- Waypath+ game-update check. Blizzard patches WoW Forever often, and a patch can
-- rename or remove a function an add-on relies on. The first login on a new game
-- build checks every game function Waypath+ needs; if one is gone it says which
-- features are affected (instead of failing quietly) and notes it in /wp errors
-- for a bug report. /wp check runs it any time.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY

-- feature = { label, { "Api.Path", "Alternative|Other.Alternative", ... } }
-- Every entry must exist; "a|b" means either one is enough.
local NEEDS = {
  { "Quest tracker and route", { "C_QuestLog.GetNumQuestLogEntries", "C_QuestLog.GetInfo", "C_QuestLog.IsComplete", "C_QuestLog.GetQuestObjectives", "C_QuestLog.IsQuestFlaggedCompleted" } },
  { "Arrow, map pins and distances", { "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_Map.GetWorldPosFromMapPos", "C_Map.SetUserWaypoint", "UiMapPoint.CreateFromCoordinates" } },
  { "Gear scores and upgrades", { "C_Item.GetItemInfoInstant|GetItemInfoInstant", "C_Item.GetItemInfo|GetItemInfo", "GetInventoryItemLink", "C_TooltipInfo.GetHyperlink|C_Item.GetItemStats|GetItemStats" } },
  { "Bags (sorting, junk, upgrade arrows)", { "C_Container.GetContainerNumSlots|GetContainerNumSlots", "C_Container.GetContainerItemInfo|GetContainerItemInfo" } },
  { "Auction House prices", { "C_AuctionHouse.ReplicateItems|C_AuctionHouse.SendBrowseQuery|GetNumAuctionItems" } },
  { "Professions", { "GetProfessions|GetNumSkillLines", "GetProfessionInfo|GetSkillLineInfo" } },
  { "Fishing", { "UnitChannelInfo", "IsFishingLoot", "GetLootSlotInfo" } },
}

local function resolve(path)
  local v = _G
  for part in path:gmatch("[^%.]+") do
    if type(v) ~= "table" then return nil end
    local ok, x = pcall(function() return v[part] end)
    if not ok then return nil end
    v = x
  end
  return v
end
local function present(alts)
  for p in alts:gmatch("[^|]+") do if resolve(p) ~= nil then return true end end
  return false
end

-- Returns the list of { feature, missing = { api, ... } } that are affected.
function RG.CompatCheck()
  local out = {}
  for _, f in ipairs(NEEDS) do
    local missing = {}
    for _, api in ipairs(f[2]) do if not present(api) then missing[#missing + 1] = api end end
    if #missing > 0 then out[#out + 1] = { feature = f[1], missing = missing } end
  end
  return out
end

local function build()
  if not GetBuildInfo then return nil end
  local version, b = GetBuildInfo()
  return tostring(version or "?") .. "." .. tostring(b or "?")
end

local function report(quietIfFine)
  local list = RG.CompatCheck()
  local b = build() or "?"
  if #list == 0 then
    if not quietIfFine then RG.Print(GREEN .. "Everything Waypath+ needs is there|r" .. GREY .. " (game build " .. b .. ").|r") end
    return list
  end
  RG.Print(GOLD .. "The game was updated (build " .. b .. ") and changed something Waypath+ uses.|r")
  for _, x in ipairs(list) do
    DEFAULT_CHAT_FRAME:AddMessage("   " .. GOLD .. "•|r " .. x.feature .. GREY .. " may not work: " .. table.concat(x.missing, ", ") .. " is gone|r")
    if RG.RecordError then pcall(RG.RecordError, "Game build " .. b .. ": " .. x.feature .. " needs " .. table.concat(x.missing, ", ") .. ", which this build no longer has") end
  end
  DEFAULT_CHAT_FRAME:AddMessage("   " .. GREY .. "Everything else keeps working. A fixed Waypath+ usually follows within hours; /wp errors has the details for a bug report.|r")
  return list
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  C_Timer.After(5, function()
    local root = RG.root or WaypathDB
    if not root then return end
    local b = build()
    if b and root.lastBuild ~= b then
      local first = root.lastBuild == nil
      root.lastBuild = b
      report(true)
      if not first and RG.Print then RG.Print(GREY .. "Game updated to build " .. b .. ". Waypath+ checked itself against it.|r") end
    end
  end)
end)

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  if cmd and cmd:lower() == "check" then report(false) return end
  return base(msg)
end
