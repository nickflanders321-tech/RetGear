-- Battle.lua - the rules of the card duel (a pure engine: no frames, no game API, so it can be tested on its own).
-- Every card in the collection becomes a minion, a spell or a weapon, with stats and effects worked out from the
-- card itself, so a card always plays the same way. The duel follows the familiar rules: 30 health, a growing pool
-- of mana, 30-card decks, 7 minions a side, hand of 10, taunt, charge, divine shield, battlecries and deathrattles.
local ADDON, RG = ...
RG = RG or {}
local B = {}
RG.Battle = B
local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil

B.MAXMANA, B.MAXHAND, B.MAXBOARD, B.DECK, B.HP = 10, 10, 7, 30, 30
B.KW = { taunt = "Taunt", charge = "Charge", rush = "Rush", shield = "Divine Shield", stealth = "Stealth", windfury = "Windfury", lifesteal = "Lifesteal", poison = "Poisonous" }
B.KWORDER = { "taunt", "charge", "rush", "shield", "stealth", "windfury", "lifesteal", "poison" }
B.defs = {}

local function hash(s) local h = 5381; for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483629 end return h end
local function seeded(s) s = s % 2147483646 + 1; return function(n) s = (s * 48271) % 2147483647; return s % n + 1 end end
local function copy(t) local c = {}; for k, v in pairs(t) do c[k] = v end return c end

-- ---------------------------------------------------------------------------
-- Effects are small tables: { op = "dmg", n = 3, at = "t" }.  "at" says who it hits:
--   t = the chosen target, self = this minion, eface/fface = enemy/own hero, emin/fmin/min = all enemy/own/any minions,
--   fall = all your characters, all = everything, rand = random enemy character, randmin = random enemy minion
-- ---------------------------------------------------------------------------
local function dmg(n, at) return { op = "dmg", n = n, at = at or "t" } end
local function heal(n, at) return { op = "heal", n = n, at = at or "t" } end
local function buff(a, h, at, temp) return { op = "buff", a = a, h = h, at = at or "t", temp = temp } end
local function kwop(k, at) return { op = "kw", k = k, at = at or "t" } end
local function draw(n) return { op = "draw", n = n or 1 } end
local function armor(n) return { op = "armor", n = n } end
local function summon(n, tok) return { op = "summon", n = n, tok = tok } end
local function freeze(at) return { op = "freeze", at = at or "t" } end

local TOKENS = {   -- what summoning cards bring along
  beast = { name = "Wolf Pup", atk = 1, hp = 1, icon = "Ability_Hunter_Pet_Wolf" },
  undead = { name = "Skeleton", atk = 1, hp = 1, icon = "Spell_Shadow_AnimateDead" },
  demon = { name = "Imp", atk = 1, hp = 1, icon = "Spell_Shadow_SummonImp" },
  dragonkin = { name = "Whelp", atk = 1, hp = 1, icon = "INV_Misc_Head_Dragon_01" },
  elemental = { name = "Spark", atk = 1, hp = 1, icon = "Spell_Fire_Fire" },
  humanoid = { name = "Recruit", atk = 1, hp = 1, icon = "Ability_Warrior_Charge" },
  mechanical = { name = "Gizmo", atk = 1, hp = 1, icon = "INV_Misc_Gear_01" },
  creature = { name = "Hatchling", atk = 1, hp = 1, icon = "Ability_Hunter_Pet_Wolf" },
  guard = { name = "Guardian", atk = 1, hp = 2, icon = "INV_Shield_06", kw = { taunt = true } },
  image = { name = "Mirror Image", atk = 0, hp = 2, icon = "Spell_Magic_LesserInvisibilty", kw = { taunt = true } },
  recruit = { name = "Militia", atk = 1, hp = 1, icon = "Ability_Warrior_Charge" },
  hand = { name = "Silver Hand Recruit", atk = 1, hp = 1, icon = "Spell_Holy_PrayerOfHealing" },
}
local function tok(kind, n, a, h, extra)
  local t = copy(TOKENS[kind] or TOKENS.humanoid); t.atk = a or t.atk; t.hp = h or t.hp
  if extra then t.kw = copy(extra) end
  t.token = true
  return t
end
B.TOKENS = TOKENS

-- ---------------------------------------------------------------------------
-- Describing a card in words
-- ---------------------------------------------------------------------------
local function stat(a, h) if (h or 0) == 0 then return "+" .. a .. " Attack" end return "+" .. a .. "/+" .. h end
local function opText(o, first)
  local op, at = o.op, o.at
  if op == "dmg" then
    local who = ({ emin = " to all enemy minions", min = " to all minions", eface = " to the enemy hero", rand = " to a random enemy", randmin = " to a random enemy minion", fface = " to your hero", all = " to everything" })[at] or ""
    return "Deal " .. o.n .. " damage" .. who
  elseif op == "heal" then
    local who = ({ fface = " to your hero", fall = " to all friendly characters" })[at] or ""
    return "Restore " .. o.n .. " Health" .. who
  elseif op == "buff" then
    local s = (o.h == 0 and not o.temp) and stat(o.a, 0) or (o.h == 0 and ("+" .. o.a .. " Attack") or ("+" .. o.a .. "/+" .. o.h))
    local tail = o.temp and " this turn" or ""
    if at == "t" then return "Give a friendly minion " .. s .. tail elseif at == "fmin" then return "Give your minions " .. s .. tail else return "Gain " .. s .. tail end
  elseif op == "kw" then
    local k = B.KW[o.k]
    if at == "t" then return "Give a friendly minion " .. k elseif at == "fmin" then return "Give your minions " .. k else return "Gain " .. k end
  elseif op == "draw" then return o.n == 1 and "Draw a card" or ("Draw " .. o.n .. " cards")
  elseif op == "armor" then return "Gain " .. o.n .. " Armor"
  elseif op == "summon" then
    local t = o.tok or (o.pick and o.pick[1])
    if o.pick then return "Summon a random Totem" end
    local kws = ""
    if t.kw then local l = {}; for _, k in ipairs(B.KWORDER) do if t.kw[k] then l[#l + 1] = B.KW[k] end end; if #l > 0 then kws = " with " .. table.concat(l, ", ") end end
    if o.n == 1 then return "Summon a " .. t.atk .. "/" .. t.hp .. " " .. t.name .. kws end
    return "Summon " .. o.n .. " " .. t.atk .. "/" .. t.hp .. " " .. t.name .. "s" .. kws
  elseif op == "destroy" then return at == "all" and "Destroy all minions" or "Destroy a minion"
  elseif op == "freeze" then
    if at == "emin" then return "Freeze all enemy minions" end
    return first and "Freeze a character" or "Freeze it"
  elseif op == "silence" then return "Silence a minion"
  elseif op == "mana" then return "Gain " .. o.n .. " Mana Crystal" .. (o.n == 1 and "" or "s") .. " this turn only"
  elseif op == "weapon" then return "Equip a " .. o.a .. "/" .. o.d .. " weapon"
  end
  return ""
end
local function opsText(ops)
  local parts = {}
  local i = 1
  ops = ops or {}
  while i <= #ops do
    local o, n = ops[i], ops[i + 1]
    if o.op == "kw" and n and n.op == "kw" and n.at == o.at then
      parts[#parts + 1] = opText(o, i == 1) .. " and " .. B.KW[n.k]; i = i + 2
    else parts[#parts + 1] = opText(o, i == 1); i = i + 1 end
  end
  return table.concat(parts, ". ")
end
B.opsText = opsText

function B.describe(d)
  local parts = {}
  if d.type == "minion" then
    local l = {}
    for _, k in ipairs(B.KWORDER) do if d.kw and d.kw[k] then l[#l + 1] = B.KW[k] end end
    if #l > 0 then parts[#parts + 1] = table.concat(l, ", ") end
    if d.bc then parts[#parts + 1] = "Battlecry: " .. opsText(d.bc) end
    if d.dr then parts[#parts + 1] = "Deathrattle: " .. opsText(d.dr) end
    if d.eot then
      local t = opsText(d.eot)
      parts[#parts + 1] = "At the end of your turn, " .. t:sub(1, 1):lower() .. t:sub(2)
    end
  else
    parts[#parts + 1] = opsText(d.ops)
  end
  local s = table.concat(parts, ". ")
  if s ~= "" then s = s .. "." end
  return s
end

-- ---------------------------------------------------------------------------
-- Turning a card into a playable one
-- ---------------------------------------------------------------------------
local WEAPONS = {}
for w in ("sword blade axe dagger mace hammer staff stave wand spear polearm bow crossbow gun fist claw scythe reaver cleaver halberd glaive rapier scimitar katana talon slayer maul club cudgel lance pike knife thrasher bludgeon crusher rod flail whip"):gmatch("%a+") do WEAPONS[#WEAPONS + 1] = w end
local SLOT = {   -- piece of gear -> the sort of spell it becomes
  { "ring band signet seal loop", "buff" },
  { "boot treads sandals footwraps greaves stompers slippers walkers", "charge" },
  { "helm helmet crown circlet cowl hood mask coif visor", "silence" },
  { "chest breastplate vest tunic robe chestguard hauberk armor plate jerkin brigandine vestments", "armor" },
  { "shield buckler bulwark aegis barricade", "bastion" },
  { "cloak cape drape shroud mantle", "shadow" },
  { "gloves gauntlets bracers bindings wristguards handguards grips mitts fists", "frenzy" },
  { "belt girdle waistband cord sash", "mend" },
  { "pants leggings legguards kilt legplates breeches", "summon" },
  { "necklace amulet pendant choker talisman medallion charm idol libram totem relic orb sphere tome book scroll trinket figurine", "draw" },
  { "potion elixir flask vial phial", "heal" },
  { "shoulders shoulderpads spaulders pauldrons epaulets", "rally" },
}
local ZONE = {   -- places by their feel
  { "frost ice winter snow alterac dun glacier cold chill wintergrasp", "blizzard" },
  { "burning searing blackrock ember lava fire hell flame molten", "aoe" },
  { "plague scourge naxx dead stratholme dark tomb crypt grave undercity", "nova" },
  { "forest glade grove wood teldrassil elwynn moonglade duskwood darkshore ashenvale feralas", "mend" },
  { "stronghold keep fort gate watch hold bastion citadel", "bastion" },
  { "camp village town city harbor port market inn", "summon" },
  { "mountain peak spire highland range rock cliff crag", "quake" },
  { "swamp marsh mire pit fen", "freeze" },
}
local function words(s) local w = {}; for x in s:lower():gmatch("%a+") do w[#w + 1] = x end return w end
local function matchList(name, list)
  local ws = words(name)
  for _, row in ipairs(list) do
    for k in row[1]:gmatch("%a+") do
      for _, w in ipairs(ws) do
        if w == k or w == k .. "s" or (#k >= 4 and w:sub(-#k) == k) then return row[2] end
      end
    end
  end
end
local function isWeapon(name)
  for _, w in ipairs(words(name)) do
    for _, k in ipairs(WEAPONS) do if w == k or w == k .. "s" or (#k >= 4 and w:sub(-#k) == k) then return true end end
  end
end

-- spell archetypes: function(cost) -> ops, target spec, (cost override)
local ARCH = {}
ARCH.bolt = function(c) return { dmg(c <= 3 and c + 1 or c + 2) }, "any" end
ARCH.smite = function(c) return { dmg(c + 2) }, "emin" end
ARCH.burn = function(c) return { dmg(c + 2, "eface") } end
ARCH.heal = function(c) return { heal(c * 2 + 2) }, "friend" end
ARCH.mend = function(c) return { heal(c + 1, "fall") } end
ARCH.buff = function(c) local a = floor(c * 0.8 + 1); return { buff(a, c < 3 and a - 1 or a) }, "fmin" end
ARCH.rally = function(c) local n = max(1, floor(c / 3)); return { buff(n, c < 3 and 0 or n, "fmin") } end
ARCH.draw = function(c) return { draw(floor((c + 1) / 2)) } end
ARCH.aoe = function(c) return { dmg(ceil(c / 2), "emin") } end
ARCH.quake = function(c) return { dmg(max(1, ceil(c / 2) - (c >= 5 and 0 or 0)), "min") }, nil, max(c, 2) end
ARCH.armor = function(c) if c >= 3 then return { armor(c + 2), draw(1) } end return { armor(c * 2) } end
ARCH.summon = function(c) local n = min(3, floor(c / 2) + 1); local s = max(1, floor((2 * c + 1) / n / 2)); return { summon(n, tok("recruit", n, s, s)) } end
ARCH.kill = function(c) return { { op = "destroy", at = "t" } }, "emin", max(c, 4) end
ARCH.silence = function(c) return { { op = "silence", at = "t" }, draw(1) }, "min", 2 end
ARCH.freeze = function(c) return { dmg(c + 1), freeze("t") }, "enemy" end
ARCH.blizzard = function(c) return { dmg(max(1, ceil(c / 3)), "emin"), freeze("emin") }, nil, max(c, 3) end
ARCH.charge = function(c) return { buff(2, 0), kwop("charge") }, "fmin", min(c, 2) end
ARCH.bastion = function(c) return { kwop("taunt"), kwop("shield") }, "fmin", max(2, min(c, 4)) end
ARCH.shadow = function(c) return { buff(1, 0), kwop("stealth") }, "fmin", min(max(c, 1), 3) end
ARCH.frenzy = function(c) return { buff(floor(c / 2) + 1, 0, "fmin", true) }, nil, max(c, 2) end
ARCH.nova = function(c) local n = max(1, ceil(c / 2.5)); return { dmg(n, "emin"), heal(n, "fall") }, nil, max(c, 4) end
ARCH.coin = function() return { { op = "mana", n = 2 } }, nil, 0 end
ARCH.wipe = function() return { { op = "destroy", at = "all" } }, nil, 8 end
ARCH.tap = function() return { dmg(2, "fface"), draw(2) }, nil, 1 end
local POOLS = {
  { "bolt", "smite", "heal", "buff", "draw", "aoe", "silence", "charge", "shadow", "armor", "summon", "freeze", "tap", "burn", "frenzy" },
  { "bolt", "smite", "mend", "buff", "rally", "draw", "aoe", "armor", "summon", "freeze", "blizzard", "bastion", "nova", "kill", "burn", "frenzy" },
  { "bolt", "smite", "mend", "rally", "draw", "aoe", "quake", "armor", "summon", "kill", "nova", "frenzy", "blizzard", "burn" },
  { "bolt", "quake", "draw", "aoe", "summon", "rally", "kill", "burn", "frenzy" },
}
local function poolFor(c) return POOLS[c <= 2 and 1 or c <= 4 and 2 or c <= 6 and 3 or 4] end

-- minion features: each returns what it adds and what it costs in stats
local FEATURES = {}
local function F(name, minc, maxc, fn) FEATURES[name] = { min = minc, max = maxc, fn = fn } end
F("taunt", 1, 10, function(d) d.kw.taunt = true; return 1, 0.7 end)
F("charge", 1, 5, function(d) d.kw.charge = true; return 2, 0.3 end)
F("rush", 2, 8, function(d) d.kw.rush = true; return 1, 0.4 end)
F("shield", 1, 8, function(d) d.kw.shield = true; return 2, 0.5 end)
F("stealth", 2, 8, function(d) d.kw.stealth = true; return 1, 0.4 end)
F("windfury", 3, 10, function(d) d.kw.windfury = true; return 2, 0.35 end)
F("lifesteal", 2, 10, function(d) d.kw.lifesteal = true; return 2, 0.5 end)
F("poison", 2, 8, function(d) d.kw.poison = true; return 3, 0.5 end)
F("bc_dmg", 1, 10, function(d) local n = 1 + floor(d.cost / 3); d.bc = { dmg(n) }; d.tgt = "any"; return 2 * n end)
F("bc_heal", 2, 10, function(d) local n = d.cost; d.bc = { heal(n) }; d.tgt = "friend"; return 1 + floor(n / 3) end)
F("bc_buff", 2, 10, function(d) local n = d.cost >= 5 and 2 or 1; d.bc = { buff(n, n) }; d.tgt = "fmin"; return 2 * n end)
F("bc_draw", 3, 10, function(d) local n = d.cost >= 6 and 2 or 1; d.bc = { draw(n) }; return 2 * n end)
F("bc_armor", 2, 10, function(d) d.bc = { armor(d.cost) }; return ceil(d.cost / 2) end)
F("bc_aoe", 4, 10, function(d) d.bc = { dmg(1, "emin") }; return 3 end)
F("bc_summon", 3, 10, function(d) local n = d.cost >= 6 and 2 or 1; d.bc = { summon(n, tok(d.tribeTok or "humanoid")) }; return 2 * n end)
F("bc_freeze", 2, 10, function(d) d.bc = { freeze("t") }; d.tgt = "emin"; return 2 end)
F("bc_silence", 3, 10, function(d) d.bc = { { op = "silence", at = "t" } }; d.tgt = "min"; return 2 end)
F("bc_self", 2, 8, function(d) local n = max(2, floor(d.cost / 2)); d.bc = { dmg(n, "fface") }; return -n end)
F("dr_dmg", 2, 10, function(d) local n = 1 + floor(d.cost / 3); d.dr = { dmg(n, "rand") }; return 2 * n end)
F("dr_draw", 2, 10, function(d) d.dr = { draw(1) }; return 3 end)
F("dr_summon", 2, 10, function(d) local n = d.cost >= 6 and 2 or 1; d.dr = { summon(n, tok(d.tribeTok or "humanoid")) }; return 2 * n end)
F("dr_heal", 2, 10, function(d) d.dr = { heal(d.cost, "fface") }; return 1 + floor(d.cost / 3) end)
F("dr_buff", 3, 10, function(d) d.dr = { buff(1, 1, "fmin") }; return 3 end)
F("dr_armor", 2, 10, function(d) d.dr = { armor(d.cost) }; return ceil(d.cost / 2) end)
F("eot_heal", 2, 10, function(d) d.eot = { heal(1, "fall") }; return 2 end)
F("eot_dmg", 3, 10, function(d) d.eot = { dmg(1, "rand") }; return 3 end)
F("eot_buff", 4, 10, function(d) d.eot = { buff(1, 1, "self") }; return 3 end)
F("eot_armor", 2, 10, function(d) d.eot = { armor(1) }; return 2 end)

local TRIBE = {   -- feature, weight
  beast = { { "charge", 18 }, { "rush", 22 }, { "windfury", 8 }, { "bc_buff", 8 }, { "dr_summon", 6 }, { "poison", 5 } },
  humanoid = { { "taunt", 18 }, { "shield", 12 }, { "bc_heal", 8 }, { "bc_buff", 10 }, { "bc_dmg", 14 }, { "bc_draw", 6 }, { "bc_armor", 4 }, { "eot_heal", 3 }, { "stealth", 4 } },
  undead = { { "dr_summon", 18 }, { "dr_dmg", 12 }, { "dr_draw", 6 }, { "lifesteal", 8 }, { "taunt", 6 }, { "poison", 4 }, { "eot_dmg", 4 } },
  dragonkin = { { "bc_dmg", 22 }, { "bc_aoe", 8 }, { "windfury", 10 }, { "shield", 6 }, { "taunt", 6 }, { "lifesteal", 4 }, { "bc_summon", 6 } },
  elemental = { { "windfury", 14 }, { "bc_freeze", 14 }, { "eot_dmg", 8 }, { "dr_dmg", 10 }, { "stealth", 6 }, { "taunt", 6 } },
  demon = { { "bc_self", 20 }, { "lifesteal", 12 }, { "bc_dmg", 10 }, { "dr_dmg", 10 }, { "charge", 8 }, { "bc_draw", 5 } },
  giant = { { "taunt", 60 }, { "bc_aoe", 6 }, { "eot_buff", 6 } },
  mechanical = { { "shield", 40 }, { "dr_summon", 10 }, { "windfury", 6 }, { "bc_silence", 5 } },
  creature = { { "rush", 28 }, { "poison", 10 }, { "stealth", 12 }, { "charge", 8 }, { "taunt", 6 } },
}
local CLASSFEAT = {   -- raiders: two features by class
  WARRIOR = { "rush", "bc_dmg" }, PALADIN = { "shield", "taunt" }, HUNTER = { "rush", "windfury" }, ROGUE = { "stealth", "poison" },
  PRIEST = { "bc_heal", "eot_heal" }, MAGE = { "bc_dmg", "bc_freeze" }, WARLOCK = { "bc_self", "lifesteal" },
  SHAMAN = { "windfury", "bc_buff" }, DRUID = { "taunt", "bc_buff" },
}

local function pickWeighted(r, list, cost)
  local ok = {}
  local tot = 0
  for _, e in ipairs(list) do
    local f = FEATURES[e[1]]
    if f and cost >= f.min and cost <= f.max then ok[#ok + 1] = e; tot = tot + e[2] end
  end
  if tot == 0 then return nil end
  local roll = r(tot + 70) -- the remainder is "plain"
  if roll > tot then return nil end
  for _, e in ipairs(ok) do roll = roll - e[2]; if roll <= 0 then return e[1] end end
end

local function genMinion(c, r, cost, tribe, feats, bonus)
  local d = { type = "minion", cost = cost, kw = {}, tribe = tribe, tribeTok = TOKENS[tribe] and tribe or "humanoid" }
  local pen, atkHeavy = 0, 0
  local function add(name)
    local f = FEATURES[name]; if not f then return end
    local p, heavy = f.fn(d)
    pen = pen + (p or 0); atkHeavy = atkHeavy + (heavy or 0)
  end
  if feats then for _, n in ipairs(feats) do add(n) end
  else
    local n1 = pickWeighted(r, TRIBE[tribe] or TRIBE.humanoid, cost)
    if n1 then add(n1) end
    if bonus then   -- bosses carry a second feature
      local n2 = pickWeighted(r, TRIBE[tribe] or TRIBE.humanoid, cost)
      if n2 and n2 ~= n1 and not ((n1 or ""):sub(1, 2) == (n2 or ""):sub(1, 2) and n2:find("_")) then add(n2) end
    end
  end
  local tot = max(2, 2 * cost + 1 + (bonus and 2 or 0) - pen + (r(3) - 2))
  local frac = 0.5 + (d.kw.taunt and 0.12 or 0) - atkHeavy * 0.25
  local hp = max(1, floor(tot * frac + 0.5)); local atk = tot - hp
  if atk < 1 and not d.kw.taunt then atk = 1; hp = max(1, tot - 1) end
  if d.kw.taunt and atk < 0 then atk = 0 end
  d.atk, d.hp = atk, hp
  return d
end

local function genSpell(c, r, cost, arch)
  local fn = ARCH[arch] or ARCH.bolt
  local ops, tgt, newCost = fn(cost)
  return { type = "spell", cost = newCost or cost, ops = ops, tgt = tgt }
end

local function genWeapon(c, r, cost)
  local dur = cost >= 5 and (2 + r(2)) or (1 + r(2)); dur = max(2, dur)
  if cost <= 1 then dur = 2 + r(2) end
  local atk = max(1, floor((2 * cost + 1) / dur + 0.5))
  if cost <= 1 then atk = 1 end
  return { type = "weapon", cost = cost, atk = atk, dur = dur, ops = { { op = "weapon", a = atk, d = dur } } }
end

-- build the playable form of a collection card: { kind, name, tier, text, key }
function B.derive(c)
  local key = c.key or c.name
  local r = seeded(hash(key .. "#" .. (c.kind or 0)))
  local d
  local kind, tier = c.kind, c.tier or 1
  if kind == 2 then
    local tribe = (c.text or ""):match("(%a+)$") or "creature"
    if not TRIBE[tribe] then tribe = "creature" end
    local cost = tier >= 5 and (5 + r(5)) or tier >= 3 and (2 + r(4)) or r(4)
    d = genMinion(c, r, cost, tribe, nil, tier >= 5)
  elseif kind == 4 then
    local cost = 6 + r(5); if cost > 10 then cost = 10 end
    d = genMinion(c, r, cost, "humanoid", CLASSFEAT[c.class or ""] or { "taunt" }, true)
    d.class = c.class
  elseif kind == 1 then
    if isWeapon(c.name) then
      local cost = tier >= 5 and (5 + r(4)) or (1 + r(5))
      d = genWeapon(c, r, cost)
    else
      local cost = tier >= 5 and (5 + r(4)) or (1 + r(5))
      local arch = matchList(c.name, SLOT)
      if arch == nil or r(100) <= 15 then local p = poolFor(cost); arch = p[r(#p)] end
      if cost == 1 and r(12) == 1 then arch = "coin" end
      if tier >= 5 and cost >= 8 and r(3) == 1 then arch = "wipe" end
      d = genSpell(c, r, cost, arch)
    end
  else
    local cost = tier >= 3 and (5 + r(3)) or tier == 2 and (3 + r(3)) or r(3)
    local arch = matchList(c.name .. " " .. (c.text or ""), ZONE)
    if arch == nil or r(100) <= 20 then local p = poolFor(cost); arch = p[r(#p)] end
    d = genSpell(c, r, cost, arch)
  end
  d.key, d.name, d.kind, d.tier, d.lore = key, c.name, kind, tier, c.text
  d.cost = max(0, min(10, d.cost))
  d.text = B.describe(d)
  B.defs[key] = d
  return d
end

-- ready-made cards everyone can use (so a new collection still makes a deck)
local BASIC_LIST = {
  { "Elwynn Boar", "minion", 1, 1, 1, "Ability_Hunter_Pet_Boar", kw = { charge = true } },
  { "Defias Cutpurse", "minion", 1, 2, 1, "Ability_Rogue_Sprint" },
  { "Stormwind Page", "minion", 1, 1, 2, "INV_Misc_Note_01", kw = { shield = true } },
  { "River Crocolisk", "minion", 2, 2, 3, "Ability_Hunter_Pet_Crocolisk" },
  { "Voodoo Doctor", "minion", 2, 2, 1, "Spell_Holy_HolyBolt", bc = { heal(2) }, tgt = "any" },
  { "Ironforge Rifleman", "minion", 3, 2, 2, "INV_Weapon_Rifle_01", bc = { dmg(1) }, tgt = "any" },
  { "Darkshire Watchman", "minion", 3, 2, 4, "INV_Shield_05", kw = { taunt = true } },
  { "Gnomish Inventor", "minion", 4, 2, 4, "INV_Misc_Gear_03", bc = { draw(1) } },
  { "Frostmane Yeti", "minion", 4, 4, 5, "Ability_Hunter_Pet_Bear" },
  { "Orgrimmar Grunt", "minion", 3, 3, 3, "Ability_Warrior_Charge" },
  { "Booty Bay Bodyguard", "minion", 5, 5, 4, "INV_Shield_06", kw = { taunt = true } },
  { "Stormpike Commando", "minion", 5, 4, 2, "Ability_Warrior_Rampage", bc = { dmg(2) }, tgt = "any" },
  { "Boulderfist Ogre", "minion", 6, 6, 7, "Ability_Hunter_Pet_Gorilla" },
  { "War Golem", "minion", 7, 7, 7, "INV_Misc_Gear_01" },
  { "Fireball", "spell", 4, nil, nil, "Spell_Fire_FlameBolt", ops = { dmg(6) }, tgt = "any" },
  { "Frost Shock", "spell", 2, nil, nil, "Spell_Frost_FrostShock", ops = { dmg(2), freeze("t") }, tgt = "enemy" },
  { "Holy Light", "spell", 2, nil, nil, "Spell_Holy_HolyBolt", ops = { heal(6) }, tgt = "friend" },
  { "Blessing of Kings", "spell", 4, nil, nil, "Spell_Magic_MageArmor", ops = { buff(4, 4) }, tgt = "fmin" },
  { "Arcane Intellect", "spell", 3, nil, nil, "Spell_Holy_MagicalSentry", ops = { draw(2) } },
  { "Consecration", "spell", 4, nil, nil, "Spell_Holy_InnerFire", ops = { dmg(2, "emin") } },
  { "Fiery War Axe", "weapon", 2, 3, 2, "INV_Axe_09" },
  { "Light's Justice", "weapon", 1, 1, 4, "INV_Mace_02" },
}
B.BASIC = {}
function B.registerBasics()
  for _, b in ipairs(BASIC_LIST) do
    local d = { type = b[2], cost = b[3], name = b[1], key = "b:" .. b[1], tier = 1, kind = 0, basic = true, icon = b[6] }
    if b[2] == "minion" then d.atk, d.hp, d.kw, d.bc, d.tgt = b[4], b[5], copy(b.kw or {}), b.bc, b.tgt
    elseif b[2] == "spell" then d.ops, d.tgt = b.ops, b.tgt
    else d.atk, d.dur = b[4], b[5]; d.ops = { { op = "weapon", a = b[4], d = b[5] } } end
    d.text = B.describe(d)
    B.defs[d.key] = d; B.BASIC[#B.BASIC + 1] = d.key
  end
  B.defs.coin = { type = "spell", cost = 0, name = "Lucky Coin", key = "coin", tier = 1, kind = 0, icon = "INV_Misc_Coin_01", ops = { { op = "mana", n = 1 } }, special = true }
  B.defs.coin.text = "Gain 1 Mana Crystal this turn only."
end
B.registerBasics()

-- ---------------------------------------------------------------------------
-- Heroes and their powers
-- ---------------------------------------------------------------------------
B.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
B.HERO = {
  WARRIOR = { title = "Warrior", power = "Armor Up!", cost = 2, ops = { armor(2) }, text = "Gain 2 Armor." },
  PALADIN = { title = "Paladin", power = "Reinforce", cost = 2, ops = { summon(1, tok("hand")) }, text = "Summon a 1/1 Silver Hand Recruit." },
  HUNTER = { title = "Hunter", power = "Steady Shot", cost = 2, ops = { dmg(2, "eface") }, text = "Deal 2 damage to the enemy hero." },
  ROGUE = { title = "Rogue", power = "Dagger Mastery", cost = 2, ops = { { op = "weapon", a = 1, d = 2 } }, text = "Equip a 1/2 Dagger." },
  PRIEST = { title = "Priest", power = "Lesser Heal", cost = 2, ops = { heal(2) }, tgt = "any", text = "Restore 2 Health." },
  SHAMAN = { title = "Shaman", power = "Totemic Call", cost = 2, ops = { { op = "summon", n = 1, pick = {
    { name = "Searing Totem", atk = 1, hp = 1, icon = "Spell_Fire_SearingTotem", token = true },
    { name = "Stoneclaw Totem", atk = 0, hp = 2, icon = "Spell_Nature_StoneClawTotem", kw = { taunt = true }, token = true },
    { name = "Healing Totem", atk = 0, hp = 2, icon = "Spell_Nature_HealingWaveGreater", token = true, eot = { heal(1, "fall") } },
  } } }, text = "Summon a random Totem." },
  MAGE = { title = "Mage", power = "Fireblast", cost = 2, ops = { dmg(1) }, tgt = "any", text = "Deal 1 damage." },
  WARLOCK = { title = "Warlock", power = "Life Tap", cost = 2, ops = { dmg(2, "fface"), draw(1) }, text = "Draw a card and take 2 damage." },
  DRUID = { title = "Druid", power = "Shapeshift", cost = 2, ops = { { op = "hero", a = 1 }, armor(1) }, text = "+1 Attack this turn. +1 Armor." },
}
B.OPPONENTS = {
  WARRIOR = "Grakthar the Unyielding", PALADIN = "Aldric Dawnward", HUNTER = "Sylvara Swiftbow", ROGUE = "Vex Nightblade", PRIEST = "Mother Elowen",
  SHAMAN = "Hargul Stormtongue", MAGE = "Archmage Ilyra", WARLOCK = "Malvek the Pale", DRUID = "Thalor Greenmane",
}

-- ---------------------------------------------------------------------------
-- The game
-- ---------------------------------------------------------------------------
local function rnd(G, n) G.seed = (G.seed * 48271) % 2147483647; return G.seed % n + 1 end
B.rnd = rnd
local function ev(G, e) if not G.sim then G.ev[#G.ev + 1] = e end end
function B.ref(o) if o.isHero then return "h" .. o.side end return o.uid end
function B.char(G, ref)
  if ref == nil then return nil end
  if type(ref) == "string" then local s = tonumber(ref:sub(2)); return G.p[s] end
  for s = 1, 2 do for _, m in ipairs(G.p[s].board) do if m.uid == ref then return m end end end
end
local function shuffle(G, t) for i = #t, 2, -1 do local j = rnd(G, i); t[i], t[j] = t[j], t[i] end end

function B.new(o)
  local G = { seed = (o.seed or 777) % 2147483646 + 1, uid = 0, turn = 0, cur = 0, p = {}, ev = {}, over = false, winner = nil, sim = false, phase = "mull", mull = { false, false } }
  for s = 1, 2 do
    local deck = {}
    for i, k in ipairs(o.decks[s]) do deck[i] = k end
    local P = { side = s, isHero = true, name = o.names and o.names[s] or ("Player " .. s), class = o.classes and o.classes[s] or "WARRIOR",
                hp = B.HP, maxhp = B.HP, armor = 0, mana = 0, maxMana = 0, deck = deck, hand = {}, board = {}, weapon = false, att = 0, tempAtk = 0,
                hpUsed = false, fatigue = 0, frozen = false, spent = 0, atk = 0 }
    shuffle(G, deck)
    G.p[s] = P
  end
  G.first = o.first or rnd(G, 2)
  for s = 1, 2 do
    local n = (s == G.first) and 3 or 4
    for _ = 1, n do local k = table.remove(G.p[s].deck); if k then G.p[s].hand[#G.p[s].hand + 1] = k end end
  end
  local second = 3 - G.first
  G.p[second].hand[#G.p[second].hand + 1] = "coin"
  return G
end

local function draw1(G, s)
  local P = G.p[s]
  local k = table.remove(P.deck)
  if not k then
    P.fatigue = P.fatigue + 1
    ev(G, { t = "fatigue", side = s, n = P.fatigue })
    B.damage(G, P, P.fatigue)
    return
  end
  if #P.hand >= B.MAXHAND then ev(G, { t = "burn", side = s, key = k }); return end
  P.hand[#P.hand + 1] = k
  ev(G, { t = "draw", side = s, key = k })
end

-- replace the cards you do not want in your opening hand (set: { [handIndex] = true })
function B.mulligan(G, s, set)
  if G.phase ~= "mull" or G.mull[s] then return false end
  local P = G.p[s]
  local back = {}
  for i = #P.hand, 1, -1 do
    if set and set[i] and P.hand[i] ~= "coin" then
      local fresh = table.remove(P.deck)
      back[#back + 1] = P.hand[i]
      if fresh then P.hand[i] = fresh end
    end
  end
  for _, k in ipairs(back) do P.deck[#P.deck + 1] = k end
  if #back > 0 then shuffle(G, P.deck) end
  G.mull[s] = true
  if G.mull[1] and G.mull[2] then B.startGame(G) end
  return true
end

function B.startGame(G)
  G.phase = "play"
  G.cur = G.first; G.turn = 1
  B.beginTurn(G)
end

function B.beginTurn(G)
  local s = G.cur
  local P = G.p[s]
  P.maxMana = min(B.MAXMANA, P.maxMana + 1); P.mana = P.maxMana; P.spent = 0
  P.att, P.tempAtk, P.hpUsed = 0, 0, false
  for _, m in ipairs(P.board) do m.sick = false; m.att = 0; m.rushOnly = nil end
  ev(G, { t = "turn", side = s, n = G.turn })
  draw1(G, s)
  B.resolve(G)
end

function B.endTurn(G, s)
  if G.over or G.phase ~= "play" or G.cur ~= s then return false end
  local P = G.p[s]
  for _, m in ipairs({ unpack(P.board) }) do
    if m.eot and not m.silenced and m.hp > 0 then B.apply(G, s, m.eot, nil, m) end
  end
  for _, m in ipairs(P.board) do
    if m.tempA and m.tempA ~= 0 then m.atk = m.atk - m.tempA; m.tempA = 0 end
    if m.frozen then m.frozen = false end
  end
  P.frozen = false; P.tempAtk = 0
  B.resolve(G)
  if G.over then return true end
  G.cur = 3 - s
  if G.cur == G.first then G.turn = G.turn + 1 end
  B.beginTurn(G)
  return true
end

function B.heroAtk(P) return (P.weapon and P.weapon.atk or 0) + (P.tempAtk or 0) end

-- ----- damage and friends -----
function B.damage(G, t, n, src, combat)
  if not t or n <= 0 then return 0 end
  local dealt = n
  if t.isHero then
    local a = min(t.armor, n); t.armor = t.armor - a
    t.hp = t.hp - (n - a)
    ev(G, { t = "dmg", tgt = B.ref(t), n = n })
  else
    if t.kw.shield then t.kw.shield = nil; ev(G, { t = "pop", tgt = t.uid }); return 0 end
    t.hp = t.hp - n
    if combat and src and src.kw and src.kw.poison then t.hp = min(t.hp, 0) end
    ev(G, { t = "dmg", tgt = t.uid, n = n })
  end
  if src and src.kw and src.kw.lifesteal and src.side then B.heal(G, G.p[src.side], dealt) end
  return dealt
end
function B.heal(G, t, n)
  if not t or n <= 0 then return end
  local before = t.hp
  t.hp = min(t.maxhp, t.hp + n)
  if t.hp > before then ev(G, { t = "heal", tgt = B.ref(t), n = t.hp - before }) end
end

local function mkMinion(G, s, d)
  G.uid = G.uid + 1
  return { uid = G.uid, seq = G.uid, side = s, key = d.key, name = d.name, icon = d.icon, token = d.token, atk = d.atk, hp = d.hp, maxhp = d.hp,
           kw = copy(d.kw or {}), sick = true, att = 0, frozen = false, cost = d.cost, tribe = d.tribe, dr = d.dr, eot = d.eot, kind = d.kind, tier = d.tier }
end
function B.summonMinion(G, s, d, pos)
  local P = G.p[s]
  if #P.board >= B.MAXBOARD then return nil end
  local m = mkMinion(G, s, d)
  if pos and pos >= 1 and pos <= #P.board then table.insert(P.board, pos, m) else P.board[#P.board + 1] = m end
  ev(G, { t = "summon", tgt = m.uid, side = s })
  return m
end

-- who counts as a legal target
function B.targets(G, s, spec)
  local me, foe = G.p[s], G.p[3 - s]
  local out = {}
  local function add(o) out[#out + 1] = o end
  local function foes() for _, m in ipairs(foe.board) do if not m.kw.stealth and m.hp > 0 then add(m) end end end
  local function mine() for _, m in ipairs(me.board) do if m.hp > 0 then add(m) end end end
  if spec == "any" then add(me); add(foe); mine(); foes()
  elseif spec == "enemy" then add(foe); foes()
  elseif spec == "emin" then foes()
  elseif spec == "fmin" then mine()
  elseif spec == "min" then mine(); foes()
  elseif spec == "friend" then add(me); mine() end
  return out
end

local function scope(G, s, at, src)
  local me, foe = G.p[s], G.p[3 - s]
  local out = {}
  local function mins(P) for _, m in ipairs(P.board) do if m.hp > 0 then out[#out + 1] = m end end end
  if at == "emin" then mins(foe)
  elseif at == "fmin" then mins(me)
  elseif at == "min" then mins(me); mins(foe)
  elseif at == "eface" then out[1] = foe
  elseif at == "fface" then out[1] = me
  elseif at == "fall" then out[1] = me; mins(me)
  elseif at == "all" then out[1] = me; out[2] = foe; mins(me); mins(foe)
  elseif at == "self" then if src then out[1] = src end
  elseif at == "rand" or at == "randmin" then
    local c = {}
    if at == "rand" then c[#c + 1] = foe end
    for _, m in ipairs(foe.board) do if m.hp > 0 then c[#c + 1] = m end end
    if #c > 0 then out[1] = c[rnd(G, #c)] end
  end
  return out
end

function B.apply(G, s, ops, target, src)
  local me = G.p[s]
  for _, o in ipairs(ops or {}) do
    local op = o.op
    local list
    if o.at == "t" then list = target and { target } or {} else list = scope(G, s, o.at, src) end
    if op == "dmg" then for _, t in ipairs(list) do B.damage(G, t, o.n, nil) end
    elseif op == "heal" then for _, t in ipairs(list) do B.heal(G, t, o.n) end
    elseif op == "buff" then
      for _, t in ipairs(list) do
        if not t.isHero then
          t.atk = t.atk + o.a; t.hp = t.hp + o.h; t.maxhp = t.maxhp + o.h
          if o.temp then t.tempA = (t.tempA or 0) + o.a end
          ev(G, { t = "buff", tgt = t.uid })
        end
      end
    elseif op == "kw" then for _, t in ipairs(list) do if not t.isHero then t.kw[o.k] = true; if o.k == "charge" then t.sick = false end; ev(G, { t = "buff", tgt = t.uid }) end end
    elseif op == "draw" then for _ = 1, o.n do draw1(G, s) end
    elseif op == "armor" then me.armor = me.armor + o.n; ev(G, { t = "armor", tgt = B.ref(me), n = o.n })
    elseif op == "summon" then
      for _ = 1, o.n do
        local d = o.pick and o.pick[rnd(G, #o.pick)] or o.tok
        B.summonMinion(G, s, d)
      end
    elseif op == "destroy" then
      if o.at == "all" then for _, t in ipairs(scope(G, s, "min")) do t.hp = 0 end
      else for _, t in ipairs(list) do if not t.isHero then t.hp = 0 end end end
    elseif op == "freeze" then for _, t in ipairs(list) do t.frozen = true; ev(G, { t = "freeze", tgt = B.ref(t) }) end
    elseif op == "silence" then
      for _, t in ipairs(list) do
        if not t.isHero then t.kw = {}; t.dr = nil; t.eot = nil; t.silenced = true; t.frozen = false; ev(G, { t = "silence", tgt = t.uid }) end
      end
    elseif op == "mana" then me.mana = min(B.MAXMANA, me.mana + o.n)
    elseif op == "weapon" then me.weapon = { atk = o.a, dur = o.d, name = o.name or "Weapon" }; ev(G, { t = "weapon", side = s })
    elseif op == "hero" then me.tempAtk = (me.tempAtk or 0) + o.a
    end
  end
end

function B.resolve(G)
  for _ = 1, 40 do
    local dead = {}
    for s = 1, 2 do for _, m in ipairs(G.p[s].board) do if m.hp <= 0 then dead[#dead + 1] = m end end end
    if #dead == 0 then break end
    table.sort(dead, function(a, b) return a.seq < b.seq end)
    for _, m in ipairs(dead) do
      local P = G.p[m.side]
      for i, x in ipairs(P.board) do if x == m then table.remove(P.board, i); break end end
      ev(G, { t = "die", tgt = m.uid, side = m.side, key = m.key, name = m.name })
    end
    for _, m in ipairs(dead) do
      if m.dr and not m.silenced then B.apply(G, m.side, m.dr, nil, m) end
    end
  end
  if not G.over then
    local a, b = G.p[1].hp <= 0, G.p[2].hp <= 0
    if a or b then
      G.over = true
      G.winner = (a and b) and 0 or (a and 2 or 1)
      ev(G, { t = "over", winner = G.winner })
    end
  end
end

-- ----- playing -----
local function contains(list, x) for _, v in ipairs(list) do if v == x then return true end end end

function B.canPlay(G, s, hi)
  if G.over or G.phase ~= "play" or G.cur ~= s then return false, "It is not your turn." end
  local P = G.p[s]
  local key = P.hand[hi]; local d = key and B.defs[key]
  if not d then return false, "No such card." end
  if d.cost > P.mana then return false, "Not enough mana." end
  if d.type == "minion" and #P.board >= B.MAXBOARD then return false, "Your board is full." end
  if d.type == "spell" and d.tgt and #B.targets(G, s, d.tgt) == 0 then return false, "There is no valid target." end
  return true
end

-- does playing this card need you to choose something? (spells always do if they have a target; battlecries only when one exists)
function B.needsTarget(G, s, hi)
  local d = B.defs[G.p[s].hand[hi]]
  if not d or not d.tgt then return nil end
  if #B.targets(G, s, d.tgt) == 0 then return nil end
  return d.tgt
end

function B.play(G, s, hi, tref, pos)
  local ok, why = B.canPlay(G, s, hi)
  if not ok then return false, why end
  local P = G.p[s]
  local key = P.hand[hi]; local d = B.defs[key]
  local tg
  if d.tgt and #B.targets(G, s, d.tgt) > 0 then
    tg = B.char(G, tref)
    if not tg or not contains(B.targets(G, s, d.tgt), tg) then return false, "Choose a valid target." end
  end
  P.mana = P.mana - d.cost; P.spent = P.spent + d.cost
  table.remove(P.hand, hi)
  ev(G, { t = "play", side = s, key = key })
  if d.type == "minion" then
    local m = B.summonMinion(G, s, d, pos)
    if m then
      if d.bc then B.apply(G, s, d.bc, tg, m) end
    end
  elseif d.type == "spell" then
    B.apply(G, s, d.ops, tg, nil)
  else
    P.weapon = { atk = d.atk, dur = d.dur, name = d.name, key = key }
    ev(G, { t = "weapon", side = s })
  end
  B.resolve(G)
  return true
end

-- ----- attacking -----
function B.canAttack(G, s, a)
  if G.over or G.phase ~= "play" or G.cur ~= s then return false, "It is not your turn." end
  if a.side ~= s then return false end
  if a.isHero then
    if a.frozen then return false, "Your hero is frozen." end
    if B.heroAtk(a) <= 0 then return false, "Your hero has no attack." end
    if a.att >= 1 then return false, "Your hero has already attacked." end
    return true
  end
  if a.frozen then return false, "That minion is frozen." end
  if a.atk <= 0 then return false, "That minion has no attack." end
  if a.att >= (a.kw.windfury and 2 or 1) then return false, "That minion has already attacked." end
  if a.sick and not (a.kw.charge or a.kw.rush) then return false, "That minion needs a turn to get ready." end
  return true
end

function B.attackTargets(G, s, a)
  local foe = G.p[3 - s]
  local seen, taunts = {}, {}
  for _, m in ipairs(foe.board) do
    if not m.kw.stealth and m.hp > 0 then seen[#seen + 1] = m; if m.kw.taunt then taunts[#taunts + 1] = m end end
  end
  if #taunts > 0 then return taunts end
  local out = {}
  local rushOnly = (not a.isHero) and a.sick and a.kw.rush and not a.kw.charge
  if not rushOnly then out[1] = foe end
  for _, m in ipairs(seen) do out[#out + 1] = m end
  return out
end

function B.attack(G, s, aref, dref)
  local a, d = B.char(G, aref), B.char(G, dref)
  if not a or not d then return false, "Bad target." end
  local ok, why = B.canAttack(G, s, a)
  if not ok then return false, why end
  if not contains(B.attackTargets(G, s, a), d) then return false, "You cannot attack that." end
  ev(G, { t = "attack", a = B.ref(a), d = B.ref(d) })
  local atk = a.isHero and B.heroAtk(a) or a.atk
  a.att = a.att + 1
  if a.kw then a.kw.stealth = nil end
  B.damage(G, d, atk, a, true)
  if not d.isHero then B.damage(G, a, d.atk, d, true) end
  if a.isHero and a.weapon then
    a.weapon.dur = a.weapon.dur - 1
    if a.weapon.dur <= 0 then a.weapon = false end
  end
  B.resolve(G)
  return true
end

function B.canHeroPower(G, s)
  if G.over or G.phase ~= "play" or G.cur ~= s then return false end
  local P = G.p[s]; local h = B.HERO[P.class]
  if P.hpUsed then return false, "You already used your hero power." end
  if P.mana < h.cost then return false, "Not enough mana." end
  if h.ops[1].op == "summon" and not h.ops[1].pick and #P.board >= B.MAXBOARD then return false, "Your board is full." end
  if h.tgt and #B.targets(G, s, h.tgt) == 0 then return false end
  return true
end
function B.heroPower(G, s, tref)
  local ok, why = B.canHeroPower(G, s)
  if not ok then return false, why end
  local P = G.p[s]; local h = B.HERO[P.class]
  local tg
  if h.tgt then tg = B.char(G, tref); if not tg or not contains(B.targets(G, s, h.tgt), tg) then return false, "Choose a target." end end
  P.mana = P.mana - h.cost; P.spent = P.spent + h.cost; P.hpUsed = true
  ev(G, { t = "power", side = s })
  B.apply(G, s, h.ops, tg, nil)
  B.resolve(G)
  return true
end

-- ---------------------------------------------------------------------------
-- A computer opponent: tries every move, looks at how the board would end up, and picks the best
-- ---------------------------------------------------------------------------
local function cloneMinion(m) local c = copy(m); c.kw = copy(m.kw); return c end
function B.clone(G)
  local C = copy(G)
  C.ev, C.sim = {}, true
  C.p = {}
  for s = 1, 2 do
    local P = G.p[s]
    local Q = copy(P)
    Q.deck, Q.hand, Q.board = copy(P.deck), copy(P.hand), {}
    for i, m in ipairs(P.board) do Q.board[i] = cloneMinion(m) end
    if P.weapon then Q.weapon = copy(P.weapon) end
    C.p[s] = Q
  end
  return C
end

local function minionValue(m)
  if m.hp <= 0 then return 0 end
  local v = m.atk * 1.6 + m.hp * 1.2 + 0.8
  if m.kw.taunt then v = v + 1.3 + m.hp * 0.25 end
  if m.kw.shield then v = v + m.atk * 0.9 + 1 end
  if m.kw.windfury then v = v + m.atk * 1.1 end
  if m.kw.lifesteal then v = v + m.atk * 0.8 + 0.5 end
  if m.kw.poison then v = v + 2.5 end
  if m.kw.stealth then v = v + 0.6 end
  if m.dr then v = v + 1.2 end
  if m.eot then v = v + 1.6 end
  if m.frozen then v = v - m.atk * 0.7 end
  return v
end
function B.eval(G, s)
  local me, foe = G.p[s], G.p[3 - s]
  if G.over then return G.winner == s and 1000 or (G.winner == 0 and 0 or -1000) end
  local v = 0
  for _, m in ipairs(me.board) do v = v + minionValue(m) end
  for _, m in ipairs(foe.board) do v = v - minionValue(m) * 1.05 end
  v = v + (me.hp + me.armor * 0.85) - 1.2 * (foe.hp + foe.armor * 0.85)
  if foe.hp <= 8 then v = v + (8 - foe.hp) * 1.4 end
  if me.hp <= 10 then v = v - (10 - me.hp) * 0.7 end
  v = v + 1.6 * #me.hand - 0.9 * #foe.hand
  if me.weapon then v = v + me.weapon.atk * me.weapon.dur * 0.9 end
  if foe.weapon then v = v - foe.weapon.atk * foe.weapon.dur * 0.9 end
  v = v + 0.25 * me.spent
  if me.frozen then v = v - 1 end
  return v
end

function B.actions(G, s)
  local acts, P = {}, G.p[s]
  local seen = {}
  for i, key in ipairs(P.hand) do
    local d = B.defs[key]
    if d and not seen[key] and B.canPlay(G, s, i) then
      seen[key] = true
      local need = B.needsTarget(G, s, i)
      if need then for _, t in ipairs(B.targets(G, s, d.tgt)) do acts[#acts + 1] = { t = "play", i = i, tgt = B.ref(t) } end
      else acts[#acts + 1] = { t = "play", i = i } end
    end
  end
  local atk = {}
  if B.canAttack(G, s, P) then atk[#atk + 1] = P end
  for _, m in ipairs(P.board) do if B.canAttack(G, s, m) then atk[#atk + 1] = m end end
  for _, a in ipairs(atk) do
    for _, d in ipairs(B.attackTargets(G, s, a)) do acts[#acts + 1] = { t = "att", a = B.ref(a), d = B.ref(d) } end
  end
  if B.canHeroPower(G, s) then
    local h = B.HERO[P.class]
    if h.tgt then for _, t in ipairs(B.targets(G, s, h.tgt)) do acts[#acts + 1] = { t = "hp", tgt = B.ref(t) } end
    else acts[#acts + 1] = { t = "hp" } end
  end
  return acts
end

function B.exec(G, s, act)
  if act.t == "play" then return B.play(G, s, act.i, act.tgt)
  elseif act.t == "att" then return B.attack(G, s, act.a, act.d)
  elseif act.t == "hp" then return B.heroPower(G, s, act.tgt) end
  return false
end

-- level 1 = apprentice (sloppy), 2 = adept, 3 = archmage
function B.aiPick(G, s, level)
  local base = B.eval(G, s)
  local best, bestV = nil, base + 0.05
  local noise = level == 1 and 5 or level == 2 and 1.5 or 0
  for _, act in ipairs(B.actions(G, s)) do
    local C = B.clone(G)
    if B.exec(C, s, act) then
      local v
      local key = act.t == "play" and G.p[s].hand[act.i]
      if key == "coin" then
        v = -1e9
        for _, a2 in ipairs(B.actions(C, s)) do
          local D = B.clone(C)
          if B.exec(D, s, a2) then v = max(v, B.eval(D, s)) end
        end
        if v < base + 0.9 then v = -1e9 end
      else v = B.eval(C, s) end
      if noise > 0 then v = v + (math.random() - 0.5) * noise * 2 end
      if v > bestV then best, bestV = act, v end
    end
  end
  if best and level == 1 and math.random() < 0.12 then return nil end
  return best
end

-- ---------------------------------------------------------------------------
-- Decks
-- ---------------------------------------------------------------------------
local CURVE = { [0] = 0, 3, 5, 5, 4, 4, 3, 2, 2, 1, 1 }   -- how many cards of each cost
function B.maxCopies(d) return (d.tier or 1) >= 5 and 1 or 2 end

-- pool: list of keys; maxTier limits rarity; rnd: function(n)->1..n
function B.randomDeck(pool, maxTier, rnd, seedList, limit)
  local byCost = {}
  for _, k in ipairs(pool) do
    local d = B.defs[k]
    if d and (d.tier or 1) <= maxTier and not d.special then
      local c = min(10, d.cost)
      byCost[c] = byCost[c] or {}
      table.insert(byCost[c], k)
    end
  end
  local deck, count = {}, {}
  local function tryAdd(k)
    local d = B.defs[k]
    if (count[k] or 0) >= min(B.maxCopies(d), limit and limit(k) or 9) then return false end
    count[k] = (count[k] or 0) + 1; deck[#deck + 1] = k
    return true
  end
  if seedList then for _, k in ipairs(seedList) do if #deck < B.DECK then tryAdd(k) end end end
  for c = 1, 10 do
    local want = CURVE[c] or 0
    local list = byCost[c] or {}
    local tries = 0
    while want > 0 and #list > 0 and tries < 80 and #deck < B.DECK do
      tries = tries + 1
      if tryAdd(list[rnd(#list)]) then want = want - 1 end
    end
  end
  local all = {}
  for _, l in pairs(byCost) do for _, k in ipairs(l) do all[#all + 1] = k end end
  local tries = 0
  while #deck < B.DECK and #all > 0 and tries < 400 do tries = tries + 1; tryAdd(all[rnd(#all)]) end
  local guard = 0
  while #deck < B.DECK and guard < 600 do guard = guard + 1; tryAdd(B.BASIC[rnd(#B.BASIC)]) end
  return deck
end
