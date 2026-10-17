-- ArcadeBattle.lua - the card duel: the board, the computer opponent, deck building (rules live in Battle.lua).
-- Opened from the cards window ("Waypath Arena") or with /wp arena. Hidden like the cards.
local ADDON, RG = ...
local B = RG.Battle
if not B then return end
local U                      -- the card window's helpers, resolved when the arena first opens
local win, game
local W, H = 1180, 700       -- window
local HW = 100               -- hand card width
local MW, MH = 88, 104       -- a minion on the board
local S = { targeting = false, level = 2, busy = false, aiN = 0, held = 0, msgT = 0, mode = "menu", mull = {}, pkey = false }
local gliding = {}      -- widgets easing to their place (see place())
local pt               -- defined below: put a widget's centre at x, y in the window
local ui = { widgetOf = {}, hand = {}, mins = { {}, {} }, back = {}, crystals = { {}, {} }, pos = {}, floats = {}, dots = {}, trail = {} }

local function Sh(f, on) if on then f:Show() else f:Hide() end end
-- Which engine side is the local player? 1 against the computer; the guest of a player duel is side 2.
local ME = 1
local function E(v) return v == 1 and ME or 3 - ME end   -- screen slot (1 = me) to engine side
local function V(s) return s == ME and 1 or 2 end         -- engine side to screen slot
local function cap(s) return (s or ""):sub(1, 1):upper() .. (s or ""):sub(2) end
local CLS_ICON = function(c) return "Interface\\Icons\\ClassIcon_" .. cap((c or "warrior"):lower()) end
local POWER_ICON = { WARRIOR = "Ability_Warrior_DefensiveStance", PALADIN = "Spell_Holy_HolyBolt", HUNTER = "Ability_Marksmanship", ROGUE = "Ability_Rogue_Eviscerate",
  PRIEST = "Spell_Holy_Heal", SHAMAN = "Spell_Nature_HealingWaveGreater", MAGE = "Spell_Fire_Fireball02", WARLOCK = "Spell_Shadow_LifeDrain02", DRUID = "Ability_Racial_BearForm" }
local REWARD = { 4, 8, 14 }
local LEVELS = { "Apprentice", "Adept", "Archmage" }
local TILE_ME, TILE_FOE = { 1, 0.86, 0.52 }, { 0.78, 0.6, 0.95 }

-- ---------------------------------------------------------------------------
-- A tiny clock: delays and per-frame animations (works whether or not C_Timer exists)
-- ---------------------------------------------------------------------------
local clock, timers, ticks = 0, {}, {}
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, dt)
  dt = type(dt) == "number" and dt or 0.016
  clock = clock + dt
  for i = #timers, 1, -1 do
    local t = timers[i]
    if clock >= t.t then table.remove(timers, i); local ok, err = pcall(t.fn); if not ok and RG.Print and RG.Opt and RG.Opt("debug") then RG.Print("arena: " .. tostring(err)) end end
  end
  for i = #ticks, 1, -1 do
    if ticks[i](dt) == false then table.remove(ticks, i) end
  end
end)
RG.BattleDriver = driver
local function after(sec, fn) timers[#timers + 1] = { t = clock + sec, fn = fn } end
local function tick(fn) ticks[#ticks + 1] = fn end

-- ---------------------------------------------------------------------------
-- Cards as they play
-- ---------------------------------------------------------------------------
local cobj = {}
local function cardObj(key)
  local d = B.defs[key]; if not d then return nil end
  local c = cobj[key]
  if c then return c end
  local real = U.byKey[key]
  if real then c = {}; for k, v in pairs(real) do c[k] = v end
  else c = { id = 0, kind = 2, name = d.name, tier = d.tier or 1, ref = 0, icon = "Interface\\Icons\\" .. (d.icon or "INV_Misc_QuestionMark"), key = key } end
  c.text, c.lore, c.def = d.text, d.lore, d
  c.num = nil
  cobj[key] = c
  return c
end
local function iconOf(key, m)
  if m and m.icon then return "Interface\\Icons\\" .. m.icon end
  local c = key and cardObj(key)
  if c then return U.iconFor(c) end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function finishOf(key, side)
  local c = U.byKey[key]
  if side == 1 and c then local a = U.store(); return a and U.bestFinish(a, c.id) or 1 end
  if side == 2 and c then local n = #key % 10; return n == 0 and 3 or (n <= 2 and 2 or 1) end
  return 1
end
local function typeLine(d)
  if d.type == "minion" then return d.tribe and cap(d.tribe) or "Minion" end
  return d.type == "weapon" and "Weapon" or "Spell"
end

local function badge(top, tex, size, layer)
  local t = top:CreateTexture(nil, layer or "ARTWORK", nil, 3); t:SetTexture(U.MEDIA .. tex); t:SetSize(size, size)
  return t
end
-- cost, attack and health on a card
local function decorate(w)
  if rawget(w, "decorated") then return end
  w.decorated = true
  local u, top = w.u, w.top
  w.costB = badge(top, "BadgeCost", 42 * u); w.costB:SetPoint("CENTER", w, "TOPLEFT", 21 * u, -22 * u)
  w.costT = U.fs(top, "title", 25 * u, "OVERLAY", "OUTLINE"); w.costT:SetPoint("CENTER", w.costB, "CENTER", 0, 0)
  w.atkB = badge(top, "BadgeAtk", 44 * u); w.atkB:SetPoint("CENTER", w, "TOPLEFT", 25 * u, -336 * u)
  w.atkT = U.fs(top, "title", 26 * u, "OVERLAY", "OUTLINE"); w.atkT:SetPoint("CENTER", w.atkB, "CENTER", 0, 0)
  w.hpB = badge(top, "BadgeHp", 44 * u); w.hpB:SetPoint("CENTER", w, "TOPLEFT", 231 * u, -336 * u)
  w.hpT = U.fs(top, "title", 26 * u, "OVERLAY", "OUTLINE"); w.hpT:SetPoint("CENTER", w.hpB, "CENTER", 0, 0)
  w.playGlow = w:CreateTexture(nil, "BACKGROUND", nil, -7); w.playGlow:SetTexture(U.MEDIA .. "Glow"); w.playGlow:SetBlendMode("ADD")
  w.playGlow:SetPoint("TOPLEFT", w, "TOPLEFT", -0.2 * w.cw, 0.14 * w.ch); w.playGlow:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", 0.2 * w.cw, -0.14 * w.ch); w.playGlow:SetVertexColor(0.3, 1, 0.4, 0.9); w.playGlow:Hide()
  w.xMark = U.fs(top, "title", 60 * u, "OVERLAY", "OUTLINE"); w.xMark:SetPoint("CENTER", w, "CENTER", 0, 0); w.xMark:SetTextColor(1, 0.2, 0.2); w.xMark:SetText("X"); w.xMark:Hide()
end
local function cardStats(w, d, live)
  w.costT:SetText(live and live.cost or d.cost); Sh(w.costB, true); Sh(w.costT, true)
  local show = d.type ~= "spell"
  Sh(w.atkB, show); Sh(w.atkT, show); Sh(w.hpB, show); Sh(w.hpT, show)
  if show then
    local atk, hp, base = d.atk, d.hp or d.dur, d.hp
    if live then atk, hp = live.atk, live.hp end
    w.atkT:SetText(atk); w.hpT:SetText(hp)
    local good = live and live.atk > d.atk
    w.atkT:SetTextColor(good and 0.5 or 1, 1, good and 0.5 or 1)
    local hurt = live and live.hp < live.maxhp
    w.hpT:SetTextColor(1, hurt and 0.45 or 1, hurt and 0.45 or ((live and live.maxhp > (d.hp or 0)) and 0.5 or 1))
  end
end
-- paint a card widget (cached by key so models and art are not reloaded every refresh)
-- rules keywords stand out in the card text
local KEYWORDS = { "Divine Shield", "Battlecry", "Deathrattle", "Windfury", "Lifesteal", "Stealth", "Poisonous", "Taunt", "Charge", "Rush", "Freeze", "Silence" }
local function hilite(t)
  for _, k in ipairs(KEYWORDS) do t = t:gsub(k, "|cff8a3a08" .. k .. "|r") end
  return t
end
local function paintCard(w, key, owner, live)
  local c = cardObj(key)
  if not c then w:Hide() return end
  local d = c.def
  w:Show()
  if w.pkey ~= key or w.powner ~= owner then
    w.pkey, w.powner = key, owner
    U.paint(w, c, finishOf(key, owner), nil)
    decorate(w)
    w.pow:SetText(""); w.powLabel:Hide(); w.fin:SetText(""); w.num:SetText(""); w.count:SetText("")
    w.type:SetText(typeLine(d))
    U.fitText(w.name, d.name, 196 * w.u, 15 * w.u, w.cw < 190 and 6.5 or 8, "head")
    w.name:ClearAllPoints(); w.name:SetPoint("TOPLEFT", w, "TOPLEFT", 40 * w.u, -13 * w.u); w.name:SetPoint("BOTTOMRIGHT", w, "TOPLEFT", 238 * w.u, -37 * w.u)
    if w.cw >= 190 then
      w.text:SetText(hilite(d.text or "") .. (d.lore and d.lore ~= "" and ("\n\n|cff6b4a2e" .. d.lore .. "|r") or ""))
    elseif w.cw >= 90 then   -- hand cards: a short line in a font you can read, the full card shows on hover
      local t = (d.text or ""):gsub("%s+", " ")
      if #t > 40 then t = t:sub(1, 38):gsub("%s*%S*$", "") .. "..." end
      U.setfont(w.text, "body", 9)
      w.text:SetTextColor(0.13, 0.08, 0.03)
      w.text:SetText(hilite(t))
    else w.text:SetText("") end
  end
  cardStats(w, d, live)
end

-- ---------------------------------------------------------------------------
-- Rewards and saved decks
-- ---------------------------------------------------------------------------
local function store() return U.store() end
local BACKS = { "Back", "Back2", "Back3", "Back4", "Back5" }
local BACK_NAMES = { "Midnight", "Crimson", "Emerald", "Azure", "Gilt" }
function RG.CardBackName()
  local a = U and U.store and U.store()
  return BACKS[(a and a.cardBack) or 1] or "Back"
end
local function avail(a)   -- the keys you can put in a deck, and how many copies
  local out, keys = {}, {}
  for _, k in ipairs(B.BASIC) do out[k] = 2; keys[#keys + 1] = k end
  for _, c in ipairs(U.CARDS) do
    local k = c.key or c.name
    if not B.defs[k] then B.derive(c) end
    local n = U.owned(a, c.id)
    if n > 0 then
      local d = B.defs[k]
      if not out[k] then keys[#keys + 1] = k end
      out[k] = math.min(B.maxCopies(d), n)
    end
  end
  return out, keys
end
local function deckOf(a, i)
  a.decks = a.decks or {}
  a.decks[i] = a.decks[i] or { cards = {}, name = "Deck " .. i }
  return a.decks[i]
end
local function deckSize(dk) local n = 0; for _, v in pairs(dk.cards) do n = n + v end return n end
local function cleanDeck(a, dk)   -- drop anything you no longer own
  local have = avail(a)
  for k, v in pairs(dk.cards) do
    if not have[k] then dk.cards[k] = nil elseif v > have[k] then dk.cards[k] = have[k] end
  end
end
local function fillDeck(a, dk)
  cleanDeck(a, dk)
  local have, keys = avail(a)
  local seed = {}
  for k, v in pairs(dk.cards) do for _ = 1, v do seed[#seed + 1] = k end end
  local deck = B.randomDeck(keys, 6, math.random, seed, function(k) return have[k] end)
  dk.cards = {}
  for _, k in ipairs(deck) do dk.cards[k] = (dk.cards[k] or 0) + 1 end
end
local function expand(dk)
  local l = {}
  for k, v in pairs(dk.cards) do for _ = 1, v do l[#l + 1] = k end end
  table.sort(l, function(x, y) local a, b = B.defs[x], B.defs[y]; if a.cost ~= b.cost then return a.cost < b.cost end return x < y end)
  return l
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------
local function say(txt, hold)
  if not win then return end
  win.msg:ClearAllPoints(); win.msg:SetPoint("CENTER", win, "BOTTOMLEFT", 600, S.mode == "mull" and 462 or 372)
  win.msg:SetText(txt or ""); S.msgT = clock + (hold or 3)
end

local function boardPos(side, i, n)
  return 600 - (n - 1) * 48 + (i - 1) * 96, side == 1 and 318 or 438
end
local HERO_POS = { [1] = { 600, 206 }, [2] = { 600, 592 } }   -- yours sits above the hand, not under it
local POWER_POS = { [1] = { 696, 192 }, [2] = { 696, 604 } }
local WEAPON_POS = { [1] = { 504, 192 }, [2] = { 504, 604 } }

local function floatText(x, y, txt, r, g, b, size)
  local f
  for _, q in ipairs(ui.floats) do if not q.live then f = q; break end end
  if not f then return end
  f.live, f.t = true, 0
  f.fs:ClearAllPoints(); f.x, f.y = x, y
  U.setfont(f.fs, "title", size or 22, "OUTLINE")
  f.fs:SetText(txt); f.fs:SetTextColor(r, g, b); f.fs:SetAlpha(1); f.fs:Show()
  f.fs:SetPoint("CENTER", win.fx, "BOTTOMLEFT", x, y)
end

local function refresh() end   -- defined below
local function afterAction() end
local sendMove = function(act) end   -- replaced by the player-duel layer

local function myTurn() return game and not game.over and game.phase == "play" and game.cur == ME and not S.busy end

local function clearTarget()
  S.targeting = false
  for _, d in ipairs(ui.dots) do d:Hide() end
  if win then refresh() end
end

local function startTarget(t)
  t.valid = t.valid or {}
  S.targeting = t
  refresh()
end

local function targetSet(list) local s = {}; for _, o in ipairs(list) do s[B.ref(o)] = true end return s end

local function doTarget(ref)
  local t = S.targeting
  if not t then return end
  if not t.valid[ref] then say("That is not a valid target.", 1.5) clearTarget() return end
  local ok, why
  if t.kind == "play" then ok, why = B.play(game, ME, t.slot, ref)
    if ok then sendMove({ t = "play", i = t.slot, tgt = ref }) end
  elseif t.kind == "att" then ok, why = B.attack(game, ME, t.aref, ref)
    if ok then sendMove({ t = "att", a = t.aref, d = ref }) end
  elseif t.kind == "power" then ok, why = B.heroPower(game, ME, ref)
    if ok then sendMove({ t = "hp", tgt = ref }) end end
  S.targeting = false
  for _, d in ipairs(ui.dots) do d:Hide() end
  if not ok then say(why or "You cannot do that.", 2) end
  afterAction()
end

local function onChar(ref)
  if not game or game.over then return end
  if S.mode == "mull" then return end
  if S.targeting then doTarget(ref) return end
  if not myTurn() then say(S.busy and "The opponent is thinking..." or "Wait for your turn.", 1.5) return end
  local c = B.char(game, ref)
  if not c or c.side ~= ME then return end
  local ok, why = B.canAttack(game, ME, c)
  if not ok then say(why or "That cannot attack.", 2) return end
  startTarget({ kind = "att", aref = ref, valid = targetSet(B.attackTargets(game, ME, c)), from = ref })
end

local function onHand(slot, btn)
  if not game then return end
  if S.mode == "mull" then if S.mullSent then return end S.mull[slot] = not S.mull[slot] or nil; refresh() return end
  if btn == "RightButton" then clearTarget() return end
  if S.targeting then clearTarget() end
  if not myTurn() then say(S.busy and "The opponent is thinking..." or "Wait for your turn.", 1.5) return end
  local ok, why = B.canPlay(game, ME, slot)
  if not ok then say(why or "You cannot play that.", 2) return end
  local need = B.needsTarget(game, ME, slot)
  if need then
    startTarget({ kind = "play", slot = slot, valid = targetSet(B.targets(game, ME, B.defs[game.p[ME].hand[slot]].tgt)), from = "hand" .. slot })
    say("Choose a target.", 4)
  else
    local ok2, why2 = B.play(game, ME, slot)
    if ok2 then sendMove({ t = "play", i = slot }) end
    if not ok2 then say(why2 or "", 2) end
    afterAction()
  end
end

local function onPower()
  if not game or S.mode == "mull" then return end
  if S.targeting then clearTarget() return end
  if not myTurn() then return end
  local ok, why = B.canHeroPower(game, ME)
  if not ok then say(why or "You cannot use your hero power.", 2) return end
  local h = B.HERO[game.p[ME].class]
  if h.tgt then
    startTarget({ kind = "power", valid = targetSet(B.targets(game, ME, h.tgt)), from = "power1" })
    say("Choose a target.", 4)
  else B.heroPower(game, ME); sendMove({ t = "hp" }); afterAction() end
end

-- the thing shown big on the left: whatever you point at
local function preview(key, live, owner)
  if not win or not key then return end
  local w = (S.mode == "deck" and win.pv2) or win.pv
  if not w then return end
  paintCard(w, key, owner or 1, live)
  w:Show()
end

-- ---------- widgets ----------
local function makeMinion(parent)
  local m = CreateFrame("Button", nil, parent)
  m:SetSize(MW, MH)
  m.glow = m:CreateTexture(nil, "BACKGROUND"); m.glow:SetTexture(U.MEDIA .. "Glow"); m.glow:SetBlendMode("ADD"); m.glow:SetSize(150, 150); m.glow:SetPoint("CENTER", m, "TOP", 0, -44); m.glow:Hide()
  m.flashTex = m:CreateTexture(nil, "OVERLAY", nil, 6); m.flashTex:SetTexture(U.MEDIA .. "Glow"); m.flashTex:SetBlendMode("ADD"); m.flashTex:SetSize(170, 170); m.flashTex:SetPoint("CENTER", m, "TOP", 0, -44); m.flashTex:SetVertexColor(1, 0.9, 0.55, 1); m.flashTex:Hide()
  m.back = m:CreateTexture(nil, "BACKGROUND", nil, 2); m.back:SetColorTexture(0.05, 0.04, 0.1, 1); m.back:SetSize(66, 66); m.back:SetPoint("CENTER", m, "TOP", 0, -44)
  m.icon = m:CreateTexture(nil, "ARTWORK", nil, 1); m.icon:SetSize(66, 66); m.icon:SetPoint("CENTER", m, "TOP", 0, -44); m.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  m.scn = U.newScene(m, 66, 66, m.back)
  m.tile = m:CreateTexture(nil, "ARTWORK", nil, 2); m.tile:SetSize(88, 88); m.tile:SetPoint("TOP", m, "TOP", 0, 0)
  m.ice = m:CreateTexture(nil, "ARTWORK", nil, 3); m.ice:SetTexture(U.MEDIA .. "Ice"); m.ice:SetSize(84, 84); m.ice:SetPoint("CENTER", m.tile, "CENTER"); m.ice:SetAlpha(0.7); m.ice:Hide()
  m.bubble = m:CreateTexture(nil, "ARTWORK", nil, 4); m.bubble:SetTexture(U.MEDIA .. "Bubble"); m.bubble:SetBlendMode("ADD"); m.bubble:SetSize(96, 96); m.bubble:SetPoint("CENTER", m.tile, "CENTER"); m.bubble:Hide()
  m.atkB = m:CreateTexture(nil, "OVERLAY", nil, 1); m.atkB:SetTexture(U.MEDIA .. "BadgeAtk"); m.atkB:SetSize(32, 32); m.atkB:SetPoint("CENTER", m.tile, "BOTTOMLEFT", 8, 6)
  m.hpB = m:CreateTexture(nil, "OVERLAY", nil, 1); m.hpB:SetTexture(U.MEDIA .. "BadgeHp"); m.hpB:SetSize(32, 32); m.hpB:SetPoint("CENTER", m.tile, "BOTTOMRIGHT", -8, 6)
  m.atkT = U.fs(m, "title", 17, "OVERLAY", "OUTLINE"); m.atkT:SetPoint("CENTER", m.atkB, "CENTER", 0, 0)
  m.hpT = U.fs(m, "title", 17, "OVERLAY", "OUTLINE"); m.hpT:SetPoint("CENTER", m.hpB, "CENTER", 0, 0)
  m.name = U.fs(m, "head", 10, "OVERLAY"); m.name:SetPoint("TOP", m.tile, "BOTTOM", 0, -2); m.name:SetWidth(MW + 6); m.name:SetWordWrap(false); m.name:SetTextColor(0.95, 0.9, 0.78)
  m.zz = U.fs(m, "title", 14, "OVERLAY", "OUTLINE"); m.zz:SetPoint("TOPRIGHT", m.tile, "TOPRIGHT", -8, -8); m.zz:SetTextColor(0.7, 0.8, 1); m.zz:SetText("Zz")
  m.fx = U.fs(m, "head", 9, "OVERLAY", "OUTLINE"); m.fx:SetPoint("TOPLEFT", m.tile, "TOPLEFT", 8, -8); m.fx:SetTextColor(1, 0.85, 0.5)
  m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  m:SetScript("OnClick", function(self, btn) if btn == "RightButton" then clearTarget() else onChar(self.ref) end end)
  m:SetScript("OnEnter", function(self)
    self.hov = true
    if self.m and self.m.key and B.defs[self.m.key] then preview(self.m.key, self.m, V(self.m.side))
    elseif self.m then
      -- a token has no card: describe it
      win.tokTip:SetText("|cfff5d273" .. self.m.name .. "|r\n" .. self.m.atk .. "/" .. self.m.hp .. (self.m.kw.taunt and "  Taunt" or "")); win.tokTip:Show()
    end
  end)
  m:SetScript("OnLeave", function(self) self.hov = false; win.tokTip:Hide() end)
  return m
end

local function paintMinion(w, m, side)
  w.m, w.ref = m, m.uid
  w:Show()
  w.icon:SetTexture(iconOf(m.key, m))
  local cc = m.key and not m.icon and cardObj(m.key)
  if cc and U.usesScene(cc) then
    U.setScene(w.scn, cc, false)
    if cc.kind == 3 then w.icon:Hide() else w.icon:SetSize(34, 34); w.icon:Show() end
  else
    U.hideScene(w.scn); w.icon:SetSize(66, 66); w.icon:Show()
  end
  local iron = m.kw.taunt
  w.tile:SetTexture(U.MEDIA .. (iron and "TileIron" or "Tile"))
  local c = side == 1 and TILE_ME or TILE_FOE
  w.tile:SetVertexColor(c[1], c[2], c[3], m.kw.stealth and 0.7 or 1)
  w.icon:SetAlpha(m.kw.stealth and 0.45 or 1)
  w.atkT:SetText(m.atk); w.hpT:SetText(m.hp)
  w.atkT:SetTextColor(1, 1, 1)
  w.hpT:SetTextColor(1, m.hp < m.maxhp and 0.45 or 1, m.hp < m.maxhp and 0.45 or 1)
  w.name:SetText(m.name)
  Sh(w.bubble, m.kw.shield); Sh(w.ice, m.frozen)
  Sh(w.zz, m.sick and not (m.kw.charge or m.kw.rush) and not m.frozen)
  local bits = {}
  if m.kw.windfury then bits[#bits + 1] = "W" end
  if m.kw.lifesteal then bits[#bits + 1] = "L" end
  if m.kw.poison then bits[#bits + 1] = "P" end
  if m.dr then bits[#bits + 1] = "D" end
  if m.eot then bits[#bits + 1] = "E" end
  if m.kw.stealth then bits[#bits + 1] = "S" end
  w.fx:SetText(table.concat(bits, " "))
  w.glow:Hide()
end

local function makeHero(parent, side)
  local h = CreateFrame("Button", nil, parent)
  h:SetSize(112, 112); h.side = side
  h.glow = h:CreateTexture(nil, "BACKGROUND"); h.glow:SetTexture(U.MEDIA .. "Glow"); h.glow:SetBlendMode("ADD"); h.glow:SetSize(190, 190); h.glow:SetPoint("CENTER"); h.glow:Hide()
  h.back = h:CreateTexture(nil, "BACKGROUND", nil, 2); h.back:SetColorTexture(0.05, 0.04, 0.1, 1); h.back:SetSize(82, 82); h.back:SetPoint("CENTER")
  h.icon = h:CreateTexture(nil, "ARTWORK", nil, 1); h.icon:SetSize(82, 82); h.icon:SetPoint("CENTER"); h.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  h.tile = h:CreateTexture(nil, "ARTWORK", nil, 2); h.tile:SetTexture(U.MEDIA .. "Tile"); h.tile:SetAllPoints(h); h.tile:SetVertexColor((side == 1 and TILE_ME or TILE_FOE)[1], (side == 1 and TILE_ME or TILE_FOE)[2], (side == 1 and TILE_ME or TILE_FOE)[3], 1)
  h.ice = h:CreateTexture(nil, "ARTWORK", nil, 3); h.ice:SetTexture(U.MEDIA .. "Ice"); h.ice:SetAllPoints(h); h.ice:SetAlpha(0.7); h.ice:Hide()
  h.hpB = h:CreateTexture(nil, "OVERLAY", nil, 1); h.hpB:SetTexture(U.MEDIA .. "BadgeHp"); h.hpB:SetSize(42, 42); h.hpB:SetPoint("CENTER", h, "BOTTOMRIGHT", -6, 8)
  h.hpT = U.fs(h, "title", 22, "OVERLAY", "OUTLINE"); h.hpT:SetPoint("CENTER", h.hpB, "CENTER", 0, 0)
  h.atkB = h:CreateTexture(nil, "OVERLAY", nil, 1); h.atkB:SetTexture(U.MEDIA .. "BadgeAtk"); h.atkB:SetSize(38, 38); h.atkB:SetPoint("CENTER", h, "BOTTOMLEFT", 6, 8)
  h.atkT = U.fs(h, "title", 20, "OVERLAY", "OUTLINE"); h.atkT:SetPoint("CENTER", h.atkB, "CENTER", 0, 0)
  h.arm = U.fs(h, "title", 16, "OVERLAY", "OUTLINE"); h.arm:SetPoint("TOPRIGHT", h, "TOPRIGHT", -2, -2); h.arm:SetTextColor(0.8, 0.85, 1)
  h.name = U.fs(h, "head", 11, "OVERLAY"); h.name:SetPoint("BOTTOM", h, "TOP", 0, 2); h.name:SetTextColor(0.96, 0.84, 0.5)
  h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  h:SetScript("OnClick", function(self, btn) if btn == "RightButton" then clearTarget() else onChar("h" .. E(self.side)) end end)
  return h
end

local function makeSmall(parent, size)   -- hero power / weapon buttons
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b.glow = b:CreateTexture(nil, "BACKGROUND"); b.glow:SetTexture(U.MEDIA .. "Glow"); b.glow:SetBlendMode("ADD"); b.glow:SetSize(size * 1.8, size * 1.8); b.glow:SetPoint("CENTER"); b.glow:SetVertexColor(0.3, 1, 0.4, 0.9); b.glow:Hide()
  b.back = b:CreateTexture(nil, "BACKGROUND", nil, 2); b.back:SetColorTexture(0.05, 0.04, 0.1, 1); b.back:SetSize(size * 0.72, size * 0.72); b.back:SetPoint("CENTER")
  b.icon = b:CreateTexture(nil, "ARTWORK", nil, 1); b.icon:SetSize(size * 0.74, size * 0.74); b.icon:SetPoint("CENTER"); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.tile = b:CreateTexture(nil, "ARTWORK", nil, 2); b.tile:SetTexture(U.MEDIA .. "Tile"); b.tile:SetAllPoints(b)
  b.cost = b:CreateTexture(nil, "OVERLAY", nil, 1); b.cost:SetTexture(U.MEDIA .. "BadgeCost"); b.cost:SetSize(size * 0.42, size * 0.42); b.cost:SetPoint("CENTER", b, "TOP", 0, -2)
  b.costT = U.fs(b, "title", size * 0.26, "OVERLAY", "OUTLINE"); b.costT:SetPoint("CENTER", b.cost, "CENTER")
  b.t1 = U.fs(b, "title", size * 0.3, "OVERLAY", "OUTLINE"); b.t1:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 0); b.t1:SetTextColor(1, 0.9, 0.4)
  b.t2 = U.fs(b, "title", size * 0.3, "OVERLAY", "OUTLINE"); b.t2:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 0); b.t2:SetTextColor(1, 0.5, 0.5)
  return b
end

local function buildWindow()
  U = RG.ArcadeUI
  win = CreateFrame("Frame", "WaypathBattle", UIParent, "BackdropTemplate")
  win:SetSize(W, H); win:SetPoint("CENTER"); win:SetFrameStrata("HIGH"); win:SetMovable(true); win:EnableMouse(true); win:SetClampedToScreen(true)
  win:SetBackdrop({ bgFile = U.WHITE, edgeFile = U.WHITE, edgeSize = 2 })
  win:SetBackdropColor(0.03, 0.02, 0.07, 1); win:SetBackdropBorderColor(0.72, 0.58, 0.3, 1)
  win.night = win:CreateTexture(nil, "BACKGROUND", nil, 0); win.night:SetTexture(U.MEDIA .. "Night"); win.night:SetPoint("TOPLEFT", 2, -2); win.night:SetPoint("BOTTOMRIGHT", -2, 2); win.night:SetAlpha(0.9)
  win.bg = win:CreateTexture(nil, "BACKGROUND", nil, 1); win.bg:SetTexture(U.MEDIA .. "Board"); win.bg:SetPoint("TOPLEFT", 2, -2); win.bg:SetPoint("BOTTOMRIGHT", -2, 2)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", function(self) self:StartMoving() end)
  win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  win:SetScript("OnMouseUp", function(_, btn) if S.targeting then clearTarget() end end)
  if UISpecialFrames then table.insert(UISpecialFrames, "WaypathBattle") end
  local ph = UIParent and UIParent.GetHeight and UIParent:GetHeight()
  local pw = UIParent and UIParent.GetWidth and UIParent:GetWidth()
  local sc = 1
  if type(ph) == "number" and ph > 0 and ph < H + 30 then sc = math.min(sc, (ph - 30) / H) end
  if type(pw) == "number" and pw > 0 and pw < W + 30 then sc = math.min(sc, (pw - 30) / W) end
  if sc < 1 then win:SetScale(math.max(0.5, sc)) end

  win.close = U.gbtn(win, "X", 28, 24, function() win:Hide() end); win.close:SetPoint("TOPRIGHT", -8, -8); win.close:SetFrameLevel(U.lv(win) + 40)
  win.logo = win:CreateTexture(nil, "ARTWORK"); win.logo:SetTexture(RG.LOGO or ""); win.logo:SetSize(26, 26); win.logo:SetPoint("TOPLEFT", 14, -10)
  win.title = U.fs(win, "title", 15); win.title:SetPoint("TOPLEFT", 46, -14); win.title:SetTextColor(U.GOLDC[1], U.GOLDC[2], U.GOLDC[3]); win.title:SetText("WAYPATH ARENA")

  -- screens
  win.menu = CreateFrame("Frame", nil, win); win.menu:SetAllPoints(win); win.menu:SetFrameLevel(U.lv(win) + 5)
  win.deck = CreateFrame("Frame", nil, win); win.deck:SetAllPoints(win); win.deck:SetFrameLevel(U.lv(win) + 5)
  win.board = CreateFrame("Frame", nil, win); win.board:SetAllPoints(win); win.board:SetFrameLevel(U.lv(win) + 5)
  win.fx = CreateFrame("Frame", nil, win); win.fx:SetAllPoints(win); win.fx:SetFrameLevel(U.lv(win) + 60)
  win.fx:EnableMouse(false)

  -- floating numbers and the aiming dots
  for i = 1, 14 do local f = { live = false }; f.fs = U.fs(win.fx, "title", 22, "OVERLAY", "OUTLINE"); f.fs:Hide(); ui.floats[i] = f end
  for i = 1, 16 do local d = win.fx:CreateTexture(nil, "OVERLAY"); d:SetTexture(U.MEDIA .. "Glow"); d:SetBlendMode("ADD"); d:SetSize(26, 26); d:Hide(); ui.dots[i] = d end
  for i = 1, 10 do local d = win.fx:CreateTexture(nil, "OVERLAY"); d:SetTexture(U.MEDIA .. "Glow"); d:SetBlendMode("ADD"); d:SetSize(30, 30); d:SetVertexColor(1, 0.55, 0.2, 1); d:Hide(); ui.trail[i] = d end
  win.msg = U.fs(win.fx, "head", 15, "OVERLAY", "OUTLINE"); win.msg:SetPoint("CENTER", win, "BOTTOMLEFT", 600, 372); win.msg:SetTextColor(1, 0.95, 0.75); win.msg:SetText("")
  win.banner = U.fs(win.fx, "title", 40, "OVERLAY", "OUTLINE"); win.banner:SetPoint("CENTER", win, "BOTTOMLEFT", 600, 378); win.banner:SetText(""); win.banner:Hide()
  win.tokTip = U.fs(win.board, "head", 13, "OVERLAY", "OUTLINE"); win.tokTip:SetPoint("CENTER", win, "BOTTOMLEFT", 125, 480); win.tokTip:SetWidth(220); win.tokTip:SetJustifyH("CENTER"); win.tokTip:Hide()

  tick(function(dt)
    -- glide, drop and lunge
    for w in pairs(gliding) do
      local settled = true
      local k = math.min(1, dt * 16)
      if rawget(w, "gx") ~= nil and rawget(w, "bx") ~= nil then
        w.gx = w.gx + (w.bx - w.gx) * k; w.gy = w.gy + (w.by - w.gy) * k
        if math.abs(w.bx - w.gx) > 0.4 or math.abs(w.by - w.gy) > 0.4 then settled = false else w.gx, w.gy = w.bx, w.by end
        local ox, oy = 0, 0
        local L = rawget(w, "lunge")
        if L then
          L.t = L.t + dt
          local q = L.t / L.dur
          if q >= 1 then w.lunge = nil else
            local f = math.sin(math.pi * q); f = f * f * (q < 0.5 and 1 or 1)
            ox, oy = L.dx * f, L.dy * f; settled = false
          end
        end
        pt(w, w.gx + ox, w.gy + oy)
      end
      local fl = rawget(w, "flash")
      if fl and w.flashTex then
        w.flash = fl - dt
        if w.flash <= 0 then w.flash = nil; w.flashTex:Hide() else w.flashTex:SetAlpha(math.min(1, w.flash / 0.35)); w.flashTex:Show(); settled = false end
      end
      if settled then gliding[w] = nil end
    end
    -- messages fade, floats rise
    if win.msg and S.msgT > 0 and clock > S.msgT then win.msg:SetText(""); S.msgT = 0 end
    for _, f in ipairs(ui.floats) do
      if f.live then
        f.t = f.t + dt
        local k = f.t / 1.1
        if k >= 1 then f.live = false; f.fs:Hide()
        else f.fs:ClearAllPoints(); f.fs:SetPoint("CENTER", win.fx, "BOTTOMLEFT", f.x, f.y + 46 * k); f.fs:SetAlpha(k < 0.6 and 1 or (1 - k) / 0.4) end
      end
    end
    -- aiming arrow
    if S.targeting and win:IsShown() and GetCursorPosition then
      local from = S.targeting.from
      local sp = ui.pos[from == "power1" and "power1" or (type(from) == "string" and from:find("^hand") and "hand" or from)]
      if from and type(from) == "string" and from:find("^hand") then sp = { 600, 150 } end
      if sp then
        local cx, cy = GetCursorPosition()
        local es = win:GetEffectiveScale()
        local l, b = win:GetLeft(), win:GetBottom()
        if type(cx) == "number" and type(es) == "number" and type(l) == "number" and type(b) == "number" and es > 0 then
          local tx, ty = cx / es - l, cy / es - b
          local n = #ui.dots
          for i, d in ipairs(ui.dots) do
            local k = i / n
            d:ClearAllPoints(); d:SetPoint("CENTER", win, "BOTTOMLEFT", sp[1] + (tx - sp[1]) * k, sp[2] + (ty - sp[2]) * k + math.sin(k * 3.14) * 18)
            d:SetSize(14 + 20 * k, 14 + 20 * k); d:SetVertexColor(0.4 + 0.6 * k, 1 - 0.5 * k, 0.4, 0.95); d:Show()
          end
        end
      end
    end
    -- strike trail
    if ui.trailT and ui.trailT > 0 then
      ui.trailT = ui.trailT - dt
      local k = 1 - math.max(0, ui.trailT) / 0.35
      for i, d in ipairs(ui.trail) do
        local q = (i / #ui.trail)
        d:ClearAllPoints()
        d:SetPoint("CENTER", win, "BOTTOMLEFT", ui.t1[1] + (ui.t2[1] - ui.t1[1]) * math.min(1, q * 0.5 + k * 0.5), ui.t1[2] + (ui.t2[2] - ui.t1[2]) * math.min(1, q * 0.5 + k * 0.5))
        d:SetAlpha(math.max(0, 1 - k) * (0.4 + 0.6 * q)); d:Show()
      end
      if ui.trailT <= 0 then for _, d in ipairs(ui.trail) do d:Hide() end end
    end
  end)
  return win
end

-- ---------------------------------------------------------------------------
-- The board
-- ---------------------------------------------------------------------------
pt = function(w, x, y) w:ClearAllPoints(); w:SetPoint("CENTER", win, "BOTTOMLEFT", x, y) end
-- Things glide to their place instead of jumping: a drawn card slides in from the deck, a summoned minion drops
-- onto the board with a flash, attackers lunge at their target.
local DECK_POS = { [1] = { 1065, 108 }, [2] = { 1065, 548 } }
local function place(w, x, y, fromX, fromY)
  w.bx, w.by = x, y
  if rawget(w, "gx") == nil then
    w.gx, w.gy = fromX or x, fromY or y
    if fromX then w.fresh = true end
  end
  gliding[w] = true
end
local function unplace(w) w.gx, w.gy = nil, nil; gliding[w] = nil; w.lunge = nil end
local function lunge(w, tx, ty)
  if not w or rawget(w, "bx") == nil then return end
  w.lunge = { t = 0, dur = 0.34, dx = (tx - w.bx) * 0.55, dy = (ty - w.by) * 0.55 }
  gliding[w] = true
end
local GREEN, RED = { 0.3, 1, 0.4, 0.95 }, { 1, 0.3, 0.25, 0.95 }
local logLines = {}
local function logLine(txt)
  logLines[#logLines + 1] = txt
  while #logLines > 11 do table.remove(logLines, 1) end
  if win and win.log then win.log:SetText(table.concat(logLines, "\n")) end
end

local function strike(a, d)
  local p1, p2 = ui.pos[a], ui.pos[d]
  if not p1 or not p2 then return end
  ui.t1, ui.t2, ui.trailT = p1, p2, 0.35
  lunge(ui.widgetOf[a], p2[1], p2[2])
end

local function banner(txt, r, g, b)
  win.banner:SetText(txt); win.banner:SetTextColor(r, g, b); win.banner:Show()
  local id = (S.bid or 0) + 1; S.bid = id
  after(1.3, function() if S.bid == id then win.banner:Hide() end end)
end

local function consume()
  if not game then return end
  local evs = game.ev; game.ev = {}
  local n = 0
  for _, e in ipairs(evs) do
    local p = e.tgt and ui.pos[e.tgt]
    if e.t == "dmg" and p then floatText(p[1], p[2], "-" .. e.n, 1, 0.3, 0.3, 26)
    elseif e.t == "heal" and p then floatText(p[1], p[2], "+" .. e.n, 0.4, 1, 0.5, 24)
    elseif e.t == "pop" and p then floatText(p[1], p[2], "Shield!", 1, 0.9, 0.5, 18)
    elseif e.t == "armor" and p then floatText(p[1], p[2], "+" .. e.n .. " armor", 0.8, 0.85, 1, 16)
    elseif e.t == "freeze" and p then floatText(p[1], p[2], "Frozen", 0.5, 0.85, 1, 16)
    elseif e.t == "silence" and p then floatText(p[1], p[2], "Silenced", 0.8, 0.8, 0.8, 16)
    elseif e.t == "attack" then strike(e.a, e.d)
    elseif e.t == "play" then
      local d = B.defs[e.key]
      if d then
        logLine((e.side == ME and "|cff9fe39a" or "|cffe39a9a") .. (e.side == ME and "You play " or (S.pvp and (S.foeName .. " plays ") or "Foe plays ")) .. d.name .. "|r")
        if e.side ~= ME then preview(e.key, nil, 2) end
      end
    elseif e.t == "die" then logLine("|cffaaaaaa" .. (e.name or "A minion") .. " dies|r")
    elseif e.t == "fatigue" then say((e.side == ME and "You are" or "The foe is") .. " out of cards: " .. e.n .. " damage!", 3)
    elseif e.t == "burn" then if e.side == ME then say("Your hand is full. " .. (B.defs[e.key] and B.defs[e.key].name or "A card") .. " burns.", 3) end
    elseif e.t == "turn" then
      if S.mode == "play" then banner(e.side == ME and "Your turn" or "Opponent's turn", e.side == ME and 0.96 or 0.8, e.side == ME and 0.82 or 0.6, e.side == ME and 0.45 or 0.95) end
    end
  end
end

local function finish()
  if S.finished then return end
  S.finished = true; S.busy = true
  local a = store()
  local won = game.winner == ME
  local lines, prize = {}, 0
  if S.pvp then
    if a then if won then a.pvpWins = (a.pvpWins or 0) + 1 elseif game.winner ~= 0 then a.pvpLoss = (a.pvpLoss or 0) + 1 end end
    local t = won and "VICTORY" or (game.winner == 0 and "A DRAW" or "DEFEAT")
    win.over.title:SetText(t); win.over.title:SetTextColor(won and 1 or 0.9, won and 0.84 or 0.4, won and 0.4 or 0.4)
    win.over.body:SetText((won and ("You beat |cfff5d273" .. (S.foeName or "your friend") .. "|r.") or ((S.foeName or "Your opponent") .. " wins this one.")) .. (S.endReason and ("\n" .. S.endReason) or "") .. "\nFriendly duel: no coins are won or lost.")
    after(1.4, function() win.over:Show() end)
    if RG.Duel and RG.Duel.ended then RG.Duel.ended() end
    return
  end
  if a then
    a.stats = a.stats or {}
    if won then
      prize = REWARD[S.level]
      local today = date and date("%Y-%m-%d") or "today"
      if a.arenaDay ~= today then a.arenaDay = today; prize = prize + 8; lines[#lines + 1] = "First arena win today: +8 bonus" end
      a.bWins = (a.bWins or 0) + 1
      local g = U.goalProgress(a, "duel2", 1)
      if g then lines[#lines + 1] = g end
    else
      prize = 1; a.bLoss = (a.bLoss or 0) + 1
    end
    a.coins = (a.coins or 0) + prize; a.stats.duel = (a.stats.duel or 0) + prize
  end
  local t = won and "VICTORY" or (game.winner == 0 and "A DRAW" or "DEFEAT")
  win.over.title:SetText(t); win.over.title:SetTextColor(won and 1 or 0.9, won and 0.84 or 0.4, won and 0.4 or 0.4)
  win.over.body:SetText((won and ("You earn |cfff5d273" .. prize .. " coins|r.") or ("A consolation |cfff5d273" .. prize .. " coin|r for trying.")) .. (#lines > 0 and ("\n" .. table.concat(lines, "\n")) or ""))
  after(1.4, function() win.over:Show() end)
  if RG.ArcadeRefresh then RG.ArcadeRefresh(true) end
end

local function aiStep(gid)
  if gid ~= S.gid or not game or game.over or game.cur ~= 2 then return end
  S.aiN = S.aiN + 1
  local act = S.aiN < 40 and B.aiPick(game, 2, S.level) or nil
  if act then
    B.exec(game, 2, act)
    afterAction()
    if not game.over then after(act.t == "play" and 1.4 or 0.8, function() aiStep(gid) end) end
  else
    B.endTurn(game, 2)
    S.busy = false; S.aiN = 0
    afterAction()
  end
end
local function startAI()
  S.busy = true; S.aiN = 0
  local gid = S.gid
  after(1.5, function() aiStep(gid) end)
end

local function endTurn()
  if not myTurn() then return end
  clearTarget()
  B.endTurn(game, ME)
  sendMove({ t = "end" })
  if S.pvp then afterAction() return end
  if not game.over and game.cur == 2 then S.busy = true end
  afterAction()
  if not game.over and game.cur == 2 then startAI() end
end

afterAction = function()
  consume()
  refresh()
  if game and game.over then finish() end
end

function ui.bindHeroes()
  for s = 1, 2 do
    ui.widgetOf["h" .. E(s)] = ui.hero[s]
    ui.pos["h" .. E(s)] = { HERO_POS[s][1], HERO_POS[s][2] }
  end
end
local function makeBoard()
  local bd = win.board
  win.pv = U.makeCard(bd, 230); pt(win.pv, 125, 470); win.pv.noTip = true; win.pv.hover = false; win.pv:Hide()
  win.log = U.fs(bd, "body", 12, "OVERLAY"); win.log:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 14, 300); win.log:SetWidth(232); win.log:SetJustifyH("LEFT"); win.log:SetJustifyV("TOP"); win.log:SetTextColor(0.85, 0.8, 0.65); win.log:SetText("")
  for s = 1, 2 do
    for i = 1, 7 do ui.mins[s][i] = makeMinion(bd); ui.mins[s][i]:Hide() end
  end
  ui.hero = { makeHero(bd, 1), makeHero(bd, 2) }
  ui.power, ui.weapon = {}, {}
  for s = 1, 2 do
    local x, y = HERO_POS[s][1], HERO_POS[s][2]
    place(ui.hero[s], x, y); ui.hero[s].gx, ui.hero[s].gy = x, y; pt(ui.hero[s], x, y)
    ui.power[s] = makeSmall(bd, 62); pt(ui.power[s], POWER_POS[s][1], POWER_POS[s][2])
    ui.weapon[s] = makeSmall(bd, 56); pt(ui.weapon[s], WEAPON_POS[s][1], WEAPON_POS[s][2]); ui.weapon[s].cost:Hide(); ui.weapon[s].costT:Hide()
    ui.weapon[s]:Hide()
  end
  ui.pos.power1 = { POWER_POS[1][1], POWER_POS[1][2] }
  ui.bindHeroes()
  ui.power[1]:RegisterForClicks("LeftButtonUp"); ui.power[1]:SetScript("OnClick", function() onPower() end)
  for s = 1, 2 do
    ui.power[s]:SetScript("OnEnter", function(self)
      local h = B.HERO[game.p[E(s)].class]
      win.tokTip:SetText("|cfff5d273" .. h.power .. "|r  (2 mana)\n" .. h.text); win.tokTip:Show()
    end)
    ui.power[s]:SetScript("OnLeave", function() win.tokTip:Hide() end)
    ui.weapon[s]:SetScript("OnEnter", function(self)
      local w = game.p[E(s)].weapon
      if w then win.tokTip:SetText("|cfff5d273" .. (w.name or "Weapon") .. "|r\n" .. w.atk .. " attack, " .. w.dur .. " durability"); win.tokTip:Show() end
    end)
    ui.weapon[s]:SetScript("OnLeave", function() win.tokTip:Hide() end)
    ui.hero[s]:SetScript("OnEnter", function() win.tokTip:SetText("|cfff5d273" .. game.p[E(s)].name .. "|r\n" .. B.HERO[game.p[E(s)].class].title); win.tokTip:Show() end)
    ui.hero[s]:SetScript("OnLeave", function() win.tokTip:Hide() end)
  end
  -- hand
  for i = 1, 10 do
    local w = U.makeCard(bd, HW); w.noTip = true; w.hover = false; w.hslot = i
    w.onCard = function(self, btn) onHand(self.hslot, btn) end
    w:HookScript("OnEnter", function(self) self.hov = true; if game and game.p[ME].hand[self.hslot] then preview(game.p[ME].hand[self.hslot], nil, 1) end; refresh() end)
    w:HookScript("OnLeave", function(self) self.hov = false; refresh() end)
    w:Hide(); ui.hand[i] = w
    local b = bd:CreateTexture(nil, "ARTWORK"); b:SetTexture(U.MEDIA .. "Back"); b:SetTexCoord(0, 1, 0, 358 / 512); b:SetSize(24, 34); b:Hide(); ui.back[i] = b
  end
  -- mana
  ui.mana = {}
  for s = 1, 2 do
    for i = 1, 10 do
      local c = bd:CreateTexture(nil, "ARTWORK"); c:SetTexture(U.MEDIA .. "Crystal"); c:SetSize(24, 24)
      c:SetPoint("CENTER", win, "BOTTOMLEFT", 1005 + ((i - 1) % 5) * 28, (s == 1 and 150 or 590) - math.floor((i - 1) / 5) * 28)
      c:Hide(); ui.crystals[s][i] = c
    end
    ui.mana[s] = U.fs(bd, "title", 19, "OVERLAY", "OUTLINE"); ui.mana[s]:SetPoint("CENTER", win, "BOTTOMLEFT", 1065, s == 1 and 186 or 626); ui.mana[s]:SetTextColor(0.6, 0.8, 1)
  end
  ui.deckT = { U.fs(bd, "head", 13, "OVERLAY"), U.fs(bd, "head", 13, "OVERLAY") }
  ui.deckT[1]:SetPoint("CENTER", win, "BOTTOMLEFT", 1065, 108); ui.deckT[2]:SetPoint("CENTER", win, "BOTTOMLEFT", 1065, 548)
  for s = 1, 2 do ui.deckT[s]:SetTextColor(0.75, 0.72, 0.9) end
  win.endBtn = U.gbtn(bd, "End Turn", 150, 40, endTurn, true); pt(win.endBtn, 1065, 378)
  win.turnT = U.fs(bd, "head", 13, "OVERLAY", "OUTLINE"); win.turnT:SetPoint("CENTER", win, "BOTTOMLEFT", 600, 378); win.turnT:SetTextColor(0.96, 0.84, 0.5)
  win.concede = U.gbtn(bd, "Concede", 90, 22, function(self)
    if not game or game.over then win:Hide() return end
    if not S.sure then S.sure = true; self:SetText("Sure?"); after(3, function() S.sure = false; if win.concede then win.concede:SetText("Concede") end end) return end
    S.sure = false; self:SetText("Concede"); game.over = true; game.winner = 3 - ME; S.endReason = S.pvp and "You conceded." or nil; if S.pvp and RG.Duel then RG.Duel.sendEnd("F") end; afterAction()
  end)
  win.concede:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 14, 10)
  win.mullBtn = U.gbtn(bd, "Keep these cards", 200, 38, function() RG.BattleMulligan() end, true); pt(win.mullBtn, 600, 418); win.mullBtn:Hide()
  -- the end screen
  win.over = CreateFrame("Frame", nil, win, "BackdropTemplate"); U.darkPanel(win.over, 420, 230); win.over:SetPoint("CENTER", 0, 20); win.over:SetFrameLevel(U.lv(win) + 80); win.over:EnableMouse(true); win.over:Hide()
  win.over.title = U.fs(win.over, "title", 34); win.over.title:SetPoint("TOP", 0, -30)
  win.over.body = U.fs(win.over, "body", 14); win.over.body:SetPoint("TOP", 0, -92); win.over.body:SetWidth(360); win.over.body:SetTextColor(0.9, 0.85, 0.72)
  local again = U.gbtn(win.over, "Another duel", 150, 30, function() win.over:Hide(); RG.BattleMenu() end); again:SetPoint("BOTTOMLEFT", 40, 24)
  local done = U.gbtn(win.over, "Close", 120, 30, function() win.over:Hide(); win:Hide() end); done:SetPoint("BOTTOMRIGHT", -40, 24)
end

refresh = function()
  if not (win and game and S.mode ~= "menu" and S.mode ~= "deck") then return end
  local me, foe = game.p[ME], game.p[3 - ME]
  local tg = S.targeting
  local mine = myTurn()
  ui.pos = { ["h1"] = ui.pos.h1, ["h2"] = ui.pos.h2, power1 = ui.pos.power1 }
  -- minions
  for s = 1, 2 do
    local P = game.p[E(s)]
    local n = #P.board
    for i = 1, 7 do
      local w, m = ui.mins[s][i], P.board[i]
      if m then
        local wasShown = rawget(w, "gx") ~= nil
        paintMinion(w, m, s)
        local x, y = boardPos(s, i, n)
        if wasShown then place(w, x, y) else
          place(w, x, y, x, y + (s == 1 and 46 or -46)); pt(w, w.gx, w.gy)   -- a new minion drops in
          w.flash = 0.45
        end
        ui.widgetOf[m.uid] = w
        ui.pos[m.uid] = { x, y + 8 }
        local col
        if tg then if tg.valid[m.uid] then col = s == 1 and GREEN or RED end
        elseif s == 1 and mine and S.mode == "play" and B.canAttack(game, ME, m) then col = GREEN end
        if col then w.glow:SetVertexColor(col[1], col[2], col[3], col[4]); w.glow:Show() else w.glow:Hide() end
      else w:Hide(); unplace(w) end
    end
  end
  -- heroes
  for s = 1, 2 do
    local P, h = game.p[E(s)], ui.hero[s]
    h.icon:SetTexture(CLS_ICON(P.class))
    h.hpT:SetText(P.hp); h.hpT:SetTextColor(1, P.hp < P.maxhp and 0.5 or 1, P.hp < P.maxhp and 0.5 or 1)
    local atk = B.heroAtk(P)
    Sh(h.atkB, atk > 0); Sh(h.atkT, atk > 0); h.atkT:SetText(atk)
    h.arm:SetText(P.armor > 0 and ("[" .. P.armor .. "]") or "")
    h.name:SetText(P.name)
    Sh(h.ice, P.frozen)
    local col
    if tg then if tg.valid["h" .. E(s)] then col = s == 1 and GREEN or RED end
    elseif s == 1 and mine and S.mode == "play" and B.canAttack(game, ME, P) then col = GREEN end
    if col then h.glow:SetVertexColor(col[1], col[2], col[3], col[4]); h.glow:Show() else h.glow:Hide() end
    -- power and weapon
    local pw, hp = ui.power[s], B.HERO[P.class]
    pw.icon:SetTexture("Interface\\Icons\\" .. (POWER_ICON[P.class] or "INV_Misc_QuestionMark"))
    pw.costT:SetText(hp.cost)
    pw.icon:SetDesaturated(P.hpUsed and true or false)
    pw.tile:SetVertexColor(P.hpUsed and 0.5 or 1, P.hpUsed and 0.5 or 0.85, P.hpUsed and 0.55 or 0.5, 1)
    Sh(pw.glow, s == 1 and mine and S.mode == "play" and B.canHeroPower(game, ME))
    pt(pw, POWER_POS[s][1], POWER_POS[s][2])
    local wp = ui.weapon[s]
    if P.weapon then
      wp:Show(); wp.icon:SetTexture("Interface\\Icons\\INV_Sword_04"); wp.t1:SetText(P.weapon.atk); wp.t2:SetText(P.weapon.dur)
      wp.tile:SetVertexColor(1, 0.85, 0.5, 1)
    else wp:Hide() end
    -- mana
    for i = 1, 10 do
      local c = ui.crystals[s][i]
      c:Show(); c:SetTexture(U.MEDIA .. (i <= P.mana and "Crystal" or "CrystalDim")); c:SetAlpha(i <= P.maxMana and 1 or 0.28)
    end
    ui.mana[s]:SetText(P.mana .. " / " .. P.maxMana)
    ui.deckT[s]:SetText("|cffa89bc9Deck|r |cffffffff" .. #P.deck .. "|r     |cffa89bc9Hand|r |cffffffff" .. #P.hand .. "|r")
  end
  -- opponent hand
  local nb = #foe.hand
  for i = 1, 10 do
    local b = ui.back[i]
    if i <= nb then
      b:ClearAllPoints(); b:SetPoint("CENTER", win, "BOTTOMLEFT", 600 + (i - (nb + 1) / 2) * 26, 681); b:SetTexture(U.MEDIA .. RG.CardBackName()); b:Show()
    else b:Hide() end
  end
  -- my hand
  local n = #me.hand
  local mull = S.mode == "mull"
  local step = n > 1 and math.min(mull and 116 or 88, 640 / (n - 1)) or 0
  for i = 1, 10 do
    local w, key = ui.hand[i], me.hand[i]
    if key then
      local x = 600 - (n - 1) * step / 2 + (i - 1) * step
      local y = (w.hov and not mull) and 108 or 68
      if mull then y = 332 end
      local fresh = rawget(w, "gx") == nil
      if fresh and not mull then place(w, x, y, DECK_POS[1][1], DECK_POS[1][2]); pt(w, w.gx, w.gy) else place(w, x, y) end
      if fresh and mull then w.gx, w.gy = x, y; pt(w, x, y) end
      w:SetFrameLevel(U.lv(win.board) + 10 + i * 6 + (w.hov and 80 or 0))
      w.hslot = i
      paintCard(w, key, 1)
      local can = mine and S.mode == "play" and not tg and B.canPlay(game, ME, i)
      Sh(w.playGlow, can)
      Sh(w.xMark, mull and S.mull[i])
      -- cards you can't afford this turn look dimmer, with a red cost
      local dim = mine and S.mode == "play" and not tg and not can
      w:SetAlpha(mull and S.mull[i] and 0.6 or (dim and 0.8 or 1))
      if w.costT then w.costT:SetTextColor(dim and 1 or 1, dim and 0.4 or 1, dim and 0.4 or 1) end
    else w:Hide(); unplace(w) end
  end
  -- buttons
  win.endBtn:SetEnabled(mine and S.mode == "play")
  local idle = mine and S.mode == "play" and #B.actions(game, ME) == 0
  win.endBtn:SetActive(idle and true or false)
  win.turnT:SetText(game.over and "" or (S.mode == "mull" and "OPENING HAND" or (game.cur == ME and "YOUR TURN" or (S.pvp and (string.upper(S.foeName or "") .. "'S TURN") or "OPPONENT'S TURN"))))
  if win.turnT.SetTextColor then if game.cur == ME or S.mode == "mull" then win.turnT:SetTextColor(0.96, 0.84, 0.5) else win.turnT:SetTextColor(0.82, 0.66, 0.98) end end
end

-- ---------------------------------------------------------------------------
-- Starting a duel
-- ---------------------------------------------------------------------------
local aiPools = {}
local function aiPool()
  if not aiPools.keys then
    aiPools.keys = {}
    for _, c in ipairs(U.CARDS) do
      if c.kind ~= 4 then local k = c.key or c.name; if not B.defs[k] then B.derive(c) end; aiPools.keys[#aiPools.keys + 1] = k end
    end
    for _, k in ipairs(B.BASIC) do aiPools.keys[#aiPools.keys + 1] = k end
  end
  return aiPools.keys
end

local function show(which)
  S.mode = which == "board" and S.mode or which
  Sh(win.menu, which == "menu"); Sh(win.deck, which == "deck"); Sh(win.board, which == "board")
  Sh(win.bg, which == "board")
  win.title:SetText(which == "menu" and "WAYPATH ARENA" or which == "deck" and "DECK BUILDER" or "WAYPATH ARENA")
  if which ~= "board" then for _, d in ipairs(ui.dots) do d:Hide() end end
end

local function beginGame(g)
  game = g
  S.gid = (S.gid or 0) + 1
  S.mode, S.mull, S.targeting, S.finished, S.busy, S.aiN, S.mullSent = "mull", {}, false, false, false, 0, false
  win.over:Hide(); logLines = {}; win.log:SetText("")
  for _, w in ipairs(ui.hand) do w.pkey = false; w.hov = false; unplace(w) end
  for s2 = 1, 2 do for _, w in ipairs(ui.mins[s2]) do unplace(w) end end
  ui.pos = { power1 = ui.pos.power1 }; ui.bindHeroes()
  show("board"); S.mode = "mull"
  win.pv:Hide()
  win.mullBtn:Show(); win.mullBtn:SetEnabled(true); win.mullBtn:SetText("Keep these cards")
  say("Click any cards you want to swap, then keep the rest.", 600)
  refresh()
  logLine("|cfff5d273" .. (game.first == ME and "You go first." or ((S.pvp and (S.foeName or "Your friend") or "The foe") .. " goes first. You get the Lucky Coin.")) .. "|r")
end

local function startMatch()
  local a = store(); if not a then return end
  local dk = deckOf(a, a.deckSel or 1)
  cleanDeck(a, dk)
  if deckSize(dk) ~= B.DECK then say("Your deck needs exactly " .. B.DECK .. " cards.", 3) return end
  for _, k in ipairs(expand(dk)) do if not B.defs[k] then return end end
  local cap = ({ 3, 4, 5 })[S.level]
  local aiDeck = B.randomDeck(aiPool(), cap, math.random)
  local cls = a.heroClass or select(2, UnitClass("player")) or "WARRIOR"
  local aiCls = B.CLASSES[math.random(#B.CLASSES)]
  ME, S.pvp, S.foeName, S.endReason = 1, false, nil, nil
  beginGame(B.new({ decks = { expand(dk), aiDeck }, classes = { cls, aiCls }, names = { (UnitName and UnitName("player")) or "You", B.OPPONENTS[aiCls] }, seed = math.random(1, 2000000000) }))
end

function RG.BattleMulligan()
  if not game or S.mode ~= "mull" then return end
  if S.pvp then
    if S.mullSent then return end
    S.mullSent = true
    local set = {}
    for i, v in pairs(S.mull) do if v then set[i] = true end end
    win.mullBtn:SetEnabled(false); win.mullBtn:SetText("Waiting for " .. (S.foeName or "your friend") .. "...")
    if RG.Duel then RG.Duel.mulligan(ME, set) end
    return
  end
  B.mulligan(game, 1, S.mull)
  local set = {}
  for i, k in ipairs(game.p[2].hand) do local d = B.defs[k]; if d and d.cost >= 4 and k ~= "coin" then set[i] = true end end
  B.mulligan(game, 2, set)
  S.mode = "play"; S.mull = {}
  win.mullBtn:Hide(); say("", 0)
  afterAction()
  if not game.over and game.cur == 2 then startAI() end
end

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------
local menu = { cls = {}, slots = {}, lvl = {} }
local function myClass(a)
  local _, c = UnitClass and UnitClass("player")
  return a.heroClass or c or "WARRIOR"
end
local function refreshMenu()
  local a = store(); if not a then return end
  local dk = deckOf(a, a.deckSel or 1)
  cleanDeck(a, dk)
  local cls = myClass(a)
  for c, b in pairs(menu.cls) do b:SetActive(c == cls) end
  for i, b in ipairs(menu.slots) do b:SetActive(i == (a.deckSel or 1)); local n = deckSize(deckOf(a, i)); b:SetText("Deck " .. i .. "  (" .. n .. ")") end
  for i, b in ipairs(menu.lvl) do b:SetActive(i == S.level) end
  for i, b in ipairs(menu.backs or {}) do
    local on = i == (a.cardBack or 1)
    if on then b:SetBackdropBorderColor(U.GOLDC[1], U.GOLDC[2], U.GOLDC[3], 1) else b:SetBackdropBorderColor(0.3, 0.27, 0.22, 0.9) end
  end
  local h = B.HERO[cls]
  menu.power:SetText("|cfff5d273" .. h.power .. "|r  (2 mana):  " .. h.text)
  local n = deckSize(dk)
  menu.deckInfo:SetText(n == B.DECK and "|cff9fe39aDeck ready|r" or ("|cffe39a9a" .. n .. " / " .. B.DECK .. " cards|r"))
  menu.play:SetEnabled(n == B.DECK)
  if menu.pvp then menu.pvp:SetEnabled(n == B.DECK) end
  menu.play:SetText(n == B.DECK and "Enter the Arena" or "Finish your deck first")
  menu.lvlInfo:SetText(({ "Plays loosely with a plain deck.  Win: " .. REWARD[1] .. " coins.", "Plays sensibly.  Win: " .. REWARD[2] .. " coins.", "Plays carefully with a full deck, bosses included.  Win: " .. REWARD[3] .. " coins." })[S.level])
  menu.rec:SetText("Arena record: " .. (a.bWins or 0) .. " won, " .. (a.bLoss or 0) .. " lost.  Your first win each day pays +8 coins." .. (((a.pvpWins or 0) + (a.pvpLoss or 0)) > 0 and ("  Player duels: " .. (a.pvpWins or 0) .. " won, " .. (a.pvpLoss or 0) .. " lost.") or ""))
end
local deckRefresh = function() end

local function buildMenu()
  local p = CreateFrame("Frame", nil, win.menu, "BackdropTemplate")
  U.darkPanel(p, 840, 660); p:SetPoint("CENTER", win, "CENTER", 0, -4)
  local function label(txt, y) local f = U.fs(p, "head", 12); f:SetPoint("TOPLEFT", 24, y); f:SetTextColor(U.GOLDC[1], U.GOLDC[2], U.GOLDC[3]); f:SetText(txt); return f end
  local t = U.fs(p, "title", 28); t:SetPoint("TOP", 0, -22); t:SetTextColor(U.GOLDC[1], U.GOLDC[2], U.GOLDC[3]); t:SetText("WAYPATH ARENA")
  local lg = p:CreateTexture(nil, "ARTWORK"); lg:SetTexture(RG.LOGO_LARGE or RG.LOGO); lg:SetSize(52, 52); lg:SetPoint("TOPLEFT", 24, -14)
  local lg2 = p:CreateTexture(nil, "ARTWORK"); lg2:SetTexture(RG.LOGO_LARGE or RG.LOGO); lg2:SetSize(52, 52); lg2:SetPoint("TOPRIGHT", -24, -14)
  local sub = U.fs(p, "body", 13); sub:SetPoint("TOP", 0, -62); sub:SetTextColor(0.8, 0.76, 0.9); sub:SetText("Duel with the cards you have found. Every card plays as a minion, a spell or a weapon.")
  label("CHOOSE YOUR HERO", -100)
  for i, c in ipairs(B.CLASSES) do
    local b = U.gbtn(p, B.HERO[c].title, 84, 26, function() local a = store(); a.heroClass = c; refreshMenu() end)
    b:SetPoint("TOPLEFT", 24 + (i - 1) * 88, -122); menu.cls[c] = b
  end
  menu.power = U.fs(p, "body", 13); menu.power:SetPoint("TOPLEFT", 24, -156); menu.power:SetTextColor(0.85, 0.8, 0.7)
  label("YOUR DECK", -190)
  for i = 1, 3 do
    local b = U.gbtn(p, "Deck " .. i, 110, 26, function() local a = store(); a.deckSel = i; refreshMenu() end)
    b:SetPoint("TOPLEFT", 24 + (i - 1) * 116, -212); menu.slots[i] = b
  end
  local edit = U.gbtn(p, "Edit deck", 110, 26, function() RG.BattleDeck() end); edit:SetPoint("TOPLEFT", 388, -212)
  local auto = U.gbtn(p, "Auto-fill", 110, 26, function() local a = store(); fillDeck(a, deckOf(a, a.deckSel or 1)); refreshMenu() end); auto:SetPoint("TOPLEFT", 504, -212)
  menu.deckInfo = U.fs(p, "head", 12); menu.deckInfo:SetPoint("TOPLEFT", 630, -218)
  label("OPPONENT", -256)
  for i = 1, 3 do
    local b = U.gbtn(p, LEVELS[i], 130, 26, function() S.level = i; local a = store(); a.level = i; refreshMenu() end)
    b:SetPoint("TOPLEFT", 24 + (i - 1) * 136, -278); menu.lvl[i] = b
  end
  menu.lvlInfo = U.fs(p, "body", 13); menu.lvlInfo:SetPoint("TOPLEFT", 440, -283); menu.lvlInfo:SetWidth(380); menu.lvlInfo:SetJustifyH("LEFT"); menu.lvlInfo:SetTextColor(0.85, 0.8, 0.7)
  menu.play = U.gbtn(p, "Enter the Arena", 300, 46, function() startMatch() end, true); menu.play:SetPoint("TOP", 0, -334)
  menu.pvp = U.gbtn(p, "Challenge a player", 220, 38, function()
    if not RG.DuelTarget then return end
    local ok, err, who = RG.DuelTarget()
    menu.msg:SetText(ok and ("Challenge sent to " .. who .. ".") or (err or ""))
  end)
  menu.pvp:SetPoint("TOPLEFT", 596, -342)
  menu.pvp:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText("Friendly duel with another Waypath+ player"); GameTooltip:AddLine("Target them first (or type /wp duel Name). You both play your selected Arena deck. No coins change hands.", 1, 1, 1, true); GameTooltip:Show() end)
  menu.pvp:SetScript("OnLeave", function() GameTooltip:Hide() end)
  label("HOW IT PLAYS", -400)
  local rules = U.fs(p, "body", 13); rules:SetPoint("TOPLEFT", 24, -422); rules:SetWidth(790); rules:SetJustifyH("LEFT"); rules:SetJustifyV("TOP"); rules:SetTextColor(0.82, 0.78, 0.7); if rules.SetSpacing then rules:SetSpacing(3) end
  rules:SetText("Each hero has 30 health. You gain one more mana crystal every turn, up to ten, and draw a card.\n"
    .. "Click a card in your hand to play it. Click a minion that glows green, then something to attack. New minions must wait a turn, unless they have Charge (anything) or Rush (minions only).\n"
    .. "Taunt must be attacked first. Divine Shield blocks one hit. Battlecries happen when a card is played, deathrattles when it dies, and some minions act at the end of your turn.\n"
    .. "Items become spells and weapons, NPCs and Raiders become minions, and Places become area spells. Every card plays the same way every time. Holo and full-art prints are for show.\n"
    .. "A deck is 30 cards, two copies of each (one of each legendary). Cards you have not found yet are not available, but a few basic cards always are.")
  menu.rec = U.fs(p, "head", 12); menu.rec:SetPoint("BOTTOM", 0, 56); menu.rec:SetTextColor(0.75, 0.72, 0.9)
  local back = U.gbtn(p, "Back to cards", 130, 26, function() win:Hide(); if RG.ShowArcade then RG.ShowArcade() end end); back:SetPoint("BOTTOMLEFT", 24, 18)
  menu.msg = U.fs(p, "head", 13); menu.msg:SetPoint("BOTTOMRIGHT", -24, 74); menu.msg:SetTextColor(1, 0.7, 0.5)
  -- card backs: pick the one your opponent's hand and your packs show
  menu.backs = {}
  for i, name in ipairs(BACKS) do
    local b = CreateFrame("Button", nil, p, "BackdropTemplate")
    b:SetSize(34, 48); b:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -24 - (#BACKS - i) * 42, 16)
    b:SetBackdrop({ bgFile = U.WHITE, edgeFile = U.WHITE, edgeSize = 2 }); b:SetBackdropColor(0, 0, 0, 1)
    b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetTexture(U.MEDIA .. name); b.tex:SetTexCoord(0, 1, 0, 358 / 512); b.tex:SetPoint("TOPLEFT", 2, -2); b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    b:SetScript("OnClick", function() local a = store(); if a then a.cardBack = i end; refreshMenu(); if RG.ArcadeRefresh then pcall(RG.ArcadeRefresh, true) end end)
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(BACK_NAMES[i] .. " card back"); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    menu.backs[i] = b
  end
  local cbl = U.fs(p, "head", 12); cbl:SetPoint("RIGHT", menu.backs[1], "LEFT", -10, 0); cbl:SetTextColor(U.GOLDC[1], U.GOLDC[2], U.GOLDC[3]); cbl:SetText("CARD BACK")
end

-- ---------------------------------------------------------------------------
-- Deck builder
-- ---------------------------------------------------------------------------
local D = { cost = nil, typ = nil, page = 1, search = "", cells = {}, rows = {}, list = {}, per = 15 }
local function deckCountOf(dk, key) return dk.cards[key] or 0 end
local function curDeck() local a = store(); return a, deckOf(a, a.deckSel or 1) end
local function limitFor(a, key) local have = avail(a); return have[key] or 0 end

local function computeList()
  local a = store()
  local have, keys = avail(a)
  local out = {}
  local s = D.search:lower()
  for _, k in ipairs(keys) do
    local d = B.defs[k]
    local ok = true
    if D.cost then if D.cost == 7 then ok = d.cost >= 7 else ok = d.cost == D.cost end end
    if ok and D.typ and d.type ~= D.typ then ok = false end
    if ok and s ~= "" and not d.name:lower():find(s, 1, true) then ok = false end
    if ok then out[#out + 1] = k end
  end
  table.sort(out, function(x, y) local a1, b1 = B.defs[x], B.defs[y]; if a1.cost ~= b1.cost then return a1.cost < b1.cost end return a1.name < b1.name end)
  D.list = out
end

deckRefresh = function()
  if not (win and win.deck) then return end
  local a, dk = curDeck()
  cleanDeck(a, dk)
  computeList()
  local pages = math.max(1, math.ceil(#D.list / D.per))
  if D.page > pages then D.page = pages end
  if D.page < 1 then D.page = 1 end
  for i, w in ipairs(D.cells) do
    local k = D.list[(D.page - 1) * D.per + i]
    if k then
      paintCard(w, k, 1)
      local have, lim = deckCountOf(dk, k), limitFor(a, k)
      w.count:SetText(have .. "/" .. lim)
      w:SetAlpha(have >= lim and 0.45 or 1)
      w.key = k
    else w:Hide(); w.key = nil end
  end
  D.pageT:SetText("Page " .. D.page .. " / " .. pages .. "   (" .. #D.list .. " cards)")
  -- the deck list, in cost order
  local rows = {}
  for k, v in pairs(dk.cards) do rows[#rows + 1] = k end
  table.sort(rows, function(x, y) local a1, b1 = B.defs[x], B.defs[y]; if a1.cost ~= b1.cost then return a1.cost < b1.cost end return a1.name < b1.name end)
  for i, r in ipairs(D.rows) do
    local k = rows[i]
    if k then
      local d = B.defs[k]
      r.key = k; r:Show()
      r.cost:SetText(d.cost)
      r.name:SetText(d.name)
      local tc = (U.TIER[d.tier or 1] or U.TIER[1])[3]
      r.name:SetTextColor(tc[1], tc[2], tc[3])
      r.n:SetText(dk.cards[k] > 1 and ("x" .. dk.cards[k]) or "")
    else r:Hide(); r.key = nil end
  end
  local n = deckSize(dk)
  D.count:SetText(n .. " / " .. B.DECK)
  D.count:SetTextColor(n == B.DECK and 0.6 or 1, n == B.DECK and 1 or 0.8, n == B.DECK and 0.6 or 0.5)
  D.name:SetText("Deck " .. (a.deckSel or 1))
  -- filter buttons
  for c, b in pairs(D.costB) do b:SetActive(c == (D.cost or "all")) end
  for t, b in pairs(D.typB) do b:SetActive(t == (D.typ or "all")) end
end

local function addCard(key)
  local a, dk = curDeck()
  if deckSize(dk) >= B.DECK then say("The deck is full.", 2) D.hint:SetText("The deck is full (" .. B.DECK .. ")."); return end
  if deckCountOf(dk, key) >= limitFor(a, key) then D.hint:SetText("You cannot add more copies of that."); return end
  dk.cards[key] = deckCountOf(dk, key) + 1
  D.hint:SetText("")
  deckRefresh()
end
local function removeCard(key)
  local a, dk = curDeck()
  local n = deckCountOf(dk, key)
  if n <= 0 then return end
  dk.cards[key] = n > 1 and n - 1 or nil
  deckRefresh()
end

local function buildDeck()
  local dscr = win.deck
  win.pv2 = U.makeCard(dscr, 230); pt(win.pv2, 700, 462); win.pv2.noTip = true; win.pv2.hover = false; win.pv2:Hide()
  D.costB, D.typB = {}, {}
  local function fbtn(label, w, x, store_, k, fn)
    local b = U.gbtn(dscr, label, w, 22, fn); b:SetPoint("TOPLEFT", win, "TOPLEFT", x, -46); store_[k] = b; return b
  end
  fbtn("All", 36, 24, D.costB, "all", function() D.cost = nil; D.page = 1; deckRefresh() end)
  for c = 0, 7 do fbtn(c == 7 and "7+" or tostring(c), 36, 24 + (c + 1) * 40, D.costB, c, function() D.cost = c; D.page = 1; deckRefresh() end) end
  fbtn("All", 44, 24 + 9 * 40 + 14, D.typB, "all", function() D.typ = nil; D.page = 1; deckRefresh() end)
  local xs = 24 + 9 * 40 + 14 + 48
  for _, t in ipairs({ { "minion", "Minions" }, { "spell", "Spells" }, { "weapon", "Weapons" } }) do
    fbtn(t[2], 70, xs, D.typB, t[1], function() D.typ = t[1]; D.page = 1; deckRefresh() end); xs = xs + 74
  end
  -- search
  local sb = CreateFrame("EditBox", nil, dscr, "BackdropTemplate")
  sb:SetSize(130, 22); sb:SetPoint("TOPLEFT", win, "TOPLEFT", 24 + 9 * 40 + 14 + 48 + 3 * 74 + 6, -46)
  sb:SetBackdrop({ bgFile = U.WHITE, edgeFile = U.WHITE, edgeSize = 1 }); sb:SetBackdropColor(0.03, 0.02, 0.07, 0.95); sb:SetBackdropBorderColor(0.45, 0.38, 0.25, 0.9)
  U.setfont(sb, "body", 12); sb:SetTextColor(0.95, 0.9, 0.78); sb:SetTextInsets(8, 6, 0, 0); sb:SetAutoFocus(false); sb:SetMaxLetters(30)
  sb:SetScript("OnTextChanged", function(self) local t = self:GetText() or ""; if t ~= D.search then D.search = t; D.page = 1; deckRefresh() end end)
  sb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  D.sb = sb
  local hint = U.fs(sb, "body", 12); hint:SetPoint("LEFT", 8, 0); hint:SetText("Search"); hint:SetTextColor(0.5, 0.46, 0.62)
  sb:SetScript("OnEditFocusGained", function() hint:Hide() end)
  sb:SetScript("OnEditFocusLost", function(self) hint:SetShown((self:GetText() or "") == "") end)
  -- the grid
  for i = 1, D.per do
    local w = U.makeCard(dscr, HW); w.noTip = true; w.hover = false
    local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
    pt(w, 76 + col * 108, 536 - row * 150)
    w.onCard = function(self, btn) if self.key then if btn == "RightButton" then removeCard(self.key) else addCard(self.key) end end end
    w:HookScript("OnEnter", function(self) if self.key then preview(self.key, nil, 1) end end)
    D.cells[i] = w; w:Hide()
  end
  D.pageT = U.fs(dscr, "head", 12); D.pageT:SetPoint("CENTER", win, "BOTTOMLEFT", 300, 112); D.pageT:SetTextColor(0.78, 0.74, 0.9)
  local prev = U.gbtn(dscr, "<", 36, 24, function() D.page = D.page - 1; deckRefresh() end); prev:SetPoint("CENTER", win, "BOTTOMLEFT", 170, 112)
  local nxt = U.gbtn(dscr, ">", 36, 24, function() D.page = D.page + 1; deckRefresh() end); nxt:SetPoint("CENTER", win, "BOTTOMLEFT", 430, 112)
  local tips = U.fs(dscr, "body", 12); tips:SetPoint("CENTER", win, "BOTTOMLEFT", 700, 270); tips:SetWidth(230); tips:SetTextColor(0.7, 0.67, 0.82)
  tips:SetText("Click a card to add it.\nRight-click to take one out.\nTwo copies of each, one of each legendary.")
  D.hint = U.fs(dscr, "head", 12); D.hint:SetPoint("CENTER", win, "BOTTOMLEFT", 700, 220); D.hint:SetWidth(230); D.hint:SetTextColor(1, 0.7, 0.5); D.hint:SetText("")
  -- the list
  D.name = U.fs(dscr, "title", 16); D.name:SetPoint("TOPLEFT", win, "TOPLEFT", 836, -42); D.name:SetTextColor(U.GOLDC[1], U.GOLDC[2], U.GOLDC[3])
  D.count = U.fs(dscr, "title", 16); D.count:SetPoint("TOPRIGHT", win, "TOPRIGHT", -20, -42)
  for i = 1, 30 do
    local r = CreateFrame("Button", nil, dscr)
    r:SetSize(326, 18); r:SetPoint("TOPLEFT", win, "TOPLEFT", 836, -66 - (i - 1) * 18.4)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetColorTexture(0.1, 0.08, 0.2, i % 2 == 0 and 0.55 or 0.3); r.bg:SetAllPoints(r)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetColorTexture(1, 0.9, 0.5, 0.12); r.hl:SetAllPoints(r)
    r.cost = U.fs(r, "title", 11, "OVERLAY"); r.cost:SetPoint("LEFT", 8, 0); r.cost:SetTextColor(0.5, 0.75, 1); r.cost:SetWidth(20)
    r.name = U.fs(r, "head", 11, "OVERLAY"); r.name:SetPoint("LEFT", 32, 0); r.name:SetWidth(240); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.n = U.fs(r, "head", 11, "OVERLAY"); r.n:SetPoint("RIGHT", -8, 0); r.n:SetTextColor(1, 0.9, 0.5)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self) if self.key then removeCard(self.key) end end)
    r:SetScript("OnEnter", function(self) if self.key then preview(self.key, nil, 1) end end)
    r:Hide(); D.rows[i] = r
  end
  local done = U.gbtn(dscr, "Done", 100, 26, function() RG.BattleMenu() end, true); done:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -20, 14)
  local clear = U.gbtn(dscr, "Clear", 80, 26, function() local a, dk = curDeck(); dk.cards = {}; deckRefresh() end); clear:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -128, 14)
  local fill = U.gbtn(dscr, "Auto-fill", 100, 26, function() local a, dk = curDeck(); fillDeck(a, dk); deckRefresh() end); fill:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -216, 14)
end

function RG.BattleDeck() show("deck"); deckRefresh() end
function RG.BattleMenu()
  S.targeting = false
  show("menu"); refreshMenu()
  if game and not game.over and (S.mode == "play" or S.mode == "mull") then end
end

function RG.ShowBattle()
  if WaypathFrame and WaypathFrame.IsShown and WaypathFrame:IsShown() then WaypathFrame:Hide() end   -- never stack on the main window
  if not win then
    U = RG.ArcadeUI
    if not U then if RG.Print then RG.Print("Waypath Arena needs the card window files (Arcade.lua) to load.") end return end
    buildWindow(); makeBoard(); buildMenu(); buildDeck()
    local a = store(); if a and a.level then S.level = a.level end
  end
  local a = store(); if a then a.seen = true end
  win:Show()
  if game and not game.over and (S.mode == "play" or S.mode == "mull") then show("board"); refresh()
  else S.mode = "menu"; RG.BattleMenu() end
end

local slashBase = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  cmd = cmd and cmd:lower()
  if cmd == "arena" or cmd == "duel" then
    local ok, err = xpcall(RG.ShowBattle, function(e) return tostring(e) .. " " .. tostring(debugstack and debugstack(2, 3, 0) or "") end)
    if not ok then
      if win then win:Hide() end
      win = nil   -- rebuild next time
      if RG.Print then RG.Print("Waypath Arena hit a snag: " .. tostring(err)) end
    elseif not (win and win:IsShown()) then
      if RG.Print then RG.Print("Waypath Arena did not open. Try /reload and /wp arena again.") end
    end
    return
  end
  return slashBase(msg)
end

-- ---------------------------------------------------------------------------
-- Hooks for player-versus-player duels (the messaging lives in ArcadeDuel.lua)
-- ---------------------------------------------------------------------------
function RG.ArenaPvPDeck()
  U = U or RG.ArcadeUI
  if not U then return nil, "The card window is not ready yet." end
  local a = store(); if not a then return nil, "Your card collection is not ready yet." end
  local dk = deckOf(a, a.deckSel or 1)
  cleanDeck(a, dk)
  local auto = false
  if deckSize(dk) ~= B.DECK then   -- no finished deck yet: build one for this duel (your saved deck is left alone)
    local tmp = { name = "duel", cards = {} }
    for k, v in pairs(dk.cards) do tmp.cards[k] = v end
    pcall(fillDeck, a, tmp)
    if deckSize(tmp) ~= B.DECK then return nil, "Your deck needs exactly " .. B.DECK .. " cards. Open the Waypath Arena menu to finish it." end
    dk, auto = tmp, true
  end
  local list = expand(dk)
  for _, k in ipairs(list) do
    if not B.defs[k] then return nil, "A card in your deck is not ready yet." end
  end
  -- Raider cards only exist on your own collection, so the other player could not load them: swap them out for this duel
  local keep, swapped = {}, 0
  for _, k in ipairs(list) do if k:sub(1, 1) == "@" then swapped = swapped + 1 else keep[#keep + 1] = k end end
  if swapped > 0 then
    local have, keys = avail(a)
    local pool, limit = {}, {}
    for _, k in ipairs(keys) do if k:sub(1, 1) ~= "@" then pool[#pool + 1] = k end end
    local deck = B.randomDeck(pool, 6, math.random, keep, function(k) return math.min(have[k] or 0, B.maxCopies(B.defs[k])) end)
    list = deck
    if #list ~= B.DECK then return nil, "Could not build a duel deck without your Raider cards." end
  end
  return list, myClass(a), (UnitName and UnitName("player")) or "Player", swapped, auto
end
function RG.ArenaPvPStart(o)
  U = U or RG.ArcadeUI
  if not win then RG.ShowBattle() end
  if not win then return false end
  ME, S.pvp, S.foeName, S.endReason = o.me, true, o.foeName, nil
  beginGame(B.new({ decks = o.decks, classes = o.classes, names = o.names, seed = o.seed, first = o.first }))
  win:Show()
  return true
end
function RG.ArenaPvPApplyMull(set1, set2)
  if not game or S.mode ~= "mull" then return end
  B.mulligan(game, 1, set1); B.mulligan(game, 2, set2)
  S.mode, S.mull = "play", {}
  win.mullBtn:Hide(); say("", 0)
  afterAction()
end
function RG.ArenaPvPMove(act)       -- the opponent's move, returns true and the engine seed afterwards
  if not game or game.over or game.phase ~= "play" or game.cur == ME then return false end
  clearTarget()
  local ok
  if act.t == "end" then ok = B.endTurn(game, 3 - ME) else ok = B.exec(game, 3 - ME, act) end
  afterAction()
  return ok and true or false, game.seed
end
function RG.ArenaPvPOver(winner, why)
  if not game or game.over then return end
  game.over, game.winner, S.endReason = true, winner, why
  afterAction()
end
function RG.ArenaPvPState() return game, ME, S end
function RG.ArenaPvPSeed() return game and game.seed end
function RG.ArenaPvPSetSend(fn) sendMove = fn end

-- test hooks
RG.__battleGame = function() return game end
RG.__battleBusy = function() return S.busy end
RG.__battleAfter = function() afterAction() end
RG.__battleUI = function() return ui, S end
