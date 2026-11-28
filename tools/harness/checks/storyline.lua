-- Mount Hyjal, as a level 55 player reported it (2026-11-27), their quest log rebuilt from their saved variables: every
-- other Hyjal quest done, these in the log. Zone quests.
--   1. Just finished The Experimental Method: hand it in to the Curious Crow and follow A Fitting End's chain, not off to
--      a camp of shrubs for three quests on their own (about as far, a few yards less walking in all).
--   2. A Revenge Now Bitter, right after Amalgamated Marrow: decide Felflick's fate (89 yards) and hand in, not the shrubs.
--   3. Heading for a stop you clicked: The Dying God offered right beside you is picked up first, then back to your stop.
--   4. Barkskin Burrow at Hostile: its quests wait for Balance Through Strength and Unfriendly standing.
local INLOG = { 91755, 91923, 92594, 93747, 93759, 95316, 96435 }
local NOTYET = { 96255, 96322, 96321, 96131, 91881, 94782, 93952 }

local function current(T)
  local o = T.RG.Objective(true)
  local it = o and o.stop and o.stop.items and o.stop.items[1]
  return it and it.act, it and it.title, o and o.text
end

return {
  {
    name = "storyline-first",
    about = "Mount Hyjal: a quest chain close by is followed through before a camp of quests on their own; a pickup beside you is taken on the way",
    race = "NightElf", class = "MAGE", level = 55,
    run = function(T)
      local RG, Wd, W = T.RG, T.Wd, T.W
      local S = Wd.state
      T.step(6)
      local keep = {}
      for _, id in ipairs(INLOG) do keep[id] = true end
      for _, id in ipairs(NOTYET) do keep[id] = true end
      for id, d in pairs(RG.QDATA) do
        if ((d.s and d.s[1] == 2482) or (d.e and d.e[1] == 2482)) and not keep[id] then S.done[id] = true end
      end
      for _, id in ipairs(INLOG) do T.accept(id) end
      RG.SetRouteMode("zone", true); T.step(3)

      T.go({ 2482, 49.4, 71.1 }); RG.GuideReset(); T.step(3)
      local act, title, text = current(T)
      T.ok(act == "turnin" and title == "The Experimental Method", "1. the hand-in where the chain goes on comes first (got: " .. tostring(text) .. ")")
      local plan = RG.GuidePlan()
      local fitting
      for i, s in ipairs(plan and plan.stops or {}) do
        if i > 4 then break end
        for _, it in ipairs(s.items) do if it.title == "A Fitting End" then fitting = true end end
      end
      T.ok(fitting, "1. A Fitting End follows soon after")

      T.go({ 2482, 40.8, 80.3 }); Wd.work(96435); T.step(1); Wd.handIn(96435); T.step(1)
      S.done[96255] = true; W.fire("QUEST_TURNED_IN", 96255, 0, 0)
      T.accept(96322); T.go({ 2482, 48.6, 73.5 }); RG.GuideReset(); T.step(3)
      act, title, text = current(T)
      T.ok(act == "doing" and title == "A Revenge Now Bitter", "2. the chain's next quest close by comes first (got: " .. tostring(text) .. ")")

      RG.PickManually({ 2482, 57.1, 78.4, "Tainted Shrubbery" }); T.step(1)
      T.go({ 2482, 36.6, 78.2 }); T.step(3)
      act, title, text = current(T)
      T.ok(act == "pickup" and title == "The Dying God", "3. the pickup beside you comes first (got: " .. tostring(text) .. ")")
      T.accept(96321); T.step(3)
      local o = RG.Objective(true)
      T.ok(o and o.manual, "3. then back to the stop you picked (got: " .. tostring(o and o.text) .. ")")

      local standing = -4500
      local R = W.apis.C_Reputation
      local function data() return { name = "Barkskin Burrow", currentStanding = standing, factionID = 2600 } end
      R.GetNumFactions = function() return 1 end
      R.GetFactionDataByIndex = function(i) if i == 1 then return data() end end
      R.GetFactionDataByID = function(id) if id == 2600 then return data() end end
      T.ok(RG.QuestBlocked(93834, RG.QDATA[93834]) ~= nil, "4. Burrow Beetles waits at Hostile")
      S.done[93952] = true; W.fire("QUEST_TURNED_IN", 93952, 0, 0); T.step(1)
      T.ok(RG.QuestBlocked(93834, RG.QDATA[93834]) ~= nil, "4. ... and with Balance Through Strength handed in but still Hostile")
      standing = -2900; T.step(1)
      T.eq(RG.QuestBlocked(93834, RG.QDATA[93834]), nil, "4. Burrow Beetles open at Unfriendly")
      T.ok(tostring(RG.QuestBlocked(94504, RG.QDATA[94504])):find("Barkskin Burrow") ~= nil, "4. Barkskin Beginnings waits for Neutral")
    end,
  },
}
