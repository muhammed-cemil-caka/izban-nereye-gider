# Yayına çıkış

Sırayla. Her adımın sonunda çalışır bir şey var.

## 1. Web — bugün yapılabilir

```bash
cd backend
npm --prefix functions install
firebase login
firebase deploy --only hosting,functions
```

Bittiğinde site `https://izban-nereye-gider.web.app` adresinde.

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

Ortak:

- Uygulama adı ve ikon: `android:label` hâlâ `izban_nereye_gider`, ikon
  Flutter varsayılanı.
- **Marka:** paket adı `com.izban.*`, uygulama adı ve logo İZBAN'a ait.
  İzin almadan mağazaya çıkmak kaldırılma riski taşır. Ya izin al, ya kendi
  adın ve logonla çık.
- Gizlilik politikası URL'si (konum izni var) — Hosting'e bir sayfa koy yeter.

Play Store:

```bash
cd mobile
flutter build appbundle --release
```

Önce imzalama: `android/app/build.gradle.kts` içindeki `release` bloğu hâlâ
debug anahtarıyla imzalıyor. Kendi keystore'unu üret, `key.properties` ile bağla.

App Store: macOS + Xcode, `flutter build ipa`, yıllık 99 $ Apple Developer
hesabı. Bundle id hazır (`com.izban.izbanNereyeGider`).

## 5. Yayın sonrası

- `npm run sefer-dogrula` — sefer motorunu canlı servise karşı denetler
- `npm run logo-dogrula` — logo geometrisi
- `node araclar/turistik-mesafeleri-uret.js --yaz && node araclar/veri-dagit.js`
  — turistik yer eklenirse mesafeleri tazele
