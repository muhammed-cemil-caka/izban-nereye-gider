import 'dart:math' as matematik;
import 'package:flutter/material.dart';

/// İZBAN markası.
///
/// Geometri resmî logodan (240x240 PNG) piksel ölçümüyle çıkarıldı ve 200'lük
/// bir kareye ölçeklendi — web'deki SVG ile birebir aynı sayılar:
/// `araclar/logo-uret.py`. Görsel dosya yerine çizim tercih edildi: hem her
/// çözünürlükte keskin duruyor hem de açılış ekranında çizilerek gelebiliyor.
class IzbanLogosu extends StatelessWidget {
  final double boyut;

  /// 0..1 — kırmızı yayın ne kadarının çizildiği. Açılışta 0'dan 1'e gider.
  final double yayIlerlemesi;

  /// 0..1 — mavi yay. Verilmezse kırmızıyla aynı anda çizilir; açılış
  /// ekranında biraz geriden gelsin diye ayrı verilir.
  final double? maviYayIlerlemesi;

  /// 0..1 — ortadaki kelimenin görünürlüğü.
  final double kelimeGorunurlugu;

  const IzbanLogosu({
    super.key,
    this.boyut = 96,
    this.yayIlerlemesi = 1,
    this.maviYayIlerlemesi,
    this.kelimeGorunurlugu = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: boyut,
      height: boyut,
      child: CustomPaint(
        painter: _IzbanCizeri(
          kirmiziIlerleme: yayIlerlemesi.clamp(0, 1),
          maviIlerleme: (maviYayIlerlemesi ?? yayIlerlemesi).clamp(0, 1),
          kelimeGorunurlugu: kelimeGorunurlugu.clamp(0, 1),
          // Uygulamanın yazı tipi neyse kelime de onunla çizilir; verilmezse
          // sistem yazı tipi kullanılır.
          yaziTipi: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        ),
        isComplex: true,
      ),
    );
  }
}

class _IzbanCizeri extends CustomPainter {
  // 240'lık kaynaktan 200'lük kareye ölçek.
  static const _olcek = 200 / 240;
  static const _merkez = 100.0;
  static const _yaricap = 69.5 * _olcek;
  static const _kalinlikKeskin = 34.0 * _olcek;
  static const _kalinlikSonuk = 6.0 * _olcek;

  static const kirmizi = Color(0xFFED1B24);
  static const mavi = Color(0xFF0C4CA3);

  /// Yaylar sönük uçtan keskin uca doğru çizilir; açılış animasyonu da bu
  /// yönde ilerler.
  static const _kirmiziYay = (sonuk: 116.0, keskin: 24.0);
  static const _maviYay = (sonuk: 292.0, keskin: 196.0);

  final double kirmiziIlerleme;
  final double maviIlerleme;
  final double kelimeGorunurlugu;
  final String? yaziTipi;

  _IzbanCizeri({
    required this.kirmiziIlerleme,
    required this.maviIlerleme,
    required this.kelimeGorunurlugu,
    this.yaziTipi,
  });

  static Offset _nokta(double aci, double r) {
    final radyan = aci * matematik.pi / 180;
    return Offset(
      _merkez + r * matematik.cos(radyan),
      _merkez - r * matematik.sin(radyan),
    );
  }

  /// Ucu incelen yayın yolu. [oran] 1 ise yayın tamamı çizilir.
  static Path _yayYolu(double sonuk, double keskin, double oran) {
    final bitis = sonuk + (keskin - sonuk) * oran;
    final dis = <Offset>[];
    final ic = <Offset>[];

    const adim = 44;
    for (var i = 0; i <= adim; i++) {
      final aci = sonuk + (bitis - sonuk) * (i / adim);
      // Kalınlık, yayın TAMAMI üzerindeki yerden hesaplanır: animasyon
      // ilerlerken çizilmiş kısmın kalınlığı değişmesin.
      final tamOran = (aci - sonuk) / (keskin - sonuk);
      final kalinlik =
          _kalinlikSonuk + (_kalinlikKeskin - _kalinlikSonuk) * tamOran;
      dis.add(_nokta(aci, _yaricap + kalinlik / 2));
      ic.add(_nokta(aci, _yaricap - kalinlik / 2));
    }

    final yol = Path()..moveTo(dis.first.dx, dis.first.dy);
    for (final n in dis.skip(1)) {
      yol.lineTo(n.dx, n.dy);
    }
    for (final n in ic.reversed) {
      yol.lineTo(n.dx, n.dy);
    }
    return yol..close();
  }

  void _yayCiz(
    Canvas tuval,
    ({double sonuk, double keskin}) yay,
    Color renk,
    double ilerleme,
  ) {
    if (ilerleme <= 0) return;

    // Gradyan her zaman yayın TAMAMININ kutusuna göre kurulur; yoksa animasyon
    // sürerken renk kayar. Keskin uç dolu, sönük uç saydam.
    final tamKutu = _yayYolu(yay.sonuk, yay.keskin, 1).getBounds();
    final keskinSagda = _nokta(yay.keskin, _yaricap).dx > _merkez;

    final boya = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: keskinSagda ? Alignment.centerLeft : Alignment.centerRight,
        end: keskinSagda ? Alignment.centerRight : Alignment.centerLeft,
        colors: [
          renk.withValues(alpha: 0),
          renk.withValues(alpha: .62),
          renk,
        ],
        stops: const [0, .5, 1],
      ).createShader(tamKutu);

    tuval.drawPath(_yayYolu(yay.sonuk, yay.keskin, ilerleme), boya);
  }

  /// Yazıyı verilen genişliğe sıkıştırarak çizer.
  ///
  /// Genişlik sabitlenmeli: yazı tipi cihazdan cihaza değişse de marka kilidi
  /// aynı kalsın (web'de textLength ile yapılanın karşılığı).
  void _yaziCiz(
    Canvas tuval,
    String metin, {
    required double x,
    required double genislik,
    required double tabanCizgisi,
    required double punto,
    required Color renk,
    FontWeight agirlik = FontWeight.w900,
    double kalinlastir = 1.6,
  }) {
    final saydam = renk.withValues(alpha: renk.a * kelimeGorunurlugu);

    TextPainter olustur(Paint? kalem) => TextPainter(
          text: TextSpan(
            text: metin,
            style: TextStyle(
              fontFamily: yaziTipi,
              fontSize: punto,
              fontWeight: agirlik,
              color: kalem == null ? saydam : null,
              foreground: kalem,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

    final boyaci = olustur(null);
    if (boyaci.width == 0) return;

    final yatayOlcek = genislik / boyaci.width;
    final temel = boyaci.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    tuval.save();
    tuval.translate(x, tabanCizgisi - temel);
    tuval.scale(yatayOlcek, 1);

    // Sistem yazı tipi resmî logodaki kadar kalın değil; ince bir çizgi
    // eklenerek harflerin ağırlığı yakalanıyor (SVG'deki paint-order="stroke").
    if (kalinlastir > 0) {
      olustur(Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = kalinlastir
            ..strokeJoin = StrokeJoin.round
            ..color = saydam)
          .paint(tuval, Offset.zero);
    }
    boyaci.paint(tuval, Offset.zero);
    tuval.restore();
  }

  @override
  void paint(Canvas tuval, Size boyut) {
    final olcek = boyut.width / 200;
    tuval.save();
    tuval.scale(olcek);

    _yayCiz(tuval, _kirmiziYay, kirmizi, kirmiziIlerleme);
    _yayCiz(tuval, _maviYay, mavi, maviIlerleme);

    if (kelimeGorunurlugu > 0) {
      _yaziCiz(tuval, 'İZ',
          x: 30.8, genislik: 40.5, tabanCizgisi: 120, punto: 57, renk: mavi);
      _yaziCiz(tuval, 'BAN',
          x: 72.5, genislik: 95.8, tabanCizgisi: 120, punto: 57, renk: kirmizi);
      _yaziCiz(tuval, 'İZMİR BANLİYÖ SİSTEMİ',
          x: 44,
          genislik: 112,
          tabanCizgisi: 131,
          punto: 7.6,
          renk: mavi,
          agirlik: FontWeight.w700,
          kalinlastir: 0);
    }

    tuval.restore();
  }

  @override
  bool shouldRepaint(_IzbanCizeri eski) =>
      eski.kirmiziIlerleme != kirmiziIlerleme ||
      eski.maviIlerleme != maviIlerleme ||
      eski.kelimeGorunurlugu != kelimeGorunurlugu ||
      eski.yaziTipi != yaziTipi;
}
