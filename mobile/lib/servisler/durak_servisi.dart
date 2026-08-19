import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import '../modeller/durak.dart';
import 'firestore_veri.dart';

/// İki x.y.z sürümünü karşılaştırır: a>b ise 1, a<b ise -1, eşitse 0.
int surumKarsilastir(String a, String b) {
  final pa = a.split('.');
  final pb = b.split('.');
  for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
    final x = i < pa.length ? (int.tryParse(pa[i]) ?? 0) : 0;
    final y = i < pb.length ? (int.tryParse(pb[i]) ?? 0) : 0;
    if (x != y) return x > y ? 1 : -1;
  }
  return 0;
}

/// Durak verisinin kaynağı.
enum VeriKaynagi {
  /// Uygulamayla gelen kopya kullanıldı, sürümü Firebase doğruladı.
  firebaseDogrulandi,

  /// Veri Firestore'dan indirildi (yerel kopya eskiydi).
  firebase,

  /// Firebase'e ulaşılamadı, uygulamayla gelen kopya kullanıldı.
  yerel,
}

/// Durak verisini en az Firestore okumasıyla getirir.
///
/// Firestore her BELGE için ayrı okuma sayar; 28 duraklık listeyi her açılışta
/// çekmek açılış başına 28 okuma demek. Durak verisi neredeyse hiç değişmediği
/// için akış şöyle:
///
///   1. `hat/bilgi` okunur (tek belge, tek okuma) ve sürüm karşılaştırılır.
///   2. Sürüm uygulamadakiyle aynıysa yerel kopya kullanılır — ek okuma yok.
///   3. Yalnızca sürüm değiştiyse 28 belgelik liste indirilir.
///
/// Firebase'e hiç ulaşılamazsa yerel kopyayla devam edilir; uygulama her
/// durumda açılır.
class DurakServisi {
  /// [firestoreKullan] false verilirse yalnızca yerel dosya okunur (testler için).
  DurakServisi({this.firestoreKullan = true})
      : _onbellek = null,
        _surum = '—',
        _kaynak = VeriKaynagi.yerel;

  /// Testler ve önizlemeler için: veri hazır verilir, hiçbir okuma yapılmaz.
  factory DurakServisi.hazir(List<Durak> duraklar, {String surum = 'test'}) {
    final servis = DurakServisi(firestoreKullan: false);
    servis._onbellek = duraklar;
    servis._surum = surum;
    return servis;
  }

  static const _varlikYolu = 'assets/duraklar.json';

  final bool firestoreKullan;
  final _firestore = const FirestoreVeri();

  List<Durak>? _onbellek;
  String _surum;
  VeriKaynagi _kaynak;

  String get surum => _surum;
  VeriKaynagi get kaynak => _kaynak;

  String get kaynakEtiketi => switch (_kaynak) {
        VeriKaynagi.firebase => 'Firebase',
        VeriKaynagi.firebaseDogrulandi => 'Firebase (doğrulandı)',
        VeriKaynagi.yerel => 'yerel kopya',
      };

  Future<List<Durak>> duraklariGetir() async {
    final onbellek = _onbellek;
    if (onbellek != null) return onbellek;

    final yerel = await _varlikVerisiOku();

    if (firestoreKullan) {
      try {
        final hat = await _firestore.hatBilgisiGetir();
        final uzakSurum = hat['surum'] as String?;

        // Uzaktaki veri yeni DEĞİLSE (aynı ya da daha eski) yerel kopya kullanılır.
        // Yalnızca eşitliğe bakmak, veritabanı henüz güncellenmemişken uygulamanın
        // kendi yeni verisini eski veriyle ezmesine yol açardı.
        if (uzakSurum == null || surumKarsilastir(uzakSurum, yerel.surum) <= 0) {
          return _yerlestir(yerel.duraklar, yerel.surum,
              VeriKaynagi.firebaseDogrulandi);
        }

        final duraklar = await _firestore.duraklariGetir();
        return _yerlestir(duraklar, uzakSurum, VeriKaynagi.firebase);
      } catch (sorun) {
        debugPrint('Firestore okunamadı, yerel kopya kullanılıyor: $sorun');
      }
    }

    return _yerlestir(yerel.duraklar, yerel.surum, VeriKaynagi.yerel);
  }

  List<Durak> _yerlestir(List<Durak> duraklar, String surum, VeriKaynagi kaynak) {
    _onbellek = duraklar;
    _surum = surum;
    _kaynak = kaynak;
    return duraklar;
  }

  /// Uygulamayla gelen JSON'u okur; servis durumunu değiştirmez.
  Future<({String surum, List<Durak> duraklar})> _varlikVerisiOku() async {
    final ham = await rootBundle.loadString(_varlikYolu);
    final json = jsonDecode(ham) as Map<String, dynamic>;

    return (
      surum: json['surum'] as String? ?? '—',
      duraklar: (json['duraklar'] as List<dynamic>)
          .map((e) => Durak.jsondan(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
