import 'dart:math' as matematik;

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

  const Durak({
    required this.kod,
    required this.ad,
    required this.ilce,
    required this.dakika,
    required this.konum,
    this.mesafeKm = 0,
    this.aktarma = const [],
    this.otobusHatlari = const [],
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
