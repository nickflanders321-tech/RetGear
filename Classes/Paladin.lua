-- Waypath+ class data: Paladin (Retribution leveling, Holy off-spec).
-- Everything paladin-specific lives here: stat weights, the hand-written gear
-- guide, class quests and route milestones, talent order and rotation tips.
-- The generated gear list is in Classes/PaladinGear.lua.
local _, RG = ...
local P = { name = "Paladin", spec = "Retribution", offSpec = "Holy", scoreName = "Ret", lfgName = "Ret Paladin", lfgNote = "Blessings, Purify" }

-- Default stat weights for a standard 2H Retribution Paladin, in Attack Power
-- equivalents (1 AP = 1.0). Vanilla-style numbers: 1 Strength = 2 AP for a
-- paladin, 1% crit or 1% hit is worth roughly 20-25 AP, and a slow two-hander's
-- weapon DPS is the single biggest stat while leveling (Seal of Command and
-- Seal of Righteousness both scale with it). Change any of these in game with
-- /rg weight <stat> <value>.
P.weights = {
  STR        = 2.2,   -- Strength
  AGI        = 1.0,   -- Agility (crit only for paladins)
  AP         = 1.0,   -- Attack Power
  CRIT       = 22,    -- per 1% critical strike chance
  HIT        = 25,    -- per 1% hit chance (only up to the hit cap)
  STA        = 0.15,  -- Stamina (survival while leveling)
  INT        = 0.15,  -- Intellect (mana for seals and judgements)
  SPI        = 0.05,
  SP         = 0.3,   -- spell damage / healing ("damage and healing done by magical spells")
  SP_HOLY    = 0.3,   -- Holy spell damage only (Exorcism, Consecration, Holy Strike)
  WEAPON_DPS = 14,    -- per point of two-hand weapon DPS
  SLOW_BONUS = 4,     -- per 0.1 sec of weapon speed above 3.0 (slow 2H swings hit harder)
  -- Modern rating stats, in case WoW Forever items use ratings instead of %:
  CRIT_RATING = 1.0,
  HIT_RATING  = 1.0,
  HASTE_RATING = 0.8,
  MASTERY_RATING = 0.6,
  VERS_RATING = 0.7,
}

-- Hit chance needed to never miss a boss three levels above you.
P.hitCap = 9

-- What the class can wear and wield (item subclass IDs), and how its weapons are
-- scored: "2H" = one big two-hander (a one-hander counts for 55%).
-- Weapons: 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword,
-- 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
-- Armor: level each type can be worn from (1 cloth, 2 leather, 3 mail, 4 plate).
P.classBit = 2
P.model = "2H"
P.weapons = { 0, 1, 4, 5, 7, 8 }
P.armor = { [1] = 1, [2] = 1, [3] = 1, [4] = 40 }
P.shield = true
P.relic = 7   -- librams

-- Leveling guide. Every item was checked against the Classic item database
-- (wowhead.com/classic). "lvl" is the level you can use it; ~ means the item
-- has no hard requirement and that's when people usually pick it up.
-- src  = where it comes from, how = Quest / Dungeon / Crafted / Raid,
-- ah   = true when it can be bought on the Auction House (Bind on Equip).
-- Paladins in this era can use one- and two-handed swords, maces and axes,
-- but not staves or polearms, so those are left out.
--
-- Tailored for an Undead (Horde) Paladin: only Horde or neutral quests, and
-- dungeons on the Horde side of the map where there's a choice. Entries with
-- tip = true are advice rows, not items.
P.guide = {
  { tip = true, lvl = 1,  text = "Undead paladins start in Deathknell, Tirisfal Glades. Your class quests run out of Bandarion Keep in the Whispering Wood, north Tirisfal." },
  { tip = true, lvl = 8,  text = "Until your first quest two-hander, buy the slowest 2H axe, mace or sword you can afford from the weapon vendors in Brill or Undercity, or the Auction House." },
  { tip = true, lvl = 16, text = "Ruins of Lordaeron (16-22, above Undercity): The Wrath of Rath'mael rewards the Forsaken Greataxe and Unending Torment the Monstrous Cleaver, both two-handers. The Lordaeron Captain (Horde only) drops the Haunting Blade (2H sword) and Phantom Armor (mail chest); The Baron drops Abomination Bones (mail chest, +8 Strength). Beta data, no item IDs yet." },
  { tip = true, lvl = 10, text = "Bandarion Keep (Whispering Wood, north-west Tirisfal) is your paladin hub from level 10. Check it whenever you train." },
  { tip = true, lvl = 20, text = "Wolf's Bane, your level 20 paladin quest weapon (Fenris Isle, Silverpine): slow 3.4 speed, +10 Strength, +9 Stamina and a holy blast proc. It needs materials from Shadowfang Keep, Blackfathom Deeps and the Deadmines; worth it over most quest weapons until Razorfen Kraul. Beta stats, may change." },
  -- ===== Two-handed weapons (the biggest upgrade path for Ret) =====
  { id = 6214,  slot = "2H",  lvl = 11, how = "Crafted", src = "Blacksmithing", zone = "Your own craft (copper)", bs = 65 },
  { id = 7230,  slot = "2H",  lvl = 18, how = "Dungeon", src = "Mr. Smite", zone = "The Deadmines (Westfall, a long trip for Horde)" },
  { id = 5322,  slot = "2H",  lvl = 24, approx = true, how = "Quest", src = "Weapons of Choice (Tatternack Steelforge)", zone = "The Barrens, Camp Taurajo" },
  { id = 6909,  slot = "2H",  lvl = 26, how = "Dungeon", src = "Aku'mai", zone = "Blackfathom Deeps" },
  { id = 6687,  slot = "2H",  lvl = 29, how = "Dungeon", src = "Overlord Ramtusk", zone = "Razorfen Kraul" },
  { id = 3855,  slot = "2H",  lvl = 32, how = "Crafted", src = "Blacksmithing", zone = "Your own craft (iron)", bs = 185, ah = true },
  { id = 3845,  slot = "Chest", lvl = 35, how = "Crafted", src = "Blacksmithing", zone = "Your own craft (gold and steel)", bs = 195, ah = true },
  { id = 7718,  slot = "Shoulder", lvl = 37, how = "Dungeon", src = "Herod", zone = "Scarlet Monastery: Armory" },
  { id = 7719,  slot = "Head", lvl = 37, how = "Dungeon", src = "Herod", zone = "Scarlet Monastery: Armory" },
  { id = 7717,  slot = "2H",  lvl = 37, how = "Dungeon", src = "Herod", zone = "Scarlet Monastery: Armory" },
  { id = 7723,  slot = "2H",  lvl = 39, how = "Dungeon", src = "Scarlet Commander Mograine", zone = "Scarlet Monastery: Cathedral" },
  { id = 9679,  slot = "2H",  lvl = 43, approx = true, how = "Quest", src = "Threat From the Sea (Tok'Kar)", zone = "Swamp of Sorrows" },
  { id = 9418,  slot = "2H",  lvl = 44, how = "Dungeon", src = "Archaedas", zone = "Uldaman" },
  { id = 7960,  slot = "2H",  lvl = 47, how = "Crafted", src = "Blacksmithing (Weaponsmith plans)", zone = "Bind on Equip", bs = 260, ah = true },
  { id = 17766, slot = "2H",  lvl = 49, how = "Dungeon", src = "Princess Theradras", zone = "Maraudon" },
  { id = 17713, slot = "Ring", lvl = 49, how = "Dungeon", src = "Princess Theradras", zone = "Maraudon" },
  { id = 10652, slot = "2H",  lvl = 50, approx = true, how = "Quest", src = "Weapons of Spirit (Witch Doctor Uzer'i)", zone = "Feralas, Camp Mojache" },
  { id = 11907, slot = "2H",  lvl = 50, approx = true, how = "Quest",   src = "The Mighty U'cha", zone = "Un'Goro Crater" },
  { id = 11726, slot = "Chest", lvl = 52, how = "Dungeon", src = "Gorosh the Dervish", zone = "Blackrock Depths" },
  { id = 11815, slot = "Trinket", lvl = 53, how = "Dungeon", src = "Rare drop", zone = "Blackrock Depths" },
  { id = 15063, slot = "Hands", lvl = 53, how = "Crafted", src = "Leatherworking", zone = "Often sold on the Auction House", ah = true },
  { id = 12422, slot = "Chest", lvl = 55, how = "Crafted", src = "Blacksmithing", zone = "Your own craft (20 Thorium Bars)", bs = 300, ah = true },
  { id = 13400, slot = "Wrist", lvl = 54, how = "Dungeon", src = "Timmy the Cruel", zone = "Stratholme" },
  { id = 15062, slot = "Legs", lvl = 55, how = "Crafted", src = "Tribal Leatherworking", zone = "Bind on Equip", ah = true },
  { id = 12927, slot = "Shoulder", lvl = 56, how = "Dungeon", src = "Pyroguard Emberseer", zone = "Upper Blackrock Spire" },
  { id = 12640, slot = "Head", lvl = 56, how = "Crafted", src = "Blacksmithing (epic)", zone = "Bind on Equip", bs = 300, ah = true },
  { id = 12784, slot = "2H",  lvl = 58, how = "Crafted", src = "Blacksmithing (Axesmith)", zone = "Bind on Equip", bs = 300, ah = true },
  { id = 13505, slot = "2H",  lvl = 58, how = "Dungeon", src = "Baron Rivendare", zone = "Stratholme" },
  { id = 13340, slot = "Back", lvl = 58, how = "Dungeon", src = "Baron Rivendare", zone = "Stratholme" },
  { id = 18538, slot = "2H",  lvl = 58, how = "Dungeon", src = "Gordok Tribute chest (after killing the King)", zone = "Dire Maul North" },
  { id = 15411, slot = "Neck", lvl = 58, approx = true, how = "Quest", src = "In Dreams (Tirion Fordring chain)", zone = "Eastern Plaguelands" },
  { id = 13965, slot = "Trinket", lvl = 58, approx = true, how = "Dungeon", src = "General Drakkisath", zone = "Upper Blackrock Spire" },
}

-- Class milestones merged into the leveling route (o = position in the route).
P.route = {
  { o = 1, from = 1,  to = 5,  kind = "pala",    zone = "Paladin", hub = "Deathknell class quests", notes = "Forsaken paladin starter quests in the Deathknell chapel: they teach Holy Light and send you to Brill." },
  { o = 2, from = 10, to = 19, kind = "pala",    zone = "Paladin", hub = "Bandarion Keep", notes = "The Forsaken paladin home in the Whispering Wood, north-west Tirisfal. Most of your class quests come from here." },
  { o = 10, from = 20, to = 26, kind = "pala",    zone = "Paladin", hub = "Wolf's Bane (level 20)", notes = "Your class weapon quest: a slow holy-proc weapon from three dungeon materials. Take Seal of Command at 20." },
  { o = 23, from = 40, to = 40, kind = "pala",    zone = "Paladin", hub = "Level 40", notes = "A Trusty Steed: your Forsaken Warhorse. Blacksmiths can pick a specialization (Axesmith for Arcanite Reaper)." },
  { o = 40, from = 60, to = 60, kind = "pala",    zone = "Paladin", hub = "Level 60", notes = "Justice and Retribution: the Forsaken Charger epic mount chain (the Retribution path for Horde paladins)." },
}

-- Travel tips for this class, merged into the route by level.
P.travel = {
  { lvl = 40, text = "Paladin warhorse at 40. From here, run new flight paths as you enter each zone instead of waiting to come back." },
}

-- Forsaken paladin class quests (names from WoW Forever beta guides), so the route can tick them off.
P.classQuests = { "A Difficult Path", "Rediscovering the Light", "Coming to Terms", "Continue Your Training", "Wolf's Bane", "A Trusty Steed", "Justice and Retribution" }

-- Step-by-step to-do lists for the class milestones, keyed by "Paladin|from".
P.steps = {
  ["Paladin|1"] = {
    "A Difficult Path: Shadow Priest Sarvis in the Deathknell chapel gives you a Consecrated Scroll. Read it and meet Aramis Hammerhand in the chapel.",
    "Rediscovering the Light (level 2): use Holy Light on five Injured Deathguard beside the Deathknell chapel, then return to Aramis Hammerhand. Do it before Night Web's Hollow.",
    "Coming to Terms (level 4): find the Frightened Paladin in the hills west of the chapel, offer aid, and go back to Aramis Hammerhand.",
    "Continue Your Training (level 4): report to Shari Stilwell in Brill.",
  },
  ["Paladin|10"] = {
    "At level 10, head into the Whispering Wood in north-west Tirisfal to Bandarion Keep, the Forsaken paladin hold.",
    "Take every class quest there. Players report a Lesson in Divinity chain with Murlocs at the Gates and The Tarnished; follow whatever the keep offers.",
    "Come back to Bandarion Keep each time you train new paladin spells: new class quests unlock as you level.",
  },
  ["Paladin|20"] = {
    "Put your first 10 talent points into Retribution so you can take Seal of Command at level 20.",
    "Wolf's Bane starts on Fenris Isle in Silverpine: rescue Lumina Windsinger and bring her to safety. Trevan then explains the weapon and its three materials.",
    "Enchanted Silver Ingot: drops in Shadowfang Keep. Do it with your SFK run.",
    "Purified Kor Gem: Blackfathom Deeps. First take Olric Frostvale's quest in Ashenvale, or the gem won't drop.",
    "Whitestone Oak Lumber: The Deadmines in Westfall. A long trip for Horde: group up and do it in one go.",
    "Bring the three materials to Orrt in Tarren Mill to forge the Moonsilver Blade, then Lumina Windsinger empowers it.",
    "Finish by defeating Old Fire Eye near the Gilneas gates in south Silverpine. Wolf's Bane is yours: slow (3.4), +10 Strength, +9 Stamina and a holy blast that hits wolves and worgen three times as hard.",
  },
  ["Paladin|40"] = {
    "A Trusty Steed: get your Forsaken Warhorse (riding training plus the class quest); travel gets much faster from here.",
    "At Blacksmithing 250 you can specialize. Axesmith leads to Arcanite Reaper.",
  },
  ["Paladin|60"] = {
    "Justice and Retribution: start the epic Forsaken Charger chain (the Retribution path for Horde paladins). The steps aren't published yet; check Bandarion Keep.",
    "Keep farming dungeons for pre-raid gear while you work on it.",
  },
}

-- Retribution talents in the order to take them while leveling with a
-- two-hander. Names are WoW Forever's (Icy Veins, Mobalytics, Warcraft Tavern).
-- The planner reads your real talent tree, skips anything you can't take yet,
-- and suggests the first one with points left.
P.talents = {
  { name = "Seal of Command", why = "Your main damage Seal with a slow two-hander." },
  { name = "Two-Handed Weapon Specialization", why = "+3% two-handed damage per point." },
  { name = "Vengeance", why = "Crits stack up to 5 times for more Physical and Holy damage." },
  { name = "Crusade", why = "+1% damage per point, and another 1% against Undead and Demons." },
  { name = "Conviction", why = "More critical strikes, which feed Vengeance." },
  { name = "Sacred Arbiter", why = "Holy Strike hits 10% harder and refreshes your Judgements." },
  { name = "Sanctified Judgement", why = "Judgement refunds Seal mana, so you drink less." },
  { name = "Benediction", why = "Cheaper instant spells: more Holy Strikes and Judgements per mana bar." },
  { name = "Holy Conduit", why = "Cheaper Exorcism, Consecration and Hammer of Wrath." },
  { name = "Vindication", why = "Weakens what you hit and gives you Attack Power." },
  { name = "Pursuit of Justice", why = "Faster mounted speed for getting around." },
  { name = "Twist of Light", why = "Seal-twisting for extra damage once you're comfortable." },
}

-- Leveling priority, adjusted for Forever's changes (Judgement no longer uses
-- up your Seal; Holy Strike is baseline at 6).
P.rotation = {
  "Before a long session, make camp: campfire + Sharpening Wheel, sit for a minute, and you're buffed for an hour.",
  "Keep Blessing of Might on yourself (1 hour in Forever).",
  "Seal of Command up (Seal of Righteousness before 20). Judgement no longer removes it.",
  "Holy Strike on cooldown. It's Holy damage, so armor doesn't reduce it.",
  "Judgement on cooldown.",
  "Exorcism on Undead and Demons. Hammer of Wrath when a target is below 20% health.",
  "Consecration when 2 to 4 enemies are on you. It's weak past 4 targets.",
}

-- Extra notes under the talent list: { heading, text }
P.talentNotes = {
  { "Undead and Demons", "Undead fill Tirisfal, Silverpine, the Plaguelands, Stratholme and Scholomance. Exorcism and Crusade's bonus make you much stronger there, and Holy Wrath stuns them." },
}

RG.RegisterClass("PALADIN", P)
