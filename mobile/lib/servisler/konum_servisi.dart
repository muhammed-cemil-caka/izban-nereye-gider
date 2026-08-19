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
          accuracy: LocationAccuracy.high,
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

  /// Uygulama ayarlarını açar (izin kalıcı reddedildiğinde).
  Future<void> ayarlariAc() => Geolocator.openAppSettings();
}
