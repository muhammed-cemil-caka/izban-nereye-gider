// Arayüz metinleri — Türkçe ve İngilizce.
//
// Yalnızca ARAYÜZ çevrilir. Durak ve turistik yer adları özel isim olduğu için
// olduğu gibi kalır; turistik özetler de Türkçe Vikipedi'den geliyor.
var DILLER = {
  tr: {
    kod: 'tr',
    dilAdi: 'Türkçe',
    digerDil: 'English',

    markaAlt: 'Aliağa – Selçuk banliyö hattı yolculuk asistanı',
    temaDegistir: 'Temayı değiştir',
    dilDegistir: 'Switch to English',

    konumBaslik: 'Konumun',
    konumAliniyor: 'Konumun alınıyor…',
    binisDuragiYap: 'Biniş durağı yap',
    yuruyerekYolTarifi: 'Yürüyerek yol tarifi',
    arabaylaYolTarifi: 'Arabayla yol tarifi',
    konumDuzelt: 'Konumum yanlış mı? Yerimi kendim gireyim',
    konumAraPlaceholder: 'Durak, mahalle veya cadde adı',
    digerDuraklar: 'Yakındaki diğer duraklar:',
    konumumuBul: 'Konumumu bul',
    konumumuYenidenBul: 'Konumumu yeniden bul',
    enYakinDurak: 'En yakın durak:',

    nereden: 'Nereden biniyorsun?',
    nereye: 'Nereye gideceksin?',
    yerDegistir: 'Biniş ve iniş duraklarını yer değiştir',
    duragaYolTarifi: 'Bu durağa yol tarifi →',

    haritaBaslik: 'Harita',
    haritaIpucu: 'Durağa tıkla · konumunu düzeltmek için işarete 2 sn basılı tut · ⊕ düğmesi konumuna döner',
    haritaKatki: 'Harita verisi © OpenStreetMap katkıcıları',
    konumaDon: 'Konumuma dön',

    basla: 'Başla',
    bitir: 'Bitir',
    sesli: 'Sesli',
    yuruyerek: 'Yürüyerek',
    arabayla: 'Arabayla',
    topluTasima: 'Toplu taşıma',
    yolTarifiniKaldir: 'Yol tarifini kaldır',
    toplamYuruyus: 'toplam yürüyüş',
    toplamSurus: 'toplam sürüş',

    siradakiTrenler: 'Sıradaki trenler',
    seferAliniyor: 'Sefer saatleri alınıyor…',
    seferYok: 'Bu durak çifti için resmî sefer verisi yayınlanmıyor.',
    seferUlasilamiyor: 'Sefer saatlerine şu an ulaşılamıyor.',
    seferKaynak: 'kaynak: İzmir Büyükşehir Belediyesi açık veri',
    sefer: 'sefer',
    dkSonra: 'dk sonra',
    simdi: 'şimdi',
    yarin: 'yarın',

    geziBaslik: 'Gezilecek yerler',
    geziIpucu: 'Biniş ve iniş durağının çevresi · karta tıkla, yol tarifi çıksın',
    geziCevresi: 'çevresi',
    yer: 'yer',
    duraktan: 'Duraktan',
    geziKaynak: 'Metin ve görseller:',

    ozetSure: 'tahmini süre',
    ozetDurak: 'durak',
    ozetAktarma: 'aktarma noktası',
    guzergah: 'Güzergâh',
    aktarmalar: 'Yol üstündeki aktarmalar',
    binis: 'BİNİŞ',
    inis: 'İNİŞ',
    aktarma: 'AKTARMA',
    aktarmaNoktasi: 'aktarma noktası',
    kaydirarakGor: 'listeyi kaydırarak devamını gör',
    adim: 'adım',

    ozetCumle: '{binis} durağından bindin: {yon} yönündeki trene binmelisin. {durak} durak sonra, yaklaşık {sure} içinde {inis} durağındasın.',
    dogruluk: 'Konum doğruluğu ±{m} m',
    dogrulukKaba: 'Konum ±{m} m doğrulukla alındı — en yakın durak şaşabilir, aşağıdan seçebilirsin.',
    elleKonum: 'Konum senin girdiğin yere göre: {etiket}',
    elleKonumSade: 'Konum senin girdiğin yere göre hesaplandı.',
    iyilestiriliyor: 'iyileştiriliyor…',
    canliTakip: 'canlı takip açık',
    yuruyusHesaplaniyor: 'Yürüyüş rotası hesaplanıyor…',
    arabaHesaplaniyor: 'Araba rotası hesaplanıyor…',
    durakSeciliyorYuruyus: 'En yakın durak yürüyüş ağına göre seçiliyor…',
    durakSeciliyorAraba: 'En yakın durak araç ağına göre seçiliyor…',
    rotaAlinamadi: 'Rota alınamadı.',
    durakBulunamadi: 'Durak bulunamadı.',
    yolaCik: 'Yola çık',
    vardin: 'Vardın.',
    varildi: '{durak} durağına vardın.',
    yolculukBaslasin: 'Yolculuk başlasın.',
    rotadanCiktin: 'Rotadan çıktın, yeniden hesaplanıyor…',
    yeniRotaYok: 'Yeni rota alınamadı, yönlendirme durduruldu.',
    konumYokYonlendirme: 'Konum alınamadı, yönlendirme durduruldu.',
    yonlendirmeSasabilir: 'Konum ±{m} m — yönlendirme şaşabilir.',
    yerlerAraniyor: 'Yerler aranıyor…',
    sonucYok: 'Sonuç yok. Mahalle, cadde veya durak adı deneyebilirsin.',
    aramaCalismiyor: 'Yer araması şu an çalışmıyor.',
    firebaseOnbellek: 'Firebase (önbellek)',
    topluTasimaAnlat: 'İZBAN ile {durak} durağına gel. · {durak} aktarmaları: {aktarma} · ESHOT hatları: {hatlar} · Oradan {yer} için "Yürüyerek" düğmesini kullan. · Otobüs saati veremiyorum: ESHOT tarife verisi elimizde yok.',
    aktarmayaTarif: '{tur} aktarmasına yürüyüş yol tarifi ({mesafe})',
    duragaTarif: '{durak} durağına yürüyerek yol tarifini haritada göster',
    duragina: 'durağına',
    yonEtiketi: '{durak} yönü',
    saat: 'sa',
    dakika: 'dk',
    yolculukSecimi: 'Yolculuk seçimi',
    geziKaynakTam: 'Metin ve görseller: Wikidata · Vikipedi (CC BY-SA) · Wikimedia Commons',
    uyari: 'Uyarı:',
    uyariMetin: 'Durak sırası ve süreler tahminidir, resmî kaynak değildir. Güncel tarife için',
    veriSurumu: 'Veri sürümü:',
    kaynak: 'Kaynak:',
    yerelKopya: 'yerel kopya',
    seferAktarmaNotu: '{durak} aktarması · {dk} dk bekleme',
    seferAktarmasiz: 'aktarmasız',
    seferBirAktarma: '1 aktarma',
    seferIkiAktarma: '2 aktarma',
    seferSayisi: '{adet} sefer',

    konumDesteklenmiyor: 'Tarayıcınız konum servisini desteklemiyor.',
    konumGuvenliBaglam: 'Konum yalnızca güvenli bağlantıda (https) çalışır. Siteyi localhost veya https adresinden açın.',
    konumYanitVermedi: 'Konum yanıt vermedi. macOS kullanıyorsan Sistem Ayarları → Gizlilik ve Güvenlik → Konum Servisleri altında tarayıcına izin verilmiş olmalı.',
    konumIzniYok: 'Konum izni verilmedi. Adres çubuğundaki kilit simgesinden izin verip tekrar deneyebilirsin.',
    konumBilgisiYok: 'Konum bilgisi alınamadı.',
    konumZamanAsimi: 'Konum isteği zaman aşımına uğradı.',
    konumAlinamadi: 'Konum alınamadı.',
    konumKoordinatYok: 'Duraklarda koordinat bilgisi yok.',
    konumOnceGerekli: 'Önce konumunu bulmam gerekiyor.',
    aramaBasarisiz: 'Arama başarısız ({kod})',

    aramaDuraklar: 'Duraklar',
    aramaYerler: 'Yerler',
    haritadanSecilen: 'haritadan seçtiğin nokta',
    fazlaHat: '+{adet} hat',

    ayniDurak: 'Biniş ve iniş durağı aynı olamaz.',
    duragaYolTarifiAd: '{durak} durağına yol tarifi →',
    rotaBasligiDurak: '{durak} durağına',
    rotaKipYuruyus: '— yürüyüş',
    rotaKipAraba: '— araba ile',
    mesafeYuruyus: '{mesafe} yürüyüş',
    mesafeAraba: '{mesafe} araba ile',
    devamEt: 'Devam et',
    kalan: 'Kalan: {mesafe}',
    aktarmaTuruEki: '{tur} aktarması',

    yolaCikYol: 'Yola çık{yol}',
    vardinYol: 'Vardın{yol}',
    donYol: '{yon} dön{yol}',
    donSadeYol: 'Dön{yol}',
    yolSonuYol: 'Yolun sonunda {yon} dön{yol}',
    ayrimYol: 'Ayrımda {yon} git{yol}',
    devamEtYol: 'Devam et{yol}',
    kavsakYol: 'Kavşaktan çık{yol}',
    yolaKatilYol: 'Yola katıl{yol}',
    manevraSola: 'sola',
    manevraSaga: 'sağa',
    manevraHafifSola: 'hafif sola',
    manevraHafifSaga: 'hafif sağa',
    manevraKeskinSola: 'keskin sola',
    manevraKeskinSaga: 'keskin sağa',
    manevraDuz: 'düz',
    manevraGeri: 'geri',
    manevraDevamEt: 'devam et',

    haritaKonumBaslik: 'Konumun',
    haritaKonumBaslikUzun: 'Konumun — yerini düzeltmek için 2 saniye basılı tut',
    haritaBuradasin: 'Buradasın',
    haritaBuradasinUzun: 'Buradasın · düzeltmek için 2 sn basılı tut',

    geziTurAciklama: '{ilce} ilçesinde {tur}',
    turAntikKent: 'antik kent',
    turMuze: 'müze',
    turCami: 'cami',
    turKilise: 'kilise',
    turKale: 'kale',
    turAnit: 'anıt',
    turPark: 'park',
    turKulturVarligi: 'kültür varlığı',
    turKule: 'kule',
    turTarihiYapi: 'tarihi yapı',
    turGeziNoktasi: 'gezilecek yer',

    birimDk: 'dk',
    birimSa: 'sa',
    birimM: 'm',
    birimKm: 'km'
  },

  en: {
    kod: 'en',
    dilAdi: 'English',
    digerDil: 'Türkçe',

    markaAlt: 'Aliağa – Selçuk commuter line travel assistant',
    temaDegistir: 'Switch theme',
    dilDegistir: 'Türkçeye geç',

    konumBaslik: 'Your location',
    konumAliniyor: 'Getting your location…',
    binisDuragiYap: 'Set as departure',
    yuruyerekYolTarifi: 'Walking directions',
    arabaylaYolTarifi: 'Driving directions',
    konumDuzelt: 'Wrong location? Let me set it myself',
    konumAraPlaceholder: 'Station, neighbourhood or street',
    digerDuraklar: 'Other nearby stations:',
    konumumuBul: 'Find my location',
    konumumuYenidenBul: 'Find my location again',
    enYakinDurak: 'Nearest station:',

    nereden: 'Where do you board?',
    nereye: 'Where are you going?',
    yerDegistir: 'Swap departure and arrival stations',
    duragaYolTarifi: 'Directions to this station →',

    haritaBaslik: 'Map',
    haritaIpucu: 'Tap a station · hold the pin 2 s to correct your location · ⊕ returns to your location',
    haritaKatki: 'Map data © OpenStreetMap contributors',
    konumaDon: 'Back to my location',

    basla: 'Start',
    bitir: 'Finish',
    sesli: 'Voice',
    yuruyerek: 'Walking',
    arabayla: 'Driving',
    topluTasima: 'Public transport',
    yolTarifiniKaldir: 'Clear directions',
    toplamYuruyus: 'total walk',
    toplamSurus: 'total drive',

    siradakiTrenler: 'Next trains',
    seferAliniyor: 'Loading timetable…',
    seferYok: 'No official timetable is published for this station pair.',
    seferUlasilamiyor: 'Timetable is unavailable right now.',
    seferKaynak: 'source: İzmir Metropolitan Municipality open data',
    sefer: 'services',
    dkSonra: 'min from now',
    simdi: 'now',
    yarin: 'tomorrow',

    geziBaslik: 'Places to visit',
    geziIpucu: 'Around your departure and arrival stations · tap a card for directions',
    geziCevresi: 'area',
    yer: 'places',
    duraktan: 'From the station',
    geziKaynak: 'Text and images:',

    ozetSure: 'estimated time',
    ozetDurak: 'stations',
    ozetAktarma: 'interchanges',
    guzergah: 'Route',
    aktarmalar: 'Interchanges along the way',
    binis: 'BOARD',
    inis: 'EXIT',
    aktarma: 'INTERCHANGE',
    aktarmaNoktasi: 'interchange points',
    kaydirarakGor: 'scroll the list for more',
    adim: 'steps',

    ozetCumle: 'You board at {binis}: take the train towards {yon}. After {durak} stations, about {sure}, you arrive at {inis}.',
    dogruluk: 'Location accuracy ±{m} m',
    dogrulukKaba: 'Location taken with ±{m} m accuracy — the nearest station may be off, pick one below.',
    elleKonum: 'Location set by you: {etiket}',
    elleKonumSade: 'Location calculated from the point you set.',
    iyilestiriliyor: 'improving…',
    canliTakip: 'live tracking on',
    yuruyusHesaplaniyor: 'Calculating walking route…',
    arabaHesaplaniyor: 'Calculating driving route…',
    durakSeciliyorYuruyus: 'Choosing the nearest station on the walking network…',
    durakSeciliyorAraba: 'Choosing the nearest station on the driving network…',
    rotaAlinamadi: 'Could not get the route.',
    durakBulunamadi: 'No station found.',
    yolaCik: 'Set off',
    vardin: 'You have arrived.',
    varildi: 'You have arrived at {durak}.',
    yolculukBaslasin: 'Have a good trip.',
    rotadanCiktin: 'Off route, recalculating…',
    yeniRotaYok: 'Could not get a new route, guidance stopped.',
    konumYokYonlendirme: 'Location unavailable, guidance stopped.',
    yonlendirmeSasabilir: 'Location ±{m} m — guidance may be off.',
    yerlerAraniyor: 'Searching places…',
    sonucYok: 'No results. Try a neighbourhood, street or station name.',
    aramaCalismiyor: 'Place search is unavailable right now.',
    firebaseOnbellek: 'Firebase (cached)',
    topluTasimaAnlat: 'Take İZBAN to {durak}. · Interchanges at {durak}: {aktarma} · ESHOT lines: {hatlar} · From there use the "Walking" button for {yer}. · No bus times: we have no ESHOT timetable data.',
    aktarmayaTarif: 'Walking directions to the {tur} interchange ({mesafe})',
    duragaTarif: 'Show walking directions to {durak} on the map',
    duragina: 'station',
    yonEtiketi: 'towards {durak}',
    saat: 'h',
    dakika: 'min',
    yolculukSecimi: 'Journey selection',
    geziKaynakTam: 'Text and images: Wikidata · Wikipedia (CC BY-SA) · Wikimedia Commons',
    uyari: 'Warning:',
    uyariMetin: 'Station order and times are estimates, not an official source. For the current timetable see',
    veriSurumu: 'Data version:',
    kaynak: 'Source:',
    yerelKopya: 'local copy',
    seferAktarmaNotu: 'change at {durak} · {dk} min wait',
    seferAktarmasiz: 'direct',
    seferBirAktarma: '1 change',
    seferIkiAktarma: '2 changes',
    seferSayisi: '{adet} services',

    konumDesteklenmiyor: 'Your browser does not support location services.',
    konumGuvenliBaglam: 'Location only works on a secure connection (https). Open the site over localhost or https.',
    konumYanitVermedi: 'Location did not respond. On macOS, check System Settings → Privacy & Security → Location Services and allow your browser.',
    konumIzniYok: 'Location permission was denied. Allow it from the lock icon in the address bar and try again.',
    konumBilgisiYok: 'Location information is unavailable.',
    konumZamanAsimi: 'The location request timed out.',
    konumAlinamadi: 'Could not get your location.',
    konumKoordinatYok: 'The stations have no coordinate data.',
    konumOnceGerekli: 'I need to find your location first.',
    aramaBasarisiz: 'Search failed ({kod})',

    aramaDuraklar: 'Stations',
    aramaYerler: 'Places',
    haritadanSecilen: 'the point you picked on the map',
    fazlaHat: '+{adet} lines',

    ayniDurak: 'Departure and arrival stations cannot be the same.',
    duragaYolTarifiAd: 'Directions to {durak} →',
    rotaBasligiDurak: '{durak} station',
    rotaKipYuruyus: '— walking',
    rotaKipAraba: '— by car',
    mesafeYuruyus: '{mesafe} walk',
    mesafeAraba: '{mesafe} by car',
    devamEt: 'Continue',
    kalan: 'Remaining: {mesafe}',
    aktarmaTuruEki: '{tur} interchange',

    yolaCikYol: 'Set off{yol}',
    vardinYol: 'You have arrived{yol}',
    donYol: 'Turn {yon}{yol}',
    donSadeYol: 'Turn{yol}',
    yolSonuYol: 'At the end of the road turn {yon}{yol}',
    ayrimYol: 'At the fork keep {yon}{yol}',
    devamEtYol: 'Continue{yol}',
    kavsakYol: 'Exit the roundabout{yol}',
    yolaKatilYol: 'Merge onto the road{yol}',
    manevraSola: 'left',
    manevraSaga: 'right',
    manevraHafifSola: 'slightly left',
    manevraHafifSaga: 'slightly right',
    manevraKeskinSola: 'sharp left',
    manevraKeskinSaga: 'sharp right',
    manevraDuz: 'straight',
    manevraGeri: 'back',
    manevraDevamEt: 'continue',

    haritaKonumBaslik: 'Your location',
    haritaKonumBaslikUzun: 'Your location — hold for 2 seconds to correct it',
    haritaBuradasin: 'You are here',
    haritaBuradasinUzun: 'You are here · hold 2 s to correct',

    geziTurAciklama: '{tur} in {ilce}',
    turAntikKent: 'Ancient city',
    turMuze: 'Museum',
    turCami: 'Mosque',
    turKilise: 'Church',
    turKale: 'Castle',
    turAnit: 'Monument',
    turPark: 'Park',
    turKulturVarligi: 'Cultural heritage site',
    turKule: 'Tower',
    turTarihiYapi: 'Historic building',
    turGeziNoktasi: 'Point of interest',

    birimDk: 'min',
    birimSa: 'h',
    birimM: 'm',
    birimKm: 'km'
  }
};

var DIL_ANAHTAR = 'izban.dil';

/** Seçili dil kodu: kayıt → tarayıcı dili → Türkçe. */
function dilKodunuBul() {
  try {
    var kayitli = localStorage.getItem(DIL_ANAHTAR);
    if (kayitli && DILLER[kayitli]) return kayitli;
  } catch (e) { /* özel mod */ }

  var tarayici = (typeof navigator !== 'undefined' && navigator.language ? navigator.language : 'tr')
    .slice(0, 2).toLowerCase();
  return DILLER[tarayici] ? tarayici : 'tr';
}

/* ---------- Ortak çeviri çalışma zamanı ----------

   Seçili dil tek bir yerde tutulur. Önce yalnızca uygulama.js'in içindeydi;
   rota adımları, harita ipuçları ve konum hataları o kapsamın dışında kaldığı
   için İngilizce arayüzde Türkçe kalıyorlardı. Artık her dosya ceviriMetni()
   çağırabiliyor. */

var DIL_DURUMU = { kod: 'tr' };

/** Seçili dili değiştirir. Bilinmeyen kod yok sayılır. */
function dilAyarla(kod) {
  if (DILLER[kod]) DIL_DURUMU.kod = kod;
  return DIL_DURUMU.kod;
}

function secilenDil() {
  return DIL_DURUMU.kod;
}

/**
 * Sözlükten metin. Anahtar yoksa anahtarın kendisi döner (gözden kaçmasın).
 *
 * {anahtar} yer tutucuları: dilden dile kelime sırası değiştiği için metin
 * parçalarını birleştirmek yerine şablon kullanılıyor.
 */
function ceviriMetni(anahtar, degerler) {
  var sozluk = DILLER[DIL_DURUMU.kod] || DILLER.tr;
  var metin = sozluk[anahtar] || DILLER.tr[anahtar] || anahtar;

  if (degerler) {
    Object.keys(degerler).forEach(function (k) {
      metin = metin.split('{' + k + '}').join(degerler[k]);
    });
  }
  return metin;
}

// Klasik script olarak yüklendiğinde bunlar zaten küresel. Node'da (testler)
// modül kapsamı geçerli olduğu için açıkça küresele bağlanıyorlar.
if (typeof globalThis !== 'undefined') {
  globalThis.DILLER = DILLER;
  globalThis.DIL_DURUMU = DIL_DURUMU;
  globalThis.dilAyarla = dilAyarla;
  globalThis.secilenDil = secilenDil;
  globalThis.ceviriMetni = ceviriMetni;
}

if (typeof module !== 'undefined') {
  module.exports = {
    DILLER: DILLER,
    dilAyarla: dilAyarla,
    secilenDil: secilenDil,
    ceviriMetni: ceviriMetni,
    dilKodunuBul: dilKodunuBul
  };
}
