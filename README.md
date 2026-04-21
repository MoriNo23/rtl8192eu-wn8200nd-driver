# rtl8192eu-linux

## Versión / Version

Driver optimizado para Realtek RTL8192EU en kernels modernos.

## Optimizaciones aplicadas / Optimizations Applied (TL-WN8200ND V3)

### Optimizaciones clave / Key Optimizations:
- **rtw_trx_path_bmp=0x33**: Fuerza 2x2 MIMO (TX+RX en ambas antenas)
- **rtw_antdiv_cfg=1**: Diversity de antena siempre activada
- **rtw_TxBBSwing_2G=255**: Potencia máxima en 2.4GHz
- **rtw_adaptivity_mode=1**: Modo adaptativo para interferencia

### Opcionales / Optional:
- **CONFIG_NARROWBAND_SUPPORTING**: Soporte para banda estrecha (5M/10M) - Solo si usas redes congestionadas / Narrowband support (5M/10M) - Only if using congested networks

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
- **Usa siempre corriente**: Optimizado para laptops conectadas, sin batería / Always use power: Optimized for laptops always connected (no battery)
- **No usar configuraciones de ahorro**: Las mejoras de batería (LPS, WOWLAN) NO son para este uso / Do NOT enable power saving features (incompatible with always-on usage)

## Idiomas soportados / Supported Languages
- English - README.md
- Español - README.md (versión en español)

## Enlace / Link
https://github.com/MoriNo23/rtl8192eu-linux

## Mejoras Agresivas de Rendimiento / Aggressive Performance Optimizations

### Optimizaciones Clave Activadas / Key Optimizations Activated:
- **2x2 MIMO Forzado** (`0x33`): Máximo throughput en ambas bandas
- **Potencia Máxima** (`255`): Alcance y velocidad óptimos
- **NAPI + GRO**: Reduce CPU usage en redes concurridas
- **A-MPDU + A-MSDU**: Agregación dual de hasta 64 frames
- **Adaptive Rate**: Ajuste dinámico según calidad de señal
- **Coexistencia BT**: Gestión automática de interferencias

### Para Máximo Throughput / For Maximum Throughput:
```bash
# Ya configurado: rtw_low_power=0, rtw_smart_ps=0
# Desactivado: adaptativo agresivo para rendimiento puro
```

### Resultado / Result:
- ⚡ **Máximo throughput** en laptop siempre enchufada
- 📶 **Estabilidad óptima** con balance adaptativo
- 🔋 **Sin límites de energía**
