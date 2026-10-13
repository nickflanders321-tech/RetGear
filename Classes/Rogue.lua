-- Waypath+ class data: Rogue (Combat leveling).
-- Stat weights, what the class can wear and wield, and the hand-written gear tips.
-- The generated gear list is in Classes/RogueGear.lua (tools/gear).
local _, RG = ...
local C = { name = "Rogue", spec = "Combat", scoreName = "Combat", lfgName = "Rogue" }

-- Combat swords leveling: a slow main-hand for Sinister Strike, a fast off-hand, Agility for Attack Power and crit, and hit because two weapons miss a lot. In WoW Forever rogues can also use one-handed axes.
-- Weights are in Attack Power (or spell damage) equivalents. Change any of them
-- in game with /wp weight <stat> <value>.
C.weights = {
  AGI        = 2.0,   -- Agility (1 AP and crit)
  STR        = 1.0,   -- Strength (1 AP)
  AP         = 1.0,   -- Attack Power
  CRIT       = 20,   -- per 1% crit
  HIT        = 20,   -- per 1% hit (up to the cap; dual wielding misses a lot)
  STA        = 0.3,   -- Stamina
  WEAPON_DPS = 12,   -- per point of main-hand DPS (off-hand counts half)
  SLOW_BONUS = 2,   -- per 0.1 sec of main-hand speed above 2.6
  RANGED_DPS = 0.5,   -- bows, guns and thrown are for pulling
}
C.hitCap = 9

-- What the class can wear and wield (item subclass IDs) and how weapons score:
-- "DW" = two one-handers (the off-hand counts half).
-- Weapons: 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword,
-- 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
-- Armor: level each type can be worn from (1 cloth, 2 leather, 3 mail, 4 plate).
C.classBit = 8
C.model = "DW"
C.weapons = { 2, 3, 4, 7, 13, 15, 16, 18 }
C.armor = { [1] = 1, [2] = 1 }
C.shield = false

-- Hand-written tips shown in the gear guide (items come from the generated list).
C.guide = {
  { tip = true, lvl = 1, text = "Your main-hand weapon is your biggest upgrade: a slow sword (2.6 speed or more) for Sinister Strike. Your off-hand can be fast." },
  { tip = true, lvl = 20, text = "Learn poisons at 20 (the class quest on your tracker). Instant Poison on both weapons is a big damage boost; in Forever poisons last longer and stack with sharpening stones." },
  { tip = true, lvl = 10, text = "Keep Thrown or a bow for pulling. Its damage hardly matters." },
}

RG.RegisterClass("ROGUE", C)
