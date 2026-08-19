import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../modeller/durak.dart';
import '../modeller/yakin_durak.dart';
import '../modeller/yolculuk.dart';
import '../servisler/durak_servisi.dart';
import '../servisler/konum_servisi.dart';

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
  late final Future<List<Durak>> _duraklarGelecegi;

  String? _binisKod;
  String? _inisKod;

  KonumServisi get _konumServisi => widget.konumServisi ?? const KonumServisi();
  YakinDurak? _yakinDurak;
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
      case KonumBulundu(:final konum):
        final duraklar = await _duraklarGelecegi;
        if (!mounted) return;
        setState(() {
          _yakinDurak = YakinDurak.bul(duraklar, konum);
          _konumHatasi = _yakinDurak == null ? 'Duraklarda koordinat bilgisi yok.' : null;
          _konumAraniyor = false;
        });

      case KonumHatasi(:final mesaj, :final ayarlarGerekli):
        setState(() {
          _yakinDurak = null;
          _konumHatasi = mesaj;
          _konumAyarlariGerekli = ayarlarGerekli;
          _konumAraniyor = false;
        });
    }
  }

  Future<void> _yolTarifiAc(YakinDurak yakin) async {
    final acildi = await launchUrl(
      yakin.yolTarifiAdresi,
      mode: LaunchMode.externalApplication,
    );
    if (!acildi && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita uygulaması açılamadı.')),
      );
    }
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
            padding: const EdgeInsets.all(16),
            children: [
              _KonumKarti(
                yakinDurak: _yakinDurak,
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
                yolTarifiAc: _yolTarifiAc,
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
  final YakinDurak? yakinDurak;
  final String? hata;
  final bool araniyor;
  final bool ayarlarGerekli;
  final VoidCallback tekrarDene;
  final VoidCallback ayarlariAc;
  final ValueChanged<Durak> binisYap;
  final ValueChanged<YakinDurak> yolTarifiAc;

  const _KonumKarti({
    required this.yakinDurak,
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
