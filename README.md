# rtl8192eu-linux — TL-WN8200ND Driver

> ⚠️ **ADVERTENCIA — CÓDIGO DE NIVEL KERNEL (RING 0)**
> Este paquete contiene un módulo del kernel de Linux. Errores en la compilación, instalación o ejecución pueden causar inestabilidad del sistema, kernel panics, pérdida de datos o caídas de red. Utilícelo bajo su propia responsabilidad. Realice siempre una copia de seguridad antes de instalar.

## Descripción

Driver optimizado para el adaptador WiFi TP-Link TL-WN8200ND basado en el chipset **Realtek RTL8192EU** (USB 2.0, 802.11n 2T2R). 

### Chipsets y revisiones HW soportados

| Revisión | Chipset | USB ID | Estado |
|----------|---------|--------|--------|
| TL-WN8200ND(UN) V1 | RTL8192CU | 2357:0106 | No soportado |
| **TL-WN8200ND(UN) V2** | **RTL8192EU** | **2357:0126** | **Soportado** |
| **TL-WN8200ND(UN) V3** | **RTL8192EU** | **2357:0126** | **Soportado** (este fork) |

### Funcionalidades conocidas

| Funcionalidad | Estado |
|---------------|--------|
| STA (cliente WiFi) | ✅ Funcional |
| AP (punto de acceso) | ⚠️ No probado |
| Monitor mode | ❌ Deshabilitado en este fork |
| Packet injection | ❌ Deshabilitado en este fork |
| WPA2/WPA3 | ✅ Funcional |
| 2.4 GHz HT20/HT40 | ✅ Funcional |
| 2×2 MIMO | ✅ Forzado (rtw_trx_path_bmp=0x33) |

## Versiones / Version

Driver optimizado para Realtek RTL8192EU en kernels modernos. Basado en el trabajo de [clnhub/rtl8192eu-linux](https://github.com/clnhub/rtl8192eu-linux) (rama `5.11.2.3`).

## Estructura del repositorio

```
rtl8192eu-linux/
├── driver/               # Código fuente del módulo del kernel
│   ├── core/             # Funciones centrales del driver
│   ├── hal/              # Capa de abstracción de hardware (HAL)
│   ├── include/          # Archivos de cabecera
│   ├── os_dep/           # Dependencias del sistema operativo
│   ├── platform/         # Soporte de plataforma
│   ├── Makefile          # Archivo de compilación
│   └── Kconfig           # Configuración del kernel
├── docs/                 # Documentación
│   ├── BACKPORT_REPORT.md   # Análisis de backport de código oficial
│   ├── DRIVER_BIBLE.md      # Documentación técnica del driver
│   ├── BUGS.md              # Bugs conocidos y diagnóstico
│   └── notes/               # Notas adicionales
├── research/             # Scripts y análisis
│   ├── re_analysis/      # Ingeniería inversa del driver Windows
│   └── analysis/         # Análisis de backport
├── dkms.conf             # Configuración de DKMS
├── Makefile              # Makefile de reenvío (delega a driver/)
├── install_wifi.sh       # Script de instalación
├── uninstall_wifi.sh     # Script de desinstalación
└── README.md             # Este archivo
```

## Optimizaciones aplicadas / Optimizations Applied

### Optimizaciones clave / Key Optimizations:
- **rtw_trx_path_bmp=0x33**: Fuerza 2×2 MIMO (TX+RX en ambas antenas)
- **rtw_antdiv_cfg=1**: Diversity de antena siempre activada
- **rtw_TxBBSwing_2G=255**: Potencia máxima en 2.4GHz
- **rtw_adaptivity_mode=1**: Modo adaptativo para interferencia

### Parámetros hardcodeados para estabilidad USB
- `rtw_en_napi = 0` — NAPI desactivado
- `rtw_usb_rxagg_mode = 0` — Agregación USB desactivada
- `rtw_dynamic_agg_enable = 0` — Agregación dinámica desactivada
- `rtw_enusbss = 0` — USB autosuspend desactivado
- `MAX_CONTINUAL_IO_ERR = 30` — Tolerancia a errores I/O USB aumentada

### Opcionales / Optional:
- **CONFIG_NARROWBAND_SUPPORTING**: Soporte para banda estrecha (5M/10M)

## Requisitos / Requirements

| Dependencia | Propósito |
|-------------|-----------|
| `linux-headers-$(uname -r)` | Encabezados del kernel para compilar módulos |
| `build-essential` | Compilador GCC y herramientas |
| `bc` | Calculadora para el sistema de compilación |
| `git` | Control de versiones |
| `dkms` | Sistema de módulos del kernel (recomendado) |

### Matriz de kernels probados

| Kernel | x86_64 | ARM | Notas |
|--------|--------|-----|-------|
| 5.15.x | ✅ | ❌ | No probado |
| 6.1.x  | ✅ | ❌ | No probado |
| 6.5.x  | ✅ | ❌ | No probado |
| 6.12.x | ✅ | ❌ | Probado en Debian Trixie (6.12.90+deb13.1) |

## Instalación rápida / Quick Install

```bash
# 1. Instalar dependencias
sudo apt update
sudo apt install -y linux-headers-$(uname -r) build-essential bc git dkms

# 2. Clonar e instalar
git clone https://github.com/MoriNo23/TL-WN8200ND-driver.git
cd TL-WN8200ND-driver
./install_wifi.sh

# 3. Verificar
lsmod | grep 8192eu
```

## Desinstalación / Uninstall

```bash
cd TL-WN8200ND-driver
./uninstall_wifi.sh
```

## Parámetros del módulo

| Parámetro | Default en este fork | Descripción |
|-----------|---------------------|-------------|
| `rtw_enusbss` | 0 | USB autosuspend (0=desactivado) |
| `rtw_en_napi` | 0 | NAPI (0=desactivado) |
| `rtw_usb_rxagg_mode` | 0 | Agregación USB RX |
| `rtw_dynamic_agg_enable` | 0 | Agregación dinámica |
| `rtw_trx_path_bmp` | 0x33 | Máscara de rutas 2×2 MIMO |
| `rtw_antdiv_cfg` | 1 | Diversidad de antena |
| `rtw_adaptivity_mode` | 1 | Modo adaptativo |
| `rtw_TxBBSwing_2G` | 255 | Potencia máxima TX 2.4GHz |
| `rtw_low_power` | 0 | Modo bajo consumo |
| `rtw_smart_ps` | 2 | Power saving inteligente |

## Notas / Notes

- **Valores hardcodeados**: Los parámetros óptimos están hardcodeados en `driver/os_dep/linux/os_intfs.c`
- **Usa siempre corriente**: Optimizado para laptops conectadas, sin batería
- **No usar configuraciones de ahorro**: Las mejoras de batería no son para este uso

## Bugs conocidos

Ver [docs/BUGS.md](docs/BUGS.md) para la lista completa de bugs conocidos y procedimientos de diagnóstico.

### Bug 1: Interferencia esporádica
- **Síntomas**: Pérdida de paquetes intermitente, latencia elevada sin saturación del canal
- **Frecuencia**: Esporádica, no reproducible bajo demanda
- **Estado**: Bajo investigación — ver [docs/BUGS.md](docs/BUGS.md) para detalles

### Bug 2: Crash que requiere modprobe cycle
- **Síntomas**: La interfaz WiFi deja de responder, solo se recupera con `sudo modprobe -r 8192eu && sudo modprobe 8192eu`
- **Causa probable**: Umbral de errores I/O USB excedido o error en recuperación de URB
- **Workaround**: 
  ```bash
  sudo rmmod 8192eu
  sudo modprobe 8192eu
  ```

## Créditos / Credits

- **[Mange/rtl8192eu-linux-driver](https://github.com/Mange/rtl8192eu-linux-driver)** — Repositorio base original del driver para kernels modernos
- **[clnhub/rtl8192eu-linux](https://github.com/clnhub/rtl8192eu-linux)** — Fork de Mange con actualizaciones adicionales (rama `5.11.2.3` usada como upstream de este fork)
- **Realtek Semiconductor Corp.** — Desarrollador original del controlador (licencia GPLv2)
- **TP-Link Technologies** — Fabricante del adaptador TL-WN8200ND

### Cambios realizados en este fork
- Hardcodeo de parámetros de estabilidad USB (rtw_en_napi=0, rtw_usb_rxagg_mode=0, rtw_dynamic_agg_enable=0)
- Aumento de tolerancia a errores I/O (MAX_CONTINUAL_IO_ERR: 4→30)
- Desactivación forzada de USB autosuspend
- Corrección de URB leak en transmisión de management frames
- Mensajes de diagnóstico en dmesg para depuración
- Adición de flujo de trabajo CI en GitHub Actions
- Reestructuración del repositorio (carpetas driver/, docs/, research/)
- Análisis de backport contra código fuente oficial Realtek v4.4.1.1

## Aviso legal / Legal Disclaimer

**No afiliación:** Este proyecto no está afiliado, respaldado ni patrocinado por TP-Link Technologies Co., Ltd. ni por Realtek Semiconductor Corp. TP-Link y Realtek son marcas registradas de sus respectivos propietarios.

**Licencia:** El código fuente de este driver se distribuye bajo los términos de la GNU General Public License v2 (GPLv2), tal como lo exige el uso de APIs del kernel de Linux. Ver el archivo [LICENSE](LICENSE) para más detalles.

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

- **2026-06-10**: DVD oficial respaldado en `dvd-backup/` (TL-WN8200ND(UN) V2.0)
- **2026-04-26**: Commit `c822e42` — Fix USB stability for low-RAM systems
  - Disable USB autosuspend (rtw_enusbss=0 forced)
  - Increase MAX_CONTINUAL_IO_ERR from 10 to 30
  - Add DRIVER_DEBUG diagnostic message
  - Fix URB leak in management xmit callback


https://github.com/MoriNo23/TL-WN8200ND-driver
