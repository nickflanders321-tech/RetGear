-- Waypath+ profession data: Engineering. Horde route from the wow-professions.com WoW
-- Forever guide (beta data; past 225 not yet tested on Forever). Pairs with Mining.
local _, RG = ...
local G = { name = "Engineering", kind = "craft", icon = "Interface\\Icons\\Trade_Engineering" }
G.source = "wow-professions.com WoW Forever guide (checked against the game's recipe tables)"
G.train = {
  start = { O = "Mukdrak in Razor Hill", R = "Mukdrak in Razor Hill", T = "Thund in Orgrimmar", U = "Graham Van Talen in Undercity", S = "Thund in Orgrimmar" },
  apprentice = "Thund (Orgrimmar), Graham Van Talen (Undercity)",
  journeyman = "Nogg (Orgrimmar), Franklin Lloyd (Undercity)",
  expert = "Roxxik (Orgrimmar)",
  artisan = "Buzzek Bracketswing (Gadgetzan, Tanaris)",
}

-- Alliance: the same trainers, in Stormwind, Ironforge, Darnassus and the starting zones (Profile.lua uses this one for Alliance characters).
G.trainA = {
  start = { H = "Sprite Jumpsprocket in Stormwind", D = "Bronk Guzzlegear in Kharanos", G = "Bronk Guzzlegear in Kharanos", N = "Sprite Jumpsprocket in Stormwind", A = "Sprite Jumpsprocket in Stormwind" },
  apprentice = "Sprite Jumpsprocket (Stormwind), Jemma Quikswitch (Ironforge), Bronk Guzzlegear (Dun Morogh)",
  journeyman = "Sprite Jumpsprocket (Stormwind), Jemma Quikswitch (Ironforge)",
  expert = "Lilliam Sparkspindle (Stormwind), Trixie Quikswitch (Ironforge)",
  artisan = "Springspindle Fizzlegear (Ironforge)",
}
G.supplies = "Blacksmith Hammer and Weak Flux: the Engineering or Blacksmithing Supply vendor by the trainer."
G.plan = {
  { from = 1,   to = 35,  craft = "Rough Blasting Powder", n = 52, mats = "1 Rough Stone each. Keep them all." },
  { from = 35,  to = 55,  craft = "Handful of Copper Bolts", n = 26, mats = "1 Copper Bar each. Keep them all." },
  { from = 50,  to = 50,  train = "Journeyman (skill 50, level 10)" },
  { from = 55,  to = 56,  craft = "Arclight Spanner", n = 1, mats = "6 Copper Bar (keep it)" },
  { from = 56,  to = 75,  craft = "Rough Copper Bomb", n = 26, mats = "1 Copper Bar, 1 Handful of Copper Bolts, 2 Rough Blasting Powder, 1 Linen Cloth each" },
  { from = 75,  to = 90,  craft = "Coarse Blasting Powder", n = 51, mats = "1 Coarse Stone each. Keep them." },
  { from = 90,  to = 100, craft = "Coarse Dynamite", n = 17, mats = "3 Coarse Blasting Powder, 1 Linen Cloth each" },
  { from = 100, to = 105, craft = "Silver Contact", n = 5, mats = "1 Silver Bar each" },
  { from = 105, to = 125, craft = "Bronze Tube", n = 25, mats = "2 Bronze Bar, 1 Weak Flux each" },
  { from = 125, to = 125, train = "Expert (skill 125, level 20, 50 silver)" },
  { from = 125, to = 135, craft = "Standard Scope", n = 10, mats = "1 Bronze Tube, 1 Moss Agate each" },
  { from = 135, to = 142, craft = "Heavy Blasting Powder", n = 30, mats = "1 Heavy Stone each. Keep them for the sheep at 160." },
  { from = 142, to = 150, craft = "Whirring Bronze Gizmo", n = 15, mats = "2 Bronze Bar, 1 Wool Cloth each. Keep them for the sheep at 160." },
  { from = 150, to = 160, craft = "Bronze Framework", n = 15, mats = "2 Bronze Bar, 1 Medium Leather, 1 Wool Cloth each" },
  { from = 160, to = 175, craft = "Explosive Sheep", n = 15, mats = "2 Heavy Blasting Powder, 1 Whirring Bronze Gizmo, 1 Bronze Framework, 2 Wool Cloth each" },
  { from = 175, to = 194, craft = "Solid Blasting Powder", n = 60, mats = "2 Solid Stone each. Keep them for the triggers and bombs." },
  { from = 194, to = 195, craft = "Gyromatic Micro-Adjustor", n = 1, mats = "4 Steel Bar (keep it)" },
  { from = 195, to = 200, craft = "Mithril Tube", n = 6, mats = "3 Mithril Bar each" },
  { from = 200, to = 200, train = "Artisan (skill 200, level 35)" },
  { from = 200, to = 215, craft = "Unstable Trigger", n = 20, mats = "1 Mithril Bar, 1 Mageweave Cloth, 1 Solid Blasting Powder each" },
  { from = 215, to = 238, craft = "Mithril Casing", n = 40, mats = "3 Mithril Bar each" },
  { from = 238, to = 250, craft = "Hi-Explosive Bomb", n = 20, mats = "2 Mithril Casing, 1 Unstable Trigger, 2 Solid Blasting Powder each" },
  { from = 250, to = 260, craft = "Dense Blasting Powder", n = 44, mats = "2 Dense Stone each" },
  { from = 260, to = 280, craft = "Thorium Widget", n = 20, mats = "3 Thorium Bar, 1 Runecloth each (schematic: an Engineering supplier in a capital city; Sovik in Orgrimmar for the Horde)" },
  { from = 280, to = 300, craft = "Thorium Tube", n = 21, mats = "6 Thorium Bar each (schematic: Xizzer Fizzbolt, Everlook). From 285 the guide also makes 15 Thorium Shells: 2 Thorium Bar, 1 Dense Blasting Powder each (left over from 250-260); one craft makes 200 shells to sell or give to a hunter" },
}
G.mats = { 2835, 2836, 2838, 7912, 12365, 2840, 2841, 3575, 3859, 3860, 12359 }
RG.RegisterProfession("Engineering", G)
