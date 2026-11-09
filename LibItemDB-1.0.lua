-- LibItemDB-1.0
-- A standalone, offline item database for World of Warcraft: resolve a name to
-- an item link / id (and back), read item level + stats, filter by type /
-- subtype / stat, and resolve random-suffix variants ("<base> of the Eagle")
-- — all without the item being in the client cache.
--
-- WoW ships no searchable item table and no name->item API. The data is built
-- offline from the client's DB2 tables (wago.tools) and shipped as static Lua.
--
-- Storage is split so language-independent bulk loads ONCE:
--   * core  — Data/<game>/_core/<Class>.lua, guarded by game version only.
--             quality, subclass, equip slot, item level, stats. Identical in
--             every locale, so it is shipped and parsed a single time.
--   * names — Data/<game>/<locale>/<Class>.lua, guarded by GetLocale(). Just
--             the localized item name. Only the active locale's files load.
--   * randomProps — positive ItemRandomProperties IDs (item-link field 8, e.g.
--             "item:15218::::::1196" = Crystal Sword of the Bear). Each ID is
--             one suffix family at one fixed magnitude tier; names + stat lines
--             are localized, so these ship per-locale (small: ~2k rows).
--
-- Usage (any addon):
--   local DB = LibStub("LibItemDB-1.0", true)
--   if DB and DB:IsReady() then
--       local link  = DB:GetLink(19019)            -- Thunderfury link
--       local id    = DB:GetID("Black Lotus")      -- 13468
--       local stats = DB:GetStats(13468)           -- { ITEM_MOD_..._SHORT = n, ... }
--       local buff  = DB:GetEffects(13452)         -- Elixir of Mongoose use-effect buff
--       for _, r in ipairs(DB:Search({ classID = 4, stat = "STRENGTH" })) do ... end
--       local v = DB:ResolveName("Demon Blade of the Eagle")  -- name, family, propIDs
--       local p = DB:GetRandomProperty(1196)      -- { name="of the Bear", stats={...} }
--       local s = DB:BuildItemString(15218, 1196) -- "item:15218::::::1196" (SetHyperlink)
--       local d = DB:GetSources(18814)            -- { { instance="Molten Core", boss="Ragnaros", rate=… }, ... }
--       local pct = DB:GetDropRate(18814, 11502)  -- drop chance from that boss, percent (nil = unknown)
--       local ok  = DB:CanUse(18814)               -- class tag AND proficiency (a hunter and a mace: false)
--       for _, inst in ipairs(DB:GetInstances()) do local ids = DB:GetInstanceItems(inst.key) end
--       local copper, why = DB:GetPrice(13468, "minBuyout")  -- Price/Sources.lua: value + provenance
--   end

local MAJOR, MINOR = "LibItemDB-1.0", 47
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end   -- a same-or-newer version is already loaded

-- Persistent state across library upgrades.
-- core:  [id] = "classID<SEP>quality<SEP>subClassID<SEP>equipLoc<SEP>itemLevel<SEP>statBlob"
-- names: [id] = "localized name"  (active locale only)
-- statBlob: "KEY=val,KEY=val" of GetItemStats keys (resolve display via _G[KEY]).
lib.core        = lib.core        or {}
lib.names       = lib.names       or {}
lib.classCounts = lib.classCounts or {}   -- [classID] = item count
lib.count       = lib.count       or 0
lib.meta        = lib.meta        or {}   -- { locale, build }
-- reqLevel: [id] = required player level, shipped ONLY for items that have one. A known
-- item absent here has no requirement (GetRequiredLevel answers 0); an unknown item
-- answers nil. Kept out of the core row so adding it did not mean regenerating every
-- stat row from a client walk. Built by tools/build-req-levels.py from wago ItemSparse.
lib.reqLevel    = lib.reqLevel    or {}
-- vendorPrice: [id] = copper a vendor CHARGES for the item. Shipped only for items an
-- emulator npc_vendor dump shows a vendor stocking with unlimited supply for gold. An
-- absent id means "no vendor RECORD", not "no vendor sells it" — the dumps are Wrath/Cata
-- era, so a Vanilla-only vendor's stock can be missing entirely (see GetVendorBasePrice).
--   * NOT GetItemInfo's sellPrice, which is what a vendor pays YOU and which the client
--     already has. There is no client API for the buy price outside an open merchant
--     window (GetMerchantItemInfo), which is why this ships as data.
--   * The BASE price — what a NEUTRAL player pays. Reputation discounts are applied
--     server-side at purchase and exist in no client table, so a consumer rendering this
--     as "the price" is wrong for anyone above Neutral. Hence GetVendorBasePrice.
-- Built by tools/build-vendor-prices.py (wago ItemSparse.BuyPrice ∩ npc_vendor).
lib.vendorPrice = lib.vendorPrice or {}
-- sellPrice: [id] = copper a vendor PAYS YOU for the item. The opposite direction to
-- vendorPrice above, ~4x smaller, and never interchangeable with it. No vendor gate: any
-- vendor buys anything, so absence here means the item has no sell value at all (a quest
-- item, a token) rather than "no record". GetItemInfo returns this natively but only for a
-- CACHED item — nil on a cold cache — which is the retry loop this library removes.
lib.sellPrice = lib.sellPrice or {}
-- randomProps: [propID(number)] = "name<SEP>statLine<SEP>statLine..."
--   propID is the positive ItemRandomProperties ID = item-link field 8.
--   name = suffix family ("of the Bear"); each statLine is an exact display
--   string ("+6 Stamina"). One entry per family-per-tier.
lib.randomProps = lib.randomProps or {}
-- effects: [id] = "KEY=val,KEY=val" — buffs a use-effect consumable grants
--   (food/elixirs/flasks/scrolls/...). GetItemStats can't report use effects, so
--   these are built offline from DB2 (tools/build-effects.py) in the SAME stat
--   vocabulary as core statBlobs (ITEM_MOD_* where an equipment equivalent
--   exists; a few use-only keys: CRIT_PCT, SPELL_CRIT_PCT, HEALTH, MANA).
--   Merged into GetStats / Search so a consumable's buff is queryable like gear.
lib.effects     = lib.effects     or {}
-- consumableType: [id] = our category for a use-effect consumable (flask/elixir/potion/scroll/food/
--   weapon/bandage/other). WoW files vanilla consumables under one subclass, so we classify them
--   (build-effects.py) and serve the grouping via GetConsumableCategories / GetConsumableBuffs.
lib.consumableType = lib.consumableType or {}
-- consumableGroup: [id] = mutual-exclusion slot ("agility-elixir" / "flask" / "food" / …). WoW enforces
--   "one active per group" for consumable buffs but doesn't tag it in the DB2, so it's sourced from
--   WoWSims (build-consumable-groups.py). Read via GetConsumableGroup / GetConsumableBuffs(...).exclGroup.
lib.consumableGroup = lib.consumableGroup or {}
-- imbueWeapons: [id] = "Axe,Dagger,Polearm,Sword" -- the weapon types (GetItemType names) a
--   sharpening stone / weightstone can be applied to, from its spell's SpellEquippedItems rule
--   (build-effects.py). Absent = no weapon-type rule (an oil fits any weapon). MINOR 42.
lib.imbueWeapons = lib.imbueWeapons or {}
-- reagentUses: [itemID] = "171,185" -- the skill line ids of the professions that use this item as a
--   crafting MATERIAL, which is the reverse of a recipe's reagent list and the one direction the
--   database could not answer ("what is this stack of cloth for"). professionNames maps those ids
--   to enUS names. Built offline (build-reagents.py) from the same DB2 tables LibProfessionDB
--   models recipe-first, so neither library holds a copy of the other's data. Read via
--   GetReagentUses / IsReagent.
lib.reagentUses     = lib.reagentUses     or {}
lib.professionNames = lib.professionNames or {}
-- expansionOf: [itemID] = expansion (LE_EXPANSION_*: 0 Classic ... 11 Midnight; -1 = not known)
--   for the items that are NOT the version's default; expansionDefault is that default, nil on a
--   version that ships no expansion data. Built offline (build-expansions.py). Read via GetExpansion.
lib.expansionOf     = lib.expansionOf     or {}
-- placeOf: [itemID] = "d92:21.84,v66,g1731:100" -- where to get an item: d = a creature that drops
--   it (with its percent chance, negative when it only drops while on a quest), v = a vendor that
--   sells it, g = an object (ore vein, herb, fishing pool, chest) that yields it. placeEntity:
--   ["c92"] / ["o1731"] = "name<US>tag<US>place<US>place..." shared by every item that names it.
--   Built offline (build-item-places.py). Read via GetItemPlaces.
lib.placeOf         = lib.placeOf         or {}
lib.placeEntity     = lib.placeEntity     or {}
-- placeName: ["c92"] = the entity's name in the client's language ("Felselementar"), only where it
--   differs from the English name inside placeEntity. Loaded by Data/<V>/<locale>/PlaceNames.lua,
--   which guards on GetLocale(). Read through GetItemPlaces.
lib.placeName       = lib.placeName       or {}
-- auraBuffs: [spellID] = { category, name, statBlob } — the stats a raid/world/self/totem BUFF
--   grants, EVERY rank, in the core statBlob vocabulary. Buffs aren't items, so a consumer reads
--   verified magnitudes here (GetAuraBuff by spellID / GetAuraBuffs by name) instead of hardcoding
--   them. Built offline from wago DB2 (tools/build-aura-buffs.py); only the buff NAME list is curated.
lib.auraBuffs        = lib.auraBuffs        or {}
lib.auraBuffsByName  = lib.auraBuffsByName  or {}
lib.auraBuffsByCat   = lib.auraBuffsByCat   or {}   -- [category] = { [buffName] = true } — for enumeration
-- auraGroup: [buffName] = mutual-exclusion slot ("blessing-of-kings" / "sayges-fortune" / …), the
--   aura counterpart of consumableGroup. TWO NAMES SHARING A TOKEN IS THE POINT: Blessing of Kings
--   and Greater Blessing of Kings are one slot, and so are all eight Sayge's Dark Fortunes, so a
--   buff planner offers each once instead of counting them twice. Keyed by NAME, not spellID,
--   because every rank of a buff shares the slot. nil = no WoWSims model names a slot for that
--   buff (the hunter aspects) — unknown, NEVER "stacks with everything". Read via GetAuraGroup, or
--   the exclGroup field of GetAuraBuff / GetAuraBuffs / GetBuffsInCategory rows. MINOR 31.
lib.auraGroup        = lib.auraGroup        or {}
-- auraSlotKeys: [buffName] = { [slot] = { [statKey] = true } } -- the SECOND and later slots of a
--   buff that fills more than one raid-buff category (Mists Arcane Brilliance: +10% spell power in
--   "spell-power-pct" AND +5% crit in "crit"). The game's stacking rule is per stat, not per buff --
--   WoWSims models every buff stat as its own exclusive effect keyed by that stat -- so one token
--   per name over-counts the second category beside another buff that fills it. Only the extra
--   slots are stored; every stat not named here belongs to auraGroup's slot. Read via the `slots`
--   field of GetAuraBuff / GetAuraBuffs ranks, or GetAuraSlots. MINOR 39.
lib.auraSlotKeys     = lib.auraSlotKeys     or {}
-- talents: [classID] = { [tab] = { id, name, talents = { [index] = {tier,column,maxRank,name,spellID,prereq} } } }
--   Every class's talent tree STRUCTURE, so a consumer can render an offline planner for ANY class —
--   the live GetTalentInfo API only exposes the logged-in character's class. `tab` is in-game tab order;
--   `index` numbers a tab's talents by (tier,column) like GetTalentInfo, so `prereq` is an index in the
--   same tab. Built offline from wago DB2 Talent + TalentTab (tools/build-talents.py). Read via
--   GetTalentTree(classID) / GetTalentClasses.
lib.talents          = lib.talents          or {}
-- talentEffects: [classID] = { [tab] = { [index] = { "rank1blob", "rank2blob", …, weapons="Axe,Sword"? } } }
--   The whole-character stat modifiers a talent grants, per rank, in the same stat vocabulary gear/buffs
--   use (plus PCT_<STAT> percents). `weapons` (optional) tags crit/hit/damage that only applies while
--   wielding one of those weapon types (GetItemType names). Only PASSIVE talents are here — a talent that
--   grants an active/buff isn't a sheet modifier. Spell-property mods, procs and conversions are absent
--   (they modify spells, not the sheet). Built offline (tools/build-talents.py). Read via GetTalentEffect.
lib.talentEffects    = lib.talentEffects    or {}
-- equipStats: [id] = "KEY=val,KEY=val" — on-EQUIP gear bonuses GetItemStats does
--   not report (vanilla implements hit/crit/etc. as equip spell effects, not stat
--   fields). Built offline from DB2 (tools/build-equip-stats.py) in the SAME stat
--   vocabulary; merged into GetStats/Search so a piece's real stat line is complete.
--   Since MINOR 43 it also carries the base school resistances (RESISTANCE1..6_NAME) that the
--   Classic clients' GetItemStats leaves out, e.g. Glacial Cloak's 24 frost.
lib.equipStats  = lib.equipStats  or {}
-- spellSchools: [id] = "fire" | "shadow,arcane" — the magic school(s) an item's
--   spell-damage bonus is restricted to, when it is school-specific (the walk reports
--   it as generic ITEM_MOD_SPELL_DAMAGE_DONE and drops the school). Only school-specific
--   items are present; generic +spell damage is absent. Built offline from the DB2 aura-13
--   school mask (tools/build-spell-schools.py). Lets a consumer gate spell-damage EP to the
--   matching spec (GetItemSchools) — a fire off-hand should not score for a frost mage.
lib.spellSchools = lib.spellSchools or {}
-- useEffects: [id] = { {k,m,d,cd}, ... } — an equippable's ON-USE effects (a
--   trinket's "Use: +280 AP for 20s, 2m cd"), which GetItemStats never reports.
--   k=stat key, m=magnitude, d=buff seconds, cd=cooldown seconds. GetItemScore adds
--   an uptime-averaged term (m * d/cd * premium). Built offline (build-use-effects.py).
-- unscoredProc: [id] = true for items whose on-use/proc effect we can't yet score
--   (ramps, chance-on-hit whose vanilla proc rate isn't in DB2, non-stat effects).
--   Exposed so a consumer can caveat them / not hide a known-BiS trinket on a 0.
lib.useEffects   = lib.useEffects   or {}
-- procEffects: [id] = { {b,k,m,d,ppm|ch,icd,st,sc,pm[,ws]}, ... } - chance-on-hit procs
--   with a known rate. b=bucket (buff/damage/heal/mana/extra_attack), k=stat (buff only),
--   m=magnitude, d=buff seconds, ppm=procs per minute OR ch=chance % (one of the two),
--   icd=internal cd secs, st=max
--   stacks, sc=trigger scope. GetItemScore prices each by rate x value per bucket.
--   pm=the RAW DB2 ProcTypeMask_0 that this row's `sc` was derived from (MINOR 23).
--   `sc` is a lossy flattening of it to "spell"/"any" and that flattening is KNOWN
--   WRONG (docs/AUDIT.md finding 15: a magnitude compare on a bitfield, so an on-cast
--   proc, a DoT-tick proc and a taken-damage proc all read "spell"). `pm` ships
--   UNINTERPRETED so a correct reading can be recomputed without a data rebuild.
--   Treat `sc` as provisional and `pm` as the fact.
--   ws=OPTIONAL, buff rows only: the proc opens a d-second WINDOW in which every trigger
--   (at the row's own scope rate) adds one stack of m, up to ws (Blackened Naaru Sliver
--   34427: 20 s, +44 AP a hit, 10 stacks). m is then PER STACK and the scorer prices the
--   window's Poisson-average stack count.
--   One spell that buffs several stats ships ONE ROW PER STAT AURA, all with the same rate
--   fields (Shard of Contempt 34472: an AP row and a ranged-AP row; the scorer prices the
--   generic-AP pair once). On Wrath a "+N spell power" buff's equal healing twin is NOT
--   shipped -- a healing row there is healing beyond the same spell's spell power.
lib.procEffects  = lib.procEffects  or {}
lib.unscoredProc = lib.unscoredProc or {}
-- Recipe-scroll data (recipeItems / skillRankBooks / syntheticRecipes / recipeScrollPrefixes /
-- recipeScrollUseText) MOVED to LibProfessionDB-1.0 at its MINOR 8, on 2026-08-06. It is
-- recipe-shaped rather than item-shaped, and it is keyed by craft spell id, which is how
-- LibProfessionDB already keys recipes. Ask that library for "which item teaches this recipe";
-- ask this one only what the resulting item is called and what its link is.
-- Item sets: membership + decoded set bonuses (tools/build-sets.py). Flat-stat
-- bonuses are EP-scorable; a proc bonus has an empty stat blob but its threshold
-- is still present so consumers know a bonus exists there.
--   sets:    [setID]  = { name, items = {id,...}, bonuses = { [n] = "KEY=val,.." } }
--   itemSet: [itemID] = setID
lib.sets        = lib.sets        or {}
lib.itemSet     = lib.itemSet     or {}
-- itemFaction: [itemID] = "A" | "H" for faction-restricted items (PvP rep gear,
-- faction quest rewards). Neutral items are absent. Built from DB2 (AllowableRace
-- + required-reputation faction). The ranking/search APIs hide the other faction's
-- items by default (a Horde player can't use Alliance-rep gear).
lib.itemFaction = lib.itemFaction or {}
-- itemRep: [itemID] = factionID * 16 + standing, for an item that needs reputation to buy or use
-- (ItemSparse MinFactionID / MinReputation). standing is the client's 1-8 reaction index
-- (DB2's 0-7 plus one). Read via GetRequiredReputation. Built by tools/build-reputation.py.
lib.itemRep     = lib.itemRep     or {}
-- Mount items: { [id] = true }. Classic files vanilla mounts as Miscellaneous/subclass 0 (the
-- client's subclass name is "Junk"), so this set — from build-mounts.py, items whose on-use spell
-- applies SPELL_AURA_MOUNTED — lets GetItemType report them as "Mount" instead.
lib.mounts      = lib.mounts      or {}
-- gems: [itemID] = "COLOURS<SEP>KEY=val,…" — the socket colours a gem fits (R/Y/B, or M for a
-- meta gem) and the stats it grants, in the same key space as item stats. Only expansions with
-- sockets ship this (TBC onward); an expansion's scoring module uses it to price an empty
-- socket at the best gem that fits it, instead of scoring sockets as nothing.
lib.gems        = lib.gems        or {}
-- hidden: [itemID] = true for test / placeholder / never-implemented items. Kept in
-- the DB (GetInfo/GetLink/GetStats still work) but excluded from rankings/search by
-- default (the ranking/search APIs skip them unless opts.includeHidden).
lib.hidden      = lib.hidden      or {}
-- classReq: [itemID] = class bitmask (bit = 1 << (classID-1)) for class-restricted
-- gear. From ItemSparse.AllowableClass, with the dungeon/AQ40/T3 sets and Atiesh —
-- which the client mis-flags as all-class — corrected by set membership offline
-- (tools/build-classes.py). All-class items are omitted (nil = anyone can use it).
-- The ranking APIs hide gear the player's class can't use by default.
lib.classReq    = lib.classReq    or {}
-- raceReq: [itemID] = "lo" or "lo:hi", the 32-bit halves of AllowableRace's 64-bit
-- mask (bit = 1 << (raceID-1)), for race-restricted gear. From ItemSparse via
-- tools/build-races.py. All-race items and a zero mask are both OMITTED, so nil
-- means "no restriction recorded" and RaceUsable fails open on it. Two halves
-- because Forever's masks exceed 2^53 and a Lua 5.1 double would round them.
lib.raceReq     = lib.raceReq     or {}
-- Drop sources (which boss/instance drops an item). Built offline from
-- AtlasLootClassic (tools/build-sources.py) — the Classic client ships no Dungeon
-- Journal, and the Retail Journal is too incomplete/wrong-era for Classic — and
-- filtered to items that exist in this version. The instance key is AtlasLoot's
-- stable data key (a string, e.g. "MoltenCore"); the encounter key is the boss
-- npcID. Provenance is tagged so another source (e.g. in-game capture) could be
-- merged via LoadSources with its own tag.
--   srcItems:   [itemID]   = "encID,encID"      bosses that drop the item
--   srcInst:    [instKey]  = "encID:encID:..."  an instance's bosses, in order
--   srcEncInst: [encID]    = instKey            boss -> its instance
--   srcProv:    [instKey]  = "atlasloot"|...    where the data came from
--   srcInstName/srcEncName: [key] = display instance / boss name
lib.srcItems    = lib.srcItems    or {}
lib.srcInst     = lib.srcInst     or {}
lib.srcEncInst  = lib.srcEncInst  or {}
lib.srcProv     = lib.srcProv     or {}
lib.srcInstName = lib.srcInstName or {}
-- srcInstExp: [instanceKey] = "Vanilla" | "TBC" | "Wrath" | "Cata" | "Mists" — the expansion
-- the instance's CONTENT belongs to, not the client serving it. Absent for an instance whose
-- data predates the tag, and a consumer must treat absent as "current" rather than unknown.
lib.srcInstExp  = lib.srcInstExp  or {}
-- srcInstKind: [instanceKey] = "raid" | "dungeon" — what KIND of instance it is, which is a
-- property of the place rather than a rule about any consumer. Dibs' DIBSREQ-IDB-009, raised
-- out of a real defect: every consumer that wants to separate raid loot from dungeon loot was
-- otherwise keeping its own hardcoded set of OUR instance keys, and each one breaks on a
-- flavour whose keys differ. Dibs' set is Vanilla/TBC slugs, so on Forever — whose keys are
-- numeric zone ids — nothing matched, no instance was classified as a raid, and the per-raid
-- badge silently never appeared.
--
-- NIL MEANS UNKNOWN, never "dungeon". A consumer must not read absence as a negative answer:
-- Mists ships no kinds at all (its Sources.lua predates the current builder and cannot be
-- regenerated from it), and an instance whose upstream carries no classification is absent
-- here rather than guessed. Same contract as dropRate and BiS-weight authoredFor.
--
-- NOT a raid SIZE. The upstream distinguishes RAID10/20/25/40, and that is deliberately
-- flattened: which raids "count" is a consumer's rule, and Dibs explicitly asked for the fact
-- and not the judgement.
lib.srcInstKind = lib.srcInstKind or {}
lib.srcEncName  = lib.srcEncName  or {}
-- dropRate: [itemID] = "encID:percent,encID:percent" -- how LIKELY the boss is to drop the
-- item, as a percent (33 means 33%). Same encounter key as srcItems, so a GetSources row can
-- carry its own rate. Computed from the CMaNGOS world database's loot tables with the
-- server's own roll rules (tools/build-droprates.py) for every encounter in Sources.lua,
-- Vanilla and TBC alike, heroic loot included. An absent pair is UNKNOWN (nil), never 0 --
-- quest-gated drops are deliberately absent (no single rate), as is any encounter whose loot
-- the emulator hangs on a gameobject. Dibs' DIBSREQ-IDB-005 (MINOR 27).
lib.dropRate    = lib.dropRate    or {}
-- tokenRewards: [tokenItemID] = "rewardID,rewardID" -- the gear a boss-dropped token is turned in
-- for (Desecrated Robe -> the Naxxramas chests, Helm of the Fallen Champion -> the T4 helms),
-- every class's rewards together, sorted by id. The exchange is server-side, so it is built from
-- the CMaNGOS world database's quest turn-ins and vendor ExtendedCost exchanges
-- (tools/build-tokens.py), Vanilla and TBC. Dibs' contract 1c5f8e8d2faf (MINOR 44).
lib.tokenRewards = lib.tokenRewards or {}
-- Non-drop source locations from the CMaNGOS DB (quest/vendor/crafted/pvp/
-- reputation, plus world drops the boss graph misses), so nothing reads "Other".
--   itemLoc: [itemID] = { {location, kind}, ... }   kind in
--            quest|vendor|crafted|pvp|reputation|drop|gathered
--            (gathered: location is the profession -- Mining / Herbalism / Skinning / Fishing)
lib.itemLoc     = lib.itemLoc     or {}
-- Battleground + reputation REWARD gear by source and tier — bought with marks/rep, which
-- CMaNGOS's vendor data omits, so they'd otherwise read "Other". Built from AtlasLoot
-- (tools/build-rep-loot.py). Feeds GetSources (a source badge) and the loot browser's
-- pvp/factions modules (tier sections).
--   repLoot: { pvp|faction = { [sourceName] = { {tier, {itemID,...}}, ... } } }
lib.repLoot     = lib.repLoot     or {}
-- Best-in-Slot gear — a PROVIDER model, not factual data. `LoadBiS(source, ...)`
-- registers a named BiS list; the shipped one is "wowsims" (built offline from
-- the WoWSims sim presets), but any addon or the user can load their own list
-- under a different source name and pick it as the default. BiS is one opinion,
-- dated per content phase.
--   bis: [source] = { [classID] = { [spec] = { [phase] = { [SLOT] = itemID } } } }
--   SLOT is a slot key: HEAD NECK SHOULDER BACK CHEST WRIST HANDS WAIST LEGS FEET
--   FINGER1 FINGER2 TRINKET1 TRINKET2 MAINHAND OFFHAND RANGED.
lib.bis        = lib.bis        or {}
lib.bisDefault = lib.bisDefault or nil   -- chosen source; falls back to first loaded
-- bisWeights: [source][classID][spec] = { statKey = weight } — EP weights that
-- score/rank items (GetItemScore/RankItems/GetRaidBiS). Same provider model, but
-- a SEPARATE default from bis: fixed sets ship as "wowsims", weights as "hawsjon",
-- and a player's custom scale switches only the weight default. The source-picker
-- API (Get/SetDefaultBiSSource, GetBiSSources, GetBiSSpecs) is weight-scoped.
lib.bisWeights = lib.bisWeights or {}
lib.bisWeightsDefault = lib.bisWeightsDefault or nil
-- bisWeightsMeta: [source] = { authoredFor = "<Version>" } — PROVENANCE for a weight
-- scale, kept beside the numbers rather than inside them. A scale is authored against one
-- game version's combat model, and nothing in the weights themselves says which; a consumer
-- reading GetWeightStats sees stat keys and values that look identical whoever they were
-- tuned for. Forever is the case that made this necessary: it ships HawsJon's CLASSIC scale
-- because nobody publishes a Forever one, and a Forever player would otherwise see exactly
-- the UI an Era player sees with nothing to tell them apart.
--
-- DELIBERATELY TWO FACTS AND NO VERDICT. There is no `tuned` or `trustworthy` boolean here,
-- at the requesting consumer's insistence and correctly: whether Classic's weights are good
-- enough for a Forever raider is the player's call and the guild's, not the library's, and a
-- boolean would bake one answer into data every consumer has to accept. Provider + the
-- version it was authored for lets each consumer draw its own conclusion.
lib.bisWeightsMeta = lib.bisWeightsMeta or {}
-- bisWeightsSpec: [weightTable] = { classID, spec } -- which class/spec a loaded weight table
-- was registered under, so the scorer (which is handed only the table) can find the rules'
-- per-spec `spellShare` override (see the scoring rules contract). Weak-keyed: a table a
-- later LoadBiSWeights replaced is collected with it. One table registered under two specs is
-- named by the LAST registration -- every shipped scale gives each spec its own table literal.
lib.bisWeightsSpec = lib.bisWeightsSpec or setmetatable({}, { __mode = "k" })
-- _noThreatSpecs: { [classID] = { [spec] = true } } -- the tank and healer specs threat reduction
-- is worth nothing to, read as the `exclude =` of the THREAT_REDUCTION_PCT rules. ONE table here
-- because Scoring/Vanilla.lua (which Forever loads too) and Scoring/TBC.lua both read it and the
-- spec tokens are the same in all three flavours' scales (Peer Review 917f21ea F1;
-- Tests/libitemdb_spec.lua asserts every token names a spec the shipped scales load, and that
-- every tank or healer scale is listed). Each `default` listed is a healer scale's copy:
-- [2].default = holy and [5].default = discipline in Vanilla, TBC and Forever.
lib._noThreatSpecs = {
    [1]  = { protection = true },
    [2]  = { protection = true, holy = true, default = true },
    [5]  = { default = true, discipline = true, holy = true },
    [7]  = { tank = true, restoration = true },
    [11] = { feral_tank = true, restoration = true },
}
-- scoreModel: [source][classID][spec] = { usePremium, hitsPerSec, castsPerSec,
--   epPerRawDPS, epPerHPS } - OUR (MIT) scoring-model constants that the licensed
--   HawsJon stat weights don't provide: the on-use burst premium, the default proc
--   trigger rate (a paperdoll consumer overrides it at score time), the OPTIONAL cast
--   rate that prices `sc="spell"` procs instead (a paperdoll cannot supply this one,
--   it reports swings), and the raw-DPS / healing-per-second conversions. Kept SEPARATE from bisWeights so
--   HawsJon's data stays untouched. Missing keys fall back to the active expansion's
--   rules model (Scoring/<Version>.lua), since that tuning is per-expansion.
lib.scoreModel = lib.scoreModel or {}

local SEP = "\31"

local _GetItemClassInfo    = (C_Item and C_Item.GetItemClassInfo)    or _G.GetItemClassInfo
local _GetItemSubClassInfo = (C_Item and C_Item.GetItemSubClassInfo) or _G.GetItemSubClassInfo
-- Namespaced first: WoW Forever (1.60.x) has ONLY C_Item.GetItemQualityColor -- the bare global is
-- nil there and every link build raised "attempt to call a nil value" (doc: wow-ui-source-forever
-- ItemDocumentation.lua:920, same four returns, the 4th being the hex string read below).
local _GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor) or _G.GetItemQualityColor
local _UnitFactionGroup    = UnitFactionGroup
local _UnitClass           = UnitClass
local _UnitRace            = UnitRace
local _UnitLevel           = UnitLevel
local strsplit             = strsplit
local format               = string.format

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------
-- core entry -> classID, quality, subClassID, equipLoc, itemLevel, statBlob
local function unpackCore(s)
    if not s then return nil end
    local f1, f2, f3, f4, f5, f6 = strsplit(SEP, s)
    return tonumber(f1) or -1, tonumber(f2) or 1, tonumber(f3) or -1,
           f4 or "", tonumber(f5) or 0, f6 or ""
end

local function decodeStats(blob)
    local t = {}
    if not blob or blob == "" then return t end
    for pair in blob:gmatch("[^,]+") do
        local k, v = pair:match("^(.-)=(.+)$")
        if k then t[k] = tonumber(v) or v end
    end
    return t
end

-- Layer a second blob UNDER an already-decoded table: a key `t` already carries wins, and a
-- nil/empty blob is a no-op. Separate from decodeStats because the precedence differs -- within
-- one blob the last spelling of a key wins (decodeStats), across blobs the first table to claim
-- a key keeps it. Exists so the extras merge does not allocate: the callers used to build an
-- `ipairs { a, b }` array AND a throwaway decode table per extra, three tables a call on
-- GetStats, which a consumer scoring a browser calls tens of thousands of times per refresh.
local function mergeStats(t, blob)
    if not blob or blob == "" then return t end
    for pair in blob:gmatch("[^,]+") do
        local k, v = pair:match("^(.-)=(.+)$")
        if k and t[k] == nil then t[k] = tonumber(v) or v end
    end
    return t
end

local function qualityHex(quality)
    local _, _, _, hex = _GetItemQualityColor(quality or 1)
    return hex or "ffffffff"
end

-- Plain item link from id + quality + name.
local function buildLink(id, quality, name)
    return format("|c%s|Hitem:%d|h[%s]|h|r", qualityHex(quality), id, name or "")
end

-- Raw item string the game reconstructs a full tooltip from. Layout after the id is
--   id : enchant : gem1 : gem2 : gem3 : gem4 : randomProperty
-- Splitting on ":" therefore gives f[1]="item", f[2]=id, f[3]=enchant, f[8]=randomProperty
-- — which is the "field 8" this file and the README use for the random property. (A
-- consumer counting from the ID instead calls those fields 2 and 7; same string.)
--   itemString(15218, 1196)             -> "item:15218::::::1196"
--   itemString(10132, 863, 2504)        -> "item:10132:2504:::::863"
-- Every part is optional; 0 and nil both mean "absent", and an id with nothing else
-- collapses to the bare "item:<id>" the client accepts for a plain item.
local function optField(v)
    v = tonumber(v)
    if not v or v == 0 then return "" end
    return tostring(v)
end

local function itemString(id, propID, enchantID, gem1, gem2, gem3, gem4)
    local parts = { optField(enchantID), optField(gem1), optField(gem2),
                    optField(gem3), optField(gem4), optField(propID) }
    for _, p in ipairs(parts) do
        if p ~= "" then
            return format("item:%d:%s:%s:%s:%s:%s:%s", id, parts[1], parts[2],
                          parts[3], parts[4], parts[5], parts[6])
        end
    end
    return format("item:%d", id)
end

-- Coloured, clickable item link carrying whatever of the above was supplied.
local function buildSuffixLink(id, propID, quality, fullName, enchantID, gem1, gem2, gem3, gem4)
    return format("|c%s|H%s|h[%s]|h|r", qualityHex(quality),
                  itemString(id, propID, enchantID, gem1, gem2, gem3, gem4), fullName or "")
end

local function className(classID)
    return (_GetItemClassInfo and _GetItemClassInfo(classID)) or ("Class " .. tostring(classID))
end

local function subClassName(classID, subID)
    return (_GetItemSubClassInfo and _GetItemSubClassInfo(classID, subID)) or ("Subtype " .. tostring(subID))
end

-- ---------------------------------------------------------------------------
-- Data loading — called by the shipped Data files (and any runtime top-up).
-- ---------------------------------------------------------------------------
-- Records the client build the data was captured on (locale-independent core).
function lib:SetBuild(build) self.meta.build = build or self.meta.build end

-- Locale-independent core for one item class. `bucket` =
-- { [idStr] = "quality<SEP>subClassID<SEP>equipLoc<SEP>itemLevel<SEP>statBlob" }.
-- Loaded once (the _core/<Class>.lua files guard on game version only). Merges.
function lib:LoadCore(classID, bucket)
    if type(bucket) ~= "table" then return end
    classID = tonumber(classID) or classID
    for idStr, packed in pairs(bucket) do
        local id = tonumber(idStr)
        if id then
            if self.core[id] == nil then
                self.count = self.count + 1
                self.classCounts[classID] = (self.classCounts[classID] or 0) + 1
            end
            self.core[id] = classID .. SEP .. packed
        end
    end
    self._slotIndex = nil   -- invalidate the lazy equipLoc -> items index
end

-- Localized names: { [idStr] = "name" }. Called by the per-locale Data files
-- (each guards on GetLocale()), so only the active locale's names load. Merges.
function lib:LoadNames(names)
    if type(names) ~= "table" then return end
    self.meta.locale = self.meta.locale or (GetLocale and GetLocale())
    for idStr, name in pairs(names) do
        local id = tonumber(idStr)
        if id then self.names[id] = name end
    end
    self._looseNames = nil  -- invalidate Search's lazy punctuation-free name index
end

-- DEPRECATED back-compat shim, and NOT unfinished work -- it is the ORIGINAL loader,
-- superseded at MINOR 4 by LoadCore + LoadNames. Pre-split data shipped one
-- self-contained table ({ [classID] = { [idStr] = "name<SEP>q<SEP>sub<SEP>equip<SEP>ilvl<SEP>stats" } });
-- this splits that into core + (active-locale) names and forwards to the real loaders.
--
-- NOTHING IN THIS REPO CALLS IT, and that is expected rather than a defect --
-- `dupscan` reports it under "no reference outside its definition" every run. Data files
-- ship INSIDE the package, so a new library can never meet an old data file: the only
-- caller this can ever have is an outside consumer holding its own pre-split table.
-- Checked 2026-08-17: no addon in the local AddOns tree calls it. That is not proof of
-- absence -- LibItemDB is a public CurseForge library, so removing it is a BREAKING
-- change for consumers we cannot see, and a computed-key call would dodge any search.
-- Kept deliberately: it is ~18 lines that forward to the real loaders, so it cannot
-- drift, and the cost of deleting it is unbounded and unobservable.
function lib:LoadClasses(build, classes)
    if type(classes) ~= "table" then return end
    self:SetBuild(build)
    self.meta.locale = self.meta.locale or (GetLocale and GetLocale())
    for classID, bucket in pairs(classes) do
        local names = {}
        local core  = {}
        for idStr, packed in pairs(bucket) do
            local name, q, sub, equip, ilvl, blob = strsplit(SEP, packed)
            core[idStr]  = (q or "1") .. SEP .. (sub or "-1") .. SEP ..
                           (equip or "") .. SEP .. (ilvl or "0") .. SEP .. (blob or "")
            if name and name ~= "" then names[idStr] = name end
        end
        self:LoadCore(classID, core)
        self:LoadNames(names)
    end
end

-- Random-property (suffix) data: { [propIDStr] = "name<SEP>statLine<SEP>..." }.
-- propID is the positive ItemRandomProperties ID (item-link field 8). Merges.
function lib:LoadRandomProps(props)
    if type(props) ~= "table" then return end
    for idStr, packed in pairs(props) do
        local id = tonumber(idStr)
        if id then self.randomProps[id] = packed end
    end
    self._familyIndex = nil   -- rebuilt lazily on next name lookup
end

-- Consumable use-effect stats: { [idStr] = "KEY=val,KEY=val" } in the core
-- statBlob vocabulary. Built by tools/build-effects.py from DB2; loaded once
-- per game version (locale-independent). Merges.
function lib:LoadEffects(effects)
    if type(effects) ~= "table" then return end
    for idStr, blob in pairs(effects) do
        local id = tonumber(idStr)
        if id then self.effects[id] = blob end
    end
    self._consByType = nil                            -- invalidate the lazy consumable-by-type index
end

-- Our consumable CATEGORY for each use-effect item: { [id] = "flask"|"elixir"|"potion"|"scroll"|"food"|
-- "weapon"|"bandage"|"other" }. Vanilla files every consumable under one subclass, so the client can't
-- group a flask from a potion — we classify (tools/build-effects.py) and serve it via GetConsumableBuffs.
function lib:LoadConsumableTypes(t)
    if type(t) ~= "table" then return end
    for idStr, cat in pairs(t) do
        local id = tonumber(idStr)
        if id then self.consumableType[id] = cat end
    end
    self._consByType = nil
end

-- The weapon types each temporary weapon enchant fits: { [id] = "Axe,Dagger,Polearm,Sword" }, the
-- GetItemType names. Built by tools/build-effects.py; read via GetImbueWeapons and the `weapons`
-- field of a GetConsumableBuffs row. Merges. MINOR 42 (Dibs' DIBSREQ-IDB-011).
function lib:LoadImbueWeapons(t)
    if type(t) ~= "table" then return end
    for idStr, list in pairs(t) do
        local id = tonumber(idStr)
        if id then self.imbueWeapons[id] = list end
    end
end

-- Which professions use each item as a crafting material: { [itemIDStr] = "171,185" } keyed by
-- skill line id, plus { [skillLineID] = name } (enUS). Built offline (tools/build-reagents.py).
-- Read via GetReagentUses / IsReagent. MINOR 32.
--
-- MERGES rather than replaces, so a consumer may top up with its own reagent data for items we
-- do not ship -- but a second load for an id it already holds REPLACES that id's professions
-- rather than adding to them, because the shipped value is the complete set for that item and a
-- union would make a partial consumer table silently widen ours.
function lib:LoadReagentUses(uses, names)
    if type(uses) == "table" then
        for idStr, blob in pairs(uses) do
            local id = tonumber(idStr)
            if id and type(blob) == "string" then self.reagentUses[id] = blob end
        end
    end
    if type(names) == "table" then
        for idStr, nm in pairs(names) do
            local id = tonumber(idStr)
            if id then self.professionNames[id] = nm end
        end
    end
end

-- Which expansion each shipped item comes from: every item the version ships is `default` unless
-- a packed "id,id,..." string under another expansion lists it. Built offline
-- (tools/build-expansions.py). Read via GetExpansion. MINOR 35.
function lib:LoadExpansions(default, others)
    self.expansionDefault = tonumber(default)
    if type(others) ~= "table" then return end
    for exp, packed in pairs(others) do
        exp = tonumber(exp)
        if exp and type(packed) == "string" then
            for part in string.gmatch(packed, "[^,]+") do
                local id = tonumber(part)
                if id then self.expansionOf[id] = exp end
            end
        end
    end
end

-- Where to get each item: the creatures, vendors and objects (see lib.placeOf), plus the packed
-- entity rows they name. Built offline (tools/build-item-places.py). Read via GetItemPlaces.
-- MINOR 36. Merges, so a second load for an id replaces that id's row.
function lib:LoadItemPlaces(entities, items)
    if type(entities) == "table" then
        for key, blob in pairs(entities) do
            if type(key) == "string" and type(blob) == "string" then self.placeEntity[key] = blob end
        end
    end
    if type(items) == "table" then
        for idStr, blob in pairs(items) do
            local id = tonumber(idStr)
            if id and type(blob) == "string" then self.placeOf[id] = blob end
        end
    end
end

-- Localized names for the entities LoadItemPlaces names: { ["c92"] = "Felselementar" }. Built
-- offline (tools/build-item-places.py) per client language. MINOR 36. Merges.
function lib:LoadPlaceNames(names)
    if type(names) ~= "table" then return end
    for key, name in pairs(names) do
        if type(key) == "string" and type(name) == "string" then self.placeName[key] = name end
    end
end

-- Consumable exclusion groups (see lib.consumableGroup). Built offline (build-consumable-groups.py).
function lib:LoadConsumableGroups(t)
    if type(t) ~= "table" then return end
    for idStr, grp in pairs(t) do
        local id = tonumber(idStr)
        if id then self.consumableGroup[id] = grp end
    end
end

-- Buff auras: { [spellIDStr] = { category, name, statBlob, exclGroup } }, every rank. Built by
-- tools/build-aura-buffs.py. Read via GetAuraBuff (by spellID) / GetAuraBuffs (all ranks by name).
--
-- `exclGroup` (field 4, MINOR 31) is the mutual-exclusion slot, and an EMPTY STRING there is
-- stored as nil rather than "": the generator writes "" for a buff no WoWSims model names a
-- slot for, and a consumer asking "is this grouped?" must get the same falsy answer whether
-- the field was empty or the whole file pre-dates MINOR 31. Field 4 is optional for exactly
-- that reason -- an older AuraBuffs.lua loads unchanged and simply carries no slots.
--
-- APPENDS rather than merges, unlike LoadEffects and LoadEquipStats which say "Merges." and are
-- idempotent. Calling this twice with an id it already holds lists that rank twice in
-- GetAuraBuffs -- multiple ids per name is correct and intended (1459 and 1460 are both "Arcane
-- Intellect"), so a membership test cannot be added without distinguishing the two cases. Not
-- reachable from shipped data: AuraBuffs.lua exists for Vanilla and TBC only and each is in
-- exactly one TOC, so one file loads per client. Documented rather than "fixed" because the
-- method is public -- a consumer topping up aura buffs at runtime would make it real.
--
-- Field 5 (MINOR 39, optional) names a buff's EXTRA slots, "slot:KEY,KEY;slot:KEY" -- the stat
-- keys that belong to a raid-buff category other than field 4's (see lib.auraSlotKeys). It is
-- read only beside a non-empty field 4, because an extra slot is meaningless without the primary
-- one that holds every other stat. An older library ignores the field and reads field 4 exactly
-- as before, so new data degrades to the single-slot answer rather than to a wrong token.
local function parseAuraSlots(spec)
    local out, any = {}, false
    for part in tostring(spec):gmatch("[^;]+") do
        local slot, keys = part:match("^([^:]+):(.+)$")
        if slot then
            for key in keys:gmatch("[^,]+") do
                out[slot] = out[slot] or {}
                out[slot][key] = true
                any = true
            end
        end
    end
    return any and out or nil
end

function lib:LoadAuraBuffs(t)
    if type(t) ~= "table" then return end
    for idStr, v in pairs(t) do
        local id = tonumber(idStr)
        if id and type(v) == "table" then
            self.auraBuffs[id] = { cat = v[1], name = v[2], blob = v[3] or "" }
            local byName = self.auraBuffsByName[v[2]]
            if not byName then byName = {}; self.auraBuffsByName[v[2]] = byName end
            byName[#byName + 1] = id
            local byCat = self.auraBuffsByCat[v[1]]
            if not byCat then byCat = {}; self.auraBuffsByCat[v[1]] = byCat end
            byCat[v[2]] = true                        -- unique buff NAMES per category
            if v[4] and v[4] ~= "" then
                self.auraGroup[v[2]] = v[4]
                if v[5] and v[5] ~= "" then self.auraSlotKeys[v[2]] = parseAuraSlots(v[5]) end
            end
        end
    end
end

-- A decoded stat map split by slot, { [slot] = { KEY = val } }, for a buff with extra slots; nil
-- for one without, so a single-slot buff's rows are exactly what they were before MINOR 39.
local function splitAuraStats(self, name, stats)
    local extra = self.auraSlotKeys[name]
    if not extra then return nil end
    local primary, out = self.auraGroup[name], {}
    for k, v in pairs(stats) do
        local slot = primary
        for s, keys in pairs(extra) do
            if keys[k] then slot = s; break end
        end
        out[slot] = out[slot] or {}
        out[slot][k] = v
    end
    return out
end

-- One class's talent tree structure (see the lib.talents note). Built offline
-- (tools/build-talents.py); called once per class. Later LoadTalents replaces a class.
function lib:LoadTalents(classID, tree)
    classID = tonumber(classID)
    if classID and type(tree) == "table" then self.talents[classID] = tree end
end

-- One class's talent EFFECTS (see the lib.talentEffects note). Built offline; called once per class.
function lib:LoadTalentEffects(classID, eff)
    classID = tonumber(classID)
    if classID and type(eff) == "table" then self.talentEffects[classID] = eff end
end

-- On-equip gear stats GetItemStats omits (hit/crit/spell-hit/spell-crit/...), in
-- the core statBlob vocabulary. Built by tools/build-equip-stats.py from DB2 equip
-- spell effects. Merged into GetStats / Search. Loaded once per version. Merges.
function lib:LoadEquipStats(stats)
    if type(stats) ~= "table" then return end
    for idStr, blob in pairs(stats) do
        local id = tonumber(idStr)
        if id then self.equipStats[id] = blob end
    end
end

-- School-specific spell-damage tags: { [idStr] = "fire" | "shadow,arcane" }. Built by
-- tools/build-spell-schools.py from the DB2 aura-13 school mask. Read via GetItemSchools. Merges.
function lib:LoadSpellSchools(t)
    if type(t) ~= "table" then return end
    for idStr, blob in pairs(t) do
        local id = tonumber(idStr)
        if id then self.spellSchools[id] = blob end
    end
end

-- Equippable on-use effects: { [idStr] = { {k,m,d,cd}, ... } }. Built by
-- tools/build-use-effects.py from DB2. Feeds GetItemScore's uptime term. Merges.
function lib:LoadUseEffects(t)
    if type(t) ~= "table" then return end
    for idStr, list in pairs(t) do
        local id = tonumber(idStr)
        if id then self.useEffects[id] = list end
    end
end

-- Chance-on-hit proc effects: { [idStr] = { {b,k,m,d,ppm|ch,icd,st,sc,pm[,ws]} } }.
-- Built by tools/build-use-effects.py. Priced by GetItemScore per bucket. Merges.
-- `pm` (MINOR 23) is the raw ProcTypeMask_0 behind `sc`; `ws` (MINOR 46, proc-window buff
-- rows only) is the in-window stack cap. See the procEffects note at the top.
function lib:LoadProcEffects(t)
    if type(t) ~= "table" then return end
    for idStr, list in pairs(t) do
        local id = tonumber(idStr)
        if id then self.procEffects[id] = list end
    end
end

-- Items with an on-use/proc effect we can't score yet: { [idStr] = true }.
function lib:LoadUnscoredProcs(t)
    if type(t) ~= "table" then return end
    for idStr in pairs(t) do
        local id = tonumber(idStr)
        if id then self.unscoredProc[id] = true end
    end
end

-- LoadRecipeItems / LoadSkillRankBooks / LoadSyntheticRecipes / LoadRecipeScrollPrefixes /
-- LoadRecipeScrollUseText moved to LibProfessionDB-1.0 (MINOR 8) with their data, 2026-08-06.

-- Item sets + set bonuses: { [setID] = { n=name, i="id,id", b={ [n]="KEY=val" } } }.
-- Built by tools/build-sets.py from DB2. Builds the itemID -> setID reverse map.
function lib:LoadSets(data)
    if type(data) ~= "table" then return end
    for idStr, s in pairs(data) do
        local sid = tonumber(idStr)
        if sid and type(s) == "table" then
            local items = {}
            for idpart in (s.i or ""):gmatch("[^,]+") do
                local iid = tonumber(idpart)
                if iid then items[#items + 1] = iid; self.itemSet[iid] = sid end
            end
            self.sets[sid] = { name = s.n, items = items, bonuses = s.b or {},
                               procs = s.p }   -- chance-on-hit set bonuses (Tier 3), or nil
        end
    end
end

-- Faction-restricted items: { [itemIDStr] = "A" | "H" }. Built by build-factions.py.
function lib:LoadFactions(t)
    if type(t) ~= "table" then return end
    for idStr, f in pairs(t) do
        local id = tonumber(idStr)
        if id then self.itemFaction[id] = f end
    end
end

-- Required reputation: { [itemIDStr] = factionID * 16 + standing }. Built by
-- tools/build-reputation.py. Read via GetRequiredReputation. Merges.
function lib:LoadReputation(t)
    if type(t) ~= "table" then return end
    for idStr, packed in pairs(t) do
        local id, n = tonumber(idStr), tonumber(packed)
        if id and n then self.itemRep[id] = n end
    end
end

-- Required player level: { [itemIDStr] = level }, non-zero only. Built by
-- tools/build-req-levels.py from wago ItemSparse.RequiredLevel. Read via
-- GetRequiredLevel / GetInfo's 7th return. Merges.
function lib:LoadRequiredLevels(t)
    if type(t) ~= "table" then return end
    for idStr, lvl in pairs(t) do
        local id, n = tonumber(idStr), tonumber(lvl)
        if id and n then self.reqLevel[id] = n end
    end
end

-- Vendor BUY prices: { [itemIDStr] = copper }, vendor-sold items only. Built by
-- tools/build-vendor-prices.py. Read via GetVendorBasePrice. Merges.
function lib:LoadVendorPrices(t)
    if type(t) ~= "table" then return end
    for idStr, copper in pairs(t) do
        local id, n = tonumber(idStr), tonumber(copper)
        if id and n and n > 0 then self.vendorPrice[id] = n end
    end
end

-- Vendor SELL prices: { [itemIDStr] = copper }, every item with a sell value. Built by
-- tools/build-vendor-prices.py. Read via GetVendorSellPrice. Merges.
function lib:LoadSellPrices(t)
    if type(t) ~= "table" then return end
    for idStr, copper in pairs(t) do
        local id, n = tonumber(idStr), tonumber(copper)
        if id and n and n > 0 then self.sellPrice[id] = n end
    end
end

-- Mount items: { [itemIDStr] = true }. Built by build-mounts.py. Read via GetItemType. Merges.
function lib:LoadMounts(t)
    if type(t) ~= "table" then return end
    for idStr in pairs(t) do
        local id = tonumber(idStr)
        if id then self.mounts[id] = true end
    end
end

-- Socket gems: { [gemID] = "COLOURS<SEP>KEY=val,…" }. Shipped only by expansions that have
-- sockets. The lib stores them raw. WHETHER an expansion has sockets is its rule (it registers
-- lib.StatScorers.sockets or not); the arithmetic is the core's, below the rules contract.

-- best[weights][colour] = EP of the best-scoring gem for that colour, per weight table.
-- GetSlotRanking over thousands of items would otherwise re-scan every gem for every socket.
-- Declared here so LoadGems can drop it: a cache built before a later LoadGems would otherwise
-- keep pricing sockets against the gem set it was built from.
local bestGemCache = setmetatable({}, { __mode = "k" })

function lib:LoadGems(t)
    if type(t) ~= "table" then return end
    for k in pairs(bestGemCache) do bestGemCache[k] = nil end
    for idStr, packed in pairs(t) do
        local id = tonumber(idStr)
        if id then self.gems[id] = packed end
    end
end

-- { colours = "RY", stats = { KEY = val, … } } for a gem, or nil. `colours` is the set of socket
-- colours it fits: R/Y/B (a gem may fit several), or "M" for a meta gem.
function lib:GetGem(id)
    local packed = self.gems[tonumber(id) or id]
    if not packed then return nil end
    local colours, blob = strsplit(SEP, packed)
    return { colours = colours or "", stats = decodeStats(blob or "") }
end

-- Every gem, as { [gemID] = { colours, stats } } — for a gem picker, or to build a
-- best-gem-per-colour table. Empty on an expansion without sockets.
function lib:GetGems()
    local out = {}
    for id in pairs(self.gems) do out[id] = self:GetGem(id) end
    return out
end

-- Class-restricted items: { [itemIDStr] = classMask }. Built by build-classes.py.
function lib:LoadClassRestrictions(t)
    if type(t) ~= "table" then return end
    for idStr, mask in pairs(t) do
        local id = tonumber(idStr)
        if id then self.classReq[id] = mask end
    end
end

-- Race-restricted items: { [itemIDStr] = "lo" | "lo:hi" }. Built by build-races.py (MINOR 30).
--
-- TWO HALVES, NOT ONE NUMBER, and that is forced by the data rather than a style choice.
-- AllowableRace is a 64-bit mask. On Vanilla and TBC the high word is always zero and the
-- values are small, but WoW Forever runs a modern client whose race list reaches id 96, and its
-- Alliance / Horde masks set 30 bits each up to bit 64 — 6130900294268439629 as a single
-- number. Lua 5.1 has only doubles, exact to 2^53, so that literal would ROUND and every bit
-- test against it would be wrong without anything saying so. Stored as given and tested per
-- half; RaceUsable picks the half, so no consumer does this arithmetic.
function lib:LoadRaceRestrictions(t)
    if type(t) ~= "table" then return end
    for idStr, packed in pairs(t) do
        local id = tonumber(idStr)
        if id and packed then self.raceReq[id] = packed end
    end
end

-- Hidden (test/placeholder/never-implemented) items: { [itemIDStr] = true }.
function lib:LoadHidden(t)
    if type(t) ~= "table" then return end
    for idStr in pairs(t) do
        local id = tonumber(idStr)
        if id then self.hidden[id] = true end
    end
    self._consByType = nil                            -- hidden filter feeds the consumable index; rebuild it
end

-- True if the item is flagged hidden (kept in the DB, not served in rankings/search).
function lib:IsHidden(itemID) return self.hidden[itemID] == true end

-- Drop-source graph for one provenance (`source`, e.g. "journal", "capture").
--   items     = { [itemIDStr] = "encID,encID" }        item -> encounters
--   instances = { [instIDStr] = "encID:encID:encID" }  instance -> ordered bosses
-- Locale-independent (numeric only); names load separately via LoadSourceNames.
-- Merges, so a second source can add instances/items the first lacked.
function lib:LoadSources(source, items, instances, expansions, kinds)
    if type(items) == "table" then
        for idStr, packed in pairs(items) do
            local id = tonumber(idStr)
            if id and packed and packed ~= "" then
                local cur = self.srcItems[id]
                self.srcItems[id] = cur and (cur .. "," .. packed) or packed
            end
        end
    end
    -- INSTANCES ARE LOADED FIRST, and the order is load-bearing rather than tidy: the two
    -- per-instance attribute maps below are filtered against `self.srcInst`, so the instances
    -- they describe have to exist by the time they run.
    if type(instances) == "table" then
        for idStr, encs in pairs(instances) do
            local id = tonumber(idStr) or idStr   -- instance key may be a string
            self.srcInst[id]  = encs
            self.srcProv[id]  = source or self.srcProv[id] or "journal"
            for encStr in encs:gmatch("[^:]+") do
                local e = tonumber(encStr)
                if e then self.srcEncInst[e] = id end
            end
        end
    end
    -- BOTH ATTRIBUTE MAPS ARE CONSTRAINED TO INSTANCES THAT ACTUALLY EXIST. Until MINOR 34 they
    -- were not: a builder emitting an attribute for a key absent from its `instances` table left
    -- GetInstanceKind answering for an instance GetInstances() never lists, so a consumer
    -- iterating the list and a consumer holding a key disagreed with no error. The expansion map
    -- had no per-key accessor at all -- it is only ever a field on a GetInstances() row -- which
    -- is part of why nobody could see it: there was no way to ask it the question directly.
    -- srcInstExp had that property from MINOR 16 and nothing noticed for seventeen versions;
    -- srcInstKind inherited it at MINOR 33 by being written next to it. Found in a self-audit
    -- and filed with only the new one named, which Peer Review correctly rejected: finding a
    -- second instance of a class while filing the first is the moment to sweep, not to defer.
    -- Dropping (rather than raising) matches the value filter on `kinds` just below.
    if type(expansions) == "table" then
        -- Which expansion an instance's content BELONGS to, which is not the same as the
        -- client serving it: a TBC client carries Molten Core ("Vanilla") alongside Karazhan
        -- ("TBC"). A consumer grouping a source list by expansion cannot derive this — the
        -- item ids and the instance keys look identical either way — so it ships as data.
        for idStr, exp in pairs(expansions) do
            local id = tonumber(idStr) or idStr
            if type(exp) == "string" and exp ~= "" and self.srcInst[id] ~= nil then
                self.srcInstExp[id] = exp
            end
        end
    end
    -- 5th arg: what KIND of place an instance is. Trailing and optional, exactly as `expansions`
    -- is, so a data file written against the four-argument form loads unchanged and simply
    -- carries no kinds. Only the two values the upstreams can actually justify are accepted --
    -- anything else is dropped rather than stored, so a consumer never has to defend against a
    -- third spelling appearing from a builder change.
    if type(kinds) == "table" then
        for idStr, kind in pairs(kinds) do
            local id = tonumber(idStr) or idStr
            if (kind == "raid" or kind == "dungeon") and self.srcInst[id] ~= nil then
                self.srcInstKind[id] = kind
            end
        end
    end
    self._srcInstItems = nil   -- invalidate the lazy instance->items index
    self._srcEncItems  = nil   -- ... and the per-BOSS one, which is built from the same srcItems
end

-- Per-boss drop rates: { [itemIDStr] = "encID:percent,encID:percent" }. A SEPARATE loader from
-- LoadSources on purpose -- the three-argument LoadSources every older data file calls, and its
-- packed "encID,encID" form, stay exactly as they were. Merges, so a second file can add pairs.
function lib:LoadDropRates(t)
    if type(t) ~= "table" then return end
    for idStr, packed in pairs(t) do
        local id = tonumber(idStr)
        if id and type(packed) == "string" and packed ~= "" then
            local cur = self.dropRate[id]
            self.dropRate[id] = cur and (cur .. "," .. packed) or packed
        end
    end
end

-- Token rewards: { [tokenIDStr] = "rewardID,rewardID" }. Called by _core/TokenRewards.lua.
-- Replaces per token rather than merging: one file ships per version, and a later load is the
-- newer statement of the whole list.
function lib:LoadTokenRewards(t)
    if type(t) ~= "table" then return end
    for idStr, packed in pairs(t) do
        local id = tonumber(idStr)
        if id and type(packed) == "string" and packed ~= "" then self.tokenRewards[id] = packed end
    end
end

-- Item source locations from the CMaNGOS DB: { [itemID] = { {location, kind}, ... } }.
-- Enriches GetSources with quest/vendor/crafted/pvp/reputation/world-drop origins the
-- AtlasLoot boss graph doesn't carry. Called by _core/ItemLocations.lua. Merges.
function lib:LoadItemLocations(t)
    if type(t) ~= "table" then return end
    for idStr, entries in pairs(t) do
        local id = tonumber(idStr)
        if id and type(entries) == "table" then self.itemLoc[id] = entries end
    end
end

-- Battleground / reputation reward loot by source and tier:
--   { pvp|faction = { [sourceName] = { {tier, {itemID,...}}, ... } } }
-- Built by tools/build-rep-loot.py from AtlasLoot (rewards CMaNGOS's vendor data omits). Merges.
function lib:LoadRepLoot(t)
    if type(t) ~= "table" then return end
    for kind, sources in pairs(t) do
        if type(sources) == "table" then
            local dst = self.repLoot[kind]
            if not dst then dst = {}; self.repLoot[kind] = dst end
            for name, tiers in pairs(sources) do dst[name] = tiers end
        end
    end
    self._repLootSrc = nil   -- invalidate the lazy itemID -> {source,place} index
end

-- Localized display names for the source graph:
--   { inst = { [instIDStr] = "Molten Core" }, enc = { [encIDStr] = "Lucifron" } }
-- Called by the per-locale SourceNames.lua (each guards on GetLocale()). Merges.
function lib:LoadSourceNames(names)
    if type(names) ~= "table" then return end
    if type(names.inst) == "table" then
        for idStr, nm in pairs(names.inst) do
            self.srcInstName[tonumber(idStr) or idStr] = nm   -- key may be a string
        end
    end
    if type(names.enc) == "table" then
        for idStr, nm in pairs(names.enc) do
            local id = tonumber(idStr)
            if id then self.srcEncName[id] = nm end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Status
-- ---------------------------------------------------------------------------
function lib:IsReady() return self.count > 0 end
function lib:Count()   return self.count end
function lib:GetMeta() return self.meta.locale, self.meta.build end

-- Realm season (Classic ruleset). Enum.SeasonID: 0 NoSeason (Era) / 1 Mastery /
-- 2 SeasonOfDiscovery / 3 Hardcore / 11 Fresh (Anniversary) / 12 FreshHardcore.
-- Feature-detected; defaults to 0 so unknown/failed detection loads Classic only.
function lib:GetSeason()
    if C_Seasons and C_Seasons.GetActiveSeason then return C_Seasons.GetActiveSeason() or 0 end
    if C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID then
        return C_SeasonInfo.GetCurrentDisplaySeasonID() or 0
    end
    return 0
end

-- True on realms whose items include the seasonal (>= 25000) range — SoD (2) and
-- Fresh/Anniversary (11, 12). The season-guarded overlay data files load only here;
-- Era / Hardcore get the original-Classic base only.
function lib:IsSeasonalRealm()
    local s = self:GetSeason()
    return s == 2 or s == 11 or s == 12
end

-- ---------------------------------------------------------------------------
-- Single-item lookups (by id)
-- ---------------------------------------------------------------------------
function lib:GetName(id) return self.names[id] end

-- name, quality, classID, subClassID, equipLoc, itemLevel, requiredLevel  (nil if unknown).
-- requiredLevel appended in MINOR 14; a caller written against 6 returns is unaffected.
function lib:GetInfo(id)
    local class, q, sub, equip, ilvl = unpackCore(self.core[id])
    if not class then return nil end
    return self.names[id], q, class, sub, equip, ilvl, self.reqLevel[id] or 0
end

-- Required PLAYER level to equip/use — not item level. `0` for an item with no
-- requirement, `nil` for an item the DB doesn't have, so "no requirement" and "no data"
-- stay distinguishable (a caller that treats both as "no requirement" can just use `or 0`).
function lib:GetRequiredLevel(id)
    if self.core[id] == nil then return nil end
    return self.reqLevel[id] or 0
end

-- What a vendor CHARGES for the item, in copper, or nil if we have no vendor record for it.
--
-- Three things a caller has to know, because every one of them fails as a plausible
-- wrong number rather than as an error:
--   * This is NOT GetItemInfo's sellPrice (what a vendor pays you). Opposite direction.
--   * It is the BASE price — what a NEUTRAL player pays. Reputation discounts are
--     applied server-side at purchase, so a player at Honored pays less than this and
--     the client is never told the discount. Label it accordingly, or don't show it.
--   * nil means "we have NO VENDOR RECORD for this item" — it is NOT proof that no vendor
--     sells it. The gate is an emulator npc_vendor dump from a LATER expansion (Wrath /
--     Cata), so an item sold only by a Vanilla- or TBC-era vendor the dump does not carry
--     is absent while a vendor really does sell it. Absence also covers a BuyPrice of 0
--     and an id this version does not ship. Do not build a "not sold by vendors" label on
--     top of nil.
-- Unlike GetRequiredLevel, nil is NOT distinguished from "unknown item": both answer nil.
-- There is no third state to represent — 0 is unreachable by construction at two
-- independent layers (build-vendor-prices.py requires bp > 0, and LoadVendorPrices rejects
-- 0/negative/non-numeric), so unlike GetRequiredLevel's 0 there is no meaningful domain
-- value to distinguish from "no data". Use HasItem(id) if you need to tell them apart.
function lib:GetVendorBasePrice(id)
    return self.vendorPrice[tonumber(id) or id]
end

-- What a vendor PAYS YOU for the item, in copper, or nil if it has no sell value.
--
-- The opposite direction to GetVendorBasePrice, and roughly 4x smaller — never substitute
-- one for the other. Three things worth knowing:
--   * GetItemInfo's 11th return is the same number, but ONLY for an item the client has
--     cached; it is nil otherwise and forces a GET_ITEM_INFO_RECEIVED retry loop. This is
--     always populated. Same rationale as GetRequiredLevel.
--   * nil here is a CLEAN statement, unlike GetVendorBasePrice's: the item has no sell
--     value (a quest item, a token). There is no vendor gate to muddy it.
--   * NO reputation discount is applied. Faction discounts are believed to be BUY-side
--     only — the sources define a faction discount in terms of buying, and say nothing
--     about selling — but that is NOT verified, and no client-side source can settle it:
--     the mechanic is entirely server-side (no flavour's client carries any discount
--     arithmetic). If it turns out selling is affected too, this number is the Neutral
--     one and a consumer would need to adjust it the same way it adjusts the buy price.
--     Stated as a limit rather than a guarantee on purpose.
function lib:GetVendorSellPrice(id)
    return self.sellPrice[tonumber(id) or id]
end

function lib:GetQuality(id)
    local _, q = unpackCore(self.core[id])
    return q
end

function lib:GetItemLevel(id)
    local _, _, _, _, ilvl = unpackCore(self.core[id])
    return ilvl
end

-- Stat table for an item, e.g. { ITEM_MOD_STRENGTH_SHORT = 24, RESISTANCE0_NAME = 1200 }.
-- For a use-effect consumable this is the granted buff (food/elixirs/...); for
-- gear it's the equipped stats. Core stats win if an id somehow carries both.
function lib:GetStats(id)
    local _, _, _, _, _, blob = unpackCore(self.core[id])
    local t = decodeStats(blob or "")
    -- Each extra is merged in by name, in order, so core stats win and equip-stats beat effects.
    -- The extras USED to be walked as `ipairs { self.equipStats[id] or "", self.effects[id] or "" }`
    -- and the `or ""` on each was load-bearing there, not defensive: a nil FIRST element ends
    -- ipairs immediately, which silently dropped the effects blob for every item with effects but
    -- no equip-stats -- i.e. every consumable, the main thing this getter is documented to serve.
    -- Naming the two calls removes the trap along with the array and the two throwaway decode
    -- tables; mergeStats takes nil itself, so nothing here depends on a sentinel any more.
    mergeStats(t, self.equipStats[id])
    mergeStats(t, self.effects[id])
    return t
end

-- Just the use-effect (consumable) buff stats for an item, or an empty table.
function lib:GetEffects(id)
    return decodeStats(self.effects[id] or "")
end

function lib:HasEffects(id) return self.effects[id] ~= nil end

-- The weapon types a sharpening stone / weightstone can be applied to, as a sorted list of
-- GetItemType names ({ "Axe", "Dagger", "Polearm", "Sword" }), or nil when the item carries no
-- weapon-type rule -- an oil (fits any weapon) or not a weapon imbue at all. Same shape as
-- GetTalentEffect's `weapons`. A fresh table per call. MINOR 42.
function lib:GetImbueWeapons(id)
    local blob = self.imbueWeapons[tonumber(id) or id]
    if not blob then return nil end
    local out = {}
    for name in blob:gmatch("[^,]+") do out[#out + 1] = name end
    return out
end

-- ---------------------------------------------------------------------------
-- Consumable use-effect enumeration — group every item that carries a use-effect
-- (Effects.lua) by OUR category (flask / elixir / potion / scroll / food / weapon /
-- other — see lib.consumableType; vanilla has no real consumable subclass), so a
-- consumer lists consumable buffs by section without a hand-kept list. Heal/restore
-- items (bandages, Dreamless Sleep) carry no effect row at all, so the "bandage"
-- classifier exists but yields no rows — a restore is not a buff. Lazy: the
-- by-type index is built once and cached until LoadEffects/LoadConsumableTypes changes it.
-- ---------------------------------------------------------------------------
function lib:_consumableIndex()
    if self._consByType then return self._consByType end
    local byType = {}
    for id in pairs(self.effects) do
        if not self.hidden[id] then                    -- test / deprecated / never-obtainable stay out of the picker
            local t = self.consumableType[id] or "other"   -- our category (build-effects.py); vanilla has no real subclass
            local bucket = byType[t]
            if not bucket then bucket = {}; byType[t] = bucket end
            bucket[#bucket + 1] = id
        end
    end
    self._consByType = byType
    return byType
end

-- The consumable categories present, sorted (e.g. "elixir", "flask", "food", "other", "potion", "weapon").
function lib:GetConsumableCategories()
    local out = {}
    for t in pairs(self:_consumableIndex()) do out[#out + 1] = t end
    table.sort(out)
    return out
end

-- Consumables that grant a use-effect, as { { id, name, type, stats, exclGroup, weapons }, … } sorted
-- by name. Pass a category (a GetConsumableCategories value) to restrict, or nil for all. `stats`
-- decodes like GetStats; `weapons` is GetImbueWeapons (nil unless a stone with a weapon-type rule).
function lib:GetConsumableBuffs(category)
    local byType = self:_consumableIndex()
    local out = {}
    local function add(t)
        for _, id in ipairs(byType[t] or {}) do
            out[#out + 1] = { id = id, name = self.names[id], type = t,
                              exclGroup = self.consumableGroup[id],
                              weapons = self:GetImbueWeapons(id),
                              stats = decodeStats(self.effects[id] or "") }
        end
    end
    if category then add(category) else for t in pairs(byType) do add(t) end end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

-- The professions that use an item as a crafting MATERIAL, as { { id, name }, … } sorted by name,
-- or nil if the item is not a reagent for any of them. `id` is the client's skill line id and
-- `name` is enUS, so a consumer with a localised source resolves its own from the id. This is the
-- reverse of a recipe's reagent list — "what is this stack of Mageweave for" — and is the question
-- SmexyMats existed to answer. MINOR 32.
function lib:GetReagentUses(itemID)
    local blob = self.reagentUses[tonumber(itemID) or itemID]
    if not blob then return nil end
    local out = {}
    for part in string.gmatch(blob, "[^,]+") do
        local id = tonumber(part)
        if id then out[#out + 1] = { id = id, name = self.professionNames[id] } end
    end
    if #out == 0 then return nil end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

-- The expansion an item comes from, the client's LE_EXPANSION_* number: 0 Classic, 1 The Burning
-- Crusade, 2 Wrath, 3 Cataclysm, 4 Mists ... 11 Midnight -- or nil when this version ships no
-- expansion data (Forever), does not ship the item, or does not KNOW it (listed under -1: a Retail
-- item no Classic flavour ships and whose ItemSparse.ExpansionID is unset). Up to Mists an item is
-- the first game whose data ships it; past Mists, Retail's own ItemSparse.ExpansionID. MINOR 35.
function lib:GetExpansion(itemID)
    local id = tonumber(itemID)
    if not id or self.expansionDefault == nil then return nil end
    local exp = self.expansionOf[id]
    if exp then return exp >= 0 and exp or nil end
    return self.core[id] and self.expansionDefault or nil
end

-- One packed place: "<uiMapID>:<count>:<x>,<y>;<x>,<y>" or "@<instance name>:<count>".
local function unpackPlace(s)
    local inst, n = s:match("^@(.*):(%d+)$")
    if inst then return { instance = inst, count = tonumber(n) } end
    local ui, count, pts = s:match("^(%d+):(%d+):?(.*)$")
    if not ui then return nil end
    local points = {}
    for x, y in pts:gmatch("([%d%.]+),([%d%.]+)") do
        points[#points + 1] = { x = tonumber(x), y = tonumber(y) }
    end
    return { uiMapID = tonumber(ui), count = tonumber(count), points = points }
end

-- q (MINOR 40): a quest giver, "q<creature>:<questID>" -- the second field is the quest, not a chance.
local PLACE_KIND = { d = "drop", v = "vendor", g = "object", q = "quest" }
-- Public (MINOR 40), read-only by contract: a consumer that decodes place tokens itself reads the
-- letters here instead of keeping a copy that misses the next one (Peer Review, thread 8acd9f23).
lib.PLACE_KIND = PLACE_KIND
-- A drop's loot-condition tag (tools/build-item-places.py condition_code) -> the row's `condition`.
-- "s<skill line>" is decoded separately into condition = "skill" plus conditionSkill.
local PLACE_CONDITION = { A = "Alliance", H = "Horde", e = "event", qd = "questDone",
                          qt = "questTaken", qn = "questNotStarted", c = "other" }

-- Where to get an item, as an array of rows in the order they should be shown -- drops by chance,
-- then vendors, then objects, then quest givers -- or nil when this version ships no place for it:
--   { kind = "drop"|"vendor"|"object"|"quest", id = creature or gameobject entry,
--     questID = the quest a "quest" row's creature gives (MINOR 40; nil when not recorded),
--     name = the client's language where a PlaceNames file names it, else English,
--     englishName = always the English name (for matching against other English data),
--     chance = percent (drops and objects; nil for a vendor), questOnly = true when it drops only
--     while the player is on a quest,
--     condition = nil, or what else the server requires for a drop: "Alliance" | "Horde" (one
--       faction's players), "skill" (a profession; conditionSkill = its skill line id), "event"
--       (a game event or holiday), "questDone" / "questTaken" / "questNotStarted", "other",
--     side = "A"|"H"|"AH"|"" (creatures: who can talk to it),
--     profession = "Mining"|"Herbalism"|"Fishing"|"" (objects: what opens it),
--     places = { { uiMapID, count, points = { { x, y }, ... } } | { instance, count } } }
-- A place's points are 0-100 map coordinates on that uiMapID, at most three per zone, standing
-- for `count` spawns; C_Map.GetWorldPosFromMapPos turns one into world yards. Every call builds
-- fresh tables, so a caller may keep or change them. MINOR 36.
function lib:GetItemPlaces(itemID)
    local blob = self.placeOf[tonumber(itemID) or itemID]
    if not blob then return nil end
    local out = {}
    for tok in blob:gmatch("[^,]+") do
        local k, eid, chance, cond = tok:match("^(%a)(%d+):?(%-?[%d%.]*):?(%w*)$")
        local kind = k and PLACE_KIND[k]
        local key = kind and ((k == "g" and "o" or "c") .. eid)
        local packed = key and self.placeEntity[key]
        if packed then
            local f = { strsplit(SEP, packed) }
            -- The client's own language where a PlaceNames file named it, else the English name;
            -- englishName is always the English one, for matching against other English data.
            local row = { kind = kind, id = tonumber(eid), name = self.placeName[key] or f[1],
                          englishName = f[1], places = {} }
            if kind == "object" then row.profession = f[2] or "" else row.side = f[2] or "" end
            local pct = tonumber(chance)
            if k == "q" then
                row.questID, pct = pct, nil
            end
            if pct then
                row.chance = math.abs(pct)
                if pct < 0 then row.questOnly = true end
            end
            if cond ~= "" then
                local skill = tonumber(cond:match("^s(%d+)$"))
                row.condition = skill and "skill" or PLACE_CONDITION[cond] or "other"
                row.conditionSkill = skill
            end
            for i = 3, #f do
                local place = unpackPlace(f[i])
                if place then row.places[#row.places + 1] = place end
            end
            out[#out + 1] = row
        end
    end
    if #out == 0 then return nil end
    return out
end

-- Whether any profession uses this item as a crafting material. The cheap gate for a tooltip
-- hook, which asks this of every item the player looks at and should not build a table to
-- find out. nil data means "we ship no reagent table for this version", never "not a reagent".
function lib:IsReagent(itemID)
    return self.reagentUses[tonumber(itemID) or itemID] ~= nil
end

-- The mutual-exclusion slot a consumable buff occupies ("agility-elixir" / "flask" / "food" / …), or
-- nil if ungrouped. "One active per group" — a buffs planner shows one slot per group. From WoWSims.
function lib:GetConsumableGroup(id)
    return self.consumableGroup[tonumber(id) or id]
end

-- The stats a buff spell grants: { cat, name, exclGroup, stats = { KEY=val, ... } } (stats decoded
-- like GetStats), or nil. One rank; use GetAuraBuffs for every rank of a buff.
function lib:GetAuraBuff(spellID)
    local b = self.auraBuffs[spellID]
    if not b then return nil end
    local stats = decodeStats(b.blob)
    return { cat = b.cat, name = b.name, exclGroup = self.auraGroup[b.name],
             stats = stats, slots = splitAuraStats(self, b.name, stats) }
end

-- Every rank of a named buff: { cat, name, exclGroup, ranks = { { spellID, stats }, ... } } sorted
-- low -> high (so ranks[#ranks] is the max rank), or nil. A consumer serves whichever rank it wants.
function lib:GetAuraBuffs(name)
    local ids = self.auraBuffsByName[name]
    if not ids then return nil end
    local ranks, cat = {}, nil
    for _, sid in ipairs(ids) do
        local b = self.auraBuffs[sid]
        cat = b.cat
        local stats, total = decodeStats(b.blob), 0
        for _, v in pairs(stats) do total = total + v end
        ranks[#ranks + 1] = { spellID = sid, stats = stats, _t = total,
                              slots = splitAuraStats(self, name, stats) }
    end
    table.sort(ranks, function(a, b) return a._t < b._t end)
    for _, r in ipairs(ranks) do r._t = nil end
    return { cat = cat, name = name, exclGroup = self.auraGroup[name], ranks = ranks }
end

-- The mutual-exclusion slot a BUFF AURA occupies ("blessing-of-kings" / "sayges-fortune" / …), or
-- nil. The aura counterpart of GetConsumableGroup, keyed by buff NAME because every rank shares
-- the slot. Two buffs answering the same token cannot both be active, so a planner offers the pair
-- once: Blessing of Kings and Greater Blessing of Kings are one slot, and so are the eight Sayge's
-- Dark Fortunes. nil means no source names a slot for that buff -- UNKNOWN, not "stacks with
-- everything" -- which today is only the hunter aspects. MINOR 31.
function lib:GetAuraGroup(name)
    return self.auraGroup[name]
end

-- EVERY mutual-exclusion slot a buff occupies, its GetAuraGroup slot first and any extra slots
-- after it in name order -- e.g. { "spell-power-pct", "crit" } for Mists Arcane Brilliance. nil
-- when the buff has no slot at all (as GetAuraGroup). A planner holding a buff should treat ALL
-- of these as filled, and read each slot's stats from the `slots` field of GetAuraBuff /
-- GetAuraBuffs ranks, which is present only for a buff that spans more than one slot. MINOR 39.
function lib:GetAuraSlots(name)
    local primary = self.auraGroup[name]
    if not primary then return nil end
    local out, extra = { primary }, {}
    for slot in pairs(self.auraSlotKeys[name] or {}) do extra[#extra + 1] = slot end
    table.sort(extra)
    for _, slot in ipairs(extra) do out[#out + 1] = slot end
    return out
end

-- The buff categories present, sorted — e.g. { "raid", "self", "totem", "world" }. For a picker that
-- lists buffs by section without hardcoding which buffs exist.
function lib:GetBuffCategories()
    local out = {}
    for cat in pairs(self.auraBuffsByCat) do out[#out + 1] = cat end
    table.sort(out)
    return out
end

-- Every buff in a category, as { { cat, name, exclGroup, ranks }, … } (each the GetAuraBuffs shape),
-- sorted by name. So a consumer enumerates all world/raid/… buffs straight from the DB instead of a
-- hand-kept list, and groups the rows by exclGroup to offer one pick per slot.
function lib:GetBuffsInCategory(cat)
    local names = self.auraBuffsByCat[cat]
    if not names then return {} end
    local out = {}
    for name in pairs(names) do out[#out + 1] = self:GetAuraBuffs(name) end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- A class's full talent tree structure: { [tab] = { id, name, talents = { [index] =
-- {tier,column,maxRank,name,spellID,prereq} } } }, or nil if talent data isn't loaded for it. A
-- consumer renders a planner from this for ANY class — not just the logged-in one the live API knows.
function lib:GetTalentTree(classID)
    return self.talents[tonumber(classID) or classID]
end

-- The class IDs that have talent data, sorted — for a class picker in an offline planner.
function lib:GetTalentClasses()
    local out = {}
    for cid in pairs(self.talents) do out[#out + 1] = cid end
    table.sort(out)
    return out
end

-- The stats a talent grants AT a given rank: { stats = { KEY=val, … }, weapons = { "Axe", … } | nil },
-- or nil if that talent/rank grants no whole-character sheet modifier. `stats` decodes like GetStats
-- (PCT_<STAT> keys are percents the consumer applies multiplicatively). `weapons` (when present) means
-- the effect only applies while wielding one of those weapon types (match against GetItemType). Only
-- passive talents have effects here; actives, granted buffs, spell-property mods and procs are absent.
function lib:GetTalentEffect(classID, tab, index, rank)
    local c = self.talentEffects[tonumber(classID) or classID]
    local t = c and c[tab] and c[tab][index]
    local blob = t and t[rank]
    if not blob or blob == "" then return nil end
    local out = { stats = decodeStats(blob) }
    if t.weapons then
        local w = {}
        for name in t.weapons:gmatch("[^,]+") do w[#w + 1] = name end
        out.weapons = w
    end
    return out
end

-- The magic school(s) an item's spell-damage bonus is restricted to, as a set { fire = true, ... },
-- or nil when the item has no school-specific spell damage (generic +spell damage, or none). A
-- consumer gates spell-damage EP with this: credit it only when the player's spell school matches —
-- a +Fire off-hand should score for a fire mage, not for a frost mage or a shadow priest.
function lib:GetItemSchools(id)
    local blob = self.spellSchools[id]
    if not blob then return nil end
    local out = {}
    for tok in blob:gmatch("[^,]+") do out[tok] = true end
    return out
end

-- An equippable's ON-USE effects: { {k,m,d,cd}, ... } (k=stat, m=magnitude,
-- d=buff seconds, cd=cooldown seconds), or nil. For display ("Use: +280 AP,
-- 20s / 2m") and scoring; GetItemScore already folds these into EP.
function lib:GetUseEffect(id) return self.useEffects[id] end

-- An equippable's chance-on-hit proc effects (where a rate is known):
-- { {b,k,m,d,ppm|ch,icd,st,sc,pm[,ws]}, ... }, or nil (fields: the procEffects note at the top). GetItemScore already folds these into EP.
function lib:GetProcEffect(id) return self.procEffects[id] end

--- GetRecipeItem / GetRecipeItems / GetRecipeScrollPrefix / GetSyntheticRecipeScroll moved to
--- LibProfessionDB-1.0 (MINOR 8) on 2026-08-06, with their data and builder. Call that library
--- for "which item teaches this recipe", then this one's GetLink/GetName on the id it returns.

--- AttachExternalRecipeInfo, and every other third-party bridge, now lives in
--- Integrations.lua. Kept out of this file because that list is expected to grow and each
--- entry is someone else's semi-public surface with its own failure modes.

-- True if the item has an on-use/proc effect not yet reflected in its EP (a ramp,
-- a chance-on-hit proc, or a non-stat effect). Consumers can flag these / avoid
-- hiding a known-BiS trinket that scores low only because its proc isn't modelled.
function lib:HasUnscoredProc(id) return self.unscoredProc[id] == true end

-- Reconstructed, fully coloured, interactive item link.
function lib:GetLink(id)
    local _, q = unpackCore(self.core[id])
    if not q then return nil end
    return buildLink(id, q, self.names[id])
end

function lib:HasItem(id) return self.core[id] ~= nil end

-- ---------------------------------------------------------------------------
-- Name -> id. Exact, case-insensitive. First match (names aren't unique).
-- ---------------------------------------------------------------------------
function lib:GetID(name)
    if not name then return nil end
    local target = name:lower()
    for id, n in pairs(self.names) do
        if n:lower() == target then return id end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Category enumeration
-- ---------------------------------------------------------------------------
function lib:GetClasses()
    local out = {}
    for classID, n in pairs(self.classCounts) do
        out[#out + 1] = { id = classID, name = className(classID), count = n }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function lib:GetSubClasses(classID)
    local seen, out = {}, {}
    for _, s in pairs(self.core) do
        local class, _, sub = unpackCore(s)
        if class == classID and not seen[sub] then
            seen[sub] = true
            out[#out + 1] = { id = sub, name = subClassName(classID, sub) }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Weapon subclass -> short type name (the game's subClassName is verbose: "One-Handed Swords").
local WEAPON_TYPE = {
    [0] = "Axe", [1] = "Axe", [2] = "Bow", [3] = "Gun", [4] = "Mace", [5] = "Mace",
    [6] = "Polearm", [7] = "Sword", [8] = "Sword", [10] = "Staff", [13] = "Fist Weapon",
    [15] = "Dagger", [16] = "Thrown", [18] = "Crossbow", [19] = "Wand",
}
-- Equip slot -> type name where the subclass is uninformative (armor "Miscellaneous" for a ring /
-- held off-hand / trinket), plus a clean singular for shields and cloaks.
local SLOT_TYPE = {
    INVTYPE_FINGER = "Ring", INVTYPE_NECK = "Neck", INVTYPE_TRINKET = "Trinket",
    INVTYPE_CLOAK = "Cloak", INVTYPE_HOLDABLE = "Off-Hand", INVTYPE_SHIELD = "Shield",
    INVTYPE_BODY = "Shirt", INVTYPE_TABARD = "Tabard",
}

-- A short, always-populated display TYPE for an item, so a consumer never shows a blank Type
-- column: slot-defined items (Ring / Neck / Trinket / Cloak / Off-Hand / Shield) use the slot;
-- weapons use a short weapon-type name; everything else (armor material, consumable type, quiver,
-- arrow / bullet, bag, …) uses the game's localized subclass name. nil only for an unknown item.
function lib:GetItemType(itemID)
    local _, _, classID, subID, equipLoc = self:GetInfo(itemID)
    if not classID then return nil end
    if self.mounts[itemID] then return "Mount" end     -- Classic files these as Miscellaneous/Junk
    local slot = equipLoc and SLOT_TYPE[equipLoc]
    if slot then return slot end
    if classID == 2 then return WEAPON_TYPE[subID] or subClassName(classID, subID) end
    return subClassName(classID, subID)
end

-- ---------------------------------------------------------------------------
-- Search. opts:
--   query       substring match on name (case-insensitive)
--   loose       (MINOR 37) also ignore apostrophes, hyphens, colons and commas and fold runs of
--               spaces, on BOTH the query and the name: "eko" finds "Frostsaber E'ko". Off by
--               default, so a plain query answers exactly as before.
--   classID     restrict to one class (number) or nil
--   subClassID  restrict to one subclass (number) or nil
--   quality     restrict to one quality (number) or nil
--   stat        match items carrying this stat — a GetItemStats key or a
--               fragment of one (e.g. "STRENGTH", "CRIT", "RESISTANCE0")
--   minValue    minimum value for `stat` (requires stat; default 1)
--   minLevel/maxLevel   item-level bounds
--   max         result cap (default 300)
-- Returns an array of { id, name, quality, classID, subClassID, equipLoc,
-- itemLevel, stats, typeName, subName, link }, sorted by name, with `.capped`.
-- ---------------------------------------------------------------------------
-- Lowercase, drop ' - : , and fold whitespace runs to one space: the loose-search form of a name.
local function looseForm(s)
    return (s:lower():gsub("[',:%-]", ""):gsub("%s+", " "))
end

function lib:Search(opts)
    opts = opts or {}
    local query   = (opts.query or ""):lower()
    -- Loose names are built ONCE per name set (LoadNames drops the index), not per call: the
    -- search strip calls this on every keystroke over up to 88,259 names.
    ---@type table|nil
    local loose = (opts.loose and query ~= "" and self._looseNames) or nil
    if opts.loose and query ~= "" then
        query = looseForm(query)
        if not loose then
            loose = {}
            for id, n in pairs(self.names) do loose[id] = looseForm(n) end
            self._looseNames = loose
        end
    end
    local wantCls = opts.classID
    local wantSub = opts.subClassID
    local wantQ   = opts.quality
    local wantStat = opts.stat and opts.stat:upper() or nil
    local minVal  = opts.minValue or (wantStat and 1) or nil
    local minLvl, maxLvl = opts.minLevel, opts.maxLevel
    local max     = opts.max or 300

    local names = self.names
    local results, capped = {}, false
    for id, s in pairs(self.core) do
        -- The NAME test first, before the row is unpacked: a name query rejects almost every item,
        -- and unpacking all of them first made a miss on Mists' 88,259 items cost ~270 ms per call
        -- in plain Lua 5.1 (measured 2026-09-24), which the "Where to get it" search strip pays on
        -- every keystroke. Same results; the unpack now only happens for a name that matched.
        local name = names[id]
        local hay = name and (loose and loose[id] or name:lower())
        local nameOK = query == "" or (hay and hay:find(query, 1, true))
        local class, q, sub, equip, ilvl, blob
        if nameOK then class, q, sub, equip, ilvl, blob = unpackCore(s) end
        if nameOK
           and (not wantCls or class == wantCls)
           and (not wantSub or sub == wantSub)
           and (not wantQ   or q == wantQ)
           and (not minLvl  or ilvl >= minLvl)
           and (not maxLvl  or ilvl <= maxLvl)
           and (opts.includeHidden or not self.hidden[id]) then
            local stats = decodeStats(blob)
            -- Same layering as GetStats, and via the same helper: this used to be a second copy
            -- of that loop, ipairs sentinel and all, so the effects-only bug had to be fixed
            -- twice. One helper is what keeps the search's stat filter and the getter agreeing.
            mergeStats(stats, self.equipStats[id])
            mergeStats(stats, self.effects[id])
            local statOK = true
            if wantStat then
                statOK = false
                for k, v in pairs(stats) do
                    if k:upper():find(wantStat, 1, true) and (tonumber(v) or 0) >= minVal then
                        statOK = true; break
                    end
                end
            end
            if statOK then
                results[#results + 1] = {
                    id = id, name = name, quality = q, classID = class,
                    subClassID = sub, equipLoc = equip, itemLevel = ilvl, stats = stats,
                    typeName = className(class), subName = subClassName(class, sub),
                    link = buildLink(id, q, name),
                }
                if #results >= max then capped = true; break end
            end
        end
    end
    table.sort(results, function(a, b) return (a.name or "") < (b.name or "") end)
    results.capped = capped
    return results
end

-- ---------------------------------------------------------------------------
-- Random properties (suffixes) — keyed by the positive ItemRandomProperties ID
-- that appears in field 8 of a modern item link.
-- ---------------------------------------------------------------------------
-- name, { statLine, statLine, ... }  from a packed randomProps entry.
local function unpackProp(s)
    if not s then return nil end
    local parts = { strsplit(SEP, s) }
    local lines = {}
    for i = 2, #parts do lines[#lines + 1] = parts[i] end
    return parts[1], lines
end

-- Suffix family name ("of the Bear") -> sorted list of propIDs. Built lazily;
-- invalidated by LoadRandomProps. The same family spans many magnitude tiers,
-- so a name maps to many propIDs.
local function familyIndex(self)
    if self._familyIndex then return self._familyIndex end
    local idx = {}
    for pid, packed in pairs(self.randomProps) do
        local fname = unpackProp(packed)
        if fname then
            local list = idx[fname]
            if not list then list = {}; idx[fname] = list end
            list[#list + 1] = pid
        end
    end
    for _, list in pairs(idx) do table.sort(list) end
    self._familyIndex = idx
    return idx
end

-- Raw item string (for GameTooltip:SetHyperlink etc.); propID 0/nil -> base.
-- enchantID (MINOR 15) and the four gem ids (MINOR 15, TBC onward) are optional and
-- trailing, so two-argument callers are unaffected. Preserving an enchant matters for
-- anything that STORES a link and rebuilds it later — dropping it silently downgrades
-- the item. Vanilla has no sockets, so the gem slots are inert there.
function lib:BuildItemString(itemID, propID, enchantID, gem1, gem2, gem3, gem4)
    return itemString(itemID, propID, enchantID, gem1, gem2, gem3, gem4)
end

-- { name = "of the Bear", stats = { "+6 Stamina", "+7 Strength" } }, or nil.
function lib:GetRandomProperty(propID)
    local fname, lines = unpackProp(self.randomProps[propID])
    if not fname then return nil end
    return { name = fname, stats = lines }
end

function lib:HasRandomProperty(propID) return self.randomProps[propID] ~= nil end

-- Every random property as { id, name, stats }, sorted by id.
function lib:GetRandomProperties()
    local out = {}
    for id, packed in pairs(self.randomProps) do
        local fname, lines = unpackProp(packed)
        out[#out + 1] = { id = id, name = fname, stats = lines }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- Coloured, clickable link for a base item + random property (game renders the
-- full, correctly-scaled tooltip from it). propID 0/nil -> plain base link.
function lib:GetSuffixLink(baseID, propID, enchantID, gem1, gem2, gem3, gem4)
    local _, q = unpackCore(self.core[baseID])
    if not q then return nil end
    local base  = self.names[baseID]
    local fname = unpackProp(self.randomProps[propID])
    local fullName = (base and fname) and (base .. " " .. fname) or (base or "")
    return buildSuffixLink(baseID, propID, q, fullName, enchantID, gem1, gem2, gem3, gem4)
end

-- Resolve a base item + random property to a full descriptor. Returns nil if
-- the base id is unknown. If the propID is unknown the base is still returned
-- (propID/suffixStats nil) so callers can fall back to the live tooltip.
function lib:ResolveSuffix(baseID, propID)
    local class, q, sub, equip, ilvl, blob = unpackCore(self.core[baseID])
    if not class then return nil end
    local base = self.names[baseID]
    local fname, lines = unpackProp(self.randomProps[propID])
    local fullName = (base and fname) and (base .. " " .. fname) or (base or "")
    return {
        id = baseID, propID = (fname and propID) or nil, name = fullName,
        quality = q, classID = class, subClassID = sub, equipLoc = equip,
        itemLevel = ilvl, requiredLevel = self.reqLevel[baseID] or 0,
        stats = decodeStats(blob), suffixStats = lines,
        itemString = itemString(baseID, propID),
        link = buildSuffixLink(baseID, propID, q, fullName),
    }
end

-- Resolve a full display name, with or without a random suffix:
--   "Black Lotus"               -> the base item (exact match)
--   "Demon Blade of the Eagle"  -> base "Demon Blade" + family "of the Eagle"
-- A suffix family spans many magnitude tiers and the tier is set by the rolled
-- item, not the name, so for a suffixed name the result carries the matched
-- family and its candidate propIDs (`propIDs`) rather than one propID. Returns
-- nil if no base item matches.
function lib:ResolveName(fullName)
    if not fullName or fullName == "" then return nil end
    local id = self:GetID(fullName)
    if id then
        local class, q, sub, equip, ilvl, blob = unpackCore(self.core[id])
        return {
            id = id, name = self.names[id], quality = q, classID = class,
            subClassID = sub, equipLoc = equip, itemLevel = ilvl,
            stats = decodeStats(blob), link = buildLink(id, q, self.names[id]),
        }
    end
    for fname, propIDs in pairs(familyIndex(self)) do
        local tail = " " .. fname
        if #fullName > #tail and fullName:sub(-#tail) == tail then
            local baseID = self:GetID(fullName:sub(1, #fullName - #tail))
            if baseID then
                local class, q, sub, equip, ilvl, blob = unpackCore(self.core[baseID])
                return {
                    id = baseID, name = fullName, suffixName = fname, propIDs = propIDs,
                    quality = q, classID = class, subClassID = sub, equipLoc = equip,
                    itemLevel = ilvl, stats = decodeStats(blob),
                }
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Drop sources — which instance / boss drops an item, and the reverse.
-- ---------------------------------------------------------------------------
function lib:HasSourceData() return next(self.srcItems) ~= nil end
function lib:HasSources(itemID)
    return self.srcItems[itemID] ~= nil or self.itemLoc[itemID] ~= nil
end

-- Where an item comes from: array of { instanceKey, instance, boss, encounterID,
-- source }, one entry per origin. For boss drops (AtlasLoot graph) instance/boss are
-- localized names (nil if this locale's SourceNames aren't loaded) and instanceKey is
-- the stable key used by GetInstanceItems / GetInstanceEncounters. For the CMaNGOS
-- locations (quest/vendor/crafted/pvp/reputation, and world drops the graph misses)
-- `instance` is the place and `source` is the kind, with no boss/instanceKey. Empty
-- table only for genuinely sourceless items (starter gear, unobtainable).
-- itemID -> { {source, place}, ... } from repLoot (battleground / reputation reward), lazy.
-- A reward's source is a badge like { instance = "Alterac Valley", source = "pvp" }.
local function repLootSrc(self)
    if self._repLootSrc then return self._repLootSrc end
    local KIND, idx = { pvp = "pvp", faction = "reputation" }, {}
    for kind, sources in pairs(self.repLoot) do
        local k = KIND[kind] or kind
        for place, tiers in pairs(sources) do
            for _, t in ipairs(tiers) do
                for _, iid in ipairs(t[2]) do
                    local list = idx[iid]; if not list then list = {}; idx[iid] = list end
                    list[#list + 1] = { source = k, place = place }
                end
            end
        end
    end
    self._repLootSrc = idx
    return idx
end

-- The drop chance of `itemID` from boss `encounterID`, as a percent (33), or nil when no rate
-- is known for that pair -- and nil is "unknown", never "never": a quest-gated drop, or an
-- encounter the data does not cover, answers nil. Nil-safe on either argument; the encounter
-- may be given as a number or its string.
function lib:GetDropRate(itemID, encounterID)
    if itemID == nil or encounterID == nil then return nil end
    local packed = self.dropRate[itemID]
    if not packed then return nil end
    local want = tostring(encounterID)
    for enc, rate in packed:gmatch("([^:,]+):([^,]+)") do
        if enc == want then return tonumber(rate) end
    end
    return nil
end

-- The items `itemID` can be turned in for, as a FRESH table of item ids sorted ascending, or nil
-- when the item is not a token -- never an empty table. Every class's rewards are listed; read
-- each one's level with GetItemLevel and its slot as GetInfo's 5th return (equipLoc). MINOR 44.
function lib:GetTokenRewards(itemID)
    local packed = itemID and self.tokenRewards[tonumber(itemID)]
    if not packed then return nil end
    local out = {}
    for id in packed:gmatch("%d+") do out[#out + 1] = tonumber(id) end
    if #out == 0 then return nil end
    table.sort(out)
    return out
end

function lib:GetSources(itemID)
    local out, seen = {}, {}
    local packed = self.srcItems[itemID]
    if packed then
        for encStr in packed:gmatch("[^,]+") do
            local enc = tonumber(encStr)
            if enc and not seen[enc] then
                seen[enc] = true
                local inst = self.srcEncInst[enc]
                out[#out + 1] = {
                    encounterID = enc,
                    boss        = self.srcEncName[enc],
                    instanceKey = inst,
                    instance    = inst and self.srcInstName[inst] or nil,
                    source      = inst and self.srcProv[inst] or nil,
                    -- percent, present only when a rate is known for THIS boss (MINOR 27)
                    rate        = self:GetDropRate(itemID, enc),
                }
            end
        end
    end
    local locs = self.itemLoc[itemID]
    if locs then
        -- Show each place once. The boss graph may list an instance several times (one
        -- row per boss) and those stand; but a CMaNGOS location whose place is already
        -- shown — by the boss graph, or by an earlier location (drop + reputation in the
        -- same instance) — is redundant for a location badge, so collapse it.
        local seenInst = {}
        for _, s in ipairs(out) do if s.instance then seenInst[s.instance] = true end end
        for _, e in ipairs(locs) do
            local loc, kind = e[1], e[2]
            if not seenInst[loc] then
                seenInst[loc] = true
                out[#out + 1] = { instance = loc, source = kind }
            end
        end
    end
    -- battleground / reputation rewards (AtlasLoot) CMaNGOS's vendor data can't see
    local rep = repLootSrc(self)[itemID]
    if rep then
        local seenInst = {}
        for _, s in ipairs(out) do if s.instance then seenInst[s.instance] = true end end
        for _, r in ipairs(rep) do
            if not seenInst[r.place] then
                seenInst[r.place] = true
                out[#out + 1] = { instance = r.place, source = r.source }
            end
        end
    end
    return out
end

-- instanceKey -> sorted array of every itemID that drops in that instance.
-- Built lazily from srcItems; invalidated by LoadSources.
local function srcInstItems(self)
    if self._srcInstItems then return self._srcInstItems end
    local sets = {}
    for itemID, packed in pairs(self.srcItems) do
        for encStr in packed:gmatch("[^,]+") do
            local inst = self.srcEncInst[tonumber(encStr) or -1]
            if inst then
                local s = sets[inst]
                if not s then s = {}; sets[inst] = s end
                s[itemID] = true
            end
        end
    end
    local out = {}
    for inst, s in pairs(sets) do
        local arr = {}
        for iid in pairs(s) do arr[#arr + 1] = iid end
        table.sort(arr)
        out[inst] = arr
    end
    self._srcInstItems = out
    return out
end

function lib:GetInstanceItems(instanceKey)
    return srcInstItems(self)[tonumber(instanceKey) or instanceKey] or {}
end

-- Ordered bosses of an instance: array of { encounterID, boss }.
function lib:GetInstanceEncounters(instanceKey)
    local encs = self.srcInst[tonumber(instanceKey) or instanceKey]
    if not encs then return {} end
    local out = {}
    for encStr in encs:gmatch("[^:]+") do
        local e = tonumber(encStr)
        if e then out[#out + 1] = { encounterID = e, boss = self.srcEncName[e] } end
    end
    return out
end

-- The organizing axis: array of { key, name, bosses, source }, sorted by name.
function lib:GetInstances()
    local out = {}
    for instID, encs in pairs(self.srcInst) do
        local n = 0
        for _ in encs:gmatch("[^:]+") do n = n + 1 end
        out[#out + 1] = {
            key    = instID,
            name   = self.srcInstName[instID] or ("Instance " .. instID),
            bosses = n,
            source = self.srcProv[instID],
            -- nil where the shipped data predates the tag; a consumer should read that as
            -- "current expansion", which is the flat-list behaviour it had before.
            expansion = self.srcInstExp[instID],
            -- "raid" | "dungeon", or nil for UNKNOWN. Unlike `expansion` above, absence here
            -- must NOT be defaulted to either value -- see lib.srcInstKind.
            kind = self.srcInstKind[instID],
        }
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

--- What kind of place an instance is: "raid", "dungeon", or nil when unknown.
--- Mirrors GetAuraGroup: the per-key accessor beside the field on the list rows, so a consumer
--- holding one key does not have to walk GetInstances to classify it.
---
--- NIL IS AN ANSWER AND IT MEANS UNKNOWN. Do not read it as "not a raid". A version whose data
--- carries no classification (Mists today) returns nil for every instance, and a consumer that
--- treats that as a negative silently reclassifies every raid on that flavour.
--- @param instanceKey string|number the key from GetInstances()[i].key or GetSources()
--- @return string|nil kind "raid" | "dungeon", or nil when the shipped data does not say
function lib:GetInstanceKind(instanceKey)
    if instanceKey == nil then return nil end
    return self.srcInstKind[instanceKey] or self.srcInstKind[tonumber(instanceKey) or instanceKey]
end

-- ---------------------------------------------------------------------------
-- Loot browser — a uniform grouped-loot view (module -> categories -> sections
-- -> items) so a consumer renders every source the same way, one code path. Backed
-- by Sources (instances/bosses), RepLoot (battleground + reputation reward tiers) and
-- Sets (collections). Crafting (professions) lives in a sibling DB, so this API
-- advertises only the modules THIS client can populate.
-- ---------------------------------------------------------------------------

-- encounterID -> sorted itemID array (per-boss loot), lazy, from srcItems.
local function srcEncItems(self)
    if self._srcEncItems then return self._srcEncItems end
    local sets = {}
    for itemID, packed in pairs(self.srcItems) do
        for encStr in packed:gmatch("[^,]+") do
            local e = tonumber(encStr)
            if e then local s = sets[e]; if not s then s = {}; sets[e] = s end; s[itemID] = true end
        end
    end
    local out = {}
    for e, s in pairs(sets) do
        local arr = {}
        for iid in pairs(s) do arr[#arr + 1] = iid end
        table.sort(arr)
        out[e] = arr
    end
    self._srcEncItems = out
    return out
end

-- The source modules the browser can offer here: array of { key, name }. Only modules with
-- data are returned, so a consumer shows exactly the ones that light up (ship incrementally).
function lib:GetLootModules()
    local out = {}
    if next(self.srcInst) then out[#out + 1] = { key = "instances", name = "Dungeons & Raids" } end
    if self.repLoot.faction and next(self.repLoot.faction) then out[#out + 1] = { key = "factions", name = "Factions" } end
    if self.repLoot.pvp and next(self.repLoot.pvp) then out[#out + 1] = { key = "pvp", name = "PvP" } end
    if next(self.sets) then out[#out + 1] = { key = "collections", name = "Collections" } end
    return out
end

-- Subcategories within a module (the second dropdown): array of { key, name }, sorted. The `key`
-- is what a consumer passes back to GetLootSections. Instances -> each instance; factions -> each
-- faction; pvp -> each battleground; collections -> "Class Sets".
function lib:GetLootCategories(moduleKey)
    local out = {}
    if moduleKey == "instances" then
        for _, inst in ipairs(self:GetInstances()) do
            out[#out + 1] = { key = inst.key, name = inst.name }
        end
    elseif moduleKey == "factions" or moduleKey == "pvp" then
        local grp = self.repLoot[moduleKey == "factions" and "faction" or "pvp"]
        if grp then for name in pairs(grp) do out[#out + 1] = { key = name, name = name } end end
        table.sort(out, function(a, b) return a.name < b.name end)
    elseif moduleKey == "collections" then
        if next(self.sets) then out[#out + 1] = { key = "class_sets", name = "Class Sets" } end
    end
    return out
end

-- The loot in (module, category), grouped into sections { header, items = { itemID, ... } } in
-- display order. `header = ""` when the category has no sub-grouping. Instances -> one section per
-- boss in kill order; factions/pvp -> one section per reputation tier (Exalted..Friendly, as the
-- rewards are earned); collections -> one section per set (header = set name).
function lib:GetLootSections(moduleKey, categoryKey)
    local out = {}
    if moduleKey == "instances" then
        local encItems = srcEncItems(self)
        for _, e in ipairs(self:GetInstanceEncounters(categoryKey)) do
            out[#out + 1] = { header = e.boss or "", items = encItems[e.encounterID] or {} }
        end
    elseif moduleKey == "factions" or moduleKey == "pvp" then
        local grp = self.repLoot[moduleKey == "factions" and "faction" or "pvp"]
        local tiers = grp and grp[categoryKey]
        if tiers then
            for _, t in ipairs(tiers) do out[#out + 1] = { header = t[1], items = t[2] } end
        end
    elseif moduleKey == "collections" and categoryKey == "class_sets" then
        local list = {}
        for _, s in pairs(self.sets) do list[#list + 1] = { name = s.name, items = s.items } end
        table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
        for _, s in ipairs(list) do out[#out + 1] = { header = s.name or "", items = s.items or {} } end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Item sets + set bonuses.
-- ---------------------------------------------------------------------------
-- setID, setName for an item (nil if it isn't part of a set).
function lib:GetItemSet(itemID)
    local sid = self.itemSet[itemID]
    if not sid then return nil end
    return sid, self.sets[sid] and self.sets[sid].name
end

-- { id, name, items = {id,...}, bonuses = { [pieces] = { KEY=val } },
--   procs = { [pieces] = { {b,k,m,d,ppm|ch,icd,st,sc,pm}, ... } } (nil if the set has none) }, or nil.
-- `bonuses[n]` with an empty table is a bonus we don't score as a flat stat (a proc, if any,
-- is under `procs[n]`; otherwise a complex bonus we can't value). `procs` rows match the
-- chance-on-hit format: b=bucket (buff/damage/heal/mana), k=stat key (buff only), m=magnitude,
-- d=buff seconds, ppm XOR ch=rate, icd, st=max stacks, sc=trigger scope. Set rows never carry
-- `ws`: tools/build-sets.py does not run build-use-effects' proc_window(), so a stacking-window
-- set bonus would ship as a plain buff row (scoreProcEffects would price a ws if one appeared). GetItemScore already
-- folds both bonuses and procs into the amortized set-bonus EP; this is for DISPLAY.
function lib:GetSet(setID)
    local s = self.sets[setID]
    if not s then return nil end
    local bonuses = {}
    for n, blob in pairs(s.bonuses) do bonuses[n] = decodeStats(blob) end
    return { id = setID, name = s.name, items = s.items, bonuses = bonuses, procs = s.procs }
end

-- Merged flat stats a set grants at `pieces` worn (every threshold <= pieces) —
-- what a set piece is worth beyond its own stats, for EP that accounts for sets.
function lib:GetSetBonusStats(setID, pieces)
    local s = self.sets[setID]
    local out = {}
    if not s then return out end
    for n, blob in pairs(s.bonuses) do
        if (tonumber(n) or 999) <= (pieces or 0) then
            for k, v in pairs(decodeStats(blob)) do out[k] = (out[k] or 0) + v end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Faction restriction (Alliance / Horde items).
-- ---------------------------------------------------------------------------
-- "Alliance" / "Horde", or nil if the item is usable by both factions.
function lib:GetItemFaction(itemID)
    local f = self.itemFaction[itemID]
    return (f == "A" and "Alliance") or (f == "H" and "Horde") or nil
end

-- The player's faction ("Alliance" / "Horde"), or nil if unknown.
function lib:GetPlayerFaction()
    return (_UnitFactionGroup and _UnitFactionGroup("player")) or nil
end

-- True if the player can use the item (neutral, unknown faction, or same side).
function lib:FactionUsable(itemID)
    local f = self.itemFaction[itemID]
    if not f then return true end
    local p = self:GetPlayerFaction()
    if not p then return true end
    return (f == "A") == (p == "Alliance")
end

-- The reputation an item needs to buy or use (MINOR 47): factionID (the client's, as
-- GetFactionInfoByID takes it) and minStanding (the client's 1-8 reaction index: 5 Friendly,
-- 6 Honored, 7 Revered, 8 Exalted). nil when it needs none, or for a non-number id.
function lib:GetRequiredReputation(itemID)
    if type(itemID) ~= "number" then return nil end
    local n = self.itemRep[itemID]
    if not n then return nil end
    return math.floor(n / 16), n % 16
end

-- The class bitmask an item is restricted to (bit = 1 << (classID-1)), or nil if
-- any class can use it. build-classes.py corrects the mis-flagged dungeon/AQ40/T3
-- sets + Atiesh, so e.g. every Bonescythe piece reads as Rogue-only here.
function lib:GetItemClasses(itemID)
    return self.classReq[itemID]
end

-- The player's classID (3rd return of UnitClass), or nil if unavailable.
function lib:GetPlayerClass()
    return _UnitClass and select(3, _UnitClass("player")) or nil
end

-- True if the given (or player's) class can use the item — unrestricted items, an
-- unknown class, or a class whose bit is set. classID is the numeric class id.
function lib:ClassUsable(itemID, classID)
    local mask = self.classReq[itemID]
    if not mask then return true end
    classID = classID or self:GetPlayerClass()
    if not classID then return true end
    local bit = 2 ^ (classID - 1)
    return mask % (bit + bit) >= bit   -- no bit ops in 5.1: test bit via modulo
end

-- The race mask an item is restricted to, as TWO 32-bit halves: `low, high`, or nil if
-- any race can use it (MINOR 30). On Vanilla and TBC `high` is always nil — the mask fits
-- the low word — so a consumer on those flavours reads the first return exactly as
-- `GetItemClasses` is read. `high` is non-nil only on a client whose race ids exceed 32:
-- Forever's ChrRaces reaches id 96 and its faction masks set bits up to 64, which is the
-- whole reason this is not one number (a Lua 5.1 double cannot hold 6130900294268439629).
-- Prefer RaceUsable unless you are rendering the mask itself.
function lib:GetItemRaces(itemID)
    local packed = self.raceReq[itemID]
    if not packed then return nil end
    local lo, hi = strsplit(":", packed)
    return tonumber(lo), tonumber(hi or "")
end

-- The player's raceID (3rd return of UnitRace), or nil if unavailable.
function lib:GetPlayerRace()
    return _UnitRace and select(3, _UnitRace("player")) or nil
end

-- True if the given (or player's) race can use the item — unrestricted items, an unknown
-- race, or a race whose bit is set. Fails OPEN exactly like ClassUsable and FactionUsable:
-- a filter must never hide gear a player can really use, so "no data" answers true and is
-- deliberately indistinguishable from "anyone may use it". Ask GetItemRaces and test for nil
-- if you need to tell those apart.
function lib:RaceUsable(itemID, raceID)
    local lo, hi = self:GetItemRaces(itemID)
    if not lo then return true end
    raceID = raceID or self:GetPlayerRace()
    if not raceID then return true end
    -- Race 33+ lives in the high word; the low word holds 1..32. Splitting here rather than
    -- doing 64-bit arithmetic is what keeps every value inside a double's exact range.
    local mask = raceID > 32 and (hi or 0) or lo
    local bit = 2 ^ ((raceID > 32 and raceID - 32 or raceID) - 1)
    return mask % (bit + bit) >= bit   -- no bit ops in 5.1: test bit via modulo
end

-- ---------------------------------------------------------------------------
-- Proficiency: which armour MATERIAL a class may wear, who may hold a SHIELD, which WEAPON
-- types each class can wield. `ClassUsable` above answers the item's class TAG (the mask
-- from Classes.lua); this answers the class's TRAINING. A hunter and a mace: the tag says
-- nothing, the proficiency says no. Questbook's contract of 2026-09-18 (MINOR 27), after
-- three addons -- Dibs Data/ItemSources.lua, TOGBankClassic Modules/Usable.lua, Questbook
-- Modules/RewardsIndex.lua -- had each grown a copy of these tables with nothing asserting
-- they agreed. The values are the fleet's current best answer, pinned by TOGBank's
-- Tests/usable_spec.lua and now by Tests/libitemdb_spec.lua; they were NOT read from the
-- client (the client keeps proficiency as learned spells, not item data). Ids are the
-- client's own enums, checked against the Classic Era ItemConstantsDocumentation:
-- ItemArmorSubclass 1 Cloth 2 Leather 3 Mail 4 Plate 6 Shield; ItemWeaponSubclass 0 Axe1H
-- 1 Axe2H 2 Bows 3 Guns 4 Mace1H 5 Mace2H 6 Polearm 7 Sword1H 8 Sword2H 10 Staff 13 fist
-- ("Unarmed") 15 Dagger 16 Thrown 18 Crossbow 19 Wand.
-- Vanilla and TBC share these tables. A class the tables do not know (Wrath's Death Knight)
-- fails OPEN, so a Wrath client answers true for it until the table is extended.
-- ---------------------------------------------------------------------------
local function idset(...)
    local t = {}
    for i = 1, select("#", ...) do t[select(i, ...)] = true end
    return t
end

-- Max armour subclass a class wears (Cloth 1 < Leather 2 < Mail 3 < Plate 4).
local CLASS_ARMOR = {
    [1] = 4, [2] = 4,           -- Warrior, Paladin: Plate
    [3] = 3, [7] = 3,           -- Hunter, Shaman: Mail
    [4] = 2, [11] = 2,          -- Rogue, Druid: Leather
    [5] = 1, [8] = 1, [9] = 1,  -- Priest, Mage, Warlock: Cloth
}
-- Mail (Hunter, Shaman) and Plate (Warrior, Paladin) are trained at level 40; below it the cap
-- is one tier down. Without the step a level-13 hunter's mail drop reads as usable.
local ARMOR_TRAINED_AT_40 = { [1] = 4, [2] = 4, [3] = 3, [7] = 3 }
-- Classes that can equip a shield (armour subclass 6).
local CLASS_SHIELD = { [1] = true, [2] = true, [7] = true }
-- Weapon subclass ids each class can wield.
local CLASS_WEAPONS = {
    [1]  = idset(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),  -- Warrior: everything but wands
    [2]  = idset(0, 1, 4, 5, 6, 7, 8),                            -- Paladin: axe/mace/sword 1H+2H, polearm
    [3]  = idset(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),        -- Hunter: no mace, no wand
    [4]  = idset(0, 2, 3, 4, 7, 13, 15, 16, 18),                  -- Rogue: 1H only; no polearm/staff/wand
    [5]  = idset(4, 10, 15, 19),                                  -- Priest: 1H mace, staff, dagger, wand
    [7]  = idset(0, 1, 4, 5, 10, 13, 15),                         -- Shaman: axe/mace 1H+2H, staff, fist, dagger
    [8]  = idset(7, 10, 15, 19),                                  -- Mage: 1H sword, staff, dagger, wand
    [9]  = idset(7, 10, 15, 19),                                  -- Warlock: 1H sword, staff, dagger, wand
    [11] = idset(4, 5, 6, 10, 13, 15),                            -- Druid: mace 1H+2H, polearm, staff, fist, dagger
}
-- equipLocs that ARE body armour, bound by material. Cloak / neck / finger / trinket / held /
-- relic are armour class 4 too, but everyone wears them, so they are not here.
local BODY_ARMOR_LOC = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
    INVTYPE_WRIST = true, INVTYPE_HAND = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
}
-- The tables, readable: a consumer building "which weapons can my class use" reads these
-- rather than copying them, which is the whole point. Treat as constants.
lib.PROFICIENCY = {
    armorCap = CLASS_ARMOR, armorTrainedAt40 = ARMOR_TRAINED_AT_40, shield = CLASS_SHIELD,
    weapons = CLASS_WEAPONS, bodyArmorLoc = BODY_ARMOR_LOC,
}

-- The player's level from the client, or nil if it cannot say (no unit API offline).
function lib:GetPlayerLevel()
    return _UnitLevel and _UnitLevel("player") or nil
end

-- The armour material `classID` may wear at `level` (1 Cloth .. 4 Plate); nil for a class the
-- table does not know. nil level = the trained cap (no level rule).
function lib:GetArmorCap(classID, level)
    local cap = CLASS_ARMOR[classID]
    if not cap then return nil end
    if ARMOR_TRAINED_AT_40[classID] and level and level < 40 then return cap - 1 end
    return cap
end

-- Does `classID` have the ARMOUR / SHIELD / WEAPON proficiency for an item of
-- (itemClassID, subClassID, equipLoc) at `level`? Pure; no item lookup. True unless the class
-- demonstrably lacks the training: anything that is not armour or a weapon passes, a class the
-- tables do not know passes, a nil class passes, and a NIL subclass passes (fail open -- an
-- item nothing has info for must not be hidden). Subclass 0 is a REAL value (1H axe; generic
-- armour), never "unknown". Ids arrive as numbers or numeric strings.
function lib:ClassProficient(classID, itemClassID, subClassID, equipLoc, level)
    if not classID then return true end
    itemClassID, subClassID = tonumber(itemClassID), tonumber(subClassID)
    if itemClassID == 4 then                                      -- armour
        if subClassID == 6 then                                   -- shield
            -- A class the tables do not know fails open here too. CLASS_SHIELD is a positive
            -- list, so without this guard a Death Knight (6) read as "no shield" while the
            -- material and weapon branches read as "no opinion" -- the asymmetry TOGBank's
            -- reference carried and a second ItemDB session caught on 2026-09-18.
            if not CLASS_ARMOR[classID] then return true end
            return CLASS_SHIELD[classID] == true
        elseif BODY_ARMOR_LOC[equipLoc] then                      -- body armour: material cap
            local cap = self:GetArmorCap(classID, level)
            return not (cap and (subClassID or 0) > cap)
        end
    elseif itemClassID == 2 then                                  -- weapon
        local allowed = CLASS_WEAPONS[classID]
        if allowed and subClassID and not allowed[subClassID] then return false end
    end
    return true
end

-- Can `classID` (default: the player) at `level` (default: the player's) use the item: its
-- class TAG (ClassUsable) AND the class's proficiency for its class / subclass / slot.
-- Deliberately NOT the required level (a consumer decides whether "not yet" means "not for
-- me") and NOT faction (FactionUsable is separate; a guild bank must not apply it). An item
-- the database does not know answers true, the same fail-open rule as everything above.
function lib:CanUse(itemID, classID, level)
    classID = classID or self:GetPlayerClass()
    if not self:ClassUsable(itemID, classID) then return false end
    local _, _, itemClassID, subClassID, equipLoc = self:GetInfo(itemID)
    if level == nil then level = self:GetPlayerLevel() end
    return self:ClassProficient(classID, itemClassID, subClassID, equipLoc, level)
end

-- ---------------------------------------------------------------------------
-- Best-in-Slot — a provider model. The lib ships "wowsims"; any addon or the
-- user can LoadBiS its own list under another source name and make it default.
-- Opinion data (sim-driven, dated per phase), not factual like drops.
-- ---------------------------------------------------------------------------
-- Register/merge a named BiS provider. data =
--   { [classID] = { [spec] = { [phase] = { [SLOT] = itemID } } } }
-- The first source loaded becomes the default (until SetDefaultBiSSource). Merges.
function lib:LoadBiS(source, data)
    if type(source) ~= "string" or type(data) ~= "table" then return end
    local bucket = self.bis[source]
    if not bucket then bucket = {}; self.bis[source] = bucket end
    for classID, specs in pairs(data) do
        local c = bucket[classID]; if not c then c = {}; bucket[classID] = c end
        for spec, phases in pairs(specs) do
            local sp = c[spec]; if not sp then sp = {}; c[spec] = sp end
            for phase, set in pairs(phases) do sp[phase] = set end
        end
    end
    if self.bisDefault == nil then self.bisDefault = source end
    self._bisIndex = nil   -- invalidate the reverse (itemID -> uses) index
end

local function bisSource(self, source)
    return source or self.bisDefault or "wowsims"
end

-- EP weights have their own default (a player's custom scale, else HawsJon).
local function weightSource(self, source)
    return source or self.bisWeightsDefault or "hawsjon"
end

-- Register/merge a named EP weight provider. data =
--   { [classID] = { [spec] = { statKey = weight } } }
-- `meta` is OPTIONAL provenance, { authoredFor = "<Version>" } — the game version the scale
-- was tuned against, which is not always the one it is loaded on. Third argument on purpose:
-- every existing caller passes two and keeps working, and a scale with no meta simply reports
-- none rather than claiming a version it cannot vouch for.
function lib:LoadBiSWeights(source, data, meta)
    if type(source) ~= "string" or type(data) ~= "table" then return end
    local bucket = self.bisWeights[source]
    if not bucket then bucket = {}; self.bisWeights[source] = bucket end
    for classID, specs in pairs(data) do
        local c = bucket[classID]; if not c then c = {}; bucket[classID] = c end
        for spec, w in pairs(specs) do
            c[spec] = w
            if type(w) == "table" then self.bisWeightsSpec[w] = { classID, spec } end
        end
    end
    if type(meta) == "table" and type(meta.authoredFor) == "string" then
        local m = self.bisWeightsMeta[source]
        if not m then m = {}; self.bisWeightsMeta[source] = m end
        m.authoredFor = meta.authoredFor
    end
    if self.bisWeightsDefault == nil then self.bisWeightsDefault = source end
end

-- Provenance for a weight scale: { source = "hawsjon", authoredFor = "Vanilla" }, or nil
-- when nothing by that name is loaded. `authoredFor` is nil for a scale that declared none
-- (a player's own, loaded through LoadBiSWeights with two arguments) — nil means UNKNOWN,
-- never "matches the current version". Omit `source` for the active default.
--
-- This reports FACTS, not a verdict: compare `authoredFor` against the version you are
-- running and decide for yourself what to tell the player. The library deliberately does not
-- decide whether a mismatch matters.
--
-- A PER-STAT `notApplicable` LIST WAS BUILT HERE AND BACKED OUT, which is worth a line so it is
-- not re-proposed. The plan was to mark the per-weapon-skill EP weights as inapplicable on
-- Forever. THERE ARE NONE TO MARK: search `Data/Forever/_core/BiSWeights.lua` for "skill" and
-- every hit is in its own header comment, never in the `lib:LoadBiSWeights` table — the melee
-- keys there are DPS_MAINHAND / HIT_PCT / CRIT_PCT and the primary stats. (Cited by NAME rather
-- than by line on purpose: the first version of this note gave a line number, and regenerating
-- the file moved it onto the LibStub guard, leaving the evidence for a "do not re-propose this"
-- comment pointing at boilerplate.)
--
-- Weapon skill is priced instead by `scoreOneWeaponSkill` in Scoring/Vanilla.lua, which reads
-- the ITEM's +N skill and values it through a miss-and-glancing model against those same
-- weights — so the exposure, if there is one, is in a scoring MODEL rather than in a weight a
-- consumer could drop, and nobody has yet checked Forever's combat constants against Classic's.
-- `authoredFor` already says the whole scale is Classic's, which is the honest statement at the
-- level the evidence supports.
function lib:GetBiSWeightsInfo(source)
    local name = weightSource(self, source)
    if not self.bisWeights[name] then return nil end
    local m = self.bisWeightsMeta[name]
    return { source = name, authoredFor = m and m.authoredFor or nil }
end

-- Register/merge OUR scoring-model constants (premium / proc rate / conversions),
-- separate from the licensed HawsJon stat weights. data = { [classID]={[spec]={..}} }.
-- Ships as source "default"; a custom scale can load its own and pass opts.source.
function lib:LoadScoreModel(source, data)
    if type(source) ~= "string" or type(data) ~= "table" then return end
    local bucket = self.scoreModel[source]
    if not bucket then bucket = {}; self.scoreModel[source] = bucket end
    for classID, specs in pairs(data) do
        local c = bucket[classID]; if not c then c = {}; bucket[classID] = c end
        for spec, m in pairs(specs) do c[spec] = m end
    end
end

-- ---------------------------------------------------------------------------
-- Scoring rules contract — how an expansion plugs its mechanics into this core
-- ---------------------------------------------------------------------------
-- EVERYTHING BELOW THIS LINE IS MECHANISM, NOT GAME RULES. The stat walk, weight lookup,
-- breakdown rows and the set/use/proc plumbing are identical in every expansion; what CHANGES
-- is the vocabulary and the rules — Vanilla prices weapon skill by an attack-table formula and
-- has no haste or expertise, TBC replaces flat percentages with combat ratings, and so on.
--
-- So this file knows nothing about any expansion. Each Scoring/<Version>.lua registers a rules
-- table and a TOC loads exactly ONE of them, which means a Vanilla client never has TBC's rules
-- in memory: enriching one expansion CANNOT regress another. Add a version by adding a file, not
-- by branching here. If you find yourself writing `if isTBC` in this file, the rule belongs in a
-- module instead.
--
--   name        string  the expansion, for GetScoringVersion / diagnostics
--   alias       { [dataKey] = weightKey }        fold a data spelling onto the weighted one
--   dpsSlot     { [equipLoc] = weightKey }       which hand a weapon's DPS is weighted as
--   apPair      { melee =, ranged = } or nil     max-pair these two instead of summing (nil = off)
--   derived     { [key] = { stat =, per = } }    price a key no scale weights, via one it does:
--                                               "per" units of `key` == 1 unit of `stat`. Vanilla
--                                               uses it for pools (10 HP == 1 Stamina); TBC for
--                                               rating conversion (1% crit == 22.08 crit rating,
--                                               so per = 1/22.08). Optional `family =`
--                                               "physical" | "melee" | "ranged" | "spell": the
--                                               attack family the key serves, for a stat whose
--                                               rating is UNIFIED (Wrath+: one crit rating buys
--                                               melee, ranged and spell crit). The conversion is
--                                               then scaled by the spec's share of that family
--                                               (familyShare below), so a spell-only % prices 0
--                                               for an arms warrior and a melee-only % prices 0
--                                               for a mage, and Burning Blossom's
--                                               CRIT_PCT=3,SPELL_CRIT_PCT=3 sums to ONE 3% crit
--                                               for any spec, never 6% (Peer Review fa38856e,
--                                               c6500056 D2/D4/D5). Applied to a stat walk, an
--                                               on-use buff and a proc buff alike (D3).
--                                               Optional `exclude =` { [classID] = { [spec] =
--                                               true } }: specs the key prices 0 for, read from
--                                               the class / spec the scale was loaded under
--                                               (MINOR 45; threat reduction for tanks/healers).
--                                               Optional `only =` the same shape, inverted: the
--                                               ONLY specs the key prices for; every other
--                                               registered spec prices it 0 (Wrath's +healing
--                                               effect rows, healers only). A scale with no
--                                               registered spec is priced, as with `exclude`.
--   spellShare  { [classID] = { [spec] = 0..1 } } optional: the share of a spec's value that
--                                               comes from SPELLS, stated outright for the
--                                               specs whose weight ratio misreads it (tanks,
--                                               hybrids -- Peer Review c27e8a07 M3). Wins over
--                                               the ratio familyShare otherwise reads off the
--                                               scale; a spec not listed keeps the ratio.
--   skipPrefix  { "PREFIX_", ... }               keys the flat walk must not price
--   skipKeys    { [key] = true }                 ditto, exact matches
--   weightStats { { key =, label = }, ... }      what a weight editor may set (GetWeightStats)
--   labels      { [key] = label }                breakdown labels for derived / non-weight rows
--   model       { usePremium, hitsPerSec, ... }  fallback scoring-model constants
--   statScorers { fn(stats, w, opts, parts), ... }  extra scorers run after the flat walk; each
--                                               returns EP and may push its own `parts` rows
--
-- A version whose module hasn't been written yet (Wrath / Cata today) simply registers nothing:
-- RULES stays nil and every scoring API returns nil, which is the documented degradation.
local RULES = nil

-- Every stat key the active rules have a VOCABULARY for, which is not the same as every key
-- they put a non-zero weight on. The difference is the point: a scale weighting Spirit at 0 is
-- a judgement, while a key the rules have never heard of is data the scorer cannot see at all,
-- and both used to add exactly 0 and emit nothing. Forever is where that bit -- its items ship
-- EXPERTISE and ARMOR_PENETRATION (from wowsims, which models a later combat system) and it
-- loads VANILLA's rules, where neither key exists because Vanilla the game has neither stat. So
-- those stats price at 0 with no error, no warning and no breakdown row. Populated on
-- registration so the check below is a table lookup rather than a scan per stat per item.
local KNOWN_STAT = {}

-- Capability flag (MINOR 29), because this adds no function for a consumer to detect: true means
-- GetItemScoreBreakdown emits `kind = "unpriced"` rows for a stat the active rules have no
-- vocabulary for. Feature-detect on this rather than pinning a MINOR.
lib.SCORE_REPORTS_UNPRICED = true

-- Capability flag (MINOR 30), same reasoning: GetItemScore and GetItemScoreBreakdown honour
-- `opts.equipLoc`, scoring an item AS the slot it is being planned into rather than the slot it
-- reports. There is no new function to detect, so detect this. Dibs' DIBSREQ-IDB-007.
lib.SCORE_OPTS_EQUIPLOC = true

-- Capability flag (MINOR 42): a flavour whose rules register lib.StatScorers.weaponDamage prices
-- WEAPON_DAMAGE (sharpening stones, weightstones) given opts.attack.weaponSpeed /
-- offhandSpeed and opts.equipLoc for the hand. Dibs' DIBSREQ-IDB-010.
lib.SCORE_WEAPON_DAMAGE = true

-- Called by Scoring/<Version>.lua. Last registration wins — only one is ever loaded per client.
function lib:RegisterScoring(rules)
    if type(rules) ~= "table" then return end
    RULES = rules
    self.scoringVersion = rules.name
    KNOWN_STAT = {}
    for _, s in ipairs(rules.weightStats or {}) do KNOWN_STAT[s.key] = true end
    for _, k in pairs(rules.alias or {}) do KNOWN_STAT[k] = true end
    for k in pairs(rules.derived or {}) do KNOWN_STAT[k] = true end
    for k in pairs(rules.skipKeys or {}) do KNOWN_STAT[k] = true end
    -- `labels` is DELIBERATELY NOT a source of vocabulary, and this comment is the whole
    -- reason: a label is a display string for a derived or bucket row, not a statement that
    -- the rules can price the key. Reading it as vocabulary would mean that adding a label to
    -- make one breakdown read nicely silently switches the warning off for that stat -- the
    -- exact failure this feature exists to catch. Both shipped modules' LABELS entries are
    -- already covered above anyway (Vanilla's AMMO_DAMAGE via skipKeys, HEALTH/MANA via
    -- derived), so nothing is lost by refusing it.
end

-- The expansion whose scoring rules are active ("Vanilla" / "TBC" / …), or nil if a client
-- shipped the data without a Scoring module. Feature-gate version-specific UI on this.
function lib:GetScoringVersion() return self.scoringVersion end
function lib:HasScoring() return RULES ~= nil end

-- Breakdown labels the CORE owns — bucket tokens it emits itself. A version module's `labels`
-- merge over these for the rows only it knows about (ammo, pools, ratings…).
local CORE_LABEL = {
    SET_BONUS = "Set bonus", PROC_DAMAGE = "Damage proc",
    PROC_HEAL = "Heal proc", PROC_MANA = "Mana proc", PROC_EXTRA_ATTACK = "Extra attack proc",
    META_SOCKET_EFFECT = "Meta gem effect", WEAPON_SPEED = "Weapon speed",
}

local function labelFor(key)
    local vl = RULES and RULES.labels and RULES.labels[key]
    if vl then return vl end
    if RULES then
        for _, s in ipairs(RULES.weightStats or {}) do
            if s.key == key then return s.label end
        end
    end
    return CORE_LABEL[key] or key
end

-- Stat scorers the CORE provides for a flavour to REGISTER (or not) in its `statScorers`. The
-- rule -- whether the mechanic exists in that expansion -- still lives in Scoring/<Version>.lua,
-- which is what opts in; only the arithmetic is shared, because it prices a stat key the core's
-- own pipeline emits identically for every flavour. Until 2026-09-17 `ammo` was a local in
-- Scoring/Vanilla.lua and TBC registered nothing, on the belief that AMMO_DAMAGE was "not
-- captured in the TBC walk" -- it never came from the walk; build-equip-stats.py reads it from
-- wago ItemSparse for every version, and Data/TBC/_core/EquipStats.lua carried 63 ammo rows
-- while a TBC hunter's ammo scored 0 (Dibs' DIBSREQ-IDB-003).
lib.StatScorers = lib.StatScorers or {}

-- AMMO_DAMAGE is the ranged DPS the ammo adds -- the client stores it and shows it as "Adds X
-- damage per second" (verified: Ice Threaded Bullet 16.5 == its 16.5 tooltip). It is NOT
-- per-shot and does not scale with bow speed, so it is valued exactly like ranged weapon DPS:
-- AMMO_DAMAGE x the class's DPS_RANGED weight -- nonzero only for hunters. 0 otherwise.
function lib.StatScorers.ammo(stats, w, _opts, parts)
    local dmg = stats.AMMO_DAMAGE
    if not dmg or dmg <= 0 then return 0 end
    local wt = w["DPS_RANGED"] or 0
    if wt == 0 then return 0 end
    local ep = dmg * wt
    if parts then
        parts[#parts + 1] = { kind = "ammo", key = "AMMO_DAMAGE", value = dmg, weight = wt, ep = ep,
            factors = { { label = "ammo DPS", value = dmg }, { label = "DPS weight", value = wt } } }
    end
    return ep
end

-- WEAPON_DAMAGE is a sharpening stone's / weightstone's flat "+N damage" on the weapon it is
-- applied to (build-effects.py, temporary-enchant type 2). It is per HIT, so as DPS it is
-- N / that weapon's swing speed, priced through the hand's weapon-DPS weight -- the same weight
-- the weapon's own DPS goes through, so a stone and a faster weapon agree. Dibs' DIBSREQ-IDB-010:
-- until MINOR 42 nothing priced the key and every stone scored 0 for every class.
--
-- The hand comes from opts.equipLoc through the rules' dpsSlot (INVTYPE_WEAPONOFFHAND = off-hand;
-- nil = main hand). The speed comes from the caller, because it belongs to the weapon being
-- imbued, not to the stone: opts.attack.weaponSpeed for the main hand, opts.attack.offhandSpeed
-- for the off hand (falling back to weaponSpeed). NO SPEED, NO SCORE -- a guessed speed would
-- misprice every stone by the ratio between the guess and the real weapon, so this answers 0
-- rather than a plausible number. A lower bound: instant attacks that add weapon damage
-- (Sinister Strike, Heroic Strike) take the bonus too and are not modelled.
function lib.StatScorers.weaponDamage(stats, w, opts, parts)
    local dmg = stats.WEAPON_DAMAGE
    if not dmg or dmg <= 0 then return 0 end
    local dk = (RULES and RULES.dpsSlot or {})[opts and opts.equipLoc] or "DPS_MAINHAND"
    if dk == "DPS_RANGED" then return 0 end         -- stones go on melee weapons only
    local wt = w[dk] or 0
    if wt == 0 then return 0 end
    local attack = opts and opts.attack
    local speed = attack and (dk == "DPS_OFFHAND" and (attack.offhandSpeed or attack.weaponSpeed)
                              or attack.weaponSpeed)
    if not speed or speed <= 0 then return 0 end
    local dps = dmg / speed
    local ep = dps * wt
    if parts then
        parts[#parts + 1] = { kind = "weapondamage", key = "WEAPON_DAMAGE", value = dmg, weight = wt,
            ep = ep, factors = { { label = dmg .. " per hit / " .. speed .. "s swing", value = dps },
                                 { label = "DPS weight", value = wt } } }
    end
    return ep
end

-- Gem sockets (TBC onward). Until 2026-10-04 this was four identical copies, one local in each
-- of Scoring/TBC.lua, Wrath.lua, Cata.lua and Mists.lua; it moved here the way `ammo` did, and
-- each of those modules now registers this one function.
--
-- A socket is worth whatever you put in it, so the honest valuation is the BEST GEM that fits,
-- under the same weights the item is being scored with -- spec-dependent by construction (a red
-- socket is a Bold gem to a warrior and a Runed one to a mage), hence computed at score time.
-- Gem facts are Pawn's via tools/build-gems.py, already in our key space.
--   R / Y / B  a gem fits those socket colours (several for a hybrid gem)
--   M          a meta gem; only a meta socket takes it
-- A PRISMATIC socket takes any non-meta colour.
--   C / H      a COGWHEEL (Cata+, engineering Tinker's gears) or HYDRAULIC (Mists, Sha-Touched)
--              gem; each fits only its own socket -- never a coloured, prismatic or meta one.
-- Pawn flags only R / Y / B, and until 2026-10-19 build-gems.py wrote every colourless gem as "M"
-- (77541 Smooth Tinker's Gear, 89873 Crystallized Dread), which made every cogwheel / hydraulic
-- socket score 0 AND let those gems out-price the real metas in a META socket (567 crit beats a
-- Primal Diamond's 432). build-gems.py now writes them "C" / "H" from the gem's core subclass
-- (Mists Gems.lua [77541]="C...", [89873]="H..."). The kind is ALSO read here from the gem's own
-- core subclass -- Gem (classID 3) subclass 10 = Cogwheel, 9 = Hydraulic, where 6 is Meta (76879
-- Ember Primal Diamond) -- so an older Gems.lua that still says "M" is read right too. TBC and
-- Wrath ship no Gem subclass 9 or 10. Socket BONUSES are not
-- modelled: honouring one means choosing off-colour gems to chase it, which is a gearing
-- decision, not an item fact -- so this is an upper bound on socket value, stated, not hidden.
--
-- META_SOCKET_EFFECT is the scale's price for a meta gem's NON-STAT effect. Pawn's own
-- description (Localization.lua, MetaSocketEffectInfo): "Points to be assigned for the non-stat
-- portion of a meta gem". Pawn attaches it to the GEM -- every Primal meta in its GemsMists.lua
-- carries `MetaSocketEffect = 1` -- so a filled meta socket earns the weight exactly once. Our
-- gem data drops that key (build-gems.py), so it is added here, once per meta socket, whenever
-- the active weights carry it, and ALSO with no gem data loaded: the effect is the scale's
-- number, not the gem file's, so it holds on a flavour or private server whose Gems.lua is not
-- loaded (every flavour from TBC to Mists ships one today). Meta ACTIVATION
-- requirements (the TBC / Wrath "requires N blue gems" rule) are not modelled.
local SOCKET_COLOUR = {
    EMPTY_SOCKET_RED = "R", EMPTY_SOCKET_YELLOW = "Y", EMPTY_SOCKET_BLUE = "B",
    EMPTY_SOCKET_META = "M", EMPTY_SOCKET_PRISMATIC = "*",
    EMPTY_SOCKET_COGWHEEL = "C", EMPTY_SOCKET_HYDRAULIC = "H",
}

-- Gem subclass -> the one socket that gem fits (see above). Only for classID 3 (Gem).
-- Cata / Mists numbering, and one map for every flavour on purpose: TBC and Wrath ship no Gem
-- subclass 9 or 10, Cata ships no Gem subclass 9 (its only colourless gems are the nine
-- subclass-10 cogwheels, Data/Cata/_core/Gem.lua), and Retail -- which numbers gem subclasses differently (77541 is subclass 5
-- there, tools/build-gems.py SOCKET_SUBCLASS) -- registers no scoring rules, so the sockets scorer
-- never runs on it. A Retail scoring file must give this map a per-flavour form first.
local GEM_SUBCLASS_SOCKET = { [9] = "H", [10] = "C" }

local function bestGemEP(w, colour)
    local byColour = bestGemCache[w]
    if not byColour then
        byColour = {}
        for id, gem in pairs(lib:GetGems()) do
            local ep = 0
            for k, v in pairs(gem.stats) do ep = ep + v * (w[k] or 0) end
            if ep > 0 then
                local fits = gem.colours
                local _, _, classID, subID = lib:GetInfo(id)
                local own = (classID == 3 and GEM_SUBCLASS_SOCKET[subID])
                    or ((fits == "C" or fits == "H") and fits) or nil
                if own then
                    if ep > (byColour[own] or 0) then byColour[own] = ep end
                elseif fits == "M" then
                    if ep > (byColour.M or 0) then byColour.M = ep end
                else
                    for c in fits:gmatch("%a") do
                        if ep > (byColour[c] or 0) then byColour[c] = ep end
                    end
                    if ep > (byColour["*"] or 0) then byColour["*"] = ep end
                end
            end
        end
        bestGemCache[w] = byColour
    end
    return byColour[colour] or 0
end

function lib.StatScorers.sockets(stats, w, _opts, parts)
    local total = 0
    if next(lib.gems) then
        for key, colour in pairs(SOCKET_COLOUR) do
            local n = stats[key]
            if n and n > 0 then
                local ep = bestGemEP(w, colour) * n
                if ep > 0 then
                    total = total + ep
                    if parts then
                        parts[#parts + 1] = { kind = "socket", key = key, value = n, ep = ep,
                            factors = { { label = "sockets", value = n },
                                        { label = "best gem", value = ep / n } } }
                    end
                end
            end
        end
    end
    local metas = stats.EMPTY_SOCKET_META
    local wt = w.META_SOCKET_EFFECT or 0
    if metas and metas > 0 and wt ~= 0 then
        local ep = metas * wt
        total = total + ep
        if parts then
            parts[#parts + 1] = { kind = "socket", key = "META_SOCKET_EFFECT", value = metas,
                weight = wt, ep = ep,
                factors = { { label = "meta sockets", value = metas },
                            { label = "effect weight", value = wt } } }
        end
    end
    return total
end

-- Weapon speed, for a scale that weights it (Pawn `Speed`; today only Mists' Wowhead scales:
-- BM 74, Marksmanship 100, Survival 75, Retribution 100, Assassination 100). Pawn's meaning,
-- verbatim from its Localization.lua: SpeedInfo "Weapon speed, in seconds per swing. (If you
-- prefer fast weapons, this number should be negative ...)", SpeedIs "1 second swing speed is
-- worth:". So EP = seconds x weight, and a positive weight means SLOWER is better. Pawn also has
-- a SpeedBaseline subtracted first; no shipped scale sets one, so it is 0 and not modelled.
--
-- THE ITEM SIDE HAS TWO KEYS, both seconds from ItemSparse.ItemDelay (build-equip-stats.py):
-- WEAPON_SPEED on RANGED weapons (bow / gun / crossbow / thrown / wand) and MELEE_WEAPON_SPEED on
-- melee ones. THE SCALE SIDE HAS ONE, WEAPON_SPEED, meaning "the speed of the weapon this spec
-- fights with". Which kind that is, is read off the scale's own DPS weights -- every shipped
-- Mists scale that weights Speed carries DPS_RANGED and no hand DPS (the hunters) or hand DPS and
-- no DPS_RANGED (Ret, Assassination). That is what stops a polearm a hunter could equip scoring
-- its swing speed against Marksmanship's 100, and a Ret scale pricing a bow. A scale that weights
-- Speed and neither kind of DPS (a hand-made one) cannot say, so it prices either.
function lib.StatScorers.speed(stats, w, _opts, parts)
    local wt = w.WEAPON_SPEED or 0
    if wt == 0 then return 0 end
    local ranged = (w.DPS_RANGED or 0) ~= 0
    local melee = (w.DPS_MAINHAND or 0) ~= 0 or (w.DPS_OFFHAND or 0) ~= 0
    if not ranged and not melee then ranged, melee = true, true end
    local spd = (ranged and stats.WEAPON_SPEED) or (melee and stats.MELEE_WEAPON_SPEED)
    if not spd or spd <= 0 then return 0 end
    local ep = spd * wt
    if parts then
        parts[#parts + 1] = { kind = "speed", key = "WEAPON_SPEED", value = spd, weight = wt, ep = ep,
            factors = { { label = "seconds", value = spd }, { label = "weight", value = wt } } }
    end
    return ep
end

-- Run the active expansion's extra scorers (weapon skill, ammo, combat ratings, …) over a stat
-- table and sum their EP. Each may push its own `parts` rows. 0 when no rules are registered or
-- the expansion has none, which is why an expansion can simply not have a mechanic.
local function runStatScorers(stats, w, opts, parts)
    if not RULES then return 0 end
    local s = 0
    for _, fn in ipairs(RULES.statScorers or {}) do
        s = s + (fn(stats, w, opts, parts) or 0)
    end
    return s
end

-- True if the flat walk must not price this key (the active rules score it another way).
local function skipped(k)
    if RULES.skipKeys and RULES.skipKeys[k] then return true end
    for _, p in ipairs(RULES.skipPrefix or {}) do
        if k:sub(1, #p) == p then return true end
    end
    return false
end

-- ONE shield, many schools. build-effects.py writes an ABSORBn key per bit of a SCHOOL_ABSORB
-- mask, so a ward against every school (mask 127: Greater Ward of Shielding 23576, Potion of
-- Petrification 13506) arrives as ABSORB0..ABSORB6 -- seven keys for one pool, which summed
-- priced the 4000-point ward as 28,000 HP (Peer Review, inbox 85dbb074, I1). Keep only the
-- largest; every expansion's rules price all seven schools the same way, so the largest value is
-- the largest EP. Copies the table only when a row carries two or more, so the hot path over
-- gear (which never has ABSORBn) allocates nothing.
local function collapseAbsorbs(stats)
    local n, bestK, bestV = 0, nil, nil
    for k, v in pairs(stats) do
        if type(k) == "string" and k:match("^ABSORB%d$") then
            n = n + 1
            if not bestV or v > bestV or (v == bestV and k < bestK) then bestK, bestV = k, v end
        end
    end
    if n < 2 then return stats end
    local t = {}
    for k, v in pairs(stats) do
        if not (type(k) == "string" and k:match("^ABSORB%d$")) or k == bestK then t[k] = v end
    end
    return t
end

-- Optional `parts` collector (GetItemScoreBreakdown): when given, push one
-- { kind, key, value, weight, ep } row per contributing stat. nil = the hot path
-- (GetItemScore over thousands of items) -- no table churn, identical sum.
--
-- Optional `drop` (docs/AUDIT.md finding 20): a set of ALIAS-RESOLVED keys to price at zero
-- for this call. Today its only caller is the school gate -- a +Fire item's spell damage is
-- worth nothing to a frost mage -- and the key set comes from RULES.schoolGated, so the caller
-- decides WHETHER to gate and the expansion decides WHICH key. Resolving the alias first is
-- load-bearing: Vanilla folds ITEM_MOD_SPELL_POWER into ITEM_MOD_SPELL_DAMAGE_DONE, so a set
-- keyed on the raw spelling would miss whichever spelling the item happens to use. Zeroing the
-- WEIGHT rather than skipping the key keeps the breakdown honest for free -- `parts` only
-- pushes a row when the contribution is non-zero, so a gated stat leaves no phantom "= 0" row.
local function positive(x) return (x and x > 0) and x or 0 end

-- How much of a spec's value comes from SPELLS, 0..1, read off the scale's own weights -- no
-- shipped scale carries a role field, and a weight scale already IS the statement of what a spec
-- uses. Two tiers, because the flavours price power differently:
--   1. spell power vs attack power (the rules' procKeys.spellDamage vs the apPair keys): every
--      Wrath / Cata caster weights spell power and no AP; every physical spec weights AP and no
--      spell power; the hybrids weight both (Wrath enhancement AP 0.59 / SP 0.53 -> 0.47 spell;
--      retribution 0.41 / 0.2 -> 0.33; protection paladin 0.13 / 0.4 -> 0.75).
--   2. neither (Mists' tank scales weight STR / AGI and no power stat): Intellect vs the better
--      of Strength / Agility -- the primary stat names the family.
-- A scale with none of those (a hand-made ratings-only scale) cannot say, and splits 50/50.
-- AN APPROXIMATION, stated: a hybrid's share is the ratio of its two power weights, not a
-- simulation of how much of its damage is spells. It is exact at the two ends, which is the
-- case the finding was about (Peer Review c6500056 D2: a spell-crit-only aura priced at full
-- weight for an arms warrior). In the middle it misreads: Wrath protection paladin's 0.75
-- would price its melee crit / hit % at a quarter (Peer Review c27e8a07 M3). So the rules'
-- `spellShare` table, keyed by the class / spec the scale was loaded under, is consulted FIRST;
-- the ratio is the fallback for a spec it does not name.
local function spellShare(w)
    local who = lib.bisWeightsSpec[w]
    local o = who and RULES.spellShare and RULES.spellShare[who[1]]
    o = o and o[who[2]]
    if o then return o end
    local PK = RULES.procKeys or {}
    local apPair = RULES.apPair or {}
    local sp = positive(w[PK.spellDamage or "ITEM_MOD_SPELL_DAMAGE_DONE"])
    local ap = math.max(positive(w[apPair.melee or "ITEM_MOD_ATTACK_POWER_SHORT"]),
                        positive(w[apPair.ranged or "ITEM_MOD_RANGED_ATTACK_POWER_SHORT"]))
    if sp + ap > 0 then return sp / (sp + ap) end
    local int = positive(w.ITEM_MOD_INTELLECT_SHORT)
    local phys = math.max(positive(w.ITEM_MOD_STRENGTH_SHORT), positive(w.ITEM_MOD_AGILITY_SHORT))
    if int + phys > 0 then return int / (int + phys) end
    return 0.5
end

-- The share of a spec's value a derived key of this `family` reaches (see the rules contract).
-- nil family = the key is not family-specific (a pool, dodge, parry...) = 1. "physical" serves
-- melee and ranged alike (auras 52 / 54 raise both); "melee" / "ranged" go to whichever the spec
-- fights with, read the way the speed scorer reads it: the ranged-DPS weight beating the
-- main-hand one (Wrath hunters weight both, ranged 2.6 vs 0.75). Any other family is melee.
-- Shares sum to 1 across a stat's spellings, so summing them is sign-correct: a buff of
-- +3% melee and -3% spell crit is +3 to a warrior, -3 to a mage and their blend to a hybrid --
-- the old "keep the better twin" rule dropped the penalty for everyone (c6500056 D5).
local function familyShare(family, w)
    if not family then return 1 end
    local sp = spellShare(w)
    if family == "spell" then return sp end
    if family == "physical" then return 1 - sp end
    local PK = RULES.procKeys or {}
    local ranged = positive(w[PK.dpsRanged or "DPS_RANGED"]) > positive(w[PK.dpsMain or "DPS_MAINHAND"])
    if family == "ranged" then return ranged and 1 - sp or 0 end
    return ranged and 0 or 1 - sp
end

-- The derived rule that prices `k` under these weights, or nil when the flat walk should.
-- `scaleWins`: the conversion is only a DEFAULT -- a scale that weights the key itself is
-- priced by the flat walk (Wrath/Cata/Mists hp5: weightable, but no shipped scale weights it,
-- so without the default it scored 0 -- Peer Review 85dbb074). "Weights it" means the key is
-- PRESENT: an explicit 0 is the scale saying the stat is worth nothing, and must not fall back
-- to the default (Peer Review 58162a3b N1).
local function derivedRule(k, w, alias)
    local p = RULES.derived and RULES.derived[k]
    if not p then return nil end
    if p.scaleWins and w[alias[k] or k] ~= nil then return nil end
    return p
end

-- The weight key `k` prices at, and the key to report it under -- the ONE place the derived
-- conversion is written. The stat walk, the on-use scorer and the proc scorer all call it, so
-- they cannot disagree (Peer Review c27e8a07 S1: scoreStats carried its own copy of the
-- formula). Until c6500056 D3 the use / proc scorers read w[alias[k] or k] only, so every
-- derived key -- a flat crit % on a client whose scales are keyed by crit RATING -- scored 0
-- inside an effect from TBC on (Felstriker 12590's CRIT_PCT proc).
-- Returns weight, key, and for a derived key also the rule, the base stat's weight and the
-- family share, which weightFactors turns into breakdown factors.
local function effectWeight(k, w, alias)
    local p = derivedRule(k, w, alias)
    if p then
        -- `exclude` (MINOR 45): the specs this key is worth nothing to, by the class / spec the
        -- scale was loaded under. Threat reduction is the case: it is damage headroom for a DPS
        -- and a liability for a tank, and a healer's spell-crit weight says nothing about it.
        -- A scale not registered through LoadBiSWeights has no spec, and is not excluded.
        local who = p.exclude and lib.bisWeightsSpec[w]
        local ex = who and p.exclude[who[1]]
        if ex and ex[who[2]] then return 0, k, p, 0, 1 end
        -- `only`: the inverse -- the specs this key is worth something to, every other
        -- registered spec prices it 0 (Wrath's +healing proc buffs: healers only). The same
        -- default as `exclude`: a scale with no registered spec cannot say, and is priced.
        who = p.only and lib.bisWeightsSpec[w]
        if who then
            local inc = p.only[who[1]]
            if not (inc and inc[who[2]]) then return 0, k, p, 0, 1 end
        end
        local base = w[p.stat] or 0
        local share = familyShare(p.family, w)
        return base / p.per * share, k, p, base, share
    end
    local key = alias[k] or k
    return w[key], key
end

-- The breakdown factors that explain a weight from effectWeight, to append after a row's own
-- amount / uptime / premium factors. A plain weight is one { weight } factor; a derived one is
-- split into the conversion, the base stat's weight and (when not 1) the family share, so a use
-- or proc row shows the same arithmetic a stat row does (Peer Review c27e8a07 L7). Either way
-- the factors multiply to `wt`.
local function weightFactors(factors, wt, p, base, share)
    if not p then
        factors[#factors + 1] = { label = "weight", value = wt }
        return factors
    end
    factors[#factors + 1] = { label = p.stat, value = 1 / p.per }
    factors[#factors + 1] = { label = "weight", value = base }
    if share ~= 1 then
        factors[#factors + 1] = { label = p.family .. " share", value = share, pct = true }
    end
    return factors
end

-- GENERIC ATTACK POWER: the one pairing rule, shared by scoreStats, scoreUseEffects and
-- scoreProcEffects (Peer Review c27e8a07 S2, then 4eaaa2da L1 -- the three scored alike and
-- itemised three different ways). The data stores "+X attack power" as a melee AND a ranged
-- spelling of one bonus, so the two sides are accumulated apart and settled here once.
-- Each scorer keeps its own accumulation loop only because a stat row, a use row and a proc
-- row carry different factors; the decision and the breakdown rows come from these two.
local function apPush(rows, r)
    rows = rows or {}
    rows[#rows + 1] = r
    return rows
end

-- The EP the pair contributes, and which side(s) supplied it. SIGN-CORRECT (4eaaa2da L2, the
-- D5 rule for % keys applied to AP): the old max(melee, ranged) dropped a lone penalty, because
-- max(-x, 0) is 0. Now:
--   same sign (or one side 0)  the side with the larger MAGNITUDE -- one bonus, priced through
--                              the attack type the spec weights more. For a buff that is the
--                              old max; for a penalty it is the larger penalty, never 0.
--   opposite signs             the SUM: a buff to one attack type and a penalty to the other
--                              cannot be twins of one bonus, so neither may be dropped.
-- A tie goes to melee, as before.
local function apPairEp(apM, apR)
    if (apM > 0 and apR < 0) or (apM < 0 and apR > 0) then return apM + apR, "both" end
    if math.abs(apR) > math.abs(apM) then return apR, "ranged" end
    return apM, "melee"
end

-- Settle the pair: return its EP and, when itemising, append the chosen side's rows -- one per
-- contributing stat / effect, never a merged row, so every row's factors multiply to its own
-- ep (4eaaa2da M1: a merged on-use row showed one effect's factors under the sum's ep).
local function apPairClose(apM, apR, mRows, rRows, parts)
    local ep, side = apPairEp(apM, apR)
    if parts and ep ~= 0 then
        if side ~= "ranged" then for _, r in ipairs(mRows or {}) do parts[#parts + 1] = r end end
        if side ~= "melee" then for _, r in ipairs(rRows or {}) do parts[#parts + 1] = r end end
    end
    return ep
end

-- Melee/ranged RATING twins. One on-equip aura that improves both attack types (TBC aura 189
-- misc 768) is reported by GetItemStats under BOTH keys -- Gloves of Holy Might 867 carries
-- CRIT_MELEE 14 and CRIT_RANGED 14 for one +14 crit line -- and every flavour's rules alias both
-- onto the one generic rating, so summing them priced that line twice (Peer Review de472a90 X1).
-- When both are present and alias to the same key, the pair settles like attack power: one
-- bonus by apPairEp's sign rule, kept under the spelling of the side it chose ("both" -> melee).
local RATING_TWINS = {
    { "ITEM_MOD_CRIT_MELEE_RATING", "ITEM_MOD_CRIT_RANGED_RATING" },
    { "ITEM_MOD_HIT_MELEE_RATING", "ITEM_MOD_HIT_RANGED_RATING" },
    { "ITEM_MOD_HASTE_MELEE_RATING", "ITEM_MOD_HASTE_RANGED_RATING" },
}

local function settleTwins(stats, alias)
    local out
    for _, t in ipairs(RATING_TWINS) do
        local m, r = stats[t[1]], stats[t[2]]
        if m and r and (alias[t[1]] or t[1]) == (alias[t[2]] or t[2]) then
            if not out then
                out = {}
                for k, v in pairs(stats) do out[k] = v end
            end
            -- kept under the side apPairEp chose (the breakdown row is keyed by the alias either
            -- way, so this only matters to a caller reading the settled table)
            local v, side = apPairEp(m, r)
            out[t[1]], out[t[2]] = nil, nil
            out[side == "ranged" and t[2] or t[1]] = v
        end
    end
    return out or stats
end

local function scoreStats(stats, w, equipLoc, parts, drop)
    if not RULES then return 0 end
    local alias = RULES.alias or {}
    stats = settleTwins(collapseAbsorbs(stats), alias)
    local apPair = RULES.apPair
    local MELEE_AP = apPair and apPair.melee
    local RANGED_AP = apPair and apPair.ranged
    local s, apM, apR = 0, 0, 0
    local apMrows, apRrows          -- breakdown rows per AP side, only when itemising
    for k, v in pairs(stats) do
        -- luacheck: ignore 542
        -- The empty branch is the POINT and must not be "tidied" into `if not skipped(k)`:
        -- this is the head of an elseif chain, so inverting it would have to re-nest every
        -- arm below. Skipping here is a positive decision (the key is priced by one of the
        -- rules' own statScorers), and stating it in place is what stops someone later
        -- deleting the test and letting these keys fall through to a flat weight.
        if skipped(k) then
            -- priced by one of the rules' own statScorers, never as a flat weight
        elseif derivedRule(k, w, alias) then
            -- A key no weight scale prices directly (a flat HP pool; a flat crit % on a client
            -- whose scales are keyed by crit RATING). Value it through the stat that does carry
            -- a weight, at this expansion's fixed conversion, times the spec's share of the
            -- key's attack family when it has one (see familyShare). Priced by effectWeight,
            -- the same function the use / proc scorers call.
            local wt, _, p, base, share = effectWeight(k, w, alias)
            local c = v * wt
            s = s + c
            if parts and c ~= 0 then
                parts[#parts + 1] = { kind = "stat", key = k, value = v, weight = wt, ep = c,
                    factors = weightFactors({ { label = k, value = v } }, wt, p, base, share) }
            end
        elseif k == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then
            -- One DPS stat in the data, but weighted per hand: pick the weight by equip slot.
            local dk = (RULES.dpsSlot or {})[equipLoc] or "DPS_MAINHAND"
            local wt = w[dk] or 0
            s = s + v * wt
            if parts and wt ~= 0 then
                parts[#parts + 1] = { kind = "stat", key = dk, value = v, weight = wt, ep = v * wt,
                    factors = { { label = dk, value = v }, { label = "weight", value = wt } } }
            end
        else
            local key = alias[k] or k
            -- A gated key prices at 0 rather than being skipped: see `drop` above.
            local wt = (drop and drop[key]) and 0 or (w[key] or 0)
            local c = v * wt
            local r = (parts and c ~= 0) and { kind = "stat", key = key, value = v, weight = wt,
                ep = c, factors = { { label = key, value = v }, { label = "weight", value = wt } } }
            if key == MELEE_AP then apM = apM + c; if r then apMrows = apPush(apMrows, r) end
            elseif key == RANGED_AP then apR = apR + c; if r then apRrows = apPush(apRrows, r) end
            else
                s = s + c
                if r then
                    parts[#parts + 1] = r
                elseif parts and v ~= 0 and not KNOWN_STAT[key] then
                    -- The rules have no VOCABULARY for this key, so it contributed nothing and
                    -- would otherwise leave no trace at all -- the item just scores lower and
                    -- nothing says why. A weight of 0 on a key the rules DO know is a judgement
                    -- and stays silent; this row is for a stat the scorer cannot see.
                    parts[#parts + 1] = { kind = "unpriced", key = key, value = v, ep = 0 }
                end
            end
        end
    end
    return s + apPairClose(apM, apR, apMrows, apRrows, parts)
end

-- The scoring-model constants the active rules supply (usePremium, hitsPerSec, castsPerSec,
-- epPerRawDPS, epPerHPS), as the ultimate fallback under anything LoadScoreModel shipped.
-- `castsPerSec` is OPTIONAL and no shipped module declares one yet; absent, spell-scoped procs
-- fall back to hitsPerSec (see scoreProcEffects, finding 9). Per-expansion
-- because the tuning is — a proc rate or on-use premium calibrated for Vanilla is not TBC's.
-- A bare table when no rules are registered, so nothing here can index nil.
local function baseModel()
    return (RULES and RULES.model) or {}
end
local function usePremiumDefault()
    return baseModel().usePremium or 1
end

-- EP from an item's on-use effects: Σ magnitude × min(1, duration/cooldown) ×
-- premium × weight[stat], the premium dropped to 1 once duration >= cooldown. Only entries with a cooldown score here; proc entries
-- (no cd) wait for the proc pass, so this is forward-compatible with that data.
local function scoreUseEffects(list, w, premium, parts)
    if not RULES then return 0 end
    local alias = RULES.alias or {}
    local apPair = RULES.apPair
    local MELEE_AP = apPair and apPair.melee
    local RANGED_AP = apPair and apPair.ranged
    local USE_PREMIUM = usePremiumDefault()
    local s, apM, apR = 0, 0, 0     -- the AP pair, settled by apPairClose like scoreStats
    local apMrows, apRrows          -- breakdown rows per AP side, only when itemising
    for _, e in ipairs(list) do
        if e.cd and e.cd > 0 and e.d and e.d > 0 then
            local wk, key, p, base, share = effectWeight(e.k, w, alias)
            if wk and wk ~= 0 then
                local uptime = e.d / e.cd
                -- A buff up for its whole cooldown is a flat stat, not a burst to line up with
                -- other cooldowns, so it earns no premium (Peer Review A6; shipped case: Cata and
                -- Mists Mark of the Dragon Lord 13143, d=1800 on cd=1800).
                local prem = premium or USE_PREMIUM
                if uptime >= 1 then uptime, prem = 1, 1 end
                local c = e.m * uptime * prem * wk
                local r = (parts and c ~= 0) and { kind = "use", key = key, value = e.m, ep = c,
                    factors = weightFactors({ { label = key, value = e.m },
                                { label = "uptime", value = uptime, pct = true },
                                { label = "premium", value = prem } },
                                wk, p, base, share) }
                if key == MELEE_AP then apM = apM + c; if r then apMrows = apPush(apMrows, r) end
                elseif key == RANGED_AP then apR = apR + c; if r then apRrows = apPush(apRrows, r) end
                else
                    s = s + c
                    if r then parts[#parts + 1] = r end
                end
            end
        end
    end
    return s + apPairClose(apM, apR, apMrows, apRrows, parts)
end


-- EP from chance-on-hit procs. rate = procs/sec: a CMaNGOS-tested `ppm` (procs per
-- minute) → ppm/60 (weapon-speed-independent, the accurate Classic model), else a
-- real per-hit `ch`% × triggering hits/sec. Capped by any internal cooldown. Value
-- per bucket: buff = magnitude × uptime ×
-- weight (uptime = min(stacks, rate×dur)); damage = bonus DPS × the weapon-DPS weight
-- (per hand, self-calibrating melee/ranged — see below); heal = HPS →
-- healing-power-equivalent × healing weight (model.epPerHPS = healing
-- power per HPS); mana = mana/sec → mp5 × weight. No burst premium — a proc isn't
-- player-controlled. hitsPerSec comes from the paperdoll (opts.attack) or the model.
--
-- SCOPE AND RATE ARE DIFFERENT QUESTIONS, and only rows with `sc="spell"` care -- finding 9.
-- A paperdoll can only ever report WEAPON SWINGS, so once a consumer wires opts.attack (the
-- documented intent) a swing rate would start driving procs that fire on a CAST: Vestments of
-- Faith's 8-piece (Sets.lua:158) triggers on a priest's spells and would move with the speed of
-- whatever they happen to be holding. So a spell-scoped row is priced off `model.castsPerSec`
-- when the flavour declares one, and off `model.hitsPerSec` -- the per-class MODEL default,
-- never the paperdoll value -- when it does not.
--
-- WHAT THIS DELIBERATELY DOES NOT DO: pick a cast rate. No shipped rules module declares
-- `castsPerSec`, so every score today is bit-identical to before this change (model.hitsPerSec
-- is exactly what the callers already resolved when no paperdoll is wired). What changes is that
-- a paperdoll can no longer reach a spell-scoped row. The VALUE is still the open half of
-- finding 9 and is a question for the owner; inventing one here is the failure this repo names.
--
-- GENERIC ATTACK POWER IS MAX-PAIRED HERE TOO, as in scoreStats and scoreUseEffects (Peer Review
-- c27e8a07 S2). The omission was not deliberate: build-use-effects.py emits a "+X attack power"
-- spell as one row per aura -- melee (aura 99) AND ranged (aura 124) -- and it reads proc spells
-- and on-use spells the same way (the on-use twins are visible in every Data/*/_core/
-- UseEffects.lua, e.g. Wrath item 14554). So a generic-AP proc arrives as two buff rows and,
-- summed, priced a hunter's +X AP twice. Shipped procs DO carry the pair since build-use-effects
-- writes one row per stat aura: 11817 (Vanilla), 34472 Shard of Contempt and 34427 Blackened
-- Naaru Sliver (TBC on), so a hunter's score for those takes the larger half. Dragonstalker's
-- 8-piece set proc is ranged alone, and a lone side still prices in full (apPairEp). The chosen side's rows are kept whole (one per effect),
-- so each row's factors still multiply to its own ep.
-- Mean stack count over a `window`-second buff that gains one stack per trigger at `rate`
-- triggers/sec (Poisson), capped at `cap`: the time-average of E[min(cap, N(t))]. The SAME
-- maths, step and all, as tools/build-use-effects.py average_stacks, which prices an on-use
-- window at build time; a proc window (`ws`) is priced here because its rate is the wearer's.
local function averageStacks(rate, window, cap)
    if rate <= 0 or window <= 0 then return 0 end
    local step = 0.05
    local n = math.floor(window / step + 0.5)
    local total = 0
    for i = 0, n - 1 do
        local lam = rate * (i + 0.5) * step
        local p, below, mean = math.exp(-lam), 0, 0
        for k = 0, cap - 1 do
            mean = mean + k * p
            below = below + p
            p = p * lam / (k + 1)
        end
        total = total + mean + cap * (1 - below)
    end
    return total / n
end

local function scoreProcEffects(list, w, model, hitsPerSec, equipLoc, parts)
    if not RULES then return 0 end
    local alias = RULES.alias or {}
    local DPS_SLOT = RULES.dpsSlot or {}
    local apPair = RULES.apPair
    local MELEE_AP = apPair and apPair.melee
    local RANGED_AP = apPair and apPair.ranged
    local s, apM, apR = 0, 0, 0
    local apMrows, apRrows          -- breakdown rows per AP side, only when itemising
    -- a proc's bonus DPS is priced through the class's weapon-DPS weight (like base weapon
    -- DPS and weapon skill), NOT the AP weight — so a melee weapon's on-hit proc is valued
    -- low for a hunter (DPS_MAINHAND ~0.75, they barely swing it) and high for a warrior.
    -- Weight-scale keys come from the expansion's rules, not from literals here -- finding 10.
    -- The `or` fallbacks keep a rules module that predates `procKeys` working unchanged; they are
    -- NOT a licence to omit the block in a new flavour, which is the case the finding is about.
    local PK = RULES.procKeys or {}
    local K_DPS_MAIN    = PK.dpsMain     or "DPS_MAINHAND"
    local K_DPS_RANGED  = PK.dpsRanged   or "DPS_RANGED"
    local K_SPELL_DMG   = PK.spellDamage or "ITEM_MOD_SPELL_DAMAGE_DONE"
    local K_HEALING     = PK.healing     or "ITEM_MOD_SPELL_HEALING_DONE"
    local K_MANA        = PK.mana        or "ITEM_MOD_POWER_REGEN0_SHORT"
    local dk = equipLoc and DPS_SLOT[equipLoc]
    local dmgDpsW = (dk and w[dk]) or math.max(w[K_DPS_MAIN] or 0, w[K_DPS_RANGED] or 0)
    -- CASTER ROUTE for the same bucket, and it is not an edge case: NO caster scale carries a
    -- weapon-DPS weight at all. Read in Data/Vanilla/_core/BiSWeights.lua -- priest (:38-41),
    -- mage (:50-53) and warlock (:56-59) price ITEM_MOD_SPELL_DAMAGE_DONE and have neither
    -- DPS_MAINHAND nor DPS_RANGED, while shaman enhancement (:46) has DPS_MAINHAND=3. So
    -- dmgDpsW was math.max(0, 0) for every caster spec and EVERY b="damage" proc scored
    -- exactly zero -- then vanished, because the `c ~= 0` filter below drops the breakdown row,
    -- making it read as absence rather than as a zero. docs/AUDIT.md finding 11; identical
    -- structure to finding 7's heal bucket, which is why they were fixed together.
    local spellDmgW = w[K_SPELL_DMG] or 0
    -- Resolved once, not per row. Written as an if rather than `a and b or c`: with both model
    -- fields nil that idiom silently yields `hitsPerSec` for a SPELL row -- the paperdoll value
    -- this exists to keep out -- because `true and nil` is nil and falls through to the `or`.
    local castsPerSec = model.castsPerSec
    if castsPerSec == nil then castsPerSec = model.hitsPerSec end
    -- THE ONE RULE BEHIND ALL THREE OF THESE: a paperdoll can report WEAPON SWINGS and nothing
    -- else. `hitsPerSec` is the only rate a consumer may override via opts.attack, so it is the
    -- only rate an `any` (swing-triggered) row may read. Every other scope resolves off the
    -- MODEL, because nothing in a character sheet knows how often you cast, how often your DoTs
    -- tick, or how often you get hit. docs/AUDIT.md finding 9, generalised by finding 15 tier 3.
    --
    -- Both new constants are OPTIONAL and fall back to a rate that is already correct-by-default,
    -- so no shipped module declaring neither can see a score move -- the same staging finding 9
    -- used for castsPerSec, and the reason an undeclared rate is a hole with a NAME rather than
    -- one constant quietly doing four jobs.
    local ticksPerSec = model.ticksPerSec          -- DoT/HoT ticks per second
    if ticksPerSec == nil then ticksPerSec = castsPerSec end   -- a tick implies you cast the DoT
    local hitsTakenPerSec = model.hitsTakenPerSec  -- incoming attacks per second (a TANK number)
    if hitsTakenPerSec == nil then hitsTakenPerSec = model.hitsPerSec end
    for _, e in ipairs(list) do
        -- An if-chain, never `a and b or c`: with a model field nil that idiom falls through
        -- to the PAPERDOLL value, which is the one thing every branch below exists to keep
        -- out. The trap is real -- it was caught once already on the castsPerSec branch.
        -- Resolved for every row (not only the `ch` ones) because a proc-window row (`ws`)
        -- stacks at this rate inside its window whatever opened the window.
        local trig
        if e.sc == "spell" then trig = castsPerSec
        elseif e.sc == "periodic" then trig = ticksPerSec
        elseif e.sc == "taken" then trig = hitsTakenPerSec
        else trig = hitsPerSec end
        local rate
        if e.ppm and e.ppm > 0 then
            rate = e.ppm / 60                       -- tested PPM, weapon-speed-independent
        else
            rate = (e.ch or 0) / 100 * (trig or 0)
        end
        if e.icd and e.icd > 0 and rate > 1 / e.icd then rate = 1 / e.icd end
        local c, key, fac = 0, nil, nil
        if e.b == "buff" and e.k then
            local wk, wkey, p, base, share = effectWeight(e.k, w, alias)
            if wk and wk ~= 0 then
                local uptime = rate * (e.d or 0)
                local cap = e.st or 1
                if uptime > cap then uptime = cap end
                key = wkey
                local f = { { label = key, value = e.m } }
                local per = e.m
                if e.ws and e.ws > 1 then
                    -- PROC WINDOW (Blackened Naaru Sliver): `m` is PER STACK, and for the d s the
                    -- window lasts every triggering hit adds one, up to `ws`. The mean stack
                    -- count comes from this row's own trigger rate -- the wearer's hits, which
                    -- only the consumer's paperdoll or the class model knows.
                    local avg = averageStacks(trig or 0, e.d or 0, e.ws)
                    per = e.m * avg
                    f[#f + 1] = { label = "avg stacks", value = avg }
                end
                c = per * uptime * wk
                f[#f + 1] = { label = "uptime", value = uptime, pct = true }
                fac = weightFactors(f, wk, p, base, share)
            end
        elseif e.b == "damage" then
            key = "PROC_DAMAGE"
            -- `sc` records what actually FIRES the proc ("any" | "spell"). Until the caster route
            -- existed it could not change any answer -- casters scored zero on this bucket however
            -- it triggered -- so the field was orphaned rather than dead (docs/AUDIT.md finding 9,
            -- the same shape as epPerRawDPS in finding 8). Now there are two routes and `sc` is
            -- what picks between them, because `dmgDpsW ~= 0` only asks "does this class swing".
            --
            -- It matters for HYBRIDS, which carry both weights: paladin protection
            -- (BiSWeights.lua:22, DPS_MAINHAND 1.77 / spell damage 0.44), paladin retribution
            -- (:23, 5.4 / 0.33) and shaman enhancement (:46, 3 / 0.3). A 10-DPS sc="spell" proc on
            -- the enhancement shaman is 10*3 = 30 by the weapon route and 10*3.5*0.3 = 10.5 by the
            -- caster one -- nearly 3x, in the overvaluing direction, for an effect that only fires
            -- when they cast.
            --
            -- Requiring spellDmgW ~= 0 is load-bearing: a pure melee scale with an sc="spell" proc
            -- has no spell weight to price it with, and must keep the weapon route rather than
            -- falling through to zero.
            local preferCaster = (e.sc == "spell") and spellDmgW ~= 0
            if dmgDpsW ~= 0 and not preferCaster then      -- bonus DPS -> weapon-DPS weight
                c = (e.m * rate) * dmgDpsW
                fac = { { label = "damage", value = e.m }, { label = "procs/sec", value = rate },
                        { label = "DPS weight", value = dmgDpsW } }
            elseif spellDmgW ~= 0 then
                -- bonus DPS -> spell-damage-power-equivalent -> the scale's spell-damage weight.
                -- The mirror of the heal bucket below, and the SAME divisor: Classic's direct
                -- DAMAGE coefficient is also castTime / 3.5, so 1 DPS is worth about 3.5 spell
                -- damage. model.epPerRawDPS carries it -- it was shipped, documented and
                -- per-class overridable while being read by nothing at all (finding 8), because
                -- this conversion was the route it was written for and never got wired to.
                local perDPS = model.epPerRawDPS or 0
                c = (e.m * rate) * perDPS * spellDmgW
                fac = { { label = "damage", value = e.m }, { label = "procs/sec", value = rate },
                        { label = "spell power/DPS", value = perDPS },
                        { label = "weight", value = spellDmgW } }
            end
        elseif e.b == "extra_attack" then
            -- An extra MELEE swing from a non-weapon (Hand of Justice). Each extra attack is one
            -- MAIN-HAND swing, worth white DPS / main-hand swings per second, so the extra share
            -- is rate x m / mainSwingsPerSec. That rate is opts.attack.mainSwingsPerSec, else
            -- the trigger rate hitsPerSec -- which for a single-weapon swing-triggered row
            -- cancels to ch% x m. A dual-wielder whose hits outnumber their main-hand swings
            -- must pass mainSwingsPerSec or HoJ prices low (Peer Review 366810d1 E1). Priced
            -- through the MAIN-HAND weight only -- extra attacks are melee, so a hunter's ranged
            -- weight must not price it. White DPS is opts.attack.weaponDPS, else
            -- model.whiteDPS; a flavour declaring neither prices it 0 rather than inventing one.
            -- model.whiteDPS has ONE meaning on every flavour: the WEAPON DPS ((min + max) / 2 /
            -- speed, no attack-power / 14 term) of one named raid two-hander, read from the
            -- flavour's own core where it carries a DPS key, from WoWSims' database where it does
            -- not (Wrath), standing in for the wearer's main-hand weapon. It leaves AP out, so it
            -- is a floor; each Scoring file names the item its number comes from. Tier: a
            -- first-tier raid weapon (TBC, Wrath, Mists). KNOWN COST: Vanilla keeps Naxxramas'
            -- Corrupted Ashbringer (90), the last tier, because moving it would move live Vanilla
            -- scores (MELEE_HASTE_PCT and the weapon-skill default read the same number).
            key = "PROC_EXTRA_ATTACK"
            local mainW = w[K_DPS_MAIN] or 0
            local white = model.whiteDPS or 0
            local swings = model.mainSwingsPerSec or hitsPerSec or 0
            if mainW ~= 0 and white > 0 and swings > 0 then
                local extra = rate / swings * e.m
                c = extra * white * mainW
                fac = { { label = "extra swings", value = extra, pct = true },
                        { label = "white DPS", value = white },
                        { label = "DPS weight", value = mainW } }
            end
        elseif e.b == "heal" then                          -- HPS -> healing power -> weight
            key = "PROC_HEAL"
            local hw = w[K_HEALING] or 0
            c = (e.m * rate) * (model.epPerHPS or 0) * hw
            fac = { { label = "heal", value = e.m }, { label = "procs/sec", value = rate },
                    { label = "HP/power", value = model.epPerHPS or 0 }, { label = "weight", value = hw } }
        elseif e.b == "mana" then                          -- mana/sec -> mp5 -> weight
            -- Through effectWeight, so a derived mp5 (Mists prices mp5 as Spirit for healers,
            -- Scoring/Mists.lua DERIVED.ITEM_MOD_POWER_REGEN0_SHORT) reaches a mana proc too.
            -- A raw w[K_MANA] read priced every Mists mana proc at 0 (Idols of Wisdom 92123).
            local wk, _, p, base, share = effectWeight(K_MANA, w, alias)
            if wk and wk ~= 0 then
                key = "PROC_MANA"
                c = (e.m * rate * 5) * wk
                fac = weightFactors({ { label = "mana", value = e.m }, { label = "procs/sec", value = rate },
                        { label = "x5 (mp5)", value = 5 } }, wk, p, base, share)
            end
        end
        local r = (parts and c ~= 0)
            and { kind = "proc", key = key, value = e.m, ep = c, factors = fac } or nil
        -- `key and`: a bucket that priced nothing leaves key nil, and so does a flavour with
        -- no apPair -- nil == nil must not file an unpriced row as melee AP.
        if key and key == MELEE_AP then apM = apM + c; if r then apMrows = apPush(apMrows, r) end
        elseif key and key == RANGED_AP then apR = apR + c; if r then apRrows = apPush(apRrows, r) end
        else
            s = s + c
            if r then parts[#parts + 1] = r end
        end
    end
    return s + apPairClose(apM, apR, apMrows, apRrows, parts)
end

-- Summed (un-amortized) EP of a set's chance-on-hit bonuses across every threshold <= maxT.
-- Same row format and pricing as item procs (scoreProcEffects); equipLoc is nil because a
-- set proc isn't tied to any one piece's weapon slot (damage procs fall back to the class's
-- best weapon-DPS weight). The caller amortizes the result across the set's pieces, exactly
-- like the flat set-bonus stats. Returns 0 when the set has no scored procs.
local function sumSetProcs(set, maxT, w, model, hitsPerSec)
    if not set.procs then return 0 end
    local s = 0
    for n, rows in pairs(set.procs) do
        if (tonumber(n) or math.huge) <= maxT then
            s = s + scoreProcEffects(rows, w, model, hitsPerSec, nil)
        end
    end
    return s
end

-- Weapon skill, ammo, combat ratings and every other expansion-specific scorer live in
-- Scoring/<Version>.lua and arrive via RULES.statScorers — see the rules contract above.

-- The resolved scoring model for a class/spec: loaded overrides (spec, then the class
-- "default") merged over the active rules' model, so every key always has a value.
-- source defaults to "default" (our shipped model); pass a scale name to override.
function lib:GetScoreModel(classID, spec, source)
    local out = {}
    for k, v in pairs(baseModel()) do out[k] = v end
    local c = self.scoreModel[source or "default"]
    c = c and c[classID]
    if c then
        -- {} not nil — a class with only a per-spec override (no "default" block) would
        -- otherwise truncate ipairs at index 1 and lose the spec model entirely.
        for _, m in ipairs({ c["default"] or {}, c[spec] or {} }) do
            for k, v in pairs(m) do out[k] = v end
        end
    end
    return out
end

-- The model and swing-trigger rate every proc pricing site uses, resolved in ONE place so the
-- item and set sites cannot diverge (Peer Review 366810d1 F2: the weaponDPS override existed at
-- two of four sites). `attack` is the paperdoll context: hitsPerSec, weaponDPS -> whiteDPS, and
-- mainSwingsPerSec (main-hand swings only, which an extra attack is worth one of).
local function procContext(self, classID, spec, source, attack)
    local model = self:GetScoreModel(classID, spec, source)   -- fresh table: writes cannot leak
    local hits = (attack and attack.hitsPerSec) or model.hitsPerSec
    if attack then
        model.whiteDPS = attack.weaponDPS or model.whiteDPS
        model.mainSwingsPerSec = attack.mainSwingsPerSec or model.mainSwingsPerSec
    end
    return model, hits
end

-- True if any FIXED BiS gear LIST is loaded — gates GetBiS / IsBiS / GetBiSPhases only.
function lib:HasBiS() return next(self.bis) ~= nil end

-- True if any EP WEIGHT SCALE is loaded — the gate for GetItemScore / ScoreStats / RankItems /
-- GetSlotRanking / GetRaidBiS, none of which need a fixed list.
--
-- These are SEPARATE datasets and an expansion can have one without the other: TBC ships
-- HawsJon's weights but no fixed BiS lists yet, so `HasBiS()` is false there while every
-- scoring API works. A consumer gating EP on `HasBiS()` silently shows no scores on such a
-- client even though the weights are right there — check this instead.
function lib:HasBiSWeights() return next(self.bisWeights) ~= nil end

-- The active EP weight scale (a player's custom scale, else HawsJon). This is the
-- scale GetItemScore/RankItems/GetRaidBiS use — the fixed-set default is separate.
function lib:GetDefaultBiSSource() return weightSource(self) end

-- Pick which loaded EP weight scale scoring defaults to. Returns true if it exists.
function lib:SetDefaultBiSSource(source)
    if self.bisWeights[source] then self.bisWeightsDefault = source; return true end
    return false
end

-- Loaded EP weight scales (what an editor lists / lets the player pick).
function lib:GetBiSSources()
    local out = {}
    for s in pairs(self.bisWeights) do out[#out + 1] = s end
    table.sort(out)
    return out
end

-- Specs a class has EP weights for, in the given (or default) weight scale.
function lib:GetBiSSpecs(classID, source)
    local c = self.bisWeights[weightSource(self, source)]
    c = c and c[classID]
    local out = {}
    if c then for spec in pairs(c) do out[#out + 1] = spec end; table.sort(out) end
    return out
end

-- Spec tokens a FIXED BiS SET source holds for a class, sorted (MINOR 45). Not the same list as
-- GetBiSSpecs, which reads the EP weight scales: a set source's tokens are its own -- bisclassic
-- adds race groups and two-hand setups (default_human, tank_2h) that no weight scale carries.
function lib:GetBiSSetSpecs(classID, source)
    local c = self.bis[bisSource(self, source)]
    c = c and c[classID]
    local out = {}
    if c then for spec in pairs(c) do out[#out + 1] = spec end; table.sort(out) end
    return out
end

-- Phases available for a class+spec, sorted ascending (0 = pre-BiS).
function lib:GetBiSPhases(classID, spec, source)
    local c = self.bis[bisSource(self, source)]
    c = c and c[classID] and c[classID][spec]
    local out = {}
    if c then for phase in pairs(c) do out[#out + 1] = phase end; table.sort(out) end
    return out
end

-- A full BiS set: { [SLOT] = itemID }, or nil if that class/spec/phase is absent.
function lib:GetBiS(classID, spec, phase, source)
    local c = self.bis[bisSource(self, source)]
    c = c and c[classID]
    c = c and c[spec]
    return c and c[phase] or nil
end

function lib:GetBiSItem(classID, spec, phase, slot, source)
    local set = self:GetBiS(classID, spec, phase, source)
    return set and set[slot] or nil
end

-- Reverse index: itemID -> { { source, classID, spec, phase, slot }, ... }.
local function bisIndex(self)
    if self._bisIndex then return self._bisIndex end
    local idx = {}
    for source, classes in pairs(self.bis) do
        for classID, specs in pairs(classes) do
            for spec, phases in pairs(specs) do
                for phase, set in pairs(phases) do
                    for slot, itemID in pairs(set) do
                        local list = idx[itemID]
                        if not list then list = {}; idx[itemID] = list end
                        list[#list + 1] = { source = source, classID = classID,
                                            spec = spec, phase = phase, slot = slot }
                    end
                end
            end
        end
    end
    self._bisIndex = idx
    return idx
end

-- Where an item is BiS: array of { source, classID, spec, phase, slot }.
-- Optionally restrict to one source. Empty table if never BiS. Always a FRESH list: returning the
-- index's own list let a caller that sorted or trimmed it edit every later answer for that item.
function lib:IsBiS(itemID, source)
    local hits = bisIndex(self)[itemID]
    local out = {}
    if not hits then return out end
    for _, h in ipairs(hits) do
        if not source or h.source == source then out[#out + 1] = h end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- EP scoring & ranking — uses the BiS weights + enriched stats + set bonuses.
-- One approximate, sim-derived opinion; good for "what's worth wanting".
-- ---------------------------------------------------------------------------
function lib:GetBiSWeights(classID, spec, source)
    local c = self.bisWeights[weightSource(self, source)]
    c = c and c[classID]
    return c and c[spec] or nil
end

-- The stats the ACTIVE expansion's weight scale can set, in display order:
-- { { key, label }, ... }. An in-game weight editor renders one input per entry and builds
-- { [key] = number } to hand LoadBiSWeights; these are exactly the keys the scorer reads.
-- Per-expansion by definition (Vanilla has weapon skill and no haste; TBC has combat ratings),
-- so it comes from the registered rules. Empty when no Scoring module is loaded.
function lib:GetWeightStats()
    local out = {}
    for i, s in ipairs((RULES and RULES.weightStats) or {}) do
        out[i] = { key = s.key, label = s.label }
    end
    return out
end

-- The `drop` set for one item's own stats, or nil to price everything -- docs/AUDIT.md
-- finding 20, routed here from the Dibs board, where a consumer had been passing
-- `opts.schools` into GetItemScore for a gate this library never implemented.
--
-- ONE helper, called by BOTH GetItemScore and GetItemScoreBreakdown, deliberately: those two
-- duplicate their orchestration (finding 4) and a gate written twice is a gate that will
-- eventually disagree with itself, which is the failure mode finding 4 is about.
--
-- The three cases, and only the third one gates:
--   opts.schools absent      the consumer has no opinion -- score everything, exactly as
--                            before. This is what makes the whole feature ADDITIVE: no
--                            caller that omits the option can see any change.
--   item has no school tag   generic +spell damage, or none at all -- always counts. A nil
--                            from GetItemSchools means "not school-specific", NOT "unknown".
--   tag and no intersection  the item's spell damage is restricted to schools this spec does
--                            not cast, so its school-gated keys price at 0.
local function schoolDrop(self, itemID, opts)
    if not (opts.schools and RULES and RULES.schoolGated) then return nil end
    local its = self:GetItemSchools(itemID)
    if not its then return nil end
    for sc in pairs(its) do
        if opts.schools[sc] then return nil end   -- one match is enough
    end
    return RULES.schoolGated
end

-- The equip slot to SCORE an item AS, which is not always the slot the item reports (MINOR 30,
-- Dibs' DIBSREQ-IDB-007). A one-hander is INVTYPE_WEAPON, which every scale's dpsSlot maps to
-- DPS_MAINHAND -- so planning that same item into the off-hand scored it as a main hand, and
-- the library had no way for the caller to say which hand it was going into. `opts.equipLoc`
-- replaces the item's own, and feeds BOTH the per-hand DPS weight and the proc damage bucket,
-- because a proc on an off-hand weapon fires at the off-hand's rate.
--
-- ONE function rather than the same `opts.equipLoc or select(5, GetInfo(id))` written at each
-- call site: GetItemScore and GetItemScoreBreakdown already duplicate this whole scoring
-- sequence (finding 4's block in the spec exists because they drifted once), and a per-hand
-- override that applied in one and not the other would disagree silently.
local function scoreEquipLoc(self, itemID, opts)
    if opts.equipLoc then return opts.equipLoc end
    local _, _, _, _, equipLoc = self:GetInfo(itemID)
    return equipLoc
end

-- EP score of one item for a class/spec (includes the hit/crit enrichment). opts:
--   source      weight provider (default)
--   setBonus    if true and the item is in a set, add its amortized set-bonus EP
--   useEffects  fold in on-use effect EP (default true; set false to exclude)
--   usePremium  on-use burst multiplier (default 1.3)
--   schools     the magic schools this spec actually casts, as a set { fire = true, ... }.
--               An item whose spell damage is restricted to other schools does not earn
--               that EP. Omit it and nothing changes. MINOR 24.
--   equipLoc    score the item AS this slot instead of the one it reports (MINOR 30). A
--               one-hander is INVTYPE_WEAPON and weights as a MAIN hand, so a planner placing
--               it in the off-hand passes "INVTYPE_WEAPONOFFHAND" to get the off-hand weight
--               and the off-hand proc rate. Omit it and nothing changes. Detect support on
--               lib.SCORE_OPTS_EQUIPLOC.
-- nil if there are no weights for that class/spec. An item's proc effect, if it
-- has one we can't score yet, is NOT reflected here — see HasUnscoredProc.
function lib:GetItemScore(itemID, classID, spec, opts)
    opts = opts or {}
    local w = self:GetBiSWeights(classID, spec, opts.source)
    if not w then return nil end
    local equipLoc = scoreEquipLoc(self, itemID, opts)
    local stats = self:GetStats(itemID)
    -- The gate applies to the ITEM'S OWN stats only. A set bonus, an on-use effect and a proc
    -- carry no school tag of their own, so there is nothing to gate them ON; passing the drop
    -- set down to those would silently zero every caster set bonus for every spec.
    local s = scoreStats(stats, w, equipLoc, nil, schoolDrop(self, itemID, opts))
    if opts.setBonus then
        local sid = self.itemSet[itemID]
        local set = sid and self.sets[sid]
        if set then
            local maxT = 0
            for n in pairs(set.bonuses) do maxT = math.max(maxT, tonumber(n) or 0) end
            if set.procs then
                for n in pairs(set.procs) do maxT = math.max(maxT, tonumber(n) or 0) end
            end
            if maxT > 0 then
                local ep = scoreStats(self:GetSetBonusStats(sid, maxT), w, equipLoc)
                if set.procs and opts.useEffects ~= false then
                    local model, hits = procContext(self, classID, spec, opts.source, opts.attack)
                    ep = ep + sumSetProcs(set, maxT, w, model, hits)
                end
                s = s + ep / math.max(#set.items, maxT)   -- amortized per piece
            end
        end
    end
    if opts.useEffects ~= false then
        local model = self:GetScoreModel(classID, spec, opts.source)
        if self.useEffects[itemID] then
            s = s + scoreUseEffects(self.useEffects[itemID], w, opts.usePremium or model.usePremium)
        end
        if self.procEffects[itemID] then
            local pmodel, hits = procContext(self, classID, spec, opts.source, opts.attack)
            s = s + scoreProcEffects(self.procEffects[itemID], w, pmodel, hits, equipLoc)
        end
    end
    s = s + runStatScorers(stats, w, opts)   -- weapon skill / ammo / ratings, per expansion
    return s
end

-- EP of an ARBITRARY stat table — a buff, consumable, enchant or talent's stats — scored
-- exactly the way GetItemScore scores an item's OWN stats: same weight scale, same key
-- folding, same melee-vs-ranged AP pairing (apPairEp), same per-hand weapon DPS, same weapon-skill
-- formula. A consumable's +40 spell power is then worth precisely what +40 spell power on
-- gear is worth, which is what makes a "gear vs. buffs vs. talents" comparison honest.
--
-- This has to live here rather than in the consumer, because the two data vocabularies
-- DIFFER: on Vanilla, Effects.lua speaks ITEM_MOD_MANA_REGENERATION / ITEM_MOD_SPELL_POWER
-- while the weight scales speak ITEM_MOD_POWER_REGEN0_SHORT / ITEM_MOD_SPELL_DAMAGE_DONE,
-- with zero overlap. The alias fold that bridges them is private to the expansion's rules
-- module, and every expansion's differs, so a consumer rolling its own Σ stat × weight scores
-- every mp5 and spell-power consumable at exactly 0 — silently, and differently per flavour.
--
-- Scores the stat table ONLY. Set bonuses, on-use and proc effects are keyed by item id and
-- can't be derived from a stat table; use GetItemScore for an actual item.
--   opts = { source, equipLoc, attack }  — all optional (source/attack as in GetItemScore;
--   equipLoc picks the per-hand DPS weight for a weapon's stats, nil for buffs).
-- nil when the arguments are incomplete or there are no weights for that class/spec.
function lib:ScoreStats(stats, classID, spec, opts)
    if type(stats) ~= "table" or not classID then return nil end
    opts = opts or {}
    local w = self:GetBiSWeights(classID, spec, opts.source)
    if not w then return nil end
    return scoreStats(stats, w, opts.equipLoc) + runStatScorers(stats, w, opts)
end

-- Itemized GetItemScore for a "why this EP" tooltip: { total, parts }, or nil when
-- GetItemScore is nil. Guaranteed by construction (it calls the same scorers with the
-- same opts): total == GetItemScore(itemID, classID, spec, opts), and Σ parts[i].ep ==
-- total. Each part = { kind = "stat"|"set"|"use"|"proc"|"weaponskill", key, label, value,
-- weight, ep, factors }. `ep` is the contribution (sum them for the total). **`factors`**
-- shows HOW the ep was derived: an ordered list of { label, value, pct? } whose values
-- MULTIPLY to `ep`, so a consumer can render "280 AP x 17% uptime x 1.3 x 0.55 = 33.4" for
-- any row, not just stats. `pct = true` means the value is a 0..1 fraction to show as a
-- percent (uptime, weapon-skill gain). Examples: a stat = { {amount}, {weight} }; an on-use
-- = { {magnitude}, {uptime,pct}, {premium}, {weight} }; a proc = magnitude x rate/uptime x
-- weight (per bucket); a set row = { {full set bonus}, {per piece = 1/N} } (amortized — the
-- per-STAGE values are in GetSetBonusEP). Generic Attack Power shows only the attack type
-- the pairing chose (both when a buff and a penalty meet -- see apPairEp), one row per stat
-- key / effect; use/proc are one row per effect. Localize a row via _G[key], else `label`.
function lib:GetItemScoreBreakdown(itemID, classID, spec, opts)
    opts = opts or {}
    local w = self:GetBiSWeights(classID, spec, opts.source)
    if not w then return nil end
    local equipLoc = scoreEquipLoc(self, itemID, opts)
    local parts = {}
    local stats = self:GetStats(itemID)
    -- Same gate, same helper, same argument position as GetItemScore -- see schoolDrop.
    -- The two functions must agree, and the docstring above promises they do.
    local total = scoreStats(stats, w, equipLoc, parts, schoolDrop(self, itemID, opts))
    if opts.setBonus then
        local sid = self.itemSet[itemID]
        local set = sid and self.sets[sid]
        if set then
            local maxT = 0
            for n in pairs(set.bonuses) do maxT = math.max(maxT, tonumber(n) or 0) end
            if set.procs then
                for n in pairs(set.procs) do maxT = math.max(maxT, tonumber(n) or 0) end
            end
            if maxT > 0 then
                local ep = scoreStats(self:GetSetBonusStats(sid, maxT), w, equipLoc)
                if set.procs and opts.useEffects ~= false then
                    local model, hits = procContext(self, classID, spec, opts.source, opts.attack)
                    ep = ep + sumSetProcs(set, maxT, w, model, hits)
                end
                local pieces = math.max(#set.items, maxT)
                local setEp = ep / pieces
                if setEp ~= 0 then
                    total = total + setEp
                    parts[#parts + 1] = { kind = "set", key = "SET_BONUS", value = ep, ep = setEp,
                        factors = { { label = "full set bonus", value = ep },
                                    { label = "per piece (1/"..pieces..")", value = 1 / pieces } } }
                end
            end
        end
    end
    if opts.useEffects ~= false then
        local model = self:GetScoreModel(classID, spec, opts.source)
        if self.useEffects[itemID] then
            total = total + scoreUseEffects(self.useEffects[itemID], w,
                                            opts.usePremium or model.usePremium, parts)
        end
        if self.procEffects[itemID] then
            local pmodel, hits = procContext(self, classID, spec, opts.source, opts.attack)
            total = total + scoreProcEffects(self.procEffects[itemID], w, pmodel, hits, equipLoc, parts)
        end
    end
    total = total + runStatScorers(stats, w, opts, parts)
    for _, p in ipairs(parts) do p.label = labelFor(p.key) end
    return { total = total, parts = parts }
end

-- EP of each set-bonus STAGE for a class/spec: { [threshold] = ep, ... } — the *full*
-- value of each stage (not the per-piece amortization GetItemScore uses), so a consumer
-- that knows how many pieces are equipped sums the stages it has crossed for the real set
-- contribution. Includes both flat-stat stages AND chance-on-hit proc stages (e.g.
-- Dragonstalker's 8-piece Expose Weakness) — the proc is priced here through the same
-- rate × value math item procs use, so a consumer that can't price procs itself still gets
-- the number. `attack` is optional paperdoll context ({ hitsPerSec = ... }); without it the
-- class default rate is used. nil if the set or the class/spec weights are unknown. (Stages
-- with no scoreable value — a pet buff, an unscored proc — are simply omitted.)
function lib:GetSetBonusEP(setID, classID, spec, source, attack)
    local s = self.sets[setID]
    if not s then return nil end
    local w = self:GetBiSWeights(classID, spec, source)
    if not w then return nil end
    local out = {}
    for n, blob in pairs(s.bonuses) do
        local ep = scoreStats(decodeStats(blob), w)
        if ep ~= 0 then out[tonumber(n) or n] = ep end
    end
    if s.procs then                       -- chance-on-hit stages (Tier 3), priced like item procs
        local model, hits = procContext(self, classID, spec, source, attack)
        for n, procRows in pairs(s.procs) do
            local ep = scoreProcEffects(procRows, w, model, hits, nil)
            if ep ~= 0 then
                local th = tonumber(n) or n
                out[th] = (out[th] or 0) + ep
            end
        end
    end
    return out
end

-- Rank item IDs for a class/spec, best first. opts: source, setBonus (as above);
-- slot (restrict to an INVTYPE_*); armorType (a subClassID); top (cap count);
-- keepDuplicates (keep every same-name variant instead of only the best-scoring
-- one). By default results the player can't use are dropped — the other faction's
-- items (opt out allFactions), gear the ranked classID can't use (opt out
-- allClasses), and hidden items (opt out includeHidden).
-- Returns { { id, score, name, link, equipLoc }, ... }.
--
-- Same-name dedup: several distinct item IDs can share one name and slot — the
-- four class versions of "Atiesh, Greatstaff of the Guardian", a base item and its
-- deprecated twin, etc. In a best-first ranking they read as pointless repeats, so
-- by default we keep only the highest-scoring one per (name, slot). That also picks
-- the class-appropriate variant automatically: the caster Atiesh outscores the
-- others for a caster, the healer one for a healer.
function lib:RankItems(itemIDs, classID, spec, opts)
    opts = opts or {}
    if not self:GetBiSWeights(classID, spec, opts.source) then return {} end
    local out = {}
    for _, id in ipairs(itemIDs) do
        local class, q, sub, equip = unpackCore(self.core[id])
        if class and (not opts.slot or equip == opts.slot)
           and (not opts.armorType or sub == opts.armorType)
           and (opts.allFactions or self:FactionUsable(id))
           and (opts.allClasses or self:ClassUsable(id, classID))
           and (opts.includeHidden or not self.hidden[id]) then
            local score = self:GetItemScore(id, classID, spec, opts)
            if score and score > 0 then
                out[#out + 1] = { id = id, score = score, name = self.names[id],
                                  equipLoc = equip, link = buildLink(id, q, self.names[id]) }
            end
        end
    end
    table.sort(out, function(a, b) return a.score > b.score end)
    if not opts.keepDuplicates then
        local seen, dedup = {}, {}
        for _, r in ipairs(out) do        -- sorted desc, so first seen = best
            local key = (r.name or r.id) .. SEP .. (r.equipLoc or "")
            if not seen[key] then seen[key] = true; dedup[#dedup + 1] = r end
        end
        out = dedup
    end
    for i = #out, (opts.top or #out) + 1, -1 do out[i] = nil end
    return out
end

-- An instance's drops ranked by EP for a class/spec — "what to want from this
-- raid". opts as RankItems (setBonus defaults ON). opts.perSlot groups the
-- result as { [equipLoc] = { ranked... } } instead of one flat list.
function lib:GetRaidBiS(instanceKey, classID, spec, opts)
    opts = opts or {}
    if opts.setBonus == nil then opts.setBonus = true end
    local ranked = self:RankItems(self:GetInstanceItems(instanceKey), classID, spec, opts)
    if not opts.perSlot then return ranked end
    local bySlot = {}
    for _, r in ipairs(ranked) do
        local slot = r.equipLoc or "?"
        local list = bySlot[slot]; if not list then list = {}; bySlot[slot] = list end
        list[#list + 1] = r
    end
    return bySlot
end

-- equipLoc -> array of every item id that occupies that slot, lazy, from core.
-- Invalidated by LoadCore. Items with no equip slot bucket under "" and are unreachable
-- through GetSlotRanking, which is correct: there is no slot to rank them in.
--
-- THIS IS A FIX, NOT TIDYING. GetSlotRanking with no `pool` used to materialise an array of
-- EVERY id in the database and hand all of them to RankItems, which unpackCore'd each one only
-- to discard the ~95% that are not in the slot. A Planner drawing one picker per slot pays that
-- whole-database walk once per slot: measured on the shipped Vanilla data (17,604 items,
-- desktop Lua 5.1) at 44 ms a call, 0.75 s for a 17-slot draw -- and the WoW client's
-- interpreter is several times slower again, which is enough on its own to trip the client's
-- "script ran too long" watchdog mid-draw. That is the v0.7.0 field report whose traceback
-- surfaced inside ScoreStats: the frame budget was already spent before the call it names.
--
-- Building it once also makes the ranking of TIED scores stable within a session. `pairs` order
-- is arbitrary and the old code re-walked it per call, so two identical requests could return
-- equal-scoring items in a different order.
local function slotIndex(self)
    if self._slotIndex then return self._slotIndex end
    local idx = {}
    for id, s in pairs(self.core) do
        local _, _, _, equip = unpackCore(s)
        local arr = idx[equip]
        if not arr then arr = {}; idx[equip] = arr end
        arr[#arr + 1] = id
    end
    self._slotIndex = idx
    return idx
end

-- Top items for one slot (an INVTYPE_*) for a class/spec -- the "top N helms, in
-- order". Ranks the whole DB, or opts.pool of IDs. opts as RankItems; top = 5.
function lib:GetSlotRanking(classID, spec, slot, opts)
    opts = opts or {}
    opts.slot = slot
    if opts.top == nil then opts.top = 5 end
    local pool = opts.pool
    if not pool then
        -- Only the items that can match, via slotIndex. A nil `slot` means "rank everything"
        -- and is the one caller that still needs the full set.
        if slot then
            pool = slotIndex(self)[slot] or {}
        else
            pool = {}
            for id in pairs(self.core) do pool[#pool + 1] = id end
        end
    end
    return self:RankItems(pool, classID, spec, opts)
end

-- ---------------------------------------------------------------------------
-- Iterator over every base item:
--   for id, name, quality, classID, subClassID, equipLoc, itemLevel in DB:Iterate()
-- ---------------------------------------------------------------------------
function lib:Iterate()
    local core, names = self.core, self.names
    local k
    return function()
        local s
        k, s = next(core, k)
        if k == nil then return nil end
        local class, q, sub, equip, ilvl = unpackCore(s)
        return k, names[k], q, class, sub, equip, ilvl
    end
end
