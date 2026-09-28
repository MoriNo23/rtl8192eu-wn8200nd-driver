# ci/vm — banco de pruebas de carga y descarga del módulo

## Qué es y por qué existe

Un banco que arranca un kernel de verdad, carga el driver con `insmod`, lo
descarga con `rmmod`, repite el ciclo, y comprueba que el `dmesg` de ese ciclo
sale limpio.

**No es un contenedor, y no puede serlo.** Un contenedor comparte el kernel del
host: `insmod`/`rmmod`/`modprobe` no están dentro de su frontera de aislamiento.
Verificado empíricamente el 2026-09-28 con un `.ko` de prueba inocuo:

```bash
docker run --privileged -v /tmp/modtest:/m:ro ubuntu:24.04 insmod /m/noop.ko
grep noop /proc/modules        # en el HOST: aparece
```

Cargar el driver desde un contenedor sería, en esta máquina, **desmontar y
remontar el adaptador que da la WAN del AP `escama`**, sin red de seguridad. La
VM tiene kernel propio, así que el ciclo `insmod`/`rmmod` es inocuo para el host.

Ver `openspec/changes/driver-silence-and-throughput/design.md`, Restricción 5 y
decisión D9.

## Por qué carga y descarga, y no solo compilar

El fix A1 de `docs/AUDIT.md` —el work de URB stall que despierta sobre un adapter
liberado— **solo se manifiesta en la descarga** del módulo. Un job que
comprobara únicamente que el `.ko` compila y enlaza pasaría por encima de ese
fallo sin verlo. Por eso el banco repite el ciclo dos veces: un módulo que se
carga una vez y deja el sistema tocado se manifiesta en el segundo `rmmod`.

## Uso

```bash
# 1. el .deb del kernel del despliegue (el script NO decide la versión)
ci/vm/pick-kernel.py <Packages-de-trixie>    # -> nombre y ruta del paquete
curl -O http://deb.debian.org/debian/<ruta>

# 2. la imagen
ci/vm/build-image.sh kernel.deb driver/8192eu.ko /tmp/initrd.img

# 3. el ciclo
OUTDIR=/tmp/out ci/vm/run.sh /tmp/initrd.img /tmp/initrd.img.kernel 600
```

En CI esto es el job `vm-load-test` del workflow.

## Ficheros

| Fichero | Rol |
|---|---|
| `build-image.sh` | Desempaqueta el `.deb` del kernel, calcula el cierre de dependencias del driver con `depmod`, copia esos módulos al initramfs, y lo empaqueta |
| `vm-test.sh` | Corre **dentro** de la VM. Hace el ciclo y decide verde/rojo |
| `run.sh` | Arranca QEMU, recoge la consola, y traduce el veredicto a código de salida |
| `pick-kernel.py` | Elige el paquete `linux-image` correcto en el índice de Debian |

## Detalles que no son evidentes

**Las dependencias se calculan, no se escriben a mano.** El driver necesita
`cfg80211`, que necesita `rfkill`, que necesita el core de USB. Si el kernel
cambia sus dependencias y la lista está escrita a mano, `insmod` falla con
`unknown symbol` y no queda claro si el problema es del driver o de la imagen.
`build-image.sh` mete el `.ko` en el árbol de módulos y le pregunta a `depmod`.

**Los `.ko` de Debian vienen en `.ko.xz` y `insmod` no los lee.** Se descomprimen
al construir la imagen, porque el busybox del initramfs no trae `xz`.

**Con un `init` propio, el kernel no monta `/proc`.** Eso lo hace el `/init` de
una distro, que aquí no existe. `vm-test.sh` los monta al empezar: sin `/proc`
no hay `/proc/modules` y el test no tiene nada que comprobar.

**El veredicto se lee del texto, no del código de salida de QEMU.** QEMU devuelve
0 también cuando la VM se apaga limpiamente *después* de fallar el test. El
runner busca `FAIL:` y `TODO CORRECTO`, que el test solo escribe si pasan todas
las comprobaciones.

**Aceleración:** `/dev/kvm` existe pero en la máquina de despliegue no es usable
(`open()` devuelve `EINVAL`), así que QEMU corre por emulación de software. Por
eso el arranque tarda ~15 s y el CI le pasa 900 s de timeout. `run.sh` usa KVM
solo si detecta que funciona, así que el día que se habilite no hay que tocar
nada.

## Qué NO cubre este banco

Está escrito en mayúsculas en la salida del test, no escondido:

- **El flapeo del enlace USB** (`disabled by hub (EMI?)`). Ocurre en el hub y el
  cable físicos, y una VM con USB emulado no lo reproduce. Además el core de USB
  mata el dispositivo *antes* del probe, así que ningún parche del driver es
  alcanzable en ese camino. Ver `docs/USB-LINK-HANG.md`.
- **El throughput real y la sensibilidad.** Dependen de la SNR del vecindario y
  del hardware. Se miden en la máquina (tareas 4.5, 5.3 y 5.5 del change).

**Un banco en verde significa que el módulo carga y descarga limpios. No
significa que el enlace de la casa esté bien.**

## Cuando falla

1. El job sube `console.log` como artefacto, que incluye el `dmesg` de la VM.
2. Distinguir «la imagen está mal» de «el driver está mal»:
   - `unknown symbol` → faltan dependencias de la imagen, no es el driver.
   - `version magic` → el `.ko` se compiló contra otro kernel.
   - `Oops` / `WARNING` / `call trace` en el `dmesg` → **esto sí es el driver**.
