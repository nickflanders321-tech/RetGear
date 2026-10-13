-- RetGear secret bank-alt guide: from a brand-new Undead alt to a working bank alt
-- at the Undercity Auction House in about ten minutes, with the arrow showing the way.
-- Shows on the tracker of any alt until it's done; on your main: /rg bankalt.
-- Coordinates: QuestieDB WoW Forever NPC data (auctioneers, bankers, innkeeper, bag vendor).
local _, RG = ...
local GOLD, GREEN, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.GREY

RG.ALT_INTRO = "Make a new character on the same realm: Horde, Undead. Undead start a few minutes' run from Undercity, the Horde capital with an Auction House, bank and mailboxes all in one ring. It doesn't need to level: a level 1 character can use the Auction House, bank and mail."

RG.ALT_STEPS = {
  { key = "brill", title = "Run to Brill", text = "Skip the Deathknell quests. Leave the graveyard by the road and run east to Brill without stopping to fight.", wp = { 1420, 61.7, 52.0, "Brill" } },
  { key = "uc",    title = "Into Undercity", text = "Keep following the road south-east to the Ruins of Lordaeron. Go through the throne room and ride an elevator down.", wp = { 1458, 56.0, 37.5, "Undercity" } },
  { key = "ah",    title = "Auction House", text = "The auctioneers stand in the Trade Quarter, the middle ring. Open the Auction House once so RetGear can scan prices.", wp = { 1458, 64.4, 52.4, "Auctioneer Epitwee" } },
  { key = "bank",  title = "Bank", text = "The bankers (the Montagues) are right next door. Open your bank once.", wp = { 1458, 66.0, 44.0, "Undercity bank" } },
  { key = "mail",  title = "Mailbox", text = "Open a mailbox next to the bank and collect anything your main sent.", wp = { 1458, 66.0, 44.0, "mailbox by the bank" } },
  { key = "inn",   title = "Make Undercity home", text = "Talk to Innkeeper Norman, make the inn your home, and always log out inside the inn so you log in at the Auction House.", wp = { 1458, 67.7, 37.9, "Innkeeper Norman" } },
  { key = "bags",  title = "Bags", text = "Fill all four bag slots: mail bags from your main, or buy them from Jonathan Chambers (bag vendor).", wp = { 1458, 69.2, 61.2, "Jonathan Chambers" } },
}

-- Only if you want it to level (not needed for a bank alt).
RG.ALT_LEVELING = {
  "You don't have to level a bank alt: the Auction House, bank and mail all work at level 1.",
  "If you want a few levels (for example to carry more or to quest later): do the Deathknell quests to level 5 (about 20 minutes), then Brill to 10. The Route tab on your main shows the same path.",
  "Logging out in the Undercity inn earns rested XP the whole time, so a parked bank alt levels twice as fast later.",
}

local function key() return RG.PlayerKey and RG.PlayerKey() or "?" end
local function prog()
  RetGearDB.altGuide = RetGearDB.altGuide or {}
  local k = key()
  RetGearDB.altGuide[k] = RetGearDB.altGuide[k] or {}
  return RetGearDB.altGuide[k]
end

-- A step counts as done when it, or any later step, has happened (you can't be in Undercity without passing Brill).
local IMPLIES_ARRIVAL = { uc = true, ah = true, bank = true, mail = true }
function RG.AltStepDone(i)
  local p = prog()
  local s = RG.ALT_STEPS[i]
  if p[s.key] then return true end
  -- Brill and "into Undercity" are done once you've done anything inside Undercity
  if s.key == "brill" or s.key == "uc" then
    for k in pairs(IMPLIES_ARRIVAL) do if p[k] then return true end end
  end
  return false
end
function RG.AltGuideProgress()
  local done, nextI = 0, nil
  for i = 1, #RG.ALT_STEPS do
    if RG.AltStepDone(i) then done = done + 1 elseif not nextI then nextI = i end
  end
  return done, #RG.ALT_STEPS, nextI
end
-- The guide runs on an alt until every step is done (or you hide it).
function RG.AltGuideActive()
  if not (RG.IsAlt and RG.IsAlt()) then return false end
  if prog().hidden then return false end
  local done, total = RG.AltGuideProgress()
  return done < total
end
function RG.AltGuideHide() prog().hidden = true; if RG.ClearWaypoint then RG.ClearWaypoint() end; if RG.RefreshTracker then RG.RefreshTracker() end end

-- Point the arrow at the next step.
local function autoPin()
  if not RG.AltGuideActive() then return end
  local _, _, nextI = RG.AltGuideProgress()
  local s = nextI and RG.ALT_STEPS[nextI]
  if s and s.wp and RG.AutoPin then RG.AutoPin("altguide#" .. nextI, s.wp) end
end
RG.AltGuidePin = autoPin

-- Detect each step from the game.
local function mark(k)
  local p = prog()
  if p[k] then return end
  p[k] = true
  local done, total = RG.AltGuideProgress()
  if done >= total then
    RG.Print(GREEN .. "Bank alt ready!|r Your main can mail to " .. (UnitName("player") or "this character") .. ", and this tracker now shows the shopping list.")
    if RG.ClearWaypoint then RG.ClearWaypoint() end
  else
    local _, _, nextI = RG.AltGuideProgress()
    local s = RG.ALT_STEPS[nextI]
    RG.Print(GOLD .. "Bank alt " .. done .. "/" .. total .. ":|r next, " .. s.title:lower() .. ".")
  end
  if RG.RefreshTracker then RG.RefreshTracker() end
  if RG.RefreshUI then RG.RefreshUI() end
  autoPin()
end
local function checkPlace()
  local zone = GetRealZoneText and GetRealZoneText() or ""
  local sub = GetSubZoneText and GetSubZoneText() or ""
  if sub == "Brill" then mark("brill") end
  if zone == "Undercity" then mark("uc") end
end
local function checkStatic()
  if GetBindLocation and GetBindLocation() == "Undercity" then mark("inn") end
  local full = true
  for bag = 1, 4 do
    local n = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
    if n == 0 then full = false end
  end
  if full then mark("bags") end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS", "AUCTION_HOUSE_SHOW", "BANKFRAME_OPENED", "MAIL_SHOW", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "HEARTHSTONE_BOUND", "CONFIRM_BINDER" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if not (RG.db and RG.IsAlt and RG.IsAlt()) then return end
  if event == "AUCTION_HOUSE_SHOW" then mark("ah")
  elseif event == "BANKFRAME_OPENED" then mark("bank")
  elseif event == "MAIL_SHOW" then mark("mail")
  else checkPlace(); checkStatic() end
  if event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(3, function()
      if RG.AltGuideActive() then
        local done, total = RG.AltGuideProgress()
        if done == 0 then RG.Print(GOLD .. "Secret bank-alt guide:|r follow the arrow to the Undercity Auction House (" .. total .. " quick steps on the tracker).") end
        autoPin()
      end
    end)
  end
end)

-- Tracker section for alts: { text, onClick, tip, done }
function RG.AltGuideLines()
  if not RG.AltGuideActive() then return nil end
  local out = {}
  local done, total, nextI = RG.AltGuideProgress()
  for i, s in ipairs(RG.ALT_STEPS) do
    local isDone = RG.AltStepDone(i)
    if not isDone and #out < 3 then
      local wp = s.wp
      out[#out + 1] = { (i == nextI and GOLD or "|cffffffff") .. s.title .. "|r" .. GREY .. ": " .. s.text .. "|r", function() if wp then RG.PinWaypoint(wp) end end,
        (wp and ("Click: point the arrow at " .. wp[4] .. ".") or "") }
    end
  end
  return out, done, total
end

local base = SlashCmdList.RETGEAR
SlashCmdList.RETGEAR = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  cmd = cmd and cmd:lower()
  if cmd == "bankalt" or cmd == "altguide" then
    if RG.IsAlt and RG.IsAlt() then
      prog().hidden = nil
      autoPin(); if RG.RefreshTracker then RG.RefreshTracker() end
      RG.Print("Bank-alt guide is on your tracker. Follow the arrow.")
    else
      RG.altGuideOpen = true
      if RG.ShowTab then RG.ShowTab("mail") end
      RG.Print(GOLD .. "Secret bank-alt guide:|r make a new Undead on this realm and log in: RetGear walks it to the Undercity Auction House with the arrow. The steps are on the Bank alt tab.")
    end
    return
  end
  return base(msg)
end
