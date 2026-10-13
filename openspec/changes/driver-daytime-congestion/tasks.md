# Tasks: driver-daytime-congestion

## 1. Baseline diurno (ANTES de tocar nada)

- [ ] 1.1 Capturar el estado efectivo actual: `cat /etc/modprobe.d/8192eu.conf`,
      `cat /sys/module/8192eu/parameters/rtw_adaptivity_mode`,
      `iw dev wn8200nd info`, `iw reg get`, señal y tasas
      (`wn8200nd-antenna --once`).
- [ ] 1.2 Medir de día (hora pico, vecindario activo): `ping -i 0.2 <gateway>`
      10 min (p50/p95/máx y % pérdida) + descarga 50 MB ×3 + videollamada 15 min.
- [ ] 1.3 Verificar `dmesg` limpio de re-enumeraciones USB durante la medición
      (condición para atribuir a RF; si hay rebotes, derivar a
      `docs/USB-LINK-HANG.md` y abortar este change).
- [ ] 1.4 Medir ocupación vecinal: APs por canal de día
      (`sudo iw dev wn8200nd scan | grep -E 'freq|signal'`), anotar cuántos
      solapan el canal del router NAVI. Queda como insumo para el change de
      canal (fuera de alcance aquí).
- [ ] 1.5 Registrar el baseline en `docs/DAYTIME.md` (formato THROUGHPUT.md:
      contexto del enlace, cifras, limitaciones).

## 2. Fase 1 — parámetros del módulo (sin recompilar)

- [x] 2.1 Editar `/etc/modprobe.d/8192eu.conf`: `rtw_adaptivity_mode=0`,
      `rtw_adaptivity_th_l2h_ini=0`. Resto sin tocar (diff=5, rxgain=0,
      notch=1, rxagg=1, napi=1).
- [x] 2.2 Recargar el módulo y confirmar el valor efectivo.
- [x] 2.3 Repetir la batería de medición de día (speed.cloudflare.com:
      streaming/videogame/calling).
- [x] 2.4 **Resultado (2026-10-14): SIN MEJORA.** El interno (ath9k AR9285)
      sigue superior cara a cara: wn8200nd = 1 estrella, interno = 3 estrellas
      en las tres categorías. La hipótesis EDCCA/carrier_sense no cierra la
      brecha por sí sola. Pendiente de datos del script de diagnóstico para
      atribuir: retries/failed del station dump (RA bajo interferencia),
      re-enumeraciones USB, power_save de cfg80211, ancho negociado.
- [x] 2.5 ~~Candidato B `rtw_hiq_filter=0`~~ **RETIRADO**: la verificación en
      código (`rtw_xmit.c:5208`, `xmitframe_hiq_filter()`) muestra que
      `hiq_filter` enruta tramas TX (ARP/EAPOL/DHCP) a la cola de alta
      prioridad, NO filtra RX por IQ imbalance. `docs/RF-SENSITIVITY.md`
      describía mal el parámetro (corregido en este change). `1` es el valor
      correcto.
- [x] 2.6 ~~Candidato C `rtw_ampdu_factor=5`~~ **NULO como parámetro en este
      IC**: el param solo alimenta rutas VHT (`rtw_vht.c:325/908`) que el
      8192E (11N) no negocia, y el HAL devuelve el factor RX fijo 64K
      (`usb_halinit.c:1687`). Sustituido por **2.10 (C′)** con el parámetro
      que sí está cableado: `rtw_rx_ampdu_sz_limit_1ss`.
- [x] 2.7 **Diagnóstico medido con ambos adaptadores (2026-10-13 14:40/14:43,
      día)**: wn8200nd -43 dBm, rx MCS7/tx MCS6, 0% loss, RTT min 9.9 / p50
      26.5 / máx 92.5 ms; ath9k -62 dBm, tx MCS7, retries 304/233 (130%),
      0.67% loss. power_save off en ambos. Sin re-enumeraciones USB durante
      los pings (hubo 2 a las 14:19, justo tras la recarga del módulo, luego
      estable 20 min). El scan del wn8200nd conectado solo devolvió 1 AP
      (limitación del driver Realtek); el entorno real (11 APs, ch9 ×1 y
      ch11 ×2 solapando el ch10 de NAVI) se ve por ath9k. **Cuidado con el
      script v1**: mezclaba min/avg/max del resumen de ping — el bloque RTT
      del ath9k (p50=261 p95=8.8) es internamente imposible y no sirve.
- [x] 2.8 **power_save de cfg80211**: verificado `off` en ambos adaptadores
      (usuario, 2026-10-13). Descartado como causa.
- [x] 2.9 **Documentado en `docs/DAYTIME.md`** (2026-10-14): caso completo —
      síntoma, ejes descartados con evidencia, diagnóstico medido, aislamiento
      F1/F2/F3′, mecanismo (head-of-line RX), solución 1.9.0 y limitaciones.
- [x] 2.10 **C′ ADOPTADO con valor validado `0x10`**: ver 2.19 y D1.4. El
      paso intermedio `0x20` queda como punto medio documentado si el
      throughput nocturno aprieta.
- [x] 2.11 **Restaurada y confirmada la config de referencia** (sysfs en
      diag-wn8200nd-151622): `rtw_adaptivity_mode=1`,
      `rtw_adaptivity_th_l2h_ini=10`, `th_edcca_hl_diff=5`. Recarga 15:15 sin
      re-enumeraciones USB (a diferencia de la de 14:19). MANTENER: no volver
      a mode=0 sin evidencia (ver D1.2, sospecha de que perjudica).
- [x] 2.12 **diag v2 ejecutado idle+load por adaptador** (2026-10-13
      15:16-15:21): wn8200nd idle P50 2.07 / P95 5.43 ms (0% loss); stonepi
      idle P50 1.68 / P95 5.69 ms (0% loss) — empate en pasarela. Survey
      ath9k: canal ch10 al 8.8-9.9% busy. **Caveat**: el modo load de v2 quedó
      vacío (no hay server iperf3 en NAVI; v2 prefería iperf3 y falló en
      silencio) — corregido en v3. El "load" de stonepi cazó igual un
      episodio (P95 241 ms, máx 482) con el canal al 10% ⇒ episodios
      puntuales no-saturación existen en CUALQUIER adaptador.
- [x] 2.13 ~~A/B concurrente con carga REAL~~ **CERRADA POR DECISIÓN DEL
      USUARIO (2026-10-14)**: no quiere más diagnóstico pasivo con scripts;
      se sustituye por el **protocolo de intervención** (2.14-2.18, ver
      design D4 rev. 3), que manipula features y mide la experiencia.
- [x] 2.14 **F1 — separar agregación (RESULTADO 2026-10-14: SIN EFECTO)**:
      `rtw_ampdu_enable=0` probado con y sin F2, varias rondas. No cambia la
      calidad. Conclusión: la agregación TX no es el mecanismo del colapso
      diurno. Restaurado (quitado del conf).
- [x] 2.15 **F2 — separar HT completo (RESULTADO 2026-10-14: VALIDADO Y
      ADOPTADO)**: `rtw_ht_enable=0` → speed.cloudflare.com pasa de calidad
      **pobre** a **regular**, reproducible (2 rondas: con F1 mezclado y
      solo F2). El usuario lo deja aplicado. El pipeline HT completo (MCS,
      RX A-MPDU 64K, Short GI) es el responsable del colapso diurno; el
      delta F2−F1 acota el sospechoso principal a **RX A-MPDU** (agregación
      de bajada, head-of-line bajo contención) y/o al comportamiento
      MCS/RA — no a la agregación TX (F1) ni a EDCCA (D1.1).
- [x] 2.19 **Refinamiento validado (RESULTADO 2026-10-14: ESTABLE — ADOPTADO)**:
      HT on + `rtw_rx_ampdu_sz_limit_1ss=0x10,0x10,0x10,0x10` → el usuario
      reporta volver a **estable** de día manteniendo tasas MCS. **Corrección
      de unidades**: 0x10 = **16 subtramas**, no 16 KB ("The size variable
      means how many MSDUs or AMSDUs, it's not Kbytes",
      `rtw_mlme_ext.c:3500-3506`); el capado opera en ADDBA vía
      `rx_ampdu_size_sta_limit()` (`:3675`). Knob extra descubierto: proc
      `rx_ampdu` acepta "accept size" en caliente con re-aplicación
      (`rtw_debug.c:3162` → `rtw_rx_ampdu_apply()`, `:3734`).
- [ ] 2.16 **F3 — separar rate-adaptation**: fijar tasa con el proc del driver
      (iw/iwconfig NO funcionan aquí: sin `.set_bitrate_mask` en
      cfg80211_ops y `rtw_wx_set_rate` es stub `#if 0`, ioctl_linux.c:2506):
      `echo 0x08 > /proc/net/rtl8192eu/wn8200nd/rate_ctl` (24M) o `0x0B`
      (54M); volver a RA con `echo 0xFF`. Verificado hasta descriptor TX
      (`rtl8192e_xmit.c:443-451`). Si mejora ⇒ RA agresiva bajo contención
      (parcheo de odm_rainfo como fase 2).
- [ ] 2.17 **F4 — separar WMM/QoS**: `rtw_wmm_enable=0` (cliente, sin tocar
      router) o WMM off en router. Si mejora ⇒ mapeo AC/colas (parcheo de
      mapeo TID→AC). Restaurar tras medir.
- [ ] 2.18 **Contadores reales bajo carga** (sin scripts, 2 capturas
      manuales): `cat /proc/net/rtl8192eu/wn8200nd/trx_info` antes y después
      de una descarga (ver también `tx_stat`, `rx_stat`, `rate_ctl`); solo
      `tx_failed` existe en `iw station dump` (ioctl_cfg80211.c:2598, no hay
      tx_retries). Regla: retries/disparo ⇒ aire/RA; rx_dropped ⇒ USB/buffer;
      nada raro ⇒ cola/agregación.

## 3. Fase 2 — código (EJECUTADA 2026-10-14: default permanente 1.9.0)

> La dirección validada por intervención (2.14-2.19) no requería tocar phydm:
> el fix es el capado de ventana RX A-MPDU ya implementado por Realtek.
> Las tareas 3.1-3.5 del plan antiguo (guard EDCCA) quedan archivadas sin
> parche (ver D1.1/D2). Ejecutado:

- [x] 3.1 `driver/include/drv_conf.h`:
      `CONFIG_RTW_RX_AMPDU_SZ_LIMIT_1SS = {0x10, 0x10, 0x10, 0x10}` con
      comentario del motivo y knobs de override.
- [x] 3.2 Bump DKMS `1.8.1` → `1.9.0` (minor: cambio de comportamiento):
      `dkms.conf`, `install_manual.sh` (VER), CHANGELOG en AGENTS.md.
- [x] 3.3 Tablas de parámetros en `AGENTS.md` actualizadas (fila nueva
      `rtw_rx_ampdu_sz_limit_1ss`; adaptivity actualizado a la referencia
      restaurada mode=1/ini=10) + `docs/DAYTIME.md` (caso completo).
- [ ] 3.4 En la máquina del usuario (fuera de este entorno): recorrer el
      bump DKMS (`/usr/src/rtl8192eu-1.8.1` → `-1.9.0` +
      `dkms remove/add/build/install --force`), recompilar y verificar
      `cat /sys/module/8192eu/parameters/rtw_rx_ampdu_sz_limit_1ss` =
      `16,16,16,16`.
- [ ] 3.5 Aserciones del job `config-assertions` en CI: añadir check del
      default `0x10`; push y CI en verde (`sanity`, `build`, `build-debian`
      6.12, `static-analysis`, `config-assertions`, `vm-load-test`) antes de
      considerar el change archiveable.
- [ ] 3.6 `openspec validate driver-daytime-congestion --strict` en verde y
      archive del change con specs sincronizadas.

## 4. Fuera de alcance (insumos para changes aparte)

- [ ] 4.1 Cambio de canal del router NAVI (9/10) o del AP escama (3) según la
      ocupación medida en 1.4 — vive en el router/repo `escama-ap`, no aquí.
- [ ] 4.2 Offset de potencia de TX por módulo (si la evidencia post-fase-1 lo
      pide): punto de parcheo `hal/hal_com_phycfg.c` →
      `PHY_SetTxPowerIndex_8192E`; NUNCA reactivando TXPWR_LIMIT
      (BUG-TXPOWER-001).
