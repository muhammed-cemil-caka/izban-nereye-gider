#!/usr/bin/env python3
"""
Geliştirme sunucusu — frontend/ klasörünü yayınlar.

    python3 araclar/gelistirme-sunucusu.py [port]

Basit `python3 -m http.server` yerine bu kullanılır: o sunucu önbellek başlığı
göndermediği için tarayıcı düzenlenen dosyaların eski sürümünü tutuyor ve
yapılan değişiklik sayfaya yansımıyor. Burada her yanıta no-store ekleniyor.
"""
import functools
import http.server
import pathlib
import socket
import socketserver
import subprocess
import sys

VARSAYILAN_PORT = 5173
KOK = pathlib.Path(__file__).resolve().parent.parent / "frontend"


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


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else VARSAYILAN_PORT
    isleyici = functools.partial(OnbelleksizIsleyici, directory=str(KOK))

    try:
        sunucu = YenidenKullananSunucu(("", port), isleyici)
    except OSError as hata:
        # errno 48/98: adres kullanımda. Ham yığın izi yerine ne yapılacağını yaz.
        if hata.errno in (48, 98):
            port_dolu_uyarisi(port)
            return 1
        raise

    with sunucu:
        # flush: çıktı bir dosyaya yönlendirildiğinde tamponda kalmasın.
        print(f"İZBAN geliştirme sunucusu: http://localhost:{port}", flush=True)
        print(f"Klasör: {KOK}", flush=True)
        print("Durdurmak için Ctrl+C", flush=True)
        try:
            sunucu.serve_forever()
        except KeyboardInterrupt:
            print("\nSunucu durduruldu.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
