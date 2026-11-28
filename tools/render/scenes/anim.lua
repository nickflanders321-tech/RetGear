-- Animations as film strips and a per-frame trace, with the add-on's own code:
--   a pack with one card of each rarity through the seal, the deal, the turns (a Mythic last) and the settle
--   film-<scene>-NNN   one picture every FRAME seconds (render.py draws them; tools/render/strip.py joins them)
--   trace.txt (in --out)  every tick: what moved, and a list of things that looked wrong:
--                         a card face showing before its cover has turned, a frame leaving the reveal window, a size that jumps
--   lua5.1 tools/harness/run.lua --shoot tools/render/scenes/anim.lua --out DIR [--dt 0.1] [--finish 1]
return function(T, opts)
  local RG, G, W = T.RG, T.G, T.W
  local UI = RG.ArcadeUI
  local dt = tonumber(opts.dt) or 0.1
  local finish = tonumber(opts.finish) or 1
  local out = (opts.out or ".") .. "/trace.txt"
  local log = io.open(out, "w")
  local bad, nframe = {}, 0
  local function flag(s) if #bad < 60 then bad[#bad + 1] = s end; log:write("!! " .. s .. "\n") end

  -- one card of each tier
  local byTier = {}
  for _, c in ipairs(UI.CARDS) do
    if c.tier and not byTier[c.tier] and c.name and #c.name < 26 then byTier[c.tier] = c end
  end
  local batch = {}
  for t = 1, 7 do if byTier[t] then batch[#batch + 1] = byTier[t] end end

  T.slash("/wp arcade"); T.step(1)
  if G.WaypathSetup then G.WaypathSetup:Hide() end
  local frame = G.WaypathArcade
  local realOpen = RG.ArcadeOpenPack
  RG.ArcadeOpenPack = function()
    local got = {}
    for _, c in ipairs(batch) do local g = RG.ArcadeAddPull(c, finish); if g then got[#got + 1] = g end end
    return got, true, {}, { kind = "normal", free = true, pityBefore = 0, sets = {}, streak = 0 }
  end

  local reveal
  local lastW = {}
  -- every tick: look at the reveal's card frames
  local function trace(label)
    nframe = nframe + 1
    if not reveal then return end
    local rl, rr, rt, rb = reveal:GetLeft(), reveal:GetRight(), reveal:GetTop(), reveal:GetBottom()
    local line = { string.format("%s %.2f", label, nframe * dt) }
    for _, f in ipairs(W.allFrames) do
      local c = rawget(f, "card")
      local cover = rawget(f, "cover")
      if type(c) == "table" and c.name and cover and W.visible(f) and f:IsDescendantOf(reveal) then
        local cw, fw = cover:GetWidth() or 0, f:GetWidth() or 0
        local shown = cover.IsShown and cover:IsShown()
        line[#line + 1] = string.format("%s cover=%s w=%.0f/%.0f a=%.2f", c.name:sub(1, 10), shown and "on" or "off", cw, fw, cover:GetAlpha() or 1)
        -- a face showing with the cover still full width and opaque is fine; the cover gone while a card isn't flipped is not
        if not shown and not rawget(f, "flipped") and not rawget(f, "turning") and reveal.phase == nil and (reveal.flipped or 0) == 0 then
          flag(string.format("%.2fs: %s's face shows before it has been turned", nframe * dt, c.name))
        end
        local l, r = f:GetLeft(), f:GetRight()
        if l and rl and (l < rl - 4 or r > rr + 4) then flag(string.format("%.2fs: %s leaves the reveal window", nframe * dt, c.name)) end
        local pw = lastW[f]
        if pw and fw > 0 and math.abs(fw - pw) > fw * 0.5 then flag(string.format("%.2fs: %s changes width %.0f -> %.0f in one tick", nframe * dt, c.name, pw, fw)) end
        lastW[f] = fw
      end
    end
    log:write(table.concat(line, " | ") .. "\n")
  end
  local shot = 0
  local function film(name, seconds)
    local t = 0
    while t < seconds do
      T.step(dt); t = t + dt
      trace(name)
      shot = shot + 1
      T.shoot(string.format("film-%s-%03d", name, shot))
    end
  end
  local function waitFor(cond, limit, name)
    local t = 0
    while not cond() and t < limit do T.step(dt); t = t + dt; trace(name or "wait") end
    return cond()
  end

  frame.buyNow("normal")
  reveal = G.WaypathArcadePack
  if not (reveal and reveal:IsShown()) then io.stdout:write("no reveal\n") log:close() return end
  film("seal", 0.6)
  for i = 1, 3 do
    if reveal.phase ~= "seal" then break end
    T.run(reveal.seal, "OnMouseDown", "LeftButton"); film("chip" .. i, 0.2)
    T.run(reveal.seal, "OnMouseUp", "LeftButton"); film("chip" .. i, 0.3)
  end
  local t = 0
  while reveal.phase and t < 8 do film("tear", dt); t = t + dt end
  film("deal", 0.5)
  T.click(reveal.all)
  local t2 = 0
  while (reveal.flipped or 0) < #batch and t2 < 30 do film("flip", dt * 2); t2 = t2 + dt * 2 end
  film("settle", 1.5)
  log:write(string.format("\n%d ticks, %d problems\n", nframe, #bad))
  log:close()
  io.stdout:write(string.format("anim: %d ticks, %d problems (see trace.txt)\n", nframe, #bad))
  for _, b in ipairs(bad) do io.stdout:write("  " .. b .. "\n") end
  RG.ArcadeOpenPack = realOpen
end
