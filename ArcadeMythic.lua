-- Waypath+ Arena: the Mythics, six chase cards above every other rarity. Hand-made (not generated): original
-- Waypath-themed subjects with their own painted art (Media/Arcade/Mythic*.tga, drawn by tools/arcade/art_mythic.py),
-- plus The 1 Ring, the game's own item (8350), which shows the item's icon from the player's game files.
-- They join the card list as tier 7 rows; their effects are in Battle.lua (MYTHIC), their look in Arcade.lua.
local _, RG = ...

-- { kind, name, tier, item id / creature type, collection text }
local ROWS = {
  { 2, "The Wanderer", 7, 7, "Mythic. Sixty levels. Every road, walked once." },
  { 3, "The First Waypoint", 7, 0, "Mythic. Follow the arrow." },
  { 3, "The Last Campfire", 7, 0, "Mythic. Camping 101, the final lesson." },
  { 3, "Sixty", 7, 0, "Mythic. The last level is the loudest." },
  { 1, "The Hourglass of Forever", 7, 0, "Mythic. The sand never runs out." },
  { 1, "The 1 Ring", 7, 8350, "Mythic. Plus one to everything." },
}
-- name -> art texture, collector number, the type line on the card, an icon from the game for small views,
-- a glow colour, and (the Ring) one per account with the opener's name engraved
RG.ARCADE_MYTHIC = {
  ["The Wanderer"]             = { art = "Mythic1", num = "M-01", type = "Raider  ·  Mythic",          icon = "Ability_Tracking",          glow = { 0.71, 0.55, 1 } },
  ["The First Waypoint"]       = { art = "Mythic2", num = "M-02", type = "Place  ·  Spell  ·  Mythic", icon = "INV_Misc_Map_01",            glow = { 1, 0.82, 0.4 } },
  ["The Last Campfire"]        = { art = "Mythic3", num = "M-03", type = "Camp  ·  Mythic",            icon = "Spell_Fire_Fire",            glow = { 1, 0.48, 0.24 } },
  ["Sixty"]                    = { art = "Mythic4", num = "M-04", type = "Spell  ·  Mythic",           icon = "Spell_Holy_HolyBolt",        glow = { 1, 0.86, 0.45 } },
  ["The Hourglass of Forever"] = { art = "Mythic5", num = "M-05", type = "Artifact  ·  Spell  ·  Mythic", icon = "INV_Misc_PocketWatch_01", glow = { 1, 0.9, 0.6 } },
  ["The 1 Ring"]               = { art = "Mythic6", num = "M-00", type = "Item  ·  Spell  ·  Mythic",  one = true,                          glow = { 1, 0.8, 0.45 } },
}
RG.ARCADE_MYTHIC_ORDER = {}
RG.ARCADE_DATA = RG.ARCADE_DATA or {}
for _, r in ipairs(ROWS) do
  RG.ARCADE_DATA[#RG.ARCADE_DATA + 1] = r
  RG.ARCADE_MYTHIC_ORDER[#RG.ARCADE_MYTHIC_ORDER + 1] = r[2]
end

-- The 1 Ring engraves the name of whoever opened it round the left of its band (the art leaves that part plain): one
-- texture per letter from RingGlyphs.tga, each set along the band and turned with it (by turning its texture
-- coordinates, which every client can do). The band's shape is the one in tools/arcade/mythic/6_ring.svg.
local GLYPHS_TEX = "Interface\\AddOns\\Waypath\\Media\\Arcade\\RingGlyphs"
local RING = { cx = 195, cy = 208, s = 1.12, rot = math.rad(-14), rx = 74, ry = 96, ta = 2.42, tb = 3 * math.pi / 2 - 0.46,
               em = 12, spacing = 1 }
-- a point on the band (t: the ellipse's angle) in card units, as the art is placed on the card (3 units in from its edges)
local function bandPoint(t)
  local lx, ly = RING.rx * math.cos(t), RING.ry * math.sin(t)
  local c, sn = math.cos(RING.rot), math.sin(RING.rot)
  local x = RING.cx + RING.s * (lx * c - ly * sn)
  local y = RING.cy + RING.s * (lx * sn + ly * c)
  return 3 + x * (256 / 390) * (250 / 256), 3 + y * (358 / 550) * (352 / 358)
end
RG.ArcadeRingPoint = bandPoint
-- the name in capitals, letter by letter (UTF-8: Latin-1 accented letters have their own glyphs; others are left out)
local function letters(text)
  local out = {}
  for ch in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    if #ch == 1 then ch = ch:upper()
    elseif #ch == 2 and ch:byte(1) == 195 then
      local b = ch:byte(2)
      if b >= 160 and b <= 190 and b ~= 183 then ch = string.char(195, b - 32) end
    end
    if RG.ARCADE_RING_GLYPHS[ch] then out[#out + 1] = ch end
  end
  return out
end
RG.ArcadeRingLetters = letters

-- w: a card widget showing The 1 Ring; text: the name to engrave (nil hides it)
function RG.ArcadeRingEngrave(w, text)
  local pool = rawget(w, "ringGl")
  if not text or text == "" then
    if pool then for _, t in ipairs(pool) do t:Hide() end end
    return
  end
  local G = RG.ARCADE_RING_GLYPHS
  local chars = letters(text)
  table.insert(chars, 1, " "); table.insert(chars, 1, "\226\156\166"); chars[#chars + 1] = " "; chars[#chars + 1] = "\226\156\166"
  -- the arc, sampled, with the distance along it
  local N, pts, len = 90, {}, 0
  local px, py
  for i = 0, N do
    local t = RING.ta + (RING.tb - RING.ta) * i / N
    local x, y = bandPoint(t)
    if px then len = len + math.sqrt((x - px) ^ 2 + (y - py) ^ 2) end
    pts[i] = { x, y, len }
    px, py = x, y
  end
  local k = RING.s * (256 / 390) * (250 / 256)
  local em, sp = RING.em * k, RING.spacing * k
  local total = 0
  for i, ch in ipairs(chars) do total = total + G[ch][2] * em + (i > 1 and sp or 0) end
  local scale = total > len * 0.96 and (len * 0.96 / total) or 1
  em, sp, total = em * scale, sp * scale, total * scale
  -- where along the arc (a distance) is, and which way the band runs there
  local function at(d)
    for i = 1, N do
      if pts[i][3] >= d or i == N then
        local a, b = pts[i - 1], pts[i]
        local f = (b[3] > a[3]) and math.max(0, math.min(1, (d - a[3]) / (b[3] - a[3]))) or 0
        return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, math.atan2(b[2] - a[2], b[1] - a[1])
      end
    end
  end
  if not pool then pool = {}; w.ringGl = pool end
  local u = w.u
  local cell = G.cell
  local samp = 26 / cell                         -- the part of each 32 px cell drawn (so a turned square stays inside it)
  local size = em * (cell / G.em) * samp
  local d = (len - total) / 2
  local n = 0
  for i, ch in ipairs(chars) do
    local adv = G[ch][2] * em
    if ch ~= " " then
      n = n + 1
      local tx = pool[n]
      if not tx then
        tx = w.mframe:CreateTexture(nil, "ARTWORK", nil, 2); tx:SetTexture(GLYPHS_TEX); pool[n] = tx
      end
      local x, y, phi = at(d + adv / 2)
      tx:ClearAllPoints(); tx:SetPoint("CENTER", w, "TOPLEFT", x * u, -y * u); tx:SetSize(size * u, size * u)
      -- the cell's centre on the 256 px sheet, and the four corners of a square turned by phi around it
      local idx = G[ch][1]
      local cu, cv = ((idx % 8) + 0.5) / 8, (math.floor(idx / 8) + 0.5) / 8
      local h = samp / 16
      local cs, sn = math.cos(phi), math.sin(phi)
      local function tc(ax, ay) return cu + cs * ax + sn * ay, cv - sn * ax + cs * ay end
      local ulx, uly = tc(-h, -h); local llx, lly = tc(-h, h); local urx, ury = tc(h, -h); local lrx, lry = tc(h, h)
      tx:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
      tx:SetAlpha(1); tx:Show()
    end
    d = d + adv + sp
  end
  for j = n + 1, #pool do pool[j]:Hide() end
end

-- ring glyphs (written by tools/arcade/art_mythic.py): letter -> { cell on RingGlyphs.tga, width in ems }
RG.ARCADE_RING_GLYPHS = { cell = 32, em = 22, ["A"] = { 0, 0.718 }, ["B"] = { 1, 0.703 }, ["C"] = { 2, 0.787 }, ["D"] = { 3, 0.835 }, ["E"] = { 4, 0.649 }, ["F"] = { 5, 0.613 }, ["G"] = { 6, 0.849 }, ["H"] = { 7, 0.877 }, ["I"] = { 8, 0.402 }, ["J"] = { 9, 0.404 }, ["K"] = { 10, 0.790 }, ["L"] = { 11, 0.634 }, ["M"] = { 12, 0.961 }, ["N"] = { 13, 0.873 }, ["O"] = { 14, 0.892 }, ["P"] = { 15, 0.681 }, ["Q"] = { 16, 0.897 }, ["R"] = { 17, 0.770 }, ["S"] = { 18, 0.612 }, ["T"] = { 19, 0.682 }, ["U"] = { 20, 0.833 }, ["V"] = { 21, 0.724 }, ["W"] = { 22, 0.968 }, ["X"] = { 23, 0.751 }, ["Y"] = { 24, 0.716 }, ["Z"] = { 25, 0.665 }, ["✦"] = { 26, 0.838 }, ["'"] = { 27, 0.210 }, ["-"] = { 28, 0.380 }, [" "] = { 29, 0.250 }, ["À"] = { 30, 0.718 }, ["Á"] = { 31, 0.718 }, ["Â"] = { 32, 0.718 }, ["Ã"] = { 33, 0.718 }, ["Ä"] = { 34, 0.718 }, ["Å"] = { 35, 0.718 }, ["Æ"] = { 36, 0.994 }, ["Ç"] = { 37, 0.787 }, ["È"] = { 38, 0.649 }, ["É"] = { 39, 0.649 }, ["Ê"] = { 40, 0.649 }, ["Ë"] = { 41, 0.649 }, ["Ì"] = { 42, 0.402 }, ["Í"] = { 43, 0.402 }, ["Î"] = { 44, 0.402 }, ["Ï"] = { 45, 0.402 }, ["Ð"] = { 46, 0.835 }, ["Ñ"] = { 47, 0.873 }, ["Ò"] = { 48, 0.892 }, ["Ó"] = { 49, 0.892 }, ["Ô"] = { 50, 0.892 }, ["Õ"] = { 51, 0.892 }, ["Ö"] = { 52, 0.892 }, ["Ø"] = { 53, 0.890 }, ["Ù"] = { 54, 0.833 }, ["Ú"] = { 55, 0.833 }, ["Û"] = { 56, 0.833 }, ["Ü"] = { 57, 0.833 }, ["Ý"] = { 58, 0.716 }, ["Þ"] = { 59, 0.677 }, ["ß"] = { 60, 1.064 } }
-- ring glyphs end
