import 'package:flutter_tts/flutter_tts.dart';

/// Adım adım yönlendirmede talimatları sesli okur.
///
/// Webdeki `speechSynthesis` karşılığı; iki istemci aynı davransın diye
/// eklendi. Cihazda Türkçe ses paketi yoksa ya da motor açılamazsa sessizce
/// vazgeçilir — yönlendirme sesli olmadan çalışmaya devam eder.
class SesServisi {
  final FlutterTts _motor = FlutterTts();
  bool _hazirlandi = false;
  bool _kullanilabilir = true;

  Future<void> _hazirla() async {
    if (_hazirlandi) return;
    _hazirlandi = true;

    try {
      await _motor.setLanguage('tr-TR');
      // Bir talimat okunurken yenisi gelirse öncekini kes; kuyruğa alma.
      await _motor.setQueueMode(0);
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
    if (!_hazirlandi || !_kullanilabilir) return;
    try {
      await _motor.stop();
    } catch (_) {
      // Motor kapandıysa yapacak bir şey yok.
    }
  }
}
