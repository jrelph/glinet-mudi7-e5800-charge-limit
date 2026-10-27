#!/bin/sh
# Removes the stock ticker (watchlist config is removed too) and restores the lock-screen signature
/etc/init.d/stockscreen stop 2>/dev/null
/etc/init.d/stockscreen disable 2>/dev/null
/etc/init.d/stockticker stop 2>/dev/null
/etc/init.d/stockticker disable 2>/dev/null
rm -rf /usr/bin/stockticker.lua /usr/bin/stockscreen.lua /etc/init.d/stockticker /etc/init.d/stockscreen /usr/lib/oui-httpd/rpc/stockticker /www/stocks.html /etc/config/stockticker /etc/stockscreen.orig /tmp/stockticker
/etc/init.d/oui-httpd restart 2>/dev/null
echo "Uninstalled."
