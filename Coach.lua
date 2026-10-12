-- RetGear DPS coach: records every fight from the combat log, breaks your
-- damage down by ability, and finds where DPS was lost (Seal down, not
-- swinging, abilities sitting off cooldown, misses, parries, missing buffs).
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY

table.insert(RG.OPTIONS, { key = "coach", label = "DPS coach: tips after each fight (DPS tab)", default = true })
table.insert(RG.OPTIONS, { key = "coachChat", label = "Print a one-line DPS report in chat after fights", default = true })
local function on() return RG.Opt("coach") end

local MAX_FIGHTS = 30
local MIN_FIGHT = 8   -- seconds; shorter fights are too noisy to coach
local TICK = 0.5

-- Abilities a Ret paladin should press whenever they're ready.
-- need = extra condition; the game's "usable" check covers the rest
-- (Exorcism only on Undead/Demons, Hammer of Wrath only under 20%).
local KEY_SPELLS = {
  { name = "Judgement",       tip = "Judge on cooldown" },
  { name = "Holy Strike",     tip = "Use Holy Strike on cooldown" },
  { name = "Crusader Strike", tip = "Use Crusader Strike on cooldown" },
  { name = "Exorcism",        tip = "Exorcism on Undead and Demons", need = function() local t = UnitCreatureType and UnitCreatureType("target"); return t == "Undead" or t == "Demon" end },
  { name = "Hammer of Wrath", tip = "Hammer of Wrath when the target is under 20%" },
}

local function db()
  RG.db.fights = RG.db.fights or {}
  RG.db.spellAvg = RG.db.spellAvg or {}
  return RG.db
end

-- ---------------------------------------------------------------------------
-- Small API helpers (modern first, old fallbacks)
-- ---------------------------------------------------------------------------
local function spellKnown(name)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(name)
    if not info then return false end
    if IsPlayerSpell then return IsPlayerSpell(info.spellID) end
    return true
  end
  return GetSpellInfo and GetSpellInfo(name) ~= nil
end
local function cooldown(name)
  if C_Spell and C_Spell.GetSpellCooldown then
    local cd = C_Spell.GetSpellCooldown(name)
    if cd then return cd.startTime or 0, cd.duration or 0 end
  elseif GetSpellCooldown then
    local s, d = GetSpellCooldown(name); return s or 0, d or 0
  end
  return 0, 0
end
local function usable(name)
  if C_Spell and C_Spell.IsSpellUsable then return C_Spell.IsSpellUsable(name) end
  if IsUsableSpell then return IsUsableSpell(name) end
  return true
end
local function inRange(name)
  local r
  if C_Spell and C_Spell.IsSpellInRange then r = C_Spell.IsSpellInRange(name, "target")
  elseif IsSpellInRange then r = IsSpellInRange(name, "target") end
  return r == nil or r == true or r == 1
end
local function hasAura(test)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for i = 1, 40 do
      local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
      if not a then break end
      if a.name and test(a.name) then return a.name end
    end
  elseif UnitBuff then
    for i = 1, 40 do
      local n = UnitBuff("player", i)
      if not n then break end
      if test(n) then return n end
    end
  end
end
local function hasSeal() return hasAura(function(n) return n:find("^Seal of") end) end
local function hasMight() return hasAura(function(n) return n:find("Blessing of Might") end) end
local function targetOK() return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") end

-- ---------------------------------------------------------------------------
-- Recording a fight
-- ---------------------------------------------------------------------------
local cur, ticker
local myGUID

local function newFight()
  local mh = UnitAttackSpeed and UnitAttackSpeed("player") or 3.5
  local _, instType = IsInInstance and IsInInstance()
  cur = {
    start = GetTime(), first = nil, last = nil,
    total = 0, abilities = {}, casts = {},
    swings = 0, swingDmg = 0, swingHits = 0, miss = 0, dodge = 0, parry = 0, glance = 0, crits = 0,
    samples = 0, sealUp = 0, meleeSamples = 0, idle = {}, cd = {}, noMana = 0,
    minMana = 1, speed = mh, died = false,
    might = hasMight() ~= nil, stone = (GetWeaponEnchantInfo and GetWeaponEnchantInfo()) and true or false,
    target = UnitExists("target") and UnitName("target") or nil,
    class = UnitExists("target") and UnitClassification and UnitClassification("target") or nil,
    instance = instType ~= "none" and instType or nil,
    level = UnitLevel("player"),
  }
end

local function addDmg(name, amount, crit)
  if not cur or not amount or amount <= 0 then return end
  local now = GetTime()
  cur.first = cur.first or now; cur.last = now
  cur.total = cur.total + amount
  local a = cur.abilities[name]
  if not a then a = { dmg = 0, hits = 0, crits = 0 }; cur.abilities[name] = a end
  a.dmg = a.dmg + amount; a.hits = a.hits + 1
  if crit then a.crits = a.crits + 1 end
end

local function sample()
  if not cur then return end
  cur.samples = cur.samples + 1
  if hasSeal() then cur.sealUp = cur.sealUp + 1 end
  local maxMana = UnitPowerMax("player", 0) or 0
  if maxMana > 0 then cur.minMana = math.min(cur.minMana, (UnitPower("player", 0) or 0) / maxMana) end
  if not targetOK() then return end
  -- each ability's own range check decides whether it could have been used
  cur.meleeSamples = cur.meleeSamples + 1
  local now = GetTime()
  for _, s in ipairs(KEY_SPELLS) do
    if spellKnown(s.name) and (not s.need or s.need()) then
      local start, dur = cooldown(s.name)
      if dur and dur > 1.6 then cur.cd[s.name] = math.max(cur.cd[s.name] or 0, dur) end
      local left = (start or 0) > 0 and (start + dur - now) or 0
      -- during the global cooldown you're busy pressing something else: don't count it
      local ready = left <= 0
      if ready then
        local ok, noMana = usable(s.name)
        if ok and inRange(s.name) then
          cur.idle[s.name] = (cur.idle[s.name] or 0) + TICK
        elseif noMana then
          cur.noMana = cur.noMana + TICK
        end
      end
    end
  end
end

-- Turn raw numbers into ranked tips: { text, lost = DPS you'd gain, fix }
local function analyze(f)
  local dur = f.dur
  local tips = {}
  local white = f.abilities["Melee"]
  local whiteDps = white and white.dmg / dur or 0
  local avgWhite = (f.swingHits > 0) and (f.swingDmg / f.swingHits) or 0
  local function add(text, lost, fix) if lost and lost >= 0.5 or (fix and lost == nil) then tips[#tips + 1] = { text = text, lost = lost or 0, fix = fix } end end

  -- Seal uptime
  if f.samples > 0 and spellKnown("Seal of Righteousness") then
    local up = f.sealUp / f.samples
    f.sealPct = up
    if up < 0.9 then
      local sealDmg = 0
      for name, a in pairs(f.abilities) do if name:find("^Seal of") then sealDmg = sealDmg + a.dmg end end
      local lost = (sealDmg > 0 and up > 0.05) and (sealDmg / up * (1 - up) / dur) or (whiteDps * 0.2 * (1 - up))
      add(string.format("No Seal for %d%% of the fight", math.floor((1 - up) * 100 + 0.5)), lost, "Put a Seal up before you pull, and recast it the moment it drops.")
    end
  end
  -- Swing uptime
  if f.speed and f.speed > 0 and dur > 0 then
    local expected = dur / f.speed
    local up = math.min(1, f.swings / math.max(1, expected))
    f.swingPct = up
    if up < 0.85 and expected >= 3 then
      local lost = (expected - f.swings) * avgWhite / dur
      add(string.format("Only swinging %d%% of the time", math.floor(up * 100 + 0.5)), lost, "Stay in melee range and keep auto-attack on. Running, looting or casting from range stops your swings.")
    end
  end
  -- Abilities left sitting ready
  for _, s in ipairs(KEY_SPELLS) do
    -- allow normal reaction time: about 3/4 of a second per cast
    local idle = (f.idle[s.name] or 0) - 0.75 * ((f.casts[s.name] or 0) + 1)
    if idle >= 3 then
      local cd = f.cd[s.name] or (RG.db.spellAvg[s.name .. "#cd"]) or 10
      local castsLost = idle / math.max(cd, 4)
      local avg = RG.db.spellAvg[s.name] or (avgWhite * 1.5)
      for name, a in pairs(f.abilities) do if name == s.name or name:find("^" .. s.name) then avg = a.dmg / math.max(1, a.hits) end end
      add(string.format("%s sat ready for %.0f sec", s.name, idle), castsLost * avg / dur, s.tip .. ". Put it on an easy key and press it every time it lights up.")
    end
  end
  -- Misses and parries
  local attempts = f.swings
  if attempts >= 10 then
    local missPct = f.miss / attempts
    if missPct > 0.06 then add(string.format("%d%% of your swings missed", math.floor(missPct * 100 + 0.5)), (missPct - 0.05) * whiteDps / math.max(0.01, 1 - missPct), "More hit chance helps: look for +Hit gear (the My gear tab shows your hit %).") end
    local parryPct = f.parry / attempts
    if parryPct > 0.03 then add(string.format("%d%% of your swings were parried", math.floor(parryPct * 100 + 0.5)), parryPct * whiteDps, "Stand behind the enemy when someone else is tanking: they can't parry from behind.") end
  end
  -- Buffs at the pull
  if not f.might and spellKnown("Blessing of Might") then add("Blessing of Might was missing at the pull", f.total / dur * 0.05, "Keep Blessing of Might on yourself. The tracker reminds you when it drops.") end
  if not f.stone and (f.level or 0) >= 10 then add("No sharpening stone or weightstone on your weapon", f.total / dur * 0.03, "Use the stone the tracker suggests. You can make them with Blacksmithing.") end
  if f.noMana >= 3 then add(string.format("Out of mana for %.0f sec", f.noMana), nil, "Drink between pulls, and judge Seal of Wisdom on long fights if you keep running dry.") end
  if f.died then add("You died in this fight", nil, "Watch your health: use a healing potion, or Lay on Hands in an emergency.") end

  table.sort(tips, function(a, b) return a.lost > b.lost end)
  local lostTotal = 0
  for _, t in ipairs(tips) do lostTotal = lostTotal + t.lost end
  f.tips = tips
  f.potential = lostTotal
  f.efficiency = f.dps > 0 and (f.dps / (f.dps + lostTotal)) or 0
end

local function finish()
  if not cur then return end
  if ticker then ticker:Cancel(); ticker = nil end
  local f = cur; cur = nil
  if not f.first then return end
  f.dur = math.max(1, (f.last or GetTime()) - f.first + (f.speed or 3) * 0.5)
  if f.dur < MIN_FIGHT then return end
  f.dps = f.total / f.dur
  f.t = time()
  -- remember average hits so later fights can price unused abilities
  local avg = db().spellAvg
  for name, a in pairs(f.abilities) do
    if a.hits > 0 then local v = a.dmg / a.hits; avg[name] = avg[name] and (avg[name] * 0.7 + v * 0.3) or v end
  end
  for name, d in pairs(f.cd) do avg[name .. "#cd"] = d end
  analyze(f)
  -- slim down what we save
  local saved = {}
  for k, v in pairs(f) do if k ~= "start" and k ~= "first" and k ~= "last" then saved[k] = v end end
  table.insert(db().fights, 1, saved)
  for i = #RG.db.fights, MAX_FIGHTS + 1, -1 do RG.db.fights[i] = nil end
  RG.lastFightAt = GetTime()
  if RG.Opt("coachChat") then
    local best = RG.BestDPS()
    local msg = string.format("%s: %s%.0f DPS|r over %ds", f.target or "Fight", GOLD, f.dps, math.floor(f.dur))
    if best and best > f.dps then msg = msg .. GREY .. string.format(" (your best at this level %.0f)", best) .. "|r" end
    local t = f.tips[1]
    if t then msg = msg .. "  ·  " .. (t.lost > 0.5 and (GREEN .. string.format("+%.0f DPS:|r ", t.lost)) or "") .. t.text .. GREY .. "  (/rg dps)|r"
    else msg = msg .. "  ·  " .. GREEN .. "clean fight, nothing to fix|r" end
    RG.Print(msg)
  end
  if RG.RefreshUI then RG.RefreshUI() end
  if RG.QueueTracker then RG.QueueTracker() end
end

function RG.BestDPS(level)
  level = level or UnitLevel("player")
  local best
  for _, f in ipairs(db().fights) do if f.level == level and (not best or f.dps > best) then best = f.dps end end
  return best
end

-- Issues that keep coming back over your last fights.
function RG.CoachPatterns(n)
  n = n or 10
  local count, lost, fix, seen = {}, {}, {}, 0
  for i = 1, math.min(n, #db().fights) do
    local f = RG.db.fights[i]
    seen = seen + 1
    for _, t in ipairs(f.tips or {}) do
      local key = t.text:gsub("%d+%%", "X%%"):gsub("%d+ sec", "X sec")
      count[key] = (count[key] or 0) + 1
      lost[key] = (lost[key] or 0) + t.lost
      fix[key] = t.fix
    end
  end
  local out = {}
  for k, c in pairs(count) do
    if c >= 2 or seen <= 2 then out[#out + 1] = { key = k, count = c, avgLost = lost[k] / c, fix = fix[k] } end
  end
  table.sort(out, function(a, b) return a.avgLost * a.count > b.avgLost * b.count end)
  return out, seen
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_DEAD" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then myGUID = UnitGUID("player"); return end
  if not on() then return end
  if event == "PLAYER_REGEN_DISABLED" then
    newFight()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(TICK, sample)
  elseif event == "PLAYER_REGEN_ENABLED" then
    finish()
  elseif event == "PLAYER_DEAD" then
    if cur then cur.died = true end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and cur then
    local _, sub, _, src, _, _, _, _, _, _, _, a12, a13, a14, a15, _, _, a18, a19, _, a21 = CombatLogGetCurrentEventInfo()
    myGUID = myGUID or UnitGUID("player")
    if src ~= myGUID then return end
    if sub == "SWING_DAMAGE" then
      cur.swings = cur.swings + 1; cur.swingHits = cur.swingHits + 1; cur.swingDmg = cur.swingDmg + (a12 or 0)
      if a18 then cur.crits = cur.crits + 1 end
      if a19 then cur.glance = cur.glance + 1 end
      addDmg("Melee", a12, a18)
    elseif sub == "SWING_MISSED" then
      cur.swings = cur.swings + 1
      if a12 == "MISS" then cur.miss = cur.miss + 1 elseif a12 == "DODGE" then cur.dodge = cur.dodge + 1 elseif a12 == "PARRY" then cur.parry = cur.parry + 1 end
    elseif sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" or sub == "RANGE_DAMAGE" then
      addDmg(a13 or "Spell", a15, a21)
    elseif sub == "SPELL_CAST_SUCCESS" and a13 then
      cur.casts[a13] = (cur.casts[a13] or 0) + 1
    end
  end
end)

-- Tracker: show the last fight's top fix for two minutes after combat.
local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  if on() and RG.lastFightAt and GetTime() - RG.lastFightAt < 120 then
    local last = db().fights[1]
    local t = last and last.tips and last.tips[1]
    if t and t.lost >= 1 then
      out[#out + 1] = { string.format("%sLast fight %.0f DPS|r%s  ·  +%.0f: %s|r", GOLD, last.dps, GREY, t.lost, t.text), function() if RG.ShowTab then RG.ShowTab("dps") end end }
    end
  end
  return out
end

local base = SlashCmdList.RETGEAR
SlashCmdList.RETGEAR = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.*)$")
  cmd = cmd and cmd:lower()
  if cmd == "dps" or cmd == "coach" then
    if rest == "reset" then RG.db.fights = {}; RG.Print("DPS history cleared.") end
    if RG.ShowTab then RG.ShowTab("dps") end
    return
  end
  return base(msg)
end
