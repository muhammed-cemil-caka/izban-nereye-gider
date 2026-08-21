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

/** OSRM manevralarının Türkçe karşılıkları. */
var YON_ADLARI = {
  left: 'sola',
  right: 'sağa',
  'slight left': 'hafif sola',
  'slight right': 'hafif sağa',
  'sharp left': 'keskin sola',
  'sharp right': 'keskin sağa',
  straight: 'düz',
  uturn: 'geri'
};

function manevrayiTurkcelestir(manevra, yolAdi) {
  var tur = manevra.type;
  var yon = YON_ADLARI[manevra.modifier] || '';
  var yer = yolAdi ? ' — ' + yolAdi : '';

  switch (tur) {
    case 'depart':
      return 'Yola çık' + yer;
    case 'arrive':
      return 'Vardın' + yer;
    case 'turn':
      return (yon ? yon.charAt(0).toUpperCase() + yon.slice(1) + ' dön' : 'Dön') + yer;
    case 'end of road':
      return 'Yolun sonunda ' + (yon || 'devam et') + ' dön' + yer;
    case 'fork':
      return 'Ayrımda ' + (yon || 'düz') + ' git' + yer;
    case 'new name':
    case 'continue':
      return 'Devam et' + yer;
    case 'roundabout':
    case 'rotary':
      return 'Kavşaktan çık' + yer;
    case 'merge':
      return 'Yola katıl' + yer;
    default:
      return 'Devam et' + yer;
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
      if (!yanit.ok) throw new Error('Rota servisi yanıtı: ' + yanit.status);
      return yanit.json();
    })
    .then(function (veri) {
      if (veri.code !== 'Ok' || !veri.routes || !veri.routes.length) {
        throw new Error(secilenKip === 'araba'
          ? 'Araba rotası bulunamadı.'
          : 'Yürüyüş rotası bulunamadı.');
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
      if (!yanit.ok) throw new Error('Mesafe servisi yanıtı: ' + yanit.status);
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
  var dakika = Math.max(1, Math.round(saniye / 60));
  if (dakika < 60) return dakika + ' dk';
  var saat = Math.floor(dakika / 60);
  var kalan = dakika % 60;
  return kalan === 0 ? saat + ' sa' : saat + ' sa ' + kalan + ' dk';
}

if (typeof module !== 'undefined') {
  module.exports = {
    manevrayiTurkcelestir: manevrayiTurkcelestir,
    rotaSuresiBicimle: rotaSuresiBicimle,
    mesafeleriAl: mesafeleriAl
  };
}
