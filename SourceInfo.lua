-- Waypath+ "where do I get this?": click an item in My gear (or the Gear guide,
-- or the 2nd Spec gear list) and a small window shows where it comes from: the
-- dungeon and the boss that drops it (boss level, when to run it, the entrance),
-- or the quest that rewards it (who starts it, where, the level you can take it
-- at, what to do first, whether it's in your log or done), or the vendor or rare
-- mob, with a button to put it on your map.
local _, RG = ...
local GOLD, GREEN, RED, GREY = RG.COLORS.GOLD, RG.COLORS.GREEN, RG.COLORS.RED, RG.COLORS.GREY
local WHITE = "|cffffffff"

-- ---------------------------------------------------------------------------
-- Finding the entry for an item
-- ---------------------------------------------------------------------------
local function lists()
  local out = { RG.GUIDE or {} }
  local cls = RG.PLAYER_CLASS
  if RG.SpecGuide then out[#out + 1] = RG.SpecGuide() end
  for _, l in pairs(((RG.SPEC_HAND or {})[cls]) or {}) do out[#out + 1] = l end
  for _, l in pairs(((RG.SPEC_GEAR or {})[cls]) or {}) do out[#out + 1] = l end
  out[#out + 1] = (RG.CLASS_GEAR or {})[cls] or {}
  return out
end
-- Hand-written entries (with notes) win over generated ones.
function RG.ItemSourceEntry(id)
  if not id then return nil end
  local best
  for _, l in ipairs(lists()) do
    for _, g in ipairs(l) do
      if g.id == id then
        if not g.gen then return g end
        best = best or g
      end
    end
  end
  return best
end

-- Quests by name (for hand-written entries, which carry the quest name, not its ID)
local byName
local function questID(g)
  if g.q then return g.q end
  if not RG.QDATA then return nil end
  if not byName then
    byName = {}
    for id, d in pairs(RG.QDATA) do
      if d.n and (not byName[d.n] or (RG.QuestForMe and RG.QuestForMe(d))) then byName[d.n] = id end
    end
  end
  local name = (g.src or ""):gsub("%s*%(.-%)$", "")
  return byName[name]
end

local function zoneName(uiMapID)
  if not uiMapID then return nil end
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMapID)
  return info and info.name or nil
end
local function at(wp)
  if not wp then return "" end
  local z = zoneName(wp[1])
  return (z and (z .. " ") or "") .. string.format("(%.0f, %.0f)", wp[2], wp[3])
end
local function dungeonOf(zone)
  if not zone or zone == "" then return nil end
  local d = RG.DUNGEON_QUESTS or {}
  if d[zone] then return zone end
  local wps = RG.WAYPOINTS and RG.WAYPOINTS.dungeons or {}
  if wps[zone] then return zone end
  -- "Scarlet Monastery Cathedral" -> "Scarlet Monastery"
  for name in pairs(wps) do if zone:find(name, 1, true) == 1 then return name end end
  for name in pairs(d) do if zone:find(name, 1, true) == 1 then return name end end
end
local function isDone(qid) return qid and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(qid) end

-- One source (quest, dungeon boss, rare mob, vendor, craft) -> heading, lines, map pin
local function describe(src, lvl)
  local how = src.how
  local out = { lines = {} }
  local function line(label, text) if text and text ~= "" then out.lines[#out.lines + 1] = { label, text } end end
  local myLvl = UnitLevel("player") or 1
  if how == "Quest" then
    local qid = questID(src)
    local d = qid and RG.QDATA and RG.QDATA[qid]
    local name = (d and d.n) or (src.src or ""):gsub("%s*%(.-%)$", "")
    out.title = "Quest reward"
    out.icon = 136797
    line("Quest", GOLD .. name .. "|r")
    if d and d.s then
      line("Starts with", WHITE .. (d.s[4] or "?") .. "|r" .. GREY .. "  ·  " .. at(d.s) .. "|r")
      out.wp = { d.s[1], d.s[2], d.s[3], d.s[4] or name }
      out.wpText = "Show " .. (d.s[4] or "the quest giver") .. " on my map"
    else
      local giver = (src.src or ""):match("%((.-)%)$")
      line("Starts with", WHITE .. (giver or "see the quest") .. "|r" .. ((src.zone or "") ~= "" and (GREY .. "  ·  " .. src.zone .. "|r") or ""))
      local gw = giver and RG.WAYPOINTS and RG.WAYPOINTS.givers and RG.WAYPOINTS.givers[giver]
      if gw then out.wp = gw; out.wpText = "Show " .. giver .. " on my map" end
    end
    if d and d.e and d.s and d.e[4] ~= d.s[4] then line("Turn in to", WHITE .. (d.e[4] or "?") .. "|r" .. GREY .. "  ·  " .. at(d.e) .. "|r") end
    local dun = dungeonOf(src.zone)
    if dun then line("Done in", "|cffA58BD8" .. dun .. "|r" .. GREY .. "  (a dungeon quest: bring a group)|r") end
    if d and (d.r or d.l) then
      local req = d.r or d.l
      local col = myLvl >= req and GREEN or GOLD
      line("Level", col .. "You can take it at " .. req .. "|r" .. (d.l and (GREY .. "  ·  quest level " .. d.l .. "|r") or ""))
    end
    local function names(list)
      local t = {}
      for _, p in ipairs(list or {}) do
        local pd = RG.QDATA[p]
        if pd and pd.n then t[#t + 1] = (isDone(p) and GREEN or WHITE) .. pd.n .. "|r" end
      end
      return t
    end
    if d and d.pg then local t = names(d.pg); if #t > 0 then line("First do", table.concat(t, GREY .. ", |r")) end end
    if d and d.ps then local t = names(d.ps); if #t > 0 then line(#t > 1 and "First do one of" or "First do", table.concat(t, GREY .. " or |r")) end end
    local status
    if isDone(qid) then status = GREEN .. "You've done this quest|r"
    elseif RG.InLog and RG.InLog(name, qid) then status = GREEN .. "It's in your quest log|r"
    elseif d and RG.QuestForMe and not RG.QuestForMe(d) then status = RED .. "Not available to your race or class|r"
    elseif d and d.r and myLvl < d.r then status = GOLD .. (d.r - myLvl) .. " more level" .. (d.r - myLvl > 1 and "s" or "") .. " before you can take it|r"
    else status = GOLD .. "Go pick it up|r" end
    line("Status", status)
  elseif how == "Dungeon" or how == "Drop" then
    local dun = dungeonOf(src.zone) or src.zone
    out.title = "Dungeon drop"
    out.icon = 136058
    line("Dungeon", "|cffA58BD8" .. (src.zone or "?") .. "|r")
    line("Drops from", WHITE .. (src.src or "?") .. "|r" .. (src.bl and (GREY .. "  ·  level " .. src.bl .. "|r") or ""))
    local dq = RG.DUNGEON_QUESTS and RG.DUNGEON_QUESTS[dun]
    if dq and dq.go then line("Run it from", (myLvl >= dq.go and GREEN or GOLD) .. "level " .. dq.go .. "|r" .. ((dq.quests and #dq.quests > 0) and (GREY .. "  ·  " .. #dq.quests .. " quest" .. (#dq.quests > 1 and "s" or "") .. " for you there (Route tab)|r") or "")) end
    local ew = RG.WAYPOINTS and RG.WAYPOINTS.dungeons and RG.WAYPOINTS.dungeons[dun]
    if ew then line("Entrance", GREY .. at(ew) .. "|r"); out.wp = ew; out.wpText = "Show the " .. dun .. " entrance on my map" end
    if dq and dq.prep and dq.prep < (dq.go or 0) then line("Get ready", GREY .. "pick up its quests from level " .. dq.prep .. "|r") end
    if dq and dq.note then line("Tip", GREY .. dq.note .. "|r") end
  elseif how == "Rare mob" then
    out.title = "Rare or elite mob"
    out.icon = 133639
    line("Drops from", WHITE .. (src.src or "?") .. "|r" .. (src.bl and (GREY .. "  ·  level " .. src.bl .. "|r") or ""))
    line("Where", GREY .. (src.zone or "") .. "|r")
    local w = RG.WAYPOINTS and RG.WAYPOINTS.gear and RG.WAYPOINTS.gear[(src.src or "") .. "|" .. (src.zone or "")]
    if w then line("Seen at", GREY .. at(w) .. "  ·  it may wander or take time to respawn|r"); out.wp = w; out.wpText = "Show " .. src.src .. " on my map" end
  elseif how == "Vendor" then
    out.title = "Sold by a vendor"
    out.icon = 133784
    line("Vendor", WHITE .. (src.src or "?") .. "|r")
    line("Where", GREY .. (src.zone or "") .. "|r")
    local w = RG.WAYPOINTS and RG.WAYPOINTS.gear and RG.WAYPOINTS.gear[(src.src or "") .. "|" .. (src.zone or "")]
    if w then line("Stands at", GREY .. at(w) .. "|r"); out.wp = w; out.wpText = "Show " .. src.src .. " on my map" end
  elseif how == "Crafted" then
    out.title = "Crafted"
    out.icon = 136241
    line("Made with", WHITE .. (src.src or "?") .. "|r")
    if src.bs then local sk = RG.Skill and RG.Skill("Blacksmithing"); line("Your skill", ((sk or 0) >= src.bs and GREEN or GOLD) .. (sk and (sk .. " / " .. src.bs) or ("needs " .. src.bs)) .. "|r") end
  else
    out.title = (how == "BoE" and "World drop (Bind on Equip)") or how or "Source"
    out.icon = 133784
    line("From", WHITE .. (src.src or "?") .. "|r" .. ((src.zone or "") ~= "" and (GREY .. "  ·  " .. src.zone .. "|r") or ""))
  end
  return out
end
RG.DescribeSource = describe

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------
local win, pool = nil, {}
local function makeWin()
  win = CreateFrame("Frame", "WaypathSourceFrame", UIParent, "BackdropTemplate")
  win:SetSize(400, 200); win:SetFrameStrata("DIALOG"); win:SetToplevel(true)
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); self.placed = true end)
  win:SetClampedToScreen(true)
  RG.DialogBackdrop(win)
  win.iconBorder = win:CreateTexture(nil, "ARTWORK"); win.iconBorder:SetSize(40, 40); win.iconBorder:SetPoint("TOPLEFT", 16, -16)
  win.iconBorder:SetColorTexture(0.6, 0.55, 0.4, 0.9)
  win.icon = win:CreateTexture(nil, "OVERLAY"); win.icon:SetPoint("TOPLEFT", win.iconBorder, 2, -2); win.icon:SetPoint("BOTTOMRIGHT", win.iconBorder, -2, 2)
  win.name = RG.NewText(win, "GameFontNormalLarge"); win.name:SetPoint("TOPLEFT", win.iconBorder, "TOPRIGHT", 10, -1); win.name:SetPoint("RIGHT", -34, 0); win.name:SetJustifyH("LEFT")
  win.sub = RG.NewText(win, "GameFontHighlightSmall"); win.sub:SetPoint("TOPLEFT", win.name, "BOTTOMLEFT", 0, -4); win.sub:SetPoint("RIGHT", -20, 0); win.sub:SetJustifyH("LEFT")
  win.close = CreateFrame("Button", nil, win, "UIPanelCloseButton"); win.close:SetPoint("TOPRIGHT", -4, -4)
  win.close:SetScript("OnClick", function() win:Hide() end)
  win.item = CreateFrame("Button", nil, win)
  win.item:SetAllPoints(win.iconBorder)
  win.item:SetScript("OnEnter", function(self)
    if not win.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetHyperlink(win.link); GameTooltip:Show()
  end)
  win.item:SetScript("OnLeave", function() GameTooltip:Hide() end)
  win.map = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.map:SetSize(220, 24)
  win.link2 = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.link2:SetSize(110, 24); win.link2:SetText("Link in chat")
  win.link2:SetScript("OnClick", function()
    local insert = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
    if win.link and insert then insert(win.link) end
  end)
  if UISpecialFrames then table.insert(UISpecialFrames, "WaypathSourceFrame") end
  win:Hide()
end
local function fs(i, kind)
  local key = kind .. i
  if not pool[key] then
    local f = RG.NewText(win, kind == "head" and "GameFontNormal" or (kind == "label" and "GameFontNormalSmall" or "GameFontHighlightSmall"))
    f:SetJustifyH("LEFT"); f:SetWordWrap(true)
    pool[key] = f
  end
  return pool[key]
end

-- g = a gear list entry ({ id, slot, lvl, how, src, zone, q?, bl?, also? }) or an item ID.
-- opts.note = an extra line under the item name (e.g. "+12 over your Worn Helm").
function RG.ShowItemSource(g, opts)
  if type(g) == "number" then g = RG.ItemSourceEntry(g) or { id = g } end
  if not g or not g.id then return end
  opts = opts or {}
  -- Shift-click links, Ctrl-click previews, like everywhere else
  local _, link = RG.ItemInfo(g.id)
  if link and IsModifiedClick then
    local insert = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
    if IsModifiedClick("CHATLINK") and insert then insert(link); return end
    if IsModifiedClick("DRESSUP") and DressUpItemLink then DressUpItemLink(link); return end
  end
  if not win then makeWin() end
  for _, f in pairs(pool) do f:Hide() end
  local name, _, quality, _, minLevel, _, _, _, _, tex = RG.ItemInfo(g.id)
  if not name then RG.RequestItem(g.id) end
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
  win.link = link
  win.icon:SetTexture(tex or (GetItemIcon and GetItemIcon(g.id)) or 134400)
  win.name:SetText((c and c.hex or WHITE) .. (name or ("Item " .. g.id)) .. "|r")
  local lvlTxt = (minLevel and minLevel > 0) and minLevel or g.lvl
  local subParts = {}
  if g.slot then subParts[#subParts + 1] = (g.slot == "2H" and "Two-Hand" or g.slot) end
  if lvlTxt then subParts[#subParts + 1] = ((UnitLevel("player") or 1) >= lvlTxt and GREEN or GOLD) .. "usable at level " .. lvlTxt .. "|r" end
  win.sub:SetText(GREY .. table.concat(subParts, "  ·  ") .. "|r" .. (opts.note and ("\n" .. opts.note) or ""))
  local y = -16 - 40 - 12 - (opts.note and 12 or 0)
  local inner = win:GetWidth() - 32
  local nh, nl, nt = 0, 0, 0
  local firstWp, firstWpText
  local function section(d, heading)
    nh = nh + 1
    local h = fs(nh, "head"); h:ClearAllPoints(); h:SetPoint("TOPLEFT", 16, y); h:SetWidth(inner)
    h:SetText(heading or d.title); h:Show()
    y = y - (h:GetStringHeight() or 14) - 6
    for _, ln in ipairs(d.lines) do
      nl = nl + 1; nt = nt + 1
      local l = fs(nl, "label"); l:ClearAllPoints(); l:SetPoint("TOPLEFT", 22, y); l:SetWidth(96); l:SetText(ln[1]); l:Show()
      local t = fs(nt, "text"); t:ClearAllPoints(); t:SetPoint("TOPLEFT", 122, y); t:SetWidth(inner - 106); t:SetText(ln[2]); t:Show()
      y = y - math.max(t:GetStringHeight() or 12, l:GetStringHeight() or 12, 12) - 5
    end
    y = y - 6
    if d.wp and not firstWp then firstWp, firstWpText = d.wp, d.wpText end
  end
  if g.how then
    local d = describe(g, g.lvl)
    section(d, d.title)
    for i, a in ipairs(g.also or {}) do
      local da = describe(a, g.lvl)
      section(da, "Also: " .. da.title:lower())
      if i >= 2 then break end
    end
  else
    section({ title = "Where it comes from", lines = { { "Source", GREY .. "Not on your gear lists. Waypath+ only knows where list items come from.|r" } } })
  end
  if g.note then
    nt = nt + 1
    local t = fs(nt, "text"); t:ClearAllPoints(); t:SetPoint("TOPLEFT", 16, y); t:SetWidth(inner); t:SetText(GOLD .. "Note:|r " .. g.note); t:Show()
    y = y - (t:GetStringHeight() or 12) - 8
  end
  if g.ah and RG.PriceText then
    nt = nt + 1
    local t = fs(nt, "text"); t:ClearAllPoints(); t:SetPoint("TOPLEFT", 16, y); t:SetWidth(inner); t:SetText(GOLD .. "Auction House:|r " .. (RG.PriceText(g.id) or "no price yet")); t:Show()
    y = y - (t:GetStringHeight() or 12) - 8
  end
  -- buttons
  win.map:ClearAllPoints(); win.map:SetPoint("TOPLEFT", 16, y - 4)
  win.link2:ClearAllPoints(); win.link2:SetPoint("LEFT", win.map, "RIGHT", 8, 0)
  if firstWp then
    win.map:SetText(firstWpText or "Show on my map"); win.map:Enable()
    win.map:SetScript("OnClick", function() if RG.PinWaypoint then RG.PinWaypoint(firstWp) end end)
  else
    win.map:SetText("No map location"); win.map:Disable()
  end
  win.link2:SetShown(link ~= nil)
  -- the map button fits its label (a long place name falls back to "Show on my map")
  local room = (win:GetWidth() - 32) - (link and (110 + 8) or 0)
  local function textW() local f = win.map.GetFontString and win.map:GetFontString(); return (f and f:GetStringWidth() or 0) + 28 end
  if textW() > room and firstWp then win.map:SetText("Show on my map") end
  win.map:SetWidth(math.min(room, math.max(140, textW())))
  win:SetHeight(-(y - 4) + 24 + 18)
  if not win.placed then
    win:ClearAllPoints()
    local main = _G.WaypathFrame
    if main and main:IsShown() then win:SetPoint("TOPLEFT", main, "TOPRIGHT", 6, -40) else win:SetPoint("CENTER", UIParent, "CENTER", 260, 60) end
  end
  win:Show()
  if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION or 857) end
end

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
  if cmd and cmd:lower() == "where" then
    local id = tonumber(rest:match("item:(%d+)") or rest)
    if id then RG.ShowItemSource(id) else RG.Print("Usage: /wp where <item link or ID>: shows where an item from your gear lists comes from.") end
    return
  end
  return base(msg)
end
