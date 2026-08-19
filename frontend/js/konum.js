// Tarayıcı konum servisi sarmalayıcısı.
//
// Not: Geolocation API yalnızca güvenli bağlamda çalışır — https:// veya
// localhost. file:// veya düz http:// üzerinden açıldığında tarayıcı isteği
// sessizce reddeder, o yüzden durum ayrıca kontrol ediliyor.

// Tek bir getCurrentPosition çağrısı çoğu zaman ilk gelen kaba konumu döndürür
// (Wi-Fi/IP tabanlı, kilometrelerce sapabilir). Bunun yerine watchPosition ile
// konum akışı dinlenip en iyi ölçüm tutuluyor: ya hedef doğruluğa ulaşılır ya da
// süre dolunca eldeki en iyisi kullanılır.
var HEDEF_DOGRULUK_M = 100;   // bu doğruluğa ulaşınca beklemeyi bırak
var TOPLAMA_SURESI_MS = 8000; // daha iyisini beklemek için ayrılan süre
var BEKCI_SURESI_MS = 15000;  // hiçbir ölçüm gelmezse pes etme süresi

/** Tarayıcı konum desteği ve güvenli bağlam kontrolü. */
function konumDesteklenirMi() {
  if (!('geolocation' in navigator)) {
    return { destekli: false, sebep: 'Tarayıcınız konum servisini desteklemiyor.' };
  }
  if (!window.isSecureContext) {
    return {
      destekli: false,
      sebep: 'Konum yalnızca güvenli bağlantıda (https) çalışır. ' +
             'Siteyi localhost veya https adresinden açın.'
    };
  }
  return { destekli: true };
}

/**
 * Kullanıcının konumunu ister. İzin istemi tarayıcı tarafından gösterilir.
 * @returns {Promise<{enlem: number, boylam: number, dogrulukM: number}>}
 */
function konumAl() {
  var durum = konumDesteklenirMi();
  if (!durum.destekli) return Promise.reject(new Error(durum.sebep));

  return new Promise(function (coz, reddet) {
    var enIyi = null;
    var izleyici = null;
    var toplamaSayaci = null;
    var bekciSayaci = null;
    var bitti = false;

    function temizle() {
      if (izleyici !== null) navigator.geolocation.clearWatch(izleyici);
      clearTimeout(toplamaSayaci);
      clearTimeout(bekciSayaci);
    }

    function tamamla() {
      if (bitti) return;
      bitti = true;
      temizle();

      if (enIyi) {
        coz(enIyi);
      } else {
        reddet(new Error(
          'Konum yanıt vermedi. macOS kullanıyorsan Sistem Ayarları → Gizlilik ve ' +
          'Güvenlik → Konum Servisleri altında tarayıcına izin verilmiş olmalı.'
        ));
      }
    }

    izleyici = navigator.geolocation.watchPosition(
      function (sonuc) {
        var olcum = {
          enlem: sonuc.coords.latitude,
          boylam: sonuc.coords.longitude,
          dogrulukM: sonuc.coords.accuracy
        };

        // Yalnızca daha isabetli ölçümler eskisinin yerini alır.
        if (!enIyi || olcum.dogrulukM < enIyi.dogrulukM) enIyi = olcum;

        // Yeterince isabetliyse daha fazla beklemeye gerek yok.
        if (enIyi.dogrulukM <= HEDEF_DOGRULUK_M) tamamla();
      },
      function (hata) {
        if (bitti) return;
        // İzin reddi gibi kalıcı hatalarda beklemenin anlamı yok.
        bitti = true;
        temizle();
        reddet(new Error(konumHatasiniAcikla(hata)));
      },
      {
        enableHighAccuracy: true,
        timeout: BEKCI_SURESI_MS,
        // Önbellekteki eski (ve genelde kaba) konum kabul edilmez.
        maximumAge: 0
      }
    );

    // Hedef doğruluğa ulaşılmasa da süre dolunca eldeki en iyi ölçüm kullanılır.
    toplamaSayaci = setTimeout(function () {
      if (enIyi) tamamla();
    }, TOPLAMA_SURESI_MS);

    // Tarayıcı hiçbir geri çağrı yapmazsa (macOS'ta sistem konum servisi
    // kapalıyken oluyor) arayüz sonsuza kadar beklemesin.
    bekciSayaci = setTimeout(tamamla, BEKCI_SURESI_MS + 2000);
  });
}

function konumHatasiniAcikla(hata) {
  switch (hata.code) {
    case hata.PERMISSION_DENIED:
      return 'Konum izni verilmedi. Adres çubuğundaki kilit simgesinden ' +
             'izin verip tekrar deneyebilirsin.';
    case hata.POSITION_UNAVAILABLE:
      return 'Konum bilgisi alınamadı.';
    case hata.TIMEOUT:
      return 'Konum isteği zaman aşımına uğradı.';
    default:
      return 'Konum alınamadı.';
  }
}

/**
 * Tarayıcı izin durumunu sorar (destekleyen tarayıcılarda).
 * @returns {Promise<'granted'|'denied'|'prompt'|'bilinmiyor'>}
 */
function konumIzinDurumu() {
  if (!navigator.permissions || !navigator.permissions.query) {
    return Promise.resolve('bilinmiyor');
  }
  return navigator.permissions.query({ name: 'geolocation' })
    .then(function (sonuc) { return sonuc.state; })
    .catch(function () { return 'bilinmiyor'; });
}
