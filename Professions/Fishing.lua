-- Waypath+ profession data: Fishing (secondary). The full fishing guide (zones by
-- skill, lures, poles, the derby, the fishing panel) lives in Fish.lua and the
-- Fishing tab; this file gives Fishing the same trainer and plan shape as the rest.
local _, RG = ...
local F = { name = "Fishing", kind = "secondary", icon = "Interface\\Icons\\Trade_Fishing" }
F.train = {
  start = { O = "Lau'Tiki in Sen'jin Village", R = "Lau'Tiki in Sen'jin Village", T = "Harn Longcast in Mulgore", U = "Clyde Kellen at Brightwater Lake, Tirisfal", S = "a Zephras Isle trainer, or any capital" },
  apprentice = "Lumak (Orgrimmar), Armand Cromwell (Undercity), Kah Mistrunner (Thunder Bluff)",
  journeyman = "any Fishing trainer (skill 50, level 10)",
  expert = "the book Expert Fishing - The Bass and You (Old Man Heming, Booty Bay; skill 125)",
  artisan = "Nat Pagle's quests in Dustwallow Marsh (skill 225)",
}
F.supplies = "Fishing Pole and Shiny Baubles: Fishing supply vendors in every capital."
F.fishTab = true
RG.RegisterProfession("Fishing", F)
