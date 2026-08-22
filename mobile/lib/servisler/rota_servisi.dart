import 'dart:convert';
import 'package:http/http.dart' as http;
import '../diller.dart';
import '../modeller/durak.dart';

/// Rota kipi. FOSSGIS her OSRM profilini ayrı adreste sunuyor.
enum RotaKipi {
  yuruyus('routed-foot', 'foot', 'kipYuruyus'),
  araba('routed-car', 'driving', 'kipAraba');

  final String sunucu;
  final String profil;

  /// Sözlük anahtarı; etiket seçili dile göre üretilir.
  final String etiketAnahtari;

  const RotaKipi(this.sunucu, this.profil, this.etiketAnahtari);

  String get taban =>
      'https://routing.openstreetmap.de/$sunucu/route/v1/$profil';

  /// "Yürüyüş" / "Walking"
  String get etiket => Diller.aktif(etiketAnahtari);
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

  String get mesafeMetni {
    final ceviri = Diller.aktif;
    if (mesafeM < 1000) return '${mesafeM.round()} ${ceviri('birimM')}';
    // Ondalık ayracı dile göre: Türkçede virgül, İngilizcede nokta.
    var deger = (mesafeM / 1000).toStringAsFixed(1);
    if (ceviri.kod != 'en') deger = deger.replaceAll('.', ',');
    return '$deger ${ceviri('birimKm')}';
  }

  String get sureMetni =>
      Diller.aktif.sure((sureSn / 60).round().clamp(1, 1 << 31));
}

/// Yürüyüş rotası hesaplar — OSRM (OpenStreetMap tabanlı).
///
/// Servis notu: routing.openstreetmap.de FOSSGIS'in işlettiği ücretsiz bir
/// topluluk servisidir, anahtar istemez ama ağır kullanıma uygun değildir.
/// Rota yalnızca kullanıcı isteyince çekilir. Yayına çıkarken kendi OSRM
/// örneğimize ya da anahtarlı bir servise geçilmeli.
class RotaServisi {
  const RotaServisi();

  static const _zamanAsimi = Duration(seconds: 15);

  /// OSRM manevra yönleri → sözlük anahtarları.
  static const _yonAnahtarlari = <String, String>{
    'left': 'manevraSola',
    'right': 'manevraSaga',
    'slight left': 'manevraHafifSola',
    'slight right': 'manevraHafifSaga',
    'sharp left': 'manevraKeskinSola',
    'sharp right': 'manevraKeskinSaga',
    'straight': 'manevraDuz',
    'uturn': 'manevraGeri',
  };

  /// İlk harfi büyütür — cümle başına gelen yön adı için.
  static String _basHarfiBuyut(String metin) =>
      metin.isEmpty ? metin : '${metin[0].toUpperCase()}${metin.substring(1)}';

  /// OSRM manevrasını arayüz diline çevirir.
  ///
  /// Adı tarihsel: önce yalnızca Türkçe üretiyordu. Artık seçili dile göre
  /// yazıyor — İngilizce arayüzde adım listesi de, sesli yönlendirme de
  /// İngilizce olsun diye.
  static String manevrayiTurkcelestir(
    String tur,
    String? yonKodu,
    String? yolAdi,
  ) {
    final ceviri = Diller.aktif;
    final yonAnahtari = _yonAnahtarlari[yonKodu];
    final yon = yonAnahtari == null ? '' : ceviri(yonAnahtari);
    final yer = (yolAdi != null && yolAdi.isNotEmpty) ? ' — $yolAdi' : '';

    switch (tur) {
      case 'depart':
        return ceviri('yolaCikYol', {'yol': yer});
      case 'arrive':
        return ceviri('vardinYol', {'yol': yer});
      case 'turn':
        if (yon.isEmpty) return ceviri('donSadeYol', {'yol': yer});
        return _basHarfiBuyut(ceviri('donYol', {'yon': yon, 'yol': yer}));
      case 'end of road':
        return ceviri('yolSonuYol', {
          'yon': yon.isEmpty ? ceviri('manevraDevamEt') : yon,
          'yol': yer,
        });
      case 'fork':
        return ceviri('ayrimYol', {
          'yon': yon.isEmpty ? ceviri('manevraDuz') : yon,
          'yol': yer,
        });
      case 'new name':
      case 'continue':
        return ceviri('devamEtYol', {'yol': yer});
      case 'roundabout':
      case 'rotary':
        return ceviri('kavsakYol', {'yol': yer});
      case 'merge':
        return ceviri('yolaKatilYol', {'yol': yer});
      default:
        return ceviri('devamEtYol', {'yol': yer});
    }
  }

  /// Bir noktadan birden çok hedefe yürüme mesafelerini tek istekte alır.
  ///
  /// Kuş uçuşu yanıltıyor: dere, otoyol veya demiryolu araya girdiğinde yakın
  /// görünen durak yürüyerek çok daha uzak olabiliyor. Ölçüldü: Çiğli kuş
  /// uçuşu daha yakın ama yürüyüşle 2,5 km; Mavişehir 1,4 km.
  ///
  /// Hedeflerle aynı sırada döner; ulaşılamayan hedef için null.
  Future<List<({double mesafeM, double sureSn})?>> mesafeler(
    Konum baslangic,
    List<Konum> hedefler, {
    RotaKipi kip = RotaKipi.yuruyus,
  }) async {
    if (hedefler.isEmpty) return const [];

    final noktalar = [baslangic, ...hedefler]
        .map((k) => '${k.boylam},${k.enlem}')
        .join(';');

    final adres = Uri.parse(
      '${kip.taban.replaceFirst('/route/v1/', '/table/v1/')}'
      '/$noktalar?sources=0&annotations=distance,duration',
    );

    final yanit = await http.get(adres).timeout(_zamanAsimi);
    if (yanit.statusCode != 200) {
      throw Exception('Mesafe servisi yanıtı: ${yanit.statusCode}');
    }

    final govde = jsonDecode(utf8.decode(yanit.bodyBytes)) as Map<String, dynamic>;
    if (govde['code'] != 'Ok') throw Exception(Diller.aktif('mesafelerAlinamadi'));

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
    final bulunamadi = Diller.aktif('rotaBulunamadi', {'kip': kip.etiket});
    if (govde['code'] != 'Ok') throw Exception(bulunamadi);

    final rotalar = govde['routes'] as List<dynamic>;
    if (rotalar.isEmpty) throw Exception(bulunamadi);

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
