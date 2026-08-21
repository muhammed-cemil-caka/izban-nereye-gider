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
    seferYok: 'Bu durak çifti için resmî sefer verisi yayınlanmıyor (Selçuk uzantısı kapsam dışı).',
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

    uyari: 'Uyarı:',
    uyariMetin: 'Durak sırası ve süreler tahminidir, resmî kaynak değildir. Güncel tarife için',
    veriSurumu: 'Veri sürümü:',
    kaynak: 'Kaynak:',
    yerelKopya: 'yerel kopya'
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
    seferYok: 'No official timetable is published for this pair (the Selçuk extension is not covered).',
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

    uyari: 'Warning:',
    uyariMetin: 'Station order and times are estimates, not an official source. For the current timetable see',
    veriSurumu: 'Data version:',
    kaynak: 'Source:',
    yerelKopya: 'local copy'
  }
};

var DIL_ANAHTAR = 'izban.dil';

/** Seçili dil kodu: kayıt → tarayıcı dili → Türkçe. */
function dilKodunuBul() {
  try {
    var kayitli = localStorage.getItem(DIL_ANAHTAR);
    if (kayitli && DILLER[kayitli]) return kayitli;
  } catch (e) { /* özel mod */ }

  var tarayici = (navigator.language || 'tr').slice(0, 2).toLowerCase();
  return DILLER[tarayici] ? tarayici : 'tr';
}

if (typeof module !== 'undefined') {
  module.exports = { DILLER: DILLER };
}
