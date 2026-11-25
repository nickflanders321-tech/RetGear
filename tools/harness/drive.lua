-- Drives the add-on after login (run.lua's default; --login-only skips it):
--   1. every event the add-on listens for, with plausible arguments
--   2. every /wp command (found in the source and the docs, so new commands are covered without a list to update)
--   3. after each command, every handler on whatever is on screen: clicks (left, right, shift), mouse-over,
--      mouse wheel, drag, typing in edit boxes, sliders; then the windows those open, and so on
--   4. the hooks the add-on put on the game's windows, tooltips and functions
--   5. per-frame updates (OnUpdate) for a few simulated seconds between all of these
--   6. the events again (now with windows open), then logout
local D = {}

local function readFile(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end

-- ---------------------------------------------------------------------------
-- Event arguments (classic-era order, which WoW Forever uses)
-- ---------------------------------------------------------------------------
local LINK = "|cffffffff|Hitem:2589::::::::1:::::::|h[Linen Cloth]|h|r"
local FRIEND = "Friend-Harness"
local function chat(text) return text, FRIEND, "", "", "Friend", "", 0, 0, "", 0, 1, "Player-0000-00000002" end
local PAYLOAD = {
  PLAYER_LEVEL_UP = function(W) return W.me.level + 1, 10, 1, 0, 1, 1, 1, 1, 1 end,
  PLAYER_XP_UPDATE = function() return "player" end,
  QUEST_ACCEPTED = function() return 1, 783 end,
  QUEST_TURNED_IN = function() return 783, 80, 0 end,
  QUEST_REMOVED = function() return 783 end,
  QUEST_LOG_CRITERIA_UPDATE = function() return 783, 1, 1, 1 end,
  QUEST_WATCH_UPDATE = function() return 1 end,
  CHAT_MSG_LOOT = function() return chat("You receive loot: " .. LINK .. ".") end,
  CHAT_MSG_MONEY = function() return chat("You loot 5 Copper") end,
  CHAT_MSG_SYSTEM = function() return chat("You are now away.") end,
  CHAT_MSG_SKILL = function() return chat("Your skill in Fishing has increased to 2.") end,
  CHAT_MSG_COMBAT_XP_GAIN = function() return chat("Kobold Vermin dies, you gain 45 experience.") end,
  CHAT_MSG_COMBAT_FACTION_CHANGE = function() return chat("Your reputation with Orgrimmar has increased by 25.") end,
  CHAT_MSG_CHANNEL_NOTICE = function() return "YOU_CHANGED", FRIEND, "", "1. General", "", "", 0, 1, "General" end,
  UI_ERROR_MESSAGE = function() return 51, "Inventory is full." end,
  UI_INFO_MESSAGE = function() return 0, "Kobold Vermin slain: 1/10" end,
  BAG_UPDATE = function() return 0 end,
  ITEM_LOCK_CHANGED = function() return 0, 1 end,
  GET_ITEM_INFO_RECEIVED = function() return 2589, true end,
  ITEM_DATA_LOAD_RESULT = function() return 2589, true end,
  PLAYER_EQUIPMENT_CHANGED = function() return 16, false end,
  PLAYER_ENTERING_WORLD = function() return false, true end,
  LOOT_OPENED = function() return false end,
  LOOT_READY = function() return false end,
  LOOT_SLOT_CLEARED = function() return 1 end,
  TAXIMAP_OPENED = function() return 0 end,
  MODIFIER_STATE_CHANGED = function() return "LSHIFT", 1 end,
  UNIT_SPELLCAST_SUCCEEDED = function() return "player", "Cast-3-0-0-0-7620-0", 7620 end,
  UNIT_SPELLCAST_START = function() return "player", "Cast-3-0-0-0-7620-0", 7620 end,
  UNIT_SPELLCAST_STOP = function() return "player", "Cast-3-0-0-0-7620-0", 7620 end,
  UNIT_SPELLCAST_CHANNEL_START = function() return "player", "Cast-3-0-0-0-7620-0", 7620 end,
  UNIT_SPELLCAST_CHANNEL_STOP = function() return "player", "Cast-3-0-0-0-7620-0", 7620 end,
  CURSOR_CHANGED = function() return false, 0, 0 end,
  SKILL_LINES_CHANGED = function() end,
  ACHIEVEMENT_EARNED = function() return 6, false end,
  CRITERIA_UPDATE = function() end,
  UPDATE_FACTION = function() end,
  PLAYER_MONEY = function() end,
}
-- the game's other add-ons and its load-on-demand windows: what they create when they load
local LOD = {
  Blizzard_AuctionUI = { "AuctionFrame", "BrowseName" },
  Blizzard_AuctionHouseUI = { "AuctionHouseFrame" },
  Blizzard_TalentUI = { "PlayerTalentFrame" },
  Blizzard_TradeSkillUI = {},
  Blizzard_CraftUI = {},
}
local function args(W, ev)
  local p = PAYLOAD[ev]
  if p then return p(W) end
  if ev == "UNIT_SPELLCAST_SENT" then return "player", "", "Cast-3-0-0-0-7620-0", 7620 end
  if ev:find("^UNIT_SPELLCAST_") then return "player", "Cast-3-0-0-0-7620-0", 7620 end
  if ev:find("^UNIT_") then return "player" end
  if ev == "CHAT_MSG_ADDON" or ev == "CHAT_MSG_ADDON_LOGGED" then return nil end   -- sent per prefix below
  if ev:find("^CHAT_MSG_") then return chat("hello") end
end

-- What firing an event changes in the fake game, before the add-on hears it.
local function apply(W, ev, a1)
  if ev == "PLAYER_REGEN_DISABLED" then W.combat = true
  elseif ev == "PLAYER_REGEN_ENABLED" then W.combat = false
  elseif ev == "PLAYER_LEVEL_UP" then W.me.level = a1 end
end

-- logout comes at the end; login and saved variables only ever come once (run.lua sends them)
local LAST = { PLAYER_LOGOUT = true, PLAYER_LEAVING_WORLD = true, PLAYER_CAMPING = true, PLAYER_QUITING = true,
  PLAYER_LOGIN = true, VARIABLES_LOADED = true }

function D.fireAll(W, step)
  local list = {}
  for ev in pairs(W.registered()) do if not LAST[ev] then list[#list + 1] = ev end end
  table.sort(list)
  -- combat last, and in pairs, so the rest isn't all "in combat"
  for _, ev in ipairs(list) do
    if ev ~= "PLAYER_REGEN_DISABLED" and ev ~= "PLAYER_REGEN_ENABLED" and ev ~= "ADDON_LOADED" then
      if ev == "CHAT_MSG_ADDON" or ev == "CHAT_MSG_ADDON_LOGGED" then
        -- every prefix the add-on registered: an empty message, a nonsense one, and one from the player
        for _, prefix in ipairs(W.prefixes()) do
          for _, m in ipairs({ "", "x", "\1\2garbage:1:2:3", string.rep("9", 255) }) do
            W.context = ev .. " (" .. prefix .. ")"
            W.fire(ev, prefix, m, "WHISPER", FRIEND)
          end
          W.fire(ev, prefix, "hello", "PARTY", W.me.name .. "-" .. W.me.realm)
        end
      else
        local a = { args(W, ev) }
        apply(W, ev, a[1])
        W.context = ev
        W.fire(ev, unpack(a))
      end
      step(0.25)
    end
  end
  for name, frames in pairs(LOD) do
    for _, n in ipairs(frames) do W.makeGameFrame(n) end
    W.context = "ADDON_LOADED (" .. name .. ")"
    W.fire("ADDON_LOADED", name, false)
  end
  for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    apply(W, ev); W.context = ev; W.fire(ev); step(1)
  end
end

function D.logout(W)
  for _, ev in ipairs({ "PLAYER_CAMPING", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT" }) do W.context = ev; W.fire(ev) end
end

-- ---------------------------------------------------------------------------
-- Slash commands, found in the source and the docs
-- ---------------------------------------------------------------------------
local PLACEHOLDER = { ["%[item%]"] = LINK, ["<item>"] = LINK, ["%[name%]"] = "Friend", ["<name>"] = "Friend", ["%[zone%]"] = "Durotar" }
local function clean(c)
  for k, v in pairs(PLACEHOLDER) do c = c:gsub(k, v) end
  c = c:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  c = c:gsub("[%[%]<>]", "")
  return (c:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- The words a file's slash handler compares the command with: cmd == "next", CMDS = { next = true }, ...
local function handlerWords(src, out)
  for w in src:gmatch("==%s*\"([%a][%w]*)\"") do out[w:lower()] = true end
  for w in src:gmatch("cmd:find%(\"%^([%a][%w]*)") do out[w:lower()] = true end
end

function D.commands(W, files)
  local hasWp = false
  for _, s in ipairs(W.slashNames()) do if s == "/wp" then hasWp = true end end
  if not hasWp then return {}, W.slashNames() end
  local found, order = {}, {}
  local function add(c)
    c = clean(c)
    if c ~= "" and not found[c] then found[c] = true; order[#order + 1] = c end
  end
  add("")          -- /wp on its own: the main window
  add("help")
  local words = {}
  for _, f in ipairs(files) do
    local src = readFile(f)
    if src then
      -- "/wp next", "/wp goto 45 60 Name" in help text and messages
      for c in src:gmatch("/wp ([%w][%w%. ]*)") do add(c) end
      if src:find("SlashCmdList%.WAYPATH") then handlerWords(src, words) end
    end
  end
  for _, doc in ipairs({ "README.md", "FEATURES.md" }) do
    local src = readFile(doc)
    if src then for c in src:gmatch("/wp ([%w][%w%. ]*)") do add(c) end end
  end
  local list = {}
  for w in pairs(words) do list[#list + 1] = w end
  table.sort(list)
  for _, w in ipairs(list) do add(w) end
  -- the ones that throw everything away or switch the add-on off go last
  local tail = {}
  local keep = {}
  for _, c in ipairs(order) do
    if c:find("^reset") or c:find("^cardsonly") or c:find("^wipe") or c:find("reset$") then tail[#tail + 1] = c else keep[#keep + 1] = c end
  end
  for _, c in ipairs(tail) do keep[#keep + 1] = c end
  -- the other slash commands the add-on registers (SLASH_WAYPATHMAP1...), with no arguments and with "help"
  local extra = {}
  for _, s in ipairs(W.slashNames()) do
    if s ~= "/wp" and s ~= "/waypath" and s ~= "/rg" and s ~= "/retgear" then extra[#extra + 1] = s end
  end
  return keep, extra
end

-- ---------------------------------------------------------------------------
-- Everything on screen: every handler, once each
-- ---------------------------------------------------------------------------
local EXERCISE = {
  -- script, arguments, what to do first
  { "OnEnter", function() return true end },
  { "OnLeave", function() return true end },
  { "OnClick", function() return "LeftButton", false end, "click" },
  { "OnClick", function() return "RightButton", false end, "click", "right" },
  { "OnClick", function() return "LeftButton", false end, "click", "shift" },
  { "OnDoubleClick", function() return "LeftButton" end },
  { "OnMouseDown", function() return "LeftButton" end },
  { "OnMouseUp", function() return "LeftButton", true end },
  { "OnMouseWheel", function() return -1 end },
  { "OnMouseWheel", function() return 1 end, nil, "up" },
  { "OnDragStart", function() return "LeftButton" end },
  { "OnDragStop", function() end },
  { "OnReceiveDrag", function() end },
  { "OnTextChanged", function() return true end, "type" },
  { "OnEnterPressed", function() end, "type" },
  { "OnEscapePressed", function() end },
  { "OnEditFocusGained", function() end },
  { "OnEditFocusLost", function() end },
  { "OnTabPressed", function() end },
  { "OnChar", function() return "a" end },
  { "OnKeyDown", function() return "ESCAPE" end },
  { "OnValueChanged", function(f) local lo, hi = f:GetMinMaxValues(); return ((lo or 0) + (hi or 0)) / 2, true end, "value" },
  { "OnVerticalScroll", function() return 10 end },
  { "OnSizeChanged", function() return 300, 200 end },
  { "OnHyperlinkClick", function() return "item:2589", "[Linen Cloth]", "LeftButton" end },
  { "OnHyperlinkEnter", function() return "item:2589", "[Linen Cloth]" end },
  { "OnHyperlinkLeave", function() end },
}

function D.crawl(W, step, budget)
  local done = W.exercised
  local calls = 0
  for _ = 1, 50 do                  -- rounds: what one round opens, the next round exercises
    local targets = {}
    for _, f in ipairs(W.frames()) do
      if not W.isOwned(f) and f:IsVisible() and W.hasScripts(f) then targets[#targets + 1] = f end
    end
    local any = false
    for _, f in ipairs(targets) do
      for _, e in ipairs(EXERCISE) do
        local script, mk, prep, variant = e[1], e[2], e[3], e[4]
        local key = script .. (variant or "")
        local seen = done[f]
        if not seen then seen = {}; done[f] = seen end
        if not seen[key] and W.hasScript(f, script) and f:IsVisible() then
          seen[key] = true
          any = true
          calls = calls + 1
          if calls > budget then return calls, true end
          if prep == "type" and f:GetObjectType() == "EditBox" then f:SetText("test") end
          if variant == "shift" then W.mods.shift = true end
          local a = { mk(f) }
          if prep == "value" and type(a[1]) == "number" then W.setValueQuiet(f, a[1]) end
          if prep ~= "click" or f:IsEnabled() then W.runScript(f, script, unpack(a)) end
          W.mods.shift = false
          step(0.1)
        end
      end
    end
    if not any then break end
  end
  return calls, false
end

-- The add-on's hooks on the game: its windows (shown and hidden), tooltips, and hooked functions.
function D.gameHooks(W, step)
  for _, f in ipairs(W.frames()) do
    if W.isOwned(f) and W.hasHooks(f) then
      local name = W.describe(f)
      W.context = "showing " .. name
      if f:IsShown() then f:Hide() end
      f:Show(); step(0.5)
      for _, e in ipairs(EXERCISE) do
        if W.hasHook(f, e[1]) and e[1] ~= "OnClick" then W.runScript(f, e[1], e[2](f)) end
      end
      if f:GetObjectType() == "GameTooltip" then
        f:SetOwner(W.G.UIParent, "ANCHOR_NONE")
        f:SetHyperlink("item:2589")
        W.runScript(f, "OnTooltipSetItem")
        W.runScript(f, "OnTooltipSetUnit")
        W.runScript(f, "OnTooltipCleared")
      end
      W.context = "hiding " .. name
      f:Hide(); step(0.2)
    end
  end
  for _, h in ipairs(W.tooltipPostCalls()) do
    W.context = "TooltipDataProcessor post-call"
    W.call("TooltipDataProcessor post-call", h.fn, W.G.GameTooltip, { type = h.type, id = 2589, lines = {} })
  end
  for _, name in ipairs(W.hookedGlobals()) do
    W.context = "the game calling " .. name
    local fn = W.G[name]
    if type(fn) == "function" then W.call("the game calling " .. name, fn) end
    step(0.1)
  end
end

return D
