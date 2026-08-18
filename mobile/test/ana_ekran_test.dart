import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izban_nereye_gider/main.dart';
import 'package:izban_nereye_gider/modeller/durak.dart';
import 'package:izban_nereye_gider/servisler/durak_servisi.dart';

const _duraklar = <Durak>[
  Durak(kod: 'aliaga', ad: 'Aliağa', ilce: 'Aliağa', dakika: 0, aktarma: []),
  Durak(kod: 'menemen', ad: 'Menemen', ilce: 'Menemen', dakika: 21, aktarma: []),
  Durak(
    kod: 'halkapinar',
    ad: 'Halkapınar',
    ilce: 'Konak',
    dakika: 58,
    aktarma: ['Metro'],
  ),
  Durak(kod: 'selcuk', ad: 'Selçuk', ilce: 'Selçuk', dakika: 140, aktarma: []),
];

Widget _uygulama() => IzbanUygulamasi(servis: DurakServisi.hazir(_duraklar));

void main() {
  testWidgets('açılışta yolculuk özeti gösteriliyor', (tester) async {
    await tester.pumpWidget(_uygulama());
    await tester.pumpAndSettle();

    expect(find.text('İZBAN Nereye Gider?'), findsOneWidget);
    expect(find.text('Nereden biniyorsun?'), findsOneWidget);
    expect(find.text('Nereye gideceksin?'), findsOneWidget);
    expect(find.text('GÜZERGÂH'), findsOneWidget);

    // Varsayılan seçim uçtan uca: Aliağa → Selçuk
    expect(find.text('Selçuk yönü'), findsOneWidget);
    expect(find.text('2 sa 20 dk'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // durak sayısı
  });

  testWidgets('yer değiştir butonu yönü tersine çevirir', (tester) async {
    await tester.pumpWidget(_uygulama());
    await tester.pumpAndSettle();

    expect(find.text('Selçuk yönü'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();

    expect(find.text('Aliağa yönü'), findsOneWidget);
    expect(find.text('Selçuk yönü'), findsNothing);
    // Süre yön değişse de aynı kalmalı.
    expect(find.text('2 sa 20 dk'), findsOneWidget);
  });
}
