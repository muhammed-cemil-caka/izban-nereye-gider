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

## Marka ve görünüm

### Logo

İZBAN markası **vektör olarak yeniden üretildi**: resmî logonun 240x240'lık
PNG'si piksel piksel ölçüldü (halka orta yarıçapı, yayların açıları ve uca
doğru incelmesi, kelimenin konumu, renkler) ve 200'lük bir kareye ölçeklendi.
Renkler resmî dosyadan örneklendi: **#ED1B24** kırmızı, **#0C4CA3** mavi.

```bash
python3 araclar/logo-uret.py
```

Betik iki yere yazar:

| Hedef | Ne için |
| --- | --- |
| `frontend/gorseller/izban-logo.svg` | Duran kopya — üst bantta `<img>` ile |
| `frontend/index.html` (işaretler arası) | Açılış ekranındaki **canlanan** kopya |

İkisi de otomatik üretilir, elle düzenlenmez. Canlanan kopyanın satır içi
olması gerekiyor: CSS ile canlandırılabilmesi için. Mobilde aynı geometri
`mobile/lib/ekranlar/izban_logosu.dart` içinde `CustomPaint` ile çizilir —
görsel dosya yok, her çözünürlükte keskin ve çizilerek canlanabiliyor.

Yaylar **sabit kalınlıkta değil**, keskin uçtan sönük uca doğru incelir
(34 → 6 birim). Bu yüzden basit bir çizgi (`stroke`) olarak çizilemiyorlar;
dolu bir yol olarak üretilip webde maskeyle, mobilde de kısmi yol üreterek
süpürülüyorlar.

Kelimenin genişliği webde `textLength`, mobilde yatay ölçekle **sabitlenir**:
cihazın yazı tipi değişse de marka kilidi bozulmaz. Sistem yazı tipi resmî
logodaki kadar kalın olmadığı için harflere ince bir çizgi eklenir.

Logo hem açılış ekranında hem de ana sayfada başlığın yanında durur. Her iki
yerde de **beyaz bir plakanın** üstündedir: marka renkleri koyu temada okunur
kalsın diye.

### Açılış ekranı

Uygulama açılırken marka **çizilerek** gelir: plaka yerine oturur, iki yay orta
çizgileri boyunca süpürülerek açılır (mavi olan biraz geriden), sonra kelime
belirir. Toplam ~2 saniye; dokunmak/tuşa basmak hemen geçer, hareket azaltma
açıksa süre kısalır.

Ekran, uygulamanın **üstünde** durur — altında değil. Sayfa/uygulama arkada
veriyi okuyup konumu istemeye başlar, kullanıcı animasyonu beklemez.

Mobilde zamanlamanın tamamı tek bir `AnimationController`'a bağlı,
zamanlayıcıya değil: widget testleri `pumpAndSettle` ile animasyonu sonuna
kadar sarabiliyor. Zamanlayıcı kullanılsaydı açılış ekranı testlerde açık
kalır ve ana ekranı gölgelerdi.

Kod: `frontend/css/stil.css` (`.acilis*`) · `mobile/lib/ekranlar/acilis_ekrani.dart`

### Renk paleti ve kabartma kutucuklar

Palet markadan geliyor; yön renkleri de öyle — **kuzey mavi, güney kırmızı**.
Kutucukların 3 boyutlu görünümü üç katmandan oluşur ve tema değişince üçü
birlikte değişir:

| Katman | Web değişkeni | Mobil karşılığı |
| --- | --- | --- |
| Yüzey eğimi | `--kutu-yuzey` | `KabarikKutu` gradyanı |
| Üst kenardaki ışık | `--kabartma` | gradyanın açık ilk durağı |
| Altındaki katmanlı gölge | `--golge` | `CardTheme.shadowColor` + `BoxShadow` |

Mobilde yuvarlatılmış kenarda Flutter tek renk kenar istiyor; üstteki ışık
hissi bu yüzden kenardan değil gradyandan geliyor.

### Tema (açık / koyu)

Her iki istemcide de üst bantta bir düğme var ve seçim kalıcı:

- **Web:** `localStorage` (`izban.tema`), seçim yapılmadıysa işletim sistemi
  tercihi geçerli.
- **Mobil:** `shared_preferences` (`izban.tema`), `ThemeMode` olarak saklanır.
  Eklenti yoksa (widget testleri) sessizce sistem temasına düşer.

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
- Sıralama **gerçek yürüme mesafesine** göre yapılır, kuş uçuşuna göre değil.
  Kuş uçuşu yanıltıyor: dere, otoyol veya demiryolu araya girdiğinde yakın
  görünen durak yürüyerek çok daha uzak olabiliyor. Ölçüldü: Çiğli kuş uçuşu
  daha yakın ama yürüyüşle **2,5 km**; Mavişehir **1,4 km**. Mesafeler OSRM'in
  matris servisiyle **tek istekte** alınır (hedef başına ayrı rota istenmez).
  Kuş uçuşu sıralama anında gösterilir, yürüme mesafesi gelince düzeltilir.
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

**Katkı ibaresi haritanın üstünde değil altındadır.** Leaflet'in ve
`flutter_map`'in kendi katkı kutusu haritanın sağ alt köşesini kapatıyordu;
kutu kapatıldı (`attributionControl: false` / `RichAttributionWidget`
kaldırıldı) ve ibare kartın içine, haritanın hemen altına alındı. İbare
**kaldırılamaz**: veri ODbL lisanslı, gösterilmesi zorunlu.

Haritada hat çizilir, 41 durak işaretlenir, seçili güzergâh vurgulanır, biniş
yeşil / iniş turuncu gösterilir. Durağa tıklamak onu biniş durağı yapar.
Kullanıcı konumu **sürüklenebilir** bir işaretle gösterilir — masaüstünde şaşan
tarayıcı konumunu düzeltmenin en doğrudan yolu budur.

Konum iğnesi yalnızca **2 saniye basılı tutunca** taşınabilir. Sürekli
açık olması, haritayı kaydırırken parmağın işarete değmesiyle konumun
yanlışlıkla değişmesine yol açıyordu. Webde işaret hazır olunca parlar,
mobilde titreşimle haber verilir ve iğne renk değiştirir.

**Taşıma neden hazır sürükleme bileşenleriyle yapılmıyor:** her iki tarafta da
"iki saniye bekle, sonra sürükle" hareketi hiç başlamıyordu.

- *Mobilde* `LongPressDraggable`, jest arenasında `FlutterMap`'in kendi
  `LongPressGestureRecognizer`'ıyla yarışıyor. O tanıyıcı **500 ms**'de jesti
  kazanıyor, arena çözülünce 2 saniyelik sürükleyici reddediliyor ve iğne hiç
  kımıldamıyor.
- *Webde* `marker.dragging.enable()` yalnızca **bundan sonraki** basışı
  yakalıyor. İki saniye dolduğunda parmak zaten basılı olduğu için sürükleme
  o hareket boyunca hiç başlamıyor; kullanıcının bırakıp yeniden basması
  gerekiyordu.

Taşıma bu yüzden iki tarafta da ham işaretçi olaylarıyla yürütülüyor (mobilde
`Listener`, webde `pointerdown/move/up`) — arenaya girmedikleri için jesti
kimin kazandığından etkilenmiyorlar. Parmağın altındaki nokta doğrudan
alınmaz, basılan noktadan itibaren **fark** uygulanır: iğne ele alınır almaz
zıplamaz. İki saniye basıp hiç oynatmadan bırakmak konumu değiştirmez.

Konum iğnesinin **ucu** konumu gösterir (`Marker.alignment: topCenter`).
Varsayılan hizalama işareti noktanın ortasına koyuyor; o zaman uç aşağıda
kalıyor ve yakınlaştırma değiştikçe kayma büyüyor. Webde Leaflet'in
varsayılan `iconAnchor: [12, 41]` değeri zaten ucu işaret ediyor.

### Konuma dön düğmesi

Haritanın sağ üst köşesindeki hedef simgesi kamerayı kullanıcının konumuna
geri getirir. Hattın başka bir yerine bakmak için harita kaydırıldığında geri
dönmek için elle kaydırmak gerekmiyor. Konum bilinmiyorsa düğme görünmez.
Kendiliğinden gelen ölçümler için konulan gürültü eşiği (8 m) bu düğmeye
uygulanmaz: basıldığında kamera her hâlükârda konuma döner.

### Yürüyüş yol tarifi

Rota, harici bir harita uygulamasına yönlendirmeden **uygulama içinde** çizilir:
mesafe, yürüme süresi ve Türkçe adım adım tarif (sokak adlarıyla) gösterilir.
Google Haritalar'a yönlendirme kaldırıldı.

Yönlendirme servisi: [OSRM](https://routing.openstreetmap.de) yürüyüş profili —
FOSSGIS'in işlettiği ücretsiz topluluk servisi, anahtar istemez. Rota yalnızca
kullanıcı düğmeye bastığında çekilir, kendiliğinden değil.

Kod: `frontend/js/rota.js` · `mobile/lib/servisler/rota_servisi.dart`

### Adım listesi en fazla 7 satır

Yol tarifi alınınca adımlar ("sola dön", "sağa dön") kartın içinde listelenir.
Uzun bir yürüyüşte bu liste sayfayı metrelerce uzatıyor, altındaki her şey
aşağı kaçıyordu. Liste artık **kendi içinde kaydırılır** ve aynı anda en fazla
**7 adım** görünür; altında "12 adım · listeyi kaydırarak devamını gör" yazar.

Yükseklik sabit piksel değil:

- *Webde* 8. adımın üst kenarı ölçülüp yükseklik ondan hesaplanır — adım metni
  sarıp iki satır olsa da tam 7 adımlık pencere kalır (`--adim-yukseklik`).
- *Mobilde* satır yüksekliği `TextPainter` ile ölçülür; yazı boyutunu büyüten
  kullanıcıda da pencere tam 7 adım kalır.

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

**Android konum aralığı:** birleşik konum sağlayıcısı, aralık açıkça
verilmezse güncellemeleri eliyor (`location delivery blocked - too fast/too
close`) ve yürüyüş hızında imleç hiç kıpırdamıyor. Yönlendirmede
`AndroidSettings(distanceFilter: 0, intervalDuration: 1 sn)`, takipte 5 sn
kullanılıyor. Ayrıca iki konum akışı aynı anda çalışmıyor: yönlendirme
başlayınca takip kapatılıyor.

**Pusula:** telefon çevrildiğinde ok da dönsün diye manyetometre dinleniyor
(`flutter_compass`). Pusula yoksa hareket yönüne düşülür. Dinleme **okun kendi
içinde** yapılır: aksi halde her küçük dönüş tüm ekranı yeniden çizdiriyor ve
harita saniyede birkaç kez kendini yeniliyordu.

**Kamera:** yönlendirme sırasında her ölçümde doğrudan `move` çağırmak haritayı
zıplatıyordu; hareket araya animasyon konarak yumuşatılıyor.

**Ekran yenilenmesi (mobil):** konum saniyede birkaç kez değişiyor ve bunu
`setState` ile taşımak tüm ekranı — dolayısıyla `FlutterMap` ve döşeme
katmanını — yeniden kuruyordu; kullanıcıya ekran sürekli yenileniyormuş gibi
görünüyordu. Konum ve yönlendirme durumu artık `ValueNotifier` ile taşınıyor:
harita widget'ı sabit kalıyor, yalnızca işaret katmanı, rota katmanı ve
yönlendirme paneli kendi `ValueListenableBuilder`'larıyla tazeleniyor. Kamera
hareketi de imperatif olarak yapılıyor, yeniden çizim gerektirmiyor.

**GPS gürültüsü:** cihaz dururken bile konum birkaç metre oynar. Her ölçümde
kamerayı taşımak haritayı sürekli ileri geri kaydırıyordu. Kamera yalnızca
kullanıcı son hedeften **12 m**'den fazla uzaklaşınca taşınıyor.

**Sabit panel yüksekliği:** yönlendirme talimatı bazen bir, bazen iki satır
oluyordu; kartın boyu değiştikçe altındaki her şey oynuyordu. Talimat alanı
iki satırlık sabit yükseklikte.

**İlerleme görünürlüğü:** kamera kullanıcıyı ortada tuttuğu için ok sabit
duruyormuş gibi görünüyordu. Yürüyüş rotasının kat edilen kısmı artık
soluklaştırılıyor; kalan kısım canlı renkte kalıyor. Panelde ayrıca
"Yürüdüğün: X m" gösteriliyor — bu sayının artması konumun güncellendiğinin
doğrudan kanıtı.

**Kalan süre:** sabit yürüyüş hızı varsayılmıyor; servisin o rota için
öngördüğü tempo (`sureSn / mesafeM`) kalan mesafeye uygulanıyor.

Yön hesabı: **önce ardışık ölçümlerden** (her cihazda güvenilir), cihazın kendi
başlığı yalnızca açıkça geçerliyse (0'dan büyük ve hareket varken). Birçok
Android cihaz "bilinmiyor" yerine 0 döndürüyor; buna güvenmek oku sürekli
kuzeye çeviriyordu. Önceki konum yalnızca açı hesaplandığında güncellenir,
yoksa 5 m'lik eşiğe hiç ulaşılamaz ve küçük adımlar birikmez.
- Rotadan uzaklaşınca rotayı yeniden hesaplar. Eşik sabit değil, **ölçüm
  doğruluğuna göre genişler** (`max(60 m, doğruluk × 3)`): şehirde GPS ±20-30 m
  şaşabildiği için dar bir eşik, kullanıcı rota üzerinde yürürken bile
  "rotadan çıktın" demeye yol açıyordu. Sapmanın **beş ölçüm** üst üste sürmesi
  ve son yeniden hesaplamadan **20 saniye** geçmiş olması gerekir
- Yeniden hesaplama sırasında **kamera kullanıcıda kalır**; rotayı çerçevelemek
  için uzaklaşmaz, harita boyut değiştirmiş gibi görünmez
- Rotadan çıkma algılandığında **eski oturum hemen kapatılır**. Yoksa yeni rota
  beklenirken gelen ölçümler üst üste yeni istekler tetikliyor ve uyarı yanıp
  sönüyordu
- Sapma **tek ölçümle değil son beş ölçümün ortalamasıyla** değerlendirilir;
  şehirde sık görülen tek bir kötü ölçüm yeniden hesaplama tetiklemez
- Yeniden hesaplama **sessizdir**: uyarı basılmaz. Kısa süre sonra kaybolan
  uyarı ekranda yanıp sönüyordu; Google Haritalar da sessizce yeniden hesaplar
- Yönlendirme panelinde **ilerleme çubuğu** ve "540 m / 1,4 km toplam yürüyüş"
  gösterilir; toplam yürünecek mesafe her an görünür
- Harita **gidiş yönüne çevrilir**: kullanıcının baktığı yön yukarı bakar, ok
  ekranda sabit dik durur (`Marker(rotate: true)`). Yön için önce pusula,
  yoksa hareket yönü kullanılır; 8°'den küçük oynamalarda harita döndürülmez ve dönüş en kısa yönden,
  yarım saniyelik animasyonla yapılır — doğrudan çevirmek takılmalı
  görünüyordu.
  Yönlendirme bitince harita kuzey yukarı konumuna döner
- Doğruluk uyarısı histerezisli: 100 m'de çıkar, 70 m'nin altına inince
  kaybolur; tek eşik sınırda gezinirken uyarıyı yanıp söndürüyordu
- Panelde **"Yürüdüğün: X m · Y km/sa"** gösterilir. Kamera kullanıcıyı ortada
  tuttuğu için ok sabit duruyormuş gibi görünür; bu iki değer hareketin
  algılandığının doğrudan kanıtıdır
- Hedefe **25 m** kalınca varış bildirir

Webde ayrıca sesli yönlendirme vardır (tarayıcının kendi konuşma sentezi,
`tr-TR`); açıp kapatılabilir. Mobilde henüz ses yok.

Navigasyon SDK'sı kullanılmıyor — gereken her şey elde: OSRM rota geometrisi,
adımlar ve cihazın konum akışı. Geometri saf fonksiyonlarda tutulur ve
testlidir: `frontend/js/yonlendirme.js` · `mobile/lib/servisler/yonlendirme_servisi.dart`

### Web ve mobil aynı davranışta

Her iki istemcide de: yürüme mesafesine göre en yakın durak, adım adım
yönlendirme, gidiş yönüne dönen harita, ekranda dik duran yön oku, ilerleme
çubuğu, kat edilen yolun soluklaşması, 2 saniye basılı tutunca taşınan konum
iğnesi, konuma dön düğmesi, pusula, canlanan açılış ekranı, açık/koyu tema
düğmesi, aynı marka paleti ve kabartma kutucuklar, en fazla 7 satırlık adım
listesi.

Leaflet haritayı döndürmeyi yerleşik desteklemediği için web tarafında
`leaflet-rotate` eklentisi kullanılır (`frontend/vendor/leaflet/`, MIT).
İşaret `leaflet-norotate-pane` içinde durduğu için harita dönerken ok
ekranda dik kalır — mobildeki davranışın aynısı.

Kamera hareketi her iki tarafta da **sürekli takip** ile yumuşatılır: her
ölçümde yeni animasyon başlatmak hızı sıfırlayıp takılma hissi veriyordu.
Mobilde `Ticker` ile üstel yumuşatma, webde `requestAnimationFrame` ile
aynı yaklaşım kullanılır.

**Yakınlık da yumuşatılır.** Önce yalnızca merkez yumuşatılıyordu; "Başla"ya
basıldığında harita bir anda 17'ye sıçrıyor, ilk hareket de animasyonsuz
yapılıyordu. Artık merkez ve yakınlık aynı üstel eğriyle birlikte akıyor,
"Başla" tek bir yumuşak yaklaşma hareketi oluyor. Webde bunun için
`zoomSnap: 0` gerekiyor: Leaflet varsayılan olarak yakınlığı tam sayıya
yuvarlar ve geçiş basamak basamak görünürdü.

İki koruma var: kullanıcı haritayı **kendi kaydırırsa** takip hedefi düşer
(kamera onu geri çekmeye çalışmaz, sonraki ölçümde yeniden kurulur) ve hedef
**3 km'den uzaksa** animasyon yapılmaz — kamera yol boyunca bütün döşemeleri
isterdi.

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
│   ├── gorseller/           # izban-logo.svg — otomatik üretilir
│   ├── js/duraklar.js       # otomatik üretilir
│   ├── js/hesap.js          # yolculuk hesabı
│   ├── js/uygulama.js       # arayüz
│   └── index.html
└── mobile/                  # Flutter
    ├── assets/duraklar.json # otomatik üretilir
    └── lib/
        ├── modeller/
        ├── servisler/
        └── ekranlar/        # ana_ekran · harita_karti · acilis_ekrani · izban_logosu
```
