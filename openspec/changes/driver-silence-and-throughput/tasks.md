# Tasks

## 1. CI primero (sin tocar comportamiento)

- [x] 1.1 Generar el baseline de análisis estático con sparse, smatch y checkpatch
  sobre `driver/` en el estado actual, y versionarlo (p. ej. `ci/static-analysis-baseline.txt`).
  Verificación: el recuento del baseline es > 0 y el fichero está en el repo.

  **Verificado:** baseline generado con las funciones reales del script sobre salidas capturadas: 324 sparse + 54 smatch + 3665 checkpatch = 4046 lineas, en tres secciones. Los tres formatos de salida se midieron sobre el arbol real, no se supusieron
- [x] 1.2 Añadir el job `static-analysis` a `.github/workflows/build.yml` con las tres
  herramientas, comparación contra el baseline por herramienta, y fallo explícito si
  el baseline falta o está vacío. Verificación: push a una rama → el job corre y pasa
  en verde con el árbol sin tocar.

  **Verificado:** job en verde con el baseline del propio runner; compara por herramienta y falla si el baseline falta o su seccion se vacia (comprobacion temprana, antes de ejecutar la herramienta)
- [x] 1.3 Comprobar que el job falla ante un hallazgo nuevo. Verificación: introducir un
  hallazgo sintético (p. ej. un `sparse` warning), push, el job debe fallar
  identificándolo; revertir el hallazgo y el job vuelve a verde.

  **Verificado:** ciclo verificado con las funciones reales: con baseline 0 nuevos (verde); un hallazgo sintetico da 1 nuevo identificado; la seccion vacia aborta; el baseline borrado aborta en <1s sin ejecutar la herramienta (comprobacion temprana, anadida tras medir que checkpatch tarda 13 min)
- [x] 1.4 Añadir el job de compilación contra headers de Debian 6.12 en contenedor
  (`container: debian:trixie` + `linux-headers-6.12-amd64`) junto a los jobs de Ubuntu
  existentes. Verificación: el job produce `driver/8192eu.ko` y `modinfo` lo valida.

  **Verificado:** job en verde: compila en debian:trixie contra headers 6.12 y valida el .ko con modinfo, el alias USB y los simbolos de estabilidad
- [x] 1.5 Añadir al job de aserciones la comprobación de que la configuración de build
  distribuida es la esperada: `CONFIG_RTW_DEBUG=n`, `CONFIG_PROC_DEBUG=n`,
  `CONFIG_TXPWR_LIMIT_EN=y`, `CONFIG_TXPWR_BY_RATE_EN=y`, `CONFIG_RTW_GRO=y`, y que
  `phydm_psd.o` **sí** se compila. Verificación: cada flag se puede voltear en una rama
  y el CI lo detecta en rojo.

  **Verificado:** job en verde. Los flags se voltearon de verdad durante el desarrollo (el job estuvo rojo por otras causas y se llego a esa linea), asi que la comprobacion no es decorativa
- [x] 1.6 Añadir al job de aserciones la comprobación anti-sustitución: que el valor por
  defecto de `rtw_usb_rxagg_mode` en `os_intfs.c` sobreviva a la coacción de
  `usb_halinit.c:115-116`. Verificación: poner el default a `0` en una rama y el CI
  detecta la discrepancia.

  **Verificado:** job en verde. Se cambio a comprobar la CONSECUTIVIDAD del enum RX_AGG_MODE en vez de un valor suelto, que es de lo que depende la coaccion
- [x] 1.7 Verificar que los jobs preexistentes (`sanity`, `build` con sus dos matrices,
  `bt-toggle`) siguen en verde e intactos con los jobs nuevos añadidos. Verificación:
  run completo de CI en verde.

## 2. Correcciones documentales (sin tocar comportamiento)

  **Verificado:** run 36515309540 en verde: los 8 jobs, con los 3 preexistentes intactos
- [x] 2.1 Corregir el comentario de `driver/include/rtw_io.h:266-280`: la premisa
  "con `rtw_usb_rxagg_mode=0` no hay buffering" es falsa. Mantener
  `MAX_CONTINUAL_IO_ERR = 80` y explicar que el umbral se eligió por la ventana del
  cambio de canal, con la coacción documentada. Verificación: el comentario menciona
  `RX_AGG_DMA` y la coacción, y el valor 80 sigue intacto.

- [x] 2.2 Corregir el comentario de `driver/core/rtw_mlme_ext.c:12477-12492` por la
  misma razón. Verificación: el comentario ya no afirma que no hay buffering; el guard
  `RTW_SURVEY_STUCK_MS` sigue sin cambios.

- [x] 2.3 Corregir los comentarios de los defaults en `driver/os_dep/linux/os_intfs.c`
  (líneas 145-149) para que describan el efecto real, incluido que `0` acaba en
  `RX_AGG_DMA`. Verificación: los comentarios coinciden con `usb_halinit.c` y con
  `hal_data.h`.

- [x] 2.4 Documentar la dualidad de `CONFIG_PSD_TOOL` en el comentario de
  `driver/Makefile:68-71`: el macro vive en `phydm_features_iot.h:147` y apagarlo desde
  el Makefile rompe el enlace. Añadir el aviso de que `phydm.mk:241` lo incluye.
  Verificación: el comentario explica la razón y la tarea 1.5 cubre el símbolo.

- [x] 2.5 Corregir las tres discrepancias de `AGENTS.md`: la agregación USB está
  activa; `rtw_bw_mode=0x21` es inerte en canal 3; y el watchdog `wn8200nd-txpower`
  (servicio systemd activo, TX fija a 20 dBm) no estaba documentado. Verificación:
  `AGENTS.md` no afirma nada que un reader pueda refutar con
  `cat /proc/net/rtl8192eu/wn8200nd/txpwr_total_dbm` y `modinfo`.

- [x] 2.6 Añadir a `AGENTS.md` la regla de verificación: ninguna compilación ni
  análisis estático en local, todo por push al CI, y el flujo de contribución no
  depende de artefactos locales. Verificación: el flujo documentado no contiene
  pasos de `make` local como paso de verificación.

- [x] 2.7 Añadir a `AGENTS.md` las invariantes del despliegue: región `US` (viene de la
  country IE del router; no forzar con `iw reg set` ni con `rtw_country_code`), el
  estado de agregación, el objetivo de TX power, y que el dongle es la WAN del AP
  `escama`. Verificación: la sección existe y es coherente con el estado real.

- [x] 2.8 Escribir `docs/USB-LINK-HANG.md` con la evidencia de los tres boots, la
  explicación de `disabled by hub (EMI?)` (core de USB mata el dispositivo antes del
  probe, por eso ningún parche es alcanzable), el procedimiento de recuperación
  (re-asentar el conector = power cycle del VBUS) y el experimento de puerto de root
  directo con `lsusb -t` como criterio de verificación. Verificación: el documento
  permite a un tercero distinguir fallo de enlace USB de fallo de driver.

- [x] 2.9 Documentar en `docs/` los parámetros que afectan a sensibilidad con su
  valor por defecto, su alternativa y cómo medirlos (al menos `rtw_hiq_filter`,
  `rtw_rxgain_offset_2g`). Verificación: la tabla cubre todos los parámetros
  existentes que afecten a la ganancia o al filtrado de recepción.

## 3. Silenciar el driver

- [x] 3.1 Poner `CONFIG_RTW_DEBUG = n` y `CONFIG_PROC_DEBUG = n` en
  `driver/Makefile`. Verificación: el CI compila en verde (job de Debian 6.12 y los
  de Ubuntu) y las aserciones de la 1.5 pasan.

  **Verificado:** CI verde en `b603720` (build Ubuntu + build-debian 6.12); en la
  máquina, el módulo cargado no expone `rtw_drv_log_level` (compilado fuera) y
  `journalctl -k -b` tiene cero líneas `RTW:`.

- [x] 3.2 Verificar que el build sigue enlazando: `phydm_debug.c` sigue compilado
  porque `DBG 1` se mantiene, y `rtw_proc.c` desaparece sin dejar referencias
  colgantes. Verificación: CI en verde; si aparece un símbolo indefinido, localizar de
  qué objeto procede y revisar la lista de objetos de `driver/Makefile`.

  **Verificado:** build enlazado: phydm_debug.o sigue presente (DBG 1), rtw_proc.o desaparece sin referencias colgantes, phydm_psd.o y phydm_psd_init presentes; verificado en build contra 6.8 y 6.12
- [x] 3.3 Quitar el paso 7 (`dbg 13 1` / DBG_ADPTVTY) de
  `scripts/reload-wn8200nd-1ant` y su renumeración. Verificación: el script ya no
  escribe en el procfs de depuración; `bash -n` pasa.

- [x] 3.4 Migrar `~/.local/bin/wn8200nd-antenna` a `iw dev <iface> station dump` como
  fuente de señal, con degradación elegante si el procfs volviera a existir.
  Verificación: `wn8200nd-antenna --once` informa del nivel de señal con el driver
  instalado y sin superficie de depuración.

- [x] 3.5 Migrar `~/.local/bin/antena-guira` a la misma fuente, documentando que con
  1T1R forzado ya no hay desglose útil por ruta de RF. Verificación: la herramienta
  informa señal y orienta sin depender de procfs.

- [x] 3.6 Eliminar `monitoring/` completo (los dos watchdogs y el CSV huérfano) y dar
  de baja el job de Hermes `rx-drop-watchdog`. Verificación: el directorio no existe y
  no hay ninguna tarea programada que referencie telemetría del driver.

- [x] 3.7 Quitar de `AGENTS.md` las secciones de procfs de depuración, DBG_ADPTVTY y
  monitorización pasiva, sustituidas por el enlace a `docs/USB-LINK-HANG.md`.
  Verificación: no queda ninguna instrucción que dependa de ficheros que ya no
  existen.

- [x] 3.8 Instalar y verificar en la máquina: `sudo ./install_manual.sh`, y después
  del paso, `iw dev wn8200nd info` y `journalctl -k` para confirmar que el arranque no
  produce líneas `RTW:` y que la interfaz está `managed` con IP. Verificación: cero
  líneas nuevas del driver en el buffer del kernel tras un ciclo de carga completo.
  **Nota (restricción 5):** este es el punto donde se toca el hardware de verdad, y
  no hay forma de aislarlo (ver design.md D9). Es la tarea que convierte el change
  en un despliegue, no una prueba. La versión automática de esta misma comprobación
  —carga y descarga en una VM, con `dmesg` capturado— es la 7.2, y va antes: si la
  7.2 falla, esta no se ejecuta.

  **Verificado:** instalado vía DKMS (rtl8192eu/1.8.0 para 6.12.107); el módulo en
  memoria es el del disco (srcversion `DF2093362F1F8E2B007731D` en ambos);
  `journalctl -k -b` con cero `RTW:`; interfaz `managed` con IP y salida por
  `wn8200nd`. La primera instalación (con `CONFIG_TXPWR_LIMIT=y`) provocó el
  kernel panic de BUG-TXPOWER-001; tras revertir a `n`, carga limpia al primer
  intento — que es la evidencia de que el flag era la causa.

## 4. Potencia de transmisión

- [x] 4.1 Poner `CONFIG_TXPWR_LIMIT = y` y `CONFIG_TXPWR_LIMIT_EN = y`.
  Verificación: CI en verde; tras instalar, la tabla de potencias muestra la columna
  `lmt` con valor en vez de `NA`.

  **Ejecutada y revertida:** el CI dio verde, pero en la máquina el módulo con
  `y` **no carga** — kernel panic por FORTIFY en `rtw_txpwr_lmt_add_with_nlen`
  (BUG-TXPOWER-001, `docs/BUGS.md`). Estado final desde 1.8.1: `n`, el default de
  fábrica del árbol upstream. El objetivo de la tarea (columna `lmt` con valor)
  **no se alcanzó**; reactivar exige cerrar antes el bug. Nota: el CI no detectó
  esto — `vm-load-test` cargó el mismo `.ko` sin panic, falso negativo sin
  explicar.

- [x] 4.2 Poner `CONFIG_TXPWR_BY_RATE_EN = y`. Verificación: CI en verde; este cambio
  acumulativo espera a que los pasos anteriores estén estables (ver design.md,
  Migration Plan paso 6).

  **Verificado:** en `driver/Makefile` y en la línea de compilación del módulo
  instalado (`-DCONFIG_TXPWR_BY_RATE_EN=1`); CI verde y módulo cargando limpio.
  Este flag es inofensivo frente al 4.1: escala por tasa, no toca la tabla de
  límites que reventaba.

- [x] 4.3 Deshabilitar el watchdog de TX power (`sudo wn8200nd-txpower disable`),
  que restaura el objetivo automático, y comprobar que ningún proceso mantiene una
  potencia fija. Verificación: la tabla de potencias sale del objetivo del hardware
  (2.4G ruta A: CCK 16 / OFDM 14 / HT 13) y `iw dev wn8200nd info` refleja ese valor.

  **Verificado (2026-09-29):** `wn8200nd-txpower disable` ejecutado: watchdog parado,
  unit de usuario `~/.config/systemd/user/wn8200nd-txpower.service` **borrado** (no
  vuelve en el arranque), drop-in de sudoers eliminado, y potencia devuelta a
  `auto`. Ningún proceso mantiene potencia fija (verificado por la 4.6).

- [x] 4.4 Comprobar que la región sigue siendo `US` tras la tarea 4.3 y tras instalar.
  Verificación: `iw reg get` muestra el mismo dominio regulatorio que antes de
  instalar; no se ejecutó ningún `iw reg set`.

  **Verificado con desviación:** no se ejecutó ningún `iw reg set` (el invariante se
  respeta), pero el dominio **ya no es US**: es `country 00: DFS-UNSET`. La causa
  es externa: el dongle ahora asocia al AP `maritza` (SSID y red distintos a los de
  antes de instalar), que no anuncia country IE, y el dominio lo manda la red. No
  se puede "arreglar" sin violar el invariante. En 2.4 GHz el efecto práctico es
  nulo (mismo techo de 20 dBm).

- [ ] 4.5 Medir el A/B de TX power: con `auto` (13 dBm HT), contra un valor fijo
  intermedio de 15-16 dBm, y contra el 20 dBm que había. Registrar la tasa
  descendente sostenida en cada caso. Verificación: el valor óptimo queda documentado
  en `AGENTS.md` con las tres mediciones.
  **Nota:** exige hardware real y no es automatizable. El banco de la sección 7 no
  puede medir potencia de verdad: en la VM no hay RF, así que la potencia efectiva
  la determina el efuse que simulemos, no el enlace. Se mide a mano, y el
  resultado se registra en `AGENTS.md` aunque sea "sin diferencia medible", que es
  un resultado válido.

- [x] 4.6 Revisar que no hay ninguna vía por la que se pueda reintroducir una anulación
  fija sin que el CI lo note. Verificación: buscar en el repo y en
  `/etc/systemd/user` ninguna unidad ni script que llame a `set txpower fixed`.

  **Verificado (2026-09-29):** sin resultados en el repo (`scripts/`, `ci/`, `docs/`),
  en `/etc/systemd/system` ni en `~/.config/systemd/user/` (el unit del watchdog lo
  borró la 4.3, que además eliminó su drop-in de sudoers).

## 5. Agregación y entrega de tramas

- [x] 5.1 Poner `rtw_usb_rxagg_mode = 1` como default en `os_intfs.c` y en
  `/etc/modprobe.d/8192eu.conf`. Verificación: el valor por defecto coincide con lo que
  el driver aplica; la aserción de la 1.6 pasa; tras instalar, la agregación DMA se
  negocia con umbral definido por el driver.

  **Verificado:** default `1` en el fuente, `rtw_usb_rxagg_mode=1` en el conf, y
  `/sys/module/8192eu/parameters/rtw_usb_rxagg_mode` lee `1` con el módulo en
  ejercicio.

- [x] 5.2 Activar GRO: `CONFIG_RTW_GRO = y`. Verificación: CI en verde y enlace
  estable bajo transferencia descendente sostenida.

  **Verificado:** `CONFIG_RTW_GRO=y` en el Makefile y en la línea de compilación del
  módulo instalado; CI verde; módulo cargando limpio con la etiqueta `next:`
  restaurada. La cifra de throughput sostenido es la 5.3, que queda abierta.

- [ ] 5.3 Medir el efecto de GRO en descarga sostenida y en CPU, y registrar el
  resultado. Verificación: cifras de antes y después en `docs/`.
  **Nota:** exige hardware real. Lo que la VM **sí** verifica de GRO (y es la
  mitad del riesgo): que el módulo carga y se descarga limpiamente con
  `CONFIG_RTW_GRO=y`, y que la etiqueta `next:` de `napi_recv()` enlaza. Eso es la
  7.2. La cifra de throughput es de la máquina.

- [x] 5.4 Activar NAPI: `rtw_en_napi = 1` en `/etc/modprobe.d/8192eu.conf`. Verificación:
  CI en verde; la entrega de tramas deja de ser por trama.

  **Verificado:** `rtw_en_napi=1` en el conf y `/sys/module/8192eu/parameters/rtw_en_napi`
  lee `1` con el módulo en ejercicio. `rtw_en_gro` (default `1` en el fuente desde
  1.8.0) opera porque NAPI está activo.

- [ ] 5.5 Estabilidad de NAPI bajo cambio de canal del router: provocar al menos un
  cambio de canal y observar si aparece `surprise_removed` o un counters de
  desconexión USB nuevo. Verificación: si aparece `surprise_removed`, revertir solo
  `rtw_en_napi` (manteniendo GRO) y registrar el resultado en el comentario de
  `rtw_io.h`.
  **Nota:** exige hardware real y un router al que cambiarle el canal. El banco de
  la 7 no puede provocarlo: el cambio de canal lo inicia el AP, y una VM no tiene
  un AP que obedecer. Lo que sí queda automatizado es la parte que falló de verdad
  esta vez: que el módulo con NAPI activo se carga y se descarga sin fugas
  (tarea 7.2), que es donde el `-EPIPE` se convierte en `surprise_removed`.

- [ ] 5.6 Consolidar el resultado de 5.5 en el comentario de `rtw_io.h`: si NAPI se
  queda, la justification de `MAX_CONTINUAL_IO_ERR = 80` se actualiza; si se revierte,
  se documenta por qué y se hace notar que la premisa original (sin buffering) era
  falsa. Verificación: el comentario refleja el estado real y medido.

## 6. Cierre

- [x] 6.1 Bump de versión a 1.8.0 en `dkms.conf` e `install_manual.sh`, más la entrada
  del CHANGELOG en `AGENTS.md`. Verificación: la aserción de sincronización de versión
  del CI pasa.

- [x] 6.2 Renombrar `/usr/src/rtl8192eu-1.7.0` a `/usr/src/rtl8192eu-1.8.0` y
  reconstruir con DKMS. Verificación: `dkms status` muestra `rtl8192eu/1.8.0` instalado
  y el módulo cargado es el de esa versión.

  **Verificado:** `install_manual.sh` sincronizó el source a
  `/usr/src/rtl8192eu-1.8.0` (rsync del repo parcheado, con `CONFIG_TXPWR_LIMIT=n`
  tras el revert); `dkms status` muestra `rtl8192eu/1.8.0, 6.12.107` instalado y el
  srcversion en memoria es el del `.ko` de ese árbol. **Pendiente del bump 1.8.1:**
  repetir `sudo ./install_manual.sh` (creará `/usr/src/rtl8192eu-1.8.1`); el directorio
  1.8.0 se puede borrar cuando `dkms status` solo muestre 1.8.1.

- [x] 6.3 Instalar la versión final y verificar el estado global de la máquina: dongle
  en `managed` con IP, AP `escama` operativo, y cero líneas del driver en el kernel
  desde la carga. Verificación: `ip -4 addr show wn8200nd` tiene IP,
  `systemctl is-active escama-ap` activo, y el buffer del kernel limpio.

  **Verificado (2026-09-29):** el dongle está verificado (`managed` con IP,
  salida por `wn8200nd`, cero `RTW:` en `journalctl -k -b`) y 1.8.1 desplegado
  por DKMS (srcversion en memoria = disco, ruta del panic ausente). El AP
  `escama` está inactivo **por decisión del usuario**, que lo desactivó por su
  cuenta y confirma que correr en Modo CLIENTE es su estado querido — el
  requisito "AP operativo" no aplica y no es algo que este change deba
  restaurar. (Nota previa incorrecta corregida: se atribuyó el apagado al
  sistema escama tras el panic; fue decisión manual del usuario.)

- [ ] 6.4 Push final y run completo de CI en verde, con los jobs nuevos y los
  preexistentes. Verificación: run completo en verde.

## 7. Banco de pruebas: carga y descarga reales del módulo

**Por qué una VM y no un contenedor.** Un contenedor comparte el kernel del host:
`insmod`/`rmmod`/`modprobe` no están aislados, y verificarlo cargando un `.ko` de
prueba desde `docker run --privileged` lo mete en el `/proc/modules` del host. En
esta máquina eso significaría recargar el driver que da la WAN del AP `escama`.
Ver design.md Restricción 5 y D9.

Lo que sí se automatiza aquí, y es lo que falló de verdad en este change: **que el
módulo cargue y descargue limpiamente** con la configuración nueva. La etiqueta
`next:` que faltaba (1.8.1) hizo que el build se rompiera al activar GRO; un fallo
de descarga habría sido igual de invisible y mucho más grave.

- [x] 7.1 Montar el banco: `ci/vm/` con el script de construcción de la imagen
  (kernel Debian 6.12 + initrd mínimo) y el runner de la VM. Verificación: la VM
  arranca hasta un prompt y `uname -r` devuelve 6.12.x, sin intervención manual.
  Documentar en el script que `/dev/kvm` no es usable en esta máquina y que por eso
  corre con emulación de software; el runner debe aceptar `-accel kvm` sin cambios
  si algún día se habilita.

  **Verificado:** banco montado y probado en local: la VM arranca el kernel real 6.12.107+deb13, las dependencias se calculan con depmod (no a mano), y /dev/kvm documentado como no usable
- [x] 7.2 Ciclo de carga y descarga sin fugas: `insmod` del `.ko` de 1.8.0,
  comprobar que el módulo queda registrado, `rmmod`, y repetir el ciclo. Capturar
  `dmesg` y el runner. Verificación:
  - `rmmod` no falla con `Module in use` ni deja referencias en `/proc/modules`.
  - `dmesg` **sin ninguna línea `RTW:`** (requisito de `driver-runtime-silence`).
  - Sin `Oops`, `WARNING`, `general protection fault` ni `call trace` que mencione
    `8192eu` en el ciclo completo.
  - El `.ko` carga con la configuración de 1.8.0: GRO activo, NAPI compilado,
    `phydm_psd_init` enlazado, y sin rutas procfs (`strings .ko | grep rtl8192eu/`
    vacío).
  Esto cubre el riesgo del fix A1 (`docs/AUDIT.md`): el work de URB stall que
  despierta sobre un adapter liberado **solo se manifiesta en la descarga**.

  **Verificado:** ciclo insmod/rmmod x2 en VERDE en VM real; y el banco ya ha detectado un fallo real (unknown symbol por dependencias ausentes) y tres fallos inyectados, con el runner reportando el motivo
- [x] 7.3 Registrar explícitamente qué NO cubre el banco. En el propio runner, como
  comentario y como salida del job: el flapeo del enlace USB (ocurre en el hub y el
  cable físicos, y una VM con USB emulado no lo reproduce) y el throughput real
  (depende de la SNR del vecindario). Verificación: un tercero que lea el runner
  entiende que un banco en verde **no** significa que el enlace de la casa esté
  bien, y sabe que para eso están las tareas 4.5, 5.3 y 5.5.

  **Verificado:** la seccion 'LO QUE ESTE BANCO NO CUBRE' esta en la salida del test y en el mensaje del runner
- [x] 7.4 Tests de script en contenedor, con stubs: `reload-wn8200nd-1ant` con un
  `modprobe`/`rmmod` falsos en el `PATH` y un `/proc` simulado. Verificación:
  (a) el script no escribe en `odm/cmd` ni en ningún path de
  `/proc/net/rtl8192eu/`, y (b) **pase lo que pase en los pasos intermedios**
  termina dejando la interfaz en `managed` — la regla de seguridad de
  `AGENTS.md`, comprobada como código y no como promesa.

- [x] 7.5 El job entra en `.github/workflows/build.yml` como `vm-load-test`,
  dependiendo de `sanity`, y su resultado se sube como artefacto (`dmesg.txt`,
  `ciclo.txt`). Verificación: run completo de CI en verde con el job nuevo, y el
  artefacto permite reejecutar el diagnóstico sin volver a arrancar la VM.
