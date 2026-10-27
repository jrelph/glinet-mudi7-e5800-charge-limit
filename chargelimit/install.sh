#!/bin/sh
# GL.iNet battery charge limit - installer (run ON the router, as root)
set -e
D=$(cd "$(dirname "$0")" && pwd)
F=$D/files
[ -d /sys/class/power_supply/cw221X-bat ] || { echo "No cw221X-bat battery found - this plugin targets the GL.iNet E5800 (Puck)."; exit 1; }
[ -d /sys/devices/platform/soc/9c0000.qcom,qupv3_0_geni_se/994000.i2c/i2c-2/2-006b/sgm41542s ] || { echo "Charger chip sgm41542s not found - unsupported hardware."; exit 1; }
echo "Dry-run check of UI patches..."
lua "$F/patch.lua" check || { echo "UI patch check failed (different firmware?). Nothing changed."; exit 1; }
cp "$F/charge_limit.sh" /usr/bin/charge_limit.sh && chmod +x /usr/bin/charge_limit.sh
cp "$F/chargelimit.init" /etc/init.d/chargelimit && chmod +x /etc/init.d/chargelimit
cp "$F/chargelimit.rpc" /usr/lib/oui-httpd/rpc/chargelimit
[ -f /etc/config/chargelimit ] || cp "$F/chargelimit.uci" /etc/config/chargelimit
lua "$F/patch.lua" apply
if [ -d /usr/lib/lua/luci ]; then
	cp "$F/luci/controller/chargelimit.lua" /usr/lib/lua/luci/controller/chargelimit.lua
	cp "$F/luci/model/cbi/chargelimit.lua" /usr/lib/lua/luci/model/cbi/chargelimit.lua
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
	echo "LuCI page installed: Services > Battery Charge Limit"
fi
/etc/init.d/chargelimit enable
/etc/init.d/chargelimit restart
/etc/init.d/oui-httpd restart 2>/dev/null || true
echo
echo "Installed. Open the admin panel > System > USB & Power to set the limit."
echo "Shown on Overview and Internet pages too. Hard-refresh the browser (Cmd/Ctrl+Shift+R)."
