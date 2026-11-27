-- Every creature card with its display id and the camera settings the add-on gives it (zoom, camera distance),
-- written to OUT/npc.json for tools/render/camfix.py.
return function(T, opts)
  local RG = T.RG
  local out = {}
  for _, c in ipairs(RG.ArcadeUI.CARDS) do
    local d = RG.ARCADE_NPC and RG.ARCADE_NPC[c.name]
    if d then
      out[#out + 1] = { name = c.name, disp = d, zoom = RG.ArcadeModelZoom(c), cam = RG.ArcadeCamScale(c), ref = c.ref, tier = c.tier }
    end
  end
  local fh = assert(io.open(opts.out .. "/npc.json", "wb"))
  fh:write(T.W.json(out))
  fh:close()
  io.stdout:write(#out .. " creature cards\n")
end
