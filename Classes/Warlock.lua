-- Waypath+ class data: Warlock (Affliction leveling).
-- Stat weights, what the class can wear and wield, and the hand-written gear tips.
-- The generated gear list is in Classes/WarlockGear.lua (tools/gear).
local _, RG = ...
local C = { name = "Warlock", spec = "Affliction", scoreName = "Affliction", lfgName = "Warlock", lfgNote = "summons" }

-- Affliction with a pet: Shadow spell damage for your DoTs and Drain Life, Stamina (Life Tap turns health into mana, and in WoW Forever your pet scales with your stats) and Spirit, plus a wand.
-- Weights are in Attack Power (or spell damage) equivalents. Change any of them
-- in game with /wp weight <stat> <value>.
C.weights = {
  SP         = 1.0,   -- spell damage (all schools)
  SP_SHADOW  = 1.0,   -- Shadow spell damage
  STA        = 0.6,   -- Stamina (Life Tap, and your pet scales with you)
  INT        = 0.4,   -- Intellect
  SPI        = 0.5,   -- Spirit
  CRIT       = 5,   -- per 1% crit
  HIT        = 8,   -- per 1% hit
  MP5        = 1.0,   -- mana per 5 seconds
  RANGED_DPS = 5,   -- per point of wand DPS
}
C.hitCap = 16

-- What the class can wear and wield (item subclass IDs) and how weapons score:
-- "caster" = weapon damage doesn't count, only stats; wands count in the ranged slot.
-- Weapons: 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword,
-- 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
-- Armor: level each type can be worn from (1 cloth, 2 leather, 3 mail, 4 plate).
C.classBit = 256
C.model = "caster"
C.weapons = { 7, 10, 15, 19 }
C.armor = { [1] = 1 }
C.shield = false

-- Hand-written tips shown in the gear guide (items come from the generated list).
C.guide = {
  { tip = true, lvl = 10, text = "Get your Voidwalker at 10 from the class quest on your tracker: it tanks while your DoTs work." },
  { tip = true, lvl = 5, text = "Life Tap and drink less: Stamina is worth more to you than to any other caster." },
  { tip = true, lvl = 30, text = "Your felhunter quest at 30 and Felsteed at 40 are on the tracker when you reach them." },
}

RG.RegisterClass("WARLOCK", C)
