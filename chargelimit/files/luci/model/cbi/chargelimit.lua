local fs = require "nixio.fs"

m = Map("chargelimit", translate("Battery Charge Limit"),
	translate("Pauses charging at the chosen level to extend battery lifespan, and resumes when it drops by the hysteresis amount."))

s = m:section(NamedSection, "main", "chargelimit", translate("Settings"))
s.addremove = false

st = s:option(DummyValue, "_status", translate("Status"))
st.rawhtml = true
function st.cfgvalue()
	local c = tonumber((fs.readfile("/sys/class/power_supply/cw221X-bat/capacity") or "0"):match("%d+")) or 0
	local held = fs.access("/tmp/chargelimit_held")
	return string.format("Battery %d%% &mdash; %s", c, held and "charging paused (limit reached)" or "charging normally")
end

s:option(Flag, "enabled", translate("Enable charge limit"))

lim = s:option(Value, "limit", translate("Maximum charge level (%)"))
lim.datatype = "range(50,100)"
lim.default = "80"
lim.rmempty = false

hys = s:option(Value, "hysteresis", translate("Resume hysteresis (%)"))
hys.datatype = "range(1,20)"
hys.default = "5"

return m
