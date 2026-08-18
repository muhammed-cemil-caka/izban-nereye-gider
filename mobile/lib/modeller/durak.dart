/// Hat üzerindeki tek bir durak.
class Durak {
  final String kod;
  final String ad;
  final String ilce;
  final int dakika; // Kuzey uçtan (Aliağa) itibaren kümülatif dakika
  final List<String> aktarma;

  const Durak({
    required this.kod,
    required this.ad,
    required this.ilce,
    required this.dakika,
    required this.aktarma,
  });

  factory Durak.jsondan(Map<String, dynamic> json) {
    return Durak(
      kod: json['kod'] as String,
      ad: json['ad'] as String,
      ilce: json['ilce'] as String,
      dakika: json['dakika'] as int,
      aktarma: List<String>.from(json['aktarma'] as List<dynamic>? ?? const []),
    );
  }

  bool get aktarmaVar => aktarma.isNotEmpty;
}
