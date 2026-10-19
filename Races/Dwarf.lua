-- Waypath+ race data: Dwarf. Starting zones (Coldridge Valley, Dun Morogh) and Ironforge travel tips.
local _, RG = ...
local R = { name = "Dwarf", faction = "Alliance", capital = "Ironforge", start = "Dun Morogh", gen = true }

R.route = {
  { o = 3, from = 1,  to = 6,  kind = "zone", zone = "Coldridge Valley", hub = "Anvilmar", notes = "Dwarf start. Do every quest here, then walk out to Kharanos." },
  { o = 4, from = 6,  to = 12, kind = "zone", zone = "Dun Morogh", hub = "Kharanos", notes = "Kharanos quests, then the Frostmane trolls and the road to Ironforge." },
}
R.travel = {
  { lvl = 6,  text = "Set your hearthstone at the Thunderbrew Distillery in Kharanos. You'll be turning in Dun Morogh quests there for a while.", fp = "Kharanos" },
  { lvl = 10, text = "Grab the Ironforge flight path. Your class trainer is there too.", fp = "Ironforge" },
  { lvl = 12, text = "Loch Modan is a short walk east from Kharanos: grab Thelsamar's flight path and move your hearthstone.", fp = "Thelsamar" },
  { lvl = 20, text = "The Deeprun Tram in Ironforge takes you to Stormwind for the Westfall and Redridge flights." },
}
RG.RegisterRace("Dwarf", R)
