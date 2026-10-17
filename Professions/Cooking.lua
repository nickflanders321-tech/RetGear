-- Waypath+ profession data: Cooking (secondary). In WoW Forever Cooking also makes
-- your campfire, and cooked food gives a little extra XP. Route: wow-professions.com
-- WoW Forever guide (beta data; 225-300 not yet tested on Forever). Pick whichever
-- option you have the meat or fish for.
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
  { from = 1,   to = 50,  craft = "Brilliant Smallfish, Charred Wolf Meat or Roasted Boar Meat", n = 55, mats = "1 raw fish or meat each (use the raw fish and meat you loot while questing)" },
  { from = 50,  to = 50,  train = "Journeyman (skill 50)" },
  { from = 50,  to = 100, craft = "Longjaw Mud Snapper, Rainbow Fin Albacore, Coyote Steak or Strider Stew", n = 55, mats = "1 raw fish or meat each (Strider Stew: plus 1 Shiny Red Apple)" },
  { from = 100, to = 130, craft = "Bristle Whisker Catfish, Crab Cake or Dry Pork Ribs", n = 35, mats = "1 raw fish, or 1 meat and 1 Mild Spices each" },
  { from = 125, to = 125, train = "Expert: buy the Expert Cookbook from Wulan (Shadowprey Village, Desolace)" },
  { from = 130, to = 175, craft = "Hot Lion Chops or Curiously Tasty Omelet", n = 50, mats = "1 Lion Meat or Raptor Egg, 1 Hot Spices each (recipes: Zargh in The Barrens, Keena in Arathi)" },
  { from = 175, to = 225, craft = "Mithril Headed Trout, Roast Raptor or Soothing Turtle Bisque", n = 50, mats = "1 raw fish or meat (plus spices) each" },
  { from = 225, to = 225, train = "Artisan: Clamlette Surprise for Dirge Quikcleave in Gadgetzan" },
  { from = 225, to = 275, craft = "Spotted Yellowtail, Filet of Redgill or Tender Wolf Steak", n = 65, mats = "1 raw fish or meat each (recipes: Gikkix, Steamwheedle Port)" },
  { from = 275, to = 300, craft = "Poached Sunscale Salmon or Nightfin Soup", n = 35, mats = "1 raw fish each (recipes: Gikkix, Tanaris)" },
}
K.mats = {}
RG.RegisterProfession("Cooking", K)
