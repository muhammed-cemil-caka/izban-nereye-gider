import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import '../modeller/durak.dart';
import 'firestore_veri.dart';

/// Durak verisinin kaynağı.
enum VeriKaynagi { firebase, yerel }

/// Durak verisini önce Firestore'dan, olmazsa uygulama içindeki JSON'dan okur.
///
/// Böylece uygulama ağ yokken de açılır; veri güncellendiğinde ise yeni sürüm
/// mağaza güncellemesi beklemeden gelir.
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

  Future<List<Durak>> duraklariGetir() async {
    final onbellek = _onbellek;
    if (onbellek != null) return onbellek;

    if (firestoreKullan) {
      try {
        final duraklar = await _firestore.duraklariGetir();
        _onbellek = duraklar;
        _kaynak = VeriKaynagi.firebase;
        _surum = 'Firebase';
        return duraklar;
      } catch (sorun) {
        // Ağ yok, koleksiyon boş veya yetki reddi: yerel kopyaya düşülür.
        debugPrint('Firestore okunamadı, yerel kopya kullanılıyor: $sorun');
      }
    }

    return _varliktanGetir();
  }

  Future<List<Durak>> _varliktanGetir() async {
    final ham = await rootBundle.loadString(_varlikYolu);
    final json = jsonDecode(ham) as Map<String, dynamic>;

    _surum = json['surum'] as String? ?? '—';
    _kaynak = VeriKaynagi.yerel;

    final duraklar = (json['duraklar'] as List<dynamic>)
        .map((e) => Durak.jsondan(e as Map<String, dynamic>))
        .toList();

    _onbellek = duraklar;
    return duraklar;
  }
}
