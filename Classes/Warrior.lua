-- Waypath+ class data: Warrior (Arms leveling).
-- Stat weights, what the class can wear and wield, and the hand-written gear tips.
-- The generated gear list is in Classes/WarriorGear.lua (tools/gear).
local _, RG = ...
local C = { name = "Warrior", spec = "Arms", scoreName = "Arms", lfgName = "Warrior" }

-- Leveling as Arms with the biggest, slowest two-hander you can find: Strength turns into Attack Power (1 Strength = 2 AP), weapon damage drives Mortal Strike and every swing, and crit and hit feed rage. Stamina keeps you alive between bandages.
-- Weights are in Attack Power (or spell damage) equivalents. Change any of them
-- in game with /wp weight <stat> <value>.
C.weights = {
  STR        = 2.0,   -- Strength (2 AP each)
  AGI        = 1.0,   -- Agility (crit and armor)
  AP         = 1.0,   -- Attack Power
  CRIT       = 20,   -- per 1% crit
  HIT        = 18,   -- per 1% hit (up to the cap)
  STA        = 0.3,   -- Stamina
  SPI        = 0.1,   -- Spirit (out-of-combat health)
  WEAPON_DPS = 14,   -- per point of two-hand weapon DPS
  SLOW_BONUS = 4,   -- per 0.1 sec of weapon speed above 3.0
  RANGED_DPS = 0.5,   -- bows, guns and thrown are for pulling
}
C.hitCap = 9

-- What the class can wear and wield (item subclass IDs) and how weapons score:
-- "2H" = one big two-hander (a one-hander counts for 55%).
-- Weapons: 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword,
-- 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
-- Armor: level each type can be worn from (1 cloth, 2 leather, 3 mail, 4 plate).
C.classBit = 1
C.model = "2H"
C.weapons = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }
C.armor = { [1] = 1, [2] = 1, [3] = 1, [4] = 40 }
C.shield = true

-- Hand-written tips shown in the gear guide (items come from the generated list).
C.guide = {
  { tip = true, lvl = 1, text = "Your weapon is your biggest upgrade: always use the slowest two-hander you can get. Check the weapon vendors in your capital every few levels." },
  { tip = true, lvl = 10, text = "Learn Defensive Stance at 10 and Berserker Stance at 30 from the class quests on your tracker." },
  { tip = true, lvl = 30, text = "The level 30 Whirlwind Axe chain (The Islander, Cyclonian) gives one of the best two-handers before 40." },
  { tip = true, lvl = 40, text = "You can wear plate from 40. Don't switch just for armor: keep whichever piece has more Strength." },
}

RG.RegisterClass("WARRIOR", C)
