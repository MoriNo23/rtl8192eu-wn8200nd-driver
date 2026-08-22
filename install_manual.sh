#!/bin/bash
# install_manual.sh v3 — instalación/actualización del driver 8192eu
#
# Estrategia (v3, 2026-07-30):
#   1. Si dkms está instalado  → asegura el registro rtl8192eu/1.6 (sync source
#      parcheado a /usr/src + dkms add si falta) y usa `dkms build + install --force`
#      como vía principal (el .ko.xz de updates/dkms tiene prioridad).
#   2. Si dkms NO está instalado → vía manual: copia el .ko compilado a /lib/modules,
#      elimina .ko.xz/.ko.zst de updates/dkms (que pisarían al manual).
#   3. SIEMPRE al final: reinicia NetworkManager (systemctl restart NetworkManager)
#      porque tras recargar el módulo NM no reconecta solo.
#
# Uso: sudo ./install_manual.sh   (desde el repo raíz; make ya debe haber corrido)

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
KO_SRC="$REPO_DIR/driver/8192eu.ko"
KVER="$(uname -r)"
KO_DST="/lib/modules/$KVER/kernel/drivers/net/wireless/8192eu.ko"
PKG="rtl8192eu"
VER="1.6.3"
USRSRC="/usr/src/$PKG-$VER"
MODPARAM_CONF="/etc/modprobe.d/8192eu.conf"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo "============================================"
echo " install_manual.sh v3 — instalación 8192eu"
echo " Kernel: $KVER | DKMS: $PKG/$VER"
echo "============================================"

# 1. Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] sudo ./install_manual.sh${NC}"; exit 1
fi

# 2. Verificar .ko compilado (solo necesario para el fallback manual)
if [ ! -f "$KO_SRC" ]; then
    echo -e "${RED}[ERROR] No existe $KO_SRC${NC}"
    echo "Primero: cd $REPO_DIR && sudo make -C driver -j\$(nproc) all"
    exit 1
fi
echo -e "${GREEN}[OK] .ko encontrado:${NC} $KO_SRC ($(du -h "$KO_SRC" | cut -f1))"

# 3. Vía DKMS si está disponible
if command -v dkms > /dev/null 2>&1; then
    echo -e "${YELLOW}[*] dkms detectado — vía DKMS${NC}"

    # 3a. Sincronizar source parcheado (nunca una copia olvidada)
    echo -e "${YELLOW}[*] Sincronizando source parcheado a $USRSRC...${NC}"
    mkdir -p "$USRSRC"
    rsync -a --delete \
        --exclude '.git' --exclude '*.o' --exclude '*.ko' --exclude '*.cmd' \
        --exclude '*.mod' --exclude '*.mod.c' --exclude '.tmp_versions' \
        --exclude 'Module.symvers' --exclude 'modules.order' \
        "$REPO_DIR/" "$USRSRC/"

    # 3b. Registrar si falta
    if ! dkms status 2>/dev/null | grep -q "$PKG/$VER"; then
        echo -e "${YELLOW}[*] $PKG/$VER no registrado — dkms add...${NC}"
        dkms add -m "$PKG" -v "$VER"
    else
        echo -e "${GREEN}[OK] $PKG/$VER ya registrado${NC}"
    fi

    # 3c. Build + install (compila desde el source parcheado)
    echo -e "${YELLOW}[*] dkms build (puede tardar 2-3 min)...${NC}"
    dkms build -m "$PKG" -v "$VER"
    echo -e "${YELLOW}[*] dkms install --force...${NC}"
    dkms install -m "$PKG" -v "$VER" --force
    depmod -a
    echo -e "${GREEN}[OK] Módulo instalado via DKMS (updates/dkms/8192eu.ko.xz)${NC}"
else
    echo -e "${YELLOW}[*] dkms NO instalado — vía manual (anti-DKMS)${NC}"

    # 3'. Descargar módulo si está cargado (verificado, no silencioso)
    if lsmod | grep -q "^8192eu "; then
        echo -e "${YELLOW}[*] Descargando módulo 8192eu...${NC}"
        rmmod 8192eu 2>/dev/null || true
        sleep 1
        if lsmod | grep -q "^8192eu "; then
            echo -e "${RED}[ERROR] No se pudo descargar 8192eu (en uso?)${NC}"
            exit 1
        fi
        echo -e "${GREEN}[OK] Módulo descargado${NC}"
    fi

    # Eliminar .ko viejos (incluye DKMS .ko.xz comprimido que tiene prioridad)
    echo -e "${YELLOW}[*] Limpiando instalaciones anteriores...${NC}"
    rm -f "$KO_DST"
    rm -f "/lib/modules/$KVER/updates/dkms/8192eu.ko" "/lib/modules/$KVER/updates/dkms/8192eu.ko.xz"
    find /lib/modules -name '8192eu.ko*' \( -name '*.ko' -o -name '*.ko.xz' -o -name '*.ko.zst' \) \
        -not -path '*/source/*' -not -path '*/build/*' 2>/dev/null | while read f; do
        echo "  -> eliminando $f"; rm -f "$f"
    done

    # Copiar .ko nuevo
    mkdir -p "$(dirname "$KO_DST")"
    cp "$KO_SRC" "$KO_DST"
    chmod 644 "$KO_DST"
    depmod -a
    echo -e "${GREEN}[OK] .ko copiado a $KO_DST${NC}"
fi

# 4. Recargar módulo (desde cualquiera de las dos vías)
echo -e "${YELLOW}[*] Cargando 8192eu...${NC}"
modprobe 8192eu
sleep 2

# 5. Verificar carga
if lsmod | grep -q "^8192eu "; then
    MODPATH=$(/sbin/modinfo 8192eu 2>/dev/null | grep '^filename:' | awk '{print $2}')
    echo -e "${GREEN}[OK] Módulo cargado:${NC} $MODPATH"
    echo -e "${GREEN}[OK] srcversion: $(cat /sys/module/8192eu/srcversion 2>/dev/null)${NC}"
    echo -e "${GREEN}[OK] rtw_trx_path_bmp: $(cat /sys/module/8192eu/parameters/rtw_trx_path_bmp 2>/dev/null) (17=1T1R antena A, 51=2x2)${NC}"
else
    echo -e "${RED}[ERROR] No cargó. dmesg | tail -20${NC}"
    exit 1
fi

# 6. Reiniciar NetworkManager (NO reconecta solo tras recarga del módulo)
echo -e "${YELLOW}[*] Reiniciando NetworkManager...${NC}"
systemctl restart NetworkManager
sleep 6

# 7. Esperar asociación e IP
echo -e "${YELLOW}[*] Esperando asociación e IP...${NC}"
IP=""
for i in $(seq 1 15); do
    IP=$(ip -4 -o addr show wn8200nd 2>/dev/null | awk '{print $4}')
    [ -n "$IP" ] && break
    sleep 2
done
ip -4 addr show wn8200nd 2>/dev/null | grep inet || echo -e "${RED}[!] Sin IP aún — revisar nmcli device connect wn8200nd${NC}"

# 8. Verificar parámetros runtime
echo -e "${GREEN}[OK] Parámetros activos:${NC}"
for p in trx_path_bmp adaptivity_th_l2h_ini adaptivity_th_edcca_hl_diff rxgain_offset_2g notch_filter smart_ps; do
    echo "  rtw_$p = $(cat /sys/module/8192eu/parameters/rtw_$p 2>/dev/null || echo N/A)"
done

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} Instalación completada.${NC}"
echo -e "${GREEN} Si no hay internet: nmcli device connect wn8200nd${NC}"
echo -e "${GREEN}============================================${NC}"
