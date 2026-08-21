import 'package:flutter_test/flutter_test.dart';
import 'package:izban_nereye_gider/modeller/durak.dart';
import 'package:izban_nereye_gider/servisler/rota_servisi.dart';
import 'package:izban_nereye_gider/servisler/yonlendirme_servisi.dart';

// Doğu yönünde uzanan düz bir rota: 38.48 enleminde, yaklaşık 1 km.
final _duzRota = Rota(
  noktalar: const [
    Konum(enlem: 38.48, boylam: 27.0),
    Konum(enlem: 38.48, boylam: 27.00575),
    Konum(enlem: 38.48, boylam: 27.0115),
  ],
  mesafeM: 1000,
  sureSn: 720,
  adimlar: const [
    RotaAdimi('Yola çık', 500),
    RotaAdimi('Sağa dön', 400),
    RotaAdimi('Vardın', 100),
  ],
);

void main() {
  final sinirlar = YonlendirmeServisi.adimSinirlariniKur(_duzRota.adimlar);

  group('geometri', () {
    test('adım sınırları kümülatif', () {
      expect(sinirlar, [500.0, 900.0, 1000.0]);
    });

    test('rota üzerindeki nokta sıfıra yakın sapma veriyor', () {
      final iz = YonlendirmeServisi.rotayaIzdusur(
        const Konum(enlem: 38.48, boylam: 27.00575),
        _duzRota.noktalar,
      );
      expect(iz.sapmaM, lessThan(1));
      expect(iz.katEdilenM, closeTo(500, 25));
    });

    test('rotadan uzaklaşan nokta sapma veriyor', () {
      final iz = YonlendirmeServisi.rotayaIzdusur(
        const Konum(enlem: 38.4809, boylam: 27.00575),
        _duzRota.noktalar,
      );
      expect(iz.sapmaM, greaterThan(80));
      expect(iz.sapmaM, lessThan(120));
    });

    test('üst üste binen noktalar sıfıra bölmeye yol açmıyor', () {
      final iz = YonlendirmeServisi.rotayaIzdusur(
        const Konum(enlem: 38.48, boylam: 27.002),
        const [
          Konum(enlem: 38.48, boylam: 27.0),
          Konum(enlem: 38.48, boylam: 27.0),
          Konum(enlem: 38.48, boylam: 27.0115),
        ],
      );
      expect(iz.sapmaM.isFinite, isTrue);
      expect(iz.katEdilenM.isFinite, isTrue);
    });

    test('tek noktalı rota çökmüyor', () {
      final iz = YonlendirmeServisi.rotayaIzdusur(
        const Konum(enlem: 38.48, boylam: 27.0),
        const [Konum(enlem: 38.48, boylam: 27.0)],
      );
      expect(iz.katEdilenM, 0);
    });
  });

  group('yön açısı', () {
    const merkez = Konum(enlem: 38.48, boylam: 27.0);

    test('ana yönlerde doğru', () {
      expect(YonlendirmeServisi.yonAcisi(merkez, const Konum(enlem: 38.49, boylam: 27.0)),
          closeTo(0, 1));
      expect(YonlendirmeServisi.yonAcisi(merkez, const Konum(enlem: 38.48, boylam: 27.01)),
          closeTo(90, 1));
      expect(YonlendirmeServisi.yonAcisi(merkez, const Konum(enlem: 38.47, boylam: 27.0)),
          closeTo(180, 1));
      expect(YonlendirmeServisi.yonAcisi(merkez, const Konum(enlem: 38.48, boylam: 26.99)),
          closeTo(270, 1));
    });

    test('0-360 aralığında kalıyor', () {
      for (final hedef in const [
        Konum(enlem: 38.49, boylam: 26.99),
        Konum(enlem: 38.47, boylam: 27.01),
        Konum(enlem: 38.485, boylam: 27.005),
      ]) {
        final aci = YonlendirmeServisi.yonAcisi(merkez, hedef);
        expect(aci, greaterThanOrEqualTo(0));
        expect(aci, lessThan(360));
      }
    });
  });

  group('ilerleme', () {
    test('ilk adımdayken doğru adım ve manevra mesafesi', () {
      final i = YonlendirmeServisi.ilerlemeHesapla(
        const Konum(enlem: 38.48, boylam: 27.002875),
        _duzRota,
        sinirlar,
      );
      expect(i.adimIndeksi, 0);
      expect(i.sonrakiManevraM, closeTo(250, 30));
      expect(i.vardiMi, isFalse);
    });

    test('ikinci adıma geçiş algılanıyor', () {
      final i = YonlendirmeServisi.ilerlemeHesapla(
        const Konum(enlem: 38.48, boylam: 27.008),
        _duzRota,
        sinirlar,
      );
      expect(i.adimIndeksi, 1);
    });

    test('hedefe yaklaşınca varış algılanıyor', () {
      final i = YonlendirmeServisi.ilerlemeHesapla(
        const Konum(enlem: 38.48, boylam: 27.0115),
        _duzRota,
        sinirlar,
      );
      expect(i.vardiMi, isTrue);
      expect(i.kalanM, lessThan(25));
    });

    test('kalan mesafe ilerledikçe azalıyor', () {
      final bas = YonlendirmeServisi.ilerlemeHesapla(
        const Konum(enlem: 38.48, boylam: 27.0), _duzRota, sinirlar);
      final orta = YonlendirmeServisi.ilerlemeHesapla(
        const Konum(enlem: 38.48, boylam: 27.00575), _duzRota, sinirlar);
      expect(orta.kalanM, lessThan(bas.kalanM));
    });
  });
}
