#!/bin/sh
# Battery charge limiter for GL.iNet E5800. Config: /etc/config/chargelimit
BAT=/sys/class/power_supply/cw221X-bat
I2C=/sys/devices/platform/soc/9c0000.qcom,qupv3_0_geni_se/994000.i2c/i2c-2
MAIN=$I2C/2-006b/sgm41542s
PUMP=$I2C/2-006f/sgm41600
STATE=/tmp/chargelimit_held

# Prefer the MCU percentage (what the UI and screen show); fall back to the gauge.
get_cap() {
	c=$(ubus call mcu status 2>/dev/null | sed -n 's/.*"charge_percent": *\([0-9]*\).*/\1/p')
	[ -n "$c" ] || c=$(cat $BAT/capacity 2>/dev/null)
	echo "$c"
}

release() {
	[ -f $STATE ] || return
	echo 5100000 > $MAIN/ichrg_curr
	echo 1 > $MAIN/charge_en
	rm -f $STATE
	logger -t chargelimit "released, charging allowed"
}

hold() {
	echo 0 > $MAIN/charge_en
	echo 0 > $PUMP/charge_en
	[ -f $STATE ] || logger -t chargelimit "limit reached, charging held"
	touch $STATE
}

# The stock quec_battery daemon re-enables charging periodically, so while
# held we re-assert charge_en=0 several times a second.
guard() {
	i=0
	while [ $i -lt 25 ]; do
		[ "$(cat $MAIN/charge_en)" = 1 ] && echo 0 > $MAIN/charge_en
		sleep 0.2
		i=$((i + 1))
	done
}

while true; do
	en=$(uci -q get chargelimit.main.enabled)
	lim=$(uci -q get chargelimit.main.limit)
	hys=$(uci -q get chargelimit.main.hysteresis)
	[ -n "$lim" ] || lim=80
	[ -n "$hys" ] || hys=5
	cap=$(get_cap)
	if [ "$en" = 1 ] && [ -n "$cap" ]; then
		if [ "$cap" -ge "$lim" ]; then
			hold
		elif [ "$cap" -le $((lim - hys)) ]; then
			release
		elif [ -f $STATE ]; then
			hold
		fi
	else
		release
	fi
	if [ -f $STATE ]; then guard; else sleep 5; fi
done
