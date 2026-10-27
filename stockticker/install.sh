#!/bin/sh
# Stock ticker web page - installer (run ON the router, as root, from the unpacked repo)
set -e
D=$(cd "$(dirname "$0")" && pwd)
F=$D/files
[ -d /usr/lib/oui-httpd/rpc ] || { echo "Not a GL.iNet 4.x firmware (no oui-httpd rpc dir)."; exit 1; }
command -v curl >/dev/null || { echo "curl is required."; exit 1; }
cp "$F/stockticker.lua" /usr/bin/stockticker.lua && chmod +x /usr/bin/stockticker.lua
cp "$F/stockticker.init" /etc/init.d/stockticker && chmod +x /etc/init.d/stockticker
cp "$F/stockscreen.lua" /usr/bin/stockscreen.lua && chmod +x /usr/bin/stockscreen.lua
cp "$F/stockscreen.init" /etc/init.d/stockscreen && chmod +x /etc/init.d/stockscreen
cp "$F/stockticker.rpc" /usr/lib/oui-httpd/rpc/stockticker
cp "$F/stocks.html" /www/stocks.html
[ -f /etc/config/stockticker ] || cp "$F/stockticker.uci" /etc/config/stockticker
/etc/init.d/stockticker enable
/etc/init.d/stockticker restart
[ -d /etc/gl_screen ] && { /etc/init.d/stockscreen enable; /etc/init.d/stockscreen restart; }
/etc/init.d/oui-httpd restart 2>/dev/null || true
echo "Installed. Quotes also appear on the touchscreen lock screen (signature area). Log in to the admin panel, then open http://<router-ip>/stocks.html"
echo "Watchlist: uci show stockticker   |   CLI: lua /usr/bin/stockticker.lua add ASX:EOS"
