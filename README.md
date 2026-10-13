# rtl8192eu-wn8200nd-driver

Linux driver for the **TP-Link TL-WN8200ND V2/V3** USB WiFi adapter (Realtek **RTL8192EU**, 802.11n 2.4 GHz) on Debian/Ubuntu, kernel 6.x (tested on 6.12).

Personal fork of [clnhub/rtl8192eu-linux](https://github.com/clnhub/rtl8192eu-linux) (branch `5.11.2.3`), maintained for one reference unit: a TL-WN8200ND **V3** with a dead antenna B (forced 1T1R) and a high-gain cantenna on antenna A. It works on any RTL8192EU adapter — if yours is healthy, see [Tuning](#tuning-other-adapters).

> **Kernel module.** Build or install mistakes can take your network down. Use at your own risk.

## Highlights

| | |
|---|---|
| **Daytime collapse fixed (1.9.0)** | RX A-MPDU window capped 64 → 16 subframes: kills head-of-line blocking under neighbor congestion. Full case study: [`docs/DAYTIME.md`](docs/DAYTIME.md) |
| **Throughput (1.8.0)** | NAPI + GRO + RX DMA aggregation: 13 → 25 Mbps on the reference host |
| **Monitor mode (1.7.0)** | Enabled by default; radiotap length fix for aircrack-ng / hcxdumptool injection |
| **Silent runtime (1.8.0)** | No driver log spam, no procfs surface |

## Install

```bash
sudo apt install -y linux-headers-$(uname -r) build-essential bc dkms rsync
make -C driver clean && make -j"$(nproc)" -C driver all
sudo ./install_manual.sh    # DKMS add/build/install + module reload + NM restart
```

Verify: `cat /sys/module/8192eu/version` → should print the DKMS version (currently `1.9.0`).
Quick reload without reinstalling: `~/.local/bin/reload-wn8200nd-1ant` (installed by the script).

## Tuning (other adapters)

Defaults are conservative for the reference unit (1T1R, no RX gain offset). A healthy 2-antenna unit wants:

```bash
# /etc/modprobe.d/8192eu.conf
options 8192eu rtw_trx_path_bmp=0x33 rtw_rxgain_offset_2g=4 rtw_bw_mode=0x21
```

HT40 is *negotiated*, not commanded: the AP must announce 40 MHz on a valid primary channel. Check the real width with `iw dev wn8200nd info`.

## Documentation

| Doc | Content |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Engineering log: every default and why, CHANGELOG, invariants, DKMS & CI procedures |
| [`docs/DAYTIME.md`](docs/DAYTIME.md) | Case study: daytime congestion collapse — root cause (RX A-MPDU head-of-line), fix, RF geometry notes |
| [`docs/RF-SENSITIVITY.md`](docs/RF-SENSITIVITY.md) | RX sensitivity parameters |
| [`docs/THROUGHPUT.md`](docs/THROUGHPUT.md) | Throughput tuning history |
| [`docs/USB-LINK-HANG.md`](docs/USB-LINK-HANG.md) | Diagnosing dead links without runtime debug |
| [`docs/BUGS.md`](docs/BUGS.md) | Known bugs (`BUG-TXPOWER-001` blocks `CONFIG_TXPWR_LIMIT`) |
| `openspec/` | Change management: specs and validated changes |

## Credits & lineage

- [clnhub/rtl8192eu-linux](https://github.com/clnhub/rtl8192eu-linux) — upstream
- [Mange/rtl8192eu-linux-driver](https://github.com/Mange/rtl8192eu-linux-driver) — original base
- Realtek Semiconductor (GPLv2 driver source) · TP-Link Technologies (hardware)

Not affiliated with TP-Link or Realtek. License: **GPLv2** (`LICENSE`).
