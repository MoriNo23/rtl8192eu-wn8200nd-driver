#!/bin/sh
# diag-dual.sh — A/B CONCURRENTE entre dos adaptadores: pings simultaneos de
# 60 s a traves de las dos interfaces, mismos instantes de aire (mismo canal).
# Es la comparacion justa: elimina la varianza temporal que hizo dudosa la
# comparacion por capturas separadas.
#
# Uso:
#   sudo ./diag-dual.sh <ifaceA> <ifaceB> [gateway] [idle|load|loadup]
# Ejemplos:
#   sudo ./diag-dual.sh wn8200nd stonepi 192.168.101.1 idle
#   sudo ./diag-dual.sh wn8200nd stonepi 192.168.101.1 load
#
# Requisitos: ambas interfaces asociadas al mismo AP y con IP.
# Salida: dual-<A>-vs-<B>-<fecha>.txt

set -u

A=${1:?uso: $0 <ifaceA> <ifaceB> [gateway] [idle|load|loadup]}
B=${2:?uso: $0 <ifaceA> <ifaceB> [gateway] [idle|load|loadup]}
GW=${3:-$(ip route show default 2>/dev/null | awk '/^default/ {print $3; exit}')}
MODE=${4:-idle}
[ -n "$GW" ] || { echo "ERROR: no hay gateway y no se paso como arg 3" >&2; exit 1; }
for i in "$A" "$B"; do
    [ -d "/sys/class/net/$i" ] || { echo "ERROR: no existe la interfaz $i" >&2; exit 1; }
done
case "$MODE" in idle|load|loadup) ;; *) echo "ERROR: modo invalido (idle|load|loadup)" >&2; exit 1;; esac

OUT="dual-${A}-vs-${B}-$(date +%Y%m%d-%H%M%S).txt"
UPLOG=$(mktemp)
TA=$(mktemp); TB=$(mktemp)

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

# resumen <tmpfile>: imprime rtt cruda + P50/P95 de un log de ping
resumen() {
    F=$1
    grep -E 'packets transmitted|rtt |round-trip' "$F" || echo "(sin resumen)"
    grep -o 'time=[0-9.]*' "$F" | cut -d= -f2 | sort -g > "${F}.s"
    N=$(wc -l < "${F}.s")
    if [ "$N" -gt 0 ]; then
        P50=$(sed -n "$(( N / 2 ))p" "${F}.s")
        P95=$(sed -n "$(( N * 95 / 100 ))p" "${F}.s")
        echo "   P50=${P50} ms   P95=${P95} ms   n=${N}"
    else
        echo "   SIN RESPUESTAS"
    fi
    rm -f "${F}.s"
}

echo "== dual A/B - $(date '+%F %T') - modo: $MODE - gw $GW ==" | tee "$OUT"
echo "A = $A ($(cat "/sys/class/net/$A/address" 2>/dev/null))" | tee -a "$OUT"
echo "B = $B ($(cat "/sys/class/net/$B/address" 2>/dev/null))" | tee -a "$OUT"

# Estado previo de cada enlace
for i in "$A" "$B"; do
    echo
    echo "-- estado previo $i --" | tee -a "$OUT"
    iw dev "$i" link | sed -n '1,8p' | tee -a "$OUT"
done

echo
if [ "$MODE" != "idle" ]; then
    start_load "$MODE" | tee -a "$OUT"
    sleep 2
fi

# Pings concurrentes (mismos instantes de aire)
ping -I "$A" -i 0.2 -w 60 "$GW" > "$TA" 2>&1 &
PA=$!
ping -I "$B" -i 0.2 -w 60 "$GW" > "$TB" 2>&1 &
PB=$!
wait $PA; wait $PB

if [ "$MODE" != "idle" ] && [ -n "${LOAD_PID:-}" ]; then
    kill "$LOAD_PID" 2>/dev/null
    wait "$LOAD_PID" 2>/dev/null
fi

{
echo
echo "== resultado $A =="
resumen "$TA"
echo
echo "== resultado $B =="
resumen "$TB"
if [ "$MODE" != "idle" ] && [ -s "$UPLOG" ]; then
    echo
    awk '{s+=$1; n++} END { if (n>0) printf "carga efectiva media: %.1f Mbps (%d tandas)\n", (s/n)*8/1000000, n }' "$UPLOG"
fi
echo
echo "Regla de lectura: con P95 y perdida comparables entre A y B, el diferencial"
echo "subjetivo NO se explica en el gateway; mirar throughput de la carga y repetir"
echo "en la franja donde ocurre el episodio malo."
} | tee -a "$OUT"

echo "guardado en $OUT"
rm -f "$TA" "$TB" "$UPLOG"
