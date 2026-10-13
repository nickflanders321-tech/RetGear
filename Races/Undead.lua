-- Waypath+ race data: Undead (Forsaken). Starting zones, the first leg of the
-- route (Tirisfal Glades and Silverpine Forest) and Undercity travel tips.
local _, RG = ...
local R = { name = "Undead", faction = "Horde", capital = "Undercity", start = "Tirisfal Glades", gen = true }

-- Starting zones merged into the leveling route (o = position in the route).
R.route = {
  { o = 3, from = 1,  to = 6,  kind = "zone",    zone = "Tirisfal Glades", hub = "Deathknell", notes = "Undead start. Do every quest here, then run to Brill." },
  { o = 4, from = 6,  to = 12, kind = "zone",    zone = "Tirisfal Glades", hub = "Brill", notes = "Brill quests, then the farms and mills around it. Learn your professions in Undercity at 10." },
  { o = 5, from = 10, to = 20, kind = "zone",    zone = "Silverpine Forest", hub = "The Sepulcher", fp = "The Sepulcher", notes = "Main 10-20 zone. Miners: Copper and Tin along the road." },
}

-- Travel tips from an Undercity start, merged into the route by level.
R.travel = {
  { lvl = 6,  text = "Set your hearthstone at the Brill inn. You'll be turning in Tirisfal quests there for a while." },
  { lvl = 10, text = "Grab the Undercity flight path (flight master up top at the Ruins of Lordaeron) and learn your professions in Undercity.", fp = "Undercity" },
  { lvl = 11, text = "Run to Silverpine and grab The Sepulcher flight path as soon as you arrive. Move your hearthstone there.", fp = "The Sepulcher" },
  { lvl = 17, text = "Take the zeppelin from the tower outside Undercity to Orgrimmar. Grab the Orgrimmar flight path, then run to the Crossroads for its flight path.", fp = "Orgrimmar" },
  { lvl = 30, text = "The Undercity zeppelin also goes to Grom'gol in Stranglethorn. Grab Grom'gol, then Booty Bay at the south tip.", fp = "Booty Bay" },
  { lvl = 32, text = "Hearth to Undercity for Scarlet Monastery runs: it's a short ride north from Brill." },
}

-- Quest steps for these zones are generated from the WoW Forever quest data
-- (Routes/Generated.lua), like every other race's.

RG.RegisterRace("Scourge", R)
