-- Waypath+ Arena: the Mythic mounts. One Mythic card for each epic mount (26 of them): the mount's own model from the game
-- on a painted backdrop (Media/Arcade/MythicMount01..26.tga, made by tools/arcade/mounts/art_mounts.py). They are extra
-- Mythics on top of the six in ArcadeMythic.lua and are drawn exactly like them (Arcade.lua's ArcadePaintMythic).
--   Where they come from: any pack but a dungeon's own can hold one, on a roll of its own (RG.ARCADE_MOUNT_RATE), so the
--   six keep their odds; Arcade.lua rolls it. One per deck in the Arena like every Mythic. Their rules are here and are read
--   by Battle.lua (RG.ARCADE_MOUNT_DESIGNS), which loads after this file.
-- (The icons are a fallback for small views: the card itself is its painted art.)
local _, RG = ...

-- { kind, name, tier, item id / creature type, collection text }
local ROWS = {
  { 2, "Black War Steed", 7, 0, "Mythic. Armour for the long road." },
  { 2, "Dreadsteed", 7, 0, "Mythic. Summoned, never stabled." },
  { 2, "Swift White Steed", 7, 0, "Mythic. Fast enough to outrun the quest log." },
  { 2, "Black War Kodo", 7, 0, "Mythic. Three tons of bad intentions." },
  { 2, "Great White Kodo", 7, 0, "Mythic. It remembers every road." },
  { 2, "Black War Ram", 7, 0, "Mythic. Horns first." },
  { 2, "Swift White Ram", 7, 0, "Mythic. Surefooted on every slope." },
  { 2, "Black War Raptor", 7, 0, "Mythic. Teeth, then manners." },
  { 2, "Swift Blue Raptor", 7, 0, "Mythic. Faster than the one that bit you." },
  { 2, "Black War Tiger", 7, 0, "Mythic. Moonlit and purring." },
  { 2, "Black War Wolf", 7, 0, "Mythic. The Horde's idea of a pet." },
  { 2, "Swift Timber Wolf", 7, 0, "Mythic. Straight through the forest." },
  { 2, "Frostwolf Howler", 7, 0, "Mythic. The clan's call, on the wind." },
  { 2, "Swift Mistsaber", 7, 0, "Mythic. Silent over Darkshore." },
  { 2, "Swift Frostsaber", 7, 0, "Mythic. Winterspring's finest." },
  { 2, "Swift Stormsaber", 7, 0, "Mythic. It brings the weather." },
  { 2, "Swift Yellow Mechanostrider", 7, 0, "Mythic. Some assembly required." },
  { 2, "Swift White Mechanostrider", 7, 0, "Mythic. Do not feed after midnight." },
  { 2, "Swift Green Mechanostrider", 7, 0, "Mythic. Runs on spite and steam." },
  { 2, "Black Qiraji Battle Tank", 7, 0, "Mythic. It was never a small bug." },
  { 2, "Blue Qiraji Battle Tank", 7, 0, "Mythic. Cool under pressure." },
  { 2, "Red Qiraji Battle Tank", 7, 0, "Mythic. Hot-headed, thin-shelled." },
  { 2, "Yellow Qiraji Battle Tank", 7, 0, "Mythic. Sand in every joint." },
  { 2, "Green Qiraji Battle Tank", 7, 0, "Mythic. The hive's quiet colour." },
  { 2, "Swift Razzashi Raptor", 7, 0, "Mythic. Swift as a rumour." },
  { 2, "Swift Zulian Tiger", 7, 0, "Mythic. Stripes at full gallop." },
}
RG.ARCADE_MYTHIC = RG.ARCADE_MYTHIC or {}
local M = RG.ARCADE_MYTHIC
M["Black War Steed"] = { art = "MythicMount01", num = "M-06", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 1, 0.78, 0.51 } }
M["Dreadsteed"] = { art = "MythicMount02", num = "M-07", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_Dreadsteed", mount = true, glow = { 1, 0.47, 0.16 } }
M["Swift White Steed"] = { art = "MythicMount03", num = "M-08", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 1, 0.93, 0.75 } }
M["Black War Kodo"] = { art = "MythicMount04", num = "M-09", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_Kodo_01", mount = true, glow = { 1, 0.67, 0.39 } }
M["Great White Kodo"] = { art = "MythicMount05", num = "M-10", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_Kodo_02", mount = true, glow = { 1, 0.96, 0.86 } }
M["Black War Ram"] = { art = "MythicMount06", num = "M-11", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 0.78, 0.67, 1 } }
M["Swift White Ram"] = { art = "MythicMount07", num = "M-12", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 1, 0.89, 0.86 } }
M["Black War Raptor"] = { art = "MythicMount08", num = "M-13", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_Raptor", mount = true, glow = { 0.55, 1, 0.75 } }
M["Swift Blue Raptor"] = { art = "MythicMount09", num = "M-14", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_Raptor", mount = true, glow = { 0.71, 0.98, 0.94 } }
M["Black War Tiger"] = { art = "MythicMount10", num = "M-15", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_BlackPanther", mount = true, glow = { 0.75, 0.63, 1 } }
M["Black War Wolf"] = { art = "MythicMount11", num = "M-16", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 1, 0.59, 0.31 } }
M["Swift Timber Wolf"] = { art = "MythicMount12", num = "M-17", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 1, 0.89, 0.59 } }
M["Frostwolf Howler"] = { art = "MythicMount13", num = "M-18", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 0.82, 0.93, 1 } }
M["Swift Mistsaber"] = { art = "MythicMount14", num = "M-19", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_BlackPanther", mount = true, glow = { 0.63, 1, 0.94 } }
M["Swift Frostsaber"] = { art = "MythicMount15", num = "M-20", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_WhiteTiger", mount = true, glow = { 0.67, 1, 0.86 } }
M["Swift Stormsaber"] = { art = "MythicMount16", num = "M-21", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_WhiteTiger", mount = true, glow = { 0.67, 0.75, 1 } }
M["Swift Yellow Mechanostrider"] = { art = "MythicMount17", num = "M-22", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 1, 0.78, 0.39 } }
M["Swift White Mechanostrider"] = { art = "MythicMount18", num = "M-23", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 0.9, 0.94, 1 } }
M["Swift Green Mechanostrider"] = { art = "MythicMount19", num = "M-24", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 0.75, 1, 0.59 } }
M["Black Qiraji Battle Tank"] = { art = "MythicMount20", num = "M-25", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 0.75, 0.47, 1 } }
M["Blue Qiraji Battle Tank"] = { art = "MythicMount21", num = "M-26", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 0.51, 0.78, 1 } }
M["Red Qiraji Battle Tank"] = { art = "MythicMount22", num = "M-27", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 1, 0.51, 0.27 } }
M["Yellow Qiraji Battle Tank"] = { art = "MythicMount23", num = "M-28", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 1, 0.89, 0.51 } }
M["Green Qiraji Battle Tank"] = { art = "MythicMount24", num = "M-29", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_RidingHorse", mount = true, glow = { 0.59, 1, 0.71 } }
M["Swift Razzashi Raptor"] = { art = "MythicMount25", num = "M-30", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_Raptor", mount = true, glow = { 1, 0.89, 0.59 } }
M["Swift Zulian Tiger"] = { art = "MythicMount26", num = "M-31", type = "Mount  ·  Beast  ·  Mythic", icon = "Ability_Mount_WhiteTiger", mount = true, glow = { 1, 0.71, 0.31 } }
RG.ARCADE_MOUNT_ORDER = {}
RG.ARCADE_DATA = RG.ARCADE_DATA or {}
for _, r in ipairs(ROWS) do
  RG.ARCADE_DATA[#RG.ARCADE_DATA + 1] = r
  RG.ARCADE_MOUNT_ORDER[#RG.ARCADE_MOUNT_ORDER + 1] = r[2]
end
-- a pack that can hold a mount Mythic holds one this often (on top of the Mythic roll; 1 in 150 is the other Mythics'), so
-- about 1 pack in 250 across the 26, each one about 1 in 6,500
RG.ARCADE_MOUNT_RATE = 1 / 250

-- Battle rules: { design, text } as in Battle.lua's MYTHIC. The helpers are Battle.lua's own, handed over by Battle.lua
-- (RG.ARCADE_MOUNT_RULES is called with them once Battle.lua has loaded).
function RG.ARCADE_MOUNT_RULES(dmg, heal, buff, draw, armor, summon, T, freeze)
  return {
    ["Black War Steed"] = { { "m", 7, 5, 5, "beast", { charge = true }, { bc = { buff(1, 1, "fother") } } },
      "Charge. Battlecry: Give your other minions +1/+1." },
    ["Dreadsteed"] = { { "m", 7, 5, 5, "demon", { charge = true }, { dr = { dmg(3, "eface") } } },
      "Charge. Deathrattle: Deal 3 damage to the enemy hero." },
    ["Swift White Steed"] = { { "m", 4, 3, 4, "beast", { rush = true }, { bc = { heal(3, "fface") } } },
      "Rush. Battlecry: Restore 3 Health to your hero." },
    ["Black War Kodo"] = { { "m", 7, 4, 8, "beast", { taunt = true }, { dr = { dmg(2, "all") } } },
      "Taunt. Deathrattle: Deal 2 damage to all minions." },
    ["Great White Kodo"] = { { "m", 6, 4, 7, "beast", { taunt = true }, { bc = { armor(4) } } },
      "Taunt. Battlecry: Gain 4 Armor." },
    ["Black War Ram"] = { { "m", 5, 4, 4, "beast", { charge = true }, { bc = { dmg(1, "eface") } } },
      "Charge. Battlecry: Deal 1 damage to the enemy hero." },
    ["Swift White Ram"] = { { "m", 4, 3, 3, "beast", { rush = true }, { bc = { draw(1) } } },
      "Rush. Battlecry: Draw a card." },
    ["Black War Raptor"] = { { "m", 5, 4, 4, "beast", { rush = true, poison = true } },
      "Rush. Poisonous." },
    ["Swift Blue Raptor"] = { { "m", 3, 3, 2, "beast", { rush = true }, { bc = { dmg(1, "eface") } } },
      "Rush. Battlecry: Deal 1 damage to the enemy hero." },
    ["Black War Tiger"] = { { "m", 6, 6, 5, "beast", { stealth = true }, { bc = { buff(1, 0, "fother") } } },
      "Stealth. Battlecry: Give your other minions +1 Attack." },
    ["Black War Wolf"] = { { "m", 5, 4, 3, "beast", { charge = true }, { dr = { draw(1) } } },
      "Charge. Deathrattle: Draw a card." },
    ["Swift Timber Wolf"] = { { "m", 4, 3, 3, "beast", { rush = true }, { dr = { summon(1, T("Timber Pup", 2, 1, "Ability_Hunter_Pet_Wolf", "beast", { rush = true })) } } },
      "Rush. Deathrattle: Summon a 2/1 Timber Pup with Rush." },
    ["Frostwolf Howler"] = { { "m", 6, 4, 6, "beast", { windfury = true } },
      "Windfury." },
    ["Swift Mistsaber"] = { { "m", 4, 4, 4, "beast", { stealth = true, rush = true } },
      "Stealth. Rush." },
    ["Swift Frostsaber"] = { { "m", 5, 4, 4, "beast", { rush = true }, { bc = { freeze("t") }, tgt = "enemy" } },
      "Rush. Battlecry: Freeze an enemy." },
    ["Swift Stormsaber"] = { { "m", 7, 5, 6, "beast", { rush = true, windfury = true } },
      "Rush. Windfury." },
    ["Swift Yellow Mechanostrider"] = { { "m", 3, 3, 2, "mechanical", { rush = true }, { dr = { draw(1) } } },
      "Rush. Deathrattle: Draw a card." },
    ["Swift White Mechanostrider"] = { { "m", 4, 3, 4, "mechanical", { taunt = true }, { eot = { heal(2, "fface") } } },
      "Taunt. At the end of your turn, restore 2 Health to your hero." },
    ["Swift Green Mechanostrider"] = { { "m", 5, 4, 4, "mechanical", nil, { bc = { heal(3, "fall") } } },
      "Battlecry: Restore 3 Health to all friendly characters." },
    ["Black Qiraji Battle Tank"] = { { "m", 8, 6, 8, "beast", { taunt = true }, { bc = { armor(5) } } },
      "Taunt. Battlecry: Gain 5 Armor." },
    ["Blue Qiraji Battle Tank"] = { { "m", 7, 5, 7, "beast", { taunt = true }, { bc = { heal(6, "fface") } } },
      "Taunt. Battlecry: Restore 6 Health to your hero." },
    ["Red Qiraji Battle Tank"] = { { "m", 8, 6, 5, "beast", { charge = true }, { bc = { dmg(3, "eface") } } },
      "Charge. Battlecry: Deal 3 damage to the enemy hero." },
    ["Yellow Qiraji Battle Tank"] = { { "m", 7, 5, 7, "beast", nil, { bc = { draw(2) } } },
      "Battlecry: Draw 2 cards." },
    ["Green Qiraji Battle Tank"] = { { "m", 7, 6, 6, "beast", nil, { eot = { heal(3, "fother") } } },
      "At the end of your turn, restore 3 Health to your other minions." },
    ["Swift Razzashi Raptor"] = { { "m", 6, 4, 4, "beast", { rush = true }, { dr = { summon(1, T("Razzashi Hatchling", 3, 2, "Ability_Hunter_Pet_Raptor", "beast", { rush = true })) } } },
      "Rush. Deathrattle: Summon a 3/2 Razzashi Hatchling with Rush." },
    ["Swift Zulian Tiger"] = { { "m", 5, 4, 4, "beast", { rush = true }, { trig = { ev = "death", ops = { buff(1, 1, "self") } } } },
      "Rush. Whenever a minion dies, gain +1/+1." },
  }
end
