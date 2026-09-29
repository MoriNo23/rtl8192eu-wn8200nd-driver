# Throughput — mediciones del enlace wn8200nd

Registro de mediciones de bajada sostenida. Cada cifra lleva su contexto
(red, señal, tasas negociadas), porque un número de velocidad sin contexto
no significa nada.

## 2026-09-29 — efecto de GRO + NAPI (tarea 5.3 del change)

**Contexto del enlace:** red `NAVI-CD91C4` (2.4G, canal 10), IP
`192.168.101.17`, HT20 negociado (tx 65 / rx 52 Mbps — el techo de
1T1R+HT20), señal -50..-57 dBm, región `US: DFS-FCC` (del country IE del
AP). Misma red y señal equivalente al baseline del proposal.

**Antes** (baseline del proposal, esta misma red, -58 dBm):

```
downlink  13.0 Mbps sostenidos
uplink    65.0 Mbps  (techo de 1T1R+HT20)
```

**Después** (3 corridas de 50 MB vía `https://speed.cloudflare.com/__down`,
configuración 1.8.1 con `rtw_en_napi=1`, `rtw_en_gro=1`,
`rtw_usb_rxagg_mode=1`):

```
run1: 25.1 Mbps en 16.0s   CPU busy 11.8%
run2: 26.8 Mbps en 14.9s   CPU busy 12.0%
run3: 25.2 Mbps en 15.8s   CPU busy 11.7%
```

**Estabilidad tras las corridas:** 0% de pérdida al gateway (192.168.101.1),
RTT medio 2.5 ms. Tasas negociadas sin colapsar (siguen tx 65 / rx 52).

**Cualitativo (usuario):** speed.cloudflare.com da "average" en todos los
indicadores y la videollamada se mantiene en "good".

**Lectura:** la bajada pasó de 13 a ~25 Mbps en la misma red y con señal
equivalente (~2x), consumiendo ~12% de CPU durante la transferencia. Eso
cierra la mitad de la asimetría patológica que motivó el change (bajada
muerta frente a una subida al techo). La otra mitad —que el techo físico
de 1T1R+HT20 son 65 Mbps— no se toca desde el driver: es la antena B
desoldada (ver `AGENTS.md`, parche 1T1R).

**Limitaciones, para no vender más de lo que hay:**

- El "antes" (13 Mbps) es del proposal, medido en otra sesión. No es un
  A/B controlado al minuto: es un antes/después con la misma red y señal
  equivalente.
- El endpoint de Cloudflare limita a 50 MB por petición (100 MB devuelve
  403 con un cuerpo de 1 byte). Cada corrida dura ~15 s: suficiente para
  bajada sostenida, no para pruebas de larga duración.
- La señal leyó -78 dBm justo al terminar las corridas y volvió a
  -50/-55 en el minuto siguiente: es la media de RSSI en tránsito, no una
  degradación del enlace.
