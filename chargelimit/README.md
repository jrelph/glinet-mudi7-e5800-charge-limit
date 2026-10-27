# GL.iNet Mudi 7 (GL-E5800) Battery Charge Limit

Adds a **maximum charge level** (50–100%, default 80%) to the GL.iNet admin panel to preserve battery life.

- **System > USB & Power**: on/off switch + slider
- **System > Overview** (Battery card): "Charge limit 80%" (adds "(holding)" while charging is paused)
- **Internet page** banner: "61% / 80% limit" next to the battery icon

Behaviour: charging is paused at the limit and resumes at limit − 5%. Setting survives reboots.

## Install (recommended: .ipk package)

Build with `./build-ipk.sh` (or take it from `../feed/`), copy it to the router and run:

    scp -O gl-sdk4-ui-chargelimit_*.ipk root@<router-ip>:/tmp/
    ssh root@<router-ip> opkg install /tmp/gl-sdk4-ui-chargelimit_*.ipk

Remove with `opkg remove gl-sdk4-ui-chargelimit` (restores the original UI files and normal charging).
It also installs a LuCI page (Services > Battery Charge Limit) where LuCI is accessible.

## Install (script)

Requires SSH root access to the router. Tested on E5800, firmware 4.10.0.

From your computer:

    ./install-remote.sh <router-ip>

Or copy this folder to the router and run `sh install.sh`. Then hard-refresh the browser.

The installer checks hardware and does a dry run of the UI patches first; if your firmware differs it changes nothing.
Originals are backed up in `/etc/chargelimit-backup`.

## Uninstall

    sh uninstall.sh   (on the router)

## Notes / limitations

- Hardware-specific (cw221X gauge, SGM41542S charger). Other models are refused.
- The stock `quec_battery` daemon re-enables charging every ~20s; the limiter re-disables it every 0.2s (~2% leak), so the level may creep up slightly over a long time on the charger.
- Never SIGSTOP/kill `quec_battery`: the watchdog reboots the router.
- Firmware upgrades overwrite the UI patches; re-run `install.sh` afterwards.
- Use at your own risk; modifies system files.

## Install via custom feed

See the [top-level README](../README.md).
