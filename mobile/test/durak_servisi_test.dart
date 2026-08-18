import 'package:flutter_test/flutter_test.dart';
import 'package:izban_nereye_gider/modeller/durak.dart';
import 'package:izban_nereye_gider/servisler/durak_servisi.dart';

void main() {
  // Bu dosyada tek test var: gerçek assets/duraklar.json paketleniyor mu ve
  // ayrıştırılabiliyor mu, onu doğrular.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Firebase kapalıyken yerel kaynak raporlanıyor', () async {
    final servis = DurakServisi(firestoreKullan: false);
    await servis.duraklariGetir();

    expect(servis.kaynak, VeriKaynagi.yerel);
    expect(servis.kaynakEtiketi, 'yerel kopya');
    expect(servis.surum, isNot('—'));
  });

  test('hazır servis hiç okuma yapmaz', () async {
    final servis = DurakServisi.hazir(const [
      Durak(kod: 'a', ad: 'A', ilce: 'İl', dakika: 0, aktarma: []),
    ], surum: '9.9.9');

    expect((await servis.duraklariGetir()).single.kod, 'a');
    expect(servis.surum, '9.9.9');
  });

  test('assets/duraklar.json okunuyor ve sıralı', () async {
    final duraklar = await DurakServisi(firestoreKullan: false).duraklariGetir();

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
