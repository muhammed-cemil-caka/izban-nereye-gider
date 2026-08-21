import 'dart:math' as matematik;

/// Aktarma yapılabilecek gerçek bir nokta (metro girişi, tramvay durağı...).
///
/// Aktarma bilgisi önce yalnızca etiketti ("Metro"); kullanıcı "metroya nasıl
/// giderim" diye sorduğunda gidilecek bir nokta yoktu. Artık koordinat da
/// saklanıyor, uygulama oraya yürüyüş rotası çizebiliyor.
class AktarmaNoktasi {
  final String tur; // Metro · Tramvay · Vapur · ESHOT
  final String ad;
  final Konum konum;
  final double mesafeM;

  const AktarmaNoktasi({
    required this.tur,
    required this.ad,
    required this.konum,
    required this.mesafeM,
  });

  factory AktarmaNoktasi.jsondan(Map<String, dynamic> json) {
    return AktarmaNoktasi(
      tur: json['tur'] as String? ?? '',
      ad: json['ad'] as String? ?? '',
      konum: Konum.jsondan(json['konum'] as Map<String, dynamic>?),
      mesafeM: (json['mesafeM'] as num?)?.toDouble() ?? 0,
    );
  }

  String get mesafeMetni => mesafeM < 1000
      ? '${mesafeM.round()} m'
      : '${(mesafeM / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Rota hedefi — bir İZBAN durağı ya da bir aktarma noktası olabilir.
class RotaHedefi {
  final String ad;
  final Konum konum;

  const RotaHedefi(this.ad, this.konum);

  factory RotaHedefi.durak(Durak durak) => RotaHedefi(durak.ad, durak.konum);

  factory RotaHedefi.aktarma(AktarmaNoktasi nokta) =>
      RotaHedefi('${nokta.ad} ${nokta.tur.toLowerCase()}', nokta.konum);
}

/// Hat üzerindeki tek bir durak.
class Durak {
  final String kod;
  final String ad;
  final String ilce;
  final int dakika; // Kuzey uçtan (Aliağa) itibaren kümülatif dakika
  final double mesafeKm; // Kuzey uçtan itibaren kümülatif mesafe
  final Konum konum;
  final List<String> aktarma;

  /// Durağa yakın ESHOT otobüs hatlarının numaraları ("53", "912"...).
  /// Kaynak: OpenStreetMap — bkz. araclar/eshot-hatlarini-ekle.js
  final List<String> otobusHatlari;

  /// Aktarma türlerinin gerçek noktaları (yürüyüş rotası için).
  final List<AktarmaNoktasi> aktarmaNoktalari;

  const Durak({
    required this.kod,
    required this.ad,
    required this.ilce,
    required this.dakika,
    required this.konum,
    this.mesafeKm = 0,
    this.aktarma = const [],
    this.otobusHatlari = const [],
    this.aktarmaNoktalari = const [],
  });

  factory Durak.jsondan(Map<String, dynamic> json) {
    return Durak(
      kod: json['kod'] as String,
      ad: json['ad'] as String,
      ilce: json['ilce'] as String,
      dakika: (json['dakika'] as num).toInt(),
      mesafeKm: (json['mesafeKm'] as num?)?.toDouble() ?? 0,
      konum: Konum.jsondan(json['konum'] as Map<String, dynamic>?),
      aktarma: List<String>.from(json['aktarma'] as List<dynamic>? ?? const []),
      otobusHatlari:
          List<String>.from(json['otobusHatlari'] as List<dynamic>? ?? const []),
      aktarmaNoktalari: ((json['aktarmaNoktalari'] as List<dynamic>?) ?? const [])
          .map((n) => AktarmaNoktasi.jsondan(n as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get aktarmaVar => aktarma.isNotEmpty;
}

/// Coğrafi konum (WGS84).
class Konum {
  final double enlem;
  final double boylam;

  const Konum({required this.enlem, required this.boylam});

  factory Konum.jsondan(Map<String, dynamic>? json) {
    if (json == null) return const Konum(enlem: 0, boylam: 0);
    return Konum(
      enlem: (json['enlem'] as num).toDouble(),
      boylam: (json['boylam'] as num).toDouble(),
    );
  }

  bool get gecerli => enlem != 0 || boylam != 0;

  /// İki nokta arası kuş uçuşu mesafe (metre) — haversine.
  double metreUzaklik(Konum digeri) {
    const yaricapM = 6371000.0;
    final dereceRadyan = matematik.pi / 180;

    final dEnlem = (digeri.enlem - enlem) * dereceRadyan;
    final dBoylam = (digeri.boylam - boylam) * dereceRadyan;

    final sinEnlem = matematik.sin(dEnlem / 2);
    final sinBoylam = matematik.sin(dBoylam / 2);

    final h = sinEnlem * sinEnlem +
        matematik.cos(enlem * dereceRadyan) *
            matematik.cos(digeri.enlem * dereceRadyan) *
            sinBoylam * sinBoylam;

    return 2 * yaricapM * matematik.asin(matematik.sqrt(h));
  }
}
