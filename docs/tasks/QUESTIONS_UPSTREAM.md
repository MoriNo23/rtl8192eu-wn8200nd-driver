# Questions for Upstream

Questions to ask Mange/clnhub about driver internals.

---

## Question 1: phydm_antdiv flow

**Status**: SUBMITTED - Issue #363
**Target**: Issue
**Link**: https://github.com/Mange/rtl8192eu-linux-driver/issues/363

**Question**:
How exactly does the antenna diversity algorithm work in `hal/phydm/phydm_antdiv.c`? 

Specifically:
- What triggers antenna switching? RSSI threshold? CRC error rate?
- How do `rtw_antdiv_cfg` and `rtw_antdiv_type` interact?
- For 2-antenna USB adapters like TL-WN8200ND, is there a recommended `antdiv_type` value?

**Context**:
Testing with TL-WN8200ND (RTL8192EU, 2x2 MIMO, 2 external antennas). Currently using `rtw_antdiv_cfg=1` with good results in crowded 2.4GHz, but unclear if `antdiv_type=0` (efuse auto) is optimal or if we should force a specific mode.

---

## Question 2: trx_path_bmp and MIMO

**Status**: PENDING
**Target**: Discussion

**Question**:
What's the relationship between `rtw_trx_path_bmp` and actual antenna usage?

I understand the bitmap format `[7:4]=TX, [0:3]=RX`, but:
- Does `0x33` mean both antennas always active for TX and RX?
- How does this interact with `phydm_antdiv` if both are set?
- Is there a performance/interference tradeoff for forcing paths vs letting firmware decide?

**Context**:
Setting `rtw_trx_path_bmp=0x33` improved stability for a 2-antenna USB adapter in a congested urban environment. Want to understand if this is safe long-term or if there are side effects.

---

## Question 3: TX power mapping

**Status**: SUBMITTED - Issue #362
**Target**: Issue
**Link**: https://github.com/Mange/rtl8192eu-linux-driver/issues/362

**Question**:
How does `rtw_TxBBSwing_2G` (0-255) map to actual TX power in dBm?

- Is this linear? 255 = max regulatory, 0 = min?
- Does this override regulatory limits or is it capped by firmware?
- Is there a way to read current TX power from sysfs/debugfs?

**Context**:
Trying to optimize for high-interference environment. Currently at 255 (default) but unsure if this is already at regulatory max or if there's headroom.

---

## Question 4: adaptivity thresholds

**Status**: PENDING
**Target**: Discussion

**Question**:
Can you explain `rtw_adaptivity_th_l2h_ini` and `rtw_adaptivity_th_edcca_hl_diff`?

The parameter descriptions exist but no docs on:
- What units are these values in?
- What's a typical range for crowded vs clean channels?
- How does `adaptivity_mode=1` (carrier sense) differ from mode 0?

**Context**:
Default values (0) seem to work but unclear if tuning them could help in dense WiFi deployments.

---

## Submitted Links

- [x] Issue #362: https://github.com/Mange/rtl8192eu-linux-driver/issues/362 (TX power mapping)
- [x] Issue #363: https://github.com/Mange/rtl8192eu-linux-driver/issues/363 (Antenna diversity)
- [ ] Pending: adaptivity thresholds question (wait for responses first)

---

## Answers Received

(To be filled when responses come in)

