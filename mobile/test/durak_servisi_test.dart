import 'package:flutter_test/flutter_test.dart';
import 'package:izban_nereye_gider/servisler/durak_servisi.dart';

void main() {
  // Bu dosyada tek test var: gerçek assets/duraklar.json paketleniyor mu ve
  // ayrıştırılabiliyor mu, onu doğrular.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('assets/duraklar.json okunuyor ve sıralı', () async {
    final duraklar = await DurakServisi().duraklariGetir();

    expect(duraklar.length, greaterThan(20));
    expect(duraklar.first.ad, 'Aliağa');
    expect(duraklar.last.ad, 'Selçuk');

    // Kümülatif dakikalar kuzeyden güneye artan olmalı.
    for (var i = 1; i < duraklar.length; i++) {
      expect(
        duraklar[i].dakika,
        greaterThan(duraklar[i - 1].dakika),
        reason: '${duraklar[i].ad} önceki duraktan sonra gelmeli',
      );
    }
  });
}
