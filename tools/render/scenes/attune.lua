-- The Journey > Onyxia attunement tab, once per faction, with a few quests ticked:
--   lua5.1 tools/harness/run.lua --shoot tools/render/scenes/attune.lua --out DIR
return function(T)
  local RG, G = T.RG, T.G
  T.slash("/wp"); T.step(1)
  if G.WaypathSetup then G.WaypathSetup:Hide() end
  local done = {}
  for _, id in ipairs({ 4182, 4183, 4184, 4185, 4186, 4223, 4224, 4241, 4242, 6566, 6567, 98325, 4903, 4941 }) do done[id] = true end
  G.C_QuestLog = G.C_QuestLog or {}
  G.C_QuestLog.IsQuestFlaggedCompleted = function(id) return done[id] or false end
  for _, f in ipairs({ "Alliance", "Horde" }) do
    RG.PLAYER_FACTION = f
    RG.UIState.tab = "attune"
    pcall(RG.RefreshUI); T.step(0.5)
    T.shoot("attune-" .. f:lower())
  end
end
