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

### Duraklar arası mesafeler

Mesafeler **gerçek ray geometrisi** üzerinden ölçülür:

```bash
node araclar/mesafeleri-guncelle.js        # yalnızca karşılaştırma tablosu
node araclar/mesafeleri-guncelle.js --yaz  # dosyaya yaz
```

Betik İZBAN rota ilişkilerinin yol geometrisini indirir, **üye sırasına göre**
uç uca dizer (yolları Overpass'ın döndürdüğü id sırasıyla eklemek çizgiyi
şehrin içinde ileri geri zıplatıp uzunluğu 2000 km'ye çıkarıyordu), sonra her
durağı bu çizgiye izdüşürüp iki durak arasını çizgi üzerinden ölçer.

Önceki değerler kuş uçuşu mesafenin **1.08** ile çarpımıydı — hattın
kıvrımlarını kaba bir katsayıyla tahmin ediyordu ve uçtan uca **%2,4 fazla**
ölçüyordu:

| | Eski (kuş uçuşu × 1.08) | Yeni (ray üzerinden) |
| --- | --- | --- |
| Aliağa → Selçuk | 137,81 km | **134,60 km** |
| Uçtan uca süre | 151 dk | 148 dk |

Resmî İZBAN uzunluğu ~136 km; ölçülen 134,6 km bununla uyumlu. Bütün duraklar
çizgiye **0 m** uzaklıkta izdüşüyor, yani eşleşme birebir.

**Süreler hâlâ tahminidir:** ölçülen mesafeden sabit hız modeliyle hesaplanır
(65 km/sa + durak başına 0,6 dk), resmî tarife değildir. Model parametreleri
dosyanın `kaynak.sureModeli` alanında yazılıdır.

### ESHOT otobüs aktarmaları

Otobüs verisi ayrı bir betikle tazelenir — tam üretim durak sırasını, ilçeleri
ve süreleri de yeniden hesapladığı için yalnızca otobüs için çalıştırmak
gereksiz risk:

```bash
node araclar/eshot-hatlarini-ekle.js
```

**Tek Overpass isteği** atılır: İzmir çevresindeki bütün `route=bus`
ilişkileri ve üye düğümleri bir kerede indirilir, durak eşleştirmesi yerelde
yapılır. Durağa **400 m**'den yakın bir hattın numarası `otobusHatlari` alanına
yazılır ve `aktarma` listesine "ESHOT" eklenir.

Önce durak başına ayrı sorgu atılıyordu (41 istek). Overpass gönüllü bir servis;
bu tempoyu önce 429 ile karşıladı, sonra bağlantıyı tamamen kesti. Tek istek hem
servise nazik hem de tekrar çalıştırması ucuz.

Neden 400 m: otobüs durakları şehirde çok sık. Raylı aktarmalar için kullanılan
600 m ile neredeyse her İZBAN durağı düzinelerce hat topluyor ve bilgi anlamını
yitiriyor.

**İki kademeli tespit.** Önce yalnızca haritalanmış `route=bus` ilişkilerine
bakılıyordu ve bu, gerçek aktarmaları "yok" gösteriyordu: Torbalı, Pancar,
Gaziemir, Havalimanı, Selçuk gibi duraklarda otobüs durağı var ama İzmir'in
dışında OSM'de çoğu durak hiçbir hat ilişkisine üye değil. Artık:

| Bulunan | Sonuç |
| --- | --- |
| Durağa 400 m'de hat ilişkisi | `ESHOT` + **hat numaraları** |
| Durağa 600 m'de ESHOT durağı | `ESHOT` (numara yok — OSM'de haritalanmamış) |
| Hiçbiri | aktarma yok |

Numara yarıçapı dar (400 m): 600 m'de her durak düzinelerce hat topluyor.
"Durak var mı" sorusu ise 600 m'den soruluyor — raylı aktarmalarla aynı mesafe.
Havalimanı'nın ESHOT durağı (`Havalimanı Dış Hatlar Gidiş`) İZBAN istasyonuna
419 m; 400 m'lik yarıçapta kaçıyordu.

**İşletmeci filtresi:** OSM'de İzmir hatlarının bir kısmında `operator` alanı
"ESHOT" yazıyor, bir kısmında ise bu alan hiç yok. Etiketsizleri elemek gerçek
hatları kaybettiriyor (ör. 535, 912), o yüzden etiketsizler ESHOT sayılıyor.
Açıkça **başka** taşıyıcı olanlar elenir: minibüs/dolmuş kooperatifleri
(`Karşıyaka Minibüs Durakları`), havalimanı servisleri (`HAVAŞ`,
`İzmir Transfer`), turistik seferler (`Bus to Ephesus`).

Sonuç: **41 durağın 34'ünde** ESHOT aktarması var, 21'inde hat numaralarıyla.
Aktarması olmayan 7 durak: Hatundere, İnkılap, Cumaovası, Develi, Tekeli,
Kuşçuburun, Belevi.

### Aktarma listesi en fazla 10 satır

Uzun bir yolculukta yol üstünde 29–34 aktarma noktası oluyor ve kart sayfayı
ekran boyu uzatıyordu. Liste artık kendi içinde kaydırılıyor; altında
"34 aktarma noktası · listeyi kaydırarak devamını gör" yazar.

Pencere iki sınırın küçüğü: **10 satırın yüksekliği** ve **ekranın yarısı**.
İkincisi gerekli — 10 aktarma satırı (durak adı + tür çipleri + hat numaraları)
telefon ekranından uzun. Webde 10 satırın yüksekliği 11. satırın üst kenarı
ölçülerek bulunur (adım listesindeki yöntem), mobilde satır yükseklikleri
değişken olduğu için doğrudan ekran oranı kullanılır.

### Aktarmaları doğrulama

Dosyadaki aktarma bilgisini OSM'e karşı sınar; hiçbir şey yazmaz:

```bash
npm run dogrula
```

Betik sorguyu üretim betiğinden **bağımsız** kurar (tür tür ayrı sorar), böylece
üretimdeki bir sorgu hatası doğrulamada da tekrarlanmaz. Üç şeye bakar: OSM'de
olup dosyada olmayan aktarma (EKSİK), dosyada olup OSM'de olmayan (FAZLA) ve
hat numaralarının tutup tutmadığı. Fark varsa çıkış kodu 1.

Son çalıştırma: **0 eksik, 0 fazla, 0 hat farkı** — 41 durağın hepsi tutuyor.

> Cumaovası'nda bir teşhis sorgusu 119 m'de `operator=Eshot` etiketli adsız bir
> nokta göstermişti ama aynı sorgu başka aynalarda tekrarlanmadı ve doğrulama
> temiz çıkıyor. Aynaların anlık görüntüleri farklı olabiliyor; ileride
> `npm run dogrula` fark bulursa `npm run eshot` ile tazelenir.

**Overpass tuzakları** — üçü de veriyi sessizce bozuyordu, betikte kapatıldı:

- `overpass.osm.ch` yalnızca İsviçre çıkartmasını tutuyor: Türkiye sorgularına
  **200 + boş sonuç** dönüyor, yani "hat yok" gibi görünüyor. Aynalar kaldırıldı,
  tek sunucu (`overpass-api.de`) kullanılıyor.
- Zaman aşımında da **200** dönüyor; hata gövdedeki `remark` alanında yazıyor.
  Böyle yanıtlar başarısız sayılıyor.
- Boş yanıt hiçbir zaman geçerli sayılmıyor. Sorgu çözülemezse dosya
  **hiç yazılmıyor** — var olan veri geçici bir sunucu hatası yüzünden silinmesin.

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
npm start
```

Sonra <http://localhost:5173> adresini açın.

`npm start` yalnızca aşağıdaki betiği çağıran bir kısayoldur — sitenin
bağımlılığı ve derleme adımı yok, `npm install` gerekmez:

```bash
python3 araclar/gelistirme-sunucusu.py
```

Konum servisi güvenli bağlam istediği için HTTPS gereken durumlarda
(Safari, telefondan yerel ağ adresi):

```bash
npm run start:https
```

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

**Webde harita açılış ekranının üstüne taşıyordu.** Leaflet katmanları 200–800
arası `z-index` kullanıyor; harita kabı yığın bağlamı kurmadığı için bu
değerler kök bağlamda geçerli oluyor ve hat çizgisiyle durak işaretleri
kaplamanın üzerine biniyordu. İki yerden düzeltildi: `.harita` artık
`isolation: isolate` ile kendi yığın bağlamını kuruyor, açılış ekranı da
`z-index: 2000` kullanıyor.

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
  Sıralama **ilk ölçümde** devreye girer, kesin ölçüm beklenmez. Önce yalnızca
  "kesin" sayılan ölçümde sıralanıyordu; masaüstünde konum Wi-Fi tabanlı
  olduğu için ±30 m hedefine hiç inilmiyor ve kesin ölçüm ancak 45 saniyelik
  izleme süresi dolunca geliyordu — kullanıcı o zamana kadar kuş uçuşu
  sıralamayı görüyordu. İstek sayısı 150 m'lik tazeleme eşiğiyle sınırlı:
  kullanıcı bu kadar yol yürümedikçe yeni istek gitmez.
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

**Aktarmalar iki yerde yazar.** Güzergâh listesinde aktarmalı duraklarda
"AKTARMA" rozeti, altındaki **"Yol üstündeki aktarmalar"** kartında da hangi
durakta hangi hatlara geçildiği (`Halkapınar — ESHOT · Metro · Tramvay`)
görünür. Mobilde önce yalnızca bir simge vardı ve hat adları ancak simgeye
basılı tutunca çıkan ipucunda görünüyordu; artık iki istemci de aynı bilgiyi
aynı yerde gösteriyor.

**ESHOT aktarmasında hat numaraları da yazar** (`53 · 102 · 154 …`): "ESHOT"
tek başına hangi otobüse binileceğini söylemiyor. Çok hat olan duraklarda ilk
12 tanesi gösterilir, gerisi "+N hat" olarak özetlenir.

**Aktarma türüne dokunmak oraya yönlendirir.** Her tür (Metro, Tramvay, Vapur,
ESHOT) artık bir düğme: basınca kullanıcının **o anki konumundan** aktarma
noktasına yürüyüş rotası çizilir ve canlı yönlendirme kendiliğinden başlar —
ayrıca "Başla"ya basmak gerekmez. Çipte aktarmanın kaç metre uzakta olduğu da
yazar (`Metro 34 m ›`).

Bunun için aktarmanın gerçek noktası gerekiyordu; önce yalnızca etiket vardı
("Metro"), gidilecek bir koordinat yoktu:

```bash
node araclar/aktarma-noktalarini-ekle.js
```

Betik her aktarma türü için durağa **en yakın** noktayı bulup `aktarmaNoktalari`
alanına yazar (ad, koordinat, mesafe). Aynı türden beş kapıyı listelemenin
faydası yok; kullanıcı "metroya nasıl giderim" diye soruyor.

Ölçülen bazı mesafeler: Halkapınar metro **34 m**, tramvay 293 m; Hilal metro
162 m; Karşıyaka tramvay 497 m, vapur 525 m.

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

### Yol tarifi: yürüyerek ve arabayla

Rota, harici bir harita uygulamasına yönlendirmeden **uygulama içinde** çizilir:
mesafe, süre ve Türkçe adım adım tarif (sokak adlarıyla) gösterilir.
Google Haritalar'a yönlendirme kaldırıldı.

**İki kip var.** En yakın durak kartında "Yürüyerek" ve "Arabayla" düğmeleri,
rota kartında da kip değiştirici bulunur; kip değişince aynı hedefe rota
yeniden istenir. Haritada yürüyüş **noktalı turuncu**, araba **düz mavi**
çizilir — hangisine bakıldığı haritadan da anlaşılsın.

| Kip | OSRM profili |
| --- | --- |
| Yürüyerek | `routed-foot/route/v1/foot` |
| Arabayla | `routed-car/route/v1/driving` |

**Adım adım yönlendirme iki kipte de çalışır** — "Başla" araba kipinde de var,
sesli talimatlar da öyle. Kipe göre değişen üç şey var:

| | Yürüyerek | Arabayla |
| --- | --- | --- |
| Harita yakınlığı | 17 | 16 (sonraki kavşak ekrana girsin) |
| Panel etiketi | "toplam yürüyüş" | "toplam sürüş" |
| Kalan süre | rotanın kendi temposundan | aynı |

> Araç içi kullanım sürücünün sorumluluğundadır; uygulama resmî bir navigasyon
> cihazı değildir.

**En yakın durak listesi de kipe göre sıralanır.** "Arabayla" seçilince liste
araba mesafesine, "Yürüyerek" seçilince yürüme mesafesine göre yeniden
sıralanır — ikisi çoğu zaman farklı çıkıyor. Ölçüldü (Halkapınar civarından):

| | En yakın | Sonrakiler |
| --- | --- | --- |
| Yürüyerek | Halkapınar **606 m** | Salhane 2,5 km · Alsancak Gar 2,5 km |
| Arabayla | Hilal **4,4 km** | Halkapınar 4,9 km · Alsancak Gar 4,9 km |

Yaya köprüsünden geçilen durak yürüyerek yakın ama arabayla dolambaçlı; tek
yön ve bölünmüş yollar sıralamayı tamamen değiştiriyor. Mesafeler OSRM'in
matris servisinden, kipin kendi profiliyle tek istekte alınır.

Yönlendirme servisi: [OSRM](https://routing.openstreetmap.de) —
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

**Sesli yönlendirme iki istemcide de var** ve açılıp kapatılabilir:

| | Motor | Anahtar |
| --- | --- | --- |
| Web | Tarayıcının `speechSynthesis` servisi (`tr-TR`) | Panelde "Sesli" kutusu |
| Mobil | `flutter_tts` (`tr-TR`) | Panelde hoparlör düğmesi |

"Başla"ya basıldığı anda ilk talimat okunur — kullanıcı ilk konum ölçümünü
beklemesin. Sonraki talimatlar **adım değiştikçe** okunur: konum saniyede
birkaç kez geliyor, her ölçümde konuşmak aynı cümleyi tekrar tekrar söylemek
olurdu. Hedefe varınca "Vardın." denir.

Cihazda Türkçe ses paketi yoksa ya da motor açılamazsa sessizce vazgeçilir;
yönlendirme sesli olmadan çalışmaya devam eder.

Navigasyon SDK'sı kullanılmıyor — gereken her şey elde: OSRM rota geometrisi,
adımlar ve cihazın konum akışı. Geometri saf fonksiyonlarda tutulur ve
testlidir: `frontend/js/yonlendirme.js` · `mobile/lib/servisler/yonlendirme_servisi.dart`

### Web ve mobil aynı davranışta

Her iki istemcide de: yürüme mesafesine göre en yakın durak, adım adım
yönlendirme, gidiş yönüne dönen harita, ekranda dik duran yön oku, ilerleme
çubuğu, kat edilen yolun soluklaşması, 2 saniye basılı tutunca taşınan konum
iğnesi, konuma dön düğmesi, pusula, canlanan açılış ekranı, açık/koyu tema
düğmesi, aynı marka paleti ve kabartma kutucuklar, en fazla 7 satırlık adım
listesi, yürüyerek/arabayla rota seçimi, kipe göre en yakın durak sıralaması,
ESHOT hat numaraları, aktarmaya dokununca canlı yönlendirme ve sesli
yönlendirme.

**Yalnızca webde olan iki şey var**, ikisi de konumu elle düzeltmekle ilgili:

| | Neden yalnızca webde |
| --- | --- |
| Yer arama (durak/mahalle/cadde → Nominatim) | Masaüstünde konum Wi-Fi tabanlı ve yüz metrelerce şaşabiliyor; telefonda GPS zaten isabetli |
| Elle girilen konumun hatırlanması (`localStorage`) | Aynı sebep |

Mobilde konumu düzeltmenin yolu haritadaki iğneyi 2 saniye basılı tutup
taşımak; o da webde var. Bu iki özelliği mobile de eklemek isterseniz iş
Nominatim araması + `shared_preferences` ile saklama.

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

## Sefer saatleri

Biniş durağından iniş durağına **sıradaki trenler** özet kartının üstünde
gösterilir: kalkış, varış ve "kaç dakika sonra". İlk sefer vurgulanır.

Kaynak: **İzmir Büyükşehir Belediyesi açık veri** —
`openapi.izmir.bel.tr/api/izban/sefersaatleri/{kalkis}/{varis}`. Anahtar
istemiyor, CORS'a açık (`access-control-allow-origin: *`), bu yüzden hem
tarayıcı hem uygulama doğrudan çağırıyor.

İstasyon kimlikleri veriye bir kez yazılır:

```bash
node araclar/izban-kimlik-ekle.js
```

41 durağın 41'i eşleşiyor; ikisi ad farkıyla: "Alsancak Gar" → *Alsancak*,
"Havalimanı" → *Adnan Menderes Havalimanı*.

**Kapsam sınırı:** servis Aliağa – Tepeköy arasını veriyor. Selçuk uzantısında
(Sağlık, Belevi, Selçuk) boş liste dönüyor; uydurma saat basmak yerine
"bu durak çifti için resmî sefer verisi yayınlanmıyor" yazılır.

Tarife gün içinde değişmediği için yanıt oturum boyu saklanır — durak seçimi
her değiştiğinde yeniden istenmez.

## Dil: Türkçe / İngilizce

Üst bantta **TR/EN** düğmesi; seçim `localStorage` (web) ve
`shared_preferences` (mobil) ile hatırlanır. Seçim yoksa cihaz dili kullanılır,
Türkçe değilse İngilizce.

Çevrilen: arayüz metinleri (başlıklar, düğmeler, etiketler, durum mesajları).
**Çevrilmeyen:** durak ve turistik yer adları (özel isim) ve turistik özetler —
metin Türkçe Vikipedi'den geliyor. İngilizce özet istenirse üretim betiğinin
`en.wikipedia.org` özetini de çekmesi gerekir.

Sözlükler: `frontend/js/diller.js` · `mobile/lib/diller.dart` — aynı anahtarlar.
Webde çevrilecek metinler HTML'de `data-ceviri` ile işaretli; mobilde
`Diller.of(context)` ile okunur.

## Gezilecek yerler

Biniş ve iniş durağının çevresindeki tarihi/turistik yerler; her biri fotoğraf,
başlık, kısa tarihçe ve üç yol tarifi düğmesi taşıyan bir kart.

```bash
npm run turistik      # veriyi Wikidata'dan üret
npm run veri          # frontend ve mobile kopyalarını yaz
```

Kaynaklar (üçü de anahtarsız): **Wikidata** (durağa 1500 m'den yakın
tarihi/turistik ögeler), **Vikipedi** (Türkçe özet, CC BY-SA), **Wikimedia
Commons** (fotoğraf + yazar + lisans). Kartta yazar ve lisans gösterilir —
Commons dosyaları bunu zorunlu kılıyor.

Sonuç: **95 yer**, **92'sinde fotoğraf**. Fotoğraf üç kademede aranır:
Wikidata `P18` → Vikipedi makale görseli → Commons'ta ad araması. Sonuncusunda
yanlış fotoğraf riskine karşı dosya adı, yerin adındaki anlamlı kelimelerden en
az ikisini içermek zorunda: yanlış fotoğraf, fotoğrafsızdan kötüdür.

Fotoğrafı olmayan yer ancak Vikipedi makalesi varsa listede kalır; yoksa liste
fotoğrafsız çeşme/türbe kayıtlarıyla doluyor ve kartlar boş görünüyordu.

Kart içi hizalama ızgarayla sabit: başlık iki satır, özet dört satır, düğme ve
kaynak satırı sabit yükseklikte. Serbest akışta özeti olmayan kartta düğmeler
yukarı kayıyor, şeritteki kartlar birbirini tutmuyordu.

Turistik veri `duraklar.json` içine **konmaz**, yanına konur
(`backend/veri/turistik-yerler.json`): durak dosyası OSM'den her üretimde
yeniden yazılıyor, içine konan veri kaybolurdu.

### Yol tarifi: duraktan yere, kipe göre durak

Kartlardaki düğme rotayı kullanıcının konumundan değil **o kipe göre en yakın
duraktan** çizer — kullanıcı oraya İZBAN ile geliyor. Durak seçimi kipin kendi
ağıyla yapılır:

1. Kuş uçuşu **yalnızca ön eleme** (6 aday)
2. OSRM matris servisi, kipin profiliyle tek istekte (`routed-foot` /
   `routed-car`)
3. Sıralama anahtarı **süre** — araçta uzun ama hızlı çevre yol, kısa ama yavaş
   şehir içinden iyi olabiliyor
4. Servis düşerse kuş uçuşu sıralama kalır, akış kesilmez

Ölçüldü: "Hayat Çemberi" Alsancak Gar'a yürüyerek **246 m**, arabayla **3,8 km**
— tek yönler yüzünden.

**Toplu taşıma düğmesi rota çizmez**, aktarma zincirini anlatır: hangi durağa
İZBAN ile gelinir, orada hangi aktarmalar/ESHOT hatları var. Sefer saati
verilmez — OSRM'de toplu taşıma profili yok ve elimizde tarife verisi yok;
uydurulmuş bir süre yolcuyu yanıltır. Ayrıntı:
[`belgeler/turistik-yerler-tasarim.md`](belgeler/turistik-yerler-tasarim.md)

> **Test notu:** `Image.network` widget testlerinde gerçek istek atıyor ve
> `pumpAndSettle` sonsuza kadar bekliyor. Gezi kartını testte çizdirecekseniz
> `HttpOverrides` ile sahte bir istemci gerekiyor; saf mantık
> `test/turistik_servisi_test.dart` içinde ağsız test ediliyor.

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
