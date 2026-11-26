local _, RG = ...
-- Waypath+ step view and drop rates.
--   * Drop rates: how often a quest's items drop and from what (Objectives.lua carries them, from Polestar forever-db's
--     item sources and the cMaNGOS loot tables). Shown in the tracker's tooltips (RG.DropTip) and in the step view.
--   * The step view (Settings: "Detailed step view", or /wp stepview): a panel that explains what to do right now. The
--     quest and what to do for it, where, how often its items drop, a 3D model of the mob (or the item's icon, or the
--     quest giver) to look for, how far it is, and what comes after. It follows the tracker's top line (RG.Objective).
-- Models are only asked for out in the world: never inside an instance (as the card game does, see v1.60.2).
local GOLD, GREY, GREEN = RG.COLORS.GOLD, RG.COLORS.GREY, RG.COLORS.GREEN
local GOLDC = RG.ACCENT or { 0.847, 0.71, 0.416 }

table.insert(RG.OPTIONS, { key = "stepView", label = "Detailed step view: a panel that explains the current step, with the mob, item or quest giver to look for and how often its items drop", default = false })

-- ---------------------------------------------------------------------------------------------------------------------
-- Drop rates
-- ---------------------------------------------------------------------------------------------------------------------
local function pct(c)
  if not c or c <= 0 then return nil end
  if c >= 10 then return string.format("%d%%", math.floor(c + 0.5)) end
  return (string.format("%.1f", c):gsub("%.0$", "")) .. "%"
end
-- "80% from Riverpaw Gnoll, Riverpaw Mongrel and 2 more", or "Burning Blade Fanatic 20%, Burning Blade Apprentice 5%"
local function dropPhrase(mobs, chances)
  if not (mobs and chances) then return nil end
  local list = {}
  for i, name in ipairs(mobs) do if chances[i] and chances[i] > 0 then list[#list + 1] = { name, chances[i] } end end
  if #list == 0 then return nil end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  local same = true
  for _, x in ipairs(list) do if pct(x[2]) ~= pct(list[1][2]) then same = false end end
  if same then
    local names = {}
    for i = 1, math.min(2, #list) do names[i] = list[i][1] end
    local more = #list > 2 and (" and " .. (#list - 2) .. " more") or ""
    return pct(list[1][2]) .. " from " .. table.concat(names, #list == 2 and " and " or ", ") .. more
  end
  local parts = {}
  for i = 1, math.min(3, #list) do parts[i] = list[i][1] .. " " .. pct(list[i][2]) end
  return table.concat(parts, ", ") .. (#list > 3 and (", " .. (#list - 3) .. " more") or "")
end
RG.DropPhrase = dropPhrase
-- The quest's items and how they drop: { { item = name, text = phrase }, ... } (only objectives with known rates).
-- label: just the objective with that name (the quest log's wording may differ a little: a match either way counts).
function RG.DropInfo(id, label)
  local d = id and RG.QDATA and RG.QDATA[id]
  if not d then return {} end
  local out, want = {}, label and label:lower()
  for _, o in ipairs(d.o or {}) do
    if o[1] == "i" and o[7] then
      local name = tostring(o[2] or "?")
      local l = name:lower()
      if not want or l == want or want:find(l, 1, true) or l:find(want, 1, true) then
        local text = dropPhrase(o[3], o[7])
        if text then out[#out + 1] = { item = name, text = text } end
      end
    end
  end
  -- a quest that starts from an item: how often that drops
  local si = d.si
  if not label and si and si[1] == "i" and si[8] then
    local text = dropPhrase(si[3], si[8])
    if text then out[#out + 1] = { item = tostring(si[2]), text = text, starts = true } end
  end
  return out
end
-- A tooltip section for a quest's drop rates ("" when nothing is known).
function RG.DropTip(id, label)
  local info = RG.DropInfo(id, label)
  if #info == 0 then return "" end
  local t = {}
  for _, x in ipairs(info) do
    t[#t + 1] = "|cffe6e6e6" .. x.item .. (x.starts and " (starts the quest)" or "") .. ":|r " .. GREY .. x.text .. "|r"
  end
  return "\n\n" .. GOLD .. "Drops:|r\n" .. table.concat(t, "\n")
end

-- ---------------------------------------------------------------------------------------------------------------------
-- What to look for: the NPC (a 3D model), or the item's icon
-- ---------------------------------------------------------------------------------------------------------------------
-- the quest's objective the planner points at (its kind and label), else its first one of that kind
local function objectiveOf(d, okind, label)
  if not (d and d.o) then return nil end
  local want = label and tostring(label):lower()
  local first
  for _, o in ipairs(d.o) do
    if not okind or o[1] == okind then
      first = first or o
      local l = tostring(o[2] or ""):lower()
      if want and (l == want or want:find(l, 1, true) or (l ~= "" and l:find(want, 1, true))) then return o end
    end
  end
  return first
end
-- { npc = id, name = label, icon = file id or path } for the thing to do now
local function lookFor(obj, it)
  local d = it and it.id and RG.QDATA and RG.QDATA[it.id]
  if not d then return nil end
  if it.act == "turnin" then
    local e = d.e
    return e and { npc = e[5], name = e[4] } or nil
  elseif it.act == "pickup" then
    if d.s then return { npc = d.s[5], name = d.s[4] } end
    local si = d.si
    if si then
      local npc = si[6] and si[6][1]
      return { npc = npc, name = npc and si[3] and si[3][1] or si[2], icon = (si[1] == "i" and si[7]) and (GetItemIcon and GetItemIcon(si[7])) or nil, item = si[1] == "i" and si[2] or nil }
    end
    return nil
  end
  local o = objectiveOf(d, it.okind, it.label)
  if not o then return nil end
  local npc = o[5] and o[5][1]
  local icon = (o[1] == "i" and o[6] and GetItemIcon) and GetItemIcon(o[6]) or nil
  return { npc = (o[1] ~= "o") and npc or nil, name = (npc and o[3] and o[3][1]) or o[2], icon = icon, item = o[1] == "i" and o[2] or nil, obj = o }
end

-- ---------------------------------------------------------------------------------------------------------------------
-- The panel
-- ---------------------------------------------------------------------------------------------------------------------
local W, MODEL = 340, 104
local f, rows, model
local function inInstance() return IsInInstance and select(1, IsInInstance()) and true or false end
local function newText(parent, size, kind)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  if RG.Font then RG.Font(fs, kind or "medium", size) else fs:SetFontObject("GameFontHighlightSmall") end
  fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP")
  return fs
end
local function build()
  if f then return f end
  f = CreateFrame("Frame", "WaypathStepView", UIParent, "BackdropTemplate")
  f:SetWidth(W); f:SetHeight(120); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:SetFrameStrata("MEDIUM")
  if RG.Round then RG.Round(f, 0.063, 0.11, 0.153, (RG.db and RG.db.trackerAlpha) or 0.85, 8) end
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not (RG.Opt and RG.Opt("trackerLocked")) then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint(1)
    if p and RG.db then RG.db.stepViewPos = { p, rp, math.floor(x + 0.5), math.floor(y + 0.5) } end
  end)
  local function place(self)
    local p = RG.db and RG.db.stepViewPos
    self:ClearAllPoints()
    if p then self:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else self:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -360, -260) end
  end
  place(f)
  if RG.RegisterMover then
    RG.RegisterMover(f, "stepView", "Step view", nil, nil, { own = {
      apply = place,
      save = function(self) local p, _, rp, x, y = self:GetPoint(1); if p then RG.db.stepViewPos = { p, rp, math.floor(x + 0.5), math.floor(y + 0.5) } end end,
      reset = function() RG.db.stepViewPos = nil end,
    } })
  end
  -- header: what to do, and how far
  f.verb = newText(f, 13, "bold"); f.verb:SetPoint("TOPLEFT", 12, -10)
  f.title = newText(f, 13, "semibold"); f.title:SetPoint("LEFT", f.verb, "RIGHT", 6, 0); f.title:SetPoint("RIGHT", f, "RIGHT", -12, 0)
  f.title:SetWordWrap(false); f.title:SetTextColor(0.937, 0.902, 0.824)
  f.where = newText(f, 11); f.where:SetPoint("TOPLEFT", f.verb, "BOTTOMLEFT", 0, -3); f.where:SetPoint("RIGHT", f, "RIGHT", -12, 0)
  f.where:SetTextColor(0.79, 0.75, 0.66); f.where:SetWordWrap(false)
  local line = f:CreateTexture(nil, "ARTWORK"); line:SetHeight(1); line:SetPoint("TOPLEFT", 10, -44); line:SetPoint("TOPRIGHT", -10, -44)
  line:SetColorTexture(GOLDC[1], GOLDC[2], GOLDC[3], 0.35)
  -- the body: one text, wrapped (quests, objectives, drop rates, why), beside the picture
  f.body = newText(f, 12); f.body:SetPoint("TOPLEFT", 12, -52); f.body:SetWidth(W - MODEL - 34); f.body:SetSpacing(2)
  -- the picture: a 3D model of the NPC, or an icon
  f.pic = CreateFrame("Frame", nil, f); f.pic:SetSize(MODEL, MODEL + 6); f.pic:SetPoint("TOPRIGHT", -10, -50)
  local bg = f.pic:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.25)
  f.icon = f.pic:CreateTexture(nil, "ARTWORK"); f.icon:SetSize(44, 44); f.icon:SetPoint("CENTER", 0, 6); f.icon:Hide()
  f.picName = newText(f, 10); f.picName:SetPoint("TOP", f.pic, "BOTTOM", 0, -3); f.picName:SetWidth(MODEL + 10); f.picName:SetJustifyH("CENTER")
  f.picName:SetTextColor(0.79, 0.75, 0.66)
  -- the footer: how far, and what's next
  f.foot = newText(f, 11); f.foot:SetPoint("BOTTOMLEFT", 12, 10); f.foot:SetPoint("RIGHT", f, "RIGHT", -12, 0); f.foot:SetTextColor(0.79, 0.75, 0.66)
  -- click: the arrow to it; right-click: hide the view
  f:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then RG.db.stepView = false; RG.RefreshStepView(); RG.Print("Step view off. Turn it back on in Settings or with /wp stepview.") return end
    if self.wp and RG.Follow then RG.Follow(self.wp) end
  end)
  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Waypath+ step view", 1, 0.93, 0.74)
    GameTooltip:AddLine("Click: the arrow to this step", 1, 1, 1)
    GameTooltip:AddLine("Drag: move it  ·  right-click: hide it", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f:Hide()
  return f
end

-- the model: asked for once per NPC, checked a moment later (the game may still be fetching it); the icon otherwise
local modelTry = 0
local function showModel(npc, icon)
  if npc and not inInstance() then
    if not model then
      local ok, m = pcall(CreateFrame, "DressUpModel", nil, f.pic)
      if ok and m then model = m; m:SetPoint("TOPLEFT", 2, -2); m:SetPoint("BOTTOMRIGHT", -2, 2) end
    end
    if model and model.SetCreature then
      if model.cur ~= npc then
        model.cur, modelTry = npc, 0
        if model.ClearModel then pcall(model.ClearModel, model) end
        local ok = pcall(model.SetCreature, model, npc)
        if ok then
          if model.SetPortraitZoom then pcall(model.SetPortraitZoom, model, 0) end
          if model.SetFacing then pcall(model.SetFacing, model, 0.45) end
          -- not there yet? look again shortly, twice at most; then the icon
          local function check()
            if not (model and model.cur == npc) then return end
            local okF, fid = false, nil
            if model.GetModelFileID then okF, fid = pcall(model.GetModelFileID, model) end
            if okF and (not fid or fid == 0) and modelTry < 2 then
              modelTry = modelTry + 1; pcall(model.SetCreature, model, npc); C_Timer.After(1, check)
            elseif okF and (not fid or fid == 0) then
              model.bad = model.bad or {}; model.bad[npc] = true; model:Hide()
              if icon then f.icon:SetTexture(icon); f.icon:Show() end
            end
          end
          if C_Timer and C_Timer.After then C_Timer.After(0.6, check) end
        else model.cur = nil end
      end
      if model.cur == npc and not (model.bad and model.bad[npc]) then model:Show(); f.icon:Hide(); return true end
    end
  end
  if model then model:Hide() end
  if icon then f.icon:SetTexture(icon); f.icon:Show() else f.icon:Hide() end
  return icon ~= nil
end

local VERB = { turnin = { "Hand in", "|cff8be0a4" }, pickup = { "Pick up", "|cffffd100" }, doing = { "Do", "|cff9fd4ff" } }
local function zoneName(map)
  local i = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  return i and i.name
end
-- what one task of the stop says, with its progress and drop rates
local function taskLines(it, out)
  local d = it.id and RG.QDATA and RG.QDATA[it.id]
  out[#out + 1] = "|cffffffff" .. tostring(it.title or (d and d.n) or "?") .. "|r"
  if it.act == "turnin" then
    out[#out + 1] = GREEN .. "  Done: hand it in" .. ((it.label and it.label ~= "") and (" to " .. it.label) or "") .. "|r"
  elseif it.act == "pickup" then
    local how
    if d and not d.s and d.si then
      local si = d.si
      how = si[1] == "o" and ("Click " .. tostring(si[2]) .. " to start it") or ("Loot " .. tostring(si[2]) .. ((si[3] and si[3][1]) and (" from " .. si[3][1]) or "") .. ": it starts the quest")
    end
    out[#out + 1] = GREY .. "  " .. (how or ("Pick it up" .. ((it.label and it.label ~= "") and (" from " .. it.label) or ""))) .. "|r"
  else
    local verb = ({ k = "Kill", i = "Collect", o = "Use" })[it.okind or ""] or "Get"
    local prog = (it.need and it.need > 0) and (" " .. (it.have or 0) .. "/" .. it.need) or ""
    local done = it.need and it.have and it.need > 0 and it.have >= it.need
    out[#out + 1] = (done and GREEN or "|cffe6e6e6") .. "  " .. verb .. " " .. tostring(it.label or "") .. "|r" .. (done and GREEN or GOLD) .. prog .. "|r"
  end
  if it.act ~= "turnin" then
    for _, x in ipairs(RG.DropInfo(it.id, it.act == "doing" and it.label or nil)) do
      out[#out + 1] = GREY .. "  " .. (x.starts and (x.item .. ": ") or "Drops ") .. x.text .. "|r"
    end
  end
end

function RG.RefreshStepView()
  local want = RG.Opt and RG.Opt("stepView") and not (RG.CardsOnly and RG.CardsOnly())
  if not want then if f then f:Hide() end return end
  build()
  local obj = RG.Objective and RG.Objective()
  if not obj then f:Hide() return end
  local it = obj.stop and obj.stop.items and obj.stop.items[1]
  -- header
  local v = (it and VERB[it.act]) or (obj.kind == "route" and { "Go", "|cffffd100" }) or (obj.kind == "dungeon" and { "In", "|cff9fd4ff" }) or { "Next", "|cffffd100" }
  f.verb:SetText(v[2] .. v[1] .. "|r")
  local titles = {}
  for _, x in ipairs(obj.stop and obj.stop.items or {}) do
    local t = tostring(x.title or "")
    local seen = false
    for _, y in ipairs(titles) do if y == t then seen = true end end
    if not seen and t ~= "" then titles[#titles + 1] = t end
  end
  f.title:SetText(#titles > 0 and table.concat(titles, ", ") or tostring(obj.text or ""))
  local zone = obj.wp and zoneName(obj.wp[1])
  local eta = obj.dist and (RG.FormatYards and RG.FormatYards(math.floor(obj.dist)) or (math.floor(obj.dist) .. " yd"))
  f.where:SetText((zone or "") .. ((zone and eta) and "  ·  " or "") .. (eta or ""))
  -- body
  local out = {}
  if obj.stop and obj.stop.items then
    for i = 1, math.min(3, #obj.stop.items) do taskLines(obj.stop.items[i], out) end
    if #obj.stop.items > 3 then out[#out + 1] = GREY .. "+" .. (#obj.stop.items - 3) .. " more here|r" end
  else
    out[#out + 1] = "|cffffffff" .. tostring(obj.text or "") .. "|r"
  end
  -- why here, and the one thing people get wrong about the quest (QuestNotes.lua)
  if obj.why and obj.why ~= "" then out[#out + 1] = GREY .. obj.why .. "|r" end
  local qn = it and it.id and RG.QuestNote and RG.QuestNote(it.id)
  if qn and qn.n then out[#out + 1] = "|cffff9f43" .. qn.n .. "|r" end
  f.body:SetText(table.concat(out, "\n"))
  -- the picture
  local look = lookFor(obj, it)
  local shown = look and showModel(look.npc, look.icon or (look.item and 134400) or nil)
  f.pic:SetShown(shown and true or false)
  f.picName:SetText(shown and look and look.name or "")
  f.body:SetWidth(shown and (W - MODEL - 34) or (W - 24))
  -- footer: nearest, and next
  local foot = {}
  if look and look.name and obj.dist and it and it.act == "doing" then foot[#foot + 1] = "Nearest " .. look.name .. ": " .. eta end
  if obj.nextText then foot[#foot + 1] = GOLD .. "Next:|r " .. obj.nextText end
  f.foot:SetText(table.concat(foot, "\n"))
  f.wp = obj.wp
  local h = 52 + math.max(f.body:GetStringHeight() or 0, shown and (MODEL + 20) or 0) + 12 + ((f.foot:GetStringHeight() or 0) > 0 and ((f.foot:GetStringHeight() or 0) + 8) or 0)
  f:SetHeight(math.max(90, h))
  f:Show()
end

-- kept up to date: a second's tick (the objective itself is worked out at most every couple of seconds), and straight
-- away when the option changes
do
  local tick = function() if f or (RG.Opt and RG.Opt("stepView")) then pcall(RG.RefreshStepView) end end
  if RG.PerfWrap then tick = RG.PerfWrap("stepView", tick) end
  local boot = CreateFrame("Frame")
  boot:RegisterEvent("PLAYER_ENTERING_WORLD")
  boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(1, tick) end
    tick()
  end)
end

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "stepview" then
    RG.db.stepView = not (RG.Opt and RG.Opt("stepView"))
    RG.Print("Step view " .. (RG.db.stepView and "on: drag it where you want it, right-click to hide it." or "off."))
    RG.RefreshStepView()
    return
  end
  return base(msg)
end
