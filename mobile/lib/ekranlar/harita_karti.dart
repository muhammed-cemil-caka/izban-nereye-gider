import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HapticFeedback;
import 'dart:async';
import 'dart:math' as matematik;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../diller.dart';
import '../modeller/durak.dart';
import '../modeller/yolculuk.dart';
import '../servisler/rota_servisi.dart';

/// Haritanın işaret katmanını besleyen konum bilgisi.
@immutable
class KonumDurumu {
  final Konum? konum;
  final bool yonlendirmede;
  final double? aci;

  /// Rota üzerinde kat edilen mesafe (metre). Yürünen kısım haritada
  /// soluklaştırılır; kullanıcı ilerlediğini gözle görsün.
  final double katEdilenM;

  const KonumDurumu({
    this.konum,
    this.yonlendirmede = false,
    this.aci,
    this.katEdilenM = 0,
  });
}

/// Hattı, durakları ve kullanıcı konumunu gösteren harita.
///
/// Döşeme sunucusu notu: tile.openstreetmap.org bağışlarla dönen bir altyapıdır
/// ve kullanım politikası ağır/ticari kullanımı kısıtlar. Geliştirme ve düşük
/// trafik için uygundur; yayına çıkarken anahtarlı bir sağlayıcıya ya da kendi
/// sunduğumuz döşemelere geçilmelidir.
class HaritaKarti extends StatefulWidget {
  static const dosemeAdresi = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const uygulamaKimligi = 'com.izban.izban_nereye_gider';

  final List<Durak> duraklar;
  final Yolculuk? yolculuk;
  final Rota? yuruyusRotasi;

  /// Kullanıcı konumu ve yönü.
  ///
  /// Düz değer yerine dinlenebilir veriliyor: konum saniyede birkaç kez
  /// değişiyor ve bunu setState ile taşımak tüm ekranı, dolayısıyla döşeme
  /// katmanını yeniden kuruyordu — ekran sürekli yenileniyormuş gibi
  /// görünüyordu. Böylece yalnızca işaret katmanı yeniden çiziliyor.
  final ValueListenable<KonumDurumu> konumDurumu;

  final ValueChanged<Durak> duragaBasildi;
  final ValueChanged<Konum> konumTasindi;

  const HaritaKarti({
    super.key,
    required this.duraklar,
    required this.yolculuk,
    required this.yuruyusRotasi,
    required this.konumDurumu,
    required this.duragaBasildi,
    required this.konumTasindi,
  });

  @override
  State<HaritaKarti> createState() => _HaritaKartiDurumu();
}

class _HaritaKartiDurumu extends State<HaritaKarti>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  // Liste kaydırılıp harita ekrandan çıkınca widget yok ediliyor, geri
  // dönüldüğünde initialCameraFit'e sıfırlanıyordu — kullanıcı her seferinde
  // kendini yeniden bulmak zorunda kalıyordu.
  @override
  bool get wantKeepAlive => true;

  final _denetleyici = MapController();

  /// MapController, harita hazır olmadan kullanılamaz.
  bool _haritaHazir = false;

  static const _yonlendirmeYakinligi = 17.0;

  /// Araçta biraz daha geniş bakış: 17 yaya yakınlığı, sürüşte bir sonraki
  /// kavşak ekrana girmiyor.
  static const _arabaYakinligi = 16.0;

  /// "Konumuma dön" düğmesinin en az açacağı yakınlık. Kullanıcı daha
  /// yakındaysa yakınlığı bozmayız.
  static const _konumaDonYakinligi = 16.0;

  /// Sürekli takip: kamera her karede hedefe doğru yaklaşır.
  ///
  /// Her ölçümde yeni bir animasyon başlatmak, hız sıfırlandığı için takılma
  /// hissi veriyordu. Üstel yumuşatma hedef değişse bile hızı korur.
  Ticker? _takipTikeri;
  LatLng? _kameraHedefNoktasi;
  LatLng? _kameraKonumu;
  double? _kameraHedefYakinlik;
  double? _mevcutYakinlik;
  double? _hedefAci;
  double? _mevcutAci;
  Duration _sonKare = Duration.zero;

  /// Saniyede kapatılan mesafe oranı. Büyük değer daha hızlı yakalar.
  static const _takipHizi = 3.2;
  static const _yakinlikHizi = 2.6;
  static const _donusHizi = 4.0;

  /// Bundan uzağa animasyonla gidilmez: kamera yol boyunca bütün döşemeleri
  /// isterdi, hareket de bitmek bilmezdi.
  static const _uzakSayilanM = 3000.0;

  /// İlk kamera hareketi animasyonsuz olsun: yönlendirme başlar başlamaz
  /// kullanıcıya doğrudan yakınlaşılır.
  bool _yonlendirmeBasladi = false;

  /// Kameranın en son taşındığı nokta.
  Konum? _kameraHedefi;

  /// GPS, kullanıcı dururken bile birkaç metre oynar. Her ölçümde kamerayı
  /// taşımak haritayı sürekli ileri geri kaydırıyor ("ekran gidip geliyor").
  /// Bu eşiğin altındaki oynamalar yok sayılır.
  static const _kameraEsigiM = 8.0;

  /// Haritayı gidiş yönüne çevirme eşiği. Küçük açı oynamalarında harita
  /// döndürülürse baş döndürücü olur.
  static const _donusEsigiDerece = 8.0;

  /* ---------- İğneyi elle taşıma ---------- */

  /// Sürükleme neden LongPressDraggable ile yapılmıyor:
  /// FlutterMap kendi LongPressGestureRecognizer'ını kuruyor ve o, jesti
  /// **500 ms**'de kazanıyor. Arena çözülünce 2 saniyelik sürükleyici
  /// reddediliyor ve iğne hiç kımıldamıyordu — "2 saniye basılı tutunca yeri
  /// değişmiyor" bunun sebebiydi. Listener ham pointer olaylarını dinler,
  /// arenaya hiç girmez; jesti kimin kazandığından etkilenmez.
  ///
  /// Yan fayda: haritanın kendisi de uzun basışta jesti kazandığı için
  /// parmak kayarken harita kaymıyor, iğne serbestçe taşınıyor.
  static const _basiliTutmaSuresi = Duration(seconds: 2);

  /// Basılı tutarken bu kadar pikselden fazla kayma, kullanıcının haritayı
  /// kaydırmak istediği anlamına gelir; taşıma açılmaz.
  static const _basiliTutmaKaymasiPx = 14.0;

  Timer? _basiliTutmaSayaci;
  int? _basiliIsaretci;
  Offset? _basmaNoktasi;
  Offset? _sonIsaretciNoktasi;

  /// Taşımanın açıldığı andaki parmak noktası ve iğnenin konumu.
  Offset? _tasimaBaslangicNoktasi;
  Konum? _tasimaBaslangicKonumu;
  bool _tasimaAktif = false;
  bool _igneOynadi = false;

  /// Taşıma sürerken iğnenin gösterileceği konum. Ayrı tutuluyor: bu sırada
  /// gelen GPS ölçümü parmağın altındaki iğneyi geri çekmesin.
  final _tasinanKonum = ValueNotifier<Konum?>(null);


  /// Pusula yalnızca haritayı döndürmek için dinleniyor. Döndürme imperatif
  /// yapıldığı için setState çağrılmıyor, ekran yeniden çizilmiyor.
  StreamSubscription? _pusula;
  double? _pusulaAcisi;

  static const _hatRengi = Color(0xFF7A8798);
  static const _guzergahRengi = Color(0xFF0B5FA5);
  static const _binisRengi = Color(0xFF0B7A63);
  static const _inisRengi = Color(0xFFB3541E);
  static const _yuruyusRengi = Color(0xFFB3541E);

  /// Araba rotası: kesintisiz mavi şerit. Yürüyüş noktalı çiziliyor;
  /// araç rotasının noktalı olması hem sürerken okunmuyor hem de iki kip
  /// haritada birbirinden ayırt edilemiyordu.
  static const _arabaRengi = Color(0xFF0C4CA3);

  List<LatLng> get _hatNoktalari => widget.duraklar
      .where((d) => d.konum.gecerli)
      .map((d) => LatLng(d.konum.enlem, d.konum.boylam))
      .toList();

  @override
  void initState() {
    super.initState();
    widget.konumDurumu.addListener(_konumDegisti);

    final akis = FlutterCompass.events;
    if (akis != null) {
      _pusula = akis.listen((olay) {
        final aci = olay.heading;
        if (aci == null) return;
        _pusulaAcisi = (aci + 360) % 360;

        // Yalnızca yönlendirme sürerken haritayı çevir.
        if (widget.konumDurumu.value.yonlendirmede) {
          _haritayiYoneCevir(_pusulaAcisi);
        }
      }, onError: (_) { /* pusula yoksa hareket yönü kullanılır */ });
    }
  }

  @override
  void didUpdateWidget(HaritaKarti eski) {
    super.didUpdateWidget(eski);

    if (!identical(widget.konumDurumu, eski.konumDurumu)) {
      eski.konumDurumu.removeListener(_konumDegisti);
      widget.konumDurumu.addListener(_konumDegisti);
    }

    if (!_haritaHazir) return;

    // Yeni yürüyüş rotası geldi: rotanın tamamı ekrana sığsın.
    //
    // Yönlendirme sürerken bu YAPILMAZ: rotadan çıkılıp yeniden hesaplandığında
    // kamera tüm rotayı çerçevelemek için uzaklaşıyor ve harita boyut
    // değiştirmiş gibi görünüyordu. Yürürken kamera kullanıcıda kalır.
    if (widget.yuruyusRotasi != null &&
        widget.yuruyusRotasi != eski.yuruyusRotasi &&
        !widget.konumDurumu.value.yonlendirmede) {
      _rotayiCercevele();
    }
  }

  /// Konum değişti: yalnızca kamerayı taşı. Widget ağacı yeniden çizilmez;
  /// işaret katmanı kendi ValueListenableBuilder'ıyla tazelenir.
  void _konumDegisti() {
    if (!_haritaHazir) return;

    final durum = widget.konumDurumu.value;
    final konum = durum.konum;

    if (!durum.yonlendirmede) {
      _yonlendirmeBasladi = false;
      _kameraHedefi = null;
      _haritayiKuzeyeAl();
      return;
    }
    if (konum == null) return;

    // Gürültüyü ele: kullanıcı gerçekten ilerlemediyse kamera oynamasın.
    final onceki = _kameraHedefi;
    if (_yonlendirmeBasladi &&
        onceki != null &&
        onceki.metreUzaklik(konum) < _kameraEsigiM) {
      return;
    }

    // "Başla" anındaki ilk hareket de yumuşak: eskiden doğrudan move
    // çağrılıyordu, harita hem zıplıyor hem bir anda 17'ye yakınlaşıyordu.
    _kameraHedefi = konum;
    _kamerayiTasi(
      LatLng(konum.enlem, konum.boylam),
      yakinlik: widget.yuruyusRotasi?.kip == RotaKipi.araba
          ? _arabaYakinligi
          : _yonlendirmeYakinligi,
    );
    _yonlendirmeBasladi = true;
    // Pusula varsa telefonun baktığı yön, yoksa hareket yönü.
    _haritayiYoneCevir(_pusulaAcisi ?? durum.aci);
  }

  /// Haritayı gidiş yönüne çevirir: kullanıcının baktığı yön yukarı bakar.
  ///
  /// Google Haritalar'ın navigasyon modundaki davranışı. Ok sabit yukarı
  /// bakar, dönen haritadır — yön duygusu böyle çok daha net.
  void _haritayiYoneCevir(double? aci) {
    if (aci == null) return;

    final onceki = _hedefAci;
    if (onceki != null) {
      final fark = (aci - onceki + 540) % 360 - 180;
      if (fark.abs() < _donusEsigiDerece) return;
    }

    _hedefAci = aci;
    _mevcutAci ??= aci;
    _takibiCalistir();
  }

  @override
  void dispose() {
    _pusula?.cancel();
    widget.konumDurumu.removeListener(_konumDegisti);
    _basiliTutmaSayaci?.cancel();
    _tasinanKonum.dispose();
    _takibiDurdur();
    super.dispose();
  }

  /// Yönlendirme bitince harita kuzey yukarı konumuna döner.
  void _haritayiKuzeyeAl() {
    _hedefAci = null;
    _mevcutAci = null;
    if (_haritaHazir) _denetleyici.rotate(0);
  }

  /// Kamerayı hedefe taşır; hareketi sürekli takip tikeri yürütür.
  ///
  /// [yakinlik] verilirse kamera oraya kadar yumuşayarak yakınlaşır — ama
  /// kullanıcı zaten daha yakındaysa yakınlığı bozulmaz.
  void _kamerayiTasi(LatLng hedef, {double? yakinlik}) {
    final kamera = _denetleyici.camera;
    _kameraHedefNoktasi = hedef;
    _kameraKonumu ??= kamera.center;
    _mevcutYakinlik ??= kamera.zoom;

    if (yakinlik != null) {
      _kameraHedefYakinlik = kamera.zoom < yakinlik ? yakinlik : kamera.zoom;
    }

    final uzaklik = const Distance().distance(_kameraKonumu!, hedef);
    if (uzaklik > _uzakSayilanM) {
      _kameraKonumu = hedef;
      _mevcutYakinlik = _kameraHedefYakinlik ?? kamera.zoom;
      _denetleyici.move(hedef, _mevcutYakinlik!);
      return;
    }

    _takibiCalistir();
  }

  void _takibiCalistir() {
    if (_takipTikeri != null) return;

    _sonKare = Duration.zero;
    _takipTikeri = createTicker(_kare)..start();
  }

  void _takibiDurdur() {
    _takipTikeri?.dispose();
    _takipTikeri = null;
  }

  /// Her karede kamerayı ve açıyı hedefe doğru üstel olarak yaklaştırır.
  void _kare(Duration gecen) {
    if (!_haritaHazir) return;

    final dt = _sonKare == Duration.zero
        ? 1 / 60
        : (gecen - _sonKare).inMicroseconds / 1e6;
    _sonKare = gecen;

    var isVar = false;

    final hedef = _kameraHedefNoktasi;
    if (hedef != null) {
      final mevcut = _kameraKonumu ?? _denetleyici.camera.center;
      // Üstel yumuşatma: kalan mesafenin sabit oranı her saniye kapatılır.
      final k = 1 - matematik.exp(-_takipHizi * dt);
      final yeni = LatLng(
        mevcut.latitude + (hedef.latitude - mevcut.latitude) * k,
        mevcut.longitude + (hedef.longitude - mevcut.longitude) * k,
      );

      // Yakınlık da aynı biçimde yumuşatılır; yoksa "Başla" anında harita
      // bir anda 17'ye sıçrıyordu.
      final hedefYakinlik = _kameraHedefYakinlik;
      var yakinlik = _mevcutYakinlik ?? _denetleyici.camera.zoom;
      if (hedefYakinlik != null) {
        final ky = 1 - matematik.exp(-_yakinlikHizi * dt);
        yakinlik += (hedefYakinlik - yakinlik) * ky;
        if ((hedefYakinlik - yakinlik).abs() > 0.01) isVar = true;
      }

      _kameraKonumu = yeni;
      _mevcutYakinlik = yakinlik;
      _denetleyici.move(yeni, yakinlik);

      // Hedefe yeterince yaklaşınca (yaklaşık 1 m) iş biter.
      if ((hedef.latitude - yeni.latitude).abs() > 1e-5 ||
          (hedef.longitude - yeni.longitude).abs() > 1e-5) {
        isVar = true;
      }
    }

    final hedefAci = _hedefAci;
    if (hedefAci != null) {
      final mevcutAci = _mevcutAci ?? hedefAci;
      // En kısa yön (-180..180)
      final fark = (hedefAci - mevcutAci + 540) % 360 - 180;
      final k = 1 - matematik.exp(-_donusHizi * dt);
      final yeniAci = (mevcutAci + fark * k + 360) % 360;

      _mevcutAci = yeniAci;
      _denetleyici.rotate(-yeniAci);

      if (fark.abs() > 0.3) isVar = true;
    }

    if (!isVar) _takibiDurdur();
  }

  /// Rotayı, kat edilen mesafede ikiye böler.
  static (List<LatLng>, List<LatLng>) _rotayiBol(
    List<Konum> noktalar,
    double katEdilenM,
  ) {
    final tumu = noktalar.map((k) => LatLng(k.enlem, k.boylam)).toList();
    if (katEdilenM <= 0 || tumu.length < 2) return (const [], tumu);

    final gecilen = <LatLng>[tumu.first];
    var toplam = 0.0;

    for (var i = 0; i < noktalar.length - 1; i++) {
      final parca = noktalar[i].metreUzaklik(noktalar[i + 1]);

      if (toplam + parca >= katEdilenM) {
        // Bölme noktası parçanın içinde: oranla araya nokta koy.
        final oran = parca == 0 ? 0.0 : (katEdilenM - toplam) / parca;
        final bolme = LatLng(
          noktalar[i].enlem + (noktalar[i + 1].enlem - noktalar[i].enlem) * oran,
          noktalar[i].boylam + (noktalar[i + 1].boylam - noktalar[i].boylam) * oran,
        );
        gecilen.add(bolme);
        return (gecilen, [bolme, ...tumu.sublist(i + 1)]);
      }

      toplam += parca;
      gecilen.add(tumu[i + 1]);
    }

    return (tumu, const []);
  }

  /// Yürüyüş rotasını, kullanıcı ve hedef görünecek şekilde çerçeveler.
  void _rotayiCercevele() {
    final rota = widget.yuruyusRotasi;
    if (rota == null || rota.noktalar.isEmpty) return;

    _denetleyici.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(
          rota.noktalar.map((k) => LatLng(k.enlem, k.boylam)).toList(),
        ),
        padding: const EdgeInsets.all(36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin gerektiriyor
    final tema = Theme.of(context);
    final noktalar = _hatNoktalari;
    if (noktalar.isEmpty) return const SizedBox.shrink();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Diller.of(context).call('haritaBaslik'),
                    style: tema.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  Diller.of(context).call('haritaIpucu'),
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 320,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _denetleyici,
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(noktalar),
                      padding: const EdgeInsets.all(24),
                    ),
                    minZoom: 7,
                    maxZoom: 18,
                    onMapReady: () {
                      _haritaHazir = true;
                      // Kart, rota hazırken kurulmuş olabilir.
                      if (widget.yuruyusRotasi != null &&
                          !widget.konumDurumu.value.yonlendirmede) {
                        _rotayiCercevele();
                      }
                    },
                    // Haritayı sürüklerken sayfa kaymasın diye dönüşler
                    // sınırlı.
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.doubleTapZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: HaritaKarti.dosemeAdresi,
                      userAgentPackageName: HaritaKarti.uygulamaKimligi,
                      maxZoom: 19,
                    ),
                    PolylineLayer(polylines: [
                      Polyline(
                        points: noktalar,
                        color: _hatRengi,
                        strokeWidth: 3,
                      ),
                      if (widget.yolculuk != null)
                        Polyline(
                          points: widget.yolculuk!.guzergah
                              .where((d) => d.konum.gecerli)
                              .map((d) => LatLng(d.konum.enlem, d.konum.boylam))
                              .toList(),
                          color: _guzergahRengi,
                          strokeWidth: 5,
                        ),
                    ]),

                    // Yürüyüş rotası ayrı katmanda: kat edilen kısım
                    // soluklaşsın diye konum değiştikçe yalnızca bu katman
                    // yeniden çiziliyor.
                    ValueListenableBuilder<KonumDurumu>(
                      valueListenable: widget.konumDurumu,
                      builder: (context, durum, _) {
                        final rota = widget.yuruyusRotasi;
                        if (rota == null) return const SizedBox.shrink();

                        final (gecilen, kalan) =
                            _rotayiBol(rota.noktalar, durum.katEdilenM);

                        // Araba kesintisiz kalın mavi şerit, yürüyüş noktalı
                        // turuncu: haritaya bakınca hangi kipte olunduğu
                        // anlaşılsın, sürerken çizgi kopuk görünmesin.
                        final arabaMi = rota.kip == RotaKipi.araba;
                        final renk = arabaMi ? _arabaRengi : _yuruyusRengi;
                        final kalinlik = arabaMi ? 6.0 : 5.0;
                        final desen =
                            arabaMi ? const StrokePattern.solid() : StrokePattern.dotted();

                        return PolylineLayer(polylines: [
                          if (gecilen.length > 1)
                            Polyline(
                              points: gecilen,
                              color: renk.withValues(alpha: .28),
                              strokeWidth: kalinlik,
                              pattern: desen,
                            ),
                          if (kalan.length > 1)
                            Polyline(
                              points: kalan,
                              color: renk,
                              strokeWidth: kalinlik,
                              pattern: desen,
                            ),
                        ]);
                      },
                    ),
                    MarkerLayer(markers: _durakIsaretleri()),
                    ValueListenableBuilder<KonumDurumu>(
                      valueListenable: widget.konumDurumu,
                      builder: (context, durum, _) {
                        // Taşıma sürerken iğne parmağı takip eder; o
                        // sırada gelen GPS ölçümü iğneyi geri çekmesin.
                        return ValueListenableBuilder<Konum?>(
                          valueListenable: _tasinanKonum,
                          builder: (context, tasinan, _) {
                            final konum = tasinan ?? durum.konum;
                            if (konum == null) return const SizedBox.shrink();
                            return MarkerLayer(markers: [
                              _konumIsareti(durum, konum,
                                  tasiniyor: tasinan != null),
                            ]);
                          },
                        );
                      },
                    ),
                  ],
                ),

                // Haritayı kaydırıp uzaklaşınca konuma dönmek için geri
                // kaydırmaya gerek kalmasın.
                Positioned(
                  top: 12,
                  right: 12,
                  child: _KonumaDonDugmesi(
                    konumDurumu: widget.konumDurumu,
                    basildi: _konumaGeriDon,
                  ),
                ),
              ],
            ),
          ),

          // Leaflet/flutter_map'in kendi katkı kutusu haritanın sağ altını
          // kapatıyordu. İbare ODbL gereği zorunlu olduğu için kaldırılmadı,
          // haritanın altına alındı.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              Diller.of(context).call('haritaKatki'),
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.textTheme.bodySmall?.color?.withValues(alpha: .7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _durakIsaretleri() {
    final binisKod = widget.yolculuk?.binis.kod;
    final inisKod = widget.yolculuk?.inis.kod;

    return widget.duraklar.where((d) => d.konum.gecerli).map((durak) {
      final ucNokta = durak.kod == binisKod || durak.kod == inisKod;
      final renk = durak.kod == binisKod
          ? _binisRengi
          : durak.kod == inisKod
              ? _inisRengi
              : _hatRengi;
      final capi = ucNokta ? 18.0 : 12.0;

      return Marker(
        point: LatLng(durak.konum.enlem, durak.konum.boylam),
        width: capi + 8,
        height: capi + 8,
        child: GestureDetector(
          onTap: () => widget.duragaBasildi(durak),
          child: Tooltip(
            message: durak.ad,
            child: Center(
              child: Container(
                width: capi,
                height: capi,
                decoration: BoxDecoration(
                  color: ucNokta ? renk : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: renk, width: 2),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Konum işareti.
  ///
  /// Normalde taşınabilir bir iğne — GPS şaştığında yeri elle düzeltmenin
  /// yolu. Yönlendirme sırasında yön okuna dönüşür ve taşınamaz olur;
  /// yürürken yanlışlıkla yeri değişmesin.
  Marker _konumIsareti(
    KonumDurumu durum,
    Konum konum, {
    required bool tasiniyor,
  }) {
    if (durum.yonlendirmede) {
      return Marker(
        point: LatLng(konum.enlem, konum.boylam),
        width: 38,
        height: 38,
        // rotate: harita döndüğünde ok ekranda dik kalsın. Gidiş yönü zaten
        // yukarı baktığı için ok da hep yukarıyı gösterir.
        rotate: true,
        child: const _YonOku(),
      );
    }

    return Marker(
      point: LatLng(konum.enlem, konum.boylam),
      width: 44,
      height: 44,
      // İğnenin UCU konumu göstermeli. Varsayılan hizalama işareti noktanın
      // ortasına koyuyor; o zaman uç aşağıda kalıyor ve yakınlaştırma
      // değiştikçe kayma büyüyor.
      alignment: Alignment.topCenter,
      // 2 saniye basılı tutmadan taşınamaz: haritayı kaydırırken parmak
      // işarete değince yanlışlıkla yer değiştiriyordu.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _isaretePasildi,
        onPointerMove: _isaretteHareket,
        onPointerUp: _isaretBirakildi,
        onPointerCancel: _isaretIptalEdildi,
        child: Semantics(
          label: Diller.aktif('haritaKonumBaslikUzun'),
          // Taşımaya açıldığında iğne renk değiştirir: kullanıcı iki saniyenin
          // dolduğunu titreşimin yanında gözle de görsün.
          child: Icon(
            Icons.place,
            size: 44,
            color: tasiniyor ? _inisRengi : _guzergahRengi,
            shadows: tasiniyor
                ? const [Shadow(color: Colors.black45, blurRadius: 12)]
                : null,
          ),
        ),
      ),
    );
  }

  void _isaretePasildi(PointerDownEvent olay) {
    _basiliTutmayiBirak();
    _basiliIsaretci = olay.pointer;
    _basmaNoktasi = olay.position;
    _sonIsaretciNoktasi = olay.position;
    _basiliTutmaSayaci = Timer(_basiliTutmaSuresi, _tasimayiAc);
  }

  /// İki saniye dolunca iğne taşımaya açılır.
  void _tasimayiAc() {
    // Başlangıç, basma anı değil AÇILMA anı: o iki saniyede gelen GPS ölçümü
    // iğneyi kaydırmış olabilir.
    final konum = widget.konumDurumu.value.konum;
    if (_basiliIsaretci == null || konum == null) return;

    _tasimaAktif = true;
    _igneOynadi = false;
    _tasimaBaslangicNoktasi = _sonIsaretciNoktasi ?? _basmaNoktasi;
    _tasimaBaslangicKonumu = konum;
    _tasinanKonum.value = konum;
    HapticFeedback.mediumImpact();
  }

  void _isaretteHareket(PointerMoveEvent olay) {
    if (olay.pointer != _basiliIsaretci) return;
    _sonIsaretciNoktasi = olay.position;

    if (!_tasimaAktif) {
      // Parmak kayıyorsa kullanıcı haritayı kaydırmak istiyordur.
      final basma = _basmaNoktasi;
      if (basma != null &&
          (olay.position - basma).distance > _basiliTutmaKaymasiPx) {
        _basiliTutmayiBirak();
      }
      return;
    }

    final yeni = _ekrandanKonum(olay.position);
    if (yeni == null) return;
    _igneOynadi = true;
    _tasinanKonum.value = yeni;
  }

  void _isaretBirakildi(PointerUpEvent olay) {
    if (olay.pointer != _basiliIsaretci) return;

    final tasindi = _tasimaAktif && _igneOynadi;
    final yeniKonum = _tasinanKonum.value;
    _basiliTutmayiBirak();

    // Yalnızca gerçekten taşındıysa bildir: iki saniye basıp bırakmak konumu
    // değiştirmemeli.
    if (tasindi && yeniKonum != null) widget.konumTasindi(yeniKonum);
  }

  void _isaretIptalEdildi(PointerCancelEvent olay) {
    if (olay.pointer == _basiliIsaretci) _basiliTutmayiBirak();
  }

  void _basiliTutmayiBirak() {
    _basiliTutmaSayaci?.cancel();
    _basiliTutmaSayaci = null;
    _basiliIsaretci = null;
    _basmaNoktasi = null;
    _sonIsaretciNoktasi = null;
    _tasimaBaslangicNoktasi = null;
    _tasimaBaslangicKonumu = null;
    _tasimaAktif = false;
    _igneOynadi = false;
    _tasinanKonum.value = null;
  }

  /// Parmağın kat ettiği yolu iğnenin başlangıç konumuna uygular.
  ///
  /// Parmağın altındaki nokta doğrudan alınmıyor, FARK uygulanıyor: kullanıcı
  /// iğneyi neresinden tuttuysa orası parmağın altında kalır, iğne ele alınır
  /// alınmaz zıplamaz.
  Konum? _ekrandanKonum(Offset isaretci) {
    final baslangicNokta = _tasimaBaslangicNoktasi;
    final baslangicKonum = _tasimaBaslangicKonumu;
    if (!_haritaHazir || baslangicNokta == null || baslangicKonum == null) {
      return null;
    }

    // latLngToScreenOffset ile screenOffsetToLatLng birbirinin tersi; ikisi de
    // haritanın kendi kutusuna göre çalışır ve dönüşü hesaba katar.
    final kamera = _denetleyici.camera;
    final ekran = kamera.latLngToScreenOffset(
      LatLng(baslangicKonum.enlem, baslangicKonum.boylam),
    );
    final nokta = kamera.screenOffsetToLatLng(
      ekran + (isaretci - baslangicNokta),
    );
    return Konum(enlem: nokta.latitude, boylam: nokta.longitude);
  }

  /// Kamerayı kullanıcının konumuna geri getirir.
  ///
  /// Kullanıcı hattın başka bir yerine bakmak için haritayı kaydırdığında
  /// konumuna dönmek için geri kaydırmak zorunda kalmasın. Hareket, takipteki
  /// yumuşatmanın aynısıdır.
  void _konumaGeriDon() {
    final konum = widget.konumDurumu.value.konum;
    if (konum == null || !_haritaHazir) return;

    // Gürültü eşiği yalnızca kendiliğinden gelen ölçümler içindir; düğmeye
    // basıldığında kamera her hâlükârda konuma dönmeli.
    _kameraHedefi = konum;
    _kamerayiTasi(
      LatLng(konum.enlem, konum.boylam),
      yakinlik: _konumaDonYakinligi,
    );
  }
}

/// Haritanın üstünde duran "konumuma dön" düğmesi.
///
/// Kullanıcı hattın başka bir yerine bakmak için haritayı kaydırdığında
/// konumuna dönmek için geri kaydırmak zorunda kalmasın.
class _KonumaDonDugmesi extends StatelessWidget {
  final ValueListenable<KonumDurumu> konumDurumu;
  final VoidCallback basildi;

  const _KonumaDonDugmesi({required this.konumDurumu, required this.basildi});

  @override
  Widget build(BuildContext context) {
    final renkler = Theme.of(context).colorScheme;

    return ValueListenableBuilder<KonumDurumu>(
      valueListenable: konumDurumu,
      builder: (context, durum, _) {
        // Konum yoksa dönülecek yer de yok.
        if (durum.konum == null) return const SizedBox.shrink();

        return Material(
          color: renkler.surface,
          elevation: 3,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: basildi,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Semantics(
                button: true,
                label: Diller.aktif('konumaDon'),
                child: Icon(Icons.my_location, size: 22, color: renkler.primary),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Yönlendirme sırasında konumu gösteren ok.
///
/// Ok dönmez: harita gidiş yönüne çevrildiği için ekranda hep yukarı bakar.
/// Google Haritalar'ın navigasyon modundaki davranış budur.
class _YonOku extends StatelessWidget {
  const _YonOku();

  @override
  Widget build(BuildContext context) {
    final renkler = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: renkler.primary,
        shape: BoxShape.circle,
        border: Border.all(color: renkler.surface, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(Icons.navigation, size: 20, color: renkler.onPrimary),
    );
  }
}
