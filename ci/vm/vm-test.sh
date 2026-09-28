#!/bin/busybox sh
# vm-test.sh — corre DENTRO de la VM de pruebas. Es el que hace el ciclo
# insmod/rmmod del driver y decide si el banco pasa o falla.
#
# Este script es el contrato de la tarea 7.2. Lo que comprueba:
#   1. el modulo carga (insmod sin error)
#   2. el modulo descarga (rmmod sin "in use" ni referencias colgando)
#   3. el ciclo se repite sin que el segundo intento se degrade
#   4. dmesg NO contiene lineas del driver ni avisos del kernel sobre el modulo
#
# Y lo que NO comprueba, y esta en mayusculas en la salida porque es la
# trampa de este banco (tarea 7.3):
#   - el flapeo del enlace USB: ocurre en el hub y el cable fisicos, y una VM
#     con USB emulado no lo reproduce.
#   - el throughput real: depende de la SNR del vecindario.
# Un banco en verde NO significa que el enlace de la casa este bien.

RESULT=/out/result.txt
DMESG_OUT=/out/dmesg.txt

fail() {
    echo "FAIL: $*" | tee -a "$RESULT"
    dmesg > "$DMESG_OUT"
    # 1 = fallo, para que el runner de QEMU devuelva codigo de error
    poweroff -f
    sleep 30
}
pass() {
    echo "PASS: $*" | tee -a "$RESULT"
}

# --- 0. estado inicial --------------------------------------------------
: > "$RESULT"

# Con un init propio, el kernel NO monta los pseudo-sistemas de ficheros: eso
# lo hace /init de una distro, que aqui no existe. Sin /proc no hay
# /proc/modules, y el test no tendria nada que comprobar.
mount -t proc     proc     /proc 2>/dev/null || echo "aviso: no se pudo montar /proc"
mount -t sysfs    sysfs    /sys  2>/dev/null || echo "aviso: no se pudo montar /sys"
mount -t devtmpfs devtmpfs /dev  2>/dev/null || echo "aviso: no se pudo montar /dev"
[ -r /proc/modules ] || fail "/proc no esta montado: el initramfs no puede verificar nada"

echo "=== banco de pruebas del driver (8192eu) ===" | tee -a "$RESULT"
echo "kernel: $(uname -r)" | tee -a "$RESULT"

# Sin esto, dmesg esta mezclado con la salida de la consola y el grep del
# runner no podria distinguir un aviso del kernel de un linea de este script.
dmesg -n 4

[ -f /lib/modules/8192eu.ko ] || fail "no esta el .ko en /lib/modules"

# --- 1. dependencias ----------------------------------------------------
# El driver no se puede cargar solo: depende de cfg80211, que depende de
# rfkill, que depende del core de USB. La lista la calcula el build (depmod) y
# queda en /lib/modules/load-order.txt, porque el orden importa: cargar el
# driver antes que sus dependencias falla con "unknown symbol", que es un error
# de la IMAGEN, no del driver, y conviene no confundirlos.
if [ -f /lib/modules/load-order.txt ]; then
    while read -r m; do
        [ -n "$m" ] || continue
        if insmod "/lib/modules/$m" 2>/out/insmod-dep.err; then
            echo "cargada dependencia: $m"
        else
            fail "no se pudo cargar la dependencia $m: $(cat /out/insmod-dep.err)"
        fi
    done < /lib/modules/load-order.txt
fi

# --- 2. carga -----------------------------------------------------------
echo "--- ciclo 1: insmod ---" | tee -a "$RESULT"
if ! insmod /lib/modules/8192eu.ko 2>/out/insmod1.err; then
    dmesg > "$DMESG_OUT"
    fail "insmod fallo: $(cat /out/insmod1.err)"
fi
pass "ciclo 1: el modulo carga"

# El modulo tiene que estar registrado de verdad, no solo haber devuelto 0.
grep -q '^8192eu ' /proc/modules || fail "8192eu no aparece en /proc/modules tras insmod"
echo "estado en /proc/modules: $(grep '^8192eu ' /proc/modules)" | tee -a "$RESULT"

# El .ko con la configuracion de 1.8.0 no debe llevar rutas de procfs: si las
# llevara, CONFIG_PROC_DEBUG no estaria busted de verdad. Se comprueba sobre el
# .ko instalado, no sobre el fuente.
if grep -q 'rtl8192eu/' /lib/modules/8192eu.ko; then
    fail "el .ko contiene rutas procfs: CONFIG_PROC_DEBUG=n no se aplico"
fi
pass "el .ko no contiene rutas procfs (CONFIG_PROC_DEBUG=n)"

# --- 2. descarga --------------------------------------------------------
echo "--- ciclo 1: rmmod ---" | tee -a "$RESULT"
if ! rmmod 8192eu 2>/out/rmmod1.err; then
    dmesg > "$DMESG_OUT"
    fail "rmmod fallo: $(cat /out/rmmod1.err)"
fi
pass "ciclo 1: el modulo descarga"

# Sin referencias colgando: si el modulo siguiera listado, el unload no fue
# completo y eso es exactamente el fallo A1 (docs/AUDIT.md) en otra forma.
if grep -q '^8192eu ' /proc/modules; then
    fail "8192eu sigue en /proc/modules tras rmmod: unload incompleto"
fi
pass "ciclo 1: sin referencias colgantes"

# --- 3. segundo ciclo ---------------------------------------------------
# Repite carga y descarga. Un modulo que se carga una vez y deja el sistema
# tocado se manifiesta aqui: el segundo rmmod es donde aparecen las fugas de
# referencia y los use-after-free del work de URB stall.
echo "--- ciclo 2: insmod/rmmod ---" | tee -a "$RESULT"
insmod /lib/modules/8192eu.ko 2>/out/insmod2.err || {
    dmesg > "$DMESG_OUT"; fail "el segundo insmod fallo: $(cat /out/insmod2.err)"; }
grep -q '^8192eu ' /proc/modules || fail "el segundo insmod no registro el modulo"
rmmod 8192eu 2>/out/rmmod2.err || {
    dmesg > "$DMESG_OUT"; fail "el segundo rmmod fallo: $(cat /out/rmmod2.err)"; }
grep -q '^8192eu ' /proc/modules && fail "el segundo rmmod dejo el modulo colgado"
pass "ciclo 2 completo: carga y descarga limpias"

# --- 4. dmesg limpio ---------------------------------------------------
dmesg > "$DMESG_OUT"

# Ninguna linea del driver. Con CONFIG_RTW_DEBUG=n el driver no debe emitir
# nada; es el requisito de driver-runtime-silence.
if grep -q 'RTW:' "$DMESG_OUT"; then
    echo "--- lineas RTW: encontradas ---" >> "$RESULT"
    grep 'RTW:' "$DMESG_OUT" | head -20 >> "$RESULT"
    fail "el driver emitio log con CONFIG_RTW_DEBUG=n"
fi
pass "dmesg sin lineas RTW: (silencio en runtime)"

# Ningun aviso del kernel que mencione el modulo. Un Oops o un WARNING aqui es
# un crash en la carga o en la descarga, que es justo lo que este banco existe
# para detectar.
if grep -qiE 'oops|general protection fault|BUG:|WARNING:|kernel panic' "$DMESG_OUT"; then
    echo "--- avisos del kernel ---" >> "$RESULT"
    grep -iE 'oops|general protection fault|BUG:|WARNING:|kernel panic' \
        "$DMESG_OUT" | head -20 >> "$RESULT"
    fail "el ciclo produjo avisos del kernel"
fi
pass "dmesg sin Oops, WARNING ni panic"

# --- resumen ------------------------------------------------------------
{
    echo ""
    echo "--- LO QUE ESTE BANCO NO CUBRE ---"
    echo "- El flapeo del enlace USB (disabled by hub (EMI?)): ocurre en el hub"
    echo "  y el cable fisicos. Una VM con USB emulado no lo reproduce, y el"
    echo "  core de USB mata el dispositivo ANTES del probe, de modo que"
    echo "  ningun parche del driver es alcanzable en ese camino. Ver"
    echo "  docs/USB-LINK-HANG.md."
    echo "- El throughput real y la sensibilidad: dependen de la SNR del"
    echo "  vecindario y del hardware. Se miden en la maquina (tareas 4.5,"
    echo "  5.3 y 5.5 del change), no aqui."
    echo ""
    echo "Un banco en verde significa que el modulo carga y descarga limpios."
    echo "No significa que el enlace de la casa este bien."
} >> "$RESULT"

echo "TODO CORRECTO" | tee -a "$RESULT"
dmesg > "$DMESG_OUT"
poweroff -f
sleep 30
