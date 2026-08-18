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

if (typeof module !== 'undefined') {
  module.exports = { durakBul: durakBul, sureBicimle: sureBicimle, yolculukHesapla: yolculukHesapla };
}
