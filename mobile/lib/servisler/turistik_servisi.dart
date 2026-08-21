import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../modeller/turistik_yer.dart';

/// Turistik yerleri assets/turistik-yerler.json dosyasından okur.
///
/// Durak verisinden ayrı dosya: duraklar.json OSM'den her üretimde yeniden
/// yazılıyor, turistik veri onun içinde kaybolurdu.
class TuristikServisi {
  static const _dosya = 'assets/turistik-yerler.json';

  final List<TuristikYer>? _hazir;

  const TuristikServisi() : _hazir = null;

  /// Testler hazır liste geçebilir.
  const TuristikServisi.hazir(List<TuristikYer> yerler) : _hazir = yerler;

  Future<List<TuristikYer>> yerleriGetir() async {
    final hazir = _hazir;
    if (hazir != null) return hazir;

    try {
      final ham = await rootBundle.loadString(_dosya);
      final govde = jsonDecode(ham) as Map<String, dynamic>;
      return (govde['yerler'] as List<dynamic>)
          .map((y) => TuristikYer.jsondan(y as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Dosya yoksa uygulama turistik bölüm olmadan çalışmaya devam eder.
      return const [];
    }
  }

  /// Bir durağın çevresindeki yerler, yakından uzağa.
  static List<({TuristikYer yer, double mesafeM})> duragaYakinlar(
    List<TuristikYer> yerler,
    String durakKodu,
  ) {
    final liste = <({TuristikYer yer, double mesafeM})>[];
    for (final yer in yerler) {
      final mesafe = yer.durakUzakligi(durakKodu);
      if (mesafe != null) liste.add((yer: yer, mesafeM: mesafe));
    }
    liste.sort((a, b) => a.mesafeM.compareTo(b.mesafeM));
    return liste;
  }
}
