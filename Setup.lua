-- RetGear setup wizard: six short pages on first launch that set RetGear up the
-- way you play. Rerun any time with /rg setup or the button in Settings.
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY

local W, H = 540, 460
local wiz

-- ---------------------------------------------------------------------------
-- Presets: which helpers are on. Anything not listed keeps its default.
-- ---------------------------------------------------------------------------
local ALL_KEYS = {}
local function allKeys() if #ALL_KEYS == 0 then for _, o in ipairs(RG.OPTIONS) do ALL_KEYS[#ALL_KEYS + 1] = o.key end end return ALL_KEYS end
RG.PRESETS = {
  full = { label = "Full guidance", desc = "Everything on: route, arrow, auto quests, coach reports, reminders and alerts. Best while you learn the game.", off = {} },
  balanced = { label = "Balanced", desc = "All the help, less chatter: no fight reports in chat, no quest-mob pings, fewer pop-ups.",
    off = { "coachChat", "nameplateAlert", "levelBanner", "wellFed" } },
  minimal = { label = "Minimal", desc = "Tracker, tooltips and vendor safety only. You drive; RetGear stays quiet.",
    on = { "tracker", "tooltip", "upgradeToast", "sellJunk", "autoRepair", "profitWatch", "autoScan", "minimap", "arrow", "bagReminder", "rewardPicker", "healSet" } },
}
function RG.ApplyPreset(name)
  local p = RG.PRESETS[name]
  if not p then return end
  for _, k in ipairs(allKeys()) do
    if p.on then RetGearDB[k] = false else RetGearDB[k] = nil end
  end
  for _, k in ipairs(p.on or {}) do RetGearDB[k] = true end
  for _, k in ipairs(p.off or {}) do RetGearDB[k] = false end
  RetGearDB.preset = name
end

-- Professions you plan to level switch their reminders and plans on or off.
local PROF_KEYS = {
  Mining = { "mineReminder" },
  Cooking = { "campReminder", "wellFed" },
}
local function applyPlan(plan)
  RetGearDB.plan = plan
  for prof, keys in pairs(PROF_KEYS) do
    if not plan[prof] then for _, k in ipairs(keys) do RetGearDB[k] = false end end
  end
end
function RG.Plans(prof)
  local plan = RetGearDB and RetGearDB.plan
  return not plan or plan[prof] ~= false
end

-- ---------------------------------------------------------------------------
-- Widgets
-- ---------------------------------------------------------------------------
local function text(parent, tpl, str, w)
  local fs = parent:CreateFontString(nil, "OVERLAY", tpl or "GameFontHighlight")
  fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP")
  if w then fs:SetWidth(w) end
  fs:SetText(str or "")
  return fs
end
local function check(parent, label, sub, getter, setter)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(26, 26)
  c.label = text(c, "GameFontNormal", label); c.label:SetPoint("LEFT", c, "RIGHT", 4, sub and 6 or 1)
  if sub then c.sub = text(c, "GameFontHighlightSmall", sub, W - 120); c.sub:SetPoint("TOPLEFT", c.label, "BOTTOMLEFT", 0, -2); c.sub:SetTextColor(0.75, 0.75, 0.75) end
  c.refresh = function() c:SetChecked(getter()) end
  c:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false); if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) end end)
  return c
end
local function choice(parent, label, desc, onPick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(W - 70, 68)
  RG.Backdrop(b, { 0.07, 0.065, 0.06, 0.9 }, { 0.55, 0.5, 0.42, 0.85 })
  b.title = text(b, "GameFontNormal", label); b.title:SetPoint("TOPLEFT", 14, -10)
  b.desc = text(b, "GameFontHighlightSmall", desc, W - 110); b.desc:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -4); b.desc:SetTextColor(0.8, 0.8, 0.8)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetPoint("TOPLEFT", 3, -3); b.hl:SetPoint("BOTTOMRIGHT", -3, 3)
  b.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); b.hl:SetBlendMode("ADD"); b.hl:SetAlpha(0.4)
  b.select = function(on)
    b:SetBackdropBorderColor(on and 1 or 0.55, on and 0.82 or 0.5, on and 0 or 0.42, 1)
    b:SetBackdropColor(on and 0.22 or 0.07, on and 0.18 or 0.065, on and 0.04 or 0.06, 0.92)
    b.title:SetFontObject(on and "GameFontHighlight" or "GameFontNormal")
  end
  b:SetScript("OnClick", function() onPick(); if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115) end end)
  return b
end

-- ---------------------------------------------------------------------------
-- Pages
-- ---------------------------------------------------------------------------
local pages, page = {}, 1
local plan = {}
local function newPage(title)
  local p = CreateFrame("Frame", nil, wiz)
  p:SetPoint("TOPLEFT", 26, -36); p:SetPoint("BOTTOMRIGHT", -26, 72)
  p.title = text(p, "GameFontNormalLarge", title); p.title:SetPoint("TOPLEFT", 0, 0)
  local line = p:CreateTexture(nil, "ARTWORK"); line:SetHeight(1); line:SetPoint("TOPLEFT", 0, -24); line:SetPoint("TOPRIGHT", 0, -24); line:SetColorTexture(1, 0.82, 0, 0.3)
  p.refreshers = {}
  pages[#pages + 1] = p
  p:Hide()
  return p
end

local function buildPages()
  -- 1. Welcome
  local p1 = newPage("Welcome, " .. (UnitName("player") or "Paladin") .. "!")
  local crest = p1:CreateTexture(nil, "ARTWORK"); crest:SetSize(44, 44); crest:SetPoint("TOPLEFT", 4, -42); crest:SetTexture("Interface\\Icons\\Spell_Holy_AuraOfLight")
  local ring = p1:CreateTexture(nil, "OVERLAY"); ring:SetSize(74, 74); ring:SetPoint("CENTER", crest, "CENTER"); ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  local intro = text(p1, "GameFontHighlight", GOLD .. "RetGear|r walks your Undead Retribution Paladin from level 1 to 60: the route and quests, gear upgrades, professions, camping, gold and your DPS.\n\nThis takes about a minute. Every choice can be changed later in Settings, or by running " .. GOLD .. "/rg setup|r again.", W - 140)
  intro:SetPoint("TOPLEFT", crest, "TOPRIGHT", 22, 2); intro:SetSpacing(3)
  local tips = text(p1, "GameFontHighlight", GOLD .. "•|r The " .. GOLD .. "tracker|r on the right shows what to do next.\n" .. GOLD .. "•|r " .. GOLD .. "/rg|r or the minimap button opens the full guide.\n" .. GOLD .. "•|r Hold " .. GOLD .. "Shift|r at a quest giver to stop RetGear accepting for you.", W - 70)
  tips:SetPoint("TOPLEFT", 0, -130); tips:SetSpacing(6)

  -- 2. Character and professions
  local p2 = newPage("Your character")
  local mainText = text(p2, "GameFontHighlight", "", W - 70); mainText:SetPoint("TOPLEFT", 0, -38)
  local mainBtn = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate"); mainBtn:SetSize(170, 22); mainBtn:SetPoint("TOPLEFT", 0, -78); mainBtn:SetText("Make this my main")
  mainBtn:SetScript("OnClick", function() RG.db.main = RG.PlayerKey(); p2.refreshers[1]() end)
  table.insert(p2.refreshers, function()
    local isMain = RG.db.main == RG.PlayerKey()
    mainText:SetText(isMain and (GREEN .. UnitName("player") .. " is your main.|r Your other characters run as bank alts and never change this character's progress.")
      or (GOLD .. "This character isn't your main yet.|r Make it your main if it's the paladin you're leveling."))
    mainBtn:SetShown(not isMain)
  end)
  local profHead = text(p2, "GameFontNormal", "Which professions will you level?"); profHead:SetPoint("TOPLEFT", 0, -116)
  local profs = { { "Mining", "Ore routes, Find Minerals reminder, smelt-or-sell" }, { "Blacksmithing", "Smithing upgrades, Sharpening Wheel for camp, weapon stones" },
    { "Fishing", "Fish Bowl for camp, fishing plan and fish worth selling" }, { "Cooking", "Campfires, Well Fed (+5% XP) reminders, cooking plan" } }
  for i, pr in ipairs(profs) do
    local c = check(p2, pr[1], pr[2], function() return plan[pr[1]] ~= false end, function(v) plan[pr[1]] = v end)
    c:SetPoint("TOPLEFT", 0, -138 - (i - 1) * 40)
    table.insert(p2.refreshers, c.refresh)
  end

  -- 3. Preset
  local p3 = newPage("How much help do you want?")
  local btns = {}
  local function pick(name) RetGearDB.preset = name; for k, b in pairs(btns) do b.select(k == name) end end
  local y = -38
  for _, name in ipairs({ "full", "balanced", "minimal" }) do
    local pr = RG.PRESETS[name]
    local b = choice(p3, pr.label, pr.desc, function() pick(name) end)
    b:SetPoint("TOPLEFT", 0, y); y = y - 76
    btns[name] = b
  end
  local note = text(p3, "GameFontHighlightSmall", GREY .. "You'll fine-tune the big switches on the next page.|r", W - 70); note:SetPoint("TOPLEFT", 0, y - 4)
  table.insert(p3.refreshers, function() pick(RetGearDB.preset or "full") end)

  -- 4. Automation (preset applied on entering this page)
  local p4 = newPage("Automation")
  local auto = {
    { "autoQuest", "Accept and turn in quests for me", "Hold Shift at a quest giver to pause. Skips grey quests and quests that cost gold." },
    { "autoReward", "Pick the quest reward when the choice is clear", "Ret upgrade first, then best vendor value. Asks you when a Ret and a healing upgrade compete." },
    { "autoArrow", "Arrow follows my next route step", "Never moves a pin you placed yourself." },
    { "sellJunk", "Sell grey junk and repair at vendors", "Anything worth more on the AH is kept, and you get a buy-back button if you sell it by mistake." },
    { "targetBar", "Quest bar and RetGearTarget macro", "Click to target the quest mobs you still need and use quest items." },
  }
  for i, a in ipairs(auto) do
    local c = check(p4, a[2], a[3], function() return RG.Opt(a[1]) end, function(v) RetGearDB[a[1]] = v; if a[1] == "sellJunk" then RetGearDB.autoRepair = v end end)
    c:SetPoint("TOPLEFT", 0, -36 - (i - 1) * 46)
    table.insert(p4.refreshers, c.refresh)
  end

  -- 5. Extras
  local p5 = newPage("Extras")
  local extras = {
    { "healSet", "Collect a healing set for dual spec", "Dual spec unlocks at 40. RetGear tracks your best healing gear and never sells it." },
    { "coach", "DPS coach", "Records fights and tells you the biggest thing to fix. Chat reports follow your preset." },
    { "profitWatch", "Protect items worth more on the AH", "Gold coin on the bag slot, kept out of junk sales, warning at vendors." },
    { "newQuests", "Show new quests near me", "Turn this off if you also run Questie, so you don't see them twice." },
  }
  for i, a in ipairs(extras) do
    local c = check(p5, a[2], a[3], function() return RG.Opt(a[1]) end, function(v) RetGearDB[a[1]] = v end)
    c:SetPoint("TOPLEFT", 0, -36 - (i - 1) * 46)
    table.insert(p5.refreshers, c.refresh)
  end
  local alt = text(p5, "GameFontHighlightSmall", GOLD .. "Bank alt?|r Just log in on it: RetGear notices it isn't your main and shows a shopping list of quest items to buy and mail, with a one-click button at the mailbox.", W - 70)
  alt:SetPoint("TOPLEFT", 0, -36 - #extras * 46 - 6); alt:SetSpacing(2)

  -- 6. Done
  local p6 = newPage("You're all set")
  local summary = text(p6, "GameFontHighlight", "", W - 70); summary:SetPoint("TOPLEFT", 0, -38); summary:SetSpacing(4)
  table.insert(p6.refreshers, function()
    local pr = RG.PRESETS[RetGearDB.preset or "full"]
    local lv = {}
    for _, n in ipairs({ "Mining", "Blacksmithing", "Fishing", "Cooking" }) do if plan[n] ~= false then lv[#lv + 1] = n end end
    summary:SetText(GOLD .. "Help level:|r " .. pr.label .. "\n" .. GOLD .. "Professions:|r " .. (#lv > 0 and table.concat(lv, ", ") or "none") .. "\n"
      .. GOLD .. "Auto quests:|r " .. (RG.Opt("autoQuest") and "on (hold Shift to pause)" or "off") .. "\n" .. GOLD .. "Healing set:|r " .. (RG.Opt("healSet") and "collecting" or "off") .. "\n\n"
      .. GOLD .. "Worth remembering|r\n"
      .. GOLD .. "/rg|r  the full guide        " .. GOLD .. "/rg next|r  pin your nearest objective\n"
      .. GOLD .. "/rg dps|r  last fight          " .. GOLD .. "/rg camp|r  camp, fishing, cooking\n"
      .. GOLD .. "/rg setup|r  run this again    " .. GOLD .. "Right-click|r a route step to pin it")
  end)
end

-- ---------------------------------------------------------------------------
-- Frame and navigation
-- ---------------------------------------------------------------------------
local function show(i)
  -- leaving a page: apply what it set
  if page == 2 and i > 2 then applyPlan(plan) end
  if page == 3 and i == 4 then RG.ApplyPreset(RetGearDB.preset or "full"); applyPlan(plan) end
  page = i
  for k, p in ipairs(pages) do
    p:SetShown(k == i)
    if k == i then for _, r in ipairs(p.refreshers) do r() end end
  end
  wiz.back:SetEnabled(i > 1)
  wiz.next:SetText(i == #pages and "Open the guide" or (i == 1 and "Let's go" or "Next"))
  wiz.skip:SetShown(i < #pages)
  for k, d in ipairs(wiz.dots) do d:SetVertexColor(k == i and 1 or 0.35, k == i and 0.82 or 0.35, k == i and 0 or 0.35, 1) end
end
local function finish(open)
  if page < 3 then applyPlan(plan) end
  RetGearDB.welcomed = true; RetGearDB.setupDone = true
  wiz:Hide()
  if RG.RefreshTracker then RG.RefreshTracker() end
  if RG.MinimapButton then RG.MinimapButton() end
  if open and RG.ToggleUI then RG.ToggleUI() end
  RG.Print("Setup saved. /rg setup runs it again; Settings has every switch.")
end

function RG.ShowSetup()
  if RG.IsAlt and RG.IsAlt() then RG.Print("This is a bank alt; run /rg setup on your main.") return end
  if not wiz then
    wiz = CreateFrame("Frame", "RetGearSetup", UIParent, "BackdropTemplate")
    wiz:SetSize(W, H); wiz:SetPoint("CENTER", 0, 40); wiz:SetFrameStrata("DIALOG")
    wiz:SetMovable(true); wiz:EnableMouse(true); wiz:RegisterForDrag("LeftButton")
    wiz:SetScript("OnDragStart", wiz.StartMoving); wiz:SetScript("OnDragStop", wiz.StopMovingOrSizing)
    tinsert(UISpecialFrames, "RetGearSetup")
    RG.DialogBackdrop(wiz)
    RG.DialogHeader(wiz, "RetGear Setup", 300)
    local close = CreateFrame("Button", nil, wiz, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() finish(false) end)
    wiz.back = CreateFrame("Button", nil, wiz, "UIPanelButtonTemplate"); wiz.back:SetSize(100, 24); wiz.back:SetPoint("BOTTOMLEFT", 22, 20); wiz.back:SetText("Back")
    wiz.next = CreateFrame("Button", nil, wiz, "UIPanelButtonTemplate"); wiz.next:SetSize(130, 24); wiz.next:SetPoint("BOTTOMRIGHT", -22, 20)
    wiz.skip = CreateFrame("Button", nil, wiz, "UIPanelButtonTemplate"); wiz.skip:SetSize(110, 24); wiz.skip:SetPoint("RIGHT", wiz.next, "LEFT", -8, 0); wiz.skip:SetText("Skip setup")
    wiz.back:SetScript("OnClick", function() if page > 1 then show(page - 1) end end)
    wiz.next:SetScript("OnClick", function() if page < #pages then show(page + 1) else finish(true) end end)
    wiz.skip:SetScript("OnClick", function() finish(false) end)
    buildPages()
    wiz.dots = {}
    for i = 1, #pages do
      local d = wiz:CreateTexture(nil, "OVERLAY"); d:SetSize(10, 10); d:SetTexture("Interface\\Buttons\\WHITE8X8")
      d:SetPoint("BOTTOM", wiz, "BOTTOM", (i - (#pages + 1) / 2) * 18, 54)
      wiz.dots[i] = d
    end
  end
  plan = {}
  for k, v in pairs(RetGearDB.plan or {}) do plan[k] = v end
  wiz:Show(); show(1)
  if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_QUEST_LOG_OPEN or 844) end
end
-- First launch shows the wizard instead of the old welcome card.
RG.ShowWelcome = RG.ShowSetup

local base = SlashCmdList.RETGEAR
SlashCmdList.RETGEAR = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  if cmd and (cmd:lower() == "setup" or cmd:lower() == "wizard") then RG.ShowSetup() return end
  return base(msg)
end
