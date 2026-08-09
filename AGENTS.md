# rtl8192eu-linux — TL-WN8200ND Driver

## Versionado (DKMS pkg rtl8192eu)

La versión del paquete DKMS (`VER` en install_manual.sh, hoy `1.6.1`) ES el versionado del fork.
Bump semver: MAJOR.MINOR.PATCH — patch para fixes de build/compat, minor para cambios de
comportamiento/optimizaciones, major para cambios estructurales. Bump → renombrar
`/usr/src/rtl8192eu-<old>` → `/usr/src/rtl8192eu-<new>` + `dkms remove/add/build/install --force`.

### CHANGELOG
| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.6.1 | 2026-08-08 | fix set_monitor_channel kernel 6.12.101+ (netdev arg, backport Debian de 6.13); -O2, rxgain 4→0, HT20 (6324f01, c312b04) |
| 1.6 | 2026-07-30 | duplicado: baseline del fork original rtl8192eu (rama 5.11.2.3) + parches 1T1R/EDCCA/EPIPE/MAX_IO_ERR |

## Repo
- Remote: `MoriNo23/TL-WN8200ND-driver` (privado)
- Branch: `optimization-wn8200nd` (única, default)
- Fork del repo original `rtl8192eu-linux`, rama `5.11.2.3`
- Adaptador: TL-WN8200ND(UN) V3.0 (chipset RTL8192EU) — DVD oficial es V2.0

## Arquitectura
Sistema target: netbook ~2009, Intel Sandy Bridge, RAM limitada.
Driver WiFi USB: TL-WN8200ND(UN) V3.0 (RTL8192EU). DVD oficial V2.0.

## Build Flags Especiales (driver/Makefile)
| Flag | Valor | Razón |
|------|-------|-------|
| `-O2` | habilitado | Estándar Realtek, código más chico (mejor caché en CPU vieja). Antes -O3 (2026-08-08) |
| `CONFIG_RTW_DEBUG` | y | Logs debug activos (dmesg) |
| `CONFIG_PROC_DEBUG` | y | /proc/net/rtl8192eu/ interfaces |
| `CONFIG_RTW_NAPI_DYNAMIC` | sí | Desactiva NAPI en bajo throughput (<100 Mbps) |
| `CONFIG_RTW_GRO` | n | Desactivado para reducir latencia |
| `CONFIG_AP_MODE` | n | No usado |
| `CONFIG_P2P` | n | No usado |
| `CONFIG_MP_INCLUDED` | n | No usado |
| `CONFIG_BT_COEXIST` | n | BT no usado |
| `CONFIG_IPS_MODE` | 0 | Sin ahorro energía |
| `CONFIG_LPS_MODE` | 0 | Sin ahorro energía |
| `CONFIG_ICMP_VOQ` | y | Prioriza ICMP para gaming |
| `CONFIG_IP_R_MONITOR` | y | Prioriza ARP/high rate |
| `CONFIG_RTW_ADAPTIVITY_EN` | enable | EDCCA adaptivity activo |
| `CONFIG_RTW_ADAPTIVITY_MODE` | carrier_sense | Modo carrier sense |

## Parámetros hardcodeados (source)
- `rtw_en_napi = 0` — NAPI desactivado (estabilidad USB)
- `rtw_usb_rxagg_mode = 0` — agreación USB desactivada
- `rtw_dynamic_agg_enable = 0` — agregación dinámica desactivada

## MIMO
- `rtw_trx_path_bmp=0x11` — **1T1R forzado (solo antena A/path 0)** — ver parche abajo
- `rtw_antdiv_cfg=1` — antenna diversity forzada

### ⚠️ Parche 1T1R (2026-07-30) — conector antena B desoldado
El conector físico de la antena B (path RF 1) está desoldado (hardware roto, confirmado
desarmando el adaptador). Con 2x2 (0x33) el driver dependía de la path muerta: RSSI
arrastrado (-72/-84 dBm), rate RX clavado en CCK_1M, stalls de ping recurrentes.

Cambios aplicados:
1. **Source** — `driver/os_dep/linux/os_intfs.c:333`: default `0x33` → `0x11`
   (TX path 4 + RX path 0 = solo antena A). srcversion: `A0A33550E9968D9FA55C846`.
2. **Conf** — `/etc/modprobe.d/rtl8192eu.conf`: `rtw_trx_path_bmp=0x11` (override
   redundante pero explícito). `/etc/modprobe.d/8192eu.conf` sin cambios de paths.

**REVERTIR al resoldar el conector:** `0x11` → `0x33` en ambos lugares + recompilar +
`sudo ./install_manual.sh`.

Resultado: ping gateway 0% loss (antes stalls de 1-51 fallos), señal -44 dBm,
tx bitrate 300 Mbps. Script de chequeo: `~/.local/bin/wn8200nd-antenna`.

## USB Stability
- `MAX_CONTINUAL_IO_ERR=80` (era 10→30→80, evita surprise_removed en channel switch)
- USB autosuspend desactivado (`rtw_enusbss=0`)

### EDCCA / Adaptivity

### Parámetros runtime (en /etc/modprobe.d/8192eu.conf)
| Parámetro | Valor | Efecto |
|-----------|-------|--------|
| `rtw_adaptivity_th_l2h_ini` | 15 | Threshold L2H inicial |
| `rtw_adaptivity_th_edcca_hl_diff` | 5 | Diferencia H-L EDCCA |
| `rtw_rxgain_offset_2g` | 0 | Sin atenuación LNA (2026-08-08: era 4; con señal débil atenuar empeora sensibilidad — medido +19 dB y 3.2x throughput) |
| `rtw_notch_filter` | 1 | Filtro notch |
| `rtw_smart_ps` | 0 | Sin ahorro energía |
| `rtw_bw_mode` | 0x20 | HT20 forzado en 2.4G (2026-08-08: era 0x21 HT40; canal angosto con 1 antena capta menos ruido) |

### Init override (parche aplicado)
`phydm_set_l2h_th_ini_carrier_sense()` en `driver/hal/phydm/phydm_adaptivity.c:350`
forzaba `dm->th_l2h_ini = 10` siempre para IC 11N en carrier_sense mode,
pisoteando el module_param. **Parche:** guard `if (dm->th_l2h_ini != 0) return;`
respeta el valor si fue configurado via modprobe.
srcversion post-parche: D4329188BC16E20CC78F085.

### EDCCA threshold calculation runtime (phydm_edcca_thre_calc)
RTL8192E es ODM_IC_PWDB_EDCCA. En adapt mode:
```
l2h_dyn_min = th_l2h_ini + igi_target  (igi_target=0x32=50)
th_l2h = min(igi, l2h_dyn_min)
th_h2l = th_l2h - th_edcca_hl_diff
```
Con th_l2h_ini=15, igi~0x35: l2h_dyn_min=65, th_l2h=IGI(~53), th_h2l=48.
En NORMAL mode (adaptivity disabled): `th_l2h = max(igi + TH_L2H_DIFF_IGI, EDCCA_TH_L2H_LB)`.

## Debug (DBG_ADPTVTY)
Activar logs EDCCA en dmesg via proc:
```
echo "dbg 13 1" | sudo tee /proc/net/rtl8192eu/wn8200nd/odm/cmd
```
Bit 13 = DBG_ADPTVTY (0x2000). Se pierde al recargar módulo.
Comandos phydm_debug disponibles:
- `dbg 100` — mostrar componentes debug activos
- `dbg <N> 1` — habilitar bit N
- `dbg <N> 2` — deshabilitar bit N
- `dbg 101` — deshabilitar todos

Logs cada ~2s muestran:
```
[PHYDM] mode = CARRIER SENSE
[PHYDM] th_l2h_ini = 15, th_edcca_hl_diff = 5
[PHYDM] IGI = 0x35, th_l2h = -47 dBm, th_h2l = -52 dBm
```

## Procfs debug
`/proc/net/rtl8192eu/wn8200nd/odm/`:
- `adaptivity` — read/write th_l2h_ini y th_edcca_hl_diff (write: formato `0xNN MM`, hex+decimal)
- `cmd` — comandos phydm_debug (formato `dbg 13 1`)
- `/proc/net/rtl8192eu/wn8200nd/rx_signal` — RSSI, señal por path RF
- `/proc/net/rtl8192eu/wn8200nd/rx_stat` — estadísticas RX
- `/proc/net/rtl8192eu/wn8200nd/survey_info` — APs visibles por canal

Sysfs module params: `/sys/module/8192eu/parameters/`
⚠️ Escribir a sysfs NO propaga a registry_priv ni a dm->edcca_mode.
Son variables separadas: module_param se copia a registry_priv solo al init.

## DKMS
- **dkms instalado** (3.2.2) y driver **registrado**: `rtl8192eu/1.6` (AUTOINSTALL=yes)
- Source DKMS: `/usr/src/rtl8192eu-1.6/` — **sync del repo parcheado** (rsync manual tras cada cambio relevante:
  `sudo rsync -a --delete --exclude '.git' --exclude '*.o' --exclude '*.ko' --exclude '*.cmd' --exclude '*.mod*' --exclude '.tmp_versions' --exclude 'Module.symvers' --exclude 'modules.order' ./ /usr/src/rtl8192eu-1.6/`)
- **Kernel updates: regeneración AUTOMÁTICA** con los parches (1T1R + EDCCA + EPIPE). El .ko de DKMS
  (`updates/dkms/8192eu.ko.xz`) tiene PRIORIDAD sobre el manual.
- Instalación principal: `sudo ./wifi_manager.sh` (TUI — hace build + copia a /usr/src + dkms add/install)
- `sudo ./install_manual.sh` **(v3)**: asegura DKMS si falta (sync source parcheado a /usr/src + `dkms add`),
  usa `dkms build + install --force` si dkms existe; vía manual solo si dkms no está.
  **SIEMPRE reinicia NetworkManager al final** (`systemctl restart NetworkManager`) —
  NM no reconecta solo tras recargar el módulo. Fallback: `nmcli device connect wn8200nd`.
- Script de recarga con fallback NM: `~/.local/bin/reload-wn8200nd-1ant`
- Parámetros configurables: `/etc/modprobe.d/8192eu.conf` (EDCCA) + `/etc/modprobe.d/rtl8192eu.conf` (paths/1T1R)

## Monitoreo pasivo
`monitoring/rx_drop_watchdog.sh` vía cron cada 30min:
- Lee rx_dropped/rx_packets de sysfs, compara con último estado
- Escribe CSV en `monitoring/rx_drop_monitor_YYYY-MM-DD_HHMMSS.csv` (uno por ejecución)
- Filtra falsos positivos: interfaz down, sin IP/gateway, contadores reseteados
- Solo alerta cuando drops > 0
- Cron (Hermes): rx-drop-watchdog, job_id 1db902a53a75

## Parámetros Runtime Ajustables
```
rtw_adaptivity_th_l2h_ini      # threshold L2H adaptivity (default 0)
rtw_adaptivity_th_edcca_hl_diff  # diff H-L EDCCA (default 0, override->7 si 0)
rtw_rxgain_offset_2g             # atenuación LNA en 2.4GHz (default 0, nuestro 4)
rtw_notch_filter                 # filtro notch (default 0, nuestro 1)
rtw_smart_ps                     # PS inteligente (default 2, nuestro 0)
rtw_napi_threshold               # Mbps threshold para dynamic NAPI (default 100)
rtw_ampdu_factor                 # AMPDU aggregation (default 7)
```
