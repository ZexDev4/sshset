#!/bin/bash
# ============================================
# stop-project-tunnel.sh
# Matikan tunnel cloudflared KHUSUS untuk port tertentu
# (aman, tidak menyentuh tunnel SSH atau tunnel user lain)
#
# Cara pakai:
#   ./stop-project-tunnel.sh <port>
# Contoh:
#   ./stop-project-tunnel.sh 8080
# ============================================

PORT="$1"

if [ -z "$PORT" ]; then
    echo "Cara pakai: ./stop-project-tunnel.sh <port>"
    exit 1
fi

PID_FILE="/tmp/cf-tunnel-$PORT.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        echo "Tunnel untuk port $PORT (PID $PID) sudah dimatikan."
    else
        echo "PID $PID sudah tidak aktif sebelumnya."
    fi
    rm -f "$PID_FILE"
else
    echo "Tidak ada file PID untuk port $PORT. Tidak ada yang dimatikan."
fi
