# rtl8192eu-linux-OptimizedFork

Driver optimizado para Realtek RTL8192EU en kernels modernos.

## Optimizaciones aplicadas (TL-WN8200ND V3)
- **rtw_trx_path_bmp=0x33**: Fuerza 2x2 MIMO (TX+RX en ambas antenas)
- **rtw_antdiv_cfg=1**: Diversity de antena siempre activada
- **rtw_TxBBSwing_2G=255**: Potencia máxima en 2.4GHz
- **rtw_adaptivity_mode=1**: Modo adaptativo para interferencia

## Requisitos
- linux-headers-generic, build-essential, dkms, git

## Instalación rápida
```bash
./install_wifi.sh
```

## Desinstalación
```bash
./uninstall_wifi.sh
```

## Notas
- Valores hardcodeados en `os_dep/linux/os_intfs.c`
- Compatible con kernels 5.x - 7.x
