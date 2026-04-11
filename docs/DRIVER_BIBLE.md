# RTL8192EU Driver Bible

> Reference document for understanding and modifying this driver. Work in progress.

## Quick Stats
- **Total files**: 346 (.c + .h)
- **C source files**: 74
- **Key directories**: `core/`, `hal/`, `os_dep/`, `include/`
- **Target hardware**: RTL8192EU USB WiFi chip (TP-Link TL-WN8200ND, D-Link DWA-131 Rev E, etc.)

---

## Directory Structure

```
├── core/           (34MB) - WiFi protocol implementation
│   ├── rtw_mlme.c      - MLME (Management Layer) - connection handling
│   ├── rtw_xmit.c      - Transmission (6367 lines)
│   ├── rtw_recv.c      - Reception (4950 lines)
│   ├── rtw_ap.c        - Access Point mode
│   ├── rtw_pwrctrl.c   - Power management
│   ├── rtw_btcoex.c    - Bluetooth coexistence
│   ├── crypto/         - Encryption (AES, CCMP, GCMP)
│   ├── mesh/           - 802.11s mesh networking
│   └── monitor/        - Monitor mode (radiotap)
│
├── hal/             (37MB) - Hardware Abstraction Layer
│   ├── rtl8192e/       - Chip-specific code (RTL8192E series)
│   │   └── usb/        - USB interface for RTL8192EU
│   ├── phydm/          - PHY Digital Modulation (physical layer)
│   │   ├── phydm_antdiv.c    - Antenna diversity
│   │   ├── phydm_adaptivity.c - DFS/adaptive channel
│   │   ├── phydm_dig.c       - Digital Initial Gain
│   │   └── halrf/            - RF (Radio Frequency) control
│   ├── btc/            - Bluetooth coexistence
│   └── led/            - LED control
│
├── os_dep/          (15MB) - OS-dependent code
│   └── linux/
│       ├── os_intfs.c      - Module entry point, parameters (5745 lines)
│       ├── usb_intf.c      - USB device registration
│       ├── ioctl_cfg80211.c - Linux wireless API
│       └── mlme_linux.c    - Linux MLME hooks
│
├── include/         (3.1MB) - Headers
│   ├── osdep_service.h     - OS abstraction
│   ├── drv_types.h         - Driver types
│   └── wifi.h              - WiFi constants
│
└── platform/        - Platform-specific hooks
```

---

## Key Files for Optimization

### Module Parameters (`os_dep/linux/os_intfs.c`)

Location: Lines 300-750 approximately

| Parameter | Default | Description |
|-----------|---------|-------------|
| `rtw_antdiv_cfg` | 2 (was) -> **1** | Antenna diversity: 0=OFF, 1=ON, 2=Efuse |
| `rtw_trx_path_bmp` | 0 (was) -> **0x33** | TX/RX path bitmap [7:4]=TX, [0:3]=RX |
| `rtw_tx_pwr_by_rate` | CONFIG | Power control by rate |
| `rtw_TxBBSwing_2G` | 0xFF | 2.4GHz TX power swing (0-255) |
| `rtw_adaptivity_en` | 1 | DFS adaptivity enable |
| `rtw_adaptivity_mode` | 1 | 0=normal, 1=carrier sense |
| `rtw_notch_filter` | 0 | Notch filter for interference |
| `rtw_power_mgnt` | 0 | Power save: 0=OFF, 1-2=levels |
| `rtw_ips_mode` | 0 | Idle power save |
| `rtw_lps_level` | 0 | Link power save |

### PHY/RF Control (`hal/phydm/`)

Key files:
- `phydm_antdiv.c` - Antenna diversity algorithm
- `phydm_adaptivity.c` - Channel adaptivity (DFS)
- `phydm_dig.c` - Dynamic Initial Gain (sensitivity)
- `halrf/` - RF power tracking, calibration

### Transmission (`core/rtw_xmit.c`)

- 6367 lines
- Handles packet queuing, aggregation (AMPDU/AMSDU)
- Key functions: `rtw_xmit_entry()`, `rtw_xmit_classifier()`

### Reception (`core/rtw_recv.c`)

- 4950 lines
- Handles packet receiving, reordering
- Key functions: `rtw_recv_entry()`, `rtw_reorder_ctrl()`

### Connection Management (`core/rtw_mlme.c`)

- 5905 lines
- Handles association, authentication, roaming
- Key functions: `rtw_join_cmd_hdl()`, `rtw_select_roaming_candidate()`

---

## Parameter Categories

### Power Management
```
rtw_power_mgnt=0    # 0=off, 1=min, 2=max power save
rtw_ips_mode=0      # Idle power save (0=off)
rtw_lps_level=0     # Link power save (0=off)
rtw_smart_ps=2      # Smart power save
```

### Antenna & MIMO
```
rtw_antdiv_cfg=1           # Antenna diversity ON
rtw_trx_path_bmp=0x33      # Force 2x2 (TX path A+B, RX path A+B)
rtw_tx_path_lmt=0          # TX path limit (0=auto)
rtw_rx_path_lmt=0          # RX path limit (0=auto)
rtw_tx_nss=0               # TX spatial streams (0=auto)
rtw_rx_nss=0               # RX spatial streams (0=auto)
```

### Interference & Channel
```
rtw_adaptivity_en=1        # Enable channel adaptivity
rtw_adaptivity_mode=1      # Carrier sense mode
rtw_notch_filter=0         # Notch filter (0=off, 1=on, 2=P2P only)
```

### TX Power
```
rtw_TxBBSwing_2G=255       # 2.4GHz TX swing (0-255, 255=max)
rtw_TxBBSwing_5G=255       # 5GHz TX swing
rtw_tx_pwr_by_rate=2       # Power by rate: 0=off, 1=on, 2=efuse
```

### Aggregation (Performance)
```
rtw_ampdu_enable=1         # AMPDU aggregation
rtw_rx_ampdu_amsdu=0       # RX A-MSDU in A-MPDU
rtw_tx_ampdu_amsdu=2       # TX A-MSDU in A-MPDU
```

---

## Unknowns / TODO

### Questions for upstream (Mange/clnhub)

1. **phydm structure** - How do `phydm_antdiv.c` and `phydm_dig.c` interact exactly?
2. **EFuse mapping** - Where is the antenna config stored and how to read it?
3. **TX power limits** - How does `rtw_TxBBSwing` map to actual dBm?
4. **Channel adaptivity** - What does `th_l2h_ini` threshold actually control?

### Needs Investigation

- `hal/rtl8192e/` - Chip-specific registers
- `hal/phydm/halrf/` - RF calibration flow
- Power tracking tables in `halrf_powertracking.c`

---

## Related Hardware

- RTL8192EU - USB 2.0, 2x2 MIMO, 802.11n 300Mbps
- Used in: TP-Link TL-WN8200ND (V2/V3), D-Link DWA-131 Rev E, Rosewill RNX-N180UBE v2

---

## Build Commands

```bash
make clean
make
sudo make install
sudo modprobe 8192eu

# With custom parameters
sudo modprobe 8192eu rtw_antdiv_cfg=1 rtw_trx_path_bmp=0x33
```

---

## Kernel Compatibility

- Tested: Kernel 5.x - 6.x
- Breaks: Kernel < 5.0 (needs patches for older APIs)
- Monitor mode: Set `CONFIG_WIFI_MONITOR = y` in Makefile
