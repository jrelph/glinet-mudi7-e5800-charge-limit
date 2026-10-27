# Stock ticker for GL.iNet Mudi 7 (GL-E5800)

Watchlist of stock/ETF codes (`AAPL`, `SPYG`, `ASX:EOS`, ...) with delayed prices from Yahoo Finance.

Quotes are shown on the **touchscreen lock screen** (the "signature" text area, up to 4 lines) and on a manage page at
`/stocks.html`. The built-in screen (`gl_screen`) is a closed binary with no plugin mechanism, so the ticker drives its
signature label with the same `ubus` call the admin UI uses. Your own signature text is saved in `/etc/stockscreen.orig`
and restored when the service stops or the package is removed. See [docs/VIABILITY.md](docs/VIABILITY.md).

## Install

Option A, opkg package (build on your computer, then on the router):

```sh
./build-ipk.sh
scp -O gl-sdk4-ui-stockticker_1.1.0-1_aarch64_cortex-a53.ipk root@<router-ip>:/tmp/
ssh root@<router-ip> opkg install /tmp/gl-sdk4-ui-stockticker_1.1.0-1_aarch64_cortex-a53.ipk
```

Option B, copy the repo to the router and run `sh install.sh`. Remove with `sh uninstall.sh` or `opkg remove gl-sdk4-ui-stockticker`.

Then log in to the admin panel and open `http://<router-ip>/stocks.html`.
Requires `curl`, `lua-cjson`, `libuci-lua` (all present on stock GL firmware 4.x).

## Use

* Web page: type a code and press Add; tap x to remove; Refresh forces an update.
* CLI: `lua /usr/bin/stockticker.lua add ASX:EOS | remove AAPL | list | force | quotes`
* UCI: `uci add_list stockticker.main.symbol='NASDAQ:GOOG'; uci commit stockticker`
* Settings: `stockticker.main.interval` (seconds, 60-86400, default 300), `stockticker.main.enabled`.

## Symbols

Plain codes are passed to Yahoo as-is (`AAPL`, `SPYG`, `BTC-USD`, `^GSPC`, `AUDUSD=X`, `EOS.AX`).
`EXCHANGE:CODE` is mapped: `ASX:EOS` -> `EOS.AX`, `LON:VOD` -> `VOD.L`, `TSX:SHOP` -> `SHOP.TO`, `HKG:700` -> `0700.HK`,
`NASDAQ:`/`NYSE:`/`NYSEARCA:` prefixes are dropped (see the table in `files/stockticker.lua`). Codes are validated
(`A-Z 0-9 . : ^ = - _`, max 24 chars) before anything is fetched.

## Rate-limit behaviour

One sequential request per symbol (1 s apart), only for quotes older than the interval. Once a market's regular session
has closed and a post-close quote is cached, it is not refetched for 6 h. HTTP 429 stops fetching for 15 minutes and keeps
showing the last prices (marked `*`). Uses the bare `Mozilla/5.0` User-Agent because Yahoo blocks others on some networks.

## Not included / risks

* No change to the physical screen, charger, MCU or other GL files. Nothing in `/www/views` is patched, so it coexists with the charge-limit plugin and survives GL UI updates (a firmware upgrade may wipe `/www/stocks.html`; reinstall).
* `/www/stocks.html` is static and reachable without login (GL serves `.html` files that way); all data goes through the authenticated `/rpc`.
* Yahoo's unofficial endpoint can change or block without notice. Data is delayed; not financial advice.
* Tested on firmware 4.10.0: fetcher, symbol mapping, watchlist edits, cache, rpc module functions, opkg install. Not tested: the page in a logged-in browser (requires the admin password), and the rpc path through `/rpc` with a real session.
