import 'dart:async';
import 'dart:math' as matematik;
import 'package:geolocator/geolocator.dart';
import '../modeller/durak.dart';
import 'rota_servisi.dart';

/// Kullanıcının rota üzerindeki anlık durumu.
class RotaIlerlemesi {
  final double katEdilenM;
  final double kalanM;
  final double sapmaM;
  final int adimIndeksi;
  final double sonrakiManevraM;
  final bool vardiMi;

  const RotaIlerlemesi({
    required this.katEdilenM,
    required this.kalanM,
    required this.sapmaM,
    required this.adimIndeksi,
    required this.sonrakiManevraM,
    required this.vardiMi,
  });
}

/// Yönlendirme oturumunun kullanıcıya yansıyan durumu.
class YonlendirmeDurumu {
  final Konum konum;
  final double dogrulukM;
  final RotaIlerlemesi ilerleme;

  /// Hareket yönü (kuzeyden saat yönünde derece); bilinmiyorsa null.
  final double? aci;

  const YonlendirmeDurumu(this.konum, this.dogrulukM, this.ilerleme, this.aci);
}

/// Yürüyüş yönlendirmesi — kullanıcıyı rota üzerinde adım adım takip eder.
///
/// Ücretli bir navigasyon SDK'sı kullanılmıyor: elde OSRM rotası ve cihazın
/// konum akışı var. Buradaki iş, kullanıcının rotanın neresinde olduğunu
/// bulmak, sıradaki manevraya kalan mesafeyi hesaplamak ve rotadan çıkıldığını
/// fark etmek.
class YonlendirmeServisi {
  static const sapmaEsigiM = 45.0;
  static const sapmaSayisi = 3;
  static const varisEsigiM = 25.0;

  /// İki nokta arasındaki yön açısı (kuzeyden saat yönünde derece).
  static double yonAcisi(Konum baslangic, Konum bitis) {
    const p = matematik.pi / 180;
    final enlem1 = baslangic.enlem * p;
    final enlem2 = bitis.enlem * p;
    final dBoylam = (bitis.boylam - baslangic.boylam) * p;

    final y = matematik.sin(dBoylam) * matematik.cos(enlem2);
    final x = matematik.cos(enlem1) * matematik.sin(enlem2) -
        matematik.sin(enlem1) * matematik.cos(enlem2) * matematik.cos(dBoylam);

    return (matematik.atan2(y, x) * 180 / matematik.pi + 360) % 360;
  }

  /// Coğrafi konumu referansa göre metre düzlemine taşır.
  static ({double x, double y}) _metreyeTasi(Konum konum, Konum referans) {
    const p = matematik.pi / 180;
    return (
      x: (konum.boylam - referans.boylam) * 111320 * matematik.cos(referans.enlem * p),
      y: (konum.enlem - referans.enlem) * 110574,
    );
  }

  /// Noktayı rota çizgisine izdüşürür.
  static ({double sapmaM, double katEdilenM, double toplamM}) rotayaIzdusur(
    Konum konum,
    List<Konum> noktalar,
  ) {
    if (noktalar.length < 2) {
      return (sapmaM: 0, katEdilenM: 0, toplamM: 0);
    }

    final referans = noktalar.first;
    final nokta = _metreyeTasi(konum, referans);

    var enIyiSapma = double.infinity;
    var enIyiKatEdilen = 0.0;
    var toplam = 0.0;

    for (var i = 0; i < noktalar.length - 1; i++) {
      final a = _metreyeTasi(noktalar[i], referans);
      final b = _metreyeTasi(noktalar[i + 1], referans);

      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final uzunluk = matematik.sqrt(dx * dx + dy * dy);

      // Sıfır uzunluklu parçalar atlanır, sıfıra bölme olmasın.
      if (uzunluk < 0.01) continue;

      var oran = ((nokta.x - a.x) * dx + (nokta.y - a.y) * dy) / (uzunluk * uzunluk);
      oran = oran.clamp(0.0, 1.0);

      final izx = a.x + oran * dx;
      final izy = a.y + oran * dy;
      final sapma = matematik.sqrt(
        (nokta.x - izx) * (nokta.x - izx) + (nokta.y - izy) * (nokta.y - izy),
      );

      if (sapma < enIyiSapma) {
        enIyiSapma = sapma;
        enIyiKatEdilen = toplam + oran * uzunluk;
      }

      toplam += uzunluk;
    }

    return (sapmaM: enIyiSapma, katEdilenM: enIyiKatEdilen, toplamM: toplam);
  }

  /// Adımların bitiş noktalarını kümülatif mesafeye çevirir.
  static List<double> adimSinirlariniKur(List<RotaAdimi> adimlar) {
    var toplam = 0.0;
    return adimlar.map((adim) => toplam += adim.mesafeM).toList();
  }

  /// Kullanıcının rota üzerindeki durumunu hesaplar.
  static RotaIlerlemesi ilerlemeHesapla(
    Konum konum,
    YuruyusRotasi rota,
    List<double> adimSinirlari,
  ) {
    final izdusum = rotayaIzdusur(konum, rota.noktalar);
    final toplam = izdusum.toplamM > 0 ? izdusum.toplamM : rota.mesafeM;
    final kalan = matematik.max(0.0, toplam - izdusum.katEdilenM);

    var adimIndeksi = 0;
    while (adimIndeksi < adimSinirlari.length - 1 &&
        izdusum.katEdilenM >= adimSinirlari[adimIndeksi]) {
      adimIndeksi++;
    }

    final sonraki = adimSinirlari.isEmpty
        ? 0.0
        : matematik.max(0.0, adimSinirlari[adimIndeksi] - izdusum.katEdilenM);

    return RotaIlerlemesi(
      katEdilenM: izdusum.katEdilenM,
      kalanM: kalan,
      sapmaM: izdusum.sapmaM,
      adimIndeksi: adimIndeksi,
      sonrakiManevraM: sonraki,
      vardiMi: kalan <= varisEsigiM,
    );
  }

  /// Yönlendirme oturumu başlatır.
  ///
  /// [rotadanCikildi] rotadan çıkıldığında yeni konumla çağrılır; çağıran
  /// taraf yeni rota isteyip oturumu yeniden başlatmalıdır.
  static StreamSubscription<Position> baslat({
    required YuruyusRotasi rota,
    required void Function(YonlendirmeDurumu) durumDegisti,
    required void Function(Konum) rotadanCikildi,
    required void Function() varildi,
    required void Function(Object) hataOldu,
  }) {
    final sinirlar = adimSinirlariniKur(rota.adimlar);
    var sapmaSayaci = 0;
    Konum? oncekiKonum;
    double? sonAci;

    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(
      (yer) {
        final konum = Konum(enlem: yer.latitude, boylam: yer.longitude);

        // Yön: cihaz veriyorsa onu kullan, yoksa ardışık ölçümlerden çıkar.
        // Çok küçük hareketlerde açı gürültülü olur, eski açı korunur.
        final onceki = oncekiKonum;
        if (yer.heading != 0 || yer.speed > 0.5) {
          sonAci = yer.heading;
        } else if (onceki != null && onceki.metreUzaklik(konum) >= 5) {
          sonAci = yonAcisi(onceki, konum);
        }
        oncekiKonum = konum;

        final ilerleme = ilerlemeHesapla(konum, rota, sinirlar);

        // Tek bir kötü ölçüm yeniden hesaplamayı tetiklemesin.
        if (ilerleme.sapmaM > sapmaEsigiM) {
          sapmaSayaci++;
          if (sapmaSayaci >= sapmaSayisi) {
            sapmaSayaci = 0;
            rotadanCikildi(konum);
            return;
          }
        } else {
          sapmaSayaci = 0;
        }

        if (ilerleme.vardiMi) {
          varildi();
          return;
        }

        durumDegisti(YonlendirmeDurumu(konum, yer.accuracy, ilerleme, sonAci));
      },
      onError: hataOldu,
    );
  }
}
