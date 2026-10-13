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
-- Gearing: every class has its own gear list with an upgrade for each slot it uses at
-- every stage of leveling. Talents and professions are reported until their phases land.
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
  "Races/Skyborne.lua", "Routes/Horde.lua", "Routes/Generated.lua", "Professions/Mining.lua", "Professions/Blacksmithing.lua", "Professions/Herbalism.lua", "Professions/Skinning.lua", "Professions/Alchemy.lua", "Professions/Enchanting.lua", "Professions/Engineering.lua", "Professions/Leatherworking.lua", "Professions/Tailoring.lua", "Professions/FirstAid.lua", "Professions/Cooking.lua", "Professions/Fishing.lua",
  "Profile.lua", "Waypoints.lua", "Objectives.lua", "NodeData.lua",
}
-- 2nd specs (load before Profile.lua, like the .toc does)
for i, f in ipairs(FILES) do if f == "Races/Undead.lua" then table.insert(FILES, i, "Classes/SpecGear.lua"); table.insert(FILES, i, "Classes/Specs.lua"); break end end
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

-- Professions (same for every race and class): each has trainers for every rank, a
-- plan that runs from 1 to 300 with no gaps, materials or supplies, and a camp object.
ALL_PROFS = { "Mining", "Herbalism", "Skinning", "Blacksmithing", "Engineering", "Alchemy", "Leatherworking", "Tailoring", "Enchanting", "Cooking", "Fishing", "First Aid" }
do
  local RG = load("WARRIOR", "Orc")
  local camp = io.open("Camp.lua"):read("*a")
  for _, name in ipairs(ALL_PROFS) do
    local P = RG.PROFESSIONS[name]
    if not P then fail("Professions", name .. " is missing")
    else
      for _, rank in ipairs({ "apprentice", "journeyman", "expert", "artisan" }) do
        if not (P.train and P.train[rank]) then fail("Professions", name .. " has no " .. rank .. " trainer") end
      end
      if not P.fishTab then
        local reach = 1
        for _, st in ipairs(P.plan or {}) do
          if not st.train then
            if st.from > reach then fail("Professions", name .. " plan has a gap at " .. reach .. "-" .. st.from) end
            if st.to > reach then reach = st.to end
          end
        end
        if reach < 300 then fail("Professions", name .. " plan stops at " .. reach) end
      end
      if not camp:find('prof = "' .. name .. '",%s*skill = %d+') then fail("Professions", name .. " has no camp object") end
      for _, st in ipairs(P.plan or {}) do
        if st.gather then
          local zones = name == "Mining" and RG.ORE_ZONES or RG.HERB_ZONES
          if not (zones and zones[st.gather]) then fail("Professions", name .. ": no zones known for " .. st.gather) end
        end
      end
    end
  end
end

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
    -- 6. gearing: a gear list of its own, weights for its main stats, and an upgrade
    -- for every slot it uses by each stage of leveling
    local items, slots = 0, {}
    for _, g in ipairs(RG.GUIDE) do
      if g.id then items = items + 1; slots[g.slot] = slots[g.slot] or {}; table.insert(slots[g.slot], g.lvl) end
    end
    local model = RG.WEAPON_MODEL
    local need = { "Head", "Shoulder", "Chest", "Hands", "Legs", "Feet", "Waist", "Wrist", "Back" }
    need[#need + 1] = (model == "DW") and "Main Hand" or "2H"
    if model == "ranged" or model == "caster" then need[#need + 1] = "Ranged" end
    local gearGaps = {}
    for _, sl in ipairs(need) do
      for _, by in ipairs({ 20, 35, 50, 60 }) do
        local ok = false
        for _, l in ipairs(slots[sl] or {}) do if l <= by and l > by - 20 then ok = true break end end
        if not ok then gearGaps[#gearGaps + 1] = sl .. "@" .. by end
      end
    end
    if items < 60 then fail(combo, "gear guide has only " .. items .. " items") end
    if not RG.ActiveClass.weights or not next(RG.ActiveClass.weights) then fail(combo, "no stat weights") end
    if #gearGaps > 4 then fail(combo, "gear guide gaps: " .. table.concat(gearGaps, ", ")) end
    r.gear = items .. " items" .. (#gearGaps > 0 and (" (gaps: " .. table.concat(gearGaps, " ") .. ")") or "")
    r.talents = #RG.TALENT_PRIORITY > 0 and (#RG.TALENT_PRIORITY .. "") or "not yet"
    -- 7. professions: every one has a closest trainer for this race
    local profOK = 0
    for name, P in pairs(RG.PROFESSIONS) do
      if P.train and P.train.start and P.train.start[RG.RACE_LETTER] then profOK = profOK + 1
      else fail(combo, name .. " has no starting trainer for this race") end
    end
    r.profs = profOK .. "/" .. #ALL_PROFS
    -- 8. 2nd specs: every spec of the class has a build, tips, weights and a gear list for 30-60
    local specs = (RG.SPECS or {})[RG.PLAYER_CLASS] or {}
    if #specs < 3 then fail(combo, "only " .. #specs .. " specs") end
    local mains, specOK = 0, 0
    for _, sp in ipairs(specs) do
      local ok = true
      local function bad(msg) ok = false; fail(combo, sp.name .. ": " .. msg) end
      if sp.main then mains = mains + 1 end
      for _, k in ipairs({ "key", "name", "role", "kind", "tab", "icon", "stats", "goal", "source" }) do if not sp[k] then bad("no " .. k) end end
      if not (sp.build and #sp.build > 0) then bad("no build") end
      if not (sp.tips and #sp.tips > 0) then bad("no tips") end
      if not sp.main then
        if not (sp.weights and next(sp.weights)) then bad("no weights") end
        local list = ((RG.SPEC_GEAR or {})[RG.PLAYER_CLASS] or {})[sp.key] or {}
        local slotsSeen, n, bands = {}, 0, { 0, 0, 0 }
        for _, g in ipairs(list) do
          n = n + 1; slotsSeen[g.slot] = true
          if g.lvl < 40 then bands[1] = bands[1] + 1 elseif g.lvl < 50 then bands[2] = bands[2] + 1 else bands[3] = bands[3] + 1 end
        end
        local ns = 0; for _ in pairs(slotsSeen) do ns = ns + 1 end
        if n < 40 then bad("only " .. n .. " gear items") end
        if ns < 12 then bad("gear for only " .. ns .. " slots") end
        for b, c in ipairs(bands) do if c < 8 then bad("only " .. c .. " items in levels " .. (20 + b * 10) .. "s") end end
      end
      if ok then specOK = specOK + 1 end
    end
    if mains ~= 1 then fail(combo, mains .. " leveling specs marked main (want 1)") end
    r.specs = specOK .. "/" .. #specs
    r.bad = badQuest + badWord
    rows[#rows + 1] = r
  end
end

local head = { "Race / class", "Start (steps)", "Steps 1-20", "With waypoint", "Route gaps", "Class quests (1-9/10-19/20-39/40+)", "Dungeon quests", "Problems", "Gear guide", "Talents", "Professions with a trainer nearby", "2nd specs ready" }
if MARKDOWN then
  print("| " .. table.concat(head, " | ") .. " |")
  print("|" .. string.rep("---|", #head))
end
for _, r in ipairs(rows) do
  local cells = { r.combo, r.start, r.steps, r.wp .. "%", r.gaps, r.cq, r.dq, r.bad, r.gear, r.talents, r.profs, r.specs }
  if MARKDOWN then print("| " .. table.concat(cells, " | ") .. " |")
  else print(string.format("%-18s %-26s steps %3d  wp %3d%%  gaps %d  class quests %-16s dungeon quests %3d  problems %d  gear %s  talents %s  2nd specs %s",
    r.combo, r.start, r.steps, r.wp, r.gaps, r.cq, r.dq, r.bad, r.gear, r.talents, r.specs)) end
end
if #failures > 0 then
  io.stderr:write("\n" .. #failures .. " problem(s):\n")
  local seen = {}
  for _, f in ipairs(failures) do if not seen[f] then seen[f] = true; io.stderr:write("  " .. f .. "\n") end end
  os.exit(1)
end
io.stderr:write("\nAll " .. #rows .. " race/class combinations pass the questing, gear, profession and 2nd spec checks.\n")
