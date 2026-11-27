-- How things look: the harness's widgets get real layout and drawing state, and what is on screen can be written
-- out as a scene (a draw list) for tools/render/render.py to draw.
--
--   * every visual setter is recorded (colors, blend modes, rotation, gradients, backdrops, masks, shadows, wrap...)
--   * anchors are resolved: GetLeft/GetRect/GetCenter/GetWidth return where the frame really is, as in the game
--   * text is measured with the real fonts' advance widths (tools/render/fonts.py writes .cache/fontmetrics.lua);
--     without that file an average width is used, so CI still runs
--   * model frames record every call (display id, creature, zoom, camera distance, facing...) with its time, load
--     their model a moment later and fire OnModelLoaded, as the game does; with .cache/models.lua (tools/render/
--     modeldata.py) GetModelFileID answers with the real model file
--
-- Coordinates: "screen units" are UIParent units at scale 1 (UIParent is 1920 x 1080 of them), x to the right and
-- y up, as GetLeft/GetBottom report them.
local L = {}

local PTX = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
  RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
local REGION = { Texture = true, FontString = true, MaskTexture = true, Line = true }

-- the game's font objects (FrameXML's Fonts.xml, Classic): path, size, flags, color, shadow
local FRIZ, ARIALN = "Fonts\\FRIZQT__.TTF", "Fonts\\ARIALN.TTF"
local GOLD, WHITE = { 1, 0.82, 0, 1 }, { 1, 1, 1, 1 }
local SHADOW = { 0, 0, 0, 1, 1, -1 }
local FONTOBJ = {
  GameFontNormal = { FRIZ, 12, "", GOLD, SHADOW }, GameFontNormalSmall = { FRIZ, 10, "", GOLD, SHADOW },
  GameFontNormalLarge = { FRIZ, 16, "", GOLD, SHADOW }, GameFontNormalHuge = { FRIZ, 20, "", GOLD, SHADOW },
  GameFontHighlight = { FRIZ, 12, "", WHITE, SHADOW }, GameFontHighlightSmall = { FRIZ, 10, "", WHITE, SHADOW },
  GameFontHighlightLarge = { FRIZ, 16, "", WHITE, SHADOW }, GameFontHighlightMedium = { FRIZ, 14, "", WHITE, SHADOW },
  GameFontDisable = { FRIZ, 12, "", { 0.5, 0.5, 0.5, 1 }, SHADOW }, GameFontDisableSmall = { FRIZ, 10, "", { 0.5, 0.5, 0.5, 1 }, SHADOW },
  GameFontGreen = { FRIZ, 12, "", { 0.1, 1, 0.1, 1 }, SHADOW }, GameFontRed = { FRIZ, 12, "", { 1, 0.1, 0.1, 1 }, SHADOW },
  GameFontWhite = { FRIZ, 12, "", WHITE, SHADOW }, ChatFontNormal = { ARIALN, 14, "", WHITE, SHADOW },
  NumberFontNormal = { ARIALN, 14, "OUTLINE", WHITE, nil }, SystemFont_Shadow_Small = { FRIZ, 10, "", GOLD, SHADOW },
  QuestFont = { FRIZ, 13, "", { 0.15, 0.09, 0.04, 1 }, nil },
}

function L.install(W, here)
  local S, M, G = W.S, W.Methods, W.G
  local gen = 0                      -- bumped by anything that can move or resize something: the layout cache's key
  local function bump() gen = gen + 1 end
  L.metrics = nil
  local mf = loadfile((here or ".") .. "/.cache/fontmetrics.lua")
  if mf then L.metrics = mf() end
  L.models = nil
  local md = loadfile((here or ".") .. "/.cache/models.lua")
  if md then L.models = md() end

  -- the game's own frames sit where the default UI puts them (an add-on reads their positions)
  local function place(name, w, h, ...)
    local f = G[name]
    if f and S[f] and #S[f].points == 0 then S[f].w, S[f].h = w, h; table.insert(S[f].points, { ... }) end
  end
  place("Minimap", 140, 140, "CENTER", G.UIParent, "TOPRIGHT", -92, -96)
  place("ChatFrame1", 430, 120, "BOTTOMLEFT", G.UIParent, "BOTTOMLEFT", 32, 95)
  for _, n in ipairs({ "CharacterFrame", "QuestLogFrame", "MerchantFrame", "BankFrame", "MailFrame", "QuestFrame", "GossipFrame",
    "TaxiFrame", "SpellBookFrame", "FriendsFrame", "TradeSkillFrame", "CraftFrame", "ClassTrainerFrame" }) do
    place(n, 384, 512, "TOPLEFT", G.UIParent, "TOPLEFT", 16, -116)
  end
  place("WorldMapFrame", 1002, 668, "CENTER", G.UIParent, "CENTER", 0, 0)
  place("GameMenuFrame", 195, 300, "CENTER", G.UIParent, "CENTER", 0, 0)
  place("LootFrame", 190, 320, "TOPLEFT", G.UIParent, "TOPLEFT", 20, -125)
  place("UIErrorsFrame", 512, 60, "TOP", G.UIParent, "TOP", 0, -122)
  place("ObjectiveTrackerFrame", 250, 600, "TOPRIGHT", G.UIParent, "TOPRIGHT", -85, -260)
  place("QuestWatchFrame", 250, 600, "TOPRIGHT", G.UIParent, "TOPRIGHT", -85, -260)

  -- the game's font objects: their real fonts, colors and shadows
  for n, d in pairs(FONTOBJ) do
    local fo = G[n]
    if fo and S[fo] then local st = S[fo]; st.font = { d[1], d[2], d[3] }; st.fcolor = d[4]; st.shadow = d[5] end
  end

  local function wrap(name, after)
    local orig = M[name]
    M[name] = function(self, ...)
      local r = { orig and orig(self, ...) }
      after(self, S[self], ...)
      return unpack(r)
    end
  end
  for _, k in ipairs({ "SetPoint", "SetAllPoints", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale",
    "SetText", "SetFormattedText", "SetFont", "SetFontObject" }) do
    wrap(k, bump)
  end
  -- SetParent: the widget moves to its new parent's children (the harness only changed the pointer)
  local origSetParent = M.SetParent
  function M:SetParent(p)
    local st = S[self]
    if type(p) == "string" then p = G[p] end
    local old = st.parent
    if old == p then return end
    local isRegion = REGION[st.type]
    if old and S[old] then
      local list = isRegion and S[old].regions or S[old].children
      for i, x in ipairs(list) do if x == self then table.remove(list, i) break end end
    end
    origSetParent(self, p)
    if p and S[p] then local list = isRegion and S[p].regions or S[p].children; list[#list + 1] = self end
    bump()
  end

  -- -------------------------------------------------------------------------
  -- drawing state
  -- -------------------------------------------------------------------------
  function M:SetColorTexture(r, g, b, a) local st = S[self]; st.tex = "color"; st.color = { r or 1, g or 1, b or 1, a or 1 } end
  function M:SetTexture(t, wrapH, wrapV)
    local st = S[self]
    st.tex = t; st.color = nil; st.wrap = (wrapH or wrapV) and { wrapH, wrapV } or nil
    return true
  end
  function M:SetBlendMode(m) S[self].blend = m end
  function M:GetBlendMode() return S[self].blend or "BLEND" end
  function M:SetDesaturated(on) S[self].desat = on and true or false end
  function M:IsDesaturated() return S[self].desat or false end
  function M:SetRotation(r, cx, cy) local st = S[self]; st.rot = tonumber(r) or 0; if st.m then st.m.facing = st.rot; L.mlog(self, "SetRotation", r) end end
  function M:GetRotation() return S[self].rot or 0 end
  local function colorArgs(...)
    local a = ...
    if type(a) == "table" then
      local c1, c2 = ...
      return { c1.r or 1, c1.g or 1, c1.b or 1, c1.a or 1 }, { c2.r or 1, c2.g or 1, c2.b or 1, c2.a or 1 }
    end
    local r1, g1, b1, r2, g2, b2 = ...
    return { r1 or 1, g1 or 1, b1 or 1, 1 }, { r2 or 1, g2 or 1, b2 or 1, 1 }
  end
  function M:SetGradient(orient, ...) local c1, c2 = colorArgs(...); S[self].grad = { orient, c1, c2 } end
  function M:SetGradientAlpha(orient, r1, g1, b1, a1, r2, g2, b2, a2)
    S[self].grad = { orient, { r1 or 1, g1 or 1, b1 or 1, a1 or 1 }, { r2 or 1, g2 or 1, b2 or 1, a2 or 1 } }
  end
  function M:SetDrawLayer(layer, sub) local st = S[self]; st.layer = layer or st.layer; st.sub = tonumber(sub) or 0 end
  function M:GetDrawLayer() local st = S[self]; return st.layer or "ARTWORK", st.sub or 0 end
  local origCreateTexture = M.CreateTexture
  function M:CreateTexture(name, layer, inherits, sub)
    local t = origCreateTexture(self, name, layer)
    S[t].sub = tonumber(sub) or 0
    return t
  end
  local origCreateMask = M.CreateMaskTexture
  function M:CreateMaskTexture(name, layer, inherits, sub) local t = origCreateMask(self, name, layer); S[t].sub = tonumber(sub) or 0; return t end
  function M:AddMaskTexture(mask) local st = S[self]; st.masks = st.masks or {}; st.masks[#st.masks + 1] = mask end
  function M:RemoveMaskTexture(mask)
    local st = S[self]
    for i, x in ipairs(st.masks or {}) do if x == mask then table.remove(st.masks, i) break end end
  end
  function M:SetHorizTile(on) S[self].htile = on and true or false end
  function M:SetVertTile(on) S[self].vtile = on and true or false end
  function M:SetTexCoord(...)
    local n = select("#", ...)
    local a = { ... }
    if n == 4 then a = { a[1], a[3], a[1], a[4], a[2], a[3], a[2], a[4] } end
    S[self].tc8 = a
  end
  function M:GetTexCoord()
    local t = S[self].tc8
    if t then return unpack(t, 1, 8) end
    return 0, 0, 0, 1, 1, 0, 1, 1
  end
  -- frames
  function M:SetBackdropColor(r, g, b, a) S[self].bdColor = { r or 1, g or 1, b or 1, a or 1 } end
  function M:SetBackdropBorderColor(r, g, b, a) S[self].bdBorder = { r or 1, g or 1, b or 1, a or 1 } end
  function M:GetBackdropColor() local c = S[self].bdColor or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
  function M:GetBackdropBorderColor() local c = S[self].bdBorder or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
  function M:SetClipsChildren(on) S[self].clips = on and true or false end
  function M:DoesClipChildren() return S[self].clips or false end
  function M:GetClipsChildren() return S[self].clips or false end
  function M:SetIgnoreParentAlpha(on) S[self].ignoreAlpha = on and true or false end
  function M:SetIgnoreParentScale(on) S[self].ignoreScale = on and true or false; bump() end
  function M:IsIgnoringParentAlpha() return S[self].ignoreAlpha or false end
  function M:IsIgnoringParentScale() return S[self].ignoreScale or false end
  local origStrata = M.SetFrameStrata
  function M:SetFrameStrata(s) origStrata(self, s); S[self].strataSet = true end
  function M:GetFrameStrata()
    local st = S[self]
    while st do if st.strataSet then return st.strata end st = st.parent and S[st.parent] end
    return "MEDIUM"
  end
  function M:LockHighlight() S[self].lockHL = true end
  function M:UnlockHighlight() S[self].lockHL = false end
  function M:SetStatusBarColor(r, g, b, a) S[self].barColor = { r or 1, g or 1, b or 1, a or 1 } end
  function M:GetStatusBarColor() local c = S[self].barColor or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
  function M:SetOrientation(o) S[self].orient = o end
  function M:GetOrientation() return S[self].orient or "HORIZONTAL" end
  function M:SetReverseFill(on) S[self].reverse = on and true or false end
  function M:SetTextInsets(l, r, t, b) S[self].insets = { l or 0, r or 0, t or 0, b or 0 } end
  function M:GetTextInsets() local i = S[self].insets or { 0, 0, 0, 0 }; return i[1], i[2], i[3], i[4] end
  function M:SetScrollChild(c) S[self].scrollChild = c; if c and S[c] then S[c].scrollOf = self end bump() end
  wrap("SetVerticalScroll", bump)
  wrap("SetValue", bump)
  wrap("SetMinMaxValues", bump)
  wrap("SetHorizontalScroll", bump)
  -- text
  function M:SetShadowColor(r, g, b, a) local st = S[self]; local s = st.shadowSet or {}; s[1], s[2], s[3], s[4] = r or 0, g or 0, b or 0, a or 1; st.shadowSet = s end
  function M:SetShadowOffset(x, y) local st = S[self]; local s = st.shadowSet or { 0, 0, 0, 1 }; s[5], s[6] = x or 0, y or 0; st.shadowSet = s end
  function M:GetShadowOffset() local s = L.shadowOf(self); if s then return s[5] or 0, s[6] or 0 end return 0, 0 end
  function M:GetShadowColor() local s = L.shadowOf(self); if s then return s[1], s[2], s[3], s[4] end return 0, 0, 0, 0 end
  function M:SetSpacing(s) S[self].spacing = tonumber(s) or 0; bump() end
  function M:GetSpacing() return S[self].spacing or 0 end
  function M:SetWordWrap(on) S[self].wordWrap = on and true or false; bump() end
  function M:CanWordWrap() local w = S[self].wordWrap; if w == nil then return true end return w end
  function M:SetNonSpaceWrap(on) S[self].nonSpaceWrap = on and true or false; bump() end
  function M:SetMaxLines(n) S[self].maxLines = tonumber(n) or 0; bump() end
  function M:GetMaxLines() return S[self].maxLines or 0 end
  function M:SetIndentedWordWrap(on) S[self].indented = on and true or false end
  function M:SetMultiLine(on) S[self].multiLine = on and true or false end
  function M:IsMultiLine() return S[self].multiLine or false end
  local origSetTextColor = M.SetTextColor
  function M:SetTextColor(r, g, b, a) origSetTextColor(self, r, g, b, a) end
  function M:GetTextColor()
    local c = L.colorOf(self)
    return c[1], c[2], c[3], c[4] or 1
  end
  local origCFS = M.CreateFontString
  function M:CreateFontString(name, layer, inherits)
    local r = origCFS(self, name, layer, inherits)
    local fo = type(inherits) == "string" and G[inherits] or inherits
    if fo and S[fo] then S[r].fontObj = fo end
    return r
  end
  function M:SetFontObject(fo)
    if type(fo) == "string" then fo = G[fo] end
    local st = S[self]
    st.fontObj = fo; st.font = nil; bump()
    if st.type == "Font" and fo and S[fo] then
      local fs = S[fo]
      st.font = fs.font and { unpack(fs.font) }; st.fcolor = fs.fcolor; st.shadow = fs.shadow
    end
  end
  function M:GetFontObject() return S[self].fontObj end
  function M:SetFont(path, size, flags) S[self].font = { path, tonumber(size) or 12, flags or "" }; bump(); return true end
  function M:GetFont() local f = L.fontOf(self); return f[1], f[2], f[3] end
  function M:CopyFontObject(fo)
    if type(fo) == "string" then fo = G[fo] end
    local st, fs = S[self], fo and S[fo]
    if not fs then return end
    local f = L.fontOf(fo)
    st.font = { f[1], f[2], f[3] }; st.fcolor = L.colorOf(fo); st.shadow = L.shadowOf(fo); bump()
  end
  -- button text: SetText makes the button's font string, as the game does
  for _, k in ipairs({ "Normal", "Highlight", "Disabled" }) do
    M["Set" .. k .. "FontObject"] = function(self, fo) if type(fo) == "string" then fo = G[fo] end S[self]["fo" .. k] = fo; bump() end
    M["Get" .. k .. "FontObject"] = function(self) return S[self]["fo" .. k] end
  end
  local origSetText = M.SetText
  function M:SetText(t)
    local st = S[self]
    if (st.type == "Button" or st.type == "CheckButton") and not st.fs and t ~= nil and t ~= "" then
      local fs = W.makeRegion(self, "FontString", nil, "ARTWORK")
      S[fs].buttonText = true
      st.fs = fs
    end
    return origSetText(self, t)
  end

  -- a button's, status bar's or slider's own textures: they fill it (or, a thumb, ride on its value)
  for _, k in ipairs({ "Normal", "Highlight", "Pushed", "Disabled", "Checked", "DisabledChecked", "Thumb", "StatusBar" }) do
    local field = k:lower() .. "Tex"
    for _, verb in ipairs({ "Get", "Set" }) do
      local orig = M[verb .. k .. "Texture"]
      M[verb .. k .. "Texture"] = function(self, ...)
        local r = { orig(self, ...) }
        local tx = S[self][field]
        if tx and S[tx] then S[tx].roleOf = field; if field == "highlightTex" and not S[tx].layer then S[tx].layer = "HIGHLIGHT" end end
        bump()
        return unpack(r)
      end
    end
  end

  -- -------------------------------------------------------------------------
  -- fonts and text
  -- -------------------------------------------------------------------------
  function L.fontOf(w)
    local st = S[w]
    if not st then return { FRIZ, 12, "" } end
    if st.font then return st.font end
    local fo = st.fontObj
    if not fo and st.buttonText and st.parent then
      local ps = S[st.parent]
      fo = (ps.enabled == false and ps.foDisabled) or ps.foNormal
    end
    if fo and S[fo] then return L.fontOf(fo) end
    if st.buttonText then return { FRIZ, 12, "" } end
    return { FRIZ, 12, "" }
  end
  function L.colorOf(w)
    local st = S[w]
    if not st then return WHITE end
    if st.tc then return st.tc end
    if st.fcolor then return st.fcolor end
    local fo = st.fontObj
    if not fo and st.buttonText and st.parent then
      local ps = S[st.parent]
      fo = (ps.enabled == false and ps.foDisabled) or ps.foNormal
      if not fo then return GOLD end
    end
    if fo and S[fo] then return L.colorOf(fo) end
    return WHITE
  end
  function L.shadowOf(w)
    local st = S[w]
    if not st then return nil end
    if st.shadowSet then return st.shadowSet end
    if st.shadow then return st.shadow end
    local fo = st.fontObj
    if not fo and st.buttonText and st.parent then fo = S[st.parent].foNormal or G.GameFontNormal end
    if fo and S[fo] then return L.shadowOf(fo) end
    return nil
  end

  local function normFont(p) return tostring(p or ""):gsub("/", "\\"):upper() end
  local function fontMetrics(path)
    local m = L.metrics and L.metrics[normFont(path)]
    return m
  end
  L.normFont = normFont

  -- the next UTF-8 character of s at i: its code point and the index after it
  local function utf8at(s, i)
    local c = s:byte(i)
    if not c then return nil end
    if c < 0x80 then return c, i + 1 end
    if c >= 0xF0 then return ((c % 8) * 262144) + ((s:byte(i + 1) or 128) % 64) * 4096 + ((s:byte(i + 2) or 128) % 64) * 64 + ((s:byte(i + 3) or 128) % 64), i + 4 end
    if c >= 0xE0 then return ((c % 16) * 4096) + ((s:byte(i + 1) or 128) % 64) * 64 + ((s:byte(i + 2) or 128) % 64), i + 3 end
    if c >= 0xC0 then return ((c % 32) * 64) + ((s:byte(i + 1) or 128) % 64), i + 2 end
    return c, i + 1
  end

  -- Text split into pieces: { raw, w, kind } with kind "g" (a character), "s" (a space), "n" (a line break) or
  -- "c" (an escape code: a color, a link, no width). Inline textures |T...|t are "g" with their own width.
  local function tokens(text, font, size)
    local out = {}
    local m = fontMetrics(font[1])
    local adv, def = m and m.adv, (m and m.def) or 0.5
    local i, n = 1, #text
    while i <= n do
      local c = text:sub(i, i)
      if c == "|" then
        local nx = text:sub(i + 1, i + 1)
        if nx == "|" then out[#out + 1] = { "||", ((adv and adv[124]) or def) * size, "g" }; i = i + 2
        elseif nx == "c" and text:sub(i + 2, i + 9):match("^%x%x%x%x%x%x%x%x$") then out[#out + 1] = { text:sub(i, i + 9), 0, "c" }; i = i + 10
        elseif nx == "r" then out[#out + 1] = { "|r", 0, "c" }; i = i + 2
        elseif nx == "n" then out[#out + 1] = { "|n", 0, "n" }; i = i + 2
        elseif nx == "T" or nx == "A" then
          local close = nx == "T" and "|t" or "|a"
          local e = text:find(close, i + 2, true)
          local body = text:sub(i + 2, (e or n + 1) - 1)
          local parts = {}
          for p in (body .. ":"):gmatch("([^:]*):") do parts[#parts + 1] = p end
          local h = tonumber(parts[2]) or 0
          local w = tonumber(parts[3]) or 0
          if h == 0 then h = size end
          if w == 0 then w = h end
          out[#out + 1] = { text:sub(i, (e or n) + 1), w, "g" }
          i = (e or n) + 2
        elseif nx == "H" then
          local e = text:find("|h", i + 2, true)
          out[#out + 1] = { text:sub(i, (e or n) + 1), 0, "c" }; i = (e or n) + 2
        elseif nx == "h" then out[#out + 1] = { "|h", 0, "c" }; i = i + 2
        elseif nx == "K" then
          local e = text:find("|k", i + 2, true)
          out[#out + 1] = { text:sub(i, (e or n) + 1), 0, "c" }; i = (e or n) + 2
        else out[#out + 1] = { "|", ((adv and adv[124]) or def) * size, "g" }; i = i + 1 end
      elseif c == "\n" then out[#out + 1] = { "\n", 0, "n" }; i = i + 1
      elseif c == " " then out[#out + 1] = { " ", ((adv and adv[32]) or def * 0.5) * size, "s" }; i = i + 1
      else
        local cp, j = utf8at(text, i)
        out[#out + 1] = { text:sub(i, j - 1), ((adv and adv[cp]) or def) * size, "g" }
        i = j
      end
    end
    return out
  end

  -- Lines of a text at a width (nil = no wrapping): { { raw, width }, ... }
  function L.layoutText(text, font, size, width, wordWrap, maxLines, nonSpaceWrap)
    local toks = tokens(tostring(text or ""), font, size)
    local lines, cur, cw = {}, {}, 0
    local function push()
      -- trailing spaces don't count
      local w = cw
      local k = #cur
      while k > 0 and cur[k][3] == "s" do w = w - cur[k][2]; k = k - 1 end
      local raw = {}
      for x = 1, #cur do raw[#raw + 1] = cur[x][1] end
      lines[#lines + 1] = { table.concat(raw), w }
      cur, cw = {}, 0
    end
    local wrapAt = width and width > 0 and wordWrap ~= false and width + 0.5 or nil
    local i = 1
    while i <= #toks do
      local t = toks[i]
      if t[3] == "n" then push(); i = i + 1
      elseif t[3] == "s" or t[3] == "c" then
        if not (t[3] == "s" and #cur == 0 and #lines > 0 and wrapAt) then cur[#cur + 1] = t; cw = cw + t[2] end
        i = i + 1
      else
        -- a word: up to the next space or line break
        local j, ww = i, 0
        while j <= #toks and toks[j][3] ~= "s" and toks[j][3] ~= "n" do ww = ww + toks[j][2]; j = j + 1 end
        if wrapAt and cw > 0 and cw + ww > wrapAt then push() end
        for x = i, j - 1 do
          local tk = toks[x]
          if wrapAt and cw > 0 and cw + tk[2] > wrapAt and ww > wrapAt then push() end
          cur[#cur + 1] = tk; cw = cw + tk[2]
        end
        i = j
      end
    end
    if #cur > 0 or #lines == 0 then push() end
    local truncated = false
    if maxLines and maxLines > 0 and #lines > maxLines then
      for k = #lines, maxLines + 1, -1 do lines[k] = nil end
      truncated = true
    end
    return lines, truncated
  end
  -- what the game draws of those lines in a box 'width' wide: a line that doesn't fit (a font string that doesn't wrap)
  -- is cut and ends in "...", and so does the last line kept when there were more (SetMaxLines)
  function L.ellipsize(lines, font, size, width, cut)
    if not width or width <= 0 then return lines end
    local dots = 0
    for _, t in ipairs(tokens("...", font, size)) do dots = dots + t[2] end
    for i, ln in ipairs(lines) do
      if ln[2] > width + 0.5 or (cut and i == #lines) then
        local out, w = {}, 0
        for _, t in ipairs(tokens(ln[1], font, size)) do
          if t[3] == "c" then out[#out + 1] = t[1]
          elseif w + t[2] > width - dots then break
          else out[#out + 1] = t[1]; w = w + t[2] end
        end
        local s = table.concat(out):gsub("%s+$", "")
        lines[i] = { s .. "...", w + dots }
      end
    end
    return lines
  end
  function L.textWidth(text, font, size)
    local best = 0
    for _, l in ipairs(L.layoutText(text, font, size, nil)) do if l[2] > best then best = l[2] end end
    return best
  end

  -- -------------------------------------------------------------------------
  -- layout
  -- -------------------------------------------------------------------------
  local SWID, SHGT = S[G.UIParent].w, S[G.UIParent].h
  L.screen = { SWID, SHGT }
  local function effScale(w)
    local s, st = 1, S[w]
    while st do
      s = s * (st.scale or 1)
      if st.ignoreScale then break end
      st = st.parent and S[st.parent]
    end
    return s
  end
  L.effScale = effScale
  M.GetEffectiveScale = function(self) return effScale(self) end

  local function parsePoint(w, p)
    local point, a, b, c, d = p[1], p[2], p[3], p[4], p[5]
    local st = S[w]
    local rel, rp, x, y
    if type(a) == "number" then rel, rp, x, y = st.parent, point, a, b
    elseif a == nil and type(b) == "number" then rel, rp, x, y = st.parent, point, b, c
    else
      rel = a
      if rel == nil then rel = st.parent end
      if type(rel) == "string" then rel = G[(rel:gsub("%$parent", S[st.parent] and S[st.parent].name or ""))] end
      if type(b) == "string" then rp, x, y = b, c, d
      elseif type(b) == "number" then rp, x, y = point, b, c
      else rp, x, y = point, c, d end
    end
    return tostring(point):upper(), rel, tostring(rp or point):upper(), tonumber(x) or 0, tonumber(y) or 0
  end

  local cache = setmetatable({}, { __mode = "k" })
  local resolving = {}
  local textLines   -- forward
  -- where a widget is, in screen units: left, bottom, right, top (nil when it has no position)
  local function rect(w)
    local st = S[w]
    if not st then return nil end
    if w == G.UIParent or w == G.WorldFrame then return 0, 0, SWID, SHGT end
    local c = cache[w]
    if c and c.gen == gen then return c[1], c[2], c[3], c[4] end
    if resolving[w] then return nil end
    resolving[w] = true
    local es = effScale(w)
    local l, r, t, b, cx, cy
    local points = st.points
    if #points == 0 and st.scrollOf and S[st.scrollOf] then
      -- a scroll child sits at its scroll frame's top left, moved by the scroll offsets
      local so = S[st.scrollOf]
      points = { { "TOPLEFT", st.scrollOf, "TOPLEFT", -(so.hs or 0) * effScale(st.scrollOf) / es, (so.vs or 0) * effScale(st.scrollOf) / es } }
    end
    if #points == 0 and st.roleOf == "thumbTex" and st.parent then
      -- a slider's thumb sits along it at its value
      local ps = S[st.parent]
      local mn, mx, v = ps.min or 0, ps.max or 0, ps.value or 0
      local fr = mx > mn and math.max(0, math.min(1, (v - mn) / (mx - mn))) or 0
      local pw, ph = M.GetWidth(st.parent), M.GetHeight(st.parent)
      local tw, th = (st.w and st.w > 0) and st.w or 32, (st.h and st.h > 0) and st.h or 32
      if ps.orient == "HORIZONTAL" then points = { { "CENTER", st.parent, "LEFT", tw / 2 + (pw - tw) * fr, 0 } }
      else points = { { "CENTER", st.parent, "TOP", 0, -(th / 2 + (ph - th) * fr) } } end
      if (st.w or 0) == 0 then st.w, st.h = tw, th end
    end
    if #points == 0 and st.owned and st.parent then
      -- another of the game's frames: always somewhere in the real UI (here: over its parent)
      points = { { "TOPLEFT", st.parent, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", st.parent, "BOTTOMRIGHT", 0, 0 } }
    end
    if #points == 0 and REGION[st.type] and (st.roleOf or st.buttonText) and st.parent then
      -- a button's own textures fill it, its text sits in its middle
      points = st.buttonText and { { "CENTER", st.parent, "CENTER", 0, 0 } } or { { "TOPLEFT", st.parent, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", st.parent, "BOTTOMRIGHT", 0, 0 } }
    end
    for _, p in ipairs(points) do
      local point, rel, rp, x, y = parsePoint(w, p)
      if rel and S[rel] and PTX[rp] and PTX[point] then
        local rl, rb, rr, rt = rect(rel)
        if rl then
          local f, g = PTX[rp], PTX[point]
          local px, py = rl + (rr - rl) * f[1] + x * es, rb + (rt - rb) * f[2] + y * es
          if g[1] == 0 then l = px elseif g[1] == 1 then r = px else cx = px end
          if g[2] == 0 then b = py elseif g[2] == 1 then t = py else cy = py end
        end
      end
    end
    resolving[w] = nil
    local wd, ht = (st.w or 0) * es, (st.h or 0) * es
    local isText = st.type == "FontString"
    if isText and (st.w or 0) == 0 and not (l and r) then
      local f = L.fontOf(w)
      wd = L.textWidth(st.text or "", f, f[2]) * es
    end
    if l and r then elseif l then r = l + wd elseif r then l = r - wd elseif cx then l, r = cx - wd / 2, cx + wd / 2 end
    if isText and (st.h or 0) == 0 and not (t and b) and l then
      local f = L.fontOf(w)
      local lines = textLines(w, (r - l) / es)
      ht = (#lines * (f[2] + (st.spacing or 0)) - (st.spacing or 0)) * es
      if (st.text or "") == "" then ht = 0 end
    end
    if t and b then elseif t then b = t - ht elseif b then t = b + ht elseif cy then b, t = cy - ht / 2, cy + ht / 2 end
    if not (l and b) then cache[w] = { gen = gen }; return nil end
    cache[w] = { l, b, r, t, gen = gen }
    return l, b, r, t
  end
  L.rect = rect

  -- the lines a font string shows at its width
  textLines = function(w, width)
    local st = S[w]
    local f = L.fontOf(w)
    local explicitW = (st.w or 0) > 0 or (width and width > 0)
    return (L.layoutText(st.text or "", f, f[2], explicitW and width or nil, st.wordWrap, st.maxLines, st.nonSpaceWrap))
  end

  function M:GetLeft() local l = rect(self); if l then return l / effScale(self) end end
  function M:GetRight() local _, _, r = rect(self); if r then return r / effScale(self) end end
  function M:GetTop() local _, _, _, t = rect(self); if t then return t / effScale(self) end end
  function M:GetBottom() local _, b = rect(self); if b then return b / effScale(self) end end
  function M:GetCenter()
    local l, b, r, t = rect(self)
    if not l then return nil end
    local es = effScale(self)
    return (l + r) / 2 / es, (b + t) / 2 / es
  end
  function M:GetRect()
    local l, b, r, t = rect(self)
    if not l then return nil end
    local es = effScale(self)
    return l / es, b / es, (r - l) / es, (t - b) / es
  end
  function M:GetScaledRect()
    local l, b, r, t = rect(self)
    if not l then return nil end
    return l, b, r - l, t - b
  end
  function M:GetWidth()
    local st = S[self]
    local l, _, r = rect(self)
    if l then return (r - l) / effScale(self) end
    if st.type == "FontString" and (st.w or 0) == 0 then local f = L.fontOf(self); return L.textWidth(st.text or "", f, f[2]) end
    return st.w or 0
  end
  function M:GetHeight()
    local st = S[self]
    local _, b, _, t = rect(self)
    if b then return (t - b) / effScale(self) end
    return st.h or 0
  end
  function M:GetSize() return self:GetWidth(), self:GetHeight() end
  function M:IsRectValid() return rect(self) ~= nil end
  function M:GetStringWidth() local st = S[self]; local f = L.fontOf(self); return L.textWidth(st.fs and S[st.fs].text or st.text or "", f, f[2]) end
  M.GetUnboundedStringWidth = M.GetStringWidth
  function M:GetStringHeight()
    local st = S[self]
    if st.fs then return M.GetStringHeight(st.fs) end
    if (st.text or "") == "" then return 0 end
    local f = L.fontOf(self)
    local l, _, r = rect(self)
    local lines = textLines(self, l and (r - l) / effScale(self) or nil)
    return #lines * (f[2] + (st.spacing or 0)) - (st.spacing or 0)
  end
  function M:GetLineHeight() local f = L.fontOf(self); return f[2] end
  function M:GetNumLines()
    local st = S[self]
    if st.type == "GameTooltip" then return #(st.lines or {}) end
    local l, _, r = rect(self)
    return #textLines(self, l and (r - l) / effScale(self) or nil)
  end
  function M:IsTruncated()
    local st = S[self]
    local f = L.fontOf(self)
    local l, b, r, t = rect(self)
    if not l then return false end
    local es = effScale(self)
    local lines, cut = L.layoutText(st.text or "", f, f[2], (r - l) / es, st.wordWrap, st.maxLines, st.nonSpaceWrap)
    if cut then return true end
    for _, ln in ipairs(lines) do if ln[2] > (r - l) / es + 0.5 then return true end end
    return #lines * f[2] > (t - b) / es + 0.5
  end
  function M:GetVerticalScrollRange()
    local st = S[self]
    local c = st.scrollChild
    if not c then return 0 end
    return math.max(0, M.GetHeight(c) - M.GetHeight(self))
  end
  function M:GetHorizontalScrollRange()
    local st = S[self]
    local c = st.scrollChild
    if not c then return 0 end
    return math.max(0, M.GetWidth(c) - M.GetWidth(self))
  end
  function M:GetEffectiveAlpha()
    local a, st = 1, S[self]
    while st do
      a = a * (st.alpha or 1)
      if st.ignoreAlpha then break end
      st = st.parent and S[st.parent]
    end
    return a
  end
  -- the mouse: a check (or a scene) can put it over a frame
  L.hover = nil
  function M:IsMouseOver(t, b, l, r)
    local cx, cy = L.mouse and L.mouse[1], L.mouse and L.mouse[2]
    if not cx then return false end
    local x0, y0, x1, y1 = rect(self)
    if not x0 then return false end
    return cx >= x0 - (l or 0) and cx <= x1 + (r or 0) and cy >= y0 - (b or 0) and cy <= y1 + (t or 0)
  end

  -- -------------------------------------------------------------------------
  -- model frames
  -- -------------------------------------------------------------------------
  local MODELTYPES = { Model = true, PlayerModel = true, DressUpModel = true, CinematicModel = true, TabardModel = true }
  local function mstate(self)
    local st = S[self]
    if not st.m then st.m = { log = {}, zoom = 0, cam = 1, scale = 1, pos = { 0, 0, 0 }, facing = 0 } end
    return st.m
  end
  -- every call on a model frame, with the frame's size on screen and whether it showed at that moment
  function L.mlog(self, name, ...)
    local st = S[self]
    local m = st and st.m
    if not m then return end
    local args = { ... }
    for i = 1, select("#", ...) do if type(args[i]) ~= "number" and type(args[i]) ~= "string" and type(args[i]) ~= "boolean" then args[i] = tostring(args[i]) end end
    local l, b, r, t = L.rect(self)
    m.log[#m.log + 1] = { t = W.now, call = name, args = args, size = l and { math.floor((r - l) * 10 + 0.5) / 10, math.floor((t - b) * 10 + 0.5) / 10 } or "none",
      visible = W.visible(self), scale = L.effScale(self) }
    if #m.log > 60 then table.remove(m.log, 1) end
  end
  local function displayFile(id)
    local d = L.models and L.models.display and L.models.display[id]
    return d and d[1]
  end
  L.displayFile = displayFile
  local function loadModel(self, m, kind, id, extra)
    m.kind, m.id, m.extra = kind, id, extra
    m.file, m.disp = nil, nil
    if kind == "display" then m.disp = id; m.file = displayFile(id)
    elseif kind == "creature" then
      local d = (tonumber(extra) and tonumber(extra) > 0 and tonumber(extra)) or (L.models and L.models.creature and L.models.creature[id])
      m.disp = d; m.file = d and displayFile(d)
    elseif kind == "unit" then m.unit = id
    elseif kind == "file" then m.file = tonumber(id) end
    m.setAt = W.now
    m.loaded = false
    m.serial = (m.serial or 0) + 1
    local serial = m.serial
    -- (no model data: every model loads; with it, only ones that exist)
    local ok = not L.models or kind == "unit" or m.file ~= nil
    if ok then
      W.schedule(W.now + 0.05, function()
        if m.serial ~= serial then return end
        m.loaded = true; m.loadedAt = W.now
        -- the game puts the camera back to the model's own on load
        L.mlog(self, "(model loaded)")
        W.runScript(self, "OnModelLoaded")
      end, nil, "a model loading")
    end
  end
  local function mmethod(name, fn)
    M[name] = function(self, ...)
      local st = S[self]
      if not MODELTYPES[st.type] then return end
      local m = mstate(self)
      L.mlog(self, name, ...)
      return fn(self, m, ...)
    end
  end
  mmethod("SetDisplayInfo", function(self, m, id) loadModel(self, m, "display", tonumber(id)) end)
  mmethod("SetCreature", function(self, m, id, disp) loadModel(self, m, "creature", tonumber(id), disp) end)
  mmethod("SetUnit", function(self, m, u) loadModel(self, m, "unit", u) end)
  mmethod("SetModel", function(self, m, f) loadModel(self, m, "file", f) end)
  mmethod("SetCustomRace", function(self, m, race, sex) m.race, m.sex = race, sex end)
  mmethod("ClearModel", function(self, m) m.kind, m.id, m.file, m.disp, m.unit, m.loaded = nil, nil, nil, nil, nil, false; m.serial = (m.serial or 0) + 1 end)
  mmethod("SetPortraitZoom", function(self, m, z) m.zoom = tonumber(z) or 0 end)
  mmethod("SetCamDistanceScale", function(self, m, s) m.cam = tonumber(s) or 1 end)
  mmethod("SetModelScale", function(self, m, s) m.scale = tonumber(s) or 1 end)
  mmethod("SetPosition", function(self, m, x, y, z) m.pos = { tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0 } end)
  mmethod("SetFacing", function(self, m, r) m.facing = tonumber(r) or 0 end)
  mmethod("SetAnimation", function(self, m, a) m.anim = tonumber(a) end)
  mmethod("SetSequence", function(self, m, a) m.anim = tonumber(a) end)
  mmethod("SetCamera", function(self, m, c) m.camera = c end)
  mmethod("RefreshCamera", function() end)
  mmethod("SetLight", function(self, m, ...) m.light = { ... } end)
  mmethod("TryOn", function(self, m, item) m.tryon = m.tryon or {}; m.tryon[#m.tryon + 1] = item end)
  mmethod("Undress", function(self, m) m.tryon = {} end)
  mmethod("Dress", function(self, m) m.tryon = nil end)
  mmethod("SetKeepModelOnHide", function(self, m, on) m.keep = on end)
  mmethod("SetPaused", function(self, m, on) m.paused = on end)
  mmethod("FreezeAnimation", function(self, m, a, v, f) m.anim, m.freeze = a, f end)
  mmethod("GetDisplayInfo", function(self, m) return m.disp end)
  mmethod("GetModelFileID", function(self, m)
    if not L.models then return nil end
    if m.kind == "unit" then return 1 end
    return m.loaded and m.file or nil
  end)
  mmethod("GetPortraitZoom", function(self, m) return m.zoom end)
  mmethod("GetCamDistanceScale", function(self, m) return m.cam end)
  mmethod("GetModelScale", function(self, m) return m.scale end)
  mmethod("GetPosition", function(self, m) return m.pos[1], m.pos[2], m.pos[3] end)
  mmethod("GetFacing", function(self, m) return m.facing end)
  -- (the generic logger for everything else a model frame is asked: it shows in the log for the camera work)
  local origShow, origHide = M.Show, M.Hide
  function M:Show() local st = S[self]; if st.m then L.mlog(self, "Show") end return origShow(self) end
  function M:Hide() local st = S[self]; if st.m then L.mlog(self, "Hide") end return origHide(self) end

  -- -------------------------------------------------------------------------
  -- the scene: what is on screen, in the order the game draws it
  -- -------------------------------------------------------------------------
  local function strataOf(w)
    local st = S[w]
    while st do if st.strataSet then return st.strata end st = st.parent and S[st.parent] end
    return "MEDIUM"
  end
  local function alphaOf(w)
    local a, st = 1, S[w]
    while st do
      a = a * (st.alpha or 1)
      if st.ignoreAlpha then break end
      st = st.parent and S[st.parent]
    end
    return a
  end
  local function inter(a, b)
    if not a then return b end
    if not b then return a end
    return { math.max(a[1], b[1]), math.max(a[2], b[2]), math.min(a[3], b[3]), math.min(a[4], b[4]) }
  end
  -- the clip rectangle a frame's content is cut to (its clipping ancestors, and scroll frames)
  local function clipOf(w, own)
    local c
    local st = S[w]
    local first = true
    local x = w
    while st do
      if (not first or own) and (st.clips or st.type == "ScrollFrame") then
        local l, b, r, t = rect(x)
        if l then c = inter(c, { l, b, r, t }) end
      end
      if st.scrollOf then
        local l, b, r, t = rect(st.scrollOf)
        if l then c = inter(c, { l, b, r, t }) end
      end
      first = false
      x = st.parent
      st = x and S[x]
    end
    return c
  end
  local function round(v) return math.floor(v * 100 + 0.5) / 100 end
  local function R(l, b, r, t) return { round(l), round(b), round(r), round(t) } end
  local function texRef(t)
    if t == nil then return nil end
    if type(t) == "number" then return t end
    return tostring(t)
  end

  -- Every visible frame, sorted as the game draws them: strata, frame level, then creation order.
  function L.scene(opts)
    opts = opts or {}
    local list = {}
    local root = opts.root
    for idx, f in ipairs(W.allFrames) do
      local st = S[f]
      if st and not st.owned and W.visible(f) and (not root or f == root or M.IsDescendantOf(f, root)) then
        list[#list + 1] = { f = f, strata = STRATA[strataOf(f)] or 3, level = st.level or 0, idx = idx }
      end
    end
    -- a child never draws under its parent: its level is at least one above
    local lv = {}
    local function levelOf(f)
      if lv[f] then return lv[f] end
      local st = S[f]
      local p = st.parent
      local l = st.level or 0
      if p and S[p] and not S[p].owned and strataOf(p) == strataOf(f) then l = math.max(l, levelOf(p) + 1) end
      lv[f] = l
      return l
    end
    for _, e in ipairs(list) do e.level = levelOf(e.f) end
    table.sort(list, function(a, b)
      if a.strata ~= b.strata then return a.strata < b.strata end
      if a.level ~= b.level then return a.level < b.level end
      return a.idx < b.idx
    end)
    local items = {}
    local hover = L.hover
    for _, e in ipairs(list) do
      local f, st = e.f, S[e.f]
      local l, b, r, t = rect(f)
      local fa = alphaOf(f)
      if l and fa > 0.001 then
        local clip = clipOf(f, false)
        local own = clipOf(f, true)
        local frameName = W.describe(f)
        local regs = {}
        -- backdrop (BackdropTemplate makes these textures in the frame's lowest sublevels)
        if st.backdrop then
          local bd = st.backdrop
          regs[#regs + 1] = { layer = 1, sub = -9, order = -2, item = { k = "backdrop", part = "bg", r = R(l, b, r, t), bg = texRef(bd.bgFile), edge = texRef(bd.edgeFile),
            edgeSize = bd.edgeSize or 0, tile = bd.tile or false, tileSize = bd.tileSize or 0, insets = bd.insets and { bd.insets.left or 0, bd.insets.right or 0, bd.insets.top or 0, bd.insets.bottom or 0 } or { 0, 0, 0, 0 },
            color = st.bdColor or { 1, 1, 1, 1 }, scale = effScale(f) } }
          regs[#regs + 1] = { layer = 2, sub = -9, order = -1, item = { k = "backdrop", part = "edge", r = R(l, b, r, t), bg = texRef(bd.bgFile), edge = texRef(bd.edgeFile),
            edgeSize = bd.edgeSize or 0, tile = bd.tile or false, tileSize = bd.tileSize or 0, insets = { 0, 0, 0, 0 },
            color = st.bdBorder or { 1, 1, 1, 1 }, scale = effScale(f) } }
        end
        -- which of a button's own textures show
        local roles = {}
        local isBtn = st.type == "Button" or st.type == "CheckButton"
        if isBtn or st.type == "StatusBar" or st.type == "Slider" then
          for _, k in ipairs({ "normalTex", "pushedTex", "disabledTex", "highlightTex", "checkedTex", "disabledcheckedTex", "statusbarTex", "thumbTex" }) do
            local tx = st[k]
            if tx and S[tx] then S[tx].roleOf = k; roles[tx] = k end
          end
        end
        local hovered = hover == f
        for order, rg in ipairs(st.regions) do
          local rs = S[rg]
          local role = roles[rg]
          local show = rs.shown and REGION[rs.type] and rs.type ~= "MaskTexture"
          if show and role then
            if role == "pushedTex" then show = false
            elseif role == "highlightTex" then show = hovered or st.lockHL
            elseif role == "disabledTex" then show = st.enabled == false
            elseif role == "normalTex" then show = not (st.enabled == false and st.disabledTex)
            elseif role == "checkedTex" then show = st.checked and not (st.enabled == false and st.disabledcheckedTex)
            elseif role == "disabledcheckedTex" then show = st.checked and st.enabled == false end
          end
          if show and rs.layer == "HIGHLIGHT" and not role then show = hovered or st.lockHL end
          if show then
            local rl, rb, rr, rt = rect(rg)
            local layer = LAYERS[rs.layer or (role == "highlightTex" and "HIGHLIGHT") or (rs.buttonText and "OVERLAY") or "ARTWORK"] or 3
            local ra = (rs.alpha or 1) * fa
            if rl and ra > 0.001 then
              local item
              if rs.type == "FontString" then
                local txt = rs.text or ""
                if txt ~= "" then
                  local font = L.fontOf(rg)
                  local es = effScale(rg)
                  local lines, cut = L.layoutText(txt, font, font[2], (rr - rl) / es, rs.wordWrap, rs.maxLines, rs.nonSpaceWrap)
                  lines = L.ellipsize(lines, font, font[2], (rr - rl) / es, cut)
                  local ls = {}
                  for i, ln in ipairs(lines) do ls[i] = { ln[1], round(ln[2] * es) } end
                  item = { k = "text", r = R(rl, rb, rr, rt), font = font[1], size = font[2] * es, flags = font[3] or "",
                    color = L.colorOf(rg), shadow = L.shadowOf(rg), jh = rs.jh or "CENTER", jv = rs.jv or "MIDDLE",
                    spacing = (rs.spacing or 0) * es, lines = ls, a = ra, scale = es, truncated = cut or nil }
                end
              elseif rs.type == "Texture" and (rs.tex ~= nil) then
                local vc = rs.vc
                if role == "statusbarTex" then vc = st.barColor or vc end
                item = { k = "tex", r = R(rl, rb, rr, rt), tex = rs.tex == "color" and "color" or texRef(rs.tex), color = rs.color,
                  vc = vc, a = ra, blend = rs.blend, tc = rs.tc8, rot = rs.rot, desat = rs.desat or nil, grad = rs.grad,
                  htile = rs.htile, vtile = rs.vtile, wrap = rs.wrap }
                if role == "statusbarTex" then
                  local mn, mx, v = st.min or 0, st.max or 0, st.value or 0
                  local fr = mx > mn and math.max(0, math.min(1, (v - mn) / (mx - mn))) or 0
                  local tc = rs.tc8 or { 0, 0, 0, 1, 1, 0, 1, 1 }
                  if st.orient == "VERTICAL" then
                    item.r = R(rl, rb, rr, rb + (rt - rb) * fr)
                    item.tc = { tc[1], 1 - fr, tc[3], tc[4], tc[5], 1 - fr, tc[7], tc[8] }
                  else
                    item.r = R(rl, rb, rl + (rr - rl) * fr, rt)
                    item.tc = { tc[1], tc[2], tc[3], tc[4], tc[1] + (tc[5] - tc[1]) * fr, tc[6], tc[3] + (tc[7] - tc[3]) * fr, tc[8] }
                  end
                end
                if rs.masks then
                  local ms = {}
                  for _, mk in ipairs(rs.masks) do
                    local ml, mb, mr, mt = rect(mk)
                    if ml and S[mk].tex then ms[#ms + 1] = { tex = texRef(S[mk].tex), r = R(ml, mb, mr, mt) } end
                  end
                  if #ms > 0 then item.masks = ms end
                end
              end
              if item then
                item.clip = own and R(own[1], own[2], own[3], own[4]) or nil
                item.frame = frameName
                regs[#regs + 1] = { layer = layer, sub = rs.sub or 0, order = order, item = item }
              end
            end
          end
        end
        table.sort(regs, function(a, b)
          if a.layer ~= b.layer then return a.layer < b.layer end
          if a.sub ~= b.sub then return a.sub < b.sub end
          return a.order < b.order
        end)
        for _, x in ipairs(regs) do
          if x.item.k == "backdrop" then x.item.clip = own and R(own[1], own[2], own[3], own[4]) or nil; x.item.frame = frameName; x.item.a = fa end
          items[#items + 1] = x.item
        end
        -- an edit box draws its own text
        if st.type == "EditBox" and (st.text or "") ~= "" then
          local font = L.fontOf(f)
          local es = effScale(f)
          local ins = st.insets or { 0, 0, 0, 0 }
          local txt = st.text
          if st.password then txt = string.rep("*", #txt) end
          local lines = L.layoutText(txt, font, font[2], st.multiLine and ((r - l) / es - ins[1] - ins[2]) or nil, st.multiLine)
          local ls = {}
          for i, ln in ipairs(lines) do ls[i] = { ln[1], round(ln[2] * es) } end
          items[#items + 1] = { k = "text", r = R(l + ins[1] * es, b + ins[4] * es, r - ins[2] * es, t - ins[3] * es), font = font[1], size = font[2] * es,
            flags = font[3] or "", color = L.colorOf(f), shadow = L.shadowOf(f), jh = st.jh or "LEFT", jv = st.multiLine and "TOP" or "MIDDLE",
            spacing = 0, lines = ls, a = fa, clip = R(l, b, r, t), frame = frameName }
        end
        -- a model frame's model (drawn over its own textures)
        if st.m and (st.m.kind) then
          local m = st.m
          items[#items + 1] = { k = "model", r = R(l, b, r, t), a = fa, clip = clip and R(clip[1], clip[2], clip[3], clip[4]) or nil, frame = frameName,
            kind = m.kind, id = m.id, disp = m.disp, file = m.file, unit = m.unit, race = m.race, sex = m.sex, loaded = m.loaded,
            zoom = m.zoom, cam = m.cam, scale = m.scale, pos = m.pos, facing = m.facing, anim = m.anim, tryon = m.tryon,
            es = effScale(f), setAt = m.setAt, loadedAt = m.loadedAt, now = W.now, log = m.log,
            player = m.kind == "unit" and { race = W.me.race, class = W.me.class, sex = 2 } or nil }
        end
      end
    end
    return { screen = { SWID, SHGT }, time = W.now, items = items, mouse = L.mouse }
  end

  function L.writeScene(path, opts)
    local sc = L.scene(opts)
    sc.name = opts and opts.name
    -- marks: labelled boxes to cut out and check later (a card's name and where it is)
    if opts and opts.marks then
      sc.marks = {}
      for _, mk in ipairs(opts.marks) do
        local l, b, r, t = rect(mk.frame)
        if l and W.visible(mk.frame) then
          local e = { label = mk.label, r = { l, b, r, t }, info = mk.info }
          -- the model frames inside it, with the size each had when its camera was last set
          local models = {}
          local function walk(f)
            local st = S[f]
            if st.m and st.m.kind and W.visible(f) then
              local ml, mb, mr, mt = rect(f)
              models[#models + 1] = { r = ml and { ml, mb, mr, mt } or nil, disp = st.m.disp, kind = st.m.kind, id = st.m.id, loaded = st.m.loaded }
            end
            for _, c in ipairs(st.children) do walk(c) end
          end
          walk(mk.frame)
          if #models > 0 then e.models = models end
          sc.marks[#sc.marks + 1] = e
        end
      end
    end
    local fh = assert(io.open(path, "wb"))
    fh:write(W.json(sc))
    fh:close()
    return #sc.items
  end
end

return L
