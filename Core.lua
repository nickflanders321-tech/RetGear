-- Waypath+ core: reads item stats, scores them for Ret, compares against what
-- you're wearing, and adds an upgrade line to every item tooltip.
local ADDON, RG = ...
_G.Waypath = RG
-- /wp perf's breakdown: RG.PerfWrap("name", fn) returns fn itself that, only while /wp perf is measuring, adds up the milliseconds
-- it took and the kilobytes it allocated (garbage the game has to collect, which is what feels like micro-stutter).
-- Wrap the callback of every recurring timer and per-frame handler with it.
RG.Perf = RG.Perf or { on = false, ms = {}, kb = {}, n = {}, q = {} }
function RG.PerfWrap(name, fn)
  local P = RG.Perf
  local stop, mem = debugprofilestop, collectgarbage
  local function fin(t0, k0, ...)
    local ms, k1 = stop() - t0, mem("count")
    P.ms[name] = (P.ms[name] or 0) + ms; P.n[name] = (P.n[name] or 0) + 1
    if k1 > k0 then P.kb[name] = (P.kb[name] or 0) + (k1 - k0) end
    return ...
  end
  return function(...)
    if not P.on or not stop then return fn(...) end
    return fin(stop(), mem("count"), fn(...))
  end
end
if RG.PruneQuests then RG.PruneQuests() end   -- drop quests this race or class can never take (Objectives.lua has loaded)
-- The version from the .toc (the release build fills it in; "dev" when run from a checkout)
do
  local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local ok, v = pcall(function() return meta and meta(ADDON, "Version") end)
  RG.VERSION = (ok and type(v) == "string" and not v:find("@")) and v or "dev"
end

-- Classic WoW text colors: quest-log gold, quest-complete green, error red, poor-quality grey
local GOLD = "|cffd8b56a"   -- the accent (Cartographer look: brass)
local GREEN, RED, GREY = "|cff40c040", "|cffff3333", "|cffa0a0a0"
-- Inter (SIL OFL) ships in Media/Fonts; fall back to the game's own fonts if it can't load.
RG.FONTS = { regular = "Interface\\AddOns\\Waypath\\Media\\Fonts\\Inter-Regular.ttf", medium = "Interface\\AddOns\\Waypath\\Media\\Fonts\\Inter-Medium.ttf", semibold = "Interface\\AddOns\\Waypath\\Media\\Fonts\\Inter-SemiBold.ttf",
  -- Fraunces (SIL OFL): the serif for titles and numbers
  display = "Interface\\AddOns\\Waypath\\Media\\Fonts\\Fraunces-SemiBold.ttf", black = "Interface\\AddOns\\Waypath\\Media\\Fonts\\Fraunces-Black.ttf" }
function RG.Font(fs, weight, size, flags)
  local ok = fs:SetFont(RG.FONTS[weight] or RG.FONTS.regular, size, flags or "")
  if not ok then fs:SetFont("Fonts\\ARIALN.TTF", size, flags or "") end
end
RG.ACCENT = { 0.847, 0.71, 0.416 }
-- Accent colours (Settings > Look, /wp theme). The accent table is changed in place, so everything that
-- reads it at draw time follows; text already coloured with a fixed code changes on /reload.
RG.ACCENT_ORDER = { "brass", "mint", "gold", "sky", "rose", "violet", "light" }
RG.ACCENTS = {
  brass = { "Brass", 0.847, 0.71, 0.416 }, mint = { "Mint", 0.31, 0.82, 0.77 }, gold = { "Gold", 0.96, 0.76, 0.25 }, sky = { "Sky", 0.38, 0.65, 0.98 },
  rose = { "Rose", 0.96, 0.45, 0.62 }, violet = { "Violet", 0.70, 0.55, 0.98 }, light = { "High contrast", 1, 1, 1 },
}
function RG.ApplyAccent(name)
  local a = RG.ACCENTS[name or "brass"] or RG.ACCENTS.brass
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
  GameFontNormal         = { "semibold", 13, 0.847, 0.71, 0.416 },
  GameFontNormalLarge    = { "display", 17, 0.937, 0.902, 0.824 },
  GameFontNormalSmall    = { "medium", 12, 0.847, 0.71, 0.416 },
  GameFontHighlight      = { "regular", 13, 0.937, 0.902, 0.824 },
  GameFontHighlightSmall = { "regular", 12, 0.82, 0.78, 0.7 },
  GameFontDisableSmall   = { "regular", 11, 0.6, 0.57, 0.5 },
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
local MOVED_STEPS = { ["Arathi Highlands|30"] = "Arathi Highlands|33", ["Mount Hyjal|58"] = "Mount Hyjal|57" }
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
  prices = true, tracked = true, alerts = true, lastFullScan = true, recipes = true, ahGear = true,
  main = true, mainHave = true, mainLevel = true, mainBS = true, mailDone = true,
  errors = true, chars = true, profiles = true, profilesMigrated = true, migratedFrom = true, altGuide = true,
  trackerPos = true, trackerScale = true, trackerWidth = true, trackerMaxH = true, windowPos = true, arrowPos = true, arrowScale = true,
  speedBarPos = true, mmAngle = true, textSize = true, seenVersion = true, matStock = true,
  drops = true,   -- drop rates you counted yourself (DropRecord.lua)
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
  if RG.ApplySimBuild then RG.ApplySimBuild() end
  if RG.ApplyMainSpec then RG.ApplyMainSpec(true) end
  if RG.SyncDefaultWeights then RG.SyncDefaultWeights() end
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
-- "Cards only" mode (see Mode.lua): the guide and helpers are off for this character
function RG.CardsOnly() return RG.db ~= nil and RG.db.cardsOnly == true end
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
    button1 = "New profile", button2 = "Bank alt", button3 = "Cards only",
    OnAlt = function()
      RG.SetCharMode("profile")
      RG.db.welcomed, RG.db.setupDone = true, true
      RG.SetCardsOnly(true)
      RG.Print("Cards only: the guide and helpers are off for " .. (UnitName("player") or "this character") .. ". /wp cardsonly off brings them back.")
    end,
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
-- how many you carry (bank too with bank = true); this client has the count under C_Item only
function RG.ItemCount(item, bank)
  local f = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
  if not (f and item) then return 0 end
  local ok, n = pcall(f, item, bank and true or false)
  return (ok and type(n) == "number") and n or 0
end
-- an item's icon, known right away (no need for its info to have loaded)
function RG.ItemIcon(item)
  if not item then return nil end
  if C_Item and C_Item.GetItemIconByID then local ok, ic = pcall(C_Item.GetItemIconByID, item); if ok and ic then return ic end end
  if _G.GetItemIcon then local ok, ic = pcall(_G.GetItemIcon, item); if ok and ic then return ic end end
  local _, _, _, _, ic = GetItemInfoInstant(item)
  return ic
end
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
-- One rule keeps this from counting anything twice: the game often gives the same stat in both places (the stat table
-- says "Spell Power 8" and the tooltip says "Equip: Increases damage and healing done by magical spells and effects by
-- up to 8"; a hit rating of 10 shows as "Improves your chance to hit by 1%"). So each stat is read from the table and
-- from the text separately, and the larger of the two counts, never the sum. tools/audit/stats.py runs every
-- weapon and armor piece in the game through this in each form the game could present it.
--
-- WoW Forever stores hit, crit, haste, dodge, parry and block as ratings (wowsims/forever's mechanics, from the game
-- files): 10 per 1% hit, 14 per 1% crit, 10 per 1% haste, 12 per 1% dodge, 15 per 1% parry, 5 per 1% block. Waypath+
-- weighs those per 1%, so a rating is divided down. Defense is per point; expertise stays a rating (its weight is per
-- rating point, from the same simulator).
local STAT_KEYS = {}
do
  local function add(names, key, div, also)
    for _, n in ipairs(names) do
      STAT_KEYS[n] = { key, div or 1, also }; STAT_KEYS[n .. "_SHORT"] = { key, div or 1, also }
    end
  end
  add({ "ITEM_MOD_STRENGTH" }, "STR"); add({ "ITEM_MOD_AGILITY" }, "AGI"); add({ "ITEM_MOD_STAMINA" }, "STA")
  add({ "ITEM_MOD_INTELLECT" }, "INT"); add({ "ITEM_MOD_SPIRIT" }, "SPI")
  add({ "ITEM_MOD_ATTACK_POWER", "ITEM_MOD_MELEE_ATTACK_POWER" }, "AP")
  add({ "ITEM_MOD_RANGED_ATTACK_POWER" }, "RAP")
  add({ "ITEM_MOD_FERAL_ATTACK_POWER" }, "FAP")
  add({ "ITEM_MOD_CRIT_RATING", "ITEM_MOD_CRIT_MELEE_RATING", "ITEM_MOD_CRIT_SPELL_RATING", "ITEM_MOD_CRIT_RANGED_RATING" }, "CRIT", 14)
  add({ "ITEM_MOD_HIT_RATING", "ITEM_MOD_HIT_MELEE_RATING", "ITEM_MOD_HIT_SPELL_RATING", "ITEM_MOD_HIT_RANGED_RATING" }, "HIT", 10)
  add({ "ITEM_MOD_HASTE_RATING", "ITEM_MOD_HASTE_MELEE_RATING", "ITEM_MOD_HASTE_SPELL_RATING" }, "HASTE", 10)
  add({ "ITEM_MOD_HASTE_RANGED_RATING" }, "RHASTE", 10)
  add({ "ITEM_MOD_EXPERTISE_RATING" }, "EXPERTISE")
  add({ "ITEM_MOD_DEFENSE_SKILL_RATING" }, "DEF")
  add({ "ITEM_MOD_DODGE_RATING" }, "DODGE", 12)
  add({ "ITEM_MOD_PARRY_RATING" }, "PARRY", 15)
  add({ "ITEM_MOD_BLOCK_RATING" }, "BLOCK", 5)
  add({ "ITEM_MOD_BLOCK_VALUE" }, "BLOCKVAL")
  -- spell power is damage and healing; the older split stats are one each
  add({ "ITEM_MOD_SPELL_POWER" }, "SP", 1, "HEAL")
  add({ "ITEM_MOD_SPELL_DAMAGE_DONE" }, "SP")
  add({ "ITEM_MOD_SPELL_HEALING_DONE" }, "HEAL")
  add({ "ITEM_MOD_MANA_REGENERATION", "ITEM_MOD_POWER_REGEN0" }, "MP5")
  STAT_KEYS.RESISTANCE0_NAME = { "ARMOR", 1 }
end
RG.STAT_KEYS = STAT_KEYS
-- Spell schools in "Increases damage done by Shadow spells and effects by up to X."
local SCHOOL = { holy = "SP_HOLY", fire = "SP_FIRE", nature = "SP_NATURE", frost = "SP_FROST", shadow = "SP_SHADOW", arcane = "SP_ARCANE" }

-- "Equip:" text: { pattern (lower case, one number), stat, divisor }. The number may have decimals ("by 1.5%").
local N = "([%d]+%.?%d*)"
local LINE_PATTERNS = {
  -- percents (the Classic wording)
  -- (WoW Forever words them "with melee attacks", "with Melee and Ranged attacks", "with ranged weapons", "with
  -- spells", with a decimal: "by 1.0%". Forever merges melee, ranged and spell crit and hit into one stat each.
  -- "the critical strike chance of your Flash of Light" is one spell's, which no weight measures: not matched.)
  { "chance to get a critical strike[^%d]- by " .. N .. "%%", "CRIT" },
  { "chance to hit[^%d]- by " .. N .. "%%", "HIT" },
  { "increases your chance to dodge an attack by " .. N .. "%%", "DODGE" },
  { "increases your chance to parry an attack by " .. N .. "%%", "PARRY" },
  { "increases your chance to block attacks with a shield by " .. N .. "%%", "BLOCK" },
  { "increases your ranged attack speed by " .. N .. "%%", "RHASTE" },
  { "increases ranged attack speed by " .. N .. "%%", "RHASTE" },
  { "increases your attack and casting speed by " .. N .. "%%", "HASTE" },
  { "increases your attack speed by " .. N .. "%%", "HASTE" },
  { "increases attack speed by " .. N .. "%%", "HASTE" },
  { "increases your haste by " .. N .. "%%", "HASTE" },
  { "increases your expertise by " .. N .. "%%", "EXPERTISE", 0.1 },   -- 1% = 10 rating
  -- ratings (the later wording, should WoW Forever's tooltips use it)
  { "critical strike rating by " .. N, "CRIT", 14 }, { "%+" .. N .. " critical strike rating", "CRIT", 14 }, { "%+" .. N .. " crit rating", "CRIT", 14 },
  { "hit rating by " .. N, "HIT", 10 }, { "%+" .. N .. " hit rating", "HIT", 10 },
  { "haste rating by " .. N, "HASTE", 10 }, { "%+" .. N .. " haste rating", "HASTE", 10 },
  { "dodge rating by " .. N, "DODGE", 12 }, { "%+" .. N .. " dodge rating", "DODGE", 12 },
  { "parry rating by " .. N, "PARRY", 15 }, { "%+" .. N .. " parry rating", "PARRY", 15 },
  { "block rating by " .. N, "BLOCK", 5 }, { "%+" .. N .. " block rating", "BLOCK", 5 },
  { "expertise rating by " .. N, "EXPERTISE" }, { "%+" .. N .. " expertise", "EXPERTISE" }, { "increases your expertise by " .. N .. "%.?$", "EXPERTISE" },
  { "defense rating by " .. N, "DEF" }, { "%+" .. N .. " defense rating", "DEF" },
  -- flat stats
  { "increased defense %+" .. N, "DEF" }, { "increases defense by " .. N, "DEF" },
  { "^equip: %+" .. N .. " attack power%.?$", "AP" },
  { "increases attack power by " .. N, "AP" },
  { "increases ranged attack power by " .. N, "RAP" }, { "^equip: %+" .. N .. " ranged attack power%.?$", "RAP" },
  { "increases damage and healing done by magical spells and effects by up to " .. N, "SP" },
  { "increases damage and healing done by magical spells and effects by up to " .. N, "HEAL" },
  { "increases spell power by " .. N, "SP" }, { "increases spell power by " .. N, "HEAL" },
  { "increases damage done by magical spells and effects by up to " .. N, "SP" },
  { "increases healing done by spells and effects by up to " .. N, "HEAL" },
  { "increases healing done by up to " .. N, "HEAL" },
  { "and damage done by up to " .. N .. " for all magical spells", "SP" },
  { "restores " .. N .. " mana per 5 sec%.?$", "MP5" },   -- (not "... to your Imp", "... in Haunted areas")
  { "increases the block value of your shield by " .. N, "BLOCKVAL" },
}
RG.LINE_PATTERNS = LINE_PATTERNS
-- conditional bonuses no weight measures: only against some creatures, only in some forms, a chance on hit, a use
local CONDITIONAL = { "when fighting", " against ", "forms only", "chance on hit", "chance on melee", "chance when hit",
  " to your ", " areas", "while ", " for your pet" }

local function blank()
  return { STR = 0, AGI = 0, STA = 0, INT = 0, SPI = 0, AP = 0, RAP = 0, CRIT = 0, HIT = 0, SP = 0,
           SP_HOLY = 0, SP_FIRE = 0, SP_NATURE = 0, SP_FROST = 0, SP_SHADOW = 0, SP_ARCANE = 0,
           DPS = 0, SPEED = 0, HEAL = 0, MP5 = 0, SCRIT = 0,
           ARMOR = 0, DEF = 0, DODGE = 0, PARRY = 0, BLOCK = 0, BLOCKVAL = 0,
           HASTE = 0, RHASTE = 0, EXPERTISE = 0, FAP = 0 }
end

-- raw: GetItemStats' table (or nil); lines: the tooltip's { leftText, rightText } lines (or nil). Pure: the audit
-- (tools/audit/stats.py) calls it directly.
function RG.ParseItemStats(raw, lines)
  local s, tab, txt = blank(), {}, {}
  if raw then
    for k, v in pairs(raw) do
      local m = STAT_KEYS[k]
      if m and type(v) == "number" then
        tab[m[1]] = (tab[m[1]] or 0) + v / m[2]
        if m[3] then tab[m[3]] = (tab[m[3]] or 0) + v / m[2] end
      end
      if (k == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" or k == "ITEM_MOD_DAMAGE_PER_SECOND") and type(v) == "number" then s.DPS = v end
    end
  end
  -- in the text too, each stat counts once, at its largest: the game can show one stat in two wordings (its stat line
  -- and its spell's line), and one line can match more than one pattern
  local seenLine = {}
  local function put(key, v) if v > (txt[key] or 0) then txt[key] = v end end
  for _, line in ipairs(lines or {}) do
    local t = type(line.leftText) == "string" and line.leftText:lower()
    if t then t = t:gsub("%s+$", "") end
    if t and not seenLine[t] then
      seenLine[t] = true
      local r = type(line.rightText) == "string" and line.rightText:lower()
      local sp = r and r:match("speed (%d+%.%d+)")
      if sp then s.SPEED = tonumber(sp) end
      local dps = t:match("^%(([%d%.]+) damage per second%)")
      if dps and s.DPS == 0 then s.DPS = tonumber(dps) end
      local armor = t:match("^(%d+) armor$")
      if armor then put("ARMOR", tonumber(armor)) end
      local block = t:match("^(%d+) block$")
      if block then put("BLOCKVAL", tonumber(block)) end
      if t:find("^equip:") then
        -- feral attack power ("... in Cat, Bear, Dire Bear and Moonkin forms only") counts only in those forms
        if t:find("forms only") then
          local fap = t:match("attack power by " .. N) or t:match("%+" .. N .. " attack power")
          if fap then put("FAP", tonumber(fap)) end
        end
        local cond = false
        for _, c in ipairs(CONDITIONAL) do if t:find(c, 1, true) then cond = true end end
        if not cond then
          local school, n = t:match("increases damage done by (%a+) spells and effects by up to " .. N)
          if school and SCHOOL[school] then put(SCHOOL[school], tonumber(n)) end
          for _, p in ipairs(LINE_PATTERNS) do
            local n = t:match(p[1])
            if n and tonumber(n) then put(p[2], tonumber(n) / (p[3] or 1)) end
          end
        end
      end
    end
  end
  -- table and text: the larger of the two, never the sum (a stat only in the table counts as it is, a penalty too)
  for k in pairs(s) do
    local a, b = tab[k], txt[k]
    if a and b then s[k] = math.max(a, b) elseif a then s[k] = a elseif b then s[k] = b end
  end
  return s
end

local cache = {}
function RG.ClearScoreCache() wipe(cache) end
function RG.GetStats(link)
  if not link then return nil end
  if cache[link] then return cache[link] end
  local raw = GetItemStats and GetItemStats(link)
  local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
  local s = RG.ParseItemStats(raw, data and data.lines)
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

-- When the default weights change (a new wowsims/forever update), every saved weight still at the old default moves to
-- the new one; a weight you set yourself (/wp weight) stays yours.
function RG.SyncDefaultWeights()
  local db = RG.db
  if not (db and db.weights and RG.DEFAULT_WEIGHTS) then return end
  local cls = RG.PLAYER_CLASS or "PALADIN"
  local m = RG.MainSpec and RG.MainSpec()
  local key = m and m.key or "main"
  db.weightsBase = db.weightsBase or {}
  local id = cls .. ":" .. key
  local base = db.weightsBase[id]
  local hand = RG.HAND_WEIGHTS and RG.HAND_WEIGHTS[cls] and RG.HAND_WEIGHTS[cls][key]
  local changed = false
  local nb = {}
  for k, v in pairs(RG.DEFAULT_WEIGHTS) do
    local was
    if base then was = base[k] elseif hand then was = hand[k] end
    local cur = db.weights[k]
    if cur == nil or (was ~= nil and math.abs(cur - was) < 1e-6 and cur ~= v) then db.weights[k] = v; changed = true end
    nb[k] = v
  end
  db.weightsBase[id] = nb
  if changed and RG.ClearScoreCache then RG.ClearScoreCache() end
end

-- Level scaling. The weights are level-60 values (wowsims/forever simulates level 60): there 1% crit is worth about
-- 2.4% of everything your Attack Power and weapon add up to. Lower down that total is much smaller (less Attack Power,
-- a slower, weaker weapon), so 1% crit, hit, haste, dodge... is worth fewer points of Strength or Attack Power. Those
-- weights scale with a typical character's Attack Power plus 14 x weapon DPS at your level (about 20 x level + 80),
-- reaching the full value at 60. Flat stats (Strength, Attack Power, spell damage, Stamina) and weapon DPS don't scale:
-- they are what the percents are measured against. tools/gear/gen.py uses the same formula for the gear lists.
RG.LEVEL_SCALED = { CRIT = true, HIT = true, HASTE = true, RHASTE = true, EXPERTISE = true, SCRIT = true,
  DODGE = true, PARRY = true, BLOCK = true, DEF = true }
function RG.LevelFactor(lvl)
  lvl = lvl or (UnitLevel and UnitLevel("player")) or 60
  if type(lvl) ~= "number" or lvl <= 0 then lvl = 60 end
  return math.max(0.15, math.min(1, (lvl + 4) / 64))
end
-- the weight that counts right now: level-scaled for the percent stats
-- Agility and Intellect: for a damage spec (weights per Attack Power or Ranged AP) most of their worth is the crit they
-- give (in WoW Forever Intellect gives a Ret Paladin or Enhancement Shaman about as much crit as Agility does), so that
-- part scales with your level like crit itself. The part that is Attack Power stays: Agility gives a Rogue 1 AP, a Cat
-- 1 AP, a Hunter 2 ranged AP. tools/gear/gen.py's score() does the same.
RG.AGI_AP = { ROGUE = { AP = 1 }, DRUID = { AP = 1 }, HUNTER = { RAP = 2 } }
local function critPart(w, k, v, f, cls)
  if not (w.AP == 1 or w.RAP == 1) then return v end      -- casters, healers and tanks: as they are
  local flat = 0
  if k == "AGI" then for stat, per in pairs(RG.AGI_AP[cls or ""] or {}) do flat = flat + per * (w[stat] or 0) end end
  flat = math.min(v, flat)
  return flat + (v - flat) * f
end
function RG.EffWeight(w, k, f, cls)
  local v = w[k]
  if not v then return nil end
  f = f or RG.LevelFactor()
  if RG.LEVEL_SCALED[k] then v = v * f
  elseif (k == "AGI" or k == "INT") and v > 0 then v = critPart(w, k, v, f, cls or RG.PLAYER_CLASS) end
  return v
end

-- parts (optional): filled with each stat's share of the score, for the tooltip's breakdown
-- Ret builds (Gear tab): wowsims/forever weighs Ret gear for two builds, Unsealed Wrath (the default) and Holy Shock.
-- Switching puts the chosen build's weights into the class's and the Ret spec's tables; your untouched saved weights
-- follow (RG.SyncDefaultWeights), ones you set yourself stay.
RG.RET_BUILDS = { { key = "unsealed", label = "Unsealed Wrath", sim = "ret" }, { key = "holyshock", label = "Holy Shock", sim = "ret_holyshock" } }
function RG.RetBuild() return (RG.db and RG.db.retBuild) or "unsealed" end
function RG.ApplySimBuild()
  if RG.PLAYER_CLASS ~= "PALADIN" then return end
  local sims = RG.SIM_WEIGHTS and RG.SIM_WEIGHTS.PALADIN
  local hand = RG.HAND_WEIGHTS and RG.HAND_WEIGHTS.PALADIN and RG.HAND_WEIGHTS.PALADIN.ret
  if not (sims and sims.ret and hand) then return end
  local pick = sims.ret
  for _, b in ipairs(RG.RET_BUILDS) do if b.key == RG.RetBuild() and sims[b.sim] then pick = sims[b.sim] end end
  local targets = { RG.CLASSES and RG.CLASSES.PALADIN and RG.CLASSES.PALADIN.weights }
  for _, s in ipairs((RG.SPECS or {}).PALADIN or {}) do if s.key == "ret" and s.weights then targets[#targets + 1] = s.weights end end
  for _, t in pairs(targets) do
    for _, b in ipairs(RG.RET_BUILDS) do for k in pairs(sims[b.sim] or {}) do t[k] = hand[k] end end
    for k, v in pairs(pick) do t[k] = v end
  end
end
function RG.SetRetBuild(key)
  if not RG.db then return end
  RG.db.retBuild = key
  RG.ApplySimBuild()
  if RG.ApplyMainSpec then RG.ApplyMainSpec(true) end
  RG.SyncDefaultWeights()
  if RG.ClearScoreCache then RG.ClearScoreCache() end
  if RG.CompareReset then RG.CompareReset() end
  if RG.UpdateBagArrows then pcall(RG.UpdateBagArrows) end
  if RG.RefreshUI then RG.RefreshUI() end
end

-- The score of a stat table (RG.GetStats) for an item that goes in equip slot loc. Pure: the audit
-- (tools/audit/stats.py) checks it against tools/gear/gen.py's score() for every item, class, spec and level.
-- f: level factor (default: yours); parts (optional): filled with each stat's share, for the tooltip's breakdown
function RG.ScoreStats(s, loc, slot, w, model, f, parts, ilvl, cls)
  f = f or RG.LevelFactor()
  local score = 0
  for k, v in pairs(s) do
    if k ~= "DPS" and k ~= "SPEED" and v ~= 0 and w[k] then
      local c = v * RG.EffWeight(w, k, f, cls)
      score = score + c
      if parts then parts[k] = (parts[k] or 0) + c end
    end
  end
  if s.DPS > 0 then
    model = model or "2H"
    local wd, sp = 0, 0
    if RANGED_LOC[loc] then
      wd = s.DPS * (w.RANGED_DPS or 0)
    else
      local twoH = loc == "INVTYPE_2HWEAPON"
      local mult
      if twoH then mult = MULT_2H[model] or 1
      elseif slot == 17 or loc == "INVTYPE_WEAPONOFFHAND" then mult = model == "DW" and 0.5 or 0
      else mult = MULT_1H[model] or 1 end
      wd = s.DPS * (w.WEAPON_DPS or 0) * mult
      if twoH and model == "2H" and s.SPEED > 3.0 then sp = (s.SPEED - 3.0) * 10 * (w.SLOW_BONUS or 0) end
      if model == "DW" and not twoH and slot ~= 17 and s.SPEED > 2.6 then sp = (s.SPEED - 2.6) * 10 * (w.SLOW_BONUS or 0) end
    end
    score = score + wd + sp
    if parts then parts.WEAPON = (parts.WEAPON or 0) + wd; if sp ~= 0 then parts.SPEED = (parts.SPEED or 0) + sp end end
  end
  -- a libram, idol or totem changes one of your spells, which no stat weight measures: rank it by item level
  -- (the gear generator does the same, so the lists and this agree)
  if score <= 0 and loc == "INVTYPE_RELIC" and type(ilvl) == "number" then
    score = ilvl * 0.5
    if parts then parts.RELIC = (parts.RELIC or 0) + score end
  end
  return score
end

-- Score an item for you. hitRoom = how much hit % still counts before the cap (nil = all of it); slot = the inventory
-- slot it would go in (17 = off-hand); parts (optional): filled with each stat's share, for the tooltip's breakdown.
-- w and model are optional: the 2nd Spec tab scores with its spec's weights and weapon model.
function RG.Score(link, hitRoom, slot, w, model, parts)
  local s = RG.GetStats(link)
  if not s then return 0 end
  if not RG.CanUse(link) then return 0 end
  w = w or RG.db.weights
  if hitRoom and s.HIT > 0 then
    local c = {}; for k, v in pairs(s) do c[k] = v end
    c.HIT = math.max(0, math.min(s.HIT, hitRoom)); s = c
  end
  local loc = RG.EquipLoc(link)
  local ilvl = loc == "INVTYPE_RELIC" and select(4, GetItemInfo(link)) or nil
  return RG.ScoreStats(s, loc, slot, w, model or RG.WEAPON_MODEL or "2H", nil, parts, ilvl)
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
  if keep and RG.ItemCount(keep) > 0 then return keep end
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

-- onlySlot: compare against that one slot (the gear lists use it to suggest a different ring or trinket for each slot)
-- parts (optional): filled with the stat-by-stat difference for the slot the answer picks (the tooltip's breakdown)
local function compareRaw(link, onlySlot, parts)
  local loc = RG.EquipLoc(link)
  local slots = loc and RG.EQUIP_SLOTS[loc]
  if not slots then return nil end
  if onlySlot then
    local fits = false
    for _, s in ipairs(slots) do if s == onlySlot then fits = true end end
    if not fits then return nil end
    slots = { onlySlot }
  end
  if not RG.CanUse(link) then return nil end   -- wrong armor type or weapon skill
  local cap = RG.db.hitCap
  local curHit = RG.CurrentHit()
  local best
  local hitW = RG.EffWeight(RG.db.weights, "HIT") or 0
  for _, slot in ipairs(slots) do
    local pn, po = parts and {} or nil, parts and {} or nil
    local old = wornLink(slot)
    -- the weapon remembered while your hand is empty (wornLink) is this very item: compare it against nothing,
    -- not against itself (a shield had taken a two-hander off, and the two-hander then looked like no upgrade)
    if old and old == link and not GetInventoryItemLink("player", slot) then old = nil end
    local oldScore, oldHit = 0, 0
    if old then oldHit = RG.GetStats(old).HIT; oldScore = RG.Score(old, nil, slot, nil, nil, po) end
    -- Two-hander replaces main hand and off hand together.
    if loc == "INVTYPE_2HWEAPON" then
      local off = wornLink(17)
      if off then oldScore = oldScore + RG.Score(off, nil, 17, nil, nil, po); oldHit = oldHit + RG.GetStats(off).HIT end
    end
    -- Anything in the off hand takes a two-hander off: it replaces that too.
    if slot == 17 then
      local main = wornLink(16)
      if main and main ~= link and RG.EquipLoc(main) == "INVTYPE_2HWEAPON" then
        oldScore = oldScore + RG.Score(main, nil, 16, nil, nil, po); oldHit = oldHit + RG.GetStats(main).HIT
      end
    end
    local hitWithout = curHit - oldHit
    local newScore = RG.Score(link, math.max(0, cap - hitWithout), slot, nil, nil, pn)
    -- Count the old item's hit only up to the cap too.
    if old and oldHit > 0 then
      local capped = math.max(0, math.min(oldHit, cap - hitWithout))
      oldScore = oldScore - (oldHit - capped) * hitW
      if po then po.HIT = (po.HIT or 0) - (oldHit - capped) * hitW end
    end
    local delta = newScore - oldScore
    if not best or delta > best.delta then best = { delta = delta, slot = slot, new = newScore, old = oldScore, pn = pn, po = po } end
  end
  if parts and best then
    for k, v in pairs(best.pn) do parts[k] = (parts[k] or 0) + v end
    for k, v in pairs(best.po) do parts[k] = (parts[k] or 0) - v end
  end
  return best.delta, best.slot, best.new, best.old
end
-- Remembered until your gear, level or talents change (or 30 seconds pass): the gear lists, the Character panel,
-- tooltips and bag arrows ask about the same items over and over, and each answer costs a tooltip read the first time.
local cmpMemo, cmpT = {}, 0
function RG.CompareReset() cmpMemo = {} end
function RG.Compare(link, onlySlot)
  if type(link) ~= "string" then return compareRaw(link, onlySlot) end
  local now = GetTime and GetTime() or 0
  if now - cmpT > 30 then cmpMemo = {}; cmpT = now end
  local key = onlySlot and (link .. "#" .. onlySlot) or link
  local m = cmpMemo[key]
  if m == nil then
    local d, s, n, o = compareRaw(link, onlySlot)
    m = d and { d, s, n, o } or false
    cmpMemo[key] = m
  end
  if not m then return nil end
  return m[1], m[2], m[3], m[4]
end
do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "SKILL_LINES_CHANGED" }) do pcall(f.RegisterEvent, f, e) end
  f:SetScript("OnEvent", function() cmpMemo = {} end)
end

-- "+38 Crit · +12 Strength · -20 Weapon damage": where an upgrade (or a downgrade) comes from, biggest first
local PART_NAME = { STR = "Strength", AGI = "Agility", STA = "Stamina", INT = "Intellect", SPI = "Spirit", AP = "Attack Power",
  RAP = "Ranged AP", FAP = "Feral AP", CRIT = "Crit", SCRIT = "Spell crit", HIT = "Hit", HASTE = "Haste", RHASTE = "Ranged haste",
  EXPERTISE = "Expertise", SP = "Spell power", SP_HOLY = "Holy damage", SP_FIRE = "Fire damage", SP_NATURE = "Nature damage",
  SP_FROST = "Frost damage", SP_SHADOW = "Shadow damage", SP_ARCANE = "Arcane damage", HEAL = "Healing", MP5 = "Mana regen",
  ARMOR = "Armor", DEF = "Defense", DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block", BLOCKVAL = "Block value",
  WEAPON = "Weapon damage", SPEED = "Weapon speed", RELIC = "Item level" }
function RG.ScoreBreakdown(link)
  local parts = {}
  local ok, d = pcall(compareRaw, link, nil, parts)
  if not ok or not d then return nil end
  local list = {}
  for k, v in pairs(parts) do if math.abs(v) >= 0.5 then list[#list + 1] = { k = k, v = v } end end
  if #list == 0 then return nil end
  table.sort(list, function(a, b) return math.abs(a.v) > math.abs(b.v) end)
  local out = {}
  for i = 1, math.min(4, #list) do
    local e = list[i]
    out[#out + 1] = (e.v > 0 and GREEN .. string.format("+%.0f", e.v) or RED .. string.format("%.0f", e.v)) .. "|r " .. GREY .. (PART_NAME[e.k] or e.k) .. "|r"
  end
  return table.concat(out, GREY .. "  ·  |r")
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
-- Is the item in this tooltip bound to you (Soulbound, Binds when picked up, a quest item, account bound)? It says so
-- in one of its first lines. Such an item can't go on the Auction House, so it gets no AH price.
local BOUND_LINES = {}
for _, k in ipairs({ "ITEM_SOULBOUND", "ITEM_BIND_ON_PICKUP", "ITEM_BIND_QUEST", "ITEM_ACCOUNTBOUND", "ITEM_BNETACCOUNTBOUND", "ITEM_BIND_TO_ACCOUNT", "ITEM_BIND_TO_BNETACCOUNT", "ITEM_ACCOUNTBOUND_UNTIL_EQUIP" }) do
  if type(_G[k]) == "string" then BOUND_LINES[_G[k]] = true end
end
BOUND_LINES["Soulbound"], BOUND_LINES["Binds when picked up"], BOUND_LINES["Quest Item"] = true, true, true
function RG.TooltipBound(tooltip, data)
  for _, ln in ipairs(data and data.lines or {}) do
    local t = ln.leftText
    if type(t) == "string" and not (RG.IsSecret and RG.IsSecret(t)) and BOUND_LINES[t] then return true end
  end
  local name = tooltip and tooltip.GetName and tooltip:GetName()
  if name then
    for i = 2, math.min(8, (tooltip.NumLines and tooltip:NumLines()) or 0) do
      local fs = _G[name .. "TextLeft" .. i]
      local ok, t = pcall(function() return fs and fs:GetText() end)
      if ok and type(t) == "string" and not (RG.IsSecret and RG.IsSecret(t)) and BOUND_LINES[t] then return true end
    end
  end
  return false
end

local function OnTooltip(tooltip, data)
  if not RG.db or RG.CardsOnly() or not RG.Opt("tooltip") or not tooltip.GetItem then return end
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
  local why = delta and math.abs(delta) > 0.5 and RG.ScoreBreakdown and RG.ScoreBreakdown(link)
  if why then tooltip:AddLine(why, 1, 1, 1, true) end
  local id = tonumber(link:match("item:(%d+)"))
  if id then
    local guide = RG.GuideByID and RG.GuideByID[id]
    if guide then tooltip:AddLine(GREY .. "Leveling pick: " .. guide.src .. ", " .. guide.zone .. "|r", 1, 1, 1, true) end
    local price = RG.PriceText and not RG.TooltipBound(tooltip, data) and RG.PriceText(id, link)
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
-- (g.link: a piece seen in your bags, on the Auction House or made by a recipe you know, with its own random enchant)
function RG.GuideDelta(g, onlySlot)
  local link = g.link
  if not link then
    local _, l = GetItemInfo(g.id)
    if not l then RG.RequestItem(g.id); return nil end
    link = l
  elseif not GetItemInfo(link) then RG.RequestItem(g.id); return nil end
  return RG.Compare(link, onlySlot)   -- delta, slot, new score, old score
end

-- The best upgrades for you that drop in a dungeon (from your class's gear guide).
-- routeZone can be a combined route name ("Stratholme, Scholomance, ..., LBRS/UBRS").
function RG.DungeonDrops(routeZone, max)
  local out = {}
  for _, g in ipairs(RG.GUIDE or {}) do
    if g.id and (g.how == "Dungeon" or g.how == "Chest") and g.zone and g.zone ~= "" and not RG.OwnState(g.id) then
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

local wornIds, wornAt = {}, nil   -- the item ids you're wearing, read once a frame (and again when gear changes)
do
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "PLAYER_EQUIPMENT_CHANGED"); pcall(f.RegisterEvent, f, "UNIT_INVENTORY_CHANGED")
  f:SetScript("OnEvent", function() wornAt = nil end)
end
function RG.OwnState(id)
  local now = GetTime and GetTime()
  if now ~= wornAt then
    wornAt = now
    for k in pairs(wornIds) do wornIds[k] = nil end
    for slot = 1, 18 do
      local l = GetInventoryItemLink("player", slot)
      local i = l and tonumber(l:match("item:(%d+)"))
      if i then wornIds[i] = true end
    end
  end
  if wornIds[id] then return "equipped" end
  local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, true) or (GetItemCount and GetItemCount(id, true)) or 0
  if count and count > 0 then return "owned" end
  return nil
end

-- ---------------------------------------------------------------------------
-- Professions: returns { Mining = {rank, max}, Blacksmithing = {rank, max} }
-- ---------------------------------------------------------------------------
-- Professions by their English name, whatever language the game client is in (the route data is in English).
-- The game's skill line numbers are the same everywhere; on clients without them, the profession spells' names
-- (which the game translates) tell us which is which.
local SKILL_LINE = { [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering", [182] = "Herbalism",
  [165] = "Leatherworking", [186] = "Mining", [393] = "Skinning", [197] = "Tailoring", [185] = "Cooking", [129] = "First Aid", [356] = "Fishing" }
local PROF_SPELL = { Alchemy = 2259, Blacksmithing = 2018, Enchanting = 7411, Engineering = 4036, Leatherworking = 2108, Mining = 2575,
  Skinning = 8613, Tailoring = 3908, Cooking = 2550, ["First Aid"] = 3273, Fishing = 7620 }
-- (Herbalism's spell is "Herb Gathering", so its skill name is listed per language)
local HERB = { ["Herbalism"] = true, ["Kräuterkunde"] = true, ["Herboristerie"] = true, ["Herboristería"] = true, ["Herborismo"] = true,
  ["Erbalismo"] = true, ["Травничество"] = true, ["약초 채집"] = true, ["草药学"] = true, ["草藥學"] = true }
local localToEnglish
function RG.EnglishProf(name)
  if not name or name == "" then return name end
  if RG.PROFESSIONS and RG.PROFESSIONS[name] then return name end
  if HERB[name] then return "Herbalism" end
  if not localToEnglish then
    localToEnglish = {}
    local gsi = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    for en, sid in pairs(PROF_SPELL) do
      local ok, loc = pcall(gsi, sid)
      if ok and type(loc) == "string" and loc ~= "" then localToEnglish[loc] = en end
    end
  end
  return localToEnglish[name] or name
end
function RG.Professions()
  local out = {}
  if GetProfessions and GetProfessionInfo then
    local p = { GetProfessions() }
    for i = 1, 6 do
      if p[i] then
        local name, _, rank, max, _, _, line = GetProfessionInfo(p[i])
        name = (line and SKILL_LINE[line]) or RG.EnglishProf(name)
        if name then out[name] = { rank = rank or 0, max = max or 0 } end
      end
    end
  elseif GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
      if name and not header then out[RG.EnglishProf(name)] = { rank = rank or 0, max = max or 0 } end
    end
  end
  return out
end

-- The zone you're in, by its English name (the route's), whatever language the client is in: from the game's map
-- number, which is the same everywhere. Falls back to the game's own (translated) name for places we don't list.
local INSTANCE_EN = { [389] = "Ragefire Chasm", [43] = "Wailing Caverns", [36] = "The Deadmines", [33] = "Shadowfang Keep", [34] = "The Stockade",
  [48] = "Blackfathom Deeps", [90] = "Gnomeregan", [47] = "Razorfen Kraul", [189] = "Scarlet Monastery", [129] = "Razorfen Downs",
  [70] = "Uldaman", [209] = "Zul'Farrak", [349] = "Maraudon", [109] = "The Temple of Atal'Hakkar", [230] = "Blackrock Depths",
  [229] = "Blackrock Spire", [329] = "Stratholme", [289] = "Scholomance", [429] = "Dire Maul" }
local CITY_EN = { [1454] = "Orgrimmar", [1456] = "Thunder Bluff", [1458] = "Undercity", [1453] = "Stormwind City", [1455] = "Ironforge", [1457] = "Darnassus" }
local mapToZone
local zoneT, zoneV
function RG.ZoneName()
  local now = GetTime and GetTime() or 0
  if zoneV and zoneT == now then return zoneV end
  local loc = (GetRealZoneText and GetRealZoneText()) or ""
  if loc == "" and GetZoneText then loc = GetZoneText() or "" end
  local res = loc
  local inInst = IsInInstance and IsInInstance()
  if inInst and GetInstanceInfo then
    local ok, _, _, _, _, _, _, _, iid = pcall(GetInstanceInfo)
    if ok and iid and INSTANCE_EN[iid] then res = INSTANCE_EN[iid] end
  elseif C_Map and C_Map.GetBestMapForUnit then
    local z = RG.MapZone(C_Map.GetBestMapForUnit("player"))
    if z then res = z end
  end
  zoneT, zoneV = now, res
  return res
end

-- The route's name for the zone a map is in (a cave or a town's map counts as its zone), or nil.
local zoneOfMap = {}
function RG.MapZone(m)
  if not (m and C_Map) then return nil end
  local hit = zoneOfMap[m]
  if hit ~= nil then return hit or nil end
  do
    if not mapToZone then
      -- ZONE_MAPS also names places inside a zone (Ratchet, Auberdine, Valanaar...) with the zone's map: for each map,
      -- the route's zone name wins, then the map's own name, then the first alphabetically (pairs() order is random,
      -- and a player anywhere in the Barrens used to be "in Ratchet", which no route entry is)
      mapToZone = {}
      local routeZone = {}
      for _, r in ipairs(RG.ROUTE or {}) do routeZone[r.zone] = true end
      local function rank(z, m)
        if routeZone[z] then return 0 end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(m)
        if info and info.name == z then return 1 end
        return 2
      end
      for z, m in pairs(RG.ZONE_MAPS or {}) do
        local cur = mapToZone[m]
        if not cur then mapToZone[m] = z
        else
          local a, b = rank(z, m), rank(cur, m)
          if a < b or (a == b and z < cur) then mapToZone[m] = z end
        end
      end
      for mm, z in pairs(CITY_EN) do mapToZone[mm] = z end
    end
  end
  local res, cur, guard = false, m, 0
  while cur and guard < 6 do
    guard = guard + 1
    if mapToZone[cur] then res = mapToZone[cur]; break end
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(cur)
    cur = info and info.parentMapID
    if info and info.mapType and info.mapType <= 2 then break end   -- (reached the continent: not a listed zone)
  end
  zoneOfMap[m] = res
  return res or nil
end

-- Which of the game's quest objectives is our objective #k? By its text (English clients), or else by position
-- when the quest has the same number of objectives in both (other languages).
function RG.MatchObjective(objs, qdo, k)
  local d = qdo and qdo[k]
  if not (d and objs) then return nil end
  -- (several objectives with the same name, Valuable Vantages' three "Credit"s: the n-th of that name is the game's n-th)
  local nth = 0
  for i = 1, k do if qdo[i][2] == d[2] then nth = nth + 1 end end
  for _, o in ipairs(objs) do
    if o.text and o.text:find(d[2], 1, true) then
      nth = nth - 1
      if nth == 0 then return o end
    end
  end
  -- (fewer of that name in the game than in the data: the last one there is)
  for i = #objs, 1, -1 do local o = objs[i]; if o.text and o.text:find(d[2], 1, true) then return o end end
  if #objs == #qdo then
    -- only when no objective of this quest matches by text (so an English client never guesses)
    for _, x in ipairs(qdo) do for _, o in ipairs(objs) do if o.text and o.text:find(x[2], 1, true) then return nil end end end
    return objs[k]
  end
  return nil
end
-- Do we know a flight path whose name contains this text? nil = never seen a flight master yet.
local fpMemo, fpMemoFor, fpMemoVer
function RG.KnowsFP(part)
  -- nil = we can't tell yet (no flight master visited since Waypath+ was installed); a character
  -- Waypath+ has followed from level 1 starts with an empty, complete list (fpsAll)
  local fps = RG.db.fps
  if not fps or (not next(fps) and not RG.db.fpsAll) then return nil end
  -- (the travel planner asks this hundreds of times in one pass: the answer is kept until the list of known paths changes)
  if fpMemoFor ~= fps or fpMemoVer ~= RG.fpVer then fpMemo, fpMemoFor, fpMemoVer = {}, fps, RG.fpVer end
  local hit = fpMemo[part]
  if hit ~= nil then return hit end
  local p = part:lower()
  hit = false
  for name in pairs(fps) do if name:lower():find(p, 1, true) then hit = true; break end end
  fpMemo[part] = hit
  return hit
end
function RG.Skill(name) local p = RG.Professions()[name]; return p and p.rank or nil end
-- Crafted gear in the gear guide (generated entries carry prof and sk, hand-written ones bs):
--   "make"  you can make it now
--   "buy"   Bind on Equip, and you can't make it (yet): buy one on the Auction House
--   "skill" Bind on Pickup, you have the profession but not the skill yet
--   "no"    Bind on Pickup and you don't have the profession: not for you
function RG.CraftState(g)
  local prof = g.prof or (g.bs and "Blacksmithing")
  if not prof then return nil end
  local need, have = g.sk or g.bs or 0, RG.Skill(prof)
  if have and have >= need then
    -- your skill is high enough; once you've opened the profession window we know whether you have the recipe
    local known = RG.KnowsCraft and RG.KnowsCraft(prof, g.id)
    if known == false then return "learn", prof, need, have end
    return "make", prof, need, have
  end
  if g.boe or not g.prof then return "buy", prof, need, have end
  if have then return "skill", prof, need, have end
  return "no", prof, need, have
end
-- in your gear guide at all (Bind on Pickup crafts only for their own profession)
-- Questie, which nearly everyone runs beside Waypath+: what it already shows or does, so we don't do it twice.
-- (We only read its settings; we never change them.)
function RG.QuestieProfile()
  local Q = rawget(_G, "Questie")
  if type(Q) ~= "table" then return nil end
  local ok, p = pcall(function() return Q.db and Q.db.profile end)
  return ok and type(p) == "table" and p or nil
end
function RG.QuestieDoes(what)
  local p = RG.QuestieProfile()
  if not p then return false end
  if what == "accept" then return type(p.autoAccept) == "table" and p.autoAccept.enabled == true end
  if what == "turnin" then return p.autocomplete == true end
  if what == "tracker" then return p.trackerEnabled ~= false end
  if what == "nameplates" then return p.nameplateEnabled ~= false end
  if what == "map" then return p.enableMapIcons ~= false end
  if what == "available" then return p.enableAvailable ~= false end
  return false
end
-- An option whose default steps back when Questie already covers it: your own choice in Settings always wins.
function RG.OptBesideQuestie(key, what)
  if RG.db and RG.db[key] ~= nil then return RG.db[key] ~= false end
  if RG.QuestieDoes(what) then return false end
  return RG.Opt(key)
end

function RG.GearShown(g)
  if RG.CraftState(g) == "no" then return false end
  -- a quest reward from a quest you've already turned in (you took another reward, or sold it): it's gone
  if g.how == "Quest" and g.q and not g.live and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, g.q)
    if ok and done == true and not RG.OwnState(g.id) then return false end
  end
  -- a quest reward from a quest your race or class can't take (another race's starting quests, say)
  if g.how == "Quest" and g.q and RG.QDATA and RG.QuestForMe then
    local d = RG.QDATA[g.q]
    if d and not RG.QuestForMe(d) then return false end
  end
  return true
end
-- something you can go and get now (for "best upgrades now", the tracker and the level-up count)
function RG.GearGettable(g) local st = RG.CraftState(g); return st == nil or st == "make" or st == "buy" or st == "learn" end

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
    -- a brand-new character knows no flight paths yet: remember that, so the reminders work before its first flight
    if RG.db.fps == nil and UnitLevel and (UnitLevel("player") or 99) <= 2 then RG.db.fps, RG.db.fpsAll = {}, true end
    -- a character Waypath+ hasn't seen: the first one gets a full profile, any
    -- later one is asked: its own new profile, or a bank alt
    if RG.CardsOnly() then
      -- the cards-only switch: no guide messages, no questions, no news
      if not RG.CharMode() then RG.SetCharMode("profile") end
      RG.db.welcomed, RG.db.setupDone = true, true
      return
    end
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
  elseif RG.IsAlt() or RG.CardsOnly() then
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
        if n.name and n.state ~= (Enum.FlightPathState and Enum.FlightPathState.Unreachable or 2) then RG.db.fps[n.name] = true; RG.fpVer = (RG.fpVer or 0) + 1 end
      end
    elseif NumTaxiNodes and TaxiNodeName then
      for i = 1, NumTaxiNodes() do
        local t = TaxiNodeGetType and TaxiNodeGetType(i)
        if t ~= "NONE" then RG.db.fps[TaxiNodeName(i)] = true; RG.fpVer = (RG.fpVer or 0) + 1 end
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
  elseif cmd == "fishseen" then
    local l = RG.FishSeenList and RG.FishSeenList() or {}
    if #l == 0 then RG.Print("No catches learned yet beyond the built-in tables.") end
    for _, e in ipairs(l) do RG.Print(e.zone .. ": " .. ((RG.FISH_LOOT and RG.FISH_LOOT.info[e.id] or {})[1] or ("item " .. e.id)) .. " x" .. e.n) end
  elseif cmd == "gpscheck" then
    if RG.GPSCheck then RG.GPSCheck() end
  elseif cmd == "trail" then
    if rest == "reset" then RG.TrailReset(); RG.Print("Learned paths cleared.")
    elseif rest == "off" or rest == "on" then RG.db.trail = (rest == "on"); RG.Print("Learned paths " .. rest .. ".")
    elseif rest == "export" or rest == "import" then RG.ShowTrailBox(rest)
    else RG.Print("Learned paths: " .. (RG.TrailSize and RG.TrailSize() or 0) .. " points remembered. /wp trail off | on | reset | export | import") end
  elseif cmd == "route" and (rest == "guide" or rest == "smart" or rest == "guided" or rest == "zone" or rest == "log" or rest == "") then
    -- what the tracker follows: guide (the route in order; smart / guided: with the smart zone order on or off),
    -- zone (one zone's route) or log (only your quests)
    if rest == "" then
      RG.Print("Following: " .. (RG.ModeName and RG.ModeName(RG.RouteMode()) or "?") .. (RG.RouteMode() == "guide" and (RG.db.smart == false and " (in order)" or " (smart zone order)") or "") ..
        ". /wp route guide | zone | log  ·  /wp route smart | guided: the guide with the smart zone order on or off")
      return
    end
    if RG.SetRouteStyle then RG.SetRouteStyle(rest == "guide" and "guide" or rest) end
  elseif cmd == "smart" then
    if RG.SmartToggle then RG.SmartToggle(rest == "on" or (rest ~= "off" and RG.db.smart == false)) end
  elseif cmd == "weight" then
    local stat, val = rest:match("^(%S+)%s+([%d%.]+)$")
    stat = stat and stat:upper()
    if stat and RG.db.weights[stat] ~= nil then
      RG.db.weights[stat] = tonumber(val); wipe(cache); if RG.CompareReset then RG.CompareReset() end
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
      "|cffffd100Questing|r  /wp next  ·  /wp plan  ·  /wp near  ·  /wp why  ·  /wp goto 45 60 Name  ·  /wp minimal  ·  /wp undo  ·  /wp route guide | zone | log  ·  /wp way 45 60  ·  /wp auto  ·  /wp pace  ·  /wp session",
      "|cffffd100Tabs|r  /wp group  ·  /wp heal  ·  /wp fish  ·  /wp camp  ·  /wp gold  ·  /wp mail  ·  /wp fp  ·  /wp log",
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
