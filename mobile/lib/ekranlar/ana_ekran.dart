import 'package:flutter/material.dart';
import '../diller.dart';
import '../modeller/durak.dart';
import '../modeller/yakin_durak.dart';
import '../modeller/turistik_yer.dart';
import '../modeller/yolculuk.dart';
import '../servisler/durak_servisi.dart';
import '../servisler/konum_servisi.dart';
import 'dart:async';
import '../servisler/rota_servisi.dart';
import '../servisler/sefer_servisi.dart';
import '../servisler/turistik_servisi.dart';
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

  /// Dil de kökte tutulur; üst bantta TR/EN düğmesi var.
  final String dilKodu;
  final ValueChanged<String>? dilDegisti;

  const AnaEkran({
    super.key,
    this.servis,
    this.konumServisi,
    this.temaKipi = ThemeMode.system,
    this.temaDegisti,
    this.dilKodu = 'tr',
    this.dilDegisti,
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
  List<TuristikYer> _turistikYerler = const [];

  /// Sefer saatleri: durak çifti → yolculuk listesi. Tarife gün içinde
  /// değişmediği için oturum boyu saklanıyor.
  final Map<String, List<SeferYolculugu>> _seferOnbellegi = {};
  String? _seferAnahtari;
  bool _seferAraniyor = false;
  bool _seferHatasi = false;

  String? _binisKod;
  String? _inisKod;

  KonumServisi get _konumServisi => widget.konumServisi ?? const KonumServisi();
  YakinDurak? _yakinDurak;
  List<YakinDurak> _yakinAdaylar = const [];
  double? _konumDogrulukM;
  Konum? _kullaniciKonumu;
  Rota? _yuruyusRotasi;
  RotaHedefi? _rotaHedefi;
  RotaKipi _rotaKipi = RotaKipi.yuruyus;

  /// En yakın durak listesi hangi kiple sıralandı?
  RotaKipi _siralamaKipi = RotaKipi.yuruyus;
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

  /// Doğruluk uyarısı ekranda mı? Histerezis için metne bakmak yetmiyor:
  /// aynı uyarı iki dilde de yazılabiliyor.
  bool _dogrulukUyarisiAcik = false;
  bool _varildi = false;
  String? _konumHatasi;
  bool _konumAyarlariGerekli = false;
  bool _konumAraniyor = false;

  @override
  void initState() {
    super.initState();
    _servis = widget.servis ?? DurakServisi();
    _duraklarGelecegi = _servis.duraklariGetir();
    _turistikYerleriYukle();

    // Kullanıcı uygulamayı açar açmaz konum isteniyor; reddedilirse uygulama
    // normal çalışmaya devam eder, yalnızca en yakın durak kartı kapanır.
    WidgetsBinding.instance.addPostFrameCallback((_) => _konumuBul());
  }

  /// Biniş → iniş için sefer saatlerini getirir (gerekirse).
  ///
  /// Servis yalnızca aktarmasız seferleri döndürüyor; dilim aşan çiftlerde
  /// (ör. Halkapınar → Selçuk) yolculuk sefer_servisi.dart'ta Cumaovası ve
  /// Tepeköy aktarmalarıyla kuruluyor.
  Future<void> _seferleriGetir(List<Durak> duraklar, Durak binis, Durak inis) async {
    if (binis.izbanId == null || inis.izbanId == null) return;

    final anahtar = '${binis.kod}-${inis.kod}';
    if (_seferAnahtari == anahtar) return;   // zaten bu çift için istendi
    _seferAnahtari = anahtar;

    if (_seferOnbellegi.containsKey(anahtar)) {
      setState(() => _seferHatasi = false);
      return;
    }

    setState(() {
      _seferAraniyor = true;
      _seferHatasi = false;
    });

    try {
      final seferler = await const SeferServisi()
          .yolculukSeferleriAl(duraklar, binis.kod, inis.kod);
      if (!mounted || _seferAnahtari != anahtar) return;
      setState(() {
        _seferOnbellegi[anahtar] = seferler;
        _seferAraniyor = false;
      });
    } catch (_) {
      if (!mounted || _seferAnahtari != anahtar) return;
      setState(() {
        _seferAraniyor = false;
        _seferHatasi = true;
      });
    }
  }

  Future<void> _turistikYerleriYukle() async {
    final yerler = await const TuristikServisi().yerleriGetir();
    if (!mounted) return;
    setState(() => _turistikYerler = yerler);
  }

  /// Turistik yere yol tarifi.
  ///
  /// Rota kullanıcının konumundan değil, **o kipe göre en yakın DURAKTAN**
  /// çizilir: kullanıcı oraya İZBAN ile geliyor. Durak da kipin kendi ağıyla
  /// seçilir — yürürken yakın olan durak arabayla dolambaçlı olabiliyor.
  Future<void> _yereYolTarifi(TuristikYer yer, RotaKipi kip) async {
    final duraklar = await _duraklarGelecegi;
    if (!mounted) return;

    setState(() {
      _rotaKipi = kip;
      _rotaAraniyor = true;
      _rotaHatasi = null;
    });

    try {
      final durak = await _yereEnYakinDurak(yer, duraklar, kip);
      if (!mounted) return;

      // Haritada o durağı seçili getir.
      setState(() {
        _binisKod = durak.kod;
        if (_inisKod == _binisKod) {
          final indeks = duraklar.indexWhere((d) => d.kod == durak.kod);
          _inisKod = indeks < duraklar.length / 2
              ? duraklar.last.kod
              : duraklar.first.kod;
        }
      });

      final rota = await const RotaServisi()
          .rotaAl(durak.konum, yer.konum, kip: kip);
      if (!mounted) return;

      setState(() {
        _yuruyusRotasi = rota;
        _rotaHedefi = RotaHedefi(yer.ad, yer.konum);
        _rotaAraniyor = false;
      });
      _haritayaKaydir();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rotaHatasi = Diller.aktif('rotaAlinamadi', {'kip': kip.etiket});
        _rotaAraniyor = false;
      });
    }
  }

  /// Bir yere kipin ağına göre en yakın durak.
  ///
  /// Kuş uçuşu YALNIZCA ön eleme için (6 aday); karar OSRM matrisinden gelen
  /// SÜREYE göre verilir. Araçta uzun ama hızlı çevre yol, kısa ama yavaş
  /// şehir içinden iyi olabiliyor.
  Future<Durak> _yereEnYakinDurak(
    TuristikYer yer,
    List<Durak> duraklar,
    RotaKipi kip,
  ) async {
    final adaylar = YakinDurak.enYakinlar(duraklar, yer.konum, adet: 6);
    if (adaylar.isEmpty) throw Exception(Diller.aktif('durakBulunamadi'));

    try {
      final olcumler = await const RotaServisi().mesafeler(
        yer.konum,
        adaylar.map((a) => a.durak.konum).toList(),
        kip: kip,
      );

      var enIyi = adaylar.first.durak;
      var enIyiSure = double.infinity;
      for (var i = 0; i < adaylar.length; i++) {
        final olcum = i < olcumler.length ? olcumler[i] : null;
        final sure = olcum?.sureSn ?? double.infinity;
        if (sure < enIyiSure) {
          enIyiSure = sure;
          enIyi = adaylar[i].durak;
        }
      }
      return enIyi;
    } catch (_) {
      // Servis yanıt vermezse kuş uçuşu sıralama kalır; akış kesilmez.
      return adaylar.first.durak;
    }
  }

  /// Toplu taşıma: gerçek bir sefer motorumuz yok, aktarma zinciri anlatılır.
  void _topluTasimaAnlat(TuristikYer yer, List<Durak> duraklar) {
    final adaylar = YakinDurak.enYakinlar(duraklar, yer.konum, adet: 1);
    if (adaylar.isEmpty) return;

    final durak = adaylar.first.durak;
    final hatlar = durak.otobusHatlari.take(6).join(', ');
    final aktarma = durak.aktarma.join(' · ');

    final ceviri = Diller.of(context);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ceviri('topluBaslik', {'yer': yer.ad})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text('1. ${ceviri('topluAdim1', {'durak': durak.ad})}'),
            if (aktarma.isNotEmpty)
              Text('2. ${ceviri('topluAdim2', {'durak': durak.ad, 'aktarma': aktarma})}'),
            if (hatlar.isNotEmpty)
              Text('3. ${ceviri('topluAdim3', {'hatlar': hatlar})}'),
            Text('4. ${ceviri('topluAdim4', {'yer': yer.ad})}'),
            const Divider(),
            Text(ceviri('topluNot'), style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ceviri('tamam')),
          ),
        ],
      ),
    );
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
        _adaylariGercekMesafeyeGoreSirala(konum, adaylar, kip: _siralamaKipi);

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
  Future<void> _adaylariGercekMesafeyeGoreSirala(
    Konum konum,
    List<YakinDurak> adaylar, {
    RotaKipi kip = RotaKipi.yuruyus,
  }) async {
    if (adaylar.isEmpty) return;

    try {
      final olcumler = await const RotaServisi().mesafeler(
        konum,
        adaylar.map((a) => a.durak.konum).toList(),
        kip: kip,
      );
      if (!mounted) return;

      // Kullanıcı bu arada kipi değiştirdiyse eski yanıt listeyi bozmasın.
      if (kip != _siralamaKipi) return;

      final yeniSira = <YakinDurak>[];
      for (var i = 0; i < adaylar.length; i++) {
        final olcum = i < olcumler.length ? olcumler[i] : null;
        yeniSira.add(olcum == null
            ? adaylar[i]
            : YakinDurak(adaylar[i].durak, olcum.mesafeM, kip: kip));
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

  /// En yakın durak listesini verilen kiple yeniden sıralar.
  ///
  /// Yürüyerek en yakın durak ile arabayla en yakın durak aynı olmayabiliyor:
  /// yaya köprüsünden geçilen durak yürüyerek yakın ama arabayla dolambaçlı.
  void _siralamaKipiniDegistir(RotaKipi kip) {
    if (kip == _siralamaKipi) return;
    setState(() => _siralamaKipi = kip);

    final konum = _kullaniciKonumu;
    if (konum != null && _yakinAdaylar.isNotEmpty) {
      _adaylariGercekMesafeyeGoreSirala(konum, _yakinAdaylar, kip: kip);
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
      _adaylariGercekMesafeyeGoreSirala(konum, adaylar, kip: _siralamaKipi);
    }, onError: (_) { /* takip sessizce durur */ });
  }

  void _takibiKapat() {
    _takipAboneligi?.cancel();
    _takipAboneligi = null;
  }

  /// Verilen hedefe rota çizer.
  ///
  /// [yonlendir] verilirse rota gelir gelmez canlı yönlendirme de başlar:
  /// kullanıcı aktarma noktasına dokunduğunda beklediği şey rota değil,
  /// yönlendirmenin kendisi.
  Future<void> _yolTarifiniGoster(
    RotaHedefi hedef, {
    RotaKipi kip = RotaKipi.yuruyus,
    bool yonlendir = false,
  }) async {
    final konum = _kullaniciKonumu;
    if (konum == null) return;

    setState(() {
      _rotaKipi = kip;
      _rotaAraniyor = true;
      _rotaHatasi = null;
    });

    try {
      final rota =
          await const RotaServisi().rotaAl(konum, hedef.konum, kip: kip);
      if (!mounted) return;
      setState(() {
        _yuruyusRotasi = rota;
        _rotaHedefi = hedef;
        _rotaAraniyor = false;
      });
      _haritayaKaydir();
      if (yonlendir) _yonlendirmeyiBaslat();
    } catch (sorun) {
      if (!mounted) return;
      setState(() {
        _rotaHatasi = Diller.aktif('rotaAlinamadi', {'kip': kip.etiket});
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
    _yolTarifiniGoster(hedef, kip: kip);
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
        // Metne bakmak yetmiyor artık: uyarı iki dilde de yazılabiliyor.
        final gorunuyor = _dogrulukUyarisiAcik;

        String? uyari;
        if (durum.dogrulukM > 100 || (gorunuyor && durum.dogrulukM > 70)) {
          uyari = Diller.aktif(
            'yonlendirmeSasabilir',
            {'m': durum.dogrulukM.round()},
          );
        }

        if (uyari != _yonlendirmeUyarisi) {
          setState(() {
            _yonlendirmeUyarisi = uyari;
            _dogrulukUyarisiAcik = uyari != null;
          });
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
          final yeni = await const RotaServisi()
              .rotaAl(konum, hedef.konum, kip: _rotaKipi);
          if (!mounted) return;
          setState(() => _yuruyusRotasi = yeni);
          _yenidenHesaplaniyor = false;
          _yonlendirmeyiBaslat();
        } catch (_) {
          _yenidenHesaplaniyor = false;
          if (!mounted) return;
          setState(() {
            _yonlendirmeUyarisi = Diller.aktif('yeniRotaYok');
            _dogrulukUyarisiAcik = false;
          });
          _yonlendirmeyiBitir();
        }
      },
      varildi: () {
        if (!mounted) return;
        if (_sesliMi) _ses.konus(Diller.aktif('vardin'));
        setState(() => _varildi = true);
        _yonlendirmeyiBitir(varisSonrasi: true);
      },
      hataOldu: (_) {
        if (!mounted) return;
        setState(() {
          _yonlendirmeUyarisi = Diller.aktif('konumYokYonlendirme');
          _dogrulukUyarisiAcik = false;
        });
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
    // Ekran kapanırken okunan talimat sürüyorsa kesilsin.
    _ses.sustur();
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
    final ceviri = Diller.of(context);

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
          TextButton(
            onPressed: widget.dilDegisti == null
                ? null
                : () => widget.dilDegisti!(widget.dilKodu == 'tr' ? 'en' : 'tr'),
            style: TextButton.styleFrom(
              minimumSize: const Size(40, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              widget.dilKodu == 'tr' ? 'EN' : 'TR',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: koyuMu ? ceviri('temaAcik') : ceviri('temaKoyu'),
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
            return Center(
              child: Text(Diller.of(context)
                  .call('veriOkunamadiAyrinti', {'ayrinti': anlik.error})),
            );
          }

          final duraklar = anlik.data!;
          _binisKod ??= duraklar.first.kod;
          _inisKod ??= duraklar.last.kod;

          final yolculuk = Yolculuk.hesapla(duraklar, _binisKod!, _inisKod!);

          // Seçim değiştiyse sefer saatleri tazelenir; çizim sırasında
          // setState çağırmamak için kare sonuna bırakılıyor.
          if (yolculuk != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _seferleriGetir(duraklar, yolculuk.binis, yolculuk.inis),
            );
          }

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
                yolTarifiAc: (yakin, kip) {
                  // Kullanıcı "arabayla" dediğinde sorduğu şey "hangi durağa
                  // arabayla daha kısa giderim"; liste de o kiple sıralanır.
                  _siralamaKipiniDegistir(kip);
                  _yolTarifiniGoster(RotaHedefi.durak(yakin.durak), kip: kip);
                },
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
                  kipDegisti: (kip) {
                    _siralamaKipiniDegistir(kip);
                    _rotaKipiniDegistir(kip);
                  },
                ),
              ],
              const SizedBox(height: 16),
              if (yolculuk == null)
                _UyariKarti(mesaj: ceviri('ayniDurak'))
              else ...[
                _OzetKarti(yolculuk: yolculuk),
                const SizedBox(height: 16),
                _SeferKarti(
                  binis: yolculuk.binis,
                  inis: yolculuk.inis,
                  seferler: _seferOnbellegi['${yolculuk.binis.kod}-${yolculuk.inis.kod}'],
                  araniyor: _seferAraniyor,
                  hata: _seferHatasi,
                ),
                const SizedBox(height: 16),
                _GuzergahKarti(yolculuk: yolculuk),
                if (_turistikYerler.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _GeziKarti(
                    yerler: _turistikYerler,
                    binis: yolculuk.binis,
                    inis: yolculuk.inis,
                    yolTarifi: _yereYolTarifi,
                    topluTasima: (yer) => _topluTasimaAnlat(yer, duraklar),
                  ),
                ],
                if (yolculuk.aktarmaliDuraklar.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AktarmaKarti(
                    yolculuk: yolculuk,
                    aktarmayaGit: (nokta) => _yolTarifiniGoster(
                      RotaHedefi.aktarma(nokta),
                      yonlendir: true,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              Text(
                '${ceviri('tarifeUyarisi')}\n'
                '${ceviri('veriSurumu')}: ${_servis.surum} · '
                '${ceviri('kaynak')}: ${_servis.kaynakEtiketi}',
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
    final ceviri = Diller.of(context);

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
                tooltip: ceviri('yerDegistir'),
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
    final ceviri = Diller.of(context);

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
                _OzetKutu(deger: yolculuk.sureMetni, etiket: ceviri('ozetSure')),
                _OzetKutu(
                  deger: '${yolculuk.durakSayisi}',
                  etiket: ceviri('ozetDurak'),
                ),
                _OzetKutu(
                  deger: '${yolculuk.aktarmaliDuraklar.length}',
                  etiket: ceviri('ozetAktarma'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              ceviri('ozetCumle', {
                'binis': yolculuk.binis.ad,
                'yon': yolculuk.yonDurakAdi,
                'durak': yolculuk.durakSayisi,
                'sure': yolculuk.sureMetni,
                'inis': yolculuk.inis.ad,
              }),
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
    final ceviri = Diller.of(context);
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ceviri('guzergah'), style: tema.textTheme.labelMedium),
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
                    if (durak.aktarmaVar) _Rozet(ceviri('aktarmaRozet')),
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

/// Biniş durağından iniş durağına sıradaki trenler.
///
/// Veri İzmir Büyükşehir Belediyesi açık servisinden. Dilim aşan çiftlerde
/// yolculuk Cumaovası/Tepeköy aktarmasıyla kuruluyor; aktarma satırın altında
/// bekleme süresiyle yazıyor.
class _SeferKarti extends StatelessWidget {
  static const gorunurSefer = 4;

  final Durak binis;
  final Durak inis;
  final List<SeferYolculugu>? seferler;
  final bool araniyor;
  final bool hata;

  const _SeferKarti({
    required this.binis,
    required this.inis,
    required this.seferler,
    required this.araniyor,
    required this.hata,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renkler = tema.colorScheme;
    final ceviri = Diller.of(context);

    if (binis.izbanId == null || inis.izbanId == null) {
      return const SizedBox.shrink();
    }

    final soluk = tema.textTheme.bodySmall?.copyWith(
      color: tema.textTheme.bodySmall?.color?.withValues(alpha: .7),
    );

    Widget govde;
    if (araniyor) {
      govde = Row(
        children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text(ceviri('seferAliniyor'), style: soluk),
        ],
      );
    } else if (hata) {
      govde = Text(ceviri('seferUlasilamiyor'), style: soluk);
    } else if (seferler == null) {
      govde = const SizedBox.shrink();
    } else if (seferler!.isEmpty) {
      govde = Text(ceviri('seferYok'), style: soluk);
    } else {
      final siradaki = SeferServisi.siradakiler(seferler!, gorunurSefer);
      govde = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          for (var i = 0; i < siradaki.length; i++)
            _seferSatiri(context, siradaki[i], ilk: i == 0),
          const SizedBox(height: 2),
          Text(
            '${ceviri('seferSayisi', {'adet': seferler!.length})}'
            ' · ${_aktarmaOzeti(ceviri)} · ${ceviri('seferKaynak')}',
            style: soluk?.copyWith(fontSize: 11),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(ceviri('siradakiTrenler'), style: tema.textTheme.labelMedium),
            Text(
              '${binis.ad} → ${inis.ad}',
              style: tema.textTheme.bodySmall?.copyWith(
                color: renkler.onSurface.withValues(alpha: .7),
              ),
            ),
            govde,
          ],
        ),
      ),
    );
  }

  /// Not satırında "aktarmasız" / "1 aktarma" yazar; listeye bakınca kaç kez
  /// tren değiştirileceği anlaşılmıyor.
  String _aktarmaOzeti(Diller ceviri) {
    final enAz = seferler!
        .map((s) => s.aktarmalar.length)
        .reduce((a, b) => a < b ? a : b);
    if (enAz == 0) return ceviri('seferAktarmasiz');
    return ceviri(enAz == 1 ? 'seferBirAktarma' : 'seferIkiAktarma');
  }

  Widget _seferSatiri(BuildContext context, SiradakiSefer sefer, {required bool ilk}) {
    final tema = Theme.of(context);
    final renkler = tema.colorScheme;
    final ceviri = Diller.of(context);

    final kalan = sefer.ertesiGun
        ? ceviri('yarin')
        : sefer.kalanDk == 0
            ? ceviri('simdi')
            : '${sefer.kalanDk} ${ceviri('dkSonra')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        // İlk sefer vurgulanır: kullanıcının yetişeceği tren o.
        color: ilk ? renkler.primary.withValues(alpha: .10) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                sefer.sefer.kalkis,
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ilk ? renkler.primary : renkler.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '→ ${sefer.sefer.varis}',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: renkler.onSurface.withValues(alpha: .7),
                ),
              ),
              const Spacer(),
              Text(
                kalan,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: ilk ? renkler.primary : renkler.onSurface.withValues(alpha: .7),
                  fontWeight: ilk ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
          // Aktarma notu satırın altına iner: kalkış–varış hizası bozulmasın.
          if (sefer.sefer.aktarmalar.isNotEmpty)
            Text(
              sefer.sefer.aktarmalar
                  .map((a) => ceviri('seferAktarmaNotu',
                      {'durak': a.durak, 'dk': a.beklemeDk}))
                  .join(' · '),
              style: tema.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: renkler.onSurface.withValues(alpha: .7),
              ),
            ),
        ],
      ),
    );
  }
}

/// Biniş ve iniş durağının çevresindeki gezilecek yerler.
///
/// Kartlar yatay şeritte: Alsancak Gar çevresinde 32 yer var, alt alta dizmek
/// ekranı boyunca uzatırdı.
class _GeziKarti extends StatelessWidget {
  /// Durak başına gösterilecek en fazla kart.
  static const gorunurYer = 8;

  final List<TuristikYer> yerler;
  final Durak binis;
  final Durak inis;
  final void Function(TuristikYer, RotaKipi) yolTarifi;
  final ValueChanged<TuristikYer> topluTasima;

  const _GeziKarti({
    required this.yerler,
    required this.binis,
    required this.inis,
    required this.yolTarifi,
    required this.topluTasima,
  });

  @override
  Widget build(BuildContext context) {
    final ceviri = Diller.of(context);
    final tema = Theme.of(context);

    final gruplar =
        <(String, String, List<({TuristikYer yer, double mesafeM})>)>[];
    for (final durak in {binis, inis}) {
      final yakinlar = TuristikServisi.duragaYakinlar(yerler, durak.kod);
      if (yakinlar.isNotEmpty) {
        gruplar.add((
          ceviri('geziCevresiTam', {'durak': durak.ad}),
          durak.ilce,
          yakinlar,
        ));
      }
    }
    if (gruplar.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ceviri('geziBaslik'), style: tema.textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    ceviri('geziIpucu'),
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            for (final (baslik, ilce, liste) in gruplar) ...[
              Text(
                '$baslik · ${liste.length} ${ceviri('yer')}',
                style: tema.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: .4,
                ),
              ),
              SizedBox(
                height: 300,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16),
                  itemCount: liste.length > gorunurYer ? gorunurYer : liste.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, sira) => _YerKarti(
                    kayit: liste[sira],
                    ilce: ilce,
                    yolTarifi: yolTarifi,
                    topluTasima: topluTasima,
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                ceviri('geziKaynak'),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.textTheme.bodySmall?.color?.withValues(alpha: .7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek bir turistik yer kartı: fotoğraf, başlık, kısa tarihçe, yol tarifi.
class _YerKarti extends StatelessWidget {
  static const simgeler = <String, IconData>{
    'antik-kent': Icons.account_balance,
    'muze': Icons.museum,
    'cami': Icons.mosque,
    'kilise': Icons.church,
    'kale': Icons.castle,
    'anit': Icons.emoji_flags,
    'park': Icons.park,
    'kultur-varligi': Icons.auto_awesome,
    'kule': Icons.cell_tower,
    'tarihi-yapi': Icons.home_work,
  };

  /// Tür etiketleri; özet yoksa açıklama bunlardan üretilir.
  static const turAnahtarlari = <String, String>{
    'antik-kent': 'turAntikKent',
    'muze': 'turMuze',
    'cami': 'turCami',
    'kilise': 'turKilise',
    'kale': 'turKale',
    'anit': 'turAnit',
    'park': 'turPark',
    'kultur-varligi': 'turKulturVarligi',
    'kule': 'turKule',
    'tarihi-yapi': 'turTarihiYapi',
    'gezi-noktasi': 'turGeziNoktasi',
  };

  final ({TuristikYer yer, double mesafeM}) kayit;

  /// En yakın durağın ilçesi — üretilen açıklamada geçiyor.
  final String ilce;

  final void Function(TuristikYer, RotaKipi) yolTarifi;
  final ValueChanged<TuristikYer> topluTasima;

  const _YerKarti({
    required this.kayit,
    required this.ilce,
    required this.yolTarifi,
    required this.topluTasima,
  });

  static String _mesafe(double m) => Diller.aktif.mesafe(m);

  /// Kart özeti.
  ///
  /// Wikidata/Vikipedi özeti seçili dilde olmayabiliyor: 95 yerin 5'inde
  /// İngilizce açıklama, 7'sinde Türkçe açıklama yok. Eskiden diğer dilin
  /// metnine düşülüyordu ve İngilizce arayüzde Türkçe cümleler kalıyordu.
  /// Artık türden ve ilçeden kısa bir açıklama üretiliyor.
  String _ozet(Diller ceviri) {
    final yer = kayit.yer;
    final ozet = ceviri.kod == 'en' ? yer.ozetEn : yer.ozet;
    if (ozet.isNotEmpty) return ozet;

    return ceviri('geziTurAciklama', {
      'tur': ceviri(turAnahtarlari[yer.tur] ?? 'turGeziNoktasi'),
      'ilce': ilce,
    });
  }

  @override
  Widget build(BuildContext context) {
    final ceviri = Diller.of(context);
    final tema = Theme.of(context);
    final renkler = tema.colorScheme;
    final yer = kayit.yer;

    return SizedBox(
      width: 230,
      child: KabarikKutu(
        dolgu: EdgeInsets.zero,
        cocuk: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Görsel kutusu her kartta var. Fotoğrafsız kartta öge tümden
            // atlanırsa kart 120 px kısalıyor ve şeritteki kartlar birbirini
            // tutmuyor; yerine tür simgesi konur.
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: yer.gorsel == null
                  ? _gorselYedegi(renkler, yer.tur)
                  : Image.network(
                      yer.gorsel!.kucukAdres,
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _gorselYedegi(renkler, yer.tur),
                      loadingBuilder: (context, cocuk, ilerleme) =>
                          ilerleme == null
                              ? cocuk
                              : Container(
                                  height: 120,
                                  color: renkler.primary.withValues(alpha: .08),
                                ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(simgeler[yer.tur] ?? Icons.place,
                            size: 16, color: renkler.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            yer.ad,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ceviri('duraktan')} ${_mesafe(kayit.mesafeM)}',
                      style: tema.textTheme.labelSmall?.copyWith(
                        color: renkler.onSurface.withValues(alpha: .6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        _ozet(ceviri),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _GeziDugmesi(
                          simge: Icons.directions_walk,
                          etiket: ceviri('yuru'),
                          basildi: () => yolTarifi(yer, RotaKipi.yuruyus),
                        ),
                        _GeziDugmesi(
                          simge: Icons.directions_car,
                          etiket: ceviri('araba'),
                          basildi: () => yolTarifi(yer, RotaKipi.araba),
                        ),
                        _GeziDugmesi(
                          simge: Icons.directions_transit,
                          etiket: ceviri('toplu'),
                          basildi: () => topluTasima(yer),
                        ),
                      ],
                    ),
                    if (yer.gorsel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${ceviri.kod == 'en' ? 'Photo' : 'Foto'}: '
                        '${yer.gorsel!.yazar} (${yer.gorsel!.lisans})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: renkler.onSurface.withValues(alpha: .5),
                        ),
                      ),
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

/// Fotoğrafsız (ya da yüklenemeyen) kartın görsel alanı.
Widget _gorselYedegi(ColorScheme renkler, String tur) => Container(
      width: double.infinity,
      height: 120,
      color: renkler.primary.withValues(alpha: .08),
      alignment: Alignment.center,
      child: Icon(
        _YerKarti.simgeler[tur] ?? Icons.place,
        size: 40,
        color: renkler.primary.withValues(alpha: .55),
      ),
    );

class _GeziDugmesi extends StatelessWidget {
  final IconData simge;
  final String etiket;
  final VoidCallback basildi;

  const _GeziDugmesi({
    required this.simge,
    required this.etiket,
    required this.basildi,
  });

  @override
  Widget build(BuildContext context) {
    final renkler = Theme.of(context).colorScheme;

    return InkWell(
      onTap: basildi,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: renkler.outlineVariant),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(simge, size: 13, color: renkler.primary),
            const SizedBox(width: 4),
            Text(
              etiket,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: renkler.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek bir aktarma türü. Noktası biliniyorsa dokunulabilir: basınca oraya
/// yürüyüş rotası çizilip canlı yönlendirme başlar.
class _AktarmaTuru extends StatelessWidget {
  static const simgeler = <String, IconData>{
    'Metro': Icons.subway,
    'Tramvay': Icons.tram,
    'Vapur': Icons.directions_boat,
    'ESHOT': Icons.directions_bus,
  };

  final String tur;
  final AktarmaNoktasi? nokta;
  final ValueChanged<AktarmaNoktasi> basildi;

  const _AktarmaTuru({
    required this.tur,
    required this.nokta,
    required this.basildi,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renkler = tema.colorScheme;
    final hedef = nokta;

    final icerik = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(simgeler[tur] ?? Icons.alt_route, size: 15, color: renkler.primary),
        const SizedBox(width: 5),
        Text(
          tur,
          style: tema.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: renkler.onSurface,
          ),
        ),
        if (hedef != null) ...[
          const SizedBox(width: 6),
          Text(
            hedef.mesafeMetni,
            style: tema.textTheme.labelSmall?.copyWith(
              color: renkler.onSurface.withValues(alpha: .6),
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right, size: 14,
              color: renkler.onSurface.withValues(alpha: .5)),
        ],
      ],
    );

    final kutu = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: renkler.surface,
        border: Border.all(color: renkler.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: icerik,
    );

    if (hedef == null) return kutu;

    return Semantics(
      button: true,
      label: Diller.aktif('aktarmayaTarif', {'tur': tur}),
      child: InkWell(
        onTap: () => basildi(hedef),
        borderRadius: BorderRadius.circular(999),
        child: kutu,
      ),
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
class _AktarmaKarti extends StatefulWidget {
  /// Aynı anda görünecek en fazla aktarma satırı. Uzun bir yolculukta 29
  /// aktarma oluyor ve kart sayfayı ekran boyu uzatıyordu.
  static const gorunurAktarma = 10;

  final Yolculuk yolculuk;

  /// Aktarma noktasına dokunulunca oraya yürüyüş rotası + canlı yönlendirme.
  final ValueChanged<AktarmaNoktasi> aktarmayaGit;

  const _AktarmaKarti({required this.yolculuk, required this.aktarmayaGit});

  @override
  State<_AktarmaKarti> createState() => _AktarmaKartiDurumu();
}

class _AktarmaKartiDurumu extends State<_AktarmaKarti> {
  final _kaydirma = ScrollController();

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  /// Tek bir aktarma satırı: durak adı, tür çipleri, ESHOT hat numaraları.
  Widget _satir(ThemeData tema, Durak durak) {
    return KabarikKutu(
      dolgu: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      cocuk: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            durak.ad,
            style:
                tema.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          // Türler alt alta sıkışan bir metin yerine hizalı çipler:
          // "ESHOT · Metro · Tramvay" tek satıra sığmadığında ortadan
          // kırpılıyordu. Noktası bilinen tür tıklanabilir.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tur in durak.aktarma)
                _AktarmaTuru(
                  tur: tur,
                  nokta: durak.aktarmaNoktalari
                      .where((n) => n.tur == tur)
                      .firstOrNull,
                  basildi: widget.aktarmayaGit,
                ),
            ],
          ),
          // ESHOT aktarması varsa hangi hatlar olduğu yazılır; "ESHOT" tek
          // başına hangi otobüse binileceğini söylemiyor.
          if (durak.otobusHatlari.isNotEmpty) ...[
            const SizedBox(height: 8),
            _OtobusHatlari(hatlar: durak.otobusHatlari),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ceviri = Diller.of(context);
    final tema = Theme.of(context);
    final duraklar = widget.yolculuk.aktarmaliDuraklar;
    if (duraklar.isEmpty) return const SizedBox.shrink();

    // Satır yükseklikleri değişken (hat numaraları sarabiliyor), o yüzden
    // pencere ekranın yarısıyla sınırlanıyor: kart hiçbir durumda sayfayı
    // ekran boyu uzatmasın.
    final kaydirmali = duraklar.length > _AktarmaKarti.gorunurAktarma;
    final pencere = MediaQuery.sizeOf(context).height * .5;
    final soluk = tema.textTheme.bodySmall?.copyWith(
      color: tema.textTheme.bodySmall?.color?.withValues(alpha: .6),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(ceviri('aktarmalar'), style: tema.textTheme.labelMedium),
            if (kaydirmali)
              SizedBox(
                height: pencere,
                child: Scrollbar(
                  controller: _kaydirma,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _kaydirma,
                    padding: const EdgeInsets.only(right: 10),
                    itemCount: duraklar.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, sira) => _satir(tema, duraklar[sira]),
                  ),
                ),
              )
            else
              ...duraklar.map((durak) => _satir(tema, durak)),
            Text(
              '${duraklar.length} ${ceviri('aktarmaNoktasi')}'
              '${kaydirmali ? ' · ${ceviri('kaydirarakGor')}' : ''}',
              style: soluk,
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
    final ceviri = Diller.of(context);
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ceviri('konumBaslik'), style: tema.textTheme.labelMedium),
            const SizedBox(height: 8),
            if (araniyor)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(ceviri('konumAraniyor')),
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
    final ceviri = Diller.of(context);
    return [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(ceviri('enYakinDurak')),
          Text(
            yakin.durak.ad,
            style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Chip(
            label: Text(
              yakin.mesafeKipMetni,
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
            child: Text(ceviri('binisDuragiYap')),
          ),
          OutlinedButton.icon(
            onPressed: () => yolTarifiAc(yakin, RotaKipi.yuruyus),
            icon: const Icon(Icons.directions_walk, size: 18),
            label: Text(ceviri('yuruyerek')),
          ),
          OutlinedButton.icon(
            onPressed: () => yolTarifiAc(yakin, RotaKipi.araba),
            icon: const Icon(Icons.directions_car, size: 18),
            label: Text(ceviri('arabayla')),
          ),
        ],
      ),
      ..._alternatifler(tema, yakin),
    ];
  }

  String _dogrulukMetni(double dogruluk) => Diller.aktif(
        dogruluk > kabaKonumEsigiM ? 'dogrulukKaba' : 'dogruluk',
        {'m': dogruluk.round()},
      );

  /// GPS şaşarsa kullanıcı doğru durağı kendisi seçebilsin.
  List<Widget> _alternatifler(ThemeData tema, YakinDurak secili) {
    final digerleri =
        adaylar.where((a) => a.durak.kod != secili.durak.kod).toList();
    if (digerleri.isEmpty) return const [];

    return [
      const SizedBox(height: 12),
      const Divider(height: 1),
      const SizedBox(height: 12),
      Text(Diller.aktif('digerDuraklar'), style: tema.textTheme.bodySmall),
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
        hata ?? Diller.of(context).call('konumYok'),
        style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: tekrarDene,
            child: Text(Diller.of(context).call('konumumuBul')),
          ),
          if (ayarlarGerekli)
            TextButton(
              onPressed: ayarlariAc,
              child: Text(Diller.of(context).call('ayarlariAc')),
            ),
        ],
      ),
    ];
  }
}

/// Hesaplanan yürüyüş rotasını adım adım gösterir.
class _RotaKarti extends StatelessWidget {
  final Rota? rota;
  final RotaHedefi? hedef;
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
    final ceviri = Diller.of(context);
    final tema = Theme.of(context);

    if (araniyor) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('${kip.etiket} ${Diller.of(context).call('rotaHesaplaniyor')}'),
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
                    '${hedef?.ad ?? ''} '
                    '${ceviri(yol.kip == RotaKipi.araba ? 'arabaIle' : 'yuruyus')}',
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
                  child: Text(ceviri(yonlendirmede ? 'bitir' : 'basla')),
                ),
                IconButton(
                  onPressed: temizle,
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: ceviri('yolTarifiniKaldir'),
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
                  segments: [
                    ButtonSegment(
                      value: RotaKipi.yuruyus,
                      icon: const Icon(Icons.directions_walk, size: 18),
                      tooltip: ceviri('yuruyerek'),
                    ),
                    ButtonSegment(
                      value: RotaKipi.araba,
                      icon: const Icon(Icons.directions_car, size: 18),
                      tooltip: ceviri('arabayla'),
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

  static String _mesafe(double metre) => Diller.aktif.mesafe(metre);

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
      text: TextSpan(
        text: Diller.of(context).call('ornek'),
        style: tema.textTheme.bodySmall,
      ),
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
          '${widget.adimlar.length} ${Diller.of(context).call('adim')}'
          ' · ${Diller.of(context).call('kaydirarakGor')}',
          style: soluk,
        ),
      ],
    );
  }
}

/// Yönlendirme sırasında sıradaki manevrayı ve kalan mesafeyi gösterir.
class _YonlendirmePaneli extends StatelessWidget {
  final Rota? rota;
  final RotaHedefi? hedef;
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

  static String _mesafe(double metre) => Diller.aktif.mesafe(metre);

  /// Kalan süreyi rotanın kendi temposundan hesaplar.
  ///
  /// Sabit bir yürüyüş hızı varsaymak yerine, servis o rota için ne kadar süre
  /// öngördüyse (yokuş, yaya geçidi, kavşak dahil) aynı tempo kalan mesafeye
  /// uygulanıyor.
  static String? _kalanSure(Rota? rota, double kalanM) {
    if (rota == null || rota.mesafeM <= 0) return null;

    final saniye = rota.sureSn * (kalanM / rota.mesafeM);
    return Diller.aktif.sure((saniye / 60).round().clamp(1, 1 << 31));
  }

  /// Anlık hız; hareket algılanmıyorsa null.
  ///
  /// Kamera kullanıcıyı ortada tuttuğu için ok sabit duruyormuş gibi görünüyor;
  /// hız, konumun gerçekten güncellendiğinin doğrudan göstergesi.
  static String? _hizMetni(double hizMs) {
    if (hizMs < 0.3) return null;
    final ceviri = Diller.aktif;
    var deger = (hizMs * 3.6).toStringAsFixed(1);
    if (ceviri.kod != 'en') deger = deger.replaceAll('.', ',');
    return '$deger ${ceviri('birimHiz')}';
  }

  String _kalanMetni(double kalanM) {
    final kalan = Diller.aktif('kalan', {'mesafe': _mesafe(kalanM)});
    final sure = _kalanSure(rota, kalanM);
    return sure == null ? kalan : '$kalan · $sure';
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
                        ? Diller.of(context).call('vardin')
                        : _kalanMetni(durum?.ilerleme.kalanM ?? 0),
                    style: tema.textTheme.bodySmall
                        ?.copyWith(color: renkler.onPrimary.withValues(alpha: .9)),
                  ),
                ),
                // Sesli yönlendirme anahtarı: talimatlar yürürken okunur.
                IconButton(
                  onPressed: () => sesDegisti(!sesliMi),
                  visualDensity: VisualDensity.compact,
                  tooltip: Diller.of(context).call(sesliMi ? 'sesiKapat' : 'sesiAc'),
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
                      _hizMetni(durum?.hizMs ?? 0) ??
                          Diller.of(context).call(rota?.kip == RotaKipi.araba
                              ? 'toplamSurus'
                              : 'toplamYuruyus'),
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
