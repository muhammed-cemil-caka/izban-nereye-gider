import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'diller.dart';
import 'ekranlar/acilis_ekrani.dart';
import 'ekranlar/ana_ekran.dart';
import 'servisler/durak_servisi.dart';
import 'servisler/konum_servisi.dart';

void main() {
  runApp(const IzbanUygulamasi());
}

/// Marka renkleri — resmî logodan örneklendi, web'deki palet ile aynı.
class IzbanRenkleri {
  static const mavi = Color(0xFF0C4CA3);
  static const kirmizi = Color(0xFFED1B24);

  /// Koyu temada marka mavisi okunmuyor; açılmış tonu kullanılır.
  static const maviAcik = Color(0xFF5B9DF0);
  static const kirmiziAcik = Color(0xFFFF5A53);

  static const zeminAcik = Color(0xFFEEF2F9);
  static const kartAcik = Color(0xFFFFFFFF);
  static const cizgiAcik = Color(0xFFD8E1EF);

  static const zeminKoyu = Color(0xFF0A1626);
  static const kartKoyu = Color(0xFF10203A);
  static const cizgiKoyu = Color(0xFF1E3149);
}

class IzbanUygulamasi extends StatefulWidget {
  /// Testler hazır veri geçebilsin diye dışarıdan verilebilir.
  final DurakServisi? servis;

  /// Testler sahte konum servisi geçebilir.
  final KonumServisi? konumServisi;

  const IzbanUygulamasi({super.key, this.servis, this.konumServisi});

  @override
  State<IzbanUygulamasi> createState() => _IzbanUygulamasiDurumu();
}

class _IzbanUygulamasiDurumu extends State<IzbanUygulamasi> {
  static const _temaAnahtari = 'izban.tema';
  static const _dilAnahtari = 'izban.dil';

  /// Seçim yapılmadıysa cihazın tercihi geçerli.
  ThemeMode _temaKipi = ThemeMode.system;

  /// Seçim yapılmadıysa cihaz dili; Türkçe değilse İngilizce.
  String? _dilKodu;

  @override
  void initState() {
    super.initState();
    _temayiOku();
    _diliOku();
  }

  Future<void> _diliOku() async {
    try {
      final ayarlar = await SharedPreferences.getInstance();
      final deger = ayarlar.getString(_dilAnahtari);
      if (!mounted || deger == null) return;
      setState(() => _dilKodu = deger);
    } catch (_) {
      // Eklenti yoksa (widget testleri) cihaz dili kullanılır.
    }
  }

  Future<void> _diliDegistir(String kod) async {
    setState(() => _dilKodu = kod);
    try {
      final ayarlar = await SharedPreferences.getInstance();
      await ayarlar.setString(_dilAnahtari, kod);
    } catch (_) {
      // Kaydedilemezse dil yine de bu oturumda değişir.
    }
  }

  Future<void> _temayiOku() async {
    try {
      final ayarlar = await SharedPreferences.getInstance();
      final deger = ayarlar.getString(_temaAnahtari);
      if (!mounted || deger == null) return;
      setState(() {
        _temaKipi = ThemeMode.values.firstWhere(
          (k) => k.name == deger,
          orElse: () => ThemeMode.system,
        );
      });
    } catch (_) {
      // Eklenti yoksa (widget testleri) sistem teması kalır.
    }
  }

  Future<void> _temayiDegistir(ThemeMode kip) async {
    setState(() => _temaKipi = kip);
    try {
      final ayarlar = await SharedPreferences.getInstance();
      await ayarlar.setString(_temaAnahtari, kip.name);
    } catch (_) {
      // Kaydedilemezse tema yine de bu oturumda değişir.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İZBAN Nereye Gider?',
      debugShowCheckedModeBanner: false,
      theme: izbanTemasi(Brightness.light),
      darkTheme: izbanTemasi(Brightness.dark),
      themeMode: _temaKipi,
      home: Builder(
        builder: (context) {
          // Seçim yoksa cihaz dili: Türkçe değilse İngilizce.
          final cihaz = View.of(context).platformDispatcher.locale.languageCode;
          final kod = _dilKodu ?? (cihaz == 'tr' ? 'tr' : 'en');
          final diller = Diller(kod);

          // Rota, konum ve sefer servisleri BuildContext görmüyor; seçili dile
          // buradan ulaşıyorlar.
          Diller.aktif = diller;

          return DilKapsami(
            diller: diller,
            child: AcilisKapisi(
              cocuk: AnaEkran(
                servis: widget.servis,
                konumServisi: widget.konumServisi,
                temaKipi: _temaKipi,
                temaDegisti: _temayiDegistir,
                dilKodu: kod,
                dilDegisti: _diliDegistir,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// İZBAN paleti ve kabartma kutucuk dili.
///
/// Derinlik iki yerden geliyor: kartların katmanlı gölgesi (CardTheme) ve
/// kutucuklardaki yüzey eğimi (ana_ekran.dart içindeki KabarikKutu).
ThemeData izbanTemasi(Brightness parlaklik) {
  final acik = parlaklik == Brightness.light;

  final renkler = ColorScheme.fromSeed(
    seedColor: IzbanRenkleri.mavi,
    brightness: parlaklik,
  ).copyWith(
    primary: acik ? IzbanRenkleri.mavi : IzbanRenkleri.maviAcik,
    secondary: acik ? IzbanRenkleri.kirmizi : IzbanRenkleri.kirmiziAcik,
    surface: acik ? IzbanRenkleri.kartAcik : IzbanRenkleri.kartKoyu,
    outlineVariant: acik ? IzbanRenkleri.cizgiAcik : IzbanRenkleri.cizgiKoyu,
  );

  return ThemeData(
    colorScheme: renkler,
    useMaterial3: true,
    scaffoldBackgroundColor:
        acik ? IzbanRenkleri.zeminAcik : IzbanRenkleri.zeminKoyu,
    cardTheme: CardThemeData(
      elevation: acik ? 6 : 10,
      margin: EdgeInsets.zero,
      color: renkler.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: acik ? const Color(0x330B1F3A) : const Color(0x99000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: renkler.outlineVariant),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: renkler.surface,
      foregroundColor: renkler.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 2,
    ),
    dividerTheme: DividerThemeData(color: renkler.outlineVariant),
  );
}
