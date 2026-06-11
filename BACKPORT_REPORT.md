# Backport Report — Realtek v4.4.1.1 → optimization-wn8200nd

## Resumen
- Archivos comparados: 351
- Hunks analizados: 3413
- Candidatos totales: 2598
- Candidatos VIABLE: 2175
- Candidatos REQUIERE_ADAPTACION: 423
- Candidatos BLOQUEADA: 0

## Candidatos Viables

Se muestran los top 20 candidatos VIABLE ordenados por directorio (hal/core优先).

### 1. `hal/HalPwrSeqCmd.c` — función `unknown`
- **Cambio:** hal_init (368 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 2. `hal/efuse/efuse_mask.h` — función `unknown`
- **Cambio:** rtl (261 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 3. `hal/efuse/rtl8192e/HalEfuseMask8192E_PCIE.c` — función `unknown`
- **Cambio:** odm_ (195 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 4. `hal/efuse/rtl8192e/HalEfuseMask8192E_PCIE.h` — función `unknown`
- **Cambio:** generic (76 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 5. `hal/efuse/rtl8192e/HalEfuseMask8192E_USB.c` — función `unknown`
- **Cambio:** odm_ (204 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 6. `hal/efuse/rtl8192e/HalEfuseMask8192E_USB.h` — función `unknown`
- **Cambio:** generic (68 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 7. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** generic (2 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 8. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** HAL_ (18 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 9. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** generic (3 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 10. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** generic (9 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 11. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** generic (11 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 12. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** generic (8 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 13. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** generic (25 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 14. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** generic (9 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 15. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** generic (3 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 16. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** generic (10 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 17. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** ps_ (59 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 18. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** ps_ (24 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 19. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** ps_ (4 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)

### 20. `hal/hal_btcoex.c` — función `unknown`
- **Cambio:** ps_ (4 líneas)
- **Impacto esperado:** lógica de hardware/driver portable
- **Kernel compat:** Sin cambios requeridos
- **Prioridad:** alta (archivo hal/core)


## Candidatos que Requieren Adaptación

Se muestran los top 15 candidatos REQUIERE_ADAPTACION.

### 1. `core/rtw_debug.c` — función `unknown`
- **Cambio:** generic (4 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 2. `core/rtw_debug.c` — función `unknown`
- **Cambio:** hw:hal_init,compat:cfg80211 (297 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 3. `core/rtw_debug.c` — función `unknown`
- **Cambio:** generic (21 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 4. `core/rtw_debug.c` — función `unknown`
- **Cambio:** generic (6 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 5. `core/rtw_debug.c` — función `unknown`
- **Cambio:** recv (247 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 6. `core/rtw_debug.c` — función `unknown`
- **Cambio:** hw:recv,compat:cfg80211 (248 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 7. `core/rtw_debug.c` — función `unknown`
- **Cambio:** generic (158 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 8. `core/rtw_debug.c` — función `unknown`
- **Cambio:** generic (7 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 9. `core/rtw_debug.c` — función `unknown`
- **Cambio:** generic (74 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 10. `core/rtw_debug.c` — función `unknown`
- **Cambio:** generic (8 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 11. `core/rtw_debug.c` — función `unknown`
- **Cambio:** HAL_ (127 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 12. `core/rtw_debug.c` — función `unknown`
- **Cambio:** generic (29 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 13. `core/rtw_debug.c` — función `unknown`
- **Cambio:** generic (4 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 14. `core/rtw_debug.c` — función `unknown`
- **Cambio:** generic (2 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)

### 15. `core/rtw_debug.c` — función `unknown`
- **Cambio:** generic (4 líneas)
- **Razón:** Archivo core con posible interacción con kernel
- **Kernel compat:** Requiere adaptación de API
- **Prioridad:** media (requiere trabajo de compat)


## Archivos Nuevos a Incorporar

Archivos SOLO_OFFICIAL marcados para revisión/incorporación.

### Archivos para revisión (42)
- `core/rtw_ioctl_rtl.c`: Archivo de código con funciones
- `core/rtw_mp_ioctl.c`: Archivo de código con funciones
- `hal/btc/HalBtc8192e1Ant.c`: Archivo BTC relevante para 8192E
- `hal/btc/HalBtc8192e1Ant.h`: Archivo BTC relevante para 8192E
- `hal/btc/HalBtc8192e2Ant.c`: Archivo BTC relevante para 8192E
- `hal/btc/HalBtc8192e2Ant.h`: Archivo BTC relevante para 8192E
- `hal/phydm/halphyrf_ap.c`: Archivo de código con funciones
- `hal/phydm/halphyrf_ap.h`: Archivo header con structs/constantes HAL
- `hal/phydm/halphyrf_ce.c`: Archivo de código con funciones
- `hal/phydm/halphyrf_ce.h`: Archivo header con structs/constantes HAL
- `hal/phydm/halphyrf_win.c`: Archivo de código con funciones
- `hal/phydm/halphyrf_win.h`: Archivo header con structs/constantes HAL
- `hal/phydm/phydm_acs.c`: Archivo de código con funciones
- `hal/phydm/phydm_acs.h`: Archivo header con structs/constantes HAL
- `hal/phydm/phydm_dynamicbbpowersaving.c`: Archivo de código con funciones
- `hal/phydm/phydm_dynamicbbpowersaving.h`: Archivo header con structs/constantes HAL
- `hal/phydm/phydm_edcaturbocheck.c`: Archivo de código con funciones
- `hal/phydm/phydm_edcaturbocheck.h`: Archivo header con structs/constantes HAL
- `hal/phydm/phydm_powertracking_ap.c`: Archivo de código con funciones
- `hal/phydm/phydm_powertracking_ap.h`: Archivo header con structs/constantes HAL
- `hal/phydm/phydm_powertracking_ce.c`: Archivo de código con funciones
- `hal/phydm/phydm_powertracking_ce.h`: Archivo header con structs/constantes HAL
- `hal/phydm/phydm_powertracking_win.c`: Archivo de código con funciones
- `hal/phydm/phydm_powertracking_win.h`: Archivo header con structs/constantes HAL
- `hal/phydm/phydm_rxhp.c`: Archivo de código con funciones
- `hal/phydm/phydm_rxhp.h`: Archivo header con structs/constantes HAL
- `hal/phydm/rtchnlplan.c`: Archivo de código con funciones
- `hal/phydm/rtchnlplan.h`: Archivo header con structs/constantes HAL
- `hal/phydm/rtl8192e/halhwimg8192e_fw.c`: Archivo de código con funciones
- `hal/phydm/rtl8192e/halhwimg8192e_fw.h`: Archivo header con structs/constantes HAL
- `hal/phydm/rtl8192e/halphyrf_8192e_ap.c`: Archivo de código con funciones
- `hal/phydm/rtl8192e/halphyrf_8192e_ap.h`: Archivo header con structs/constantes HAL
- `hal/phydm/rtl8192e/halphyrf_8192e_ce.c`: Archivo de código con funciones
- `hal/phydm/rtl8192e/halphyrf_8192e_ce.h`: Archivo header con structs/constantes HAL
- `hal/phydm/rtl8192e/halphyrf_8192e_win.c`: Archivo de código con funciones
- `hal/phydm/rtl8192e/halphyrf_8192e_win.h`: Archivo header con structs/constantes HAL
- `hal/phydm/txbf/haltxbf8821b.c`: Archivo de código con funciones
- `hal/phydm/txbf/haltxbf8821b.h`: Archivo header con structs/constantes HAL
- `include/mp_custom_oid.h`: Archivo header con structs/constantes HAL
- `include/rtw_ioctl_rtl.h`: Archivo header con structs/constantes HAL
- `include/rtw_mp_ioctl.h`: Archivo header con structs/constantes HAL
- `include/rtw_wifi_regd.h`: Archivo header con structs/constantes HAL

### Archivos para incorporar (0)
No se identificaron archivos que requieran incorporación inmediata.


## Observaciones

### Hallazgos principales
- La mayoría de los cambios en `hal/` y `core/` son lógica de hardware portable
- Los archivos `os_dep/linux/` contienen la mayoría de los cambios de compatibilidad de kernel
- Los archivos BTC para chipsets no relevantes (8188, 8723, 8812, 8821) pueden ignorarse
- Los archivos específicos de 8192E (BTC y PHYDM) deben revisarse

### Recomendaciones
1. Priorizar backports de archivos `hal/` y `core/` marcados como VIABLE
2. Revisar manualmente los archivos `os_dep/linux/` marcados como REQUIERE_ADAPTACION
3. Evaluar si los archivos BTC de 8192E aportan funcionalidad Bluetooth coexistence relevante
4. Considerar si los archivos PHYDM de 8192E mejoran el rendimiento de la PHY

