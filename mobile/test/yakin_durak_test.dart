import 'package:flutter_test/flutter_test.dart';
import 'package:izban_nereye_gider/modeller/durak.dart';
import 'package:izban_nereye_gider/modeller/yakin_durak.dart';

// Gerçek İZBAN koordinatları
const _halkapinar = Durak(
  kod: 'halkapinar',
  ad: 'Halkapınar',
  ilce: 'Konak',
  dakika: 63,
  konum: Konum(enlem: 38.435190, boylam: 27.168837),
);
const _alsancak = Durak(
  kod: 'alsancak-gar',
  ad: 'Alsancak Gar',
  ilce: 'Konak',
  dakika: 65,
  konum: Konum(enlem: 38.438597, boylam: 27.148762),
);
const _selcuk = Durak(
  kod: 'selcuk',
  ad: 'Selçuk',
  ilce: 'Selçuk',
  dakika: 151,
  konum: Konum(enlem: 37.950734, boylam: 27.373029),
);
const _koordinatsiz = Durak(
  kod: 'yok',
  ad: 'Koordinatsız',
  ilce: '—',
  dakika: 10,
  konum: Konum(enlem: 0, boylam: 0),
);

const _duraklar = [_halkapinar, _alsancak, _selcuk];

void main() {
  group('mesafe', () {
    test('Halkapınar–Alsancak Gar arası bilinen aralıkta', () {
      final m = _halkapinar.konum.metreUzaklik(_alsancak.konum);
      expect(m, greaterThan(1500));
      expect(m, lessThan(2100));
    });

    test('aynı noktanın mesafesi sıfır', () {
      expect(_halkapinar.konum.metreUzaklik(_halkapinar.konum), closeTo(0, 0.001));
    });

    test('mesafe simetrik', () {
      expect(
        _halkapinar.konum.metreUzaklik(_selcuk.konum),
        closeTo(_selcuk.konum.metreUzaklik(_halkapinar.konum), 0.001),
      );
    });
  });

  group('YakinDurak.bul', () {
    test('en yakın durağı seçiyor', () {
      final sonuc = YakinDurak.bul(_duraklar, const Konum(enlem: 38.4380, boylam: 27.1695));
      expect(sonuc!.durak.kod, 'halkapinar');
      expect(sonuc.mesafeM, lessThan(500));
    });

    test('uzak konumda da doğru durağı buluyor', () {
      final sonuc = YakinDurak.bul(_duraklar, const Konum(enlem: 37.96, boylam: 27.37));
      expect(sonuc!.durak.kod, 'selcuk');
    });

    test('koordinatsız duraklar atlanıyor', () {
      final sonuc = YakinDurak.bul(
        [_koordinatsiz, _halkapinar],
        const Konum(enlem: 38.44, boylam: 27.17),
      );
      expect(sonuc!.durak.kod, 'halkapinar');
    });

    test('aday yoksa null döner', () {
      expect(YakinDurak.bul(const [], const Konum(enlem: 38.4, boylam: 27.1)), isNull);
      expect(
        YakinDurak.bul([_koordinatsiz], const Konum(enlem: 38.4, boylam: 27.1)),
        isNull,
      );
    });
  });

  group('biçimlendirme ve bağlantı', () {
    test('mesafe metni', () {
      expect(const YakinDurak(_halkapinar, 450).mesafeMetni, '450 m');
      expect(const YakinDurak(_halkapinar, 999).mesafeMetni, '999 m');
      expect(const YakinDurak(_halkapinar, 2300).mesafeMetni, '2,3 km');
    });

    test('yol tarifi adresi yürüyüş modunda ve doğru hedefte', () {
      final adres = const YakinDurak(_halkapinar, 100).yolTarifiAdresi.toString();
      expect(adres, startsWith('https://www.google.com/maps/dir/?api=1'));
      expect(adres, contains('destination=38.43519,27.168837'));
      expect(adres, contains('travelmode=walking'));
    });
  });
}
