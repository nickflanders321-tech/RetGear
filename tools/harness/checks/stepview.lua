-- The step view (StepView.lua) and drop rates in the tracker's tooltips.
local function texts(T, frame)
  local out = {}
  for _, t in ipairs(T.W.visibleTexts(frame)) do out[#out + 1] = (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end
  return table.concat(out, "\n")
end

return {
  {
    name = "drop-rates-known",
    about = "a quest's item drop rates come from the quest data (Gnoll Paw from the Riverpaw gnolls)",
    race = "Human", class = "MAGE", level = 12,
    run = function(T)
      local info = T.RG.DropInfo(102)   -- Patrolling Westfall: Gnoll Paws
      T.ok(#info > 0, "Patrolling Westfall has drop rates")
      local x = info[1]
      T.ok(x and x.item == "Gnoll Paw" and x.text:find("%d+%%") and x.text:find("Riverpaw", 1, true), "Gnoll Paw: " .. tostring(x and x.text))
      T.ok(T.RG.DropTip(102):find("Drops:", 1, true), "the tooltip section says so")
      T.eq(#T.RG.DropInfo(102, "Gnoll Paw"), 1, "asked for one objective by name, it's that one")
      local st = T.RG.DropInfo(832)   -- Burning Shadows: starts from Eye of Burning Shadow (Gazz'uz, always)
      T.eq(#st, 0, "a Human isn't told about a Horde quest's item")
    end,
  },
  {
    name = "item-start-drop-rate",
    about = "a quest that starts from an item says how often that item drops",
    race = "Orc", class = "WARRIOR", level = 12,
    run = function(T)
      local info = T.RG.DropInfo(832)   -- Burning Shadows: Eye of Burning Shadow, 100% from Gazz'uz
      local x = info[1]
      T.ok(x and x.starts and x.text:find("100%", 1, true) and x.text:find("Gazz'uz", 1, true), "Eye of Burning Shadow: " .. tostring(x and x.text))
    end,
  },
  {
    name = "step-view-shows-step",
    about = "with the step view on, it explains the quest you're doing, how often its item drops and what to look for",
    race = "Human", class = "MAGE", level = 12,
    run = function(T)
      T.RG.db.stepView = true
      local ok = T.accept(102)   -- Patrolling Westfall
      T.ok(ok, "Patrolling Westfall accepted")
      T.go(T.Wd.objectiveSpot(102))   -- out among the gnolls
      T.RG.Objective(true); T.RG.RefreshStepView(); T.step(1)
      local f = T.W.G.WaypathStepView
      T.ok(f and f:IsShown(), "the step view is on screen")
      if not (f and f:IsShown()) then return end
      local all = texts(T, f)
      T.ok(all:find("Patrolling Westfall", 1, true), "it names the quest")
      T.ok(all:find("Gnoll Paw", 1, true), "and the item to collect")
      T.ok(all:find("Drops %d+%% from"), "and how often it drops")
      T.ok(f.pic and f.pic:IsShown(), "with a picture of what to look for")
      -- the distance shows once (in the header)
      local _, n = all:gsub("%d+ yd", "")
      T.eq(n, 1, "the distance is shown once")
      -- off again: gone
      T.RG.db.stepView = false; T.RG.RefreshStepView()
      T.ok(not f:IsShown(), "turned off, it's gone")
    end,
  },
  {
    name = "step-view-skip",
    about = "the step view's Skip moves on from the current step",
    race = "Human", class = "MAGE", level = 12,
    run = function(T)
      T.RG.db.stepView = true
      T.accept(102)   -- Patrolling Westfall
      T.go(T.Wd.objectiveSpot(102))
      T.RG.Objective(true); T.RG.RefreshStepView(); T.step(1)
      local f = T.W.G.WaypathStepView
      T.ok(f and f.skip and f.skip:IsShown(), "there's a Skip button")
      local before = T.RG.Objective(true)
      T.ok(before and before.qtitle == "Patrolling Westfall", "the view is on Patrolling Westfall (" .. tostring(before and before.qtitle) .. ")")
      T.RG.StepViewSkip(); T.step(1)
      local after = T.RG.Objective(true)
      T.ok(not after or after.key ~= before.key, "after Skip it's on something else (" .. tostring(after and after.text) .. ")")
    end,
  },
}
