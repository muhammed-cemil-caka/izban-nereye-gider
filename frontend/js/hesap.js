// Yolculuk hesaplamaları — saf fonksiyonlar, DOM'a dokunmaz.
// Hem tarayıcıda (klasik script) hem Node üzerinde (test için) çalışır.

/** Durak kodundan durak nesnesini bulur. */
function durakBul(duraklar, kod) {
  return duraklar.find(function (d) { return d.kod === kod; }) || null;
}

/** 140 → "2 sa 20 dk" */
function sureBicimle(dakika) {
  if (dakika < 60) return dakika + ' dk';
  var saat = Math.floor(dakika / 60);
  var kalan = dakika % 60;
  return kalan === 0 ? saat + ' sa' : saat + ' sa ' + kalan + ' dk';
}

/**
 * İki durak arasındaki yolculuğu hesaplar.
 * Veri kuzeyden (Aliağa) güneye (Selçuk) sıralı olduğu için indeks karşılaştırması yeterli.
 */
function yolculukHesapla(duraklar, binisKod, inisKod) {
  var binisIndeks = duraklar.findIndex(function (d) { return d.kod === binisKod; });
  var inisIndeks = duraklar.findIndex(function (d) { return d.kod === inisKod; });

  if (binisIndeks === -1 || inisIndeks === -1) {
    return { gecerli: false, hata: 'Durak bulunamadı.' };
  }
  if (binisIndeks === inisIndeks) {
    return { gecerli: false, hata: 'Biniş ve iniş durağı aynı olamaz.' };
  }

  var guneyeGidiyor = inisIndeks > binisIndeks;
  var ilk = Math.min(binisIndeks, inisIndeks);
  var son = Math.max(binisIndeks, inisIndeks);

  // Güzergâhı her zaman yolculuk yönünde döndür.
  var guzergah = duraklar.slice(ilk, son + 1);
  if (!guneyeGidiyor) guzergah = guzergah.slice().reverse();

  var dakika = Math.abs(duraklar[inisIndeks].dakika - duraklar[binisIndeks].dakika);

  // Biniş ve iniş dahil, aradaki aktarma imkânları.
  var aktarmalar = guzergah
    .filter(function (d) { return d.aktarma && d.aktarma.length > 0; })
    .map(function (d) { return { ad: d.ad, hatlar: d.aktarma }; });

  return {
    gecerli: true,
    binis: duraklar[binisIndeks],
    inis: duraklar[inisIndeks],
    yon: guneyeGidiyor ? 'guney' : 'kuzey',
    yonEtiketi: guneyeGidiyor
      ? duraklar[duraklar.length - 1].ad + ' yönü'
      : duraklar[0].ad + ' yönü',
    durakSayisi: son - ilk,
    dakika: dakika,
    sureMetni: sureBicimle(dakika),
    guzergah: guzergah,
    aktarmalar: aktarmalar
  };
}

/* ---------- Konum ---------- */

/** İki nokta arası kuş uçuşu mesafe (metre) — haversine. */
function metreUzaklik(a, b) {
  var yaricapM = 6371000;
  var p = Math.PI / 180;

  var dEnlem = (b.enlem - a.enlem) * p;
  var dBoylam = (b.boylam - a.boylam) * p;

  var sinEnlem = Math.sin(dEnlem / 2);
  var sinBoylam = Math.sin(dBoylam / 2);

  var h = sinEnlem * sinEnlem +
    Math.cos(a.enlem * p) * Math.cos(b.enlem * p) * sinBoylam * sinBoylam;

  return 2 * yaricapM * Math.asin(Math.sqrt(h));
}

/** 450 → "450 m", 2300 → "2,3 km" */
function mesafeBicimle(metre) {
  if (metre < 1000) return Math.round(metre) + ' m';
  return (metre / 1000).toFixed(1).replace('.', ',') + ' km';
}

/**
 * Verilen konuma en yakın durağı bulur.
 * Koordinatı olmayan duraklar atlanır; hiç aday yoksa null döner.
 */
function enYakinDurak(duraklar, konum) {
  var enIyi = null;

  duraklar.forEach(function (durak) {
    if (!durak.konum || (!durak.konum.enlem && !durak.konum.boylam)) return;

    var mesafe = metreUzaklik(konum, durak.konum);
    if (!enIyi || mesafe < enIyi.mesafeM) {
      enIyi = { durak: durak, mesafeM: mesafe };
    }
  });

  return enIyi;
}

/**
 * Konuma en yakın durakları sıralı döndürür.
 * GPS her zaman isabetli olmadığı için tek bir sonuç dayatmak yerine
 * kullanıcıya seçenek sunmakta kullanılır.
 */
function enYakinDuraklar(duraklar, konum, adet) {
  return duraklar
    .filter(function (durak) {
      return durak.konum && (durak.konum.enlem || durak.konum.boylam);
    })
    .map(function (durak) {
      return { durak: durak, mesafeM: metreUzaklik(konum, durak.konum) };
    })
    .sort(function (a, b) { return a.mesafeM - b.mesafeM; })
    .slice(0, adet || 3);
}

/** Türkçe harfleri sadeleştirip karşılaştırmaya uygun hale getirir. */
function aramaIcinSadelestir(metin) {
  var harita = {
    'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g', 'ı': 'i', 'I': 'i', 'İ': 'i',
    'ö': 'o', 'Ö': 'o', 'ş': 's', 'Ş': 's', 'ü': 'u', 'Ü': 'u'
  };
  return String(metin)
    .replace(/[çÇğĞıIİöÖşŞüÜ]/g, function (h) { return harita[h]; })
    .toLowerCase()
    .trim();
}

/**
 * Durak adlarında arama yapar. Yerel veriyle çalıştığı için ağ gerektirmez ve
 * konum servisi şaştığında kullanıcının doğrudan durak seçmesini sağlar.
 */
function durakAra(duraklar, sorgu) {
  var temiz = aramaIcinSadelestir(sorgu);
  if (temiz.length < 2) return [];

  return duraklar.filter(function (durak) {
    return aramaIcinSadelestir(durak.ad).indexOf(temiz) !== -1 ||
           aramaIcinSadelestir(durak.ilce).indexOf(temiz) !== -1;
  });
}

/** Durağa yürüyerek yol tarifi için Google Haritalar adresi. */
function yolTarifiAdresi(durak) {
  return 'https://www.google.com/maps/dir/?api=1' +
    '&destination=' + durak.konum.enlem + ',' + durak.konum.boylam +
    '&travelmode=walking';
}

if (typeof module !== 'undefined') {
  module.exports = {
    durakBul: durakBul,
    sureBicimle: sureBicimle,
    yolculukHesapla: yolculukHesapla,
    metreUzaklik: metreUzaklik,
    mesafeBicimle: mesafeBicimle,
    enYakinDurak: enYakinDurak,
    enYakinDuraklar: enYakinDuraklar,
    durakAra: durakAra,
    aramaIcinSadelestir: aramaIcinSadelestir,
    yolTarifiAdresi: yolTarifiAdresi
  };
}
