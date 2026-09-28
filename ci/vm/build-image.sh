#!/bin/bash
# ci/vm/build-image.sh — construye la imagen de la VM de pruebas del driver.
#
# Qué es: un initramfs mínimo con un busybox estático y el .ko del driver, que
# arranca en QEMU, hace el ciclo insmod/rmmod, y vuelca dmesg por la consola.
#
# Por qué una VM y no un contenedor: un contenedor comparte el kernel del host, así
# que `insmod` desde un contenedor carga el módulo en la máquina. Verificado el
# 2026-09-28: un .ko de prueba cargado con `docker run --privileged` aparece en el
# /proc/modules del host. Ver design.md Restricción 5 y D9.
#
# Uso:
#   ci/vm/build-image.sh <kernel-debian-6.12.deb> <driver.ko> <salida-initrd>
#
# El .deb del kernel se pasa por parametro a proposito: el script no decide la
# version, la elige quien lo invoca. Asi el CI puede actualizar la version del
# kernel sin tocar este fichero.
set -euo pipefail

# die existe aqui (no se comparte con ci/static-analysis.sh, que tiene el suyo).
die() { echo "ERROR: $*" >&2; exit 1; }

KERNEL_DEB="${1:?falta el .deb del kernel}"
KO="${2:?falta el .ko del driver}"
OUT="${3:?falta la ruta del initrd de salida}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Desempaquetando $KERNEL_DEB"
mkdir -p "$WORK/kernel"
# dpkg-deb -x no necesita root niScripts: extrae en un directorio arbitrario.
dpkg-deb -x "$KERNEL_DEB" "$WORK/kernel"

# El vmlinuz real vive en linux-image-<ver>, no en linux-headers ni en el -dbg.
VMLINUZ="$(find "$WORK/kernel/boot" -name 'vmlinuz-*' -type f | head -1)"
[ -n "$VMLINUZ" ] || { echo "ERROR: no hay vmlinuz en el .deb" >&2; exit 1; }
echo "==> kernel: $VMLINUZ"

# En Debian el kernel va a /boot y los modulos a /usr/lib/modules (NO a
# /lib/modules, que es un symlink que el paquete no crea). Se buscan los dos.
MODDIR=""
for cand in "$WORK/kernel/lib/modules" "$WORK/kernel/usr/lib/modules"; do
    if [ -d "$cand" ]; then
        d="$(find "$cand" -maxdepth 1 -mindepth 1 -type d | head -1)"
        [ -n "$d" ] && { MODDIR="$d"; break; }
    fi
done
[ -n "$MODDIR" ] || { echo "ERROR: no hay arbol de modulos en el .deb" >&2; exit 1; }
echo "==> moddir: $MODDIR"

# ---------------------------------------------------------------- initramfs --
# El kernel deja los pseudo-sistemas de ficheros montados en /proc, /sys y /dev
# al arrancar el init (mount -t proc proc /proc, etc.), asi que el initramfs solo
# necesita los directorios. Lo que SI hace falta es que existan.
mkdir -p "$WORK/root"/{bin,sbin,proc,sys,dev,mnt,tmp,lib/modules,out,root}

cp "$KO" "$WORK/root/lib/modules/8192eu.ko"

# busybox estatico: sin el, el initramfs no tiene shell ni coreutils.
BUSYBOX="${BUSYBOX:-$(command -v busybox || true)}"
if [ -z "$BUSYBOX" ]; then
    echo "ERROR: busybox no encontrado. Instala busybox-static." >&2
    exit 1
fi
echo "==> busybox: $BUSYBOX"

# busybox hay que COPIARLO y crear los enlaces: sin esto el initramfs no tiene
# shell ni las utilidades que usa el test, y el kernel falla al arrancar el init
# con "Failed to execute /out/vm-test.sh (error -2)" (ENOENT), que es el mismo
# sintoma que un script ausente.
cp "$BUSYBOX" "$WORK/root/bin/busybox"
chmod 755 "$WORK/root/bin/busybox"
( cd "$WORK/root/bin" && for applet in \
      sh ash ls cat echo grep sed awk head tail wc sort uniq cut tr tee \
      mkdir rm cp mv ln chmod sleep sync printf test true false env \
      mount umount insmod rmmod lsmod modprobe depmod dmesg \
      poweroff reboot halt uname date; do
      ln -sf busybox "$applet"
  done
  cd "$WORK/root/sbin" && for applet in insmod rmmod lsmod modprobe depmod \
      poweroff reboot halt mount umount ifconfig dmesg; do
      ln -sf ../bin/busybox "$applet"
  done
)

# El driver necesita cfg80211, y cfg80211 necesita rfkill, y este necesita el
# core de USB. Adivinarlo es fragil: si el kernel cambia sus dependencias,
# `insmod` falla con "unknown symbol" y no queda claro si es un problema del
# driver o de la imagen. Se le pregunta a depmod, que es quien tiene la verdad.
#
# El .ko del driver se mete en el arbol de modulos antes de indexar, para que
# depmod lo vea y calcule su cierre de dependencias.
mkdir -p "$WORK/kernel/usr/lib/modules" "$MODDIR/extra"
cp "$KO" "$MODDIR/extra/8192eu.ko"

DEPMOD="$(command -v depmod || echo /usr/sbin/depmod)"
MODPROBE="$(command -v modprobe || echo /usr/sbin/modprobe)"
[ -x "$DEPMOD" ] || die "depmod no encontrado (instala kmod)"

KVER_VM="$(basename "$MODDIR")"
mkdir -p "$WORK/lib"
ln -sfn "$WORK/kernel/usr/lib/modules" "$WORK/lib/modules"
"$DEPMOD" -b "$WORK" "$KVER_VM" || die "depmod fallo"

# Lista de modulos a cargar, en orden de dependencia, deducida por modprobe.
DEPS="$("$MODPROBE" --set-version "$KVER_VM" --dirname "$WORK" \
        --ignore-install --show-depends 8192eu 2>/dev/null \
        | sed -n 's/^insmod //p' | sed 's/ .*//' \
        | grep -v '/8192eu\.ko$')"
if [ -z "$DEPS" ]; then
    die "no se pudo calcular las dependencias del driver con modprobe"
fi
echo "==> dependencias calculadas por depmod:"
echo "$DEPS" | sed 's/^/    /'

# Copia esos modulos al initramfs, descomprimiendo los .ko.xz (insmod no los
# acepta, y el busybox del initramfs no trae xz).
ORDER="$WORK/root/lib/modules/load-order.txt"
: > "$ORDER"
for f in $DEPS; do
    # modprobe devuelve la ruta ABSOLUTA ya con el prefijo del arbol de modulos.
    # Hay que quitarselo para poder abrirla en $MODDIR (que esta en otro sitio).
    rel="${f#"$WORK/lib/modules/$KVER_VM/"}"
    src="$MODDIR/$rel"
    [ -f "$src" ] || { echo "  (aviso: no existe $src)"; continue; }
    base=$(basename "$src")
    case "$base" in
        *.xz|*.zst) plain="${base%.*}"; xz -dkf "$src" 2>/dev/null || true
                    [ -f "$(dirname "$src")/$plain" ] && base="$plain" ;;
    esac
    cp "$(dirname "$src")/$base" "$WORK/root/lib/modules/"
    echo "$base" >> "$ORDER"
    echo "  + $base"
done
echo "==> orden de carga: $(tr '\n' ' ' < "$ORDER")"

# El script de prueba vive en el initramfs y es lo que corre dentro de la VM.
# Se pone con el shebang apuntando a busybox, que es el unico shell del initramfs.
cp "$(dirname "$0")/vm-test.sh" "$WORK/root/out/vm-test.sh"
chmod +x "$WORK/root/out/vm-test.sh"

# ------------------------------------------------------------ empaquetado --
echo "==> Empaquetando initramfs en $OUT"
( cd "$WORK/root" && find . -print0 | cpio --null -o --format=newc 2>/dev/null ) \
    | gzip -9 > "$OUT"
echo "==> initramfs: $OUT ($(du -h "$OUT" | cut -f1))"

# El kernel se deja junto para que el runner lo localize.
cp "$VMLINUZ" "$OUT.kernel"
echo "==> kernel: $OUT.kernel ($(du -h "$OUT.kernel" | cut -f1))"

# El moddir completo, para el caso de que el runner quiera usarlo tal cual.
echo "==> moddir original: $MODDIR"
