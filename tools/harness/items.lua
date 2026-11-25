-- Item data for the simulated world: LibItemDB's WoW Forever tables (the data/itemdb branch, MIT), loaded in a
-- sandbox of their own. The files are copied out of the branch with `git show` into tools/harness/.cache/itemdb the
-- first time (that folder is ignored by git); run `git fetch origin data/itemdb` if the branch isn't there.
local I = {}

local FILES = { "LibItemDB-1.0.lua",
  "Forever/_core/Armor.lua", "Forever/_core/Weapon.lua", "Forever/_core/Quest.lua", "Forever/_core/Consumable.lua",
  "Forever/_core/Miscellaneous.lua", "Forever/_core/Reagent.lua", "Forever/_core/TradeGoods.lua", "Forever/_core/Container.lua",
  "Forever/_core/Projectile.lua", "Forever/_core/Quiver.lua", "Forever/_core/Recipe.lua", "Forever/_core/Key.lua",
  "Forever/_core/EquipStats.lua", "Forever/_core/ReqLevels.lua", "Forever/_core/SellPrices.lua", "Forever/enUS/Names.lua" }

local function exists(p) local f = io.open(p, "rb"); if f then f:close() return true end return false end

-- copy the files out of the branch (once)
function I.ensure(cache)
  for _, f in ipairs(FILES) do
    local dest = cache .. "/" .. f
    if not exists(dest) then
      local dir = dest:match("^(.*)/[^/]+$")
      os.execute("mkdir -p '" .. dir .. "'")
      local ok = os.execute("git show 'origin/data/itemdb:" .. f .. "' > '" .. dest .. ".part' 2>/dev/null && mv '" .. dest .. ".part' '" .. dest .. "'")
      if (ok ~= 0 and ok ~= true) or not exists(dest) then
        os.remove(dest .. ".part")
        return false, "can't copy " .. f .. " from the data/itemdb branch (try: git fetch origin data/itemdb)"
      end
    end
  end
  return true
end

-- load the library and its tables in a sandbox: it needs LibStub, GetLocale and the game's Lua extras (strsplit...),
-- which come from `game` (the harness's globals)
function I.load(cache, game)
  game = game or {}
  local libs = {}
  local LibStub = setmetatable({
    NewLibrary = function(_, major) local l = libs[major] or {}; libs[major] = l; return l end,
    GetLibrary = function(_, major) return libs[major] end,
  }, { __call = function(_, major) return libs[major] end })
  local noop = function() end
  local dummy = setmetatable({}, { __index = function() return noop end })
  local env = setmetatable({ LibStub = LibStub, GetLocale = function() return "enUS" end, CreateFrame = function() return dummy end },
    { __index = function(_, k)
      local v = rawget(game, k)
      if v ~= nil and type(v) ~= "table" or (type(v) == "table" and (k == "string" or k == "table" or k == "math" or k == "bit")) then return v end
      return _G[k]
    end })
  env._G = env
  for _, f in ipairs(FILES) do
    local chunk, err = loadfile(cache .. "/" .. f)
    if not chunk then return false, err end
    setfenv(chunk, env)
    local ok, e = pcall(chunk)
    if not ok then return false, f .. ": " .. tostring(e) end
  end
  I.lib = libs["LibItemDB-1.0"]
  if not I.lib then return false, "LibItemDB didn't register" end
  return true
end

-- the item id in a number, "item:123:...", a link, or an item name
function I.id(x)
  if type(x) == "number" then return x end
  if type(x) ~= "string" then return nil end
  local n = tonumber(x) or tonumber(x:match("item:(%d+)"))
  if n then return n end
  return I.lib and I.lib:GetID(x)
end

local CLASS_NAME = { [0] = "Consumable", [1] = "Container", [2] = "Weapon", [3] = "Gem", [4] = "Armor", [5] = "Reagent",
  [6] = "Projectile", [7] = "Trade Goods", [9] = "Recipe", [11] = "Quiver", [12] = "Quest", [13] = "Key", [15] = "Miscellaneous" }
-- id -> { name, link, quality, ilvl, req, classID, subID, loc, sell, className } or nil
local memo = {}
function I.get(x)
  local id = I.id(x)
  if not id or not I.lib then return nil end
  local m = memo[id]
  if m ~= nil then return m or nil end
  local name, q, classID, subID, loc, ilvl, req = I.lib:GetInfo(id)
  if not name and not classID then memo[id] = false return nil end
  m = { id = id, name = name or ("Item " .. id), quality = tonumber(q) or 1, classID = tonumber(classID) or 15, subID = tonumber(subID) or 0,
    loc = (loc and loc ~= "" and loc ~= "INVTYPE_NON_EQUIP_IGNORE") and loc or "", ilvl = tonumber(ilvl) or 1, req = tonumber(req) or 0,
    sell = (I.lib.GetVendorSellPrice and I.lib:GetVendorSellPrice(id)) or 0 }
  m.className = CLASS_NAME[m.classID] or "Miscellaneous"
  m.link = I.lib:GetLink(id) or string.format("|cffffffff|Hitem:%d::::::::1:::::::|h[%s]|h|r", id, m.name)
  memo[id] = m
  return m
end

function I.stats(x)
  local id = I.id(x)
  if not id or not I.lib then return nil end
  local t = I.lib:GetStats(id)
  local c = {}
  for k, v in pairs(t or {}) do c[k] = v end
  return c
end

-- the tooltip's lines, as C_TooltipInfo gives them: what RG.ParseItemStats reads besides the stat table
local SLOT_TEXT = { INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder", INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest",
  INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_WRIST = "Wrist", INVTYPE_HAND = "Hands", INVTYPE_FINGER = "Finger",
  INVTYPE_TRINKET = "Trinket", INVTYPE_CLOAK = "Back", INVTYPE_WEAPON = "One-Hand", INVTYPE_2HWEAPON = "Two-Hand", INVTYPE_WEAPONMAINHAND = "Main Hand",
  INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_SHIELD = "Off Hand", INVTYPE_HOLDABLE = "Held In Off-hand", INVTYPE_RANGED = "Ranged",
  INVTYPE_RANGEDRIGHT = "Ranged", INVTYPE_THROWN = "Thrown", INVTYPE_RELIC = "Relic", INVTYPE_TABARD = "Tabard", INVTYPE_BODY = "Shirt" }
function I.tooltipLines(x)
  local it = I.get(x)
  if not it then return nil end
  local lines = { { leftText = it.name } }
  if it.classID == 2 or it.classID == 4 then lines[#lines + 1] = { leftText = "Binds when picked up" } end
  if it.classID == 12 then lines[#lines + 1] = { leftText = "Quest Item" } end
  if SLOT_TEXT[it.loc] then lines[#lines + 1] = { leftText = SLOT_TEXT[it.loc], rightText = "" } end
  local st = I.stats(it.id) or {}
  local speed = st.MELEE_WEAPON_SPEED or st.WEAPON_SPEED
  local dps = st.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
  if it.classID == 2 and dps then
    local sp = tonumber(speed) or 2.0
    local avg = dps * sp
    lines[#lines + 1] = { leftText = string.format("%d - %d Damage", math.floor(avg * 0.8), math.floor(avg * 1.2)), rightText = string.format("Speed %.2f", sp) }
    lines[#lines + 1] = { leftText = string.format("(%.1f damage per second)", dps) }
  end
  if st.RESISTANCE0_NAME then lines[#lines + 1] = { leftText = string.format("%d Armor", st.RESISTANCE0_NAME) } end
  if it.req and it.req > 1 then lines[#lines + 1] = { leftText = "Requires Level " .. it.req } end
  return lines
end

return I
