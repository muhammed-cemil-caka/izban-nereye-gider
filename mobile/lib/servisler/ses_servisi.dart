import 'package:flutter_tts/flutter_tts.dart';
import '../diller.dart';

/// Adım adım yönlendirmede talimatları sesli okur.
///
/// Webdeki `speechSynthesis` karşılığı; iki istemci aynı davransın diye
/// eklendi. Cihazda Türkçe ses paketi yoksa ya da motor açılamazsa sessizce
/// vazgeçilir — yönlendirme sesli olmadan çalışmaya devam eder.
class SesServisi {
  final FlutterTts _motor = FlutterTts();
  bool _kullanilabilir = true;

  /// Motorun ayarlandığı dil. Kullanıcı yönlendirme sürerken dili
  /// değiştirebiliyor; İngilizce adımı Türkçe sesle okutmak anlaşılmaz oluyor.
  String? _ayarlananDil;

  Future<void> _hazirla() async {
    final istenen = Diller.aktif.kod == 'en' ? 'en-US' : 'tr-TR';
    if (_ayarlananDil == istenen) return;

    try {
      // Cihazda tam eşleşme kurulu olmayabilir (yalnızca en-GB gibi). Doğrudan
      // setLanguage çağırmak motoru önceki dilde bırakıyor ve İngilizce
      // cümleler Türkçe sesle okunuyor.
      var kod = istenen;
      if (await _motor.isLanguageAvailable(istenen) != true) {
        kod = istenen.split('-').first;
      }
      await _motor.setLanguage(kod);
      // Bir talimat okunurken yenisi gelirse öncekini kes; kuyruğa alma.
      await _motor.setQueueMode(0);
      _ayarlananDil = istenen;
    } catch (_) {
      _kullanilabilir = false;
    }
  }

  /// Metni okur. Önceki okuma varsa kesilir: kullanıcı geçmiş bir manevrayı
  /// dinlemeye devam etmesin.
  Future<void> konus(String metin) async {
    if (metin.trim().isEmpty) return;
    await _hazirla();
    if (!_kullanilabilir) return;

    try {
      await _motor.stop();
      await _motor.speak(metin);
    } catch (_) {
      _kullanilabilir = false;
    }
  }

  Future<void> sustur() async {
    if (_ayarlananDil == null || !_kullanilabilir) return;
    try {
      await _motor.stop();
    } catch (_) {
      // Motor kapandıysa yapacak bir şey yok.
    }
  }
}
