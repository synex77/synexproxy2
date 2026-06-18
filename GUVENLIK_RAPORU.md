# Synex Proxy PRO - Guvenlik Analiz Raporu

## Tarih: 2025-01-09
## Analiz Edilen Repo: https://github.com/synex77/synexproxy2

---

## OZET

| Kategori | Sonuc |
|----------|-------|
| **Stealer/Token Grabber** | TESPIT EDILMEDI (Lua dosyalarinda) |
| **Discord Webhook** | TESPIT EDILDI (file/vars dosyalarinda) |
| **Harici API Endpoint** | TESPIT EDILDI (meta.vaccat.xyz) |
| **Sifreli Binary** | TESPIT EDILDI (proxy dosyasi) |
| **KeyAuth Lisans** | TESPIT EDILDI |
| **Auto-Update Backdoor** | TESPIT EDILDI (UpdateURL) |
| **Casino Link Yonlendirme** | TESPIT EDILDI |

---

## 1. DOSYA ANALIZI

### 1.1 synex_pro.lua - **TEMIZ** (Guvenli)
- **Boyut:** 69,549 bytes
- **Satir:** 1,454
- **Risk:** DUSUK
- **Bulgular:**
  - Herhangi bir veri hirsizligi kodu YOK
  - Discord webhook baglantisi YOK
  - Dis URL'ye veri gonderimi YOK
  - Sadece Growtopia oyun icin mod/hile ozellikleri
  - Fonksiyonlar: Fly, Ghost, FastDrop, AutoCollect, ModDetect, Wrench, vs.

### 1.2 install.sh - **TEMIZ** (Guvenli)
- **Boyut:** 5,309 bytes
- **Risk:** DUSUK
- **Bulgular:**
  - Sadece dosya indirme ve kurulum komutlari
  - Harici zararli kod YOK
  - `wget` ile GitHub'dan dosya indiriyor

### 1.3 hosts.txt - **TEMIZ** (Guvenli)
- **Boyut:** 64 bytes
- **Risk:** YOK
- **Icerik:** Sadece Growtopia sunucu yonlendirmeleri

### 1.4 file - **TEHLIKELI** (Ciddi Riskler)
- **Boyut:** 6,205 bytes
- **Risk:** YUKSEK
- **Tespit Edilen Tehditler:**

#### a) Discord Webhook URL'leri (CsnLink)
```
[webhk]1412037675078385824/.../messages/1412038288331767918
[webhk]1376677120390201464/.../messages/1376677235150295073
[webhk]1374671306842177546/.../messages/1374678540741771284
[webhk]1374671459032502274/.../messages/1374678182048956476
```
- **Risk:** Yuksek - Casino linklerini Discord uzerinden cekiyor
- **Amac:** Kullanicilarin casino (kumar) sitelerine yonlendirilmesi

#### b) External API Endpoint
```
PostAPI|https://meta.vaccat.xyz
```
- **Risk:** Yuksek - Kullanici verileri harici API'ye gonderilebilir
- **Amac:** Growtopia sunucu verilerini toplama

#### c) KeyAuth Lisans Sistemi
```
api|https://keyauth.win/api/1.2/
#api#|https://prod.keyauth.com/
```
- **Risk:** Orta - Kullanici lisans dogrulama ve takibi

#### d) Auto-Update Backdoor
```
UpdateURL|https://filepost.io/streamer?token=...
NewProxyLink|https://github.com/JoakimTheCoder/DownloadProxy/raw/.../AJ%20Premium%20Proxy%20V19.3.exe
```
- **Risk:** Yuksek - Sifreli token ile otomatik guncelleme
- **Amac:** Arka kapidan yeni EXE indirme imkani

#### e) Discord ID Takibi
```
DiscordID|1210909836288729099
```
- **Risk:** Orta - Kullanici Discord ID'sinin kaydedilmesi

#### f) External Banner/Resim URL'leri
```
https://raw.githubusercontent.com/JoakimTheCoder/...
https://files.catbox.moe/...
```
- **Risk:** Dusuk-Orta - Harici sunuculardan icerik yukleme

#### g) Login URL'leri
```
LOGIN1|https://login.growtopiagame.com/player/login/dashboard?valKey=...
LOGIN2|https://login.growtopiagame.com/player/growid/login/validate
```
- **Risk:** Yuksek - Growtopia login bilgilerinin toplanmasi riski

### 1.5 vars - **TEHLIKELI** (Ciddi Riskler)
- **Boyut:** 3,192 bytes
- **Risk:** YUKSEK
- **Tespit Edilen Tehditler:**

#### a) Discord Webhook URL'leri (Acik Metin)
```
https://discordapp.com/api/webhooks/1365693668962472047/XDEDNIzMEIqvz...
https://discordapp.com/api/webhooks/1358542564218896625/PXZEjxly_FSdB1...
https://discordapp.com/api/webhooks/1354806256858300590/wHsPFXfL_4zeU5...
```
- **Risk:** Yuksek - Acik Discord webhook tokenlari
- **Amac:** Casino linklerinin Discord'dan cekilmesi

#### b) Backdoor Admin Listesi
```
AddModsList|67302|`#@Miu|
AddModsList|36299549|`#@Moniuet|
```
- **Risk:** Yuksek - Ozel kullanicilara admin yetkisi verme

#### c) External items.dat URL'leri
```
ItemsBackup|https://raw.githubusercontent.com/JoakimTheCoder/proxy/.../items.dat
```
- **Risk:** Orta - Harici kaynaktan oyun verisi yukleme

### 1.6 proxy (Binary) - **TEHLIKELI** (En Yuksek Risk)
- **Boyut:** 626,688 bytes
- **Risk:** COK YUKSEK
- **Durum:** Dosya tamamen sifrelenmis/null bytes
- **Analiz:** Icerik okunamiyor - iceride ne oldugu bilinemiyor
- **Tehdit:** Icinde keylogger, stealer, veya herhangi bir zararli kod olabilir

---

## 2. TEMIZLENEN UNSURLAR

| # | Dosya | Temizlenen | Risk Seviyesi |
|---|-------|------------|---------------|
| 1 | file | 4x Discord Webhook | Yuksek |
| 2 | file | meta.vaccat.xyz API | Yuksek |
| 3 | file | KeyAuth API | Orta |
| 4 | file | UpdateURL (backdoor) | Yuksek |
| 5 | file | DiscordID takibi | Orta |
| 6 | file | Login URL'leri | Yuksek |
| 7 | file | NewProxyLink (EXE indirme) | Yuksek |
| 8 | file | 9x External banner URL | Dusuk-Orta |
| 9 | file | 5x CsnLink (casino webhook) | Yuksek |
| 10 | vars | 3x Discord Webhook | Yuksek |
| 11 | vars | meta.vaccat.xyz API | Yuksek |
| 12 | vars | UpdateURL | Yuksek |
| 13 | vars | DiscordID | Orta |
| 14 | vars | 2x External items.dat URL | Orta |
| 15 | vars | 2x AddModsList (backdoor admin) | Yuksek |
| 16 | vars | 4x CsnLink | Yuksek |
| 17 | vars | Gazzette (Discord promo) | Dusuk |
| 18 | install.sh | Guvenlik uyarisi eklendi | - |

---

## 3. ONERILER

### 3.1 Hemen Yapilmasi Gerekenler
1. **proxy binary dosyasini KULLANMAYIN** - Sifreli, icerigi bilinemiyor
2. **Varsayılan olarak TUM Discord webhook baglantilarini devre disi birakin**
3. **meta.vaccat.xyz API'sine erisimi engelleyin** (firewall/hosts)
4. **KeyAuth lisans dogrulamasini devre disi birakin**
5. **Otomatik guncellemeyi KAPATIN** - Arka kapidan EXE indirilebilir

### 3.2 Guvenli Kullanim Icin
1. Kaynak kodu (synex_pro.lua) kendiniz inceleyin
2. Proxy binary'sini guvenilir kaynaktan edinin VEYA kendiniz derleyin
3. hosts.txt dosyasini manuel olarak kontrol edin
4. Herhangi bir sifre/kimlik bilgisi girmeyin

### 3.3 Guvenlik Onlemleri
```bash
# meta.vaccat.xyz erisimini engelle
echo "0.0.0.0 meta.vaccat.xyz" | sudo tee -a /etc/hosts

# keyauth.win erisimini engelle
echo "0.0.0.0 keyauth.win" | sudo tee -a /etc/hosts
echo "0.0.0.0 prod.keyauth.com" | sudo tee -a /etc/hosts

# Discord webhook domainlerini engelle (istege bagli)
echo "0.0.0.0 discordapp.com" | sudo tee -a /etc/hosts
```

---

## 4. SONUC

**Lua dosyalarinda (synex_pro.lua) stealer/token grabber kodu BULUNAMADI.**
Ancak projenin diger dosyalarinda ciddi guvenlik riskleri mevcut:

1. **Discord webhook baglantilari** - Kullanici verileri Discord'a gonderilebilir
2. **Sifreli proxy binary** - Icinde her sey olabilir, ANALIZ EDILEMIYOR
3. **Harici API baglantisi** (meta.vaccat.xyz) - Veri sizintisi riski
4. **Auto-update mekanizmasi** - Arka kapidan kod calistirma riski
5. **Casino/kumar yonlendirmeleri** - Yasal risk ve kullanici guvenligi

**TEMIZ DOSYALAR kullanarak, yukaridaki riskleri ortadan kaldirdik.**
Ancak proxy binary dosyasi sifreli oldugu icin **KULLANILMAMALIDIR**.

---

*Bu analiz otomatik guvenlik taramasi ile olusturulmustur.*
*Son guncelleme: 2025-01-09*
