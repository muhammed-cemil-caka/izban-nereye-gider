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
| `lib/servisler/durak_servisi.dart` | Veri kaynağı |
| `lib/ekranlar/ana_ekran.dart` | Arayüz |
| `assets/duraklar.json` | **Otomatik üretilir** — `node araclar/veri-dagit.js` |

## Veriyi Firestore'a taşımak

`DurakServisi.duraklariGetir` gövdesini değiştirmek yeterli; arayüz tarafında hiçbir şey
değişmez. `cloud_firestore` paketini ekleyip:

```dart
final anlik = await FirebaseFirestore.instance
    .collection('duraklar')
    .orderBy('sira')
    .get();
return anlik.docs.map((b) => Durak.jsondan(b.data())).toList();
```

Bunun için önce `flutterfire configure` ile `firebase_options.dart` üretin ve
`main()` içinde `Firebase.initializeApp()` çağırın. Üretilen dosya ve
`google-services.json` / `GoogleService-Info.plist` `.gitignore` içindedir.

## Test edilebilirlik

`AnaEkran` ve `IzbanUygulamasi` isteğe bağlı bir `DurakServisi` alır. Testler
`DurakServisi.hazir([...])` ile hazır veri geçer; böylece widget testleri asset
yüklemesine bağlı kalmaz.
