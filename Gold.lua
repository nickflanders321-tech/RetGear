-- RetGear gold-making tips for an Undead Ret Paladin with Mining and Blacksmithing.
-- The weekly RetGear update refreshes this table from the newest WoW Forever
-- gold guides, so keep the shape the same: one row per tip.
--   cat   = "Mining" | "Blacksmithing" | "Farming" | "Auction House" | "Forever"
--   from, to = character levels the tip is useful at
--   title, text = what to do and why
--   ids   = item IDs whose live AH price is shown with the tip (optional)
--   prof  = profession needed (optional; the tip is marked if you don't have it)
local _, RG = ...

RG.GOLD = {
  updated = "2026-10-12",
  note = "Forever's economy is brand new (beta, launch Nov 4 2026). Prices are still settling, so the live AH prices next to each tip matter more than any guide.",
  tips = {
    -- Every level
    { cat = "Auction House", from = 1, to = 60, title = "Never vendor without checking", text = "Anything with a gold coin in your bags is worth more on the AH. RetGear keeps it out of the junk sale and lists it on the Auction House tab." },
    { cat = "Auction House", from = 1, to = 60, title = "Undercut a little, not a lot", text = "List 1 copper under the cheapest auction. Big undercuts just lower the price for everyone, including you next time. Remember the AH keeps 5% and you lose the deposit if it doesn't sell." },
    { cat = "Farming", from = 1, to = 60, title = "Loot everything while you quest", text = "Questing pays best when you also loot every mob and sell grey items. Don't stop to farm until your bags are full of things that are actually worth money." },
    { cat = "Farming", from = 5, to = 60, title = "Cloth is money", text = "Humanoids drop cloth that tailors and First Aid users always need. Sell it in full stacks of 20 on the AH, never at a vendor.", ids = { 2589, 2592, 4306, 4338, 14047 } },
    -- Mining
    { cat = "Mining", from = 1, to = 25, prof = "Mining", title = "Copper and Tin sell well early", text = "In a new economy everyone is leveling Blacksmithing and Engineering at once, so low ore is often your best seller. Keep Find Minerals on while you quest in Tirisfal, Silverpine and the Barrens.", ids = { 2770, 2771 } },
    { cat = "Mining", from = 1, to = 60, prof = "Mining", title = "Smelt or sell? Check first", text = "Compare ore and bar prices after the AH cut before smelting a whole stack, because you can't un-smelt. The Professions tab shows which is worth more right now.", ids = { 2770, 2840, 2771, 3576, 2841 } },
    { cat = "Mining", from = 1, to = 60, prof = "Mining", title = "Don't vendor stone", text = "Rough, Coarse, Heavy, Solid and Dense Stone all feed Blacksmithing and Engineering recipes, so they sell for more than the vendor gives.", ids = { 2835, 2836, 2838, 7912, 12365 } },
    { cat = "Mining", from = 25, to = 45, prof = "Mining", title = "Iron and Mithril for the mid-level rush", text = "Iron (Arathi, Desolace, Stranglethorn, Badlands) and Mithril (Tanaris, Hinterlands, Searing Gorge, Feralas) are used by most mid-level crafts. Bank some when the price dips.", ids = { 2772, 3858 } },
    { cat = "Mining", from = 45, to = 60, prof = "Mining", title = "Thorium routes", text = "Thorium ore, Dense Stone, gems and Arcane Crystals together make the money. A loop through Un'Goro, Burning Steppes or Winterspring beats waiting on one Rich node.", ids = { 10620, 12365, 12363 } },
    -- Blacksmithing
    { cat = "Blacksmithing", from = 5, to = 60, prof = "Blacksmithing", title = "Sharpening stones and weightstones", text = "Every warrior, rogue and paladin leveling uses them. They're cheap to make from stone, stack well and sell steadily.", ids = { 2862, 2863, 2871, 3239, 3240, 3241 } },
    { cat = "Blacksmithing", from = 10, to = 60, prof = "Blacksmithing", title = "Sell gear that's bind on equip", text = "Check the binding before you craft to sell: BoE pieces can go on the AH, BoP can't. Price-check before making a batch." },
    -- Forever-only
    { cat = "Forever", from = 1, to = 60, title = "Waylaid Crates", text = "Players turn in supply crates for Merchant's Favor and need set materials to fill them (Copper Bar showed up in the beta). Watch for crate materials spiking on the AH and sell into it." },
    { cat = "Forever", from = 1, to = 60, title = "Sell the mats for new recipes", text = "Forever adds 600+ new profession recipes, and some Blueprints drop from dungeon bosses. Mats those recipes need can jump in price, so check before vendoring anything that looks odd." },
    { cat = "Forever", from = 1, to = 60, title = "Rare mobs and dungeon drops", text = "Blizzard added hundreds of new rare and dungeon drops. Check any unfamiliar bind on equip item on the AH before selling it." },
    { cat = "Forever", from = 1, to = 60, title = "Each ruleset has its own AH", text = "Prices are different on every ruleset, so a guide's price might not match yours. Trust your own scans." },
  },
  sources = {
    "gamsgo.com/blog/wow-forever-gold-guide",
    "boostroom.com/blog/wow-forever-gold-making-guide-best-ways-to-farm-gold",
    "expcarry.com/wow-forever-mining-guide",
    "icy-veins.com/wow-forever/blacksmithing",
  },
}

-- Tips that fit your level right now.
function RG.GoldTips(all)
  local lvl = UnitLevel("player") or 1
  local out = {}
  for _, t in ipairs(RG.GOLD.tips) do
    if all or (lvl >= t.from - 2 and lvl <= t.to) then out[#out + 1] = t end
  end
  return out
end

-- Item IDs from those tips, so opening the AH prices them too.
function RG.GoldIDs()
  local ids, seen = {}, {}
  for _, t in ipairs(RG.GoldTips()) do
    if t.ids and (not t.prof or (RG.Professions and RG.Professions()[t.prof])) then
      for _, id in ipairs(t.ids) do if not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
    end
  end
  return ids, seen
end
