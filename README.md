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
| Önbellek eski, sürüm aynı | **1** (`hat/bilgi`) |
| Sürüm değişmiş | 1 + 28 (tarayıcı başına bir kez) |

Yani sürekli maliyet ziyaret başına 28 okumadan **~0'a** iniyor; tam liste ancak veri
gerçekten güncellendiğinde indiriliyor. Aynı mantık mobilde de var (orada önbellek
uygulama oturumu boyunca bellekte, açılış başına 1 okuma).

Veriyi güncellediğinizde `duraklar.json` içindeki `surum` alanını da artırın —
istemciler yeni veriyi bu alandan anlıyor.

## Veri tek yerden yönetilir

Durak listesi, ilçeler, aktarmalar ve süreler yalnızca şu dosyada tutulur:

```
backend/veri/duraklar.json
```

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

Derleme gerekmez, `frontend/index.html` dosyasını çift tıklayarak açabilirsiniz.
Yerel sunucuyla çalıştırmak için:

```bash
python3 -m http.server 5173 --directory frontend
```

Sonra <http://localhost:5173> adresini açın.

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

## Testler

```bash
node araclar/test-hesap.js
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
