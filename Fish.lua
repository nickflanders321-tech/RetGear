-- RetGear fishing (WoW Forever): where to fish for your skill, ranks, gear,
-- fish to cook, and a live fishing session (skill, lure, catches, zone check).
-- Data: WoW Forever beta guides (build 1.60.1) and the QuestieDB Forever item,
-- NPC and quest data. Zone skill levels are Classic's until Forever confirms them.
local _, RG = ...
local GOLD, GREEN, GREY, RED = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY, RG.COLORS.RED
local ORANGE = "|cffff8040"
local FISH_ICON = "|TInterface\\Icons\\Trade_Fishing:14:14|t "
table.insert(RG.OPTIONS, { key = "fishTracker", label = "Fishing panel on the tracker while I fish (skill, lure, catches)", default = true })

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------
-- Skill at which every fish bites in a zone (catches start 95 below that).
RG.FISH_ZONES = {
  ["Tirisfal Glades"] = 25, ["Durotar"] = 25, ["Mulgore"] = 25, ["Elwynn Forest"] = 25, ["Dun Morogh"] = 25, ["Teldrassil"] = 25,
  ["Undercity"] = 25, ["Orgrimmar"] = 25, ["Thunder Bluff"] = 25, ["Stormwind City"] = 25, ["Ironforge"] = 25, ["Darnassus"] = 25,
  ["The Barrens"] = 75, ["Silverpine Forest"] = 75, ["Darkshore"] = 75, ["Loch Modan"] = 75, ["Westfall"] = 75,
  ["Ashenvale"] = 150, ["Duskwood"] = 150, ["Hillsbrad Foothills"] = 150, ["Redridge Mountains"] = 150, ["Stonetalon Mountains"] = 150, ["Wetlands"] = 150,
  ["Alterac Mountains"] = 225, ["Arathi Highlands"] = 225, ["Desolace"] = 225, ["Dustwallow Marsh"] = 225, ["Stranglethorn Vale"] = 225, ["Swamp of Sorrows"] = 225,
  ["Azshara"] = 300, ["Felwood"] = 300, ["Feralas"] = 300, ["The Hinterlands"] = 300, ["Moonglade"] = 300, ["Tanaris"] = 300, ["Un'Goro Crater"] = 300, ["Western Plaguelands"] = 300,
  ["Burning Steppes"] = 425, ["Deadwind Pass"] = 425, ["Eastern Plaguelands"] = 425, ["Silithus"] = 425, ["Winterspring"] = 425,
  ["Stratholme"] = 425, ["Scholomance"] = 425, ["Zul'Gurub"] = 425,
}
-- Subzones that are harder than their zone.
RG.FISH_SUBZONES = { ["Jademir Lake"] = 425, ["Bay of Storms"] = 425 }

-- How to reach each rank (Horde). max = skill cap while you have that rank.
RG.FISH_RANKS = {
  { name = "Apprentice", max = 75,  at = 0,   lvl = 5,  how = "Any Fishing trainer, 1s: Armand Cromwell in the Undercity canals, Lumak in Orgrimmar, Kah Mistrunner in Thunder Bluff." },
  { name = "Journeyman", max = 150, at = 50,  lvl = 10, how = "Fishing trainer at 50 skill and level 10, 5s." },
  { name = "Expert",     max = 225, at = 125, lvl = 20, how = "Book \"Expert Fishing - The Bass and You\" from Old Man Heming in Booty Bay, 1g, at 125 skill and level 20. It isn't soulbound, so your bank alt can buy it or check the AH.", wp = { 1434, 27.4, 77.2, "Old Man Heming" } },
  { name = "Artisan",    max = 300, at = 225, lvl = 35, how = "Quest Nat Pagle, Angler Extreme at Tidefury Cove, Dustwallow Marsh (level 35; 225 skill in Classic). Bring Misty Reed Mahi Mahi, Sar'theris Striker, Feralas Ahi and Savage Coast Blue Sailfin.", wp = { 1445, 58.6, 60.1, "Nat Pagle" } },
}

-- Where to fish, by skill, for an Undead Horde paladin.
RG.FISH_ROUTE = {
  { from = 1, to = 75, lvl = 5, zone = "Undercity", spot = "Undercity canals", text = "Fish the canals by Armand Cromwell (trainer) and Lizbeth Cromwell (supplies): safe, no mobs. Tirisfal's lakes give lots of Sickly Looking Fish. A Shiny Bauble helps below 25.", wp = { 1458, 80.7, 31.3, "Armand Cromwell" } },
  { from = 75, to = 150, lvl = 10, zone = "Silverpine Forest", spot = "Wherever you quest", text = "No lure needed now. Fish while you wait on respawns in Silverpine, the Barrens and Hillsbrad: Longjaw Mud Snapper and Bristle Whisker Catfish level your Cooking. The Undercity canals still work." },
  { from = 150, to = 225, lvl = 30, zone = "Stranglethorn Vale", spot = "Islands southeast of Grom'gol", text = "Take the zeppelin to Grom'gol and fish the two small islands to its southeast: Rockscale Cod, Spotted Yellowtail, Oily Blackmouth, Firefin Snapper. Or Dustwallow's inland water for catfish and Mithril Head Trout. Fish get away below 225, so use Nightcrawlers.", wp = { 1434, 32.5, 29.4, "Grom'gol" } },
  { from = 225, to = 300, lvl = 42, zone = "Tanaris", spot = "Steamwheedle Port coast", text = "Tanaris coast: Spotted Yellowtail, Firefin Snapper, Glossy Mightfish, plus Summer Bass or Winter Squid by season. Or Feralas inland lakes from Camp Mojache for Redgill (not Jademir Lake). Fish get away below 300: keep a lure on." },
}

-- Poles, lures and fishing gear. bonus = Fishing skill (Classic values in the beta).
RG.FISH_GEAR = {
  { kind = "pole", id = 6256,  bonus = 0,  how = "Fishing supply vendors (Lizbeth Cromwell, Undercity), about 23c" },
  { kind = "pole", id = 12225, bonus = 3,  how = "Quest: The Family and the Fishing Pole" },
  { kind = "pole", id = 6365,  bonus = 5,  skill = 10, how = "Fishing vendors, about 9s: Lizbeth Cromwell (Undercity), Shankys (Orgrimmar), Kilxx (Ratchet)" },
  { kind = "pole", id = 6367,  bonus = 20, skill = 100, how = "Shellfish Traps underwater in Desolace (level 25); also on the AH" },
  { kind = "pole", id = 19022, bonus = 25, skill = 100, how = "Horde quest Snapjaws, Mon! from Katoom the Angler, Revantusk Village, The Hinterlands (level 44)" },
  { kind = "pole", id = 19970, bonus = 35, skill = 300, how = "Win the Stranglethorn Fishing Extravaganza (Master Angler)" },
  { kind = "lure", id = 6529,  bonus = 25,  mins = 10, how = "Any fishing vendor, 50c" },
  { kind = "lure", id = 6530,  bonus = 50,  mins = 10, skill = 50,  how = "Fishing vendors, 1s (Sun Rock Retreat, Ratchet, Undercity)" },
  { kind = "lure", id = 6811,  bonus = 50,  mins = 10, skill = 50,  how = "Quest: Electropellers" },
  { kind = "lure", id = 6532,  bonus = 75,  mins = 10, skill = 100, how = "Fishing vendors, 2s 50c" },
  { kind = "lure", id = 7307,  bonus = 75,  mins = 10, skill = 100, how = "Drops from Rotted One, Duskwood" },
  { kind = "lure", id = 6533,  bonus = 100, mins = 5,  skill = 100, how = "Fishing vendors (Shankys, Kilxx, Lizbeth Cromwell), 2s 50c" },
  { kind = "gear", id = 19972, bonus = 5, how = "Extravaganza: Keefer's Angelfish" },
  { kind = "gear", id = 19969, bonus = 5, how = "Extravaganza: Brownell's Blue Striped Racer" },
  { kind = "gear", id = 19971, bonus = 5, skill = 150, how = "Extravaganza: Dezian Queenfish (permanent pole upgrade)" },
}
local POLE, LURE = {}, {}
for _, g in ipairs(RG.FISH_GEAR) do if g.kind == "pole" then POLE[g.id] = g.bonus elseif g.kind == "lure" then LURE[g.id] = g end end

-- Fish that level Cooking or feed you. cook = Cooking skill for the recipe.
RG.FISH_COOK = {
  { id = 6291,  dish = "Brilliant Smallfish",      cook = 1,   fish = 1,   where = "Inland: Undercity canals, Tirisfal lakes", recipe = "Martine Tramblay (Tirisfal), Lizbeth Cromwell (Undercity)", note = "Keep a few raw for Fish Bowls" },
  { id = 6303,  dish = "Slitherskin Mackerel",     cook = 1,   fish = 1,   where = "Coast: Durotar, starting zones" },
  { id = 6289,  dish = "Longjaw Mud Snapper",      cook = 50,  fish = 1,   where = "Inland: Silverpine, Barrens, Undercity canals", recipe = "Lizbeth Cromwell (Undercity), Killian Sanatha (Silverpine)" },
  { id = 6361,  dish = "Rainbow Fin Albacore",     cook = 50,  fish = 1,   where = "Coast: Silverpine, Barrens", recipe = "Ronald Burch (Undercity), Killian Sanatha (Silverpine), Kilxx (Ratchet)" },
  { id = 6522,  dish = "Savory Deviate Delight",   cook = 85,  fish = 1,   where = "Barrens oases, Wailing Caverns", recipe = "Recipe drops (check the AH)", note = "Fun transform; sells well" },
  { id = 6308,  dish = "Bristle Whisker Catfish",  cook = 100, fish = 75,  where = "Inland: Hillsbrad, Stonetalon, Barrens, Dustwallow", recipe = "Derak Nightfall (Hillsbrad), Ronald Burch (Undercity), Kilxx (Ratchet)" },
  { id = 6362,  dish = "Rockscale Cod",            cook = 175, fish = 130, where = "Coast: Stranglethorn, Desolace", recipe = "Lizbeth Cromwell (Undercity), Wulan (Desolace)" },
  { id = 8365,  dish = "Mithril Head Trout",       cook = 175, fish = 130, where = "Inland: Dustwallow, Arathi, Swamp of Sorrows", recipe = "Lizbeth Cromwell (Undercity), Wulan (Desolace)", note = "Also the Fishing Rack reagent" },
  { id = 4603,  dish = "Spotted Yellowtail",       cook = 225, fish = 130, where = "Coast: Stranglethorn, Tanaris", recipe = "Gikkix (Gadgetzan)" },
  { id = 13754, dish = "Cooked Glossy Mightfish",  cook = 225, fish = 205, where = "Coast: Tanaris, Feralas", recipe = "Kelsey Yance (Booty Bay)" },
  { id = 13758, dish = "Filet of Redgill",         cook = 225, fish = 205, where = "Inland: Feralas, The Hinterlands, Un'Goro", recipe = "Kelsey Yance (Booty Bay)" },
  { id = 13755, dish = "Grilled Squid",            cook = 240, fish = 205, where = "Coast: Tanaris, Azshara, Feralas (winter)", recipe = "Gikkix (Gadgetzan)", note = "Well Fed +10 Agility: crit for Ret", ret = true, season = "winter" },
  { id = 13756, dish = "Hot Smoked Bass",          cook = 240, fish = 205, where = "Coast: Tanaris, Feralas (summer)", recipe = "Kelsey Yance (Booty Bay)", season = "summer" },
  { id = 13759, dish = "Nightfin Soup",            cook = 250, fish = 205, where = "Feralas, The Hinterlands, Western Plaguelands", recipe = "Gikkix (Gadgetzan)", note = "Mana regen: great for your healing set", time = "night" },
  { id = 13760, dish = "Poached Sunscale Salmon",  cook = 250, fish = 205, where = "Feralas, The Hinterlands, Azshara", recipe = "Gikkix (Gadgetzan)", note = "Health regen while leveling", time = "day" },
  { id = 13888, dish = "Lobster Stew",             cook = 275, fish = 205, where = "Coast: Feralas, Azshara", recipe = "Sheendra Tallgrass (Camp Mojache)" },
  { id = 13893, dish = "Mightfish Steak",          cook = 275, fish = 205, where = "Coast: Feralas, Tanaris", recipe = "Sheendra Tallgrass (Camp Mojache)" },
  { id = 13889, dish = "Baked Salmon",             cook = 275, fish = 205, where = "Feralas, The Hinterlands", recipe = "Sheendra Tallgrass (Camp Mojache)" },
}
-- Fish other professions buy (sell these).
RG.FISH_SELL = {
  { id = 6358,  note = "Blackmouth Oil (Alchemy 80). Coasts and Oily Blackmouth schools" },
  { id = 6359,  note = "Fire Oil (Alchemy 130). Coasts and Stonetalon lakes" },
  { id = 13422, note = "Stonescale Oil (Alchemy 250). Coastal swarms in Feralas, Tanaris, Azshara" },
  { id = 7973,  note = "Big-mouth Clam: Zesty Clam Meat and sometimes a pearl. Tanaris, Feralas, Stranglethorn coasts" },
}

RG.FISH_DERBY = {
  "Stranglethorn Fishing Extravaganza: Sundays from 2 pm server time (beta report). Turn in 40 Speckled Tastyfish to Riggle Bassbait in Booty Bay first to win.",
  "Winner picks the Arcanite Fishing Pole (+35) or the Hook of the Master Angler, and gets an Extravagant Extravaganza Coin to spend with Jang.",
  "Everyone else: Jang pays out for every 5 Tastyfish (Apprentice Angler). Tastyfish now stack to 40.",
  "Rare fish (4 hours to turn in): Keefer's Angelfish (Lucky Fishing Hat), Dezian Queenfish (Eternium line), Brownell's Blue Striped Racer (boots).",
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function db()
  RG.db.fish = RG.db.fish or { caught = {}, total = 0 }
  return RG.db.fish
end
function RG.FishSkill()
  local p = RG.Professions()
  local f = p.Fishing
  return f and f.rank or nil, f and f.max or 0
end
local function cookSkill() local p = RG.Professions().Cooking; return p and p.rank or 0 end

-- Catches per skill point (Classic rule of thumb: 1 below 75, one more every 25 after).
function RG.FishCatchesPerPoint(skill)
  if not skill or skill < 75 then return 1 end
  return math.floor((skill - 75) / 25) + 1
end

local function poleBonus()
  local id = GetInventoryItemID and GetInventoryItemID("player", 16)
  if id and POLE[id] then return POLE[id], id end
  return nil, id
end
function RG.HasPole() return poleBonus() ~= nil end

-- Lure: the weapon enchant on your pole, and which lure you last used.
local lastLure
function RG.FishLure()
  if not RG.HasPole() or not GetWeaponEnchantInfo then return nil end
  local has, ms = GetWeaponEnchantInfo()
  if not has then return nil end
  return (ms or 0) / 1000, lastLure and LURE[lastLure] and LURE[lastLure].bonus or nil
end

-- The zone you're in: skill where every fish bites, and how you compare.
function RG.FishZone()
  local zone = GetRealZoneText and GetRealZoneText() or ""
  local sub = GetSubZoneText and GetSubZoneText() or ""
  local full = RG.FISH_SUBZONES[sub] or RG.FISH_ZONES[zone]
  if not full then return nil, zone end
  local skill = RG.FishSkill() or 0
  local pole = poleBonus() or 0
  local lureLeft, lure = RG.FishLure()
  local eff = skill + pole + ((lureLeft and lure) or 0)
  local status
  if eff >= full then status = "all"
  elseif eff >= full - 95 then status = "some"
  else status = "none" end
  return { zone = (RG.FISH_SUBZONES[sub] and sub or zone), full = full, min = full - 95, eff = eff, status = status, skill = skill, pole = pole, lure = lureLeft and lure }, zone
end

-- Is it day or night on the server (for Nightfin / Sunscale)?
function RG.FishNight()
  local h = GetGameTime and GetGameTime() or 12
  return h >= 18 or h < 6
end

-- Your rank and what's next.
function RG.FishNextRank()
  local skill, max = RG.FishSkill()
  if not skill then return RG.FISH_RANKS[1], "learn" end
  for _, r in ipairs(RG.FISH_RANKS) do
    if r.max > (max or 0) then
      local lvl = UnitLevel("player")
      local ready = skill >= r.at and lvl >= r.lvl
      return r, ready and "ready" or "later"
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Cooking: which raw fish in your bags still give skill
-- ---------------------------------------------------------------------------
-- Read from your Cooking window each time you open it: recipe -> difficulty.
local function scanCooking()
  if not (GetTradeSkillLine and GetNumTradeSkills and GetTradeSkillInfo) then return end
  local ok, line = pcall(GetTradeSkillLine)
  if not ok or line ~= "Cooking" then return end
  local out = {}
  for i = 1, (GetNumTradeSkills() or 0) do
    local name, kind = GetTradeSkillInfo(i)
    if name and kind and kind ~= "header" then out[name:lower()] = kind end
  end
  if next(out) then RG.db.cookRecipes = out; RG.db.cookScanAt = cookSkill() end
end
-- difficulty of a dish for you: "optimal" | "medium" | "easy" | "trivial" | "unknown" (not learned or not scanned)
function RG.CookState(dish)
  local r = RG.db and RG.db.cookRecipes
  if not r then return nil end
  return r[dish:lower()] or "missing"
end
local function countItem(id) return (GetItemCount and GetItemCount(id)) or 0 end
-- Raw fish in your bags that still give Cooking skill.
function RG.CookNow()
  local list, total = {}, 0
  for _, c in ipairs(RG.FISH_COOK) do
    local have = countItem(c.id)
    if have > 0 then
      local st = RG.CookState(c.dish)
      if st == "optimal" or st == "medium" or st == "easy" then list[#list + 1] = { c = c, have = have, st = st }; total = total + have end
    end
  end
  table.sort(list, function(a, b) return a.c.cook > b.c.cook end)
  return list, total
end

-- ---------------------------------------------------------------------------
-- Fishing session: catches, fish per hour, skill gained
-- ---------------------------------------------------------------------------
local session = { start = nil, last = nil, catches = 0, skillStart = nil, items = {} }
RG.FishSessionData = session
local function onCatch()
  if not (IsFishingLoot and IsFishingLoot()) then return end
  local now = GetTime()
  if not session.last or now - session.last > 20 * 60 then
    session.start, session.catches, session.items = now, 0, {}
    session.skillStart = RG.FishSkill()
  end
  session.last = now
  session.catches = session.catches + 1
  local d = db()
  d.total = (d.total or 0) + 1
  for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
    local link = GetLootSlotLink and GetLootSlotLink(i)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then
      local qty = select(3, GetLootSlotInfo(i)) or 1
      session.items[id] = (session.items[id] or 0) + qty
      d.caught[id] = (d.caught[id] or 0) + qty
    end
  end
  if RG.QueueTracker then RG.QueueTracker() end
end
-- Active = pole in hand, or a catch in the last 10 minutes.
function RG.FishActive()
  if RG.IsAlt and RG.IsAlt() then return false end
  if not RG.Opt("fishTracker") then return false end
  if session.last and GetTime() - session.last < 600 then return true end
  return RG.HasPole()
end
function RG.FishSession()
  if not session.start then return nil end
  local mins = math.max(1, (session.last - session.start) / 60)
  local skill = RG.FishSkill()
  return { catches = session.catches, perHour = (session.catches > 1 and session.last - session.start >= 180) and math.floor(session.catches / mins * 60 + 0.5) or nil,
    gained = (skill and session.skillStart) and (skill - session.skillStart) or 0, items = session.items }
end

-- Lines for the tracker's Fishing section: { text, right, onClick, tip }
function RG.FishTrackerLines()
  if not RG.FishActive() then return nil end
  local out = {}
  local skill, max = RG.FishSkill()
  local function open() if RG.ShowTab then RG.ShowTab("fish") end end
  if not skill then
    out[1] = { GOLD .. "Learn Fishing|r" .. GREY .. " from a Fishing trainer|r", nil, open }
    return out, nil
  end
  local per = RG.FishCatchesPerPoint(skill)
  out[#out + 1] = { "|cffffffffSkill " .. skill .. "/" .. max .. "|r" .. GREY .. "  ·  ~" .. per .. " catch" .. (per > 1 and "es" or "") .. " per point|r", nil, open,
    "Your Fishing skill. At " .. skill .. " it takes about " .. per .. " catch" .. (per > 1 and "es" or "") .. " for each point." }
  if skill >= max and max < 300 then
    local r = RG.FishNextRank()
    if r then out[#out + 1] = { ORANGE .. "Capped: train " .. r.name .. "|r", nil, open, r.how } end
  end
  local z = RG.FishZone()
  if z then
    local t
    if z.status == "all" then t = GREEN .. "Every fish bites here|r"
    elseif z.status == "some" then t = ORANGE .. "Some fish get away|r" .. GREY .. " (need " .. z.full .. ", you have " .. z.eff .. ")|r"
    else t = RED .. "Too low to fish here|r" .. GREY .. " (need " .. z.min .. "+)|r" end
    out[#out + 1] = { t, nil, open, z.zone .. ": every fish bites at " .. z.full .. ", fishing starts at " .. math.max(1, z.min) .. ".\nYour skill " .. z.skill .. (z.pole > 0 and (" + pole " .. z.pole) or "") .. (z.lure and (" + lure " .. z.lure) or "") .. " = " .. z.eff .. "." }
  end
  if RG.HasPole() then
    local left = RG.FishLure()
    if left then
      out[#out + 1] = { GREY .. "Lure|r", (left < 60 and ORANGE or "|cffffffff") .. math.ceil(left / 60) .. " min|r" }
    elseif z and z.status ~= "all" then
      out[#out + 1] = { ORANGE .. "No lure on your pole|r", nil, open, "A lure adds 25 to 100 skill for 5-10 minutes so fewer fish get away." }
    end
  end
  local s = RG.FishSession()
  if s and s.catches > 0 then
    out[#out + 1] = { GREY .. "This session|r", "|cffffffff" .. s.catches .. " fish|r" .. (s.perHour and (GREY .. "  ·  " .. s.perHour .. "/hr|r") or "") .. (s.gained > 0 and (GREEN .. "  +" .. s.gained .. "|r") or "") }
  end
  local cook, n = RG.CookNow()
  if n > 0 then
    out[#out + 1] = { GOLD .. "Cook " .. n .. " raw fish|r" .. GREY .. ": still levels Cooking|r", nil, open,
      "At your campfire: " .. cook[1].c.dish .. (cook[2] and (", " .. cook[2].c.dish) or "") .. "." }
  end
  return out, GREY .. (z and z.zone or "") .. "|r"
end

-- ---------------------------------------------------------------------------
-- Reminders (tracker)
-- ---------------------------------------------------------------------------
local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  if (RG.IsAlt and RG.IsAlt()) or not RG.Plans or not RG.Plans("Fishing") then return out end
  local skill, max = RG.FishSkill()
  if skill and max and skill >= max and max < 300 then
    local r, st = RG.FishNextRank()
    if r and st == "ready" then
      out[#out + 1] = { FISH_ICON .. GOLD .. "Fishing capped at " .. max .. "|r" .. GREY .. ": get " .. r.name .. "|r", function() if RG.ShowTab then RG.ShowTab("fish") end end, 6 }
    end
  end
  -- cooking reminder only away from fishing (the Fishing section shows it then)
  if not RG.FishActive() and RG.Plans("Cooking") then
    local _, n = RG.CookNow()
    if n >= 5 then out[#out + 1] = { GOLD .. "Cook " .. n .. " raw fish|r" .. GREY .. " at your next campfire: they still level Cooking|r", function() if RG.ShowTab then RG.ShowTab("fish") end end, 7 } end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local lureCounts = {}
local function snapshotLures() for id in pairs(LURE) do lureCounts[id] = countItem(id) end end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "LOOT_OPENED", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "BAG_UPDATE_DELAYED", "UNIT_INVENTORY_CHANGED", "SKILL_LINES_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, a1)
  if RG.IsAlt and RG.IsAlt() then return end
  if event == "PLAYER_LOGIN" then snapshotLures()
  elseif event == "LOOT_OPENED" then pcall(onCatch)
  elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then pcall(scanCooking)
  elseif event == "BAG_UPDATE_DELAYED" then
    -- a lure used up while holding a pole = the lure on it now
    if RG.HasPole() then for id in pairs(LURE) do local c = countItem(id); if lureCounts[id] and c < lureCounts[id] then lastLure = id end end end
    snapshotLures()
  end
  if RG.FishActive() and RG.QueueTracker then RG.QueueTracker() end
end)
-- keep the lure timer moving on the tracker while fishing
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(30, function() if RG.db and RG.FishActive() and RG.QueueTracker and not (InCombatLockdown and InCombatLockdown()) then RG.QueueTracker() end end)
end

local base = SlashCmdList.RETGEAR
SlashCmdList.RETGEAR = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  cmd = cmd and cmd:lower()
  if cmd == "fish" or cmd == "cook" then if RG.ShowTab then RG.ShowTab("fish") end return end
  return base(msg)
end

-- ---------------------------------------------------------------------------
-- Fishing sound mode: the game doesn't tell addons when a fish bites, so the
-- next best thing is to make the bobber's own splash impossible to miss.
-- While you fish: sound effects to full, music and ambience off, sound on in
-- the background. Your settings come back 30 seconds after your last cast.
-- When a cast ends without a catch, a ding and a quick flash say "cast again".
-- ---------------------------------------------------------------------------
table.insert(RG.OPTIONS, { key = "fishSound", label = "Loud bobber splash while fishing (music and ambience muted)", default = true })
table.insert(RG.OPTIONS, { key = "fishRecast", label = "Ding and screen flash when my bobber is gone (cast again)", default = true })
local FISHING_IDS = { [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true, [51294] = true, [131474] = true }
local function isFishing(spellID)
  if RG.IsSecret and RG.IsSecret(spellID) then return false end
  if spellID and FISHING_IDS[spellID] then return true end
  local ok, name = pcall(function()
    if C_Spell and C_Spell.GetSpellInfo then local i = C_Spell.GetSpellInfo(spellID); return i and i.name end
    return GetSpellInfo and GetSpellInfo(spellID)
  end)
  return ok and name == "Fishing"
end
local SOUND_CVARS = { Sound_SFXVolume = "1.0", Sound_MusicVolume = "0", Sound_AmbienceVolume = "0", Sound_EnableSoundWhenGameIsInBG = "1" }
local saved, lastCast, castEndedAt, lootedAt
local function soundOn()
  if saved or not RG.Opt("fishSound") or not GetCVar or not SetCVar then return end
  saved = {}
  for k, v in pairs(SOUND_CVARS) do
    local ok, cur = pcall(GetCVar, k)
    if ok and cur then saved[k] = cur; pcall(SetCVar, k, v) end
  end
end
local function soundOff()
  if not saved then return end
  for k, v in pairs(saved) do pcall(SetCVar, k, v) end
  saved = nil
end
RG.FishSoundRestore = soundOff

local flash
local function recastAlert()
  if not RG.Opt("fishRecast") then return end
  if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.READY_CHECK or 8960, "Master") end
  if not flash then
    flash = CreateFrame("Frame", nil, UIParent)
    flash:SetAllPoints(UIParent); flash:SetFrameStrata("FULLSCREEN_DIALOG"); flash:EnableMouse(false)
    flash.t = flash:CreateTexture(nil, "BACKGROUND"); flash.t:SetAllPoints()
    flash.t:SetTexture("Interface\\FullScreenTextures\\LowHealth"); flash.t:SetBlendMode("ADD"); flash.t:SetVertexColor(0.3, 0.7, 1)
  end
  local t = 0
  flash:SetAlpha(0.9); flash:Show()
  flash:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    self:SetAlpha(math.max(0, 0.9 - t * 1.5))
    if t > 0.6 then self:Hide(); self:SetScript("OnUpdate", nil) end
  end)
  if UIErrorsFrame then UIErrorsFrame:AddMessage("Bobber gone: cast again", 0.4, 0.8, 1) end
end

local sev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "LOOT_OPENED", "PLAYER_LOGOUT", "PLAYER_REGEN_DISABLED" }) do pcall(sev.RegisterEvent, sev, e) end
sev:SetScript("OnEvent", function(_, event, unit, _, spellID)
  if event == "PLAYER_LOGOUT" then soundOff() return end
  if event == "PLAYER_REGEN_DISABLED" then soundOff() return end -- in a fight: back to normal sound
  if event == "LOOT_OPENED" then lootedAt = GetTime() return end
  if unit ~= "player" or not isFishing(spellID) then return end
  if event == "UNIT_SPELLCAST_CHANNEL_START" then
    lastCast = GetTime(); castEndedAt = nil
    soundOn()
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    castEndedAt = GetTime()
    local ended = castEndedAt
    -- no loot window right after the cast ended: the fish got away or the bobber timed out
    C_Timer.After(1.2, function()
      if castEndedAt == ended and not (lootedAt and lootedAt >= ended - 0.5) and not (InCombatLockdown and InCombatLockdown()) then recastAlert() end
    end)
  end
end)
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(5, function()
    if saved and lastCast and GetTime() - lastCast > 30 and not (castEndedAt == nil) then soundOff() end
  end)
end
