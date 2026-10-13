# Colapso diurno — caso cerrado (C′)

Fechas: 2026-10-13 a 2026-10-14 · Adaptador: TP-Link TL-WN8200ND V3 (RTL8192EU, 1T1R cantenna)
· Contraste: AR9285 interno (ath9k) · AP: NAVI, ch10, 20 MHz · Fix: `CONFIG_RTW_RX_AMPDU_SZ_LIMIT_1SS = 0x10` (driver 1.9.0)

## Síntoma

De madrugada el WN8200ND iba bien; de día el enlace se degradaba hasta obligar
a cambiar al adaptador interno (calidad speed.cloudflare.com: 1★ vs 3★ del
interno). Sin desconexiones: era latencia, no enlace caído.

## Hallazgos descartados (con evidencia de código o medición)

| Eje | Veredicto | Prueba |
|---|---|---|
| EDCCA/carrier_sense | Descartado | Dos extremos probados (mode=0 sordo, mode=1 ini=10/15 equivalentes bajo señal fuerte); `phydm_adaptivity.c:563-611`: en modo normal PWDB nadie reprograma umbrales |
| power_save | Descartado | `off` verificado en ambos adaptadores |
| `rtw_ampdu_factor` | No-op en 8192E | HAL fijo 64K (`usb_halinit.c:1687`); solo alimentaba rutas VHT |
| `rtw_hiq_filter` | No es filtro RX | Enruta TX ARP/EAPOL/DHCP (`rtw_xmit.c:5208`) |
| Router/AP | Descartado | ath9k fino en el mismo AP; escama desactivada |
| USB desconexión | Descartado | Sin re-enumeraciones durante mediciones |
| Agregación TX | Descartado (F1) | `rtw_ampdu_enable=0`: sin efecto |
| "APIs viejas de mac80211" | Falsa | El driver NO usa mac80211 (cero `ieee80211_hw` en el árbol): stack standalone |

## Diagnóstico medido

- 14:40 (día, HT on): wn8200nd -43 dBm, 0% loss, RTT p50 26.5 / máx 92.5 ms;
  ath9k -62 dBm con 130% retries y mejor experiencia. El interno gana con 19 dB
  MENOS señal ⇒ el diferencial no es cobertura ni pérdida, es comportamiento
  bajo contención.
- 15:16 (madrugada/tarde baja, canal 8.8% busy): empate técnico en pasarela
  (P50 2.07 vs 1.68 ms). El colapso es de contención diurna, no de señal.

## Aislamiento (una variable a la vez)

| Config | Calidad diurna |
|---|---|
| Referencia (HT on, RX AMPDU 64 subtramas) | pobre |
| F1 `rtw_ampdu_enable=0` (sin TX AMPDU) | pobre — sin efecto |
| F2 `rtw_ht_enable=0` (11g legacy) | regular — reproducible |
| **F3′ HT on + `rtw_rx_ampdu_sz_limit_1ss=0x10`** | **estable — ADOPTADO** |

Delta F2−F1: F1 solo mató TX; F2 mató además MCS, RX A-MPDU y Short GI ⇒ el
mecanismo vive en la RX. **Mecanismo**: el AP agrega bloques de hasta 64
subtramas hacia el dongle; de día cada subtrama dañada por ruido vecinal
obliga a retransmitir el bloque entero (head-of-line), la cola se traga la
latencia y el contador de pérdida no lo ve. ath9k aguanta el mismo HT porque
su path RX/reordenado es mainline maduro.

## Solución (1.9.0)

Ventana RX A-MPDU capada a **16 subtramas** (unidad = nº de buffers, NO
Kbytes — `rtw_mlme_ext.c:3500-3506`) por `rx_ampdu_size_sta_limit()`
(`rtw_mlme_ext.c:3675`) en el ADDBA:

- Default del árbol: `drv_conf.h` `CONFIG_RTW_RX_AMPDU_SZ_LIMIT_1SS = 0x10`.
- Override por módulo: `options 8192eu rtw_rx_ampdu_sz_limit_1ss=0x10,0x10,0x10,0x10`.
- A/B en caliente sin recargar: `echo 1 16 > /proc/net/rtl8192eu/wn8200nd/rx_ampdu`
  (acept=1, tamaño=16 buffers, `RX_AMPDU_DRV_FIXED` + `rtw_rx_ampdu_apply()`
  renegocia el ADDBA al vuelo). Volver a auto: `echo 0xFF 0xFF .../rx_ampdu`.

Coste: algo más de overhead de BlockAck por bloque (baja la eficiencia pico).
Beneficio: bajo ruido, una retransmisión cuesta 1/4 del bloque; el p95 de
latencia deja de explotar.

## Modelo conceptual: "más redes" y "más señal" ⇒ por qué suena a "más ruido"

Tres fenómenos distintos se confunden bajo la palabra "ruido":

| Fenómeno | Qué es | ¿Varía con la hora? |
|---|---|---|
| Ruido de fondo | Energía térmica + RF no decodificable (microondas, BT) | Casi no |
| **Interferencia** | **RÁFAGAS DE TRÁFICO de otros transmisores** pisando las tuyas | **Sí — es lo que cambia de día** |
| Contención | Canal ocupado: tu radio escucha antes de hablar (CCA) y espera | Sí |

- **"Veo más redes"**: el scan lista APs por sus beacons (tramas mínimas,
  constantes, casi gratis). El wn8200nd con cantenna ESCUCHA MÁS LEJOS que
  el ath9k (ganancia + sensibilidad): registra redes que el interno ni ve.
  Pero un AP visible y silencioso no molesta — lo que tumba el enlace es el
  TRÁFICO de esos APs. De madrugada la lista de redes es la misma; lo que
  cambia es que la gente empieza a usarlas. La lista del scan es la guía
  telefónica; la interferencia son las llamadas.
- **"Agarro más señal"**: la ganancia no es un filtro, es un amplificador
  de TODO lo que cae en el lóbulo. Tu AP ya llegaba saturado (-43 dBm) —
  más ganancia no compra nada ahí — pero los vecinos también llegan MÁS
  FUERTES y desde MÁS LEJOS. La cantenna es ventaja neta con el aire vacío
  (madrugada) y amplifica el daño cuando hay ráfagas ajenas (día).
- **Dos vías de daño, efectos distintos**:
  1. *Deferral (TX)*: energía en el canal > umbral ⇒ tu radio espera su
     turno. Afecta por igual a ambos adaptadores; sube el piso de latencia,
     no tumba el enlace. No es el "colapso".
  2. *Corrupción + head-of-line (RX)*: bloque A-MPDU de NAVI (hasta 64
     subtramas) + ráfaga vecinal pisando subtramas ⇒ agujero en la ventana
     de reordenado; todo lo que llega detrás queda "rehén" hasta que el
     timer fuerza la entrega. Firma medida: 0% loss con p95 explotando.
     Específico del port Realtek; es lo que el cap 64→16 acota (el radio de
     explosión de cada agujero baja de 64 a 16 subtramas).
- **Solape parcial agrava la vía RX**: NAVI en ch10 con vecinos en ch9 (×1)
  y ch11 (×2). Co-canal exacto = cortesía CSMA (turnos, se respetan);
  solape parcial = el "escuchar antes de hablar" del vecino NO te protege y
  su energía aterriza dentro de tus 20 MHz como corrupción pura.

## Cómo ver el "ruido" en números

- **Ocupación de canal (vía deferral)**: `iw dev wlan0 survey dump`. El
  driver Realtek no implementa survey; medir con la interfaz ath9k interna
  mientras el wn8200nd lleva tráfico (el canal es compartido: el busy% vale
  para ambos). Incluido en `scripts/diag-daytime.sh`.
- **Head-of-line (vía RX)**: `/proc/net/rtl8192eu/wn8200nd/trx_info`
  (`rtw_debug.c:1996-2007`), contadores acumulados: leer, hacer 60 s de
  actividad diurna, releer y restar.
  - `Reorder Time-out Trigger Counts`: el timer de reordenado venció por un
    agujero que no se llenó a tiempo — el evento head-of-line CAZADO
    (`rtw_recv.c:3513`).
  - `Packet Loss Counts`: subtramas perdidas (tamaño del agujero sumado en
    `recv_indicatepkts_pkt_loss_cnt`, `rtw_recv.c:3471-3481`).
  - `Window Shift Count`: la ventana de BA saltó hacia adelante.
  Con ventana 64 de día suben en ráfagas; con 16, mucho menos. Es la prueba
  objetiva del mecanismo (y del efecto del fix) sin depender de estrellas.

## Limitaciones / notas

- Resultado del usuario (estrellas speed.cloudflare.com), no lab: repetible
  pero subjetivo. Los contadores finos viven en
  `/proc/net/rtl8192eu/wn8200nd/{trx_info,tx_stat,rx_stat}` (`iw station
  dump` solo expone `tx_failed`, no `tx_retries`).
- Sin param para desactivar el RX AMPDU por completo; el límite de tamaño es
  el único knob.
- Tasas fijas por `iw`/`iwconfig` IMPOSIBLES en este driver (sin
  `.set_bitrate_mask`; `rtw_wx_set_rate` es stub `#if 0`). La vía real es
  `/proc/net/rtl8192eu/wn8200nd/rate_ctl` (`0x08`=24M, `0x0B`=54M, `0xFF`=RA).
- Verificación pendiente en la máquina: throughput de madrugada tras el capado
  (el baseline 1.8.0 era 25 Mbps; con 16 subtramas se espera una caída menor
  al 20%). Si aprieta, punto medio: `0x20` (32 subtramas).
- Palanca adicional router-side (gratis, otra vía): NAVI está en ch10, canal
  no estándar, solapado con ch9/ch11/ch12/ch13. Probar un canal estándar
  (1/6/11) elegido con el scan del diag para minimizar solapes parciales con
  los APs más cargados: menos corrupción RX de raíz, complementario al cap.
