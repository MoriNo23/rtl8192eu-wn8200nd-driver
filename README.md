# rtl8192eu-linux

## Version / Version

Driver optimizado para Realtek RTL8192EU en kernels modernos.

## Optimizaciones aplicadas / Optimizations Applied (TL-WN8200ND V3)

### Optimizaciones clave / Key Optimizations:
- **rtw_trx_path_bmp=0x33**: Fuerza 2x2 MIMO (TX+RX en ambas antenas)
- **rtw_antdiv_cfg=1**: Diversity de antena siempre activada
- **rtw_TxBBSwing_2G=255**: Potencia máxima en 2.4GHz
- **rtw_adaptivity_mode=1**: Modo adaptativo para interferencia

### Opcionales / Optional:
- **CONFIG_NARROWBAND_SUPPORTING**: Soporte para banda estrecha (5M/10M)

## Requisitos / Requirements

- linux-headers-generic, build-essential, dkms, git
- kernel 5.x - 7.x compatible

## Instalación rápida / Quick Install

```bash
./install_wifi.sh
```

## Desinstalación / Uninstall

```bash
./uninstall_wifi.sh
```

## Notas / Notes

- **Valores hardcodeados**: Los parámetros óptimos están hardcodeados en `os_dep/linux/os_intfs.c`
- **Usa siempre corriente**: Optimizado para laptops conectadas, sin batería
- **No usar configuraciones de ahorro**: Las mejoras de batería no son para este uso

## Idiomas soportados / Supported Languages
- English - README.md
- Español - README.md (versión en español)

## Enlace / Link
https://github.com/MoriNo23/rtl8192eu-linux

## ⚡ Mejoras de Rendimiento (Performance Optimizations)

### Módulos que disminuyen CPU (Modules that reduce CPU usage):
- `rtw_low_power` - Modo bajo consumo → Liberar para CPU
- `rtw_dynamic_agg_enable` - 0 (hardcodeado en source)
- `rtw_smart_ps` - Power Save → Liberar para CPU
- `rtw_lps_level` - Nivel LPS → Liberar para CPU
- `rtw_ips_mode` - Modo IPS → Liberar para CPU
- `rtw_btcoex_enable` - Coexistencia BT → Liberar si no usas BT
| `rtw_usb_rxagg_mode` | 0 - Agregación USB → Liberar si no usas USB (hardcodeado a 0 en source)
| `rtw_en_napi` | 0 - NAPI → Liberar si no usas streaming (hardcodeado a 0 en source)
- `rtw_en_gro` - Agregación GRO → Liberar si no usas streaming

### Para liberar módulos (e.g., laptop sin BT/USB):
```bash
sudo -S -p '' rmmod btusb  # Si no usas Bluetooth
sudo -S -p '' rmmod 8192eu  # Luego: make && sudo -S -p '' insmod 8192eu.ko
```

### Parámetros de rendimiento (tu configuración actual):
```
rtw_trx_path_bmp=0x33    → 2x2 MIMO forzado (máximo throughput)
rtw_antdiv_cfg=1         → Diversity siempre activada
rtw_TxBBSwing_2G=255     → Potencia máxima 2.4GHz
rtw_adaptivity_mode=1    → Adaptativo para interferencia
rtw_low_power=0          → Sin ahorro (máximo rendimiento)
rtw_btcoex_enable=2      → Coexistencia BT automática
```

### Resultado:
- ⚡ **Máximo throughput** en laptop siempre enchufada
- 📶 **Estabilidad óptima** con balance adaptativo
- 🔋 **Sin límites de energía** (corriente)


## 🔧 Estabilidad USB / USB Stability Fixes

### Problema identificado / Problem Identified

El driver original presentaba micro-cortes y pérdida de paquetes en puertos USB 2.0 debido a:

1. **USB autosuspend conflictivo**: El parámetro `rtw_enusbss` se habilitaba bajo `CONFIG_USB_AUTOSUSPEND`, causando suspensión/reactivación del bus USB que generaba micro-desconexiones.
2. **Threshold de errores I/O demasiado sensible**: `MAX_CONTINUAL_IO_ERR = 10` activaba `surprise_removed` tras pocos errores transitorios en USB 2.0.
3. **Memory leak en transmisión**: Los URBs de gestión no se liberaban correctamente en el path de completación, causando fugas.
4. **Falta de diagnóstico**: No había logs claros para identificar el threshold.

### Cambios aplicados / Changes Applied

#### 1. Desactivación forzada de USB autosuspend
**Archivo**: `os_dep/linux/os_intfs.c`

```c
#ifdef CONFIG_USB_AUTOSUSPEND
/* int rtw_enusbss = 1; */ /* DESACTIVADO */
#else
int rtw_enusbss = 0;
#endif
```

**Efecto**: El driver nunca activa el autosuspend USB, previniendo micro-cortes por suspensión del bus.

#### 2. Aumento de tolerancia a errores I/O
**Archivo**: `include/rtw_io.h`

```c
#ifdef CONFIG_USB_HCI
#define MAX_CONTINUAL_IO_ERR 30  /* Era 10 */
#endif
```

**Efecto**: El driver tolera 3× más errores USB antes de marcar el dispositivo como "removido sorpresivamente".

#### 3. Mensaje de diagnóstico
**Archivo**: `core/rtw_io.c`

```c
if (value > MAX_CONTINUAL_IO_ERR) {
    RTW_INFO("[dvobj:%p][ERROR] continual_io_error:%d > %d\n", ...);
    RTW_INFO("=== DRIVER_DEBUG: Umbral de error I/O alcanzado. Posible micro-desconexión USB detectada. ===\n");
    ret = _TRUE;
}
```

**Efecto**: Aparece un mensaje claro en `dmesg` cuando se supera el threshold, permitiendo confirmar/descargar el problema.

#### 4. Corrección de URB leak
**Archivo**: `hal/rtl8192e/usb/rtl8192eu_xmit.c`

- Eliminada liberación prematura de URB inmediatamente después de `usb_submit_urb()`
- El callback `rtl8192eu_hostap_mgnt_xmit_cb` ahora libera el URB con `usb_unanchor_urb()` + `usb_free_urb()`

**Efecto**: Previene use-after-free y fugas de memoria URBs en path de transmisión de management frames.

### Verificación / Verification

#### 1. Confirmar parámetros cargados
```bash
cat /sys/module/8192eu/parameters/rtw_enusbss
# Debe mostrar: 0
```

#### 2. Monitoreo de diagnóstico en tiempo real
```bash
sudo dmesg -w | grep -E "DRIVER_DEBUG|surprise|error.*8192eu"
```

Deja esto corriendo en un `tmux` mientras usas la red intensivamente. Si ves `DRIVER_DEBUG`, significa que el threshold se activó (errores USB reales).

#### 3. Forzar estrés para exponer fallos
```bash
# Descarga continua de archivo grande
while true; do wget -O /dev/null http://speedtest.tele2.net/100MB.zip; done

# O con curl
curl -o /dev/null http://speedtest.tele2.net/1GB.zip &
```

Observa si aparecen mensajes de diagnóstico o desconexiones.

### Ajustes adicionales si persisten los problemas / Further Tuning

Si tras estos cambios aún hay inestabilidad, prueba estos parámetros vía `modprobe`:

```bash
# 1. Desactivar NAPI (reduce latencia pero aumenta CPU)
sudo modprobe -r 8192eu
sudo modprobe 8192eu rtw_en_napi=0

# 2. Desactivar agregación USB (canal único, menos congestión)
sudo modprobe -r 8192eu
sudo modprobe 8192eu rtw_usb_rxagg_mode=0 rtw_dynamic_agg_enable=0

# 3. Combinación estable para USB 2.0 antiguo
sudo modprobe -r 8192eu
sudo modprobe 8192eu rtw_enusbss=0 rtw_en_napi=0 rtw_usb_rxagg_mode=0

# 4. Asegurar power management USB a nivel kernel
for d in /sys/bus/usb/devices/*/power/control; do echo on | sudo tee $d; done
```

### Diagnóstico de Umbral (Threshold Diagnostics)

Si ves el mensaje:
```
=== DRIVER_DEBUG: Umbral de error I/O alcanzado. Posible micro-desconexión USB detectada. ===
```

Esto indica errores I/O reales en el bus USB (>30 en corto período). Causas comunes:

- Cable USB defectuoso o muy largo (>1m sin hub activo)
- Hub USB sin alimentación suficiente
- Puerto USB 3.x que retrocede a USB 2.0 con interferencia
- Overcurrent en el puerto (otros dispositivos consumiendo)
- Problemas de timing en chipset Intel Sandy Bridge (tu caso)

**Solución hardware**: Cambiar cable, usar puerto directo (no hub), conectar a puerto en motherboard trasero.

### Historial de cambios / Changelog

- **2026-04-26**: Commit `c822e42` — Fix USB stability for low-RAM systems
  - Disable USB autosuspend (rtw_enusbss=0 forced)
  - Increase MAX_CONTINUAL_IO_ERR from 10 to 30
  - Add DRIVER_DEBUG diagnostic message
  - Fix URB leak in management xmit callback

