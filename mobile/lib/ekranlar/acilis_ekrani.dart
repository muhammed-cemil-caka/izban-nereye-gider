import 'package:flutter/material.dart';
import '../diller.dart';
import 'izban_logosu.dart';

/// Açılış ekranı: marka çizilerek gelir, sonra kendini kaldırır.
///
/// Ana ekranın ÜSTÜNDE durur (altında değil): uygulama arkada durak verisini
/// okuyup konumu istemeye başlar, kullanıcı beklemez.
///
/// Zamanlamanın tamamı tek bir denetleyiciye bağlı — zamanlayıcıyla değil.
/// Widget testleri `pumpAndSettle` ile animasyonları sonuna kadar sarabiliyor;
/// zamanlayıcı kullanılsaydı ekran testlerde açık kalırdı.
class AcilisKapisi extends StatefulWidget {
  final Widget cocuk;

  const AcilisKapisi({super.key, required this.cocuk});

  @override
  State<AcilisKapisi> createState() => _AcilisKapisiDurumu();
}

class _AcilisKapisiDurumu extends State<AcilisKapisi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _denetleyici = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool _bitti = false;

  @override
  void initState() {
    super.initState();
    _denetleyici.addStatusListener((durum) {
      if (durum == AnimationStatus.completed && mounted) {
        setState(() => _bitti = true);
      }
    });
    _denetleyici.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kullanıcı hareketi azaltmayı açtıysa ekran oyalanmaz.
    if (MediaQuery.disableAnimationsOf(context) && _denetleyici.isAnimating) {
      _denetleyici.duration = const Duration(milliseconds: 400);
    }
  }

  @override
  void dispose() {
    _denetleyici.dispose();
    super.dispose();
  }

  /// Dokununca beklemeden geçilir.
  void _atla() {
    if (_denetleyici.value < .84) {
      _denetleyici.animateTo(1, duration: const Duration(milliseconds: 320));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.cocuk,
        if (!_bitti)
          Positioned.fill(
            child: GestureDetector(
              onTap: _atla,
              child: _AcilisPerdesi(ilerleme: _denetleyici),
            ),
          ),
      ],
    );
  }
}

class _AcilisPerdesi extends StatelessWidget {
  final Animation<double> ilerleme;

  const _AcilisPerdesi({required this.ilerleme});

  static const _plaka = Interval(0, .14, curve: Curves.easeOutBack);
  static const _kirmiziYay = Interval(.06, .40, curve: Curves.easeInOutCubic);
  static const _maviYay = Interval(.19, .53, curve: Curves.easeInOutCubic);
  static const _kelime = Interval(.40, .58, curve: Curves.easeOut);
  static const _ad = Interval(.50, .68, curve: Curves.easeOut);
  static const _altYazi = Interval(.55, .73, curve: Curves.easeOut);
  static const _kapanis = Interval(.84, 1, curve: Curves.easeIn);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final koyu = tema.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: ilerleme,
      builder: (context, _) {
        final t = ilerleme.value;
        final gorunurluk = 1 - _kapanis.transform(t);
        final plakaOrani = _plaka.transform(t);

        return Opacity(
          opacity: gorunurluk,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: koyu
                    ? const [Color(0xFF143059), Color(0xFF0B1C33), Color(0xFF060F1D)]
                    : const [Color(0xFFFFFFFF), Color(0xFFE3ECF9), Color(0xFFCFDCF1)],
                stops: const [0, .55, 1],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: .88 + .12 * plakaOrani,
                    child: Opacity(
                      opacity: plakaOrani.clamp(0, 1),
                      // Logo her iki temada da okunsun diye beyaz plakanın
                      // üstünde durur — kartlarla aynı kabartma dili.
                      child: Container(
                        width: 208,
                        height: 208,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x2E0B1F3A),
                              blurRadius: 40,
                              spreadRadius: -8,
                              offset: Offset(0, 22),
                            ),
                            BoxShadow(
                              color: Color(0x1F0B1F3A),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IzbanLogosu(
                          boyut: 180,
                          yayIlerlemesi: _kirmiziYay.transform(t),
                          maviYayIlerlemesi: _maviYay.transform(t),
                          kelimeGorunurlugu: _kelime.transform(t),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Opacity(
                    opacity: _ad.transform(t),
                    child: Text(
                      'İZBAN Nereye Gider?',
                      style: tema.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Opacity(
                    opacity: _altYazi.transform(t),
                    child: Text(
                      Diller.of(context).call('markaAlt'),
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
