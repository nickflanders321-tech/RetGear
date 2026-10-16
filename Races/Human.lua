-- Waypath+ race data: Human. Starting zones (Northshire Valley, Elwynn Forest) and Stormwind travel tips.
local _, RG = ...
local R = { name = "Human", faction = "Alliance", capital = "Stormwind City", start = "Elwynn Forest", gen = true }

R.route = {
  { o = 3, from = 1,  to = 6,  kind = "zone", zone = "Northshire Valley", hub = "Northshire Abbey", notes = "Human start. Do every quest here, then walk out to Goldshire." },
  { o = 4, from = 6,  to = 12, kind = "zone", zone = "Elwynn Forest", hub = "Goldshire", notes = "Goldshire quests, then the farms, mines and Stormwind errands. Learn your professions in Stormwind at 10." },
}
R.travel = {
  { lvl = 6,  text = "Set your hearthstone at the Lion's Pride Inn in Goldshire. You'll be turning in Elwynn quests there for a while.", fp = "Goldshire" },
  { lvl = 10, text = "Stormwind's flight master is in the Dwarven District. Learn your professions in the Trade District and visit your class trainer.", fp = "Stormwind" },
  { lvl = 11, text = "Ride to Westfall for Sentinel Hill's flight path and move your hearthstone there.", fp = "Sentinel Hill" },
  { lvl = 20, text = "The Deeprun Tram in Stormwind's Mage Quarter takes you to Ironforge, the starting point for Loch Modan and the Wetlands boat." },
}
RG.RegisterRace("Human", R)
