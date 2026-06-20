#!/bin/bash
# ============================================
# setup-shell.sh
# Jalankan di server (lewat ttyd atau setelah SSH)
# Fungsi: install & setup Oh My Zsh (tema robbyrussell)
#         + neofetch saat login + styling sudo
# ============================================

set +e
USER_HOME="$HOME"
ZSHRC="$USER_HOME/.zshrc"

echo "=== 1. Install dependency dasar ==="
apt update -y
apt install -y zsh git curl wget sudo neofetch fonts-powerline 2>/dev/null

echo ""
echo "=== 2. Install Oh My Zsh ==="
if [ -d "$USER_HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh sudah terinstall, skip."
else
    RUNZSH=no CHSH=no KEEP_ZSHRC=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo ""
echo "=== 3. Set tema ke robbyrussell ==="
if [ -f "$ZSHRC" ]; then
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' "$ZSHRC"
else
    echo 'ZSH_THEME="robbyrussell"' >> "$ZSHRC"
fi

echo ""
echo "=== 4. Tambah plugin berguna (git, sudo, command-not-found) ==="
if grep -q '^plugins=' "$ZSHRC"; then
    sed -i 's/^plugins=.*/plugins=(git sudo command-not-found)/' "$ZSHRC"
else
    echo 'plugins=(git sudo command-not-found)' >> "$ZSHRC"
fi
# plugin "sudo" dari Oh My Zsh: tekan ESC dua kali buat nambahin "sudo " di depan command terakhir

echo ""
echo "=== 5. Tambah neofetch otomatis muncul saat login shell ==="
if ! grep -q "neofetch" "$ZSHRC"; then
    cat >> "$ZSHRC" << 'EOF'

# Tampilkan neofetch setiap login shell interaktif
if [ -t 1 ] && command -v neofetch >/dev/null 2>&1; then
    neofetch
fi
EOF
fi

echo ""
echo "=== 6. Styling prompt sudo (highlight command jadi merah saat pakai sudo) ==="
cat >> "$ZSHRC" << 'EOF'

# --- Styling tambahan: highlight saat menjalankan sudo ---
sudo() {
    echo -e "\033[1;31m[sudo]\033[0m menjalankan: \033[1;33m$*\033[0m"
    command sudo "$@"
}
EOF

echo ""
echo "=== 7. Set zsh sebagai default shell ==="
ZSH_PATH=$(command -v zsh)
if [ -n "$ZSH_PATH" ]; then
    chsh -s "$ZSH_PATH" "$(whoami)" 2>/dev/null
    if [ -f /etc/passwd ]; then
        sed -i "s#^\($(whoami):.*:\).*#\1$ZSH_PATH#" /etc/passwd 2>/dev/null
    fi
    echo "Default shell diset ke: $ZSH_PATH"
else
    echo "zsh tidak ditemukan, default shell tidak diubah."
fi

echo ""
echo "=== SELESAI ==="
echo "Ketik 'zsh' untuk langsung coba sekarang, atau logout/SSH ulang"
echo "supaya default shell baru aktif otomatis."
