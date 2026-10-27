# Can a stock-quote app run on the Mudi 7 (GL-E5800) touchscreen?

**Verdict: the native on-device screen is not extensible, so a real touchscreen app is not feasible without
replacing the stock UI. A web page in the admin panel session (fallback) is feasible and is what this repo ships.**

## Evidence (firmware 4.10.0, OpenWrt 23.05.4, aarch64; read-only inspection)

| Question | Finding |
|---|---|
| What draws the screen? | `/usr/bin/gl_screen -c /tmp/gl_screen/config` (procd service `gl_screen`, 3.6 MB closed C binary, statically embeds LVGL, links freetype, libcurl, jansson, libubus). Draws on `/dev/fb0`, 240x320. Touch: `/dev/input/event0` (`chsc_cap_touch`). |
| Plugin / widget / page mechanism? | None found. Pages (home, Internet, Wi-Fi, Clients, Tethering, Settings, lock screen) are compiled in. `/etc/gl_screen/` holds only PNG assets, fonts, language strings, layout coordinates and a flat key/value config (brightness, auto-lock, wallpaper, passcode, owner "signature" text). No scripts, no dlopen of add-ons, no web view. |
| ubus API | `gl_screen` exposes a single method `set` (`reload`, `config_update` of those key/values). Not a drawing API. |
| What is `mcu`? | `/usr/bin/mcu` is a Lua script (run by `eco`) that talks over UART to a separate MCU for OLED-style status screens (`send_custom_msg`, `cmd_json`, `cmd_string`, `set_warning`, battery state). On the E5800 its config has `custom_enabled=0`, and battery data is what it is used for; the colour LCD is driven by `gl_screen`, not by it. No evidence `send_custom_msg` reaches the LCD. |
| Only user-text on screen | The lock-screen "personalised signature" (about 208x45 px label). Writable through the stock `screen` rpc + `gl_screen set`. Tiny, replaces the owner/finder text, and each update triggers a screen config reload, so it was deliberately **not** used. |
| Takeover option | A custom framebuffer + touch app (e.g. cross-compiled Go) could draw on `/dev/fb0`, but only by stopping `gl_screen`, which removes the whole stock UI, has no launcher entry, and fights the power/lock logic. Not attempted; not recommended. |
| Free space / runtimes | Overlay 2.7 GB free. `lua` 5.1, `lua-cjson`, `libuci-lua`, `curl` 8.7 (OpenSSL 3), `uclient-fetch`. No Python. |
| Internet fetch | Yahoo Finance chart endpoint works from the router over HTTPS (JSON, no key). `ASX:EOS` maps to `EOS.AX` (works). Stooq CSV returned 404 (not usable). Nasdaq's public API works for US tickers only; Google Finance needs HTML scraping. |
| Gotcha | Yahoo returns HTTP 429 for `curl/…` and for long browser-like User-Agent strings from this network, but accepts the bare `Mozilla/5.0`. Early testing with other UAs triggered long blocks. |

## What was built instead (fallback, clearly not on the physical screen)

* `stockticker.lua`: fetcher + CLI, watchlist in UCI (`/etc/config/stockticker`), cache at `/tmp/stockticker/quotes.json`.
* `stockticker` rpc module (admin-session protected) and `/www/stocks.html`, a dark, phone-friendly page to add/remove
  tickers and see prices.

The page can be opened from the admin panel's host (or a phone/laptop on the router's Wi-Fi) at `/stocks.html`.

## Update: lock-screen ticker works

The lock-screen signature label can be driven live with
`ubus call gl_screen set '{"method":"config_update","params":{"config":{"SIGNATURE":"..."}}}'`
(the same call the GL web UI makes). It renders instantly with no restart.
The label fits about 4 lines of ~14 characters. `files/stockscreen.lua` pushes one line per stock
(max 4) from the quote cache and only writes when text changes, because each update commits to flash.
`files/stockscreen.init` restores the original signature on stop.
Install by hand: copy to `/usr/bin/stockscreen.lua` and `/etc/init.d/stockscreen`, then `enable` and `start`.
The screen framebuffer can be captured with `dd if=/dev/fb0` (240x320, BGR;16).
