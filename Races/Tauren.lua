-- Waypath+ race data: Tauren. Camp Narache on Red Cloud Mesa, Bloodhoof Village
-- in Mulgore, then The Barrens. Quest steps for these zones are generated from the
-- WoW Forever quest data (Routes/Generated.lua).
local _, RG = ...
local R = { name = "Tauren", faction = "Horde", capital = "Thunder Bluff", start = "Mulgore", gen = true }
-- Kalimdor dungeons first: Ragefire Chasm is in Orgrimmar, Wailing Caverns in The Barrens
R.prefer = { ["Ragefire Chasm"] = 5.1, ["Wailing Caverns"] = 5.2 }
R.route = {
  { o = 3, from = 1,  to = 6,  kind = "zone", zone = "Camp Narache", hub = "Camp Narache", notes = "Tauren start on Red Cloud Mesa. Do every quest at the camp, then follow the road down to Bloodhoof Village." },
  { o = 4, from = 6,  to = 12, kind = "zone", zone = "Mulgore", hub = "Bloodhoof Village", fp = "Thunder Bluff", notes = "Bloodhoof Village quests, the Venture Co. mines, then Thunder Bluff for its flight path before heading east into The Barrens." },
  { o = 5, from = 12, to = 20, kind = "zone", zone = "The Barrens", hub = "The Crossroads", fp = "Crossroads", notes = "The Crossroads is your base until 20; Camp Taurajo is the closest town to Mulgore." },
}
R.travel = {
  { lvl = 6,  text = "Make Bloodhoof Village your home at its inn." },
  { lvl = 10, text = "Ride the lifts up into Thunder Bluff: grab the flight path and visit your class trainer.", fp = "Thunder Bluff" },
  { lvl = 12, text = "Take the road east out of Mulgore into The Barrens. Grab Camp Taurajo's flight path on the way north, then the Crossroads, and make the Crossroads your home.", fp = "Crossroads" },
  { lvl = 14, text = "Run east from the Crossroads to Orgrimmar once for its flight path and the zeppelins.", fp = "Orgrimmar" },
  { lvl = 17, text = "Optional: the zeppelin from the towers outside Orgrimmar goes to Tirisfal (Undercity) for Silverpine, the Ruins of Lordaeron and Shadowfang Keep." },
  { lvl = 30, text = "The other Orgrimmar zeppelin goes to Grom'gol in Stranglethorn. Grab Grom'gol, then Booty Bay at the south tip.", fp = "Booty Bay" },
  { lvl = 32, text = "Scarlet Monastery is in Tirisfal: take the Undercity zeppelin from outside Orgrimmar and ride north-east from Brill." },
}
RG.RegisterRace("Tauren", R)
