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

https://github.com/MoriNo23/TL-WN8200ND-driver
