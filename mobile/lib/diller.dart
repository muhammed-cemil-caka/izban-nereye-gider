import 'package:flutter/widgets.dart';

/// Arayüz metinleri — Türkçe ve İngilizce.
///
/// Yalnızca ARAYÜZ çevrilir. Durak ve turistik yer adları özel isim olduğu için
/// olduğu gibi kalır; turistik özetler de Türkçe Vikipedi'den geliyor.
/// Web tarafındaki frontend/js/diller.js ile aynı anahtarları kullanır.
class Diller {
  static const tr = <String, String>{
    'markaAlt': 'Aliağa – Selçuk banliyö hattı yolculuk asistanı',
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
    'seferYok': 'Bu durak çifti için resmî sefer verisi yayınlanmıyor.',
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
    'ozetCumle': '{binis} durağından {yon} yönündeki trene bin. {durak} durak sonra, yaklaşık {sure} içinde {inis} durağındasın.',
    'yonEtiketi': '{durak} yönü',
    'saat': 'sa',
    'dakika': 'dk',
    'dogruluk': 'Konum doğruluğu ±{m} m',
    'dogrulukKaba': 'Konum ±{m} m doğrulukla alındı — en yakın durak şaşabilir, aşağıdan seçebilirsin.',
    'yonlendirmeSasabilir': 'Konum ±{m} m — yönlendirme şaşabilir.',
    'konumYok': 'Konum alınamadı.',
    'konumYokYonlendirme': 'Konum alınamadı, yönlendirme durdu.',
    'ayarlariAc': 'Ayarları aç',
    'durakBulunamadi': 'Durak bulunamadı.',
    'rotaAlinamadi': '{kip} rotası alınamadı.',
    'vardin': 'Vardın.',
    'varildi': '{durak} durağına vardın.',
    'duragina': 'durağına',
    'yuruyus': 'yürüyüş',
    'arabaIle': 'araba ile',
    'topluBaslik': '{yer} — toplu taşıma',
    'topluAdim1': 'İZBAN ile {durak} durağına gel.',
    'topluAdim2': '{durak} aktarmaları: {aktarma}',
    'topluAdim3': 'ESHOT hatları: {hatlar}',
    'topluAdim4': 'Oradan "Yürüyerek" ile {yer}.',
    'topluNot': 'Otobüs saati veremiyorum: ESHOT tarife verisi elimizde yok, uydurulmuş bir süre yanıltır.',
    'tamam': 'Tamam',
    'aktarmayaTarif': '{tur} aktarmasına yürüyüş yol tarifi',
    'aktarmaTuruEki': '{tur} aktarması',
    'veriOkunamadi': 'Durak verisi okunamadı',
    'veriSurumu': 'Veri sürümü',
    'firebaseDogrulandi': 'Firebase (doğrulandı)',
    'yerelKopya': 'yerel kopya',
    'kaynak': 'Kaynak',
    'ayniDurak': 'Biniş ve iniş durağı aynı olamaz.',
    'tarifeUyarisi': 'Durak sırası ve süreler tahminidir, resmî kaynak değildir.',

    'seferAktarmaNotu': '{durak} aktarması · {dk} dk bekleme',
    'seferAktarmasiz': 'aktarmasız',
    'seferBirAktarma': '1 aktarma',
    'seferIkiAktarma': '2 aktarma',
    'seferSayisi': '{adet} sefer',

    'konumServisiKapali': 'Cihazın konum servisi kapalı. Ayarlardan açman gerekiyor.',
    'konumIzniYok': 'Konum izni verilmedi.',
    'konumIzniKalici': 'Konum izni kalıcı olarak reddedilmiş. Uygulama ayarlarından açabilirsin.',
    'konumTekrarDene': 'Konum alınamadı, tekrar dener misin?',
    'konumKoordinatYok': 'Duraklarda koordinat bilgisi yok.',

    'yeniRotaYok': 'Yeni rota alınamadı.',
    'rotaBulunamadi': '{kip} rotası bulunamadı.',
    'mesafelerAlinamadi': 'Mesafeler alınamadı.',
    'kipYuruyus': 'Yürüyüş',
    'kipAraba': 'Araba',

    'yolaCikYol': 'Yola çık{yol}',
    'vardinYol': 'Vardın{yol}',
    'donYol': '{yon} dön{yol}',
    'donSadeYol': 'Dön{yol}',
    'yolSonuYol': 'Yolun sonunda {yon} dön{yol}',
    'ayrimYol': 'Ayrımda {yon} git{yol}',
    'devamEtYol': 'Devam et{yol}',
    'kavsakYol': 'Kavşaktan çık{yol}',
    'yolaKatilYol': 'Yola katıl{yol}',
    'manevraSola': 'sola',
    'manevraSaga': 'sağa',
    'manevraHafifSola': 'hafif sola',
    'manevraHafifSaga': 'hafif sağa',
    'manevraKeskinSola': 'keskin sola',
    'manevraKeskinSaga': 'keskin sağa',
    'manevraDuz': 'düz',
    'manevraGeri': 'geri',
    'manevraDevamEt': 'devam et',

    'haritaKonumBaslikUzun': 'Konumun. Yerini düzeltmek için 2 saniye basılı tut.',
    'geziCevresiTam': '{durak} çevresi',
    'mesafeYuruyus': '{mesafe} yürüyüş',
    'mesafeAraba': '{mesafe} araba ile',
    'veriOkunamadiAyrinti': 'Durak verisi okunamadı: {ayrinti}',
    'ornek': 'Örnek',

    'geziTurAciklama': '{ilce} ilçesinde {tur}',
    'turAntikKent': 'antik kent',
    'turMuze': 'müze',
    'turCami': 'cami',
    'turKilise': 'kilise',
    'turKale': 'kale',
    'turAnit': 'anıt',
    'turPark': 'park',
    'turKulturVarligi': 'kültür varlığı',
    'turKule': 'kule',
    'turTarihiYapi': 'tarihi yapı',
    'turGeziNoktasi': 'gezilecek yer',

    'birimM': 'm',
    'birimKm': 'km',
    'birimHiz': 'km/sa',
    'kalan': 'Kalan: {mesafe}',
  };

  static const en = <String, String>{
    'markaAlt': 'Aliağa – Selçuk commuter line travel assistant',
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
    'seferYok': 'No official timetable is published for this station pair.',
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
    'ozetCumle': 'Board at {binis} towards {yon}. After {durak} stations, about {sure}, you arrive at {inis}.',
    'yonEtiketi': 'towards {durak}',
    'saat': 'h',
    'dakika': 'min',
    'dogruluk': 'Location accuracy ±{m} m',
    'dogrulukKaba': 'Location taken with ±{m} m accuracy — the nearest station may be off, pick one below.',
    'yonlendirmeSasabilir': 'Location ±{m} m — guidance may be off.',
    'konumYok': 'Location unavailable.',
    'konumYokYonlendirme': 'Location unavailable, guidance stopped.',
    'ayarlariAc': 'Open settings',
    'durakBulunamadi': 'No station found.',
    'rotaAlinamadi': 'Could not get the {kip} route.',
    'vardin': 'You have arrived.',
    'varildi': 'You have arrived at {durak}.',
    'duragina': 'station',
    'yuruyus': 'walking',
    'arabaIle': 'by car',
    'topluBaslik': '{yer} — public transport',
    'topluAdim1': 'Take İZBAN to {durak}.',
    'topluAdim2': 'Interchanges at {durak}: {aktarma}',
    'topluAdim3': 'ESHOT lines: {hatlar}',
    'topluAdim4': 'From there use "Walking" for {yer}.',
    'topluNot': 'No bus times: we have no ESHOT timetable data, and an invented one would mislead.',
    'tamam': 'OK',
    'aktarmayaTarif': 'Walking directions to the {tur} interchange',
    'aktarmaTuruEki': '{tur} interchange',
    'veriOkunamadi': 'Could not read station data',
    'veriSurumu': 'Data version',
    'firebaseDogrulandi': 'Firebase (verified)',
    'yerelKopya': 'local copy',
    'kaynak': 'Source',
    'ayniDurak': 'Departure and arrival stations cannot be the same.',
    'tarifeUyarisi': 'Station order and times are estimates, not an official source.',

    'seferAktarmaNotu': 'change at {durak} · {dk} min wait',
    'seferAktarmasiz': 'direct',
    'seferBirAktarma': '1 change',
    'seferIkiAktarma': '2 changes',
    'seferSayisi': '{adet} services',

    'konumServisiKapali': 'Location services are off on your device. Turn them on in settings.',
    'konumIzniYok': 'Location permission was denied.',
    'konumIzniKalici': 'Location permission is permanently denied. You can enable it in app settings.',
    'konumTekrarDene': 'Could not get your location, try again?',
    'konumKoordinatYok': 'The stations have no coordinate data.',

    'yeniRotaYok': 'Could not get a new route.',
    'rotaBulunamadi': 'No {kip} route found.',
    'mesafelerAlinamadi': 'Could not get the distances.',
    'kipYuruyus': 'Walking',
    'kipAraba': 'Driving',

    'yolaCikYol': 'Set off{yol}',
    'vardinYol': 'You have arrived{yol}',
    'donYol': 'Turn {yon}{yol}',
    'donSadeYol': 'Turn{yol}',
    'yolSonuYol': 'At the end of the road turn {yon}{yol}',
    'ayrimYol': 'At the fork keep {yon}{yol}',
    'devamEtYol': 'Continue{yol}',
    'kavsakYol': 'Exit the roundabout{yol}',
    'yolaKatilYol': 'Merge onto the road{yol}',
    'manevraSola': 'left',
    'manevraSaga': 'right',
    'manevraHafifSola': 'slightly left',
    'manevraHafifSaga': 'slightly right',
    'manevraKeskinSola': 'sharp left',
    'manevraKeskinSaga': 'sharp right',
    'manevraDuz': 'straight',
    'manevraGeri': 'back',
    'manevraDevamEt': 'continue',

    'haritaKonumBaslikUzun': 'Your location. Hold for 2 seconds to correct it.',
    'geziCevresiTam': '{durak} area',
    'mesafeYuruyus': '{mesafe} walk',
    'mesafeAraba': '{mesafe} by car',
    'veriOkunamadiAyrinti': 'Could not read station data: {ayrinti}',
    'ornek': 'Example',

    'geziTurAciklama': '{tur} in {ilce}',
    'turAntikKent': 'Ancient city',
    'turMuze': 'Museum',
    'turCami': 'Mosque',
    'turKilise': 'Church',
    'turKale': 'Castle',
    'turAnit': 'Monument',
    'turPark': 'Park',
    'turKulturVarligi': 'Cultural heritage site',
    'turKule': 'Tower',
    'turTarihiYapi': 'Historic building',
    'turGeziNoktasi': 'Point of interest',

    'birimM': 'm',
    'birimKm': 'km',
    'birimHiz': 'km/h',
    'kalan': 'Remaining: {mesafe}',
  };

  /// Widget ağacının dışında kalan katmanlar için son seçilen dil.
  ///
  /// Rota servisi, konum servisi ve sefer motoru BuildContext görmüyor ama
  /// ürettikleri metinler ekrana çıkıyor. Önce bunlar sabit Türkçeydi;
  /// İngilizce arayüzde adım listesi ve hata satırları Türkçe kalıyordu.
  static Diller aktif = const Diller('tr');

  final String kod;

  const Diller(this.kod);

  Map<String, String> get _sozluk => kod == 'en' ? en : tr;

  /// Sözlükten metin. Anahtar yoksa anahtarın kendisi döner (gözden kaçmasın).
  ///
  /// {anahtar} yer tutucuları: dilden dile kelime sırası değiştiği için metin
  /// parçalarını birleştirmek yerine şablon kullanılıyor.
  String call(String anahtar, [Map<String, Object?>? degerler]) {
    var metin = _sozluk[anahtar] ?? anahtar;
    if (degerler != null) {
      degerler.forEach((k, v) {
        metin = metin.replaceAll('{$k}', '$v');
      });
    }
    return metin;
  }

  /// 450 → "450 m", 2300 → "2,3 km" / "2.3 km"
  ///
  /// Ondalık ayracı dile göre: Türkçede virgül, İngilizcede nokta.
  String mesafe(double metre) {
    if (metre < 1000) return '${metre.round()} ${call('birimM')}';
    var deger = (metre / 1000).toStringAsFixed(1);
    if (kod != 'en') deger = deger.replaceAll('.', ',');
    return '$deger ${call('birimKm')}';
  }

  /// 148 -> "2 sa 28 dk" / "2 h 28 min"
  String sure(int dakika) {
    final d = dakika < 0 ? 0 : dakika;
    if (d < 60) return '$d ${call('dakika')}';
    final saat = d ~/ 60;
    final kalan = d % 60;
    if (kalan == 0) return '$saat ${call('saat')}';
    return '$saat ${call('saat')} $kalan ${call('dakika')}';
  }

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
