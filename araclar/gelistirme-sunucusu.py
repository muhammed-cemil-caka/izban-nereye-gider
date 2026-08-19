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
import socketserver
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5173
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


if __name__ == "__main__":
    isleyici = functools.partial(OnbelleksizIsleyici, directory=str(KOK))
    with YenidenKullananSunucu(("", PORT), isleyici) as sunucu:
        print(f"İZBAN geliştirme sunucusu: http://localhost:{PORT}")
        print(f"Klasör: {KOK}")
        print("Durdurmak için Ctrl+C")
        try:
            sunucu.serve_forever()
        except KeyboardInterrupt:
            print("\nSunucu durduruldu.")
