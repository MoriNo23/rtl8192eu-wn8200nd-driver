#!/usr/bin/env bash
# rx_drop_watchdog.sh — monitoreo pasivo de rx_dropped para 8192eu driver
#
# Uso: ./rx_drop_watchdog.sh
# Se espera como cron cada 30min o invocación manual.
#
# Lee rx_dropped y rx_packets de sysfs, compara con último estado conocido,
# filtra falsos positivos (interfaz caída, reseteo de contadores, etc.),
# y escribe una línea CSV al log.
#
# False positives que filtra:
#   - Interfaz DOWN o sin IP → skip, marca "interface_down"
#   - rx_packets reseteado (menor que último valor) → módulo recargado / reboot router
#   - Sin gateway default → skip, marca "no_route"
#   - Primer arranque (no hay estado previo) → inicializa sin alerta

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MONITOR_DIR="$REPO_DIR/monitoring"
LOG_FILE="$MONITOR_DIR/rx_drop_monitor.log"
STATE_FILE="$MONITOR_DIR/.rx_state"

INTERFACE="wn8200nd"
SYSFS_DROPPED="/sys/class/net/${INTERFACE}/statistics/rx_dropped"
SYSFS_PACKETS="/sys/class/net/${INTERFACE}/statistics/rx_packets"
SYSFS_CARRIER="/sys/class/net/${INTERFACE}/carrier"
PROC_ADAPTIVITY="/proc/net/rtl8192eu/${INTERFACE}/odm/adaptivity"
PROC_SIGNAL="/proc/net/rtl8192eu/${INTERFACE}/rx_signal"

NOW_EPOCH=$(date +%s)
NOW_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')

# ── Sanity checks ──────────────────────────────────────────────

# 1. Existen los sysfs?
if [ ! -f "$SYSFS_DROPPED" ] || [ ! -f "$SYSFS_PACKETS" ]; then
    echo "$NOW_HUMAN,$NOW_EPOCH,ERROR,no_sysfs" >> "$LOG_FILE"
    exit 1
fi

# 2. Interfaz tiene carrier (link)?
CARRIER=$(cat "$SYSFS_CARRIER" 2>/dev/null || echo 0)
if [ "$CARRIER" != "1" ]; then
    echo "$NOW_HUMAN,$NOW_EPOCH,SKIP,carrier_down" >> "$LOG_FILE"
    exit 0
fi

# 3. Tiene IP válida?
IP=$(ip -4 addr show "$INTERFACE" 2>/dev/null | awk '/inet / {print $2}' | head -1)
if [ -z "$IP" ]; then
    echo "$NOW_HUMAN,$NOW_EPOCH,SKIP,no_ip" >> "$LOG_FILE"
    exit 0
fi

# 4. Tiene gateway?
GATEWAY=$(ip route show default 2>/dev/null | awk '{print $3}')
if [ -z "$GATEWAY" ]; then
    echo "$NOW_HUMAN,$NOW_EPOCH,SKIP,no_gateway" >> "$LOG_FILE"
    exit 0
fi

# ── Leer contadores actuales ──────────────────────────────────

RX_DROPPED_CUR=$(cat "$SYSFS_DROPPED")
RX_PACKETS_CUR=$(cat "$SYSFS_PACKETS")

# Señal / adaptivity (si existe)
RSSI="?"
SIGNAL_QUAL="?"
if [ -f "$PROC_SIGNAL" ]; then
    RSSI=$(grep -oP 'rssi:-\d+' "$PROC_SIGNAL" 2>/dev/null | head -1 || echo "?")
    SIGNAL_QUAL=$(grep -oP 'signal_qual:\d+' "$PROC_SIGNAL" 2>/dev/null | head -1 || echo "?")
fi

# ── Cargar estado anterior ────────────────────────────────────

if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
else
    # Primera ejecución: inicializar sin alerta
    echo "RX_DROPPED_PREV=$RX_DROPPED_CUR" > "$STATE_FILE"
    echo "RX_PACKETS_PREV=$RX_PACKETS_CUR" >> "$STATE_FILE"
    echo "$NOW_HUMAN,$NOW_EPOCH,INIT,dropped=$RX_DROPPED_CUR,rx=$RX_PACKETS_CUR,$RSSI,$SIGNAL_QUAL" >> "$LOG_FILE"
    exit 0
fi

# ── Detectar falsos positivos ─────────────────────────────────

STATUS="OK"

# Reset de contadores? (módulo recargado o reboot)
if [ "$RX_PACKETS_CUR" -lt "$RX_PACKETS_PREV" ]; then
    # Contador de paquetes se reseteó → módulo recargado / reboot
    STATUS="RESET_counter"
fi

# Delta de dropped
DROP_DELTA=$(( RX_DROPPED_CUR - RX_DROPPED_PREV ))
PACKET_DELTA=$(( RX_PACKETS_CUR - RX_PACKETS_PREV ))

# ── Actualizar estado ─────────────────────────────────────────

echo "RX_DROPPED_PREV=$RX_DROPPED_CUR" > "$STATE_FILE"
echo "RX_PACKETS_PREV=$RX_PACKETS_CUR" >> "$STATE_FILE"

# ── Loggear ────────────────────────────────────────────────────

# Formato CSV:
# timestamp,epoch,status,rx_dropped,delta_dropped,rx_packets,delta_packets,rssi,signal_qual,gateway
echo "$NOW_HUMAN,$NOW_EPOCH,$STATUS,$RX_DROPPED_CUR,$DROP_DELTA,$RX_PACKETS_CUR,$PACKET_DELTA,$RSSI,$SIGNAL_QUAL,$GATEWAY" >> "$LOG_FILE"

# ── Notificar solo si hay problemas ───────────────────────────

if [ "$DROP_DELTA" -gt 0 ]; then
    echo "[rx_drop_watchdog] $NOW_HUMAN — ALERTA: $DROP_DELTA drops nuevos (total: $RX_DROPPED_CUR), paquetes: $RX_PACKETS_CUR, RSSI: $RSSI"
elif [ "$STATUS" = "RESET_counter" ]; then
    echo "[rx_drop_watchdog] $NOW_HUMAN — INFO: contadores reseteados (modulo recargado/reboot)"
fi

# En SKIP/ERROR no se notifica — son esperables (interfaz caida, sin gateway)
