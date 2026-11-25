-- The tracker and the arrow through one quest: The Mindless Ones (364), Deathknell, a fresh Undead.
local MINDLESS, RUDE = 364, 363

local function startMindless(T, routeOn)
  -- the arrow follows the route only with the leveling route switched on ("routeGuide", off by default: WIP)
  if routeOn then T.RG.db.routeGuide = true end
  T.complete(RUDE)
  local ok, why = T.accept(MINDLESS)
  T.ok(ok, "accepting The Mindless Ones works (" .. tostring(why) .. ")")
  T.step(2)
end

return {
  {
    name = "tracker-accepted-quest",
    about = "an accepted quest is on the tracker with its progress",
    race = "Scourge", class = "PALADIN", level = 1,
    run = function(T)
      startMindless(T)
      T.ok(T.trackerFind("Mindless Ones"), "the tracker lists The Mindless Ones (it shows: " .. table.concat(T.tracker(), " | ") .. ")")
      T.ok(T.trackerFind("0/6"), "the tracker shows the objective's progress, 0/6")
    end,
  },
  {
    name = "tracker-progress-and-turnin",
    about = "objective progress shows on the tracker, and a finished quest says to hand it in",
    race = "Scourge", class = "PALADIN", level = 1,
    run = function(T)
      startMindless(T)
      T.work(MINDLESS)
      T.step(2)
      T.ok(not T.trackerFind("0/6"), "after the objectives are done, 0/6 is gone from the tracker")
      local line
      for _, t in ipairs(T.tracker()) do if t:lower():find("turn in") or t:lower():find("hand in") or t:lower():find("complete") then line = t end end
      T.ok(line, "the tracker says the quest is ready to hand in (it shows: " .. table.concat(T.tracker(), " | ") .. ")")
      T.handIn(MINDLESS)
      T.step(2)
      T.ok(T.done(MINDLESS), "the quest was handed in")
      T.ok(not T.trackerFind("Mindless Ones"), "once handed in, The Mindless Ones is off the tracker's quest list")
    end,
  },
  {
    name = "arrow-follows-the-quest",
    about = "with the leveling route on, the arrow points at the objective, then at the hand-in once the quest is done",
    race = "Scourge", class = "PALADIN", level = 1,
    run = function(T)
      startMindless(T, true)
      local q = T.quest(MINDLESS)
      local a = T.arrow()
      local atObjective = false
      for _, o in ipairs(q.o or {}) do for _, sp in ipairs(o[4] or {}) do if T.near(a, sp, 6) then atObjective = true end end end
      T.ok(a, "the arrow is pointing somewhere after the quest is accepted")
      T.ok(atObjective or T.near(a, q.e, 3), "the arrow points at the quest's objectives (or its NPC): it points at " .. (a and string.format("%d %.1f,%.1f", a[1], a[2], a[3]) or "nothing"))
      T.work(MINDLESS)
      T.step(3)
      a = T.arrow()
      T.ok(T.near(a, q.e, 3), string.format("with the quest done the arrow points at the finisher %s (%.1f,%.1f): it points at %s",
        q.e[4], q.e[2], q.e[3], a and string.format("%d %.1f,%.1f", a[1], a[2], a[3]) or "nothing"))
    end,
  },
  {
    name = "distance-shrinks",
    about = "with the leveling route on, walking toward the hand-in, the distance shown goes down",
    race = "Scourge", class = "PALADIN", level = 1,
    run = function(T)
      startMindless(T, true)
      T.work(MINDLESS)
      T.step(3)
      local q = T.quest(MINDLESS)
      -- start well away from the finisher, then walk halfway to it
      T.go({ q.e[1], q.e[2] + 20, q.e[3] + 20 })
      T.step(2)
      -- the top line names the hand-in ("Hand in to Shadow Priest Sarvis"); its distance is the text after it
      local function yards()
        local lines, seen = T.tracker(), false
        for _, t in ipairs(lines) do
          if t:find("Hand in to", 1, true) then seen = true
          elseif seen then local n = t:match("(%d+) yd"); if n then return tonumber(n), t end end
        end
      end
      local far, l1 = yards()
      T.go({ q.e[1], q.e[2] + 10, q.e[3] + 10 })
      T.step(6)   -- two of the guide's 3-second heartbeats
      local nearer, l2 = yards()
      T.ok(far and nearer, "the tracker shows the distance to the hand-in (it shows: " .. table.concat(T.tracker(), " | ") .. ")")
      if far and nearer then T.ok(nearer < far, string.format("the distance went down as the bot walked closer (\"%s\", then \"%s\")", l1, l2)) end
    end,
  },
}
