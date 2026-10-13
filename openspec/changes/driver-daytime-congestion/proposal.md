# Proposal: driver-daytime-congestion

## Why

El TL-WN8200ND cumple de madrugada y colapsa de día: ping errático (3 ms →
cientos de ms en ráfagas), micro-cortes, enlace asociado con buena señal pero
sin rendimiento. La firma es de **coexistencia**, no de cobertura: de día el
vecindario 2.4 GHz se enciende y el adaptador transmite **encima** del tráfico
vecinal en vez de retroceder.

La causa mecánica en el driver: el despliegue corre EDCCA en modo
**carrier_sense** con `rtw_adaptivity_th_l2h_ini=15`. Ese modo está diseñado
para operar alrededor de -50 dBm (ver `phydm_set_l2h_th_ini_carrier_sense()`,
`driver/hal/phydm/phydm_adaptivity.c:350`): el umbral EDCCA efectivo queda tan
alto que las transmisiones de los vecinos —más débiles que el propio enlace—
no disparan CCA y no hay escucha-antes-de-transmitir real. Resultado:
colisiones y retransmisiones durante el día; de noche el canal calla y el
mismo perfil funciona. El ath9k interno (AR9285) juega LBT bien portado y por
eso aguanta el día.

## What Changes

**Fase 1 — parámetros, sin recompilar** (aplica en `/etc/modprobe.d/8192eu.conf`
+ recarga del módulo):

- `rtw_adaptivity_mode` `1` → `0` (**normal**): EDCCA con retroceso ante
  ocupación vecinal. Para 11N el driver asigna `th_l2h_ini = -11`
  (`phydm_set_l2h_th_ini()`, `phydm_adaptivity.c:326`), lo que baja el umbral
  efectivo a ~-71 dBm: escucha-antes-de-transmitir real.
- `rtw_adaptivity_th_l2h_ini` `15` → `0` (dejar que el modo normal ponga su
  default; en carrier_sense el guard 1.6.1 lo respetaba, en normal aún se pisa
  — se parchea en fase 2).
- Sin tocar en esta ronda: `rtw_en_napi=1`, `rtw_usb_rxagg_mode=1`,
  `rtw_rxgain_offset_2g=0`, `rtw_notch_filter=1`, `rtw_smart_ps=0`,
  `rtw_adaptivity_th_edcca_hl_diff=5` (una variable a la vez, hereda D6 del
  change anterior).
- Candidatos de segundo orden **solo si** el lag persiste: `rtw_hiq_filter=0`
  (A/B documentado en `docs/RF-SENSITIVITY.md`, no medido) y
  `rtw_ampdu_factor=5` (ráfagas de retransmisión más cortas).

**Fase 2 — código, solo si la fase 1 valida la dirección:**

- Guard de paridad en `phydm_set_l2h_th_ini()`: respetar `th_l2h_ini != 0`
  desde modprobe en modo normal, igual que ya hace carrier_sense desde 1.6.1.
- Defaults permanentes en `driver/Makefile`:
  `CONFIG_RTW_ADAPTIVITY_MODE = normal`, bump DKMS `1.8.1` → `1.9.0`,
  CHANGELOG, tablas de AGENTS.md/README y aserciones de `config-assertions`.
- Documentar el protocolo y resultados en `docs/DAYTIME.md`.

**Fuera de alcance de este change:**

- `CONFIG_TXPWR_LIMIT`/`_EN` — sigue `n` hasta cerrar BUG-TXPOWER-001.
- Canal del router NAVI (9/10) y del AP escama (3): es cambio del router/AP
  (repo `escama-ap` o router), no del driver. Se recomienda medir ocupación
  (tarea 1.4) y evaluar aparte.
- Región regulatoria: invariante intocable.
- Offset de potencia de TX por parámetro de módulo: extensión condicional en
  change aparte, solo si la evidencia post-fase-1 la pide.

## Impact

- **Affected specs:** `rf-throughput-tuning` (ADDED: requirement de retroceso
  ante ocupación vecinal del canal).
- **Affected code (fase 2):** `driver/hal/phydm/phydm_adaptivity.c`,
  `driver/Makefile`, `dkms.conf`, `AGENTS.md`, `README.md`,
  `docs/DAYTIME.md` (nuevo), workflow de `config-assertions`.
- **Fase 1 no toca el árbol:** solo `/etc/modprobe.d/8192eu.conf` en la máquina
  de despliegue + recarga.
- Riesgo asumido: en canal ocupado, la adaptividad normal retrocede más, así
  que el techo de throughput nocturno puede bajar algo. El objetivo declarado
  es estabilidad diurna; la adaptividad ajusta el umbral dinámicamente con la
  ocupación, no es un coste plano.
