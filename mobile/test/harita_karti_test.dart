import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izban_nereye_gider/ekranlar/harita_karti.dart';
import 'package:izban_nereye_gider/modeller/durak.dart';

const _duraklar = <Durak>[
  Durak(
    kod: 'halkapinar',
    ad: 'Halkapınar',
    ilce: 'Konak',
    dakika: 63,
    konum: Konum(enlem: 38.435190, boylam: 27.168837),
  ),
  Durak(
    kod: 'sirinyer',
    ad: 'Şirinyer',
    ilce: 'Buca',
    dakika: 75,
    konum: Konum(enlem: 38.383600, boylam: 27.155600),
  ),
];

/// İki durağın arasında: harita bu iki noktaya oturduğu için iğne haritanın
/// ortasında kalır ve dokunma hedefi tam görünür olur.
const _konum = Konum(enlem: 38.4100, boylam: 27.1620);

/// Kartı, dışarıya bildirilen konumu yakalayacak şekilde kurar.
Future<ValueNotifier<KonumDurumu>> _kartiKur(
  WidgetTester tester, {
  required void Function(Konum) konumTasindi,
  KonumDurumu baslangic = const KonumDurumu(konum: _konum),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(600, 900);
  addTearDown(tester.view.reset);

  final durum = ValueNotifier<KonumDurumu>(baslangic);
  addTearDown(durum.dispose);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: HaritaKarti(
        duraklar: _duraklar,
        yolculuk: null,
        yuruyusRotasi: null,
        konumDurumu: durum,
        duragaBasildi: (_) {},
        konumTasindi: konumTasindi,
      ),
    ),
  ));
  await tester.pump();
  return durum;
}

void main() {
  testWidgets('iğne 2 saniye basılı tutulunca taşınıyor', (tester) async {
    Konum? tasinan;
    await _kartiKur(tester, konumTasindi: (konum) => tasinan = konum);

    final igne = find.byIcon(Icons.place);
    expect(igne, findsOneWidget);

    final hareket = await tester.startGesture(tester.getCenter(igne));
    // İki saniye dolmadan taşıma açılmaz.
    await tester.pump(const Duration(milliseconds: 1500));
    await hareket.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(tasinan, isNull, reason: 'süre dolmadan taşınmamalı');

    await hareket.up();
    await tester.pump();
    expect(tasinan, isNull);

    // Süre dolunca aşağı çekilen iğne konumu güneye taşır.
    final ikinci = await tester.startGesture(tester.getCenter(igne));
    await tester.pump(const Duration(milliseconds: 2100));
    await ikinci.moveBy(const Offset(0, 60));
    await tester.pump();
    await ikinci.up();
    await tester.pump();

    expect(tasinan, isNotNull);
    expect(tasinan!.enlem, lessThan(_konum.enlem));
  });

  testWidgets('basıp hiç oynatmadan bırakmak konumu değiştirmiyor',
      (tester) async {
    Konum? tasinan;
    await _kartiKur(tester, konumTasindi: (konum) => tasinan = konum);

    final hareket =
        await tester.startGesture(tester.getCenter(find.byIcon(Icons.place)));
    await tester.pump(const Duration(milliseconds: 2100));
    await hareket.up();
    await tester.pump();

    expect(tasinan, isNull);
  });

  testWidgets('konum varken "konumuma dön" düğmesi çıkıyor', (tester) async {
    await _kartiKur(tester, konumTasindi: (_) {});
    expect(find.byIcon(Icons.my_location), findsOneWidget);

    // Düğmeye basmak hata vermemeli.
    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pump();
  });

  testWidgets('konum yokken düğme gizli', (tester) async {
    await _kartiKur(
      tester,
      konumTasindi: (_) {},
      baslangic: const KonumDurumu(),
    );
    expect(find.byIcon(Icons.my_location), findsNothing);
  });
}
