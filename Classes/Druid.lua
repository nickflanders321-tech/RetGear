-- Waypath+ class data: Druid (Feral leveling).
-- Stat weights, what the class can wear and wield, and the hand-written gear tips.
-- The generated gear list is in Classes/DruidGear.lua (tools/gear).
local _, RG = ...
local C = { name = "Druid", spec = "Feral", scoreName = "Feral", lfgName = "Feral Druid", lfgNote = "Mark of the Wild" }

-- Feral (Cat) leveling: in WoW Forever Cat and Bear Form scale with your weapon's damage, so a strong two-hander matters. Strength and Agility give Attack Power (Agility also crit), and a little Intellect lets you shift back for heals.
-- Weights are in Attack Power (or spell damage) equivalents. Change any of them
-- in game with /wp weight <stat> <value>.
C.weights = {
  STR        = 2.0,   -- Strength (2 AP in forms)
  AGI        = 2.0,   -- Agility (AP and crit in Cat Form)
  AP         = 1.0,   -- Attack Power
  CRIT       = 20,   -- per 1% crit
  HIT        = 18,   -- per 1% hit (up to the cap)
  STA        = 0.4,   -- Stamina
  INT        = 0.2,   -- Intellect (heals between fights)
  SPI        = 0.1,   -- Spirit
  WEAPON_DPS = 8,   -- per point of weapon DPS (forms scale with it in Forever)
}
C.hitCap = 9

-- What the class can wear and wield (item subclass IDs) and how weapons score:
-- "feral" = forms scale with the weapon (Forever change); polearms are new for druids.
-- Weapons: 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword,
-- 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
-- Armor: level each type can be worn from (1 cloth, 2 leather, 3 mail, 4 plate).
C.classBit = 1024
C.model = "feral"
C.weapons = { 4, 5, 6, 10, 13, 15 }
C.armor = { [1] = 1, [2] = 1 }
C.shield = false
C.relic = 8

-- Hand-written tips shown in the gear guide (items come from the generated list).
C.guide = {
  { tip = true, lvl = 10, text = "Bear Form at 10 (class quest on your tracker) makes the next levels easy. Cat Form comes at 20." },
  { tip = true, lvl = 1, text = "In forms your weapon's damage doesn't count, only its stats: pick staves and maces for Strength and Agility." },
  { tip = true, lvl = 16, text = "Aquatic Form at 16 is a quick class quest worth doing." },
}

RG.RegisterClass("DRUID", C)
