-- Offline art audit for every Waypath+ trading card. Run: texlua tools/arcade/audit_art.lua   (exit code 1 on problems)
-- It checks what can be checked without the game: every NPC card has a creature model id, every place card has a painting
-- cell inside its atlas, no two cards share a picture by accident, and every card has the data its face needs.
-- (What only the game can tell, whether a model id really loads, is /wp cardcheck, which also remembers the answer.)
local RG = {}
local function load(f) local c = assert(loadfile(f)); c("Waypath", RG) end
for _, f in ipairs({ "ArcadeCards.lua", "ArcadeMythic.lua", "ArcadeArt.lua", "ArcadeDungeons.lua", "ArcadeField.lua", "ArcadeRaids.lua", "ArcadeHolidays.lua", "ArcadeArtFix.lua", "ArcadePlaces.lua" }) do
  if io.open(f) then load(f) end
end
RG.ARCADE_DUNGEON_CREATURE = RG.ARCADE_DUNGEON_CREATURE or {}
RG.ARCADE_PLACE_FILE = RG.ARCADE_PLACE_FILE or {}
local byCreature, byScreen, mythic = 0, 0, 0
RG.ARCADE_DATA = RG.ARCADE_DATA or {}
local bad, warn = {}, {}
local counts = { 0, 0, 0 }
local modelUse, cellUse = {}, {}
local seenName = {}
for i, d in ipairs(RG.ARCADE_DATA) do
  local kind, name, tier, ref, text, src = d[1], d[2], d[3], d[4], d[5], d[6]
  if type(name) ~= "string" or name == "" then bad[#bad + 1] = "card #" .. i .. " has no name" end
  if seenName[name] then bad[#bad + 1] = "duplicate card name: " .. tostring(name) end
  seenName[name] = true
  if not (tier and tier >= 1 and tier <= 7) then bad[#bad + 1] = "bad tier on " .. tostring(name) end
  if tier == 7 then mythic = mythic + 1   -- (the Mythics draw their own art: ArcadeMythic.lua)
  elseif kind == 1 then
    counts[1] = counts[1] + 1
    if type(ref) ~= "number" or ref <= 0 then bad[#bad + 1] = "item with no item id: " .. name end
  elseif kind == 2 then
    counts[2] = counts[2] + 1
    local id = RG.ARCADE_NPC[name]
    if not id and RG.ARCADE_DUNGEON_CREATURE[name] then byCreature = byCreature + 1   -- (a WoW Forever creature: drawn by its creature id once the game knows it)
    elseif not id and (text or ""):find("^Raid boss") then warn[#warn + 1] = "raid encounter with no creature (drawn scenery): " .. name
    elseif not id then bad[#bad + 1] = "NPC with no model id: " .. name
    elseif type(id) ~= "number" or id <= 0 then bad[#bad + 1] = "NPC with a bad model id: " .. name
    else modelUse[id] = modelUse[id] or {}; table.insert(modelUse[id], name) end
  elseif kind == 3 then
    counts[3] = counts[3] + 1
    local e = RG.ARCADE_PLACE[name]
    if not e and RG.ARCADE_PLACE_FILE[name] then byScreen = byScreen + 1   -- (a dungeon's own loading screen)
    elseif not e and (src or ""):len() > 0 then warn[#warn + 1] = "dungeon or raid place with no painting (drawn scenery): " .. name
    elseif not e then bad[#bad + 1] = "place with no painting: " .. name
    else
      local atlas, cell = e[1], e[2]
      if not (atlas and atlas >= 1 and atlas <= 4) or not (cell and cell >= 0 and cell < 96) then bad[#bad + 1] = "place painting out of range: " .. name
      else
        local k = atlas .. ":" .. cell
        if cellUse[k] then bad[#bad + 1] = "two places share one painting: " .. name .. " and " .. cellUse[k] end
        cellUse[k] = name
      end
    end
  end
end
for name in pairs(RG.ARCADE_NPC) do if not seenName[name] and not name:find("^%d") then warn[#warn + 1] = "model id for a card that does not exist: " .. name end end
for name in pairs(RG.ARCADE_PLACE) do if not seenName[name] then warn[#warn + 1] = "painting for a card that does not exist: " .. name end end
local shared = 0
for id, names in pairs(modelUse) do if #names > 1 then shared = shared + 1 end end
print(string.format("cards: %d items, %d NPCs, %d places, %d Mythics; %d creature models are shared by several cards (they get their own scenery)", counts[1], counts[2], counts[3], mythic, shared))
print(string.format("%d WoW Forever creatures drawn by creature id once the game knows them; %d dungeons and raids show their loading screen", byCreature, byScreen))
for _, l in ipairs(warn) do print("warning: " .. l) end
for _, l in ipairs(bad) do print("PROBLEM: " .. l) end
if #bad == 0 then print("Art audit passed.") end
os.exit(#bad == 0 and 0 or 1)
