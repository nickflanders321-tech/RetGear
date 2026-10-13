-- Waypath+ extras: quest reward picker, Exorcism alerts, weapon stone reminder,
-- XP per hour and session summary, character-screen scores, talent planner.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLDC = { 1, 0.82, 0 }

-- New options (shown in the Settings tab)
for _, o in ipairs({
  { key = "rewardPicker", label = "Highlight the best quest reward", default = true },
  { key = "exorcism",     label = "Alert me to use Exorcism on Undead and Demons", default = true },
  { key = "stoneReminder", label = "Remind me to sharpen my weapon", default = true },
  { key = "paperdoll",    label = "Show upgrade scores on my character screen", default = true },
  { key = "talentReminder", label = "Remind me to spend talent points", default = true },
}) do table.insert(RG.OPTIONS, o) end

local function itemInfoInstant(x) return (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(x) end
local function count(id) return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id)) or (GetItemCount and GetItemCount(id)) or 0 end

-- ===========================================================================
-- 1. Quest reward picker
-- ===========================================================================
local marks = {}
local function rewardButton(i)
  if QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons and QuestInfoRewardsFrame.RewardButtons[i] then return QuestInfoRewardsFrame.RewardButtons[i] end
  return _G["QuestInfoRewardsFrameQuestInfoItem" .. i] or _G["QuestInfoItem" .. i]
end
local function clearMarks() for _, m in pairs(marks) do m:Hide() end end
local function markButton(i, text, good)
  local b = rewardButton(i)
  if not b then return end
  local m = marks[b]
  if not m then
    m = CreateFrame("Frame", nil, b, "BackdropTemplate")
    m:SetPoint("TOPLEFT", -3, 3); m:SetPoint("BOTTOMRIGHT", 3, -3); m:SetFrameLevel((b:GetFrameLevel() or 1) + 5)
    RG.Backdrop(m, { 0, 0, 0, 0 }, { GOLDC[1], GOLDC[2], GOLDC[3], 1 })
    m.label = m:CreateFontString(nil, "OVERLAY"); m.label:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE"); m.label:SetPoint("BOTTOMRIGHT", -4, 3)
    marks[b] = m
  end
  m:SetBackdropBorderColor(good and 0.31 or GOLDC[1], good and 0.68 or GOLDC[2], good and 0.48 or GOLDC[3], 1)
  m.label:SetText(text); m:Show()
end

-- Score every quest reward choice. Returns a table:
-- { upI, up, goldI, gold, healI, heal, unknown = true if some item hasn't loaded }
function RG.ScoreRewards()
  local n = GetNumQuestChoices and GetNumQuestChoices() or 0
  local r = { up = 0.5, gold = -1, heal = 0.5, n = n }
  for i = 1, n do
    local link = GetQuestItemLink("choice", i)
    if not link then r.unknown = true else
      local _, _, _, _, minLevel, _, _, _, _, _, sell = RG.ItemInfo(link)
      if not minLevel then r.unknown = true end
      local loc = RG.EquipLoc(link)
      if loc and RG.EQUIP_SLOTS[loc] and (minLevel or 0) <= UnitLevel("player") + 1 then
        local d = RG.Compare(link)
        if d and d > r.up then r.up, r.upI = d, i end
        if RG.HealDelta and RG.SecondSetOn and RG.SecondSetOn() and UnitLevel("player") >= 30 then
          local hd = RG.HealDelta(link)
          if hd and hd > r.heal then r.heal, r.healI = hd, i end
        end
      end
      local _, _, qty = GetQuestItemInfo("choice", i)
      local value = (sell or 0) * (qty or 1)
      if value > r.gold then r.gold, r.goldI = value, i end
    end
  end
  return r
end

local function pickReward()
  clearMarks()
  if not RG.Opt("rewardPicker") then return end
  local n = GetNumQuestChoices and GetNumQuestChoices() or 0
  if n < 2 then return end
  local r = RG.ScoreRewards()
  local bestUp, bestUpI, bestGold, bestGoldI = r.up, r.upI, r.gold, r.goldI
  if r.healI and r.healI ~= bestUpI then markButton(r.healI, "|cffF58CBA" .. (RG.SecondSpecName and RG.SecondSpecName() or "2nd spec") .. " +" .. string.format("%.0f", r.heal) .. "|r", true) end
  if bestUpI then
    markButton(bestUpI, GREEN .. string.format("%s +%.0f", (RG.ActiveClass and RG.ActiveClass.scoreName) or "Upgrade", bestUp) .. "|r", true)
    RG.Print("Best quest reward for you: " .. (GetQuestItemLink("choice", bestUpI) or "") .. " " .. GREEN .. string.format("(+%.0f %s)", bestUp, RG.SCORE_NAME) .. "|r")
  elseif bestGoldI and bestGold > 0 then
    markButton(bestGoldI, GOLD .. "Sells best|r", false)
    RG.Print("No upgrades here. " .. (GetQuestItemLink("choice", bestGoldI) or "") .. " sells for the most (" .. RG.Money(bestGold) .. ").")
  end
end

-- ===========================================================================
-- 2. Exorcism alert on Undead and Demon targets
-- ===========================================================================
local exo
local function knows(name)
  if C_Spell and C_Spell.GetSpellInfo then local i = C_Spell.GetSpellInfo(name); return i and (not IsPlayerSpell or IsPlayerSpell(i.spellID)) end
  return GetSpellInfo and GetSpellInfo(name) ~= nil
end
local function exorcismAlert()
  if exo then exo:Hide() end
  local S = RG.SafeCall
  if not RG.Opt("exorcism") or not S(UnitExists, "target") or S(UnitIsDead, "target") or not S(UnitCanAttack, "player", "target") then return end
  -- creature type can be hidden from addons: then there's simply no alert
  local ctype = S(UnitCreatureType, "target")
  if ctype ~= "Undead" and ctype ~= "Demon" then return end
  if not knows("Exorcism") then return end
  if not exo then
    exo = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    exo:SetSize(250, 40); exo:SetPoint("CENTER", 0, -170); exo:SetFrameStrata("HIGH")
    RG.Backdrop(exo, { 0.04, 0.035, 0.03, 0.85 }, { GOLDC[1], GOLDC[2], GOLDC[3], 0.7 })
    local ic = exo:CreateTexture(nil, "OVERLAY"); ic:SetSize(28, 28); ic:SetPoint("LEFT", 6, 0); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo("Exorcism")
    ic:SetTexture(info and info.iconID or "Interface\\Icons\\Spell_Holy_Excorcism_02")
    exo.text = exo:CreateFontString(nil, "OVERLAY"); exo.text:SetFont("Fonts\\FRIZQT__.TTF", 12, ""); exo.text:SetPoint("LEFT", ic, "RIGHT", 8, 0); exo.text:SetJustifyH("LEFT")
    exo:EnableMouse(false)
  end
  exo.text:SetText(GOLD .. ctype .. "!|r  Use " .. GOLD .. "Exorcism|r" .. (knows("Holy Wrath") and " and Holy Wrath" or ""))
  exo:SetAlpha(1); exo:Show()
  local t = 0
  exo:SetScript("OnUpdate", function(self, dt) t = t + dt; if t > 4 then self:SetAlpha(math.max(0, 1 - (t - 4))); if t > 5 then self:Hide(); self:SetScript("OnUpdate", nil) end end end)
end

-- ===========================================================================
-- 3. Weapon stone reminder
-- ===========================================================================
-- Sword and axe = sharp, mace = blunt. Weapon subclass IDs: 0/1 axe, 7/8 sword, 4/5 mace.
local function weaponKind()
  local link = GetInventoryItemLink("player", 16)
  if not link then return nil end
  local _, _, _, _, _, classID, subID = itemInfoInstant(link)
  if classID ~= 2 then return nil end
  if subID == 0 or subID == 1 or subID == 7 or subID == 8 then return "sharp" end
  if subID == 4 or subID == 5 then return "blunt" end
end
function RG.BestStone()
  -- casters and druids in forms don't swing their weapon
  if RG.WEAPON_MODEL == "caster" or RG.WEAPON_MODEL == "feral" then return nil end
  local kind = weaponKind()
  if not kind then return nil end
  local lvl, bs = UnitLevel("player"), RG.Skill("Blacksmithing") or 0
  local best, bestUsable
  for _, s in ipairs(RG.STONES[kind]) do
    if s.lvl <= lvl then
      bestUsable = s
      if count(s.id) > 0 then best = s end
    end
  end
  return best or bestUsable, kind, best ~= nil
end
local function stoneReminder()
  if not RG.Opt("stoneReminder") or InCombatLockdown() then return nil end
  local has = GetWeaponEnchantInfo and GetWeaponEnchantInfo()
  if has then return nil end
  local s, kind, inBags = RG.BestStone()
  if not s then return nil end
  local bs = RG.Skill("Blacksmithing") or 0
  local how = inBags and ("you have " .. count(s.id)) or (bs >= s.bs and "you can make it" or "buy one on the Auction House")
  return GOLD .. "Use a " .. s.name .. "|r" .. GREY .. "  (+" .. s.dmg .. " damage, " .. how .. ")|r"
end

-- ===========================================================================
-- 4. XP per hour, time to level, session summary
-- ===========================================================================
local session = { start = time(), xp = 0, gold = nil, quests = 0, ore = 0, samples = {} }
local lastXP, lastMax, lastLevel
local oreIDs = {}
for _, p in ipairs(RG.SMELT) do oreIDs[p.ore] = true end
oreIDs[2775] = true; oreIDs[2776] = true; oreIDs[7911] = true -- Silver, Gold, Truesilver ore
local oreCounts = {}
local function oreSnapshot() local t = {}; for id in pairs(oreIDs) do t[id] = count(id) end; return t end

local function onXP()
  local xp, max, lvl = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
  if lastXP then
    local gained = (lvl > lastLevel) and ((lastMax - lastXP) + xp) or (xp - lastXP)
    if gained > 0 then
      session.xp = session.xp + gained
      table.insert(session.samples, { t = GetTime(), xp = gained })
    end
  end
  lastXP, lastMax, lastLevel = xp, max, lvl
end
-- XP per hour over the last 20 minutes of play (or the whole session if shorter).
function RG.XPRate()
  local now, total, oldest = GetTime(), 0, nil
  for i = #session.samples, 1, -1 do
    local s = session.samples[i]
    if now - s.t > 1200 then break end
    total = total + s.xp; oldest = s.t
  end
  if not oldest or now - oldest < 60 then return nil end
  local rate = total / (now - oldest) * 3600
  local need = UnitXPMax("player") - UnitXP("player")
  return rate, rate > 0 and need / rate * 3600 or nil
end
function RG.SessionSummary()
  local mins = math.max(1, math.floor((time() - session.start) / 60))
  local gold = GetMoney() - (session.gold or GetMoney())
  RG.Print(string.format("This session (%d min): %s XP, %s quests, %s ore mined, %s%s|r gold.",
    mins, BreakUpLargeNumbers and BreakUpLargeNumbers(session.xp) or session.xp, session.quests, session.ore, gold >= 0 and GREEN or RED, (gold >= 0 and "+" or "-") .. RG.Money(math.abs(gold))))
  local rate, eta = RG.XPRate()
  if rate then RG.Print(string.format("Leveling at %.1fk XP per hour; about %d minutes to level %d.", rate / 1000, math.floor((eta or 0) / 60), UnitLevel("player") + 1)) end
end
function RG.FormatETA(sec)
  if not sec then return nil end
  local m = math.floor(sec / 60)
  if m < 60 then return m .. " min" end
  return string.format("%dh %02dm", math.floor(m / 60), m % 60)
end

-- ===========================================================================
-- 5. Ret scores on the character screen
-- ===========================================================================
local SLOT_FRAMES = {
  [1] = "CharacterHeadSlot", [2] = "CharacterNeckSlot", [3] = "CharacterShoulderSlot", [15] = "CharacterBackSlot",
  [5] = "CharacterChestSlot", [9] = "CharacterWristSlot", [10] = "CharacterHandsSlot", [6] = "CharacterWaistSlot",
  [7] = "CharacterLegsSlot", [8] = "CharacterFeetSlot", [11] = "CharacterFinger0Slot", [12] = "CharacterFinger1Slot",
  [13] = "CharacterTrinket0Slot", [14] = "CharacterTrinket1Slot", [16] = "CharacterMainHandSlot", [17] = "CharacterSecondaryHandSlot",
}
local dollTexts, dollTotal = {}, nil
local function updatePaperdoll()
  local show = RG.Opt("paperdoll")
  local scores, worst, total = {}, nil, 0
  for slot in pairs(SLOT_FRAMES) do
    local link = GetInventoryItemLink("player", slot)
    scores[slot] = link and RG.Score(link) or nil
    if scores[slot] then total = total + scores[slot] end
  end
  -- weakest slot: an empty slot first, otherwise the lowest score (off hand, trinkets left out)
  for slot in pairs(SLOT_FRAMES) do
    if slot ~= 17 and slot ~= 13 and slot ~= 14 then
      local sc = scores[slot] or -1
      if worst == nil or sc < (scores[worst] or -1) then worst = slot end
    end
  end
  for slot, name in pairs(SLOT_FRAMES) do
    local btn = _G[name]
    if btn then
      local t = dollTexts[slot]
      if not t then t = btn:CreateFontString(nil, "OVERLAY"); t:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE"); t:SetPoint("BOTTOMRIGHT", -2, 2); dollTexts[slot] = t end
      local sc = scores[slot]
      if show and sc then t:SetText((slot == worst and RED or GOLD) .. string.format("%.0f", sc) .. "|r"); t:Show() else t:Hide() end
    end
  end
  if CharacterFrame and show then
    if not dollTotal then dollTotal = CharacterFrame:CreateFontString(nil, "OVERLAY"); dollTotal:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE"); dollTotal:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -34, -32) end
    dollTotal:SetText(GOLD .. RG.SCORE_NAME .. " " .. string.format("%.0f", total) .. "|r" .. (worst and (GREY .. "  ·  weakest: " .. (RG.SLOT_NAMES[worst] or "") .. "|r") or ""))
    dollTotal:Show()
  elseif dollTotal then dollTotal:Hide() end
end

-- ===========================================================================
-- 6. Talent planner
-- ===========================================================================
-- Talent APIs differ between clients, so each way of reading talents is tried
-- in turn; RG.talentSource remembers which one worked (shown by /wp talents check).
local function try(fn, ...)
  if not fn then return nil end
  local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
  if ok then return a, b, c, d, e, f, g, h end
end
-- Classic-style trees: GetTalentInfo(tab, i) -> name, icon, tier, column, rank, maxRank, ..., available
function RG.ReadTalents()
  local tabs = try(GetNumTalentTabs)
  if not (tabs and tabs > 0 and GetNumTalents and GetTalentInfo) then return nil end
  local out, found, spent = {}, false, 0
  for tab = 1, tabs do
    for i = 1, (try(GetNumTalents, tab) or 0) do
      local name, _, tier, _, rank, maxRank, _, available = try(GetTalentInfo, tab, i)
      if type(name) == "string" then
        out[name] = { rank = rank or 0, max = maxRank or 1, available = available ~= false, tier = tier, tab = tab }
        spent = spent + (tonumber(rank) or 0); found = true
      end
    end
  end
  return found and out or nil, spent
end
-- Modern talent trees (C_ClassTalents / C_Traits): unspent points from the tree's currency.
local function traitUnspent()
  if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeCurrencyInfo) then return nil end
  local cfg = try(C_ClassTalents.GetActiveConfigID)
  local info = cfg and try(C_Traits.GetConfigInfo, cfg)
  if not (info and info.treeIDs) then return nil end
  local total
  for _, tree in ipairs(info.treeIDs) do
    for _, cur in ipairs(try(C_Traits.GetTreeCurrencyInfo, cfg, tree, false) or {}) do
      if type(cur.quantity) == "number" then total = (total or 0) + cur.quantity end
    end
  end
  return total
end
function RG.UnspentTalents()
  local p = try(UnitCharacterPoints, "player")
  if RG.IsSecret and RG.IsSecret(p) then p = nil end
  if type(p) == "number" then RG.talentSource = "UnitCharacterPoints"; return p end
  p = try(GetUnspentTalentPoints)
  if type(p) == "number" then RG.talentSource = "GetUnspentTalentPoints"; return p end
  p = traitUnspent()
  if type(p) == "number" then RG.talentSource = "C_Traits"; return p end
  -- count it ourselves: one point per level from 10, minus what's spent in the tree
  local tree, spent = RG.ReadTalents()
  if tree then
    RG.talentSource = "counted from your talent tree"
    return math.max(0, math.max(0, (UnitLevel("player") or 1) - 9) - (spent or 0))
  end
  if C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints then
    local has = try(C_ClassTalents.HasUnspentTalentPoints)
    if has ~= nil then RG.talentSource = "HasUnspentTalentPoints"; return has and 1 or 0 end
  end
  RG.talentSource = nil
  return nil
end
-- What this client offers, for bug reports: /wp talents check
function RG.TalentCheck()
  local function has(x) return x and "yes" or "no" end
  RG.Print("Talent check (please send this if talents look wrong):")
  local p = try(UnitCharacterPoints, "player")
  DEFAULT_CHAT_FRAME:AddMessage("   UnitCharacterPoints: " .. has(UnitCharacterPoints) .. " -> " .. tostring(p))
  DEFAULT_CHAT_FRAME:AddMessage("   GetUnspentTalentPoints: " .. has(GetUnspentTalentPoints) .. " -> " .. tostring(try(GetUnspentTalentPoints)))
  DEFAULT_CHAT_FRAME:AddMessage("   GetNumTalentTabs: " .. has(GetNumTalentTabs) .. " -> " .. tostring(try(GetNumTalentTabs)) .. "   GetTalentInfo: " .. has(GetTalentInfo))
  local tree, spent = RG.ReadTalents()
  local n = 0; for _ in pairs(tree or {}) do n = n + 1 end
  DEFAULT_CHAT_FRAME:AddMessage("   tree read: " .. n .. " talents, " .. tostring(spent) .. " points spent")
  DEFAULT_CHAT_FRAME:AddMessage("   C_ClassTalents: " .. has(C_ClassTalents) .. "   C_Traits: " .. has(C_Traits) .. " -> " .. tostring(traitUnspent()))
  local u = RG.UnspentTalents()
  DEFAULT_CHAT_FRAME:AddMessage("   result: " .. tostring(u) .. " unspent (" .. (RG.talentSource or "no method worked") .. ")")
end
function RG.NextTalent()
  local tree = RG.ReadTalents()
  if not tree then return RG.TALENT_PRIORITY[1], nil end
  for _, t in ipairs(RG.TALENT_PRIORITY) do
    local info = tree[t.name]
    if info and info.rank < info.max and info.available then return t, info end
  end
  return nil
end
local function talentReminder()
  if not RG.Opt("talentReminder") then return nil end
  local pts = RG.UnspentTalents()
  if not pts or pts <= 0 then return nil end
  local t = RG.NextTalent()
  return GOLD .. "Spend " .. pts .. " talent point" .. (pts > 1 and "s" or "") .. "|r" .. (t and (GREY .. "  (next: " .. t.name .. ")|r") or "")
end

-- Add our reminders to the tracker's list.
local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  local s = stoneReminder(); if s then out[#out + 1] = { s } end
  local t = talentReminder(); if t then out[#out + 1] = { t, function() if RG.ShowTab then RG.ShowTab("talents") end end } end
  return out
end

-- ===========================================================================
-- Events
-- ===========================================================================
local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_COMPLETE", "QUEST_DETAIL", "QUEST_FINISHED", "PLAYER_TARGET_CHANGED", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
  "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event, a1)
  if RG.IsAlt and RG.IsAlt() then return end
  if event == "PLAYER_LOGIN" then
    session.gold = GetMoney(); onXP(); oreCounts = oreSnapshot()
    if CharacterFrame then CharacterFrame:HookScript("OnShow", updatePaperdoll) end
  elseif event == "QUEST_COMPLETE" or event == "QUEST_DETAIL" then
    C_Timer.After(0.1, pickReward)
  elseif event == "QUEST_FINISHED" then
    clearMarks()
  elseif event == "PLAYER_TARGET_CHANGED" then
    exorcismAlert()
  elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
    onXP()
  elseif event == "QUEST_TURNED_IN" then
    session.quests = session.quests + 1
  elseif event == "BAG_UPDATE_DELAYED" then
    local now = oreSnapshot()
    for id, n in pairs(now) do local d = n - (oreCounts[id] or 0); if d > 0 and not (MerchantFrame and MerchantFrame:IsShown()) and not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then session.ore = session.ore + d end end
    oreCounts = now
  end
  if (event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED") and CharacterFrame and CharacterFrame:IsShown() then updatePaperdoll() end
  if (event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "PLAYER_LEVEL_UP") and RG.RefreshUI then RG.RefreshUI() end
  if RG.QueueTracker then RG.QueueTracker() end
end)

-- /wp session
local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  if cmd and cmd:lower() == "session" then RG.SessionSummary(); return end
  if cmd and cmd:lower() == "talents" then
    if (msg or ""):lower():find("check") then RG.TalentCheck() elseif RG.ShowTab then RG.ShowTab("talents") end
    return
  end
  return base(msg)
end
-- Logging out prints a short summary next time you look at chat.
local lo = CreateFrame("Frame"); lo:RegisterEvent("PLAYER_LOGOUT")
lo:SetScript("OnEvent", function() if RG.IsAlt and RG.IsAlt() then return end; WaypathDB.lastSession = { xp = session.xp, quests = session.quests, ore = session.ore, t = time() - session.start } end)
