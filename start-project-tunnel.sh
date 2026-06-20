#!/bin/bash
# ============================================
# start-project-tunnel.sh
# Jalankan di server, untuk expose project SENDIRI
# (Flask, Node.js, dll) lewat Cloudflare Tunnel
# tanpa mengganggu tunnel SSH atau tunnel user lain.
#
# Cara pakai:
#   ./start-project-tunnel.sh <port> [http|tcp]
# Contoh:
#   ./start-project-tunnel.sh 8080          # default: http
#   ./start-project-tunnel.sh 8080 tcp       # mode tcp (raw)
# ============================================

PORT="$1"
MODE="${2:-http}"

if [ -z "$PORT" ]; then
    echo "Cara pakai: ./start-project-tunnel.sh <port> [http|tcp]"
    echo "Contoh    : ./start-project-tunnel.sh 8080"
    exit 1
fi

if [ "$PORT" = "22" ]; then
    echo "Port 22 sudah dipakai tunnel SSH server. Pakai port lain untuk project kamu."
    exit 1
fi

PID_FILE="/tmp/cf-tunnel-$PORT.pid"
LOG_FILE="/tmp/cf-tunnel-$PORT.log"

echo "=== Cek proses & port $PORT ==="
(echo > "/dev/tcp/localhost/$PORT") 2>/dev/null \
    && echo "Port $PORT terdeteksi listening, lanjut." \
    || echo "Peringatan: port $PORT belum kelihatan listening. Pastikan project kamu sudah jalan."

echo ""
echo "=== Cek & matikan tunnel LAMA untuk port $PORT saja (PID-specific) ==="
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Tunnel lama untuk port $PORT (PID $OLD_PID) masih jalan, mematikan..."
        kill "$OLD_PID"
        sleep 1
    fi
    rm -f "$PID_FILE"
else
    echo "Tidak ada tunnel lama untuk port $PORT."
fi

echo ""
echo "=== Membuka tunnel baru untuk port $PORT (mode: $MODE) ==="
rm -f "$LOG_FILE"
nohup cloudflared tunnel --url "$MODE://localhost:$PORT" > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
disown

echo "Menunggu hostname tunnel..."
for i in $(seq 1 15); do
    sleep 1
    URL=$(grep -o 'https://[a-zA-Z0-9.-]*trycloudflare\.com' "$LOG_FILE" | head -n1)
    if [ -n "$URL" ]; then
        break
    fi
done

echo ""
echo "=== HASIL ==="
if [ -n "$URL" ]; then
    echo "Tunnel URL : $URL"
    echo "PID        : $(cat "$PID_FILE")"
    echo ""
    echo ">> Untuk matikan tunnel ini nanti, jalankan:"
    echo "   ./stop-project-tunnel.sh $PORT"
else
    echo "Gagal mendapatkan URL. Cek log: $LOG_FILE"
    tail -n 20 "$LOG_FILE"
fi
