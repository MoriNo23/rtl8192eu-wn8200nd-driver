#!/usr/bin/env bash
# rx_drop_watchdog.sh — monitoreo pasivo de rx_dropped para 8192eu driver
#
# Uso: ./rx_drop_watchdog.sh
# Se espera como cron cada 30min o invocación manual.
#
# Lee rx_dropped y rx_packets de sysfs, compara con último estado conocido,
# filtra falsos positivos (interfaz caída, reseteo de contadores, etc.),
# y escribe una línea CSV por ejecucion en archivo con fecha-hora.
#
# Archivos de log: monitoring/rx_drop_monitor_YYYY-MM-DD_HHMMSS.csv
#
# False positives que filtra:
#   - Interfaz DOWN o sin carrier → skip, marca "carrier_down"
#   - rx_packets reseteado (menor que último valor) → modulo recargado / reboot router
#   - Sin gateway default → skip, marca "no_gateway"
#   - Primer arranque (no hay estado previo) → inicializa sin alerta

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MONITOR_DIR="$REPO_DIR/monitoring"
STATE_FILE="$MONITOR_DIR/.rx_state"

NOW_EPOCH=$(date +%s)
NOW_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')
NOW_FILE=$(date '+%Y-%m-%d_%H%M%S')
LOG_FILE="$MONITOR_DIR/rx_drop_monitor_${NOW_FILE}.csv"

INTERFACE="wn8200nd"
SYSFS_DROPPED="/sys/class/net/${INTERFACE}/statistics/rx_dropped"
SYSFS_PACKETS="/sys/class/net/${INTERFACE}/statistics/rx_packets"
SYSFS_CARRIER="/sys/class/net/${INTERFACE}/carrier"
PROC_ADAPTIVITY="/proc/net/rtl8192eu/${INTERFACE}/odm/adaptivity"
PROC_SIGNAL="/proc/net/rtl8192eu/${INTERFACE}/rx_signal"

# Formato CSV fijo (mismo para todos los estados):
# timestamp,epoch,status,rx_dropped,delta_dropped,rx_packets,delta_packets,rssi,signal_qual,gateway
write_log() {
    local STATUS="$1"
    local RX_DROP="$2"
    local DROP_DELTA="$3"
    local RX_PKT="$4"
    local PKT_DELTA="$5"
    local RSSI_VAL="$6"
    local QUAL_VAL="$7"
    local GW="$8"
    echo "${NOW_HUMAN},${NOW_EPOCH},${STATUS},${RX_DROP},${DROP_DELTA},${RX_PKT},${PKT_DELTA},${RSSI_VAL},${QUAL_VAL},${GW}" > "$LOG_FILE"

    # Notificar por stdout solo si hay problema real
    if [ "$DROP_DELTA" -gt 0 ]; then
        echo "[rx_drop_watchdog] ${NOW_HUMAN} — ALERTA: ${DROP_DELTA} drops nuevos (total: ${RX_DROP}), paquetes: ${RX_PKT}, RSSI: ${RSSI_VAL}"
    elif [ "$STATUS" = "RESET_counter" ]; then
        echo "[rx_drop_watchdog] ${NOW_HUMAN} — INFO: contadores reseteados (modulo recargado/reboot)"
    fi
}

# ── Sanity checks ──────────────────────────────────────────────

# 1. Existen los sysfs?
if [ ! -f "$SYSFS_DROPPED" ] || [ ! -f "$SYSFS_PACKETS" ]; then
    write_log "ERROR_no_sysfs" "-" "-" "-" "-" "-" "-" "-"
    exit 1
fi

# 2. Interfaz tiene carrier (link)?
CARRIER=$(cat "$SYSFS_CARRIER" 2>/dev/null || echo 0)
if [ "$CARRIER" != "1" ]; then
    write_log "SKIP_carrier_down" "-" "-" "-" "-" "-" "-" "-"
    exit 0
fi

# 3. Tiene IP valida?
IP=$(ip -4 addr show "$INTERFACE" 2>/dev/null | awk '/inet / {print $2}' | head -1)
if [ -z "$IP" ]; then
    write_log "SKIP_no_ip" "-" "-" "-" "-" "-" "-" "-"
    exit 0
fi

# 4. Tiene gateway?
GATEWAY=$(ip route show default 2>/dev/null | awk '{print $3}')
if [ -z "$GATEWAY" ]; then
    write_log "SKIP_no_gateway" "-" "-" "-" "-" "-" "-" "-"
    exit 0
fi

# ── Leer contadores actuales ──────────────────────────────────

RX_DROPPED_CUR=$(cat "$SYSFS_DROPPED")
RX_PACKETS_CUR=$(cat "$SYSFS_PACKETS")

# Senyal / adaptivity (si existe)
RSSI_VAL="-"
SIGNAL_QUAL_VAL="-"
if [ -f "$PROC_SIGNAL" ]; then
    RSSI=$(grep -oP 'rssi:-\d+' "$PROC_SIGNAL" 2>/dev/null | head -1 || echo "")
    [ -n "$RSSI" ] && RSSI_VAL="$RSSI"
    QUAL=$(grep -oP 'signal_qual:\d+' "$PROC_SIGNAL" 2>/dev/null | head -1 || echo "")
    [ -n "$QUAL" ] && SIGNAL_QUAL_VAL="$QUAL"
fi

# ── Cargar estado anterior ────────────────────────────────────

if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
else
    # Primera ejecucion: inicializar sin alerta
    echo "RX_DROPPED_PREV=$RX_DROPPED_CUR" > "$STATE_FILE"
    echo "RX_PACKETS_PREV=$RX_PACKETS_CUR" >> "$STATE_FILE"
    write_log "INIT" "$RX_DROPPED_CUR" "0" "$RX_PACKETS_CUR" "0" "$RSSI_VAL" "$SIGNAL_QUAL_VAL" "$GATEWAY"
    exit 0
fi

# ── Detectar falsos positivos ─────────────────────────────────

STATUS="OK"

# Reset de contadores? (modulo recargado o reboot)
if [ "$RX_PACKETS_CUR" -lt "$RX_PACKETS_PREV" ]; then
    STATUS="RESET_counter"
fi

# Delta de dropped
DROP_DELTA=$(( RX_DROPPED_CUR - RX_DROPPED_PREV ))
PACKET_DELTA=$(( RX_PACKETS_CUR - RX_PACKETS_PREV ))

# ── Actualizar estado ─────────────────────────────────────────

echo "RX_DROPPED_PREV=$RX_DROPPED_CUR" > "$STATE_FILE"
echo "RX_PACKETS_PREV=$RX_PACKETS_CUR" >> "$STATE_FILE"

# ── Loggear ────────────────────────────────────────────────────

write_log "$STATUS" "$RX_DROPPED_CUR" "$DROP_DELTA" "$RX_PACKETS_CUR" "$PACKET_DELTA" "$RSSI_VAL" "$SIGNAL_QUAL_VAL" "$GATEWAY"
