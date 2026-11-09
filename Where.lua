-- LibItemDB-1.0 -- the "Where to get it" window (MINOR 36)
--
-- One item, every way to get it, one row per place: the creatures that drop it (with the chance
-- and the zone they stand in), the vendors that sell it, the veins / herbs / pools / chests that
-- yield it, the bosses from the drop graph, and the quest, crafting, reputation and PvP sources.
--
-- THE LAYOUT IS FASTGUILDINVITE'S, by the operator's direction of 2026-09-24: "use libaceguiwidgets
-- for the UI and lets make it like FGI, a strip on the top and zebra stripped rows to show the info
-- with columns". So: LibAceGUIWidgets' ClearFrame for the chrome, a strip across the top of the
-- content (FGI GUI/Tabs/Scan.lua builds its strip the same way -- a plain frame with text buttons),
-- and W.RowList below it, which is the list FGI's own RowList was extracted into and bands every
-- second row.
--
-- Built on FIRST OPEN, like the price window: most players loading this library never open it.
-- The window owns no data -- rows come from GetItemPlaces and GetSources.

local lib = LibStub and LibStub("LibItemDB-1.0", true)
if not lib or not lib._PriceDB then return end

local function Widgets() return LibStub and LibStub("LibAceGUIWidgets-1.0", true) or nil end

lib.whereWindow = lib.whereWindow or nil

local HELP = "Every way to get the item shown at the top, one row per place.\n\n"
    .. "Source -- how you get it: a creature's Drop, a Boss, a Vendor, a gathering node (Mining, "
    .. "Herbalism, Fishing), a Chest, a Quest, a crafting profession, a Reputation or PvP reward.\n\n"
    .. "Zone -- where that creature, vendor or node stands. Hover a row for its map coordinates.\n\n"
    .. "Chance -- the drop chance per kill or per loot. (quest) means it only drops while you are on "
    .. "the quest that needs it. A faction or profession in brackets means it only drops for that "
    .. "faction's players or for players with that profession; (event) only during a world event; "
    .. "(after a quest) or (before a quest) only once, or until, you have done a quest; "
    .. "(conditional) something else the server checks.\n\n"
    .. "Spawns -- how many of that creature or node the zone has.\n\n"
    .. "With Questbook installed, click a row to be guided to it."

-- ---------------------------------------------------------------------------
-- Pure helpers (specced without a frame)
-- ---------------------------------------------------------------------------
local OBJECT_KIND = { Mining = "Mining", Herbalism = "Herbalism", Fishing = "Fishing" }
local SOURCE_KIND = { quest = "Quest", crafted = "Crafted", reputation = "Reputation", pvp = "PvP",
                      drop = "Drop", vendor = "Vendor", gathered = "Gathered" }

--- A zone's name, in the client's own language when the client can say.
function lib:GetZoneName(uiMapID)
    local info = uiMapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMapID)
    if info and info.name and info.name ~= "" then return info.name end
    return uiMapID and ("Map " .. uiMapID) or ""
end

-- What a drop's loot condition (GetItemPlaces' `condition`) reads as after its chance. A profession
-- is named by the client in its own language; the faction names use the client's own strings.
local function conditionLabel(condition, skill)
    if condition == "skill" then
        local name = skill and C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
            and C_TradeSkillUI.GetTradeSkillDisplayName(skill)
        return (name and name ~= "") and name or "profession"
    end
    if condition == "Alliance" then return FACTION_ALLIANCE or "Alliance" end
    if condition == "Horde" then return FACTION_HORDE or "Horde" end
    return ({ event = "event", questDone = "after a quest", questTaken = "quest",
              questNotStarted = "before a quest" })[condition] or "conditional"
end

local function chanceText(chance, questOnly, condition, skill)
    if not chance then return "" end
    local s = chance < 0.1 and "<0.1%" or ("%.1f%%"):format(chance)
    if questOnly then s = s .. " (quest)" end
    if condition then
        local label = conditionLabel(condition, skill)
        -- "(quest)" once, when the chance's own sign already said it.
        if not (questOnly and label == "quest") then s = s .. " (" .. label .. ")" end
    end
    return s
end

-- Whether a creature with `side` ("A", "H", "AH" or "") serves a player of `faction`.
local function serves(side, faction)
    if faction == "Alliance" then return side:find("A", 1, true) ~= nil end
    if faction == "Horde" then return side:find("H", 1, true) ~= nil end
    return true
end

--- The window's rows for an item, frame-free so what a player sees is pinned by a spec. `faction`
--- ("Alliance" / "Horde"), when given, drops the vendors that faction cannot use. Each row:
---   { kind, name, zone, chance (number or nil), chanceText, spawns (number or nil),
---     uiMapID, points = { {x, y}, ... } }   -- uiMapID/points only for an open-world place
--- In order: bosses, drops, vendors, objects, then the kinds that have no coordinates.
function lib:BuildWhereRows(itemID, faction)
    local rows = {}
    local have = {}              -- which kinds the places data already covers
    local function add(r)
        r.chanceText = chanceText(r.chance, r.questOnly, r.condition, r.conditionSkill)
        r.questOnly, r.condition, r.conditionSkill = nil, nil, nil
        rows[#rows + 1] = r
    end

    local sources = self:GetSources(itemID) or {}
    -- Bosses by CREATURE ID first: the drop graph's encounter key is the boss npcID
    -- (LibItemDB-1.0.lua, the srcItems note), and a place row's id is the CMaNGOS creature entry,
    -- the same number. The NAME is the fallback, for an encounter keyed some other way. Still
    -- missed, and known: a multi-creature encounter keyed on one npc whose other creatures the
    -- loot table also names under a different name.
    local bosses, bossIds = {}, {}
    for _, s in ipairs(sources) do
        if s.encounterID then
            add({ kind = "Boss", name = s.boss or "", zone = s.instance or "", chance = s.rate })
            bossIds[s.encounterID] = true
            if s.boss then bosses[s.boss] = true end
        end
    end

    for _, p in ipairs(self:GetItemPlaces(itemID) or {}) do
        local kind = (p.kind == "drop" and "Drop") or (p.kind == "vendor" and "Vendor")
            or (p.kind == "quest" and "Quest") or OBJECT_KIND[p.profession] or "Chest"
        -- A creature the drop graph already lists as a BOSS is not repeated as a Drop row: the places
        -- data reads the same creature out of the server's loot table (Garr, Molten Core), and two
        -- rows for one kill -- possibly with two different chances -- read as two sources.
        local dupBoss = p.kind == "drop" and (bossIds[p.id] or bosses[p.englishName or p.name])
        -- With a faction given, a vendor that faction cannot use and a drop only the OTHER faction's
        -- players get (a Horde-only quest item, condition "Horde") are both left out.
        local otherSide = faction and (p.condition == "Alliance" or p.condition == "Horde")
            and p.condition ~= faction
        -- A quest giver, like a vendor, only serves the players its side talks to.
        local talks = p.kind == "vendor" or p.kind == "quest"
        if not dupBoss and not otherSide and (not talks or not faction or serves(p.side or "", faction)) then
            have[p.kind == "object" and kind or p.kind] = true
            if #p.places == 0 then
                add({ kind = kind, name = p.name, zone = "", chance = p.chance, questOnly = p.questOnly,
                      condition = p.condition, conditionSkill = p.conditionSkill })
            end
            for _, place in ipairs(p.places) do
                add({ kind = kind, name = p.name, chance = p.chance, questOnly = p.questOnly,
                      condition = p.condition, conditionSkill = p.conditionSkill,
                      zone = place.instance or self:GetZoneName(place.uiMapID), spawns = place.count,
                      uiMapID = place.uiMapID, points = place.points })
            end
        end
    end

    -- The kinds with no coordinates. A drop / vendor / gathering row from the location data only
    -- stands in when the places data had nothing of that kind -- a version with no places data
    -- (Mists, Forever) still shows "World Drop", and one with it does not show it twice.
    for _, s in ipairs(sources) do
        if not s.encounterID and s.instance then
            local kind = SOURCE_KIND[s.source] or s.source or ""
            if kind == "Gathered" then
                if not have[s.instance] then add({ kind = s.instance, name = "", zone = "" }) end
            elseif kind == "Crafted" or kind == "Reputation" or kind == "PvP" then
                add({ kind = kind, name = s.instance, zone = "" })
            elseif not ((kind == "Drop" and have.drop) or (kind == "Vendor" and have.vendor)
                        or (kind == "Quest" and have.quest)) then
                -- A quest's zone, or the generic drop / vendor place a place row did not cover.
                add({ kind = kind, name = "", zone = s.instance })
            end
        end
    end
    return rows
end

--- The point of a row to guide the player to: the one nearest the player when they stand on the
--- row's map, else the row's first (the one nearest its spawns' centre). nil without a point.
function lib:_WherePickPoint(row)
    local pts = row.points
    if not (pts and pts[1]) then return nil end
    local best = pts[1]
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if here and here == row.uiMapID and C_Map.GetPlayerMapPosition then
        local pos = C_Map.GetPlayerMapPosition(here, "player")
        local px, py = pos and pos.x, pos and pos.y
        if px and py then
            px, py = px * 100, py * 100
            local bestD
            for _, p in ipairs(pts) do
                local d = (p.x - px) ^ 2 + (p.y - py) ^ 2
                if not bestD or d < bestD then best, bestD = p, d end
            end
        end
    end
    return best
end

-- Questbook, when it is installed and offers the public call `method` (default TrackPlace, the
-- "track this place" call; StopTracking is its universal stop).
local function questbook(method)
    local ace = LibStub and LibStub("AceAddon-3.0", true)
    local qb = ace and ace:GetAddon("Questbook", true)
    if qb and type(qb[method or "TrackPlace"]) == "function" then return qb end
    return nil
end

-- Whether Questbook is guiding the player to anything. A Questbook with StopTracking but no
-- IsTracking is taken as tracking, so its stop icon is never dimmed into looking useless.
local function questbookTracking(qb)
    if type(qb.IsTracking) ~= "function" then return true end
    return qb:IsTracking() == true
end

local STOP_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-NotReady"   -- Questbook's own stop icon
local STOP_IDLE_ALPHA = 0.4                                         -- and its dimmed idle alpha

--- Dim the window's stop icon while Questbook is guiding to nothing, as Questbook's own is.
function lib:_WhereShowStop()
    local icon = self.whereWindow and self.whereWindow.stopIcon
    local qb = icon and questbook("StopTracking")
    if not qb then return false end
    icon:SetAlpha(questbookTracking(qb) and 1 or STOP_IDLE_ALPHA)
    return true
end

--- Stop whatever Questbook is guiding the player to -- Questbook's universal stop, the same one its
--- own stop icon and `/questbook hud off` use. Returns true when something was stopped.
function lib:WhereStopTracking()
    local qb = questbook("StopTracking")
    if not qb then return false end
    local stopped = qb:StopTracking() == true
    self:_WhereShowStop()
    return stopped
end

--- Ask Questbook to guide the player to a row's place. Returns true when Questbook took it.
function lib:WhereTrack(row)
    local qb = questbook()
    local p = qb and self:_WherePickPoint(row)
    if not (p and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return false end
    local continent, world = C_Map.GetWorldPosFromMapPos(row.uiMapID, CreateVector2D(p.x / 100, p.y / 100))
    if not (continent and world) then return false end
    local tracked = qb:TrackPlace({ name = row.name ~= "" and row.name or row.kind, kind = row.kind,
                                    world = { continent = continent, x = world.x, y = world.y },
                                    location = { zoneName = row.zone } }) ~= false
    self:_WhereShowStop()
    return tracked
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------
local STRIP_H = 30
local STRIP_PAD = 4
local SEARCH_MIN = 3        -- letters typed before the list follows the box on its own; Enter always searches
local SEARCH_MAX = 100      -- results kept; the summary says "100+" when there were more

--- The search strip's results, frame-free: every item whose name contains `query` (any case),
--- sorted by name, at most SEARCH_MAX of them, and whether more were cut. Each row:
---   { id, name (the coloured link when there is one), plainName, typeName, subName, itemLevel }
--- An empty or blank query answers no rows. MINOR 36.
function lib:BuildWhereSearchRows(query)
    query = tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then return {}, false end
    local found = self:Search({ query = query, max = SEARCH_MAX })
    local rows = {}
    for i, r in ipairs(found) do
        rows[i] = { id = r.id, name = r.link or r.name, plainName = r.name, typeName = r.typeName or "",
                    subName = r.subName or "", itemLevel = r.itemLevel }
    end
    return rows, found.capped and true or false
end

-- The two column sets the one list switches between. Built fresh per call, because a RowList may
-- widen a column table it is handed.
local function whereColumns()
    return {
        { key = "kind",       header = "Source", justify = "LEFT", width = 80 },
        { key = "name",       header = "Name",   justify = "LEFT" },
        { key = "zone",       header = "Zone",   justify = "LEFT", width = 150 },
        { key = "chanceText", header = "Chance", justify = "RIGHT", width = 80 },
        { key = "spawns",     header = "Spawns", justify = "RIGHT", width = 50 },
    }
end

local function searchColumns()
    return {
        { key = "name",      header = "Item",    justify = "LEFT" },
        { key = "typeName",  header = "Type",    justify = "LEFT", width = 110 },
        { key = "subName",   header = "Subtype", justify = "LEFT", width = 110 },
        { key = "itemLevel", header = "Level",   justify = "RIGHT", width = 50 },
    }
end

local function store()
    local db = lib:_PriceDB()
    if type(db.where) ~= "table" then db.where = {} end
    return db.where
end

-- Vendors of the other faction are hidden unless the player turned that off.
function lib:GetWhereOwnFactionOnly()
    return store().ownFactionOnly ~= false
end

function lib:SetWhereOwnFactionOnly(on)
    store().ownFactionOnly = on and true or false
    if self.whereWindow and self.whereWindow.itemID then self:_PaintWhereWindow() end
end

local function playerFaction()
    return UnitFactionGroup and UnitFactionGroup("player") or nil
end

local function makeStripButton(parent, width, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 22)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", b, "CENTER", 0, 0)
    label:SetText(text)
    b.label = label
    b:SetScript("OnClick", onClick)
    return b
end

-- The search strip, across the very top: a box that searches LibItemDB by name. Typing SEARCH_MIN
-- letters or more (or pressing Enter) turns the list below into the matching items; clicking one
-- shows where to get it. Escape leaves the box without searching.
--
-- THE BOX IS LIBAceGUIWidgets' OWN SEARCH BOX (W:CreateSearchBox: Blizzard's SearchBoxTemplate with
-- the magnifier, the greyed placeholder and the clear-X), not a hand-built InputBoxTemplate -- the
-- operator, 2026-09-24: "you have libaceguiwidgets, you should use their search bar with graphics and
-- clear functionality instead of the hand rolled one". Its onChanged fires on every edit, the
-- clear-X included, so clearing the box is what returns to the item.
local function buildSearchStrip(W, win, parent)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetHeight(STRIP_H)
    strip:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    strip:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    win.searchStrip = strip

    local box = W:CreateSearchBox(strip, {
        height      = 20,
        placeholder = "Search items by name",
        tipTitle    = "Search items",
        tipBody     = "Type three or more letters of an item's name, or press Enter, then click an item "
            .. "to see where to get it. Clear the box to go back.",
        onChanged   = function(text)
            text = text or ""
            if #text >= SEARCH_MIN or text == "" then lib:WhereSearch(text) end
        end,
    })
    box:ClearAllPoints()
    box:SetPoint("LEFT", strip, "LEFT", 8, 0)
    box:SetPoint("RIGHT", strip, "RIGHT", -8, 0)
    -- Enter searches whatever the length. Hooked, so the template's own Enter handling still runs.
    box:HookScript("OnEnterPressed", function(self) lib:WhereSearch(self:GetText()) end)
    win.searchBox = box
end

local function buildStrip(win, parent)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetHeight(STRIP_H)
    strip:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(STRIP_H + STRIP_PAD))
    strip:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(STRIP_H + STRIP_PAD))
    win.strip = strip

    local icon = strip:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", strip, "LEFT", 4, 0)
    win.icon = icon

    local name = strip:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    name:SetJustifyH("LEFT")
    win.itemLabel = name

    win.factionButton = makeStripButton(strip, 150, "", function()
        lib:SetWhereOwnFactionOnly(not lib:GetWhereOwnFactionOnly())
    end)
    win.factionButton:SetPoint("RIGHT", strip, "RIGHT", -4, 0)

    local summary = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("RIGHT", win.factionButton, "LEFT", -8, 0)
    summary:SetJustifyH("RIGHT")
    win.summary = summary
end

local function rowTooltip(win, entry, rowFrame)
    if win.mode == "search" then
        -- A search result is an item: show the game's own tooltip for it.
        if GameTooltip and GameTooltip.SetHyperlink then
            GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. entry.id)
            GameTooltip:Show()
        end
        return
    end
    if not (GameTooltip and entry.points and entry.points[1]) then return end
    GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
    GameTooltip:SetText(entry.name ~= "" and entry.name or entry.kind, 1, 1, 1)
    GameTooltip:AddLine(entry.zone, 1, 0.82, 0)
    for _, p in ipairs(entry.points) do
        GameTooltip:AddLine(("%.1f, %.1f"):format(p.x, p.y), 0.9, 0.9, 0.9)
    end
    if questbook() then GameTooltip:AddLine("Click to be guided there (Questbook).", 0.5, 0.8, 1) end
    GameTooltip:Show()
end

-- The list sits on its own frame anchored under the strip, as FGI's Scan tab does (rowsArea,
-- GUI/Tabs/Scan.lua). No timer is needed for the first paint: RowList hooks its parent's
-- OnSizeChanged and refreshes itself when the client first gives the new frame a size.
--
-- TWO LISTS, ONE PER MODE, each on its own area frame at the same anchors; hiding an area hides its
-- list. NOT one list switched with RowList:SetColumns: that raised in game on the first search
-- ("FontString:SetScript(): Doesn't have a "OnClick" script", LibAceGUIWidgets-RowList.lua:1368 --
-- its cell release calls SetScript("OnClick") on a text cell, which is a FontString). Two lists
-- never rebuild a column set, so they never reach that path.
local function listArea(parent)
    local area = CreateFrame("Frame", nil, parent)
    area:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -2 * (STRIP_H + STRIP_PAD))
    area:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    return area
end

local function buildList(W, win, parent)
    local leave = function() if GameTooltip then GameTooltip:Hide() end end
    win.mode = "where"
    win.rowsArea = listArea(parent)
    win.list = W.RowList:New(win.rowsArea, {
        rowCount = 12,
        columns  = whereColumns(),
        onRowClick = function(entry) lib:WhereTrack(entry) end,
        onRowEnter = function(entry, _, _, rowFrame) rowTooltip(win, entry, rowFrame) end,
        onRowLeave = leave,
    })
    win.searchArea = listArea(parent)
    win.searchArea:Hide()
    win.searchList = W.RowList:New(win.searchArea, {
        rowCount = 12,
        columns  = searchColumns(),
        onRowClick = function(entry) lib:OpenWhereWindow(entry.id) end,
        onRowEnter = function(entry, _, _, rowFrame) rowTooltip(win, entry, rowFrame) end,
        onRowLeave = leave,
    })
end

-- Show the list for `mode` and hide the other one. A list shown again after being hidden is
-- refreshed, since its area may have been resized while it was away.
local function setMode(win, mode)
    if win.mode == mode then return end
    win.mode = mode
    local search = mode == "search"
    if search then win.rowsArea:Hide() else win.rowsArea:Show() end
    if search then win.searchArea:Show() else win.searchArea:Hide() end
    ;(search and win.searchList or win.list):Refresh()
end

local function itemIcon(itemID)
    local get = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return get and get(itemID) or nil
end

--- Show the search results for `text` in the window, opening it if needed (with no item yet).
--- Returns the window, or nil (with a chat line) when LibAceGUIWidgets with RowList is missing.
--- A blank query goes back to the item's places. MINOR 36.
function lib:WhereSearch(text)
    local W = Widgets()
    if not (W and W.RowList) then
        self:_PricePrint("The Where to get it window needs LibAceGUIWidgets with RowList.")
        return nil
    end
    local win = self.whereWindow or self:CreateWhereWindow(W)
    win.frame:Show()
    local rows, capped = self:BuildWhereSearchRows(text)
    if #rows == 0 and tostring(text or ""):match("^%s*$") then
        if win.itemID then self:_PaintWhereWindow() end
        return win
    end
    setMode(win, "search")
    win.searchRows = rows
    win.summary:SetText(#rows == 0 and "No item matches"
        or (capped and (#rows .. "+ matches") or (#rows == 1 and "1 match" or (#rows .. " matches"))))
    win.searchList:SetData(rows)
    win.widget:SetStatusText("LibItemDB -- click an item to see where to get it")
    return win
end

function lib:_PaintWhereWindow()
    local win = self.whereWindow
    if not (win and win.itemID) then return false end
    setMode(win, "where")
    local ownOnly = self:GetWhereOwnFactionOnly()
    local rows = self:BuildWhereRows(win.itemID, ownOnly and playerFaction() or nil)
    win.rows = rows
    win.icon:SetTexture(itemIcon(win.itemID))
    win.itemLabel:SetText(self:GetLink(win.itemID) or self:GetName(win.itemID) or ("Item " .. win.itemID))
    win.summary:SetText(#rows == 0 and "No known source" or (#rows == 1 and "1 place" or (#rows .. " places")))
    win.factionButton.label:SetText(ownOnly and "My faction's vendors" or "Every vendor")
    win.list:SetData(rows)
    win.widget:SetStatusText("LibItemDB -- where to get it")
    return true
end

-- The stop icon, beside the window's "i": Questbook's universal stop, from the window that started
-- the guiding. Dressed through LibAceGUIWidgets' DressBottomRow, as Questbook dresses its own
-- (Questbook/Modules/Chrome.lua:145-158), and ONLY when Questbook offers StopTracking at the time
-- the window is built -- so a player without Questbook, or with one too old to stop from outside,
-- gets no icon and no shortened status bar. The window is built on first open, long after every
-- addon has loaded, and close only hides it (it is never released to AceGUI's pool), so one dress
-- lasts the session and no UndressBottomRow is needed. The tooltip text is read at hover.
local function buildStopIcon(W, win, widget)
    if not (W.DressBottomRow and questbook("StopTracking")) then return end
    local icons = W:DressBottomRow(widget, { {
        key = "stop", texture = STOP_TEXTURE, size = 20, y = 17,
        tipTitle = "Stop guiding",
        tipBody = function()
            local qb = questbook("StopTracking")
            return (qb and questbookTracking(qb)) and "Stop Questbook guiding you to a place."
                or "Questbook is not guiding you to anything."
        end,
        onClick = function() lib:WhereStopTracking() end,
    } })
    win.stopIcon = icons and icons.stop
    lib:_WhereShowStop()
end

function lib:CreateWhereWindow(W)
    local AceGUI = LibStub("AceGUI-3.0")
    local win = {}
    ---@diagnostic disable-next-line: param-type-mismatch
    local frame = AceGUI:Create("ClearFrame")
    frame:SetTitle("Where to get it")
    frame:SetInfoTooltip(HELP)
    local saved = store()
    saved.window = saved.window or {}
    if W.PersistWindow then
        W:PersistWindow(frame, saved.window, { width = 620, height = 340, minWidth = 480, minHeight = 220 })
    else
        frame:SetStatusTable(saved.window)
    end
    win.widget = frame
    ---@diagnostic disable-next-line: invisible
    win.frame = frame.frame
    local content = frame.content or win.frame
    buildSearchStrip(W, win, content)
    buildStrip(win, content)
    buildList(W, win, content)
    self.whereWindow = win
    buildStopIcon(W, win, frame)
    return win
end

--- Open the "Where to get it" window on an item (an id, a link, or anything with `item:<id>`).
--- Built on first use; reopening it on another item repaints the same window. Returns the window
--- table, or nil when there is no item id in `item`, or (with a chat line) when LibAceGUIWidgets
--- with RowList is not installed. MINOR 36.
function lib:OpenWhereWindow(item)
    local itemID = tonumber(item) or (type(item) == "string" and tonumber(item:match("item:(%d+)")))
    if not itemID then return nil end
    local W = Widgets()
    if not (W and W.RowList) then
        self:_PricePrint("The Where to get it window needs LibAceGUIWidgets with RowList.")
        return nil
    end
    local win = self.whereWindow or self:CreateWhereWindow(W)
    win.itemID = itemID
    win.frame:Show()
    self:_PaintWhereWindow()
    return win
end

-- ---------------------------------------------------------------------------
-- Opening it: Alt+click on any item, and a key for the item under the mouse
-- ---------------------------------------------------------------------------
--- The Alt+click hook's body. Every item button in the default UI -- bags, bank, loot, the character
--- panel, chat links, the auction house, and the bag addons that call it too -- sends a modified
--- click through HandleModifiedItemClick(link), which on Era acts on the CHATLINK (Shift) and
--- DRESSUP (Ctrl) modifiers only (Blizzard_ItemButton/Classic/ItemButtonTemplate.lua:137-159). So
--- one hook there catches Alt+click everywhere, and in the default UI Alt+click on an item has no
--- other job. Returns true when it opened the window.
function lib:_WhereOnModifiedClick(link)
    if not self:GetTooltipOption("altClick") then return false end
    if not self:IsWhereClick() then return false end
    return self:OpenWhereWindow(link) ~= nil
end

-- ---------------------------------------------------------------------------
-- WHICH click opens it -- the player's choice, Alt + Left Click by default
-- ---------------------------------------------------------------------------
-- A player on Discord, 2026-09-28: Alt+click "collides with gargul". The operator: "we make it
-- alt+click by default, but make it so the users can change it". Stored as the tooltip option
-- `whereClick` in WoW's own binding spelling -- modifiers in ALT, CTRL, SHIFT order, then the
-- button: "ALT-LeftButton", "ALT-CTRL-RightButton". The on/off switch stays `altClick`, so a player
-- who had switched it off before this existed is still off.
local CLICK_MODS = { "ALT", "CTRL", "SHIFT" }
local CLICK_BUTTONS = { LeftButton = true, RightButton = true, MiddleButton = true,
                        Button4 = true, Button5 = true }
local MOD_WORD = { ALT = "Alt", CTRL = "Ctrl", SHIFT = "Shift" }
local BUTTON_WORD = { LeftButton = "Click", RightButton = "Right-Click", MiddleButton = "Middle-Click",
                      Button4 = "Button 4", Button5 = "Button 5" }

--- Parse a click binding. Returns its canonical spelling and a set of its modifiers, or nil for
--- anything that is not one. At least ONE modifier is required: an unmodified click on an item is
--- the game's own (use, equip, pick up), and a binding that took it would break every bag.
--- MINOR 38.
--- @param binding string e.g. "ALT-LeftButton", "shift-ctrl-RightButton"
--- @return string|nil canonical e.g. "CTRL-SHIFT-RightButton"
--- @return table|nil mods { ALT = true, ... }
function lib:ParseClickBinding(binding)
    if type(binding) ~= "string" then return nil end
    local parts = {}
    for p in binding:gmatch("[^%-]+") do parts[#parts + 1] = p end
    local button = table.remove(parts)
    if not (button and CLICK_BUTTONS[button]) or #parts == 0 then return nil end
    local mods = {}
    for i = 1, #parts do
        local m = parts[i]:upper()
        if not MOD_WORD[m] or mods[m] then return nil end
        mods[m] = true
    end
    local out = {}
    for _, m in ipairs(CLICK_MODS) do
        if mods[m] then out[#out + 1] = m end
    end
    out[#out + 1] = button
    return table.concat(out, "-"), mods
end

--- The click binding as a player reads it: "Alt+Click", "Ctrl+Shift+Right-Click". nil for a
--- string that is not a binding.
--- @param binding string|nil defaults to the stored `whereClick`
--- @return string|nil
function lib:ClickBindingText(binding)
    local canonical = self:ParseClickBinding(binding or self:GetTooltipOption("whereClick"))
    if not canonical then return nil end
    local words = {}
    for p in canonical:gmatch("[^%-]+") do words[#words + 1] = MOD_WORD[p] or BUTTON_WORD[p] end
    return table.concat(words, "+")
end

--- Whether the click happening right now is the player's "Where to get it" click. The modifiers
--- must match EXACTLY -- Ctrl+Alt is not Alt -- so a combination another addon owns never opens
--- it by overlap. The button is compared too wherever the client can say which one was clicked
--- (GetMouseButtonClicked); where it cannot, the modifiers alone decide, because
--- HandleModifiedItemClick hands its hook the item link and nothing else.
--- @return boolean
function lib:IsWhereClick()
    local canonical, mods = self:ParseClickBinding(self:GetTooltipOption("whereClick"))
    if not canonical then return false end
    local down = { ALT = _G.IsAltKeyDown, CTRL = _G.IsControlKeyDown, SHIFT = _G.IsShiftKeyDown }
    for _, m in ipairs(CLICK_MODS) do
        local fn = down[m]
        local isDown = type(fn) == "function" and fn() and true or false
        if isDown ~= (mods[m] == true) then return false end
    end
    local clicked = type(_G.GetMouseButtonClicked) == "function" and _G.GetMouseButtonClicked()
    if type(clicked) == "string" and clicked ~= "" then
        return clicked == canonical:match("([^%-]+)$")
    end
    return true
end

--- Open the window on whatever item GameTooltip is showing -- the key binding's action. Returns the
--- window, or nil when no item is under the mouse. MINOR 36.
function lib:WhereHovered()
    if not (GameTooltip and GameTooltip.GetItem and GameTooltip:IsShown()) then return nil end
    local _, link = GameTooltip:GetItem()
    if not link then return nil end
    return self:OpenWhereWindow(link)
end

-- ONE hook for the life of the session, however many times a library upgrade reloads this file:
-- a hooksecurefunc cannot be removed, and a second one would open the window twice per click.
if hooksecurefunc and HandleModifiedItemClick and not lib._whereClickHooked then
    lib._whereClickHooked = true
    hooksecurefunc("HandleModifiedItemClick", function(link) lib:_WhereOnModifiedClick(link) end)
end

-- The key binding's labels in the game's Key Bindings panel (Bindings.xml declares the binding).
_G.BINDING_HEADER_LIBITEMDB = "LibItemDB"
_G.BINDING_NAME_LIBITEMDB_WHERE = "Where to get the item under the mouse"
