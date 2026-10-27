#!/bin/sh
# Builds an opkg package (architecture-independent scripts, tagged for aarch64_cortex-a53). Run on the dev machine.
set -e
cd "$(dirname "$0")"
OUT=${1:-$PWD}
VER=1.1.0-1
ARCH=aarch64_cortex-a53
NAME=gl-sdk4-ui-stockticker
W=$(mktemp -d "${PWD}/.build.XXXXXX")
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/data/usr/bin" "$W/data/etc/init.d" "$W/data/etc/config" "$W/data/usr/lib/oui-httpd/rpc" "$W/data/www" "$W/control"
cp files/stockticker.lua "$W/data/usr/bin/stockticker.lua"; chmod 755 "$W/data/usr/bin/stockticker.lua"
cp files/stockscreen.lua "$W/data/usr/bin/stockscreen.lua"; chmod 755 "$W/data/usr/bin/stockscreen.lua"
cp files/stockscreen.init "$W/data/etc/init.d/stockscreen"; chmod 755 "$W/data/etc/init.d/stockscreen"
cp files/stockticker.init "$W/data/etc/init.d/stockticker"; chmod 755 "$W/data/etc/init.d/stockticker"
cp files/stockticker.uci "$W/data/etc/config/stockticker"
cp files/stockticker.rpc "$W/data/usr/lib/oui-httpd/rpc/stockticker"
cp files/stocks.html "$W/data/www/stocks.html"
cat > "$W/control/control" <<EOF
Package: $NAME
Version: $VER
Depends: libc, curl, lua-cjson, libuci-lua
Section: gl
Architecture: $ARCH
Maintainer: community
Installed-Size: 24000
Description: Stock ticker for GL.iNet E5800 (quotes on the touchscreen lock screen + watchlist page at /stocks.html)
EOF
echo /etc/config/stockticker > "$W/control/conffiles"
cat > "$W/control/postinst" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
/etc/init.d/stockticker enable
/etc/init.d/stockticker restart
[ -d /etc/gl_screen ] && { /etc/init.d/stockscreen enable; /etc/init.d/stockscreen restart; }
/etc/init.d/oui-httpd restart 2>/dev/null
exit 0
EOF
cat > "$W/control/prerm" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
/etc/init.d/stockscreen stop
/etc/init.d/stockscreen disable
rm -f /etc/stockscreen.orig
/etc/init.d/stockticker stop
/etc/init.d/stockticker disable
rm -rf /tmp/stockticker
exit 0
EOF
chmod 755 "$W/control/postinst" "$W/control/prerm"
echo 2.0 > "$W/debian-binary"
export COPYFILE_DISABLE=1
(cd "$W/control" && tar --format ustar --uid 0 --gid 0 -czf ../control.tar.gz .)
(cd "$W/data" && tar --format ustar --uid 0 --gid 0 -czf ../data.tar.gz .)
(cd "$W" && tar --format ustar --uid 0 --gid 0 -czf "$OUT/${NAME}_${VER}_${ARCH}.ipk" ./debian-binary ./data.tar.gz ./control.tar.gz)
echo "built ${NAME}_${VER}_${ARCH}.ipk"
