-- Waypath+ race data: Skyborne (Windshapers, the Horde side). Every Skyborne starts
-- on Zephras Isle (1-12); "The Earthen Ring" then sends Horde Skyborne to Mulgore,
-- by Thunder Bluff, and from there into The Barrens. Quest steps are generated from
-- the WoW Forever quest data (Routes/Generated.lua).
local _, RG = ...
local R = { name = "Skyborne", faction = "Horde", capital = "Thunder Bluff", start = "Zephras Isle", gen = true }
-- Kalimdor dungeons first: Ragefire Chasm is in Orgrimmar, Wailing Caverns in The Barrens
R.prefer = { ["Ragefire Chasm"] = 5.1, ["Wailing Caverns"] = 5.2 }
R.route = {
  { o = 3, from = 1,  to = 12, kind = "zone", zone = "Zephras Isle", hub = "Shen'dar Village / Valanaar", notes = "Skyborne start. Zephras Isle runs to level 12: follow the main story from the starting grove to Shen'dar Village and Valanaar. Miners: it has its own Mining trainers and Copper." },
  { o = 4, from = 12, to = 14, kind = "zone", zone = "Mulgore", hub = "Thunder Bluff", fp = "Thunder Bluff", notes = "The Earthen Ring sends you to Alaana Stormwalker in Mulgore, below Thunder Bluff. Set up in Thunder Bluff, then head east into The Barrens." },
  { o = 5, from = 13, to = 20, kind = "zone", zone = "The Barrens", hub = "The Crossroads", fp = "Crossroads", notes = "The Crossroads is your base until 20." },
}
R.travel = {
  { lvl = 12, text = "When Zephras is done, take The Earthen Ring to Mulgore. Grab the Thunder Bluff flight path and visit your class trainer.", fp = "Thunder Bluff" },
  { lvl = 13, text = "Take the road east out of Mulgore into The Barrens: Camp Taurajo's flight path first, then the Crossroads. Make the Crossroads your home.", fp = "Crossroads" },
  { lvl = 14, text = "Run east from the Crossroads to Orgrimmar once for its flight path and the zeppelins.", fp = "Orgrimmar" },
  { lvl = 17, text = "Optional: the zeppelin from the towers outside Orgrimmar goes to Tirisfal (Undercity) for Silverpine, the Ruins of Lordaeron and Shadowfang Keep." },
  { lvl = 30, text = "The other Orgrimmar zeppelin goes to Grom'gol in Stranglethorn. Grab Grom'gol, then Booty Bay at the south tip.", fp = "Booty Bay" },
  { lvl = 32, text = "Scarlet Monastery is in Tirisfal: take the Undercity zeppelin from outside Orgrimmar and ride north-east from Brill." },
}
RG.RegisterRace("Skyborne", R)
