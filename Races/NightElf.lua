-- Waypath+ race data: Night Elf. Starting zones (Shadowglen, Teldrassil) and Darnassus travel tips.
local _, RG = ...
local R = { name = "Night Elf", faction = "Alliance", capital = "Darnassus", start = "Teldrassil", gen = true }

R.route = {
  { o = 3, from = 1,  to = 6,  kind = "zone", zone = "Shadowglen", hub = "Shadowglen", notes = "Night Elf start. Do every quest here, then follow the road to Dolanaar." },
  { o = 4, from = 6,  to = 12, kind = "zone", zone = "Teldrassil", hub = "Dolanaar", notes = "Dolanaar quests, then Starbreeze Village and the tree's lower paths." },
}
R.travel = {
  { lvl = 6,  text = "Set your hearthstone at the Dolanaar inn. You'll be turning in Teldrassil quests there for a while.", fp = "Dolanaar" },
  { lvl = 10, text = "Darnassus is up the path from Dolanaar: visit your class trainer.", fp = "Darnassus" },
  { lvl = 12, text = "The portal and boat at Rut'theran Village take you to Auberdine in Darkshore. Grab its flight path and move your hearthstone there.", fp = "Auberdine" },
  { lvl = 20, text = "Darkshore's quests lead on to Ashenvale (Astranaar) and the Stonetalon road. Westfall and Elwynn are a boat ride away from Auberdine." },
}
RG.RegisterRace("NightElf", R)
