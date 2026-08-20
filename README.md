# İZBAN Nereye Gider?

İZBAN (Aliağa – Selçuk banliyö hattı) için yolculuk asistanı. Biniş ve iniş durağını
seçersin; hangi yöne giden trene bineceğini, kaç durak kaldığını, tahmini süreyi ve
yol üstündeki aktarma noktalarını gösterir.

Tek kod deposunda üç parça:

| Klasör | Ne | Teknoloji |
| --- | --- | --- |
| [`frontend/`](frontend/) | Web arayüzü | HTML + CSS + JavaScript (derleme adımı yok) |
| [`backend/`](backend/) | API ve veri | Firebase (Firestore + Cloud Functions + Hosting) |
| [`mobile/`](mobile/) | Mobil uygulama | Flutter (iOS + Android) |

## Firebase

| | |
| --- | --- |
| Proje kimliği | `izban-nereye-gider` |
| Konsol | https://console.firebase.google.com/project/izban-nereye-gider |
| Firestore konumu | `europe-west1` |
| Web uygulaması | `IZBAN Web` |

Firestore'da `duraklar` (28 belge) ve `hat/bilgi` dolu, güvenlik kuralları yayında:
herkes okur, istemci yazamaz.

**Veri akışı:** hem site hem mobil uygulama açılışta yerel kopyayla anında çizer,
ardından Firestore'dan güncel veriyi çekip arayüzü tazeler. Firestore'a ulaşılamazsa
(ağ yok, kural değişikliği, boş koleksiyon) yerel kopyayla çalışmaya devam eder —
uygulama hiçbir durumda boş ekran göstermez. Arayüzün altındaki "Kaynak" satırı o an
hangisinin kullanıldığını söyler.

Firestore'a Firebase JS/Flutter SDK'sı yerine **REST API** ile erişiliyor; böylece
web tarafında derleme adımı, mobilde de platform yapılandırma dosyası gerekmiyor.

### Okuma bütçesi

Firestore her **belge** için ayrı okuma sayar. 28 duraklık listeyi her ziyarette
çekmek ziyaret başına 28 okuma demektir — Spark planının günlük ~50.000 okumalık
ücretsiz kotası bu hızda ~1.800 ziyarette biter. Durak verisi neredeyse hiç
değişmediği için akış buna göre kuruldu:

| Durum | Firestore okuması |
| --- | --- |
| Tarayıcı önbelleği taze (6 saat) | **0** |
| Önbellek eski, sürüm aynı veya uzaktaki daha eski | **1** (`hat/bilgi`) |
| Firestore'da daha YENİ sürüm var | 1 + durak sayısı (tarayıcı başına bir kez) |

Sürüm karşılaştırması tek yönlüdür: uzaktaki veri yalnızca **daha yeniyse**
kullanılır. Aksi halde uygulama güncellenip veritabanı henüz yüklenmemişken
istemci kendi yeni verisini eskisiyle ezerdi.

Yani sürekli maliyet ziyaret başına 28 okumadan **~0'a** iniyor; tam liste ancak veri
gerçekten güncellendiğinde indiriliyor. Aynı mantık mobilde de var (orada önbellek
uygulama oturumu boyunca bellekte, açılış başına 1 okuma).

Veriyi güncellediğinizde `duraklar.json` içindeki `surum` alanını da artırın —
istemciler yeni veriyi bu alandan anlıyor.

## Veri tek yerden yönetilir

Durak listesi, koordinatlar, ilçeler, aktarmalar ve süreler yalnızca şu dosyada tutulur:

```
backend/veri/duraklar.json
```

Bu dosya elle yazılmaz; OpenStreetMap'ten üretilir:

```bash
node araclar/duraklari-osm-den-uret.js
```

Betik durak sırasını ve koordinatları İZBAN rota ilişkilerinden, aktarmaları
duraklara 600 m'den yakın tramvay/metro/vapur noktalarından (yapım aşamasındakiler
elenir), ilçeleri Nominatim'den alır. Veri **ODbL** lisanslıdır — yayında
"© OpenStreetMap katkıcıları" ibaresi bulunmalıdır.

**Süreler hâlâ tahminidir:** gerçek mesafeden sabit hız modeliyle hesaplanır,
resmî tarife değildir. Model parametreleri dosyanın `kaynak.sureModeli` alanında yazılıdır.

Bu dosyayı değiştirdikten sonra frontend ve mobile kopyalarını üretmek için:

```bash
node araclar/veri-dagit.js
```

Betik `frontend/js/duraklar.js` ve `mobile/assets/duraklar.json` dosyalarını yeniden yazar.
Bu iki dosya otomatik üretilir — elle düzenlemeyin.

Değişikliği Firestore'a da taşımak için (yönetici kimliği gerekir):

```bash
cd backend/functions && GOOGLE_APPLICATION_CREDENTIALS=/yol/anahtar.json node araclar/veri-yukle.js
```

> **Uyarı:** Depodaki durak sırası, ilçe/aktarma bilgileri ve süreler **tahminidir** ve
> resmî kaynak değildir. Yayına almadan önce [izban.com.tr](https://www.izban.com.tr)
> üzerinden doğrulayın.

## Hızlı başlangıç

### Frontend

```bash
python3 araclar/gelistirme-sunucusu.py
```

Sonra <http://localhost:5173> adresini açın.

`python3 -m http.server` yerine bu betik kullanılır: o sunucu önbellek başlığı
göndermediği için tarayıcı düzenlenen dosyaların eski sürümünü tutuyor ve
değişiklikler sayfaya yansımıyor.

`frontend/index.html` çift tıklanarak da açılabilir ama `file://` üzerinde iki
özellik çalışmaz: Firestore isteği CORS'a takılır (yerel kopyaya düşer) ve
**konum servisi devre dışı kalır** — tarayıcılar konumu yalnızca güvenli
bağlamda (https veya localhost) verir.

### Backend

```bash
cd backend/functions && npm install
```

Firebase projesini bağlayın (`.firebaserc.ornek` dosyasını `.firebaserc` adıyla kopyalayıp
proje kimliğinizi yazın), sonra emülatörleri başlatın:

```bash
cd backend && firebase emulators:start --only functions,firestore,hosting
```

Ayrıntılar: [`backend/README.md`](backend/README.md)

### Mobile

```bash
cd mobile && flutter pub get && flutter run
```

Ayrıntılar: [`mobile/README.md`](mobile/README.md)

## Konum ve en yakın durak

Uygulama açılışında konum izni ister, izin verilirse en yakın durağı bulur ve
iki işlem sunar: durağı biniş noktası yapmak, ya da **yürüyüş yol tarifini
uygulamanın kendi haritasında** göstermek. Yol tarifi ayrıca seçili biniş durağı
için de alınabilir, en yakın durakla sınırlı değildir.

### Konum isabeti

Tek bir `getCurrentPosition` çağrısı çoğu zaman ilk gelen kaba konumu döndürür
(Wi-Fi/IP tabanlı, kilometrelerce sapabilir) ve yanlış durağı en yakın gösterir.
Bunun önüne geçmek için:

- Web'de izleme açık tutulur ve konum **zamanla iyileştirilir**: ilk sonuç 6
  saniyede gösterilir, ardından daha isabetli her ölçüm arayüze yansır. ±30 m'ye
  inince izleme durur, en geç 45 saniyede kapanır. Önbellekteki eski konum kabul
  edilmez (`maximumAge: 0`).
- Mobilde `LocationAccuracy.best` istenir.
- Ölçüm doğruluğu ekranda yazar. ±200 m'nin üstündeyse kullanıcı uyarılır.
- Her iki istemcide de **en yakın dört durak** listelenir; GPS şaşarsa kullanıcı
  doğru durağı kendisi seçebilir.
- İlk ölçüm oturduktan sonra **canlı takip** devreye girer: harita işareti
  kullanıcıyla birlikte hareket eder ve en yakın durak sürekli tazelenir.
  Takip düşük isabet/yüksek eşikle çalışır (20 m'den küçük hareketler yok
  sayılır), pil ömrü gözetilir. Kullanıcı konumunu elle belirlerse takip durur —
  yoksa GPS seçimi hemen ezerdi.
- Webde ayrıca **elle düzeltme** vardır: kullanıcı durak, mahalle veya cadde adı
  arayıp konumunu kendisi belirleyebilir. Durak araması yerel veriyle anında
  çalışır (Türkçe karakter yazmaya gerek yok), yer araması Nominatim'e gider.

Elle girilen konum `localStorage`'da saklanır; sonraki açılışlarda tarayıcı
konumu istenmez, doğrudan o kullanılır. "Konumumu yeniden bul" düğmesi kaydı
silip tarayıcı konumuna döner.

**Sınır — masaüstünde GPS yoktur:** Mac ve çoğu dizüstü bilgisayarda GPS alıcısı
bulunmaz. macOS konumu, görünen Wi-Fi ağlarını Apple'ın veritabanında arayarak
tahmin eder; şehir içinde tipik isabet 50–500 metredir. Bu yazılımla aşılamaz,
okunacak bir GPS donanımı yoktur. Gerçek GPS isabeti (5–20 m) yalnızca telefonda
alınır: Flutter uygulaması ya da telefon tarayıcısından açılan **https** adres.
Masaüstü tarayıcıda konum Wi-Fi tabanlıdır ve yüz metrelerce şaşabilir;
telefon uygulamasındaki GPS'e denk isabet beklenmemelidir. Tarayıcı yalnızca
işletim sisteminin verdiği konumu aktarır, bunu iyileştirmek uygulamanın elinde
değildir — bu yüzden elle düzeltme ve alternatif durak listesi eklendi. Tarife için harita SDK'sı veya API anahtarı
kullanılmaz — tek bir bağlantı açılır, navigasyonu Google üstlenir.

İzin reddedilirse uygulama normal çalışmaya devam eder; yalnızca en yakın durak
kartı kapanır ve "Konumumu bul" düğmesi görünür. Konum cihazdan dışarı gönderilmez,
en yakın durak hesabı tamamen istemcide yapılır.

Sık karışan nokta: Chrome adres çubuğunda `http://localhost` için "Güvenli
değil" yazar ama **localhost güvenli bağlam sayılır** ve konum çalışır. Bu yazı
tek başına konum sorununun sebebi değildir; izin reddi ya da işletim sistemi
seviyesinde kapalı konum servisi daha olası sebeplerdir.

Platform notları:

- **Web:** yalnızca `https://` veya `localhost` üzerinde çalışır.
- **iOS:** `NSLocationWhenInUseUsageDescription` (Info.plist).
- **Android:** `ACCESS_FINE_LOCATION` ve `ACCESS_COARSE_LOCATION`.

## Harita

Her iki istemcide de **OpenStreetMap** kullanılır — API anahtarı ve
faturalandırma hesabı gerektirmez.

- **Web:** Leaflet 1.9.4, `frontend/vendor/leaflet/` altında depoda tutulur
  (CDN bağımlılığı yok). Kod: `frontend/js/harita.js`
- **Mobil:** `flutter_map` paketi. Kod: `mobile/lib/ekranlar/harita_karti.dart`

Haritada hat çizilir, 41 durak işaretlenir, seçili güzergâh vurgulanır, biniş
yeşil / iniş turuncu gösterilir. Durağa tıklamak onu biniş durağı yapar.
Kullanıcı konumu **sürüklenebilir** bir işaretle gösterilir — masaüstünde şaşan
tarayıcı konumunu düzeltmenin en doğrudan yolu budur.

### Yürüyüş yol tarifi

Rota, harici bir harita uygulamasına yönlendirmeden **uygulama içinde** çizilir:
mesafe, yürüme süresi ve Türkçe adım adım tarif (sokak adlarıyla) gösterilir.
Google Haritalar'a yönlendirme kaldırıldı.

Yönlendirme servisi: [OSRM](https://routing.openstreetmap.de) yürüyüş profili —
FOSSGIS'in işlettiği ücretsiz topluluk servisi, anahtar istemez. Rota yalnızca
kullanıcı düğmeye bastığında çekilir, kendiliğinden değil.

Kod: `frontend/js/rota.js` · `mobile/lib/servisler/rota_servisi.dart`

### Adım adım yönlendirme

Rota çizildikten sonra **Başla** ile yönlendirme başlar. Uygulama konumu sürekli
dinler ve:

- Kullanıcıyı rota çizgisine izdüşürerek nerede olduğunu bulur
- Sıradaki manevrayı ve ona kalan mesafeyi gösterir
- Kalan toplam mesafeyi ve süreyi günceller
- Haritayı kullanıcıyla birlikte kaydırır ve ona yakınlaşır (mobilde de)
- Yol tarifi alınınca sayfa haritaya kayar ve rota ekrana sığacak şekilde
  çerçevelenir
- **Konum işareti yön okuna dönüşür** ve hareket yönüne göre döner; yönlendirme
  bitince sürüklenebilir iğneye geri döner.

Yön hesabı: **önce ardışık ölçümlerden** (her cihazda güvenilir), cihazın kendi
başlığı yalnızca açıkça geçerliyse (0'dan büyük ve hareket varken). Birçok
Android cihaz "bilinmiyor" yerine 0 döndürüyor; buna güvenmek oku sürekli
kuzeye çeviriyordu. Önceki konum yalnızca açı hesaplandığında güncellenir,
yoksa 5 m'lik eşiğe hiç ulaşılamaz ve küçük adımlar birikmez.
- Rotadan **45 m** uzaklaşıp bu üç ölçüm sürerse rotayı yeniden hesaplar
  (tek bir kötü ölçüm yeniden hesaplamayı tetiklemez)
- Hedefe **25 m** kalınca varış bildirir

Webde ayrıca sesli yönlendirme vardır (tarayıcının kendi konuşma sentezi,
`tr-TR`); açıp kapatılabilir. Mobilde henüz ses yok.

Navigasyon SDK'sı kullanılmıyor — gereken her şey elde: OSRM rota geometrisi,
adımlar ve cihazın konum akışı. Geometri saf fonksiyonlarda tutulur ve
testlidir: `frontend/js/yonlendirme.js` · `mobile/lib/servisler/yonlendirme_servisi.dart`

### Döşeme ve yönlendirme sunucusu uyarısı

`tile.openstreetmap.org` bağışlarla dönen bir altyapıdır ve
[kullanım politikası](https://operations.osmfoundation.org/policies/tiles)
ağır/ticari kullanımı kısıtlar. `flutter_map` paketi de çalışırken bu konuda
uyarı basar. Geliştirme ve düşük trafik için uygundur; **yayına çıkmadan önce**
anahtarlı bir sağlayıcıya (MapTiler, Stadia, Thunderforest) ya da kendi
sunduğumuz döşemelere geçilmelidir.

Aynı uyarı yönlendirme servisi için de geçerlidir: `routing.openstreetmap.de`
ücretsiz bir topluluk servisidir ve ağır kullanıma uygun değildir.

Her iki adres de tek sabitte tutulur, geçiş tek satırdır:

| | Web | Mobil |
| --- | --- | --- |
| Döşeme | `js/harita.js` → `DOSEME_ADRESI` | `harita_karti.dart` → `HaritaKarti.dosemeAdresi` |
| Rota | `js/rota.js` → `ROTA_TABAN` | `rota_servisi.dart` → `RotaServisi._taban` |

Haritada "© OpenStreetMap katkıcıları" ibaresi bulunmak zorundadır.

## Testler

```bash
node araclar/test-hesap.js
```

Durak verisini OpenStreetMap'ten yeniden üretmek için:

```bash
node araclar/duraklari-osm-den-uret.js
```

```bash
cd mobile && flutter test
```

## Bilinen ortam sorunu

Depo yolunda Türkçe karakter varsa (`İZBAN nereye gider` gibi) `flutter analyze`
komutu analiz sunucusuyla konuşurken çöküyor. `dart analyze` ve `flutter test`
etkilenmiyor. Klasörü ASCII bir adla (`izban-nereye-gider`) tutarsanız üçü de çalışır.

## Klasör yapısı

```
.
├── araclar/                 # Yardımcı betikler (veri dağıtımı, testler)
├── backend/                 # Firebase
│   ├── functions/           # Cloud Functions (API)
│   ├── veri/duraklar.json   # TEK DOĞRULUK KAYNAĞI
│   ├── firestore.rules      # Güvenlik kuralları
│   └── firebase.json
├── frontend/                # HTML + CSS + JS
│   ├── css/stil.css
│   ├── js/duraklar.js       # otomatik üretilir
│   ├── js/hesap.js          # yolculuk hesabı
│   ├── js/uygulama.js       # arayüz
│   └── index.html
└── mobile/                  # Flutter
    ├── assets/duraklar.json # otomatik üretilir
    └── lib/
        ├── modeller/
        ├── servisler/
        └── ekranlar/
```
