-- Self-test for the harness: every line marked EXPECT must show up in the report. Not part of the add-on.
-- Run from the repo root:  lua5.1 tools/harness/run.lua --toc tools/harness/selftest/SelfTest.toc
local _, RG = ...
RG.loaded = true

-- taint: replacing a game function, writing into an API table, writing a field on a game frame
CreateFrame = CreateFrame                                   -- EXPECT taint: global CreateFrame
C_Timer.After = C_Timer.After                               -- EXPECT taint: C_Timer.After
GameTooltip.waypathMark = true                              -- EXPECT taint: GameTooltip.waypathMark
_G.ChatFrame_OpenChat = function() end                      -- EXPECT taint: global ChatFrame_OpenChat
GameTooltip:SetScript("OnTooltipSetItem", function() end)   -- fine: the game had no handler there yet
GameTooltip:SetScript("OnTooltipSetItem", function() end)   -- EXPECT taint: replaces a handler on a game frame

-- fine: the add-on's own globals, a slash command, hooks done the right way
WaypathSelfTest = {}
SLASH_WAYPATHSELFTEST1 = "/wpselftest"
SlashCmdList.WAYPATHSELFTEST = function() end
hooksecurefunc("ToggleBackpack", function() end)
GameTooltip:HookScript("OnShow", function() end)

-- errors: one while loading, one in an event, one in a timer
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  local t = nil
  C_Timer.After(3, function() return #RG.notThere end)      -- EXPECT error: timer, length of nil
  return t.field                                            -- EXPECT error: PLAYER_LOGIN, index nil
end)
local x = os.time()                                         -- EXPECT error: the game has no `os`
