-- Waypath+ race data: Undead (Forsaken). Starting zones, the first leg of the
-- route (Tirisfal Glades and Silverpine Forest) and Undercity travel tips.
local _, RG = ...
local R = { name = "Undead", faction = "Horde", capital = "Undercity", start = "Tirisfal Glades" }

-- Starting zones merged into the leveling route (o = position in the route).
R.route = {
  { o = 3, from = 1,  to = 6,  kind = "zone",    zone = "Tirisfal Glades", hub = "Deathknell", notes = "Undead start. Do every quest here, then run to Brill." },
  { o = 4, from = 6,  to = 12, kind = "zone",    zone = "Tirisfal Glades", hub = "Brill", notes = "Brill quests, then Bandarion Keep (Whispering Wood) for paladin class quests. Learn Mining and Blacksmithing in Undercity." },
  { o = 5, from = 10, to = 20, kind = "zone",    zone = "Silverpine Forest", hub = "The Sepulcher", fp = "The Sepulcher", notes = "Main 10-20 zone. Copper and Tin along the road." },
}

-- Travel tips from an Undercity start, merged into the route by level.
R.travel = {
  { lvl = 6,  text = "Set your hearthstone at the Brill inn. You'll be turning in Tirisfal quests there for a while." },
  { lvl = 10, text = "Grab the Undercity flight path (flight master up top at the Ruins of Lordaeron) and train Mining and Blacksmithing in Undercity.", fp = "Undercity" },
  { lvl = 11, text = "Run to Silverpine and grab The Sepulcher flight path as soon as you arrive. Move your hearthstone there.", fp = "The Sepulcher" },
  { lvl = 17, text = "Take the zeppelin from the tower outside Undercity to Orgrimmar. Grab the Orgrimmar flight path, then run to the Crossroads for its flight path.", fp = "Orgrimmar" },
  { lvl = 30, text = "The Undercity zeppelin also goes to Grom'gol in Stranglethorn. Grab Grom'gol, then Booty Bay at the south tip.", fp = "Booty Bay" },
  { lvl = 32, text = "Hearth to Undercity for Scarlet Monastery runs: it's a short ride north from Brill." },
}

-- Step-by-step to-do lists for the starting zones.
R.steps = {
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
}

RG.RegisterRace("Scourge", R)
