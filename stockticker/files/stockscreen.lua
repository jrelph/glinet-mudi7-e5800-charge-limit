-- Pushes the cached stock quotes onto the lock-screen "signature" label
-- of the built-in touchscreen. Writes only when the text changes (flash wear).
local cjson = require "cjson"

local QUOTES = "/tmp/stockticker/quotes.json"
local INTERVAL = 60
local MAX_LINES = 4

local function read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a"); f:close()
  return s
end

local function fmt_price(p)
  if p >= 100 then return string.format("%.0f", p) end
  return string.format("%.1f", p)
end

local function build()
  local raw = read(QUOTES)
  if not raw then return nil end
  local ok, data = pcall(cjson.decode, raw)
  if not ok or type(data.quotes) ~= "table" then return nil end
  local lines = {}
  for _, q in ipairs(data.quotes) do
    if #lines >= MAX_LINES then break end
    if q.price and q.pct then
      local sym = (q.symbol or "?"):gsub("^.*:", "")
      lines[#lines + 1] = string.format("%s %s %+.1f%%", sym, fmt_price(q.price), q.pct)
    end
  end
  if #lines == 0 then return nil end
  return table.concat(lines, "\n")
end

local function push(text)
  local msg = cjson.encode({ method = "config_update",
    params = { config = { SIGNATURE = text } } })
  local p = io.popen("ubus call gl_screen set '" .. msg:gsub("'", "") .. "' 2>&1")
  p:read("*a"); p:close()
end

local last
while true do
  local text = build()
  if text and text ~= last then
    push(text)
    last = text
  end
  os.execute("sleep " .. (text and INTERVAL or 5))
end
