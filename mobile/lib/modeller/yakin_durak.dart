import '../diller.dart';
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

  /// "1,6 km yürüyüş" / "1.6 km walk"
  String get mesafeKipMetni => switch (kip) {
        RotaKipi.yuruyus =>
          Diller.aktif('mesafeYuruyus', {'mesafe': mesafeMetni}),
        RotaKipi.araba =>
          Diller.aktif('mesafeAraba', {'mesafe': mesafeMetni}),
        null => mesafeMetni,
      };

  /// 450 → "450 m", 2300 → "2,3 km" / "2.3 km"
  String get mesafeMetni {
    final ceviri = Diller.aktif;
    if (mesafeM < 1000) return '${mesafeM.round()} ${ceviri('birimM')}';
    // Ondalık ayracı dile göre: Türkçede virgül, İngilizcede nokta.
    var deger = (mesafeM / 1000).toStringAsFixed(1);
    if (ceviri.kod != 'en') deger = deger.replaceAll('.', ',');
    return '$deger ${ceviri('birimKm')}';
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
