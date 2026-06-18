#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Synex Proxy PRO Installer
# Termux için otomatik kurulum
# ============================================

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
ENDCOLOR="\e[0m"
BOLD="\e[1m"

PROXY_VERSION="v3.0"
PROXY_DIR="$HOME/SynexProxy"
HOSTS_FILE="/data/data/com.termux/files/usr/etc/hosts"

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
# 0. libcurl Uyumluluk Fix
# --------------------------------------------
echo -e "${GREEN}[0/8] libcurl uyumluluk kontrolü...${ENDCOLOR}"
pkg install -y libnghttp3 libngtcp2 > /dev/null 2>&1
pkg reinstall -y curl libcurl > /dev/null 2>&1
echo -e "${GREEN}      ✓ libcurl güncellendi${ENDCOLOR}"

# --------------------------------------------
# 1. Paketleri Yükle
# --------------------------------------------
echo -e "${GREEN}[1/8] Gerekli paketler yükleniyor...${ENDCOLOR}"
pkg update -y > /dev/null 2>&1
pkg install -y wget openssl curl libcurl libenet tsu > /dev/null 2>&1
echo -e "${GREEN}      ✓ Paketler yüklendi${ENDCOLOR}"

# --------------------------------------------
# 2. Proxy Dizinini Oluştur
# --------------------------------------------
echo -e "${GREEN}[2/8] Proxy dizini hazırlanıyor...${ENDCOLOR}"
# Eski AJProxy dizinini de temizle
if [ -d "$HOME/AJProxy" ]; then
    echo -e "${YELLOW}      Eski AJProxy dizini siliniyor...${ENDCOLOR}"
    rm -rf "$HOME/AJProxy"
fi
if [ -d "$PROXY_DIR" ]; then
    echo -e "${YELLOW}      Eski kurulum bulundu, yedekleniyor...${ENDCOLOR}"
    mv "$PROXY_DIR" "$PROXY_DIR.backup.$(date +%s)"
fi
mkdir -p "$PROXY_DIR"
echo -e "${GREEN}      ✓ Dizin hazır: $PROXY_DIR${ENDCOLOR}"

# --------------------------------------------
# 3. Eski Başlatıcıyı Temizle
# --------------------------------------------
echo -e "${GREEN}[3/8] Eski başlatıcı temizleniyor...${ENDCOLOR}"
rm -f "$HOME/ajproxy"
echo -e "${GREEN}      ✓ Eski başlatıcı silindi${ENDCOLOR}"

# --------------------------------------------
# 4. Hosts Dosyasını Ayarla (Virtual Hosts)
# --------------------------------------------
echo -e "${GREEN}[4/8] Virtual hosts ayarlanıyor (/etc/hosts)...${ENDCOLOR}"

# Önce eski hostları temizle
if [ -f "$HOSTS_FILE" ]; then
    grep -v "# SynexProxy\|# AJProxy\|growtopia1.com\|growtopia2.com" "$HOSTS_FILE" > "$PROXY_DIR/hosts.tmp" 2>/dev/null
    mv "$PROXY_DIR/hosts.tmp" "$HOSTS_FILE" 2>/dev/null
fi

# Yeni hostları ekle
cat >> "$HOSTS_FILE" << 'HOSTSEOF'

# ============================================
# SynexProxy - Virtual Hosts
# ============================================
# SynexProxy
195.62.48.50 www.growtopia1.com
195.62.48.50 www.growtopia2.com
HOSTSEOF

echo -e "${GREEN}      ✓ Virtual hosts eklendi${ENDCOLOR}"
echo -e "${CYAN}        → growtopia1.com → 195.62.48.50${ENDCOLOR}"
echo -e "${CYAN}        → growtopia2.com → 195.62.48.50${ENDCOLOR}"

# --------------------------------------------
# 5. Proxy Binary'sini İndir
# --------------------------------------------
echo -e "${GREEN}[5/8] Synex Proxy binary indiriliyor...${ENDCOLOR}"
cd "$PROXY_DIR"

wget -q --show-progress "https://github.com/synex77/synexproxy2/raw/main/proxy" -O "$PROXY_DIR/proxy"
if [ ! -f "$PROXY_DIR/proxy" ]; then
    echo -e "${RED}      ✗ Proxy indirilemedi!${ENDCOLOR}"
    echo -e "${YELLOW}      Alternatif kaynak deneniyor...${ENDCOLOR}"
    wget -q --show-progress "https://raw.githubusercontent.com/synex77/synexproxy2/main/proxy" -O "$PROXY_DIR/proxy"
fi

chmod +x "$PROXY_DIR/proxy"
echo -e "${GREEN}      ✓ Proxy indirildi${ENDCOLOR}"

# --------------------------------------------
# 6. Vars Dosyasını İndir
# --------------------------------------------
echo -e "${GREEN}[6/8] Yapılandırma dosyası (vars) indiriliyor...${ENDCOLOR}"
wget -q --show-progress "https://raw.githubusercontent.com/synex77/synexproxy2/main/vars" -O "$PROXY_DIR/vars"
echo -e "${GREEN}      ✓ Yapılandırma dosyası indirildi${ENDCOLOR}"

# --------------------------------------------
# 7. Synex Proxy PRO Lua Scriptini İndir
# --------------------------------------------
echo -e "${GREEN}[7/8] Synex Proxy PRO mod menüsü indiriliyor...${ENDCOLOR}"
wget -q --show-progress "https://raw.githubusercontent.com/synex77/synexproxy2/main/synex_pro.lua" -O "$PROXY_DIR/synex_pro.lua"

if [ -f "$PROXY_DIR/synex_pro.lua" ]; then
    echo -e "${GREEN}      ✓ Synex Proxy PRO mod menüsü hazır${ENDCOLOR}"
else
    echo -e "${YELLOW}      ! Mod menüsü indirilemedi, manuel yüklemeniz gerekebilir${ENDCOLOR}"
fi

# --------------------------------------------
# 8. Başlatma Scripti Oluştur
# --------------------------------------------
echo -e "${GREEN}[8/8] Başlatma scripti oluşturuluyor...${ENDCOLOR}"

cat > "$HOME/synexproxy" << 'STARTEREOF'
#!/data/data/com.termux/files/usr/bin/bash
PROXY_DIR="$HOME/SynexProxy"

cd "$PROXY_DIR"

# Hosts kontrol et
grep -q "growtopia1.com" /data/data/com.termux/files/usr/etc/hosts 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "\e[33m[UYARI] Virtual hosts bulunamadı, yeniden ayarlanıyor...\e[0m"
    echo "195.62.48.50 www.growtopia1.com" >> /data/data/com.termux/files/usr/etc/hosts
    echo "195.62.48.50 www.growtopia2.com" >> /data/data/com.termux/files/usr/etc/hosts
fi

# Proxy'i başlat
echo -e "\e[36mSynex Proxy PRO başlatılıyor...\e[0m"
echo -e "\e[32mProxy Server: 195.62.48.50:1234\e[0m"
echo -e "\e[32mGrowtopia IP: 213.179.209.175:17043\e[0m"
echo -e "\e[33mÇıkmak için Ctrl+C\e[0m"
echo ""
./proxy "$@"
STARTEREOF

chmod +x "$HOME/synexproxy"

# PATH'e ekle
if [ -d "$PREFIX/bin" ]; then
    cp "$HOME/synexproxy" "$PREFIX/bin/synexproxy" 2>/dev/null
    chmod +x "$PREFIX/bin/synexproxy" 2>/dev/null
fi

# --------------------------------------------
# KURULUM TAMAMLANDI
# --------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}========================================${ENDCOLOR}"
echo -e "${BOLD}${GREEN}    ✓ KURULUM TAMAMLANDI!${ENDCOLOR}"
echo -e "${BOLD}${GREEN}========================================${ENDCOLOR}"
echo ""
echo -e "${CYAN}📁 Proxy dizini: ${YELLOW}$PROXY_DIR${ENDCOLOR}"
echo -e "${CYAN}🎮 Başlatma:    ${YELLOW}synexproxy${ENDCOLOR}"
echo -e "${CYAN}🌐 Hosts:       ${YELLOW}/data/data/com.termux/files/usr/etc/hosts${ENDCOLOR}"
echo ""
echo -e "${BOLD}${GREEN}Komutlar:${ENDCOLOR}"
echo -e "  ${YELLOW}synexproxy${ENDCOLOR}              - Proxy'i başlat"
echo -e "  ${YELLOW}synexproxy --help${ENDCOLOR}       - Yardım"
echo ""
echo -e "${BOLD}${YELLOW}SYNEX PROXY PRO Komutları (oyundayken):${ENDCOLOR}"
echo -e "  ${CYAN}/menu${ENDCOLOR}              - Ana menüyü aç"
echo -e "  ${CYAN}/ft${ENDCOLOR} / ${CYAN}/nf${ENDCOLOR}           - Fly aç/kapat"
echo -e "  ${CYAN}/ghost${ENDCOLOR} / ${CYAN}/gf${ENDCOLOR}       - Ghost/NoClip aç/kapat"
echo -e "  ${CYAN}/cbgl${ENDCOLOR} / ${CYAN}/cbgloff${ENDCOLOR}   - Auto CBGL aç/kapat"
echo -e "  ${CYAN}/cg${ENDCOLOR} / ${CYAN}/cgoff${ENDCOLOR}        - CheckGems aç/kapat"
echo -e "  ${CYAN}/fd${ENDCOLOR} / ${CYAN}/fdoff${ENDCOLOR}        - FastDrop aç/kapat"
echo -e "  ${CYAN}/afk${ENDCOLOR} / ${CYAN}/afkoff${ENDCOLOR}      - AFK modu aç/kapat"
echo -e "  ${CYAN}/tp [isim]${ENDCOLOR}        - Oyuncuya ışınlan"
echo -e "  ${CYAN}/drop [miktar]${ENDCOLOR}    - DL/WL düşür"
echo -e "  ${CYAN}/pullall${ENDCOLOR}          - Herkesi çek"
echo -e "  ${CYAN}/legend${ENDCOLOR}           - Legend title"
echo -e "  ${CYAN}/maxlevel${ENDCOLOR}         - Mavi isim (Max Level)"
echo ""
echo -e "${GREEN}Başlamak için: ${BOLD}synexproxy${ENDCOLOR}"
echo ""
