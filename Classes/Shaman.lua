-- Waypath+ class data: Shaman (Enhancement leveling).
-- Stat weights, what the class can wear and wield, and the hand-written gear tips.
-- The generated gear list is in Classes/ShamanGear.lua (tools/gear).
local _, RG = ...
local C = { name = "Shaman", spec = "Enhancement", scoreName = "Enh", lfgName = "Enhancement Shaman", lfgNote = "totems" }

-- Enhancement with a slow two-hander: Windfury and Stormstrike love weapon damage and slow speed, Strength gives Attack Power, and a bit of Intellect keeps Lightning Bolt pulls and heals going.
-- Weights are in Attack Power (or spell damage) equivalents. Change any of them
-- in game with /wp weight <stat> <value>.
C.weights = {
  STR        = 2.0,   -- Strength (2 AP each)
  AGI        = 1.0,   -- Agility (crit)
  AP         = 1.0,   -- Attack Power
  CRIT       = 20,   -- per 1% crit
  HIT        = 18,   -- per 1% hit (up to the cap)
  STA        = 0.3,   -- Stamina
  INT        = 0.4,   -- Intellect (mana)
  SPI        = 0.1,   -- Spirit
  SP         = 0.25,   -- spell damage (shocks and Lightning Bolt pulls)
  SP_NATURE  = 0.2,   -- Nature spell damage
  WEAPON_DPS = 14,   -- per point of two-hand weapon DPS
  SLOW_BONUS = 4,   -- per 0.1 sec of weapon speed above 3.0
}
C.hitCap = 9

-- What the class can wear and wield (item subclass IDs) and how weapons score:
-- "2H" = one big two-hander (a one-hander counts for 55%).
-- Weapons: 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword,
-- 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
-- Armor: level each type can be worn from (1 cloth, 2 leather, 3 mail, 4 plate).
C.classBit = 64
C.model = "2H"
C.weapons = { 0, 1, 4, 5, 10, 13, 15 }
C.armor = { [1] = 1, [2] = 1, [3] = 40 }
C.shield = true
C.relic = 9

-- Hand-written tips shown in the gear guide (items come from the generated list).
C.guide = {
  { tip = true, lvl = 1, text = "Your weapon is your biggest upgrade: a slow two-handed axe, mace or staff. Rockbiter, then Windfury at 30, both scale with weapon speed." },
  { tip = true, lvl = 4, text = "Do your totem quests as they come up (Earth at 4, Fire at 10, Water at 20, Air at 30): they're on your tracker." },
  { tip = true, lvl = 40, text = "You can wear mail from 40. Keep whichever piece has more Strength and Agility." },
}

RG.RegisterClass("SHAMAN", C)
