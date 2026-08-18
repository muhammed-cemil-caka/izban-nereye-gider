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
| `js/firebase-ayar.js` | Firebase proje bilgileri (gizli değil, bilerek depoda) |
| `js/firebase-veri.js` | Firestore REST okuma katmanı |
| `js/firebase-ayar.ornek.js` | Başka bir projeye bağlamak isteyenler için şablon |

Betikler klasik `<script>` olarak yüklenir (ES modülü değil) — böylece sayfa `file://`
üzerinden, sunucu olmadan da açılabilir.

## Firebase bağlantısı

Bağlı proje: `izban-nereye-gider`. Sayfa açılırken şu sırayı izler:

1. `js/duraklar.js` içindeki yerel kopyayla **anında** çizer — ağ beklenmez.
2. Firestore REST'ten (`js/firebase-veri.js`) güncel veriyi çeker.
3. Geldiğinde listeyi ve güzergâhı tazeler, alt bilgideki "Kaynak" satırını
   `Firebase` yapar. Seçili duraklar korunur.
4. İstek başarısız olursa yerel kopya kalır, konsola uyarı düşer.

`js/firebase-ayar.js` içindeki değerler **gizli değildir**; web istemcisine zaten açıkta
gider ve yalnızca projeyi tanımlar. Güvenlik sınırı `backend/firestore.rules` dosyasıdır:
`duraklar` ve `hat` herkese okunur, yazma tamamen kapalıdır.

Firebase SDK'sı yerine düz `fetch` ile REST kullanılıyor — böylece paket yöneticisi,
derleme adımı ve CDN bağımlılığı olmadan çalışıyor.

## Tema

Tema sırası: kullanıcının seçimi (`localStorage`) → işletim sistemi tercihi → açık tema.
Seçim `<html data-tema="acik|koyu">` olarak uygulanır.

## Testler

Hesaplama katmanı Node ile test edilir:

```bash
node araclar/test-hesap.js
```
