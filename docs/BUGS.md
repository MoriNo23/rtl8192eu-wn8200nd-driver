# Bugs Conocidos — rtl8192eu TL-WN8200ND Driver

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
