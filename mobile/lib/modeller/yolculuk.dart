import 'durak.dart';

enum Yon { kuzey, guney }

/// İki durak arasındaki hesaplanmış yolculuk.
class Yolculuk {
  final Durak binis;
  final Durak inis;
  final Yon yon;
  final String yonEtiketi;
  final int durakSayisi;
  final int dakika;
  final List<Durak> guzergah;

  const Yolculuk({
    required this.binis,
    required this.inis,
    required this.yon,
    required this.yonEtiketi,
    required this.durakSayisi,
    required this.dakika,
    required this.guzergah,
  });

  List<Durak> get aktarmaliDuraklar =>
      guzergah.where((durak) => durak.aktarmaVar).toList();

  String get sureMetni => sureBicimle(dakika);

  static String sureBicimle(int dakika) {
    if (dakika < 60) return '$dakika dk';
    final saat = dakika ~/ 60;
    final kalan = dakika % 60;
    return kalan == 0 ? '$saat sa' : '$saat sa $kalan dk';
  }

  /// Duraklar kuzeyden güneye sıralı geldiği için indeks karşılaştırması yeterli.
  static Yolculuk? hesapla(List<Durak> duraklar, String binisKod, String inisKod) {
    final binisIndeks = duraklar.indexWhere((d) => d.kod == binisKod);
    final inisIndeks = duraklar.indexWhere((d) => d.kod == inisKod);

    if (binisIndeks == -1 || inisIndeks == -1 || binisIndeks == inisIndeks) {
      return null;
    }

    final guneyeGidiyor = inisIndeks > binisIndeks;
    final ilk = binisIndeks < inisIndeks ? binisIndeks : inisIndeks;
    final son = binisIndeks < inisIndeks ? inisIndeks : binisIndeks;

    final guzergah = duraklar.sublist(ilk, son + 1);

    return Yolculuk(
      binis: duraklar[binisIndeks],
      inis: duraklar[inisIndeks],
      yon: guneyeGidiyor ? Yon.guney : Yon.kuzey,
      yonEtiketi: guneyeGidiyor
          ? '${duraklar.last.ad} yönü'
          : '${duraklar.first.ad} yönü',
      durakSayisi: son - ilk,
      dakika: (duraklar[inisIndeks].dakika - duraklar[binisIndeks].dakika).abs(),
      guzergah: guneyeGidiyor ? guzergah : guzergah.reversed.toList(),
    );
  }
}
