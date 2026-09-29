# Bugs Conocidos — rtl8192eu TL-WN8200ND Driver

## Bug 3: Panic del kernel al cargar con CONFIG_TXPWR_LIMIT=y

**ID:** BUG-TXPOWER-001
**Estado:** 🚫 Evitado (flag revertido a `n`); causa raíz identificada
**Severidad:** Crítica (el modulo no carga: kernel panic en `modprobe`)
**Descubierto:** 2026-09-28, en la maquina de despliegue (kernel 6.12.107+deb13-amd64, gcc-14)
**Afecta:** Cualquier build con `CONFIG_TXPWR_LIMIT = y` en kernel con `CONFIG_FORTIFY_SOURCE`

### Sintomas

```
modprobe 8192eu   ->  Violación de segmento del propio modprobe
dmesg:
  strlen: detected buffer overflow: 1 byte read of buffer size 0
  WARNING ... at lib/string_helpers.c:1032 __fortify_report
  Oops: invalid opcode   (-> __fortify_panic: panic INTENCIONADO de FORTIFY)
  Tainted: G|U|O|E
```

Pila completa:

```
rtw_txpwr_lmt_add_with_nlen.cold  <- rtw_rf.c:1819, el strlen
rtw_txpwr_lmt_add                 <- inline, rtw_rf.c:1888
phy_set_tx_power_limit            <- hal_com_phycfg.c
odm_read_and_config_mp_8192e_txpwr_lmt
odm_config_rf_with_header_file
phy_load_tx_power_limit
rtw_init_drv_sw
rtw_drv_init / rtw_drv_entry      <- module_init: ANTES de tocar el USB
```

### Causa raiz (verificada en el codigo, no hipotesis)

1. `struct txpwr_lmt_ent` termina en `char regd_name[0]` (`hal_data.h:345`):
   un array de TAMANO CERO, el idioma pre-C99 de flexible array member.
2. La reserva es correcta: `rtw_zvmalloc(sizeof(struct txpwr_lmt_ent) + nlen + 1)`
   (`rtw_rf.c:1825`) y `_rtw_zvmalloc` hace `memset(0)` del bloque
   (`osdep_service.c:102-109`), asi que el terminador NUL existe en el byte
   `[nlen]`. **No hay desbordamiento real.**
3. El reventazo es la RELECTURA: el bucle de busqueda hace
   `strlen(ent->regd_name)` (`rtw_rf.c:1819`) sobre un `ent` que sale de
   `LIST_CONTAINOR` (container_of artesanal, `osdep_service_linux.h:251`).
4. GCC no puede rastrear la procedencia del puntero hasta el `vmalloc`, asi que
   calcula el tamano del objeto via la declaracion: `regd_name[0]` = **0 bytes**.
   El `__fortify_strlen` del kernel ve "leer de un buffer de tamano 0" y llama
   a `__fortify_panic`, que es un panic deliberado: el kernel prefiere parar a
   seguir con un acceso que no puede demostrar seguro.

### La prueba del gemelo

`rtw_regd_exc_add_with_nlen` (`rtw_rf.c:1418`) hace **exactamente** la misma
reserva (`+ nlen + 1`) con la misma struct `char regd_name[0]` — y NO revienta.
Diferencia unica: **nunca relee** `regd_name` despues del `memcpy`. El panic
aparece solo en la funcion que relee. Eso acota el fallo a la relectura, no a la
reserva.

Detalle que confirma el analisis: la PRIMERA llamada no revienta (la lista esta
vacia, el bucle no se ejecuta). Revienta en la segunda en adelante, cuando ya
hay una entrada que rebuscar — y el module_init carga varios dominios
regulatorios del RF header, asi que siempre llega a la segunda.

### Workaround (lo que se ha hecho)

`CONFIG_TXPWR_LIMIT = n` y `CONFIG_TXPWR_LIMIT_EN = n` en `driver/Makefile`
(desde la version 1.8.1 del paquete DKMS). Es ademas el default de fabrica de
esta familia de drivers: el estado historico del arbol upstream.

Coste asumido: con `n`, `lmt` y `ulmt` salen `NA` en la tabla de potencias — el
driver no calcula limites regulatorios. Bajo el dominio actual (mundo/US en
2.4 GHz, techo de 20 dBm) y con el objetivo del efuse (13 dBm HT) no recorta
nada en la practica; lo que se pierde es la garantia.

### Arreglo posible (NO verificado, hipotesis para un change futuro)

Declarar el miembro como flexible array member moderno (`char regd_name[]` en
`hal_data.h:345`) para que `__builtin_object_size` devuelva "desconocido" en
lugar de 0 y FORTIFY salte la comprobacion. Es un cambio de una linea mas los
sitios que dependan del tipo, PERO no se ha compilado ni probado. No activar
`CONFIG_TXPWR_LIMIT` sin cerrar antes esta seccion.

### El agujero del CI (falso negativo SIN explicar)

Los 8 jobs del CI dieron verde con `CONFIG_TXPWR_LIMIT = y` en el commit
`b603720`, **incluido `vm-load-test`, que carga ese mismo `.ko` de verdad en
una VM**. El panic ocurre en `rtw_drv_entry`, que corre en el `module_init`
ANTES de cualquier acceso al hardware, asi que la ausencia del dongle en la VM
no lo explica. Mismo source, mismo kernel de Debian... y sin panic alli.

No se ha determinado por que. Hasta que se explique, `vm-load-test` NO sirve
como garantia contra regresiones de esta clase (fortify/analisis estatico del
compilador), y hay que tratar cualquier cambio en esa zona como no verificado
por el CI.

## Bug 1: Interferencia esporádica (bajo investigación)

**ID:** BUG-INT-001  
**Estado:** 🔍 Bajo investigación  
**Severidad:** Media  
**Frecuencia:** Esporádica (no reproducible bajo demanda)  
**Afecta:** Rendimiento y latencia de la conexión WiFi

### Síntomas
- Pérdida de paquetes intermitente (5-20% durante episodios de 1-5 segundos)
- Latencia elevada (>200ms) sin saturación del canal
- No hay mensajes de error en `dmesg` durante los episodios
- La conexión se recupera espontáneamente

### Diagnóstico
Para capturar evidencia durante un episodio:

```bash
# Monitor de diagnóstico en tiempo real
sudo dmesg -w | grep -E "DRIVER_DEBUG|surprise|error|rtl8192eu" &

# Ping continuo al gateway
ping -c 100 -i 0.1 -I wn8200nd 192.168.1.1

# Verificar canal y señal
iw dev wn8200nd survey dump | grep -A5 "in use"
```

### Hipótesis
1. **Interferencia en canal 2.4GHz** — Canales vecinos, microondas, Bluetooth
2. **USB autosuspend a nivel de hub** — Aunque el driver lo desactiva, el hub USB root puede suspenderse
3. **Firmware** — Timers o estados internos del chip RTL8192EU

### Comandos para recolección de datos
```bash
# Nivel de señal y ruido
watch -n 1 "cat /proc/net/wireless"

# Errores de transmisión
ip -s link show wn8200nd

# Estadísticas del driver (si está disponible)
cat /sys/kernel/debug/ieee80211/phy*/stats 2>/dev/null
```

---

## Bug 2: Crash que requiere modprobe cycle

**ID:** BUG-CRSH-002  
**Estado:** 🔧 Workaround documentado  
**Severidad:** Alta  
**Frecuencia:** 1-2 veces por semana en operación 24/7  
**Afecta:** Conectividad WiFi — requiere intervención manual

### Síntomas
- La interfaz WiFi deja de transmitir/recepcionar (estado UP pero sin tráfico)
- `dmesg` muestra ocasionalmente mensajes de error USB
- No se recupera automáticamente
- Única recuperación conocida:

```bash
sudo modprobe -r 8192eu
sudo modprobe 8192eu rtw_enusbss=0 rtw_en_napi=0 rtw_usb_rxagg_mode=0
```

(La recarga del módulo puede omitir los parámetros si están hardcodeados en la fuente.)

### Causa probable
El driver alcanza el umbral `MAX_CONTINUAL_IO_ERR` de errores USB consecutivos y marca el dispositivo como `surprise_removed = TRUE`, lo que detiene toda comunicación. El valor actual de 30 es una mejora sobre el original (4-10), pero no elimina la posibilidad.

**Código sospechoso:**
- `driver/core/rtw_io.c:469-471` — Incremento y verificación de `continual_io_error`
- `driver/os_dep/linux/usb_intf.c` — Manejo de `surprise_removed`
- `driver/hal/rtl8192e/usb/rtl8192eu_xmit.c` — Callbacks de transmisión URB

### Workaround actual
```bash
# Recarga rápida del módulo
sudo modprobe -r 8192eu && sudo modprobe 8192eu
```

### Investigación pendiente
1. ¿Son errores USB reales (hardware) o el driver es demasiado sensible?
2. ¿Podría un `USB_RESET` en lugar de un modprobe cycle recuperar el dispositivo?
3. ¿Hay un leak de URBs que eventualmente agota los recursos?

### Comandos para diagnóstico en vivo
```bash
# Monitoreo de errores USB continuos
sudo dmesg -w | grep -E "surprise|continual_io|DRIVER_DEBUG|USB disconnect"

# Ver si el dispositivo sigue visible en el bus USB
lsusb | grep 2357

# Estado del driver
cat /sys/module/8192eu/parameters/rtw_enusbss
cat /sys/module/8192eu/parameters/rtw_en_napi
cat /sys/module/8192eu/parameters/rtw_usb_rxagg_mode
```

---

## Reportar un bug

Si encuentras un bug no documentado, por favor abre un issue en:
https://github.com/MoriNo23/TL-WN8200ND-driver/issues

Incluye:
1. Kernel version (`uname -a`)
2. Salida de `dmesg` después del incidente
3. Pasos para reproducir (si aplica)
4. Configuración del adaptador (revisión HW, tipo de puerto USB)
