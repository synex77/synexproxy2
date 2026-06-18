#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# GUVENLIK UYARISI:
# Bu script guvenlik analizinden gecirilmistir.
# Discord webhook ve harici API baglantilari temizlenmistir.
# Proxy binary dosyasi sifreli oldugu icin kaynaktan
# derlemeniz onerilir.
# ============================================
# Synex Proxy PRO Installer
# Termux için otomatik kurulum
# ============================================
# GUVENLIK UYARISI:
# Bu script guvenlik analizinden gecirilmistir.
# Discord webhook ve harici API baglantilari temizlenmistir.
# Proxy binary dosyasi sifreli oldugu icin kaynaktan
# derlemeniz onerilir.
# ============================================

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
ENDCOLOR="\e[0m"
BOLD="\e[1m"

PROXY_VERSION="v3.0-cleaned"
PROXY_DIR="$HOME/AJProxy"

clear

echo -e "${CYAN}"
echo "  ____                       __  ____             "
echo " / ___| _   _ _ __ ___ _ __ |  _|  _ \ _ __ _____  ___"
echo " \___ \| | | |  __/ _ \  _ \| |_)| |_) |  __/ _ \ \/ / "
echo "  ___) | |_| | | |  __/ | | | |_ |  __/| | | (_) >  <  "
echo " |____/ \__, |_|  \___|_| |_|_(_)|_|   |_|  \___/_/\_\ "
echo "        |___/                                         "
echo -e "${ENDCOLOR}"
echo -e "${BOLD}${GREEN}         Synex Proxy PRO Installer ${PROXY_VERSION}${ENDCOLOR}"
echo -e "${YELLOW}         Termux Otomatik Kurulum${ENDCOLOR}"
echo ""

# --------------------------------------------
# 1. Paketleri Yükle
# --------------------------------------------
echo -e "${GREEN}[1/4] Gerekli paketler yükleniyor...${ENDCOLOR}"
pkg update -y > /dev/null 2>&1
pkg install -y wget openssl curl libcurl libenet > /dev/null 2>&1
echo -e "${GREEN}      ✓ Paketler yüklendi${ENDCOLOR}"

# --------------------------------------------
# 2. Proxy Dizinini Oluştur
# --------------------------------------------
echo -e "${GREEN}[2/4] Proxy dizini hazırlanıyor...${ENDCOLOR}"
if [ -d "$PROXY_DIR" ]; then
    echo -e "${YELLOW}      Eski kurulum bulundu, yedekleniyor...${ENDCOLOR}"
    mv "$PROXY_DIR" "$PROXY_DIR.backup.$(date +%s)"
fi
mkdir -p "$PROXY_DIR"
echo -e "${GREEN}      ✓ Dizin hazır: $PROXY_DIR${ENDCOLOR}"

# --------------------------------------------
# 3. Proxy ve Dosyaları İndir
# --------------------------------------------
echo -e "${GREEN}[3/4] Synex Proxy dosyaları indiriliyor...${ENDCOLOR}"
cd "$PROXY_DIR"

# Proxy binary
wget -q --show-progress "https://github.com/synex77/synexproxy2/raw/main/proxy" -O "$PROXY_DIR/proxy"
chmod +x "$PROXY_DIR/proxy"

# Vars
wget -q --show-progress "https://raw.githubusercontent.com/synex77/synexproxy2/main/vars" -O "$PROXY_DIR/vars"

# Synex PRO Lua
wget -q --show-progress "https://raw.githubusercontent.com/synex77/synexproxy2/main/synex_pro.lua" -O "$PROXY_DIR/synex_pro.lua"

echo -e "${GREEN}      ✓ Dosyalar indirildi${ENDCOLOR}"

# --------------------------------------------
# 4. Başlatma Scripti
# --------------------------------------------
echo -e "${GREEN}[4/4] Başlatma scripti oluşturuluyor...${ENDCOLOR}"

cat > "$HOME/synexproxy" << 'STARTEREOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/AJProxy"
echo -e "\e[36mSynex Proxy PRO başlatılıyor...\e[0m"
echo -e "\e[32mProxy Server: 195.62.48.50:1234\e[0m"
echo -e "\e[33mÇıkmak için Ctrl+C\e[0m"
echo ""
./proxy "$@"
STARTEREOF

chmod +x "$HOME/synexproxy"

# PATH'e ekle ($PREFIX/bin/)
cp "$HOME/synexproxy" "$PREFIX/bin/synexproxy" 2>/dev/null
chmod +x "$PREFIX/bin/synexproxy" 2>/dev/null

# --------------------------------------------
# KURULUM TAMAMLANDI
# --------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}========================================${ENDCOLOR}"
echo -e "${BOLD}${YELLOW}    ⚠ UYARI: GUVENLIK ONLEMLERI${ENDCOLOR}"
echo -e "${YELLOW}    Proxy binary dosyasi sifrelenmis durumda.${ENDCOLOR}"
echo -e "${YELLOW}    Kaynak kodu inceleyip kendiniz derlemeniz onerilir.${ENDCOLOR}"
echo ""
echo -e "${BOLD}${GREEN}    ✓ KURULUM TAMAMLANDI!${ENDCOLOR}"
echo -e "${BOLD}${GREEN}========================================${ENDCOLOR}"
echo ""
echo -e "${CYAN}📁 Proxy dizini: ${YELLOW}$PROXY_DIR${ENDCOLOR}"
echo -e "${CYAN}🎮 Başlatma:    ${YELLOW}synexproxy${ENDCOLOR}"
echo ""

echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════╗${ENDCOLOR}"
echo -e "${BOLD}${YELLOW}║  ⚠️  ONEMLI: Virtual Hosts App Gerekli!         ║${ENDCOLOR}"
echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════╝${ENDCOLOR}"
echo ""
echo -e "${RED}Growtopia proxy'e baglanamazsa:${ENDCOLOR}"
echo -e "${YELLOW}1. Play Store'dan 'Virtual Hosts' veya 'Hosts Go' yukle${ENDCOLOR}"
echo -e "${YELLOW}2. Asagidaki hostlari Virtual Hosts app'ine gir:${ENDCOLOR}"
echo ""
echo -e "${CYAN}   195.62.48.50 www.growtopia1.com${ENDCOLOR}"
echo -e "${CYAN}   195.62.48.50 www.growtopia2.com${ENDCOLOR}"
echo ""
echo -e "${YELLOW}3. VPN'i baslat, sonra Growtopia'ya gir${ENDCOLOR}"
echo ""

echo -e "${BOLD}${GREEN}Komutlar:${ENDCOLOR}"
echo -e "  ${YELLOW}synexproxy${ENDCOLOR}              - Proxy'i başlat"
echo ""
echo -e "${BOLD}${YELLOW}SYNEX PROXY PRO Komutları (oyundayken):${ENDCOLOR}"
echo -e "  ${CYAN}/menu${ENDCOLOR}              - Ana menüyü aç"
echo -e "  ${CYAN}/ft${ENDCOLOR} / ${CYAN}/nf${ENDCOLOR}           - Fly aç/kapat"
echo -e "  ${CYAN}/ghost${ENDCOLOR} / ${CYAN}/gf${ENDCOLOR}       - Ghost/NoClip aç/kapat"
echo -e "  ${CYAN}/cbgl${ENDCOLOR} / ${CYAN}/cbgloff${ENDCOLOR}   - Auto CBGL aç/kapat"
echo -e "  ${CYAN}/cg${ENDCOLOR} / ${CYAN}/cgoff${ENDCOLOR}        - CheckGems aç/kapat"
echo -e "  ${CYAN}/fd${ENDCOLOR} / ${CYAN}/fdoff${ENDCOLOR}        - FastDrop aç/kapat"
echo -e "  ${CYAN}/tp [isim]${ENDCOLOR}        - Oyuncuya ışınlan"
echo -e "  ${CYAN}/drop [miktar]${ENDCOLOR}    - DL/WL düşür"
echo -e "  ${CYAN}/pullall${ENDCOLOR}          - Herkesi çek"
echo -e "  ${CYAN}/legend${ENDCOLOR}           - Legend title"
echo -e "  ${CYAN}/maxlevel${ENDCOLOR}         - Mavi isim (Max Level)"
echo ""
echo -e "${GREEN}Başlamak için: ${BOLD}synexproxy${ENDCOLOR}"
echo ""
