-- Waypath+ shared data: stat names, equipment slots, and the registry that
-- class, race, route and profession files add themselves to. Profile.lua then
-- picks the ones for the character you're playing.
local _, RG = ...

RG.STAT_LABELS = {
  STR = "Strength", AGI = "Agility", AP = "Attack Power", CRIT = "Crit %", HIT = "Hit %",
  STA = "Stamina", INT = "Intellect", SPI = "Spirit", SP = "Spell Power",
  WEAPON_DPS = "Weapon DPS", SLOW_BONUS = "Slow weapon bonus",
  CRIT_RATING = "Crit rating", HIT_RATING = "Hit rating", HASTE_RATING = "Haste rating",
  MASTERY_RATING = "Mastery rating", VERS_RATING = "Versatility rating",
}

-- equipLoc -> inventory slot ids it can go in
RG.EQUIP_SLOTS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
  INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RELIC = { 18 }, INVTYPE_RANGED = { 18 },
}

RG.SLOT_NAMES = {
  [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs",
  [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket",
  [14] = "Trinket", [15] = "Back", [16] = "Main Hand", [17] = "Off Hand", [18] = "Relic",
}
RG.SLOT_ORDER = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

-- ---------------------------------------------------------------------------
-- Registry
-- ---------------------------------------------------------------------------
RG.CLASSES, RG.RACES, RG.ROUTES, RG.PROFESSIONS = {}, {}, {}, {}
-- The Waypath+ logo (Media/Logo.tga, 64x64) and its chat-line form
RG.LOGO = "Interface\\AddOns\\Waypath\\Media\\Logo"
RG.LOGO_LARGE = "Interface\\AddOns\\Waypath\\Media\\LogoLarge"
RG.LOGO_INLINE = "|T" .. RG.LOGO .. ":14:14|t "
function RG.RegisterClass(token, def) def.token = token; RG.CLASSES[token] = def end
function RG.RegisterRace(token, def) def.token = token; RG.RACES[token] = def end
function RG.RegisterRoute(faction, def) RG.ROUTES[faction] = def end
function RG.RegisterProfession(name, def) RG.PROFESSIONS[name] = def end
