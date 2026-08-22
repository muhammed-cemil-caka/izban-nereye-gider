import 'package:flutter_test/flutter_test.dart';
import 'package:izban_nereye_gider/diller.dart';
import 'package:izban_nereye_gider/servisler/rota_servisi.dart';

void main() {
  group('manevra Türkçeleştirme', () {
    test('yola çıkış ve varış', () {
      expect(
        RotaServisi.manevrayiTurkcelestir('depart', 'left', '8294. Sokak'),
        'Yola çık — 8294. Sokak',
      );
      expect(RotaServisi.manevrayiTurkcelestir('arrive', null, null), 'Vardın');
    });

    test('dönüşler', () {
      expect(
        RotaServisi.manevrayiTurkcelestir('turn', 'left', '6525. Sokak'),
        'Sola dön — 6525. Sokak',
      );
      expect(
        RotaServisi.manevrayiTurkcelestir('turn', 'slight right', ''),
        'Hafif sağa dön',
      );
      expect(RotaServisi.manevrayiTurkcelestir('turn', null, null), 'Dön');
    });

    test('yolun sonu ve ayrım', () {
      expect(
        RotaServisi.manevrayiTurkcelestir('end of road', 'right', 'Atatürk Cd.'),
        'Yolun sonunda sağa dön — Atatürk Cd.',
      );
      expect(
        RotaServisi.manevrayiTurkcelestir('fork', 'left', null),
        'Ayrımda sola git',
      );
    });

    test('bilinmeyen manevra makul metne düşüyor', () {
      expect(RotaServisi.manevrayiTurkcelestir('notify', null, null), 'Devam et');
    });
  });

  group('biçimlendirme', () {
    Rota rota({double mesafe = 0, double sure = 0}) => Rota(
          noktalar: const [],
          mesafeM: mesafe,
          sureSn: sure,
          adimlar: const [],
        );

    test('mesafe', () {
      expect(rota(mesafe: 450).mesafeMetni, '450 m');
      expect(rota(mesafe: 1389).mesafeMetni, '1,4 km');
    });

    test('süre', () {
      expect(rota(sure: 1140).sureMetni, '19 dk');
      expect(rota(sure: 20).sureMetni, '1 dk');
      expect(rota(sure: 3600).sureMetni, '1 sa');
      expect(rota(sure: 4500).sureMetni, '1 sa 15 dk');
    });
  });

  group('yol adı çevirisi', () {
    tearDown(() => Diller.aktif = const Diller('tr'));

    test('Türkçede yol adı olduğu gibi kalır', () {
      expect(RotaServisi.yolAdiniCevir('6525. Sokak'), '6525. Sokak');
      expect(RotaServisi.yolAdiniCevir('İzmir Çevre Yolu'), 'İzmir Çevre Yolu');
    });

    test('İngilizcede yol türü çevrilir, özel isim kalır', () {
      Diller.aktif = const Diller('en');
      expect(RotaServisi.yolAdiniCevir('Namık Kemal Caddesi'), 'Namık Kemal Avenue');
      expect(RotaServisi.yolAdiniCevir('Atatürk Bulvarı'), 'Atatürk Boulevard');
      expect(RotaServisi.yolAdiniCevir('Cumhuriyet Meydanı'), 'Cumhuriyet Square');
      // "Çevre Yolu" daha genel "Yolu"dan önce denenmeli.
      expect(RotaServisi.yolAdiniCevir('İzmir Çevre Yolu'), 'İzmir Ring Road');
    });

    test('numaralı sokakta numara türden sonra gelir', () {
      Diller.aktif = const Diller('en');
      expect(RotaServisi.yolAdiniCevir('6525. Sokak'), 'Street 6525');
    });

    test('tanınmayan ad dokunulmadan geçer', () {
      Diller.aktif = const Diller('en');
      expect(RotaServisi.yolAdiniCevir('Kordon'), 'Kordon');
      expect(RotaServisi.yolAdiniCevir(null), '');
    });
  });

  group('adım metni okunduğu anda çevrilir', () {
    tearDown(() => Diller.aktif = const Diller('tr'));

    test('dil değişince eldeki rotanın adımı da değişir', () {
      const adim = RotaAdimi(tur: 'turn', yonKodu: 'left', yolAdi: '6525. Sokak', mesafeM: 40);
      expect(adim.metin, 'Sola dön — 6525. Sokak');

      Diller.aktif = const Diller('en');
      expect(adim.metin, 'Turn left — Street 6525');
    });
  });
}
