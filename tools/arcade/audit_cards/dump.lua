-- Load the card data files as the add-on does and write every card with the art it gets (for audit_cards.py).
-- Usage (from the repo root): lua5.1 tools/arcade/audit_cards/dump.lua <out dir>
local OUT = (arg and arg[1] or "/tmp/cards"):gsub("/$", "") .. "/"
local RG = {}
local files = {}
for line in io.lines("Waypath_Forever.toc") do
  line = line:gsub("\r", "")
  if line:match("^Arcade.*%.lua$") then files[#files + 1] = line end
end
for _, f in ipairs(files) do
  local src = io.open(f):read("*a")
  -- only the data files (they don't touch frames at load)
  if not src:find("CreateFrame", 1, true) or f:match("Art") then
    local ch = loadfile(f); if ch then pcall(ch, "Waypath", RG) end
  end
end
local npc = RG.ARCADE_NPC or {}
local cre = RG.ARCADE_DUNGEON_CREATURE or {}
local out = io.open(OUT .. "cards.tsv", "w")
local seen = {}
for i, r in ipairs(RG.ARCADE_DATA or {}) do
  local name = r[2]
  local dup = seen[name] and "dup" or ""
  seen[name] = (seen[name] or 0) + 1
  out:write(table.concat({ i, r[1], name, r[3], r[4] or "", r[5] or "", npc[name] or "", cre[name] or "", tostring(r[6] or ""), dup }, "\t"), "\n")
end
out:close()
local o2 = io.open(OUT .. "sources.tsv", "w")
local function src(tbl, tag) for k, v in pairs(tbl or {}) do o2:write(tag, "\t", k, "\t", v, "\n") end end
src(RG.ARCADE_DUNGEON_NPC, "dungeon"); src(RG.ARCADE_FIELD_DISPLAY, "field"); src(RG.ARCADE_RAID_NPC, "raid"); src(RG.ARCADE_HOLIDAY_NPC, "holiday")
o2:close()
print(#(RG.ARCADE_DATA or {}), "cards")
for _, f in ipairs(files) do io.write(f, " ") end print()
