-- Drop rates you count yourself (DropRecord.lua): where the quest data names who drops a quest's item but not how
-- often (Notation, Notation, Notation: Fel Ash Experimentation Notes from Ashen Acolytes, Mount Hyjal), the add-on counts
-- your kills and the items you loot from them: what it's counted so far from the first kill, a rough rate from 10 kills,
-- the rate from 30.
local QUEST, ITEM, ACOLYTE = 95317, 274396, 260422

return {
  {
    name = "drop-rate-counted",
    about = "a quest item with no known rate gets one from your own kills and loot, marked as yours",
    race = "Orc", class = "WARRIOR", level = 57,
    run = function(T)
      local RG, G = T.RG, T.W.G
      local d = T.quest(QUEST)
      local o = d and d.o and d.o[1]
      T.ok(o and o[1] == "i" and o[6] == ITEM and not o[7], "the quest data names who drops the notes, with no rate")
      if not (o and o[1] == "i" and not o[7]) then return end
      T.ok(T.accept(QUEST), "Notation, Notation, Notation accepted")
      T.W.fire("QUEST_LOG_UPDATE"); T.step(2)
      local x = RG.DropInfo(QUEST)[1]
      T.ok(x and not x.rate and x.text:find("Ashen Acolyte", 1, true), "before any kills: who drops it, no rate (" .. tostring(x and x.text) .. ")")

      local saved = { UnitGUID = G.UnitGUID, UnitIsDead = G.UnitIsDead, UnitIsTapDenied = G.UnitIsTapDenied,
        GetNumLootItems = G.GetNumLootItems, GetLootSlotLink = G.GetLootSlotLink, GetLootSourceInfo = G.GetLootSourceInfo }
      local target
      G.UnitGUID = function(u) if u == "target" then return target end return saved.UnitGUID(u) end
      G.UnitIsDead = function(u) if u == "target" then return target ~= nil end return saved.UnitIsDead and saved.UnitIsDead(u) end
      G.UnitIsTapDenied = function(u) if u == "target" then return false end return saved.UnitIsTapDenied and saved.UnitIsTapDenied(u) end
      local loot
      G.GetNumLootItems = function() return loot and 1 or 0 end
      G.GetLootSlotLink = function() return loot and ("|cffffffff|Hitem:" .. ITEM .. "::::::::57:::::|h[Fel Ash Experimentation Notes]|h|r") end
      G.GetLootSourceInfo = function() return loot, 1 end
      -- 32 kills, every 4th drops the notes. Each corpse is seen dead as your target, and the ones with notes are looted
      -- (looted twice: the same corpse counts once)
      local function at(i)
        x = RG.DropInfo(QUEST)[1]
        local t = tostring(x and x.text)
        if i == 1 then T.ok(x and not x.rate and t:find("no drops in 1 kill yet", 1, true), "1 kill, no drop: counted from the first kill (" .. t .. ")") end
        if i == 3 then T.ok(x and not x.rate and t:find("no drops in 3 kills yet", 1, true), "3 kills, no drop: the count goes up (" .. t .. ")") end
        if i == 9 then T.ok(x and not x.rate and t:find("2 in 9 kills so far", 1, true), "9 kills: too few for a rate, what's counted so far (" .. t .. ")") end
        if i == 12 then
          local r = RG.db.drops and RG.db.drops[ITEM] and RG.db.drops[ITEM][ACOLYTE]
          T.ok(r and r[1] == 12 and r[2] == 3, "counted 12 kills and 3 drops (" .. tostring(r and r[1]) .. ", " .. tostring(r and r[2]) .. ")")
          T.ok(x and x.rate and x.mine and t:find("~25%", 1, true) and t:find("rough: 3 in 12 of your kills", 1, true),
            "12 kills: the rate is shown, marked as yours and rough (" .. t .. ")")
        end
        if i == 32 then
          T.ok(x and x.rate and x.mine and t:find("25%", 1, true) and not t:find("~", 1, true) and t:find("your 32 kills", 1, true),
            "32 kills: the rate, no longer rough (" .. t .. ")")
        end
      end
      for i = 1, 32 do
        target = string.format("Creature-0-1-2-3-%d-%010d", ACOLYTE, i)
        T.W.fire("PLAYER_TARGET_CHANGED")
        if i % 4 == 0 then loot = target; T.W.fire("LOOT_OPENED"); T.W.fire("LOOT_READY"); loot = nil end
        at(i)
      end
      for k, v in pairs(saved) do G[k] = v end
      T.ok(RG.SHARED_KEYS and RG.SHARED_KEYS.drops, "the counts are account-wide")
    end,
  },
}
