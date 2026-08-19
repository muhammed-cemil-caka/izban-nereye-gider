import 'dart:convert';
import 'package:http/http.dart' as http;
import '../firebase_ayari.dart';
import '../modeller/durak.dart';

/// Firestore REST API'sinden durak verisi okur.
///
/// Firebase SDK'sı yerine REST kullanılıyor: uygulamanın platform yapılandırması
/// (google-services.json / GoogleService-Info.plist) olmadan da çalışsın diye.
/// Okuma yetkisi firestore.rules ile herkese açık, kimlik doğrulaması gerekmiyor.
class FirestoreVeri {
  const FirestoreVeri();

  static const _zamanAsimi = Duration(seconds: 8);

  /// Firestore'un tipli değerini ({"stringValue": "x"}) düz Dart değerine çevirir.
  static dynamic _deger(Map<String, dynamic> alan) {
    if (alan.containsKey('stringValue')) return alan['stringValue'];
    if (alan.containsKey('integerValue')) {
      return int.parse(alan['integerValue'] as String);
    }
    if (alan.containsKey('doubleValue')) return alan['doubleValue'];
    if (alan.containsKey('booleanValue')) return alan['booleanValue'];
    if (alan.containsKey('nullValue')) return null;
    if (alan.containsKey('arrayValue')) {
      final degerler = (alan['arrayValue'] as Map<String, dynamic>)['values']
          as List<dynamic>?;
      return (degerler ?? const [])
          .map((e) => _deger(e as Map<String, dynamic>))
          .toList();
    }
    // konum gibi iç içe alanlar mapValue olarak gelir.
    if (alan.containsKey('mapValue')) {
      return _belge(alan['mapValue'] as Map<String, dynamic>);
    }
    return null;
  }

  /// Belgenin alanlarını düz haritaya çevirir.
  static Map<String, dynamic> _belge(Map<String, dynamic> belge) {
    final alanlar = belge['fields'] as Map<String, dynamic>? ?? const {};
    return alanlar.map(
      (ad, alan) => MapEntry(ad, _deger(alan as Map<String, dynamic>)),
    );
  }

  /// Hat özetini (sürüm, uç duraklar) getirir — tek belge, tek okuma.
  ///
  /// Sürüm karşılaştırması bunun üzerinden yapılır: uygulamayla gelen kopya
  /// güncelse 28 belgelik liste hiç çekilmez.
  Future<Map<String, dynamic>> hatBilgisiGetir() async {
    final adres = Uri.parse(
      '${FirebaseAyari.firestoreTaban}/hat/bilgi?key=${FirebaseAyari.apiAnahtari}',
    );

    final yanit = await http.get(adres).timeout(_zamanAsimi);
    if (yanit.statusCode != 200) {
      throw Exception('hat/bilgi yanıtı: ${yanit.statusCode}');
    }

    return _belge(
      jsonDecode(utf8.decode(yanit.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// Durakları kuzeyden güneye sıralı getirir.
  /// Ağ hatası, boş koleksiyon veya yetki sorununda hata fırlatır.
  Future<List<Durak>> duraklariGetir() async {
    final adres = Uri.parse(
      '${FirebaseAyari.firestoreTaban}/duraklar'
      '?pageSize=300&key=${FirebaseAyari.apiAnahtari}',
    );

    final yanit = await http.get(adres).timeout(_zamanAsimi);
    if (yanit.statusCode != 200) {
      throw Exception('Firestore yanıtı: ${yanit.statusCode}');
    }

    final govde = jsonDecode(utf8.decode(yanit.bodyBytes)) as Map<String, dynamic>;
    final belgeler = govde['documents'] as List<dynamic>? ?? const [];
    if (belgeler.isEmpty) throw Exception('Firestore boş.');

    final haritalar = belgeler
        .map((b) => _belge(b as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => (a['sira'] as int).compareTo(b['sira'] as int));

    return haritalar.map(Durak.jsondan).toList();
  }
}
