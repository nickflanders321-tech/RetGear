-- RetGear data: stat weights and the leveling gear guide.
local _, RG = ...

-- Default stat weights for a standard 2H Retribution Paladin, in Attack Power
-- equivalents (1 AP = 1.0). Vanilla-style numbers: 1 Strength = 2 AP for a
-- paladin, 1% crit or 1% hit is worth roughly 20-25 AP, and a slow two-hander's
-- weapon DPS is the single biggest stat while leveling (Seal of Command and
-- Seal of Righteousness both scale with it). Change any of these in game with
-- /rg weight <stat> <value>.
RG.DEFAULT_WEIGHTS = {
  STR        = 2.2,   -- Strength
  AGI        = 1.0,   -- Agility (crit only for paladins)
  AP         = 1.0,   -- Attack Power
  CRIT       = 22,    -- per 1% critical strike chance
  HIT        = 25,    -- per 1% hit chance (only up to the hit cap)
  STA        = 0.15,  -- Stamina (survival while leveling)
  INT        = 0.15,  -- Intellect (mana for seals and judgements)
  SPI        = 0.05,
  SP         = 0.3,   -- spell damage / healing ("damage and healing done by magical spells")
  WEAPON_DPS = 14,    -- per point of two-hand weapon DPS
  SLOW_BONUS = 4,     -- per 0.1 sec of weapon speed above 3.0 (slow 2H swings hit harder)
  -- Modern rating stats, in case WoW Forever items use ratings instead of %:
  CRIT_RATING = 1.0,
  HIT_RATING  = 1.0,
  HASTE_RATING = 0.8,
  MASTERY_RATING = 0.6,
  VERS_RATING = 0.7,
}

RG.STAT_LABELS = {
  STR = "Strength", AGI = "Agility", AP = "Attack Power", CRIT = "Crit %", HIT = "Hit %",
  STA = "Stamina", INT = "Intellect", SPI = "Spirit", SP = "Spell Power",
  WEAPON_DPS = "Weapon DPS", SLOW_BONUS = "Slow weapon bonus",
  CRIT_RATING = "Crit rating", HIT_RATING = "Hit rating", HASTE_RATING = "Haste rating",
  MASTERY_RATING = "Mastery rating", VERS_RATING = "Versatility rating",
}

-- Hit chance needed to never miss a boss three levels above you.
RG.DEFAULT_HIT_CAP = 9

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
RG.GUIDE = {
  { tip = true, lvl = 1,  text = "Undead paladins start in Deathknell, Tirisfal Glades. Your class quests run out of Bandarion Keep in the Whispering Wood, north Tirisfal." },
  { tip = true, lvl = 8,  text = "Until your first quest two-hander, buy the slowest 2H axe, mace or sword you can afford from the weapon vendors in Brill or Undercity, or the Auction House." },
  { tip = true, lvl = 20, text = "Check Bandarion Keep for new class quests around level 20. The Horde paladin quest rewards in Forever aren't documented yet; if one gives a two-hander, it's likely a big upgrade." },
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

-- equipLoc -> inventory slot ids it can go in
RG.EQUIP_SLOTS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
  INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RELIC = { 18 }, INVTYPE_RANGED = { 18 },
}

RG.SLOT_NAMES = {
  [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs",
  [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket",
  [14] = "Trinket", [15] = "Back", [16] = "Main Hand", [17] = "Off Hand", [18] = "Relic",
}
RG.SLOT_ORDER = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

-- Mining: where to find each ore on the Horde side, by skill.
RG.MINING = {
  { from = 1,   to = 64,  ore = "Copper",  zones = "Tirisfal Glades, Silverpine Forest, Durotar" },
  { from = 65,  to = 124, ore = "Tin (and Silver)", zones = "Silverpine Forest, Hillsbrad Foothills, The Barrens, Stonetalon Mountains" },
  { from = 125, to = 174, ore = "Iron (and Gold)", zones = "Arathi Highlands, Desolace, Thousand Needles, Stranglethorn Vale" },
  { from = 175, to = 244, ore = "Mithril (and Truesilver)", zones = "Badlands, The Hinterlands, Searing Gorge, Tanaris, Felwood" },
  { from = 245, to = 300, ore = "Thorium", zones = "Un'Goro Crater, Burning Steppes, Winterspring, Eastern Plaguelands, Silithus" },
}

-- Ore and bars whose Auction House prices are tracked for a miner/blacksmith.
RG.MATS = {
  2770, 2840,   -- Copper Ore, Copper Bar
  2771, 3576,   -- Tin Ore, Tin Bar
  2841,         -- Bronze Bar
  2772, 3575,   -- Iron Ore, Iron Bar
  3859,         -- Steel Bar
  3858, 3860,   -- Mithril Ore, Mithril Bar
  6037,         -- Truesilver Bar
  10620, 12359, -- Thorium Ore, Thorium Bar
  12360,        -- Arcanite Bar
}

-- Leveling route for an Undead (Horde) character, zone by zone. This is the
-- classic Horde path; WoW Forever adds new content, so treat it as a backbone.
-- kind: "zone" = questing zone, "dungeon" = dungeon to run at that level,
-- "pala" = paladin milestone.
RG.ROUTE = {
  { from = 1,  to = 6,  kind = "zone",    zone = "Tirisfal Glades", hub = "Deathknell", notes = "Undead start. Do every quest here, then run to Brill." },
  { from = 6,  to = 12, kind = "zone",    zone = "Tirisfal Glades", hub = "Brill", notes = "Brill quests, then Bandarion Keep (Whispering Wood) for paladin class quests. Learn Mining and Blacksmithing in Undercity." },
  { from = 10, to = 20, kind = "zone",    zone = "Silverpine Forest", hub = "The Sepulcher", fp = "The Sepulcher", notes = "Main 10-20 zone. Copper and Tin along the road." },
  { from = 13, to = 18, kind = "dungeon", zone = "Ragefire Chasm", hub = "Orgrimmar", notes = "Take the zeppelin from outside Undercity." },
  { from = 17, to = 24, kind = "dungeon", zone = "Wailing Caverns", hub = "The Barrens", notes = "Grab the dungeon quests at the Crossroads first." },
  { from = 18, to = 26, kind = "zone",    zone = "The Barrens", hub = "The Crossroads / Camp Taurajo", fp = "Crossroads", notes = "Lots of quests. Weapons of Choice at Camp Taurajo gives Demolition Hammer." },
  { from = 20, to = 20, kind = "pala",    zone = "Paladin", hub = "Level 20", notes = "Take Seal of Command in the Retribution tree and check Bandarion Keep for new class quests." },
  { from = 22, to = 30, kind = "dungeon", zone = "Shadowfang Keep", hub = "Silverpine Forest", notes = "Close to home for Undead." },
  { from = 22, to = 27, kind = "zone",    zone = "Stonetalon Mountains", hub = "Sun Rock Retreat", fp = "Sun Rock Retreat", notes = "Tin and a little Iron." },
  { from = 24, to = 32, kind = "dungeon", zone = "Blackfathom Deeps", hub = "Ashenvale", notes = "Aku'mai drops Strike of the Hydra." },
  { from = 25, to = 30, kind = "zone",    zone = "Hillsbrad Foothills", hub = "Tarren Mill", fp = "Tarren Mill", notes = "Tin and Silver. Good mix with Ashenvale." },
  { from = 25, to = 30, kind = "zone",    zone = "Ashenvale", hub = "Splintertree Post", fp = "Splintertree Post", notes = "" },
  { from = 29, to = 38, kind = "dungeon", zone = "Razorfen Kraul", hub = "The Barrens", notes = "Overlord Ramtusk drops Corpsemaker." },
  { from = 30, to = 35, kind = "zone",    zone = "Thousand Needles", hub = "Freewind Post", fp = "Freewind Post", notes = "Iron starts showing up." },
  { from = 30, to = 38, kind = "zone",    zone = "Arathi Highlands", hub = "Hammerfall", fp = "Hammerfall", notes = "Great Iron and Gold mining." },
  { from = 32, to = 40, kind = "zone",    zone = "Desolace", hub = "Shadowprey Village", fp = "Shadowprey", notes = "Iron. Kolkar and centaur quests." },
  { from = 33, to = 45, kind = "dungeon", zone = "Scarlet Monastery", hub = "Tirisfal Glades", notes = "Right in your backyard. Herod (Armory) drops Ravager; Mograine (Cathedral) drops Mograine's Might." },
  { from = 32, to = 42, kind = "zone",    zone = "Stranglethorn Vale", hub = "Grom'gol Base Camp", fp = "Grom'gol", notes = "Nesingwary hunting quests. Iron and Mithril up north." },
  { from = 36, to = 42, kind = "zone",    zone = "Dustwallow Marsh", hub = "Brackenwall Village", fp = "Brackenwall", notes = "" },
  { from = 40, to = 40, kind = "pala",    zone = "Paladin", hub = "Level 40", notes = "Paladin warhorse. Blacksmiths can pick a specialization (Axesmith for Arcanite Reaper)." },
  { from = 40, to = 45, kind = "zone",    zone = "Badlands", hub = "Kargath", fp = "Kargath", notes = "Mithril. Uldaman is here." },
  { from = 41, to = 51, kind = "dungeon", zone = "Uldaman", hub = "Badlands", notes = "Archaedas drops Stoneslayer." },
  { from = 40, to = 45, kind = "zone",    zone = "Swamp of Sorrows", hub = "Stonard", fp = "Stonard", notes = "Threat From the Sea gives Tok'kar's Murloc Chopper." },
  { from = 43, to = 48, kind = "zone",    zone = "Tanaris", hub = "Gadgetzan", fp = "Gadgetzan", notes = "Mithril and Truesilver. Zul'Farrak is here." },
  { from = 44, to = 54, kind = "dungeon", zone = "Zul'Farrak", hub = "Tanaris", notes = "" },
  { from = 44, to = 50, kind = "zone",    zone = "Feralas", hub = "Camp Mojache", fp = "Camp Mojache", notes = "Weapons of Spirit gives Will of the Mountain Giant." },
  { from = 46, to = 55, kind = "dungeon", zone = "Maraudon", hub = "Desolace", notes = "Princess Theradras drops her Scepter and Blackstone Ring." },
  { from = 47, to = 52, kind = "zone",    zone = "The Hinterlands", hub = "Revantusk Village", fp = "Revantusk", notes = "Mithril and Truesilver." },
  { from = 48, to = 54, kind = "zone",    zone = "Searing Gorge", hub = "Thorium Point", fp = "Thorium Point", notes = "Mithril, Truesilver and early Thorium." },
  { from = 50, to = 55, kind = "zone",    zone = "Un'Goro Crater", hub = "Marshal's Refuge", fp = "Marshal's Refuge", notes = "Thorium everywhere. The Mighty U'cha gives Beastslayer." },
  { from = 52, to = 60, kind = "dungeon", zone = "Blackrock Depths", hub = "Searing Gorge / Burning Steppes", notes = "Hand of Justice and Savage Gladiator Chain." },
  { from = 51, to = 55, kind = "zone",    zone = "Felwood", hub = "Bloodvenom Post", fp = "Bloodvenom", notes = "" },
  { from = 53, to = 58, kind = "zone",    zone = "Burning Steppes", hub = "Flame Crest", fp = "Flame Crest", notes = "Thorium." },
  { from = 55, to = 60, kind = "zone",    zone = "Winterspring", hub = "Everlook", fp = "Everlook", notes = "Rich Thorium." },
  { from = 55, to = 60, kind = "zone",    zone = "Western & Eastern Plaguelands", hub = "The Bulwark / Light's Hope", fp = "Light's Hope", notes = "Tirion Fordring's chain ends in Mark of Fordring." },
  { from = 56, to = 60, kind = "dungeon", zone = "Stratholme, Scholomance, Dire Maul, LBRS/UBRS", hub = "Level 58-60", notes = "Pre-raid gear: Rivendare's Runeblade, Treant's Bane, Truestrike Shoulders." },
  { from = 60, to = 60, kind = "pala",    zone = "Paladin", hub = "Level 60", notes = "Epic Charger quest chain (the Retribution path for Horde paladins)." },
}

-- Dungeon quests to collect before each run (Horde), and the level to head
-- over. go = when to start going; prep = when to start picking up quests.
-- Quest givers are from the original game; Forever may move some of them.
RG.DUNGEON_QUESTS = {
  ["Ragefire Chasm"] = { go = 15, prep = 13, quests = {
    { "Hidden Enemies", "Thrall", "Orgrimmar, Grommash Hold" },
    { "Slaying the Beast", "Neeru Fireblade", "Orgrimmar, Cleft of Shadow" },
    { "Searching for the Lost Satchel", "Rahauro", "Thunder Bluff, Elder Rise" },
  } },
  ["Wailing Caverns"] = { go = 19, prep = 17, quests = {
    { "Leaders of the Fang", "Nara Wildmane", "Thunder Bluff, Elder Rise" },
    { "Serpentbloom", "Apothecary Zamah", "Thunder Bluff, Spirit Rise" },
    { "Deviate Eradication", "Ebru", "The Barrens, on the hill above the cave" },
    { "Deviate Hides", "Nalpak", "The Barrens, on the hill above the cave" },
    { "Smart Drinks", "Mebok Mizzyrix", "Ratchet" },
    { "Trouble at the Docks", "Crane Operator Bigglefuzz", "Ratchet" },
  } },
  ["Shadowfang Keep"] = { go = 23, prep = 20, quests = {
    { "Deathstalkers in Shadowfang", "High Executor Hadrec", "Silverpine Forest, The Sepulcher" },
    { "Arugal Must Die", "Dalar Dawnweaver", "Silverpine Forest, The Sepulcher" },
    { "The Book of Ur", "Keeper Bel'dugur", "Undercity, The Apothecarium" },
  } },
  ["Blackfathom Deeps"] = { go = 25, prep = 23, quests = {
    { "The Essence of Aku'Mai", "Je'neu Sancrea", "Ashenvale, Zoram'gar Outpost" },
    { "Amongst the Ruins", "Je'neu Sancrea", "Ashenvale, Zoram'gar Outpost" },
    { "Blackfathom Villainy", "Bashana Runetotem", "Thunder Bluff, Elder Rise" },
  } },
  ["Razorfen Kraul"] = { go = 30, prep = 28, quests = {
    { "Going, Going, Guano!", "Master Apothecary Faranell", "Undercity, The Apothecarium" },
    { "A Vengeful Fate", "Auld Stonespire", "Thunder Bluff" },
    { "Willix the Importer", "Willix (escort)", "Inside Razorfen Kraul" },
  } },
  ["Scarlet Monastery"] = { go = 33, prep = 31, quests = {
    { "Into the Scarlet Monastery", "Varimathras", "Undercity, Royal Quarter" },
    { "Hearts of Zeal", "Master Apothecary Faranell", "Undercity, The Apothecarium" },
    { "Test of Lore", "Parqual Fintallas", "Undercity, Magic Quarter" },
  }, note = "Graveyard ~33, Library ~35, Armory ~37, Cathedral ~39." },
  ["Uldaman"] = { go = 42, prep = 40, quests = {
    { "Uldaman Reagent Run", "Jarkal Mossmeld", "Badlands, Kargath" },
    { "Power in Uldaman", "Tabetha", "Dustwallow Marsh" },
    { "Necklace Recovery", "Dran Droffers", "Orgrimmar, The Drag" },
    { "The Platinum Discs", "Discs of Norgannon", "Inside Uldaman" },
  } },
  ["Zul'Farrak"] = { go = 45, prep = 43, quests = {
    { "Divino-matic Rod", "Chief Engineer Bilgewhizzle", "Tanaris, Gadgetzan" },
    { "Troll Temper", "Trenton Lighthammer", "Tanaris, Gadgetzan" },
    { "Scarab Shells", "Tran'rek", "Tanaris, Gadgetzan" },
    { "Gahz'rilla", "Wizzle Brassbolts", "Thousand Needles, Shimmering Flats" },
    { "Tiara of the Deep", "Tabetha", "Dustwallow Marsh" },
    { "The Prophecy of Mosh'aru", "Yeh'kinya", "Tanaris, Steamwheedle Port" },
  } },
  ["Maraudon"] = { go = 47, prep = 45, quests = {
    { "Vyletongue Corruption", "Vark Battlescar", "Desolace, Shadowprey Village" },
    { "Legends of Maraudon", "Cavindra", "Desolace, outside Maraudon" },
    { "Corruption of Earth and Seed", "Selendra", "Desolace, outside Maraudon" },
    { "Shadowshard Fragments", "Uthel'nay", "Orgrimmar, Valley of Spirits" },
  }, note = "Corruption of Earth and Seed leads toward Princess Theradras." },
  ["Blackrock Depths"] = { go = 53, prep = 51, quests = {
    { "Disharmony of Fire", "Thunderheart", "Badlands, Kargath" },
    { "The Lost Thunderbrew Recipe", "Vivian Lagrave", "Badlands, Kargath" },
    { "Dark Iron Legacy", "Franclorn Forgewright (ghost)", "Blackrock Mountain" },
    { "Ribbly Screwspigot", "Yuka Screwspigot", "Burning Steppes, Flame Crest" },
    { "The Heart of the Mountain", "Maxwort Uberglint", "Burning Steppes, Flame Crest" },
  } },
  ["Stratholme, Scholomance, Dire Maul, LBRS/UBRS"] = { go = 57, prep = 55, quests = {
    { "Warlord's Command (LBRS)", "Warlord Goretooth", "Badlands, Kargath" },
    { "Mother's Milk (LBRS)", "Ragged John", "Burning Steppes" },
    { "Elven Legends (Dire Maul)", "Sage Korolusk", "Feralas, Camp Mojache" },
    { "Pusillin and the Elder Azj'Tordin (Dire Maul)", "Azj'Tordin", "Feralas, Lariss Pavilion" },
    { "The Restless Souls (Stratholme)", "Egan", "Eastern Plaguelands" },
    { "Houses of the Holy (Stratholme)", "Leonid Barthalomew", "Eastern Plaguelands, Light's Hope Chapel" },
    { "Scholomance key chain", "High Executor Derrington", "Western Plaguelands, The Bulwark" },
    { "Barov Family Fortune (Scholomance)", "Alexi Barov", "Western Plaguelands, The Bulwark" },
  } },
}

-- Travel tips, merged into the route. fp = flight path to grab at that point.
RG.TRAVEL = {
  { lvl = 6,  text = "Set your hearthstone at the Brill inn. You'll be turning in Tirisfal quests there for a while." },
  { lvl = 10, text = "Grab the Undercity flight path (flight master up top at the Ruins of Lordaeron) and train Mining and Blacksmithing in Undercity.", fp = "Undercity" },
  { lvl = 11, text = "Run to Silverpine and grab The Sepulcher flight path as soon as you arrive. Move your hearthstone there.", fp = "The Sepulcher" },
  { lvl = 17, text = "Take the zeppelin from the tower outside Undercity to Orgrimmar. Grab the Orgrimmar flight path, then run to the Crossroads for its flight path.", fp = "Orgrimmar" },
  { lvl = 18, text = "In The Barrens, also grab Ratchet and Camp Taurajo on your way past. Ratchet's boat goes to Booty Bay later.", fp = "Ratchet" },
  { lvl = 20, text = "Detour into Mulgore for the Thunder Bluff flight path. Several dungeon quests start there.", fp = "Thunder Bluff" },
  { lvl = 24, text = "Grab Zoram'gar Outpost on the Ashenvale coast before Blackfathom Deeps.", fp = "Zoram'gar" },
  { lvl = 30, text = "The Undercity zeppelin also goes to Grom'gol in Stranglethorn. Grab Grom'gol, then Booty Bay at the south tip.", fp = "Booty Bay" },
  { lvl = 32, text = "Hearth to Undercity for Scarlet Monastery runs: it's a short ride north from Brill." },
  { lvl = 40, text = "Paladin warhorse at 40. From here, run new flight paths as you enter each zone instead of waiting to come back." },
  { lvl = 47, text = "Grab Valormok in Azshara if you quest there; it's a quick hop from Orgrimmar.", fp = "Valormok" },
  { lvl = 55, text = "Cenarion Hold in Silithus and Moonglade (Nighthaven) are worth grabbing for the endgame quests.", fp = "Cenarion Hold" },
}

-- Step-by-step to-do lists for each route entry, keyed by "zone|from".
-- Shown under the route step when you open it; tick each one off as you go.
RG.STEPS = {
  ["Tirisfal Glades|1"] = {
    "When you rise from your grave, talk to Undertaker Mordo, then take his quest to Shadow Priest Sarvis in the Deathknell chapel.",
    "Pick up every quest in the chapel and the houses around the village.",
    "Kill Mindless Zombies, Wretched Zombies and Rattlecage Skeletons in the fields around Deathknell.",
    "Clear the spiders in Night Web's Hollow, the cave just north of the village. Stay near the entrance until level 4.",
    "Visit your class trainer in Deathknell at levels 2 and 4 for new paladin spells.",
    "At level 5-6, follow the road east out of the valley to Brill.",
  },
  ["Tirisfal Glades|6"] = {
    "Talk to the innkeeper in Brill and make it your home.",
    "Take every quest in Brill: the town hall, the inn, and the guards along the road.",
    "Head west to Solliden Farmstead for the pumpkin and Scarlet Crusader quests.",
    "Go north to Agamand Mills for the undead and Agamand family quests.",
    "Ride north to Bandarion Keep in the Whispering Wood for your paladin class quests.",
    "At level 10, go to Undercity: train Mining and Blacksmithing, grab the flight path at the Ruins of Lordaeron, and sell your junk.",
    "Finish the Garren's Haunt and Brightwater Lake quests, mining Copper as you go, then take the south-west road into Silverpine.",
  },
  ["Silverpine Forest|10"] = {
    "Run straight to The Sepulcher and grab the flight path first.",
    "Take every quest there: gnolls, coastal murlocs, and the Dalaran mages.",
    "Work through Fenris Isle and the gnoll camps, then the Dalaran wizards at Ambermill.",
    "Mine every Copper and Tin vein you pass on the main road and around Pyrewood Village.",
    "Do the Pyrewood and worgen quests in the south; they lead toward Shadowfang Keep.",
    "Smelt your ore into bars and keep crafting Blacksmithing items to raise your skill.",
    "At level 17-18, ride the zeppelin from the tower outside Undercity to Orgrimmar.",
  },
  ["Ragefire Chasm|13"] = {
    "Pick up the quests listed below before you go.",
    "The entrance is in the Cleft of Shadow inside Orgrimmar.",
    "Find a group of five. It's a short run, about 20 minutes.",
  },
  ["Wailing Caverns|17"] = {
    "Grab the quests at the Crossroads, Thunder Bluff and Ratchet first (listed below).",
    "The cave is south-west of the Crossroads, under the hill where the druids stand.",
    "Fight through to Mutanus at the end. Escort the Disciple of Naralex to wake Naralex.",
  },
  ["The Barrens|18"] = {
    "From Orgrimmar, run south through Durotar to the Crossroads and grab the flight path.",
    "Take every quest at the Crossroads; this hub keeps you busy for several levels.",
    "Kill quilboars at the Forgotten Pools, harpies in the Dry Hills, and centaur in the north.",
    "Grab the Ratchet flight path and its quests on the east coast.",
    "Go south to Camp Taurajo: take Weapons of Choice from Tatternack Steelforge for the Demolition Hammer.",
    "Mine the Copper and Tin outcrops along the cliffs and canyon walls.",
  },
  ["Paladin|20"] = {
    "Put your first 10 talent points into Retribution so you can take Seal of Command at level 20.",
    "Play it with your slowest two-hander: keep Seal of Command up and Judgement when your mana allows.",
    "Go back to Bandarion Keep and check for new class quests.",
  },
  ["Shadowfang Keep|22"] = {
    "Pick up the quests at The Sepulcher and in Undercity first (listed below).",
    "The keep is the castle on the hill above Pyrewood Village in south Silverpine.",
    "Archmage Arugal is the last boss; finish Arugal Must Die there.",
  },
  ["Stonetalon Mountains|22"] = {
    "Run west from the Crossroads to Sun Rock Retreat and grab the flight path.",
    "Do the harpy and Windshear Crag quests, including the Venture Co. loggers.",
    "Mine Tin and your first Iron in the mountain passes.",
  },
  ["Blackfathom Deeps|24"] = {
    "Grab the quests at Zoram'gar Outpost on the Ashenvale coast and in Thunder Bluff (listed below).",
    "The entrance is in the ruins on the Zoram Strand, on Ashenvale's west coast.",
    "Aku'mai at the end drops Strike of the Hydra.",
  },
  ["Hillsbrad Foothills|25"] = {
    "From The Sepulcher, follow the road south-east to Tarren Mill and grab the flight path.",
    "Take the Tarren Mill quests: the farms, the Syndicate in the foothills, and the yetis.",
    "Mine Tin and Silver around the foothills and on the Alterac slopes.",
  },
  ["Ashenvale|25"] = {
    "Go to Splintertree Post in east Ashenvale and grab the flight path.",
    "Do the Warsong Lumber Camp and Splintertree quests. Watch out for Alliance players.",
    "Grab Zoram'gar Outpost on the west coast while you're here for the BFD quests.",
  },
  ["Razorfen Kraul|29"] = {
    "Pick up the quests in Undercity and Thunder Bluff first (listed below).",
    "The entrance is at the far south of The Barrens, past Camp Taurajo.",
    "Overlord Ramtusk drops Corpsemaker, a great two-hander at 29.",
  },
  ["Thousand Needles|30"] = {
    "Go south from Camp Taurajo down the Great Lift into Thousand Needles.",
    "Grab the Freewind Post flight path and quests: centaur, harpies and Grimtotem.",
    "The Shimmering Flats in the south-east have the goblin racer quests.",
  },
  ["Arathi Highlands|30"] = {
    "Head east from Tarren Mill into Arathi and follow the road to Hammerfall in the far east. Grab the flight path.",
    "Take the Hammerfall quests: Boulderfist ogres, Witherbark trolls, and the Syndicate.",
    "Arathi is one of the best Iron and Gold mining zones. Fill your bags.",
  },
  ["Desolace|32"] = {
    "Go to Shadowprey Village on the south-west coast and grab the flight path.",
    "Do the Kolkar centaur and Burning Blade quests.",
    "Note Maraudon's entrance here; you'll be back in the mid-40s.",
  },
  ["Scarlet Monastery|33"] = {
    "Pick up the three quests in Undercity first (listed below).",
    "Ride north from Brill to the north-east corner of Tirisfal, past the Scarlet Watch Post.",
    "Run the wings in order: Graveyard (~33), Library (~35), Armory (~37), Cathedral (~39).",
    "Herod in the Armory drops Ravager, and Mograine in the Cathedral drops Mograine's Might.",
  },
  ["Stranglethorn Vale|32"] = {
    "Take the zeppelin from outside Undercity to Grom'gol and grab the flight path.",
    "Do the Nesingwary hunting quests (tigers, panthers, raptors) at his camp north of Grom'gol.",
    "Collect Green Hills of Stranglethorn pages as they drop and turn them in.",
    "Run south to Booty Bay for its flight path. Mine Iron and Mithril in the north.",
  },
  ["Dustwallow Marsh|36"] = {
    "Go to Brackenwall Village in west Dustwallow and grab the flight path.",
    "Do the Grimtotem, black dragon and Theramore deserter quests.",
    "Visit Tabetha's hut; her quests point you toward Uldaman and Zul'Farrak.",
  },
  ["Paladin|40"] = {
    "Train your warhorse; travel gets much faster from here.",
    "At Blacksmithing 250 you can specialize. Axesmith leads to Arcanite Reaper.",
  },
  ["Badlands|40"] = {
    "Go to Kargath on the west edge and grab the flight path.",
    "Do the Dark Iron dwarf, ogre and buzzard quests, plus Jarkal's Uldaman reagent run.",
    "Mine Mithril and Iron along the canyon walls.",
  },
  ["Uldaman|41"] = {
    "Pick up the quests in Kargath, Dustwallow and Orgrimmar first (listed below).",
    "The entrance is in the north of the Badlands.",
    "Archaedas at the end drops Stoneslayer.",
  },
  ["Swamp of Sorrows|40"] = {
    "Go to Stonard in the middle of the swamp and grab the flight path.",
    "Take Threat From the Sea from Tok'Kar for Tok'kar's Murloc Chopper.",
    "The Sunken Temple is here for later.",
  },
  ["Tanaris|43"] = {
    "Go to Gadgetzan and grab the flight path.",
    "Do the pirate quests at Lost Rigger Cove, the Wastewander bandits, and the Steamwheedle Port quests.",
    "Mine Mithril and Truesilver across the dunes.",
  },
  ["Zul'Farrak|44"] = {
    "Pick up the quests in Gadgetzan, Steamwheedle Port and Dustwallow first (listed below).",
    "The entrance is in north-west Tanaris.",
    "Gahz'rilla is summoned at the pool with the Mallet of Zul'Farrak.",
  },
  ["Feralas|44"] = {
    "Go to Camp Mojache in east Feralas and grab the flight path.",
    "Take Weapons of Spirit from Witch Doctor Uzer'i for Will of the Mountain Giant.",
    "Dire Maul is in the middle of the zone for later.",
  },
  ["Maraudon|46"] = {
    "Pick up the quests at Shadowprey Village, outside Maraudon and in Orgrimmar first (listed below).",
    "The entrance is in central Desolace.",
    "Princess Theradras drops her Scepter and the Blackstone Ring.",
  },
  ["The Hinterlands|47"] = {
    "Go to Revantusk Village on the east coast and grab the flight path.",
    "Do the troll and owlbeast quests.",
    "Mine Mithril and Truesilver in the hills.",
  },
  ["Searing Gorge|48"] = {
    "Go to Thorium Point on the north cliff and grab the flight path.",
    "Do the Dark Iron and golem quests.",
    "Mine Thorium and Mithril, and smelt in the Thorium Point forge.",
  },
  ["Un'Goro Crater|50"] = {
    "Go to Marshal's Refuge on the north rim and grab the flight path.",
    "Take The Mighty U'cha for Beastslayer, and collect crystals and pylons as you go.",
    "Thorium veins are everywhere. Mine every one.",
  },
  ["Blackrock Depths|52"] = {
    "Pick up the quests in Kargath and Flame Crest first (listed below).",
    "Blackrock Mountain sits between Searing Gorge and Burning Steppes.",
    "Look out for Hand of Justice and the Savage Gladiator Chain from Gorosh.",
  },
  ["Felwood|51"] = {
    "Go to Bloodvenom Post and grab the flight path.",
    "Do the corrupted wildlife and satyr quests.",
  },
  ["Burning Steppes|53"] = {
    "Go to Flame Crest and grab the flight path.",
    "Do the Blackrock orc and black dragon quests.",
    "Mine Thorium on the ridges.",
  },
  ["Winterspring|55"] = {
    "Go to Everlook and grab the flight path.",
    "Do the Winterfall furbolg and Frostsaber quests.",
    "Rich Thorium veins line the valleys.",
  },
  ["Western & Eastern Plaguelands|55"] = {
    "Start at The Bulwark in Western Plaguelands for the plague quests.",
    "In Eastern Plaguelands, grab Light's Hope Chapel's flight path.",
    "Find Tirion Fordring near Terrorweb Path and do his chain for Mark of Fordring.",
  },
  ["Stratholme, Scholomance, Dire Maul, LBRS/UBRS|56"] = {
    "Pick up the quests listed below; several open the doors and keys for these dungeons.",
    "Farm the pre-raid gear in the Gear guide tab: Rivendare's Runeblade, Treant's Bane, Truestrike Shoulders.",
  },
  ["Paladin|60"] = {
    "Start the epic Charger quest chain (the Retribution path for Horde paladins).",
    "Keep farming dungeons for pre-raid gear while you work on it.",
  },
}
