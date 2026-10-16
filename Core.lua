-- Waypath+ core: reads item stats, scores them for Ret, compares against what
-- you're wearing, and adds an upgrade line to every item tooltip.
local ADDON, RG = ...
_G.Waypath = RG
if RG.PruneQuests then RG.PruneQuests() end   -- drop quests this race or class can never take (Objectives.lua has loaded)
-- The version from the .toc (the release build fills it in; "dev" when run from a checkout)
do
  local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local ok, v = pcall(function() return meta and meta(ADDON, "Version") end)
  RG.VERSION = (ok and type(v) == "string" and not v:find("@")) and v or "dev"
end

-- Classic WoW text colors: quest-log gold, quest-complete green, error red, poor-quality grey
local GOLD = "|cff4fd1c5"   -- the accent (Graphite look: teal)
local GREEN, RED, GREY = "|cff40c040", "|cffff3333", "|cffa0a0a0"
-- Inter (SIL OFL) ships in Media/Fonts; fall back to the game's own fonts if it can't load.
RG.FONTS = { regular = "Interface\\AddOns\\Waypath\\Media\\Fonts\\Inter-Regular.ttf", medium = "Interface\\AddOns\\Waypath\\Media\\Fonts\\Inter-Medium.ttf", semibold = "Interface\\AddOns\\Waypath\\Media\\Fonts\\Inter-SemiBold.ttf" }
function RG.Font(fs, weight, size, flags)
  local ok = fs:SetFont(RG.FONTS[weight] or RG.FONTS.regular, size, flags or "")
  if not ok then fs:SetFont("Fonts\\ARIALN.TTF", size, flags or "") end
end
RG.ACCENT = { 0.31, 0.82, 0.77 }
-- Accent colours (Settings > Look, /wp theme). The accent table is changed in place, so everything that
-- reads it at draw time follows; text already coloured with a fixed code changes on /reload.
RG.ACCENT_ORDER = { "mint", "gold", "sky", "rose", "violet", "light" }
RG.ACCENTS = {
  mint = { "Mint", 0.31, 0.82, 0.77 }, gold = { "Gold", 0.96, 0.76, 0.25 }, sky = { "Sky", 0.38, 0.65, 0.98 },
  rose = { "Rose", 0.96, 0.45, 0.62 }, violet = { "Violet", 0.70, 0.55, 0.98 }, light = { "High contrast", 1, 1, 1 },
}
function RG.ApplyAccent(name)
  local a = RG.ACCENTS[name or "mint"] or RG.ACCENTS.mint
  RG.ACCENT[1], RG.ACCENT[2], RG.ACCENT[3] = a[2], a[3], a[4]
end
-- Localisation scaffolding: RG.L["English text"] returns the translation for the game's language,
-- or the English text itself. Add a language with RG.AddLocale("deDE", { ["English text"] = "Text" }) from a
-- Locales/<code>.lua file (see LOCALES.md). New code wraps player-facing strings in RG.L[...].
RG.L = setmetatable({}, { __index = function(_, k) return k end })
function RG.AddLocale(code, strings)
  if GetLocale and GetLocale() == code then for k, v in pairs(strings) do rawset(RG.L, k, v) end end
end
-- Inter for every piece of text: the game's built-in font objects (gold, ornate) mapped to the window's look.
local STYLE = {
  GameFontNormal         = { "semibold", 13, 0.31, 0.82, 0.77 },
  GameFontNormalLarge    = { "semibold", 17, 0.95, 0.95, 0.95 },
  GameFontNormalSmall    = { "medium", 12, 0.31, 0.82, 0.77 },
  GameFontHighlight      = { "regular", 13, 0.93, 0.93, 0.93 },
  GameFontHighlightSmall = { "regular", 12, 0.8, 0.8, 0.8 },
  GameFontDisableSmall   = { "regular", 11, 0.5, 0.5, 0.5 },
}
function RG.StyleText(fs, tpl)
  local st = STYLE[tpl]
  if not st then return fs end
  RG.Font(fs, st[1], st[2]); fs:SetTextColor(st[3], st[4], st[5]); fs:SetShadowColor(0, 0, 0, 0)
  return fs
end
function RG.NewText(parent, tpl)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  return RG.StyleText(fs, tpl)
end

RG.COLORS = { GOLD = GOLD, GREEN = GREEN, RED = RED, GREY = GREY }

function RG.Print(msg) DEFAULT_CHAT_FRAME:AddMessage(GOLD .. "Waypath+|r " .. tostring(msg)) end
-- Small confirmations (pins, arrow on/off) flash in the middle of the screen instead of filling chat.
function RG.Notify(msg)
  if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(tostring(msg), 1, 0.82, 0) else RG.Print(msg) end
end

-- ---------------------------------------------------------------------------
-- Saved settings
-- ---------------------------------------------------------------------------
-- Route entries that moved level: carry hand-ticked steps over to the new key.
local MOVED_STEPS = { ["Arathi Highlands|30"] = "Arathi Highlands|33" }
-- Coming from RetGear (the old name): take over its saved progress once. Its
-- saved data is only readable while the old RetGear folder is still installed,
-- so this runs on the first login with both, then turns RetGear off.
local function oldAddonLoaded()
  local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  return f and f("RetGear")
end
local function migrateFromRetGear()
  if not oldAddonLoaded() then return end
  if not WaypathDB and type(RetGearDB) == "table" then
    WaypathDB = RetGearDB
    WaypathDB.migratedFrom = "RetGear"
    RG.migrated = true
  end
  local disable = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
  if disable then pcall(disable, "RetGear") end
  RG.oldAddonOn = true
end
-- ---------------------------------------------------------------------------
-- Profiles: every character has its own profile (settings, route progress,
-- quests, flight paths, weights, professions plan, 2nd spec set...). A few
-- things are shared by the whole account: Auction House prices and alerts,
-- recipes read from profession windows, which character is your main and what
-- it has (for bank alts), the error log, and where windows sit on screen.
-- WaypathDB.chars[character] = "profile" (full guide) or "alt" (bank alt).
-- ---------------------------------------------------------------------------
local SHARED = {
  prices = true, tracked = true, alerts = true, lastFullScan = true, recipes = true,
  main = true, mainHave = true, mainLevel = true, mainBS = true, mailDone = true,
  errors = true, chars = true, profiles = true, profilesMigrated = true, migratedFrom = true, altGuide = true,
  trackerPos = true, trackerScale = true, trackerWidth = true, windowPos = true, arrowPos = true, arrowScale = true,
  speedBarPos = true, mmAngle = true, textSize = true, seenVersion = true,
}
RG.SHARED_KEYS = SHARED
local function charKey() return (UnitName("player") or "?") .. "-" .. ((GetRealmName and GetRealmName()) or "") end

local function setupProfiles(root)
  root.profiles = root.profiles or {}
  root.chars = root.chars or {}
  -- before profiles, everything belonged to your main (or to whoever logged in)
  if not root.profilesMigrated then
    local owner = root.main or charKey()
    local p = root.profiles[owner] or {}
    local move = {}
    for k in pairs(root) do if not SHARED[k] then move[#move + 1] = k end end
    for _, k in ipairs(move) do p[k] = root[k]; root[k] = nil end
    root.profiles[owner] = p
    if next(p) then root.chars[owner] = root.chars[owner] or "profile" end
    root.profilesMigrated = true
  end
  local key = charKey()
  root.profiles[key] = root.profiles[key] or {}
  local prof = root.profiles[key]
  RG.root, RG.profile = root, prof
  -- RG.db: one table for the rest of the add-on; shared keys go to the account
  return setmetatable({}, {
    __index = function(_, k) if SHARED[k] then return root[k] end return prof[k] end,
    __newindex = function(_, k, v) if SHARED[k] then root[k] = v else prof[k] = v end end,
  })
end

local function InitDB()
  pcall(migrateFromRetGear)
  if WaypathDB == nil then RG.freshInstall = true end
  WaypathDB = WaypathDB or {}
  local db = setupProfiles(WaypathDB)
  RG.db = db
  RG.ApplyAccent(db.accent)
  -- the DPS coach was removed: drop its saved fight history
  db.fights, db.spellAvg, db.coach, db.coachChat = nil, nil, nil, nil
  if db.stepsDone then
    for old, new in pairs(MOVED_STEPS) do
      for k, v in pairs(db.stepsDone) do
        local i = k:match("^" .. old:gsub("%p", "%%%0") .. "#(%d+)$")
        if i then db.stepsDone[new .. "#" .. i] = v; db.stepsDone[k] = nil end
      end
    end
  end
  -- stat weights and hit cap are kept per class (a mage's weights aren't a paladin's);
  -- the weights saved before this belonged to the paladin
  db.weightsByClass, db.hitCapByClass = db.weightsByClass or {}, db.hitCapByClass or {}
  if not db.weightsPerClass then
    if db.weights and next(db.weights) then db.weightsByClass.PALADIN = db.weights end
    if db.hitCap then db.hitCapByClass.PALADIN = db.hitCap end
    db.weightsPerClass = true
  end
  local cls = RG.PLAYER_CLASS or "PALADIN"
  db.weightsByClass[cls] = db.weightsByClass[cls] or {}
  db.weights = db.weightsByClass[cls]
  for k, v in pairs(RG.DEFAULT_WEIGHTS) do if db.weights[k] == nil then db.weights[k] = v end end
  if db.hitCapByClass[cls] == nil then db.hitCapByClass[cls] = RG.DEFAULT_HIT_CAP end
  db.hitCap = db.hitCapByClass[cls]
  if db.talentHit == nil then db.talentHit = 0 end
  if db.tooltip == nil then db.tooltip = true end
  if db.levelAlerts == nil then db.levelAlerts = true end
  db.prices = db.prices or {}     -- [itemID] = { price = copper, t = time(), n = listings }
  db.tracked = db.tracked or {}   -- [itemID] = true (extra items you asked to watch)
end
RG.InitDB = InitDB

-- ---------------------------------------------------------------------------
-- Full profile vs bank alt. Each character picks the first time it logs in
-- with Waypath+ (the very first character is a full profile). Your "main" is
-- the character bank alts buy and mail for.
-- ---------------------------------------------------------------------------
RG.PlayerKey = charKey
function RG.CharMode()
  local r = RG.root
  return r and r.chars and r.chars[charKey()] or nil
end
function RG.IsAlt() return RG.CharMode() == "alt" end
function RG.IsMain() return RG.db ~= nil and RG.db.main == charKey() end
function RG.SetCharMode(mode)
  if not RG.root then return end
  RG.root.chars[charKey()] = mode
  if mode == "profile" and not RG.root.main then RG.root.main = charKey() end
  if mode == "alt" and RG.root.main == charKey() then RG.root.main = nil end
end
-- Start this character over: a brand new, empty profile (settings back to defaults).
function RG.ResetProfile()
  if not RG.root then return end
  RG.root.profiles[charKey()] = {}
  ReloadUI()
end
-- The first-login question for a new character.
function RG.AskCharMode()
  if not (StaticPopupDialogs and StaticPopup_Show) then RG.SetCharMode("profile"); return end
  local main = RG.MainName()
  StaticPopupDialogs.WAYPATH_NEW_CHAR = {
    text = "|cffffd100Waypath+|r: first time on %s.\n\n|cffffd100New profile|r: the full leveling guide with this character's own settings, route progress and professions. Your other characters keep theirs.\n\n|cffffd100Bank alt|r: no leveling guide. A shopping list of quest items to buy and mail" .. (main and (" to " .. main) or " to your main") .. ", and the vendor and mailbox helpers.",
    button1 = "New profile", button2 = "Bank alt",
    OnAccept = function()
      RG.SetCharMode("profile")
      RG.Print("New profile for " .. (UnitName("player") or "this character") .. ".")
      if RG.ShowWelcome and not RG.db.setupDone then RG.ShowWelcome() end
    end,
    OnCancel = function(_, _, reason)
      if reason ~= "clicked" then return end   -- closed some other way: ask again next login
      RG.SetCharMode("alt")
      RG.db.setupDone, RG.db.welcomed = true, true
      ReloadUI()
    end,
    timeout = 0, whileDead = true, hideOnEscape = false, preferredIndex = 3,
  }
  StaticPopup_Show("WAYPATH_NEW_CHAR", UnitName("player") or "this character")
end
function RG.KnownChars()
  local out = {}
  for k, m in pairs((RG.root and RG.root.chars) or {}) do out[#out + 1] = { key = k, mode = m } end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end
-- Run fn once, `delay` seconds after the last call with this key (bursts of
-- bag and quest events collapse into one piece of work).
local debounced = {}
function RG.Debounce(key, delay, fn)
  if debounced[key] then debounced[key].fn = fn; return end
  debounced[key] = { fn = fn }
  C_Timer.After(delay, function() local d = debounced[key]; debounced[key] = nil; if d then d.fn() end end)
end

-- Auras are "secret" to addons during combat on this client: reading them then
-- throws a taint error. All aura reads go through here: in combat it returns
-- nil, true ("can't tell") without touching the API, and any other refusal is
-- caught the same way.
local isSecret = issecretvalue or function() return false end
RG.IsSecret = isSecret
-- Unit info (names, health, class) can also come back "secret" on this client,
-- e.g. for nameplates or in combat. These return nil instead of a hidden value.
function RG.Safe(v) if v == nil or isSecret(v) then return nil end return v end
function RG.SafeUnit(fn, unit)
  if not fn then return nil end
  local ok, a, b = pcall(fn, unit)
  if not ok then return nil end
  return RG.Safe(a), RG.Safe(b)
end
function RG.SafeName(unit) return (RG.SafeUnit(UnitName, unit)) end
-- Any unit query with any arguments: its first result, or nil if refused or hidden.
function RG.SafeCall(fn, ...)
  if not fn then return nil end
  local ok, a = pcall(fn, ...)
  if not ok then return nil end
  return RG.Safe(a)
end
function RG.AurasLocked() return (InCombatLockdown and InCombatLockdown()) and true or false end
function RG.FindAura(unit, filter, test)
  if RG.AurasLocked() then return nil, true end
  local ok, res = pcall(function()
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
      for i = 1, 40 do
        local a = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not a then return nil end
        if a.name and not isSecret(a.name) then
          local r = test(a)
          if r then return r end
        end
      end
    elseif UnitAura then
      for i = 1, 40 do
        local n, _, _, dispel, _, exp, src = UnitAura(unit, i, filter)
        if not n then return nil end
        local r = test({ name = n, dispelName = dispel, expirationTime = exp, sourceUnit = src })
        if r then return r end
      end
    end
  end)
  if ok then return res end
  return nil, true
end
-- A player buff by name: the aura table, or nil (second value true when it couldn't be read).
function RG.PlayerBuff(name)
  return RG.FindAura("player", "HELPFUL", function(a) return a.name == name and a end)
end

function RG.MainName()
  local m = RG.db and RG.db.main
  return m and m:match("^(.-)%-") or m
end

-- ---------------------------------------------------------------------------
-- Item info helpers (modern client API with fallbacks)
-- ---------------------------------------------------------------------------
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
local GetItemStats = (C_Item and C_Item.GetItemStats) or _G.GetItemStats

function RG.ItemInfo(item) return GetItemInfo(item) end
function RG.EquipLoc(item)
  local _, _, _, equipLoc = GetItemInfoInstant(item)
  return equipLoc
end
function RG.RequestItem(id)
  if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
end

-- ---------------------------------------------------------------------------
-- Stat extraction: the stat table plus vanilla-style "Equip:" lines
-- ---------------------------------------------------------------------------
local STAT_KEYS = {
  ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
  ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI",
  ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_MELEE_ATTACK_POWER_SHORT = "AP",
  ITEM_MOD_CRIT_RATING_SHORT = "CRIT_RATING", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT_RATING",
  ITEM_MOD_HIT_RATING_SHORT = "HIT_RATING", ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT_RATING",
  ITEM_MOD_HASTE_RATING_SHORT = "HASTE_RATING", ITEM_MOD_MASTERY_RATING_SHORT = "MASTERY_RATING",
  ITEM_MOD_VERSATILITY = "VERS_RATING", ITEM_MOD_SPELL_POWER_SHORT = "SP",
  ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP",
  ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL", ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
  ITEM_MOD_POWER_REGEN0_SHORT = "MP5", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
  ITEM_MOD_CRIT_SPELL_RATING_SHORT = "CRIT_RATING", ITEM_MOD_HIT_SPELL_RATING_SHORT = "HIT_RATING",
  -- tank stats (used by tank specs on the 2nd Spec tab)
  RESISTANCE0_NAME = "ARMOR", ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF", ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
  ITEM_MOD_PARRY_RATING_SHORT = "PARRY", ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK", ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVAL",
}
-- Spell schools in "Increases damage done by Shadow spells and effects by up to X."
local SCHOOL = { holy = "SP_HOLY", fire = "SP_FIRE", nature = "SP_NATURE", frost = "SP_FROST", shadow = "SP_SHADOW", arcane = "SP_ARCANE" }

-- Text patterns for "Equip:" effects that many Classic-era items use.
local LINE_PATTERNS = {
  { "improves your chance to get a critical strike by (%d+)%%", "CRIT" },
  { "improves your chance to hit by (%d+)%%", "HIT" },
  { "^equip: %+(%d+) attack power%.?$", "AP" },
  { "increases attack power by (%d+)", "AP" },
  { "increases damage and healing done by magical spells and effects by up to (%d+)", "SP" },
  { "increases ranged attack power by (%d+)", "RAP" },
  -- WoW Forever merges hit and crit: spell hit and crit count as hit and crit for everyone
  { "improves your chance to hit with spells by (%d+)%%", "HIT" },
  -- healing (used by healer specs on the 2nd Spec tab)
  { "increases damage and healing done by magical spells and effects by up to (%d+)", "HEAL" },
  { "increases healing done by spells and effects by up to (%d+)", "HEAL" },
  { "restores (%d+) mana per 5 sec", "MP5" },
  { "improves your chance to get a critical strike with spells by (%d+)%%", "SCRIT" },
  { "improves your chance to get a critical strike with spells by (%d+)%%", "CRIT" },
  -- tank stats
  { "increased defense %+(%d+)", "DEF" },
  { "increases your chance to dodge an attack by (%d+)%%", "DODGE" },
  { "increases your chance to parry an attack by (%d+)%%", "PARRY" },
  { "increases your chance to block attacks with a shield by (%d+)%%", "BLOCK" },
  { "increases the block value of your shield by (%d+)", "BLOCKVAL" },
}

local cache = {}
function RG.GetStats(link)
  if not link then return nil end
  if cache[link] then return cache[link] end
  local s = { STR = 0, AGI = 0, STA = 0, INT = 0, SPI = 0, AP = 0, RAP = 0, CRIT = 0, HIT = 0, SP = 0,
              SP_HOLY = 0, SP_FIRE = 0, SP_NATURE = 0, SP_FROST = 0, SP_SHADOW = 0, SP_ARCANE = 0,
              CRIT_RATING = 0, HIT_RATING = 0, HASTE_RATING = 0, MASTERY_RATING = 0, VERS_RATING = 0,
              DPS = 0, SPEED = 0, HEAL = 0, MP5 = 0, SCRIT = 0,
              ARMOR = 0, DEF = 0, DODGE = 0, PARRY = 0, BLOCK = 0, BLOCKVAL = 0 }
  local raw = GetItemStats and GetItemStats(link)
  if raw then
    for k, v in pairs(raw) do
      local key = STAT_KEYS[k]
      if key then s[key] = s[key] + v end
      if k == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then s.DPS = v end
    end
    -- modern "spell power" heals too
    if (raw.ITEM_MOD_SPELL_POWER_SHORT or 0) > 0 then s.HEAL = s.HEAL + raw.ITEM_MOD_SPELL_POWER_SHORT end
  end
  local fromTable = { AP = raw and (raw.ITEM_MOD_ATTACK_POWER_SHORT or 0) > 0, HEAL = s.HEAL > 0, MP5 = s.MP5 > 0,
    DEF = s.DEF > 0, DODGE = s.DODGE > 0, PARRY = s.PARRY > 0, BLOCK = s.BLOCK > 0, BLOCKVAL = s.BLOCKVAL > 0 }
  -- Tooltip text for Equip: lines and weapon speed.
  local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
  local equipSeen = {}
  if data and data.lines then
    for _, line in ipairs(data.lines) do
      local t = line.leftText and line.leftText:lower()
      if t then
        local r = line.rightText and line.rightText:lower()
        local sp = r and r:match("speed (%d+%.%d+)")
        if sp then s.SPEED = tonumber(sp) end
        local dps = t:match("^%(([%d%.]+) damage per second%)")
        if dps and s.DPS == 0 then s.DPS = tonumber(dps) end
        local armor = s.ARMOR == 0 and t:match("^(%d+) armor$")
        if armor then s.ARMOR = tonumber(armor) end
        local block = s.BLOCKVAL == 0 and t:match("^(%d+) block$")
        if block then s.BLOCKVAL = tonumber(block) end
        if t:find("^equip:") then
          local school, n = t:match("increases damage done by (%a+) spells and effects by up to (%d+)")
          if school and SCHOOL[school] and not equipSeen[t] then s[SCHOOL[school]] = s[SCHOOL[school]] + tonumber(n); equipSeen[t] = true end
          for _, p in ipairs(LINE_PATTERNS) do
            local n = t:match(p[1])
            -- Ignore situational bonuses like "when fighting Beasts", and don't
            -- count Attack Power twice when the stat table already has it.
            if n and not t:find("when fighting") and not equipSeen[t .. p[2]] and not fromTable[p[2]] then
              s[p[2]] = s[p[2]] + tonumber(n)
              equipSeen[t .. p[2]] = true
            end
          end
        end
      end
    end
  end
  -- Only remember the result once the item's data has actually loaded.
  if raw or (data and data.lines and #data.lines > 1) then cache[link] = s end
  return s
end

-- ---------------------------------------------------------------------------
-- Scoring
-- ---------------------------------------------------------------------------
local RANGED_LOC = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
-- How much of a weapon's damage counts, by the class's weapon model (Classes/<Class>.lua):
-- 2H = one big two-hander, DW = two one-handers, caster/feral = weapon damage doesn't count,
-- ranged = the ranged weapon is the big one (melee weapons only count a little).
local MULT_2H = { ["2H"] = 1, DW = 0.75, ranged = 1, caster = 0, feral = 1, tank = 0.6 }
local MULT_1H = { ["2H"] = 0.55, DW = 1, ranged = 0.55, caster = 0, feral = 0.55, tank = 1 }

-- Can this character wear or wield it? (armor type, weapon skill, shields, relics)
function RG.CanUse(link)
  local C = RG.ActiveClass
  if not (C and C.weapons) or not GetItemInfoInstant then return true end
  local _, _, _, loc, _, classID, subID = GetItemInfoInstant(link)
  if not classID then return true end
  if classID == 2 then
    if subID == 14 or subID == 20 then return true end   -- miscellaneous, fishing poles
    if not C._weaponSet then C._weaponSet = {}; for _, w in ipairs(C.weapons) do C._weaponSet[w] = true end end
    return C._weaponSet[subID] or false
  elseif classID == 4 then
    if subID == 0 or loc == "INVTYPE_CLOAK" then return true end
    if subID == 6 then return C.shield and true or false end
    if subID >= 7 and subID <= 9 then return C.relic == subID end
    local from = C.armor and C.armor[subID]
    return from ~= nil and (UnitLevel("player") or 1) >= from
  end
  return true
end

-- Score an item. hitRoom = how much hit % still counts before the cap (nil = all
-- of it); slot = the inventory slot it would go in (17 = off-hand).
-- w and model are optional: the 2nd Spec tab scores with its spec's weights and weapon model.
function RG.Score(link, hitRoom, slot, w, model)
  local s = RG.GetStats(link)
  if not s then return 0 end
  if not RG.CanUse(link) then return 0 end
  w = w or RG.db.weights
  local hit = s.HIT
  if hitRoom then hit = math.max(0, math.min(hit, hitRoom)) end
  local score = hit * (w.HIT or 0)
  for k, v in pairs(s) do
    if k ~= "HIT" and k ~= "DPS" and k ~= "SPEED" and v ~= 0 and w[k] then score = score + v * w[k] end
  end
  if s.DPS > 0 then
    local loc = RG.EquipLoc(link)
    model = model or RG.WEAPON_MODEL or "2H"
    if RANGED_LOC[loc] then
      score = score + s.DPS * (w.RANGED_DPS or 0)
    else
      local twoH = loc == "INVTYPE_2HWEAPON"
      local mult
      if twoH then mult = MULT_2H[model] or 1
      elseif slot == 17 or loc == "INVTYPE_WEAPONOFFHAND" then mult = model == "DW" and 0.5 or 0
      else mult = MULT_1H[model] or 1 end
      score = score + s.DPS * (w.WEAPON_DPS or 0) * mult
      if twoH and model == "2H" and s.SPEED > 3.0 then score = score + (s.SPEED - 3.0) * 10 * (w.SLOW_BONUS or 0) end
      if model == "DW" and not twoH and slot ~= 17 and s.SPEED > 2.6 then score = score + (s.SPEED - 2.6) * 10 * (w.SLOW_BONUS or 0) end
    end
  end
  return score
end

-- Total hit % from equipped gear plus talents.
function RG.CurrentHit()
  local total = RG.db.talentHit or 0
  for slot = 1, 18 do
    local link = GetInventoryItemLink("player", slot)
    if link then total = total + (RG.GetStats(link).HIT or 0) end
  end
  return total
end

-- Compare an item with what you'd replace. Returns delta, replacedSlot, newScore, oldScore.
-- While you hold a fishing pole (or nothing) your real weapon is in your bags:
-- upgrades are measured against the last weapon you wore, as long as you still have it.
local function isPole(l)
  if not l then return false end
  local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
  if not info then return false end
  local _, _, _, _, _, classID, subID = info(l)
  return classID == 2 and subID == 20
end
RG.IsFishingPole = isPole
local function rememberWeapons()
  if not RG.db then return end
  local mh = GetInventoryItemLink("player", 16)
  if mh and not isPole(mh) then
    RG.db.lastWeapons = { [16] = mh, [17] = GetInventoryItemLink("player", 17) }
  end
end
RG.RememberWeapons = rememberWeapons
local function wornLink(slot)
  local l = GetInventoryItemLink("player", slot)
  if slot ~= 16 and slot ~= 17 then return l end
  local mh = GetInventoryItemLink("player", 16)
  if mh and not isPole(mh) then return l end
  local lw = RG.db and RG.db.lastWeapons
  local keep = lw and lw[slot]
  if keep and GetItemCount and (GetItemCount(keep) or 0) > 0 then return keep end
  if slot == 16 and isPole(mh) then return RG.BestBagWeapon and RG.BestBagWeapon() or nil end
  return l
end
-- The best main-hand weapon in your bags (used while a fishing pole is in your hands
-- and no weapon was remembered yet). Cached until your bags change.
local bagBest, bagDirty = nil, true
function RG.BestBagWeapon()
  if not bagDirty then return bagBest end
  bagDirty, bagBest = false, nil
  local C = C_Container
  local numSlots = (C and C.GetContainerNumSlots) or GetContainerNumSlots
  local itemLink = (C and C.GetContainerItemLink) or GetContainerItemLink
  if not (numSlots and itemLink) then return nil end
  local best, bestScore
  for bag = 0, 4 do
    for slot = 1, (numSlots(bag) or 0) do
      local l = itemLink(bag, slot)
      local loc = l and RG.EquipLoc(l)
      if loc and (loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONMAINHAND") and not isPole(l) and (not RG.CanUse or RG.CanUse(l)) then
        local sc = RG.Score(l, nil, 16) or 0
        if not bestScore or sc > bestScore then best, bestScore = l, sc end
      end
    end
  end
  bagBest = best
  return best
end
do
  local bf = CreateFrame("Frame")
  pcall(bf.RegisterEvent, bf, "BAG_UPDATE_DELAYED")
  bf:SetScript("OnEvent", function() bagDirty = true end)
end
RG.WornLink = wornLink
do
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "PLAYER_EQUIPMENT_CHANGED"); pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function() pcall(rememberWeapons) end)
end

function RG.Compare(link)
  local loc = RG.EquipLoc(link)
  local slots = loc and RG.EQUIP_SLOTS[loc]
  if not slots then return nil end
  if not RG.CanUse(link) then return nil end   -- wrong armor type or weapon skill
  local cap = RG.db.hitCap
  local curHit = RG.CurrentHit()
  local best
  for _, slot in ipairs(slots) do
    local old = wornLink(slot)
    local oldScore, oldHit = 0, 0
    if old then oldHit = RG.GetStats(old).HIT; oldScore = RG.Score(old, nil, slot) end
    -- Two-hander replaces main hand and off hand together.
    if loc == "INVTYPE_2HWEAPON" then
      local off = wornLink(17)
      if off then oldScore = oldScore + RG.Score(off, nil, 17); oldHit = oldHit + RG.GetStats(off).HIT end
    end
    local hitWithout = curHit - oldHit
    local newScore = RG.Score(link, math.max(0, cap - hitWithout), slot)
    -- Count the old item's hit only up to the cap too.
    if old and oldHit > 0 then
      local capped = math.max(0, math.min(oldHit, cap - hitWithout))
      oldScore = oldScore - (oldHit - capped) * (RG.db.weights.HIT or 0)
    end
    local delta = newScore - oldScore
    if not best or delta > best.delta then best = { delta = delta, slot = slot, new = newScore, old = oldScore } end
  end
  return best.delta, best.slot, best.new, best.old
end

function RG.FormatDelta(d)
  if not d then return "" end
  if d > 0.5 then return GREEN .. string.format("+%.0f", d) .. "|r"
  elseif d < -0.5 then return RED .. string.format("%.0f", d) .. "|r" end
  return GREY .. "±0|r"
end

-- ---------------------------------------------------------------------------
-- Tooltip line
-- ---------------------------------------------------------------------------
local function OnTooltip(tooltip)
  if not RG.db or not RG.Opt("tooltip") or not tooltip.GetItem then return end
  local _, link = tooltip:GetItem()
  if not link then return end
  local loc = RG.EquipLoc(link)
  if not loc or not RG.EQUIP_SLOTS[loc] then return end
  local score = RG.Score(link)
  local delta = RG.Compare(link)
  local icon = RG.LOGO_INLINE
  local right
  if delta and delta > 0.5 then right = GREEN .. string.format("+%.0f upgrade", delta) .. "|r"
  elseif delta and delta < -0.5 then right = RED .. string.format("%.0f", delta) .. "|r" .. GREY .. " vs worn|r"
  elseif delta then right = GREY .. "same as worn|r" end
  tooltip:AddLine(" ")
  if right then tooltip:AddDoubleLine(icon .. GOLD .. RG.SCORE_NAME .. "|r  " .. string.format("%.0f", score), right)
  else tooltip:AddLine(icon .. GOLD .. RG.SCORE_NAME .. "|r  " .. string.format("%.0f", score)) end
  local id = tonumber(link:match("item:(%d+)"))
  if id then
    local guide = RG.GuideByID and RG.GuideByID[id]
    if guide then tooltip:AddLine(GREY .. "Leveling pick: " .. guide.src .. ", " .. guide.zone .. "|r", 1, 1, 1, true) end
    local price = RG.PriceText and RG.PriceText(id)
    if price then tooltip:AddLine(GREY .. "Auction House: |r" .. price) end
  end
  tooltip:Show()
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)
else
  GameTooltip:HookScript("OnTooltipSetItem", OnTooltip)
  if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltip) end
end

-- ---------------------------------------------------------------------------
-- Guide lookups
-- ---------------------------------------------------------------------------
RG.GuideByID = {}
for _, g in ipairs(RG.GUIDE) do if g.id then RG.GuideByID[g.id] = g end end

-- Is this guide item an upgrade for you right now? Returns delta or nil if
-- the item data hasn't loaded yet.
function RG.GuideDelta(g)
  local _, link = GetItemInfo(g.id)
  if not link then RG.RequestItem(g.id); return nil end
  return (RG.Compare(link))
end

-- The best upgrades for you that drop in a dungeon (from your class's gear guide).
-- routeZone can be a combined route name ("Stratholme, Scholomance, ..., LBRS/UBRS").
function RG.DungeonDrops(routeZone, max)
  local out = {}
  for _, g in ipairs(RG.GUIDE or {}) do
    if g.id and g.how == "Dungeon" and g.zone and g.zone ~= "" and not RG.OwnState(g.id) then
      local here = routeZone:find(g.zone, 1, true) or g.zone:find(routeZone, 1, true)
        or (g.zone:find("Blackrock Spire", 1, true) and routeZone:find("BRS", 1, true))
      if here then
        local d = RG.GuideDelta(g)
        if d and d > 0.5 then out[#out + 1] = { g = g, d = d } end
      end
    end
  end
  table.sort(out, function(a, b) return a.d > b.d end)
  for i = #out, (max or 3) + 1, -1 do out[i] = nil end
  return out
end

function RG.OwnState(id)
  for slot = 1, 18 do
    local l = GetInventoryItemLink("player", slot)
    if l and tonumber(l:match("item:(%d+)")) == id then return "equipped" end
  end
  local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, true) or (GetItemCount and GetItemCount(id, true)) or 0
  if count and count > 0 then return "owned" end
  return nil
end

-- ---------------------------------------------------------------------------
-- Professions: returns { Mining = {rank, max}, Blacksmithing = {rank, max} }
-- ---------------------------------------------------------------------------
function RG.Professions()
  local out = {}
  if GetProfessions and GetProfessionInfo then
    local p = { GetProfessions() }
    for i = 1, 6 do
      if p[i] then
        local name, _, rank, max = GetProfessionInfo(p[i])
        if name then out[name] = { rank = rank or 0, max = max or 0 } end
      end
    end
  elseif GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
      if name and not header then out[name] = { rank = rank or 0, max = max or 0 } end
    end
  end
  return out
end
-- Do we know a flight path whose name contains this text? nil = never seen a flight master yet.
function RG.KnowsFP(part)
  if not RG.db.fps or not next(RG.db.fps) then return nil end
  part = part:lower()
  for name in pairs(RG.db.fps) do if name:lower():find(part, 1, true) then return true end end
  return false
end
function RG.Skill(name) local p = RG.Professions()[name]; return p and p.rank or nil end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("TAXIMAP_OPENED")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    InitDB()
  elseif event == "PLAYER_LOGIN" then
    -- a character Waypath+ hasn't seen: the first one gets a full profile, any
    -- later one is asked: its own new profile, or a bank alt
    if not RG.CharMode() then
      local others = 0
      for k in pairs(RG.root.chars) do if k ~= RG.PlayerKey() then others = others + 1 end end
      if others == 0 then RG.SetCharMode("profile")
      else C_Timer.After(2.5, function() if RG.AskCharMode then RG.AskCharMode() end end) end
    end
    -- quest, zone and profession names are matched in English: say so once on other clients
    local loc = GetLocale and GetLocale()
    if loc and loc ~= "enUS" and loc ~= "enGB" and RG.root and not RG.root.localeWarned then
      RG.root.localeWarned = true
      C_Timer.After(9, function()
        RG.Print("Waypath+ is made for English game clients. On this client (" .. loc .. ") route steps, quest names, professions and fishing may not be recognized. Everything else still works.")
      end)
    end
    -- after an update: what's new (once per version)
    C_Timer.After(7, function()
      local N = RG.NEWS
      if not (N and N.version == RG.VERSION and RG.root) then return end
      local seen = RG.root.seenVersion
      if seen == RG.VERSION then return end
      RG.root.seenVersion = RG.VERSION
      if RG.freshInstall then return end
      -- the versions since the one you last saw (at most three of them)
      local lines = {}
      for i, sec in ipairs(N.sections or {}) do
        if sec.v == seen or i > 3 then break end
        for _, l in ipairs(sec.lines) do if not l:find("^%s") then lines[#lines + 1] = l end end
      end
      if #lines == 0 then return end
      RG.Print("Updated to " .. GOLD .. RG.VERSION .. "|r. What's new:")
      for i = 1, math.min(4, #lines) do
        local short = lines[i]:match("^(.-[%.:])%s") or lines[i]
        if #short > 140 then short = short:sub(1, 137) .. "..." end
        DEFAULT_CHAT_FRAME:AddMessage("   " .. GOLD .. "•|r " .. short)
      end
      DEFAULT_CHAT_FRAME:AddMessage("   " .. GREY .. "/wp news for everything|r")
    end)
    if RG.oldAddonOn and StaticPopupDialogs and StaticPopup_Show then
      StaticPopupDialogs.WAYPATH_REPLACED = {
        text = "RetGear is now |cffffd100Waypath+|r." .. (RG.migrated and "\n\nYour progress, settings and ticked steps came across." or "") .. "\n\nReload to switch the old RetGear off. You can then delete the RetGear folder from Interface\\AddOns.",
        button1 = RELOADUI or "Reload", button2 = LATER or "Later",
        OnAccept = function() ReloadUI() end, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
      }
      C_Timer.After(2, function() StaticPopup_Show("WAYPATH_REPLACED") end)
    end
    -- ask the server for guide items a few at a time (the guide has ~170 items)
    local ids = {}
    for _, g in ipairs(RG.GUIDE) do if g.id then ids[#ids + 1] = g.id end end
    for i = 1, #ids, 20 do
      C_Timer.After((i - 1) / 20 * 0.5, function() for j = i, math.min(i + 19, #ids) do RG.RequestItem(ids[j]) end end)
    end
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    -- your main: the first character past level 10 that logs in with the add-on
    if not RG.db.main and not RG.IsAlt() and ((UnitLevel("player") or 1) >= 10 or class == "PALADIN") then RG.db.main = RG.PlayerKey() end
    if RG.IsAlt() then
      RG.Print("Bank alt mode: buying and mailing for " .. GOLD .. (RG.MainName() or "your main") .. "|r. /wp mail shows the shopping list. (/wp main makes this character your main.)")
      return
    end
    local cname = UnitClass("player") or "your class"
    if not RG.ClassSupported then RG.Print("Loaded. " .. cname .. " isn't set up yet: the route, quests, arrow, travel and professions all work, and item scores use a general melee guide for now.")
    elseif RG.PLAYER_FACTION == "Alliance" and not (RG.db and RG.db.allianceBetaSeen) then
      if RG.db then RG.db.allianceBetaSeen = true end
      RG.Print("Loaded. Alliance routes are new: quest steps come from WoW Forever's quest data, the zone order and travel tips are hand-written. Professions and some gear sources are still being matched to Alliance towns, so tell me (/wp report) if a step looks wrong.")
    elseif not RG.RaceSupported then RG.Print("Loaded. Your starting zone isn't in the route yet: it picks up from level 12, which is the same for every race on your side.") end
  elseif RG.IsAlt() then
    return
  elseif event == "PLAYER_LEVEL_UP" then
    if not RG.db.levelAlerts then return end
    local lvl = arg1
    local found = {}
    for _, g in ipairs(RG.GUIDE) do
      if g.id and (g.lvl == lvl or (g.lvl < lvl and g.lvl >= lvl - 1)) then
        local d = RG.GuideDelta(g)
        if d and d > 0.5 and not RG.OwnState(g.id) then
          local _, link = GetItemInfo(g.id)
          found[#found + 1] = (link or ("item " .. g.id)) .. " " .. RG.FormatDelta(d) .. GREY .. " (" .. g.src .. ", " .. g.zone .. ")|r"
        end
      end
    end
    local go = {}
    for _, r in ipairs(RG.ROUTE or {}) do if r.from == lvl then go[#go + 1] = r.zone .. (r.kind == "dungeon" and " (dungeon)" or "") end end
    if #go > 0 then RG.Print("Level " .. lvl .. ": time for " .. table.concat(go, ", ") .. ". /wp for the route.") end
    for _, t in ipairs(RG.TRAVEL or {}) do
      if t.lvl == lvl and not (t.fp and RG.KnowsFP(t.fp)) then RG.Print("Travel: " .. t.text) end
    end
    for name, dq in pairs(RG.DUNGEON_QUESTS or {}) do
      if dq.prep == lvl then
        local where = {}
        for _, q in ipairs(dq.quests) do where[#where + 1] = q[1] .. GREY .. " (" .. q[3] .. ")|r" end
        RG.Print("Start collecting " .. GOLD .. name .. "|r quests now (head over at " .. dq.go .. "):")
        for _, w in ipairs(where) do DEFAULT_CHAT_FRAME:AddMessage("   " .. w) end
      elseif dq.go == lvl then
        RG.Print("You're ready for " .. GOLD .. name .. "|r. Grab a group!")
      end
    end
    if #found > 0 then
      RG.Print("Level " .. lvl .. "! New upgrades in reach:")
      for _, s in ipairs(found) do DEFAULT_CHAT_FRAME:AddMessage("   " .. s) end
    end
  elseif event == "TAXIMAP_OPENED" then
    -- Remember every flight path this character knows.
    RG.db.fps = RG.db.fps or {}
    local nodes
    if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
      local mapID = (GetTaxiMapID and GetTaxiMapID()) or (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
      nodes = mapID and C_TaxiMap.GetAllTaxiNodes(mapID)
    end
    if nodes then
      for _, n in ipairs(nodes) do
        if n.name and n.state ~= (Enum.FlightPathState and Enum.FlightPathState.Unreachable or 2) then RG.db.fps[n.name] = true end
      end
    elseif NumTaxiNodes and TaxiNodeName then
      for i = 1, NumTaxiNodes() do
        local t = TaxiNodeGetType and TaxiNodeGetType(i)
        if t ~= "NONE" then RG.db.fps[TaxiNodeName(i)] = true end
      end
    end
    if RG.RefreshUI then RG.RefreshUI() end
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    if RG.RefreshUI then RG.RefreshUI() end
  end
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
SLASH_WAYPATH1, SLASH_WAYPATH2, SLASH_WAYPATH3, SLASH_WAYPATH4 = "/waypath", "/wp", "/rg", "/retgear"
SlashCmdList.WAYPATH = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = msg:match("^(%S+)%s*(.*)$")
  cmd = cmd and cmd:lower() or ""
  if cmd == "" then
    if RG.ToggleUI then RG.ToggleUI() end
  elseif cmd == "arrow3d" then
    RG.db.arrow3d = (rest ~= "off"); RG.Print("3D arrow " .. (RG.db.arrow3d and "on" or "off"))
  elseif cmd == "trail" then
    if rest == "reset" then RG.TrailReset(); RG.Print("Learned paths cleared.")
    elseif rest == "off" or rest == "on" then RG.db.trail = (rest == "on"); RG.Print("Learned paths " .. rest .. ".")
    else RG.Print("Learned paths: " .. (RG.TrailSize and RG.TrailSize() or 0) .. " points remembered. /wp trail off | on | reset") end
  elseif cmd == "smart" then
    if RG.SmartToggle then RG.SmartToggle(rest == "on" or (rest ~= "off" and (RG.db.smart == false or RG.db.routeStyle == "guided"))) end
  elseif cmd == "weight" then
    local stat, val = rest:match("^(%S+)%s+([%d%.]+)$")
    stat = stat and stat:upper()
    if stat and RG.db.weights[stat] ~= nil then
      RG.db.weights[stat] = tonumber(val); wipe(cache)
      RG.Print(RG.STAT_LABELS[stat] .. " weight set to " .. val)
      if RG.RefreshUI then RG.RefreshUI() end
    else
      RG.Print("Weights (AP = 1):")
      for k, v in pairs(RG.db.weights) do DEFAULT_CHAT_FRAME:AddMessage(string.format("   %s%s|r %s = %s", GOLD, k, RG.STAT_LABELS[k] or "", v)) end
      RG.Print("Change one with /wp weight STR 2.5")
    end
  elseif cmd == "reset" then
    RG.db.weightsByClass[RG.PLAYER_CLASS or "PALADIN"] = {}; InitDB(); wipe(cache); RG.Print("Weights reset to the defaults.")
  elseif cmd == "hitcap" and tonumber(rest) then
    RG.db.hitCap = tonumber(rest); RG.db.hitCapByClass[RG.PLAYER_CLASS or "PALADIN"] = RG.db.hitCap; RG.Print("Hit cap set to " .. rest .. "%.")
  elseif cmd == "talenthit" and tonumber(rest) then
    RG.db.talentHit = tonumber(rest); RG.Print("Hit from talents set to " .. rest .. "%.")
  elseif cmd == "tooltip" then
    RG.db.tooltip = not RG.Opt("tooltip"); RG.Print("Tooltip scores " .. (RG.db.tooltip and "on." or "off."))
  elseif cmd == "track" then
    local id = tonumber(rest:match("item:(%d+)") or rest)
    if id then RG.db.tracked[id] = true; RG.Print("Tracking Auction House prices for item " .. (select(2, GetItemInfo(id)) or id) .. ".") end
  elseif cmd == "untrack" then
    local id = tonumber(rest:match("item:(%d+)") or rest)
    if id then RG.db.tracked[id] = nil; RG.Print("Stopped tracking item " .. id .. ".") end
  elseif cmd == "scan" then
    if RG.ScanAH then RG.ScanAH(true) end
  else
    RG.Print("Commands (type /wp on its own to open the guide):")
    for _, line in ipairs({
      "|cffffd100Guide|r  /wp  ·  /wp setup  ·  /wp settings  ·  /wp tracker",
      "|cffffd100Questing|r  /wp next  ·  /wp undo  ·  /wp way 45 60  ·  /wp auto  ·  /wp pace  ·  /wp session",
      "|cffffd100Tabs|r  /wp group  ·  /wp heal  ·  /wp fish  ·  /wp camp  ·  /wp gold  ·  /wp mail  ·  /wp fp",
      "|cffffd100Group|r  /wp lfg Scarlet Monastery",
      "|cffffd100Auction House|r  /wp scan  ·  /wp autoscan  ·  /wp track [item]  ·  /wp untrack [item]  ·  /wp alert [item] 25",
      "|cffffd100Bags|r  /wp sort  ·  /wp sort bank",
      "|cffffd100Selling|r  /wp profit  ·  /wp profit min 25  ·  /wp profit ignore [item]",
      "|cffffd100" .. RG.SCORE_NAME .. "|r  /wp weight STR 2.5  ·  /wp hitcap 9  ·  /wp talenthit 3  ·  /wp reset  ·  /wp tooltip",
      "|cffffd100Characters|r  /wp main",
    }) do DEFAULT_CHAT_FRAME:AddMessage("   " .. line) end
  end
end

-- Addon compartment (the addons button by the minimap)
function Waypath_OnAddonCompartmentClick() if RG.ToggleUI then RG.ToggleUI() end end
function Waypath_OnAddonCompartmentEnter(_, frame)
  GameTooltip:SetOwner(frame or UIParent, "ANCHOR_LEFT")
  GameTooltip:SetText("Waypath+"); GameTooltip:AddLine("Click to open the guide.", 1, 1, 1)
  GameTooltip:Show()
end
function Waypath_OnAddonCompartmentLeave() GameTooltip:Hide() end
