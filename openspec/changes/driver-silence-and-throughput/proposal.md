# Proposal

## Why

El driver acumula tres problemas que se refuerzan entre sí, todos medidos sobre la
máquina real el 2026-09-28:

1. **Ruido sin consumidor.** En un arranque normal, 2.908 de 3.929 líneas del kernel
   son `RTW:`. De ellas, 220 las genera el poll de 10 s del watchdog
   `wn8200nd-txpower`. La monitorización que justifica ese ruido **nunca se ejecutó**:
   `monitoring/` contiene un único CSV con una fila (2026-08-22), cero
   `rx_drop_monitor_*.csv` en su historia, y la tabla `executions` del cron de Hermes
   está vacía. Se paga ruido en cada arranque a cambio de nada.
2. **El propio driver empeora el rendimiento.** El watchdog fuerza 20 dBm fijos en
   todas las tasas (el objetivo del driver es CCK 16 / OFDM 14 / HT 13), con el límite
   regulatorio sin calcular (`CONFIG_TXPWR_LIMIT=n` → `lmt`/`ulmt` = `NA`) y sin
   escalado por tasa (`CONFIG_TXPWR_BY_RATE_EN=n`). A la vez NAPI y GRO están
   apagados y el valor `rtw_usb_rxagg_mode=0` no hace lo que su comentario dice.
   Resultado medido: **uplink 65,0 Mbps (el techo de 1T1R+HT20) contra downlink
   13,0 Mbps a -58 dBm**, con un SNR reportado de 30 dB que no corresponde a MCS4.
3. **La verificación se hace en local, no en CI.** `build.yml` solo tiene
   `sanity`, `build` (2 matrices) y `bt-toggle`. No hay sparse, smatch ni checkpatch,
   aunque las skills del repo los prescriben como estado inicial.

Además, el repositorio describe comportamiento que el código no tiene: la
agregación USB **sí** está activa (el `0` se coacciona a `RX_AGG_DMA` en
`usb_halinit.c:115-116`), y `rtw_bw_mode=0x21` (HT40) es **inerte** porque el AP
está en canal 3, que no es primo HT40 válido.

Y hay un cuarto problema, más estructural que los otros tres: **lo que el change
cambia no se puede probar con las herramientas a mano.** Un contenedor comparte el
kernel del host, así que cargar el `.ko` desde un contenedor lo carga en la máquina
— sobre el adaptador que da la WAN del AP. Sin una VM, la carga y la descarga del
módulo quedan como pasos manuales sin red de seguridad, y este change tocó justo la
inicialización del driver (tres flags de compilación y un parámetro). Por eso el
banco de pruebas de la sección 3 es una VM y no un contenedor, aunque compilar siga
siendo en contenedor: son cosas distintas.

Contexto de uso que condiciona las decisiones: barrio denso (4 paredes entre
 routers, casas pegadas, 15 APs visibles en 2.4G), prioridad **velocidad /
estabilidad / descarga**, y **región que se queda como está: US**. El regdomain
`US: DFS-FCC` limita a canales 1-11 con 30 dBm, así que los +7 dB del watchdog no
son una infracción regulatoria, pero sí son potencia y corriente de más sin
beneficio medible.

## What Changes

### 1. Silenciar el driver en runtime

- `CONFIG_RTW_DEBUG = n` — elimina `RTW_INFO` / `RTW_WARN` / `RTW_DBG` (el 74% de las
  líneas del kernel) y el parámetro `rtw_drv_log_level`.
- `CONFIG_PROC_DEBUG = n` — elimina el árbol `/proc/net/rtl8192eu/`. Esto es lo que
  además cierra la vía de activación: `rtw_odm_proc_write()` es el único escritor
  del bitmask `dm->debug_components`, así que sin procfs el debug de phydm queda
  inalcanzable en runtime aunque siga compilado.
- `CONFIG_PSD_TOOL = n` — con el tratamiento del fallo de modpost que ya está
  documentado para `hal_phy.o`.
- Quitar el paso 7 (`dbg 13 1` / DBG_ADPTVTY) de `scripts/reload-wn8200nd-1ant`,
  que hoy reactiva el debug de adaptividad **en cada recarga del módulo**.
- Eliminar `monitoring/` (los dos watchdogs, el CSV huérfano) y dar de baja el job
  de Hermes `rx-drop-watchdog`.
- Migrar `antena-guira` y `wn8200nd-antenna` fuera de `rx_signal` de procfs, porque
  se quedan sin su fuente de datos.

### 2. Dejar de degradar el rendimiento por configuración propia

- Retirar el watchdog de TX power fija: el objetivo vuelve al efuse del dongle
  (16/14/13 dBm) y desaparece el `dbg 13` implícito. **No se toca la región.**
- `CONFIG_TXPWR_LIMIT = y` / `CONFIG_TXPWR_LIMIT_EN = y`: el driver calcula el límite
  del regdomain en vez de emitir `NA`. Bajo US es no-op a 13 dBm, pero hace seguro el
  resto del sistema.
- `CONFIG_TXPWR_BY_RATE_EN = y`: escalado por tasa (menos potencia en MCS alto).
- `rtw_usb_rxagg_mode = 1`: la agregación DMA queda con umbral definido por el driver
  en vez del umbral por defecto del firmware, que es lo que realmente ocurre hoy.
- Reactivar NAPI (`rtw_en_napi = 1`) y GRO (`CONFIG_RTW_GRO = y`) — el mayor ahorro de
  CPU y el mayor techo de throughput de la lista, ahora que se sabe que la
  agregación nunca estuvo desactivada y que la premisa de los parches USB previos
  era falsa.
- Corregir los comentarios y la documentación que describen lo contrario de lo que
  hace el código: `rtw_io.h` (`MAX_CONTINUAL_IO_ERR`), `rtw_mlme_ext.c` (guard de
  `WIFI_UNDER_SURVEY`), `os_intfs.c` (defaults de agregación) y `AGENTS.md`.

### 3. Mover toda la verificación al CI de GitHub

- Job nuevo de análisis estático (sparse, smatch, checkpatch) con **baseline**: falla
  por regresión, no por el ruido heredado de un árbol de vendor.
- Job de compilación contra headers de Debian 6.12 en contenedor, que es el kernel
  target real; hoy el CI solo compila contra headers de Ubuntu.
- Job de **carga y descarga reales del módulo en una VM** (QEMU, kernel 6.12): ciclo
  `insmod`/`rmmod`, `dmesg` capturado, y ausencia de líneas `RTW:`. Es la única forma
  de comprobar en aislamiento lo que este change cambia de verdad, porque un
  contenedor **no** puede hacerlo: comparte el kernel del host, así que `insmod`
  desde un contenedor carga el módulo en la máquina. Verificado empíricamente.
- Regla en `AGENTS.md`: ninguna compilación ni análisis estático en local. Push → CI.

### 4. Documentar lo que no se puede arreglar en software

- El flapeo USB (`disabled by hub (EMI?)` → desconexión → re-enumeración) es
  **hardware**: el core de USB mata el dispositivo antes del probe, así que ningún
  parche del driver puede alcanzarlo. Queda documentado con la evidencia de los tres
  boots, el procedimiento de recuperación y el experimento de puerto directo.
- Nota de acoplamiento: el dongle es la **WAN del AP `escama`**, así que un flapeo
  suyo corta internet a todos los clientes del AP, no solo a esta máquina.

### Fuera de alcance

- El cambio de canal del AP `escama` (excluir el canal de la WAN y elegir el menos
  concurrido) es un change separado en el repo `MoriNo23/escama-ap`, que no usa
  OpenSpec. Aquí solo se deja constancia del acoplamiento.
- El diagnóstico USB de hardware (puerto de root directo, limpieza de conector) es
  una prueba manual, no código.

## Capabilities

### New Capabilities

- `driver-runtime-silence`: el driver no debe emitir logging periódico en runtime ni
  exponer superficie de monitorización (debug, procfs, scripts y jobs asociados).
- `rf-throughput-tuning`: los defaults y la configuración efectiva del driver no
  deben degradar por sí mismos el throughput ni la estabilidad de RF.
- `ci-verification`: toda verificación de compilación y análisis estático del driver
  debe ejecutarse en GitHub Actions, no en la máquina del desarrollador.

### Modified Capabilities

Ninguna. `openspec/specs/` está vacío; las tres capacidades son nuevas.

## Impact

**Código del driver**

- `driver/Makefile`: `CONFIG_RTW_DEBUG`, `CONFIG_PROC_DEBUG`, `CONFIG_PSD_TOOL`,
  `CONFIG_TXPWR_LIMIT`, `CONFIG_TXPWR_LIMIT_EN`, `CONFIG_TXPWR_BY_RATE_EN`,
  `CONFIG_RTW_GRO`.
- `driver/include/autoconf.h`: `DBG 1` se mantiene a propósito (ver design.md) — se
  documenta por qué no se toca.
- `driver/os_dep/linux/os_intfs.c`: defaults de agregación y comentarios.
- `driver/os_dep/linux/rtw_proc.c`: queda fuera del build con `PROC_DEBUG=n`.
- `driver/include/rtw_io.h`, `driver/core/rtw_mlme_ext.c`: comentarios correctos.
- `driver/hal/rtl8192e/usb/usb_halinit.c`: sin cambios de lógica; se documenta el
  coaccionamiento `0 → RX_AGG_DMA`.

**Fuera de `driver/`**

- `/etc/modprobe.d/8192eu.conf`: `rtw_en_napi`, `rtw_usb_rxagg_mode`.
- `scripts/reload-wn8200nd-1ant`: se elimina el paso 7.
- `monitoring/`: se elimina el directorio.
- `~/.config/systemd/user/wn8200nd-txpower.service`: se deshabilita y se restaura TX
  power automático.
- `~/.local/bin/antena-guira`, `~/.local/bin/wn8200nd-antenna`: dejan de leer procfs.
- Job de Hermes `rx-drop-watchdog`: baja.
- `.github/workflows/build.yml`: dos jobs nuevos.
- `AGENTS.md`, `docs/`, `README.md`: corregidos.
- `dkms.conf` / `install_manual.sh`: bump 1.7.0 → 1.8.0 (**minor**: cambia
  comportamiento observable) y renombrado de `/usr/src/rtl8192eu-1.7.0`.

**Riesgo asumido**

- Reactivar NAPI/GRO y el escalado por tasa son cambios de comportamiento que solo
  se pueden validar en hardware, y el flapeo USB activo añade ruido a la medición.
  Cada uno lleva tarea de A/B con reversión explícita.
- Apagar `PROC_DEBUG` deja sin datos a las dos herramientas de antena; por eso la
  migración va en el mismo change y no después.
