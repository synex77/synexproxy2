# Synex Proxy PRO

Growtopia için Android/Termux proxy kurulumu.

## Kurulum (Tek Komut)

Termux'a yapıştır:

```bash
pkg update -y && pkg install -y wget && wget https://github.com/synex77/synexproxy2/raw/main/install.sh && bash install.sh
```

## Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `install.sh` | Ana kurulum scripti |
| `proxy` | Synex Proxy binary ( Growtopia trafik yönlendirici ) |
| `vars` | Proxy yapılandırma dosyası |
| `hosts.txt` | Virtual host mapping |
| `synex_pro.lua` | Synex Proxy PRO mod menüsü |

## Virtual Hosts (/etc/hosts)

```
195.62.48.50 www.growtopia1.com
195.62.48.50 www.growtopia2.com
```

## Başlatma

```bash
synexproxy
```

## Hata Çözümü

Eğer `libcurl.so` hatası alırsan:

```bash
pkg install libnghttp3 libngtcp2
pkg reinstall curl libcurl
```

## Synex PRO Komutları

| Komut | Açıklama |
|-------|----------|
| `/menu` | Ana menü |
| `/ft` / `/nf` | Fly aç/kapat |
| `/ghost` / `/gf` | Ghost/NoClip aç/kapat |
| `/cbgl` / `/cbgloff` | Auto CBGL aç/kapat |
| `/cg` / `/cgoff` | CheckGems aç/kapat |
| `/fd` / `/fdoff` | FastDrop aç/kapat |
| `/afk` / `/afkoff` | AFK modu aç/kapat |
| `/tp [isim]` | Oyuncuya ışınlan |
| `/drop [miktar]` | DL/WL düşür |
| `/pullall` | Herkesi çek |
| `/legend` | Legend title |
| `/maxlevel` | Mavi isim |
| `/mod` / `/modoff` | Mod Detect aç/kapat |

## Proxy Bilgileri

- **Proxy Server:** 195.62.48.50:1234
- **Growtopia IP:** 213.179.209.175:17043

## Discord

discord.gg/ajproxy
