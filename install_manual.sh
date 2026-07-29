#!/bin/bash
# install_manual.sh — Fase 2: copiar .ko ya compilado + recargar módulo
#
# Para CUANDO wifi_manager.sh falla después de compilar (ej: DKMS timeout).
# NO compila. Solo copia el .ko fresco a /lib/modules, depmod, rmmod, modprobe.
#
# Uso: sudo ./install_manual.sh
#   (ejecutar desde el repo raíz, después de que make ya haya corrido)

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
KO_SRC="$REPO_DIR/driver/8192eu.ko"
KVER="$(uname -r)"
KO_DST="/lib/modules/$KVER/kernel/drivers/net/wireless/8192eu.ko"
MODPARAM_CONF="/etc/modprobe.d/8192eu.conf"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo "============================================"
echo " install_manual.sh — Fase 2 (post-compilación)"
echo " Kernel: $KVER"
echo " Source: $KO_SRC"
echo " Destino: $KO_DST"
echo "============================================"

# 1. Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] sudo ./install_manual.sh${NC}"; exit 1
fi

# 2. Verificar .ko compilado
if [ ! -f "$KO_SRC" ]; then
    echo -e "${RED}[ERROR] No existe $KO_SRC${NC}"
    echo "Primero: cd $REPO_DIR && sudo make -C driver -j\$(nproc) all"
    echo "O: ejecutar wifi_manager.sh (modo 1 o 2) hasta que compile"
    exit 1
fi
echo -e "${GREEN}[OK] .ko encontrado:${NC} $KO_SRC ($(du -h "$KO_SRC" | cut -f1))"

# 3. Descargar módulo si está cargado
if lsmod | grep -q "^8192eu "; then
    echo -e "${YELLOW}[*] Descargando módulo 8192eu...${NC}"
    rmmod 8192eu 2>/dev/null || true
    sleep 1
    if lsmod | grep -q "^8192eu "; then
        echo -e "${RED}[ERROR] No se pudo descargar 8192eu (en uso?)${NC}"
        exit 1
    fi
    echo -e "${GREEN}[OK] Módulo descargado${NC}"
else
    echo -e "${YELLOW}[OK] Módulo no estaba cargado${NC}"
fi

# 4. Eliminar .ko viejos (incluye DKMS .ko.xz comprimido que tiene prioridad)
echo -e "${YELLOW}[*] Limpiando instalaciones anteriores...${NC}"
# 4a. Eliminar de /kernel/ (estándar)
rm -f "$KO_DST"
# 4b. Eliminar de /updates/dkms/ (DKMS comprimido .ko.xz — tiene PRIORIDAD)
rm -f "/lib/modules/$KVER/updates/dkms/8192eu.ko" "/lib/modules/$KVER/updates/dkms/8192eu.ko.xz"
# 4c. Eliminar cualquier otro 8192eu.ko en /lib/modules (excepto source trees)
find /lib/modules -name '8192eu.ko*' \( -name '*.ko' -o -name '*.ko.xz' -o -name '*.ko.zst' \) \
    -not -path '*/source/*' -not -path '*/build/*' 2>/dev/null | while read f; do
    echo "  -> eliminando $f"; rm -f "$f"
done

# 5. Copiar .ko nuevo
mkdir -p "$(dirname "$KO_DST")"
cp "$KO_SRC" "$KO_DST"
chmod 644 "$KO_DST"
echo -e "${GREEN}[OK] .ko copiado a $KO_DST${NC}"

# 6. depmod
depmod -a
echo -e "${GREEN}[OK] depmod -a${NC}"

# 7. Verificar modprobe.conf
if [ -f "$MODPARAM_CONF" ]; then
    echo -e "${GREEN}[OK] Parámetros desde $MODPARAM_CONF:${NC}"
    grep '^options' "$MODPARAM_CONF"
fi

# 8. Cargar módulo
echo -e "${YELLOW}[*] Cargando 8192eu...${NC}"
modprobe 8192eu
sleep 2

# 9. Verificar
if lsmod | grep -q "^8192eu "; then
    echo -e "${GREEN}[OK] Módulo cargado:${NC}"
    lsmod | grep "^8192eu "
    # Verificar que cargó desde NUESTRO .ko, no de un remanente DKMS
    MODPATH=$(/sbin/modinfo 8192eu 2>/dev/null | grep '^filename:' | awk '{print $2}')
    echo -e "${GREEN}[OK] Path origen: ${NC}$MODPATH"
    echo -e "${GREEN}[OK] srcversion: $(cat /sys/module/8192eu/srcversion 2>/dev/null)${NC}"
    if echo "$MODPATH" | grep -q 'updates/dkms'; then
        echo -e "${RED}[ERROR] Cargó desde DKMS (updates/dkms/) — no se eliminó correctamente${NC}"
        echo -e "${RED}Ejecutá: sudo rm -f /lib/modules/$KVER/updates/dkms/8192eu* && sudo depmod -a && sudo modprobe -r 8192eu && sudo modprobe 8192eu${NC}"
    fi
else
    echo -e "${RED}[ERROR] No cargó. dmesg | tail -20${NC}"
    exit 1
fi

# 10. Verificar parámetros runtime
echo -e "${GREEN}[OK] Parámetros activos:${NC}"
for p in adaptivity_th_l2h_ini adaptivity_th_edcca_hl_diff rxgain_offset_2g notch_filter smart_ps enusbss; do
    val=$(cat /sys/module/8192eu/parameters/rtw_$p 2>/dev/null || echo "N/A")
    echo "  rtw_$p = $val"
done

# 11. Mostrar estado WiFi
echo -e "${YELLOW}[*] Esperando asociación...${NC}"
for i in $(seq 1 15); do
    if [ "$(cat /sys/class/net/wn8200nd/carrier 2>/dev/null)" = "1" ]; then
        echo -e "${GREEN}[OK] Enlace activo${NC}"
        break
    fi
    sleep 1
done
/usr/sbin/iw dev wn8200nd link 2>/dev/null
cat /proc/net/wireless 2>/dev/null
ip -4 addr show wn8200nd 2>/dev/null | grep inet

# 12. Debug interfaces
echo ""
echo -e "${YELLOW}[*] Debug interfaces:${NC}"
if ls /proc/net/rtl* 2>/dev/null; then
    echo -e "${GREEN}[OK] CONFIG_PROC_DEBUG activo${NC}"
else
    echo -e "${YELLOW}(sin /proc/net/rtl* — recompilar con CONFIG_PROC_DEBUG=y)${NC}"
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} Instalación manual completada.${NC}"
echo -e "${GREEN}============================================${NC}"
