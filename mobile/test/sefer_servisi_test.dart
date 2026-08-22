import 'package:flutter_test/flutter_test.dart';
import 'package:izban_nereye_gider/modeller/durak.dart';
import 'package:izban_nereye_gider/servisler/sefer_servisi.dart';

/// Sentetik hat: aktarma durakları gerçek adlarıyla, aralara dolgu duraklar.
/// Gerçek durak listesi değiştiğinde testler kırılmasın diye.
Durak _durak(String kod, int id) => Durak(
      kod: kod,
      ad: kod,
      ilce: 'İl',
      dakika: 0,
      konum: const Konum(enlem: 38, boylam: 27),
      izbanId: id,
    );

final _hat = <Durak>[
  _durak('kuzey', 1),
  _durak('cumaovasi', 2),
  _durak('orta', 3),
  _durak('tepekoy', 4),
  _durak('guney', 5),
];

Sefer _sefer(String kalkis, String varis) => Sefer(
      kalkis: kalkis,
      varis: varis,
      kalkisDk: SeferServisi.dakikayaCevir(kalkis)!,
    );

SeferYolculugu _yolculuk(int kalkisDk, int varisDk) => SeferYolculugu(
      kalkis: '00:00',
      varis: '00:00',
      kalkisDk: kalkisDk,
      varisDk: varisDk,
    );

void main() {
  group('zincir', () {
    test('aradaki aktarma durakları zincire girer', () {
      final zincir = SeferServisi.zincirKur(_hat, 'kuzey', 'guney')!;
      expect(zincir.map((d) => d.kod).toList(),
          ['kuzey', 'cumaovasi', 'tepekoy', 'guney']);
    });

    test('yolculuğun dışındaki aktarma durağı zincire girmez', () {
      final zincir = SeferServisi.zincirKur(_hat, 'orta', 'guney')!;
      expect(zincir.map((d) => d.kod).toList(), ['orta', 'tepekoy', 'guney']);
    });

    test('ters yönde zincir de yolculuk sırasında', () {
      final zincir = SeferServisi.zincirKur(_hat, 'guney', 'kuzey')!;
      expect(zincir.map((d) => d.kod).toList(),
          ['guney', 'tepekoy', 'cumaovasi', 'kuzey']);
    });

    test('aynı durak ve bilinmeyen kod null döner', () {
      expect(SeferServisi.zincirKur(_hat, 'orta', 'orta'), isNull);
      expect(SeferServisi.zincirKur(_hat, 'orta', 'yokboyle'), isNull);
    });

    test('izbanId olmayan uç durak zinciri geçersiz kılar', () {
      final eksik = [
        Durak(
          kod: 'kimliksiz',
          ad: 'Kimliksiz',
          ilce: 'İl',
          dakika: 0,
          konum: const Konum(enlem: 38, boylam: 27),
        ),
        ..._hat,
      ];
      expect(SeferServisi.zincirKur(eksik, 'kimliksiz', 'guney'), isNull);
    });
  });

  group('zincir yolları', () {
    test('iki düğümde tek yol', () {
      expect(SeferServisi.zincirYollari(2), [
        [0, 1]
      ]);
    });

    test('dört düğümde dört yol: doğrudan, tek aktarma, çift aktarma', () {
      // Liste eşitliği Dart'ta kimlik üzerinden; metne çevirip karşılaştırılır.
      final yollar =
          SeferServisi.zincirYollari(4).map((y) => y.join('-')).toSet();
      expect(yollar, {'0-3', '0-1-3', '0-2-3', '0-1-2-3'});
    });
  });

  group('bağlantı seçimi', () {
    final liste = [_sefer('08:00', '08:20'), _sefer('09:00', '09:20')];

    test('en az bekleten sefer seçilir', () {
      final b = SeferServisi.ilkBaglanti(liste, 7 * 60 + 30)!;
      expect(b.sefer.kalkis, '08:00');
      expect(b.beklemeDk, 30);
    });

    test('yetişilemeyecek kadar yakınsa sonraki sefere geçilir', () {
      // 07:59'da hazır: 08:00'a 1 dk var, en az aktarma süresi 3 dk.
      final b = SeferServisi.ilkBaglanti(liste, 7 * 60 + 59)!;
      expect(b.sefer.kalkis, '09:00');
      expect(b.beklemeDk, 61);
    });

    test('gece yarısını aşan bekleme doğru hesaplanır', () {
      // 23:30'da hazır → ertesi sabah 08:00, 510 dakika.
      final b = SeferServisi.ilkBaglanti(liste, 23 * 60 + 30)!;
      expect(b.sefer.kalkis, '08:00');
      expect(b.beklemeDk, 510);
    });
  });

  group('yolculuk kurma', () {
    final zincir = SeferServisi.zincirKur(_hat, 'kuzey', 'guney')!;

    test('aktarmasız yol doğrudan bağlanır', () {
      final kenarlar = <String, List<Sefer>>{
        '0-3': [_sefer('08:00', '09:30')],
      };
      final y = SeferServisi.yolculuguKur(
          [0, 3], zincir, kenarlar, kenarlar['0-3']!.first)!;
      expect(y.kalkis, '08:00');
      expect(y.varis, '09:30');
      expect(y.aktarmalar, isEmpty);
      expect(y.varisDk, 9 * 60 + 30);
    });

    test('iki aktarmalı yol zincirlenir ve bekleme yazılır', () {
      final kenarlar = <String, List<Sefer>>{
        '0-1': [_sefer('08:00', '08:30')],
        '1-2': [_sefer('08:40', '09:10')],
        '2-3': [_sefer('09:20', '09:50')],
      };
      final y = SeferServisi.yolculuguKur(
          [0, 1, 2, 3], zincir, kenarlar, kenarlar['0-1']!.first)!;
      expect(y.kalkis, '08:00');
      expect(y.varis, '09:50');
      expect(y.aktarmalar.map((a) => a.durak).toList(),
          ['cumaovasi', 'tepekoy']);
      expect(y.aktarmalar.map((a) => a.beklemeDk).toList(), [10, 10]);
    });

    test('çok uzun bekleten bağlantı yolculuk sayılmaz', () {
      final kenarlar = <String, List<Sefer>>{
        '0-1': [_sefer('08:00', '08:30')],
        // Tek bağlantı ertesi sabah: 3 saatlik sınırın çok üstünde.
        '1-3': [_sefer('06:00', '07:00')],
      };
      final y = SeferServisi.yolculuguKur(
          [0, 1, 3], zincir, kenarlar, kenarlar['0-1']!.first);
      expect(y, isNull);
    });

    test('gece yarısını aşan sefer süresi doğru', () {
      final kenarlar = <String, List<Sefer>>{
        '0-3': [_sefer('23:40', '00:20')],
      };
      final y = SeferServisi.yolculuguKur(
          [0, 3], zincir, kenarlar, kenarlar['0-3']!.first)!;
      expect(y.varisDk, 23 * 60 + 40 + 40);
    });
  });

  group('baskınlık', () {
    test('geç kalkıp aynı anda varan yolculuk erkeni eler', () {
      final kalanlar = SeferServisi.baskinOlanlar([
        _yolculuk(365, 496), // 06:05 → 08:16
        _yolculuk(417, 496), // 06:57 → 08:16
        _yolculuk(444, 556), // 07:24 → 09:16
      ]);
      expect(kalanlar.map((y) => y.kalkisDk).toList(), [417, 444]);
    });

    test('kalkışa göre artan sırada döner', () {
      final kalanlar = SeferServisi.baskinOlanlar([
        _yolculuk(600, 700),
        _yolculuk(400, 500),
        _yolculuk(500, 600),
      ]);
      expect(kalanlar.map((y) => y.kalkisDk).toList(), [400, 500, 600]);
    });
  });

  group('sıradakiler', () {
    final seferler = [
      _yolculuk(8 * 60, 9 * 60),
      _yolculuk(10 * 60, 11 * 60),
      _yolculuk(12 * 60, 13 * 60),
    ];

    test('şu andan sonraki seferler kalan süreyle döner', () {
      final s = SeferServisi.siradakiler(seferler, 2, simdiDk: 9 * 60);
      expect(s.length, 2);
      expect(s.first.sefer.kalkisDk, 10 * 60);
      expect(s.first.kalanDk, 60);
      expect(s.first.ertesiGun, isFalse);
    });

    test('gün bitince ertesi günün ilk seferlerine sarılır', () {
      final s = SeferServisi.siradakiler(seferler, 2, simdiDk: 23 * 60);
      expect(s.every((x) => x.ertesiGun), isTrue);
      expect(s.first.sefer.kalkisDk, 8 * 60);
      expect(s.first.kalanDk, isNull);
    });

    test('boş liste boş döner', () {
      expect(SeferServisi.siradakiler(const [], 4), isEmpty);
    });
  });
}
