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
nohup cloudflared access tcp --hostname "$HOSTNAME_CLEAN" --url localhost:$LOCAL_PORT > /tmp/cf-access.log 2>&1 &
disown

echo "Menunggu tunnel siap..."
sleep 3
cat /tmp/cf-access.log

echo ""
echo "=== Connect SSH ==="
echo "Menjalankan: ssh $SSH_USER@localhost -p $LOCAL_PORT"
ssh "$SSH_USER@localhost" -p $LOCAL_PORT
