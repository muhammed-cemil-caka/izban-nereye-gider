import 'dart:convert';
import 'package:http/http.dart' as http;
import '../diller.dart';
import '../modeller/durak.dart';
import 'servis_adresi.dart';

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
///
/// Manevra HAM hâlde saklanır, metin okunduğu anda çevrilir. Önce çekim anında
/// biçimleniyordu: kullanıcı dili değiştirdiğinde eldeki rotanın adımları eski
/// dilde kalıyor, sesli yönlendirme de İngilizce arayüzde Türkçe okuyordu.
class RotaAdimi {
  final String tur;
  final String? yonKodu;
  final String? yolAdi;
  final double mesafeM;

  const RotaAdimi({
    required this.tur,
    required this.mesafeM,
    this.yonKodu,
    this.yolAdi,
  });

  String get metin => RotaServisi.manevrayiTurkcelestir(tur, yonKodu, yolAdi);
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

  /* OSM'deki yol adları Türkçe: "8294. Sokak", "Namık Kemal Caddesi".
     İngilizce arayüzde adım listesine olduğu gibi giriyordu ve İngilizce ses
     onları Türkçe okuyordu. Yol TÜRÜ cins isimdir, çevrilir; addaki özel isim
     olduğu gibi kalır — "Namık Kemal Avenue".

     Sıra önemli: "Çevre Yolu", "Yolu"dan önce denenmeli. */
  static final _yolTurleri = <(RegExp, String)>[
    (RegExp(r'(^|\s)(?:Sokağı|Sokak|Sk\.)$', caseSensitive: false), 'Street'),
    (RegExp(r'(^|\s)(?:Caddesi|Cadde|Cad\.|Cd\.)$', caseSensitive: false), 'Avenue'),
    (RegExp(r'(^|\s)(?:Bulvarı|Bulvar|Blv\.|Bul\.)$', caseSensitive: false), 'Boulevard'),
    (RegExp(r'(^|\s)(?:Çevre Yolu)$', caseSensitive: false), 'Ring Road'),
    (RegExp(r'(^|\s)(?:Sahil Yolu)$', caseSensitive: false), 'Coastal Road'),
    (RegExp(r'(^|\s)(?:Otoyolu|Otoyol)$', caseSensitive: false), 'Motorway'),
    (RegExp(r'(^|\s)(?:Yolu|Yol)$', caseSensitive: false), 'Road'),
    (RegExp(r'(^|\s)(?:Meydanı|Meydan)$', caseSensitive: false), 'Square'),
    (RegExp(r'(^|\s)(?:Köprüsü|Köprü)$', caseSensitive: false), 'Bridge'),
    (RegExp(r'(^|\s)(?:Geçidi|Geçit)$', caseSensitive: false), 'Pass'),
    (RegExp(r'(^|\s)(?:Çıkmazı|Çıkmaz)$', caseSensitive: false), 'Cul-de-sac'),
    (RegExp(r'(^|\s)(?:Parkı|Park)$', caseSensitive: false), 'Park'),
  ];

  // "8294. Sokak" → "Street 8294"; İngilizcede numara türden sonra gelir.
  static final _numaraliYol = RegExp(r'^(\d+)\.\s*(.+)$');

  /// Yol adını arayüz diline uyarlar. Türkçede olduğu gibi bırakır.
  static String yolAdiniCevir(String? ad) {
    if (ad == null || ad.isEmpty || Diller.aktif.kod != 'en') return ad ?? '';

    String? numara;
    var kalan = ad;
    final eslesme = _numaraliYol.firstMatch(ad);
    if (eslesme != null) {
      numara = eslesme.group(1);
      kalan = eslesme.group(2)!;
    }

    for (final (desen, karsilik) in _yolTurleri) {
      if (desen.hasMatch(kalan)) {
        kalan = kalan
            .replaceAllMapped(desen, (e) => '${e.group(1)}$karsilik')
            .trim();
        break;
      }
    }

    return numara == null ? kalan : '$kalan $numara';
  }

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
    final cevrilen = yolAdiniCevir(yolAdi);
    final yer = cevrilen.isEmpty ? '' : ' — $cevrilen';

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

    final adres = await ServisAdresi.coz(
      () => Uri.parse(
        '${ServisAdresi.taban}/api/mesafe?kip=${kip.name}'
        '&baslangic=${baslangic.boylam},${baslangic.enlem}'
        '&hedefler=${hedefler.map((h) => '${h.boylam},${h.enlem}').join(';')}',
      ),
      () => Uri.parse(
        '${kip.taban.replaceFirst('/route/v1/', '/table/v1/')}'
        '/$noktalar?sources=0&annotations=distance,duration',
      ),
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
    // Vekil varsa oradan: rota geometrisi CDN'de 7 gün duruyor ve gönüllü
    // sunucuya yüzlerce kullanıcı yerine avuç dolusu istek gidiyor.
    final adres = await ServisAdresi.coz(
      () => Uri.parse(
        '${ServisAdresi.taban}/api/rota?kip=${kip.name}'
        '&baslangic=${baslangic.boylam},${baslangic.enlem}'
        '&bitis=${bitis.boylam},${bitis.enlem}',
      ),
      () => Uri.parse(
        '${kip.taban}/${baslangic.boylam},${baslangic.enlem}'
        ';${bitis.boylam},${bitis.enlem}'
        '?overview=full&geometries=geojson&steps=true',
      ),
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
        tur: manevra['type'] as String? ?? '',
        yonKodu: manevra['modifier'] as String?,
        yolAdi: adim['name'] as String?,
        mesafeM: mesafe,
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
