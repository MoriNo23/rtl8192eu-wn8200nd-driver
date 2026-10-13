#!/bin/sh
# diag-daytime.sh v3 — diagnostico por adaptador (solo lectura + carga opcional).
#
# v3: el modo de carga PRUEBA si de verdad hay server iperf3 en el gateway
#     (v2 lo asumia y si no habia, media "reposo" sin decirlo); si no hay,
#     usa curl contra speed.cloudflare.com. Modos: idle | load (bajada) |
#     loadup (subida). Reporta Mbps de la carga. Todo ASCII para no depender
#     del locale del equipo.
#
# Uso:
#   sudo ./diag-daytime.sh <iface> [gateway] [idle|load|loadup]
# Ejemplos:
#   sudo ./diag-daytime.sh wn8200nd 192.168.101.1 idle
#   sudo ./diag-daytime.sh wn8200nd 192.168.101.1 load
#
# Para comparar DOS adaptadores en los mismos instantes de aire usa
# diag-dual.sh (mismo directorio): es el A/B justo.

set -u

IFACE=${1:?uso: $0 <iface> [gateway] [idle|load|loadup]}
GW=${2:-$(ip route show default 2>/dev/null | awk '/^default/ {print $3; exit}')}
MODE=${3:-idle}
[ -n "$GW" ] || { echo "ERROR: no hay gateway y no se paso como arg 2" >&2; exit 1; }
[ -d "/sys/class/net/$IFACE" ] || { echo "ERROR: no existe la interfaz $IFACE" >&2; exit 1; }
case "$MODE" in idle|load|loadup) ;; *) echo "ERROR: modo '$MODE' invalido (idle|load|loadup)" >&2; exit 1;; esac

OUT="diag-${IFACE}-$(date +%Y%m%d-%H%M%S).txt"
exec > "$OUT" 2>&1

echo "== diag $IFACE - $(date '+%F %T') - modo: $MODE =="
DRIVER=$(basename "$(readlink -f "/sys/class/net/$IFACE/device/driver" 2>/dev/null)" 2>/dev/null)
echo "driver: ${DRIVER:-desconocido}   gateway: $GW"

echo
echo "-- parametros efectivos del modulo 8192eu (sysfs) --"
if [ -d /sys/module/8192eu/parameters ]; then
    for f in /sys/module/8192eu/parameters/*; do
        printf '%s = %s\n' "$(basename "$f")" "$(cat "$f" 2>/dev/null)"
    done
fi

echo
echo "-- iw dev $IFACE info (canal/ancho/txpower) --"
iw dev "$IFACE" info

echo
echo "-- power_save --"
iw dev "$IFACE" get power_save 2>/dev/null || echo "(no disponible)"

echo
echo "-- survey dump (ocupacion REAL del canal) --"
# Drivers Realtek suelen devolver esto vacio: el busy% de referencia del canal
# se toma con la otra interfaz (ath9k si lo implementa).
iw dev "$IFACE" survey dump 2>&1

echo
echo "-- iw link --"
iw dev "$IFACE" link

echo
echo "-- station dump (signal/rates/retries/failed) --"
iw dev "$IFACE" station dump

echo
echo "-- reg dominio --"
iw reg get 2>/dev/null | head -n 6

echo
echo "-- ocupacion: APs por frecuencia 2.4G --"
iw dev "$IFACE" scan 2>/dev/null | grep -o 'freq: [0-9.]*' \
    | awk '{print $2}' | sort -n | uniq -c \
    | awk '{printf "freq %s MHz: %d AP(s)\n", $2, $1}'

# --------------------------------------------------------------- carga ----
UPLOG=$(mktemp)
# start_load <load|loadup>: lanza la carga en segundo plano (LOAD_PID).
# Devuelve true si la carga es "de verdad" (iperf3 server o curl ok).
start_load() {
    NEED=$1
    if command -v iperf3 >/dev/null 2>&1 && timeout 4 iperf3 -c "$GW" -t 1 >/dev/null 2>&1; then
        echo "(carga: iperf3 reverse 55s contra server en $GW)"
        iperf3 -c "$GW" -t 55 -R >/dev/null 2>&1 &
        LOAD_PID=$!
        return 0
    fi
    if [ "$NEED" = "load" ]; then
        echo "(carga: descarga en bucle desde speed.cloudflare.com)"
        ( while :; do
              curl -sS -o /dev/null --max-time 20 -w '%{speed_download}\n' \
                  "https://speed.cloudflare.com/__down?bytes=50000000" \
                  >> "$UPLOG" 2>/dev/null || sleep 1
          done ) &
        LOAD_PID=$!
        return 0
    fi
    if [ "$NEED" = "loadup" ]; then
        TMPUP=$(mktemp)
        dd if=/dev/urandom of="$TMPUP" bs=1M count=30 2>/dev/null
        echo "(carga: subida en bucle de 30MB a speed.cloudflare.com/__up)"
        ( while :; do
              curl -sS -o /dev/null --max-time 20 -w '%{speed_upload}\n' \
                  --data-binary @"$TMPUP" "https://speed.cloudflare.com/__up" \
                  >> "$UPLOG" 2>/dev/null || sleep 1
          done; rm -f "$TMPUP" ) &
        LOAD_PID=$!
        return 0
    fi
    return 1
}

report_load_speed() {
    if [ -s "$UPLOG" ]; then
        awk '{s+=$1; n++} END { if (n>0) printf "carga efectiva media: %.1f Mbps (%d tandas)\n", (s/n)*8/1000000, n; else print "carga: sin datos de velocidad" }' "$UPLOG"
    else
        echo "carga: SIN DATOS (¿sin salida a internet?)"
    fi
}

# ---------------------------------------------------------------- ping ----
echo
echo "-- ping $GW x60s (itv=0.2, modo: $MODE) --"

if [ "$MODE" != "idle" ]; then
    start_load "$MODE"
    sleep 2
fi

PING_TMP=$(mktemp)
ping -i 0.2 -w 60 "$GW" > "$PING_TMP" 2>&1

if [ "$MODE" != "idle" ] && [ -n "${LOAD_PID:-}" ]; then
    kill "$LOAD_PID" 2>/dev/null
    wait "$LOAD_PID" 2>/dev/null
fi

grep -E 'packets transmitted|rtt |round-trip' "$PING_TMP" || true
grep -o 'time=[0-9.]*' "$PING_TMP" | cut -d= -f2 | sort -g > "${PING_TMP}.s"
N=$(wc -l < "${PING_TMP}.s")
if [ "$N" -gt 0 ]; then
    P50=$(sed -n "$(( N / 2 ))p" "${PING_TMP}.s")
    P95=$(sed -n "$(( N * 95 / 100 ))p" "${PING_TMP}.s")
    echo "P50=${P50} ms   P95=${P95} ms   n=${N}"
else
    echo "SIN RESPUESTAS del ping (¿enlace caido durante la medicion?)"
fi
[ "$MODE" != "idle" ] && report_load_speed
rm -f "$PING_TMP" "${PING_TMP}.s" "$UPLOG"

# --------------------------------------------------------------- dmesg ----
echo
echo "-- dmesg USB/driver/deauth ultimos 60 (con timestamps) --"
dmesg -T 2>/dev/null | grep -Ei 'usb|rtl8192|8192eu|deauth|disassoc' | tail -n 60

echo
echo "-- usb arbol (velocidad del adaptador) --"
lsusb -t 2>/dev/null

echo
echo "== fin diag $IFACE =="
