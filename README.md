# rtl8192eu-linux — TL-WN8200ND Driver (optimization-wn8200nd)

> ⚠️ **ADVERTENCIA — CÓDIGO DE NIVEL KERNEL (RING 0)**
> Este paquete contiene un módulo del kernel de Linux. Errores en la compilación, instalación o ejecución pueden causar inestabilidad del sistema, kernel panics, pérdida de datos o caídas de red. Utilícelo bajo su propia responsabilidad.

Driver optimizado para el adaptador WiFi **TP-Link TL-WN8200ND(UN) V3.0** basado en el chipset **Realtek RTL8192EU** (USB 2.0, 802.11n 2T2R). Repo fork de `rtl8192eu-linux` rama `5.11.2.3`.

## Chipsets y revisiones HW soportadas

| Revisión | Chipset | USB ID | Estado |
|----------|---------|--------|--------|
| TL-WN8200ND(UN) V2 | RTL8192EU | 2357:0126 | Soportado |
| **TL-WN8200ND(UN) V3** | **RTL8192EU** | **2357:0126** | **Soportado (este fork)** |

## Funcionalidades

| Funcionalidad | Estado |
|---------------|--------|
| STA (cliente WiFi) | ✅ Funcional |
| WPA2/WPA3 | ✅ Funcional |
| 2.4 GHz HT20/HT40 | ✅ Funcional |
| 2×2 MIMO | ✅ Forzado (rtw_trx_path_bmp=0x33) |
| AP / Monitor / Packet injection | ❌ Deshabilitado en este fork |

---

## 🔑 Flujo de trabajo (LEER PRIMERO — no confundir)

### CI = solo TEST de compilación
`.github/workflows/build.yml` compila en Ubuntu latest y sube `8192eu.ko.gz` a GitHub Release
para confirmar que el código compila limpio. **El `.ko` del release es para kernel azure de Ubuntu,
NO es drop-in para el host Debian** — no lo uses para instalar. Corré el CI cuando hagas cambios
de código para verificar que no hay *failed*.

### Shell = instalación real en el host (wifi_manager.sh)
Único script: `wifi_manager.sh` (TUI interactivo). Soluciona la confusión de DKMS: **SIEMPRE
borra el source viejo de `/usr/src/rtl8192eu-1.0/` y copia tu build reciente del repo ANTES de
compilar**. Así el DKMS nunca usa una copia olvidada; cuando el kernel cambie, el auto-rebuild
usa tus features nuevas.

**Flujo al tocar código:**
1. Editás código en `driver/` (NO hace falta compilar a mano — el script compila solo)
2. `sudo ./wifi_manager.sh` → elegís `2) Actualizar` (borra lo viejo + compila tu build reciente + reinstala)
3. Pusheás → CI confirma verde

> El modo Instalar/Actualizar compila automáticamente `driver/8192eu.ko` (make clean + make all).
> No compilés manualmente antes.

---

## Instalación / Gestión (wifi_manager.sh)

### Requisitos
```bash
sudo apt update
sudo apt install -y linux-headers-$(uname -r) build-essential bc dkms
```

### Usar el TUI
```bash
cd /home/fullmetal/InstalarDriver/rtl8192eu-linux
sudo ./wifi_manager.sh
```
Menú:
```
1) Instalar     (primera vez / forzar desde cero)
2) Actualizar   (borra lo viejo + reinstala tu build reciente)  ← usá esto al editar código
3) Desinstalar  (limpia TODO: módulo, /lib/modules, /usr/src, /var/lib/dkms)
4) Salir
```

El modo Instalar/Actualizar hace: descarga módulo → borra `/usr/src/rtl8192eu-$VER` y
`/var/lib/dkms/rtl8192eu` → **compila `driver/8192eu.ko` (automático)** → copia tu repo a `/usr/src`
(source fresco, carpeta `rtl8192eu-$VER`) → `dkms add` + `dkms install --force` → `depmod -a` → `modprobe 8192eu`.

> **Nota técnica (fix de build):** el `dkms.conf` tiene `BUILT_MODULE_LOCATION[0]="driver/"` porque el
> Makefile forwarding delega a `driver/`, y el `.ko` queda en `build/driver/8192eu.ko` (no en la raíz del
> build). Sin eso, DKMS reportaba "Build failed" pese a compilar bien (exit 0). El `dkms install` usa
> `--force` para pisar el `.ko` previo en `/lib/modules`.
> `VER` actual = `1.6` (subirla no rompe el workflow: el script borra `/usr/src` y `/var/lib/dkms` completos).

> No hace falta correr `make` a mano: el script compila solo. Solo editá el código y elegí
> `2) Actualizar`.

**Auto-rebuild en update de kernel:** DKMS recompila solo cuando hay nuevo kernel, usando el
source que copiaste en `/usr/src` (que ya tiene tus features). No recompila en cada boot.

### Verificar
```bash
lsmod | grep 8192eu
cat /sys/module/8192eu/parameters/rtw_enusbss   # debe mostrar: 0
```

---

## Parámetros hardcodeados (source)

| Flag | Valor | Razón |
|------|-------|-------|
| `rtw_en_napi` | 0 | NAPI off (estabilidad USB) |
| `rtw_usb_rxagg_mode` | 0 | agregación USB off (baja latencia) |
| `rtw_dynamic_agg_enable` | 0 | agregación dinámica off |
| `rtw_enusbss` | 0 | USB autosuspend off |
| `MAX_CONTINUAL_IO_ERR` | 80 | tolerancia errores USB (era 10→30→80) |
| `CONFIG_IPS_MODE` / `CONFIG_LPS_MODE` | 0 | sin ahorro energía |
| `-O3` | on | optimización agresiva para gaming |
| `rtw_trx_path_bmp` | 0x33 | 2×2 MIMO forzado |
| `rtw_antdiv_cfg` | 1 | antenna diversity forzada |
| `rtw_TxBBSwing_2G` | 255 | potencia máxima 2.4GHz |

## Parámetros runtime EDCCA / adaptivity

Además de los parámetros USB, el driver tiene parámetros runtime para EDCCA
configurables en `/etc/modprobe.d/8192eu.conf`:

| Parámetro | Default | Descripción |
|-----------|---------|-------------|
| `rtw_adaptivity_th_l2h_ini` | 0 | Threshold L2H (modprobe: 15) |
| `rtw_adaptivity_th_edcca_hl_diff` | 0 | Diferencia H-L (modprobe: 5, si 0 se override a 7) |
| `rtw_rxgain_offset_2g` | 0 | Atenuación LNA 2.4GHz (modprobe: 4) |
| `rtw_notch_filter` | 0 | Filtro notch (modprobe: 1) |
| `rtw_smart_ps` | 2 | Ahorro energía (modprobe: 0) |

### Init override (parche 2026-07-29)
`phydm_set_l2h_th_ini_carrier_sense()` en `driver/hal/phydm/phydm_adaptivity.c:350`
forzaba `th_l2h_ini = 10` siempre para RTL8192EU en carrier_sense mode,
pisoteando el module_param 15. **Parche:** guard `if (th_l2h_ini != 0) return;`
respeta el valor configurado. Comportamiento igual al branch no-carrier_sense
(línea 703) que ya tenía este guard.

### Debug EDCCA en dmesg
```bash
echo "dbg 13 1" | sudo tee /proc/net/rtl8192eu/wn8200nd/odm/cmd
```
Bit 13 = DBG_ADPTVTY (0x2000). Muestra logs cada ~2s:
```
[PHYDM] phydm_adaptivity ====>
[PHYDM] mode = CARRIER SENSE, debug_mode = 0
[PHYDM] th_l2h_ini = 15, th_edcca_hl_diff = 5
[PHYDM] IGI = 0x35, th_l2h = -47 dBm, th_h2l = -52 dBm
```
Ver en tiempo real: `sudo dmesg -w | grep -E 'ADPTVTY|th_l2h.*dBm'`

Otros comandos phydm_debug:
```bash
echo "dbg 100" | sudo tee .../odm/cmd   # mostrar debug components activos
echo "dbg 13 2" | sudo tee .../odm/cmd   # deshabilitar
echo "dbg 101" | sudo tee .../odm/cmd    # deshabilitar todos
```

⚠️ Escribir a `/sys/module/8192eu/parameters/rtw_adaptivity_en`
**no propaga** a registry_priv. Usar `odm/cmd` en su lugar.

### Monitoreo pasivo rx_dropped
`monitoring/rx_drop_watchdog.sh` vía cron cada 30min (Hermes cron
`rx-drop-watchdog`). Lee rx_dropped/rx_packets de sysfs, compara con
estado previo, escribe CSV en `monitoring/rx_drop_monitor_YYYY-MM-DD_HHMMSS.csv`
(un archivo por ejecucion). Filtra falsos positivos: interfaz DOWN,
sin IP/gateway, contadores reseteados.

---

## Parches anti-freeze (channel switch del router)

- **#1 Kill-switch** (`driver/os_dep/linux/usb_ops_linux.c`, `usb_write_port_complete`):
  TX URB con `-EPIPE`/`-EPROTO` (silencio de radio transitorio durante channel switch) resetean el
  contador de errores en lugar de declarar `surprise_removed`. Solo un status desconocido tras
  alcanzar `MAX_CONTINUAL_IO_ERR` (80) mata la interfaz. Evita `modprobe cycle`.
- **#3 MLME stuck** (`driver/core/rtw_mlme_ext.c`, `linked_status_chk`): además de `scan_abort`,
  re-armar `scan_to_timer` a 50ms como guardián final para limpiar `WIFI_UNDER_SURVEY` aunque
  `survey_timer_hdl` no dispare.

Detalle en brain-vault: `dev/01-rtl8192eu-freeze-fix.md`.

---

## Estructura del repositorio

```
rtl8192eu-linux/
├── driver/               # Código fuente del módulo del kernel
│   ├── core/  hal/  include/  os_dep/  platform/
│   ├── Makefile  Kconfig
│   └── 8192eu.ko         # Módulo compilado (generado por make)
├── docs/                 # BACKPORT_REPORT, DRIVER_BIBLE, BUGS.md, notes/
├── research/             # Ingeniería inversa y análisis
├── monitoring/           # Monitoreo pasivo rx_dropped (watchdog + logs por fecha)
│   ├── rx_drop_watchdog.sh
│   └── rx_drop_monitor_*.csv
├── install_manual.sh     # Instalación manual post-compilación (anti-DKMS)
├── dkms.conf             # PACKAGE_NAME=rtl8192eu (matchea con wifi_manager.sh)
├── wifi_manager.sh       # TUI instalar/actualizar/desinstalar (recomendado)
├── AGENTS.md             # Config del driver para agentes
└── README.md
```

## Bugs conocidos
Ver [docs/BUGS.md](docs/BUGS.md). BUG-CRSH-002 = crash que requería modprobe cycle (mitigado por
parche #1).

## Créditos
- [clnhub/rtl8192eu-linux](https://github.com/clnhub/rtl8192eu-linux) (rama `5.11.2.3`, upstream)
- [Mange/rtl8192eu-linux-driver](https://github.com/Mange/rtl8192eu-linux-driver) (base original)
- Realtek Semiconductor Corp. (GPLv2) — TP-Link Technologies (hardware)

**No afiliación:** proyecto no afiliado a TP-Link ni Realtek.
**Licencia:** GPLv2 — ver [LICENSE](LICENSE).

https://github.com/MoriNo23/TL-WN8200ND-driver
