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
  { prof = "Blacksmithing", skill = 20,  name = "Sharpening Wheel", buff = "+Strength (6 / 11 / 20 / 34 as you level)", mats = "1 Rough Stone, 1 Copper Bar", how = "Trainer recipe", best = "dps" },
  { prof = "Blacksmithing", skill = 140, name = "Anvil",            buff = "Strength, plus an anvil anywhere", how = "Blueprint: Gilnid, The Deadmines (Alliance side, so buy it on the AH with your bank alt)" },
  { prof = "Blacksmithing", skill = 300, name = "Master Forge",     buff = "Strength, plus Master Forge recipes", how = "Blueprint source not found yet" },
  { prof = "Mining",        skill = 20,  name = "Lodestone",        buff = "+melee Attack Power (12 up to 90). Doesn't stack with Blessing of Might", how = "Trainer recipe", best = "group" },
  { prof = "Mining",        skill = 140, name = "Rock Garden",      buff = "Spawns a common ore node over time", how = "Blueprint: Relic Guardian, Excavation Site in Wetlands (Alliance side, so try the AH)" },
  { prof = "Mining",        skill = 300, name = "Molten Foundry",   buff = "Smelts ores that need a Mining Foundry", how = "Blueprint source not found yet" },
  { prof = "Fishing",       skill = 20,  name = "Fish Bowl",        buff = "+8% to all stats. Doesn't stack with Blessing of Kings", mats = "1 Raw Brilliant Smallfish, 1 Empty Vial", how = "Trainer recipe", best = "heal" },
  { prof = "Fishing",       skill = 140, name = "Fishing Rack",     buff = "Fish Bowl, plus uncommon fish and skill lures for an hour", mats = "2 Simple Wood, 1 Crystal Vial, 2 Raw Mithril Head Trout", how = "Blueprint: Gelihast, Blackfathom Deeps" },
  { prof = "Fishing",       skill = 300, name = "Fishing Hut",      buff = "Fish Bowl, plus rare fish and more lures", mats = "5 Simple Wood, 2 Bolt of Runecloth, 1 Seasonal Fish Steaks", how = "Blueprint source not found yet" },
  { prof = "Cooking",       skill = 140, name = "Cookie's Feast",   buff = "Stamina food for the group", how = "Blueprint: Cookie, The Deadmines (try the AH)" },
}

-- Leveling plan for Fishing and Cooking, tied to your route (Horde, Undead start).
-- zone = route zone it belongs to; lvl = character level; need = { prof = skill } that marks it done.
RG.CAMP_PLAN = {
  { lvl = 5,  zone = "Tirisfal Glades", text = "Do The Great Outdoors (around level 5). Learn Cooking in Brill or Undercity, buy Simple Wood and Flint and Tinder, and make a Basic Campfire Kit.", need = { Cooking = 1 } },
  { lvl = 5,  zone = "Tirisfal Glades", text = "Learn Fishing from Clyde Kellen at Brightwater Lake. Buy a Fishing Pole, a Shiny Bauble and the Brilliant Smallfish recipe from Martine Tramblay.", need = { Fishing = 1 } },
  { lvl = 6,  zone = "Tirisfal Glades", text = "Fish while you wait on respawns: the Undercity canals are best (Tirisfal's lakes give lots of Sickly Looking Fish). Cook every Brilliant Smallfish you catch, and keep a few raw ones for Fish Bowls.", need = { Fishing = 50, Cooking = 40 } },
  { lvl = 8,  zone = "Tirisfal Glades", text = "Learn the camp objects at 20 skill: Sharpening Wheel (Blacksmithing trainer) and Fish Bowl (Fishing trainer). Lodestone (Mining) is only worth it in groups.", need = { Blacksmithing = 20 } },
  { lvl = 10, zone = "Silverpine Forest", text = "Train Journeyman Fishing (Fishing 50, level 10) and Journeyman Cooking (Cooking 50). Fish the Undercity canals or the Silverpine coast to 130.", need = { Fishing = 130 } },
  { lvl = 12, zone = "Silverpine Forest", text = "Cook Longjaw Mud Snapper and Bristle Whisker Catfish. Recipes are in Undercity from Lizbeth Cromwell and Ronald Burch. Push Cooking toward 90 for the Journeyman Campfire.", need = { Cooking = 90 } },
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
-- Which ONE object to place when you camp alone (one per hour), in Ret score terms.
function RG.CampPick()
  local p = RG.Professions()
  local lvl = UnitLevel("player")
  local w = RG.db.weights
  local opts = {}
  if (p.Blacksmithing and p.Blacksmithing.rank or 0) >= 20 then
    opts[#opts + 1] = { name = "Sharpening Wheel", value = wheelStr(lvl) * (w.STR or 0), why = string.format("about +%d Strength", wheelStr(lvl)) }
  end
  if (p.Fishing and p.Fishing.rank or 0) >= 20 and UnitStat then
    local v, txt = 0, {}
    local keys = { { 1, "STR" }, { 2, "AGI" }, { 3, "STA" }, { 4, "INT" }, { 5, "SPI" } }
    for _, k in ipairs(keys) do
      local _, stat = UnitStat("player", k[1])
      local add = (stat or 0) * 0.08
      v = v + add * (w[k[2]] or 0)
    end
    local _, str = UnitStat("player", 1)
    opts[#opts + 1] = { name = "Fish Bowl", value = v, why = string.format("+8%% all stats (about +%d Strength)", math.floor((str or 0) * 0.08 + 0.5)) }
  end
  table.sort(opts, function(a, b) return a.value > b.value end)
  return opts[1], opts
end

local function skill(name) local p = RG.Professions()[name]; return p and p.rank or 0 end
-- Fishing/Cooking steps hide when setup says you won't level that profession.
local function planned(step)
  if not RG.Plans then return true end
  for prof in pairs(step.need or {}) do if (prof == "Fishing" or prof == "Cooking") and not RG.Plans(prof) then return false end end
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
