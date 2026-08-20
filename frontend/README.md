# Frontend — HTML + CSS + JS

Derleme adımı, paket yöneticisi ve çerçeve yok. `index.html` çift tıklanarak açılabilir.

## Çalıştırma

```bash
python3 araclar/gelistirme-sunucusu.py
```

Bu betik `Cache-Control: no-store` gönderir; `python3 -m http.server` göndermediği
için tarayıcı düzenlenen dosyaları önbellekte tutuyor ve değişiklikler görünmüyor.

Port doluysa betik ham hata yerine ne yapılacağını yazar: sunucu zaten başka bir
terminalde çalışıyor olabilir. Yan yana çalıştırmak için port verilebilir:

```bash
python3 araclar/gelistirme-sunucusu.py 5174
```

### HTTPS

Konum servisi güvenli bağlam ister. `http://localhost` çoğu tarayıcıda güvenli
sayılır, ama **Safari'de** ve **telefondan yerel ağ adresiyle** bağlanırken
HTTPS gerekir:

```bash
python3 araclar/gelistirme-sunucusu.py --https
```

Kendinden imzalı sertifika ilk çalıştırmada üretilir (`.sertifika/`, depoya
girmez) ve hem `localhost` hem Mac'in yerel ağ adresini kapsar — telefondan da
aynı sertifikayla bağlanılır. Tarayıcı bir kez uyarı gösterir; "Gelişmiş → Yine
de devam et" dendikten sonra konum çalışır.

<http://localhost:5173>

## Dosyalar

| Dosya | Sorumluluk |
| --- | --- |
| `index.html` | Sayfa iskeleti |
| `css/stil.css` | Tüm stiller; açık/koyu tema CSS değişkenleriyle |
| `js/duraklar.js` | **Otomatik üretilir** — `node araclar/veri-dagit.js` |
| `js/hesap.js` | Yolculuk hesabı; saf fonksiyonlar, DOM'a dokunmaz |
| `js/uygulama.js` | Arayüz: seçimler, çizim, localStorage |
| `js/konum.js` | Tarayıcı konum servisi sarmalayıcısı (bekçi zamanlayıcı dahil) |
| `js/harita.js` | Leaflet haritası: hat, duraklar, güzergâh, sürüklenebilir konum |
| `js/rota.js` | OSRM yürüyüş rotası ve manevraların Türkçeleştirilmesi |
| `js/yonlendirme.js` | Adım adım takip: izdüşüm, ilerleme, sapma, sesli yönlendirme |
| `vendor/leaflet/` | Leaflet 1.9.4 (BSD-2-Clause), CDN yerine depoda |
| `js/firebase-ayar.js` | Firebase proje bilgileri (gizli değil, bilerek depoda) |
| `js/firebase-veri.js` | Firestore REST okuma katmanı |
| `js/firebase-ayar.ornek.js` | Başka bir projeye bağlamak isteyenler için şablon |

Betikler klasik `<script>` olarak yüklenir (ES modülü değil) — böylece sayfa `file://`
üzerinden, sunucu olmadan da açılabilir.

## Firebase bağlantısı

Bağlı proje: `izban-nereye-gider`. Sayfa açılırken şu sırayı izler:

1. `js/duraklar.js` içindeki yerel kopyayla **anında** çizer — ağ beklenmez.
2. `localStorage` önbelleği tazeyse (6 saat) hiçbir istek atmaz.
3. Değilse tek belge okur (`hat/bilgi`) ve sürümü yerel kopyayla karşılaştırır.
   Aynıysa iş biter — 28 belgelik liste indirilmez.
4. Sürüm değişmişse tam listeyi çeker, önbelleğe yazar, arayüzü tazeler.
   Seçili duraklar korunur.
5. İstek başarısız olursa yerel kopya kalır, konsola uyarı düşer.

Alt bilgideki "Kaynak" satırı o an hangi yolun kullanıldığını söyler:
`Firebase`, `Firebase (önbellek)` veya `yerel kopya`.

Önbelleği sıfırlamak için tarayıcı konsolunda:

```js
localStorage.removeItem('izban.veriOnbellegi')
```

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

## Önbellek

`index.html` içindeki js/css bağlantıları içerik damgası taşır
(`js/uygulama.js?s=faab2a19`). Dosya değişince damga da değişir ve tarayıcı
yeni sürümü indirmek zorunda kalır. Damgaları tazelemek için:

```bash
node araclar/varlik-damgala.js
```

`veri-dagit.js` bu betiği kendiliğinden çağırır. **Frontend dosyalarını elle
düzenledikten sonra bunu çalıştırın** — yoksa tarayıcı eski sürümü göstermeye
devam eder.

Yayında Firebase Hosting `index.html` için `no-cache`, js/css için 10 dakikalık
önbellek gönderir (`backend/firebase.json`).
