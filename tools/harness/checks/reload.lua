-- What survives a /reload: a second login with the first one's saved data (WaypathDB) and the same world.
local MINDLESS, RUDE = 364, 363

local function firstEntry(T)
  local r = T.RG.CurrentRouteEntry()
  return r, r and (r.zone .. "|" .. r.from)
end

return {
  {
    name = "reload-keeps-ticks-and-settings",
    about = "a step ticked by hand and a changed setting are still there after /reload",
    race = "Scourge", class = "PALADIN", level = 1,
    run = function(T)
      local r, key = firstEntry(T)
      T.ok(r, "there is a route entry at level 1")
      if not r then return end
      T.RG.TickStep(key .. "#2", "test tick")
      T.step(1)
      T.ok(T.RG.StepIsDone(r, 2), "the ticked step counts as done")
      local before = T.RG.Opt("tooltip")
      T.slash("/wp tooltip")
      T.ok(T.RG.Opt("tooltip") ~= before, "/wp tooltip changes the tooltip setting")
      T.db().harnessTooltipWas = T.RG.Opt("tooltip")
    end,
    reload = function(T)
      local r, key = firstEntry(T)
      T.ok(r and T.RG.StepIsDone(r, 2), "the step ticked before /reload is still done")
      T.ok(T.RG.db.stepsDone and T.RG.db.stepsDone[key .. "#2"], "it's still in the saved ticks (stepsDone)")
      local was = T.db().harnessTooltipWas
      T.eq(T.RG.Opt("tooltip"), was, "the tooltip setting changed before /reload is unchanged")
    end,
  },
  {
    name = "reload-keeps-quest-progress",
    about = "after /reload the tracker shows the same quest, and the route the same step",
    race = "Scourge", class = "PALADIN", level = 1,
    run = function(T)
      T.complete(RUDE)
      T.accept(MINDLESS)
      T.step(2)
      local r = T.RG.CurrentRouteEntry()
      T.db().harnessStep = r and (r.zone .. "|" .. r.from .. "#" .. tostring(T.RG.NextStep(r)))
      T.ok(T.trackerFind("Mindless Ones"), "before /reload the tracker lists The Mindless Ones")
    end,
    reload = function(T)
      T.step(2)
      T.ok(T.trackerFind("Mindless Ones"), "after /reload the tracker still lists The Mindless Ones (it shows: " .. table.concat(T.tracker(), " | ") .. ")")
      local r = T.RG.CurrentRouteEntry()
      local now = r and (r.zone .. "|" .. r.from .. "#" .. tostring(T.RG.NextStep(r)))
      T.eq(now, T.db().harnessStep, "the route is on the same step after /reload")
      T.ok(T.done(RUDE), "the world still has Rude Awakening handed in")
    end,
  },
  {
    name = "retgear-migration",
    about = "an old RetGear install's data moves into WaypathDB, once",
    race = "Scourge", class = "PALADIN", level = 1,
    addons = { "RetGear" },
    saved = { RetGearDB = { harnessMarker = "from RetGear", chars = {} } },
    run = function(T)
      local db = T.db()
      T.ok(db, "WaypathDB exists after the first login")
      -- (RetGear kept one flat table; Waypath+ moves its keys into the character's profile, which RG.db reads)
      T.eq(T.RG.db.harnessMarker, "from RetGear", "RetGearDB's data is in this character's profile")
      T.eq(db and db.migratedFrom, "RetGear", "WaypathDB says it came from RetGear")
    end,
    reload = function(T)
      T.eq(T.RG.db.harnessMarker, "from RetGear", "after /reload the migrated data is still there")
      T.eq(T.RG.migrated, nil, "and it isn't migrated a second time")
    end,
  },
}
