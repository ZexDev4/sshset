#!/bin/bash
# ============================================
# start-server.sh
# Jalankan di server (web CLI / ttyd)
# Fungsi: start sshd + bore tunnel
# ============================================

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

echo "=== 0. Install dependency ==="

if ! command -v sshd >/dev/null 2>&1 && ! [ -x /usr/sbin/sshd ]; then
    echo "Installing openssh-server..."
    apt update -y && apt install -y openssh-server
else
    echo "openssh-server sudah terinstall."
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Installing curl..."
    apt install -y curl
fi

# Install bore
if ! command -v bore >/dev/null 2>&1 && ! [ -f /usr/local/bin/bore ]; then
    echo "Installing bore..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        BORE_URL="https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz"
    elif [ "$ARCH" = "aarch64" ]; then
        BORE_URL="https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-aarch64-unknown-linux-musl.tar.gz"
    else
        echo "Arsitektur tidak dikenali: $ARCH"
        exit 1
    fi
    curl -L "$BORE_URL" -o /tmp/bore.tar.gz
    tar xzf /tmp/bore.tar.gz -C /tmp/
    mv /tmp/bore /usr/local/bin/bore
    chmod +x /usr/local/bin/bore
    rm -f /tmp/bore.tar.gz
    echo "bore versi: $(bore --version)"
else
    echo "bore sudah terinstall."
fi

echo ""
echo "=== 0b. Set password SSH ==="
if [ -f "$PASSWD_FLAG" ]; then
    echo "Password sudah pernah di-set, dilewati."
else
    echo "Masukkan password baru untuk user: $(whoami)"
    passwd "$(whoami)"
    if [ $? -eq 0 ]; then
        touch "$PASSWD_FLAG"
    else
        echo "Gagal set password."
    fi
fi

echo ""
echo "=== 1. Konfigurasi sshd & start SSH ==="
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
echo "=== 2. Matikan tunnel bore lama (kalau ada) ==="
pkill -f "bore local" 2>/dev/null
sleep 1

echo ""
echo "=== 3. Jalankan bore tunnel ==="
BORE_LOG="/tmp/bore.log"
rm -f "$BORE_LOG"
nohup bore local 22 --to bore.pub > "$BORE_LOG" 2>&1 &
disown

echo "Menunggu port tunnel muncul..."
BORE_PORT=""
for i in $(seq 1 15); do
    sleep 1
    BORE_PORT=$(grep -o 'listening at bore.pub:[0-9]*' "$BORE_LOG" | grep -o '[0-9]*$')
    if [ -n "$BORE_PORT" ]; then
        break
    fi
done

echo ""
echo "=== HASIL ==="
if [ -n "$BORE_PORT" ]; then
    echo "Host : bore.pub"
    echo "Port : $BORE_PORT"
    echo ""
    echo ">> Konek di Termius:"
    echo "   Hostname : bore.pub"
    echo "   Port     : $BORE_PORT"
    echo "   User     : $(whoami)"

    send_telegram "✅ SSH Tunnel Aktif (bore.pub)

Host: bore.pub
Port: $BORE_PORT
User: $(whoami)
Server: $(hostname)
Waktu: $(date)

Konek via Termius:
Host: bore.pub
Port: $BORE_PORT"
else
    echo "Gagal mendapatkan port. Cek log: $BORE_LOG"
    tail -n 20 "$BORE_LOG"
    send_telegram "❌ SSH Tunnel GAGAL

Server: $(hostname)
Waktu: $(date)

Log:
$(tail -n 10 $BORE_LOG)"
fi

echo ""
echo "=== Info user ==="
echo "User SSH : $(whoami)"
