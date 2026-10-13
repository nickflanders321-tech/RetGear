-- Waypath+ gold-making tips, for every profession (tips for professions you don't
-- have or plan are hidden).
-- The weekly Waypath+ update refreshes this table from the newest WoW Forever
-- gold guides, so keep the shape the same: one row per tip.
--   cat   = "Auction House" | "Farming" | "Forever" | a profession name ("Mining", "Herbalism", ...)
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
    { cat = "Auction House", from = 1, to = 60, title = "Never vendor without checking", text = "Anything with a gold coin in your bags is worth more on the AH. Waypath+ keeps it out of the junk sale and lists it on the Auction House tab." },
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
    -- Herbalism
    { cat = "Herbalism", from = 1, to = 30, prof = "Herbalism", title = "Early herbs for the alchemist rush", text = "Peacebloom, Silverleaf, Briarthorn and Mageroyal feed every new alchemist's first 120 points, and Forever's 77 new Alchemy recipes add more demand. Sell in stacks of 20.", ids = { 2447, 765, 2450, 785 } },
    { cat = "Herbalism", from = 30, to = 60, prof = "Herbalism", title = "Kingsblood, Liferoot and up", text = "Mid-level herbs (Kingsblood, Liferoot, Sungrass) are mana and protection potion staples. Your herb alerts point you to patches you can still learn from.", ids = { 3356, 3357, 8838 } },
    -- Skinning
    { cat = "Skinning", from = 5, to = 60, prof = "Skinning", title = "Skin everything you kill", text = "Leather sells steadily because leatherworkers need hundreds of pieces. In Forever each beast can be skinned once, so skin your own kills right away.", ids = { 2318, 2319, 4234, 4304, 8170 } },
    -- Crafting
    { cat = "Alchemy", from = 10, to = 60, prof = "Alchemy", title = "Potions people use every day", text = "Mana potions and elixirs sell all through leveling. Forever moved Healing Potions to First Aid, so focus on mana, protection and buff potions.", ids = { 3827, 6149 } },
    { cat = "Enchanting", from = 10, to = 60, prof = "Enchanting", title = "Disenchant, then sell the dust", text = "Green items you can't use are often worth more as dust and essences than at a vendor or on the AH. Compare before you sell.", ids = { 10940, 11083, 11137, 11176 } },
    { cat = "Tailoring", from = 10, to = 60, prof = "Tailoring", title = "Bags always sell", text = "Every new character needs bags. Linen, Woolen, Silk and Mageweave bags are the tailor's steady earners.", ids = { 4238, 4240, 10050 } },
    { cat = "Leatherworking", from = 10, to = 60, prof = "Leatherworking", title = "Armor kits and leveling gear", text = "Armor kits sell to everyone, and bind on equip leather and mail pieces with good stats sell to leveling rogues, hunters, druids and shamans.", ids = { 2304, 2313 } },
    { cat = "Engineering", from = 10, to = 60, prof = "Engineering", title = "Ammo and explosives", text = "Hunters burn through arrows and shot; bombs and grenades sell to everyone who groups. Your own Repair Bot camp object saves the trip back to town.", ids = { 2512, 2516 } },
    { cat = "First Aid", from = 1, to = 60, prof = "First Aid", title = "Healing Potions are First Aid now", text = "In Forever, Healing Potions come from First Aid, so a First Aid user can sell them as well as bandages.", ids = { 929, 1710 } },
    { cat = "Cooking", from = 5, to = 60, prof = "Cooking", title = "Well Fed food sells", text = "Forever's cooked food gives a little extra XP besides its stats, so good leveling food sells. Cook what you fish while you wait.", ids = {} },
    -- Fishing
    { cat = "Fishing", from = 10, to = 30, prof = "Fishing", title = "Deviate Fish in the Barrens", text = "Fish the Barrens oases (Lushwater, Stagnant, Forgotten Pools) or outside Wailing Caverns. Savory Deviate Delight is a popular fun item, so the raw fish sells.", ids = { 6522 } },
    { cat = "Fishing", from = 15, to = 45, prof = "Fishing", title = "Fish for alchemists", text = "Oily Blackmouth (Ratchet docks, Silverpine coast) and Firefin Snapper (coasts, Stonetalon lakes) go into Blackmouth Oil and Fire Oil. Sell them in stacks of 20.", ids = { 6358, 6359 } },
    { cat = "Fishing", from = 45, to = 60, prof = "Fishing", title = "Stonescale Eels", text = "Azshara and coastal schools, best at night. Raiders' potions use them, so they hold their price.", ids = { 13422 } },
    { cat = "Fishing", from = 1, to = 60, prof = "Fishing", title = "Fish while you wait", text = "Waiting on respawns, a group or a camp buff? Fish. It levels Fishing and Cooking for free and stocks your Fish Bowls and Well Fed food." },
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
    local wanted = not t.prof or not RG.Plans or RG.Plans(t.prof)
    if wanted and (all or (lvl >= t.from - 2 and lvl <= t.to)) then out[#out + 1] = t end
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
