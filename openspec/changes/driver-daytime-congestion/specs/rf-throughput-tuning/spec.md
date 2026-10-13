# rf-throughput-tuning Specification

## ADDED Requirements

### Requirement: El enlace retrocede ante ocupación vecinal del canal

El driver SHALL operar por defecto con la adaptividad EDCCA en modo normal,
de modo que la escucha antes de transmitir considere el tráfico vecinal por
debajo del nivel del propio enlace. El modo carrier_sense SHALL quedar
disponible solo como anulación explícita del operador, y el umbral L2H
configurado por el operador SHALL ser respetado en ambos modos.

#### Scenario: El modo por defecto retrocede ante tráfico vecinal

- **WHEN** el módulo se carga con la configuración distribuida y el canal
  tiene ocupación vecinal por debajo del nivel del propio enlace
- **THEN** el modo EDCCA efectivo es la adaptividad normal y el umbral L2H
  queda en el valor por defecto del driver para 11N (`th_l2h_ini = -11`),
  no en el del carrier_sense

#### Scenario: La anulación a carrier_sense sigue disponible

- **WHEN** el operador fija `rtw_adaptivity_mode=1` en `8192eu.conf` y
  recarga el módulo
- **THEN** el comportamiento carrier_sense queda activo exactamente como en
  1.8.1, con el guard de `th_l2h_ini` existente respetando el valor del
  operador

#### Scenario: El umbral configurado no se pisa en modo normal

- **WHEN** el operador fija un `rtw_adaptivity_th_l2h_ini` distinto de 0 vía
  modprobe con la adaptividad en modo normal
- **THEN** el driver usa ese valor en lugar de sobrescribirlo con el default
  de 11N, en paridad con el comportamiento de carrier_sense

#### Scenario: La verificación es comportamental, no de ficheros

- **WHEN** se valida este requirement en el despliegue, donde el debug de
  phydm es inalcanzable (`CONFIG_PROC_DEBUG=n`)
- **THEN** la validación se hace midiendo la latencia diurna bajo ocupación
  vecinal (p95 de RTT y pérdida al gateway) antes y después del cambio, con
  `dmesg` libre de eventos USB durante la medición
