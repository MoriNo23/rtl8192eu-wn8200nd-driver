# rtl8192eu-wn8200nd-driver

Driver fork for the **TP-Link TL-WN8200ND(UN) V2/V3** USB WiFi adapter (Realtek **RTL8192EU**, USB 2.0, 802.11n 2T2R).

Forked from [`rtl8192eu-linux`](https://github.com/clnhub/rtl8192eu-linux), branch `5.11.2.3`.

> ⚠️ **KERNEL MODULE.** Errors in build or install can break your network, crash the kernel or lose data. You run it at your own risk.

> 📌 **This is a personal fork.** Every default here was chosen for the one physical
> adapter described below (which has a **dead antenna B**). It is published as-is, not as a
> general-purpose driver. If you clone it, read [Full-capability tuning](#full-capability-tuning-healthy-2-antenna-adapter) first.

---

## My hardware (this repo's reference unit)

```
$ lsusb | grep 2357
Bus 001 Device 018: ID 2357:0126 TP-Link 802.11n NIC
```

| Item | Value |
|---|---|
| USB ID | `2357:0126` (vendor TP-Link `0x2357`, product `0x0126`) |
| Product | TL-WN8200ND(UN) **V3.0** (the bundled DVD is for V2.0) |
| Chipset | Realtek RTL8192EU, USB 2.0, 802.11n 2T2R (2.4 GHz only) |
| Interface name | `wn8200nd` (renamed from `wlanX`) |
| Physical defect | antenna B connector desoldered → driver forced to 1T1R |
| Host | ~2009 netbook, Intel Sandy Bridge, limited RAM |
| Target kernel | Debian 6.12.x |
| DKMS package | `rtl8192eu/1.6.2` |

The matching entry in the driver's USB ID table is
`driver/os_dep/linux/usb_intf.c:212`:

```c
{USB_DEVICE(0x2357, 0x0126), .driver_info = RTL8192E}, /* TPLINK - TL-WN8200ND */
```

Other IDs bound by this build (same `RTL8192E` block, lines 203–214): Realtek `0bda:818b`
and `0bda:818c` (default IDs), D-Link DWA-131 `2001:3312` / `2001:3319`,
PLANEX GW-300S `2019:ab33`, TP-Link TL-WN821N/822N/823N `2357:0107`/`0108`/`0109`,
Mercusys MW300UM/MW300UH `2c4e:0100`/`0104`.

Verify your own unit:

```bash
lsusb -d 2357:0126                 # present on the bus?
lsusb -v -d 2357:0126 | grep bcdDevice   # hardware revision
modinfo 8192eu | grep 2357p0126    # is the ID compiled into the loaded module?
dmesg | grep -i 8192eu             # bind + interface name
```

---

## What this fork changes

The defaults in this repo are tuned for **one specific adapter with broken hardware** (see below).
If you clone this repo, **your adapter may be fine** — read the tuning guide to restore full capability.

| Adjustment | Default in this repo | Why |
|---|---|---|
| `rtw_trx_path_bmp=0x11` (1T1R) | only antenna A | antenna B connector desoldered (physically dead) |
| `rtw_rxgain_offset_2g=0` | no LNA attenuation | antenna A signal weak (-73 dBm); attenuation made it worse |
| `rtw_bw_mode=0x20` | HT20 only | narrow channel with 1 antenna, weak signal |
| `-O2` build | standard optimization | smaller code, better cache on an old CPU |

### Full-capability tuning (healthy 2-antenna adapter)

If your TL-WN8200ND has both antennas working, change the following to restore 2T2R/HT40:

```bash
# /etc/modprobe.d/rtl8192eu.conf
options 8192eu rtw_trx_path_bmp=0x33 rtw_bw_mode=0x21 rtw_rxgain_offset_2g=4
```

Or edit the source directly:
- `driver/os_dep/linux/os_intfs.c:333` — `rtw_trx_path_bmp = 0x11` → `0x33`
- `driver/Makefile` — `ccflags-y += -O2` → `-O3` (optional)

Then reinstall (see below).

**The fork is named after this adapter, but works for any RTL8192EU-based adapter** (D-Link DWA-131 rev E1, Rosewill RNX-N180, etc.) with matching USB IDs.

---

## Adapter capacity vs this configuration

| Feature | Hardware supports | This repo (default) | How to enable |
|---|---|---|---|
| STA (Wi-Fi client) | yes | ✅ enabled | — |
| WPA2/WPA3 | yes | ✅ enabled | — |
| 2.4 GHz HT20/HT40 | yes | HT20 only | `rtw_bw_mode=0x21` |
| 2x2 MIMO | yes | 1T1R (antenna A) | `rtw_trx_path_bmp=0x33` |
| Monitor mode | yes | ❌ disabled by build | `CONFIG_WIFI_MONITOR=y` + rebuild |
| Monitor + packet injection (combined) | **no** | ❌ | not supported — see below |
| AP mode (softAP / hostapd) | yes | ✅ enabled since 1.6.2 | — |

## Monitor mode & pentesting

**This adapter can capture traffic (monitor mode), but it cannot do monitor + packet injection at the same time.** If you need to test a WiFi network (deauth, Mana, WPS brute), this is NOT the adapter for you. It is fine for:

- passive traffic analysis / packet capture
- channel scan / spectrum dump (aircrack-ng suite, tshark)

How to enable monitor mode (requires rebuild):

```bash
# 1. enable in driver/Makefile
sed -i 's/^CONFIG_WIFI_MONITOR = n$/CONFIG_WIFI_MONITOR = y/' driver/Makefile

# 2. rebuild + install
sudo ./install_manual.sh

# 3. use it
sudo ip link set wn8200nd down
sudo iw dev wn8200nd set type monitor
sudo ip link set wn8200nd up
```

The driver also exposes `/proc/net/rtl8192eu/<iface>/` debug interface even in client mode (RSSI, RX stats, adaptivity write) because `CONFIG_PROC_DEBUG=y` is on.

---

## Install / manage

Requires: kernel headers, build tools, dkms

```bash
sudo apt install -y linux-headers-$(uname -r) build-essential bc dkms
cd /path/to/rtl8192eu-wn8200nd-driver
sudo ./install_manual.sh          # non-interactive (DKMS)
# or
sudo ./wifi_manager.sh            # interactive TUI (install/update/remove)
```

`install_manual.sh` (v3):
1. Sync patched source to `/usr/src/rtl8192eu-1.6.2` + `dkms add` if missing
2. `dkms build` + `dkms install --force` (the `.ko.xz` in `updates/dkms/` wins)
3. Restart NetworkManager at the end

Check:

```bash
lsmod | grep 8192
cat /sys/module/8192eu/version     # 1.6.2
```

### Hardcoded params (source)

| Param | Default | Why |
|---|---|---|
| `rtw_en_napi` | 0 | NAPI off (USB stability) |
| `rtw_usb_rxagg_mode` | 0 | USB RX aggregation off (low latency) |
| `rtw_dynamic_agg_enable` | 0 | dynamic aggregation off |
| `rtw_enusbss` | 0 | USB autosuspend off |
| `MAX_CONTINUAL_IO_ERR` | 80 | tolerate USB error bursts (10→30→80) |
| `CONFIG_IPS_MODE` / `CONFIG_LPS_MODE` | 0 | no power saving |
| `CONFIG_TRAFFIC_PROTECT` | y | prioritizes ICMP/ARP (gaming) |
| `CONFIG_ICMP_VOQ` | y | ICMP priority for gaming |
| `rtw_antdiv_cfg` | 1 | antenna diversity (no effect on 8192E: HW always off) |

### Runtime EDCCA / RF params (`/etc/modprobe.d/8192eu.conf`)

| Param | This repo | Meaning |
|---|---|---|
| `rtw_adaptivity_th_l2h_ini` | 15 | EDCCA L2H threshold |
| `rtw_adaptivity_th_edcca_hl_diff` | 5 | EDCCA H-L difference |
| `rtw_rxgain_offset_2g` | 0 | LNA attenuation (0 = more) |
| `rtw_notch_filter` | 1 | notch filter on |
| `rtw_smart_ps` | 0 | power saving for realtek (no) |
| `rtw_bw_mode` | 0x20 | HT20 (0x21 = HT40) |

Note: writing to `/sys/module/8192eu/parameters/*` does **not** propagate to runtime
registry. Use `/proc/net/rtl8192eu/<iface>/odm/cmd` for live EDCCA tuning instead.

---

## Debug

```bash
echo "dbg 13 1" | sudo tee /proc/net/rtl8192eu/wn8200nd/odm/cmd   # EDCCA logs
sudo dmesg -w | grep -E 'ADPTVTY|th_l2h.*dBm'
```

`dbg 10` – show active debug components. `dbg 101` – disable all.

---

## Known bugs

See `docs/BUGS.md`. BUG-CRSH-002 = crash requiring modprobe cycle (mitigated, still can
surface on kernel `6.12.101`+ `set_monitor_channel` signature change — patched).

---

## Credits & lineage

The work in this repo is a fork of:

- [clnhub/rtl8192eu-linux](https://github.com/clnhub/rtl8192eu-linux) — upstream, branch `5.11.2.3`
- [Mange/rtl8192eu-linux-driver](https://github.com/Mange/rtl8192eu-linux-driver) — base original
- Realtek Semiconductor Corp. (GPLv2 driver source)
- TP-Link Technologies (hardware)

Not affiliated with TP-Link or Realtek. License: GPLv2 (`LICENSE`).