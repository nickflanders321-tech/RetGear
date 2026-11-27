-- Waypath+ profession data: Cooking (secondary). In WoW Forever Cooking also makes
-- your campfire, and cooked food gives a little extra XP. Route: wow-professions.com
-- WoW Forever guide (beta data; 225-300 not yet tested on Forever). Pick whichever
-- option you have the fish for (the route follows Fishing: level both together).
local _, RG = ...
local K = { name = "Cooking", kind = "secondary", icon = "Interface\\Icons\\INV_Misc_Food_15" }
K.source = "wow-professions.com WoW Forever guide"
K.train = {
  start = { O = "Cook Torka in Razor Hill", R = "Cook Torka in Razor Hill", T = "Pyall Silentstride in the big tent at Bloodhoof Village", U = "William Pickman in the Brill inn", S = "a Zephras Isle trainer, or any capital" },
  apprentice = "Zamja (Orgrimmar), Eunice Burch (Undercity), Aska Mistrunner (Thunder Bluff)",
  journeyman = "any Cooking trainer (skill 50)",
  expert = "the Expert Cookbook from Wulan (Shadowprey Village, Desolace; skill 125)",
  artisan = "Clamlette Surprise for Dirge Quikcleave in Gadgetzan (skill 225, level 35): take To Gadgetzan You Go! from Zamja in Orgrimmar, and bring 12 Giant Egg, 10 Zesty Clam Meat and 20 Alterac Swiss",
}

-- Alliance: the same trainers, in Stormwind, Ironforge, Darnassus and the starting zones (Profile.lua uses this one for Alliance characters).
K.trainA = {
  start = { H = "Stephen Ryback in Stormwind", D = "Gremlock Pilsnor in Kharanos", G = "Gremlock Pilsnor in Kharanos", N = "Alegorn in Darnassus", A = "Stephen Ryback in Stormwind" },
  apprentice = "Stephen Ryback (Stormwind), Daryl Riknussun (Ironforge), Alegorn (Darnassus), Gremlock Pilsnor (Dun Morogh)",
  journeyman = "any Cooking trainer (skill 50)",
  expert = "the Expert Cookbook (skill 125): a Cooking recipe vendor for your side; not confirmed for WoW Forever yet",
  artisan = "Clamlette Surprise for Dirge Quikcleave in Gadgetzan (skill 225, level 35); bring 12 Giant Egg, 10 Zesty Clam Meat and 20 Alterac Swiss",
}
K.suppliesA = "Simple Wood and Flint and Tinder for the campfire, spices and Refreshing Spring Water: Cooking Supply vendors in Stormwind, Ironforge and Darnassus."
K.supplies = "Simple Wood and Flint and Tinder for the campfire, spices and Refreshing Spring Water: Cooking Supply vendors (Xen'to in Orgrimmar, Ronald Burch in Undercity, Naal Mistrunner in Thunder Bluff)."
K.plan = {
  { from = 1,   to = 50,  craft = "Brilliant Smallfish or Slitherskin Mackerel", n = 55, mats = "1 Raw Brilliant Smallfish or Raw Slitherskin Mackerel each (catch them while you level Fishing)" },
  { from = 50,  to = 50,  train = "Journeyman (skill 50)" },
  { from = 50,  to = 100, craft = "Longjaw Mud Snapper or Rainbow Fin Albacore", n = 55, mats = "1 Raw Longjaw Mud Snapper or Raw Rainbow Fin Albacore each" },
  { from = 100, to = 150, craft = "Bristle Whisker Catfish", n = 53, mats = "1 Raw Bristle Whisker Catfish each" },
  { from = 125, to = 125, train = "Expert: buy the Expert Cookbook from Wulan (Shadowprey Village, Desolace)" },
  { from = 150, to = 175, craft = "Goblin Deviled Clams", n = 28, mats = "1 Tangy Clam Meat, 1 Hot Spices each" },
  { from = 175, to = 225, craft = "Roast Raptor or Mithril Headed Trout", n = 55, mats = "1 Raptor Flesh and 1 Hot Spices, or 1 Raw Mithril Head Trout each" },
  { from = 225, to = 225, train = "Artisan: Clamlette Surprise for Dirge Quikcleave in Gadgetzan (bring 12 Giant Egg and 10 Zesty Clam Meat from the Auction House, and 20 Alterac Swiss from Innkeeper Abeqwa in Freewind Post or Dwane Wertle in Dustwallow Marsh, or the Auction House, so you only go once)" },
  { from = 225, to = 285, craft = "Spotted Yellowtail or Filet of Redgill", n = 72, mats = "1 Raw Spotted Yellowtail or Raw Redgill each (recipes: Gikkix, Tanaris)" },
  { from = 285, to = 300, craft = "Nightfin Soup", n = 18, mats = "1 Raw Nightfin Snapper, 1 Refreshing Spring Water each. The guide also cooks 69 more Filet of Redgill here (1 Raw Redgill each)" },
}
K.mats = {}
RG.RegisterProfession("Cooking", K)
