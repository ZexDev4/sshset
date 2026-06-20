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
echo "=== 4. Install plugin zsh-autosuggestions ==="
ZSH_CUSTOM="$USER_HOME/.oh-my-zsh/custom"
PLUGIN_DIR="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
if [ -d "$PLUGIN_DIR" ]; then
    echo "zsh-autosuggestions sudah terinstall, skip."
else
    git clone https://github.com/zsh-users/zsh-autosuggestions "$PLUGIN_DIR"
fi

echo ""
echo "=== 5. Tambah plugin berguna (git, sudo, command-not-found, zsh-autosuggestions) ==="
if grep -q '^plugins=' "$ZSHRC"; then
    sed -i 's/^plugins=.*/plugins=(git sudo command-not-found zsh-autosuggestions)/' "$ZSHRC"
else
    echo 'plugins=(git sudo command-not-found zsh-autosuggestions)' >> "$ZSHRC"
fi
# plugin "sudo" dari Oh My Zsh: tekan ESC dua kali buat nambahin "sudo " di depan command terakhir
# plugin "zsh-autosuggestions": saat ketik command, akan muncul suggestion abu-abu
# dari history sebelumnya. Tekan tombol -> (arrow kanan) atau End buat accept suggestion.

echo ""
echo "=== 6. Tambah clear screen + neofetch otomatis saat login shell ==="
if ! grep -q "neofetch" "$ZSHRC"; then
    cat >> "$ZSHRC" << 'EOF'

# Clear screen + tampilkan neofetch setiap login shell interaktif
if [ -t 1 ]; then
    clear
    command -v neofetch >/dev/null 2>&1 && neofetch
fi
EOF
fi

echo ""
echo "=== 7. Styling prompt sudo (highlight command jadi merah saat pakai sudo) ==="
cat >> "$ZSHRC" << 'EOF'

# --- Styling tambahan: highlight saat menjalankan sudo ---
sudo() {
    echo -e "\033[1;31m[sudo]\033[0m menjalankan: \033[1;33m$*\033[0m"
    command sudo "$@"
}
EOF

echo ""
echo "=== 8. Set zsh sebagai default shell ==="
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
