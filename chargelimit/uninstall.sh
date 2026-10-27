#!/bin/sh
# Removes the charge limit plugin and restores original UI files
/etc/init.d/chargelimit stop 2>/dev/null
/etc/init.d/chargelimit disable 2>/dev/null
for f in /etc/chargelimit-backup/*.gz; do [ -f "$f" ] && cp "$f" /www/views/$(basename "$f"); done
rm -f /usr/lib/lua/luci/controller/chargelimit.lua /usr/lib/lua/luci/model/cbi/chargelimit.lua; rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
rm -rf /etc/chargelimit-backup /usr/bin/charge_limit.sh /etc/init.d/chargelimit /usr/lib/oui-httpd/rpc/chargelimit /etc/config/chargelimit /tmp/chargelimit_held
echo 1 > /sys/devices/platform/soc/9c0000.qcom,qupv3_0_geni_se/994000.i2c/i2c-2/2-006b/sgm41542s/charge_en 2>/dev/null
/etc/init.d/oui-httpd restart 2>/dev/null
echo "Uninstalled; charging restored to stock behaviour."
