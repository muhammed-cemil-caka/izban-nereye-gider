import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../modeller/durak.dart';
import '../modeller/yolculuk.dart';
import '../servisler/rota_servisi.dart';

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
  final Konum? kullaniciKonumu;
  final YuruyusRotasi? yuruyusRotasi;

  /// Yönlendirme sürüyorsa işaret, hareket yönüne dönen bir oka dönüşür.
  final bool yonlendirmede;
  final double? yonAcisi;
  final ValueChanged<Durak> duragaBasildi;
  final ValueChanged<Konum> konumTasindi;

  const HaritaKarti({
    super.key,
    required this.duraklar,
    required this.yolculuk,
    required this.kullaniciKonumu,
    required this.yuruyusRotasi,
    required this.yonlendirmede,
    required this.yonAcisi,
    required this.duragaBasildi,
    required this.konumTasindi,
  });

  @override
  State<HaritaKarti> createState() => _HaritaKartiDurumu();
}

class _HaritaKartiDurumu extends State<HaritaKarti> {
  final _denetleyici = MapController();

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
  Widget build(BuildContext context) {
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
                  if (widget.yuruyusRotasi != null)
                    Polyline(
                      points: widget.yuruyusRotasi!.noktalar
                          .map((k) => LatLng(k.enlem, k.boylam))
                          .toList(),
                      color: _yuruyusRengi,
                      strokeWidth: 5,
                      pattern: StrokePattern.dotted(),
                    ),
                ]),
                MarkerLayer(markers: _durakIsaretleri()),
                if (widget.kullaniciKonumu != null)
                  MarkerLayer(markers: [_konumIsareti(widget.kullaniciKonumu!)]),
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
  Marker _konumIsareti(Konum konum) {
    if (widget.yonlendirmede) {
      return Marker(
        point: LatLng(konum.enlem, konum.boylam),
        width: 38,
        height: 38,
        child: _YonOku(aci: widget.yonAcisi ?? 0),
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

/// Yönlendirme sırasında hareket yönünü gösteren ok.
class _YonOku extends StatelessWidget {
  final double aci;

  const _YonOku({required this.aci});

  @override
  Widget build(BuildContext context) {
    final renkler = Theme.of(context).colorScheme;

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
