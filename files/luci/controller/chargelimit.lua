module("luci.controller.chargelimit", package.seeall)

function index()
	entry({"admin", "services", "chargelimit"}, cbi("chargelimit"), _("Battery Charge Limit"), 60).dependent = false
end
