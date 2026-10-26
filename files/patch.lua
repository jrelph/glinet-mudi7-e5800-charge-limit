-- usage: lua patch.lua <apply|check> ; patches GL.iNet UI chunks in /www/views (idempotent, backs up originals)
local R = 'window.$rpcRequest'
local GET = R..'("call",["sid","chargelimit","get_config",{}])'

local patches = {
 ["gl-sdk4-ui-usbpower.common.js.gz"] = {
  {'data:()=>({powerConfigForm:{wifi_sleep_time:900',
   'data:()=>({chargeLimit:{enabled:0,limit:80,capacity:0},powerConfigForm:{wifi_sleep_time:900'},
  {'created(){this.getPowerConfig()},methods:{getPowerConfig(){',
   'created(){this.getPowerConfig(),this.getChargeLimit()},methods:{getChargeLimit(){'..GET..'.then((e=>{e&&(this.chargeLimit=e)}))},setChargeLimit(){const{enabled:e,limit:t}=this.chargeLimit;'..R..'("call",["sid","chargelimit","set_config",{enabled:e,limit:t}]).then((()=>{this.$message.success(this.$t("msg.success"))}))},getPowerConfig(){'},
  {'e.powerConfigForm.system_sleep_enable?t("li",[t("div",[e._v(e._s(e.$t("power.pow',
   't("li",[t("div",[e._v("Battery charge limit "+e._s(e.chargeLimit.enabled?"("+e.chargeLimit.limit+"%)":"")+" - now "+e._s(e.chargeLimit.capacity)+"%")]),t("div",[t("gl-switch",{attrs:{size:"small",activeValue:1,inactiveValue:0},on:{change:e.setChargeLimit},model:{value:e.chargeLimit.enabled,callback:function(t){e.$set(e.chargeLimit,"enabled",t)},expression:"chargeLimit.enabled"}})],1)]),e.chargeLimit.enabled?t("li",[t("div",[e._v("Maximum charge level")]),t("div",[t("el-slider",{staticStyle:{width:"100%"},attrs:{min:50,max:100,step:5},on:{change:e.setChargeLimit},model:{value:e.chargeLimit.limit,callback:function(t){e.$set(e.chargeLimit,"limit",t)},expression:"chargeLimit.limit"}})],1)]):e._e(),e.powerConfigForm.system_sleep_enable?t("li",[t("div",[e._v(e._s(e.$t("power.pow'},
 },
 ["gl-sdk4-ui-overview.common.js.gz"] = {
  {'{name:"BatteryCard",computed:',
   '{name:"BatteryCard",data:()=>({chargeLimit:{enabled:0,limit:80},clTimer:null}),created(){this.getChargeLimit(),this.clTimer=setInterval(this.getChargeLimit,1e4)},destroyed(){clearInterval(this.clTimer)},methods:{getChargeLimit(){'..GET..'.then((t=>{t&&(this.chargeLimit=t)})).catch((()=>{}))}},computed:'},
  {'t._s(t.mcuStatus.charge_percent)+"%")])]),t.mcuStatus.temperature?',
   't._s(t.mcuStatus.charge_percent)+"%")])]),t.chargeLimit.enabled?e("li",[e("span",[t._v("Charge limit")]),e("span",[t._v(t._s(t.chargeLimit.limit)+"%"+(t.chargeLimit.held?" (holding)":""))])]):t._e(),t.mcuStatus.temperature?'},
 },
 ["gl-sdk4-ui-internet.common.js.gz"] = {
  {'pt={name:"RouterVisual",',
   'pt={name:"RouterVisual",data:()=>({chargeLimit:{enabled:0,limit:80},clTimer:null}),created(){this.getChargeLimit(),this.clTimer=setInterval(this.getChargeLimit,1e4)},destroyed(){clearInterval(this.clTimer)},'},
  {'methods:{handleToMwan(){',
   'methods:{getChargeLimit(){'..GET..'.then((t=>{t&&(this.chargeLimit=t)})).catch((()=>{}))},handleToMwan(){'},
  {'t._v(" "+t._s(t.mcu.charge_percent)+"% ")',
   't._v(" "+t._s(t.mcu.charge_percent)+"%"+(t.chargeLimit.enabled?" / "+t.chargeLimit.limit+"% limit":"")+" ")'},
 },
}

local function count(s, p)
  local n, i = 0, 1
  while true do
    local a, b = s:find(p, i, true)
    if not a then return n end
    n = n + 1; i = b + 1
  end
end

local mode = arg[1] or "apply"
local dir = arg[2] or "/www/views"
local bak = "/etc/chargelimit-backup"
os.execute("mkdir -p "..bak)
local failed = false
for fname, edits in pairs(patches) do
  local path = dir.."/"..fname
  local p = io.popen("zcat '"..path.."' 2>/dev/null")
  local src = p:read("*a"); p:close()
  if #src == 0 then
    print("SKIP  "..fname.." (not found)"); failed = true
  elseif src:find("chargelimit", 1, true) then
    print("OK    "..fname.." (already patched)")
  else
    local ok = true
    for i, e in ipairs(edits) do
      local n = count(src, e[1])
      if n ~= 1 then print("FAIL  "..fname.." edit "..i.." matched "..n.." times (firmware differs?)"); ok = false end
    end
    if ok and mode == "apply" then
      for _, e in ipairs(edits) do
        local a, b = src:find(e[1], 1, true)
        src = src:sub(1, a - 1)..e[2]..src:sub(b + 1)
      end
      os.execute("[ -f "..bak.."/"..fname.." ] || cp '"..path.."' "..bak.."/"..fname)
      local o = io.open("/tmp/_cl_patch.js", "w"); o:write(src); o:close()
      os.execute("gzip -9 -c /tmp/_cl_patch.js > '"..path.."' && rm -f /tmp/_cl_patch.js")
      print("PATCH "..fname)
    elseif ok then print("READY "..fname)
    else failed = true end
  end
end
os.exit(failed and 1 or 0)
