# STACK.md — ficha técnica del repo (input para generar skills)

> Documento de referencia **factual** del stack, versionado, invariantes y procedimientos
> de `MoriNo23/rtl8192eu-wn8200nd-driver`.
> Objetivo: poder **reconstruir / refactorizar el driver sin romper nada**.
> Todo lo de aquí está verificado contra el árbol de fuentes (rutas y líneas reales).
> Fecha de captura: 2026-08-22 · commit base `b2f1df5`.

---

## 1. Identidad del proyecto

| Campo | Valor |
|---|---|
| Repo | `MoriNo23/rtl8192eu-wn8200nd-driver` (privado) |
| Naturaleza | Fork **personal** de un driver de kernel Linux out-of-tree |
| Upstream | [`clnhub/rtl8192eu-linux`](https://github.com/clnhub/rtl8192eu-linux), rama `5.11.2.3` |
| Upstream del upstream | `Mange/rtl8192eu-linux-driver` → source GPLv2 de Realtek |
| Módulo generado | `8192eu.ko` |
| Licencia | GPLv2 (`LICENSE`) |
| Rama única | `main` |

### Hardware de referencia (una sola unidad física)

```
Bus 001 Device 018: ID 2357:0126 TP-Link 802.11n NIC
```

| Campo | Valor |
|---|---|
| USB ID | `2357:0126` |
| Modelo | TP-Link TL-WN8200ND(UN) **V3.0** (DVD oficial es V2.0) |
| Chipset | Realtek **RTL8192EU** — USB 2.0, 802.11n, 2T2R, solo 2.4 GHz |
| Interfaz | `wn8200nd` |
| **Defecto físico** | conector de **antena B (path RF 1) desoldado** — confirmado desarmando el adaptador |
| Host | netbook ~2009, Intel Sandy Bridge, RAM limitada |
| SO target | Debian, kernel **6.12.x** |

Tabla de IDs del driver: `driver/os_dep/linux/usb_intf.c:203-214` (bloque `RTL8192E`).
El ID propio está en la **línea 212**.

---

## 2. Stack técnico

### Lenguajes y runtime

| Capa | Tecnología | Versión / detalle |
|---|---|---|
| Driver | **C**, kernel-space (GNU C, estilo kernel Linux) | base Realtek `v5.11.2.3-11-g0b6c21f44.20210820` |
| BTCoex string | — | `COEX20171113-0047` (definido pero deshabilitado) |
| Scripts de instalación | **Bash** | `#!/bin/bash`, `set -e` |
| Monitoreo | **Bash** | `#!/usr/bin/env bash` + cron |
| Análisis / RE | **Python 3** | `pefile`, `requests`, `csv`, `json`, `re`, `os`, `sys` |

`driver/include/rtw_version.h:1`
```c
#define DRIVERVERSION "v5.11.2.3-11-g0b6c21f44.20210820_COEX20171113-0047"
#define BTCOEXVERSION "COEX20171113-0047"
```

### Build

| Elemento | Detalle |
|---|---|
| Sistema | GNU Make + **Kbuild** del kernel |
| Makefile raíz | forwarding puro → `$(MAKE) -C driver $@` (necesario para DKMS) |
| Makefile real | `driver/Makefile` (~2200 líneas, matriz de ~20 ICs y ~60 plataformas) |
| Kconfig | `driver/Kconfig` (presente, no usado en out-of-tree) |
| Compilador | GCC; el Makefile detecta `>= 4.9` vía `$(CC) -dumpversion` + `bc` |
| Optimización | `ccflags-y += -O2` (era `-O3` hasta 2026-08-08) |
| Link | `ldflags-y += --strip-debug` |
| Includes | `-I$(src)/include` |
| Warnings suprimidos | `-Wno-error=date-time`, `-Wno-date-time` (gcc≥4.9), `-Wno-unused-variable`, `-Wno-unused-function` |
| Dependencias de build | `linux-headers-$(uname -r)`, `build-essential`, `bc`, `dkms` |

### Empaquetado / despliegue

| Elemento | Detalle |
|---|---|
| DKMS | versión **3.2.2**, `AUTOINSTALL=yes` |
| `dkms.conf` | `PACKAGE_NAME=rtl8192eu`, `PACKAGE_VERSION=1.6.2`, `BUILT_MODULE_NAME[0]=8192eu`, `BUILT_MODULE_LOCATION[0]=driver/`, `DEST_MODULE_LOCATION[0]=/kernel/drivers/net/wireless/` |
| MAKE\[0\] | `'make' -C driver -j$(nproc) all KVER=${kernelver}` |
| Source DKMS | `/usr/src/rtl8192eu-<VER>/` (rsync del repo parcheado) |
| Destino efectivo | `/lib/modules/$(uname -r)/updates/dkms/8192eu.ko.xz` (**tiene prioridad** sobre la copia manual) |
| Config runtime | `/etc/modprobe.d/8192eu.conf` (EDCCA/RF) y `/etc/modprobe.d/rtl8192eu.conf` (paths/1T1R) |
| Integración SO | NetworkManager (`systemctl restart NetworkManager`, `nmcli device connect wn8200nd`) |

### CI

`.github/workflows/build.yml` — **build-check**, no produce artefactos instalables
(el `.ko` del runner Ubuntu no es vermagic-compatible con Debian 6.12.x).

| Campo | Valor |
|---|---|
| Trigger | `push` a `main`, `workflow_dispatch` |
| Runner | `ubuntu-latest`, `actions/checkout@v4`, `permissions: contents: read` |
| Matriz | `linux-headers-generic`, `linux-headers-6.8-generic`, `linux-headers-6.11-generic`, `linux-headers-6.14-generic`, `fail-fast: false` |
| Pasos | `make clean` → `make -j$(nproc) all` → existe `driver/8192eu.ko` → `modinfo` → `modinfo -p` de params clave → `strings` de símbolos AP |

---

## 3. APIs consumidas

### Kernel Linux
- **net core**: `net_device`, `sk_buff`, NAPI (`CONFIG_RTW_NAPI` + `CONFIG_RTW_NAPI_DYNAMIC`), GRO (off), scatter-gather (`CONFIG_RTW_NETIF_SG=y`).
- **cfg80211 / nl80211**: `os_dep/linux/ioctl_cfg80211.c`, `struct cfg80211_ops` (~línea 10483).
- **Wireless Extensions (WEXT) / ioctl**: `os_dep/linux/ioctl_linux.c`.
- **cfg80211 vendor commands**: `rtw_cfgvendor.c` (no usado).
- **Android private cmds**: `rtw_android.c` (`CONFIG_RTW_ANDROID = 0`).
- **USB core**: URBs, `usb_intf.c`, `usb_ops_linux.c`; autosuspend off.
- **procfs**: `CONFIG_PROC_DEBUG=y` → `/proc/net/rtl8192eu/<iface>/`.
- **sysfs / module_param**: `/sys/module/8192eu/parameters/`.
- **generic netlink**: `nlrtw.c`.
- **rhashtable**: shim propio (`rtw_rhashtable.c`) por compatibilidad de versiones.

**Compatibilidad de versión**: el patrón obligatorio en todo el árbol es
`#if (LINUX_VERSION_CODE >= KERNEL_VERSION(x, y, z))`. Rango cubierto: 2.6.x → 6.14.
Solo en `ioctl_cfg80211.c` hay decenas de guardas de este tipo.

### APIs internas Realtek
- **HAL** (`hal_intf.c`, `hal_com.c`, `hal_com_phycfg.c`) — capa de abstracción de IC.
- **PHYDM / ODM** (`hal/phydm/`) — DIG, EDCCA/adaptivity, CFO tracking, antdiv, debug (`dbg` cmds).
- **HALRF** (`hal/phydm/halrf/`) — calibración RF.
- **efuse** (`hal/efuse/`, `core/efuse/`).
- **HALMAC** (`hal_halmac.c`) — presente pero **no aplica** al 8192E.

### Servicios externos
- **OpenRouter API** — `https://openrouter.ai/api/v1/chat/completions`, env `OPENROUTER_API_KEY`, en `research/re_analysis/llm_analysis.py`. Rutas hardcodeadas a Google Colab (`/content/drive/MyDrive/...`).
- **GitHub Actions**.

---

## 4. Versionado

**Regla:** la versión del paquete DKMS **es** el versionado del fork. Semver
`MAJOR.MINOR.PATCH`:

- **PATCH** — fixes de build/compatibilidad de kernel.
- **MINOR** — cambios de comportamiento / optimizaciones / features.
- **MAJOR** — cambios estructurales (p. ej. reconstrucción del árbol).

**Versión actual: `1.6.2`.** Aparece en **3 sitios que deben ir sincronizados**:

| Archivo | Referencia |
|---|---|
| `dkms.conf` | `PACKAGE_VERSION="1.6.2"` |
| `install_manual.sh:22` | `VER="1.6.2"` |
| `AGENTS.md` | tabla CHANGELOG |
| `README.md` | `/usr/src/rtl8192eu-1.6.2`, `cat /sys/module/8192eu/version` |

### CHANGELOG

| Versión | Fecha | Cambios |
|---|---|---|
| 1.6.2 | 2026-08-13 | `CONFIG_AP_MODE=y` (softAP/hostapd); bump DKMS; CI build-check con matriz de kernels |
| 1.6.1 | 2026-08-08 | fix `set_monitor_channel` kernel 6.12.101+ (arg `netdev`, backport Debian de 6.13); `-O3`→`-O2`; `rxgain 4→0`; HT40→HT20 (`6324f01`, `c312b04`) |
| 1.6 | 2026-07-30 | baseline del fork: upstream `5.11.2.3` + parches 1T1R / EDCCA / EPIPE / MAX_IO_ERR |

### Procedimiento de bump (obligatorio, en orden)

```bash
# 1. editar dkms.conf, install_manual.sh (VER), AGENTS.md (CHANGELOG), README.md
# 2. renombrar el source DKMS
sudo mv /usr/src/rtl8192eu-<old> /usr/src/rtl8192eu-<new>
# 3. re-registrar
sudo dkms remove rtl8192eu/<old> --all || true
sudo dkms add    -m rtl8192eu -v <new>
sudo dkms build  -m rtl8192eu -v <new> --force
sudo dkms install -m rtl8192eu -v <new> --force
# 4. NM no reconecta solo
sudo systemctl restart NetworkManager
```

### Trazabilidad de parches: `srcversion`

`modinfo 8192eu | grep srcversion` es la huella del árbol compilado. Valores históricos
registrados en `AGENTS.md`:

| srcversion | Estado |
|---|---|
| `A0A33550E9968D9FA55C846` | tras el parche 1T1R (`os_intfs.c`) |
| `D4329188BC16E20CC78F085` | tras el parche EDCCA `th_l2h_ini` |

**Anota el srcversion nuevo en cada bump** — es la única forma barata de confirmar que
el `.ko` cargado es el que compilaste.

---

## 5. Configuración de build vigente (`driver/Makefile`)

### IC / interfaz — NO TOCAR
```
CONFIG_RTL8192E = y     ← único IC activo
CONFIG_USB_HCI  = y     ← única interfaz
CONFIG_PCI_HCI  = n   CONFIG_SDIO_HCI = n   CONFIG_GSPI_HCI = n
CONFIG_MULTIDRV = n
CONFIG_PLATFORM_I386_PC = y   (todas las demás plataformas = n)
```

### Features
| Flag | Valor | Razón |
|---|---|---|
| `CONFIG_AP_MODE` | y | softAP/hostapd (desde 1.6.2) |
| `CONFIG_P2P` | n | no usado |
| `CONFIG_MP_INCLUDED` | n | test de fábrica, no usado |
| `CONFIG_BT_COEXIST` | n | sin Bluetooth |
| `CONFIG_WAPI_SUPPORT` | n | — |
| `CONFIG_TDLS` | n | — |
| `CONFIG_MCC_MODE` | n | — |
| `CONFIG_WIFI_MONITOR` | n | activable para captura pasiva |
| `CONFIG_WOWLAN` / `CONFIG_AP_WOWLAN` / `CONFIG_PNO_SUPPORT` | n | — |
| `CONFIG_POWER_SAVING` | n | — |
| `CONFIG_IPS_MODE` / `CONFIG_LPS_MODE` | 0 | sin ahorro de energía |
| `CONFIG_USB_AUTOSUSPEND` | n | estabilidad USB |
| `CONFIG_80211W` | y | PMF |
| `CONFIG_BR_EXT` | y | bridge ext |
| `CONFIG_TRAFFIC_PROTECT` | y | prioriza tráfico |
| `CONFIG_ICMP_VOQ` | y | ICMP prioritario (gaming) |
| `CONFIG_IP_R_MONITOR` | y | ARP VOQ + high rate |
| `CONFIG_RTW_NAPI` | y | con `NAPI_DYNAMIC` (off bajo 100 Mbps) |
| `CONFIG_RTW_GRO` | n | menor latencia |
| `CONFIG_RTW_NETIF_SG` | y | — |
| `CONFIG_RTW_ADAPTIVITY_EN` | enable | EDCCA activo |
| `CONFIG_RTW_ADAPTIVITY_MODE` | carrier_sense | — |
| `CONFIG_RTW_CHPLAN` | 0x34 | plan de canales |
| `CONFIG_RTW_DEBUG` | y | logs en dmesg |
| `CONFIG_RTW_LOG_LEVEL` | 4 | — |
| `CONFIG_PROC_DEBUG` | y | interfaces `/proc` |
| `CONFIG_LOAD_PHY_PARA_FROM_FILE` | y | — |
| `CONFIG_TXPWR_BY_RATE` | y (`_EN` = n) | — |
| `CONFIG_LONG_DELAY_ISSUE` | y | — |
| `CONFIG_SIGNAL_SCALE_MAPPING` | y | — |
| `CONFIG_REDUCE_TX_CPU_LOADING` | y | CPU vieja |
| `CONFIG_RTW_UP_MAPPING_RULE` | tos | — |
| `CONFIG_RTW_ANDROID` | 0 | — |

---

## 6. INVARIANTES — los 6 parches que no se pueden perder

> Cualquier reconstrucción del driver **debe** re-aplicar estos 6 cambios o el adaptador
> vuelve a fallar. Cada uno tiene causa física documentada.

### P1 — 1T1R forzado (antena B muerta)
- **Dónde**: `driver/os_dep/linux/os_intfs.c:333`
- **Qué**: `int rtw_trx_path_bmp = 0x11;` (upstream: `0x33`). TX path 4 + RX path 0 = solo antena A.
- **Refuerzo**: `/etc/modprobe.d/rtl8192eu.conf` → `options 8192eu rtw_trx_path_bmp=0x11`
- **También**: `os_intfs.c:400` → `int rtw_antdiv_cfg = 1;`
- **Síntoma si se pierde**: RSSI -72/-84 dBm, RX clavado en CCK_1M, stalls de ping.
- **Revertir solo si**: se resuelda el conector de antena B → `0x33` en ambos sitios.

### P2 — EDCCA `th_l2h_ini` respeta el module_param
- **Dónde**: `driver/hal/phydm/phydm_adaptivity.c:350-355`, en `phydm_set_l2h_th_ini_carrier_sense()`
- **Qué**: guarda al inicio de la función
  ```c
  if (dm->th_l2h_ini != 0)
      return; /* respetar config del usuario via module_param */
  ```
- **Por qué**: upstream forzaba `th_l2h_ini = 10` siempre en IC 11N/carrier_sense, pisando el `module_param`.

### P3 — `MAX_CONTINUAL_IO_ERR = 80`
- **Dónde**: `driver/include/rtw_io.h:280` (bloque `#ifdef CONFIG_USB_HCI`)
- **Qué**: `10` (upstream) → `30` → **`80`**
- **Por qué**: con `rxagg_mode=0` y `en_napi=0` cada paquete genera un error USB durante el silencio de radio de un channel switch (200-500 ms). Con 30 se llegaba a `surprise_removed` en ~300 ms. Con 80 hay ~800 ms de tolerancia. Una desconexión física real produce errores en <50 ms, así que la detección genuina no se degrada.

### P4 — `-EPIPE`/`-EPROTO` en TX no es `surprise_removed`
- **Dónde**: `driver/os_dep/linux/usb_ops_linux.c:~577` (`urb_write_port_complete`)
- **Qué**: ante `-EPIPE` o `-EPROTO` → `rtw_reset_continual_io_error()` + `sreset_set_wifi_error_status(USB_WRITE_PORT_FAIL)` en vez de matar la interfaz. Solo un status **desconocido** que supere el umbral llega a `rtw_set_surprise_removed()` (`~línea 606`).

### P5 — Watchdog de `WIFI_UNDER_SURVEY` atascado
- **Dónde**: `driver/core/rtw_mlme_ext.c:~12478`
- **Qué**: `#define RTW_SURVEY_STUCK_MS 5000`; si el scan lleva >5 s sin completarse, fuerza `pmlmeext->scan_abort = _TRUE` (+ guarda final contra el flag pegado).
- **Por qué**: sin buffering de RX aggregation, un beacon perdido tras un channel switch dejaba la máquina de estados congelada en silencio.

### P6 — `set_monitor_channel` con arg `netdev` (kernel 6.12.101+)
- **Dónde**: `driver/os_dep/linux/ioctl_cfg80211.c:6910`
- **Qué**:
  ```c
  #if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 13, 0)) || \
      (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 12, 101)) /* backport Debian */
      , struct net_device *netdev
  #endif
  ```
- **Por qué**: Debian retroportó a 6.12.101 el cambio de firma de 6.13. Sin esto no compila.

### Parámetros runtime que forman parte del contrato

`/etc/modprobe.d/8192eu.conf`:
| Param | Valor | Nota |
|---|---|---|
| `rtw_adaptivity_th_l2h_ini` | 15 | depende de P2 para tener efecto |
| `rtw_adaptivity_th_edcca_hl_diff` | 5 | |
| `rtw_rxgain_offset_2g` | **0** | era 4; atenuar con señal débil daba -19 dB y 3.2× menos throughput |
| `rtw_notch_filter` | 1 | |
| `rtw_smart_ps` | 0 | |
| `rtw_bw_mode` | **0x20** (HT20) | era 0x21 (HT40); con 1 antena, canal angosto capta menos ruido |

Hardcodeados en source: `rtw_en_napi = 0`, `rtw_usb_rxagg_mode = 0`,
`rtw_dynamic_agg_enable = 0`, `rtw_enusbss = 0`.

⚠️ Escribir en `/sys/module/8192eu/parameters/*` **no** propaga a `registry_priv` ni a
`dm->edcca_mode`: el `module_param` se copia al `registry_priv` solo en el init.
Para tuning en vivo usar `/proc/net/rtl8192eu/<iface>/odm/`.

---

## 7. Procedimientos operativos

### Build local
```bash
make clean
make -j"$(nproc)" all       # genera driver/8192eu.ko
modinfo driver/8192eu.ko
modinfo -p driver/8192eu.ko | grep -E 'rtw_enusbss|rtw_en_napi|rtw_usb_rxagg|rtw_dynamic_agg'
```

### Instalación
```bash
sudo ./install_manual.sh    # no interactivo (DKMS, v3)
sudo ./wifi_manager.sh      # TUI: install / update / remove
```
`install_manual.sh` v3: si hay dkms → sync a `/usr/src/rtl8192eu-$VER` + `dkms add` si falta
+ `dkms build`/`install --force`; si no hay dkms → copia manual a
`/lib/modules/$KVER/kernel/drivers/net/wireless/` y borra los `.ko.xz`/`.ko.zst` de
`updates/dkms/` que lo pisarían. **Siempre** reinicia NetworkManager al final.

Sync manual del source a DKMS:
```bash
sudo rsync -a --delete --exclude '.git' --exclude '*.o' --exclude '*.ko' --exclude '*.cmd' \
  --exclude '*.mod*' --exclude '.tmp_versions' --exclude 'Module.symvers' \
  --exclude 'modules.order' ./ /usr/src/rtl8192eu-1.6.2/
```

### Verificación
```bash
lsusb -d 2357:0126
lsmod | grep 8192
cat /sys/module/8192eu/version          # 1.6.2
modinfo 8192eu | grep -E 'srcversion|vermagic|2357p0126'
iw dev wn8200nd link                    # signal, bitrate
cat /proc/net/rtl8192eu/wn8200nd/rx_signal
```

### Debug EDCCA
```bash
echo "dbg 13 1" | sudo tee /proc/net/rtl8192eu/wn8200nd/odm/cmd   # bit 13 = DBG_ADPTVTY
sudo dmesg -w | grep -E 'ADPTVTY|th_l2h.*dBm'
# dbg 100 = listar componentes · dbg <N> 2 = desactivar · dbg 101 = desactivar todo
```
Se pierde al recargar el módulo.

### Monitoreo pasivo
`monitoring/rx_drop_watchdog.sh` vía cron cada 30 min → CSV
`monitoring/rx_drop_monitor_YYYY-MM-DD_HHMMSS.csv` (uno por ejecución).
Filtra falsos positivos (interfaz down, sin IP/gateway, contadores reseteados).
Cron: job `rx-drop-watchdog`, id `1db902a53a75`.

---

## 8. Inventario del árbol (para decidir qué se reconstruye)

| Ruta | Tamaño | Estado |
|---|---|---|
| `driver/hal/phydm/` | 4.5 M | activo solo `rtl8192e/`; `halrf/` 1.0 M y `txbf/` 220 K no aplican a 11N |
| `driver/hal/rtl8192e/` | 1.1 M | **núcleo activo** |
| `driver/hal/btc/` | 572 K | muerto (`BT_COEXIST=n`) |
| `driver/hal/hal_com.c` | 448 K | activo |
| `driver/hal/hal_mp.c` | 96 K | muerto (`MP_INCLUDED=n`) |
| `driver/hal/hal_halmac.c/.h` | 148 K | muerto (chips 8822/8814/8821C) |
| `driver/hal/hal_mcc.c` | 128 K | muerto (`MCC_MODE=n`) |
| `driver/core/` | 3.6 M | activo, con muertos: `rtw_p2p.c`, `rtw_wapi*.c`, `rtw_vht.c`, `rtw_tdls.c`, `rtw_mp.c`, `rtw_bt_mp.c`, `rtw_btcoex*.c`, `rtw_beamforming.c`, `rtw_rson.c`, `mesh/`, `wds/`, `rtw_sdio.c` |
| `driver/include/` | 3.0 M | activo |
| `driver/os_dep/linux/` | 1.9 M | activo; muertos: `ioctl_mp.c`, `rtw_android.c`, `rtw_cfgvendor.c` |
| `driver/platform/` | 72 K | solo `platform_ops.c/.h` + `custom_country_chplan.h`; el resto es SDIO ARM/SoC |
| `docs/` | 372 K | `DRIVER_BIBLE.md`, `BUGS.md`, `BACKPORT_*.md`, `analysis/*.csv`, `tasks/` |
| `research/re_analysis/` | 348 K | Python de RE; rutas Colab hardcodeadas |
| `monitoring/` | 8 K | watchdog |

**Basura de trabajo a eliminar**: `driver/os_dep/linux/os_intfs.c.backup`,
`driver/os_dep/linux/os_intfs.c.mine`.

---

## 9. Reglas de oro para reconstruir sin romper nada

1. **Un cambio por commit**, con el motivo físico/técnico en el mensaje.
2. **Nunca borrar un archivo sin comprobar antes que el Makefile no lo referencia**:
   `grep -n "<archivo sin extensión>" driver/Makefile`. Muchos `.o` entran por bloques
   `ifeq` anidados (p. ej. `CONFIG_WIFI_MONITOR` se define también dentro de
   `CONFIG_RTW_IPCAM_APPLICATION`, y `CONFIG_AP_MODE` dentro de `CONFIG_AP_WOWLAN`).
3. **Los 6 invariantes de la §6 se verifican tras cada reconstrucción**, con grep, antes de compilar.
4. **Compilar siempre contra los headers del kernel local** (Debian 6.12.x); el CI solo
   valida que el source compila en kernels modernos.
5. **Validar en este orden**: `make clean && make -j` → `modinfo -p` → `dkms build` →
   instalar → `srcversion` nuevo → `iw dev wn8200nd link` → ping al gateway 100 paquetes
   (criterio de aceptación: **0% loss**, señal ≈ -44 dBm, tx bitrate ≈ 300 Mbps con HT20/1T1R).
6. **Tener siempre un `.ko` bueno anterior** para volver atrás: guarda una copia del
   `updates/dkms/8192eu.ko.xz` que funciona antes de instalar el nuevo.
7. **No confiar en sysfs para probar cambios de parámetros**: no propaga (§6).
8. **Bump de versión en los 4 sitios sincronizados** (§4) o DKMS se desalinea con `/usr/src`.

---

## 10. Estado conocido / pendientes

- `docs/BUGS.md:110` apunta a `https://github.com/MoriNo23/TL-WN8200ND-driver/issues`, repo que **no existe** con ese nombre.
- `install_manual.sh` y `wifi_manager.sh` se solapan (ambos hacen sync a `/usr/src` + dkms).
- `research/re_analysis/*.py` tienen rutas hardcodeadas de Google Colab.
- `monitoring/` genera un CSV por ejecución (crecimiento sin límite en el repo).
- BUG-CRSH-002 (`docs/BUGS.md`): crash que requiere ciclo de modprobe — mitigado por P3/P4/P5.
