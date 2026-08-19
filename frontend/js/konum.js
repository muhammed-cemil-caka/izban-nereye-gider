// Tarayıcı konum servisi sarmalayıcısı.
//
// Not: Geolocation API yalnızca güvenli bağlamda çalışır — https:// veya
// localhost. file:// veya düz http:// üzerinden açıldığında tarayıcı isteği
// sessizce reddeder, o yüzden durum ayrıca kontrol ediliyor.

var KONUM_ZAMAN_ASIMI_MS = 10000;

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
    navigator.geolocation.getCurrentPosition(
      function (sonuc) {
        coz({
          enlem: sonuc.coords.latitude,
          boylam: sonuc.coords.longitude,
          dogrulukM: sonuc.coords.accuracy
        });
      },
      function (hata) {
        reddet(new Error(konumHatasiniAcikla(hata)));
      },
      { enableHighAccuracy: true, timeout: KONUM_ZAMAN_ASIMI_MS, maximumAge: 60000 }
    );
  });
}

function konumHatasiniAcikla(hata) {
  switch (hata.code) {
    case hata.PERMISSION_DENIED:
      return 'Konum izni verilmedi.';
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
