# rtl8192eu-wn8200nd-driver — TL-WN8200ND Driver

## ⚡ Skills — CARGA OBLIGATORIA ANTES DE TRABAJAR

Antes de tocar código, leer las skills de `skills/`. Son la caja de herramientas del
refactor y **cada una define el procedimiento correcto**; no improvisar con sed/regex
cuando existe una skill para el caso.

| Fase | Skills a cargar |
|---|---|
| Entender el árbol | `bear-compilation-database`, `code-navigation-cscope-global`, `cflow-callgraph` |
| Medir estado inicial | `sparse-typechecker`, `smatch-static-analysis`, `checkpatch-kernel-style` |
| Podar código muerto | `unifdef-coan`, `iwyu-deheader` |
| Transformar | `coccinelle-spatch`, `clang-tooling-c` |
| Verificar APIs de kernel | `bootlin-elixir-api`, `lore-kernel-archives-api`, `debian-sources-api`, `kernel-doc-and-api-references`, `kernel-org-releases-api` |
| Seguridad / versiones | `linux-kernel-cves-api`, `repology-api`, `github-rest-api-code-archaeology` |
| Historia del repo | `git-filter-repo` |

Índice completo y orden de uso: `skills/README.md`.
Reglas mínimas que imponen las skills:
- Antes de borrar una función: `cscope -dL -3` **+** `grep -w` (los punteros a función no
  aparecen en el grafo de llamadas).
- Antes de borrar un fichero: `grep -n "<fichero>" driver/Makefile driver/hal/phydm/phydm.mk`.
- Toda transformación masiva va con un `.cocci` versionado, un cambio por commit.
- Verificar el resultado con `bloat-o-meter antes.o despues.o`: si no baja el tamaño, no se
  eliminó nada real.

## Versionado (DKMS pkg rtl8192eu)

La versión del paquete DKMS (`VER` en install_manual.sh, hoy `1.8.1`) ES el versionado del fork.
Bump semver: MAJOR.MINOR.PATCH — patch para fixes de build/compat, minor para cambios de
comportamiento/optimizaciones, major para cambios estructurales. Bump → renombrar
`/usr/src/rtl8192eu-<old>` → `/usr/src/rtl8192eu-<new>` + `dkms remove/add/build/install --force`.

### CHANGELOG
| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.8.1 | 2026-09-29 | **Fix de carga: `CONFIG_TXPWR_LIMIT`/`_EN` revertidos a `n`** — con `y` el driver reventaba el kernel en el `modprobe`: `strlen()` sobre `regd_name[0]` (array de tamaño cero) con `ent` salido de `LIST_CONTAINOR` hace que FORTIFY calcule tamaño de destino 0 y llame a `__fortify_panic` (panic deliberado). La reserva es correcta (`+ nlen + 1` y `_rtw_zvmalloc` hace `memset(0)`), no hay desbordamiento real: el fallo es la relectura. Causa completa, traza y gemelo que no revienta en `docs/BUGS.md` (BUG-TXPOWER-001). `n` es el default de fábrica del árbol upstream. Además: **checkpatch pasa a opt-in en el CI** (7.329 hallazgos de estilo, ~13 min y 140 MB de `linux-source` por push; `sparse`+`smatch` siguen obligatorios) y el watchdog de TX power se desinstala de la máquina (`wn8200nd-txpower disable`: unit de usuario y drop-in de sudoers eliminados) |
| 1.8.0 | 2026-09-28 | **Silencio en runtime + throughput**: `CONFIG_RTW_DEBUG=n` (fuera el 74% de líneas `RTW:`) y `CONFIG_PROC_DEBUG=n` (cierra la única vía de escritura de `dm->debug_components`); `monitoring/` eliminado y job de Hermes dado de baja; herramientas de antena migradas a `iw dev ... station dump`; TX power al objetivo del efuse (watchdog retirado, región US intacta); `CONFIG_TXPWR_LIMIT`/`_EN`/`BY_RATE_EN` activos (los dos primeros revertidos al día siguiente, ver 1.8.1); `rtw_usb_rxagg_mode=1` + GRO + NAPI; comentarios falsos corregidos; CI con sparse+smatch+checkpatch contra baseline, build `debian:trixie` 6.12 y aserciones de config; `docs/USB-LINK-HANG.md`. Incluye el fix de build de GRO: restaurada la etiqueta `next:` de `napi_recv()` (`recv_linux.c`), que el commit `5507d47` borró para callar `-Wunused-label`; al activar GRO el `goto` quedaba sin destino y el driver no compilaba (restaurada tal cual `clnhub/rtl8192eu-linux`, rama `5.11.2.3`) |
| 1.7.0 | 2026-08-22 | **Bitrate/senal visible en NetworkManager y KDE plasma-nm**: `.dump_station` registrado en cfg80211_ops con rama cliente (delega en `get_station`, llena `TX_BITRATE`); el dump de NM (`NLM_F_DUMP`) devolvía vacío porque la función original solo recorre estaciones asociadas (rol AP). Tasas **dinámicas** reales (RA del firmware vía C2H + RX por paquete con `rtw_desc_rate_to_bitrate`), no el techo negociado; también en wext (`rtw_wx_get_rate`). **Pentest**: `CONFIG_WIFI_MONITOR=y` por defecto y fix de inyección — `rtw_monitor_xmit_entry` rechazaba cualquier radiotap cuyo largo no fuera exactamente 12 (aircrack-ng/hcxdumptool/mdk4 emiten otros largos = "no injection"); ahora acepta headers bien formados y respeta el flag FCS |
| 1.6.4 | 2026-08-22 | CI reparado y en verde: workflow activado (pull_request + sanity + build con KVER autodetectado); fix modpost (`hal_phy.o` incondicional, `CONFIG_PSD_TOOL=y`); aserciones AP con símbolos reales; artefacto se sube antes del clean |
| 1.6.3 | 2026-08-22 | HT40 reactivado (0x20→0x21); **fix use-after-free** del work de URB stall (`cancel_work_sync` en disconnect); contador propio de stalls USB; orden EPIPE/escalado corregido; `make clean` arreglado; 10 ficheros clon (Windows) eliminados; 1 MB menos de fuente compilada; skills obligatorias; `docs/AUDIT.md` |
| 1.6.2 | 2026-08-13 | CONFIG_AP_MODE=y habilitado (softAP/hostapd en wn8200nd); bump DKMS 1.6.2; CI build-check en GitHub (matriz kernels) |
| 1.6.1 | 2026-08-08 | fix set_monitor_channel kernel 6.12.101+ (netdev arg, backport Debian de 6.13); -O2, rxgain 4→0, HT20 (6324f01, c312b04) |
| 1.6 | 2026-07-30 | duplicado: baseline del fork original rtl8192eu (rama 5.11.2.3) + parches 1T1R/EDCCA/EPIPE/MAX_IO_ERR |

## Repo
- Remote: `MoriNo23/rtl8192eu-wn8200nd-driver` (privado)
- Branch: `main` (única, default)
- Fork del repo original `rtl8192eu-wn8200nd-driver`, rama `5.11.2.3`
- Adaptador: TL-WN8200ND(UN) V3.0 (chipset RTL8192EU) — DVD oficial es V2.0

## Arquitectura
Sistema target: netbook ~2009, Intel Sandy Bridge, RAM limitada.
Driver WiFi USB: TL-WN8200ND(UN) V3.0 (RTL8192EU). DVD oficial V2.0.

## Build Flags Especiales (driver/Makefile)
| Flag | Valor | Razón |
|------|-------|-------|
| `-O2` | habilitado | Estándar Realtek, código más chico (mejor caché en CPU vieja). Antes -O3 (2026-08-08) |
| `CONFIG_RTW_DEBUG` | **n** (1.8.0; era y) | Sin logging en runtime. `RTW_INFO`/`RTW_WARN`/`RTW_DBG` son no-ops y el parámetro `rtw_drv_log_level` desaparece. Coste asumido: los parches propios ya no se ven en dmesg |
| `CONFIG_PROC_DEBUG` | **n** (1.8.0; era y) | Sin `/proc/net/rtl8192eu/`. Cierra además la única vía de escritura de `dm->debug_components`, así que el debug de phydm queda **inalcanzable**, no solo silenciado |
| `CONFIG_RTW_NAPI_DYNAMIC` | sí | Desactiva NAPI en bajo throughput (<100 Mbps) |
| `CONFIG_RTW_GRO` | **y** (1.8.0; era n) | Coalescencia de tramas. La premisa de que estaba apagado ("sin buffering por `rxagg_mode=0`") era falsa |
| `CONFIG_TXPWR_LIMIT` / `_EN` | **n** (revertido en 1.8.1; en 1.8.0 se puso `y`) | Con `y` el módulo **no carga**: kernel panic por FORTIFY en `rtw_txpwr_lmt_add_with_nlen` al hacer `strlen()` sobre `regd_name[0]` (`hal_data.h:345`) con `ent` salido de `LIST_CONTAINOR`. No es un desbordamiento real — la reserva es correcta — pero el compilador calcula tamaño 0 y `__fortify_panic` es deliberado. Ver `docs/BUGS.md` (BUG-TXPOWER-001). Con `n`, `lmt`/`ulmt` salen `NA`: sin límites regulatorios, que es el default de fábrica del árbol upstream. **No reactivar sin cerrar BUG-TXPOWER-001** |
| `CONFIG_TXPWR_BY_RATE_EN` | **y** (1.8.0; era n) | Escalado de potencia por tasa (menos potencia en MCS alto) |
| `CONFIG_PSD_TOOL` | y | **No se toca**: el macro vive en `phydm_features_iot.h:147`; apagarlo desde aquí rompe el enlazado. Ver design.md D2 |
| `CONFIG_AP_MODE` | y | softAP/hostapd (desde 1.6.2; Evil Twin/KARMA) |
| `CONFIG_WIFI_MONITOR` | y | Monitor + inyección pentest (desde 1.7.0; antes n) |
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
Defaults en `driver/os_dep/linux/os_intfs.c`. Los valores **efectivos** salen de
`/etc/modprobe.d/*.conf`, que gana en el `modprobe`.

- `rtw_en_gro = 1` (1.8.0; era 0) — coalescencia de tramas. Solo opera si NAPI
  está activo: con `en_napi==0` el propio driver pone `en_gro=0` (`os_intfs.c:1499`).
- `rtw_en_napi = 0` — NAPI desactivado por defecto en el source. En el despliegue
  se pone a 1 desde `8192eu.conf` (ver tabla de parámetros runtime).
- `rtw_usb_rxagg_mode = 1` (1.8.0; era 0) — RX_AGG_DMA con umbral del driver.
  ⚠️ Un valor distinto de 1 y 2 es **sustituido en silencio** por DMA
  (`usb_halinit.c:115-116`), y el modo disable es inalcanzable. Ver design.md D5.
- `rtw_dynamic_agg_enable = 0` — agregación dinámica de TX desactivada

## MIMO
- `rtw_trx_path_bmp=0x11` — **1T1R forzado (solo antena A/path 0)** — ver parche abajo
- `rtw_antdiv_cfg=1` — antenna diversity forzada
- **Hardware fisico (2026-08-22)**: antena dentro de cantenna direccional artesanal
  (lata de Pringles con agujero) apuntando al router. Enlace direccional hecho a mano:
  por eso 1T1R+rxgain=0 rinde; no es una omni deficiente.

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
- `MAX_CONTINUAL_IO_ERR=80` (era 10→30→80, evita surprise_removed en channel switch).
  ⚠️ El valor se elige por la **ventana temporal** del cambio de canal (200-500 ms de
  silencio de radio ⇒ ~800 ms de tolerancia). La justificación original en el comentario
  del fuente ("con `rtw_usb_rxagg_mode=0` no hay buffering") era **falsa** y se corrigió
  el 2026-09-28; el umbral **se conserva** (revertirlo sería un cambio de comportamiento
  sin evidencia). Ver design.md D5 y el comentario en `driver/include/rtw_io.h`.
- `MAX_USB_STALL_ERR=200` (2026-08-22) — contador propio para `-EPIPE`/`-EPROTO`. Antes se
  reseteaba el contador general de forma incondicional y un endpoint permanentemente colgado
  nunca escalaba: interfaz muerta en silencio.
- USB autosuspend desactivado (`rtw_enusbss=0`)

### URB stall recovery (`usb_ops_linux.c:20-130`)
Recuperación de `-EPIPE` con `usb_clear_halt()` en workqueue (no se puede llamar desde el
callback URB, duerme). Piezas obligatorias — **no tocar sin leer esto**:
- `rtw_usb_ep_reset_work_init()` en probe (`usb_intf.c`)
- **`rtw_usb_ep_reset_work_deinit()` al principio de `rtw_dev_remove()`** — sin el
  `cancel_work_sync` el worker despierta sobre un adapter liberado (use-after-free).
- `rtw_ep_reset_pending` (atomic): un solo work encolado a la vez; sin él dos URBs en stall
  se pisan el `recv_buf` y se pierde un buffer de RX.
- El worker aborta si `surprise_removed` o `drv_stopped`.


### EDCCA / Adaptivity

### Parámetros runtime (en /etc/modprobe.d/8192eu.conf)
| Parámetro | Valor | Efecto |
|-----------|-------|--------|
| `rtw_adaptivity_th_l2h_ini` | 15 | Threshold L2H inicial |
| `rtw_adaptivity_th_edcca_hl_diff` | 5 | Diferencia H-L EDCCA |
| `rtw_rxgain_offset_2g` | 0 | Sin atenuación LNA (2026-08-08: era 4; con señal débil atenuar empeora sensibilidad — medido +19 dB y 3.2x throughput) |
| `rtw_notch_filter` | 1 | Filtro notch |
| `rtw_smart_ps` | 0 | Sin ahorro energía |
| `rtw_usb_rxagg_mode` | 1 | **Agregación de RX USB = RX_AGG_DMA con umbral del driver** (`size=8` kB, `timeout=8`×32 µs). ⚠️ Antes era `0` con el comentario "0:disable (estabilidad USB)", lo cual era **falso**: `usb_halinit.c:115-116` sustituye por `RX_AGG_DMA` todo valor que no sea DMA ni USB, y a continuación (línea 123-125) le asigna el umbral. `0` y `1` dan un estado **bit a bit idéntico**; el modo disable es **inalcanzable** por este parámetro. Ver design.md D5 |
| `rtw_en_napi` | 1 (desde 1.8.0) | Entrega coalescente de tramas. Era `0`; la premisa que lo justificaba ("sin buffering por `rxagg_mode=0`") era falsa |
| `rtw_bw_mode` | 0x21 | HT40 **configurado** en 2.4G (bit 0-3 = 2.4G, bit 4-7 = 5G; default del source `os_intfs.c:246` ya es 0x21). ⚠️ **Configurado no es negociado**: 40 MHz solo se negocia si el AP lo anuncia **y** está en un canal primario válido. El AP `escama` está en **canal 3**, que en 2.4 GHz no es un canal primario HT40 válido, así que con este AP el enlace se queda en **20 MHz** por muy bien que el parámetro valga 0x21. Para negociar 40 MHz hay que (a) mover el AP a canal 1, 5, 9 o 11 y (b) que anuncie HT40+ — cambio de canal que vive en el repo `MoriNo23/escama-ap`, fuera de este |

**Regla de lectura de esta tabla:** un parámetro escrito en `8192eu.conf` no
garantiza por sí solo el efecto que su nombre sugiere. Para el ancho de banda hay
que mirar `iw dev wn8200nd info` (HT20/HT40 negociado) y para la potencia
`iw dev wn8200nd info` (txpower), no el fichero de modprobe.

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

## EDCCA: qué se puede mirar y cómo (sin debug en runtime)

El debug de phydm (`dbg 13 1` = `DBG_ADPTVTY`, bit 13) **ya no es alcanzable**:
`rtw_odm_proc_write()` (`driver/os_dep/linux/rtw_proc.c`) es el **único**
escritor de `dm->debug_components`, y con `CONFIG_PROC_DEBUG=n` ese fichero no
se compila. No hay sustituto: ni parámetro de módulo, ni ioctl, ni comando de
vendor.

`DBG 1` sigue en `driver/include/autoconf.h:274` a propósito, así que
`phydm_debug.c` **se sigue compilando y enlazando** (apagar `DBG` lo vaciaría y
reproduciría el fallo de modpost de `phydm_psd.o`). Los macros `PHYDM_DBG` no
dependen de `CONFIG_RTW_DEBUG`: se gobiernan en runtime por el bitmask, que
ahora está permanentemente en 0. Compilado, inalcanzable, inerte.

Lo que sí se puede observar del estado EDCCA, sin depuración:

- **Valores de config** (los que importan): están en
  `/etc/modprobe.d/8192eu.conf` y en `/sys/module/8192eu/parameters/`
  (lectura). Ver la tabla de «Parámetros runtime».
- **Comportamiento observable**: desensibilización por ruido vecinal se manifiesta
  como **caída de throughput sin caída de señal** mientras `rtw_rxgain_offset_2g`
  está en 0. Esa es la firma a buscar cuando «el enlace va bien pero va lento».

⚠️ La trampa de siempre: **escribir a `/sys/module/8192eu/parameters/` NO
propaga a `registry_priv` ni a `dm->edcca_mode`.** Son variables separadas; el
`module_param` se copia a `registry_priv` solo en el init del módulo. El único
modo que funciona es editar `8192eu.conf` y recargar.

## Invariantes del despliegue — NO TOCAR

Estas cosas se dio por suppressa y romperlas degrada la máquina en silencio.
Cada una tiene una aserción en el CI salvo donde se indica.

| Invariante | Valor / regla | Por qué |
|---|---|---|
| **Región regulatoria** | `US: DFS-FCC`, **de la red**, no de nosotros. **Nunca** `iw reg set`, **nunca** `rtw_country_code`, **nunca** tocar `cfg80211` domain. | Viene del country IE del AP. Forzar un código de país a mano desincroniza el dominio del mundo real y es ilegal. La aserción del CI solo verifica que **no exista** ninguna orden de `reg set` en el repo ni en `/etc`. |
| **Agregación de RX USB** | `rtw_usb_rxagg_mode=1` (RX_AGG_DMA con umbral del driver). **Los valores ≠1 y ≠2 se sustituyen en silencio** por DMA. | El modo disable es inalcanzable por este parámetro. Aserción de CI anti-sustitución (tarea 1.6). |
| **Objetivo de TX power** | El del **efuse** (2.4G ruta A: CCK 16 / OFDM 14 / HT 13 dBm). **Ningún proceso** mantiene potencia fija. | El watchdog que forzaba 20 dBm se retiró (1.8.0 del repo); el unit de usuario `wn8200nd-txpower.service` se desinstaló de la máquina el 2026-09-29 con `wn8200nd-txpower disable`, que además borró su drop-in de sudoers. `CONFIG_TXPWR_LIMIT=n` desde 1.8.1: **no** hay recorte contra el regdomain (`lmt`/`ulmt` = `NA`). Aserción de CI: ninguna unidad systemd ni script llama a `set txpower fixed`. |
| **1T1R forzado** | `rtw_trx_path_bmp=0x11`. Revertir a `0x33` **solo** cuando se resuelda el conector de la antena B. | Conector B desoldado. Con 2×2 el driver depende de la path muerta. |
| **El dongle es la WAN de `escama`** | `AP_IFACE=stonepi` (Intel interno), `WAN_IFACE=wn8200nd`. | Un flapeo del dongle corta internet a **todos** los clientes del AP, no solo a esta máquina. Primera pregunta cuando se investigue un corte de red en casa. Ver `docs/USB-LINK-HANG.md`. |
| **Canal 3 = HT20** | `rtw_bw_mode=0x21` está configurado pero el AP está en canal 3, que **no** es canal primario HT40 válido ⇒ el enlace se queda en **20 MHz**. | Configurado ≠ negociado. Mover el canal del AP a 1/5/9/11 es change aparte, en el repo `escama-ap`. |
| **`CONFIG_PSD_TOOL=y`** aunque no se use | El macro vive en `phydm_features_iot.h:147`; apagarlo desde el Makefile rompe el enlazado. | Dualidad conocida. El CI comprueba que `phydm_psd.o` **sí** se compila. Ver el comentario en `driver/Makefile:68`. |
| **`DBG 1`** | Se mantiene a propósito. | `phydm_debug.c` está entero dentro de `#if DBG`; `DBG 0` lo deja vacío y reintroduce el fallo de modpost. Inerte en runtime porque el bitmask no tiene escritor. |

## DKMS
- **dkms instalado** (3.2.2) y driver **registrado**: `rtl8192eu/1.8.0` (AUTOINSTALL=yes)
- Source DKMS: `/usr/src/rtl8192eu-1.8.0/` — **sync del repo parcheado**, y lo hace
  `install_manual.sh` solo (step 3a, `rsync -a --delete`); ya no hace falta el rsync a mano.
  El directorio de la versión anterior (`/usr/src/rtl8192eu-1.7.0/`) se puede borrar
  cuando el `dkms status` ya solo muestra 1.8.0.
- **Kernel updates: regeneración AUTOMÁTICA** con los parches (1T1R + EDCCA + EPIPE). El .ko de DKMS
  (`updates/dkms/8192eu.ko.xz`) tiene PRIORIDAD sobre el manual.
- Instalación/actualización (ÚNICO script, v4): `sudo ./install_manual.sh` — sync source
  parcheado a /usr/src + `dkms add/build/install --force` (vía manual solo si dkms no está),
  instala `scripts/reload-wn8200nd-1ant` en ~/.local/bin del usuario, recarga el módulo y
  **SIEMPRE reinicia NetworkManager al final** (`systemctl restart NetworkManager`) —
  NM no reconecta solo tras recargar el módulo. Fallback: `nmcli device connect wn8200nd`.
  (wifi_manager.sh eliminado 2026-08-22: redundante.)
- Script de recarga: versionado en `scripts/reload-wn8200nd-1ant`, instalado a
  `~/.local/bin/reload-wn8200nd-1ant` por install_manual.sh
- Parámetros configurables: `/etc/modprobe.d/8192eu.conf` (EDCCA) + `/etc/modprobe.d/rtl8192eu.conf` (paths/1T1R)

## Verificación — **TODO va por GitHub Actions, nada en local**

**No compiles ni analices estáticamente el árbol en la máquina de desarrollo.**
Ni `make`, ni `sparse`, ni `smatch`, ni `checkpatch`. Push al repo y mira el
resultado. Esta regla no es una preferencia de estilo: la máquina de desarrollo
es la de uso diario del usuario, y compilar este driver contra los headers del
kernel local tarda lo suficiente como para que acabe corriéndose en segundo
plano, produciendo un `.ko` rancio que se instala sin haber pasado por el CI.

### El flujo

1. Editas el árbol.
2. `git commit` y `git push` (o abres PR contra `main`).
3. El workflow `CI — build check` corre:
   - `sanity` — comprobaciones de árbol, sin compilar. Falla pronto.
   - `build` — compila contra los headers del runner (compatibilidad hacia delante).
   - `build-debian` — compila en `debian:trixie` contra **headers 6.12**, que es
     el kernel del despliegue real.
   - `static-analysis` — sparse + smatch + checkpatch contra un baseline versionado.
   - `config-assertions` — la configuración distribuida es la esperada.
   - `vm-load-test` — carga y descarga REALES del módulo en una VM (QEMU, kernel
     6.12 del despliegue): ciclo `insmod`/`rmmod`, `dmesg` capturado, y cero
     líneas `RTW:`. ⚠️ **Un contenedor no puede hacer esto**: comparte el kernel
     del host, así que `insmod` desde un contenedor carga el módulo en la máquina
     (verificado: el módulo aparece en el `/proc/modules` del host). Ver
     `ci/vm/README.md`.
   - `bt-toggle` — el interruptor de Bluetooth sigue compilando.
4. Todo en verde, y solo entonces instalas en la máquina.

### Por qué el CI y no el local

- Compila contra **dos** familias de kernel: los headers de Ubuntu del runner y
  los headers 6.12 de Debian en contenedor. Un `vermagic` o un `__attribute__`
  que solo exista en una de las dos pasaría el local y rompe en la máquina.
- El `static-analysis` compara contra un **baseline** versionado, así que no está
  rojo de salida: solo falla ante hallazgos **nuevos**. El baseline se genera
  desde el propio CI con `ci/static-analysis.sh <tool> --update-baseline`.

### Lo único que sí se hace en local

- Editar ficheros. `git`. El reinicio de NetworkManager.
- **Medir en hardware** (throughput, señal, estabilidad): eso solo existe en la
  máquina y es la única verificación que el CI no puede hacer por ti.
- `sudo ./install_manual.sh` — que compila e instala. Es **deployment**, no
  verificación: se hace después de que el CI haya pasado, nunca en su lugar.

### Las skills de análisis, excepción consciente

Las herramientas que el repo prescribe para investigar (`cscope`, Coccinelle,
`bloat-o-meter`, las de las skills de análisis estático) se siguen usando en local
cuando la tarea **es** analizar o medir, porque no existen como job de CI. La
regla de arriba va sobre la *verificación de cambios del driver*, no sobre las
herramientas de investigación.

## Testing con el adaptador — regla obligatoria

Cualquier script o comando de prueba (agente IA o humano) que ponga `wn8200nd` en
modo monitor, cambie canales o detenga NetworkManager/wpa_supplicant **DEBE, como
último paso después de su salida final**, devolver el equipo a estado usable:

```bash
sudo ip link set wn8200nd down
sudo iw dev wn8200nd set type managed
sudo ip link set wn8200nd up
sudo systemctl restart NetworkManager
# verificar: ip -4 addr show wn8200nd debe tener IP
```

Sin excepciones: el usuario sigue usando la máquina entre pruebas. Si un test
falla a mitad de camino, la restauración corre IGUAL (usar `;` en vez de `&&`
en la parte de limpieza, nunca dejar la interfaz en monitor).

## Diagnóstico sin debug en runtime

Desde 1.8.0 el driver es **silencioso en runtime**: `CONFIG_RTW_DEBUG=n` y
`CONFIG_PROC_DEBUG=n`. No hay logging periódico, no hay `/proc/net/rtl8192eu/`,
y no existe ninguna vía (fichero, parámetro de módulo, ioctl o comando de
vendor) para activar el bitmask de debug de la capa PHY en caliente.

Eso tiene un coste: **no se puede depurar en vivo**. Se asume a cambio de no
pagar 2.908 líneas `RTW:` en cada arranque. Lo que queda es:

| Para diagnosticar | Usar |
|---|---|
| ¿Es un fallo del enlace USB o del driver? | `docs/USB-LINK-HANG.md` — señales del log del núcleo, y por qué ningún parche puede alcanzar ese fallo |
| ¿El driver compiló y enlazó? | Las aserciones de CI (`sanity`, `build`, `build-debian`, `config-assertions`) |
| ¿El driver cargó en esta máquina? | `lsmod \| grep 8192eu`, `dmesg \| grep -i 8192eu` (errores del core, no del driver) |
| ¿Cuál es la señal / el ancho negociado? | `wn8200nd-antenna --once`, `iw dev wn8200nd info` |
| ¿Qué parámetro afecta a la sensibilidad? | `docs/RF-SENSITIVITY.md` |

El criterio de clasificación: si el dispositivo **no** aparece en `lsusb`, es
el enlace USB y no hay nada que el driver pueda hacer. Si aparece pero no carga
el módulo, es del driver, y el CI dice por qué.

### Lo que se eliminó y por qué (2026-09-28)

- `monitoring/rx_drop_watchdog.sh` + su CSV, y el job de Hermes
  `rx-drop-watchdog` (id `1db902a53a75`, dado de baja). **La monitorización nunca
  se ejecutó**: cero `rx_drop_monitor_*.csv` en el repo y la tabla `executions`
  del cron vacía. Se pagaba ruido en cada arranque a cambio de nada.
- `monitoring/dig_fa_watchdog.sh`: muestreaba `fa_cnt` del DIG, pero su única vía
  de datos era `odm/cmd` y `/proc/net/rtl8192eu/`, que desaparece con
  `PROC_DEBUG=n`. Sin fuente, sin script.
- El paso 7 de `scripts/reload-wn8200nd-1ant` (`dbg 13 1`) **reactiva el debug de
  adaptividad en cada recarga del módulo**. Eliminado: un script de recarga no
  debe dejar superficie de depuración activa.

## Parámetros Runtime Ajustables
```
rtw_adaptivity_th_l2h_ini      # threshold L2H adaptivity (default 0)
rtw_adaptivity_th_edcca_hl_diff  # diff H-L EDCCA (default 0, override->7 si 0)
rtw_rxgain_offset_2g             # ganancia LNA en 2.4GHz (default 0, medido: 4 empeora)
rtw_notch_filter                 # filtro notch (default 0, nuestro 1)
rtw_smart_ps                     # PS inteligente (default 2, nuestro 0)
rtw_napi_threshold               # Mbps threshold para dynamic NAPI (default 100)
rtw_ampdu_factor                 # AMPDU aggregation (default 7)
rtw_hiq_filter                   # filtro desbalance IQ (default 1, NO medido)
```

Ver `docs/RF-SENSITIVITY.md` para la tabla completa de parámetros de ganancia y
filtrado de recepción, con su coste en sensibilidad y su procedimiento de A/B.
