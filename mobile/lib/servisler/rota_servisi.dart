import 'dart:convert';
import 'package:http/http.dart' as http;
import '../modeller/durak.dart';

/// Rota kipi. FOSSGIS her OSRM profilini ayrı adreste sunuyor.
enum RotaKipi {
  yuruyus('routed-foot', 'foot', 'Yürüyüş'),
  araba('routed-car', 'driving', 'Araba');

  final String sunucu;
  final String profil;
  final String etiket;

  const RotaKipi(this.sunucu, this.profil, this.etiket);

  String get taban =>
      'https://routing.openstreetmap.de/$sunucu/route/v1/$profil';
}

/// Rotanın bir adımı.
class RotaAdimi {
  final String metin;
  final double mesafeM;

  const RotaAdimi(this.metin, this.mesafeM);
}

/// Hesaplanmış rota — yürüyüş ya da araba.
class Rota {
  final List<Konum> noktalar;
  final double mesafeM;
  final double sureSn;
  final List<RotaAdimi> adimlar;
  final RotaKipi kip;

  const Rota({
    required this.noktalar,
    required this.mesafeM,
    required this.sureSn,
    required this.adimlar,
    this.kip = RotaKipi.yuruyus,
  });

  String get mesafeMetni => mesafeM < 1000
      ? '${mesafeM.round()} m'
      : '${(mesafeM / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  String get sureMetni {
    final dakika = (sureSn / 60).round().clamp(1, 1 << 31);
    if (dakika < 60) return '$dakika dk';
    final saat = dakika ~/ 60;
    final kalan = dakika % 60;
    return kalan == 0 ? '$saat sa' : '$saat sa $kalan dk';
  }
}

/// Yürüyüş rotası hesaplar — OSRM (OpenStreetMap tabanlı).
///
/// Servis notu: routing.openstreetmap.de FOSSGIS'in işlettiği ücretsiz bir
/// topluluk servisidir, anahtar istemez ama ağır kullanıma uygun değildir.
/// Rota yalnızca kullanıcı isteyince çekilir. Yayına çıkarken kendi OSRM
/// örneğimize ya da anahtarlı bir servise geçilmeli.
class RotaServisi {
  const RotaServisi();

  /// En yakın durak sıralaması hep YÜRÜYEREK hesaplanır: kullanıcı durağa
  /// yürüyerek gidiyor, araba mesafesi orada yanıltıcı olurdu.
  static final _yuruyusTabani = RotaKipi.yuruyus.taban;
  static const _zamanAsimi = Duration(seconds: 15);

  static const _yonAdlari = <String, String>{
    'left': 'sola',
    'right': 'sağa',
    'slight left': 'hafif sola',
    'slight right': 'hafif sağa',
    'sharp left': 'keskin sola',
    'sharp right': 'keskin sağa',
    'straight': 'düz',
    'uturn': 'geri',
  };

  /// OSRM manevralarını Türkçeleştirir.
  static String manevrayiTurkcelestir(
    String tur,
    String? yonKodu,
    String? yolAdi,
  ) {
    final yon = _yonAdlari[yonKodu] ?? '';
    final yer = (yolAdi != null && yolAdi.isNotEmpty) ? ' — $yolAdi' : '';

    switch (tur) {
      case 'depart':
        return 'Yola çık$yer';
      case 'arrive':
        return 'Vardın$yer';
      case 'turn':
        if (yon.isEmpty) return 'Dön$yer';
        return '${yon[0].toUpperCase()}${yon.substring(1)} dön$yer';
      case 'end of road':
        return 'Yolun sonunda ${yon.isEmpty ? "devam et" : yon} dön$yer';
      case 'fork':
        return 'Ayrımda ${yon.isEmpty ? "düz" : yon} git$yer';
      case 'new name':
      case 'continue':
        return 'Devam et$yer';
      case 'roundabout':
      case 'rotary':
        return 'Kavşaktan çık$yer';
      case 'merge':
        return 'Yola katıl$yer';
      default:
        return 'Devam et$yer';
    }
  }

  /// Bir noktadan birden çok hedefe yürüme mesafelerini tek istekte alır.
  ///
  /// Kuş uçuşu yanıltıyor: dere, otoyol veya demiryolu araya girdiğinde yakın
  /// görünen durak yürüyerek çok daha uzak olabiliyor. Ölçüldü: Çiğli kuş
  /// uçuşu daha yakın ama yürüyüşle 2,5 km; Mavişehir 1,4 km.
  ///
  /// Hedeflerle aynı sırada döner; ulaşılamayan hedef için null.
  Future<List<({double mesafeM, double sureSn})?>> yuruyusMesafeleri(
    Konum baslangic,
    List<Konum> hedefler,
  ) async {
    if (hedefler.isEmpty) return const [];

    final noktalar = [baslangic, ...hedefler]
        .map((k) => '${k.boylam},${k.enlem}')
        .join(';');

    final adres = Uri.parse(
      '${_yuruyusTabani.replaceFirst('/route/v1/foot', '/table/v1/foot')}'
      '/$noktalar?sources=0&annotations=distance,duration',
    );

    final yanit = await http.get(adres).timeout(_zamanAsimi);
    if (yanit.statusCode != 200) {
      throw Exception('Mesafe servisi yanıtı: ${yanit.statusCode}');
    }

    final govde = jsonDecode(utf8.decode(yanit.bodyBytes)) as Map<String, dynamic>;
    if (govde['code'] != 'Ok') throw Exception('Yürüme mesafeleri alınamadı.');

    final mesafeler = (govde['distances'] as List<dynamic>).first as List<dynamic>;
    final sureler = (govde['durations'] as List<dynamic>?)?.first as List<dynamic>?;

    // İlk değer başlangıcın kendisi; hedefler ondan sonra geliyor.
    return List.generate(hedefler.length, (i) {
      final mesafe = mesafeler[i + 1];
      if (mesafe == null) return null;
      return (
        mesafeM: (mesafe as num).toDouble(),
        sureSn: ((sureler?[i + 1] as num?) ?? 0).toDouble(),
      );
    });
  }

  Future<Rota> rotaAl(
    Konum baslangic,
    Konum bitis, {
    RotaKipi kip = RotaKipi.yuruyus,
  }) async {
    final adres = Uri.parse(
      '${kip.taban}/${baslangic.boylam},${baslangic.enlem}'
      ';${bitis.boylam},${bitis.enlem}'
      '?overview=full&geometries=geojson&steps=true',
    );

    final yanit = await http.get(adres).timeout(_zamanAsimi);
    if (yanit.statusCode != 200) {
      throw Exception('Rota servisi yanıtı: ${yanit.statusCode}');
    }

    final govde = jsonDecode(utf8.decode(yanit.bodyBytes)) as Map<String, dynamic>;
    if (govde['code'] != 'Ok') throw Exception('${kip.etiket} rotası bulunamadı.');

    final rotalar = govde['routes'] as List<dynamic>;
    if (rotalar.isEmpty) throw Exception('${kip.etiket} rotası bulunamadı.');

    final rota = rotalar.first as Map<String, dynamic>;
    final geometri = rota['geometry'] as Map<String, dynamic>;

    // GeoJSON [boylam, enlem] sırasıyla gelir.
    final noktalar = (geometri['coordinates'] as List<dynamic>)
        .map((n) => Konum(
              enlem: ((n as List<dynamic>)[1] as num).toDouble(),
              boylam: (n[0] as num).toDouble(),
            ))
        .toList();

    final bacaklar = rota['legs'] as List<dynamic>;
    final hamAdimlar =
        bacaklar.isEmpty ? const [] : (bacaklar.first['steps'] as List<dynamic>);

    final adimlar = <RotaAdimi>[];
    for (var i = 0; i < hamAdimlar.length; i++) {
      final adim = hamAdimlar[i] as Map<String, dynamic>;
      final manevra = adim['maneuver'] as Map<String, dynamic>;
      final mesafe = (adim['distance'] as num).toDouble();

      // Sıfıra yakın adımlar listeyi gereksiz uzatıyor.
      if (mesafe < 5 && i != 0 && i != hamAdimlar.length - 1) continue;

      adimlar.add(RotaAdimi(
        manevrayiTurkcelestir(
          manevra['type'] as String? ?? '',
          manevra['modifier'] as String?,
          adim['name'] as String?,
        ),
        mesafe,
      ));
    }

    return Rota(
      noktalar: noktalar,
      mesafeM: (rota['distance'] as num).toDouble(),
      sureSn: (rota['duration'] as num).toDouble(),
      adimlar: adimlar,
      kip: kip,
    );
  }
}
