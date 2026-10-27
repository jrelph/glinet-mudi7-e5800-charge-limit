-- run: lua test/test_normalize.lua  (needs lua-cjson; on the router: lua /tmp/test_normalize.lua)

local M = loadfile((arg[1] or "files") .. "/stockticker.lua")("lib")
local cases = {
  { "AAPL", "AAPL" }, { " msft ", "MSFT" }, { "SPYG", "SPYG" }, { "ASX:EOS", "EOS.AX" },
  { "asx:eos", "EOS.AX" }, { "NASDAQ:GOOG", "GOOG" }, { "NYSE:BRK.B", "BRK-B" }, { "LON:VOD", "VOD.L" },
  { "HKG:700", "0700.HK" }, { "TSX:SHOP", "SHOP.TO" }, { "BTC-USD", "BTC-USD" }, { "^GSPC", "^GSPC" },
  { "AUDUSD=X", "AUDUSD=X" }, { "EOS.AX", "EOS.AX" },
  { "", nil }, { "A B", nil }, { "FOO:BAR", nil }, { "AAPL;rm -rf /", nil }, { "$(id)", nil },
  { "'x'", nil }, { string.rep("A", 30), nil },
}
local fail = 0
for _, c in ipairs(cases) do
  local got = M.normalize(c[1])
  if got ~= c[2] then fail = fail + 1; print("FAIL", c[1], got, c[2]) end
end
local q = M.parse_chart('{"chart":{"result":[{"meta":{"symbol":"X","regularMarketPrice":110,"chartPreviousClose":100,"currency":"USD"}}],"error":null}}')
assert(q and math.abs(q.pct - 10) < 1e-9 and q.change == 10, "parse")
assert(not M.parse_chart('{"chart":{"result":null,"error":{"description":"No data found"}}}'))
assert(M.is_fresh({ fetched = 1000 }, 1100, 300))
assert(not M.is_fresh({ fetched = 1000 }, 1400, 300))
assert(M.is_fresh({ fetched = 5000, reg_end = 4000 }, 9000, 300))
print(fail == 0 and "ALL PASS" or (fail .. " FAILED"))
os.exit(fail == 0 and 0 or 1)
