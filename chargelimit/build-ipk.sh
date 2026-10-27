#!/bin/sh
# Builds the chargelimit opkg package. Usage: ./build-ipk.sh [outdir]
set -e
cd "$(dirname "$0")"
OUT=${1:-$PWD}
VER=1.0.1-1
ARCH=aarch64_cortex-a53
NAME=gl-sdk4-ui-chargelimit
W=$(mktemp -d "${PWD}/.build.XXXXXX")
trap 'rm -rf "$W"' EXIT
D=$W/data
mkdir -p "$D/usr/bin" "$D/etc/init.d" "$D/etc/config" "$D/usr/lib/oui-httpd/rpc" "$D/usr/share/chargelimit" "$D/usr/lib/lua/luci/controller" "$D/usr/lib/lua/luci/model/cbi" "$W/control"
cp files/charge_limit.sh "$D/usr/bin/charge_limit.sh"; chmod 755 "$D/usr/bin/charge_limit.sh"
cp files/chargelimit.init "$D/etc/init.d/chargelimit"; chmod 755 "$D/etc/init.d/chargelimit"
cp files/chargelimit.uci "$D/etc/config/chargelimit"
cp files/chargelimit.rpc "$D/usr/lib/oui-httpd/rpc/chargelimit"
cp files/patch.lua "$D/usr/share/chargelimit/patch.lua"
cp files/luci/controller/chargelimit.lua "$D/usr/lib/lua/luci/controller/chargelimit.lua"
cp files/luci/model/cbi/chargelimit.lua "$D/usr/lib/lua/luci/model/cbi/chargelimit.lua"
cat > "$W/control/control" <<EOT
Package: $NAME
Version: $VER
Depends: libc
Section: gl
Architecture: $ARCH
Maintainer: community
Installed-Size: 32000
Description: Battery charge limit for GL.iNet E5800 (slider in USB & Power, status on Overview/Internet, LuCI page)
EOT
echo /etc/config/chargelimit > "$W/control/conffiles"
cat > "$W/control/postinst" <<'EOT'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
if [ ! -d /sys/class/power_supply/cw221X-bat ]; then echo "chargelimit: unsupported hardware"; exit 0; fi
lua /usr/share/chargelimit/patch.lua apply
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/chargelimit enable
/etc/init.d/chargelimit restart
/etc/init.d/oui-httpd restart 2>/dev/null
exit 0
EOT
cat > "$W/control/prerm" <<'EOT'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
/etc/init.d/chargelimit stop
/etc/init.d/chargelimit disable
for f in /etc/chargelimit-backup/*.gz; do [ -f "$f" ] && cp "$f" /www/views/$(basename "$f"); done
rm -rf /etc/chargelimit-backup /tmp/chargelimit_held /tmp/luci-indexcache /tmp/luci-modulecache
echo 1 > /sys/devices/platform/soc/9c0000.qcom,qupv3_0_geni_se/994000.i2c/i2c-2/2-006b/sgm41542s/charge_en 2>/dev/null
exit 0
EOT
chmod 755 "$W/control/postinst" "$W/control/prerm"
echo 2.0 > "$W/debian-binary"
export COPYFILE_DISABLE=1
T="--no-xattrs --no-mac-metadata --format ustar --uid 0 --gid 0"
(cd "$W/control" && tar $T -czf ../control.tar.gz .)
(cd "$D" && tar $T -czf ../data.tar.gz .)
(cd "$W" && tar $T -czf "$OUT/${NAME}_${VER}_${ARCH}.ipk" ./debian-binary ./data.tar.gz ./control.tar.gz)
echo "built ${NAME}_${VER}_${ARCH}.ipk"
