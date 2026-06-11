# rtl8192eu-linux — TL-WN8200ND Driver

## Repo
- Remote: `MoriNo23/TL-WN8200ND-driver` (privado)
- Branch: `optimization-wn8200nd` (única, default)
- Fork del repo original `rtl8192eu-linux`, rama `5.11.2.3`
- Adaptador: TL-WN8200ND(UN) V3.0 (chipset RTL8192EU) — DVD oficial es V2.0

## Build Flags Especiales
| Flag | Valor | Razón |
|------|-------|-------|
| `-O3` | habilitado | Optimización agresiva para gaming |
| `CONFIG_RTW_NAPI_DYNAMIC` | sí | Desactiva NAPI en bajo throughput (<100 Mbps) para ahorrar CPU |
| `CONFIG_RTW_GRO` | n | Desactivado para reducir latencia |
| `CONFIG_AP_MODE` | n | No usado |
| `CONFIG_P2P` | n | No usado |
| `CONFIG_MP_INCLUDED` | n | No usado |
| `CONFIG_BT_COEXIST` | n | BT no usado |
| `CONFIG_IPS_MODE` | 0 | Sin ahorro energía |
| `CONFIG_LPS_MODE` | 0 | Sin ahorro energía |
| `CONFIG_ICMP_VOQ` | y | Prioriza ICMP para gaming |
| `CONFIG_IP_R_MONITOR` | y | Prioriza ARP/high rate |

## Parámetros hardcodeados (source)
- `rtw_en_napi = 0` — NAPI desactivado (estabilidad USB)
- `rtw_usb_rxagg_mode = 0` — agreación USB desactivada
- `rtw_dynamic_agg_enable = 0` — agregación dinámica desactivada

## MIMO
- `rtw_trx_path_bmp=0x33` — forzado 2 antenas
- `rtw_antdiv_cfg=1` — antenna diversity forzada

## USB Stability
- `MAX_CONTINUAL_IO_ERR=30` (vs 10 original)
- USB autosuspend desactivado

## DKMS
- Source: `/usr/src/rtl8192eu-1.0/`
- Instalado para kernels: 6.12.85, .86, .88, .90
- Instalación: `sudo ./install_wifi.sh`
- Parámetros configurables: `/etc/modprobe.d/8192eu.conf`

## Parámetros Runtime Ajustables
```
rtw_adaptivity_th_l2h_ini  # threshold L2H adaptivity (default 0)
rtw_adaptivity_th_edcca_hl_diff  # diff H-L EDCCA (default 0)
rtw_napi_threshold  # Mbps threshold for dynamic NAPI (default 100)
rtw_ampdu_factor  # AMPDU aggregation (default 7)
```

## Arquitectura
Sistema target: netbook ~2009, Intel Sandy Bridge, RAM limitada.
Driver WiFi USB: TL-WN8200ND(UN) V3.0 (RTL8192EU). DVD oficial V2.0.
