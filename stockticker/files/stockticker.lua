#!/usr/bin/lua
-- Stock ticker fetcher for GL.iNet routers (OpenWrt, Lua 5.1, curl, lua-cjson, uci).
-- usage: stockticker.lua <fetch|force|daemon|list|add SYM|remove SYM|quotes>
local cjson = require "cjson"

local M = {}

local STATE_DIR = os.getenv("STOCKTICKER_DIR") or "/tmp/stockticker"
local CACHE = STATE_DIR .. "/quotes.json"
local BACKOFF = STATE_DIR .. "/backoff"
-- Yahoo answers 429 to unusual/long User-Agent strings from some networks; a bare "Mozilla/5.0" works
local UA = "Mozilla/5.0"
local BASE = "https://query1.finance.yahoo.com/v8/finance/chart/"
local MAX_SYMBOLS = 30

-- exchange prefix -> Yahoo suffix ("" = none)
local EXCHANGES = {
  ASX = ".AX", NZX = ".NZ", NZE = ".NZ", LON = ".L", LSE = ".L", TSX = ".TO", TSE = ".T",
  TYO = ".T", HKG = ".HK", HKEX = ".HK", SGX = ".SI", EPA = ".PA", FRA = ".F", ETR = ".DE",
  XETRA = ".DE", AMS = ".AS", BIT = ".MI", BME = ".MC", SWX = ".SW", STO = ".ST", CPH = ".CO",
  HEL = ".HE", OSL = ".OL", NSE = ".NS", BOM = ".BO", KRX = ".KS", SHA = ".SS", SHE = ".SZ",
  TPE = ".TW", JSE = ".JO", TLV = ".TA", NASDAQ = "", NYSE = "", NYSEARCA = "", NYSEAMERICAN = "",
  AMEX = "", BATS = "", OTC = "", OTCMKTS = "", CBOE = "", US = "",
}

-- "ASX:EOS" -> "EOS.AX". Returns nil if the code is not acceptable.
function M.normalize(input)
  if type(input) ~= "string" then return nil end
  local s = input:gsub("^%s+", ""):gsub("%s+$", ""):upper()
  if s == "" or #s > 24 or not s:match("^[%w%.:%^=%-_]+$") then return nil end
  local ex, code = s:match("^(%w+):([%w%.%^=%-_]+)$")
  if ex then
    local suffix = EXCHANGES[ex]
    if suffix == nil then return nil end
    if suffix == ".HK" and code:match("^%d+$") then code = string.format("%04d", tonumber(code)) end
    code = code:gsub("%.", "-")
    if suffix == "" then return code end
    return code .. suffix
  end
  if s:find(":", 1, true) then return nil end
  return s
end

local function shq(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

local function read_file(p)
  local f = io.open(p, "r"); if not f then return nil end
  local d = f:read("*a"); f:close(); return d
end

local function write_atomic(p, data)
  local tmp = p .. ".tmp"
  local f = assert(io.open(tmp, "w")); f:write(data); f:close()
  assert(os.rename(tmp, p))
end

local function mkdir() os.execute("mkdir -p " .. shq(STATE_DIR)) end

-- UCI helpers (all optional so the module can be unit-tested off-device)
local function cursor()
  local ok, uci = pcall(require, "uci")
  if not ok then return nil end
  return uci.cursor()
end

function M.get_config()
  local cfg = { enabled = 1, interval = 300, symbols = {} }
  local c = cursor()
  if not c then return cfg end
  local e = tonumber(c:get("stockticker", "main", "enabled"))
  if e ~= nil then cfg.enabled = e end
  local i = tonumber(c:get("stockticker", "main", "interval"))
  if i then cfg.interval = math.max(60, math.min(86400, math.floor(i))) end
  local l = c:get("stockticker", "main", "symbol")
  if type(l) == "string" then l = { l } end
  cfg.symbols = l or {}
  return cfg
end

function M.save_symbols(list)
  local c = cursor(); if not c then return false end
  if not c:get("stockticker", "main") then c:set("stockticker", "main", "stockticker") end
  if #list == 0 then c:delete("stockticker", "main", "symbol")
  else c:set("stockticker", "main", "symbol", list) end
  c:commit("stockticker")
  return true
end

function M.set_options(enabled, interval)
  local c = cursor(); if not c then return false end
  if not c:get("stockticker", "main") then c:set("stockticker", "main", "stockticker") end
  if enabled ~= nil then c:set("stockticker", "main", "enabled", tonumber(enabled) == 1 and "1" or "0") end
  if interval ~= nil then
    local i = math.max(60, math.min(86400, math.floor(tonumber(interval) or 300)))
    c:set("stockticker", "main", "interval", tostring(i))
  end
  c:commit("stockticker")
  return true
end

function M.add(sym)
  local n = M.normalize(sym)
  if not n then return nil, "invalid symbol" end
  local cfg = M.get_config()
  for _, s in ipairs(cfg.symbols) do
    if M.normalize(s) == n then return true end
  end
  if #cfg.symbols >= MAX_SYMBOLS then return nil, "watchlist full" end
  -- keep what the user typed (uppercased) so the display matches their input
  cfg.symbols[#cfg.symbols + 1] = (sym:gsub("^%s+", ""):gsub("%s+$", ""):upper())
  M.save_symbols(cfg.symbols)
  return true
end

function M.remove(sym)
  local n = M.normalize(sym)
  if not n then return nil, "invalid symbol" end
  local keep = {}
  for _, s in ipairs(M.get_config().symbols) do
    if M.normalize(s) ~= n then keep[#keep + 1] = s end
  end
  M.save_symbols(keep)
  return true
end

-- Parse a Yahoo v8 chart response body into a quote table.
function M.parse_chart(body)
  local ok, j = pcall(cjson.decode, body)
  if not ok or type(j) ~= "table" or type(j.chart) ~= "table" then return nil, "bad response" end
  local r = j.chart.result
  if type(r) ~= "table" or type(r[1]) ~= "table" then
    local d = type(j.chart.error) == "table" and j.chart.error.description
    return nil, (type(d) == "string" and d) or "not found"
  end
  local m = r[1].meta or {}
  local price = tonumber(m.regularMarketPrice)
  if not price then return nil, "no price" end
  local prev = tonumber(m.chartPreviousClose) or tonumber(m.previousClose)
  local change, pct
  if prev and prev ~= 0 then
    change = price - prev
    pct = change / prev * 100
  else
    pct = tonumber(m.regularMarketChangePercent)
  end
  local reg = type(m.currentTradingPeriod) == "table" and m.currentTradingPeriod.regular or nil
  return {
    yahoo = m.symbol, name = m.shortName or m.longName, currency = m.currency,
    exchange = m.fullExchangeName, price = price, prev = prev, change = change, pct = pct,
    market_time = tonumber(m.regularMarketTime),
    reg_start = reg and tonumber(reg.start), reg_end = reg and tonumber(reg["end"]),
  }
end

local function http_get(url)
  local cmd = string.format("curl -sS -m 15 -A %s -w '\\n%%{http_code}' %s 2>&1", shq(UA), shq(url))
  local p = io.popen(cmd); if not p then return nil, "curl failed" end
  local out = p:read("*a") or ""; p:close()
  local body, code = out:match("^(.*)\n(%d+)$")
  if not body then return nil, (out:gsub("%s+$", ""):sub(1, 120)) end
  return body, tonumber(code)
end

function M.fetch_one(norm)
  local body, code = http_get(BASE .. norm:gsub("[%^=]", { ["^"] = "%5E", ["="] = "%3D" }) .. "?range=1d&interval=1d")
  if not body then return nil, code end
  if code == 429 then return nil, "rate limited", true end
  if code == 404 then return nil, "unknown symbol" end
  if code ~= 200 then return nil, "http " .. tostring(code) end
  return M.parse_chart(body)
end

-- A quote is fresh enough to skip if younger than interval, or the market is closed
-- and the cached value was taken after that session closed.
function M.is_fresh(q, now, interval)
  if not q or not q.fetched or q.error then return false end
  if now - q.fetched < interval then return true end
  if q.reg_end and now > q.reg_end and q.fetched >= q.reg_end then
    return now - q.fetched < 6 * 3600
  end
  return false
end

function M.market_state(q, now)
  if not q or not q.reg_start then return "unknown" end
  if now >= q.reg_start and now < q.reg_end then return "open" end
  return "closed"
end

function M.load_cache()
  local d = read_file(CACHE)
  if not d then return { quotes = {} } end
  local ok, j = pcall(cjson.decode, d)
  if not ok or type(j) ~= "table" or type(j.quotes) ~= "table" then return { quotes = {} } end
  return j
end

-- Refresh stale quotes. force=true ignores freshness (still honours rate-limit backoff).
function M.fetch(force)
  mkdir()
  local cfg = M.get_config()
  local now = os.time()
  local cache = M.load_cache()
  local byuser = {}
  for _, q in ipairs(cache.quotes) do byuser[q.symbol] = q end

  local backoff = tonumber(read_file(BACKOFF) or "")
  local blocked = backoff and backoff > now

  local out = {}
  local fetched_any = false
  for idx, sym in ipairs(cfg.symbols) do
    local norm = M.normalize(sym)
    local old = byuser[sym]
    local q = old
    if norm and (force or not M.is_fresh(old, now, cfg.interval)) and not blocked then
      if fetched_any then os.execute("sleep 1") end
      fetched_any = true
      local res, err, limited = M.fetch_one(norm)
      if limited then
        blocked = true
        write_atomic(BACKOFF, tostring(os.time() + 900))
        q = old or { symbol = sym, error = err }
        if old then q.stale = true end
      elseif res then
        res.symbol = sym; res.fetched = os.time()
        q = res
      else
        q = { symbol = sym, yahoo = norm, error = err or "error", fetched = os.time() }
        if old and old.price then q.price, q.change, q.pct, q.currency, q.name, q.stale = old.price, old.change, old.pct, old.currency, old.name, true end
      end
    elseif not norm then
      q = { symbol = sym, error = "invalid symbol" }
    elseif not q then
      q = { symbol = sym, yahoo = norm, error = blocked and "rate limited" or "pending" }
    end
    out[idx] = q
  end
  if not blocked then os.remove(BACKOFF) end
  for _, q in ipairs(out) do q.state = M.market_state(q, os.time()) end
  write_atomic(CACHE, cjson.encode({ updated = os.time(), interval = cfg.interval, quotes = out }))
  return out
end

-- Seconds until the next quote could need refreshing; used by the daemon loop.
function M.daemon()
  mkdir()
  while true do
    local cfg = M.get_config()
    if cfg.enabled == 1 and #cfg.symbols > 0 then pcall(M.fetch, false) end
    os.execute("sleep " .. tostring(math.max(30, math.min(cfg.interval, 300))))
  end
end

local function main(a)
  local cmd = a[1] or "fetch"
  if cmd == "fetch" then M.fetch(false)
  elseif cmd == "force" then M.fetch(true)
  elseif cmd == "daemon" then M.daemon()
  elseif cmd == "list" then
    for _, s in ipairs(M.get_config().symbols) do print(s, M.normalize(s) or "INVALID") end
  elseif cmd == "add" then
    local ok, err = M.add(a[2] or ""); if not ok then io.stderr:write(err .. "\n"); os.exit(1) end
  elseif cmd == "remove" then
    local ok, err = M.remove(a[2] or ""); if not ok then io.stderr:write(err .. "\n"); os.exit(1) end
  elseif cmd == "quotes" then
    for _, q in ipairs(M.load_cache().quotes) do
      print(string.format("%-10s %10s %8s  %s", q.symbol, q.price and string.format("%.2f", q.price) or "-",
        q.pct and string.format("%+.2f%%", q.pct) or "-", q.error or q.currency or ""))
    end
  else
    io.stderr:write("usage: stockticker.lua fetch|force|daemon|list|add SYM|remove SYM|quotes\n"); os.exit(2)
  end
end

if select("#", ...) > 0 and (...) == "lib" then return M end
main(arg)
