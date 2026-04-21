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
- `rtw_smart_ps` - Power Save → Liberar para CPU
- `rtw_lps_level` - Nivel LPS → Liberar para CPU
- `rtw_ips_mode` - Modo IPS → Liberar para CPU
- `rtw_btcoex_enable` - Coexistencia BT → Liberar si no usas BT
- `rtw_usb_rxagg_mode` - Agregación USB → Liberar si no usas USB
- `rtw_en_napi` - NAPI → Liberar si no usas streaming
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
