import 'package:http/http.dart' as http;

/// Dış servislere nereden gidileceğini belirler.
///
/// İki yol var:
///
///   VEKİL     `<taban>/api/...` — kendi Cloud Function'ımız. Yanıtlar Firebase
///             Hosting CDN'inde önbelleklenir, dış servise avuç dolusu istek
///             gider. Yüzlerce yolcuyu kaldıran yol bu.
///   DOĞRUDAN  dış servisin kendisi. Vekil ayakta değilken kullanılır.
///
/// Vekil bir kez yoklanır; sonuç uygulama açık kaldığı sürece saklanır. Böylece
/// yayına alınmamış bir kurulumda da uygulama çalışmaya devam eder.
///
/// Sağlayıcı sunucuda değiştiğinde uygulama güncellemesi gerekmiyor — mobilde
/// bu, webden daha değerli: mağaza güncellemesi kullanıcılara günlerce yayılıyor.
///
/// Web tarafındaki frontend/js/servis.js ile aynı mantık.
class ServisAdresi {
  const ServisAdresi._();

  /// Firebase Hosting adresi. Kendi projene göre değiştir.
  static const taban = 'https://izban-nereye-gider.web.app';

  static const _yoklamaSuresi = Duration(seconds: 4);

  /// null = bilinmiyor, true = vekil var, false = yok.
  static bool? _vekilVarMi;

  /// Testler için: yoklamayı atlayıp sonucu dayatır.
  static void dayat(bool? deger) => _vekilVarMi = deger;

  static Future<bool> _vekiliYokla() async {
    final bilinen = _vekilVarMi;
    if (bilinen != null) return bilinen;

    try {
      final yanit = await http
          .get(Uri.parse('$taban/api/saglik'))
          .timeout(_yoklamaSuresi);
      _vekilVarMi = yanit.statusCode == 200;
    } catch (_) {
      _vekilVarMi = false;
    }
    return _vekilVarMi!;
  }

  /// Vekil varsa [vekil], yoksa [dogrudan] adresini döndürür.
  static Future<Uri> coz(Uri Function() vekil, Uri Function() dogrudan) async {
    return await _vekiliYokla() ? vekil() : dogrudan();
  }
}
