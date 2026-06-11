# DARU_NOTES.md - TL-WN8200ND V3 Performance Audit & Optimization

**Audit performed by:** Daru  
**Date:** 2026-06-11  
**Base upstream:** clnhub/rtl8192eu-linux v5.11.2.3  
**Target branch:** optimization-wn8200nd  
**Hardware:** TP-Link TL-WN8200ND V3 (RTL8192EU, USB ID 2357:0126)  
**Use case:** 24/7 operation with continuous power (corriente permanente)

---

## Executive Summary

This audit analyzes the performance optimizations applied to the TL-WN8200ND V3 driver fork based on Realtek SDK v5.11.2.3. The target branch implements several critical stability and performance improvements for 24/7 operation, particularly for USB 2.0 systems like Sandy Bridge platforms.

### Key Findings

1. **4 existing patches verified correct** - URB leak fix, USB autosuspend disable, I/O error tolerance increase, and debug diagnostics
2. **6 parameters hardcoded for stability** - USB power saving features disabled for 24/7 reliability
3. **Windows 2025 driver analysis** - Binary-only, based on older SDK v2.0, no backport opportunities
4. **TxBBSwing_2G=255 confirmed safe** - Already maximum in upstream, no clamping detected
5. **1 improvement opportunity identified** - `rtw_smart_ps` should be 0 instead of 2 for 24/7 operation

---

## 1. Base Configuration Audit

### Upstream Base
- **Repository:** clnhub/rtl8192eu-linux
- **Branch:** 5.11.2.3
- **SDK Version:** v5.11.2.3
- **Commit:** Latest stable on branch

### Target Branch Analysis
- **Repository:** MoriNo23/TL-WN8200ND-driver
- **Branch:** optimization-wn8200nd
- **Total changes:** 129 files modified, 24,573 insertions, 356 deletions
- **Source code changes:** Focus on core driver files (C/H), plus binary drivers and documentation

---

## 2. Existing Patches Verification

### Patch 1: USB Autosuspend Disabled
**File:** `os_dep/linux/os_intfs.c`  
**Line:** 407-409  
**Change:** `rtw_enusbss` default changed from 1 to 0  
**Status:** ✅ VERIFIED CORRECT

```c
/* int rtw_enusbss = 1; */ /* 0:disable,1:enable (DESACTIVADO para estabilidad) */
int rtw_enusbss = 0; /* 0:disable,1:enable */
```

**Justification:** USB autosuspend causes micro-disconnections in 24/7 operation. Disabling ensures continuous power delivery to the RTL8192EU chip.

### Patch 2: I/O Error Tolerance Increased
**File:** `include/rtw_io.h`  
**Line:** 266  
**Change:** `MAX_CONTINUAL_IO_ERR` increased from 4 to 30  
**Status:** ✅ VERIFIED CORRECT

```c
#define MAX_CONTINUAL_IO_ERR 30  /* Aumentado de 10 a 30 para mayor tolerancia en USB 2.0 */
```

**Note:** The comment says "increased from 10 to 30" but upstream was actually 4. This is a 7.5x increase in tolerance, appropriate for USB 2.0's higher error rates.

### Patch 3: Driver Debug Diagnostics
**File:** `core/rtw_io.c`  
**Line:** 471  
**Change:** Added Spanish debug message when I/O error threshold reached  
**Status:** ✅ VERIFIED CORRECT

```c
RTW_INFO("=== DRIVER_DEBUG: Umbral de error I/O alcanzado. Posible micro-desconexión USB detectada. ===\n");
```

**Justification:** Provides clear diagnostic information in dmesg when USB connectivity issues occur.

### Patch 4: URB Leak Fix
**File:** `hal/rtl8192e/usb/rtl8192eu_xmit.c`  
**Function:** `rtl8192eu_hostap_mgnt_xmit_cb`  
**Change:** Added `usb_unanchor_urb()` and `usb_free_urb()` calls  
**Status:** ✅ VERIFIED CORRECT

**Upstream (buggy):**
```c
static void rtl8192eu_hostap_mgnt_xmit_cb(struct urb *urb)
{
#ifdef PLATFORM_LINUX
    struct sk_buff *skb = (struct sk_buff *)urb->context;
    rtw_skb_free(skb);  // URB never freed!
#endif
}
```

**Target (fixed):**
```c
static void rtl8192eu_hostap_mgnt_xmit_cb(struct urb *urb)
{
#ifdef PLATFORM_LINUX
    struct sk_buff *skb = (struct sk_buff *)urb->context;
    
    /* Des-anclar y liberar el URB (era un leak) */
    usb_unanchor_urb(urb);  // Properly unanchor before free
    usb_free_urb(urb);      // Fix the memory leak
    
    rtw_skb_free(skb);
#endif
}
```

**Justification:** Critical memory leak fix. Without this, HostAP mode would exhaust memory over time, causing crashes in 24/7 operation.

---

## 3. Performance Parameter Analysis

### Parameters Currently Hardcoded in Target

| Parameter | Upstream Default | Target Value | Status | Justification |
|-----------|-----------------|-------------|--------|---------------|
| `rtw_enusbss` | 1 | 0 | ✅ Optimal | USB autosuspend disabled for 24/7 stability |
| `rtw_low_power` | 0 | 0 | ✅ Optimal | Already disabled in upstream |
| `rtw_dynamic_agg_enable` | 1 | 0 | ✅ Optimal | Aggregation disabled for USB 2.0 stability |
| `rtw_en_napi` | 1 | 0 | ✅ Optimal | NAPI disabled for Sandy Bridge compatibility |
| `rtw_usb_rxagg_mode` | 2 | 0 | ✅ Optimal | USB RX aggregation disabled |

### Parameters Already Optimal in Upstream

| Parameter | Upstream Default | Target Value | Status | Justification |
|-----------|-----------------|-------------|--------|---------------|
| `rtw_TxBBSwing_2G` | 0xFF (255) | 0xFF (255) | ✅ Optimal | Maximum TX power swing for 2.4GHz |
| `rtw_TxBBSwing_5G` | 0xFF (255) | 0xFF (255) | ✅ Optimal | Maximum TX power swing for 5GHz (not used by 8192EU) |
| `rtw_btcoex_enable` | 2 (auto) | 2 (auto) | ✅ Optimal | BT coexistence auto-detection |
| `rtw_adaptivity_mode` | 0 (normal) | 0 (normal) | ✅ Optimal | Normal interference adaptation |
| `rtw_power_mgnt` | PS_MODE_ACTIVE (0) | PS_MODE_ACTIVE (0) | ✅ Optimal | Power management disabled |
| `rtw_ips_mode` | IPS_NONE | IPS_NONE | ✅ Optimal | IPS power saving disabled |
| `rtw_lps_level` | LPS_NORMAL | LPS_NORMAL | ✅ Optimal | Normal LPS level (not used when PS_MODE_ACTIVE) |

### Parameters Requiring Changes

| Parameter | Upstream Default | Target Value | Recommended | Justification |
|-----------|-----------------|-------------|-------------|---------------|
| `rtw_smart_ps` | 2 | 2 | **0** | Should be 0 for 24/7 operation to minimize power save transitions |

### Additional Parameters Considered

| Parameter | Upstream Default | File | Notes |
|-----------|-----------------|------|-------|
| `rtw_trx_path_bmp` | 0x00 (auto) | os_intfs.c:333 | Could force 0x33 for 2x2 MIMO, but auto is usually fine |
| `rtw_antdiv_cfg` | 2 (auto by efuse) | os_intfs.c:395 | Auto is optimal; efuse config knows best |
| `CONFIG_USB_AUTOSUSPEND` | n (disabled) | Makefile:62 | Already disabled in build config |

---

## 4. RF/BB Swing Analysis

### TxBBSwing_2G Investigation

**Finding:** The upstream already sets `rtw_TxBBSwing_2G = 0xFF` (255), which is the maximum value. The target maintains this value.

**Hardware Limit Check:** 
- Investigated RTL8192E RF power tracking code in `hal/phydm/halrf/rtl8192e/`
- Found that 0xFF is used as a default/sentinel value in some contexts
- Actual swing values are applied through power tracking calibration tables
- No hardware clamping detected that would reduce 255 silently

**Conclusion:** `rtw_TxBBSwing_2G=255` is safe and represents the intended maximum. The PHYDM layer handles actual power limiting through calibration, not through this module parameter.

---

## 5. Windows 2025 Driver Analysis

### Download Source
- **URL:** https://static.tp-link.com/upload/driver/2025/202507/20250704/TL-WN8200ND(UN)_V3_20250702_Win10_11.zip
- **Size:** 24.8 MB
- **Date:** 2025-07-02

### Archive Contents
```
TL-WN8200ND(UN)_V3_20250702_Win10_11/
├── Setup.exe (25.9 MB)
├── setup.iss
├── uninstall.iss
└── update.iss
```

### Analysis Results

**Finding:** The Windows driver is **binary-only** - no source code included.

**Strings Analysis:**
- Setup.exe contains references to RTL8192EU drivers
- Version strings indicate drivers for Windows XP, 7, 8, 8.1, and 10
- Internal references suggest SDK version 2.0 (older than Linux SDK v5.11.2.3)
- No C source code or configuration tables accessible

### Backport Opportunities

**Conclusion:** ❌ **NO BACKPORT OPPORTUNITIES**

**Reasons:**
1. Binary-only distribution - no source code to backport
2. Based on older SDK v2.0 vs Linux SDK v5.11.2.3
3. Linux driver is actually more recent than Windows driver
4. No configuration tables or register values accessible for extraction

**Recommendation:** Continue with current Linux SDK v5.11.2.3 base. Monitor Realtek for newer Linux SDK releases instead of trying to extract from Windows drivers.

---

## 6. Sandy Bridge USB 2.0 Specific Notes

### Hardware Context
- **CPU:** Intel i5-2430M (Sandy Bridge)
- **USB:** USB 2.0 only (480 Mbps max)
- **Implication:** Limited bandwidth compared to USB 3.0 (5 Gbps)

### Optimization Implications

1. **USB RX Aggregation Disabled (`rtw_usb_rxagg_mode=0`)**
   - **Rationale:** USB 2.0 has limited bandwidth; large aggregations can cause latency spikes
   - **Impact:** Reduced throughput but more consistent latency

2. **Dynamic Aggregation Disabled (`rtw_dynamic_agg_enable=0`)**
   - **Rationale:** Dynamic aggregation changes can cause micro-stalls on USB 2.0
   - **Impact:** More stable connection at cost of peak throughput

3. **NAPI Disabled (`rtw_en_napi=0`)**
   - **Rationale:** NAPI overhead may outweigh benefits on older hardware
   - **Impact:** Higher CPU usage but potentially more consistent performance

4. **I/O Error Tolerance Increased (`MAX_CONTINUAL_IO_ERR=30`)**
   - **Rationale:** USB 2.0 more prone to transient errors than USB 3.0
   - **Impact:** Driver more forgiving of USB hiccups, less likely to disconnect

### Recommendations

The current optimization settings are **appropriate for Sandy Bridge USB 2.0**. The trade-offs (lower peak throughput for higher stability) are correct for 24/7 operation on this hardware.

---

## 7. Compilation & Testing Notes

### Build Environment
- **Target OS:** Debian Trixie
- **Kernel:** ~6.x
- **Required packages:** build-essential, linux-headers-$(uname -r)

### Build Commands
```bash
cd target
make clean
make
```

### Module Installation
```bash
sudo rmmod 8192eu 2>/dev/null || true
sudo insmod 8192eu.ko
```

### Parameter Verification
```bash
for param in rtw_enusbss rtw_low_power rtw_smart_ps rtw_en_napi rtw_usb_rxagg_mode rtw_dynamic_agg_enable; do
  echo "$param: $(cat /sys/module/8192eu/parameters/$param 2>/dev/null || echo 'N/A')"
done
```

### Expected Values
- `rtw_enusbss`: 0
- `rtw_low_power`: 0
- `rtw_smart_ps`: 2 (should be 0 in future)
- `rtw_en_napi`: 0
- `rtw_usb_rxagg_mode`: 0
- `rtw_dynamic_agg_enable`: 0

---

## 8. Stress Testing Recommendations

### Test Environment
- **Duration:** Minimum 30 minutes, ideally 24+ hours
- **Monitoring:** Continuous dmesg monitoring for DRIVER_DEBUG messages

### Test Commands

**Terminal 1 - Monitor:**
```bash
sudo dmesg -w | grep -E "DRIVER_DEBUG|surprise|8192eu|error|continual_io_error"
```

**Terminal 2 - Download Stress:**
```bash
while true; do
  wget -q -O /dev/null http://speedtest.tele2.net/100MB.zip && echo "OK $(date)"
done
```

**Terminal 3 - Error Count:**
```bash
watch -n 5 'dmesg | grep -c "continual_io_error"'
```

### Success Criteria
- ✅ No DRIVER_DEBUG messages during normal operation
- ✅ No "surprise_removed" messages
- ✅ Stable throughput (measure with iftop/nethogs)
- ✅ No disconnections or driver reloads
- ✅ continual_io_error count stable or decreasing

---

## 9. Recommended Improvements

### Immediate Changes (PR Candidate)

1. **Set `rtw_smart_ps = 0`**
   - **File:** `os_dep/linux/os_intfs.c:126`
   - **Change:** `int rtw_smart_ps = 0;`
   - **Justification:** Value 0 disables smart power save completely, optimal for 24/7 operation with continuous power

### Future Considerations

1. **Investigate `rtw_trx_path_bmp = 0x33`**
   - **Potential:** Force 2x2 MIMO instead of auto-detection
   - **Risk:** May cause issues if hardware has antenna limitations
   - **Recommendation:** Test on actual hardware before implementing

2. **Monitor for SDK Updates**
   - Realtek may release newer SDK versions
   - Current v5.11.2.3 is from 2019
   - Newer SDKs may have USB 3.0 optimizations that could be backported

3. **Consider Runtime Parameter Configuration**
   - Current approach hardcodes optimal values
   - Alternative: Keep module_param but set optimal defaults
   - **Trade-off:** Hardcoding prevents user error but reduces flexibility

---

## 10. Conclusion

### Audit Summary

The `optimization-wn8200nd` branch implements **solid, well-reasoned optimizations** for 24/7 operation of the TL-WN8200ND V3 on Sandy Bridge USB 2.0 systems. All 4 documented patches are correct and address real stability issues:

1. ✅ **USB autosuspend disabled** - Prevents micro-disconnections
2. ✅ **I/O error tolerance increased** - Accommodates USB 2.0 characteristics  
3. ✅ **Debug diagnostics added** - Aids troubleshooting
4. ✅ **URB leak fixed** - Critical memory leak in HostAP mode

The parameter hardcoding decisions are appropriate for the target use case (24/7 with continuous power), with one improvement opportunity identified (`rtw_smart_ps` should be 0).

### Windows Driver Analysis

The Windows 2025 driver provides **no backport opportunities** due to:
- Binary-only distribution (no source code)
- Based on older SDK v2.0 (older than Linux SDK v5.11.2.3)
- No accessible configuration tables or register values

### Recommendation

**Proceed with current optimization-wn8200nd branch** with the following addition:
- Set `rtw_smart_ps = 0` for complete power save disable

The current optimizations are well-suited for Sandy Bridge USB 2.0 hardware and 24/7 operation scenarios. No changes needed for RF/BB swing configuration as upstream already uses maximum values.

---

## Appendix A: File Changes Summary

### Source Code Changes (C/H)

1. **core/rtw_io.c** - Added DRIVER_DEBUG message
2. **core/efuse/rtw_efuse.c** - Minor formatting fix
3. **core/rtw_br_ext.c** - Kernel 7.1 compatibility changes
4. **core/rtw_mlme.c** - Minor code formatting
5. **core/rtw_mp.c** - Delay function changes
6. **core/rtw_recv.c** - Minor code formatting
7. **core/rtw_sta_mgt.c** - Memory management fix
8. **core/rtw_xmit.c** - Minor code formatting
9. **hal/rtl8192e/rtl8192e_hal_init.c** - Minor changes
10. **hal/rtl8192e/usb/rtl8192eu_xmit.c** - **URB leak fix**
11. **hal/rtl8192e/usb/usb_halinit.c** - Minor changes
12. **hal/phydm/** - Multiple minor changes across PHYDM layer
13. **include/rtw_io.h** - **MAX_CONTINUAL_IO_ERR increased**
14. **include/rtw_recv.h** - Minor changes
15. **include/usb_ops.h** - Minor changes
16. **os_dep/linux/ioctl_cfg80211.c** - Minor changes
17. **os_dep/linux/ioctl_mp.c** - Minor changes
18. **os_dep/linux/os_intfs.c** - **Parameter hardcoding (rtw_enusbss, etc.)**
19. **os_dep/linux/recv_linux.c** - Minor changes
20. **os_dep/linux/usb_ops_linux.c** - Minor changes

### Binary/Documentation Changes

- Added Windows drivers (Win10/11)
- Added macOS driver (already present)
- Added GitHub Actions workflow
- Updated README.md with comprehensive optimization guide
- Added DRIVER_BIBLE.md documentation
- Added build/test scripts

---

**Audit completed by Daru on 2026-06-11**  
**Next steps:** Implement `rtw_smart_ps=0` change and proceed with stress testing on actual hardware.