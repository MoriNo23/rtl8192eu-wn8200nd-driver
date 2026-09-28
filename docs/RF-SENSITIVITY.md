# RF-SENSITIVITY — parámetros que afectan a la sensibilidad de recepción

Todos los parámetros de este documento son **valores por defecto del driver**
(`driver/os_dep/linux/os_intfs.c`), no del fichero de modprobe. El valor
efectivo en runtime sale de `/etc/modprobe.d/8192eu.conf`, que copia a
`registry_priv` **solo en el init del módulo** (ver la advertencia al final).

El criterio de este repo es: **cualquier opción cuyo efecto sobre la
sensibilidad no esté medido en el despliegue viene documentada aquí con su
alternativa y su procedimiento de A/B.** Si añades un parámetro de ganancia o
filtrado y no lo añades a esta tabla, el CI no te lo va a reclamar — pero la
próxima persona que lea el módulo no tendrá forma de saber qué le afecta.

## Tabla de parámetros

| Parámetro | Default | Efecto | Coste / alternativa |
|---|---|---|---|
| `rtw_rxgain_offset_2g` | `0` | Offset de ganancia de RF en 2.4 GHz. `0` = neutro. | **Medido en este despliegue:** con `4` la señal se resentía. Puesto a `0` el 2026-08-08, medido **+19 dB** y **3.2× throughput** respecto a `4`. Con enlace débil, atenuar empeora la sensibilidad — no lo subas por inercia. Es el parámetro con más evidencia detrás que tenemos. |
| `rtw_rxgain_offset_5gl/5gm/5gh` | `0` | Equivalente para las tres bandas de 5 GHz (bajo/m medio/alto). | Este adaptador es 2.4 GHz (`TL-WN8200ND(UN) V3.0`, RTL8192EU 2×2 con una antena desoldada). **No se han medido**: no hay enlace de 5 GHz que las ejercite. Se dejan en `0` (neutro) por simetría. |
| `rtw_notch_filter` | `0` en el fuente (`RTW_NOTCH_FILTER`, `autoconf.h:172`), **`1` en el despliegue** | Filtro notch. `0`=desactiva, `1`=habilita, `2`=solo P2P. | Rechaza interferencia fuera de banda (p. ej. canals adyacentes), lo que mejora la **selectividad**. No es un ajuste de ganancia: no se espera que cambie la sensibilidad útil. Está en `1` desde antes de este change y **no se ha medido su A/B**; se documenta aquí por estar activo. |
| `rtw_hiq_filter` | `1` (`CONFIG_RTW_HIQ_FILTER`, `drv_conf.h:336`) | Filtro de desbalance IQ. `0`=permite todo, `1`=permite especial, `2`=deniega todo. | **Es el ajuste que más SENSIBILIDAD cuesta.** Rechaza tramas con imbalance IQ fuera de rango, lo cual corta interferencia pero **también puede matar tramas legítimas** si el desequilibrio del propio receptor es alto. Con la antena artesanal direccional y el vecindario denso, `1` es el valor conservador. **No verificado en este despliegue** — no hay A/B medido de `1` vs `0`. Si se nota Sensitivity perdida en enlace corto y limpio, `0` es el primer candidato a probar. |
| `rtw_iqk_fw_offload` | `1` si `RTW_IQK_FW_OFFLOAD`, si no `0` (sin valor) | Offload de IQK al firmware. Afecta a la **calibración** de imbalance, no directamente a la ganancia. | No es un ajuste fino de sensibilidad; se documenta porque toca la misma cadena IQ que `hiq_filter`. No medido. |

### Lo que **no** está en esta tabla (y por qué)

- `rtw_bw_mode` — ancho de banda, no ganancia. Está documentado en `AGENTS.md`
  (parámetros runtime) porque su valor configurado ≠ ancho negociado.
- `rtw_adaptivity_*` / EDCCA — afecta a **desensibilización** por ruido
  (vecinos ruidosos), no a la sensibilidad de línea base. Tiene su propia
  sección en `AGENTS.md`.
- `rtw_smart_ps`, `rtw_enusbss` — ahorro de energía, no RF.

## Cómo medirlos

El procedimiento es siempre el mismo y **no necesita la depuración en runtime**
(que ya no existe — ver `AGENTS.md`):

1. **Cámbialo** en `/etc/modprobe.d/8192eu.conf` y recarga:
   ```bash
   sudo ./install_manual.sh
   ```
   (el script ya reinicia NetworkManager al final).

2. **Mide la señal** con la herramienta de antena, que ya no depende de procfs:
   ```bash
   wn8200nd-antenna --once
   ```
   Reporta `signal:` en dBm desde `iw dev <iface> station dump`.

3. **Mide el throughput** y, sobre todo, **la tasa de error**, no solo la señal:
   una opción de filtrado puede mejorar el RSSI y empeorar el throughput real si
   está rechazando tramas buenas. La métrica que decide es la velocidad
   sostenida de descarga, con la señal como dato de contexto.

4. **Deja estabilizarse** entre mediciones. El diseño de este change
   (`design.md`, D6) es explícito en que no se miden dos cambios de
   comportamiento en la misma ventana.

### Deshazlo si empeora

Todo parámetro de esta tabla se revierte desde
`/etc/modprobe.d/8192eu.conf` sin recompilar. Si un A/B sale peor, se vuelve al
valor de esta tabla y se documenta el resultado.

## La trampa de los sysfs

Escribir en `/sys/module/8192eu/parameters/` **no** propaga a `registry_priv`
ni a `dm->edcca_mode`. Son variables separadas: el `module_param` se copia a
`registry_priv` **solo en el init del módulo**. Escribir a sysfs cambia la
variable global, pero el camino de inicialización ya pasó. **El único modo que
funciona es editar `8192eu.conf` y recargar el módulo.**

## Ver también

- `AGENTS.md` → «Parámetros runtime» para los valores que el despliegue tiene
  realmente puestos, y «Regla de lectura de esa tabla».
- `openspec/changes/driver-silence-and-throughput/specs/rf-throughput-tuning/spec.md`
  → requirement «La configuración por defecto no empeora la sensibilidad de
  recepción».
