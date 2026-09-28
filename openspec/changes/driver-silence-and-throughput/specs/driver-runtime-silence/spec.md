# Spec Delta

## Purpose

Define la superficie de silencio del driver: qué se garantiza que el módulo **no**
emite ni expone en runtime, de modo que el equipo funcione sin ruido de kernel
periódico y sin dependencias de monitorización que nadie consume.

## ADDED Requirements

### Requirement: El driver no emite logging en runtime

El driver no SHALL emitir líneas de log propias (`RTW_INFO`, `RTW_WARN`, `RTW_DBG`)
durante la operación normal: enumeración, asociación, transferencia de datos,
re-enumeración tras desconexión y apagado. Las condiciones de error irrecuperables
que impiden seguir operando MAY seguir registrándose, siempre que no sean
periódicas.

#### Scenario: Sesión estable sin tráfico de depuración

- **WHEN** el adaptador está asociado y transmitiendo durante 30 minutos
- **THEN** el buffer del kernel no recibe ninguna línea nueva del driver

#### Scenario: El ciclo de vida completo no produce log

- **WHEN** el módulo se carga, la interfaz se asocia, se transfieren datos y el
  módulo se descarga
- **THEN** ninguna de esas transiciones añade líneas de log del driver al buffer
  del kernel

#### Scenario: La desconexión USB no inunda el log

- **WHEN** el dispositivo se desconecta y se re-enumera por un flapeo del enlace
  USB
- **THEN** el log muestra el desenlace de la enumeración, no un volcado por
  paquete ni por transferencia fallida

### Requirement: No existe superficie de depuración alcanzable en runtime

El driver no SHALL exponer un árbol de ficheros procfs de depuración, y en
consecuencia ningún proceso de espacio de usuario SHALL poder habilitar en runtime
el bitmask de componentes de depuración de la capa PHY.

#### Scenario: El árbol procfs no se monta

- **WHEN** el módulo está cargado y la interfaz existe
- **THEN** no existe ningún directorio de depuración del driver bajo `/proc/net/`

#### Scenario: El bitmask de depuración es inalcanzable

- **WHEN** un proceso intenta activar cualquier componente de depuración PHY
- **THEN** no existe ninguna interfaz — ni fichero, ni parámetro de módulo, ni
  ioctl, ni comando de vendor — que lo active

#### Scenario: El nivel de log en runtime no es un parámetro expuesto

- **WHEN** se inspeccionan los parámetros del módulo
- **THEN** no existe ningún parámetro que controle el nivel de log del driver

### Requirement: No quedan artefactos de monitorización del driver

El repositorio y el sistema no SHALL mantener scripts de watchdog, ficheros de
muestra ni tareas programadas que recojan telemetría del driver. Ningún flujo de
verificación SHALL depender de ellos.

#### Scenario: El árbol del repositorio no contiene recolección de telemetría

- **WHEN** se inspecciona el árbol del repositorio en busca de scripts o datos
  recolectados del driver
- **THEN** no existe ningún script de watchdog ni fichero de muestras

#### Scenario: Ninguna tarea programada recolecta telemetría del driver

- **WHEN** se inspecciona la configuración de tareas programadas del sistema
- **THEN** ninguna tarea ejecuta recolección de telemetría del driver

#### Scenario: La verificación no depende de datos recolectados

- **WHEN** se ejecuta la verificación del proyecto
- **THEN** se sostiene únicamente con el estado actual del sistema y con GitHub
  Actions, sin ningún histórico previamente recolectado

### Requirement: Los procedimientos de recarga no activan depuración

Los procedimientos documentados de recarga del módulo no SHALL dejar ningún
componente de depuración activado, ni activar el logging del driver como paso
intermedio.

#### Scenario: Recargar el módulo no activa depuración

- **WHEN** se ejecuta el procedimiento documentado de recarga del módulo con el
  driver ya instalado
- **THEN** el procedimiento no activa ningún componente de depuración y no deja
  ninguno activo

### Requirement: Las herramientas de antena siguen funcionando sin depuración

Las herramientas que informan de la señal por ruta de RF o agregada SHALL obtener
sus datos de una interfaz que exista con la superficie de depuración del driver
deshabilitada. Ninguna herramienta SHALL requerir que el driver exponga datos de
depuración para cumplir su función.

#### Scenario: La herramienta de antena informa de la señal

- **WHEN** se ejecuta la herramienta de comprobación de antena con el driver
  instalado y sin superficie de depuración
- **THEN** informa del nivel de señal de la interfaz y termina correctamente

#### Scenario: La herramienta de orientación informa de la señal por ruta

- **WHEN** se ejecuta la herramienta de orientación de antena para deciding el
  giro físico de la antena direccional
- **THEN** informa del nivel de señal por ruta de RF sin depender de ficheros de
  depuración del driver

### Requirement: El silencio no degrada la recuperabilidad

La ausencia de logging periódico no SHALL impedir el diagnóstico de un fallo. Los
puntos de fallo que quedan fuera de la superficie de depuración — entre ellos, una
desconexión del enlace USB decidida por el host — SHALL quedar documentados con su
procedimiento de diagnóstico y recuperación en la documentación del proyecto.

#### Scenario: Un fallo del enlace USB se puede diagnosticar sin depuración

- **WHEN** el adaptador deja de ser usable por un fallo del enlace USB y el
  operador consulta la documentación del proyecto
- **THEN** encuentra cómo distinguir un fallo del enlace USB de un fallo del
  driver, y un procedimiento de recuperación

#### Scenario: Un fallo del driver se puede diagnosticar sin depuración

- **WHEN** el driver no carga o no expone la interfaz y el operador consulta la
  documentación del proyecto
- **THEN** encuentra un procedimiento de diagnóstico basado en el log del núcleo y
  en las aserciones de CI, no en la depuración en runtime
