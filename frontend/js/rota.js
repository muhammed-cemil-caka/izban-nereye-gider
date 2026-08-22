// Rota — OSRM (OpenStreetMap tabanlı yönlendirme).
//
// Servis notu: routing.openstreetmap.de FOSSGIS'in işlettiği ücretsiz bir
// topluluk servisidir, anahtar istemez ama ağır kullanıma uygun değildir.
// Bu yüzden rota yalnızca kullanıcı isteyince çekilir, kendiliğinden değil.
// Yayına çıkarken kendi OSRM örneğimize ya da anahtarlı bir servise geçilmeli.
//
// İki kip var: yürüyüş ve araba. FOSSGIS her profili ayrı adreste sunuyor.
var ROTA_TABANLARI = {
  yuruyus: 'https://routing.openstreetmap.de/routed-foot/route/v1/foot',
  araba: 'https://routing.openstreetmap.de/routed-car/route/v1/driving'
};

// En yakın durak sıralaması hep yürüyerek hesaplanır: kullanıcı durağa
// yürüyerek gidiyor, araba mesafesi orada yanıltıcı olurdu.
var ROTA_TABAN = ROTA_TABANLARI.yuruyus;

/** OSRM manevra yönleri → sözlük anahtarları. */
var YON_ANAHTARLARI = {
  left: 'manevraSola',
  right: 'manevraSaga',
  'slight left': 'manevraHafifSola',
  'slight right': 'manevraHafifSaga',
  'sharp left': 'manevraKeskinSola',
  'sharp right': 'manevraKeskinSaga',
  straight: 'manevraDuz',
  uturn: 'manevraGeri'
};

/** İlk harfi büyütür — cümle başına gelen yön adı için. */
function basHarfiBuyut(metin) {
  return metin ? metin.charAt(0).toLocaleUpperCase('tr') + metin.slice(1) : metin;
}

/**
 * OSRM manevrasını arayüz diline çevirir.
 *
 * Adı tarihsel: önce yalnızca Türkçe üretiyordu. Artık seçili dile göre
 * yazıyor — İngilizce arayüzde adım listesi de, sesli yönlendirme de
 * İngilizce olsun diye.
 */
function manevrayiTurkcelestir(manevra, yolAdi) {
  var tur = manevra.type;
  var yonAnahtari = YON_ANAHTARLARI[manevra.modifier];
  var yon = yonAnahtari ? ceviriMetni(yonAnahtari) : '';
  var yer = yolAdi ? ' — ' + yolAdi : '';

  switch (tur) {
    case 'depart':
      return ceviriMetni('yolaCikYol', { yol: yer });
    case 'arrive':
      return ceviriMetni('vardinYol', { yol: yer });
    case 'turn':
      return yon
        ? basHarfiBuyut(ceviriMetni('donYol', { yon: yon, yol: yer }))
        : ceviriMetni('donSadeYol', { yol: yer });
    case 'end of road':
      return ceviriMetni('yolSonuYol', { yon: yon || ceviriMetni('manevraDevamEt'), yol: yer });
    case 'fork':
      return ceviriMetni('ayrimYol', { yon: yon || ceviriMetni('manevraDuz'), yol: yer });
    case 'new name':
    case 'continue':
      return ceviriMetni('devamEtYol', { yol: yer });
    case 'roundabout':
    case 'rotary':
      return ceviriMetni('kavsakYol', { yol: yer });
    case 'merge':
      return ceviriMetni('yolaKatilYol', { yol: yer });
    default:
      return ceviriMetni('devamEtYol', { yol: yer });
  }
}

/**
 * İki nokta arasında rota ister.
 * @param {object} baslangic
 * @param {object} bitis
 * @param {string} [kip] 'yuruyus' (varsayılan) veya 'araba'
 * @returns {Promise<{kip: string, noktalar: Array<[number,number]>, mesafeM: number, sureSn: number, adimlar: Array}>}
 */
function rotaAl(baslangic, bitis, kip) {
  var secilenKip = kip === 'araba' ? 'araba' : 'yuruyus';
  var taban = ROTA_TABANLARI[secilenKip];

  var adres = taban + '/' +
    baslangic.boylam + ',' + baslangic.enlem + ';' +
    bitis.boylam + ',' + bitis.enlem +
    '?overview=full&geometries=geojson&steps=true';

  return fetch(adres)
    .then(function (yanit) {
      if (!yanit.ok) throw new Error(ceviriMetni('rotaAlinamadi'));
      return yanit.json();
    })
    .then(function (veri) {
      if (veri.code !== 'Ok' || !veri.routes || !veri.routes.length) {
        throw new Error(ceviriMetni('rotaAlinamadi'));
      }

      var rota = veri.routes[0];

      // GeoJSON [boylam, enlem] verir; Leaflet [enlem, boylam] bekler.
      var noktalar = rota.geometry.coordinates.map(function (n) {
        return [n[1], n[0]];
      });

      var adimlar = (rota.legs[0] ? rota.legs[0].steps : [])
        .map(function (adim) {
          return {
            metin: manevrayiTurkcelestir(adim.maneuver, adim.name),
            mesafeM: adim.distance
          };
        })
        // Sıfıra yakın adımlar listeyi gereksiz uzatıyor.
        .filter(function (adim, sira, dizi) {
          return adim.mesafeM >= 5 || sira === 0 || sira === dizi.length - 1;
        });

      return {
        kip: secilenKip,
        noktalar: noktalar,
        mesafeM: rota.distance,
        sureSn: rota.duration,
        adimlar: adimlar
      };
    });
}

/**
 * Bir noktadan birden çok hedefe GERÇEK mesafeleri tek istekte alır.
 *
 * Kuş uçuşu mesafe yanıltıyor: dere, otoyol veya demiryolu araya girdiğinde
 * yakın görünen durak yürüyerek çok daha uzak olabiliyor. OSRM'in matris
 * servisi bunu tek çağrıda çözüyor, hedef başına ayrı rota istemeye gerek yok.
 *
 * Kip önemli: yürüyerek en yakın durak ile arabayla en yakın durak farklı
 * olabiliyor. Yaya köprüsünden geçilen durak yürüyerek yakın ama arabayla
 * dolambaçlı; bölünmüş yol kenarındaki durak ise tersi.
 *
 * @param {object} baslangic
 * @param {Array} hedefler
 * @param {string} [kip] 'yuruyus' (varsayılan) veya 'araba'
 * @returns {Promise<Array<{mesafeM: number, sureSn: number}>>} hedeflerle aynı sırada
 */
function mesafeleriAl(baslangic, hedefler, kip) {
  if (!hedefler.length) return Promise.resolve([]);

  var secilenKip = kip === 'araba' ? 'araba' : 'yuruyus';
  var taban = ROTA_TABANLARI[secilenKip];

  var noktalar = [baslangic].concat(hedefler)
    .map(function (n) { return n.boylam + ',' + n.enlem; })
    .join(';');

  var adres = taban.replace('/route/v1/', '/table/v1/') +
    '/' + noktalar + '?sources=0&annotations=distance,duration';

  return fetch(adres)
    .then(function (yanit) {
      if (!yanit.ok) throw new Error('Mesafe servisi yanıtı: ' + yanit.status); // arayüze çıkmaz
      return yanit.json();
    })
    .then(function (veri) {
      if (veri.code !== 'Ok' || !veri.distances || !veri.distances[0]) {
        throw new Error('Mesafeler alınamadı.');
      }

      var mesafeler = veri.distances[0];
      var sureler = (veri.durations && veri.durations[0]) || [];

      // İlk değer başlangıcın kendisi; hedefler ondan sonra geliyor.
      return hedefler.map(function (_, sira) {
        return {
          mesafeM: mesafeler[sira + 1],
          sureSn: sureler[sira + 1] || 0
        };
      });
    });
}

/**
 * 1140 → "19 dk"
 *
 * Adı hesap.js'teki sureBicimle'den ayrı: o dakika alıyor, bu saniye.
 * İkisi de küresel kapsamda olduğu için aynı adı taşımaları, sonra
 * yüklenen dosyanın diğerini ezmesi demekti.
 */
function rotaSuresiBicimle(saniye) {
  var dk = ceviriMetni('birimDk');
  var sa = ceviriMetni('birimSa');
  var dakika = Math.max(1, Math.round(saniye / 60));
  if (dakika < 60) return dakika + ' ' + dk;
  var saat = Math.floor(dakika / 60);
  var kalan = dakika % 60;
  return kalan === 0 ? saat + ' ' + sa : saat + ' ' + sa + ' ' + kalan + ' ' + dk;
}

if (typeof module !== 'undefined') {
  module.exports = {
    manevrayiTurkcelestir: manevrayiTurkcelestir,
    rotaSuresiBicimle: rotaSuresiBicimle,
    mesafeleriAl: mesafeleriAl
  };
}
