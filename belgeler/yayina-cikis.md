# Yayına çıkış

Sırayla. Her adımın sonunda çalışır bir şey var.

## 1. Web — YAYINDA

Site: **https://izban-nereye-gider.web.app**

`firebase.json` ve `.firebaserc` **depo kökünde** (bkz.
`backend/OKUBENI-yapilandirma.md`). Komutlar kökten çalıştırılır:

```bash
npm --prefix backend/functions install
firebase deploy --only hosting
```

**Fonksiyonlar henüz yayında değil:** Cloud Functions v2, projenin Blaze
(kullandıkça öde) planında olmasını istiyor. Vekil uçları o zamana kadar
kapalı; istemciler bunu yokluyor ve doğrudan dış servise gidiyor, uygulama
sorunsuz çalışıyor. Blaze'e geçince:

```bash
firebase deploy --only functions
```

Neyin yayına gittiği:

| Parça | Nerede |
| --- | --- |
| Site | Firebase Hosting, `frontend/` |
| API + vekiller | Cloud Functions, `europe-west1` |
| Durak/hat verisi | Firestore (yerel kopya yedek) |

**Doğrulama:**

```bash
curl -s https://izban-nereye-gider.web.app/api/saglik
curl -sI https://izban-nereye-gider.web.app/api/sefer/45/48 | grep -i cache-control
```

İkincisi `public, max-age=21600...` dönmeli — CDN önbelleği çalışıyor demektir.

## 2. Döşeme sağlayıcısı — canlıda kalmanın şartı

`tile.openstreetmap.org` bağış altyapısı; kullanım politikası üretim
kullanımını dışlıyor. Trafik artınca Referer üzerinden engellenirsin.

Adres iki yerde, tek satır:

- `frontend/js/harita.js` → `DOSEME_ADRESI`
- `mobile/lib/ekranlar/harita_karti.dart` → `HaritaKarti.dosemeAdresi`

Seçenekler:

| Yol | Not |
| --- | --- |
| MapTiler / Stadia / Thunderforest | Hesap aç, anahtarı adrese koy, panelden HTTP referrer kısıtı ekle |
| Kendi PMTiles'ın | Türkiye çıkarımı tek dosya, R2/Storage'a konur. İstek başına ücret yok |

Anahtarın adreste görünmesi normaldir; koruma referrer kısıtıyla yapılır.

## 3. Firebase paneli

- **API anahtarı kısıtı:** Google Cloud Console → Credentials → web anahtarı →
  HTTP referrer kısıtı olarak kendi alan adın.
- **Firestore kuralları** zaten sıkı (`allow write: if false`), dokunma.
- **Bütçe uyarısı:** Billing → Budgets & alerts. Aylık bir tavan koy.

## 4. Mobil mağazalar

### Hazır olanlar

- Uygulama adı: `İZBAN Nereye Gider?` (önce teknik ad görünüyordu)
- Başlatıcı simgesi: `python3 araclar/uygulama-simgesi-uret.py` ile logodan
  üretildi; Play Console listeleme simgesi de hazır
  (`mobile/android/app/src/main/ic_launcher-playstore.png`, 512×512)
- `targetSdk 36` — Play'in güncel eşiğini karşılıyor
- AAB üretimi çalışıyor, R8 küçültme açık
- İmza bağlantısı kurulu: `android/key.properties` varsa kullanılır

### Sende kalanlar

**1. İmza anahtarı.** Parola gerektirdiği için bunu sen üretmelisin:

```bash
keytool -genkey -v -keystore ~/izban-yayin.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias izban
```

Sonra `mobile/android/key.properties`:

```
storeFile=/Users/<kullanici>/izban-yayin.jks
storePassword=...
keyAlias=izban
keyPassword=...
```

Dosya `.gitignore`'da. **Anahtarı kaybetme:** ilk yüklemeden sonra aynı
anahtarla imzalamak zorundasın, yoksa güncelleme yayımlayamazsın.

```bash
cd mobile && flutter build appbundle --release
```

**2. Marka.** Paket adı `com.izban.*`, uygulama adı ve logo İZBAN'a ait.
İzin almadan mağazaya çıkmak kaldırılma riski taşır. Ya izin al, ya kendi adın
ve logonla çık.

**3. Gizlilik politikası URL'si** (konum izni var) — Hosting'e bir sayfa koymak
yeterli. **Data safety** formu da doldurulacak.

App Store: macOS + Xcode, `flutter build ipa`, yıllık 99 $ Apple Developer
hesabı. Bundle id hazır (`com.izban.izbanNereyeGider`).

## 5. Yayın sonrası

- `npm run sefer-dogrula` — sefer motorunu canlı servise karşı denetler
- `npm run logo-dogrula` — logo geometrisi
- `node araclar/turistik-mesafeleri-uret.js --yaz && node araclar/veri-dagit.js`
  — turistik yer eklenirse mesafeleri tazele
