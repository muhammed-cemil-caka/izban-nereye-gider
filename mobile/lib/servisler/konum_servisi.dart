import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import '../modeller/durak.dart';

/// Konum isteğinin sonucu — hata durumları çağırana açıkça bildirilir.
sealed class KonumSonucu {
  const KonumSonucu();
}

class KonumBulundu extends KonumSonucu {
  final Konum konum;
  final double dogrulukM;

  const KonumBulundu(this.konum, this.dogrulukM);
}

class KonumHatasi extends KonumSonucu {
  final String mesaj;

  /// Kullanıcı izni kalıcı olarak reddettiyse ayarları açmak gerekir.
  final bool ayarlarGerekli;

  const KonumHatasi(this.mesaj, {this.ayarlarGerekli = false});
}

/// Cihaz konumunu izin akışıyla birlikte alır.
class KonumServisi {
  const KonumServisi();

  static const _zamanAsimi = Duration(seconds: 12);

  Future<KonumSonucu> konumAl() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const KonumHatasi(
        'Cihazın konum servisi kapalı. Ayarlardan açman gerekiyor.',
      );
    }

    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }

    if (izin == LocationPermission.deniedForever) {
      return const KonumHatasi(
        'Konum izni kalıcı olarak reddedilmiş. Uygulama ayarlarından açabilirsin.',
        ayarlarGerekli: true,
      );
    }

    if (izin == LocationPermission.denied) {
      return const KonumHatasi('Konum izni verilmedi.');
    }

    try {
      final yer = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // İlk gelen kaba konum yerine mümkün olan en isabetli ölçüm istenir;
          // en yakın durak hesabı buna dayanıyor.
          accuracy: LocationAccuracy.best,
          timeLimit: _zamanAsimi,
        ),
      );
      return KonumBulundu(
        Konum(enlem: yer.latitude, boylam: yer.longitude),
        yer.accuracy,
      );
    } catch (sorun) {
      return const KonumHatasi('Konum alınamadı, tekrar dener misin?');
    }
  }

  /// Konumu düşük maliyetle izlemeye devam eder.
  ///
  /// [konumAl] tek seferlik ölçüm verir; bu, açılışta hızlı sonuç için doğru
  /// ama harita işaretinin donmasına yol açıyor. Takip açık kalınca işaret
  /// kullanıcıyla birlikte hareket eder. Yönlendirme kendi akışını kullandığı
  /// için takip o sırada durdurulmalıdır.
  Stream<Konum> konumTakibi() {
    // Android aralık verilmezse güncellemeleri eliyor; takipte seyrek ama
    // düzenli ölçüm isteniyor.
    final ayarlar = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 20,
            intervalDuration: const Duration(seconds: 5),
          )
        : const LocationSettings(
            // Takipte yüksek isabet istenmiyor: pil ömrü daha önemli.
            accuracy: LocationAccuracy.medium,
            distanceFilter: 20,
          );

    return Geolocator.getPositionStream(locationSettings: ayarlar)
        .map((yer) => Konum(enlem: yer.latitude, boylam: yer.longitude));
  }

  /// Uygulama ayarlarını açar (izin kalıcı reddedildiğinde).
  Future<void> ayarlariAc() => Geolocator.openAppSettings();
}
