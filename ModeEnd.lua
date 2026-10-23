-- last file loaded: the slash command goes through the "Cards only" check (see Mode.lua)
local _, RG = ...
if RG and RG.WrapCardsOnlySlash then RG.WrapCardsOnlySlash() end
-- in Cards only mode the guide's start-up doesn't run, so the minimap button (cards, Arena, menu) is put up from here
if CreateFrame then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function()
    if RG.CardsOnly and RG.CardsOnly() and RG.MinimapButton and C_Timer then C_Timer.After(3, function() pcall(RG.MinimapButton) end) end
  end)
end
