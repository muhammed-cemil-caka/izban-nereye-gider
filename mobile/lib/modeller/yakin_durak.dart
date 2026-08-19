import 'durak.dart';

/// Bir konuma en yakın durak ve aradaki mesafe.
class YakinDurak {
  final Durak durak;
  final double mesafeM;

  const YakinDurak(this.durak, this.mesafeM);

  /// 450 → "450 m", 2300 → "2,3 km"
  String get mesafeMetni {
    if (mesafeM < 1000) return '${mesafeM.round()} m';
    return '${(mesafeM / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// Durağa yürüyerek yol tarifi için Google Haritalar adresi.
  /// Uygulama kuruluysa uygulamada, değilse tarayıcıda açılır.
  Uri get yolTarifiAdresi => Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${durak.konum.enlem},${durak.konum.boylam}'
        '&travelmode=walking',
      );

  /// Verilen konuma en yakın durağı bulur.
  /// Koordinatı olmayan duraklar atlanır; aday yoksa null döner.
  static YakinDurak? bul(List<Durak> duraklar, Konum konum) {
    YakinDurak? enIyi;

    for (final durak in duraklar) {
      if (!durak.konum.gecerli) continue;

      final mesafe = konum.metreUzaklik(durak.konum);
      if (enIyi == null || mesafe < enIyi.mesafeM) {
        enIyi = YakinDurak(durak, mesafe);
      }
    }

    return enIyi;
  }
}
