import 'package:flutter/material.dart';
import 'ekranlar/ana_ekran.dart';
import 'servisler/durak_servisi.dart';
import 'servisler/konum_servisi.dart';

void main() {
  runApp(const IzbanUygulamasi());
}

class IzbanUygulamasi extends StatelessWidget {
  /// Testler hazır veri geçebilsin diye dışarıdan verilebilir.
  final DurakServisi? servis;

  /// Testler sahte konum servisi geçebilir.
  final KonumServisi? konumServisi;

  const IzbanUygulamasi({super.key, this.servis, this.konumServisi});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İZBAN Nereye Gider?',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5FA5)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5FA5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: AnaEkran(servis: servis, konumServisi: konumServisi),
    );
  }
}
