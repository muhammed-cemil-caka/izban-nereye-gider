import 'package:flutter/material.dart';
import '../modeller/durak.dart';
import '../modeller/yakin_durak.dart';
import '../modeller/yolculuk.dart';
import '../servisler/durak_servisi.dart';
import '../servisler/konum_servisi.dart';
import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';
import '../servisler/rota_servisi.dart';
import '../servisler/yonlendirme_servisi.dart';
import 'harita_karti.dart';

class AnaEkran extends StatefulWidget {
  /// Verilmezse assets/duraklar.json okunur; testler hazır servis geçebilir.
  final DurakServisi? servis;

  /// Verilmezse gerçek cihaz konumu kullanılır; testler sahte servis geçebilir.
  final KonumServisi? konumServisi;

  const AnaEkran({super.key, this.servis, this.konumServisi});

  @override
  State<AnaEkran> createState() => _AnaEkranDurumu();
}

class _AnaEkranDurumu extends State<AnaEkran> {
  late final DurakServisi _servis;
  final _kaydirma = ScrollController();

  /// Yol tarifi alınınca haritaya kaydırmak için.
  final _haritaAnahtari = GlobalKey();
  late final Future<List<Durak>> _duraklarGelecegi;

  String? _binisKod;
  String? _inisKod;

  KonumServisi get _konumServisi => widget.konumServisi ?? const KonumServisi();
  YakinDurak? _yakinDurak;
  List<YakinDurak> _yakinAdaylar = const [];
  double? _konumDogrulukM;
  Konum? _kullaniciKonumu;
  YuruyusRotasi? _yuruyusRotasi;
  Durak? _rotaHedefi;
  bool _rotaAraniyor = false;
  String? _rotaHatasi;

  StreamSubscription? _takipAboneligi;
  StreamSubscription? _yonlendirmeAboneligi;

  /// Arayüz bu bayrağı okur. Aboneliği doğrudan okumak yetmiyordu: abonelik
  /// setState dışında atandığı için harita yön okuna geçmiyordu.
  bool _yonlendirmeAktif = false;
  double? _baslangicAcisi;

  /// Pusula açısı. Kullanıcı yürümeden telefonu çevirdiğinde de ok dönsün diye
  /// hareket yönünün yanında manyetometre de dinleniyor (Google Haritalar gibi).
  StreamSubscription? _pusulaAboneligi;
  double? _pusulaAcisi;
  YonlendirmeDurumu? _yonlendirmeDurumu;
  String? _yonlendirmeUyarisi;
  bool _varildi = false;
  String? _konumHatasi;
  bool _konumAyarlariGerekli = false;
  bool _konumAraniyor = false;

  @override
  void initState() {
    super.initState();
    _servis = widget.servis ?? DurakServisi();
    _duraklarGelecegi = _servis.duraklariGetir();

    // Kullanıcı uygulamayı açar açmaz konum isteniyor; reddedilirse uygulama
    // normal çalışmaya devam eder, yalnızca en yakın durak kartı kapanır.
    WidgetsBinding.instance.addPostFrameCallback((_) => _konumuBul());
  }

  Future<void> _konumuBul() async {
    if (_konumAraniyor) return;
    setState(() {
      _konumAraniyor = true;
      _konumHatasi = null;
    });

    final sonuc = await _konumServisi.konumAl();
    if (!mounted) return;

    switch (sonuc) {
      case KonumBulundu(:final konum, :final dogrulukM):
        _takibiBaslat();
        final duraklar = await _duraklarGelecegi;
        if (!mounted) return;
        final adaylar = YakinDurak.enYakinlar(duraklar, konum);
        setState(() {
          _yakinAdaylar = adaylar;
          _yakinDurak = adaylar.isEmpty ? null : adaylar.first;
          _konumDogrulukM = dogrulukM;
          _kullaniciKonumu = konum;
          _konumHatasi = adaylar.isEmpty ? 'Duraklarda koordinat bilgisi yok.' : null;
          _konumAraniyor = false;
        });

      case KonumHatasi(:final mesaj, :final ayarlarGerekli):
        setState(() {
          _yakinDurak = null;
          _yakinAdaylar = const [];
          _konumHatasi = mesaj;
          _konumAyarlariGerekli = ayarlarGerekli;
          _konumAraniyor = false;
        });
    }
  }

  /// Yürüyüş rotasını hesaplayıp haritada gösterir.
  /// Google Haritalar'a yönlendirilmiyor: rota uygulamanın kendi haritasında.
  /// Harita işareti kullanıcıyla birlikte hareket etsin diye takibi açar.
  void _takibiBaslat() {
    _takipAboneligi?.cancel();
    _takipAboneligi = _konumServisi.konumTakibi().listen((konum) async {
      // Yönlendirme kendi akışını kullanıyor; takip araya girmesin.
      if (_yonlendirmeAktif || !mounted) return;

      final duraklar = await _duraklarGelecegi;
      if (!mounted) return;
      final adaylar = YakinDurak.enYakinlar(duraklar, konum);
      setState(() {
        _kullaniciKonumu = konum;
        _yakinAdaylar = adaylar;
        _yakinDurak = adaylar.isEmpty ? null : adaylar.first;
      });
    }, onError: (_) { /* takip sessizce durur */ });
  }

  void _takibiKapat() {
    _takipAboneligi?.cancel();
    _takipAboneligi = null;
  }

  Future<void> _yolTarifiniGoster(YakinDurak yakin) async {
    final konum = _kullaniciKonumu;
    if (konum == null) return;

    setState(() {
      _rotaAraniyor = true;
      _rotaHatasi = null;
    });

    try {
      final rota = await const RotaServisi().rotaAl(konum, yakin.durak.konum);
      if (!mounted) return;
      setState(() {
        _yuruyusRotasi = rota;
        _rotaHedefi = yakin.durak;
        _rotaAraniyor = false;
      });
      _haritayaKaydir();
    } catch (sorun) {
      if (!mounted) return;
      setState(() {
        _rotaHatasi = 'Yürüyüş rotası alınamadı.';
        _rotaAraniyor = false;
      });
    }
  }

  void _yonlendirmeyiBaslat() {
    final rota = _yuruyusRotasi;
    if (rota == null) return;

    _yonlendirmeAboneligi?.cancel();

    // İlk açı: rotanın ilk parçasının yönü. Kullanıcı yürümeye başlayınca
    // gerçek hareket yönüyle değişir. Böylece "Başla"ya basıldığı anda ok
    // doğru yöne bakar; yeni bir konum ölçümü beklenmez.
    double? ilkAci;
    if (rota.noktalar.length > 1) {
      ilkAci = YonlendirmeServisi.yonAcisi(rota.noktalar[0], rota.noktalar[1]);
    }

    setState(() {
      _varildi = false;
      _yonlendirmeUyarisi = null;
      _yonlendirmeDurumu = null;
      _yonlendirmeAktif = true;
      _baslangicAcisi = ilkAci;
    });

    _pusulayiBaslat();

    // İki konum akışı aynı anda çalışırsa Android istekleri birleştirip
    // seyrekleştiriyor; yönlendirme sırasında takip kapatılır.
    _takibiKapat();

    _yonlendirmeAboneligi = YonlendirmeServisi.baslat(
      rota: rota,
      durumDegisti: (durum) async {
        if (!mounted) return;

        // En yakın durak kartı da tazelensin; yoksa yönlendirme "243 m" derken
        // üstteki kart eski mesafeyi göstermeye devam ediyor.
        final duraklar = await _duraklarGelecegi;
        if (!mounted) return;
        final adaylar = YakinDurak.enYakinlar(duraklar, durum.konum);

        setState(() {
          _yonlendirmeDurumu = durum;
          _kullaniciKonumu = durum.konum;
          _yakinAdaylar = adaylar;
          _yakinDurak = adaylar.isEmpty ? null : adaylar.first;
          _yonlendirmeUyarisi = durum.dogrulukM > 100
              ? 'Konum ±${durum.dogrulukM.round()} m — yönlendirme şaşabilir.'
              : null;
        });
      },
      rotadanCikildi: (konum) async {
        if (!mounted) return;
        setState(() {
          _kullaniciKonumu = konum;
          _yonlendirmeUyarisi = 'Rotadan çıktın, yeniden hesaplanıyor…';
        });

        final hedef = _rotaHedefi;
        if (hedef == null) return;
        try {
          final yeni = await const RotaServisi().rotaAl(konum, hedef.konum);
          if (!mounted) return;
          setState(() => _yuruyusRotasi = yeni);
          _yonlendirmeyiBaslat();
        } catch (_) {
          if (!mounted) return;
          setState(() => _yonlendirmeUyarisi = 'Yeni rota alınamadı.');
          _yonlendirmeyiBitir();
        }
      },
      varildi: () {
        if (!mounted) return;
        setState(() => _varildi = true);
        _yonlendirmeyiBitir(varisSonrasi: true);
      },
      hataOldu: (_) {
        if (!mounted) return;
        setState(() => _yonlendirmeUyarisi = 'Konum alınamadı, yönlendirme durdu.');
        _yonlendirmeyiBitir();
      },
    );
  }

  /// Pusulayı dinlemeye başlar. Cihazda manyetometre yoksa akış hiç veri
  /// üretmez; o durumda hareket yönü kullanılmaya devam eder.
  void _pusulayiBaslat() {
    _pusulaAboneligi?.cancel();

    final akis = FlutterCompass.events;
    if (akis == null) return;

    _pusulaAboneligi = akis.listen((olay) {
      final aci = olay.heading;
      if (aci == null || !mounted) return;

      // Küçük sapmalarda yeniden çizim yapma; ok titremesin ve pil yanmasın.
      final onceki = _pusulaAcisi;
      if (onceki != null && (aci - onceki).abs() < 3) return;

      setState(() => _pusulaAcisi = (aci + 360) % 360);
    }, onError: (_) { /* pusula yoksa sessizce geç */ });
  }

  void _pusulayiKapat() {
    _pusulaAboneligi?.cancel();
    _pusulaAboneligi = null;
    _pusulaAcisi = null;
  }

  void _yonlendirmeyiBitir({bool varisSonrasi = false}) {
    _yonlendirmeAboneligi?.cancel();
    _yonlendirmeAboneligi = null;
    _pusulayiKapat();

    if (mounted) {
      setState(() {
        _yonlendirmeAktif = false;
        _baslangicAcisi = null;
        if (!varisSonrasi) {
          _yonlendirmeDurumu = null;
          _yonlendirmeUyarisi = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    _pusulaAboneligi?.cancel();
    _takipAboneligi?.cancel();
    _yonlendirmeAboneligi?.cancel();
    super.dispose();
  }

  /// Rota çizilince harita ekranın görünür kısmına gelsin; kullanıcı
  /// aşağı kaydırmak zorunda kalmasın.
  void _haritayaKaydir() {
    // Kart yeniden çizilmeden konumu bilinmiyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final baglam = _haritaAnahtari.currentContext;
      if (baglam == null || !mounted) return;

      Scrollable.ensureVisible(
        baglam,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    });
  }

  void _rotayiTemizle() {
    _yonlendirmeyiBitir();
    setState(() {
      _yuruyusRotasi = null;
      _rotaHedefi = null;
      _rotaHatasi = null;
      _varildi = false;
    });
  }

  void _tersCevir() {
    setState(() {
      final gecici = _binisKod;
      _binisKod = _inisKod;
      _inisKod = gecici;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İZBAN Nereye Gider?'),
        centerTitle: false,
      ),
      body: FutureBuilder<List<Durak>>(
        future: _duraklarGelecegi,
        builder: (context, anlik) {
          if (anlik.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (anlik.hasError) {
            return Center(child: Text('Durak verisi okunamadı: ${anlik.error}'));
          }

          final duraklar = anlik.data!;
          _binisKod ??= duraklar.first.kod;
          _inisKod ??= duraklar.last.kod;

          final yolculuk = Yolculuk.hesapla(duraklar, _binisKod!, _inisKod!);

          return ListView(
            controller: _kaydirma,
            padding: const EdgeInsets.all(16),
            children: [
              _KonumKarti(
                yakinDurak: _yakinDurak,
                adaylar: _yakinAdaylar,
                dogrulukM: _konumDogrulukM,
                digeriniSec: (secilen) => setState(() {
                  _yakinDurak = secilen;
                  _binisKod = secilen.durak.kod;
                }),
                hata: _konumHatasi,
                araniyor: _konumAraniyor,
                ayarlarGerekli: _konumAyarlariGerekli,
                tekrarDene: _konumuBul,
                ayarlariAc: _konumServisi.ayarlariAc,
                binisYap: (durak) => setState(() {
                  _binisKod = durak.kod;
                  if (_inisKod == _binisKod) {
                    final indeks = duraklar.indexWhere((d) => d.kod == durak.kod);
                    _inisKod = indeks < duraklar.length / 2
                        ? duraklar.last.kod
                        : duraklar.first.kod;
                  }
                }),
                yolTarifiAc: _yolTarifiniGoster,
              ),
              const SizedBox(height: 16),
              _SecimKarti(
                duraklar: duraklar,
                binisKod: _binisKod!,
                inisKod: _inisKod!,
                binisDegisti: (kod) => setState(() => _binisKod = kod),
                inisDegisti: (kod) => setState(() => _inisKod = kod),
                tersCevir: _tersCevir,
              ),
              const SizedBox(height: 16),
              HaritaKarti(
                key: _haritaAnahtari,
                duraklar: duraklar,
                yolculuk: yolculuk,
                kullaniciKonumu: _kullaniciKonumu,
                yuruyusRotasi: _yuruyusRotasi,
                yonlendirmede: _yonlendirmeAktif,
                // Pusula varsa telefonun baktığı yön, yoksa hareket yönü.
                yonAcisi: _pusulaAcisi ?? _yonlendirmeDurumu?.aci ?? _baslangicAcisi,
                duragaBasildi: (durak) => setState(() {
                  _binisKod = durak.kod;
                  if (_inisKod == _binisKod) {
                    final indeks = duraklar.indexWhere((d) => d.kod == durak.kod);
                    _inisKod = indeks < duraklar.length / 2
                        ? duraklar.last.kod
                        : duraklar.first.kod;
                  }
                }),
                konumTasindi: (konum) {
                  // Sürükleme, GPS şaştığında yeri elle düzeltmenin en doğrudan
                  // yolu; takip devam ederse seçimi hemen ezer.
                  _takibiKapat();
                  final adaylar = YakinDurak.enYakinlar(duraklar, konum);
                  setState(() {
                    _kullaniciKonumu = konum;
                    _yakinAdaylar = adaylar;
                    _yakinDurak = adaylar.isEmpty ? null : adaylar.first;
                    _konumDogrulukM = null;
                    _konumHatasi = null;
                  });
                },
              ),
              if (_yonlendirmeDurumu != null || _varildi) ...[
                const SizedBox(height: 16),
                _YonlendirmePaneli(
                  rota: _yuruyusRotasi,
                  hedef: _rotaHedefi,
                  durum: _yonlendirmeDurumu,
                  uyari: _yonlendirmeUyarisi,
                  varildi: _varildi,
                  bitir: () {
                    setState(() => _varildi = false);
                    _yonlendirmeyiBitir();
                  },
                ),
              ],
              if (_rotaAraniyor || _rotaHatasi != null || _yuruyusRotasi != null) ...[
                const SizedBox(height: 16),
                _RotaKarti(
                  rota: _yuruyusRotasi,
                  hedef: _rotaHedefi,
                  araniyor: _rotaAraniyor,
                  hata: _rotaHatasi,
                  temizle: _rotayiTemizle,
                  // Düğme, yönlendirme aktifken Bitir'e dönüşür. Daha önce
                  // _yonlendirmeDurumu'na bakılıyordu ama o yalnızca ilk konum
                  // ölçümü gelince doluyor; ölçüm gecikince düğme Başla'da
                  // takılı kalıyordu.
                  yonlendirmede: _yonlendirmeAktif,
                  basla: _yonlendirmeyiBaslat,
                  bitir: () {
                    setState(() => _varildi = false);
                    _yonlendirmeyiBitir();
                  },
                ),
              ],
              const SizedBox(height: 16),
              if (yolculuk == null)
                const _UyariKarti(mesaj: 'Biniş ve iniş durağı aynı olamaz.')
              else ...[
                _OzetKarti(yolculuk: yolculuk),
                const SizedBox(height: 16),
                _GuzergahKarti(yolculuk: yolculuk),
              ],
              const SizedBox(height: 24),
              Text(
                'Durak sırası ve süreler tahminidir, resmî kaynak değildir.\n'
                'Veri sürümü: ${_servis.surum} · Kaynak: ${_servis.kaynakEtiketi}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SecimKarti extends StatelessWidget {
  final List<Durak> duraklar;
  final String binisKod;
  final String inisKod;
  final ValueChanged<String> binisDegisti;
  final ValueChanged<String> inisDegisti;
  final VoidCallback tersCevir;

  const _SecimKarti({
    required this.duraklar,
    required this.binisKod,
    required this.inisKod,
    required this.binisDegisti,
    required this.inisDegisti,
    required this.tersCevir,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DurakSecici(
              etiket: 'Nereden biniyorsun?',
              duraklar: duraklar,
              secili: binisKod,
              degisti: binisDegisti,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton.filledTonal(
                onPressed: tersCevir,
                icon: const Icon(Icons.swap_vert),
                tooltip: 'Yer değiştir',
              ),
            ),
            _DurakSecici(
              etiket: 'Nereye gideceksin?',
              duraklar: duraklar,
              secili: inisKod,
              degisti: inisDegisti,
            ),
          ],
        ),
      ),
    );
  }
}

class _DurakSecici extends StatelessWidget {
  final String etiket;
  final List<Durak> duraklar;
  final String secili;
  final ValueChanged<String> degisti;

  const _DurakSecici({
    required this.etiket,
    required this.duraklar,
    required this.secili,
    required this.degisti,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: secili,
      decoration: InputDecoration(
        labelText: etiket,
        border: const OutlineInputBorder(),
      ),
      isExpanded: true,
      items: duraklar
          .map((durak) => DropdownMenuItem(
                value: durak.kod,
                child: Text(durak.ad, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (kod) {
        if (kod != null) degisti(kod);
      },
    );
  }
}

class _OzetKarti extends StatelessWidget {
  final Yolculuk yolculuk;

  const _OzetKarti({required this.yolculuk});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(
              label: Text(yolculuk.yonEtiketi),
              avatar: Icon(
                yolculuk.yon == Yon.guney ? Icons.south : Icons.north,
                size: 18,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _OzetKutu(deger: yolculuk.sureMetni, etiket: 'tahmini süre'),
                _OzetKutu(deger: '${yolculuk.durakSayisi}', etiket: 'durak'),
                _OzetKutu(
                  deger: '${yolculuk.aktarmaliDuraklar.length}',
                  etiket: 'aktarma',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${yolculuk.binis.ad} durağından ${yolculuk.yonEtiketi}ndeki trene bin. '
              '${yolculuk.durakSayisi} durak sonra, yaklaşık ${yolculuk.sureMetni} '
              'içinde ${yolculuk.inis.ad} durağındasın.',
              style: tema.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _OzetKutu extends StatelessWidget {
  final String deger;
  final String etiket;

  const _OzetKutu({required this.deger, required this.etiket});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(deger, style: tema.textTheme.headlineSmall),
          Text(etiket, style: tema.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _GuzergahKarti extends StatelessWidget {
  final Yolculuk yolculuk;

  const _GuzergahKarti({required this.yolculuk});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GÜZERGÂH', style: tema.textTheme.labelMedium),
            const SizedBox(height: 8),
            ...yolculuk.guzergah.asMap().entries.map((girdi) {
              final sira = girdi.key;
              final durak = girdi.value;
              final ucNokta = sira == 0 || sira == yolculuk.guzergah.length - 1;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      ucNokta ? Icons.circle : Icons.circle_outlined,
                      size: ucNokta ? 14 : 10,
                      color: tema.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        durak.ad,
                        style: ucNokta
                            ? tema.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold)
                            : tema.textTheme.bodyMedium,
                      ),
                    ),
                    if (durak.aktarmaVar)
                      Tooltip(
                        message: durak.aktarma.join(' · '),
                        child: Icon(
                          Icons.alt_route,
                          size: 16,
                          color: tema.colorScheme.secondary,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _UyariKarti extends StatelessWidget {
  final String mesaj;

  const _UyariKarti({required this.mesaj});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(mesaj),
      ),
    );
  }
}

/// Konum durumunu ve en yakın durağı gösteren kart.
class _KonumKarti extends StatelessWidget {
  /// Kaba konumda en yakın durak şaşabildiği için kullanıcıya bu eşiğin
  /// üstünde uyarı gösterilir ve alternatifler öne çıkarılır.
  static const kabaKonumEsigiM = 200.0;

  final YakinDurak? yakinDurak;
  final List<YakinDurak> adaylar;
  final double? dogrulukM;
  final ValueChanged<YakinDurak> digeriniSec;
  final String? hata;
  final bool araniyor;
  final bool ayarlarGerekli;
  final VoidCallback tekrarDene;
  final VoidCallback ayarlariAc;
  final ValueChanged<Durak> binisYap;
  final ValueChanged<YakinDurak> yolTarifiAc;

  const _KonumKarti({
    required this.yakinDurak,
    required this.adaylar,
    required this.dogrulukM,
    required this.digeriniSec,
    required this.hata,
    required this.araniyor,
    required this.ayarlarGerekli,
    required this.tekrarDene,
    required this.ayarlariAc,
    required this.binisYap,
    required this.yolTarifiAc,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KONUMUN', style: tema.textTheme.labelMedium),
            const SizedBox(height: 8),
            if (araniyor)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Konumun alınıyor…'),
                ],
              )
            else if (yakinDurak != null)
              ..._sonuc(context, tema, yakinDurak!)
            else
              ..._hata(context, tema),
          ],
        ),
      ),
    );
  }

  List<Widget> _sonuc(BuildContext context, ThemeData tema, YakinDurak yakin) {
    return [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          const Text('En yakın durak:'),
          Text(
            yakin.durak.ad,
            style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Chip(
            label: Text(yakin.mesafeMetni),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
      if (dogrulukM != null) ...[
        const SizedBox(height: 4),
        Text(
          _dogrulukMetni(dogrulukM!),
          style: tema.textTheme.bodySmall?.copyWith(
            color: dogrulukM! > kabaKonumEsigiM
                ? tema.colorScheme.tertiary
                : tema.textTheme.bodySmall?.color,
            fontWeight: dogrulukM! > kabaKonumEsigiM ? FontWeight.bold : null,
          ),
        ),
      ],
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: () => binisYap(yakin.durak),
            child: const Text('Biniş durağı yap'),
          ),
          OutlinedButton.icon(
            onPressed: () => yolTarifiAc(yakin),
            icon: const Icon(Icons.directions_walk, size: 18),
            label: const Text('Yol tarifi al'),
          ),
        ],
      ),
      ..._alternatifler(tema, yakin),
    ];
  }

  String _dogrulukMetni(double dogruluk) {
    if (dogruluk > kabaKonumEsigiM) {
      return 'Konum ±${dogruluk.round()} m doğrulukla alındı — '
          'en yakın durak şaşabilir, aşağıdan seçebilirsin.';
    }
    return 'Konum doğruluğu ±${dogruluk.round()} m';
  }

  /// GPS şaşarsa kullanıcı doğru durağı kendisi seçebilsin.
  List<Widget> _alternatifler(ThemeData tema, YakinDurak secili) {
    final digerleri =
        adaylar.where((a) => a.durak.kod != secili.durak.kod).toList();
    if (digerleri.isEmpty) return const [];

    return [
      const SizedBox(height: 12),
      const Divider(height: 1),
      const SizedBox(height: 12),
      Text('Yakındaki diğer duraklar:', style: tema.textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: digerleri
            .map((aday) => ActionChip(
                  onPressed: () => digeriniSec(aday),
                  label: Text('${aday.durak.ad} · ${aday.mesafeMetni}'),
                ))
            .toList(),
      ),
    ];
  }

  List<Widget> _hata(BuildContext context, ThemeData tema) {
    return [
      Text(
        hata ?? 'Konum alınamadı.',
        style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: tekrarDene,
            child: const Text('Konumumu bul'),
          ),
          if (ayarlarGerekli)
            TextButton(
              onPressed: ayarlariAc,
              child: const Text('Ayarları aç'),
            ),
        ],
      ),
    ];
  }
}

/// Hesaplanan yürüyüş rotasını adım adım gösterir.
class _RotaKarti extends StatelessWidget {
  final YuruyusRotasi? rota;
  final Durak? hedef;
  final bool araniyor;
  final String? hata;
  final VoidCallback temizle;

  final bool yonlendirmede;
  final VoidCallback basla;
  final VoidCallback bitir;

  const _RotaKarti({
    required this.rota,
    required this.hedef,
    required this.araniyor,
    required this.hata,
    required this.temizle,
    required this.yonlendirmede,
    required this.basla,
    required this.bitir,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    if (araniyor) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Yürüyüş rotası hesaplanıyor…'),
            ],
          ),
        ),
      );
    }

    if (hata != null) {
      return Card(
        color: tema.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(hata!),
        ),
      );
    }

    final yol = rota;
    if (yol == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${hedef?.ad ?? ""} durağına yürüyüş',
                    style: tema.textTheme.titleSmall,
                  ),
                ),
                FilledButton(
                  onPressed: yonlendirmede ? bitir : basla,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: yonlendirmede
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  child: Text(yonlendirmede ? 'Bitir' : 'Başla'),
                ),
                IconButton(
                  onPressed: temizle,
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Yol tarifini kaldır',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Chip(
              label: Text('${yol.mesafeMetni} · ${yol.sureMetni}'),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 8),
            ...yol.adimlar.map((adim) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chevron_right, size: 16),
                      const SizedBox(width: 4),
                      Expanded(child: Text(adim.metin, style: tema.textTheme.bodySmall)),
                      Text(
                        adim.mesafeM < 1000
                            ? '${adim.mesafeM.round()} m'
                            : '${(adim.mesafeM / 1000).toStringAsFixed(1)} km',
                        style: tema.textTheme.bodySmall
                            ?.copyWith(color: tema.textTheme.bodySmall?.color?.withValues(alpha: .6)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// Yönlendirme sırasında sıradaki manevrayı ve kalan mesafeyi gösterir.
class _YonlendirmePaneli extends StatelessWidget {
  final YuruyusRotasi? rota;
  final Durak? hedef;
  final YonlendirmeDurumu? durum;
  final String? uyari;
  final bool varildi;
  final VoidCallback bitir;

  const _YonlendirmePaneli({
    required this.rota,
    required this.hedef,
    required this.durum,
    required this.uyari,
    required this.varildi,
    required this.bitir,
  });

  static String _mesafe(double metre) => metre < 1000
      ? '${metre.round()} m'
      : '${(metre / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renkler = tema.colorScheme;

    final manevra = varildi
        ? '${hedef?.ad ?? ""} durağına vardın.'
        : (rota != null && durum != null &&
                durum!.ilerleme.adimIndeksi < rota!.adimlar.length
            ? rota!.adimlar[durum!.ilerleme.adimIndeksi].metin
            : 'Devam et');

    return Card(
      color: renkler.primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    manevra,
                    style: tema.textTheme.titleMedium?.copyWith(
                      color: renkler.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  varildi ? '✓' : _mesafe(durum?.ilerleme.sonrakiManevraM ?? 0),
                  style: tema.textTheme.headlineSmall?.copyWith(
                    color: renkler.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: renkler.onPrimary.withValues(alpha: .25), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    varildi
                        ? 'Yolculuk başlasın.'
                        : 'Kalan: ${_mesafe(durum?.ilerleme.kalanM ?? 0)}',
                    style: tema.textTheme.bodySmall
                        ?.copyWith(color: renkler.onPrimary.withValues(alpha: .9)),
                  ),
                ),
                TextButton(
                  onPressed: bitir,
                  style: TextButton.styleFrom(foregroundColor: renkler.onPrimary),
                  child: const Text('Bitir'),
                ),
              ],
            ),
            if (uyari != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: renkler.onPrimary.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  uyari!,
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: renkler.onPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
