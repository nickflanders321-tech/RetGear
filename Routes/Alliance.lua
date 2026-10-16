-- Waypath+ Alliance leveling route: the zones and dungeons every Alliance character
-- shares once the starting zones are done. Races add their starting zones and
-- classes their milestones (see Races/ and Classes/).
-- The quest steps for these zones are generated from WoW Forever's quest data
-- (Routes/Generated.lua, letter F); zone order, level ranges, hubs and travel are written here.
-- kind: "zone" = questing zone, "dungeon" = dungeon to run at that level.
-- o = position in the merged route (keeps the order the route was written in).
local _, RG = ...
local A = { faction = "Alliance", gen = true }

A.route = {
  { o = 6,  from = 10, to = 18, kind = "zone", zone = "Westfall", hub = "Sentinel Hill", fp = "Sentinel Hill", notes = "Humans and Skyborne come straight from Elwynn; others fly or ride from Stormwind. The Defias chain leads into the Deadmines." },
  { o = 6.5, from = 10, to = 18, kind = "zone", zone = "Loch Modan", hub = "Thelsamar", fp = "Thelsamar", notes = "Dwarves and Gnomes are close; everyone else takes the Ironforge tram or flies. Miners: Copper and Tin." },
  { o = 7,  from = 12, to = 21, kind = "zone", zone = "Darkshore", hub = "Auberdine", fp = "Auberdine", notes = "Night Elves walk from Teldrassil; others take the boat from Stormwind Harbor or Menethil. Long quest chains, great at 14-20." },
  { o = 8,  from = 15, to = 24, kind = "zone", zone = "Redridge Mountains", hub = "Lakeshire", fp = "Lakeshire", notes = "East of Elwynn. Lakeshire's quests lead on to Duskwood." },
  { o = 8.5, from = 17, to = 24, kind = "dungeon", zone = "The Deadmines", hub = "Westfall", notes = "Under Moonbrook in Westfall. The classic first dungeon: 5-player, about 45 minutes." },
  { o = 9,  from = 17, to = 24, kind = "dungeon", zone = "Wailing Caverns", hub = "The Barrens", notes = "In The Barrens. Alliance reach it through Ashenvale and Stonetalon, or by boat and a long ride." },
  { o = 10, from = 20, to = 30, kind = "zone", zone = "Ashenvale", hub = "Astranaar", fp = "Astranaar", notes = "Main 20-30 zone for Night Elves and a strong alternative for everyone." },
  { o = 11, from = 22, to = 30, kind = "zone", zone = "Duskwood", hub = "Darkshire", fp = "Darkshire", notes = "Dark forest south of Redridge. Many quests; Darkshire's inn is the hub." },
  { o = 11.5, from = 22, to = 30, kind = "dungeon", zone = "The Stockade", hub = "Stormwind City", notes = "In the Mage Quarter of Stormwind. Short, good for quick levels." },
  { o = 12, from = 21, to = 27, kind = "zone", zone = "Stonetalon Mountains", hub = "Stonetalon Peak", fp = "Stonetalon Peak", notes = "Mixed with Ashenvale. Miners: Tin and a little Iron." },
  { o = 13, from = 21, to = 31, kind = "zone", zone = "Wetlands", hub = "Menethil Harbor", fp = "Menethil Harbor", notes = "Boats from Menethil go to Darkshore and Theramore. Dwarf and Gnome quests continue here." },
  { o = 14, from = 22, to = 30, kind = "dungeon", zone = "Shadowfang Keep", hub = "Silverpine Forest", notes = "In Silverpine Forest, in Horde land. Most Alliance groups go to Blackfathom Deeps or the Stockade instead." },
  { o = 14.5, from = 24, to = 32, kind = "dungeon", zone = "Blackfathom Deeps", hub = "Ashenvale", notes = "On the Ashenvale coast, at the Blackfathom Deeps entrance by Zoram Strand." },
  { o = 15, from = 27, to = 35, kind = "zone", zone = "Hillsbrad Foothills", hub = "Southshore", fp = "Southshore", notes = "Good mix with Ashenvale and Arathi. Miners: Tin and Silver." },
  { o = 15.5, from = 26, to = 31, kind = "dungeon", zone = "Excavation Site", hub = "Wetlands", notes = "New Forever dungeon in the Wetlands (26-31)." },
  { o = 15.7, from = 28, to = 33, kind = "dungeon", zone = "City of Dalaran", hub = "Alterac Mountains / Hillsbrad", notes = "New Forever dungeon: the sealed city of Dalaran (28-33). Southshore is the closest Alliance town." },
  { o = 16, from = 29, to = 38, kind = "dungeon", zone = "Gnomeregan", hub = "Dun Morogh", notes = "Entrance in Dun Morogh, in the Gnomeregan ruins past Kharanos." },
  { o = 16.5, from = 29, to = 38, kind = "dungeon", zone = "Razorfen Kraul", hub = "The Barrens", notes = "South of Camp Taurajo, deep in Horde land." },
  { o = 17, from = 30, to = 42, kind = "zone", zone = "Thousand Needles", hub = "Theramore / Feathermoon", notes = "Quests from the Theramore side and the Gnomish Great Lift." },
  { o = 18, from = 33, to = 38, kind = "zone", zone = "Dustwallow Marsh", hub = "Theramore Isle", fp = "Theramore", notes = "Reached by boat from Menethil Harbor." },
  { o = 19, from = 33, to = 41, kind = "zone", zone = "Desolace", hub = "Nijel's Point", fp = "Nijel's Point", notes = "Centaur and ghost quests. Miners: Iron." },
  { o = 20, from = 33, to = 40, kind = "zone", zone = "Arathi Highlands", hub = "Refuge Pointe", fp = "Refuge Pointe", notes = "Its quests are 34-42 in Forever, so come at 33. Miners: great Iron and Gold." },
  { o = 21, from = 33, to = 45, kind = "dungeon", zone = "Scarlet Monastery", hub = "Tirisfal Glades", notes = "North-east Tirisfal Glades. Alliance groups usually run it from a flight to Undercity's side; four wings." },
  { o = 22, from = 32, to = 48, kind = "zone", zone = "Stranglethorn Vale", hub = "Booty Bay / Rebel Camp", fp = "Booty Bay", notes = "Nesingwary hunting quests and Booty Bay. Miners: Iron and Mithril up north." },
  { o = 23, from = 35, to = 42, kind = "zone", zone = "Swamp of Sorrows", hub = "Stormwind side: Blasted Lands border", notes = "Small Alliance quest set; Stonard is Horde." },
  { o = 24, from = 37, to = 44, kind = "zone", zone = "Badlands", hub = "Dustbelch Grotto / Uldaman", notes = "Uldaman is here. Miners: Mithril." },
  { o = 24.5, from = 37, to = 46, kind = "dungeon", zone = "Razorfen Downs", hub = "The Barrens / Thousand Needles", notes = "South end of The Barrens." },
  { o = 25, from = 38, to = 43, kind = "zone", zone = "Shen'Dralas", hub = "Shen'Dralas", notes = "New Forever zone, quests from level 38." },
  { o = 25.5, from = 41, to = 51, kind = "dungeon", zone = "Uldaman", hub = "Badlands", notes = "In the north of the Badlands." },
  { o = 26, from = 41, to = 48, kind = "zone", zone = "Feralas", hub = "Feathermoon Stronghold", fp = "Feathermoon Stronghold", notes = "Feathermoon's boat links to Sardor Isle and the Darnassus side." },
  { o = 27, from = 43, to = 49, kind = "zone", zone = "The Hinterlands", hub = "Aerie Peak", fp = "Aerie Peak", notes = "Miners: Mithril and Truesilver." },
  { o = 28, from = 44, to = 52, kind = "zone", zone = "Tanaris", hub = "Gadgetzan", fp = "Gadgetzan", notes = "Zul'Farrak is here. Miners: Mithril and Truesilver." },
  { o = 28.5, from = 44, to = 54, kind = "dungeon", zone = "Zul'Farrak", hub = "Tanaris", notes = "In the south of Tanaris." },
  { o = 29, from = 45, to = 50, kind = "zone", zone = "Searing Gorge", hub = "Thorium Point", fp = "Thorium Point", notes = "Miners: Mithril, Truesilver and early Thorium." },
  { o = 30, from = 46, to = 55, kind = "dungeon", zone = "Maraudon", hub = "Desolace", notes = "In Desolace. Long dungeon: do the wings in two runs." },
  { o = 31, from = 50, to = 55, kind = "zone", zone = "Un'Goro Crater", hub = "Marshal's Refuge", fp = "Marshal's Refuge", notes = "Miners: Thorium everywhere." },
  { o = 32, from = 50, to = 56, kind = "zone", zone = "Felwood", hub = "Talonbranch Glade", fp = "Talonbranch Glade", notes = "North of Ashenvale, reached through Moonglade or Winterspring." },
  { o = 33, from = 50, to = 55, kind = "zone", zone = "Burning Steppes", hub = "Morgan's Vigil", fp = "Morgan's Vigil", notes = "Miners: Thorium. Blackrock Mountain is right here." },
  { o = 33.5, from = 50, to = 56, kind = "dungeon", zone = "The Temple of Atal'Hakkar", hub = "Swamp of Sorrows", notes = "The Sunken Temple, in the Swamp of Sorrows." },
  { o = 34, from = 52, to = 60, kind = "dungeon", zone = "Blackrock Depths", hub = "Searing Gorge / Burning Steppes", notes = "Huge dungeon under Blackrock Mountain: plan two or three runs." },
  { o = 35, from = 50, to = 58, kind = "zone", zone = "Blasted Lands", hub = "Nethergarde Keep", fp = "Nethergarde Keep", notes = "Reached through the Swamp of Sorrows." },
  { o = 36, from = 51, to = 58, kind = "zone", zone = "Western Plaguelands", hub = "Chillwind Camp", fp = "Chillwind Camp", notes = "Tirion Fordring's chain starts here." },
  { o = 37, from = 52, to = 58, kind = "zone", zone = "Azshara", hub = "Talrendis Point", fp = "Talrendis Point", notes = "Few quests, good for a break from the grind." },
  { o = 38, from = 53, to = 59, kind = "zone", zone = "Winterspring", hub = "Everlook", fp = "Everlook", notes = "Miners: rich Thorium." },
  { o = 38.5, from = 54, to = 60, kind = "zone", zone = "Eastern Plaguelands", hub = "Light's Hope Chapel", fp = "Light's Hope Chapel", notes = "Tirion Fordring's chain ends in Mark of Fordring." },
  { o = 39, from = 56, to = 60, kind = "zone", zone = "Silithus", hub = "Cenarion Hold", fp = "Cenarion Hold", notes = "Endgame quests; Cenarion Hold is the hub." },
  { o = 40, from = 56, to = 60, kind = "dungeon", zone = "Stratholme, Scholomance, Dire Maul, LBRS/UBRS", hub = "Level 58-60", notes = "The level 58-60 dungeons for pre-raid gear: the gear guide's pre-raid checklist says which ones drop yours." },
}

-- Dungeon quests to collect before each run. The quests themselves come from WoW Forever's
-- quest data (Routes/Generated.lua); go = when to start going, prep = when to start picking up quests.
A.dungeons = {
  ["The Deadmines"] = { go = 17, prep = 15, quests = {} },
  ["Wailing Caverns"] = { go = 19, prep = 17, quests = {} },
  ["The Stockade"] = { go = 22, prep = 20, quests = {} },
  ["Shadowfang Keep"] = { go = 22, prep = 20, quests = {} },
  ["Blackfathom Deeps"] = { go = 24, prep = 22, quests = {} },
  ["Excavation Site"] = { go = 26, prep = 24, quests = {} },
  ["City of Dalaran"] = { go = 28, prep = 26, quests = {} },
  ["Gnomeregan"] = { go = 29, prep = 27, quests = {} },
  ["Razorfen Kraul"] = { go = 29, prep = 27, quests = {} },
  ["Scarlet Monastery"] = { go = 33, prep = 31, quests = {} },
  ["Razorfen Downs"] = { go = 37, prep = 35, quests = {} },
  ["Uldaman"] = { go = 41, prep = 39, quests = {} },
  ["Zul'Farrak"] = { go = 44, prep = 42, quests = {} },
  ["Maraudon"] = { go = 46, prep = 44, quests = {} },
  ["The Temple of Atal'Hakkar"] = { go = 50, prep = 48, quests = {} },
  ["Blackrock Depths"] = { go = 52, prep = 50, quests = {} },
  ["Stratholme, Scholomance, Dire Maul, LBRS/UBRS"] = { go = 56, prep = 54, quests = {} },
}

-- Travel tips merged into the route by level. fp = flight path to grab at that point.
A.travel = {
  { lvl = 12, text = "Grab the Stormwind flight path (Dwarven District) and the Ironforge one if you're passing: the tram between the cities is the fast way across.", fp = "Stormwind" },
  { lvl = 13, text = "Darkshore is a boat ride: from Stormwind Harbor or Menethil Harbor to Auberdine. Grab Auberdine's flight path on arrival.", fp = "Auberdine" },
  { lvl = 16, text = "Lakeshire (Redridge) and Darkshire (Duskwood) are the next flight points on the road east.", fp = "Lakeshire" },
  { lvl = 20, text = "Astranaar is the Ashenvale flight point. The Darnassus boat leaves from Auberdine.", fp = "Astranaar" },
  { lvl = 22, text = "Grab Menethil Harbor; boats from there go to Darkshore and Theramore.", fp = "Menethil Harbor" },
  { lvl = 27, text = "Southshore is Hillsbrad's flight point and a short ride from the Alterac side dungeons.", fp = "Southshore" },
  { lvl = 33, text = "Take the Menethil boat to Theramore for Dustwallow, then grab Nijel's Point in Desolace on your way.", fp = "Theramore" },
  { lvl = 35, text = "Booty Bay is the Stranglethorn hub; Rebel Camp is the northern one.", fp = "Booty Bay" },
  { lvl = 43, text = "Aerie Peak (Hinterlands) and Feathermoon Stronghold (Feralas) are the next flight points.", fp = "Aerie Peak" },
  { lvl = 47, text = "Grab Talrendis Point in Azshara if you quest there.", fp = "Talrendis Point" },
  { lvl = 55, text = "Cenarion Hold in Silithus and Moonglade (Nighthaven) are worth grabbing for the endgame quests.", fp = "Cenarion Hold" },
}

A.steps = {}

RG.RegisterRoute("Alliance", A)
