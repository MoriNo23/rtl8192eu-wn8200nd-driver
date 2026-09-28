#!/bin/bash
# ci/vm/run.sh — arranca la VM de pruebas y devuelve el codigo de salida del
# test que corre dentro. Si el test falla dentro, aqui falla tambien.
#
# Uso:
#   ci/vm/run.sh <initrd> <kernel> [segundos-timeout]
#
# ACELERACION
#   /dev/kvm no es usable en la maquina de despliegue (abre con EINVAL), asi que
#   por defecto corre con emulacion de software (TCG). Es lenta: llegar a insmod
#   tarda minutos. Si /dev/kvm llega a estar disponible, se usa sola y sin
#   cambiar nada mas del runner.
set -uo pipefail

INITRD="${1:?falta el initrd}"
KERNEL="${2:?falta el kernel}"
TIMEOUT="${3:-600}"
OUTDIR="${OUTDIR:-vmout}"
SERIAL="$OUTDIR/console.log"

mkdir -p "$OUTDIR"

# Decide aceleracion: KVM si esta disponible y usable, si no TCG.
ACCEL="tcg"
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    if python3 - <<'PY' 2>/dev/null
import os, sys
try:
    fd = os.open("/dev/kvm", os.O_RDWR)
except OSError:
    sys.exit(1)
try:
    os.read(fd, 4)
except OSError:
    sys.exit(1)
finally:
    os.close(fd)
sys.exit(0)
PY
    then
        ACCEL="kvm"
    fi
fi
echo "aceleracion: $ACCEL"

# -nographic : serie a stdout, sin ventana
# -no-reboot : el apagado de la VM es el final real, no un reinicio
# -append    : el init del initramfs ejecuta el test y apaga
# console=ttyS0 : dmesg y la salida del test van al puerto serie, que es el
#                  unico canal disponible sin consola grafica
CMD=(qemu-system-x86_64
     -accel "$ACCEL" -m 512 -smp 2
     -kernel "$KERNEL" -initrd "$INITRD"
     -append "console=ttyS0 quiet panic=1 rdinit=/out/vm-test.sh"
     -nographic -no-reboot
     -drive file=/dev/null,if=none,id=hd0
)

echo "arrancando la VM (timeout ${TIMEOUT}s)..."
timeout --signal=TERM "$TIMEOUT" "${CMD[@]}" > "$SERIAL" 2>&1
QEMU_RC=$?

echo "qemu termino con rc=$QEMU_RC"
echo "--- ultimas lineas de la consola ---"
tail -25 "$SERIAL"

# El veredicto lo da el propio test, escrito en /out/result.txt. Es mas fiable
# que el codigo de salida de QEMU, que tambien es 0 cuando la VM se apaga bien
# despues de fallar el test (poweroff -f).
#
# El criterio es explicito y NO busca frases sueltas: el test imprime "TODO
# CORRECTO" solo si pasan TODAS sus comprobaciones, y cada fallo imprime
# "FAIL:". Preguntar por esas dos cosas no depende de como se redacte cada
# mensaje intermedio.
if grep -q '^FAIL:' "$SERIAL"; then
    echo ""
    echo "==> BANCO EN ROJO"
    echo "motivo: $(grep '^FAIL:' "$SERIAL" | head -1)"
    exit 1
fi
if grep -q 'TODO CORRECTO' "$SERIAL"; then
    echo ""
    echo "==> BANCO EN VERDE: el modulo carga y descarga limpiamente"
    echo "    (recuerda: esto NO prueba el enlace USB fisico ni el throughput;"
    echo "     ver la seccion 'LO QUE ESTE BANCO NO CUBRE' en el log)"
    exit 0
fi

echo ""
echo "==> BANCO EN ROJO: la VM no llego a dar veredicto"
echo "    (puede ser timeout, o un panic antes de empezar el test)"
exit 1
