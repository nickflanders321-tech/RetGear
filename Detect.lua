-- Waypath+ profile detection: what the game can tell us without asking (faction, race,
-- class, level, zone, professions), and live profession tracking. When you learn or drop a
-- profession the guide follows: it adds or removes that profession's plan and says so.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY

RG.PROFESSION_LIST = { "Mining", "Herbalism", "Skinning", "Blacksmithing", "Engineering", "Alchemy",
  "Leatherworking", "Tailoring", "Enchanting", "Cooking", "Fishing", "First Aid" }
local IS_PROF = {}
for _, n in ipairs(RG.PROFESSION_LIST) do IS_PROF[n] = true end

-- One line per character: "Undead Paladin, level 14, Tirisfal Glades".
function RG.Detect()
  local d = { faction = RG.PLAYER_FACTION or (UnitFactionGroup and UnitFactionGroup("player")) or "Horde" }
  d.race = UnitRace and (UnitRace("player")) or "?"
  d.class = UnitClass and (UnitClass("player")) or "?"
  d.level = UnitLevel and UnitLevel("player") or 1
  d.zone = (GetRealZoneText and GetRealZoneText()) or ""
  if d.zone == "" and GetZoneText then d.zone = GetZoneText() or "" end
  d.profs = {}
  for name, p in pairs(RG.Professions()) do if IS_PROF[name] then d.profs[name] = p.rank end end
  return d
end
function RG.DetectLine()
  local d = RG.Detect()
  return string.format("%s %s, level %d%s", d.race, d.class, d.level, d.zone ~= "" and (", " .. d.zone) or "")
end

-- ---------------------------------------------------------------------------
-- Live profession tracking
-- ---------------------------------------------------------------------------
local checking, missing = false, {}
local function check(first)
  if not RG.db then return end
  local known = RG.db.knownProfs
  local now = {}
  for name in pairs(RG.Professions()) do if IS_PROF[name] then now[name] = true end end
  if not known then   -- first run on this character: remember what it has, say nothing
    RG.db.knownProfs = now
    return
  end
  local changed = false
  for name in pairs(now) do
    missing[name] = nil
    if not known[name] then
      known[name] = true; changed = true
      if RG.db.profIgnore then RG.db.profIgnore[name] = nil end
      RG.db.plan = RG.db.plan or {}
      RG.db.plan[name] = true
      RG.Notify("Waypath+: " .. name .. " added to your guided professions")
      RG.Print(GREEN .. name .. "|r learned. It now has its own section on the Professions tab, with this level's step and materials.")
    end
  end
  for name in pairs(known) do
    if not now[name] then
      -- the skill list is briefly empty while loading: only drop it after a second sighting
      if missing[name] then
        known[name] = nil; missing[name] = nil; changed = true
        if RG.db.plan then RG.db.plan[name] = nil end
        RG.Notify("Waypath+: " .. name .. " removed from your guided professions")
        RG.Print(GREY .. name .. " dropped. Its section is hidden; /wp setup brings it back if you plan to relearn it.|r")
      else
        missing[name] = true
      end
    end
  end
  if changed then
    if RG.RefreshUI then RG.RefreshUI() end
    if RG.RefreshTracker then RG.RefreshTracker() end
  end
end

local pending
local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event)
  if pending then return end
  pending = true
  C_Timer.After(event == "PLAYER_LOGIN" and 4 or 1.5, function()
    pending = nil
    local ok, err = pcall(check)
    if not ok and RG.RecordError then RG.RecordError("Detect: " .. tostring(err)) end
    -- a dropped profession needs a second look a few seconds later to be sure
    if next(missing) then C_Timer.After(4, function() pcall(check) end) end
  end)
end)

-- Optional: ignore a profession you know but don't want guided (set from setup).
function RG.IgnoreProfession(name, on)
  RG.db.profIgnore = RG.db.profIgnore or {}
  RG.db.profIgnore[name] = on and true or nil
  RG.db.plan = RG.db.plan or {}
  RG.db.plan[name] = (not on) and true or false
end
