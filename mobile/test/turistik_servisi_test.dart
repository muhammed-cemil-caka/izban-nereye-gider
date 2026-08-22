import 'package:flutter_test/flutter_test.dart';
import 'package:izban_nereye_gider/modeller/turistik_yer.dart';
import 'package:izban_nereye_gider/servisler/turistik_servisi.dart';

const _ham = {
  'kod': 'ayasuluk',
  'ad': 'Ayasuluk',
  'tur': 'anit',
  'konum': {'enlem': 37.9555, 'boylam': 27.368111},
  'ozet': 'Ayasuluk Tepesi, Selçuk ilçesinde yer alan bir höyüktür.',
  'gorsel': {
    'adres': 'https://ornek/tam.jpg',
    'kucukAdres': 'https://ornek/640.jpg',
    'yazar': 'Bir Fotoğrafçı',
    'lisans': 'CC BY-SA 4.0',
    'kaynakSayfa': 'https://commons.wikimedia.org/wiki/File:Ornek.jpg'
  },
  'kaynaklar': {'wikidata': 'Q123', 'wikipedia': 'https://tr.wikipedia.org/wiki/Ayasuluk'},
  'duraklar': [
    {'kod': 'selcuk', 'kusUcusuM': 620},
    {'kod': 'belevi', 'kusUcusuM': 1400}
  ]
};

void main() {
  test('JSON okunuyor, lisans bilgisi korunuyor', () {
    final yer = TuristikYer.jsondan(Map<String, dynamic>.from(_ham));

    expect(yer.ad, 'Ayasuluk');
    expect(yer.tur, 'anit');
    expect(yer.konum.enlem, closeTo(37.9555, 1e-6));
    // Yazar ve lisans zorunlu: Commons görselleri kaynak gösterimi istiyor.
    expect(yer.gorsel?.yazar, 'Bir Fotoğrafçı');
    expect(yer.gorsel?.lisans, 'CC BY-SA 4.0');
    expect(yer.wikipedia, contains('tr.wikipedia.org'));
  });

  test('görselsiz kayıt çökmüyor', () {
    final ham = Map<String, dynamic>.from(_ham)..remove('gorsel');
    final yer = TuristikYer.jsondan(ham);
    expect(yer.gorsel, isNull);
    expect(yer.ozet, isNotEmpty);
  });

  test('durak uzaklığı bağdan okunuyor', () {
    final yer = TuristikYer.jsondan(Map<String, dynamic>.from(_ham));
    expect(yer.durakUzakligi('selcuk'), 620);
    expect(yer.durakUzakligi('halkapinar'), isNull);
  });

  test('durağa yakın yerler yakından uzağa sıralanıyor', () {
    final yakin = TuristikYer.jsondan({
      ..._ham,
      'kod': 'yakin',
      'ad': 'Yakın Yer',
      'duraklar': [
        {'kod': 'selcuk', 'kusUcusuM': 200}
      ]
    });
    final uzak = TuristikYer.jsondan(Map<String, dynamic>.from(_ham));

    final liste = TuristikServisi.duragaYakinlar([uzak, yakin], 'selcuk');
    expect(liste.map((k) => k.yer.ad).toList(), ['Yakın Yer', 'Ayasuluk']);
    expect(liste.first.mesafeM, 200);

    // Bağı olmayan durak boş liste döndürür.
    expect(TuristikServisi.duragaYakinlar([uzak, yakin], 'aliaga'), isEmpty);
  });

  test('hazır servis dosyaya gitmiyor', () async {
    final yer = TuristikYer.jsondan(Map<String, dynamic>.from(_ham));
    final servis = TuristikServisi.hazir([yer]);
    expect((await servis.yerleriGetir()).single.ad, 'Ayasuluk');
  });

  group('önceden hesaplanmış en yakın durak', () {
    test('enYakin alanı okunuyor', () {
      final yer = TuristikYer.jsondan({
        ..._ham,
        'enYakin': {
          'yuruyus': {'kod': 'selcuk', 'mesafeM': 168, 'sureSn': 124},
          'araba': {'kod': 'tepekoy', 'mesafeM': 420, 'sureSn': 70},
        },
      });
      expect(yer.enYakin['yuruyus']!.kod, 'selcuk');
      expect(yer.enYakin['yuruyus']!.mesafeM, 168);
      expect(yer.enYakin['araba']!.sureSn, 70);
    });

    test('alan yoksa boş harita döner', () {
      expect(TuristikYer.jsondan(_ham).enYakin, isEmpty);
    });

    test('bozuk kayıt atlanır, sağlamı kalır', () {
      final yer = TuristikYer.jsondan({
        ..._ham,
        'enYakin': {
          'yuruyus': {'mesafeM': 168},
          'araba': {'kod': 'tepekoy', 'mesafeM': 420, 'sureSn': 70},
        },
      });
      expect(yer.enYakin.containsKey('yuruyus'), isFalse);
      expect(yer.enYakin['araba']!.kod, 'tepekoy');
    });
  });
}
