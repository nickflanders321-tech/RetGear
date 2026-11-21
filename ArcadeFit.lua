local _, RG = ...
-- Waypath Cards: every text fits where it's drawn. Loaded last, so it sees each card after every other file's touches
-- (a Mythic's type line, a Gilded name...):
--   * a card's type line and its rules are made a little smaller until the whole of them fits
--   * RG.ArcadeFitLine: one line of text made smaller until it fits its width (the window's message line)
--   * RG.ArcadeFitRow: a list row's left text made smaller until it fits beside the right one (Sets, Trade, Ledger...)
local function UI() return RG.ArcadeUI end
local function sizeOf(t)
  if rawget(t, "fkey") then return rawget(t, "fsize") or 12 end
  local _, sz = t:GetFont()
  return sz or 12
end
local function width(t)
  local w = t.GetUnboundedStringWidth and t:GetUnboundedStringWidth() or t:GetStringWidth()
  return type(w) == "number" and w or 0
end
-- set a text's size, in its own font (one made by the window's fs() keeps its kind of font; any other keeps its face)
local function resize(t, key, sz)
  local u = UI()
  if rawget(t, "fkey") and u and u.setfont then u.setfont(t, rawget(t, "fkey") or key, sz, rawget(t, "fflags"))
  else
    local path, _, flags = t:GetFont()
    if path then t:SetFont(path, sz, flags or "") end
  end
  t:SetText(t:GetText() or "")
end
-- smaller, half a point at a time, until fits() or the floor
local function shrink(t, key, floor, fits)
  local sz = sizeOf(t)
  for _ = 1, 24 do
    if fits() or sz <= floor then return end
    sz = math.max(floor, sz - 0.5)
    resize(t, key, sz)
  end
end

-- (size: the text's own size to start from; without one, the size it had the first time it was fitted)
function RG.ArcadeFitLine(t, maxW, size, floor, key)
  if not t then return end
  local base = size or rawget(t, "fitBase") or sizeOf(t)
  rawset(t, "fitBase", base)
  if sizeOf(t) ~= base then resize(t, key or "body", base) end
  shrink(t, key or "body", floor or 10, function() return width(t) <= maxW + 0.5 end)
end

-- a list row: the right text keeps its size; the left one fits in the rest (and is cut short with "..." only below 11)
function RG.ArcadeFitRow(b)
  if not (b and b.left and b.right) or rawget(b, "fitting") then return end
  rawset(b, "fitting", true)   -- (setting the text again below calls back here)
  pcall(function()
    local u = UI()
    local total = (b.GetWidth and b:GetWidth()) or 0
    if type(total) ~= "number" or total <= 0 then return end
    local rw = width(b.right)
    local room = total - 20 - (rw > 0 and (rw + 16) or 0)
    if u and u.setfont then u.setfont(b.left, "body", 14); b.left:SetText(b.left:GetText() or "") end
    b.left:SetWidth(room); if b.left.SetWordWrap then b.left:SetWordWrap(false) end
    shrink(b.left, "body", 11, function() return width(b.left) <= room + 0.5 end)
  end)
  rawset(b, "fitting", nil)
end

-- a box's text: smaller until it fits the box's height
function RG.ArcadeFitBox(t, room)
  if not (t and t.GetStringHeight) then return end
  shrink(t, "body", 11, function() local h = t:GetStringHeight(); return type(h) ~= "number" or h <= room + 0.5 end)
end

-- the card: its type line, and a big card's rules
RG.ArcadeCardHooks = RG.ArcadeCardHooks or {}
table.insert(RG.ArcadeCardHooks, function(w, card, finish)
  if not card or not finish then return end
  local u = w.u or 1
  local ty = w.type
  if ty and ty:IsShown() and (ty:GetText() or "") ~= "" then
    shrink(ty, "head", 6, function() return width(ty) <= 226 * u + 0.5 end)
  end
  local tx = w.text
  if (w.cw or 0) >= 120 and tx and tx:IsShown() and tx.IsTruncated and (tx:GetText() or "") ~= "" then
    shrink(tx, "body", (w.cw or 0) >= 190 and math.max(8, 9 * u) or 6, function() return not tx:IsTruncated() end)
  end
  -- (a big card's two-line name, if the game still cuts it short)
  local nm = w.name
  if (w.cw or 0) >= 190 and nm and nm.IsTruncated and (nm:GetText() or "") ~= "" then
    shrink(nm, "title", 7, function() return not nm:IsTruncated() end)
  end
end)
