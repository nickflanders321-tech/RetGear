-- Waypath+ class data: Priest (Shadow leveling).
-- Stat weights, what the class can wear and wield, and the hand-written gear tips.
-- The generated gear list is in Classes/PriestGear.lua (tools/gear).
local _, RG = ...
local C = { name = "Priest", spec = "Shadow", scoreName = "Shadow", lfgName = "Shadow Priest", lfgNote = "Fortitude" }

-- Shadow leveling: spell damage for Mind Blast and Shadow Word: Pain, Spirit for mana back between pulls (WoW Forever lets Spirit work in combat too), and a good wand for finishing every mob.
-- Weights are in Attack Power (or spell damage) equivalents. Change any of them
-- in game with /wp weight <stat> <value>.
C.weights = {
  SP         = 1.0,   -- spell damage (all schools)
  SP_SHADOW  = 1.0,   -- Shadow spell damage
  INT        = 0.5,   -- Intellect
  SPI        = 0.6,   -- Spirit (mana back, in and out of combat)
  STA        = 0.4,   -- Stamina
  CRIT       = 6,   -- per 1% crit
  HIT        = 6,   -- per 1% hit
  MP5        = 1.5,   -- mana per 5 seconds
  HEAL       = 0.15,   -- healing
  RANGED_DPS = 5,   -- per point of wand DPS
}
C.hitCap = 16

-- What the class can wear and wield (item subclass IDs) and how weapons score:
-- "caster" = weapon damage doesn't count, only stats; wands count in the ranged slot.
-- Weapons: 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword,
-- 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
-- Armor: level each type can be worn from (1 cloth, 2 leather, 3 mail, 4 plate).
C.classBit = 16
C.model = "caster"
C.weapons = { 4, 10, 15, 19 }
C.armor = { [1] = 1 }
C.shield = false

-- Hand-written tips shown in the gear guide (items come from the generated list).
C.guide = {
  { tip = true, lvl = 5, text = "A wand is your best leveling damage until Shadowform: buy one on the Auction House or from an Enchanter, and finish every mob with it." },
  { tip = true, lvl = 10, text = "Take Spirit Tap early in Shadow: with a high-Spirit set you barely need to drink." },
  { tip = true, lvl = 20, text = "Pick Holy or Discipline as your 2nd spec (2nd Spec tab) and Waypath+ collects a healing set for dungeons." },
}

RG.RegisterClass("PRIEST", C)
