-- Waypath+ leveling report: what each level took. Kept per character in RG.db.levelLog[level] =
--   { t = seconds played (not AFK), q = quest XP, k = other XP (kills, exploring), g = gold change, d = deaths, n = quests }
-- At each level-up one line in chat compares it with your average; /wp levels shows the last levels in a box.
local _, RG = ...

local function log()
  RG.db.levelLog = RG.db.levelLog or {}
  return RG.db.levelLog
end
local function cur()
  local lvl = UnitLevel and UnitLevel("player") or 1
  local l = log()
  local e = l[lvl]
  if not e then e = { t = 0, q = 0, k = 0, g = 0, d = 0, n = 0 }; l[lvl] = e end
  return e, lvl
end

local lastXP, lastMax, lastMoney
local questXP = 0   -- XP from the quest just turned in (the XP update that follows isn't counted twice)
local function onXP()
  local ok, xp, max = pcall(function() return UnitXP("player"), UnitXPMax("player") end)
  if not ok or (RG.IsSecret and (RG.IsSecret(xp) or RG.IsSecret(max))) then return end
  if lastXP then
    local gained = xp >= lastXP and (xp - lastXP) or ((lastMax or 0) - lastXP + xp)
    if gained > 0 and gained < 500000 then
      local e = cur()
      local fromQuest = math.min(gained, questXP)
      questXP = questXP - fromQuest
      e.q = e.q + fromQuest
      e.k = e.k + (gained - fromQuest)
    end
  end
  lastXP, lastMax = xp, max
end
local function onMoney()
  local m = GetMoney and GetMoney() or 0
  if lastMoney then cur().g = cur().g + (m - lastMoney) end
  lastMoney = m
end

local function fmtTime(sec)
  local m = math.floor((sec or 0) / 60 + 0.5)
  if m < 60 then return m .. " min" end
  return string.format("%dh %02dm", math.floor(m / 60), m % 60)
end
local function money(c)
  if c == 0 then return "0" end
  return (c > 0 and "+" or "-") .. RG.Money(math.abs(c))
end
-- the average time of the levels around this one that have a full record (at least 5 minutes, at most 10 levels back)
local function average(level)
  local l, sum, n = log(), 0, 0
  for lv = level - 1, math.max(1, level - 10), -1 do
    local e = l[lv]
    if e and e.done and e.t >= 300 then sum = sum + e.t; n = n + 1 end
  end
  return n >= 2 and sum / n or nil
end
function RG.LevelLine(level)
  local e = log()[level]
  if not e then return nil end
  local xp = e.q + e.k
  local qp = xp > 0 and math.floor(e.q / xp * 100 + 0.5) or 0
  local avg = average(level)
  local cmp = ""
  if avg and e.t > 0 then
    local d = (e.t - avg) / avg
    cmp = math.abs(d) < 0.1 and " (about your average)" or string.format(" (%d%% %s than your average of %s)", math.floor(math.abs(d) * 100 + 0.5), d < 0 and "faster" or "slower", fmtTime(avg))
  end
  return string.format("Level %d took %s%s: %d%% of the XP from quests, %d%% from kills and exploring; %d quest%s, %s gold, %d death%s.",
    level, fmtTime(e.t), cmp, qp, 100 - qp, e.n, e.n == 1 and "" or "s", money(e.g), e.d, e.d == 1 and "" or "s")
end

-- /wp levels: the last levels in a box
function RG.ShowLevels()
  local l = log()
  local lines = { "Your levels (time played, not counting AFK):", "" }
  local top = UnitLevel and UnitLevel("player") or 1
  local any = false
  for lv = top, math.max(1, top - 19), -1 do
    local e = l[lv]
    if e and (e.t > 0 or e.q + e.k > 0) then
      any = true
      local xp = e.q + e.k
      lines[#lines + 1] = string.format("%2d  %-8s %3d%% XP from quests  %3d quest%s  %8s  %d death%s%s", lv, fmtTime(e.t),
        xp > 0 and math.floor(e.q / xp * 100 + 0.5) or 0, e.n, e.n == 1 and " " or "s", money(e.g):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""), e.d, e.d == 1 and "" or "s", e.done and "" or "  (so far)")
    end
  end
  if not any then lines[#lines + 1] = "Nothing yet: Waypath+ starts counting from now." end
  RG.ShowErrors(table.concat(lines, "\n"), "Waypath+ leveling report")
end

do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "PLAYER_DEAD", "PLAYER_MONEY" }) do pcall(f.RegisterEvent, f, e) end
  f:SetScript("OnEvent", function(_, ev, a1, a2)
    if not RG.db or (RG.IsAlt and RG.IsAlt()) then return end
    if ev == "PLAYER_ENTERING_WORLD" then
      lastMoney = GetMoney and GetMoney() or 0
      local ok, xp, max = pcall(function() return UnitXP("player"), UnitXPMax("player") end)
      if ok then lastXP, lastMax = xp, max end
    elseif ev == "PLAYER_XP_UPDATE" then onXP()
    elseif ev == "QUEST_TURNED_IN" then
      local e = cur(); e.n = e.n + 1
      if type(a2) == "number" and not (RG.IsSecret and RG.IsSecret(a2)) then questXP = questXP + a2 end
      onXP()
    elseif ev == "PLAYER_DEAD" then cur().d = cur().d + 1
    elseif ev == "PLAYER_MONEY" then onMoney()
    elseif ev == "PLAYER_LEVEL_UP" then
      -- a1 is the new level: the one before it is finished
      local done = (tonumber(a1) or ((UnitLevel and UnitLevel("player") or 2))) - 1
      local e = log()[done]
      if e then
        e.done = true
        if RG.Opt and RG.Opt("levelReport") and e.t >= 120 then
          C_Timer.After(2, function() local line = RG.LevelLine(done); if line then RG.Print(line .. " |cff808080(/wp levels)|r") end end)
        end
      end
    end
  end)
  -- time played, every 30 seconds you're not AFK (and not at max level)
  if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(30, function()
      if not RG.db or (RG.IsAlt and RG.IsAlt()) then return end
      if RG.SafeCall and RG.SafeCall(UnitIsAFK, "player") then return end
      if (UnitLevel("player") or 60) >= 60 then return end
      cur().t = cur().t + 30
    end)
  end
end

table.insert(RG.OPTIONS, { key = "levelReport", label = "At each level-up, one line on how long the level took and where the XP came from (/wp levels for the history)", default = true })

local base = SlashCmdList.WAYPATH
SlashCmdList.WAYPATH = function(msg)
  local cmd = (msg or ""):match("^%s*(%S+)")
  if cmd and (cmd:lower() == "levels" or cmd:lower() == "level") then RG.ShowLevels(); return end
  return base(msg)
end
