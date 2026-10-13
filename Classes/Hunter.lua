-- Waypath+ class data: Hunter (Beast Mastery leveling).
-- Stat weights, what the class can wear and wield, and the hand-written gear tips.
-- The generated gear list is in Classes/HunterGear.lua (tools/gear).
local _, RG = ...
local C = { name = "Hunter", spec = "Beast Mastery", scoreName = "Hunter", lfgName = "Hunter" }

-- Hunters level on their ranged weapon and pet: ranged weapon damage is by far the biggest stat, then Agility (Attack Power and crit). Your melee weapon only matters for its stats.
-- Weights are in Attack Power (or spell damage) equivalents. Change any of them
-- in game with /wp weight <stat> <value>.
C.weights = {
  AGI        = 2.0,   -- Agility (ranged AP and crit)
  RAP        = 1.0,   -- Ranged Attack Power
  AP         = 0.5,   -- Attack Power (melee; most items give both)
  CRIT       = 20,   -- per 1% crit
  HIT        = 18,   -- per 1% hit (up to the cap)
  STA        = 0.3,   -- Stamina
  INT        = 0.4,   -- Intellect (mana for Serpent Sting and Arcane Shot)
  SPI        = 0.2,   -- Spirit
  STR        = 0.1,   -- Strength
  WEAPON_DPS = 1,   -- melee weapon damage barely matters
  RANGED_DPS = 14,   -- per point of ranged weapon DPS
}
C.hitCap = 9

-- What the class can wear and wield (item subclass IDs) and how weapons score:
-- "ranged" = the ranged weapon is the big one; melee weapons only for stats.
-- Weapons: 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword,
-- 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
-- Armor: level each type can be worn from (1 cloth, 2 leather, 3 mail, 4 plate).
C.classBit = 4
C.model = "ranged"
C.weapons = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }
C.armor = { [1] = 1, [2] = 1, [3] = 40 }
C.shield = false

-- Hand-written tips shown in the gear guide (items come from the generated list).
C.guide = {
  { tip = true, lvl = 1, text = "Your bow, gun or crossbow is your biggest upgrade: check the bowyer and gunsmith in your capital every few levels, and buy arrows or bullets in bulk." },
  { tip = true, lvl = 10, text = "Tame your first pet at 10 (the class quests on your tracker walk you through it). Pets do much of your damage while leveling." },
  { tip = true, lvl = 40, text = "You can wear mail from 40. Agility still matters more than armor." },
}

RG.RegisterClass("HUNTER", C)
