#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# start-termux.sh
# Jalankan di Termux
# Fungsi: connect ke cloudflared tunnel + SSH otomatis
#
# Cara pakai:
#   ./start-termux.sh <hostname-tunnel>
# Contoh:
#   ./start-termux.sh recall-governing-palestinian-guide.trycloudflare.com
#
# Atau tanpa argumen, akan ditanya manual.
# ============================================

LOCAL_PORT=2222
SSH_USER="root"

# --- Banner ---
command -v figlet >/dev/null 2>&1 || pkg install figlet -y >/dev/null 2>&1
command -v lolcat >/dev/null 2>&1 || pkg install lolcat -y >/dev/null 2>&1
if command -v figlet >/dev/null 2>&1; then
    if command -v lolcat >/dev/null 2>&1; then
        figlet -f standard "SZex" | lolcat -a -d 1
    else
        figlet -f standard "SZex"
    fi
fi
echo ""

# Termux tidak punya /tmp standar Linux, pakai TMPDIR yang valid
LOG_DIR="${TMPDIR:-$PREFIX/tmp}"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG_FILE="$LOG_DIR/cf-access.log"

# Pastikan dependency terinstall
command -v cloudflared >/dev/null 2>&1 || { echo "Installing cloudflared..."; pkg install cloudflared -y; }
command -v ssh >/dev/null 2>&1 || { echo "Installing openssh..."; pkg install openssh -y; }

# Ambil hostname dari argumen atau input manual
HOSTNAME_ARG="$1"
if [ -z "$HOSTNAME_ARG" ]; then
    read -p "Masukkan hostname tunnel (contoh: xxxx.trycloudflare.com): " HOSTNAME_ARG
fi

if [ -z "$HOSTNAME_ARG" ]; then
    echo "Hostname kosong, batal."
    exit 1
fi

# Bersihkan kalau ada "https://" nyangkut
HOSTNAME_CLEAN=$(echo "$HOSTNAME_ARG" | sed 's#https://##' | sed 's#/$##')

echo "=== Mematikan tunnel lama (kalau ada) di port $LOCAL_PORT ==="
pkill -f "cloudflared access tcp" 2>/dev/null
sleep 1

echo "=== Membuka tunnel ke: $HOSTNAME_CLEAN ==="
nohup cloudflared access tcp --hostname "$HOSTNAME_CLEAN" --url localhost:$LOCAL_PORT > "$LOG_FILE" 2>&1 &
disown

echo "Menunggu tunnel siap..."
sleep 3
cat "$LOG_FILE" 2>/dev/null

# Pastikan tunnel benar-benar listening sebelum SSH dicoba
for i in $(seq 1 10); do
    if grep -qi "Start Websocket listener\|Listening on\|Connection established" "$LOG_FILE" 2>/dev/null; then
        echo "Tunnel siap."
        break
    fi
    sleep 1
done

echo ""
echo "Tunnel siap."

# Bersihkan host key lama untuk localhost:port ini secara otomatis,
# karena server sering regenerate SSH host key tiap restart (umum di container/Railway)
ssh-keygen -R "[localhost]:$LOCAL_PORT" >/dev/null 2>&1

echo ""
echo "=== Tunnel siap ==="
echo "Buka SESI TERMUX BARU (swipe dari kiri -> New session), lalu jalankan:"
echo ""
echo "  ssh -o StrictHostKeyChecking=no $SSH_USER@localhost -p $LOCAL_PORT"
echo ""
echo "Tunnel tetap berjalan di background. Jangan tutup sesi ini."
