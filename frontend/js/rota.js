// Yürüyüş rotası — OSRM (OpenStreetMap tabanlı yönlendirme).
//
// Servis notu: routing.openstreetmap.de FOSSGIS'in işlettiği ücretsiz bir
// topluluk servisidir, anahtar istemez ama ağır kullanıma uygun değildir.
// Bu yüzden rota yalnızca kullanıcı isteyince çekilir, kendiliğinden değil.
// Yayına çıkarken kendi OSRM örneğimize ya da anahtarlı bir servise geçilmeli.
var ROTA_TABAN = 'https://routing.openstreetmap.de/routed-foot/route/v1/foot';

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
 * İki nokta arasında yürüyüş rotası ister.
 * @returns {Promise<{noktalar: Array<[number,number]>, mesafeM: number, sureSn: number, adimlar: Array}>}
 */
function yuruyusRotasiAl(baslangic, bitis) {
  var adres = ROTA_TABAN + '/' +
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
        throw new Error('Yürüyüş rotası bulunamadı.');
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
        noktalar: noktalar,
        mesafeM: rota.distance,
        sureSn: rota.duration,
        adimlar: adimlar
      };
    });
}

/**
 * Bir noktadan birden çok hedefe yürüme mesafelerini tek istekte alır.
 *
 * Kuş uçuşu mesafe yanıltıyor: dere, otoyol veya demiryolu araya girdiğinde
 * yakın görünen durak yürüyerek çok daha uzak olabiliyor. OSRM'in matris
 * servisi bunu tek çağrıda çözüyor, hedef başına ayrı rota istemeye gerek yok.
 *
 * @returns {Promise<Array<{mesafeM: number, sureSn: number}>>} hedeflerle aynı sırada
 */
function yuruyusMesafeleriAl(baslangic, hedefler) {
  if (!hedefler.length) return Promise.resolve([]);

  var noktalar = [baslangic].concat(hedefler)
    .map(function (n) { return n.boylam + ',' + n.enlem; })
    .join(';');

  var adres = ROTA_TABAN.replace('/route/v1/foot', '/table/v1/foot') +
    '/' + noktalar + '?sources=0&annotations=distance,duration';

  return fetch(adres)
    .then(function (yanit) {
      if (!yanit.ok) throw new Error('Mesafe servisi yanıtı: ' + yanit.status);
      return yanit.json();
    })
    .then(function (veri) {
      if (veri.code !== 'Ok' || !veri.distances || !veri.distances[0]) {
        throw new Error('Yürüme mesafeleri alınamadı.');
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

/** 1140 → "19 dk" */
function yuruyusSuresiBicimle(saniye) {
  var dakika = Math.max(1, Math.round(saniye / 60));
  if (dakika < 60) return dakika + ' dk';
  var saat = Math.floor(dakika / 60);
  var kalan = dakika % 60;
  return kalan === 0 ? saat + ' sa' : saat + ' sa ' + kalan + ' dk';
}

if (typeof module !== 'undefined') {
  module.exports = {
    manevrayiTurkcelestir: manevrayiTurkcelestir,
    yuruyusSuresiBicimle: yuruyusSuresiBicimle,
    yuruyusMesafeleriAl: yuruyusMesafeleriAl
  };
}
