-- The Arrow switch turned off stays off: nothing the game or another add-on does on its own brings it back (a friend
-- had it come back after a hearthstone and a new continent: the game super-tracks a quest after every loading screen).
local function shown(W)
  local a = rawget(W.G, "WaypathArrow")
  return a and a:IsShown() or false
end

return {
  {
    name = "arrow-off-stays-off",
    about = "the Arrow switch off: loading screens, the game super-tracking a quest, TomTom pins and a corpse run leave it off",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG, W = T.RG, T.W
      T.step(6)
      -- a quest in the log, so the game has something to super-track
      local obj = RG.Objective(true)
      local it = obj and obj.stop and obj.stop.items and obj.stop.items[1]
      local qid = it and it.id
      if qid and it.act == "pickup" then T.accept(qid) end
      T.step(2)
      RG.ToggleArrow(); T.step(1)
      T.eq(RG.Opt("arrow"), false, "the Arrow switch turned the arrow off")

      -- after a hearthstone or a boat: a loading screen, a new zone, and the game super-tracks a quest by itself
      local ST = W.apis.C_SuperTrack
      ST.GetSuperTrackedQuestID = function() return qid end
      ST.IsSuperTrackingUserWaypoint = function() return false end
      W.fire("PLAYER_ENTERING_WORLD", false, false); W.fire("ZONE_CHANGED_NEW_AREA"); W.fire("SUPER_TRACKING_CHANGED")
      T.step(5)
      T.eq(RG.Opt("arrow"), false, "still off after a loading screen and the game super-tracking a quest")
      T.ok(not shown(W), "and the arrow isn't on screen")

      -- another add-on setting a TomTom waypoint on its own
      local TT = rawget(W.G, "TomTom")
      if TT and TT.AddWaypoint then
        pcall(TT.AddWaypoint, TT, 1411, 0.5, 0.5, { title = "Somewhere" }); T.step(1)
        T.eq(RG.Opt("arrow"), false, "still off after a TomTom waypoint")
      end

      -- dying: the way back to your body shows, and the setting is left alone (a /reload as a ghost left it on for good)
      local ghost = true
      W.G.UnitIsGhost = function() return ghost end
      W.apis.C_DeathInfo.GetCorpseMapPosition = function() return { x = 0.5, y = 0.5 } end
      RG.CorpseSync(); T.step(1)
      T.ok(shown(W), "dead: the arrow shows the way back to your body")
      T.eq(RG.Opt("arrow"), false, "dead: the Arrow setting itself is still off")
      ghost = false
      RG.CorpseSync(); T.step(1)
      T.eq(RG.Opt("arrow"), false, "alive again: still off")
      T.ok(not shown(W), "alive again: the arrow is gone")

      -- switching it back on yourself still works
      RG.ToggleArrow(); T.step(1)
      T.eq(RG.Opt("arrow"), true, "the Arrow switch turns it back on")
    end,
  },
}
