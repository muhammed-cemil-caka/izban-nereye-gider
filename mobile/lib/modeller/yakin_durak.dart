import '../servisler/rota_servisi.dart';
import 'durak.dart';

/// Bir konuma en yakın durak ve aradaki mesafe.
class YakinDurak {
  final Durak durak;
  final double mesafeM;

  /// Mesafe hangi kiple ölçüldü? null ise kuş uçuşu.
  ///
  /// Yürüyerek en yakın durak ile arabayla en yakın durak aynı olmayabiliyor;
  /// bu yüzden ölçümün kipi de taşınıyor.
  final RotaKipi? kip;

  const YakinDurak(this.durak, this.mesafeM, {this.kip});

  /// "1,6 km yürüyüş" / "1,6 km araba ile" / "1,6 km"
  String get mesafeKipMetni => switch (kip) {
        RotaKipi.yuruyus => '$mesafeMetni yürüyüş',
        RotaKipi.araba => '$mesafeMetni araba ile',
        null => mesafeMetni,
      };

  /// 450 → "450 m", 2300 → "2,3 km"
  String get mesafeMetni {
    if (mesafeM < 1000) return '${mesafeM.round()} m';
    return '${(mesafeM / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// Verilen konuma en yakın durağı bulur.
  /// Koordinatı olmayan duraklar atlanır; aday yoksa null döner.
  static YakinDurak? bul(List<Durak> duraklar, Konum konum) {
    final liste = enYakinlar(duraklar, konum, adet: 1);
    return liste.isEmpty ? null : liste.first;
  }

  /// Konuma en yakın durakları mesafeye göre sıralı döndürür.
  ///
  /// GPS her zaman isabetli olmadığı için tek bir sonuç dayatmak yerine
  /// kullanıcıya seçenek sunmakta kullanılır.
  static List<YakinDurak> enYakinlar(
    List<Durak> duraklar,
    Konum konum, {
    int adet = 4,
  }) {
    final adaylar = duraklar
        .where((durak) => durak.konum.gecerli)
        .map((durak) => YakinDurak(durak, konum.metreUzaklik(durak.konum)))
        .toList()
      ..sort((a, b) => a.mesafeM.compareTo(b.mesafeM));

    return adaylar.take(adet).toList();
  }
}
