-- An objective whose name starts another's (Extinguish the Firegut: "Firegut Ogre" and "Firegut Ogre Mage"): once the
-- ogres are done, the arrow moves on to the mages and brutes, instead of staying on the ogres (the game's line "Firegut
-- Ogre Mage slain: 0/6" was read as the ogres', so their objective never counted as done).
return {
  {
    name = "objective-name-inside-another",
    about = "Extinguish the Firegut: with the ogres done, the quest's waypoint moves to the mages or brutes, then to the hand-in",
    race = "Human", class = "MAGE", level = 55,
    run = function(T)
      local RG, Wd = T.RG, T.Wd
      local QID = 3823
      T.step(6)
      T.accept(QID); T.step(3)
      local function wpOf()
        for _, q in ipairs(RG.MyQuests()) do if q.id == QID then return q.wp end end
      end
      local visits, stuck = 0, nil
      for _ = 1, 4 do
        local wp = wpOf()
        if not wp then break end
        T.go(wp)
        local moved = Wd.work(QID); T.step(3)
        visits = visits + 1
        if moved == 0 and not T.done(QID) and Wd.objectiveSpot(QID) then
          stuck = string.format("%s at %.1f,%.1f", tostring(wp[4]), wp[2], wp[3])
          break
        end
        if Wd.objectiveSpot(QID) == nil then break end
      end
      T.ok(not stuck, "every waypoint it gave had something left to do" .. (stuck and (": stuck on " .. stuck) or ""))
      T.ok(Wd.objectiveSpot(QID) == nil, "all three objectives done in " .. visits .. " visits")
      local hand = wpOf()
      T.ok(hand and hand[4] == "Oralius", "then it points at the hand-in (" .. tostring(hand and hand[4]) .. ")")
    end,
  },
}
