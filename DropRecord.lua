local _, RG = ...
-- Waypath+ drop rates you count yourself.
-- Where the quest data knows which mobs drop a quest's item but not how often (WoW Forever's own zones, mostly: no open
-- loot table has them yet), the add-on counts it while you're on the quest: every one of those mobs you kill, and every
-- one of the item you loot from them. The counts are account-wide (RG.db.drops[item][npc] = { kills, drops }), so an
-- alt doing the quest adds to them. A rate is shown (RG.DropInfo, StepView.lua) once a mob has MIN_KILLS kills, marked
-- as yours; a rate in the quest data always wins over a counted one.
-- Kills: the combat log is closed to add-ons on this client, so a kill is read from the corpse after the fight, as the
-- card game's Field Guide does (ArcadeFieldGuide.lua): your target, mouse-over or a nameplate that's dead and was yours
-- (not tapped by someone else), or a corpse you loot.
local MIN_KILLS = 10

local function safe(fn, ...) local ok, v = pcall(fn, ...); if ok and v ~= nil and not (RG.IsSecret and RG.IsSecret(v)) then return v end end
local function npcOfGuid(g)
  if type(g) ~= "string" or (RG.IsSecret and RG.IsSecret(g)) then return nil end
  local kind, _, _, _, _, id = strsplit("-", g)
  if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
  return tonumber(id)
end

-- What to count: creature id -> { [item id] = true }, the items of quests in your log that you still need, where the
-- quest data names the mobs but has no rate. Rebuilt when the quest log changes.
local watch, any = {}, false
local function rebuild()
  watch, any = {}, false
  if not (RG.db and RG.QDATA and RG.LogQuestInfos) then return end
  if RG.CardsOnly and RG.CardsOnly() then return end
  for _, info in ipairs(RG.LogQuestInfos()) do
    local qid = info.questID
    local d = qid and RG.QDATA[qid]
    if d and d.o then
      local objs = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(qid) or {}
      for _, o in ipairs(d.o) do
        if o[1] == "i" and not o[7] and type(o[6]) == "number" and o[5] and #o[5] > 0 then
          -- still needed: the quest log's line for it isn't finished (no line found: the quest isn't complete)
          local need, name, found = true, tostring(o[2] or ""):lower(), false
          for _, l in ipairs(objs) do
            local t = type(l.text) == "string" and l.text:lower()
            if t and name ~= "" and t:find(name, 1, true) then found = true; need = not l.finished end
          end
          if not found and C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(qid) then need = false end
          if need then
            for _, nid in ipairs(o[5]) do
              watch[nid] = watch[nid] or {}
              watch[nid][o[6]] = true
              any = true
            end
          end
        end
      end
    end
  end
end

local function rec(item, nid)
  local all = RG.db.drops or {}; RG.db.drops = all
  local byNpc = all[item] or {}; all[item] = byNpc
  local r = byNpc[nid] or { 0, 0 }; byNpc[nid] = r
  return r
end

-- a corpse counts once (also across a /reload: the last few are remembered)
local killed = {}     -- GUID -> { [item] = true }: what it was counted for
local dropped = {}    -- GUID .. item -> true: its drop is counted
local function kill(nid, guid)
  if not (nid and guid and RG.db) then return nil end
  if killed[guid] then return killed[guid] end
  local items = watch[nid]
  if not items then return nil end
  local seen = RG.db.dropGuids or {}; RG.db.dropGuids = seen
  for _, g in ipairs(seen) do if g == guid then killed[guid] = {}; return killed[guid] end end
  table.insert(seen, guid); while #seen > 40 do table.remove(seen, 1) end
  local snap = {}
  for item in pairs(items) do snap[item] = true; local r = rec(item, nid); r[1] = r[1] + 1 end
  killed[guid] = snap
  return snap
end

local function sweep()
  if not any then return end
  local units = { "target", "mouseover", "focus" }
  for i = 1, 40 do units[#units + 1] = "nameplate" .. i end
  for _, u in ipairs(units) do
    local guid = UnitGUID and safe(UnitGUID, u)
    local nid = npcOfGuid(guid)
    if nid and watch[nid] and not killed[guid] then
      local dead = UnitIsDead and safe(UnitIsDead, u)
      local denied = UnitIsTapDenied and safe(UnitIsTapDenied, u)
      if dead == true and denied == false then kill(nid, guid) end
    end
  end
end

-- looting: the game says which corpse each item came from; a corpse you loot was yours
local function looted()
  if not (any and GetNumLootItems and GetLootSourceInfo and GetLootSlotLink) then return end
  for i = 1, (safe(GetNumLootItems) or 0) do
    local link = safe(GetLootSlotLink, i)
    local item = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    local src = { pcall(GetLootSourceInfo, i) }
    if src[1] then
      for k = 2, #src, 2 do
        local g = src[k]
        local nid = npcOfGuid(g)
        local snap = nid and kill(nid, g)
        if snap and item and snap[item] and not dropped[g .. item] then
          dropped[g .. item] = true
          local r = rec(item, nid); r[2] = r[2] + 1
        end
      end
    end
  end
end

-- What you've counted for an item from these mobs: { percent or 0 per mob } in the same order, and the kills
-- they're from, or nil when no mob has MIN_KILLS kills yet.
function RG.MyDropChances(item, npcs)
  local all = RG.db and RG.db.drops
  local byNpc = all and item and all[item]
  if not (byNpc and npcs) then return nil end
  local out, kills, anyRate = {}, 0, false
  for i, nid in ipairs(npcs) do
    local r = byNpc[nid]
    if r and r[1] >= MIN_KILLS and r[2] > 0 then
      out[i] = 100 * r[2] / r[1]; kills = kills + r[1]; anyRate = true
    else out[i] = 0 end
  end
  if not anyRate then return nil end
  return out, kills
end
RG.DROP_MIN_KILLS = MIN_KILLS
-- What you've counted so far for an item from these mobs, all of them together: kills, drops (0, 0 when none). Shown
-- from the first kill ("no drops in 4 kills yet", "1 in 6 kills so far") until there are enough kills for a rate.
function RG.MyDropCounts(item, npcs)
  local all = RG.db and RG.db.drops
  local byNpc = all and item and all[item]
  local kills, drops = 0, 0
  if byNpc and npcs then
    for _, nid in ipairs(npcs) do
      local r = byNpc[nid]
      if r then kills = kills + (r[1] or 0); drops = drops + (r[2] or 0) end
    end
  end
  return kills, drops
end

local ev = CreateFrame("Frame")
local queued = false
local function later()
  if queued then return end
  queued = true
  local function go() queued = false; pcall(rebuild) end
  if C_Timer and C_Timer.After then C_Timer.After(0.5, go) else go() end
end
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_TARGET_CHANGED",
  "UNIT_FLAGS", "PLAYER_REGEN_ENABLED", "LOOT_OPENED", "LOOT_READY" }) do pcall(ev.RegisterEvent, ev, e) end
local function onEvent(_, event, unit)
  if event == "PLAYER_LOGIN" or event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then later()
  elseif not any then return
  elseif event == "PLAYER_TARGET_CHANGED" then pcall(sweep)
  elseif event == "UNIT_FLAGS" then if unit == "target" then pcall(sweep) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    pcall(sweep)
    if C_Timer and C_Timer.After then C_Timer.After(1.5, function() pcall(sweep) end) end
  else pcall(looted) end
end
ev:SetScript("OnEvent", (RG.PerfWrap and RG.PerfWrap("drop counts", onEvent)) or onEvent)
