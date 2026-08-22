import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izban_nereye_gider/main.dart';
import 'package:izban_nereye_gider/modeller/durak.dart';
import 'package:izban_nereye_gider/servisler/durak_servisi.dart';
import 'package:izban_nereye_gider/servisler/konum_servisi.dart';

/// Testlerde gerçek GPS yerine sabit sonuç döndüren konum servisi.
class SahteKonumServisi extends KonumServisi {
  final KonumSonucu sonuc;

  const SahteKonumServisi(this.sonuc);

  @override
  Future<KonumSonucu> konumAl() async => sonuc;
}

// Gerçek İZBAN koordinatları — ileride en yakın durak testleri de bunu kullanır.
const _duraklar = <Durak>[
  Durak(
    kod: 'aliaga',
    ad: 'Aliağa',
    ilce: 'Aliağa',
    dakika: 0,
    konum: Konum(enlem: 38.788773, boylam: 26.967164),
  ),
  Durak(
    kod: 'menemen',
    ad: 'Menemen',
    ilce: 'Menemen',
    dakika: 25,
    konum: Konum(enlem: 38.603221, boylam: 27.076514),
  ),
  Durak(
    kod: 'halkapinar',
    ad: 'Halkapınar',
    ilce: 'Konak',
    dakika: 63,
    konum: Konum(enlem: 38.435190, boylam: 27.168837),
    aktarma: ['Metro', 'Tramvay'],
  ),
  Durak(
    kod: 'selcuk',
    ad: 'Selçuk',
    ilce: 'Selçuk',
    dakika: 151,
    konum: Konum(enlem: 37.950734, boylam: 27.373029),
  ),
];

/// Varsayılan: konum reddedilmiş sayılır — konum kartı yolculuk akışını
/// etkilemediği için mevcut testler bundan bağımsız çalışır.
Widget _uygulama({KonumSonucu? konum}) => IzbanUygulamasi(
      servis: DurakServisi.hazir(_duraklar),
      konumServisi: SahteKonumServisi(
        konum ?? const KonumHatasi('Konum izni verilmedi.'),
      ),
    );

/// Ekranı uzun tutar: ListView tembel çizdiği için kısa ekranda alttaki
/// kartlar hiç oluşturulmuyor ve testler onları bulamıyor.
///
/// Dil de sabitlenir: uygulama seçim yoksa cihaz dilini kullanıyor, test
/// ortamının dili İngilizce ve metinler İngilizce çıkıyordu.
void _uzunEkran(WidgetTester tester, {String dil = 'tr'}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1000, 2600);
  tester.platformDispatcher.localeTestValue = Locale(dil);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}

/// Ekrandaki bütün metinleri toplar — dil denetimi için.
List<String> _tumMetinler(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((m) => m.isNotEmpty)
    .toList();

void main() {
  testWidgets('açılışta yolculuk özeti gösteriliyor', (tester) async {
    _uzunEkran(tester);
    await tester.pumpWidget(_uygulama());
    await tester.pumpAndSettle();

    expect(find.text('İZBAN Nereye Gider?'), findsOneWidget);
    expect(find.text('Nereden biniyorsun?'), findsOneWidget);
    expect(find.text('Nereye gideceksin?'), findsOneWidget);
    // Varsayılan seçim uçtan uca: Aliağa → Selçuk
    expect(find.text('Selçuk yönü'), findsOneWidget);
    expect(find.text('2 sa 31 dk'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // durak sayısı

    expect(find.text('GÜZERGÂH'), findsOneWidget);
  });

  testWidgets('yer değiştir butonu yönü tersine çevirir', (tester) async {
    _uzunEkran(tester);
    await tester.pumpWidget(_uygulama());
    await tester.pumpAndSettle();

    expect(find.text('Selçuk yönü'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();

    expect(find.text('Aliağa yönü'), findsOneWidget);
    expect(find.text('Selçuk yönü'), findsNothing);
    // Süre yön değişse de aynı kalmalı.
    expect(find.text('2 sa 31 dk'), findsOneWidget);
  });

  testWidgets('konum reddedilince uygulama çalışmaya devam ediyor', (tester) async {
    _uzunEkran(tester);
    await tester.pumpWidget(_uygulama());
    await tester.pumpAndSettle();

    expect(find.text('Konum izni verilmedi.'), findsOneWidget);
    expect(find.text('Konumumu bul'), findsOneWidget);

    // Yolculuk özeti hâlâ görünüyor olmalı.
    expect(find.text('Selçuk yönü'), findsOneWidget);
    expect(find.text('GÜZERGÂH'), findsOneWidget);
  });

  testWidgets('konum bulununca en yakın durak gösteriliyor', (tester) async {
    _uzunEkran(tester);
    await tester.pumpWidget(_uygulama(
      // Halkapınar'ın ~300 m kuzeyi
      konum: const KonumBulundu(Konum(enlem: 38.4380, boylam: 27.1695), 20),
    ));
    await tester.pumpAndSettle();

    expect(find.text('En yakın durak:'), findsOneWidget);
    expect(find.text('Halkapınar'), findsWidgets);
    expect(find.text('Biniş durağı yap'), findsOneWidget);
    // Yol tarifi iki kiple istenebiliyor.
    expect(find.text('Yürüyerek'), findsOneWidget);
    expect(find.text('Arabayla'), findsOneWidget);

    // Doğruluk yazısı ve alternatif duraklar da görünmeli.
    expect(find.text('Konum doğruluğu ±20 m'), findsOneWidget);
    expect(find.text('Yakındaki diğer duraklar:'), findsOneWidget);
  });

  testWidgets('kaba konumda uyarı gösteriliyor', (tester) async {
    _uzunEkran(tester);
    await tester.pumpWidget(_uygulama(
      konum: const KonumBulundu(Konum(enlem: 38.4380, boylam: 27.1695), 900),
    ));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('en yakın durak şaşabilir'),
      findsOneWidget,
    );
  });

  testWidgets('alternatif durak seçilince biniş değişiyor', (tester) async {
    _uzunEkran(tester);
    await tester.pumpWidget(_uygulama(
      konum: const KonumBulundu(Konum(enlem: 38.4380, boylam: 27.1695), 900),
    ));
    await tester.pumpAndSettle();

    // Halkapınar en yakın; Menemen alternatiflerden biri.
    await tester.tap(find.textContaining('Menemen ·'));
    await tester.pumpAndSettle();

    // Menemen'den Selçuk'a: 151 - 25 = 126 dk
    expect(find.text('2 sa 6 dk'), findsOneWidget);
  });

  testWidgets('biniş durağı yap butonu seçimi değiştiriyor', (tester) async {
    _uzunEkran(tester);
    await tester.pumpWidget(_uygulama(
      konum: const KonumBulundu(Konum(enlem: 38.4380, boylam: 27.1695), 20),
    ));
    await tester.pumpAndSettle();

    // Varsayılan biniş Aliağa; en yakın durak Halkapınar.
    await tester.tap(find.text('Biniş durağı yap'));
    await tester.pumpAndSettle();

    // Halkapınar'dan Selçuk'a: 151 - 63 = 88 dk
    expect(find.text('1 sa 28 dk'), findsOneWidget);
    expect(find.text('Selçuk yönü'), findsOneWidget);
  });

  testWidgets('İngilizce arayüzde durak adları dışında Türkçe kalmıyor',
      (tester) async {
    _uzunEkran(tester, dil: 'en');
    await tester.pumpWidget(_uygulama(
      konum: const KonumBulundu(Konum(enlem: 38.4380, boylam: 27.1695), 900),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ROUTE'), findsOneWidget);
    expect(find.text('towards Selçuk'), findsOneWidget);
    expect(find.text('2 h 31 min'), findsOneWidget);
    expect(find.text('Nearest station:'), findsOneWidget);
    expect(find.textContaining('the nearest station may be off'), findsOneWidget);
    expect(find.text('Other nearby stations:'), findsOneWidget);

    // Durak ve ilçe adları özel isim; onlar dışında Türkçe metin kalmamalı.
    final ozelIsimler = {
      for (final d in _duraklar) ...{d.ad, d.ilce},
      'İZBAN Nereye Gider?',
    };
    final turkce = RegExp('[çğıöşüÇĞİÖŞÜ]');

    for (final metin in _tumMetinler(tester)) {
      if (!turkce.hasMatch(metin)) continue;
      final kalan = ozelIsimler.fold(metin, (m, ad) => m.replaceAll(ad, ''));
      expect(
        turkce.hasMatch(kalan),
        isFalse,
        reason: 'İngilizce arayüzde Türkçe metin: "$metin"',
      );
    }
  });
}
