-- Waypath+ cards: a Mythic for every dungeon. Each dungeon's toughest boss gets a Mythic print of its own: the same
-- creature, in that dungeon's own picture, inside a turning rainbow edge. It only comes from that dungeon's packs, in
-- the Mythic slot (about as often as a Mythic in any pack), and opens with the Mythic moment.
--   Not part of the set's bronze, silver and gold (a chase card, never a wall); the Album page shows whether you have it.
--   Like every Mythic: one per deck in the Arena, never traded, crafted or sold.
-- Raids and holidays come later (their packs keep the six Mythics for now).
local _, RG = ...

-- the dungeon's toughest boss: highest rarity, then highest level, then first listed (the data lists the last boss first)
local rowOf = {}
for _, r in ipairs(RG.ARCADE_DATA or {}) do if r[1] == 2 and not rowOf[r[2]] then rowOf[r[2]] = r end end
local function level(r) return tonumber((r[5] or ""):match("level (%d+)")) or 0 end

-- where the data's pick isn't the dungeon's real last boss
local PICK = { ["Maraudon"] = "Princess Theradras", ["Scholomance"] = "Darkmaster Gandling", ["The Temple of Atal'Hakkar"] = "Shade of Eranikus" }

RG.ARCADE_SET_MYTHIC = {}       -- dungeon -> the Mythic's card key
RG.ARCADE_SET_MYTHIC_OF = {}    -- card key -> dungeon
for _, d in ipairs(RG.ARCADE_DUNGEONS or {}) do
  if not d.raid and not d.holiday then
    local best
    for _, n in ipairs(d[5] or {}) do
      local r = rowOf[n]
      if r and (r[5] or ""):find("boss", 1, true) and (not best or r[3] > best[3] or (r[3] == best[3] and level(r) > level(best))) then best = r end
    end
    local want = PICK[d[1]] and rowOf[PICK[d[1]]]
    if want then for _, n in ipairs(d[5] or {}) do if n == want[2] then best = want end end end
    if best then
      local key = "Mythic: " .. d[1]
      -- { kind, name, tier, ref, text, dungeon, field, bound, key }
      RG.ARCADE_DATA[#RG.ARCADE_DATA + 1] = { 2, best[2], 7, best[4], "Mythic. The heart of " .. d[1] .. ".", d[1], nil, true, key }
      RG.ARCADE_SET_MYTHIC[d[1]] = key
      RG.ARCADE_SET_MYTHIC_OF[key] = d[1]
    end
  end
end

-- ---------------------------------------------------------------------------
-- The look: its dungeon's picture behind the creature, and an edge and glow that run through every colour
-- ---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\Waypath\\Media\\Arcade\\"
local live = setmetatable({}, { __mode = "k" })   -- card widgets showing a dungeon Mythic now
local function placeBackdrop(w, dn)
  local pl = RG.ARCADE_PLACE and RG.ARCADE_PLACE[dn]
  local scr = RG.ARCADE_PLACE_FILE and RG.ARCADE_PLACE_FILE[dn]
  local bg = rawget(w, "smBg")
  if not bg then
    bg = w.artClip:CreateTexture(nil, "BACKGROUND", nil, 7)
    bg:SetAllPoints(w.artClip)
    w.smBg = bg
  end
  local aw, ah = w.aw or 1, w.ah or 1
  local want = aw / math.max(1, ah)   -- the art window's shape: the picture is cropped to it
  if pl then
    local col, row = pl[2] % 8, math.floor(pl[2] / 8)
    local x0, y0, cw, ch = col * 120 / 1024, row * 84 / 1024, 120 / 1024, 84 / 1024
    local have = 120 / 84
    if have > want then local cut = (cw - cw * want / have) / 2; bg:SetTexCoord(x0 + cut, x0 + cw - cut, y0, y0 + ch)
    else local cut = (ch - ch * have / want) / 2; bg:SetTexCoord(x0, x0 + cw, y0 + cut, y0 + ch - cut) end
    bg:SetTexture(MEDIA .. "Places" .. pl[1])
  elseif scr then
    bg:SetTexture(scr[1])
    local have = (scr[2] == 1) and (16 / 9) or (4 / 3)
    if have > want then local cut = (1 - want / have) / 2; bg:SetTexCoord(cut, 1 - cut, 0, 1) else local cut = (1 - have / want) / 2; bg:SetTexCoord(0, 1, cut, 1 - cut) end
  else bg:Hide(); return false end
  bg:SetVertexColor(1, 1, 1, 1); bg:Show()
  return true
end

RG.ArcadeCardHooks = RG.ArcadeCardHooks or {}
table.insert(RG.ArcadeCardHooks, function(w, card, finish)
  local bg = rawget(w, "smBg")
  local dn = card and finish and RG.ARCADE_SET_MYTHIC_OF[card.key or ""]
  if not dn then
    if bg then bg:Hide() end
    live[w] = nil
    return
  end
  local u = RG.ArcadeUI
  -- the dungeon's own picture instead of the drawn sky behind the creature
  if placeBackdrop(w, dn) and u and rawget(w, "scn") then u.hideScene(w.scn) end
  w.spot:Hide()
  -- the type line, and a Mythic's glow: brighter, every colour, sparkling
  if w.type then w.type:SetText("Dungeon boss  ·  Mythic") end
  w.fxset = { aura = 0.85, foil = 0.85, rune = 0.6, sparks = true, rays = 0.35, finish = 4 }
  w.aura:Show(); w.foil:Show()
  for _, sp in ipairs(w.sparks or {}) do sp:Show() end
  live[w] = card
end)

-- every colour, turning: the edge, the glow and the plate's rune follow one hue around the wheel
local function hue(h)
  h = h % 1
  local i = math.floor(h * 6); local f = h * 6 - i
  local q, t = 1 - f, f
  if i == 0 then return 1, t, 0 elseif i == 1 then return q, 1, 0 elseif i == 2 then return 0, 1, t
  elseif i == 3 then return 0, q, 1 elseif i == 4 then return t, 0, 1 else return 1, 0, q end
end
local tick = CreateFrame("Frame")
tick:SetScript("OnUpdate", function()
  if not next(live) then return end
  local t = GetTime()
  for w, card in pairs(live) do
    if w.card ~= card or not w:IsVisible() then live[w] = nil
    else
      local r, g, b = hue(t * 0.12 + (w.phase or 0))
      w.edge:SetVertexColor(0.55 + 0.45 * r, 0.55 + 0.45 * g, 0.55 + 0.45 * b, 1)
      w.aura:SetVertexColor(r, g, b, 1)
      if w.rune then w.rune:SetVertexColor(0.6 + 0.4 * r, 0.6 + 0.4 * g, 0.6 + 0.4 * b, 0.9) end
      for i, sp in ipairs(w.sparks or {}) do local r2, g2, b2 = hue(t * 0.12 + i * 0.17); sp:SetVertexColor(0.7 + 0.3 * r2, 0.7 + 0.3 * g2, 0.7 + 0.3 * b2) end
    end
  end
end)

-- where it comes from
local function mythTip(cd)
  local dn = cd and RG.ARCADE_SET_MYTHIC_OF[cd.key or ""]
  if not dn then return false end
  local o = RG.ArcadePackOdds and RG.ArcadePackOdds("dungeon")
  GameTooltip:AddLine("The Mythic of " .. dn .. ": only in its packs" .. (o and o.mythic and (", about 1 in " .. o.mythic) or "") .. ". It doesn't count toward the set, and it can't be traded, crafted or sold.", 1, 0.9, 0.55, true)
  return true
end
-- (first in the list, ahead of the hooks of files loaded after this one)
local tipEv = CreateFrame("Frame"); tipEv:RegisterEvent("PLAYER_LOGIN")
tipEv:SetScript("OnEvent", function() RG.ArcadeTipHooks = RG.ArcadeTipHooks or {}; table.insert(RG.ArcadeTipHooks, 1, mythTip) end)

-- the Album page of a dungeon: its Mythic, found or not yet
RG.ArcadeAlbumHooks = RG.ArcadeAlbumHooks or {}
table.insert(RG.ArcadeAlbumHooks, function(st, frame)
  local btn = rawget(frame.albOpen, "mythBtn")
  local key = st and st.dungeon and not st.raid and not st.holiday and RG.ARCADE_SET_MYTHIC[st.name]
  local u = RG.ArcadeUI
  local c = key and u and u.byKey[key]
  if not c then if btn then btn:Hide() end return end
  if not btn then
    btn = u.gbtn(frame.albOpen, "Mythic", 190, 24, function() local cc = frame.albOpen.mythCard; if cc and RG.ArcadeOpenDetail then RG.ArcadeOpenDetail(cc) end end)
    btn:SetPoint("RIGHT", frame.prev, "LEFT", -14, 0)
    btn:SetScript("OnEnter", function(self)
      local cc = frame.albOpen.mythCard
      if not cc then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Mythic: " .. cc.name, 1, 0.9, 0.55)
      local have = u.owned(u.store(), cc.id) > 0
      GameTooltip:AddLine(have and "You have it. Click to see it." or ("Not found yet. It only comes from " .. (RG.ARCADE_SET_MYTHIC_OF[cc.key] or "its") .. " packs."), 1, 1, 1, true)
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.albOpen.mythBtn = btn
  end
  frame.albOpen.mythCard = c
  local have = u.owned(u.store(), c.id) > 0
  btn:SetText(have and ("|cffffe58cMythic:|r " .. c.name) or "|cffa89bc9Mythic: not found yet|r")
  btn:SetEnabled(have)
  btn:Show()
end)
