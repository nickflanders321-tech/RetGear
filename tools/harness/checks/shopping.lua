-- The ordered guide's shopping stop: before a zone whose quests need auction house goods you don't have (Frost Oil
-- for Coolant Heads Prevail in the Badlands), the nearest auction house first.
local COOLANT, FROST_OIL = 713, 3829
local ORGRIMMAR = { 1454, 50.0, 60.0 }

local function setup(T)
  local RG = T.RG
  RG.db.routeGuide = true
  T.setLevel(37)
  RG.SetRouteMode("guide", true); T.step(1)
  local r = T.entry("Badlands")
  -- (the guide on the Badlands, as when it moves on there from the zone before)
  RG.CurrentRouteEntry = function() return r end
  RG.ForgetNextStep()
  T.go(ORGRIMMAR)
  return r
end

return {
  {
    name = "shopping-stop-before-zone",
    about = "the guide moving on to the Badlands, whose Coolant Heads Prevail needs Frost Oil: the nearest auction house first, until it's in your bags",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      local r = setup(T)
      if not T.ok(r, "the route has the Badlands") then return end
      local list = RG.BringList(r)
      local frost
      for _, e in ipairs(list) do if e.item == FROST_OIL then frost = e end end
      T.ok(frost and frost.need == 1, "the Badlands' shopping list has 1 Frost Oil")
      T.ok(frost and table.concat(frost.quests, ","):find("Coolant Heads Prevail", 1, true), "for Coolant Heads Prevail")
      local obj = RG.Objective(true); T.step(1)
      T.eq(obj and obj.kind, "shop", "the current step is the shopping stop")
      T.ok(obj and obj.wp and obj.wp[1] == 1454, "at Orgrimmar's auction house (" .. tostring(obj and obj.wp and obj.wp[4]) .. ")")
      T.ok(obj and tostring(obj.qline):find("Frost Oil", 1, true) or tostring(obj and obj.qline):find("item " .. FROST_OIL, 1, true),
        "it says what to buy: " .. tostring(obj and obj.qline))
      T.give(FROST_OIL, 1)
      obj = RG.Objective(true); T.step(1)
      local still = obj and obj.kind == "shop" and tostring(obj.qline) or ""
      T.ok(not still:find("Frost Oil", 1, true) and not still:find("item " .. FROST_OIL, 1, true),
        "with the Frost Oil in your bags, it's off the list (left: " .. (still ~= "" and still or "nothing, the stop is done") .. ")")
      -- everything on it bought: the stop is done
      for _, e in ipairs(RG.BringList(r)) do T.give(e.item, e.need) end
      obj = RG.Objective(true); T.step(1)
      T.ok(not obj or obj.kind ~= "shop", "with everything bought, the stop is done")
    end,
  },
  {
    name = "shopping-stop-skip",
    about = "the shopping stop can be skipped, and doesn't come back for that zone; once you're in the zone it's gone too",
    race = "Orc", class = "WARRIOR", level = 1,
    run = function(T)
      local RG = T.RG
      local r = setup(T)
      if not r then return end
      local obj = RG.Objective(true); T.step(1)
      T.eq(obj and obj.kind, "shop", "the shopping stop")
      RG.StepViewSkip(); T.step(1)
      obj = RG.Objective(true); T.step(1)
      T.ok(not obj or obj.kind ~= "shop", "skipped: it's gone (" .. tostring(obj and obj.kind) .. ")")
      RG.db.shopDone = nil
      T.go({ 1418, 25.9, 44.9 })   -- in the Badlands, at Lotwil Veriatus
      obj = RG.Objective(true); T.step(1)
      T.ok(not obj or obj.kind ~= "shop", "in the zone, no shopping stop (" .. tostring(obj and obj.kind) .. ")")
    end,
  },
}
