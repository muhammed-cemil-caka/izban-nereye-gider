# Backend — Firebase

Firestore (veri) + Cloud Functions (API) + Hosting (frontend yayını).

## Gereksinimler

- Node.js 22 (Cloud Functions çalışma zamanı)
- Firebase CLI: `npm install -g firebase-tools`
- Bir Firebase projesi (Blaze planı — Cloud Functions v2 için gerekli)

## Kurulum

1. Bağımlılıklar:

```bash
cd backend/functions && npm install
```

2. Proje bağlantısı — `.firebaserc.ornek` dosyasını kopyalayıp kendi proje kimliğinizi yazın:

```bash
cp backend/.firebaserc.ornek backend/.firebaserc
```

`.firebaserc` `.gitignore` içindedir, depoya gitmez.

3. Giriş:

```bash
firebase login
```

## Yerel çalıştırma (emülatör)

```bash
cd backend && firebase emulators:start --only functions,firestore,hosting
```

| Servis | Adres |
| --- | --- |
| Hosting (frontend) | http://localhost:5000 |
| Functions | http://localhost:5001 |
| Firestore | http://localhost:8080 |
| Emülatör arayüzü | http://localhost:4000 |

Emülatör boş başlar; durak verisini yüklemek için başka bir terminalde:

```bash
cd backend/functions && FIRESTORE_EMULATOR_HOST=localhost:8080 node araclar/veri-yukle.js
```

## Gerçek projeye veri yükleme

Firebase Konsolu → Proje ayarları → Servis hesapları → yeni özel anahtar üretin, sonra:

```bash
cd backend/functions && GOOGLE_APPLICATION_CREDENTIALS=/yol/anahtar.json node araclar/veri-yukle.js
```

Anahtar dosyasını **depoya koymayın**.

## API uç noktaları

Hepsi `GET`. Yayında `/api` altında, yerelde `http://localhost:5001/<proje>/europe-west1/api`.

| Uç nokta | Açıklama |
| --- | --- |
| `/api/saglik` | Servis ayakta mı |
| `/api/duraklar` | Tüm duraklar, kuzeyden güneye sıralı |
| `/api/yolculuk?binis=<kod>&inis=<kod>` | Yön, durak sayısı, süre, güzergâh, aktarmalar |

Örnek:

```bash
curl "http://localhost:5001/PROJE/europe-west1/api/yolculuk?binis=halkapinar&inis=havalimani"
```

## Veri modeli

`duraklar/{kod}` — durak belgeleri:

| Alan | Tip | Açıklama |
| --- | --- | --- |
| `kod` | string | Belge kimliğiyle aynı (`halkapinar`) |
| `ad` | string | Görünen ad (`Halkapınar`) |
| `ilce` | string | İlçe |
| `dakika` | number | Kuzey uçtan (Aliağa) kümülatif dakika |
| `aktarma` | string[] | Aktarma imkânları |
| `sira` | number | Kuzeyden güneye sıra numarası |

`hat/bilgi` — hat özeti (uç duraklar, sürüm, durak sayısı).

`kullanicilar/{uid}/favoriler/{id}` — kullanıcının kaydettiği güzergâhlar (ileride).

## Güvenlik kuralları

`firestore.rules` içinde:

- `duraklar` ve `hat`: herkes okur, kimse yazamaz (yazma yalnızca Admin SDK ile).
- `kullanicilar/{uid}`: yalnızca o kullanıcı okur/yazar.
- Geri kalan her şey kapalı.

Kuralları yayınlamak:

```bash
cd backend && firebase deploy --only firestore:rules
```

## Yayınlama

```bash
cd backend && firebase deploy
```

Yalnızca bir parçayı yayınlamak için: `--only functions`, `--only hosting`, `--only firestore`.

Hosting `../frontend` klasörünü yayınlar ve `/api/**` isteklerini `api` fonksiyonuna yönlendirir.
