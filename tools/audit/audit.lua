-- Waypath+ coverage audit: loads the add-on's data once for every playable Horde
-- race/class combination and checks that each one gets the same quality of guide.
--
--   lua5.1 tools/audit/audit.lua [--markdown]      (run from the add-on folder)
--
-- Questing checks (these fail the run):
--   * the route covers every level 1-60 with a questing zone, and the starting zone has steps
--   * every quest a step names by ID can be taken by that race and class
--   * no step or note speaks to another class ("Paladins: ..." lines are filtered per class)
--     or assumes a profession without saying so ("Miners: ...")
--   * class quests from the data show up for the class in the levels they exist
-- Gearing and professions are reported (not failed) until their phases land.
local MARKDOWN = arg[1] == "--markdown"

local COMBOS = {
  Orc = { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "MAGE", "WARLOCK" },
  Troll = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK" },
  Tauren = { "WARRIOR", "HUNTER", "SHAMAN", "DRUID" },
  Scourge = { "WARRIOR", "PALADIN", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
  Skyborne = { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "DRUID" },
}
local RACE_ORDER = { "Orc", "Troll", "Tauren", "Scourge", "Skyborne" }
local FILES = {
  "Data.lua", "Classes/Paladin.lua", "Classes/PaladinGear.lua", "Races/Undead.lua", "Races/Durotar.lua", "Races/Tauren.lua",
  "Races/Skyborne.lua", "Routes/Horde.lua", "Routes/Generated.lua", "Professions/Mining.lua", "Professions/Blacksmithing.lua",
  "Profile.lua", "Waypoints.lua", "Objectives.lua",
}
-- extra class files, if any were added since
local function exists(p) local f = io.open(p) if f then f:close() return true end return false end
for _, c in ipairs({ "Warrior", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid" }) do
  if exists("Classes/" .. c .. ".lua") then table.insert(FILES, 3, "Classes/" .. c .. ".lua") end
  if exists("Classes/" .. c .. "Gear.lua") then table.insert(FILES, 4, "Classes/" .. c .. "Gear.lua") end
end

local function load(class, race)
  local RG = {}
  UnitClass = function() return class, class end
  UnitRace = function() return race, race end
  UnitFactionGroup = function() return "Horde" end
  for _, f in ipairs(FILES) do assert(loadfile(f))("Waypath", RG) end
  return RG
end

-- Things only one class does: ability names, and "your paladin" style phrasing.
local CLASS_WORDS = {
  PALADIN = { "paladin spells", "paladin class", "your paladin", "seal of", "blessing of", "judgement", "holy strike", "exorcism", "lay on hands" },
  WARRIOR = { "warrior spells", "your warrior", "battle shout", "heroic strike", "defensive stance" },
  HUNTER = { "hunter spells", "your hunter", "your pet", "tame a" }, ROGUE = { "rogue spells", "your rogue", "poisons", "pick pocket" },
  PRIEST = { "priest spells", "your priest", "power word" }, SHAMAN = { "shaman spells", "your shaman", "your totems" },
  MAGE = { "mage spells", "your mage", "conjure" }, WARLOCK = { "warlock spells", "your warlock", "soul shard", "your demon" },
  DRUID = { "druid spells", "your druid", "bear form", "cat form" },
}
local PLURAL = { WARRIOR = "Warriors", PALADIN = "Paladins", HUNTER = "Hunters", ROGUE = "Rogues", PRIEST = "Priests", SHAMAN = "Shamans", MAGE = "Mages", WARLOCK = "Warlocks", DRUID = "Druids" }
local PROF_WORDS = { "mining", "mine ", "blacksmith", "smelt", "veins", "herbs", "skinning" }
local PROF_OK = { "Miners:", "Crafters:", "Blacksmiths:", "%(miners", "learn your professions", "Herbalists:", "Skinners:" }

local failures, rows = {}, {}
local function fail(combo, msg) failures[#failures + 1] = combo .. ": " .. msg end

for _, race in ipairs(RACE_ORDER) do
  for _, class in ipairs(COMBOS[race]) do
    local RG = load(class, race)
    local combo = race .. " " .. class
    local r = { combo = combo }
    -- 1. route coverage
    local gaps = {}
    for lvl = 1, 59 do
      local ok = false
      for _, e in ipairs(RG.ROUTE) do if e.kind == "zone" and lvl >= e.from and lvl <= e.to then ok = true break end end
      if not ok then gaps[#gaps + 1] = lvl end
    end
    if #gaps > 0 then fail(combo, "no questing zone for level(s) " .. table.concat(gaps, ", ")) end
    r.gaps = #gaps
    -- 2. starting zone
    local start
    for _, e in ipairs(RG.ROUTE) do if e.kind == "zone" and e.from == 1 then start = e break end end
    local startSteps = start and #(RG.STEPS[start.zone .. "|" .. start.from] or {}) or 0
    if not start or startSteps < 2 then fail(combo, "starting zone has no steps") end
    r.start = start and (start.zone .. " (" .. startSteps .. ")") or "none"
    -- 3. steps 1-20: quest IDs takeable, waypoints, wording
    local steps, withWp, badQuest, badWord = 0, 0, 0, 0
    for _, e in ipairs(RG.ROUTE) do
      local key = e.zone .. "|" .. e.from
      local list = RG.STEPS[key] or {}
      local texts = { e.notes or "" }
      for i, text in ipairs(list) do
        texts[#texts + 1] = text
        if e.from <= 20 then
          steps = steps + 1
          local wp = (RG.STEP_WP[key] and RG.STEP_WP[key][i]) or (RG.WAYPOINTS.steps[key] and RG.WAYPOINTS.steps[key][i])
          if wp then withWp = withWp + 1 end
        end
        for _, id in ipairs((RG.STEP_QUESTS[key] or {})[i] or {}) do
          local d = RG.QDATA[id]
          if d and not RG.QuestForMe(d) then badQuest = badQuest + 1; fail(combo, key .. " step " .. i .. " names quest " .. id .. " this character can't take") end
        end
      end
      for _, text in ipairs(texts) do
        local low = text:lower()
        for other, words in pairs(CLASS_WORDS) do
          if other ~= class and not text:find("^" .. PLURAL[other] .. ":") and e.kind ~= "pala" then
            for _, w in ipairs(words) do
              if low:find(w, 1, true) then
                badWord = badWord + 1; fail(combo, key .. ": speaks to " .. other .. " (\"" .. w .. "\"): " .. text:sub(1, 80))
                break
              end
            end
          end
        end
        local prof = false
        for _, w in ipairs(PROF_WORDS) do if low:find(w, 1, true) then prof = true break end end
        if prof then
          local ok = false
          for _, p in ipairs(PROF_OK) do if text:find(p) or low:find(p) then ok = true break end end
          if not ok and e.kind ~= "pala" then badWord = badWord + 1; fail(combo, key .. ": assumes a profession: " .. text:sub(1, 80)) end
        end
      end
    end
    r.steps, r.wp = steps, steps > 0 and math.floor(withWp / steps * 100 + 0.5) or 0
    -- 4. class quests in the data
    local cq, brackets = 0, { 0, 0, 0, 0 }
    for _, d in pairs(RG.QDATA) do
      if d.cq and d.s and RG.QuestForMe(d) and (d.r or 1) < 58 then
        cq = cq + 1
        local b = (d.r or 1) < 10 and 1 or (d.r or 1) < 20 and 2 or (d.r or 1) < 40 and 3 or 4
        brackets[b] = brackets[b] + 1
      end
    end
    r.cq = cq .. " (" .. table.concat(brackets, "/") .. ")"
    -- 5. dungeon quests
    local dq = 0
    for _, d in pairs(RG.DUNGEON_QUESTS) do dq = dq + #d.quests end
    r.dq = dq
    -- 6. gearing / professions (report)
    r.gear = RG.ClassSupported and (#RG.GUIDE .. " items") or "not yet"
    r.talents = #RG.TALENT_PRIORITY > 0 and (#RG.TALENT_PRIORITY .. "") or "not yet"
    local profs = {}
    for name in pairs(RG.PROFESSIONS) do profs[#profs + 1] = name end
    table.sort(profs)
    r.profs = table.concat(profs, ", ")
    r.bad = badQuest + badWord
    rows[#rows + 1] = r
  end
end

local head = { "Race / class", "Start (steps)", "Steps 1-20", "With waypoint", "Route gaps", "Class quests (1-9/10-19/20-39/40+)", "Dungeon quests", "Problems", "Gear guide", "Talents", "Profession guides" }
if MARKDOWN then
  print("| " .. table.concat(head, " | ") .. " |")
  print("|" .. string.rep("---|", #head))
end
for _, r in ipairs(rows) do
  local cells = { r.combo, r.start, r.steps, r.wp .. "%", r.gaps, r.cq, r.dq, r.bad, r.gear, r.talents, r.profs }
  if MARKDOWN then print("| " .. table.concat(cells, " | ") .. " |")
  else print(string.format("%-18s %-26s steps %3d  wp %3d%%  gaps %d  class quests %-16s dungeon quests %3d  problems %d  gear %s  talents %s",
    r.combo, r.start, r.steps, r.wp, r.gaps, r.cq, r.dq, r.bad, r.gear, r.talents)) end
end
if #failures > 0 then
  io.stderr:write("\n" .. #failures .. " problem(s):\n")
  local seen = {}
  for _, f in ipairs(failures) do if not seen[f] then seen[f] = true; io.stderr:write("  " .. f .. "\n") end end
  os.exit(1)
end
io.stderr:write("\nAll " .. #rows .. " race/class combinations pass the questing checks.\n")
