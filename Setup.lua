-- Waypath+ setup wizard: six short pages on first launch that set Waypath+ up the
-- way you play. Rerun any time with /wp setup or the button in Settings.
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
  full = { label = "Full guidance", desc = "Everything on: route, arrow, auto quests, reminders and alerts. Best while you learn the game.", off = {} },
  balanced = { label = "Balanced", desc = "All the help, less chatter: no fight reports in chat, no quest-mob pings, fewer pop-ups.",
    off = { "nameplateAlert", "levelBanner", "wellFed" } },
  minimal = { label = "Minimal", desc = "Tracker, tooltips and vendor safety only. You drive; Waypath+ stays quiet.",
    on = { "tracker", "tooltip", "upgradeToast", "sellJunk", "autoRepair", "profitWatch", "autoScan", "minimap", "arrow", "bagReminder", "rewardPicker", "healSet" } },
}
function RG.ApplyPreset(name)
  local p = RG.PRESETS[name]
  if not p then return end
  for _, k in ipairs(allKeys()) do
    if p.on then RG.db[k] = false else RG.db[k] = nil end
  end
  for _, k in ipairs(p.on or {}) do RG.db[k] = true end
  for _, k in ipairs(p.off or {}) do RG.db[k] = false end
  RG.db.preset = name
end

-- Professions you plan to level switch their reminders and plans on or off.
local PROF_KEYS = {
  Mining = { "mineReminder", "oreAlert" },
  Herbalism = { "herbAlert" },
  Cooking = { "campReminder", "wellFed" },
}
local function applyPlan(plan)
  RG.db.plan = plan
  for prof, keys in pairs(PROF_KEYS) do
    if not RG.Plans(prof) then for _, k in ipairs(keys) do RG.db[k] = false end end
  end
end
-- Does this character level the profession? Yes if it knows it, or if setup says so.
-- (Plans saved before every profession was in the guide only had these four, on by default.)
local LEGACY = { Mining = true, Blacksmithing = true, Fishing = true, Cooking = true }
function RG.Plans(prof)
  if RG.db and RG.db.profIgnore and RG.db.profIgnore[prof] then return false end
  if RG.Skill and RG.Skill(prof) then return true end
  local plan = RG.db and RG.db.plan
  if plan and plan[prof] ~= nil then return plan[prof] and true or false end
  return LEGACY[prof] and (plan ~= nil or RG.IsClass("PALADIN")) or false
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
  local p1 = newPage("Welcome, " .. (UnitName("player") or "adventurer") .. "!")
  local crest = p1:CreateTexture(nil, "ARTWORK"); crest:SetSize(44, 44); crest:SetPoint("TOPLEFT", 4, -42); crest:SetTexture(RG.LOGO_LARGE)
  local ring = p1:CreateTexture(nil, "OVERLAY"); ring:SetSize(74, 74); ring:SetPoint("CENTER", crest, "CENTER"); ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  local intro = text(p1, "GameFontHighlight", GOLD .. "Waypath+|r walks you from level 1 to 60: the route and quests, the arrow, gear upgrades, professions, camping and gold.\n\nThis takes about a minute. Every choice can be changed later in Settings, or by running " .. GOLD .. "/wp setup|r again.", W - 140)
  intro:SetPoint("TOPLEFT", crest, "TOPRIGHT", 22, 2); intro:SetSpacing(3)
  local tips = text(p1, "GameFontHighlight", GOLD .. "•|r The " .. GOLD .. "tracker|r on the right shows what to do next.\n" .. GOLD .. "•|r " .. GOLD .. "/wp|r or the minimap button opens the full guide.\n" .. GOLD .. "•|r Hold " .. GOLD .. "Shift|r at a quest giver to stop Waypath+ accepting for you.", W - 70)
  tips:SetPoint("TOPLEFT", 0, -130); tips:SetSpacing(6)

  -- 2. Character and professions
  local p2 = newPage("Your character")
  local mainText = text(p2, "GameFontHighlight", "", W - 70); mainText:SetPoint("TOPLEFT", 0, -38)
  local mainBtn = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate"); mainBtn:SetSize(170, 22); mainBtn:SetPoint("TOPLEFT", 0, -78); mainBtn:SetText("Make this my main")
  mainBtn:SetScript("OnClick", function() RG.db.main = RG.PlayerKey(); p2.refreshers[1]() end)
  table.insert(p2.refreshers, function()
    local isMain = RG.db.main == RG.PlayerKey()
    mainText:SetText((isMain and (GREEN .. UnitName("player") .. " is your main|r (the character your bank alts buy for).") or (GOLD .. "This character has its own profile.|r Make it your main if your bank alts should buy for it."))
      .. GREY .. " Every character has its own settings and progress.|r")
    mainBtn:SetShown(not isMain)
  end)
  local seen = text(p2, "GameFontNormal", "", W - 70); seen:SetPoint("TOPLEFT", 0, -106)
  table.insert(p2.refreshers, function()
    local d = RG.Detect()
    seen:SetText(GREY .. "Detected:|r " .. GOLD .. d.faction .. "|r " .. RG.DetectLine())
  end)
  local profHead = text(p2, "GameFontNormal", "Professions  " .. GREY .. "ticked = guided. Ones you learn later are added automatically.|r", W - 70); profHead:SetPoint("TOPLEFT", 0, -132)
  for i, pr in ipairs(RG.PROFESSION_LIST) do
    local c = check(p2, pr, nil, function() if plan[pr] ~= nil then return plan[pr] end return RG.Plans(pr) end, function(v) plan[pr] = v; RG.IgnoreProfession(pr, not v and RG.Skill(pr) ~= nil) end)
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    c:SetPoint("TOPLEFT", col * (W / 2 - 30), -154 - row * 26)
    table.insert(p2.refreshers, function()
      local r = RG.Skill(pr)
      c.label:SetText(pr .. (r and (GREEN .. "  learned, " .. r .. "|r") or ""))
      c.refresh()
    end)
  end

  -- 3. How you play
  local pp = newPage("How do you play?")
  local sy = -40
  local function segment(question, key, opts, default)
    local q = text(pp, "GameFontNormal", question, W - 70); q:SetPoint("TOPLEFT", 0, sy)
    local bs, x = {}, 0
    local function pickIt(v) RG.db[key] = v; for k, b in pairs(bs) do if k == v then b:LockHighlight() else b:UnlockHighlight() end end end
    for _, o in ipairs(opts) do
      local b = CreateFrame("Button", nil, pp, "UIPanelButtonTemplate")
      b:SetSize(math.max(96, #o[2] * 7 + 20), 22); b:SetPoint("TOPLEFT", x, sy - 20); b:SetText(o[2])
      b:SetScript("OnClick", function() pickIt(o[1]) end)
      bs[o[1]] = b; x = x + b:GetWidth() + 6
    end
    table.insert(pp.refreshers, function() pickIt(RG.db[key] or default) end)
    sy = sy - 62
  end
  segment("What matters most?", "goal", { { "fast", "Level fast" }, { "balanced", "Balanced" }, { "scenic", "Enjoy the zones" } }, "balanced")
  segment("Solo or with others?", "playStyle", { { "solo", "Solo only" }, { "group", "Open to dungeons and groups" } }, "solo")
  segment("Travel", "travel", { { "any", "Use boats, zeppelins and hearth" }, { "walk", "Keep travel short" } }, "any")
  segment("Your role", "role", { { "dps", "Damage" }, { "tank", "Tank" }, { "heal", "Healer" } }, "dps")
  local why = text(pp, "GameFontHighlightSmall", GREY .. "Waypath+ uses these to choose routes, gear and dungeon steps. Change them any time with /wp setup.|r", W - 70)
  why:SetPoint("TOPLEFT", 0, sy)

  -- 4. Preset
  local p3 = newPage("How much help do you want?")
  local btns = {}
  local function pick(name) RG.db.preset = name; for k, b in pairs(btns) do b.select(k == name) end end
  local y = -38
  for _, name in ipairs({ "full", "balanced", "minimal" }) do
    local pr = RG.PRESETS[name]
    local b = choice(p3, pr.label, pr.desc, function() pick(name) end)
    b:SetPoint("TOPLEFT", 0, y); y = y - 76
    btns[name] = b
  end
  local note = text(p3, "GameFontHighlightSmall", GREY .. "You'll fine-tune the big switches on the next page.|r", W - 70); note:SetPoint("TOPLEFT", 0, y - 4)
  table.insert(p3.refreshers, function() pick(RG.db.preset or "full") end)

  -- 4. Automation (preset applied on entering this page)
  local p4 = newPage("Automation")
  local auto = {
    { "autoQuest", "Accept and turn in quests for me", "Hold Shift at a quest giver to pause. Skips grey quests and quests that cost gold." },
    { "autoReward", "Pick the quest reward when the choice is clear", "Your upgrade first, then best vendor value. Asks when an upgrade for you and one for your 2nd spec compete." },
    { "autoArrow", "Arrow follows my next route step", "Never moves a pin you placed yourself." },
    { "sellJunk", "Sell grey junk and repair at vendors", "Anything worth more on the AH is kept, and you get a buy-back button if you sell it by mistake." },
    { "targetBar", "Quest bar and WaypathTarget macro", "Click to target the quest mobs you still need and use quest items." },
  }
  for i, a in ipairs(auto) do
    local c = check(p4, a[2], a[3], function() return RG.Opt(a[1]) end, function(v) RG.db[a[1]] = v; if a[1] == "sellJunk" then RG.db.autoRepair = v end end)
    c:SetPoint("TOPLEFT", 0, -36 - (i - 1) * 46)
    table.insert(p4.refreshers, c.refresh)
  end

  -- 5. Extras
  local p5 = newPage("Extras")
  local extras = {
    { "healSet", "Collect gear for a 2nd spec", "Pick the spec below (or later on the 2nd Spec tab). Dual spec unlocks at 40; Waypath+ tracks your best pieces for it and never sells them." },
    { "profitWatch", "Protect items worth more on the AH", "Gold coin on the bag slot, kept out of junk sales, warning at vendors." },
    { "newQuests", "Show new quests near me", "Turn this off if you also run Questie, so you don't see them twice." },
    { "groupDuties", "Group helper", "In a party: who needs a Blessing, Aura reminder, dispel and \"dying\" alerts, shared quests and LFG posts." },
  }
  for i, a in ipairs(extras) do
    local c = check(p5, a[2], a[3], function() return RG.Opt(a[1]) end, function(v) RG.db[a[1]] = v; if a[1] == "groupDuties" then RG.db.groupAlerts = v end end)
    c:SetPoint("TOPLEFT", 0, -36 - (i - 1) * 46)
    table.insert(p5.refreshers, c.refresh)
  end
  local alt = text(p5, "GameFontHighlightSmall", GOLD .. "Bank alt?|r Just log in on it: Waypath+ notices it isn't your main and shows a shopping list of quest items to buy and mail, with a one-click button at the mailbox.", W - 70)
  alt:SetPoint("TOPLEFT", 0, -36 - #extras * 46 - 6); alt:SetSpacing(2)
  -- 2nd spec: one button per spec of your class
  local specLabel = text(p5, "GameFontNormal", GOLD .. "2nd spec:|r", 80)
  specLabel:SetPoint("TOPLEFT", 0, -36 - #extras * 46 - 52)
  local specBtns, x = {}, 80
  for _, sp in ipairs(RG.SpecList and RG.SpecList() or {}) do
    if not sp.main then
      local b = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
      b:SetSize(math.max(84, (#sp.name * 7) + 20), 22); b:SetPoint("TOPLEFT", x, -36 - #extras * 46 - 48); b:SetText(sp.name)
      b:SetScript("OnClick", function() RG.SetSecondSpec(sp.key); RG.db.healSet = true; for _, r in ipairs(p5.refreshers) do r() end end)
      b.key = sp.key
      specBtns[#specBtns + 1] = b; x = x + b:GetWidth() + 6
    end
  end
  table.insert(p5.refreshers, function()
    local cur = RG.SecondSpec and RG.SecondSpec()
    for _, b in ipairs(specBtns) do if cur and cur.key == b.key then b:LockHighlight() else b:UnlockHighlight() end end
  end)

  -- 6. Done
  local p6 = newPage("You're all set")
  local summary = text(p6, "GameFontHighlight", "", W - 70); summary:SetPoint("TOPLEFT", 0, -38); summary:SetSpacing(4)
  table.insert(p6.refreshers, function()
    local pr = RG.PRESETS[RG.db.preset or "full"]
    local lv = {}
    for _, n in ipairs({ "Mining", "Herbalism", "Skinning", "Blacksmithing", "Engineering", "Alchemy", "Leatherworking", "Tailoring", "Enchanting", "Cooking", "Fishing", "First Aid" }) do if RG.Plans(n) then lv[#lv + 1] = n end end
    summary:SetText(GOLD .. "You:|r " .. RG.DetectLine() .. ", " .. (RG.db.goal or "balanced") .. ", " .. (RG.db.playStyle or "solo") .. "\n" .. GOLD .. "Help level:|r " .. pr.label .. "\n" .. GOLD .. "Professions:|r " .. (#lv > 0 and table.concat(lv, ", ") or "none") .. "\n"
      .. GOLD .. "Auto quests:|r " .. (RG.Opt("autoQuest") and "on (hold Shift to pause)" or "off") .. "\n" .. GOLD .. "2nd spec:|r " .. ((RG.SecondSpecActive and RG.SecondSpecActive()) and (RG.SecondSpecActive().name .. (RG.Opt("healSet") and ", collecting its gear" or "")) or "none yet (/wp spec)") .. "\n\n"
      .. GOLD .. "Worth remembering|r\n"
      .. GOLD .. "/wp|r  the full guide        " .. GOLD .. "/wp next|r  pin your nearest objective\n"
      .. GOLD .. "/wp group|r  group play         " .. GOLD .. "/wp camp|r  camp, fishing, cooking\n"
      .. GOLD .. "/wp setup|r  run this again    " .. GOLD .. "/wp fish|r  fishing\n"
      .. GOLD .. "Right-click|r a route step to pin it")
  end)
end

-- ---------------------------------------------------------------------------
-- Frame and navigation
-- ---------------------------------------------------------------------------
local function show(i)
  -- leaving a page: apply what it set
  if page == 2 and i > 2 then applyPlan(plan) end
  if page == 4 and i == 5 then RG.ApplyPreset(RG.db.preset or "full"); applyPlan(plan) end
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
  if page < 4 then applyPlan(plan) end
  RG.db.welcomed = true; RG.db.setupDone = true
  wiz:Hide()
  if RG.RefreshTracker then RG.RefreshTracker() end
  if RG.MinimapButton then RG.MinimapButton() end
  if open and RG.ToggleUI then RG.ToggleUI() end
  RG.Print("Setup saved. /wp setup runs it again; Settings has every switch.")
end

function RG.ShowSetup()
  if RG.IsAlt and RG.IsAlt() then RG.Print("This character is a bank alt. /wp char profile gives it its own full profile.") return end
  if not wiz then
    wiz = CreateFrame("Frame", "WaypathSetup", UIParent, "BackdropTemplate")
    wiz:SetSize(W, H); wiz:SetPoint("CENTER", 0, 40); wiz:SetFrameStrata("DIALOG")
    wiz:SetMovable(true); wiz:EnableMouse(true); wiz:RegisterForDrag("LeftButton")
    wiz:SetScript("OnDragStart", wiz.StartMoving); wiz:SetScript("OnDragStop", wiz.StopMovingOrSizing)
    tinsert(UISpecialFrames, "WaypathSetup")
    RG.DialogBackdrop(wiz)
    RG.DialogHeader(wiz, "Waypath+ Setup", 300)
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
  for k, v in pairs(RG.db.plan or {}) do plan[k] = v end
  wiz:Show(); show(1)
  if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_QUEST_LOG_OPEN or 844) end
end
-- First launch shows the wizard instead of the old welcome card.
RG.ShowWelcome = RG.ShowSetup

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  if cmd and (cmd:lower() == "setup" or cmd:lower() == "wizard") then RG.ShowSetup() return end
  return base(msg)
end
