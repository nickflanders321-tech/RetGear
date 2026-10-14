-- Waypath+ Horde leveling route: the zones and dungeons every Horde character
-- shares once the starting zones are done. Races add their starting zones and
-- classes their milestones (see Races/ and Classes/).
-- kind: "zone" = questing zone, "dungeon" = dungeon to run at that level.
-- o = position in the merged route (keeps the order the route was written in).
local _, RG = ...
local H = { faction = "Horde" }

H.route = {
  { o = 6, from = 16, to = 22, kind = "dungeon", zone = "Ruins of Lordaeron", hub = "Undercity", notes = "New Forsaken dungeon in the ruins above Undercity (take the Orgrimmar zeppelin to Tirisfal if you started in Kalimdor). Several quests, with good weapon rewards." },
  { o = 7, from = 13, to = 18, kind = "dungeon", zone = "Ragefire Chasm", hub = "Orgrimmar", notes = "Inside Orgrimmar, in the Cleft of Shadow. Undead: take the zeppelin from outside Undercity." },
  { o = 8, from = 17, to = 24, kind = "dungeon", zone = "Wailing Caverns", hub = "The Barrens", notes = "Grab the dungeon quests at the Crossroads first." },
  { o = 9, from = 18, to = 26, kind = "zone",    zone = "The Barrens", hub = "The Crossroads / Camp Taurajo", fp = "Crossroads", notes = "Lots of quests, with good weapon rewards at Camp Taurajo." },
  { o = 11, from = 22, to = 30, kind = "dungeon", zone = "Shadowfang Keep", hub = "Silverpine Forest", notes = "In Silverpine Forest, south of The Sepulcher. From Kalimdor, take the Orgrimmar zeppelin to Tirisfal." },
  { o = 12, from = 22, to = 27, kind = "zone",    zone = "Stonetalon Mountains", hub = "Sun Rock Retreat", fp = "Sun Rock Retreat", notes = "Miners: Tin and a little Iron." },
  { o = 13, from = 24, to = 32, kind = "dungeon", zone = "Blackfathom Deeps", hub = "Ashenvale", notes = "On the Ashenvale coast, by Zoram'gar Outpost." },
  { o = 14, from = 25, to = 30, kind = "zone",    zone = "Hillsbrad Foothills", hub = "Tarren Mill", fp = "Tarren Mill", notes = "Good mix with Ashenvale. Miners: Tin and Silver." },
  { o = 15, from = 25, to = 30, kind = "zone",    zone = "Ashenvale", hub = "Splintertree Post", fp = "Splintertree Post", notes = "" },
  { o = 15.5, from = 26, to = 31, kind = "dungeon", zone = "Excavation Site", hub = "Wetlands", notes = "New Forever dungeon in the Wetlands (26-31)." },
  { o = 15.7, from = 28, to = 33, kind = "dungeon", zone = "City of Dalaran", hub = "Alterac Mountains / Hillsbrad", notes = "New Forever dungeon: the sealed city of Dalaran (28-33). Tarren Mill is the closest Horde town." },
  { o = 16, from = 29, to = 38, kind = "dungeon", zone = "Razorfen Kraul", hub = "The Barrens", notes = "South of Camp Taurajo in The Barrens." },
  { o = 16.5, from = 29, to = 38, kind = "dungeon", zone = "Gnomeregan", hub = "Dun Morogh", notes = "Deep in Alliance land (Dun Morogh): most Horde groups skip it unless a quest sends them." },
  { o = 17, from = 30, to = 35, kind = "zone",    zone = "Thousand Needles", hub = "Freewind Post", fp = "Freewind Post", notes = "Miners: Iron starts showing up." },
  { o = 18, from = 33, to = 40, kind = "zone",    zone = "Arathi Highlands", hub = "Hammerfall", fp = "Hammerfall", notes = "Its quests are 34-42 in Forever, so come at 33, not 30. Miners: great Iron and Gold." },
  { o = 19, from = 32, to = 40, kind = "zone",    zone = "Desolace", hub = "Shadowprey Village", fp = "Shadowprey", notes = "Kolkar and centaur quests. Miners: Iron." },
  { o = 20, from = 33, to = 45, kind = "dungeon", zone = "Scarlet Monastery", hub = "Tirisfal Glades", notes = "North-east Tirisfal Glades, past Brill (Orgrimmar zeppelin to Tirisfal from Kalimdor). Four wings: Graveyard, Library, Armory, Cathedral." },
  { o = 21, from = 32, to = 42, kind = "zone",    zone = "Stranglethorn Vale", hub = "Grom'gol Base Camp", fp = "Grom'gol", notes = "Nesingwary hunting quests. Miners: Iron and Mithril up north." },
  { o = 22, from = 36, to = 42, kind = "zone",    zone = "Dustwallow Marsh", hub = "Brackenwall Village", fp = "Brackenwall", notes = "" },
  { o = 22.5, from = 37, to = 46, kind = "dungeon", zone = "Razorfen Downs", hub = "The Barrens / Thousand Needles", notes = "South end of The Barrens, at the top of the Thousand Needles road." },
  { o = 23, from = 36, to = 44, kind = "zone",    zone = "Riverglades", hub = "Powderfuse Port", notes = "New Forever zone (33-44): take the boat from Tanaris to Powderfuse Port. Quest data for it isn't out yet, so there are no steps here until it is." },
  { o = 24, from = 40, to = 45, kind = "zone",    zone = "Badlands", hub = "Kargath", fp = "Kargath", notes = "Uldaman is here. Miners: Mithril." },
  { o = 25, from = 41, to = 51, kind = "dungeon", zone = "Uldaman", hub = "Badlands", notes = "In the north of the Badlands, near Kargath." },
  { o = 26, from = 40, to = 45, kind = "zone",    zone = "Swamp of Sorrows", hub = "Stonard", fp = "Stonard", notes = "Stonard quests, and Threat From the Sea for a weapon reward." },
  { o = 27, from = 43, to = 48, kind = "zone",    zone = "Tanaris", hub = "Gadgetzan", fp = "Gadgetzan", notes = "Zul'Farrak is here. Miners: Mithril and Truesilver." },
  { o = 28, from = 44, to = 54, kind = "dungeon", zone = "Zul'Farrak", hub = "Tanaris", notes = "" },
  { o = 29, from = 44, to = 50, kind = "zone",    zone = "Feralas", hub = "Camp Mojache", fp = "Camp Mojache", notes = "Camp Mojache quests; Weapons of Spirit has weapon rewards." },
  { o = 30, from = 46, to = 55, kind = "dungeon", zone = "Maraudon", hub = "Desolace", notes = "In Desolace, west of Shadowprey Village's road. Long dungeon: do the wings in two runs." },
  { o = 31, from = 47, to = 52, kind = "zone",    zone = "The Hinterlands", hub = "Revantusk Village", fp = "Revantusk", notes = "Miners: Mithril and Truesilver." },
  { o = 32, from = 48, to = 54, kind = "zone",    zone = "Searing Gorge", hub = "Thorium Point", fp = "Thorium Point", notes = "Miners: Mithril, Truesilver and early Thorium." },
  { o = 33, from = 50, to = 55, kind = "zone",    zone = "Un'Goro Crater", hub = "Marshal's Refuge", fp = "Marshal's Refuge", notes = "Miners: Thorium everywhere." },
  { o = 33.5, from = 50, to = 56, kind = "dungeon", zone = "The Temple of Atal'Hakkar", hub = "Swamp of Sorrows", notes = "The Sunken Temple, in the Swamp of Sorrows. Stonard is the closest Horde town." },
  { o = 34, from = 52, to = 60, kind = "dungeon", zone = "Blackrock Depths", hub = "Searing Gorge / Burning Steppes", notes = "Huge dungeon under Blackrock Mountain: plan two or three runs." },
  { o = 35, from = 51, to = 55, kind = "zone",    zone = "Felwood", hub = "Bloodvenom Post", fp = "Bloodvenom", notes = "" },
  { o = 36, from = 53, to = 58, kind = "zone",    zone = "Burning Steppes", hub = "Flame Crest", fp = "Flame Crest", notes = "Miners: Thorium." },
  { o = 37, from = 55, to = 60, kind = "zone",    zone = "Winterspring", hub = "Everlook", fp = "Everlook", notes = "Miners: rich Thorium." },
  { o = 38, from = 55, to = 60, kind = "zone",    zone = "Western & Eastern Plaguelands", hub = "The Bulwark / Light's Hope", fp = "Light's Hope", notes = "Tirion Fordring's chain ends in Mark of Fordring." },
  { o = 39, from = 56, to = 60, kind = "dungeon", zone = "Stratholme, Scholomance, Dire Maul, LBRS/UBRS", hub = "Level 58-60", notes = "The level 58-60 dungeons for pre-raid gear: the gear guide's pre-raid checklist says which ones drop yours." },
}

-- Dungeon quests to collect before each run (Horde), and the level to head
-- over. go = when to start going; prep = when to start picking up quests.
-- Quest givers are from the original game; Forever may move some of them.
H.dungeons = {
  ["Ruins of Lordaeron"] = { go = 16, prep = 15, note = "Enter at 16 to be able to take every quest. Run out rather than hearthing: Captain Truman at the entrance takes the Head of the Baron.", quests = {
    { "The Wrath of Rath'mael", "Deathguard Kristof", "Tirisfal Glades, tents between Brill and Undercity" },
    { "Light's Justice", "Morbin Lightbane", "Undercity, Royal Quarter" },
    { "The New Plague", "Theodore Griffs", "Undercity, The Apothecarium" },
    { "A Frightened Request", "Tabitha Heartweaver", "Silverpine Forest, The Sepulcher" },
  } },
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
    { "Blackfathom Villainy", "Argent Guard Thaelrid", "Blackfathom Deeps, inside (hand in to Bashana Runetotem, Thunder Bluff)" },
  } },
  ["Excavation Site"] = { go = 27, prep = 25, quests = {} },
  ["City of Dalaran"] = { go = 29, prep = 27, quests = {} },
  ["Gnomeregan"] = { go = 32, prep = 30, quests = {} },
  ["Razorfen Downs"] = { go = 38, prep = 36, quests = {} },
  ["The Temple of Atal'Hakkar"] = { go = 50, prep = 48, quests = {} },
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
    { "Lost Thunderbrew Recipe", "Shadowmage Vivian Lagrave", "Badlands, Kargath" },
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
    { "Scholomance (starts the key chain)", "High Executor Derrington", "Western Plaguelands, The Bulwark" },
    { "Barov Family Fortune (Scholomance)", "Alexi Barov", "Western Plaguelands, The Bulwark" },
  } },
}

-- Travel tips merged into the route by level. fp = flight path to grab at that point.
H.travel = {
  { lvl = 18, text = "In The Barrens, also grab Ratchet and Camp Taurajo on your way past. Ratchet's boat goes to Booty Bay later.", fp = "Ratchet" },
  { lvl = 20, text = "Detour into Mulgore for the Thunder Bluff flight path. Several dungeon quests start there.", fp = "Thunder Bluff" },
  { lvl = 24, text = "Grab Zoram'gar Outpost on the Ashenvale coast before Blackfathom Deeps.", fp = "Zoram'gar" },
  { lvl = 47, text = "Grab Valormok in Azshara if you quest there; it's a quick hop from Orgrimmar.", fp = "Valormok" },
  { lvl = 55, text = "Cenarion Hold in Silithus and Moonglade (Nighthaven) are worth grabbing for the endgame quests.", fp = "Cenarion Hold" },
}

-- Step-by-step to-do lists for each route entry, keyed by "zone|from".
-- Shown under the route step when you open it; tick each one off as you go.
H.steps = {
  ["Ruins of Lordaeron|16"] = {
    "Pick up the four quests first (listed below): Deathguard Kristof in the tents between Brill and Undercity, Morbin Lightbane and Theodore Griffs in Undercity, Tabitha Heartweaver at The Sepulcher.",
    "The entrance is in the surface ruins above Undercity: go through the front gate, and the portal is up a short flight of stairs before the keep.",
    "Bosses: Witherfang, The Baron, Viktor the Vile (light the fireplace to start him), The Abandoned, Bjork and Rath'mael. The Lordaeron Captain on the west side is Horde-only.",
    "Paladins: Loot the Abominable Head from The Baron (about 13% drop): it starts Unending Torment, whose reward can be the Monstrous Cleaver two-hander.",
    "Light's Justice needs 25 Intact Limbs, which only undead drop, so don't skip the undead packs.",
    "Finish The Wrath of Rath'mael at the last boss, then run out of the dungeon rather than hearthing.",
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
    "Miners: Copper and Tin outcrops along the cliffs and canyon walls.",
  },
  ["Shadowfang Keep|22"] = {
    "Pick up the quests at The Sepulcher and in Undercity first (listed below).",
    "The keep is the castle on the hill above Pyrewood Village in south Silverpine.",
    "Archmage Arugal is the last boss; finish Arugal Must Die there.",
    "Paladins: grab the Enchanted Silver Ingot for Wolf's Bane while you're here.",
  },
  ["Stonetalon Mountains|22"] = {
    "Run west from the Crossroads to Sun Rock Retreat and grab the flight path.",
    "Do the harpy and Windshear Crag quests, including the Venture Co. loggers.",
    "Miners: Tin and your first Iron in the mountain passes.",
  },
  ["Blackfathom Deeps|24"] = {
    "Grab the quests at Zoram'gar Outpost on the Ashenvale coast and in Thunder Bluff (listed below).",
    "The entrance is in the ruins on the Zoram Strand, on Ashenvale's west coast.",
    "Paladins: Aku'mai at the end drops Strike of the Hydra.",
    "Paladins: take Olric Frostvale's quest in Ashenvale first, then collect the Purified Kor Gem here for Wolf's Bane.",
  },
  ["Hillsbrad Foothills|25"] = {
    "From The Sepulcher, follow the road south-east to Tarren Mill and grab the flight path.",
    "Take the Tarren Mill quests: the farms, the Syndicate in the foothills, and the yetis.",
    "Miners: Tin and Silver around the foothills and on the Alterac slopes.",
  },
  ["Ashenvale|25"] = {
    "Go to Splintertree Post in east Ashenvale and grab the flight path.",
    "Do the Warsong Lumber Camp and Splintertree quests. Watch out for Alliance players.",
    "Grab Zoram'gar Outpost on the west coast while you're here for the BFD quests.",
  },
  ["Razorfen Kraul|29"] = {
    "Pick up the quests in Undercity and Thunder Bluff first (listed below).",
    "The entrance is at the far south of The Barrens, past Camp Taurajo.",
    "Paladins: Overlord Ramtusk drops Corpsemaker, a great two-hander at 29.",
  },
  ["Thousand Needles|30"] = {
    "Go south from Camp Taurajo down the Great Lift into Thousand Needles.",
    "Grab the Freewind Post flight path and quests: centaur, harpies and Grimtotem.",
    "The Shimmering Flats in the south-east have the goblin racer quests.",
  },
  ["Arathi Highlands|33"] = {
    "Head east from Tarren Mill into Arathi and follow the road to Hammerfall in the far east. Grab the flight path.",
    "Take the Hammerfall quests: Boulderfist ogres, Witherbark trolls, and the Syndicate.",
    "Miners: Arathi is one of the best Iron and Gold zones. Fill your bags.",
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
    "Paladins: Herod in the Armory drops Ravager, and Mograine in the Cathedral drops Mograine's Might.",
  },
  ["Stranglethorn Vale|32"] = {
    "Take the zeppelin from outside Undercity to Grom'gol and grab the flight path.",
    "Do the Nesingwary hunting quests (tigers, panthers, raptors) at his camp north of Grom'gol.",
    "Collect Green Hills of Stranglethorn pages as they drop and turn them in.",
    "Run south to Booty Bay for its flight path. Miners: Iron and Mithril in the north.",
  },
  ["Dustwallow Marsh|36"] = {
    "Go to Brackenwall Village in west Dustwallow and grab the flight path.",
    "Do the Grimtotem, black dragon and Theramore deserter quests.",
    "Visit Tabetha's hut; her quests point you toward Uldaman and Zul'Farrak.",
  },
  ["Badlands|40"] = {
    "Go to Kargath on the west edge and grab the flight path.",
    "Do the Dark Iron dwarf, ogre and buzzard quests, plus Jarkal's Uldaman reagent run.",
    "Miners: Mithril and Iron along the canyon walls.",
  },
  ["Uldaman|41"] = {
    "Pick up the quests in Kargath, Dustwallow and Orgrimmar first (listed below).",
    "The entrance is in the north of the Badlands.",
    "Paladins: Archaedas at the end drops Stoneslayer.",
  },
  ["Swamp of Sorrows|40"] = {
    "Go to Stonard in the middle of the swamp and grab the flight path.",
    "Take Threat From the Sea from Tok'Kar for Tok'kar's Murloc Chopper.",
    "The Sunken Temple is here for later.",
  },
  ["Tanaris|43"] = {
    "Go to Gadgetzan and grab the flight path.",
    "Do the pirate quests at Lost Rigger Cove, the Wastewander bandits, and the Steamwheedle Port quests.",
    "Miners: Mithril and Truesilver across the dunes.",
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
    "Paladins: Princess Theradras drops her Scepter and the Blackstone Ring.",
  },
  ["The Hinterlands|47"] = {
    "Go to Revantusk Village on the east coast and grab the flight path.",
    "Do the troll and owlbeast quests.",
    "Miners: Mithril and Truesilver in the hills.",
  },
  ["Searing Gorge|48"] = {
    "Go to Thorium Point on the north cliff and grab the flight path.",
    "Do the Dark Iron and golem quests.",
    "Miners: Thorium and Mithril, and the Thorium Point forge to smelt.",
  },
  ["Un'Goro Crater|50"] = {
    "Go to Marshal's Refuge on the north rim and grab the flight path.",
    "Take The Mighty U'cha for Beastslayer, and collect crystals and pylons as you go.",
    "Miners: Thorium veins are everywhere. Mine every one.",
  },
  ["Blackrock Depths|52"] = {
    "Pick up the quests in Kargath and Flame Crest first (listed below).",
    "Blackrock Mountain sits between Searing Gorge and Burning Steppes.",
    "Paladins: Look out for Hand of Justice and the Savage Gladiator Chain from Gorosh.",
  },
  ["Felwood|51"] = {
    "Go to Bloodvenom Post and grab the flight path.",
    "Do the corrupted wildlife and satyr quests.",
  },
  ["Burning Steppes|53"] = {
    "Go to Flame Crest and grab the flight path.",
    "Do the Blackrock orc and black dragon quests.",
    "Miners: Thorium on the ridges.",
  },
  ["Winterspring|55"] = {
    "Go to Everlook and grab the flight path.",
    "Do the Winterfall furbolg and Frostsaber quests.",
    "Miners: rich Thorium veins line the valleys.",
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
}

RG.RegisterRoute("Horde", H)
