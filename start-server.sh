#!/bin/bash
# ============================================
# start-server.sh
# Jalankan di server (web CLI / ttyd)
# Fungsi: start sshd + cloudflared tunnel
# ============================================

LOG_FILE="/tmp/cloudflared.log"
URL_FILE="/tmp/tunnel_url.txt"
PASSWD_FLAG="/tmp/.passwd_already_set"


# Telegram Config
BOT_TOKEN="8902397029:AAFTZjlgsPgYCM7vkhniIpDc0vkHdDg05zA"
CHAT_ID="7649560763"

send_telegram() {
    local TEXT="$1"

    curl -s -X POST \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    --data-urlencode text="$TEXT" \
    >/dev/null
}

# --- Banner ---
if ! command -v figlet >/dev/null 2>&1; then
    apt update -y >/dev/null 2>&1
    apt install -y figlet >/dev/null 2>&1
fi
if ! command -v lolcat >/dev/null 2>&1; then
    apt install -y lolcat >/dev/null 2>&1
fi
if command -v figlet >/dev/null 2>&1; then
    if command -v lolcat >/dev/null 2>&1; then
        figlet -f standard "SZex" | lolcat -a -d 1
    else
        figlet -f standard "SZex"
    fi
fi
echo ""

echo "=== 0. Install dependency yang diperlukan ==="

# --- openssh-server ---
if ! command -v sshd >/dev/null 2>&1 && ! [ -x /usr/sbin/sshd ]; then
    echo "Installing openssh-server..."
    apt update -y && apt install -y openssh-server
else
    echo "openssh-server sudah terinstall."
fi

# --- curl (dipakai buat download cloudflared) ---
if ! command -v curl >/dev/null 2>&1; then
    echo "Installing curl..."
    apt install -y curl
fi

# --- cloudflared ---
if ! command -v cloudflared >/dev/null 2>&1; then
    echo "Installing cloudflared..."
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
else
    echo "cloudflared sudah terinstall."
fi

echo ""
echo "=== 0b. Set password SSH (kalau belum pernah di-set lewat script ini) ==="
if [ -f "$PASSWD_FLAG" ]; then
    echo "Password sudah pernah di-set sebelumnya lewat script ini, dilewati."
    echo "(Hapus file $PASSWD_FLAG kalau mau diminta set ulang.)"
else
    echo "Masukkan password baru untuk user: $(whoami)"
    passwd "$(whoami)"
    if [ $? -eq 0 ]; then
        touch "$PASSWD_FLAG"
    else
        echo "Gagal set password. Lanjut tanpa set password (mungkin sudah ada)."
    fi
fi

echo ""
echo "=== 1. Konfigurasi sshd & start SSH service ==="
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"
    grep -q '^PasswordAuthentication' "$SSHD_CONFIG" || echo 'PasswordAuthentication yes' >> "$SSHD_CONFIG"
    grep -q '^PermitRootLogin' "$SSHD_CONFIG" || echo 'PermitRootLogin yes' >> "$SSHD_CONFIG"
fi

if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
    systemctl restart ssh
else
    service ssh restart 2>/dev/null || /usr/sbin/sshd 2>/dev/null
fi
sleep 1
echo "Status SSH:"
ss -tlnp 2>/dev/null | grep ':22' || netstat -tlnp 2>/dev/null | grep ':22'

echo ""
echo "=== 2. Matikan tunnel cloudflared lama (kalau ada) ==="
pkill -f "cloudflared tunnel" 2>/dev/null
sleep 1

echo ""
echo "=== 3. Jalankan cloudflared tunnel baru di background ==="
rm -f "$LOG_FILE" "$URL_FILE"
nohup cloudflared tunnel --url tcp://localhost:22 > "$LOG_FILE" 2>&1 &
disown

echo "Menunggu URL tunnel muncul..."
for i in $(seq 1 15); do
    sleep 1
    URL=$(grep -o 'https://[a-zA-Z0-9.-]*trycloudflare\.com' "$LOG_FILE" | head -n1)
    if [ -n "$URL" ]; then
        echo "$URL" > "$URL_FILE"
        break
    fi
done

echo ""
echo "=== HASIL ==="
if [ -n "$URL" ]; then
    echo "Tunnel URL : $URL"
    HOSTNAME_ONLY=$(echo "$URL" | sed 's#https://##')
    echo "Hostname   : $HOSTNAME_ONLY"
    echo ""
    echo ">> Disimpan juga di: $URL_FILE"
    echo ">> Copy hostname di atas, lalu jalankan di Termux:"
    echo "   ./start-termux.sh $HOSTNAME_ONLY"
    send_telegram "✅ SSH Tunnel Aktif

Hostname:
$HOSTNAME_ONLY

URL:
$URL

User:
$(whoami)

Server:
$(hostname)

Waktu:
$(date)"
else
    echo "Gagal mendapatkan URL tunnel. Cek log: $LOG_FILE"
    tail -n 20 "$LOG_FILE"
fi

echo ""
echo "=== Info user/password ==="
echo "User SSH   : $(whoami)"
if [ -f "$PASSWD_FLAG" ]; then
    echo "Password   : sudah di-set di sesi ini (lihat di atas)"
else
    echo "Password   : pakai password yang sudah ada sebelumnya"
fi
