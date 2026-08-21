import 'package:flutter/widgets.dart';

/// Arayüz metinleri — Türkçe ve İngilizce.
///
/// Yalnızca ARAYÜZ çevrilir. Durak ve turistik yer adları özel isim olduğu için
/// olduğu gibi kalır; turistik özetler de Türkçe Vikipedi'den geliyor.
/// Web tarafındaki frontend/js/diller.js ile aynı anahtarları kullanır.
class Diller {
  static const tr = <String, String>{
    'dilDegistir': 'Switch to English',
    'temaAcik': 'Açık temaya geç',
    'temaKoyu': 'Koyu temaya geç',

    'konumBaslik': 'KONUMUN',
    'enYakinDurak': 'En yakın durak:',
    'binisDuragiYap': 'Biniş durağı yap',
    'yuruyerek': 'Yürüyerek',
    'arabayla': 'Arabayla',
    'topluTasima': 'Toplu taşıma',
    'digerDuraklar': 'Yakındaki diğer duraklar:',
    'konumumuBul': 'Konumumu bul',
    'konumAraniyor': 'Konumun alınıyor…',

    'nereden': 'Nereden biniyorsun?',
    'nereye': 'Nereye gideceksin?',
    'yerDegistir': 'Yer değiştir',

    'haritaBaslik': 'HARİTA',
    'haritaIpucu': 'Durağa dokun · konumu düzeltmek için işarete 2 sn basılı tut · ⊕ düğmesi konumuna döner',
    'haritaKatki': 'Harita verisi © OpenStreetMap katkıcıları',
    'konumaDon': 'Konumuma dön',

    'basla': 'Başla',
    'bitir': 'Bitir',
    'sesiAc': 'Sesi aç',
    'sesiKapat': 'Sesi kapat',
    'yolTarifiniKaldir': 'Yol tarifini kaldır',
    'toplamYuruyus': 'toplam yürüyüş',
    'toplamSurus': 'toplam sürüş',
    'rotaHesaplaniyor': 'rotası hesaplanıyor…',

    'siradakiTrenler': 'SIRADAKİ TRENLER',
    'seferAliniyor': 'Sefer saatleri alınıyor…',
    'seferYok': 'Bu durak çifti için resmî sefer verisi yayınlanmıyor (Selçuk uzantısı kapsam dışı).',
    'seferUlasilamiyor': 'Sefer saatlerine şu an ulaşılamıyor.',
    'seferKaynak': 'kaynak: İzmir Büyükşehir Belediyesi açık veri',
    'sefer': 'sefer',
    'dkSonra': 'dk sonra',
    'simdi': 'şimdi',
    'yarin': 'yarın',

    'geziBaslik': 'GEZİLECEK YERLER',
    'geziIpucu': 'Biniş ve iniş durağının çevresi · karttaki düğmeler yol tarifi çizer',
    'geziCevresi': 'çevresi',
    'yer': 'yer',
    'duraktan': 'Duraktan',
    'geziKaynak': 'Metin ve görseller: Wikidata · Vikipedi (CC BY-SA) · Wikimedia Commons',
    'yuru': 'Yürü',
    'araba': 'Araba',
    'toplu': 'Toplu',

    'ozetSure': 'tahmini süre',
    'ozetDurak': 'durak',
    'ozetAktarma': 'aktarma',
    'guzergah': 'GÜZERGÂH',
    'aktarmalar': 'YOL ÜSTÜNDEKİ AKTARMALAR',
    'aktarmaRozet': 'AKTARMA',
    'aktarmaNoktasi': 'aktarma noktası',
    'kaydirarakGor': 'listeyi kaydırarak devamını gör',
    'adim': 'adım',
    'ayniDurak': 'Biniş ve iniş durağı aynı olamaz.',
    'tarifeUyarisi': 'Durak sırası ve süreler tahminidir, resmî kaynak değildir.',
  };

  static const en = <String, String>{
    'dilDegistir': 'Türkçeye geç',
    'temaAcik': 'Switch to light theme',
    'temaKoyu': 'Switch to dark theme',

    'konumBaslik': 'YOUR LOCATION',
    'enYakinDurak': 'Nearest station:',
    'binisDuragiYap': 'Set as departure',
    'yuruyerek': 'Walking',
    'arabayla': 'Driving',
    'topluTasima': 'Public transport',
    'digerDuraklar': 'Other nearby stations:',
    'konumumuBul': 'Find my location',
    'konumAraniyor': 'Getting your location…',

    'nereden': 'Where do you board?',
    'nereye': 'Where are you going?',
    'yerDegistir': 'Swap',

    'haritaBaslik': 'MAP',
    'haritaIpucu': 'Tap a station · hold the pin 2 s to correct your location · ⊕ returns to your location',
    'haritaKatki': 'Map data © OpenStreetMap contributors',
    'konumaDon': 'Back to my location',

    'basla': 'Start',
    'bitir': 'Finish',
    'sesiAc': 'Turn on voice',
    'sesiKapat': 'Turn off voice',
    'yolTarifiniKaldir': 'Clear directions',
    'toplamYuruyus': 'total walk',
    'toplamSurus': 'total drive',
    'rotaHesaplaniyor': 'route is being calculated…',

    'siradakiTrenler': 'NEXT TRAINS',
    'seferAliniyor': 'Loading timetable…',
    'seferYok': 'No official timetable is published for this pair (the Selçuk extension is not covered).',
    'seferUlasilamiyor': 'Timetable is unavailable right now.',
    'seferKaynak': 'source: İzmir Metropolitan Municipality open data',
    'sefer': 'services',
    'dkSonra': 'min from now',
    'simdi': 'now',
    'yarin': 'tomorrow',

    'geziBaslik': 'PLACES TO VISIT',
    'geziIpucu': 'Around your departure and arrival stations · the buttons draw directions',
    'geziCevresi': 'area',
    'yer': 'places',
    'duraktan': 'From the station',
    'geziKaynak': 'Text and images: Wikidata · Wikipedia (CC BY-SA) · Wikimedia Commons',
    'yuru': 'Walk',
    'araba': 'Drive',
    'toplu': 'Transit',

    'ozetSure': 'estimated time',
    'ozetDurak': 'stations',
    'ozetAktarma': 'interchanges',
    'guzergah': 'ROUTE',
    'aktarmalar': 'INTERCHANGES ALONG THE WAY',
    'aktarmaRozet': 'INTERCHANGE',
    'aktarmaNoktasi': 'interchange points',
    'kaydirarakGor': 'scroll the list for more',
    'adim': 'steps',
    'ayniDurak': 'Departure and arrival stations cannot be the same.',
    'tarifeUyarisi': 'Station order and times are estimates, not an official source.',
  };

  final String kod;

  const Diller(this.kod);

  Map<String, String> get _sozluk => kod == 'en' ? en : tr;

  /// Sözlükten metin. Anahtar yoksa anahtarın kendisi döner (gözden kaçmasın).
  String call(String anahtar) => _sozluk[anahtar] ?? anahtar;

  static Diller of(BuildContext context) =>
      DilKapsami.of(context)?.diller ?? const Diller('tr');
}

/// Seçili dili ağaçta taşır — her widget'a tek tek geçirmemek için.
class DilKapsami extends InheritedWidget {
  final Diller diller;

  const DilKapsami({super.key, required this.diller, required super.child});

  static DilKapsami? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DilKapsami>();

  @override
  bool updateShouldNotify(DilKapsami eski) => eski.diller.kod != diller.kod;
}
