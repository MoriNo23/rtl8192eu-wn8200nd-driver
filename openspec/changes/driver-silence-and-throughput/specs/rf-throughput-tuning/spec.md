# Spec Delta

## Purpose

Define que la configuración por defecto y la configuración efectiva del driver no
degradan por sí mismas el rendimiento de RF, y fijar las invariantes —región,
potencia, escalado por tasa, agregación, entrega de tramas y ancho de banda— que
un despliegue de barrio denso en 2.4 GHz necesita para descargas rápidas y estables.

## ADDED Requirements

### Requirement: La potencia de transmisión sigue el objetivo del hardware y del dominio regulatorio

En ausencia de una anulación explícita del operador, la potencia de transmisión
efectiva SHALL seguir el objetivo calibrado en el hardware para la banda y la ruta
de RF activas. Ningún componente de espacio de usuario SHALL sostener una anulación
de potencia fija como parte del estado por defecto del sistema.

#### Scenario: El estado por defecto no tiene anulación de potencia

- **WHEN** el sistema arranca con la configuración instalada y el adaptador asociado
- **THEN** ningún proceso de espacio de usuario mantiene una potencia de
  transmisión fija, y la potencia efectiva no excede el objetivo del hardware para
  la banda activa

#### Scenario: La potencia no es plana e igual para todas las tasas

- **WHEN** se inspecciona la política de potencia del driver con el escalado por tasa
  activo
- **THEN** la tasa más alta no requiere más potencia que la más baja, y la potencia
  efectiva se queda en el objetivo del hardware o por debajo

#### Scenario: Una anulación por encima del límite regulatorio se rechaza o se recorta

- **WHEN** un operador solicita una potencia fija superior al límite del dominio
  regulatorio activo
- **THEN** la solicitud se rechaza, o la potencia efectiva queda recortada al
  límite; en ningún caso se emite por encima del límite

### Requirement: El dominio regulatorio no se modifica

El proyecto SHALL mantener el dominio regulatorio tal y como lo proporciona la red
a la que se asocia el adaptador. Ningún cambio de configuración, script o
procedimiento de este proyecto SHALL alterar el dominio regulatorio ni forzar un
código de país.

#### Scenario: La región se mantiene tras instalar y recargar

- **WHEN** se instala la configuración del proyecto y se recarga el módulo con el
  adaptador associado
- **THEN** el dominio regulatorio activo es el mismo que antes del cambio, y sigue
  siendo el que impone la red asociada

#### Scenario: Ningún componente del proyecto fija el país

- **WHEN** se inspecciona el árbol del proyecto y los ficheros de configuración del
  sistema en busca de fijaciones de dominio regulatorio
- **THEN** no existe ninguna orden que establezca el dominio regulatorio, ni ningún
  ajuste de código de país forzado

### Requirement: La entrega de tramas recibidas no es por trama

El camino de recepción de tramas SHALL ser interrumpido y coalescente: no SHALL
entregar cada trama recibida como una invocación de red independiente, y SHALL
coalescer las tramas de un flujo antes de entregarlas a la pila de red.

#### Scenario: Descarga sostenida con entrega coalescida

- **WHEN** se ejecuta una transferencia descendente sostenida sobre el enlace del
  despliegue durante 30 s o más
- **THEN** el rendimiento medido queda limitado por la tasa física negociada y no
  por el coste de entrega por trama

#### Scenario: La coalescencia está activa en el módulo cargado

- **WHEN** se inspecciona la configuración del driver tal y como se distribuye
- **THEN** la recepción interrumpida y la coalescencia de tramas están habilitadas,
  y no hay ningún parámetro de módulo que las deshabilite por defecto

### Requirement: La agregación de recepción USB está activa con umbral definido por el driver

El driver SHALL solicitar agregación de recepción en el enlace USB con un umbral de
tamaño y tiempo definido por el propio driver, en lugar de depender del umbral por
defecto del firmware. Todo parámetro del módulo documentado SHALL tener el efecto
que su documentación afirma: si un valor no es honrado, el driver SHALL rechazarlo en
lugar de sustituirlo silenciosamente por otro.

#### Scenario: La agregación se negocia en la inicialización

- **WHEN** el módulo se carga y el hardware se inicializa
- **THEN** la agregación de recepción USB se negocia en modo DMA con un umbral de
  tamaño y tiempo definido por el driver

#### Scenario: Un valor de parámetro no honrado se hace visible

- **WHEN** el driver recibe un valor de agregación que no puede aplicar tal cual
- **THEN** lo rechaza, o lo registra de forma que el valor efectivo sea
  verificable; no lo sustituye sin que quede constancia

#### Scenario: El valor por defecto del parámetro es honored

- **WHEN** se lee el valor por defecto del parámetro de agregación en el módulo
  cargado
- **THEN** ese valor corresponde al modo de agregación que el driver aplica

### Requirement: El ancho de banda configurado se negocia cuando la red lo permite

Cuando el ancho de banda esté configurado para 40 MHz en 2.4 GHz, el driver SHALL
negociar 40 MHz contra un punto de acceso que lo ofrezca en un canal válido para
40 MHz. La documentación SHALL declarar que el ancho configurado depende del canal
y del ancho que anuncie el punto de acceso, y SHALL que la configuración de 40 MHz
es inerte en un canal que no admita 40 MHz.

#### Scenario: Anuncio de 40 MHz en un canal válido

- **WHEN** el punto de acceso anuncia 40 MHz y está en un canal primario válido
- **THEN** el enlace se negocia a 40 MHz con la configuración de 40 MHz activa

#### Scenario: 40 MHz configurado pero canal o anuncio que no lo admiten

- **WHEN** el punto de acceso anuncia 20 MHz, o está en un canal que no admite
  40 MHz en 2.4 GHz
- **THEN** el enlace se negocia a 20 MHz, y la documentación explica que la
  configuración de 40 MHz no tiene efecto en ese caso

#### Scenario: La documentación declara la dependencia

- **WHEN** un operador consulta la documentación del proyecto sobre el ancho de
  banda
- **THEN** encuentra que la negociación depende del canal y del anuncio del punto de
  acceso, no solo del parámetro del driver

### Requirement: La configuración por defecto no empeora la sensibilidad de recepción

Los parámetros por defecto del driver que afectan a la ganancia y al filtrado de
recepción SHALL mantener la sensibilidad efectiva del enlace. Las opciones cuyo
efecto sobre la sensibilidad no esté verificado en el despliegue SHALL venir
documentadas con su alternativa y su procedimiento de A/B.

#### Scenario: La ganancia de recepción no se atenúa por defecto

- **WHEN** el módulo se carga con la configuración por defecto
- **THEN** el ajuste de ganancia de recepción en 2.4 GHz es neutro, y el filtrado de
  desbalance IQ está documentado con su coste en sensibilidad

#### Scenario: Las opciones sensibles a interferencia están identificadas

- **WHEN** un operador revisa la configuración de recepción del despliegue
- **THEN** encuentra documentadas las opciones que afectan a la sensibilidad, con su
  valor por defecto, su alternativa y cómo medirlas
