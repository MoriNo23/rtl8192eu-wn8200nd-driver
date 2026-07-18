#!/bin/bash
# wifi_manager.sh — Gestor interactivo del driver rtl8192eu (TL-WN8200ND)
#
# Resuelve la confusión de DKMS: SIEMPRE borra el source viejo de /usr/src y
# copia tu build reciente del repo ANTES de compilar. Así el DKMS nunca usa
# una copia olvidada; cuando el kernel cambie, el auto-rebuild usa tus features.
#
# Modos:
#   1) Instalar     — primera vez (o forzar desde cero)
#   2) Actualizar   — ya existía; borra todo lo viejo y reinstala limpio
#   3) Desinstalar  — limpia TODO (módulo, /lib/modules, /usr/src, /var/lib/dkms)
#
# Uso: sudo ./wifi_manager.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DRIVER_DIR="$REPO_DIR/driver"
KO_SRC="$DRIVER_DIR/8192eu.ko"
PKG="rtl8192eu"
VER="1.0"
USRSRC="/usr/src/$PKG-$VER"
DKMSBUILD="/var/lib/dkms/$PKG"
KVER=$(uname -r)
KO_DST="/lib/modules/$KVER/kernel/drivers/net/wireless/8192eu.ko"

is_loaded()   { lsmod | grep -q "^8192eu "; }
is_dkms()     { sudo dkms status 2>/dev/null | grep -q "$PKG/$VER"; }
is_installed(){ [ -f "$KO_DST" ] || is_dkms; }

cleanup_old() {
  echo "  -> Descargando módulo si está cargado..."
  sudo rmmod 8192eu 2>/dev/null || true
  echo "  -> Borrando source viejo de /usr/src y build de DKMS..."
  sudo rm -rf "$USRSRC"
  sudo rm -rf "$DKMSBUILD"
  echo "  -> Quitando de DKMS si existía..."
  sudo dkms remove -m "$PKG" -v "$VER" --all 2>/dev/null || true
  echo "  -> Borrando .ko instalado en /lib/modules..."
  sudo rm -f "$KO_DST"
  sudo rm -f /etc/modprobe.d/blacklist-rtl8xxxu.conf
  if grep -qxF "8192eu" /etc/modules 2>/dev/null; then
    sudo sed -i '/^8192eu$/d' /etc/modules
  fi
}

compile_repo() {
  echo "  -> Compilando driver/8192eu.ko desde tu repo..."
  make -C "$DRIVER_DIR" -j"$(nproc)" clean
  make -C "$DRIVER_DIR" -j"$(nproc)" all
  echo "  -> Build listo: $KO_SRC"
}

do_install() {
  cleanup_old
  compile_repo
  echo "  -> Copiando tu build reciente a /usr/src (source fresco para DKMS)..."
  sudo mkdir -p "$USRSRC"
  sudo cp -ar "$REPO_DIR/." "$USRSRC/"
  echo "  -> blacklist rtl8xxxu..."
  echo "blacklist rtl8xxxu" | sudo tee /etc/modprobe.d/blacklist-rtl8xxxu.conf >/dev/null
  echo "  -> Registrando en DKMS y compilando contra kernel $KVER..."
  sudo dkms add -m "$PKG" -v "$VER"
  sudo dkms install -m "$PKG" -v "$VER"
  sudo depmod -a
  echo "  -> Cargando módulo..."
  sudo modprobe 8192eu
  echo "[+] Instalado y cargado. Cuando el kernel cambie, DKMS rebuild usa tu source fresco."
  lsmod | grep 8192eu
}

do_uninstall() {
  cleanup_old
  sudo depmod -a
  echo "[+] Desinstalado completamente. El wifi no cargará hasta reinstalar."
  is_loaded && echo "AVISO: sigue cargado" || echo "módulo no cargado"
}

echo ""
echo "=== rtl8192eu wifi manager ==="
echo "Source del build: $DRIVER_DIR"
echo "Kernel actual:    $KVER"
if is_installed; then echo "Estado:           INSTALADO"; else echo "Estado:           NO instalado"; fi
echo ""
echo "1) Instalar     (primera vez / forzar desde cero)"
echo "2) Actualizar   (borra lo viejo + reinstala tu build reciente)"
echo "3) Desinstalar  (limpia todo)"
echo "4) Salir"
echo ""
read -r -p "Elegí [1-4]: " opt

case "$opt" in
  1) do_install ;;
  2) do_install ;;
  3) do_uninstall ;;
  4) echo "Saliendo."; exit 0 ;;
  *) echo "Opción inválida."; exit 1 ;;
esac
