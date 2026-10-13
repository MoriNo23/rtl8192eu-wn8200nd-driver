# Design: driver-daytime-congestion

## D1 — Diagnóstico: carrier_sense deja al vecino invisible

Cálculo EDCCA en este árbol (RTL8192E = ODM_IC_PWDB_EDCCA), documentado en
AGENTS.md y verificable en `phydm_adaptivity.c`:

```
l2h_dyn_min = th_l2h_ini + igi_target   (igi_target = 0x32 = 50)
th_l2h      = min(igi, l2h_dyn_min)
th_h2l      = th_l2h - th_edcca_hl_diff
```

| Config | th_l2h_ini | l2h_dyn_min | Umbral efectivo | Comportamiento |
|---|---|---|---|---|
| Actual (carrier_sense, conf=15) | 15 | 65 | min(IGI~53, 65) ≈ RSSI 43 ≈ **-57 dBm** | Tráfico vecinal más débil que -57 dBm **no** dispara CCA: transmite encima |
| Propuesto (normal, driver 11N) | -11 | 39 | min(IGI, 39) = 39 ≈ **-71 dBm** | Retrocede ante vecinos 14 dB más débiles: LBT real |

Consecuencia diurna esperada: menos colisiones ⇒ menos retransmisiones ⇒ p95
de RTT y micro-cortes bajan. Coste nocturno esperado: pequeño (la adaptividad
sube el umbral dinámicamente cuando el canal está despejado; no es un coste
plano).

**Verificación de la hipótesis sin debug en runtime:** el debug de phydm es
inalcanzable desde 1.8.0 (`CONFIG_PROC_DEBUG=n`), así que la confirmación es
comportamental: A/B de latencia diurna (tarea 1.2 vs 2.3). Condición para
atribuir a RF y no a USB: `dmesg` sin re-enumeraciones durante la medición
(si hay rebotes USB, el asunto es `docs/USB-LINK-HANG.md`, no este change).

## D1.1 — Corrección post-fase-1 (2026-10-13): el eje EDCCA está cerrado

La lectura fina del código tras el resultado negativo de la fase 1 corrige D1
y explica por qué el experimento A no podía mover la aguja (verificado en
`phydm_adaptivity.c`, `phydm_adaptivity.h` y `hal_dm.c:438-440`):

1. **Modo normal (`mode=0`, lo probado en fase 1):** RTL8192E es
   `ODM_IC_PWDB_EDCCA`; en esa rama el modo normal calcula
   `th_l2h = 70 - igi` (`phydm_adaptivity.c:568`) y **no usa `th_l2h_ini`
   para nada**. Además `phydm_set_edcca_threshold_api()` retorna temprano si
   `edcca_mode != ADAPT` (`:611`), así que en modo normal nadie reprograma
   los umbrales periódicamente (quedan en el estado "no link" 0x7f, `:311`).
   En la práctica la fase 1 dejó el radio **sordo** (casi nunca difiere).
2. **Modo carrier_sense (`mode=1`, config anterior):**
   `th_l2h = min(th_l2h_ini + 50 - igi, 10)` con tope duro en 10
   (`:563-564`). Bajo señal fuerte (-43 dBm) **todo `ini` ≥ ~10 es
   equivalente**: el `ini=15` histórico y el default 10 del fork dan el mismo
   umbral. El `ini` solo diferencia en señal débil.
3. Consecuencia: ya se probaron los dos extremos (EDCCA sensible -50 dBm vía
   carrier_sense, EDCCA sordo vía normal) con el mismo resultado diurno malo.
   **La deferral por EDCCA no es el mecanismo principal del colapso diurno.**
   El comentario "-11 ≈ -71 dBm" del código aplica al uso de `ini` en modo
   ADAPT, no al modo normal (D1 asumía lo contrario para este IC).

Diagnóstico medido 2026-10-13 14:40-14:43 (día, ambos adaptadores, pings de
60 s): wn8200nd -43 dBm, rx MCS7/tx MCS6, 0% loss, RTT min 9.9 / p50 26.5 /
máx 92.5 ms; ath9k -62 dBm, tx MCS7, 130% retries, 0.67% loss. El interno
gana con 19 dB MENOS señal y el doble de retries ⇒ el diferencial no es
cobertura ni pérdida, es comportamiento del radio/driver bajo contención.
Piso común ~9-10 ms en ambos ⇒ el diferencial está en la cola/distribución.

## D1.2 — Datos rev. 3 (2026-10-13 15:16-15:21): config de referencia restaurada y empate en pasarela

Cuatro capturas v2 (`diag-*-20261013-151*`) con `scripts/diag-daytime.sh`:

1. **Config confirmada en sysfs** (tarea 2.11): `rtw_adaptivity_mode=1`,
   `rtw_adaptivity_th_l2h_ini=10`, `th_edcca_hl_diff=5`, `en=1`;
   `rx_ampdu_sz_limit_1ss` vacío (= 0xFF sin límite); power_mgnt=0,
   smart_ps=0, enusbss=0, napi/gro=1, usb_rxagg=1, 1T1R (0x11), reg US.
2. **wn8200nd idle 15:16** (señal -46 dBm, tx 72.2/rx 65): 0% loss, RTT
   min/avg/máx = 1.56/2.63/12.76, **P50 2.07 / P95 5.43 ms**. Comparar con la
   captura de las 14:40 (en mode=0): p50 26.5 / máx 92.5.
3. **stonepi idle 15:19** (-63 dBm): 0% loss, **P50 1.68 / P95 5.69 ms** —
   **empate técnico** con el wn8200nd en la pasarela, minutos después.
4. **Ocupación de aire baja**: survey del ath9k en ch10 → busy/active
   ≈ 8.8-9.9% en ambos instantes. El canal estaba mayoritariamente LIBRE
   mientras había 12-14 APs visibles.
5. **El modo `load` de v2 quedó vacío** (no hay server iperf3 en NAVI; v2
   prefería iperf3 a ciegas y falló en silencio): ambos "load" midieron casi
   reposo. Corregido en v3 (prueba el server y si no, curl con Mbps). Aun
   así, el "load" de stonepi cazó un **episodio malo** (P95 241 ms, máx
   482 ms) **con el canal al 10% de ocupación** ⇒ hay episodios puntuales que
   no son saturación de aire (candidatos: ráfaga de un vecino, escaneo en
   background del supplicant, retransmisión masiva puntual).

**Lectura (hipótesis a confirmar con A/B concurrente, no hecho cerrado):**
- El "colapso diurno" es **episódico**, no permanente: mismo adaptador, misma
  tarde, P50 26.5 ms a las 14:40 y P50 2.07 ms a las 15:16.
- Con la config de referencia (mode=1/ini=10) el wn8200nd **empata** con el
  ath9k en latencia de pasarela.
- La captura mala de las 14:40 se tomó **en mode=0 (EDCCA sordo)** y la
  prueba de estrellas también: **sospecha invertida** — mode=0 probablemente
  PERJUDICA (transmite sobre energía ambiente ⇒ reintentos que el contador de
  pérdida no ve) en vez de ayudar. Atribución débil: 1 muestra por config, y
  ese día hubo además 2 re-enumeraciones USB 20 min antes.
- El diferencial subjetivo 1★/3★ se midió bajo mode=0 ⇒ probablemente
  penalizado por la config, además de por el episodio.
- **Prueba decisiva**: `scripts/diag-dual.sh` (A/B concurrente, mismos
  instantes de aire) en idle + load + loadup, y repetirlo dentro de la franja
  real del episodio ("se tira 3 peos"). C′ (`rx_ampdu_sz_limit_1ss`) queda
  condicionado a que el dual muestre al wn8200nd peor bajo carga real.

## D1.3 — Resultado de intervención (2026-10-14): F2 valida el pipeline HT

A/B del usuario en speed.cloudflare.com de día, varias rondas
(una variable a la vez):

| Config | Calidad diurna |
|---|---|
| Referencia (HT on) | **pobre** (reproducible) |
| F1: `rtw_ampdu_enable=0` (sin F2) | pobre — **sin efecto** |
| F1+F2 | regular |
| F2 solo: `rtw_ht_enable=0` | **regular** (reproducible, adoptado) |

Lectura:

1. **El pipeline HT es el mecanismo del colapso diurno**, reproducible y no
   dependiente de la hora de medición (ya no queda en "episodio").
2. El delta F2−F1 es la pista fina: F1 mató SOLO la agregación TX y no movió
   nada; F2 mata además tasas MCS (→ OFDM legacy), RX A-MPDU (64 KB) y Short
   GI. **El sospechoso principal se traslada a la RX: el router agrega
   bloques de hasta 64 KB hacia el dongle; bajo la contención diurna un
   subtrama dañada fuerza retransmisión del bloque entero (head-of-line) y
   la cola se traga la latencia.** El path RX/reordenado del port Realtek es
   el punto débil conocido frente al path mainline del ath9k (que con el
   MISMO AP en HT y 130% retries da mejor experiencia).
3. C′ (`rtw_rx_ampdu_sz_limit_1ss=0x10`, 16 KB) pasa de hipótesis a
   **refinamiento con evidencia directa** (tarea 2.19): si con HT on + límite
   16 KB la calidad vuelve a "regular", se recupera el ancho de banda MCS sin
   el colapso; si no, `rtw_ht_enable=0` queda como config permanente (11g ≈
   20-25 Mbps reales, suficiente para videollamadas).
4. Coherencia con datos previos: wn8200nd -43 dBm con 0% loss y p50 26.5 ms
   (14:40, HT on) vs empate en reposo con canal libre (15:16) — la pérdida en
   contención no se ve en contadores de pérdida sino en la cola, exacto al
   patrón head-of-line de bloques RX grandes.

## D1.4 — Cierre (2026-10-14): C′ adoptado, 1.9.0

El refinamiento 2.19 (HT on + `rtw_rx_ampdu_sz_limit_1ss=0x10`) devolvió la
experiencia a **estable** de día manteniendo tasas MCS. Veredicto: el
mecanismo del colapso diurno es la ventana RX A-MPDU de 64 subtramas
(head-of-line en retransmisión de bloques bajo ruido vecinal) y la solución
es el capado a 16, ya implementado por Realtek como knob — no hace falta
parchear phydm (sección 3 reescrita y ejecutada como bump de defaults).

1. **Corrección de unidades** (importa para futuras lecturas): el valor de
   `rx_ampdu_sz_limit` es **nº de subtramas/buffers, NO Kbytes**
   (`rtw_mlme_ext.c:3500-3506`: "The size variable means how many MSDUs or
   AMSDUs, it's not Kbytes"). 0x10 = 16 subtramas (≈ 1/4 de bloque).
2. **Cambio permanente**: `drv_conf.h`
   `CONFIG_RTW_RX_AMPDU_SZ_LIMIT_1SS = {0x10,0x10,0x10,0x10}`; overrides:
   modprobe (`rtw_rx_ampdu_sz_limit_1ss`) o proc en caliente
   (`echo 1 16 > /proc/net/rtl8192eu/wn8200nd/rx_ampdu`, re-aplica ADDBA vía
   `rtw_rx_ampdu_apply()` — `rtw_debug.c:3162`, `rtw_mlme_ext.c:3734`).
3. **Versionado**: bump 1.8.1 → 1.9.0 (minor) en `dkms.conf` +
   `install_manual.sh`; CHANGELOG y tablas en `AGENTS.md`; caso completo en
   `docs/DAYTIME.md`.
4. **Verificación pendiente en la máquina del usuario** (fuera de este
   entorno): bump DKMS y comprobar
   `/sys/module/8192eu/parameters/rtw_rx_ampdu_sz_limit_1ss` = `16,16,16,16`;
   throughput nocturno de control (baseline 25 Mbps; si aprieta >20% de
   caída, punto medio `0x20` = 32 subtramas).
5. Queda vivo como follow-up opcional: aserción CI del nuevo default
   (3.5) y el eje RA/rate_ctl si reapareciera degradación distinta.

## D2 — Por qué modo normal y no bajar th_l2h_ini dentro de carrier_sense

**OBSOLETA tras D1.1 (se conserva por trazabilidad):** el planteamiento
tenía un error para el 8192E: el modo normal ni usa `th_l2h_ini` ni
reprograma umbrales, así que no hay nada que "respetar" con un guard en
`phydm_set_l2h_th_ini()` para este IC. El guard de carrier_sense 1.6.1 sí
vale (ese modo sí consume el valor). La fase 2 tal como está en tasks.md 3.x
queda **condicionada** a que otro candidato (C′/carga/USB) valide una
dirección que la haga pertinente; si no, se archiva sin parche.

Bajar `rtw_adaptivity_th_l2h_ini` a un valor muy negativo **en carrier_sense**
convertiría ese modo en una imitación de normal con paths de código distintos
(decisión EDCCA, `phydm_edcca_decision_opt()`, forgetting factor). El modo
normal es el diseñado para LBT con umbral dinámico; se elige el modo, no el
número. El guard 1.6.1 ya permite override en carrier_sense; se añade el
mismo guard en normal (fase 2) para afinar sin recompilar.

## D3 — Lo que NO se toca (invariantes y decisiones previas)

| Invariante | Razón |
|---|---|
| `CONFIG_TXPWR_LIMIT`/`_EN = n` | BUG-TXPOWER-001 (`docs/BUGS.md`): con `y` el módulo no carga. No reactivar sin cerrar el bug. |
| `rtw_en_napi=1`, `rtw_en_gro=1`, `rtw_usb_rxagg_mode=1` | Ganancia medida 1.8.0 (13→25 Mbps). Una variable a la vez: no se mezclan con el cambio EDCCA. |
| `rtw_rxgain_offset_2g=0` | Medido (+19 dB y 3.2× throughput vs 4). No se sube por inercia. |
| Región regulatoria (US, del country IE) | Invariante del repo: nunca `iw reg set`, nunca `rtw_country_code`. |
| 1T1R (`rtw_trx_path_bmp=0x11`) | Antena B desoldada (hardware). |
| `CONFIG_PSD_TOOL=y`, `DBG 1` | Dualidades conocidas del Makefile/phydm; romperlas rompe el enlazado. |

## D4 — Orden de experimentos (una variable a la vez) — rev. 2

1. **A (fase 1): EJECUTADO, SIN EFECTO** (ver D1.1). Restaurar la config de
   referencia `rtw_adaptivity_mode=1` + `rtw_adaptivity_th_l2h_ini=10`
   (equivalente funcional al 15 histórico bajo señal fuerte).
2. **B: RETIRADO** — `hiq_filter` enruta TX, no filtra RX (tasks 2.5).
3. **C: NULO como parámetro** — `rtw_ampdu_factor` solo alimenta rutas VHT
   (`rtw_vht.c:325/908`) que el 8192E (11N) no usa; el HAL devuelve 64K fijo
   (`usb_halinit.c:1687`). Sustituido por **C′**.
4. **C′ (nuevo, picos en ráfagas RX):** `rtw_rx_ampdu_sz_limit_1ss` —
   `module_param_array` real y cableado (default `0xFF` = sin límite,
   `drv_conf.h:459`). Probar `0x20,0x20,0x20,0x20` (32 KB) y si acaso
   `0x10` (16 KB): menos subtramas por ráfaga de bajada = retransmisión de
   bloque más corta = menos head-of-line bajo contención diurna.
5. **D (nuevo, discriminación de cola):** ping bajo carga (`diag-daytime.sh
   <iface> <gw> load`) por adaptador: si el wn8200nd explota en p95 solo bajo
   carga, el problema es de cola/AMPDU/USB; si explota igual en reposo, es de
   RF/rate-adaptation.
6. **E (higiene física/USB, gratis y en paralelo):** alargo USB para alejar
   el adaptador del chasis (EMI), puerto directo en vez del hub interno; las
   2 re-enumeraciones de las 14:19 + historial `docs/USB-LINK-HANG.md` lo
   justifican. La nota del usuario sobre la orientación de la pantalla del
   interno sugiere que el apuntado/posición pesa más de lo esperado.
7. Cada paso: medir día + noche, adoptar o revertir, documentar.

## D4 rev. 3 — Protocolo de intervención (2026-10-14), sustituye a D y 2.13

Entrada externa adoptada: el usuario rechaza más diagnóstico pasivo (scripts);
en su lugar, intervenciones de una variable que miden la experiencia. Eje
vivo según análisis externo: interacción driver↔router (WMM/AMPDU/HT/RA).

Evidencia nueva verificada en código:

1. **El driver NO usa mac80211** (cero hits de `ieee80211_hw`/`mac80211`/
   `sta_rc_update`/`ampdu_mlme_action` en todo el árbol): stack standalone
   con MLME, RA (ODM `phydm_rainfo`), ADDBA y mapeo WMM propios. La
   hipótesis "APIs viejas de mac80211" queda cerrada; la del "port
   incompleto" sale reforzada por 2 y 3.
2. **`iw set bitrates` no existe aquí**: sin `.set_bitrate_mask` en
   `cfg80211_ops`. **`iwconfig rate` es un no-op silencioso**: el cuerpo de
   `rtw_wx_set_rate` está envuelto en `#if 0` (`ioctl_linux.c:2506-2581`).
3. **La vía real de tasa fija es el proc del driver**: `/proc/net/rtl8192eu/
   wn8200nd/rate_ctl` (`rtw_debug.c:2011/2036`) → `adapter->fix_rate` →
   `SET_TX_DESC_TX_RATE_92E` (`rtl8192e_xmit.c:443-451`). Índices
   (`hal_com.h:33-56`): 0x03=11M, 0x08=24M, 0x0B=54M, 0x0C..0x13=MCS0..7,
   `0xFF` restaura RA.
4. Params disponibles (todos 0644, `os_intfs.c:580/591/593`):
   `rtw_wmm_enable` (default 1), `rtw_ht_enable` (1), `rtw_ampdu_enable`
   (1, "0: disable").
5. Contadores: `iw station dump` solo expone `tx_failed`
   (`ioctl_cfg80211.c:2598`, no hay tx_retries); los completos están en
   `/proc/net/rtl8192eu/wn8200nd/{trx_info,tx_stat,rx_stat}`
   (`rtw_proc.c:4982, 5262-5264`).

Candidatos de intervención (una variable a la vez, restaurar tras cada uno):

| # | Intervención | Aísla | Si mejora ⇒ |
|---|---|---|---|
| F1 | `rtw_ampdu_enable=0` | Agregación A-MPDU TX (mantiene MCS) | C′ (2.10) permanente |
| F2 | `rtw_ht_enable=0` | HT completo (11g legacy) | Agregación+SGI; si F1 no movió, el problema es HT-wide |
| F3 | `rate_ctl` 0x08/0x0B | Rate-adaptation | RA agresiva bajo contención → parchear odm_rainfo |
| F4 | `rtw_wmm_enable=0` (cliente) | WMM/QoS AC | Mapeo AC/colas → parcheo de colas |

Matriz con contadores (2.18): retries↑ ⇒ aire/RA; rx_dropped↑ ⇒ USB/buffer;
sin anomalías ⇒ cola/agregación.

## D5 — Protocolo de medición (día = hora pico, noche = madrugada)

Mismo router (NAVI), misma ubicación, misma antena (cantenna). Para cada
configuración y cada franja:

1. `scripts/diag-daytime.sh <iface> [gw] [idle|load]` (v2): vuelca TODOS los
   parámetros efectivos de `/sys/module/8192eu/parameters/`, survey dump
   (ocupación real busy/active), station dump, reg, scan, ping 60 s con
   percentiles correctos + línea `rtt` cruda (v1 mezclaba min/avg/max y daba
   p95 < p50), dmesg con timestamps y árbol USB.
2. Correrlo por adaptador (wn8200nd y stonepi) de día, en reposo y bajo
   carga; idealmente una pasada nocturna de referencia con el wn8200nd.
3. Descarga sostenida ×3 (50 MB, `speed.cloudflare.com/__down`) → Mbps.
4. Prueba cualitativa del usuario: videollamada 15-30 min de día.
5. `dmesg` limpio de eventos USB durante toda la medición (condición D1).

Aceptación de la fase 1: mejora clara de p95 RTT y pérdida de día (sin
eventos USB) **y** throughput nocturno ≥ ~20 Mbps (baseline 25, tolerancia
-20%). Si la fase 1 valida, fase 2 hace permanentes los defaults.

## D6 — Alcance de la fase 2 (mínima y reversible)

- Guard de `th_l2h_ini` en `phydm_set_l2h_th_ini()` (3 líneas, paridad con el
  guard de carrier_sense 1.6.1).
- Defaults en Makefile (`CONFIG_RTW_ADAPTIVITY_MODE = normal`) + bump DKMS
  1.8.1 → 1.9.0 (minor: cambio de comportamiento) + CHANGELOG + tablas de
  AGENTS.md/README + aserciones `config-assertions`.
- **Quedan fuera** (changes aparte, evidencia-guiados): offset de potencia TX
  por módulo (punto de parcheo identificado: cómputo de índice en
  `hal/hal_com_phycfg.c` → escritura en `PHY_SetTxPowerIndex_8192E`,
  `rtl8192e_phycfg.c:463`; nunca vía TXPWR_LIMIT), límites DIG/IGI
  (`phydm_dig.c`), canal del AP/router.
