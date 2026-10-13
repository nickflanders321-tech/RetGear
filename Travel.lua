-- RetGear travel tips: the quickest way from where you are to where the guide
-- sends you next, using your hearthstone, the flight paths you know, Horde
-- zeppelins, the Booty Bay boat and running across zone borders.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY
table.insert(RG.OPTIONS, { key = "travelTips", label = "Travel tips when the guide sends me to another zone", default = true })

-- Horde (and neutral) flight masters by zone.
local FP = {
  ["Tirisfal Glades"] = "Undercity", ["Undercity"] = "Undercity", ["Silverpine Forest"] = "The Sepulcher", ["Hillsbrad Foothills"] = "Tarren Mill",
  ["Arathi Highlands"] = "Hammerfall", ["The Hinterlands"] = "Revantusk Village", ["Badlands"] = "Kargath", ["Swamp of Sorrows"] = "Stonard",
  ["Stranglethorn Vale"] = "Grom'gol", ["Searing Gorge"] = "Thorium Point", ["Burning Steppes"] = "Flame Crest", ["Eastern Plaguelands"] = "Light's Hope",
  ["Durotar"] = "Orgrimmar", ["Orgrimmar"] = "Orgrimmar", ["The Barrens"] = "Crossroads", ["Mulgore"] = "Thunder Bluff", ["Thunder Bluff"] = "Thunder Bluff",
  ["Stonetalon Mountains"] = "Sun Rock Retreat", ["Ashenvale"] = "Splintertree Post", ["Thousand Needles"] = "Freewind Post", ["Desolace"] = "Shadowprey Village",
  ["Dustwallow Marsh"] = "Brackenwall Village", ["Tanaris"] = "Gadgetzan", ["Feralas"] = "Camp Mojache", ["Azshara"] = "Valormok",
  ["Felwood"] = "Bloodvenom Post", ["Winterspring"] = "Everlook", ["Un'Goro Crater"] = "Marshal's Refuge", ["Silithus"] = "Cenarion Hold", ["Moonglade"] = "Moonglade",
}
-- Inn towns (hearthstone locations) -> zone
local INN_TOWN = { ["Brill"] = "Tirisfal Glades", ["Undercity"] = "Undercity", ["The Sepulcher"] = "Silverpine Forest", ["Tarren Mill"] = "Hillsbrad Foothills",
  ["Hammerfall"] = "Arathi Highlands", ["Revantusk Village"] = "The Hinterlands", ["Kargath"] = "Badlands", ["Stonard"] = "Swamp of Sorrows",
  ["Grom'gol Base Camp"] = "Stranglethorn Vale", ["Booty Bay"] = "Stranglethorn Vale", ["Orgrimmar"] = "Orgrimmar", ["Razor Hill"] = "Durotar",
  ["The Crossroads"] = "The Barrens", ["Camp Taurajo"] = "The Barrens", ["Ratchet"] = "The Barrens", ["Thunder Bluff"] = "Thunder Bluff",
  ["Bloodhoof Village"] = "Mulgore", ["Sun Rock Retreat"] = "Stonetalon Mountains", ["Splintertree Post"] = "Ashenvale", ["Freewind Post"] = "Thousand Needles",
  ["Shadowprey Village"] = "Desolace", ["Brackenwall Village"] = "Dustwallow Marsh", ["Gadgetzan"] = "Tanaris", ["Camp Mojache"] = "Feralas",
  ["Everlook"] = "Winterspring", ["Light's Hope Chapel"] = "Eastern Plaguelands", ["Thorium Point"] = "Searing Gorge", ["Cenarion Hold"] = "Silithus",
  ["Marshal's Refuge"] = "Un'Goro Crater", ["Bloodvenom Post"] = "Felwood", ["Valormok"] = "Azshara" }
local EK = { ["Tirisfal Glades"] = 1, ["Undercity"] = 1, ["Silverpine Forest"] = 1, ["Hillsbrad Foothills"] = 1, ["Alterac Mountains"] = 1, ["Arathi Highlands"] = 1,
  ["The Hinterlands"] = 1, ["Western Plaguelands"] = 1, ["Eastern Plaguelands"] = 1, ["Wetlands"] = 1, ["Loch Modan"] = 1, ["Dun Morogh"] = 1, ["Badlands"] = 1,
  ["Searing Gorge"] = 1, ["Burning Steppes"] = 1, ["Redridge Mountains"] = 1, ["Elwynn Forest"] = 1, ["Westfall"] = 1, ["Duskwood"] = 1,
  ["Stranglethorn Vale"] = 1, ["Deadwind Pass"] = 1, ["Swamp of Sorrows"] = 1, ["Blasted Lands"] = 1 }
local function continent(z) if EK[z] then return "EK" end return "K" end

-- Zones you can walk between.
local BORDERS = {
  { "Tirisfal Glades", "Silverpine Forest" }, { "Tirisfal Glades", "Western Plaguelands" }, { "Tirisfal Glades", "Undercity", 2 },
  { "Silverpine Forest", "Hillsbrad Foothills" }, { "Hillsbrad Foothills", "Alterac Mountains" }, { "Hillsbrad Foothills", "Arathi Highlands" },
  { "Hillsbrad Foothills", "The Hinterlands" }, { "Alterac Mountains", "Western Plaguelands" }, { "Western Plaguelands", "Eastern Plaguelands" },
  { "Arathi Highlands", "Wetlands" }, { "Wetlands", "Loch Modan" }, { "Wetlands", "Dun Morogh" }, { "Loch Modan", "Badlands" },
  { "Badlands", "Searing Gorge" }, { "Searing Gorge", "Burning Steppes" }, { "Burning Steppes", "Redridge Mountains" },
  { "Redridge Mountains", "Duskwood" }, { "Redridge Mountains", "Swamp of Sorrows" }, { "Duskwood", "Stranglethorn Vale" }, { "Duskwood", "Deadwind Pass" },
  { "Deadwind Pass", "Swamp of Sorrows" }, { "Swamp of Sorrows", "Blasted Lands" }, { "Duskwood", "Westfall" }, { "Elwynn Forest", "Westfall" },
  { "Durotar", "Orgrimmar", 2 }, { "Durotar", "The Barrens" }, { "The Barrens", "Mulgore" }, { "Mulgore", "Thunder Bluff", 2 },
  { "The Barrens", "Stonetalon Mountains" }, { "The Barrens", "Ashenvale" }, { "The Barrens", "Thousand Needles" }, { "The Barrens", "Dustwallow Marsh" },
  { "Stonetalon Mountains", "Ashenvale" }, { "Stonetalon Mountains", "Desolace" }, { "Desolace", "Feralas" }, { "Feralas", "Thousand Needles" },
  { "Thousand Needles", "Tanaris" }, { "Tanaris", "Un'Goro Crater" }, { "Un'Goro Crater", "Silithus" }, { "Ashenvale", "Felwood" },
  { "Ashenvale", "Azshara" }, { "Ashenvale", "Darkshore" }, { "Felwood", "Winterspring" }, { "Felwood", "Moonglade" }, { "Winterspring", "Moonglade" },
}
-- Zeppelins and the boat: { from zone, to zone, text }
local RIDES = {
  { "Tirisfal Glades", "Durotar", "Zeppelin from the tower outside Undercity to Orgrimmar" },
  { "Durotar", "Tirisfal Glades", "Zeppelin from the tower outside Orgrimmar to Undercity" },
  { "Tirisfal Glades", "Stranglethorn Vale", "Zeppelin from the tower outside Undercity to Grom'gol" },
  { "Stranglethorn Vale", "Tirisfal Glades", "Zeppelin from Grom'gol to Undercity" },
  { "Durotar", "Stranglethorn Vale", "Zeppelin from the tower outside Orgrimmar to Grom'gol" },
  { "Stranglethorn Vale", "Durotar", "Zeppelin from Grom'gol to Orgrimmar" },
  { "The Barrens", "Stranglethorn Vale", "Boat from Ratchet to Booty Bay" },
  { "Stranglethorn Vale", "The Barrens", "Boat from Booty Bay to Ratchet" },
}
-- Dungeons and combined route names -> the zone you travel to.
local DESTINATION = {
  ["Ragefire Chasm"] = "Orgrimmar", ["Ruins of Lordaeron"] = "Tirisfal Glades", ["Excavation Site: Wetlands"] = "Wetlands", ["Wailing Caverns"] = "The Barrens", ["Shadowfang Keep"] = "Silverpine Forest", ["Blackfathom Deeps"] = "Ashenvale",
  ["Razorfen Kraul"] = "The Barrens", ["Razorfen Downs"] = "The Barrens", ["Scarlet Monastery"] = "Tirisfal Glades", ["Uldaman"] = "Badlands",
  ["Zul'Farrak"] = "Tanaris", ["Maraudon"] = "Desolace", ["Blackrock Depths"] = "Searing Gorge", ["Gnomeregan"] = "Dun Morogh",
  ["The Deadmines"] = "Westfall", ["Sunken Temple"] = "Swamp of Sorrows", ["Dire Maul"] = "Feralas",
  ["Western & Eastern Plaguelands"] = "Western Plaguelands", ["Stratholme, Scholomance, Dire Maul, LBRS/UBRS"] = "Burning Steppes",
}
function RG.TravelZone(name)
  if not name then return nil end
  if DESTINATION[name] then return DESTINATION[name] end
  if FP[name] or EK[name] then return name end
  for z in pairs(FP) do if name:find(z, 1, true) then return z end end
  return name
end

local edges
local function buildEdges()
  edges = {}
  local function add(a, b, cost, how, text) edges[a] = edges[a] or {}; table.insert(edges[a], { to = b, cost = cost, how = how, text = text }) end
  for _, b in ipairs(BORDERS) do add(b[1], b[2], b[3] or 10, "walk"); add(b[2], b[1], b[3] or 10, "walk") end
  for _, r in ipairs(RIDES) do add(r[1], r[2], 7, "ride", r[3]) end
end
local function knows(z)
  local f = FP[z]
  if not f then return false end
  local k = RG.KnowsFP and RG.KnowsFP(f)
  return k, f
end
local function hearthReady()
  if not GetItemCooldown then return false end
  local ok, start, dur = pcall(GetItemCooldown, 6948)
  if not ok or RG.IsSecret(start) then return false end
  return (start or 0) == 0 or (dur or 0) <= 1.5
end

-- Returns the legs { text } from your zone to `target`, or nil when you're already there.
function RG.TravelPlan(target)
  target = RG.TravelZone(target)
  local here = GetRealZoneText and GetRealZoneText() or ""
  if not target or target == "" or here == "" or target == here then return nil end
  if not edges then buildEdges() end
  -- Dijkstra over zones; flying is an extra edge between any two known flight paths on a continent
  local dist, prev, done = { [here] = 0 }, {}, {}
  local starts = {}
  local bind = GetBindLocation and GetBindLocation() or nil
  local bindZone
  if bind and bind ~= "" then
    bindZone = INN_TOWN[bind]
    if not bindZone then for z, f in pairs(FP) do if bind:find(f, 1, true) or bind == z then bindZone = z end end end
  end
  if bindZone and bindZone ~= here and hearthReady() then dist[bindZone] = 2; prev[bindZone] = { from = here, how = "hearth", text = "Hearthstone to " .. bind } end
  local function relax(z, d, from, how, text)
    if not dist[z] or d < dist[z] then dist[z] = d; prev[z] = { from = from, how = how, text = text } end
  end
  for _ = 1, 80 do
    local cur, best
    for z, d in pairs(dist) do if not done[z] and (not best or d < best) then cur, best = z, d end end
    if not cur or cur == target then break end
    done[cur] = true
    for _, e in ipairs(edges[cur] or {}) do relax(e.to, best + e.cost, cur, e.how, e.text) end
    local k1, f1 = knows(cur)
    if k1 ~= false and f1 then
      for z2, f2 in pairs(FP) do
        if z2 ~= cur and f2 ~= f1 and continent(z2) == continent(cur) then
          local k2 = knows(z2)
          if k2 ~= false then relax(z2, best + 4 + ((k1 == nil or k2 == nil) and 8 or 0), cur, "fly", "Fly from " .. f1 .. " to " .. f2 .. ((k1 == nil or k2 == nil) and " (if you have both flight paths)" or "")) end
        end
      end
    end
  end
  if not prev[target] and target ~= here then return nil end
  -- walk back
  local legs, z = {}, target
  for _ = 1, 30 do
    local p = prev[z]
    if not p then break end
    table.insert(legs, 1, { how = p.how, text = p.text or ("Run from " .. p.from .. " into " .. z), to = z })
    z = p.from
    if z == here then break end
  end
  -- merge runs through several zones into one line
  local out = {}
  for _, l in ipairs(legs) do
    local last = out[#out]
    if l.how == "walk" and last and last.how == "walk" then last.text = last.text .. " and on into " .. l.to
    else out[#out + 1] = { how = l.how, text = l.text, to = l.to } end
  end
  -- a flight path you haven't learned at the destination: mention it
  local kd, fd = knows(target)
  if kd == false and fd then out[#out + 1] = { how = "tip", text = "Grab the " .. fd .. " flight path when you arrive" } end
  return out, target
end

-- One line for the tracker: "Zeppelin ... > Fly ... > Run ..."
function RG.TravelSummary(target)
  if not RG.Opt("travelTips") then return nil end
  local legs, to = RG.TravelPlan(target)
  if not legs or #legs == 0 then return nil end
  local parts = {}
  for _, l in ipairs(legs) do parts[#parts + 1] = (l.how == "tip" and GREY or "") .. l.text .. (l.how == "tip" and "|r" or "") end
  return table.concat(parts, GOLD .. "  >  |r"), to, legs
end

-- ---------------------------------------------------------------------------
-- Leveling efficiency reminders
-- ---------------------------------------------------------------------------
table.insert(RG.OPTIONS, { key = "efficiency", label = "Efficiency tips: no-XP quests, batch turn-ins, rested XP", default = true })
local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  if (RG.IsAlt and RG.IsAlt()) or not RG.Opt("efficiency") or not RG.MyQuests then return out end
  local lvl = UnitLevel("player")
  if lvl >= 60 then return out end
  local grey, ready, readyZones, red = 0, 0, {}, 0
  for _, q in ipairs(RG.MyQuests()) do
    local c = RG.QuestColor(q.level)
    if q.complete then
      ready = ready + 1
      local z = q.zone or "?"; readyZones[z] = (readyZones[z] or 0) + 1
    elseif c == "|cff808080" then grey = grey + 1
    elseif c == "|cffff1a1a" and not q.group then red = red + 1 end
  end
  local openLog = function() if ToggleQuestLog then ToggleQuestLog() end end
  -- turn-ins: three or more waiting means a trip back is worth it now
  if ready >= 3 then
    local bestZ, bestN = nil, 0
    for z, c in pairs(readyZones) do if c > bestN then bestZ, bestN = z, c end end
    out[#out + 1] = { GREEN .. ready .. " quests ready to turn in|r" .. GREY .. ": hand them in" .. (bestZ and bestZ ~= "?" and (" (" .. bestN .. " in " .. bestZ .. ")") or "") .. " before you head out|r", openLog, 4 }
  end
  if grey >= 1 then
    out[#out + 1] = { GOLD .. grey .. " grey quest" .. (grey > 1 and "s" or "") .. " in your log|r" .. GREY .. ": almost no XP. Turn in if you're passing, otherwise abandon|r", openLog, 6 }
  end
  if red >= 2 then
    out[#out + 1] = { GOLD .. red .. " red quests|r" .. GREY .. ": 5+ levels above you. Leave them for later or bring a group|r", openLog, 7 }
  end
  -- rested XP: log out at an inn or a campfire
  if GetXPExhaustion and not GetXPExhaustion() and IsResting and not IsResting() and UnitXP("player") > 0 then
    -- (only a hint when the session is long; shown as a low-priority line)
    out[#out + 1] = { GREY .. "No rested XP: log out in an inn or by your campfire to earn it|r", nil, 9 }
  end
  return out
end
