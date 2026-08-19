# Mobile — Flutter

İZBAN yolculuk asistanının iOS/Android uygulaması. Material 3, açık/koyu tema.

## Gereksinimler

- Flutter 3.44 veya üzeri (`flutter --version`)
- iOS için Xcode, Android için Android Studio / SDK

## Çalıştırma

```bash
cd mobile
flutter pub get
flutter run
```

Cihaz listesi: `flutter devices`

## Testler

```bash
flutter test
```

```bash
dart analyze
```

> Depo yolunda Türkçe karakter varsa `flutter analyze` çöküyor (analiz sunucusu
> hatası). `dart analyze` aynı işi görür ve etkilenmez.

## Yapı

| Yol | Sorumluluk |
| --- | --- |
| `lib/main.dart` | Uygulama girişi, tema |
| `lib/modeller/durak.dart` | Durak modeli, JSON ayrıştırma |
| `lib/modeller/yolculuk.dart` | Yolculuk hesabı (saf mantık) |
| `lib/servisler/durak_servisi.dart` | Veri kaynağı: önce Firestore, olmazsa yerel |
| `lib/servisler/firestore_veri.dart` | Firestore REST okuma katmanı |
| `lib/servisler/konum_servisi.dart` | GPS izni ve konum alma |
| `lib/modeller/yakin_durak.dart` | En yakın durak ve yol tarifi bağlantısı |
| `lib/firebase_ayari.dart` | Proje kimliği ve API anahtarı (gizli değil) |
| `lib/ekranlar/ana_ekran.dart` | Arayüz |
| `assets/duraklar.json` | **Otomatik üretilir** — `node araclar/veri-dagit.js` |

## Veri kaynağı

Bağlı proje: `izban-nereye-gider`. `DurakServisi.duraklariGetir` şu sırayı izler:

1. `hat/bilgi` belgesini okur (tek belge = tek Firestore okuması).
2. Sürüm `assets/duraklar.json` ile aynıysa yerel kopyayı kullanır — 28 belgelik
   liste indirilmez.
3. Sürüm değişmişse tam listeyi Firestore'dan çeker.
4. Firebase'e hiç ulaşılamazsa yerel kopyayla devam eder.

Böylece uygulama ağ yokken de açılır, veri güncellendiğinde yeni sürüm mağaza
güncellemesi beklemeden gelir ve açılış başına Firestore maliyeti 28 okuma yerine
1 okumada kalır. Ekranın altındaki "Kaynak" satırı hangi yolun kullanıldığını yazar
(`Firebase`, `Firebase (doğrulandı)`, `yerel kopya`).

Firestore'a `cloud_firestore` paketi yerine **REST API** ile erişiliyor
(`lib/servisler/firestore_veri.dart`, tek bağımlılık `http`). Nedeni: uygulamanın
`google-services.json` / `GoogleService-Info.plist` olmadan da çalışması. Okuma
yetkisi kurallarda herkese açık olduğu için kimlik doğrulaması gerekmiyor.

Yazma işlemleri veya kullanıcıya özel veri (favoriler) gerekirse gerçek SDK'ya
geçmek gerekir: `flutterfire configure` ile `firebase_options.dart` üretin,
`main()` içinde `Firebase.initializeApp()` çağırın. Üretilen dosya ve platform
yapılandırma dosyaları `.gitignore` içindedir.

## Test edilebilirlik

`AnaEkran` ve `IzbanUygulamasi` isteğe bağlı bir `DurakServisi` alır. Testler
`DurakServisi.hazir([...])` ile hazır veri geçer; böylece widget testleri asset
yüklemesine bağlı kalmaz.

## Konum izni

Uygulama açılışında konum ister. İzinler manifest dosyalarında tanımlıdır:

- iOS: `NSLocationWhenInUseUsageDescription` — `ios/Runner/Info.plist`
- Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` — `AndroidManifest.xml`

İzin reddedilirse uygulama çalışmaya devam eder, yalnızca en yakın durak kartı
kapanır. Kalıcı reddedilmişse kart "Ayarları aç" düğmesi gösterir.

Testlerde gerçek GPS kullanılmaz: `AnaEkran` ve `IzbanUygulamasi` isteğe bağlı
bir `KonumServisi` alır, testler `KonumBulundu`/`KonumHatasi` döndüren sahte bir
servis geçer.
