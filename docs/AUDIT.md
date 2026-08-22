# AUDIT.md — auditoría estática del árbol `driver/`

Ejecutada con los procedimientos de `skills/` (`code-navigation`, `cflow-callgraph`,
`unifdef-coan`, `checkpatch-kernel-style`) sobre el commit de trabajo, 2026-08-22.

Método: evaluador de `driver/Makefile` + `driver/hal/phydm/phydm.mk` con los `CONFIG_*`
actuales, cruzado contra el árbol de ficheros y contra los guards de preprocesador de cada
fichero. Los conteos de "no compilado" son **conservadores** (una condición no evaluable se
asume activa).

| Métrica | Valor |
|---|---|
| Ficheros `.c` en el árbol | 200 · 11.1 MB |
| Compilados (aprox.) | 152 · 9.0 MB |
| **No compilados** | **48 · 2.2 MB** |
| Compilados que producen **objeto vacío** | **16 · 643 KB** |

---

## 1. DESECHABLE — 48 ficheros `.c` que el Makefile nunca compila (2.2 MB)

Verificado: ninguno aparece en `$(MODULE_NAME)-y`, `rtk_core`, `_HAL_INTFS_FILES`,
`_OS_INTFS_FILES`, `_PHYDM_FILES`, `_BTC_FILES` ni `_PLATFORM_FILES` con la configuración
actual.

**Bluetooth coexistence (469 KB)** — `CONFIG_BT_COEXIST = n`
```
hal/btc/halbtc8192e1ant.c   hal/btc/halbtc8192e2ant.c
hal/btc/HalBtc8192e1Ant.c   hal/btc/HalBtc8192e2Ant.c
core/rtw_bt_mp.c
```

**Firmware/imágenes de otras variantes (669 KB)**
```
hal/phydm/rtl8192e/halhwimg8192e_fw.c
```

**HALRF de otras plataformas (405 KB)** — variantes `_ap`, `_win`, `_iot` (Realtek AP/Windows/IoT)
```
hal/phydm/halrf/halphyrf_ap.c            hal/phydm/halrf/halphyrf_win.c
hal/phydm/halrf/halphyrf_iot.c           hal/phydm/halrf/halrf_powertracking_ap.c
hal/phydm/halrf/halrf_powertracking_win.c  hal/phydm/halrf/halrf_powertracking_iot.c
hal/phydm/halrf/halrf_txgapcal.c
hal/phydm/halrf/rtl8192e/halrf_8192e_ap.c  hal/phydm/halrf/rtl8192e/halrf_8192e_win.c
```

**PHYDM no usado (197 KB)**
```
phydm_rxhp.c  phydm_powertracking_ap.c  phydm_powertracking_ce.c  phydm_powertracking_win.c
phydm_dynamicbbpowersaving.c  phydm_edcaturbocheck.c  rtchnlplan.c
```

**Beamforming de otros chips (89 KB)**
```
hal/phydm/txbf/haltxbf8192e.c  haltxbf8814a.c  haltxbf8822b.c  haltxbfjaguar.c
```

**HALMAC (134 KB)** — solo para 8822/8814/8821C
```
hal/hal_halmac.c
```

**MP / test de fábrica y otros (124 KB)**
```
os_dep/linux/ioctl_mp.c        os_dep/linux/custom_gpio_linux.c
os_dep/linux/rhashtable.c      (se usa rtw_rhashtable.c)
core/rtw_eeprom.c  core/rtw_mem.c  core/rtw_sdio.c
```

**LED / recv / xmit de la variante USB no seleccionada (35 KB)**
```
hal/rtl8192e/usb/rtl8192eu_led.c  rtl8192eu_recv.c  rtl8192eu_xmit.c
```

**Plataformas SDIO ARM/SoC (20 KB · 10 ficheros)**
```
platform/platform_ARM_SUN50IW1P1_sdio.c  platform_ARM_SUNnI_sdio.c  platform_ARM_SUNxI_sdio.c
platform_ARM_WMT_sdio.c  platform_RTK_DMP_usb.c  platform_aml_s905_sdio.c
platform_arm_act_sdio.c  platform_hisilicon_hi3798_sdio.c  platform_sprd_sdio.c
platform_zte_zx296716_sdio.c
```

**Efuse de otras interfaces (4 KB)**
```
hal/efuse/rtl8192e/HalEfuseMask8192E_PCIE.c  ..._SDIO.c
```

**Basura de trabajo (no compilada, en el índice de Git)**
```
driver/os_dep/linux/os_intfs.c.backup
driver/os_dep/linux/os_intfs.c.mine      ← nombre de conflicto de merge sin resolver
```

---

## 2. OPTIMIZABLE

### 2.1 · 643 KB que se compilan para producir objetos vacíos

Estos 16 ficheros **sí** los compila el Makefile, pero todo su contenido está dentro de un
`#ifdef` cuyo símbolo no está definido. Resultado: coste de compilación, cero código.

| Tamaño | Fichero | Guard |
|---|---|---|
| 196 KB | `hal/phydm/phydm_antdiv.c` | `CONFIG_PHYDM_ANTENNA_DIVERSITY` |
| 120 KB | `core/mesh/rtw_mesh.c` | `CONFIG_RTW_MESH` |
| 57 KB | `core/rtw_beamforming.c` | `CONFIG_BEAMFORMING` |
| 45 KB | `core/mesh/rtw_mesh_hwmp.c` | `CONFIG_RTW_MESH` |
| 38 KB | `core/rtw_vht.c` | `CONFIG_80211AC_VHT` |
| 33 KB | `hal/phydm/phydm_antdect.c` | `CONFIG_ANT_DETECTION` |
| 32 KB | `core/mesh/rtw_mesh_pathtbl.c` | `CONFIG_RTW_MESH` |
| 32 KB | `hal/phydm/phydm_pathdiv.c` | `CONFIG_PATH_DIVERSITY` |
| 21 KB | `hal/phydm/phydm_dynamictxpower.c` | `CONFIG_DYNAMIC_TX_TWR` |
| 17 KB | `core/wds/rtw_wds.c` | `CONFIG_RTW_WDS` |
| 15 KB | `hal/phydm/phydm_psd.c` | `CONFIG_PSD_TOOL` |
| 12 KB | `hal/phydm/phydm_direct_bf.c` | `CONFIG_DIRECTIONAL_BF` |
| 11 KB | `core/rtw_iol.c` | `CONFIG_IOL` |
| 6 KB | `hal/hal_phy.c` | `CONFIG_RF_SHADOW_RW` |
| 6 KB | `os_dep/linux/nlrtw.c` | `CONFIG_RTW_NLRTW` |
| 2 KB | `os_dep/linux/rtw_rhashtable.c` | `CONFIG_RTW_WDS` |

⚠️ `CONFIG_RTW_WDS` y `CONFIG_RTW_NLRTW` **se autodefinen** en `driver/include/drv_conf.h:237-245`
si se activa `CONFIG_RTW_MULTI_AP`. Con AP mode ya habilitado (1.6.2), activar Multi-AP en
el futuro reactivaría esos ficheros: no borrarlos sin decidir antes sobre Multi-AP.

**Acción recomendada** (skill `unifdef-coan` + patrón Kbuild): moverlos de `$(MODULE_NAME)-y`
a `$(MODULE_NAME)-$(CONFIG_X) +=`, que es el idiom correcto de Kbuild. Cero riesgo funcional
y menos trabajo del compilador.

### 2.2 · `ccflags-y` global en lugar de por objeto

Todo el árbol se compila con el mismo bloque de flags. `-O2` sobre 152 ficheros de los
cuales solo un puñado están en el hot path (`usb_ops_linux.c`, `rtw_recv.c`, `rtw_xmit.c`,
`phydm_adaptivity.c`) es correcto, pero `-Wno-unused-variable` y `-Wno-unused-function`
globales **ocultan exactamente el diagnóstico que necesitas para podar**. Recomendación:
quitarlos temporalmente en una corrida de auditoría (`make ccflags-y=...`) y anotar la
salida antes de volver a ponerlos.

### 2.3 · Duplicación de `hal/btc`

`hal/btc/` contiene los mismos cuatro ficheros **dos veces, diferenciados solo por
mayúsculas**: `HalBtc8192e1Ant.c/.h` y `halbtc8192e1ant.c/.h` (ídem 2Ant). 469 KB
duplicados de código muerto.

### 2.4 · Objetos que sobreviven a `make clean`

El target `clean` (`driver/Makefile:2513-2528`) está escrito a mano con globs de
profundidad fija:

```make
cd hal ; rm -fr */*/*/*.o ...     # cubre hasta hal/a/b/c.o
```

`hal/phydm/halrf/rtl8192e/` está a **cuatro** niveles bajo `hal/` → sus `.o` y `.cmd`
**no se borran**. Tras un cambio de configuración pueden enlazarse objetos rancios.
Arreglo correcto: descomentar `$(MAKE) -C $(KSRC) M=$(shell pwd) clean` (línea 2512), que
es lo que Kbuild sabe hacer bien, o usar `find . -name '*.o' -delete`.

---

## 3. MAL EN EL CÓDIGO — hallazgos por severidad

### 🔴 A1 · Work item sin `cancel_work_sync()` → use-after-free al descargar el módulo

`driver/os_dep/linux/usb_ops_linux.c:20-73` — parche "URB STALL RECOVERY", **no documentado
en la lista de invariantes de AGENTS.md**.

```c
static struct work_struct rtw_ep_reset_work;
static _adapter *rtw_ep_reset_padapter;
static struct recv_buf *rtw_ep_reset_recvbuf;
```

`rtw_usb_ep_reset_work_init()` se llama en `usb_intf.c:1269` (probe). **No existe ninguna
llamada a `cancel_work_sync()` / `flush_work()` en disconnect ni en unload.** Si un URB
hace stall y el trabajo queda encolado mientras se desconecta el adaptador o se hace
`modprobe -r`, el worker despierta con `rtw_ep_reset_padapter` apuntando a memoria liberada
y llama a `rtw_read_port()` sobre ella → oops.

**Arreglo mínimo**: exportar un `rtw_usb_ep_reset_work_deinit()` con `cancel_work_sync(&rtw_ep_reset_work)`
e invocarlo en el path de disconnect, antes de liberar el adapter.

### 🔴 A2 · Estado global compartido en el mismo parche → carrera entre URBs

Las tres variables son `static` de fichero, no por adaptador. Si dos URBs stallan antes de
que el worker corra, el segundo pisa `rtw_ep_reset_recvbuf`: el primer `recv_buf` nunca se
reencola (fuga de buffer de RX) o se reencola dos veces el mismo. El propio comentario
admite la limitación ("Single-adapter assumption"), pero la carrera existe **con un solo
adaptador**, porque hay varios URBs de RX en vuelo simultáneamente.

**Arreglo**: mover el `work_struct` y el `recv_buf` pendiente a `struct dvobj_priv` /
`struct recv_priv`, o usar una cola de trabajos con el `recv_buf` como payload.

### 🟠 A3 · Orden invertido: se marca `surprise_removed` antes de intentar la recuperación

`usb_ops_linux.c:880-889` (`usb_read_port_complete`):

```c
if (rtw_inc_and_chk_continual_io_error(...) == _TRUE)
        rtw_set_surprise_removed(padapter);   /* ← primero se mata */

switch (purb->status) {
case -EPIPE:
        ...                                    /* ← luego se intenta recuperar */
        _set_workitem(&rtw_ep_reset_work);
```

Al llegar al umbral (`MAX_CONTINUAL_IO_ERR = 80`) el adaptador queda marcado como removido
y **acto seguido** se programa un clear_halt que reencolará RX sobre un adaptador ya
declarado muerto. El worker además llama a `rtw_reset_continual_io_error()`, dejando el
contador y el flag en estados contradictorios. Debería comprobarse `rtw_is_surprise_removed()`
al principio del worker y abortar.

### 🟠 A4 · El parche de `-EPIPE` en TX puede impedir la detección de un fallo real

`usb_ops_linux.c:575-588` (`urb_write_port_complete`): ante `-EPIPE`/`-EPROTO` se llama
**siempre** a `rtw_reset_continual_io_error()`. Un endpoint permanentemente en halt genera
`-EPIPE` indefinidamente y el contador nunca sube → nunca se escala a `surprise_removed`
→ la interfaz queda TX-muerta en silencio, sin recuperación automática.

**Arreglo propuesto**: contador separado para EPIPE/EPROTO con umbral propio (p. ej. 200)
en vez de reset incondicional; conserva la tolerancia al channel switch sin perder la
detección de fallo permanente.

### 🟠 A5 · `phydm_set_l2h_th_ini_carrier_sense()` no recalcula al cambiar de modo

`hal/phydm/phydm_adaptivity.c:350-355` — el guard `if (dm->th_l2h_ini != 0) return;` cumple
su objetivo (respetar el `module_param`), pero **también bloquea el recálculo legítimo**
cuando el driver cambia de `carrier_sense` a otro modo de adaptivity en runtime, o tras un
cambio de banda. El valor queda congelado al de arranque.

**Arreglo**: guardar el valor del usuario en un campo aparte (`dm->th_l2h_ini_user`) y
aplicarlo solo si el registry lo definió, en lugar de cortocircuitar la función entera.

### 🟡 A6 · `os_intfs.c.mine` — conflicto de merge sin resolver en el índice

El sufijo `.mine` es el que genera un merge conflictivo. `diff` contra `os_intfs.c` muestra
que difieren. Está en el repo, no se compila, y confunde a cualquier herramienta de
indexado (cscope/ctags lo indexan y devuelven definiciones duplicadas de los mismos
símbolos). Borrar ambos: la historia de Git ya los cubre.

### 🟡 A7 · Ficheros con finales de línea CRLF mezclados

`os_dep/linux/rhashtable.c` (no compilado) tiene CRLF. Con `.gitattributes` ausente esto
produce diffs espurios. Normalizar o borrar el fichero.

### 🟡 A8 · 457 bloques `#if 0` en código compilado

Código muerto conservado "por si acaso" desde upstream. La skill `unifdef-coan` lo elimina
de forma segura: `unifdef -D0` no aplica, hay que usar `coan source --replace -m` o una
regla Coccinelle. No es urgente, pero infla la lectura del árbol.

### 🟡 A9 · 309 usos de `sprintf`/`strcpy`/`strcat` en ficheros compilados

Patrón desaconsejado explícitamente por `docs.kernel.org/process/deprecated.html`. La
mayoría son formateo de buffers de debug con tamaño controlado, pero cada uno es un
desbordamiento potencial. Migración mecánica a `snprintf`/`scnprintf` con Coccinelle.

### 🟡 A10 · `hal/hal_hci/` y `core/rtw_sdio.c` referenciados condicionalmente

`core/rtw_sdio.c` solo entra con `CONFIG_SDIO_HCI = y` (línea 2411). Es dead code seguro de
borrar **si** se descarta para siempre el soporte SDIO.

---

## 4. ESTADO — qué se aplicó el 2026-08-22 (v1.6.3)

| Hallazgo | Estado | Cambio |
|---|---|---|
| A1 use-after-free del work | ✅ **corregido** | `rtw_usb_ep_reset_work_deinit()` con `_cancel_workitem_sync()`, llamado al inicio de `rtw_dev_remove()` |
| A2 carrera entre URBs | ✅ corregido | `rtw_ep_reset_pending` (atomic) + `rtw_ep_reset_schedule()`; un único work encolado |
| A3 orden invertido | ✅ corregido | `-EPIPE` ya no escala por el contador genérico; el worker aborta si `surprise_removed`/`drv_stopped` |
| A4 EPIPE sin techo | ✅ corregido | `MAX_USB_STALL_ERR = 200` + `dvobj->usb_stall_err`; se resetea en cada TX/RX correcto |
| A6 `.backup` / `.mine` | ✅ borrados | |
| Clones Windows / case-duplicados | ✅ borrados | `HalBtc8192e{1,2}Ant.{c,h}`, `halphyrf_win.c`, `halrf_powertracking_win.c`, `halrf_8192e_win.c`, `phydm_powertracking_win.c` |
| 2.4 `make clean` incompleto | ✅ corregido | `find` de profundidad ilimitada en vez de globs fijos |
| 2.1 objetos vacíos | ✅ 12 de 16 | movidos a `$(MODULE_NAME)-$(CONFIG_X) +=` |
| A5 `th_l2h_ini` congelado | ⏳ pendiente | requiere prueba en hardware |
| A8 `#if 0` · A9 `sprintf` | ⏳ pendiente | transformación masiva con Coccinelle |
| §1 48 ficheros no compilados | ⏳ parcial | borrados los 10 clones; quedan 38 |

**Resultado medible:** fuente compilada **152 → 135 ficheros, 9.0 → 8.03 MB**.

### ⚠️ Hallazgo nuevo durante la corrección

Tres objetos que parecían "vacíos" **no** se pueden excluir del build:

- `core/rtw_btcoex.o` — `rtw_btcoex_set_ant_info()` y `rtw_btcoex_connect_notify()` están
  **fuera** del `#ifdef CONFIG_BT_COEXIST` (a partir de la línea 1774) y se llaman sin guard
  desde `hal/rtl8192e/usb/usb_halinit.c:1488`. Excluirlo rompe el link.
- `core/rtw_btcoex_wifionly.o` — **no tiene guard alguno**; se llama desde `usb_intf.c:1128`.
- `hal/hal_btcoex_wifionly.o` — depende del anterior.

Confirma la regla de la skill `code-navigation`: comprobar el guard **y** los llamadores
antes de excluir nada.

### Bluetooth: cómo activarlo en el futuro

El soporte BT queda **completo en el árbol y activable en un solo sitio**:

```make
# driver/Makefile
CONFIG_BT_COEXIST = y
```

Eso enciende `hal/btc/halbtc8192e1ant.o`, `halbtc8192e2ant.o` (`_BTC_FILES`),
`hal/hal_btcoex.o` y `core/rtw_btcoex.o`, además del `-DCONFIG_BT_COEXIST`. Con `n` se
compilan 469 KB menos y el driver queda idéntico al actual.

---

## 5. Plan restante (orden de menor a mayor riesgo)

1. Borrar los 38 ficheros no compilados restantes de la §1, por grupos y un commit por grupo, comprobando guards **y llamadores** antes de cada borrado.
2. A5: `th_l2h_ini` — mover el valor del usuario a un campo propio en vez de cortocircuitar la función. Requiere validar EDCCA en hardware.
3. A8 (`#if 0`) y A9 (`sprintf` → `scnprintf`) con Coccinelle.
4. A7: normalizar finales de línea con `.gitattributes`.

**Verificación obligatoria tras cada paso**: `make clean && make -j` → `modinfo -p` →
`bloat-o-meter` contra el `.ko` anterior → ping al gateway.
