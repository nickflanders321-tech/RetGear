-- Waypath+ camping, fishing and cooking (WoW Forever).
-- Camping isn't a skill of its own in Forever: Cooking makes the campfire
-- (bigger fires hold more objects), and each profession adds one object at
-- skill 20 / 140 / 300. You can place one object per hour. Sit by the fire for
-- a minute to get "Camp Benefits" for an hour.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local CAMP_ICON = "|TInterface\\Icons\\Spell_Fire_Fire:14:14:0:0:64:64:5:59:5:59|t "

table.insert(RG.OPTIONS, { key = "campReminder", label = "Remind me to make camp for the 1-hour camp buff", default = true })
table.insert(RG.OPTIONS, { key = "wellFed", label = "Remind me to eat for Well Fed (+5% XP while leveling)", default = true })

-- ---------------------------------------------------------------------------
-- Data (Icy Veins, Mobalytics, wowforever.be, classicwowforever.com, wow-professions.com)
-- ---------------------------------------------------------------------------
RG.CAMPFIRES = {
  { name = "Basic Campfire",      cook = 1,   slots = 3,  wood = "Simple Wood", how = "Learned with Cooking. Buy Simple Wood and Flint and Tinder from the Cooking trainer." },
  { name = "Journeyman Campfire", cook = 140, learn = 90,  slots = 5,  wood = "Star Wood",   how = "Blueprint from Lord Serpentis in Wailing Caverns (also reported in Deadmines)." },
  { name = "Expert Campfire",     cook = 220, learn = 200, slots = 10, wood = "Thick Logs",  how = "Blueprint source not found yet. The weekly update will add it." },
}
-- Your professions' camp objects. buff = what you get; mats = what it costs to place.
RG.CAMP_OBJECTS = {
  { prof = "Alchemy",        skill = 20,  name = "Mana Well",        buff = "Mana regeneration. Doesn't stack with Blessing of Wisdom", mats = "1 Peacebloom, 1 Empty Vial", how = "Trainer recipe or Camping 101" },
  { prof = "Alchemy",        skill = 140, name = "Fermenter",        buff = "Needed for a few Alchemy recipes", mats = "1 Leaded Vial, 1 Kingsblood, 1 Swiftthistle", how = "Blueprint: Rath'mael, Ruins of Lordaeron" },
  { prof = "Alchemy",        skill = 300, name = "Alchemy Laboratory", buff = "Needed for some Alchemy recipes", mats = "1 Lich's Index Finger, 1 Crystal Vial, 2 Dreamfoil", how = "Blueprint source not found yet" },
  { prof = "Blacksmithing",  skill = 20,  name = "Sharpening Wheel", buff = "+Strength (6 / 11 / 20 / 34 as you level). Doesn't stack with Strength of Earth Totem", mats = "1 Rough Stone, 1 Copper Bar", how = "Trainer recipe or Camping 101", best = "dps" },
  { prof = "Blacksmithing",  skill = 140, name = "Anvil",            buff = "An anvil anywhere", mats = "5 Bronze Bar, 2 Coarse Grinding Stone, 2 Medium Leather", how = "Blueprint: Gilnid, The Deadmines (Alliance side, so try the AH)" },
  { prof = "Blacksmithing",  skill = 300, name = "Master Forge",     buff = "Needed for many Blacksmithing recipes", mats = "1 Golem Heart, 5 Thorium Bar, 2 Rugged Leather", how = "Blueprint source not found yet" },
  { prof = "Enchanting",     skill = 20,  name = "Enchanted Lute",   buff = "Armor, all stats and all resistances. Doesn't stack with Mark of the Wild", mats = "1 Simple Wood, 1 Strange Dust", how = "Trainer recipe or Camping 101" },
  { prof = "Enchanting",     skill = 140, name = "Arcane Salvager",  buff = "Better disenchanting", mats = "2 Vision Dust, 1 Lesser Nether Essence", how = "Blueprint: Shade of the Archmage, City of Dalaran" },
  { prof = "Enchanting",     skill = 300, name = "Arcane Forge",     buff = "Needed for some Enchanting recipes", mats = "1 Maker's Spark, 2 Large Brilliant Shard, 4 Greater Eternal Essence", how = "Blueprint source not found yet" },
  { prof = "Engineering",    skill = 20,  name = "Reagent Bot",      buff = "A vendor for class reagents and profession supplies, for everyone at camp", mats = "1 Handful of Copper Bolts, 1 Copper Tube", how = "Trainer recipe or Camping 101" },
  { prof = "Engineering",    skill = 140, name = "Repair Bot",       buff = "Repairs for everyone at camp", mats = "2 Whirring Bronze Gizmo, 1 Bronze Tube, 1 Heavy Leather", how = "Blueprint: Sneed, The Deadmines (try the AH)" },
  { prof = "Engineering",    skill = 300, name = "Anarchist's Workbench", buff = "Needed for some Engineering recipes", mats = "1 Essence of Anarchy, 2 Thorium Widget", how = "Blueprint source not found yet" },
  { prof = "Leatherworking", skill = 20,  name = "Camp Tent",        buff = "Rested XP worth up to 5% of a level, once an hour", mats = "5 Light Leather", how = "Trainer recipe or Camping 101", best = "xp" },
  { prof = "Leatherworking", skill = 140, name = "Tanning Rack",     buff = "Needed for many Leatherworking recipes", mats = "5 Medium Leather, 3 Fine Thread, 2 Simple Wood", how = "Blueprint: Razorclaw the Butcher, Shadowfang Keep" },
  { prof = "Leatherworking", skill = 300, name = "Sewing Machine",   buff = "Needed for many Leatherworking recipes", mats = "1 Undeath Engine, 5 Rugged Leather, 1 Rune Thread", how = "Blueprint source not found yet" },
  { prof = "Tailoring",      skill = 20,  name = "Faction Banner",   buff = "+Spirit. Doesn't stack with Divine Spirit", mats = "1 Bolt of Linen Cloth, 1 Coarse Thread", how = "Trainer recipe or Camping 101" },
  { prof = "Tailoring",      skill = 140, name = "Spinning Wheel",   buff = "Needed for many Tailoring recipes", mats = "2 Simple Wood, 5 Bolt of Silk Cloth, 3 Fine Thread", how = "Blueprint: Unstable Sentinel, City of Dalaran" },
  { prof = "Tailoring",      skill = 300, name = "Loom",             buff = "Needed for many Tailoring recipes", mats = "1 Bottled Screams, 4 Bolt of Runecloth, 4 Simple Wood", how = "Blueprint source not found yet" },
  { prof = "Herbalism",      skill = 20,  name = "Incense Candle",   buff = "+Intellect. Doesn't stack with Arcane Intellect", mats = "1 Peacebloom, 1 Silverleaf", how = "Trainer recipe or Camping 101" },
  { prof = "Herbalism",      skill = 140, name = "Greenhouse",       buff = "Grows herbs from seeds you plant", mats = "2 Simple Wood, 1 Arthas' Tears, 1 Purple Lotus", how = "Blueprint: Shadetooth, Excavation Site" },
  { prof = "Herbalism",      skill = 300, name = "Seed Hybridizer",  buff = "Multiplies seeds or combines them into rarer ones", mats = "4 Mountain Silversage, 1 Crystal Vial, 2 Runecloth", how = "Blueprint source not found yet" },
  { prof = "Mining",         skill = 20,  name = "Lodestone",        buff = "+melee Attack Power (12 up to 90). Doesn't stack with Blessing of Might", mats = "1 Rough Stone, 1 Copper Bar", how = "Trainer recipe or Camping 101", best = "group" },
  { prof = "Mining",         skill = 140, name = "Rock Garden",      buff = "A common ore node that grows over time", mats = "2 Heavy Stone, 1 Iron Ore, 1 Silver Bar", how = "Blueprint: Relic Guardian, Excavation Site" },
  { prof = "Mining",         skill = 300, name = "Molten Foundry",   buff = "Needed to smelt Heavy Thorium", mats = "5 Thorium Bar, 2 Dense Stone, 1 Truesilver Bar", how = "Blueprint source not found yet" },
  { prof = "Skinning",       skill = 20,  name = "Camp Chair",       buff = "+2% crit. Doesn't stack with Moonkin Aura", mats = "3 Light Leather, 2 Simple Wood", how = "Trainer recipe or Camping 101" },
  { prof = "Skinning",       skill = 140, name = "Field Guide",      buff = "A book anyone at camp can read to learn Track Beasts", mats = "3 Medium Leather, 2 Slimy Murloc Scale, 1 Fine Thread", how = "Blueprint: Lady Anacondra, Wailing Caverns" },
  { prof = "Skinning",       skill = 300, name = "Trapper's Workbench", buff = "A workbench with a trap", mats = "2 Simple Wood, 4 Heavy Leather, 1 Iron Bar", how = "Blueprint source not found yet" },
  { prof = "Cooking",        skill = 140, name = "Cookie's Feast",   buff = "Stamina food for everyone at camp", mats = "2 Mystery Meat, 1 Heavy Kodo Meat, 1 Soothing Spices", how = "Blueprint: Cookie, The Deadmines (try the AH)" },
  { prof = "Cooking",        skill = 300, name = "Iron Oven",        buff = "Needed for the most advanced Cooking recipes", mats = "10 Simple Flour, 5 Refreshing Spring Water, 4 Soothing Spices", how = "Blueprint source not found yet" },
  { prof = "First Aid",      skill = 20,  name = "First Aid Kit",    buff = "+Stamina. Doesn't stack with Power Word: Fortitude", mats = "3 Linen Bandage, 1 Refreshing Spring Water", how = "Trainer recipe or Camping 101" },
  { prof = "First Aid",      skill = 140, name = "Toxin Study",      buff = "Healing potions and anti-venom", mats = "1 Anti-Venom, 2 Mageweave Bandage, 2 Simple Wood", how = "Blueprint: Commander Springvale, Shadowfang Keep" },
  { prof = "First Aid",      skill = 300, name = "Plague Doctor's Laboratory", buff = "Healing potions and poultices", mats = "2 Simple Wood, 2 Strong Anti-Venom, 5 Heavy Runecloth Bandage", how = "Blueprint source not found yet" },
  { prof = "Fishing",        skill = 20,  name = "Fish Bowl",        buff = "+8% to all stats. Doesn't stack with Blessing of Kings", mats = "1 Raw Brilliant Smallfish, 1 Empty Vial", how = "Trainer recipe or Camping 101", best = "heal" },
  { prof = "Fishing",        skill = 140, name = "Fishing Rack",     buff = "Uncommon fish for an hour, plus fishing lures", mats = "2 Simple Wood, 1 Crystal Vial, 2 Raw Mithril Head Trout", how = "Blueprint: Gelihast, Blackfathom Deeps" },
  { prof = "Fishing",        skill = 300, name = "Fishing Hut",      buff = "Rare fish for an hour, plus fishing lures", mats = "5 Simple Wood, 2 Bolt of Runecloth, 1 Seasonal Fish Steaks", how = "Blueprint source not found yet" },
}

-- Leveling plan for Fishing and Cooking, tied to your route. "@start" and "@second" are
-- your race's first two route zones; {Cooking} and {Fishing} become your closest trainers.
-- zone = route zone it belongs to; lvl = character level; need = { prof = skill } that marks it done.
RG.CAMP_PLAN = {
  { lvl = 5,  zone = "@start", text = "Do The Great Outdoors (around level 5). Learn Cooking from {Cooking}, buy Simple Wood and Flint and Tinder, and make a Basic Campfire Kit.", need = { Cooking = 1 } },
  { lvl = 5,  zone = "@start", text = "Learn Fishing from {Fishing}. Buy a Fishing Pole and Shiny Baubles from a fishing supply vendor, and the Brilliant Smallfish recipe.", need = { Fishing = 1 } },
  { lvl = 6,  zone = "@start", text = "Fish while you wait on respawns, and cook every fish you catch. Keep a few Raw Brilliant Smallfish for Fish Bowls.", need = { Fishing = 50, Cooking = 50 } },
  { lvl = 8,  zone = "@start", text = "At skill 20, learn your professions' camp objects from their trainers (the Camping tab lists them): one object per camp, and the best one for you is marked.", need = { Cooking = 20 } },
  { lvl = 10, zone = "@second", text = "Train Journeyman Fishing (Fishing 50, level 10) and Journeyman Cooking (Cooking 50). Fish wherever you quest to 130.", need = { Fishing = 130 } },
  { lvl = 12, zone = "@second", text = "Cook what you catch: Longjaw Mud Snapper and Rainbow Fin Albacore (recipes from the fishing and cooking vendors in your capital). Push Cooking toward 90 for the Journeyman Campfire.", need = { Cooking = 90 } },
  { lvl = 18, zone = "Wailing Caverns", text = "Kill Lord Serpentis for the Journeyman Campfire blueprint (Cooking 90 to learn, 140 to use: 5 object slots). Fish the oasis outside for Deviate Fish.", need = { Cooking = 140 } },
  { lvl = 20, zone = "Stonetalon Mountains", text = "Get Expert Fishing (\"The Bass and You\", Old Man Heming in Booty Bay, 1g, level 20; or the AH) at Fishing 125. Buy Nightcrawlers at Sun Rock Retreat and fish Stonetalon's lakes to 205.", need = { Fishing = 205 } },
  { lvl = 22, zone = "Stonetalon Mountains", text = "Get the Expert Cookbook at Cooking 125, before you reach 150 (Wulan, Shadowprey Village in Desolace, or the AH). Without it you stop gaining skill at 150.", need = { Cooking = 150 } },
  { lvl = 26, zone = "Blackfathom Deeps", text = "Kill Gelihast for the Fishing Rack blueprint (Fishing 140): it gives your Fish Bowl plus uncommon fish for an hour.", need = { Fishing = 140 } },
  { lvl = 26, zone = "Ashenvale", text = "Buy the Anvil blueprint on the AH (it drops in Deadmines). It lets you smith anywhere at Blacksmithing 140.", need = { Blacksmithing = 140 } },
  { lvl = 35, zone = "Dustwallow Marsh", text = "Fish Dustwallow's inland water to 225, then take Nat Pagle, Angler Extreme at Tidefury Cove (level 35) for Artisan Fishing. Its 4 fish come from Feralas, Swamp of Sorrows, Desolace and Stranglethorn, all on your route.", need = { Fishing = 225 } },
  { lvl = 36, zone = "Dustwallow Marsh", text = "Cook at Brackenwall Village or at your own fire: Catfish, then Mithril Head Trout up to Cooking 225 (the Expert Campfire needs 220).", need = { Cooking = 220 } },
  { lvl = 44, zone = "Feralas", text = "Camp Mojache: buy Baked Salmon and Nightcrawlers from Sheendra Tallgrass, and fish inland Feralas lakes to 300 (not Jademir Lake).", need = { Fishing = 300 } },
  { lvl = 45, zone = "Tanaris", text = "Artisan Cooking: Clamlette Surprise from Dirge Quikcleave in Gadgetzan (may not be in the game yet). Then Nightfin Soup and Poached Sunscale Salmon to 300.", need = { Cooking = 300 } },
}

-- Fish worth catching (prices come from your AH scans).
RG.FISH = {
  { id = 6291,  name = "Raw Brilliant Smallfish", note = "Fish Bowl reagent and early cooking", skill = 1 },
  { id = 6522,  name = "Deviate Fish",            note = "Barrens oases and Wailing Caverns. Savory Deviate Delight sells well", skill = 1 },
  { id = 6358,  name = "Oily Blackmouth",         note = "Ratchet docks and the Silverpine coast. Alchemists buy it for Blackmouth Oil", skill = 55 },
  { id = 6359,  name = "Firefin Snapper",         note = "Coasts and Stonetalon lakes. Alchemists buy it for Fire Oil", skill = 130 },
  { id = 8365,  name = "Raw Mithril Head Trout",  note = "Fishing Rack reagent and Cooking 175-225", skill = 130 },
  { id = 13422, name = "Stonescale Eel",          note = "Azshara and coastal schools. Raiders' potions keep it expensive", skill = 225 },
}

-- ---------------------------------------------------------------------------
-- Live state: auras and recommendations
-- ---------------------------------------------------------------------------
-- Auras can't be read in combat, so the last reading is kept and reused then.
local last = { state = nil, exp = nil }
local function readCamp()
  local b, blocked = RG.PlayerBuff("Camp Benefits")
  if blocked then return false end
  if b then
    local exp = b.expirationTime
    last.state, last.exp = "active", (type(exp) == "number" and not RG.IsSecret(exp) and exp > 0) and exp or nil
  elseif RG.PlayerBuff("Welcoming Campfire") then last.state, last.exp = "sitting", nil
  elseif RG.PlayerBuff("Campfire Nearby") then last.state, last.exp = "near", nil
  else last.state, last.exp = nil, nil end
  return true
end
-- "active" (with seconds left) | "sitting" | "near" | nil
function RG.CampState()
  readCamp()
  if last.state == "active" and last.exp then
    local left = last.exp - GetTime()
    if left <= 0 then return nil end
    return "active", left
  end
  return last.state
end

-- Estimated Sharpening Wheel strength at your level (4 steps from level 1 to 60).
local function wheelStr(lvl) if lvl >= 45 then return 34 elseif lvl >= 30 then return 20 elseif lvl >= 15 then return 11 end return 6 end
-- Which ONE object to place when you camp alone (one per hour), scored with your
-- class's stat weights. Rough sizes, scaled like the Sharpening Wheel (4 steps 1-60).
function RG.CampPick()
  local p = RG.Professions()
  local lvl = UnitLevel("player")
  local w = RG.db.weights or {}
  local step = wheelStr(lvl)
  local opts = {}
  local function has(prof) return (p[prof] and p[prof].rank or 0) >= 20 end
  local function add(prof, name, value, why) if has(prof) then opts[#opts + 1] = { name = name, value = value, why = why } end end
  add("Blacksmithing", "Sharpening Wheel", step * (w.STR or 0), string.format("about +%d Strength", step))
  add("Mining", "Lodestone", math.min(90, 12 + lvl * 1.3) * (w.AP or 0), string.format("about +%d melee Attack Power", math.min(90, 12 + math.floor(lvl * 1.3))))
  add("Herbalism", "Incense Candle", step * (w.INT or 0), string.format("about +%d Intellect", step))
  add("Tailoring", "Faction Banner", step * (w.SPI or 0), string.format("about +%d Spirit", step))
  add("First Aid", "First Aid Kit", step * (w.STA or 0), string.format("about +%d Stamina", step))
  add("Skinning", "Camp Chair", 2 * (w.CRIT or 0), "+2% crit")
  add("Alchemy", "Mana Well", step * 0.5 * (w.MP5 or w.INT or 0), "mana regeneration")
  if has("Enchanting") then
    local v = 0
    for _, k in ipairs({ "STR", "AGI", "STA", "INT", "SPI" }) do v = v + (w[k] or 0) * step / 3 end
    opts[#opts + 1] = { name = "Enchanted Lute", value = v, why = "armor, all stats and resistances" }
  end
  if has("Leatherworking") and lvl < 60 then opts[#opts + 1] = { name = "Camp Tent", value = 1e6, why = "rested XP worth up to 5% of a level every hour" } end
  if has("Fishing") and UnitStat then
    local v = 0
    local keys = { { 1, "STR" }, { 2, "AGI" }, { 3, "STA" }, { 4, "INT" }, { 5, "SPI" } }
    for _, k in ipairs(keys) do
      local _, stat = UnitStat("player", k[1])
      v = v + (stat or 0) * 0.08 * (w[k[2]] or 0)
    end
    opts[#opts + 1] = { name = "Fish Bowl", value = v, why = "+8% to all your stats" }
  end
  table.sort(opts, function(a, b) return a.value > b.value end)
  return opts[1], opts
end

local function skill(name) local p = RG.Professions()[name]; return p and p.rank or 0 end
-- Fishing/Cooking steps hide when setup says you won't level that profession.
local function planned(step)
  if not RG.Plans then return true end
  for prof in pairs(step.need or {}) do if not RG.Plans(prof) then return false end end
  return true
end
RG.CampPlanned = planned
function RG.CampPlanDone(step)
  for prof, need in pairs(step.need or {}) do if skill(prof) < need then return false end end
  return true
end
-- Next unfinished plan steps at or below your level (+2)
function RG.CampNext(max)
  local lvl = UnitLevel("player")
  local out = {}
  for _, s in ipairs(RG.CAMP_PLAN) do
    if s.lvl <= lvl + 2 and planned(s) and not RG.CampPlanDone(s) then out[#out + 1] = s; if #out >= (max or 1) then break end end
  end
  return out
end
do
  local R = RG.ActiveRace or {}
  local z1 = R.route and R.route[1] and R.route[1].zone
  local z2 = R.route and (R.route[3] or R.route[2]) and (R.route[3] or R.route[2]).zone
  for _, st in ipairs(RG.CAMP_PLAN) do
    if st.zone == "@start" then st.zone = z1 or "Tirisfal Glades" elseif st.zone == "@second" then st.zone = z2 or z1 or "Silverpine Forest" end
    st.text = st.text:gsub("{(%a[%a ]*)}", function(prof)
      local P = RG.PROFESSIONS and RG.PROFESSIONS[prof]
      return P and P.train and P.train.start and P.train.start[RG.RACE_LETTER] or "a trainer in your capital"
    end)
  end
end
function RG.CampForEntry(r)
  local out = {}
  for _, s in ipairs(RG.CAMP_PLAN) do if s.zone == r.zone then out[#out + 1] = s end end
  return out
end

-- ---------------------------------------------------------------------------
-- Tracker reminders: make camp, keep sitting, eat, next camp/fish/cook step
-- ---------------------------------------------------------------------------
local function inCityOrInstance()
  if IsResting and IsResting() then return true end
  local inInst = IsInInstance and IsInInstance()
  return inInst and true or false
end
local function wellFed() return RG.PlayerBuff("Well Fed") ~= nil end

local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  if RG.IsAlt and RG.IsAlt() then return out end
  if InCombatLockdown and InCombatLockdown() then return out end
  local lvl = UnitLevel("player")
  local state, left = RG.CampState()
  if state == "sitting" then
    out[#out + 1] = { CAMP_ICON .. GOLD .. "Keep sitting|r" .. GREY .. ": Camp Benefits in about a minute|r", nil, 1 }
  elseif RG.Opt("campReminder") and skill("Cooking") >= 1 and lvl >= 5 and not inCityOrInstance() then
    if state ~= "active" then
      local pick = RG.CampPick()
      out[#out + 1] = { CAMP_ICON .. GOLD .. "Make camp|r" .. GREY .. ": fire" .. (pick and (" + " .. pick.name) or "") .. ", sit 1 minute for an hour of buffs|r", function() if RG.ShowTab then RG.ShowTab("camp") end end, 4 }
    elseif left and left < 300 then
      out[#out + 1] = { CAMP_ICON .. GOLD .. string.format("Camp buff ends in %d min", math.ceil(left / 60)) .. "|r" .. GREY .. ": make camp at your next stop|r", function() if RG.ShowTab then RG.ShowTab("camp") end end, 3 }
    end
  end
  if RG.Opt("wellFed") and lvl < 60 and not wellFed() and not inCityOrInstance() and skill("Cooking") >= 1 then
    out[#out + 1] = { GOLD .. "Eat cooked food|r" .. GREY .. ": Well Fed gives +5% XP from kills|r", nil, 5 }
  end
  local nxt = RG.CampNext(1)[1]
  if nxt then out[#out + 1] = { "|TInterface\\Icons\\Trade_Fishing:14:14|t " .. GREY .. nxt.text:gsub("%. .*$", ".") .. "|r", function() if RG.ShowTab then RG.ShowTab("camp") end end, 8 } end
  return out
end

-- Skill milestones in chat
local lastSkill = {}
local MILESTONES = {
  Fishing = { [20] = "Learn the Fish Bowl at your Fishing trainer.", [50] = "Train Journeyman Fishing (level 10).", [125] = "Get Expert Fishing: \"The Bass and You\" (Old Man Heming, Booty Bay, 1g, level 20; or the AH).", [140] = "Fishing Rack unlocked if you have the blueprint (Gelihast, Blackfathom Deeps).", [225] = "Take Nat Pagle, Angler Extreme in Dustwallow Marsh (level 35) for Artisan Fishing." },
  Cooking = { [50] = "Train Journeyman Cooking.", [90] = "You can learn the Journeyman Campfire blueprint (Lord Serpentis, Wailing Caverns).", [125] = "Get the Expert Cookbook now. Skill stops at 150 without it.", [140] = "Journeyman Campfire usable: 5 object slots.", [200] = "You can learn the Expert Campfire blueprint.", [225] = "Artisan Cooking: Clamlette Surprise in Gadgetzan (level 35)." },
  Blacksmithing = { [20] = "Learn the Sharpening Wheel camp object at your trainer.", [140] = "Anvil camp object unlocked if you have the blueprint (Deadmines, or the AH)." },
  Mining = { [20] = "Lodestone camp object unlocked (good for groups without a paladin).", [140] = "Rock Garden unlocked if you have the blueprint (Wetlands excavation site, or the AH)." },
}
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "UNIT_AURA" }) do pcall(ev.RegisterEvent, ev, e) end
local lastState
ev:SetScript("OnEvent", function(_, event, unit)
  if RG.IsAlt and RG.IsAlt() then return end
  if event == "UNIT_AURA" then
    if unit ~= "player" then return end
    local s = RG.CampState()
    if s ~= lastState then
      if s == "active" and lastState == "sitting" then RG.Print(CAMP_ICON .. "Camp Benefits for an hour. Happy hunting.") end
      lastState = s
      if RG.QueueTracker then RG.QueueTracker() end
    end
    return
  end
  for prof, marks in pairs(MILESTONES) do
    local now = skill(prof)
    local before = lastSkill[prof]
    if before and now > before then
      for at, msg in pairs(marks) do if before < at and now >= at then RG.Print(GOLD .. prof .. " " .. at .. ":|r " .. msg) end end
    end
    lastSkill[prof] = now
  end
  if event ~= "PLAYER_LOGIN" and RG.RefreshUI then RG.RefreshUI() end
end)

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  cmd = cmd and cmd:lower()
  if cmd == "camp" then if RG.ShowTab then RG.ShowTab("camp") end return end
  return base(msg)
end
