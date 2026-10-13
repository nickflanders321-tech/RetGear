-- Dump Classes/Specs.lua (every class's specs: weights, weapon model, weapons) to JSON
-- for gen.py.   Usage: lua5.1 specs_dump.lua <Waypath+ folder> <out.json>
local dir, out = arg[1], arg[2]
local RG = {}
local chunk = assert(loadfile(dir .. "/Classes/Specs.lua"))
chunk("Waypath", RG)
local function enc(v)
  local t = type(v)
  if t == "nil" then return "null" elseif t == "number" then return string.format("%.17g", v)
  elseif t == "boolean" then return tostring(v)
  elseif t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
  elseif t == "table" then
    local n, max = 0, 0
    for k in pairs(v) do n = n + 1; if type(k) == "number" and k > max then max = k end end
    if n > 0 and max == n then local p = {} for i = 1, n do p[i] = enc(v[i]) end return "[" .. table.concat(p, ",") .. "]" end
    if n == 0 then return "{}" end
    local p = {}
    for k, x in pairs(v) do p[#p + 1] = enc(tostring(k)) .. ":" .. enc(x) end
    table.sort(p)
    return "{" .. table.concat(p, ",") .. "}"
  end
  return "null"
end
local o = {}
for class, list in pairs(RG.SPECS) do
  o[class] = {}
  for i, s in ipairs(list) do
    o[class][i] = { key = s.key, name = s.name, kind = s.kind, main = s.main or false, weights = s.weights,
      model = s.model, weapons = s.weapons, shield = s.shield }
  end
end
local f = assert(io.open(out, "w")); f:write(enc(o)); f:close()
