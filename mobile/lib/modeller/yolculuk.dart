import '../diller.dart';
import 'durak.dart';

enum Yon { kuzey, guney }

/// İki durak arasındaki hesaplanmış yolculuk.
class Yolculuk {
  final Durak binis;
  final Durak inis;
  final Yon yon;

  /// Hattın ucundaki durağın adı — "Selçuk yönü" / "towards Selçuk" bundan
  /// kurulur. Ham ad taşınıyor ki dil değişince etiket yeniden yazılabilsin.
  final String yonDurakAdi;

  final int durakSayisi;
  final int dakika;
  final List<Durak> guzergah;

  const Yolculuk({
    required this.binis,
    required this.inis,
    required this.yon,
    required this.yonDurakAdi,
    required this.durakSayisi,
    required this.dakika,
    required this.guzergah,
  });

  List<Durak> get aktarmaliDuraklar =>
      guzergah.where((durak) => durak.aktarmaVar).toList();

  /// "Selçuk yönü" / "towards Selçuk"
  String get yonEtiketi =>
      Diller.aktif('yonEtiketi', {'durak': yonDurakAdi});

  String get sureMetni => sureBicimle(dakika);

  static String sureBicimle(int dakika) => Diller.aktif.sure(dakika);

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
      yonDurakAdi: guneyeGidiyor ? duraklar.last.ad : duraklar.first.ad,
      durakSayisi: son - ilk,
      dakika: (duraklar[inisIndeks].dakika - duraklar[binisIndeks].dakika).abs(),
      guzergah: guneyeGidiyor ? guzergah : guzergah.reversed.toList(),
    );
  }
}
