-- Scene scripts (run.lua --shoot FILE --out DIR): a script puts something on screen and calls T.shoot("name"),
-- which writes DIR/name.json, the draw list tools/render/render.py turns into DIR/name.png. A script is a Lua
-- file returning function(T). See tools/render/README.md.
local M = {}

local function clean(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end

function M.run(W, L, RG, opts)
  local G, S = W.G, W.S
  local out = opts.out or "."
  local T = { W = W, L = L, RG = RG, G = G, shots = {}, fps = tonumber(opts.fps) or 30 }
  local index = {}

  function T.step(seconds, fps) W.step(seconds or 0.1, fps or T.fps) end
  function T.slash(text) W.context = text; return W.slash(text) end
  function T.click(f, button)
    if not f then return false end
    W.context = "click " .. W.describe(f)
    if f.Click then f:Click(button or "LeftButton") end
    return true
  end
  function T.run(f, script, ...) W.runScript(f, script, ...) end
  -- the mouse over a frame (its highlight shows, its OnEnter runs); nil takes it away
  function T.hover(f)
    if L.hover and L.hover ~= f then W.runScript(L.hover, "OnLeave") end
    L.hover = f
    if f then
      local x, y = f:GetCenter()
      local es = L.effScale(f)
      L.mouse = x and { x * es, y * es } or nil
      W.runScript(f, "OnEnter")
    else L.mouse = nil end
  end
  -- the first visible font string (or button) showing a text, and its frame
  function T.findText(text, root)
    local found
    local function walk(f)
      if found or not W.visible(f) then return end
      local st = S[f]
      for _, r in ipairs(st.regions) do
        local rs = S[r]
        if rs.type == "FontString" and rs.shown and rs.text and clean(rs.text):find(text, 1, true) then found = f return end
      end
      for _, c in ipairs(st.children) do walk(c) end
    end
    if root then walk(root) else for _, f in ipairs(W.allFrames) do if not S[f].parent then walk(f) end end walk(G.UIParent) end
    return found
  end
  -- every visible frame of the add-on that sits directly on UIParent (its windows)
  function T.windows()
    local t = {}
    for _, f in ipairs(W.allFrames) do
      local st = S[f]
      if not st.owned and (st.parent == G.UIParent or st.parent == nil) and W.visible(f) then t[#t + 1] = f end
    end
    return t
  end
  function T.hideAll() for _, f in ipairs(T.windows()) do f:Hide() end end
  function T.shoot(name, o)
    o = o or {}
    o.name = name
    local path = out .. "/" .. name .. ".json"
    local n = L.writeScene(path, o)
    index[#index + 1] = name
    T.shots[#T.shots + 1] = { name = name, items = n }
    return n
  end

  local script = opts.shoot
  local chunk, err = loadfile(script)
  if not chunk then io.stderr:write("can't load " .. tostring(script) .. ": " .. tostring(err) .. "\n") return false end
  local fn = chunk()
  W.phase = "scene " .. script
  W.call("the scene script " .. script, fn, T, opts)
  local fh = assert(io.open(out .. "/index.json", "wb"))
  fh:write(W.json(index))
  fh:close()
  for _, s in ipairs(T.shots) do io.stdout:write(string.format("scene %-40s %5d items\n", s.name, s.items)) end
  if #W.errors > 0 then
    for _, e in ipairs(W.errors) do io.stdout:write("LUA ERROR " .. tostring(e.msg) .. " at " .. tostring(e.where) .. " (" .. tostring(e.context) .. ")\n") end
  end
  return #W.errors == 0
end

return M
