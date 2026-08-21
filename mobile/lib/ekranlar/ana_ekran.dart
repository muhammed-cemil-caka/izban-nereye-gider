import 'package:flutter/material.dart';
import '../modeller/durak.dart';
import '../modeller/yakin_durak.dart';
import '../modeller/yolculuk.dart';
import '../servisler/durak_servisi.dart';
import '../servisler/konum_servisi.dart';
import 'dart:async';
import '../servisler/rota_servisi.dart';
import '../servisler/ses_servisi.dart';
import '../servisler/yonlendirme_servisi.dart';
import 'harita_karti.dart';
import 'izban_logosu.dart';

class AnaEkran extends StatefulWidget {
  /// Verilmezse assets/duraklar.json okunur; testler hazır servis geçebilir.
  final DurakServisi? servis;

  /// Verilmezse gerçek cihaz konumu kullanılır; testler sahte servis geçebilir.
  final KonumServisi? konumServisi;

  /// Tema seçimi uygulama kökünde tutulur; üst bantdaki düğme onu değiştirir.
  final ThemeMode temaKipi;
  final ValueChanged<ThemeMode>? temaDegisti;

  const AnaEkran({
    super.key,
    this.servis,
    this.konumServisi,
    this.temaKipi = ThemeMode.system,
    this.temaDegisti,
  });

  @override
  State<AnaEkran> createState() => _AnaEkranDurumu();
}

class _AnaEkranDurumu extends State<AnaEkran> {
  late final DurakServisi _servis;
  final _kaydirma = ScrollController();

  /// Konum ve yön, setState yerine bu taşıyıcıyla haritaya gidiyor.
  /// Konum saniyede birkaç kez değişiyor; setState ile taşımak tüm ekranı,
  /// dolayısıyla haritanın döşeme katmanını yeniden kuruyordu.
  final _konumDurumu = ValueNotifier<KonumDurumu>(const KonumDurumu());

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
  Rota? _yuruyusRotasi;
  Durak? _rotaHedefi;
  RotaKipi _rotaKipi = RotaKipi.yuruyus;
  bool _rotaAraniyor = false;
  String? _rotaHatasi;

  /// Sesli yönlendirme — webdeki "Sesli" kutusunun karşılığı.
  final _ses = SesServisi();
  bool _sesliMi = true;

  /// Aynı talimatın her ölçümde yeniden okunmaması için son okunan adım.
  int? _seslendirilenAdim;

  StreamSubscription? _takipAboneligi;
  StreamSubscription? _yonlendirmeAboneligi;

  /// Arayüz bu bayrağı okur. Aboneliği doğrudan okumak yetmiyordu: abonelik
  /// setState dışında atandığı için harita yön okuna geçmiyordu.
  bool _yonlendirmeAktif = false;

  /// Yeniden hesaplama sürerken ikinci bir istek başlatılmasın.
  bool _yenidenHesaplaniyor = false;

  /// Yürüme sıralamasının hesaplandığı konum. Takip her ölçümde listeyi kuş
  /// uçuşuyla yeniden kurarsa yürüme sıralaması siliniyordu; kullanıcı kayda
  /// değer mesafe yürümedikçe liste korunur.
  Konum? _sonYuruyusKonumu;
  static const _yuruyusTazelemeM = 150.0;
  /// Yönlendirme paneli bunu dinler; her ölçümde tüm ekran çizilmesin.
  final _yonlendirmeNotifier = ValueNotifier<YonlendirmeDurumu?>(null);
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
          _konumDurumu.value = KonumDurumu(konum: konum);
          _kullaniciKonumu = konum;
          _konumHatasi = adaylar.isEmpty ? 'Duraklarda koordinat bilgisi yok.' : null;
          _konumAraniyor = false;
        });

        // Kuş uçuşu sıralama anında gösterilir; yürüme mesafesi gelince düzelir.
        _sonYuruyusKonumu = konum;
        _adaylariYuruyuseGoreSirala(konum, adaylar);

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
  /// Adayları gerçek yürüme mesafesine göre yeniden sıralar.
  ///
  /// Kuş uçuşu yanıltıyor: dere, otoyol veya demiryolu araya girdiğinde yakın
  /// görünen durak yürüyerek çok daha uzak olabiliyor. Ölçüldü: Çiğli kuş
  /// uçuşu daha yakın ama yürüyüşle 2,5 km; Mavişehir 1,4 km.
  Future<void> _adaylariYuruyuseGoreSirala(
    Konum konum,
    List<YakinDurak> adaylar,
  ) async {
    if (adaylar.isEmpty) return;

    try {
      final olcumler = await const RotaServisi()
          .yuruyusMesafeleri(konum, adaylar.map((a) => a.durak.konum).toList());
      if (!mounted) return;

      final yeniSira = <YakinDurak>[];
      for (var i = 0; i < adaylar.length; i++) {
        final olcum = i < olcumler.length ? olcumler[i] : null;
        yeniSira.add(olcum == null
            ? adaylar[i]
            : YakinDurak(adaylar[i].durak, olcum.mesafeM, yuruyusMu: true));
      }
      yeniSira.sort((a, b) => a.mesafeM.compareTo(b.mesafeM));

      setState(() {
        _yakinAdaylar = yeniSira;
        _yakinDurak = yeniSira.first;
      });
    } catch (_) {
      // Servise ulaşılamazsa kuş uçuşu sıralama kalır.
    }
  }

  /// Harita işareti kullanıcıyla birlikte hareket etsin diye takibi açar.
  void _takibiBaslat() {
    _takipAboneligi?.cancel();
    _takipAboneligi = _konumServisi.konumTakibi().listen((konum) async {
      // Yönlendirme kendi akışını kullanıyor; takip araya girmesin.
      if (_yonlendirmeAktif || !mounted) return;

      _konumDurumu.value = KonumDurumu(konum: konum);
      _kullaniciKonumu = konum;

      // Liste yerinde duruyorsa yeniden hesaplama: yürüme sıralaması korunur.
      final onceki = _sonYuruyusKonumu;
      if (_yakinAdaylar.isNotEmpty &&
          onceki != null &&
          onceki.metreUzaklik(konum) < _yuruyusTazelemeM) {
        return;
      }

      final duraklar = await _duraklarGelecegi;
      if (!mounted) return;
      final adaylar = YakinDurak.enYakinlar(duraklar, konum);
      setState(() {
        _yakinAdaylar = adaylar;
        _yakinDurak = adaylar.isEmpty ? null : adaylar.first;
      });

      _sonYuruyusKonumu = konum;
      _adaylariYuruyuseGoreSirala(konum, adaylar);
    }, onError: (_) { /* takip sessizce durur */ });
  }

  void _takibiKapat() {
    _takipAboneligi?.cancel();
    _takipAboneligi = null;
  }

  Future<void> _yolTarifiniGoster(
    YakinDurak yakin, {
    RotaKipi kip = RotaKipi.yuruyus,
  }) async {
    final konum = _kullaniciKonumu;
    if (konum == null) return;

    setState(() {
      _rotaKipi = kip;
      _rotaAraniyor = true;
      _rotaHatasi = null;
    });

    try {
      final rota = await const RotaServisi()
          .rotaAl(konum, yakin.durak.konum, kip: kip);
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
        _rotaHatasi = '${kip.etiket} rotası alınamadı.';
        _rotaAraniyor = false;
      });
    }
  }

  /// Sıradaki manevrayı okur. Aynı adım iki kez okunmaz: konum saniyede
  /// birkaç kez geliyor, her ölçümde konuşmak tekrar tekrar aynı cümleyi
  /// söylemek olurdu.
  void _adimiSeslendir(int adimIndeksi, Rota rota) {
    if (!_sesliMi) return;
    if (_seslendirilenAdim == adimIndeksi) return;
    if (adimIndeksi < 0 || adimIndeksi >= rota.adimlar.length) return;

    _seslendirilenAdim = adimIndeksi;
    _ses.konus(rota.adimlar[adimIndeksi].metin);
  }

  /// Aynı hedefe kipi değiştirerek yeniden rota ister.
  void _rotaKipiniDegistir(RotaKipi kip) {
    final hedef = _rotaHedefi;
    if (hedef == null || kip == _rotaKipi) return;
    if (_yonlendirmeAktif) _yonlendirmeyiBitir();
    _yolTarifiniGoster(YakinDurak(hedef, 0), kip: kip);
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

    _yonlendirmeNotifier.value = null;

    // Ok, ilk konum ölçümü gelmeden de rotanın yönüne baksın.
    _konumDurumu.value = KonumDurumu(
      konum: _kullaniciKonumu,
      yonlendirmede: true,
      aci: ilkAci,
    );

    setState(() {
      _varildi = false;
      _yonlendirmeUyarisi = null;
      _yonlendirmeAktif = true;
    });

    // İki konum akışı aynı anda çalışırsa Android istekleri birleştirip
    // seyrekleştiriyor; yönlendirme sırasında takip kapatılır.
    _takibiKapat();

    // İlk talimat hemen okunur: kullanıcı "Başla"ya bastığında ilk ölçümü
    // beklemeden nereye gideceğini duysun.
    _seslendirilenAdim = null;
    if (rota.adimlar.isNotEmpty) _adimiSeslendir(0, rota);

    _yonlendirmeAboneligi = YonlendirmeServisi.baslat(
      rota: rota,
      durumDegisti: (durum) {
        if (!mounted) return;

        _kullaniciKonumu = durum.konum;

        // Harita ve yönlendirme paneli bu taşıyıcıyı dinliyor; setState
        // çağrılmadığı için ekranın kalanı yeniden çizilmiyor.
        _konumDurumu.value = KonumDurumu(
          konum: durum.konum,
          yonlendirmede: true,
          aci: durum.aci,
          katEdilenM: durum.ilerleme.katEdilenM,
        );
        _yonlendirmeNotifier.value = durum;
        _adimiSeslendir(durum.ilerleme.adimIndeksi, rota);

        // Histerezis: uyarı 100 m'de çıkar, 70 m'nin altına inince kaybolur.
        // Tek bir eşik, doğruluk sınırda gezinirken uyarıyı yanıp söndürüyordu.
        final gorunuyor = _yonlendirmeUyarisi != null &&
            _yonlendirmeUyarisi!.startsWith('Konum ±');

        String? uyari;
        if (durum.dogrulukM > 100 || (gorunuyor && durum.dogrulukM > 70)) {
          uyari = 'Konum ±${durum.dogrulukM.round()} m — yönlendirme şaşabilir.';
        }

        if (uyari != _yonlendirmeUyarisi) {
          setState(() => _yonlendirmeUyarisi = uyari);
        }
      },
      rotadanCikildi: (konum) async {
        if (!mounted || _yenidenHesaplaniyor) return;

        // Eski oturum hemen kapatılmalı. Yoksa yeni rota beklenirken gelen
        // ölçümler üst üste yeni istekler tetikliyor ve "rotadan çıktın"
        // uyarısı yanıp sönüyordu.
        _yenidenHesaplaniyor = true;
        _yonlendirmeAboneligi?.cancel();
        _yonlendirmeAboneligi = null;

        final hedef = _rotaHedefi;
        if (hedef == null) {
          _yenidenHesaplaniyor = false;
          return;
        }

        // Uyarı basılmıyor: Google Haritalar gibi sessizce yeniden hesaplanıyor.
        // Uyarı, kısa süre sonra kaybolduğu için ekranda yanıp sönüyordu.
        _kullaniciKonumu = konum;

        try {
          final yeni = await const RotaServisi().rotaAl(konum, hedef.konum);
          if (!mounted) return;
          setState(() => _yuruyusRotasi = yeni);
          _yenidenHesaplaniyor = false;
          _yonlendirmeyiBaslat();
        } catch (_) {
          _yenidenHesaplaniyor = false;
          if (!mounted) return;
          setState(() => _yonlendirmeUyarisi = 'Yeni rota alınamadı.');
          _yonlendirmeyiBitir();
        }
      },
      varildi: () {
        if (!mounted) return;
        if (_sesliMi) _ses.konus('Vardın.');
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

  void _yonlendirmeyiBitir({bool varisSonrasi = false}) {
    _yonlendirmeAboneligi?.cancel();
    _yonlendirmeAboneligi = null;

    // Varışta "Vardın." okunuyor; onu kesmemek için orada susturulmuyor.
    if (!varisSonrasi) _ses.sustur();
    _seslendirilenAdim = null;

    if (mounted) {
      // İşaret yön okundan sürüklenebilir iğneye geri dönsün.
      _konumDurumu.value = KonumDurumu(konum: _kullaniciKonumu);
      if (!varisSonrasi) _yonlendirmeNotifier.value = null;

      setState(() {
        _yonlendirmeAktif = false;
        if (!varisSonrasi) _yonlendirmeUyarisi = null;
      });
    }
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    _konumDurumu.dispose();
    _yonlendirmeNotifier.dispose();
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
    final renkler = Theme.of(context).colorScheme;
    final koyuMu = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 12,
        title: Row(
          children: [
            // Logo beyaz plakanın üstünde durur: marka renkleri koyu temada
            // da okunur kalsın, kabartma dili kartlarla aynı olsun.
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: renkler.outlineVariant),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x220B1F3A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const IzbanLogosu(boyut: 34),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('İZBAN Nereye Gider?')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: koyuMu ? 'Açık temaya geç' : 'Koyu temaya geç',
            icon: Icon(koyuMu ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: widget.temaDegisti == null
                ? null
                : () => widget.temaDegisti!(
                      koyuMu ? ThemeMode.light : ThemeMode.dark,
                    ),
          ),
          const SizedBox(width: 4),
        ],
        // İnce marka şeridi: mavi → kırmızı.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0C4CA3), Color(0xFFED1B24)],
              ),
            ),
          ),
        ),
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
                yolTarifiAc: (yakin, kip) =>
                    _yolTarifiniGoster(yakin, kip: kip),
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
                yuruyusRotasi: _yuruyusRotasi,
                konumDurumu: _konumDurumu,
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
                  _konumDurumu.value = KonumDurumu(konum: konum);
                  setState(() {
                    _kullaniciKonumu = konum;
                    _yakinAdaylar = adaylar;
                    _yakinDurak = adaylar.isEmpty ? null : adaylar.first;
                    _konumDogrulukM = null;
                    _konumHatasi = null;
                  });
                },
              ),
              // Panel taşıyıcıyı dinliyor: her konum ölçümünde yalnızca bu
              // kart yeniden çiziliyor, harita dokunulmadan kalıyor.
              ValueListenableBuilder<YonlendirmeDurumu?>(
                valueListenable: _yonlendirmeNotifier,
                builder: (context, durum, _) {
                  if (durum == null && !_varildi) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _YonlendirmePaneli(
                      rota: _yuruyusRotasi,
                      hedef: _rotaHedefi,
                      durum: durum,
                      uyari: _yonlendirmeUyarisi,
                      varildi: _varildi,
                      sesliMi: _sesliMi,
                      sesDegisti: (acik) {
                        setState(() => _sesliMi = acik);
                        if (!acik) {
                          _ses.sustur();
                        } else {
                          // Ses yeniden açılınca sıradaki talimat hemen okunsun.
                          final rota = _yuruyusRotasi;
                          final indeks =
                              _yonlendirmeNotifier.value?.ilerleme.adimIndeksi;
                          _seslendirilenAdim = null;
                          if (rota != null && indeks != null) {
                            _adimiSeslendir(indeks, rota);
                          }
                        }
                      },
                      bitir: () {
                        setState(() => _varildi = false);
                        _yonlendirmeyiBitir();
                      },
                    ),
                  );
                },
              ),
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
                  kip: _rotaKipi,
                  kipDegisti: _rotaKipiniDegistir,
                ),
              ],
              const SizedBox(height: 16),
              if (yolculuk == null)
                const _UyariKarti(mesaj: 'Biniş ve iniş durağı aynı olamaz.')
              else ...[
                _OzetKarti(yolculuk: yolculuk),
                const SizedBox(height: 16),
                _GuzergahKarti(yolculuk: yolculuk),
                if (yolculuk.aktarmaliDuraklar.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AktarmaKarti(yolculuk: yolculuk),
                ],
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
              spacing: 10,
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

/// Yüzeyi eğimli, kenarı çizgili, altı gölgeli kutucuk.
///
/// Kabartma hissi üç katmandan geliyor: yüzeydeki eğim (gradyan), üst kenardaki
/// ışık çizgisi ve altındaki gölge — web'deki --kutu-yuzey/--kabartma/--golge
/// üçlüsünün karşılığı.
class KabarikKutu extends StatelessWidget {
  final Widget cocuk;
  final EdgeInsetsGeometry dolgu;
  final double yuvarlaklik;

  const KabarikKutu({
    super.key,
    required this.cocuk,
    this.dolgu = const EdgeInsets.all(14),
    this.yuvarlaklik = 12,
  });

  @override
  Widget build(BuildContext context) {
    final renkler = Theme.of(context).colorScheme;
    final acik = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: dolgu,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: acik
              ? const [Color(0xFFFFFFFF), Color(0xFFF2F6FC)]
              : const [Color(0xFF16294A), Color(0xFF0D1C33)],
        ),
        borderRadius: BorderRadius.circular(yuvarlaklik),
        // Kenar tek renk olmak zorunda (yuvarlatılmış kenarda Flutter böyle
        // istiyor); üstteki ışık hissi gradyanın açık ilk durağından geliyor.
        border: Border.all(color: renkler.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: acik ? const Color(0x1F0B1F3A) : const Color(0x66000000),
            blurRadius: 14,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: cocuk,
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
      child: KabarikKutu(
        cocuk: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deger,
              style: tema.textTheme.headlineSmall?.copyWith(
                color: tema.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(etiket, style: tema.textTheme.bodySmall),
          ],
        ),
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
                    // Simge + Tooltip yerine okunur rozet: hangi aktarma
                    // olduğunu görmek için basılı tutmak gerekiyordu, hatların
                    // adı hiç görünmüyordu. Hat adları aşağıdaki aktarma
                    // kartında yazıyor — webdeki düzenin aynısı.
                    if (durak.aktarmaVar) const _Rozet('AKTARMA'),
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

/// ESHOT hat numaraları. Çok hat olan duraklarda liste kartı şişirmesin diye
/// ilk [gorunurHat] tanesi gösterilir, gerisi "+N" olarak özetlenir.
class _OtobusHatlari extends StatelessWidget {
  static const gorunurHat = 12;

  final List<String> hatlar;

  const _OtobusHatlari({required this.hatlar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renkler = tema.colorScheme;
    final gosterilen = hatlar.take(gorunurHat).toList();
    final kalan = hatlar.length - gosterilen.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.directions_bus, size: 15, color: renkler.secondary),
        for (final hat in gosterilen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: renkler.secondary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              hat,
              style: tema.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: renkler.secondary,
              ),
            ),
          ),
        if (kalan > 0)
          Text(
            '+$kalan hat',
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.textTheme.bodySmall?.color?.withValues(alpha: .7),
            ),
          ),
      ],
    );
  }
}

/// Küçük etiket — webdeki .rozet karşılığı.
class _Rozet extends StatelessWidget {
  final String metin;

  const _Rozet(this.metin);

  @override
  Widget build(BuildContext context) {
    final renkler = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: renkler.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        metin,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: .5,
          color: renkler.primary,
        ),
      ),
    );
  }
}

/// Yol üstündeki aktarma noktaları ve hangi hatlara aktarma yapıldığı.
///
/// Özet kutusunda yalnızca sayı yazıyordu ("2 aktarma"); hangi durakta hangi
/// hatta geçileceği görünmüyordu. Webdeki "Yol üstündeki aktarmalar" kartının
/// karşılığı.
class _AktarmaKarti extends StatelessWidget {
  final Yolculuk yolculuk;

  const _AktarmaKarti({required this.yolculuk});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final duraklar = yolculuk.aktarmaliDuraklar;
    if (duraklar.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text('YOL ÜSTÜNDEKİ AKTARMALAR', style: tema.textTheme.labelMedium),
            ...duraklar.map(
              (durak) => KabarikKutu(
                dolgu: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                cocuk: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            durak.ad,
                            style: tema.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            durak.aktarma.join(' · '),
                            textAlign: TextAlign.end,
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: tema.textTheme.bodySmall?.color
                                  ?.withValues(alpha: .8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // ESHOT aktarması varsa hangi hatlar olduğu yazılır;
                    // "ESHOT" tek başına hangi otobüse bineceğini söylemiyor.
                    if (durak.otobusHatlari.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _OtobusHatlari(hatlar: durak.otobusHatlari),
                    ],
                  ],
                ),
              ),
            ),
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
  /// (durak, kip) — yürüyüş ya da araba rotası istenir.
  final void Function(YakinDurak, RotaKipi) yolTarifiAc;

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
            label: Text(
              yakin.yuruyusMu ? '${yakin.mesafeMetni} yürüyüş' : yakin.mesafeMetni,
            ),
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
            onPressed: () => yolTarifiAc(yakin, RotaKipi.yuruyus),
            icon: const Icon(Icons.directions_walk, size: 18),
            label: const Text('Yürüyerek'),
          ),
          OutlinedButton.icon(
            onPressed: () => yolTarifiAc(yakin, RotaKipi.araba),
            icon: const Icon(Icons.directions_car, size: 18),
            label: const Text('Arabayla'),
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
  final Rota? rota;
  final Durak? hedef;
  final bool araniyor;
  final String? hata;
  final VoidCallback temizle;

  final bool yonlendirmede;
  final VoidCallback basla;
  final VoidCallback bitir;

  /// Aynı hedefe kip değiştirerek yeniden rota istemek için.
  final RotaKipi kip;
  final ValueChanged<RotaKipi> kipDegisti;

  const _RotaKarti({
    required this.rota,
    required this.hedef,
    required this.araniyor,
    required this.hata,
    required this.temizle,
    required this.yonlendirmede,
    required this.basla,
    required this.bitir,
    required this.kip,
    required this.kipDegisti,
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
                    '${hedef?.ad ?? ""} durağına '
                    '${yol.kip == RotaKipi.araba ? "araba ile" : "yürüyüş"}',
                    style: tema.textTheme.titleSmall,
                  ),
                ),
                // Adım adım yönlendirme yürüyüş için tasarlandı: panel yürüme
                // temposundan süre hesaplıyor, harita yaya yakınlığında duruyor
                // ve sesli uyarı araç hızında geç kalıyor. Araba kipinde rota
                // gösterilir, yönlendirme başlatılmaz.
                if (yol.kip == RotaKipi.yuruyus)
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
            Row(
              spacing: 8,
              children: [
                Chip(
                  label: Text('${yol.mesafeMetni} · ${yol.sureMetni}'),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                SegmentedButton<RotaKipi>(
                  segments: const [
                    ButtonSegment(
                      value: RotaKipi.yuruyus,
                      icon: Icon(Icons.directions_walk, size: 18),
                      tooltip: 'Yürüyerek',
                    ),
                    ButtonSegment(
                      value: RotaKipi.araba,
                      icon: Icon(Icons.directions_car, size: 18),
                      tooltip: 'Arabayla',
                    ),
                  ],
                  selected: {kip},
                  showSelectedIcon: false,
                  onSelectionChanged: (secim) => kipDegisti(secim.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _AdimListesi(adimlar: yol.adimlar),
          ],
        ),
      ),
    );
  }
}

/// Yürüyüş adımları — aynı anda en fazla 7 tanesi görünür.
///
/// Önce bütün adımlar alt alta diziliyordu; uzun bir yürüyüşte kart ekranı
/// metrelerce uzatıyor, altındaki her şey aşağı kaçıyordu. Artık liste kendi
/// içinde kaydırılıyor.
class _AdimListesi extends StatefulWidget {
  final List<RotaAdimi> adimlar;

  const _AdimListesi({required this.adimlar});

  @override
  State<_AdimListesi> createState() => _AdimListesiDurumu();
}

class _AdimListesiDurumu extends State<_AdimListesi> {
  static const gorunurAdim = 7;
  final _kaydirma = ScrollController();

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  static String _mesafe(double metre) => metre < 1000
      ? '${metre.round()} m'
      : '${(metre / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.textTheme.bodySmall
        ?.copyWith(color: tema.textTheme.bodySmall?.color?.withValues(alpha: .6));

    final satirlar = widget.adimlar
        .map((adim) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chevron_right, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(adim.metin, style: tema.textTheme.bodySmall),
                  ),
                  Text(_mesafe(adim.mesafeM), style: soluk),
                ],
              ),
            ))
        .toList();

    if (satirlar.length <= gorunurAdim) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: satirlar);
    }

    // Sabit piksel yerine gerçek satır yüksekliği ölçülüyor: yazı boyutunu
    // büyüten kullanıcıda da tam 7 adımlık pencere kalsın.
    final olcer = TextPainter(
      text: TextSpan(text: 'Örnek', style: tema.textTheme.bodySmall),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final satirYuksekligi = olcer.height + 6; // dikey dolgu 3 + 3

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: satirYuksekligi * gorunurAdim,
          child: Scrollbar(
            controller: _kaydirma,
            thumbVisibility: true,
            child: ListView(
              controller: _kaydirma,
              padding: const EdgeInsets.only(right: 10),
              children: satirlar,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.adimlar.length} adım · listeyi kaydırarak devamını gör',
          style: soluk,
        ),
      ],
    );
  }
}

/// Yönlendirme sırasında sıradaki manevrayı ve kalan mesafeyi gösterir.
class _YonlendirmePaneli extends StatelessWidget {
  final Rota? rota;
  final Durak? hedef;
  final YonlendirmeDurumu? durum;
  final String? uyari;
  final bool varildi;
  final VoidCallback bitir;

  /// Sesli yönlendirme açık mı — webdeki "Sesli" kutusunun karşılığı.
  final bool sesliMi;
  final ValueChanged<bool> sesDegisti;

  const _YonlendirmePaneli({
    required this.rota,
    required this.hedef,
    required this.durum,
    required this.uyari,
    required this.varildi,
    required this.bitir,
    required this.sesliMi,
    required this.sesDegisti,
  });

  static String _mesafe(double metre) => metre < 1000
      ? '${metre.round()} m'
      : '${(metre / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  /// Kalan süreyi rotanın kendi temposundan hesaplar.
  ///
  /// Sabit bir yürüyüş hızı varsaymak yerine, servis o rota için ne kadar süre
  /// öngördüyse (yokuş, yaya geçidi, kavşak dahil) aynı tempo kalan mesafeye
  /// uygulanıyor.
  static String? _kalanSure(Rota? rota, double kalanM) {
    if (rota == null || rota.mesafeM <= 0) return null;

    final saniye = rota.sureSn * (kalanM / rota.mesafeM);
    final dakika = (saniye / 60).round().clamp(1, 1 << 31);

    if (dakika < 60) return '$dakika dk';
    final saat = dakika ~/ 60;
    final kalanDk = dakika % 60;
    return kalanDk == 0 ? '$saat sa' : '$saat sa $kalanDk dk';
  }

  /// Anlık hız; hareket algılanmıyorsa null.
  ///
  /// Kamera kullanıcıyı ortada tuttuğu için ok sabit duruyormuş gibi görünüyor;
  /// hız, konumun gerçekten güncellendiğinin doğrudan göstergesi.
  static String? _hizMetni(double hizMs) {
    if (hizMs < 0.3) return null;
    return '${(hizMs * 3.6).toStringAsFixed(1).replaceAll('.', ',')} km/sa';
  }

  String _kalanMetni(double kalanM) {
    final sure = _kalanSure(rota, kalanM);
    return sure == null
        ? 'Kalan: ${_mesafe(kalanM)}'
        : 'Kalan: ${_mesafe(kalanM)} · $sure';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renkler = tema.colorScheme;

    // Yerel değişkene alınıyor: alan üzerinden null denetimi Dart'ta
    // yükseltilemiyor (public property promotion yok).
    final ilerleme = durum?.ilerleme;

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
            // Talimat alanı iki satırlık sabit yükseklikte tutuluyor.
            // Değişken yükseklik, talimat kısaldıkça/uzadıkça kartın boyunu
            // değiştiriyor ve altındaki her şeyi oynatıyordu — ekran
            // "gidip geliyor" gibi görünüyordu.
            SizedBox(
              height: 62,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      manevra,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium?.copyWith(
                        color: renkler.onPrimary,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
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
            ),
            const SizedBox(height: 6),
            Divider(color: renkler.onPrimary.withValues(alpha: .25), height: 1),
            const SizedBox(height: 8),
            // Bitir düğmesi buradan kaldırıldı; alttaki rota kartında zaten var.
            Row(
              children: [
                Expanded(
                  child: Text(
                    varildi
                        ? 'Yolculuk başlasın.'
                        : _kalanMetni(durum?.ilerleme.kalanM ?? 0),
                    style: tema.textTheme.bodySmall
                        ?.copyWith(color: renkler.onPrimary.withValues(alpha: .9)),
                  ),
                ),
                // Sesli yönlendirme anahtarı: talimatlar yürürken okunur.
                IconButton(
                  onPressed: () => sesDegisti(!sesliMi),
                  visualDensity: VisualDensity.compact,
                  tooltip: sesliMi ? 'Sesi kapat' : 'Sesi aç',
                  icon: Icon(
                    sesliMi ? Icons.volume_up : Icons.volume_off,
                    size: 20,
                    color: renkler.onPrimary
                        .withValues(alpha: sesliMi ? 1 : .55),
                  ),
                ),
              ],
            ),
            if (!varildi && ilerleme != null && rota != null) ...[
              const SizedBox(height: 10),
              // Toplam yürüyüşün ne kadarı bitti: çubuk ve büyük sayılar.
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: rota!.mesafeM > 0
                      ? (ilerleme.katEdilenM / rota!.mesafeM).clamp(0.0, 1.0)
                      : 0,
                  minHeight: 6,
                  backgroundColor: renkler.onPrimary.withValues(alpha: .25),
                  valueColor: AlwaysStoppedAnimation(renkler.onPrimary),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _mesafe(ilerleme.katEdilenM),
                    style: tema.textTheme.titleSmall?.copyWith(
                      color: renkler.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    ' / ${_mesafe(rota!.mesafeM)}',
                    style: tema.textTheme.titleSmall?.copyWith(
                      color: renkler.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _hizMetni(durum?.hizMs ?? 0) ?? 'toplam yürüyüş',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: renkler.onPrimary.withValues(alpha: .8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
