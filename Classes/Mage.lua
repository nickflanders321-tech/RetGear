-- Waypath+ class data: Mage (Frost leveling).
-- Stat weights, what the class can wear and wield, and the hand-written gear tips.
-- The generated gear list is in Classes/MageGear.lua (tools/gear).
local _, RG = ...
local C = { name = "Mage", spec = "Frost", scoreName = "Frost", lfgName = "Mage", lfgNote = "water" }

-- Frost leveling: spell damage for Frostbolt and Frost Nova kiting, Intellect for a bigger mana bar, Spirit for faster drinking (and in combat in WoW Forever), and a wand to finish mobs and save mana.
-- Weights are in Attack Power (or spell damage) equivalents. Change any of them
-- in game with /wp weight <stat> <value>.
C.weights = {
  SP         = 1.0,   -- spell damage (all schools)
  SP_FROST   = 1.0,   -- Frost spell damage
  INT        = 0.6,   -- Intellect
  SPI        = 0.4,   -- Spirit
  STA        = 0.3,   -- Stamina
  CRIT       = 8,   -- per 1% crit
  HIT        = 8,   -- per 1% hit
  MP5        = 1.5,   -- mana per 5 seconds
  RANGED_DPS = 5,   -- per point of wand DPS
}
C.hitCap = 16

-- What the class can wear and wield (item subclass IDs) and how weapons score:
-- "caster" = weapon damage doesn't count, only stats; wands count in the ranged slot.
-- Weapons: 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword,
-- 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
-- Armor: level each type can be worn from (1 cloth, 2 leather, 3 mail, 4 plate).
C.classBit = 128
C.model = "caster"
C.weapons = { 7, 10, 15, 19 }
C.armor = { [1] = 1 }
C.shield = false

-- Hand-written tips shown in the gear guide (items come from the generated list).
C.guide = {
  { tip = true, lvl = 5, text = "Conjure your own food and water: never buy any. A wand finishes mobs without spending mana." },
  { tip = true, lvl = 20, text = "Frost is the easy leveling spec: Frost Nova and Frostbolt let you kill without being hit. At 40 Forever adds Frostfire Bolt, which counts as Fire and Frost." },
  { tip = true, lvl = 30, text = "Arcane Explosion grinding in dungeons and on packs is fast once you have the mana for it." },
}

RG.RegisterClass("MAGE", C)
