-- Preobtain dungeon quests (DungeonPrep.lua): the plan for a dungeon, its chains, skipping a chain, the tracker's view
-- and Journey > Dungeon quests.
local function clean(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end

return {
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
      -- the chains as one tree: a quest several chains share is one line
      local seen, dup = {}, nil
      for _, row in ipairs(RG.PrepTree()) do
        if seen[row.first.id] then dup = row.first.name end
        seen[row.first.id] = true
      end
      T.ok(not dup, "every quest is on one line of the tree (" .. tostring(dup) .. " came twice)")
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
      T.ok(T.trackerFind("STEPS · BLACKROCK DEPTHS") and T.trackerFind("CHAINS"), "and the tracker lists the steps and the chains")
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
