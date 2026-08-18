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
| `lib/firebase_ayari.dart` | Proje kimliği ve API anahtarı (gizli değil) |
| `lib/ekranlar/ana_ekran.dart` | Arayüz |
| `assets/duraklar.json` | **Otomatik üretilir** — `node araclar/veri-dagit.js` |

## Veri kaynağı

Bağlı proje: `izban-nereye-gider`. `DurakServisi.duraklariGetir` önce Firestore'u
dener, başarısız olursa `assets/duraklar.json` dosyasına düşer. Böylece uygulama
ağ yokken de açılır, veri güncellendiğinde ise yeni sürüm mağaza güncellemesi
beklemeden gelir. Ekranın altındaki "Kaynak" satırı hangisinin kullanıldığını yazar.

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
