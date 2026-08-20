import 'dart:async';
import 'dart:math' as matematik;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
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

  /// Anlık hız (m/sn). Kamera kullanıcıyı ortada tuttuğu için ok sabit
  /// duruyormuş gibi görünüyor; bu değer hareketin algılandığını gösterir.
  final double hizMs;

  const YonlendirmeDurumu(
    this.konum,
    this.dogrulukM,
    this.ilerleme,
    this.aci,
    this.hizMs,
  );
}

/// Yürüyüş yönlendirmesi — kullanıcıyı rota üzerinde adım adım takip eder.
///
/// Ücretli bir navigasyon SDK'sı kullanılmıyor: elde OSRM rotası ve cihazın
/// konum akışı var. Buradaki iş, kullanıcının rotanın neresinde olduğunu
/// bulmak, sıradaki manevraya kalan mesafeyi hesaplamak ve rotadan çıkıldığını
/// fark etmek.
class YonlendirmeServisi {
  /// Rotadan çıkma eşiği için taban değer.
  ///
  /// Şehirde GPS ±20-30 m şaşabiliyor; sabit ve dar bir eşik, kullanıcı rota
  /// üzerinde yürürken bile "rotadan çıktın" demeye yol açıyordu. Eşik ölçüm
  /// doğruluğuna göre genişletiliyor.
  static const sapmaTabanEsigiM = 75.0;
  static const sapmaDogrulukCarpani = 3.0;

  /// Sapmanın kaç ölçüm üst üste sürmesi gerektiği.
  static const sapmaSayisi = 5;

  /// Sapma, tek ölçümle değil son ölçümlerin ortalamasıyla değerlendirilir.
  /// Tek bir kötü GPS ölçümü (şehirde sık) yeniden hesaplama tetiklemesin.
  static const sapmaPencereBoyu = 5;

  /// İki yeniden hesaplama arasındaki en kısa süre. Yoksa kötü sinyalde
  /// uygulama sürekli rota isteyip duruyor.
  static const yenidenHesapAraligi = Duration(seconds: 20);

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

  /// Yönlendirme sırasında kullanılacak konum ayarları.
  ///
  /// Android'in birleşik konum sağlayıcısı, aralık açıkça verilmezse
  /// güncellemeleri eliyor ("location delivery blocked - too fast/too close")
  /// ve yürüyüş hızında imleç hiç kıpırdamıyordu. Yönlendirmede her ölçüm
  /// gerekli, bu yüzden mesafe süzgeci sıfır ve aralık kısa tutuluyor.
  static LocationSettings yonlendirmeAyarlari() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
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
    final sonSapmalar = <double>[];
    DateTime? sonYenidenHesap;
    Konum? oncekiKonum;
    double? sonAci;

    return Geolocator.getPositionStream(
      locationSettings: yonlendirmeAyarlari(),
    ).listen(
      (yer) {
        final konum = Konum(enlem: yer.latitude, boylam: yer.longitude);

        // Yön önce ardışık ölçümlerden hesaplanır: her cihazda güvenilirdir.
        // Cihazın kendi başlığı yalnızca açıkça geçerliyse kullanılır — birçok
        // Android cihaz "bilinmiyor" yerine 0 döndürüyor ve buna güvenmek oku
        // sürekli kuzeye çeviriyordu.
        //
        // Önceki konum yalnızca yön hesaplandığında güncellenir; yoksa 5 m'lik
        // eşiğe hiç ulaşılamaz ve küçük adımlar birikmez.
        final onceki = oncekiKonum;
        if (onceki == null) {
          oncekiKonum = konum;
        } else if (onceki.metreUzaklik(konum) >= 5) {
          sonAci = yonAcisi(onceki, konum);
          oncekiKonum = konum;
        } else if (yer.heading > 0 && yer.speed > 0.5) {
          sonAci = yer.heading;
        }

        final ilerleme = ilerlemeHesapla(konum, rota, sinirlar);

        // Eşik ölçüm doğruluğuna göre genişler: ±25 m'lik bir ölçümde 45 m
        // sapma gürültünün içinde kalır, gerçek bir rota terk değildir.
        final esik = matematik.max(
          sapmaTabanEsigiM,
          yer.accuracy * sapmaDogrulukCarpani,
        );

        // Son ölçümlerin ortalaması: ani sıçramalar tek başına karar vermesin.
        sonSapmalar.add(ilerleme.sapmaM);
        if (sonSapmalar.length > sapmaPencereBoyu) sonSapmalar.removeAt(0);
        final ortalamaSapma =
            sonSapmalar.reduce((a, b) => a + b) / sonSapmalar.length;

        if (ortalamaSapma > esik && sonSapmalar.length >= sapmaPencereBoyu) {
          sapmaSayaci++;

          final simdi = DateTime.now();
          final beklemede = sonYenidenHesap != null &&
              simdi.difference(sonYenidenHesap!) < yenidenHesapAraligi;

          if (sapmaSayaci >= sapmaSayisi && !beklemede) {
            sapmaSayaci = 0;
            sonSapmalar.clear();
            sonYenidenHesap = simdi;
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

        durumDegisti(YonlendirmeDurumu(konum, yer.accuracy, ilerleme, sonAci, yer.speed));
      },
      onError: hataOldu,
    );
  }
}
