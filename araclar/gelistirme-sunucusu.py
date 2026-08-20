#!/usr/bin/env python3
"""
Geliştirme sunucusu — frontend/ klasörünü yayınlar.

    python3 araclar/gelistirme-sunucusu.py [port] [--https]

Basit `python3 -m http.server` yerine bu kullanılır: o sunucu önbellek başlığı
göndermediği için tarayıcı düzenlenen dosyaların eski sürümünü tutuyor ve
yapılan değişiklik sayfaya yansımıyor. Burada her yanıta no-store ekleniyor.

--https: kendinden imzalı sertifikayla HTTPS sunar. Konum servisi yalnızca
güvenli bağlamda çalışır; http://localhost çoğu tarayıcıda güvenli sayılır ama
Safari'de ve telefondan yerel ağ adresiyle bağlanırken HTTPS gerekir.
Sertifika yoksa kendiliğinden üretilir (openssl ile).
"""
import functools
import http.server
import pathlib
import socket
import socketserver
import ssl
import subprocess
import sys

VARSAYILAN_PORT = 5173
KOK = pathlib.Path(__file__).resolve().parent.parent / "frontend"
SERTIFIKA_KLASORU = pathlib.Path(__file__).resolve().parent.parent / ".sertifika"


class OnbelleksizIsleyici(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, bicim, *args):
        # Sessiz kal; yalnızca hataları göster.
        if not str(args[1] if len(args) > 1 else "").startswith("2"):
            super().log_message(bicim, *args)


class YenidenKullananSunucu(socketserver.TCPServer):
    allow_reuse_address = True


def portu_tutan_sureci_bul(port):
    """Portu tutan sürecin kimliğini döndürür; bulunamazsa None."""
    try:
        cikti = subprocess.run(
            ["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN", "-t"],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
        return cikti.split("\n")[0] if cikti else None
    except Exception:
        return None


def bos_port_bul(baslangic):
    """Verilen porttan itibaren ilk boş portu bulur."""
    for port in range(baslangic + 1, baslangic + 20):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(("127.0.0.1", port)) != 0:
                return port
    return None


def port_dolu_uyarisi(port):
    pid = portu_tutan_sureci_bul(port)
    bos = bos_port_bul(port)

    print(f"\n{port} portu zaten kullanımda.\n")
    print("Büyük ihtimalle sunucuyu başka bir terminalde çoktan başlatmışsın.")
    print(f"Öyleyse yapman gereken bir şey yok, site şurada:  http://localhost:{port}\n")
    print("Gerçekten yeniden başlatmak istiyorsan:")
    if pid:
        print(f"  kill {pid}")
    else:
        print(f"  lsof -ti tcp:{port} | xargs kill")
    print("  (ya da o terminalde Ctrl+C)\n")
    if bos:
        print("Yan yana çalıştırmak istersen başka bir port verebilirsin:")
        print(f"  python3 araclar/gelistirme-sunucusu.py {bos}\n")


def yerel_adres():
    """Telefondan bağlanmak için Mac'in yerel ağ adresi."""
    for arayuz in ("en0", "en1"):
        try:
            adres = subprocess.run(
                ["ipconfig", "getifaddr", arayuz],
                capture_output=True, text=True, timeout=3,
            ).stdout.strip()
            if adres:
                return adres
        except Exception:
            pass
    return None


def sertifika_uret(sertifika, anahtar):
    """Kendinden imzalı sertifika üretir; localhost ve yerel ağ adresini kapsar."""
    adlar = ["DNS:localhost", "IP:127.0.0.1"]
    yerel = yerel_adres()
    if yerel:
        adlar.append(f"IP:{yerel}")

    SERTIFIKA_KLASORU.mkdir(exist_ok=True)
    print("Kendinden imzalı sertifika üretiliyor…", flush=True)

    sonuc = subprocess.run(
        [
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
            "-keyout", str(anahtar), "-out", str(sertifika),
            "-days", "365", "-subj", "/CN=localhost",
            "-addext", "subjectAltName=" + ",".join(adlar),
        ],
        capture_output=True, text=True,
    )
    if sonuc.returncode != 0:
        print("Sertifika üretilemedi:", sonuc.stderr.strip()[:300], flush=True)
        return False
    return True


def https_baglami():
    """HTTPS bağlamı hazırlar; sertifika yoksa üretir."""
    sertifika = SERTIFIKA_KLASORU / "sertifika.pem"
    anahtar = SERTIFIKA_KLASORU / "anahtar.pem"

    if not (sertifika.exists() and anahtar.exists()):
        if not sertifika_uret(sertifika, anahtar):
            return None

    baglam = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    baglam.load_cert_chain(certfile=str(sertifika), keyfile=str(anahtar))
    return baglam


def main():
    arguman = [a for a in sys.argv[1:] if not a.startswith("--")]
    https_mi = "--https" in sys.argv

    port = int(arguman[0]) if arguman else VARSAYILAN_PORT
    isleyici = functools.partial(OnbelleksizIsleyici, directory=str(KOK))

    try:
        sunucu = YenidenKullananSunucu(("", port), isleyici)
    except OSError as hata:
        # errno 48/98: adres kullanımda. Ham yığın izi yerine ne yapılacağını yaz.
        if hata.errno in (48, 98):
            port_dolu_uyarisi(port)
            return 1
        raise

    if https_mi:
        baglam = https_baglami()
        if baglam is None:
            sunucu.server_close()
            return 1
        sunucu.socket = baglam.wrap_socket(sunucu.socket, server_side=True)

    protokol = "https" if https_mi else "http"

    with sunucu:
        # flush: çıktı bir dosyaya yönlendirildiğinde tamponda kalmasın.
        print(f"İZBAN geliştirme sunucusu: {protokol}://localhost:{port}", flush=True)
        yerel = yerel_adres()
        if yerel:
            print(f"Telefondan:                 {protokol}://{yerel}:{port}", flush=True)
        if https_mi:
            print("\nSertifika kendinden imzalı: tarayıcı bir kez uyarı gösterir.",
                  flush=True)
            print("'Gelişmiş' → 'Yine de devam et' dediğinde konum servisi çalışır.",
                  flush=True)
        print(f"\nKlasör: {KOK}", flush=True)
        print("Durdurmak için Ctrl+C", flush=True)
        try:
            sunucu.serve_forever()
        except KeyboardInterrupt:
            print("\nSunucu durduruldu.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
