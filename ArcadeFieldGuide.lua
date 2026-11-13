-- Waypath+ cards: the Field Guide. Rares and world bosses are earned out in the world, never from a pack.
--   Sighting a rare (your target, your mouse or its nameplate) marks it "sighted" on its zone's page.
--   Killing it (you or your group got the tag, and its corpse is yours to loot) gives you its card with a kill stamp:
--   who, where and when. Kill it again for a better print: 2 kills a Rare print, 4 a Holo, 8 a Full art.
--   A world boss gives a Witness card (stamped with your guild) to everyone whose raid had the tag when it died.
-- (The combat log is closed to add-ons on this client: kills are read from the corpse, after the fight.)
local _, RG = ...

table.insert(RG.OPTIONS, { key = "fieldGuideToasts", label = "Cards: tell me when a rare for my Field Guide is nearby", default = true })

local FIELD = RG.ARCADE_FIELD_NPC or {}
local OF = RG.ARCADE_FIELD_OF or {}
local KILLS_FOR = { 1, 2, 4, 8 }        -- kills for each print: Common, Rare, Holo, Full art
local WITNESS_FOR = { 0, 0, 1, 3 }      -- a Witness card starts Holo; the third time it's Full art
local byCard = {}                       -- card name -> { creature ids }
for nid, e in pairs(FIELD) do byCard[e[1]] = byCard[e[1]] or {}; table.insert(byCard[e[1]], nid) end
for _, l in pairs(byCard) do table.sort(l) end

local function U() return RG.ArcadeUI end
local function store() local u = U(); return u and u.store and u.store() end
local function book(a) a.field = a.field or {}; return a.field end
local function now() return (time and time()) or 0 end
local function safe(fn, ...) local ok, v = pcall(fn, ...); if ok and v ~= nil and not (RG.IsSecret and RG.IsSecret(v)) then return v end end
local function npcOf(unit)
  local g = UnitGUID and safe(UnitGUID, unit)
  if type(g) ~= "string" then return nil end
  local kind, _, _, _, _, id = strsplit("-", g)
  if kind ~= "Creature" then return nil end
  return tonumber(id), g
end
local function zoneName()
  local m = C_Map and C_Map.GetBestMapForUnit and safe(C_Map.GetBestMapForUnit, "player")
  local info = m and C_Map.GetMapInfo and safe(C_Map.GetMapInfo, m)
  return (info and info.name) or (GetRealZoneText and safe(GetRealZoneText)) or "?"
end
local function finishFor(kills, witness)
  local need, f = witness and WITNESS_FOR or KILLS_FOR, 1
  for i = 1, 4 do if kills >= need[i] then f = i end end
  return f
end
local function printName(f) local u = U(); return (u and u.FINISH[f] and u.FINISH[f][1]) or "Common" end

-- ---------------------------------------------------------------------------
-- Seen and slain
-- ---------------------------------------------------------------------------
local lastToast = {}      -- card -> time of the last "sighted" toast this session
local engaged = {}        -- corpse id (GUID) -> creature id: field creatures seen lately, checked for a kill after the fight
local credited = {}       -- GUIDs already counted this session

local function sighted(nid, guid)
  local e = FIELD[nid]; if not e then return end
  if guid then engaged[guid] = nid end
  local a = store(); if not (a and RG.db and RG.db.arcade ~= false) then return end
  local f = book(a)
  local r = f[e[1]]
  local first = not (r and r.seen)
  if not r then r = {}; f[e[1]] = r end
  if first then r.seen = now() end
  if e[6] ~= "r" or (r.kills or 0) > 0 then return end
  -- tell the player once a session per rare (and always the first time)
  local t = GetTime and GetTime() or 0
  if lastToast[e[1]] and t - lastToast[e[1]] < 3 * 3600 then return end
  lastToast[e[1]] = t
  if RG.Toast and RG.Opt and RG.Opt("fieldGuideToasts") ~= false then
    RG.Toast(first and "Rare sighted" or "Rare nearby", e[1] .. ": kill it for its Field Guide card (" .. e[2]:gsub("^Field Guide: ", "") .. ").",
      "Interface\\Icons\\INV_Misc_Book_09", "See the page", function() if RG.ArcadeOpenAlbum then RG.ArcadeOpenAlbum(e[2]) end end, 8)
  end
end

local function slain(nid, guid)
  local e = FIELD[nid]; if not e then return end
  if guid then if credited[guid] then return end; credited[guid] = true; engaged[guid] = nil end
  local a = store(); if not (a and RG.db and RG.db.arcade ~= false) then return end
  -- (a corpse counts once, even across a reload)
  a.fieldGuids = a.fieldGuids or {}
  if guid then
    for _, g in ipairs(a.fieldGuids) do if g == guid then return end end
    table.insert(a.fieldGuids, guid); while #a.fieldGuids > 60 do table.remove(a.fieldGuids, 1) end
  end
  local f = book(a)
  local r = f[e[1]] or {}; f[e[1]] = r
  r.seen = r.seen or now()
  r.kills = (r.kills or 0) + 1
  local witness = e[6] == "w"
  if r.kills == 1 then
    r.who = (UnitName and safe(UnitName, "player")) or "?"
    r.where = zoneName()
    r.when = date and date("%d %b %Y") or ""
    if witness then r.guild = (IsInGuild and IsInGuild() and GetGuildInfo and safe(GetGuildInfo, "player")) or nil end
  end
  local fin = finishFor(r.kills, witness)
  if RG.ArcadeGiveCard then RG.ArcadeGiveCard(e[1], fin) end
  if RG.ArcadeSound then RG.ArcadeSound("reward") end
  local nextAt
  for i = fin + 1, 4 do local need = (witness and WITNESS_FOR or KILLS_FOR)[i]; if need > r.kills then nextAt = { i, need }; break end end
  local text = (witness and "You witnessed " or "Slain: ") .. e[1]:gsub("^Witness: ", "") .. ". Its card is yours (" .. printName(fin) .. ")" ..
    (nextAt and (", " .. (nextAt[2] - r.kills) .. " more for " .. printName(nextAt[1])) or "") .. "."
  if RG.Toast then
    RG.Toast(witness and "Witness card" or "Field Guide", text, "Interface\\Icons\\INV_Misc_Book_09", "See it",
      function() if RG.ArcadeOpenAlbum then RG.ArcadeOpenAlbum(e[2]) end end, 10)
  elseif RG.Print then RG.Print(text) end
end
RG.ArcadeFieldSlain, RG.ArcadeFieldSighted = slain, sighted

local function look(unit)
  local nid, guid = npcOf(unit)
  if nid and FIELD[nid] then sighted(nid, guid) end
end
-- after a fight: a field creature you saw, dead, and yours (not tapped by someone else) is a kill
local function sweep()
  local units = { "target", "mouseover", "focus", "boss1", "boss2", "boss3", "boss4", "boss5" }
  for i = 1, 40 do units[#units + 1] = "nameplate" .. i end
  for _, u in ipairs(units) do
    local nid, guid = npcOf(u)
    if nid and FIELD[nid] and guid and not credited[guid] then
      local dead = UnitIsDead and safe(UnitIsDead, u)
      local denied = UnitIsTapDenied and safe(UnitIsTapDenied, u)
      if dead == true and denied == false then slain(nid, guid) end
    end
  end
end
-- looting a corpse: whose it was (the game says which corpse each item came from)
local function looted()
  if not (GetNumLootItems and GetLootSourceInfo) then return end
  for i = 1, (safe(GetNumLootItems) or 0) do
    local src = { pcall(GetLootSourceInfo, i) }
    if src[1] then
      for k = 2, #src, 2 do
        local g = src[k]
        if type(g) == "string" and not (RG.IsSecret and RG.IsSecret(g)) then
          local kind, _, _, _, _, id = strsplit("-", g)
          id = tonumber(id)
          if kind == "Creature" and id and FIELD[id] then slain(id, g) end
        end
      end
    end
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "PLAYER_REGEN_ENABLED", "LOOT_OPENED", "LOOT_READY", "UNIT_FLAGS" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_TARGET_CHANGED" then pcall(look, "target"); pcall(sweep)
  elseif event == "UPDATE_MOUSEOVER_UNIT" then pcall(look, "mouseover")
  elseif event == "NAME_PLATE_UNIT_ADDED" then pcall(look, unit)
  elseif event == "UNIT_FLAGS" then if unit == "target" and not (InCombatLockdown and InCombatLockdown()) then pcall(sweep) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    pcall(sweep)
    if C_Timer and C_Timer.After then C_Timer.After(1.5, function() pcall(sweep) end) end
  else pcall(looted) end
end)

-- ---------------------------------------------------------------------------
-- The Album: labels, tooltips, the page header and "show on map"
-- ---------------------------------------------------------------------------
local function rec(name) local a = store(); return a and a.field and a.field[name] end
local function spot(name)
  local l = byCard[name]; local e = l and FIELD[l[1]]
  if e and e[3] and e[3] > 0 then return { e[3], e[4], e[5], name:gsub("^Witness: ", "") } end
end
function RG.ArcadeFieldLabel(c)
  local r = rec(c.name)
  if (c.text or ""):find("witnessed") then
    return r and r.seen and "SEEN\nNOT WITNESSED" or "NOT WITNESSED", r and r.seen and { 1, 0.82, 0.45 } or { 0.75, 0.72, 0.68 }
  end
  if r and r.seen then return "SIGHTED\nHUNT IT", { 1, 0.82, 0.45 } end
  return "NOT SEEN\nRARE", { 0.75, 0.72, 0.68 }
end
local function fieldTip(cd, page)
  local fp = OF[cd.name]
  if not fp and not (page and page:find("^Field Guide")) then return false end
  local r = rec(cd.name)
  local l = byCard[cd.name]; local e = l and FIELD[l[1]]
  local witness = (cd.text or ""):find("witnessed")
  if e then
    local where = (fp or page or ""):gsub("^Field Guide: ", "")
    if witness then GameTooltip:AddLine("A world boss. Be in the fight when it dies (your raid needs the tag) to earn this card.", 0.55, 0.8, 1, true)
    else GameTooltip:AddLine("A rare in " .. where .. ". Kill it (you or your group get the tag) for its card.", 0.55, 0.8, 1, true) end
    if e[3] and e[3] > 0 then GameTooltip:AddLine(string.format("Spawns around %.0f, %.0f%s", e[4], e[5], #l > 1 and (" and " .. (#l - 1) .. " other place" .. (#l > 2 and "s" or "")) or ""), 0.8, 0.8, 0.8) end
  end
  if r and r.seen then GameTooltip:AddLine("Sighted " .. (date and date("%d %b %Y", r.seen) or ""), 1, 0.82, 0.45) end
  if not cd.field then GameTooltip:AddLine("Also in regular packs", 0.6, 0.6, 0.6) end
  return true
end
RG.ArcadeTipHooks = RG.ArcadeTipHooks or {}
table.insert(RG.ArcadeTipHooks, fieldTip)
local pinCursor = {}
function RG.ArcadeFieldClick(name)
  if not (name and name:find("^Field Guide")) then return false end
  local sets = U() and U().getSets() or {}
  local st
  for _, s in ipairs(sets) do if s.name == name then st = s end end
  if not st then return true end
  local a = store()
  local todo = {}
  for _, c in ipairs(st.cards) do if (U().owned(a, c.id) or 0) == 0 and spot(c.name) then todo[#todo + 1] = c.name end end
  if #todo == 0 then for _, c in ipairs(st.cards) do if spot(c.name) then todo[#todo + 1] = c.name end end end
  if #todo == 0 then return true end
  pinCursor[name] = (pinCursor[name] or 0) % #todo + 1
  local wp = spot(todo[pinCursor[name]])
  if RG.PinWaypoint then RG.PinWaypoint(wp) end
  return true
end
function RG.ArcadeFieldAlbum(st, frame, parts, nextText)
  local a = store()
  local slain, seen = 0, 0
  for _, c in ipairs(st.cards) do
    if (U().owned(a, c.id) or 0) > 0 then slain = slain + 1 end
    local r = rec(c.name); if r and r.seen then seen = seen + 1 end
  end
  local paid = ((a and a.setStage) or {})[st.name] or 0
  local world = st.zone == "World bosses"
  frame.albTitle:SetText("|cff9fd8a0FIELD GUIDE|r  " .. (st.zone or st.name) .. "  |cffa89bc9·  " .. slain .. " of " .. #st.cards .. (world and " witnessed" or " slain") .. "|r" .. (paid >= 1 and "  |cffffd24aExplorer|r" or ""))
  frame.albNext:ClearAllPoints()
  frame.albNext:SetPoint("LEFT", frame.albTitle, "LEFT", math.min(frame.albTitle:GetStringWidth() or 300, 430) + 10, 0)
  -- (two short lines: a longer one wraps into the tabs below it)
  frame.sub:SetText(#st.cards .. " cards   ·   " .. seen .. " sighted     " .. table.concat(parts, "     ") .. "\n|cffa89bc9" ..
    (world and "Be in the fight when one dies" or "Kill them to earn them: never in packs") .. "|r")
  frame.albOpen:SetText(world and "World boss on the map" or "Next rare on the map"); frame.albOpen:SetEnabled(true); frame.albOpen:Show()
end

-- the kill stamp, across the foot of the card's picture
local stamps = setmetatable({}, { __mode = "k" })
local function stamp(w, card, finish)
  local s = stamps[w]
  if not card or not finish then if s then s:Hide() end return end
  local r = (OF[card.name] or card.field) and rec(card.name)
  if not (r and (r.kills or 0) > 0 and r.when) then if s then s:Hide() end return end
  local u = w.u or 1
  if (w.cw or 0) < 90 then if s then s:Hide() end return end
  if not s then
    s = CreateFrame("Frame", nil, w)
    s.bg = s:CreateTexture(nil, "OVERLAY"); s.bg:SetAllPoints(); s.bg:SetColorTexture(0.05, 0.04, 0.03, 0.72)
    s.edge = s:CreateTexture(nil, "OVERLAY"); s.edge:SetHeight(1); s.edge:SetPoint("TOPLEFT"); s.edge:SetPoint("TOPRIGHT")
    s.t = s:CreateFontString(nil, "OVERLAY"); s.t:SetPoint("CENTER"); s.t:SetJustifyH("CENTER")
    stamps[w] = s
  end
  s:SetFrameLevel((w:GetFrameLevel() or 1) + 6)
  s:ClearAllPoints()
  s:SetPoint("BOTTOMLEFT", w.artClip, "BOTTOMLEFT", 0, 0); s:SetPoint("BOTTOMRIGHT", w.artClip, "BOTTOMRIGHT", 0, 0)
  local big = (w.cw or 0) >= 200
  s:SetHeight((big and 30 or 18) * math.max(0.6, u))
  local witness = (card.text or ""):find("witnessed")
  s.edge:SetColorTexture(witness and 1 or 0.62, witness and 0.82 or 0.85, witness and 0.4 or 0.6, 0.9)
  local font = (RG.FONTS and (RG.FONTS.semibold or RG.FONTS.medium)) or "Fonts\\FRIZQT__.TTF"
  pcall(s.t.SetFont, s.t, font, math.max(7, (big and 10 or 7.5) * math.max(0.7, u)), "")
  s.t:SetTextColor(witness and 1 or 0.86, witness and 0.88 or 0.95, witness and 0.6 or 0.82)
  local line1 = (witness and "WITNESSED" or "SLAIN") .. "  ·  " .. (r.when or "")
  local line2 = witness and (r.guild and ("<" .. r.guild .. ">") or (r.who or "")) or ((r.who or "") .. "  ·  " .. (r.where or ""))
  s.t:SetText(big and (line1 .. "\n" .. line2) or line1)
  s:Show()
end

RG.ArcadeCardHooks = RG.ArcadeCardHooks or {}
table.insert(RG.ArcadeCardHooks, stamp)

-- Explorer badges: Field Guide pages with every card (bronze)
function RG.ArcadeExplorerBadges()
  local a = store(); if not a then return 0, 0 end
  local have, all = 0, 0
  for _, p in ipairs(RG.ARCADE_FIELD_PAGES or {}) do
    all = all + 1
    if ((a.setStage or {})[p[1]] or 0) >= 1 then have = have + 1 end
  end
  return have, all
end
