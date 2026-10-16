-- Waypath+ race data: Skyborne (the Alliance side). Every Skyborne starts on Zephras Isle (1-12), then moves on to Westfall. Quest steps come from the WoW Forever quest data (Routes/Generated.lua).
local _, RG = ...
local R = { name = "Skyborne", faction = "Alliance", capital = "Stormwind City", start = "Zephras Isle", gen = true }

R.route = {
  { o = 3, from = 1,  to = 12, kind = "zone", zone = "Zephras Isle", hub = "Shen'dar Village / Valanaar", notes = "Skyborne start. Zephras Isle runs to level 12: follow the main story from the starting grove to Shen'dar Village and Valanaar. Miners: it has its own Mining trainers and Copper." },
}
R.travel = {
  { lvl = 12, text = "When Zephras is done, take your way off the island to Westfall (Sentinel Hill). Grab its flight path, visit your class trainer in Stormwind and learn your professions.", fp = "Sentinel Hill" },
  { lvl = 14, text = "Make Sentinel Hill or Lakeshire your base, then continue with the shared Alliance route." },
}
RG.RegisterRace("SkyborneA", R)
