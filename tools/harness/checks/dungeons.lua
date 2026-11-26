-- Preobtain dungeon quests (DungeonPrep.lua): the plan for a dungeon, its chains, skipping a chain, the tracker's view
-- and Journey > Dungeon quests.
local function clean(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end

-- the tracker's line showing a text (its button: .onClick, .onRightClick), or nil
local function trackerLine(T, text)
  local body = T.W.G.WaypathTracker and T.W.G.WaypathTracker.body
  if not body then return nil end
  for _, b in ipairs({ body:GetChildren() }) do
    if b:IsShown() and b.text and clean(b.text:GetText()):find(text, 1, true) then return b end
  end
end
local function prepRow(RG, id)
  for i, r in ipairs(RG.PrepList(nil, (RG.GuidePlan() or {}).stops)) do if r.s.id == id then return r, i end end
end

return {
  {
    name = "prep-dungeon-list",
    about = "Blackrock Depths lists the hand-written quests (by name in Routes/Horde.lua) and the ones picked up inside, but not a breadcrumb as a quest of its own",
    race = "Orc", class = "WARRIOR", level = 53,
    run = function(T)
      local RG = T.RG
      RG.db.prepDungeon = "Blackrock Depths"
      RG.SetTrackerView("dungeon"); T.step(2)
      local pl = RG.PrepPlan()
      local targets, steps = {}, {}
      for _, t in ipairs(pl.quests) do
        targets[t.id] = t
        for _, s in ipairs(t.chain) do steps[s.id] = s end
      end
      for id, name in pairs({ [4134] = "Lost Thunderbrew Recipe", [3907] = "Disharmony of Fire", [3802] = "Dark Iron Legacy",
          [4136] = "Ribbly Screwspigot", [4123] = "The Heart of the Mountain" }) do
        T.ok(targets[id], name .. " (" .. id .. ") is one of the dungeon's quests")
      end
      T.ok(targets[3802] and targets[3802].chain[1].id == 3801, "the first Dark Iron Legacy comes before the second")
      T.ok(not targets[4133], "Vivian Lagrave (a breadcrumb to Lost Thunderbrew Recipe) isn't one of the dungeon's own quests")
      T.ok(not targets[4324], "nor Yuka Screwspigot (a breadcrumb to Ribbly Screwspigot)")
      T.eq(steps[4201] and steps[4201].state, "inside", "The Love Potion is picked up inside the dungeon")
      T.ok(pl.can > 0 and pl.can < pl.total, "the count is of the quests you can get before the run (" .. pl.can .. " of " .. pl.total .. ")")
    end,
  },
  {
    name = "prep-other-continent",
    about = "preparing for Blackrock Depths from Kalimdor: the current step is the first thing to do for it in the Eastern Kingdoms, not 'nothing to do'",
    race = "Orc", class = "WARRIOR", level = 53,
    run = function(T)
      local RG = T.RG
      T.accept(3906)   -- Disharmony of Flame (Badlands)
      RG.db.prepDungeon = "Blackrock Depths"
      RG.SetTrackerView("dungeon"); T.step(2)
      T.go({ 1454, 45, 60 }); T.step(2)   -- Orgrimmar
      local obj = RG.Objective(true)
      local work = RG.PrepWork()
      T.ok(obj and obj.kind ~= "prep" and obj.id and (work.full[obj.id] or work.keep[obj.id]), "the current step is one of the dungeon's chains (" .. tostring(obj and (obj.qtitle or obj.text)) .. ")")
      T.ok(obj and obj.wp and RG.MapZone(obj.wp[1]) ~= "Orgrimmar", "and the arrow points to it (" .. tostring(obj and obj.wp and RG.MapZone(obj.wp[1])) .. ")")
      RG.RefreshTracker(); T.step(1)
      T.ok(not T.trackerFind("Nothing to go and do right now"), "the tracker doesn't say there's nothing to do: " .. table.concat(T.tracker(), " | "))
      local r = prepRow(RG, 3906)
      T.eq(r and r.g, "now", "Disharmony of Flame, in your log, is one to do now")
    end,
  },
  {
    name = "prep-list-order",
    about = "the dungeon view lists every quest once, one per line, each after the quests it needs, the ones to do now first",
    race = "Orc", class = "WARRIOR", level = 53,
    run = function(T)
      local RG = T.RG
      T.accept(3906)
      RG.db.prepDungeon = "Blackrock Depths"
      RG.SetTrackerView("dungeon"); T.step(2)
      T.go({ 1418, 6.0, 47.0 }); T.step(2)   -- Kargath
      local stops = (RG.GuidePlan() or {}).stops or {}
      local rows = RG.PrepList(nil, stops)
      local pos, bad, back, rank = {}, nil, nil, { now = 1, wait = 2, level = 3, have = 4, after = 5, inside = 6 }
      for i, r in ipairs(rows) do
        if pos[r.s.id] then bad = r.s.name end
        pos[r.s.id] = i
        if i > 1 and rank[rows[i - 1].g] > rank[r.g] then back = r.s.name end
      end
      T.ok(#rows > 10 and not bad, "every quest once (" .. #rows .. " lines; " .. tostring(bad) .. " twice)")
      T.ok(not back, "the groups in order: now, later, level, in your log, after the run, in the run (" .. tostring(back) .. ")")
      local early
      for i, r in ipairs(rows) do
        for _, p in ipairs(r.before) do if pos[p] and pos[p] > i then early = r.s.name end end
      end
      T.ok(not early, "each quest comes after the ones it needs (" .. tostring(early) .. " came first)")
      local obj = RG.Objective(true)
      local firstIsCur = false
      for _, it in ipairs(obj and obj.stop and obj.stop.items or {}) do if rows[1] and it.id == rows[1].s.id then firstIsCur = true end end
      T.ok(firstIsCur, "the first quest of the list is the current step's (" .. tostring(rows[1] and rows[1].s.name) .. ", " .. tostring(obj and obj.qtitle) .. ")")
      RG.RefreshTracker(); T.step(1)
      local joined
      for _, t in ipairs(T.tracker()) do if t:find("›", 1, true) then joined = t end end
      T.ok(not joined, "no line names several quests (" .. tostring(joined) .. ")")
    end,
  },
  {
    name = "prep-click-quest",
    about = "clicking a quest of the dungeon view makes it the current step; clicking one that waits leads to the quest it waits on",
    race = "Orc", class = "WARRIOR", level = 53,
    run = function(T)
      local RG = T.RG
      T.accept(3906)   -- Disharmony of Flame
      RG.db.prepDungeon = "Blackrock Depths"
      RG.SetTrackerView("dungeon"); T.step(2)
      T.go({ 1418, 25.9, 44.9 }); T.step(2)   -- Lotwil Veriatus's hill in the Badlands, away from Kargath
      RG.RefreshTracker(); T.step(1)
      local b = trackerLine(T, "Disharmony of Flame")
      T.ok(b and b.onClick, "Disharmony of Flame has a line to click")
      if b and b.onClick then b.onClick(); T.step(1) end
      local obj = RG.Objective(true)
      T.eq(obj and obj.id, 3906, "and clicking it makes it the current step (" .. tostring(obj and obj.text) .. ")")
      -- The Last Element waits on Disharmony of Flame: clicking it leads there too
      RG.PickManually(nil); T.step(1)
      RG.RefreshTracker(); T.step(1)
      local b2 = trackerLine(T, "The Last Element")
      T.ok(b2 and b2.onClick, "The Last Element has a line to click")
      if b2 and b2.onClick then b2.onClick(); T.step(1) end
      obj = RG.Objective(true)
      T.eq(obj and obj.id, 3906, "clicking The Last Element (after Disharmony of Flame) leads to Disharmony of Flame (" .. tostring(obj and obj.text) .. ")")
    end,
  },
  {
    name = "prep-plan-chains",
    about = "preparing for Blackrock Depths lists its quests, each with the chain that comes first, and skipping a quest skips the rest of its chain",
    race = "Orc", class = "WARRIOR", level = 50,
    run = function(T)
      local RG = T.RG
      RG.db.prepDungeon = "Blackrock Depths"
      RG.SetTrackerView("dungeon"); T.step(2)
      T.eq(RG.TrackerView(), "dungeon", "the tracker preobtains dungeon quests")
      local pl = RG.PrepPlan()
      T.eq(pl.name, "Blackrock Depths", "for the dungeon picked")
      T.ok(pl.total > 0, "with quests to collect (" .. pl.total .. ")")
      -- a quest with a chain before it
      local withChain
      for _, t in ipairs(pl.quests) do if #t.chain > 1 and t.state ~= "after" then withChain = t break end end
      T.ok(withChain, "one of them has quests that come first")
      if withChain then
        local last = withChain.chain[#withChain.chain]
        T.ok(last.target and last.id == withChain.id, "the chain ends with the dungeon's own quest")
        T.ok(not withChain.chain[1].target, "and starts with an earlier quest")
        -- skip the first quest of the chain: the whole chain is skipped
        RG.PrepSkip(withChain.chain[1].id, true); T.step(1)
        local again
        for _, t in ipairs(RG.PrepPlan().quests) do if t.id == withChain.id then again = t end end
        T.eq(again and again.state, "skipped", "skipping its first quest skips the dungeon's quest too")
        RG.PrepSkip(withChain.chain[1].id, false); T.step(1)
        for _, t in ipairs(RG.PrepPlan().quests) do if t.id == withChain.id then again = t end end
        T.ok(again and again.state ~= "skipped", "and bringing it back brings the chain back")
      end
      -- the list: a quest several chains share is one line
      local seen, dup = {}, nil
      for _, row in ipairs(RG.PrepList()) do
        if seen[row.s.id] then dup = row.s.name end
        seen[row.s.id] = true
      end
      T.ok(not dup, "every quest is on one line of the list (" .. tostring(dup) .. " came twice)")
      -- the steps: in the Badlands, the trip starts with something from the chains
      T.go({ 1418, 6.0, 47.0 }); T.step(2)
      RG.Objective(true)
      local stops = (RG.GuidePlan() or {}).stops or {}
      T.ok(#stops > 0, "there are steps to take (" .. #stops .. ")")
      local w = RG.PrepWork()
      local first = stops[1] and stops[1].items[1]
      T.ok(first and first.id and (w.full[first.id] or w.keep[first.id]), "the first step is one of the chains (" .. tostring(first and RG.PrepStepText(first)) .. ")")
      -- the tracker: the dungeon picker and the quests
      RG.RefreshTracker(); T.step(1)
      T.ok(T.trackerFind("Selected Dungeon: Blackrock Depths"), "the line under the header says which dungeon: " .. table.concat(T.tracker(), " | "))
      T.ok(T.trackerFind("Quests · Blackrock Depths"), "and the tracker lists the quests")
      -- the planner only picks from the chains: whatever the current step is, it's one of them (or how it stands)
      local obj = RG.Objective(true)
      local work = RG.PrepWork()
      local okObj = not obj or obj.kind == "prep" or (obj.id and (work.full[obj.id] or work.keep[obj.id])) or false
      T.ok(okObj, "the current step is one of the dungeon's chains (" .. tostring(obj and (obj.qtitle or obj.text)) .. ")")
      -- Journey > Dungeon quests draws
      RG.ShowTab("dungeons"); T.step(1)
      local page = clean(table.concat(T.W.visibleTexts(T.W.G.WaypathFrame), "\n"))
      T.ok(not page:find("This page hit an error", 1, true), "the Dungeon quests page draws without an error")
      T.ok(page:find("Blackrock Depths", 1, true), "and shows the dungeon")
      -- back to the guide
      RG.SetTrackerView("guide"); T.step(1)
      T.eq(RG.TrackerView(), "guide", "picking the guide leaves the dungeon view")
    end,
  },
  {
    name = "guide-button-opens-section",
    about = "the tracker's guide button opens the part of the main window for what it follows",
    race = "Orc", class = "WARRIOR", level = 20,
    run = function(T)
      local RG = T.RG
      RG.ShowTab("settings"); T.step(1)
      local tr = T.W.G.WaypathTracker
      local btn = tr and tr.guideBtn
      T.ok(btn, "the guide button is on the tracker")
      if not btn then return end
      RG.SetTrackerView("guide"); T.step(1)
      btn:GetScript("OnClick")(btn, "LeftButton"); T.step(1)
      T.ok(RG.UIState.tab == "route" or RG.UIState.tab == "dungeons" or RG.UIState.tab == "plan" or RG.UIState.tab == "flights", "the guide opens Journey (" .. tostring(RG.UIState.tab) .. ")")
      RG.SetTrackerView("prof"); T.step(1)
      btn:GetScript("OnClick")(btn, "LeftButton"); T.step(1)
      T.eq(RG.UIState.tab, "prof", "professions open the Professions page")
      RG.SetTrackerView("dungeon"); T.step(1)
      btn:GetScript("OnClick")(btn, "LeftButton"); T.step(1)
      T.eq(RG.UIState.tab, "dungeons", "dungeon quests open the Dungeon quests page")
    end,
  },
}
