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
| DKMS package | `rtl8192eu/1.8.0` |

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
| `rtw_bw_mode=0x21` | HT40 configured (2.4 GHz) | matches the source default — but **configured is not negotiated**: 40 MHz only happens if the AP announces it *and* sits on a valid HT40 primary channel |
| `rtw_usb_rxagg_mode=1` | RX aggregation in DMA mode with a driver-defined threshold | the previous default `0` never disabled anything (see below) |
| `CONFIG_RTW_GRO=y`, `rtw_en_napi=1` | coalesced frame delivery | largest CPU and throughput win; the reason they were off was based on a false premise |
| `CONFIG_RTW_DEBUG=n`, `CONFIG_PROC_DEBUG=n` | **no runtime logging, no procfs** | 2 908 of 3 929 kernel lines were the driver's own. Debug output is compiled in but **unreachable**: no procfs, no module parameter, no ioctl |
| `CONFIG_TXPWR_LIMIT_EN=y` | driver computes the regulatory power limit | previously emitted `lmt`/`ulmt = NA` |
| `-O2` build | standard optimization | smaller code, better cache on an old CPU |

### Two defaults that never did what their names said

**`rtw_usb_rxagg_mode=0` did not disable aggregation.** `usb_halinit.c:115-116`
replaces any value that is neither `RX_AGG_DMA` (1) nor `RX_AGG_USB` (2) with
`RX_AGG_DMA`, and then (lines 123-125) assigns the driver threshold. So `0` and `1`
produced a **bit-identical** state, and the disable mode is unreachable through
this parameter. The default is now `1` — same behaviour, honest value. Two
stability patches were justified in comments by "with `rtw_usb_rxagg_mode=0` there
is no buffering"; that premise was false, and the comments have been corrected. The
thresholds themselves are kept (see `AGENTS.md`).

**`rtw_bw_mode=0x21` configures HT40 but does not get you HT40.** Bandwidth is
negotiated, not commanded: the link stays at 20 MHz unless the AP announces 40 MHz
*and* is on a valid HT40 primary channel. On this deployment the AP is on **channel
3**, which is not a valid 40 MHz primary in 2.4 GHz, so the link is 20 MHz no matter
what this parameter says. Check the real width with `iw dev wn8200nd info`, not with
the modprobe file.

### Full-capability tuning (healthy 2-antenna adapter)

If your TL-WN8200ND has both antennas working, change the following to restore 2T2R/HT40:

```bash
# /etc/modprobe.d/rtl8192eu.conf
options 8192eu rtw_trx_path_bmp=0x33 rtw_bw_mode=0x21 rtw_rxgain_offset_2g=4
```

Or edit the source directly:
- `driver/os_dep/linux/os_intfs.c` — `rtw_trx_path_bmp = 0x11` → `0x33`
- `driver/Makefile` — `ccflags-y += -O2` → `-O3` (optional)

With a healthy adapter you may also want to re-enable 2x2 antenna diversity and
`rtw_antdiv_cfg=0` (currently forced to 1), and check `rtw_hiq_filter`: it is a
sensitivity trade-off, documented with its alternatives in
[`docs/RF-SENSITIVITY.md`](docs/RF-SENSITIVITY.md).

Then reinstall (see below).

**The fork is named after this adapter, but works for any RTL8192EU-based adapter** (D-Link DWA-131 rev E1, Rosewill RNX-N180, etc.) with matching USB IDs.

---

## Adapter capacity vs this configuration

| Feature | Hardware supports | This repo (default) | How to enable |
|---|---|---|---|
| STA (Wi-Fi client) | yes | ✅ enabled | — |
| WPA2/WPA3 | yes | ✅ enabled | — |
| 2.4 GHz HT20/HT40 | yes | HT40 configured (`0x21`); actual width is **20 MHz** on a channel 3 AP | `rtw_bw_mode=0x20` forces HT20 |
| 2x2 MIMO | yes | 1T1R (antenna A) | `rtw_trx_path_bmp=0x33` |
| Monitor mode | yes | ✅ enabled since 1.7.0 | — |
| Packet injection (monitor) | yes | ⚠️ radiotap fix in 1.7.0, on-air test pending | test: `aireplay-ng -9 <mon>` |
| AP mode (softAP / hostapd) | yes | ✅ enabled since 1.6.2 | — |

## Monitor mode & pentesting

**Monitor mode is enabled by default since 1.7.0, and the injection path was fixed (it used to reject every radiotap header whose length was not exactly 12 bytes — aircrack-ng/hcxdumptool emit different lengths, which silently killed all injection). On-air validation with `aireplay-ng -9` is still pending.** It is good for:

- passive traffic analysis / packet capture
- channel scan / spectrum dump (aircrack-ng suite, tshark)

How to use monitor mode:

```bash
# 1. switch interface to monitor
sudo ip link set wn8200nd down
sudo iw dev wn8200nd set type monitor
sudo ip link set wn8200nd up

# 2. test injection
sudo aireplay-ng -9 wn8200nd
```

Since 1.8.0 the driver exposes **no** `/proc/net/rtl8192eu/` tree: `CONFIG_PROC_DEBUG=n`.
That also removes the only way to turn on the PHY debug bitmask at runtime, so
there is no runtime debug surface at all — no procfs, no module parameter, no ioctl.
For live signal and rate use `wn8200nd-antenna --once` or `iw dev wn8200nd station dump`.
See [`docs/USB-LINK-HANG.md`](docs/USB-LINK-HANG.md) for diagnosing a dead link
without driver logging.

---

## Install / manage

Requires: kernel headers, build tools, dkms, rsync

```bash
sudo apt install -y linux-headers-$(uname -r) build-essential bc dkms rsync
cd /path/to/rtl8192eu-wn8200nd-driver

make -C driver clean && make -j"$(nproc)" -C driver all   # compilar
sudo ./install_manual.sh                                  # instalar/actualizar (único script)
```

### Verification lives in CI, not on your machine

Do **not** compile or run static analysis locally to check a change — push and let
GitHub Actions decide. The workflow compiles against two kernel families (the
runner's Ubuntu headers for forward compatibility, and Debian 6.12 headers in a
container, which is the actual deployment target) and runs sparse, smatch and
checkpatch against a versioned baseline.

`make` above is for **deploying**, not for verifying: it is the step that installs
the module. Verification is the CI run, and it should be green before you install.

`install_manual.sh` (v4) hace todo:
1. Sincroniza el source parcheado a `/usr/src/rtl8192eu-<VER>` + `dkms add` si falta
2. `dkms build` + `dkms install --force` (el `.ko.xz` de `updates/dkms/` tiene prioridad) + `depmod`
3. Instala `scripts/reload-wn8200nd-1ant` en `~/.local/bin/` del usuario que invoca sudo
4. Recarga el módulo y reinicia NetworkManager (no reconecta solo tras recarga)

### Actualizar a mano (equivalente a lo que hace install_manual.sh)

Si prefieres hacerlo paso a paso — por ejemplo tras un `git pull`:

```bash
VER=$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' dkms.conf)   # ej: 1.8.0

# 1. Source parcheado a /usr/src (siempre fresco, nunca una copia olvidada)
sudo mkdir -p /usr/src/rtl8192eu-$VER
sudo rsync -a --delete \
  --exclude '.git' --exclude '*.o' --exclude '*.ko' --exclude '*.cmd' \
  --exclude '*.mod*' --exclude '.tmp_versions' \
  --exclude 'Module.symvers' --exclude 'modules.order' \
  ./ /usr/src/rtl8192eu-$VER/

# 2. Registrar, compilar e instalar (depmod corre dentro; repetirlo no daña)
sudo dkms add      -m rtl8192eu -v $VER    # solo si dkms status no lo lista
sudo dkms build    -m rtl8192eu -v $VER    # si decía "already built, skip" tras cambiar source:
                                           #   sudo dkms remove -m rtl8192eu -v $VER  primero
sudo dkms install  -m rtl8192eu -v $VER --force
sudo depmod -a "$(uname -r)"

# 3. Cargar y verificar
sudo modprobe 8192eu
cat /sys/module/8192eu/version            # debe decir $VER
strings /lib/modules/$(uname -r)/updates/dkms/8192eu.ko.xz | grep srcversion
```

⚠️ Si actualizas el source sin subir `PACKAGE_VERSION`, `dkms build` reutiliza la
compilación anterior ("already built, skip") aunque uses `install --force`.
Fuerza con: `sudo dkms remove -m rtl8192eu -v $VER` antes del build.

### Recarga rápida (sin reinstalar)

```bash
~/.local/bin/reload-wn8200nd-1ant     # lo instala install_manual.sh
```

Check:

```bash
lsmod | grep 8192
cat /sys/module/8192eu/version
```

### Hardcoded params (source)

| Param | Default | Why |
|---|---|---|
| `rtw_en_napi` | 0 | NAPI off **in the source**; the deployment turns it on via `8192eu.conf` |
| `rtw_en_gro` | 1 | coalesced frame delivery (1.8.0; was 0). Only effective with NAPI: the driver zeroes `en_gro` when `en_napi==0` |
| `rtw_usb_rxagg_mode` | 1 | RX_AGG_DMA with a driver-defined threshold (1.8.0; was 0). Any value other than 1 or 2 is silently replaced by DMA, and the disable mode is unreachable |
| `rtw_dynamic_agg_enable` | 0 | dynamic **TX** aggregation off |
| `rtw_enusbss` | 0 | USB autosuspend off |
| `MAX_CONTINUAL_IO_ERR` | 80 | tolerate the radio silence of a channel switch (10→30→80). Chosen by the *time window*, not by any buffering theory |
| `MAX_USB_STALL_ERR` | 200 | own counter for `-EPIPE`/`-EPROTO`, so a permanently halted endpoint eventually escalates |
| `CONFIG_IPS_MODE` / `CONFIG_LPS_MODE` | 0 | no power saving |
| `CONFIG_TRAFFIC_PROTECT` | y | prioritizes ICMP/ARP (gaming) |
| `CONFIG_ICMP_VOQ` | y | ICMP priority for gaming |
| `rtw_antdiv_cfg` | 1 | antenna diversity (no effect on 8192E: HW always off) |
| `rtw_bw_mode` | 0x21 | HT40 *configured* in 2.4 GHz; the negotiated width depends on the AP's channel and announcement |
| `DBG` (autoconf.h) | 1 | kept on purpose: `phydm_debug.c` is entirely inside `#if DBG`, and `DBG 0` would empty the object and break linking |

### Runtime EDCCA / RF params (`/etc/modprobe.d/8192eu.conf`)

| Param | This repo | Meaning |
|---|---|---|
| `rtw_adaptivity_th_l2h_ini` | 15 | EDCCA L2H threshold |
| `rtw_adaptivity_th_edcca_hl_diff` | 5 | EDCCA H-L difference |
| `rtw_rxgain_offset_2g` | 0 | LNA attenuation (0 = more) |
| `rtw_notch_filter` | 1 | notch filter on |
| `rtw_smart_ps` | 0 | power saving for realtek (no) |
| `rtw_bw_mode` | **0x21** | HT40 configured in 2.4 GHz (0x20 = HT20 only). Check the real width with `iw dev wn8200nd info` |
| `rtw_usb_rxagg_mode` | 1 | RX aggregation, DMA mode with driver threshold |
| `rtw_en_napi` | 1 | coalesced frame delivery |
| `rtw_en_gro` | (default 1) | GRO on; only effective when NAPI is on |

Note: writing to `/sys/module/8192eu/parameters/*` does **not** propagate to the
runtime registry — the `module_param` is copied into `registry_priv` only at module
init. Edit `/etc/modprobe.d/8192eu.conf` and reload the module instead.

---

## Debugging

There is **no runtime debug surface** since 1.8.0. `CONFIG_RTW_DEBUG=n` means no
driver log lines, and `CONFIG_PROC_DEBUG=n` means no `/proc/net/rtl8192eu/` — which
was the only writer of the PHY debug bitmask. The debug code is still compiled in
(it must be, see `DBG` above) but there is no way to reach it: no procfs, no module
parameter, no ioctl, no vendor command.

What to use instead:

| Question | Answer |
|---|---|
| Is the link dead because of USB hardware or the driver? | [`docs/USB-LINK-HANG.md`](docs/USB-LINK-HANG.md) |
| Does the driver even build and link? | the CI assertions (`build`, `build-debian`, `config-assertions`) |
| Did the module load? | `lsmod \| grep 8192eu`, `dmesg \| grep -i 8192eu` (core messages, not driver ones) |
| Signal, rate, negotiated width | `wn8200nd-antenna --once`, `iw dev wn8200nd info` |
| Which parameters affect RX sensitivity? | [`docs/RF-SENSITIVITY.md`](docs/RF-SENSIVITY.md) |

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