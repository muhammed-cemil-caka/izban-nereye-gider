import 'dart:convert';
import 'package:http/http.dart' as http;
import '../modeller/durak.dart';
import 'servis_adresi.dart';

/// Tek bir aktarmasız sefer — servisin döndürdüğü ham kayıt.
class Sefer {
  final String kalkis; // "07:35"
  final String varis;  // "08:05"
  final int kalkisDk;  // gün içi dakika — sıralama ve "kaç dk sonra" için

  const Sefer({required this.kalkis, required this.varis, required this.kalkisDk});
}

/// Aktarmalı yolculukta bir tren değişimi.
class SeferAktarmasi {
  final String durak;
  final String inis;   // aktarma durağına varış saati
  final String binis;  // aktarma durağından kalkış saati
  final int beklemeDk;

  const SeferAktarmasi({
    required this.durak,
    required this.inis,
    required this.binis,
    required this.beklemeDk,
  });
}

/// Biniş durağından iniş durağına tam bir yolculuk; gerekiyorsa aktarmalı.
class SeferYolculugu {
  final String kalkis;
  final String varis;
  final int kalkisDk;
  final int varisDk;   // gün başından itibaren; gece yarısını aşabilir
  final List<SeferAktarmasi> aktarmalar;

  const SeferYolculugu({
    required this.kalkis,
    required this.varis,
    required this.kalkisDk,
    required this.varisDk,
    this.aktarmalar = const [],
  });
}

/// Sıradaki yolculuk: kalkışa kalan süreyle birlikte.
class SiradakiSefer {
  final SeferYolculugu sefer;
  final bool ertesiGun;
  final int? kalanDk;

  const SiradakiSefer(this.sefer, {required this.ertesiGun, this.kalanDk});
}

/// İZBAN sefer saatleri — İzmir Büyükşehir Belediyesi açık veri servisi.
///
/// https://openapi.izmir.bel.tr/api/izban/sefersaatleri/{kalkis}/{varis}
/// Anahtar istemiyor.
///
/// Servis YALNIZCA aktarmasız seferleri veriyor. Hat tek parça görünse de
/// işletme üç dilime ayrılmış ve dilimi aşan çiftler boş dönüyor:
///
///   Aliağa → Cumaovası   43 sefer      Aliağa → Torbalı    4 sefer
///   Aliağa → Tepeköy      4 sefer      Aliağa → Selçuk     0 sefer
///   Tepeköy → Selçuk     14 sefer      Halkapınar → Selçuk 0 sefer
///
/// Kırılma noktaları ölçüldü: CUMAOVASI ve TEPEKÖY. 41 durağın tamamı bu
/// ikisine bağlı, dolayısıyla bu iki aktarmayla bütün durak çiftleri
/// kapsanıyor. Web tarafındaki frontend/js/sefer.js ile aynı mantık.
class SeferServisi {
  const SeferServisi();

  static const _taban = 'https://openapi.izmir.bel.tr/api/izban/sefersaatleri';
  static const _zamanAsimi = Duration(seconds: 15);

  /// Servis dilimlerinin birleştiği duraklar — aktarma buralarda yapılır.
  static const aktarmaDuraklari = <String>['cumaovasi', 'tepekoy'];

  /// Aktarma için gereken en az süre; aynı istasyonda peron değiştirmek yeter.
  static const enAzAktarmaDk = 3;

  /// Bundan uzun bekleten bağlantı yolculuk sayılmaz: gece son trenle gelip
  /// sabahki ilk trene binmek "sıradaki tren" değildir.
  static const enCokBeklemeDk = 180;

  static const _gunDk = 24 * 60;

  /// "07:35:00" → 455 (dakika). Bozuk değerde null.
  static int? dakikayaCevir(String? metin) {
    final parca = (metin ?? '').split(':');
    if (parca.length < 2) return null;
    final saat = int.tryParse(parca[0]);
    final dakika = int.tryParse(parca[1]);
    if (saat == null || dakika == null) return null;
    return saat * 60 + dakika;
  }

  static String kisalt(String? metin) =>
      (metin ?? '').length >= 5 ? metin!.substring(0, 5) : (metin ?? '');

  /// Bir seferin yolda geçirdiği süre; gece yarısını aşanlarda da doğru.
  static int seferSuresi(Sefer sefer) {
    final varisDk = dakikayaCevir(sefer.varis);
    if (varisDk == null) return 0;
    return (varisDk - sefer.kalkisDk) % _gunDk;
  }

  /// İki durak arasındaki AKTARMASIZ seferler.
  Future<List<Sefer>> seferleriAl(int kalkisId, int varisId) async {
    // Vekil varsa oradan: tarife CDN'de 6 saat duruyor, yüzlerce kullanıcı
    // tek dış isteğe iniyor.
    final adres = await ServisAdresi.coz(
      () => Uri.parse('${ServisAdresi.taban}/api/sefer/$kalkisId/$varisId'),
      () => Uri.parse('$_taban/$kalkisId/$varisId'),
    );
    final yanit = await http.get(adres).timeout(_zamanAsimi);
    if (yanit.statusCode != 200) {
      throw Exception('Sefer servisi yanıtı: ${yanit.statusCode}');
    }

    final govde = jsonDecode(utf8.decode(yanit.bodyBytes));
    if (govde is! List) return const [];

    final seferler = <Sefer>[];
    for (final ham in govde) {
      final harita = ham as Map<String, dynamic>;
      final dk = dakikayaCevir(harita['HareketSaati'] as String?);
      if (dk == null) continue;
      seferler.add(Sefer(
        kalkis: kisalt(harita['HareketSaati'] as String?),
        varis: kisalt(harita['VarisSaati'] as String?),
        kalkisDk: dk,
      ));
    }

    seferler.sort((a, b) => a.kalkisDk.compareTo(b.kalkisDk));
    return seferler;
  }

  /// Yolculuğun geçtiği durak zinciri: biniş, aradaki aktarma durakları, iniş.
  ///
  /// Aktarma durağı yolculuğun İÇİNDE değilse zincire girmez — Halkapınar'dan
  /// Konak'a giderken Tepeköy'e uğramak anlamsız.
  static List<Durak>? zincirKur(List<Durak> duraklar, String binisKod, String inisKod) {
    final binisSira = duraklar.indexWhere((d) => d.kod == binisKod);
    final inisSira = duraklar.indexWhere((d) => d.kod == inisKod);
    if (binisSira < 0 || inisSira < 0 || binisSira == inisSira) return null;

    final yon = inisSira > binisSira ? 1 : -1;
    final zincir = <Durak>[duraklar[binisSira]];

    for (var sira = binisSira + yon; sira != inisSira; sira += yon) {
      final durak = duraklar[sira];
      if (aktarmaDuraklari.contains(durak.kod) && durak.izbanId != null) {
        zincir.add(durak);
      }
    }

    zincir.add(duraklar[inisSira]);
    return zincir.every((d) => d.izbanId != null) ? zincir : null;
  }

  /// Zincirdeki 0 → son arası artan tüm düğüm dizilişleri.
  ///
  /// İki aktarma durağı varsa dört yol çıkar: doğrudan, yalnızca birincisinden,
  /// yalnızca ikincisinden ve ikisinden de. Hepsi denenip en iyisi seçilir —
  /// hangisinin daha erken vardıracağı saate göre değişiyor.
  static List<List<int>> zincirYollari(int uzunluk) {
    final son = uzunluk - 1;
    final yollar = <List<int>>[];

    void ilerle(List<int> yol) {
      final suanki = yol.last;
      if (suanki == son) {
        yollar.add(List<int>.from(yol));
        return;
      }
      for (var sonraki = suanki + 1; sonraki <= son; sonraki++) {
        yol.add(sonraki);
        ilerle(yol);
        yol.removeLast();
      }
    }

    ilerle([0]);
    return yollar;
  }

  /// Verilen ana yetişilebilen, EN ERKEN VARDIRAN bağlantı.
  ///
  /// En az bekleyen değil en erken vardıran seçilir: iki ölçüt bu hatta aynı
  /// sonucu veriyor (hepsi her durakta duruyor) ama hızlı bir sefer eklenirse
  /// beklemeye bakan seçim yolcuyu geç vardırırdı. Gece yarısını aşan
  /// bağlantılar için bekleme bir güne sarılır.
  static ({Sefer sefer, int beklemeDk, int kalkisDk, int varisDk})? ilkBaglanti(
    List<Sefer> seferler,
    int hazirDk,
  ) {
    ({Sefer sefer, int beklemeDk, int kalkisDk, int varisDk})? enIyi;

    for (final sefer in seferler) {
      var bekleme = (sefer.kalkisDk - hazirDk) % _gunDk;
      // Yetişilemeyecek kadar yakınsa o tren bugün kaçtı, sıradakine bakılır.
      if (bekleme < enAzAktarmaDk) bekleme += _gunDk;

      final kalkisDk = hazirDk + bekleme;
      final varisDk = kalkisDk + seferSuresi(sefer);
      if (enIyi == null ||
          varisDk < enIyi.varisDk ||
          (varisDk == enIyi.varisDk && bekleme < enIyi.beklemeDk)) {
        enIyi = (
          sefer: sefer,
          beklemeDk: bekleme,
          kalkisDk: kalkisDk,
          varisDk: varisDk,
        );
      }
    }

    return enIyi;
  }

  /// Bir yolu, ilk seferi verilmiş hâlde sonuna kadar bağlar.
  static SeferYolculugu? yolculuguKur(
    List<int> yol,
    List<Durak> zincir,
    Map<String, List<Sefer>> kenarlar,
    Sefer ilkSefer,
  ) {
    var anVarisDk = ilkSefer.kalkisDk + seferSuresi(ilkSefer);
    var sonVaris = ilkSefer.varis;
    final aktarmalar = <SeferAktarmasi>[];

    for (var adim = 1; adim < yol.length - 1; adim++) {
      final liste = kenarlar['${yol[adim]}-${yol[adim + 1]}'] ?? const <Sefer>[];
      final baglanti = ilkBaglanti(liste, anVarisDk);
      if (baglanti == null || baglanti.beklemeDk > enCokBeklemeDk) return null;

      aktarmalar.add(SeferAktarmasi(
        durak: zincir[yol[adim]].ad,
        inis: sonVaris,
        binis: baglanti.sefer.kalkis,
        beklemeDk: baglanti.beklemeDk,
      ));

      anVarisDk = baglanti.varisDk;
      sonVaris = baglanti.sefer.varis;
    }

    return SeferYolculugu(
      kalkis: ilkSefer.kalkis,
      varis: sonVaris,
      kalkisDk: ilkSefer.kalkisDk,
      varisDk: anVarisDk,
      aktarmalar: aktarmalar,
    );
  }

  /// Baskın olmayanları eler.
  ///
  /// Aynı Selçuk trenine binmek için 06:05'te de 06:57'de de yola çıkılabiliyor;
  /// ikisi de 08:16'da varıyor. Erken kalkanı göstermek yolcuyu Tepeköy'de bir
  /// saat bekletir. Daha geç kalkıp daha erken (ya da aynı anda) varan bir
  /// yolculuk varsa diğeri listeden düşer.
  static List<SeferYolculugu> baskinOlanlar(List<SeferYolculugu> yolculuklar) {
    final sirali = List<SeferYolculugu>.from(yolculuklar)
      ..sort((a, b) {
        final fark = a.kalkisDk.compareTo(b.kalkisDk);
        return fark != 0 ? fark : b.varisDk.compareTo(a.varisDk);
      });

    final kalanlar = <SeferYolculugu>[];
    var enErkenVaris = 1 << 30;

    for (var i = sirali.length - 1; i >= 0; i--) {
      if (sirali[i].varisDk >= enErkenVaris) continue;
      enErkenVaris = sirali[i].varisDk;
      kalanlar.add(sirali[i]);
    }

    return kalanlar.reversed.toList();
  }

  /// Bir yolculuğun tüm seferleri — gerekiyorsa aktarmalı.
  ///
  /// Hiçbir istek geçmezse fırlatır: "sefer yok" ile "servise ulaşılamadı"
  /// arayüzde farklı yazıyor.
  Future<List<SeferYolculugu>> yolculukSeferleriAl(
    List<Durak> duraklar,
    String binisKod,
    String inisKod,
  ) async {
    final zincir = zincirKur(duraklar, binisKod, inisKod);
    if (zincir == null) return const [];

    final kenarlar = <String, List<Sefer>>{};
    final istekler = <Future<void>>[];
    var basarili = 0;

    for (var i = 0; i < zincir.length; i++) {
      for (var j = i + 1; j < zincir.length; j++) {
        final (bas, son) = (i, j);
        istekler.add(
          seferleriAl(zincir[bas].izbanId!, zincir[son].izbanId!).then((liste) {
            kenarlar['$bas-$son'] = liste;
            basarili++;
          }).catchError((_) {
            kenarlar['$bas-$son'] = const <Sefer>[];
          }),
        );
      }
    }

    await Future.wait(istekler);
    if (basarili == 0) throw Exception('Sefer servisine ulaşılamadı.');

    final yolculuklar = <SeferYolculugu>[];
    for (final yol in zincirYollari(zincir.length)) {
      for (final ilk in kenarlar['${yol[0]}-${yol[1]}'] ?? const <Sefer>[]) {
        final yolculuk = yolculuguKur(yol, zincir, kenarlar, ilk);
        if (yolculuk != null) yolculuklar.add(yolculuk);
      }
    }

    return baskinOlanlar(yolculuklar);
  }

  /// Şu andan GÜN SONUNA kadarki bütün yolculuklar.
  ///
  /// Önce yalnızca ilk dördü gösteriliyordu; "akşam kaça kadar tren var"
  /// sorusu cevapsız kalıyordu. Liste uzayabildiği için arayüz kendi içinde
  /// kaydırıyor.
  ///
  /// Bugün sefer kalmadıysa (gece yarısına yakın) ertesi günün tarifesi
  /// gösterilir; kutu boş kalmasın.
  static List<SiradakiSefer> siradakiler(
    List<SeferYolculugu> seferler, {
    int? simdiDk,
  }) {
    if (seferler.isEmpty) return const [];

    final an = simdiDk ?? (() {
      final d = DateTime.now();
      return d.hour * 60 + d.minute;
    })();

    final kalanlar = seferler.where((s) => s.kalkisDk >= an).toList();
    final ertesiGun = kalanlar.isEmpty;
    final secilen = ertesiGun ? seferler : kalanlar;

    return secilen
        .map((s) => SiradakiSefer(
              s,
              ertesiGun: ertesiGun,
              kalanDk: ertesiGun ? null : s.kalkisDk - an,
            ))
        .toList();
  }
}
