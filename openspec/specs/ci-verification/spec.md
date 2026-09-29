# ci-verification Specification

## Purpose

Define que la verificación del driver —compilación y análisis estático— se ejecuta
en GitHub Actions y no en la máquina del desarrollador, y que la configuración
distribuida está protegida por aserciones automáticas que fallan ante una
regresión silenciosa.

## Requirements

### Requirement: La compilación se verifica en CI

Toda compilación del driver SHALL ejecutarse en GitHub Actions. Una revisión que
introduzca un error de compilación SHALL dejar el CI en rojo antes de poder
fusionarse.

#### Scenario: Una regresión de compilación se detecta antes de fusionar

- **WHEN** se abre una revisión que no compila
- **THEN** el job de compilación falla y la revisión no puede fusionarse

#### Scenario: La compilación cubre el kernel del despliegue

- **WHEN** se ejecuta el job de compilación
- **THEN** se compila contra las cabeceras de la familia de kernel del despliegue,
  además de contra las cabeceras por defecto del runner

#### Scenario: El artefacto compilado se valida

- **WHEN** el job de compilación termina con éxito
- **THEN** comprueba que el módulo generado es válido, expone el identificador USB
  del adaptador, y contiene los símbolos que el despliegue depende de

### Requirement: El análisis estático se ejecuta en CI con baseline

GitHub Actions SHALL ejecutar el análisis estático del árbol del driver en cada
integración. El job SHALL comparar contra un baseline registrado y SHALL fallar
únicamente ante hallazgos nuevos, no ante el ruido heredado del árbol de vendor.

#### Scenario: Un hallazgo nuevo hace fallar el job

- **WHEN** una revisión introduce un hallazgo de análisis estático que no está en el
  baseline
- **THEN** el job falla e identifica el hallazgo

#### Scenario: El ruido preexistente no hace fallar el job

- **WHEN** el árbol tiene los hallazgos heredados registrados en el baseline
- **THEN** el job pasa y reporta el recuento sin marcarlo como error

#### Scenario: El baseline no se puede eludir

- **WHEN** una revisión elimina o vacía el baseline sin registrar el recuento actual
- **THEN** el job falla, de modo que el baseline solo se actualiza de forma explícita
  y revisable

### Requirement: La configuración distribuida está protegida por aserciones

GitHub Actions SHALL verificar mecánicamente la configuración de build y los valores
por defecto de los parámetros del módulo que el despliegue depende de, de modo que
revertirlos falle la integración en lugar de degradar la máquina en silencio.

#### Scenario: Revertir una opción de silencio falla la integración

- **WHEN** una revisión reactiva el logging en runtime o la superficie de depuración
  en la configuración de build
- **THEN** el job de aserciones falla

#### Scenario: Un valor por defecto que el driver no honra falla la integración

- **WHEN** una revisión fija un valor por defecto de parámetro que el driver sustituye
  o ignora en la inicialización
- **THEN** el job de aserciones detecta la discrepancia y falla

#### Scenario: Las invariantes del despliegue siguen verificándose

- **WHEN** se ejecuta el job de aserciones
- **THEN** comprueba la versión, la identidad USB del adaptador, los parámetros
  críticos del enlace y de RF, y la presencia de los símbolos de corrección de
  estabilidad

### Requirement: La verificación documentada no se ejecuta en local

El flujo de verificación documentado del proyecto SHALL conducir la compilación y
el análisis estático a GitHub Actions. La documentación SHALL indicar que el flujo
de verificación no requiere compilar ni analizar el árbol en la máquina del
desarrollador, y las instrucciones de desarrollo SHALL ser coherentes con esa regla.

#### Scenario: La documentación define la ruta de verificación

- **WHEN** un desarrollador o un agente consulta el flujo de verificación del proyecto
- **THEN** encuentra que la verificación se hace en la integración continua y que
  no debe compilar ni analizar el árbol localmente

#### Scenario: Las instrucciones de desarrollo no exigen verificación local

- **WHEN** un desarrollador o un agente sigue las instrucciones de contribución del
  proyecto de principio a fin
- **THEN** ninguna instrucción le exige compilar o analizar el árbol localmente, y
  ninguna depende de artefactos de compilación locales

### Requirement: La carga y la descarga del módulo se verifican en aislamiento

La verificación de que el módulo **carga y descarga correctamente** —el ciclo
`insmod`/`rmmod`, y la ausencia de ruido en el log del núcleo durante ese ciclo—
SHALL ejecutarse en un entorno que no comparta kernel con la máquina del
desarrollador, y SHALL formar parte de la integración continua.

Un contenedor no cumple este requisito: comparte el kernel del host, de modo que
cargar el módulo desde un contenedor lo carga en la máquina. La verificación
SHALL usar un entorno con kernel propio.

#### Scenario: El módulo carga y descarga sin fugas

- **WHEN** el job de carga se ejecuta
- **THEN** el módulo se insmod sin error, se rmmod sin dejar referencias ni
  fallar con "in use", y el ciclo se repite

#### Scenario: El ciclo completo no produce log del driver

- **WHEN** el ciclo `insmod`/`rmmod` termina
- **THEN** el `dmesg` del entorno de prueba no contiene ninguna línea del driver,
  ni avisos del kernel que mencionen el módulo

#### Scenario: La carga no depende de la máquina del desarrollador

- **WHEN** se ejecuta la verificación de carga
- **THEN** el kernel del entorno de prueba es distinto del kernel del host, de modo
  que el resultado no puede depender de lo que tenga cargado la máquina

### Requirement: CI no se degrada al añadir verificación

Añadir jobs de verificación SHALL preservar todas las garantías que los jobs
existentes ya dan, incluidos los chequeos de cordura del árbol, la compilación
condicional con coexistencia de Bluetooth, y la limpieza de artefactos.

#### Scenario: Los jobs existentes siguen presentes y en verde

- **WHEN** el flujo de verificación se ejecuta sobre un árbol correcto
- **THEN** los jobs previos a este cambio siguen ejecutándose y en verde, con sus
  aserciones intactas

#### Scenario: La compilación con coexistencia de Bluetooth no se pierde

- **WHEN** se ejecuta el flujo de verificación completo
- **THEN** sigue compilándose la variante con coexistencia de Bluetooth activada
