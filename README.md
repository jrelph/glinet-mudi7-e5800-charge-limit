# GL.iNet Mudi 7 (GL-E5800) Enhancements

Small plug-ins for the GL.iNet Mudi 7 travel router (tested on firmware 4.10.0). Install page: https://jrelph.github.io/glinet-mudi7-enhancements/

| Plug-in | What it does |
|---|---|
| [`chargelimit`](chargelimit/) | Battery charge limit (50-100%, default 80%) with a slider in System > USB & Power, status on Overview and Internet. |
| [`stockticker`](stockticker/) | Stock/ETF watchlist (`AAPL`, `SPYG`, `ASX:EOS`...) shown on the built-in touchscreen lock screen, plus a manage page at `/stocks.html`. |

## Install via the GL.iNet UI

Applications > Plug-ins > Manage Sources, add name `mudi7` and URL
`https://jrelph.github.io/glinet-mudi7-enhancements/feed`, then Refresh and install the plug-in you want.

Or on the router:

    echo 'src/gz mudi7 https://jrelph.github.io/glinet-mudi7-enhancements/feed' >> /etc/opkg/customfeeds.conf
    opkg update && opkg install gl-sdk4-ui-chargelimit gl-sdk4-ui-stockticker

Each plug-in folder also has `install.sh` / `uninstall.sh` and its own README.

## Build

    ./build-feed.sh    # builds both ipks into feed/ and regenerates Packages(.gz)

## Notes

- Hardware- and firmware-specific; the installers refuse unsupported devices. Firmware upgrades wipe the patches: reinstall.
- The stock ticker uses Yahoo's unofficial API (delayed, may break). Not financial advice.
- Unofficial, not affiliated with GL.iNet. Use at your own risk; these modify system files.
