-- Waypath+ weapon skills: a heads-up when the skill of the weapon you're using is far behind your level (you miss
-- more and hit for less until it catches up), and where to learn a weapon type you can't use yet.
-- Weapon masters come from the game data (Professions/Generated.lua RG.WEAPON_MASTERS). Classic-style clients only:
-- clients without weapon skills (GetSkillLineInfo has none) simply never say anything.
local _, RG = ...

-- the item's weapon type (GetItemInfoInstant's subclass, the same in every language) -> the skill's English name
local SUB = { [0] = "Axes", [1] = "Two-Handed Axes", [2] = "Bows", [3] = "Guns", [4] = "Maces", [5] = "Two-Handed Maces",
  [6] = "Polearms", [7] = "Swords", [8] = "Two-Handed Swords", [10] = "Staves", [13] = "Fist Weapons", [15] = "Daggers",
  [16] = "Thrown", [18] = "Crossbows" }
-- what each class can learn at a weapon master
local CAN = {
  WARRIOR = { "Axes", "Two-Handed Axes", "Bows", "Crossbows", "Daggers", "Fist Weapons", "Guns", "Maces", "Two-Handed Maces", "Polearms", "Staves", "Swords", "Two-Handed Swords", "Thrown" },
  PALADIN = { "Axes", "Two-Handed Axes", "Maces", "Two-Handed Maces", "Polearms", "Swords", "Two-Handed Swords" },
  HUNTER  = { "Axes", "Two-Handed Axes", "Bows", "Crossbows", "Daggers", "Fist Weapons", "Guns", "Polearms", "Staves", "Swords", "Two-Handed Swords", "Thrown" },
  ROGUE   = { "Bows", "Crossbows", "Daggers", "Fist Weapons", "Guns", "Maces", "Swords", "Thrown" },
  PRIEST  = { "Daggers", "Maces", "Staves" },
  SHAMAN  = { "Axes", "Two-Handed Axes", "Daggers", "Fist Weapons", "Maces", "Two-Handed Maces", "Staves" },
  MAGE    = { "Daggers", "Staves", "Swords" },
  WARLOCK = { "Daggers", "Staves", "Swords" },
  DRUID   = { "Daggers", "Fist Weapons", "Maces", "Two-Handed Maces", "Staves" },
}
local canLearn = {}
for cls, l in pairs(CAN) do local s = {}; for _, k in ipairs(l) do s[k] = true end; canLearn[cls] = s end

-- your weapon skills: { [English name] = { rank, max } } (English clients; other languages are matched through the
-- skill spells' translated names)
local SKILL_SPELL = { Axes = 196, ["Two-Handed Axes"] = 197, Maces = 198, ["Two-Handed Maces"] = 199, Polearms = 200, Swords = 201,
  ["Two-Handed Swords"] = 202, Staves = 227, Bows = 264, Guns = 266, Crossbows = 5011, Daggers = 1180, Thrown = 2567, ["Fist Weapons"] = 15590 }
local localName
local function english(name)
  if SKILL_SPELL[name] then return name end
  if not localName then
    localName = {}
    local gsi = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    for en, sid in pairs(SKILL_SPELL) do
      local ok, loc = pcall(gsi, sid)
      if ok and type(loc) == "string" then localName[loc] = en end
    end
  end
  return localName[name]
end
function RG.WeaponSkills()
  local out = {}
  if not (GetNumSkillLines and GetSkillLineInfo) then return out end
  for i = 1, GetNumSkillLines() do
    local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
    local en = name and not header and english(name)
    if en and rank and max then out[en] = { rank, max } end
  end
  return out
end

-- the closest weapon master for your faction who teaches it: {map, x, y, label}
function RG.WeaponMaster(skill)
  local list = RG.WEAPON_MASTERS and RG.WEAPON_MASTERS[skill]
  if not list then return nil end
  local fac = RG.PLAYER_FACTION == "Alliance" and "A" or "H"
  local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local first
  for _, m in ipairs(list) do
    if m[5] == fac or m[5] == "AH" then
      if m[1] == here then return m end
      first = first or m
    end
  end
  return first
end

local last   -- the weapon master the last message was about (for /wp weapon)
local function said(key)
  RG.db.weaponSaid = RG.db.weaponSaid or {}
  if RG.db.weaponSaid[key] then return true end
  RG.db.weaponSaid[key] = true
  return false
end
local TAIL = " |cff808080(weapon skill tips: Settings)|r"

-- The weapons you're holding: is one's skill far behind? (said once per weapon type every 5 levels)
function RG.WeaponSkillCheck()
  if not (RG.db and RG.Opt and RG.Opt("weaponTips")) or (RG.IsAlt and RG.IsAlt()) then return end
  local lvl = UnitLevel and UnitLevel("player") or 1
  if lvl < 10 then return end
  local skills = RG.WeaponSkills()
  if not next(skills) then return end
  for _, slot in ipairs({ 16, 17, 18 }) do
    local id = GetInventoryItemID and GetInventoryItemID("player", slot)
    if id and GetItemInfoInstant then
      local _, _, _, _, _, classID, subID = GetItemInfoInstant(id)
      local sk = classID == 2 and SUB[subID]
      local s = sk and skills[sk]
      if s and s[2] - s[1] >= 25 and not said(sk .. "@" .. math.floor(lvl / 5)) then
        RG.Print("Your " .. sk .. " skill is " .. s[1] .. "/" .. s[2] .. ": you'll miss more and hit softer with it until it catches up. "
          .. "It rises as you fight with it; a few fights on mobs at your level do it." .. TAIL)
        return
      end
    end
  end
end

-- A weapon you just got but can't use yet because you haven't learned its type: where to learn it.
function RG.WeaponLearnCheck(itemID)
  if not (RG.db and RG.Opt and RG.Opt("weaponTips")) or (RG.IsAlt and RG.IsAlt()) then return end
  if not (itemID and GetItemInfoInstant) then return end
  local _, _, _, _, _, classID, subID = GetItemInfoInstant(itemID)
  local sk = classID == 2 and SUB[subID]
  if not sk then return end
  local skills = RG.WeaponSkills()
  if not next(skills) or skills[sk] then return end
  local _, cls = UnitClass("player")
  if not (canLearn[cls] and canLearn[cls][sk]) then return end
  if said("learn" .. sk) then return end
  local m = RG.WeaponMaster(sk)
  last = m
  RG.Print("You can't use " .. sk .. " yet: " .. (m and (m[4] .. " teaches it") or "a weapon master in a capital city teaches it")
    .. " (10 silver)." .. (m and " |cffffd100/wp weapon|r puts them on your map." or "") .. TAIL)
end

-- /wp weapon: the last weapon master mentioned (or the one for your weapon's type) on the map, with the arrow
function RG.WeaponMasterPin(skill)
  local m = (skill and skill ~= "" and RG.WeaponMaster(skill)) or last
  if not m then
    RG.Print("Weapon masters: Orgrimmar, Undercity and Thunder Bluff for the Horde; Stormwind, Ironforge and Darnassus for the Alliance.")
    return
  end
  RG.PinWaypoint({ m[1], m[2], m[3], m[4] })
end

do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "SKILL_LINES_CHANGED", "CHAT_MSG_LOOT", "PLAYER_ENTERING_WORLD" }) do pcall(f.RegisterEvent, f, e) end
  f:SetScript("OnEvent", function(_, ev, msg)
    if not RG.db then return end
    if ev == "CHAT_MSG_LOOT" then
      -- only what you looted yourself ("You receive loot: ...")
      if type(msg) ~= "string" or (RG.IsSecret and RG.IsSecret(msg)) then return end
      if LOOT_ITEM_SELF and not msg:find((LOOT_ITEM_SELF:gsub("%%s.*", "")), 1, true) then return end
      local id = tonumber(msg:match("item:(%d+)"))
      if id then pcall(RG.WeaponLearnCheck, id) end
      return
    end
    if RG.Debounce then RG.Debounce("weaponSkill", 2, function() pcall(RG.WeaponSkillCheck) end) else pcall(RG.WeaponSkillCheck) end
  end)
end

table.insert(RG.OPTIONS, { key = "weaponTips", label = "Weapon skill tips: when my weapon's skill is far behind, and where to learn a weapon type I just got", default = true })

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
  if cmd and (cmd:lower() == "weapon" or cmd:lower() == "weapons") then
    -- "/wp weapon polearms": a weapon type's master; plain "/wp weapon": the last one mentioned
    local want
    if rest and rest ~= "" then
      local r = rest:lower()
      for _, sk in pairs(SUB) do if sk:lower() == r or sk:lower() == r .. "s" then want = sk end end
      if not want then for _, sk in pairs(SUB) do if sk:lower():find("^" .. r) then want = sk end end end
      if not want then for _, sk in pairs(SUB) do if sk:lower():find(r, 1, true) then want = sk end end end
    end
    RG.WeaponMasterPin(want)
    return
  end
  return base(msg)
end
