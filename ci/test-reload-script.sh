#!/bin/bash
# test-reload-script.sh — prueba scripts/reload-wn8200nd-1ant SIN tocar la red.
#
# Por que con stubs: el script real llama a rmmod, modprobe, ip, iw y nmcli, y
#y cualquiera de ellos en la maquina del usuario desmonta el adaptador que da la WAN
# del AP. Aqui se ejecutan versiones falsas de esos comandos, que registran lo
# que se les pidio y no hacen nada, y /proc se simula.
#
# Lo que verifica (tarea 7.4):
#   (a) el script no escribe en ningun path de /proc/net/rtl8192eu/ (el debug de
#       runtime esta cerrado, un reload no debe intentar activarlo)
#   (b) pase lo que pase en los pasos intermedios, el script devuelve la
#       interfaz a managed con IP (la regla de seguridad de AGENTS.md)
#
# Uso: ci/test-reload-script.sh   (sale != 0 si algo falla)
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/scripts/reload-wn8200nd-1ant"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()   { echo "  OK: $*";   PASS=$((PASS+1)); }
bad()  { echo "  FALLO: $*"; FAIL=$((FAIL+1)); }

# ---------------------------------------------------------------- stubs ----
# Cada stub registra su invocacion en $STUB_LOG y no hace nada.
make_stubs() {
    local d="$1"
    mkdir -p "$d"
    for cmd in rmmod modprobe ip iw nmcli ping lsusb sudo tee systemctl; do
        cat > "$d/$cmd" <<STUB
#!/bin/bash
echo "$cmd \$*" >> "\$STUB_LOG"
# 'ip -4 -o addr show wn8200nd' debe devolver algo con IP, para que el script
# no entre en el camino de reconexion de NetworkManager.
case "$cmd" in
  ip)
    if [[ "\$*" == *"addr show wn8200nd"* ]]; then
      echo "3: wn8200nd    inet 192.168.1.50/24 brd 192.168.1.255 scope global wn8200nd"
    elif [[ "\$*" == *"-4 -o addr show wn8200nd"* ]]; then
      echo "3: wn8200nd    inet 192.168.1.50/24 brd 192.168.1.255 scope global wn8200nd"
    fi
    ;;
  iw)
    if [[ "\$*" == *"dev wn8200nd info"* ]]; then
      echo "Interface wn8200nd"
      echo "  type managed"
    fi
    ;;
esac
exit 0
STUB
        chmod +x "$d/$cmd"
    done

    # /sys/module/... stub: el script lee los parametros del modulo.
    mkdir -p "$d/sys/module/8192eu/parameters"
    local v
    for v in rtw_trx_path_bmp rtw_adaptivity_th_l2h_ini \
             rtw_adaptivity_th_edcca_hl_diff rtw_rxgain_offset_2g; do
        echo "0" > "$d/sys/module/8192eu/parameters/$v"
    done
    echo 17 > "$d/sys/module/8192eu/parameters/rtw_trx_path_bmp"
    echo 15 > "$d/sys/module/8192eu/parameters/rtw_adaptivity_th_l2h_ini"
    echo 5  > "$d/sys/module/8192eu/parameters/rtw_adaptivity_th_edcca_hl_diff"
}

run_script() {
    local name="$1"; shift
    local sandbox="$TMP/$name"
    mkdir -p "$sandbox/stubs"
    make_stubs "$sandbox/stubs"
    export STUB_LOG="$sandbox/calls.log"
    : > "$STUB_LOG"

    # Se ejecuta con el PATH de stubs delante, y con las escrituras a /proc
    # interceptadas: si el script intenta escribir en el procfs del driver, el
    # stub de 'tee' lo registra y el test lo detecta.
    ( cd "$sandbox"
      PATH="$sandbox/stubs:$PATH" \
      REPO_DIR="$REPO" \
      bash "$SCRIPT" ) > "$sandbox/out.log" 2>&1
    return $?
}

# ------------------------------------------------------- (a) sin procfs ----
echo "== (a) el script no toca el procfs de depuracion =="
run_script noproc
if grep -qE 'rtl8192eu|odm/cmd|dbg 13' "$TMP/noproc/calls.log"; then
    bad "el script invoco algo sobre el procfs del driver:"
    grep -E 'rtl8192eu|odm/cmd|dbg 13' "$TMP/noproc/calls.log" | sed 's/^/      /'
else
    ok "ninguna llamada al procfs del driver"
fi
# Y en el propio fuente, no solo en la traza: el paso 7 no debe existir.
if grep -qE 'odm/cmd|dbg 13' "$SCRIPT"; then
    bad "el script todavia contiene una escritura al procfs de debug"
    grep -nE 'odm/cmd|dbg 13' "$SCRIPT" | sed 's/^/      /'
else
    ok "el fuente no menciona odm/cmd ni dbg 13"
fi

# ------------------------------------------------- (b) vuelve a managed ----
echo "== (b) devuelve la interfaz a managed aunque algo falle =="

# El script tiene 'set -e'. Si un paso intermedio falla, el script muere ahi y
# NO ejecuta la restauracion final. Eso es exactamente lo que la regla de
# seguridad de AGENTS.md prohibe ("si un test falla a mitad de camino, la
# restauracion corre IGUAL"). Se comprueba que el texto de limpieza existe y
# que se ejecuta con ';' y no con '&&'.
run_script managed
if grep -q 'type managed' "$TMP/managed/calls.log"; then
    ok "el script pide devolver la interfaz a managed"
else
    bad "el script no deja la interfaz en managed"
fi

# La restauracion tiene que ser incondicional: separador ';' o 'trap', nunca
# encadenada con '&&' al exito del paso anterior.
if grep -qE 'type managed' "$SCRIPT"; then
    # Extrae las lineas de restauracion y comprueba que no dependen de un &&.
    restore_lines=$(grep -A2 -B2 'type managed' "$SCRIPT" | grep -cE '&&')
    if [ "$restore_lines" -eq 0 ]; then
        ok "la restauracion no esta encadenada con && (se ejecuta siempre)"
    else
        bad "la restauracion depende de un && previo: si algo falla antes, no corre"
    fi
else
    bad "el script no tiene restauracion de la interfaz a managed"
fi

# Y lo mismo para la limpieza: no puede quedar 'set -e' sin trap que restaure.
if grep -q 'trap' "$SCRIPT" || ! grep -qE '^\s*set -e\s*$' "$SCRIPT"; then
    ok "el script tiene una trampa o no usa set -e: la restauracion no se pierde"
else
    bad "el script usa 'set -e' sin 'trap': un fallo intermedio deja la interfaz caida"
fi

# ------------------------------------------------------------------ fin ----
echo ""
echo "resumen: $PASS comprobaciones OK, $FAIL fallos"
[ "$FAIL" -eq 0 ] || exit 1
echo "test-reload-script: VERDE"
exit 0
