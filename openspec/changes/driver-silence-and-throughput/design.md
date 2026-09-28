# Design

## Context

Cinco restricciones no obvias condicionan cualquier decisión de este change. Ver
`proposal.md` para la motivación.

**Restricción 1 — la superficie de depuración de phydm tiene dos fuentes de verdad.**
`CONFIG_PSD_TOOL` se declara en `driver/hal/phydm/phydm_features_iot.h:147` (una
`#define` sin valor, no se puede apagar desde el Makefile) y además existe como
variable de make en `driver/Makefile:71`. El fix del 2026-08-22 tuvo que poner la
variable a `y` precisamente por esa dualidad: apagarla desde el Makefile vaciaba
`phydm_psd.o` mientras `phydm.h` seguía viendo el macro del header y `phydm.c:1779`
seguía llamando a `phydm_psd_init()` → símbolos indefinidos en el enlace.

**Restricción 2 — `DBG 1` es incondicional y `phydm_debug.c` está entero dentro de
`#if DBG`.** `driver/include/autoconf.h:274` define `DBG 1` sin condición, y
`driver/hal/phydm/phydm_debug.c` envuelve todo su contenido entre `#if DBG` (línea
38) y su `#endif` final. Poner `DBG 0` dejaría un objeto vacío con la misma clase
de fallo de modpost que la Restricción 1. Los macros `PHYDM_DBG` no dependen de
`CONFIG_RTW_DEBUG`: se gobiernan en runtime por el bitmask `dm->debug_components`,
que solo se escribe desde `rtw_odm_proc_write()` en `driver/os_dep/linux/rtw_proc.c:5605`.

**Restricción 3 — el enlace USB que falla nunca llega al driver.** El core de USB
deshabilita el puerto (`disabled by hub (EMI?)`, `hub.c` procesando
`USB_PORT_STAT_C_ENABLE`), fuerza la desconexión y mata el dispositivo antes del
probe. Ningún parche de `driver/` es alcanzable en ese camino. Verificado en los
tres boots disponibles: 8 desconexiones en el boot -2 (con un hueco estable de 28
horas), 3 en el -1 (una precedida de `disabled by hub (EMI?)` a los 5 minutos de
arrancar, sin intervención física) y 5 en el actual (con 4× `error -32` en la
lectura del descriptor).

**Restricción 4 — el dongle es la WAN del AP `escama`.** `escama.env` fija
`AP_IFACE=stonepi` (WiFi interno Intel, `parentdev 0000:02:00.0`) y
`WAN_IFACE=wn8200nd` (el dongle). Un flapeo del dongle corta internet a todos los
clientes del AP, no solo a esta máquina.

**Restricción 5 — cargar el módulo desde un contenedor lo carga en el host, y el
host es la WAN.** Verificado el 2026-09-28: `insmod` dentro de `docker run
--privileged` de un `.ko` de prueba aparece en el `/proc/modules` del host. Un
contenedor comparte el kernel, de modo que probar la carga del driver "en un
contenedor" es, en esta máquina, desplegar el driver sin querer sobre el
adaptador que da internet a la casa. De ahí la decisión D9: el banco de pruebas
de carga va en QEMU, no en un contenedor.

## Goals / Non-Goals

**Goals:**

- Cero logging periódico del driver en runtime, por el motivo que sea.
- Cero superficie de monitorización mantenida: ni scripts, ni tareas, ni parámetros.
- Que la configuración distribuida mejore o preserve el throughput de descarga en el
  enlace de despliegue, sin tocar el dominio regulatorio.
- Que toda verificación —compilación y análisis estático— ocurra en GitHub Actions.
- Que cada cambio de comportamiento venga con su A/B y su reversión.

**Non-Goals:**

- Arreglar el flapeo USB en software. No es alcanzable desde el driver (Restricción 3).
- Cambiar el canal o el ancho del AP `escama`: es change separado en otro repo.
- Cambiar el dominio regulatorio o forzar un código de país.
- Reactivar la antena B ni pasar a 2x2 MIMO.
- Rediseñar los patches de estabilidad USB existentes. Se conservan; lo que se
  corrige es el comentario que justifica `MAX_CONTINUAL_IO_ERR`, no el umbral.

## Decisions

### D1 — Callar el driver con `RTW_DEBUG=n` + `PROC_DEBUG=n`, dejando `DBG 1`

**Elegido:** apagar `CONFIG_RTW_DEBUG` y `CONFIG_PROC_DEBUG`; mantener
`CONFIG_PSD_TOOL` y `DBG` como están.

**Por qué funciona:** `RTW_INFO` / `RTW_WARN` / `RTW_DBG` se convierten en no-ops
(`rtw_debug.h:38-53`) — eso elimina el 74% de las líneas del kernel que se midieron.
Y `PROC_DEBUG=n` elimina `rtw_proc.c` completo, que es **el único escritor** de
`dm->debug_components`. Sin procfs, el bitmask se queda en 0 para siempre y los
macros `PHYDM_DBG` —aunque sigan compilados— no emiten nada. Eso silencia phydm sin
tocar `DBG`.

**Alternativas descartadas:**

- *Poner `DBG 0`.* Elimina el debug de phydm en la raíz, pero vacía
  `phydm_debug.c` entero y reintroduce el fallo de modpost de la Restricción 1.
  Descartado.
- *Bajar solo `rtw_drv_log_level` a runtime.* Dejaría el código compilado y los
  macros expandidos; no reduce nada de forma permanente, y el usuario pidió
  eliminar la superficie, no silenciarla parcialmente.
- *Borrar `RTW_INFO` con Coccinelle.* 457 bloques `#if 0` y 309 usos de
  `sprintf` ya están pendientes en `docs/AUDIT.md`; añadir otra transformación
  masiva ahora compite con esas por el mismo presupuesto de revisión.

### D2 — `CONFIG_PSD_TOOL` se queda; el ruido de PSD es irrelevante

**Elegido:** no tocar `CONFIG_PSD_TOOL`.

**Por qué:** desactivarlo correctamente exige tocar a la vez el header
(`phydm_features_iot.h:147`), la variable de make (`Makefile:71`) y la entrada de
`phydm.mk:241`, con el orden correcto para no romper el enlace. El objeto
`phydm_psd.o` son 15 KB y no emite nada en runtime: la función de medida solo corre
cuando se invoca. El ruido real de este change son las líneas `RTW:` del ciclo de
vida, no 15 KB de código. El coste de esta decisión es una variable de make que
"miente" sobre lo que controla; se corrige **documentando** la dualidad en el
comentario de `Makefile:68-71` y añadiendo una aserción de CI que verifique que
`phydm_psd.o` sí se compila, de modo que nadie la apague a la ligera y rompa el
enlace.

**Alternativa descartada:** apagar PSD de forma completa. Beneficio marginal,
riesgo de enlace alto, y ya sabemos que el precedente intento de apagarlo desde el
Makefile rompió el build.

### D3 — El objetivo de TX power vuelve al efuse y se retira el watchdog

**Elegido:** `sudo wn8200nd-txpower disable` (que además restaura TX power
automático) y documentar el valor resultante (2.4G ruta A: CCK 16, OFDM 14,
HT 13 dBm) como el estado correcto.

**Por qué:** el uplink ya está en el techo físico de 1T1R+HT20 (65,0 Mbps medidos =
MCS7 long GI). Los +7 dB sobre el objetivo HT no compran throughput: se pagan
enteros en corriente del puerto USB, en interferencia para el vecindario y en
desgaste del PA. El usuario tiene prioridad de descarga y estabilidad, no de
alcance de uplink.

**Matiz que no se ignora:** una TX más fuerte puede ayudar algo el downlink, porque
el AP decodifica mejor nuestras ACK y sostiene un MCS más alto hacia nosotros. Como
el uplink está topado, el valor útil está en 15-16 dBm, no en 20. Por eso la tarea
incluye un A/B de `auto` contra un valor intermedio antes de cerrar el default.

### D4 — `CONFIG_TXPWR_LIMIT` se activa aunque bajo US sea casi no-op

**Elegido:** `CONFIG_TXPWR_LIMIT = y` y `CONFIG_TXPWR_LIMIT_EN = y`.

**Por qué:** hoy `lmt` y `ulmt` salen `NA` en la tabla de potencias: el driver no
calcula ningún límite. Bajo `US: DFS-FCC` (2.4G a 30 dBm) no recorta nada a 13 dBm,
así que **no es un arreglo de rendimiento**. Es una garantía: sin él, cualquier
anulación de potencia que se añada en el futuro se emite sin recortar, y el dominio
regulatorio es la única red de seguridad que queda. Es la razón por la que el
escenario del spec pide "rechazado o recortado" en vez de un número.

**Alternativa descartada:** dejarlo en `n` y confiar en el dominio regulatorio de
cfg80211. No aplica: el dominio regulatorio gobierna qué canales se pueden usar,
no el índice de potencia que escribe la HAL.

### D5 — `rtw_usb_rxagg_mode = 1`, no `0`

**Elegido:** el default pasa a `1` (`RX_AGG_DMA` con umbral del driver:
`rxagg_dma_size = 8`, `rxagg_dma_timeout = 8`, en `usb_halinit.c:124-125`).

**Por qué:** el valor `0` actual no desactiva la agregación. `usb_halinit.c:115-116`
coacciona cualquier valor que no sea DMA ni USB a `RX_AGG_DMA`, y
`hal_halmac.c:4686` mapea eso a `HALMAC_RX_AGG_MODE_DMA`. Con `0` la agregación
está activa pero **sin umbral definido por el driver** (los dos campos quedan a 0,
así que la rama `drv_define` no se toma y manda el umbral del firmware). `1` activa
exactamente el mismo modo pero con umbral explícito. Es decir: el valor correcto
para el comportamiento que el usuario creía tener ya era `1`, y nadie lo puso.

**Consecuencia que hay que asumir en voz alta:** los dos parches de estabilidad USB
(`MAX_CONTINUAL_IO_ERR = 80` y el guard de `WIFI_UNDER_SURVEY`) se escribieron
justificándolos con "no hay buffering". Esa premisa era falsa. **No se tocan** —
prevenir un `surprise_removed` masivo no hace daño y revertirlos sería un cambio de
comportamiento sin evidencia. Lo que sí se corrige es el comentario, que es
documentación actively falsa. La aserción de CI (§D7) vigila que el default no
vuelva a ser un valor que la HAL sustituya.

### D6 — NAPI y GRO se reactivan, con A/B y reversión

**Elegido:** `rtw_en_napi = 1` y `CONFIG_RTW_GRO = y`.

**Por qué:** es el mayor consumidor de CPU de la lista por trama, y la entrega
por trama limita la descarga, que es la prioridad del usuario. La premisa que
los Justificó ("la agregación USB está desactivada, por eso NAPI molesta") queda
demostrada falsa por D5, así que el compromiso original no se sostiene.

**Por qué con cautela:** NAPI se apagó por una razón real observada —los
`-EPIPE` durante el cambio de canal del router—, y el mecanismo de recuperación que
la soportaba (`MAX_CONTINUAL_IO_ERR = 80`) **sigue en el sitio**. El plan es por
tanto: activar, medir estabilidad bajo tráfico real durante al menos un ciclo de
cambio de canal del router, y revertir solo NAPI (manteniendo GRO) si aparece
`surprise_removed`. GRO y NAPI se por separado para que esa reversión sea parcial.

### D7 — Análisis estático con baseline, no en blanco

**Elegido:** job nuevo con sparse, smatch y checkpatch, con un fichero de baseline
en el repo; falla solo ante hallazgos nuevos.

**Por qué:** este es un árbol de vendor. Checkpatch sobre `driver/` producirá
miles de avisos heredados de Realtek; un job en blanco estaría rojo desde el primer
día y nadie lo miraría. El baseline convierte el job en una alerta real de
regresión. El baseline se versiona, y el job **falla si el baseline no existe o
está vacío** — sin eso, borrar el fichero convierte el job en un no-op silencioso,
que es el fallo clásico de este patrón.

**Por qué smatch aparte:** smatch (análisis de valores) tarda mucho más y genera
ruido distinto. Se ejecuta en el mismo job pero con su propia sección y su propio
contador, para poder desactivarlo sin tumbar sparse y checkpatch.

### D8 — Compilación contra headers de Debian 6.12 en contenedor

**Elegido:** añadir un job con `container: debian:trixie` que compila contra
`linux-headers-6.12-amd64`, junto a los dos jobs de Ubuntu que ya existen.

**Por qué:** el objetivo de despliegue es Debian trixie con kernel 6.12.x, y el CI
solo compila hoy contra headers de Ubuntu. Un `vermagic` o un `__attribute__`
disponible solo en una de las dos familias pasa el CI y rompe en la máquina. El
contenedor Debian con el paquete de headers exacto del despliegue es el test de
compilación que corresponde.

**No sustituye** a los jobs de Ubuntu: esos prueban compatibilidad hacia delante.
Se quedan.

### D9 — Las pruebas de carga del módulo van en una VM, no en un contenedor

**Restricción 5 — un contenedor NO puede cargar módulos del kernel de forma
aislada.** Verificado empíricamente el 2026-09-28, no supuesto: un módulo de
prueba inocuo (`noop.ko`, built con los headers del host) cargado con
`docker run --privileged ... insmod /m/noop.ko` **aparece en el `/proc/modules`
del host**. Un contenedor comparte el kernel con el host, así que `insmod`,
`rmmod` y `modprobe` no están dentro de su frontera de aislamiento: cargarlos
"en el contenedor" ES cargarlos en la máquina del usuario.

La consecuencia es directa sobre este change: **el hardware que hay que probar es
el que toca el change**. Cargar el `.ko` de 1.8.0 desde un contenedor significaría
desmontar el módulo que da la WAN del AP `escama` y montarlo con GRO, NAPI y el
escalado por tasa activados, sin forma de volver atrás si el `rmmod` falla o si
la carga deja la interfaz colgada. Eso no es una prueba: es un despliegue
involuntario con el router de la casa en medio.

**Elegido:** banco de pruebas en **QEMU**, con un kernel Debian 6.12 (el del
despliegue) y un `.ko` construido contra él. La VM da lo que el contenedor no
puede:

- `dmesg` completo y capturado por runner, para comprobar que la carga y la
  descarga no producen líneas `RTW:` (requisito del spec `driver-runtime-silence`).
- Ciclo `insmod` → `rmmod` → `insmod` real, que es donde aparecen fugas de
  referencia y use-after-free: el fallo A1 de `docs/AUDIT.md` (el work de URB
  stall que despierta sobre un adapter liberado) **solo se manifiesta en la
  descarga**, no en la carga.
- Carga del módulo sin hardware USB conectado, que aísla la inicialización del
  driver de la física del dongle.

**Restricción de recursos:** `/dev/kvm` existe pero no es usable por el usuario
del despliegue (abre con `EINVAL`), así que QEMU corre por emulación de software
(TCG). Arrancar un kernel 6.12 y llegar a `insmod` tarda minutos, no segundos.
Es aceptable para un job de CI y no lo es para un bucle de desarrollo, y por eso
el banco vive en CI y no como script local de uso frecuente.

**Qué NO se prueba en la VM, y por qué:** el flapeo del enlace USB (Restricción 3)
ocurre en el hub físico y en el cable; una VM con un dispositivo USB emulado no
lo reproduce. Y el throughput real, que depende de la SNR del vecindario. Eso
sigue exigiendo hardware, y las tareas de medición lo dicen explícitamente
(tarea 7.3) en vez de dar por hecho que un banco automático lo cubre.

**Alternativas descartadas:**

- *`docker run --privileged` con el host como kernel.* Aísla el sistema de
  ficheros, no el kernel: el módulo se carga en el host. Descartado por la
  Restricción 5, que es empírica.
- *Cargar solo en la VM de CI y probar en local a mano.* Es lo que hacen muchas
  forks, y es la razón por la que este repo acumula documentación falsa: nadie
  pudo comprobar que el flag decía lo que prometía. La VM es el sitio donde esa
  comprobación se vuelve mecánica.
- *KVM para que la VM sea rápida.* No disponible en esta máquina sin cambios de
  grupo o permisos en `/dev/kvm`, que están fuera del alcance de este change. Si
  algún día se habilita, el runner no cambia: solo baja el flag `-accel`.

## Risks / Trade-offs

- **Silenciar el driver ciega el diagnóstico en vivo** → se mitiga documentando, en
  `docs/`, cómo distinguir un fallo del enlace USB de un fallo del driver usando solo
  el log del núcleo y las aserciones de CI, y cómo usar las comprobaciones de CI
  cuando el módulo no carga. El requisito del spec `driver-runtime-silence` lo
  convierte en contrato, no en nota.
- **Apagar `PROC_DEBUG` deja sin datos a `antena-guira` y `wn8200nd-antenna`**, que
  leen `rx_signal` de procfs → la migración va en el mismo change, con
  `iw dev <iface> station dump` como fuente. La herramienta de antena pierde el
  desglose por ruta de RF; se documenta la limitación, porque con 1T1R forzado la
  ruta B ya no es informativo.
- **Reactivar NAPI puede resucitar el `surprise_removed` por `-EPIPE`** → A/B con
  reversión parcial (NAPI sí, GRO no) y umbral de abort explícito: si aparece
  `surprise_removed` en la ventana de prueba, se revierte NAPI en la misma tarea y se
  registra el resultado. El comentario de `rtw_io.h` se actualiza en consecuencia.
- **El flapeo USB seguirá occurriendo** → no hay mitigación de software. Se documenta
  la evidencia, el procedimiento de recuperación y el experimento de puerto de root
  directo como prueba manual. La honestidad aquí vale más que un parche cosmético:
  el driver no se ejecuta en ese camino.
- **Activar `CONFIG_TXPWR_BY_RATE_EN` cambia la potencia por tasa** → puede bajar la
  potencia de MCS7 (donde menos falta hace) y subir la de MCS0. Bajo el objetivo de
  13 dBm el efecto neto sobre el enlace es pequeño, pero no está medido. A/B con el
  mismo criterio de reversión que NAPI.
- **El A/B de TX power y el de NAPI se solapan en el tiempo** → no se miden a la vez.
  Un solo cambio de comportamiento activo por ventana de medición, y entre ventanas
  se estabiliza el enlace.
- **Apagar `CONFIG_RTW_DEBUG` reduce la capacidad de ver los parches propios** → es
  el objetivo declarado por el usuario, y el propio repo lo pide en
  `docs/AUDIT.md` (los `[PATCH]` actuales solo se ven porque el log está activo).
  Se asume.

## Migration Plan

1. **Preparación sin tocar el sistema.** Bump de versión, correcciones de
   documentación y comentarios, y el job de análisis estático con baseline
   generado. Push a CI: el baseline refleja el estado actual, así que el CI queda
   en verde sin haber cambiado ningún comportamiento.
2. **Silencio.** Apagar `RTW_DEBUG` y `PROC_DEBUG`, quitar el paso de `dbg 13` del
   script de recarga, eliminar `monitoring/`, migrar las herramientas de antena, baja
   del job de Hermes. Push a CI y, si verde, `sudo ./install_manual.sh` más
   `sudo wn8200nd-txpower disable`.
3. **TX power.** `auto` como default, con `CONFIG_TXPWR_LIMIT` activado. Push, CI
   verde, instalación, y ventana de medición del A/B contra 15-16 dBm.
4. **Agregación.** `rtw_usb_rxagg_mode = 1`. Push, CI, instalación, medición.
5. **NAPI y GRO, por separado.** GRO primero (menos riesgo), luego NAPI. Cada uno con
   su propia ventana y su reversión.
6. **`CONFIG_TXPWR_BY_RATE_EN`.** Última, y solo si los pasos anteriores ya están
   estables, porque su efecto sobre la potencia es acumulativo con el paso 3.

**Reversión.** Cada paso es reversible por su cuenta: los flags del Makefile se
revierten y se reinstala; `rtw_en_napi` y `rtw_usb_rxagg_mode` se revierten desde
`/etc/modprobe.d/8192eu.conf` sin recompilar; el watchdog de TX power se rehabilita
con `sudo wn8200nd-txpower enable`. El único punto de no retorno es la migración de
las herramientas de antena, que se hace de forma aditiva (manteniendo la lectura de
procfs con degradación elegante si vuelve a existir).

**Seguridad de la máquina.** Cada paso que cargue el módulo o toque la interfaz
devuelve el equipo a `managed` y reinicia NetworkManager al final, incluso si el
paso falla a mitad.

## Open Questions

Ninguna que afecte a los specs, al enfoque o al desglose. Dos unknows que se
resolverán **midiendo**, no decidiendo, y que por tanto no bloquean nada:

- El valor óptimo de TX power en el rango 13-20 dBm: se mide en la ventana del
  paso 3 y se documenta el resultado.
- Si NAPI+GRO juntos rompen la estabilidad USB o solo NAPI: se resuelve en la
  ventana del paso 5 con la reversión parcial ya prevista.
