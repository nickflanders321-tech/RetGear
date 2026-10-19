-- Waypath+ race data: Orc and Troll. Both start in the Valley of Trials, Durotar,
-- then move on to The Barrens. The quest steps for these zones are generated from
-- the WoW Forever quest data (Routes/Generated.lua); this file sets the route and
-- the travel tips.
local _, RG = ...

local function durotar(name)
  local R = { name = name, faction = "Horde", capital = "Orgrimmar", start = "Durotar", gen = true }
  -- Kalimdor dungeons first: Ragefire Chasm is in Orgrimmar, Wailing Caverns in The Barrens
  R.prefer = { ["Ragefire Chasm"] = 5.1, ["Wailing Caverns"] = 5.2 }
  R.route = {
    { o = 3, from = 1,  to = 6,  kind = "zone", zone = "Valley of Trials", hub = "The Den", notes = name .. " start. Do every quest in the valley, then take the road out to Sen'jin Village and Razor Hill." },
    { o = 4, from = 6,  to = 12, kind = "zone", zone = "Durotar", hub = "Razor Hill / Sen'jin Village", fp = "Orgrimmar", notes = "Razor Hill and Sen'jin Village quests, a first visit to Orgrimmar for its flight path, then west over the bridge into The Barrens." },
    { o = 5, from = 12, to = 20, kind = "zone", zone = "The Barrens", hub = "The Crossroads", fp = "Crossroads", notes = "The Crossroads is your base until 20. Ratchet and Camp Taurajo come later in the zone." },
  }
  R.travel = {
    { lvl = 6,  text = "Make Razor Hill your home at its inn: most of Durotar's quests turn in there or at Sen'jin Village." },
    { lvl = 10, text = "Run north into Orgrimmar: grab the flight path at the top of the tower and visit your class trainer.", fp = "Orgrimmar" },
    { lvl = 12, text = "Cross the bridge west into The Barrens and grab the Crossroads flight path. Make the Crossroads your home.", fp = "Crossroads" },
    { lvl = 17, text = "Optional: the zeppelin from the towers outside Orgrimmar goes to Tirisfal (Undercity) for Silverpine, the Ruins of Lordaeron and Shadowfang Keep." },
    { lvl = 30, text = "The other Orgrimmar zeppelin goes to Grom'gol in Stranglethorn. Grab Grom'gol, then Booty Bay at the south tip.", fp = "Booty Bay" },
    { lvl = 32, text = "Scarlet Monastery is in Tirisfal: take the Undercity zeppelin from outside Orgrimmar and ride north-east from Brill." },
  }
  return R
end
RG.RegisterRace("Orc", durotar("Orc"))
RG.RegisterRace("Troll", durotar("Troll"))
