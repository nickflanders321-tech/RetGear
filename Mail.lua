-- Waypath+ bank alt: quests on your route whose items you can buy on the
-- Auction House and mail to your main instead of farming or crafting them.
-- Your main records what it already has; the bank alt sees what's left to
-- buy, can search the AH for it, and attaches it all at the mailbox in one click.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY

-- Classic-era quests (WoW Forever may have changed some; the weekly update checks).
--   lvl = quest level, req = level you can pick it up, items = { {id, count, name} }
--   bs  = Blacksmithing skill that lets you make the item yourself instead
--   any = the quest needs whichever of these you're missing (pages)
local function pages(first, list)
  local out = {}
  for _, p in ipairs(list) do out[#out + 1] = { first + p, 1, "Page " .. p } end
  return out
end
RG.MAIL_QUESTS = {
  { quest = "The Lost Pages", zone = "Ashenvale", lvl = 26, req = 20, giver = "Gurda Ragescar, near Splintertree Post",
    why = "12 Shredder Operating Manual pages make 3 chapters. They drop slowly from Wrathtail nagas, so buy the ones you're missing.",
    any = true, items = pages(16644, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }) },
  { quest = "Warsong Saw Blades", zone = "Ashenvale", lvl = 27, req = 22, giver = "Splintertree Post",
    why = "Trade a Deadly Blunderbuss (Engineering) for the saw blades, which also finishes part of Warsong Supplies (2,750 XP).",
    items = { { 4369, 1, "Deadly Blunderbuss" } } },
  { quest = "Elixir of Agony (part 3)", zone = "Hillsbrad Foothills", lvl = 30, req = 24, giver = "Apothecary Lydon, Tarren Mill",
    why = "Needs a Strong Troll's Blood Potion (Alchemy). Mail one ahead so you can finish the chain in one visit.",
    items = { { 3388, 1, "Strong Troll's Blood Potion" } } },
  { quest = "Coolant Heads Prevail", zone = "Badlands", lvl = 37, req = 35, giver = "Lotwil Veriatus, Badlands",
    why = "3,700 XP for one Frost Oil (Alchemy). Free experience if it's in your bags.",
    items = { { 3829, 1, "Frost Oil" } } },
  { quest = "Gyro... What?", zone = "Badlands", lvl = 37, req = 35, giver = "Lotwil Veriatus, Badlands",
    why = "Follows Coolant Heads Prevail: one Gyrochronatom (Engineering) for another big XP turn-in.",
    items = { { 4389, 1, "Gyrochronatom" } } },
  { quest = "Stone Is Better than Cloth", zone = "Badlands", lvl = 42, req = 36, giver = "Lucien Tosselwrench, Badlands", bs = 120,
    why = "Patterned Bronze Bracers. You're a blacksmith: make them yourself at 120 skill (5 Bronze Bar, 2 Coarse Grinding Stone). Rewards Enchanted Stonecloth Bracers.",
    items = { { 2868, 1, "Patterned Bronze Bracers" } } },
  { quest = "The Green Hills of Stranglethorn", zone = "Stranglethorn Vale", lvl = 40, req = 30, giver = "Barnil Stonepot, Nesingwary's camp",
    why = "Four chapters of pages, then 4,700 XP and Jungle Boots. Pages drop from STV mobs; buy the missing ones instead of grinding for them.",
    any = true, items = pages(2724, { 1, 4, 6, 8, 10, 11, 14, 16, 18, 20, 21, 24, 25, 26, 27 }) },
  { quest = "Caught!", zone = "Searing Gorge", lvl = 45, req = 43, giver = "The Wooden Outhouse, Searing Gorge",
    why = "5,550 XP. Needs 15 Silk Cloth plus 8 Dark Iron Geologists. Mail the silk so you only do the kills.",
    items = { { 4306, 15, "Silk Cloth" } } },
  { quest = "Chasing A-Me 01", zone = "Un'Goro Crater", lvl = 53, req = 48, giver = "Un'Goro Crater (A-Me 01 chain)",
    why = "Needs a Mithril Casing (Engineering) to repair A-Me 01. Big XP chain if you bring it.",
    items = { { 10561, 1, "Mithril Casing" } } },
}

-- ---------------------------------------------------------------------------
-- Main side: remember what you already have and which quests are done
-- ---------------------------------------------------------------------------
local function count(id, bank)
  return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, bank)) or (GetItemCount and GetItemCount(id, bank)) or 0
end
local function snapshot()
  if not RG.IsMain() then return end   -- only your main's bags count for the bank alt's list
  RG.db.mainHave = RG.db.mainHave or {}
  RG.db.mailDone = RG.db.mailDone or {}
  RG.db.mainLevel = UnitLevel("player")
  local p = RG.Professions and RG.Professions()["Blacksmithing"]
  RG.db.mainBS = p and p.rank or 0
  for _, q in ipairs(RG.MAIL_QUESTS) do
    for _, it in ipairs(q.items) do RG.db.mainHave[it[1]] = count(it[1], true) end
    -- chain parts share one name, so only trust the game for single quests
    if not q.quest:find("%(") and RG.QuestState and RG.QuestState(q.quest) == "done" then RG.db.mailDone[q.quest] = true end
  end
end
RG.MailSnapshot = snapshot

-- Quests worth mailing for: from a few levels back to `ahead` levels ahead of your main.
function RG.MailQuests(ahead, all)
  local lvl = RG.db.mainLevel or UnitLevel("player")
  ahead = ahead or 8
  local out = {}
  for _, q in ipairs(RG.MAIL_QUESTS) do
    local done = RG.db.mailDone and RG.db.mailDone[q.quest]
    if all or (not done and q.lvl >= lvl - 4 and q.req <= lvl + ahead) then
      local rows, missing = {}, 0
      for _, it in ipairs(q.items) do
        local have = (RG.db.mainHave and RG.db.mainHave[it[1]]) or 0
        local need = math.max(0, it[2] - have)
        missing = missing + need
        rows[#rows + 1] = { id = it[1], count = it[2], name = it[3], have = have, need = need }
      end
      out[#out + 1] = { q = q, items = rows, missing = missing, done = done, selfMade = q.bs and (RG.db.mainBS or 0) >= q.bs }
    end
  end
  table.sort(out, function(a, b) return a.q.lvl < b.q.lvl end)
  return out
end

-- What the bank alt should buy and mail: one row per item, soonest first.
function RG.ShoppingList(ahead)
  local list = {}
  for _, m in ipairs(RG.MailQuests(ahead)) do
    if not m.selfMade then
      for _, it in ipairs(m.items) do
        if it.need > 0 then
          local onAlt = RG.IsAlt() and count(it.id, false) or 0
          list[#list + 1] = { id = it.id, need = it.need, toBuy = math.max(0, it.need - onAlt), quest = m.q.quest, lvl = m.q.lvl, name = it.name }
        end
      end
    end
  end
  return list
end
function RG.MailIDs()
  local ids = {}
  for _, e in ipairs(RG.ShoppingList()) do ids[#ids + 1] = e.id end
  return ids
end

-- Mail quests for a route entry (same zone, overlapping levels)
function RG.MailForEntry(r)
  local out = {}
  for _, m in ipairs(RG.MailQuests(nil, true)) do
    if m.q.zone == r.zone and m.q.lvl >= r.from - 3 and m.q.req <= r.to then out[#out + 1] = m end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Auction House: click an item in the list to search for it
-- ---------------------------------------------------------------------------
function RG.SearchAH(id)
  local name = RG.ItemInfo(id)
  if not name then RG.RequestItem(id); RG.Print("Loading the item, click again in a moment."); return end
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() and AuctionHouseFrame.SearchBar then
    local sb = AuctionHouseFrame.SearchBar
    pcall(function()
      if sb.SearchBox then sb.SearchBox:SetText(name) end
      if sb.StartSearch then sb:StartSearch() elseif sb.SearchButton then sb.SearchButton:Click() end
    end)
  elseif AuctionFrame and AuctionFrame:IsShown() and BrowseName then
    BrowseName:SetText(name)
    if AuctionFrameBrowse_Search then pcall(AuctionFrameBrowse_Search) end
  else
    RG.Print("Open the Auction House, then click the item to search for it.")
  end
end

-- ---------------------------------------------------------------------------
-- Mailbox (bank alt): one button attaches everything your main needs
-- ---------------------------------------------------------------------------
local mailBtn
local function attachAll()
  local main = RG.MainName()
  if not main then RG.Print("No main set yet. Log in on your paladin first (or /wp main there).") return end
  if MailFrameTab2 and MailFrameTab2.Click and not (SendMailFrame and SendMailFrame:IsShown()) then MailFrameTab2:Click() end
  if SendMailNameEditBox then SendMailNameEditBox:SetText(main) end
  if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText("Quest items from your bank alt") end
  local want = {}
  for _, e in ipairs(RG.ShoppingList()) do want[e.id] = (want[e.id] or 0) + e.need end
  local attached, slotN = 0, 1
  local maxAttach = ATTACHMENTS_MAX_SEND or 12
  local C = C_Container
  for bag = 0, 4 do
    for slot = 1, (C.GetContainerNumSlots(bag) or 0) do
      local info = C.GetContainerItemInfo(bag, slot)
      if info and want[info.itemID] and want[info.itemID] > 0 and not info.isLocked and slotN <= maxAttach then
        C.PickupContainerItem(bag, slot)
        if ClickSendMailItemButton then ClickSendMailItemButton(slotN) end
        if CursorHasItem and CursorHasItem() then ClearCursor() end
        want[info.itemID] = want[info.itemID] - (info.stackCount or 1)
        slotN = slotN + 1; attached = attached + 1
      end
    end
  end
  if attached > 0 then RG.Print("Attached " .. attached .. " item" .. (attached > 1 and "s" or "") .. " for " .. main .. ". Check it, then press Send.")
  else RG.Print("Nothing from the shopping list is in your bags yet. Buy it on the AH first (/wp mail).") end
end
local function showMailButton()
  if not RG.IsAlt() or not MailFrame then return end
  if not mailBtn then
    mailBtn = CreateFrame("Button", nil, MailFrame, "UIPanelButtonTemplate")
    mailBtn:SetSize(190, 24)
    mailBtn:SetPoint("TOPRIGHT", MailFrame, "BOTTOMRIGHT", 0, -2)
    mailBtn:SetScript("OnClick", attachAll)
  end
  local n = #RG.ShoppingList()
  mailBtn:SetText(n > 0 and ("Waypath+: send " .. (RG.MainName() or "main") .. "'s items") or "Waypath+: nothing to send")
  mailBtn:SetEnabled(n > 0)
  mailBtn:Show()
end

-- ---------------------------------------------------------------------------
-- Events, tracker reminder, slash command
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "BANKFRAME_OPENED" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(5, function()
      snapshot()
      if RG.IsAlt() then
        local list = RG.ShoppingList()
        if #list > 0 then RG.Print(#list .. " item" .. (#list > 1 and "s" or "") .. " to buy and mail to " .. (RG.MainName() or "your main") .. ". /wp mail") end
      end
      if RG.QueueTracker then RG.QueueTracker() end
    end)
    return
  elseif event == "MAIL_SHOW" then
    C_Timer.After(0.2, showMailButton)
  else
    RG.Debounce("mailSnap", 0.8, function()
      snapshot()
      if mailBtn and mailBtn:IsShown() then showMailButton() end
      if RG.RefreshUI then RG.RefreshUI() end
    end)
    return
  end
  if RG.RefreshUI then RG.RefreshUI() end
end)

-- On your main: remind you when a mail-able quest is in reach and you're missing the item.
local baseReminders = RG.Reminders
function RG.Reminders()
  local out = baseReminders and baseReminders() or {}
  if RG.IsAlt() then return out end
  local lvl = UnitLevel("player")
  for _, m in ipairs(RG.MailQuests(2)) do
    if m.missing > 0 and m.q.req <= lvl + 2 and not m.done then
      local what = m.selfMade and ("make " .. (m.items[1].name)) or ("have your bank alt mail " .. (m.q.any and (m.missing .. " missing pages") or m.items[1].name))
      out[#out + 1] = { "|TInterface\\Icons\\INV_Letter_15:14:14|t " .. GOLD .. m.q.quest .. "|r" .. GREY .. ": " .. what .. "|r", function() if RG.ShowTab then RG.ShowTab("mail") end end, 6 }
      break
    end
  end
  return out
end

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  cmd = cmd and cmd:lower()
  if cmd == "mail" or cmd == "alt" or cmd == "bank" then if RG.ShowTab then RG.ShowTab("mail") end return end
  if cmd == "char" or cmd == "character" or cmd == "profile" then
    local what = ((msg or ""):match("^%s*%S+%s+(%S+)") or ""):lower()
    if what == "alt" or what == "bankalt" then RG.SetCharMode("alt"); ReloadUI()
    elseif what == "profile" or what == "full" or (cmd == "profile" and what == "") then RG.SetCharMode("profile"); ReloadUI()
    elseif what == "reset" or what == "new" then RG.ResetProfile()
    else
      RG.Print("This character: " .. (RG.IsAlt() and "bank alt" or "its own profile") .. (RG.IsMain() and " (your main)" or "") .. ".")
      RG.Print("/wp char profile  ·  /wp char alt  ·  /wp char reset (a brand new profile)  ·  /wp main")
    end
    return
  end
  if cmd == "main" then
    if RG.IsAlt() then RG.SetCharMode("profile") end
    RG.db.main = RG.PlayerKey()
    RG.Print(UnitName("player") .. " is now your main: your bank alts buy and mail for this character. /reload to apply.")
    return
  end
  return base(msg)
end
