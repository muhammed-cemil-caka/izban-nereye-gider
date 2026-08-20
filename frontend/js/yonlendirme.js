// Yürüyüş yönlendirmesi — kullanıcıyı rota üzerinde adım adım takip eder.
//
// Ücretli bir navigasyon SDK'sı kullanılmıyor. Gereken her şey elimizde:
// OSRM'den gelen rota geometrisi ve adımlar, tarayıcının konum akışı. Buradaki
// iş, kullanıcının rotanın neresinde olduğunu bulmak (izdüşüm), sıradaki
// manevraya kalan mesafeyi hesaplamak ve rotadan çıkıldığını fark etmek.

var SAPMA_ESIGI_M = 45;        // bu kadar uzaklaşınca rotadan çıkılmış sayılır
var SAPMA_SAYISI = 3;          // üst üste bu kadar ölçümde sapma varsa yeniden hesapla
var VARIS_ESIGI_M = 25;        // hedefe bu kadar yaklaşınca varılmış sayılır
var SESLI_TEKRAR_ESIGI_M = 30; // aynı manevrayı tekrar seslendirmemek için

/**
 * İki nokta arasındaki yön açısını hesaplar (kuzeyden saat yönünde derece).
 * Cihaz kendi başlığını vermediğinde (masaüstünde genelde vermez) hareket
 * yönü ardışık ölçümlerden çıkarılır.
 */
function yonAcisi(baslangic, bitis) {
  var p = Math.PI / 180;
  var enlem1 = baslangic.enlem * p;
  var enlem2 = bitis.enlem * p;
  var dBoylam = (bitis.boylam - baslangic.boylam) * p;

  var y = Math.sin(dBoylam) * Math.cos(enlem2);
  var x = Math.cos(enlem1) * Math.sin(enlem2) -
          Math.sin(enlem1) * Math.cos(enlem2) * Math.cos(dBoylam);

  return (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
}

/** Coğrafi konumu, referans noktaya göre metre cinsinden düzleme taşır. */
function metreyeTasi(konum, referans) {
  var p = Math.PI / 180;
  return {
    x: (konum.boylam - referans.boylam) * 111320 * Math.cos(referans.enlem * p),
    y: (konum.enlem - referans.enlem) * 110574
  };
}

/**
 * Bir noktayı rota çizgisine izdüşürür.
 *
 * @param {{enlem:number, boylam:number}} konum
 * @param {Array<[number,number]>} noktalar rota geometrisi [enlem, boylam]
 * @returns {{sapmaM:number, katEdilenM:number, parcaIndeksi:number}}
 */
function rotayaIzdusur(konum, noktalar) {
  if (!noktalar || noktalar.length < 2) {
    return { sapmaM: 0, katEdilenM: 0, parcaIndeksi: 0 };
  }

  var referans = { enlem: noktalar[0][0], boylam: noktalar[0][1] };
  var nokta = metreyeTasi(konum, referans);

  var enIyi = { sapmaM: Infinity, katEdilenM: 0, parcaIndeksi: 0 };
  var toplam = 0;

  for (var i = 0; i < noktalar.length - 1; i++) {
    var a = metreyeTasi({ enlem: noktalar[i][0], boylam: noktalar[i][1] }, referans);
    var b = metreyeTasi({ enlem: noktalar[i + 1][0], boylam: noktalar[i + 1][1] }, referans);

    var dx = b.x - a.x;
    var dy = b.y - a.y;
    var parcaUzunlugu = Math.sqrt(dx * dx + dy * dy);

    // Sıfır uzunluklu parçalar atlanır, sıfıra bölme olmasın.
    if (parcaUzunlugu < 0.01) continue;

    // Noktanın parça üzerindeki izdüşüm oranı, parça dışına taşmayacak şekilde.
    var oran = ((nokta.x - a.x) * dx + (nokta.y - a.y) * dy) / (parcaUzunlugu * parcaUzunlugu);
    oran = Math.max(0, Math.min(1, oran));

    var izx = a.x + oran * dx;
    var izy = a.y + oran * dy;
    var sapma = Math.sqrt((nokta.x - izx) * (nokta.x - izx) + (nokta.y - izy) * (nokta.y - izy));

    if (sapma < enIyi.sapmaM) {
      enIyi = {
        sapmaM: sapma,
        katEdilenM: toplam + oran * parcaUzunlugu,
        parcaIndeksi: i
      };
    }

    toplam += parcaUzunlugu;
  }

  enIyi.toplamM = toplam;
  return enIyi;
}

/** Adımların bitiş noktalarını kümülatif mesafeye çevirir. */
function adimSinirlariniKur(adimlar) {
  var toplam = 0;
  return adimlar.map(function (adim) {
    toplam += adim.mesafeM;
    return toplam;
  });
}

/**
 * Kullanıcının rota üzerindeki durumunu hesaplar.
 *
 * @returns {{katEdilenM, kalanM, sapmaM, adimIndeksi, sonrakiManevraM, vardiMi}}
 */
function rotaIlerlemesi(konum, rota, adimSinirlari) {
  var izdusum = rotayaIzdusur(konum, rota.noktalar);
  var toplam = izdusum.toplamM || rota.mesafeM;
  var kalan = Math.max(0, toplam - izdusum.katEdilenM);

  // Kat edilen mesafeye göre içinde bulunulan adım.
  var adimIndeksi = 0;
  while (adimIndeksi < adimSinirlari.length - 1 &&
         izdusum.katEdilenM >= adimSinirlari[adimIndeksi]) {
    adimIndeksi++;
  }

  var sonrakiManevraM = Math.max(0, adimSinirlari[adimIndeksi] - izdusum.katEdilenM);

  return {
    katEdilenM: izdusum.katEdilenM,
    kalanM: kalan,
    sapmaM: izdusum.sapmaM,
    adimIndeksi: adimIndeksi,
    sonrakiManevraM: sonrakiManevraM,
    vardiMi: kalan <= VARIS_ESIGI_M
  };
}

/**
 * Yönlendirme oturumu. Konum akışını dinler, ilerlemeyi hesaplar ve
 * geri çağrılarla arayüzü besler.
 *
 * @param {object} secenekler
 *   rota, hedef, durumDegisti(durum), yenidenHesapla(), bitti(sebep)
 */
function yonlendirmeBaslat(secenekler) {
  var rota = secenekler.rota;
  var adimSinirlari = adimSinirlariniKur(rota.adimlar);

  var izleyici = null;
  var sapmaSayaci = 0;
  var sonSeslendirilenAdim = -1;
  var oncekiKonum = null;
  var sonAci = null;
  var bitti = false;

  function durdur(sebep) {
    if (bitti) return;
    bitti = true;
    if (izleyici !== null) navigator.geolocation.clearWatch(izleyici);
    if (secenekler.bitti) secenekler.bitti(sebep);
  }

  function seslendir(metin) {
    if (!secenekler.sesliMi || typeof speechSynthesis === 'undefined') return;
    try {
      var konusma = new SpeechSynthesisUtterance(metin);
      konusma.lang = 'tr-TR';
      speechSynthesis.cancel();
      speechSynthesis.speak(konusma);
    } catch (sorun) { /* ses desteklenmiyorsa sessizce geç */ }
  }

  izleyici = navigator.geolocation.watchPosition(
    function (sonuc) {
      if (bitti) return;

      var konum = {
        enlem: sonuc.coords.latitude,
        boylam: sonuc.coords.longitude,
        dogrulukM: sonuc.coords.accuracy
      };

      // Yön önce ardışık ölçümlerden hesaplanır: her cihazda güvenilirdir.
      // Cihazın kendi başlığı yalnızca açıkça geçerliyse kullanılır — birçok
      // cihaz "bilinmiyor" yerine 0 döndürüyor ve buna güvenmek oku sürekli
      // kuzeye çeviriyordu.
      //
      // Önceki konum yalnızca yön hesaplandığında güncellenir; yoksa 5 m'lik
      // eşiğe hiç ulaşılamaz ve küçük adımlar birikmez.
      if (!oncekiKonum) {
        oncekiKonum = { enlem: konum.enlem, boylam: konum.boylam };
      } else {
        var p = Math.PI / 180;
        var dx = (konum.boylam - oncekiKonum.boylam) * 111320 * Math.cos(konum.enlem * p);
        var dy = (konum.enlem - oncekiKonum.enlem) * 110574;

        if (Math.sqrt(dx * dx + dy * dy) >= 5) {
          sonAci = yonAcisi(oncekiKonum, konum);
          oncekiKonum = { enlem: konum.enlem, boylam: konum.boylam };
        } else if (sonuc.coords.heading > 0 && sonuc.coords.speed > 0.5) {
          sonAci = sonuc.coords.heading;
        }
      }

      var ilerleme = rotaIlerlemesi(konum, rota, adimSinirlari);

      // Rotadan çıkış: tek bir kötü ölçüm yeniden hesaplamayı tetiklemesin.
      if (ilerleme.sapmaM > SAPMA_ESIGI_M) {
        sapmaSayaci++;
        if (sapmaSayaci >= SAPMA_SAYISI) {
          sapmaSayaci = 0;
          if (secenekler.yenidenHesapla) secenekler.yenidenHesapla(konum);
          return;
        }
      } else {
        sapmaSayaci = 0;
      }

      if (ilerleme.vardiMi) {
        seslendir('Vardın.');
        durdur('varildi');
        return;
      }

      // Yeni bir manevraya geçildiyse bir kez seslendir.
      if (ilerleme.adimIndeksi !== sonSeslendirilenAdim &&
          ilerleme.sonrakiManevraM > SESLI_TEKRAR_ESIGI_M) {
        sonSeslendirilenAdim = ilerleme.adimIndeksi;
        var adim = rota.adimlar[ilerleme.adimIndeksi];
        if (adim) seslendir(adim.metin);
      }

      if (secenekler.durumDegisti) {
        secenekler.durumDegisti({ konum: konum, ilerleme: ilerleme, aci: sonAci });
      }
    },
    function (hata) {
      durdur('hata');
    },
    { enableHighAccuracy: true, maximumAge: 0, timeout: 20000 }
  );

  return { durdur: function () { durdur('kullanici'); } };
}

if (typeof module !== 'undefined') {
  module.exports = {
    rotayaIzdusur: rotayaIzdusur,
    yonAcisi: yonAcisi,
    adimSinirlariniKur: adimSinirlariniKur,
    rotaIlerlemesi: rotaIlerlemesi
  };
}
