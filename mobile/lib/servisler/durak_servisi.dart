import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../modeller/durak.dart';

/// Durak verisini uygulama paketindeki JSON dosyasından okur.
///
/// Firestore'a geçilecekse yalnızca [duraklariGetir] gövdesi değiştirilir;
/// arayüz tarafında hiçbir şey değişmez.
class DurakServisi {
  /// Normal kullanım: veri assets/duraklar.json dosyasından okunur.
  DurakServisi()
      : _onbellek = null,
        _surum = '—';

  /// Testler ve önizlemeler için: veri hazır verilir, dosya okunmaz.
  factory DurakServisi.hazir(List<Durak> duraklar, {String surum = 'test'}) {
    final servis = DurakServisi();
    servis._onbellek = duraklar;
    servis._surum = surum;
    return servis;
  }

  static const _varlikYolu = 'assets/duraklar.json';

  List<Durak>? _onbellek;
  String _surum;

  String get surum => _surum;

  Future<List<Durak>> duraklariGetir() async {
    final onbellek = _onbellek;
    if (onbellek != null) return onbellek;

    final ham = await rootBundle.loadString(_varlikYolu);
    final json = jsonDecode(ham) as Map<String, dynamic>;

    _surum = json['surum'] as String? ?? '—';
    final duraklar = (json['duraklar'] as List<dynamic>)
        .map((e) => Durak.jsondan(e as Map<String, dynamic>))
        .toList();

    _onbellek = duraklar;
    return duraklar;
  }
}
