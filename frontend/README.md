# Frontend — HTML + CSS + JS

Derleme adımı, paket yöneticisi ve çerçeve yok. `index.html` çift tıklanarak açılabilir.

## Çalıştırma

```bash
python3 -m http.server 5173 --directory frontend
```

<http://localhost:5173>

## Dosyalar

| Dosya | Sorumluluk |
| --- | --- |
| `index.html` | Sayfa iskeleti |
| `css/stil.css` | Tüm stiller; açık/koyu tema CSS değişkenleriyle |
| `js/duraklar.js` | **Otomatik üretilir** — `node araclar/veri-dagit.js` |
| `js/hesap.js` | Yolculuk hesabı; saf fonksiyonlar, DOM'a dokunmaz |
| `js/uygulama.js` | Arayüz: seçimler, çizim, localStorage |
| `js/firebase-ayar.ornek.js` | Firebase ayar şablonu |

Betikler klasik `<script>` olarak yüklenir (ES modülü değil) — böylece sayfa `file://`
üzerinden, sunucu olmadan da açılabilir.

## Firebase bağlantısı

Site şu an `js/duraklar.js` içindeki yerel veriyle çalışır; Firebase'e ihtiyaç duymaz.
Canlı veriye geçmek için:

```bash
cp frontend/js/firebase-ayar.ornek.js frontend/js/firebase-ayar.js
```

Kendi proje bilgilerinizi yazın (`firebase-ayar.js` `.gitignore` içindedir), `index.html`
içine script etiketini ekleyin ve `uygulama.js` içinde `DURAKLAR` yerine
`${API_ADRESI}/duraklar` çağrısını kullanın.

## Tema

Tema sırası: kullanıcının seçimi (`localStorage`) → işletim sistemi tercihi → açık tema.
Seçim `<html data-tema="acik|koyu">` olarak uygulanır.

## Testler

Hesaplama katmanı Node ile test edilir:

```bash
node araclar/test-hesap.js
```
