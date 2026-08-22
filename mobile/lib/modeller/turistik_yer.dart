import 'durak.dart';

/// Turistik yerin fotoğrafı ve lisans bilgisi.
///
/// Görseller Wikimedia Commons'tan; her dosyanın kendi lisansı var ve yazar
/// gösterimi zorunlu. Bu yüzden yazar/lisans alanları taşınıyor.
class TuristikGorsel {
  final String adres;
  final String kucukAdres;
  final String yazar;
  final String lisans;
  final String kaynakSayfa;

  const TuristikGorsel({
    required this.adres,
    required this.kucukAdres,
    required this.yazar,
    required this.lisans,
    required this.kaynakSayfa,
  });

  factory TuristikGorsel.jsondan(Map<String, dynamic> json) => TuristikGorsel(
        adres: json['adres'] as String? ?? '',
        kucukAdres: json['kucukAdres'] as String? ?? json['adres'] as String? ?? '',
        yazar: json['yazar'] as String? ?? 'bilinmiyor',
        lisans: json['lisans'] as String? ?? 'bilinmiyor',
        kaynakSayfa: json['kaynakSayfa'] as String? ?? '',
      );
}

/// Bir turistik yerin hangi durağa ne kadar uzak olduğu.
class YerDurakBagi {
  final String kod;
  final double kusUcusuM;

  const YerDurakBagi(this.kod, this.kusUcusuM);
}

/// Yere bir kipte en yakın durak — önceden hesaplanmış.
///
/// Durak da yer de kıpırdamıyor, bu ölçüler sabit; veriye gömülüyorlar
/// (bkz. araclar/turistik-mesafeleri-uret.js). Eskiden her dokunuşta canlı
/// mesafe matrisi çekiliyor ve rota isteğiyle birlikte ARDIŞIK iki çağrı
/// oluyordu — gecikme toplanıyor, ikisinden biri düşünce "rota alınamadı"
/// çıkıyordu.
class EnYakinDurakOlcusu {
  final String kod;
  final double mesafeM;
  final double sureSn;

  const EnYakinDurakOlcusu({
    required this.kod,
    required this.mesafeM,
    required this.sureSn,
  });

  static EnYakinDurakOlcusu? jsondan(Map<String, dynamic>? json) {
    if (json == null || json['kod'] is! String) return null;
    return EnYakinDurakOlcusu(
      kod: json['kod'] as String,
      mesafeM: ((json['mesafeM'] as num?) ?? 0).toDouble(),
      sureSn: ((json['sureSn'] as num?) ?? 0).toDouble(),
    );
  }
}

/// Tarihi/turistik yer. Kaynak: Wikidata + Wikipedia + Commons.
class TuristikYer {
  final String kod;
  final String ad;
  final String tur;
  final Konum konum;
  final String ozet;
  final String ozetEn;
  final TuristikGorsel? gorsel;
  final String? wikipedia;
  final String? wikipediaEn;
  final List<YerDurakBagi> duraklar;

  /// Kip adı ("yuruyus" / "araba") → en yakın durak ölçüsü.
  final Map<String, EnYakinDurakOlcusu> enYakin;

  const TuristikYer({
    required this.kod,
    required this.ad,
    required this.tur,
    required this.konum,
    required this.ozet,
    required this.ozetEn,
    required this.gorsel,
    required this.wikipedia,
    required this.wikipediaEn,
    required this.duraklar,
    this.enYakin = const {},
  });

  factory TuristikYer.jsondan(Map<String, dynamic> json) {
    final kaynaklar = json['kaynaklar'] as Map<String, dynamic>? ?? const {};
    final gorselJson = json['gorsel'] as Map<String, dynamic>?;

    return TuristikYer(
      kod: json['kod'] as String? ?? '',
      ad: json['ad'] as String? ?? '',
      tur: json['tur'] as String? ?? 'gezi-noktasi',
      konum: Konum.jsondan(json['konum'] as Map<String, dynamic>?),
      ozet: json['ozet'] as String? ?? '',
      ozetEn: json['ozetEn'] as String? ?? '',
      gorsel: gorselJson == null ? null : TuristikGorsel.jsondan(gorselJson),
      wikipedia: kaynaklar['wikipedia'] as String?,
      wikipediaEn: kaynaklar['wikipediaEn'] as String?,
      duraklar: ((json['duraklar'] as List<dynamic>?) ?? const [])
          .map((d) => YerDurakBagi(
                (d as Map<String, dynamic>)['kod'] as String? ?? '',
                ((d)['kusUcusuM'] as num?)?.toDouble() ?? 0,
              ))
          .toList(),
      enYakin: {
        for (final giris in ((json['enYakin'] as Map<String, dynamic>?) ?? const {}).entries)
          giris.key: ?EnYakinDurakOlcusu.jsondan(giris.value as Map<String, dynamic>?),
      },
    );
  }

  /// Verilen durağa kuş uçuşu uzaklık (metre); bağ yoksa null.
  double? durakUzakligi(String durakKodu) {
    for (final bag in duraklar) {
      if (bag.kod == durakKodu) return bag.kusUcusuM;
    }
    return null;
  }
}
