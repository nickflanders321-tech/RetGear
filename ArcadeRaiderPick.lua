local _, RG = ...
-- Raider cards (and Rivals): which of the class's three raid sets a raider wears (ArcadeGearSets.lua), which stand-in
-- NPC shows them on a client that can't change a model's race (ArcadeRaiderLook.lua: several per race, sex and class),
-- and which way they face. All from the raider's own name, so a card always looks the same, and two raiders of the same
-- race and class don't.
local function hash(s, salt)
  local h = 5381 + (salt or 0)
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end
-- the set's name (for the card's text) and its item ids (for the model)
function RG.ArcadeRaiderSet(name, class)
  local sets = RG.ARCADE_GEAR_SETS and RG.ARCADE_GEAR_SETS[class or ""]
  if not (sets and #sets > 0 and type(name) == "string") then
    return RG.ARCADE_GEAR_SET and RG.ARCADE_GEAR_SET[class or ""], RG.ARCADE_GEAR and RG.ARCADE_GEAR[class or ""]
  end
  local s = sets[hash(name) % #sets + 1]
  return s[1], s[2]
end
-- which of n stand-ins (1..n)
function RG.ArcadeRaiderPick(name, n) return hash(type(name) == "string" and name or "?", 7) % math.max(1, n) + 1 end
-- which way the model faces: a little to the left or the right of the usual three-quarter view
function RG.ArcadeRaiderFace(name) return 0.4 + ((hash(type(name) == "string" and name or "?", 13) % 7) - 3) * 0.06 end
-- (a model can only wear an item the game has loaded: every raid set's pieces are asked for once at login)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if not (C_Timer and C_Timer.After) then return end
  C_Timer.After(5, function()
    for _, sets in pairs(RG.ARCADE_GEAR_SETS or {}) do
      for _, s in ipairs(sets) do
        for _, id in ipairs(s[2] or {}) do
          if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id)
          elseif GetItemInfo then pcall(GetItemInfo, id) end
        end
      end
    end
  end)
end)
