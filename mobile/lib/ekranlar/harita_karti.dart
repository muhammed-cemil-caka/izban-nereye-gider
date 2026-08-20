import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  final YuruyusRotasi? yuruyusRotasi;

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

  AnimationController? _kameraAnimasyonu;

  /// İlk kamera hareketi animasyonsuz olsun: yönlendirme başlar başlamaz
  /// kullanıcıya doğrudan yakınlaşılır.
  bool _yonlendirmeBasladi = false;

  /// Kameranın en son taşındığı nokta.
  Konum? _kameraHedefi;

  /// GPS, kullanıcı dururken bile birkaç metre oynar. Her ölçümde kamerayı
  /// taşımak haritayı sürekli ileri geri kaydırıyor ("ekran gidip geliyor").
  /// Bu eşiğin altındaki oynamalar yok sayılır.
  static const _kameraEsigiM = 12.0;

  static const _hatRengi = Color(0xFF7A8798);
  static const _guzergahRengi = Color(0xFF0B5FA5);
  static const _binisRengi = Color(0xFF0B7A63);
  static const _inisRengi = Color(0xFFB3541E);
  static const _yuruyusRengi = Color(0xFFB3541E);

  List<LatLng> get _hatNoktalari => widget.duraklar
      .where((d) => d.konum.gecerli)
      .map((d) => LatLng(d.konum.enlem, d.konum.boylam))
      .toList();

  @override
  void initState() {
    super.initState();
    widget.konumDurumu.addListener(_konumDegisti);
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

    _kameraHedefi = konum;
    _kamerayiTasi(
      LatLng(konum.enlem, konum.boylam),
      animasyonlu: _yonlendirmeBasladi,
    );
    _yonlendirmeBasladi = true;
  }

  /// Kamerayı hedefe taşır.
  ///
  /// Yönlendirme sırasında her ölçümde doğrudan move çağırmak haritayı
  /// zıplatıyordu; hareket araya animasyon konarak yumuşatılıyor.
  void _kamerayiTasi(LatLng hedef, {required bool animasyonlu}) {
    _kameraAnimasyonu?.dispose();
    _kameraAnimasyonu = null;

    // Kullanıcı uzaklaştırdıysa yakınlaştırmasını zorla değiştirme.
    final yakinlik = _denetleyici.camera.zoom < _yonlendirmeYakinligi
        ? _yonlendirmeYakinligi
        : _denetleyici.camera.zoom;

    if (!animasyonlu) {
      _denetleyici.move(hedef, yakinlik);
      return;
    }

    final baslangic = _denetleyici.camera.center;
    final denetleyici = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final egri = CurvedAnimation(parent: denetleyici, curve: Curves.easeInOut);

    denetleyici.addListener(() {
      final t = egri.value;
      _denetleyici.move(
        LatLng(
          baslangic.latitude + (hedef.latitude - baslangic.latitude) * t,
          baslangic.longitude + (hedef.longitude - baslangic.longitude) * t,
        ),
        yakinlik,
      );
    });

    _kameraAnimasyonu = denetleyici;
    denetleyici.forward();
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
                Text('HARİTA', style: tema.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  'Durağa dokun · konum işaretini basılı tutup sürükle',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 320,
            child: FlutterMap(
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
                // Haritayı sürüklerken sayfanın kaymaması için dönüşler sınırlı.
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
                  Polyline(points: noktalar, color: _hatRengi, strokeWidth: 3),
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

                // Yürüyüş rotası ayrı katmanda: kat edilen kısım soluklaşsın
                // diye konum değiştikçe yalnızca bu katman yeniden çiziliyor.
                ValueListenableBuilder<KonumDurumu>(
                  valueListenable: widget.konumDurumu,
                  builder: (context, durum, _) {
                    final rota = widget.yuruyusRotasi;
                    if (rota == null) return const SizedBox.shrink();

                    final (gecilen, kalan) =
                        _rotayiBol(rota.noktalar, durum.katEdilenM);

                    return PolylineLayer(polylines: [
                      if (gecilen.length > 1)
                        Polyline(
                          points: gecilen,
                          color: _yuruyusRengi.withValues(alpha: .28),
                          strokeWidth: 5,
                          pattern: StrokePattern.dotted(),
                        ),
                      if (kalan.length > 1)
                        Polyline(
                          points: kalan,
                          color: _yuruyusRengi,
                          strokeWidth: 5,
                          pattern: StrokePattern.dotted(),
                        ),
                    ]);
                  },
                ),
                MarkerLayer(markers: _durakIsaretleri()),
                ValueListenableBuilder<KonumDurumu>(
                  valueListenable: widget.konumDurumu,
                  builder: (context, durum, _) {
                    final konum = durum.konum;
                    if (konum == null) return const SizedBox.shrink();
                    return MarkerLayer(markers: [_konumIsareti(durum, konum)]);
                  },
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap katkıcıları',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
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
  /// Normalde sürüklenebilir bir iğne — GPS şaştığında yeri elle düzeltmenin
  /// yolu. Yönlendirme sırasında yön okuna dönüşür ve sürüklenemez olur;
  /// yürürken yanlışlıkla taşınmasın.
  Marker _konumIsareti(KonumDurumu durum, Konum konum) {
    if (durum.yonlendirmede) {
      return Marker(
        point: LatLng(konum.enlem, konum.boylam),
        width: 38,
        height: 38,
        child: _YonOku(aci: durum.aci ?? 0),
      );
    }

    return Marker(
      point: LatLng(konum.enlem, konum.boylam),
      width: 44,
      height: 44,
      child: Draggable<bool>(
        feedback: const Icon(Icons.place, size: 44, color: _guzergahRengi),
        childWhenDragging: const SizedBox.shrink(),
        onDragEnd: (ayrinti) => _isaretiTasi(ayrinti.offset),
        child: const Icon(Icons.place, size: 44, color: _guzergahRengi),
      ),
    );
  }

  /// Ekran koordinatını coğrafi koordinata çevirip yukarı bildirir.
  void _isaretiTasi(Offset ekranNoktasi) {
    final kutu = context.findRenderObject() as RenderBox?;
    if (kutu == null) return;

    // Draggable global koordinat verir; ikonun sol üstü değil ucu esas alınır.
    final yerel = kutu.globalToLocal(ekranNoktasi + const Offset(22, 44));
    final nokta = _denetleyici.camera.screenOffsetToLatLng(yerel);
    widget.konumTasindi(Konum(enlem: nokta.latitude, boylam: nokta.longitude));
  }
}

/// Yönlendirme sırasında yönü gösteren ok.
///
/// Pusulayı kendi içinde dinler: telefon çevrildiğinde yalnızca bu widget
/// yeniden çizilir, harita ve sayfanın kalanı etkilenmez. Cihazda manyetometre
/// yoksa dışarıdan gelen hareket yönü kullanılır.
class _YonOku extends StatefulWidget {
  final double aci;

  const _YonOku({required this.aci});

  @override
  State<_YonOku> createState() => _YonOkuDurumu();
}

class _YonOkuDurumu extends State<_YonOku> {
  StreamSubscription? _pusula;
  double? _pusulaAcisi;

  @override
  void initState() {
    super.initState();

    final akis = FlutterCompass.events;
    if (akis == null) return;

    _pusula = akis.listen((olay) {
      final aci = olay.heading;
      if (aci == null || !mounted) return;

      // Küçük sapmalarda yeniden çizme; ok titremesin, pil yanmasın.
      final onceki = _pusulaAcisi;
      if (onceki != null && (aci - onceki).abs() < 4) return;

      setState(() => _pusulaAcisi = (aci + 360) % 360);
    }, onError: (_) { /* pusula yoksa sessizce geç */ });
  }

  @override
  void dispose() {
    _pusula?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renkler = Theme.of(context).colorScheme;
    final aci = _pusulaAcisi ?? widget.aci;

    return AnimatedRotation(
      turns: aci / 360,
      duration: const Duration(milliseconds: 250),
      child: Container(
        decoration: BoxDecoration(
          color: renkler.primary,
          shape: BoxShape.circle,
          border: Border.all(color: renkler.surface, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(Icons.navigation, size: 20, color: renkler.onPrimary),
      ),
    );
  }
}
