import 'dart:convert';
import 'package:http/http.dart' as http;

/// Tek bir İZBAN seferi.
class Sefer {
  final String kalkis; // "07:35"
  final String varis;  // "08:05"
  final int kalkisDk;  // gün içi dakika — sıralama ve "kaç dk sonra" için

  const Sefer({required this.kalkis, required this.varis, required this.kalkisDk});
}

/// Sıradaki sefer: kalkışa kalan süreyle birlikte.
class SiradakiSefer {
  final Sefer sefer;
  final bool ertesiGun;
  final int? kalanDk;

  const SiradakiSefer(this.sefer, {required this.ertesiGun, this.kalanDk});
}

/// İZBAN sefer saatleri — İzmir Büyükşehir Belediyesi açık veri servisi.
///
/// https://openapi.izmir.bel.tr/api/izban/sefersaatleri/{kalkis}/{varis}
/// Anahtar istemiyor. Kapsam: Aliağa – Tepeköy. Selçuk uzantısında (Sağlık,
/// Belevi, Selçuk) servis boş liste döndürüyor; uydurmak yerine boş dönülür.
class SeferServisi {
  const SeferServisi();

  static const _taban = 'https://openapi.izmir.bel.tr/api/izban/sefersaatleri';
  static const _zamanAsimi = Duration(seconds: 15);

  /// "07:35:00" → 455 (dakika). Bozuk değerde null.
  static int? dakikayaCevir(String? metin) {
    final parca = (metin ?? '').split(':');
    if (parca.length < 2) return null;
    final saat = int.tryParse(parca[0]);
    final dakika = int.tryParse(parca[1]);
    if (saat == null || dakika == null) return null;
    return saat * 60 + dakika;
  }

  static String kisalt(String? metin) =>
      (metin ?? '').length >= 5 ? metin!.substring(0, 5) : (metin ?? '');

  Future<List<Sefer>> seferleriAl(int kalkisId, int varisId) async {
    final adres = Uri.parse('$_taban/$kalkisId/$varisId');
    final yanit = await http.get(adres).timeout(_zamanAsimi);
    if (yanit.statusCode != 200) {
      throw Exception('Sefer servisi yanıtı: ${yanit.statusCode}');
    }

    final govde = jsonDecode(utf8.decode(yanit.bodyBytes));
    if (govde is! List) return const [];

    final seferler = <Sefer>[];
    for (final ham in govde) {
      final harita = ham as Map<String, dynamic>;
      final dk = dakikayaCevir(harita['HareketSaati'] as String?);
      if (dk == null) continue;
      seferler.add(Sefer(
        kalkis: kisalt(harita['HareketSaati'] as String?),
        varis: kisalt(harita['VarisSaati'] as String?),
        kalkisDk: dk,
      ));
    }

    seferler.sort((a, b) => a.kalkisDk.compareTo(b.kalkisDk));
    return seferler;
  }

  /// Şu andan sonraki ilk [adet] sefer.
  ///
  /// Gün sonunda liste boşalmasın diye başa sarılır: gece 23:50'de bakan
  /// kullanıcıya ertesi günün ilk seferleri gösterilir.
  static List<SiradakiSefer> siradakiler(
    List<Sefer> seferler,
    int adet, {
    int? simdiDk,
  }) {
    if (seferler.isEmpty) return const [];

    final an = simdiDk ?? (() {
      final d = DateTime.now();
      return d.hour * 60 + d.minute;
    })();

    final sonrakiler = seferler.where((s) => s.kalkisDk >= an).take(adet).toList();
    final secilen = sonrakiler
        .map((s) => SiradakiSefer(s, ertesiGun: false, kalanDk: s.kalkisDk - an))
        .toList();

    for (var i = 0; secilen.length < adet && i < seferler.length; i++) {
      secilen.add(SiradakiSefer(seferler[i], ertesiGun: true));
    }

    return secilen;
  }
}
