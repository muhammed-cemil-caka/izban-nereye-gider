import 'package:flutter_test/flutter_test.dart';
import 'package:izban_nereye_gider/modeller/durak.dart';
import 'package:izban_nereye_gider/modeller/yolculuk.dart';

const _ornekDuraklar = <Durak>[
  Durak(kod: 'a', ad: 'A', ilce: 'İl', dakika: 0, konum: Konum(enlem: 38.4, boylam: 27.1), aktarma: []),
  Durak(kod: 'b', ad: 'B', ilce: 'İl', dakika: 10, konum: Konum(enlem: 38.4, boylam: 27.1), aktarma: ['Metro']),
  Durak(kod: 'c', ad: 'C', ilce: 'İl', dakika: 25, konum: Konum(enlem: 38.4, boylam: 27.1), aktarma: []),
  Durak(kod: 'd', ad: 'D', ilce: 'İl', dakika: 70, konum: Konum(enlem: 38.4, boylam: 27.1), aktarma: []),
];

void main() {
  group('Yolculuk.hesapla', () {
    test('güneye giderken yön ve durak sayısı doğru', () {
      final yolculuk = Yolculuk.hesapla(_ornekDuraklar, 'a', 'c')!;
      expect(yolculuk.yon, Yon.guney);
      expect(yolculuk.durakSayisi, 2);
      expect(yolculuk.dakika, 25);
      expect(yolculuk.guzergah.first.kod, 'a');
      expect(yolculuk.guzergah.last.kod, 'c');
    });

    test('kuzeye giderken güzergâh ters sırada', () {
      final yolculuk = Yolculuk.hesapla(_ornekDuraklar, 'd', 'b')!;
      expect(yolculuk.yon, Yon.kuzey);
      expect(yolculuk.guzergah.first.kod, 'd');
      expect(yolculuk.guzergah.last.kod, 'b');
    });

    test('aynı durak seçilirse null döner', () {
      expect(Yolculuk.hesapla(_ornekDuraklar, 'b', 'b'), isNull);
    });

    test('bilinmeyen durak kodu null döner', () {
      expect(Yolculuk.hesapla(_ornekDuraklar, 'b', 'yok'), isNull);
    });

    test('aktarmalı duraklar güzergâhtan süzülür', () {
      final yolculuk = Yolculuk.hesapla(_ornekDuraklar, 'a', 'd')!;
      expect(yolculuk.aktarmaliDuraklar.map((d) => d.kod), ['b']);
    });

    test('süre biçimlendirme', () {
      expect(Yolculuk.sureBicimle(45), '45 dk');
      expect(Yolculuk.sureBicimle(60), '1 sa');
      expect(Yolculuk.sureBicimle(140), '2 sa 20 dk');
    });
  });
}
