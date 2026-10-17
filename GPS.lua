-- Waypath+ GPS extras: live Questie data, dungeon entrances, and a /wp gpscheck report of which map
-- and quest data this game client offers. Everything here is optional and guarded: if an API is
-- missing, the rest of the add-on works as before.
local _, RG = ...

local function questieModule(name)
  local L = _G.QuestieLoader
  if not (L and L.ImportModule) then return nil end
  local ok, m = pcall(L.ImportModule, L, name)
  if ok then return m end
end

-- Where Questie says a quest is started or handed in: { uiMapID, x (0-100), y (0-100), name } or nil.
-- Only used when our own data and the game itself have no answer.
function RG.QuestieWaypoint(questId, which)
  local DB, Zone = questieModule("QuestieDB"), questieModule("ZoneDB")
  if not (DB and DB.GetQuest and Zone and Zone.GetUiMapIdByAreaId) then return nil end
  local ok, wp = pcall(function()
    local q = DB.GetQuest(questId)
    local by = q and (which == "start" and q.startedBy or q.finishedBy)
    local npcs = by and by[1]
    if not npcs then return nil end
    for _, npcId in ipairs(npcs) do
      local npc = DB.GetNPC and DB.GetNPC(npcId)
      if npc and npc.spawns then
        for area, list in pairs(npc.spawns) do
          local map = Zone.GetUiMapIdByAreaId(area)
          local s = list and list[1]
          if map and s and s[1] and s[2] and s[1] >= 0 then return { map, s[1], s[2], npc.name or ("NPC " .. npcId) } end
        end
      end
    end
  end)
  if ok then return wp end
end

-- A dungeon's door on the outside map: the arrow leads there when the target is inside the dungeon.
local entCache = {}
function RG.DungeonEntrance(uiMapID)
  if not (uiMapID and C_Map and C_Map.GetMapInfo and C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap) then return nil end
  if entCache[uiMapID] ~= nil then return entCache[uiMapID] or nil end
  local res = false
  local ok = pcall(function()
    local info = C_Map.GetMapInfo(uiMapID)
    local dungeon = Enum and Enum.UIMapType and Enum.UIMapType.Dungeon or 4
    if not (info and info.mapType == dungeon and info.parentMapID and info.parentMapID > 0) then return end
    local list = C_EncounterJournal.GetDungeonEntrancesForMap(info.parentMapID)
    for _, e in ipairs(list or {}) do
      if e.name and info.name and (e.name == info.name or e.name:find(info.name, 1, true) or info.name:find(e.name, 1, true)) and e.position then
        res = { map = info.parentMapID, x = e.position.x, y = e.position.y, name = e.name }
        return
      end
    end
  end)
  entCache[uiMapID] = res
  return res or nil
end

local function has(path)
  local v = _G
  for part in path:gmatch("[^%.]+") do v = type(v) == "table" and v[part] or nil end
  return v ~= nil
end
function RG.GPSCheck()
  local P = RG.Print
  local function line(ok, label, extra) P((ok and RG.COLORS.GREEN .. "yes|r  " or RG.COLORS.RED .. "no|r   ") .. label .. (extra and ("  " .. RG.COLORS.GREY .. extra .. "|r") or "")) end
  P("Waypath+ GPS data this client offers:")
  line(has("C_QuestLog.GetNextWaypoint"), "Game's next leg of a quest")
  line(has("C_QuestLog.GetQuestsOnMap"), "Quest POIs on the map")
  line(has("C_QuestLine.GetAvailableQuestLines"), "Quest lines available on the map")
  line(has("C_TaxiMap.GetAllTaxiNodes"), "Flight path nodes")
  line(has("C_EncounterJournal.GetDungeonEntrancesForMap"), "Dungeon entrances")
  line(has("C_AreaPoiInfo.GetAreaPOIForMap"), "Map points of interest")
  line(has("C_Map.GetMapLinksForMap"), "Zone exits")
  line(has("C_VignetteInfo.GetVignettes"), "Rares and treasures nearby")
  line(has("C_Navigation.GetDistance"), "Game's own waypoint navigation")
  line(_G.QuestieLoader ~= nil, "Questie (live data)", RG.QuestieWaypoint and questieModule("QuestieDB") and "database found" or nil)
  line(_G.TomTom ~= nil, "TomTom or our stand-in")
  line(RG.SPFInstalled and RG.SPFInstalled(), "Shortest Path Forever")
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if map then
    if has("C_Map.GetMapLinksForMap") then local ok, l = pcall(C_Map.GetMapLinksForMap, map); P("Zone exits on this map: " .. ((ok and type(l) == "table") and #l or "?")) end
    if has("C_EncounterJournal.GetDungeonEntrancesForMap") then local ok, l = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, map); P("Dungeon entrances on this map: " .. ((ok and type(l) == "table") and #l or "?")) end
    if has("C_AreaPoiInfo.GetAreaPOIForMap") then local ok, l = pcall(C_AreaPoiInfo.GetAreaPOIForMap, map); P("Points of interest on this map: " .. ((ok and type(l) == "table") and #l or "?")) end
  end
  P("Trail: " .. (RG.TrailSize and RG.TrailSize() or 0) .. " learned points.")
end
